//! REPL line-editor — wraps `rustyline` for interactive input.
//!
//! This module provides [`LineEditor`], which handles all interactive input in
//! the Claw Code REPL.  Key features:
//!
//! - **Slash-command tab completion** — pressing Tab after a `/` prefix completes
//!   to known slash commands or their arguments.
//! - **Emacs key bindings** — the default editing mode matches what most terminal
//!   users expect (`Ctrl-A`, `Ctrl-E`, `Ctrl-K`, etc.).
//! - **Multi-line input** — `Ctrl-J` or `Shift-Enter` inserts a newline without
//!   submitting the input, enabling multi-line prompts.
//! - **History** — prior inputs are added to an in-memory `rustyline` history
//!   buffer and available via the Up/Down arrow keys.
//! - **Non-terminal fallback** — when stdin/stdout are not a TTY (e.g. piped
//!   input), `LineEditor` falls back to a plain `read_line()` call.
//!
//! # Usage
//!
//! ```rust,ignore
//! let mut editor = LineEditor::new("> ", completions);
//! loop {
//!     match editor.read_line()? {
//!         ReadOutcome::Submit(line) => { /* process the line */ }
//!         ReadOutcome::Cancel       => { /* user pressed Ctrl-C mid-input */ }
//!         ReadOutcome::Exit         => break,
//!     }
//! }
//! ```

use std::borrow::Cow; // Zero-copy string wrapper used by the rustyline Highlighter trait.
use std::cell::RefCell; // Interior-mutability cell for tracking the current buffer inside callbacks.
use std::collections::BTreeSet; // Sorted, deduplicated set used for normalising completion candidates.
use std::io::{self, IsTerminal, Write}; // I/O traits for terminal detection and writing the fallback prompt.

use rustyline::completion::{Completer, Pair}; // Tab-completion trait and candidate type.
use rustyline::error::ReadlineError; // Error variants returned by `Editor::readline`.
use rustyline::highlight::{CmdKind, Highlighter}; // Syntax-highlighting trait (used to track the buffer).
use rustyline::hint::Hinter; // Inline hint trait (not used, but required by `Helper`).
use rustyline::history::DefaultHistory; // In-memory history backend.
use rustyline::validate::Validator; // Input-validation trait (not used, but required by `Helper`).
use rustyline::{
    Cmd,            // Named editor command (e.g. `Cmd::Newline`).
    CompletionType, // How to display completions (List vs. Circular).
    Config,         // Builder for rustyline configuration.
    Context,        // Provides access to history during completion.
    EditMode,       // Emacs vs. Vi key bindings.
    Editor,         // The main rustyline line-editor type.
    Helper,         // Marker trait that combines all the helper sub-traits.
    KeyCode,        // Raw key code (e.g. `KeyCode::Enter`).
    KeyEvent,       // A key event (key code + modifiers).
    Modifiers,      // Modifier keys (Ctrl, Shift, Meta, etc.).
};

// ── Result type ───────────────────────────────────────────────────────────────

/// The outcome of a single call to [`LineEditor::read_line`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReadOutcome {
    /// The user typed something and pressed Enter; the line content is the payload.
    Submit(String),
    /// The user pressed Ctrl-C while there was already some input in the buffer.
    ///
    /// This clears the current line without exiting — equivalent to "cancel this input".
    Cancel,
    /// The user pressed Ctrl-C on an empty line, or Ctrl-D (EOF).
    ///
    /// This signals the REPL should exit.
    Exit,
}

// ── rustyline helper ──────────────────────────────────────────────────────────

/// Internal `rustyline::Helper` implementation that provides:
/// - Tab-completion for slash commands and their arguments.
/// - Buffer tracking (to know whether the line is empty when Ctrl-C is pressed).
struct SlashCommandHelper {
    /// Normalised list of completion candidates (all start with `/`, deduplicated).
    completions: Vec<String>,
    /// The current contents of the editing buffer, kept in sync via [`Highlighter`] callbacks.
    current_line: RefCell<String>,
}

