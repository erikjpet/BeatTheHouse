param(
    [ValidateRange(1, 512)]
    [int]$SeedsPerPlaystyle = 64,
    [ValidateRange(8, 512)]
    [int]$MaxActions = 208,
    [ValidateRange(1, 8)]
    [int]$WorkerCount = 4,
    [string]$SeedPrefix = "BALANCE06-1-FINAL",
    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "foundation_systems_shards.ps1")
$styles = @(
    "control_crew_ignoring", "pure_gambler", "crew_maximizer",
    "numbers_specialist", "coin_pusher_grinder", "cheater",
    "heist_rusher", "mixed_opportunist"
)

if (-not $OutDir) {
    $OutDir = Join-Path $projectRoot ".tmp\balance06_1_follow_on\distribution_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
}
$OutDir = [IO.Path]::GetFullPath($OutDir)
$rootPrefix = [IO.Path]::GetFullPath($projectRoot)
if (-not $rootPrefix.EndsWith([IO.Path]::DirectorySeparatorChar)) { $rootPrefix += [IO.Path]::DirectorySeparatorChar }
if (-not $OutDir.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutDir must remain inside the project worktree."
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
if (Get-ChildItem -LiteralPath $OutDir -Force | Select-Object -First 1) {
    throw "OutDir must be new and empty; evidence is never overwritten."
}

$dirty = @(git -C $projectRoot status --porcelain --untracked-files=no)
if ($dirty.Count -ne 0) { throw "Tracked tree must be clean before freezing a distribution." }
$head = (git -C $projectRoot rev-parse HEAD).Trim()
$tree = (git -C $projectRoot rev-parse "HEAD^{tree}").Trim()
$godot = $env:GODOT_BIN
if (-not $godot) { $godot = "D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe" }
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) { throw "Godot console executable not found: $godot" }
$godotWorker = [IO.Path]::GetFullPath($godot)
if ($godotWorker.EndsWith("_console.exe", [StringComparison]::OrdinalIgnoreCase)) {
    $godotWorker = $godotWorker.Substring(0, $godotWorker.Length - "_console.exe".Length) + ".exe"
}
if (-not (Test-Path -LiteralPath $godotWorker -PathType Leaf)) { throw "Godot worker executable not found: $godotWorker" }

$inputPaths = @(
    "tools/cross_economy_audit.gd", "tools/cross_economy_audit.ps1",
    "tools/cross_economy_audit_shards.ps1", "tools/foundation_systems_shards.ps1",
    "data/economy/content06_1_audit.json",
    "data/games/games.json", "data/crew/jobs.json", "data/crew/plays.json",
    "data/crew/numbers.json", "data/crew/heist.json", "data/items/items.json",
    "data/services/services.json", "data/debt/lenders.json", "data/travel/routes.json",
    "data/events/events.json"
)
$inputs = [ordered]@{}
foreach ($path in $inputPaths) {
    $inputs[$path] = (git -C $projectRoot rev-parse "HEAD:$path").Trim()
}
$policyHash = $inputs["tools/cross_economy_audit.gd"]
$inputJson = $inputs | ConvertTo-Json -Depth 4 -Compress
$inputHash = ([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($inputJson)) | ForEach-Object { $_.ToString("x2") }) -join ""

$jobs = [Collections.Generic.List[object]]::new()
$shardProjectsRoot = Join-Path $OutDir "shard_projects"
New-Item -ItemType Directory -Path $shardProjectsRoot -Force | Out-Null
foreach ($style in $styles) {
    $stem = $style
    $privateRoot = Join-Path $shardProjectsRoot $style
    New-Item -ItemType Directory -Path $privateRoot -Force | Out-Null
    foreach ($file in Get-ChildItem -LiteralPath $projectRoot -File -Force) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $privateRoot $file.Name) -Force
    }
    foreach ($directoryName in @(".agents", "addons", "assets", "branding", "data", "docs", "scenes", "scripts", "tools")) {
        $sourceDirectory = Join-Path $projectRoot $directoryName
        if (Test-Path -LiteralPath $sourceDirectory) {
            if (-not (Test-FoundationJunctionTargetSafe -ProjectRoot $privateRoot -TargetPath $sourceDirectory)) { throw "Unsafe shard junction target: $sourceDirectory" }
            New-Item -ItemType Junction -Path (Join-Path $privateRoot $directoryName) -Target $sourceDirectory | Out-Null
        }
    }
    $privateCache = Join-Path $privateRoot ".godot"
    New-Item -ItemType Directory -Path $privateCache -Force | Out-Null
    foreach ($cacheFile in @("global_script_class_cache.cfg", "uid_cache.bin")) {
        Copy-Item -LiteralPath (Join-Path $projectRoot ".godot\$cacheFile") -Destination (Join-Path $privateCache $cacheFile) -Force
    }
    Copy-Item -LiteralPath (Join-Path $projectRoot ".godot\extension_list.cfg") -Destination (Join-Path $privateCache "extension_list.cfg") -Force
    $jobs.Add([pscustomobject]@{
        Style = $style
        ProjectRoot = $privateRoot
        Json = Join-Path $privateRoot "$stem.json"
        Stdout = Join-Path $OutDir "$stem.stdout.txt"
        Stderr = Join-Path $OutDir "$stem.stderr.txt"
        Process = $null
        ExitCode = $null
        DurationSec = 0.0
        Started = $null
    })
}

