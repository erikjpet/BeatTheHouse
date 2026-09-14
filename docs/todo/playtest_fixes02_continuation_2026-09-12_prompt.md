Status: DONE — continuation fixes uncommitted in shared fix worktree, awaiting owner review
Source report: `docs/plans/agent_playtest/agent_playtest_report_2026-09-12.md` (continuation findings BUG-24 … BUG-31)
Predecessor task: `docs/todo/playtest_fixes01_agent_sweep_2026-09-12_prompt.md` (BUG-01 … BUG-23)

# Agent Prompt — Playtest Fixes 02: Fix the Eight Continuation Findings

Copy everything below this line into the agent.

---

You are working on **Beat The House**, a Godot 4.6 GDScript roguelite. This is
the second task in a two-part playtest repair sweep. The first task handles
BUG-01 through BUG-23; this task handles **BUG-24 through BUG-31**.

## Goal

Validate and fix every valid continuation finding in:

`D:\Projects\Beat-The-House\docs\plans\agent_playtest\agent_playtest_report_2026-09-12.md`

Read that report in full first, including its Not Bugs, Harness Issues, and
Coverage sections. Then read:

- `D:\Projects\Beat-The-House\docs\todo\playtest_fixes01_agent_sweep_2026-09-12_prompt.md`
- `D:\Projects\Beat-The-House\docs\plans\agent_playtest\agent_playtest_fixes_2026-09-12.md`
  if the first worker created it.

The report contains claims and likely-cause hypotheses, not permission to patch
blindly. For each BUG-24 through BUG-31, independently reproduce or prove the
defect on the code state inherited from Fixes 01, trace the real production
path, write a failing regression test, and only then fix it.

## Hard rules

- **Run this only after Fixes 01 is finished.** Confirm the predecessor prompt
  says `Status: DONE` and read its execution record and fix report. If it is
  still READY, active, or BLOCKED, stop and report that dependency; do not race
  the first worker.
- **Continue in the existing fix worktree** at
  `D:\Projects\Beat-The-House-worktrees\playtest-fixes` on branch
  `codex/agent-playtest-fixes`. Do not create another worktree or branch.
- The worktree intentionally contains the first worker's **uncommitted**
  BUG-01–23 fixes. Preserve and build on them. Before editing, record
  `git status`, inspect the complete diff, and read every changed function you
  will touch. Never restore, overwrite, or reformat the earlier fixes.
- **No commits, pushes, merges, stashes, resets, rebases, or checkouts.** Leave
  the combined BUG-01–31 changes uncommitted for owner review.
- Other agents have uncommitted work in the main checkout. Do not edit, stage,
  or run the game from `D:\Projects\Beat-The-House`. The only main-checkout
  files you may create or edit are:
  - the continuation fix report named in Deliverables;
  - the execution record and Status at the top/bottom of this prompt.
- Do not touch the `backroom-poker-tweaks`, `game-prop-art`, or
  `agent-playtest` worktrees. The last one is read-only evidence/tooling source.
- Validate each bug before changing product code for it. Put its validation
  record in the continuation fix report before applying its fix.
- Use the report's Recommended option unless validation proves it insufficient.
  Choose the smallest root-cause fix, document any deviation, and do no
  drive-by refactors, balance changes, lender-term changes, or voice rewrites.
- Scratch output, screenshots, logs, and new harness sessions belong under
  `.tmp/playtest_fixes02/` in the fix worktree and stay uncommitted.

## 1. Establish the inherited baseline

1. Record the fix worktree branch, HEAD, status, and complete inherited diff.
   The HEAD may still be the original tested commit
   `56de66598a2bcdbc3f171f090b48c361daf35563`; the working tree is the real
   inherited baseline because Fixes 01 is uncommitted.
2. Read the Fixes 01 report and classify any failing gates it lists as inherited
   or pre-existing. Do not relabel them as failures introduced by this task.
