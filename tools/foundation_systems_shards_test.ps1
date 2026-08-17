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
    passed = $false
    failures = @("hostile shard assertion")
    checks = @([pscustomobject]@{ id = "alpha"; duration_msec = 1; failure_count = 1; failures = @("hostile shard assertion") })
    last_started_check = "alpha"
    registered_check_ids = @("alpha", "beta")
}
$passedReport = [pscustomobject]@{
    passed = $true
    failures = @()
    checks = @([pscustomobject]@{ id = "beta"; duration_msec = 1; failure_count = 0; failures = @() })
    last_started_check = "beta"
    registered_check_ids = @("alpha", "beta")
}
$aggregate = Merge-FoundationSystemsShardReports -ExpectedIds @("alpha", "beta") -ShardResults @(
    [pscustomobject]@{ shard_id = "first"; expected_check_ids = @("alpha"); exit_code = 1; timed_out = $false; duration_msec = 2; report = $failedReport; report_path = "first.json"; stdout_path = "first.out"; stderr_path = "first.err"; stderr_issues = @(); last_started_check = "alpha" },
    [pscustomobject]@{ shard_id = "second"; expected_check_ids = @("beta"); exit_code = 0; timed_out = $false; duration_msec = 2; report = $passedReport; report_path = "second.json"; stdout_path = "second.out"; stderr_path = "second.err"; stderr_issues = @(); last_started_check = "beta" }
)
Assert-True (-not $aggregate.passed) "Aggregate accepted a failing shard report."
Assert-True ($aggregate.exit_code -ne 0) "Aggregate failure did not propagate a nonzero exit code."
Assert-True ((@($aggregate.report.failures) -join " | ").Contains("hostile shard assertion")) "Aggregate dropped the shard assertion failure."
Assert-True ($aggregate.report.checks.Count -eq 2) "Aggregate dropped executed check evidence while propagating failure."

if (-not $Quiet) {
    Write-Host "Foundation systems shard hostile contracts passed."
}