impl SlashCommandHelper {
    /// Create a new helper, normalising the provided completions.
    fn new(completions: Vec<String>) -> Self {
        Self {
            completions: normalize_completions(completions), // Deduplicate and filter non-`/` entries.
            current_line: RefCell::new(String::new()),       // Start with an empty buffer.
        }
    }

    /// Clear the tracked buffer (called at the start of each readline call).
    fn reset_current_line(&self) {
        self.current_line.borrow_mut().clear(); // Drop any stale content from the previous call.
    }

    /// Return a snapshot of the current buffer content.
    fn current_line(&self) -> String {
        self.current_line.borrow().clone() // Clone to avoid holding a borrow across the call boundary.
    }

    /// Replace the tracked buffer with `line`.
    ///
    /// Called from the [`Highlighter`] callbacks, which fire on every keystroke.
    fn set_current_line(&self, line: &str) {
        let mut current = self.current_line.borrow_mut(); // Acquire the interior mutable reference.
        current.clear();             // Wipe the previous content.
        current.push_str(line);      // Write the new buffer state.
    }

    /// Replace the current completion list with a new one.
    fn set_completions(&mut self, completions: Vec<String>) {
        self.completions = normalize_completions(completions); // Normalise and store.
    }
}

// ── Completer impl ────────────────────────────────────────────────────────────

impl Completer for SlashCommandHelper {
    type Candidate = Pair; // Completion candidate type: display string + replacement string.

    /// Provide tab-completion candidates for the current line at `pos`.
    ///
    /// Returns `(start_pos, candidates)`.  `start_pos` is always `0` because we
    /// replace the entire line rather than just a suffix.
    fn complete(
        &self,
        line: &str,     // Current buffer content.
        pos: usize,     // Cursor position within `line`.
        _ctx: &Context<'_>, // Provides history access (unused here).
    ) -> rustyline::Result<(usize, Vec<Self::Candidate>)> {
        // Only complete slash commands — bail early for non-`/` input.
        let Some(prefix) = slash_command_prefix(line, pos) else {
            return Ok((0, Vec::new())); // Not a slash prefix; return empty list.
        };

        // Filter the completion list to candidates that start with the current prefix.
        let matches = self
            .completions
            .iter()
            .filter(|candidate| candidate.starts_with(prefix)) // Prefix match.
            .map(|candidate| Pair {
                display: candidate.clone(),     // Text shown in the completion menu.
                replacement: candidate.clone(), // Text inserted when the candidate is selected.
            })
            .collect();

        Ok((0, matches)) // Replace from position 0 (the entire line).
    }
}

// ── Hinter, Highlighter, Validator, Helper impls ──────────────────────────────

impl Hinter for SlashCommandHelper {
    type Hint = String; // Inline hint type (not used — we don't produce inline hints).
    // Default `hint()` implementation returns `None`, which disables inline hinting.
}

impl Highlighter for SlashCommandHelper {
    /// Called on every keystroke with the current buffer content.
    ///
    /// We use this callback purely to keep `current_line` in sync with the buffer;
    /// we return the line unchanged (no ANSI highlighting applied here).
    fn highlight<'l>(&self, line: &'l str, _pos: usize) -> Cow<'l, str> {
        self.set_current_line(line); // Sync the tracked buffer.
        Cow::Borrowed(line)          // Return the line unchanged.
    }

    /// Called when deciding whether to re-render the line.
    ///
    /// Again used purely for buffer tracking; always returns `false` so we don't
    /// force unnecessary redraws.
    fn highlight_char(&self, line: &str, _pos: usize, _kind: CmdKind) -> bool {
        self.set_current_line(line); // Sync the tracked buffer.
        false                        // No character-level highlighting.
    }
}

impl Validator for SlashCommandHelper {} // No input validation — accept any input.
impl Helper for SlashCommandHelper {}    // Marker trait: this type implements all helper sub-traits.

// ── LineEditor ─────────────────────────────────────────────────────────────────

