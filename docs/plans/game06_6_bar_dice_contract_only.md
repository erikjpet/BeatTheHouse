# game06_6 BAR-DICE contract-only staging

Status: **UNREVIEWED / dependency-held**

Base: frozen `game06_1` vocabulary head `a2760d81`. Integration is held until
the owner resolves `craps06_3` and an accepted `game06_1` successor exists.
This lineage consumes no rejected runtime and changes no environment, crew,
world, shared assembly, board, Craps, or shipped Bar Dice implementation file.

## Read-only authority boundary

BAR-DICE is a presentation projection over the shipped `BarDiceGame`. It does
not roll dice, grade timing, score Ship/Captain/Crew, select winners, calculate
rake or payouts, accept wagers, move cash, add heat, grant training, disperse a
street game, or decide interruption recovery.

| Shipped authority | Read-only contract input | Forbidden presentation effect |
| --- | --- | --- |
| `BarDiceGame._active_stake_from_context()` | proposed/accepted stake and available cash | selecting, raising, covering, charging, or refunding a stake |
| `BarDiceGame._player_final_dice()` and `_opponent_results()` | authoritative committed throw and visible opponent legs | rolling, rerolling, changing order, or introducing a second RNG |
| `BarDiceGame._score_ship()` and `_winning_seats()` | qualification, 6-5-4 acquisition order, cargo, winners | rescoring or choosing a winner from animation state |
| `BarDiceGame._working_pot()`, `_rake_for_pot()`, `_gross_payout_for_pot()` | covered cash, pot, rake, payout and carryover | generating cash or changing payout/probability |
| `BarDiceGame._resolve_table_round()` | one immutable result receipt | double-settlement, presentation luck, or wall-clock outcomes |
| controlled-roll and palmed-swap graders | accepted grade, margin, applied flag and heat | widening timing, inventing tells, or leaking a future result |
| Craps street guidance/training seam | accepted teaching lines and completion facts | duplicating teaching progress or granting training |
| Craps street dispersal seam | warning, interruption, refund and aftermath receipts | recomputing a sweep or independently refunding a wager |

The shipped five-die, three-shake Ship/Captain/Crew rules, stake ladder,
participant pot, edge-tier rake, carryover, press, cheat grades, heat, item
effects, luck behavior, patron determinism, and all bankroll deltas remain
unchanged. Any mismatch found during later integration is a dependency finding,
not permission to alter those values on this branch.

## Frozen ritual

The BAR-DICE presentation has exactly seven ordered phases:

1. `agree_wager` — show both parties' available cash and a proposed cash stake.
2. `cover` — stage only an authoritative accepted, partial, or refused cover.
3. `shake` — bounded cup motion; no dice authority is consumed yet.
4. `throw` — submit one accepted throw action and bind its result receipt.
5. `reveal` — lift the cup over the already-authoritative visible dice.
6. `call` — project qualification, cargo, winner, and bounded readable tells.
7. `settle` — animate the exact cash delta, return, rake, or carry receipt once.

A rejected verb returns to a legal pre-commit phase without charge or progress.
Every pointer verb has keyboard, controller, and reduced-motion equivalents
that submit the same action envelope. Presentation clocks may animate cup and
cash movement but never choose dice, timing grades, winners, dispersal, or
settlement.

## Actors, tells and energy

The opponent is a seeded actor projection with bounded states: `offering`,
`covering`, `watching`, `calling`, `won`, `lost`, `refused`, `backing_off`, and
`walking`. Onlookers are seeded presentation actors whose reactions depend only
on public wager, round, result, heat, and interruption facts. They cannot affect
the throw or economy.

A tell must name its public source fact and disclose whether it is reliable.
No tell may read unrevealed dice, a future RNG draw, private timing targets, or
hidden interruption state. A deceptive tell is invalid unless an accepted
dependency explicitly declares its discoverable lie rule.

Energy tiers are `quiet`, `watching`, `tense`, and `breaking`. Each tier changes
at least one actor plus one bar/cup/cash/interactable state; audio or dialogue
alone never satisfies the tier contract.

## Street seam hold

The frozen Craps seam currently establishes cash-only teaching and these
dispersal semantics: adjacent sweep detection, heat-spike threshold, working
wagers refunded at face value, pending cash returned uncommitted, persisted
dispersal reason, and revisit as inactive. BAR-DICE records those as required
capabilities only. It will bind to the owner-resolved `craps06_3` successor; it
must not copy `scripts/games/craps.gd` or its state flags.

## Proof required before integration

- exact money conservation for accepted, partial, refused, interrupted and
  settled covers;
- no double throw, double settle, out-of-turn action, stranded stake, or charge
  on rejected input;
- opponent/onlooker determinism and outcome noninterference across ten seeds;
- tells derived only from declared public facts;
- save/load and revisit at every phase with one-shot receipt protection;
- exact reuse of accepted Craps teaching/dispersal envelopes;
- native/Web canonical parity, bounded liveness, accessibility and performance;
- captures for quiet, crowded, agreed, refused, shake, reveal, win, bad beat,
  interruption, reduced motion, small screen and colorblind presentation.

No accepted-ready handoff can come from this lineage alone. The row must be
replayed onto the owner-resolved `craps06_3` and accepted `game06_1` successor
heads without importing rejected runtime commits.
