# game06_2 second-rejection owner decision packet

Status: **UNREVIEWED / docs-only / option-neutral**

Packet base: main `9ea919fe9b53ab3ae37e085ed462febaa8ad76f8`

Decision scope: disposition of the twice-rejected game06_2 implementation and
the Blackjack ritual-authority boundary. This packet makes no recommendation,
acceptance claim, product edit, or gate claim.

## Decision requested

Choose exactly one authority disposition:

- **A -- Same-scope sole authority closure.** Authorize one named game06_2
  successor to make the ritual resolver/input path the sole authoritative route,
  followed by one exceptional independent review.
- **B -- Explicit split.** Preserve the non-authoritative presentation and record
  work as game06_2, create a named `game06_2b` Blackjack Ritual Authority
  Integration row, and hold game06_7/game06_8 until game06_2b is accepted.
- **C -- Explicit compatibility exception.** Accept that Blackjack continues to
  charge and resolve through bare `resolve_with_context()` /
  `wager_cost_for_context()` and helper-local target routing rather than making
  the frozen ritual envelope the sole authority boundary.

No option is selected or preferred here. Until the owner selects one,
`e699d0bc` and `4dbb83bf` remain rejected/frozen and downstream authority intake
must fail closed.

## Binding evidence

### Source and ancestry

| Artifact | Immutable identity | Binding fact |
| --- | --- | --- |
| Full game06_2 prompt | `docs/todo/game06_2_blackjack_depth_prompt.md`, blob `537a3744253984a7f19ee29828812d4ef66810f0` | Requires the accepted game06_1 contract; owns Blackjack and its tests; forbids shared runtime edits without an exact runtime request; requires no charge/advance on rejected input, full consumer reproof, money conservation, save/revisit, native/Web parity, RTP, accessibility, and visual QA |
| Frozen ritual contract | `a2760d816c781e711ff0923c296f97b786662453`, tree `1df3d9b767d7490acdffb291ce5220c0b409127e`; contract-document blob `fd1deacdcc86fdb67cd2b3f79b480fdcf56ec08b` | Defines one normalized command boundary, closed action declarations and handler allowlists, authenticated targets, deterministic rejection, receipts/fingerprints, idempotent request cache, and keyboard/controller/reduced-motion target equivalence |
| Landed contract | merge `6d8755394c6374ef66364f035e67827fb6e6bf6e`, tree `bf40316ef8bdc0b6f2ef3709e981a2d6b9b324dc` | Parents include accepted contract `a2760d81`; it is an ancestor of packet-base main |
| First rejected game06_2 | `e699d0bcfb566a022f4c4115920690874d0991ab`, tree `30ca1fd1f798988755fb5c422e07d676080f1689` | Direct descendant of `a2760d81`; net `4 files, +1066/-4`; adds consumer audit, presentation/projection, row test, and handoff but retains bare charge/resolve and declaration/projection authority gaps |
| Second rejected game06_2 | `4dbb83bfe6e235640352a39ec90aa80f7d221b02`, tree `098b15369a6a333cf6c18f13f0a9f332e94a4fc8` | Descendant of `e699d0bc`; net `3 files, +362/-35` over first head; adds closed deal-envelope helpers, handler checks, reconciled projected IDs/records, equivalent-input helpers, and hostile tests, but the live host still routes through bare cost/funding/resolve APIs |

The first head changed only:

- `docs/plans/game06_2_blackjack_consumer_audit.md`;
- `docs/todo/game06_2_contract_only_handoff.md`;
- `scripts/games/blackjack.gd`;
- `scripts/tests/foundation/game06_2_depth_contract.gd`.

The second head changes only the latter three relative to the first. Neither
head changes shared `GameModule`, `foundation_main`, `RunState`,
`GameSurfaceCanvas`, or the landed contract.

### Live authority path at both rejected heads

The live foreground host path remains:

1. `FoundationMain._handle_game_surface_command()` reads a surface command's
   `direct_resolve`, `action_id`, and UI state, then calls
   `_resolve_game_action()`.
2. `_resolve_game_action()` calls the game module's
   `wager_cost_for_context(action_id, stake, ...)`.
3. The host calls `RunState.fund_grand_casino_wager()` before resolution.
4. The host calls `current_game.resolve_with_context(action_id, stake, ...)`.
5. Successful results advance time and are applied through the existing result
   path.

At `e699d0bc`, Blackjack emits `blackjack_place_bet` from the local deal helper,
then `wager_cost_for_context()` and `resolve_with_context()` accept it directly.
At `4dbb83bf`, the local command also carries `ritual_command` and
`ritual_handler_id`; however, `FoundationMain` does not consume or authenticate
those fields, and the same bare cost/funding/resolve chain remains callable.
The equivalent-input helper validates its own caller arguments before calling
the same local Blackjack surface-action helper; it is not the host's sole input
authority.

This is the unresolved question. The second head demonstrates closed-envelope
construction and hostile helper rejection, but it does not make that envelope
the exclusive authority for charge, RNG consumption, mutation, settlement, or
request replay.

