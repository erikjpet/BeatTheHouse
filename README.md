# Beat the House

Beat the House is a Godot casino roguelike foundation about surviving a gambling
run, managing heat and debt, using items, choosing when to cheat, and pushing far
enough to beat the Grand Casino demo objective.

This is a runnable foundation/demo project, not a real-money gambling product. It
has no gambling monetization and no store credentials checked into the repository.

## Current Implementation

| Area | Current state |
| --- | --- |
| Engine | Godot 4.x project with Godot 4.6 project feature metadata |
| Main scene | `res://scenes/main.tscn` |
| Main UI shell | `res://scripts/ui/foundation_main.gd` |
| Viewport | 1280x720, non-resizable, canvas stretch with kept aspect |
| Renderer | Godot mobile renderer |
| Input model | Single pointer interaction with mouse/touch parity |
| Target exports | Windows desktop, Android, iOS |
| Run model | Seeded deterministic run state with forked RNG streams |
| Current win target | Reach the Grand Casino, then win either clean (net +$200 while staying low-heat for a Players Card) or by surviving Pit Boss Rourke's back-room showdown |
| Prestige content | Code path exists, but `data/prestige/purchases.json` is currently empty |

The player starts in a generated low-stakes environment, buys or uses items,
plays full-simulation casino games, takes services or lender offers when needed,
travels through unlocked routes, and either reaches a victory state or fails from
bankroll, heat, police capture, or being stranded without a useful recovery path.

## Core Game Loop

1. `FoundationMain` loads content through `ContentLibrary`.
2. `RunGenerator` creates a seeded run and an initial environment.
3. `EnvironmentInstance` turns archetype data into visible objects: games, items,
   events, services, lenders, travel hooks, and prestige hooks.
4. The player interacts with objects through the shared UI shell.
5. Game modules, item effects, services, lenders, events, travel, and prestige
   targets return result dictionaries.
6. `GameModule.apply_result()` and `RunActionService` apply those results to
   `RunState`.
7. `RunTerminalEvaluator` and `RunState` determine whether the run continues,
   fails, or ends in demo/prestige victory.
8. `SaveService` persists the active run through the autosave slot.

## Content Packs

Production content is JSON under `data/`.

| Pack | Count | Path | Notes |
| --- | ---: | --- | --- |
| Environments | 8 | `data/environments/archetypes.json` | Shops, casinos, the jazz club, and the Grand Casino boss destination |
| Games | 7 | `data/games/games.json` | All current games are full-simulation modules |
| Items | 18 | `data/items/items.json` | Permanent, temporary, consumable, contraband, active, game, security, and travel effects |
| Events | 15 | `data/events/events.json` | Scoped room events with choices and consequences, including the boss-floor `the_house_calls` and `high_roller_cashout` |
| Services | 8 | `data/services/services.json` | `cashier_tip`, `house_drink`, plus jazz-club round/tip/show services |
| Lenders | 2 | `data/debt/lenders.json` | `street_lender`, `motel_friend` |
| Travel routes | 8 | `data/travel/routes.json` | Routes into shops, casinos, the jazz club, the underground casino, and the Grand Casino |
| Prestige purchases | 0 | `data/prestige/purchases.json` | Empty data pack with live code support |
| Challenges | 0 | `data/challenges/challenges.json` | Future optional pack; path is known but no file is present |

`data/art/art_manifest.json` maps art identities used by environments, events,
items, games, and the UI. Asset files live under `assets/`.

## Environments

The current environment pack contains:

| ID | Kind | Tier | Role |
| --- | --- | ---: | --- |
| `corner_store` | shop | 1 | Start-capable item/service stop |
| `back_alley` | shop | 1 | Start-capable risky item/lender stop |
| `motel` | shop | 1 | Start-capable recovery and lender stop |
| `bar` | casino | 1 | Low-stakes gambling room |
| `gas_station_casino` | casino | 1 | Low-stakes gambling room |
| `jazz_club` | shop | 1 | Rare late-1960s music room with trio services, no games, and rare musician rewards |
| `small_underground_casino` | casino | 1 | Larger room with Grand Casino route access |
| `grand_casino` | boss | 3 | Demo objective destination |

