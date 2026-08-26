Status: TODO
Board row: `game06_7` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 game06_7: Rourke Duel and Grand Casino Showdown Depth

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is a depth pass over the
shipped endgame duel, not a redesign of its outcome ladder. Read
`scripts/core/grand_casino_duel_model.gd`,
`scripts/core/grand_casino_showdown_model.gd`, their surfaces and tests,
`docs/plans/grand_casino_endgame_design.md`, the `game06_1` ritual contract
document under `docs/plans/`, and the accepted `game06_2` blackjack head — the
duel shares blackjack's settlement path.

## Why this rework exists

The four-phase duel against Rourke is the last thing a player sees on the
showdown victory route. It is the payoff for an entire run and it currently
presents in the same panel vocabulary as an ordinary table. The crew heist route
added by `crew06_8` gives the game a second ending, which makes the contrast
sharper: two different endings, one flat presentation.

## Board and dependencies

Follow the active board protocol. Claim `game06_7`. `game06_1` must be landed
and reviewed, and this row bases on the accepted `game06_2` head rather than the
bare runtime commit — record that in the ledger. You own the duel and showdown
models, their surfaces and their tests exclusively. You may not edit
`blackjack.gd`; if the duel needs a blackjack change, file it as a request with
exact evidence.

## 1. Preserve the ladder exactly

- Every phase, every outcome rung, every gate condition and every victory route
  contract stays as shipped, including the `grand_casino_invite` flag gate, the
  Players Card route, and the `crew_heist` seam route.
- Do not change duel math, odds, stakes or the conditions under which each rung
  is reached. Produce a written before-and-after table proving the ladder is
  untouched.

## 2. Stage the duel as an occasion

- Implement explicit presentation phases across the four duel phases with
  authored staging beats between them: the approach, the seating, the phase
  break, the crowd change, and the final settlement. Authoritative outcomes stay
  seeded and rules-owned.
- Rourke is an actor, not a portrait: authored states for arrival, confidence,
  pressure, tilt, respect, contempt, suspicion and the moment he realizes he is
  losing. His state must derive from the authoritative duel state, never from a
  parallel dramatic timer.
- The room changes across the duel. Early phases have a floor around them; late
  phases empty or fill depending on how it is going. Staff posture, security
  presence and the rail all move with the ladder rung.
- The player's own position must be legible: what is at stake now, what has been
  won or lost, which phase this is, and what ends it.

## 3. Both endings

- The showdown victory and the `crew_heist` route ending must each get their own
  final beat. They are different stories and must not resolve into the same
  staged moment.
- Where the crew path is active, crew presence at or around the duel must be
  visible using the `game06_1` actor vocabulary, without leaking any hidden Turn
  state. If a crew member has turned, nothing in this surface may reveal it
  earlier than the Turn's own contract allows.
- Defeat needs staging too. The failure rungs are part of the ladder and must
  read as endings, not as a dismissed panel.

## 4. Cheats, crew plays and heat

- Preserve every landed cheat contract, detection math and heat effect exactly,
  and integrate cheat flows into the duel's phases rather than a detached panel.
- Coordinated plays permitted at the duel keep their landed availability, cost,
  window, detection and heat contracts, and present as visible crew presence.
- Suspicion at the duel is the same number it is everywhere else; this row
  changes how it is seen, not what it is.

## 5. Tests and acceptance

- The ladder-preservation table from section 1, backed by tests that assert
  every rung is reachable under the same conditions as before.
- Phase assertions: no input can skip a phase, double-settle, replay a staged
  beat, or strand a stake.
- Both endings played end to end in tests and in captures, including the crew
  route, with a hidden-information audit proving no Turn state leaks.
- Save, exit and revisit at every phase boundary and between phases, with no
  replayed reward, dialogue, audio or one-shot effect and no double-fired
  consequence.
- Assert Rourke's actor state and the room's state derive from authoritative
  duel state, with 10-seed determinism.
- Visual QA: every phase, every ladder rung including all failure rungs, both
  endings, maximum crowd, cheat flows, crew presence, reduced motion, small
  screen, colorblind.
- Playtest checklist: a player reaching the duel can tell what phase they are
  in, what is at stake, how they are doing, and what just happened when it ends.

Run project validation, all relevant foundation suites, 10-seed determinism,
native/Web parity, performance, accessibility and visual QA, plus the full
Rourke duel and Players Card route regressions. Archive only with exact evidence
and with the ladder-preservation table attached.