/// Interactive REPL line editor built on top of `rustyline`.
///
/// Wraps an `Editor<SlashCommandHelper, DefaultHistory>` with convenience methods
/// for the Claw Code REPL.
pub struct LineEditor {
    /// The prompt string printed before each input line (e.g. `"> "`).
    prompt: String,
    /// The underlying rustyline editor with our custom helper attached.
    editor: Editor<SlashCommandHelper, DefaultHistory>,
}

impl LineEditor {
    /// Create a new `LineEditor` with the given prompt and initial completion list.
    ///
    /// Sets up:
    /// - `CompletionType::List` — show all matches in a list rather than cycling.
    /// - `EditMode::Emacs` — Emacs key bindings (Ctrl-A, Ctrl-E, etc.).
    /// - `Ctrl-J` → `Newline` — insert a literal newline without submitting.
    /// - `Shift-Enter` → `Newline` — same as Ctrl-J (for terminals that send this).
    #[must_use]
    pub fn new(prompt: impl Into<String>, completions: Vec<String>) -> Self {
        // Build the rustyline configuration.
        let config = Config::builder()
            .completion_type(CompletionType::List) // Show all matches, don't cycle.
            .edit_mode(EditMode::Emacs)             // Standard Emacs key bindings.
            .build();

        // Construct the editor with our config.
        let mut editor = Editor::<SlashCommandHelper, DefaultHistory>::with_config(config)
            .expect("rustyline editor should initialize");

        // Attach our custom helper (completion + buffer tracking).
        editor.set_helper(Some(SlashCommandHelper::new(completions)));

        // Bind Ctrl-J to insert a literal newline (multi-line input without submitting).
        editor.bind_sequence(KeyEvent(KeyCode::Char('J'), Modifiers::CTRL), Cmd::Newline);
        // Bind Shift-Enter to the same action (some terminals encode it this way).
        editor.bind_sequence(KeyEvent(KeyCode::Enter, Modifiers::SHIFT), Cmd::Newline);

        Self {
            prompt: prompt.into(), // Store the prompt string.
            editor,
        }
    }

    /// Add `entry` to the readline history buffer.
    ///
    /// Blank entries (all whitespace) are silently ignored — they're not useful
    /// in history and would clutter the Up-arrow navigation.
    pub fn push_history(&mut self, entry: impl Into<String>) {
        let entry = entry.into();
        if entry.trim().is_empty() {
            return; // Ignore blank entries.
        }
        let _ = self.editor.add_history_entry(entry); // Best-effort; ignore the Result.
    }

    /// Replace the completion candidate list with `completions`.
    ///
    /// Call this when the available slash commands change (e.g. after loading plugins).
    pub fn set_completions(&mut self, completions: Vec<String>) {
        if let Some(helper) = self.editor.helper_mut() {
            helper.set_completions(completions); // Delegate to the helper.
        }
    }

    /// Read one line of input from the user.
    ///
    /// Dispatches to [`read_line_fallback`] when stdin or stdout is not a terminal,
    /// and to the full rustyline path otherwise.
    ///
    /// # Return values
    ///
    /// - `Ok(ReadOutcome::Submit(line))` — a non-empty line was entered.
    /// - `Ok(ReadOutcome::Cancel)` — Ctrl-C was pressed with input in the buffer.
    /// - `Ok(ReadOutcome::Exit)` — Ctrl-C on empty input, or Ctrl-D (EOF).
    /// - `Err(io::Error)` — a terminal I/O error occurred.
    pub fn read_line(&mut self) -> io::Result<ReadOutcome> {
        // When either stdin or stdout is not a TTY, skip rustyline and use the simple fallback.
        if !io::stdin().is_terminal() || !io::stdout().is_terminal() {
            return self.read_line_fallback();
        }

        // Reset the buffer tracker before each readline call.
        if let Some(helper) = self.editor.helper_mut() {
            helper.reset_current_line();
        }

        // Invoke rustyline's interactive readline.
        match self.editor.readline(&self.prompt) {
            Ok(line) => Ok(ReadOutcome::Submit(line)), // Normal input submitted.

            Err(ReadlineError::Interrupted) => {
                // Ctrl-C: distinguish "cancel current input" (buffer had text)
                // from "exit REPL" (buffer was empty).
                let has_input = !self.current_line().is_empty(); // Check buffer before clearing.
                self.finish_interrupted_read()?; // Clear the buffer and write a newline.
                if has_input {
                    Ok(ReadOutcome::Cancel) // Buffer had content — signal "cancel this input".
                } else {
                    Ok(ReadOutcome::Exit) // Buffer was empty — signal "exit the REPL".
                }
            }

            Err(ReadlineError::Eof) => {
                // Ctrl-D (EOF): always signal exit.
                self.finish_interrupted_read()?; // Write a newline for clean terminal output.
                Ok(ReadOutcome::Exit)
            }

            Err(error) => Err(io::Error::other(error)), // Wrap other rustyline errors as I/O errors.
        }
    }

