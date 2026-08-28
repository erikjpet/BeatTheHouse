# game06_4 Machine Authority Owner Decision

Status: **UNREVIEWED — owner decision required**

This packet records an unresolved authority boundary. It does not select or
recommend an option. No product implementation or gate result is represented by
this document.

## Bound evidence

- Rejected implementation head:
  `259d63523bbc5ef9cacc4340c3fa3eae1855b7ed`
- Frozen remediation head:
  `a1643b525f426d45501a2b479ec918d17bb04178`

The rejected head did not implement authoritative machine-credit buy-in,
cash-out, conservation, or hand-pay transactions. It presented bankroll as
credits, supplied cosmetic transaction renderers, invented a Video Poker
hand-pay threshold, left Video Poker action bindings disconnected, and did not
prove the required lifecycle, hostile-call, persistence, allocation, or
host-root authority behavior.

The frozen remediation removes those false claims, binds live surface
identities and Video Poker controls, roots Slot acknowledgement in the host run
state available at entry, and adds focused executable coverage. It intentionally
fails closed for buy-in and cash-out because no authorized machine-credit ledger
exists, and it does not invent a Video Poker hand-pay rule. It is therefore not
a review candidate while the authority decision remains open.

## Invariants under every option

Whichever option the owner selects:

- Existing odds, paytables, return-to-player behavior, detection, and heat rules
  remain unchanged.
- A local surface may not manufacture money, credits, payouts, hand-pay
  qualification, acknowledgements, or settlement results.
- Every value presented as authoritative must trace to the host-rooted authority
  selected by the option.
- Mutating commands require authoritative results, stable receipts, replay-safe
  idempotency, exactly-once settlement, and no duplicate payout.
- Persistence must define schema versioning, migration, save, restore, and
  reconciliation behavior for every newly authoritative value.
- Pointer, keyboard, and controller paths must converge on the same command
  boundary and result handling.
- Projection remains fail-closed: unavailable authoritative state must not be
  replaced by a plausible local value.
- Credits and bankroll/cash must not be labeled as each other.
- Per-frame polling must not become an alternate settlement or authority path.

Leaving the decision unresolved is not a closure path. `game06_4` remains
blocked, and the applicable portions of `game06_8` and `audio06_1` cannot close.

## Option A — one shared host-rooted machine authority

Authorize a single shared game-authority successor to own machine-credit and
hand-pay state. Slot and Video Poker consume that authority through the accepted
ritual command/result boundary; neither game owns a second ledger.

The shared authority owns:

- the bankroll/cash-to-machine-credit transfer and its inverse;
- the authoritative machine-credit balance and cabinet/session scope;
- atomic conservation across source funds, pending transfer, credits, payout,
  cash-out, and hand-pay settlement;
- hand-pay qualification supplied by authoritative game results or owner-authored
  policy, never by a consumer-local threshold;
- acknowledgement authorization and receipts;
- idempotency, duplicate-command handling, and exactly-once settlement; and
- schema versioning, migration, save, restore, and reconciliation.

`game06_4` would be limited to adapters, commands, result consumption, and
truthful presentation. The new shared authority must have its own explicitly
assigned owner before the frozen remediation is rebased or extended.

### Downstream implications

- **game06_1:** extend or clarify the ritual contract and acceptance checklist
  so the shared successor explicitly owns machine-credit cost authority,
  transfer receipts, hand-pay qualification, acknowledgement, conservation,
  and persistence. The shared successor requires review before Slot or Video
  Poker integration is reviewed.
- **game06_8:** retain the existing machine-credit, buy-in, cash-out, hand-pay,
  conservation, hostile-call, and save/revisit requirements. Gate evidence must
  exercise both the shared authority and each consumer without a second ledger.
- **audio06_1:** retain credit-in, credit-out, hand-pay, tower-light, and machine
  interaction profiles. Trigger sounds only from accepted shared facts or
  transition operations. Machine-profile work that needs these events waits for
  the accepted fact names.

### Owner values required to execute Option A

- source currency and authority;
- credit conversion unit, rate, rounding, minimums, and permitted increments;
- balance scope (cabinet, game instance, session, or another owner-defined
  scope);
- cash-out and terminal/exit treatment of remaining credits;
- hand-pay qualification source and policy configuration;
- acknowledgement actor and authorization rule; and
- save compatibility and migration policy for prior machine state.

This option adds shared scope, schema, migration, and review work. Its accepted
architecture contains one machine-credit ledger.

## Option B — direct-bankroll machines with no Video Poker hand-pay

Explicitly reduce the 0.6 machine requirements. Slot and Video Poker wager and
settle directly through the existing bankroll authority. They do not expose a
machine-credit balance, buy-in, or cash-out. Video Poker has no hand-pay flow.
Projection stays fail-closed, and the interface must call the value bankroll or
cash rather than credits.

This is a requirements amendment, not permission to simulate missing
transactions. The owner must explicitly decide whether Slot's existing
authoritative jackpot/attendant acknowledgement remains in scope.

### Downstream implications

- **game06_1:** no machine-credit authority is added. The contract records that
  these consumers use the existing bankroll command/result and payout facts.
  Any checklist language implying a universal machine-credit ledger must be
  scoped accordingly.
