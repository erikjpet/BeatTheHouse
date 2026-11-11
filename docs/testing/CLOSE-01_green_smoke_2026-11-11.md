# CLOSE-01 — tutorial and Smoke closure

Source: docs/todo/BTH_0.6.1_closeout_plan.md. Up-to-date initial main4cb86ee3fd9b04733a794af2289ab8fce0132443, following accepted audit2113db41 and separately delivered Count repair. Plan saved unchanged, SHA256 b6f8e907a0af800fec4d64b195d6b69af9eb7af905f41bc5ce241fbf7d7a6d64, first commit84627b0fe6380eaf7f4d52c4f3c05bf8d18f94df. Registration precedes implementation.

## Tutorial first — actual new-profile NEXT before changes

Exact immutable served4cb86ee3fd9b04733a794af2289ab8fce0132443, fresh admitted E browser profile, no initial save; unmodified HTML/PCK/engine/native.49 normal-control commands,0 page errors,0 console warnings/errors,4 asset requests200. No scene override, save editing or internal gameplay call.

- **Pull Tabs redemption advances:** Play mandatory first-night tutorial→pick up glasses→Inventory→Corner Store→inspect and buy both shelf items→Crew warning→phone/call/confirm family loan→parking tip→Gas Casino→four confirmed Peeks→buy tickets/Collect Tray→peel/file scripted target#012→Leave→Nell→Cash In Pull Tabs. Cash75→175 for one100 winner, then Pal switches to underground map lesson. One additional2-cost column ticket and one filed loser are retained in raw input history; no value or hidden-state edits. Screenshot041 is decisive.
- **Blackjack wager advances:** same run→map→The Punchline→Blackjack→Deal5 (cash161→156)→Stand on14→dealer23 bust, pays10 (cash166)→real1-dollar felt chip raises next wager5→6. Pal advances from Raise it once to Deal the Peek hand; screenshot049 is decisive.

Both results were reported immediately in chat. These observations disprove the claimed player progression stalls on this build. Before modifying either check, source confirms intentional replacement: tutorial_blackjack_raise completion is durable game.wager_raised state, not any blackjack_chip notification; tutorial_gas_redeem requires ENVIRONMENT at gas_station_casino plus the retained scripted_target_redeemed receipt, not last_hook_result.action_id alone. The existing tests exercise the superseded action-only completion and fabricated hook while still on GAME respectively. Full replacement provenance and changes follow below.

## Failure classification, written before edits

| Failure | Classification | Evidence before edits | Planned correction |
| --- | --- | --- | --- |
| Blackjack wager lesson | Stale expectation | Normal real wager5→6 advances. Current authored completion uses game.wager_raised; check_core_content calls action-only completion_matches. | Assert current durable state completion plus negative controls; preserve action-trigger tests for action lessons. |
| Pull Tabs redemption lesson | Stale harness | Actual Nell payment75→175 advances; test injects a hook id while app remains on GAME and no actual receipt, contradicting current lesson environment/receipt predicate. | Exercise actual purchase/file/redemption and environment transition; negative check before payment and receipt persistence after. |

Initial checkpoint before repairs: a fresh full Smoke baseline was run under unchanged caps and fresh E paths. Its confirmed output and each subsequent classification are recorded below; the reviewer classifications were not assumed.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: close061-tutorial-before-web-20261111.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\close061-record-tutorial-before-classification-20261111\evidence\raw-evidence-index.json | f4104a27739922047de9ea198e3be99428b5fb5b77e44c0db76a4fdc4224aa0f |
| E:\CodexQA\BTH\runs\close061-tutorial-before-web-20261111\evidence\041-redeem-scripted-winner.png | a00b529438ada4bb813b2dde755f322c439a7814953d93a6138f5744b0b6b402 |
| E:\CodexQA\BTH\runs\close061-tutorial-before-web-20261111\evidence\049-raise-real-felt-chip.png | a78dff5373570b8f39b0a146eb3876fecc2bf462743a88eafc90736a93b85b13 |
| E:\CodexQA\BTH\runs\close061-tutorial-before-web-20261111\evidence\result.json | 3f056ff82fef587886b3400f03451cd1aab49d2b9c388df4a36fe11420cd309a |
| E:\CodexQA\BTH\runs\close061-tutorial-before-web-20261111\evidence\job.json | e56f215ac401b16e10dc3f8bf3f7a91292da9dfb4f5d25f340bade3443849a6c |
| E:\CodexQA\BTH\runs\close061-tutorial-before-web-20261111\evidence\storage-manifest.json | e1fb6e635de7fda9d21ca07a21765bc2ec8560814a661dfbdc2bc9e364d6ee29 |

## Fresh pre-edit Smoke baseline

Exact command: tools/check_godot.ps1 -Suite Smoke -RequireGodot -KeepGoing -ReportDir <admitted E evidence>/smoke -VerboseStages. Sourcef00a686f082a3b4ca277d5541755616320e5264c, runtime unchanged since initial4cb86ee3. Exit1,4 stages pass/7 fail; no timeout; active release0. Content25 failures, runtime16, damaged geometry4, performance10 categories.

| Stage | Exit | Duration ms |
| --- | --- | --- |
| validate_project | 1 | 95816 |
| godot_import | 0 | 11699 |
| gdscript_load_check | 1 | 45882 |
| foundation_smoke_content | 1 | 39602 |
| foundation_smoke_runtime | 1 | 55084 |
| ui_scene_compile | 1 | 27370 |
| cold_continue_room_projection | 1 | 16023 |
| game_library_launchers | 0 | 20939 |
| dave_bus_encounter | 0 | 24267 |
| roulette_audio_audit | 0 | 4680 |
| foundation_perf_smoke | 1 | 75274 |

Before any edit, three next classifications: generated layout breakdown is a **stale generated expectation** (validator compares current source-model render bytes to committed output and reports missing/stale); Rourke override is a **stale harness** (parent has fourth bool refresh_presentation defaulttrue, child still declares3 parameters); scenario presentation probe is a **stale harness** (contract check now requires ContentLibrary and failures, probe supplies only failures). Correct the artifacts/call signatures, preserving all checks and defaults.

Tutorial replacement provenance: c458224b8e65fb6a7f1f5415f0f86f587c837e1a intentionally replaced action notifications with durable raised-wager state;27368b993e23851efa411fb422cf7881ad7c7236 intentionally replaced transient redemption action with persisted target receipt and environment boundary.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: close061-before-smoke-20261111, close061-confirm-deliberate-tutorial-contract-changes-20261111.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\close061-baseline-and-trivial-classifications-20261111\evidence\raw-evidence-index.json | db7fd02501b4433c757264aae3a2c9e5b0c7c3312ccc879ef08b270ed63374dd |
| E:\CodexQA\BTH\runs\close061-before-smoke-20261111\evidence\smoke\summary.json | addec527e1437ea1fcaf7fcbe1c57b4facac7f01805709dd8a31531621e6f90f |
| E:\CodexQA\BTH\runs\close061-before-smoke-20261111\evidence\smoke\foundation_smoke_content.json | a0dc260c145cc70993d96355958cfbee3df841b6fc15bfa1ae728a2bb79ca98c |
| E:\CodexQA\BTH\runs\close061-before-smoke-20261111\evidence\smoke\foundation_smoke_runtime.json | f4f5e26578885d9aadaafe21f752f95e057b884f32e1c873be6e51af418bf2e2 |
| E:\CodexQA\BTH\runs\close061-before-smoke-20261111\evidence\smoke\cold_continue_room_projection.stderr.txt | 216457fd20f765ca3994670255cd0b7ede9a869fd972584545595bfaa6dd73f0 |
| E:\CodexQA\BTH\runs\close061-before-smoke-20261111\evidence\smoke\foundation_perf_smoke.stderr.txt | 490296bf7e976628b7aac7bac0631afbf18703d0069e72cdcb008254cd7b70d0 |

### Five initial-arrival failures — stale harness, before repair

The direct unchanged synthetic fixture builds an object manifest but its unknown fixture_environment has no authored slot schema/map. The real binder rejects it with missing schema/fixed/event/scenario/exit slots; atomic generator installation rolls back, leaving no room id. The harness then tries to finalize that empty run, producing the misleading Object manifest is missing text. Real playable rooms are not implicated. This deliberately stronger production requirement replaced pre-slot fixture generation. Repair the synthetic catalog with its own complete isolated authored map and run the unchanged real manifest/binder/install/finalization path; do not bypass readiness or forge a seal. Existing production maps and item/scenario content remain untouched. Diagnostic command/actual output: close061-fixture-arrival-composed-diagnostic-20261111.