$pending = [Collections.Generic.Queue[object]]::new()
foreach ($job in $jobs) { $pending.Enqueue($job) }
$running = [Collections.Generic.List[object]]::new()
$startedAt = Get-Date
function Join-ProcessArguments([string[]]$Arguments) {
    return (($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '([\\]*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"' } else { $_ }
    }) -join ' ')
}
while ($pending.Count -gt 0 -or $running.Count -gt 0) {
    for ($index = $running.Count - 1; $index -ge 0; $index--) {
        $job = $running[$index]
        if ($job.Process.HasExited) {
            $job.Process.WaitForExit()
            $job.Process.Refresh()
            $job.ExitCode = $job.Process.ExitCode
            [IO.File]::WriteAllText($job.Stdout, $job.Process.StandardOutput.ReadToEnd(), [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText($job.Stderr, $job.Process.StandardError.ReadToEnd(), [Text.UTF8Encoding]::new($false))
            $job.DurationSec = ((Get-Date) - $job.Started).TotalSeconds
            $job.Process.Dispose()
            $running.RemoveAt($index)
            Write-Host "BALANCE_SHARD_DONE style=$($job.Style) exit=$($job.ExitCode) duration_sec=$([math]::Round($job.DurationSec, 3))"
            if ($job.ExitCode -ne 0) { throw "Distribution shard failed: $($job.Style)" }
        }
    }
    while ($pending.Count -gt 0 -and $running.Count -lt $WorkerCount) {
        $job = $pending.Dequeue()
        $args = @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $job.ProjectRoot "tools\cross_economy_audit.ps1"),
            "-SeedsPerPlaystyle", "$SeedsPerPlaystyle", "-SeedStart", "1",
            "-MaxActions", "$MaxActions", "-SeedPrefix", $SeedPrefix,
            "-Playstyle", $job.Style, "-BuildRef", $head, "-Output", "res://$($job.Style).json"
        )
        $job.Started = Get-Date
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = (Get-Command powershell.exe).Source
        $startInfo.Arguments = Join-ProcessArguments $args
        $startInfo.WorkingDirectory = $job.ProjectRoot
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $job.Process = [Diagnostics.Process]::new()
        $job.Process.StartInfo = $startInfo
        if (-not $job.Process.Start()) { throw "Could not launch distribution shard: $($job.Style)" }
        $running.Add($job)
        Write-Host "BALANCE_SHARD_START style=$($job.Style)"
    }
    if ($running.Count -gt 0) { Start-Sleep -Milliseconds 500 }
}

function Get-Distribution([double[]]$Values) {
    if ($Values.Count -eq 0) { return [ordered]@{ n = 0 } }
    $sorted = @($Values | Sort-Object)
    $mean = ($sorted | Measure-Object -Average).Average
    $sumSquares = 0.0
    foreach ($value in $sorted) { $sumSquares += [math]::Pow($value - $mean, 2) }
    $sd = [math]::Sqrt($sumSquares / [math]::Max(1, $sorted.Count - 1))
    $margin = 1.96 * $sd / [math]::Sqrt($sorted.Count)
    function Percentile([double]$Fraction) {
        $position = $Fraction * ($sorted.Count - 1)
        $low = [math]::Floor($position)
        $high = [math]::Ceiling($position)
        if ($low -eq $high) { return $sorted[$low] }
        return $sorted[$low] + (($position - $low) * ($sorted[$high] - $sorted[$low]))
    }
    return [ordered]@{
        n = $sorted.Count; min = $sorted[0]; p05 = (Percentile 0.05);
        p25 = (Percentile 0.25); median = (Percentile 0.5); p75 = (Percentile 0.75);
        p95 = (Percentile 0.95); max = $sorted[-1]; mean = $mean;
        sample_standard_deviation = $sd; mean_ci95_lower = $mean - $margin;
        mean_ci95_upper = $mean + $margin
    }
}

