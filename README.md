# Beat the House

Beat the House is a single-player Godot casino roguelike about surviving a
debt-and-heat spiral across low-stakes rooms and the Grand Casino. Build a
seeded run, buy risky items, take loans and services, travel between venues, and
play full simulations of Scratch Tickets, Pull Tabs, Slots, Bar Dice,
Blackjack, Baccarat, Roulette, and Video Poker. Every win, cheat, drink, loan,
and bad exit pushes the run state forward.

Versions 0.2.0 through 0.3.3 are historical source releases; 0.4.0 was an Act 1
candidate tag that was not published before development continued. Version
0.5.0 is the current pre-human release-candidate source line. It keeps the Act
1 foundation and reworks the Grand Casino into a three-room endgame with a living
Rourke, a chips-and-Cage economy, Linda's Bronze/Silver/Gold Players Card
ladder, a four-phase back-room showdown, a playable heads-up blackjack duel,
and persistent card/chip meta rewards. Integration recovery, the agent-driven
tutorial matrix, native performance/liveness, the 180-minute soak, and Grand
Casino Web runtime checks are green. The cold-player tutorial gate, the final
Web cold-start/broad performance closure, owner playtest, fresh export
packaging, uploads, and release tag remain pending until recorded otherwise.
Beat the House is not a real-money gambling product. It has no real-money
wagering, cash prizes, gambling monetization, or store credentials checked into
the repository.

## Current Implementation

| Area | Current state |
| --- | --- |
| Engine | Godot 4.x project with Godot 4.6 project feature metadata |
| Main scene | `res://scenes/main.tscn` |
| Main UI shell | `res://scripts/ui/foundation_main.gd` |
| Prior release line | 0.3.3 public source release; 0.4.0 unpublished Act 1 candidate |
| Active planning target | 0.5.0 pre-release verification and owner approval |
| Current release readiness | Feature implementation and pre-human tutorial repair are complete; Web cold-start/broad performance closure, TUT-N17 cold-player testing, final owner playtest, packaging, upload, and tag remain pending in `docs/todo/README_0_5_release_queue.md` |
| Viewport | 1280x720, non-resizable, canvas stretch with kept aspect |
| Renderer | Godot mobile renderer by default; Windows uses Godot compatibility/OpenGL to avoid the native Vulkan/OBS crash path seen in local WER reports |
| Input model | Single pointer interaction with mouse/touch parity |
| Target exports | Web/itch.io and Windows desktop; Android/iOS presets remain credential-blocked |
| Run model | Seeded deterministic run state with forked RNG streams |
| Current win target | Reach the Grand Casino, then earn Gold clean (five settled games, net +$30, heat at most 30) or survive Pit Boss Rourke's four-phase back-room showdown |
| Prestige content | A clean Gold win mints a fragile Players Card; carrying it grants recognition, tightens the clean heat ceiling, improves collection drops, and risks permanent loss on failure |

The player starts in a generated low-stakes environment, buys or uses items,
plays full-simulation casino games, takes services or lender offers when needed,
travels through unlocked routes, and either reaches a victory state or fails from
bankroll, heat, police capture, or being stranded without a useful recovery path.

## Core Game Loop

1. `FoundationMain` loads content through `ContentLibrary`.
2. `RunGenerator` creates a seeded run and an initial environment.
3. `EnvironmentInstance` turns archetype data into visible objects: games, items,
   events, services, lenders, and world-map travel exits.
4. The player interacts with objects through the shared UI shell.
5. Game modules, item effects, services, lenders, events, and travel return
   result dictionaries.
6. `GameModule.apply_result()` and `RunActionService` apply those results to
   `RunState`.
7. `RunTerminalEvaluator` and `RunState` determine whether the run continues,
   fails, or ends in demo victory.
8. `SaveService` persists the active run through the autosave slot.

## Content Packs

Production content is JSON under `data/`.

