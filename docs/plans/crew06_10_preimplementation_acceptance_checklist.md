# crew06_10 Pre-implementation Acceptance Checklist

Status: fixed Review Pool checklist; no product implementation reviewed yet

Row: `crew06_10`

This checklist is binding with the complete row prompt. It was written before
squad product work. Missing, ambiguous, implementation-inferred, or
schedule-weakened evidence rejects the candidate.

## 1. Authority and start condition

- [ ] The exact accepted `crew06_2` and Punchline L3 heads, archived
  `crew06_2` prompt, current Turn contract, and exact accepted `env06_6`
  implementation/vocabulary head are cited.
- [ ] If the row consumes shared game ritual primitives, the exact independently
  accepted reconciled `game06_1` contract head is cited. No product code invents
  fields left unresolved by a draft contract.
- [ ] Existing hand ranking, cash-only economy, friendly swing/hand caps, trust,
  tell-learning threshold, Turn seam, save compatibility, and deterministic
  policy behavior are preserved unless an explicit failing test proves a
  correction is necessary.
- [ ] No debt, grievance, cheating, side-pot, tournament, economy, tuning,
  schema, migration, roster, itinerary, or locked design change is guessed. A
  genuine stack case or design conflict goes to the program director.
- [ ] The program director publishes one exclusive ownership manifest before
  edits. Product implementation does not begin from an unaccepted shared
  contract or unresolved shared-file assignment.

## 2. Consumer and authority audit before betting edits

Before any wager, turn, deck, result, trust, or settlement edit, the squad
delivers a matrix of exact symbols/state keys, read/write authority, current
tests, planned change, and file owner for:

- [ ] `scripts/games/crew_draw_poker.gd`: enter/generation, legal actions,
  wager cost, live-hand guard, surface projection/commands, resolution, deal,
  betting, draws, observations, showdown, fold, hand/session finish, and stored
  table state.
- [ ] `scripts/core/crew_poker_model.gd` and `data/crew/poker.json`: all seven
  policies, hand ranking, split-pot/conservation helpers, tells, tuning,
  validation, and migration. Audit does not authorize the squad to edit the
  model; ownership remains explicit.
- [ ] `RunState` cash/result application, neutral tell persistence,
  `tell_learned(member_id)`, tell-exposure recording, poker-session trust, save,
  exit/autosave, and result-history/reporting seams.
- [ ] Crew roster, residence, itinerary, active-job, trust/rank, Turn,
  recruitment/play/heist/turn, and sweep consumers. The matrix separates public
  adapter data from private crew/world state.
- [ ] Punchline L3 render/object/interactable layers and accepted env06_6
  command/fact/operation/projection/reentry APIs, including object/actor ids,
  room/layer seals, routes, services, jobs, spectators, and clean exits.
- [ ] Game surface controller/canvas, table visuals, card renderer, surface
  audio, input, animation-channel, accessibility, save, telemetry, and idle
  liveness consumers.
- [ ] Registration/config/content groups, career/run reports, visual/seed tools,
  determinism/visual QA, and every foundation fixture that names Crew Poker.
- [ ] Every serialized table, deck, contribution, policy memory, observation,
  tell, room, and receipt field is classified as authoritative, derived public
  projection, transient presentation, one-shot receipt, or secret-until-reveal.
- [ ] The audit identifies the one authoritative cash debit/credit path, the one
  session settlement/trust path, the one tell-learning path, and the one deck RNG
  owner. Presentation and scenarios own none of them.

Newly found consumers join the matrix before their producers change. An
unowned shared-file edit is a rejection.

## 3. Explicit deterministic betting engine

- [ ] A documented phase/turn machine preserves `ante -> pre-draw betting ->
  ordered discards/draw -> post-draw betting -> showdown -> between hands`, with
  stable dealer/button, seat order, current actor, and legal transitions.
- [ ] Each seat has a visible bounded stack or ledger, total contribution,
  current-round contribution, active/folded/all-in-compatible status if required
  by a proven stack case, and prior action.
- [ ] Check, call, bounded raise/re-raise, fold, round closure, and showdown use
  one authoritative command/result boundary. A participant never contributes
  less than the amount it claims to call.
- [ ] Raise minimum/maximum, cap, reopening behavior, action order, folded-seat
  skipping, and closure after calls/folds are explicit and deterministic.
- [ ] Friendly-table constraints remain binding. Side pots are absent unless a
  documented unavoidable stack case and owner decision require them; otherwise
  the bounded ledger prevents the case.
- [ ] Ante, contributions, pot, returned amounts, payouts, session swing, and
  run cash reconcile exactly at every boundary. The game never awards money
  absent from the pot or strands a round/pot.
