$script:IntegTerminalCases = @(
    [pscustomobject]@{ id = "clean_prepared_01"; seed = "INTEG06-1-CLEAN-PREPARED-001" },
    [pscustomobject]@{ id = "clean_prepared_02"; seed = "INTEG06-1-CLEAN-PREPARED-002" },
    [pscustomobject]@{ id = "clean_tight_01"; seed = "INTEG06-1-CLEAN-TIGHT-001" },
    [pscustomobject]@{ id = "clean_tight_02"; seed = "INTEG06-1-CLEAN-TIGHT-002" },
    [pscustomobject]@{ id = "cheat_prepared_01"; seed = "INTEG06-1-CHEAT-PREPARED-001" },
    [pscustomobject]@{ id = "cheat_prepared_02"; seed = "INTEG06-1-CHEAT-PREPARED-002" },
    [pscustomobject]@{ id = "cheat_tight_01"; seed = "INTEG06-1-CHEAT-TIGHT-001" },
    [pscustomobject]@{ id = "cheat_tight_02"; seed = "INTEG06-1-CHEAT-TIGHT-002" },
    [pscustomobject]@{ id = "crew_ignored_control"; seed = "INTEG06-1-CREW-IGNORED-001" }
)
$script:IntegRequiredSystemWitnesses = @(
    "crew", "crew_jobs", "crew_heist", "numbers", "delivery",
    "scenario", "police_sweep", "traveler", "coin_pusher"
)
$script:IntegRetainedGrowthLimits = [ordered]@{ nodes = 8; resources = 8; objects = 32 }
$script:IntegMaxStateBytes = 1500000

