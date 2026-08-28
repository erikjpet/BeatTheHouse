# game06_1 product second-rejection owner decision evidence

Status: **UNREVIEWED / OPTION-NEUTRAL / READ-ONLY**

Decision required: choose the disposition of the `game06_1` product runtime
after two independent rejections. This packet records three executable choices
without selecting, ranking or recommending one. No third ordinary remediation
cycle is authorized.

The accepted vocabulary contract is not rejected and is not reopened by this
packet. Product acceptance remains governed by the full row prompt at
`docs/todo/game06_1_table_machine_ritual_runtime_prompt.md`, the landed contract,
and its frozen validation fixtures unless Option C explicitly records a design
exception.

## 1. Exact authority and head inventory

Captured from the local repository on 2026-08-27. Every implementation and
intake must revalidate these identities against current accepted main.

| Classification | Exact commit | Tree | Consequence |
| --- | --- | --- | --- |
| current local `main` used by this packet | `9ea919fe9b53ab3ae37e085ed462febaa8ad76f8` | `8521ef294311e3bdcb32d51d644ac76bd425e841` | documentation base only |
| accepted frozen `game_ritual/1` contract | `a2760d816c781e711ff0923c296f97b786662453` | `1df3d9b767d7490acdffb291ce5220c0b409127e` | normative contract, fixtures and validation tests; remains accepted |
| landed contract merge | `6d8755394c6374ef66364f035e67827fb6e6bf6e` | `bf40316ef8bdc0b6f2ef3709e981a2d6b9b324dc` | merge of accepted contract into main; product runtime is not included by this merge |
| first rejected product | `44fefe5ffe599d8d75f03df33a2ceecd0a1c6fbd` | `ecbf2aa37bae9d7903fdcc3c52a9d5356390ad49` | first complete runtime candidate; frozen evidence |
| second rejected product | `932287ba0e049f1110cb748f02cb09047d3b42f5` | `9a33aebef2d37fc0093e6cca43bbc01fbc3710a0` | descendant of `44fefe5f` by three remediation commits; frozen after second rejection |

The three commits after the first rejection are `c5e5d4d5` (envelope and
restore remediation), `3e6fab15` (exact runtime records), and `932287ba`
(authenticated ritual boundaries). The remediation changes only:

- `scripts/core/game_ritual_runtime.gd`;
- `scripts/tests/foundation/game_ritual_runtime_contract.gd`; and
- `docs/plans/game06_1_runtime_proof_manifest.md`.

The complete candidate also contains the new ritual schema/layout/runtime,
opt-in table visual and canvas adapters, registered/focused tests and proof
manifest. At `932287ba`, key evidence blobs are:

| Path | Blob |
| --- | --- |
| `scripts/core/game_ritual_runtime.gd` | `de3a1ba666f654726be1b4302de63f55c46a60ad` |
| `scripts/core/game_ritual_schema.gd` | `1b8c485537eee1824c487c35aae414044c5afca5` |
| `scripts/core/game_ritual_layout.gd` | `558098cfcee16999fce39d280aa73714c253b32f` |
| `scripts/tests/foundation/game_ritual_runtime_contract.gd` | `10bd5b4ec03bc44ba559d6ac493b1f058adaa0f7` |
| `scripts/tests/game_ritual_runtime_test.gd` | `712d55dad8374e5226b999dbf16e3e233a757ca8` |
| `scripts/games/table_game_visuals.gd` | `5592a634e3a64f7937f60b513d53aae90ea2ad89` |
| `scripts/ui/game_surface_canvas.gd` | `094e9c1c00ad1392d22e08d395e7ae98a2686c85` |

These are evidence identities, not accepted product baselines. Neither rejected
head may be imported, copied wholesale, or used as a new consumer authority. An
authorized continuation starts from then-current accepted main and replays only
reviewed net payloads by three-way semantic application. The Integrator may
review, gate and land an accepted candidate; it may not implement the closure.

## 2. Full prompt and landed-contract boundary

The full product row must still:

- harvest and re-express the accepted Craps ritual without a Craps branch;
- provide one versioned neutral ritual runtime covering phases, staged
  commitment, equivalent pointer verbs, actors, scene objects, energy, facts,
  handlers and persistence;
