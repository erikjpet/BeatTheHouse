# Environment slot placement mode

Status: COMPLETE. The original placement-mode work and the `rw06_10`
four-family extension are implemented. Final artistic repositioning is an
owner handoff, not unfinished tool or slot-contract work.

## Goal

Provide a developer-only authoring mode that displays and moves the active
placement slots for the current environment context. Shared room slots remain
stable across contexts; catalog `scenario.*` slots belong to one exact
scenario layout. The mode edits slot geometry, never a spawned-object save.

## Current slot-family contract

The movement tool uses the same four lifecycle families as the environment
manifest and binder:

- `fixed.*` for guaranteed environment objects and permanent capacity;
- `event.*` for optional ambient-event objects unrelated to the active
  scenario;
- `scenario.*` for physical actors, props, items, controls, and scenario-only
  doorway objects. Catalog scenarios use exact local banks; only explicit
  runtime reserves and no-catalog chain capacity remain room-shared;
- `exit.*` for real travel between environments, rooms, sub-environments, or
  layers.

Legacy `base.*` and `stage.*` terminology is no longer part of the placement
mode contract.

## Product contract

- Expose a separate **Environment slot placement mode** toggle under Settings
  > Developer. F1 toggles that live mode on or off from the environment view,
  persists the preference, and keeps the Settings draft and checkbox in sync.
  F2 remains the independent hide/restore shortcut for the placement panel.
- Keep object-placement mode and slot-placement mode mutually exclusive.
- Open base contexts on `fixed` and exact contexts on `scenario`; present
  `fixed`, `event`, `scenario`, and `exit` as equal-size single-family tabs
  with distinct colors, plus a final **All** tab that deliberately shows every
  available family together. Switching back to a single family replaces the
  combined overlay.
- Default **Empty capacity** and **Runtime reserves** on during the exhaustive
  placement pass so no authored coordinate is silently skipped. The toggles
  may still reduce temporary visual clutter, and the panel warns when they
  conceal authored markers. Required missing positions remain visible.
- Lead marker and panel text with the current occupant's friendly name. Keep
  the stable authored slot ID as secondary authoring information, followed by
  family, footprint class, support, layer, and required/optional/reserve state.
  For an empty slot, use its authored `physical_role`; expose optional sorted
  `occupant_ids` as known claimants in details and hover text, not as extra
  room labels.
- Show the active scenario and phase from the current immutable room snapshot.
  The placement overlay previews that active state; it does not select,
  advance, or otherwise mutate scenario state.
- Allow pointer dragging and keyboard nudging on the canonical 900x430 room
  plane. Moving a slot translates its position, hit rectangle, and label
  anchor without changing its size, family, or identity. The selected slot can
  also use one of three explicit draw layers—**Behind**, **Standard**, or
  **Front**—and higher layers render above lower layers.
- Keep the placement controls in one fixed, no-scroll panel that fits the
  supported viewport. Family, visibility, layer, and action controls retain
  consistent height, type size, and equal-width grouping rather than resizing
  per label or context.
- Save local slot edits durably, reset individual local edits, and promote all
  local edits into the project placement override file through the existing
  developer placement workflow.
- Scope edits by environment map and layer, including each Punchline layer.
  Scenario selection chooses an exact scenario-instance bank. Shared
  fixed/event/exit geometry remains room-scoped; ordinary scenario geometry is
  isolated beneath that active scenario ID.
- Treat shared markers as locked reference inside an exact scenario. A clearly
  warned **Edit shared room slots** override remains available for deliberate
  corrections and explains that such a move invalidates the base and every
  saved scenario for that room.
- Expose **Save Current Layout** to lock a valid pending drag and snapshot all
  active slots, including hidden families, empty capacity, and runtime
  reserves. Track explicit completion for 20 reachable base layouts and 55
  scenario layouts; the unlayered Punchline parent remains template-only.
- Apply edited slot geometry before the normal slot binder runs so current and
  future objects placed into that slot inherit the new location.
- Surface missing required occupants, incompatible occupants, family
  crossovers, and overlap warnings without silently moving an object into a
  different family. Manual overlap diagnostics compare the selected position
  with every authored marker in the active context, including future capacity
  and runtime reserves; warnings remain advisory for intentional alternatives.
- Do not mutate manifest identities, gameplay selection, scenario state, RNG,
  save economy, or specific spawned objects.

## Exporting placement changes from an EXE

