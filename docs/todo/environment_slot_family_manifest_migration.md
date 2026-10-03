# rw06_10 — Environment slot families and generated object manifests

Status: COMPLETE — implemented and verified 2026-09-29. Final artistic
repositioning remains the owner handoff and is not unfinished migration work.

Queue row: `T10` in `docs/todo/rw06_final_queue.md`.

Workspace: `D:\Projects\Beat-The-House`

## Completion evidence

- Placement data now uses root schema 3 and slot schema 2 across all 21 maps,
  18 archetypes, and 55 scenarios.
- The authored inventory contains 722 slots: 225 `fixed`, 149 `event`, 270
  `scenario`, and 78 `exit`. The static checker covered 767 active snapshots
  with zero overflow, family crossover, or binding conflict.
- Every generated environment owns a deterministic sealed object manifest;
  revisit, save/load, runtime projection, and second-load retention checks pass.
- Jazz Club now guarantees eight distinct fixed occupants: bartender, sax,
  cello, drummer, band tip jar, band stage, Pull Tabs, and Dot.
- Effective layer inheritance is part of the migration contract: the Punchline
  casino's inherited Side Door is fixed-owned and retains its authored geometry.
- The focused manifest, retention, occupancy, stacking, placement-tool,
  grounding, and readability gates pass. The Audit runtime matrix passed all
  38 Godot/performance stages, including 440/440 scenario finalizations,
  18,000 reachable states, and 4,024 distinct layouts after action-routing
  signatures were included in de-duplication. Its first static
  preflight observed a transient cache-snapshot race; the same
  `validate_project.ps1 -Quiet` gate then passed in isolation with no Godot
  process present. Evidence: `.tmp/test_reports/20260929_final_slot_audit/`.
- The post-repair canonical Smoke suite passed all 10 stages. Evidence:
  `.tmp/test_reports/20260929_final_slot_smoke4/`.
- Fresh movement-tool evidence captured all 21 maps with zero failures at
  `.tmp/rw06_1/visual_evidence/rw06_10_final_20260929_07/slot_markers/`.
  Placement SHA-256: `1A1BE472607C1CCEA8A184400D8A2A26674C81280251D366C8056757588401A2`;
  marker manifest: `3EC1694A0615E840E276E93EB8E65B879873769DC57BB116F32C525B08AC6E0A`;
  contact sheet: `46B42AF2064C149AAAE8DB8EBE1062DCEB418E13AA685654FD62A8C96914A33E`.

## Goal

Replace the current mixed `base` / `stage` placement model with four explicit,
lifecycle-owned slot families across every environment and layer:

- `fixed.*`
- `event.*`
- `scenario.*`
- `exit.*`

Every generated environment must own a deterministic manifest of the physical
objects created for it. That manifest, rather than inferred art/type rules or a
late reconstruction from unrelated gameplay arrays, becomes the authority used
to fill authored slots.

This is a repository-wide migration. It is complete only when all 21 production
placement maps, all 18 environment archetypes, all layered/subroom variants, and
all 55 environment scenarios use the new contract without changing existing
gameplay selections, action IDs, save outcomes, or deterministic RNG behavior.

The owner will manually perform final object positioning after the structural
migration. Preserve the current layout wherever possible and provide safe
provisional positions where one old position must split into multiple
simultaneous objects. The owner will inspect and reposition every slot later;
no special provisional-position flagging is required.

## Locked owner decisions

- Category 1 is named `fixed`, never `base`.
- The canonical spelling is `scenario`, never `scenerio`.
- The canonical instrument spelling is `cello`, never `chello`.
- `fixed.*` owns environment-specific objects and permanent capacity.
- `event.*` owns optional ambient events unrelated to the active scenario.
- `scenario.*` owns all physical actors, props, items, and controls created by
  the active scenario or its current phase.
- `exit.*` retains its current purpose: real travel to another environment,
  sub-environment, room, or layer.
- Scenario slots are reusable, generic positions. Their IDs must describe
  location/type and must not contain scenario IDs.
- Fixed slots may be specifically named because their environment role is
  stable.
