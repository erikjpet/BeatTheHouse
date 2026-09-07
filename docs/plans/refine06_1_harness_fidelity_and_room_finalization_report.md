# refine06_1 Harness Fidelity and Room Finalization Report

Date: 2026-09-07  
Rows: `qa06_1`, `fix06_27`

## Harness incident corrections

Five apparent production failures were harness-fidelity failures. Incidents
1–4 skipped the production host's mandatory arrival finalization before reading
sequence state or departing. Incident 5 selected the first rendered `travel`
object after local travel, which was `travel:motel_room` (`Room Door`) rather
than the intended `travel:leave`.

The shared `HarnessProductionFidelity` support now centralizes initial arrival,
travel-plus-finalization, and exact semantic-object resolution/activation. Its
arrival helpers always run `scenario_finalize_installed_environment()` with a
production-sized layout context and append the exact failure to the calling
harness. Its object helper has no type, label, or render-order fallback.

The Foundation visual/click QA now reacquires `travel:leave` by exact id and
requires it to be enabled, visible, interactive, and hittable. The parent-venue
regression requires both `travel:motel_room` and `travel:leave`, verifies the
second recorded input is `travel:leave`, requires the map to open, and compares
serialized RunState byte-for-byte until route confirmation. Failures include
the selected id, label, and serialized-state difference.

The fail-closed departure guard is unchanged. Its refusal now says the arrived
room was likely never finalized by its host or harness.

## 36-harness audit

The audit found 20 of the 25 exposed harnesses inspect destination contents,
read sequence state, or depart again and therefore require the shared arrival
helper:

- Foundation contracts: `back_alley_fence_night_install_contract.gd`,
  `check_core_content.gd`, `check_delivery_runs.gd`,
  `check_items_events_world.gd`, `check_lenders_release_saves.gd`,
  `content_depth_contract.gd`, `crew_heist_contract.gd`,
  `crew_ignored_golden_probe.gd`,
  `env06_7_production_authority_contract.gd`,
  `punchline_layer_contract.gd`, and `scenario_sequence_contract.gd`.
- UI contract: `tutorial_corner_shop_order_check.gd` and
  `compile_run_menu_and_game_flows.gd`.
- Tools: `coin_pusher_copy_visual_probe.gd`, `content06_manual_smoke.gd`,
  `cross_economy_audit.gd`, `environment_generation_audit.gd`,
  `foundation_determinism_probe.gd`,
  `perf06_deferred_validation_contract.gd`, and
  `playtest06_2_seed_catalog_probe.gd`.

Deliberate rejected-travel cases and real `FoundationMain` host paths remain on
their raw production seams; wrapping those would erase the oracle being tested.
Custom-generator probes continue to pass their actual generator into the helper.
Determinism checkpoints consume no added RNG, and accepted goldens were not
refreshed.

Five exposed files are intentionally unconverted:

| File | Reason |
| --- | --- |
| `check_coin_pusher.gd` | Initial generation only obtains a registered node id, then the test replaces the environment with a focused cabinet fixture. It neither inspects nor departs the generated room. |
| `check_slots_surfaces.gd` | Initial generation only establishes a map/current node for a read-purity test; no room or sequence contents are inspected and there is no departure. |
| `numbers_contract.gd` | Initial generation constructs a delivery-world shell, after which purpose-built Numbers environments replace it. Finalizing the discarded room is outside the fixture's model boundary. |
| `crew_poker_visual_capture_wrapper_check.ps1` | This is a source-text meta-check, not a RunState owner; it performs no runtime travel. |
| `crew_poker_visual_seed_audit.gd` | Initial generation only advances to the pinned post-foundation RNG point, then a synthetic poker room is installed. Generated room/sequence contents are never read or departed. |

The other 11 travelling harnesses were audited as the complement of the 25-file
zero-finalizer exposure set:
`crew_recruitment_contract.gd`,
`env06_8_environment_readability_contract.gd`,
`world_sequence_delivery_proof_contract.gd`, `endgame_metrics_probe.gd`,
`scenario_seed_audit.gd`, `slot_bonus_stuck_sweep.gd`,
`tier1_scenario_audit.gd`, `tutorial_seed_audit.gd`,
`wave_a_coexistence_probe.gd`, `wave_b_composition_probe.gd`, and
`foundation_visual_qa.gd`. Their relevant live scenario paths either already
contain an explicit finalizer, drive the real `FoundationMain` host, or are
selector/synthetic setup paths that do not inspect or depart a live dynamic
room. No additional zero-finalizer candidate was found. This distinction is
recorded so textual call counting is not mistaken for behavioral fidelity.

## Seed-dependent dead-room root causes and decisions

### Random room event versus Lotto Fever

`corner_store_lotto_fever` renders the short prop label `Queue Rail`, but its
actionable interaction label is `Hold the ticket line`. Placement previously
reserved only the short label; strict validation correctly rejected seeds where
the longer actionable label touched `event::event:town_rumor_staff`.

Decision: keep the validator strict and make late scenario placement reserve the
longer of the visual and interaction labels against all already-placed base-room
controls. This is a deterministic runtime collision-avoidance pass at the point
where both the seeded room event and authored scenario geometry are known. No
event is deleted, no label guarantee is weakened, and no RNG is consumed.

### Inventory Night cage/exit

`count_cage` declared `zone_id: left` while also anchoring to
`delivery_manifest`, a service-lane anchor at `[700,100]`. Removing that
contradictory anchor restores left-zone placement and keeps both the cage and
the authored safe exit separately selectable at expanded-small scale. The
scenario signature was regenerated; its objects and actions are unchanged.

### Barrier walk-lane displacement

`kitty_cat_lounge_buyout_buyout_ropes` starts at a safe authored anchor, but a
seed-varying base-room collision could displace it into `WALK_LANE`. Collision
placement now treats the lane as forbidden for every object whose role is
`obstacle`, `barrier`, or `blockade`, including the expanded-small rectangle.
The post-placement validator remains strict as a second fail-closed check.

The permanent structural sweep freezes 25 such objects (18 barriers and 7
obstacles) and all 39 authored spawn/move placements across the 55 scenarios.
The permanent seed gate uses eight independent families across all 55 scenarios
and requires 440 successful production-faithful finalizations, each validating
normal and expanded-small geometry. The established 1,108-object and 673-action
census runs in the same gate, preventing deletion as a collision repair.

## Verification

Exact implementation head `8cf795d9` passed the permanent gate in 357.8 seconds:
eight seed families, all 55 scenarios, 440 production-faithful finalizations,
normal and expanded-small geometry, exact parent-venue departure, structural
barrier coverage, and the unchanged object/action census. `validate_project.ps1`
passed on the same tree in 80.6 seconds. Focused environment travel, tutorial
Corner Store, and deferred-validation checks also passed.

The broad Foundation visual QA exercised the corrected exact `travel:leave`
input and opened the world map without a target-path failure, then stopped later
on a Talk Dock response-chain action bound. A broader UI compile run
proved that the room-layout repair changed only the two generated-layout hashes;
all route, RNG, story, money, Heat, clock, and travel-count values remained
identical. After that justified two-hash update, the auxiliary run stopped later
on its separate M1.5 layout-only inspection assertion. The assembled Foundation
contracts auxiliary run likewise exceeded its 360-second ceiling after the
mandatory production finalizations and returned no contract verdict. None of
these broader attempts is represented as a pass, waived, or used as acceptance
evidence for these rows.

No money, RNG, RTP, payout, odds, schema, or migration logic was changed. No
release, export, package, version, tag, or owner build was produced.
