# integ06_1 composition, migration, and soak report

Status: **PARTIAL — keep `integ06_1` TODO**
Audit base: `6875646b19cb8c8ce242414e1251a8ae7bcffc2c`
Harness prerequisite: `1131c6262eb04b2cbbabc6265caba71c4c234e22`
Product/content repair: `c9e5941f43c3f507921482bdac1e7a8c34a75a18`
Composition harness: `91af060af1b28bd5217f8c2ee9454fc0aa589567`
Exhaustive composition producer: `408c670a` plus eligibility proof `9c30110b`
Terminal native/Web soak producer: `2bda2450` plus authority hardening at the current branch head
Package-E layout correction checkpoint: `b7a75334` (**runtime unreviewed**)

This report records the completed historical-save and maximal-composition work
without claiming the native/Web terminal soak that has not yet run. The
provenance and capture history for every historical fixture remain in
`docs/plans/integ06_1_historical_fixture_wip.md` and the checked-in sidecars.

## 2026-09-04 closeout checkpoint

The recovery branch was rebased without conflict onto `origin/main` at
`9b52c27a`. It has no diff in the env06_8-owned scenario data, archetype layout
authority, environment interaction controller, pixel-scene icon fallback, or
`foundation_main.gd`.

Three genuine mid-0.6 saves are now retained under
`scripts/tests/fixtures/integ06_1/mid_0_6/`. Each was captured from its exact
historical commit by that commit's production FoundationMain and SaveService,
using only public player actions. Each save has a provenance sidecar and a
portable custody manifest:

- `mid06_pre_game_depth_slot` (`31e434c`): entered Gas Station Slot and retained
  a completed spin outcome;
- `mid06_pre_environment_depth_bar_dice` (`5a2b1e1a`): entered Bar Dice and
  retained one resolved round; and
- `mid06_pre_world_depth_crew_debt` (`f1ebe9a7`): followed the public parking-lot
  tip to Corner Store and retained an active Crew favor debt.

On candidate `70a239bd`, foundation architecture validation passed, the v0.5.1
matrix passed all 37 fixtures, and the new mid-0.6 matrix passed all three
fixtures. Both matrices reported `provenance=verified source=FoundationMain
round_trip=stable`.

The composition producer now derives a non-repeating real-edge route for each
generated map and opens hidden destinations only through the shipped public
Parking Lot Tip and Grand Casino Invitation choices. It no longer uses
arbitrary prevalidated jumps or creates false revisit failures. On the current
pre-env candidate it reaches one external blocker while entering Grand Casino:

- `game::game:video_poker` overlaps
  `scenario::grand_casino_convention_crowd_convention_coordinator` in normal and
  expanded-small layouts; and
- `base::travel:grand_casino_back_room` and
  `base::travel:grand_casino_cage` have ambiguous hit authority and overlapping
  labels in both layouts.

Those records are owned by env06_8 and were routed there; this integration branch
does not alter them. Composition remains unaccepted until the env repair lands
and the exact-candidate matrix is green.

The terminal producer successfully built fresh pinned Web native code and a
fresh Windows release export on diagnostic candidate `de49c753`. Its first runs
exceeded 900 and 1,800 seconds because an inferred `profile_persisted` local did
not parse in the exported scene; with no attached script, Godot remained in an
empty main loop. Those timeouts are invalid setup evidence, not performance or
terminal verdicts. The local is now explicitly typed, progress stages make this
failure mode visible, and a one-case/one-action schema smoke completed in 29.3
seconds wall / 16.6 seconds probe time, writing the expected report and journey
fields. The runner also writes native reports through its existing `--out`
surface instead of depending on unavailable GUI-subsystem stdout, accepts an
explicit shared pinned-toolchain root, and exposes fixture/checkpoint/action
ordinals plus exact save/load boundaries. These are production-core policy
checkpoints, not executable FoundationMain UI replay commands. No action cap,
save/load cadence, route requirement, or semantic assertion was weakened.

A later diagnostic based on candidate `5652fb7e` reached real gameplay in the
fresh Windows export. Its first native shard exposed integration-driver mistakes that
would otherwise hide the product result: the driver compared JSON integer
normalization as data loss, called the legacy destination generator without
checking arrival, treated a preferred destination stake floor as a travel gate,
and ignored rejected scenario action boundaries. Those results were discarded
as superseded harness evidence. The repaired producer now canonicalizes only
integer-valued game tallies, uses `RunGenerator.travel_environment_result`,
finalizes scenario semantics at the same action/travel boundaries required by
production, consults `RunTerminalEvaluator` at terminal boundaries, retains
exact changed-field diagnostics for save/load, and fails the row on any rejected
travel or action boundary. It also isolates ProfileInventory output per shard so
independent diagnostic processes cannot race each other.