- extend visuals/canvas/layout validation opt-in while keeping every unadopted
  game byte-for-byte equivalent;
- preserve game-owned seeded outcomes, action-boundary facts, native/Web parity
  and liveness/performance constraints; and
- prove malformed definitions/actions, hostile authority, phase properties,
  opt-out behavior, Craps re-expression, accessibility and every save boundary.

The landed contract's non-negotiable authority rules include one authoritative
command/result boundary, closed records, exact canonical fingerprints,
handler-specific allowlists, side-effect-free rejection, private-by-default
state and authenticated restore/migration. A passing row-local test cannot
replace those invariants.

Because the reference `craps06_3` product is itself unresolved, no option may
claim the required accepted Craps re-expression until an accepted Craps head is
available. Contract-only conformance examples remain specification evidence,
not the product proof required by the full prompt.

## 3. First rejection: `44fefe5f`

The first product supplied neutral schema/layout/runtime modules, opt-in visual
and pointer adapters, tests and a proof manifest. It was rejected because:

- the runtime accepted a reduced synthesized action call rather than the full
  closed authenticated `RitualCommand` envelope;
- result, rejection, fact, receipt, request-cache and error records remained
  open or ad hoc;
- a registered handler could emit operations or facts belonging to another
  handler; and
- restore accepted open unauthenticated state.

The exact head and its reported passing gates remain preserved, but its product
authority was not accepted. Any consumer branch based on it is rejected-runtime
ancestry and cannot be integrated as authority.

## 4. Second rejection: `932287ba`

The remediation materially added compliant work:

- complete `RitualCommand` closed-shape, fingerprint, phase, boundary, receipt
  and authenticated-origin validation;
- closed fingerprinted `RitualResult`, `RitualRejection`, `GameFact`,
  `OperationResult`, `ReceiptRecord` and `RequestCacheRecord` shapes;
- per-handler accepted-operation and emitted-fact allowlists with hostile
  cross-handler negatives; and
- authenticated closed snapshot validation plus hostile restore/migration
  fixtures.

That work is preservable only through semantic extraction and independent
review. The second candidate remains rejected for four related authority gaps:

1. `process_command()` validates the closed authenticated command but then calls
   public `process_action()`. External code can call `process_action()` directly
   and reach the complete mutation/handler/phase/fact path without the envelope,
   trusted-origin, boundary or receipt authority.
2. Public `set_energy_tier()` independently mutates actor/object/interactable
   state and request cache without the sole command boundary.
3. Public raw `restore()` installs state without the outer authenticated
   snapshot; `restore_snapshot()` therefore does not own the only restore path.
4. Top-level closed shapes do not fully close nested semantic authority. Known
   actor/object ids are insufficient unless pose/behavior/anchor and
   visual/functional/enabled values are declared; item collections, readable
   totals, handler state, receipt identity/order, cache bindings and nested
   result/fact/operation relationships must all be typed, bounded, owned and
   cross-checked. A well-shaped but semantically forged nested value can remain
   authoritative.

Additionally, a valid-envelope command that is rejected after ingress currently
updates caches/state and emits command/rejection receipts. The accepted contract
requires atomic authoritative pre-state preservation. A closed rejection
envelope may be returned, and a separately declared bounded non-authoritative
diagnostic may exist, but rejection may not become a second durable game-state
mutation boundary.

Together these gaps mean the product has multiple authorities even though its
new envelope records are individually closed.

## 5. Inherited consumer risk: game06_2 through game06_7

The contract-first program permits row-local consumer design against landed
`a2760d81`/`6d875539`; it does not permit any consumer to import either rejected
product. Product integration remains blocked until an owner-selected game06_1
successor lands.