- The existing slot-movement tool is the basis for the owner's later manual
  placement pass. Extend it for the four families; do not replace it with a
  separate editor.
- Legacy saves and legacy placement overrides do not require compatibility.
  Development environments may be regenerated under the new rules.
- The planning hold was lifted by the owner's explicit kickoff.

## Owner confirmations recorded 2026-09-28

1. Permanent capacity slots such as `fixed.item_shop_2` may remain empty when
   the existing generated count selects fewer objects. Named required fixed
   objects must always be occupied; current game-balance counts remain intact.
2. Shared legacy slots may split into deterministic in-room provisional
   positions. They only need to exist in the environment; overlap warnings are
   visible in the movement tool, and the owner will manually adjust positions
   later without special provisional flags.
3. Legacy-save compatibility is not required. The owner is the only player and
   accepts regenerating development environments with the new rules.
4. The task is tracked as `rw06_10` / final-queue row `T10` for documentation.

## Pre-migration baseline and root cause

The pre-migration placement authority in
`data/environments/placement_surfaces.json` contained:

- 21 placement maps for 18 archetypes.
- 241 `base.*` slots.
- 185 `stage.*` slots.
- 42 `exit.*` slots.
- 468 total authored slots.
- 11 footprint classes.
- 255 exact object preferences.
- 295 category/index preferences.
- 623 scenario preferences.

`EnvironmentInstance` previously generated games, ambient events, offers,
services, lenders, fixtures and travel state into separate fields. Later,
`_active_object_layout_entries()` reconstructs a possible physical inventory
from those fields. There is no single durable generated object manifest.

`EnvironmentSlotBinder.bind_base_layout()` previously allowed ordinary generated
objects to consume both `base_slots` and `stage_slots`. Scenario visuals consume
`stage_slots`, while scenario safe-exit controls may consume `exit_slots`. This
allows lifecycle families to borrow from one another.

Jazz Club demonstrated the failure clearly:

- The musicians are painted into the background by `_draw_jazz_club()` and
  `_draw_jazz_player()`; they do not have generated physical object identities.
- Only their service actions reach slot binding.
- Sax and cello both prefer `base.service_band_rail`.
- Drummer and band tip jar both prefer `base.service_stage`.
- The current physical-object heuristic rejects those services when they have
  neither approved art provenance nor another whitelisted physical marker.

The migration must create distinct fixed Jazz objects and attach the existing
service actions to them. It must also suppress the equivalent baked background
drawing so each musician is rendered once.

## Canonical slot contract

Every placement map uses four explicit arrays:

- `fixed_slots`
- `event_slots`
- `scenario_slots`
- `exit_slots`

Every slot keeps the current reusable geometry contract:

- `id`
- `kind`
- `pos`
- `footprint_class`
- `hit_rect`
- `label_anchor`
- `facing`
- `priority`
- `zone_id`
- `support_id`
- `walk_lane_ids`

Rules:

1. `kind` must equal the ID prefix.
2. Slot IDs are unique within the effective map/layer.
3. `footprint_class` is the binding compatibility authority. Never infer
   compatibility from the human-readable slot name.
4. A physical object may bind only inside its declared family.
5. No cross-family fallback, overflow borrowing, or collision reassignment.
6. One live physical object owns exactly one slot, and one occupied slot points
   to exactly one live physical object.
7. Multiple actions may attach to one physical object without claiming more
   slots.
8. Required fixed objects and real exits fail closed if their exact slot is
   missing or incompatible.
9. Empty authored capacity is legal only when its declaration explicitly says
   occupancy is optional.
10. Validate geometric overlap for combinations that can be active
    simultaneously and surface it as a placement warning; duplicate slot
    ownership, family/class mismatch, missing authority, and out-of-canvas
    geometry remain hard failures.

Recommended names include:

- `fixed.staff_bartender`
- `fixed.musician_sax`
- `fixed.musician_cello`
- `fixed.musician_drummer`
- `fixed.tip_jar_band`
- `fixed.pulltab_game`
- `fixed.random_game_1`
- `fixed.item_shop_1`
- `event.standing_person_1`
- `event.behind_counter_person_1`
- `event.floor_fixture_1`
- `event.floor_fixture_1`
- `event.wall_item_1`
- `scenario.standing_person_1`
- `scenario.seated_person_1`
- `scenario.floor_fixture_1`
- `scenario.wall_item_1`
- `scenario.doorway_1`

Keep existing `exit.*` slot IDs wherever possible. Do not mass-rename exits.
Move actual world, room and layer transitions that currently occupy `base.*`
doors into exit-family authority.

## Environment object declarations and generated manifest

Add an authored environment/layer declaration describing guaranteed physical
objects and variable-capacity fill rules. Resolve it into a per-instance
`object_manifest` after the environment's gameplay content is selected.

The environment payload needs a manifest schema version, revision/digest and a
closed array of physical object rows. Each row must contain enough information
to validate and replay the composition without content-selection RNG:

- stable `instance_object_id`;
- existing presentation/action-facing object ID where compatibility requires it;
- `family`: `fixed`, `event`, `scenario`, or `exit`;
- exact source collection and source ID/provenance;
- placement/footprint class;
- exact slot ID for named fixed objects and exits, or selected compatible slot
  for generic event/scenario objects;
- required versus optional occupancy;
- active/present lifecycle state;
- explicit physical/render authority;
- attached interaction/action IDs;
- ordinal, route, layer, support, or location metadata where applicable.

Manifest rules:

- The manifest contains physical room objects, not duplicate records for every
  action verb.
- Slot geometry remains exclusively in the placement map. Do not copy mutable
  coordinates into durable object rows.
- Fixed, selected ambient-event and exit rows are durable per generated room.
- Scenario rows are a transactionally derived live section owned by the sealed
  current scenario phase. They must be available to the same runtime authority
  and digest checks, but may be rebuilt from durable scenario state on load.
- Manifest construction consumes zero RNG. It projects selections that already
  exist in `game_ids`, `event_ids`, `item_offers`, `service_ids`, lender state,
  fixture state, travel targets and scenario state.
- Keep those gameplay fields during the first cutover. Do not combine this
  placement migration with an unrelated rewrite of game/economy state.
- Family comes from authored lifecycle provenance, never from prefixes such as
  `event:` or words in labels.

## Binding order and ownership

Use one validated occupancy authority with four disjoint passes:

1. Bind required and optional fixed-manifest rows to `fixed_slots`.
2. Bind actual navigation rows to `exit_slots` and reserve them from every
   non-navigation family.
3. Bind selected ambient-event rows to compatible `event_slots`.
4. Bind active scenario rows to compatible `scenario_slots`.

Ordering inside a family remains deterministic: exact authored preference,
then compatible location/footprint and priority, then stable slot ID. Do not
consume RNG during binding.

Scenario routes must preserve start/end-slot claims and authored walk lanes.
An active route endpoint is an occupancy claim. A scenario safe-exit object
belongs to `exit.*` only when activating it actually changes room/environment/
layer. A scenario-local escape task, door prop or resolution control remains a
generic `scenario.*` object. A scenario may enable, disable or relabel an
existing real exit without creating a second physical exit.

## Full environment coverage

Convert all maps in one schema/data cutover. Jazz Club may be the internal
canary, but a partially converted production schema must never ship.

### Street and venue maps

- `corner_store`
- `back_alley`
- `motel`
- `bar`
- `gas_station_casino`
- `jazz_club`
- `kitty_cat_lounge`
- `delta_queen`
- `beach`
- `pawn_shop`

### Layered Punchline maps

- `small_underground_casino` legacy/fallback map
- `small_underground_casino:club`
- `small_underground_casino:casino`
- `small_underground_casino:back_room`

Retain the existing default-layer, compatibility-primary-layer and per-layer
state behavior.

### Grand Casino suite

- `grand_casino`
- `grand_casino_high_limit`
- `grand_casino_back_room`
- `grand_casino_cage`

### Homes

- `motel_room`
- `apartment`
- `house`

## Data migration procedure

