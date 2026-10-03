# Environment slot placement mode

Status: COMPLETE. The original placement-mode work and the `rw06_10`
four-family extension are implemented. Final artistic repositioning is an
owner handoff, not unfinished tool or slot-contract work.

## Goal

Provide a developer-only authoring mode that displays and moves the reusable
placement slots for the current environment. The mode edits stable room slots,
not the particular object instances occupying those slots.

## Current slot-family contract

The movement tool uses the same four lifecycle families as the environment
manifest and binder:

- `fixed.*` for guaranteed environment objects and permanent capacity;
- `event.*` for optional ambient-event objects unrelated to the active
  scenario;
- `scenario.*` for reusable positions occupied by active scenario actors,
  props, items, and controls;
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
  Scenario selection may alter visibility, reservations, and occupancy, but it
  must not create scenario-instance slot IDs.
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
path to the clipboard. The report contains only local changes, keyed by stable
environment/layer and `fixed.*`, `event.*`, `scenario.*`, or `exit.*` slot ID.
It uses the same schema-v2 `rooms` structure as the committed developer
placement override file, so the report can be provided directly for merging
back into the source layout. Re-exporting replaces the report with the current
set of local changes; it does not clear or modify those active changes. Family
tabs and the empty/reserve visibility controls are presentation-only: export
always includes every locked machine-local slot change, including currently
hidden families and capacity.

**Save to Project** remains available for a writable source checkout. Use the
export action when running a packaged `.exe`.

## `rw06_10` extension and owner handoff

`rw06_10` extended the existing movement tool across all four families rather
than creating a second editor. The repository-wide migration covers all 21
placement maps, including layered and subroom variants. Empty reusable
capacity remains editable through the explicit visibility controls without
crowding the default room preview.

The migrated coordinates preserve the prior layout wherever that was possible.
Where a formerly shared slot had to become multiple simultaneous slots, the
new positions are deterministic in-room provisional placements. Overlap
warnings remain visible in the tool, and the owner will perform the final
artistic repositioning in every environment; those visual adjustments do not
require another schema or runtime change.

## Validation

- Settings persistence and mutual exclusion.
- Fixed-only default, exclusive family tabs, explicit empty/reserve visibility,
  occupant-first labels, stable secondary IDs, active scenario/phase context,
  selection, and family legend.
- Drag/nudge preview and exact durable local reload.
- `fixed`, `event`, `scenario`, and `exit` geometry translation.
- Map/layer isolation, reset, and promotion.
- Future object binding consumes the edited reusable slot.
- Slot identity and manifest identity remain stable after movement.
- Required occupancy, family isolation, compatibility, and active-context
  overlap warnings.
- Existing environment-library, manifest, and fixed-slot checks remain green.

## Verification evidence

- `environment_slot_placement_mode_check.gd`: PASS. Covers Settings
  persistence and mutual exclusion, fixed-only default presentation, exclusive
  family tabs, empty/reserve controls, occupant-first labeling, active
  scenario/phase context, all four slot families, empty-slot editing,
  context-aware overlaps, map/layer scoping, preview restoration, durable
  reload, complete report export, reset, promotion, and future-object binding.
- `environment_test_mode_check.gd`: PASS across 18 environments and 55
  scenarios.
- `environment_fixed_slot_static_check.py`: PASS across 659 slots (214 fixed,
  147 event, 222 scenario, 76 exit), 21 authored maps, all four families, 18
  archetypes, 55 scenarios, and 767 active snapshots.
- `health06_1_serialization_contract.gd`: PASS.
- `check_game_library_launchers.gd`: PASS for all 11 debug game launchers.
- `validate_project.ps1 -Quiet`: PASS.
- Audit runtime matrix: all 38 Godot/performance stages PASS, including 440
  scenario finalizations, 18,000 reachable states, and 4,024 distinct layouts.
- `environment_slot_consolidation_breakdown.md`: audited placement handoff for
  every one of the 659 slot IDs across all 21 maps and all 55 scenarios;
  canonical placement SHA-256
  `E18795A6665699AA1C8C6A1B451E66C10357F496C1FA059848EA7B3598FCC5D0`.
