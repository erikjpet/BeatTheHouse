# Agent Prompt - Restore 0.5 Release-Gate Truth and Fix Committed Regressions

Last reconciled: 2026-08-05
Release target: 0.5.0
Status: OPEN / BLOCKS FEATURE CLOSURE AND FINAL RC

## Execution record — 2026-08-05

Status: **COMPLETE**

- Root causes: the load gate treated a non-null script resource/process exit as
  success even when strict stderr contained parser/runtime errors;
  compositional Foundation/UI fragments were being loaded outside their real
  generated compilation units; map selection cleared its animation origin at
  the wrong state-machine boundary; inventory focus and bag sizing ran before
  their owning controls had stable tree/layout state; and stale content/UI
  assertions no longer followed the authored route and outcome contracts.
- Fixes: strict classified stderr is now authoritative; standalone scripts are
  exhaustive-loaded while compositional fragments run through split runners;
  map focus preserves its pre-selection window; lifecycle/layout ownership was
  corrected; the Grand Casino seen/locked route, parking-tip route-open copy,
  dealer reprieve, and data-backed result-title contracts were reconciled.
- Commits: `038d8a94`, `f9fb2fd2`, `ee41ac74`, with final gate-quality followups
  `37eba0bb` and `84ae3fc6`.
- Negative control: a temporary invalid standalone fixture made
  `gdscript_load_check` and its wrapper exit nonzero in
  `.tmp/gate_truth_negative_control/summary.json`; the fixture was removed.
- Gates: Systems and UI passed with clean classified stderr
  (`.tmp/v05_systems_green/summary.json`,
  `.tmp/v05_ui_decision_final/summary.json`); the exact-source Full matrix
  passed at `.tmp/v05_release_candidate_green/summary.json`; determinism
  matched 320 checkpoints/hash `2820946917`; strict mouse play passed 2/2;
  visual QA completed with no warnings.

## Objective

Make the release gates accurately fail on real errors, then fix every fresh
committed Systems/UI regression found by the 2026-08-05 pre-release audit. Fix
root causes; do not suppress output, exclude valid coverage, relax assertions,
or change expected copy solely to make a row green.

Read `docs/plans/0.5_pre_release_audit.md` first. Preserve all unrelated
owner-owned narration and audio work.

## RG-01 - GDScript load gate is false-green

`tools/gdscript_load_check.gd` reports PASS while Godot emits many parse errors
for compositional Foundation/UI fragments. Establish the intended compilation
unit for every script category:

- production scripts and standalone tools must load directly with clean stderr;
- compositional test fragments must be validated through the generated runner
  that supplies their shared helpers, not misleading standalone loads;
- any direct-load failure in an intended standalone unit must produce a
  nonzero stage and a named report failure; and
- `check_godot.ps1` must reject unexpected `ERROR:`, `SCRIPT ERROR:`, leaks,
  and resource-at-exit messages rather than relying only on process exit code.

Acceptance: inject one temporary broken standalone fixture and prove the gate
fails, remove it, then prove the normal run has clean classified stderr. Do not
retain the temporary defect.

## RG-02 - Systems content/travel contracts

On clean `58519d4a`, Systems fails:

1. known Grand Casino map node does not persist as a seen, locked reference
   before invitation acceptance;
2. `parking_lot_tip/follow_tip` lacks explicit route-open copy; and
3. the same choice does not name `small_underground_casino`.

Trace the map-state and authored content contracts. Restore honest player copy
and persistent seen/locked state without exposing the route as travel-enabled
early. Coordinate with the later meaningful-destination prompt; do not invent
a second travel-state model.

## RG-03 - World-map focus animation regression

The UI suite reproducibly reports that selecting a location snaps the view
window from `x=0.0` to about `x=0.69677` immediately. Selection must establish
an animation from the current visible window, retain hit/selection correctness
through the transition, and finish on the target. Fix the focus state-machine
ordering, not the assertion or animation duration.

## RG-04 - Runtime error and warning cleanup

Fix at the owning lifecycle/layout seams:

- `RunInventoryScreen.open()` / `InventoryContainerSurface.focus_selection()`
  calls `grab_focus()` before the control is inside the scene tree;
- the bag-opening component sets size while opposite anchors make Godot
  override it after `_ready()`;
- Systems exits with an ObjectDB leak warning and one resource still in use;
- the current narration work adds a missing tutorial dealer-reprieve warning;
  reconcile the authored line and its content contract together.

Every error/warning needs a causal disposition. A test-only exemption is
allowed only when the event is proven engine noise, narrowly classified, and
documented; broad stderr filtering is forbidden.

## Hard rules

- Preserve determinism, input behavior, animation liveness, normal-run time,
  and tutorial-only freeze rules.
- No assertion weakening, budget relaxation, sleep/retry masking, output
  redirection, or catch-all stderr allowlist.
- Keep test compilation architecture explicit. Do not make compositional
  fragments fake standalone classes by duplicating shared helpers.
- Tabs, typed GDScript, sparse comments. Never revert or stage unrelated work.

## Gates

- `tools/validate_project.ps1`
- `tools/check_godot.ps1 -RequireGodot -Suite Smoke -FoundationSuite systems`
- `tools/check_godot.ps1 -RequireGodot -Suite Smoke -FoundationSuite ui`
- every other supported FoundationSuite affected by the fix
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_mouse_batch_playtest.ps1`
- `tools/foundation_visual_qa.ps1 -RequireGodot`
- strict scan of every stage stderr: no unclassified error, script error,
  leak, resource-at-exit error, or new warning

## Deliverable and completion

Append an execution section to `docs/plans/0.5_pre_release_audit.md` with root
causes, fixes, before/after reports, stderr classification, and commits. Only
after all gates are green, prepend an execution record and move this prompt to
`docs/todone/`. Do not push without explicit user authorization.
