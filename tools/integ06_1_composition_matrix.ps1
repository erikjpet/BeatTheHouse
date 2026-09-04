param(
    [Parameter(Mandatory = $true)]
    [string]$CandidateCommit,
    [Parameter(Mandatory = $true)]
    [string]$ProfilePath,
    [Parameter(Mandatory = $true)]
    [string]$EvidenceProfile,
    [Parameter(Mandatory = $true)]
    [string]$OutDir,
    [string]$GodotPath = "",
    [ValidateRange(1, 4096)]
    [int]$SeedCount = 512,
    [ValidateRange(1, 64)]
    [int]$ShardCount = 8,
    [ValidateRange(10, 600)]
    [int]$CaseTimeoutSeconds = 120,
    [switch]$RequireGodot
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$head = (& git -C $root rev-parse HEAD).Trim()
$candidate = (& git -C $root rev-parse "$CandidateCommit^{commit}").Trim()
if ($head -cne $candidate) { throw "HEAD $head does not equal CandidateCommit $candidate." }
if (& git -C $root status --porcelain --untracked-files=no) { throw "Tracked worktree changes make immutable candidate evidence invalid." }
$candidateTree = (& git -C $root rev-parse "HEAD^{tree}").Trim()

$resolvedProfile = (Resolve-Path -LiteralPath $ProfilePath).Path
$profileHash = (Get-FileHash -LiteralPath $resolvedProfile -Algorithm SHA256).Hash.ToLowerInvariant()
$out = [IO.Path]::GetFullPath((Join-Path $root $OutDir))
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $root ".tmp"))
if (-not $out.StartsWith($allowedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutDir must resolve below the repository .tmp directory: $out"
}
if (Test-Path -LiteralPath $out) { throw "OutDir already exists; evidence is immutable: $out" }

if (-not $GodotPath) { $GodotPath = $env:GODOT_BIN }
if (-not $GodotPath) {
    $common = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
    $candidateGodot = Join-Path (Split-Path -Parent $common) ".tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe"
    if (Test-Path -LiteralPath $candidateGodot -PathType Leaf) { $GodotPath = $candidateGodot }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    if ($RequireGodot) { throw "Godot console was not found; pass -GodotPath or set GODOT_BIN." }
    Write-Host "INTEG06_1_COMPOSITION_MATRIX NOT RUN (Godot unavailable)."
    exit 0
}
New-Item -ItemType Directory -Path $out | Out-Null

$probePath = Join-Path $root "tools\wave_b_composition_probe.gd"
$toolHash = (Get-FileHash -LiteralPath $probePath -Algorithm SHA256).Hash.ToLowerInvariant()
$orders = @(
    "save_load_replay_abandon",
    "replay_save_load_abandon",
    "travel_return_save_load_abandon",
    "save_load_abandon_travel_return",
    "expire_save_load_travel_return"
)

# Eligibility is computed from shipped production data. A caller cannot add a
# venue or layer to the matrix. Punchline is additionally required in all three
# authored layers by the integ06_1 contract even though its public club layer is
# intentionally not a maximal game floor.
$archetypes = Get-Content -LiteralPath (Join-Path $root "data\environments\archetypes.json") -Raw | ConvertFrom-Json
$scenarioCatalog = Get-Content -LiteralPath (Join-Path $root "data\environments\scenarios.json") -Raw | ConvertFrom-Json
$eligibleArchetypes = @()
foreach ($archetype in $archetypes) {
    $id = [string]$archetype.id
    $hasScenario = $null -ne $scenarioCatalog.PSObject.Properties[$id]
    if ($hasScenario -and @($archetype.game_pool).Count -gt 0 -and @($archetype.event_pool).Count -gt 0 -and @($archetype.service_pool).Count -gt 0) {
        $eligibleArchetypes += $id
    }
}
$punchlineId = "small_underground_casino"
$requiredTargets = @($eligibleArchetypes + $punchlineId | Sort-Object -Unique)
if ($requiredTargets.Count -lt 2) { throw "Production data yielded an implausible composition eligibility set." }

function Convert-ToResourcePath {
    param([string]$AbsolutePath)
    $rootPrefix = $root
    if (-not $rootPrefix.EndsWith([IO.Path]::DirectorySeparatorChar)) { $rootPrefix += [IO.Path]::DirectorySeparatorChar }
    $relative = [Uri]::UnescapeDataString(([Uri]$rootPrefix).MakeRelativeUri([Uri]$AbsolutePath).ToString())
    return "res://$($relative -replace '\\', '/')"
}

function Get-RelativeEvidencePath {
    param([string]$AbsolutePath)
    $rootPrefix = $out
    if (-not $rootPrefix.EndsWith([IO.Path]::DirectorySeparatorChar)) { $rootPrefix += [IO.Path]::DirectorySeparatorChar }
    return ([Uri]::UnescapeDataString(([Uri]$rootPrefix).MakeRelativeUri([Uri]$AbsolutePath).ToString()) -replace '\\', '/')
}

function Get-TextSha256 {
    param([string]$Value)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        return (($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)) | ForEach-Object { $_.ToString("x2") }) -join '')
    }
    finally { $algorithm.Dispose() }
}

