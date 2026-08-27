# craps06_3 Pre-implementation Acceptance Checklist

Status: fixed Review Pool checklist; no product implementation reviewed yet

Row: `craps06_3`

Checklist owner: independent Review Pool

Implementation owner: one assigned craps squad, not the checklist author

This checklist is the acceptance contract for the `craps06_3` implementation.
It was written before squad product work. A reviewer must reject a candidate if
any required item is absent, ambiguous, supported only by an uncommitted
artifact, or weakened to fit schedule or existing code.

## 1. Binding inputs and start condition

- [ ] The full `docs/todo/craps06_3_craps_depth_rework_prompt.md` remains
  binding, including the no-hardways/props readability decision and the five
  mandatory dynamic sequences.
- [ ] The accepted `craps06_1` and `craps06_2` heads and their full archived
  prompts are cited. Verified rules, RTP, cash/chip routing, cheat tuning, and
  street settlement behavior are preserved unless an explicit failing test
  proves a correction is required.
- [ ] The exact independently accepted `env06_6` runtime/vocabulary head and
  exact independently accepted `game06_1` ritual-contract head are cited.
  Implementation does not infer missing envelope, identifier, receipt,
  operation, fact, persistence, or rejection fields from runtime code.
- [ ] The `game06_1` contract used by the squad has reconciled every item that
  its draft marked pending on the env vocabulary. A draft or checklist alone is
  not implementation authority.
- [ ] Rules, surface, fixture, and capture tests may be prepared while a
  dependency is pending, but no product implementation begins until the
  program director records both contract acceptances and the exclusive file
  assignment.
- [ ] No owner-locked design, economy, payout, odds, wager math, tuning,
  migration, or Voice Bible value is guessed. A conflict is raised to the
  program director and the row parks without idling another lane.

## 2. Consumer audit before settlement edits

Before editing any roll, wager, result, or settlement path, the squad delivers
a consumer matrix with exact symbols/state keys, read/write authority, existing
tests, planned change, and assigned file owner for every direct and indirect
consumer. At minimum it covers:

- [ ] `scripts/games/craps.gd`, `scripts/games/craps/craps_rules.gd`, and the
  `craps_config` / `street_craps` slices of `data/games/games.json`: session
  generation, legal targets, command routing, authoritative roll, working-bet
  lifecycle, result construction, energy, cheats, and street dispersal.
- [ ] `GameModule.apply_result`, `RunState` serialization, bankroll/chip
  authorities, autosave/exit, and result history/reporting: identify the one
  money mutation boundary and prove the ritual never performs a second debit or
  credit.
- [ ] `scripts/ui/foundation_main.gd`, `scripts/ui/game_surface_canvas.gd`,
  `scripts/games/table_game_visuals.gd`, surface audio, accessibility, input,
  animation-channel, and liveness seams: identify who consumes command results,
  patches, hit regions, safe acceleration, and post-action interrupts.
- [ ] The accepted env06_6 public command/fact/projection APIs and current
  scenario/environment consumers. The audit distinguishes public projection
  from private local state, reducer journals, receipts, seals, and hidden branch
  data.
- [ ] Street-craps scenario, event, archetype, game-hook, sweep/heat, training,
  and item consumers in current data and code. Ordinary alley generation with
  no street-craps scenario remains trace-free.
- [ ] Current crew/heist/play consumers, tutorial lesson, career/run reports,
  performance telemetry, RTP/determinism/soak/visual tools, and all foundation
  fixtures that mention craps.
- [ ] Every serialized craps/session/UI/scenario key is classified as
  authoritative, derived prepared projection, transient presentation, or
  one-shot receipt. Migration and unknown-field behavior are named.
- [ ] The audit proves there is one authoritative rules engine for casino and
  street modes and one settlement authority. No presentation, scenario, actor,
  audio, capture, or tutorial consumer can reroll, settle, or move money.

Any newly discovered consumer is added to the matrix before its producer is
changed. An unowned shared-file edit is a review rejection, not an integration
convenience.

## 3. Rules, wager controls, and accounting

- [ ] A bet-by-bet matrix covers pass, don't pass, come, don't come, odds,
  place 4/5/6/8/9/10, and field across come-out/point states: implementation,
  label, availability, working behavior, settlement, payout, removal, and
  contextual help.
- [ ] Casino and street variants preserve their intended rule sets. No new
  hardway or proposition bet appears; street exposes only its authorized
  pass/don't-pass gutter-stake rules.
- [ ] Direct denomination selection and semantic controls exist for add,
  correct, remove one pending wager, undo, clear, repeat last, re-bet eligible
  resolved wagers, confirm, odds management, and working-bet management where
  the authoritative rules permit them. `Clear All` is never the only correction
  path.
- [ ] Pending, working, resolved, returned, and removed wagers have stable item
  identities. Controls cannot mutate a wager in the wrong lifecycle state.