Create an explicit reviewed mapping row for every legacy slot. Each mapping
records:

- map/layer;
- old ID and collection;
- new family and ID;
- footprint and support;
- every current exact/category/scenario claimant;
- whether claimants can coexist;
- required versus capacity occupancy;
- action-to-object attachment decisions;
- preserved or provisional geometry.

General conversion rules:

- Guaranteed environment-owned physical object -> `fixed.*`.
- Variable selected ambient event -> `event.*`.
- Scenario-provenance physical object -> `scenario.*`.
- Real destination/layer/room transition -> `exit.*`.
- Guaranteed content whose gameplay definition happens to be an event is
  classified by actual lifecycle, not its `event:` ID.
- Rumor/drink/dialogue actions that use a permanent bartender or clerk attach
  to that fixed host rather than minting duplicate people.
- Random game and shop-item identity may fill stable numbered fixed capacity.
- Mutually exclusive scenario objects may reuse the same generic compatible
  scenario slot.
- Simultaneous objects must never share one slot. Overlapping provisional hit
  targets remain visible and actionable, emit placement warnings, and are left
  for the owner's artistic positioning pass.

Preserve every current coordinate that maps one-to-one. Where a mixed legacy
slot must split, create deterministic in-room provisional geometry and expose
overlap warnings in the updated movement tool. Special provisional markers are
not required. Do not spend this task attempting the owner's final artistic
layout.

## Jazz Club canary contract

Jazz must define and bind distinct required fixed objects for at least:

- bartender;
- sax musician;
- cello musician;
- drummer;
- band tip jar;
- band stage / `listen_to_jazz` host;
- Pull Tabs machine/sign as its actual physical contract;
- Dot;
- every other genuinely guaranteed fixture/host;
- configured shop-item capacities.

Keep the existing service/action IDs, including:

- `service:house_drink`
- `service:jazz_sax_round`
- `service:jazz_cello_round`
- `service:jazz_drummer_round`
- `service:jazz_band_tip_jar`
- `service:listen_to_jazz`

Attach those actions to the appropriate fixed object. `listen_to_jazz` should
attach to an appropriate band/stage host and must not consume a musician's
slot. Remove or condition the baked musician draw path once manifest-owned
musicians render, preventing duplicate people.

Jazz acceptance must cover Base / No Scenario, every Jazz scenario and phase,
multiple seeds, revisit, save/load, and second-load idempotence.

## Runtime integration work

Update every path that currently reconstructs, mutates, authenticates or draws
physical inventory:

- `scripts/core/environment_instance.gd`
- `scripts/core/environment_slot_binder.gd`
- `scripts/core/environment_placement.gd`
- `scripts/core/environment_base_semantic_records.gd`
- `scripts/core/environment_semantic_inventory.gd`
- `scripts/core/scenario_layout_resolver.gd`
- `scripts/core/scenario_engine.gd`
- `scripts/core/run_generator.gd`
- `scripts/core/run_state.gd`
- `scripts/ui/environment_interaction_controller.gd`
- `scripts/ui/environment_interaction_view_model.gd`
- `scripts/ui/pixel_scene_canvas.gd`
- the FoundationMain environment/interactable cache token and installation seam;
- developer placement storage and Settings toggles;
- content-library validation for environment and layer declarations.

Add one manifest reconciliation API and route all physical-state changes
through it, including:

- environment generation and restoration;
- selected/resolved ambient events;
- item purchases and cage stock changes;
- game hook appearance/disappearance;
- service, lender, Crew and Numbers changes;
- home container/storage changes;
- town/challenge mutations;
- Grand Casino room targets;
- world destinations and `travel:leave`;
- layer transitions;
- scenario installation, phase transition, aftermath and rollback.

The UI must join existing interactions to manifest physical identities. The
current closed art/type heuristic may remain as defensive validation, but it
must no longer decide whether an authored required object exists.

Audit room-specific background draw functions. Any object newly owned by the
manifest must be removed from or conditionally hidden in baked background art
to avoid double rendering.

## Versioning and fresh-save behavior

Bump all affected authorities together:

