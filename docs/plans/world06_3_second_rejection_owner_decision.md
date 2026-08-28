# world06_3 second-rejection owner decision evidence

Status: **UNREVIEWED / OPTION-NEUTRAL / READ-ONLY**

Decision required: choose the disposition of the independent Numbers depth
model after two product rejections. This packet records three executable choices
without selecting, ranking or recommending one. No third ordinary remediation
cycle is authorized.

This is documentation-only owner prestage. It does not edit or authorize edits
to the world lane's exclusive Numbers model, authored data, tests, adapters,
routes, crew/world models or integration files.

## 1. Binding prompt and exact-head inventory

Captured from the local repository on 2026-08-28. Every continuation must
revalidate these identities against the accepted world06_1/world06_2 authority
and current main at implementation and intake.

| Classification | Exact commit | Tree | Consequence |
| --- | --- | --- | --- |
| current local `main` used by this packet | `232ec7d6be3947ef3a5195f3c380ae0b624430e5` | `df19fba31b62495dc1fb0d076e7856b3374d4004` | documentation base only |
| full row prompt | `docs/todo/world06_3_numbers_depth_prompt.md` | current accepted file at intake | unchanged Numbers math/economy plus full physical book/slip/draw/routes/rig/persistence/evidence scope remains binding unless an option explicitly narrows it |
| proof predeclaration | `d1e0acd88e4644df9b063b7ffb1d9d8e603a92ac` | `63dde957b0605ee79f963d20e9deadd7007a953f` | proof-only ancestor; not product acceptance |
| non-economic semantics ancestor | `7b024b164dbc7dc499ff45ed007e112679657058` | `24a9a884229dcd4ab3416189b3fabdd5138bbb99` | exact parent of first rejected product |
| first rejected product | `8cde9f9be16d445ab85ed6f9cbab1548183f68ac` | `bc8b98eaf6a134876a930a8ee7eabe015b1a648f` | frozen first candidate |
| second rejected product | `e7aca3478bade4568c8c29ea109f799fd4f0a249` | `3af0dbc3d0133ee21eb13cf1ccc40cf1e323978e` | direct child of `8cde9f9b`; frozen after second rejection |

The first product changed only `scripts/core/numbers_model.gd` after its
semantics/proof ancestors. The second product changes exactly:

- `scripts/core/numbers_model.gd`; and
- `scripts/tests/foundation/world06_3_numbers_depth_contract.gd`.

At the second head those blobs are respectively
`2437074c3b02a57032234cc61cf8b3d2e18186c4` and
`8a16200d319229b73f7bb0330d1b83b5f52fd750`. The unchanged
`data/crew/numbers.json` blob is
`ef50f49248881a3091e154d74f0ee08d358d87ba` at both rejected heads.

These are evidence identities, not accepted implementation bases. Both rejected
heads remain preserved. Any authorized continuation belongs to the exclusive
world implementation/model owner, starts from the accepted dependency base and
replays reviewed net payload semantically. The Integrator reviews, gates and
lands; it does not implement a closure.

## 2. Full contract boundary

The full prompt preserves the shipped daily seeded draw, timing, odds, payouts,
bet limits, route economics, trust, grievance, detection, bribe, camouflage,
player cut, debt and rumor truth exactly. Depth work may stage people, places,
physical slips, attendance, collection, routes and rig tells; it may not create
a second economic or draw authority.

It also requires exactly-once persistence across save, exit, travel, revisit and
expiry for slips, wins, debts, grievances and aftermath. A bookmaker's memory,
draw attendance or slip location is authoritative depth state only when its
cause is authenticated and compatible with the already-authoritative Numbers
record. Restore shape alone is insufficient.

World06_1 owns the host adapter/receipt boundary and world06_2 owns delivery
runner routing. The independent world06_3 package may propose work without those
dependencies, but cannot mint their authority or claim integration/landing.

## 3. First rejection: `8cde9f9b`

The first candidate added physical slips, bookmaker place/state/aftermath, draw
occasion attendance and staged depth actions. It also minted a model-local
receipt/hash chain. Independent review rejected the product because the public
self-hash was not a host-rooted authority: a caller could recompute a coherent
chain and matching state. Public depth actions could mutate authority, draw
attendance could be asserted retroactively, and restored chains/state remained
forgeable. The package also lacked the authoritative world06_1/world06_2 bridge
needed to commit the staged placement, collection, past-post and runner work.

The candidate's unchanged numeric configuration and row-local green evidence do
not make its model-minted authority acceptable.

## 4. Second rejection: `e7aca347`

The remediation materially corrected several first findings:

- depth actions and place-slip/collect-payday/solo-past-post sequences became
  explicit non-mutating proposals requiring host presence, proximity and a host
  command/transaction;
- model-minted action receipts and sequence fields were removed from snapshots;
- every imported nonempty or malformed receipt chain rejects restore; and
- draw attendance is pre-post only, with uncommitted absence terminal at the
  posting boundary.

