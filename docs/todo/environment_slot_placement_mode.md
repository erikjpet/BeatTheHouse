# Environment slot placement mode

Status: COMPLETE ON FEATURE BRANCH (not merged to `main`)
Branch: `codex/environment-slot-placement-mode`

## Goal

Add a developer-only authoring mode that displays and moves the reusable
placement slots for the current environment. It must edit stable room slots,
not the particular object instances occupying those slots.

## Product contract

- Expose a separate **Environment slot placement mode** toggle under Settings
  > Developer.
- Keep object-placement mode and slot-placement mode mutually exclusive.
- Display every authored base, stage, and exit slot in a dedicated overlay,
  including currently empty slots.
- Identify slots by their stable authored slot IDs and show their kind,
  placement class, support, and current occupancy where available.
- Allow pointer dragging and keyboard nudging on the canonical 900x430 room
  plane. Moving a slot translates its position, hit rectangle, and label
  anchor without changing its size or identity.
- Save local slot edits durably, reset individual local edits, and promote all
  local edits into the project placement override file through the existing
  developer placement workflow.
- Scope edits by environment archetype and layer. Scenario selection may alter
  visibility/reservations, but it must not create scenario-instance slot IDs.
- Apply edited slot geometry before the normal slot binder runs so current and
  future objects placed into that slot inherit the new location.
- Do not mutate scenario state, RNG, save games, or specific spawned objects.

## Validation

- Settings persistence and mutual exclusion.
- Empty-slot visibility and selection.
- Drag/nudge preview and exact durable local reload.
- Base/stage/exit slot geometry translation.
- Layer isolation, reset, and promotion.
- Future object binding consumes the edited reusable slot.
- Existing environment-library and fixed-slot checks remain green.

## Verification evidence

- `environment_slot_placement_mode_check.gd`: PASS. Covers Settings
  persistence and mutual exclusion, all three slot kinds, empty-slot editing,
  environment/layer scoping, preview restoration, durable reload, reset,
  promotion, and future-object binding.
- `environment_test_mode_check.gd`: PASS across 18 environments and 55
  scenarios.
- `environment_fixed_slot_static_check.py`: PASS across 21 authored maps with
  zero active or complete overflow.
- `health06_1_serialization_contract.gd`: PASS.
- `check_game_library_launchers.gd`: PASS for all 11 debug game launchers.
- `validate_project.ps1 -Quiet`: PASS.
- The older `developer_placement_mode_check.gd` retains its pre-existing 11
  expectation failures around machine-local object overrides; this branch does
  not add failures to that known baseline.
