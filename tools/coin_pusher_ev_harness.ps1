param(
    [ValidateRange(200000, 2000000)]
    [int]$AcceptedPerMachine = 200000,
    [ValidateRange(1, 64)]
    [int]$ShardsPerMachine = 8,
    [ValidateRange(1, 16)]
    [int]$Throttle = 1,
    [string]$OutDir = "",
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$machines = @("quarter_falls", "jackpot_ridge", "vault_drop")
if ($Throttle -ne 1) {
    throw "EV shards must run serially. Parallel persistent-machine shards exhausted host memory before producing reports."
}

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
            PeakWorkingSetBytes = 0L
            Report = $null
            FailureKind = ""
            FailureDetail = ""
        })
    }
}

function Read-EvShardReport([object]$Job) {
    if (-not (Test-Path -LiteralPath $Job.Json)) {
        return [pscustomobject]@{ Ok = $false; Report = $null; Kind = "missing_json"; Detail = "Shard exited without writing its JSON report." }
    }
    try {
        $report = Get-Content -LiteralPath $Job.Json -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return [pscustomobject]@{ Ok = $false; Report = $null; Kind = "malformed_json"; Detail = $_.Exception.Message }
    }
    if ($null -eq $report -or $report.schema -ne "coin_pusher_v3_physical_ev_shard_v2") {
        return [pscustomobject]@{ Ok = $false; Report = $null; Kind = "invalid_schema"; Detail = "Expected coin_pusher_v3_physical_ev_shard_v2." }
    }
    try {
        $reportedShard = [int]$report.shard_index
    }
    catch {
        return [pscustomobject]@{ Ok = $false; Report = $null; Kind = "identity_mismatch"; Detail = "Shard JSON index is not an integer." }
    }
    if ($report.machine_id -ne $Job.Machine -or $reportedShard -ne [int]$Job.Shard) {
        return [pscustomobject]@{ Ok = $false; Report = $null; Kind = "identity_mismatch"; Detail = "Shard JSON machine/index does not match the launched job." }
    }
    $requiredProperties = @("accepted_player_inserts", "accounting", "assertions", "coverage", "economy", "geometry_sha256", "passed", "policy_sha256")
    $missingProperties = @($requiredProperties | Where-Object { $report.PSObject.Properties.Name -notcontains $_ })
    if ($missingProperties.Count -gt 0) {
        return [pscustomobject]@{ Ok = $false; Report = $null; Kind = "incomplete_json"; Detail = "Missing required properties: $($missingProperties -join ', ')" }
    }
    return [pscustomobject]@{ Ok = $true; Report = $report; Kind = ""; Detail = "" }
}

if (-not $AggregateOnly) {
    $plannedOutputs = [System.Collections.Generic.List[string]]::new()
    foreach ($job in $jobs) {
        $plannedOutputs.Add($job.Json)
        $plannedOutputs.Add($job.Stdout)
        $plannedOutputs.Add($job.Stderr)
    }
    $plannedOutputs.Add((Join-Path $OutDir "manifest.json"))
    $plannedOutputs.Add((Join-Path $OutDir "execution_failure.json"))
    $existingOutputs = @($plannedOutputs | Where-Object { Test-Path -LiteralPath $_ })
    if ($existingOutputs.Count -gt 0) {
        throw "OutDir contains output files planned for this invocation. Use a new unique OutDir; existing files will not be overwritten: $($existingOutputs -join ', ')"
    }
}