The canonicalized save/load checks then passed exactly at every sampled point.
All nine policy seeds were exercised far enough to inventory the current
environment-owned blockers. No terminal verdict from those interrupted runs is
claimed:

- `jazz_club_guest_legend` and several other generated scenarios reject
  finalization with `scenario semantic inventory version or digest changed;
  explicit migration is required`;
- `bar_dead_tuesday` overlaps `event::event:town_rumor_staff` in normal and
  expanded-small layouts;
- `kitty_cat_lounge_amateur_night` has normal/expanded-small collisions among
  its dressing rack, task, judge, town-reputation or town-rumor events,
  `grand_casino_invite`, and `kitty_burlesque_show`; and
- `gas_station_trucker_convoy` overlaps `event::event:parking_lot_tip` in normal
  and expanded-small layouts.

These failures were routed to env06_8 with their exact identities. The
integration branch changes none of the scenario JSON, archetype anchor data,
layout resolver/controller, icon fallback, package generators, or
`foundation_main.gd`. The final repeated native/Web run remains correctly
deferred until that environment work lands.

The aggregate composition and terminal manifests are now directly consumable
by `tools/perf06_matrix_contract.ps1`: shard references are relative path
strings, every aggregate artifact has a SHA-256 and byte count, composition
coverage fields are numeric, and terminal evidence includes the required
Crew-ignoring control, victory/failure routes, and per-seed native/repeat/Web
trace triples. A synthetic consumer smoke passed exact nested-path and artifact-
hash validation before the producer change was committed. This proves the
schema handoff only; it is not a substitute for the final candidate run.

A separate real-Foundation entry reproduction found one non-environment blocker.
`FoundationMain.enter_game("blackjack")` returns true with `current_screen=GAME`
and the live Blackjack module, but leaves
`current_environment.active_game_id` empty. The resulting legal actions contain
only `play_basic`, and `RunState.crew_play_activate("spotter", "blackjack", ... )`
rejects the call as not bound to the live table. Setting only that missing field
in a control copy exposes both `play_basic` and `crew_play:spotter`. The opt-in
`tools/integ06_1_crew_play_entry_repro.gd` records those values and intentionally
exits 1 while the regression is present. The smallest post-env shared-host fix
is to bind `active_game_id` before `GameModule.enter`/legal-action presentation
and clear it on every game-exit path; this integration branch does not modify
`foundation_main.gd`.

Final acceptance still requires the shared-host Crew Play binding repair and one
clean rerun after env06_8 and the final perf06 evidence profile are both frozen:
project validation, the Crew Play entry reproduction, both migration matrices,
the full composition matrix, and the repeated native/Web terminal soak with
parity, route, profile, retained-state, and cleanup checks.

## Historical migration matrix

The current strict verifier passed all 37 genuine v0.5.1 saves. They were
captured by the tagged v0.5.1 FoundationMain and SaveService through public
player actions; no RunState dictionaries or progression flags were hand
authored. Admission rechecks source commit/blob identities, driver hash, exact
public-call transcript, fixture byte hash, and size before loading a fixture.

Coverage includes:

- all 18 v0.5.1 environment archetypes;
- all eight historical game families, including interrupted Scratch Tickets;
- active debt from all five historical lenders;
- the ordinary and `tutorial_first_card` tutorial routes through opening the
  tutorial Pull Tabs machine;
- Grand Casino invitation/no-invitation routes, all public casino rooms, and an
  active Rourke back-room duel.

Every admitted fixture loaded through current FoundationMain, retained its
declared gameplay contract, saved through current SaveService, reloaded, and
retained the same contract again. Exact command:

```powershell
Godot_v4.6-stable_win64_console.exe --headless --path . --script res://scripts/tests/foundation/integ06_1_v051_migration_smoke.gd
```

Verdict: `fixtures=37 provenance=verified source=FoundationMain round_trip=stable`.

The recovery audit found no owner-retained mid-0.6 save inventory, so the
approved historical capture path produced the three genuine public-action saves
listed in the closeout checkpoint above. The current verifier admits and
round-trips all three. Synthetic lookalike saves were not substituted.

