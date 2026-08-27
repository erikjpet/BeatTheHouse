# program06_0 Depth Rows — Cross-file Ownership Audit

Status: Review Pool static audit and proposed matrix; the program director is
the only authority that binds or changes assignments

Audited immutable checklist heads:

- `craps06_3`: `24dcebabebb93b954f62219ed3bfa120aa7fc0da`
- `env06_7`: `849aa8c2487398622dc5785dc43a6458bc02c438`
- `crew06_10`: `dc6894a100b188b17e6a1ed51321113463eaa40e`

The three heads are documentation-only and share base
`917ac03028650e6d76921aed893f4a575a0f17a8`. This audit does not accept product,
assign a squad, or authorize an edit. It identifies collisions that must be
resolved before product work.

## 1. Static findings

### O1 — Street Craps has two legitimate owners unless its seam is frozen

`craps06_3` owns the mechanical shooter ritual, wager/settlement lifecycle,
typed craps facts, street warning response, and exactly-once recovery of
unresolved stakes. env06_7 Package A owns the environment scenario
`back_alley_street_craps`: chalk, lookout, room actors, routes, relocation,
dispersal, reentry, and aftermath. Both prompts require arrival, warning,
relocation/dispersal, and persistence.

Required split: the craps squad owns game authority and publishes public facts;
Package A owns the room sequence and responds through env06_6 at a safe
boundary. Neither may duplicate the other's state machine or write the other's
files. The env assembly owner alone integrates the monolithic scenario catalog
and owns the combined sequence dossier. A director-named composition-test owner
must own the one cross-seam fixture.

### O2 — Poker debt-court and raid-jitters overlap env Package D

`crew06_10` requires five poker-night sequences, including a debt-court table
and raid-jitters/knock-at-door table. env06_7 Package D owns the environment ids
`punchline_debt_court` and `punchline_raid_jitters`, including their actors,
multi-layer routes, room duties, hide/clear/reopen operations, branches,
aftermath, cleanup, and revisit.

Required split: the poker squad owns the poker session/hand boundary, betting,
pause/resume/abort protocol, and public poker facts. Package D owns the L3 room
graph, duties, actors, routes, and scenario aftermath. Debt court cannot add
poker debt; raid staging cannot inspect cards/deck. The env assembly owner owns
the combined dossier and one director-assigned integration fixture. Two parallel
implementations of the room sequence are forbidden.

### O3 — Grand Casino audit/high-energy tables overlap by layer

`craps06_3` requires ordinary, hot/high-stakes, and security/audit craps table
profiles. env06_7 Package E owns `grand_casino_audit_night`, while other Grand
Casino variants own gala/convention room routing.

Required split: craps owns game-local ritual phases, table staff, wagers,
results, energy, and public facts. Package E owns casino-wide auditors, routes,
room services/game availability, and persistent room aftermath. Scenario code
cannot settle craps or read future dice/cheat outcomes; craps code cannot move
room auditors or mutate scenario state directly.

### O4 — Monolithic catalogs and Foundation aggregators cannot belong to squads

At least these current files are natural collision points:

- `data/games/games.json`
- `data/environments/scenarios.json`
- `scripts/tests/foundation/check_table_games.gd`
- `scripts/tests/foundation/scenario_backlog_contract.gd`
- `tools/foundation_determinism_probe.gd`
- `tools/foundation_visual_qa.gd`

Each must have one named integrator. Squads author uniquely named definitions,
fixtures, tools, or exact patch requests; they do not concurrently edit a
monolith. Gate Service runs harnesses but does not repair them. Defect Triage or
a director-designated test integrator owns shared harness changes.

### O5 — Shared game surface and environment render paths need retained owners

The row prompts require shared visual/runtime behavior, but the following files
cannot become row-squad property merely because a row needs them:

- `scripts/core/game_module.gd`
- `scripts/games/table_game_visuals.gd`
- `scripts/ui/game_surface_canvas.gd`
- `scripts/ui/foundation_main.gd`
- shared input/accessibility/audio/liveness code
- `scripts/core/scenario_engine.gd`
- `scripts/core/environment_instance.gd`
- `scripts/ui/pixel_scene_canvas.gd`

Shared game ritual/runtime files remain with the game06_1 implementation owner.
Scenario runtime/schema/renderer files remain with the env06_6 owner. A row
submits a bounded adapter request; a director-recorded transfer is required
before any other writer touches one.

### O6 — Crew/world model exclusivity constrains crew06_10

