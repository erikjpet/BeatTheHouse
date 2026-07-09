# Queue Order â€” maintained by the project manager

Agents told to "work on the todo list" (or similar) follow this protocol:

1. Read this file. Take the **first entry whose Status is `ready`** and whose
   Machine constraint matches where you are running.
2. Claim it: change its Status to `claimed (<date>, <machine/session>)`,
   commit and push this file **before** starting work, and pull first â€” if
   someone else claimed it in the meantime, take the next entry.
3. Execute the prompt per `RULES.md`, archive it to `docs/todone/` with an
   execution record, update this file (remove the entry), commit, push.
4. **Repeat from step 1** until no entry is `ready` for your machine, then
   report which entries remain and why they are blocked.

Never execute an entry marked `in-progress-elsewhere` or `blocked` â€” and
NEVER re-implement work a status note says already exists somewhere.

Last reviewed: 2026-07-07 by Codex for the v0.4 Act 1 completion plan.
`docs/plans/0.4_act1_completion_plan.md` is the current release path. The first
task must reconcile the existing dirty worktree and stale prompt/archive moves
before new feature work proceeds.

| # | Prompt | Status | Machine | Notes |
| --- | --- | --- | --- | --- |
| 0c | playtest_beach_placement_duplicate_objects_prompt.md | ready | PM machine | Playtest blockers: beach must always anchor 1 distance block from delta_queen with a direct edge (it currently falls through the anchor table to the hash fallback), and identity-carrying objects (clerks etc.) must be unique per environment via a data-driven uniqueness class (owner hit two pull-tab clerks). Adds seed-sweep guards to the generation audit. |
| 0d | CRITICAL_table_games_function_confirmation_prompt.md | blocked until #0c (shared machine/gates) | PM machine | **PLAYTEST BLOCKER — 5th appearance of the liveness regression class.** Bets failing to place; roulette wheel freezes between bet-completion animations and jumps on click (simulation advances, rendering doesn't — the 81111d9 fix missed animation-handoff windows and its guard passes while broken). Full-lifecycle liveness predicate + per-game function confirmation table + hardened guard that must fail pre-fix. |
| 0e | playtest_map_moves_on_selection_prompt.md | blocked until #0d (shared machine/gates) | PM machine | Playtest blocker: selecting a map node re-frames the whole map (suspect: selection feeds `map_focus_node_ids`, whose bounds drive the view window — world_map_canvas.gd:279-316). Selection must never move the view; adds a before/after window-stability guard. Applies to run and meta maps. |
| 0f | playtest_bankroll_spoiler_prompt.md | blocked until #0e (shared machine/gates) | PM machine | Playtest blocker: bankroll updates at bet settle (action time) instead of at result presentation, spoiling outcomes. Presentation-layer fix only — a presented-bankroll display value syncing at reveal boundaries; simulation/settle timing untouched (determinism). Stake deduction stays immediate; guard samples the bar mid-animation. |
| 9b | v04_repackage_after_playtest_fixes_prompt.md | blocked until #0b, #0c, #0d, #0e, and #0f (and any further owner playtest fixes) | PM machine | Re-runs the fix-affected release gates, re-exports both 0.4.0 packages, refreshes checklist hashes, and appends the Playtest Fix Addendum so the publish audit passes against the fixed tree. |
| 10 | v04_publish_and_tag_prompt.md | blocked until #9b; owner-launch only | PM machine (stored git credentials) | Owner decision 2026-07-08: NO new logins — publish uses existing git credentials only (push main + v0.4.0 tag, no gh Release, no butler). The itch upload is prepared as a documented owner action with verified zip integrity. First-attempt toolchain blockers are moot under this flow. |
| 11 | v04_post_release_verification_prompt.md | blocked until #10; owner-launch only | PM machine | Verifies the LIVE builds players receive (itch web + published Windows zip), generates devlog #4 card/copy assets, marks the plan SHIPPED. Devlog posting stays with the owner. |

Only the project manager adds entries or reorders this table; executing
agents only flip Status fields for claims and remove completed entries.
"Owner-launch only" entries are never taken by agents running the generic
todo-list loop, even when their blockers clear; they start only when the
owner pastes their kickoff prompt.