- [ ] Available cash/chips, pending total, at-risk working stake, returned
  stake, payout, net change, and each bet resolution are simultaneously
  unambiguous and reconcile exactly to the authoritative result.
- [ ] Point/come-out state, legal targets, odds capacity, enabled/disabled
  status, and disabled reason are readable on the table and non-color-only.
- [ ] Exit and save mid-point state explain and preserve every unresolved wager.
  No wager is silently settled, lost, duplicated, or permanently stranded.
- [ ] Table-driven rules and conservation tests cover naturals/craps, point
  make/seven-out, come/don't-come travel, odds on/off and limits, place/field,
  push/return/removal, repeat/re-bet, casino chips, and street cash.

## 4. Tactile ritual and authoritative settlement

- [ ] The explicit presentation machine is `betting -> dice offered ->
  aiming/throw -> bounce/read -> dealer settlement -> betting`, with stable
  phase ids, legal actions, explicit transitions, reachability, and safe exit.
- [ ] Confirming wagers, committing a roll, obtaining authoritative dice,
  revealing dice, and settling are distinct boundaries. One receipt/fingerprint
  cannot authorize two different commands or two settlements.
- [ ] Pointer/touch drag-release has bounded direction and strength, visible
  dice travel, table/wall contact, separation, and readable final faces.
  Keyboard, controller, click, and reduced-motion auto-throw produce the same
  authoritative outcome and fair timing.
- [ ] Invalid, incomplete, out-of-bounds, inaccessible, stale-phase, or repeated
  throws return the dice harmlessly: no charge, RNG consumption, result change,
  phase advance, fact, receipt, audio reward, or scenario mutation.
- [ ] Dice animation consumes an already authoritative result. Presentation
  never rerolls, reorders dice, reads wall-clock time for authority, or changes
  settlement.
- [ ] Chips visibly move to semantic targets; dealer collection, returned stake,
  payout, puck state, dice offer/return, and roll call are staged in order. The
  result remains readable before another commit, with deterministic safe
  acceleration for repeat play.
- [ ] Dice-setting and dice-switching challenges are integrated into the ritual
  without becoming a disconnected result panel. Existing eligibility, item,
  heat, suspicion, confiscation, bias, fairness, and training contracts remain
  authoritative.
- [ ] Property/trace tests prove no input sequence can double-roll,
  double-commit, double-settle, act out of phase, charge on rejection, lose a
  working wager, or strand the ritual.

## 5. Staffed actors, table energy, and room response

- [ ] The visible casino table includes a stickperson, base dealers, box/pit
  presence, and a bounded crowd. Each has stable semantic id, authored anchor,
  bounded pose/behavior states, and action-boundary reactions.
- [ ] Authored actor states cover come-out, point on, winning point, seven-out,
  hot shooter, cheat suspicion, closing, and idle. Gaze/attention and reactions
  are driven by typed facts, never frame count.
- [ ] The player remains the only mechanical shooter. Staged hand-off/rotation
  between sessions or scenario beats does not create an NPC roll, hidden wager,
  or player-money consequence.
- [ ] Calls and reactions are varied, cooldown-bound, and Voice Bible compliant.
  Audio covers dice offer/cup, chip placement, table contact, call, collection,
  payout, crowd swell/drop, and street cues without owning authority.
- [ ] Every energy tier materially changes at least one actor, object, or
  interactable: crowd population/position, rail space, staff attention,
  animation intensity, nearby interaction, or security presence. Music, tint,
  labels, and patron text alone fail.
- [ ] Energy rising and falling applies and removes its effects at named safe
  boundaries. Revisit/restore prepares the correct state without replaying a
  reaction or leaving stale blocked interactions.

## 6. env06_6 fact and sequence integration

- [ ] Typed, versioned craps facts publish only at accepted safe boundaries for
  come-out, point set, point made, seven-out, streak tier, large swing, cheat
  attempt/result, table cooled, street lookout warning, and dispersal.
- [ ] Fact payloads expose only public causal information. Future dice,
  unrevealed cheat outcomes, private scenario state, hidden security decisions,
  RNG state, receipt journals, and sealed inventory internals never leak.
- [ ] Facts enter through the accepted env06_6 authenticated batch boundary;
  craps does not mutate scenario internals, actors, routes, services, objects,
  objectives, or local state directly.
- [ ] Scenario responses consume successful prepared public projections and
  apply at the next safe boundary. A rejected or duplicate batch is atomic and
  cannot partially move an actor, block a service, or change a route.
- [ ] Five distinct sequences ship and are proved: ordinary casino table;
  hot/high-stakes casino table; security/audit casino table; ordinary street
  circle; street circle interrupted by sweep/heat.
