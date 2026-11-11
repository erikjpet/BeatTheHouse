# AUD061-15 — Wrong-sized install-key repair (item 2 only)

Started from main 26f326ef64f7e8e63f69a9e29efb1270692a6b5a; accepted preceding NEXT facf757e9520800f4212266e42b4dedc6f3ad32b. Specification: [unchanged audit report](../todo/BTH_0.6.1_audit_work_orders.md#aud061-15--the-crew-private-capsule-is-bound-to-a-per-install-key-saves-are-not-portable). Owner-approved scope is item 2 only. No portability, message, override, format, derivation, padding, migration or old-save fixture work.

## Before and after

Same command, fresh guarded E profile each time:
`Godot_v4.6-stable_win64_console.exe --headless --path . --script res://scripts/tests/aud061_wrong_sized_install_key_check.gd`

The check refuses to write unless the actual unchanged user:// key path is inside BTH_QA_RUN_DIR on E:/CodexQA/BTH. It uses current-format empty Crew payloads, never prints key/capsule bytes, and tests sizes 0,1,31,33,64. Actual before output:
```
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

{"checks":45,"failure_count":35,"failures":["pack succeeds after size 0","replacement is 32 bytes for size 0","damaged bytes retained for size 0","round-trip after size 0","cold-cache round-trip size 0","subsequent save succeeds size 0","save recovers after rejected old-key capsule size 0","pack succeeds after size 1","replacement is 32 bytes for size 1","damaged bytes retained for size 1","round-trip after size 1","cold-cache round-trip size 1","subsequent save succeeds size 1","save recovers after rejected old-key capsule size 1","pack succeeds after size 31","replacement is 32 bytes for size 31","damaged bytes retained for size 31","round-trip after size 31","cold-cache round-trip size 31","subsequent save succeeds size 31","save recovers after rejected old-key capsule size 31","pack succeeds after size 33","replacement is 32 bytes for size 33","damaged bytes retained for size 33","round-trip after size 33","cold-cache round-trip size 33","subsequent save succeeds size 33","save recovers after rejected old-key capsule size 33","pack succeeds after size 64","replacement is 32 bytes for size 64","damaged bytes retained for size 64","round-trip after size 64","cold-cache round-trip size 64","subsequent save succeeds size 64","save recovers after rejected old-key capsule size 64"],"key_path_admitted":true}

```
45 checks / 35 failures. Repeated pack fails indefinitely with each damaged size.

Change: scripts/core/crew_turn_model.gd now renames an existing wrong-sized key to a unique `.corrupt.<pid>.<ticks>` sibling before generating a new 32-byte key. Rename failure returns empty without deleting damaged bytes. Existing valid-key fast path, temporary-write/flush/install path, and another-process-won valid-key read remain. The original key path and capsule construction/authentication are unchanged.

Actual after:
```
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

{"checks":45,"failure_count":0,"failures":[],"key_path_admitted":true}

```
45 checks / 0 failures: damaged bytes retained aside; fresh pack/unpack and cold-cache unpack succeed; subsequent pack/unpack succeeds; valid key bytes unchanged; after key damage the prior capsule still fails authentication as before, while the next new save succeeds. This does not claim a changed heist fallback/message, cross-version compatibility, concurrent repair stress or forced filesystem rename-failure execution.

## Broader checks

Required Smoke: `powershell.exe -NoProfile -File tools/check_godot.ps1 -Suite Smoke -RequireGodot -KeepGoing -ReportDir <guarded-evidence>/smoke -VerboseStages`. Full stage comparison and exact observed errors: [smoke_comparison.json](evidence/AUD061-15_20261111/smoke_comparison.json). Observed after: 4 pass / 7 fail, content25/runtime16 exactly unchanged; nine inherited performance failures versus ten at baseline; normalized new stderr errors []. Ledger: 1683 inherited errors across 52 old tasks, zero AUD061/QOL findings. Initial baseline: 4 pass / 7 fail, content25/runtime16, ten performance failures. No scheduling, pause or rendering change; this narrow key repair does not require a new animation check.

All manifests, launch gates and raw outputs are retained in evidence/AUD061-15_20261111. Runs use unchanged 12% CPU / 2 GiB Job limits, E-only private profiles and storage budget/reserve; no active/old profile was moved.

## NEXT

Verified NEXT 3b36a9c3957fe4b4484d8584d16e971fc743ef93 containing code 5676a6102b7b9d7a90a59f4d74c4285b3c4e2ccc; tree bf5dd2b94e52df79195369cb880c8b6dab5aafbf; archive b0eb655ae9db4cea2698547d3cb7be0916c24ff89ffee995571e919fd276d00e. Existing watcher phase current/error null. Ten served asset checks PASS, including metadata/REF/HTML/JS/PCK/native hashes and engine HEAD length/MIME/pins. Fresh-profile unmodified browser startup visually clean; footer 0.6.0-dev+3b36a9c3957f. Daily Challenge enters House with bankroll68 and creates primary100302bytes, SHA256 b1ac8d466dc0e355b04bfda454f67a4a797a95a1de61858964655714c1c2a8a4; no tmp/rollback residue. Screenshots00startup/01Daily/02House inspected (02 name says Menu but shows House). Pageerrors0/console0/job0/no timeout/active0. Key-repair fault matrix was native, not injected into the served browser. No manual publish.
