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

$guard = New-FoundationConcurrencyGuardStage -Message "hostile contention"
Assert-True ($guard.name -eq "concurrent_godot_guard" -and $guard.exit_code -eq 125 -and $guard.error -eq "hostile contention") "Mutex contention did not create the established guard stage/exit 125 evidence."
$mutexWorkspace = Join-Path ([System.IO.Path]::GetTempPath()) ("bth_mutex_hostile_" + [Guid]::NewGuid().ToString("N"))
$mutexLease = Enter-FoundationWorkspaceMutex -WorkspaceRoot $mutexWorkspace
try {
    Assert-True $mutexLease.acquired "Hostile mutex setup could not acquire its unique workspace lock."
    $modulePath = (Join-Path $PSScriptRoot "foundation_systems_shards.ps1").Replace("'", "''")
    $childWorkspace = $mutexWorkspace.Replace("'", "''")
    $mutexProbeCommand = ". '$modulePath'; `$lease = Enter-FoundationWorkspaceMutex -WorkspaceRoot '$childWorkspace'; if (`$lease.acquired) { Exit-FoundationWorkspaceMutex -Lease `$lease; 'ACQUIRED' } else { 'CONTENDED' }"
    $mutexProbeOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -Command $mutexProbeCommand)
    Assert-True ($LASTEXITCODE -eq 0 -and $mutexProbeOutput[-1] -eq "CONTENDED") "A real second process acquired the already-owned workspace mutex."
}
finally {
    Exit-FoundationWorkspaceMutex -Lease $mutexLease
}
$postReleaseLease = Enter-FoundationWorkspaceMutex -WorkspaceRoot $mutexWorkspace
try {
    Assert-True $postReleaseLease.acquired "Workspace mutex remained locked after releasing the hostile owner."
}
finally {
    Exit-FoundationWorkspaceMutex -Lease $postReleaseLease
}

$hostileRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("bth_cleanup_hostile_" + [Guid]::NewGuid().ToString("N"))
$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd([char[]]@([char]'\', [char]'/'))
$hostileFull = [System.IO.Path]::GetFullPath($hostileRoot)
Assert-True $hostileFull.StartsWith($tempBase + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) "Hostile cleanup root escaped the OS temporary directory."
$allowedProjects = Join-Path $hostileRoot "projects"
$disposableProject = Join-Path $allowedProjects "partial"
$junctionTarget = Join-Path $hostileRoot "target"
$sentinelPath = Join-Path $junctionTarget "sentinel.txt"
$benignChild = $null
try {
    New-Item -ItemType Directory -Force -Path $disposableProject | Out-Null
    New-Item -ItemType Directory -Force -Path $junctionTarget | Out-Null
    [System.IO.File]::WriteAllText($sentinelPath, "survives")
    New-Item -ItemType Junction -Path (Join-Path $disposableProject "scripts") -Target $junctionTarget | Out-Null
    $childStart = New-Object System.Diagnostics.ProcessStartInfo
    $childStart.FileName = (Get-Command powershell -ErrorAction Stop).Source
    $childStart.Arguments = '-NoProfile -Command "Start-Sleep -Seconds 30"'
    $childStart.UseShellExecute = $false
    $childStart.CreateNoWindow = $true
    $benignChild = [System.Diagnostics.Process]::Start($childStart)
    $partialRecord = [pscustomobject]@{
        shard_id = "hostile_partial"
        process = $benignChild
        process_started = $true
        stdout_task = $null
        stderr_task = $null
        project_root = $disposableProject
    }
    $actualCleanupFailures = @(Invoke-FoundationShardResourceCleanup -Records @($partialRecord) -AllowedProjectRoot $allowedProjects)
    $benignChild.Refresh()
    Assert-True ($actualCleanupFailures.Count -eq 0) ("Real partial-launch cleanup failed: " + ($actualCleanupFailures -join " | "))
    Assert-True $benignChild.HasExited "Real partial-launch cleanup left its benign child running."
    Assert-True (-not (Test-Path -LiteralPath $disposableProject)) "Real partial-launch cleanup left its private project behind."
    Assert-True ((Test-Path -LiteralPath $sentinelPath) -and [System.IO.File]::ReadAllText($sentinelPath) -eq "survives") "Junction cleanup damaged the source target sentinel."
    Assert-True ([string]::IsNullOrWhiteSpace([string]$partialRecord.project_root)) "Successful cleanup did not retire the record's private-project ownership."
}
finally {
    if ($null -ne $benignChild) {
        try { if (-not $benignChild.HasExited) { Stop-Process -Id $benignChild.Id -Force -ErrorAction SilentlyContinue } } catch { }
    }
    if (Test-Path -LiteralPath $disposableProject) {
        Remove-FoundationShardProjectRoot -ProjectRoot $disposableProject -AllowedProjectRoot $allowedProjects
    }
    if (Test-Path -LiteralPath $hostileRoot) {
        Remove-Item -LiteralPath $hostileRoot -Recurse -Force
    }
}

$exceptionStage = New-FoundationHarnessExceptionStage -GodotPath "godot" -Message "hostile launch failure" -DurationMsec 2500 -BaselineSec 10.0 -BudgetSec 20.0 -StdoutPath "out" -StderrPath "err"
Assert-True ($exceptionStage.name -eq "foundation_systems" -and $exceptionStage.exit_code -eq 1 -and $exceptionStage.error -eq "hostile launch failure" -and $exceptionStage.duration_sec -eq 2.5) "Harness exception did not retain honest foundation_systems stage evidence."
Assert-True ($checkGodotSource.Contains('New-FoundationHarnessExceptionStage')) "Shard exception path does not consume the validated failure-stage contract."
$cleanupFailureReport = [pscustomobject]@{ passed = $true; failure_count = 0; failures = @() }
$cleanupClock = [System.Diagnostics.Stopwatch]::StartNew()
$cleanupCompletion = Complete-FoundationTimedCleanup -Records @() -AllowedProjectRoot $allowedProjects -Stopwatch $cleanupClock -Report $cleanupFailureReport -CleanupAction { Start-Sleep -Milliseconds 75; @("hostile cleanup failure") }
$cleanupFailureReport = $cleanupCompletion.report
Assert-True (-not $cleanupFailureReport.passed -and $cleanupFailureReport.failure_count -eq 1 -and $cleanupFailureReport.failures[0] -eq "hostile cleanup failure") "Cleanup failure did not deterministically fail the aggregate report."
Assert-True (-not $cleanupClock.IsRunning -and $cleanupClock.ElapsedMilliseconds -ge 70) "Timed cleanup stopped its stage clock before the cleanup action completed."
$cleanupFailureExit = Resolve-FoundationSystemsExitCode -ShardResults @([pscustomobject]@{ exit_code = 0; raw_exit_code = 0; timed_out = $false }) -AggregatePassed ([bool]$cleanupFailureReport.passed) -BudgetExceeded $false
Assert-True ($cleanupFailureExit -eq 1) "Cleanup failure report did not force a nonzero systems stage exit."

$fakeProject = Join-Path $projectRoot ".tmp/test_reports/fake_shard"
Assert-True (-not (Test-FoundationJunctionTargetSafe -ProjectRoot $fakeProject -TargetPath (Join-Path $projectRoot ".tmp"))) "Ancestor .tmp junction cycle was accepted."
Assert-True (Test-FoundationJunctionTargetSafe -ProjectRoot $fakeProject -TargetPath (Join-Path $projectRoot "scripts")) "Disjoint read-only source junction was rejected."
Assert-True (-not $checkGodotSource.Contains('@(".agents", ".tmp",')) "Shard project still junctions its ancestor .tmp report tree."
Assert-True ($checkGodotSource.Contains('Copy-Item -LiteralPath $sourceImported -Destination (Join-Path $shardCache "imported") -Recurse -Force')) "Shard imported cache is not physically private."

if (-not $Quiet) {
    Write-Host "Foundation systems shard hostile contracts passed."
}
