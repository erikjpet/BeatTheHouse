# Beat the House - Demo Release Finalization Prompt Board

> **Historical board:** The 0.2.0 demo shipped. This file is retained as
> historical context only; use `docs/plans/act_one_feature_complete_task_board.md`
> as the active planning board. Its section 13 Status Ledger records the T0.1
> verification pass for every task A0-F6 below.

Updated: 2026-06-26

> **Status accuracy note (revised 2026-06-29):** This board's per-task statuses
> predate substantial endgame and UI work and are now stale. A static code read
> confirms the following are already implemented in some form, despite being
> marked TODO/Partial/Missing below: the Grand Casino endgame design lock
> (`docs/plans/grand_casino_endgame_design.md`), the dual-route demo objective
> data (`high_roller_*` and `showdown_*` fields in
> `data/environments/archetypes.json`), the boss-floor events `the_house_calls`
> and `high_roller_cashout`, a dedicated victory screen (`SCREEN_VICTORY` +
> victory summary panel in `scripts/ui/foundation_main.gd`), an in-run pause menu
> with Resume/Save/Load/Abandon, and a dev-gated game-test launcher
> (`dev_game_test_mode`). Treat the task *prompts* below as still-useful specs,
> but **re-run each task's DONE gate before trusting its status**. The Section 1
> content counts have been corrected to match the live data packs.

**Role:** executable repository-finalization prompt list for taking the current Beat the House Godot project from its runnable foundation state to a polished demo release. This file keeps the original board format: current-state assessment, a shared main guideline to prepend to every task, then copy-paste prompts for each finalization task.

This board is updated against the current repo. It does **not** repeat stale tasks that treated slot, bar dice, video poker, baccarat, or roulette as missing placeholders. Those games now exist as full-simulation modules and should be audited, polished, balanced, and integrated into the final Grand Casino demo arc.

Design source of truth remains `README.md`. This task board operationalizes the current source, with special emphasis on the requested Grand Casino alternatives:

- **Heat route:** high Grand Casino heat plus staff attention sends the player into a back-room Pit Boss Showdown instead of instantly ending the run.
- **Clean route:** a player who does not openly cheat can win by meeting a Grand Casino monetary/high-roller goal and cashing out.

---

## 1. Current Repo State

| Area | Status | Evidence |
| --- | --- | --- |
| Godot project foundation | **Built** | `project.godot`, `scenes/main.tscn`, `scripts/ui/foundation_main.gd` |
| Core run state | **Built** | `scripts/core/run_state.gd` owns seed, bankroll, local heat, travel, debt, alcohol, inventory, story log, terminal run status |
| Content loading | **Built** | `scripts/core/content_library.gd` loads JSON packs under `data/` |
| Environment generation | **Built, needs final balance/polish** | `scripts/core/run_generator.gd`, `scripts/core/environment_instance.gd` |
| Current environments | **Built** | Seven archetypes in `data/environments/archetypes.json`, including `grand_casino` |
| Current games | **Built** | Pull Tabs, Slot, Bar Dice, Blackjack, Baccarat, Roulette, Video Poker in `data/games/games.json` |
| Pull Tabs | **Built** | `scripts/games/pull_tabs.gd` |
| Slots | **Built, release audit needed** | `scripts/games/slot.gd`, `scripts/games/slots/*` |
| Bar Dice | **Built, release audit needed** | `scripts/games/bar_dice.gd` has generated table state, keep/reroll, press, two cheats |
| Blackjack | **Built, release audit needed** | `scripts/games/blackjack.gd` |
| Baccarat | **Built, Grand Casino only** | `scripts/games/baccarat.gd`; foundation tests check Grand Casino-only placement |
| Roulette | **Built, release audit needed** | `scripts/games/roulette.gd` |
| Video Poker | **Built, release audit needed** | `scripts/games/video_poker.gd` has variants, holds, multi-hand, double-up, holdout cheat |
| Grand Casino objective | **Partial** | Bankroll target, pit boss watch cycle, boss events, and `the_house_calls` exist |
| Current finale | **Functional but not final** | `the_house_calls` is a data event with branch choices, not a full back-room showdown |
| Heat failure | **Built but needs Grand Casino override** | Generic heat 100 can trigger `police_capture`; Grand Casino should instead route to back room when staff attention is present |
| Main menu | **Built, release polish needed** | New Run, Continue, Settings, Inventory, temporary Game Test |
| Settings | **Built, accessibility polish needed** | Resolution, window mode, VSync, audio, UI scale, text size, reduce motion, drunk effect |
| Failure summary | **Built** | Dedicated failure summary panel exists in `FoundationMain` |
| Victory summary | **Missing/fuzzy** | No dedicated victory screen constant or complete run-summary presentation |
| Prestige | **Code hooks only** | `data/prestige/purchases.json` is empty |
| Content depth | **Growing** | 15 events, 18 items, 8 services, 2 lenders, 8 routes, 0 prestige purchases (counts verified 2026-06-29) |
| QA tooling | **Built** | `tools/validate_project.ps1`, `tools/check_godot.ps1`, visual QA, perf probe, mouse batch, game audits |
| Export presets | **Configured, unverified for release** | `export_presets.cfg` has Windows, Android, iOS presets |

**Net:** the repository is no longer a structure-first prototype. It is a broad playable foundation whose final demo blockers are the Grand Casino endgame design, terminal presentation, save/load coverage for new endgame state, final UX polish, content/balance, QA, and packaging.

---

## 2. Definition Of Demo Release

A player can start a run from a release-ready main menu, understand the objective, route through generated venues, play all current games from their surfaces, manage items, alcohol, debt, heat, and travel, reach the Grand Casino, and finish the demo through either:

1. **Pit Boss Showdown victory:** high Grand Casino heat and staff attention pull the player into the back room; surviving the showdown wins the demo.
2. **High-Roller Cashout victory:** clean or non-openly-cheating play reaches a monetary target; the casino rates the player as a high roller and lets them leave with winnings.

Failure can happen through bankroll zero, being stranded, generic police capture outside the Grand Casino, or losing the Grand Casino back-room showdown. Every terminal route has a polished summary. Demo victory clearly points to the next act as not implemented yet.

**Standard release gate:**

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1
powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot
powershell -ExecutionPolicy Bypass -File tools/foundation_visual_qa.ps1 -RequireGodot
powershell -ExecutionPolicy Bypass -File tools/foundation_performance_probe.ps1 -RequireGodot
powershell -ExecutionPolicy Bypass -File tools/foundation_mouse_batch_playtest.ps1 -RunCount 60 -RequireGodot -AllowRunFailures
```

---

## 3. Shared Finalization Guideline

Prepend this block to every task prompt below.

```text
You are a senior Godot 4 / GDScript engineer finalizing Beat the House.

WORKSPACE: D:\Projects\Beat-The-House
ENGINE TARGET: Godot 4.6-compatible project, Windows/PowerShell.

