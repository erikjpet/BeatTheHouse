$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "integ06_1_terminal_soak_contract.ps1")

$failures = [Collections.Generic.List[string]]::new()
$checks = 0

function Assert-IntegTerminal {
    param([bool]$Condition, [string]$Message)
    $script:checks += 1
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Copy-IntegValue {
    param([object]$Value)
    return $Value | ConvertTo-Json -Depth 30 | ConvertFrom-Json
}

function New-IntegWitnessRecord {
    param([string]$CaseId, [string]$Seed)
    return [pscustomobject]@{
        case_id = $CaseId
        seed = $Seed
        action_index = 17
        trace_label = "before_action_017"
        evidence = [pscustomobject]@{ observed = $true }
    }
}

function New-IntegShardReport {
    param([int]$Index, [int]$Count, [switch]$WithAllWitnesses)
    $cases = @(Get-IntegExpectedShardCases $Index $Count)
    $rows = @($cases | ForEach-Object { [pscustomobject]@{ case_id = $_.id; seed = $_.seed } })
    $witnesses = [ordered]@{}
    if ($WithAllWitnesses) {
        foreach ($system in $script:IntegRequiredSystemWitnesses) {
            $witnesses[$system] = @(New-IntegWitnessRecord ([string]$cases[0].id) ([string]$cases[0].seed))
        }
    }
    $baseline = [pscustomobject]@{ nodes = 11; resources = 28; objects = 87; orphans = 0 }
    return [pscustomobject]@{
        shard = [pscustomobject]@{ index = $Index; count = $Count; seed_ids = @($cases | ForEach-Object seed) }
        rows = $rows
        required_active_systems = $script:IntegRequiredSystemWitnesses
        active_systems = @($witnesses.Keys)
        system_witnesses = [pscustomobject]$witnesses
        retained_counters = [pscustomobject]@{
            available = $true
            measured = @("resources", "objects", "nodes", "orphans", "state_bytes")
            nodes = 12; resources = 30; objects = 90; orphans = 0; state_bytes = 120000
            pre_run = [pscustomobject]@{ nodes = 10; resources = 27; objects = 84; orphans = 0 }
            baseline = $baseline
            growth = [pscustomobject]@{ nodes = 1; resources = 2; objects = 3; orphans = 0 }
            limits = [pscustomobject]@{ nodes = 8; resources = 8; objects = 32 }
            samples = @($cases | ForEach-Object { [pscustomobject]@{ case_id = $_.id; nodes = 12; resources = 30; objects = 90; orphans = 0 } })
        }
    }
}

$reports = @(
    (New-IntegShardReport 0 3 -WithAllWitnesses),
    (New-IntegShardReport 1 3),
    (New-IntegShardReport 2 3)
)
for ($index = 0; $index -lt $reports.Count; $index++) {
    Assert-IntegTerminal (@(Get-IntegTerminalShardFailures $reports[$index] $index 3 "valid shard $index").Count -eq 0) "Valid shard $index was rejected."
}
Assert-IntegTerminal (@(Get-IntegTerminalAggregateFailures $reports "valid aggregate").Count -eq 0) "Valid exact nine-case/witness aggregate was rejected."

$missing = Copy-IntegValue $reports
$missing[1].rows = @($missing[1].rows | Select-Object -Skip 1)
Assert-IntegTerminal (@(Get-IntegTerminalShardFailures $missing[1] 1 3 "missing case").Count -gt 0) "A missing terminal case was accepted."

$duplicate = Copy-IntegValue $reports
$duplicate[2].rows = @($duplicate[2].rows) + @($duplicate[2].rows[0])
Assert-IntegTerminal (@(Get-IntegTerminalShardFailures $duplicate[2] 2 3 "duplicate case").Count -gt 0) "A duplicate terminal case was accepted."

$misindexed = Copy-IntegValue $reports
$misindexed[0].shard.index = 1
Assert-IntegTerminal (@(Get-IntegTerminalShardFailures $misindexed[0] 0 3 "misindexed shard").Count -gt 0) "A misindexed terminal shard was accepted."

$missingWitness = Copy-IntegValue $reports
$missingWitness[0].system_witnesses.PSObject.Properties.Remove("coin_pusher")
$missingWitness[0].active_systems = @($missingWitness[0].active_systems | Where-Object { $_ -cne "coin_pusher" })
Assert-IntegTerminal (@(Get-IntegTerminalAggregateFailures $missingWitness "missing witness").Count -gt 0) "An aggregate missing a required system witness was accepted."

$growth = Copy-IntegValue $reports
$growth[2].retained_counters.growth.nodes = 9
Assert-IntegTerminal (@(Get-IntegTerminalShardFailures $growth[2] 2 3 "growth overflow").Count -gt 0) "Over-cap node growth was accepted."

$wrongLimit = Copy-IntegValue $reports
$wrongLimit[1].retained_counters.limits.objects = 33
Assert-IntegTerminal (@(Get-IntegTerminalShardFailures $wrongLimit[1] 1 3 "changed bound").Count -gt 0) "A changed retained-growth bound was accepted."

$missingGrowth = Copy-IntegValue $reports
$missingGrowth[1].retained_counters.growth.PSObject.Properties.Remove("resources")
Assert-IntegTerminal (@(Get-IntegTerminalShardFailures $missingGrowth[1] 1 3 "missing growth").Count -gt 0) "A missing retained-growth counter was accepted."

$wrongWitnessSeed = Copy-IntegValue $reports
$wrongWitnessSeed[0].system_witnesses.crew[0].seed = "WRONG-SEED"
Assert-IntegTerminal (@(Get-IntegTerminalShardFailures $wrongWitnessSeed[0] 0 3 "wrong witness seed").Count -gt 0) "A witness with false case custody was accepted."

if ($failures.Count -ne 0) {
    Write-Host "INTEG06_1_TERMINAL_CONTRACT_SELF_TEST_FAIL checks=$checks failures=$($failures.Count)" -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host " - $failure" }
    exit 1
}
Write-Host "INTEG06_1_TERMINAL_CONTRACT_SELF_TEST_PASS checks=$checks exact_cases=9 missing_duplicate_misindex_rejected=true missing_witness_rejected=true growth_and_bound_changes_rejected=true"
