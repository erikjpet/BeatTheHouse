Status: IN PROGRESS
Board row: `fix06_8` in `docs/todo/README_0_6_board.md`

# Agent Prompt — fix06_8: deterministic upper-row join evidence

Repair only the stale `upper_row_join` scene in
`tools/coin_pusher_plan94_feel_capture.gd`. Plan 9.4 requires a production drop
to land beside existing upper stock and that local row to advance. The inherited
fixture instead creates an obsolete 70-body state, inserts and advances through
direct solver calls, accepts an ambiguous support root, and scans every body for
movement. `pusherv3_10` now ships deterministic 150/150/154-body production
openings that remain parked until a committed production drop starts the motor.

Use the exact production-entry settled snapshot, production action/resolve/drop
queue and live-session advancement paths. Add a one-period no-input control that
fails unless the opening remains parked with unchanged bodies, ledgers and
events. For the committed drop, require both the first-support event and an
independent body view to be platform-rooted, identify only adjacent pre-existing
platform-rooted coin neighbors, and compare those exact neighbors at first
support and one complete stroke later so platform phase cannot create a false
advance. Preserve a readable three-stage strip plus the idle control and record
all predicates in a fail-closed manifest for Quarter Falls, Jackpot Ridge and
Vault Drop.

Evidence tooling only. Do not change gameplay, solver, live-session, renderer,
machine data, tuning, RTP, EV, payout, odds, wager math, RNG, schema, migration,
goldens, budgets or owner artifacts. Do not seed-search for a green trace. If a
fixed production trace has an identical parked baseline, an accepted emitted
drop, platform-rooted first support beside qualified local upper stock, but no
qualified neighbor advances over the phase-matched cycle, preserve the red and
route a product defect instead of weakening the fixture.

Run static validation, the focused and full foundation gates, determinism,
actual-GL 1280x720 capture with visual inspection, and the standard performance
probe. Supply and hash the ignored native addon before any engine timing. Retain
every result and obtain independent implementation/evidence review before land.