MISSION: Implement this task completely against the current repository state. Do not stop at analysis. Read the relevant files before editing, make the smallest coherent changes, add or update tests, run the requested gates, and leave the repo closer to a polished demo release.

DESIGN SOURCE OF TRUTH:
- README.md is the current top-level spec.
- docs/plans/demo_release_task_board.md is the executable finalization board.
- Do not resurrect stale assumptions from older plans that claimed bar dice, video poker, slots, baccarat, or roulette are placeholders. They are current full-simulation modules and should be polished/audited, not rebuilt from scratch unless a test proves a specific broken behavior.

GRAND CASINO ENDGAME REQUIREMENTS:
- The Grand Casino must support two demo victory routes.
- Heat route: if enough heat is gained inside the Grand Casino and staff attention is present, Pit Boss Rourke calls the player to the back room. The run must not instantly end from generic police capture. Resolve the Pit Boss Showdown. Success wins the demo and allows the player to leave with winnings. Failure means the casino takes the player out back and the run ends.
- Clean route: a player who does not openly cheat must be able to win the Grand Casino by meeting a high-roller monetary goal. The casino rates them as a high roller and lets them cash out.
- Outside the Grand Casino, existing heat failure behavior should continue unless this task explicitly says otherwise.

ARCHITECTURE CONTRACTS:
- RunState is the authoritative simulation state for a run.
- Game modules return result dictionaries and deltas; shared code applies deltas through GameModule.apply_result or RunActionService paths.
- Do not mutate RunState bankroll/heat/inventory directly from a game surface except through existing accepted state-owner methods.
- Use RngStream for deterministic randomness. Do not use randomize(), randf(), randi(), or engine-global RandomNumberGenerator in gameplay code.
- Keep content data-driven through ContentLibrary and JSON packs where practical.
- FoundationMain owns shared UI flow. Concrete GameModule scripts own game-specific surfaces.
- Save/load round trips must preserve any new state.
- Player-facing copy must fit existing validator limits. Avoid placeholder, TODO, dev-only, or test-only copy in the release path.

GDSCRIPT STRICTNESS:
- Treat warnings as errors.
- Type locals when values come from dictionaries or untyped APIs.
- Use clampi/clampf, mini/minf, maxi/maxf, absi/absf where appropriate.
- Keep ternaries type-compatible.
- Register all clickable surface regions through existing hit-region helpers.

VALIDATION LOOP:
1. Inspect current files.
2. Implement the task.
3. Add or update tests, especially in scripts/tests/foundation_check.gd for system behavior.
4. Run the narrowest meaningful test first.
5. Run the task's DONE gate.
6. Fix root causes and repeat until green.

DEFAULT GATE:
powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1
powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot

Do not weaken validators, skip assertions, or hide failures. End with evidence: commands run, pass/fail output, and file:line summary.
```

---

## 4. Prompt Board

Priority: P0 blocks the finalized demo. P1 is required for a polished demo. P2 is public-release polish that can only be cut deliberately.

### Category A - Grand Casino Endgame

**A0 - Grand Casino Endgame Design Lock** - P0 - deps: none - status: TODO

Lock the Grand Casino endgame design (narrative + mechanics + state machine) into a written spec before A1 implementation, so A1-A6 build against a fixed contract instead of designing while coding.

DONE: docs/plans/grand_casino_endgame_design.md exists and defines both victory lanes, the showdown encounter structure, the deterministic check inputs, the state machine, and every event/flag/id referenced by A1-A6.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK A0 - Author the Grand Casino endgame design lock.

Read:
- README.md player goal, heat, environments, and demo victory sections.
- data/environments/archetypes.json grand_casino demo_objective and security_profile.
- scripts/core/run_state.gd demo_objective_status(), evaluate_environment_objective_state(), pit_boss_watch_status(), security_action_pressure().
- data/events/events.json the_house_calls and boss events.

Produce docs/plans/grand_casino_endgame_design.md as the authoritative design for A1-A6. It must define, leaving no open questions for implementers:
- Narrative frame: Pit Boss Rourke, the back room, the high-roller cage/host.
- Two-lane state machine: states (pre-grand, grand-incomplete, high-roller-ready, showdown-pending, showdown-active, victory, failure) and every transition trigger.
- Heat route triggers: showdown_heat_threshold, forced_showdown_heat_threshold, and the exact definition of "staff attention" (which concrete sources count).
- Clean route criteria: high_roller_target_bankroll, high_roller_net_winnings, high_roller_min_grand_casino_games, high_roller_max_heat, and the rule that hitting the money target with cheating evidence or high heat routes to the showdown instead of cashout.
- Showdown encounter structure: beats (arrival, pressure choice, final check, outcome), the deterministic check formula, and every modifier input (heat, watched-cheat evidence, clean play, items, alcohol/debt, prior boss events), plus success/failure outcomes.
- Canonical id list: showdown_event_id, high_roller_event_id, failure reason casino_taken_out_back, narrative/attention flag names, and victory route names (high_roller_cashout, pit_boss_showdown).
- Suggested initial numeric tuning (to be validated in D3/D7), explicitly marked as tunable.

This is a design + documentation task. Do not change gameplay code. A1-A6, B2, C1, C3, C5, D1, and D7 must reference the ids and rules defined here.

DONE GATE:
- validate_project.ps1 (docs change must not break validation).
- Cross-check the design against current run_state.gd helpers so referenced ids/states are implementable.
```

**A1 - Dual Grand Casino Victory Lanes** - P0 - deps: A0 - status: TODO

Rework the Grand Casino objective model so it exposes both the heat/back-room route and the clean high-roller route.

DONE: HUD/status data can represent both routes; tests cover incomplete, high-roller-ready, showdown-pending, victory, and failure states.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK A1 - Implement dual Grand Casino victory lane state.

Read:
- README.md sections about current player goal, games, heat, environments, and demo victory.
- data/environments/archetypes.json grand_casino entry.
- scripts/core/run_state.gd demo_objective_status(), evaluate_environment_objective_state(), pit_boss_watch_status().
- scripts/ui/foundation_main.gd current_objective_hud_snapshot(), _run_status_hud_model(), _objective_goal_text().
- scripts/tests/foundation_check.gd _check_demo_boss_objective_foundation().

Implement a Grand Casino objective model that can describe:
1. Heat route: Rourke/back-room showdown path.
2. Clean route: high-roller cashout path.

Add data fields under the Grand Casino demo objective for high-roller and heat-showdown requirements. Suggested fields:
- high_roller_target_bankroll
- high_roller_net_winnings
- high_roller_min_grand_casino_games
- high_roller_max_heat
- showdown_heat_threshold
- forced_showdown_heat_threshold
- showdown_event_id
- high_roller_event_id

Add RunState helpers as needed so UI does not infer these rules from strings. The status dictionary should expose current bankroll, target bankroll, Grand Casino net progress if available, high-roller readiness, showdown pending, staff attention state, and readable summary copy.

