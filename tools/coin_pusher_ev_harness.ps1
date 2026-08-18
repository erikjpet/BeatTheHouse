param(
    [ValidateRange(200000, 2000000)]
    [int]$AcceptedPerMachine = 200000,
    [ValidateRange(1, 64)]
    [int]$ShardsPerMachine = 8,
    [ValidateRange(1, 16)]
    [int]$Throttle = 6,
    [string]$OutDir = "",
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$machines = @("quarter_falls", "jackpot_ridge", "vault_drop")

function Get-ProjectRelativePath([string]$BasePath, [string]$TargetPath) {
    $base = [System.IO.Path]::GetFullPath($BasePath)
    if (-not $base.EndsWith([System.IO.Path]::DirectorySeparatorChar)) { $base += [System.IO.Path]::DirectorySeparatorChar }
    $baseUri = [System.Uri]$base
    $targetUri = [System.Uri]([System.IO.Path]::GetFullPath($TargetPath))
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()) -replace "\\", "/"
}

if (-not $OutDir) {
    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $OutDir = Join-Path $projectRoot ".tmp\coin_pusher_ev_$stamp"
}
$OutDir = [System.IO.Path]::GetFullPath($OutDir)
$projectPrefix = [System.IO.Path]::GetFullPath($projectRoot)
if (-not $projectPrefix.EndsWith([System.IO.Path]::DirectorySeparatorChar)) { $projectPrefix += [System.IO.Path]::DirectorySeparatorChar }
if (-not $OutDir.StartsWith($projectPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "OutDir must remain inside the project so Godot can write deterministic res:// shard reports."
}
[System.IO.Directory]::CreateDirectory($OutDir) | Out-Null

$godot = $env:GODOT_BIN
if (-not $godot) {
    $candidateRoots = @(
        (Join-Path $projectRoot ".tools"),
        (Join-Path (Split-Path -Parent $projectRoot) "Beat-The-House\.tools"),
        (Join-Path (Split-Path -Parent (Split-Path -Parent $projectRoot)) "Beat-The-House\.tools")
    )
    foreach ($candidateRoot in $candidateRoots) {
        if (-not (Test-Path -LiteralPath $candidateRoot)) { continue }
        $candidate = Get-ChildItem -LiteralPath $candidateRoot -Recurse -Filter "Godot*_console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($candidate) { $godot = $candidate.FullName; break }
    }
}
if (-not $godot) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { $godot = $command.Source }
}
if (-not $godot) { throw "Godot was not found. Set GODOT_BIN or install the project-local toolchain." }

$jobs = [System.Collections.Generic.List[object]]::new()
$baseAccepted = [math]::Floor($AcceptedPerMachine / $ShardsPerMachine)
$remainder = $AcceptedPerMachine % $ShardsPerMachine
foreach ($machine in $machines) {
    for ($shard = 0; $shard -lt $ShardsPerMachine; $shard++) {
        $accepted = $baseAccepted + $(if ($shard -lt $remainder) { 1 } else { 0 })
        $stem = "${machine}_shard_$('{0:D2}' -f $shard)"
        $jobs.Add([pscustomobject]@{
            Machine = $machine
            Shard = $shard
            Accepted = $accepted
            Json = Join-Path $OutDir "$stem.json"
            Stdout = Join-Path $OutDir "$stem.stdout.txt"
            Stderr = Join-Path $OutDir "$stem.stderr.txt"
            Process = $null
            ExitCode = $null
        })
    }
}

