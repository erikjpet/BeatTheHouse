# game06_6 BAR-DICE contract-only staging

Status: **UNREVIEWED / clean-parked / dependency-held**

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

## Park manifest

- Canonical closed-shape ritual:
  `data/games/bar_dice_game_ritual_v1.json`.
- Pure row-local projection:
  `scripts/core/bar_dice_ritual_projection.gd`.
- Executable invariant proof:
  `scripts/tests/foundation/game06_6_bar_dice_contract.gd`.
- Bounded platform/evidence probe:
  `tools/game06_6_bar_dice_platform_probe.gd` and its scene.
- Fifteen inspected native captures, contact sheet, hashes and report:
  `docs/plans/evidence/game06_6_bar_dice/`.

The frozen vocabulary validator passes all 72 negative fixtures and five
neutrality targets. The row-local proof passes seven phases and ten seed
projections, including refused/partial cover conservation, interruption from
every nonterminal phase, receipt replay/conflict handling, save/load, hidden
state noninterference and canonical serialization parity.

The inspected native evidence covers quiet/crowded bars, agreed/refused cover,
shake/throw/reveal/call, win/bad beat, interruption, partial return, reduced
motion, small screen and colorblind labels. Its canonical semantic SHA-256 is
`4e24b5f7230e6169cec55ce0e812fe76639dfff64ce3f49165d7644fc115019c`;
500 serializations measured 192.208 ms and the 30-frame idle maximum was
7.41 ms. These are bounded contract-only observations, not the mandatory
native/Web or full performance gates; those remain with the Integrator after
dependency replay.

This park is deliberately **not** accepted-ready. It owns no shipped Bar Dice
or Craps implementation change and cannot bind the street seam until the owner
resolves `craps06_3` and an accepted `game06_1` successor exists.