function Invoke-CompositionCase {
    param(
        [string]$Seed,
        [string]$OrderId,
        [string]$LayerId,
        [string]$CaseRoot,
        [int]$ShardIndex,
        [ValidateSet("delivery-matrix", "delivery-discovery")]
        [string]$Mode = "delivery-matrix"
    )
    New-Item -ItemType Directory -Force -Path $CaseRoot | Out-Null
    $reportPath = Join-Path $CaseRoot "report.json"
    $stdoutPath = Join-Path $CaseRoot "stdout.txt"
    $stderrPath = Join-Path $CaseRoot "stderr.txt"
    $dataRoot = Join-Path $CaseRoot "user_data"
    New-Item -ItemType Directory -Force -Path $dataRoot | Out-Null
    $args = @(
        "--headless", "--audio-driver", "Dummy", "--path", $root,
        "--script", "res://tools/wave_b_composition_probe.gd", "--",
        "--mode=$Mode", "--seed=$Seed", "--order-id=$OrderId",
        "--candidate-commit=$candidate", "--candidate-tree=$candidateTree",
        "--tool-source-sha256=$toolHash", "--shard-index=$ShardIndex", "--shard-count=$ShardCount",
        "--evidence-profile=$EvidenceProfile", "--profile-path=$resolvedProfile", "--profile-sha256=$profileHash",
        "--out=$(Convert-ToResourcePath $reportPath)"
    )
    if ($LayerId) { $args += "--target-layer-id=$LayerId" }
    $names = @("BTH_DISTRIBUTION_BUILD", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_USER_SETTINGS_PATH")
    $prior = @{}
    foreach ($name in $names) { $prior[$name] = [Environment]::GetEnvironmentVariable($name, "Process") }
    try {
        $env:BTH_DISTRIBUTION_BUILD = "1"
        $env:BTH_DISTRIBUTION_DATA_ROOT = $dataRoot
        $env:BTH_USER_SETTINGS_PATH = Join-Path $dataRoot "settings.json"
        $process = Start-Process -FilePath $GodotPath -ArgumentList $args -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru -WindowStyle Hidden
        $null = $process.Handle
        if (-not $process.WaitForExit($CaseTimeoutSeconds * 1000)) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            return [pscustomobject]@{ exit_code = -1; report = $null; timed_out = $true; path = $reportPath }
        }
        $process.WaitForExit()
        $process.Refresh()
    }
    finally {
        foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $prior[$name], "Process") }
    }
    $report = $null
    if (Test-Path -LiteralPath $reportPath -PathType Leaf) { $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json }
    return [pscustomobject]@{ exit_code = $process.ExitCode; report = $report; timed_out = $false; path = $reportPath }
}

$discoveryRoot = Join-Path $out "discovery"
New-Item -ItemType Directory -Path $discoveryRoot | Out-Null
$seedByTarget = @{}
for ($index = 0; $index -lt $SeedCount -and $seedByTarget.Count -lt $requiredTargets.Count; $index++) {
    $seed = "INTEG06-1-COMPOSITION-{0:D4}" -f $index
    $caseRoot = Join-Path $discoveryRoot ("seed_{0:D4}" -f $index)
    $result = Invoke-CompositionCase -Seed $seed -OrderId $orders[0] -LayerId "" -CaseRoot $caseRoot -ShardIndex ($index % $ShardCount) -Mode "delivery-discovery"
    if ($null -eq $result.report -or [string]$result.report.schema -cne "beat_the_house.integ06_1_composition_discovery/v1") { continue }
    $archetypeId = [string]$result.report.target_archetype
    if ($requiredTargets -contains $archetypeId -and -not $seedByTarget.ContainsKey($archetypeId)) {
        $seedByTarget[$archetypeId] = $seed
    }
}
$backRoomSeed = ""
for ($index = 0; $index -lt $SeedCount -and -not $backRoomSeed; $index++) {
    $seed = "INTEG06-1-COMPOSITION-L3-{0:D4}" -f $index
    $caseRoot = Join-Path $discoveryRoot ("l3_seed_{0:D4}" -f $index)
    $result = Invoke-CompositionCase -Seed $seed -OrderId $orders[0] -LayerId "back_room" -CaseRoot $caseRoot -ShardIndex ($index % $ShardCount) -Mode "delivery-discovery"
    if ($null -ne $result.report -and [string]$result.report.schema -ceq "beat_the_house.integ06_1_composition_discovery/v1" -and [string]$result.report.target_archetype -ceq $punchlineId) {
        $backRoomSeed = $seed
    }
}

