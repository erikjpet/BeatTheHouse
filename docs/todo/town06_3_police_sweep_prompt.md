Status: TODO
Board row: `town06_3` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 town06_3: The Police Sweep (Full Feature)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 2 "The
Police Sweep" (owner-locked: ships fully fleshed in 0.6.0). The sweep
is a first-class system, not an event. This prompt is self-contained
for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `town06_3`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop and pick other work.
2. Log discoveries/deviations tagged `[town06_3]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log line noting
   streets06_1/crew06_3 full-scope unblocked.

## Dependencies

`town06_1` (happenings framework) + `town06_2` (rumor registry, map
heard-tier) DONE — verify landed APIs by code.

## Task

### 1. The track

- The sweep is a happenings-framework citizen: seeded per run (not
  every run — data-tuned probability), spawning a sweep unit that
  walks a deterministic path across the world graph, one node per N
  action boundaries (data-tuned dwell). Path preference: tier-1 →
  tier-2 order with seeded variation; **never enters `grand_casino`**;
  may revisit; despawns after a seeded duration.
- All parameters in `data/town/conditions.json` (extend town06_1's
  file): spawn chance, dwell range, duration, encounter tuning.

### 2. Legibility (the sweep is read, not shown)

- **Rumors**: register a sweep rumor class with town06_2 (recent and
  next-heading sightings, truth-sourced from the actual track).
- **Scenario pressure**: nodes adjacent to the sweep's current
  position up-weight law-flavored scenarios/mutations at generation
  (*Cruiser Parked*, *Serial-Check Day*, strict security bands) via
  the env06_1 weight-modifier seam.
- **Personal sighting**: being in a node when the sweep is there (or
  adjacent with a sighting event) places a map marker with staleness
  (marker shows last-known node + how many turns ago; it does not
  live-update).
- **Crew intel seam**: expose `sweep_status()` (current node, heading)
  behind a capability flag that crew06_5 wires to Switch at
  `associate+` — API only this slice.

### 3. Being caught in it

- Sweep entering the player's node triggers the sweep encounter:
  severity scales with heat band, carried contraband (cheat-flagged
  items; the item schema's risk flags exist — extend with a
  `contraband` marker where missing; Numbers slips get theirs in
  crew06_3), and active street debts. Outcome ladder (data-tuned):
  pass-over → shakedown fee → contraband confiscation → short
  travel-lock. **Never an instant run-kill**; every outcome is a
  costed continue.
- Encounter presentation reuses the existing unavoidable-event
  pattern (`the_collector` family is the model).

### 4. The wake + interplay

- Swept-window: a node the sweep just left carries a timed looseness
  window (security strictness −1 band, cheat windows open, pusher
  alarm tolerance +1 band via the security-override channel).
- Punchline: the sweep sees only layer 1 unless town heat exceeds a
  data threshold (then a tense L2 near-miss event fires — content
  included).
- Seams left registered but inert until their owners land: Knuckles
  stash (crew06_5/6), Numbers pause (crew06_3), Streets patrol
  density (streets06_1).

## Hard rules

- Determinism: spawn, path, dwell, encounters — all seeded, all
  boundary-driven; the map marker's staleness counts boundaries.
- The sweep must be worth reading: swept-window and adjacency pressure
  are real, tested effects, not flavor.
- Never soft-lock: travel-locks from encounters expire
  deterministically; a sweep camping the only affordable route must
  still leave an escape (prove with a worst-case test).
- Perf: track advance O(1) per boundary; idle liveness green.
- Save compat: full sweep state serializes; pre-0.6 saves load
  sweep-free.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports.
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Determinism: same seed → identical spawn/path/dwell/encounter
   timeline.
2. Grand Casino never appears on any generated path (property test
   over a seed sweep).
3. Encounter ladder scales with heat/contraband/debt fixtures; no
   outcome ends the run.
4. Swept-window measurably loosens security + alarm tolerance for its
   window, then restores.
5. Adjacent-node scenario weighting shifts and restores.
6. Punchline: sweep at the node with low town heat = L1 pass; above
   threshold = L2 near-miss event.
7. Worst-case escape test: player travel-locked + sweep adjacent still
   has a legal path forward.
8. Save/load mid-sweep restores track + marker staleness.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: track parameters, encounter ladder tuning, seams registered,
and gate results. On an unfixable gate failure: stop at last green
commit, set `BLOCKED`, report verbatim.
