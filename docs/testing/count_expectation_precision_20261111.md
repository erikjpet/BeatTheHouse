# Count expectation precision follow-up, 2026-11-11

Task: BTH061-RC-COUNT-EXPECTATION-001 and its existing implementation batch.
Base main: `2113db415ce3639eb546caaaf58d582782e30bc7`.

## Root cause and bounded correction

On unchanged current main, prospective write (20 assertions) and a separate-process read (7) each fail only `official restore preserves full ending/receipts/RNG state`. The full comparison includes layout/map/audio doubles. Its ordinary JSON test reference rounds values such as 0.14883720930232558 to 0.148837209302326, while the official save path preserves the original value. The original frozen-RC evidence remains unchanged in AUD061-17.

Only `scripts/tests/count_heist_money_flow_check.gd` changes executable code. Its expectation now uses FileAccess.store_var/get_var with object serialization/deserialization disabled and a separate .bin filename. Files are explicitly closed. Write/open checks and direct exact readback of the original full snapshot catch a lossy test reference before restore qualification. A negative numeric control confirms exact comparison still rejects the rounded value. `_equal`, snapshot normalization, full ending/receipt/RNG assertions, archived payout, cash/chips and replay checks are unchanged. No production serializer, state, gameplay or payout is edited.

## Focused acceptance

- Bounded import: exit0, temporary single-worker import policy removed afterward.
- Corrected prospective write: 26 assertions, 0 failures.
- Fresh Godot process on the same disposable synthetic profile: 8 assertions, 0 failures, restore_differences=[] in both processes.
- Unchanged synthetic Count/adjacent Whale/report controls: 70 assertions, 0 failures.
- Focused ledger unit tests: 36 tests, OK.
- Documented manual reconciliation with matching owner/runtime snapshots and fixed reference time: 1,682 inherited findings before and after, zero added/removed, zero scoped Count findings. It remains globally failing, not a clean backlog pass.

Actual commands, stage identities, exact outcomes, assignment-before-resume, CPU12%/memory2GiB limits and raw E evidence locations are in [results.json](evidence/count_expectation_precision_20261111/results.json). Test stdout is retained beside it. The local adapter uses tools/bth_qa_storage.py before workspace writes and immediately before each suspended child. All native stages exit, no timeouts, active_at_release=0. Binary expectations and saves remain private under E and are not committed.

This is current-build synthetic/native qualification of this test-oracle defect. It is not replay of a historical heist, a full Smoke pass, full frozen-candidate release acceptance or visual Web gameplay coverage. Existing AUD061-11/AUD061-17 failures and release/version blockers remain open. No portrait-mode work, audit-worker contact, new watcher, builder guard/pin change, stable/itch publication, audience change or profile migration occurred.

## Delivery

Tested source is ready for scoped commit/push through the existing NEXT watcher. Exact commit, served identity and basic startup are pending observation and will be recorded separately; no deployment success is claimed here.
