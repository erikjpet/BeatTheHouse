Status: TODO
Board row: `crew06_10` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 crew06_10: Back-Room Poker Depth Rework

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is an
owner-requested depth pass over the shipped Crew five-card draw table. Read the
archived `crew06_2` prompt, actual module/model/data/tests, Crew trust/itinerary
APIs, Punchline layer-3 renderer, Turn consumers, and the new dynamic scenario
runtime before editing.

## Audit finding and target

The game has deterministic hands, personality-weighted policies, hidden tell
learning, trust, swing caps, and persistence. Its live play is thin: NPCs each
act once in a simplified aggregate round; tells share one presentation slot so
later tells overwrite earlier ones; timing is based on surface elapsed time
rather than an action-relative beat; portraits are generic hash variations;
the room barely changes; and a settled session appears permanently closed in
the stored table snapshot. The target is a credible private table night where
seat order, bets, discards, personalities, tells, room state, and relationships
all visibly matter.

## Board/dependencies

Follow the active board protocol. `crew06_2`, Crew depth, and Punchline L3 are
landed. `env06_6` is required for room sequences and persistent aftermath. Do
not expose hidden tell-learning state or weaken Turn compatibility.

## 1. Correct session and betting lifecycle

- Replace aggregate betting with an explicit deterministic turn engine:
  dealer/button and seat order, current bet, per-seat contribution, check/call,
  bounded raise/re-raise rules, fold, round closure, pot conservation, and
  showdown. Friendly table caps remain binding; do not add gambling debt,
  grievances, cheating, side pots, or tournament complexity unless required by
  a proven stack case.
- Give every participant a visible session stack or clearly bounded ledger.
  Actions must never contribute less than the amount they claim to call, award
  money not in the pot, or strand a betting round.
- Preserve ante → pre-draw betting → ordered discards/draw → post-draw betting
  → showdown. Let the player observe each NPC decision instead of collapsing
  the table into a single `$N to call` result.
- Define visits/nights/sessions explicitly. Leaving or reaching the five-hand
  cap settles once; a later valid visit must be able to start a newly seeded
  session according to a documented cooldown/reentry rule. Save/load mid-hand
  restores exact turn, deck, contributions, observations, and animation
  receipts without replaying trust or cash.
- Support deliberate leave between hands and safe interruption by a room
  scenario. Never allow leaving a live hand to duplicate or erase funds.

## 2. Make opponents characterful and strategically distinct

- Expand each of all seven policy profiles into explainable opening/draw/
  post-draw tendencies: hand thresholds, bluff/semi-bluff frequency, response
  to position and raises, draw strategy, table-image adjustment, and friendly
  quit behavior. Decisions may inspect only legal public information and their
  own cards.
- Add bounded per-session memory (who raised, showed bluffs, folded to pressure,
  current swing) so behavior adapts without becoming omniscient. Persist it
  neutrally and keep deterministic replay exact.
- Author enough contextual banter for arrival, ante, check, call, raise, fold,
  draw count, showdown, unusual hand, win/loss streak, player hustle, leave,
  interruption, and revisit. Enforce cooldown/no immediate repetition and each
  member's voice.

## 3. Rebuild tells as observable sequences

- Store observations as an ordered action-relative timeline/queue. Multiple
  tells in one round must not overwrite each other. Every beat has a source
  action, start boundary, bounded visibility duration, channel, and consumed/
  verified state.
- Replace generic hashed portrait marks with member-specific posture/hand/chip/
  gaze/card/audio staging that a human can learn across sessions. Text lines
  may support a tell but must not label its meaning.
- Timing tells are relative to the NPC action beat and deterministic; never use
  global surface age as evidence. Reduced-motion mode preserves equivalent
  readable pauses or cues.
- A tell exposure becomes learnable only when the exact authored condition is
  later verifiable at showdown. Folds and hidden cards teach nothing. Queue
  replay/save/load cannot double-count. Preserve neutral serialized keys and
  the `tell_learned(member_id)`/Turn seam.
- Add blinded human-readability fixtures/playtest: after normal exposures a
  reviewer can identify the tell above chance without debug UI; before those
  exposures it remains subtle. Debug overlays exist only in test/dev builds.

## 4. Make the back room a changing place

- Stage members arriving, taking/leaving seats, dealing, moving chips, placing
  discards, drawing, watching, smoking/drinking/fidgeting as authored, and
  clearing the table at settlement. The pot and discard pile must visually
  match state.
- Use `env06_6` scene/actor/interactable operations so table nights change L3:
  chairs fill/empty, lamp/table state changes, spectators/jobs/services move or
  wait, a private door or side interaction may open/close, and terminal
  aftermath remains visible on revisit where authored.
- Ship at least five mechanically distinct poker-night sequences, selected from
  roster/world context rather than reward skins:
  1. ordinary friendly teaching table;
  2. high-pressure hustle test with tighter quit/raise behavior;
  3. debt-court table where non-poker room duties interrupt between hands;
  4. after-job decompression table whose conversation choices change who stays
     and therefore the opponents/tells;
  5. raid-jitters/knock-at-door table with pause, hide/clear, and resume/abort
     branches.
  Each needs distinct scene changes, altered required actions, and persistent
  aftermath. Cash/item/trust differences are consequences, not the sequence.
- Integrate residents/itineraries truthfully. Never seat absent members without
  an authored arrival, and never remove a member needed by an active job without
  an explicit conflict/deferral rule.

## 5. Surface, pacing, and accessibility

- Redesign for clear seat order, turn owner, amount to call, allowed raise,
  player stack, pot, contributions, held/discard state, and prior action while
  keeping tells diegetic and unlabeled.
- Animate deals/actions in short skippable beats with input locking only where
  needed. Repeated hands must remain brisk. Provide keyboard/controller/touch,
  reduced-motion, non-color-only state, and safe 1280×720/small-screen layouts.
- Give cards, chips, voices, room tone, chair movement, door knocks, and
  showdown distinct audio cues with bounded repetition.

## 6. Tests and acceptance

- Property tests for hand ranking, ordered betting closure, legal raises,
  contribution/pot/cash conservation, ties, folds, caps, exits, and interrupts.
- Policy black-box tests prove distinct member behavior over seeded samples and
  no hidden-card/undealt-card leakage.
- Observation timeline tests cover collision, order, timing, reduced motion,
  showdown verification, folds, save/load, and exactly-once learning.
- Session lifecycle tests prove settlement exactly once and a valid later
  session/revisit; pre-rework saves migrate without permanent lockout or payout
  duplication.
- For every poker-night sequence, prove spatial/actor changes, changed player
  task, distinct branch aftermath, cleanup, save/load, and deterministic reach.
- Visual captures: every turn/round, 2- and 3-opponent tables, all seven member
  tells, maximum action text, settlement/revisit, five night sequences,
  reduced motion, and small screen.

Run project validation, all relevant foundation suites, 10-seed determinism,
native/Web parity, accessibility, performance, and visual QA. Report policy
profiles, betting state machine, tell timeline, session reentry, five sequences,
Turn compatibility, and exact gate evidence.
