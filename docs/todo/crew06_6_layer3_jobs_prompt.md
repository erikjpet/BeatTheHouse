Status: TODO
Board row: `crew06_6` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 crew06_6: Layer 3 Build-Out + Jobs Content

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). env06_4 shipped
the Punchline with L3 as a shell; crew06_1 shipped the job framework;
streets06_1 shipped playable runs; crew06_5 shipped recruitment.
Binding design contract: `docs/plans/0.6_living_world_roadmap.md` —
Pillar 3 "Layer 3", "Jobs", and the Practice Rig. This prompt is
self-contained for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `crew06_6`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[crew06_6]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log: crew06_8
   planning table ready.

## Dependencies

`crew06_1`, `env06_4`, `streets06_1`, `crew06_5` DONE. Coordinate with
crew06_2 (poker table lives here) and crew06_3 (Numbers desk) via the
board — whichever lands later integrates with the earlier one's
furniture; verify by code.

## Task

### 1. The back room, furnished

- Build out L3 as a real environment layer: layout spots for the
  **job board**, **planning table** (inert until crew06_8 — shows
  "when the score is real" flavor), **Numbers desk** (crew06_3
  integration or its minimal stand-in), **back-room poker table**
  (crew06_2 integration), **Practice Rig**, and crew residency spots.
- **Residency rotation**: which met members are physically present
  rotates on a seeded schedule (itineraries via town06_2 where they
  exist; otherwise a local seeded rotation). Present members carry
  their contextual lines and offer their jobs in person.
- L3 services: Rook's ride (a free/discounted travel service with
  data-limited uses per rank — routes through normal travel, no
  Streets board), Mags' bench (item repair/upgrade seam —
  content06_1 fills the catalog; ship the service surface).

### 2. The job board

- The board surfaces available jobs from all met members
  (`data/crew/jobs.json` — extend the schema as needed, never fork
  it): package runs (Streets), Numbers routes (if crew06_3 landed),
  lookout holds (Streets hold mode), **stake-horse plays** (new here:
  gamble crew money at a named venue/game with a target; hit target =
  split + trust; bust = trust hit and, if the player shrugs it off
  through the offered choice beat, the `stake_horse_loss_shrugged`
  grievance), and **collections** (new here: a Knuckles two-beat
  encounter chain — the friendly-face visit, then the choice of how
  hard to press; outcomes tune trust vs heat vs cash).
- Author a launch set of **10–14 job definitions** across the five
  kinds and all seven members, rank-gated per `data/crew/crew.json`,
  with expiries in action boundaries and rewards per the crew06_1
  schema. Every job must be declinable without grievance (grievances
  come from *accepting and failing/shrugging*, per the taxonomy).

### 3. The Practice Rig

- A layer-3 interactable minigame: dice-setting practice (throw
  timing windows against a target distribution readout, diegetic
  "Mags' rig"). Sessions grant `craps_setting_trained` progress
  (shared progress pool with craps06_2's street route — verify the
  landed grant API and use it; never a second flag).
- Short, replayable, deterministic; no stakes, no heat.

## Hard rules

- L1/L2 behavior untouched (regression via env06_4's tests).
- All job content routes through the crew06_1 framework — no bespoke
  job state.
- Grievance writers added here (`stake_horse_loss_shrugged`,
  collections-related if the design note in the roadmap taxonomy
  applies) go through the taxonomy — no new kinds without a board
  Discovery entry.
- Determinism/perf/save/voice rules as other prompts (street
  register; residency seeded; idle liveness green in L3).
- Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Residency rotation seeded + deterministic; present members offer,
   absent members don't.
2. Each of the 5 job kinds end-to-end: accept → play/resolve → reward
   or documented failure path; decline never writes grievance.
3. Stake-horse shrug choice writes exactly its grievance; repayment
   choice doesn't.
4. Rook's ride consumes uses, respects rank caps, and cannot bypass
   travel locks.
5. Practice Rig grants shared training progress; craps cheat gate
   opens from either source (with craps06_2 evidence).
6. Save/load round-trips board offers, residency, rig progress.
7. Visual QA + manual smoke of the furnished L3; screenshots to
   `.tmp/`.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: L3 layout, job catalog (ids × kinds × members), rig tuning,
and gate results. On an unfixable gate failure: stop at last green
commit, set `BLOCKED`, report verbatim.
