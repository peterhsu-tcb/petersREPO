//! Wire-format types for the Anthropic and OpenAI-compatible APIs.
//!
//! These types are (de)serialised directly from/to JSON payloads sent over the
//! network.  The naming and field layout follows the Anthropic `/v1/messages`
//! spec unless otherwise noted; the OpenAI-compat translation layer in
//! `providers/openai_compat.rs` converts between formats when needed.
//!
//! # Key types
//!
//! | Type | Direction | Purpose |
//! |------|-----------|---------|
//! | [`MessageRequest`] | Outgoing | Sent to the provider to initiate a conversation turn |
//! | [`MessageResponse`] | Incoming | Full (non-streaming) response from the provider |
//! | [`StreamEvent`] | Incoming | One SSE event in a streaming response |
//! | [`Usage`] | Both | Token counts attached to requests and responses |
//! | [`InputMessage`] / [`OutputContentBlock`] | Both | Conversation history |

use runtime::{pricing_for_model, TokenUsage, UsageCostEstimate}; // Cost estimation helpers from the runtime crate.
use serde::{Deserialize, Serialize}; // Standard JSON (de)serialisation derives.
use serde_json::Value; // Untyped JSON value — used for tool `input` and schema fields.

// ── Outgoing request ──────────────────────────────────────────────────────────

/// The outgoing JSON body POSTed to `/v1/messages` (or `/chat/completions`).
///
/// Fields annotated with `skip_serializing_if = "Option::is_none"` are omitted
/// from the payload when not set, keeping requests minimal.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct MessageRequest {
    /// Model ID (or alias, after expansion) to use for this request.
    pub model: String,

    /// Maximum number of output tokens the model may generate in this turn.
    pub max_tokens: u32,

    /// Conversation history: alternating user / assistant messages.
    pub messages: Vec<InputMessage>,

    /// Optional system prompt.  Omitted from the JSON payload when `None`.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub system: Option<String>,

    /// Tool definitions available to the model in this turn.  Omitted when empty.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tools: Option<Vec<ToolDefinition>>,

    /// Controls how the model selects tools (`auto`, `any`, or a specific tool).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tool_choice: Option<ToolChoice>,

    /// When `true`, the provider streams response events via SSE.
    /// Uses `std::ops::Not::not` as the skip predicate so `false` is always omitted.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub stream: bool,

    /// OpenAI-compatible tuning parameters. Optional — omitted from payload when None.
    /// Sampling temperature (0.0–1.0 for most models; 0.0–2.0 for some OpenAI models).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub temperature: Option<f64>,

    /// Nucleus sampling probability mass (0.0–1.0). Alternative to `temperature`.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub top_p: Option<f64>,

    /// Penalises token frequency to reduce repetition (OpenAI-compat only).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub frequency_penalty: Option<f64>,

    /// Penalises already-present tokens to encourage topic diversity (OpenAI-compat only).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub presence_penalty: Option<f64>,

    /// Optional stop sequences — generation halts on the first match.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stop: Option<Vec<String>>,

    /// Reasoning effort level for OpenAI-compatible reasoning models (e.g. `o4-mini`).
    /// Accepted values: `"low"`, `"medium"`, `"high"`. Omitted when `None`.
    /// Silently ignored by backends that do not support it.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reasoning_effort: Option<String>,
}

impl MessageRequest {
    /// Return a copy of this request with `stream` set to `true`.
    ///
    /// Convenience builder method — call this before passing the request to
    /// [`ProviderClient::stream_message`].
    #[must_use]
    pub fn with_streaming(mut self) -> Self {
        self.stream = true; // Enable SSE streaming in the outgoing payload.
        self
    }
}

// ── Conversation history ──────────────────────────────────────────────────────

/// A single message in the conversation history (one `role` + one or more content blocks).
///
/// Anthropic requires messages to alternate `"user"` / `"assistant"` roles.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct InputMessage {
    /// Either `"user"` or `"assistant"`.
    pub role: String,
    /// One or more content blocks making up this message.
    pub content: Vec<InputContentBlock>,
}

impl InputMessage {
    /// Construct a `"user"` message with a single plain-text block.
    ///
    /// This is the most common way to send a user prompt to the model.
    #[must_use]
    pub fn user_text(text: impl Into<String>) -> Self {
        Self {
            role: "user".to_string(), // Anthropic requires lowercase "user".
            content: vec![InputContentBlock::Text { text: text.into() }], // Wrap in a text block.
        }
    }

