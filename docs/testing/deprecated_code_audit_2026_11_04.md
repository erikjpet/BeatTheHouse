# Deprecated-code audit continuation — 2026-11-04

Task `BTH061-AUDIT-001` / `BTH-DEPRECATED-CODE-AUDIT-001` is reopened.
Baseline: `ecdccee418c2297a0fb864d00c902a4c159dfd5c`.

The earlier pass delivered confirmed removals in `6a784623` and verified them on
NEXT `be4cd671`. It screened several areas but did not resolve the full original
codebase-wide scope, inherited check failures or every deferred candidate.
Calling the entire audit complete was premature. At resumption no intentional
user hold applied; the later explicit item/scenario pause is recorded below.
Age, test-only use or a historical coordination note is not a decision
to keep or delete code. Current consumer and compatibility evidence determines
each disposition.

## Scope and method

The resumed whole-tree inventory accounts for all 3,964 tracked paths at the
baseline: 222 production GDScript modules, 292 active-tool paths, 11 first-party
native paths, 60 runtime data/scene/config paths, 464 runtime assets, 476 test
and fixture paths, 114 historical-tool paths, 2,315 document/evidence paths and
10 root build/metadata paths. There are no tracked addons. Every path has a role;
binary/media/historical role accounting is distinguished from source review.
The [baseline path inventory](deprecated_code_audit_2026_11_04_inventory.tsv)
records each path, role, exact blob, prior blob identity and review level. A
role-screened row does not claim a manual body review.

Production coverage is 95 core scripts / 4,377 top-level function declarations, 80 UI scripts / 4,128
functions and 47 game scripts / 3,194 functions. The reference survey includes
current code, callable/string names, engine callbacks, inheritance, resource and
content-selected loaders, native registration and tests/tools. Receiver-specific
review checks same-name methods that a global token count can incorrectly keep.
The previous complete authored-file inventory is compared by exact Git blob:
3,498 paths are unchanged, 214 changed and 252 new; old review evidence is not
represented as fresh runtime qualification.

This is a whole-tree deprecation/reference survey with targeted semantic and
history review of candidates and dynamic entry points. It is not a manual read
of every function body, an exhaustive whole-program proof, binary analysis or
an all-game playtest. The tracked inventory records these levels explicitly.

## Current work

| Removed | Consumer/replacement proof |
| --- | --- |
| Four ScenarioLayoutResolver overlap helpers and two constants | `69506f95` removed their gameplay callers. The old test-only island still exercised the retired algorithm; its two meaningful edge/overlap cases now exercise the live PixelSceneCanvas diagnostic. Live route, board, expansion and overlap-count logic stays intact. |
| Thirty-six unused Keys constants | Only four internal aliases have production readers. No reflection or saved-schema reader consumes the others. The old count-only test kept dead declarations; current exact-value and IoResult/error/adoption assertions remain. No actual save key string is removed. |
| Two duplicate facade forwarding properties | RunState uses the live backing fields and its own save wrappers. No current caller, reflection or serialized property consumes the duplicate facade names. Round-trip facade checks remain. |
| Three game helpers | Baccarat's old character painter/accent pair has no receiver-specific caller; current painting delegates to TableGameVisuals. Scratch's duplicate reader lost its sole caller in `4cf2b440`; current read/write/migration APIs remain. Same-named methods in other classes had hidden these findings from a global token count. |
| Three unused HUD constants and hidden clock label | Fixed HUD dimensions and the real details overlay replaced them. The active `time_detail_visible` snapshot key remains. |
| Dormant GameSurfaceCanvas external-background path | Both fields had only null/false writers. The current procedural stripe body is preserved exactly. Active PixelSceneCanvas/main-menu and native game backgrounds remain. |
| Obsolete external-game backdrop data and assets | Eleven unused `scene_asset_path` fields, obsolete art-manifest sections and nine PNGs (125,776 bytes) are removed. Remaining game/manifest values match independently parsed baseline objects. No active generator recreates this subsystem. The current tutorial whole-definition pin is independently updated only for this removed field; other fixture assertions/baseline remain. |
| Superseded procedural slot writer | Eighteen allocation, clone, regeneration and writer functions are removed with `author_scenario_slot_layouts.py`. Thirteen independently consumed semantic helpers remain AST-identical in `scenario_slot_layout_contracts.py`. The read-only replacement checks current accepted authority instead of reconstructing an older 604-slot version. |