| Pack | Count | Path | Notes |
| --- | ---: | --- | --- |
| Environments | 18 | `data/environments/archetypes.json` | Shops, homes, tier-1 casinos, tier-2 venues, jazz club, beach, pawn shop, and the Grand Casino's connected rooms plus Cage |
| Games | 8 | `data/games/games.json` | All current games are full-simulation modules |
| Items | 67 | `data/items/items.json` | Permanent, temporary, consumable, contraband, active, game, security, travel, slot, pinball, container, and build-synergy effects |
| Content groups | 10 | `data/content_groups/groups.json` | Modular run packs that enable/disable games and their related item pools |
| Events | 49 | `data/events/events.json` | Scoped room events with choices and consequences, including unavoidable pressure events, triggered follow-ups, and the boss-floor `the_house_calls` and `high_roller_cashout` |
| Services | 14 | `data/services/services.json` | `cashier_tip`, `house_drink`, `call_brother_in_law`, jazz-club round/tip/show services, and tier-2 lounge/riverboat services |
| Lenders | 5 | `data/debt/lenders.json` | `street_lender`, `motel_friend`, `the_crew`, `brother_in_law`, `sals_pawn_counter` |
| Travel route templates | 12 | `data/travel/routes.json` | Destination templates for shops, casinos, tier-2 venues, the jazz club, beach, the underground casino, and the Grand Casino; `WorldMap` turns them into seeded graph paths with costs, unlocks, scouting previews, travel locks, and route-risk events |
| Challenges | 8 | `data/challenges/challenges.json` | Act 1 authored challenge runs with profile completion flags |
| Dialogues | 25 | `data/dialogue/dialogues.json` | TalkDock dialogue content for current Act 1, the guided first night, and 0.5 routes |
| Collection schemas | 1 collection | `data/collections/collections.json` | Local meta collection bags/items, housing data, and pawn-shop sale values |
| Music tracks | 3 | `data/audio/music_manifest.json` | Authored music manifest used by the procedural music player |
| Tutorial lessons | 49 | `data/tutorial/lessons.json` | Dialogue-guided tutorial sequence definitions, highlights, and gating contracts |

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
| `jazz_club` | shop | 1 | Rare late-1960s music room with trio services, pull tabs, and rare musician rewards |
| `small_underground_casino` | casino | 1 | Larger room with Grand Casino route access |
| `kitty_cat_lounge` | casino | 2 | Velvet-rope lounge with a house wheel, champagne pressure, and paid heat management |
| `delta_queen` | casino | 2 | Riverboat mid-stakes rung with scheduled boarding and temporary travel lock |
| `beach` | recovery | 2 | Low Tide Beach route environment and recovery stop |
| `pawn_shop` | shop | 2 | Sal's run-side pawn counter and item-backed lender stop |
| `grand_casino` | boss | 3 | Grand Casino Main Floor: machines, bar dice, Cage, host desk, and room doors |
| `grand_casino_high_limit` | boss | 3 | Silver-card or paid-entry blackjack, baccarat, and roulette room |
| `grand_casino_back_room` | boss | 3 | Locked Rourke showdown and heads-up blackjack duel room |
| `grand_casino_cage` | boss | 3 | Walkable Cage room with Linda, card claims, chip/cash handling, and review flow |
| `motel_room` | home | 1 | First paid housing tier |
| `apartment` | home | 1 | Mid-tier home with collection facilities |
| `house` | home | 1 | Final current housing tier |

Environment archetypes define name parts, visual context, layout points,
security/economic/music profiles, object pools, route hooks, local narrative
flags, and demo objective data. The Grand Casino's three archetypes share the
`grand_casino_demo_bankroll` objective. The clean route climbs Linda's
Bronze/Silver/Gold ladder and claims Gold at the Main Floor Cage; the cheat
route reads Rourke's spatial watch and survives the saveable walk, pat-down,
three-beat interrogation, and five-hand blackjack duel. Grand Casino table
games use chips, while its machines and bar dice continue to use cash.

## World Map And Travel

The current travel system is a seeded `WorldMap`, not a flat room-to-room hook
list. Environment archetypes name likely neighbors and route hooks; route
templates in `data/travel/routes.json` define destination identity, cost, risk,
unlock rules, route-risk events, availability windows, and scouting text.
`WorldMap` lays out the graph, records discovered/visited nodes, stores each
node's generated environment, and exposes a modal map through
`scripts/ui/world_map_canvas.gd`.