    /// Construct a `"user"` message that returns a tool result to the model.
    ///
    /// After the model emits a `ToolUse` block, the caller executes the tool and
    /// sends back the result in a `ToolResult` block so the model can continue.
    ///
    /// - `tool_use_id` — the `id` from the model's `ToolUse` block.
    /// - `content` — the tool's output as a string.
    /// - `is_error` — `true` if the tool execution failed; the model may handle errors differently.
    #[must_use]
    pub fn user_tool_result(
        tool_use_id: impl Into<String>,
        content: impl Into<String>,
        is_error: bool,
    ) -> Self {
        Self {
            role: "user".to_string(), // Tool results are always in a "user" message.
            content: vec![InputContentBlock::ToolResult {
                tool_use_id: tool_use_id.into(), // Links this result back to the model's request.
                content: vec![ToolResultContentBlock::Text {
                    text: content.into(), // The tool's stdout / return value as a plain string.
                }],
                is_error, // Signal to the model whether the tool succeeded or failed.
            }],
        }
    }
}

/// A single content block within an `InputMessage`.
///
/// Serde uses `#[serde(tag = "type")]` to serialise/deserialise the variant
/// using the Anthropic `"type"` discriminator field (`"text"`, `"tool_use"`, etc.).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum InputContentBlock {
    /// Plain text from the user or assistant.
    Text {
        text: String, // The raw text content.
    },
    /// A tool call previously returned by the assistant and now included for context.
    ToolUse {
        id: String,    // Opaque tool-call ID assigned by the model.
        name: String,  // Tool name (must match a `ToolDefinition` name in the request).
        input: Value,  // Tool arguments as an untyped JSON object.
    },
    /// The result of executing a tool, sent back to the model.
    ToolResult {
        tool_use_id: String,                  // Matches the `id` from the corresponding `ToolUse` block.
        content: Vec<ToolResultContentBlock>, // One or more content blocks with the tool's output.
        /// Whether the tool invocation produced an error. Default `false`; omitted from JSON when false.
        #[serde(default, skip_serializing_if = "std::ops::Not::not")]
        is_error: bool,
    },
}

/// Content block types that can appear inside a `ToolResult`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ToolResultContentBlock {
    /// Plain text (most common — stdout, file contents, error messages, etc.).
    Text { text: String },
    /// Structured JSON output (used by tools that return machine-readable data).
    Json { value: Value },
}

// ── Tool definition ───────────────────────────────────────────────────────────

/// A tool definition included in the request, describing one callable tool.
///
/// The `input_schema` is a JSON Schema object that tells the model what arguments
/// the tool expects.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolDefinition {
    /// Unique tool name (used by the model when emitting a `ToolUse` block).
    pub name: String,
    /// Human-readable description helping the model decide when to use this tool.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// JSON Schema for the tool's input parameters.
    pub input_schema: Value,
}

/// Controls how the model selects tools when `tools` are present in the request.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ToolChoice {
    /// Model decides whether and which tool to use (default).
    Auto,
    /// Model must use at least one tool in its response.
    Any,
    /// Model must use the specified tool.
    Tool { name: String },
}

// ── Full (non-streaming) response ─────────────────────────────────────────────

/// The full response body returned by a non-streaming `/v1/messages` call.
///
/// Also emitted as the initial envelope in a streaming response via
/// [`MessageStartEvent`].
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MessageResponse {
    /// Opaque message ID assigned by the provider (e.g. `"msg_01XFDUDYJgAACzvnptvVoYEL"`).
    pub id: String,
    /// Always `"message"` in the current API version.
    #[serde(rename = "type")]
    pub kind: String,
    /// Always `"assistant"` for responses.
    pub role: String,
    /// One or more content blocks produced by the model (text, tool calls, etc.).
    pub content: Vec<OutputContentBlock>,
    /// The model that generated this response (may differ from the requested model).
    pub model: String,
    /// Reason the generation stopped: `"end_turn"`, `"max_tokens"`, `"tool_use"`, etc.
    #[serde(default)]
    pub stop_reason: Option<String>,
    /// The stop sequence that triggered the stop, if `stop_sequences` was configured.
    #[serde(default)]
    pub stop_sequence: Option<String>,
    /// Token counts for this response.
    #[serde(default)]
    pub usage: Usage,
    /// Provider-assigned request ID (from the `x-request-id` header, if available).
    #[serde(default)]
    pub request_id: Option<String>,
}

