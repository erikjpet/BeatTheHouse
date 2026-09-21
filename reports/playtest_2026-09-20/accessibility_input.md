# Beat the House — Accessibility and Input Playtest Report

Date: 2026-09-20  
Tester: `/root/accessibility_input`  
Scope: keyboard and mouse focus, modal cancel behavior, small-screen targets, large-text/UI scaling, reduced motion, settings persistence paths, color/non-color communication, window sizing, and long-text behavior.  
Change policy: diagnostic only. No tracked game, source, test, or data file was modified.

## Executive summary

Five player-facing defects were confirmed. The most serious is that world-map destinations are pointer-only: every destination hit target is explicitly removed from keyboard focus and has no visible or accessible button text. A keyboard-only player can reach the map but cannot select a destination.

The other confirmed defects are:

1. Escape does not close Settings.
2. “Play on small screen” renders environment detail actions only 34 px high, below both the project’s 44 px standard minimum and its 52 px small-screen policy.
3. Dynamically rebuilt gameplay action buttons bypass active large-text and small-screen transforms, reverting to 13 px text and 44 px height.
4. TalkDock still starts a scale/fade attention tween while Reduce Motion is enabled.

All five results reproduced in two consecutive Godot 4.6 runs with identical measurements. These findings are distinct from UIE-023, UIE-024, and UIE-025 in the UI/environment report: they concern input reachability, preference enforcement, and motion rather than environment-label truncation, the High-Limit title asset, or the Corner Store label collision.

## Method and evidence

Static tracing identified candidate paths, after which a diagnostic harness instantiated the production UI classes and exercised their production methods. It did not substitute reimplemented behavior. The harness was run twice, serially, with the project’s bundled Godot 4.6 executable.

- Probe: `.tmp/playtest_2026-09-20/accessibility_input/accessibility_probe.gd`
- Machine-readable evidence: `.tmp/playtest_2026-09-20/accessibility_input/accessibility_probe.json`
- Evidence SHA-256: `CC0FC9864771FB9F1BA067DF996A72BD485C7553E0EDC932607BBFFAD3A1D962`
- Both runs exited 0 and printed the same `ACCESSIBILITY_INPUT_OBSERVATIONS` payload.

The probe’s `PASS` means that every expected defect signature was reproduced; it does not mean the product behavior passed accessibility requirements.

A native-window interaction pass was also attempted. The Windows automation layer could list the live `Beat the House (DEBUG)` window but failed to acquire it twice with a contradictory stale-owner error (“no longer belongs” while reporting the same owner). This was treated as a tooling limitation, not a game defect. No result below relies solely on that failed automation attempt.

## Confirmed defects

### A11Y-001 — World-map destinations cannot be selected by keyboard

- Severity: High
- Frequency: 100%; reproduced in both probe runs and all generated map-node buttons use the same constructor
- Affected input: keyboard, switch input mapped through focus navigation, and assistive technology that depends on focusable controls
- Reproduction:
  1. Open the world map without using a pointer after it appears.
  2. Attempt to Tab to a destination or use directional navigation to select one.
  3. Observe that destination nodes never receive focus; only a prior control or ordinary overlay button can participate in focus traversal.
- Expected: every revealed destination has a focusable, named target; focus enters the map on open; directional or Tab navigation can select a destination and then reach Travel.
- Actual: the destination hit targets have `focus_mode=FOCUS_NONE` (`0`) and empty button text. The only label is a pointer tooltip. The controller contains pointer callbacks but no keyboard node-selection route.
- Evidence: `world_map_nodes[0]` records `focus_mode:0`, `text:""`, `tooltip:"Stop A"`, and `visible:true`. The same result was produced twice.
- Root cause:
  - `_hit_button` creates a flat, empty Button and explicitly assigns `Control.FOCUS_NONE` (`scripts/ui/world_map_overlay_controller.gd:717-731`).
  - Node labels are stored only in `tooltip_text` (`world_map_overlay_controller.gd:527-554`, `557-581`).
  - Opening the overlay clears room selection and shows the map but does not place focus inside it (`scripts/ui/foundation_main.gd:3785-3804`).
  - The map’s Close button is a local variable, preventing the controller from using it as a deterministic entry focus (`foundation_main.gd:10007-10009`).
- Impact: map travel is a core progression boundary. A keyboard-only player cannot complete it without a pointer.
- Fix options:
  1. Make revealed node buttons focusable, assign `accessibility_name`/visible text from the node label, and implement roving spatial focus between map nodes.
  2. Store the Close button and move focus to the nearest revealed node or Close when the overlay opens; restore prior focus when it closes.
  3. Add a keyboard-accessible destination list synchronized with the visual map if spatial navigation is undesirable.
  4. Add an automated contract that selects and confirms a destination using only key events.

### A11Y-002 — Escape does not close the Settings modal

- Severity: Medium
- Frequency: 2/2 direct reproductions
- Reproduction:
  1. Open Settings.
  2. Press Escape.
  3. Repeat after closing/reopening Settings.