Do not complete victory in this task unless existing behavior already does. This task establishes the state model and objective reporting.

Tests:
- Grand Casino objective reports both lanes.
- Outside Grand Casino, no boss objective appears.
- Objective is incomplete below targets.
- Objective can report high-roller ready without setting victory.
- Objective can report showdown pending without setting victory.
- Save/load preserves new objective metadata and runtime defaults.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite systems
- Relevant foundation_check output shows the new objective cases.
```

**A2 - Grand Casino Heat Reroute To Back Room** - P0 - deps: A1 - status: TODO

Replace instant generic police capture on the Grand Casino boss floor with a pending back-room showdown when heat and staff attention conditions are met.

DONE: Grand Casino heat plus attention queues the showdown and keeps the run active; outside Grand Casino heat still fails normally.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK A2 - Reroute severe Grand Casino heat into the back-room showdown.

Read:
- scripts/core/run_state.gd add_suspicion(), _evaluate_immediate_terminal_state(), security_action_pressure(), pit_boss_watch_status().
- scripts/core/game_module.gd apply_result().
- scripts/core/run_terminal_evaluator.gd evaluate().
- data/environments/archetypes.json Grand Casino security_profile and demo_objective.
- data/events/events.json boss events.
- scripts/tests/foundation_check.gd high heat and House Calls tests.

Current behavior lets heat 100 fail the run as police_capture. In the Grand Casino, this should become Rourke calling the player into the back room when staff attention is present.

Implement a deterministic Grand Casino override:
- Detect current environment archetype/kind as Grand Casino boss floor.
- Detect staff attention from at least one concrete source: pit boss currently watched, prior watched risky/cheat action, active boss security event, or a new narrative flag set by boss events/game results.
- If Grand Casino heat crosses the configured showdown threshold while staff attention is present, set a showdown pending flag, inject the showdown event, and keep the run active.
- If Grand Casino heat reaches the forced threshold but staff attention is missing, either establish attention with a clear story entry or apply a strong warning without generic capture, according to the data thresholds.
- Outside Grand Casino, preserve existing police_capture behavior.

Add a new failure reason constant for the eventual showdown loss, such as casino_taken_out_back, but do not use it until the showdown task resolves failure.

Tests:
- Watched Grand Casino cheat/risky action at high heat queues showdown and does not fail immediately.
- Unwatched Grand Casino high heat produces warning or pending state according to the chosen rule.
- Outside Grand Casino heat 100 still fails as police_capture.
- Pending showdown survives save/load.
- Repeated heat changes do not duplicate the showdown event.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite systems
- targeted foundation_check cases for Grand Casino heat reroute.
```

**A3 - Pit Boss Showdown Event** - P0 - deps: A1,A2 - status: TODO

Turn the back-room confrontation into a real playable boss event, not a simple win/loss branch picker.

DONE: Back-room event has state, choices/checks, success, failure, item/state modifiers, save/load, and readable presentation.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK A3 - Build the playable Pit Boss Showdown back-room event.

Read:
- data/events/events.json current the_house_calls event.
- scripts/core/event_module.gd event conditions and result application.
- scripts/core/run_state.gd apply_demo_finale_result(), story_log helpers, failure handling.
- scripts/ui/foundation_main.gd event rendering, event choice popup, result feedback, failure summary.
- scripts/ui/pixel_scene_canvas.gd event props and pit boss rendering.

Replace or extend the current The House Calls branch event into a playable back-room showdown. It should feel like a short boss encounter:
1. Back Room Arrival: Rourke states what drew attention.
2. Pressure Choice: player chooses a response such as keep the story straight, talk high-roller numbers, lean on reputation/items, or bluff.
3. Final Check: deterministic seeded check with modifiers from heat, watched cheating evidence, clean play, items, alcohol/debt pressure, and prior boss events.
4. Outcome: success wins the demo; failure means the casino takes the player out back and the run ends.

Implementation may use EventModule extensions, RunState showdown state, or a small dedicated event-surface flow, but keep it data-driven where practical and saveable.

Success:
- Clears showdown pending flags.
- Sets demo_victory.
- Uses victory message: casino lets you walk with your winnings / next act not implemented.

Failure:
- Clears showdown pending flags.
- Fails run with casino_taken_out_back or similarly named reason.
- Does not describe generic police capture.

Tests:
- Showdown can trigger from pending flag.
- Success branch sets demo victory and ended status.
- Failure branch sets the new failure reason.
- Item-assisted or clean-play modifier changes the outcome odds/check result.
- Save/load mid-showdown preserves step and choices.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite systems
- foundation_visual_qa.ps1 -RequireGodot reaches or snapshots the showdown event.
```

**A4 - Clean High-Roller Cashout** - P0 - deps: A1 - status: TODO

Add a monetary non-open-cheating Grand Casino win method.

DONE: Clean players can win the Grand Casino by meeting high-roller criteria and cashing out.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK A4 - Implement the clean high-roller Grand Casino victory path.

Read:
- scripts/core/run_state.gd environment history, narrative_flags, story_log, demo objective helpers.
- scripts/core/game_module.gd apply_result().
- scripts/ui/foundation_main.gd room object/action model.
- data/environments/archetypes.json grand_casino.
- data/events/events.json boss events.
- scripts/tests/foundation_check.gd demo boss objective tests.

Track Grand Casino visit performance:
- bankroll on Grand Casino entry
- current Grand Casino net winnings
- number of Grand Casino game outcomes
- whether open cheat actions were used
- max local Grand Casino heat during visit
- whether staff attention is active

Add a high-roller cashout event/object that becomes available when the player meets the clean monetary goal. Suggested initial tuning:
- bankroll >= 500 OR Grand Casino net winnings >= 250
- at least 3 Grand Casino game outcomes
- no open cheat actions in Grand Casino
- Grand Casino heat below 65

If the player reaches the money target but has open cheating evidence or high heat, route toward the Pit Boss Showdown instead of high-roller cashout.

High-roller cashout should be a deliberate action, not an invisible automatic win. It should set demo victory, log the route as high_roller_cashout, and show a next-act message.

Tests:
- Clean player reaching target can cash out and win.
- Cheated player at same target cannot high-roller cashout.
- High-heat player at same target gets showdown pressure instead.
- Eligibility survives save/load.
- High-roller event/object appears only in Grand Casino.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite systems
- foundation_visual_qa.ps1 -RequireGodot shows high-roller objective state or event availability.
```

**A5 - Victory And Terminal Summary Screen** - P0 - deps: A3,A4 - status: TODO

Create polished terminal presentation for both demo victory routes and all failure routes.

DONE: Dedicated demo victory summary and distinct failure summaries exist.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK A5 - Add polished victory and terminal run-summary presentation.

Read:
- scripts/ui/foundation_main.gd screen constants, failure summary panel, result panel, current_screen_snapshot().
- scripts/core/run_state.gd run_status, run_failure_reason, current_demo_victory_message().
- scripts/core/run_action_service.gd prestige result handling.
- scripts/tests/ui_scene_compile_check.gd failure screen tests.

