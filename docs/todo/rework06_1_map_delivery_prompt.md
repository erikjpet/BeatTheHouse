Status: TODO
Board row: `rework06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 rework06_1: Delivery Runs on the Real Map (replaces the Streets board)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — read the section
**"Delivery Runs — courier work on the real map (round-5 rework)"**
in Pillar 3 before anything else. World-map contract:
`docs/plans/world_map_design.md`.

## Why this task exists

`streets06_1` shipped a standalone tactical board: a synthetic grid of
`{x, y, kind: building/street}` cells generated per map edge
(`scripts/core/streets_run_model.gd`). The owner played it and
rejected it: **it does not work, and it reads as a disconnected menu
rather than part of the game.** The abstract geography is the problem,
not the tuning.

The replacement is not a new minigame. **Delivery becomes a variation
of the world map the player already uses.** Every destination is a
real map node with a real generatable environment; every movement goes
through the travel system that already exists.

This is a *deletion and re-derivation*, not a patch. Do not preserve
the synthetic board because it exists.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row
   `rework06_1` to `IN_PROGRESS` with agent + date, append a Work Log
   line, commit the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[rework06_1]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log line naming
   affected consumers (crew06_3 Numbers routes, crew06_6 jobs,
   crew06_8 getaway).

## Dependencies

`town06_1`, `town06_2`, `town06_3`, `crew06_1` are DONE on `main`.
`streets06_1` is DONE on `main` and is what you are replacing.
`crew06_3` (Numbers) consumes the old multi-stop API on the Wave C
integration branch — **coordinate before you break it**: read its
landed consumption, and either land your API first and re-point
Numbers, or agree the new contract with the PM and re-point in the
same integration. Record the chosen order on the board.

## Task

### 1. Remove the synthetic board

- Delete the abstract grid geography: cell painting, building/street
  synthesis, patrol-cone cells, per-board props. Remove
  `streets_run_model.gd`'s board generation and its UI overlay
  surface, plus their tests and visual-QA entries.
- Keep and re-home what is genuinely reusable and *not* geographic:
  cargo/contraband state, deadlines counted in action boundaries, job
  linkage and reward/failure routing, and the resolved-run world
  effects. These move into the new courier model.
- The public consumer API (`streets_begin_multi_stop`,
  `streets_begin_hold`, `streets_begin_chase`, `streets_apply_action`,
  `streets_snapshot`, `streets_has_active_run`) is replaced by a
  delivery-run API of your design. Name it for what it now is
  (`delivery_*` or similar). Update every consumer; leave no shim
  that pretends the old board still exists.

### 2. Delivery jobs target real nodes

- A delivery job declares one or more **targets**, each a real
  world-map node id resolved at offer time from the run's actual
  world graph. Selection rules:
  - prefer nodes the player has **discovered/visited**;
  - may include a node **not yet traveled to**, revealed as a target
    with its real map identity (this is a feature: jobs pull the
    player into unseen town);
  - **never** a node whose environment cannot be generated, never a
    synthetic place, never an unreachable node. Assert this at offer
    time and prove it with a wide seed sweep.
- Deadlines count action boundaries (never wall-clock). Targets and
  deadline serialize into the run save.

### 3. The map becomes the courier board

Extend the **existing world-map overlay** with a courier presentation
layer that appears only while a delivery job is active:

- delivery targets marked with remaining deadline;
- carried cargo shown as contraband;
- a per-edge **carrier risk read** derived from state the town
  already models — Police Sweep position/heading (respect
  `sweep_status` capability gating: unearned intel must not leak),
  weather, local reputation, scenario law-pressure. Present it as
  route information the player weighs, not as a solved answer.

No new full-screen surface. This is the map the player already knows,
carrying more truth while they are working.

### 4. Movement is normal travel

- All courier movement resolves through the **existing travel
  pipeline** (`FoundationMain._travel_to` and the RunState route
  status/risk path): normal cost, time, risk roll, and environment
  generation. There is no parallel movement system and no separate
  turn economy.
- Carrying cargo modulates *existing* systems: sweep encounters can
  confiscate it, heat responds to what is carried, venue security
  reacts on arrival. Add these through the seams those systems
  already expose.

### 5. The drop is an in-venue beat

- Arriving at a target generates that environment normally (tonight's
  scenario running) and exposes a hand-off interaction through the
  existing event/interaction systems — a real beat in a real room,
  never a menu confirmation.
- Completing all targets before the deadline resolves the job through
  the crew06_1 job framework with its rewards; missing it fails the
  job through the same framework (trust cost, grievance only where
  the taxonomy already says so).

### 6. The four modes

- **Package run** — one target, one deadline.
- **Multi-stop route** — several targets before a deadline; ordering
  is the strategy. This is what Numbers collection routes consume.
- **Hold** — remain in a named venue across a window and satisfy a
  condition without drawing attention; resolves against existing
  suspicion/security systems in that real venue.
- **Getaway** — the heist exit: pressured map movement with elevated
  pursuit and one-use crew assists, expressed through travel. Ship
  behind a flag with a test-harness driver for crew06_8.

### 7. Compatibility

- **Ordinary travel is untouched** when no delivery job is active —
  prove byte-identical behavior against a pre-change baseline.
- The shipped `crew_favor_delivery` reward/failure contracts survive
  exactly (`streets06_1` preserved +22/+4 success and +9 failure —
  verify the landed values and keep them).
- Save migration: in-flight old-board runs must load without crashing
  (resolve them to a clean non-blocking state and log it); new
  delivery state is schema-versioned.

## Hard rules

- **No synthetic geography anywhere.** Every place is a real map node
  with a generatable environment. If you find yourself inventing a
  location, you have misread this prompt.
- Determinism: target selection, risk reads, and outcomes are seeded
  and advance on action boundaries; identical seed + inputs reproduce
  exactly.
- Never soft-lock: an impossible/expired job always resolves and
  normal travel always completes. Prove worst cases (target
  travel-locked, sweep camped on the only route, deadline expiring
  mid-travel).
- Perf: no per-frame allocation in the courier map layer; idle
  liveness counter-gate green with the overlay open.
- Voice: street register (both voice bibles).
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports;
  suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Property sweep (≥20 seeds): every offered target is a real,
   reachable node with a generatable environment; zero synthetic
   places; undiscovered targets carry real map identity.
2. All four modes end-to-end, including every failure path.
3. `crew_favor_delivery` reward/failure regression exact.
4. Ordinary travel byte-identical with no active job.
5. Sweep interaction: confiscation on encounter while carrying; risk
   read never leaks ungated sweep intel.
6. No-soft-lock worst cases above.
7. Save/load mid-job; old-board save migration clean.
8. Visual QA of the courier map layer + one full in-venue drop
   capture to `.tmp/`.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: the new delivery API, target-selection rules and their proof,
the courier map layer, consumer re-pointing (Numbers/jobs/getaway),
migration behavior, and gate results. On an unfixable gate failure:
stop at the last green commit, set `BLOCKED`, report verbatim.
