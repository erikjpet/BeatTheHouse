# CLOSE-05 — frozen candidate and original Windows/Web packages

Started2026-11-11; final checks/packages/launches completed2026-11-12 UTC.
Specification: docs/todo/BTH_0.6.1_closeout_plan.md, unchanged SHA256
b6f8e907a0af800fec4d64b195d6b69af9eb7af905f41bc5ce241fbf7d7a6d64.
Both ledger views registered CLOSE-05 before execution.

## Candidate and freeze

Source commit **8724a23f6d8979863f4ed024159a0f07a1d4f0ab**.
Source tree **cea7a9402bd32b1f6092d1d2a1b501bbf9643ac2**.
Clean detached export checkout:
E:\CodexQA\BTH\workspaces\close061-package.

All runtime changes were already rendered on NEXT a6ce512640cbd98019a6b9a4c5b5081278ba78bb.
Only docs changed from a6 to the candidate and after the freeze. Packages and
all final gates below use the frozen 8724 commit, not later proof/ledger HEADs.
No source, test, exporter, pin, cap, reserve, template, audience or security
setting changed during final qualification. Only the two owner-approved data
files differ from the closeout baseline: data/debt/lenders.json and
data/events/events.json, each the specified one-word shortening.

The isolated E checkout has the existing pinned toolchains/templates copied
and hash-checked (30,078 files,2,424,635,736 bytes). No active profile/save was
migrated. Every new run records bth_qa_storage planning/preparation and launch
gates, explicit workspace/profile/temp/evidence/output paths, assignment before
execution,12% CPU / 2 GiB Job containment and cleanup. This package checkout declares
8 GiB expected writes for the real toolchain/build outputs and keeps the20 GiB
reserve; ordinary QA uses the existing4 GiB expected writes. All successful
candidate/export/launch workers end with 0 active children and no cleanup errors.

## Before and after output / counts

Baseline and earlier task detail are retained in CLOSE-01 and the accepted
AUD061 proofs. No historical failure is discarded.

| Check | Baseline / before | Frozen candidate final |
| --- | --- | --- |
| Smoke 11-stage suite |4 passing / 7 failing stages |11 passing/0 failing; summary passed=true, failure_count=0; parent exit0. |
| First candidate Smoke attempt |cl061-rc-smoke:10 passing/1 failing, validate_project only |Same source and unchanged checks rerun cl061-r2:11/11; no timeouts, stderr issues or budget overruns. |
| Loader |826 loaded /2 parse failures |831 loaded /0 failures, original exclusions unchanged. |
| Content/runtime/cold baseline |25 content errors /16 runtime errors /4 damaged sealed-geometry assertions |All clear. Cold publication restores 9 objects and damaged_authority_rejected=true; all four original negatives remain. |
| No-pointer animation liveness |Existing release gate |Animation liveness without pointer input: PASS; exit0. |
| Python tools/tests discovery |180/180 first-run baseline |Ran 180 tests in 24.055s; OK. |
| Additional existing Python tools-root discovery |Not included in180 baseline |Ran 53 tests in 13.267s; OK. No claim of 53 new tests claim. |
| Windows PCK audit |No final candidate package |PCK AUDIT PASS files=1098. |
| Web PCK audit |No final candidate package |PCK AUDIT PASS files=1170; loader verify/apply status verified. |
| Final archive audits |No final candidate archives |Verified archive Windows and Web, exact manifest-bound hashes below. |
| Windows launch |First adapter blocked before child by cwd_mismatch |Actual exported EXE,300 headless frames, exit 0, no SCRIPT ERROR/ERROR. |
| Web launch |No final archive launch |PASS; errors=[], console=[],4 required PCK/WASM requests200; crossOriginIsolated=true. |

Final Smoke commands use the unchanged tools/check_godot.ps1 -Suite Smoke,
the existing 1.5 suite-time multiplier and existing per-stage budgets. No check
was loosened/deleted/skipped to obtain this result. Final liveness uses:
godot --headless --path <clean checkout> --script
res://scripts/tests/animation_liveness_without_pointer_check.gd.
Python commands: python -B -m unittest discover -s tools/tests -p test_*.py -v,
and the same discover command with -s tools.


