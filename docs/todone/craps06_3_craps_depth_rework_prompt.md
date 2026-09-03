Status: COMPLETE — landed Craps depth accepted and archived
Board row: `craps06_3` in `docs/todo/README_0_6_board.md`

## Execution Record

- Completed: 2026-09-03.
- Recovered implementation: `7d230a63`; no product rebuild or remediation was
  required during closeout.
- Five casino/street ritual profiles, tactile throw phases, bet correction,
  staffed energy states, committed environment responses, street warning and
  dispersal, save/revisit, and exactly-once returned stakes are present on the
  audited current tree.
- Project validation, focused Foundation Craps, row and environment contracts,
  million-decision RTP/fairness, 55-scenario uniqueness, actual-GL visual QA,
  liveness, reduced motion, and authority-hostile checks pass. Exact commands,
  timings, hashes, and retained setup red are in
  `docs/plans/craps06_3_final_closeout.md`.
- Only the program-level cold-player comprehension check remains for
  `playtest06_1`; it is not automated implementation work.

# Agent Prompt — 0.6 craps06_3: Craps Table Depth and Living Sequence Rework

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is an
owner-requested depth pass over the shipped Grand Casino and street-craps
implementations, not a rules rewrite from scratch. Read
`docs/todone/craps06_1_craps_core_prompt.md`,
`docs/todone/craps06_2_street_craps_prompt.md`, and the actual craps module,
rules, view model, tuning, and tests. Preserve verified math and correct it only
with explicit test evidence.

## Audit finding and target

The shipped rules cover the scoped line/come/odds/place/field matrix and save
correctly, but the player experience is a static procedural layout: click bets,
click Roll, view a short dice wobble and settlement. Table energy currently
projects mostly into music numbers and a patron line. Street dispersal is a
useful state change, but neither table yet feels like a staffed, reactive craps
sequence. The target is a tactile, readable casino ritual whose crowd and room
physically react to play.

## Board/dependencies

Follow the active board protocol. `craps06_1` and `craps06_2` are landed.
`env06_6` is required for persistent room-level scenario reactions; rules,
surface, and table staging may be developed independently, but this row cannot
finish until the dynamic integration passes.

## 1. Rules and usability completeness audit

- Produce a bet-by-bet matrix comparing implementation, labels, availability,
  working behavior, settlement, payout, removal, and help against the intended
  readable 0.6 rules. Do not silently add every casino prop bet: the original
  no-hardways/props readability decision remains binding unless the owner
  changes it.
- Add direct chip denomination selection, add/remove a specific pending wager,
  undo, clear, repeat last, re-bet resolved wagers, and explicit management of
  odds/working bets where rules allow. Never force Clear All to correct one
  mistake.
- Show available cash/chips, total new stake, at-risk working stake, payout,
  returned stake, and per-bet resolution without accounting ambiguity.
- Make the point/come-out state, legal bet targets, odds capacity, and why a bet
  is disabled readable on table. Provide concise contextual rules/help and an
  accessible non-color-only state.
- Audit shooter/session lifecycle and leave no permanently stuck or silently
  settled wager. Exit and save mid-point must explain and preserve unresolved
  bets exactly.

## 2. Tactile throw and table phase machine

- Implement explicit `betting → dice offered → aiming/throw → bounce/read →
  dealer settlement → betting` presentation phases. Authoritative outcomes
  remain seeded and rules-owned; presentation may never reroll or change them.
- Primary throw: pointer/touch drag and release with direction/strength bounds,
  visibly traveling dice, table-wall/contact bounces, separation, and a readable
  final face. Mouse click/keyboard/controller and reduced-motion auto-throw must
  provide equivalent outcomes and fair timing.
- Reject incomplete/invalid throws gently and return the dice without charging
  or advancing. Do not use wall-clock data for the result.
- Stage chips moving to targets, dealer collection/payout, point puck changes,
  dice offer/return, and roll call. Settlement must be readable before the next
  action without becoming slow on repeated play; allow safe acceleration.
- Dice-setting/switching challenges integrate into the throw sequence rather
  than opening as disconnected result panels. Preserve heat/fairness contracts.

## 3. Staff, shooters, patrons, and table ritual

- Put a stickperson, base dealers, box/pit presence, and bounded crowd actors in
  the visible table scene. Give them authored states for come-out, point on,
  winning point, seven-out, hot shooter, cheat suspicion, closing, and idle.
- The player remains the mechanical shooter for 0.6 compatibility. Represent
  shooter hand-off/rotation as table staging between player sessions or
  scenario sequences; do not build fake NPC rolls that consume player money.
- Add characterful, non-repetitive calls and reactions with cooldowns and
  Voice Bible compliance. Audio must cover dice cup/offer, table contact,
  call, chip placement, collection, payout, crowd swell/drop, and street cues.
- Table energy must change the actual scene: crowd size/positions, open rail
  space, staff attention, animation intensity, nearby interactables, and
  security presence. It may also affect music, but music alone fails.

## 4. Dynamic environment integration

- Publish typed craps facts at safe boundaries: come-out, point set/made,
  seven-out, streak tier, large swing, cheat attempt/result, table cooled,
  street lookout warning, and dispersal.
- Consume authored scenario responses through `env06_6`: patrons gather or
  leave, a pit boss moves to the rail, a service becomes blocked/open, a lookout
  changes position, a chalk ring relocates, or a route/object changes. Persist
  the resulting local state and restore it on revisit.
- At minimum ship and prove distinct sequences for: ordinary casino table,
  scenario-hot/high-stakes table, security/audit table, ordinary street circle,
  and street circle interrupted by sweep/heat. Each changes space and required
  actions, not just tuning/reward/dialogue.
- Street craps needs a staged arrival, cash circle/readable participants,
  lookout pressure, warning phase, break-up/escape or relocation aftermath,
  and honest recovery of unresolved stakes. Training must be embedded in play.

## 5. Presentation and accessibility

- Redesign the surface around a recognizable craps table while preserving
  1280×720 hit targets and touch readability. No text overlap at all supported
  sizes. Dice and chips remain distinguishable under colorblind settings.
- Idle life comes from actors/table machinery; do not add distracting constant
  motion. Reduced motion removes large travel/shake while keeping phase/result
  clarity. All pointer actions have keyboard/controller equivalents.
- Do visual QA for every point state, dense working bets, max crowd energy,
  all cheat flows, every street phase, save restore, reduced motion, and small
  screen.

## 6. Tests and acceptance

- Preserve and extend the full rules/RTP/fairness matrix. Add UI command tests
  for add/remove/undo/rebet/odds and bankroll/chip conservation.
- Script the phase machine and assert no input can double-roll, double-settle,
  lose a working bet, or charge on an invalid throw.
- Prove presentation results match authoritative dice on native/Web and after
  mid-animation save/restore policy.
- Assert every energy tier changes at least one actor/object/interactable state,
  not only music/text, and returns/settles correctly when energy falls.
- Save/load and revisit at point-on, during safe throw boundaries, hot table,
  warning, relocated street circle, and dispersed terminal state.
- Human playtest checklist: a new player can place/remove a line bet, identify
  the point, throw, understand payout, and exit safely without outside rules.

Run project validation, all relevant foundation suites, 10-seed determinism,
native/Web parity, million-roll RTP, performance, accessibility, and visual QA.
Archive only with exact evidence and no waived dynamic-sequence requirement.