Environment archetypes define name parts, visual context, layout points,
security/economic/music profiles, object pools, route hooks, local narrative
flags, and demo objective data. The Grand Casino objective is
`grand_casino_demo_bankroll`: win `$200` on that floor, stay clean enough for
the host to issue a Players Card, or survive Rourke's back-room showdown.

## Games

Game definitions live in `data/games/games.json`. Each game module extends the
shared `GameModule` contract and owns its own surface state, action routing, and
rendering details.

| Game | Family | Module | Current behavior |
| --- | --- | --- | --- |
| Pull Tabs | novelty | `scripts/games/pull_tabs.gd` | Finite pull-tab deals, ticket windows, row/deal state, detector and tarot item interactions |
| Slot | slots | `scripts/games/slot.gd` | Generated Pinball/Buffalo machines, fixed bet ladder, nudge, autoplay, feature bonuses |
| Bar Dice | dice | `scripts/games/bar_dice.gd` | Ship, Captain, Crew as a bar-top table game with patrons, cargo scoring, carryover pots, and loaded/palmed cheat actions |
| Blackjack | cards | `scripts/games/blackjack.gd` | Shoe blackjack with hit/stand/split/double, side bets, count challenge, hole-card peek heat |
| Baccarat | cards | `scripts/games/baccarat.gd` | Mini-baccarat with Player/Banker/Tie/pair bets, commission, and shoe state |
| Roulette | wheel | `scripts/games/roulette.gd` | Full roulette layout with inside/outside bets, chip placement, wheel spin, and payout animation |
| Video Poker | cards | `scripts/games/video_poker.gd` | Multi-game video poker with bet, hold, draw, double-up, and mark-hold cheat action |

Shared table-game visuals live in `scripts/games/table_game_visuals.gd`.

## Slot System

The slot game uses a compact backend/presentation stack. Historical docs may refer
to older slot file names; the live implementation is:

| Path | Responsibility |
| --- | --- |
| `scripts/games/slot.gd` | Public `GameModule`, host action routing, wager cost, autoplay, active feature ticks |
| `scripts/games/slots/slot_catalog.gd` | Machine formats, families, math variants, cabinet skins, symbols, outcome helpers |
| `scripts/games/slots/slot_machine_generator.gd` | Deterministic machine generation from run/environment RNG |
| `scripts/games/slots/slot_machine_state.gd` | Machine schema, fixed bet ladder, selected bet, active bonus, persistence helpers |
| `scripts/games/slots/slot_resolver.gd` | Spin/nudge resolution, payout attribution, economy deltas, feature open/step, animation plans |
| `scripts/games/slots/slot_family_pinball.gd` | Pinball reel behavior, payouts, feature open/step logic |
| `scripts/games/slots/slot_family_buffalo.gd` | Buffalo reel/ways behavior, free games, Hold and Spin, wheel, Gold Buffalo, jackpots |
| `scripts/games/slots/slot_pinball_table.gd` | Deterministic pinball table physics for feature play |
| `scripts/games/slots/slot_presentation.gd` | Surface-state payload normalization |
| `scripts/games/slots/slot_renderer.gd` | Procedural cabinet, reel, feature, and celebration drawing |
| `scripts/games/slots/slot_rng_math.gd` | Weighted picks and deterministic reel/grid math helpers |

Live slot data exposes:

- 3 formats: `classic_3_reel`, `line_5x3`, `video_feature`.
- 2 families: `pinball`, `buffalo`.
- 3 math variants: `steady`, `standard`, `volatile`.
- 4 bonus variants: `plain`, `retrigger`, `jackpot_chase`, `skill_window`.
- 5 cabinet variants: `neon_magenta`, `cyan_gold`, `hot_orange`, `blacklight`,
  `toxic_teal`.
- 72 behavior combinations and 360 visual machine combinations.
- Fixed bet options: `$2`, `$5`, `$10`, `$15`, `$20`.

Pinball supports classic, 5x3, and video feature identities with live feature
actions. Buffalo supports free games, Hold and Spin, wheel/monster feature paths,
Gold Buffalo collection/conversion, must-hit meter data, and jackpot tiers.