$startedAt = Get-Date
$completed = [System.Collections.Generic.List[object]]::new()
$schedulerFailure = ""
if ($AggregateOnly) {
    foreach ($job in $jobs) {
        $job.ExitCode = if (Test-Path -LiteralPath $job.Json) { 0 } else { -1 }
        $parsed = Read-EvShardReport $job
        if ($parsed.Ok) {
            $job.Report = $parsed.Report
        }
        else {
            $job.FailureKind = $parsed.Kind
            $job.FailureDetail = $parsed.Detail
        }
    }
}
else {
    $pending = [System.Collections.Generic.Queue[object]]::new()
    foreach ($job in $jobs) { $pending.Enqueue($job) }
    $running = [System.Collections.Generic.List[object]]::new()
    $launchStopped = $false
    $nextProgressAt = Get-Date
    try {
        while (($pending.Count -gt 0 -and -not $launchStopped) -or $running.Count -gt 0) {
            for ($index = $running.Count - 1; $index -ge 0; $index--) {
                $job = $running[$index]
                $job.Process.Refresh()
                $job.PeakWorkingSetBytes = [math]::Max([int64]$job.PeakWorkingSetBytes, [int64]$job.Process.PeakWorkingSet64)
                if (-not $job.Process.HasExited) { continue }
                $job.Process.WaitForExit()
                $job.Process.Refresh()
                $observedExitCode = $job.Process.ExitCode
                $job.ExitCode = if ($null -eq $observedExitCode) { -2 } else { [int]$observedExitCode }
                $parsed = Read-EvShardReport $job
                if ($parsed.Ok) {
                    $job.Report = $parsed.Report
                }
                else {
                    $job.FailureKind = $parsed.Kind
                    $job.FailureDetail = $parsed.Detail
                }
                if ($job.ExitCode -ne 0 -and -not $job.FailureKind) {
                    $job.FailureKind = "nonzero_exit"
                    $job.FailureDetail = "Shard process exited with code $($job.ExitCode)."
                }
                $job.Process.Dispose()
                $job.Process = $null
                $completed.Add($job)
                $running.RemoveAt($index)
                Write-Host ("EV shard {0}/{1} machine={2} shard={3} exit={4} report_valid={5} peak_working_set_mb={6:N1}" -f $completed.Count, $jobs.Count, $job.Machine, $job.Shard, $job.ExitCode, $parsed.Ok, ([double]$job.PeakWorkingSetBytes / 1MB))
                if ($job.ExitCode -ne 0 -or -not $parsed.Ok) {
                    $launchStopped = $true
                }
            }
            while (-not $launchStopped -and $pending.Count -gt 0 -and $running.Count -lt $Throttle) {
                $job = $pending.Dequeue()
                $resourceOut = "res://" + (Get-ProjectRelativePath $projectRoot $job.Json)
                $arguments = @(
                    "--headless", "--path", $projectRoot,
                    "--script", "res://tools/coin_pusher_ev_shard.gd", "--",
                    "--machine=$($job.Machine)", "--shard=$($job.Shard)",
                    "--accepted=$($job.Accepted)", "--out=$resourceOut"
                )
                try {
                    $job.Process = Start-Process -FilePath $godot -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput $job.Stdout -RedirectStandardError $job.Stderr -PassThru
                    $running.Add($job)
                }
                catch {
                    $launchError = $_.Exception.Message
                    if ($job.Process -ne $null) {
                        try {
                            $job.Process.Refresh()
                            if (-not $job.Process.HasExited) {
                                $job.Process.Kill()
                                $job.Process.WaitForExit()
                            }
                        }
                        finally {
                            $job.Process.Dispose()
                            $job.Process = $null
                        }
                    }
                    $job.ExitCode = -6
                    $job.FailureKind = "launch_error"
                    $job.FailureDetail = $launchError
                    $completed.Add($job)
                    $launchStopped = $true
                }
            }
            if ((Get-Date) -ge $nextProgressAt -and $running.Count -gt 0) {
                $workingSetBytes = 0L
                foreach ($runningJob in $running) {
                    $runningJob.Process.Refresh()
                    if ($runningJob.Process.HasExited) { continue }
                    $runningJob.PeakWorkingSetBytes = [math]::Max([int64]$runningJob.PeakWorkingSetBytes, [int64]$runningJob.Process.PeakWorkingSet64)
                    $workingSetBytes += [int64]$runningJob.Process.WorkingSet64
                }
                Write-Host ("EV harness progress completed={0}/{1} running={2} pending={3} working_set_mb={4:N1}" -f $completed.Count, $jobs.Count, $running.Count, $pending.Count, ([double]$workingSetBytes / 1MB))
                $nextProgressAt = (Get-Date).AddSeconds(30)
            }
            if ($running.Count -gt 0) { Start-Sleep -Milliseconds 250 }
        }
    }
    catch {
        $schedulerFailure = $_.Exception.ToString()
        $launchStopped = $true
    }
    finally {
        $cleanupRecords = [System.Collections.Generic.List[object]]::new()
        foreach ($job in @($running)) {
            try {
                $job.Process.Refresh()
                if (-not $job.Process.HasExited) {
                    $job.Process.Kill()
                    $job.Process.WaitForExit()
                }
                $job.Process.Refresh()
                $job.PeakWorkingSetBytes = [math]::Max([int64]$job.PeakWorkingSetBytes, [int64]$job.Process.PeakWorkingSet64)
                $job.ExitCode = if ($null -eq $job.Process.ExitCode) { -5 } else { [int]$job.Process.ExitCode }
            }
            catch {
                $job.ExitCode = -5
                $job.FailureDetail = $_.Exception.Message
            }
            finally {
                if ($job.Process -ne $null) {
                    $job.Process.Dispose()
                    $job.Process = $null
                }
            }
            $job.FailureKind = "scheduler_cleanup"
            if (-not $job.FailureDetail) { $job.FailureDetail = "Active child was stopped and awaited during scheduler cleanup." }
            $completed.Add($job)
            $cleanupRecords.Add([ordered]@{ machine = $job.Machine; shard = $job.Shard; exit_code = $job.ExitCode; peak_working_set_bytes = $job.PeakWorkingSetBytes; failure_kind = $job.FailureKind; failure_detail = $job.FailureDetail })
        }
        $running.Clear()
        foreach ($job in $pending) {
            $job.ExitCode = -3
            $job.FailureKind = "not_started_after_failure"
            $job.FailureDetail = "The scheduler stopped before this shard was launched."
        }
        if ($cleanupRecords.Count -gt 0 -or $schedulerFailure) {
            $recoveryReport = [ordered]@{
                schema = "coin_pusher_v3_physical_ev_execution_failure_v1"
                generated_at = (Get-Date).ToUniversalTime().ToString("o")
                scheduler_failure = $schedulerFailure
                stopped_children = @($cleanupRecords)
                jobs = @($jobs | ForEach-Object { [ordered]@{ machine = $_.Machine; shard = $_.Shard; exit_code = $_.ExitCode; peak_working_set_bytes = $_.PeakWorkingSetBytes; failure_kind = $_.FailureKind; failure_detail = $_.FailureDetail } })
            }
            try {
                $recoveryReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutDir "execution_failure.json") -Encoding utf8
            }
            catch {
                Write-Warning "Could not persist EV scheduler cleanup report: $($_.Exception.Message)"
            }
        }
    }
    if ($launchStopped) {
        Write-Host ("EV harness stopped scheduling after a failed shard; {0} shard(s) were not started." -f $pending.Count)
    }
}