After the fixture-only map repair, the unchanged RNG twin A/B, game-result twin A/B and contract arrival tests pass. All five initial-arrival failures and their five downstream hooks/cues/flags/event failures disappear. The full same7-check foundation run now has31 failures (25content+6runtime) vs41 before; no check omitted. Parser load826/0 passes. Layout generated check75contexts607slots passes. Validation exposed a further Get-FileHash command-resolution failure in the exact-seed hostile launcher self-test; it is recorded for diagnosis, not yet classified or altered.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: close061-fixture-arrival-composed-diagnostic-20261111, close061-runtime-after-fixture-authority-20261111, close061-parser-load-after-20261111, close061-layout-breakdown-check-20261111.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\close061-record-fixture-and-ledger-delivery-20261111\evidence\raw-evidence-index.json | 246e90833b1f9b836c52ab9c5171bc55fb1d7440f49cfb3f208baf5bb7703607 |
| E:\CodexQA\BTH\runs\close061-runtime-after-fixture-authority-20261111\evidence\smoke\foundation_smoke.json | a5918bc7268043fb15548d0f3c7bb422aad5dd933cfac774a559acb80a424d9a |
| E:\CodexQA\BTH\runs\close061-runtime-after-fixture-authority-20261111\evidence\smoke\summary.json | 4035e257871ac7ccba3c27154b7990a5d033d44e04b3ff953b77bd72bceb57f9 |
| E:\CodexQA\BTH\runs\close061-runtime-after-fixture-authority-20261111\evidence\smoke\gdscript_load_check.json | 5f4cdadd7f43840d1c866f6ff30a4d734f583e65c723a969471cf2c9f8ea61cb |
| E:\CodexQA\BTH\runs\close061-parser-load-after-20261111\evidence\gdscript_load_check.json | ab22d9ad557b800101c636b82661f95e254e7f6e0bdaf65940f97eb1634050b2 |

### Additional launcher failure: classification before correction

The regenerated validator reaches its hostile-launcher self-test but cannot resolve
Get-FileHash. A separate untouched native-bootstrap command fails on that same
cmdlet. The Windows PowerShell 5.1 probe proves it imports PowerShell 7's Utility
module first from the desktop's inherited PSModulePath, where that cmdlet is not
exported, despite the correct 5.1 module being installed. Classification: stale
QA launcher environment, not a failed hostile contract or a product defect.
Correct only the ignored audit controller's module search path to the installed
Windows PowerShell module directory when launching its canonical 5.1 executable.
No repository launcher, security setting, resource/storage limit or test changes.

### Damaged sealed geometry: product defect (before repair)

Both decode→encode→packed-save→decode and RunState.from_dict preserve the injected
all-zero digest. The existing incoming-authority validator accepts the unchanged
captured save, and rejects the damaged one with "Scenario manifest layout authority
digest is invalid." The production finalizer instead reconstructs and replaces
that durable seal before validating it, explaining all four Smoke assertions.
Restore the incoming strict authority check at the cold-rebuild boundary before
any layout refresh. Preserve the rejected bytes and all four original assertions;
renderer caches alone may be rebuilt. No test expectation changes for this defect.

The first replacement UI harness exposed its own ticket-selection mistake: it
opened all three paid tickets but filed only #010, a loser, leaving #012 ready to
file. The diagnostic shows target-consumed=true, target-ready-to-file=true and
target-filed=false, with all three tickets revealed. Correct the normal-control
sequence to open/file each purchased stack entry until the marked winner is filed,
allowing the full 1.02s peel animation. No fabricated ticket or receipt is injected.

The original cold-Continue check now passes unchanged: restored_objects=9,
damaged_authority_rejected=true; all four damaged-geometry assertions remain.

### Remaining shared contracts: classification before repair

Two ActionResult UI-key failures are the older production-game smoke caller
passing Video Poker draw/mark_holds host responses to the core-only lint.
The response declares only bet_level and denomination_index. Commit e772560f
already introduced a strict host-response boundary for exactly these producers,
checking its settled, bounded presentation session and preserving every core field,
with hostile producer/action, nested UI, nonplain and account-leak controls.
Classification: stale harness caller. Route these two calls through that existing
boundary; keep the raw core lint and all rejection controls.

The event authority failure is scenario_graveyard_maintenance at
gas_station_casino_002. Its exact declared host is the scenario shutter panel,
present in the scenario authority and physical manifest, while Nell and
parking_lot_tip remain in base bindings. The existing test reads only base bindings
for all three. The production composed-publication proof deliberately separates
scenario authority from base layout (7181ce43 placement workflow). Classification:
stale harness. Keep strict base validation, additionally validate the complete
publication and check scenario-host bindings/geometry against the authenticated
scenario authority rather than inventing a base slot.

The UI stage now passes the paid tutorial receipt checks and reaches an older New
Run assertion. Classification: stale harness following the deliberately accepted
QOL-01 change b0cb51df: a menu start that replaces a loadable save now waits for
explicit confirmation. The legacy challenge/content-group cases emit New Run but
never press the visible confirmation. Require that dialog and press its real
Start button before retaining the original seed/challenge/content assertions.

### Architecture and draw tripwires: classifications before repair

The two shell-token failures are product architecture defects: the shell owns
Blackjack-specific wager restoration and recorded-net/old-penalty interpretation,
plus ticket-specific counter recovery and tutorial receipt rules. These are real
game semantics, introduced deliberately for correctness, but their shared UI
location violates the unchanged module-boundary rule. Move those decisions behind
explicit GameModule methods with neutral defaults and game-owned implementations.
Keep the token lint unchanged and retain the full net-feedback, closing-counter,
wager-restore and tutorial behavior checks. No spelling-only bypass or allow-list.

The three draw tripwires are product performance defects. The Blackjack ritual
draw makes a shallow dictionary copy solely to override three displayed scalars;
read those scalars locally instead. The Street Craps draw constructs identical
cash polygon/corner arrays every scheduled frame; retain bounded geometry keyed
by the unchanged board rectangle. Preserve all drawing and no-input scheduling.

The two nine-word lender/event lines violate the actual eight-word content rule.
Classification: product text defects. Apply owner C5 by removing only "package"
from the lender line and "The" from the event line. Consequences are unchanged.

### Four talk consequence failures: stale harness, not changed values

The diagnostic resolves all three original choices unchanged and receives
ok=false, bankroll=0, heat=0, "Room object authority is invalid." The invented
talk_parity archetype has no slot schema/map. The authored values are still
suspicious_patron/talk_down heat -3; motel_knock/borrow cash +35;
the_collector/pay_now cash -20 and heat -2. The reviewer's suggested changed-data
classification is therefore disproved. Replace the invalid room fixture with a
real generated/finalized Bar room, retain the exact four expected values, and
require a successful result before checking them. Keep triggered-event ownership.

The first broad rerun stopped before Godot: the validator's exact reviewed-source
classification still names the old wager-selector line moved behind GameModule.
This is a stale expectation created by this repair; update the two exact reviewed
bindings to the new module-policy calls, retaining the named function, exact-line
match, ambiguity rejection, binding count and hostile controls. The security
allow-list is unchanged. The rerun also correctly refused a concurrently finishing
diagnostic Godot process; it is not counted as a full Smoke result. Subsequent
Godot checks are serialized.

### Sixteen layout reports: stale expectation (before repair)

The exact original checks report 15 Lounge pairs and one Grand Casino pair.
For every reported pair the diagnostic proves actual_overlap=false and area=0:
the old helper pads BOTH rectangles by 8 board pixels, demanding a 16px gap.
Grand Casino desk/staff have a real 9px horizontal gap; several Lounge manual
placements intentionally have 1–11px gaps. The accepted saved placements
(9794d07a and earlier authored edits) replaced the older auto-packing clearance
rule; none of these sixteen are shared hit authority.

Exact served NEXT f00a686f... was reviewed through the Environment Library with
normal controls: Lounge base rendered; Grand Casino base rendered; Host Desk and
Iris independently focused with distinct cards (screenshots 007,012,013,014).
No placement/content edit is warranted. Update only the obsolete expectation:
for two explicitly hand-positioned slots, require exact authored binding/geometry
and exclusive actual rectangles; retain the old padded clearance for generated
slots. Add a tampered-geometry negative control, and retain every original pair
and fixture/host/lender assertion. No check is skipped or blanket-exempted.