- placement-map root/schema version;
- slot schema version;
- generated layout version;
- grounding signature inputs;
- slot-map and binding digests;
- manifest schema/revision/digest;
- semantic inventory/layout authority versions if their sealed payload changes;
- developer placement override schema, invalidating old slot-ID overrides.

Legacy environment/save compatibility is deliberately out of scope. Do not
build a v1-to-v2 manifest or slot-binding translator. Existing development
saves and old local placement overrides may be invalidated/reset and their
environments regenerated through the canonical v2 generation path.

Frozen historical-fixture probes are diagnostic only for this cutover. When an
old fixture is still admitted by the shape-generic save codec, its first load
may canonicalize legacy environment data into v2. That transition is not
required to preserve an exact pre-v2 gameplay projection. The first restored
v2 state becomes the baseline, and saving/loading that current-version state a
second time must be exact and idempotent. If the historical room instead has
v2 placement errors, discard that incompatible room and exercise the public
fresh-run path with the same seed; the regenerated manifest/layout must validate
and remain exact across two current-version restores. Historical mid-state is
not preserved or asserted in that regeneration branch.

The new schema must still have a complete current-version persistence contract:

1. Fresh v2 generation creates and validates the complete manifest before the
   environment is installed.
2. Current environment state, persistent world nodes, Grand Casino rooms and
   every Punchline layer state serialize the v2 manifest and bindings.
3. Current-version save/load and revisit preserve selected content, scenario
   phase, object manifest, bindings and digests without rerolling.
4. A second current-version load is idempotent.
5. An incompatible old save fails cleanly through the existing unsupported-save
   or fresh-generation path; it must not be partially interpreted as v2.
6. The save codec may remain shape-generic if tests prove it preserves the new
   fields exactly.

## Developer movement tool and manual-placement handoff

Extend the existing Environment slot placement mode so the owner can perform
the final layout pass after this task:

- Show/filter `fixed`, `event`, `scenario` and `exit` independently.
- Give each family a distinct color and legend.
- Show stable slot ID, family, footprint, support, layer, occupancy and whether
  occupancy is required or optional.
- Keep empty capacity visible and editable.
- Preserve pointer dragging, keyboard nudge, preview, cancel, reset, durable
  local save and project promotion.
- Translate position, hit rectangle and label anchor together without changing
  slot identity or size.
- Scope overrides by map and layer, including all Punchline layers.
- Show missing required occupants, incompatible occupants, family crossover,
  and overlap warnings.
- Generate an all-21-map marker contact sheet for the owner's repositioning
  pass. No separate provisional-position report is required.

Moving slots must update placement-map authority/digests without changing
manifest identities, gameplay selection, scenario state, RNG or save economy.

## Tools that must be updated or retired

These currently emit or enforce schema-v1 fields and can undo the migration:

- `tools/rw06_1_author_fixed_slots.py`
- `tools/rw06_1_apply_hand_authored_slots.py`
- `tools/environment_fixed_slot_static_check.py`
- `tools/environment_grounding_contract.gd`
- `tools/environment_layout_screenshots.gd`
- environment generation/finalization audit tools;
- exact-seed and visual-capture wrappers that parse old report fields.

Update each tool to v2 or explicitly retire it so no normal command can rewrite
`placement_surfaces.json` back to `base_slots` / `stage_slots`.

## Validation requirements

Add or update focused coverage for:

- prefix/kind and schema validation;
- globally unique slot IDs per effective map;
- required fixed occupancy versus optional capacity;
- strict family isolation and no borrowing;
- footprint/support compatibility;
- manifest-to-binding and binding-to-manifest bijection;
- real-navigation-only exit occupancy;
- simultaneous normal and expanded hit/label overlap warnings;
- event/scenario worst-case capacity by footprint;
- scenario actor routes and distinct endpoints;
- action attachment without duplicate physical objects;
- deterministic generation, revisit and save/load;
- current-version save round-trip and second-load idempotence;
- clean rejection/reset of incompatible old save and placement data;
- placement editor behavior for all four families;
- no duplicate baked/manifest rendering.

