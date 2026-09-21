# Beat the House — Extended Accessibility, Input, and Resolution Playtest

Date: 2026-09-20  
Owner: Accessibility/Input specialist  
Disposition: investigation and documentation only; no product files were changed to fix defects  
Scope: keyboard-only, pointer-only, mixed-input transitions, modal focus, overlay stacking, controller mappings, large text, high contrast, Reduce Motion, small-screen presentation, multiple aspect ratios, live resize, and every environment archetype

## Executive summary

This extended pass confirmed **four new player-facing defects** beyond A11Y-001 through A11Y-005:

1. Decision/meta popups do not acquire or contain focus. Keyboard input can activate controls hidden behind the popup and create an overlay state that the game's own contract marks invalid.
2. The world map is clipped below 860×540, including the code-enforced 640×360 safe-window floor.
3. Settings with Large text and 130% UI scale is taller than the code-enforced 640×360 safe-window presentation, placing its lower controls off-screen.
4. Global UI input maps directional controller navigation but does not map controller accept or cancel, leaving most non-game-surface UI impossible to complete with a controller alone.

The exhaustive room sweep covered all 18 environment archetypes twice at a 640×360 logical viewport with small-screen mode, Large text, 130% UI scale, high contrast, and Reduce Motion. Across 36 room presentations and 298 generated objects, every object accepted programmatic focus, every selected-object composition stayed inside the viewport, directional selection changed objects, and pointer selection hit its intended first object. Existing authored object overlaps were observed and classified as duplicates of UIE-001 through UIE-025 rather than refiled.

## Evidence and method

Two read-only runtime probes instantiated the shipping `MainScene` and used production controls, layout methods, input handlers, and overlay contract checks. Test profiles were isolated below `.tmp/playtest_extended/accessibility_input`; no player profile, tracked product file, or content data was changed.

- Overlay/resolution evidence: `.tmp/playtest_extended/accessibility_input/extended_overlay_probe.json`
  - SHA-256: `DE0C35A21CC019DDAE3C6B55C19D14D4A665ABB8DD98F2ED97A2D0D977C9DCC2`
- All-room/input evidence: `.tmp/playtest_extended/accessibility_input/all_room_input_probe.json`
  - SHA-256: `A2F94DC6D797BB3151B441D0E713D1189EBF6573F0AF0C09BAAC1813B37CE441`
- Probe sources:
  - `.tmp/playtest_extended/accessibility_input/extended_overlay_probe.gd`
  - `.tmp/playtest_extended/accessibility_input/all_room_input_probe.gd`

The overlay matrix covered 1280×720, 1024×768, 960×540, 800×450 during edge resize, and 640×360. The evidence explicitly records `logical_viewport: 640×360`; this was not inferred from the host window. The 640×360 case is not a selectable `RESOLUTIONS` entry—those begin at 1280×720 (`scripts/core/user_settings.gd:11-16`)—but it is the runtime's own minimum safe-window floor (`user_settings.gd:264-276`).

The all-room sweep ran twice. Cycle one generated 151 objects and cycle two generated 147 objects. Each cycle covered Corner Store, Back Alley, Motel, Bar, Gas Station Casino, Small Underground Casino, Jazz Club, Kitty Cat Lounge, Delta Queen, Beach, Pawn Shop, all four Grand Casino room variants, Motel Room, Apartment, and House.

Native desktop computer-control acquisition failed twice with a stale/contradictory ownership response, so hardware-level UI automation was unavailable. That is recorded as a tooling limitation, not a game defect. The fallback still exercised the real scene tree and production input routes rather than mocks.

## New defects

### A11Y-006 — Decision popups leak keyboard focus to obscured controls

- Severity: **High**
- Frequency: **2/2 fresh production-scene repetitions**
- Affected users: keyboard-only players, controller/switch users routed through focus navigation, screen-reader users, and any player who mixes pointer and keyboard input
- Reproduction:
  1. Put focus on the main-menu Settings button.
  2. Open a dismissible meta decision popup with a visible Back choice.
  3. Observe focus after the popup appears.
  4. Press Escape, then Enter.
  5. Query the production overlay contract.
