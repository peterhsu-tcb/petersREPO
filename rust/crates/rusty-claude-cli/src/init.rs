//! Project initialisation — `claw init`.
//!
//! Implements the `claw init` command, which bootstraps a new project with the
//! minimal set of files that Claw Code needs to work well:
//!
//! | Artifact | Purpose |
//! |----------|---------|
//! | `.claw/` | Directory for local session data, caches, and machine-local settings |
//! | `.claw.json` | Project-level configuration committed to the repo |
//! | `.gitignore` | Ensures machine-local artifacts are not accidentally committed |
//! | `CLAUDE.md` | Tailored guidance file for the AI agent, auto-generated from repo detection |
//!
//! The operation is idempotent — running `claw init` twice in the same directory
//! skips already-present files and directories without overwriting them.

use std::fs; // Standard library filesystem operations (create_dir_all, write, read_to_string).
use std::path::{Path, PathBuf}; // Path manipulation.

// ── Constant templates ────────────────────────────────────────────────────────

/// Starter `.claw.json` content written when none exists.
///
/// Sets `permissions.defaultMode` to `"dontAsk"` so new projects run without
/// interactive permission prompts by default.  Users can tighten this after init.
const STARTER_CLAW_JSON: &str = concat!(
    "{\n",
    "  \"permissions\": {\n",
    "    \"defaultMode\": \"dontAsk\"\n", // Allow all operations without prompting.
    "  }\n",
    "}\n",
);

/// Section comment written at the top of the `.gitignore` block for Claw Code artifacts.
const GITIGNORE_COMMENT: &str = "# Claw Code local artifacts";

/// Paths appended to `.gitignore` when they are not already present.
///
/// - `.claw/settings.local.json` — machine-local config overrides (API keys, etc.)
/// - `.claw/sessions/` — JSONL session history (can be large; not needed in source control)
/// - `.clawhip/` — Clawhip plugin cache directory
const GITIGNORE_ENTRIES: [&str; 3] = [".claw/settings.local.json", ".claw/sessions/", ".clawhip/"];

// ── Status types ──────────────────────────────────────────────────────────────

/// The outcome of attempting to create or update a single init artifact.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum InitStatus {
    /// The artifact did not exist and was created from scratch.
    Created,
    /// The artifact existed and was updated (e.g. new `.gitignore` entries were appended).
    Updated,
    /// The artifact already existed with the expected content; nothing was changed.
    Skipped,
}

impl InitStatus {
    /// Human-readable label used in the `claw init` text output.
    #[must_use]
    pub(crate) fn label(self) -> &'static str {
        match self {
            Self::Created => "created",                  // Newly created.
            Self::Updated => "updated",                  // Existing file was modified.
            Self::Skipped => "skipped (already exists)", // Nothing needed to change.
        }
    }

    /// Machine-stable identifier for structured JSON output.
    ///
    /// Unlike [`label`], this never changes wording — callers can `switch` on these
    /// values without brittle substring matching against the human label.
    #[must_use]
    pub(crate) fn json_tag(self) -> &'static str {
        match self {
            Self::Created => "created", // Bare word, never changes.
            Self::Updated => "updated", // Bare word, never changes.
            Self::Skipped => "skipped", // Note: `label()` says "skipped (already exists)" but json_tag is just "skipped".
        }
    }
}

// ── Report types ──────────────────────────────────────────────────────────────

/// A single file or directory that was created, updated, or skipped during `claw init`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct InitArtifact {
    /// Human-readable name of the artifact (e.g. `".claw/"` or `"CLAUDE.md"`).
    pub(crate) name: &'static str,
    /// What happened to this artifact during this init run.
    pub(crate) status: InitStatus,
}

/// The complete report produced by a single `claw init` run.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct InitReport {
    /// The directory that was initialised (the current working directory).
    pub(crate) project_root: PathBuf,
    /// All artifacts that were processed, in creation order.
    pub(crate) artifacts: Vec<InitArtifact>,
}