$shardReports = [System.Collections.Generic.List[object]]::new()
$processFailures = [System.Collections.Generic.List[object]]::new()
foreach ($job in $jobs) {
    if ($job.Report -ne $null) {
        $shardReports.Add($job.Report)
    }
    if ($job.ExitCode -ne 0 -or $job.FailureKind) {
        $processFailures.Add([pscustomobject]@{
            machine = $job.Machine
            shard = $job.Shard
            exit_code = $job.ExitCode
            stderr = $job.Stderr
            peak_working_set_bytes = $job.PeakWorkingSetBytes
            failure_kind = $job.FailureKind
            failure_detail = $job.FailureDetail
            report_passed = if ($job.Report -ne $null) { $job.Report.passed } else { $null }
            not_started_after_failure = $job.ExitCode -eq -3
        })
    }
}

function Get-TCritical95([int]$DegreesOfFreedom) {
    $table = @(0.0, 12.706, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365, 2.306, 2.262, 2.228, 2.201, 2.179, 2.160, 2.145, 2.131, 2.120, 2.110, 2.101, 2.093, 2.086, 2.080, 2.074, 2.069, 2.064, 2.060, 2.056, 2.052, 2.048, 2.045, 2.042)
    if ($DegreesOfFreedom -le 0) { return 0.0 }
    if ($DegreesOfFreedom -lt $table.Count) { return [double]$table[$DegreesOfFreedom] }
    return 1.96
}

