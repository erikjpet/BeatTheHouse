# fix06_24 owner decision: upper-row join disposition

Status: **UNREVIEWED / OPTION-NEUTRAL / DECISION REQUIRED**

This packet presents only the two dispositions authorized by the binding board
row. It does not select, rank or recommend either option. No product, evidence
tool, gate, assertion, budget, geometry or machine behavior is changed here.

## Binding record and absent row prompt

The binding `fix06_24` board row is preserved at board commit
`a3865e4db286f1c876b03012eacfb93f699a0688` (tree
`8db798674ef464734ad075f8e3b1bc5474fb504b`). It classifies `fix06_24` as a
blocked product-physics defect requiring an owner decision and binds it to exact
`fix06_8` evidence `1f0595af`.

No `fix06_24` row prompt currently exists on main
`00ee744fa6269e8a7eb34f67b2659f32d55febaa`; specifically,
`docs/todo/fix06_24_coin_pusher_adjacent_coin_movement_defect_prompt.md` is
absent. The path named by the preserved board record is therefore not a current
binding prompt. This decision packet derives no additional implementation scope
from an unlanded or inferred prompt.

The exact evidence commit is
`1f0595af567494f1c7d69f319a1ee8e4bead26dc`, tree
`217fa051986dbd9172c777a69ed7a729e25244f2`, parent
`68de0a30527c737ee8486c33423352b2b51d4618`. It is an empty evidence-preserving
commit: its tree equals its parent's tree. Its immutable commit record binds:

- actual-GL manifest SHA-256
  `AFA40DF473C264D87A69C7D9BD38D3823DCCFC9B2E5E7FDC6A5D0B13D2EC1DF8`;
- native Windows debug DLL SHA-256
  `56B26FF9218EB5BCDB605418AB6FA6CF215CBB741DF8CB346170DA335C34165A`;
- all fixed-trace setup predicates passed except qualified adjacency;
- movement was not demonstrated; and
- the retained red was classified as a separate product-physics defect, with
  no rerun or search.

The binding board detail adds that the fixed trace covered idle, baseline,
twelve priming drops, tracked paid drop, support, ticks, phase, final root and
strip checks. Quarter Falls, Jackpot Ridge and Vault Drop each had zero
qualified adjacent pre-existing platform coins. Thus the evidence did not reach
the prerequisite population on which the required neighbor movement could be
measured. It does not prove that an adjacent qualified neighbor stayed still;
it proves that none existed at the tracked first-support event.

The governing Plan 9.4 requirement, as carried by the accepted `fix06_8`
evidence contract, is a production drop that lands beside existing upper stock
and advances that local row. Qualification requires platform-rooted first
support, strictly adjacent pre-existing platform-rooted coin neighbors, and a
comparison of those exact neighbors from first support through one
phase-matched complete stroke.

## Freeze before decision

Until the owner records Option A or Option B, all of the following remain
prohibited:

- rerunning the trace or any related capture/gate to seek a different result;
- seed, control, timing, action, nozzle or initial-condition search;
- weakening, widening or substituting the strict adjacency predicate;
- editing any nozzle, geometry, transport, contact or neighboring/opening-stock
  behavior or data;
- changing solver, live-session, renderer, machine tuning, physics, RTP, EV,
  payout, odds, wager math, RNG, schema, migration, golden or budget; and
- claiming movement, Plan 9.4 closure, `fix06_24` completion or
  `pusherv3_11` closure from evidence `1f0595af`.

Classification does not authorize remediation. Evidence `1f0595af` remains the
only fixed-trace record for this decision and must not be replaced or erased by
a later result.

## Option A: authorize a separate product-physics remediation

Owner statement: authorize a separately scoped product-physics row whose
acceptance condition is that a fixed production control/nozzle trace:

1. uses the production opening, production control, production action/resolve/
   drop queue and live-session advancement path;
2. emits the tracked paid production drop;
3. records that drop's first support as platform-rooted in both the authoritative
   support event and an independent body view;
4. finds at least one strictly adjacent, qualified, pre-existing,
   platform-rooted platform coin at that exact first-support moment; and
5. proves that those exact identified neighbors move through one complete
   platform stroke measured at matching platform phase.

The authorized row must name its exact permitted physics surface before editing
and must preserve the fixed trace, strict adjacency, platform-root, exact-neighbor
identity, phase matching, idle control and fail-closed evidence requirements.
It may not turn into seed/control search, broaden the neighbor set after first
support, accept newly emitted or non-platform-rooted bodies, scan unrelated
coins, or substitute visible motion for exact-body movement.

Consequences of Option A:

- Product behavior may change only inside the separately authorized and bounded
  remediation scope; this packet itself authorizes no file edit.
- The production control/nozzle path must reliably create the qualified physical
  contact topology, not merely make the evidence tool pass.
- Existing machine identity, playability, transport, contact, stock stability,
  determinism, native/Web parity, performance, RTP/EV/economy, save behavior and
  visual presentation become mandatory non-regression surfaces for the
  remediation.
- Evidence `1f0595af` remains the retained pre-fix red. A post-fix trace is new
  evidence and cannot rewrite the prior result.
- `fix06_24` remains blocked until independent review and the separately
  authorized acceptance evidence establish both qualified adjacency and exact
  neighbor movement over the phase-matched full stroke.
- `pusherv3_11` remains blocked on `fix06_24` plus all of its other unmet closure
  conditions; authorization alone is not closure.

## Option B: explicitly revise or cut the Plan 9.4 requirement

Owner statement: revise or remove the Plan 9.4 upper-row-join requirement that a
production drop land beside qualified pre-existing upper stock and move those
exact neighbors over a phase-matched complete stroke.

The owner record must state the replacement requirement, if any. It must say
whether production drops may remain isolated from pre-existing upper stock,
whether local-row transmission is no longer a product promise, and which
evidence scenes/claims are retired rather than silently treated as passing.

Consequences of Option B:

- No product-physics remediation is authorized or required for the specific
  absent-adjacent-stock finding in `1f0595af`.
- Evidence `1f0595af` stays red against the old Plan 9.4 requirement; the old
  requirement is explicitly revised/cut rather than reinterpreted as satisfied.
- The Plan 9.4 document, `fix06_8` disposition, `fix06_24` board record,
  `pusherv3_11` closure criteria and every dependent audit/visual manifest must
  be amended to identify the retired claim and any replacement acceptance
  condition.
- Any player-facing or audit claim that paid drops join and advance an existing
  upper row must be removed or rewritten consistently. No DONE claim may retain
  the old wording.
- Tests or evidence tooling whose sole purpose is the cut requirement must be
  retired through an explicit reviewed change, not weakened, skipped or made
  unconditionally green.
- `pusherv3_11` remains blocked on its other required EV, determinism,
  native/Web parity, lifecycle, performance, broad-suite and visual evidence;
  revising this one requirement does not satisfy those conditions.

## Owner record required

To resume, record exactly `A` or `B`, owner and timestamp.

- For A, name the new product-physics row, exclusive implementation owner,
  exact permitted edit surface and unchanged non-regression requirements.
- For B, provide the exact replacement/cut Plan 9.4 wording and name every
  plan, board, audit, test/evidence and `pusherv3_11` claim that must change.

Until that record exists, no agent may infer authority from this packet. The
no-rerun/no-search/no-edit freeze remains in force.
