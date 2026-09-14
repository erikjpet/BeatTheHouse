Status: COMPLETE — recovered machine depth is landed, verified, and archived
Board row: `game06_4` in `docs/todo/README_0_6_board.md`

## Execution Record

- Completed: 2026-09-02.
- Recovered implementation: `e874d6bc1636ab8094bd88c0c304a5db29902535`.
  Final gate and fairness remediation: `bd77ac54da2c9a911587802968d66cd589a7a1c9`.
- Slot and Video Poker retain the owner-selected W0 + H0 direct-bankroll
  authority: no machine credits or conversion path, no Video Poker hand-pay,
  and a sealed, receipted, replay-safe, settlement-neutral Slot attendant
  acknowledgement.
- Closeout restored mandatory bounded Slot idle life and corrected Holdout
  timing so sealed inputs are graded against the cabinet frame the player sees,
  without changing RNG, rules, paytables, odds, detection, or settlement.
- Project validation, row/dependency contracts, full Slot and Video Poker
  suites, RTP matrices, native/Web ten-seed outcome and bonus parity,
  two-process ten-seed determinism, performance/liveness, accessibility, and
  real-renderer visual QA all pass. Exact evidence and retained non-green
  attempts are recorded in `docs/plans/game06_4_final_closeout.md`.
- No automated implementation work remains. The later program-level human
  playtest must still confirm that new players understand wagers, holds,
  payline readout, feature progression, and Slot attendant acknowledgement.

# Agent Prompt — 0.6 game06_4: Machine Games Depth (Slot, Video Poker)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is a depth pass over the
shipped slot and video poker implementations, not a math or paytable rewrite.
Read `scripts/games/slot.gd`, `scripts/games/slots/*`,
`scripts/games/video_poker.gd`, `scripts/games/video_poker_renderer.gd`, the
`game06_1` ritual contract document under `docs/plans/`, and the landed coin
pusher V3 cabinet — that cabinet is the reference for what machine presence
means in this project now.

## Why this rework exists

The coin pusher V3 rows built a real machine: a cabinet with a body, physical
audio, a playfield that dominates the frame, and a room that contains it. Slot
and video poker sit beside it as panels — a reel strip, a paytable and a spin
button floating in a surface. They are also the games a player touches most
often in the early run, so their flatness sets the tone for the whole update.

## Board and dependencies

Follow the active board protocol. Claim `game06_4`. `game06_1` must be landed
and reviewed; build only on its accepted head. You own `scripts/games/slot.gd`,
`scripts/games/slots/*`, `scripts/games/video_poker.gd`,
`video_poker_renderer.gd` and their tests exclusively. You may not edit the
shared runtime or visual layer; file a runtime request instead.

Treat slot and video poker as two logical commit groups on one branch.

## Owner-selected authority amendment (W0 + H0)

Slot and Video Poker use the existing host-rooted direct-bankroll wager and
settlement boundary. They expose no machine-credit balance, buy-in, cash-out,
conversion, or credit-ledger schema. Every player-funds display labels the value
as bankroll/cash. Video Poker has no hand-pay qualification or acknowledgement
flow. Slot's existing jackpot/grand attendant acknowledgement remains in scope
and must be sealed, receipted, replay-safe, and settlement-neutral.

## 1. The cabinet is the game

- Give both games a cabinet as a scene object: body, glass, belly art, button
  deck, credit meter, denomination state, candle or tower light, and a bill
  validator or coin path that is where money physically goes.
- Wagers and settlements are direct-bankroll host transactions. The cabinet's
  money path and meter must make the committed cash wager and returned payout
  legible without presenting a machine-credit balance or conversion flow.
- Attract, idle, play, feature and lockup are machine states that change the
  cabinet's appearance and audio, not just a label.
- Preserve the shipped slot families, generators, definitions and paytables
  exactly. This row changes the cabinet around the math, never the math.

## 2. Tactile play

- The spin verb becomes physical: a handle pull or button press with a real
  press state, held-button repeat where appropriate, and a bounded tactile verb
  per the `game06_1` pointer vocabulary. Keyboard, controller and reduced-motion
  equivalents must produce identical outcomes and fair timing.
- Video poker's hold and draw becomes card handling: holds are placed on cards
  on the deck, the draw replaces only unheld positions visibly, and the final
  hand is read out against the paytable line it hit.
- Reel stop, feature entry, bonus progression and big-win presentation are
  staged beats that a player can follow and can safely accelerate on repeat
  play. Presentation may never reroll, reorder or alter an authoritative result,
  and may never read wall-clock time for one.
- Rejected or incomplete input returns to the same state without charging a
  credit or advancing a spin.

## 3. The room around the machine

- Seat neighbours are actors playing their own machines, with seeded, bounded
  reactions. They never consume or generate player money and never affect player
  outcomes.
- A floor attendant actor appears for Slot jackpot acknowledgement, lockups and suspicion; the
  cabinet's tower light is how that attention becomes visible.
- A big win must change the room — heads turn, the attendant walks over, the
  candle lights — rather than printing a bigger number. Energy tiers must change
  at least one actor, object or interactable state; music alone is a validation
  failure.
- Cheat flows integrate into the machine (the nudge and tilt language already in
  the project, tilt dampener items, and any landed slot cheat) rather than
  opening a detached panel, with detection math and heat contracts untouched.

## 4. Performance discipline — read this twice

- The slot bonus watchdog per-frame deep copy is a recorded 32.6 ms/frame
  regression in this project's history. Nothing in this row may deep-copy state
  per frame, and the tests must assert per-frame allocation and copy behavior for
  both games.
- Idle life comes from cabinet machinery and actors. The liveness counter-gate in
  `scripts/ui/performance_liveness_guard.gd` is mandatory: an idle draw cost of
  0.000 is a failure, not a pass. This pattern has regressed four times here.
- Nothing new runs per frame that can run at an action boundary. Feature and
  bonus watchdogs tick at boundaries.

## 5. Tests and acceptance

- Preserve and extend the full RTP and paytable matrices for every shipped slot
  family and for video poker. Direct-bankroll conservation is asserted exactly,
  including rejected wagers, Slot jackpot acknowledgement, replay, and
  mid-feature exit.
- Phase and machine-state assertions: no input can double-spin, double-pay,
  hold after draw, duplicate a bankroll charge or charge on a rejected verb.
- Presentation provably matches the authoritative outcome for 10 seeds on native
  and Web, including feature and bonus sequences.
- Per-frame cost and allocation assertions for both games, plus the idle
  liveness counter-gate.
- Save, exit and revisit mid-spin, mid-feature, at a Slot jackpot lockup and
  before/after its acknowledgement, with no lost or duplicated bankroll and no
  replayed reward, audio or one-shot effect. Video Poker has no hand-pay phase.
- Visual QA: attract, base play, near-miss, feature entry, bonus, big win,
  Slot lockup/jackpot acknowledgement, every denomination state, reduced
  motion, small screen, colorblind, and no Video Poker hand-pay presentation.
- Playtest checklist: a new player can commit a direct-bankroll Slot wager,
  spin, and understand the exact settlement; and can play a direct-bankroll
  Video Poker hand, hold correctly and read the paytable line they hit.

Run project validation, all relevant foundation suites, 10-seed determinism,
native/Web parity, RTP, performance, accessibility and visual QA. Archive only
with exact evidence for both games and with the per-frame assertions green.