$allRuns = [Collections.Generic.List[object]]::new()
$shardIndex = [Collections.Generic.List[object]]::new()
$styleSummaries = [ordered]@{}
foreach ($job in $jobs) {
    if (-not (Test-Path -LiteralPath $job.Json)) { throw "Missing shard report: $($job.Style)" }
    $report = Get-Content -LiteralPath $job.Json -Raw | ConvertFrom-Json
    if (-not $report.passed -or @($report.failures).Count -ne 0 -or @($report.warnings).Count -ne 0) { throw "Shard report is not W0/H0 green: $($job.Style)" }
    if ([string]$report.build_ref -ne $head -or [string]$report.playstyle_filter -ne $job.Style -or [int]$report.seed_start -ne 1 -or [int]$report.run_count -ne $SeedsPerPlaystyle) { throw "Shard provenance mismatch: $($job.Style)" }
    foreach ($run in @($report.runs)) { $allRuns.Add($run) }
    $sha = (Get-FileHash -LiteralPath $job.Json -Algorithm SHA256).Hash.ToLowerInvariant()
    $shardIndex.Add([ordered]@{ style = $job.Style; seed_start = 1; seed_count = $SeedsPerPlaystyle; duration_sec = $job.DurationSec; bytes = (Get-Item $job.Json).Length; sha256 = $sha; path = $job.Json })
    $styleSummaries[$job.Style] = @($report.aggregate.playstyles)[0]
}

$expectedSeeds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($style in $styles) { for ($i = 1; $i -le $SeedsPerPlaystyle; $i++) { $null = $expectedSeeds.Add("$SeedPrefix-$style-$('{0:D3}' -f $i)") } }
$actualSeeds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($run in $allRuns) { if (-not $actualSeeds.Add([string]$run.seed)) { throw "Duplicate run seed: $($run.seed)" } }
if (-not $actualSeeds.SetEquals($expectedSeeds)) { throw "Distribution seed coverage has a gap or unexpected seed." }

$numericKeys = @("final_bankroll", "liquid_cash", "inventory_value", "debt_balance", "net_position", "actions", "final_heat", "peak_heat", "peak_debt", "bankroll_reconciliation_delta")
$overall = [ordered]@{}
foreach ($key in $numericKeys) { $overall[$key] = Get-Distribution @($allRuns | ForEach-Object { [double]$_.$key }) }
$terminalCauses = [ordered]@{}
$victoryRoutes = [ordered]@{}
$opportunities = [ordered]@{}
foreach ($run in $allRuns) {
    $cause = if ([bool]$run.censored) { [string]$run.stopped_reason } elseif ([bool]$run.won) { "victory" } elseif ([string]$run.failure_reason) { [string]$run.failure_reason } else { "terminal_other" }
    $terminalCauses[$cause] = [int]$terminalCauses[$cause] + 1
    $route = if ([string]$run.victory_route) { [string]$run.victory_route } else { "none" }
    $victoryRoutes[$route] = [int]$victoryRoutes[$route] + 1
    foreach ($systemProperty in $run.opportunities.PSObject.Properties) {
        if (-not $opportunities.Contains($systemProperty.Name)) { $opportunities[$systemProperty.Name] = [ordered]@{} }
        foreach ($counterProperty in $systemProperty.Value.PSObject.Properties) {
            $opportunities[$systemProperty.Name][$counterProperty.Name] = [int]$opportunities[$systemProperty.Name][$counterProperty.Name] + [int]$counterProperty.Value
        }
    }
}

$summary = [ordered]@{
    schema = "balance06_1_cross_economy_distribution_v2"
    passed = $true
    exact_head = $head
    exact_tree = $tree
    input_manifest_sha256 = $inputHash
    policy_blob = $policyHash
    seed_prefix = $SeedPrefix
    seeds_per_playstyle = $SeedsPerPlaystyle
    max_actions = $MaxActions
    run_count = $allRuns.Count
    expected_run_count = $styles.Count * $SeedsPerPlaystyle
    warnings = @()
    failures = @()
    overall = $overall
    terminal_causes = $terminalCauses
    victory_routes = $victoryRoutes
    opportunity_denominators = $opportunities
    playstyles = $styleSummaries
    shards = $shardIndex
    elapsed_seconds = ((Get-Date) - $startedAt).TotalSeconds
}
$summaryPath = Join-Path $OutDir "aggregate_summary.json"
$summary | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $summaryPath -Encoding utf8
$custody = [ordered]@{
    schema = "balance06_1_cross_economy_custody_v1"
    exact_head = $head; exact_tree = $tree; generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    engine_path = [IO.Path]::GetFullPath($godot); engine_sha256 = (Get-FileHash -LiteralPath $godot -Algorithm SHA256).Hash.ToLowerInvariant()
    worker_path = $godotWorker; worker_sha256 = (Get-FileHash -LiteralPath $godotWorker -Algorithm SHA256).Hash.ToLowerInvariant()
    os = [Environment]::OSVersion.VersionString; processor_count = [Environment]::ProcessorCount; worker_count = $WorkerCount
    input_manifest_sha256 = $inputHash; inputs = $inputs; policy_blob = $policyHash
    aggregate_summary = [ordered]@{ path = $summaryPath; bytes = (Get-Item $summaryPath).Length; sha256 = (Get-FileHash -LiteralPath $summaryPath -Algorithm SHA256).Hash.ToLowerInvariant() }
    shards = $shardIndex
}
$custodyPath = Join-Path $OutDir "custody_manifest.json"
$custody | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $custodyPath -Encoding utf8
Write-Host "CROSS_ECONOMY_SHARDS_PASS runs=$($allRuns.Count) output=$summaryPath"