Travel can reveal tier-2 rungs, scout likely games/items/services/lenders,
apply heat decay and suspicion deltas, trigger route-risk consequences, and lock
the player temporarily in venues such as `delta_queen`. The Grand Casino route
requires the `grand_casino_invite` story flag and costs `$70` before any graph
path modifiers.

## Games

Game definitions live in `data/games/games.json`. Each game module extends the
shared `GameModule` contract and owns its own surface state, action routing, and
rendering details.

| Game | Family | Module | Cheat actions | Current behavior |
| --- | --- | --- | --- | --- |
| Scratch Tickets | lottery | `scripts/games/scratch_tickets.gd` | none | Seven generated-art ticket faces with separate background/icon/foil renderers, high-resolution interpolated scratching, intentional drag-to-bin discard, visible win/dud piles, fixed-at-purchase outcomes, compact settled receipts, and collection-print payoff |
| Pull Tabs | novelty | `scripts/games/pull_tabs.gd` | `tab_detector_scan` | Finite pull-tab deals, ticket windows, row/deal state, detector and tarot item interactions |
| Slot | slots | `scripts/games/slot.gd` | `nudge` | Generated Pinball/Buffalo machines, fixed bet ladder, reel-shift nudge, autoplay, feature bonuses, and bonus-stuck watchdog coverage |
| Bar Dice | dice | `scripts/games/bar_dice.gd` | `loaded_toss`, `palmed_swap` | Ship, Captain, Crew as a bar-top table game with patrons, cargo scoring, carryover pots, and skill-timed dice cheats |
| Blackjack | cards | `scripts/games/blackjack.gd` | `peek_hole_card`, `count_cards` | Shoe blackjack with hit/stand/split/double, side bets, count challenge, and hole-card peek heat |
| Baccarat | cards | `scripts/games/baccarat.gd` | `read_baccarat_shoe`, `edge_sort` | Mini-baccarat with Player/Banker/Tie/pair bets, commission, shoe state, read-shoe, and edge-sort play |
| Roulette | wheel | `scripts/games/roulette.gd` | `read_wheel_bias`, `past_post` | Full roulette layout with inside/outside bets, chip placement, wheel spin, payout animation, wheel-read, and past-post timing |
| Video Poker | cards | `scripts/games/video_poker.gd` | `mark_holds` | Multi-game video poker with bet, hold, draw, double-up, and mark-hold cheat action |

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
Buffalo supports free games, Hold and Spin, wheel/monster feature paths, Gold
Buffalo collection/conversion, must-hit meter data, and jackpot tiers.

## Runtime Architecture

| Path | Responsibility |
| --- | --- |
| `scripts/core/run_state.gd` | Authoritative run state, RNG state, bankroll, heat, alcohol/luck, debt, inventory, environment, story, terminal status, save payloads |
| `scripts/core/rng_stream.gd` | Deterministic seeded RNG streams and forks |
| `scripts/core/content_library.gd` | Loads and validates JSON content packs |
| `scripts/core/character_roster.gd` | Resolves reusable character pools, stable encounter casts, models, and voice lines |
| `scripts/core/environment_instance.gd` | Builds generated environment instances from archetypes |
| `scripts/core/run_generator.gd` | Chooses starting and next environments |
| `scripts/core/world_map.gd` | Builds and normalizes the seeded travel graph, node discovery, stored environments, and route paths |
| `scripts/core/game_module.gd` | Base game contract and shared result application |
| `scripts/core/item_effect.gd` | Item purchase/use/sale effect resolution |
| `scripts/core/event_module.gd` | Event condition and choice resolution |
| `scripts/core/run_action_service.gd` | Services, lenders, travel, and item actions |
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
| `scripts/ui/talk_dock.gd` | Dialogue popup layout, speaker presentation, choices, and action-driven progression |
| `scripts/ui/coach_overlay.gd` | Visual-only tutorial highlights that track rendered targets without blocking pointer input |
| `scripts/ui/world_map_overlay_controller.gd` | Modal map ownership, tutorial-safe layering, and travel interaction lifecycle |
| `scripts/ui/sfx_player.gd` | Procedural and shared sound effect playback |
| `scripts/ui/procedural_music_player.gd` | Procedural room music |
| `scripts/ui/web_audio_bridge.gd` | Browser delivery for pre-encoded Web SFX/music banks and native-equivalent bus gain behavior |
| `scripts/ui/settings_menu.gd` | Settings UI |
| `scripts/ui/drunk_distortion_overlay.gd` | Drunk/alcohol visual effect |
| `scripts/ui/icon_sprite_renderer.gd` | Icon rendering helper |
| `scripts/ui/visual_style.gd` | Shared colors and presentation constants |

