Status: DONE — owner selected fixed production control/nozzle trace; verified 2026-09-01
Board row: `fix06_8` in `docs/todo/README_0_6_board.md`

# fix06_8: deterministic upper-row join evidence

## Original defect

The old Plan 9.4 `upper_row_join` scene restored a production opening but its
single default drop did not land close enough to qualified upper-platform stock
to prove local advancement. The trace correctly stayed red; seed searching and
weakening the adjacency rule were forbidden.

## Owner disposition

The owner selected option 1: authorize one fixed, deterministic production
control/nozzle trace that physically reaches adjacent stock. This is a control
trace, not a favorable-seed search and not a synthetic solver insertion.

## Implementation and verification

The recovered implementation at `3c2d545e` uses the real generated machine,
production action/resolve/drop queue, live-session advancement, authored nozzle
controls, and skill-stop/release path. It performs one fixed priming drop,
aligns the moving face at the rear, engages skill stop, then tracks the paid
proof drop.

Actual-GL verification at 1280×720 passed for Quarter Falls, Jackpot Ridge, and
The Vault Drop:

- a full-period no-input control leaves bodies, ledgers, events, bankroll,
  motor, and story log unchanged;
- the fixed control/nozzle sequence is handled without seed/control searching;
- the paid production drop is accepted and emitted on exact live ticks;
- first support is independently platform-rooted in both event and body view;
- exactly qualified pre-existing adjacent platform stock is named; and
- that exact neighbor advances over the phase-matched stroke.

Evidence: `.tmp/fix06_8_option1_final/captures/manifest.json`, SHA-256
`0239F827C712D3F337A7DD821C2532E53AA1197CED7D72C0EF7AC475B`.
All 27 normal/reduced production scenes also pass visual inspection.

No gameplay tuning, RTP, EV, payout, odds, wager, RNG, schema, migration,
golden, fixture size, or performance budget changed in this evidence closeout.
