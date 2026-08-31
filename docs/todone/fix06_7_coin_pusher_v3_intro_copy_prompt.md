# fix06_7 - Coin Pusher V3 intro copy correction

Status: DONE — independently accepted, landed, and post-land verified on
2026-08-26.

## Defect and authority

The shipped Quarter Falls player-facing copy still described the rejected V2
"two shelves" machine. The binding V3 contract in
`docs/plans/coin_pusher_v3_machine_rework_plan.md` defines one reciprocating
flat-topped platform above a fixed lower deck for Quarter Falls, Jackpot Ridge,
and The Vault Drop. This was a stale-copy correction, not a mechanics or design
change.

## Exact implementation scope

Change only these three strings:

- `data/games/games.json` `coin_pusher.intro` to
  `One platform shoves a pile somebody else started.`
- `data/games/games.json` `coin_pusher.description` to
  `Aim. Read the pile. Walk the alarm line.`
- `scripts/games/coin_pusher.gd` Quarter Falls `_variation_intro()` to
  `Quarter Falls moves one platform under a pile that remembers every coin.`

Do not change the solver, renderer, RNG, economy, payout, odds, wager math,
schema, migration, performance caps, release/version/package state, remote
state, or owner files. Test and evidence scope may expand only as required to
prove the authorized copy repair without weakening a test.

## Acceptance

- Source implementation independently accepted at exact head
  `62dba2e3b2b036d0885d209da308bf6e8655a773` with no findings.
- Integration independently accepted at exact head
  `bb3be7fdc329fbcd0e81696656f47a908d31ff74`; the product/test/tool payload was
  byte-identical to the accepted source and the integration documentation was
  additive and preserved current row truth.
- Landed one row at a time by merge
  `040f9fe2cc8ab675b07940999153282a5f03e64e`.
- Recursive stale-golden proof found exactly 36 changed leaves, all the
  persisted `game_states.coin_pusher.last_message` projection of the exact old
  Quarter Falls intro to the exact one-platform intro, with zero unauthorized
  changes.
- Final visual matrix passed 8/8 at 1280x720 and logical 640x360 small-screen,
  normal and reduced motion, including room inspection and untouched initial
  Quarter Falls. Manual review found every image readable and unclipped.
- Post-land static validation, import, GDScript load, and focused Coin Pusher
  passed in 52.341s, 43.424s, 23.748s, and 158.986s respectively; summed time
  was 279.094s. Every timing used the supplied native DLL whose SHA-256 was
  `1052770B5A96057928F67A72159D8A31B89D5591EAB7A64F07F8FCAE458E83F5`.
- Post-land Contract completed every functional assertion successfully but
  retained a timing-only red at 258.562s against the unchanged 230.391s cap.
  That measurement is routed to `fix06_5`; no cap was changed and no rerun was
  performed merely to obtain green.

## Execution record

- Claim owner: `/root/program_row_inventory`.
- Source branch/worktree: `codex/fix06_7-stale-pusher-copy` /
  `D:\Projects\Beat-The-House-worktrees\fix06_7-stale-pusher-copy`, retained as
  provenance.
- Independent reviewer: `/root/fix07_final_review`.
- Recursive parent/current full-capture SHA-256:
  `CA99A6F29B10B0B20C024CDE8E9F5595AE6E9DF61FFEEE38983038A0D4C4B04F` /
  `386FA3B59D08DF4827B4E781DC9CDE061FB40F5CE2B03216EB9967A2DF89E7E0`.
- No mechanics, math, economy, RNG, schema, migration, performance-cap,
  release, version, packaging, remote, or owner-artifact change was made.