Active save migrations, paid-hand completion, registered native paths, current
rendering fallbacks and meaningful authority/reference tests remain because
they have real consumers. Crew's old paid hand can still finish and transition
to the current engine. Coin Pusher's reference solver and packed/dictionary
native paths remain active. Current native/export inputs and manual tool entry
points are not removed on a missing static caller alone.

Resource ambiguities are classified, not silently deleted: saved item asset
aliases, video-poker authoring source art and qualification scene entry points
have compatibility/authoring consumers or insufficient retirement proof. These
are not alternate runnable game screens. Historical qualification evidence is
retained as evidence. No intentional hold is a reason for any retention.

No portrait product geometry, fixed-canvas policy or animation scheduling is
changed. Source proofs compare unchanged layout/configuration files and the
exact procedural draw path. A separate canceled-touch defect exposed by the
repaired native fixture is tracked as `BTH061-AUDIT-TOUCH-CANCEL-001`; its narrow
candidate only enables the existing cancellation guards independently of the
retired portrait-layout predicate and protects the Package callback.

## Inherited-check follow-ups

Each check has a stable task ID on the existing task list. A prior baseline
failure is not a pass or a newly diagnosed player bug. Fresh current-baseline
receipts preserve the failing test source before fixture changes.

| ID | Scope | Status |
| --- | --- | --- |
| `BTH061-AUDIT-CREW-WINDOW-001` | Current obligation/physical-Crew eligibility and real world-sequence terminal handoff; retain once-only payout and Save/Continue. | Focused acceptance passes; repair `dec71ae8`, NEXT `b94f3938` verified. |
| `BTH061-AUDIT-PLACEMENT-MODE-001` | Separate independent Runtime reserves and Empty capacity switches in the fixture. | Focused acceptance passes; repair `dec71ae8`, NEXT `b94f3938` verified. |
| `BTH061-AUDIT-OFFER-CACHE-001` | Initialize current lazy collaborators and initial authenticated room publication. | Focused acceptance passes; repair `dec71ae8`, NEXT `b94f3938` verified. |
| `BTH061-AUDIT-SLOT-STATIC-001` | Resolve all nineteen stale audit expectations with precise current identities and hostile checks; keep runtime layout/authority bytes. | Focused acceptance passes; repair `dec71ae8`, NEXT `b94f3938` verified. |
| `BTH061-AUDIT-VALIDATOR-001` | Repair internal preload aliases and current source/JSON contracts. | Repair `dec71ae8`; focused contracts pass, full validator remains Open. |
| `BTH061-AUDIT-MOBILE-CONTRACT-001` | Replace obsolete direct HUD fields/responsive-policy assertions with current fixed-canvas popup contracts, retaining behavioral criteria. | Native five-case acceptance passes; `b3337406`, NEXT `b94f3938` verified. |
| `BTH061-AUDIT-BACKDROP-001` | Remove the closed obsolete external-game backdrop subsystem, preserving live backgrounds and old-state sanitization. | Removal `d641ce2d`, native acceptance passes; cold-import/NEXT `b94f3938` verified. |
| `BTH061-AUDIT-TOUCH-CANCEL-001` | Canceled native/emulated touch must not activate Continue, clock details or a Package action; current geometry/policy stay identical. | Native acceptance passes; `b3337406`, NEXT `b94f3938` verified. |
| `BTH061-AUDIT-POPUP-SCROLL-001` | Resolve current popup scroll/drag acceptance while retaining reachable actions, canceled/deliberate-touch criteria, focus and protected run state under the fixed canvas. | Native acceptance passes; `b3337406`, NEXT `b94f3938` verified. |
| `BTH061-AUDIT-TUTORIAL-FIXTURE-001` | Investigate the inherited canonical tutorial full-fixture pin mismatch independently of the approved Blackjack definition-pin update; preserve the trusted full-fixture oracle. | Open; `NONE - OPEN`. |
| `BTH061-AUDIT-SLOT-AUTHOR-001` | Remove superseded writer while preserving independently consumed structural/semantic checks and current accepted authority. | Removal `8e9951c3`, focused acceptance and NEXT `788224c2` verified. |
| `BTH061-AUDIT-SLOT-MIGRATION-001` | Separate historical conversion pins from current authored additions without changing either authority. | Repair `8e9951c3`, focused acceptance and NEXT `788224c2` verified. |

