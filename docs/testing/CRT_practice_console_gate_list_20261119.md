# CRT qualification reproduction record - no current launch authorization

Current ONE bounded Cold3 is closedexit1/owned0, browser/serverclosedtrue.
Strict new-loader PCK abort remains unexpected: technicalFAIL/PARTIAL, actual
Continue semanticsPASS. BothstartGame readiness hooks succeeded; full server
bytes/no prematureclose do not explain the transportabort. Exactly2PCKrequests,
no laterretry/cachecompletion. Portrait ergonomicsOPEN and inheritedSaveACK
warning retained. Allsix releasegatesOpen; no main/NEXT/TEST publication.
Only parent-authorized verified transfer-artifact phase is planned. Its external
manifest will be authoritative for actual patch/hash verification; no artifact
completion is claimed here. Earlier37receipts/reconciliation stay historical.
No user-reserved manual checks or reconciliation are run/authorized by this
follow-up. The commands below are historical/future reproduction material, not
permission for another Job. C edits stop for the parent artifact freeze.

Keep the photographed layout. Run sequentially, with a fresh run ID/profile per
command and unchanged storage/resource guards. Stop a failed gate before the
next one. Never run CLI `prepare` and then CLI `run` with the same ID: `run`
prepares and launches once. The two custom build/capture adapters also prepare
and launch once themselves, so do not wrap them in another guarded Job.
The complete campaign has six native Jobs (navigation, state, cold, rooms,
launchers, Slot), one private pack Job and three fresh browser Jobs. Retain
completed unchanged gates rather than rerunning them; all six native gates and
the private-pack gate now have passing receipts. Commands remain the reproducible gate list,
not an instruction to repeat completed work. Liveness is conditional below.

## Evidence already obtained

`crt061-capture2-20261119` captured actual production title Games mouse
press/release into the corrected CRT at 1280 x 720. It proves the photographed
source loads, native desktop GDScript and glass shader compile/render, the
4:3 display and eleven icon/name tiles are present, and that one title entry
works. Exit code 0, assignment before execution, 12% CPU/2 GiB caps, owned 0.

PNG SHA-256: `dd12ca34f8815fdc676b87f3098da4bab06944a38b505769ae69ea0838228dd2`.
The image does not prove eleven gameplay launches, seed repeatability, state
isolation, six room pointer paths, mobile readability, motion behavior or Web.
Two mouse-exit warnings occurred after capture during teardown. The narrow
source fix removes the redundant explicit `notify_mouse_exited()` after
`gui_disable_input = true`; pinned Godot already leaves mouse focus there.
The overlay hide and subsequent menu hide caused the two observed callbacks.
Nav 5 now qualifies that teardown correction for the exercised desktop paths:
no Viewport notification warnings were logged. Shader/layout are unchanged.

| Subsequent receipt | Exact coverage and limit |
| --- | --- |
| `crt061-navigation4-20261119` | Closed exit 1 / owned 0. Desktop work passed without SCRIPT ERROR or Viewport warnings. It failed a test assumption that resizing a Windows window changed the production logical viewport; the app retains its fixed 1280 x 720 logical coordinates. No product layout change followed. |
| `crt061-navigation5-20261119` | Closed exit 0 / owned 0, 459 checks, empty failure array, no engine or Viewport warnings. Actual native desktop/default and large-form navigation, mapped input, retained options, selected game/Leave loops, static Reduce Motion and bounded no-input image changes passed. Root inspected the desktop/form renders. |
| Actual mobile rendering | Landscape2 at844x390 and Portrait2 at390x844 now have clean raw protocols, stage screenshots and touch/seed/setup/game-return/exit-reopen flows. Production MobileViewportPolicy retains authored1280x720 on all platforms; these test CSS sizing/letterbox coordinates, not logical resizing. Tiny portrait captions/footer remain an ergonomic limitation, not a readability pass. |

