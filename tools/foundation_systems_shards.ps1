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

function Get-FoundationSystemsCheckIds {
    return @($script:FoundationSystemsCheckIds)
}

function Get-FoundationSystemsShardPlan {
    return $script:FoundationSystemsShardPlan
}

function Get-FoundationSystemsUserPathOwners {
    return $script:FoundationSystemsUserPathOwners
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
        if ([int]$shard.exit_code -ne 0) {
            return [int]$shard.exit_code
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
            timed_out = [bool]$shard.timed_out
            duration_msec = [int]$shard.duration_msec
            report = [string]$shard.report_path
            stdout = [string]$shard.stdout_path
            stderr = [string]$shard.stderr_path
            stderr_issue_count = @($shard.stderr_issues).Count
            stderr_issues = @($shard.stderr_issues)
            last_started_check = if ($null -ne $report) { [string]$report.last_started_check } else { [string]$shard.last_started_check }
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
        $fatalCandidates = @($shardSummaries | Where-Object { $_.exit_code -ne 0 } | ForEach-Object { [string]$_.last_started_check } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
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