The fresh pre-repair fixtures fail on current source as well as the older
baseline. Placement and offer-cache now pass (36 assertions/zero failures for
offers), and the repaired Crew check now passes real host handoff, once-only
money and Save/Continue. The full static slot checker passes all 21 maps and 767
active snapshots; ten focused tests include hostile identity, reserve,
duplicate-occupant, capacity and provenance cases. Runtime layout JSON remains
byte-identical. Its historical Sal occupant order is preserved because the
entire authored row contributes to saved map authority.

The project validator required additional genuine repairs after the first
reported alias: lexical masking must distinguish embedded JavaScript from
GDScript indentation; singleton JSON arrays must retain their root type on
Windows PowerShell; current object packs, recovered completion markers, census
empty bodies and reviewed function-specific content bindings need current
contracts. These findings are tooling/fixture issues, not passing tests or newly
diagnosed player bugs. Current validator qualification remains open until the
complete invocation passes.

The complete host invocation also exposed further inherited authoring and
migration oracle failures. Exact baseline equality is recorded before changing
their disposition: the procedural author currently reconstructs 604 slots
against 607 stored slots and differs in 21 layouts; its unit suite reports 175
failure occurrences across five methods, including old overlap/provenance and
capacity assumptions. The migration suite has two failing cases and a stale
four-versus-five converted-ledger expectation. Current authored coordinates,
host mappings and saved authority must not be regenerated to make these pass.
`BTH061-AUDIT-SLOT-AUTHOR-001` and `BTH061-AUDIT-SLOT-MIGRATION-001` track this
work independently. Separately, the hostile-launcher contract detected other
authorized concurrent tasks in its global process census; no peer process was
stopped or guard weakened. These are distinct limitations, not a claim that
concurrency is the only remaining validator failure.

The authoring disposition is established by accepted history, not failure count:
`46474bc8` adds Delta action hosting, `b92b79a5` adds a distinct Open Mic phase
slot, `bf894fcd` adds two Raid phase slots, `9cfb2ad7` binds the Reopen host and
`4f7778a2` adds Bar Lock-In task hosts. Those focused fixes intentionally update
the stored authority without rerunning the older allocation recipe. Runtime
loads that JSON directly. Independent semantic/snapshot/structural helpers are
still used and must remain; the superseded regeneration/write/equality path is
being replaced separately. Current PixelSceneCanvas explicitly treats local
scenario/capacity overlaps as advisory and applies its hard route rule only to
active shared bindings, so a replacement must follow those actual semantics
and retain hostile active-route rejection rather than waive named pairs.

Commit `8e9951c3228f28843c0576bb29ff3323f1894b0e` delivers that extraction and
the migration follow-up. The current read-only checker passes all 55 layouts /
607 slots, 25 scenario tests and the derived guide's 75 contexts. Ten migration
and four consolidation tests pass; both unchanged historical ledgers validate
their original 468-to-525 and 525-to-525 conversions. An exact reviewed overlay
handles subsequent authored additions independently. The legacy capacity
writer rejects current authority. A genuinely missing row-local `slot_id`
assignment in consolidation reporting is restored; it is not masked by new
counts or pins. All 1,391 protected runtime/data/assets/native/scene/ledger and
project inputs remain byte-identical to the qualified batch.

Complete validator receipts are preserved, including failures. All source/authoring/migration stages pass on the frozen tool candidate before
the later main integrations. Host run r3 reached a missing canonical
Q-009 lease directory; its existing atomic identity helper initialized only
that empty container under the real launch mutex, with no guard code change.
Host run r4 then completed its checks but was rejected by the final global
process census after other authorized work started. Aggregate validator
acceptance remains Open under `BTH061-AUDIT-VALIDATOR-001`; no process guard was
weakened and no other task's process was stopped. The exact pending acceptance
is one complete invocation whose global process census remains unchanged.
Raw receipts `tool_audit/validator_complete_result-host-r3.json` and
`validator_complete_result-host-r4.json` stay private in the task workspace;
peer command lines are not published.

## Commits and current acceptance

After integrating current main `66cd97dd18c78350b0194f824186772b30039938`, the
obsolete-code removal commit is
`d641ce2d36cd353730f69f4360f619f295333ff3` and the passing fixture/tool repairs are
`dec71ae8b267e9adb27bd408b10cbad9f4644b82`. The four original failures now have
associated repairs and focused acceptance; the broader validator is still Open.
No task is closed merely because it has a commit.