Completed native gates: Regression6 passed634 checks; Cold2 passed23 producer
and16 cold checks with exact RNG strings and retained ordinary Apartment cash130,
two profile chips and137 meta gold; Rooms3 passed531 checks/all six ordinary+meta
origins; Launchers1 clicked, entered and returned all11 games through normal
Leave; Slot2 passed19 assertions. Each passed exit0/owned0. Webpack1 passed its
private PCK audit:125018680 bytes,
SHA-256 `249de92b391d1501c3c8e4d4d2d0e530eb267a646bee9cf525c6b60ad612a307`.
These do not constitute final Web or main/NEXT qualification. Exact receipts and
the two earlier raw failed Web results are retained in
[structured evidence](CRT_practice_console_native_web_evidence_20261119.json).
Fresh Trace1, Landscape2 and Portrait2 each exited0/owned0, explicitly stopped,
closed browser/server and reported passedtrue without JS/console/failed-request
or non200 entries. Trace1 fully received the private125018680-byte PCK without
abort or premature server close. Earlier failed attempts remain unchanged.
Exact served Baseline1 also passed its protocol and reproduced the same manual
Save warning before any CRT entry, establishing inherited behavior but not
passing Save UX. Fresh Webcold2 now has working Continue semantic evidence, but the NEW reload-page
asset abort leaves technical acceptance PARTIAL. Final owned closure is confirmed.

## Commands and pass criteria

Use a new campaign value every time this block is run. Variables only compose
paths; each launcher admits storage before its first QA write or child.

```powershell
$sourceCheckout = 'C:\Users\theep\Documents\Codex\2026-11-18\task\crt-source'
$qaWorkspace = 'E:\CodexQA\BTH\workspaces\crt-console-20261119'
$qaPy = 'C:\Users\theep\AppData\Local\Programs\Python\Python310\python.exe'
$qaGodot = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe'
$qaGuard = Join-Path $sourceCheckout 'tools\bth_qa_guarded_run.py'
$qaCampaign = 'crt061-qual-' + (Get-Date -Format 'yyyyMMdd-HHmmss')

function Invoke-CrtNative {
    param([string]$Label, [string]$Script, [int]$Seconds, [switch]$Rendered)
    $runId = "$qaCampaign-$Label"
    $runEvidence = "E:\CodexQA\BTH\runs\$runId\evidence"
    $engineArguments = @('--path', $qaWorkspace, '--log-file',
        (Join-Path $runEvidence 'godot.log'), '--script', $Script)
    if (-not $Rendered) { $engineArguments = @('--headless') + $engineArguments }
    & $qaPy -B $qaGuard run --workspace $qaWorkspace --run-id $runId --timeout $Seconds --cpu-rate 1200 -- $qaGodot @engineArguments
    if ($LASTEXITCODE -ne 0) { throw "CRT gate failed: $Label" }
    if (Select-String -LiteralPath (Join-Path $runEvidence 'worker.log') -Pattern 'SCRIPT ERROR|Parse Error|Failed to load script|previously notified that the mouse' -Quiet) {
        throw "CRT gate has an engine/input warning or error: $Label"
    }
}
```

1. **Refresh, teardown warning and rendered input/motion.** The capture adapter's
   `--navigation` mode hash-checks the authoritative C inputs into E and runs only
   the native navigation script. It first replays Games-to-CRT-to-close with the
   pointer outside the glass, reopens, and then
   exercises actual hover, Exit/Back/reopen, edge hits, keyboard/controller/touch,
   popup/Setup cancellation, retained seed/JSON and large text in the production
   fixed Windows 1280x720 logical viewport. It explicitly defers mobile sizes on
   unsupported native platforms to the mandatory actual Web/mobile gate below.
   It checks both static Reduce Motion and bounded idle image changes
   with motion enabled. Inspect screenshots for legibility and the 44-virtual-pixel
   footer's physical touch size; source bounds alone do not pass visual acceptance.

   ```powershell
   & $qaPy -B (Join-Path $sourceCheckout 'tools\crt_practice_capture.py') --navigation --source-checkout $sourceCheckout --workspace $qaWorkspace --run-id "$qaCampaign-navigation"
   if ($LASTEXITCODE -ne 0) { throw 'CRT refresh/navigation failed' }
   $navigationLog = "E:\CodexQA\BTH\runs\$qaCampaign-navigation\evidence\worker.log"
   if (Select-String -LiteralPath $navigationLog -Pattern 'SCRIPT ERROR|Parse Error|Failed to load script|previously notified that the mouse' -Quiet) { throw 'CRT navigation has an engine/input warning or error' }
   ```

   Inspect the navigation `worker.log`: the adapter's exit-code/image check does
   not itself reject nonfatal warnings. It must lack the two mouse-exit warnings
   and new mouse-enter warnings. Preserve image/source hashes and
   unchanged photographed geometry/assets; do not demand pixel equality while
   analog displacement is enabled.