impl InitReport {
    /// Render a human-readable multi-line summary of the init run.
    ///
    /// Example output:
    /// ```text
    /// Init
    ///   Project          /home/user/myproject
    ///   .claw/           created
    ///   .claw.json       created
    ///   .gitignore       created
    ///   CLAUDE.md        created
    ///   Next step        Review and tailor the generated guidance
    /// ```
    #[must_use]
    pub(crate) fn render(&self) -> String {
        let mut lines = vec![
            "Init".to_string(),
            format!("  Project          {}", self.project_root.display()), // Show the initialised path.
        ];
        for artifact in &self.artifacts {
            // Left-pad the artifact name to 16 chars for alignment.
            lines.push(format!(
                "  {:<16} {}",
                artifact.name,
                artifact.status.label() // Human-readable status.
            ));
        }
        // Always append the "next step" hint at the end.
        lines.push("  Next step        Review and tailor the generated guidance".to_string());
        lines.join("\n") // Join with newlines (no trailing newline in the final string).
    }

    /// The constant "next step" string, for use in JSON output without
    /// parsing the human-formatted `message` field.
    pub(crate) const NEXT_STEP: &'static str = "Review and tailor the generated guidance";

    /// Return the names of all artifacts that ended with the given status.
    ///
    /// Used to build the structured `created[]`, `updated[]`, and `skipped[]`
    /// arrays in JSON output.
    #[must_use]
    pub(crate) fn artifacts_with_status(&self, status: InitStatus) -> Vec<String> {
        self.artifacts
            .iter()
            .filter(|artifact| artifact.status == status) // Keep only matching status.
            .map(|artifact| artifact.name.to_string())    // Extract the name as an owned String.
            .collect()
    }

    /// Build the structured artifact list for JSON output.
    ///
    /// Each entry is a JSON object with `name` (string) and `status` (machine-stable tag).
    #[must_use]
    pub(crate) fn artifact_json_entries(&self) -> Vec<serde_json::Value> {
        self.artifacts
            .iter()
            .map(|artifact| {
                serde_json::json!({
                    "name": artifact.name,           // The artifact file/directory name.
                    "status": artifact.status.json_tag(), // Machine-stable status tag.
                })
            })
            .collect()
    }
}

// ── Repo detection ────────────────────────────────────────────────────────────

/// Flags set after scanning the project directory for language/framework markers.
///
/// Used by `render_init_claude_md` to generate a tailored `CLAUDE.md`.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
#[allow(clippy::struct_excessive_bools)] // Many bool fields are expected here — each represents one detected marker.
struct RepoDetection {
    rust_workspace: bool,  // `rust/Cargo.toml` present — nested Rust workspace layout.
    rust_root: bool,       // `Cargo.toml` at repo root — single Rust project.
    python: bool,          // `pyproject.toml`, `requirements.txt`, or `setup.py` present.
    package_json: bool,    // `package.json` present — Node.js / JavaScript project.
    typescript: bool,      // `tsconfig.json` present OR `"typescript"` in `package.json`.
    nextjs: bool,          // `"next"` dependency in `package.json`.
    react: bool,           // `"react"` dependency in `package.json`.
    vite: bool,            // `"vite"` dependency in `package.json`.
    nest: bool,            // `"@nestjs"` dependency in `package.json`.
    src_dir: bool,         // `src/` directory present.
    tests_dir: bool,       // `tests/` directory present.
    rust_dir: bool,        // `rust/` directory present.
}

// ── Public entry point ────────────────────────────────────────────────────────

/// Initialise a project directory for use with Claw Code.
///
/// Creates (or updates) four artifacts in `cwd`:
/// 1. `.claw/` directory
/// 2. `.claw.json` project config (only if absent)
/// 3. `.gitignore` (created fresh or updated with Claw entries)
/// 4. `CLAUDE.md` (only if absent; auto-generated from repo detection)
///
/// Returns an [`InitReport`] describing what was created/updated/skipped.
/// Returns `Err` if any filesystem operation fails.
pub(crate) fn initialize_repo(cwd: &Path) -> Result<InitReport, Box<dyn std::error::Error>> {
    let mut artifacts = Vec::new(); // Accumulate artifact results in order.

    // 1. Ensure the `.claw/` directory exists.
    let claw_dir = cwd.join(".claw");
    artifacts.push(InitArtifact {
        name: ".claw/",
        status: ensure_dir(&claw_dir)?, // Create if missing; skip if present.
    });

    // 2. Write the starter `.claw.json` only if it doesn't already exist.
    let claw_json = cwd.join(".claw.json");
    artifacts.push(InitArtifact {
        name: ".claw.json",
        status: write_file_if_missing(&claw_json, STARTER_CLAW_JSON)?, // Idempotent write.
    });

    // 3. Ensure the required Claw entries are in `.gitignore`.
    let gitignore = cwd.join(".gitignore");
    artifacts.push(InitArtifact {
        name: ".gitignore",
        status: ensure_gitignore_entries(&gitignore)?, // Append missing entries; skip if all present.
    });

    // 4. Generate and write `CLAUDE.md` only if it doesn't already exist.
    let claude_md = cwd.join("CLAUDE.md");
    let content = render_init_claude_md(cwd); // Auto-generate from repo detection.
    artifacts.push(InitArtifact {
        name: "CLAUDE.md",
        status: write_file_if_missing(&claude_md, &content)?, // Idempotent write.
    });

    Ok(InitReport {
        project_root: cwd.to_path_buf(), // Record the directory that was initialised.
        artifacts,                        // Return all artifact results.
    })
}

