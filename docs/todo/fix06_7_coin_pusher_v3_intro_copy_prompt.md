# fix06_7 - Coin Pusher V3 intro copy correction

Status: IN_PROGRESS (claimed 2026-08-26 by `/root/program_row_inventory`).

## Defect and authority

The shipped Quarter Falls player-facing copy still describes the rejected V2
"two shelves" machine. The binding V3 contract in
`docs/plans/coin_pusher_v3_machine_rework_plan.md` defines one reciprocating
flat-topped platform above a fixed lower deck for Quarter Falls, Jackpot Ridge,
and The Vault Drop. This is a stale-copy correction, not a mechanics or design
change.

## Exact implementation scope

Change only these three strings:

- `data/games/games.json` `coin_pusher.intro` to
  `One platform shoves a pile somebody else started.`
- `data/games/games.json` `coin_pusher.description` to
  `Aim. Read the pile. Walk the alarm line.`
- `scripts/games/coin_pusher.gd` Quarter Falls `_variation_intro()` to
  `Quarter Falls moves one platform under a pile that remembers every coin.`

Do not change tests unless an existing validation failure requires it. Do not
touch the solver, renderer, RNG, economy, payout, odds, wager math, schema,
migration, performance caps, release/version/package state, remote state, or
owner files.

## Acceptance

- Exact diff contains only the claim records and the three copy replacements.
- Project static validation passes.
- Source search finds no remaining player-facing `two shelves`, `both shelves`,
  or `read the shelves` Coin Pusher copy.
- A non-author independently reviews the exact implementation head, followed
  by focused Coin Pusher/content/Smoke gates and targeted visual review when the
  engine is available.
