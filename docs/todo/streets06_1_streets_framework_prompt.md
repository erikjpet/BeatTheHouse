Status: TODO
Board row: `streets06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 streets06_1: The Streets Framework (Playable Town)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 3 "The
Streets" (owner-approved at full scope, round 4, **including the heist
Getaway chase variant**). This framework turns crew deliveries, Numbers
routes, lookout holds, and the heist getaway into played gameplay on
one surface. This prompt is self-contained for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row
   `streets06_1` to `IN_PROGRESS` with agent + date, append a Work Log
   line, commit the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[streets06_1]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log line naming
   unblocked rows (crew06_3/6/8).

## Dependencies

`town06_1` + `crew06_1` DONE (town painting; job framework
integration). `town06_3` optional at build time: consume
`sweep_status()` if landed, else leave the patrol-density seam
registered and logged.

## Task

### 1. The board

- A new game-surface: a compact block map generated from the world-map
  edge being traversed (origin node, destination node; block count and
  shape scaled from the edge's distance band; seeded and deterministic
  per run + edge + attempt).
- Grid/intersection movement, turn-based. Board features painted from
  live state at generation:
  - **Patrol cones** — units with sweeping sightlines on seeded
    routes; density scales with local reputation, town heat, and
    sweep proximity (seam).
  - **Light/weather** — rain/fog shrink sightlines (slower, safer);
    blackout blocks are dark (fast, but seeded hazards live in the
    dark); clear payday nights are bright and busy.
  - **Crowds** — Fight Night/Festival crowds block routes but break
    line-of-sight (slow cover).
  - **Props** — stash boxes (bank carried cargo mid-route), shortcut
    alleys (fast, exposed), the snitch's window (pass it and Silas
    learns your business — reputation/rumor write).
- Presentation: stylized top-down blocks consistent with the game's
  art language; view-model + controller; board built once at
  generation, mutations on action only.

### 2. The verbs + run resolution

- Per turn: move (walk = quiet / run = fast+noisy), wait, duck (into
  cover/crowd), stash, ditch (dump cargo — run fails cleanly, evidence
  gone). Getting spotted starts a **pursuit timer** (N turns to reach
  destination or a stash) rather than instant failure; timer expiry =
  caught consequence.
- Cargo rules: carried packages/slips are contraband — caught =
  confiscation + heat + job failure (+ trust hit via the job
  framework); clean fast runs pay speed bonuses.
- Run modes shipped this slice:
  - **Package run** — replace the `crew_favor_delivery` job resolution
    (crew06_1's marked seam) with a played run; keep the event id and
    reward flow compatible.
  - **Multi-stop route** — ordered/free-order stops with a deadline in
    action boundaries (consumed by crew06_3 Numbers).
  - **Hold** — stationary variant: watch a marked zone, call the
    signal in the right window, don't get made (the Lookout absorbed;
    consumed by crew06_6 jobs and heist setups).
  - **Chase** — getaway variant: pursuit starts hot, Rook's car is the
    destination, one-use crew assists (consumed by crew06_8; ship the
    mode behind a flag with a test harness driver).
- Failing or declining a run never soft-locks: the world state
  resolves (job failed, cargo lost) and normal travel completes.

### 3. Integration honesty

- Entering a Streets run is always diegetic and optional per job
  design: normal travel between nodes stays exactly as shipped —
  Streets boards fire only for jobs/routes that declare them.

## Hard rules

- Determinism: board generation, patrol routes, pursuit outcomes —
  seeded, boundary-driven, reproducible (probe-integrated).
- Perf: board is a budgeted game surface; no per-frame allocations;
  idle liveness green on an open board.
- Save compat: mid-run board state serializes (or the run declares
  atomic-with-rollback semantics — choose, document, and test the
  choice; log it on the board).
- Voice: street register throughout.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports.
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Determinism: same seed/edge/attempt → identical board + patrol
   timeline; scripted run reproduces outcome.
2. Painting matrix: rain/fog/blackout/crowds/reputation/sweep-seam
   fixtures each measurably change the board.
3. Package run end-to-end replaces favor delivery with identical
   reward/failure flags (regression vs crew06_1 behavior).
4. Pursuit: spotted → timer → escape via destination and via stash;
   expiry → caught consequences (confiscation, heat, trust).
5. Ditch verb fails cleanly; multi-stop deadline math correct; hold
   window logic correct; chase mode drives under the harness.
6. Save/load per the chosen semantics; no soft-lock in any failure.
7. Visual QA + manual smoke of package + multi-stop + hold runs;
   screenshots to `.tmp/`.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: board generation params, mode APIs (multi-stop/hold/chase
consumers), the save-semantics decision, and gate results. On an
unfixable gate failure: stop at last green commit, set `BLOCKED`,
report verbatim.
