$script:FoundationSystemsCheckIds = @(
    "content",
    "town_state_foundation",
    "coach_engine_foundation",
    "onboarding_tutorial_arc",
    "attribute_glyph_foundation",
    "profile_inventory_boundary",
    "fixture_rng",
    "run_state_source_of_truth",
    "locked_logic_rate_foundation",
    "fixture_contracts",
    "run_action_service_boundary",
    "mutation_firewall_foundation",
    "ui_state_machine_input_fuzz_foundation",
    "challenge_pack_foundation",
    "item_effect_foundation",
    "item_build_interaction_foundation",
    "event_module_foundation",
    "event_system_state_foundation",
    "interactable_event_class_guard",
    "crew_recruitment_contract",
    "crew_layer3_jobs_contract",
    "crew_plays_contract",
    "crew_heist_contract",
    "character_chains_contract",
    "game_activation_class_guard",
    "lottery_redemption_clerk_merge",
    "talk_decision_system_foundation",
    "dialogue_system_foundation",
    "t4_7_event_interaction_model",
    "t6_7_visibility_event_cadence",
    "save_service_foundation_round_trip",
    "save_load_interrupt_fuzz_foundation",
    "platform_services_foundation",
    "economy_pressure_foundation",
    "travel_route_foundation",
    "world_map_foundation",
    "meta_home_run_boundary",
    "meta_home_fresh_store_defaults",
    "meta_home_fixture_pollution_migration",
    "time_open_hours_foundation",
    "service_hook_foundation",
    "jazz_club_foundation",
    "lender_debt_foundation",
    "suspicion_security_foundation",
    "run_report_foundation",
    "music_fx_foundation",
    "music_stem_director_foundation",
    "skill_cheat_contract_foundation",
    "skill_timing_helper_foundation",
    "skill_cheat_item_modifier_foundation",
    "m2_system_interaction_scenario",
    "demo_boss_objective_foundation",
    "recovery_loss_pressure_foundation"
)

$script:FoundationSystemsShardPlan = [ordered]@{
    "systems_core" = @(
        "content",
        "town_state_foundation",
        "coach_engine_foundation",
        "onboarding_tutorial_arc",
        "attribute_glyph_foundation",
        "profile_inventory_boundary",
        "fixture_rng",
        "run_state_source_of_truth",
        "locked_logic_rate_foundation",
        "fixture_contracts",
        "run_action_service_boundary",
        "mutation_firewall_foundation",
        "challenge_pack_foundation",
        "item_effect_foundation",
        "item_build_interaction_foundation"
    )
    "systems_activation" = @(
        "game_activation_class_guard"
    )
    "systems_events_saves" = @(
        "event_module_foundation",
        "event_system_state_foundation",
        "interactable_event_class_guard",
        "crew_recruitment_contract",
        "crew_layer3_jobs_contract",
        "crew_plays_contract",
        "crew_heist_contract",
        "character_chains_contract",
        "lottery_redemption_clerk_merge",
        "talk_decision_system_foundation",
        "dialogue_system_foundation",
        "t4_7_event_interaction_model",
        "t6_7_visibility_event_cadence",
        "save_service_foundation_round_trip",
        "save_load_interrupt_fuzz_foundation",
        "platform_services_foundation",
        "jazz_club_foundation",
        "lender_debt_foundation",
        "demo_boss_objective_foundation"
    )
    "systems_world_release" = @(
        "ui_state_machine_input_fuzz_foundation",
        "economy_pressure_foundation",
        "travel_route_foundation",
        "world_map_foundation",
        "meta_home_run_boundary",
        "meta_home_fresh_store_defaults",
        "meta_home_fixture_pollution_migration",
        "time_open_hours_foundation",
        "service_hook_foundation",
        "suspicion_security_foundation",
        "run_report_foundation",
        "music_fx_foundation",
        "music_stem_director_foundation",
        "skill_cheat_contract_foundation",
        "skill_timing_helper_foundation",
        "skill_cheat_item_modifier_foundation",
        "m2_system_interaction_scenario",
        "recovery_loss_pressure_foundation"
    )
}

