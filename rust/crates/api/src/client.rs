//! Unified provider client — wraps Anthropic, xAI, and OpenAI-compatible backends
//! behind a single `ProviderClient` enum so the rest of the workspace never needs
//! to branch on provider type.
//!
//! # Provider routing
//!
//! `ProviderClient::from_model(model)` inspects the model string to pick the right
//! backend:
//! - Models prefixed with `claude-` (or the `opus`/`sonnet`/`haiku` aliases) → `Anthropic`
//! - Models prefixed with `grok-` → `Xai`
//! - Everything else (including `qwen-*` DashScope models) → `OpenAi`
//!
//! DashScope models speak the OpenAI wire format but need a different base URL and
//! auth env-var (`DASHSCOPE_API_KEY`), so `from_model` also reads provider metadata
//! to select the right `OpenAiCompatConfig`.

use crate::error::ApiError; // Top-level API error type.
use crate::prompt_cache::{PromptCache, PromptCacheRecord, PromptCacheStats}; // Cache management.
use crate::providers::anthropic::{self, AnthropicClient, AuthSource}; // Native Anthropic client.
use crate::providers::openai_compat::{self, OpenAiCompatClient, OpenAiCompatConfig}; // OAI-compat client.
use crate::providers::{self, ProviderKind}; // Provider detection utilities.
use crate::types::{MessageRequest, MessageResponse, StreamEvent}; // Wire-format types.

/// Unified LLM provider client.
///
/// Callers construct one of these via [`ProviderClient::from_model`] and then use
/// [`send_message`] / [`stream_message`] without caring which provider backs the model.
///
/// The `large_enum_variant` lint is suppressed because `AnthropicClient` is
/// intentionally larger than the OpenAI variant — the size difference is acceptable
/// here since `ProviderClient` is typically heap-allocated inside an `Arc`.
#[allow(clippy::large_enum_variant)]
#[derive(Debug, Clone)]
pub enum ProviderClient {
    /// Native Anthropic client — handles `claude-*` models via `/v1/messages`.
    Anthropic(AnthropicClient),
    /// xAI/Grok client — OpenAI-compatible endpoint at `api.x.ai`.
    Xai(OpenAiCompatClient),
    /// Generic OpenAI-compatible client — covers `openai`, `qwen-*`/DashScope, etc.
    OpenAi(OpenAiCompatClient),
}

impl ProviderClient {
    /// Construct a `ProviderClient` from a model string using environment-based auth.
    ///
    /// Alias expansion (e.g. `"opus"` → `"claude-opus-4-6"`) is applied before
    /// provider detection, so short aliases work transparently.
    ///
    /// Returns `Err(ApiError)` if the required API key environment variable is missing.
    pub fn from_model(model: &str) -> Result<Self, ApiError> {
        // Delegate to the variant that accepts an explicit auth override; pass `None`
        // to use the default environment-based auth path.
        Self::from_model_with_anthropic_auth(model, None)
    }

