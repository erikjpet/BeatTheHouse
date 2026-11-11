# AUD061-08 — Flush run saves at lifecycle boundaries

Started from main **602030abf81154c337f0a47f1253122ac381c9a6** (AUD061-14 delivery receipt, waiting for this finished task push); NEXT71e456a36d079e2aa8c4d8a95d22b325a673973b. Specification: [audit work order](../todo/BTH_0.6.1_audit_work_orders.md#aud061-08--no-save-flush-on-background-tab-hide-or-tab-close).

## Before

Pinned Godot4.6.stable.official.89cea1439; approved E-root fresh profiles, capped12percentCPU/2GiB Job, assignment before resume. Same focused command before/after:
Godot_v4.6-stable_win64_console.exe --headless --path . --script res://scripts/tests/aud061_background_save_flush_check.gd

A prior fixture string-type inference error is retained separately, not counted as reproduction. Actual unchanged production result:
```
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

AUD061_08_LIFECYCLE {"checks":65,"failures":["Queued generation durable synchronously lifecycle_2017","Pending state clears lifecycle_2017","Queued generation durable synchronously lifecycle_1005","Pending state clears lifecycle_1005","Queued generation durable synchronously lifecycle_2015","Pending state clears lifecycle_2015","Focus boundary drains the actual worker","Current generation replaces older in-flight generation","Pause drains actual finite Web job","Current generation follows drained phases","Failed lifecycle save retains pending warning","Later boundary persists held state after physical failure","Successful retry clears pending warning"],"observations":[{"case":"lifecycle_2017","frame_unchanged":true,"marker":"baseline"},{"case":"lifecycle_1005","frame_unchanged":true,"marker":"baseline"},{"case":"lifecycle_2015","frame_unchanged":true,"marker":"baseline"},{"case":"scopes","guards":"actual publication/practice/meta; explicit rejecting GameModule readiness boundary","native_worker":"actual","web_phases":"actual SaveService phases invoked natively; exported callback delivery is separate Web evidence"}]}
```
65checks/13failures. Three lifecycle notifications return without saving queued state or clearing pending. Actual native worker and actual finite Web phase job remain in flight; current newer state is not installed. Actual temporary-path failure does not acquire the expected lifecycle pending warning/retry behavior because no lifecycle save is attempted.

## Change

scripts/ui/foundation_main.gd: application/window focus-out and application-paused call one synchronous flush only when pending or in-flight work exists. It uses existing _autosave_foundation_run(...,true), including live-machine readiness, room-publication, practice and Meta refusal. It also preserves the ordinary autosave owner's existing active-transaction exclusion, avoiding a partial event/Rourke capture. Duplicate/reentrant work is guarded. No new queue or retry cadence.

Retained JavaScript callback is registered on document visibilitychange (only hidden=true) and window pagehide, then unregistered/released on scene exit. Successful Web VFS installation requests engine-owned filesystem sync through WebSaveDurabilityBridge.request_lifecycle_sync; this boundary requests persistence without awaiting or claiming the manual Save acknowledgement. Existing bridge begin/poll flow and engine compatibility checks are unchanged. No new version checks, beforeunload hook, debounce/animation changes, schema migration, item/scenario change, pipeline guard/cap/reserve change.

## After

Expanded77checks include two existing active-transaction guards:
```
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

BTH support: Save waits for the live machine to settle.
BTH support: Room check pending; existing save retained.
AUD061_08_LIFECYCLE {"checks":77,"failures":[],"observations":[{"case":"lifecycle_2017","flush_elapsed_ms":123.825,"frame_unchanged":true,"marker":"lifecycle_2017"},{"case":"lifecycle_1005","flush_elapsed_ms":118.151,"frame_unchanged":true,"marker":"lifecycle_1005"},{"case":"lifecycle_2015","flush_elapsed_ms":117.18,"frame_unchanged":true,"marker":"lifecycle_2015"},{"case":"scopes","guards":"actual publication/practice/meta; explicit rejecting GameModule readiness boundary","native_worker":"actual","web_phases":"actual SaveService phases invoked natively; exported callback delivery is separate Web evidence"}]}
```
Initial identical65checks after:65/0. Final77/0. All3notifications install/load the new marker without advancing a frame. Actual WorkerThreadPool job and actual four SaveService Web phases are drained before current-generation persistence. The Web phases are invoked directly in native QA, not claimed as an exported callback test. Explicit rejecting GameModule is the readiness boundary fixture; room-publication/practice/Meta guards use actual host state. Actual E-run .tmp directory blocks write; previous generation remains, pending+warning persist, removal of only the owned empty directory allows the next focus boundary to save and clear warning. No pending/in-flight work makes no redundant write. No processing/rendering disabled.

Measured three queued flush calls123.825/118.151/117.180ms under the12percentCPU cap, zero frame advancement. This is one ordinary QA run size, not a bound on every possible late-run save. No-pointer animation command res://scripts/tests/animation_liveness_without_pointer_check.gd: **PASS**. Initial Smoke4pass/7fail matches baseline4/7, content25/runtime16 exact inherited assertion sets, normalized new stderr errors[]. Performance9inherited errors versus baseline10. Command: powershell.exe -NoProfile -File tools/check_godot.ps1 -Suite Smoke -RequireGodot -KeepGoing -ReportDir <guarded-evidence>/smoke -VerboseStages. Exit1/no timeout/activeprocesses0. Ledger1683inherited errors across52older tasks, zero new AUD061/QOL findings. Baseline Python180/0. Full raw outputs/storage manifests and launch gates retained in evidence/AUD061-08_20261111/.

## Web capture preparation

Real hidden-state method is now confirmed; candidate verification remains open. Playwright default headless and off-screen full modes report document.hidden=false after minimizing and switching tabs. Installed Playwright1.63.0 primary source coreBundle.js37638 explicitly enables focus emulation. Disabling it from an additional CDP session still did not produce hidden state. All attempts retained, not counted as hidden-tab proof.

Fresh Chrome launched directly in inherited capped Job with explicit E profile/cache/temp/evidence and immediate pre-child launch gate, attached via public connectOverCDP(noDefaults=true), avoids framework focus/media overrides. First attempt had no initial page yet; corrected attempt timed out waiting for startup. Those attempts are retained as probe failures, not game acceptance failures or permission/capacity failures. Those initial adapter failures were resolved by the final probe below. No document.hidden property override, engine state/script injection or security-setting change to the owner system. Subsequent probe preparation preserves the established framework's software WebGL runtime support and background-render flags while leaving focus emulation off; startup status/console/screenshot diagnostics will distinguish unsupported graphics from visibility scheduling.

## NEXT

Pending finished task push and exact deployment/asset/startup/actual lifecycle verification through the existing watcher.


### Real hidden-state method and Web before

Final fresh owned Chrome probe, exact pre-AUD08 NEXT71e456a36d079e2aa8c4d8a95d22b325a673973b: **REAL_HIDDEN_AVAILABLE**. Startup clean, no pageerrors/consolewarnings-errors. Browser uses explicit E profile/cache/temp/evidence, immediate pre-child storage gate and inherited capped Job. Public connectOverCDP(noDefaults=true) leaves focus/media emulation off. Established QA software WebGL/background-render runtime flags allow off-screen startup; minimize and ordinary tab switch both produce actual document.hidden=true/visibility=hidden, then restore to visible. No document property override or owner-system security setting change. Exact browser arguments, guard evidence and adapter source retained.

Timed Web before command: node .tmp/aud08_web.cjs 71e456a36d079e2aa8c4d8a95d22b325a673973b, fresh ordinary Daily profile. UI steps: open actual House Sleep card (368,348), normal Sleep button(913,465), wait40ms then minimize the owned window, reload while hidden, restore, normal Continue(492,405). DOM observation records trusted pointer and actual lifecycle events only; no helper filesystem sync call, game state/scene/path override or profile migration.

Observed hidden event118ms after trusted pointer-up; minimize completion58ms after click acknowledgement. Before/while hidden/after reload primary stays103197bytes and SHA2562cf33c89c3b5318979fe61e79ec354aa9ab9d9a9799bc4ba64cd684111259e78, no .tmp/rollback. Sleep card had Day1 12:30PM; reload/Continue visibly restores old Day1 12:00PM and Run loaded:Old House. This establishes that this input/elapsed state was not persisted. No hidden screenshot was requested between action and reload; there is no separate captured post-Sleep outcome frame before hiding. Native before65/13 independently establishes the queued-state loss. Same normal UI steps will be repeated on the candidate to establish that its actual action survives.

Screens00startup/01Daily/22SleepCard/23ReloadContinue/24RestoredOldClock inspected. Pageerrors0,consolewarnings/errors0,jobexit0/no timeout/activeprocesses0. Before run is reproduction evidence, not candidate acceptance.


### First candidate delivery and observed storage gap

Existing watcher promoted **23326f534823da8c5175f835f958ee55e7f1605e**, containing code30ac66e48f7abe0d5ddfcdc2f8d97a2dbd940c84, tree1462b5783fe0300945dfb02184b011c1b0180850, archive4f62a1e20557319ef95c3defcd370a3b8ff44c48e355ab6a356ccaf91d65fe67. Exact10assetchecksPASS. Established browser startup+ordinary Daily clean, pageerrors0/console0/job0/active0.

Real-visibility adapter initially had two interrupted initial navigations (ERR_ABORTED before game startup, retained). HTTP both old/new directory/index.html responses200/text-html; ordinary startup passed. Waiting for the dedicated tab initial DOM load and800ms startup settlement resolves this adapter race; this delay precedes gameplay and does not affect the timed click/hide interval. All attempts and diagnostics retained.

Actual follow-up Web run aud061-aud08-web-after-observed-20261111: Sleep card Day1 12:30PM. Normal Sleep click then40ms wait/minimize. Actual hidden DOM event205.2ms after trusted pointer-up; host minimize completes72ms after click acknowledgement. **205.2ms exceeds strict200ms, so not accepted as timing pass.** Before primary100742bytes/SHA2560126b077ae9b0487956fb31206207afd888a057333297d3ca3e211a9732afd05. While genuinely hidden, primary changes to100867bytes/SHA256321fdc93c06498b6f234a8aa3577b8d4127c287d98bac28138c67378ef387c8e. After reload it reverts to old100742bytes/0126..., and Continue visibly restores Day1 12:00PM. Thus synchronous VFS flush works, but the frame-dependent public sync request does not complete storage persistence while hidden. Errors0/console0; job1 because timingFailure. Final delivery is **not accepted**.

### Immediate sync follow-up

Exact served pinned-engine index.js inspected: _godot_js_os_fs_sync assigns GodotOS._fs_sync_promise=GodotFS.sync(); GodotFS.sync guards _syncing, calls its existing FS.syncfs(false,...), clears busy and resolves the error. Requesting only a future engine-frame flag can stall once RAF is hidden. New lifecycle bridge request queues a distinct GodotOS._fs_sync_promise immediately after the current one (including recovery from an older rejection), then invokes the same GodotFS.sync. It does not call FS.syncfs directly, create an IndexedDB schema or alter the engine assets. Unsupported request leaves the host pending with its existing warning path. Existing manual begin/poll and engine compatibility checks remain unchanged. No new version checks.

Focused actual adapter-JavaScript check:
node scripts/tests/aud061_web_lifecycle_bridge_check.cjs
Before2checks/1failure: Actual adapter has immediate lifecycle request API. After21checks/0failures, including old-sync sequencing/current generation, old rejection recovery, supported-method refusal, existing manual busy guard, future-promise acknowledgement and actual error propagation. This evaluates the shipping adapter source in a Node VM with controlled engine promises, not real IndexedDB; deployed proof is still required.

Native lifecycle after correction77/0; measured queued calls111.836/111.267/117.853ms, no frame advancement. LivenessPASS again. Final Smoke4pass/7fail matches baseline4/7; exact content25/runtime16 inherited assertions, normalized new errors[], performance9inherited versus baseline10, no timeout/activeprocesses0. Capture helper now can copy only its owned fresh primary bytes to unique E-evidence filenames while hidden/after reload for read-only same-candidate validation; it still makes no filesystem sync request itself. Final timed capture will use a shorter delay and must show real hidden event within200ms, persisted primary through reload, and actual Sleep state after Continue.

 
### Pipeline classification stop and test placement correction

Push33904c0b5f0e887704a6f712c23658b6d2a22b78 stopped before exporter process creation: **Asset/importer/settings inputs changed; cold-import qualification required**. Current NEXT remained23326f534823da8c5175f835f958ee55e7f1605e. Retention attempt has process_started=false/statefailed. Status.build_log and build_finished_at were stale references to the successful233 build; they are not evidence of a new export attempt.

Existing bth_e_ephemeral.classify uses bth_import_cache.inputs: docs/ and tools/ are excluded, non-addon .gd excluded; other files count as importer inputs. Exact Git difference outside those exclusions is one added file:scripts/tests/aud061_web_lifecycle_bridge_check.cjs. This is my Node QA check, not a game asset. Corrected its placement to tools/tests/aud061_web_lifecycle_bridge_check.cjs with identical SHA256, without deleting or weakening the test. Current command: node tools/tests/aud061_web_lifecycle_bridge_check.cjs. Earlier command/output above remains historical evidence for9d7d9c4a.

No pipeline code, guard/pin, cold-qualification request, cap, reserve, security setting, retained evidence or profile changed. Runtime .gd bytes remain those already checked77native/21bridge/liveness/Smoke. The unchanged check is rerun at its correct location, and exact classified Git inputs are compared before the next push.

Relocated Node check21/21 again, SHA256unchanged5b461c75ced25bf6b913af33d8e7098b5172ccffa8ffde145215a872d1808d5a. Exact actual classifier on recorded Git rows: 1420inputs in both baseline23326f53 and candidate d45f5c02, identical SHA2568e97a24171b5692169f247c107e2c7c037b5232f5788f8f0299963241348074c, changed classified paths[]. Classifier source and dependency scope in relocated_import_inputs_comparison.json; normal watcher still performs the actual admission/export after push. No runtime code changed after native77/bridge21/liveness/Smoke verification.


### Guard-admitted deployment, persisted action and overlap finding

The unmodified watcher admits and promotes **eb48bb98364966324813e2b7a1c6516c32ecf86e**, tree0949bf9a185acb3a96eea0d59dab60632aa248af, archive16724079d8d759cf3c27dc092cb42e78ac623aea49c5d04ce141cd05ce4d1f45. Exact10assetchecksPASS; no cold qualification request or guard/cap/reserve change. This resolves the Node-test placement classification stop through the ordinary pipeline.

Fresh real-visibility capture aud061-aud08-web-accepted-20261111: actual DOM listener presence for document.visibilitychange and window.pagehide each shows1bubble game listener plus1capture observation listener. Ordinary Sleep card1PM; trusted Sleep input followed by genuine hidden event**173.5ms**, minimize completion26ms after click acknowledgement. Strict200ms targetPASS. Primary changes100302bytes/SHA7ea8271815d80dda4a2923bfca8885ea8fb76a63d356499e42763ca6ec8dbc3c to100432bytes/SHAe407d09a0fdeffd2b6621857ad941936bd2a1e9ff6128d0d0fb660de8ed2f480 while hidden. After reload primary is the same new100432bytes/e407...; no .tmp/rollback. Normal Continue visibly restores9:15PM and You sleep for8hours... (screenshot32).

Read-only actual Codec validation/decode of hidden/reloaded primary captures:
Godot --headless --path . --script res://.tmp/aud08_capture_readback.gd -- <owned-hidden-capture> <owned-reloaded-capture> eb48bb98364966324813e2b7a1c6516c32ecf86e
**19checks/0failures**. Both havegame_clock_minutes1275, bankroll68, onehome_sleep entryhours8/minutes480/clock1275, exact identical byte hash e407.... No save write/profile migration/schema-version addition or game-state override. Emits only requested clock/wallet/action/hash facts.

However browser console records1error: **Already syncing!**, pageerrors0. Jobexit0 did not itself reject console output; this is explicitly **not final accepted delivery**. Capture helper now fails on any console warning/error as well, so a clean job is required along with visual review.

### Coordinate automatic and lifecycle engine sync requests

Official pinned-version source confirms public force_fs_sync only marks idb_needs_sync, while main_loop_iterate later starts the automatic sync and its callback clears idb_is_syncing. [Godot4.6 OS Web source](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/platform/web/os_web.cpp). The public bridge delegates to that flag setter. [Godot4.6 JavaScript bridge source](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/platform/web/javascript_bridge_singleton.cpp). Exact served JS inspection above establishes the underlying busy guard. The immediate lifecycle request can overlap the later C++ automatic request, producing the observed error.

Actual adapter test first expanded28checks/3failures, then30checks/4failures including a manual Save begun during the active lifecycle sync. Observedcalls1/overlaps1/persistedgeneration2: the automatic newer generation was refused. No thresholds or existing assertions were removed.

After the first lifecycle request, the bridge now serializes calls to the unchanged GodotFS.sync primitive with one promise tail. Automatic and lifecycle callers each receive a distinct later promise; original engine sync/busy/IDB implementation and native callback acknowledgement are preserved. This coordinates existing callers rather than coalescing a newer manual write into an older promise. No engine asset rewrite, direct FS.syncfs/IndexedDB access, frame pump, debounce/canvas scheduling change or new version check. Queue installation occurs once in this engine module; existing manual begin/poll code stays unchanged.

Same full adapter test after: **30/0**, automatic/lifecycle interleavingcalls2/overlaps0/persistedgeneration3, newer manual acknowledgement succeeds. This is controlled engine-promise VM evidence, not real IndexedDB. Native77/0 again, queued flush113.000/115.097/120.759ms with no frames. LivenessPASS again. Coordinated Smoke4pass/7fail matches baseline4/7, exact content25/runtime16 inherited assertions, normalized new errors[], performance9inherited versus baseline10, no timeout/activeprocesses0; exact deployed clean-console/within200ms/reload proof still pending.