The remaining scenario-host failure also crosses a deliberate storage projection:
EnvironmentInstance.to_dict retains scenario semantic version/digest and causal
state, but intentionally omits compiled scenario layout authority. Validate the
generated instance shape against the full authoritative RunState room supplied
by its caller, requiring that room's EnvironmentInstance projection exactly
equals the tested instance. Then use its complete sealed scenario host proof.
The full composed room is not reconstructed or fabricated by this check.

### Newly reached Sal shelf assertion: stale expectation (before repair)

After tutorial/confirmation repairs, UI reaches seven Sal shelf "overlaps".
The focused diagnostic captures every model, padded footprint, interaction target
and label: actual shelf targets are 72x48 and separated; only 8px padding on both
sides overlaps. Label resolution reports zero label/label and label/object
collisions. The six exact shelf slot identities remain distinct, matching the
accepted manual Pawn positions (fade41b4). Replace the old generated-clearance
expectation with exhaustive actual-target exclusivity, exact authored rectangles,
label-clearance checks and a coincident-target negative control. Keep all six
stable shelf, shared Sal, travel, purchase and persistence assertions.

### Remaining performance failures: confirmed classifications

Slot icon/status (two assertions): PRODUCT DEFECT. The untouched public practice
launcher returns ok=true for six Slot cabinets, but its Grand Casino map has only
four unreserved compatible machine slots. Its initial layout already reports no
slot for game:slot:5 / :6 and contains empty bindings/digest. The live Slot module
correctly reports active=true, AUTO and increasing spin_count; the room correctly
refuses publication. This precedes leaving the surface or the fixture's due-time
write. Supply a separately identified six-cabinet practice placement authority
using the launcher's existing six authored coordinates. Preserve normal Grand
Casino maps/hashes and strict room validation; test all six published identities.

Late Crew conversation: STALE HARNESS. It renames a copied initial room to Delta
Queen, changes all its physical selections, and retains the old binding seal.
The exact diagnostic reports binding-digest stale and no published room before
opening the lender. Replace this fabricated envelope with real generated/finalized
Delta arrival, retain actual lender/game membership and the real world map, and
finalize its restored copy through the cold-load boundary. Preserve all legacy
scratch-mask payloads, exact lender context limits, compaction ratios and budgets.

The six original Coin Pusher failures are STALE HARNESS ENVIRONMENT: the fresh QA
clone lacked the native extension. Built exact current native sources with the
unchanged pinned compiler/bootstrap/runtime verifier and imported the newly built
artifact. The complete unchanged probe now proves native_v3, raw300 timing, the
160-body DROP/carriage/skill-stop/collect sequence and unchanged22/7ms budgets.
The deferred retention campaign remains deferred. This is no native source,
backend-rule, budget, cap or pipeline modification.

The Blackjack draw category now measures3.175ms p95 (<5ms), with13 autonomous
redraws against floor8; baseline13.55ms. The local scalar draw repair preserves
display values and removes its dictionary copy. Treat timing as this run's
measurement; final full Smoke/candidate measurements remain required.

### Focused repair checkpoint

The six-cabinet public-launch contract passes12/12: strict room authority; all six
published cabinet identities; separate practice cache/seal identity; ordinary
Grand Casino map hash unchanged; host save-shaped round trip; edited geometry
still rejected. The first profile attempt correctly failed because its inherited
cabinet classes differed; the final profile retains each existing cabinet class.

All seven foundation check IDs ran, with no skipped checks: content0 failures
(vs25 baseline), coach0(vs1), onboarding0, profile0, shared contracts1(vs5),
fixture_rng0(vs4), fixture_contracts0(vs6). That final shared scenario-host case
is now supplied its exact live authority as described above; rerun remains due.

### Generated guide correction refined

Regeneration changes no canonical Git content: the checked-out generated guide
had Windows CRLF, while its unchanged --check compares exact LF UTF-8 bytes.
Classification is therefore stale checkout/harness encoding, rather than changed
layout rows. Regeneration restores the exact607-slot output locally. Pin LF for
this one generated Markdown file in .gitattributes so a fresh Windows checkout
also passes the same byte-exact generator check; do not normalize or weaken the
generator comparison. Historical byte-authenticated fixtures remain untouched.

After Slot/Crew repairs the full46-observation performance probe clears those
three failures and all Coin Pusher categories. Blackjack p95 remains intermittent
(10.52ms in this run); the earlier3.175ms result did not close that category.
A component profile preserves all drawing and identifies chip rail and patrons
as the largest steady work. Further measurement/optimization is required.

The full-flow component diagnostic confirms steady chip-rail work is largest
(~628us of ~2.58ms total). Each chip recomputes12 identical rim-spoke endpoints
and makes12 separate native line calls. Cache those exact endpoints in a
bounded128-entry geometry cache and submit the same12 independent segments in
one CanvasItem.draw_multiline call. Preserve colors, line widths, labels, chip
hits, all moving actors and every autonomous redraw. Non-Canvas audit doubles
retain equivalent individual-line replay. This reduces real scheduled work;
neither the5ms budget nor sampling/liveness floors change.

### Newly reached multi-slot UI fixture: stale harness (before repair)

Installation and explicit finalization already pass strict authority. The later
host refresh has cycle_failed=true and removes publication because the static
ui_multi_slot_fixture_room is mistaken for a scheduled Grand Casino visit:
"base presentation record1 is not backed by an exact environment source
(event:scenario_audit_roster/event/scenario_audit_roster)." Adding the ordinary
practice_session flag does not correct this; no such bypass is assumed.

387013ac deliberately introduced live venue rotation. The existing Environment
Library's environment_test_session scope is the explicit static-room contract.
The diagnostic using that exact scope plus normal finalization passes: all three
original Slot objects are published, strict authority remains valid, and cycle
rotation stays outside this static fixture. Mark this synthetic fixture explicitly,
check installation/finalization success, and retain its original three separate
machine states and every reentry/checkpoint assertion. No production cycle guard
or room validation changes.

Chip geometry check157/157 and animation liveness PASS after segment batching.

The repaired multi-slot fixture passes within the full UI run. The next reached
failure is the Daily Run case, whose legacy fixture also emits a menu start over
an existing save without answering QOL-01's replacement dialog (b0cb51df).
Classification: stale harness. Require and press the same visible explicit
confirmation before retaining the existing Daily Run seed/config assertions.

The uninstrumented complete performance probe now exits0 after chip batching:
46 observations, all11 game surfaces, all10 resolve paths and all8 required new
surface modes covered. Every original budget and liveness floor is unchanged.
Raw JSON contains exact per-mode timings and coverage. This does not substitute
for the final complete11-stage Smoke invocation.

### Newly reached live-room layout failure: product defect plus stale spacing

The Back Alley UI diagnostic distinguishes its five reports: four have zero
actual target overlap and only obsolete padded clearance. The item pair
lock_jammer/feature_magnet has a real159.0016px² target overlap (3px horizontal).
Their authored slots are separate, but the live view model supplies an explicit
default fixed_slot_geometry=false; the authenticated manifest join preserves
that false because it sets the flag only when absent. The canvas then expands
the bound72px items to its legacy90px natural minima. This is a PRODUCT DEFECT,
not a reason to waive the item collision.

Restore the same fixed-slot marker that the production binder already stamps
unconditionally (f3ab259e), after the manifest join has authenticated slot/family/
class. Keep unknown/mismatched bindings rejected. Add the false-default regression
to the manifest contract. Then evaluate exact target exclusivity and authored
geometry, retaining rejection of actual collisions; padded spacing is not the
manual-placement contract. No item/scenario data or animation scheduling changes.

### Newly reached Grand Casino spatial UI: stale harness (before repair)

close061-grand-spatial-before-20261111 reproduces the missing Host Desk:
publication=true and strict authority errors=[] immediately after installation,
then cycle_failed=true, publication=false and objects=[] after a twenty-day
staff rotation and refresh. The fixture duplicates the bare Grand archetype into
grand_casino_ui_hud_fixture without declaring its static test context. Actual
NEXT f00 Host Desk and Iris were independently focused in the earlier rendered
layout review. Deliberate live venue-cycle replacement387013ac requires a real
visit or the explicit Environment Library environment_test_session scope.
Mark this static HUD fixture with that existing scope; retain every staff,
rotation cue, four authored objects, door access and cash-fallback assertion.
No production venue-cycle bypass is added.

