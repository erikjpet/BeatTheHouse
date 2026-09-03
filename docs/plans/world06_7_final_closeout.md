# world06_7 Crew and World Depth final closeout

Date: 2026-09-03  
Exact base: `914e5ac822d8ee3127f210203dc688b182a19c65`  
Runtime/test remediation: `57b01ed40cf9fdabf2de016d9df6ef2e8db42019`

## Verdict

Family 2 is complete. `world06_1` through `world06_6` began from their landed
implementations and were not rebuilt. The exact-tree release gate accepts the
adapter, streets/delivery, Numbers, jobs/recruitment, coordinated plays,
Police Sweep, both heist plans, and the Turn confrontation. The seven prompts
are archived under `docs/todone/`.

Closeout found and repaired one blocking security defect: grievance details and
derived classifiers could distinguish future Turn state through save and public
surfaces. The remediation seals all private Crew/Turn state in one
always-present, fixed-width authenticated capsule. It also corrected stale test
fixtures so they use the shipped host boundaries rather than forged game/event
results. No odds, payouts, costs, rewards, trust thresholds, grievance weights,
play limits, heist ladders, or RNG ordering changed.

## Recovered product and focused acceptance

| Row/system | Played verbs and equivalent input | Actor set | Durable aftermath | Values | Evidence/verdict |
| --- | --- | --- | --- | --- | --- |
| `world06_1` adapter | `make_handoff`; shared action focus/activate supplies keyboard, controller and reduced-motion equivalents | Crew contact, package recipient | delivered, expired and abandoned sequence states survive revisit | Adapter adds no economy | Host-sealed adapter `95c6aaf5`; production queue, hostile schedule/replay/save and hidden-observer proof pass — ACCEPT |
| `world06_2` streets | pickup, move, wait, duck, stash, ditch, hold and handoff through shared action activation | courier, recipient, pursuer/patrol | cargo custody, chase, expiry, abandon and result receipts persist exactly once | Delivery deadlines, rewards, heat and costs unchanged | Delivery `e46ae808`/`a244eb6a`; depth and shared proof pass — ACCEPT |
| `world06_3` Numbers | place/inspect slip, close, draw, collect and the two rig-route actions; common focus/activate equivalents | bookmaker, runner, collection contact | book/day/slips/draw/collection/rig route restore without preview or replay | Five-book odds, payouts and route costs unchanged | Numbers `7425fb53`; authored/depth/migration contracts pass — ACCEPT |
| `world06_4` back room | talk, accept, refuse, defer and job-kind work actions through common focus/activate equivalents | all seven Crew members and room contacts | meeting history, contact state, job progress, expiry and result survive save/revisit | 13 jobs/five kinds, trust ladder, rewards/failures unchanged | Jobs/recruitment `d94977b9`/`334674fb`; authored/model/hostile/integration contracts pass — ACCEPT |
| `world06_5` plays/sweep | five coordinated-play activations plus sweep route/cost responses; common focus/activate equivalents | participating Crew member, dealer/table actors, patrol | uses/windows/cooldowns, cargo outcome and sweep aftermath persist exactly once | Five-play/13-surface costs, rates and five sweep rungs unchanged | Plays/sweeps `418d6e7f`/`9f89b615`; authored/model ten-seed contracts pass — ACCEPT |
| `world06_6` heist/Turn | plan, observe, stage, confront, hedge and exit actions; game/table and common focus/activate equivalents | Crew plan actors, quiet-table players/dealer, Turn target, pursuers | phase/plan/abort/exit/confrontation receipts and clean/hot aftermath persist | Both plans, four exits/failure beats and Turn weights unchanged | Heist `4822d288`/`613f5013`; authored/surface/real-Blackjack/confrontation/migration contracts pass — ACCEPT |
| `world06_7` gate | adversarial save/restore, replay, transplant and paired-observer operations | no new actors; audits every set above | verifies all durable state rather than adding state | verifies all tables above unchanged | Intake/checklist `5f79be20`/`2c76a9ea`; official and independent security probes pass — ACCEPT |

Keyboard/controller/reduced-motion presentation remains provided by the shared
`env06_6` sequence runtime and accepted game surfaces rather than duplicated in
the Crew models. The authored-semantic contracts verify the actor/object/action
payloads consumed by that runtime. Program-level subjective playability remains
the later `playtest06_1` owner gate; no Family 2 code or automated closeout work
is deferred to it.

## Hidden-information audit — blocking result

The save projection now contains exactly two private-envelope keys:

