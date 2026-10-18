# Beat the House — Post-Fix UI, Environment, Input, and Lifecycle Playtest

Date: 2026-09-21  
Owner: `/root/ui_environment`  
Build: `b7c51bf4` (`Remediate code health audit`)  
Disposition: investigation and documentation only; no product source or data was modified.

## Executive summary

This independent post-fix wave retained **nine defects**: eight High and one Medium. Two are UI/lifecycle regressions outside the previous tests, six are distinct authored scenario/base placement pairs that prevent a destination room from loading, and one is a latent small-screen validator omission.

The broad generation pass executed 100 deterministic seeds with a target of six visits each. It completed all 100 seed attempts, but 22 runs stopped on room finalization, producing 519 successful environment visits instead of 600. The 22 failures reduce to six distinct player-facing layout pairs: Bar Fight Night safe-exit reachability (10), Gas Station Road Crew station versus Side Door (6), Corner Store Dead Shift exit versus Town Rumor Staff (3), the same exit versus Late Shift Discount (1), Count Cage versus Inventory Night Count (1), and Count Cage versus Parking Lot Tip (1).

The focused input probes additionally proved that canceling an active hold while opening a modal clears the pause state it just established, allowing surface simulation to advance behind the modal, and that World Map Tab focus escapes to a background room action in 2/2 repetitions.

Prior findings were not blindly carried forward. The prior base-room placement, Bar Dice layering, label ellipsis, responsive sizing, controller mapping, event-popup focus, application lifecycle, Settings rollback, player-text, currency, plural, and clock defects all have targeted remediation in the current tree and their focused post-fix contracts passed. The old scenario-overlap family is not considered fully closed, however: its original silent ambiguity was replaced by six fail-closed room-install failures documented here.

## Coverage and evidence

- Focused edge probe: `.tmp/playtest_2026-09-21/ui_environment/postfix_edge_probe.json`
  - SHA-256: `A3823F8E2F3E49A75ADB7C6263B0CCB6AF13F9EFEFA216308F9383A4000687E7`
- World Map focus probe: `.tmp/playtest_2026-09-21/ui_environment/modal_focus_probe.json`
  - SHA-256: `A65BED0282BAE5567F10A9B6C1F9DCA9D9A44CC02AC87A344D1EADCC766070D4`
- 100-seed generation audit: `.tmp/playtest_2026-09-21/ui_environment/env_generation.json`
  - SHA-256: `5D9C3D1955664100D5EE20248C54685E3BB1F8B70476131A824151396EFEFE52`
  - Summary: `passed:false`, 22 failures, 0 warnings, 519 successful visits.
- Focused shipping contracts:
  - `FIXSWEEP06_1_LIFECYCLE PASS`
  - `FIXSWEEP06_1_ACCESSIBILITY PASS`
  - `FIXSWEEP06_1_PLAYER_TEXT PASS`
- Static content inventory: all 18 environment archetypes, all five scenario-sequence files, and all 55 scenario definitions were inspected/parsed. The bounded random runtime pass reached 13/18 archetypes; Jazz Club and the four Grand Casino subrooms were not selected in those 100 six-visit routes. They therefore have static and prior-contract coverage here, not a fresh visual runtime claim.
- Input modalities: production mouse capture and keyboard focus were exercised directly. Touch shares the same capture-clear routine; controller A/B mappings and controller-facing focus routes were checked by the accessibility contract and `project.godot`. No physical touch panel or controller was available.
- Final runtime hygiene: `GODOT_COUNT=0` before handoff.

## Findings

### UIENV-PF-001 — Canceling an active hold clears modal and lifecycle pause state

- Severity: **High**
- Confidence: **High; direct production-class runtime proof plus exact control-flow root**
- Frequency: **1/1 modal-during-hold and 1/1 application-focus-out-during-hold**
- Affected input: mouse/touch drag capture and keyboard/controller hold capture on `GameSurfaceCanvas`; wager-bearing hold surfaces are the highest-risk case.

Reproduction:

1. Start a hold/drag in a registered game-surface hold region.
2. While it is captured, open a modal through `set_modal_activity_paused(true)`.
3. Inspect the pause contract and tick the surface for 250 ms.
4. Repeat with `handle_application_lifecycle(false)` during an active capture.

