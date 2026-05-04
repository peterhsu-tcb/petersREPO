//! Lane completion detector — automatically marks lanes as completed when
//! a session finishes successfully with green tests and pushed code.
//!
//! # Background
//!
//! A "lane" in Claw Code's workflow model represents an in-progress unit of
//! work (e.g. a feature branch or a PR).  [`LaneContext`] tracks the health
//! of a lane (blocker status, review status, test greenness, etc.).
//!
//! Previously, `LaneContext::completed` was a passive flag that nothing
//! automatically set — it had to be set manually.  This module introduces
//! automatic completion detection: given the output from a finished agent
//! run and two boolean flags (tests green, code pushed), it determines
//! whether the lane should transition to `completed = true`.
//!
//! # Completion criteria (all must be met)
//!
//! 1. The agent's `output.error` is `None` (no error occurred).
//! 2. The agent's `output.status` is `"completed"` or `"finished"` (case-insensitive).
//! 3. The agent's `output.current_blocker` is `None` (no blocking issue).
//! 4. `test_green` is `true` (all tests passed).
//! 5. `has_pushed` is `true` (code was pushed to the remote).
//!
//! # Policy actions
//!
//! Once a lane is detected as complete, [`evaluate_completed_lane`] runs the
//! policy engine over it and returns the actions to take:
//! - `PolicyAction::CloseoutLane` — archive/close the lane.
//! - `PolicyAction::CleanupSession` — remove the local session state.

use runtime::{
    evaluate,       // Entry point for the policy engine — returns a list of triggered actions.
    LaneBlocker,    // Enum: None | Blocker(reason) — whether the lane has a blocking issue.
    LaneContext,    // Full context snapshot for a lane (green level, blocker, review status, etc.).
    PolicyAction,   // An action the policy engine recommends (CloseoutLane, CleanupSession, etc.).
    PolicyCondition, // A predicate tested against a `LaneContext` (LaneCompleted, GreenAt, etc.).
    PolicyEngine,   // Holds a set of rules and evaluates them against a context.
    PolicyRule,     // A single rule: condition → action with a priority weight.
    ReviewStatus,   // Enum: Approved | ChangesRequested | Pending | etc.
};

use crate::AgentOutput; // The output struct returned by a completed agent run.

// ── Lane completion detection ─────────────────────────────────────────────────

/// Detect whether a lane should be automatically marked as completed.
///
/// Checks all five completion criteria (see module docs) against `output`,
/// `test_green`, and `has_pushed`.
///
/// # Returns
///
/// - `Some(LaneContext)` with `completed = true` if all conditions are met.
/// - `None` if any condition fails (the lane stays active).
#[allow(dead_code)] // Used by the broader agent runtime surface; not always called directly in tests.
pub(crate) fn detect_lane_completion(
    output: &AgentOutput, // The output from the agent run to evaluate.
    test_green: bool,     // `true` if the test suite passed (workspace is green).
    has_pushed: bool,     // `true` if the branch was successfully pushed to the remote.
) -> Option<LaneContext> {
    // Criterion 1: No error occurred during the agent run.
    if output.error.is_some() {
        return None; // Error present — lane cannot be considered complete.
    }

    // Criterion 2: Agent status must be "completed" or "finished" (case-insensitive).
    if !output.status.eq_ignore_ascii_case("completed")
        && !output.status.eq_ignore_ascii_case("finished")
    {
        return None; // Agent didn't finish cleanly — lane not complete.
    }

    // Criterion 3: No active blocker on the lane.
    if output.current_blocker.is_some() {
        return None; // Still blocked — cannot complete.
    }

    // Criterion 4: All tests must be passing.
    if !test_green {
        return None; // Tests failed — lane not safe to close.
    }

    // Criterion 5: Code must have been pushed to the remote.
    if !has_pushed {
        return None; // Work exists only locally — lane not publishable yet.
    }

    // All conditions met — construct a completed LaneContext.
    Some(LaneContext {
        lane_id: output.agent_id.clone(), // Carry the agent's ID as the lane identifier.
        green_level: 3,                   // 3 = "workspace green" (all tests passing).
        branch_freshness: std::time::Duration::from_secs(0), // Fresh — just finished.
        blocker: LaneBlocker::None,       // No blocker (verified above).
        review_status: ReviewStatus::Approved, // Treat a finished push as implicitly approved.
        diff_scope: runtime::DiffScope::Scoped, // Scoped diff (only the lane's changes).
        completed: true,                  // This is the key flag being set.
        reconciled: false,                // Not yet reconciled with the upstream branch.
    })
}

// ── Policy evaluation ─────────────────────────────────────────────────────────