The parallel former-PM lane exclusively owns crew/world models and the
EventModule crew seam. `crew06_10` must not directly edit
`crew_state_model.gd`, `crew_recruitment_model.gd`, `crew_play_model.gd`,
`crew_heist_model.gd`, `crew_turn_model.gd`, `police_sweep_model.gd`, or other
assigned crew model adapters. `crew_poker_model.gd` must be explicitly assigned:
the safe default is retained other-lane custody, with the poker squad authoring
`data/crew/poker.json` and a bounded model-adapter request.

## 2. Proposed row/package ownership

| Owner | Exclusive product/content scope | Must not edit |
| --- | --- | --- |
| Craps squad | `scripts/games/craps.gd`; `scripts/games/craps/**`; uniquely named craps ritual definitions, focused tests/tools/captures; explicitly assigned craps slice request for game catalog | Scenario catalog/runtime, shared game runtime/canvas/controller, crew/world models, shared Foundation probes, board/main |
| Crew Poker squad | `scripts/games/crew_draw_poker.gd`; `data/crew/poker.json`; uniquely named poker ritual definitions, focused tests/tools/captures | Crew/world models, EventModule crew seam, env runtime/catalog, shared game runtime/canvas/controller, shared Foundation probes, board/main |
| env Package A | Unique definitions/dossiers/fixtures/assets for Corner Store, Back Alley, Pawn Shop; room side of Street Craps | Craps game/rules, scenario monolith/index, env runtime, sweep/crew models |
| env Package B | Unique definitions/dossiers/fixtures/assets for Motel, Gas Station, Beach | Scenario monolith/index, env runtime, travel/sweep models |
| env Package C | Unique definitions/dossiers/fixtures/assets for Bar and Jazz Club | Game modules, audio runtime, scenario monolith/index, env runtime, crew/world models |
| env Package D | Unique definitions/dossiers/fixtures/assets for Underground and Lounge; room side of poker Debt Court/Raid Jitters | Poker game/model/data, scenario monolith/index, env runtime, crew/world models |
| env Package E | Unique definitions/dossiers/fixtures/assets for Delta Queen and Grand Casino; room side of casino audit | Craps/other game modules, scenario monolith/index, env runtime, travel/crew models |
| env06_7 Assembly owner | `data/environments/scenarios.json`, scenario indexes/loaders if assigned, 55-id machine dossier, global uniqueness/reachability report, archetype contact sheets, cross-package composition fixtures | Package implementation rewrites, env06_6 runtime/schema changes, game/crew/world authority |
| game06_1 runtime owner | Shared ritual validator/runtime, `game_module.gd`, table visuals/canvas/controller adapter work, shared game layout/actor/object seams, shared game test registration | Game-specific rules/content, scenario runtime, crew/world models |
| env06_6 owner | Scenario runtime/schema/renderer adapters, env-specific shared test registration, sealed room/layer authority | Authored 55 scenario conversions, game rules, crew/world models outside its lane |
| Parallel former-PM lane | Crew/world models, EventModule crew seam, Turn/sweep/itinerary/job adapters | Game rules/surfaces, env06_7 content packages, program board/main |
| Audio squad (`audio06_1`) | Shared audio manifest/runtime and cross-row cue integration | Game/scenario authority and tuning |
| Director-designated game catalog integrator | `data/games/games.json` and its shared validation/index work | Game implementation beyond mechanical integration of accepted slices |
| Director-designated Foundation integrator / Defect Triage | Shared Foundation aggregators and probe harnesses | Row product fixes unless routed inline under that row |
| Gate Service | Native-plugin identity, warm runners, immutable gate evidence | Product, harness, golden, budget, or test repair |
| Program director / Landing Coordinator | `main`, board, assignment order, landing records; exact accepted payload extraction | Product implementation or acceptance review |

## 3. Path-level matrix for known collision points

