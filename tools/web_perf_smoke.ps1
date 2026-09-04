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
    [ValidateSet("cold", "warm")]
    [string]$CacheMode = "cold",
    [ValidateSet("l02", "grand_casino", "coin_pusher", "secure_entropy")]
    [string]$Plan = "l02",
    [ValidatePattern("^[A-Za-z0-9_.:-]*$")]
    [string]$EvidenceProfile = "web",
    [switch]$CoinPusherStageDiagnostic,
    [switch]$SkipExport,
    [switch]$Headed
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "web_perf_coin_pusher_clock_contract.ps1")
. (Join-Path $PSScriptRoot "web_perf_idle_liveness_contract.ps1")
. (Join-Path $PSScriptRoot "web_perf_prestage_contract.ps1")
. (Join-Path $PSScriptRoot "web_server_lifecycle.ps1")
$trackedStatus = @(& git -C $root status --short --untracked-files=no)
if ($Plan -eq "coin_pusher" -and $trackedStatus.Count -gt 0) {
    throw "Coin Pusher Web performance evidence requires a clean tracked source tree so its commit identity is exact."
}
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    throw "Node.js was not found on PATH. The web perf smoke uses tools/l02_web_perf_probe.mjs."
}
$outPath = Resolve-WebPerfEvidencePath -Root $root -Out $Out
$outDir = Split-Path -Parent $outPath
if (Test-Path -LiteralPath $outPath) {
    if ($Plan -eq "coin_pusher") {
        throw "Refusing to overwrite retained Coin Pusher Web performance evidence: $outPath"
    }
    Remove-Item -LiteralPath $outPath -Force
}
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$frameP95BudgetsMs = @{
    "menu_idle" = 180.0
    "start_menu_idle" = 20.0
    "corner_store_idle" = 120.0
    "pull_tabs_idle" = 20.0
    "pull_tabs_active" = 60.0
    "scratch_tickets_idle" = 25.0
    "scratch_tickets_active" = 65.0
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
    "craps_idle" = 30.0
    "craps_active" = 160.0
    "crew_draw_poker_idle" = 25.0
    "crew_draw_poker_active" = 110.0
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
if ($Plan -eq "secure_entropy") {
    $frameP95BudgetsMs = @{
        "menu_idle" = 180.0
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

$serverStdout = Join-Path $outDir "serve_web.stdout.txt"
$serverStderr = Join-Path $outDir "serve_web.stderr.txt"
$serverOwnership = Join-Path $outDir ("serve_web.ownership.{0}.json" -f [guid]::NewGuid().ToString("N"))
$profile = Join-Path $root (".tmp/web_perf_smoke/{0}_profile" -f $Browser)
if ($CacheMode -eq "warm" -and -not (Test-Path -LiteralPath $profile)) {
    throw "Warm-cache Web performance evidence requires an existing profile from a preceding cold-cache run: $profile"
}
$server = $null
try {
    $server = Start-OwnedWebServer -ServeScript (Join-Path $PSScriptRoot "serve_web.ps1") -ServerScript (Join-Path $PSScriptRoot "serve_web_server.py") -ServeRoot (Join-Path $root "builds/web") -Port $Port -OwnershipFile $serverOwnership -StandardOutput $serverStdout -StandardError $serverStderr
    Wait-ForWebServer -Url "http://127.0.0.1:$Port/" -TimeoutSec 30
    Assert-OwnedWebServerListener -Launch $server
    $headless = if ($Headed) { "false" } else { "true" }
    $url = "http://127.0.0.1:$Port/?bth_perf=1&bth_perf_plan=$Plan&bth_perf_auto_quit=1&bth_perf_frames=$Frames&bth_perf_active_frames=$ActiveFrames&bth_perf_memory_seconds=$MemorySeconds&bth_perf_source_commit=$sourceCommit&bth_perf_export_sha256=$exportSha256&bth_perf_evidence_profile=$EvidenceProfile"
    if ($Plan -eq "coin_pusher" -and $CoinPusherStageDiagnostic) {
        $url += "&bth_perf_coin_pusher_stage_diagnostic=1"
    }
    $coldCache = if ($CacheMode -eq "cold") { "true" } else { "false" }
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
    if ($server -ne $null) {
        Stop-OwnedWebServer -Launch $server
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
    $cornerStoreTiming = Get-WebPerfCornerStoreTimingEvaluation -Report $report
    Assert-Condition -Condition ([bool]$cornerStoreTiming.startup_schema_present) -Message "Corner Store startup timing did not preserve every outer startup boundary." -Failures $failures
    Assert-Condition -Condition ([bool]$cornerStoreTiming.travel_schema_present) -Message "Corner Store travel timing did not preserve every inner production boundary." -Failures $failures
    Assert-Condition -Condition ([bool]$cornerStoreTiming.stage_values_valid) -Message "Corner Store stage timing contained an invalid stage value or target identity." -Failures $failures
    Assert-Condition -Condition ([bool]$cornerStoreTiming.totals_valid) -Message "Corner Store stage timing did not reconcile with its measured startup/travel totals." -Failures $failures
}

$scenariosByName = @{}
foreach ($scenario in @($report.scenarios)) {
    $scenariosByName[[string]$scenario.name] = $scenario
}
$l02AnimatedIdleGameIds = @(
    "pull_tabs", "scratch_tickets", "slot", "bar_dice", "blackjack",
    "baccarat", "roulette", "craps", "crew_draw_poker", "video_poker"
)
$l02ActiveGameIds = $l02AnimatedIdleGameIds
foreach ($scenarioName in $frameP95BudgetsMs.Keys) {
    Assert-Condition -Condition ($scenariosByName.ContainsKey($scenarioName)) -Message "Missing web perf scenario '$scenarioName'." -Failures $failures
    if (-not $scenariosByName.ContainsKey($scenarioName)) {
        continue
    }
    $scenario = $scenariosByName[$scenarioName]
    $p95 = [double]$scenario.frame_time_ms.p95
    $budget = [double]$frameP95BudgetsMs[$scenarioName]
    $frameSampleEligible = $true
    if ($Plan -eq "l02" -and $scenarioName -in @("baccarat_active", "roulette_active")) {
        $expectedChannel = if ($scenarioName -eq "baccarat_active") { "baccarat_deal" } else { "roulette_spin" }
        $activePhase = Get-WebPerfActivePhaseEvaluation -Scenario $scenario -ExpectedChannel $expectedChannel
        Assert-Condition -Condition ([bool]$activePhase.schema_present) -Message ("Scenario {0} omitted named active-phase evidence." -f $scenarioName) -Failures $failures
        Assert-Condition -Condition ([bool]$activePhase.channel_matches) -Message ("Scenario {0} measured channel '{1}' instead of '{2}'." -f $scenarioName, [string]$activePhase.channel_id, $expectedChannel) -Failures $failures
        Assert-Condition -Condition ([bool]$activePhase.active_at_start) -Message ("Scenario {0} did not enter its named animation phase at the action boundary." -f $scenarioName) -Failures $failures
        Assert-Condition -Condition ([bool]$activePhase.frame_window_passed) -Message ("Scenario {0} retained only {1} consecutive active frames; at least {2} are required before frame p95 is eligible." -f $scenarioName, [int]$activePhase.longest_consecutive_active_frames, [int]$activePhase.minimum_active_frames) -Failures $failures
        Assert-Condition -Condition ([bool]$activePhase.elapsed_window_passed) -Message ("Scenario {0} retained only {1:N3}ms in its named phase; at least {2:N3}ms are required before frame p95 is eligible." -f $scenarioName, [double]$activePhase.active_elapsed_msec, [double]$activePhase.minimum_active_msec) -Failures $failures
        $frameSampleEligible = [bool]$activePhase.passed
    }
    if ($frameSampleEligible) {
        Assert-Condition -Condition ($p95 -le $budget) -Message ("Scenario {0} frame p95 {1:N3}ms exceeded {2:N3}ms." -f $scenarioName, $p95, $budget) -Failures $failures
    }
    $memoryDelta = [Math]::Abs([int64]$scenario.static_memory_bytes.delta)
    Assert-Condition -Condition ($memoryDelta -le $scenarioMemoryDeltaBudgetBytes) -Message ("Scenario {0} memory delta {1:N0} bytes exceeded {2:N0} bytes." -f $scenarioName, $memoryDelta, $scenarioMemoryDeltaBudgetBytes) -Failures $failures
    # Keep each idle timing assertion structurally paired with evidence from
    # the same sample window that scheduler and drawing stayed alive. Absolute
    # counters can be nonzero because of an earlier transition and are not proof.
    if ($Plan -eq "l02" -and $scenarioName.EndsWith("_idle")) {
        $gameId = $scenarioName.Substring(0, $scenarioName.Length - 5)
        if ($l02AnimatedIdleGameIds -notcontains $gameId) { continue }
        $idleEvidence = Get-WebPerfIdleLivenessEvaluation -Scenario $scenario
        Assert-Condition -Condition ([bool]$idleEvidence.schema_present) -Message ("Scenario {0} omitted declared idle FPS, scheduler elapsed, redraw, or draw evidence." -f $scenarioName) -Failures $failures
        Assert-Condition -Condition ([bool]$idleEvidence.cadence_stable) -Message ("Scenario {0} did not retain one positive production-declared idle cadence across the sample (declared {1:N3} FPS)." -f $scenarioName, [double]$idleEvidence.declared_fps) -Failures $failures
        Assert-Condition -Condition ([bool]$idleEvidence.window_complete) -Message ("Scenario {0} sampled only {1}ms of its production scheduler; at {2:N3} FPS at least two intervals ({3}ms) are required." -f $scenarioName, [int]$idleEvidence.scheduler_elapsed_msec, [double]$idleEvidence.declared_fps, [int]$idleEvidence.minimum_window_msec) -Failures $failures
        Assert-Condition -Condition ([bool]$idleEvidence.redraw_cadence_passed) -Message ("Scenario {0} scheduled {1} redraw(s), below the elapsed-time floor {2} for {3}ms at {4:N3} FPS." -f $scenarioName, [int]$idleEvidence.redraw_delta, [int]$idleEvidence.required_redraws, [int]$idleEvidence.scheduler_elapsed_msec, [double]$idleEvidence.declared_fps) -Failures $failures
        Assert-Condition -Condition ([bool]$idleEvidence.paired_draw_passed) -Message ("Scenario {0} had no production canvas draw paired with its same-window scheduler evidence." -f $scenarioName) -Failures $failures
    }
    if ($Plan -eq "l02" -and $scenarioName.EndsWith("_active")) {
        $gameId = $scenarioName.Substring(0, $scenarioName.Length - 7)
        if ($l02ActiveGameIds -notcontains $gameId) { continue }
        $actionEvidence = $scenario.tags.action_evidence
        Assert-Condition -Condition ([bool]$actionEvidence.accepted) -Message ("Scenario {0} measured a rejected/no-op action instead of an accepted action." -f $scenarioName) -Failures $failures
        Assert-Condition -Condition ([bool]$actionEvidence.progressed) -Message ("Scenario {0} accepted no observable game progress." -f $scenarioName) -Failures $failures
        if ($scenarioName -in @("craps_active", "crew_draw_poker_active")) {
            $expectedAction = if ($scenarioName -eq "craps_active") { "roll_craps" } else { "deal" }
            Assert-Condition -Condition ([string]$actionEvidence.action_id -eq $expectedAction) -Message ("Scenario {0} did not dispatch required legal action {1}." -f $scenarioName, $expectedAction) -Failures $failures
        }
    }
}

if ($Plan -eq "coin_pusher") {
    Assert-Condition -Condition ($Browser -eq "chrome") -Message "Coin Pusher Web performance evidence requires the supported Chrome configuration." -Failures $failures
    Assert-Condition -Condition ($Cpu -eq 4) -Message "Coin Pusher Web performance evidence requires CPU throttle rate 4." -Failures $failures
    Assert-Condition -Condition (-not $SkipExport) -Message "Coin Pusher closure evidence requires a fresh Web export; -SkipExport is not accepted." -Failures $failures
    Assert-Condition -Condition (@($reportEnvelope.page_errors).Count -eq 0) -Message "Coin Pusher browser probe captured a page error." -Failures $failures
    Assert-Condition -Condition (@($reportEnvelope.request_failures).Count -eq 0) -Message "Coin Pusher browser probe captured a failed request." -Failures $failures
    Assert-Condition -Condition (@($reportEnvelope.failed_responses).Count -eq 0) -Message "Coin Pusher browser probe captured an HTTP failure response." -Failures $failures
    $startupErrors = @($reportEnvelope.startup_console | Where-Object { [string]$_.type -eq "error" -or [string]$_.classification -eq "error" })
    $unexpectedStartupConsole = @($reportEnvelope.startup_console | Where-Object { [string]$_.classification -ne "expected_audio_autoplay_warning" })
    Assert-Condition -Condition ($startupErrors.Count -eq 0) -Message "Coin Pusher browser probe captured a startup console error." -Failures $failures
    Assert-Condition -Condition ($unexpectedStartupConsole.Count -eq 0) -Message "Coin Pusher browser probe captured an unexpected or unclassified startup warning/error." -Failures $failures
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
    $reducedObservationEvents = @($report.events | Where-Object { [string]$_.id -eq "coin_pusher_reduced_fixture_observation" })
    $reducedSampleBoundaryEvents = @($report.events | Where-Object { [string]$_.id -eq "coin_pusher_reduced_sample_boundary" })
    Assert-Condition -Condition ($reducedFixtureEvents.Count -eq 1) -Message "Coin Pusher report did not contain exactly one reduced-motion fixture reinstall identity event." -Failures $failures
    Assert-Condition -Condition ($reducedObservationEvents.Count -eq 1) -Message "Coin Pusher report did not contain exactly one reduced-motion post-entry observation event." -Failures $failures
    Assert-Condition -Condition ($reducedSampleBoundaryEvents.Count -eq 1) -Message "Coin Pusher report did not contain exactly one reduced-motion sample-boundary event." -Failures $failures
    if ($fixtureEvents.Count -eq 1 -and $reducedFixtureEvents.Count -eq 1) {
        $reducedFixture = $reducedFixtureEvents[0].data
        Assert-Condition -Condition ([string]$reducedFixture.fixture_seed -eq [string]$fixture.fixture_seed -and [string]$reducedFixture.rng_namespace -eq [string]$fixture.rng_namespace -and [string]$reducedFixture.rng_fork -eq [string]$fixture.rng_fork) -Message "Coin Pusher reduced-motion reinstall did not use the identical deterministic fixture identity." -Failures $failures
        Assert-Condition -Condition ([int]$reducedFixture.body_count -eq 300 -and [string]$reducedFixture.variation_id -eq "quarter_falls") -Message "Coin Pusher reduced-motion reinstall did not re-enter the exact 300-body Quarter Falls fixture." -Failures $failures
    }
    if ($reducedObservationEvents.Count -eq 1) {
        $reducedObservation = $reducedObservationEvents[0].data
        Assert-Condition -Condition ([int]$reducedObservation.boundary_body_count -eq 300 -and [int]$reducedObservation.boundary_tray_count -eq 0) -Message "Coin Pusher reduced-motion reinstall boundary was not the exact 300-body fixture." -Failures $failures
        Assert-Condition -Condition ([int]$reducedObservation.liveness_after -gt [int]$reducedObservation.liveness_before) -Message "Coin Pusher reduced-motion reinstall did not preserve live production-clock advancement after identity capture." -Failures $failures
        Assert-Condition -Condition (Test-CoinPusherReinstallClockObservation -Observation $reducedObservation) -Message "Coin Pusher reduced-motion post-entry observation fabricated bodies, lost the live machine or froze its clock." -Failures $failures
    }
    $collectFixtureEvents = @($report.events | Where-Object { [string]$_.id -eq "coin_pusher_collect_fixture_identity" })
    $collectObservationEvents = @($report.events | Where-Object { [string]$_.id -eq "coin_pusher_collect_fixture_observation" })
    $collectSeedEvents = @($report.events | Where-Object { [string]$_.id -eq "coin_pusher_collect_seed" })
    Assert-Condition -Condition ($collectFixtureEvents.Count -eq 1) -Message "Coin Pusher report did not contain exactly one COLLECT fixture reinstall identity event." -Failures $failures
    Assert-Condition -Condition ($collectObservationEvents.Count -eq 1) -Message "Coin Pusher report did not contain exactly one COLLECT post-entry observation event." -Failures $failures
    Assert-Condition -Condition ($collectSeedEvents.Count -eq 1) -Message "Coin Pusher report did not contain exactly one COLLECT conservation seed event." -Failures $failures
    if ($collectFixtureEvents.Count -eq 1) {
        $collectFixture = $collectFixtureEvents[0].data
        Assert-Condition -Condition ([int]$collectFixture.body_count -eq 300 -and [string]$collectFixture.variation_id -eq "quarter_falls") -Message "Coin Pusher COLLECT fixture did not begin from a fresh exact 300-body Quarter Falls fixture." -Failures $failures
    }
    if ($collectObservationEvents.Count -eq 1) {
        $collectObservation = $collectObservationEvents[0].data
        Assert-Condition -Condition ([int]$collectObservation.boundary_body_count -eq 300 -and [int]$collectObservation.boundary_tray_count -eq 0) -Message "Coin Pusher COLLECT reinstall boundary was not the exact 300-body fixture." -Failures $failures
        Assert-Condition -Condition ([int]$collectObservation.liveness_after -gt [int]$collectObservation.liveness_before) -Message "Coin Pusher COLLECT reinstall did not preserve live production-clock advancement after identity capture." -Failures $failures
        Assert-Condition -Condition (Test-CoinPusherReinstallClockObservation -Observation $collectObservation) -Message "Coin Pusher COLLECT post-entry observation fabricated bodies, lost the live machine or froze its clock." -Failures $failures
    }
    if ($collectSeedEvents.Count -eq 1) {
        $collectSeed = $collectSeedEvents[0].data
        Assert-Condition -Condition ([int]$collectSeed.origin_body_count -eq 300 -and [int]$collectSeed.active_body_count -eq 299 -and [int]$collectSeed.tray_count -eq 1 -and [int]$collectSeed.conserved_body_count -eq 300) -Message "Coin Pusher COLLECT seed did not conserve the exact 300-origin fixture as 299 active bodies plus one tray body." -Failures $failures
    }

    if ($scenariosByName.ContainsKey("coin_pusher_idle")) {
        $idle = $scenariosByName["coin_pusher_idle"]
        $idleFrames = [int]$idle.frame_time_ms.count
        $idleDraw = $idle.tags.canvas_after
        # Bind the 1 Hz floor to the reset-scoped production scheduler clock.
        # Scenario duration also contains synchronous pre/post evidence capture
        # outside the sampled process frames and therefore is not this clock.
        $schedulerEvidencePresent = Test-CoinPusherPropertiesPresent -Value $idleDraw -Names @("surface_animation_scheduler_elapsed_msec", "surface_animation_redraw_count")
        Assert-Condition -Condition ($idleFrames -ge 120) -Message "Coin Pusher normal idle sampled fewer than 120 frames." -Failures $failures
        Assert-Condition -Condition $schedulerEvidencePresent -Message "Coin Pusher idle omitted the production scheduler elapsed-time evidence." -Failures $failures
        if ($schedulerEvidencePresent) {
            $requiredRedraws = Get-CoinPusherRequiredIdleRedraws -DurationMsec ([double]$idleDraw.surface_animation_scheduler_elapsed_msec)
            Assert-Condition -Condition (Test-CoinPusherIdleSchedulerEvidence -Counters $idleDraw) -Message ("Coin Pusher idle redraw delta {0} was below the production scheduler floor {1} for {2}ms." -f [int]$idleDraw.surface_animation_redraw_count, $requiredRedraws, [int]$idleDraw.surface_animation_scheduler_elapsed_msec) -Failures $failures
        }
        Assert-Condition -Condition ([int]$idleDraw.draw_sample_count -gt 0) -Message "Coin Pusher normal idle produced no surface draw samples despite required liveness." -Failures $failures
        Assert-Condition -Condition ([double]$idleDraw.draw_p95_ms -le 5.0) -Message ("Coin Pusher idle draw p95 {0:N3}ms exceeded 5.000ms." -f [double]$idleDraw.draw_p95_ms) -Failures $failures
        Assert-Condition -Condition ([int]$idle.tags.solver_liveness_delta -gt 0) -Message "Coin Pusher normal idle solver liveness did not advance." -Failures $failures
        Assert-Condition -Condition (Test-CoinPusherSurfaceConservationBinding -BodyCount ([int]$idle.tags.body_count_before) -TrayCount ([int]$idle.tags.tray_count_before) -Snapshot $idle.tags.conservation_before -ExpectedOrigin 300) -Message "Coin Pusher normal idle did not begin from the exact conserved 300-origin fixture." -Failures $failures
        Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace([string]$idle.tags.solver_backend)) -Message "Coin Pusher normal idle did not identify its solver backend." -Failures $failures
    }

    if ($scenariosByName.ContainsKey("coin_pusher_reduced_motion")) {
        $reduced = $scenariosByName["coin_pusher_reduced_motion"]
        $reducedSchemaPresent = Test-CoinPusherReducedEvidenceSchema -Scenario $reduced
        Assert-Condition -Condition $reducedSchemaPresent -Message "Coin Pusher reduced-motion evidence omitted a required after-state, scheduler or draw field." -Failures $failures
        if ($reducedSchemaPresent) {
            $reducedDraw = $reduced.tags.canvas_after
            Assert-Condition -Condition ([int]$reduced.frame_time_ms.count -ge 120) -Message "Coin Pusher reduced-motion sample contained fewer than 120 frames." -Failures $failures
            Assert-Condition -Condition ([int]$reduced.tags.solver_liveness_delta -gt 0) -Message "Coin Pusher reduced motion froze solver liveness." -Failures $failures
            if ($reducedFixtureEvents.Count -eq 1 -and $reducedSampleBoundaryEvents.Count -eq 1) {
                Assert-Condition -Condition (Test-CoinPusherReducedSampleBoundary -Fixture $reducedFixtureEvents[0].data -Boundary $reducedSampleBoundaryEvents[0].data -ScenarioTags $reduced.tags) -Message "Coin Pusher reduced-motion sample was not linked to the exact-300 reinstall boundary with conserved live setup motion." -Failures $failures
            }
            Assert-Condition -Condition ([int]$reduced.tags.body_count_after -gt 0) -Message "Coin Pusher reduced-motion sample lost the production body surface." -Failures $failures
            Assert-Condition -Condition (Test-CoinPusherSurfaceConservationBinding -BodyCount ([int]$reduced.tags.body_count_after) -TrayCount ([int]$reduced.tags.tray_count_after) -Snapshot $reduced.tags.conservation_after -ExpectedOrigin 300) -Message "Coin Pusher reduced-motion after-state did not bind its surface counts to every conserved production outcome channel." -Failures $failures
            Assert-Condition -Condition ([int]$reduced.tags.redraw_delta -eq 0 -and (-not [bool]$reducedDraw.surface_animation_liveness_active)) -Message "Coin Pusher reduced motion unexpectedly advanced the presentation-animation scheduler." -Failures $failures
            Assert-Condition -Condition ([int]$reducedDraw.draw_sample_count -gt 0) -Message "Coin Pusher reduced motion recorded no canvas draw sample." -Failures $failures
            Assert-Condition -Condition ([double]$reducedDraw.draw_p95_ms -le 5.0) -Message ("Coin Pusher reduced-motion draw p95 {0:N3}ms exceeded 5.000ms." -f [double]$reducedDraw.draw_p95_ms) -Failures $failures
        }
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
        Assert-Condition -Condition ([int]$collect.body_count_before + [int]$collect.tray_count_before -eq 300) -Message "Web COLLECT action did not execute from the exact 300-origin conserved fixture." -Failures $failures
        Assert-Condition -Condition ([int]$collect.tray_count_before -eq 1 -and [int]$collect.tray_value_before -eq 3) -Message "Web COLLECT did not begin from the meaningful seeded tray result." -Failures $failures
        Assert-Condition -Condition ([int]$collect.tray_count_at_accept -eq 0 -and [int]$collect.tray_value_at_accept -eq 0) -Message "Accepted Web COLLECT did not empty the seeded tray at action completion." -Failures $failures
        $postCollectAccounting = Get-CoinPusherPostCollectAccounting -Tags $collect
        Assert-Condition -Condition ([bool]$postCollectAccounting.valid) -Message "Web COLLECT post-action window did not account later tray results as exits from the live body set." -Failures $failures
        Assert-Condition -Condition ([int]$collect.bankroll_after -eq [int]$collect.bankroll_before + 3) -Message "Accepted Web COLLECT did not credit the seeded tray value." -Failures $failures
        Assert-Condition -Condition ([int]$collect.story_entries_after -eq [int]$collect.story_entries_before + 1) -Message "Accepted Web COLLECT did not add its production story entry." -Failures $failures
    }
}

if ($Plan -eq "secure_entropy") {
    Assert-Condition -Condition (-not $SkipExport) -Message "Secure entropy closure evidence requires a fresh Web export; -SkipExport is not accepted." -Failures $failures
    Assert-Condition -Condition (@($reportEnvelope.page_errors).Count -eq 0) -Message "Secure entropy browser probe captured a page error." -Failures $failures
    Assert-Condition -Condition (@($reportEnvelope.request_failures).Count -eq 0) -Message "Secure entropy browser probe captured a failed request." -Failures $failures
    Assert-Condition -Condition (@($reportEnvelope.failed_responses).Count -eq 0) -Message "Secure entropy browser probe captured an HTTP failure response." -Failures $failures
    $startupErrors = @($reportEnvelope.startup_console | Where-Object { [string]$_.type -eq "error" -or [string]$_.classification -eq "error" })
    $unexpectedStartupConsole = @($reportEnvelope.startup_console | Where-Object { [string]$_.classification -ne "expected_audio_autoplay_warning" })
    Assert-Condition -Condition ($startupErrors.Count -eq 0) -Message "Secure entropy browser probe captured a startup console error." -Failures $failures
    Assert-Condition -Condition ($unexpectedStartupConsole.Count -eq 0) -Message "Secure entropy browser probe captured an unexpected or unclassified startup warning/error." -Failures $failures
    Assert-Condition -Condition ([string]$report.build_identity.source_commit -eq $sourceCommit) -Message "Secure entropy runtime source commit identity did not match the exported source commit." -Failures $failures
    Assert-Condition -Condition ([string]$report.build_identity.export_sha256 -eq $exportSha256) -Message "Secure entropy runtime Web export identity did not match the served export." -Failures $failures
    $contractEvents = @($report.events | Where-Object { [string]$_.id -eq "secure_entropy_contract" })
    Assert-Condition -Condition ($contractEvents.Count -eq 1) -Message "Secure entropy report did not contain exactly one contract event." -Failures $failures
    if ($contractEvents.Count -eq 1) {
        $contract = $contractEvents[0].data
        Assert-Condition -Condition ([bool]$contract.passed) -Message "Secure entropy Web contract did not pass." -Failures $failures
        Assert-Condition -Condition ([string]$contract.entropy_provider -eq "godot_crypto_mbedtls") -Message "Web contract did not use the pinned Godot mbedTLS crypto provider." -Failures $failures
        Assert-Condition -Condition ([bool]$contract.exact_lengths -and [bool]$contract.nonrepeating) -Message "Web entropy requests were short or repeated." -Failures $failures
        Assert-Condition -Condition ([bool]$contract.authority_id_valid) -Message "Web entropy did not mint a valid authority id." -Failures $failures
        Assert-Condition -Condition ([int]$contract.capsule_bytes -eq 65584 -and [bool]$contract.fixed_width -and [bool]$contract.distinct_capsules) -Message "Web capsules were not fixed-width and independently randomized." -Failures $failures
        Assert-Condition -Condition ([bool]$contract.aes_round_trip) -Message "AESContext failed the exported Web capsule round-trip." -Failures $failures
        Assert-Condition -Condition ([bool]$contract.hmac_tamper_rejected) -Message "HMACContext did not reject the exported Web tamper probe." -Failures $failures
        Assert-Condition -Condition ([bool]$contract.privacy_preserved) -Message "Exported Web capsule exposed its canonical private payload." -Failures $failures
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
    coin_pusher_stage_diagnostic = [bool]$CoinPusherStageDiagnostic
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
    launch_options = $reportEnvelope.launch_options
    cold_cache = [bool]$reportEnvelope.cold_cache
    evidence_profile = $EvidenceProfile
    cache_mode = $CacheMode
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