function Get-Dispersion([double[]]$Values) {
    $mean = if ($Values.Count -gt 0) { [double](($Values | Measure-Object -Average).Average) } else { 0.0 }
    $sumSquared = 0.0
    foreach ($value in $Values) { $sumSquared += ([double]$value - $mean) * ([double]$value - $mean) }
    $sampleStdDev = if ($Values.Count -gt 1) { [math]::Sqrt($sumSquared / ($Values.Count - 1)) } else { 0.0 }
    $standardError = if ($Values.Count -gt 0) { $sampleStdDev / [math]::Sqrt($Values.Count) } else { 0.0 }
    $degreesOfFreedom = [math]::Max(0, $Values.Count - 1)
    $critical = Get-TCritical95 $degreesOfFreedom
    return [ordered]@{
        method = "two-sided Student t interval across deterministic shard estimates"
        sample_count = $Values.Count
        degrees_of_freedom = $degreesOfFreedom
        critical_95 = $critical
        mean = $mean
        sample_standard_deviation = $sampleStdDev
        standard_error = $standardError
        confidence_95 = @(($mean - $critical * $standardError), ($mean + $critical * $standardError))
        shard_values = @($Values)
    }
}

$machineReports = [System.Collections.Generic.List[object]]::new()
$aggregationFailure = ""
try {
foreach ($machine in $machines) {
    $reports = @($shardReports | Where-Object machine_id -eq $machine | Sort-Object shard_index)
    $shardHashes = [ordered]@{}
    foreach ($shardReport in $reports) {
        $shardName = "$($shardReport.machine_id)_shard_$('{0:D2}' -f $shardReport.shard_index).json"
        $shardHashes[$shardName] = (Get-FileHash -LiteralPath (Join-Path $OutDir $shardName) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $accepted = [int64](($reports | Measure-Object accepted_player_inserts -Sum).Sum)
    $wagered = [int64](($reports | ForEach-Object { $_.economy.wagered } | Measure-Object -Sum).Sum)
    $physicalValue = [int64](($reports | ForEach-Object { $_.economy.base_physical_coin_tray_value } | Measure-Object -Sum).Sum)
    $creditedValue = [int64](($reports | ForEach-Object { $_.economy.ridge_credited_coin_tray_value } | Measure-Object -Sum).Sum)
	$endingPaidValue = [int64](($reports | ForEach-Object { $_.economy.ending_active_paid_coin_value } | Measure-Object -Sum).Sum)
    $fragments = [int64](($reports | ForEach-Object { $_.economy.physically_banked_fragments_excluded_from_base_roi } | Measure-Object -Sum).Sum)
    $targetInstantValue = [int64](($reports | ForEach-Object { $_.economy.plinko_target_instant_payout_value_excluded_from_base_roi } | Measure-Object -Sum).Sum)
    $targetBonusDrops = [int64](($reports | ForEach-Object { $_.economy.plinko_target_bonus_drop_award_count_excluded_from_base_roi } | Measure-Object -Sum).Sum)
    $targetCaptureCounts = @{}
    foreach ($report in $reports) {
        foreach ($property in $report.economy.plinko_target_capture_counts.PSObject.Properties) {
            $targetCaptureCounts[$property.Name] = [int64]$targetCaptureCounts[$property.Name] + [int64]$property.Value
        }
    }
    $physicalRoi = if ($wagered -gt 0) { [double]$physicalValue / [double]$wagered } else { 0.0 }
    $creditedRoi = if ($wagered -gt 0) { [double]$creditedValue / [double]$wagered } else { 0.0 }
	$stockAdjustedUpper = if ($wagered -gt 0) { [double]($physicalValue + $endingPaidValue) / [double]$wagered } else { 0.0 }
    $shardLowerRois = [double[]]@($reports | ForEach-Object { [double]$_.economy.stock_adjusted_physical_roi_interval[0] })
    $shardUpperRois = [double[]]@($reports | ForEach-Object { [double]$_.economy.stock_adjusted_physical_roi_interval[1] })
    $lowerDispersion = Get-Dispersion $shardLowerRois
    $upperDispersion = Get-Dispersion $shardUpperRois
    $bands = @($reports | ForEach-Object { ,@($_.economy.documented_physical_roi_band) })
    $band = if ($bands.Count -gt 0) { @([double]$bands[0][0], [double]$bands[0][1]) } else { @() }
    $bandKeys = @($bands | ForEach-Object { (@($_) -join ",") } | Sort-Object -Unique)
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
    $identifiedIntervalInBand = $band.Count -eq 2 -and $physicalRoi -ge $band[0] -and $stockAdjustedUpper -le $band[1]
    $confidenceIntervalsInBand = $band.Count -eq 2 -and [double]$lowerDispersion.confidence_95[0] -ge $band[0] -and [double]$lowerDispersion.confidence_95[1] -le $band[1] -and [double]$upperDispersion.confidence_95[0] -ge $band[0] -and [double]$upperDispersion.confidence_95[1] -le $band[1]
    $vaultBandExact = $machine -ne "vault_drop" -or ($band.Count -eq 2 -and $band[0] -eq 0.72 -and $band[1] -eq 0.94)
    $assertions = [ordered]@{
        shard_count = $reports.Count -eq $ShardsPerMachine
        accepted_at_least_200000 = $accepted -ge 200000
        accepted_exact = $accepted -eq $AcceptedPerMachine
        every_shard_passed = $reports.Count -gt 0 -and @($reports | Where-Object { -not $_.passed }).Count -eq 0
        persistent_one_machine_each_shard = $reports.Count -gt 0 -and @($reports | Where-Object { $_.machine_instances -ne 1 -or $_.pile_resets -ne 0 -or -not $_.no_favorable_reset }).Count -eq 0
        conservation_every_shard = $reports.Count -gt 0 -and @($reports | Where-Object { -not $_.accounting.conservation_ok }).Count -eq 0
        origin_by_kind_reconciliation_every_shard = $reports.Count -gt 0 -and @($reports | Where-Object { -not $_.accounting.origin_by_kind_reconciliation_ok }).Count -eq 0
        policy_hash_stable = $hashes.Count -eq 1
        geometry_hash_stable = $geometryHashes.Count -eq 1
        authored_physical_roi_band_stable = $bandKeys.Count -eq 1
        phase_domain_complete = @($phaseTotals | Where-Object { $_ -le 0 }).Count -eq 0
        apparatus_domain_complete = $apparatusTotals.Count -gt 0 -and @($apparatusTotals.Values | Where-Object { $_ -le 0 }).Count -eq 0
        aggregate_identified_roi_interval_in_authored_band = $identifiedIntervalInBand
        lower_and_upper_confidence_intervals_in_authored_band = $confidenceIntervalsInBand
        vault_band_exact_072_094 = $vaultBandExact
        vault_option_value_not_merged = $machine -ne "vault_drop" -or @($reports | Where-Object { $_.economy.vault_option_value_merged_into_physical_roi }).Count -eq 0
        vault_physical_fragment_ids_reconciled = $machine -ne "vault_drop" -or @($reports | Where-Object { -not $_.economy.vault_option_value_sampling.physical_id_count_reconciled -or -not $_.economy.vault_option_value_sampling.token_balance_reconciled -or -not $_.assertions.vault_physical_fragment_ids_reconciled -or -not $_.assertions.vault_option_token_balance_reconciled }).Count -eq 0
        ridge_credit_reported_separately = $machine -ne "jackpot_ridge" -or $creditedValue -ge $physicalValue
        plinko_target_value_reported_separately = @($reports | Where-Object { $_.economy.plinko_target_value_merged_into_physical_roi }).Count -eq 0
        authored_plinko_targets_reached = $machine -eq "quarter_falls" -or ($targetCaptureCounts.Count -ge 2 -and @($targetCaptureCounts.Values | Where-Object { $_ -le 0 }).Count -eq 0)
    }
    $machineReports.Add([ordered]@{
        machine_id = $machine
        accepted_player_inserts = $accepted
        wagered = $wagered
        base_physical_coin_tray_value = $physicalValue
        base_physical_coin_to_tray_roi = $physicalRoi
		ending_active_paid_coin_value = $endingPaidValue
        stock_adjusted_physical_roi_interval = @($physicalRoi, $stockAdjustedUpper)
        identified_interval_method = "lower is aggregate paid-origin tray ROI; upper adds all unresolved active paid-origin stock; paid gutter is terminal loss"
        shard_roi_dispersion = [ordered]@{ lower_bound = $lowerDispersion; upper_bound = $upperDispersion }
        documented_physical_roi_band = $band
        ridge_credited_coin_tray_value = $creditedValue
        ridge_credited_roi = $creditedRoi
        physically_banked_fragments = $fragments
        plinko_target_capture_counts = $targetCaptureCounts
        plinko_target_instant_payout_value_excluded_from_base_roi = $targetInstantValue
        plinko_target_bonus_drop_award_count_excluded_from_base_roi = $targetBonusDrops
        plinko_target_value_merged_into_physical_roi = $false
        vault_option_value_sampling = if ($machine -eq "vault_drop") {
            [ordered]@{
                method = "production_state_physically_banked_fragment_chain_v1"
                shards = @($reports | ForEach-Object { $_.economy.vault_option_value_sampling })
                physical_fragment_count = [int64](($reports | ForEach-Object { $_.economy.vault_option_value_sampling.physical_fragment_count } | Measure-Object -Sum).Sum)
                outcome_count = [int64](($reports | ForEach-Object { $_.economy.vault_option_value_sampling.outcomes.Count } | Measure-Object -Sum).Sum)
                cash_total = [int64](($reports | ForEach-Object { $_.economy.vault_option_value_sampling.cash_total } | Measure-Object -Sum).Sum)
                fixed_cash_total = [int64](($reports | ForEach-Object { $_.economy.vault_option_value_sampling.fixed_cash_total } | Measure-Object -Sum).Sum)
                progressive_cash_total = [int64](($reports | ForEach-Object { $_.economy.vault_option_value_sampling.progressive_cash_total } | Measure-Object -Sum).Sum)
                measured_cash_option_value_per_physically_banked_fragment = if ($fragments -gt 0) { [double](($reports | ForEach-Object { $_.economy.vault_option_value_sampling.cash_total } | Measure-Object -Sum).Sum) / [double]$fragments } else { 0.0 }
                fragment_refund_count = [int64](($reports | ForEach-Object { $_.economy.vault_option_value_sampling.fragment_refund_count } | Measure-Object -Sum).Sum)
                unspent_physical_fragment_count = [int64](($reports | ForEach-Object { $_.economy.vault_option_value_sampling.unspent_physical_fragment_ids.Count } | Measure-Object -Sum).Sum)
                unspent_refund_token_count = [int64](($reports | ForEach-Object { $_.economy.vault_option_value_sampling.unspent_refund_token_ids.Count } | Measure-Object -Sum).Sum)
                production_banked_after = [int64](($reports | ForEach-Object { $_.economy.vault_option_value_sampling.production_banked_after } | Measure-Object -Sum).Sum)
                reset_count = [int64](($reports | ForEach-Object { $_.economy.vault_option_value_sampling.reset_count } | Measure-Object -Sum).Sum)
                jackpot_count = [int64](($reports | ForEach-Object { $_.economy.vault_option_value_sampling.jackpot_count } | Measure-Object -Sum).Sum)
                merged_into_coin_to_tray_roi = $false
            }
        } else { @{} }
        policy_sha256 = $hashes
        geometry_sha256 = $geometryHashes
        aggregate_phase_bins = $phaseTotals
        aggregate_apparatus = $apparatusTotals
        assertions = $assertions
        passed = @($assertions.Values | Where-Object { -not $_ }).Count -eq 0
        shard_reports = @($reports | ForEach-Object { [System.IO.Path]::GetFileName("$($_.machine_id)_shard_$('{0:D2}' -f $_.shard_index).json") })
        shard_report_sha256 = $shardHashes
    })
}
}
catch {
    $aggregationFailure = $_.Exception.ToString()
    $processFailures.Add([pscustomobject]@{
        machine = "__harness__"
        shard = -1
        exit_code = -7
        stderr = ""
        peak_working_set_bytes = 0
        failure_kind = "aggregation_error"
        failure_detail = $aggregationFailure
        report_passed = $null
        not_started_after_failure = $false
    })
}
finally {
    foreach ($job in $jobs) {
        if ($job.Process -eq $null) { continue }
        try {
            $job.Process.Refresh()
            if (-not $job.Process.HasExited) {
                $job.Process.Kill()
                $job.Process.WaitForExit()
            }
        }
        finally {
            $job.Process.Dispose()
            $job.Process = $null
        }
    }
}

$overallPassed = $processFailures.Count -eq 0 -and $machineReports.Count -eq $machines.Count -and @($machineReports | Where-Object { -not $_.passed }).Count -eq 0
$finalReport = [ordered]@{
    schema = "coin_pusher_v3_physical_ev_harness_v2"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    command = "tools/coin_pusher_ev_harness.ps1 -AcceptedPerMachine $AcceptedPerMachine -ShardsPerMachine $ShardsPerMachine -Throttle $Throttle"
    methodology = [ordered]@{
        accepted_drop_minimum_per_machine = 200000
        production_machine_persistent_per_deterministic_shard = $true
        accepted_inserts_are_real_solver_bodies = $true
        solver_progression_after_every_attempt = $true
        favorable_resets = 0
        opening_ending_tray_gutter_collected_reconciled = $true
        origin_by_kind_reconciled = $true
        unresolved_paid_stock_reported_as_identified_interval = $true
        identified_interval_and_both_bound_confidence_intervals_must_fit_authored_band = $true
        physical_coin_roi_excludes_features = $true
        vault_fragment_and_option_value_separate = $true
        vault_option_value_uses_only_physically_banked_fragment_ids_and_real_subgame_actions = $true
        ridge_credited_roi_separate = $true
        plinko_target_capture_and_reward_value_separate = $true
    }
    elapsed_seconds = ((Get-Date) - $startedAt).TotalSeconds
    scheduler_failure = $schedulerFailure
    aggregation_failure = $aggregationFailure
    shard_processes = @($jobs | ForEach-Object {
        [ordered]@{
            machine = $_.Machine
            shard = $_.Shard
            accepted_target = $_.Accepted
            exit_code = $_.ExitCode
            peak_working_set_bytes = $_.PeakWorkingSetBytes
            report_valid = $_.Report -ne $null
            failure_kind = $_.FailureKind
            failure_detail = $_.FailureDetail
        }
    })
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