The first scope edit replaced rather than merged authored local flags; its diagnostic correctly rejected missing casino fixtures/doors while publication remained valid. Corrected the fixture edit to merge the one scope marker and retain all authored flags. This failed experiment is retained in external evidence; no assertion was changed.

### Newly reached Health Inspector interrupt ordering: stale harness (before repair)

The full UI run now clears the Grand Casino HUD matrix and reaches the timed
interrupt checks. Two assertions fail: forced-travel outer order and destination
change. The fixture arms only health_inspector_closing_actions=1; production
reconcile_health_inspector_venue_scope deliberately refuses an unknown legacy
allowance without an originating venue or a retained accepted-event receipt.
AUD061-09 added this venue ownership to prevent later unrelated rooms spending
an old allowance. The fixture supplies neither. Add the current room's exact
origin id to this explicitly armed interrupt fixture. Retain exact stage counts
[1,1,1,0,0], forced flag and real enabled-route destination-change assertions.
The production venue-scope guard is unchanged.

### Newly reached inactive-delivery travel snapshot: stale expectation (before repair)

The untouched source control f00a686f (fresh source-only archive, fresh profile)
and the CLOSE-01 candidate produce **identical full environment and world-map
values**, not merely matching scalars. Their exact room/world hashes are
f563ddfe23c125be386c7690cbf14e1a3f756eda46b74f2fa454d2ce39ba8d91 /
56b43eea175ca046e89aff1120695ea2377506208cfae9a94cdb952db525e7ea.
The untouched f00 source retains pre-C5 text and the candidate has the shortened lines; their full values are still identical.

The legacy snapshot was introduced by0d114bcd. Source-only replays of its named
86961119 source and0d114bcd both produce the older scenario-bearing structure
but do not reproduce the two documented byte pins in this environment; that
limitation is retained, not claimed as an exact historical reproduction.
Full old/current leaf comparison records the deliberate replacements:
venue-cycle identity/retirement387013ac,0adf3925,32052d05 removes expired stored
Bar scenarios and per-visit transient fields; authored physical placement changes
and Bar patron-seat hints04965ffa replace old geometry. The scenario replacement
also explains its derived stake limits/patrons/rumors, not a payout-table change.
All route, fare(-4), clock(+42), Heat(0), RNG953559834, story, action index0 and
travel count(+1) remain exact. No CLOSE-01 runtime regression is present.

Refresh only the two complete-value hash expectations to the independently
reproduced pre-closeout f00 source. Keep every scalar/hash assertion and all
three phases (before/after delivery lifecycle and same-process restart).
Raw comparison.json retains every changed historical leaf and proves zero
control/candidate differences. No production state is normalized or ignored.

### Newly reached Crew favor conversation: stale harness/expectation (before repair)

The fixture queues no offer because it installs an old favor debt and pending flag
in the starting home. Accepted cd769f1881a94cbfd84a2375fb784ed867964433 replaced
favor debt with delivery obligations, actual Crew presence and the hourly25%
solicitation gate. Current eligibility requires obligations>0 and a live Crew
actor/group. The test supplies neither and must not bypass either guard.
Use real generated/finalized travel to the Corner Store's authored Crew lender,
model the last outstanding delivery as obligation1 with marker_clear=false, and
seed only the separate solicitation stream at the existing appointment fixture
seam48 (also used by crew_package_windows_check). Require real eligibility and
successful enqueue. The completed handoff must decrement1→0 and clear the marker;
retain the exact authored+22 cash/+4 Heat, package inventory,3 animated portraits,
visited-target preference, real route, strict owner-scoped slot, no abstract prop,
and all three byte-identical inactive ordinary-travel replays.

The handoff diagnostic confirms **early arrival**, not a financial discrepancy:
cash93, Heat1, obligation1 stay unchanged; strict room authority passes; the
recipient's actual window is Day1 14:30–15:00, and arrival is12:42.
Accepted04b3520571c38d243216ec68f025794289ee7f59 introduced these appointments.
Classification: stale harness. Preserve the early rejection as a negative
control with exact full account/RNG/inventory/obligation equality, advance the
fixture through the canonical game-clock API to its actual opening (the same
existing appointment test seam, no assignment to clock/state), refresh, require
available=true and then retain the exact+22/+4/final-obligation settlement.
The UI fixture explicitly disables continuous clock because its time is driven.

The complete focused Talk/Crew lifecycle now passes, including early rejection, appointment opening, exact+22/+4 settlement, final obligation clearance and all three full-value travel replays. The full UI runner is executing again. Manifest contracts pass maps21/variants20/rows172/roundtrips20/jazz6/lottery4, including the new explicit-false marker regression. Full Smoke remains pending; no green/complete claim yet.

### Newly reached dialogue route branch: stale harness (before repair)

The failed route response reports Room object authority is invalid. Its snapshot
contains no bound rectangles and an explicit placement error: Corner Store has no
compatible fixed.surface_item slot for game_hook:pull_tabs:ticket_redeemer.
The legacy fixture replaces that room's games with Pull Tabs without its declared
counter host and omits full arrival finalization. Accepted bf63e433 moved lottery
services onto declared counter NPCs; Corner Store does not host this lottery.
Use real generated/finalized Gas Casino with the existing Graveyard Shift pin,
its required Pull Tabs machine and authored Nell counter. Retain all speaker
override, dock geometry, unchanged world positions, story flag/route unlock,
repeat idempotency and suspicious-cashout no-double-Heat assertions. No shipping
room, scenario, counter rule or production authority guard changes.

### Newly reached preview/focus room: stale harness (before repair)

With the same full-library bootstrap as the complete UI runner, the event's two
choices are eligible, but every rendered object is absent and the host reports
Persisted base slot authority binding digest is missing or stale. The synthetic
room calls ensure_generated_layout without its content library, ignores the
installation outcome and omits required arrival finalization. The initial
isolated diagnostic without start_foundation_run had only the partial menu
catalog; it is not treated as a product reproduction. The corrected diagnostic
matches the real failure.

Bring this explicitly static preview fixture through current library-backed
manifest/binding/install/finalization, requiring all outcomes. Retain every exact
serialized-run equality around focus, choice preview/dismissal, item, service,
lender and travel, including overdue alcohol absorption. No input/authority or
simulation guard is relaxed.

The checked construction diagnostic identifies the exact incompatible object:
lender:street_lender needs fixed.standing_person, but Corner Store authors only
The Crew's group lender slot. The shipped archetype's lender_hooks is[the_crew].
Replace this synthetic lender with that real authored group, preserving both
lender focus and selection plus exact no-state-mutation assertions. Shipping
placements and lender content remain unchanged.

### Newly reached save/Continue status failure: stale harness (before repair)

Full diagnostic confirms that this is NOT obsolete wording: loaded-primary and
all saved account/story/travel values match, but publication=false and status is
Room unavailable; existing save retained. The status assertion remains unchanged.
A shorter exact-helper reproduction finds valid construction geometry/digest and
then the same synthetic-room/live-venue conflict already seen in the multi-Slot
and Grand HUD fixtures: event:scenario_audit_roster is injected by live venue
rotation but has no exact source in the synthetic Practice: Bar Dice room.
Publication is already absent **before** the save/Continue. The helper privately
borrows _game_test_environment into an ordinary RunState without declaring the
Environment Library static scope or checking install/finalization outcomes.

Classification: stale harness following deliberate venue-cycle387013ac. Merge
environment_test_session into this static fixture before installation, use its
library-backed binding and require installation/finalization success before game
entry. Preserve all action, wager, risk, save/Continue, visible-room and original
Loaded status assertions. No save guard, wording or production cycle changes.
This native helper is not represented as normal browser save-Continue coverage.

The short action-fixture reproduction now has publication=true both before and after public Continue, exact Loaded run status, no save errors and retained cash136. The original status assertion is unchanged. Complete UI is running; no remaining failure is pre-classified. git diff --check is clean; pinned project/presets/exporter/native/item/environment content and committed raw evidence have no diff.

### Newly reached event-card title: stale harness (before repair)

The fallback fixture directly assigns current_environment after constructing a
Corner Store, bypassing the atomic install and detached room publication.
Focused reproduction has current=ui_event_slot_fixture, published=null, eligible
late_shift_discount present in raw options, and title_visible=false before any
event resolution. The sealed-room publication model replaced these raw swaps:
the current model cannot render an uncommitted fixture. Install/finalize the
explicit static fixture through RunState with checked success, then refresh the
host view. Preserve title, choices, full state equality, inline actions and all
subsequent response/popup assertions. No event content or production guard changes.

