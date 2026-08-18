Status: DONE
Board row: `pusherv3_2` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-18
- **Completion/implementation commits:** `7e95c662`, `1bea1ecc`, `85814c06`, `47a45462`, `257e5974`, `5385c37e`, `63f84c1d`, `590eee6d`, `23395d43`, `61f9472c`
- **Verification:** PM line-by-line scope/design review; final combined Systems/UI/Contracts PASS; 10-seed/510-checkpoint two-process determinism PASS (`3549586652`); visual QA PASS with zero warnings; performance PASS (300-body native tick p95 3.072 ms, active DROP p95 15.727 ms, zero full-snapshot fallbacks); Windows/Web native parity exact (`c25d088c...`, input `61c7c14e...`), collection 1/$3 and empty tray.
- **Deviations:** None. Stage-3 cabinet presentation remains intentionally downstream.

# Agent Prompt — pusherv3_2: The Live Machine Loop (continuous play, tray, persistence)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. **Binding design
contract:** `docs/plans/coin_pusher_v3_machine_rework_plan.md` —
read it in full; this stage implements sections 3.5–3.7, 5.1–5.2,
and 8 on top of pusherv3_1's solver. The machine stops being
turn-based here.

## Board protocol

1. Claim row `pusherv3_2` per the board's protocol (IN_PROGRESS,
   agent, date, Work Log, committed claim). If not `TODO`, stop.
2. Log discoveries/deviations tagged `[pusherv3_2]`; owner questions
   to Owner Questions; contradictions with the contract get logged,
   never improvised around.
3. Blocked: row → `BLOCKED` + reason, log, stop.
4. Completion: row → `DONE` + note; Execution Record; archive to
   `docs/todone/`; Work Log: pusherv3_3 unblocked.

## Dependencies

`pusherv3_1` DONE (verify the landed solver API by code).

## Task

### 1. The continuous loop (plan 4.2, 5.1)

- Replace the action-batch game flow in `coin_pusher.gd`: while the
  surface is open, a real-time accumulator advances the solver at
  60 Hz (max 4 catch-up ticks/frame, never skipping). The motor
  strokes the moment the surface opens and never stops while
  present (except skill stop / night lock).
- All inputs quantize to tick indices and append to the session's
  input trace (the determinism artifact): DROP, carriage movement,
  skill stop toggle, nudge, collect.
- **World-time pricing (owner-locked):** DROP costs one game action
  at standard pricing — wire through the existing action/wager seam
  so bankroll deduction, story logging, and turn advancement behave
  exactly like other games' actions. Carriage movement, skill stop,
  and collection are FREE and consume no world time. Nudge keeps its
  shipped semantics.
- Payout crediting is decoupled from actions: coins crossing the
  tray lip at ANY tick append to the tray ledger with their
  provenance (which Ridge multiplier state was armed when they fell
  — plan 5.5), regardless of which insert caused them.

### 2. Entry apparatus framework (plan 3.5, 7)

- Data-driven apparatus from the machine definition: `rail_slot`
  (continuous carriage on a rail, free movement, seeded ±300 release
  jitter) and `hole_set` (fixed release x options). Pegs come from
  data and are already solver colliders (stage 1). Quarter Falls
  ships on `rail_slot` with its 3 pegs NOW; Ridge's plinko board
  arrives in stage 4 but the framework must already support it
  (test with a synthetic 5-row peg definition).

### 3. Skill stop (plan 3.2 — owner-locked free)

- The toggle input drives the solver's rate ramp (24-tick ease
  out/in). No cost, no heat, no tell interaction, always available,
  visibly smooth. State surfaces to the renderer (button lit).

### 4. The physical tray (plan 3.6 — owner-locked)

- Tray ledger + COLLECT interaction: free, transfers value to
  bankroll and prize riders to inventory through the existing result
  seams, story-logged. Money NEVER credits without collection. Tray
  persists across exit/entry.

### 5. Exit settle + settled-state persistence (plan 3.7, 5.2, 8)

- On surface close: input-lock, run to carried-sleep steady state
  (bounded 1200 ticks, chunked across frames — the player sees the
  machine finish its business), write `coin_pusher_settled_v3`
  (quantized positions, phase, carriage, tray, sub-game, alarm
  fields — target ~2 KB), freeze. Absence simulates NOTHING.
- Re-entry: restore snapshot, resume stroking from stored phase.
  Visit 1 ≡ visit 80 (owner-locked).
- Migration: V2 machine states reseed per plan section 8, carrying
  tray_value + sub-game state; log once per machine.
- **Delete the packed presentation-trace subsystem**:
  `coin_pusher_packed_trace_reader.gd`, the packed-trace solver
  paths, and their tests. Live state is the only presentation
  source now (stage 3 renders it; until then the placeholder
  surface from stage 1 shows live positions crudely).

## Hard rules

- Determinism: session = snapshot + input trace + RNG stream →
  identical digest; extend the stage-1 harness with live-loop traces
  (including skill-stop toggles mid-stroke and collects).
- Idle liveness: the stroking motor IS the idle animation; the
  settled machine must run within the animated-idle budget WITH the
  liveness counter (carried-sleep is the mechanism — if idle cost is
  high, fix the sleep discipline, never fake the counter).
- Save compat: schema-versioned; non-pusher saves untouched; the
  world-map snapshot contract holds.
- No coin deletion; ceiling refusal preserved end-to-end (a refused
  DROP refunds its action cost — the player was not served).
- Style: tabs, typed GDScript; `.tmp/` reports; suite timeout =
  max(300s, baseline×1.5).

## QA / Tests

1. Live-loop determinism traces (drop/carriage/stop/collect mixes)
   across runs, processes, Windows/Web.
2. Action pricing: DROP advances world exactly like a slot spin;
   free inputs advance nothing (regression against existing turn
   accounting).
3. Tray: coins landing while idle-stroking after a cascade still
   credit the ledger; collect transfers exactly; no credit without
   collect; prizes reach inventory.
4. Exit settle: forced mid-cascade exit settles within bound and
   snapshots; re-entry digest-identical; tray survives.
5. Skill stop: ramp profile per contract; banked coins push on
   release (behavior contract from stage 1 re-run through the live
   loop).
6. Migration: a V2 save enters cleanly once, carries tray value.
7. Idle liveness + perf gates at settled state and mid-cascade.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- the input-trace export-parity runner (Windows + Web)
- the performance probe at existing budgets

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: the loop architecture, input-trace format, pricing wiring,
snapshot size measured, migration behavior, and gate results. On an
unfixable gate failure: stop at the last green commit, set `BLOCKED`,
report verbatim.