- Expected: focus moves to a meaningful choice inside the popup, Tab/focus stays within it, Escape closes the dismissible popup, and underlying controls cannot activate.
- Actual: focus remains on the obscured Settings button. Escape does not close the popup. Enter activates Settings behind it, leaving both Settings and the decision popup visible. `current_overlay_state_snapshot()` returns `contract_valid:false` with `decision_popup overlaps settings_visible` in both repetitions.
- Evidence:
  - `focus_before`, `focus_after_show`, and `focus_after_escape` are the same Settings button in both iterations.
  - `first_choice_has_focus:false` in both iterations even though the Back button exists.
  - `popup_visible_after_escape:true`, `popup_visible_after_enter:true`, and `settings_visible_after_enter:true` in both iterations.
- Root cause:
  - `_show_meta_popup()` builds snapshot state, reveals the overlay, moves it to front, and positions it, but never calls `grab_focus()` or installs a focus trap (`scripts/ui/foundation_main.gd:17061-17083`).
  - The same show-without-focus pattern exists in triggered event popups (`foundation_main.gd:4854-4904`) and wager confirmation (`13051-13077`), so the defect is structural rather than meta-popup-specific.
  - Choice buttons are created as ordinary Buttons (`foundation_main.gd:13080-13117`), but no first-choice reference is focused after creation.
  - `FoundationMain._input()` handles web audio and TalkDock only (`foundation_main.gd:778-784`); it has no topmost-modal `ui_cancel` route.
  - `_hide_event_choice_popup()` clears the popup but does not restore a saved prior focus owner (`foundation_main.gd:18975-19005`).
- Impact: a modal decision is not actually modal to keyboard input. Hidden actions can execute, overlays can stack illegally, and blocking event choices may leave focus on an unrelated background control.
- Fix options:
  1. Create a shared modal focus controller that stores the prior focus owner, focuses the preferred/first enabled choice on open, traps navigation, and restores focus on close.
  2. Route `ui_cancel` by explicit topmost-overlay priority, honoring each popup snapshot's `dismissible` flag and refusing cancel for blocking decisions.
  3. Guard global/open-overlay actions while a decision popup owns input; do not rely on draw order as an input barrier.
  4. Add keyboard and controller tests for every event-popup constructor, including background-button activation and contract validity.

### A11Y-007 — World map is clipped at the code-enforced minimum safe window

- Severity: **High**
- Frequency: **2/2 static 640×360 presentations and 2/2 live-resize sequences**
- Affected configurations: small monitors where `_safe_window_size()` scales the selected 16:9 resolution down, plus any equivalent embedded/small-screen logical viewport
- Reproduction:
  1. Run at a 640×360 logical viewport, the safe-window lower bound.
  2. Enable small-screen mode and open the world map.
  3. Repeat by opening the map at 1280×720 and resizing through 960×540, 800×450, and 640×360.
- Expected: the entire map panel, Close control, destinations, detail card, and Travel control remain within the visible viewport.
- Actual:
  - At 640×360, the panel rect is `x=-110, y=-90, w=860, h=540`.
  - At 800×450, it is `x=-30, y=-45, w=860, h=540`.
  - It fits at 1280×720 and exactly vertically at 960×540, then clips identically in both resize repetitions.
- Root cause:
  - The panel has a fixed 860×540 minimum and fixed center offsets of ±430/±270 (`scripts/ui/foundation_main.gd:9978-9987`).
  - Its holder and map layer retain 800×430 minimums (`foundation_main.gd:10018-10027`).
  - The small-screen accessibility update configures the map controller's target behavior but does not replace or clamp those host panel dimensions.
  - `_safe_window_size()` explicitly permits a 640-pixel width (`scripts/core/user_settings.gd:264-276`), so the window floor and modal minimum contradict each other.
- Impact: Close, destinations, and Travel can lie partly or wholly outside the visible frame. This compounds A11Y-001, but it is a separate responsive-layout failure affecting pointer users too.
- Fix options:
  1. Clamp panel size to the viewport minus safe margins and replace fixed offsets with full-rect anchors plus a centered responsive container.
  2. Scale or scroll the 800×430 map content at narrow sizes while keeping node hit targets at their small-screen minimum.
  3. Recompute bounded geometry on `NOTIFICATION_RESIZED` while the overlay is open.
  4. Add assertions for 1280×720, 960×540, 800×450, and the 640×360 safe-window floor.

### A11Y-008 — Large-text Settings extends below the minimum safe window

- Severity: **Medium**
- Frequency: **2/2 repeated minimum-window checks**, plus the standalone matrix case
- Configuration: 640×360 logical viewport, small-screen mode, Large text, UI scale 130%
- Reproduction:
  1. Present the game at the 640×360 `_safe_window_size()` floor.
  2. Enable Play on small screen, Large text, and 130% UI scale.
  3. Open Settings.