The UI is designed around mouse/touch parity. Full-simulation games own their
surface-specific state and drawing, while the foundation shell owns flow, routing,
shared state, autosave, and terminal presentation.

The guided first night starts both New Run and Replay Lessons in the Apartment
with Pal, forced X-ray Glasses, and action-driven TalkDock guidance. Its authored
route covers the Corner Store and family loan, an optional Gas Casino pull-tab
lesson, Underground Blackjack/Peek/counting/Heat, the High Roller Invitation,
and the Grand Casino Host/Rourke/Linda/Bronze sequence. Highlights are visual
only: camera movement updates their screen transform while the underlying real
hit target remains usable. Both authored routes and the modal lifecycle matrix
have agent-driven real-pointer evidence in
`docs/plans/tutorial_completion_report.md`; the five-person cold-player gate
TUT-N17 remains explicitly human-only.

Native and Web audio now share the 22.05 kHz SFX synthesis contract. The Web
export ships 80 pre-encoded SFX cues and authored music derivatives, decodes
them off the main thread, preserves the stem mix, and follows the native
Master/Music/SFX bus gains. The native authored masters remain unchanged.

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
  `pit_boss_showdown` (`the_house_calls`) back-room route. The duel records
  `walk_out_clean`, `shown_the_door`, or `taken_out_back`; the middle outcome
  is a successful exit that converts the uncashed rack into a Sal-pawnable
  meta item. See
  `docs/plans/grand_casino_endgame_design.md` for the authoritative endgame
  contract.
- Gold clean victories mint unique, critical-condition Players Cards. Carrying
  one starts a prestige run with recognition heat relief, a tighter clean heat
  ceiling, improved collection drops, and permanent card loss if the run fails.

## Repository Layout

