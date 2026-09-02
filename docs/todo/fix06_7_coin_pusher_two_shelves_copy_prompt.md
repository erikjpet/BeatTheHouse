Status: TODO
Board row: `fix06_7` in `docs/todo/README_0_6_board.md`

# Agent Prompt — fix06_7: remove rejected-V2 Coin Pusher “two shelves” copy

Work in `D:\Projects\Beat-The-House` on a clean branch from the exact current
`main`. Read the current board/landing contract, the pusherv3_11 closure report,
the V3 machine rework plan and amendments, and every reachable Coin Pusher
player-facing string before editing.

The shipped behavior correctly uses one reciprocating platform, but at least
two reachable strings still describe rejected V2 “two shelves”:

- `data/games/games.json` Coin Pusher `intro` and `description`
- `scripts/games/coin_pusher.gd` `_variation_intro("quarter_falls")`

Replace only stale copy with concise wording faithful to the one-platform,
rear-fed V3 machine. Audit all Coin Pusher-facing text for the same rejected
geometry, but do not broaden into a voice pass. Add a fail-closed content test
that exercises the production definition/entry path and rejects “two shelves”
or equivalent V2 geometry language.

Hard boundaries: no gameplay, physics, tuning, RTP, EV, payout, odds, wager,
RNG, schema, migration, persistence, renderer, audio, performance-budget or
golden change. Do not use the row to rewrite unrelated prose.

Run exact validation, the focused Coin Pusher suite and the smallest content/UI
gate that proves both strings are reachable and corrected. Use the qualified
ignored native addon before any engine gate and record its source and hashes.
Preserve every red and timing result; do not rerun until green. Commit logical
changes, obtain independent review, and land only the reviewed net payload.
