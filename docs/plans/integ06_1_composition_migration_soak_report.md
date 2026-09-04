# integ06_1 composition, migration, and soak report

Status: **PARTIAL — keep `integ06_1` TODO**
Audit base: `6875646b19cb8c8ce242414e1251a8ae7bcffc2c`
Harness prerequisite: `1131c6262eb04b2cbbabc6265caba71c4c234e22`
Product/content repair: `c9e5941f43c3f507921482bdac1e7a8c34a75a18`
Composition harness: `91af060af1b28bd5217f8c2ee9454fc0aa589567`
Exhaustive composition producer: `408c670a` plus eligibility proof `9c30110b`
Terminal native/Web soak producer: `2bda2450`
Package-E layout correction checkpoint: `b7a75334` (**runtime unreviewed**)

This report records the completed historical-save and maximal-composition work
without claiming the native/Web terminal soak that has not yet run. The
provenance and capture history for every historical fixture remain in
`docs/plans/integ06_1_historical_fixture_wip.md` and the checked-in sidecars.

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

No authentic mid-0.6 owner-build inventory has been located or admitted. In
particular, this matrix does not yet prove saves taken before the Punchline,
delivery, scenario-snapshot, or Coin Pusher V3 successor migrations. Synthetic
lookalike saves were not substituted.

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

- Generate and admit the three approved player-reachable mid-0.6 development-
  boundary saves; no owner-authored inventory existed to recover.
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
