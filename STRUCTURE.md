# Claw Code — Structure Note

This document describes the architecture, crate layout, and key design decisions of the Claw Code Rust implementation found in [`rust/`](./rust/).

---

## Top-Level Repository Layout

```
petersREPO/
├── rust/                   # Canonical Rust workspace (the `claw` binary + all crates)
├── src/                    # Python/reference workspace and audit helpers
├── tests/                  # Parity-audit and validation test helpers
├── docs/                   # Supplemental documentation
│   ├── container.md        # Container-first workflow guide
│   └── MODEL_COMPATIBILITY.md
├── USAGE.md                # Task-oriented build/auth/session/parity guide
├── PARITY.md               # Rust-port parity checkpoint
├── ROADMAP.md              # Active roadmap and backlog
├── PHILOSOPHY.md           # Project intent and system-design framing
├── STRUCTURE.md            # This file
├── Containerfile           # OCI container build definition
└── install.sh              # Convenience install script
```

---

## Rust Workspace Layout

```
rust/
├── Cargo.toml              # Workspace root (declares all member crates)
├── Cargo.lock              # Locked dependency versions
├── crates/
│   ├── api/                # Provider clients, streaming, request/response types
│   ├── commands/           # Slash-command registry and help rendering
│   ├── compat-harness/     # TS-manifest extraction harness
│   ├── mock-anthropic-service/  # Deterministic local Anthropic-compatible mock
│   ├── plugins/            # Plugin metadata, install/enable/disable/update surfaces
│   ├── runtime/            # Session, config, permissions, MCP, prompt assembly, conversation loop
│   ├── rusty-claude-cli/   # Main CLI binary (`claw`)
│   ├── telemetry/          # Session tracing and usage telemetry types
│   └── tools/              # Built-in tool specs and execution engine
└── scripts/
    ├── run_mock_parity_harness.sh   # Reproducible clean-env parity harness wrapper
    └── run_mock_parity_diff.py      # Scenario checklist + PARITY mapping runner
```

---

## Crate Responsibilities

### `api`
**Role:** Provider-facing network layer.

- Defines all Anthropic/OpenAI-compatible request/response types (`MessageRequest`, `MessageResponse`, `StreamEvent`, etc.) in `types.rs`.
- Implements provider-specific HTTP clients (`AnthropicClient`, `OpenAiCompatClient`) and the unified `ProviderClient` enum in `client.rs`.
- Handles SSE (Server-Sent Events) streaming parsing in `sse.rs`.
- Implements prompt-cache logic (`PromptCache`, `PromptCacheRecord`, `PromptCacheStats`) in `prompt_cache.rs`.
- Builds and configures HTTP clients with proxy support in `http_client.rs`.
- Handles all API-level errors (`ApiError`) in `error.rs`.
- Re-exports telemetry types from the `telemetry` crate.

Key files:
```
api/src/
├── lib.rs           # Public re-export surface
├── client.rs        # ProviderClient enum (Anthropic, Xai, OpenAi)
├── types.rs         # MessageRequest, MessageResponse, StreamEvent, Usage, etc.
├── error.rs         # ApiError variants and display
├── http_client.rs   # Reqwest client builder with proxy config
├── prompt_cache.rs  # Prompt caching logic and stats
├── sse.rs           # SSE frame parser
└── providers/
    ├── mod.rs              # Provider detection, model aliases, metadata
    ├── anthropic.rs        # Anthropic-specific client and auth
    └── openai_compat.rs    # OpenAI-compatible client (Xai, DashScope, etc.)
```

---

### `commands`
**Role:** Slash-command registry used by the REPL and direct CLI subcommands.

- Defines all slash commands (`SlashCommand` structs) with their names, descriptions, and argument specs.
- Provides tab-completion candidate generation.
- Handles slash-command parsing, validation, and dispatch routing.
- Renders help text in both human-readable and JSON formats.
- Special-cases skill, agent, MCP, and plugin slash-command flows.

---

### `compat-harness`
**Role:** Extracts tool and prompt manifests from the upstream TypeScript source.

- Used to keep the Rust implementation in sync with the upstream TS surface.
- Reads upstream source paths defined in `UpstreamPaths` and produces structured manifests.
- Not part of the main runtime — used offline for parity audits.