- Expected: the outer Settings panel fits inside the viewport; its internal scroll region exposes every setting and the bottom action row.
- Actual: the Settings rect is `x=88, y=60, w=464, h=447` in a `640×360` logical viewport. Its bottom is at y=507, 147 pixels below the frame. The same geometry was recorded in both resize repetitions.
- Boundary result: the same accessibility configuration fits at 960×540 (`x=88, y=60, w=784, h=447`) and at 1024×768.
- Root cause:
  - The base overlay applies fixed 48-pixel top and bottom margins (`scripts/ui/foundation_main.gd:9628-9631`).
  - Small-screen policy changes only the left/right margins to 72 pixels (`foundation_main.gd:20596-20603`; `scripts/ui/small_screen_policy.gd:18`). It does not reduce or bound vertical margins.
  - The Settings list scroll container has a 300-pixel minimum (`scripts/ui/settings_menu.gd:82`); headings, section spacing, and the action row expand the outer menu beyond the remaining 264 vertical pixels.
  - Accessibility scaling correctly enlarges content but no outer `ScrollContainer` or viewport clamp absorbs the expansion.
- Impact: the lowest actions can be visually inaccessible on the runtime's own minimum safe-window presentation. Keyboard focus can still move into off-screen controls, which makes focus disappear rather than solving access.
- Fix options:
  1. Make the modal panel height viewport-bounded and keep heading/action controls fixed while only the settings body scrolls.
  2. Apply responsive vertical margins and remove the 300-pixel scroll minimum when available height is smaller.
  3. Call `ensure_control_visible()` on focus changes so keyboard traversal never leaves the focused control off-screen.
  4. Add 640×360 tests at every text/UI-scale combination, including visibility of Back, Restore Defaults, and Apply.

### A11Y-009 — Controller can navigate globally but cannot accept or cancel

- Severity: **High**
- Frequency: **Deterministic configuration defect; directional path exercised in all 18 rooms in both cycles**
- Affected input: controller/gamepad outside the few surfaces with local hard-coded button handling
- Reproduction:
  1. Inspect the production InputMap and use a controller on a room or ordinary Godot Button screen.
  2. Move selection with D-pad or left stick.
  3. Press the controller's south/A button to activate, or east/B to cancel.
- Expected: controller directions map to `ui_left/right/up/down`, the south/A button maps to `ui_accept`, and east/B maps to `ui_cancel`.
- Actual:
  - Each directional action includes D-pad and left-stick joypad events.
  - `ui_accept` includes only Enter, keypad Enter, and Space.
  - `ui_cancel` includes only Escape.
  - Both room sweeps proved the directional selection route changes objects in every applicable room, but the common activation/cancel actions have no joypad event to deliver.
- Root cause:
  - `PixelSceneCanvas._gui_input()` activates selected actions only through `event.is_action_pressed("ui_accept")` (`scripts/ui/pixel_scene_canvas.gd:803-827`).
  - Inventory/meta modal cancel paths likewise depend on `ui_cancel` (`scripts/ui/run_inventory_screen.gd:675`; `scripts/ui/meta_item_interaction_screen.gd:288`).
  - The generic InputMap lacks joypad accept/cancel events, while `GameSurfaceCanvas` locally special-cases `JOY_BUTTON_A` (`scripts/ui/game_surface_canvas.gd:1056-1062`). That workaround proves controller confirmation was intended but is isolated to game surfaces.
- Impact: controller users can visibly move selection but cannot complete the action, close common screens, or reliably proceed without switching to a keyboard/mouse.
- Fix options:
  1. Add standard joypad A/south and B/east mappings to `ui_accept` and `ui_cancel` at the project level.
  2. Remove per-surface confirmation exceptions after the shared actions are authoritative, or retain them only for hold semantics with duplicate suppression.
  3. Add a no-keyboard controller smoke path: start run, inspect/activate an object, enter/exit a game, open/close inventory, acknowledge/cancel dismissible overlays, and navigate Settings.

## Duplicates reconfirmed, not refiled

