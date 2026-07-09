# Execution Record

- Completion date: 2026-07-09.
- Claim commit: `a9df75d`.
- Implementation/archive commit: this commit (local only; not pushed).
- Beach root cause: confirmed `beach` had no fixed world-map anchor, so it fell through to the generic tier/kind hash placement. Repro seed `PLAYTEST-BEACH-DUP-000` generated a direct `beach`/`delta_queen` edge priced at `8` blocks, with beach at `{x=0.33, y=0.53}` and `delta_queen` at `{x=0.75, y=0.21}`.
- Duplicate-object root cause: confirmed identity dedup only handled rectangle collisions/object ids, not semantic identity. The owner-facing pull-tab duplicate source was the Pull Tabs module exposing two room-side hooks with the same visible identity: `game_hook:pull_tabs:ticket_redeemer` and `dialogue:pull_tab_clerk` / hook id `pull_tab_clerk_dialogue`. The new audit also exposed an authored shop-clerk collision in `corner_store`: `event:late_shift_discount` and `event:chatty_clerk`.
- Fix summary: `beach` now anchors beside `delta_queen`, the beach/delta pair is re-clamped after spread, and a direct edge is guaranteed at `distance_blocks == 1`. Unique identity is now data-shaped through `unique_object_class`, `unique_object_priority`, and `allow_duplicate_unique_class`; Pull Tabs clerk hooks and shop clerk events declare their classes; generated layout assignment and live interactable objects filter duplicate classes deterministically, keeping the higher-priority object.
- Permanent guards: `foundation_check.gd` sweeps 50 world-map seeds for beach/delta adjacency and checks pull-tab unique-clerk layout in `bar`, `gas_station_casino`, and `jazz_club`. `tools/environment_generation_audit.gd` now fails if any generated map lacks the 1-block direct beach/delta edge or any generated layout contains duplicate visible unique-class objects.
- Verification:
  - `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1` - PASS.
  - `powershell -ExecutionPolicy Bypass -File tools\environment_generation_audit.ps1 -RequireGodot -Runs 20 -Visits 6 -SeedPrefix V04-BEACHFIX -Output res://.tmp/environment_generation_audit/beachfix_report.json -Report res://.tmp/environment_generation_audit/beachfix_report.md` - initially reproduced duplicate failures, then PASS after fixes.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300` - PASS (`.tmp/test_reports/20260709_000201_smoke/summary.json`).
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite contracts -TimeoutSec 300` - PASS (`.tmp/test_reports/20260709_000304_smoke/summary.json`).
  - `powershell -ExecutionPolicy Bypass -File tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 5 -SeedPrefix V04-WORLDFIX` - PASS, combined hash `3493911849`.
  - `powershell -ExecutionPolicy Bypass -File tools\environment_generation_audit.ps1 -RequireGodot -SeedPrefix V04-WORLDFIX` - PASS, `598` environment samples and `499` travel transitions.
- Save/load note: existing saved maps with old beach positions still load without normalization crashes; new generated maps receive the fixed beach anchor/edge. Existing environments with duplicate objects are filtered at the live interactable layer when viewed.
- Release packaging note: built 0.4.0 packages remain stale until the queued repackage task runs.

# Agent Prompt - Playtest Fixes: Beach Anchors Beside The Riverboat + No Duplicate Unique Objects

Priority: playtest blocker for the 0.4 release (runs before the repackage
step).

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). Owner playtest found two world/environment
generation defects.

## Defect 1 — The beach spawns anywhere; it must always sit 1 block from the riverboat casino

- **Observed cause (verify):** `scripts/core/world_map.gd`'s per-archetype
  anchor table (~:695-712) has fixed positions for every named venue —
  `delta_queen` at (0.76, 0.20) — but **`beach` has no entry**, so it falls
  through to the generic tier/kind fallback with a hash-based y
  (:713-719) and lands wherever the seed says.
- **Required behavior:** the beach is the dockside next to the riverboat.
  On every generated map, the beach node:
  1. is positioned adjacent to `delta_queen` (add its anchor relative to
     the delta_queen anchor, and make sure `_spread_positions` cannot push
     the pair apart — exempt or re-clamp the pairing after spreading);
  2. has a direct edge to `delta_queen` whose computed `distance_blocks`
     is exactly 1, so travel between them always prices as 1 block (check
     how edges and `_path_distance_blocks_prepared` derive blocks and make
     the adjacency hold in graph terms, not just visually).
- Keep it data-shaped where possible (an `anchor_near: "delta_queen"`
  style field on the archetype/map config beats another hardcoded case if
  the structure supports it cheaply; otherwise extend the existing anchor
  table and note why).

## Defect 2 — Duplicate unique objects in one environment (two pull-tab clerks observed)

- **Investigate the real source before fixing.** The placement code has
  rect-collision dedup (`environment_instance.gd:672,687`) but apparently
  no **identity** dedup. Likely candidates: two content sources placing
  the same prop (a game's room-side clerk plus an event's
  `clerk_talk`/`clerk_counter` environment_prop), or object-list selection
  with replacement. Reproduce with seeds (the owner hit a room with two
  pull-tab clerks), name the actual colliding sources in the execution
  record.
- **Required behavior:** identity-carrying objects — clerks, shopkeepers,
  dealers, any interactable NPC or named prop — are **unique per
  environment** unless the archetype data explicitly declares a multiple
  allowance. Implement one registry in the environment build path that
  tracks placed object identities and resolves conflicts deterministically
  (second requester gets an alternative prop/spot or is dropped, seeded —
  never wall-clock, never order-of-iteration dependent across runs of the
  same seed).
- Ambient repeatables (crates, plants, decorative filler) stay allowed —
  the uniqueness class must be data-driven (a field on the prop/object
  definition), not a hardcoded id list.

## Permanent guards (extend, both defects)

1. Environment generation audit / foundation check over many seeds
   (follow the existing generation audit's seed-sweep pattern): assert
   (a) every generated world map has the beach adjacent to delta_queen at
   1 distance block with a direct edge, and (b) no environment instance
   contains two objects of the same unique-class identity.
2. These run in the suites the generation audit already belongs to — no
   new opt-in scripts that future changes can skip.

## Verification

1. Manual: several fresh runs — map shows beach beside the riverboat every
   time; enter pull-tab venues across seeds and see exactly one clerk.
2. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
3. `tools\check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
   and `-FoundationSuite contracts -TimeoutSec 300` (with the new guards
   wired in), plus the environment generation audit wrapper.
4. `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 5
   -SeedPrefix V04-WORLDFIX` — placement changes must stay seed-stable.
5. Note in the execution record that the 0.4.0 packages remain stale until
   the repackage step. Archive to docs/todone/ with the execution record;
   update QUEUE.md and commit per the queue lifecycle.

## Hard constraints

1. Seeded determinism throughout; same seed → same map and same rooms.
2. Do not break existing saved runs: an in-flight save with the old beach
   position/duplicate objects must still load (normalize, don't crash;
   regeneration on next run is acceptable and should be stated).
3. Match house style: tabs, typed GDScript, sparse constraint comments.