// ── Filesystem helpers ────────────────────────────────────────────────────────

/// Ensure `path` is a directory, creating it (recursively) if it doesn't exist.
///
/// Returns `Skipped` if the directory already exists, `Created` if it was just made.
fn ensure_dir(path: &Path) -> Result<InitStatus, std::io::Error> {
    if path.is_dir() {
        return Ok(InitStatus::Skipped); // Already a directory — nothing to do.
    }
    fs::create_dir_all(path)?; // Create the directory (and any missing parents).
    Ok(InitStatus::Created)
}

/// Write `content` to `path` only if the file does not yet exist.
///
/// Returns `Skipped` if the file exists (regardless of its content), `Created` if written.
fn write_file_if_missing(path: &Path, content: &str) -> Result<InitStatus, std::io::Error> {
    if path.exists() {
        return Ok(InitStatus::Skipped); // File already present — do not overwrite.
    }
    fs::write(path, content)?; // Write the file from scratch.
    Ok(InitStatus::Created)
}

/// Ensure the required Claw entries are present in the `.gitignore` file.
///
/// - If the file doesn't exist, create it with the comment header and all entries.
/// - If it exists, append only the entries that are missing.
///
/// Returns `Created` (file was new), `Updated` (entries were appended), or
/// `Skipped` (all entries already present).
fn ensure_gitignore_entries(path: &Path) -> Result<InitStatus, std::io::Error> {
    if !path.exists() {
        // No .gitignore yet — write the section header followed by all entries.
        let mut lines = vec![GITIGNORE_COMMENT.to_string()]; // Start with the comment.
        lines.extend(GITIGNORE_ENTRIES.iter().map(|entry| (*entry).to_string())); // Append all entries.
        fs::write(path, format!("{}\n", lines.join("\n")))?; // Write with trailing newline.
        return Ok(InitStatus::Created);
    }

    // File exists — read it and check which entries are missing.
    let existing = fs::read_to_string(path)?; // Read current contents.
    let mut lines = existing.lines().map(ToOwned::to_owned).collect::<Vec<_>>(); // Split into lines.
    let mut changed = false; // Track whether we need to rewrite the file.

    // Append the section comment if it's not already in the file.
    if !lines.iter().any(|line| line == GITIGNORE_COMMENT) {
        lines.push(GITIGNORE_COMMENT.to_string()); // Add the comment header.
        changed = true;
    }

    // Append any missing entries.
    for entry in GITIGNORE_ENTRIES {
        if !lines.iter().any(|line| line == entry) {
            lines.push(entry.to_string()); // Append the missing entry.
            changed = true;
        }
    }

    if !changed {
        return Ok(InitStatus::Skipped); // All entries already present — nothing written.
    }

    // Rewrite the file with the appended entries.
    fs::write(path, format!("{}\n", lines.join("\n")))?;
    Ok(InitStatus::Updated)
}

// ── CLAUDE.md template generation ────────────────────────────────────────────