---

### `mock-anthropic-service`
**Role:** Deterministic local Anthropic-compatible HTTP mock server.

- Implements `/v1/messages` with scripted response scenarios.
- Supports streaming and non-streaming response modes.
- Used by `rusty-claude-cli/tests/mock_parity_harness.rs` for end-to-end CLI parity checks.
- Scenarios are defined in `mock_parity_scenarios.json` at the workspace root.

Harness scenarios covered:
- `streaming_text`
- `read_file_roundtrip`
- `grep_chunk_assembly`
- `write_file_allowed` / `write_file_denied`
- `multi_tool_turn_roundtrip`
- `bash_stdout_roundtrip`
- `bash_permission_prompt_approved` / `bash_permission_prompt_denied`
- `plugin_tool_roundtrip`

---

### `plugins`
**Role:** Plugin metadata, lifecycle, and management surfaces.

- Defines `PluginMetadata`, `PluginRegistry`, and `PluginManager`.
- Handles plugin install/enable/disable/update flows.
- Exposes plugin tool definitions (plugins can contribute new tools).
- Integrates with the hook system (plugins can register lifecycle hooks).

---

### `runtime`
**Role:** Core session, config, permissions, MCP, and conversation loop.

This is the largest and most complex crate. Key submodules:

| Module | Responsibility |
|--------|----------------|
| `conversation` | `ConversationRuntime` — the main agentic turn loop driving multi-turn tool use |
| `config` | `RuntimeConfig`, `ConfigLoader` — `.claw.json` / `.claw/settings.json` loading and merging |
| `session` | `Session`, `ConversationMessage` — JSONL-based session persistence and resume |
| `permissions` | `PermissionPolicy`, `PermissionOutcome` — per-tool permission evaluation |
| `permission_enforcer` | Enforces permission decisions, prompts user for confirmation |
| `policy_engine` | `PolicyEngine`, `PolicyRule` — lane/workflow policy evaluation |
| `mcp_stdio` | `McpServerManager`, `McpStdioProcess` — MCP server process lifecycle |
| `mcp_client` | MCP client transport variants (stdio, remote, SDK, OAuth-managed proxy) |
| `mcp_lifecycle_hardened` | Degraded-mode handling and error surface for MCP lifecycle |
| `mcp_server` | `McpServer` — claw's own MCP server implementation |
| `mcp_tool_bridge` | Bridges MCP tools into claw's tool executor |
| `hooks` | `HookRunner` — lifecycle hook execution (pre/post tool, pre/post turn, etc.) |
| `prompt` | `SystemPromptBuilder`, `load_system_prompt` — system prompt assembly |
| `file_ops` | `read_file`, `write_file`, `edit_file`, `glob_search`, `grep_search` |
| `bash` | `execute_bash`, `BashCommandInput`, `BashCommandOutput` |
| `bash_validation` | Validates bash commands against allow/deny rules |
| `sandbox` | `SandboxConfig`, `SandboxStatus` — sandbox/container detection and config |
| `usage` | `UsageTracker`, `TokenUsage`, cost estimation |
| `git_context` | `GitContext` — reads git log for project context |
| `compact` | `compact_session` — session compaction / summarization |
| `oauth` | OAuth PKCE flow helpers for MCP-managed proxy auth |
| `remote` | `RemoteSessionContext` — upstream proxy session handling |
| `session_control` | `SessionStore` — session list, resume, fork |
| `worker_boot` | `Worker`, `WorkerRegistry` — sub-agent worker boot and registry |
| `task_registry` | `TaskRegistry` — background task registry |
| `recovery_recipes` | `RecoveryRecipe`, `attempt_recovery` — error recovery strategies |
| `branch_lock` | Branch-lock collision detection for concurrent lane work |
| `stale_base` / `stale_branch` | Stale commit and branch freshness detection |
| `summary_compression` | Session summary compression helpers |
| `lane_events` | `LaneEvent`, `LaneEventBuilder` — structured lane event system |
| `lsp_client` | Lightweight LSP client (diagnostics, hover, definitions) |
| `green_contract` | Green-contract validation (workspace health invariants) |
| `task_packet` | `TaskPacket` validation for structured agent task inputs |
| `team_cron_registry` | Cron/scheduled task registry for team automation |
| `bootstrap` | `BootstrapPlan` — project bootstrap plan generation |
| `sse` | `IncrementalSseParser` — SSE stream parser for streaming responses |
| `trust_resolver` | `TrustResolver` — worker trust evaluation (test-only) |

