# Pinball Feel Reference - Ballionaire

Date: 2026-07-01
Binding phase: Phase 0 of `docs/plans/pinball_feature_rework_plan.md`

This document is the feel contract for the pinball feature rework. Later phase
decisions should cite this file when tuning physics, pacing, event density,
board proportions, item hooks, and payout presentation.

## Sources Researched

- Steam store page: https://store.steampowered.com/app/2667120/Ballionaire/
  - Official positioning: fast-paced, kinetic roguelike; strategy meets
    physics; game-breaking synergies; Steam page currently lists 145+
    triggers and 55+ boons.
- Raw Fury official page: https://rawfury.com/games/ballionaire/
  - Official positioning: physics-driven kinetic chaos, trigger combos,
    Laballatory sandbox, mod support, and the developer goal of producing
    "braintickles."
- Rogueliker demo writeup: https://rogueliker.com/ballionaire-demo/
  - Captures five-ball round structure, trigger placement, points totaling
    after the drop, and busy combo chains where triggers cause more events.
- Rogueliker early-access impressions:
  https://rogueliker.com/ballionaire-early-access-review/
  - Captures the drop-to-bottom loop, trigger bonks, portals that return balls
    to the top, and mushrooms/bouncy triggers that push balls upward.
- Guardian review:
  https://www.theguardian.com/games/2025/jan/11/ballionaire-newobject-rawfury-review-addictive-pinball-inspired-strategy-game
  - Captures pyramid board readability, five attempts, 55 board spaces,
    score accumulation, spawned balls, teleport/reverse-gravity style effects,
    and chain reactions.
- Vice review:
  https://www.vice.com/en/article/ballionaire-brings-something-different-to-roguelikes-review/
  - Captures player agency as planning/placement/drop start, with bounce
    physics handling the run and small advantages mattering.
- Openindie/newobject interview listing:
  https://openindie.eu/podcasts/ballionaire/
  - Confirms the developer interview topic: Ballionaire's pachinko/Luck Be a
    Landlord inspiration, static-board synergies, and player discovery of
    unexpected interactions.
- Gameplay/review videos sampled by search and used as visual references:
  - https://www.youtube.com/watch?v=-ZCfoGHpq5I
  - https://www.youtube.com/watch?v=4dgBP5K701c
  - https://www.youtube.com/watch?v=n27yijGz6FY
  - https://www.youtube.com/watch?v=TJcPLB_I2xA

## Design Read

Ballionaire's satisfaction comes from three stacked loops:

1. Immediate launch clarity: the player drops a ball and receives a visible
   response almost immediately.
2. Dense cause-and-effect: pegs/triggers fire in readable bursts, often
   causing secondary triggers, extra balls, teleports, or upward rebounds.
3. Score theater: every trigger contributes to a live money climb, then the
   drop resolves into a clear banked total before the next decision.

For Beat the House, the pinball slot feature should keep the Ballionaire-like
drop satisfaction while adding slot-feature structure: skill shot, locks,
multiball, jackpot ladder, lit inserts, tilt, nudges, and flipper rescues.

## Numeric Feel Targets

These are implementation targets, not Ballionaire reverse-engineering claims.
They are numeric, testable targets inferred from the researched sources and
reconciled against plan section 3.4.

| Target | Number | Rationale | Final check |
|---|---:|---|---|
| Time from feature open to launch-ready | <= 1.0s | Matches the "drop a ball" immediacy and keeps the slot feature from feeling modal. | [ ] |
| Time from launch to first visible payout/event | <= 0.75s median, <= 1.0s p90 | Ballionaire's first bonks/trigger response arrive quickly; the slot feature needs the same early feedback. | [ ] |
| Untouched top-to-bottom fall | 1.3-1.6s | Reconciles plan 3.4's ~1.4s untouched fall with a fast pachinko read. | [ ] |
| Normal single-ball playout | 3.0-8.0s | Existing plan goal; Ballionaire-like boards should extend drops through bounces, portals, and upward kicks. | [ ] |
| Board A full event duration | 8-20s | Quick common feature with 1-3 balls. | [ ] |
| Board B full event duration | 20-40s | Multiball feature with locks and cascade. | [ ] |
| Board C full event duration | 30-60s | High-volatility ladder/wizard feature. | [ ] |
| Normal trigger density | 2-5 visible events/s while active | Enough "bonk" feedback to feel alive without unreadable spam. | [ ] |
| Chain burst density | 6-12 visible events/s for <= 2.0s bursts | Captures Ballionaire chain-reaction excitement while bounding presentation load. | [ ] |
| Event-to-floater latency | <= 100ms | Score/tally should feel causally attached to hits. | [ ] |
| Drain-to-bank tally | 0.4-1.2s | The banked total should resolve briskly before the next ball/decision. | [ ] |
| Live score count-up rate | >= 20 increments/s, capped at 1.2s for large awards | Supports satisfying money climb without delaying the next ball. | [ ] |
| Camera/board aspect | board visible in one view; 0.62-0.72 width/height playfield | Ballionaire readability depends on seeing the route, targets, and bottom outcome together. | [ ] |
| Standard active-ball cap | <= 8 live balls, absolute sim cap 12 | Supports Ballionaire-style spawned balls without swamping the slot cabinet renderer. | [ ] |
| Nudge comfort budget | ~3 nudges/ball before tilt warning | Gives real trajectory agency without turning the feature into manual steering. | [ ] |
| Flipper rescue timing | 120-180ms prompt window | Skillful, readable rescue moment; reconciles plan's 8-10 ticks at 120 Hz (67-83ms) upward to a human-tappable window. | [ ] |
| Perfect-play edge | +15-25% average over random policy across 1000 seeds | Matches plan section 5 skill ceiling. | [ ] |
| Sim tick budget | <= 150us avg at 4 live balls | Plan 3.5 performance gate. | [ ] |
| Surface state budget | <= 300us avg | Plan 3.5 performance gate. | [ ] |
| Hot-loop allocation budget | zero object-count growth per tick probe | Plan 3.5 performance gate. | [ ] |

## Reconciliation Against Plan Section 3.4

- Gravity stays in the same spirit but should tune to an untouched fall of
  1.3-1.6s and a normal playout of 3-8s. Target range updated to
  2.8-3.4 board-heights/s^2.
- Peg restitution tightens from 0.45-0.60 to 0.50-0.62 so ordinary pegs read as
  crisp Ballionaire-style bonks.
- Bumper kick widens upward from 1.8-2.6 to 2.1-3.0 speed units so bumpers,
  launchers, and flippers can visibly send balls back up the board.
- Flipper rescue windows update from 8-10 ticks (67-83ms at 120 Hz) to
  120-180ms, because this rework requires a real timing skill that a human can
  intentionally hit.
- Section 3.4 now also needs explicit event-density and tally targets, because
  Ballionaire feel is not only physics constants; it is trigger cadence plus
  live money feedback.

## Later-Phase Citation Rule

When tuning a phase, cite this document in the progress entry with the target
name used. Example: "Bumper kick tuned to 2.4 speed units per
`pinball_feel_reference.md` Target: Bumper kick / upward relaunch."
