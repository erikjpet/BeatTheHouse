Status: TODO
Board row: `pusher06_4` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — pusher06_4: Venue Integration & Persistence at Scale

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike. Binding design contracts:
`docs/plans/0.6_coin_pusher_simulation_plan.md` and the Coin Pusher
section of `docs/plans/0.6_living_world_roadmap.md`.

## What this task is

The three machines play. This task makes them **part of the living
town** rather than a good minigame the world knows nothing about, and
proves the persistence story holds at real run scale.

The bar: a player should be able to leave a loaded machine, travel
across town, survive a police sweep, come back hours later, and find
*their pile* exactly as they left it — and the town should have been
talking about it while they were gone.

## Board protocol

1. Before work: set row `pusher06_4` to `IN_PROGRESS` with agent +
   date, append a Work Log line, commit the claim. If not `TODO`,
   stop.
2. Log discoveries/deviations tagged `[pusher06_4]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move to `docs/todone/`; Work Log entry closing the coin
   pusher rebuild.

## Dependencies

`pusher06_1`, `pusher06_2`, `pusher06_3` DONE. Wave A/B town systems
(scenarios, town state, rumors, police sweep) are on `main` — verify
their landed APIs by code.

## Task

### 1. Presence in the venue

- Machines occupy their venue's environment as real, approachable
  objects with the existing interaction idioms: visible in the room,
  walk-up interaction, and a legible transition into and out of the
  machine surface. Leaving returns the player to the room with the
  room's state intact.
- The machine's visible state reads from across the room where cheap:
  a locked-down cabinet after an alarm looks locked down; a fat Vault
  Drop meter is visible; a machine someone else is using is occupied.
- Attendant/staff presence reacts to the tell ladder and to a tripped
  alarm using existing NPC/ambient systems — no bespoke actor
  framework.

### 2. Persistence at run scale

- Pile state persists per machine per node across: leaving the
  machine, leaving the venue, traveling, save/load, and returning
  much later. Prove it with a long multi-venue run, not a unit
  fixture.
- **Snapshot budget is a real constraint.** Multiple machines across
  multiple venues each holding hundreds of coins must not bloat run
  saves unacceptably. Measure the per-machine snapshot size, report
  it, and if it is too large, quantize harder or cap stored coins
  with a deterministic, documented reconstruction rule — never store
  a lie about the pile the player built.
- Scenario reset flags ("someone else played it") replace a pile
  deterministically; the Vault Drop's meter persists independently of
  the pile.

### 3. Living-town integration

- **Rumors**: pusher-pile state and fat Vault meters are registered
  rumor facts, truth-sourced (the town may only say true things —
  the rumor system's existing discipline).
- **Police sweep**: the swept-window loosens alarm tolerance one
  band, as the shipped design specifies; a sweep arriving while a
  player is mid-session behaves sensibly (no soft-lock, no lost
  pile).
- **Scenarios**: Graveyard Shift lax alarms and maintenance access,
  Trucker Convoy occupying the good machine, and any other landed
  scenario access effects apply at generation.
- **Heat and reputation**: a tripped alarm writes its reputation
  incident through the existing traveling-reputation writer, so the
  town remembers it the way it remembers other incidents.

### 4. Playability guard

- Every machine interaction satisfies the `fix06_1` class guard: an
  icon that does nothing is the worst possible playtest experience
  and this project has shipped that bug once already.
- No soft-locks: alarm lockdown, occupied machines, mid-session
  sweeps, travel locks, and save/load mid-session all resolve
  cleanly.

### 5. Handoff readiness

- Extend the playability/reachability evidence the `playtest06_1`
  handoff will need: seeds that reach each of the three variations
  quickly, and a capture of each machine in its venue.

## Hard rules

- Authoritative simulation and the alarm contract (no forced exit)
  unchanged.
- Determinism absolute across all integration paths, Windows and Web.
- Budgets unchanged, including with a machine visible in a populated
  room: frame p95 ≤ 16.0 ms, surface draw p95 ≤ 5.0 ms, idle within
  budget with its liveness counter.
- Save-size regression is a gate, not a footnote — report the
  numbers.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports;
  suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Long multi-venue run: load a pile, leave, travel, return; pile
   exact. Repeat across save/load and across a police sweep.
2. Save-size measurement with several loaded machines; report
   per-machine snapshot bytes and total run-save delta.
3. Scenario effects: lax/strict alarm bands, busy machine, reset
   flag replacement.
4. Rumor truth: every emitted pusher rumor traces to real state.
5. Sweep interaction mid-session; swept-window tolerance shift and
   restoration.
6. Alarm writes its reputation incident and node memory; staff react
   on the next visit.
7. `fix06_1` class guard green including all machine interactions.
8. Perf with a machine present in a populated room.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`
- the performance probe at existing budgets

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: venue presence approach, measured snapshot sizes and the
save-size delta, town-integration wiring, reachability seeds and
captures for the handoff, and gate results. Close with your honest
assessment of whether the coin pusher now reads as a real machine
inside a living town. On an unfixable gate failure: stop at the last
green commit, set `BLOCKED`, report verbatim.