/// Generate the content of a `CLAUDE.md` guidance file tailored to the given directory.
///
/// Detection runs against `cwd` to identify the project's language(s), frameworks,
/// and directory structure.  The resulting file is a Markdown document with sections:
/// - Detected stack (languages + frameworks)
/// - Verification commands
/// - Repository shape
/// - Framework notes (if applicable)
/// - Working agreement (always present)
pub(crate) fn render_init_claude_md(cwd: &Path) -> String {
    // Probe the directory for language/framework markers.
    let detection = detect_repo(cwd);

    // Build the output lines list.
    let mut lines = vec![
        "# CLAUDE.md".to_string(),
        String::new(), // Blank line after the heading.
        "This file provides guidance to Claw Code (clawcode.dev) when working with code in this repository.".to_string(),
        String::new(), // Blank line before the first section.
    ];

    // ── Section: Detected stack ───────────────────────────────────────────────
    let detected_languages = detected_languages(&detection); // e.g. ["Rust", "Python"]
    let detected_frameworks = detected_frameworks(&detection); // e.g. ["Next.js", "React"]

    lines.push("## Detected stack".to_string());

    // Language list or a placeholder when nothing was detected.
    if detected_languages.is_empty() {
        lines.push("- No specific language markers were detected yet; document the primary language and verification commands once the project structure settles.".to_string());
    } else {
        lines.push(format!("- Languages: {}.", detected_languages.join(", ")));
    }

    // Framework list or a placeholder.
    if detected_frameworks.is_empty() {
        lines.push("- Frameworks: none detected from the supported starter markers.".to_string());
    } else {
        lines.push(format!(
            "- Frameworks/tooling markers: {}.",
            detected_frameworks.join(", ")
        ));
    }
    lines.push(String::new()); // Blank line after the section.

    // ── Section: Verification ─────────────────────────────────────────────────
    let verification_lines = verification_lines(cwd, &detection);
    if !verification_lines.is_empty() {
        lines.push("## Verification".to_string());
        lines.extend(verification_lines); // Append language-specific verification steps.
        lines.push(String::new());
    }

    // ── Section: Repository shape ─────────────────────────────────────────────
    let structure_lines = repository_shape_lines(&detection);
    if !structure_lines.is_empty() {
        lines.push("## Repository shape".to_string());
        lines.extend(structure_lines); // Append detected directory structure notes.
        lines.push(String::new());
    }

    // ── Section: Framework notes ──────────────────────────────────────────────
    let framework_lines = framework_notes(&detection);
    if !framework_lines.is_empty() {
        lines.push("## Framework notes".to_string());
        lines.extend(framework_lines); // Append framework-specific guidance.
        lines.push(String::new());
    }

    // ── Section: Working agreement ────────────────────────────────────────────
    // This section is always present regardless of what was detected.
    lines.push("## Working agreement".to_string());
    lines.push("- Prefer small, reviewable changes and keep generated bootstrap files aligned with actual repo workflows.".to_string());
    lines.push("- Keep shared defaults in `.claw.json`; reserve `.claw/settings.local.json` for machine-local overrides.".to_string());
    lines.push("- Do not overwrite existing `CLAUDE.md` content automatically; update it intentionally when repo workflows change.".to_string());
    lines.push(String::new()); // Trailing blank line.

    lines.join("\n") // Combine all lines into a single string.
}

// ── Detection helpers ─────────────────────────────────────────────────────────

/// Scan `cwd` for language/framework markers and return a [`RepoDetection`] struct.
fn detect_repo(cwd: &Path) -> RepoDetection {
    // Read and lowercase `package.json` contents once; reuse for multiple checks below.
    let package_json_contents = fs::read_to_string(cwd.join("package.json"))
        .unwrap_or_default()      // Returns empty string if the file doesn't exist.
        .to_ascii_lowercase();    // Lowercase so dependency name checks are case-insensitive.

    RepoDetection {
        // Nested Rust workspace: `rust/Cargo.toml` present.
        rust_workspace: cwd.join("rust").join("Cargo.toml").is_file(),
        // Root Rust project: `Cargo.toml` at the repo root.
        rust_root: cwd.join("Cargo.toml").is_file(),
        // Python project: one of the common Python project files.
        python: cwd.join("pyproject.toml").is_file()
            || cwd.join("requirements.txt").is_file()
            || cwd.join("setup.py").is_file(),
        // Node.js / JavaScript project: `package.json` present.
        package_json: cwd.join("package.json").is_file(),
        // TypeScript: explicit `tsconfig.json` OR `"typescript"` in dependencies.
        typescript: cwd.join("tsconfig.json").is_file()
            || package_json_contents.contains("typescript"),
        // Next.js: `"next"` dependency in `package.json`.
        nextjs: package_json_contents.contains("\"next\""),
        // React: `"react"` dependency in `package.json`.
        react: package_json_contents.contains("\"react\""),
        // Vite: `"vite"` dependency in `package.json`.
        vite: package_json_contents.contains("\"vite\""),
        // NestJS: `@nestjs` in `package.json`.
        nest: package_json_contents.contains("@nestjs"),
        // Source directory: `src/` present at repo root.
        src_dir: cwd.join("src").is_dir(),
        // Tests directory: `tests/` present at repo root.
        tests_dir: cwd.join("tests").is_dir(),
        // Rust subdirectory: `rust/` present at repo root.
        rust_dir: cwd.join("rust").is_dir(),
    }
}