- Expected: Escape cancels or closes the modal and returns focus to the control that opened it.
- Actual: Settings remains visible and emits no `back_requested` signal. The probe recorded `visible_after_escape:true` and `back_signal_count:0` in both iterations.
- Root cause:
  - `SettingsMenu._input` handles Tab trapping only and contains no `ui_cancel` branch (`scripts/ui/settings_menu.gd:178-196`).
  - The application-level input router only handles web-audio gestures and TalkDock hotkeys (`scripts/ui/foundation_main.gd:778-784`); it does not route modal cancel.
  - The existing focus-return implementation runs only after some other path hides Settings (`settings_menu.gd:204-219`).
- Impact: mouse users have a Back button, but keyboard users lose the standard modal cancel path and must traverse the entire Settings focus loop to reach Back.
- Fix options:
  1. Add `ui_cancel` handling to SettingsMenu that emits `back_requested` and marks the event handled.
  2. Prefer a central modal-cancel router with explicit priority so Escape closes only the topmost dismissible overlay.
  3. Add two tests: Escape after opening from the main menu and Escape after opening from the run menu, both asserting focus restoration.

### A11Y-003 — Small-screen environment action targets are only 34 px high

- Severity: High on touch devices; Medium elsewhere
- Frequency: 100%; identical in both probe runs
- Reproduction:
  1. Enable “Play on small screen.”
  2. Focus an environment object with a primary or inline detail action.
  3. Measure the action hit rectangle.
- Expected: interactive controls meet the project’s 52 px small-screen target policy and never fall below the project’s 44 px native minimum.
- Actual: both primary and inline action heights are 34 px. The evidence records `primary:34`, `inline:34`, `minimum_native:44`, and `small_screen_control_target:52`.
- Root cause:
  - The small-screen policy hard-codes `ENVIRONMENT_ACTION_HEIGHT` and `ENVIRONMENT_INLINE_ACTION_HEIGHT` to 34 (`scripts/ui/small_screen_policy.gd:14-15`) even though the same policy defines `CONTROL_TOUCH_TARGET_HEIGHT=52` (`small_screen_policy.gd:10`).
  - PixelSceneCanvas returns those 34 px constants when small-screen mode is active (`scripts/ui/pixel_scene_canvas.gd:3982-3987`) and uses them for drawn action rectangles (`pixel_scene_canvas.gd:4071-4082`, `4436-4443`).
- Impact: the preference promises larger controls and tap areas, but these gameplay-critical actions remain 18 px smaller than that promise and 10 px smaller than the standard minimum.
- Fix options:
  1. Set both small-screen action heights to at least 52 px and recompute detail-card height/placement.
  2. If visual rows must remain compact, retain the visual 34 px row but expand each nonoverlapping hit rectangle to 52 px.
  3. Add a layout audit that enumerates every clickable rect, not only native Buttons, under small-screen mode.

### A11Y-004 — Rebuilt gameplay actions lose large-text and small-screen sizing

- Severity: High
- Frequency: 2/2 direct reproductions; the helper has 51 call sites
- Reproduction:
  1. Enable Large text, UI Scale 130%, and Play on small screen, then apply.
  2. Trigger a gameplay refresh that rebuilds an environment/event/numbers action card.
  3. Inspect the newly created action buttons.
- Expected: dynamically created controls inherit the active accessibility font scale and the 52 px small-screen minimum.
- Actual: new card buttons are created at the unscaled defaults: 13 px font and 44 px height. Both probe iterations reported `font_size:13`, `height:44`, and `expected_small_screen_height:52`.
- Root cause:
  - Applying settings transforms the existing tree first, then rerenders gameplay snapshots (`scripts/ui/foundation_main.gd:16259-16268`).
  - Rerendered cards call `_add_card_button`, which directly delegates to `FoundationWidgets.add_card_button` without applying the host’s active accessibility transform (`foundation_main.gd:19936-19937`).
  - The shared helper always authors 44 px / 13 px defaults (`scripts/ui/foundation_widgets.gd:37-54`, `77-83`).
  - The host’s accessible `_button` path does apply current small-screen sizing (`foundation_main.gd:20760-20764`), but the dynamic card helper bypasses it.
- Impact: settings screens pass their target-size checks while core gameplay actions silently revert after refresh, creating inconsistent text and touch sizes precisely where the player acts.
- Fix options:
  1. Route dynamic action construction through the host’s accessibility-aware `_button` helper.
  2. Apply `_apply_accessibility_to_node` to every newly created subtree before it becomes interactive.
  3. Reorder settings application so rerender completes before the recursive transform, while still making future dynamic creation accessibility-aware.
  4. Extend tests to apply settings, rebuild an environment card and an event popup, then assert effective font and target sizes.

### A11Y-005 — TalkDock attention motion still runs with Reduce Motion enabled

- Severity: Medium
- Frequency: 2/2 direct reproductions
- Reproduction:
  1. Enable Reduce Motion.
  2. Present a new TalkDock entry.
  3. Inspect the dock panel and portrait immediately after the entry changes.
