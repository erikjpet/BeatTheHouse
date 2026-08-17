Status: TODO
Board row: `env06_5` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — env06_5: Scenario Backlog (wave 2 authoring)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike. The Tonight system shipped in `env06_1`; the launch
cut of 42 scenarios shipped in `env06_2`/`env06_3` (both archived in
`docs/todone/`). Binding design contract:
`docs/plans/0.6_living_world_roadmap.md` — Pillar 1's scenario
catalog. Voice: `docs/plans/0.5_voice_bible.md` +
`docs/plans/0.6_voice_bible_world_register.md`.

## Why this task exists

The owner chose a quality-first launch cut of 3–4 scenarios per
venue, leaving the rest of the authored catalog as backlog. 0.6's
central promise is that *every visit feels different*; more variety
per venue is the most direct way to strengthen the pillar the
upcoming playtest is meant to judge. The engine is proven and the
launch cut is your template — this is authoring, not engineering.

## Board protocol

1. Before work: set row `env06_5` to `IN_PROGRESS` with agent + date,
   append a Work Log line, commit the claim. If not `TODO`, stop.
2. Log discoveries/deviations tagged `[env06_5]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`.

## Concurrency — read carefully

This runs alongside the crew wave and the Wave E content pass, which
also write `data/events/events.json`. **Ownership rule, binding:**

- You own `data/environments/scenarios.json` outright.
- In `events.json` you may ONLY add events whose ids begin
  `scenario_` and which are referenced by a scenario you author.
  Touch nothing else in that file — no edits to existing events, no
  reordering, no reformatting of unrelated entries.
- Merge current `main` before your gates run and re-verify after.
- If you need a change outside that ownership, log it as a Discovery
  and route it to the owning task instead of doing it.

## Task

Author the backlog scenarios from the roadmap catalog (entries not
marked ★). Target the full set below; if any single scenario cannot
meet the completeness bar, drop it and say so rather than shipping a
thin one:

- **corner_store**: Inventory Night
- **back_alley**: Nothing Moving
- **motel**: Wedding Overflow
- **bar**: Darts League Night, Live Band, Dead Tuesday
- **gas_station_casino**: Road Crew Payday, Storm Shelter
- **The Punchline (casino layer)**: New Muscle, Raid Jitters
- **jazz_club**: Union Trouble
- **kitty_cat_lounge**: Bachelorette Storm
- **delta_queen**: Captain's Invitational

Completeness bar per scenario is identical to the launch cut — match
what `env06_2`/`env06_3` actually landed (read their data as the
house style, code reality wins over this list):

1. Mutations across **at least three axes** (patrons, events,
   economy/stakes, services, security, presentation, music override),
   tuned so each scenario **plays** differently rather than merely
   reading differently.
2. **1–3 exclusive events**, pooled only via the scenario, never
   added to a base archetype pool. Reuse existing event mechanics —
   no new event-engine features.
3. **Presentation**: palette tint, crowd density, signage line;
   music override where the night demands it. No new art assets — if
   a scenario truly needs art, log it as a Discovery rather than
   blocking.
4. **Phases** where the design implies an arc (Darts League: league
   play → decider; Storm Shelter: gathering → waiting out → clearing;
   Captain's Invitational: entry → rounds → final). At most 3.
5. **Hook flags** only where the roadmap assigns them. Do not invent
   recruitment or heist anchors — those are owned by the crew wave.

Notes on specific entries:

- *Raid Jitters* and *New Muscle* attach to the Punchline's **casino
  layer** (`layer_id`), per the layer model env06_4 landed.
- *Storm Shelter* is weather-sensitive: use the town-weight tag seam
  so it up-weights in rain/storm rather than hardcoding.
- *Captain's Invitational* is a tournament night on the Delta Queen.
  Keep it within existing table-game mechanics; it must not require
  new game features, and it must not collide with heist Plan B's
  whale anchors.

## Hard rules

- Data/content only. Generic engine gaps get a Discovery entry, never
  a scenario-special-cased code path.
- Every scenario passes the env06_1 content check; extend validation
  only where new referenced ids need it.
- Tutorial neutrality preserved: pinned tutorial configs must keep
  selecting their neutral scenario — prove it with the existing
  tutorial regression.
- Determinism: seeded selection, phases on action boundaries.
- Voice register per both bibles; street venues speak blunt.
- Style: tabs; `.tmp/` reports; suite timeout = max(300s,
  baseline×1.5).

## QA / Tests

1. Content check green over the full expanded catalog.
2. Seed-audit sweep (20 seeds) reaches every new scenario; no starved
   weights and no crowding-out of the launch cut.
3. Phase arcs advance correctly; save/load mid-phase.
4. Punchline layer scoping correct for the two casino-layer entries.
5. Tutorial regression unchanged.
6. Manual smoke with captures to `.tmp/` for three of the new
   scenarios across different venues.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: scenarios added with their axes and exclusive events, the new
per-venue totals, any entry you dropped and why, and gate results. On
an unfixable gate failure: stop at the last green commit, set
`BLOCKED`, report verbatim.