$script:FoundationSystemsUserPathOwners = [ordered]@{
    "user://foundation_tutorial_meta_store.json" = "onboarding_tutorial_arc"
    "user://foundation_profile_inventory_check.json" = "profile_inventory_boundary"
    "user://saves/foundation_save_round_trip.json" = "save_service_foundation_round_trip"
    "user://saves/foundation_save_atomic_recovery.json" = "save_service_foundation_round_trip"
    "user://meta_collection_linked_bag_check.json" = "meta_home_run_boundary"
    "user://foundation_check_fresh_meta_collection.json" = "meta_home_fresh_store_defaults"
    "user://foundation_check_polluted_meta_collection.json" = "meta_home_fixture_pollution_migration"
    "user://foundation_check_earned_meta_collection.json" = "meta_home_fixture_pollution_migration"
    "user://music_wav_cache_fixture.wav" = "music_fx_foundation"
}

$script:FoundationShardClearedEnvironmentNames = @(
    "BTH_DISTRIBUTION_DATA_ROOT",
    "BTH_DISTRIBUTION_BUILD",
    "BTH_META_COLLECTION_PATH",
    "BTH_PROFILE_INVENTORY_PATH"
)

$script:FoundationShardStableCacheFiles = @(
    "global_script_class_cache.cfg",
    "uid_cache.bin"
)

function Get-FoundationSystemsCheckIds {
    return @($script:FoundationSystemsCheckIds)
}

function Get-FoundationSystemsShardPlan {
    return $script:FoundationSystemsShardPlan
}

function Get-FoundationSystemsUserPathOwners {
    return $script:FoundationSystemsUserPathOwners
}

function Get-FoundationShardClearedEnvironmentNames {
    return @($script:FoundationShardClearedEnvironmentNames)
}

function Copy-FoundationShardCache {
    param(
        [string]$SourceCache,
        [string]$DestinationCache
    )
    $sourceImported = Join-Path $SourceCache "imported"
    if (-not (Test-Path -LiteralPath $sourceImported -PathType Container)) {
        throw "Parent Godot import did not produce .godot/imported before systems sharding."
    }
    New-Item -ItemType Directory -Force -Path $DestinationCache | Out-Null
    foreach ($fileName in $script:FoundationShardStableCacheFiles) {
        $sourceFile = Join-Path $SourceCache $fileName
        if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
            throw "Parent Godot import did not produce required stable cache file '$fileName'."
        }
        Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $DestinationCache $fileName) -Force
    }
    # Imported artifacts are the only cache directory the shards inherit.
    # Editor, export, and shader caches are volatile and child Godot processes
    # create their own private versions when needed.
    Copy-Item -LiteralPath $sourceImported -Destination (Join-Path $DestinationCache "imported") -Recurse -Force
}