- [ ] Each sequence changes space and required actions, not only tuning, reward,
  dialogue, music, tint, or density text. Casino examples may gather/disperse
  patrons, move pit staff, and block/open a service; street examples may move a
  lookout, relocate the chalk ring, and alter a route/object.
- [ ] Every sequence has readable arrival, complication/opportunity, at least
  two consequential action boundaries, meaningful choice/failure/ignore path,
  material branch-specific aftermath, clean exit, and partial/terminal revisit.
- [ ] Scenario-local aftermath persists in the node snapshot. Save/load or
  revisit never replays rewards, facts, dialogue, audio, transition operations,
  cleanup, or settlement.

## 7. Street-craps living sequence

- [ ] Arrival visibly establishes the cash circle, readable participants, dice,
  lookout, and embedded first-session teaching without an overlay.
- [ ] Lookout pressure and sweep/heat facts produce a staged warning phase before
  break-up where the accepted scenario graph allows it; warning is not merely a
  text banner.
- [ ] Break-up leads to a deterministic escape, dispersal, or relocation
  aftermath with changed actors, chalk ring, route/object, and available
  actions. Revisit distinguishes partial warning, relocated, and terminally
  dispersed states.
- [ ] Unresolved street stakes follow the existing documented fair recovery
  rule exactly once across interruption, save, exit, restore, travel, and
  revisit. Scenario staging cannot invent a refund or second settlement.
- [ ] Street training progress and the crew practice route remain compatible;
  neither source is mandatory and neither can duplicate a grant.

## 8. Determinism, exactly-once behavior, and privacy

- [ ] Identical seed plus canonical action trace produces identical rolls,
  wager state, ritual phases, actor/object states, scenario facts/responses,
  layouts/routes, receipts, and aftermath on native and Web.
- [ ] All authoritative randomness comes from declared run RNG streams with
  documented ownership and consumption. Pointer samples, timestamps, frame
  count, animation duration, audio, and renderer state are never RNG authority.
- [ ] A stable receipt plus identical command returns the accepted cached result;
  receipt reuse with another fingerprint rejects without mutation.
- [ ] Money movement, settlement, training, item consumption/confiscation,
  suspicion/heat, facts, scenario operations, branch outcomes, cleanup, and
  terminal aftermath each occur exactly once across save, reload, exit, travel,
  revisit, interruption, abort, expiry, and retry.
- [ ] Failed commands, facts, operations, settlement, restore, and rendering are
  atomic. Public presentation fails closed rather than exposing a partial or
  unauthenticated state.
- [ ] Automated fixtures attempt early result reads, future-dice inference,
  unrevealed cheat-result reads, private scenario-state reads, and receipt
  substitution. Any hidden-information leak is P0 and rejects the row.

## 9. Save, restore, compatibility, and platform

- [ ] Save/load is proved at every ritual phase boundary and the declared safe
  mid-animation policy, including point-on, dense working bets, hot/audit table,
  street warning, relocated circle, and dispersed terminal state.
- [ ] Restore lands in a legal phase with matching authoritative semantic
  snapshot. Derived projection is rebuilt; transient travel/shake is safely
  resumed or completed; one-shot effects and settlement do not replay.
- [ ] Existing saves migrate without reselecting scenario identity, changing
  rolls, changing unresolved stakes, or losing casino/street variant identity.
- [ ] Casino tables still route wagers/payouts through chips; street craps still
  uses cash. Other games' money seams and all unadopted ritual surfaces remain
  behavior-compatible.
- [ ] Native and Web accept the same semantic input trace, including pointer
  normalization and equivalent actions, and produce exact authoritative parity.
- [ ] No schema evaluation, scene reconstruction, authority decision, or deep
  copy is added per frame. Existing animation channels are reused.
- [ ] Idle-liveness counter evidence advances on every touched surface; a
  measured `0.000` draw cost without advancing liveness is a failure.

## 10. Accessibility, presentation, and human proof

- [ ] The casino surface reads as a recognizable craps table at 1280x720 and all
  supported sizes. Dense bets, help, controls, dice, chips, totals, actors, and
  reactions have no overlap, clipping, or unreachable hit target.
- [ ] Pointer actions have keyboard/controller equivalents; touch targets meet
  current size requirements; focus order and contextual help are complete.
- [ ] Point, legal/disabled/working/resolved states, denominations, dice, and
  chips are distinguishable without color alone and under supported colorblind
  settings.
- [ ] Reduced motion removes large travel, bounce, shake, and crowd motion while
  preserving phase, result, settlement, reaction, and fair timing clarity.
- [ ] Idle life is bounded actor/table activity, not distracting constant motion.
- [ ] Human playtest proves a new player can place and remove a line bet,
  identify the point, perform or invoke an equivalent throw, understand payout
  and returned stake, and exit safely without outside rules.

## 11. Required visual evidence