- Expected: the entry appears in its settled state with no fade or scale tween.
- Actual: the panel starts at alpha `0.88`, the portrait starts at scale `1.04`, and an attention tween is created. Repeating the presentation created a second tween while `reduce_motion:true` remained active.
- Root cause:
  - Every new TalkDock entry unconditionally calls `_play_attention_animation` (`scripts/ui/talk_dock.gd:324-343`).
  - `set_reduce_motion` completes the typewriter and updates the portrait idle-animation policy, but does not cancel/normalize attention tweens (`talk_dock.gd:535-541`).
  - `_play_attention_animation` has no reduced-motion guard and always applies alpha/scale offsets plus 0.12/0.18-second tweens (`talk_dock.gd:1307-1319`).
  - CoachOverlay implements the missing pattern correctly by returning early when reduced motion is active (`scripts/ui/coach_overlay.gd:971-978`), confirming the intended policy.
- Impact: recurring dialogue produces motion despite an explicit user preference intended to suppress it.
- Fix options:
  1. Return early from `_play_attention_animation` when `reduce_motion` is true after normalizing panel alpha and portrait scale.
  2. When Reduce Motion is enabled mid-animation, kill active attention tweens and settle both controls immediately.
  3. Add a test that presents two consecutive entries with Reduce Motion enabled and asserts no valid tween and settled transforms.

## Coverage and pass notes

| Area | Coverage/result |
|---|---|
| Settings Tab containment | Static path reviewed. Settings builds a focus-control cache, traps forward/reverse Tab, and skips hidden/disabled controls (`settings_menu.gd:183-208`). No defect promoted. |
| Settings focus return | Static path reviewed. Previous focus is captured on open and restored when the menu becomes hidden (`settings_menu.gd:60-68`, `204-219`). Escape fails to trigger that otherwise valid path (A11Y-002). |
| Settings serialization | `UserSettings.to_dict/from_dict` includes UI scale, text size, Reduce Motion, high contrast, small-screen mode, and coach tips (`scripts/core/user_settings.gd:88-145`). Invalid enum/range values are clamped or defaulted. No persistence defect found in review. |
| Window sizing | Project is intentionally non-resizable and the runtime enforces a selected 16:9 size (`project.godot`; `user_settings.gd:214-276`). Arbitrary resize testing was excluded as unsupported product behavior, not reported as a bug. |
| Map pointer target sizing | Small-screen map nodes expand to 60×60 (`small_screen_policy.gd:11`, `world_map_overlay_controller.gd:734-744`). Pointer sizing passes; keyboard reachability fails (A11Y-001). |
| Environment object targets | Small-screen environment object hit regions use 104×76 (`art_contracts.gd:9`; `pixel_scene_canvas.gd:4908-4925`). The nested detail actions fail independently (A11Y-003). |
| Inventory/meta Escape | Both `RunInventoryScreen` and `MetaItemInteractionScreen` implement `ui_cancel` handlers (`run_inventory_screen.gd:674-678`; `meta_item_interaction_screen.gd:287-291`). Not promoted as defects. |
| Reduced motion — canvases | Environment and game-surface canvases contain explicit reduced-motion freeze/snap paths. No additional defect was confirmed in this pass. TalkDock attention is the exception (A11Y-005). |
| High contrast/non-color cues | The shared palette exposes a dedicated high-contrast mapping and preserves text labels alongside status color in reviewed core HUD/settings paths. No confirmed color-only blocker was promoted. |
| Long text | Existing scroll/wrap paths were inspected in Settings, event-choice popups, TalkDock, and career stats. UIE-023/UIE-024 already own the confirmed label/title truncation findings; no duplicate filed here. |

## Tooling limitation and exclusions

- Windows automation could not acquire the live Godot window after discovering it; the exact failure was retained as a test-infrastructure note and not counted as a game issue.
- No screen-reader hardware/software session was available. Static review shows custom-drawn canvases rely heavily on one Control plus hit rectangles, but this was not promoted without a direct assistive-technology run.
- Haptics are explicitly unsupported by the current product and documented as such in Settings; they were excluded rather than treated as a bug.
- No arbitrary window-resize finding was filed because the project intentionally disables resize and offers fixed 16:9 resolution choices.

## Recommended triage order

1. Fix A11Y-001 first because the map is a required progression boundary and currently blocks keyboard-only play.
2. Fix A11Y-004 and A11Y-003 together so the advertised small-screen/large-text settings hold across native and custom-drawn action surfaces.
3. Add the central modal cancel/focus policy for A11Y-002 and cover Settings plus the map with keyboard tests.
4. Add the reduced-motion guard and tween cancellation for A11Y-005.

## Count reconciliation

- Confirmed player-facing defects: **5**
- High: **3** (A11Y-001, A11Y-003 on touch, A11Y-004)
- Medium: **2** (A11Y-002, A11Y-005)
- Tool/harness defects counted as game bugs: **0**
