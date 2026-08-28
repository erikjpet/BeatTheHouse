# env06_6 runtime vocabulary and delivery handoff

Status: CONTRACT HANDOFF — implementation-independent; not a review verdict or landing authorization.

## 1. Custody, state, and provenance

- Contract-author worktree: `D:\bth-env6`.
- Contract-author branch before this handoff commit: `codex/land06-env06_6-final`.
- Product head before this handoff commit: `064594023302742474ece0b8c4f79e606eff7890`.
- Preserved product chain, oldest to newest: integration `390211ae`; runner deferral `c373bb52`; lifecycle fixture `02e7412f`; interaction arbitration `f804c013`; arbitration provenance proof `262c378c`; presentation fixture semantics `f10f602d`; sealed route authority `e0644b34`; stale-P1 remediation `def0d067`; fail-closed renderer payload remediation `06459402`.
- A/B/C/D labels occur in retained evidence names, but their authoritative label-to-commit assignment is unresolved in the inherited record. Do not infer it from directory names. The commit chain above is authoritative; a delivery service that requires A/B/C/D labels must inventory and record that mapping before landing.
- Current functional state: the env06_6 implementation and focused remediation commits exist on the preserved integration branch; formal row acceptance and landing remain external coordination decisions.
- The source branch is provenance. Preserve it and its worktree until the Landing Coordinator records the landed net payload and final gate evidence.

The earlier independent P1 was stale in one respect: it treated requested route hints as authority. The correction requires exact sealed route-or-anchor authority and rejects forged/unsealed hints. `e0644b34` established the sealed route seam; independent review found the remaining bypass; `def0d067` closed it by gating route hints behind sealed authority. `06459402` separately closes renderer failure-response impurity. Neither commit authorizes weakening target validation or publishing partial failed presentation data.

## 2. Normative runtime vocabulary

The terms below define behavior, not filenames or a preferred implementation.

### Sequence, phase, boundary, and cause

A **sequence** is a versioned authored phase graph bound to one scenario and one environment node. A **phase** is the current authored operation/action scope. A **boundary** is an exact durable scope for a phase entry, fact flush, command, cleanup, or aftermath application. A **cause** is a closed command or fact envelope with an exact receipt key and content fingerprint.

Persistent state includes phase/status, public-schema local state, objective progress, semantic reducer state, exact receipts and fingerprints, branch/outcome records, pending bounded queues, cleanup/reentry/expiry records, and safe counters. Derived state includes renderer snapshots, presentation geometry, public projections, action tokens, availability projections, layout authority, and audits. Derived data must be rebuilt only from validated persistent authority and must never become durable authority by round trip.

### `scene_ops`

Inputs are closed, bounded authored operations over owned scene identities: create (`spawn`), replace, remove, move/position, visibility, enabled/state/appearance changes, and other registered verbs only. Spatial references use declared and exact anchors/zones. A scenario create establishes a scenario-owned live identity; a modifier cannot manufacture a missing scenario identity merely because a string appears in declared inventory. Non-scenario targets require exact sealed host authority.

Results are a new semantic scene collection plus operation receipts/fingerprints. Apply is transactional. Exact same receipt and fingerprint is idempotent; same receipt with different content rejects. Remove/cleanup is conditional and replay-safe. Rendering geometry is derived and must not be persisted as authored truth.

### `interaction_ops`

Inputs are closed add/remove/replace/gate/augment/retarget records with exact owned source identity and, where applicable, exact target identity. Arbitration is deterministic and owner-priority based. Same-owner duplicates, collisions, missing targets, lower-priority overrides, cycles, and ambiguous winners reject or fail closed according to the typed contract.

An accepted augment contributes actions to the authoritative target; the source overlay does not become an independently addressable host action. Every presented action carries origin owner/stable identity, operation receipt, boundary, and fingerprint. Command authorization starts from the exact live resolved interaction/action, verifies enabled/host availability, verifies the sealed origin receipt and fingerprint against authored content, and separately verifies that the current phase permits the command. Caller-provided origin fields are comparison material, never authority. Removed, tombstoned, gated, stale, spoofed, wrong-phase, or absent actions reject without mutation.

`alternate_exit` is an explicit authored interaction property. It is not inferred from layout position, label, `safe_exit`, or action text. A safe exit and an alternate exit are separate claims. Consumers must preserve both booleans, expose only enabled/reachable actions, and never invent an alternate route to make validation pass.

### `actor_ops`

Inputs are closed spawn/despawn/replace/position/route/pose/behavior operations over exact actor identities. A spawn requires an authored actor and an exact spatial anchor/zone. Route tokens are requests, not authority: resolution must use a valid room-bound sealed inventory and a unique exact sealed route-or-anchor record. Unknown, ambiguous, unsealed, cross-room, or stale authority rejects.