## Consumer and invariant baseline

Every option inherits these constraints unless the owner expressly records a
separate product exception:

| Consumer/invariant | Current exact seam | Must remain true |
| --- | --- | --- |
| Grand Casino wager funding | `RunState._grand_casino_result_wager_funding_amount()` recognizes only Blackjack `action_id=blackjack_place_bet` for placement funding | exactly one main/side wager debit; rejected/staging input funds nothing; no second funding at settlement |
| Settled-game progress | `RunState._grand_casino_result_has_wager()` counts only Blackjack `action_id=play_basic` with positive stake | placement never advances Players Card/game counts; one settled hand advances once |
| Host charge order | `FoundationMain._resolve_game_action()` computes cost, performs all-in confirmation, funds, then resolves | insufficient or rejected input does not strand funds; confirmation does not duplicate resolution |
| Blackjack settlement | `resolve_with_context()` dispatches placement and later play/settlement; result fields feed RunState | split/double/insurance/surrender conservation and exact `blackjack_hand_results` meanings remain unchanged |
| Tutorial | authored `blackjack_deal`, hit/stand, stake, distraction/peek/count action IDs and state predicates | clean-deal, finish, raise, raised-deal, heat-precheck, count challenge, and exit lessons remain reachable at the same boundaries |
| Crew/heist | normalized `action_kind`, settled hand records, pending dishonesty/detection, Spotter/Big Player availability/cost/window/heat | presentation never grants crew authority or changes detection/heat; nonterminal cheat state survives to settlement |
| Grand Casino endgame | game06_7 reuses Blackjack settlement; Players Card and Rourke routes consume settled results | duel cannot double-charge, bypass a phase, or depend on a ritual authority that was not actually accepted |
| Save/revisit | authoritative table/shoe/session/results live in existing game/environment state; presentation/UI state is reconstructed or selectively persisted | mid-shoe/hand/split/dealer/settlement restores without reroll, repayment, duplicate facts, or repeated one-shots |
| Native/Web | both platforms currently execute the same module APIs; second head's canonical envelope helper is row-local | identical accepted input traces must produce identical costs, RNG use, results, receipts where applicable, and target selection |

## Option A -- same-scope sole authoritative resolver/input route

### Authority disposition

The owner authorizes one named game06_2 successor despite the two-rejection
stop. That successor must make the frozen ritual command/handler route the sole
entry to any authoritative Blackjack action. Bare direct calls, forged/stale
envelopes, cross-target IDs, wrong phases, duplicate request keys, and changed
fingerprints must reject before cost authorization, funding, RNG, mutation, or
settlement. The closure receives one exceptional independent review rather than
another ordinary review loop.

### Consumer consequences

- Surface buttons, pointer gestures, keyboard, controller, reduced-motion,
  autoplay/sit-out, all-in confirmation, tutorial actions, crew actions, and the
  Rourke duel adapter must all reach the same authenticated action registry.
- Existing public action IDs/result fields may remain as compatibility outputs,
  but they cannot independently authorize work.
- If sole authority cannot be achieved inside `blackjack.gd` and its row tests,
  the row must raise an exact shared-runtime integration request; the original
  file-ownership prohibition does not silently disappear.
- game06_7 may consume the accepted authenticated Blackjack boundary; game06_8
  can require it across Family 1.

### Money consequences

- Cost authorization, placement receipt, host funding, and settlement must bind
  to one command identity. The integration must prove the host cannot fund a
  command later rejected by the ritual boundary and cannot fund the same receipt
  twice.
- `blackjack_place_bet` placement and `play_basic` settlement meanings consumed
  by RunState must remain exact or every consumer must change and be re-proved
  together.
- Full split/double/insurance/surrender conservation, all-in cancellation,
  insufficient-funds, stale-phase, duplicate-command, and save/replay cases are
  blocking proofs.

### Save consequences

- The authoritative save schema must persist or reconstruct the legal ritual
  phase, monotonic boundary ordinal, accepted command/result/fact receipts,
  request-cache status, and any fingerprint needed to prevent replay.
- Migration from shipped saves with only table/shoe/session state must be
  explicit and deterministic. Restore must not retroactively charge, emit a
  fact, replay animation/audio/dialogue, or manufacture a receipt for an
  unaccepted action.

### Parity/review consequences

- Native and Web must canonicalize the same closed envelope and produce the
  same lowercase SHA-256 fingerprints, validation order, costs, target choices,
  RNG consumption, and receipt sequence for identical traces.
- The exceptional reviewer must audit both helper bypass and actual host entry,
  not accept helper-only tests as sole-route evidence.
- Acceptance unblocks game06_7 and later game06_8, subject to their own gates.

## Option B -- split presentation from `game06_2b` authority integration

### Authority disposition

The owner classifies the reusable portions of the rejected trees as
non-authoritative game06_2 presentation/record work and creates a separately
named `game06_2b` row for the sole Blackjack Ritual Authority Integration.
game06_7 and game06_8 remain held until game06_2b is accepted.