---

### `rusty-claude-cli`
**Role:** Main CLI binary (`claw`).

This crate wires everything together into the user-facing `claw` executable.

Key files:
```
rusty-claude-cli/src/
├── main.rs    # CLI argument parsing, REPL, one-shot prompt, all subcommands
├── render.rs  # Markdown terminal rendering, spinner, color theme, syntax highlighting
├── input.rs   # REPL line editor (rustyline), tab completion, readline handling
└── init.rs    # `claw init` — project initialization (CLAUDE.md, .claw.json, .gitignore)
```

**`main.rs`** is the hub. It contains:
- `main()` / `run()` — CLI entry point and top-level dispatch
- Argument parsing (manual `argv` scanning, not a parser library)
- `run_repl()` — interactive REPL loop
- `run_one_shot()` — non-interactive single-prompt mode
- Subcommand handlers: `status`, `sandbox`, `acp`, `agents`, `mcp`, `skills`, `doctor`, `dump-manifests`, `bootstrap-plan`, `init`, `system-prompt`, `version`
- Slash-command dispatch inside the REPL
- Tool call rendering and streaming display logic
- Session resume, fork, and compaction logic
- Permission prompt handling
- MCP server lifecycle management wiring

**`render.rs`** handles terminal output:
- `TerminalRenderer` — stateful Markdown-to-ANSI renderer (headings, code blocks, tables, emphasis, links)
- `MarkdownStreamState` — incremental streaming Markdown state machine
- `Spinner` — animated terminal spinner (braille dots) for async waits
- `ColorTheme` — configurable ANSI color palette
- Syntax highlighting via `syntect` and `pulldown-cmark`

**`input.rs`** handles REPL input:
- `LineEditor` — wraps `rustyline` with slash-command tab completion
- `SlashCommandHelper` — implements `rustyline::Helper` for completion and highlighting
- `ReadOutcome` — result of a readline call (Submit, Cancel, Exit)
- Handles both terminal (interactive) and non-terminal (piped) input modes

**`init.rs`** handles project initialization:
- `initialize_repo()` — creates `.claw/`, `.claw.json`, `.gitignore` entries, and `CLAUDE.md`
- `render_init_claude_md()` — generates a tailored `CLAUDE.md` by detecting the repo's language/framework stack
- `InitReport`, `InitArtifact`, `InitStatus` — structured results for both human and JSON output

---

### `telemetry`
**Role:** Session tracing and usage telemetry types.

- Defines `TelemetryEvent`, `SessionTraceRecord`, `SessionTracer`.
- Implements `TelemetrySink` trait with `JsonlTelemetrySink` and `MemoryTelemetrySink`.
- Provides `AnthropicRequestProfile` and `ClientIdentity` for request tracing.
- Referenced by `api` (re-exported) and `runtime`.

---

### `tools`
**Role:** Built-in tool specifications and execution engine.

Key contents:
- `lib.rs` — all built-in tool specs (`mvp_tool_specs()`), `execute_tool()`, `GlobalToolRegistry`, `RuntimeToolDefinition`, and the agent/sub-agent runtime surfaces
- `lane_completion.rs` — automatic lane completion detection via policy evaluation
- `pdf_extract.rs` — PDF text extraction support

Built-in tools:
| Tool | Description |
|------|-------------|
| `Bash` | Execute shell commands |
| `ReadFile` | Read file contents |
| `WriteFile` | Write/create files |
| `EditFile` | Patch files with string replacement |
| `GlobSearch` | Find files by glob pattern |
| `GrepSearch` | Search file contents by regex |
| `WebSearch` | Web search integration |
| `WebFetch` | Fetch web page content |
| `Agent` | Launch sub-agents |
| `TodoWrite` | Write/update todo lists |
| `NotebookEdit` | Edit Jupyter notebooks |
| `Skill` | Invoke installed skills |
| `ToolSearch` | Discover available tools |

---