$startedAt = Get-Date
if ($AggregateOnly) {
    foreach ($job in $jobs) { $job.ExitCode = if (Test-Path -LiteralPath $job.Json) { 0 } else { -1 } }
}
else {
    $pending = [System.Collections.Generic.Queue[object]]::new()
    foreach ($job in $jobs) { $pending.Enqueue($job) }
    $running = [System.Collections.Generic.List[object]]::new()
    $completed = [System.Collections.Generic.List[object]]::new()
    while ($pending.Count -gt 0 -or $running.Count -gt 0) {
        while ($pending.Count -gt 0 -and $running.Count -lt $Throttle) {
            $job = $pending.Dequeue()
            $resourceOut = "res://" + (Get-ProjectRelativePath $projectRoot $job.Json)
            $arguments = @(
                "--headless", "--path", $projectRoot,
                "--script", "res://tools/coin_pusher_ev_shard.gd", "--",
                "--machine=$($job.Machine)", "--shard=$($job.Shard)",
                "--accepted=$($job.Accepted)", "--out=$resourceOut"
            )
            $job.Process = Start-Process -FilePath $godot -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput $job.Stdout -RedirectStandardError $job.Stderr -PassThru
            $running.Add($job)
        }
        Start-Sleep -Milliseconds 250
        for ($index = $running.Count - 1; $index -ge 0; $index--) {
            $job = $running[$index]
            if (-not $job.Process.HasExited) { continue }
            $job.Process.WaitForExit()
            $job.ExitCode = $job.Process.ExitCode
            $completed.Add($job)
            $running.RemoveAt($index)
            Write-Host ("EV shard {0}/{1} machine={2} shard={3} exit={4}" -f $completed.Count, $jobs.Count, $job.Machine, $job.Shard, $job.ExitCode)
        }
    }
}

$shardReports = [System.Collections.Generic.List[object]]::new()
$processFailures = [System.Collections.Generic.List[object]]::new()
foreach ($job in $jobs) {
    if (-not (Test-Path -LiteralPath $job.Json)) {
        $processFailures.Add([pscustomobject]@{ machine = $job.Machine; shard = $job.Shard; exit_code = $job.ExitCode; stderr = $job.Stderr })
        continue
    }
    $shardReport = Get-Content -LiteralPath $job.Json -Raw | ConvertFrom-Json
    $shardReports.Add($shardReport)
    if ($job.ExitCode -ne 0) {
        $processFailures.Add([pscustomobject]@{ machine = $job.Machine; shard = $job.Shard; exit_code = $job.ExitCode; stderr = $job.Stderr; report_passed = $shardReport.passed })
    }
}

$machineReports = [System.Collections.Generic.List[object]]::new()
foreach ($machine in $machines) {
    $reports = @($shardReports | Where-Object machine_id -eq $machine | Sort-Object shard_index)
    $accepted = [int64](($reports | Measure-Object accepted_player_inserts -Sum).Sum)
    $wagered = [int64](($reports | ForEach-Object { $_.economy.wagered } | Measure-Object -Sum).Sum)
    $physicalValue = [int64](($reports | ForEach-Object { $_.economy.base_physical_coin_tray_value } | Measure-Object -Sum).Sum)
    $creditedValue = [int64](($reports | ForEach-Object { $_.economy.ridge_credited_coin_tray_value } | Measure-Object -Sum).Sum)
    $fragments = [int64](($reports | ForEach-Object { $_.economy.physically_banked_fragments_excluded_from_base_roi } | Measure-Object -Sum).Sum)
    $physicalRoi = if ($wagered -gt 0) { [double]$physicalValue / [double]$wagered } else { 0.0 }
    $creditedRoi = if ($wagered -gt 0) { [double]$creditedValue / [double]$wagered } else { 0.0 }
    $bands = @($reports | ForEach-Object { ,@($_.economy.documented_physical_roi_band) })
    $band = if ($bands.Count -gt 0) { @([double]$bands[0][0], [double]$bands[0][1]) } else { @() }
    $hashes = @($reports.policy_sha256 | Sort-Object -Unique)
    $geometryHashes = @($reports.geometry_sha256 | Sort-Object -Unique)
    $phaseTotals = @(0) * 12
    $apparatusTotals = @{}
    foreach ($report in $reports) {
        for ($index = 0; $index -lt 12; $index++) { $phaseTotals[$index] += [int64]$report.coverage.phase_bins[$index] }
        foreach ($property in $report.coverage.apparatus.PSObject.Properties) {
            $apparatusTotals[$property.Name] = [int64]$apparatusTotals[$property.Name] + [int64]$property.Value
        }
    }
    $bandPass = $band.Count -eq 2 -and $physicalRoi -ge $band[0] -and $physicalRoi -le $band[1]
    $vaultBandExact = $machine -ne "vault_drop" -or ($band.Count -eq 2 -and $band[0] -eq 0.72 -and $band[1] -eq 0.94)
    $assertions = [ordered]@{
        shard_count = $reports.Count -eq $ShardsPerMachine
        accepted_at_least_200000 = $accepted -ge 200000
        accepted_exact = $accepted -eq $AcceptedPerMachine
        every_shard_passed = $reports.Count -gt 0 -and @($reports | Where-Object { -not $_.passed }).Count -eq 0
        persistent_one_machine_each_shard = $reports.Count -gt 0 -and @($reports | Where-Object { $_.machine_instances -ne 1 -or $_.pile_resets -ne 0 -or -not $_.no_favorable_reset }).Count -eq 0
        conservation_every_shard = $reports.Count -gt 0 -and @($reports | Where-Object { -not $_.accounting.conservation_ok }).Count -eq 0
        policy_hash_stable = $hashes.Count -eq 1
        geometry_hash_stable = $geometryHashes.Count -eq 1
        phase_domain_complete = @($phaseTotals | Where-Object { $_ -le 0 }).Count -eq 0
        apparatus_domain_complete = $apparatusTotals.Count -gt 0 -and @($apparatusTotals.Values | Where-Object { $_ -le 0 }).Count -eq 0
        physical_roi_in_authored_band = $bandPass
        vault_band_exact_072_094 = $vaultBandExact
        vault_option_value_not_merged = $machine -ne "vault_drop" -or @($reports | Where-Object { $_.economy.vault_option_value_merged_into_physical_roi }).Count -eq 0
        ridge_credit_reported_separately = $machine -ne "jackpot_ridge" -or $creditedValue -ge $physicalValue
    }
    $machineReports.Add([ordered]@{
        machine_id = $machine
        accepted_player_inserts = $accepted
        wagered = $wagered
        base_physical_coin_tray_value = $physicalValue
        base_physical_coin_to_tray_roi = $physicalRoi
        documented_physical_roi_band = $band
        ridge_credited_coin_tray_value = $creditedValue
        ridge_credited_roi = $creditedRoi
        physically_banked_fragments = $fragments
        vault_option_value_basis = if ($machine -eq "vault_drop" -and $reports.Count -gt 0) { $reports[0].economy.vault_option_value_basis } else { @{} }
        policy_sha256 = $hashes
        geometry_sha256 = $geometryHashes
        aggregate_phase_bins = $phaseTotals
        aggregate_apparatus = $apparatusTotals
        assertions = $assertions
        passed = @($assertions.Values | Where-Object { -not $_ }).Count -eq 0
        shard_reports = @($reports | ForEach-Object { [System.IO.Path]::GetFileName("$($_.machine_id)_shard_$('{0:D2}' -f $_.shard_index).json") })
    })
}

