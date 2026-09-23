param(
    [int]$Visits = 6,
    [int]$ChildTimeoutSeconds = 240,
    [switch]$RequireGodot,
    [switch]$ValidateManifestOnly
)

$ErrorActionPreference = "Stop"
if ($Visits -lt 6) {
    throw "rw06_1 historical UIENV regression requires Visits >= 6; got $Visits."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $PSScriptRoot "fixtures\rw06_1_environment_exact_seed_manifest.json"
$auditScript = Join-Path $PSScriptRoot "environment_generation_audit.ps1"
$staticChecker = Join-Path $PSScriptRoot "environment_fixed_slot_static_check.py"
$scenarioCatalogPath = Join-Path $projectRoot "data\environments\scenarios.json"
$evidenceDirectory = Join-Path $projectRoot ".tmp\rw06_1\exact_seed"
$staticReportPath = Join-Path $projectRoot ".tmp\rw06_1\static\exact_seed_preflight.json"
$suiteReportPath = Join-Path $evidenceDirectory "summary.json"

function Stop-DisposableProcessTree {
    param([int]$ProcessId)
    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue)
    foreach ($child in $children) {
        Stop-DisposableProcessTree -ProcessId ([int]$child.ProcessId)
    }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

function Quote-NativeArgument {
    param([AllowEmptyString()][string]$Value)
    return '"' + $Value.Replace('\', '\').Replace('"', '\"') + '"'
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
        $issues.Add("could not parse JSON evidence: $($_.Exception.Message)")
        return $issues
    }

    $runs = @($evidence.runs)
    $environmentRecords = @($evidence.environment_records)
    $travelRecords = @($evidence.travel_records)
    $reportedFailures = @($evidence.failures)
    if ([int]$evidence.run_count -ne 1 -or $runs.Count -ne 1) {
        $issues.Add("expected one run; report run_count=$($evidence.run_count) runs=$($runs.Count)")
    }
    if ([int]$evidence.visits_per_run_target -ne $RequestedVisits) {
        $issues.Add("visits_per_run_target=$($evidence.visits_per_run_target), expected $RequestedVisits")
    }
    if (($evidence.passed -isnot [bool]) -or (-not $evidence.passed)) {
        $issues.Add("report passed was not true")
    }
    if ([int]$evidence.failure_count -ne 0 -or $reportedFailures.Count -ne 0) {
        $issues.Add("audit reported failures=$($evidence.failure_count) array_count=$($reportedFailures.Count)")
    }

    $seed = [string]$Expectation.seed
    $destination = [string]$Expectation.destination
    $marker = [string]$Expectation.required_marker
    $requiredObject = [string]$Expectation.required_object
    $run = if ($runs.Count -eq 1) { $runs[0] } else { $null }
    if ($null -ne $run) {
        if ([string]$run.seed -cne $seed) {
            $issues.Add("run seed '$($run.seed)' did not exactly match '$seed'")
        }
        if ([string]$run.stopped_reason -cne "completed") {
            $issues.Add("run stopped_reason '$($run.stopped_reason)' was not completed")
        }
        if ([int]$run.environment_count -lt $RequestedVisits -or @($run.visited).Count -lt $RequestedVisits) {
            $issues.Add("run visited $($run.environment_count)/$(@($run.visited).Count), expected at least $RequestedVisits")
        }
        if ([int]$run.travel_count -lt ($RequestedVisits - 1)) {
            $issues.Add("run completed $($run.travel_count) travel transitions, expected at least $($RequestedVisits - 1)")
        }
    }

    if (@($environmentRecords | Where-Object { [string]$_.seed -cne $seed }).Count -gt 0) {
        $issues.Add("one or more environment records carried a foreign seed")
    }
    if (@($travelRecords | Where-Object { [string]$_.seed -cne $seed }).Count -gt 0) {
        $issues.Add("one or more travel records carried a foreign seed")
    }
    $matchingTargetRecords = @($environmentRecords | Where-Object {
        if ([string]$_.seed -cne $seed -or [string]$_.archetype_id -cne $destination) {
            return $false
        }
        $events = @($_.events)
        if ($events -cnotcontains $marker) {
            return $false
        }
        if (-not [string]::IsNullOrWhiteSpace($requiredObject) -and $events -cnotcontains $requiredObject) {
            return $false
        }
        return $true
    })
    if ($matchingTargetRecords.Count -eq 0) {
        $composition = "$destination/$($Expectation.scenario_id) marker=$marker"
        if (-not [string]::IsNullOrWhiteSpace($requiredObject)) {
            $composition += " base_object=$requiredObject"
        }
        $issues.Add("expected exact-seed composition was not observed: $composition")
    }
    $matchingTargetTravels = @($travelRecords | Where-Object {
        [string]$_.seed -ceq $seed -and
        [string]$_.target_id -ceq $destination -and
        [string]$_.to_archetype_id -ceq $destination
    })
    if ($matchingTargetTravels.Count -eq 0) {
        $issues.Add("expected destination travel was not completed: $destination")
    }
    return $issues
}

foreach ($requiredPath in @($manifestPath, $auditScript, $staticChecker, $scenarioCatalogPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Missing rw06_1 exact-seed dependency: $requiredPath"
    }
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -ErrorAction Stop
$expectations = @($manifest.expectations)
if ([int]$manifest.schema_version -ne 1 -or $expectations.Count -ne 22) {
    throw "Historical UIENV manifest must be schema 1 with 22 rows; got schema=$($manifest.schema_version) rows=$($expectations.Count)."
}
$uniqueSeeds = @($expectations | ForEach-Object { [string]$_.seed } | Sort-Object -Unique)
if ($uniqueSeeds.Count -ne 22 -or $uniqueSeeds -contains "") {
    throw "Historical UIENV manifest seed identities must be 22 unique non-empty strings."
}

# The fast validator proves every fixture's marker uniquely identifies its
# scenario and every required scenario interaction receives room/overflow
# authority before the expensive historical trajectories are replayed.
& python $staticChecker $projectRoot $staticReportPath
if ($LASTEXITCODE -ne 0) {
    throw "rw06_1 fixed-slot exact-seed preflight failed."
}
if ($ValidateManifestOnly) {
    Write-Host "RW06_1_ENVIRONMENT_EXACT_SEED MANIFEST_PASS seeds=22 static_report=$staticReportPath"
    exit 0
}

if ($RequireGodot -and [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
    throw "GODOT_BIN must name the leased console executable when -RequireGodot is used."
}
$runningGodot = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^Godot.*\.exe$' })
if ($runningGodot.Count -gt 0) {
    $details = ($runningGodot | ForEach-Object { "$($_.ProcessId):$($_.Name)" }) -join ', '
    throw "Serialized rw06_1 exact-seed runner requires an empty Godot slot; running=$details"
}

[void][System.IO.Directory]::CreateDirectory($evidenceDirectory)
$failures = [System.Collections.Generic.List[string]]::new()
$results = [System.Collections.Generic.List[object]]::new()
$suiteTimer = [System.Diagnostics.Stopwatch]::StartNew()
$index = 0
foreach ($expectation in $expectations) {
    $index += 1
    $seed = [string]$expectation.seed
    $safeSeed = $seed -replace '[^A-Za-z0-9._-]', '_'
    $jsonOutput = "res://.tmp/rw06_1/exact_seed/$safeSeed.json"
    $markdownOutput = "res://.tmp/rw06_1/exact_seed/$safeSeed.md"
    $jsonEvidencePath = Join-Path $evidenceDirectory "$safeSeed.json"
    $markdownEvidencePath = Join-Path $evidenceDirectory "$safeSeed.md"
    $logPath = Join-Path $evidenceDirectory "$safeSeed.log"
    Remove-Item -LiteralPath $jsonEvidencePath, $markdownEvidencePath, $logPath -Force -ErrorAction SilentlyContinue
    Write-Host "RW06_1_ENVIRONMENT_EXACT_SEED CHECK $index/22 seed=$seed target=$($expectation.destination)/$($expectation.scenario_id)"

    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $auditScript,
        '-Runs', '1',
        '-Visits', [string]$Visits,
        '-ExactSeed', $seed,
        '-Output', $jsonOutput,
        '-Report', $markdownOutput
    )
    if ($RequireGodot) {
        $arguments += '-RequireGodot'
    }
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = 'powershell.exe'
    $startInfo.Arguments = ($arguments | ForEach-Object { Quote-NativeArgument -Value ([string]$_) }) -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $null = $process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($ChildTimeoutSeconds * 1000)
    if ($timedOut) {
        Stop-DisposableProcessTree -ProcessId $process.Id
    }
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    [System.IO.File]::WriteAllText($logPath, $stdout + $stderr)
    $exitCode = if ($timedOut) { -1 } else { [int]$process.ExitCode }
    $issues = @(Test-ExactSeedEvidence -Expectation $expectation -EvidencePath $jsonEvidencePath -RequestedVisits $Visits)
    if ($timedOut) {
        $issues += "child exceeded $ChildTimeoutSeconds seconds"
    }
    if ($exitCode -ne 0) {
        $issues += "child exited $exitCode"
    }
    foreach ($issue in $issues) {
        $failures.Add("$seed`: $issue")
    }
    $outcome = if ($issues.Count -eq 0) { "PASS" } else { "FAIL" }
    $results.Add([pscustomobject]@{
        seed = $seed
        destination = [string]$expectation.destination
        scenario_id = [string]$expectation.scenario_id
        outcome = $outcome
        issue_count = $issues.Count
        evidence = $jsonEvidencePath
        log = $logPath
    })
    Write-Host "RW06_1_ENVIRONMENT_EXACT_SEED RESULT seed=$seed outcome=$outcome issues=$($issues.Count) evidence=$jsonEvidencePath"
}
$suiteTimer.Stop()

$summary = [ordered]@{
    tool = "rw06_1_environment_exact_seed_contract_test"
    passed = $failures.Count -eq 0
    seed_count = $expectations.Count
    visits = $Visits
    serialized = $true
    evidence_validated = $true
    elapsed_seconds = [Math]::Round($suiteTimer.Elapsed.TotalSeconds, 3)
    static_report = $staticReportPath
    results = @($results)
    failures = @($failures)
}
[System.IO.File]::WriteAllText($suiteReportPath, (($summary | ConvertTo-Json -Depth 8) + "`n"))
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        [Console]::Error.WriteLine("RW06_1_ENVIRONMENT_EXACT_SEED FAIL $failure")
    }
    [Console]::Error.WriteLine("RW06_1_ENVIRONMENT_EXACT_SEED FAIL seeds=22 failures=$($failures.Count) visits=$Visits report=$suiteReportPath")
    exit 1
}

Write-Host "RW06_1_ENVIRONMENT_EXACT_SEED PASS seeds=22 visits=$Visits serialized=true evidence_validated=true report=$suiteReportPath"
exit 0