### Newly reached item icon/holder: stale harness (before repair)

The fixture first proves a valid item icon path, then finds no rendered holder.
Its setup mutates an installed Motel home dictionary in place into Corner Store,
retaining the home's identity/registry/authority while replacing its archetype,
kind and layout; no atomic installation or publication follows. This is the same
raw-swap seam superseded by sealed room publication. Build a fresh Corner Store
instance with the same single8-cost Creased Luck Card offer, no other hooks,
explicit static scope and checked installation/finalization. Retain icon, exact
fixed-slot geometry, merchant, item text, cost, purchase/account, persistence and
all later item behavior assertions. No shipping item/environment data changes.

### Newly reached supported service object: stale harness (before repair)

The repaired item case passes its icon, geometry, merchant, purchase, sale and
persistence checks. The next hook fixture again mutates the installed shop into
Back Alley in place, replaces the service catalog, and inspects spatial objects
without an atomic room install/publication. This raw mutation predates the same
sealed-room model. Create a fresh explicitly static Back Alley with the existing
synthetic service(cost8/delta+3/flag), missing-lender negative case and unavailable
merchant, rebuild the deliberately replaced fixture catalog at its supported
invalidation seam, and require install/finalization before inspection.
Keep all exact costs/result deltas, duplicates, hidden missing lender and disabled
merchant assertions. No production service/lender definitions are edited.

### Newly reached immediate terminal routing: PRODUCT DEFECT (before repair)

The diagnostic classifies police_capture at Heat100 and commits run_status=failed,
but remains on GAME with terminal_game_result_presentation populated. Its
last_game_result is only {ok:true,type:game_enter,game_id:bar_dice,...}; no wager
or hand has occurred. The gate accepts any successful message. Accepted
776a819d0420c8801708b20b5e9376c5fd0d15fe introduced this wait specifically to
finish a committed table result before replacing it with the report. An entry
acknowledgement is not such a result. Restrict the presentation wait to canonical
successful game_action results; retain all paid-result animation/readability,
Save/Continue, nonending, reduced-motion, machine and Rourke hand protections.

First extend table_terminal_presentation_check with an entry-only external
police failure and exact unchanged cash/chips/RNG/inventory checks, then run it
red before the product edit. The original immediate FAILURE assertion stays.

Red regression confirmed: table-terminal check77 checks/1 failure, solely the new entry-only immediate route. All existing paid Blackjack/Baccarat, nonending, reduced-motion, machine and interrupted-save expectations pass. Apply the canonical game_action type guard now; retain every presentation timer and autonomous update.

### Final Crew lender actor fixture: stale harness (before repair)

The construction diagnostic has no placement errors and a valid binding digest,
but refresh has cycle_failed=true, publication=false, and an unbacked
event:call_brother_in_law injected by the live venue cycle. Native source mode is
confirmed (distribution env empty); fault controls are not being bypassed.
This is the same static-fixture/live-visit distinction387013ac. Mark the intended
static Corner Store fixture with environment_test_session, pass the actual library
and require arrival finalization. Keep the unrelated Motel event in the fixture
and preserve all three-actor/model/voice/context, rejection/retry and no-unrelated-
popup checks. Its later financial expectations are evaluated separately.

The final lender test now passes actor, hover,3 unique voices/models, bounded
context and injected rejection/retry checks, then fails only its old debt-marker
expectation. Classification: stale expectation. Accepted cd769f1881 replaced the
Crew favor debt with70 cash for2 delivery obligations, without cash repayment or
interest. Require exact bankroll1→71, obligations0→2 and debt=[] on acceptance.
Strengthen the rejected transaction check to require obligations remain0 as well
as unchanged cash/debt. Retain the original no-popup/no-unrelated-event assertions.
No production lender value is changed.

The first new principal assertion mistakenly used30 and correctly failed on
cash71/owed2/debt[]. The authoritative current definition and the original
cd769f1881 definition both have principal_min=principal_max=loan_amount=70 and
deliveries_per_loan=2. Correct the test to the verified unchanged70 advance
(bankroll1→71). This is a test-authoring mistake, not evidence of a product value
difference or a reason to change/round production money. Raw failed output stays.

### Compatibility after all Smoke repairs

The original table-terminal check is now77 checks/0 failures (before77/1,
solely the added entry-only regression). Existing paid-hand presentation,
interrupted-save, reduced-motion, nonending and machine cases remain intact.
Both runs retain the same shutdown resource diagnostics; they are not claimed
warning-free, and their capped jobs release with zero remaining processes.

The sequential compatibility worker exits0 for all seven invocations:
Rourke phased interruption; prepared surface routing; Blackjack net feedback
(179 checks); its separate fresh-process Continue(52 checks); closed-counter
redemption; Blackjack tutorial raise(15 checks); and animation liveness without
pointer input. Every captured error list is empty. The final Crew lender fixture
also passes with the verified unchanged70 advance and2 delivery obligations.
Full, unmodified11-stage Smoke is now running; focused results do not replace it.

### Candidate validation: stale harness exposed by exact chip-line batching

Canonical full Smoke's validator rejects the candidate because SurfaceHarness
has no draw_multiline method, now called by Blackjack's equivalent batched chip
rim drawing. The real Canvas already inherits this Godot drawing method, and
geometry157/157 plus live performance/liveness passed. Its strict API audit is
correctly exposing an incomplete test double. Classification: stale harness
introduced by this run. Add equivalent multiline drawing to the double, preserving
its complete method-coverage audit and geometry assertions. Do not allow-list or
skip the new call. Wait for this candidate run to finish before editing its source.

## Failure disposition table

All classifications above preceded the corresponding repair. This table also
includes failures reached only after the original blockers were removed.

