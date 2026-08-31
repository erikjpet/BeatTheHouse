Status: SUPERSEDED — do not claim. The V3 machine rework
(docs/plans/coin_pusher_v3_machine_rework_plan.md, owner round-6 design session
2026-08-17) replaces this work. See the pusherv3_* rows on the board.
Board row: `pusher06_0` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — pusher06_0: Coin Physics Lab (GO/NO-GO gate)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720, `mobile` /
`gl_compatibility` renderer, all game surfaces GDScript-drawn 2D).
Binding design contract:
`docs/plans/0.6_coin_pusher_simulation_plan.md` — read sections 2 and
6 before writing code.

## What this task is

This is a **feasibility laboratory, not a feature.** Its entire
purpose is to answer one question with measurements:

> Can this project simulate a dense, deterministic coin pile within
> its existing frame budgets?

A **NO-GO result is a successful outcome** if it is properly
measured. Do not tune, fake, or narrow the test to reach GO. The
owner needs the truth, not a pass.

Nothing here ships to players. No game registration, no venue
placement, no economy, no save integration. Build it as a tool under
`tools/` with its own harness scene, keep it out of the shipped game,
and do not touch the existing `coin_pusher` implementation at all.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row
   `pusher06_0` to `IN_PROGRESS` with agent + date, append a Work Log
   line, commit the claim. If the row is not `TODO`, stop.
2. Log findings tagged `[pusher06_0]` in the Discovery & Decision Log
   as you measure — the numbers are the deliverable.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` with the **GO or NO-GO verdict and its
   headline numbers** in Notes; fill Execution Record; move this file
   to `docs/todone/`; Work Log entry stating the verdict and what it
   implies for `pusher06_1`.

## Task

### 1. Build the solver prototype

A fixed-timestep, seeded, **fixed-point or integer** 2.5D solver:

- Coins are discs on a plane (`x` lateral, `y` depth) with shallow
  integer stacking layers (`z` ≈ 0–3).
- Two tiers: upper shelf and lower field. Coins pushed off the upper
  shelf fall to the lower field and disturb what is there; coins
  pushed off the lower field fall to tray or gutters.
- A sweeping pusher plate on a physical cycle bulldozes contact.
- Impulse or position-based contact resolution, **fixed iteration
  count** (the count is part of the deterministic contract).
- Spatial-hash broadphase.
- Sleeping: settled coins cost nothing until disturbed; waking
  propagates through contact.
- Settle detection: a deterministic definition of "the pile has come
  to rest."

**No floats anywhere in state that affects outcomes.** No Godot
built-in physics bodies — you are proving an owned solver precisely
because the engine's is not cross-platform deterministic.

### 2. Instrument it

The harness must report, not merely run:

- coin count (total, awake, sleeping) over time
- solver step cost p50/p95 (ms)
- render cost p50/p95 (ms) for a batched draw of the pile
- total frame p95 under active sweep with drops landing
- contact-resolution iteration counts and worst-case contacts
- pathology counters: tunneling events, wedged coins, unresolved
  penetration, energy gain ("explosions"), coins lost out of bounds

### 3. Measure the required scenarios

Run each headless where possible and captured visually once:

1. **Cold pile** — 200 coins settled, machine idle. Idle cost must be
   ~free.
2. **Sweep under load** — full pusher cycle against a settled
   200-coin pile.
3. **Drop cascade** — coin dropped onto a leaning stack; measure the
   disturbance and the settle time.
4. **Level fall** — coins pushed off the upper shelf landing on the
   lower field among existing coins.
5. **Nudge** — a lateral impulse to the whole cabinet with a full
   pile awake (worst realistic case).
6. **Adversarial** — deliberately stack toward instability and force
   a large topple.
7. **Long run** — 2,000+ simulated drops; watch for drift,
   accumulated penetration, and pathology counts.

### 4. Prove determinism

- Identical seed + identical input sequence reproduces the **exact**
  final pile (coin-for-coin position, layer, and rest state) across
  two runs in-process.
- Same, across a **fresh process**.
- Same, on the **Web export** vs Windows. This is the load-bearing
  determinism claim for this project — if it fails, say so plainly.

## GO / NO-GO criteria

Report the verdict against these explicitly, number by number:

**GO requires all of:**

- ≥150 simulated coins with solver step p95 + render p95 leaving the
  living-floor frame p95 ≤ **16.0 ms** on the Windows
  `gl_compatibility` target, with the pusher sweeping and drops
  landing.
- Idle attract state within the animated idle draw budget **with its
  liveness counter present** (a 0.000 idle number without the counter
  is an automatic FAIL in this project).
- Bit-exact determinism across process restarts **and** Windows vs
  Web.
- Zero unrecovered pathologies across the long run (tunneling,
  wedging, explosions may be *detected and deterministically
  corrected*, but never left in a broken state).
- The captured behavior visibly reads as a coin pusher: stacking,
  leaning, toppling, cascades, level falls.

**Partial GO** (report as such, with the number): all criteria met
but only at a lower coin cap. State the highest cap that holds. Per
the plan, lowering the cap is the correct trade — re-abstracting the
pile is not.

**NO-GO:** any determinism failure that cannot be fixed within the
solver, or a coin cap so low the pile cannot read as a pusher. Report
what broke, the measurements, and what you would need.

## Hard rules

- Do not modify the shipped `coin_pusher` implementation, its data,
  or any board/gameplay system. This task is additive and isolated.
- Do not weaken any existing budget or test to make room.
- Do not report GO on tuned or narrowed scenarios; the adversarial
  and long-run cases are mandatory.
- Style: tabs, typed GDScript, sparse comments; measurements and
  captures to `.tmp/`; suite timeout = max(300s, baseline×1.5).

## Gates

- `tools/validate_project.ps1` (the repo must stay green; this is
  additive tooling)
- the lab's own measurement report, complete, in `.tmp/`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report to the owner: **the verdict**, the coin cap that holds, the
frame/solver/render numbers, the determinism results including Web,
the pathology counts, the captures, and your engineering judgment on
what Phase 1 should assume. If the answer is NO-GO, say so directly
and explain what would change it.