Expected: the interrupted gesture emits exactly one cancel, capture clears, modal simulation/timed-feedback pause remains true, and application focus-out retains orphan-event rejection until a fresh press.

Actual: both captures emit `begin, cancel`, but `_clear_captured_surface_pointer_state()` also resets `environment_activity_paused`, `timed_feedback_paused`, and `reject_orphan_surface_events` to false. The focused probe then advanced the simulation clock by exactly 250 ms behind the modal; the surface-audio snapshot was also unpaused. Focus-out ended with `reject_orphan_surface_events:false`.

Impact: a modal or Alt-Tab can cancel the visible gesture yet briefly resume the underlying game's simulation, timed feedback, and surface audio. On stateful or wager-bearing surfaces this creates an input/lifecycle race the player cannot observe.

Root cause:

- `scripts/ui/game_surface_canvas.gd:132-146` sets both pause flags before canceling capture.
- `game_surface_canvas.gd:149-155` sets the orphan-event latch before canceling capture.
- `_cancel_captured_surface_pointer()` at `game_surface_canvas.gd:1253-1257` delegates to `_clear_captured_surface_pointer_state()`.
- That generic clear routine resets all three caller-owned lifecycle flags at `game_surface_canvas.gd:1260-1269`.
- The existing lifecycle contract opens a modal without an active capture, so it passes and misses the destructive interaction between the two paths.

Fix options:

1. Make capture clearing clear capture fields only; lifecycle/pause ownership must remain exclusively with their callers.
2. If a full reset is required for teardown, split it into a separate explicit routine and never use it for modal/focus cancellation.
3. Add mouse, touch, keyboard, and controller tests that open a modal and focus out during `begin`, then assert one cancel, frozen clocks/audio, retained orphan rejection, and no later stale `end`.

### UIENV-PF-002 — World Map Tab focus escapes to a background room control

- Severity: **High**
- Confidence: **High; 2/2 production-scene repetitions**
- Frequency: **2/2; escaped on the third Tab in both seeds**
- Affected users: keyboard-only, controller/switch focus navigation, and assistive technology users.

Reproduction:

1. Start a run and open World Map before selecting a destination.
2. Confirm initial focus is on a map destination.
3. Press Tab repeatedly.

Expected: focus cycles among enabled map destinations and Close; the disabled Travel control is skipped without leaving the modal.

Actual: the first two Tabs move among destination nodes. The third moves to a visible run-screen Button below `WorldMapOverlay`, while the map stays open. This occurred in both repetitions with different destination sets.

Impact: focus becomes visually detached from the modal. Keyboard/controller users can no longer tell what owns activation, and background actions can receive focus while the map blocks pointer interaction.

Root cause:

- `FoundationMain._input()` traps focus only for event-choice popups (`scripts/ui/foundation_main.gd:782-794`); World Map has no equivalent modal-wide trap.
- `WorldMapOverlayController._refresh_spatial_focus_neighbors()` links the last node to Travel and Travel back to the first (`scripts/ui/world_map_overlay_controller.gd:799-818`).
- Travel is disabled before selection and Close is absent from this focus ring, leaving Godot to choose the next enabled control in the scene tree.

Fix options:

1. Add a shared topmost-modal focus trap and include Close, visible enabled destinations, and enabled Travel.
2. Rebuild the ring whenever destination selection changes Travel's enabled state.
3. Add forward/reverse Tab and controller shoulder/D-pad tests both before and after selecting a destination, asserting every focus owner remains under `WorldMapOverlay`.

### UIENV-PF-003 — Bar Fight Night safe exit makes the Bar unloadable

- Severity: **High**
- Confidence: **High; ten independent random seeds**
- Frequency: **10/100 run seeds; deterministic when Bar Fight Night is selected in the failing composition**

Reproduction: run the environment generation audit with seed prefix `POSTFIX-UIENV`; affected examples include `...009-4151570434`, `...015-1938529946`, `...031-2491917705`, `...036-3073861592`, `...037-655530953`, `...043-934268634`, `...054-1002983031`, `...073-140575119`, `...093-397681310`, and `...098-1674379668`, then travel to Bar.