At minimum, update and explicitly register the relevant checks:

- `scripts/tests/room_slot_occupancy_check.gd`
- `scripts/tests/environment_slot_stacking_regression_check.gd`
- `scripts/tests/environment_slot_placement_mode_check.gd`
- `scripts/tests/developer_placement_mode_check.gd`
- environment-library launcher/test-mode checks;
- `scripts/tests/foundation/check_slots_surfaces.gd`
- `scripts/tests/foundation/check_items_events_world.gd`
- scenario semantic presentation contracts;
- environment semantic inventory contracts;
- layered Punchline contracts;
- Grand Casino travel/subroom probes;
- current-version save/load smoke tests.

Do not assume files ending in `_check.gd` are automatically included in the
permanent suite. Register or bridge them explicitly.

## Verification matrix

Exercise every materially distinct combination:

- all 21 placement maps and 18 archetypes;
- all four families;
- Base / No Scenario and every legal scenario;
- every scenario phase, branch, outcome and aftermath;
- all selected ambient-event candidates across deterministic seeds;
- minimum and maximum configured game, item and event counts;
- fresh generation, repeated entry, revisit and replacement;
- save/load and second-load idempotence;
- Punchline layer changes and stored layer restoration;
- all Grand Casino local rooms and world travel;
- normal and expanded/small-screen geometry;
- new local and project developer placement overrides;
- fresh v2 saves, current-version reload and second-load idempotence;
- current exact-seed fixtures plus deterministic multi-seed sweeps.

Run the gate ladder serially and fix root causes before advancing:

1. Schema/static validation.
2. Focused occupancy, stacking, placement, library and grounding checks.
3. Fresh-save, current-version reload and incompatible-save rejection checks.
4. Project validation.
5. Smoke suite.
6. Contract suite.
7. Audit/full suite, including all-scenario finalization and environment
   generation audits.
8. All-map visual captures/contact sheets.
9. Final repository search proving `base_slots`, `stage_slots`, `base.*` and
   `stage.*` placement IDs remain only in compatibility code or frozen fixtures.

Do not overlap Godot test processes in this workspace. Use the repository's
existing process-custody rules and timeouts.

## Definition of done

This task is DONE only when:

- Every production map declares the four canonical slot collections.
- Every generated room/layer owns a validated object manifest.
- Every named guaranteed fixed object always exists and binds uniquely.
- Optional capacity behavior is explicit and preserves approved generation
  counts.
- Ambient event objects bind only to `event.*` and do not reroll on revisit.
- Scenario physical objects bind only to generic `scenario.*` positions.
- Actual navigation binds only to `exit.*`, and all destinations remain usable.
- Cross-family fallback is impossible.
- Existing game, service, event, tutorial and travel action IDs still dispatch.
- Fresh v2 saves preserve complete current-version state and round-trip
  idempotently; incompatible old saves fail cleanly and may be regenerated.
- Jazz bartender, sax, cello, drummer, tip jar, band stage, Pull Tabs, and Dot
  pass the canary contract.
- No new manifest-owned object is also baked into the room background.
- The updated movement tool works on every map and layer and produces the
  owner's manual-placement handoff report/contact sheet.
- Static and focused gates pass; canonical Smoke passes; every migration-owned
  Contract/Audit runtime gate passes, with the isolated static validator rerun
  resolving the Audit preflight's transient cache-snapshot race.
- No v1 authoring tool can accidentally rewrite production placement data.

## Non-goals

- Do not perform the owner's final visual positioning pass.
- Do not rebalance item/game/event counts unless separately approved.
- Do not rename gameplay action IDs or scenario semantic `base::` ownership.
- Do not redesign travel, scenario content, economy or RNG.
- Do not replace the existing movement tool with another editor.
- Do not build legacy-save or old-placement-override migration.

## Kickoff record

The owner explicitly kicked off this task after approving the four-family
contract, provisional-position policy, development-save regeneration, and
`rw06_10` tracking. The implementation proceeded beyond the Jazz canary and
schema conversion through the complete all-environment migration and handoff.