function Test-FoundationJunctionTargetSafe {
    param(
        [string]$ProjectRoot,
        [string]$TargetPath
    )
    $project = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd([char[]]@([char]'\', [char]'/'))
    $target = [System.IO.Path]::GetFullPath($TargetPath).TrimEnd([char[]]@([char]'\', [char]'/'))
    $separator = [System.IO.Path]::DirectorySeparatorChar
    $projectContainsTarget = $target.StartsWith($project + $separator, [System.StringComparison]::OrdinalIgnoreCase)
    $targetContainsProject = $project.StartsWith($target + $separator, [System.StringComparison]::OrdinalIgnoreCase)
    return -not ($project.Equals($target, [System.StringComparison]::OrdinalIgnoreCase) -or $projectContainsTarget -or $targetContainsProject)
}

function Get-FoundationPartialLaunchCleanupTargets {
    param([object[]]$Records)
    $processIds = @()
    $projectRoots = @()
    foreach ($record in @($Records)) {
        if ([bool]$record.process_started -and -not [bool]$record.process_has_exited -and [int]$record.process_id -gt 0) {
            $processIds += [int]$record.process_id
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$record.project_root)) {
            $projectRoots += [string]$record.project_root
        }
    }
    return [pscustomobject]@{
        process_ids = @($processIds)
        project_roots = @($projectRoots)
    }
}

function New-FoundationConcurrencyGuardStage {
    param([string]$Message)
    return [pscustomobject][ordered]@{
        name = "concurrent_godot_guard"
        command = "System.Threading.Mutex"
        arguments = @()
        exit_code = 125
        timed_out = $false
        duration_msec = 0
        stdout = ""
        stderr = ""
        error = $Message
    }
}

function Enter-FoundationWorkspaceMutex {
    param([string]$WorkspaceRoot)
    $rootBytes = [System.Text.Encoding]::UTF8.GetBytes(([System.IO.Path]::GetFullPath($WorkspaceRoot)).ToLowerInvariant())
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = ([System.BitConverter]::ToString($sha.ComputeHash($rootBytes))).Replace("-", "").Substring(0, 24)
    }
    finally {
        $sha.Dispose()
    }
    $name = "Local\BeatTheHouse_CheckGodot_$hash"
    $mutex = New-Object System.Threading.Mutex($false, $name)
    $acquired = $false
    try {
        $acquired = $mutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        $acquired = $true
    }
    if (-not $acquired) {
        $mutex.Dispose()
        $mutex = $null
    }
    return [pscustomobject]@{
        acquired = $acquired
        mutex = $mutex
        name = $name
    }
}

function Exit-FoundationWorkspaceMutex {
    param([object]$Lease)
    if ($null -eq $Lease -or -not [bool]$Lease.acquired -or $null -eq $Lease.mutex) {
        return
    }
    try { $Lease.mutex.ReleaseMutex() } catch { }
    try { $Lease.mutex.Dispose() } catch { }
    $Lease.acquired = $false
    $Lease.mutex = $null
}

function Remove-FoundationShardProjectRoot {
    param(
        [string]$ProjectRoot,
        [string]$AllowedProjectRoot
    )
    if ([string]::IsNullOrWhiteSpace($ProjectRoot) -or -not (Test-Path -LiteralPath $ProjectRoot)) {
        return
    }
    $fullRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
    $allowedRoot = [System.IO.Path]::GetFullPath($AllowedProjectRoot).TrimEnd([char[]]@([char]'\', [char]'/'))
    if (-not $fullRoot.StartsWith($allowedRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove shard project outside allowed root: $fullRoot"
    }
    foreach ($directoryName in @(".agents", "assets", "branding", "data", "docs", "scenes", "scripts", "tools")) {
        $junction = Join-Path $fullRoot $directoryName
        if (Test-Path -LiteralPath $junction) {
            [System.IO.Directory]::Delete($junction, $false)
        }
    }
    Remove-Item -LiteralPath $fullRoot -Recurse -Force
}

function Invoke-FoundationShardResourceCleanup {
    param(
        [object[]]$Records,
        [string]$AllowedProjectRoot
    )
    $failures = New-Object System.Collections.Generic.List[string]
    $cleanupRecords = @()
    foreach ($record in @($Records)) {
        $hasExited = $true
        if ($null -ne $record.process -and $record.process_started) {
            try { $hasExited = [bool]$record.process.HasExited } catch { $hasExited = $false }
        }
        $cleanupRecords += [pscustomobject]@{
            process_started = [bool]$record.process_started
            process_has_exited = $hasExited
            process_id = if ($null -ne $record.process -and $record.process_started) { [int]$record.process.Id } else { 0 }
            project_root = [string]$record.project_root
        }
    }
    $cleanupTargets = Get-FoundationPartialLaunchCleanupTargets -Records $cleanupRecords
    foreach ($processId in @($cleanupTargets.process_ids)) {
        try { Stop-Process -Id $processId -Force -ErrorAction Stop } catch { $failures.Add("Could not stop systems shard process ${processId}: $($_.Exception.Message)") }
    }
    foreach ($record in @($Records)) {
        if ($null -ne $record.process -and $record.process_started) {
            try {
                if (-not $record.process.WaitForExit(5000)) {
                    $failures.Add("Timed out draining systems shard '$($record.shard_id)' process during cleanup.")
                }
            }
            catch { $failures.Add("Could not drain systems shard '$($record.shard_id)' process: $($_.Exception.Message)") }
            if ($null -ne $record.stdout_task) {
                try {
                    if (-not $record.stdout_task.Wait(5000)) {
                        $failures.Add("Timed out draining systems shard '$($record.shard_id)' stdout during cleanup.")
                    }
                }
                catch { $failures.Add("Could not drain systems shard '$($record.shard_id)' stdout: $($_.Exception.Message)") }
            }
            if ($null -ne $record.stderr_task) {
                try {
                    if (-not $record.stderr_task.Wait(5000)) {
                        $failures.Add("Timed out draining systems shard '$($record.shard_id)' stderr during cleanup.")
                    }
                }
                catch { $failures.Add("Could not drain systems shard '$($record.shard_id)' stderr: $($_.Exception.Message)") }
            }
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$record.project_root)) {
            try {
                Remove-FoundationShardProjectRoot -ProjectRoot ([string]$record.project_root) -AllowedProjectRoot $AllowedProjectRoot
                $record.project_root = ""
            }
            catch {
                $failures.Add("Could not remove systems shard '$($record.shard_id)' private project: $($_.Exception.Message)")
            }
        }
    }
    return @($failures)
}

function Complete-FoundationTimedCleanup {
    param(
        [object[]]$Records,
        [string]$AllowedProjectRoot,
        [System.Diagnostics.Stopwatch]$Stopwatch,
        [object]$Report,
        [scriptblock]$CleanupAction,
        [scriptblock]$AfterCleanupCheck
    )
    $failures = @()
    try {
        if ($null -ne $CleanupAction) {
            $failures += @(& $CleanupAction)
        }
        else {
            $failures += @(Invoke-FoundationShardResourceCleanup -Records $Records -AllowedProjectRoot $AllowedProjectRoot)
        }
        if ($null -ne $AfterCleanupCheck) {
            $failures += @(& $AfterCleanupCheck)
        }
    }
    catch {
        $failures += "Systems shard cleanup harness failed: $($_.Exception.Message)"
    }
    finally {
        if ($Stopwatch.IsRunning) {
            $Stopwatch.Stop()
        }
    }
    $Report = Add-FoundationCleanupFailuresToReport -Report $Report -CleanupFailures $failures
    return [pscustomobject]@{
        report = $Report
        failures = @($failures)
    }
}

function New-FoundationHarnessExceptionStage {
    param(
        [string]$GodotPath,
        [string]$Message,
        [int]$DurationMsec,
        [double]$BaselineSec,
        [double]$BudgetSec,
        [string]$StdoutPath,
        [string]$StderrPath
    )
    return [pscustomobject][ordered]@{
        name = "foundation_systems"
        command = $GodotPath
        arguments = @("four deterministic systems shards")
        exit_code = 1
        timed_out = $false
        duration_msec = $DurationMsec
        duration_sec = [Math]::Round($DurationMsec / 1000.0, 3)
        suite_time_baseline_sec = $BaselineSec
        suite_time_budget_sec = $BudgetSec
        suite_time_budget_exceeded = ($BudgetSec -gt 0.0 -and ($DurationMsec / 1000.0) -gt $BudgetSec)
        stderr_issue_count = 1
        stderr_issues = @($Message)
        stdout = $StdoutPath
        stderr = $StderrPath
        error = $Message
    }
}

function Add-FoundationCleanupFailuresToReport {
    param(
        [object]$Report,
        [string[]]$CleanupFailures
    )
    foreach ($failure in @($CleanupFailures)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$failure)) {
            $Report.failures += [string]$failure
        }
    }
    $Report.failure_count = @($Report.failures).Count
    $Report.passed = ($Report.failure_count -eq 0)
    return $Report
}

function Get-FoundationCacheFingerprint {
    param([string]$CacheRoot)
    if (-not (Test-Path -LiteralPath $CacheRoot)) {
        return @()
    }
    $rootPath = [System.IO.Path]::GetFullPath($CacheRoot).TrimEnd([char[]]@([char]'\', [char]'/'))
    return @(Get-ChildItem -LiteralPath $rootPath -Recurse -File -ErrorAction Stop | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($rootPath.Length).TrimStart([char[]]@([char]'\', [char]'/')).Replace("\", "/")
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        "{0}|{1}|{2}" -f $relative, $_.Length, $hash
    })
}

function Resolve-FoundationSystemsExitCode {
    param(
        [object[]]$ShardResults,
        [bool]$AggregatePassed,
        [bool]$BudgetExceeded
    )
    if (@($ShardResults | Where-Object { [bool]$_.timed_out }).Count -gt 0) {
        return 124
    }
    foreach ($shard in $ShardResults) {
        if ([int]$shard.raw_exit_code -ne 0) {
            return [int]$shard.raw_exit_code
        }
    }
    foreach ($shard in $ShardResults) {
        if ([int]$shard.exit_code -eq 127) {
            return 127
        }
    }
    if (-not $AggregatePassed) {
        return 1
    }
    if ($BudgetExceeded) {
        return 126
    }
    return 0
}

function Test-FoundationSystemsShardPlan {
    param(
        [string[]]$ExpectedIds,
        [System.Collections.IDictionary]$Shards
    )
    $errors = New-Object System.Collections.Generic.List[string]
    $expectedSet = @{}
    foreach ($id in $ExpectedIds) {
        if ($expectedSet.ContainsKey($id)) {
            $errors.Add("Expected check id is duplicated: $id")
        }
        $expectedSet[$id] = $true
    }
    $owners = @{}
    foreach ($shardId in $Shards.Keys) {
        $ids = @($Shards[$shardId])
        if ($ids.Count -eq 0) {
            $errors.Add("Shard '$shardId' is empty.")
        }
        foreach ($id in $ids) {
            if (-not $expectedSet.ContainsKey($id)) {
                $errors.Add("Shard '$shardId' contains unknown check id '$id'.")
            }
            if ($owners.ContainsKey($id)) {
                $errors.Add("Check id '$id' has duplicate owners '$($owners[$id])' and '$shardId'.")
            }
            else {
                $owners[$id] = [string]$shardId
            }
        }
    }
    foreach ($id in $ExpectedIds) {
        if (-not $owners.ContainsKey($id)) {
            $errors.Add("Check id '$id' has no shard owner.")
        }
    }
    return [pscustomobject]@{
        valid = ($errors.Count -eq 0)
        errors = @($errors)
        owners = $owners
    }
}

function Merge-FoundationSystemsShardReports {
    param(
        [string[]]$ExpectedIds,
        [object[]]$ShardResults
    )
    $harnessFailures = New-Object System.Collections.Generic.List[string]
    $checksById = @{}
    $executedByShard = [ordered]@{}
    $shardSummaries = @()
    foreach ($shard in $ShardResults) {
        $shardId = [string]$shard.shard_id
        $report = $shard.report
        $executedIds = @()
        if ($null -eq $report) {
            $harnessFailures.Add("Systems shard '$shardId' did not produce a readable report.")
        }
        else {
            if ([string]$report.tool -ne "foundation_check" -or [string]$report.suite -ne "systems") {
                $harnessFailures.Add("Systems shard '$shardId' produced a report with the wrong tool or suite.")
            }
            $registeredIds = @($report.registered_check_ids)
            if (($registeredIds -join "|") -ne ($ExpectedIds -join "|")) {
                $harnessFailures.Add("Systems shard '$shardId' did not observe the canonical systems registration in its original order.")
            }
            foreach ($check in @($report.checks)) {
                $checkId = [string]$check.id
                $executedIds += $checkId
                if ($checksById.ContainsKey($checkId)) {
                    $harnessFailures.Add("Systems shard reports duplicated check id '$checkId'.")
                }
                else {
                    $checksById[$checkId] = $check
                }
                $checkFailures = @($check.failures)
                if ([int]$check.failure_count -ne $checkFailures.Count -or [bool]$check.passed -ne ($checkFailures.Count -eq 0)) {
                    $harnessFailures.Add("Systems shard '$shardId' check '$checkId' has inconsistent failure fields.")
                }
            }
            $expectedShardIds = @($shard.expected_check_ids)
            $requestedIds = @($report.requested_check_ids)
            $reportedExecutedIds = @($report.executed_check_ids)
            if (($requestedIds -join "|") -ne ($expectedShardIds -join "|")) {
                $harnessFailures.Add("Systems shard '$shardId' requested-check evidence diverged from its stable ownership list.")
            }
            if (($executedIds -join "|") -ne ($expectedShardIds -join "|") -or ($reportedExecutedIds -join "|") -ne ($expectedShardIds -join "|")) {
                $harnessFailures.Add("Systems shard '$shardId' executed checks outside its canonical owned order.")
            }
            $attachedFailures = @($report.checks | ForEach-Object { @($_.failures) })
            if ((@($report.failures) -join "`n") -ne ($attachedFailures -join "`n")) {
                $harnessFailures.Add("Systems shard '$shardId' report-level failures diverged from its ordered check failures.")
            }
            if ([int]$report.failure_count -ne @($report.failures).Count -or [bool]$report.passed -ne (@($report.failures).Count -eq 0)) {
                $harnessFailures.Add("Systems shard '$shardId' has inconsistent report-level failure fields.")
            }
        }
        $executedByShard[$shardId] = $executedIds
        $expectedShardIds = @($shard.expected_check_ids)
        foreach ($expectedId in $expectedShardIds) {
            if ($executedIds -notcontains $expectedId) {
                $harnessFailures.Add("Systems shard '$shardId' did not execute owned check id '$expectedId'.")
            }
        }
        foreach ($executedId in $executedIds) {
            if ($expectedShardIds -notcontains $executedId) {
                $harnessFailures.Add("Systems shard '$shardId' executed unowned check id '$executedId'.")
            }
        }
        if ([int]$shard.exit_code -ne 0 -and ($null -eq $report -or [bool]$report.passed)) {
            $harnessFailures.Add("Systems shard '$shardId' exited with code $([int]$shard.exit_code).")
        }
        if (@($shard.stderr_issues).Count -gt 0) {
            $harnessFailures.Add("Systems shard '$shardId' emitted $(@($shard.stderr_issues).Count) error/warning line(s) on stderr.")
        }
        $shardSummaries += [ordered]@{
            id = $shardId
            exit_code = [int]$shard.exit_code
            raw_exit_code = [int]$shard.raw_exit_code
            timed_out = [bool]$shard.timed_out
            duration_msec = [int]$shard.duration_msec
            report = [string]$shard.report_path
            stdout = [string]$shard.stdout_path
            stderr = [string]$shard.stderr_path
            stderr_issue_count = @($shard.stderr_issues).Count
            stderr_issues = @($shard.stderr_issues)
            last_started_check = if ($null -ne $report) { [string]$report.last_started_check } else { [string]$shard.last_started_check }
            report_available = ($null -ne $report)
            executed_check_ids = $executedIds
        }
    }
    $coverage = Test-FoundationSystemsShardPlan -ExpectedIds $ExpectedIds -Shards $executedByShard
    foreach ($error in @($coverage.errors)) {
        $harnessFailures.Add([string]$error)
    }
    $orderedChecks = @()
    foreach ($id in $ExpectedIds) {
        if ($checksById.ContainsKey($id)) {
            $orderedChecks += $checksById[$id]
        }
    }
    $failures = New-Object System.Collections.Generic.List[string]
    foreach ($check in $orderedChecks) {
        foreach ($failure in @($check.failures)) {
            $failures.Add([string]$failure)
        }
    }
    foreach ($failure in $harnessFailures) {
        $failures.Add([string]$failure)
    }
    $lastStarted = ""
    if ($orderedChecks.Count -eq $ExpectedIds.Count) {
        $lastStarted = [string]$ExpectedIds[$ExpectedIds.Count - 1]
    }
    else {
        $fatalCandidates = @($shardSummaries | Where-Object { $_.exit_code -ne 0 -or -not $_.report_available } | ForEach-Object { [string]$_.last_started_check } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        foreach ($id in $ExpectedIds) {
            if ($fatalCandidates -contains $id) {
                $lastStarted = $id
                break
            }
        }
    }
    $passed = ($failures.Count -eq 0)
    $mergedReport = [ordered]@{
        tool = "foundation_check"
        suite = "systems"
        sharded = $true
        shard_count = $ShardResults.Count
        started_msec = 0
        duration_msec = 0
        passed = $passed
        failure_count = $failures.Count
        failures = @($failures)
        checks = $orderedChecks
        skipped = @()
        last_started_check = $lastStarted
        registered_check_ids = @($ExpectedIds)
        requested_check_ids = @($ExpectedIds)
        executed_check_ids = @($orderedChecks | ForEach-Object { [string]$_.id })
        shards = $shardSummaries
    }
    return [pscustomobject]@{
        passed = $passed
        exit_code = if ($passed) { 0 } else { 1 }
        report = $mergedReport
        errors = @($failures)
    }
}
