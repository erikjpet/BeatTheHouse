# Environment scenario slot-instance rework

Status: **ENGINEERING COMPLETE; OWNER PLACEMENT PASS PENDING**.

The four-family migration is implemented across every authored environment.
Shared room geometry and scenario-specific geometry now have separate
authorities and separate persistence scopes. The remaining work is the
owner's visual pass through the 75 reachable placement contexts; it does not require a
new schema or runtime change.

## Objective

Make placement identity describe an object's lifecycle clearly:

- `fixed.*` is room-owned capacity for objects that are guaranteed or whose
  capacity permanently belongs to the environment. Specific permanent
  objects use specific IDs, such as musicians, staff, tip jars, fixtures, and
  game/shop positions.
- `event.*` is reusable room-owned capacity for optional ambient events that
  are independent of the selected scenario.
- `scenario.*` is scenario-owned capacity for the physical actors, props,
  items, controls, and scenario exits used by one exact catalog scenario.
  Catalog scenarios no longer share one oversized map-wide bank.
- `exit.*` remains room-owned travel capacity for changing environments,
  rooms, sub-environments, or layers.

Legacy saves are intentionally not migrated. Regeneration under the new
rules is the supported path.

## Final authority model

The current data split is deliberate:

- `data/environments/placement_surfaces.json` (schema 3, slot schema 2) owns
  21 source room maps and their shared `fixed`, `event`, and `exit` slots.
  Twenty are reachable base contexts; the unlayered
  `small_underground_casino` parent is template-only because runtime always
  resolves the venue to one of its three real layers.
  It physically retains the full legacy/generic `scenario` source geometry as
  a migration template. Runtime composition filters that raw bank: catalog
  maps keep only explicit runtime reserves in no-scenario and active-scenario
  contexts, while the seven reachable maps without catalog layouts keep their
  ordinary scenario-family capacity in the sole base context. The eighth raw
  no-catalog map is the excluded template-only parent described above.
- `data/environments/scenario_slot_layouts.json` (schema 1, slot schema 2)
  owns 55 exact `map_id::scenario_id` banks containing 604 scenario-instance
  slots.
- `data/environments/developer_placement_overrides.json` (schema 3) stores
  committed authoring overrides. Room-level `slot_positions` contain shared
  geometry; `scenario_layouts[scenario_id].slot_positions` contain only that
  scenario's geometry.
- `docs/plans/environment_scenario_layout_breakdown.md` is the complete
  20-base/55-scenario owner checklist and slot inventory. It is a guide, not
  another authority.

The post-audit raw shared source contains 517 authored positions: 175 fixed,
98 event, 211 scenario-source, and 33 exit. Of the 211 shared scenario
positions, 69 are explicit runtime reserves. Catalog scenario contexts replace
the former
ordinary map-wide scenario bank with their exact local bank and append the
room's runtime reserves. The seven reachable no-catalog maps persist their effective
ordinary scenario slots at room scope rather than beneath a fabricated
scenario ID. This is why the raw shared census must not be added blindly to
the 604 local slots.

## Completed implementation checklist

### Naming and data migration

- [x] Replace category-one `base.*` terminology with `fixed.*` everywhere in
  the placement contract.
- [x] Keep the four accepted families limited to `fixed`, `event`,
  `scenario`, and `exit`.
- [x] Give permanent environment objects stable, readable fixed identities.
- [x] Replace the final positional Crew/Ox fixed IDs with identity-specific
  names (`fixed.crew_group` and `fixed.staff_ox`).
- [x] Keep ambient-event capacity in `event.*` and real travel in `exit.*`.
- [x] Audit all 21 placement maps and preserve valid existing coordinates.
- [x] Classify every legacy slot disposition and remove retired `base.*` and
  `stage.*` identities from the active contract.
- [x] Preserve explicit runtime-reserve scenario positions only where a
  runtime producer still needs shared capacity.

### Scenario-local layout generation

- [x] Enumerate all 55 catalog scenarios against their effective placement
  maps, including Punchline layer-qualified maps.