$overallPassed = $processFailures.Count -eq 0 -and $machineReports.Count -eq $machines.Count -and @($machineReports | Where-Object { -not $_.passed }).Count -eq 0
$finalReport = [ordered]@{
    schema = "coin_pusher_v3_physical_ev_harness_v1"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    command = "tools/coin_pusher_ev_harness.ps1 -AcceptedPerMachine $AcceptedPerMachine -ShardsPerMachine $ShardsPerMachine -Throttle $Throttle"
    methodology = [ordered]@{
        accepted_drop_minimum_per_machine = 200000
        production_machine_persistent_per_deterministic_shard = $true
        accepted_inserts_are_real_solver_bodies = $true
        solver_progression_after_every_attempt = $true
        favorable_resets = 0
        opening_ending_tray_gutter_collected_reconciled = $true
        physical_coin_roi_excludes_features = $true
        vault_fragment_and_option_value_separate = $true
        ridge_credited_roi_separate = $true
    }
    elapsed_seconds = ((Get-Date) - $startedAt).TotalSeconds
    process_failures = $processFailures
    machines = $machineReports
    passed = $overallPassed
}
$reportPath = Join-Path $OutDir "manifest.json"
$finalReport | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $reportPath -Encoding utf8

Write-Host ("COIN_PUSHER_EV_HARNESS_{0} report={1}" -f $(if ($overallPassed) { "PASS" } else { "FAIL" }), $reportPath)
foreach ($machineReport in $machineReports) {
    Write-Host ("{0}: accepted={1} physical_roi={2:N6} band=[{3}] credited_roi={4:N6} fragments={5} pass={6}" -f $machineReport.machine_id, $machineReport.accepted_player_inserts, $machineReport.base_physical_coin_to_tray_roi, ($machineReport.documented_physical_roi_band -join ","), $machineReport.ridge_credited_roi, $machineReport.physically_banked_fragments, $machineReport.passed)
}
exit $(if ($overallPassed) { 0 } else { 1 })