## Runtime Architecture

| Path | Responsibility |
| --- | --- |
| `scripts/core/run_state.gd` | Authoritative run state, RNG state, bankroll, heat, alcohol/luck, debt, inventory, environment, story, terminal status, save payloads |
| `scripts/core/rng_stream.gd` | Deterministic seeded RNG streams and forks |
| `scripts/core/content_library.gd` | Loads and validates JSON content packs |
| `scripts/core/environment_instance.gd` | Builds generated environment instances from archetypes |
| `scripts/core/run_generator.gd` | Chooses starting and next environments |
| `scripts/core/game_module.gd` | Base game contract and shared result application |
| `scripts/core/item_effect.gd` | Item purchase/use/sale effect resolution |
| `scripts/core/event_module.gd` | Event condition and choice resolution |
| `scripts/core/run_action_service.gd` | Services, lenders, travel, item actions, prestige actions |
| `scripts/core/run_terminal_evaluator.gd` | Terminal state evaluation that needs run and content context |
| `scripts/core/save_service.gd` | Autosave/load round trips |
| `scripts/core/platform_services.gd` | Platform abstraction boundary |
| `scripts/core/profile_inventory.gd` | Out-of-run/profile inventory boundary |
| `scripts/core/user_settings.gd` | User settings persistence |
| `scripts/core/card_shoe.gd` | Shared card shoe support |
| `scripts/core/art_contracts.gd` | Art contract constants/helpers |

`RunState` is the source of truth for the active run. Game and action modules
return data; the shared result path mutates the run.

## UI And Presentation

| Path | Responsibility |
| --- | --- |
| `scripts/ui/foundation_main.gd` | Main UI shell, run lifecycle, object focus, game entry/exit, autosave, terminal screens, test snapshots |
| `scripts/ui/game_surface_canvas.gd` | Shared host for full-simulation game surfaces, hit regions, animation channels, audio cues, scaling |
| `scripts/ui/pixel_scene_canvas.gd` | Procedural environment/object scene rendering |
| `scripts/ui/sfx_player.gd` | Procedural and shared sound effect playback |
| `scripts/ui/procedural_music_player.gd` | Procedural room music |
| `scripts/ui/main_menu_background.gd` | Main menu animated background |
| `scripts/ui/settings_menu.gd` | Settings UI |
| `scripts/ui/drunk_distortion_overlay.gd` | Drunk/alcohol visual effect |
| `scripts/ui/icon_sprite_renderer.gd` | Icon rendering helper |
| `scripts/ui/visual_style.gd` | Shared colors and presentation constants |

The UI is designed around mouse/touch parity. Full-simulation games own their
surface-specific state and drawing, while the foundation shell owns flow, routing,
shared state, autosave, and terminal presentation.

## Save, Failure, And Victory

- Autosave slot: `foundation_ui_autosave`.
- Save/load is routed through `SaveService` and `RunState` payloads.
- Bankroll-zero failure can be deferred when a game needs to finish resolving a
  state transition cleanly.
- Terminal failure reasons are defined in `RunState`: `bankroll_zero`,
  `stranded`, `police_capture`, `casino_taken_out_back` (losing the Grand Casino
  back-room showdown), and `abandoned` (the player walks away).
- Demo victory is driven by environment `demo_objective` data and has two Grand
  Casino routes: the clean `high_roller_cashout` Players Card route and the
  `pit_boss_showdown` (`the_house_calls`) back-room route. See
  `docs/plans/grand_casino_endgame_design.md` for the authoritative endgame
  contract.
- Prestige victory is implemented as a code path through `RunActionService`, but
  no prestige purchases are currently present in data.

## Repository Layout