- [x] Build one exact scenario bank per `map_id::scenario_id`.
- [x] Size each bank from the scenario's reachable simultaneous content, not
  from the union of every scenario on the map.
- [x] Preserve footprint class, support, facing, hit rectangle, label anchor,
  route endpoints, and known claimant identities.
- [x] Retain deterministic source coordinates wherever a scenario's slots
  could be mapped without conflict.
- [x] Mark the 180 unavoidable generated coordinates with
  `provisional_geometry: true` for the owner's attention.
- [x] Give every authored scenario scene object exact placement authority;
  interaction-only choices remain attached to their tangible host and do not
  create fake placement markers.
- [x] Generate and validate exact instance/object preference maps for the
  binder.

### Runtime composition and binding

- [x] Resolve the active placement map from environment plus optional layer.
- [x] Compose no-scenario rooms from shared room geometry.
- [x] For a catalog scenario, replace ordinary shared scenario capacity with
  that scenario's exact local bank.
- [x] Append shared runtime reserves without copying them into every local
  bank.
- [x] Keep shared fixed/event/exit content present regardless of which
  scenario is active.
- [x] Route scenario semantic identities and concrete object identities to
  the local bank before generic compatibility fallback.
- [x] Keep scenario actors, props, items, controls, and scenario-only doorway
  objects in the `scenario` family even when their footprint class is
  `doorway`, `wall_mounted`, `surface_item`, or another physical class.
- [x] Remove scenario-owned identities from shared fixed/event/exit maps when
  composing an active scenario.
- [x] Make the effective layout identity and audit data available to the
  rendering and interaction layers.

### Placement tool and persistence

- [x] Continue using the existing Environment slot placement mode rather than
  introducing a second editor.
- [x] Provide focused single-family tabs plus an explicit **All** view while
  keeping every active slot available to full-layout save.
- [x] Allow the selected slot to use the **Behind**, **Standard**, or **Front**
  draw layer without changing its family or identity.
- [x] Preserve explicit Empty capacity and Runtime reserves visibility
  controls.
- [x] Add a prominent **Save Current Layout** action.
- [x] Make that action lock a valid pending drag before taking the snapshot.
- [x] Save every active slot in the exact current context, including hidden
  families, empty optional capacity, and runtime reserves.
- [x] Store `fixed.*`, `event.*`, `exit.*`, and shared reserve coordinates at
  room scope.
- [x] Store ordinary `scenario.*` coordinates only beneath the active
  scenario ID.
- [x] Mark no-scenario completion with `base_saved` and scenario completion
  with `scenario_layouts[scenario_id].saved`, including zero-slot layouts.
- [x] Track expected coverage as 20 reachable base layouts plus 55 scenario
  layouts; exclude the non-playable layered parent template.
- [x] Auto-select and lock a scenario's authored Punchline layer so an exact
  scenario cannot accidentally be saved against the wrong room.
- [x] Keep the placement panel fixed and scrollbar-free within the supported
  viewport, with consistent control/type sizing, actual scenario occupant
  names, saved/remaining progress, and the next missing layout visible in the
  workflow.
- [x] Keep **Save to Project** for writable source checkouts.
- [x] Keep **Export Placement Report** for packaged builds, with schema-3
  room/scenario separation and a complete coverage snapshot.
- [x] Reject unsupported/legacy IDs instead of silently adding them to the
  new authority.
- [x] Require the exact active authored slot set before recording a layout as
  saved; reject both incomplete snapshots and fabricated IDs.
- [x] Merge committed and machine-local completion markers for coverage, while
  making a new local drag mark only its affected context as needing a resave.
- [x] Treat a retained layer-specific scenario cursor as inactive placement
  authority whenever the player is viewing another floor.

### Compatibility and safety

- [x] Preserve stable slot IDs within each layout so moving a slot changes
  geometry, not gameplay identity.
- [x] Keep scenario state, RNG, economy, and spawn selection outside the
  placement tool.