    /// Construct a `ProviderClient` from a model string, optionally with an explicit
    /// Anthropic `AuthSource` (e.g. a bearer token loaded from a config file).
    ///
    /// - `model` — raw model string, may be a short alias.
    /// - `anthropic_auth` — if `Some`, bypasses `ANTHROPIC_API_KEY` env-var lookup.
    pub fn from_model_with_anthropic_auth(
        model: &str,
        anthropic_auth: Option<AuthSource>,
    ) -> Result<Self, ApiError> {
        // Expand short model aliases ("opus" → "claude-opus-4-6", etc.).
        let resolved_model = providers::resolve_model_alias(model);

        // Route to the correct backend based on the resolved model string.
        match providers::detect_provider_kind(&resolved_model) {
            ProviderKind::Anthropic => Ok(Self::Anthropic(match anthropic_auth {
                // Caller supplied explicit auth — use it directly.
                Some(auth) => AnthropicClient::from_auth(auth),
                // No explicit auth — read from ANTHROPIC_API_KEY / ANTHROPIC_AUTH_TOKEN.
                None => AnthropicClient::from_env()?,
            })),

            ProviderKind::Xai => Ok(Self::Xai(OpenAiCompatClient::from_env(
                // xAI uses the `grok-*` model family; route to api.x.ai.
                OpenAiCompatConfig::xai(),
            )?)),

            ProviderKind::OpenAi => {
                // DashScope models (qwen-*) also return ProviderKind::OpenAi because they
                // speak the OpenAI wire format, but they need the DashScope config which
                // reads DASHSCOPE_API_KEY and points at dashscope.aliyuncs.com.
                //
                // Check provider metadata to detect DashScope before falling back to the
                // standard OpenAI config.
                let config = match providers::metadata_for_model(&resolved_model) {
                    // Model metadata says it uses DASHSCOPE_API_KEY — use the DashScope config.
                    Some(meta) if meta.auth_env == "DASHSCOPE_API_KEY" => {
                        OpenAiCompatConfig::dashscope()
                    }
                    // All other OpenAI-compatible models use the standard openai config.
                    _ => OpenAiCompatConfig::openai(),
                };
                Ok(Self::OpenAi(OpenAiCompatClient::from_env(config)?))
            }
        }
    }

    /// Returns which provider kind backs this client instance.
    ///
    /// Useful for diagnostics and for conditional behaviour that legitimately differs
    /// by provider (e.g. prompt-cache support is Anthropic-only).
    #[must_use]
    pub const fn provider_kind(&self) -> ProviderKind {
        match self {
            Self::Anthropic(_) => ProviderKind::Anthropic, // Native Anthropic endpoint.
            Self::Xai(_) => ProviderKind::Xai,             // xAI/Grok endpoint.
            Self::OpenAi(_) => ProviderKind::OpenAi,       // Generic OpenAI-compatible endpoint.
        }
    }

    /// Attach a [`PromptCache`] to this client (Anthropic-only; no-op for other providers).
    ///
    /// Prompt caching injects `cache_control` breakpoints into the system prompt and
    /// initial messages so the provider can reuse computed KV cache across turns,
    /// reducing latency and cost for long-context sessions.
    #[must_use]
    pub fn with_prompt_cache(self, prompt_cache: PromptCache) -> Self {
        match self {
            // Only the Anthropic client implements prompt caching.
            Self::Anthropic(client) => Self::Anthropic(client.with_prompt_cache(prompt_cache)),
            // xAI and OpenAI-compat clients don't support prompt caching — return unchanged.
            other => other,
        }
    }

    /// Returns current prompt-cache statistics, if the client supports caching.
    ///
    /// Always `None` for xAI and OpenAI-compatible clients.
    #[must_use]
    pub fn prompt_cache_stats(&self) -> Option<PromptCacheStats> {
        match self {
            Self::Anthropic(client) => client.prompt_cache_stats(), // Delegate to Anthropic client.
            Self::Xai(_) | Self::OpenAi(_) => None, // No cache support for these providers.
        }
    }

    /// Takes (removes and returns) the most recent prompt-cache record.
    ///
    /// Used by `ConversationRuntime` to emit a `PromptCacheEvent` after each turn.
    /// Always `None` for xAI and OpenAI-compatible clients.
    #[must_use]
    pub fn take_last_prompt_cache_record(&self) -> Option<PromptCacheRecord> {
        match self {
            Self::Anthropic(client) => client.take_last_prompt_cache_record(), // Delegate.
            Self::Xai(_) | Self::OpenAi(_) => None, // No cache record for these providers.
        }
    }

    /// Send a blocking (non-streaming) message request and return the full response.
    ///
    /// Internally, the Anthropic client uses the non-streaming `/v1/messages` path.
    /// OpenAI-compatible clients use `/chat/completions` with `stream: false`.
    pub async fn send_message(
        &self,
        request: &MessageRequest, // The outgoing request payload.
    ) -> Result<MessageResponse, ApiError> {
        match self {
            Self::Anthropic(client) => client.send_message(request).await,
            // xAI and generic OpenAI clients share the same `OpenAiCompatClient` impl.
            Self::Xai(client) | Self::OpenAi(client) => client.send_message(request).await,
        }
    }

