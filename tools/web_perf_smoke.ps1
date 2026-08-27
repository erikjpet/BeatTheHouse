param(
    [ValidateSet("chrome", "firefox")]
    [string]$Browser = "chrome",
    [int]$Cpu = 4,
    [int]$Port = 8062,
    [int]$Frames = 45,
    [int]$ActiveFrames = 60,
    [int]$MemorySeconds = 20,
    [int]$TimeoutMs = 600000,
    [string]$Out = ".tmp/web_perf_smoke/report.json",
    [ValidateSet("l02", "grand_casino", "coin_pusher")]
    [string]$Plan = "l02",
    [switch]$SkipExport,
    [switch]$Headed
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$trackedStatus = @(& git -C $root status --short --untracked-files=no)
if ($Plan -eq "coin_pusher" -and $trackedStatus.Count -gt 0) {
    throw "Coin Pusher Web performance evidence requires a clean tracked source tree so its commit identity is exact."
}
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    throw "Node.js was not found on PATH. The web perf smoke uses tools/l02_web_perf_probe.mjs."
}

$frameP95BudgetsMs = @{
    "menu_idle" = 180.0
    "start_menu_idle" = 20.0
    "corner_store_idle" = 120.0
    "pull_tabs_idle" = 20.0
    "pull_tabs_active" = 60.0
    "slot_idle" = 45.0
    "slot_active" = 110.0
    "bar_dice_idle" = 25.0
    "bar_dice_active" = 90.0
    "blackjack_idle" = 25.0
    "blackjack_active" = 110.0
    "baccarat_idle" = 25.0
    "baccarat_active" = 120.0
    "roulette_idle" = 30.0
    "roulette_active" = 160.0
    "video_poker_idle" = 20.0
    "video_poker_active" = 60.0
    "slot_autoplay_active" = 100.0
    "pinball_feature_session" = 180.0
    "world_map_idle" = 45.0
    "scripted_play_memory_10m" = 45.0
}
if ($Plan -eq "grand_casino") {
    $frameP95BudgetsMs = @{
        "menu_idle" = 180.0
        "grand_casino_late_settle" = 60.0
        "grand_casino_room_churn" = 50.0
        "grand_casino_late_idle" = 50.0
    }
}
if ($Plan -eq "coin_pusher") {
    # The 22/7 active limits are the maintained owner-authorized native
    # baseline recorded in foundation_performance_probe.gd. Idle retains the
    # V3 plan's 16/5 shipped-cap contract.
    $frameP95BudgetsMs = @{
        "menu_idle" = 180.0
        "coin_pusher_idle" = 16.0
        "coin_pusher_active_drop" = 22.0
        "coin_pusher_active_carriage" = 22.0
        "coin_pusher_active_skill_stop" = 22.0
        "coin_pusher_active_skill_release" = 22.0
        "coin_pusher_active_collect" = 22.0
        "coin_pusher_reduced_motion" = 16.0
    }
}
$readyBudgetMs = 20000
$cornerStoreOpenBudgetMs = 1200
$telemetryOverheadAvgBudgetMs = 0.1
$scenarioMemoryDeltaBudgetBytes = 128MB

function Wait-ForWebServer {
    param([string]$Url, [int]$TimeoutSec)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                return
            }
        }
        catch {
            Start-Sleep -Milliseconds 250
        }
    }
    throw "Timed out waiting for web server at $Url."
}

function Assert-Condition {
    param([bool]$Condition, [string]$Message, [System.Collections.Generic.List[string]]$Failures)
    if (-not $Condition) {
        $Failures.Add($Message)
    }
}

function Get-WebExportIdentity {
    param([string]$WebDirectory)
    if (-not (Test-Path -LiteralPath (Join-Path $WebDirectory "index.html"))) {
        throw "Web export identity requires builds/web/index.html."
    }
    $files = @(Get-ChildItem -LiteralPath $WebDirectory -File -Recurse | Sort-Object FullName)
    $rows = @()
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($WebDirectory.Length).TrimStart('\', '/') -replace '\\', '/'
        $rows += [ordered]@{
            path = $relative
            bytes = [int64]$file.Length
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        }
    }
    $canonical = ($rows | ForEach-Object { "{0}`t{1}`t{2}" -f $_.path, $_.bytes, $_.sha256 }) -join "`n"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $aggregate = [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($canonical))).Replace("-", "")
    }
    finally {
        $sha.Dispose()
    }
    return [ordered]@{ aggregate_sha256 = $aggregate; file_count = $rows.Count; files = $rows }
}