The current fixed-canvas mobile contract passes policy, portrait390, title390
and desktop1280 under isolated native input, including ordinary/maximum-font
Package scrolling, cancellation and deliberate exactly-once action checks.
The initial rotation case rejected a 0.6 logical-pixel bottom remainder despite
retaining focus in all four orientations. Godot's integer scroll offset explains
that remainder. The corrected fixture requires exact horizontal bounds, a
positive visible intersection and strictly less than one logical pixel of
vertical remainder, recording all rectangles and offsets. Rotation now passes
477 checks with zero failures. This is not an all-mobile or physical-phone
acceptance claim. The Package fix passes
events through its own buttons and card panels only, while the existing
cancellation guard is enabled under the active fixed canvas. Shared popup
protocols, physical layout and portrait policy are unchanged.

Input/fixture commit `b33374061f1be396e1c6a73a6af690d618fc4b64` is qualified by
native policy (26 checks), portrait390 (380), title390 (70), desktop1280 (380)
and rotation (477). Ordinary and maximum-font gesture completion have separate
required phases. The integrated thirteen-stage suite also passes with zero
owned processes after release. Final parser and rotation receipts identify the
exact final fixture SHA-256
`3813149509bd298cf82dfe846fbc2c41d634874e453f6c67fc326ac1949c88e3`;
the other four case receipts precede only that precise rotation-oracle repair.
NEXT acceptance for this batch is recorded below.

## Verified NEXT batch

The existing watcher promoted
`b94f39382c8e181014140ae2600f13eef63a60f5`, tree
`f55e85c8e1bc1baa28ac7c5803c3287e1a4b3f02`, at
2026-11-04 01:31:15 UTC. Its exact-input request covers nine removed backdrops
and the two metadata files. The recorded cold qualification uses zero imported
cache files/bytes and the normal serial importer/exporter and unchanged caps.
Native/export guarded inputs are unchanged; the qualified native tuple is
reused by the normal watcher.

Served NEXT/BUILD/manifest/REF/VERSION, tree, redirect, pipeline metadata hashes,
PCK audit/hash and four payload size/MIME checks pass. All nine backdrop source
and imported texture identities are absent; all eleven current game icons and
seventeen current scratch symbols remain. Fresh sandboxed Chromium startup
reaches the visually reviewed correct-version menu with zero page or console
errors and zero owned processes after closure. The restricted-token attempt
stopped before navigation because its GPU-sandbox check failed; the normal host
attempt preserved that check and passed. No browser protection or TLS check was
disabled. Raw receipts are `evidence/next-identity-20261104-r2.json` and
`evidence/next-startup-20261104-r3/` in the isolated task workspace.

This qualifies the removal, four original fixture/check repairs and narrow
input/fixture batch on NEXT. It does not claim a full tutorial playthrough,
physical-phone or Web gesture acceptance, or a passing complete validator.
At that batch acceptance point, the author/migration follow-ups were still
Open; their subsequent acceptance is recorded below. The umbrella, aggregate
validator and inherited tutorial follow-ups remain Open.

The frozen cleanup candidate passes editor import and thirteen focused native
stages: the three repaired baseline checks, all 75 layout contexts, Back Alley
edge tolerance, IoResult, facade/save round trip, 957 HUD checks, Baccarat deal
presentation/save-load, scratch projection, surface ownership and autonomous
animation. Raw receipts retain the isolated host certificate-store diagnostic;
no TLS check was bypassed. Later input-guard changes require their own native
gesture acceptance and do not retroactively claim an exact-source all-game pass.

Paired canonical tutorial evidence is recorded in the isolated workspace at
`evidence/resume-probe-20261104-r1/comparison.json`. The exact baseline
`ecdccee418c2297a0fb864d00c902a4c159dfd5c` and candidate produce byte-identical
normalized fixture states, each 121,008 bytes, with no differing top-level keys
or deep-state differences. Both observed full-state SHA-256 values are
`fba86ca4c882f9e7425cce1eb5cb76e691d60d1b422eb35f18e786e4e6380105`.
They both differ from the untouched trusted full-fixture pin
`fbf5f57b1111a90bb650c5d8668eda8c90404b596c5ecbf91ca8a015acf44700`.
The trusted pin remains unchanged; no observed fingerprint was substituted to
obtain a pass. This paired fixture-state proof identifies an inherited failure,
not a passing tutorial playthrough. `BTH061-AUDIT-TUTORIAL-FIXTURE-001` remains
Open independently of popup scrolling and the obsolete-code removals. The
umbrella audit remains Open, with no intentional holds.

