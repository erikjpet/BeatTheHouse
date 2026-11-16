# CJ2 failed-case private authority and cold recovery

`CREW-CJ2-FAILED-RECOVERY-20261116`; parent `BTH-QA-CREW-ENDING-001`; sidebar `6afa5073-0cb4-8191-82b0-326a14a3e029`. Source94b90392a97f54b6e69adea4279ced4addf7cc8f; exact productc9ada2a2cf6a42dd4fa6d6fc3cb15d59628582320f52fffcc6e55bd9053a299b. Original CJ2 remains CASE_FAILED at crew-native-cj2-handoff-fixed1-261116. Its one observed handoff must never be replayed, although both actual run JSON generations contain the pre-handoff151cash/87standing/twoobligations/clock1230/carried state. Public inspection94b90392 is separately qualified and published; it did not establish private authority.

## Qualified read-only authority verdict

`tools/crew_cj2_private_inspection.py` and its separate `.gd` worker use the exact existing32-byte key under read-only/non-write-sharing handles, current capsule KDF/HMAC/constant-time comparison/AES and production private-payload normalization. They preserve the exact authority-ID text and canonical public binding. Actual inspection never constructs Main/RunState, calls the installer, mutates the private cache, saves, clones a profile or authorizes an action. It emits only strict boolean verdicts, bounded error codes and public correlation booleans; hidden private payload, key/capsule contents, private ledger sizes/entries or classifiers are never emitted.

Before actual key access,25 in-memory wrapper/guard/privacy tests and35 fresh synthetic crypto/correlation assertions passed. Synthetic qualification uses a known isolated cachedkey for direct production pack/unpack parity with empty and nonempty private payloads, then clears it and verifies no install-key file existed before or after. Tampered key/IV/cipher/MAC/publiccontext, malformed authenticated payload, legacy/partial authority, Windows path aliases and malformed/missing owner containers are rejected. It explicitly verifies that private MAC validity does not authenticate cash and never grants replay.

Actual Job32756 returned valid current-format private verdicts for BOTH exact primary and backup using the existing key. Public receipt correlation confirms no stored command/outcome/ack/checkpoint or pending delivery work. This verifies the capsule/binding and existing private payload normalization; it is not an exercise of ordinary Continue, room authority or economic recovery. All10 original profile files and111 frozen QA receipts plus prior inspection receipts remained byte-identical. Original failed custody SHA256 `ec2e39f4134387538007b42467c1908ea5e462a57be87f1d32e48f3e41a1e00d` is unchanged. No key was created, replaced, copied or exposed; no original Save/replay/reset occurred.

| Case | Closed Job | Worker log SHA256 |
| --- | --- | --- |
| crew-failed-qual-private1-261116-guard |25736,exit0,active0 |`36e28e7bf12a15e5474a63f5db1faaaa27ebb8869a984f6aa15ad0b17f1cdf89` |
| crew-failed-qual-private1-261116-codec |18408,exit0,active0 |`86918964b41994321455166a8c2c01ecc84387314c42cbbb5e68f85c5c93064e` |
| crew-failed-inspect-private1-261116 |32756,exit0,active0 |`efbcd675db1814c011ffd7784eb856857cde2ef05335a327fbd76bd3d8330575` |

All workers used admitted fresh E: write storage with4GiB expected writes +20GiB reserve,12%CPU/2GiB, both launch gates, suspended assignment before resume and zero-process closure. Exact engine/worker/launcher/common-guard hashes are in qualification receipts. Raw private preservation metadata stays in E:, not this repository.

Actual private result SHA256 `96068a247663ccffd4bcf0286c76a616d0774536a8642c6a1d00f7325d5514d5`; preservation `c8de7a377dda0345cc76086038434732c2e7c7cf359f1e21b10d3b40bf87eb35`. Receipts: `E:\CodexQA\BTH\runs\crew-failed-inspect-private1-261116\evidence`. Command: `python -B tools/crew_cj2_private_inspection.py --run-id crew-failed-inspect-private1-261116 --expected-commit 94b90392a97f54b6e69adea4279ced4addf7cc8f --mode inspect --qualification crew-failed-qual-private1-261116 --root-confirmed-no-owned-live-job`.

## Remaining boundary

Source review found a technical path for a new exact-case typed cold-inspection binding without weakening default fresh/browser/native admission. It is not installed or qualified yet. A successful private verdict alone admits no Main/Continue or gameplay. Main startup/Continue can migrate settings/meta, write profile coach state, consume pending work, recover rooms and save even while paused; the observer must delegate normal reads/validators and count/block every write attempt, rejecting any nonzero attempt.

Independently qualify the separate typed cold-inspection binding and paused normal Continue-only observer, requiring exact current primary, intact existing authority, zero startup/recovery/coach/Save attempts, no backup fallback, zero new delivery work and unchanged original bytes. Preserve CASE_FAILED and the prohibition on original handoff/reward replay. Ordinary forward play remains unadmitted.

Browser/WASM launch, visible Web play, human pacing and broader Crew-ending acceptance remain open. Prior publishing review rejected the inspector main push by treating an art-specific TEST approval as global. After reading the surrounding art request and existing main/NEXT authorization, the same scoped push was approved once and remote main94b90392 verified. No alternate publication route was used.

Manual checkpoint reconciliation `E:\CodexQA\BTH\runs\crew-private-checkpoint-reconcile1-261116\evidence\reconciliation.json`: zero findings across20 owned Crew rows and all31 listed exact closed native/synthetic/qualification Jobs. The all-project report retains716 unrelated/stale/incomplete-snapshot findings (checker exit1, not a crash). No foreign process or task was changed.
