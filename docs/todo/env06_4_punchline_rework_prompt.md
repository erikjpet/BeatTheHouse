Status: TODO
Board row: `env06_4` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 env06_4: The Punchline (3-Layer Venue Rework)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). This task reworks
the `small_underground_casino` archetype
(`data/environments/archetypes.json`) into **The Punchline**: a
three-layer venue — street-level comedy club (public cover), hidden
casino (the existing underground content), hidden crew back room
(shell only this slice; crew06_6 furnishes it). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 3 "The
Punchline" section. World-map contract:
`docs/plans/world_map_design.md` (node identity and the guaranteed
`small_underground_casino → grand_casino` shortcut edge must survive).
This prompt is self-contained for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `env06_4`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop and pick other work.
2. Log discoveries/deviations tagged `[env06_4]`; owner-only questions
   under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log line naming
   unblocked rows (env06_3 Punchline block, crew06_2, crew06_6).

## Dependencies

`env06_1` DONE (layers interact with scenario scoping — scenarios
declare which layer they attach to; add that field to the schema if
env06_1 didn't). Verify landed code.

## Task

### 1. Layer model

- One map node, one archetype id (keep `small_underground_casino` as
  the internal id for route/save compatibility; display identity
  becomes The Punchline — name data-driven). Three layers inside the
  environment: `club` (L1), `casino` (L2), `back_room` (L3).
- Layer navigation is in-environment (a transition object per layer
  boundary using existing environment-object interaction idioms — no
  world-map travel, no travel cost). Current layer persists in the
  node snapshot and saves.
- Per-layer: own background asset slot, own layout spots, own music
  profile (club: tinny stage sound; casino: the existing underground
  hush; back room: low and private — reuse/extend the music-profile
  system per layer), own game/event/service pools. Art: reuse existing
  underground art for L2; L1/L3 may ship with palette-shifted or
  placeholder backgrounds registered through the art manifest — log
  final-art needs as a Discovery for the owner.

### 2. Access gating

- **L1 is public**: anyone enters from the map; the venue presents as
  a comedy club (name, preview lines, map description all say comedy
  club — the casino is never advertised).
- **L1 → L2 discovery seam**: promote the existing `side_door` event
  into the canonical discovery: password/bribe/regular's-nod/crew
  standing paths (data-driven conditions; at least two ways in per
  run). Once discovered, the node snapshot remembers — re-entry is
  one click. Players who never find it experience a slightly odd
  comedy club, and that is fine.
- **L2 → L3**: locked behind crew rank (`made`, via crew06_1 API) or
  a Rook escort flag; until crew06_6 lands, L3 is a minimal shell
  (door + one line of Rook flavor when accessible; log the shell state
  on the board).
- Existing underground behavior (games, stakes, cheat looseness,
  events) moves to L2 **byte-identically** except for the entry path.

### 3. Compatibility + migration

- Route ids, unlock requirements, availability windows, and the
  guaranteed shortcut edge to `grand_casino` are unchanged (the
  shortcut departs from L2 diegetically; mechanically from the node).
- Save migration: pre-0.6 saves whose current room or snapshots
  reference `small_underground_casino` load into L2 with the seam
  already discovered (they were already inside). Schema-version the
  snapshot addition.
- Travel/story logs and `environment_history` keep working; entries
  gain a layer field where cheap.

### 4. Ambient identity

- L1 ships a minimal ambient stage bit (rotating one-line terrible
  jokes from a data list, Voice Bible II register — the street
  *performing*), two-drink-minimum service reusing the house-drink
  service pattern, and comedy-club patron dressing. Keep it lean —
  env06_3 authors the real L1 scenarios on top.

## Hard rules

- The shortcut edge and every shipped route/unlock survive: prove with
  the existing travel/content foundation checks plus a targeted test.
- L2 gameplay regression-identical to the pre-rework underground
  (fixture comparison where feasible).
- No wall-clock; discovery conditions are event/flag/action-boundary
  based; deterministic under seed.
- Perf: layer transition rebuilds surfaces at transition time only;
  idle liveness green on all three layers.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports.
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Map shows comedy-club identity; casino never leaks into previews
   before discovery.
2. Both discovery paths open L2; snapshot remembers; save/load
   mid-layer restores layer + discovery state.
3. Shortcut edge to `grand_casino` present and traversable
   (world-graph test).
4. L2 behavior matches pre-rework underground baseline (games, stakes,
   event pool regression).
5. Pre-0.6 save referencing the underground loads into L2 discovered.
6. L3 door: denied politely below `made`; opens with rank/escort flag.
7. Visual QA + manual smoke across all layers; screenshots to `.tmp/`.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: layer model API, discovery seam conditions, migration proof,
and gate results. On an unfixable gate failure: stop at last green
commit, set `BLOCKED`, report verbatim.