/// Build the list of detected language names from the detection flags.
fn detected_languages(detection: &RepoDetection) -> Vec<&'static str> {
    let mut languages = Vec::new();
    if detection.rust_workspace || detection.rust_root {
        languages.push("Rust"); // Either layout counts as a Rust project.
    }
    if detection.python {
        languages.push("Python"); // At least one Python project file found.
    }
    // Prefer "TypeScript" over "JavaScript/Node.js" when TypeScript markers are found.
    if detection.typescript {
        languages.push("TypeScript");
    } else if detection.package_json {
        languages.push("JavaScript/Node.js"); // Plain JS project (no TypeScript detected).
    }
    languages
}

/// Build the list of detected framework names from the detection flags.
fn detected_frameworks(detection: &RepoDetection) -> Vec<&'static str> {
    let mut frameworks = Vec::new();
    if detection.nextjs {
        frameworks.push("Next.js"); // Next.js supersedes React as the framework name.
    }
    if detection.react {
        frameworks.push("React"); // React detected (may overlap with Next.js).
    }
    if detection.vite {
        frameworks.push("Vite"); // Vite build tool.
    }
    if detection.nest {
        frameworks.push("NestJS"); // NestJS backend framework.
    }
    frameworks
}

/// Build language-specific verification command lines for the `## Verification` section.
fn verification_lines(cwd: &Path, detection: &RepoDetection) -> Vec<String> {
    let mut lines = Vec::new();

    // Rust workspace (nested under `rust/`) uses different paths than a root Cargo project.
    if detection.rust_workspace {
        lines.push("- Run Rust verification from `rust/`: `cargo fmt`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`".to_string());
    } else if detection.rust_root {
        lines.push("- Run Rust verification from the repo root: `cargo fmt`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`".to_string());
    }

    if detection.python {
        // Distinguish between projects using `pyproject.toml` (modern) and older layouts.
        if cwd.join("pyproject.toml").is_file() {
            lines.push("- Run the Python project checks declared in `pyproject.toml` (for example: `pytest`, `ruff check`, and `mypy` when configured).".to_string());
        } else {
            lines.push(
                "- Run the repo's Python test/lint commands before shipping changes.".to_string(),
            );
        }
    }

    if detection.package_json {
        lines.push("- Run the JavaScript/TypeScript checks from `package.json` before shipping changes (`npm test`, `npm run lint`, `npm run build`, or the repo equivalent).".to_string());
    }

    // When both `src/` and `tests/` exist, remind the agent to keep them in sync.
    if detection.tests_dir && detection.src_dir {
        lines.push("- `src/` and `tests/` are both present; update both surfaces together when behavior changes.".to_string());
    }

    lines
}

/// Build repository-shape notes for the `## Repository shape` section.
fn repository_shape_lines(detection: &RepoDetection) -> Vec<String> {
    let mut lines = Vec::new();
    if detection.rust_dir {
        lines.push(
            "- `rust/` contains the Rust workspace and active CLI/runtime implementation."
                .to_string(),
        );
    }
    if detection.src_dir {
        lines.push("- `src/` contains source files that should stay consistent with generated guidance and tests.".to_string());
    }
    if detection.tests_dir {
        lines.push("- `tests/` contains validation surfaces that should be reviewed alongside code changes.".to_string());
    }
    lines
}

