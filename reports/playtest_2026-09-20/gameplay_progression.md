# Gameplay, Progression, Travel, and Persistence Playtest Report

Date: 2026-09-20  
Build: `0.5.1`, Godot `4.6.stable`, commit `4384378a00d2e81e259aa28ae01ffbbc7cf21fd5`  
Scope owner: gameplay/progression worker  
Disposition: investigation only; no product code or data was changed

## Executive summary

This pass confirmed **two player-facing defects**:

| ID | Severity | Area | Summary | Confidence |
|---|---:|---|---|---|
| GP-01 | P2 / Medium | Tutorial | Buying the Pencil before finishing the Coffee inspection clears the selected Coffee card; the final lesson highlights the shelf instead of the required Buy action. | High |
| GP-02 | P1 / High | Save/load, dynamic scenarios | JSON round-trip discards queued scenario facts because persisted integer fields become floats and the strict restore validator rejects them. Restored runs can then fail to continue/travel. | High |

The broad systems pass executed 28 targeted contracts. Twenty-four passed outright. Four initially failed; isolated reruns and source tracing separated one product failure (GP-02) from three stale/test-lifecycle failures. Tutorial testing additionally completed both authored tutorial routes, 56 lesson-boundary save/load checkpoints, a 100-seed stuck sweep, and 1,622 guardrail recovery transitions.

## Method

- Ran the full guided tutorial audit on the fixed tutorial seed, including Path A, Path B/skip, Bronze-card completion, 56 save/load lesson boundaries, and normal-run isolation.
- Ran tutorial-specific visible/runtime checks for failure restart, guardrail recovery, map route visibility, talk target geometry, dialogue cadence, and wrong-order Corner Store interactions.
- Ran 28 gameplay contracts spanning actions, items, builds, events, Crew recruitment/jobs/plays/heist/turns, character chains, dialogue, save/load, economy, travel, world map, time/open hours, services, lenders, suspicion/security, run reports, Grand Casino/demo boss, recovery, and terminal pressure.
- Reran every red system cluster individually to separate shared-run contamination from deterministic defects.
- Traced every retained defect through the production call path. Failures whose fixture bypassed production authorization or tree-ready sequencing are documented separately and are not counted as game bugs.

Primary evidence is under `.tmp/playtest_2026-09-20/gameplay_progression/`. The two most useful machine-readable artifacts are:

- `tutorial_audit_1/tutorial_guided_run_audit.json`
- `systems_repros/save_load_interrupt_fuzz_foundation/report.json`

## GP-01 — Wrong-order Corner Store tutorial loses the actionable Buy target

**Severity:** P2 / Medium  
**Frequency:** 2/2 dedicated regressions plus one instrumented reproduction  
**Player impact:** confusing progression friction and apparent tutorial stall; recoverable only by manually reselecting Coffee  
**Affected flow:** first-night tutorial, Corner Store, Coffee/Pencil ordering

### Reproduction

1. Start the first-night tutorial and travel to the Corner Store.
2. Inspect Coffee as directed.
3. Inspect and buy the Pencil before buying Coffee.
4. Return focus to Coffee and allow already-satisfied intermediate lessons to advance.
5. Observe the final “buy remaining Coffee” lesson.

### Expected

Coffee remains selected and the coach ring targets the Coffee **Buy** action. The player can immediately perform the required action.

### Actual

The Coffee selection is cleared. The selected-info/action panel is hidden and its action rect is `Rect2(0, 0, 0, 0)`. The coach falls back to the shelf-object rectangle instead of the Buy action. Instrumented state at failure:

- Coffee offer exists and is affordable (`$8`; bankroll `$66`).
- Shelf object is enabled and advertises `buy_item`.
- `selected_info.visible == false`.
- The highlighted rect is the Coffee shelf object (`117.58,253.84 120.56x72.33`), not the action control.

The run is not permanently dead: clicking/re-focusing the object can recover it. However, the prescribed action is unavailable at the moment the tutorial says to take it, and the visual instruction points to the wrong control.

### Root cause

`FoundationMain._resume_after_completed_tutorial_action()` clears stale focus before it resolves the final active lesson (`scripts/ui/foundation_main.gd:16381-16392`). `_clear_stale_focus_before_dependent_tutorial_target()` examines only the first directly authored dependent and returns (`16395-16411`). It does not skip dependents that the player already satisfied out of order, nor compare the selected object with the eventual active lesson.

Once selection is cleared, `PixelSceneCanvas` only exposes the action rectangle for the selected object (`scripts/ui/pixel_scene_canvas.gd:4839-4845`). The tutorial target resolver then falls back to the shelf object (`scripts/ui/foundation_main.gd:15003-15006`). The lesson graph is therefore advanced correctly, but focus state and coach geometry are resolved against different lessons.

### Fix options

