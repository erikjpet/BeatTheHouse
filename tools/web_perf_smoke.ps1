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
    [switch]$SkipExport,
    [switch]$Headed
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    throw "Node.js was not found on PATH. The web perf smoke uses tools/l02_web_perf_probe.mjs."
}

$frameP95BudgetsMs = @{
    "menu_idle" = 180.0
    "start_menu_idle" = 20.0
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
$readyBudgetMs = 20000
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

if (-not $SkipExport) {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "export_itch.ps1") -Target web
    if ($LASTEXITCODE -ne 0) {
        throw "Web export failed with exit code $LASTEXITCODE."
    }
}

$outPath = Join-Path $root $Out
$outDir = Split-Path -Parent $outPath
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
if (Test-Path -LiteralPath $outPath) {
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
    $url = "http://127.0.0.1:$Port/?bth_perf=1&bth_perf_plan=l02&bth_perf_auto_quit=1&bth_perf_frames=$Frames&bth_perf_active_frames=$ActiveFrames&bth_perf_memory_seconds=$MemorySeconds"
    $profile = Join-Path $root (".tmp/web_perf_smoke/{0}_profile" -f $Browser)
    $probeArgs = @(
        (Join-Path $PSScriptRoot "l02_web_perf_probe.mjs"),
        "--browser=$Browser",
        "--headless=$headless",
        "--cpu=$Cpu",
        "--timeout-ms=$TimeoutMs",
        "--url=$url",
        "--out=$outPath",
        "--profile=$profile",
        "--cold-cache=true"
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
    $readyWall = [int]$reportEnvelope.ready.wall_msec
}
Assert-Condition -Condition ($readyWall -gt 0) -Message "BTH_PERF_READY was not captured." -Failures $failures
Assert-Condition -Condition ($readyWall -le $readyBudgetMs) -Message ("Web ready wall time {0}ms exceeded {1}ms." -f $readyWall, $readyBudgetMs) -Failures $failures

$overheadAvg = [double]$report.telemetry_overhead.avg_ms
Assert-Condition -Condition ($overheadAvg -le $telemetryOverheadAvgBudgetMs) -Message ("Telemetry overhead avg {0:N4}ms exceeded {1:N4}ms." -f $overheadAvg, $telemetryOverheadAvgBudgetMs) -Failures $failures

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

$summary = [ordered]@{
    tool = "web_perf_smoke"
    passed = ($failures.Count -eq 0)
    browser = $Browser
    cpu_throttle_rate = $Cpu
    frames = $Frames
    active_frames = $ActiveFrames
    memory_seconds = $MemorySeconds
    ready_wall_msec = $readyWall
    ready_budget_msec = $readyBudgetMs
    telemetry_overhead_avg_ms = $overheadAvg
    telemetry_overhead_avg_budget_ms = $telemetryOverheadAvgBudgetMs
    scenario_frame_p95_budgets_ms = $frameP95BudgetsMs
    scenario_memory_delta_budget_bytes = $scenarioMemoryDeltaBudgetBytes
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