Add a clear terminal presentation for demo victory. You may add SCREEN_VICTORY or implement a distinct victory summary mode, but tests must be able to distinguish victory from generic result and failure.

Victory summary should show:
- victory route: high_roller_cashout or pit_boss_showdown
- seed
- final bankroll
- final heat
- current/visited venues
- key story beats
- items/debt/alcohol state
- message that the next act is not implemented yet
- Main Menu and New Run actions

Failure summary should distinguish:
- bankroll_zero
- stranded
- police_capture outside Grand Casino
- casino_taken_out_back / back-room showdown loss

Update snapshots/tests so terminal UI is stable and game surfaces do not remain visible over terminal summaries.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite ui
- foundation_visual_qa.ps1 -RequireGodot
```

**A6 - Grand Casino Endgame Test Matrix** - P0 - deps: A2,A3,A4,A5 - status: TODO

Add deterministic automated coverage for all new Grand Casino end states.

DONE: Foundation tests cover the full endgame matrix and save/load states.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK A6 - Add the Grand Casino endgame test matrix.

Read:
- scripts/tests/foundation_check.gd existing boss objective, high heat, save/load, failure/victory tests.
- scripts/tests/ui_scene_compile_check.gd terminal UI tests.
- tools/foundation_visual_qa.gd current coverage markers.

Add deterministic test coverage for:
- Clean high-roller cashout victory.
- Pit Boss Showdown success after watched high heat.
- Pit Boss Showdown failure after watched high heat.
- Cheated/high-heat player blocked from high-roller cashout.
- Outside-Grand-Casino heat 100 still police-captures.
- Grand Casino high heat without staff attention follows the chosen warning/attention rule.
- Save/load while showdown is pending.
- Save/load while high-roller eligible.
- Save/load after high-roller victory.
- Save/load after showdown victory.
- Save/load after taken-out-back failure.

Update visual QA coverage markers where useful, but do not make tests brittle to exact visual timing.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot
- foundation_visual_qa.ps1 -RequireGodot
```

### Category B - Release UX And Flow

**B1 - Main Menu Release Finalization** - P0 - deps: none - status: TODO

Finish the main menu for a public demo.

DONE: no accidental dev-only launcher in release path; daily/challenge/disclaimer behavior is deliberate.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK B1 - Finalize the main menu release flow.

Read:
- scripts/ui/foundation_main.gd _build_start_screen(), _refresh_start_screen(), start_foundation_run().
- scripts/core/run_state.gd challenge helpers.
- scripts/core/save_service.gd.
- README.md current status and non-real-money framing.

Polish the main menu:
- Keep New Run, Continue, Settings, Inventory/Profile, Exit Game.
- Hide or dev-gate the temporary Game Test launcher from normal release UI.
- Add Daily Run and Custom Challenge only if the challenge content/task is complete; otherwise do not show dead buttons.
- Add tasteful non-real-money simulated gambling framing at launch/menu.
- Make seed entry and continue status clear.
- Ensure touch/mouse usability and no overlapping text.

Tests:
- Continue is disabled without save and enabled with save.
- Release mode/menu snapshot does not expose Game Test.
- New Run starts with entered seed.
- Disclaimer/framing is present in the appropriate menu/start flow.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite ui
- foundation_visual_qa.ps1 -RequireGodot
```

**B2 - Objective HUD And Onboarding Refresh** - P0 - deps: A1,A2,A4 - status: TODO

Update the HUD and first-run guidance for the new two-route Grand Casino demo.

DONE: a fresh player can understand the path to Grand Casino, high-roller cashout, and Rourke showdown pressure.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK B2 - Refresh objective HUD and onboarding for the final demo.

Read:
- scripts/ui/foundation_main.gd _run_status_hud_model(), _objective_goal_text(), _next_objective_option().
- scripts/core/run_state.gd demo objective helpers and pit boss watch helpers.
- data/environments/archetypes.json objective_hint fields.

Update objective presentation:
- Before Grand Casino: build bankroll, find route, manage heat.
- On Grand Casino floor: win clean as high roller or survive Rourke's attention.
- When high-roller progress is close: show clean cashout progress without raw spreadsheet feel.
- When heat/staff attention is close: show Rourke pressure and back-room risk.
- When showdown is pending: next objective points to the showdown event.
- When victory is achieved: point to summary/next act.

Add skippable first-run guidance only if it can be done without blocking repeated play. Keep it concise and diegetic.

Tests:
- HUD snapshot exposes the correct objective state across pre-Grand, Grand incomplete, high-roller-ready, showdown-pending, victory, and failure.
- Text stays within UI bounds in visual QA.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite ui
- foundation_visual_qa.ps1 -RequireGodot
```

**B3 - In-Run Menu, Save/Load Slots, And Abandon Run** - P1 - deps: none - status: TODO

Make the in-run Menu button open a release-quality pause/menu instead of immediately returning to the main menu.

DONE: player can resume, save, load, open settings, abandon, and return safely.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK B3 - Build the in-run menu and player-facing save/load flow.

Read:
- scripts/ui/foundation_main.gd top_menu_button, return_to_main_menu(), save/load methods.
- scripts/core/save_service.gd.
- scripts/core/run_state.gd to_dict/from_dict.

Replace the in-run Menu behavior with a pause/menu overlay:
- Resume
- Save
- Load
- Settings
- Abandon Run
- Main Menu

Implement either multiple visible slots or a clear single autosave/manual save policy. The user should understand what will be overwritten.

No menu action should mutate simulation except explicit save/load/abandon. Save/load should work from environment, game, event, travel, showdown, failure, and victory contexts.

Tests:
- Menu opens from each major screen.
- Resume returns to previous screen.
- Save/load round-trip from environment and game surface.
- Abandon sets clear terminal/return state.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite ui
- foundation_visual_qa.ps1 -RequireGodot
```

**B4 - Run Journal / Story Log View** - P1 - deps: none - status: TODO

Expose the story log as a readable in-run journal.

DONE: player can browse the run's key story beats.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK B4 - Add a run journal/story log view.

Read:
- scripts/core/run_state.gd story_log, log_story().
- scripts/ui/foundation_main.gd _story_message_view_list(), failure summary, inventory popup patterns.

Add a read-only run journal accessible from the in-run UI/menu. It should show:
- travel
- debts/lenders
- item purchases/sales/uses
- events
- notable wins/losses
- heat spikes
- boss-floor attention
- high-roller eligibility
- showdown outcome
- terminal result

Keep it touch-friendly and readable. Do not mutate simulation from the journal.

Tests:
- Journal opens/closes.
- Journal reflects story entries in chronological order.
- Grand Casino endgame entries appear.
- Save/load preserves journal contents.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite ui
```

**B5 - Accessibility And Settings Completion** - P1 - deps: none - status: TODO

