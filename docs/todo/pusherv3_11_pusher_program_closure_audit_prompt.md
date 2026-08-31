Status: BLOCKED — requires pusherv3_10 acceptance, fix06_8 owner disposition, and fix06_13 formal closeout
Board row: `pusherv3_11` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 pusherv3_11: Coin Pusher V3 Program Closure Audit

Copy everything below this line into the agent.

---

This is the independent closure audit for the coin pusher V3 machine program in
`D:\Projects\Beat-The-House`. It depends on `pusherv3_10`. You did not implement
any V3 row; if you did, you are the wrong agent for this row.

Read `docs/plans/coin_pusher_v3_machine_rework_plan.md`,
`docs/plans/0.6_coin_pusher_simulation_plan.md`, the coin pusher section of
`docs/plans/0.6_living_world_roadmap.md` (Pillar 4, including the universal
nudge system), every archived `pusherv3_*` prompt, the board rows and their
notes, and the shipped implementation:
`scripts/games/coin_pusher.gd`, `scripts/games/coin_pusher/coin_pusher_solver.gd`,
`coin_pusher_solver_api.gd`, `coin_pusher_live_session.gd`,
`coin_pusher_renderer.gd`, `jackpot_ridge.gd`, `vault_drop.gd`, the export parity
runner, and `scripts/tests/foundation/check_coin_pusher.gd`.

## Why this row exists

`pusherv3_4` was accepted as "coin pusher closure". Six further rows were then
appended — contact piles and visible exits, plinko bounce and entry boards,
played-in opening stock, coin scale and edge ramp, contact bed and opaque edge,
and opening plinko nozzles and stack physics — each responding to an owner
observation and each verified on its own. No row has ever audited the V3 machine
as a whole program against its binding contracts.

That is the specific risk this audit addresses: ten individually-correct rows can
still add up to a machine that has drifted from its plan, accumulated dead code
from superseded models, or quietly lost a Pillar 4 requirement that no single row
owned.

## 1. Contract fidelity

- Map every requirement in the V3 machine rework plan and its amendments —
  including Amendment 6.1's corrected `FACE_EXTENDED_Y` / `FACE_RETRACTED_Y`
  geometry and Amendment 6.2's rear-fed entry rule — to the shipped
  implementation. Report any requirement that is unimplemented, partially
  implemented, or implemented differently from the amended contract.
- Map roadmap Pillar 4 the same way, with particular attention to the universal
  nudge system: force, aim and timing; the tell ladder; alarm leading to machine
  lockdown, a heat spike and node memory; and no forced exit. The nudge and alarm
  vocabulary is present in the shipped solver — confirm it is complete, reachable
  in play, and behaving as the roadmap describes, not merely present as symbols.
- Confirm all three variations — Quarter Falls, Jackpot Ridge, The Vault Drop —
  ship their documented mechanics, including the owner rulings that a banked lock
  puck preserves the armed multiplier against expiry for one full 240-tick stroke
  without steering the motor, and that Vault Drop's physical coin-to-tray EV band
  is `[0.72, 0.94]` reported separately from vault option value.

## 2. Economics and determinism on the exact tree

- Re-run the 200k-per-machine physical drop harness for all three machines and
  confirm each lands inside its documented band: Quarter Falls `[0.72, 0.94]`,
  Jackpot Ridge `[0.70, 1.08]`, Vault Drop `[0.72, 0.94]` physical with option
  value reported separately.
- Re-run 10-seed determinism and the exact Windows/Web replay parity harness.
  Parity must be exact, not close.
- Confirm money conservation across drops, nudges, alarms, lockdowns, collection,
  exit-settle and save-restore.

## 3. Persistence, lifecycle and performance

- Verify the separation of transient live state from settled persistence that
  `pusherv3_2` was returned for: an autosave during play must not run a long
  settle or freeze, and post-drop motion must continue correctly.
- Verify pile persistence, node memory and alarm memory survive save, exit,
  travel and revisit, with no replayed payout and no lost stock.
- Verify shipped-cap performance on native and Web, per-action budgets, and the
  idle-liveness counter-gate. An idle draw cost of 0.000 is a failure.

## 4. Code health after ten rows

- Identify dead code, superseded models, unused constants, orphaned fixtures and
  duplicated logic left behind by the succession of reworks. Report them; do not
  delete product code inside an audit branch unless it is provably unreferenced,
  and say explicitly which category each removal falls into.
- Report any place where a later row's fix worked around an earlier row's design
  rather than correcting it, since that is where the next regression will come
  from.

## 5. Board reconciliation

- State which parts of `pusher06_2`'s presentation and audio contract still bind
  after V3, and which were superseded. The board currently leaves this ambiguous.
- Confirm the superseded `pusher06_0/1/3/4` rows are correctly retired — coordinate
  with `board06_1` rather than editing the board structure yourself.
- List every owner ruling recorded for the pusher and confirm each is implemented
  as ruled.

## 6. Deliverable

A closure report under `docs/plans/` mapping every V3 contract requirement and
Pillar 4 requirement to code, tests, harness figures and captures, with a verdict
per requirement, the full economics and parity table, the code-health findings,
and the board reconciliation.

Findings are routed as `fix06_*` rows or returned to the owning row. Do not fix
gameplay inside this audit branch — an audit that rewrites the thing it is
auditing has destroyed its own evidence.

This row remains TODO or BLOCKED if any documented EV band is missed, if parity
is not exact, if a Pillar 4 requirement is unimplemented, or if an owner ruling
is not honored in code. On pass, archive this prompt and record the report path
and exact commit on the board.
