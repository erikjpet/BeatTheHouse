# Video Poker hint integration, 10 November 2026

Candidate `18a99d5e` integrated without conflict as `b64344b5` over clean main `ec289687`, preserving both existing documentation commits. Only the reviewed Video Poker source, focused tests and evidence were added.

Fresh integration checks pass: 82,180 numeric payouts, 1,083 legacy payouts, 96 exact mask EVs; incremental lifecycle/cache/cancellation/read-only checks; required no-pointer animation liveness. All three guarded E-drive Jobs exited 0 with zero owned processes. The candidate maintained Video Poker suite and rendered functional Web receipts remain separately identified historical evidence.

Exact main/NEXT `e410e05c6919e7cf7599552f67946f4e53974cd2`, tree `093f0125adaa380eaeb3f9b80013bbd6ac2339b0`, deployed at `2026-11-10T19:00:56Z`. Localhost and LAN metadata, redirect, BUILD/manifest/REF/VERSION, served PCK/native hashes, pinned engine receipts and fresh rendered basic-menu startup pass. Reviewed pixels show `0.6.0-dev+e410e05c6919`; no page/console/request errors. This is basic launch, not NEXT gameplay/timing acceptance. Full timing qualification remains Open: standalone Web steps reached 188-344 ms, and the final timing-instrumented rendered retry timed out before fixture readiness. No 50 ms guarantee, aggregate suite pass or whole-game completion is claimed.

Subsequent [rendered timing follow-up](video_poker_hint_timing_followup_20261110.md) qualifies the unchanged 50 ms strategy-slice gate on three source-matched rendered cold Deals at 3.010-3.045 ms under a 12% aggregate CPU cap. This uses a timing-instrumented test export, not the unchanged deployed PCK. Exact deployed ordinary gameplay/performance, historical minimal-harness outlier attribution and the whole-game parent remain Open. The earlier failures above remain historical evidence.

See the matching JSON for integration source identity, guarded Job receipts and retained limits.

The first watcher attempt failed before build-process creation because the two new test scenes required cold-import qualification. The exact-source request passed the maintained contract and the existing watcher succeeded on its normal 15-minute retry. First Node verification stopped at LAN CA validation before browser launch; using the existing public site CA for that process retained full TLS verification and passed. No watcher reset, manual builder, TLS bypass or OS/browser trust change was used. Both failures remain in the delivery receipt.

Only primary local/remote main remains. Two temporary refs were removed after a verified recoverable bundle roundtrip; their original detached clean worktrees and every file remain. Historical-clone cleanup remains blocked by Git ownership protection, with no trust bypass. See [delivery receipt](video_poker_hint_delivery_20261110.json).
