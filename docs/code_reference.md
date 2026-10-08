# 0.6 Code Reference

Updated 2026-10-08 from the feature-complete 0.6 source. This document explains
the runtime ownership boundaries and the comment standard used by production
code. It is a navigation aid, not a replacement for the exact contracts in code
and data.

## Source inventory

Production GDScript under `scripts/` contains 212 modules:

| Area | Files | Responsibility |
| --- | ---: | --- |
| `scripts/core/` | 88 | Deterministic state, content, generation, scenarios, actions, persistence, placement, economy, Crew, and endgame rules |
| `scripts/ui/` | 77 | Application flow, view models, canvases, input, accessibility, dialogue/tutorial UI, audio, and presentation |
| `scripts/games/` | 47 | Eleven playable modules plus shared renderers and game-specific simulation/support code |

Tests under `scripts/tests/` and active tools under `tools/` are executable
evidence rather than product runtime. Dated tools under `tools/archive/` retain
their historical source-boundary meaning and are not rewritten to resemble the
current architecture.

The complete game-script and game-data inventory is maintained separately in
`docs/game_reference.md`.

## Comment contract

Every production GDScript module begins with a purpose/ownership header near its
class declaration. A reader should be able to determine:

- what state or presentation the file owns;
- which neighboring layer owns mutation it deliberately does not perform;
- whether returned collections are owned copies, borrowed read-only views, or
  transient action values;
- whether time, RNG, save, transaction, or animation behavior has a special
  contract.

Function-header comments are required where the signature and name cannot state
the whole contract. This includes public extension points, authority or
persistence boundaries, rollback/checkpoint methods, borrowed-reference reads,
scheduled/realtime hooks, performance fast paths, and compatibility migrations.
Comments explain current behavior and invariants in present tense. Historical
reasoning belongs in a clearly marked migration/compatibility note or a dated
document.

Small private helpers do not receive comments that merely restate their names.
Their call site, type/signature, and implementation are the useful context;
duplicating those facts creates stale prose without explaining an invariant.

## Runtime ownership

### Content and generation

`ContentLibrary` loads, validates, and indexes the immutable JSON catalog.
`RunGenerator` combines that catalog with deterministic RNG, `WorldMap`,
`TownState`, challenges, scenario packages, and placement authority to install
an `EnvironmentInstance`. Installation is atomic: rejected generation/travel
retains the prior run and exposes explicit failure evidence.

`EnvironmentInstance` is the durable location value. It carries generated
content, layered scenario state, semantic inventory, the physical object
manifest, game fixture state, and sealed slot bindings.

### Active run and actions

`RunState` is the sole active-run source of truth. It owns deterministic time
and RNG, bankroll/chips, Heat, alcohol/luck, debt, inventory, visited rooms,
travel, story/scenario/Crew progress, and terminal state. It delegates focused
domains to bound facades/models but remains the persistence and publication
root.

`RunActionService` resolves non-game actions. `EventModule` resolves data-backed
events and conversations. Concrete `GameModule` subclasses resolve game-owned
actions. All produce the shared result/delta shape; the host applies it once at
the authenticated action boundary.

### Scenario and placement authority

`ScenarioSequenceRuntime` owns data-driven sequence phases, facts, commands,
and terminal cleanup. `ScenarioHostTransaction` is the authenticated publication
boundary for scenario-hosted games. Extension dispatchers/adapters can prepare
allowlisted data but cannot mint authority.

`EnvironmentPlacement` reads four authored slot families: fixed, event,
scenario, and exit. `ScenarioLayoutResolver` selects exact scenario-local
geometry. `EnvironmentSlotBinder` binds live physical records to that geometry,
and `EnvironmentObjectManifest` seals the resulting membership/provenance.
`DeveloperPlacementStore` owns local manual edits, completion state, schema-3
export/import, and coordinate promotion.

### Game execution

`GameModule` defines the host contract for entry/exit, legal and advantage
actions, wager cost, surface projection/input, automatic/realtime scheduling,
background runtime, save checkpoints, settlement, rollback, audio, and shared
result normalization. Concrete modules own their rules and durable fixture
state; `FoundationMain` owns orchestration and applies their normalized results.

Automatic game actions and visual animation are separate. A module can reduce
the work performed by a scheduled tick, but environment/game animation remains
autonomous without mouse movement, hover, selection, or placement-overlay
input.

### UI and presentation

`FoundationMain` is the top-level application orchestrator, not a rules engine.
It owns screens/modals, session wiring, action routing, entry/exit, save/recovery,
travel, tutorials, terminal screens, and stable test snapshots.

View-model files project immutable player-safe dictionaries. They do not commit
domain actions. `PixelSceneCanvas` draws and interacts with rooms;
`GameSurfaceCanvas` hosts the active game module; `TalkDock` owns conversation
presentation; focused controls own their local selection/layout state.

`PixelSceneCanvas` consumes sealed room geometry but owns camera/focus animation,
hit regions, object feedback, and the developer placement overlay.
`GameSurfaceCanvas` owns board scaling, hit regions, pointer capture, animation
channels, retained child layers, and shared audio/UI signals. Neither canvas may
tie animation scheduling to pointer activity.

### Audio

`SfxPlayer` resolves semantic event classes through
`SurfaceSfxManifest`, then uses native samples/procedural fallbacks or the Web
audio bridge. Game modules name semantic cues rather than concrete files.

`ProceduralMusicPlayer` owns authored/procedural delivery, synchronized stems,
bar/phrase choreography, feature layers, outcome cues, caching, WebAudio, and
Music-bus playback. Selection and choreography helpers remain pure so tests and
runtime share the same decisions.

### Persistence

`SaveService` owns slot I/O and recovery envelopes. `RunSaveCodec` compacts
authored/runtime repetition without changing the accepted JSON save schema.
`RunState.to_dict()`/restore paths remain the canonical active-run payload;
profile collection state is persisted separately by `MetaCollectionService`.

## Common traces

| Change | Start here | Follow into |
| --- | --- | --- |
| Run economy or terminal behavior | `scripts/core/run_state.gd` | `run_action_service.gd`, `run_terminal_evaluator.gd`, relevant domain facade |
| Room generation/content | `scripts/core/run_generator.gd` | `environment_instance.gd`, `content_library.gd`, scenario/placement modules |
| Room objects or slot placement | `scripts/core/environment_placement.gd` | `scenario_layout_resolver.gd`, `environment_slot_binder.gd`, `pixel_scene_canvas.gd` |
| Game rule/action | Concrete file under `scripts/games/` | `game_module.gd`, game support files, Foundation result route |
| Game surface input/animation | Concrete game module | `scripts/ui/game_surface_canvas.gd`, then `foundation_main.gd` |
| General room interaction | `scripts/ui/environment_interaction_controller.gd` | its view model, core scenario/action owner, `pixel_scene_canvas.gd` |
| Save/load | `scripts/core/save_service.gd` | `run_save_codec.gd`, `run_state.gd`, collection persistence |
| SFX | `data/audio/surface_sfx_manifest.json` | `surface_sfx_manifest.gd`, `sfx_player.gd`, semantic cue producer |
| Music | `data/audio/music_manifest.json` | `procedural_music_player.gd`, arrangement/choreography models |

## Documentation validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\code_documentation_check.ps1
powershell -ExecutionPolicy Bypass -File tools\game_documentation_check.ps1
```

The code check requires purpose context in every production GDScript module,
rejects unresolved debt markers in production comments, catches broken local
file references inside production comments, and verifies that maintained entry
documents point to this reference. The game check keeps the 11-game catalog,
47 game scripts, and 9 game-data files synchronized with the game reference.