| Final Smoke stage | Exit | Seconds |
| --- | ---: | ---: |
| validate_project | 0 | 233.995 |
| godot_import | 0 | 11.859 |
| gdscript_load_check | 0 | 46.378 |
| foundation_smoke_content | 0 | 39.999 |
| foundation_smoke_runtime | 0 | 55.407 |
| ui_scene_compile | 0 | 126.426 |
| cold_continue_room_projection | 0 | 16.606 |
| game_library_launchers | 0 | 21.141 |
| dave_bus_encounter | 0 | 23.423 |
| roulette_audio_audit | 0 | 3.807 |
| foundation_perf_smoke | 0 | 56.367 |

Final performance has 46 observations,11 game surfaces,10 resolve paths and 8
additional modes; failures/warnings empty. Mandatory native 160-sequence/300-timing
checks execute. Smoke practice contexts have run_count 0; this does not certify
broad seeded performance or the separately owner-deferred retention measurement.

## Classification before final QA repairs

These were stale harness issues, not product defects. The first candidate full
Smoke run failed only validate_project after all other10 stages passed:

- Local QA checkout core.autocrlf=false made git hash-object read existing CRLF
  bytes differently from the builder-pinned source object. Restoring the original
  true setting restores the exact pinned object. Canonical LF guide bytes have
  the same Git blob; no committed source or builder pin changed.
- PowerShell module analysis wrote an owned Microsoft/Windows/PowerShell cache
  inside this new clean checkout. It was preserved with hash/custody in E
  evidence; the QA controls now explicitly route that cache to the admitted E
  cache path. The unrelated pre-existing Microsoft tree in the main QA workspace
  was not touched. Failed shadow/cleanup evidence is retained.
- The new archive launch adapter initially asked the guard to run from the
  extracted archive directory, which was not its declared workspace. The guard
  rejected cwd_mismatch before starting any game. The pre-change classification
  records this. The adapter now uses the admitted package workspace as actual
  cwd; EXE, server root, browser script, URL and all writable locations remain
  explicit absolute E paths. Gates, resource limits and reserve are unchanged.

Classification evidence precedes each repair; the final launch used a new run.
No production/pipeline change was made for any of these QA setup corrections.

## NEXT result

Existing watcher promoted8724 at 2026-11-12T00:41:33Z, phase current.
Ten exact served identity/asset checks pass. NEXT archive SHA256:
ca29c8d069e3fad44e2efa13f6ad20001f027e0a5b3f74f7dfe7ce0682531ed9.