Expected: Fight Night installs with its safe exit reachable from the player access lane, or deterministic placement chooses a reachable fallback.

Actual: travel fails room finalization with `Scenario interaction scenario::bar_fight_night_safe_exit is not reachable from the player access lane.` The run stops rather than entering Bar.

Impact: a normally available destination cannot be entered, ending further travel/playtest progression for that run.

Root cause: the scenario authors a 64x56 safe-exit interaction (`data/environments/scenario_sequences/env06_7_bars_road.json:1994-2037`) into the extreme-right slot `[840,300]` alongside Fight Night blockers (`data/environments/placement_surfaces.json:42`). Placement resolves visuals first, then `_validate_interactions()` requires both normal and expanded-small-screen path reachability and rejects the projection at `scripts/core/scenario_layout_resolver.gd:786-795`. The authored safe-exit/blocker composition has no reachable accepted fallback.

Fix options: reserve a guaranteed walk-lane-connected doorway for every safe exit; constrain blockers away from its approach corridor; or add reachable route-aware candidates and require the safe-exit reachability invariant during content validation.

### UIENV-PF-004 — Road Crew Payday station collides with Side Door and blocks Gas Station travel

- Severity: **High**
- Confidence: **High; six independent seeds with identical geometry**
- Frequency: **6/100 run seeds**
- Exact pair: `scenario::gas_station_road_crew_payday_station` `[578,327,64,56]` versus `event::event:side_door` `[611,346,100,64]`.

Reproduction seeds: `...007-2898334884`, `...008-2688401675`, `...018-2408131097`, `...033-405233240`, `...082-1306411836`, and `...092-1191177531`; travel to Gas Station Casino when Road Crew Payday is active.

Expected: the scenario audit station and room Side Door have exclusive hit authority, or one is deterministically moved before the room commits.

Actual: their normal hit rectangles intersect and travel fails; the destination is not installed.

Root cause: the Road Crew interaction is a 56x56 station (`env06_7_roadside_shelter.json:11071-11097`) authored near `[650,330]`, while Gas Station Side Door is an active base event in the same lower-right area (`placement_surfaces.json:53,55`). Scenario recovery can exhaust candidates and return its grounded rect as `crowded:true, colliding:false` (`scenario_layout_resolver.gd:1327-1414`); the later base-authority audit correctly rejects the remaining normal overlap at `scenario_layout_resolver.gd:829-845`, too late to recover the room.

Fix options: reserve the station footprint against base events; give the station a dedicated alternative surface; or make the final audit feed a conflicting base identity back into a second deterministic repack rather than immediately aborting travel.

### UIENV-PF-005 — Dead Shift exit collides with Town Rumor Staff

- Severity: **High**
- Confidence: **High; three independent seeds with identical geometry**
- Frequency: **3/100 run seeds**
- Exact pair: `scenario::corner_store_dead_shift_exit` `[690,330,72,56]` versus `event::event:town_rumor_staff` `[648,329,100,64]`.

Reproduction seeds: `...061-1987792568`, `...062-84881432`, and `...087-3894813921`; travel to Corner Store when Dead Shift and Town Rumor Staff compose.

Expected: the marked safe exit and staff event retain separate hit authority.

Actual: final validation reports ambiguous normal authority and aborts Corner Store installation.

Root cause: Dead Shift declares a 64x56 safe exit (`env06_7_shops_streets.json:4881-4905`) and the room surface map supplies an authored exit slot, but dynamic placement resolves it into the same lower-right band as the 100x64 staff event. The crowded fallback/late rejection path is the same as PF-004 (`scenario_layout_resolver.gd:1327-1414, 829-845`).

Fix options: dedicate/reserve the marked-exit corridor; relocate the staff event when this scenario is active; or repack on the exact conflicting base identity before finalization.

### UIENV-PF-006 — Dead Shift exit collides with Late Shift Discount

- Severity: **High**
- Confidence: **High; direct current-content runtime proof**
- Frequency: **1/100 run seeds**
- Exact pair: `scenario::corner_store_dead_shift_exit` `[690,330,72,56]` versus `event::event:late_shift_discount` `[650,270,100,64]`.
- Reproduction seed: `POSTFIX-UIENV-090-235429475`.

