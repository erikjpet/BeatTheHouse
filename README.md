# Beat the House

Beat the House is a single-player Godot casino roguelike about surviving a
debt-and-heat spiral across low-stakes rooms and the Grand Casino. Build a
seeded run, buy risky items, take loans and services, travel between venues, and
play full simulations of Pull Tabs, Slots, Bar Dice, Blackjack, Baccarat,
Roulette, and Video Poker. Every win, cheat, drink, loan, and bad exit pushes
the run state forward.

The runnable 0.2.0 demo candidate has shipped. Current development targets the
Act 1 feature-complete scope: the full street-to-Grand-Casino arc, deeper
mid-game content, cross-game skill cheating, polished feature events, complete
presentation/audio, and a clean Act 2 handoff. Beat the House is not a
real-money gambling product. It has no real-money wagering, cash prizes,
gambling monetization, or store credentials checked into the repository.

## 0.2.0 Demo Highlights

- Seven full-simulation games with shared run-state consequences.
- Generated Pinball and Buffalo slot machines with cabinet art, fixed bet
  ladders, feature bonuses, nudge/autoplay support, and active room previews.
- Seeded run generation, daily runs, content-group packs, autosave/load, travel,
  events, services, lenders, debt, heat, alcohol/luck, items, and terminal
  states.
- Grand Casino demo objective with two victory routes: a clean Players Card
  cashout or Pit Boss Rourke's back-room showdown.
- Web/itch.io and Windows export packaging, with Android and iOS presets staged
  for future credentialed store work.

## Current Implementation

| Area | Current state |
| --- | --- |
| Engine | Godot 4.x project with Godot 4.6 project feature metadata |
| Main scene | `res://scenes/main.tscn` |
| Main UI shell | `res://scripts/ui/foundation_main.gd` |
| Shipped baseline | 0.2.0 demo release candidate |
| Active planning target | Act 1 feature-complete |
| Viewport | 1280x720, non-resizable, canvas stretch with kept aspect |
| Renderer | Godot mobile renderer |
| Input model | Single pointer interaction with mouse/touch parity |
| Target exports | Web/itch.io, Windows desktop, Android, iOS |
| Run model | Seeded deterministic run state with forked RNG streams |
| Current win target | Reach the Grand Casino, then win either clean (net +$200 while staying low-heat for a Players Card) or by surviving Pit Boss Rourke's back-room showdown |
| Prestige content | Act 1 keeps prestige dormant: the code path exists, but empty `data/prestige/purchases.json` hides all prestige UI/objects |

The player starts in a generated low-stakes environment, buys or uses items,
plays full-simulation casino games, takes services or lender offers when needed,
travels through unlocked routes, and either reaches a victory state or fails from
bankroll, heat, police capture, or being stranded without a useful recovery path.

## Core Game Loop

1. `FoundationMain` loads content through `ContentLibrary`.
2. `RunGenerator` creates a seeded run and an initial environment.
3. `EnvironmentInstance` turns archetype data into visible objects: games, items,
   events, services, lenders, travel hooks, and prestige hooks when prestige
   data exists.
4. The player interacts with objects through the shared UI shell.
5. Game modules, item effects, services, lenders, events, travel, and any
   authored prestige targets return result dictionaries.
6. `GameModule.apply_result()` and `RunActionService` apply those results to
   `RunState`.
7. `RunTerminalEvaluator` and `RunState` determine whether the run continues,
   fails, or ends in demo victory or a future data-enabled prestige victory.
8. `SaveService` persists the active run through the autosave slot.

## Content Packs

Production content is JSON under `data/`.

| Pack | Count | Path | Notes |
| --- | ---: | --- | --- |
| Environments | 10 | `data/environments/archetypes.json` | Shops, tier-1 casinos, tier-2 venues, the jazz club, and the Grand Casino boss destination |
| Games | 7 | `data/games/games.json` | All current games are full-simulation modules |
| Items | 59 | `data/items/items.json` | Permanent, temporary, consumable, contraband, active, game, security, travel, slot, pinball, and build-synergy effects |
| Content groups | 9 | `data/content_groups/groups.json` | Modular run packs that enable/disable games and their related item pools |
| Events | 31 | `data/events/events.json` | Scoped room events with choices and consequences, including unavoidable pressure events and the boss-floor `the_house_calls` and `high_roller_cashout` |
| Services | 12 | `data/services/services.json` | `cashier_tip`, `house_drink`, `call_brother_in_law`, jazz-club round/tip/show services, and tier-2 lounge/riverboat services |
| Lenders | 5 | `data/debt/lenders.json` | `street_lender`, `motel_friend`, `the_crew`, `brother_in_law`, `sals_pawn_counter` |
| Travel routes | 10 | `data/travel/routes.json` | Routes into shops, casinos, tier-2 venues, the jazz club, the underground casino, and the Grand Casino, with costs, unlocks, scouting previews, travel locks, and route-risk events |
| Prestige purchases | 0 | `data/prestige/purchases.json` | Empty Act 1 data pack; HUD, menu, room, and victory hooks stay hidden |
| Challenges | 7 | `data/challenges/challenges.json` | Act 1 authored challenge runs with profile completion flags |