## Maximal production composition

`tools/wave_b_composition_probe.gd` now drives one production run through:

- two real selected scenario nodes and a truth-backed heard rumor;
- Dave's live traveler itinerary and a Police Sweep movement/window boundary;
- Punchline L1, Side Door discovery, L2, earned Crew access to L3, SaveService
  save/load in L3, departure, intermediate-room finalization, and L3 revisit;
- a real Crew-favor event, physical pickup, ordinary world-map travel to its
  selected target, composition with the target's live scenario, service/event/
  game/traveler/town state, and an actual SaveService JSON round trip;
- repeated finalization with unchanged economy, heat, story log, and owner
  registration; and
- abandonment after load, followed by exact cleanup of the delivery, handoff
  owner, pending outcomes, and mounted registration.

The save assertion is strict at both boundaries. Before presentation rebuild it
compares the room's causal restore contract and the adapter's bounded durable
public authority. After rebuild it compares delivery, registration, town,
story, bankroll, heat, action identities, normalized layout authority, and
world-sequence state. It normalizes only JSON integral numbers, record order,
renderer-derived pixel/focus measurements, and transient transition counters.

Exact command:

```powershell
Godot_v4.6-stable_win64_console.exe --headless --path . --script res://tools/wave_b_composition_probe.gd -- --seed=WAVE-B-COMPOSITION-08 --out=res://.tmp/integ06_1/deep_composition_final/report.json
```

Verdict: PASS; `save_load_exact=true`, `replay_idempotent=true`,
`abandonment_clean=true`, final registration lifecycle `cleaned`.

This proves a maximal real Bar composition and all three Punchline layers. The
checked-in `tools/integ06_1_composition_matrix.ps1` now derives every eligible
archetype from production catalogs and schedules five lifecycle orderings plus
all three Punchline layers. It refuses a dirty or mismatched candidate and
writes immutable provenance-bound shard reports. That larger matrix is a
producer, not evidence, until it runs green on the final candidate.

## Findings repaired and routed

1. Independent runs now carry randomized opaque Crew save-envelope fields
   `a`/`z`. Two harnesses incorrectly treated those bytes as gameplay
   determinism. Same-run byte immutability remains exact; paired/cross-process
   observers remove only `a`/`z`, while the determinism hash still includes the
   hidden Turn state, grievance ledger, and grievance sequence.
2. Punchline layer entry applied Crew presence after scenario semantic sealing.
   Crew presence is an authoritative dynamic actor, so SaveService rebuild
   could produce a different inventory. Presence is now applied before the
   first seal and again after reconciliation as required by the existing flat
   event/presence projection.
3. The Punchline high-stakes floor runner overlapped the chair stack in normal
   and expanded-small layouts. Its canonical anchor and package-D generated
   data/dossier are synchronized.
4. JSON converted active-delivery and world-registration security integers to
   floats. Their strict authority validators rejected the loaded structures and
   silently normalized the active delivery away. The save codec now preserves
   exact integers only for those two bounded roots, matching existing scenario
   exact-integer handling.
5. Mounted world-sequence persistence discarded its public scene objects,
   interactions, target inventory, declared targets, and tombstones. Causal
   receipts could prove creation but could not service cleanup after a fresh
   load. The adapter now persists those bounded public collections while still
   rebuilding host interactions, event choices, and transition queues. The
   binding test rejects private Crew envelope keys or Turn/traitor/grievance/
   heist payloads and applies the shared persisted-collection bounds.
6. The real delivery proof target selected `jazz_club_guest_legend`, exposing
   normal/small label collisions. Canonical package-C labels and Jazz Club
   anchors were repaired and regenerated. Commands, branches, outcomes,
   economy, RNG, receipt identities, and lifecycle are unchanged. The Crew
   handoff's public label was shortened without changing `make_handoff`.

## Reproducible gates

| Gate | Result |
|---|---|
| `tools/validate_project.ps1` | PASS — foundation architecture validation |
| `integ06_1_v051_migration_smoke.gd` | PASS — 37/37 genuine saves |
| `world_sequence_delivery_proof_contract.gd` | PASS — production delivery, actual SaveService mid-active recovery, hidden-observer, hostile checkpoint, retry, replay, and cleanup matrices |
| `crew06_10_depth_contract.gd` | PASS — 10 seeds, five profiles, `ordered_v1` |
| `tools/foundation_determinism_probe.ps1 -SeedCount 1 -SeedPrefix INTEG06-1-CHEAP -RequireGodot` | PASS — 56 checkpoints; process hashes `3661442998` / `3661442998` |
| package-C author | PASS — 11 scenarios, 55 pairs |
| package-D author | PASS — 12 scenarios, 66 pairs |