3. Confirm the playtest harness exists in the fix worktree. Compare it read-only
   with the latest copies in
   `D:\Projects\Beat-The-House-worktrees\agent-playtest\tools\` and update the
   fix-worktree copies if needed. The latest harness includes isolated
   persistence directories, clipped hit geometry, and parseable-result waits.
   Harness files are tooling, not product fixes; list them separately.
4. Run and record a baseline:
   - `powershell -File tools\validate_project.ps1`
   - `powershell -File tools\check_godot.ps1 -RequireGodot -Suite Smoke`
   - targeted suites named in section 6.
5. The full validator may be slow. Do not call a timeout a pass. If it exceeds a
   reasonable extended limit, run its component checks, preserve the timeout
   output, and classify it accurately in the report.

## 2. Bug groups

| Group | Bugs | Primary area |
|---|---|---|
| G8 Surface layout and copy | BUG-24, BUG-25, BUG-26, BUG-28 | Baccarat back control, room detail layout, scenario semantic lines, Bar Dice guidance |
| G9 Round/result state | BUG-27, BUG-29 | Blackjack semantic result, Roulette rebet lifecycle |
| G10 Dialogue identity and loan disclosure | BUG-30, BUG-31 | chained-event speaker hydration, lender choice/confirmation/result copy |

You may use sub-agents to validate groups in parallel, with distinct harness
session names and persistence roots. All product edits must be made serially by
you in the one shared fix worktree.

## 3. Validation protocol — required for every bug

For each BUG-NN:

1. Replay the original player path from the cited session evidence using a fresh
   Fixes 02 persistence root. Try twice when timing or random state matters.
   Capture before PNG and result JSON.
2. Read the named implementation and its callers/consumers. Record the actual
   root cause as `file:function:line`, correcting the report if necessary.
3. Add a regression test at the lowest existing production seam. Add it to the
   established suite for that area rather than creating a parallel framework.
   Prove the new assertion fails against the inherited pre-fix state.
4. Classify it as one of:
   - `VALID`
   - `VALID-DIFFERENT-CAUSE`
   - `ALREADY FIXED BY FIXES 01`
   - `NOT REPRODUCIBLE`
   - `NOT A BUG`
   - `HARNESS ARTIFACT`
   - `OWNER DECISION`
5. Only `VALID` and `VALID-DIFFERENT-CAUSE` receive product changes. If Fixes 01
   already fixed it incidentally, prove the regression test is green, identify
   the inherited hunk, and do not duplicate or churn it.

## 4. Per-bug requirements

Line numbers below are from the original report and may have moved after Fixes
01. Re-locate every symbol.

### G8 — surface layout and copy

**BUG-24 — Baccarat LEAVE overlaps the hand explainer.**

- Original evidence:
  - `.tmp/agent_playtest/2026-09-12/pt_b3/0013.png`
  - `.tmp/agent_playtest/2026-09-12/pt_b3/0025.png`
  under the read-only `agent-playtest` worktree.
- Validate deal, squeeze/reveal if available, and result states at 1280×720.
- The report suspects the shared default back rect in
  `scripts/ui/game_surface_canvas.gd` overlaps the explainer drawn by
  `scripts/games/baccarat.gd`.
- Preferred fix: Baccarat supplies an explicit non-overlapping
  `surface_back_rect`. Do not globally move every game's back control unless a
  shared layout invariant demonstrably requires it.
- Add a layout contract asserting the effective back-control rectangle does not
  intersect Baccarat's explainer/content rectangles in every relevant state.
  Verify the hit target and label remain visible, not merely the drawing.

**BUG-25 — Dave's consequence preview is clipped.**

- Original evidence:
  `.tmp/agent_playtest/2026-09-12/pt_c5/0063.png`.
- The full structured response ends with “Bus knew the turns better than the
  driver,” but the 1280×720 card clips after “Keep Alley in mind. S”.
- Preferred fix: wrap the inline detail and size the detail/card region from the
  resulting line count. Do not fix only this string or silently ellipsize it.
- Exercise normal text, the longest authored current consequence, small-screen
  mode, and increased text/UI scale. The action button and adjacent cards must
  remain visible and non-overlapping.
- Add a rendered-layout or deterministic geometry test proving all visible text
  fits its assigned region.

**BUG-26 — scenario instruction appears twice.**

- Original evidence:
  `.tmp/agent_playtest/2026-09-12/pt_d4/0021.png`.
- Trace `short_description` and `action_summary` from
  `scripts/ui/scenario_semantic_view_model.gd` into
  `scripts/ui/pixel_scene_canvas.gd`.
- Preferred fix: suppress one rendered line only when the normalized strings
  are equal. Preserve both when they carry different useful information.
- Audit the current scenario catalog for other identical pairs and add a view-
  model/presentation test for both duplicate and legitimately distinct cases.

**BUG-28 — Bar Dice guidance clips at 1280×720.**

- Original evidence:
  `.tmp/agent_playtest/2026-09-12/pt_b6/0019.png`.
- Replace character-count slicing such as `.left(74)` with width-aware layout
  inside the actual console rectangle. Prefer wrapping if it remains readable;
  concise copy is acceptable only in addition to a general fit invariant.
- Cover idle, active hand, SETTLE, and result instructions at normal and small-
  screen layouts. Verify controls and text do not overlap.
- No collection-building or text measurement cache churn may be introduced per
  frame; cache layout inputs if the draw path is hot.

### G9 — round and result state

**BUG-27 — Blackjack loss headline says `PUSH +0`.**

- Original evidence:
  `.tmp/agent_playtest/2026-09-12/pt_b5/0026.png`.
- The captured hand lost $11: the lower summary and bankroll are correct, but
  the prominent result uses the zero settlement-transfer delta after the wager
  was pre-debited.
- Preferred fix: keep settlement/accounting transfer values separate from the
  semantic round net and build the headline from the semantic result. Do not
  debit or credit the bankroll a second time to make the headline convenient.
- Add conservation and headline tests for a normal win, normal loss, push,
  blackjack, bust, surrender if supported, double-down, split/multiple hands,
  and insurance if supported. Assert displayed delta equals the player's full
  round outcome while actual bankroll movement remains exact.
- Confirm save/load of a completed hand preserves the same headline and does not
  replay settlement.

**BUG-29 — Roulette REBET is disabled after CLEAR.**

- Original evidence:
  `.tmp/agent_playtest/2026-09-12/pt_b7/0013.png`.
- Validate twice: place a multi-chip layout, complete the spin, CLEAR retained
  current chips, then REBET. The prior settled layout must be restored exactly
  once and bankroll accounting must match it.
- Trace `table.last_bets`, session `roulette_rebet`, normalization, settlement,
  CLEAR, and rendering. Preferred fix: update one authoritative rebet history at
  settlement and prevent an explicit stale empty session array from shadowing
  it.
- Cover win/loss, repeated rebet rounds, clear-before-first-spin, insufficient
  bankroll, leave/re-enter, and save/Continue. A new table/run must not inherit
  unrelated old bets.
- Keep spin determinism and idle liveness unchanged.

### G10 — dialogue identity and loan disclosure

**BUG-30 — chained phone event loses “Caller” from “Unknown Caller”.**

- Original evidence:
  `.tmp/agent_playtest/2026-09-12/pt_c7/0021.png`.
- `data/events/events.json` authors “Unknown Caller”; the real chained-event path
  renders the generic fallback “Unknown”.
- Fix speaker hydration at the general chained-event enqueue/display boundary,
  not with an event-ID or string special case. Preserve authored speaker name,
  portrait/faceless metadata, and entry overrides using the same contract as a
  directly queued event.
- Add tests for direct events, chained target events, hook overrides, an authored
  faceless name, and a truly unnamed speaker that should still fall back to
  “Unknown”. Check save/Continue mid-chain.

**BUG-31 — Vic Mercer's loan hides its terms.**

- Original evidence:
  `.tmp/agent_playtest/2026-09-12/pt_d7/0020.png`.
- The $25 loan creates $28 repayment debt at 10%, due in three turns. Those exact
  terms must be visible before acceptance, in the confirmation, and in the
  resulting acknowledgement. Preserve Vic's authored voice beside the terms;
  do not replace it with generic financial copy.
- Source displayed values from the lender data/model and the same rounding rule
  used to create debt. Never duplicate literals in UI code. Do not change the
  rate, deadline, principal, rounding policy, heat, or balance.
- Audit every lender/loan entry for the same disclosure gap. Add a parameterized
  contract test asserting offer, confirmation, and result expose principal,
  repayment total, rate, and deadline and agree with the debt actually created.
- Validate insufficient/declined/repeated-offer paths and save/Continue with the
  accepted debt.

## 5. Engineering constraints

- GDScript uses tabs and static typing for new variables/functions; follow local
  names and idioms.
- Fix root causes with minimal diffs. No unrelated cleanup, content rewrites, or
  broad reformatting.
- **Zero-copy per frame:** draw, `_process`, and other hot paths may not add
  `duplicate()` calls or rebuild collections every frame.
- **Idle liveness:** Baccarat, Bar Dice, Blackjack, and Roulette must keep their
  idle/animation counters moving. A 0.000 timing result is not a pass without
  the liveness assertion.
- All randomness uses the existing RNG streams. No fix may change deterministic
  outcomes for an unchanged valid seed unless the faulty state itself made that
  impossible; document any unavoidable difference.
- Hidden cards/outcomes remain outside presentation state.
- If a saved-state shape changes, add a versioned migration and round-trip test.
- Several continuation bugs overlap likely Fixes 01 files:
  `foundation_main.gd`, `pixel_scene_canvas.gd`, `game_surface_canvas.gd`, and
  `roulette.gd`. Integrate with inherited edits at the function level. In the
  report, list every inherited function you extended and distinguish Fixes 01
  lines from Fixes 02 lines.

## 6. Validation gates after fixes

Run all inherited Fixes 01 gates that were green, plus:

1. `powershell -File tools\validate_project.ps1`
2. `powershell -File tools\check_godot.ps1 -RequireGodot -Suite Smoke`
3. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite games`
4. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems`
5. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui`
6. Targeted suites for Baccarat/table games, Bar Dice, Blackjack, Roulette,
   event chains/dialogue, lenders/debt, scenario semantic presentation, and room
   canvas/layout. Use existing suite names discovered from the test runner; do
   not invent commands that silently run nothing.
