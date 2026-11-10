# BTH-PERF-20261104-001: continuous nozzle input starves Web coin views

Parent: [BTH-PERF-20261104](../plans/performance_audit_2026-11-04.md), which
remains OPEN. First finding is fixed in source and measured; main/NEXT delivery
is verified below; broader normal-input runtime acceptance stays separate. No player save was
needed or accessed. Stable, itch and hosting audience are outside this change.

## Reproduction and cause

Baseline source: `dc15b7d369f435d50fbf16e37af33952a4c58760`. The focused
`scripts/tests/coin_pusher_continuous_input_check.tscn` uses disposable generated
Quarter Falls state and normal module entry, paid Drop/result, carriage pointer
and realtime-patch APIs. It drives a synthetic60Hz clock through idle120frames,
feeding120, continuous drag+feeding180, then released60. It does not inject a
saved player's state, claim full-host input, or measure rendered FPS.

Web `queue_input()` set `presentation_last_publish_msec` to the current session
clock on every accepted movement. With a33ms interval, successive pointer
events postponed dense coin publication indefinitely. The nozzle received its
own immediate scalar patch. This reproduces smooth nozzle movement with frozen
coin positions while authority and queued emissions continue.

The fix lets only actual publication advance that timestamp. It retains33ms
Web cadence and the existing immediate control patch. No solver, input ordering,
RNG, clock accumulation, economy, snapshot schema, or rendering schedule changes.
Native `presentation_publish_due()` remains unconditional. A nearby stale
comment was corrected. Same-frame input and publication can now coincide;
restoring publication is bounded by its existing cadence.

## Decisive measurements

| Three-second continuous-input window | Web before | Web after | Native before/after |
| --- | --- | --- | --- |
| Authoritative ticks |180|180|180 /180|
| Nozzle changes |180|180|180 /180|
| Published coin frames |0|90|120 /120|
| Maximum sampled age of coin publication |3017ms|17ms|16ms /16ms|
| Maximum accumulated backlog |1tick|1tick|0 /0|

All four runs retain$476 after24 reserved drops,18 emitted plus6 pending, zero
carriage turn charges and passing coin conservation in every phase. Idle,
feeding and released publication also pass after the fix. These are actual
native/Web module executions with a synthetic clock, not a wall-clock gameplay
or all-cabinet certification. Update age is sampled once per supplied frame;
the17ms figure is not a claim that the33ms publisher runs at60Hz.

Comparable raw reports and attribution timings are in
[`evidence/performance_audit_20261104`](evidence/performance_audit_20261104).
Pointer/realtime mean,p95,max are retained there. The5% aggregate CPU cap can
cause large wall-time outliers; these diagnostic call timings are not player
hardware budgets or a generalized FPS speedup. No budgets were changed.

Both Web comparisons use the current qualified shipped native WASM hash
`82c71b7d743027817c8f5041ad2f052565bf27fe43ec60312a2473af08957943`, copied
from the existing NEXT archive and checked against served provenance. Original
local native bytes and earlier diagnostic attempts were preserved. The pinned
Web template hash is `cf371f607aa9cb18e690bd595976c1baaf00c8cec24078e4a307fd515ad07913`.
Native DLL hashes match the pipeline's recorded editor dependencies. Baseline
and fixed Web probes have byte-identical test sources; export PCK/WASM hashes,
browser version,viewport and zero console errors are in the manifest/reports.

## Focused checks and exact local commands

From task-18, the maintained private Job helpers assign each worker suspended,
verify5% CPU/2GiB limits, use isolated persistence roots and a finite deadline,
then record zero processes at release. The native executable is the locked
Godot4.6 stable `89cea1439`. Run the committed scene with:

```text
Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path <source> res://scripts/tests/coin_pusher_continuous_input_check.tscn
Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path <source> --script res://scripts/tests/animation_liveness_without_pointer_check.gd
```

The fixed native scene passes. Required no-pointer animation liveness passes.
Existing paid-resolution test passes23 synthetic payment/terminal checks;
its required `BTH_TARGET_OUTPUT` is an isolated evidence path. It is not compact
rollback or actual Web gameplay coverage. Native CA-store access diagnostics
were retained; these checks perform no network operation.

Exact local launch/evidence files: task-18 `run_owned.py`, `export_probe.py`,
`capture_probe.cjs`, `focused_checks.py` and `evidence/*.json/*.log`. Export
uses production all_resources and the pinned template with this test scene as
the temporary main, then restores original config bytes. Reused native payload
hashes are validated. No native rebuild, second watcher or manual deployment
substitute was introduced.

Earlier harness-only failures are retained: clamped pointer geometry was fixed
by deriving the production drag rectangle; selected-resource export omitted
global-class/native dependencies and was corrected to production all_resources;
Chromium installation discovery requires real Windows roots while its browser
profile stays disposable. Those failures are not product regressions.

## Remaining acceptance

Implementation is on main as `ea136553ce3f33236aa3ea22d23921e6f957e7a2`.
Existing cold-import qualification consumed the exact `247ebe3277cee8bc46fc3cff084607441fa296d4`
request and promoted that descendant at2026-11-04T00:52:33Z. Its tree is
`d6666d67326787155852e0fc51a91c354946e8ff`; archive SHA256 is
`4973723cb4141541868fd6597a2bd61f2a71abfb78d63eb0627c81930c0ef0e1`.
Served redirect/metadata,PCK/native bytes,engine sizes and fresh isolated menu
startup pass with no page or request failures. No manual build or guard bypass
was used. Later NEXT heads may supersede that observed receipt.

Sustained normal player drag in the full served host remains a broader sampled
play acceptance; the faithful module reproduction is labeled above.
Broader actual native and Web runtime profiling, other cabinets, long
session retention and other games remain in the parent coverage plan. The
separate Video Poker and retained-input candidates are not closed here.