2. **State/generation and engine-cold Continue.** The focused regression owns all
   eleven production generation/default/override and repeatability assertions,
   Scratch stock 100 per active ticket, paid wager/Leave, complete origin state,
   queued save completion before ownership, refusal/retry, accepted in-flight
   draining, background write rejection and profile/meta bytes. The cold worker
   runs two separate engine processes sequentially in one fresh guarded Job and
   checks real Continue plus nonempty profile/meta retention.

   ```powershell
   Invoke-CrtNative 'state' 'res://scripts/tests/crt_practice_console_check.gd' 360
   & $qaPy -B $qaGuard run --workspace $qaWorkspace --run-id "$qaCampaign-cold" --timeout 600 --cpu-rate 1200 -- $qaPy -B (Join-Path $qaWorkspace 'tools\crt_practice_cold_continue.py') --godot $qaGodot --timeout-per-phase 240
   if ($LASTEXITCODE -ne 0) { throw 'CRT engine-cold Continue failed' }
   ```

   Require empty semantic failure arrays, both cold phases closed/exit 0, no
   SCRIPT ERROR in either phase's logs, unchanged original state and the ordinary
   run still in Continue. The previous cold attempt was rejected before any
   engine by `not_directory: E:\CodexQA\BTH\runs\crt061-cold1-20261119\evidence\crt-cold-supervisor.json: a writable path ancestor is not a directory`.
   The client now declares its evidence parent directory, leaving guards intact.
   Cold2 subsequently obtained fresh normal admission and passed both phases;
   the old refused request is retained, not reused. Future runs still require
   fresh admission. If rejected, retain the exact barrier and stop that launch.

3. **Six rendered source/return paths and all eleven normal game Leave paths.**
   The room script runs Motel Room, Apartment and Home as ordinary rooms and all
   three meta-home tiers. Require CRT/current_game-null after Play release,
   unoccluded mapped Exit, exact origin identity/room/RNG restoration, no upgrade
   sign overlap and all six cases passed. Keep phase diagnostics for failures.
   The launcher then clicks all eleven curved tile edges and each game's normal
   rendered Leave, including Quarter Falls settlement. Slot retains its separate
   six-cabinet strict-authority/tamper/prerequisite adjacent coverage.

   ```powershell
   Invoke-CrtNative 'rooms' 'res://scripts/tests/ui_scene/check_crt_room_entry.gd' 300 -Rendered
   Invoke-CrtNative 'launchers' 'res://scripts/tests/ui_scene/check_game_library_launchers.gd' 300 -Rendered
   Invoke-CrtNative 'slot' 'res://scripts/tests/close01_slot_practice_room_check.gd' 120
   ```

   Run the existing adjacent liveness check if a new fix/rebase changes canvas
   scheduling/performance. The CRT's no-input jitter is already tested by Gate 1;
   the earlier liveness pass remains historical evidence for unchanged canvases.

   ```powershell
   Invoke-CrtNative 'liveness' 'res://scripts/tests/animation_liveness_without_pointer_check.gd' 90
   ```