7. Every new regression assertion: red on the inherited pre-fix state, green
   after its fix. Preserve both outputs.
8. Performance/liveness probes for each touched game surface and the room canvas
   at 1280×720 and small-screen mode. Record before/after values against
   `tools/perf06_budget_table.json`.
9. Player-path replay for all eight original routes, capturing after PNG/result
   JSON. Then run at least 40 additional visible-input actions in each group G8,
   G9, and G10.
10. One complete Save → quit → relaunch → Continue pass covering a loan/event
    chain and one completed table-game result.

A gate failing identically in the inherited baseline is inherited/pre-existing;
record it and do not expand scope. Any new failure caused by Fixes 02 must be
resolved before completion. Compare the final complete diff against the Fixes
01 baseline so no prior fix was lost.

## 7. Deliverables

Write the continuation fix report in the main checkout:

`D:\Projects\Beat-The-House\docs\plans\agent_playtest\agent_playtest_fixes_continuation_2026-09-12.md`

Do not edit the original playtest report or the Fixes 01 report. Structure:

1. **Header:** inherited HEAD/branch, worktree, predecessor status, inherited
   dirty files, harness version, and baseline gate results.
2. **Summary table:** one row per BUG-24…31 with validation class, corrected root
   cause, fixed status, regression test, files changed, and before/after links.
