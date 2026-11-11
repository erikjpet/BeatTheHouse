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
CLOSE04_SOURCE_MENU Version0.6.1 (with a space between Version and0.6.1 in the
actual log). The trial's finally block restored the exact pre-trial bytes.
Restored final run again reports5/0 and actual menu Version0.6.0, no script errors.

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
