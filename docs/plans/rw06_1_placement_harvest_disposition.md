# rw06_1 placement harvest disposition

Date: 2026-09-23
Source custody report: `docs/plans/postfix06_2_placement_harvest.md`
Solver snapshot: `78a62257745602c40ec804740ee9f95d789606db`

This is the complete disposition of the 20 pieces in the postfix06_2 placement
harvest. The fixed-slot system keeps every player-facing guarantee while
removing runtime coordinate search. The snapshot remains the recovery point for
mechanisms deliberately dropped below.

## Complete item disposition

| Harvest item | Source verdict | rw06_1 disposition | Replacement / evidence |
| --- | --- | --- | --- |
| Safe-exit corridor reservation and reachability | ADAPT | Ported as authored `exit_slots`; safe exits bind before routed and ordinary visuals. Every exit slot names an entry walk lane, and required safe exits may not overflow. Repack requests were not ported. | `scripts/core/environment_slot_binder.gd`; `scripts/core/scenario_layout_resolver.gd`; `tools/environment_fixed_slot_static_check.py` checks exit geometry, entry-lane reachability, and every reachable phase. |
| Live base-control inclusion | KEEP | Kept. The complete generated games/events/items/services/lenders/travel inventory is classified and receives a base slot or explicit overflow authority. Late membership refreshes the same immutable binding rather than silently omitting an object. An actionable late alias of an already generated physical prop reuses that prop's binding instead of consuming a duplicate slot; Sal and all six Pawn Shop shelf controls exercise this path. | `scripts/core/environment_instance.gd::ensure_generated_layout`; `EnvironmentSlotBinder.bind_base_layout` and `bind_base_records`; the full-catalog hooks in `environment_interaction_controller.gd` and `meta_session_controller.gd`. |
| Exclusive normal and 44px authority validator | KEEP | Kept as a fast schema invariant over base, stage, and exit slots. Normal hits, expanded 44px hits, labels, and both normal and expanded cross hit/label pairs must all be disjoint. | `tools/environment_fixed_slot_static_check.py::validate_map`, called by `tools/environment_grounding_static_check.ps1` and `tools/validate_project.ps1`. |
| Renderer/authority geometry synchronization | ADAPT | Ported. A room record carries `slot_id`, `placement_class`, `presentation_mode`, and the exact immutable slot rect. Overflow has no canvas rect. Pointer/focus authority and drawing therefore consume the same geometry. | `environment_interaction_view_model.gd`; `pixel_scene_canvas.gd`; replacement `_check_fixed_slot_renderer_authority` in `scenario_semantic_presentation_contract.gd`. |
| Scenario visual deterministic repack/displacement | DROP | Dropped. Production `_resolve_visual_queue` calls the deterministic slot binder; it never moves a prior binding or searches a coordinate. Failure to bind becomes an overflow action. | `scenario_layout_resolver.gd`; source-route assertions in `environment_fixed_slot_static_check.py`. The old search remains only at the snapshot commit. |
| Base-object transitive repack solver | DROP | Dropped. Base inventory uses preferred compatible slot, then `(priority, id)`, otherwise overflow. No graph or cohort is built. | `environment_instance.gd`; `environment_slot_binder.gd`; fixed-binding checks in `environment_grounding_contract.gd`. |
| Lazy fine-grid candidate materialization | DROP | Dropped. Runtime has no coarse/fine grid and no candidate materialization. | Binder source has no candidate-grid API; static source-route check rejects production grounding/search calls. |
| Compatibility/clique solver diagnostics and oracle | DROP | Dropped. Class compatibility is a direct slot predicate, so the clique/oracle mechanism has no fixed-slot meaning. | `environment_slot_binder.gd::_select_slot`; replacement class/overflow contract in `environment_grounding_contract.gd`. |
| Deferred one-pass layout finalization | ADAPT | Ported as idempotent binding after each authoritative membership mutation. The binder is pure, so the same complete membership produces the same digest without a second solver pass. | Existing generation/character-chain finalization boundaries call `EnvironmentInstance.ensure_generated_layout`; layout version 13 stores bindings and digests. |
| Initial-generation finalization receipt and atomic rollback | ADAPT | Ported to immutable slot receipts. `slot_map_digest` and `slot_binding_digest` seal the installed membership-to-slot result; ordinary generation/travel rollback remains authoritative, while overflow makes geometric exhaustion non-fatal and atomic. | `environment_instance.gd`; `environment_slot_binder.gd`; digest equality checks in `environment_grounding_contract.gd` and the maintained production-fidelity travel audit. |
| Scenario-prime cache lifecycle | ADAPT | Kept at the stable situation-cycle boundary instead of importing the snapshot's solver-era cache. A retained cycle returns its recorded scenario before selection; new/invalidated cycles prime deterministically. No placement cache was added. | `run_generator.gd::_prime_town_scenarios` and `_select_scenario`; multiseed and environment-generation audits exercise lifecycle generation. |
| Physical-support closed boundaries and independent stage bands | ADAPT | Ported into slot authoring. Each slot seals a class, named support, and semantic zone; exact boundary containment is closed. Bar's extra upper stage band is authored data used by three ground-marker slots, not a runtime exception. Motel classification remains data-driven. | `placement_surfaces.json`; `rw06_1_author_fixed_slots.py`; static support/zone/containment checks. |
| Developer placement overrides for reported pairs | DROP | Dropped from shipping authority. Legacy overrides are available only through `authoring_surface_map()` for preview/migration; shipping `surface_map()` returns authored fixed slots directly. | `environment_placement.gd`; static source-route assertion; ordinary slot data contains all approved positions. |
| Exhaustive 55/415/177 composition enumerator | KEEP/ADAPT | The legal-host and reachable-phase census is kept and made engine-free. The binder simulation covers all 55 sequences, all 55 legal hosts, 767 active snapshots and 1,504 active-plus-aftermath snapshots; order-search mechanics are gone. Offered destinations, actions, hidden state, safe exits, class compatibility, and deterministic repeat binding remain asserted. The report fields are `active_bindings=5452`, `active_overflow=0`, and `complete_overflow=31`: every common active binding fits in-room, while aftermath exercises explicit overflow. | `rw06_1_author_fixed_slots.py::collect_active_phase_snapshots`; `environment_fixed_slot_static_check.py`; machine report under `.tmp/rw06_1/static/slot_report.json`. |
| Historical exact-seed replay | KEEP/ADAPT | All 22 exact UIENV seeds are a checked manifest and a serialized focused runner. Static preflight proves each marker uniquely owns its destination/scenario and each required interaction binds to room or overflow; the runner then executes six visits per exact seed and asserts the target travel, marker, coexisting base object, complete trajectory, and zero audit failures. Solver receipts/survival-reserve assertions were removed. | `tools/fixtures/rw06_1_environment_exact_seed_manifest.json`; `tools/rw06_1_environment_exact_seed_contract_test.ps1`; evidence under `.tmp/rw06_1/exact_seed/`. |
| Solver-derived fixture goldens and recapture provenance | ADAPT | The golden mechanism stays, but layout authority is now `layout-v13` fixed slots. Any changed production golden is recaptured only from the final green fixed-slot build; no solver-era hash is treated as placement truth. | `environment_instance.gd`; Contract golden gate and its existing recapture workflow. |
| Grounding/readability/semantic focused contracts | ADAPT | Solver-mechanism checks were replaced with slot-schema, deterministic repeat binding, class compatibility, overflow, fixed renderer authority, authored route, save/revisit digest, actionability, hidden-state, and safe-exit guarantees. | `environment_grounding_contract.gd`; `scenario_room_multiseed_finalization.gd`; `scenario_semantic_presentation_contract.gd`; Python static contract. |
| Serialized multiseed execution | KEEP | Kept. The maintained multiseed audit still runs its seed families in-process; the 22 historical trajectories are also strictly serial. | `scenario_room_multiseed_finalization.gd`; `rw06_1_environment_exact_seed_contract_test.ps1`. |
| Static content pin used to stabilize a placement fixture | DROP | Remains dropped. Historical seeds and the manifest own placement regression coverage; an unrelated content census is not pinned to one room situation. | Dedicated exact-seed manifest/runner; no custom Bar Fight Night content pin restored. |
| Standalone manifest registration for the exhaustive contract | DROP | The obsolete Godot exhaustive-composition script remains unregistered. Its replacement is a required engine-free gate directly invoked by project validation, which is the appropriate registration point for a Python/PowerShell static contract. | `tools/environment_grounding_static_check.ps1`; required-file and invocation checks in `tools/validate_project.ps1`. |

