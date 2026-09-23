param(
    [int]$Visits = 6,
    [int]$ChildTimeoutSeconds = 180,
    [int]$SlotWaitTimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
if ($Visits -lt 6) {
    throw "UIENV-PF-003..008 exact-seed contract requires Visits >= 6; got $Visits."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$auditScript = Join-Path $PSScriptRoot "environment_generation_audit.ps1"
$evidenceDirectory = Join-Path $projectRoot ".tmp\postfix06_2_environment_exact_seeds"
$scenarioCatalogPath = Join-Path $projectRoot "data\environments\scenarios.json"

function Get-RunningGodotProcesses {
    return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '^Godot.*\.exe$'
    })
}

function Wait-ForGodotSlot {
    param([string]$Seed)
    $deadline = [DateTime]::UtcNow.AddSeconds($SlotWaitTimeoutSeconds)
    do {
        $running = @(Get-RunningGodotProcesses)
        if ($running.Count -eq 0) {
            Write-Host "POSTFIX06_2_ENVIRONMENT_EXACT_SEED SLOT seed=$Seed godot_process_count=0"
            return $true
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    $details = ($running | ForEach-Object { "$($_.ProcessId):$($_.Name)" }) -join ', '
    [Console]::Error.WriteLine("POSTFIX06_2_ENVIRONMENT_EXACT_SEED SLOT_TIMEOUT seed=$Seed running=$details")
    return $false
}

function Stop-DisposableProcessTree {
    param([int]$ProcessId)
    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue)
    foreach ($child in $children) {
        Stop-DisposableProcessTree -ProcessId ([int]$child.ProcessId)
    }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

function Test-TextContainsOrdinal {
    param(
        [AllowEmptyString()][string]$Text,
        [AllowEmptyString()][string]$Expected
    )
    if ([string]::IsNullOrEmpty($Expected)) {
        return $true
    }
    if ($null -eq $Text) {
        return $false
    }
    return $Text.IndexOf($Expected, [StringComparison]::Ordinal) -ge 0
}

function Test-ExactSeedEvidence {
    param(
        [pscustomobject]$Expectation,
        [string]$EvidencePath,
        [int]$RequestedVisits
    )

    $issues = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
        $issues.Add("missing JSON evidence at $EvidencePath")
        return $issues
    }

    try {
        $evidence = Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $issues.Add("could not parse JSON evidence at $EvidencePath`: $($_.Exception.Message)")
        return $issues
    }

    $runs = @($evidence.runs)
    $environmentRecords = @($evidence.environment_records)
    $travelRecords = @($evidence.travel_records)
    $reportedFailures = @($evidence.failures)
    if ([int]$evidence.run_count -ne 1 -or $runs.Count -ne 1) {
        $issues.Add("expected exactly one run, report run_count=$($evidence.run_count) runs=$($runs.Count)")
    }
    if ([int]$evidence.visits_per_run_target -ne $RequestedVisits) {
        $issues.Add("report visits_per_run_target=$($evidence.visits_per_run_target), expected $RequestedVisits")
    }
    if (($evidence.passed -isnot [bool]) -or (-not $evidence.passed)) {
        $issues.Add("report passed was not true")
    }
    if ($null -eq $evidence.failure_count -or [int]$evidence.failure_count -ne 0) {
        $issues.Add("report failure_count=$($evidence.failure_count), expected 0")
    }
    if ($reportedFailures.Count -ne 0) {
        $issues.Add("report failures array contained $($reportedFailures.Count) item(s), expected 0")
    }

    $reserve = $evidence.audit_survival_reserve
    if ($null -eq $reserve -or ($reserve.enabled -isnot [bool]) -or (-not $reserve.enabled)) {
        $issues.Add("audit-only survival reserve evidence was missing or not enabled")
    }
    else {
        if ([string]$reserve.scope -cne "audit_process_only") {
            $issues.Add("audit-only survival reserve scope '$($reserve.scope)' was not audit_process_only")
        }
        if ([string]$reserve.policy -cne "minimal_event_and_travel_continuity") {
            $issues.Add("audit-only survival reserve policy '$($reserve.policy)' was unexpected")
        }
        if ([int]$reserve.bankroll_floor -ne 1) {
            $issues.Add("audit-only survival reserve bankroll_floor=$($reserve.bankroll_floor), expected 1")
        }
        $reserveGrants = @($reserve.grants)
        if ([int]$reserve.grant_count -ne $reserveGrants.Count) {
            $issues.Add("audit-only survival reserve grant_count=$($reserve.grant_count) but grants=$($reserveGrants.Count)")
        }
        $terminalReservePhases = @("pre_event_settlement", "pre_travel_settlement")
        $reserveTotal = 0
        foreach ($grant in $reserveGrants) {
            $phase = [string]$grant.phase
            $bankrollBefore = [long]$grant.bankroll_before
            $settlementDelta = [long]$grant.settlement_delta
            $projectedWithoutGrant = [long]$grant.projected_bankroll_without_grant
            $amount = [long]$grant.amount
            $bankrollAfterGrant = [long]$grant.bankroll_after_grant
            $reserveTotal += $amount
            if (($grant.audit_only -isnot [bool]) -or (-not $grant.audit_only)) {
                $issues.Add("survival reserve grant was not marked audit_only=true")
            }
            if ([string]$grant.seed -cne [string]$Expectation.Seed) {
                $issues.Add("survival reserve grant seed '$($grant.seed)' did not exactly match '$($Expectation.Seed)'")
            }
            if ($amount -le 0 -or $bankrollAfterGrant -ne ($bankrollBefore + $amount)) {
                $issues.Add("survival reserve grant had invalid bankroll arithmetic: $($grant | ConvertTo-Json -Compress)")
            }
            $computedProjection = $bankrollBefore + $settlementDelta
            if ($projectedWithoutGrant -ne $computedProjection) {
                $issues.Add("survival reserve grant projected_bankroll_without_grant=$projectedWithoutGrant, computed $computedProjection`: $($grant | ConvertTo-Json -Compress)")
            }
            if ($terminalReservePhases -ccontains $phase) {
                $expectedAmount = [Math]::Max([long]0, ([long]$reserve.bankroll_floor - $computedProjection))
                if ($amount -ne $expectedAmount) {
                    $issues.Add("survival reserve $phase grant amount=$amount, exact minimum for bankroll floor $($reserve.bankroll_floor) is $expectedAmount`: $($grant | ConvertTo-Json -Compress)")
                }
            }
            elseif ($phase -ceq "route_access") {
                $routeCost = -$settlementDelta
                $expectedAmount = [Math]::Max([long]0, ($routeCost - $bankrollBefore))
                if ($settlementDelta -ge 0 -or $amount -ne $expectedAmount) {
                    $issues.Add("survival reserve route_access grant amount=$amount, exact minimum to afford route cost $routeCost is $expectedAmount`: $($grant | ConvertTo-Json -Compress)")
                }
            }
            else {
                $issues.Add("survival reserve grant phase '$phase' was not an allowed audit phase")
            }
        }
        if ([int]$reserve.total_granted -ne $reserveTotal) {
            $issues.Add("audit-only survival reserve total_granted=$($reserve.total_granted), computed $reserveTotal")
        }
    }

    $run = $null
    if ($runs.Count -eq 1) {
        $run = $runs[0]
        if ([string]$run.seed -cne [string]$Expectation.Seed) {
            $issues.Add("run seed '$($run.seed)' did not exactly match '$($Expectation.Seed)'")
        }
        $runReserve = $run.audit_survival_reserve
        if ($null -eq $runReserve -or ($runReserve.enabled -isnot [bool]) -or (-not $runReserve.enabled)) {
            $issues.Add("run summary did not retain enabled audit-only survival reserve evidence")
        }
        elseif ([int]$runReserve.grant_count -ne @($runReserve.grants).Count) {
            $issues.Add("run survival reserve grant_count=$($runReserve.grant_count) but grants=$(@($runReserve.grants).Count)")
        }
        elseif ($null -ne $reserve -and [int]$runReserve.grant_count -ne [int]$reserve.grant_count) {
            $issues.Add("single-run survival reserve evidence diverged: run=$($runReserve.grant_count) report=$($reserve.grant_count)")
        }
        if (($run.requested_visits_satisfied -isnot [bool]) -or (-not $run.requested_visits_satisfied)) {
            $issues.Add("run did not report requested_visits_satisfied=true")
        }
        if ([string]$run.stopped_reason -cne "completed") {
            $issues.Add("run stopped_reason '$($run.stopped_reason)' was not completed")
        }
    }
    $foreignEnvironmentSeeds = @($environmentRecords | Where-Object {
        [string]$_.seed -cne [string]$Expectation.Seed
    })
    if ($foreignEnvironmentSeeds.Count -gt 0) {
        $issues.Add("$($foreignEnvironmentSeeds.Count) environment record(s) did not carry the exact seed")
    }
    $foreignTravelSeeds = @($travelRecords | Where-Object {
        [string]$_.seed -cne [string]$Expectation.Seed
    })
    if ($foreignTravelSeeds.Count -gt 0) {
        $issues.Add("$($foreignTravelSeeds.Count) travel record(s) did not carry the exact seed")
    }

    # The audit schema does not expose scenario_id directly. The startup checks
    # below prove ScenarioEvent is authored by exactly Expectation.Scenario, so
    # requiring that marker here establishes the exact scenario identity too.
    $matchingTargetRecords = @($environmentRecords | Where-Object {
        if ([string]$_.seed -cne [string]$Expectation.Seed) {
            return $false
        }
        if ([string]$_.archetype_id -cne [string]$Expectation.Destination) {
            return $false
        }
        $eventIds = @($_.events)
        if ($eventIds -cnotcontains [string]$Expectation.ScenarioEvent) {
            return $false
        }
        if (-not [string]::IsNullOrEmpty([string]$Expectation.RequiredEvent) -and
            $eventIds -cnotcontains [string]$Expectation.RequiredEvent) {
            return $false
        }
        return $true
    })
    $matchingTargetTravels = @($travelRecords | Where-Object {
        [string]$_.seed -ceq [string]$Expectation.Seed -and
        [string]$_.target_id -ceq [string]$Expectation.Destination -and
        [string]$_.to_archetype_id -ceq [string]$Expectation.Destination
    })

    # Old failing reports stop before installing the destination environment.
    # Keep that state diagnosable by recognizing the exact attempted route and
    # collision signature. It cannot make the suite pass because passed=true
    # and failure_count=0 are independently mandatory above.
    $failureText = ($reportedFailures | ForEach-Object { [string]$_ }) -join "`n"
    $historicalTravelAttempt = @($travelRecords | Where-Object {
        [string]$_.seed -ceq [string]$Expectation.Seed -and
        [string]$_.target_id -ceq [string]$Expectation.Destination
    }).Count -gt 0
    $historicalTargetIdentified =
        (-not $evidence.passed) -and
        $historicalTravelAttempt -and
        (Test-TextContainsOrdinal -Text $failureText -Expected "travel to $($Expectation.Destination)") -and
        (Test-TextContainsOrdinal -Text $failureText -Expected $Expectation.HistoricalInteraction) -and
        (Test-TextContainsOrdinal -Text $failureText -Expected $Expectation.HistoricalConflict)

    if ($matchingTargetRecords.Count -eq 0 -and -not $historicalTargetIdentified) {
        $composition = "$($Expectation.Destination)/$($Expectation.Scenario) via $($Expectation.ScenarioEvent)"
        if (-not [string]::IsNullOrEmpty([string]$Expectation.RequiredEvent)) {
            $composition += " with $($Expectation.RequiredEvent)"
        }
        $issues.Add("expected PF composition was not observed: $composition")
    }
    if ($matchingTargetTravels.Count -eq 0 -and -not $historicalTargetIdentified) {
        $issues.Add("expected destination travel was not completed: $($Expectation.Destination)")
    }

    $minimumVisits = [Math]::Max(6, $RequestedVisits)
    $minimumTravels = $minimumVisits - 1
    $completedTravelRecords = @($travelRecords | Where-Object {
        [string]$_.seed -ceq [string]$Expectation.Seed -and
        -not [string]::IsNullOrWhiteSpace([string]$_.to_archetype_id)
    })
    $trajectoryComplete = $null -ne $run -and
        [int]$run.environment_count -ge $minimumVisits -and
        @($run.visited).Count -ge $minimumVisits -and
        [int]$run.travel_count -ge $minimumTravels -and
        $environmentRecords.Count -ge $minimumVisits -and
        $completedTravelRecords.Count -ge $minimumTravels
    if (-not $trajectoryComplete -and -not $historicalTargetIdentified) {
        $actualVisits = if ($null -eq $run) { 0 } else { [int]$run.environment_count }
        $actualVisited = if ($null -eq $run) { 0 } else { @($run.visited).Count }
        $actualTravels = if ($null -eq $run) { 0 } else { [int]$run.travel_count }
        $issues.Add("trajectory incomplete: environments=$actualVisits visited=$actualVisited travels=$actualTravels; expected at least $minimumVisits visits and $minimumTravels travels")
    }

    return $issues
}

# Preserved UIENV-PF-003..008 reproductions from the 2026-09-21 post-fix
# playtest. Each audit is a separate synchronous process: never run this list
# through ForEach-Object -Parallel or background jobs.
$expectations = @(
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-009-4151570434"; Destination = "bar"; Scenario = "bar_fight_night"; ScenarioEvent = "scenario_fight_night_swing_bet"; RequiredEvent = ""; HistoricalInteraction = "scenario::bar_fight_night_safe_exit"; HistoricalConflict = "" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-015-1938529946"; Destination = "bar"; Scenario = "bar_fight_night"; ScenarioEvent = "scenario_fight_night_swing_bet"; RequiredEvent = ""; HistoricalInteraction = "scenario::bar_fight_night_safe_exit"; HistoricalConflict = "" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-031-2491917705"; Destination = "bar"; Scenario = "bar_fight_night"; ScenarioEvent = "scenario_fight_night_swing_bet"; RequiredEvent = ""; HistoricalInteraction = "scenario::bar_fight_night_safe_exit"; HistoricalConflict = "" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-036-3073861592"; Destination = "bar"; Scenario = "bar_fight_night"; ScenarioEvent = "scenario_fight_night_swing_bet"; RequiredEvent = ""; HistoricalInteraction = "scenario::bar_fight_night_safe_exit"; HistoricalConflict = "" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-037-655530953"; Destination = "bar"; Scenario = "bar_fight_night"; ScenarioEvent = "scenario_fight_night_swing_bet"; RequiredEvent = ""; HistoricalInteraction = "scenario::bar_fight_night_safe_exit"; HistoricalConflict = "" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-043-934268634"; Destination = "bar"; Scenario = "bar_fight_night"; ScenarioEvent = "scenario_fight_night_swing_bet"; RequiredEvent = ""; HistoricalInteraction = "scenario::bar_fight_night_safe_exit"; HistoricalConflict = "" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-054-1002983031"; Destination = "bar"; Scenario = "bar_fight_night"; ScenarioEvent = "scenario_fight_night_swing_bet"; RequiredEvent = ""; HistoricalInteraction = "scenario::bar_fight_night_safe_exit"; HistoricalConflict = "" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-073-140575119"; Destination = "bar"; Scenario = "bar_fight_night"; ScenarioEvent = "scenario_fight_night_swing_bet"; RequiredEvent = ""; HistoricalInteraction = "scenario::bar_fight_night_safe_exit"; HistoricalConflict = "" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-093-397681310"; Destination = "bar"; Scenario = "bar_fight_night"; ScenarioEvent = "scenario_fight_night_swing_bet"; RequiredEvent = ""; HistoricalInteraction = "scenario::bar_fight_night_safe_exit"; HistoricalConflict = "" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-098-1674379668"; Destination = "bar"; Scenario = "bar_fight_night"; ScenarioEvent = "scenario_fight_night_swing_bet"; RequiredEvent = ""; HistoricalInteraction = "scenario::bar_fight_night_safe_exit"; HistoricalConflict = "" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-007-2898334884"; Destination = "gas_station_casino"; Scenario = "gas_station_road_crew_payday"; ScenarioEvent = "scenario_road_crew_payday_pool"; RequiredEvent = "side_door"; HistoricalInteraction = "scenario::gas_station_road_crew_payday_station"; HistoricalConflict = "event::event:side_door" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-008-2688401675"; Destination = "gas_station_casino"; Scenario = "gas_station_road_crew_payday"; ScenarioEvent = "scenario_road_crew_payday_pool"; RequiredEvent = "side_door"; HistoricalInteraction = "scenario::gas_station_road_crew_payday_station"; HistoricalConflict = "event::event:side_door" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-018-2408131097"; Destination = "gas_station_casino"; Scenario = "gas_station_road_crew_payday"; ScenarioEvent = "scenario_road_crew_payday_pool"; RequiredEvent = "side_door"; HistoricalInteraction = "scenario::gas_station_road_crew_payday_station"; HistoricalConflict = "event::event:side_door" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-033-405233240"; Destination = "gas_station_casino"; Scenario = "gas_station_road_crew_payday"; ScenarioEvent = "scenario_road_crew_payday_pool"; RequiredEvent = "side_door"; HistoricalInteraction = "scenario::gas_station_road_crew_payday_station"; HistoricalConflict = "event::event:side_door" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-082-1306411836"; Destination = "gas_station_casino"; Scenario = "gas_station_road_crew_payday"; ScenarioEvent = "scenario_road_crew_payday_pool"; RequiredEvent = "side_door"; HistoricalInteraction = "scenario::gas_station_road_crew_payday_station"; HistoricalConflict = "event::event:side_door" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-092-1191177531"; Destination = "gas_station_casino"; Scenario = "gas_station_road_crew_payday"; ScenarioEvent = "scenario_road_crew_payday_pool"; RequiredEvent = "side_door"; HistoricalInteraction = "scenario::gas_station_road_crew_payday_station"; HistoricalConflict = "event::event:side_door" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-061-1987792568"; Destination = "corner_store"; Scenario = "corner_store_dead_shift"; ScenarioEvent = "scenario_dead_shift_rumor"; RequiredEvent = "town_rumor_staff"; HistoricalInteraction = "scenario::corner_store_dead_shift_exit"; HistoricalConflict = "event::event:town_rumor_staff" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-062-84881432"; Destination = "corner_store"; Scenario = "corner_store_dead_shift"; ScenarioEvent = "scenario_dead_shift_rumor"; RequiredEvent = "town_rumor_staff"; HistoricalInteraction = "scenario::corner_store_dead_shift_exit"; HistoricalConflict = "event::event:town_rumor_staff" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-087-3894813921"; Destination = "corner_store"; Scenario = "corner_store_dead_shift"; ScenarioEvent = "scenario_dead_shift_rumor"; RequiredEvent = "town_rumor_staff"; HistoricalInteraction = "scenario::corner_store_dead_shift_exit"; HistoricalConflict = "event::event:town_rumor_staff" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-090-235429475"; Destination = "corner_store"; Scenario = "corner_store_dead_shift"; ScenarioEvent = "scenario_dead_shift_rumor"; RequiredEvent = "late_shift_discount"; HistoricalInteraction = "scenario::corner_store_dead_shift_exit"; HistoricalConflict = "event::event:late_shift_discount" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-040-2723440700"; Destination = "corner_store"; Scenario = "corner_store_inventory_night"; ScenarioEvent = "scenario_inventory_night_count"; RequiredEvent = "scenario_inventory_night_count"; HistoricalInteraction = "scenario::count_cage"; HistoricalConflict = "event::event:scenario_inventory_night_count" },
    [pscustomobject]@{ Seed = "POSTFIX-UIENV-063-608418289"; Destination = "corner_store"; Scenario = "corner_store_inventory_night"; ScenarioEvent = "scenario_inventory_night_count"; RequiredEvent = "parking_lot_tip"; HistoricalInteraction = "scenario::count_cage"; HistoricalConflict = "event::event:parking_lot_tip" }
)

if ($expectations.Count -ne 22) {
    throw "UIENV-PF-003..008 exact-seed census changed: expected 22, got $($expectations.Count)."
}
$uniqueSeeds = @($expectations | ForEach-Object { [string]$_.Seed } | Sort-Object -Unique)
if ($uniqueSeeds.Count -ne 22) {
    throw "UIENV-PF-003..008 exact-seed census contains duplicate seed identities."
}
if (-not (Test-Path -LiteralPath $scenarioCatalogPath -PathType Leaf)) {
    throw "Missing scenario catalog: $scenarioCatalogPath"
}
$scenarioCatalog = Get-Content -LiteralPath $scenarioCatalogPath -Raw | ConvertFrom-Json -ErrorAction Stop
foreach ($expectation in $expectations) {
    $destinationProperty = $scenarioCatalog.PSObject.Properties[[string]$expectation.Destination]
    if ($null -eq $destinationProperty) {
        throw "Exact-seed expectation $($expectation.Seed) references unknown destination $($expectation.Destination)."
    }
    $scenarioMatches = @($destinationProperty.Value | Where-Object {
        [string]$_.id -ceq [string]$expectation.Scenario
    })
    if ($scenarioMatches.Count -ne 1) {
        throw "Exact-seed expectation $($expectation.Seed) requires one exact scenario $($expectation.Scenario); found $($scenarioMatches.Count)."
    }
    $scenarioEvents = @($scenarioMatches[0].mutations.event_pool_add)
    if ($scenarioEvents -cnotcontains [string]$expectation.ScenarioEvent) {
        throw "Exact-seed expectation $($expectation.Seed) marker $($expectation.ScenarioEvent) is not authored by scenario $($expectation.Scenario)."
    }
    $markerOwners = [System.Collections.Generic.List[string]]::new()
    foreach ($destination in $scenarioCatalog.PSObject.Properties) {
        foreach ($scenario in @($destination.Value)) {
            if (@($scenario.mutations.event_pool_add) -ccontains [string]$expectation.ScenarioEvent) {
                $markerOwners.Add("$($destination.Name)/$($scenario.id)")
            }
        }
    }
    $expectedOwner = "$($expectation.Destination)/$($expectation.Scenario)"
    if ($markerOwners.Count -ne 1 -or $markerOwners[0] -cne $expectedOwner) {
        throw "Exact-seed expectation $($expectation.Seed) marker $($expectation.ScenarioEvent) must uniquely identify $expectedOwner; owners=$($markerOwners -join ',')."
    }
}
if (-not (Test-Path -LiteralPath $auditScript -PathType Leaf)) {
    throw "Missing maintained environment audit: $auditScript"
}
[void][System.IO.Directory]::CreateDirectory($evidenceDirectory)

$failures = [System.Collections.Generic.List[string]]::new()
$index = 0
$suiteTimer = [System.Diagnostics.Stopwatch]::StartNew()
foreach ($expectation in $expectations) {
    $seed = [string]$expectation.Seed
    $index += 1
    if (-not (Wait-ForGodotSlot -Seed $seed)) {
        $failures.Add("$seed could not acquire an empty Godot slot")
        continue
    }
    $safeSeed = $seed -replace '[^A-Za-z0-9._-]', '_'
    $jsonOutput = "res://.tmp/postfix06_2_environment_exact_seeds/$safeSeed.json"
    $markdownOutput = "res://.tmp/postfix06_2_environment_exact_seeds/$safeSeed.md"
    $jsonEvidencePath = Join-Path $evidenceDirectory "$safeSeed.json"
    $markdownEvidencePath = Join-Path $evidenceDirectory "$safeSeed.md"
    Remove-Item -LiteralPath $jsonEvidencePath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $markdownEvidencePath -Force -ErrorAction SilentlyContinue
    Write-Host "POSTFIX06_2_ENVIRONMENT_EXACT_SEED CHECK $index/$($expectations.Count) seed=$seed target=$($expectation.Destination)/$($expectation.Scenario)"
    $seedTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $exitCode = -1
    $timedOut = $false
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $auditScript,
        '-Runs', '1',
        '-Visits', [string]$Visits,
        '-ExactSeed', $seed,
        '-AuditSurvivalReserve',
        '-Output', $jsonOutput,
        '-Report', $markdownOutput,
        '-RequireGodot'
    )
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = 'powershell.exe'
    # These maintained paths/seeds contain no whitespace or quotes. Keeping the
    # native argument string explicit also avoids Start-Process losing ExitCode
    # after redirected child completion on Windows PowerShell 5.1.
    $startInfo.Arguments = $arguments -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $null = $process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($ChildTimeoutSeconds * 1000)) {
        $timedOut = $true
        Stop-DisposableProcessTree -ProcessId $process.Id
        $process.WaitForExit()
    }
    else {
        $process.WaitForExit()
        $exitCode = [int]$process.ExitCode
    }
    $standardOutput = $stdoutTask.GetAwaiter().GetResult()
    $standardError = $stderrTask.GetAwaiter().GetResult()
    if (-not [string]::IsNullOrWhiteSpace($standardOutput)) {
        [Console]::Out.Write($standardOutput)
    }
    if (-not [string]::IsNullOrWhiteSpace($standardError)) {
        [Console]::Error.Write($standardError)
    }
    $seedTimer.Stop()
    $evidenceIssues = @(Test-ExactSeedEvidence -Expectation $expectation -EvidencePath $jsonEvidencePath -RequestedVisits $Visits)
    foreach ($evidenceIssue in $evidenceIssues) {
        $failures.Add("$seed evidence: $evidenceIssue")
    }
    if ($timedOut) {
        $failures.Add("$seed exceeded $ChildTimeoutSeconds seconds")
        Write-Host "POSTFIX06_2_ENVIRONMENT_EXACT_SEED RESULT seed=$seed outcome=TIMEOUT elapsed_seconds=$([Math]::Round($seedTimer.Elapsed.TotalSeconds, 3))"
    }
    elseif ($exitCode -ne 0) {
        $failures.Add("$seed exited $exitCode")
        Write-Host "POSTFIX06_2_ENVIRONMENT_EXACT_SEED RESULT seed=$seed outcome=FAIL exit=$exitCode elapsed_seconds=$([Math]::Round($seedTimer.Elapsed.TotalSeconds, 3))"
    }
    elseif ($evidenceIssues.Count -gt 0) {
        Write-Host "POSTFIX06_2_ENVIRONMENT_EXACT_SEED RESULT seed=$seed outcome=EVIDENCE_FAIL issues=$($evidenceIssues.Count) elapsed_seconds=$([Math]::Round($seedTimer.Elapsed.TotalSeconds, 3))"
    }
    else {
        Write-Host "POSTFIX06_2_ENVIRONMENT_EXACT_SEED RESULT seed=$seed outcome=PASS exit=0 elapsed_seconds=$([Math]::Round($seedTimer.Elapsed.TotalSeconds, 3))"
    }
}
$suiteTimer.Stop()

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        [Console]::Error.WriteLine("POSTFIX06_2_ENVIRONMENT_EXACT_SEED FAIL $failure")
    }
    [Console]::Error.WriteLine("POSTFIX06_2_ENVIRONMENT_EXACT_SEED FAIL seeds=$($expectations.Count) failures=$($failures.Count) visits=$Visits serialized=true evidence_validated=true elapsed_seconds=$([Math]::Round($suiteTimer.Elapsed.TotalSeconds, 3))")
    exit 1
}

Write-Host "POSTFIX06_2_ENVIRONMENT_EXACT_SEED PASS seeds=22 visits=$Visits serialized=true evidence_validated=true elapsed_seconds=$([Math]::Round($suiteTimer.Elapsed.TotalSeconds, 3))"
exit 0