## Data Flow: One-Shot Prompt

```
claw prompt "explain this"
        │
        ▼
   main() → run()
        │
        ▼
  parse_args() → RunMode::OneShot
        │
        ▼
  run_one_shot(config, runtime, ...)
        │
        ▼
  ConversationRuntime::run_turn()
        │
        ├─► SystemPromptBuilder::build()    # Assemble system prompt
        ├─► ProviderClient::stream_message() # Stream from Anthropic/OpenAI
        ├─► TerminalRenderer::render()       # Print streamed text to terminal
        └─► execute_tool() (loop)            # Execute tool calls from model
               │
               ├─► BashCommandInput / execute_bash()
               ├─► read_file / write_file / edit_file / glob_search / grep_search
               ├─► WebSearch / WebFetch
               └─► Agent (recursive sub-agent)
```

## Data Flow: REPL

```
claw [--model opus]
        │
        ▼
   run_repl(config, ...)
        │
        ▼
  LineEditor::read_line()   ← rustyline with slash-command tab completion
        │
        ├─► /slash-command → dispatch to handler (status, help, model, session, ...)
        └─► plain text → ConversationRuntime::run_turn() (same as one-shot)
```

---

## Configuration Hierarchy

Configuration is merged from multiple sources (highest priority first):

1. **CLI flags** (`--model`, `--permission-mode`, `--allowedTools`, etc.)
2. **Environment variables** (`ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL`, `ANTHROPIC_BASE_URL`, etc.)
3. **`.claw/settings.local.json`** — machine-local overrides (gitignored)
4. **`.claw.json`** — project-level config committed to the repo
5. **`~/.claw/settings.json`** — user-global config
6. **Built-in defaults** (`claude-opus-4-6`, `danger-full-access`, etc.)

---

## Session Persistence

Sessions are stored as newline-delimited JSON (`.jsonl`) files:

- Default location: `.claw/sessions/<session-id>.jsonl`
- Each line is a `ConversationMessage` (role + content blocks)
- Session compaction rewrites older turns with a summarized `[Compact]` message when context grows large
- `claw --resume latest` (or `--resume <session-id>`) restores the last session
- `SessionStore` manages listing, loading, forking, and pruning sessions

---

## Permission System

The permission system gates destructive operations (bash execution, file writes, etc.):

| Mode | Behavior |
|------|----------|
| `danger-full-access` | All tools allowed without prompting (default) |
| `default` | Prompts for write/execute operations |
| `plan-only` | Read-only; no writes or bash |

Per-tool allow/deny rules can be configured in `.claw.json` under `permissions.rules[]`.

---

## MCP (Model Context Protocol)

Claw Code implements both an MCP client and an MCP server:

- **Client:** connects to external MCP servers defined in `.claw.json` under `mcpServers`. Supports stdio, remote HTTP, OAuth-managed proxy, and SDK transports.
- **Server:** exposes claw's own tool surface as an MCP server for editor integrations (e.g., Zed). The ACP/Zed server entrypoint is not yet shipped; `claw acp` reports current status.

MCP tools discovered from connected servers are bridged into the tool executor via `mcp_tool_bridge.rs` and appear alongside built-in tools.

---

## Binary Name and Build

- **Binary:** `claw` (macOS/Linux) / `claw.exe` (Windows)
- **Build:** `cd rust && cargo build --workspace`
- **Install to PATH:** `cargo install --path rust/crates/rusty-claude-cli --force`
- **Default model:** `claude-opus-4-6`
- **Default permissions:** `danger-full-access`
- **Workspace size:** ~20K lines of Rust across 9 crates

---

## Key External Dependencies

| Crate | Purpose |
|-------|---------|
| `tokio` | Async runtime |
| `reqwest` | HTTP client |
| `serde` / `serde_json` | JSON serialization |
| `rustyline` | REPL line editing with history |
| `crossterm` | Cross-platform terminal control |
| `pulldown-cmark` | Markdown parsing |
| `syntect` | Syntax highlighting |
| `clap` (indirect) | CLI argument parsing (some paths use manual parsing) |
| `anyhow` | Error handling |

---

*For task-oriented usage, see [`USAGE.md`](./USAGE.md). For the live command reference, run `claw --help`.*