4. **One private Web pack, then three fresh Web profiles.** Before using the
   composite adapter, retain an exact read-only source comparison proving
   `native/`, `addons/`, `project.godot` and `export_presets.cfg` unchanged from
   `89403f389a5807e050a450cd27b1bd93b3a4a41e`. Run Git as the checkout's owner;
   never change Git trust. Store its command, exit code and output in the first
   navigation run's admitted evidence directory as `native-input-proof.json` and set
   `$nativeProof` to that exact file. If native/project inputs changed during
   integration, this baseline adapter is not qualified: use the normal reviewed
   build path with approved matching runtime inputs instead. Do not merely
   substitute another WASM or alter a pin.

   ```powershell
   $nativeComparison = @(git -C $sourceCheckout diff --exit-code 89403f389a5807e050a450cd27b1bd93b3a4a41e -- native addons project.godot export_presets.cfg 2>&1)
   $nativeComparisonExit = $LASTEXITCODE
   if ($nativeComparisonExit -ne 0) { throw 'Baseline Web runtime inputs are not unchanged' }
   $nativeProof = "E:\CodexQA\BTH\runs\$qaCampaign-navigation\evidence\native-input-proof.json"
   [ordered]@{ baseline = '89403f389a5807e050a450cd27b1bd93b3a4a41e'; source = $sourceCheckout; paths = @('native/', 'addons/', 'project.godot', 'export_presets.cfg'); command = 'git diff --exit-code BASE -- native addons project.godot export_presets.cfg'; exit_code = $nativeComparisonExit; output = $nativeComparison } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $nativeProof -Encoding utf8
   $packName = "$qaCampaign-private"
   & $qaPy -B (Join-Path $sourceCheckout 'tools\crt_practice_web_pack.py') --workspace $qaWorkspace --run-id "$qaCampaign-pack" --output-name $packName --caller-proof $nativeProof
   if ($LASTEXITCODE -ne 0) { throw 'Private CRT Web pack failed' }
   ```

   Require passed PCK audit, required menu/shader/home-console resources, matching
   pinned runtime inputs, no export/parser errors and owned 0. This is disposable
   composite QA, not a deployed commit identity. Launch each browser command
   separately and finish it with the worker's explicit `stop` command before
   starting the next viewport:

   ```powershell
   $qaNode = 'C:\Program Files\nodejs\node.exe'
   $webWorker = Join-Path $qaWorkspace 'tools\crt_practice_web_smoke.cjs'
   $privateRoot = Join-Path $qaWorkspace "builds\$packName"
   & $qaPy -B $qaGuard run --workspace $qaWorkspace --run-id "$qaCampaign-web-desktop" --timeout 510 --cpu-rate 1200 -- $qaNode $webWorker --root $privateRoot --viewport 1280x720
   if ($LASTEXITCODE -ne 0) { throw 'CRT desktop Web gate failed' }
   & $qaPy -B $qaGuard run --workspace $qaWorkspace --run-id "$qaCampaign-web-landscape" --timeout 510 --cpu-rate 1200 -- $qaNode $webWorker --root $privateRoot --viewport 844x390
   if ($LASTEXITCODE -ne 0) { throw 'CRT landscape Web gate failed' }
   & $qaPy -B $qaGuard run --workspace $qaWorkspace --run-id "$qaCampaign-web-portrait" --timeout 510 --cpu-rate 1200 -- $qaNode $webWorker --root $privateRoot --viewport 390x844
   if ($LASTEXITCODE -ne 0) { throw 'CRT portrait Web gate failed' }
   ```

   These are screenshot-driven interactive workers, not autonomous pass scripts.
   The worker now has a bounded normal `page.reload()` action and retains raw
   request failures with action context. Its narrow classifier permits only
   `net::ERR_ABORTED` during an explicit reload as an expected navigation abort;
   every other failed request still fails the gate. The later cold2 trace shows active-reload-only classification was insufficient:
   its aborted request belongs to the NEW page. The corrected classifier has8
   source checks but remains runtime-unqualified; future verification must not
   waive a new-page asset abort solely because reload is active.
   The earlier Webcold1 raw failed result is not retroactively
   changed to passed. Nav 5 qualifies the mouse-exit fix for
   its exercised native desktop paths only.
   Use each fresh `evidence/control/command-01.json` onward with the existing
   bounded action schema; choose coordinates from that run's actual screenshots.
   Do not paste desktop coordinates into mobile runs. Desktop: title entry,
   all eleven icons/names and normal game launches/Leave, seed/Setup editing,
   focus/back, repeated title/selector loop. Also create/save a supported ordinary
   run through normal UI, record its room/cash/clock, enter CRT and make a real
   practice wager, then reload the page in this same fresh browser context and
   use actual Continue. Require the ordinary room/cash/clock, not practice state.
   This supplies Web persistence/pagehide evidence; native Gate 2 owns exact RNG,
   queued/in-flight generation and nonempty profile/meta comparisons. Mobile:
   inspect full TV/glass and
   captions, touch near first/last tile edges, real Leave, seed and scrolled Setup
   editing, popup/Back/Exit and repeated loops. Exercise existing Reduce Motion
   through its normal settings UI and inspect static display. No forced Godot
   state, save import or browser-storage injection. Require no page/SCRIPT errors,
   unexpected failed required assets, input occlusion or clipped/unusable controls;
   retain any narrowly classified reload abort in the raw evidence. Require a
   passed result, explicit stop and browser/server/owned-process closure.
   The workers are bounded to 480 seconds/40 commands each. If a normal required
   flow needs another run, start a fresh admitted profile; do not relax limits.

## Exit to integration

At every Job boundary inspect `job.json`: assigned-before-execution, unchanged
caps, exit 0, no timeout/error/cleanup errors and `active_at_release=0`. Preserve
all failed receipts; do not restart a watcher, terminate another worker or clean
profiles. Manual reconciliation is user-reserved and was not run for this follow-up.
Only with separate future direction use
the separately approved main-to-NEXT workflow, rechecking exact candidate/source,
remote and served commit/assets and feature smoke. The screenshot is not a
substitute for those delivery gates.