No item is complete until its associated commit and applicable acceptance are
recorded. Current raw receipts and graph inventories remain in the isolated
task workspace; no player state is included in the repository.

## Final tool batch acceptance

The existing watcher promoted `788224c2b719141c17145e1d939ede72fba52aca`, tree
`a072f8a5e3c8639e427306acc97199dc45064aa7`. Served identity/redirect/metadata hashes,
matching PCK audit and four payload checks pass. The nine retired backdrops are
absent; eleven live game icons and seventeen scratch symbols remain. Fresh
sandboxed Chromium reaches the visually reviewed correct-version menu with
zero page/console errors and zero owned processes after closure. Receipts are
`evidence/next-identity-20261104-r4.json` and
`evidence/next-startup-20261104-r4/` in the isolated task workspace.

Concurrent Save, Count Sit, Video Poker and Motel commits were preserved. The
focused scenario/guide/migration/ledger and source-rule contracts were rerun
after the main integration; the last Motel integration changes no tool/data
input to those checks. This tools patch changes no runtime, layout, asset,
native or ledger input relative to that integrated main. Earlier native gesture
and gameplay receipts retain their exact qualified source snapshots rather than
being represented as fresh tests of every concurrent change.

The author and migration tasks are Complete with code commit
`8e9951c3228f28843c0576bb29ff3323f1894b0e` and exact NEXT acceptance. The
umbrella stays Open for the precisely recorded aggregate process-census
qualification and inherited tutorial-fixture investigation. The trusted tutorial
pin is unchanged.

A subsequent explicit user pause covers item and scenario work prospectively.
Root received it after the above code had been pushed and NEXT had deployed
`788224c2b719141c17145e1d939ede72fba52aca` at 02:12:46 UTC. No item/scenario code changes were made or
published after receipt; only read-only release verification and this evidence
record followed. Further audit edits must stay outside the paused areas, and
pending evidence is preserved. This new pause does not retroactively justify
the earlier inaccurate hold or completion labels.

## Remaining-findings investigation after the pause

The continued investigation changes only general tutorial qualification tests
and evidence. No product, item, authored scenario/sequence, venue-access or Crew
implementation/data is edited. The umbrella remains Open.

### Exact tutorial fingerprint cause

The current fixture is still 121,008 normalized bytes with full SHA-256
`fba86ca4c882f9e7425cce1eb5cb76e691d60d1b422eb35f18e786e4e6380105`.
All drift from the original trusted pin is accounted for by 17 differences:

| Later accepted change | Exact fixture differences |
| --- | --- |
| `fa3de446` | One complete `story_money_archive` saved-state extension. |
| `accef469` | One `surface_clock_checkpoint_msec` extension. |
| `cd769f18` | Nine Crew restoration flags created when the old fixture's three-flag assignment enters the supported legacy migration. |
| `26d399aa` | Three venue-door leaves at each of two saved locations: made-rank access, current-access requirement and its explanation. |

Reversing exactly those historical differences in an external forensic copy
produces 120,254 bytes and the exact original
`fbf5f57b1111a90bb650c5d8668eda8c90404b596c5ecbf91ca8a015acf44700`
pin. This identifies stale whole-state acceptance, not a cleanup regression.
The forensic copy is never supplied as gameplay or saved-state input.

The test-only repair keeps that trusted pin and first requires each complete
current extension/door record to match its reviewed current shape. Only a
detached comparison view is projected to the historical authority. Unknown,
missing, changed and wrong-type fields still reject. The current full-state
fingerprint, constructed fixture, clone/restore equality and gameplay checks
remain unchanged. The current-source private probe confirms the same actual
and restored full hashes, heat zero and an empty round-trip diff.

Native parser qualification and 73 hostile cases pass, including all 17
wrong/missing/type cases, unknown additions, unchanged pinned values and
structural corruption. Caller data remains unchanged. The durable checker is
`scripts/tests/tutorial_fixture_historical_authority_check.gd`. Raw synthetic
states and all private paths remain outside the repository in
`evidence/tutorial-pin-history-20261104-r1/` and the isolated native receipts.

