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

## Two independent decision axes

The earlier packet coupled credit storage and hand-pay scope. They are separate
authority decisions. Select one wagering option and one hand-pay option; do not
infer either selection from the other.

### Wagering axis W0 — existing direct-bankroll authority

Slot and Video Poker commit wagers and receive settlement through the existing
authoritative bankroll command/result boundary. They expose no machine-credit
balance, buy-in, or cash-out and add no credit-ledger schema. Projection stays
fail-closed, and the surface labels the value bankroll/cash rather than credits.

Required proof includes authoritative cost validation, exactly-once settlement,
hostile/replayed request handling, bankroll conservation, and save/revisit. This
option changes the current credit/buy-in/cash-out requirements but does not by
itself decide whether Video Poker or Slot has a hand-pay flow.

### Wagering axis W1 — one shared host-rooted credit ledger

Authorize one shared game-authority successor to own bankroll-to-credit transfer,
machine-credit balance, cash-out, conservation, stable receipts, idempotency,
schema/migration/save/restore, and reconciliation. Slot and Video Poker consume
it; neither owns a second ledger.

Owner values required: source currency, conversion unit/rate/rounding/minimums,
balance scope, exit treatment for remaining credits, and migration policy.

### Wagering axis W2 — game-local credit ledgers

Authorize Slot and Video Poker to own separate local ledgers alongside host
bankroll authority, explicitly accepting double-authority risk. Each game owns
its schema/migration, conversion, buy-in/cash-out, receipts, idempotency,
save/restore, abandoned-credit policy, and reconciliation. The owner must define
an atomic host/local transfer and recovery protocol; independent mutation of
host funds and local credits is not sufficient.

Owner values required are those for W1 plus whether schemas may diverge and
explicit acceptance of duplicated implementation, migration, reconciliation,
and split-brain risk.

### Hand-pay axis H0 — no Video Poker hand-pay

Video Poker has no hand-pay qualification or acknowledgement flow. This is an
explicit scope amendment, independent of whether wagering uses direct bankroll
or credits. The owner separately states whether Slot's existing authoritative
jackpot/attendant acknowledgement remains in scope.

### Hand-pay axis H1 — shared host-rooted qualification and acknowledgement

Retain an authoritative Video Poker hand-pay flow without requiring a credit
ledger. The accepted game result, or owner-authored policy applied to that exact
result by a shared host authority, supplies qualification. The host owns lockup,
acknowledgement authorization, stable receipts, replay/idempotency,
exactly-once payout release, save/restore, and reconciliation. Video Poker may
request and render the flow but may not invent a threshold or settle it locally.

H1 is compatible with W0. The specific **W0 + H1** combination therefore uses
the existing authoritative direct-bankroll wager/settlement path, adds no credit
ledger, and retains authoritative Video Poker hand-pay qualification and
acknowledgement derived from the accepted result/policy. The hand-pay boundary
must not duplicate the bankroll payout or create a second funds ledger.

H1 may also combine with W1 or W2. In those combinations the hand-pay authority
must name which authoritative balance receives or releases settlement and prove
that the credit and bankroll authorities cannot both pay the same result.

### Hand-pay axis H2 — game-local qualification and acknowledgement

Authorize each game to own its hand-pay policy, lockup, acknowledgement,
receipts, idempotency, persistence, and payout-release boundary. Qualification
must still derive from the accepted authoritative game result and owner-authored
policy, never a renderer threshold. This option accepts duplicated authority and
review scope independently of the selected wagering architecture.

H2 combined with W0 does not create a credit ledger, but it does create local
hand-pay authority adjacent to host bankroll settlement. H2 combined with W1 or
W2 must define atomicity between hand-pay release and the selected credit
authority.

## Combination matrix

No cell is recommended. Every cell requires an explicit owner selection and the
listed contract changes before implementation or review.

