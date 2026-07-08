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
| 4 | v04_meta_home_environment_prompt.md | claimed (2026-07-08, Codex desktop) | any | Owner-directed renovation superseding the former loadout + economy-polish prompts: walkable persistent home (alley→motel→apartment→house bought with gold), meta map travel, pawn-shop sell counter, homeless carry-everything rule, loadout injection + failure decay for normal runs only (daily/challenge isolated). |
| 6 | profile_persistence_completion_prompt.md | blocked until #4 | any | Parked T5.3: run history, daily streaks, lifetime stats, challenge display, schema/atomic profile save. |
| 7 | act_two_seam_prompt.md | blocked until #6 | any | Parked T8.1: save act marker, profile act seam, and route-specific victory hook replacing "not implemented yet". |
| 8 | v04_final_balance_release_gate_prompt.md | blocked until #4-#7 | any | Final full gate, metrics, performance, soak, determinism, stuck-state, web smoke, and 60-run mouse batch. |
| 9 | v04_release_docs_packaging_prompt.md | blocked until #8 | any | Version 0.4.0, README/checklist/changelog/publish copy, exports, checksums, web/windows smoke, butler dry-run. |

Only the project manager adds entries or reorders this table; executing
agents only flip Status fields for claims and remove completed entries.
