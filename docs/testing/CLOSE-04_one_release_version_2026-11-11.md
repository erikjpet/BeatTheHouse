# CLOSE-04 — one displayed release version

Registered before implementation. Owner decision C1 keeps the displayed number
0.6.0 and forbids builder re-pinning or version edits in project.godot,
export_presets.cfg and tools/export_itch.ps1. The menu is to read one constant;
source runs show it alone, valid distribution manifests append source_commit's
first12 characters. Missing-manifest distributions retain their unbound warning.
Internal build_version and telemetry_identity must remain byte-for-byte unchanged.

Before: BuildIdentity has DEVELOPMENT_VERSION, source fallback0.6.0; valid
manifest display reads build_version, so an exported menu exposes the internal
0.6.0-dev+ identity. The UI smoke also couples displayed version to the pinned
project setting. Classification: product display ownership, with a stale UI
expectation that must instead follow RELEASE_VERSION. Record a failing exact
manifest/source probe before editing, then run the maintained packaging/menu
contract. Temporarily change only the constant to0.6.1, check the real source
menu, and restore the original bytes. No game surface or scheduling changes.

## Before and after

The exact manifest/source probe before changes reports5 checks,2 failures:
source with an incidental manifest inherits the internal build identity, and the
distribution footer exposes build_version instead of release version/short SHA.
The unchanged original packaging contract passes, demonstrating its missing
coverage rather than just a previously failing test.

After:5/0, maintained packaging/runtime contract PASS with no script errors.
Its original project stamp, source telemetry, unbound-distribution and mandatory
native-backend guards remain; it now also checks a valid exported identity,
unchanged internal build_version, and a real constructed source menu. The UI
smoke follows RELEASE_VERSION; the separate project stamp check remains0.6.0.

One-line source trial: only RELEASE_VERSION changed0.6.0 ->0.6.1. The same5/0
probe and actual menu contract pass, and the raw output reads
CLOSE04_SOURCE_MENU Version 0.6.1. The trial's finally block restored the exact pre-trial bytes.
Restored final run again reports5/0 and actual menu Version 0.6.0, no script errors.

Protected file SHA-256 values match before/after:
project.godot d9eb64e9635c66f230bbe779956f3d8763e8ba701eabca905209a4cdd8fc01b3;
export_presets.cfg ebf93c38034595a9ac7356250fe8378b55674e4cca5fa6015530733fef22fdad;
tools/export_itch.ps1 b1faa1148a6f3079528f58d6f6add4d115b5e0baebf87b06fd929e4c007b54de.
The complete telemetry_identity implementation and all following distribution/
cache helpers compare byte-for-byte unchanged. No builder pin was edited.

NEXT result: pending exact delivery. The owner is submitting the prior CLOSE-01
cold-import request; this commit will follow that build through the existing
watcher. The required served footer0.6.0 (<actual short commit>) is not claimed yet.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: close061-s04-expectation-read, close061-s04-finalize-format, close061-s04-implement, close061-s04-read-contract, close061-s04-red-prepare, close061-s04-trial-prepare, native-private-close061-s04-after, native-private-close061-s04-before, native-private-close061-s04-final, native-private-close061-s04-trial.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\close061-s04-proof-commit\evidence\raw-evidence-index.json | cc51c38d08fde83c45b9e3954d5df80d82f71cdbfbd8c832b1db8dad3b45fb58 |
| E:\CodexQA\BTH\runs\native-private-close061-s04-after\evidence\results.json | 21b4186d74d35d062c409d27ac6c8c48e99051e3db11eb0fe99bfca36641caa5 |
| E:\CodexQA\BTH\runs\native-private-close061-s04-before\evidence\results.json | ebd18453b5b5693b0ba56ada8eb260c89b0ee925a6af664e1e2a9b03d566a30a |
| E:\CodexQA\BTH\runs\native-private-close061-s04-final\evidence\results.json | bdb059d9528eec2f57b7b0e585e618cc5574dabe0b4a3781e036049a18e29acd |
| E:\CodexQA\BTH\runs\native-private-close061-s04-trial\evidence\results.json | 4956b80c1a610b59fdd5f80e5fbb0599e5f3da6a2dbb8362e0a966e7225ef67d |
| E:\CodexQA\BTH\runs\native-private-close061-s04-trial\evidence\source-trial.json | a695a9ff9302de5a5e61222bdf1388976fb6c6d141d6378e242d70c3a71cf459 |
| E:\CodexQA\BTH\runs\native-private-close061-s04-trial\evidence\source-restored.json | 9c6fb108c1a737a2b8e89260c786056180f87b4125c0c7234527d4030fe36739 |