/// Evaluate policy rules for a completed lane and return the recommended actions.
///
/// Builds a two-rule `PolicyEngine` inline:
/// 1. **closeout-completed-lane** (priority 10): if the lane is completed AND
///    tests are at green level 3, trigger `CloseoutLane`.
/// 2. **cleanup-completed-session** (priority 5): if the lane is completed
///    (any green level), trigger `CleanupSession`.
///
/// Returns the list of `PolicyAction`s whose conditions were satisfied.
#[allow(dead_code)] // Called by the agent runtime surface.
pub(crate) fn evaluate_completed_lane(context: &LaneContext) -> Vec<PolicyAction> {
    // Construct a policy engine with two rules specific to lane completion.
    let engine = PolicyEngine::new(vec![
        // Rule 1: Full closeout — requires completed + workspace-green (level 3).
        PolicyRule::new(
            "closeout-completed-lane", // Unique rule identifier.
            PolicyCondition::And(vec![
                PolicyCondition::LaneCompleted,          // Lane must be marked complete.
                PolicyCondition::GreenAt { level: 3 },   // All tests must be green.
            ]),
            PolicyAction::CloseoutLane, // Action: archive/close the lane.
            10,                          // Priority weight (higher = evaluated first).
        ),
        // Rule 2: Session cleanup — only requires completed (no greenness requirement).
        PolicyRule::new(
            "cleanup-completed-session", // Unique rule identifier.
            PolicyCondition::LaneCompleted, // Lane just needs to be completed.
            PolicyAction::CleanupSession,   // Action: remove local session state.
            5,                               // Lower priority than the closeout rule.
        ),
    ]);

    // Run the policy engine and return the triggered actions.
    evaluate(&engine, context)
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*; // Import everything from the parent module under test.
    use runtime::{DiffScope, LaneBlocker};

    /// Build a fully-successful `AgentOutput` fixture for use in tests.
    fn test_output() -> AgentOutput {
        AgentOutput {
            agent_id: "test-lane-1".to_string(),           // Unique lane/agent identifier.
            name: "Test Agent".to_string(),                 // Display name.
            description: "Test".to_string(),               // Short description.
            subagent_type: None,                           // Not a sub-agent.
            model: None,                                   // Model not relevant for completion.
            status: "Finished".to_string(),               // Meets the "finished" criterion.
            output_file: "/tmp/test.output".to_string(),  // Path to the agent's output file.
            manifest_file: "/tmp/test.manifest".to_string(), // Path to the manifest.
            created_at: "2024-01-01T00:00:00Z".to_string(), // Creation timestamp.
            started_at: Some("2024-01-01T00:00:00Z".to_string()), // Start timestamp.
            completed_at: Some("2024-01-01T00:00:00Z".to_string()), // Completion timestamp.
            lane_events: vec![],   // No lane events in this simple fixture.
            derived_state: "working".to_string(), // Derived state label.
            current_blocker: None, // No active blocker — meets the blocker criterion.
            error: None,           // No error — meets the error criterion.
        }
    }

    #[test]
    fn detects_completion_when_all_conditions_met() {
        let output = test_output(); // All conditions satisfied by default.
        let result = detect_lane_completion(&output, true, true); // test_green=true, has_pushed=true.

        assert!(result.is_some()); // Should produce a completed context.
        let context = result.unwrap();
        assert!(context.completed);           // The `completed` flag must be set.
        assert_eq!(context.green_level, 3);  // Workspace-green level.
        assert_eq!(context.blocker, LaneBlocker::None); // No blocker on the completed lane.
    }

    #[test]
    fn no_completion_when_error_present() {
        let mut output = test_output();
        output.error = Some("Build failed".to_string()); // Inject an error.

        let result = detect_lane_completion(&output, true, true);
        assert!(result.is_none()); // Error present — must not complete.
    }

    #[test]
    fn no_completion_when_not_finished() {
        let mut output = test_output();
        output.status = "Running".to_string(); // Override status to non-terminal value.

        let result = detect_lane_completion(&output, true, true);
        assert!(result.is_none()); // Status not "completed" or "finished" — must not complete.
    }

    #[test]
    fn no_completion_when_tests_not_green() {
        let output = test_output();

        let result = detect_lane_completion(&output, false, true); // test_green=false.
        assert!(result.is_none()); // Tests failing — must not complete.
    }

    #[test]
    fn no_completion_when_not_pushed() {
        let output = test_output();

        let result = detect_lane_completion(&output, true, false); // has_pushed=false.
        assert!(result.is_none()); // Not pushed — must not complete.
    }

    #[test]
    fn evaluate_triggers_closeout_for_completed_lane() {
        // Build a context that satisfies both policy rules.
        let context = LaneContext {
            lane_id: "completed-lane".to_string(),
            green_level: 3,                               // Workspace-green — satisfies GreenAt { level: 3 }.
            branch_freshness: std::time::Duration::from_secs(0),
            blocker: LaneBlocker::None,
            review_status: ReviewStatus::Approved,
            diff_scope: DiffScope::Scoped,
            completed: true,   // Satisfies LaneCompleted.
            reconciled: false,
        };

        let actions = evaluate_completed_lane(&context);

        // Both rules should fire for this fully-green, completed lane.
        assert!(actions.contains(&PolicyAction::CloseoutLane));    // Closeout triggered.
        assert!(actions.contains(&PolicyAction::CleanupSession));  // Cleanup triggered.
    }
}