| Path or family | Proposed sole writer | Inputs accepted from other squads |
| --- | --- | --- |
| `scripts/games/craps.gd`, `scripts/games/craps/**` | Craps squad | Accepted game06_1 adapter API; public env facts only |
| `scripts/games/crew_draw_poker.gd` | Crew Poker squad | Accepted game06_1 adapter API; public crew/env facts only |
| `data/crew/poker.json` | Crew Poker squad | Policy/voice constraints and model validation contract from other lane |
| `scripts/core/crew_poker_model.gd` | Parallel former-PM lane unless director transfers it | Bounded schema/API request from Crew Poker squad |
| Listed crew/world models + EventModule crew seam | Parallel former-PM lane | Typed adapter requests only |
| `data/environments/scenarios.json` | env06_7 Assembly owner | Accepted package definitions/patch manifests |
| Scenario indexes/loaders | env06_7 Assembly owner, unless env06_6 owner retains a named file | Package manifests; no direct package edits |
| `scripts/core/scenario_engine.gd`, `environment_instance.gd` | env06_6 owner | Bounded defects/adapters routed through director |
| `scripts/ui/pixel_scene_canvas.gd` scenario projection paths | env06_6 owner or one director-named renderer integrator | Semantic operation/asset requirements from packages |
| `data/games/games.json` | Director-designated game catalog integrator | Accepted row-specific data fragments/patch requests |
| `game_module.gd`, `table_game_visuals.gd`, `game_surface_canvas.gd`, game controller seams | game06_1 runtime owner | Accepted consumer conformance requirements and adapter requests |
| Shared audio manifests/runtime | `audio06_1` owner | Named cue requests with semantic events from rows/packages |
| `check_table_games.gd` and shared game-suite registration | game06_1 owner or director-designated Foundation integrator | Uniquely named row fixtures plus registration request |
| Scenario shared suite/uniqueness runner | env06_7 Assembly owner or director-designated Foundation integrator | Package-local fixtures/dossiers |
| Determinism/visual/performance master probes | Foundation integrator / Defect Triage | Focused row tools and trace/capture adapters |
| Row-focused tools/tests/captures with unique filenames | Owning row/package squad | None; references only accepted public seams |
| `.tmp/`, `.tools/`, `review_artifacts/` | Owner property; no staging owner | Evidence may be referenced by hash/path, never staged/moved/removed |
| `docs/todo/README_0_6_board.md`, `main` | Program director / Landing Coordinator | Handoff status only; squads do not edit |

## 4. Cross-seam state authority

| Combined feature | Game/row authority | Environment/other-lane authority | One integration owner needed |
| --- | --- | --- | --- |
| Street Craps | wagers, dice, throw phases, settlement, training, public facts | Package A: chalk, lookout, crowd, routes, relocation/dispersal, aftermath | env assembly for combined dossier; director names fixture owner |
| Casino audit craps | dice/wagers/table ritual/energy/public cheat result after reveal | Package E: auditors, room route, service/game availability, casino aftermath | env assembly for scenario dossier; director names fixture owner |
| Poker Debt Court | hands, betting, between-hand pause/resume, public session facts | Package D: hearing, duties, actors, routes, ruling aftermath; other lane supplies public crew adapter | env assembly for dossier; director names fixture owner |
| Poker Raid Jitters | live-hand safe boundary, hidden-card protection, resume/abort settlement policy | Package D: knock, hide/clear/reopen, actors/doors/routes/aftermath; sweep state from other-lane public adapter | env assembly for dossier; director names fixture owner |
| Poker roster/itinerary | seat selection from authenticated public availability; no direct model mutation | Other lane owns residence, itinerary, active jobs, Turn and sweep authority | Director names cross-lane adapter owner/test fixture |
| Game energy -> room reaction | Game computes and publishes public tier fact | env scenario applies actor/object/interactable operations at next safe boundary | env assembly owns composition evidence |

## 5. Decisions required before product edits

The Review Pool recommends the director record these smallest decisions in the
assignment order:

1. Name the sole `data/games/games.json` integrator. Until named, craps and Crew
   Poker squads prepare row-local data fragments or exact patch requests only.
2. Confirm `crew_poker_model.gd` remains with the parallel former-PM lane, or
   record one explicit temporary transfer with start/end commit. No concurrent
   ownership is valid.
3. Name the sole writer for `check_table_games.gd` and the master determinism,
   visual, and performance probes.
4. Name one owner for each cross-seam composition fixture: Street Craps, casino
   audit craps, Poker Debt Court, Poker Raid Jitters, and roster/job conflict.
5. Confirm whether `pixel_scene_canvas.gd` stays with env06_6 or transfers to a
   singular renderer integrator for env06_7; packages and Crew Poker never own
   it directly.
6. Confirm shared audio cue requests route exclusively through `audio06_1`.

These are assignment decisions, not design blockers. Audit/test authoring and
row-local work can continue while an integrator is named, but no unowned shared
file may be edited.

## 6. Handoff enforcement

- Every squad handoff includes exact base/head, complete changed-path list, and
  the director's ownership record current at the first product commit.
- Review compares every changed path against this matrix and rejects an
  unrecorded shared-file edit before semantic review.
- Cross-seam behavior is proved from authenticated public facts and operations;
  no consumer reads another owner's private state or duplicates authority.
- Entangled or behind branches are delivered by exact net payload, never merged
  wholesale. Owner files, generated output, remote state, release activity, and
  deletion remain outside every row.
- The matrix changes only by a new director-recorded assignment. A commit does
  not establish ownership merely because it touched a file first.