| Failure / original count | Classification | Evidence and change |
| --- | --- | --- |
| Blackjack wager tutorial1 | Stale expectation | Fresh NEXT felt chip5→6 advances Pal; c458224b durable wager predicate replaces input-only completion. Check false/true state and unchanged-input rejection. |
| Pull Tabs redemption tutorial1 | Stale harness | Fresh NEXT paid marked winner filed at Nell advances Pal;27368b99 requires retained receipt and environment counter. Drive real ticket lifecycle and retain duplicate/account controls. |
| Generated breakdown stale1 | Stale generated expectation | Generator yields identical75 contexts/607 slots; CRLF checkout differs from canonical LF. Regenerate canonical LF using the unchanged strict check; final attribute file is identical to baseline. |
| Prepared route override / scenario probe2 | Stale harness | Parent adds refresh argument; scenario check requires library and errors. Match current signatures and pass both arguments. |
| Missing object manifest5 and dependent contract6 | Stale harness | Fixture never bound mandatory sealed object authority. Bind isolated synthetic map before freeze; inspect live scenario authority separately from base projection. |
| Talk consequence4 | Stale harness | Raw synthetic room cannot resolve under current publication guard. Generate/finalize real arrival; preserve all four exact cash/Heat expectations. No value updates. |
| Damaged geometry4 | Product defect | Trusted rebuild re-signed damaged sealed rectangles. Validate retained publication before rebuild; preserve bytes/save and all original four rejection assertions. |
| Kitty layout15 / Grand host1 | Stale expectation | Authored hand placements supersede automatic16px pair spacing; actual intersections0, rendered NEXT rooms/desk distinct. Require authenticated geometry and actual hit exclusivity for hand-placed pairs; retain padded automatic packing and tamper negative. |
| Draw allocations3 source hits | Product defect | Blackjack duplicates state; Street Craps constructs geometry every draw. Use scalars/bounded exact geometry cache, keep autonomous frames. |
| Video Poker ui_state2 | Stale harness | Strict host-response boundary deliberately owns UI envelope. Validate through existing boundary, retain nested/account/producer hostile controls. |
| UI shell game tokens2 | Product architecture defect | Game-specific recovery/feedback leaked into shell. Move identical behavior into game-owned neutral virtual methods; original lint unchanged and179+52 feedback checks pass. |
| Lender/event overlong2 | Product text defect | Both approved9-word lines become8 words; amounts, obligations and event consequences unchanged. |
| Slot perf active/status2 | Product defect | Six practice cabinets exceed ordinary map's free authority slots. Isolate six exact practice slots behind practice flag;12 authority/cache/roundtrip/tamper checks, ordinary map unchanged. |
| Blackjack draw perf1 | Product performance defect | Draw loop dispatch/cache cost exceeds unchanged5ms threshold. Cache exact rim endpoints and batch native lines;157 geometry assertions and no-input liveness pass. |
| Crew perf1 | Stale harness | Renamed/cloned room retained obsolete seal. Use real finalized travel; same payload and16ms/512-key/size budgets. |
| Native perf6 | Stale harness setup | E clone lacked current backend. Build unchanged native source with existing toolchain/caps;160 sequences/300 timings/frame/draw checks now execute. Deferred retention measurement remains separate. |
| Run/Daily replacement UI | Stale harness | b0cb51df requires visible saved-run replacement confirmation. Press actual confirmation control; preserve seeds and challenge assertions. |
| Sal/M1.6 padded collisions | Stale expectation | Authored72×48 slots replace legacy padding; retain exhaustive actual exclusivity, strict authority and coincident negative; existing scenario-overlap policy unchanged. |
| Back Alley Jammer/Magnet159px² collision | Product defect | Live defaultfalse overrides validated fixed geometry, triggering legacy90px expansion. Authenticated join owns marker; explicitfalse regression added. |
| Static Slot/Grand/action/lender fixtures | Stale harness |387013ac live venue cycle injects unbacked events into private synthetic rooms. Declare intended static scope; check library-backed install/finalization, retain all existing interactions. |
| Health Inspector ordering | Stale harness |8107039e requires origin venue. Supply actual origin; keep exact[1,1,1,0,0] stage counts and real route assertions. |
| Inactive delivery travel hashes | Stale expectation | Untouched f00 control and candidate full room/world values identical; accepted venue retirement/hand placements supersede old projection. Refresh only full hash pins; keep all exact scalar and3 replay checks. Historical byte pins not independently reproduced. |
| Crew conversation / appointment | Stale harness/expectation | cd769f1881 obligations/presence/hourly offer and04b35205 appointment windows replace favor-debt/anytime model. Real Crew and separate fixture RNG; retain early no-change rejection, window opening and exact+22/+4 settlement. |
| Dialogue route fixture | Stale harness | bf63e433 lottery service belongs to actual counter; fake Corner Pull Tabs lacks slot. Use real finalized Gas/Nell, retain all dock/route/idempotency checks. |
| Preview focus fixture | Stale harness | Missing library/finalization plus wrong lender footprint. Use authored Crew group and checked static installation; exact no-mutation checks retained. |
| Continue status fixture | Stale harness | Same action fixture has no publication even before save. Fix construction, preserve original Loaded status and saved values. |
| Event/item/service UI fixtures | Stale harness | Raw installed-room dictionary swaps bypass atomic publication and retain wrong registry. Fresh supported fixture construction, checked installation/finalization; all exact economics and UI checks retained. |
| Entry-only terminal delay | Product defect | game_enter acknowledgement incorrectly waits for nonexistent hand result. Require canonical game_action; red77/1→77/0, original paid-hand cases remain. |
| Final Crew lender debt marker | Stale expectation | cd769f1881 replaces favor debt with unchanged70 cash/2 obligations. Assert exact1→71,0→2,debt[] and stronger rejected-transaction equality. |
| Candidate multiline API audit | Stale harness introduced here | Real Canvas inherits draw_multiline; shared test double lacks it. Implement equivalent segment-pair replay; retain API coverage audit. |

Current-scope ledger reconciliation remains1681 errors/0 warnings, identical to
the post-disposition baseline, with zero CLOSE-/AUD061-scoped findings. The
historical runtime inventory contributes1671 errors; unrelated records are
preserved. The earlier all-scope2135 result used a different scope and is not a
regression comparison.

### Candidate loader: stale harness introduced by this run

The canonical loader reaches roulette_social_quote_check's direct inheritance of
check_core_content. Its new authenticated-layout helpers incorrectly rely on two
preloads supplied only by the composed Foundation runner. The loader reports
undeclared EnvironmentPlacementScript/EnvironmentSlotBinderScript and dependent
inference errors. Classification: stale harness introduced by this run. Give the
helpers explicit local preloads so both direct inheritance and composed usage
resolve the same real authority code. Preserve loader coverage and all geometry
checks; no script exclusion will be added. Wait for the current run before edit.

### Strict-suite warning gate: classification pending diagnostics

The full candidate is7 pass/4 fail. UI and performance exit0 internally but the
unchanged Smoke wrapper correctly rejects5 UI warnings and11 performance warnings
(exit127). UI traces all originate at the Pawn immediate-credit fixture's raw
current_environment replacement; performance traces originate at the late-Crew
fixture's migrated-run refresh. Do not suppress or allow-list these warnings.
Inspect the actual detached publication and live manifest join before assigning
the performance classification. Internal assertion success alone is insufficient.

### Pawn warning gate: stale harness (before repair)

All5 UI warning identities originate at _check_run_pawn_credit_is_immediate.
That fixture replaces the installed room with a bare ui_pawn_credit_room
(dictionary with empty layout and no manifest), then opens the real Pawn UI.
Current live venue membership adds estate-lot actions/items; they cannot join a
published room that the fixture never installed. Sealed atomic publication
replaced this raw swap. Use a real generated/finalized Pawn Shop before setting
the existing100-cash/Creased Card credit scenario. Keep exact loan credit,
presented-bankroll release, popup Cash label and main-menu button normalization
assertions. No warning suppression or credit/value change.

The multiline method-coverage failure is cleared. The validator then exposes its
next preserved reviewed-binding assertion: _environment_result_feedback_view's
legacy-unit condition still pins the old game-specific shell spelling. This is
the neutral virtual-method refactor already classified above, with179+52 exact
feedback checks; the semantic condition is unchanged. Classification: stale
expectation introduced by this run. Update only that exact reviewed binding to
the equivalent neutral call; retain uniqueness/count and hostile-source checks.

The same source audit also pins the relocated round-net, observation, penalty,
recorded-feedback and tutorial-receipt fragments. Each obsolete exact snippet is
replaced one-for-one with its corresponding neutral wrapper/call, including the
same unique-function and unique-snippet requirement. No reviewed binding is
removed, no new content exemption is added and the security allow-list is unchanged.

The hostile classifier's5 feedback fixtures also embed the old literal-bearing
fragments. Preserve all33 executed hostile mutations and exactly29 production
bindings. Bind each fixture to its equivalent neutral snippet; duplicate/moved
cases must leave that exact snippet visible, content-identity attacks inject an
explicit motel game argument, and predicate attacks flip each real current
null/capability gate. Additional Blackjack literals, duplicate owners, multiline
ambiguity and outside-function content still must remain unclassified. Assert
that every mutation actually changes its source. This retains the original
security intent after module-owned feedback replaces shell game-id selection.

The first neutral hostile replay catches that ambiguity probes relied on the old
function body itself containing a Blackjack literal. Explicitly carry that same
hostile content payload in the ambiguous source; retain both ambiguity rejection
and visible unclassified literal. All33 cases still execute; no condition removed.

The content classifier now passes: exactly29 production bindings, full current
catalog scan, eight existing hostile classes and all33 feedback hostile mutations.
The current complete Smoke's UI and perf internal passes remain recorded as
suite failures until their5/11 warnings are removed at the fixture source.

### Late-Crew warning gate: stale harness (before repair)

Detached snapshots prove valid20-row manifest and successful base join (16 live
objects) with correct room geometry before/after host refresh. The finalized
scenario projection, however, marks EVERY record overflow; the final attachment
then correctly warns for11 actions with no room host. The fixture rebuilds the
restored scenario through scenario_finalize_installed_environment(library) with
an empty layout context, omitting the1280×720 viewport supplied by the real UI
and HarnessProductionFidelity. Unknown viewport deliberately projects overflow.
Use the existing full finalize_arrival boundary for the restored run as well,
with its explicit viewport context and checked success. Retain real Delta room,
large ticket payload, actual lender interaction, strict warning gate and every
unchanged performance/size/liveness budget. No projection rule is relaxed.

**Correction before any performance edit:** the additional boundary snapshots
rule out the viewport hypothesis above. project_finalized_sequence_interaction_result
and restore_live_presentation_fields both retain room mode. The later
_reconcile_unsealed_record_slots rejects a record as Composed room record has no
authored slot, converting the combined room to overflow. Initial base join and
sealed authority both validate. Performance classification returns to PENDING
until the exact offending identity is isolated; no context repair was applied.

### Confirmed late-Crew root cause: PRODUCT DEFECT (before repair)