```text
assets/                  PNG art used by environment, event, item, game, and UI presentation
data/                    JSON content packs, reusable character identities/pools, and art manifest
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

### Local artifact retention

Development artifacts are kept locally through active development. At release,
use `tools/manage_local_artifacts.ps1` to report the ignored inventory and copy
it to backup storage with `-Export <destination>`. Cleanup is allowed only
after that export's manifest and SHA256 hashes verify, and requires both
`-Clean -Destination <destination>` and `-IAmSure`. The `.tools/` toolchain is
always protected from cleanup. The default invocation is read-only and removes
or moves nothing.

## Running The Project

`tools/run_godot.ps1` launches the app, and `tools/run_godot.ps1 -Editor`
opens the editor. These are interactive developer commands rather than
headless release gates. `tools/install_godot.ps1` installs a local Godot binary
into `.tools/` when Godot is not already available.

The wrappers resolve Godot in this order:

1. `GODOT_BIN`
2. `.tools\`
3. `godot` on `PATH`

## Validation

The current release readiness ledger is
`docs/plans/0.5_release_checklist.md`. Earlier 0.2-0.4 ledgers are retained
as historical evidence only. The current final battery and package evidence
must be recorded before publishing. The primary headless commands are:

```powershell
powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -FoundationSuite all -TimeoutSec 300
```

Current 0.5 supplemental probes:

```powershell
powershell -ExecutionPolicy Bypass -File tools\foundation_performance_probe.ps1 -RequireGodot
powershell -ExecutionPolicy Bypass -File tools\foundation_soak_probe.ps1 -RequireGodot -SimMinutes 180 -ActionsPerSample 28
powershell -ExecutionPolicy Bypass -File tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10
powershell -ExecutionPolicy Bypass -File tools\foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 200
powershell -ExecutionPolicy Bypass -File tools\foundation_mouse_batch_playtest.ps1 -RunCount 60 -RequireGodot
powershell -ExecutionPolicy Bypass -File tools\web_perf_smoke.ps1
powershell -ExecutionPolicy Bypass -File tools\web_perf_smoke.ps1 -Plan grand_casino -SkipExport
powershell -ExecutionPolicy Bypass -File tools\collection_meta_check.ps1
powershell -ExecutionPolicy Bypass -File tools\ui05_surface_coverage_check.ps1
powershell -ExecutionPolicy Bypass -File tools\ui05_token_adoption_check.ps1
powershell -ExecutionPolicy Bypass -File tools\ui05_popup_fit_check.ps1
powershell -ExecutionPolicy Bypass -File tools\ui05_asset_pipeline_check.ps1
```

Current pre-human evidence and remaining final results:

- The integrated tutorial source has passed validation, every FoundationSuite,
  both scripted and real-pointer tutorial routes, the 100-seed traversal and
  stuck-state sweeps, 10-seed determinism, strict rendered mouse input, and
  visual QA. The native performance/liveness battery, 180-minute/504-action
  soak, Scratch Ticket RTP audit, and Grand Casino Web runtime budgets are also
  green; see the current tutorial and performance reports below.
- The final integrated Web source passes the unchanged 4x-throttled cold-ready
  and broad L0.2 budgets with high-fidelity audio active: interactive ready is
  17.557 seconds against 20 seconds and slot autoplay is 88.312 ms against
  100 ms. TUT-N17 and the owner's packaged Web/Windows playtest cannot be
  replaced by automation.
- Only fresh reports linked by `docs/plans/0.5_release_checklist.md` are final
  0.5 release evidence; older candidate reports remain historical baselines.

Other targeted wrappers live in `tools/`: slot cabinet visual QA, environment
generation audit, performance probe, mouse playtests, and game seed audits.
Additional GDScript audit/probe files include slot metrics, slot deep audit,
roulette rule/audio checks, pull-tab seed audit, and GDScript load checks.
Reports are written under `.tmp/` or Godot `user://` paths and should not be
committed as source documentation.

Do not overlap headless Godot gates against the same workspace. `check_godot.ps1`
now stops early if another Godot process is already running for this project;
use `-AllowConcurrentGodot` only for an intentional isolated run. Long suites
also need an outer command timeout longer than the harness timeout: the slot
acceptance gate reserves up to 900 seconds and has passed at about 889 seconds,
while the full suite reserves up to 1800 seconds. Killing the parent PowerShell
early can leave Godot children writing `user://` logs, which has reproduced
Windows native access-violation dialogs on later runs.

For shipped 0.2.0 release evidence, use the tracked checklist at
`docs/plans/0.2_release_checklist.md`. For shipped 0.3.0 evidence, use
`docs/plans/0.3_release_checklist.md`. For shipped 0.3.1 evidence, use
`docs/plans/0.3.1_release_checklist.md`. For the completed 0.3.2 internal
readiness ledger, use `docs/plans/0.3.2_release_checklist.md`. For the
unpublished 0.4 candidate, use `docs/plans/0.4_release_checklist.md` as
historical context only. For Act 1 historical work, use
`docs/plans/act_one_feature_complete_task_board.md`.

## Documentation

The README is the current top-level implementation spec. The `docs/plans/`
folder holds active planning documents, shipped-release ledgers, and historical
context:

- `CHANGELOG.md` - public release changelog for shipped releases and candidate
  notes.
- `docs/plans/0.5_release_checklist.md` - current 0.5 source-prep and release
  readiness ledger.
- `docs/plans/0.5_publish_copy.md` - paste-ready itch.io and GitHub release
  copy for 0.5.0 after owner approval.
- `docs/plans/0.5_devlog_post.md` - draft 0.5 devlog copy for the owner.
- `docs/plans/0.5_prerelease_playtest_report.md` - 0.5 prerelease playtest
  findings and closure evidence.
- `docs/plans/tutorial_completion_report.md` - current pre-human tutorial
  requirement table, real-interface route matrix, and explicit TUT-N17 handoff.
- `docs/plans/0.5_performance_audit.md` - current native/Web performance,
  liveness, memory-soak, Scratch Ticket compaction, and Web audio evidence.
