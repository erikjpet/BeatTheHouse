Status: TODO
Board row: `env06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 env06_1: The Tonight System (Scenario Engine)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Data-driven content
lives in `data/*.json`; run logic in `scripts/core/run_state.gd`;
environments generate via `EnvironmentInstance.from_archetype` from
`data/environments/archetypes.json`; the world map stores per-node
environment snapshots for revisits (contract:
`docs/plans/world_map_design.md`). Binding design contract:
`docs/plans/0.6_living_world_roadmap.md` — read the Vision, Pillar 1,
and Guardrails sections first. This prompt is self-contained for rules
and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `env06_1`
   to `IN_PROGRESS` with your agent name + date, append a Work Log
   line, and commit the claim. If the row is not `TODO`, stop — pick
   other claimable work.
2. Log scope-affecting discoveries/deviations in the board's Discovery
   & Decision Log (dated, tagged `[env06_1]`). Owner-only questions go
   under Owner Questions; do not guess on owner-locked design.
3. If blocked: row → `BLOCKED` + one-line reason, log it, stop.
4. On completion (all gates green): row → `DONE` with date + one-line
   verification note; fill this file's Execution Record; move this
   file to `docs/todone/`; append a Work Log line naming unblocked
   rows (env06_2/3/4, town06_2/3, craps06_2, push06_1).

## Dependencies

None (Wave A). This is the foundation everything in Pillar 1 hangs on —
API stability matters more than feature count here.

## Task

### 1. Scenario schema + data

- Create `data/environments/scenarios.json`: scenario definitions keyed
  by archetype id. Each scenario: `id`, `archetype_id`, `display_name`,
  `weight`, optional `phases` (ordered list with per-phase mutation
  deltas and `advance_after_actions` counts), and a `mutations` block
  limited to the axes in the roadmap's Pillar 1 table: patron/staff
  set, event pool add/remove, economic profile overrides, game modifier
  hooks, service add/remove, music profile override, presentation
  (palette tint, lighting key, crowd density, signage line), exclusive
  opportunity (event/offer/game id), security overrides (strictness
  band, cheat-risk window, machine alarm tolerance band), and hook
  flags (recruitment/chain/rumor anchors).
- Ship **2 placeholder scenarios for `bar` and 1 for `corner_store`**
  as engine-proof content (env06_2/3 author the real launch cut — keep
  these minimal and clearly marked `"placeholder": true` so content
  prompts replace them).
- Extend the content foundation check
  (`scripts/tests/foundation/check_core_content.gd` family) to
  validate: every scenario references a real archetype, real event ids,
  real service ids; weights positive; phase counts sane; mutation keys
  restricted to the allowed axes (unknown keys fail the check).

### 2. Selection + lifecycle

- On a node's **first visit**, select exactly one scenario from that
  archetype's pool using the run RNG stream (seeded, deterministic per
  seed + challenge config). Implement per-run repeat protection: a
  "recently seen" penalty multiplier so repeated archetype visits and
  low-variety pools avoid immediate repeats.
- Challenge config may pin a scenario id or exclude ids per archetype
  (extend the existing challenge config surface minimally).
- **Phases advance at action boundaries only** (the same boundary the
  event/turn system already uses — never wall-clock). Phase advancement
  applies that phase's mutation delta on top of the base scenario.
- Archetypes with no scenarios defined behave byte-identically to
  today (empty-pool = no-op path; this is the compatibility guarantee
  for all venues until env06_2/3 land).

### 3. Application + persistence

- Apply the selected scenario's mutations inside
  `EnvironmentInstance.from_archetype` (and the per-game
  `generate_environment_state` flow where game modifiers apply) at
  **generation time** — mutations are computed once per
  generation/phase-advance, never per frame.
- Persist scenario id + phase index + phase action counter in the world
  node's environment snapshot; revisits restore exactly (world-map
  revisit contract stays authoritative). Save/load round-trips the
  full scenario state; schema-version the addition and migrate
  pre-0.6 saves (missing scenario state = legacy no-scenario node).
- Expose a read API for later systems (rumors, sweep, recruitment):
  `scenario_for_node(node_id)` returning id/phase/display data without
  regenerating anything.

### 4. Tooling

- Extend `tools/tutorial_seed_audit.gd`-style seed tooling (or add
  `tools/scenario_seed_audit.gd`) to print, for a given seed, every
  node's selected scenario — needed by QA and by env06_2/3 authors.

## Hard rules

- Determinism: selection and phases derive from run RNG + action
  boundaries; two runs on the same seed + config produce identical
  scenario assignments and phase timings.
- Perf: zero per-frame work added; mutation application at
  generation/boundary only; idle-draw numbers must keep the liveness
  counter-gate green (never accept 0.000 idle without liveness).
- Save compat: schema-versioned; pre-0.6 saves load with legacy
  no-scenario behavior.
- Style: tabs, typed GDScript, sparse comments; reports to `.tmp/`
  only. Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Same seed → identical scenario selection + phase schedule across two
   full generations (determinism probe covers this).
2. Empty-pool archetype generates byte-identical environment state to a
   pre-change baseline capture (compatibility regression).
3. Phase advances exactly on the Nth action boundary; save/load
   mid-phase restores counter and phase.
4. Repeat protection: a forced 10-visit sequence on one archetype never
   selects the same scenario twice consecutively when pool size ≥ 3.
5. Content check fails on: bad archetype ref, bad event id, unknown
   mutation key (add fixture-based negative tests).
6. Node revisit restores the stored scenario unchanged.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete the Board protocol step 4, and
report: the scenario schema, selection API surface, snapshot fields
added, and gate results. On an unfixable gate failure: stop at last
green commit, set `BLOCKED`, report verbatim.