The exact candidate head supplies current, labeled captures or deterministic
traces for:

- [ ] come-out, point-on, point-made, seven-out, and every point number;
- [ ] dense working wagers, odds at capacity, per-bet settlement, and disabled
  help states;
- [ ] dice offered, aim/throw, bounce/read, settlement, invalid-return, safe
  acceleration, dice-setting, and dice-switching success/failure;
- [ ] idle/minimum and maximum energy, hot table, audit/security attention, and
  energy cooldown;
- [ ] ordinary/hot/audit casino sequences and ordinary/warning/relocated/
  dispersed street sequences, including revisit and save restore;
- [ ] keyboard/controller focus, touch/small-screen, colorblind, reduced-motion,
  obstruction, text-safety, z-order, and hit-target overlays.

Automated visual generation is not human visual review. The evidence manifest
records exact commit, command, platform, dimensions, settings, capture ids,
reviewer, and findings. Goldens are not refreshed merely because the design
changed; any stale-golden claim requires independent evidence.

## 12. Gate Service evidence required for acceptance

All evidence is bound to one exact candidate commit, declared Godot identity,
built native-plugin path and SHA-256, command, timeout/method, start/end time,
duration, exit code, complete stdout/stderr, report hash, host, and first result.
No squad self-run substitutes for Gate Service evidence.

- [ ] `tools/validate_project.ps1` passes.
- [ ] All supported relevant systems, content, games/table-games, UI, save,
  accessibility, scenario, and full Foundation suites pass.
- [ ] Craps-focused rules, UI-command, phase-property, conservation, scenario
  integration, hidden-state, save/revisit, and compatibility fixtures pass.
- [ ] `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
  passes with exact checkpoint count and digest reported.
- [ ] Native/Web exact authoritative trace parity passes for casino and street
  rituals, including interruption and restore.
- [ ] The million-roll RTP/fairness matrix passes for every scoped bet and the
  existing bounded setting bias; street pass-line parity remains exact.
- [ ] Performance and idle-liveness pass on every touched surface with measured
  average/p95/max and liveness counts. Budgets are not raised or selectively
  rerun.
- [ ] `tools/foundation_visual_qa.ps1` and the complete focused visual plan pass
  independent review.
- [ ] The env06_6 sequence/uniqueness audit accepts all five sequences with
  reachability, persistence, cleanup, normalized signatures, refs, seeds, and
  capture ids.

Every red, timeout, crash, stderr stream, and repeat remains in the manifest.
Infrastructure defects are routed through Defect Triage under the program
contract; tests, goldens, filters, and budgets are never weakened to obtain a
green result.

## 13. Exclusive file ownership and immutable handoff

- [ ] The program director publishes one exact ownership manifest before edits.
  The craps squad owns only its assigned craps module/rules/view-model/content
  slice, craps-specific fixtures/tools, and explicitly assigned presentation
  assets.
- [ ] Shared game runtime and visual files, including `game_module.gd`,
  `table_game_visuals.gd`, `game_surface_canvas.gd`, `foundation_main.gd`,
  shared audio/input/accessibility systems, and the `game06_1` contract, remain
  with their assigned owners unless the director records a singular transfer.
- [ ] env06_6 runtime/schema/renderer files and env06_7 authored packages remain
  with their owners. The craps squad integrates only through accepted public
  APIs and contributes craps-specific definitions in an explicitly assigned
  file or slice.
- [ ] Crew/world models and the EventModule crew seam are exclusively owned by
  the parallel former-PM lane. The craps squad does not edit
  `delivery_run_model`, `numbers_model`, `crew_state_model`,
  `crew_recruitment_model`, `crew_play_model`, `crew_heist_model`,
  `crew_turn_model`, `police_sweep_model`, or the EventModule crew seam.
- [ ] `main`, `docs/todo/README_0_6_board.md`, assignment order, Gate Service,
  and Review Pool records remain program-director property. Older row-prompt
  instructions to claim or close the board are superseded.
- [ ] No owner property under `.tmp/`, `.tools/`, or `review_artifacts/` is
  staged, moved, or removed. No remote state, release activity, or deletion is
  part of this row.
- [ ] The candidate handoff names exact source head, base, complete path list,
  ownership proof, net diff, generated/untracked exclusions, consumer matrix,
  contract heads, evidence manifest, deferred defects, and any owner decision.
- [ ] Independent review checks this fixed checklist against the exact immutable
  candidate head. The reviewer did not implement the row. A second rejection
  escalates to the program director.

## 14. Acceptance disposition

`ACCEPT <exact-head>` is permitted only when every binding item above is green
or a prompt-authorized non-applicable item is documented with exact evidence.
Dynamic sequences, tactile settlement, physical energy projection,
exactly-once behavior, hidden-state privacy, accessibility, platform parity,
and exclusive ownership cannot be waived.
