Status: TODO — investigated and root-caused; implementation intentionally not started
Priority: P1 test-infrastructure defect because it blocks the required playability sweep and misreports working gameplay as broken
Investigation date: 2026-09-07

# Current-source playtest bug investigation

## Source under investigation

The active worker source in the main folder was identified before testing:

- Workspace: `D:\Projects\Beat-The-House`
- Active worker task: `Complete 0.6 landing and board`
- Branch: `codex/fix06_26-crew-favor-cadence`
- Commit: `b9bd8fcb1cc205956ae085c9cfb53de408faedc8`
- Commit subject: `fix(world): restore Crew favor cadence`
- Entry point: `project.godot` -> `res://scenes/main.tscn`
- Active UI script: `res://scripts/ui/foundation_main.gd`
- Tracked files were clean. Five pre-existing `docs/todo/*.md` prompt files were untracked; this investigation did not modify them.

A fresh source instance was launched directly from this folder with Godot 4.6, separate from the already-open packaged `builds/windows/BeatTheHouse.exe`. The source instance was PID `4036` at launch. No worker task was contacted and no gameplay fix was made.

## New confirmed bug: the click playtest chooses the wrong exit after motel-room travel

### Player/test symptom

The standard mouse-driven playability test reports both of these failures immediately after leaving the motel room:

1. `Opening the world map should not mutate serialized RunState before route confirmation.`
2. `Double-clicking Leave did not open the world map overlay.`

The same result reproduced in three independent runs:

- `BUGINV-B9BD-001`
- `BUGINV-B9BD-002`
- `BUGINV-B9BD-003`

All three runs then emit twenty downstream errors about games, consequences, saving, Continue, and recovery. Those errors are cascades: the harness stops progressing at travel and never reaches the later surfaces.

This is **not a player-facing world-map failure**. The production travel implementation was checked separately: after the local motel-room-to-motel move, explicitly activating `travel:leave` opened the map, returned screen `TRAVEL`, kept the overlay visible, and produced no serialized `RunState` changes.

### Root cause

The defect is in `tools/foundation_visual_qa.gd`.

`_try_travel_object_flow()` correctly handles the first `travel:leave` activation as a local move from the motel room into its parent motel. After that move, however, line 652 reacquires the next target with:

```gdscript
travel_object = _first_clickable_canvas_object_type_enabled(canvas, "travel", true)
```

That helper, at line 4401, returns the first enabled object whose broad type is `travel`. It does not distinguish a world-map exit from a local interior door.

The parent motel exposes at least two enabled objects of that type:

- `travel:motel_room`, label `Room Door` — valid local travel back into the room
- `travel:leave` — the world-map opener the test intends to exercise

Render order places `travel:motel_room` first. The harness therefore double-clicks `Room Door`, legitimately changes environment state by returning to the room, and leaves the world map closed. Lines 659-660 then misclassify that valid local move as a mutating/broken map open.

The input evidence is exact: in all three failing reports the second travel event is `object_id = travel:motel_room`, `label = Room Door`; it is never `travel:leave`.

### Required fix

Change only the post-local-travel target selection in `tools/foundation_visual_qa.gd`:

1. Reacquire the exact semantic target `travel:leave` with `_canvas_object_by_id(canvas, "travel:leave")` instead of choosing the first object of type `travel`.
2. Verify that this exact object is enabled, visible, and hittable before double-clicking it. If useful, add a small ID-specific helper rather than weakening the check.
3. Include the selected object ID/label and `_serialized_diff_summary()` in a failure message so another wrong-target regression is obvious.
4. Add a regression case for a parent venue that simultaneously exposes `travel:motel_room` and `travel:leave`. Assert that the second recorded input event targets `travel:leave`, the map becomes visible, and serialized run state remains byte-identical until route confirmation.

Do **not** change `FoundationMain.open_world_map()`, `RunGenerator.world_map_snapshot()`, or production travel state in response to this report. They were exonerated by the direct state-difference probe.

### Acceptance evidence

An isolated detached copy of commit `b9bd8fcb` was used so the active worker folder stayed untouched. With only the selector changed from broad type lookup to exact `travel:leave` lookup, the full visual/click QA completed with:

- 75 captured states
- 143 visible input events
- 0 warnings
- Successful motel-room -> motel -> world-map progression

The three remaining `false` coverage flags (`pit_boss_watch_visible`, `r100_result_populated_after_consequence`, and `unaffordable_item_rejects`) are optional/unavailable-path coverage in this run and did not produce warnings or failures.

Evidence artifacts are under `.tmp/bug_investigation_b9bd8fcb/`:

- `mouse/raw_mouse_reports/mouse_run_001.json`
- `mouse/raw_mouse_reports/mouse_run_002.json`
- `mouse/raw_mouse_reports/mouse_run_003.json`
- `foundation_visual_qa_after_selector_fix.json`

## Findings deliberately not filed as gameplay bugs

### World-map mutation/overlay failure

Rejected as a false positive. The direct probe returned `changed_paths = []`, `second_activation_result = true`, `second_screen = TRAVEL`, and `second_map_visible = true` when the intended `travel:leave` object was activated.

### Family Loan contract failure in `.tmp/fix06_26_t47.json`

Rejected as a current gameplay defect. That test directly resolves the triggered event without first placing it in the host pending-event queue. Current event authority correctly rejects such an unowned resolution. The actual player action (`call_brother_in_law`) enqueues `family_loan` before resolution. If retained, the stale test should be repaired as test debt, not used to change production event authority.

### Existing environment-object visual/consequence work

Not new and not duplicated here. The already-authored `fix06_25` and `env06_9` documents own missing object identities, panels/actions, and visible scenario consequences.

## Current conclusion

No new player-facing travel defect was reproduced on commit `b9bd8fcb`. One new deterministic test-infrastructure bug was confirmed and root-caused. It must be fixed before relying on the mouse playability sweep, because its current cascade can falsely label most of the game loop as unavailable.
