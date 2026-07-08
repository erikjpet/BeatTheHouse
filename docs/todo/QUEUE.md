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
| 0 | CRITICAL_meta_home_must_be_walkable_environment_prompt.md | claimed (2026-07-07, DESKTOP-1950ULQ/Codex) | any | **OWNER REJECTION REWORK — top priority.** The v04 meta home shipped as a broken menu, not the walkable environment the prompt required. Rebuild the presentation as in-world rooms (pixel scene canvas + archetype props) reusing the intact backend; remove the menu path; popup-fits-screen assertions; screenshot evidence required. Owner will personally re-review. |
| 7b | v04_completed_work_review_prompt.md | blocked until #0 | any | Owner-directed adversarial verification of ALL prompts completed 2026-07-06/07: per-prompt requirement re-verification against current code, cross-feature integration matrix, edge-case hunting (save/load, hostile input, determinism, daily/challenge isolation), upgrade-path 0.3.3 fixture, and per-frame efficiency audit. Produces docs/plans/v04_work_review_2026_07.md. |
| 7c | v04_player_performance_pass_prompt.md | blocked until #7b | any | Owner-directed player-style performance pass: instrumented full-session playthrough (meta home rooms → pawn shop → run with dialogue/talk/eviction live → slot autoplay → decay/drop/open), probe + web smoke + 60-min soak vs 0.3.2 ledger baselines, and adoption of enforced budgets for the new surfaces. Runs after #7b so review fixes do not contaminate baselines. |
| 8 | v04_final_balance_release_gate_prompt.md | blocked until #0-#7c | any | Final full gate, metrics, performance, soak, determinism, stuck-state, web smoke, and 60-run mouse batch. |
| 9 | v04_release_docs_packaging_prompt.md | blocked until #8 | any | Version 0.4.0, README/checklist/changelog/publish copy, exports, checksums, web/windows smoke, butler dry-run. |

Only the project manager adds entries or reorders this table; executing
agents only flip Status fields for claims and remove completed entries.
