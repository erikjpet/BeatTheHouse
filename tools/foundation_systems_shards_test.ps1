param([switch]$Quiet)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "foundation_systems_shards.ps1")
. (Join-Path $PSScriptRoot "split_test_runner_helpers.ps1")

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Message)
    try {
        & $Action | Out-Null
    }
    catch {
        return $_.Exception
    }
    throw $Message
}

function Get-GDScriptTopLevelFunctionBlocks {
    param(
        [AllowEmptyCollection()]
        [string[]]$Lines,
        [string]$SourceLabel
    )

    $result = [ordered]@{}
    $starts = @()
    for ($index = 0; $index -lt $Lines.Count; $index += 1) {
        $match = [regex]::Match($Lines[$index], '^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')
        if ($match.Success) {
            $starts += [pscustomobject]@{ index = $index; name = $match.Groups[1].Value; signature = $Lines[$index] }
        }
    }
    for ($startIndex = 0; $startIndex -lt $starts.Count; $startIndex += 1) {
        $entry = $starts[$startIndex]
        if ($result.Contains($entry.name)) {
            throw "Duplicate top-level GDScript function '$($entry.name)' in $SourceLabel."
        }
        $blockStart = [int]$entry.index
        $endIndex = if ($startIndex + 1 -lt $starts.Count) { [int]$starts[$startIndex + 1].index - 1 } else { $Lines.Count - 1 }
        $result[$entry.name] = [pscustomobject]@{
            name = [string]$entry.name
            signature = [string]$entry.signature
            lines = @($Lines[$blockStart..$endIndex])
        }
    }
    return $result
}

function Get-NormalizedGDScriptSignature {
    param([string]$Signature)
    return ([regex]::Replace($Signature.Trim(), '\s+', ''))
}