- [ ] Every NPC action is separately observable in seat order. No aggregate
  `$N to call` result collapses multiple decisions.
- [ ] Ordered discards/draws preserve deck uniqueness and ownership. Hidden and
  undealt cards never become public before an authoritative reveal.
- [ ] Property/state-machine tests cover rankings, kickers/ties, split payout,
  legal/illegal checks/calls/raises/re-raises/folds, all-fold closure, caps,
  contribution/pot/cash conservation, and arbitrary valid input traces.
- [ ] No valid or rejected trace can act out of turn, double-deal, double-draw,
  double-showdown, double-settle, charge on rejection, lose a contribution, or
  leave a nonterminal round without a legal action/exit policy.

## 4. Nights, visits, sessions, leave, and interruption

- [ ] Night, visit, session, hand, and betting-round identities and lifetimes are
  distinct, stable, and documented with deterministic seed derivation.
- [ ] Leaving between hands and the five-hand cap settle cash/trust exactly once.
  Repeated leave, reload, result application, or revisit returns the cached
  outcome without another consequence.
- [ ] A later valid visit can open a freshly seeded session under a documented
  cooldown/reentry rule. A settled stored snapshot cannot permanently lock the
  table.
- [ ] Leaving during a live hand follows one explicit safe policy that neither
  erases nor duplicates funds, cards, trust, observations, or receipts.
- [ ] Room-scenario interruption is accepted only at named safe boundaries.
  Between-hand duties may pause the session; knock/raid staging may pause,
  hide/clear, resume, or abort under authored branches.
- [ ] Save/load mid-hand restores exact session/hand ids, phase, dealer/button,
  current actor, deck order, cards, stacks, contributions, pot, legal actions,
  policy memory, observations, room state, and receipts.
- [ ] Pre-rework saves migrate without permanent closure, reseeded live hands,
  cash/trust duplication, tell exposure duplication, or roster substitution.

## 5. Seven characterful, non-omniscient opponents

- [ ] All seven member profiles have explicit opening, draw, and post-draw
  policies covering strength thresholds, bluff/semi-bluff frequency, position,
  response to prior raises, draw strategy, table-image adjustment, and friendly
  quit behavior.
- [ ] Each decision is explainable from legal public information, the actor's
  own cards, bounded private policy state, declared per-session memory, and its
  owned deterministic RNG consumption.
- [ ] Policies cannot inspect opponents' hidden cards, undealt cards, future
  deck order, private tell-learning state, hidden Turn state, or renderer timing.
- [ ] Bounded per-session memory includes only authored facts such as who
  raised, shown bluffs, folds to pressure, and current public swing. Persistence
  is neutral, versioned, deterministic, and reset at the documented boundary.
- [ ] Black-box seeded samples demonstrate seven materially distinct tendencies,
  deterministic replay, legal-action compliance, bounded aggression, and no
  hidden-information advantage.
- [ ] Banter covers arrival, ante, check, call, raise, fold, draw count,
  showdown, unusual hand, streak, player hustle, leave, interruption, and
  revisit, with member Voice Bible compliance, cooldowns, and no immediate
  repetition.

## 6. Ordered tell-observation sequences and Turn privacy

- [ ] Observations are an ordered action-relative timeline/queue. Multiple tells
  in one round remain distinct and cannot overwrite a shared presentation slot.
- [ ] Every beat records stable observation id, member/source action receipt,
  start boundary/ordinal, bounded duration, presentation channel, public cue,
  verification condition, consumed state, and verification receipt.
- [ ] Timing is relative to the authoritative NPC action boundary, never global
  surface age, wall-clock time, frame count, or render elapsed time.
- [ ] Each of seven members has authored posture, hand, chip, gaze, card, and/or
  audio staging recognizable across sessions. Generic hash portrait variation
  does not satisfy identity. Text may support a cue but never labels its meaning.
- [ ] Reduced motion supplies an equivalent readable pause/cue with identical
  observation, verification, learning, and receipt order.
- [ ] Exposure becomes learnable only when the exact authored condition is
  later verifiable from cards revealed at showdown. Folded/hidden hands,
  interrupted reveals, and unavailable cards teach nothing.
- [ ] Observation save/load/replay preserves order and remaining presentation
  policy without replaying or double-counting exposure. One verification
  receipt can advance learning at most once.
- [ ] Neutral serialized keys and private-by-default projections preserve
  `tell_learned(member_id)` and Turn compatibility while exposing no counter,
  threshold, meaning, debug label, future tell, or hidden condition in normal
  UI/logs/results/saves presented to players.
- [ ] Test/dev overlays are build-gated and absent from shipping projections.
  Automated privacy fixtures attempt early reads, folded-hand inference,
  undealt-card reads, observation-queue leakage, and debug-overlay activation;
  any leak is P0.