/// Build framework-specific notes for the `## Framework notes` section.
fn framework_notes(detection: &RepoDetection) -> Vec<String> {
    let mut lines = Vec::new();
    if detection.nextjs {
        lines.push("- Next.js detected: preserve routing/data-fetching conventions and verify production builds after changing app structure.".to_string());
    }
    // Only emit the plain React note when Next.js wasn't detected; otherwise it's redundant.
    if detection.react && !detection.nextjs {
        lines.push("- React detected: keep component behavior covered with focused tests and avoid unnecessary prop/API churn.".to_string());
    }
    if detection.vite {
        lines.push("- Vite detected: validate the production bundle after changing build-sensitive configuration or imports.".to_string());
    }
    if detection.nest {
        lines.push("- NestJS detected: keep module/provider boundaries explicit and verify controller/service wiring after refactors.".to_string());
    }
    lines
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::{initialize_repo, render_init_claude_md, InitStatus};
    use std::fs;
    use std::path::Path;
    use std::time::{SystemTime, UNIX_EPOCH};

    /// Create a unique temporary directory for each test to avoid conflicts.
    fn temp_dir() -> std::path::PathBuf {
        // Use nanoseconds since epoch to generate a unique suffix.
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("time should be after epoch")
            .as_nanos();
        std::env::temp_dir().join(format!("rusty-claude-init-{nanos}")) // e.g. /tmp/rusty-claude-init-1234567890
    }

    #[test]
    fn initialize_repo_creates_expected_files_and_gitignore_entries() {
        // Set up a temp directory that looks like a Rust workspace.
        let root = temp_dir();
        fs::create_dir_all(root.join("rust")).expect("create rust dir"); // Simulate the `rust/` subdirectory.
        fs::write(root.join("rust").join("Cargo.toml"), "[workspace]\n").expect("write cargo"); // Marker for Rust detection.

        // Run claw init.
        let report = initialize_repo(&root).expect("init should succeed");
        let rendered = report.render();

        // Verify all expected artifacts appear in the human-readable output.
        assert!(rendered.contains(".claw/"));
        assert!(rendered.contains(".claw.json"));
        assert!(rendered.contains("created"));
        assert!(rendered.contains(".gitignore       created"));
        assert!(rendered.contains("CLAUDE.md        created"));

        // Verify the files/dirs were actually created on disk.
        assert!(root.join(".claw").is_dir());
        assert!(root.join(".claw.json").is_file());
        assert!(root.join("CLAUDE.md").is_file());

        // Verify the starter `.claw.json` content is correct.
        assert_eq!(
            fs::read_to_string(root.join(".claw.json")).expect("read claw json"),
            concat!(
                "{\n",
                "  \"permissions\": {\n",
                "    \"defaultMode\": \"dontAsk\"\n",
                "  }\n",
                "}\n",
            )
        );

        // Verify all required gitignore entries were written.
        let gitignore = fs::read_to_string(root.join(".gitignore")).expect("read gitignore");
        assert!(gitignore.contains(".claw/settings.local.json"));
        assert!(gitignore.contains(".claw/sessions/"));
        assert!(gitignore.contains(".clawhip/"));

        // Verify CLAUDE.md was auto-generated with Rust-specific content.
        let claude_md = fs::read_to_string(root.join("CLAUDE.md")).expect("read claude md");
        assert!(claude_md.contains("Languages: Rust.")); // Rust was detected.
        assert!(claude_md.contains("cargo clippy --workspace --all-targets -- -D warnings")); // Rust verification commands.

        fs::remove_dir_all(root).expect("cleanup temp dir");
    }

    #[test]
    fn initialize_repo_is_idempotent_and_preserves_existing_files() {
        let root = temp_dir();
        fs::create_dir_all(&root).expect("create root");
        // Pre-create CLAUDE.md with custom content that must NOT be overwritten.
        fs::write(root.join("CLAUDE.md"), "custom guidance\n").expect("write existing claude md");
        // Pre-populate .gitignore with the first required entry.
        fs::write(root.join(".gitignore"), ".claw/settings.local.json\n").expect("write gitignore");

        // First run: CLAUDE.md and the partially-complete .gitignore should trigger skipped/updated.
        let first = initialize_repo(&root).expect("first init should succeed");
        assert!(first
            .render()
            .contains("CLAUDE.md        skipped (already exists)")); // Custom CLAUDE.md preserved.

        // Second run: everything should be skipped.
        let second = initialize_repo(&root).expect("second init should succeed");
        let second_rendered = second.render();
        assert!(second_rendered.contains(".claw/"));
        assert!(second_rendered.contains(".claw.json"));
        assert!(second_rendered.contains("skipped (already exists)"));
        assert!(second_rendered.contains(".gitignore       skipped (already exists)"));
        assert!(second_rendered.contains("CLAUDE.md        skipped (already exists)"));

        // Verify the custom CLAUDE.md was not overwritten.
        assert_eq!(
            fs::read_to_string(root.join("CLAUDE.md")).expect("read existing claude md"),
            "custom guidance\n"
        );

        // Verify no duplicate gitignore entries were written.
        let gitignore = fs::read_to_string(root.join(".gitignore")).expect("read gitignore");
        assert_eq!(gitignore.matches(".claw/settings.local.json").count(), 1); // Exactly once.
        assert_eq!(gitignore.matches(".claw/sessions/").count(), 1);
        assert_eq!(gitignore.matches(".clawhip/").count(), 1);

        fs::remove_dir_all(root).expect("cleanup temp dir");
    }

    #[test]
    fn artifacts_with_status_partitions_fresh_and_idempotent_runs() {
        // #142: the structured JSON output needs to be able to partition
        // artifacts into created/updated/skipped without substring matching
        // the human-formatted `message` string.
        let root = temp_dir();
        fs::create_dir_all(&root).expect("create root");

        // Fresh init: all four artifacts should be "created".
        let fresh = initialize_repo(&root).expect("fresh init should succeed");
        let created_names = fresh.artifacts_with_status(InitStatus::Created);
        assert_eq!(
            created_names,
            vec![
                ".claw/".to_string(),
                ".claw.json".to_string(),
                ".gitignore".to_string(),
                "CLAUDE.md".to_string(),
            ],
            "fresh init should place all four artifacts in created[]"
        );
        assert!(
            fresh.artifacts_with_status(InitStatus::Skipped).is_empty(),
            "fresh init should have no skipped artifacts"
        );

        // Idempotent init: all four artifacts should now be "skipped".
        let second = initialize_repo(&root).expect("second init should succeed");
        let skipped_names = second.artifacts_with_status(InitStatus::Skipped);
        assert_eq!(
            skipped_names,
            vec![
                ".claw/".to_string(),
                ".claw.json".to_string(),
                ".gitignore".to_string(),
                "CLAUDE.md".to_string(),
            ],
            "idempotent init should place all four artifacts in skipped[]"
        );
        assert!(
            second.artifacts_with_status(InitStatus::Created).is_empty(),
            "idempotent init should have no created artifacts"
        );

        // Verify that `artifact_json_entries()` uses the machine-stable `json_tag()`,
        // which never says "skipped (already exists)".
        let entries = second.artifact_json_entries();
        assert_eq!(entries.len(), 4); // All four artifacts returned.
        for entry in &entries {
            let status = entry.get("status").and_then(|v| v.as_str()).unwrap();
            assert_eq!(
                status, "skipped",
                "machine status tag should be the bare word 'skipped', not label()'s 'skipped (already exists)'"
            );
        }

        fs::remove_dir_all(root).expect("cleanup temp dir");
    }

    #[test]
    fn render_init_template_mentions_detected_python_and_nextjs_markers() {
        let root = temp_dir();
        fs::create_dir_all(&root).expect("create root");
        // Create a `pyproject.toml` to simulate a Python project.
        fs::write(root.join("pyproject.toml"), "[project]\nname = \"demo\"\n")
            .expect("write pyproject");
        // Create a `package.json` with Next.js + React + TypeScript dependencies.
        fs::write(
            root.join("package.json"),
            r#"{"dependencies":{"next":"14.0.0","react":"18.0.0"},"devDependencies":{"typescript":"5.0.0"}}"#,
        )
        .expect("write package json");

        let rendered = render_init_claude_md(Path::new(&root));

        // Verify that all detected markers appear in the rendered CLAUDE.md.
        assert!(rendered.contains("Languages: Python, TypeScript.")); // Both detected.
        assert!(rendered.contains("Frameworks/tooling markers: Next.js, React.")); // Both detected.
        assert!(rendered.contains("pyproject.toml")); // Python verification hint.
        assert!(rendered.contains("Next.js detected")); // Framework note present.

        fs::remove_dir_all(root).expect("cleanup temp dir");
    }
}