### Separate synthetic animation-fixture finding

The full guide gets past the former fingerprint failure, then fails its
finite-transition assertion. This is tracked independently as
`BTH061-AUDIT-TUTORIAL-ANIMATION-001`. The synthetic fixture still sends an
anchored action after production lesson completion moved to the
`game.wager_raised` state predicate in `c458224b`; its first lesson therefore
remains active. The old assertion treats any active lesson as a prematurely
started next lesson. That result is not evidence of a product animation bug.
The test-only correction must explicitly author its synthetic completion,
settle the first dialogue before its canvas injection, and assert exact
first/next identities and active finite channel around the blocked interval.
Production scheduling and gates remain unchanged. Full acceptance is pending.

The strengthened observer also exposed a stale object reference: the capture
helper deliberately installs a restored RunState, while its caller kept the
old instance. Guide queue ownership itself is unchanged. The caller now
rebinds immediately after that replacement, and the cadence method checks
identity and complete displayed/current queue equality. It observes the
synthetic channel active at each of five blocked frames, then requires the
exact second lesson, event, dialogue and node after release.

Both test-only fixes now have separate commits:
`c3d92ba8728c744d48c53c959d608f2303a06e47` for historical fixture authority and
its durable 73-case checker, and
`4bc0147b7ae3667fbaba654985603ec8fe76f38a` for synthetic cadence/current-run
custody. The published checker passes all 73 cases. The complete native
`tutorial_dialogue_trigger_cadence_check.gd` now passes at exact test SHA-256
`bf5fe28bc11b92d38e99acef3248af14304875730bc4b17dbd20e82a19830461`.
All owned native jobs close with zero active processes. The existing isolated
host certificate-store diagnostic is retained; no TLS behavior is changed.
These are test repairs, not changes to current feature semantics. NEXT
acceptance and the unchanged aggregate validator remain pending.

### Aggregate validator evidence limit

Host-r4's five new identities form the known other-workspace process chain,
starting within 619.6096 ms. Baseline/post/live confirmation use the same
PID/UTC-creation/name identity. Validator synthetic descendants use pinned
Windows PowerShell; the external Python/Godot chain is not validator-owned.
No guard correction or exclusion is justified.

The global-process throw precedes later lease/residue/cache/environment checks
and rethrow of the inner launcher failure. Consequently, the old receipt proves
the earlier source/authoring/migration results, but does not by itself prove
inner launcher or later postcondition success. A private capture extension now
records missing versus null/empty variables, scalar custody/exit/cleanup facts,
terminal boundary and inner exception type without raw command lines or error
contents. Its diagnostic-only harness passes; this is not a project-validator
pass. The next unchanged complete invocation will retain those facts even if
external concurrency again prevents aggregate acceptance. Other workers,
process guards and machinery are left unchanged.

Host-r5 ran the unchanged validator from 02:59:02 to 03:05:44 UTC. Its captured
inner launcher contracts pass 40/40 and the independent contracts pass 11/11.
Both native exits are zero with clean executable pins, successful Job
assignment/accounting/cleanup and zero final active members. The owned manifest
reaches `validator-terminal-green`, sequence 7, with the shadow removed and
handles terminal. There is no deferred inner failure. Validator source hashes
before and after are identical.

Complete qualification nevertheless fails at the unchanged global process
guard: six new external-to-validator identities appeared. Four have a recorded
other-workspace marker; the other two have unresolved workspace attribution.
They are not silently excluded or assumed to be validator-owned. All four
later lease/residue/cache/environment checks are unreached, so no pass is
claimed for them. The exact remaining blocker for
`BTH061-AUDIT-VALIDATOR-001` is an unchanged complete invocation whose global
process census remains consistent through that boundary. No peer was stopped
and no admission hold is inferred. The sanitized machine evidence is
`tool_audit/validator_host_r5_safe_summary.json`; raw process commands and
diagnostics stay private. The umbrella remains Open as requested.

### Publication review blocker

After preserving concurrent main updates, clean candidate
`227a74eb337dffdadc2b32f93bd70db798dcd62d` passes the full native tutorial,
the durable checker parser and all 73 hostile cases again. All three stages
exit zero, with no script errors or owned processes after closure. Relative to
the integrated remote base, the introduced paths are only two tutorial tests
and the audit plan/report. No product, item, authored scenario, data, native,
scene or scheduling input is changed by these repairs.