## Additional UI-wrapper attempt

The optional focused UI wrapper cl061-s04-ui used a360-second outer QA budget.
It completed strict validate_project232.960s, import11.718s and all831 script
loads45.406s, then entered ui_scene_compile before the outer budget expired.
This is an incomplete run, not a UI pass or a product failure. The existing
FoundationSuite UI option still runs those preconditions. The owned Job drained
to zero with no cleanup errors. Final full candidate Smoke remains required.
The direct packaging and actual source-menu checks above are the qualified
CLOSE-04 results; no check or budget inside the maintained suite was changed.

The direct unchanged maintained UI split runner was then invoked with the same
private roots and resource limits: ui_scene/compile_run_menu_and_game_flows.gd,
exit0,120.83s, UI scene compile check passed, no script errors, owned processes0.
This isolates the changed UI expectation without repeating already successful
validation/import/load preconditions. The complete final candidate Smoke remains
required after CLOSE-06; the interrupted wrapper is retained as incomplete.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: cl061-s04-ui, cl061-s04-ui-direct, cl061-checkpoint-prepare.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\cl061-checkpoint-evidence\evidence\raw-evidence-index.json | 88a94a540fa10de165320ad1d924af90526bb3cdbd349530cd205d9155165832 |
| E:\CodexQA\BTH\runs\cl061-s04-ui-direct\evidence\results.json | 8f979482845a19494ef975a971093afc76acd616b6012eb8ca418125918fce0b |
| E:\CodexQA\BTH\runs\cl061-checkpoint-prepare\evidence\handoff-observation.json | a0e8db39cf4750c42e486871110d4d2d53e147b306bab0728f10e8977e952f22 |
| E:\CodexQA\BTH\runs\cl061-checkpoint-prepare\evidence\next-status.json | 7d37ec16b0089d2db45f53980a0793a362ada8fd4db1c323d380581b45913134 |

Checkpoint reconciliation uses the same current-group snapshots and fixed
comparison time as the established baseline:1681 findings, unchanged; zero
CLOSE-/AUD061 findings.1671 are unrelated preserved runtime-inventory findings.
No unrelated runtime, owner or protected resource was changed.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: cl061-checkpoint-reconcile.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\cl061-checkpoint-commit\evidence\raw-evidence-index.json | f4484a9dcd145e4cdfe8fd626d9b039a5c3f70a447ed3d3f73e1cdec9c709998 |
| E:\CodexQA\BTH\runs\cl061-checkpoint-reconcile\evidence\reconciliation.json | e1c22860660ef8777052b722cba068437ec081d8e6046d75361390129559629a |

## Exact NEXT footer — completed

On served a6ce512640cbd98019a6b9a4c5b5081278ba78bb, tree
8846b3457d48daafd2ae37279bade6cd42f3d38e,10 identity/asset checks pass.
Fresh rendered menu visibly reads Version 0.6.0 (a6ce512640cb), recorded in
002-release-footer.png. Browser six normal-control batches then closes with
zero page/console warnings/errors, exit0 and owned processes0. It also carries
the scoped CLOSE-02 rendered financial-line qualification; no campaign-save
coverage is claimed from this practice session.

Together with the earlier one-line0.6.1 source-menu trial/restoration and
byte-identical pinned inputs/internal telemetry, this completes owner decisionC1.
The unchanged project/export-preset/Windows properties/internal build_version
remain0.6.0 as the owner explicitly chose. No builder was re-pinned.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: cl061-a6-next-identity, cl061-s02-s04-web, cl061-s02-s04-web-cmd-1, cl061-s02-s04-web-cmd-2, cl061-s02-s04-web-cmd-3, cl061-s02-s04-web-cmd-4, cl061-s02-s04-web-cmd-5, cl061-s02-s04-web-cmd-6.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\cl061-s04-delivery-proof\evidence\raw-evidence-index.json | 70e22bee83c0156365180a2f6bc1bd5e239e5c9fdf9ef0e67d7b82cb644c578b |
| E:\CodexQA\BTH\runs\cl061-s02-s04-web\evidence\result.json | 6ef7842f897e97bde9bc4ef344f98c9fda455095628f7c58b41223de0393131c |
| E:\CodexQA\BTH\runs\cl061-s02-s04-web\evidence\002-release-footer.png | d0d7e5b2d66fb29d93e560fff5da1cd596013db67388f132d4f5900789ab8c3c |
