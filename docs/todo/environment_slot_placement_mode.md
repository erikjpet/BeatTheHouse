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
  > Developer.
- Keep object-placement mode and slot-placement mode mutually exclusive.
- Open on the `fixed` family alone and present `fixed`, `event`, `scenario`,
  and `exit` as mutually exclusive family tabs with distinct colors. Switching
  tabs replaces the prior overlay instead of accumulating markers.
- Default to the occupied preview for the current environment snapshot. Hide
  unused optional capacity, and hide slots marked `runtime_reserve: true`,
  until **Empty capacity** or **Runtime reserves** is explicitly enabled.
  Required positions with missing occupants remain visible as diagnostics.
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
  anchor without changing its size, family, or identity.
- Save local slot edits durably, reset individual local edits, and promote all
  local edits into the project placement override file through the existing
  developer placement workflow.
- Scope edits by environment map and layer, including each Punchline layer.
  Scenario selection chooses an exact scenario-instance bank. Shared
  fixed/event/exit geometry remains room-scoped; ordinary scenario geometry is
  isolated beneath that active scenario ID.
- Expose **Save Current Layout** to lock a valid pending drag and snapshot all
  active slots, including hidden families, empty capacity, and runtime
  reserves. Track explicit completion for 20 reachable base layouts and 55
  scenario layouts; the unlayered Punchline parent remains template-only.
- Apply edited slot geometry before the normal slot binder runs so current and
  future objects placed into that slot inherit the new location.
- Surface missing required occupants, incompatible occupants, family
  crossovers, and overlap warnings without silently moving an object into a
  different family. Overlap diagnostics compare the selected position with
  required and currently occupied positions that can coexist in the active
  snapshot, not every empty position from mutually exclusive possibilities.
- Do not mutate manifest identities, gameplay selection, scenario state, RNG,
  save economy, or specific spawned objects.

## Exporting placement changes from an EXE

Packaged builds cannot write changes back into their embedded `res://` project
data. After moving and locking slots in either placement mode, use **Export
Placement Report** in the placement overlay. If a move is still pending, the
button locks that move first and then exports all machine-local slot changes.

The game writes `BeatTheHouse_environment_slot_placement_changes.json` to its
writable per-user data directory, opens the file location, and copies the full
path to the clipboard. The schema-3 report contains only machine-local
changes. Shared room coordinates are keyed beneath
`rooms[map_id].slot_positions`; exact scenario coordinates are keyed beneath
`rooms[map_id].scenario_layouts[scenario_id].slot_positions`. Completion
markers and a 20-base/55-scenario coverage snapshot are included, so the
report can be merged back into the committed developer placement override
file without flattening scenario geometry. Re-exporting replaces the report
with the current local snapshot; it does not clear active changes. Family tabs
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
Empty capacity remains editable through the explicit visibility controls
without crowding the default room preview.

The migrated coordinates preserve prior source geometry wherever possible.
Seven scenario-instance positions are deterministic provisional placements;
the exhaustive list is in
`docs/plans/environment_scenario_layout_breakdown.md`. Overlap warnings remain
visible in the tool, and the owner will perform the final artistic pass in all
75 contexts. Those visual adjustments do not require another schema or
runtime change.

## Validation

- Settings persistence and mutual exclusion.
- Fixed-only default, exclusive family tabs, explicit empty/reserve visibility,
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
- Required occupancy, family isolation, compatibility, and active-context
  overlap warnings.
- Existing environment-library, manifest, and fixed-slot checks remain green.

## Verification coverage

- `environment_slot_placement_mode_check.gd` covers Settings
  persistence and mutual exclusion, fixed-only default presentation, exclusive
  family tabs, empty/reserve controls, occupant-first labeling, active
  scenario/phase context, all four slot families, empty-slot editing,
  context-aware overlaps, map/layer scoping, preview restoration, durable
  reload, complete report export, reset, promotion, and future-object binding.
- `developer_layout_save_ui_check.gd` covers the prominent full-layout action,
  pending-drag lock ordering, and slot-mode-only visibility.
- `scenario_slot_layout_check.gd` covers catalog scenario isolation, base
  filtering, runtime reserves, no-catalog behavior, and exact layout
  composition.
- `environment_fixed_slot_static_check.py` validates the post-audit raw
  579-position source/template census (175 fixed, 147 event, 222 scenario,
  35 exit), all 21
  maps, the 55 exact scenario banks and their 339 local slots, and reachable
  active snapshots.
- Serialization, environment-library, launcher, and full-project validation
  remain part of the release gate.
- `environment_scenario_layout_breakdown.md` is the current auditable handoff
  for all 75 reachable contexts. `environment_slot_consolidation_breakdown.md` remains a
  raw migration/source-template reference only for scenario placement.
