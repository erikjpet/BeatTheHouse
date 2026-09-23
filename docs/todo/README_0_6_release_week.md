# 0.6 Release Week — plan and scoreboard

Created 2026-09-22 by the owner and PM. Target: 0.6.0 upload-ready artifact handoff by **2026-09-29**.
This page replaces the "Current owner-directed sequence" on
`README_0_6_board.md`. Anything not on this page ships in 0.6.1 and is listed in
`../plans/0.6.1_backlog.md`, so no idea is dropped.

## What 0.6 means

A player can start a new run and reach the win state of **all three endings**
through the normal game:

1. **Clean**: climb Linda's Players Card ladder to the clean Grand Casino ending.
2. **Cheat**: survive Rourke's walk, pat-down and interrogation, and win the
   five-hand back-room duel.
3. **Crew/heist**: build Crew trust and finish a Grand Casino heist to its win
   state.

Each ending may be simpler than the full design, but it must be finishable. Rooms
use fixed, modular slots instead of randomly scattered objects.

## Deliverable

Two upload-ready zip files: the **itch.io Web build** and the **Windows `.exe`
build**, both at version 0.6.0, built with `tools/export_itch.ps1` without
`-Push`. Each zip must pass its PCK audit and packaged smoke checks. The owner
always uploads the zips personally; agents never run butler or any upload or
publish command.

## Owner questions file

`rw06_owner_questions.md`, read and written at its primary-checkout path
`D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md`, is the only channel between agents and the owner. Agents ask there
and keep working. The owner answers there within a few hours. Whichever agent
next finds the answer resumes the work. Every row must follow its protocol.

## Owner decisions (2026-09-22, binding)

- **Placement.** Every room gets fixed, authored, modular slots. Scenario objects
  are placed only in those slots. Anything that doesn't fit goes to a room action
  list. Adding a slot later must be a data change only.
- **Nothing useful is lost, and no branch is left behind.** The worker merges
  its snapshot commit into `main`, so all of the solver work lives permanently
  in `main`'s history and can be recovered with `git show SNAPSHOT:<path>`.
  The unfinished solver is deactivated in production. Each piece is kept,
  adapted or dropped based on `docs/plans/postfix06_2_placement_harvest.md`.
  Nothing is deleted without a recorded reason. The branch is deleted after
  the merge.
- **Every row branch merges back.** Every worktree or branch a row creates is
  merged into `main` (or fast-forwarded) and then deleted, both locally and on
  origin. A row is not DONE while it has an unmerged branch. Abandoned
  experiments are merged as a history-preserving commit and then reverted,
  never left dangling.
- **Smaller release gate.** The gate is defined in `rw06_4`. The larger gates
  move to 0.6.1.
- **All three endings** must reach their win state.
- **Run length.** A normal run to an ending takes about 150–350 player actions
  (roughly 30–60 minutes). It may be much quicker when the player hits a
  jackpot or finds a legitimate fast route. Don't remove those shortcuts.
- **Commits.** Worker agents executing these prompts commit and push their own
  work. The PM (planning) session never commits.

## Order

| Day | Row | Prompt | Depends on | Status |
| --- | --- | --- | --- | --- |
| 0 | rw06_pre | `../todone/rw06_pre_worker_handoff_message.md`: the running worker finishes on its branch, merges to main and deletes the branch | — | DONE (`54c7d788`) |
| 1 | rw06_0 | `../todone/rw06_0_custody_commit_prompt.md` | rw06_pre reports MERGED (fixes on main, branch deleted) | DONE (`7da3e5da`) |
| 1–4 | rw06_1 | `rw06_1_fixed_slot_rooms_prompt.md` | rw06_0 | IN_PROGRESS (focused gate exposed real base-slot, stable-binding, walk-lane and validator-fidelity blockers at `78dfa8e1`; fixes in progress) |
| 1–5 | rw06_2 | `rw06_2_three_endings_prompt.md` | rw06_0 (runs parallel to rw06_1; final pass after rw06_1) | IN_PROGRESS (replay safety harness focused PASS at `172731ee`; qualifying routes wait for rw06_1) |
| 1–3 | rw06_5 | `../todone/rw06_5_owner_gameplay_fixes_prompt.md`: clicking a person starts a conversation, blackjack count shown between hands, Cass needs a real count | rw06_0 (parallel with rw06_1/rw06_2) | DONE (`1038a31f`) |
| 5 | owner run | Owner plays one ending start to finish; notes go to the scoreboard | rw06_1, rw06_2 first pass | TODO |
| 5 | rw06_3 | `rw06_3_balance_prompt.md` | rw06_2 routes exist | TODO |
| 6–7 | rw06_4 | `rw06_4_release_gate_ship_prompt.md` | rw06_1, rw06_2, rw06_3, rw06_5 | TODO |

One orchestrator runs rows rw06_0 through rw06_5:
`rw06_execute_release_week_prompt.md`. rw06_1, rw06_2 and rw06_5 run at the same time. The file-ownership rule is in each
prompt.

