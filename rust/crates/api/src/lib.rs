//! API crate — provider-facing network layer for Claw Code.
//!
//! This crate owns all communication with LLM provider APIs (Anthropic, xAI/Grok,
//! OpenAI-compatible endpoints such as DashScope/Qwen). It exposes:
//!
//! - A unified [`ProviderClient`] enum that routes to the correct backend.
//! - All wire-format request/response types (`MessageRequest`, `MessageResponse`,
//!   `StreamEvent`, `Usage`, etc.) used throughout the workspace.
//! - SSE streaming parsing via [`SseParser`].
//! - Prompt-cache management via [`PromptCache`].
//! - An HTTP client builder with proxy support via [`ProxyConfig`].
//! - Telemetry re-exports from the `telemetry` crate.

// ── Internal modules ──────────────────────────────────────────────────────────

/// Unified `ProviderClient` enum that wraps provider-specific clients.
mod client;

/// `ApiError` — all API-level errors (network, auth, rate-limit, etc.).
mod error;

/// Reqwest HTTP client builder with optional proxy configuration.
mod http_client;

/// Prompt caching logic: breakpoint detection, stats, and record persistence.
mod prompt_cache;

/// Provider detection, model alias resolution, and per-provider client impls.
mod providers;

/// Incremental SSE (Server-Sent Events) frame parser for streaming responses.
mod sse;

/// Serde types for the Anthropic/OpenAI-compatible wire format.
mod types;

// ── Public re-exports — client layer ─────────────────────────────────────────

pub use client::{
    // OAuth helpers re-exported so callers don't need to import `providers::anthropic` directly.
    oauth_token_is_expired,        // Returns true when an OAuth token has passed its expiry.
    read_base_url,                 // Reads ANTHROPIC_BASE_URL (or default) for the Anthropic endpoint.
    read_xai_base_url,             // Reads XAI_BASE_URL (or default) for the xAI/Grok endpoint.
    resolve_saved_oauth_token,     // Loads a cached OAuth token from disk, if present.
    resolve_startup_auth_source,   // Determines the auth source (API key vs. OAuth) at startup.
    MessageStream,                 // Enum wrapping provider-specific streaming response handles.
    OAuthTokenSet,                 // OAuth token bundle (access + refresh + expiry).
    ProviderClient,                // Unified enum: Anthropic | Xai | OpenAi.
};

// ── Public re-exports — error types ──────────────────────────────────────────

pub use error::ApiError; // Top-level error type for all API operations.

// ── Public re-exports — HTTP client ──────────────────────────────────────────

pub use http_client::{
    build_http_client,             // Builds a reqwest Client from env proxy settings.
    build_http_client_or_default,  // Same as above but returns a plain client on failure.
    build_http_client_with,        // Builds a reqwest Client from an explicit ProxyConfig.
    ProxyConfig,                   // Proxy configuration (URL, no-proxy list).
};

// ── Public re-exports — prompt cache ─────────────────────────────────────────

pub use prompt_cache::{
    CacheBreakEvent,      // Event emitted when a prompt-cache breakpoint is inserted.
    PromptCache,          // Manages prompt-cache state across turns.
    PromptCacheConfig,    // Configuration for cache breakpoint placement.
    PromptCachePaths,     // Filesystem paths used for prompt-cache persistence.
    PromptCacheRecord,    // Snapshot of cache state after a single request.
    PromptCacheStats,     // Aggregate hit/miss/cost statistics for the current session.
};

// ── Public re-exports — provider clients ─────────────────────────────────────

/// Native Anthropic client (`/v1/messages`). Also re-exported as `ApiClient`
/// for backwards compatibility with callers that use the older alias.
pub use providers::anthropic::{AnthropicClient, AnthropicClient as ApiClient, AuthSource};

pub use providers::openai_compat::{
    build_chat_completion_request,  // Converts a `MessageRequest` into an OpenAI chat-completion body.
    flatten_tool_result_content,    // Normalises tool-result content to a plain string for OpenAI.
    is_reasoning_model,             // Returns true for models that use the `reasoning_effort` field.
    model_rejects_is_error_field,   // Returns true for models that reject `is_error` in tool results.
    translate_message,              // Translates an Anthropic `InputMessage` to OpenAI format.
    OpenAiCompatClient,             // HTTP client for OpenAI-compatible endpoints (xAI, DashScope, …).
    OpenAiCompatConfig,             // Per-provider endpoint/auth config (openai, xai, dashscope).
};

pub use providers::{
    detect_provider_kind,                // Infers `ProviderKind` from a model string.
    max_tokens_for_model,                // Returns the default max-tokens cap for a given model.
    max_tokens_for_model_with_override,  // Same, but respects an explicit caller-supplied override.
    resolve_model_alias,                 // Expands short aliases (e.g. "opus") to full model IDs.
    ProviderKind,                        // Enum: Anthropic | Xai | OpenAi.
};

// ── Public re-exports — SSE parser ───────────────────────────────────────────

pub use sse::{
    parse_frame, // Parses a single raw SSE frame into an event type and data string.
    SseParser,   // Stateful incremental SSE parser that buffers partial frames.
};

// ── Public re-exports — wire-format types ────────────────────────────────────

pub use types::{
    ContentBlockDelta,          // A streaming delta for a single content block.
    ContentBlockDeltaEvent,     // SSE event wrapping a `ContentBlockDelta` with its block index.
    ContentBlockStartEvent,     // SSE event marking the start of a new content block.
    ContentBlockStopEvent,      // SSE event marking the end of a content block.
    InputContentBlock,          // Tagged enum: Text | ToolUse | ToolResult.
    InputMessage,               // A single message in the conversation (role + content blocks).
    MessageDelta,               // Stop-reason delta emitted at end of streaming message.
    MessageDeltaEvent,          // SSE event wrapping a `MessageDelta` and incremental usage.
    MessageRequest,             // Outgoing request body sent to the provider API.
    MessageResponse,            // Full (non-streaming) response from the provider API.
    MessageStartEvent,          // First SSE event; carries the initial `MessageResponse` shell.
    MessageStopEvent,           // Final SSE event; signals the stream is complete.
    OutputContentBlock,         // Tagged enum: Text | ToolUse | Thinking | RedactedThinking.
    StreamEvent,                // Top-level SSE event enum used by streaming consumers.
    ToolChoice,                 // How the model selects tools: Auto | Any | Tool { name }.
    ToolDefinition,             // A single tool spec (name, description, JSON schema).
    ToolResultContentBlock,     // Content inside a tool-result block: Text | Json.
    Usage,                      // Token counts (input, output, cache_creation, cache_read).
};

// ── Public re-exports — telemetry ────────────────────────────────────────────

/// Telemetry types are defined in the `telemetry` crate and re-exported here
/// so that callers can use them without taking a direct dependency on that crate.
pub use telemetry::{
    AnalyticsEvent,            // High-level analytics event (session start, tool call, etc.).
    AnthropicRequestProfile,   // Per-request profiling data (model, tokens, latency).
    ClientIdentity,            // Identifies the client SDK/version in telemetry payloads.
    JsonlTelemetrySink,        // Writes telemetry records as newline-delimited JSON to disk.
    MemoryTelemetrySink,       // In-memory telemetry sink used in tests.
    SessionTraceRecord,        // Full trace record for one session turn.
    SessionTracer,             // Accumulates trace records for the current session.
    TelemetryEvent,            // Low-level telemetry event payload.
    TelemetrySink,             // Trait: sink that accepts telemetry events.
    DEFAULT_ANTHROPIC_VERSION, // The default `anthropic-version` header value used in requests.
};