| Combination | Funds state | Video Poker hand-pay state | Principal authority consequence |
| --- | --- | --- | --- |
| W0 + H0 | Existing bankroll only | None | Credit/buy-in/cash-out and VP hand-pay scope are removed. |
| W0 + H1 | Existing bankroll only | Shared host-rooted | No credit ledger; host result/policy qualifies and acknowledges hand-pay without duplicate payout. |
| W0 + H2 | Existing bankroll only | Game-local | No credit ledger; owner accepts local hand-pay authority beside host settlement. |
| W1 + H0 | One shared credit ledger | None | Shared conversion/migration exists; VP hand-pay scope is removed. |
| W1 + H1 | One shared credit ledger | Shared host-rooted | Shared ledger and hand-pay may be one successor or separately bounded shared services. |
| W1 + H2 | One shared credit ledger | Game-local | Local hand-pay must atomically release against the shared ledger. |
| W2 + H0 | Two game-local credit ledgers | None | Local ledger duplication exists; VP hand-pay scope is removed. |
| W2 + H1 | Two game-local credit ledgers | Shared host-rooted | Shared hand-pay must identify and reconcile the relevant local ledger. |
| W2 + H2 | Two game-local credit ledgers | Game-local | Maximum duplicated schema, migration, reconciliation, and authority scope. |

## Downstream consequences by axis

### game06_1

- W0 records Slot/Video Poker as consumers of existing bankroll cost and payout
  facts; no credit schema is added.
- W1 extends the shared contract with credit transfer, balance, conservation,
  receipts, and persistence.
- W2 permits bounded game-local funds authorities and defines their atomic host
  handoff.
- H0 adds no Video Poker hand-pay authority.
- H1 adds shared qualification, lockup, acknowledgement, payout release,
  idempotency, and persistence from authoritative results/policy.
- H2 permits bounded game-local hand-pay authority and defines its atomic payout
  handoff.

Any selected extension needs its own authorized owner and acceptance review
before `game06_4` integration review.

### game06_8

- W0 requires amending credit/buy-in/cash-out expectations to direct-bankroll
  commitment, settlement, hostile-call rejection, and conservation.
- W1 retains the current credit/conversion gate and proves one shared ledger
  through both consumers.
- W2 retains and expands the gate for two schemas, migrations, crash/retry,
  reconciliation, and duplicate prevention.
- H0 removes Video Poker hand-pay expectations while leaving the separately
  selected Slot acknowledgement scope explicit.
- H1 retains hand-pay lifecycle tests against the shared authority, including
  accepted-result qualification and no duplicate payout.
- H2 retains and expands hand-pay lifecycle tests per game-local authority.

### audio06_1

- W0 removes Slot/Video Poker credit-in and credit-out events; W1/W2 retain them
  and bind sounds to accepted shared/local transition facts.
- H0 removes Video Poker hand-pay audio; H1/H2 retain it and bind audio only to
  the selected authoritative qualification/lockup/acknowledgement operations.
- Slot's tower-light/jackpot audio follows the separately confirmed Slot scope.
  No UI timer or projection may synthesize an authority event.

## Required documentation and review path

For W0, amend `game06_4_machine_games_depth_prompt.md` and
`game06_8_games_depth_release_gate_prompt.md` so direct-bankroll behavior is the
truthful contract. For W1/W2, retain credit requirements and authorize the
selected schema owner. For H0, amend the Video Poker hand-pay requirements. For
H1/H2, retain them and add the selected qualification/acknowledgement boundary.
Amend `audio06_1_surface_sfx_pass_prompt.md` only to match the selected event
set, and amend the `game06_1` contract/checklist for every new authority it must
own or permit.

After documentation/contract acceptance:

- W0 + H0 may align the frozen remediation with the reduced contract before
  independent review.
- W0 + H1 requires a shared hand-pay successor, then integration and review; it
  does not require a machine-credit ledger.
- every W1 combination requires the shared credit successor before integration;
- every W2 combination requires both local credit implementations and their
  host transfer protocol before review; and
- every H2 combination requires the authorized local hand-pay implementation
  before review.

The rejected and frozen heads remain evidence only throughout these paths.

## Owner response

Select exactly one wagering option and one hand-pay option without editing the
evidence heads:

- Wagering: [ ] **W0** direct bankroll; [ ] **W1** shared credit ledger;
  [ ] **W2** game-local credit ledgers.
- Video Poker hand-pay: [ ] **H0** none; [ ] **H1** shared host-rooted;
  [ ] **H2** game-local.
- Slot existing jackpot/attendant acknowledgement: [ ] retain; [ ] remove;
  [ ] owner clarification required.

For W1/W2, provide currency, conversion, balance-scope, exit, and migration
values. For H1/H2, provide the policy source/configuration, acknowledgement actor
and authorization, payout-release target, exit/recovery behavior, and migration
policy. Implementation assignment, contract amendment, or review submission
begins only after both axes and the required values are recorded.