if (-not $SkipExport) {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "export_itch.ps1") -Target web
    if ($LASTEXITCODE -ne 0) {
        throw "Web export failed with exit code $LASTEXITCODE."
    }
}

$sourceCommit = (& git -C $root rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourceCommit)) {
    throw "Could not resolve the source commit for Web performance identity."
}
$webExportIdentity = Get-WebExportIdentity -WebDirectory (Join-Path $root "builds/web")
$exportSha256 = [string]$webExportIdentity.aggregate_sha256

$outPath = Join-Path $root $Out
$outDir = Split-Path -Parent $outPath
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
if (Test-Path -LiteralPath $outPath) {
    if ($Plan -eq "coin_pusher") {
        throw "Refusing to overwrite retained Coin Pusher Web performance evidence: $outPath"
    }
    Remove-Item -LiteralPath $outPath -Force
}
$serverStdout = Join-Path $outDir "serve_web.stdout.txt"
$serverStderr = Join-Path $outDir "serve_web.stderr.txt"
$serverArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $PSScriptRoot "serve_web.ps1"),
    "-Port", [string]$Port,
    "-NoBrowser"
)
$server = $null
try {
    $server = Start-Process -FilePath (Get-Command powershell -ErrorAction Stop).Source -ArgumentList $serverArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $serverStdout -RedirectStandardError $serverStderr
    Wait-ForWebServer -Url "http://127.0.0.1:$Port/" -TimeoutSec 30
    $headless = if ($Headed) { "false" } else { "true" }
    $url = "http://127.0.0.1:$Port/?bth_perf=1&bth_perf_plan=$Plan&bth_perf_auto_quit=1&bth_perf_frames=$Frames&bth_perf_active_frames=$ActiveFrames&bth_perf_memory_seconds=$MemorySeconds&bth_perf_source_commit=$sourceCommit&bth_perf_export_sha256=$exportSha256"
    $profile = Join-Path $root (".tmp/web_perf_smoke/{0}_profile" -f $Browser)
    $coldCache = if ($SkipExport) { "false" } else { "true" }
    $probeArgs = @(
        (Join-Path $PSScriptRoot "l02_web_perf_probe.mjs"),
        "--browser=$Browser",
        "--headless=$headless",
        "--cpu=$Cpu",
        "--timeout-ms=$TimeoutMs",
        "--url=$url",
        "--out=$outPath",
        "--profile=$profile",
        "--cold-cache=$coldCache"
    )
    & $node.Source @probeArgs
    if ($LASTEXITCODE -ne 0) {
        throw "L0.2 web perf probe failed with exit code $LASTEXITCODE."
    }
}
finally {
    if ($server -ne $null -and -not $server.HasExited) {
        Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path -LiteralPath $outPath)) {
    throw "Web perf smoke did not produce report: $outPath"
}
$reportEnvelope = Get-Content -LiteralPath $outPath -Raw | ConvertFrom-Json
$report = $reportEnvelope.report
$failures = [System.Collections.Generic.List[string]]::new()

$readyWall = 0
if ($null -ne $reportEnvelope.ready) {
    if ($null -ne $reportEnvelope.ready.navigation_wall_msec) {
        $readyWall = [int]$reportEnvelope.ready.navigation_wall_msec
    }
    else {
        $readyWall = [int]$reportEnvelope.ready.wall_msec
    }
}
Assert-Condition -Condition ($readyWall -gt 0) -Message "BTH_PERF_READY was not captured." -Failures $failures
Assert-Condition -Condition ($readyWall -le $readyBudgetMs) -Message ("Web ready wall time {0}ms exceeded {1}ms." -f $readyWall, $readyBudgetMs) -Failures $failures

$overheadAvg = [double]$report.telemetry_overhead.avg_ms
Assert-Condition -Condition ($overheadAvg -le $telemetryOverheadAvgBudgetMs) -Message ("Telemetry overhead avg {0:N4}ms exceeded {1:N4}ms." -f $overheadAvg, $telemetryOverheadAvgBudgetMs) -Failures $failures