impl MessageResponse {
    /// Convenience method: returns the total token count (input + output + cache).
    #[must_use]
    pub fn total_tokens(&self) -> u32 {
        self.usage.total_tokens() // Delegate to Usage::total_tokens().
    }
}

/// A content block in an assistant response.
///
/// The discriminator field is `"type"` using `snake_case` variant names.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum OutputContentBlock {
    /// Plain text output from the model.
    Text {
        text: String, // The generated text.
    },
    /// A request by the model to call a tool.
    ToolUse {
        id: String,   // Opaque ID — must be echoed back in the corresponding `ToolResult`.
        name: String, // Tool name matching one of the `ToolDefinition` names in the request.
        input: Value, // Tool arguments as a JSON object.
    },
    /// Extended thinking output (Claude extended-thinking models only).
    Thinking {
        /// The model's internal reasoning text.
        #[serde(default)]
        thinking: String,
        /// Optional cryptographic signature for thinking verification.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        signature: Option<String>,
    },
    /// Redacted thinking block — emitted instead of `Thinking` when content was redacted.
    RedactedThinking {
        data: Value, // Opaque redacted data payload.
    },
}

// ── Token usage ───────────────────────────────────────────────────────────────

/// Token counts for a single API request/response pair.
///
/// All fields default to `0` when absent from the JSON (e.g. when prompt caching
/// is not active, `cache_creation_input_tokens` and `cache_read_input_tokens` are 0).
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Usage {
    /// Tokens in the input messages (not counted towards cache savings).
    #[serde(default)]
    pub input_tokens: u32,
    /// Tokens written to the prompt cache (incur a higher per-token cost).
    #[serde(default)]
    pub cache_creation_input_tokens: u32,
    /// Tokens read from the prompt cache (much cheaper than fresh input tokens).
    #[serde(default)]
    pub cache_read_input_tokens: u32,
    /// Tokens generated in the output.
    #[serde(default)]
    pub output_tokens: u32,
}

impl Usage {
    /// Sum of all four token counts.
    ///
    /// Includes cache tokens because they still count towards the model's context window.
    #[must_use]
    pub const fn total_tokens(&self) -> u32 {
        self.input_tokens
            + self.output_tokens
            + self.cache_creation_input_tokens
            + self.cache_read_input_tokens
    }

    /// Convert to the `TokenUsage` type used by the `runtime` crate's usage tracker.
    #[must_use]
    pub const fn token_usage(&self) -> TokenUsage {
        TokenUsage {
            input_tokens: self.input_tokens,
            output_tokens: self.output_tokens,
            cache_creation_input_tokens: self.cache_creation_input_tokens,
            cache_read_input_tokens: self.cache_read_input_tokens,
        }
    }

    /// Estimate the USD cost for this usage, using per-model pricing from the `runtime` crate.
    ///
    /// Falls back to a generic estimate when the model is not in the pricing table.
    #[must_use]
    pub fn estimated_cost_usd(&self, model: &str) -> UsageCostEstimate {
        let usage = self.token_usage(); // Convert to runtime's TokenUsage first.
        pricing_for_model(model).map_or_else(
            || usage.estimate_cost_usd(),                      // Unknown model — use generic pricing.
            |pricing| usage.estimate_cost_usd_with_pricing(pricing), // Known model — use exact pricing.
        )
    }
}

// ── Streaming SSE events ──────────────────────────────────────────────────────

/// The first SSE event in a streaming response. Carries the initial response envelope.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MessageStartEvent {
    /// Partial `MessageResponse` shell (no content yet; `usage` may be partially populated).
    pub message: MessageResponse,
}

/// Emitted near the end of a streaming response with final stop reason and usage.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MessageDeltaEvent {
    /// Stop reason and stop sequence for the completed message.
    pub delta: MessageDelta,
    /// Final token usage counts (may supersede counts from `MessageStartEvent`).
    #[serde(default)]
    pub usage: Usage,
}

/// The `delta` payload inside a [`MessageDeltaEvent`].
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MessageDelta {
    /// Why generation stopped (e.g. `"end_turn"`, `"max_tokens"`, `"tool_use"`).
    #[serde(default)]
    pub stop_reason: Option<String>,
    /// The stop sequence string that triggered the stop, if applicable.
    #[serde(default)]
    pub stop_sequence: Option<String>,
}