The exact offending newcomer is travel:leave. All15 restored physical records use
authored slots present in the36-slot map. The authoritative20-row manifest has no
exit row because this world's current Delta room has no currently offered target
(next_archetypes/travel_hooks empty). The live view nevertheless invents a Leave
door from3 inspectable locked map routes. Legacy BASE_ALWAYS_PHYSICAL_OBJECT_IDS
then treats the unsealed empty-slot door as physical, and strict composition
correctly rejects the entire room. This is not damaged saved geometry or a reason
to loosen validation.

Preserve the valid room and emit a tangible generic Leave door only when its
committed manifest owns one. The existing global map control continues to inspect
locked routes. Keep legacy pre-manifest construction behavior, all sealed exit
behavior, generic slot rejection and damaged-room guards. Add a red real-host
regression for the exact no-exit Delta publication plus a normal Corner exit/map
positive case before editing the producer. No manifest, content, save-schema or
route/lock/value changes are required.

The real-host exit regression reproduces the product defect before the edit:
10 executed checks/1 failure (valid Delta table disappears; the rejected catalog
is empty, so its per-record checks cannot run). After the producer-only repair:
50 checks/0 failures,20 returned room records, normal global map inspection and
full serialized-run equality, plus an ordinary sealed Corner exit all pass.
No warnings are emitted by the repaired regression. Generic composition and
publication rejection remain unchanged. The viewport hypothesis was not applied.

The post-exit complete performance probe passes46 observations with all11 game
surfaces,10 resolve paths and8 additional modes, unchanged budgets, no report
warnings and no WARNING:/ERROR: markers in the captured output. The Pawn credit
focused check is true with no warnings. Animation liveness passes after the
latest room-controller edit. The canonical11-stage strict suite is rerunning.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index enumerates every raw evidence file, absolute path, byte size and SHA-256 for446 preceding CLOSE-01 run directories, including failed experiments and diagnostics. The final complete-suite run will be indexed separately after completion.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\close061-assemble-pre-final-proof-evidence-index-20261111\evidence\raw-evidence-index.json | 39ac955f10b1d15ca908ab7a945dda81bc6789c9a0e439f9de2a4d8aaba781dc |
| E:\CodexQA\BTH\runs\close061-before-smoke-20261111\evidence\smoke\summary.json | addec527e1437ea1fcaf7fcbe1c57b4facac7f01805709dd8a31531621e6f90f |
| E:\CodexQA\BTH\runs\close061-canonical-smoke-after-repairs-20261111\evidence\smoke\summary.json | b345fc846d168beb16c2d2a11f56b5a333e7803b3ca24cff3a38c11e86c5cfe6 |
| E:\CodexQA\BTH\runs\close061-neutral-binding-hostile-contract-final-20261111\evidence\worker.log | ca96962d2cf474861cdf2984d76f5f531fde59a710461457a6f1e5aae8cedf4e |
| E:\CodexQA\BTH\runs\close061-unsealed-exit-regression-before-20261111\evidence\worker.log | 51fe3d6c9f269fc9340ef12eb2683a26b32b9edf8d36aa78923ed96ca52e68f5 |
| E:\CodexQA\BTH\runs\close061-unsealed-exit-regression-after-20261111\evidence\worker.log | 4fe4d9ae1445f741ef556362d76637c8a9325911bfad28cde8d88a9ca450d584 |
| E:\CodexQA\BTH\runs\native-private-close061-module-and-ending-compatibility-20261111\evidence\results.json | e9a2a4aa0d80a5e406c7e1fceffcb79db53b70dbd996f9e7e3a5d1d07edd323f |

| E:\CodexQA\BTH\runs\close061-perf-candidate-run-after-authorized-exit-20261111\appdata\Godot\app_userdata\Beat the House\foundation_performance_probe_report.json | 576709471ac4c7762d4f99c4c258512ae48b0bcdc6625151a3509362d385184c |
| E:\CodexQA\BTH\runs\close061-assemble-pre-final-proof-evidence-index-20261111\evidence\post-exit-perf-report.json | 576709471ac4c7762d4f99c4c258512ae48b0bcdc6625151a3509362d385184c |

Post-exit performance details: Blackjack animated-idle draw avg2.836ms/p953.257ms
against unchanged5ms gate. Real visible-room Crew select8.031ms/open14.929ms
against unchanged16ms each; queued context145 characters against512. No-input
animation liveness passes after the controller edit. These are measured results,
not revised budgets. Native active Coin Pusher release frame p956.916ms against22,
draw p952.522ms against7; all original native stress/sequence checks execute.

### Final rerun validator: QA path-length failure (before any action)

Loader now passes831 files/0 failures. Validator clears the repaired source
binding/API checks but its unchanged exact-seed launcher hostile self-test fails
while deleting evidence-post-move-replacement.owned-original beneath a long
.q009-delete self-test temporary name. It correctly preserves changed/ambiguous
cleanup roots and reports the exact error. No Godot/content assertion is involved.
The descriptive QA run ID lengthens the admitted temporary path; inspect exact
path lengths and repeat the same unchanged gate under a shorter E run ID. No
security/long-path settings, launcher/pipeline code, caps or cleanup policy will
be changed; preserved roots remain evidence rather than being forcibly removed.

## Complete strict rerun before QA path shortening

Canonical Smoke exits1:10 pass/1 fail. All10 Godot stages pass, with empty
stderr for UI and performance; the sole failure is the264-character temporary
cleanup path in the unchanged launcher hostile validator. The same command is
rerunning under close061-s01a-20261111 to keep its admitted E temp paths shorter.
No runtime or maintained test source changed between these two runs.

| Stage | Fresh untouched baseline | Strict candidate before shorter QA path |
| --- | --- | --- |
| validate_project | FAIL | FAIL |
| godot_import | PASS | PASS |
| gdscript_load_check | FAIL | PASS |
| foundation_smoke_content | FAIL | PASS |
| foundation_smoke_runtime | FAIL | PASS |
| ui_scene_compile | FAIL | PASS |
| cold_continue_room_projection | FAIL | PASS |
| game_library_launchers | PASS | PASS |
| dave_bus_encounter | PASS | PASS |
| roulette_audio_audit | PASS | PASS |
| foundation_perf_smoke | FAIL | PASS |

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: close061-canonical-smoke-after-strict-warning-repairs-20261111, close061-gdloader-after-local-preloads-20261111, close061-neutral-binding-hostile-contract-final-20261111, close061-unsealed-exit-regression-after-20261111, close061-pawn-credit-after-finalized-arrival-20261111, close061-liveness-after-authorized-room-exit-20261111.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\close061-record-ten-stage-strict-result-20261111\evidence\raw-evidence-index.json | 392575ce891cde8b2e10b82299facf77d94b7e4e8a84f9626fe8fc56e3bf8b41 |
| E:\CodexQA\BTH\runs\close061-canonical-smoke-after-strict-warning-repairs-20261111\evidence\smoke\summary.json | 3a5a15307573d3f8d4755d96b456757949c68cd563f603f704c4385442ae9e19 |
| E:\CodexQA\BTH\runs\close061-canonical-smoke-after-strict-warning-repairs-20261111\evidence\smoke\validate_project.stderr.txt | 8a708cb819349a43e4546e08c0c7d330532b40f7920128daba34b0c7e6ca7a5e |
| E:\CodexQA\BTH\runs\close061-canonical-smoke-after-strict-warning-repairs-20261111\evidence\smoke\gdscript_load_check.json | ba909d056e93a7e16411e62f5df0b0474b47aa017088fc95cb10872405bdb3e2 |
| E:\CodexQA\BTH\runs\close061-gdloader-after-local-preloads-20261111\evidence\gdscript_load_check.json | ca1e175e6d51ef3004fa16327ab0af828c6a83c636ed140cb0e59d97f949f0d3 |
| E:\CodexQA\BTH\runs\close061-unsealed-exit-regression-after-20261111\evidence\worker.log | 4fe4d9ae1445f741ef556362d76637c8a9325911bfad28cde8d88a9ca450d584 |

## Final local CLOSE-01 result

Command: tools/check_godot.ps1 -Suite Smoke -RequireGodot -KeepGoing -VerboseStages,
with an explicit admitted E report directory and unchanged existing Job limits.
Final run close061-s01a-20261111: **exit0,11 pass/0 fail**, no timeout,
cleanup_errors=[], active_at_release=0. Source and maintained checks are identical
to the preceding10/11 run; only the QA run-directory name is shorter.