$cornerStoreOpenMs = 0.0
if ($Plan -eq "l02") {
    $cornerStoreOpenEvents = @($report.events | Where-Object { [string]$_.id -eq "corner_store_open" })
    Assert-Condition -Condition ($cornerStoreOpenEvents.Count -gt 0) -Message "Missing corner_store_open web transition event." -Failures $failures
    if ($cornerStoreOpenEvents.Count -gt 0) {
        $cornerStoreOpenMs = [double]$cornerStoreOpenEvents[-1].data.duration_ms
        Assert-Condition -Condition ($cornerStoreOpenMs -le $cornerStoreOpenBudgetMs) -Message ("Corner Store open {0:N3}ms exceeded {1:N3}ms." -f $cornerStoreOpenMs, $cornerStoreOpenBudgetMs) -Failures $failures
    }
}

$scenariosByName = @{}
foreach ($scenario in @($report.scenarios)) {
    $scenariosByName[[string]$scenario.name] = $scenario
}
foreach ($scenarioName in $frameP95BudgetsMs.Keys) {
    Assert-Condition -Condition ($scenariosByName.ContainsKey($scenarioName)) -Message "Missing web perf scenario '$scenarioName'." -Failures $failures
    if (-not $scenariosByName.ContainsKey($scenarioName)) {
        continue
    }
    $scenario = $scenariosByName[$scenarioName]
    $p95 = [double]$scenario.frame_time_ms.p95
    $budget = [double]$frameP95BudgetsMs[$scenarioName]
    Assert-Condition -Condition ($p95 -le $budget) -Message ("Scenario {0} frame p95 {1:N3}ms exceeded {2:N3}ms." -f $scenarioName, $p95, $budget) -Failures $failures
    $memoryDelta = [Math]::Abs([int64]$scenario.static_memory_bytes.delta)
    Assert-Condition -Condition ($memoryDelta -le $scenarioMemoryDeltaBudgetBytes) -Message ("Scenario {0} memory delta {1:N0} bytes exceeded {2:N0} bytes." -f $scenarioName, $memoryDelta, $scenarioMemoryDeltaBudgetBytes) -Failures $failures
}