- `crew_state.a`: a random per-run 64-hex public authority id;
- `crew_state.z`: a 65,584-byte authenticated fixed-width capsule.

The capsule is emitted for zero through 256 grievances, so absence and length do
not classify whether a member has turned. Each new seal/reseal uses a random IV;
unchanged projections reuse the cached capsule. Authentication binds seed,
challenge, public heist plan/state/action and authority id. Missing, partial,
tampered, cross-run, cross-plan, cross-action, cross-install and transplanted
capsules fail closed without economy or RNG mutation. Legacy `g`/`q`,
`grievances`/`grievance_sequence`, and the shipped legacy heist capsule remain
read-compatible and migrate to the unified envelope on the next save.

The public projection removes grievance ids/kinds/weights/source references,
grievance-derived contact state, hidden job failure metadata, distraction join
keys, and the heist quiet-table owner token. Public economic outcomes remain
visible only after their authentic host boundary; they are not hidden-state
classifiers.

Independent review used four adversarial runs on the detached remediation
ancestry:

1. Official expanded hidden-information contract: PASS; fixed size, per-install
   key, random nonce, stable cache, tamper rejection, binding, legacy migration.
2. 512 paired saves spanning all seven real grievance producer routes: PASS;
   exact-`57b01ed4` classifier accuracy 0.4531, 512 unique capsules and 512
   unique IVs.
3. Seed/challenge/trust/plan/action substitution matrix: PASS; every mismatch
   failed closed with economy and RNG unchanged.
4. Separate-process cross-install key test: PASS; wrong or missing install key
   could not restore private state.

The official contract was also rerun on the final documentation head. Any future
change that makes zero/nonzero state differ in key set or capsule length, emits
`g`/`q`, or restores from unauthenticated content is a P0 regression.

## Authorized crew-ignored golden exception

The prior golden required byte-identical `RunState` serialization. That is
incompatible with randomized encryption and would reward deterministic nonce
reuse. The replacement keeps exact raw byte counts and hashes every public
field, but substitutes equal-width placeholders only when `crew_state.a` is a
valid authority id and `crew_state.z` decodes to exactly 65,584 bytes. Missing,
malformed or wrong-width envelopes do not normalize and fail. Coin Pusher's
public numeric `z` coordinates and every environment/world field remain intact.

The accepted fixture is
`scripts/tests/fixtures/crew06_5_ignored_run_baseline.json`, canonical Git blob
`50372bcf98eef07ee65028ad985c9756571c283d` at `57b01ed4`. The blob identity is
used instead of a checkout-byte hash because line endings differ by platform.
It reflects the current landed Coin Pusher V3 settled state plus the mandated
capsule. The 48-byte current-environment delta after restore is solely the
existing `scenario_restore_pending_trusted_rebuild` safety marker.

## Exact-tree verification

- `tools/validate_project.ps1 -Quiet`: PASS, exit 0, 79.9 seconds.
- Combined `crew_recruitment_contract`, `crew_heist_contract`, and
  `crew_turn_contract`: PASS, zero failures; report SHA-256
  `7654992B4EA81D062A177D72DAFD57D6F5F704A47F28537110AEEBA1DB96EAB9`.
- All 15 direct Family 2 contracts: PASS. This includes shared delivery proof;
  delivery depth; Numbers authored/depth; jobs/recruitment authored, model and
  hostile checks; plays/sweep authored and model checks; heist authored/surface;
  confrontation; and hidden information.
- Crew-ignored same-seed twins and all inactive world-sequence no-op calls:
  PASS with exact public serialization and key-set equality.
- Serialization performance: warmed clean `to_dict()` measured 0.463 ms per
  boundary call, +0.153 ms versus the pre-capsule implementation. This is not a
  per-frame path and remains far below 16.67 ms. Raw save growth is the required
  fixed private envelope; the later `perf06_1` matrix retains the measurement.

The earlier broad Systems attempt and the original 62/61 crew-ignore reds are
retained under `.tmp/world06_closeout/`; they were not relabeled or deleted.
They document stale pre-authority fixtures and the pre-regeneration golden. The
focused reruns above prove the corrected production boundaries. Unrelated broad
suite findings remain with their owning rows and are not represented as Family
2 regressions.

## Remaining work

No Family 2 implementation, security, migration, or automated verification work
remains. The owner playtest should still judge whether the complete Crew path is
clear, satisfying and readable without outside explanation. Findings from that
human pass belong to `playtest06_1`/`triage06_1`, not to reopened world rows.