3. **Per-bug records:** player replay, code trace, red test, fix, green test,
   after evidence, and deviations from the recommended option.
4. **Incidental predecessor coverage:** any bug already fixed by Fixes 01, with
   the inherited hunk and proof; do not count it as a new edit.
5. **Not fixed:** all non-VALID classifications, evidence, and any owner action.
6. **Overlap/merge notes:** every Fixes 02 function changed in a file already
   changed by Fixes 01, clearly separated from the inherited work.
7. **Gates and performance:** baseline vs final, inherited/pre-existing vs new,
   and player-path replay results.
8. **Changed files:** grouped by BUG-24…31, with harness/tooling separate.

## 8. Completion

1. Confirm `git -C D:\Projects\Beat-The-House status` contains nothing from you
   except this prompt's Status/execution record and the continuation fix report.
2. Confirm the fix worktree contains the combined uncommitted Fixes 01 and
   Fixes 02 changes, with no commit or staged files. Reconcile the final diff
   against the predecessor report's changed-file list.
3. Quit every harness session and verify no Godot processes you started remain.
4. Append an execution record to the bottom of this file containing:
   - date, inherited HEAD, and predecessor completion state;
   - continuation fix report path;
   - counts per validation class and fixed count;
   - tests/gates and performance results;
   - inherited failures/timeouts;
   - owner decisions or remaining work.
5. Change the top line to:
   `Status: DONE — continuation fixes uncommitted in shared fix worktree, awaiting owner review`.