- **game06_8:** amend the machine gate before implementation review. For Slot and
  Video Poker, replace buy-in/cash-out/credit/Video-Poker-hand-pay expectations
  with direct-bankroll commitment, settlement, exactly-once payout, hostile-call
  rejection, and bankroll conservation. Do not accept cosmetic transaction
  panels as substitutes.
- **audio06_1:** remove Slot/Video Poker credit-in, credit-out, and Video Poker
  hand-pay obligations. Author only events that exist: machine controls,
  reels/cards, features, attract behavior, and any retained authoritative Slot
  jackpot/attendant transition. Do not synthesize transaction sounds from UI
  timers.

### Documentation amendments required to execute Option B

- `game06_4_machine_games_depth_prompt.md`: machine-depth contract and its
  acceptance/tests;
- `game06_8_games_depth_release_gate_prompt.md`: machine conservation and
  hand-pay acceptance language;
- `audio06_1_surface_sfx_pass_prompt.md`: machine-event scope; and
- the `game06_1` contract/checklist only where its wording would otherwise imply
  machine-credit or Video Poker hand-pay support for these consumers.

This option changes the promised 0.6 machine experience and avoids adding a new
ledger or migration. The scope reduction must be accepted before the frozen
remediation can be reviewed against the amended contract.

## Option C — game-local credit and hand-pay authorities

Authorize Slot and Video Poker to own local machine-credit ledgers and hand-pay
authority. This explicitly accepts two game-local authorities alongside the
existing bankroll authority and the resulting double-authority risk.

Each game-local implementation must own and document:

- a versioned credit-ledger and transaction schema;
- migration from every supported prior save shape;
- source-fund transfer, credit conversion, rounding, buy-in, and cash-out;
- atomic conservation and reconciliation across host funds and local credits;
- authoritative payout and hand-pay qualification without consumer-invented
  thresholds;
- acknowledgement authorization and stable receipts;
- idempotency, crash/retry behavior, and exactly-once settlement;
- save/restore behavior at every commitment, payout, lockup, acknowledgement,
  cash-out, exit, and revisit boundary; and
- ownership of abandoned or stranded credits.

A local ledger may not be a presentation cache. The owner must authorize the
cross-authority transfer protocol; direct independent mutation of host funds and
local credits would otherwise permit split-brain loss or duplication.

### Downstream implications

- **game06_1:** amend the ritual contract and checklist to permit bounded
  game-local funds authorities and to define their atomic handoff with host
  bankroll authority. Both implementations and their cross-authority protocol
  require review.
- **game06_8:** retain the original machine gate and expand its matrix to prove
  both schemas, all migrations, conservation, crash/save/retry boundaries,
  hostile calls, exit/revisit behavior, and duplicate prevention independently.
- **audio06_1:** retain the original machine-event scope, but bind Slot and Video
  Poker profiles to their separately accepted local facts and operations. Audio
  integration waits for both local schemas and event vocabularies.

### Owner values required to execute Option C

- the same currency, conversion, rounding, balance-scope, exit, hand-pay,
  acknowledgement, and migration values listed for Option A;
- the authorized host/local atomic transfer and recovery protocol;
- whether Slot and Video Poker schemas must remain identical or may diverge;
  and
- explicit acceptance of duplicate implementation, migration, reconciliation,
  and double-authority risk.

This option expands implementation and review across two ledgers plus their host
handoffs.

## Comparison

| Decision surface | Option A | Option B | Option C |
| --- | --- | --- | --- |
| Machine authority owner | One shared host-rooted successor | Existing bankroll authority only | Slot-local and Video-Poker-local authorities plus host bankroll |
| 0.6 requirement effect | Retains current machine depth | Reduces machine-credit and Video Poker hand-pay scope | Retains current machine depth |
| New schema/migration | One shared machine schema | None for machine credits | Two local schemas plus cross-authority recovery |
| Double-authority exposure | One machine ledger coordinated with host | No new ledger | Explicitly accepted across local ledgers and host |
| game06_1 | Extend shared authority contract | Scope consumers to existing bankroll facts | Permit and govern local funds authorities |
| game06_8 | Keep gate; prove shared authority and consumers | Amend gate before review | Keep and expand gate per local authority |
| audio06_1 | Keep machine transaction events; bind shared facts | Remove nonexistent transaction events | Keep events; bind two local vocabularies |
| game06_4 review path | Shared successor accepted, then integrate and review | Contract amendments accepted, then review aligned successor | Local authority successor implemented, then review |

## Owner response

Select exactly one without editing the evidence heads:

- [ ] **A** — authorize one shared host-rooted machine-credit and hand-pay
  authority.
- [ ] **B** — amend 0.6 to direct-bankroll Slot/Video Poker with no Video Poker
  hand-pay.
- [ ] **C** — authorize game-local credit and hand-pay authorities and accept the
  documented double-authority risk.

Also provide the values required by the selected option. For Option B, state
whether Slot's existing authoritative jackpot/attendant acknowledgement remains
in scope. Implementation assignment, contract amendment, or review submission
begins only after this owner response is recorded.