Those changes are preservable evidence, not acceptance. Restore still loads
depth-owned fields after checking only that `action_receipts` is empty and
`action_sequence` is zero. A caller can take a rejected/forged predecessor,
delete those receipt keys, and import the remaining depth records as if they
were an ordinary compatible save. This is a stripped-record anti-downgrade gap.

The affected depth records include:

- `draw_occasions`, including attendance/presence, venue, post/resolution state;
- `bookmaker_aftermath`, including friendly/suspicious/past-post, collection and
  local-memory consequences; and
- each slip's nested physical identity/location/holder/state/visibility record.

Four hostile families remain mandatory findings under Option A:

1. **Predecessor snapshot minus receipts.** Start with a rejected or forged
   snapshot whose depth mutation and receipt chain agree, then remove
   `action_receipts`/`action_sequence`. Restore must not reinterpret the result
   as a trusted predecessor or legacy save.
2. **Present without host.** A snapshot cannot claim a player was present at a
   draw unless a host-rooted pre-post attendance cause belongs to that exact
   day, venue, run/context and posting boundary. A caller-authored `present`
   occasion must fail closed.
3. **Unsupported physical slip states.** Unknown state/visibility values and
   impossible holder/node/place/status combinations must reject. Known words do
   not suffice when the physical relation is impossible or lacks its exact
   causal transfer.
4. **Causal mismatch.** Draw occasion, slip, collection and bookmaker aftermath
   must agree with the exact authoritative draw/slip/settlement/detection/host
   cause. Cross-day, cross-venue, cross-slip, future-boundary, payout, memory or
   sequence substitutions must reject even when every individual record is
   well-shaped.

## 5. Migration, privacy and economy baseline

All options must state their treatment of three save classes:

1. a genuine pre-depth legacy Numbers save with no depth-version marker or
   depth fields;
2. a current authenticated depth save with complete causal authority; and
3. a stripped or partially copied record that claims depth effects without the
   required cause.

Privacy requires that no save/projection reveal or imply a draw before its
posting boundary, retroactively create presence, expose a fix to an unqualified
player, or create an untruthful rumor/aftermath. Economy requires unchanged
numeric tables and also causal eligibility: a caller-authored carried slip,
friendly bookmaker, collection memory or attendance state cannot silently
enable/deny payout, debt, trust, grievance, access or detection consequences.

The owner choice below determines whether these are fail-closed invariants,
excluded non-authoritative scope, or accepted compatibility risk.

## 6. Option A: bounded fail-closed restore closure

Owner statement: retain the full row scope and authorize one exceptional
post-second-rejection restore remediation and review.

### Implementation consequence

The exclusive world owner creates a fresh successor from the accepted
world06_1/world06_2 dependency base and preserves the non-mutating proposal work.
Restore becomes a versioned causal migration boundary:

- A genuine pre-depth legacy save is recognized by an exact predecessor schema
  and exact allowed key set, not merely by absent receipt fields. It migrates to
  deterministic empty/derived depth defaults without inventing attendance,
  physical transfers or aftermath.
- A current depth save requires an exact depth version plus a host-rooted cause
  chain anchored to the accepted world adapter. Every persisted depth record is
  closed, typed, bounded and linked to exact run/context, model identity,
  action/boundary, predecessor digest and authoritative source record.
- A record that carries any depth field but lacks its required version/cause is
  neither legacy nor current; it rejects atomically and leaves the model at its
  pre-restore state.
- Physical slip validation checks item/instance identity, allowed state and
  visibility, holder/place/node relationships, slip status, transfer cause and
  collection/detection terminality.
- Draw attendance validates pre-post timing and exact host presence/proximity;
  after posting, attendance is immutable and the seeded number remains solely
  draw-owned.
- Bookmaker aftermath is reconstructed or verified from exact settled slip,
  collection, detection, refusal or host interaction causes. It cannot be a
  caller-authored memory map.

### Required hostile proof

For every supported valid save, construct and reject without mutation:

- the exact predecessor snapshot with the receipt/cause fields removed;
- a coherent forged mutation followed by removal of its receipt keys;
- present attendance with no host cause, wrong day/venue/context, after-post
  insertion and present/absent replacement;
- every unknown physical state plus known-but-impossible holder/node/place/
  visibility/status combination;
- cross-slip, cross-day, cross-venue, cross-boundary and cross-run cause swaps;
- aftermath without its settlement/detection/collection cause, or with changed
  payout/debt/trust/grievance inputs; and
- partial version, migration-version downgrade, unknown field, missing field,
  type/bounds, fingerprint/root and replay conflicts.

The proof compares complete pre/post state, RNG, draw records, slips, payouts,
debts, trust, grievances, rumors and public projections. The full row's
unchanged-math table, 10-seed/native-Web/privacy/exactly-once/save/performance/
accessibility/visual gates remain required.

### Acceptance consequence

Only one exceptional review is authorized. A rejection returns to the owner.
World06_3 remains blocked until the accepted host-rooted candidate and full
world06_1/world06_2 integration land. `world06_7` remains blocked on world06_3
and all other world rows.

Migration consequence: genuine old saves receive deterministic defaults;
stripped depth records reject rather than downgrade. Privacy consequence: only
host-caused attendance/aftermath can persist. Economy consequence: numeric
values remain unchanged and no depth record can change eligibility without its
exact authoritative cause.