1. Resolve/refresh the final active lesson first, then clear selection only if that lesson truly targets a different object.
2. When walking dependencies, skip already-complete or currently ineligible lessons before making the focus decision.
3. As a defensive UI measure, when an action-target lesson activates for the same object, restore that object's selection before resolving the action rect.
4. Keep the wrong-order regression as a required tutorial gate and assert that both `selected_info.visible` and the `buy_item` action rect are non-empty.

### Evidence

- `.tmp/playtest_2026-09-20/gameplay_progression/tutorial_visible/tutorial_corner_shop_order_check.*`
- `.tmp/playtest_2026-09-20/gameplay_progression/tutorial_repros/tutorial_corner_shop_order_check.*`
- `.tmp/playtest_2026-09-20/gameplay_progression/diagnostics/corner.stdout.log`
- Regression route: `scripts/tests/tutorial_corner_shop_order_check.gd:65-104`

## GP-02 — Save/load drops pending dynamic-scenario facts and can strand continuation

**Severity:** P1 / High  
**Frequency:** queued-fact loss at 7 sampled action boundaries across all 4 deterministic seeds; general second-load drift at all 20 fuzz action checkpoints and 7 targeted states  
**Player impact:** an autosave/manual reload at an action boundary can silently lose scenario causality. Later sequence aftermath may not fire; the restored clone can become unable to continue or install the next destination.  
**Affected flow:** JSON-backed saves in rooms using dynamic scenario sequences; downstream travel/continuation

### Reproduction

1. Start any deterministic run that arrives in a room with an active dynamic scenario sequence.
2. Take an action that enqueues a scenario fact before that fact is consumed.
3. Serialize with `RunState.to_dict()`, pass through JSON, then restore with `RunState.from_dict()`.
4. Compare `current_environment.scenario_sequence_state.fact_queue` before and after.
5. Continue the restored run and attempt ordinary travel when it becomes available.

The automated sweep performs this at five action boundaries for each of four seeds and also checks targeted mid-states.

### Expected

The queued causal fact survives byte-equivalently, normalization reaches a fixed point after one load, and the restored run retains the same legal continuation/travel behavior.

### Actual

- Repeated exact mismatch: `$.current_environment.scenario_sequence_state.fact_queue size 1 != 0`.
- This occurred at seven sampled boundaries across all four seeds.
- All 20 seed/action checkpoints reported that normalization changed again on the second load.
- Targeted blackjack-count, world-map, travel-lock, pending-event, active-event, and challenge-modifier states also reported second-load drift.
- All four seeds later attempted a legal `motel -> jazz_club` route but destination installation returned `Travel destination was not installed.`
- Three of four seed clones then had no legal continuation at step 0. A controlled bar-dice mid-state clone also could not continue.

The ordinary `save_service_foundation_round_trip` check passed, so this is specifically an interrupt/mid-sequence persistence defect, not total save-file failure.

### Root cause

Godot JSON parsing materializes numeric values as floats. `RunState.from_dict()` feeds the persisted environment through `_normalize_environment()` (`scripts/core/run_state.gd:15821`), which normalizes the scenario sequence (`17481-17504`). The queue normalizer then demands `ingress_serial` already be a native integer and silently skips any entry whose type is not `TYPE_INT` (`scripts/core/scenario_sequence_runtime.gd:2403-2415`). Unlike top-level `schema_version`, which is explicitly converted from an integral float at `run_state.gd:17484-17485`, the queued fact's integer fields receive no JSON-type normalization. A valid queued fact therefore becomes invalid solely because it crossed JSON and is discarded.

That loss violates the documented restore contract: `fact_queue` is causal/authority-bearing state, while only presentation projections should be rebuilt. The widespread second-load drift indicates this is part of a broader non-idempotent restore boundary; the exact queue loss is the directly localized data-loss mechanism. The later travel-install and continuation failures are treated here as downstream symptoms rather than separately counted bugs because they occur after repeated restore mutation and the isolated report does not expose a different install root cause.

### Fix options

1. Canonicalize every integer field in persisted fact envelopes after JSON parsing and before `_normalized_fact_queue()` performs strict validation. Only accept finite, integral floats within the permitted range.
2. Centralize persisted-scenario numeric canonicalization so commands, facts, receipts, boundary ordinals, and nested payload schema fields use one audited conversion boundary.
3. Make invalid queued-fact restore fail loudly/quarantine the save with a diagnostic instead of silently dropping causal state.
4. Add a direct JSON round-trip unit case containing one pending fact and assert exact queue preservation plus first-load idempotence.
5. Extend the fuzz reporter to print the first second-load mismatch, then fix remaining restore-time mutations until the second-load drift is zero.
6. Retain continuation checks for travel installation and mid-challenge inputs after persistence; these caught player-visible consequences that byte comparison alone would miss.

### Evidence