Persistent actor semantics contain identity and authored behavior/route request. Resolved route points, collision adjustments, geometry, z order, and motion staging are derived. Reduced-motion and platform presentation may change staging, never semantic outcome, receipt order, route authority, or action availability.

### Objectives and branches

Objectives have stable ids, bounded steps, typed completion causes, and allowed outcomes. A command/fact may complete only the authored step it matches. Branch selection is deterministic in authored order, records phase, branch, trigger kind, exact trigger receipt, branch fingerprint, cause fingerprint, and target phase or terminal outcome. Branch and objective changes are transactional with their handler and phase transition.

Command-entered phases receive exactly one immediate turn-boundary grace so the command's own world boundary is not double-counted. Fact-entered phases receive no command grace. The next legitimate world boundary remains eligible. A terminal outcome persists as aftermath; it is not merely a transient presentation state.

### `transition_ops`

Inputs are closed bounded feedback, stage, sound/music, and registered scene-change operations. Outputs enter a bounded deterministic queue with exact receipts. Delivery acknowledgement is separate from production. Replay cannot duplicate presentation. Stage expiry follows real world boundaries, including when phase-progression grace consumes that boundary. Reduced-motion may substitute authored presentation text but cannot alter ordering, duration boundary semantics, causes, or durable state.

### Cleanup, reentry, expiry, and aftermath

**Cleanup** is an authored transactional operation batch with a structural receipt and content fingerprint. It removes/restores only proven targets, is idempotent on exact replay, and rejects changed content after finalization. Cleanup cannot synthesize missing scenario-owned identities or erase unrelated host state.

**Aftermath** is the durable material result of exactly one terminal outcome. Cleanup completes before the outcome's material operations commit. The status, resolved outcome, material semantic changes, feedback, and receipts survive save/load and terminal reentry. Other outcomes' identities must not leak.

**Reentry** applies the authored partial/terminal/expired policy exactly once per visit receipt. Resume preserves current progress; restart cleans and reinitializes from trusted host semantics; aftermath preserves the terminal material state; expiry cleans and closes ingress. Reentry never guesses missing inventory and never converts derived projection data into authority.

### Sealed semantic inventory and layout/route authority

A sealed instance inventory is an immutable, digest-bound proof of identities that exist in the exact room/layer and of the source provenance consumed to build it. Catalog possibility is not instance existence. Seals are not portable across rooms or layers. Validation must check schema, kind, digest, binding, source provenance, and consumed dynamic sources.

Layout authority is produced from validated final base records and successful scenario resolution. The renderer consumes the successful seal; it does not independently resolve a second candidate. On any renderer preparation failure, every public presentation collection is empty (`visual_objects`, `interaction_overlays`, `services`, `games`, `routes`, `active_stages`); typed errors and safe non-content metadata may remain. No hidden or partial payload may escape.

### Replay, security, determinism, and platform obligations

- All externally supplied variants are closed, bounded, canonical, and path-safe.
- Receipt keys identify one envelope; reuse with different content rejects.
- Fingerprints bind exact canonical content. Migration may reconstruct authority only from already sealed durable records, never from caller assertions.
- Failed command, fact batch, operation batch, cleanup, reentry, finalization, or rendering is atomic and preserves the authoritative pre-state except for explicitly documented rejected-ingress handling.
- Ordering is stable across dictionary order, save/load, native/Web, reduced-motion, and headless/interactive execution.
- RNG, economy, payout, odds, wager math, schema, migration, and tuning are outside this contract and must not be changed as incidental remediation.
- Consumers must use public projections and authenticated action descriptors; they must not read private local state, reducer journals, tombstones, inventory digests, or hidden branch state for presentation or gameplay shortcuts.

## 3. Gate economics and authoritative evidence

Known evidence:

- The accepted-def0 retained content report is `D:\bth-env6\.tmp\env06_6_accepted_def0_content_01\report.json`: exit 1 with 78 failures. It is triage evidence, not a passing gate and must not be represented as acceptance.
- fix20 changed-file parse reports are `D:\bth-env6\.tmp\fix20_parse_report.json` and `fix20_parse_report_second.json`; both recorded 2/2 scripts loaded, exit 0, SHA-256 `22BC61CE481E818A1F39737FA75B2EAE5F6F90D0327CFCBCEE3FC82680A19900`.
- The retained fix20 focused review helper is `D:\bth-env6\.tmp\fix20_review_helper.gd`, SHA-256 `07861B1D2D953B310FD41365BBE60A7C80AFB7D0D1ACD7B2BAA130CD4C8DE780`.
- The fix21 row-20 diagnostic is retained at `D:\bth-env6\.tmp\fix21_branch_diag_01`; it proved transactional rejection for missing live `scenario::fixture_102`. Helper SHA-256: `5B8B202F4AEE83DE496465A92061A76EBFA2ED912B9B77E76397E79F3653EB50`; stdout SHA-256: `72783C5FA3A77DE5B375FFEFC392C646AC96D49F563D2259A5846650F027B288`; stderr is empty.
- The pinned Godot identity used for accepted focused evidence was `D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe`.
- Contract timing budget: `230.391s`, derived from baseline `153.594s × 1.5`. The same byte-identical tree previously measured `213.643s` and `231.531s`; every timing result must be reported. A marginal red is a measurement question, not permission to raise a cap or rerun until green.
- The coin-pusher native library is generated and git-ignored; its absence silently changes Contract, pusher, and performance measurements. Every gate record must name the exact supplied native build and verify its identity before timing or parity claims.

Unresolved evidence inventory:

- Exact native-library path, build commit/hash, binary SHA-256, and which retained timing runs used it are not established in the inherited record. Gate Service must resolve and record these before accepting any timing/native/Web claim.
- The authoritative A/B/C/D commit mapping and complete serialized Full/audit/determinism/native-Web parity/performance/21-image result set are not established here. Existing `.tmp/env06_6_final` artifacts are candidates, not acceptance, until Gate Service binds each to commit, tool identity, native identity, exit code, report hash, and complete stdout/stderr.
- No gate was run for this handoff commit.

Gate economics are strict: use one exact commit and one declared tool/native identity; retain the first result; serialize expensive Godot gates; use bounded timeouts and process-tree cleanup; never omit slow/red results; never weaken a test, filter a failure, or raise a cap to manufacture green. Visual review and automated visual generation are different evidence and must be recorded separately.

## 4. Deferred defect partition and dependencies

- `fix06_18`: caller rollback/transactional delivery failures, preserved as an isolated docs-only route at branch `codex/fix06_18-route`, head `fc31b9db6c1da9473e923ffe75dfc6b526f6204e`, worktree `C:\Users\theep\.codex\tmp\bth-fix18-route`.
- `env06_7`: all 55 authored sequence conversions and content-specific validation, including Delivery Day's missing validation seal/local route authority; depends on the landed/reviewed env06_6 runtime.
- `fix06_19`: routed failures #64–68; exact subject inventory is unresolved in this inherited record.
- `fix21`: failures #14–21. Product scope is sealed persisted live-action provenance across phases (#15/#21); #14 and #16–20 are fixture construction/expectation corrections using production reseal and exact live authority. Do not weaken missing-scenario target validation.
- `fix22`: #22–33 reducer/fact/lifecycle; follows fix21 so provenance/fixture noise is removed first.
- `fix23`: #34–42 persistence; follows the normalized reducer contract.
- `fix24`: #43–46 projection/replay/cleanup/capacity.
- `fix25`: #47–56 transition/event bridge.
- `fix26`: #69–74 atomic finalization.
- `fix27`: #75–76 expanded layout.
- `fix28`: #77–78 membership.
- `fix06_13` and `fix06_15`: preserved external dependencies/defects, but their exact heads, worktrees, and remaining scope are unresolved in the inherited record and must be inventoried rather than guessed.
- Separate routed items remain: marginal Contract timing, stale delivery full-state UI golden, and owner design decision for fix06_3 Phase 5 Crossword Corner art direction.

Preserve all source heads and worktrees until their net payloads are landed and recorded. Entangled/behind branches must be landed by exact net payload rather than merged wholesale.

## 5. Delivery mechanism

1. **Review Pool** receives this vocabulary, the exact source head, net diff, preserved evidence paths/hashes, and unresolved inventory list. It performs independent implementation and security review. It must return findings, not edit a verdict into this handoff.
2. **Gate Service** receives the reviewed candidate commit. It binds every run to commit, Godot identity, native binary identity, command, timeout/method, exit code, complete stdout/stderr, report hash, host/date, and timing result. It retains first reds and all repeats. It may not repair code or reinterpret caps.
3. **Landing Coordinator** receives the independent review disposition and Gate Service manifest. It verifies the landing precondition, selects the exact net payload when the source branch is entangled or behind, lands one row at a time to `main`, reruns only the contract-required post-land verification, records provenance and deferred defects, and preserves the source branch.

Handoff consumers must not treat this document, a green focused helper, an audit with `count=1`, or the existence of retained artifacts as formal acceptance. Acceptance requires the owner/PM-defined review and gate set on the exact landing candidate.