function Get-GDScriptFunctionClosure {
    param(
        [System.Collections.IDictionary]$FunctionBlocks,
        [string[]]$Roots
    )

    $visited = @{}
    $pending = New-Object System.Collections.Generic.Queue[string]
    foreach ($rootName in $Roots) {
        if (-not $FunctionBlocks.Contains($rootName)) {
            throw "GDScript closure root is missing: $rootName"
        }
        $pending.Enqueue($rootName)
    }
    while ($pending.Count -gt 0) {
        $name = $pending.Dequeue()
        if ($visited.ContainsKey($name)) {
            continue
        }
        $visited[$name] = $true
        $body = [string]::Join("`n", @($FunctionBlocks[$name].lines))
        $tokens = @([regex]::Matches($body, '(?<![A-Za-z0-9_])(_[A-Za-z0-9_]+)\s*\(') | ForEach-Object { $_.Groups[1].Value })
        $tokens += @([regex]::Matches($body, 'Callable\(self,\s*"(_[A-Za-z0-9_]+)"\)') | ForEach-Object { $_.Groups[1].Value })
        foreach ($target in @($tokens | Sort-Object -Unique)) {
            if ($FunctionBlocks.Contains($target) -and -not $visited.ContainsKey($target)) {
                $pending.Enqueue($target)
            }
        }
    }
    return @($visited.Keys | Sort-Object)
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
$fixtureSource = Get-Content -LiteralPath (Join-Path $projectRoot "scripts/tests/foundation/check_lenders_release_saves.gd") -Raw
$fixtureMatch = [regex]::Match($fixtureSource, '(?s)func _fixture_library\(failures: Array\) -> ContentLibrary:(.*?)(?=\r?\n\r?\nfunc )')
Assert-True ($fixtureMatch.Success -and $fixtureMatch.Value.IndexOf('before_hydration := _foundation_library_fingerprint(library)') -ge 0 -and $fixtureMatch.Value.IndexOf('library._rebuild_indexes()') -gt $fixtureMatch.Value.IndexOf('before_hydration :=') -and $fixtureMatch.Value.IndexOf('library._rebuild_indexes()') -lt $fixtureMatch.Value.LastIndexOf('return library')) "Fixture ContentLibrary is not fully indexed before the immutable baseline captures it."
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
$gitignoreSource = Get-Content -LiteralPath (Join-Path $projectRoot ".gitignore") -Raw

$selectionMatrix = @(
    [pscustomobject]@{ suite = "smoke"; foundation = ""; expected = $true },
    [pscustomobject]@{ suite = "contract"; foundation = ""; expected = $true },
    [pscustomobject]@{ suite = "full"; foundation = ""; expected = $true },
    [pscustomobject]@{ suite = "audit"; foundation = ""; expected = $false }
)
foreach ($selection in $selectionMatrix) {
    $actual = Test-FoundationSplitRunnerPreparationRequired -Suite $selection.suite -FoundationSuite $selection.foundation
    Assert-True ($actual -eq $selection.expected) "Foundation split-runner top-level selection matrix drifted for Suite=$($selection.suite)."
}
$preparationKindMatrix = @(
    [pscustomobject]@{ suite = "smoke"; foundation = ""; expected = "full" },
    [pscustomobject]@{ suite = "contract"; foundation = ""; expected = "full" },
    [pscustomobject]@{ suite = "full"; foundation = ""; expected = "full" },
    [pscustomobject]@{ suite = "audit"; foundation = ""; expected = "none" },
    [pscustomobject]@{ suite = "smoke"; foundation = "ui"; expected = "none" },
    [pscustomobject]@{ suite = "smoke"; foundation = "blackjack"; expected = "blackjack" },
    [pscustomobject]@{ suite = "contract"; foundation = "blackjack"; expected = "blackjack" },
    [pscustomobject]@{ suite = "audit"; foundation = "blackjack"; expected = "blackjack" },
    [pscustomobject]@{ suite = "full"; foundation = "blackjack"; expected = "blackjack" },
    [pscustomobject]@{ suite = "smoke"; foundation = "systems"; expected = "full" },
    [pscustomobject]@{ suite = "audit"; foundation = "contracts"; expected = "full" }
)
foreach ($selection in $preparationKindMatrix) {
    $actualKind = Get-FoundationSplitRunnerPreparationKind -Suite $selection.suite -FoundationSuite $selection.foundation
    Assert-True ($actualKind -ceq $selection.expected) "Foundation split-runner preparation kind drifted for Suite=$($selection.suite), FoundationSuite=$($selection.foundation)."
}
$normalizedFoundationSuites = @(
    "smoke", "contracts", "games", "systems", "slot", "slots", "slot_acceptance", "blackjack", "roulette",
    "baccarat", "craps", "video_poker", "bar_dice", "crew_poker", "pull_tabs", "scratch_tickets", "coin_pusher", "audit", "all"
)
foreach ($topLevelSuite in @("smoke", "contract", "audit", "full")) {
    foreach ($foundationSuite in $normalizedFoundationSuites) {
        Assert-True (Test-FoundationSplitRunnerPreparationRequired -Suite $topLevelSuite -FoundationSuite $foundationSuite) "Normalized FoundationSuite '$foundationSuite' did not select the composite under Suite=$topLevelSuite."
        $expectedKind = if ($foundationSuite -eq "blackjack") { "blackjack" } else { "full" }
        Assert-True ((Get-FoundationSplitRunnerPreparationKind -Suite $topLevelSuite -FoundationSuite $foundationSuite) -ceq $expectedKind) "Normalized FoundationSuite '$foundationSuite' selected the wrong composite kind under Suite=$topLevelSuite."
    }
    Assert-True (-not (Test-FoundationSplitRunnerPreparationRequired -Suite $topLevelSuite -FoundationSuite "ui")) "UI-only FoundationSuite selected the Foundation composite under Suite=$topLevelSuite."
    Assert-True ((Get-FoundationSplitRunnerPreparationKind -Suite $topLevelSuite -FoundationSuite "ui") -ceq "none") "UI-only FoundationSuite selected a prepared composite under Suite=$topLevelSuite."
}
Assert-True (Test-FoundationSplitRunnerPreparationRequired -Suite "smoke" -FoundationSuite "contracts") "Normalized contract alias did not select the Foundation composite."
Assert-True (Test-FoundationSplitRunnerPreparationRequired -Suite "smoke" -FoundationSuite "all") "Normalized full alias did not select the Foundation composite."
foreach ($invalidSelection in @(
    [pscustomobject]@{ suite = "Smoke"; foundation = "" },
    [pscustomobject]@{ suite = "smoke "; foundation = "" },
    [pscustomobject]@{ suite = "smoke"; foundation = "Blackjack" },
    [pscustomobject]@{ suite = "smoke"; foundation = "blackjack " },
    [pscustomobject]@{ suite = "smoke"; foundation = "contract" },
    [pscustomobject]@{ suite = "smoke"; foundation = "full" },
    [pscustomobject]@{ suite = "unknown"; foundation = "" },
    [pscustomobject]@{ suite = "smoke"; foundation = "unknown" }
)) {
    Assert-Throws -Action { Test-FoundationSplitRunnerPreparationRequired -Suite $invalidSelection.suite -FoundationSuite $invalidSelection.foundation } -Message "Invalid or non-normalized split-runner selection was accepted: Suite=$($invalidSelection.suite), FoundationSuite=$($invalidSelection.foundation)." | Out-Null
}
Assert-True (-not (Get-Command Test-FoundationSplitRunnerPreparationRequired).Parameters.ContainsKey("NoImport")) "NoImport leaked into pure split-runner selection."
Assert-True (-not (Get-Command Get-FoundationSplitRunnerPreparationKind).Parameters.ContainsKey("NoImport")) "NoImport leaked into pure split-runner routing."
Assert-True ($checkGodotSource.Contains('if ($foundationSuiteKey -eq "contract")') -and $checkGodotSource.Contains('$foundationSuiteKey = "contracts"') -and $checkGodotSource.Contains('elseif ($foundationSuiteKey -eq "full")') -and $checkGodotSource.Contains('$foundationSuiteKey = "all"')) "FoundationSuite alias normalization changed or moved behind split-runner selection."

$expectedSplitSources = @(
    "scripts/tests/foundation/check_core_content.gd",
    "scripts/tests/foundation/check_slots_surfaces.gd",
    "scripts/tests/foundation/check_table_games.gd",
    "scripts/tests/foundation/check_items_events_world.gd",
    "scripts/tests/foundation/check_delivery_runs.gd",
    "scripts/tests/foundation/check_lenders_release_saves.gd",
    "scripts/tests/foundation/check_scratch_tickets.gd",
    "scripts/tests/foundation/check_cage_environment_rework.gd",
    "scripts/tests/foundation/check_coin_pusher.gd"
)
$sourceFunctionMatch = [regex]::Match($checkGodotSource, '(?s)function Get-FoundationSplitRunnerSourceRelativePaths \{(.*?)(?=\r?\n\}\r?\n\r?\nfunction Get-FoundationSplitRunnerPhysicalPath)')
Assert-True $sourceFunctionMatch.Success "Could not locate the canonical Foundation split-runner source manifest."
$declaredSplitSources = @([regex]::Matches($sourceFunctionMatch.Groups[1].Value, '"(scripts/tests/foundation/[^\"]+\.gd)"') | ForEach-Object { $_.Groups[1].Value })
Assert-True (($declaredSplitSources -join "|") -ceq ($expectedSplitSources -join "|")) "Canonical nine-source Foundation split-runner order changed."
$splitLines = @(Get-SplitTestRunnerLines -ProjectRoot $projectRoot -SourceRelativePaths $expectedSplitSources)
Assert-True ($splitLines.Count -eq 35084) "Canonical Foundation composite line count changed from 35,084."
Assert-True ((Get-SplitTestRunnerSemanticSha256 -Lines $splitLines) -ceq "52e0bc8635f52ab39019edef4995a77a4d6662e937158475f6430071d2702e45") "Canonical Foundation composite semantic hash changed."
$splitBytes = [byte[]](Get-SplitTestRunnerBytes -Lines $splitLines)
Assert-True ($splitBytes.Length -eq 2308016) "Canonical Foundation composite exact byte length changed."
Assert-True ((Get-SplitTestRunnerByteSha256 -Bytes $splitBytes) -ceq "19b60badb149eed8bad881ed95228223f168b54172407f0c6016686162ed8f19") "Canonical Foundation composite exact byte hash changed."
Assert-True (-not ($splitBytes.Length -ge 3 -and $splitBytes[0] -eq 0xEF -and $splitBytes[1] -eq 0xBB -and $splitBytes[2] -eq 0xBF)) "Foundation composite unexpectedly contains a UTF-8 BOM."
$splitText = (New-Object System.Text.UTF8Encoding($false)).GetString($splitBytes)
Assert-True (-not [regex]::IsMatch($splitText, '(?<!\r)\n')) "Foundation composite contains a non-CRLF line ending."
Assert-True ($splitText.EndsWith("`r`n")) "Foundation composite is missing its trailing CRLF newline."

$expectedBlackjackSplitSources = @(
    "scripts/tests/foundation/check_core_content.gd",
    "scripts/tests/foundation/check_slots_surfaces.gd",
    "scripts/tests/foundation/check_table_games.gd",
    "scripts/tests/foundation/check_items_events_world.gd",
    "scripts/tests/foundation/check_lenders_release_saves.gd"
)
$expectedBlackjackOmittedSources = @(
    "scripts/tests/foundation/check_delivery_runs.gd",
    "scripts/tests/foundation/check_scratch_tickets.gd",
    "scripts/tests/foundation/check_cage_environment_rework.gd",
    "scripts/tests/foundation/check_coin_pusher.gd"
)
$focusedSourceFunctionMatch = [regex]::Match($checkGodotSource, '(?s)function Get-FoundationBlackjackSplitRunnerSourceRelativePaths \{(.*?)(?=\r?\n\}\r?\n\r?\nfunction Get-FoundationBlackjackSplitRunnerPhysicalPath)')
Assert-True $focusedSourceFunctionMatch.Success "Could not locate the focused Blackjack source manifest."
$declaredBlackjackSplitSources = @([regex]::Matches($focusedSourceFunctionMatch.Groups[1].Value, '"(scripts/tests/foundation/[^\"]+\.gd)"') | ForEach-Object { $_.Groups[1].Value })
Assert-True (($declaredBlackjackSplitSources -join "|") -ceq ($expectedBlackjackSplitSources -join "|")) "Focused Blackjack five-source order changed."
$derivedOmittedSources = @($expectedSplitSources | Where-Object { $expectedBlackjackSplitSources -notcontains $_ })
Assert-True (($derivedOmittedSources -join "|") -ceq ($expectedBlackjackOmittedSources -join "|")) "Focused Blackjack included/omitted manifest partition changed."

$blackjackBaseLines = @(Get-SplitTestRunnerLines -ProjectRoot $projectRoot -SourceRelativePaths $expectedBlackjackSplitSources)
$blackjackFocusedLines = @(Get-BlackjackFocusedSplitTestRunnerLines -Lines $blackjackBaseLines)
$blackjackFocusedBytes = [byte[]](Get-SplitTestRunnerBytes -Lines $blackjackFocusedLines)
Assert-True ($blackjackFocusedLines.Count -eq 30464) "Focused Blackjack composite line count changed from 30,464."
Assert-True ((Get-SplitTestRunnerSemanticSha256 -Lines $blackjackFocusedLines) -ceq "c2f8bd89822c9c883dd7f0f43be8be0d3b910a43f764369106a4b7a12d4a6f42") "Focused Blackjack semantic hash changed."
Assert-True ($blackjackFocusedBytes.Length -eq 1968001) "Focused Blackjack exact byte length changed from 1,968,001."
Assert-True ((Get-SplitTestRunnerByteSha256 -Bytes $blackjackFocusedBytes) -ceq "126f0c33468e6d4b84ae17de784aa2d1270cf22994356b8be9dadfb46a44b43f") "Focused Blackjack exact byte hash changed."
Assert-True (-not ($blackjackFocusedBytes.Length -ge 3 -and $blackjackFocusedBytes[0] -eq 0xEF -and $blackjackFocusedBytes[1] -eq 0xBB -and $blackjackFocusedBytes[2] -eq 0xBF)) "Focused Blackjack composite unexpectedly contains a UTF-8 BOM."
$blackjackFocusedDiskText = (New-Object System.Text.UTF8Encoding($false)).GetString($blackjackFocusedBytes)
Assert-True (-not [regex]::IsMatch($blackjackFocusedDiskText, '(?<!\r)\n')) "Focused Blackjack composite contains a non-CRLF line ending."
Assert-True ($blackjackFocusedDiskText.EndsWith("`r`n")) "Focused Blackjack composite is missing its trailing CRLF newline."
$blackjackFocusedText = [string]::Join("`n", $blackjackFocusedLines)
$blackjackBaseText = [string]::Join("`n", $blackjackBaseLines)
$blackjackBaseBlocks = Get-GDScriptTopLevelFunctionBlocks -Lines $blackjackBaseLines -SourceLabel "focused Blackjack base"
$blackjackFocusedBlocks = Get-GDScriptTopLevelFunctionBlocks -Lines $blackjackFocusedLines -SourceLabel "focused Blackjack generated runner"

$omittedLines = @(Get-SplitTestRunnerLines -ProjectRoot $projectRoot -SourceRelativePaths $expectedBlackjackOmittedSources)
$omittedBlocks = Get-GDScriptTopLevelFunctionBlocks -Lines $omittedLines -SourceLabel "focused Blackjack omitted sources"
$requiredFatalStubs = @(
    "_check_delivery_framework",
    "_delivery_complete_all_targets",
    "_check_scratch_tickets_surface_contract",
    "_check_cage_environment_rework",
    "_check_coin_pusher_contract"
)
$referencedOmittedFunctions = @($omittedBlocks.Keys | Where-Object { [regex]::IsMatch($blackjackBaseText, "(?<![A-Za-z0-9_])$([regex]::Escape([string]$_))(?![A-Za-z0-9_])") } | Sort-Object)
Assert-True (($referencedOmittedFunctions -join "|") -ceq ((@($requiredFatalStubs | Sort-Object)) -join "|")) "Focused Blackjack token-wide omitted-function intersection is not exactly the five reviewed fatal seams."

$omittedNonFunctionDeclarations = @()
foreach ($line in $omittedLines) {
    $declarationMatch = [regex]::Match($line, '^(?:const|var|class_name|class)\s+([A-Za-z_][A-Za-z0-9_]*)')
    if ($declarationMatch.Success) {
        $omittedNonFunctionDeclarations += $declarationMatch.Groups[1].Value
    }
}
$referencedOmittedDeclarations = @($omittedNonFunctionDeclarations | Sort-Object -Unique | Where-Object { [regex]::IsMatch($blackjackBaseText, "(?<![A-Za-z0-9_])$([regex]::Escape([string]$_))(?![A-Za-z0-9_])") })
Assert-True ($referencedOmittedDeclarations.Count -eq 0) ("Focused Blackjack retained omitted const/var/class references: " + ($referencedOmittedDeclarations -join ", "))

$expectedInjectedFunctions = @($requiredFatalStubs + "_foundation_generated_focused_fatal_stub" | Sort-Object)
$actualInjectedFunctions = @($blackjackFocusedBlocks.Keys | Where-Object { -not $blackjackBaseBlocks.Contains($_) } | Sort-Object)
Assert-True (($actualInjectedFunctions -join "|") -ceq ($expectedInjectedFunctions -join "|")) "Focused Blackjack injected functions are not exactly one fatal helper plus five reviewed stubs."
foreach ($stubName in $requiredFatalStubs) {
    Assert-True ($omittedBlocks.Contains($stubName) -and $blackjackFocusedBlocks.Contains($stubName)) "Focused Blackjack fatal stub signature source is missing: $stubName"
    $sourceSignature = Get-NormalizedGDScriptSignature -Signature $omittedBlocks[$stubName].signature
    $stubSignature = Get-NormalizedGDScriptSignature -Signature $blackjackFocusedBlocks[$stubName].signature
    Assert-True ($sourceSignature -ceq $stubSignature) "Focused Blackjack fatal stub signature drifted from its omitted source: $stubName"
    $stubBody = [string]::Join("`n", @($blackjackFocusedBlocks[$stubName].lines))
    Assert-True (([regex]::Matches($stubBody, "_foundation_generated_focused_fatal_stub\(`"$([regex]::Escape($stubName))`"\)")).Count -eq 1) "Focused Blackjack fatal stub does not invoke the fatal helper exactly once: $stubName"
    if ($omittedBlocks[$stubName].signature -match '->\s*bool:') {
        Assert-True (([regex]::Matches($stubBody, '(?m)^\treturn false\s*$')).Count -eq 1) "Focused Blackjack bool fatal stub does not return false exactly once: $stubName"
    }
    else {
        Assert-True (-not [regex]::IsMatch($stubBody, '(?m)^\treturn\s+')) "Focused Blackjack void fatal stub unexpectedly returns a value: $stubName"
    }
}
$fatalHelperBody = [string]::Join("`n", @($blackjackFocusedBlocks["_foundation_generated_focused_fatal_stub"].lines))
Assert-True (([regex]::Matches($fatalHelperBody, '_foundation_generated_focused_stub_call_count \+= 1')).Count -eq 1) "Focused Blackjack fatal helper does not increment exactly once."
Assert-True (([regex]::Matches($fatalHelperBody, '_foundation_generated_focused_failures_ref\.append\(failure\)')).Count -eq 1) "Focused Blackjack fatal helper does not append through the bound failures reference exactly once."
Assert-True (([regex]::Matches($fatalHelperBody, 'push_error\(failure\)')).Count -eq 1) "Focused Blackjack fatal helper does not push_error exactly once."

Assert-True (([regex]::Matches($blackjackFocusedText, '(?m)^const FOUNDATION_GENERATED_FOCUSED_SUITE := "blackjack"$')).Count -eq 1) "Focused Blackjack scope constant is missing or duplicated."
Assert-True (([regex]::Matches($blackjackFocusedText, '(?m)^var _foundation_generated_focused_stub_call_count := 0$')).Count -eq 1) "Focused Blackjack stub counter is missing or duplicated."
Assert-True (([regex]::Matches($blackjackFocusedText, '(?m)^var _foundation_generated_focused_failures_ref: Array = \[\]$')).Count -eq 1) "Focused Blackjack bound-failures reference is missing or duplicated."
$focusedInitBody = [string]::Join("`n", @($blackjackFocusedBlocks["_init"].lines))
$scopeGuardIndex = $focusedInitBody.IndexOf('if _foundation_active_suite != FOUNDATION_GENERATED_FOCUSED_SUITE:')
$bindFailuresIndex = $focusedInitBody.IndexOf('_foundation_generated_focused_failures_ref = failures')
$libraryWorkIndex = $focusedInitBody.IndexOf('ContentLibraryScript.new()')
$suiteCallIndex = $focusedInitBody.IndexOf('_foundation_run_suite(_foundation_active_suite, content_library, fixture_library, failures, report)')
$counterGuardIndex = $focusedInitBody.IndexOf('if _foundation_generated_focused_stub_call_count != 0:')
Assert-True ($scopeGuardIndex -gt $focusedInitBody.IndexOf('var report := _foundation_report(_foundation_active_suite)') -and $scopeGuardIndex -lt $bindFailuresIndex -and $bindFailuresIndex -lt $libraryWorkIndex) "Focused Blackjack scope rejection/bound-failures guard is not before library work."
$scopeGuardText = $focusedInitBody.Substring($scopeGuardIndex, $bindFailuresIndex - $scopeGuardIndex)
Assert-True ($scopeGuardText.Contains('failures.append(scope_failure)') -and $scopeGuardText.Contains('push_error(scope_failure)') -and $scopeGuardText.Contains('quit(1)') -and $scopeGuardText.Contains('return')) "Focused Blackjack wrong-scope guard does not fail, push_error, quit nonzero and return."
Assert-True ($suiteCallIndex -ge 0 -and $counterGuardIndex -gt $suiteCallIndex -and $counterGuardIndex -lt $focusedInitBody.IndexOf('var registered_check_ids:')) "Focused Blackjack does not require zero fatal-stub calls immediately after suite dispatch."

$acceptedBlackjackRoots = @("_check_content", "_load_surface_contract_game", "_check_blackjack_surface_contract")
$acceptedBlackjackClosure = @(Get-GDScriptFunctionClosure -FunctionBlocks $blackjackFocusedBlocks -Roots $acceptedBlackjackRoots)
$reachableFatalStubs = @($requiredFatalStubs | Where-Object { $acceptedBlackjackClosure -contains $_ })
Assert-True ($reachableFatalStubs.Count -eq 0) ("Focused Blackjack accepted callable closure reaches fatal omitted stubs: " + ($reachableFatalStubs -join ", "))
$runSuiteBody = [string]::Join("`n", @($blackjackFocusedBlocks["_foundation_run_suite"].lines))
$targetSuiteBranch = [regex]::Match($runSuiteBody, '(?s)\t\t_:\n\t\t\tif \["blackjack".*?(?=\n\t\t\telse:)')
Assert-True $targetSuiteBranch.Success "Focused Blackjack could not prove the target-game dispatcher branch."
$targetRegistrations = @([regex]::Matches($targetSuiteBranch.Value, '_foundation_run_check\([^\n]+') | ForEach-Object { $_.Value })
Assert-True ($targetRegistrations.Count -eq 2 -and $targetRegistrations[0].Contains('"content"') -and $targetRegistrations[1].Contains('"%s_game_suite" % suite') -and $targetRegistrations[1].Contains('"_check_target_game_suite"')) "Focused Blackjack target-game registration order or callable changed."
$derivedBlackjackCheckIds = @("content", ("{0}_game_suite" -f "blackjack"))
Assert-True (($derivedBlackjackCheckIds -join "|") -ceq "content|blackjack_game_suite") "Focused Blackjack registered/executed check IDs are not exact or ordered."

$selectedFocusedBodyHashes = [ordered]@{
    "_init" = "af47052dcece30bed849050a5dc0fd8ee58c1b11c9f21bf2f17539a479bee277"
    "_foundation_run_suite" = "47525ea1cae9582613ca85a540fc57dabadc0f47296ec053271631f6228f00ca"
    "_check_content" = "0288297615f46d1da9d2ac1e12b8ae6993f0781b0ea2bf6f1bc67a35c465577f"
    "_load_surface_contract_game" = "da0a481951558b71c7214f46bcd838dda293f5b57b48cbdb0b9ce089e1ee5dc6"
    "_check_blackjack_surface_contract" = "0caa5e36e9842793540aebc2b0685e4e3e6d501b8bb1e342103d3869375ff201"
    "_foundation_generated_focused_fatal_stub" = "80028f6d9f64aea087bdf6100ab67238eee45fcb347e9d99efab018c5219af6b"
}
foreach ($functionName in $selectedFocusedBodyHashes.Keys) {
    Assert-True ($blackjackFocusedBlocks.Contains($functionName)) "Focused Blackjack selected body is missing: $functionName"
    $actualBodyHash = Get-SplitTestRunnerSemanticSha256 -Lines @($blackjackFocusedBlocks[$functionName].lines)
    Assert-True ($actualBodyHash -ceq $selectedFocusedBodyHashes[$functionName]) "Focused Blackjack selected body hash changed: $functionName"
}

function Invoke-HostileSplitRunnerPublication {
    param([string]$DestinationPath, [byte[]]$IntendedBytes)
    $published = $null
    $failure = $null
    try {
        $candidate = Set-SplitTestRunnerFile -DestinationPath $DestinationPath -ResourcePath "res://generated_tests/foundation_check_split_runner.gd" -IntendedBytes $IntendedBytes
        Get-VerifiedSplitTestRunnerResourcePath -PreparedState $candidate -ExpectedPath $DestinationPath -ExpectedResourcePath "res://generated_tests/foundation_check_split_runner.gd" -IntendedBytes $IntendedBytes | Out-Null
        $published = $candidate
    }
    catch {
        $failure = $_.Exception
    }
    return [pscustomobject]@{ published = $published; failure = $failure }
}

$runnerLifecycleRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("bth_split_runner_" + [Guid]::NewGuid().ToString("N"))
$runnerLifecycleFull = [System.IO.Path]::GetFullPath($runnerLifecycleRoot)
$tempRootFull = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd([char[]]@([char]'\', [char]'/'))
Assert-True $runnerLifecycleFull.StartsWith($tempRootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) "Split-runner hostile fixture escaped the OS temporary directory."
try {
    $runnerPath = Join-Path $runnerLifecycleRoot "generated_tests\foundation_check_split_runner.gd"
    $fixtureBytes = [byte[]](Get-SplitTestRunnerBytes -Lines @("extends SceneTree", "func _init():", "`tquit(0)"))

    $missingPreparation = Invoke-HostileSplitRunnerPublication -DestinationPath $runnerPath -IntendedBytes $fixtureBytes
    Assert-True ($null -eq $missingPreparation.failure -and $null -ne $missingPreparation.published -and $missingPreparation.published.Wrote) "Missing split runner was not created and published after verification."
    Assert-True (Test-SplitTestRunnerBytesEqual -Left ([System.IO.File]::ReadAllBytes($runnerPath)) -Right $fixtureBytes) "Created split runner does not contain the intended exact bytes."

    $preservedTimestamp = [DateTime]::SpecifyKind([DateTime]::Parse("2024-01-02T03:04:06Z"), [DateTimeKind]::Utc)
    [System.IO.File]::SetLastWriteTimeUtc($runnerPath, $preservedTimestamp)
    $identicalPreparation = Invoke-HostileSplitRunnerPublication -DestinationPath $runnerPath -IntendedBytes $fixtureBytes
    Assert-True ($null -eq $identicalPreparation.failure -and $null -ne $identicalPreparation.published -and -not $identicalPreparation.published.Wrote) "Byte-identical split runner was rewritten."
    Assert-True (([System.IO.FileInfo]$runnerPath).LastWriteTimeUtc.Ticks -eq $preservedTimestamp.Ticks) "Byte-identical split runner did not preserve LastWriteTimeUtc."

    [System.IO.File]::WriteAllBytes($runnerPath, [byte[]](Get-SplitTestRunnerBytes -Lines @("hostile changed bytes")))
    [System.IO.File]::SetLastWriteTimeUtc($runnerPath, $preservedTimestamp)
    $changedPreparation = Invoke-HostileSplitRunnerPublication -DestinationPath $runnerPath -IntendedBytes $fixtureBytes
    Assert-True ($null -eq $changedPreparation.failure -and $null -ne $changedPreparation.published -and $changedPreparation.published.Wrote) "Changed split runner was not rewritten and published."
    Assert-True (Test-SplitTestRunnerBytesEqual -Left ([System.IO.File]::ReadAllBytes($runnerPath)) -Right $fixtureBytes) "Changed split runner rewrite did not produce the intended exact bytes."
    $prepared = $changedPreparation.published

    $focusedRunnerPath = Join-Path $runnerLifecycleRoot "generated_tests\foundation_blackjack_split_runner.gd"
    $focusedFixtureBytes = [byte[]](Get-SplitTestRunnerBytes -Lines @("extends SceneTree", "# focused"))
    $focusedPrepared = Set-SplitTestRunnerFile -DestinationPath $focusedRunnerPath -ResourcePath "res://generated_tests/foundation_blackjack_split_runner.gd" -IntendedBytes $focusedFixtureBytes
    Get-VerifiedSplitTestRunnerResourcePath -PreparedState $focusedPrepared -ExpectedPath $focusedRunnerPath -ExpectedResourcePath $focusedPrepared.ResourcePath -IntendedBytes $focusedFixtureBytes | Out-Null
    Assert-Throws -Action { Get-VerifiedSplitTestRunnerResourcePath -PreparedState $null -ExpectedPath $focusedRunnerPath -ExpectedResourcePath $focusedPrepared.ResourcePath -IntendedBytes $focusedFixtureBytes } -Message "Missing focused preparation state was accepted." | Out-Null
    Assert-Throws -Action { Get-VerifiedSplitTestRunnerResourcePath -PreparedState $prepared -ExpectedPath $focusedRunnerPath -ExpectedResourcePath $focusedPrepared.ResourcePath -IntendedBytes $focusedFixtureBytes } -Message "Full prepared state crossed into the focused accessor." | Out-Null
    Assert-Throws -Action { Get-VerifiedSplitTestRunnerResourcePath -PreparedState $focusedPrepared -ExpectedPath $runnerPath -ExpectedResourcePath $prepared.ResourcePath -IntendedBytes $fixtureBytes } -Message "Focused prepared state crossed into the full accessor." | Out-Null

    Assert-Throws -Action { Get-VerifiedSplitTestRunnerResourcePath -PreparedState $null -ExpectedPath $runnerPath -ExpectedResourcePath $prepared.ResourcePath -IntendedBytes $fixtureBytes } -Message "Missing preparation state was accepted." | Out-Null
    Assert-Throws -Action { Get-VerifiedSplitTestRunnerResourcePath -PreparedState $prepared -ExpectedPath (Join-Path $runnerLifecycleRoot "other.gd") -ExpectedResourcePath $prepared.ResourcePath -IntendedBytes $fixtureBytes } -Message "Prepared physical-path drift was accepted." | Out-Null
    Assert-Throws -Action { Get-VerifiedSplitTestRunnerResourcePath -PreparedState $prepared -ExpectedPath $runnerPath -ExpectedResourcePath "res://generated_tests/other.gd" -IntendedBytes $fixtureBytes } -Message "Prepared resource-path drift was accepted." | Out-Null

    $beforeSourceDriftBytes = [System.IO.File]::ReadAllBytes($runnerPath)
    $beforeSourceDriftTimestamp = ([System.IO.FileInfo]$runnerPath).LastWriteTimeUtc
    $sourceDriftBytes = [byte[]](Get-SplitTestRunnerBytes -Lines @("extends SceneTree", "# changed source"))
    Assert-Throws -Action { Get-VerifiedSplitTestRunnerResourcePath -PreparedState $prepared -ExpectedPath $runnerPath -ExpectedResourcePath $prepared.ResourcePath -IntendedBytes $sourceDriftBytes } -Message "Post-preparation source drift was accepted." | Out-Null
    Assert-True ((Test-SplitTestRunnerBytesEqual -Left ([System.IO.File]::ReadAllBytes($runnerPath)) -Right $beforeSourceDriftBytes) -and ([System.IO.FileInfo]$runnerPath).LastWriteTimeUtc.Ticks -eq $beforeSourceDriftTimestamp.Ticks) "Source-drift verification rewrote the prepared output."

    $hostileOutputBytes = [byte[]](Get-SplitTestRunnerBytes -Lines @("extends SceneTree", "func hostile():", "`tpass"))
    [System.IO.File]::WriteAllBytes($runnerPath, $hostileOutputBytes)
    [System.IO.File]::SetLastWriteTimeUtc($runnerPath, $prepared.LastWriteTimeUtc)
    Assert-Throws -Action { Get-VerifiedSplitTestRunnerResourcePath -PreparedState $prepared -ExpectedPath $runnerPath -ExpectedResourcePath $prepared.ResourcePath -IntendedBytes $fixtureBytes } -Message "Post-preparation output drift was accepted." | Out-Null
    Assert-True (Test-SplitTestRunnerBytesEqual -Left ([System.IO.File]::ReadAllBytes($runnerPath)) -Right $hostileOutputBytes) "Output-drift verification silently rewrote the hostile output."

    [System.IO.File]::WriteAllBytes($runnerPath, $fixtureBytes)
    [System.IO.File]::SetLastWriteTimeUtc($runnerPath, $prepared.LastWriteTimeUtc.AddSeconds(5))
    Assert-Throws -Action { Get-VerifiedSplitTestRunnerResourcePath -PreparedState $prepared -ExpectedPath $runnerPath -ExpectedResourcePath $prepared.ResourcePath -IntendedBytes $fixtureBytes } -Message "Post-preparation timestamp drift was accepted." | Out-Null
    Assert-True (Test-SplitTestRunnerBytesEqual -Left ([System.IO.File]::ReadAllBytes($runnerPath)) -Right $fixtureBytes) "Timestamp-drift verification rewrote the prepared output."

    Remove-Item -LiteralPath $runnerPath -Force
    Assert-Throws -Action { Get-VerifiedSplitTestRunnerResourcePath -PreparedState $prepared -ExpectedPath $runnerPath -ExpectedResourcePath $prepared.ResourcePath -IntendedBytes $fixtureBytes } -Message "Missing prepared output was accepted." | Out-Null
    Assert-True (-not (Test-Path -LiteralPath $runnerPath)) "Missing-output verification recreated the split runner."

    $invalidParent = Join-Path $runnerLifecycleRoot "invalid_parent"
    [System.IO.File]::WriteAllText($invalidParent, "not a directory")
    $invalidPublication = Invoke-HostileSplitRunnerPublication -DestinationPath (Join-Path $invalidParent "runner.gd") -IntendedBytes $fixtureBytes
    Assert-True ($null -ne $invalidPublication.failure -and $null -eq $invalidPublication.published) "Invalid split-runner destination published preparation state."

    $readOnlyPath = Join-Path $runnerLifecycleRoot "readonly\runner.gd"
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $readOnlyPath)) | Out-Null
    [System.IO.File]::WriteAllBytes($readOnlyPath, [byte[]](Get-SplitTestRunnerBytes -Lines @("old")))
    [System.IO.File]::SetAttributes($readOnlyPath, [System.IO.FileAttributes]::ReadOnly)
    try {
        $readOnlyPublication = Invoke-HostileSplitRunnerPublication -DestinationPath $readOnlyPath -IntendedBytes $fixtureBytes
        Assert-True ($null -ne $readOnlyPublication.failure -and $null -eq $readOnlyPublication.published) "Unwritable split-runner destination published preparation state."
    }
    finally {
        [System.IO.File]::SetAttributes($readOnlyPath, [System.IO.FileAttributes]::Normal)
    }
}
finally {
    if (Test-Path -LiteralPath $runnerLifecycleRoot) {
        Remove-Item -LiteralPath $runnerLifecycleRoot -Recurse -Force
    }
}

$executionStart = $checkGodotSource.LastIndexOf('$powerShellExe =')
Assert-True ($executionStart -ge 0) "Could not locate check_godot execution sequence."
$executionSource = $checkGodotSource.Substring($executionStart)
$guardIndex = $executionSource.IndexOf('Assert-NoConcurrentProjectGodot')
$preparationRouteIndex = $executionSource.IndexOf('switch (Get-FoundationSplitRunnerPreparationKind')
$focusedPrepareIndex = $executionSource.IndexOf('Initialize-FoundationBlackjackSplitRunner', $preparationRouteIndex)
$fullPrepareIndex = $executionSource.IndexOf('Initialize-FoundationSplitRunner', $preparationRouteIndex)
$importGuardIndex = $executionSource.IndexOf('if (-not $NoImport)')
$importIndex = $executionSource.IndexOf('Invoke-GodotImport', $importGuardIndex)
$loadIndex = $executionSource.IndexOf('Invoke-GDScriptLoadCheck')
$suiteIndex = $executionSource.IndexOf('Invoke-FoundationSuite')
Assert-True ($guardIndex -ge 0 -and $guardIndex -lt $preparationRouteIndex -and $preparationRouteIndex -lt $focusedPrepareIndex -and $preparationRouteIndex -lt $fullPrepareIndex -and $focusedPrepareIndex -lt $importGuardIndex -and $fullPrepareIndex -lt $importGuardIndex -and $importGuardIndex -lt $importIndex -and $importIndex -lt $loadIndex -and $loadIndex -lt $suiteIndex) "Split-runner preparation is not ordered host guard < exact route < one producer < import < load < suite."
Assert-True (([regex]::Matches($executionSource, '\bInitialize-FoundationSplitRunner\b')).Count -eq 1) "Foundation split runner is not prepared exactly once in the execution sequence."
Assert-True (([regex]::Matches($executionSource, '\bInitialize-FoundationBlackjackSplitRunner\b')).Count -eq 1) "Focused Blackjack split runner is not prepared exactly once in the execution sequence."
$preparationCallMatch = [regex]::Match($executionSource, 'Get-FoundationSplitRunnerPreparationKind[^\r\n]+')
Assert-True ($preparationCallMatch.Success -and -not $preparationCallMatch.Value.Contains('NoImport')) "NoImport changes split-runner preparation routing."
Assert-True ($executionSource.Contains('"blackjack" { Initialize-FoundationBlackjackSplitRunner }') -and $executionSource.Contains('"full" { Initialize-FoundationSplitRunner }') -and $executionSource.Contains('"none" { }')) "Execution sequence does not route focused/full/none preparation exactly."
$initializerMatch = [regex]::Match($checkGodotSource, '(?s)function Initialize-FoundationSplitRunner \{(.*?)(?=\r?\n\}\r?\n\r?\nfunction Get-VerifiedFoundationSplitRunnerPath)')
Assert-True ($initializerMatch.Success -and $initializerMatch.Value.IndexOf('Set-SplitTestRunnerFile') -lt $initializerMatch.Value.IndexOf('Get-VerifiedSplitTestRunnerResourcePath') -and $initializerMatch.Value.IndexOf('Get-VerifiedSplitTestRunnerResourcePath') -lt $initializerMatch.Value.IndexOf('$script:PreparedFoundationSplitRunner = $prepared')) "Prepared path/hash/length/timestamp are published before reread verification."
$focusedInitializerMatch = [regex]::Match($checkGodotSource, '(?s)function Initialize-FoundationBlackjackSplitRunner \{(.*?)(?=\r?\n\}\r?\n\r?\nfunction Get-VerifiedFoundationBlackjackSplitRunnerPath)')
Assert-True ($focusedInitializerMatch.Success -and $focusedInitializerMatch.Value.IndexOf('Set-SplitTestRunnerFile') -lt $focusedInitializerMatch.Value.IndexOf('Get-VerifiedSplitTestRunnerResourcePath') -and $focusedInitializerMatch.Value.IndexOf('Get-VerifiedSplitTestRunnerResourcePath') -lt $focusedInitializerMatch.Value.IndexOf('$script:PreparedFoundationBlackjackSplitRunner = $prepared')) "Focused prepared path/hash/length/timestamp are published before reread verification."
$ordinaryInvokerMatch = [regex]::Match($checkGodotSource, '(?s)function Invoke-FoundationSuite \{(.*?)(?=\r?\n\}\r?\n\r?\nfunction Enter-CheckGodotWorkspaceMutex)')
$systemsInvokerMatch = [regex]::Match($checkGodotSource, '(?s)function Invoke-FoundationSystemsSharded \{(.*?)(?=\r?\n\}\r?\n\r?\nfunction Invoke-FoundationPerfSmoke)')
Assert-True ($ordinaryInvokerMatch.Success -and $ordinaryInvokerMatch.Value.Contains('Get-VerifiedFoundationSplitRunnerPathForSuite -FoundationSuite $FoundationSuite')) "Ordinary Foundation suites bypass exact focused/full accessor routing."
Assert-True ($systemsInvokerMatch.Success -and $systemsInvokerMatch.Value.Contains('Get-VerifiedFoundationSplitRunnerPath') -and -not $systemsInvokerMatch.Value.Contains('Get-VerifiedFoundationBlackjackSplitRunnerPath') -and -not $systemsInvokerMatch.Value.Contains('Get-VerifiedFoundationSplitRunnerPathForSuite')) "Sharded Systems does not exclusively consume the verified full runner."
$runnerAccessorMatch = [regex]::Match($checkGodotSource, '(?s)function Get-VerifiedFoundationSplitRunnerPathForSuite \{(.*?)(?=\r?\n\}\r?\n\r?\nfunction Get-UiSceneSplitRunnerPath)')
Assert-True ($runnerAccessorMatch.Success -and $runnerAccessorMatch.Value.Contains('if ($FoundationSuite -eq "blackjack")') -and $runnerAccessorMatch.Value.Contains('return Get-VerifiedFoundationBlackjackSplitRunnerPath') -and $runnerAccessorMatch.Value.Contains('return Get-VerifiedFoundationSplitRunnerPath') -and $runnerAccessorMatch.Value.IndexOf('return Get-VerifiedFoundationBlackjackSplitRunnerPath') -lt $runnerAccessorMatch.Value.IndexOf('return Get-VerifiedFoundationSplitRunnerPath')) "Ordinary Foundation accessor does not route exact Blackjack to focused and every other valid suite to full."
Assert-True ($checkGodotSource.Contains('$script:PreparedFoundationSplitRunner = $null') -and $checkGodotSource.Contains('$script:PreparedFoundationBlackjackSplitRunner = $null')) "Full and focused prepared states are not independently initialized."
Assert-True (-not $checkGodotSource.Contains('Get-FoundationSplitRunnerPath') -and -not $checkGodotSource.Contains('New-SplitTestRunner') -and -not $checkGodotSource.Contains('.tmp\generated_tests')) "A focused or legacy split-runner resolver remains reachable."
Assert-True ($checkGodotSource.Contains('res://generated_tests/foundation_check_split_runner.gd')) "Canonical generated Foundation resource path changed."
Assert-True ($checkGodotSource.Contains('res://generated_tests/foundation_blackjack_split_runner.gd')) "Canonical focused Blackjack resource path changed."
Assert-True ($gitignoreSource -match '(?m)^/generated_tests/\s*$') "Canonical generated_tests directory is not ignored at the repository root."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $projectRoot "generated_tests\.gdignore"))) "generated_tests contains a forbidden .gdignore."
Assert-True ($checkGodotSource.Contains('$FoundationSuiteBudgetMultiplier = 1.5') -and $checkGodotSource.Contains('"foundation_systems" = 29.141')) "Foundation Systems timing baseline or multiplier changed."
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
