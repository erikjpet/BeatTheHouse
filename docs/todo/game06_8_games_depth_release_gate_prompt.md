Status: TODO
Board row: `game06_8` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 game06_8: Games Depth Release Gate

Copy everything below this line into the agent.

---

This is the independent closure gate for the game depth parity program in
`D:\Projects\Beat-The-House`. It depends on `game06_1` through `game06_7` and on
`depth06_1`. Do not implement a substitute mini-pass and do not mark it complete
from child-row notes alone. Inspect the landed code, data, reports and the
player-facing build yourself.

You did not own any of the implementation branches. If you did, you are the
wrong agent for this row.

## Acceptance audit

1. Account for every game id in `data/games/games.json` — `scratch_tickets`,
   `pull_tabs`, `slot`, `bar_dice`, `blackjack`, `baccarat`, `craps`,
   `roulette`, `crew_draw_poker`, `video_poker`, `coin_pusher` — plus the Grand
   Casino duel and showdown surfaces. Reject any surface that still resolves as
   a control panel, whose only change is art, text or sound, or whose "ritual"
   is a delay before the same result line.
2. Play each game to a real conclusion: commitment, correction, resolution,
   settlement, repeat play, acceleration on repeat, and exit. Confirm staged
   commitment actually prevents the failure it exists to prevent — try to
   double-commit, double-settle, act out of phase, and charge a rejected verb.
3. Verify every tactile verb has a working keyboard, controller and
   reduced-motion equivalent producing identical outcomes and fair timing.
   A verb reachable only by pointer is a failure, not a polish item.
4. Review unlabeled per-game contact sheets. Each game must be identifiable from
   room, actor and object state without titles, signage or reward text.
5. Re-verify math on the exact tree: every RTP band, paytable, probability
   matrix and EV harness at its documented figure, and money and credit
   conservation across splits, doubles, insurance, commissions, multi-bets,
   buy-ins, cash-outs, hand-pays, partial tickets and interrupted street games.
   Any figure outside its documented band blocks closure.
6. Re-verify every integration consumer: Players Card routes, tutorial lessons
   in `data/tutorial/lessons.json`, count challenge and heat backoffs, crew
   coordinated plays from `data/crew/plays.json`, heist honesty and detection
   derivation, and the duel ladder table from `game06_7`.
7. Verify actor and energy honesty across every game: each energy or heat tier
   changes at least one actor, object or interactable state and settles when it
   falls. A tier that only moves music or a patron line fails.
8. Verify neighbour and opponent actors cannot affect player outcomes or
   bankroll anywhere, and are deterministic across 10 seeds.
9. Save, exit and revisit at every phase boundary in every game, including
   mid-ritual, mid-feature, mid-scratch, mid-shoe and mid-duel. No lost wager,
   no double settlement, no replayed reward, dialogue, audio or one-shot effect,
   no orphaned actor or object state.
10. Stress composition: game plus scenario sequence plus event plus service plus
    traveler plus Police Sweep plus save and load at the same node, in the games
    that share nodes with those systems. Verify safe exits and no lost base
    functionality.
11. Performance on the exact tree: per-surface frame cost within budget, no
    per-frame deep copies, and the idle-liveness counter-gate green for every
    touched surface. An idle draw cost of 0.000 is a failure. Check Web and
    low-end alongside native.
12. Re-run full project, content, systems, UI, save, accessibility, determinism,
    native/Web parity, performance, RTP and visual gates on the exact tree.

## Deliverable

Create a closure report mapping each requirement to code, data, automated
evidence and captures, with a per-game table showing ritual phases, tactile
verbs and their equivalents, actor set, energy projection, RTP figure and
verdict. List any remediation commits.

This row remains TODO or BLOCKED if any game still resolves as a control panel,
if any tactile verb lacks an equivalent path, if any documented math figure
moved, if any integration consumer regressed, or if a consequence can
double-fire across save and revisit. On pass, archive this prompt and note the
exact commit and report paths on the board.