Packaged builds cannot write changes back into their embedded `res://` project
data. After moving and locking slots in either placement mode, use **Export
Placement Report** in the placement overlay. If a move is still pending, the
button locks that move first and then exports the complete effective placement
authority reviewed on that machine.

The game writes `BeatTheHouse_environment_slot_placement_changes.json` to its
writable per-user data directory, opens the file location, and copies the full
path to the clipboard. The schema-3 report is self-contained even when some
coordinates or completion markers came from committed project authority.
Shared room coordinates are keyed beneath
`rooms[map_id].slot_positions`; exact scenario coordinates are keyed beneath
`rooms[map_id].scenario_layouts[scenario_id].slot_positions`. Completion
markers, a 20-base/55-scenario coverage snapshot, build/source identity, and
SHA-256 hashes of both placement authorities are included, so the
report can be merged back into the committed developer placement override
file without flattening scenario geometry. Re-exporting replaces the report
with the current effective snapshot; it does not clear active changes. Family tabs
and empty/reserve visibility controls are presentation-only: full-layout save
and export include hidden families and capacity.

**Save to Project** remains available for a writable source checkout. Use the
export action when running a packaged `.exe`.

## `rw06_10` extension and owner handoff

`rw06_10` extended the existing movement tool across all four families rather
than creating a second editor. The follow-up scenario-instance rework expands
the authoring pass from 21 source maps to 75 explicit contexts: 20 reachable
base layouts plus 55 catalog scenario layouts, including layered and subroom
variants. The unlayered Punchline parent is source geometry, not a playable
manual context.
Empty capacity remains editable through explicit visibility controls and
family tabs keep each room from displaying all lifecycle families at once.

The migrated coordinates preserve prior source geometry wherever possible.
One hundred eighty scenario-instance positions are deterministic provisional placements;
the exhaustive list is in
`docs/plans/environment_scenario_layout_breakdown.md`. Overlap warnings remain
visible in the tool, and the owner will perform the final artistic pass in all
75 contexts. Those visual adjustments do not require another schema or
runtime change.

## Validation

- Settings persistence, F1 shortcut synchronization, and mutual exclusion.
- Context-aware default tab, exclusive family tabs, complete empty/reserve visibility,
  occupant-first labels, stable secondary IDs, active scenario/phase context,
  selection, and family legend.
- Drag/nudge preview and exact durable local reload.
- `fixed`, `event`, `scenario`, and `exit` geometry translation.
- Map/layer/scenario isolation, reset, and promotion.
- Exact scenario-bank composition, shared runtime reserves, and no-catalog
  base-context scenario capacity.
- Full-layout save ordering, hidden-slot capture, completion markers, and
  20/55/75 coverage accounting and exclusion of the template-only parent.
- Future object binding consumes the edited shared or scenario-local slot.
- Slot identity and manifest identity remain stable after movement.
- Required occupancy, family isolation, compatibility, and complete-context
  overlap warnings.
- Existing environment-library, manifest, and fixed-slot checks remain green.

## Verification coverage

- `scripts/tests/environment_slot_placement_mode_check.gd` covers Settings
  persistence, F1 enable/disable synchronization, mutual exclusion, context-aware default presentation,
  single-family/All filters, empty/reserve controls, occupant-first labeling, active
  scenario/phase context, all four slot families, empty-slot editing,
  context-aware overlaps, map/layer scoping, preview restoration, durable
  reload, complete report export, reset, promotion, and future-object binding.
- `scripts/tests/developer_layout_save_ui_check.gd` covers the prominent full-layout action,
  pending-drag lock ordering, and slot-mode-only visibility.
- `scripts/tests/scenario_slot_layout_check.gd` covers catalog scenario isolation, base
  filtering, runtime reserves, no-catalog behavior, and exact layout
  composition.
- `tools/environment_fixed_slot_static_check.py` validates the post-audit raw
  517-position source/template census (175 fixed, 98 event, 211 scenario,
  33 exit), all 21
  maps, the 55 exact scenario banks and their 604 local slots, and reachable
  active snapshots.
- Serialization, environment-library, launcher, and full-project validation
  remain part of the release gate.
- `docs/plans/environment_scenario_layout_breakdown.md` is the current
  auditable handoff for all 75 reachable contexts.
  `docs/plans/environment_slot_consolidation_breakdown.md` remains a raw
  migration/source-template reference only for scenario placement.