/// Signals the start of a new content block in the stream.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ContentBlockStartEvent {
    /// Zero-based index of the content block being started.
    pub index: u32,
    /// The initial (possibly empty) content block.
    pub content_block: OutputContentBlock,
}

/// Carries an incremental delta for an in-progress content block.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ContentBlockDeltaEvent {
    /// Index of the content block being updated.
    pub index: u32,
    /// The delta to append to the block.
    pub delta: ContentBlockDelta,
}

/// An incremental delta for a content block in the stream.
///
/// The variant to expect depends on the block type started in [`ContentBlockStartEvent`]:
/// - `Text` blocks → `TextDelta`
/// - `ToolUse` input → `InputJsonDelta`
/// - `Thinking` blocks → `ThinkingDelta` + `SignatureDelta` at the end
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ContentBlockDelta {
    /// Incremental text chunk for a `Text` output block.
    TextDelta { text: String },
    /// Incremental JSON fragment for a `ToolUse` input field.
    InputJsonDelta { partial_json: String },
    /// Incremental thinking text for a `Thinking` block.
    ThinkingDelta { thinking: String },
    /// Cryptographic signature appended at the end of a `Thinking` block.
    SignatureDelta { signature: String },
}

/// Signals that a content block is complete (no more deltas for this index).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContentBlockStopEvent {
    /// Index of the content block that just finished.
    pub index: u32,
}

/// Signals that the entire streaming message is complete.
///
/// After this event, no further SSE events will arrive on the connection.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MessageStopEvent {}

/// Top-level SSE event discriminated union.
///
/// The `type` field in each SSE `data` payload determines which variant to parse.
/// Consumers iterate these events via [`MessageStream::next_event`].
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum StreamEvent {
    /// First event — carries the initial message envelope.
    MessageStart(MessageStartEvent),
    /// Near-final event — carries stop reason and final usage counts.
    MessageDelta(MessageDeltaEvent),
    /// Signals a new content block is starting.
    ContentBlockStart(ContentBlockStartEvent),
    /// Carries an incremental update to the current content block.
    ContentBlockDelta(ContentBlockDeltaEvent),
    /// Signals the current content block is complete.
    ContentBlockStop(ContentBlockStopEvent),
    /// Final event — the entire message stream is done.
    MessageStop(MessageStopEvent),
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use runtime::format_usd; // Helper that formats a USD amount as a "$X.XXXX" string.

    use super::{MessageResponse, Usage};

    #[test]
    fn usage_total_tokens_includes_cache_tokens() {
        // Ensure all four token categories are summed correctly.
        let usage = Usage {
            input_tokens: 10,                  // Regular input tokens.
            cache_creation_input_tokens: 2,    // Tokens written to cache.
            cache_read_input_tokens: 3,        // Tokens read from cache.
            output_tokens: 4,                  // Generated output tokens.
        };

        // Total must be 10 + 2 + 3 + 4 = 19.
        assert_eq!(usage.total_tokens(), 19);
        // TokenUsage::total_tokens() must agree with Usage::total_tokens().
        assert_eq!(usage.token_usage().total_tokens(), 19);
    }

    #[test]
    fn message_response_estimates_cost_from_model_usage() {
        // Build a synthetic response with known token counts and a known-priced model.
        let response = MessageResponse {
            id: "msg_cost".to_string(),
            kind: "message".to_string(),
            role: "assistant".to_string(),
            content: Vec::new(), // No content needed for cost estimation.
            model: "claude-sonnet-4-20250514".to_string(), // Model with known pricing.
            stop_reason: Some("end_turn".to_string()),
            stop_sequence: None,
            usage: Usage {
                input_tokens: 1_000_000,              // 1M input tokens.
                cache_creation_input_tokens: 100_000, // 100K cache-write tokens.
                cache_read_input_tokens: 200_000,     // 200K cache-read tokens.
                output_tokens: 500_000,               // 500K output tokens.
            },
            request_id: None,
        };

        // Verify the cost estimate matches the expected value for these token counts.
        let cost = response.usage.estimated_cost_usd(&response.model);
        assert_eq!(format_usd(cost.total_cost_usd()), "$54.6750");
        // Total tokens: 1M + 100K + 200K + 500K = 1.8M.
        assert_eq!(response.total_tokens(), 1_800_000);
    }
}