If the predecessor is incomplete, set `Status: BLOCKED — waiting for Playtest
Fixes 01` and do not touch the fix worktree. If a new gate failure cannot be
resolved within BUG-24–31 scope, leave all work uncommitted, set `Status:
BLOCKED`, and paste the failing output verbatim into the execution record.

## Execution record — 2026-09-12

- Dependency check: BLOCKED. `playtest_fixes01_agent_sweep_2026-09-12_prompt.md` is still `Status: READY`, not `DONE`.
- Predecessor report: `docs/plans/agent_playtest/agent_playtest_fixes_2026-09-12.md` does not exist.
- Inherited fix worktree: `D:\Projects\Beat-The-House-worktrees\playtest-fixes`, branch `codex/agent-playtest-fixes`, HEAD `56de66598a2bcdbc3f171f090b48c361daf35563`.
- Fix worktree state observed: only the two untracked playtest harness files were present; no BUG-24 through BUG-31 product edits were made.
- Continuation validation/fixes: not started, as required by the predecessor dependency gate.
- Cleanup: no Godot process launched by this continuation remains running.
- Required next step: complete Fixes 01, mark its prompt `DONE`, and create its fix report before rerunning this continuation.

## Execution record — 2026-09-13 continuation

- Dependency: Fixes 01 was confirmed `DONE`; its full prompt, execution record, and fix report were read before continuation work began.
- Inherited state: branch `codex/agent-playtest-fixes`, HEAD `56de66598a2bcdbc3f171f090b48c361daf35563`, inherited unstaged content-diff hash `6c108b64a8766e5f4c6f58089d4e939610671b49`. All inherited changes were preserved.
- Continuation report: `D:\Projects\Beat-The-House\docs\plans\agent_playtest\agent_playtest_fixes_continuation_2026-09-12.md`.
- Validation classes: 8 VALID, 0 NOT-A-BUG, 0 NEEDS-DESIGN, 0 OWNED-ELSEWHERE. Fixed: 8/8 (BUG-24 through BUG-31).
- Regression proof: `playtest_fixes02_regressions` failed 26 assertions on the inherited Fixes 01 state and passed after implementation. The final combined run passed Fixes 01, Fixes 02, event-module, and save-service round-trip contracts with zero failures.
- Targeted gates: Baccarat, Blackjack, Roulette, and Bar Dice passed; Bar Dice included 3x1000-round coverage. Final repository validation passed repeatedly, including after the last review edit.
- Broad gates: final Smoke passed import, script load, runtime, launchers, Dave, and Roulette audio, but retained the inherited foundation-content timeout, Path A tutorial fixture failure, and inaccessible late performance probes. `FoundationSuite games` timed out at 307.482 s in slow content; `FoundationSuite systems` timed out at 307.161 s; `FoundationSuite ui` retained only the pre-existing Path A missing-apartment-return failure. These failure classes predate Fixes 02 and are detailed with reports in the continuation report.
- Performance/liveness: Bar Dice 0.615/0.650/0.697 ms, Blackjack 3.318/3.605/3.630 ms, Baccarat 1.028/1.078/1.169 ms, and Roulette 1.348/1.475/1.485 ms (avg/P95/max), all within their budgets. Published idle counters advanced for Blackjack, Baccarat, and Roulette; the Bar Dice long-run contract passed, while the shared probe has no separate Bar Dice idle row.
- Player replay: all eight original streams were rerun after fixes, producing 242 PNG/result pairs and zero script errors. Group totals were G8 138, G9 59, and G10 45 visible-input actions. Route drift made some late old commands unavailable; deterministic production-seam regressions provide the after proof for those states.
- Persistence: the inherited harness lifecycle pass covers Save → process quit → relaunch → Continue. Continuation serialization checks preserve the completed Blackjack semantic result, hydrated family-loan chain, and exact accepted Vic debt; `save_service_foundation_round_trip` passes. The drifted player route did not reproduce all three states in one visible session, and the continuation report records that limitation explicitly.
- Remaining work/owner decisions: none for BUG-24 through BUG-31. Fixes 01 BUG-10 retains its separate reusable spawn-slot owner. Existing broad-suite infrastructure/fixture failures remain outside this scope.
- Final worktree state: combined unstaged content-diff hash `45add38e02d9de93e2ecae3f2092f32714ab5431`; no staged files. No commit, push, merge, stash, or reset was performed.
- Cleanup: no Godot process started by this continuation remains running.