```text
assets/                  PNG art used by environment, event, item, game, and UI presentation
data/                    JSON content packs and art manifest
docs/plans/              Active planning docs: demo release task board and Grand Casino endgame design lock
scenes/main.tscn          Active Godot scene wired to FoundationMain
scripts/core/             Runtime state, content loading, generation, result application, save/load
scripts/games/            Full-simulation game modules
scripts/games/slots/      Slot generation, state, resolver, families, renderer, math helpers
scripts/tests/            Headless Godot foundation and UI compile checks
scripts/ui/               Foundation shell, canvases, render helpers, audio, settings
tools/                    Validation wrappers, audits, probes, visual QA, Godot install/run helpers
export_presets.cfg        Windows, Android, and iOS export presets
project.godot             Godot project configuration
```

Generated and local paths are intentionally not source:

- `.godot/`
- `.tmp/`
- `tmp/`
- `.tools/`
- `builds/`
- `*.uid`
- `*.import`
- local assistant/editor config directories

## Running The Project

From PowerShell:

```powershell
.\tools\run_godot.ps1
```

Open the editor:

```powershell
.\tools\run_godot.ps1 -Editor
```

Install a local Godot binary into `.tools/`:

```powershell
.\tools\install_godot.ps1
```

`run_godot.ps1` resolves Godot in this order:

1. `GODOT_BIN`
2. `.tools\`
3. `godot` on `PATH`

## Validation

Fast repository validation:

```powershell
.\tools\validate_project.ps1
```

Godot-backed suites:

```powershell
.\tools\check_godot.ps1 -Suite Smoke
.\tools\check_godot.ps1 -Suite Contract
.\tools\check_godot.ps1 -Suite Audit
.\tools\check_godot.ps1 -Suite Full
```

Useful targeted tools:

```powershell
.\tools\slot_cabinet_visual_qa.ps1
.\tools\environment_generation_audit.ps1
.\tools\foundation_visual_qa.ps1
.\tools\foundation_mouse_playtest.ps1
.\tools\foundation_mouse_batch_playtest.ps1
.\tools\foundation_performance_probe.ps1
.\tools\blackjack_seed_audit.ps1
.\tools\run_baccarat_seed_audit.ps1
.\tools\roulette_seed_audit.ps1
```

Additional GDScript audit/probe files live in `tools/`, including slot metrics,
slot deep audit, roulette rule/audio/interface checks, baccarat interface capture,
pull-tab seed audit, and GDScript load checks. Reports are written under `.tmp/`
or Godot `user://` paths and should not be committed as source documentation.

## Documentation

The README is the current top-level implementation spec. The `docs/plans/`
folder currently holds two tracked planning documents:

- `docs/plans/demo_release_task_board.md` - the executable finalization task
  board for taking the project from its runnable foundation to a polished demo
  release. This is the active planning entry point.
- `docs/plans/grand_casino_endgame_design.md` - the authoritative Grand Casino
  endgame design lock (dual victory routes, showdown structure, state machine,
  and canonical ids).

For current slot implementation work, use the slot stack listed in this README
rather than any older file names referenced inside historical plan text.

## Export Targets

| Preset | Platform | Output |
| --- | --- | --- |
| Windows Steam | Windows Desktop | `builds/windows/BeatTheHouse.exe` |
| Android | Android | `builds/android/BeatTheHouse.aab` |
| iOS | iOS | `builds/ios/BeatTheHouse.zip` |

Android signing and iOS team/signature values still require real project
credentials before store submission.

## Design Rules

- Beat the House is a casino roguelike, not a casino monetization product.
- Runs should create gambling stories through systems, not fixed scripting.
- Simulation must be deterministic from seed and explicit RNG streams.
- High-risk actions should have readable upside and consequence.
- Cheating is optional and should raise heat or risk when used.
- Game modules own their detailed surfaces.
- The foundation shell owns flow, routing, autosave, and shared run state.
- Data carries content identity; scripts carry contracts and reusable behavior.
- UI interaction should remain single-pointer friendly for desktop and mobile.
- Renderer and presentation code should not own backend payout, RNG, or economy
  mutation.

## Cleanup Policy

Keep the repository focused on runnable source, current specs, source assets, and
intentional documentation. Do not commit generated Godot caches, import products,
temporary reports, build outputs, local tool installs, or assistant/editor state.

When a planning document becomes outdated, preserve it as historical context or
fold the surviving truth into this README or an active tracked plan. Do not let
obsolete file names override the current implementation described here.
