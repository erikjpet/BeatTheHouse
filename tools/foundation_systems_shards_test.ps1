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
$fixtureMatch = [regex]::Match($foundationSourceText, '(?s)func _fixture_library\(failures: Array\) -> ContentLibrary:(.*?)(?=\r?\n\r?\nfunc )')
Assert-True ($fixtureMatch.Success -and $fixtureMatch.Value.IndexOf('before_hydration := _foundation_library_fingerprint(library)') -ge 0 -and $fixtureMatch.Value.IndexOf('library._rebuild_indexes()') -gt $fixtureMatch.Value.IndexOf('before_hydration :=') -and $fixtureMatch.Value.IndexOf('library._rebuild_indexes()') -lt $fixtureMatch.Value.LastIndexOf('return library')) "Fixture ContentLibrary is not fully indexed before the immutable baseline captures it."
$hostileFixtureMatch = [regex]::Match($foundationSourceText.Replace('library._rebuild_indexes()', '# hostile fixture omitted hydration'), '(?s)func _fixture_library\(failures: Array\) -> ContentLibrary:(.*?)(?=\r?\n\r?\nfunc )')
Assert-True (-not ($hostileFixtureMatch.Success -and $hostileFixtureMatch.Value.IndexOf('library._rebuild_indexes()') -gt $hostileFixtureMatch.Value.IndexOf('before_hydration :=') -and $hostileFixtureMatch.Value.IndexOf('library._rebuild_indexes()') -lt $hostileFixtureMatch.Value.LastIndexOf('return library'))) "Hostile combined-source fixture without hydration was accepted."
Assert-True ($fixtureMatch.Value.Contains('_foundation_library_fingerprint(library, false)') -and $fixtureMatch.Value.Contains('changed state outside the lazy index cache')) "Fixture hydration regression no longer proves that only the lazy index cache changes."
Assert-True $runnerSource.Contains('var fixture_library := _fixture_library(failures)') "Foundation runner no longer reports hostile unhydrated-fixture regression failures."
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
$validateProjectSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot "validate_project.ps1") -Raw
$surfaceGuardDirectPattern = [regex]'\bsurface\s*\.\s*((?:surface|draw)_[A-Za-z0-9_]+)\s*\('
$surfaceGuardDynamicPattern = [regex]'\bsurface\s*\.\s*(?:call|has_method)\s*\(\s*["''](surface_[A-Za-z0-9_]+)["'']'
Assert-True ($validateProjectSource.Contains('$directSurfaceCallPattern = [regex]') -and $validateProjectSource.Contains('$dynamicSurfaceCallPattern = [regex]') -and $validateProjectSource.Contains('foreach ($callMatch in @($directSurfaceCallPattern.Matches($gameSource)) + @($dynamicSurfaceCallPattern.Matches($gameSource)))')) "Static SurfaceHarness parity guard patterns changed without updating their hostile contract."
Assert-True ($surfaceGuardDirectPattern.Match('surface.surface_add_exact_hover_hit(rect, "action")').Groups[1].Value -eq "surface_add_exact_hover_hit") "Static SurfaceHarness parity guard missed a direct surface call."
Assert-True ($surfaceGuardDirectPattern.Match('surface . draw_arc(center, radius)').Groups[1].Value -eq "draw_arc") "Static SurfaceHarness parity guard missed a whitespace-separated draw call."
Assert-True ($surfaceGuardDynamicPattern.Match('surface.call("surface_runtime_status")').Groups[1].Value -eq "surface_runtime_status") "Static SurfaceHarness parity guard missed a literal dynamic call."
Assert-True ($surfaceGuardDynamicPattern.Match("surface.has_method('surface_runtime_status')").Groups[1].Value -eq "surface_runtime_status") "Static SurfaceHarness parity guard missed a literal has_method call."
Assert-True (-not $surfaceGuardDirectPattern.IsMatch('surface_alias.surface_add_exact_hover_hit(rect, "action")')) "Static SurfaceHarness parity guard exceeded its documented surface-identifier scope."
Assert-True (-not $surfaceGuardDynamicPattern.IsMatch('surface.call(method_name)')) "Static SurfaceHarness parity guard treated a computed method name as discoverable."
$expectedOverrides = @("BTH_DISTRIBUTION_DATA_ROOT", "BTH_DISTRIBUTION_BUILD", "BTH_META_COLLECTION_PATH", "BTH_PROFILE_INVENTORY_PATH")
Assert-True (((Get-FoundationShardClearedEnvironmentNames) -join "|") -eq ($expectedOverrides -join "|")) "Shard persistence override clearing list is incomplete or reordered."
Assert-True ($checkGodotSource.Contains('foreach ($overrideName in Get-FoundationShardClearedEnvironmentNames)')) "Shard launcher does not consume the validated persistence override list."

$cacheIsolationRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("bth_shard_cache_isolation_" + [Guid]::NewGuid().ToString("N"))
$sourceCacheRoot = Join-Path $cacheIsolationRoot "source"
$privateCacheRoot = Join-Path $cacheIsolationRoot "private"
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $sourceCacheRoot "imported") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $sourceCacheRoot "shader_cache\volatile") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $sourceCacheRoot "editor") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $sourceCacheRoot "exported") | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $sourceCacheRoot "imported\asset.ctex"), "IMPORTED_SOURCE")
    [System.IO.File]::WriteAllText((Join-Path $sourceCacheRoot "global_script_class_cache.cfg"), "CLASS_SOURCE")
    [System.IO.File]::WriteAllText((Join-Path $sourceCacheRoot "uid_cache.bin"), "UID_SOURCE")
    [System.IO.File]::WriteAllText((Join-Path $sourceCacheRoot "shader_cache\volatile\hostile.vulkan.cache"), "VOLATILE")
    [System.IO.File]::WriteAllText((Join-Path $sourceCacheRoot "editor\hostile.cache"), "EDITOR")
    [System.IO.File]::WriteAllText((Join-Path $sourceCacheRoot "exported\hostile.cache"), "EXPORTED")

    Copy-FoundationShardCache -SourceCache $sourceCacheRoot -DestinationCache $privateCacheRoot

    Assert-True ([System.IO.File]::ReadAllText((Join-Path $privateCacheRoot "imported\asset.ctex")) -eq "IMPORTED_SOURCE") "Shard cache isolation dropped required imported data."
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $privateCacheRoot "global_script_class_cache.cfg")) -eq "CLASS_SOURCE") "Shard cache isolation dropped the stable script-class cache."
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $privateCacheRoot "uid_cache.bin")) -eq "UID_SOURCE") "Shard cache isolation dropped the stable UID cache."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $privateCacheRoot "shader_cache"))) "Shard cache isolation traversed/copied the volatile shader cache."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $privateCacheRoot "editor"))) "Shard cache isolation traversed/copied the volatile editor cache."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $privateCacheRoot "exported"))) "Shard cache isolation traversed/copied the volatile export cache."
    [System.IO.File]::WriteAllText((Join-Path $privateCacheRoot "imported\asset.ctex"), "PRIVATE_MUTATION")
    [System.IO.File]::WriteAllText((Join-Path $privateCacheRoot "uid_cache.bin"), "PRIVATE_UID_MUTATION")
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $sourceCacheRoot "imported\asset.ctex")) -eq "IMPORTED_SOURCE") "Shard imported cache is not a physical private copy."
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $sourceCacheRoot "uid_cache.bin")) -eq "UID_SOURCE") "Shard stable cache files are not physical private copies."
}
finally {
    if (Test-Path -LiteralPath $cacheIsolationRoot) {
        Remove-Item -LiteralPath $cacheIsolationRoot -Recurse -Force
    }
}

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

function Invoke-HostileNestedCacheCompletion {
    param(
        [string]$CacheRoot,
        [bool]$MutateAfterBaseline
    )
    $cacheBefore = @(Get-FoundationCacheFingerprint -CacheRoot $CacheRoot)
    if ($MutateAfterBaseline) {
        [System.IO.File]::WriteAllText((Join-Path $CacheRoot "sentinel.cache"), "MUTATED")
    }
    $cacheCheck = {
        if (($cacheBefore -join "`n") -ne ((Get-FoundationCacheFingerprint -CacheRoot $CacheRoot) -join "`n")) {
            return @("hostile parent cache mutation detected")
        }
        return @()
    }
    $report = [pscustomobject]@{ passed = $true; failure_count = 0; failures = @() }
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    return Complete-FoundationTimedCleanup -Records @() -AllowedProjectRoot $allowedProjects -Stopwatch $clock -Report $report -AfterCleanupCheck $cacheCheck
}

$nestedCacheRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("bth_nested_cache_check_" + [Guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Force -Path $nestedCacheRoot | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $nestedCacheRoot "sentinel.cache"), "BASELINE")
    $cleanNestedCompletion = Invoke-HostileNestedCacheCompletion -CacheRoot $nestedCacheRoot -MutateAfterBaseline $false
    Assert-True ([bool]$cleanNestedCompletion.report.passed) "Nested post-cleanup cache callback could not resolve its fingerprint seam or enclosing baseline."
    $mutatedNestedCompletion = Invoke-HostileNestedCacheCompletion -CacheRoot $nestedCacheRoot -MutateAfterBaseline $true
    Assert-True (-not [bool]$mutatedNestedCompletion.report.passed) "Nested post-cleanup cache callback did not fail closed on a real parent-cache mutation."
    Assert-True ((@($mutatedNestedCompletion.failures) -join " | ").Contains("hostile parent cache mutation detected")) "Nested post-cleanup cache callback dropped its mutation diagnostic."
}
finally {
    if (Test-Path -LiteralPath $nestedCacheRoot) {
        Remove-Item -LiteralPath $nestedCacheRoot -Recurse -Force
    }
}

$fakeProject = Join-Path $projectRoot ".tmp/test_reports/fake_shard"
Assert-True (-not (Test-FoundationJunctionTargetSafe -ProjectRoot $fakeProject -TargetPath (Join-Path $projectRoot ".tmp"))) "Ancestor .tmp junction cycle was accepted."
Assert-True (Test-FoundationJunctionTargetSafe -ProjectRoot $fakeProject -TargetPath (Join-Path $projectRoot "scripts")) "Disjoint read-only source junction was rejected."
Assert-True (-not $checkGodotSource.Contains('@(".agents", ".tmp",')) "Shard project still junctions its ancestor .tmp report tree."
Assert-True ($checkGodotSource.Contains('Copy-FoundationShardCache -SourceCache $sourceCache -DestinationCache $shardCache')) "Shard launcher bypasses the validated private-cache copier."
Assert-True (-not $checkGodotSource.Contains('Get-ChildItem -LiteralPath $sourceCache -Force')) "Shard launcher still enumerates volatile parent-cache siblings."
Assert-True (-not $checkGodotSource.Contains('Get-ProjectCacheWriteState')) "Shard launcher still routes cleanup cache checks through a callback-invisible script-local wrapper."
Assert-True (-not ([regex]::IsMatch($checkGodotSource, '(?s)\$cacheCheck\s*=\s*\{.*?\}\.GetNewClosure\(\)'))) "Post-cleanup cache callback still hides script-scope fingerprint functions inside a dynamic closure module."

if (-not $Quiet) {
    Write-Host "Foundation systems shard hostile contracts passed."
}
