Status: DONE
Board row: `pusherv3_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-17
- **Completion/implementation commits:** `a6e36d2f`
- **Verification:** PM scope review and Amendment 6.1 behavior contracts PASS; validation PASS; Smoke, Contracts, Games, Systems, UI, focused Coin Pusher, native Windows/Web parity, 10-seed determinism, and 300-body performance PASS. Native p95 2.951 ms; exact cross-export SHA-256 `7fbb4b1667a2f5d09627659dd7a6908c84bc88e1a6c88f8dd9a1ea8fcc868778`.
- **Deviations:** Amendment 6.1 is the binding geometry correction. The faithful reference implementation exceeded renderer headroom, so the existing cross-export native seam was rebuilt with identical V3 state and behavior. The owner subsequently ruled this row complete; the unrelated baseline Gold Buffalo acceptance assertion remains outside this row's implementation scope.

# Agent Prompt — pusherv3_1: The Machine Physics (solver rebuild + real pusher)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike. **Binding design contract:**
`docs/plans/coin_pusher_v3_machine_rework_plan.md` — the machine is
ALREADY DESIGNED there, with geometry, constants, algorithms in
pseudocode, and behavior contracts. Read it in full before writing
code. Your job is to implement sections 3.1–3.4 and 4 exactly; you
are not designing a machine, you are building the one specified.
Sections 1 and 2 tell you what is rejected and what survives —
respect both lists.

This stage is HEADLESS: solver + machine mechanics + behavior tests.
No UI changes beyond keeping the project compiling (the existing V2
surface may render nonsense against the new state during this stage;
gate it behind a state-schema check so it draws a placeholder rather
than crashing — stages 2–3 replace it).

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row
   `pusherv3_1` to `IN_PROGRESS` with agent + date, append a Work Log
   line, commit the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[pusherv3_1]`; owner-only
   questions under Owner Questions. If the contract contradicts code
   reality, log it — do not improvise a different machine.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log: pusherv3_2
   unblocked.

## Dependencies

None. The V2 solver on `main` is your starting codebase; plan
sections 1/2 define exactly what is deleted vs kept.

## Task

### 1. Delete the rejected mechanics (plan section 1)

Remove from `coin_pusher_solver.gd` and `coin_pusher.gd`:
`_pressurize_full_pile`; the two-phase blade model (`_pusher_face_y`
upper/lower pair, `_hot_apply_pushers`); the cardinal-axis collision
separation and `overlap * 5` injection; the single-support
`lean > 620` topple rule; `phase_accuracy` / `clean_nudge_phase` /
push-strength timing scalars; the lane-grid input surface
(`add_coin(lane, ...)` becomes `add_coin(x, ...)`); the
`ACTION_TICKS = 48` batch as the outer model (keep a
`step_ticks(state, config, n)` entry — stage 2 drives it
continuously; your tests drive it directly).

### 2. Build the machine (plan section 3.1–3.4)

- Geometry constants per section 3.1, read from the machine
  definition (build the section 7 schema now with `quarter_falls`
  defaults; solver consumes the definition, hardcodes nothing).
- Platform kinematics + cosine table + skill-stop rate ramp per
  section 3.2 (the skill-stop INPUT arrives in stage 2; the solver
  supports `rate` ramping now and tests drive it).
- Static colliders: back plate (with the 400 gap over the platform
  top), side walls, gutter mouths, deck, tray lip, pegs from
  apparatus data.
- Entry: `add_coin(state, rng, x, density)` releasing at
  (x ± jitter, DROP_Y, DROP_Z) in free fall.

### 3. Rebuild the contact solver (plan section 4 — implement the pseudocode as written)

- 4.3 spatial hash broadphase, O(n·k), pool = ceiling × 32; the n²
  candidate pool and 256-body hot ceiling are deleted;
  HARD_BODY_CEILING = 600 with slot-refusal semantics (coin returned,
  NEVER deleted).
- 4.4 radial normals via integer `isqrt`, Euclidean overlap,
  positional correction (SLOP 60, BETA 600), restitution E=100
  coin-coin / 0 walls / 250 pegs, Coulomb friction MU 500 / 700 deck
  / 800 platform.
- 4.5 six Gauss-Seidel passes, ascending (low_id, high_id) order.
- 4.6 multi-contact support with the bracket/nestle rule; unstable
  bodies slide via lateral acceleration — no scripted topple.
- 4.7 platform carry with friction slip cap + back-plate blocking.
  The ratchet must EMERGE from these two rules; writing special-case
  ratchet code is a defect.
- 4.8 sleeping, contact islands, carried-sleep.
- 4.9 invariants as debug assertions: no energy gain, settle
  guarantee, conservation reconciliation.

### 4. Behavior contracts (plan section 9.2 — these are the acceptance)

Implement every listed contract as a headless foundation test:
ratchet walk, face push of a 3-row mass, the landing-skill fork
(same x, two phases → deck vs platform landing), **nestle** (the
crystallization regression), **no-lattice** (300-coin settle,
nearest-neighbor angle histogram must not spike at 0/90°),
skill-stop bank-and-release, tray fall, gutter loss, ceiling
refusal, energy invariant, settle guarantee, conservation. Plus the
input-trace determinism harness (9.1): rebuild the export-parity
runner from action-batch replay to tick-stamped input-trace replay,
prove Windows-vs-Web digest equality.

## Hard rules

- The contract's numbers are the starting truth. If a value proves
  physically wrong in testing (e.g., a friction that dead-stops the
  mass), tune it, document the change and reason on the board — but
  the STRUCTURE (radial normals, iteration, bracket support, carry +
  plate ratchet) is not negotiable.
- Determinism: fixed pass counts, fixed orders, integer math only in
  outcome-affecting state; identical trace → identical digest,
  Windows and Web.
- No coin deletion ever; refusal only.
- Perf target now, not later: 300 coins mid-cascade must solve a
  tick within budget headroom for stage 3's renderer (measure and
  report solver tick p95; islands + carried-sleep are your levers).
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports;
  suite timeout = max(300s, baseline×1.5).

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` (the V2 pusher tests you delete
  are replaced by the section 9.2 contracts — never weaken, replace)
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- the rebuilt export-parity runner, Windows + Web

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: what was deleted, the solver architecture as landed, every
behavior-contract result, solver tick p95 at 300 coins, any tuned
constants with reasons, and the parity evidence. On an unfixable gate
failure: stop at the last green commit, set `BLOCKED`, report
verbatim.