if ($Plan -eq "coin_pusher") {
    Assert-Condition -Condition ($Browser -eq "chrome") -Message "Coin Pusher Web performance evidence requires the supported Chrome configuration." -Failures $failures
    Assert-Condition -Condition ($Cpu -eq 4) -Message "Coin Pusher Web performance evidence requires CPU throttle rate 4." -Failures $failures
    Assert-Condition -Condition (-not $SkipExport) -Message "Coin Pusher closure evidence requires a fresh Web export; -SkipExport is not accepted." -Failures $failures
    Assert-Condition -Condition (@($reportEnvelope.page_errors).Count -eq 0) -Message "Coin Pusher browser probe captured a page error." -Failures $failures
    Assert-Condition -Condition (@($reportEnvelope.request_failures).Count -eq 0) -Message "Coin Pusher browser probe captured a failed request." -Failures $failures
    Assert-Condition -Condition (@($reportEnvelope.failed_responses).Count -eq 0) -Message "Coin Pusher browser probe captured an HTTP failure response." -Failures $failures
    $startupErrors = @($reportEnvelope.startup_console | Where-Object { [string]$_.type -eq "error" })
    $unclassifiedStartupConsole = @($reportEnvelope.startup_console | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.classification) })
    Assert-Condition -Condition ($startupErrors.Count -eq 0) -Message "Coin Pusher browser probe captured a startup console error." -Failures $failures
    Assert-Condition -Condition ($unclassifiedStartupConsole.Count -eq 0) -Message "Coin Pusher browser probe captured an unclassified startup warning/error." -Failures $failures
    Assert-Condition -Condition ([int]$reportEnvelope.viewport.inner_width -gt 0 -and [int]$reportEnvelope.viewport.inner_height -gt 0) -Message "Coin Pusher browser viewport identity was missing." -Failures $failures
    Assert-Condition -Condition ([string]$report.build_identity.source_commit -eq $sourceCommit) -Message "Runtime source commit identity did not match the exported source commit." -Failures $failures
    Assert-Condition -Condition ([string]$report.build_identity.export_sha256 -eq $exportSha256) -Message "Runtime Web export identity did not match the served export." -Failures $failures

    $fixtureEvents = @($report.events | Where-Object { [string]$_.id -eq "coin_pusher_fixture_identity" })
    Assert-Condition -Condition ($fixtureEvents.Count -eq 1) -Message "Coin Pusher report did not contain exactly one fixture identity event." -Failures $failures
    if ($fixtureEvents.Count -eq 1) {
        $fixture = $fixtureEvents[0].data
        Assert-Condition -Condition ([string]$fixture.fixture_seed -eq "practice:coin_pusher_full_cap") -Message "Coin Pusher Web fixture seed did not match the native fixture." -Failures $failures
        Assert-Condition -Condition ([string]$fixture.rng_namespace -eq "performance_coin_pusher_full_cap" -and [string]$fixture.rng_fork -eq "bodies:300") -Message "Coin Pusher Web fixture RNG identity did not match the native fixture." -Failures $failures
        Assert-Condition -Condition ([string]$fixture.fixture_api -eq "CoinPusherSolverScript.create_machine" -and [string]$fixture.snapshot_api -eq "CoinPusherLiveSessionScript.make_snapshot") -Message "Coin Pusher Web fixture API identity did not match the native fixture." -Failures $failures
        Assert-Condition -Condition ([string]$fixture.variation_id -eq "quarter_falls" -and [string]$fixture.cabinet_scope -like "Quarter Falls shared*") -Message "Coin Pusher Web proof did not stay scoped to Quarter Falls on the shared cabinet path." -Failures $failures
        Assert-Condition -Condition ([int]$fixture.body_count -eq 300 -and [int]$fixture.machine_ceiling -ge 300 -and [int]$fixture.solver_fixed_hz -eq 60) -Message "Coin Pusher Web fixture was not the exact 300-body, 60 Hz production fixture." -Failures $failures
        Assert-Condition -Condition ([string]$fixture.platform -eq "web") -Message "Coin Pusher fixture did not execute in the Web runtime." -Failures $failures
        Assert-Condition -Condition ([string]$fixture.source_commit -eq $sourceCommit -and [string]$fixture.export_sha256 -eq $exportSha256) -Message "Coin Pusher fixture identity did not preserve source/export hashes." -Failures $failures
    }
    $reducedFixtureEvents = @($report.events | Where-Object { [string]$_.id -eq "coin_pusher_reduced_fixture_identity" })
    Assert-Condition -Condition ($reducedFixtureEvents.Count -eq 1) -Message "Coin Pusher report did not contain exactly one reduced-motion fixture reinstall identity event." -Failures $failures
    if ($fixtureEvents.Count -eq 1 -and $reducedFixtureEvents.Count -eq 1) {
        $reducedFixture = $reducedFixtureEvents[0].data
        Assert-Condition -Condition ([string]$reducedFixture.fixture_seed -eq [string]$fixture.fixture_seed -and [string]$reducedFixture.rng_namespace -eq [string]$fixture.rng_namespace -and [string]$reducedFixture.rng_fork -eq [string]$fixture.rng_fork) -Message "Coin Pusher reduced-motion reinstall did not use the identical deterministic fixture identity." -Failures $failures
        Assert-Condition -Condition ([int]$reducedFixture.body_count -eq 300 -and [string]$reducedFixture.variation_id -eq "quarter_falls") -Message "Coin Pusher reduced-motion reinstall did not re-enter the exact 300-body Quarter Falls fixture." -Failures $failures
    }

    if ($scenariosByName.ContainsKey("coin_pusher_idle")) {
        $idle = $scenariosByName["coin_pusher_idle"]
        $idleFrames = [int]$idle.frame_time_ms.count
        $idleDraw = $idle.tags.canvas_after
        $requiredRedraws = [Math]::Ceiling(($idleFrames * 8.0) / 120.0)
        Assert-Condition -Condition ($idleFrames -ge 120) -Message "Coin Pusher normal idle sampled fewer than 120 frames." -Failures $failures
        Assert-Condition -Condition ([int]$idle.tags.redraw_delta -ge $requiredRedraws) -Message ("Coin Pusher idle redraw delta {0} was below the scaled floor {1}." -f [int]$idle.tags.redraw_delta, $requiredRedraws) -Failures $failures
        Assert-Condition -Condition ([int]$idleDraw.draw_sample_count -gt 0) -Message "Coin Pusher normal idle produced no surface draw samples despite required liveness." -Failures $failures
        Assert-Condition -Condition ([double]$idleDraw.draw_p95_ms -le 5.0) -Message ("Coin Pusher idle draw p95 {0:N3}ms exceeded 5.000ms." -f [double]$idleDraw.draw_p95_ms) -Failures $failures
        Assert-Condition -Condition ([int]$idle.tags.solver_liveness_delta -gt 0) -Message "Coin Pusher normal idle solver liveness did not advance." -Failures $failures
        Assert-Condition -Condition ([int]$idle.tags.body_count_before -eq 300) -Message "Coin Pusher normal idle did not begin with exactly 300 bodies." -Failures $failures
        Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace([string]$idle.tags.solver_backend)) -Message "Coin Pusher normal idle did not identify its solver backend." -Failures $failures
    }

    if ($scenariosByName.ContainsKey("coin_pusher_reduced_motion")) {
        $reduced = $scenariosByName["coin_pusher_reduced_motion"]
        Assert-Condition -Condition ([int]$reduced.frame_time_ms.count -ge 120) -Message "Coin Pusher reduced-motion sample contained fewer than 120 frames." -Failures $failures
        Assert-Condition -Condition ([int]$reduced.tags.solver_liveness_delta -gt 0) -Message "Coin Pusher reduced motion froze solver liveness." -Failures $failures
        Assert-Condition -Condition ([int]$reduced.tags.body_count_before -eq 300) -Message "Coin Pusher reduced-motion sample did not begin from the reinstalled exact 300-body fixture." -Failures $failures
        Assert-Condition -Condition ([int]$reduced.tags.body_count_after -gt 0) -Message "Coin Pusher reduced-motion sample lost the production body surface." -Failures $failures
    }

    $actionScenarios = @(
        "coin_pusher_active_drop",
        "coin_pusher_active_carriage",
        "coin_pusher_active_skill_stop",
        "coin_pusher_active_skill_release",
        "coin_pusher_active_collect"
    )
    foreach ($actionName in $actionScenarios) {
        if (-not $scenariosByName.ContainsKey($actionName)) { continue }
        $action = $scenariosByName[$actionName]
        $tags = $action.tags
        $draw = $tags.canvas_after
        Assert-Condition -Condition ([int]$action.frame_time_ms.count -ge 60) -Message "Coin Pusher $actionName sampled fewer than 60 active frames." -Failures $failures
        Assert-Condition -Condition ([bool]$tags.handled) -Message "Coin Pusher $actionName was not accepted by production action dispatch." -Failures $failures
        Assert-Condition -Condition ([double]$tags.resolve_call_ms -le 16.0) -Message ("Coin Pusher {0} synchronous resolve {1:N3}ms exceeded 16.000ms." -f $actionName, [double]$tags.resolve_call_ms) -Failures $failures
        Assert-Condition -Condition ([int]$draw.draw_sample_count -gt 0) -Message "Coin Pusher $actionName produced no surface draw samples." -Failures $failures
        Assert-Condition -Condition ([double]$draw.draw_p95_ms -le 7.0) -Message ("Coin Pusher {0} draw p95 {1:N3}ms exceeded the maintained 7.000ms active baseline." -f $actionName, [double]$draw.draw_p95_ms) -Failures $failures
        Assert-Condition -Condition ([int]$tags.input_trace_after -gt [int]$tags.input_trace_before) -Message "Coin Pusher $actionName did not grow the production input trace." -Failures $failures
        Assert-Condition -Condition ([bool]$tags.physical_motion_seen) -Message "Coin Pusher $actionName did not show physical motion." -Failures $failures
        Assert-Condition -Condition ([int]$tags.host_full_snapshot_fallbacks -eq 0 -and [int]$tags.full_snapshot_calls -eq 0) -Message "Coin Pusher $actionName used a full-snapshot fallback instead of incremental refresh." -Failures $failures
        Assert-Condition -Condition ([bool]$tags.surface_ui_preserved) -Message "Coin Pusher $actionName did not preserve free cabinet controls." -Failures $failures
        Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace([string]$tags.solver_backend)) -Message "Coin Pusher $actionName did not identify its solver backend." -Failures $failures
    }
    if ($scenariosByName.ContainsKey("coin_pusher_active_drop")) {
        $drop = $scenariosByName["coin_pusher_active_drop"].tags
        Assert-Condition -Condition ([int]$drop.bankroll_after -eq [int]$drop.bankroll_before - 1) -Message "Accepted Web DROP did not charge exactly one quarter." -Failures $failures
        Assert-Condition -Condition ([int]$drop.environment_turns_after -eq [int]$drop.environment_turns_before + 1) -Message "Accepted Web DROP did not advance exactly one environment turn." -Failures $failures
        Assert-Condition -Condition ([int]$drop.story_entries_after -eq [int]$drop.story_entries_before + 1) -Message "Accepted Web DROP did not add exactly one story entry." -Failures $failures
        Assert-Condition -Condition ([int]$drop.bankroll_delta -eq -1 -and [bool]$drop.action_patch_present) -Message "Accepted Web DROP did not retain native consequence/patch semantics." -Failures $failures
    }
    if ($scenariosByName.ContainsKey("coin_pusher_active_carriage")) {
        $carriage = $scenariosByName["coin_pusher_active_carriage"].tags
        Assert-Condition -Condition (([int]$carriage.carriage_x_after -ne [int]$carriage.carriage_x_before) -or ([int]$carriage.selected_hole_after -ne [int]$carriage.selected_hole_before)) -Message "Accepted Web carriage/hole action did not change carriage position or selected hole." -Failures $failures
    }
    if ($scenariosByName.ContainsKey("coin_pusher_active_skill_stop")) {
        $skillStop = $scenariosByName["coin_pusher_active_skill_stop"].tags
        Assert-Condition -Condition ((-not [bool]$skillStop.skill_stop_before) -and [bool]$skillStop.skill_stop_after) -Message "Accepted Web SKILL STOP did not transition false to true." -Failures $failures
    }
    if ($scenariosByName.ContainsKey("coin_pusher_active_skill_release")) {
        $skillRelease = $scenariosByName["coin_pusher_active_skill_release"].tags
        Assert-Condition -Condition ([bool]$skillRelease.skill_stop_before -and (-not [bool]$skillRelease.skill_stop_after)) -Message "Accepted Web RELEASE did not transition true to false." -Failures $failures
    }
    if ($scenariosByName.ContainsKey("coin_pusher_active_collect")) {
        $collect = $scenariosByName["coin_pusher_active_collect"].tags
        Assert-Condition -Condition ([int]$collect.tray_count_before -eq 1 -and [int]$collect.tray_value_before -eq 3) -Message "Web COLLECT did not begin from the meaningful seeded tray result." -Failures $failures
        Assert-Condition -Condition ([int]$collect.tray_count_after -eq 0 -and [int]$collect.tray_value_after -eq 0) -Message "Accepted Web COLLECT did not empty the seeded tray." -Failures $failures
        Assert-Condition -Condition ([int]$collect.bankroll_after -eq [int]$collect.bankroll_before + 3) -Message "Accepted Web COLLECT did not credit the seeded tray value." -Failures $failures
        Assert-Condition -Condition ([int]$collect.story_entries_after -eq [int]$collect.story_entries_before + 1) -Message "Accepted Web COLLECT did not add its production story entry." -Failures $failures
    }
}