    /// Return the current buffer content from the helper's tracker.
    fn current_line(&self) -> String {
        self.editor
            .helper()
            .map_or_else(String::new, SlashCommandHelper::current_line) // Default to empty if no helper.
    }

    /// Reset the buffer tracker and emit a newline to move past the interrupted prompt.
    fn finish_interrupted_read(&mut self) -> io::Result<()> {
        if let Some(helper) = self.editor.helper_mut() {
            helper.reset_current_line(); // Clear the stale buffer state.
        }
        let mut stdout = io::stdout();
        writeln!(stdout) // Print a newline so the next prompt appears on a fresh line.
    }

    /// Non-interactive fallback: print the prompt and read one line from stdin.
    ///
    /// Used when stdin or stdout is not a TTY (e.g. piped input in automation).
    /// Returns `Exit` on EOF (zero bytes read).
    fn read_line_fallback(&self) -> io::Result<ReadOutcome> {
        let mut stdout = io::stdout();
        write!(stdout, "{}", self.prompt)?; // Print the prompt without a newline.
        stdout.flush()?; // Ensure the prompt is visible before blocking on stdin.

        let mut buffer = String::new();
        let bytes_read = io::stdin().read_line(&mut buffer)?; // Block until newline or EOF.
        if bytes_read == 0 {
            return Ok(ReadOutcome::Exit); // EOF — signal exit.
        }

        // Strip the trailing newline(s) from the input.
        while matches!(buffer.chars().last(), Some('\n' | '\r')) {
            buffer.pop(); // Remove `\n` and `\r` from the end.
        }
        Ok(ReadOutcome::Submit(buffer)) // Return the trimmed line.
    }
}

// ── Helper functions ──────────────────────────────────────────────────────────

/// Extract the slash-command prefix from `line` at cursor position `pos`.
///
/// Returns `Some(prefix)` if:
/// - The cursor is at the end of the buffer (`pos == line.len()`).
/// - The buffer starts with `/`.
///
/// Returns `None` otherwise (not a slash command, or cursor is not at end).
fn slash_command_prefix(line: &str, pos: usize) -> Option<&str> {
    if pos != line.len() {
        return None; // Cursor is not at end of line — don't complete.
    }

    let prefix = &line[..pos]; // The text from the start up to the cursor.
    if !prefix.starts_with('/') {
        return None; // Not a slash command — don't complete.
    }

    Some(prefix) // Return the full slash-command prefix (e.g. "/he" or "/session sw").
}