- `docs/plans/act_one_feature_complete_task_board.md` - the historical Act 1
  implementation board, retained for decisions and landing evidence.
- `docs/plans/pinball_feature_rework_plan.md`,
  `docs/plans/pinball_feel_reference.md` - the shipped pinball feature
  contract and feel targets. Use these with the live slot stack when touching
  pinball or shared slot release work.
- `docs/plans/grand_casino_endgame_design.md` - the authoritative Grand Casino
  endgame design lock (three rooms, chips/Cage, Linda's card ladder, living
  Rourke, four-phase showdown, duel outcome ladder, meta rewards, and canonical
  ids).
- `docs/plans/content_style_guide.md` - the active release voice and
  player-facing copy rules for Act 1 content.
- `docs/plans/dead_code_audit_report.md` - the release cleanup audit and
  protect list for code and tooling that looks dead but is live.
- `docs/plans/skill_based_cheating_methods_plan.md` - the shared
  skill-cheat design contract and cross-game method matrix.
- `docs/plans/world_map_design.md` - the world-map route/progression design
  lock.
- `docs/plans/music_system_rework_plan.md` and
  `docs/plans/music_listening_pass.md` - parked post-0.3 music planning and
  listening-check context.
- `docs/plans/0.2_release_checklist.md` - the shipped 0.2.0 release readiness
  checklist, including validation evidence and known blockers.
- `docs/plans/0.3_release_checklist.md` - the shipped 0.3.0 readiness ledger.
- `docs/plans/0.3.1_release_checklist.md` - the shipped 0.3.1 hardening
  release ledger, including performance/stability evidence and package hashes.
- `docs/plans/0.3.2_release_checklist.md` - the completed 0.3.2 low-end/web
  cleanup release ledger, including gate evidence and package hashes.
- `docs/plans/0.3.3_publish_copy.md` - paste-ready itch.io, GitHub release,
  and devlog copy for the 0.3.3 public patch.
- `docs/plans/0.4_act1_completion_plan.md` - the implemented 0.4 scope and
  historical candidate evidence.
- `docs/plans/0.4_release_checklist.md` - the 0.4 package/readiness ledger,
  retained as historical context.
- `docs/plans/0.4_publish_copy.md` - historical paste-ready itch.io, GitHub,
  and devlog copy prepared for the unpublished 0.4.0 candidate.

For current slot implementation work, use the slot stack listed in this README
and the pinball docs above rather than older file names referenced inside
historical release evidence.

## Export Targets

| Preset | Platform | Output |
| --- | --- | --- |
| Web | Web | `builds/web/index.html` |
| Windows Steam | Windows Desktop | `builds/windows/BeatTheHouse.exe` |
| Android | Android | `builds/android/BeatTheHouse.aab` |
| iOS | iOS | `builds/ios/BeatTheHouse.zip` |

`tools/export_itch.ps1` packages the Web and Windows presets for itch.io upload
after Godot export templates are installed. Project and export preset versions
are currently stamped `0.5.0`. The tool supports `-Push -DryRun` for butler
command verification and non-dry-run publishing after the user has installed
butler and run `butler login` once. Fresh final 0.5 Web/Windows package hashes
do not exist until the owner runs the final export packaging. Android
signing and iOS team/signature values still require real project credentials
before store submission.

## Known Release Limitations

- The Web export is intentionally single-threaded. Procedural music is generated
  deterministically at build time into compact Web beds, so browser startup and
  playback no longer depend on PThreads or main-thread synthesis. Cross-origin
  isolation headers remain supported but are not required by the shipped build.
- Tutorial requirement TUT-N17 is pending five cold players, including two
  without Blackjack knowledge; agent-driven routes do not satisfy that human
  comprehension gate.
- The collection schema still uses `draft: true` pending the owner's explicit
  ship decision.
- itch.io publishing remains a user action: install/login with butler and push
  the Web and Windows packages from `tools/export_itch.ps1`, or upload through
  the itch.io dashboard.
- itch.io package publishing remains separate from the GitHub source release.
- Android and iOS store submission require real signing/team credentials.

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