Expected/actual/impact: as PF-005, but the conflicting base event is Late Shift Discount; Corner Store travel aborts.

Root cause and fixes: the same unreserved exit lane and crowded-fallback/late-validator boundary as PF-005. Add this event to the scenario's reserved/conflict matrix and cover every legal Corner Store event combination, not only one staff layout.

### UIENV-PF-007 — Count Cage collides with Inventory Night Count event

- Severity: **High**
- Confidence: **High; direct current-content runtime proof**
- Frequency: **1/100 run seeds**
- Exact pair: `scenario::count_cage` `[350,330,72,56]` versus `event::event:scenario_inventory_night_count` `[346,346.4,100,64]`.
- Reproduction seed: `POSTFIX-UIENV-040-2723440700`.

Expected: the scenario task interaction and its base event entry point compose into one authority or separate controls.

Actual: two controls for the Inventory Night composition occupy substantially the same hit region, so Corner Store finalization aborts.

Root cause: Inventory Night adds `count_cage` as a separate interactive task (`env06_7_shops_streets.json:5983-6001`), while the base event `scenario_inventory_night_count` remains independently interactive. `count_cage` is authored at `[56,228]` but recovery moves it into the base event instead of merging/replacing its authority (`placement_surfaces.json:8`; `scenario_layout_resolver.gd:1327-1414`).

Fix options: have scenario activation replace/disable the base event control; bind both presentations to one stable authority; or reserve a task surface that cannot collide with the event entry control.

### UIENV-PF-008 — Count Cage collides with Parking Lot Tip

- Severity: **High**
- Confidence: **High; direct current-content runtime proof**
- Frequency: **1/100 run seeds**
- Exact pair: `scenario::count_cage` `[350,330,72,56]` versus `event::event:parking_lot_tip` `[377,294,100,64]`.
- Reproduction seed: `POSTFIX-UIENV-063-608418289`.

Expected/actual/impact: Count Cage should repack away from current room events; instead the final overlap aborts Corner Store travel.

Root cause and fixes: the same crowded-fallback/late-validator boundary as PF-007, with Parking Lot Tip demonstrating that the issue is not limited to the scenario's own base event. Reserve the task lane against all dynamic base controls and add pairwise composition coverage.

### UIENV-PF-009 — Expanded small-screen scenario/base hit overlaps are omitted from validation

- Severity: **Medium**
- Confidence: **High for the validator defect; latent for current authored content**
- Frequency: **1/1 synthetic boundary case; no shipped authored occurrence isolated in the bounded run**

Reproduction: provide a 30x30 scenario target at x=100 and a 30x30 base control at x=140. Their normal rectangles are disjoint, while their 44x44 small-screen expansions overlap by 176 px². Call `_validate_interactions()`.

Expected: the audit either reports ambiguous expanded-small-screen authority or explicitly records/handles the permitted overlap in its contract.

Actual: no small-screen hit-authority error is emitted. The only returned diagnostic in the fixture is a normal-layout label overlap.

Impact: a future or less common small-screen composition can give two controls the same enlarged touch area while layout audit remains valid, reproducing ambiguous touch targeting without the normal-layout signal.

Root cause:

- Scenario/scenario audit iterates only `for rect_key in ["rect"]` (`scripts/core/scenario_layout_resolver.gd:801-815`).
- Scenario/base audit similarly checks only `[target.rect, base_rect, "normal"]` (`scenario_layout_resolver.gd:829-845`) despite computing both `small_rect` and `base_small`.
- The comment says 44px expansion is allowed to share spacing, but these are active hit rectangles, not an 8px visual margin; no alternate deterministic pointer authority is recorded.

Fix options:

1. Include `small_rect/base_small` in exclusive hit-authority validation, or document and implement deterministic disambiguation for touch.
2. Add a contract fixture where normal rectangles are disjoint and only 44px expansions intersect.
3. Include base controls in `small_screen_overlap_count` coverage so the report cannot claim zero while this pair exists.

## Prior-defect disposition

