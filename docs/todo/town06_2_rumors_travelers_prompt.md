Status: TODO
Board row: `town06_2` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 town06_2: Rumors, Travelers, Traveling Reputation

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). The world map
already supports `scouted` node flags that upgrade preview detail
(`docs/plans/world_map_design.md`); the snitch/reputation event cluster
and Dave the bus regular already exist. Binding design contract:
`docs/plans/0.6_living_world_roadmap.md` — Pillar 2 (Rumors, Traveling
NPCs, Consequences). Voice: both voice bibles. This prompt is
self-contained for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `town06_2`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop and pick other work.
2. Log discoveries/deviations tagged `[town06_2]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log line naming
   unblocked rows (town06_3, crew06_3, crew06_9, chain06_1).

## Dependencies

`env06_1` + `town06_1` DONE (verify landed APIs by code). Rumor
truth-sources read `scenario_for_node` and TownState.

## Task

### 1. Rumor system — true statements about elsewhere

- A rumor is generated from **actual state**: another node's seeded
  scenario, an active/incoming town condition, or a registered rumor
  fact (extensible class registry — pusher piles, Numbers whispers,
  and sweep sightings plug in via later prompts; ship the registry
  now with scenario/condition classes live).
- Delivery surfaces (reuse existing systems, no new chrome): staff
  dialogue lines (bartender/clerk/chatty archetypes), a rumor line
  woven into existing events where natural, and Dave's bus lines.
  Surfaces select rumors deterministically from the run RNG stream at
  environment generation.
- **Mechanical payoff**: hearing a scenario/condition rumor about node
  X upgrades X's map preview through the existing `scouted` pipeline
  to a partial "heard" tier (distinct from full scouting): the preview
  names the scenario diegetically ("word is there's a wedding on the
  Queen"). Data: rumor templates in `data/town/rumors.json` with
  per-class template pools, Voice Bible II register per speaker side.
- Rumors are never false in 0.6 (trust in the system first; falsehood
  is future design space — note in data comments).

### 2. Traveling NPC itineraries

- Itinerary system: a seeded, deterministic schedule of node
  assignments over the run for itinerant characters, advancing on
  action boundaries. Data-driven (`data/town/itineraries.json`).
- Ship three travelers:
  - **Dave** (`dave_bus_regular`): itinerary formalizes where he is;
    his existing lines gain where-he's-been references (data only).
  - **Cass Venn** (`cass_rival_counter`): visits casino venues; a
    venue she has left carries a `rival_worked_here` local modifier
    (slightly raised table attention) and a rumor fact; a venue she is
    in seeds her presence for chain06_1 (flag + ambient placement
    only this slice — her chain content arrives there).
  - **Silas Crow** (`silas_snitch`): his current node gates his
    existing snitch events/services; where he drinks is rumorable.
- Read API: `traveler_node(character_id)`, `travelers_at(node_id)` —
  consumed by crew06_9 (itinerary-lie clue) and chain06_1.

### 3. Traveling reputation (edge propagation)

- Generalize the snitch-reputation seed: a small set of typed
  reputation incidents (thrown out, alarm tripped, generous tipper,
  big public win) propagate along map edges at action boundaries with
  per-hop decay (data-tuned). Environments read the local reputation
  value at generation into: door strictness band, staff line
  selection, and a rare reaction event. Legible, small, deterministic
  — town gossip, not a global stat bar. Incident writers: wire the
  ones that exist today (thrown-out/security events, big-win logs);
  leave a registered writer API for pusher alarms and future systems.

## Hard rules

- Truth only: every generated rumor line must trace to a real state
  fact at generation time (assert in debug builds).
- Determinism: rumor selection, itineraries, and propagation are
  seeded and boundary-driven; no wall-clock.
- Perf: propagation is O(edges) per boundary tick worst case; nothing
  per-frame; idle liveness green.
- Save compat: itinerary positions, heard-tier map flags, and
  reputation values serialize; schema-versioned; pre-0.6 saves load
  clean with empty state.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports.
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Rumor about node X's scenario upgrades X's preview to heard-tier;
   preview text matches the actual seeded scenario.
2. Determinism: same seed → same rumors heard at same venues, same
   itineraries, same propagation timeline.
3. Cass's `rival_worked_here` modifier appears exactly at her departed
   nodes and decays per data.
4. Silas's events only fire at his current itinerary node.
5. Reputation incident at node A measurably shifts adjacent node B's
   door strictness next generation, decayed at hop 2+.
6. Save/load round-trips all three subsystems; pre-0.6 save clean.
7. Debug truth-assert never fires across a 20-seed sweep.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: rumor class registry API, itinerary data shape, reputation
incident taxonomy, and gate results. On an unfixable gate failure:
stop at last green commit, set `BLOCKED`, report verbatim.
