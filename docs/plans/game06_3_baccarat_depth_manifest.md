# game06_3 Baccarat depth manifest

Branch: `codex/game06_3-impl`
Frozen ritual contract: `a2760d816c781e711ff0923c296f97b786662453`

This is the second logical group on the row branch. It is implemented entirely
inside the Baccarat module and row-local proof. It does not import, copy, or
depend on any rejected game06_1 runtime head.

The finite shoe and mandatory Punto Banco rules remain the sole authority for
cards, draws, winner, wagers, commission, and heat. The presentation projection
adds the ceremony `betting -> shoe -> deal -> squeeze_reveal ->
third_card_rule -> settlement -> betting`, structured player/banker third-card
decisions, explicit per-hand and running commission, and material dealer,
caller, neighbour, crew, security, shoe, road-board, discard-tray, felt, and
energy state.

The squeeze is a bounded presentation-only verb. Pointer/touch distance,
keyboard/controller increments, confirm, and reduced-motion completion reveal
the same already-authored card. Invalid or incomplete gestures return without
resolving, charging, advancing authority, or changing RNG. Road boards declare
no predictive authority and are derived only from settled history.

`scripts/tests/foundation/game06_3_depth_contract.gd` proves both games. The
shipped Baccarat seed audit completed 400 hands with no game-specific failures;
its nonzero wrapper result consisted solely of inherited missing-asset content
validation errors on the frozen base.