## Superseded assertions and equivalent guarantees

| Removed/replaced assertion family | Fixed-slot guarantee |
| --- | --- |
| Candidate ordering, strict/fine fallback order, displacement and repack success | Pure preferred-slot then `(priority, id)` binding is run twice for every reachable composition and must produce the identical identity-to-slot map. |
| Exact solver-produced coordinates | Every room coordinate is an authored slot sealed by `slot_id`, map digest, class, hit rect, label anchor, facing, and support. Renderer and action authority share it. The former six hard-coded Pawn Shop shelf points are replaced by six distinct authored surface slots; the actionable shelf records reuse the corresponding generated item bindings, while Sal and the sell counter use distinct behind-counter slots. |
| Repack could clear a blocked exit | Exit slots are globally disjoint, connect to an entry lane, bind first, and every required safe exit must be spatially present. |
| Search found physical support | Slot authoring and static validation prove class-appropriate named support and closed semantic-zone containment before runtime. |
| Solver could accommodate a dense composition | Every public visual gets exactly one `room` or `overflow` presentation; every public action remains reachable. The active census currently reports overflow as a measured per-scenario property, not silent loss. |
| Opposite insertion orders converged | Binding ignores insertion order after stable priority/identity sorting; repeat simulation and digest tests cover save, reload, and revisit determinism. |
| Collision-adjusted renderer rect matched action rect | No collision adjustment exists. Both sides receive the exact bound slot rect, while overflow receives no canvas rect and uses the room action list. |
| Hidden visuals were displaced without leaking actions | Hidden-only actions are absent from both canvas and overflow; the static phase census fails any hidden action exposure. |
| Hostile authored anchors/bounds forced lane or overlay displacement | Free-form anchors and bounds cannot move a fixed binding. The Contract fixture proves a hostile lane anchor still resolves to the authored slot with zero adjustments, while a TalkDock reservation over that exact slot is rejected atomically. |
| Runtime-only controls made scenario visuals search around late reservations | The complete live base inventory binds first. Base and stage slots are globally disjoint, and the Contract fixture verifies the exact immutable rectangles without admitting the runtime control into scenario authority. |
| Collocated fixture anchors were separated at runtime | Distinct visible identities consume distinct compatible authored slots; normal/expanded hit and label disjointness is a static schema invariant, and capacity exhaustion routes to the action list. |

## Runtime-search deletion boundary

The production calls and private helpers for grounding, candidate search,
fallback grids, repack, displacement, and clique solving have been deleted from
`environment_instance.gd`, `scenario_layout_resolver.gd`, and
`environment_placement.gd`. The static contract rejects both calls and function
definitions if any of those paths reappear. Unrelated UI information-card
candidate positioning remains intact. The complete removed implementation is
recoverable from the snapshot named above.

## Authored JSON modularity boundary

`data/environments/placement_surfaces.json` is the continuing fixed-slot
authority. `tools/rw06_1_author_fixed_slots.py` is retained only as the
one-time migration/reproducibility helper that produced the initial authored
inventory; byte-for-byte regeneration is deliberately not an acceptance gate.
The comprehensive static validator reads and validates the checked-in JSON
directly. Its engine-free `validate_single_json_slot_extension` regression
copies the Corner Store map in memory, appends one otherwise absent valid stage
slot, and sends that copy through the same closed-schema, geometry, semantic
zone, support, lane, route, and overlap validation path. This demonstrates that
a later slot addition is one JSON edit covered automatically, without requiring
unrelated slot arrays to be regenerated.