function Get-IntegObjectValue {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    if ($Object -is [Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-IntegPropertyNames {
    param([object]$Object)
    if ($null -eq $Object) { return @() }
    if ($Object -is [Collections.IDictionary]) { return @($Object.Keys | ForEach-Object { [string]$_ }) }
    return @($Object.PSObject.Properties | ForEach-Object { [string]$_.Name })
}

function ConvertTo-IntegArray {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    return @($Value)
}

function Add-IntegExactSetFailures {
    param([object[]]$Expected, [object[]]$Actual, [string]$Label, [Collections.Generic.List[string]]$Failures)
    $expectedSet = @{}
    $actualSet = @{}
    foreach ($value in @($Expected)) {
        $key = [string]$value
        if ($expectedSet.ContainsKey($key)) { $Failures.Add("$Label expected set contains duplicate '$key'.") }
        else { $expectedSet[$key] = $true }
    }
    foreach ($value in @($Actual)) {
        $key = [string]$value
        if ($actualSet.ContainsKey($key)) { $Failures.Add("$Label contains duplicate '$key'.") }
        else { $actualSet[$key] = $true }
    }
    foreach ($key in $expectedSet.Keys) { if (-not $actualSet.ContainsKey($key)) { $Failures.Add("$Label is missing '$key'.") } }
    foreach ($key in $actualSet.Keys) { if (-not $expectedSet.ContainsKey($key)) { $Failures.Add("$Label contains unexpected '$key'.") } }
}

function Get-IntegExpectedShardCases {
    param([int]$ShardIndex, [int]$ShardCount)
    $result = [Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $script:IntegTerminalCases.Count; $index++) {
        if ($index % $ShardCount -eq $ShardIndex) { $result.Add($script:IntegTerminalCases[$index]) }
    }
    return @($result)
}

function Get-IntegTerminalShardFailures {
    param([object]$Report, [int]$ExpectedShardIndex, [int]$ExpectedShardCount, [string]$Label)
    $failures = [Collections.Generic.List[string]]::new()
    if ($null -eq $Report) { return @("$Label is missing.") }
    $shard = Get-IntegObjectValue $Report "shard"
    if ($null -eq $shard -or [int](Get-IntegObjectValue $shard "index") -ne $ExpectedShardIndex -or [int](Get-IntegObjectValue $shard "count") -ne $ExpectedShardCount) {
        $failures.Add("$Label shard index/count does not match $ExpectedShardIndex/$ExpectedShardCount.")
    }

    $expectedCases = @(Get-IntegExpectedShardCases $ExpectedShardIndex $ExpectedShardCount)
    $expectedIds = @($expectedCases | ForEach-Object { [string]$_.id })
    $expectedSeeds = @($expectedCases | ForEach-Object { [string]$_.seed })
    $rows = @(ConvertTo-IntegArray (Get-IntegObjectValue $Report "rows") | Where-Object { $null -ne $_ })
    $actualIds = @($rows | ForEach-Object { [string](Get-IntegObjectValue $_ "case_id") })
    Add-IntegExactSetFailures $expectedIds $actualIds "$Label case ids" $failures
    foreach ($row in $rows) {
        $caseId = [string](Get-IntegObjectValue $row "case_id")
        $expected = @($expectedCases | Where-Object { [string]$_.id -ceq $caseId })
        if ($expected.Count -eq 1 -and [string](Get-IntegObjectValue $row "seed") -cne [string]$expected[0].seed) {
            $failures.Add("$Label case '$caseId' has the wrong seed.")
        }
    }
    Add-IntegExactSetFailures $expectedSeeds @(ConvertTo-IntegArray (Get-IntegObjectValue $shard "seed_ids")) "$Label shard seed ids" $failures

    $required = @(ConvertTo-IntegArray (Get-IntegObjectValue $Report "required_active_systems"))
    Add-IntegExactSetFailures $script:IntegRequiredSystemWitnesses $required "$Label required active systems" $failures
    $witnesses = Get-IntegObjectValue $Report "system_witnesses"
    $witnessNames = @(Get-IntegPropertyNames $witnesses | Where-Object { @(ConvertTo-IntegArray (Get-IntegObjectValue $witnesses $_)).Count -gt 0 })
    Add-IntegExactSetFailures $witnessNames @(ConvertTo-IntegArray (Get-IntegObjectValue $Report "active_systems")) "$Label active systems" $failures
    foreach ($system in $witnessNames) {
        if ($script:IntegRequiredSystemWitnesses -cnotcontains $system) {
            $failures.Add("$Label has an unexpected active-system witness '$system'.")
            continue
        }
        foreach ($witness in @(ConvertTo-IntegArray (Get-IntegObjectValue $witnesses $system))) {
            $caseId = [string](Get-IntegObjectValue $witness "case_id")
            if ($expectedIds -cnotcontains $caseId) { $failures.Add("$Label $system witness names an out-of-shard case '$caseId'.") }
            $caseRows = @($rows | Where-Object { [string](Get-IntegObjectValue $_ "case_id") -ceq $caseId })
            $witnessSeed = [string](Get-IntegObjectValue $witness "seed")
            $evidence = Get-IntegObjectValue $witness "evidence"
            if ($caseRows.Count -ne 1 -or $witnessSeed -cne [string](Get-IntegObjectValue $caseRows[0] "seed")) {
                $failures.Add("$Label $system witness seed does not match its exact case custody.")
            }
            if ([string]::IsNullOrWhiteSpace($witnessSeed) -or
                [string]::IsNullOrWhiteSpace([string](Get-IntegObjectValue $witness "trace_label")) -or
                $null -eq (Get-IntegObjectValue $witness "action_index") -or
                $null -eq $evidence -or @(Get-IntegPropertyNames $evidence).Count -eq 0) {
                $failures.Add("$Label $system witness is missing seed/action/trace/evidence custody.")
            }
        }
    }

    $retained = Get-IntegObjectValue $Report "retained_counters"
    if ($null -eq $retained -or -not [bool](Get-IntegObjectValue $retained "available")) {
        $failures.Add("$Label retained counters are unavailable.")
    } else {
        Add-IntegExactSetFailures @("resources", "objects", "nodes", "orphans", "state_bytes") @(ConvertTo-IntegArray (Get-IntegObjectValue $retained "measured")) "$Label retained measured counters" $failures
        $growth = Get-IntegObjectValue $retained "growth"
        $limits = Get-IntegObjectValue $retained "limits"
        $baseline = Get-IntegObjectValue $retained "baseline"
        $preRun = Get-IntegObjectValue $retained "pre_run"
        if ($null -eq $baseline -or $null -eq $preRun) { $failures.Add("$Label retained pre-run/baseline snapshots are missing.") }
        $samples = @(ConvertTo-IntegArray (Get-IntegObjectValue $retained "samples") | Where-Object { $null -ne $_ })
        Add-IntegExactSetFailures $expectedIds @($samples | ForEach-Object { [string](Get-IntegObjectValue $_ "case_id") }) "$Label retained sample case ids" $failures
        foreach ($metric in $script:IntegRetainedGrowthLimits.Keys) {
            $growthValue = Get-IntegObjectValue $growth $metric
            $limitValue = Get-IntegObjectValue $limits $metric
            $baselineValue = Get-IntegObjectValue $baseline $metric
            $finalValue = Get-IntegObjectValue $retained $metric
            if ($null -eq $growthValue -or $null -eq $limitValue -or $null -eq $baselineValue -or $null -eq $finalValue) {
                $failures.Add("$Label retained $metric final/baseline/growth/limit is missing.")
                continue
            }
            if ([int64]$limitValue -ne [int64]$script:IntegRetainedGrowthLimits[$metric]) { $failures.Add("$Label retained $metric limit changed from the release bound.") }
            if ([int64]$growthValue -ne [int64]$finalValue - [int64]$baselineValue) { $failures.Add("$Label retained $metric growth does not match final minus baseline.") }
            if ([int64]$growthValue -gt [int64]$script:IntegRetainedGrowthLimits[$metric]) { $failures.Add("$Label retained $metric growth exceeds the release bound.") }
        }
        $orphanValue = Get-IntegObjectValue $retained "orphans"
        $orphanBaseline = Get-IntegObjectValue $baseline "orphans"
        $orphanGrowth = Get-IntegObjectValue $growth "orphans"
        if ($null -eq $orphanValue -or $null -eq $orphanBaseline -or $null -eq $orphanGrowth) { $failures.Add("$Label retained orphan final/baseline/growth is missing.") }
        elseif ([int64]$orphanGrowth -ne [int64]$orphanValue - [int64]$orphanBaseline) { $failures.Add("$Label retained orphan growth does not match final minus baseline.") }
        elseif ([int64]$orphanValue -ne 0) { $failures.Add("$Label retained orphan count is not zero.") }
        $stateBytes = Get-IntegObjectValue $retained "state_bytes"
        if ($null -eq $stateBytes -or [int64]$stateBytes -le 0) { $failures.Add("$Label retained state size is missing or empty.") }
        elseif ([int64]$stateBytes -gt $script:IntegMaxStateBytes) { $failures.Add("$Label retained state size exceeds the release bound.") }
    }
    return @($failures)
}

function Get-IntegTerminalAggregateFailures {
    param([object[]]$Reports, [string]$Label)
    $failures = [Collections.Generic.List[string]]::new()
    $allRows = @($Reports | ForEach-Object { @(ConvertTo-IntegArray (Get-IntegObjectValue $_ "rows")) })
    $actualIds = @($allRows | ForEach-Object { [string](Get-IntegObjectValue $_ "case_id") })
    Add-IntegExactSetFailures @($script:IntegTerminalCases | ForEach-Object { [string]$_.id }) $actualIds "$Label aggregate case ids" $failures
    foreach ($system in $script:IntegRequiredSystemWitnesses) {
        $records = @($Reports | ForEach-Object {
            $witnesses = Get-IntegObjectValue $_ "system_witnesses"
            @(ConvertTo-IntegArray (Get-IntegObjectValue $witnesses $system))
        } | Where-Object { $null -ne $_ })
        if ($records.Count -eq 0) { $failures.Add("$Label has no exact active-system witness for '$system'.") }
    }
    return @($failures)
}
