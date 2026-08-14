Status: TODO
Board row: `town06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 town06_1: Town State Core (One Town, One Night)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Data-driven content
in `data/*.json`; run logic in `scripts/core/run_state.gd`; travel and
the world map per `docs/plans/world_map_design.md`. Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — read Pillar 2 and
Guardrails first. This prompt is self-contained for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `town06_1`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop and pick other work.
2. Log discoveries/deviations in the Discovery & Decision Log (tagged
   `[town06_1]`); owner-only questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log line naming
   unblocked rows (town06_2/3, push06_2, streets06_1).

## Dependencies

None (Wave A). The Police Sweep is NOT this task (town06_3); this task
builds the framework the sweep plugs into.

## Task

### 1. Town state service

- Add a run-level `TownState` module (own script under `scripts/core/`,
  owned/serialized by `RunState`): generated once at run start from the
  run RNG, evolving only at turn/action boundaries.
- Components:
  - **Weather track**: an ordered, seeded schedule of weather states
    (`clear`, `rain`, `fog`, `storm`) over the run's turn horizon, with
    dwell ranges per state. Data-driven in a new
    `data/town/conditions.json`.
  - **Calendar**: seeded day-type tags (`payday`, `midweek`) on a
    repeating cycle; the current day type is queryable.
  - **Happenings framework**: 0–2 seeded citywide happenings per run,
    each a data definition with id, duration window, and modifier
    hooks. Ship `fight_night`, `festival_weekend`, and
    `rolling_blackout` as data (blackout generalizes the intent of the
    existing `lights_out` event — leave that event untouched; the
    happening only sets town flags this slice).
- Public read API (pure, allocation-free per call):
  `weather_now()`, `day_type()`, `active_happenings()`,
  `happening_active(id)`, plus a snapshot dictionary for UI/save.

### 2. Read hooks (wired, minimal)

- **Scenario weighting**: expose town-state weight modifiers that
  env06_1's selection consumes if present (e.g. storm boosts
  weather-tagged scenarios). Define the seam even if env06_1 lands in
  parallel — coordinate via the board if the API shape needs agreement.
- **Travel**: weather adjusts travel risk/cost band presentation and
  the risk roll inputs (small, data-tuned multipliers; document values
  in `conditions.json`).
- **Music**: weather + happenings expose a modifier profile the music
  system may consume (ambience/volume/texture deltas); wire at the
  seam where archetype `music_profile` is read.
- **Crowd/stakes**: payday exposes an economic modifier (stake
  floor/ceiling nudges, crowd density up) consumed at environment
  generation; midweek the inverse. Applied at generation time only.
- One ambient HUD/status line surfaces the current weather + day type
  diegetically (reuse existing status-line idioms; no new chrome).

### 3. Persistence + determinism

- Full serialization in run saves; schema-versioned; pre-0.6 saves
  load with a freshly generated (seed-derived) town state and a log
  note — never a crash.
- Same seed + config → identical weather schedule, calendar, and
  happening selection every run.

## Hard rules

- Determinism: all schedules seeded at run start; evolution only at
  action/turn boundaries; no wall-clock anywhere.
- Perf: state advance is O(1) per boundary; read API allocation-free;
  nothing per-frame; idle liveness gate stays green.
- Do not change any shipped event/scenario behavior beyond the wired
  hooks above; hooks must no-op cleanly when data provides no modifier.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports only.
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Determinism: two generations on one seed produce identical
   weather/calendar/happening schedules (probe-integrated).
2. Boundary-only evolution: advancing N actions yields the same state
   regardless of real elapsed time.
3. Travel risk/cost reflects weather per the data multipliers;
   clear-weather behavior matches pre-change baseline (regression).
4. Payday modifiers apply at generation and disappear on midweek.
5. Save/load round-trips town state exactly; pre-0.6 save loads clean.
6. Content check validates `conditions.json` (ids, ranges, modifier
   keys restricted to documented set).

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: TownState API surface, hook seams wired, data schema, and gate
results. On an unfixable gate failure: stop at last green commit, set
`BLOCKED`, report verbatim.