/// Normalise a list of completion candidates:
/// 1. Remove any entries that don't start with `/` (invalid slash commands).
/// 2. Deduplicate using a `BTreeSet` (also sorts them, which is a nice bonus).
fn normalize_completions(completions: Vec<String>) -> Vec<String> {
    let mut seen = BTreeSet::new(); // Tracks which completions we've already yielded.
    completions
        .into_iter()
        .filter(|candidate| candidate.starts_with('/')) // Keep only slash commands.
        .filter(|candidate| seen.insert(candidate.clone())) // Remove duplicates.
        .collect()
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::{slash_command_prefix, LineEditor, SlashCommandHelper};
    use rustyline::completion::Completer;
    use rustyline::highlight::Highlighter;
    use rustyline::history::{DefaultHistory, History};
    use rustyline::Context;

    #[test]
    fn extracts_terminal_slash_command_prefixes_with_arguments() {
        // Cursor at end of a short prefix.
        assert_eq!(slash_command_prefix("/he", 3), Some("/he"));
        // Cursor at end of a prefix with a space-separated argument.
        assert_eq!(slash_command_prefix("/help me", 8), Some("/help me"));
        // Cursor at end of a longer prefix with multiple arguments.
        assert_eq!(
            slash_command_prefix("/session switch ses", 19),
            Some("/session switch ses")
        );
        // Non-slash input — should return None.
        assert_eq!(slash_command_prefix("hello", 5), None);
        // Cursor not at the end — should return None.
        assert_eq!(slash_command_prefix("/help", 2), None);
    }

    #[test]
    fn completes_matching_slash_commands() {
        // Set up a helper with three candidates.
        let helper = SlashCommandHelper::new(vec![
            "/help".to_string(),
            "/hello".to_string(),
            "/status".to_string(),
        ]);
        let history = DefaultHistory::new();
        let ctx = Context::new(&history);

        // "/he" should match "/help" and "/hello" but not "/status".
        let (start, matches) = helper
            .complete("/he", 3, &ctx)
            .expect("completion should work");

        assert_eq!(start, 0); // Replacement starts from position 0.
        assert_eq!(
            matches
                .into_iter()
                .map(|candidate| candidate.replacement)
                .collect::<Vec<_>>(),
            vec!["/help".to_string(), "/hello".to_string()]
        );
    }

    #[test]
    fn completes_matching_slash_command_arguments() {
        // Set up completions that include argument variants.
        let helper = SlashCommandHelper::new(vec![
            "/model".to_string(),
            "/model opus".to_string(),
            "/model sonnet".to_string(),
            "/session switch alpha".to_string(),
        ]);
        let history = DefaultHistory::new();
        let ctx = Context::new(&history);

        // "/model o" should only match "/model opus".
        let (start, matches) = helper
            .complete("/model o", 8, &ctx)
            .expect("completion should work");

        assert_eq!(start, 0);
        assert_eq!(
            matches
                .into_iter()
                .map(|candidate| candidate.replacement)
                .collect::<Vec<_>>(),
            vec!["/model opus".to_string()]
        );
    }

    #[test]
    fn ignores_non_slash_command_completion_requests() {
        let helper = SlashCommandHelper::new(vec!["/help".to_string()]);
        let history = DefaultHistory::new();
        let ctx = Context::new(&history);

        // "hello" (no leading slash) should produce no completions.
        let (_, matches) = helper
            .complete("hello", 5, &ctx)
            .expect("completion should work");

        assert!(matches.is_empty());
    }

    #[test]
    fn tracks_current_buffer_through_highlighter() {
        let helper = SlashCommandHelper::new(Vec::new());
        // Simulate the highlighter callback being called with "draft".
        let _ = helper.highlight("draft", 5);

        // The buffer tracker should now contain "draft".
        assert_eq!(helper.current_line(), "draft");
    }

    #[test]
    fn push_history_ignores_blank_entries() {
        let mut editor = LineEditor::new("> ", vec!["/help".to_string()]);
        editor.push_history("   "); // Whitespace-only — should be ignored.
        editor.push_history("/help"); // Valid entry — should be stored.

        // Only the non-blank entry should be in the history.
        assert_eq!(editor.editor.history().len(), 1);
    }

    #[test]
    fn set_completions_replaces_and_normalizes_candidates() {
        let mut editor = LineEditor::new("> ", vec!["/help".to_string()]);
        editor.set_completions(vec![
            "/model opus".to_string(),
            "/model opus".to_string(), // Duplicate — should be collapsed.
            "status".to_string(),      // No leading slash — should be filtered out.
        ]);

        // After normalisation: one unique slash command.
        let helper = editor.editor.helper().expect("helper should exist");
        assert_eq!(helper.completions, vec!["/model opus".to_string()]);
    }
}