| Consumer | Inherited risk from alternate authority |
| --- | --- |
| `game06_2` Blackjack | split/double/insurance/settlement can enter through direct action and authenticated command paths, producing duplicate charges, facts, receipts or restore divergence; old `2def171d` is based on rejected `44fefe5f` and must not be integrated |
| `game06_3` Baccarat/Roulette | tactile phase input and mid-ritual save can disagree between envelope and raw restore paths; its independent rejection history does not make either game06_1 product acceptable |
| `game06_4` machine games | credits, spins/hands, hand-pay and energy/liveness staging can mutate through a bypass, creating replay or native/Web ordering differences |
| `game06_5` counter games | ticket/tab purchase, partial reveal and redemption persistence can accept forged nested items/totals or replay across raw restore |
| `game06_6` bar dice | dice/street facts and energy share the unresolved Craps pattern; alternate mutation can publish or stage a different boundary than the environment consumer observes |
| `game06_7` duel/showdown | commitment, outcome ladder and both endings can double-fire or restore inconsistently; it also inherits `game06_2`'s dependency risk |

All six consumers risk implementing different answers to which API is
authoritative. That divergence is the principal shared-runtime hazard: local
tests may pass while composition, restore, receipts and cross-system facts do
not agree. `game06_8` Family 1 closure cannot accept any consumer whose authority
or restore path differs from the selected game06_1 contract/product boundary.

## 6. Option A: same-scope single-authority redesign

Owner statement: retain the full landed contract and full product prompt,
preserve compliant remediation work, and authorize one exceptional
post-second-rejection redesign and review.

### Implementation consequence

- Create a fresh implementation branch from exact current accepted main.
  Semantically replay reviewed schema/layout/visual/canvas work and the compliant
  closed envelope/result/allowlist validators from `932287ba`; never copy the
  rejected runtime wholesale.
- Make one authenticated command reducer the only mutation entry. Direct action
  and energy calls become non-public internal reducer steps or construct and
  traverse the same complete authenticated command boundary. There is no path
  that can invoke handlers, mutate a phase/item/actor/object/energy value,
  publish facts or write receipts/caches without it.
- Make authenticated snapshot/migration validation the only restore entry. Raw
  state installation is internal to that validator and cannot be called by a
  game, UI, save loader or test.
- Validate every nested state and record recursively: exact keys/types/bounds,
  declared ids and value sets, ownership, item schemas, total conservation,
  handler-specific persisted state, sequence/boundary monotonicity, receipt
  uniqueness and cause, cache-to-command/response bindings, and canonical
  fingerprints. Unknown, ambiguous, stale or semantically impossible nested
  authority fails closed.
- A rejected command returns its closed deterministic `RitualRejection` while
  preserving byte-identical authoritative state, RNG position, phase, caches,
  receipts, facts, operations, projection one-shots and handler state. Any
  diagnostic is separately declared, bounded and non-authoritative.
- The accepted Craps product must be re-expressed through this sole boundary
  without a special case before final acceptance.

### Acceptance consequence

Hostile tests must enumerate every public method and prove only the authenticated
command and authenticated restore adapters can mutate. For each mutation family,
execute direct-call, forged nested state, cross-handler, replay/conflict,
valid-command rejection, hostile restore and migration negatives; compare the
complete pre/post state and RNG. Run the full prompt's opt-out eleven-game,
Craps, phase property, native/Web, determinism, performance/liveness,
accessibility, visual and save gates on one immutable head.

Only one exceptional review is authorized. A rejection returns to the owner,
not another ordinary remediation cycle. `game06_2` through `game06_7` remain
blocked from product integration until this candidate and the required accepted
Craps re-expression land. Their contract-only WIP may remain preserved without
rejected runtime ancestry.

## 7. Option B: partial split plus authority-consolidation successor

Owner statement: preserve independently compliant closed-record work as a
partial delivery, open a named successor for the single authority boundary, and
keep every product consumer blocked.

### Exact partial boundary

Original `game06_1` becomes `PARTIAL - CLOSED PRIMITIVES / AUTHORITY SUCCESSOR
REQUIRED`, never `DONE`. A fresh partial candidate may contain:

- independently reviewed schema/layout validation and opt-in visual/canvas
  adapters extracted from the rejected candidate;
- pure closed `RitualCommand`, result, rejection, fact, operation-result,
  receipt and request-cache shape/canonical-fingerprint validators/builders; and
- pure handler operation/fact allowlist validation plus hostile fixtures.