| Existing ID | Extended observation |
|---|---|
| A11Y-001 | World-map node controls remain outside focus navigation. The responsive clipping in A11Y-007 is separate. |
| A11Y-002 | Settings still has no Escape route because `SettingsMenu._input()` traps Tab only (`settings_menu.gd:178-196`). A11Y-006 broadens the same missing modal policy to event/meta popups but adds background activation and illegal overlay stacking. |
| A11Y-003 | Small-screen custom-drawn action heights remain below the shared native target standard; no new root cause was found. |
| A11Y-004 | Dynamically rebuilt gameplay buttons still bypass accessibility scaling. A11Y-008 concerns the outer Settings geometry, not rebuilt gameplay actions. |
| A11Y-005 | TalkDock Reduce Motion behavior remains owned by the original report. Reduced-motion mode was enabled throughout the all-room sweep; no additional motion source was promoted. |
| UIE-001–UIE-025 | The generated small-screen cycles recorded 21 and 23 object-rectangle overlaps, concentrated in the same dense rooms already covered by the UI/environment report. They were not counted again. No resolved label overlaps were reported in these two seeds. |

## Passed coverage

| Area | Result |
|---|---|
| All environment archetypes | **Pass with known overlap duplicates.** 18/18 rooms loaded in each of two cycles at a 640×360 logical viewport. |
| Object focus and selected compositions | **Pass.** 298/298 generated objects accepted focus; all non-empty selected-object composition rects fit the viewport. |
| Keyboard directional room navigation | **Pass.** Selection changed on `ui_right` in every applicable room in both cycles (36/36 room checks). |
| Pointer room selection | **Pass.** Production hit testing selected the intended first object in every room in both cycles (36/36). |
| Rapid mixed path | **Pass within harness scope.** Each room alternated programmatic focus, keyboard-direction routing, mouse hover, and mouse press without a stuck selection, crash, or hidden modal. Hardware-level timing injection was unavailable. |
| Environment canvas bounds | **Pass.** Canvas global rect stayed within 640×360 for all 36 room presentations. |
| Selected-card bounds | **Pass.** No selected detail/action composition extended outside the 640×360 viewport across 298 object checks. |
| Settings focus entry | **Pass at fitting sizes.** Settings focuses the first OptionButton at 1280×720, 1024×768, and 960×540; A11Y-008 owns the 640×360 outer-bound failure. |
| Settings Tab containment | **Static pass.** Existing focus cache loops forward/reverse Tab through visible enabled controls. Escape remains A11Y-002. |
| 4:3 presentation | **Pass for tested overlays at 1024×768.** World map and Large-text Settings fit. |
| 960×540 compact presentation | **Pass for tested overlays.** World map fits exactly vertically and Large-text Settings fits. |
| High contrast | **Pass for state application.** High-contrast mode applied throughout both room cycles without loss of object focus/hit routing. Visual colorimetry was not measured. |
| Reduce Motion | **Pass except existing A11Y-005.** No additional motion defect was promoted. |
| Game-surface controller confirmation | **Local code path present.** `GameSurfaceCanvas` explicitly handles joypad A; A11Y-009 is the missing global mapping around it. |
| Runtime stability | **Pass.** Both exhaustive room cycles completed with zero harness failures and no fatal/runtime script error. Godot reported an ObjectDB leak warning on harness teardown; because the probe force-quits immediately after queue-free and the shipped long-play/package agents own memory-leak evaluation, it was not promoted here. |

## Exclusions and confidence notes

- No physical controller was available. A11Y-009 is based on the runtime's resolved InputMap and exact production event predicates, not a vendor-specific device test. Vendor labels, hot-plug behavior, rumble, and Steam Input remapping remain outside this pass.
- Arbitrary desktop resize is normally disabled (`UserSettings._apply_window()`), but the tested 640×360 case is still in scope because `_safe_window_size()` deliberately produces that lower bound on constrained displays. Edge resize was additionally used to expose the precise breakpoints.
- The harness directly invoked production handlers for deterministic automation. It did not simulate screen-reader speech output or OS accessibility APIs.
- Randomized room population explains the cycle totals of 151 versus 147 objects. Both cycles covered every room and every object generated in that cycle.

## Recommended triage order

1. Fix A11Y-006 first: it violates the game's own overlay contract and permits hidden actions during decisions.
2. Fix A11Y-009 next so controller navigation can complete actions instead of dead-ending after selection moves.
3. Resolve A11Y-007 and A11Y-008 together with a shared viewport-bounded modal layout policy tested at the 640×360 safe-window floor.
4. Keep the prior A11Y-001/A11Y-002 repairs in the same modal/input workstream so focus entry, cancel priority, focus restoration, and controller actions are implemented once rather than screen by screen.