Finish accessibility settings and verify they apply across the demo.

DONE: settings cover release needs and persist.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK B5 - Complete accessibility and settings release pass.

Read:
- scripts/ui/settings_menu.gd.
- scripts/core/user_settings.gd.
- scripts/ui/visual_style.gd.
- scripts/ui/drunk_distortion_overlay.gd.

Current settings already include resolution, window mode, VSync, audio, UI scale, text size, reduce motion, and drunk effect mode.

Add or deliberately cut with documented reason:
- high contrast/colorblind-friendly palette
- haptics toggle for mobile targets if haptics are used
- stronger large-text/readability application across HUD, menus, popups, and terminal summaries

Persist all new settings. Apply them live where practical. Verify no screen breaks at small/large text or UI scale settings.

Tests:
- Settings save/load and apply after restart.
- VisualStyle or equivalent reflects high contrast setting if implemented.
- Reduced motion affects new Grand Casino showdown/terminal animation where relevant.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite ui
- foundation_visual_qa.ps1 -RequireGodot
```

### Category C - Game Integration And Surface Release Audit

**C1 - All Games Endgame Contract Audit** - P1 - deps: A2 - status: TODO

Audit every game module so high heat and cheat outcomes cooperate with the Grand Casino endgame.

DONE: no game can bypass the new Grand Casino heat reroute.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK C1 - Audit all game modules against the final Grand Casino endgame contract.

Read:
- scripts/games/pull_tabs.gd
- scripts/games/slot.gd and scripts/games/slots/*
- scripts/games/bar_dice.gd
- scripts/games/blackjack.gd
- scripts/games/baccarat.gd
- scripts/games/roulette.gd
- scripts/games/video_poker.gd
- scripts/core/game_module.gd
- scripts/core/run_state.gd security_action_pressure and pit_boss_watch_status

Audit and fix all game result paths so:
- Cheat/risky actions report heat consistently.
- Pit boss watched state increases heat/attention on Grand Casino floor.
- High heat in Grand Casino routes to pending showdown instead of generic instant terminal failure.
- Outside Grand Casino still respects normal terminal heat failure.
- Game result messages explain Rourke/staff pressure when applicable.
- Each module records enough story/context for high-roller clean/cheat tracking.

Do not rebuild games wholesale. Make targeted fixes based on current code.

Tests:
- Each game has a Grand Casino cheat/risky fixture that can mark staff attention or showdown pressure.
- Each game still passes existing module contract tests.
- No game's ended=true result bypasses A2's Grand Casino reroute.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot
- Run available targeted game audits where present.
```

**C2 - Game Surface UX Release Pass** - P1 - deps: none - status: TODO

Polish game surfaces for readability, controls, and touch/mouse parity.

DONE: all current games are understandable and playable from visible controls.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK C2 - Polish all game surfaces for release UX.