- [x] Keep required-occupant, footprint compatibility, family crossover, and
  overlap diagnostics.
- [x] Keep layered and subroom map isolation.
- [x] Keep packaged-build export recoverable and source-project promotion
  explicit.
- [x] Do not attempt legacy-save migration.

## Coverage inventory

There are **75 manual placement contexts**: 20 reachable base/no-scenario
contexts and
55 exact scenario contexts.

| Placement map | Base | Scenario layouts | Total contexts |
| --- | ---: | ---: | ---: |
| `corner_store` | 1 | 5 | 6 |
| `back_alley` | 1 | 4 | 5 |
| `motel` | 1 | 4 | 5 |
| `bar` | 1 | 7 | 8 |
| `gas_station_casino` | 1 | 5 | 6 |
| `small_underground_casino` (template only) | 0 | 0 | 0 |
| `small_underground_casino:club` | 1 | 5 | 6 |
| `small_underground_casino:casino` | 1 | 3 | 4 |
| `small_underground_casino:back_room` | 1 | 0 | 1 |
| `jazz_club` | 1 | 4 | 5 |
| `kitty_cat_lounge` | 1 | 4 | 5 |
| `delta_queen` | 1 | 5 | 6 |
| `beach` | 1 | 3 | 4 |
| `pawn_shop` | 1 | 3 | 4 |
| `grand_casino` | 1 | 3 | 4 |
| `grand_casino_high_limit` | 1 | 0 | 1 |
| `grand_casino_back_room` | 1 | 0 | 1 |
| `grand_casino_cage` | 1 | 0 | 1 |
| `motel_room` | 1 | 0 | 1 |
| `apartment` | 1 | 0 | 1 |
| `house` | 1 | 0 | 1 |
| **Total** | **20** | **55** | **75** |

## Owner placement handoff

- [ ] Open every `map_id::__base` context listed in the breakdown and arrange
  the shared fixed/event/exit geometry plus any shared scenario reserves.
- [ ] Open every one of the 55 scenario contexts and arrange its local
  scenario bank against the already-positioned shared room content.
- [ ] Treat all 180 scenario slots marked with provisional geometry as awaiting
  artistic placement; their generated coordinates are deterministic starting
  points, not approved final composition.
- [ ] Check all four family tabs and enable Empty capacity and Runtime
  reserves before accepting each context.
- [ ] Use **Save Current Layout** once the entire active context is correct.
  Saving only a scenario does not count that room's base layout as complete;
  visit and save the no-scenario context separately.
- [ ] Continue until the tool reports `75/75 layouts saved; 0 missing`.
- [ ] Use **Export Placement Report** from a packaged build, or **Save to
  Project** from a writable checkout.
- [ ] Merge/promote the report and rerun the placement/runtime validation
  suite before treating the artistic pass as shipped.

## Verification contract

The implementation is guarded by checks for:

- the 20/55/75 reachable-layout census, one template-only parent, and the
  schema-3 persistence shape;
- exact scenario isolation and shared fixed/event/exit inheritance;
- runtime-reserve behavior in base and active-scenario contexts;
- scenario-local binding, mapped object families, and actor routes;
- Save Current Layout ordering, full hidden-slot capture, completion markers,
  and coverage accounting;
- report export and project promotion without cross-scenario leakage;
- all four family prefixes, stable IDs, valid geometry, supported footprint
  classes, and deterministic generation;
- a 75-context runtime sweep that rejects binding failures, duplicate active
  IDs, two objects claiming one slot, missing slots, and occupied hit-rectangle
  intersections, while enforcing a reviewed maximum of 20 occupied room
  objects per generated layout;
- existing environment-library, renderer, interaction, and serialization
  behavior.

## Out of scope

- Migrating old player saves or old developer placement files.
- Choosing final artistic coordinates for the owner.
- Changing scenario gameplay, event probability, spawn selection, rewards, or
  progression.
- Turning scenario-local physical doorway slots into `exit.*`; family is based
  on lifecycle ownership, while `footprint_class` describes physical shape.