$cases = @()
foreach ($archetypeId in $requiredTargets) {
    if (-not $seedByTarget.ContainsKey($archetypeId)) { continue }
    $layers = if ($archetypeId -ceq $punchlineId) { @("club", "casino", "back_room") } else { @("") }
    foreach ($layerId in $layers) {
        if ($archetypeId -ceq $punchlineId -and $layerId -ceq "back_room" -and -not $backRoomSeed) { continue }
        foreach ($orderId in $orders) {
            $cases += [pscustomobject]@{
                id = "$archetypeId|$layerId|$orderId"
                archetype_id = $archetypeId
                layer_id = $layerId
                order_id = $orderId
                seed = if ($archetypeId -ceq $punchlineId -and $layerId -ceq "back_room") { $backRoomSeed } else { [string]$seedByTarget[$archetypeId] }
            }
        }
    }
}

$rowsByShard = @{}
$failuresByShard = @{}
$artifactsByShard = @{}
for ($shardIndex = 0; $shardIndex -lt $ShardCount; $shardIndex++) {
    $rowsByShard[$shardIndex] = @()
    $failuresByShard[$shardIndex] = @()
    $artifactsByShard[$shardIndex] = @()
}
for ($caseIndex = 0; $caseIndex -lt $cases.Count; $caseIndex++) {
    $case = $cases[$caseIndex]
    $shardIndex = $caseIndex % $ShardCount
    $safeId = ([string]$case.id) -replace '[^A-Za-z0-9_.-]', '_'
    $caseRoot = Join-Path $out "shard_$shardIndex\cases\$safeId"
    $result = Invoke-CompositionCase -Seed ([string]$case.seed) -OrderId ([string]$case.order_id) -LayerId ([string]$case.layer_id) -CaseRoot $caseRoot -ShardIndex $shardIndex
    if ($null -eq $result.report -or @($result.report.rows).Count -ne 1) {
        $failuresByShard[$shardIndex] += "$($case.id): no valid report (exit $($result.exit_code), timed_out=$($result.timed_out))"
        continue
    }
    $row = @($result.report.rows)[0]
    if ([string]$row.archetype_id -cne [string]$case.archetype_id -or [string]$row.layer_id -cne [string]$case.layer_id -or [string]$row.order_id -cne [string]$case.order_id) {
        $failuresByShard[$shardIndex] += "$($case.id): production replay selected a different target/layer/order"
        continue
    }
    $row | Add-Member -NotePropertyName case_id -NotePropertyValue ([string]$case.id) -Force
    $rowsByShard[$shardIndex] += $row
    if (-not $result.report.passed -or -not $row.passed) { $failuresByShard[$shardIndex] += "$($case.id): semantic composition failed" }
    $artifactPath = Get-RelativeEvidencePath ([string]$result.path)
    $artifactsByShard[$shardIndex] += [ordered]@{
        path = $artifactPath
        sha256 = (Get-FileHash -LiteralPath ([string]$result.path) -Algorithm SHA256).Hash.ToLowerInvariant()
        size_bytes = (Get-Item -LiteralPath ([string]$result.path).Length)
    }
}