- [ ] Blinded human testing shows above-chance recognition after normal verified
  exposures and subtle/below-threshold recognition before them, without debug
  UI. Method, sample, expected baseline, and results are recorded.

## 7. Staffed table and five room sequences

- [ ] Members visibly arrive, take/leave assigned seats, deal, move chips,
  discard, draw, watch, smoke/drink/fidget, react, and clear the table at
  settlement through bounded actor states and semantic anchors.
- [ ] Pot, contributions, stacks, cards, discard pile, button, turn owner, and
  seat occupancy visually match authoritative state at every boundary.
- [ ] env06_6 operations change real L3 actors/objects/interactions: chairs,
  lamp/table, spectators, jobs/services, private door/side interaction, and
  persistent terminal aftermath. Metadata, tint, music, reward, or dialogue
  alone fail.
- [ ] Ordinary friendly teaching table has embedded play guidance and a distinct
  low-pressure room/task progression.
- [ ] High-pressure hustle test changes legal/public pressure, quit/raise
  behavior, actors/space, and aftermath without changing hidden odds or caps.
- [ ] Debt-court table interrupts only between hands with concrete non-poker room
  duties and distinct return/abort aftermath; it does not add poker debt.
- [ ] After-job decompression uses conversation choices to change who stays,
  which seats/opponents/tells remain, room objects, and aftermath.
- [ ] Raid-jitters/knock-at-door stages pause, hide/clear, and resume/abort
  branches with changed actors, doors/routes, table state, and revisit.
- [ ] Each sequence has readable arrival, at least two material actor/object
  changes, scenario-specific interaction, two action boundaries, meaningful
  choice/failure/ignore, two material outcomes, clean exit, partial/terminal
  revisit, world-system connection, cleanup, expiry, and unique normalized
  mechanic signature.
- [ ] Cash/item/trust changes are consequences, never the primary verb or whole
  sequence. Scenario code cannot settle a hand/session or mutate trust/tells.

## 8. Roster, itinerary, jobs, and cross-lane truth

- [ ] Seat assignment uses authenticated public residence/itinerary projections.
  An absent member appears only after an authored arrival operation.
- [ ] A member required by an active job is not removed or seated inconsistently;
  explicit priority/conflict/deferral behavior is deterministic, public, and
  tested.
- [ ] Crew-ignoring runs remain no-op. Merely visiting L3 without accepting a
  poker sequence does not create trust, tells, memory, table state, or aftermath.
- [ ] Turn consumers observe the same neutral learned-tell API and cannot infer
  unlearned tells or altered thresholds.
- [ ] Cross-runtime facts and operations apply at next safe boundaries with
  authenticated origin, sealed exact room/layer authority, and atomic failure.
  The game never reads scenario private state; scenarios never read hands/deck.

## 9. Surface, pacing, audio, and accessibility

- [ ] The surface continuously and unambiguously shows seat/button order,
  current actor, amount to call, legal raise range, player stack, pot,
  per-seat/round contributions, held/discard state, prior actions, and phase.
- [ ] Deals, individual actions, chips, discards, draws, reveals, payouts, and
  clearing use short action-relative, skippable beats. Input locks only while an
  action would be ambiguous; safe acceleration preserves order and outcomes.
- [ ] Keyboard, controller, touch, and pointer paths reach every action with the
  same semantic command. Focus order and disabled reasons are complete.
- [ ] Reduced motion removes travel/shake while preserving turns, tells,
  showdown, and room-response clarity. Required state is non-color-only.
- [ ] Cards, chips, voices, room tone, chairs, knocks, and showdown have distinct
  bounded audio cues with cooldown/no immediate repetition and non-audio
  equivalents for required information.
- [ ] 1280x720 and supported small-screen layouts have no overlap, clipping,
  inaccessible target, hidden amount, stale hit region, or text collision at
  maximum action copy and 2-/3-opponent tables.
- [ ] No schema evaluation, scene reconstruction, authority decision, or deep
  copy is added per frame. Existing animation/liveness channels are reused;
  idle `0.000` without advancing liveness is failure.

## 10. Determinism, exactly-once, and platform

- [ ] Identical seed and canonical action trace produce identical deck, seat and
  button order, legal actions, policies/memory, bets, draws, results, observation
  queue, learning, cash/trust, room state, receipts, and aftermath.
- [ ] RNG ownership and fixed action-boundary consumption are documented for
  deck, policy, banter, tells, sequence selection, and staging. Presentation RNG
  cannot affect authority.
- [ ] Identical receipt/fingerprint returns the cached result; receipt reuse with
  different content rejects without mutation.