| Prior IDs | Post-fix disposition | Evidence |
|---|---|---|
| UIE-001–UIE-016 | **Not reopened in 519 successful visits; remediation present.** Base placement now performs recovery/fallback plus a final direct-overlap audit (`scripts/core/environment_instance.gd:668-806`). Fresh screenshot equivalence was not run in this bounded handoff. | Static source + generation audit produced no base-placement failure. |
| UIE-017–UIE-021 | **Partly transformed, not closed.** Developer-room overlap suppression is removed (`scenario_layout_resolver.gd:829-855,1656-1666`), but six legal compositions now abort destination install: PF-003–PF-008. | 22/100 room-finalization failures. |
| UIE-022 | **Fixed/not reopened.** Bar Dice exclusion regions include opponent/dealer bands and row positions were separated (`scripts/games/bar_dice.gd:64-85,3198-3224,3503-3549`). | Static diff review; no fresh Bar Dice screenshot in this bounded pass. |
| UIE-023–UIE-025 | **Fixed/not reopened.** Environment labels use ellipsis and expose full text through tooltip/accessibility; High-Limit title uses text mode (`pixel_scene_canvas.gd:3896-3917,5107-5136`; `data/ui/environment_ui.json:74-76`). | Static review + player-text contract pass. |
| A11Y-006 | **Fixed for event-choice popup.** It now has topmost cancel routing and a focus trap (`foundation_main.gd:782-794,12314-12367`). **World Map remains independently broken as PF-002.** | Accessibility contract pass + focused map failure. |
| A11Y-007–A11Y-008 | **Fixed/not reopened.** World Map and Settings use viewport-bounded geometry (`foundation_main.gd:9103-9172`). | Accessibility contract pass. |
| A11Y-009 | **Fixed/not reopened.** Joypad A/B are mapped globally to accept/cancel (`project.godot:33-47`). | Accessibility contract pass + static InputMap review. |
| LIFE-001 | **Fixed/not reopened.** Root focus/minimize notifications own simulation pause (`foundation_main.gd:797-819,11847-11900`). | Lifecycle contract pass. |
| LIFE-002 | **Original stale capture fixed, but follow-on regression PF-001 opened.** Focus loss now emits cancel, yet the clear routine destroys pause/orphan ownership. | Lifecycle contract pass plus focused edge failure. |
| LIFE-003 | **Fixed/not reopened.** High-contrast preview is scoped to Settings and global palette changes only on apply (`settings_menu.gd:376-387,529-550`). | Lifecycle contract pass. |
| EXT-TXT-001–EXT-TXT-004 | **Fixed/not reopened.** Shared player-text, currency-routing, clock, plural, and sentence composition checks pass. | `FIXSWEEP06_1_PLAYER_TEXT PASS`. |

## Passed and bounded checks

- The focused lifecycle contract passed application-focus pause, ordinary capture cancel, and Settings discard cases that do not combine modal/focus cancellation with an already active capture.
- The focused accessibility contract passed event-popup focus containment, bounded 640x360 overlays, large-text Settings, and global controller accept/cancel mappings.
- The focused player-text contract passed generalized sealed-action wording, cash/chip routing, 12-hour report clock, plural grammar, and Baccarat sentence composition.
- The environment generator completed all 100 seed attempts without crash or hang. Seventy-five reached six visits; 22 stopped at the documented room-finalization defects, one reached bankroll zero, and two ended with no enabled travel.
- All generated evidence stayed under `.tmp/playtest_2026-09-21`; no player profile or tracked game data was changed.

## Recommended remediation order

1. Fix PF-003–PF-008 together at the placement/finalization boundary: a validator that catches ambiguity is correct, but legal generated content must be repacked or rejected before travel is offered, not after the player commits travel.
2. Fix PF-001 by separating capture state from lifecycle pause ownership; its behavior can advance wager-bearing simulation behind a modal.
3. Add a reusable modal focus scope and apply it to World Map for PF-002.
4. Close PF-009 before another small-screen content expansion makes it player-visible.
5. Rerun: the exact 22 failing seeds, all 55 scenarios across at least two seed families, the 18-room windowed layout survey, then the focused lifecycle/map probes.

## Final disposition

- Retained defects: **9**
- High: **8**
- Medium: **1**
- Critical: **0**
- Product fixes made: **none**
- Godot processes at handoff: **0**