- `.tmp/playtest_2026-09-20/gameplay_progression/systems_repros/save_load_interrupt_fuzz_foundation/report.json`
- `.tmp/playtest_2026-09-20/gameplay_progression/systems_repros/save_load_interrupt_fuzz_foundation/stdout.log`
- `.tmp/playtest_2026-09-20/gameplay_progression/systems_repros/save_load_interrupt_fuzz_foundation/stderr.log`
- Checkpoint and continuation driver: `scripts/tests/foundation/check_lenders_release_saves.gd:5359-5599`
- Restore path: `scripts/core/run_state.gd:15779-15935`, `17481-17504`
- Queue rejection: `scripts/core/scenario_sequence_runtime.gd:2403-2415`

## Red results excluded from the product bug count

These failures were deterministic, but source tracing showed that their fixtures bypass a production prerequisite. They are test-maintenance findings, not evidence of a player-facing regression in the exercised build.

### H-01 — Talk popup and ignore-penalty fixture runs before staged UI construction

The isolated talk test creates `FoundationMain`, adds it to the tree, and immediately calls refresh/travel methods without yielding a process frame. The native start path defers staged run-UI construction (`foundation_main.gd:8745-8794`). Consequently the fixture sees no expanded Talk dock, and later reaches `_ensure_wager_confirmation_controller()` while `WagerConfirmationControllerScript` is still null (`13034-13036`), producing `Invalid call. Nonexistent function 'new' in base 'Nil'`.

A player cannot take this call sequence before the scene receives frames, and the Play path ensures the run UI is built. Recommended harness correction: await the documented tree-ready/prewarm boundary or explicitly invoke the same synchronous run-UI ensure path as Play.

### H-02 — Dialogue-effects fixture resolves an event id that was never host-authorized

The test queues `dialogue:pull_tab_clerk`, but builds the effect event with ids `dialogue_route_fixture` and `dialogue_loose_fixture` (`check_items_events_world.gd:950-1005`, helper at `1049-1065`). `EventModule.resolve()` correctly rejects a triggered event unless that exact id is pending (`event_module.gd:181-200`). Production dialogue uses the pending entry's actual `event_id` (`foundation_main.gd:5690-5708`), so its effects are authorized. The missing flag, route, and Heat results are all consequences of this stale fixture identity.

Recommended harness correction: construct the event with `entry.event_id`, or enqueue the exact fixture event id before resolving it.

### H-03 — Closing-time host fixture is blocked by the same pre-tree-ready UI race

The time fixture also instantiates `FoundationMain` and immediately drives `_refresh()` and `_guard_player_input_route()` without yielding (`check_items_events_world.gd:2756-2817`). This allows startup modal/staged controls to intercept the guard before `_ensure_closing_time_departure_talk()` is reached. The production implementation independently loads `venue_closing_notice`, resolves `dorian_room_host`, enqueues `dialogue:venue_closing_notice`, and waits for acknowledgment before opening the map (`foundation_main.gd:4309-4356`).

Recommended harness correction: use the same ready/prewarm barrier as H-01 and assert that no startup modal owns input before driving the closing route.

### H-04 — Tutorial Heat non-overlap fixture mutates obsolete global Heat storage

The fixture writes `run_state.suspicion["level"] = 98` directly, then calls `add_suspicion()`. Heat is now venue-local (`run_state.gd:4953-4969`); because no local level was seeded, the production method correctly starts from the current venue's zero and reaches 8, not the intended near-terminal state. Recommended correction: seed Heat through `add_suspicion()` with the current environment context or populate `local_levels`.

### H-05 — Dialogue cadence fixture pins an obsolete content hash

The cadence test rejects the current `games.json` before exercising gameplay because its expected SHA-256 no longer matches. Its empty fallback is then JSON-parsed and passed into `from_dict`, producing a null-type failure. Recommended correction: regenerate the approved fixture/hash after reviewing the content delta; do not count this as dialogue behavior evidence.

## Verified coverage and negative findings

The following areas passed the targeted checks used in this wave:

- Full first-night tutorial: both authored paths reach Bronze/card completion; 100-seed stuck sweep found 0 stuck runs; all 56 lesson-boundary save/load checkpoints passed.
- Tutorial guardrail recovery: 1,622 irregular boundary transitions passed.
- Failure/restart recovery and world-map route visibility passed.
- Core action boundary, item effects, item builds, event module, event state, and interactable-event class guard passed.
- Crew recruitment, layer-3 jobs, plays, heist, turn state, character chains, and content-depth contracts passed.
- Ordinary SaveService round-trip passed; only interrupt/mid-sequence persistence is red.
- Economy pressure, travel route calculation, world map, services, lender/debt, suspicion/security, run report, demo boss/Grand Casino objective, and recovery/loss pressure passed.

These passes reduce the likelihood that GP-01 is a general tutorial deadlock or GP-02 is a total save-system outage. They should not be read as exhaustive proof that every content permutation is defect-free.

## Prioritization

1. Fix GP-02 first. It silently drops causal state and has downstream continuation/travel consequences; save corruption is more damaging than a recoverable tutorial targeting problem.
2. Fix GP-01 next, then retain its wrong-order route as a release gate.
3. Repair H-01 through H-05 before using those checks as product quality signals. Their current failures add noise and can hide real regressions in the same subsystems.