The partial candidate exports no callable mutating runtime. It must extract the
listed code into a reviewed non-authoritative primitive boundary or otherwise
prove that `process_action`, `set_energy_tier`, raw `restore`, handlers and state
installation cannot be reached. It excludes runtime acceptance claims,
authenticated restore acceptance, Craps product re-expression and all consumer
integration. An exact path/hunk and public-symbol manifest is required; neither
rejected head lands wholesale.

Create successor row `game06_1b` (`Ritual Authority Consolidation`). It owns:

- the sole authenticated command reducer and internal action/energy steps;
- the sole authenticated snapshot/migration restore boundary;
- recursive nested semantic authority and conservation;
- side-effect-free rejection and exact replay/cache/receipt behavior;
- complete adopted-Craps re-expression and opt-out proofs; and
- final production composition and all full-prompt gates.

### Dependency consequence

`game06_1b` depends on the accepted partial primitives and an accepted
`craps06_3` reference head. `game06_2`, `game06_3`, `game06_4`, `game06_5`,
`game06_6` and `game06_7` all remain product-integration blocked until
`game06_1b` lands. They may not import the partial library as a runtime, copy
rejected adapters, or invent row-local authority. `game06_8` remains blocked on
the successor and all consumers.

The successor has its own review accounting, but the two product rejections and
all findings in section 4 stay binding evidence. Splitting the row does not
reset or waive them.

## 8. Option C: compatibility/design exception for alternate authority

Owner statement: retain the multiple public mutation/restore authorities as a
deliberate compatibility design and accept their risks under a versioned,
explicit exception.

Record exception `GAME-RITUAL-AUTH-EXCEPTION-01` with these exact allowances:

1. `process_command()` is the authenticated envelope path, while public
   `process_action()` remains a trusted in-process action/handler/phase/fact
   mutation path that does not require a `RitualCommand`.
2. Public `set_energy_tier()` remains a separate trusted in-process
   actor/object/interactable and request-cache mutation path.
3. `restore_snapshot()` remains the authenticated external restore path, while
   public raw `restore()` remains a trusted save-loader state-install path
   without the outer snapshot fingerprint.
4. Nested state validation may enforce top-level closed shape and known ids
   without fully proving every nested declared value, collection schema,
   conservation relation, handler state, receipt cause/order or cache binding.
5. A valid-envelope rejection may write its bounded request-cache response and
   command/rejection receipt records while leaving money, phase, items,
   actors/objects, handler-owned game state, facts, operations and RNG unchanged.

### Required compatibility controls

The owner must add the exception to the landed contract as an explicit addendum
or new version; the product may not claim unqualified conformance to frozen
`a2760d81`. Every alternate method must declare trusted callers, allowed fields,
ordering relative to the envelope path, replay semantics and save/migration
scope. Tests must execute both paths, prove their stated mutation limits, and
lock the exact rejection-cache/receipt exception. Public documentation and
release evidence must state that one authoritative command/restore boundary is
not guaranteed.

Each `game06_2` through `game06_7` implementation must choose and record one
call/restore profile. A consumer that mixes profiles must prove cross-path
idempotency, ordering, receipts, facts, money conservation, save/revisit and
native/Web parity. The six risks in section 5 are accepted design risk under
this option, not defects silently transferred to consumer squads.

Consumers remain blocked until the exception contract/addendum and an immutable
compatible game06_1 product pass independent review, accepted Craps
re-expression and all remaining full-prompt gates. `game06_8` must be amended to
audit the selected compatibility profiles and cannot claim single-authority
closure. If any consumer or closure gate still requires the original sole
boundary, the owner must name a successor restoring it before that dependency
can clear.

## 9. Owner record required to resume

The decision record must state exactly `A`, `B` or `C`, owner and timestamp. It
must additionally name:

- for A, the single-authority implementation owner and one exceptional-review
  authorization;
- for B, successor `game06_1b`, its owner, the exact partial manifest and all
  held consumers; or
- for C, exception `GAME-RITUAL-AUTH-EXCEPTION-01`, the contract/addendum
  identity, trusted callers, consumer profiles and amended `game06_8` claims.

Until that record exists, `44fefe5f` and `932287ba` remain frozen rejected
evidence. No agent may infer a choice, no consumer may treat either as authority,
and the Integrator may not implement a resolution.