- [ ] Bet, payout, session settlement, trust, tell learning, item/economy effect,
  fact, room operation, transition, cleanup, and aftermath occur exactly once
  across save, reload, exit, travel, revisit, interrupt, abort, expiry, retry,
  and result reapplication.
- [ ] Failed command, fact/operation batch, restore, settlement, finalization,
  or render preparation is atomic and fails closed.
- [ ] Native and Web produce exact authoritative parity for ordinary hands,
  multi-raise hands, fold/no-showdown, each tell verification, save/restore,
  interruption, and each night branch.

## 11. Required visual and human evidence

- [ ] Captures/traces cover ante, every actor turn, pre/post-draw rounds,
  check/call/raise/re-raise/fold, ordered discards/draws, showdown/tie, and
  between-hand/settled/reopened visit.
- [ ] Both 2- and 3-opponent layouts, maximum action/banter text, maximum pot and
  contributions, all seven member tells, overlapping tell queue, and every
  member-specific actor state are covered.
- [ ] Arrival, every phase/branch/terminal aftermath, save restore, and revisit
  for all five poker-night sequences are covered.
- [ ] Keyboard/controller focus, touch, reduced motion, colorblind/non-color
  state, small screen, obstruction, z-order, text-safety, and hit-target overlays
  are covered.
- [ ] Capture manifests bind exact commit, platform, dimensions, settings,
  command, capture id, reviewer, and finding. Automated generation is not human
  visual review; goldens are not refreshed without independent stale proof.

## 12. Gate Service evidence

Every run binds exact candidate, Godot identity, native-plugin path/SHA-256,
command, timeout/method, start/end/duration, process exit, full stdout/stderr,
report hash, host/date, and first result.

- [ ] `tools/validate_project.ps1` passes.
- [ ] Relevant content, systems, games/table-games, UI, save, accessibility,
  scenario, privacy, crew/Turn, Punchline L3, and full Foundation suites pass.
- [ ] Focused state-machine, pot/cash conservation, policy black-box/privacy,
  observation timeline/learning, session reentry/migration, room-sequence,
  coexistence, and human-readability evidence passes.
- [ ] `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
  passes with checkpoint count and digest.
- [ ] Native/Web exact-trace parity, performance/idle-liveness, and
  accessibility pass on all touched surfaces.
- [ ] `tools/foundation_visual_qa.ps1` plus focused independent visual review
  passes.
- [ ] env06_6 sequence/uniqueness audit accepts all five nights with graph,
  refs, persistence, cleanup, signature, seeds, and captures.

Every red, timeout, crash, stderr, and repeat is retained. Defect Triage handles
infrastructure findings under the program contract. No test/golden weakening,
failure filtering, rerun-until-green, or budget increase is accepted.

## 13. Exclusive file ownership and handoff

- [ ] The poker squad owns only explicitly assigned game-specific files/slices,
  unique fixtures/tools, dossiers, and presentation assets.
- [ ] All crew/world models and the EventModule crew seam remain exclusively
  owned by the parallel former-PM lane, including `crew_state_model`,
  `crew_recruitment_model`, `crew_play_model`, `crew_heist_model`,
  `crew_turn_model`, `police_sweep_model`, and any assigned
  `crew_poker_model` adapter work. The squad submits bounded adapter requests.
- [ ] Shared ritual/runtime/visual/controller/canvas/audio/input/accessibility
  files remain with their singular owners unless the director records a
  transfer. env06_6 files remain with that runtime owner; env06_7 package files
  remain with their assigned content squads/assembler.
- [ ] `main`, `docs/todo/README_0_6_board.md`, assignment order, Gate Service,
  and Review Pool records remain program-director property. Older prompt board
  claim/close instructions are superseded.
- [ ] No `.tmp/`, `.tools/`, `review_artifacts/`, editor state, build output, or
  unrelated file is staged, moved, or removed. The row performs no remote or
  release activity and deletes nothing.
- [ ] Exact handoff names base/head, complete path list, ownership proof, net
  diff, consumer matrix, accepted dependency heads, migrations, policy/tell/
  session/sequence reports, evidence manifest, known reds, deferred defects,
  and owner decisions.
- [ ] Independent reviewer checks this fixed checklist against one immutable
  candidate head and did not implement the row. A second rejection escalates to
  the program director.

## 14. Acceptance disposition

`ACCEPT <exact-head>` is permitted only when every binding item is green or a
prompt-authorized non-applicable item has exact evidence. Explicit betting,
pot/cash conservation, tell privacy, Turn compatibility, five material room
sequences, later-session reentry, exactly-once behavior, platform/accessibility,
and exclusive ownership cannot be waived.
