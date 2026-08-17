param([switch]$Quiet)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "foundation_systems_shards.ps1")

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

$productionPlan = Test-FoundationSystemsShardPlan -ExpectedIds (Get-FoundationSystemsCheckIds) -Shards (Get-FoundationSystemsShardPlan)
Assert-True $productionPlan.valid ("Production systems shard plan is invalid: " + (@($productionPlan.errors) -join " | "))

$runnerSource = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) "scripts/tests/foundation/check_core_content.gd") -Raw
$systemsMatch = [regex]::Match($runnerSource, '(?s)func _foundation_run_system_suite\(.*?(?=\nfunc _foundation_run_all_suite\()')
Assert-True $systemsMatch.Success "Could not locate the systems registration in the foundation runner source."
$registeredIds = @([regex]::Matches($systemsMatch.Value, '_foundation_run_check\(report, failures, "([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-True (($registeredIds -join "|") -eq ((Get-FoundationSystemsCheckIds) -join "|")) "Shard manifest diverged from the systems registration or changed its canonical order."

$missingPlan = [ordered]@{ first = @("alpha"); second = @() }
$missingResult = Test-FoundationSystemsShardPlan -ExpectedIds @("alpha", "beta") -Shards $missingPlan
Assert-True (-not $missingResult.valid) "Hostile missing-id shard plan was accepted."
Assert-True ((@($missingResult.errors) -join " | ").Contains("beta")) "Missing-id diagnostic did not identify beta."

$duplicatePlan = [ordered]@{ first = @("alpha"); second = @("alpha", "beta") }
$duplicateResult = Test-FoundationSystemsShardPlan -ExpectedIds @("alpha", "beta") -Shards $duplicatePlan
Assert-True (-not $duplicateResult.valid) "Hostile duplicate-id shard plan was accepted."
Assert-True ((@($duplicateResult.errors) -join " | ").Contains("duplicate owners")) "Duplicate-id diagnostic did not identify both owners."

$failedReport = [pscustomobject]@{
    tool = "foundation_check"
    suite = "systems"
    passed = $false
    failure_count = 1
    failures = @("hostile shard assertion")
    checks = @([pscustomobject]@{ id = "alpha"; duration_msec = 1; failure_count = 1; failures = @("hostile shard assertion") })
    last_started_check = "alpha"
    registered_check_ids = @("alpha", "beta")
    requested_check_ids = @("alpha")
    executed_check_ids = @("alpha")
}
$passedReport = [pscustomobject]@{
    tool = "foundation_check"
    suite = "systems"
    passed = $true
    failure_count = 0
    failures = @()
    checks = @([pscustomobject]@{ id = "beta"; duration_msec = 1; failure_count = 0; failures = @() })
    last_started_check = "beta"
    registered_check_ids = @("alpha", "beta")
    requested_check_ids = @("beta")
    executed_check_ids = @("beta")
}
$aggregate = Merge-FoundationSystemsShardReports -ExpectedIds @("alpha", "beta") -ShardResults @(
    [pscustomobject]@{ shard_id = "first"; expected_check_ids = @("alpha"); exit_code = 1; raw_exit_code = 1; timed_out = $false; duration_msec = 2; report = $failedReport; report_path = "first.json"; stdout_path = "first.out"; stderr_path = "first.err"; stderr_issues = @(); last_started_check = "alpha" },
    [pscustomobject]@{ shard_id = "second"; expected_check_ids = @("beta"); exit_code = 0; raw_exit_code = 0; timed_out = $false; duration_msec = 2; report = $passedReport; report_path = "second.json"; stdout_path = "second.out"; stderr_path = "second.err"; stderr_issues = @(); last_started_check = "beta" }
)
Assert-True (-not $aggregate.passed) "Aggregate accepted a failing shard report."
Assert-True ($aggregate.exit_code -ne 0) "Aggregate failure did not propagate a nonzero exit code."
Assert-True ((@($aggregate.report.failures) -join " | ").Contains("hostile shard assertion")) "Aggregate dropped the shard assertion failure."
Assert-True ($aggregate.report.checks.Count -eq 2) "Aggregate dropped executed check evidence while propagating failure."

$unknownPlan = [ordered]@{ first = @("alpha", "intruder"); second = @("beta") }
$unknownResult = Test-FoundationSystemsShardPlan -ExpectedIds @("alpha", "beta") -Shards $unknownPlan
Assert-True (-not $unknownResult.valid) "Hostile unknown-id shard plan was accepted."
Assert-True ((@($unknownResult.errors) -join " | ").Contains("unknown")) "Unknown-id diagnostic was not explicit."

$noReport = Merge-FoundationSystemsShardReports -ExpectedIds @("alpha") -ShardResults @(
    [pscustomobject]@{ shard_id = "missing"; expected_check_ids = @("alpha"); exit_code = 0; raw_exit_code = 0; timed_out = $false; duration_msec = 1; report = $null; report_path = "missing.json"; stdout_path = "missing.out"; stderr_path = "missing.err"; stderr_issues = @(); last_started_check = "alpha" }
)
Assert-True (-not $noReport.passed) "Missing child report was accepted."
Assert-True ($noReport.report.last_started_check -eq "alpha") "Missing-report aggregate dropped stdout-derived last-started evidence."

$orderDriftReport = [pscustomobject]@{
    tool = "foundation_check"; suite = "systems"; passed = $true; failure_count = 0; failures = @();
    checks = @(
        [pscustomobject]@{ id = "beta"; duration_msec = 1; failure_count = 0; failures = @(); passed = $true },
        [pscustomobject]@{ id = "alpha"; duration_msec = 1; failure_count = 0; failures = @(); passed = $true }
    );
    last_started_check = "alpha"; registered_check_ids = @("alpha", "beta"); requested_check_ids = @("alpha", "beta"); executed_check_ids = @("beta", "alpha")
}
$orderDrift = Merge-FoundationSystemsShardReports -ExpectedIds @("alpha", "beta") -ShardResults @(
    [pscustomobject]@{ shard_id = "drift"; expected_check_ids = @("alpha", "beta"); exit_code = 0; raw_exit_code = 0; timed_out = $false; duration_msec = 1; report = $orderDriftReport; report_path = "drift.json"; stdout_path = "drift.out"; stderr_path = "drift.err"; stderr_issues = @(); last_started_check = "alpha" }
)
Assert-True (-not $orderDrift.passed) "Out-of-order child report was accepted and hidden by canonical aggregate sorting."

Assert-True ((Resolve-FoundationSystemsExitCode -ShardResults @([pscustomobject]@{ exit_code = 37; raw_exit_code = 37; timed_out = $false }) -AggregatePassed $false -BudgetExceeded $false) -eq 37) "Native/nonstandard child exit code was collapsed."
Assert-True ((Resolve-FoundationSystemsExitCode -ShardResults @([pscustomobject]@{ exit_code = 124; raw_exit_code = 124; timed_out = $true }) -AggregatePassed $false -BudgetExceeded $true) -eq 124) "Timeout did not retain exit-code precedence."
Assert-True ((Resolve-FoundationSystemsExitCode -ShardResults @([pscustomobject]@{ exit_code = 127; raw_exit_code = 0; timed_out = $false }) -AggregatePassed $false -BudgetExceeded $false) -eq 127) "Stderr-only failure did not retain exit code 127."
Assert-True ((Resolve-FoundationSystemsExitCode -ShardResults @([pscustomobject]@{ exit_code = 0; raw_exit_code = 0; timed_out = $false }) -AggregatePassed $true -BudgetExceeded $true) -eq 126) "Wall-budget failure did not retain exit code 126."
$mixedExit = Resolve-FoundationSystemsExitCode -ShardResults @(
    [pscustomobject]@{ exit_code = 127; raw_exit_code = 0; timed_out = $false },
    [pscustomobject]@{ exit_code = 1; raw_exit_code = 1; timed_out = $false }
) -AggregatePassed $false -BudgetExceeded $false
Assert-True ($mixedExit -eq 1) "Synthesized stderr exit 127 hid a genuine child process failure."

$pathOwners = Get-FoundationSystemsUserPathOwners
$knownChecks = Get-FoundationSystemsCheckIds
foreach ($path in $pathOwners.Keys) {
    Assert-True ([string]$path).StartsWith("user://") "Shard persistence ownership contains a non-user path: $path"
    Assert-True ($knownChecks -contains [string]$pathOwners[$path]) "Shard persistence path '$path' has an unknown owning check."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$foundationSources = @(
    (Join-Path $projectRoot "scripts/tests/foundation/check_core_content.gd")
    (Join-Path $projectRoot "scripts/tests/foundation/check_items_events_world.gd")
    (Join-Path $projectRoot "scripts/tests/foundation/check_lenders_release_saves.gd")
)
$foundationSourceText = ($foundationSources | ForEach-Object { Get-Content -LiteralPath $_ -Raw }) -join "`n"
$literalUserPaths = @([regex]::Matches($foundationSourceText, 'user://[^"\s]+') | ForEach-Object { $_.Value } | Sort-Object -Unique)
$ownedLiteralPaths = @($pathOwners.Keys | Where-Object { -not ([string]$_).StartsWith("user://saves/") } | Sort-Object)
Assert-True (($literalUserPaths -join "|") -eq ($ownedLiteralPaths -join "|")) "Systems foundation source user:// literals diverged from the explicit shard ownership table."
$saveServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot "scripts/core/save_service.gd") -Raw
foreach ($slotId in @("foundation_save_round_trip", "foundation_save_atomic_recovery")) {
    Assert-True $foundationSourceText.Contains(('var slot_id := "' + $slotId + '"')) "Systems source no longer exposes save slot '$slotId' for ownership validation."
    Assert-True $pathOwners.Contains("user://saves/$slotId.json") "Derived SaveService user path for '$slotId' has no shard owner."
}
Assert-True ($saveServiceSource.Contains('const SAVE_DIR := "user://saves"') -and $saveServiceSource.Contains('"%s.tmp"') -and $saveServiceSource.Contains('"%s.bak"')) "SaveService derived .tmp/.bak persistence targets are no longer covered by the owned save slots."

$tempCache = Join-Path ([System.IO.Path]::GetTempPath()) ("bth_shard_cache_" + [Guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Force -Path $tempCache | Out-Null
    $cacheFile = Join-Path $tempCache "same_length.bin"
    [System.IO.File]::WriteAllText($cacheFile, "AAAA")
    $beforeCache = Get-FoundationCacheFingerprint -CacheRoot $tempCache
    [System.IO.File]::WriteAllText($cacheFile, "BBBB")
    $afterCache = Get-FoundationCacheFingerprint -CacheRoot $tempCache
    Assert-True (($beforeCache -join "|") -ne ($afterCache -join "|")) "SHA-256 cache sentinel missed a same-length content mutation."
}
finally {
    if (Test-Path -LiteralPath $tempCache) {
        Remove-Item -LiteralPath $tempCache -Recurse -Force
    }
}

$requiredLibraryFields = @("_load_errors", "_indexes", "_load_timing", "_load_pack_timings")
foreach ($field in $requiredLibraryFields) {
    Assert-True $runnerSource.Contains(('"' + $field + '": library.' + $field)) "Exact ContentLibrary fingerprint omitted $field."
}

$checkGodotSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot "check_godot.ps1") -Raw
$expectedOverrides = @("BTH_DISTRIBUTION_DATA_ROOT", "BTH_DISTRIBUTION_BUILD", "BTH_META_COLLECTION_PATH", "BTH_PROFILE_INVENTORY_PATH")
Assert-True (((Get-FoundationShardClearedEnvironmentNames) -join "|") -eq ($expectedOverrides -join "|")) "Shard persistence override clearing list is incomplete or reordered."
Assert-True ($checkGodotSource.Contains('foreach ($overrideName in Get-FoundationShardClearedEnvironmentNames)')) "Shard launcher does not consume the validated persistence override list."

$cleanupPlan = Get-FoundationPartialLaunchCleanupTargets -Records @(
    [pscustomobject]@{ process_started = $false; process_has_exited = $false; process_id = 11; project_root = "first" },
    [pscustomobject]@{ process_started = $true; process_has_exited = $false; process_id = 22; project_root = "second" },
    [pscustomobject]@{ process_started = $true; process_has_exited = $true; process_id = 33; project_root = "third" }
)
Assert-True ((@($cleanupPlan.process_ids) -join "|") -eq "22") "Partial-launch cleanup did not select exactly the live child process."
Assert-True ((@($cleanupPlan.project_roots) -join "|") -eq "first|second|third") "Partial-launch cleanup dropped a prepared shard project root."
Assert-True ($checkGodotSource.Contains('Get-FoundationPartialLaunchCleanupTargets -Records $cleanupRecords')) "Shard launcher does not consume the simulated partial-launch cleanup contract."

$guard = New-FoundationConcurrencyGuardStage -Message "hostile contention"
Assert-True ($guard.name -eq "concurrent_godot_guard" -and $guard.exit_code -eq 125 -and $guard.error -eq "hostile contention") "Mutex contention did not create the established guard stage/exit 125 evidence."
Assert-True ($checkGodotSource.Contains('New-FoundationConcurrencyGuardStage -Message $message')) "Workspace-mutex contention path does not consume the validated guard result."
$exceptionStage = New-FoundationHarnessExceptionStage -GodotPath "godot" -Message "hostile launch failure" -DurationMsec 2500 -BaselineSec 10.0 -BudgetSec 20.0 -StdoutPath "out" -StderrPath "err"
Assert-True ($exceptionStage.name -eq "foundation_systems" -and $exceptionStage.exit_code -eq 1 -and $exceptionStage.error -eq "hostile launch failure" -and $exceptionStage.duration_sec -eq 2.5) "Harness exception did not retain honest foundation_systems stage evidence."
Assert-True ($checkGodotSource.Contains('New-FoundationHarnessExceptionStage')) "Shard exception path does not consume the validated failure-stage contract."

$fakeProject = Join-Path $projectRoot ".tmp/test_reports/fake_shard"
Assert-True (-not (Test-FoundationJunctionTargetSafe -ProjectRoot $fakeProject -TargetPath (Join-Path $projectRoot ".tmp"))) "Ancestor .tmp junction cycle was accepted."
Assert-True (Test-FoundationJunctionTargetSafe -ProjectRoot $fakeProject -TargetPath (Join-Path $projectRoot "scripts")) "Disjoint read-only source junction was rejected."
Assert-True (-not $checkGodotSource.Contains('@(".agents", ".tmp",')) "Shard project still junctions its ancestor .tmp report tree."
Assert-True ($checkGodotSource.Contains('Copy-Item -LiteralPath $sourceImported -Destination (Join-Path $shardCache "imported") -Recurse -Force')) "Shard imported cache is not physically private."
Assert-True ($checkGodotSource.Contains('Remove-Item -LiteralPath $junction -Force')) "Shard cleanup does not unlink source junctions before recursive removal."

if (-not $Quiet) {
    Write-Host "Foundation systems shard hostile contracts passed."
}