    /// Begin streaming a message request, returning a [`MessageStream`] handle.
    ///
    /// The caller drives the stream by calling [`MessageStream::next_event`] in a loop
    /// until it returns `Ok(None)` (stream complete) or `Err` (stream error).
    pub async fn stream_message(
        &self,
        request: &MessageRequest, // The outgoing request payload; `stream: true` will be set.
    ) -> Result<MessageStream, ApiError> {
        match self {
            // Wrap the Anthropic-specific stream in the unified enum variant.
            Self::Anthropic(client) => client
                .stream_message(request)
                .await
                .map(MessageStream::Anthropic),
            // Both xAI and generic OpenAI use the same OpenAI-compat stream implementation.
            Self::Xai(client) | Self::OpenAi(client) => client
                .stream_message(request)
                .await
                .map(MessageStream::OpenAiCompat),
        }
    }
}

/// A live streaming response handle.
///
/// Created by [`ProviderClient::stream_message`]. The caller polls it with
/// [`next_event`] until the stream is exhausted or an error occurs.
#[derive(Debug)]
pub enum MessageStream {
    /// Stream from the native Anthropic client.
    Anthropic(anthropic::MessageStream),
    /// Stream from an OpenAI-compatible client (xAI or generic).
    OpenAiCompat(openai_compat::MessageStream),
}

impl MessageStream {
    /// Returns the provider-assigned request ID for this streaming response, if available.
    ///
    /// The request ID is extracted from the `x-request-id` (Anthropic) or `x-request-id`
    /// (OpenAI) response header and is useful for correlating log entries with provider
    /// support tickets.
    #[must_use]
    pub fn request_id(&self) -> Option<&str> {
        match self {
            Self::Anthropic(stream) => stream.request_id(),     // From Anthropic response headers.
            Self::OpenAiCompat(stream) => stream.request_id(),  // From OpenAI response headers.
        }
    }

    /// Pull the next SSE event from the stream.
    ///
    /// Returns:
    /// - `Ok(Some(event))` — another event is available.
    /// - `Ok(None)` — the stream has ended cleanly (all events consumed).
    /// - `Err(ApiError)` — a network or parse error occurred.
    pub async fn next_event(&mut self) -> Result<Option<StreamEvent>, ApiError> {
        match self {
            Self::Anthropic(stream) => stream.next_event().await,     // Decode Anthropic SSE.
            Self::OpenAiCompat(stream) => stream.next_event().await,  // Decode OpenAI SSE.
        }
    }
}

// ── Convenience re-exports from the Anthropic provider ───────────────────────

/// Re-export OAuth helpers so callers can import from `api` rather than
/// reaching into the internal `providers::anthropic` module.
pub use anthropic::{
    oauth_token_is_expired,       // True if the stored OAuth access token has expired.
    resolve_saved_oauth_token,    // Load a cached OAuth token from disk.
    resolve_startup_auth_source,  // Determine auth source (API key vs. OAuth) at startup.
    OAuthTokenSet,                // OAuth access + refresh token bundle with expiry.
};

/// Read the Anthropic base URL from `ANTHROPIC_BASE_URL` env-var, or return the
/// production default (`https://api.anthropic.com`).
#[must_use]
pub fn read_base_url() -> String {
    anthropic::read_base_url() // Delegates to the Anthropic provider module.
}