### Consumer consequences

- A split manifest must name, file by file and symbol by symbol, what is retained
  as pure projection/presentation: consumer audit, actors/objects/energy,
  readable staged/resolution records, visual procedure, and input affordances
  that do not themselves claim authority.
- Envelope construction, handler authentication, target authority, request
  replay, and the charged resolver route belong to game06_2b. Ambiguous helper
  code cannot be declared authoritative in both rows.
- game06_2 can be reviewed for visual/consumer correctness without representing
  that Blackjack satisfies the frozen sole-boundary contract.
- game06_7 must base on accepted game06_2 plus game06_2b; game06_8 lists both as
  dependencies and audits their composition.

### Money consequences

- Until game06_2b lands, the shipped bare cost/funding/resolve route remains the
  only money authority; retained presentation code may display but may not
  create a second ledger or receipt authority.
- game06_2b owns the atomic seam between authenticated command, wager-cost
  decision, host funding, placement, and settlement, while preserving the exact
  RunState placement/settlement action meanings.
- Integration tests must run presentation and authority together; separate
  green row tests do not prove no double charge or stranded funds.

### Save consequences

- game06_2 retains only derived/transient presentation state and the existing
  authoritative table/shoe/session records.
- game06_2b owns any new durable boundary, receipt, request-cache, fingerprint,
  and migration records. The split must specify which row restores each field
  and the ordering of authority restore before projection rebuild.
- Downstream save/revisit acceptance is held until the combined exact tree
  proves every prompt boundary.

### Parity/review consequences

- game06_2 may provide presentation/input-equivalence parity evidence; it cannot
  claim charged-authority parity.
- game06_2b must provide actual-host native/Web canonicalization, bypass,
  idempotency, cost/funding, RNG, and receipt parity evidence.
- This option adds a board row, assignment, review, landing, and dependency edge;
  it preserves narrower review scopes but holds game06_7/game06_8 explicitly.

## Option C -- explicit compatibility exception

### Authority disposition

The owner records that Blackjack is an exception to the frozen sole ritual
command boundary. The accepted behavior continues to use bare
`wager_cost_for_context()` and `resolve_with_context()` for charge/resolution,
with target/gesture checks local to Blackjack helpers. Any `ritual_command`
record retained from `4dbb83bf` is descriptive/diagnostic, not the security or
mutation authority, unless separately stated.

### Consumer consequences

- Existing FoundationMain, RunState, tutorial, crew/heist, and Rourke adapters
  continue consuming legacy action IDs and settled result fields without a new
  shared authority integration.
- Generic game06_1 consumers and game06_8 cannot assert that every Family 1 game
  uses the same sole authenticated command/handler path; validation and release
  documents must name the Blackjack exception.
- Keyboard/controller/reduced-motion and pointer equivalence remains a
  Blackjack-local behavior contract. A caller that reaches a bare resolver is
  outside the helper target checks by design under this exception.
- The owner must state whether `e699d0bc` or the presentation portions of
  `4dbb83bf` form the acceptance candidate; neither becomes accepted merely by
  selecting the exception.

### Money consequences

- The current order remains: host cost query, all-in confirmation, RunState
  funding, then bare resolution. `blackjack_place_bet` remains the placement
  funding signal and `play_basic` remains the settled-game signal.
- No canonical ritual request-cache or fingerprint becomes the money
  idempotency authority. Safety continues to depend on existing host guards,
  Blackjack phase/session checks, and settled result conventions.
- Full no-double-charge, no-stranded-funds, conservation, consumer, and hostile
  UI/helper tests are still required; the exception waives the sole-envelope
  architecture, not observable correctness.

### Save consequences

- Existing table/shoe/session/result saves and compatibility behavior remain
  authoritative; no new ritual receipt/cache migration is required solely by
  game06_2.
- Save/revisit proof remains based on legacy phase/session guards and result
  idempotence. It cannot be reported as proof of the frozen request-cache and
  receipt contract.

### Parity/review consequences

- Native/Web parity covers action IDs, cost, funding, RNG, result fields,
  presentation, and helper-local target behavior. It does not claim parity of an
  exclusive canonical ritual envelope or durable request cache.
- game06_7 must bind to the legacy Blackjack settlement contract and must not
  treat the row-local envelope helper as authoritative.
- game06_8 either carries the explicit exception as an accepted release
  criterion or fails on universal ritual-authority parity; the owner decision
  determines which.

## Decision recording requirements

The owner response should name `A`, `B`, or `C` and record the corresponding
authority boundary, accepted/replayable source heads, downstream holds, and
review owner. For B, it must also authorize the new `game06_2b` row. For C, it
must explicitly identify the game06_1 clauses treated as compatibility
exceptions. Silence is not an owner-side blocker: until a choice is recorded,
the program owns the unresolved escalation and keeps game06_7/game06_8 held.

No product gates were run for this decision packet. Evidence is ancestry,
source inspection, and existing committed gate records only.
