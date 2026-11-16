# CJ2 failed-case read-only inspection

`CREW-CJ2-FAILED-INSPECTION-20261116`; parent `BTH-QA-CREW-ENDING-001`; sidebar `6afa5073-0cb4-8191-82b0-326a14a3e029`. Source9bf0d6c291ae44817b345a2893ad6e72cd847243, exact productc9ada2a2cf6a42dd4fa6d6fc3cb15d59628582320f52fffcc6e55bd9053a299b. Delivered Continue/cleanup fixes046754f0 remain separate from original persistence and browser acceptance.

The new `tools/crew_cj2_failed_inspection.py` + `.gd` capability has only qualification and read-only inspect modes. It never constructs Main or RunState, loads/Continues a run, saves, creates a key, writes original custody or admits gameplay. Normal native admission still requires CLEAN_CLOSED and its three historical exact product builds. Existing browser recovery policies remain untouched.

Before original save reads,18 synthetic guard tests and29 in-memory codec checks passed. Real Windows GENERIC_READ handles allowed reads and denied write/delete/rename, with normal/exception/partial-entry cleanup tested. The inspector uses supported numeric JSON and SaveService/RunSaveCodec in-memory payload decoding, with explicit slot, hash and size bounds. Its output contains only selected public state and hashed receipt identities. Private companion contents are hashed in memory for preservation but never decoded or emitted by this capability.

The actual read-only Job used fresh admitted E: write directories while holding the existing native CJ2 mutex and non-write-sharing handles over all input files. Both storage launch gates,12%CPU/2GiB, assignment before resume and zero-process closure were retained. Frozen111 original QA receipts and the archived clean chain were authenticated before inspection. All six original profile trees and every frozen receipt remained byte-for-byte unchanged; custody SHA256 `ec2e39f4134387538007b42467c1908ea5e462a57be87f1d32e48f3e41a1e00d` still denotes CASE_FAILED at crew-native-cj2-handoff-fixed1-261116. No save/profile copy, fallback, replay, reward, reset or post-failure Save occurred.

## Stored generations

| Field | Primary | Backup |
| --- | --- | --- |
| Cash / standing / obligations |151 /87 /2 |151 /87 /2 |
| Clock / deadline |1230 /1260 |1230 /1260 |
| RNG / action |950800549 /12 |950800549 /12 |
| Room / cargo / job |Back Alley /carried /active |Back Alley /carried /active |
| Stored command /outcome /ack counts |0 /0 /0 |0 /0 /0 |
| Closed delivery checkpoint |absent |absent |
| Envelope/content valid |yes |yes |
| Private authority / Continue accepted |unvalidated /unexercised |unvalidated /unexercised |

Primary SHA256 `38a1db7a230330ca5f1d4bfec2621993b428800880b185985511a4b67eebc637`; backup `06b20e48d8c98b333fa8423ce29f67f2806757d4b6070ee11d0f322381bef716`. These are the current files read in place, not restored older copies. The observed in-memory handoff did not appear in either run JSON generation. This does not authorize repeating it, establish private capsule validity or prove absence of independent companion effects. Counts alone do not prove exact receipt correlation. Meta/profile companions remain preserved and were not loaded/migrated.

## Evidence

Command: `python -B tools/crew_cj2_failed_inspection.py --run-id crew-failed-inspect1-261116 --expected-commit 9bf0d6c291ae44817b345a2893ad6e72cd847243 --mode inspect --qualification crew-failed-qual1-261116 --root-confirmed-no-owned-live-job` after qualification in its own fresh runs. Private raw manifests and per-file hashes remain in E: evidence, not this repository.

| Case | Closed Job | Worker log SHA256 |
| --- | --- | --- |
| crew-failed-qual1-261116-guard |42840,exit0,active0 |`737b9572a91349f273d1ccc649e9951e5c1e418cae8263a55893171b169ee0a7` |
| crew-failed-qual1-261116-codec |42808,exit0,active0 |`3d9509241f556ca206f9e1d56c721dede7e77fc39c73456d45877dfdc7d6791a` |
| crew-failed-inspect1-261116 |37072,exit0,active0 |`1bdb8cb4ec9a581f2c6a675d3a2a68d5ae08697d109135910cd4933decce3232` |

Exact qualification/inspection/preservation receipts: `E:/CodexQA/BTH/runs/crew-failed-qual1-261116/evidence/qualification.json` and `E:\CodexQA\BTH\runs\crew-failed-inspect1-261116\evidence`. Source hashes bind the engine, worker, launcher, tests and common guards.

Technical boundary: the former missing read-only capability is now qualified. Private authority verification and a separate exact-case cold-recovery admission remain unqualified. The existing forward guard correctly rejects CASE_FAILED; no reset or exception was added. `Keep original CJ2 CASE_FAILED and never replay its observed handoff. Qualify read-only private authority/receipt correlation before any named cold recovery; develop a separate exact-case typed admission only if existing rules permit it, retaining failed predecessor and forbidding handoff/reward replay. No ordinary Continue, Save or gameplay is currently admitted.`

Browser/WASM startup, visible Web gameplay, human pacing and broader Crew-ending acceptance remain open.

Associated inspector commit `94b90392a97f54b6e69adea4279ced4addf7cc8f`.
