# Exact deployed Video Poker sample, 11 November 2026

BTH-PERF-20261104-002 remains **Open** for historical outlier attribution. The whole-game performance parent also remains Open. This evidence-only closeout adds normal player-path coverage of the unchanged deployed game, not a new internal advice-slice benchmark or a product optimization.

## Actual deployed ordinary flow

Trusted LAN HTTPS loaded **17ae0cb50b5852c232d68e61784f117b1220f84d**, tree **2e71e62a9e4f704254dc88cfab12e24d9c08baaa**, in a fresh E-drive profile. The existing exact-build startup/PCK/native custody receipt is reused. Browser engine/PCK/native responses were all 200, with no page errors, console errors or failed requests. TLS validation stayed enabled. Production HTML, scripts, engine, PCK, saves and deployment were not changed; no scene override, fixture or game-state hook was used.

Normal Main Menu > Games navigation and the visible practice seed field produced:

- PRACTICE: Neon Jacks, one hand, two completed rounds. A third Deal was abandoned through normal Leave. Early inputs during card/payout transitions are retained and not falsely counted as accepted actions.
- A: Double Deuces, two hands, two completed rounds.
- B: Triple Double Bonus, three hands, two completed rounds.

All six settled rounds showed the selected card HELD, retained that card on Draw, and displayed payout/loss and chip feedback. Both multi-hand cabinets copied holds across their hands. Card-reveal screenshots progressed without more pointer input; settled Triple Double Bonus lighting also changed over a one-second no-input sample. This is six rounds, not exhaustive gameplay/economy or Save/cold Continue qualification. Practice does not autosave. Original profiles and saves were not opened.

## Performance and fair limits

The browser used pinned Chromium 153 / Playwright 1.63, rendered headless at 1280x720, under the maintained **12% aggregate CPU/2GiB** Job. Audio output was disabled to avoid AudioService contention; this does not accept audio quality.

Continuous browser telemetry found **no >=50ms long task in seven bounded Deal windows or the six accepted Hold windows**. Browser Event Timing records initial Deal feedback at40ms. Accepted Hold feedback is32-40ms and Draw feedback48-96ms; observations are recorded individually in the JSON. These are 8ms-quantized dispatch-to-next-paint observations, not the full deliberate card-reveal animation, an exact internal strategy duration or human-PC feel certification. Screenshot capture, tracing and resource throttling can affect results.

Draw windows retain **59-66ms** long tasks. Opening Games/cabinets retains **175-502ms** tasks. The initial saved trace contains two renderer animation callbacks of **66.088/61.836ms wall** with **59.868/59.893ms thread CPU**, inside deployed index.js MainLoop_runner. They represent real engine work in this sample, not merely descheduling, but the trace has no GDScript/advice stack. Do not call every frame or whole-game performance passed.

The record-until-full trace saved only an initial bounded window, not the entire six-minute browser session. Standard long-task/event telemetry continued throughout. The extra external requestAnimationFrame observer stopped recording at 30000 samples; later frame cadence is unavailable, not zero. No sample was discarded and no threshold was raised.

The preserved source-matched rendered **3.010-3.045ms** advice slices still pass the unchanged 50ms gate. Canonical Video Poker Git bytes remain SHA-256 **ac367c3b96ffb068fca63183163b082a0586ef88bdd5b65fc6fb6a01f83bc3c9**, matching that prior test and native parity/lifecycle/liveness evidence. The working checkout uses CRLF. That historical source-matched slice evidence is separate from this unchanged deployed-PCK ordinary-flow sample, which exposes no new internal slice metric.

## Historical outlier disposition

The old standalone **188-344ms** wall-time outliers remain unattributed. Their committed numeric reports are preserved. Named old raw E-drive run directories were absent from the current runs inventory. The new trace cannot retroactively assign them to CPU quota, JIT, GC or advice, and its full-host MainLoop costs do not establish the old standalone cause. Time.get_ticks_usec measures wall elapsed; correlated call-stack/thread-CPU evidence is needed to resolve those historical values.

No speculative product fix is justified by that missing attribution. Preserve this deployed sample and the earlier exact-source tests, retain a concrete historical-attribution follow-up, and investigate repeated Draw/full-host frame and entry costs under the whole-game parent. No original-save or user-input dependency is invented.

## Custody and validation

[Machine-readable receipt](video_poker_deployed_visible_20261111.json), [archived browser runner](video_poker_deployed_visible_20261111.cjs), and [scoped runtime inventory](video_poker_deployed_visible_20261111.runtime.json) retain exact inputs, event timings, limits and hashes. Raw 52-step screenshots/result/commands and 310399477-byte trace are under E:\CodexQA\BTH\runs\vp-deployed-visible-20261111\evidence. Raw profiles and trace are not committed.

The browser Job exited0, did not time out, and drained to zero owned processes. The rejected linked-worktree attempt spawned no worker; an admitted local clone was used instead. An initial desktop transport interruption and the analysis helper's prior-run output-directory limitation are retained in the runtime/report scope, not hidden as gameplay passes. No shared process was terminated, and stable/itch/audience/security settings were unchanged.

Archived browser runner syntax and all 180 tooling unit tests pass. git diff --check passes. Current-scope manual reconciliation ran with the refreshed task owner and scoped runtime inventory: exit1 retains unrelated historical scope/owner/runtime findings, with no finding for BTH-PERF-20261104-002. This is not a clean whole-ledger or game-suite pass. Exact commands and the report remain in the vp-deployed-validation-20261111 evidence directory. No product code changed, so the byte-identical prior gameplay/native liveness checks are retained rather than falsely rerun.

Final seven-Job metadata snapshot: reconciliation checked162 objectives and9 batches, retained47 unrelated/global findings, and reported no finding for the Video Poker task. No clean whole-ledger pass is claimed.