## Scoreboard (only the orchestrator edits it; rows report to the orchestrator)

This is the one place that shows whether things are improving. Update values in
place, and add one dated line to the history below.

| Metric | Target | Current | Last updated by |
| --- | --- | --- | --- |
| `check_godot.ps1 -Suite Smoke` | PASS | PASS (`1038a31f`, 10/10 composite: 9/10 full merged-main suite plus a clean isolated exact-profile retest of the sole stochastic performance stage; unchanged budgets) | release orchestrator |
| `check_godot.ps1 -Suite Contract` failing shards | 0 | 0/18 Foundation shards at `1038a31f`; all later UI/tutorial/audio stages passed. The one inherited repeated-reprieve room/scenario-composition standalone stage remains (`.tmp/rw06_5/orchestrator_main_contract/summary.json`, SHA-256 `FDD2D9D421378F6A3F063ADBD378B786F05F08782F72B6AFCD849EFF1F77092B`). | release orchestrator |
| Open P1 (High) defects | 0 | 7 (UIENV-PF-003…008; RP-006 packaged proof) | release orchestrator |
| Open P2 (Medium) defects | 0 | 1 placement (UIENV-PF-009); 0 non-placement | release orchestrator |
| Endings reaching the win state through real UI | 3/3 | unknown | — |
| Owner day-2 room sample (3 rooms) | approved | not started | — |
| Owner start-to-finish run | done, no blockers | not started | — |
| Owner run notes | (owner writes blockers here; non-blockers go to the 0.6.1 backlog) | — | — |
| Release gate items green (rw06_4) | all | 0 | — |
| Unmerged row branches (`git branch -a`) | 0 | 2 active release-week branches (rw06_1, rw06_2) | release orchestrator |

History (newest last):

- 2026-09-22 PM: baseline recorded from the 9/21 post-fix ledger and playtest.
- 2026-09-23 release orchestrator: verified postfix merge `54c7d788`, SNAPSHOT ancestry, harvest, tested-tree identity and complete branch/worktree cleanup; committed the release-week plan and started rw06_0.
- 2026-09-23 release orchestrator: completed rw06_0 custody at `7da3e5da`; validator passed, Smoke closed 10/10 after the authored native-solver wrapper corrected a fresh-worktree extension-cache miss without changing a budget, and the worker Contract census was reused because every change since `54c7d788` is docs-only. Started rw06_1, rw06_2 and rw06_5 in parallel.
- 2026-09-23 release orchestrator: completed rw06_5 at product commit `1038a31f`; person events now converse before resolution, blackjack shows the player's recorded count between hands, and Cass requires a live recorded count. Production-input evidence passed; merged-main validation passed; Smoke closed 10/10 by an unchanged-profile composite; Contract passed 18/18 Foundation shards and all later stages with only the inherited repeated-reprieve standalone red. Archived the prompt and removed the merged row branches/worktrees.
- 2026-09-23 release orchestrator: rw06_2 replay safety harness reached exact branch tip `172731ee`; its engine-free source contract, hostile public-observation contract, and two-launch bridge lifecycle contract passed. Focused evidence is `.tmp/rw06_2/public_observation_contract.json` (SHA-256 `F8F699846DB1CFD6C5659F7A9D10F42C77CAB4F8573C4C5EE19D28E683889195`) and `.tmp/rw06_2/clean/bridge-20260923-054711-435-14372/summary.json` (SHA-256 `79F6D5CB75857BA83A66A475BA4EB5FC6C18A2D9311C7954B5B56AEA2C862CCF`). Qualifying ending runs remain deferred until rw06_1 lands.
- 2026-09-23 release orchestrator: rw06_1's first focused grounding run at `78dfa8e1` failed on a real generated-base slot mismatch. Read-only audit also found unstable phase-to-phase scenario bindings, two barriers intersecting the mandatory walk lane, runtime label placement still bypassing authored anchors, and an incomplete static phase/action census. The row remains IN_PROGRESS while those root causes and their non-weakened regressions are repaired; Godot is off pending a new audited tip.

## Rules every row inherits

- Owner decisions only go through `rw06_owner_questions.md`. Ask, then keep working.
- Never weaken a test, budget, idle-liveness floor or deterministic assertion to
  get to green. An idle draw cost of 0.000 without its liveness counter is a
  failure.
- Everything is seeded and happens at action boundaries, never on wall-clock
  time. Every consequence fires exactly once across save, reload, travel and
  revisit.
- No hidden-state leaks: Turn, traitor, rigged-draw and unrevealed-ticket
  information never appears in scene data, saves, captures or audio.
- A run that ignores the Crew must be a true no-op for Crew systems.
- Scope discipline: if something doesn't block this week's goal, it goes into
  `../plans/0.6.1_backlog.md` with enough detail to act on later. It is never
  silently dropped.
- Serialize Godot runs. One heavy Godot process at a time per machine.