Read:
- scripts/ui/game_surface_canvas.gd.
- scripts/games/*.gd draw_surface/surface_state/surface_action_command methods.
- tools/foundation_visual_qa.gd game-surface coverage.

Audit each game surface:
- Pull Tabs
- Slot
- Bar Dice
- Blackjack
- Baccarat
- Roulette
- Video Poker

Fix issues with:
- too-small hit targets
- unclear selected action state
- payout/win explanation
- heat/cheat consequence clarity
- animation blocking or stale input
- text overlap
- mobile/touch parity

Do not redesign the game rules unless the surface exposes a bug. Keep each game's current simulation model.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite ui
- foundation_visual_qa.ps1 -RequireGodot
- foundation_mouse_playtest.ps1 -RequireGodot if useful
```

**C3 - Premium Grand Casino Games Integration** - P1 - deps: A1,A2 - status: TODO

Make baccarat and roulette feel like Grand Casino premium games and ensure they feed staff attention.

DONE: premium games support the boss-floor pressure loop and high-roller route.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK C3 - Integrate baccarat and roulette into Grand Casino boss pressure.

Read:
- scripts/games/baccarat.gd.
- scripts/games/roulette.gd.
- data/environments/archetypes.json Grand Casino game pool.
- scripts/tests/foundation_check.gd baccarat/roulette tests and Grand Casino-only baccarat check.

Ensure baccarat and roulette:
- remain full-simulation modules
- remain appropriate for Grand Casino premium play
- contribute to Grand Casino games-played and net-winnings tracking
- mark staff attention when read-shoe/read-wheel style cheat actions happen while watched
- communicate patron/snitch/staff pressure in result messages
- do not appear outside Grand Casino unless explicitly intended by content

Tests:
- Baccarat remains Grand Casino-only.
- Roulette and baccarat count toward high-roller progress.
- Their cheat/advantage actions can feed staff attention/showdown pressure.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot
- run baccarat/roulette audit tools where applicable.
```

**C4 - Slot Release Acceptance Audit** - P1 - deps: none - status: TODO

Run the current slot stack through final acceptance without reverting to stale rework assumptions.

DONE: slot system passes acceptance and any release-critical issues are fixed.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK C4 - Final slot acceptance audit.

Read:
- scripts/games/slot.gd.
- scripts/games/slots/*
- scripts/tests/foundation_check.gd slot and slot_acceptance suites.
- tools/slot_machine_deep_audit.gd and tools/slot_metrics_probe.gd for current slot behavior evidence. No external slot spec/prompt docs exist; treat the code and these suites as the source of truth, not as proof current code is missing.

Run slot-focused validation and fix release-critical issues:
- deterministic generation
- bet ladder behavior
- pinball/buffalo feature state
- autoplay/runtime state
- nudge/cheat heat
- Grand Casino heat reroute integration
- visual clarity and text overlap

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite slot
- check_godot.ps1 -RequireGodot -FoundationSuite slot_acceptance
- tools/slot_cabinet_visual_qa.ps1 -RequireGodot if available
```

**C5 - Skill-Based Cheating Consistency Pass** - P1 - deps: A2 - status: TODO

Standardize the skill-based cheat interaction model (the blackjack count-challenge pattern) across all games so cheating is a coherent, polished pillar instead of per-game ad hoc behavior.

DONE: every game that supports cheating uses a consistent skill-cheat contract that reports heat/attention through the same paths and integrates with the Grand Casino reroute.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK C5 - Make skill-based cheating consistent across all games.

Read:
- scripts/games/blackjack.gd count_challenge, _start_count_challenge(), _finalize_count_challenge(), _sync_count_challenge_icons(), cheat_actions().
- scripts/core/game_module.gd cheat_actions() and apply_result().
- scripts/core/run_state.gd security_action_pressure(), security_risk_bonus(), pit_boss_watch_status().
- scripts/games/video_poker.gd holdout cheat; scripts/games/bar_dice.gd cheats; scripts/games/roulette.gd, scripts/games/baccarat.gd, scripts/games/slot.gd, scripts/games/pull_tabs.gd cheat/advantage actions.
- docs/plans/grand_casino_endgame_design.md staff-attention definition.

Blackjack implements a rich skill-based cheat (the count challenge) with a watched/attention model; other games implement cheats unevenly. Define and apply a shared skill-cheat contract:
- A common result shape for cheat/advantage actions: action_kind, skill outcome, suspicion delta, watched flag, and story context.
- Each cheating game exposes its cheats through cheat_actions() and resolves them through security_action_pressure with consistent action_kind values ("cheat"/"risky"/"advantage").
- Watched cheats on the Grand Casino floor mark staff attention per the A0/A2 definition.
- Cheat outcomes record enough story/context for clean-vs-cheat high-roller tracking (A4).
- Each cheat communicates skill, payoff, and risk in result copy without placeholder text.

Do not rebuild game rules. Refactor toward a shared contract; promote reusable helpers into GameModule where it removes duplication. Where a game's cheat is intentionally simpler than the count challenge, document why rather than forcing parity.

Tests:
- Each cheating game routes its cheat through security_action_pressure and reports consistent fields.
- A watched Grand Casino cheat in each game can mark staff attention / showdown pressure.
- Clean play in each game leaves no open-cheat evidence.
- Existing per-game module contract tests still pass.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite systems
- Run available per-game audit tools (blackjack/roulette/baccarat/slot) where present.
```

### Category D - Content, Economy, And Balance

**D1 - Grand Casino Boss Content Pass** - P0 - deps: A1,A3,A4 - status: TODO

Author the content needed to support Rourke, high rollers, and the back room.

DONE: boss-floor events and copy support both final victory routes.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK D1 - Author and wire the final Grand Casino boss content.

Read:
- data/events/events.json.
- data/environments/archetypes.json grand_casino.
- data/art/art_manifest.json.
- scripts/core/event_module.gd.
- scripts/ui/pixel_scene_canvas.gd event props.

Add or revise boss content:
- Rourke attention event
- high-roller host/cage cashout event
- back-room showdown event content
- security/staff attention cues
- event summaries and choice consequence summaries
- art manifest entries for new boss/back-room props

Keep copy short and validator-safe. Make sure boss events do not randomly block or contradict the endgame routes.

Tests:
- New events validate.
- Conditions gate events correctly.
- Boss events are scoped to boss/Grand Casino.
- Art manifest references exist.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite contracts
```

**D2 - Full Content Depth Pass** - P1 - deps: none - status: TODO

Expand current thin content enough for a replayable polished demo.

DONE: multiple routes and play styles have supporting content.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK D2 - Expand demo content depth across rooms.

Read:
- data/items/items.json.
- data/events/events.json.
- data/services/services.json.
- data/debt/lenders.json.
- data/travel/routes.json.
- data/environments/archetypes.json.
- scripts/core/content_library.gd validators.

Current content is playable but thin. Add enough data-driven content to support:
- clean play
- advantage play
- cheating
- debt recovery
- alcohol/luck tradeoffs
- travel scouting
- heat management
- Grand Casino preparation

Do not bloat the game with out-of-scope systems. Prefer a smaller number of polished, useful entries over a huge noisy pack.

Tests:
- Content validates.
- No duplicate ids.
- All referenced items/events/services/lenders/routes exist.
- Object-card copy limits pass.
- Multi-seed generation shows variety without incoherent rooms.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite contracts
- tools/environment_generation_audit.ps1 -RequireGodot if available
```

**D3 - Economy And Endgame Balance Gauntlet** - P0 - deps: A3,A4,C1,D1,D7 - status: TODO

Tune the whole run so both Grand Casino victory paths are viable and distinct.

DONE: batch data shows reasonable win/failure rates and multiple viable strategies.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK D3 - Balance the final demo economy and endgame.

Read:
- README.md product shape and design principles.
- data/environments/archetypes.json economic profiles and Grand Casino objective.
- data/travel/routes.json.
- data/items/items.json.
- data/services/services.json.
- data/debt/lenders.json.
- data/games/games.json.
- scripts/core/run_state.gd economy, heat, alcohol, debt methods.

Tune:
- starting bankroll if needed
- route costs, especially Grand Casino buy-in
- Grand Casino high-roller target
- showdown heat thresholds
- game stake floors/ceilings
- item prices/effects
- service/lender values
- alcohol/luck tradeoffs
- debt pressure

Goals:
- Clean high-roller route is possible without cheating.
- Heat/showdown route is tempting but dangerous.
- Cheating is powerful but creates readable Rourke pressure.
- Bankruptcy/recovery has teeth but does not dominate every run.
- Demo length is reasonable.

Use data tuning where possible. Avoid hardcoded balance constants unless they belong in RunState/system code.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot
- foundation_mouse_batch_playtest.ps1 -RunCount 60 -RequireGodot -AllowRunFailures
- Produce balance notes in this task's final response or a small docs/plans balance note if needed.
```

**D4 - Alcohol, Luck, Debt, And Recovery Polish** - P1 - deps: D2,D3 - status: TODO

Audit the supporting pressure systems so they feel meaningful but not mandatory.

DONE: systems are readable, balanced, and reflected in UI/story.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK D4 - Polish alcohol, luck, debt, and recovery systems.

Read:
- scripts/core/run_state.gd alcohol/luck/debt/economy methods.
- scripts/core/run_action_service.gd services/lenders/items.
- data/services/services.json.
- data/debt/lenders.json.
- data/items/items.json.
- scripts/ui/drunk_distortion_overlay.gd.
- scripts/ui/foundation_main.gd HUD and consequence cards.

Audit and tune:
- alcohol intake and dependency progression
- effective luck tradeoff
- heat amplification from alcohol
- lender availability and repayment pressure
- recovery availability when bankroll is low
- HUD/consequence clarity
- story log entries

Ensure the systems support clean, cheat, and recovery strategies without becoming mandatory.

Tests:
- Alcohol affects luck/heat as intended.
- Debt/recovery saves a run without creating free money loops.
- UI snapshots show readable state.
- Save/load preserves all relevant state.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite systems
```

**D5 - Prestige And Challenge Decision** - P1 - deps: B1 - status: TODO

Resolve empty prestige data and challenge hooks for the demo.

DONE: no confusing empty systems remain in the release UI.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK D5 - Decide and implement demo prestige/challenge behavior.

Read:
- data/prestige/purchases.json.
- scripts/core/run_action_service.gd prestige methods.
- scripts/core/run_state.gd challenge and prestige helpers.
- scripts/ui/foundation_main.gd prestige objects and menu.
- README.md current status.

Prestige:
- Either hide prestige entirely for the demo because Grand Casino is the demo victory, or add one post-demo teaser purchase that is clearly not the main win condition.
- Empty prestige data must not produce confusing UI/HUD/action state.

Challenges:
- Either add a small data/challenges/challenges.json and wire Daily/Custom challenge UI, or hide challenge UI for this demo.
- Daily seed should be deterministic by local date if implemented.

Tests:
- Chosen prestige behavior is stable with empty or populated data.
- Challenge/daily run starts deterministically if implemented.
- UI does not show dead controls.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite systems
- check_godot.ps1 -RequireGodot -FoundationSuite ui
```

**D6 - Narrative Voice And Content Style Guide** - P1 - deps: none - status: TODO

Author a content voice/style guide and bring existing copy into line, so the polished demo content reads consistently and future content does not need rewriting.

DONE: docs/plans/content_style_guide.md exists and current player-facing copy conforms.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK D6 - Establish narrative voice and content style guide.

Read:
- README.md tone and product shape.
- data/events/events.json, data/items/items.json, data/services/services.json, data/debt/lenders.json copy.
- scripts/core/content_library.gd copy-length validators.

Produce docs/plans/content_style_guide.md defining:
- Voice and tone (seedy, deterministic-luck casino roguelike; no real-money framing).
- Person/tense conventions for narration and choice copy.
- Length budgets aligned to the existing validator limits, per content type.
- Terminology canon (Rourke, the back room, heat, staff attention, high roller, cage/host) so D1/D2 content matches A0.
- Do/don't list: no placeholder/TODO/dev copy, no leaking mechanics as raw numbers in narration, no real-money implications.

Then audit and revise existing player-facing copy across events/items/services/lenders to conform. Fix the worst inconsistencies now; do not invent new content here (D2 adds volume).

Tests:
- All copy still passes validator length/limit checks.
- No placeholder/TODO/dev-only strings remain in release content.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite contracts
```

**D7 - Endgame Balance Metrics Harness** - P1 - deps: A3,A4 - status: TODO

Build endgame-aware run metrics so D3 balance is data-driven, not guesswork.

DONE: a deterministic metrics report summarizes route outcomes across many seeds to drive D3 tuning.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK D7 - Build the endgame balance metrics harness.

Read:
- tools/foundation_mouse_batch_playtest.ps1 and tools/slot_metrics_probe.gd as patterns.
- scripts/core/run_state.gd demo objective, heat, economy, and story helpers.
- scripts/tests/foundation_check.gd deterministic run-driving patterns.

Add a deterministic batch metrics tool (e.g. tools/endgame_metrics_probe.gd + .ps1) that runs many seeds and reports:
- victory-route distribution (high_roller_cashout vs pit_boss_showdown vs none).
- failure-reason distribution (bankroll_zero, stranded, police_capture, casino_taken_out_back).
- average/median heat at Grand Casino entry and at terminal.
- bankroll-curve milestones and Grand Casino net-winnings distribution.
- showdown win rate; clean-vs-cheat outcome split.
- run length (steps/venues) distribution.

Use RngStream/seeded runs only; no engine-global RNG. Output a compact summary suitable for pasting into D3 balance notes. Keep heavy work off frame paths.

Tests:
- Probe runs deterministically for a fixed seed set.
- Report includes all route/failure categories.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot
- Run the new probe over a small seed set and include a sample report.
```

### Category E - Visual And Audio Polish

**E1 - Grand Casino And Back-Room Visual Pass** - P1 - deps: A3,D1 - status: TODO

Make the boss floor and back room visually readable.

DONE: the Grand Casino finale has distinct, polished presentation.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK E1 - Polish Grand Casino and back-room visual presentation.

Read:
- scripts/ui/pixel_scene_canvas.gd.
- data/environments/archetypes.json Grand Casino layout/visual_context.
- data/art/art_manifest.json.
- assets/art/environments/grand_casino.png.
- assets/art/events/*.

Improve visual readability:
- Grand Casino floor should clearly show cameras, high-limit tables, cage/host, and Rourke.
- Pit boss watched/unwatched state should be readable.
- Back-room showdown should have a distinct scene or modal presentation.
- High-roller cashout should have a distinct object/host/cage presentation.
- Event/game/service/travel objects should not collapse into label clutter.

Keep current art pipeline and procedural canvas style. Add assets only if necessary.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite ui
- foundation_visual_qa.ps1 -RequireGodot
```

**E2 - SFX And Music Cue Finalization** - P1 - deps: A3,A4,C2 - status: TODO

Add final audio feedback for boss/endgame and audit existing game cues.

DONE: key endgame and game moments have clear cues.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK E2 - Finalize SFX/music cue coverage.

Read:
- scripts/ui/sfx_player.gd.
- scripts/ui/procedural_music_player.gd.
- scripts/ui/game_surface_canvas.gd audio cue handling.
- Game modules' surface_audio specs.

Add or refine cues for:
- pit boss watched state
- Rourke calling the player back
- back-room showdown start
- showdown success
- taken-out-back failure
- high-roller cashout
- demo victory
- key current game interactions if missing or mistimed

Do not replace the procedural music system. Keep cue generation off hot play-frame paths.

Tests:
- Cues are referenced by UI/game state.
- No missing cue ids in normal release paths.
- Reduced motion/settings do not break cue flow.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot
- foundation_visual_qa.ps1 -RequireGodot if it exercises audio snapshots/cues
```

**E3 - Text, Layout, And Touch Collision Pass** - P1 - deps: A5,B2,C2 - status: TODO

Hunt down overlap and small-target issues across the final UI.

DONE: no release path has incoherent overlap or unreadable controls.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK E3 - Run a full text/layout/touch collision pass.

Read:
- scripts/ui/foundation_main.gd.
- scripts/ui/game_surface_canvas.gd.
- scripts/ui/pixel_scene_canvas.gd.
- scripts/ui/visual_style.gd.
- tools/foundation_visual_qa.gd.

Audit:
- main menu
- HUD/objective band
- environment view
- event choices
- inventory/shop
- travel
- game surfaces
- in-run menu/journal
- showdown
- victory/failure summaries

Fix:
- text overflow
- overlapping labels/buttons
- touch targets too small
- hover/selection states shifting layout
- mobile aspect problems

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite ui
- foundation_visual_qa.ps1 -RequireGodot
- foundation_mouse_playtest.ps1 -RequireGodot if useful
```

### Category F - Save, Stability, Export, And Release

**F1 - Save/Load Versioning And Robustness** - P0 - deps: A1-A5,B3 - status: TODO

Make saves robust across final demo state.

DONE: every new endgame and UI state round-trips or gracefully resets.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK F1 - Harden save/load for final demo state.

Read:
- scripts/core/save_service.gd.
- scripts/core/run_state.gd to_dict/from_dict and normalization helpers.
- scripts/ui/foundation_main.gd load/save/autosave behavior.

Ensure saves preserve:
- Grand Casino entry state
- high-roller progress/eligibility
- open-cheat status in Grand Casino
- staff attention flags
- showdown pending and showdown step
- victory route
- casino_taken_out_back failure
- journal/story log
- in-progress game state where already supported

Add schema versioning or migration defaults if not present. Corrupt/missing saves should not crash the game.

Tests:
- Round-trip all new fields.
- Load old minimal save without new fields.
- Corrupt save handling is graceful.
- Save/load from showdown and terminal screens.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite systems
```

**F2 - Performance And Stability Hardening** - P1 - deps: A6,C2,E3 - status: TODO

Run the heavy QA loops and fix real issues.

DONE: full suite and batch playtests are stable.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK F2 - Performance and stability hardening.

Read:
- tools/foundation_performance_probe.gd/.ps1.
- tools/foundation_mouse_batch_playtest.ps1.
- scripts/ui/procedural_music_player.gd performance notes.
- any code touched by recent finalization tasks.

Run:
- foundation_performance_probe.ps1 -RequireGodot
- foundation_mouse_batch_playtest.ps1 -RunCount 60 -RequireGodot -AllowRunFailures

Fix:
- frame-path heavy work
- memory growth
- autoplay/runtime instability
- terminal-state routing crashes
- input deadlocks
- UI overlap that causes mouse batch failure

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot
- foundation_performance_probe.ps1 -RequireGodot
- foundation_mouse_batch_playtest.ps1 -RunCount 60 -RequireGodot -AllowRunFailures
```

**F3 - Final Automated QA Gauntlet** - P1 - deps: ALL P0,P1 implementation tasks - status: TODO

Run and document final repo validation.

DONE: standard gate passes and release checklist has evidence.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK F3 - Run the final automated QA gauntlet.

Read:
- README.md validation section.
- tools/*.ps1.
- scripts/tests/foundation_check.gd.
- scripts/tests/ui_scene_compile_check.gd.

Run the standard release gate:
1. validate_project.ps1
2. check_godot.ps1 -RequireGodot
3. foundation_visual_qa.ps1 -RequireGodot
4. foundation_performance_probe.ps1 -RequireGodot
5. foundation_mouse_batch_playtest.ps1 -RunCount 60 -RequireGodot -AllowRunFailures

Also run targeted audits for blackjack, pull tabs, roulette, baccarat, and slots if relevant scripts are present.

Do not accept unknown regressions. If a tool reveals real failures, fix them or create a precise blocker note only if the failure cannot be resolved in this task.

DONE:
- Full gate output summarized.
- 0 true app failures accepted for release.
- Any allowed run failures are understood gameplay losses, not crashes/bugs.
```

**F4 - Desktop And Mobile Export Readiness** - P2 - deps: F3 - status: TODO

Verify configured exports and document any credential blockers.

DONE: desktop build launches; mobile export blockers are explicit.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK F4 - Verify export readiness.

Read:
- export_presets.cfg.
- README.md Export Targets.
- project.godot platform/render settings.
- tools/run_godot.ps1 and tools/check_godot.ps1.

Verify:
- Windows desktop export path builds and launches.
- Android export preset is coherent; signing credential blockers are documented.
- iOS export preset is coherent; team/signing blockers are documented.
- Window/input/scaling settings work in exported desktop build.
- Release build does not expose dev-only Game Test UI.

Make small config fixes if needed. Do not invent signing credentials.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot
- documented export checklist and build result.
```

**F5 - Compliance And Store Framing** - P1 - deps: B1 - status: TODO

Finish non-real-money gambling framing and release disclaimers.

DONE: release path clearly frames the game as simulated gambling with no real-money mechanics.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK F5 - Add compliance and simulated-gambling framing.

Read:
- README.md Product Shape and Design Principles.
- scripts/ui/foundation_main.gd main menu/start flow.
- export presets and platform notes.

Add release-appropriate framing:
- no real-money gambling
- no gambling monetization
- simulated casino roguelike
- age/content note if appropriate

The copy should fit the game's tone and avoid legalistic clutter during normal play. Put it in the launch/menu area or a first-run modal that does not annoy repeated play.

Tests:
- UI snapshot or foundation check confirms framing appears in release path.
- README/export notes reflect the same framing.

DONE GATE:
- validate_project.ps1
- check_godot.ps1 -RequireGodot -FoundationSuite ui
```

**F6 - README Status And Release Checklist** - P1 - deps: F3,F4,F5 - status: TODO

Update docs only after implementation and QA are real.

DONE: README and checklist reflect shipped behavior, not planned behavior.

```text
[PREPEND SHARED FINALIZATION GUIDELINE]

TASK F6 - Update README and final release checklist.

Read:
- README.md.
- docs/plans/demo_release_task_board.md.
- final QA outputs from F3/F4/F5.

Update README current status to reflect what is actually implemented:
- Grand Casino dual victory routes if complete
- high-roller cashout
- Pit Boss Showdown
- terminal summary
- save/load support
- export status
- validation commands and current QA evidence

Create or update a concise release checklist under docs/plans if useful. Do not include generated reports or noisy local artifacts as canonical source docs.

DONE:
- README no longer describes stale behavior.
- Checklist has exact command evidence and known release blockers.
- validate_project.ps1 passes after docs changes.
```

---

## 5. Recommended Execution Order

1. **Design lock:** A0.
2. **Grand Casino state and routing:** A1, A2.
3. **Playable endings:** A3, A4, A5.
4. **Endgame tests:** A6.
5. **Release flow:** B1, B2, B3, B4, B5.
6. **Game integration:** C1, C2, C3, C4, C5.
7. **Content and balance:** D1, D2, D6, D7, D3, D4, D5.
8. **Presentation:** E1, E2, E3.
9. **Hardening and release:** F1, F2, F3, F4, F5, F6.

Parallel-safe groups:

- A0 should land before A1; B1/B5/C4/D6 can run in parallel with A0.
- B1/B5 can run while A1/A2 are in progress.
- C2/C4 can run after A2 interface expectations are known.
- C5 depends on A2 and should precede D7/D3 so cheat pressure is consistent before balancing.
- D7 depends on A3/A4 and must land before D3.
- D2 can run before final balance, but D3 must happen after A3/A4 and D7.
- E2 can start once A3/A4 event ids and cue names stabilize.

Do not run F3/F4/F6 until all P0 and intended P1 tasks are complete.

---

## 6. Demo-Complete Gate

The demo is complete when:

- New player flow starts cleanly from the main menu.
- No normal release UI exposes temporary dev-only launchers.
- Every current game is playable and readable from its surface.
- Grand Casino has two working win routes: high-roller cashout and Pit Boss Showdown success.
- Grand Casino high heat with staff attention routes to the back room instead of instant generic police capture.
- Losing the back-room showdown ends with distinct casino-taken-out-back failure copy.
- Victory summary points to the next act as unimplemented.
- Save/load works before, during, and after both endgame routes.
- Content supports multiple strategies without requiring cheating.
- Balance makes clean, advantage, and cheat routes meaningfully different.
- Skill-based cheating is consistent across games and feeds Grand Casino staff attention.
- Accessibility/touch pass is clean enough for desktop and mobile targets.
- Standard release gate passes.
- Packaged desktop build launches.
- README and final checklist match the actual implemented behavior.