$summary = [ordered]@{
    tool = "web_perf_smoke"
    passed = ($failures.Count -eq 0)
    plan = $Plan
    browser = $Browser
    cpu_throttle_rate = $Cpu
    frames = $Frames
    active_frames = $ActiveFrames
    memory_seconds = $MemorySeconds
    ready_wall_msec = $readyWall
    ready_browser_wall_msec = if ($null -ne $reportEnvelope.ready -and $null -ne $reportEnvelope.ready.wall_msec) { [int]$reportEnvelope.ready.wall_msec } else { 0 }
    ready_node_navigation_wall_msec = if ($null -ne $reportEnvelope.ready -and $null -ne $reportEnvelope.ready.node_navigation_wall_msec) { [int]$reportEnvelope.ready.node_navigation_wall_msec } else { 0 }
    ready_budget_msec = $readyBudgetMs
    telemetry_overhead_avg_ms = $overheadAvg
    telemetry_overhead_avg_budget_ms = $telemetryOverheadAvgBudgetMs
    corner_store_open_ms = $cornerStoreOpenMs
    corner_store_open_budget_ms = $cornerStoreOpenBudgetMs
    scenario_frame_p95_budgets_ms = $frameP95BudgetsMs
    scenario_memory_delta_budget_bytes = $scenarioMemoryDeltaBudgetBytes
    source_commit = $sourceCommit
    fresh_export = (-not $SkipExport)
    web_export_identity = $webExportIdentity
    browser_version = [string]$reportEnvelope.browser_version
    user_agent = [string]$reportEnvelope.user_agent
    cold_cache = [bool]$reportEnvelope.cold_cache
    host_name = [string]$env:COMPUTERNAME
    viewport = $reportEnvelope.viewport
    page_errors = @($reportEnvelope.page_errors)
    request_failures = @($reportEnvelope.request_failures)
    failed_responses = @($reportEnvelope.failed_responses)
    report = $outPath
    failures = @($failures)
}
$summaryPath = [System.IO.Path]::ChangeExtension($outPath, ".summary.json")
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Host ("Web perf smoke report: {0}" -f $outPath)
Write-Host ("Web perf smoke summary: {0}" -f $summaryPath)
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure
    }
    exit 1
}
Write-Host "Web perf smoke passed."