/// Read the xAI base URL from `XAI_BASE_URL` env-var, or return the
/// production default (`https://api.x.ai`).
#[must_use]
pub fn read_xai_base_url() -> String {
    openai_compat::read_base_url(OpenAiCompatConfig::xai()) // Delegates to the OpenAI-compat module with xAI config.
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use std::sync::{Mutex, OnceLock};

    use super::ProviderClient;
    use crate::providers::{detect_provider_kind, resolve_model_alias, ProviderKind};

    /// Serializes every test in this module that mutates process-wide
    /// environment variables so concurrent test threads cannot observe
    /// each other's partially-applied state.
    fn env_lock() -> std::sync::MutexGuard<'static, ()> {
        // Use a `OnceLock<Mutex>` so the mutex is created exactly once per process.
        static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
        LOCK.get_or_init(|| Mutex::new(())) // Initialise the mutex on first access.
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner) // Recover from poisoned mutex.
    }

    #[test]
    fn resolves_existing_and_grok_aliases() {
        // Short "opus" alias must expand to the current default Opus model ID.
        assert_eq!(resolve_model_alias("opus"), "claude-opus-4-6");
        // "grok" should expand to the current default Grok model ID.
        assert_eq!(resolve_model_alias("grok"), "grok-3");
        // "grok-mini" should expand to the mini variant.
        assert_eq!(resolve_model_alias("grok-mini"), "grok-3-mini");
    }

    #[test]
    fn provider_detection_prefers_model_family() {
        // grok-3 must be routed to xAI, not Anthropic.
        assert_eq!(detect_provider_kind("grok-3"), ProviderKind::Xai);
        // claude-sonnet must be routed to Anthropic.
        assert_eq!(
            detect_provider_kind("claude-sonnet-4-6"),
            ProviderKind::Anthropic
        );
    }

    /// Snapshot-restore guard for a single environment variable.
    ///
    /// Captures the original value on construction, applies the requested override,
    /// and restores the original on drop — so tests leave the process env untouched
    /// even when they panic.
    struct EnvVarGuard {
        key: &'static str,                   // Name of the environment variable being guarded.
        original: Option<std::ffi::OsString>, // Original value before the test override.
    }

    impl EnvVarGuard {
        /// Apply `value` to `key`, capturing the old value for restoration.
        /// Pass `None` for `value` to unset the variable.
        fn set(key: &'static str, value: Option<&str>) -> Self {
            let original = std::env::var_os(key); // Capture the current value (may be None).
            match value {
                Some(value) => std::env::set_var(key, value), // Set the override.
                None => std::env::remove_var(key),            // Unset the variable.
            }
            Self { key, original } // Return the guard so it can restore on drop.
        }
    }

    impl Drop for EnvVarGuard {
        /// Restore the original environment variable value when the guard goes out of scope.
        fn drop(&mut self) {
            match self.original.take() {
                Some(value) => std::env::set_var(self.key, value), // Restore previous value.
                None => std::env::remove_var(self.key),            // Variable wasn't set before; remove.
            }
        }
    }

    #[test]
    fn dashscope_model_uses_dashscope_config_not_openai() {
        // Regression: qwen-plus was being routed to OpenAiCompatConfig::openai()
        // which reads OPENAI_API_KEY and points at api.openai.com, when it should
        // use OpenAiCompatConfig::dashscope() which reads DASHSCOPE_API_KEY and
        // points at dashscope.aliyuncs.com.

        // Acquire the env-var mutex to prevent interference from other tests.
        let _lock = env_lock();
        // Provide a fake DashScope API key so the client can be constructed.
        let _dashscope = EnvVarGuard::set("DASHSCOPE_API_KEY", Some("test-dashscope-key"));
        // Ensure OPENAI_API_KEY is absent so we'd get a clear error if routing is wrong.
        let _openai = EnvVarGuard::set("OPENAI_API_KEY", None);

        // Attempt to build a client for a qwen-plus model.
        let client = ProviderClient::from_model("qwen-plus");

        // Must succeed (not fail with "missing OPENAI_API_KEY").
        assert!(
            client.is_ok(),
            "qwen-plus with DASHSCOPE_API_KEY set should build successfully, got: {:?}",
            client.err()
        );

        // Verify the constructed client points at the DashScope base URL, not api.openai.com.
        match client.unwrap() {
            ProviderClient::OpenAi(openai_client) => {
                assert!(
                    openai_client.base_url().contains("dashscope.aliyuncs.com"),
                    "qwen-plus should route to DashScope base URL (contains 'dashscope.aliyuncs.com'), got: {}",
                    openai_client.base_url()
                );
            }
            other => panic!("Expected ProviderClient::OpenAi for qwen-plus, got: {other:?}"),
        }
    }
}