$shardReports = @()
for ($shardIndex = 0; $shardIndex -lt $ShardCount; $shardIndex++) {
    $shardRoot = Join-Path $out "shard_$shardIndex"
    New-Item -ItemType Directory -Force -Path $shardRoot | Out-Null
    $shardRows = @($rowsByShard[$shardIndex])
    $shardFailures = @($failuresByShard[$shardIndex])
    $seedIds = @($shardRows | ForEach-Object { [string]$_.seed } | Sort-Object -Unique)
    $stateBytes = [long](($shardRows | ForEach-Object { [long]$_.PSObject.Properties['state_bytes'].Value } | Measure-Object -Sum).Sum)
    $orphanCount = [long](($shardRows | ForEach-Object { [long]$_.orphan_count } | Measure-Object -Sum).Sum)
    $shardReport = [ordered]@{
        schema = "beat_the_house.integ06_1_composition_shard/v1"
        version = 1
        candidate_commit = $candidate
        candidate_tree = $candidateTree
        tool_source_sha256 = $toolHash
        profile = [ordered]@{ evidence_profile = $EvidenceProfile; path = $resolvedProfile; sha256 = $profileHash }
        shard = [ordered]@{ index = $shardIndex; count = $ShardCount; seed_ids = $seedIds }
        platform = "Windows"
        active_systems = @("scenario", "crew_world_sequence", "event", "service", "traveler", "police_sweep", "game", "save_load")
        authored_max_counts = [ordered]@{ orders = $orders.Count; punchline_layers = 3 }
        phase_samples = @()
        phase_samples_status = [ordered]@{ available = $false; reason = "semantic composition probe does not instrument frame or draw timing" }
        lifecycle_status = if ($shardFailures.Count -eq 0) { "clean" } else { "failed" }
        terminal = @{}
        semantic_trace_sha256 = Get-TextSha256 ($shardRows | ConvertTo-Json -Depth 100 -Compress)
        save_load_points = @("mounted_mid_composition")
        retained_counters = [ordered]@{ available = $true; measured = @("orphans", "state_bytes"); nodes = $null; resources = $null; objects = $null; orphans = $orphanCount; state_bytes = $stateBytes }
        allocation_copy_counters = [ordered]@{ available = $false; allocations = $null; shallow_copies = $null; deep_copies = $null; bytes = $null; source = "not_instrumented_by_semantic_composition_probe" }
        artifacts = @($artifactsByShard[$shardIndex])
        rows = $shardRows
        failures = $shardFailures
        passed = ($shardFailures.Count -eq 0)
    }
    $shardPath = Join-Path $shardRoot "report.json"
    $shardReport | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $shardPath -Encoding utf8
    $shardReports += [ordered]@{ path = (Get-RelativeEvidencePath $shardPath); sha256 = (Get-FileHash -LiteralPath $shardPath -Algorithm SHA256).Hash.ToLowerInvariant(); passed = $shardReport.passed }
}

$eligibleRows = @()
foreach ($archetypeId in $requiredTargets) {
    $layers = if ($archetypeId -ceq $punchlineId) { @("club", "casino", "back_room") } else { @("") }
    foreach ($layerId in $layers) { foreach ($orderId in $orders) { $eligibleRows += "$archetypeId|$layerId|$orderId" } }
}
$coveredRows = @($rowsByShard.Values | ForEach-Object { $_ } | ForEach-Object { [string]$_.case_id } | Sort-Object -Unique)
$uncoveredRows = @($eligibleRows | Where-Object { $coveredRows -notcontains $_ })
$manifest = [ordered]@{
    schema = "beat_the_house.integ06_1_composition_manifest/v1"
    version = 1
    candidate_commit = $candidate
    candidate_tree = $candidateTree
    tool_source_sha256 = $toolHash
    profile = [ordered]@{ evidence_profile = $EvidenceProfile; path = $resolvedProfile; sha256 = $profileHash }
    eligibility_source = @("data/environments/archetypes.json", "data/environments/scenarios.json", "production delivery target selector")
    eligible_archetypes = $requiredTargets
    discovered_seed_by_archetype = $seedByTarget
    eligible_rows = $eligibleRows
    covered_rows = $coveredRows
    uncovered_rows = $uncoveredRows
    order_ids = $orders
    journey_binding = [ordered]@{
        fixture_id_field = "rows[].case_id"
        checkpoint_field = "rows[].journey_checkpoints[]"
        checkpoint_ordinal_field = "rows[].journey_checkpoints[].ordinal"
        action_ordinal_field = "rows[].journey_checkpoints[].action_index"
        save_load_boundary_field = "rows[].save_load_points[]"
    }
    shard_reports = $shardReports
    passed = ($uncoveredRows.Count -eq 0 -and @($shardReports | Where-Object { -not $_.passed }).Count -eq 0)
}
$manifestPath = Join-Path $out "manifest.json"
$manifest | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $manifestPath -Encoding utf8
$resultLabel = if ($manifest.passed) { "PASS" } else { "FAIL" }
Write-Host "INTEG06_1_COMPOSITION_MATRIX $resultLabel rows=$($coveredRows.Count)/$($eligibleRows.Count) manifest=$manifestPath"
if (-not $manifest.passed) { exit 1 }