Automatic approval review rejected the exact action `git push origin HEAD:main`
to `erikjpet/BeatTheHouse:main`, stating that authorization for this exact shared
main publication could not be verified and treating it as an external,
deployment-like commitment. The Git process did not run. No alternate or
indirect publication was attempted. The fixes remain committed locally as
`c3d92ba8728c744d48c53c959d608f2303a06e47` and
`4bc0147b7ae3667fbaba654985603ec8fe76f38a`; their task IDs remain Open pending
publication/NEXT acceptance. The pause and all pending evidence are preserved.
Recorded-context lookup was unavailable, so the rejection has not been resolved
with new authorization evidence. This is an automated publication block, not an
intentional user hold or an unfinished implementation.

## Approved finished-work NEXT follow-through

The user subsequently explicitly approved pushing all finished work to NEXT.
`BTH061-AUDIT-PUBLISH-NEXT-002` tracks this follow-through. The earlier rejected
push never ran; the new approval permits one retry, with any further rejection
reported rather than bypassed. No prior acceptance gap is silently closed.

Integration starts from current main `9894795bfc71690ef49c25baa6c50702920e7ac9`.
Original tutorial fixes `c3d92ba8` and `4bc0147b` are integrated as
`b5fb8d1979552f98cc4c8080e617ccf9384b4ad8` and
`a735b135ac3c79b0125419b83f17b9c94b2f687e`. The independent reviewed UI/tool
commits `8ba8ba8a` and `88cb119b` retain their original commit identities.
Only two tutorial tests, three UI helpers, five tools and audit documentation
are introduced. There are no product item/scenario/data/native/scheduling,
validator or pipeline edits. The preserved `source` branch remains untouched.

Combined current-main focused checks and exact existing-watcher NEXT acceptance
are recorded below when available. The broad audit remains Open, including the
unchanged aggregate-validator process-census acceptance and paused-area remainder.

On integrated candidate `a735b135ac3c79b0125419b83f17b9c94b2f687e`, normal import,
HUD12, UI design-system, wager150, full tutorial cadence, durable parser and all73
hostile controls pass. Test scripts match their recorded exact file hashes and
every owned Job closes with zero active processes. The source-owned validator,
trusted fixture pin and native/toolchain inputs are unchanged. Private receipts
are `evidence/independent-ui-publish-20261104-r1/`,
`evidence/resume-tutorial-publish-20261104-r1/` and
`evidence/resume-hostile-durable-tutorial-publish-20261104-r1/`.

## Finished-work NEXT delivery acceptance

The approved push succeeded. The existing watcher detected and automatically
promoted `df7d77a820b59f787701fb578cdd4a3b08bbb974`, tree
`d4806443bb4d548ba1e09154119333315521f2b4`, at **2026-11-04 15:56:28 UTC**.
Before publication, concurrent main `ee02497f` was merged and the focused
HUD12/design-system/wager150/full tutorial checks passed again on that exact
combined source. The durable73 hostile controls and unchanged generator/capture
structural/parser evidence retain their stated scope; image parity was not run.

Served NEXT metadata, redirect, BUILD/manifest/REF/VERSION, archive provenance,
exact PCK audit and four required payload size/MIME checks match this SHA/tree.
A fresh disposable browser renders the correct-version menu with zero page or
console errors, GPU sandbox enabled, zero inputs and all owned processes closed.
This proves basic Web launch; changed tooltip/wager/tutorial behavior is qualified
by the focused native checks, not a claim of replayed Web gameplay or phone tests.
No stable/itch/audience, item/scenario, scheduling, guard or pipeline change was
introduced. The preserved sibling repair branch and tutorial hashes are unchanged.

The five scoped tutorial/UI/tool/publication tasks now have associated commits
and exact NEXT evidence. The codebase-wide umbrella and aggregate-validator task
remain Open. The prior host-r5 global-process-census failure and its four
unreached postconditions have not been waived or misreported as passing.

Private receipts: `evidence/approved-audit-scope-20261104-r1.json`,
`evidence/independent-ui-final-publish-20261104-r2/job.json`,
`evidence/approved-audit-next-identity-20261104-r1.json`,
`evidence/next-startup-approved-audit-20261104-r1/` and
`evidence/approved-audit-next-acceptance-20261104-r1.json`.
