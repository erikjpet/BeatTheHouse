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

Corrective commit `1ed18edd616dd14a1e5f32b7fca81a6f13772732` is on remote main and was promoted by the existing watcher at 2026-11-11T15:07:06Z. Its source tree is `d80d8c2daf3e6767638b12478d17e33c6024b487`; version `0.6.0-dev+1ed18edd616d`. The bounded 1,168-file PCK audit passed in its existing build log. Main and NEXT identity were independently rechecked before this bookkeeping closure.

[Served asset receipt](evidence/count_expectation_precision_20261111/delivery_assets.json) retains ten passing HTTP checks with exact pipeline hashes for metadata, HTML, JS, PCK and native module; engine files use pipeline hash/pin equality plus served HEAD identity. The NEXT redirect resolves to the exact immutable commit path, and strict HTTPS metadata matches using the existing trust configuration. Archive SHA-256: `2c9833e405ac68dfc053ede5f2c01684501f4db4d719a7996ea530e632a9a797`.

[Browser startup receipt](evidence/count_expectation_precision_20261111/delivery_startup.json) records one canvas, the correct title, four successful engine/PCK/native downloads, zero page errors and zero console warnings/errors. The retained screenshot was inspected and shows the main menu and exact commit version. This is basic startup, not a new Web heist playthrough. Native write26/cold8/synthetic70 acceptance above is reused for the exact unchanged test script.

Both Count finding records now associate the corrective commit, mark the required scoped acceptance and deployment verified, and close only `BTH061-RC-COUNT-EXPECTATION-001` and its implementation batch. Original frozen-RC failures remain historical evidence; AUD061-11/AUD061-17, version admission, Riverboat fixture, final package qualification and their other open work remain unchanged. Completion bookkeeping is owned by `/root/record_count_completion`; original implementation evidence remains attributed to `/root/fix_count_test_precision`. No original audit worker was contacted or changed.

Closure checkpoint reran the 36 focused ledger unit tests successfully. The documented fixed-time manual reconciliation, using the existing matching owner/runtime snapshots, still reports the identical 1,682 inherited findings and zero direct Count findings. Only these two Count records changed; open work decreased by one objective and one batch. This is a regression comparison of the recorded snapshot, not a fresh global ownership audit.
