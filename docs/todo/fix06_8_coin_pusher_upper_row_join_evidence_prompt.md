Status: PARKED — OWNER DECISION REQUIRED
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

## Parking disposition — 2026-08-26

The independently accepted static head remains
`be15d864fbd64eca5029bf76aa9bafd15cd350ee`. Its actual-GL qualification was
red only on `upper_row_join`. An exact production-session diagnostic proved that
Quarter Falls, Jackpot Ridge and Vault Drop all committed and emitted a paid
drop with platform-rooted event/view evidence, exact ticks and matched phase,
but their nearest eligible pre-existing platform coins were respectively
8.04k, 12.43k and 17.36k units away against a 4.70k combined contact width.
No trace had an adjacent qualified neighbor, so none could prove local advance.
The inherited `gutter_visible_fall` scenes passed for all three machines.

The row is parked until the owner authorizes either (a) one deterministic
production control/nozzle trace that physically lands beside existing upper
stock, or (b) a product/design change that makes such a landing possible. Seed
or control searching for a passing outcome and weakening the adjacency rule
remain forbidden.

Preserved ignored evidence is under
`.tmp/fix06_8_exact_production_diag/`: manifest SHA-256
`4ACA94A1B52C22DDB02EC50DF4D1E014A06D4F8AD0861730D9E5FFC77D00393A`;
diagnostic patch SHA-256
`104CC9EA3D2622BE90DE2CF796CD66C5139CDDCF84EA3B649DA314F5652EBA84`;
Quarter Falls idle/join PNGs
`B6A6F9D991211E7CE2215DD2AA16F2C75F194B4E1B516B80CF70831B600FC5CB` /
`9521802E3A07F6C36B0B2F6330FA6F8746F8F355742C56A5F147AAA0E6E4F48B`;
Jackpot Ridge idle/join PNGs
`589B5E1060866F8B6433FC64D8AC60299BA4EE67C85F449913A6F52E5F20A21E` /
`3207E76AA38F0D002757F93E20101C74C039EB178E07853B7207E5DBECB1929D`;
Vault Drop idle/join PNGs
`D7F1911E5A76442C4094F9A721844C28D5E57E4A001E81CDC7AA38CA30F59A4D` /
`0628E8929C521D40D3D44DCFE6B6A46F5199206C71B91437148453A3C0CBDEBE`.
