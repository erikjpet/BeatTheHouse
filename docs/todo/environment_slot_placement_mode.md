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
- Display every authored `fixed`, `event`, `scenario`, and `exit` slot in a
  dedicated overlay, including currently empty capacity slots.
- Allow the four families to be shown or hidden independently, with distinct
  colors and a clear legend.
- Identify slots by their stable authored slot IDs and show their family,
  footprint class, support, layer, current occupancy, and required/optional
  occupancy where available.
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
  different family.
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
set of local changes; it does not clear or modify those active changes.

**Save to Project** remains available for a writable source checkout. Use the
export action when running a packaged `.exe`.

## `rw06_10` extension and owner handoff

`rw06_10` extended the existing movement tool across all four families rather
than creating a second editor. The repository-wide migration covers all 21
placement maps, including layered and subroom variants, and empty reusable
capacity remains visible and editable.

The migrated coordinates preserve the prior layout wherever that was possible.
Where a formerly shared slot had to become multiple simultaneous slots, the
new positions are deterministic in-room provisional placements. Overlap
warnings remain visible in the tool, and the owner will perform the final
artistic repositioning in every environment; those visual adjustments do not
require another schema or runtime change.

## Validation

- Settings persistence and mutual exclusion.
- Empty-slot visibility, per-family filtering, selection, and family legend.
- Drag/nudge preview and exact durable local reload.
- `fixed`, `event`, `scenario`, and `exit` geometry translation.
- Map/layer isolation, reset, and promotion.
- Future object binding consumes the edited reusable slot.
- Slot identity and manifest identity remain stable after movement.
- Required occupancy, family isolation, compatibility, and overlap warnings.
- Existing environment-library, manifest, and fixed-slot checks remain green.

## Verification evidence

- `environment_slot_placement_mode_check.gd`: PASS. Covers Settings
  persistence and mutual exclusion, all four slot families, empty-slot
  editing, map/layer scoping, preview restoration, durable reload, reset,
  promotion, and future-object binding.
- `environment_test_mode_check.gd`: PASS across 18 environments and 55
  scenarios.
- `environment_fixed_slot_static_check.py`: PASS across 722 slots (225 fixed,
  149 event, 270 scenario, 78 exit), 21 authored maps, all four families, 18
  archetypes, 55 scenarios, and 767 active snapshots.
- `health06_1_serialization_contract.gd`: PASS.
- `check_game_library_launchers.gd`: PASS for all 11 debug game launchers.
- `validate_project.ps1 -Quiet`: PASS.
- Audit runtime matrix: all 38 Godot/performance stages PASS, including 440
  scenario finalizations, 18,000 reachable states, and 4,024 distinct layouts.
- Fresh 21-map slot-marker handoff:
  `.tmp/rw06_1/visual_evidence/rw06_10_final_20260929_07/slot_markers/`;
  manifest SHA-256
  `3EC1694A0615E840E276E93EB8E65B879873769DC57BB116F32C525B08AC6E0A` and
  contact-sheet SHA-256
  `46B42AF2064C149AAAE8DB8EBE1062DCEB418E13AA685654FD62A8C96914A33E`.