The earlier direct `check_core_content.gd` invocation is invalid setup evidence,
not a product verdict. That file is an intermediate inheritance source for the
marker-aware split runner assembled by `tools/check_godot.ps1`; its content
check deliberately calls `_check_canonical_pack_paths`, which is supplied by
the descendant `check_lenders_release_saves.gd`. `check_delivery_runs.gd` is
likewise an intermediate source, not a standalone test entrypoint.

The supported generated Contracts runner completed project validation and the
306-file GDScript load check with zero failures. It then exceeded the 300-second
hard limit after reporting two `content` failures and 69
`crew_recruitment_contract` failures. The later Crew layer-3 jobs, plays, heist,
Turn, character-chain, content-depth, and coach checks that completed before the
timeout all reported zero failures. This run is a release red: neither the two
content differences nor the 69 Crew differences may be waived because they
also existed on an earlier tree.

The relevant test sources are byte-identical at audit base `6875646b`, accepted
root `47a3a241`, and this branch. The exact ordered 69-message list captured by
the unsupported diagnostic is identical on accepted root `47a3a241` and this
branch; the supported runner independently confirmed the same failure count.
The first eight messages are failed Velvet/Bishop production placements. A
focused production-path diagnostic traced them to four real layout conflicts:
Kitty Cat Lounge buyout ropes versus request cart, Grand Casino gala badges
versus coat check, Grand Casino gala coat check versus host, and the base video
poker control versus the convention coordinator. Repairs are under focused
normal/small-screen verification. The remaining 61 messages are the aggregate
guard plus exact byte/hash differences for the two Crew-ignoring control seeds.
The golden was last authored at `9e8af74b`; six later accepted world changes
alter Crew authority initialization, scenario-authored routes, scenario
layouts, and composed-sequence retention. Full normalized captures from the
exact golden commit and the repaired current tree must prove that every leaf
difference is intended before the fixture is refreshed.

## Work still required before DONE

- Repair the Foundation game-entry/game-exit binding seam, then require
  `integ06_1_crew_play_entry_repro.gd` to exit 0 with the Crew Play present.
- Re-run both admitted migration classes on the final frozen candidate and
  retain their exact logs.
- Run the checked-in maximal composition matrix across every production-
  eligible archetype and all five lifecycle orderings.
- Run the checked-in native/Web terminal-soak producer, including its
  crew-ignoring control and independent native repeat.
- Prove native/Web outcome-trace parity, bounded retained state/frame cost,
  repeated mid-run save/load, representative failure routes, every victory
  route, and terminal profile recording.
- Run the supported generated Foundation suite on the final main tree; never
  invoke its intermediate inheritance sources directly.

The three formerly missing entry points now exist. Their presence does not
change this report's PARTIAL verdict: generation, Godot compilation, exact-
candidate execution, and retained green artifacts are still required.

Until those items have reproducible green evidence, `integ06_1` must remain
TODO and cannot unblock the owner playtest by itself.

## Binding terminal authority boundary

The standalone `endgame_metrics_probe.gd` retains four casino-conditioned
balance scenarios for nonbinding tuning work. Those scenarios directly choose
a Grand Casino start, bankroll, invitation, and a synthetic collection item;
they are therefore excluded from release qualification.

`integ06_1_terminal_soak_main.gd` supplies a separate policy-only scenario
catalog. Every binding case starts with `RunState.standard_challenge`, enters
the generated first environment, and may choose only actions returned as
available by production game, event, service, lender, and travel interfaces.
The binding mode disables synthetic collection/loadout setup, delegates
no-funds termination to `RunTerminalEvaluator`, and rejects a scenario before
start if it requests a casino teleport, bankroll override, invitation, or
caller-selected collection state. Each shard report records that authority
audit. It also refuses to manufacture progress by skipping a travel lock or
advancing an idle turn when no visible player action can be selected; such a
case remains nonterminal and fails the gate. This source hardening is not
runtime evidence; the strict producer must still compile and pass on the exact
final candidate.
