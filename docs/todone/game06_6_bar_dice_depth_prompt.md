Status: COMPLETE — recovered Bar Dice depth is landed, verified, and archived
Board row: `game06_6` in `docs/todo/README_0_6_board.md`

## Execution Record

- Completed: 2026-09-02.
- Recovered implementation: `d98de5440bec7685f4bb26eace77f2dbb1627f53`.
  Closeout proof tooling: `9a6b6abb43b41bebd5d3a12a9a6bbddb25ad68f5`.
- Rules/economy: focused shipped-game suite passed with zero failures. The
  1,000-round friendly/standard/sharp samples retained house edges
  `0.1106/0.1423/0.1719`; exact sealed wagers, carries, presses, cheats,
  rejected input, and save/load passed.
- Ritual/lifecycle: all seven phases, every save boundary, receipt replay and
  conflict protection, exact partial/refused cover accounting, 10-seed
  opponent/onlooker/tell noninterference, and input/reduced-motion equivalence
  passed. The production Main-scene ante probe passed before and after revisit.
- Dependencies: Game 1's sealed host and both Craps depth/environment contracts
  passed, including five distinct profiles and nine hostile-authority cases.
  The Craps environment seam remains intentionally Craps-owned and rejects Bar
  Dice identity; per the prompt's explicit finding clause, Bar Dice neither
  copies that logic nor invents a second interruption authority. Its projection
  safely handles a future already-authoritative interruption fact.
- Determinism: two byte-identical ten-seed runs, 560 checkpoints each, combined
  hash `3142248255`, including 20 Bar Dice roll/controlled-roll checkpoints per
  pass.
- Platform: native and fresh Web release export under Chrome 152 CPU4 passed
  all 15 states with identical semantic hash
  `4e24b5f7230e6169cec55ce0e812fe76639dfff64ce3f49165d7644fc115019c`
  and zero browser errors.
- Performance: full unchanged probe passed; Bar Dice resolve average/p95/max
  `0.611/0.646/0.677 ms` against `1.5/3.0/4.0 ms` budgets, with surface and
  resolve coverage present.
- Visual/accessibility: 15 current native 1280x720 captures and the contact
  sheet reproduced byte-for-byte; canonical visual QA exited zero with no
  warnings. Quiet/crowded, every phase, refused/partial, win/loss,
  interruption, reduced-motion, small-screen, and colorblind states are covered.
- Retained caveats: an extra whole-runtime contract exceeded its 900-second
  outer limit without verdict, and an initial dummy-renderer screenshot attempt
  produced no pixels. Neither is claimed green; the focused dependency gates
  and real-renderer rerun passed. Full report and hashes:
  `docs/plans/game06_6_final_closeout.md`.

# Agent Prompt — 0.6 game06_6: Bar Dice Depth

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is a depth pass over the
shipped bar dice implementation, not a rules rewrite. Read
`scripts/games/bar_dice.gd` (~3300 lines), the `game06_1` ritual contract
document under `docs/plans/`, and the landed `craps06_2` street craps and
`craps06_3` depth work — street craps is this game's closest sibling and its
dispersal, teaching and cash-only seams must be reused, not duplicated.

## Why this rework exists

Bar dice is the street register's own game: no felt, no dealer, no house — just
a cup, a person across from you, and cash on the bar. It currently resolves as a
panel with a result line, which throws away the one thing it has that no casino
game does. This is also the game most likely to be a player's first experience
of the street voice, so its flatness costs more than its play time suggests.

## Board and dependencies

Follow the active board protocol. Claim `game06_6`. `game06_1` must be landed
and reviewed, and `craps06_3` must be landed so its street sequence work can be
reused. You own `scripts/games/bar_dice.gd` and its tests exclusively. You may
not edit the shared runtime or visual layer; file a runtime request instead.

## 1. An opponent, not a panel

- The opponent is an actor with a name, a face, authored states and their own
  money. Seeded and deterministic, they call, react, press, back off, grumble
  and walk. They must never generate or consume money outside the wagers the
  rules already settle.
- Wagers are agreed, not selected: money goes on the bar, the opponent covers it
  or does not, and a raise is a thing the other person can refuse. Show available
  cash, at-risk cash, what is covered and what is returned, with no ambiguity.
- The bar is a scene with onlookers as actors — bounded, seeded reactions, no
  effect on outcomes. A tense round draws people; a bad beat empties the space.
- Preserve every landed rule, payout and probability exactly.

## 2. Cup, dice and tell

- The throw is a bounded tactile verb: shake, slam, lift, reveal. Keyboard,
  controller and reduced-motion equivalents must produce identical outcomes and
  fair timing.
- Presentation phases: `agree wager → cover → shake → throw → reveal → call →
  settle`. Authoritative outcomes stay seeded and rules-owned; presentation may
  never reroll or alter them, and may never read wall-clock time for a result.
- Rejected or incomplete throws return the cup without charging or advancing.
- Where the game has bluffing or calling, the opponent needs observable tells
  that a player can learn — bounded, deterministic, and never a hidden second
  RNG. Keep them honest: a tell that lies is only acceptable if the design says
  it lies and the player can discover that.
- Settlement is hand to hand. Money physically moves between two people, and the
  loser reacts.

## 3. Street pressure and integration

- Reuse the landed street craps seams for dispersal, lookout pressure, sweep
  interruption, warning and relocation rather than writing a second copy. If a
  seam is not general enough to reuse, file the finding with evidence.
- A game interrupted by heat, a sweep or a hostile crowd must resolve honestly:
  unresolved stakes recovered per the shipped rules, aftermath persisted, and
  revisit consistent with what happened.
- Teaching must be embedded in play, in the same style `craps06_2` uses for its
  cash-only street teaching, not delivered as a rules panel.
- Voice must obey the Voice Bible street register: blunt, short, no house
  courtesy. This is the room where the game is allowed to be rude.

## 4. Tests and acceptance

- Preserve and extend the full rules, probability and payout matrix. Money
  conservation asserted exactly, including refused covers, partial covers and
  interrupted games.
- Phase assertions: no input can double-throw, double-settle, act out of turn,
  strand a wager or charge on a rejected verb.
- Opponent and onlooker determinism across 10 seeds, with proof neither can
  affect the player's outcome beyond the rules' own settlement.
- Tell behavior deterministic and learnable; assert it derives from existing
  authoritative state and cannot leak future results.
- Interruption and dispersal paths: unresolved stakes recovered correctly,
  aftermath persisted, revisit consistent, no double-fire across save and
  reload.
- Assert every energy tier changes at least one actor, object or interactable
  state; music and a patron line alone are a validation failure.
- Visual QA: quiet bar, crowded bar, wager agreed, cover refused, mid-shake,
  reveal, win, bad beat, interruption, reduced motion, small screen, colorblind.
- Playtest checklist: a new player can agree a wager, throw, understand the call
  and settle without outside rules knowledge.

Run project validation, all relevant foundation suites, 10-seed determinism,
native/Web parity, probability and payout gates, performance, accessibility and
visual QA. Archive only with exact evidence and with the reused street seams
named explicitly.