[Immutable NEXT candidate](http://localhost:8088/p/beat-the-house/play/dev/8724a23f6d8979863f4ed024159a0f07a1d4f0ab/)
was launched in a fresh E browser profile. Inspected menu Version 0.6.0
(8724a23f6d89), then normal Play into the apartment tutorial; no page/console
errors/warnings, owned browser closed. This is startup evidence; detailed
rendered changed-behavior and acceptance cases retain their actual a6/973 build
identities in CLOSE-01/02/03/04/06 proofs.

Existing watcher/pins/caps/audience and stable/itch channels are unchanged.
External mirror handoff was pending and is separate owner work, not claimed
as uploaded. No second watcher/manual NEXT build was used.

## Packages and hashes

| Artifact (absolute path) | Bytes | SHA-256 |
| --- | ---: | --- |
| E:\CodexQA\BTH\workspaces\close061-package\builds\itch\BeatTheHouse-0.6.0-dev+8724a23f6d89-8724a23f6d89-a51a7c919302.manifest.json | 8521 | 74d23b13b68f99b66558a832dcf9ef5a7c373fbc9d8c6303f115b57b47195764 |
| E:\CodexQA\BTH\workspaces\close061-package\builds\itch\BeatTheHouse-0.6.0-dev+8724a23f6d89-web-8724a23f6d89-a51a7c919302.zip | 41582908 | 2afc223c0f8d71437fd1410de0332adeb7f365bfb11ffb3adf91a8c3336393f8 |
| E:\CodexQA\BTH\workspaces\close061-package\builds\itch\BeatTheHouse-0.6.0-dev+8724a23f6d89-windows-8724a23f6d89-a51a7c919302.zip | 85315664 | b744f89523401838be64ea57a575d727f11edc832cc10d0b28c9c4f1f861e2db |

Both archives were created by the unchanged tools/export_itch.ps1 using
-Target windows -NoPackage, then -Target web to package both completed stages.
Candidate manifest: source 8724, tree cea7a9402bd32b1f6092d1d2a1b501bbf9643ac2,
source_dirty=false, build_version 0.6.0-dev+8724a23f6d89. The nonempty dirty-state
digest is the exporter identity digest and does not mean source_dirty=true.
Archive member traversal/size and exact manifest/native-library hashes were
verified before extraction/launch. Original names retained; no tag, rename,
upload or release publication.

Windows: actual extracted EXE --headless --audio-driver Dummy --quit-after300,
fresh E state, exit0, stdout only Godot4.6 identity and no script/engine errors.
This does not claim rendered native gameplay.

Web: unchanged local serve_web_server.py with an owned private port, real fresh
browser, exact manifest fetched over HTTP, native/engine WASM and PCK all200,
cross-origin isolation true. Screens001/002 inspected: menu has correct footer,
normal Play opens the apartment/Pal/X-Ray Glasses. ResultPASS, no page/console
errors or warnings. Server/browser closed; cleanup 0.

Pinned file SHA256 values remain:
project.godot d9eb64e9635c66f230bbe779956f3d8763e8ba701eabca905209a4cdd8fc01b3;
export_presets.cfg ebf93c38034595a9ac7356250fe8378b55674e4cca5fa6015530733fef22fdad;
tools/export_itch.ps1 b1faa1148a6f3079528f58d6f6add4d115b5e0baebf87b06fd929e4c007b54de.
No version bump or re-pinning; RELEASE_VERSION stays 0.6.0, other packaging/
telemetry stamps remain0.6.0 per C1.

## Open acceptance and handoff scope

CLOSE-06 finished its authorized normal-control run:6 game passes,4 narrower
funding/save-barrier qualifications, Crew Poker not reached; Crew offer return
passed, expired Jazz and offered Meta choice not reached. Those are still open,
not passing acceptance. Gas scenery finding
BTH061-CLOSE06-SCENARIO-CONTINUE-001 is reproduced/open and was not fixed inline.
Native retention and six P2 rows stay open/deferred after 0.6.1 by C4.
The owner handoff lists every visible change and scoped open finding.

CLOSE-05 and owner-reduced BTH061-RC-PACKAGING-001 are complete on this evidence.
This means final technical qualification/packages, not full acceptance closure.
The following separate ledger commit records that distinction in both views.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: cl061-candidate-push, cl061-package-clone, cl061-package-tools, cl061-rc-native-debug, cl061-rc-python-root, cl061-rc-python-tools, cl061-rc-smoke, cl061-validator-prechange, cl061-cache-classify-before, cl061-rc-blob-read, cl061-rc-qa-clean, cl061-r2, cl061-rc-perf-receipt, cl061-rc-liveness, cl061-rc-next-identity, cl061-rc-served, cl061-export-windows, cl061-export-web, cl061-launch-windows, cl061-package-launch-classify, cl061-launch-win2, cl061-launch-web, cl061-package-metadata, cl061-final-scope, cl061-final-result-receipt.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\cl061-c05-proof\evidence\raw-evidence-index.json | 7852c35ef048deb1555cbf6bec1e5ff87ac206f6857c3fa4d5f8955931d17ba1 |
| E:\CodexQA\BTH\runs\cl061-rc-smoke\evidence\smoke\summary.json | d341ec1f78f206ca49fb914cd98fbf10bb0edb93402f4fe5c6f4e374b7735acc |
| E:\CodexQA\BTH\runs\cl061-r2\evidence\smoke\summary.json | 996d8b6fe343f42f0ec69e0d032486926b4317d1efa3242bbcde2b517683b748 |
| E:\CodexQA\BTH\runs\cl061-package-metadata\evidence\package-files.json | eb2b9493d91877342a48ef942fca5c789a3eae4af4c9ded73d3613968fa36268 |
| E:\CodexQA\BTH\runs\cl061-package-metadata\evidence\candidate_manifest.json | 9077e33dfbf9f1f8ca0e6209cf9cc3df69cbb16dea30b4f7bb09e1e11b724369 |
| E:\CodexQA\BTH\runs\cl061-launch-win2\evidence\package-windows-result.json | 131113c0ef63247831553781d52e0c34a4a858f7e391d6b360ceb046f88bda26 |
| E:\CodexQA\BTH\runs\cl061-launch-web\evidence\package-web-result.json | 3363d907a66f6fa8fe1a93ee3cbbccf95b4b54442cf5d58b026cc838ddf138ad |
| E:\CodexQA\BTH\runs\cl061-rc-next-identity\evidence\served-assets.json | 33b6955d629999a2e21fad97bffa4d463c5ae015850cfdd9e83cf610cd629a7c |
| E:\CodexQA\BTH\runs\cl061-rc-perf-receipt\evidence\report-custody.json | b2a0dbb741ec256d2027e43456a39992a7b207055a66b2c7cc0300bedd84f1b5 |
| E:\CodexQA\BTH\runs\cl061-package-launch-classify\evidence\prechange-classification.json | f5f049ab239c1eedd885cd4960d9fba413857fb1903f117e1dc3f8573cefeea3 |
| E:\CodexQA\BTH\runs\cl061-final-scope\evidence\scope-receipt.json | b4ed3b229091dff22ff7446a68ececa77d2de128a458eceb12bab20d1e8e4cb0 |

## Final ledger reconciliation

The final ledger reconciliation retains the same1,681 pre-existing unrelated
errors and0 warnings as the fixed-time baseline (1,671 concern the inherited
runtime inventory). There are0 owned CLOSE/AUD061/RC metadata errors. The checker
therefore still exits1 globally; it is not a green repository-wide ledger claim.
Execution is recorded done with findings open; AUD061-EXECUTION and CLOSEOUT-061
remain open parent rows because acceptance/deferred children remain open.
No child dependency or required acceptance was deleted or waived.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: cl061-final-ledger, cl061-ledger-parent-reconcile, cl061-ledger-final2.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\cl061-ledger-proof-final\evidence\raw-evidence-index.json | 51cc4d6c1793e9cb9d4a2e80cc407db74f2e5a9ccf1a55fa2e4774fc7c69a3e8 |
| E:\CodexQA\BTH\runs\cl061-final-ledger\evidence\reconciliation.json | 08a7879a20b09f3c8d924e36e43dbdc295715005e692127ec0c4681e157ba2a2 |
| E:\CodexQA\BTH\runs\cl061-ledger-final2\evidence\reconciliation.json | 3c053287248720b390de62aac2bf7d7eab30f83402e1f5a77e2899c680991e0a |

## Final raw-evidence custody and bookkeeping delivery

Final custody verification found one older owner-disposition proof referring
to a shared index path later reused by CLOSE-01. The old current bytes were
preserved, and the original17-record index was reconstructed with its exact
original committed SHA256. Its proof now points at a unique immutable E copy.
A full verification then checked3,579 unique raw hash references across21
external indexes with0 mismatches (cl061-proof-hashes-all2). This is an evidence
reference repair only; no product/test/package/pipeline changes.

Bookkeeping commit672b7292a73c835f07b1d7c49ff757235b1dd3b6 was also promoted and
verified:10 served identity/assets pass; fresh browser shows its exact footer
and normal Play first tutorial room;2 batches,0 errors/warnings, exit0/cleanup0.
Candidate8724 and its original package hashes remain unchanged. Later custody
documentation continues through the same existing watcher.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: cl061-evidence-index-classify, cl061-index-repair, cl061-proof-hashes-all2, cl061-bookkeeping-next, cl061-final-served.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\cl061-custody-ledger\evidence\raw-evidence-index.json | f8539351ad85b1c67c3b80b43cfc99dc43479bda7af03f57724648d0f6561181 |
| E:\CodexQA\BTH\runs\cl061-evidence-index-classify\evidence\classification-before-repair.json | 1d631dc54232736c6785e0df61bc1cb912317ec719e18f680d56340855e207e1 |
| E:\CodexQA\BTH\runs\cl061-index-repair\evidence\repair-receipt.json | fb3497e2b61550ce85ad932241e52b17d315c2056172880a619ca3c15224a5a9 |
| E:\CodexQA\BTH\runs\cl061-proof-hashes-all2\evidence\all-proof-raw-hashes.json | c49340576d4e2d7a653fafb8bcf8f21826eefacace94ff6bfc59db78026b693e |
| E:\CodexQA\BTH\runs\cl061-bookkeeping-next\evidence\served-assets.json | bfbdba59b1c95fb7e4dde2177a5b16a4332d515d3aa97cd030aa5a5fa5dd9e9d |
| E:\CodexQA\BTH\runs\cl061-final-served\evidence\result.json | ff25ac6656f4a18b7601d85c000d29457301a414067ece2b08657e9904d19d81 |