## 7. Option B: non-persisted, non-authoritative partial slice

Owner statement: accept only ephemeral player-safe projections/proposal
vocabulary, remove depth-owned fields from persistence, and defer authoritative
persistence/integration to a named successor.

Original `world06_3` becomes `PARTIAL - NON-AUTHORITATIVE / PERSISTENCE
SUCCESSOR REQUIRED`, never `DONE`. The partial slice may preserve:

- derived book place/actor/close-time projections from existing authoritative
  Numbers state;
- non-mutating `place_slip`, `collect_payday` and `solo_past_post` proposal step
  vocabulary marked `authoritative=false` and `ready_for_host_commit`; and
- player-safe derived slip/draw/aftermath presentation that is recomputed from
  existing core authority and never serialized as a new depth fact.

It excludes all depth-owned persisted `draw_occasions`,
`bookmaker_aftermath`, nested slip physical transfer state, receipt/cause fields
and any action that changes Numbers authority. Partial snapshots must not emit
those fields, and restore rejects them rather than imports or silently ignores
them. Draw presence defaults absent, physical slip state is only a derived view
of legacy status, and bookmaker memory cannot survive without the successor.

Create successor `world06_3b` (`Numbers Host-Rooted Persistence and
Integration`). It owns world06_1 host commit/receipt consumption, world06_2
runner integration, authoritative physical transfers/attendance/aftermath,
versioned migration, the four hostile families in section 4 and the full row's
exactly-once/privacy/economy proof.

Migration consequence: existing legacy core saves continue; no new depth state
round-trips until `world06_3b`. Privacy consequence: proposal and presentation
state cannot become secret authority. Economy consequence: the partial slice
cannot enable/deny or mutate stake, payout, debt, trust, grievance, access or
detection; host commit remains absent.

All route, authoritative placement/collection/rig, save/revisit and aftermath
completion claims remain open. `world06_7` stays blocked until `world06_3b`
lands and complete world06_3 is independently accepted. The partial slice may
not be counted as a played Numbers path in the world release gate.

## 8. Option C: stripped-record restore compatibility exception

Owner statement: preserve compatibility with stripped schema-version-1 Numbers
saves by accepting depth fields without receipt/cause records as trusted import.

Record exception `WORLD06_3-RESTORE-COMPAT-01` with this exact behavior:

- A schema-version-1 snapshot with absent/empty `action_receipts` and zero/absent
  `action_sequence` may import `draw_occasions`, `bookmaker_aftermath` and nested
  slip physical records without host-rooted cause validation.
- A nonempty or malformed receipt chain continues to reject. Removing the chain
  deliberately selects the compatibility path; anti-downgrade resistance is
  waived.
- Shape/type/bounds checks may still apply, but causal agreement with host
  presence, slip transfer, draw boundary, settlement, collection, detection or
  predecessor state is not required.

### Exact consequences

Migration: stripped records are treated as trusted legacy saves, so the system
cannot distinguish a genuine old save from a forged current record with its
receipts removed. Downgrade/import is intentional and must be documented in the
save format and migration report.

Privacy: an imported save may assert present attendance, friendly/suspicious or
past-post bookmaker memory, and a carried/hidden/handed/lost physical slip
without host observation. The seeded draw number must still remain hidden until
post, but presence, qualification, local memory and staged scene/rumor truth are
save-trusted rather than host-attested. The product cannot claim fail-closed
privacy or causal aftermath for those fields.

Economy: draw math, odds, payout formulas and tuning remain byte-identical, but
eligibility and access can be caller-authored. A stripped import may make a slip
appear carried or unavailable, change bookmaker disposition/collection memory,
or change conditions consumers use for payout, debt, trust, grievance,
detection or service access. If consumers quarantine these fields from economic
decisions, that non-authoritative boundary must be explicit and executable; if
they do not, the owner accepts the resulting save-edit/replay risk. An
unchanged-value table does not prove causal economic integrity under this
exception.

The owner must amend the row prompt, board, save/migration contract, privacy and
economy evidence, and `world06_7` gate to name this exception. Every consumer
must declare whether it trusts compatibility-imported fields. World06_3 remains
blocked until the exception-bearing candidate also completes world06_1/
world06_2 integration and all non-waived row gates. If `world06_7` retains its
current hidden-information, exactly-once and economic-honesty criteria, it stays
blocked or the owner must name a successor that restores causal authority.

## 9. Owner record required to resume

The decision record must state exactly `A`, `B` or `C`, owner and timestamp. It
must additionally name:

- for A, the exclusive world implementation owner and single exceptional-review
  authorization;
- for B, successor `world06_3b`, its owner and all held world06_7/integration
  dependencies; or
- for C, exception `WORLD06_3-RESTORE-COMPAT-01`, trusted import fields,
  consumer policy and every amended migration/privacy/economy/world06_7 claim.

Until that record exists, `8cde9f9b` and `e7aca347` remain frozen rejected
evidence. No agent may infer a choice, no partial may be called authoritative,
and the Integrator may not implement a resolution.
