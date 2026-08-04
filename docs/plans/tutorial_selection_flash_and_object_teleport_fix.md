# Tutorial selection stability repair

Date: 2026-08-03
Branch: `agent/v05-pre-human-playtest-rework`

## Verdict

PASS. Environment objects now retain the generated position for the lifetime of the environment instance. Selection, camera focus, TalkDock movement, coach highlighting, viewport changes, and refreshes no longer rewrite the rendered object records. Repeated equal coach anchors no longer request redraws, so the tutorial highlight remains steady instead of entering a layout/redraw feedback loop.

## Confirmed root cause

The seeded environment layout was already generated and retained correctly by `EnvironmentInstance.ensure_generated_layout()`. The bar drink is confirmed as `service:house_drink`, backed by `service_spots`; 24 repeated layout reads did not rerun `pick_many` or alter `layout.object_rects`.

The teleport was introduced later by a second, mutable view-only layout in `PixelSceneCanvas._apply_reserved_overlay_layout()`. When TalkDock published its occupied rectangle, the canvas moved any intersecting room object to a different board position. That changed drawing, hit testing, camera focus, and coach geometry without changing the authoritative generated layout.

The flashing was the same feedback loop:

1. Selection or camera focus updated the coach anchor.
2. FoundationMain sent the anchor to TalkDock as an avoidance rectangle.
3. TalkDock moved and published a new occupied rectangle.
4. PixelSceneCanvas reflowed the room objects around that rectangle.
5. The selected target moved, producing another anchor, TalkDock move, and redraw.

`CoachOverlay` also redrew its focus layer when given the same rectangle again, amplifying harmless refresh traffic.

## Exact repair

- `scripts/ui/pixel_scene_canvas.gd`
  - Removed the overlay-driven room-object reflow and its fallback placement scan.
  - `set_reserved_overlay_rect()` now affects camera clearance only.
  - Drawing, hit testing, selection, camera targeting, and coach anchoring all continue to consume the one stable object record generated from the environment snapshot.
  - File size changed from 4,552 to 4,456 lines (`-96`).
- `scripts/ui/talk_dock.gd`
  - Repositions only when its preferred side/occupancy changes or its current rectangle actually intersects the target.
  - Decorative TalkDock surfaces are pointer-transparent after body reveal; authored choice buttons remain interactive.
- `scripts/ui/coach_overlay.gd`
  - Equal live anchor rectangles are no-ops; only real geometry changes redraw the focus layer.
  - A scalar diagnostic count proves redraw-boundary behavior without adding per-frame copies or allocations.
- Regression coverage
  - Systems: fixed layouts and same-seed reproduction across Corner Store, Bar, Gas Casino, Underground Casino, and Grand Casino; explicit `service:house_drink`/`service_spots` assertion.
  - UI: stable service position through 24 refreshes, changing TalkDock reserves, selection, and 48 camera-focus frames; hit testing remains attached.
  - UI: opening live dialogue preserves every rendered object position and serialized `object_rects`.
  - UI: 24 equal coach-anchor updates produce zero changes; one real geometry change produces exactly one update; the next 24 equal updates remain no-ops.
  - Visual QA: resolves legitimate queued blocking event/talk overlays before performing the existing disabled-item pointer assertion.

## Before/after proof

All captures are under `.tmp/` as required.

| Proof | Evidence |
|---|---|
| Pre-fix Apartment before selection | `.tmp/tutorial_selection_fix_before_1280.png` |
| Pre-fix Apartment selected/focused; view-only relocation visible | `.tmp/tutorial_selection_fix_before_focus_1280.png` |
| Repaired 1280x720 tutorial highlight | `.tmp/tutorial_selection_fix_after_1280.png` |
| Repaired 1280x720 selected/focused state | `.tmp/tutorial_selection_fix_after_focus_1280.png` |
| Repaired focus-clear state; original composition restored | `.tmp/tutorial_selection_fix_after_repeat_1280.png` |
| Repaired 640x360 tutorial highlight | `.tmp/tutorial_selection_fix_after_640.png` |
| Repaired 640x360 selected/focused state | `.tmp/tutorial_selection_fix_after_focus_640.png` |
| Full rendered tutorial sequence across five environments | `.tmp/tutorial_selection_fix_scripted_captures/01_dialogue_highlight_apartment_pal.png` through `18_normal_run_host_greeting.png` |
| Successful rendered capture log | `.tmp/tutorial_selection_fix_scripted_capture_windowed.log` |

The 1280x720 and 640x360 checks used the fresh Web export and real pointer input. Selection opens and focuses the real X-Ray Glasses action; clearing focus returns to the same room composition. Camera movement remains allowed, but it transforms the whole stable scene rather than moving an individual object to a new generated position. The highlight stays attached to the target throughout.

Static captures cannot prove absence of temporal flicker by themselves. The UI regression supplies that proof: repeated equal live anchors leave `live_anchor_change_count` unchanged and preserve `highlight_emphasis`; one actual geometry change increments it exactly once.

The scripted rendered sequence covers Apartment, Corner Store, Gas Casino, Underground Blackjack, and Grand Casino, including their authored coach highlights and TalkDock placements. The bar drink is covered directly by the systems invariant and the UI service-selection invariant.

## Gates

| Gate | Result | Evidence |
|---|---|---|
| `tools/validate_project.ps1` | PASS | `.tmp/tutorial_selection_fix_validate.log` and final systems/UI suite validation stages |
| FoundationSuite systems | PASS | `.tmp/tutorial_selection_fix_systems_final.log`; `.tmp/test_reports/20260803_235239_smoke/summary.json` |
| FoundationSuite ui | PASS | `.tmp/tutorial_selection_fix_ui_final.log`; `.tmp/test_reports/20260803_234018_smoke/summary.json` |
| Determinism, 10 seeds | PASS, 320 checkpoints, hash `3634294742` on both runs | `.tmp/tutorial_selection_fix_determinism.log` |
| General stuck-state sweep, 100 seeds | PASS, `stuck=0` | `.tmp/tutorial_selection_fix_stuck.log` |
| Foundation visual QA | PASS, no warnings | `.tmp/tutorial_selection_fix_visual_qa_final.log` |
| Performance/liveness | PASS, 63 observations; active liveness measurements 49-51 against floor 8 | `.tmp/tutorial_selection_fix_performance.log` |
| Web export | PASS | `.tmp/tutorial_selection_fix_web_export.log` |
| Real-interface Web pointer check | PASS at 1280x720 and 640x360 | after-captures listed above |
| Full rendered tutorial capture matrix | PASS, 18 captures | `.tmp/tutorial_selection_fix_scripted_capture_windowed.log` |

The first attempt to run the rendered capture helper with `--headless` timed out before producing a frame because that helper requires a rendered window. Its two owned Godot processes were stopped, Godot returned quiet, and the intended windowed invocation completed all 18 captures in 15.7 seconds. This was a capture-tool invocation error, not a game gate failure.

## Performance and determinism boundaries

No simulation, seed, generated-layout, object ordering, or outcome logic changed. The repair deletes a reflow scan that could run on overlay movement and adds only equality guards and scalar state updates at action/geometry boundaries. It introduces no per-frame deep copy or allocation. The performance probe remained green, including nonzero idle-animation liveness well above the binding floor.