`data/art/art_manifest.json` maps art identities used by environments, events,
items, games, and the UI. Asset files live under `assets/`.

Run content groups are selected through the start-menu seed settings and stored
in `RunState.challenge_config.modifiers.content_groups`. Standard runs enable
all default groups; custom challenge work can remove a game pack to remove both
that game from generated rooms and its game-specific items from shop pools.

Authored challenges are selected from the start menu when
`data/challenges/challenges.json` loads. They reuse the same
`RunState.challenge_config` modifier contract for starting bankroll, heat, luck,
debt, content groups, service availability/prices, cheat suppression, and Grand
Casino target tuning. Completing a challenge records its `completion_flag` in the
profile inventory file; challenges do not add meta-currency or Act 2 unlocks.

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
| `kitty_cat_lounge` | casino | 2 | Velvet-rope lounge with a house wheel, champagne pressure, and paid heat management |
| `delta_queen` | casino | 2 | Riverboat mid-stakes rung with scheduled boarding and temporary travel lock |
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
| `scripts/games/slots/slot_family_pinball.gd` | Pinball reel behavior, payouts, and delegation to the pinball feature runtime |
| `scripts/games/slots/slot_family_buffalo.gd` | Buffalo reel/ways behavior, free games, Hold and Spin, wheel, Gold Buffalo, jackpots |
| `scripts/games/slots/pinball/` | Pinball feature sim, board compiler/data, sequencer, item hooks, and feature adapter |
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
actions through the reworked runtime under `scripts/games/slots/pinball/`.
Acceptance follow-up for the post-rework slot stack is tracked in the active Act
1 board. Buffalo supports free games, Hold and Spin, wheel/monster feature paths,
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
- Prestige victory is implemented as a future code path through
  `RunActionService`, but Act 1 keeps `data/prestige/purchases.json` empty and
  the empty pack produces no menu, HUD, environment, or victory-screen hooks.

## Repository Layout

```text
assets/                  PNG art used by environment, event, item, game, and UI presentation
data/                    JSON content packs and art manifest
docs/plans/              Active Act 1 board, release ledgers, design locks, and historical plans
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

For shipped 0.2.0 release evidence, use the tracked checklist at
`docs/plans/0.2_release_checklist.md` as the command-evidence ledger. For active
Act 1 work, use `docs/plans/act_one_feature_complete_task_board.md`.

## Documentation

The README is the current top-level implementation spec. The `docs/plans/`
folder holds active planning documents, shipped-release ledgers, and historical
context:

- `docs/plans/act_one_feature_complete_task_board.md` - the active planning
  entry point for Act 1 feature-complete work, including the T0.1 status ledger
  and current gap table.
- `docs/plans/pinball_feature_rework_plan.md`,
  `docs/plans/pinball_feel_reference.md`, and
  `docs/plans/pinball_rework_progress.md` - the pinball feature rework spec,
  feel targets, progress, and acceptance evidence. Use these with the live slot
  stack when touching pinball or shared slot release work.
- `docs/plans/grand_casino_endgame_design.md` - the authoritative Grand Casino
  endgame design lock (dual victory routes, showdown structure, state machine,
  and canonical ids).
- `docs/plans/0.2_release_checklist.md` - the shipped 0.2.0 release readiness
  checklist, including validation evidence and known blockers.
- `docs/plans/demo_release_task_board.md` - historical 0.2.0 demo finalization
  board. Its prompts remain useful context, but it is not the active planning
  entry point.

For current slot implementation work, use the slot stack listed in this README
and the pinball rework docs above rather than older file names referenced inside
historical plan text.

## Export Targets

| Preset | Platform | Output |
| --- | --- | --- |
| Web | Web | `builds/web/index.html` |
| Windows Steam | Windows Desktop | `builds/windows/BeatTheHouse.exe` |
| Android | Android | `builds/android/BeatTheHouse.aab` |
| iOS | iOS | `builds/ios/BeatTheHouse.zip` |

`tools/export_itch.ps1` packages the Web and Windows presets for itch.io upload
after Godot export templates are installed. Android signing and iOS
team/signature values still require real project credentials before store
submission.

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