```text
validate_project PASS
 godot_import PASS
 gdscript_load_check PASS
 foundation_smoke_content PASS
 foundation_smoke_runtime PASS
 ui_scene_compile PASS
 cold_continue_room_projection PASS
 game_library_launchers PASS
 dave_bus_encounter PASS
 roulette_audio_audit PASS
 foundation_perf_smoke PASS
Beat the House Godot checks passed. Suite=Smoke
```

Baseline was4 pass/7 fail across the same11 stages. Loader coverage grows826→831
scripts (two original parse failures→zero), with its original exclusions unchanged.
Content and runtime retain their original1+6 selected groups; all original25
content/16 runtime errors clear. The complete UI sequence now has empty stderr.
Cold Continue retains9 restored objects and all four damaged-authority rejection
assertions. Eleven launcher games and46 performance observations remain covered.
Additional regressions: Slot practice12 checks; chip geometry157; terminal
presentation73 original+4 new=77 checks (new regression red77/1→77/0);
unauthorized exit red10/1→50/0 as its formerly empty room becomes inspectable.
Blackjack feedback179+52, tutorial15 and no-input liveness pass as recorded above.
Exactly29 reviewed content bindings and all33 hostile feedback mutations remain
required. No failed check was deleted, skipped, loosened or warning-filtered.

Two final classifications supplement the table: the5 Pawn warnings were a stale
raw-room fixture repaired through real arrival finalization; the11 late-Crew
warnings exposed the real unauthorized Leave-door defect, fixed in the producer
with sealed authority/rejection unchanged. The264-character QA temp cleanup
failure is a stale harness path choice, cleared by a shorter admitted E run ID;
validator/launcher/security/caps/reserve/cleanup code is unchanged.

NEXT delivery is pending the code+ledger push. This local gate is not represented
as a deployed result; exact served identity/assets and rendered checks follow.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: close061-s01a-20261111, close061-perf-candidate-run-after-authorized-exit-20261111, close061-liveness-after-authorized-room-exit-20261111.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\close061-finalize-s01-proof-20261111\evidence\raw-evidence-index.json | f50244cb85f362286e41a420c6ee51f9feaba98f0d2f1c3c8e87e87a10774580 |
| E:\CodexQA\BTH\runs\close061-s01a-20261111\evidence\smoke\summary.json | 2e685e6b0b79c5ed262946ac472c8b6accce11d85a197184a3a2e90d6e26c14a |
| E:\CodexQA\BTH\runs\close061-s01a-20261111\evidence\smoke\gdscript_load_check.json | ba909d056e93a7e16411e62f5df0b0474b47aa017088fc95cb10872405bdb3e2 |
| E:\CodexQA\BTH\runs\close061-s01a-20261111\evidence\smoke\foundation_smoke_content.json | ed899e5ef650ead813cd6afbe19c87dbded4cbf5cb273c1d3b220a50a4f83784 |
| E:\CodexQA\BTH\runs\close061-s01a-20261111\evidence\smoke\foundation_smoke_runtime.json | 42081d28ebca51687a6a6ed703dec98a3e004bf4aa130c5c4689b662777b570f |
| E:\CodexQA\BTH\runs\close061-liveness-after-authorized-room-exit-20261111\evidence\worker.log | e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b |

## NEXT guarded-input classification and scoped follow-up

Code4fe2c509 and ledgerb7da568e were pushed after pull/rebase. Existing watcher
observed b7da568e but retained f00a686f, refusing before export: Asset/importer/
settings inputs changed; cold-import qualification required. Exact unchanged
pipeline classification identifies THREE guarded paths: .gitattributes plus the
two owner-approved C5 JSON text files. The earlier chat attribution to attributes
alone was incomplete; the exact three-file comparison corrects it.

The attribute entry is unnecessary: the generator already emits canonical LF and
its output's Git blob is unchanged. Revert only our added attribute entry, run the
existing generator and its strict byte-for-byte --check unchanged, and preserve
the original attribute file exactly. No generator/test relaxation is needed.
The11/11 Smoke and liveness receipts continue to qualify the identical runtime
and maintained checks; this metadata-only follow-up adds a focused strict guide
check. Final candidate exact-commit full qualification remains CLOSE-05.

The remaining two guarded paths are precisely the authorized eight-word lender
and event lines. scripts/bth_e_ephemeral.py already supports a one-shot
bth.cold_import_request/v1 binding the exact target commit/tree, last-good commit,
before/after input hashes and changed paths. Its existing watcher consumes this
request and performs the normal cache-free import under unchanged containment
and artifact/pin checks. Prepare that exact request as a normal delivery input;
no pipeline code, classification allow-list, pin, cap, reserve, template, security
setting or audience is changed. This is not the historical allocation failure:
no export was attempted, so the owner-closed C3 finding is not reopened.

Focused follow-up: unchanged generator and --check both exit0,20 base+55 scenario=75 contexts/607 exact slots. Original .gitattributes Git blob4f46cb324f1b6089df1a566791710361a91e4381 is restored exactly; generated guide blob0753df036a963f0bba648fc91e5a888cbcc75988 remains unchanged.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: close061-s01-preserve-guard-and-remove-extra-input, close061-s01-regenerate-guide, close061-s01-strict-guide-check, close061-s01-confirm-exact-guarded-inputs.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\close061-s01-commit-original-input-preservation\evidence\raw-evidence-index.json | ca3027a19aa73b4f32d2bc709d89b6bcb2f2f1d944b63ae39d4cbea6b0085729 |
| E:\CodexQA\BTH\runs\close061-s01-preserve-guard-and-remove-extra-input\evidence\failed-watcher-status.json | 6acc770d8db87708aca33bd9b34e6b1ceb4dd7b5aa53474e93ef0c4651b89ec2 |
| E:\CodexQA\BTH\runs\close061-s01-strict-guide-check\evidence\worker.log | ecb2ead4cb3437c61c7775bdb44aec94ee551eca3b08fffde8f083a8805e2a60 |

## Storage launch stopped before request submission

The prepared exact request targets973f0ba2ae5fbf50f38cac3346a433c13a1e5c2c/tree
f08f58cd96a2a39190f397d9044dece08ca20d5d, with only data/debt/lenders.json and
data/events/events.json changed among guarded inputs. The original attributes
and all pipeline code/settings/pins/limits are unchanged.

The attempted guarded administrative worker stops in plan_layout, before any
new directory, child or site write: root_escape: D:\Projects\site: workspace
must be strictly below approved root E:\CodexQA\BTH. This is a storage validation
failure, not an automatic approval-review rejection. No alternate root or
security change is attempted. The owner has been asked for an explicit exception
for only the exact existing NEXT control file, or owner submission of the prepared
request. The payload and its full input comparison remain on E. NEXT stays f00.
Independent code/test work continues; no delivery success is claimed.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: close061-s01-prepare-exact-cold-request, close061-s02-register-rendered-regression.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\close061-s02-commit-local-scope\evidence\raw-evidence-index.json | 49bdb067f0ed519da9458222ee52ce926b5ff001914e1a4faf2dcb51a709561c |
| E:\CodexQA\BTH\runs\close061-s01-prepare-exact-cold-request\evidence\qualification-request.json | ae586957174c7e06af02784b032b62bdbd4c073981be5bc49197ba37740f8643 |
| E:\CodexQA\BTH\runs\close061-s01-prepare-exact-cold-request\evidence\exact-input-comparison.json | 5d2ec09d4c6c3c4febc5738de6d9750d2a3c0ff3e07572ec6f2109d4a0b2ff17 |
| E:\CodexQA\BTH\runs\close061-s02-register-rendered-regression\evidence\storage-launch-stop.json | a48df3a90cfec620ae648d633a66f16734c5bd37313ecf63ebbbd5dd484f77ca |

## Owner submission handoff checkpoint

The owner answered "I'll submit the prepared request". The agent has not written
the D site control file or retried a storage-rule exception. At the current
checkpoint the exact973f0ba2 request destination is absent and existing NEXT
still servesf00a686f. The target remote remains973f0ba2 so its one-shot request
will continue to match exactly. CLOSE-02/03/04 code and separate ledger commits
are local only, not pushed over that target. Those local focused checks pass;
they do not close NEXT delivery. CLOSE-06 and final CLOSE-05 remain unrun.
Resume existing-pipeline observation once the owner places the prepared file.

The final checkpoint raw observation/request hashes and reconciliation index are in docs/testing/CLOSE-04_one_release_version_2026-11-11.md. Current-group reconciliation remains1681 versus1681, with zero CLOSE-/AUD061 findings; unrelated runtime records remain untouched.
