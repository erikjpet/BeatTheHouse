[CmdletBinding()]
param(
    [string]$ReportPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Worktree = Split-Path -Parent $PSScriptRoot
$AdmissionPath = Join-Path $PSScriptRoot 'rw06_2_evidence_admission.ps1'
$PreflightPath = Join-Path $PSScriptRoot 'rw06_2_heist_seed_preflight.ps1'
$RunnerPath = Join-Path $PSScriptRoot 'rw06_2_ending_replay.ps1'
$FixedLauncherPath = Join-Path $PSScriptRoot 'rw06_2_final_evidence.ps1'
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $Worktree '.tmp\rw06_2\evidence_admission_contract.json'
}

$failures = [Collections.Generic.List[string]]::new()
$resolverValidFixtures = 0
$resolverHostileFixtures = 0
$preflightValidFixtures = 0
$admissionObjectHostileFixtures = 0
$preflightHostileFixtures = 0
$sourceValidFixtures = 0
$sourceHostileFixtures = 0
$outerValidFixtures = 0
$outerHostileFixtures = 0


function Add-Failure {
    param([Parameter(Mandatory = $true)][string]$Message)
    $failures.Add($Message)
}


function ConvertTo-ContractClone {
    param([Parameter(Mandatory = $true)]$InputObject)
    return ($InputObject | ConvertTo-Json -Depth 30 -Compress | ConvertFrom-Json)
}


function Test-Throws {
    param([Parameter(Mandatory = $true)][scriptblock]$Action)
    try {
        & $Action
        return $false
    }
    catch {
        return $true
    }
}


function Invoke-PreflightReport {
    param([Parameter(Mandatory = $true)][string]$Seed)
    $safeSeed = $Seed -replace '[^A-Za-z0-9_-]', '_'
    $path = Join-Path $Worktree ".tmp\rw06_2\q017_contract\$safeSeed.json"
    $lines = @(& $PreflightPath -SeedText $Seed -ReportPath $path)
    if ($lines.Count -ne 1) {
        throw "Preflight for '$Seed' returned $($lines.Count) records instead of one."
    }
    return ([string]$lines[0] | ConvertFrom-Json)
}


function Get-ExactOuterAdmissionFunctionSource {
    param([Parameter(Mandatory = $true)][string]$Path)
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0) {
        throw "Could not parse fixed launcher for exact admission-function extraction: $($errors[0].Message)"
    }
    $allFunctions = @($ast.FindAll({
        param($node)
        return $node -is [Management.Automation.Language.FunctionDefinitionAst]
    }, $true))
    $definitions = [Collections.Generic.List[string]]::new()
    foreach ($name in @('Get-ExactValue', 'Test-ExactStringArray', 'Assert-FixedReplayAdmission')) {
        $matches = @($allFunctions | Where-Object { $_.Name -ceq $name })
        if ($matches.Count -ne 1) {
            throw "Fixed launcher must contain exactly one '$name' function; observed $($matches.Count)."
        }
        $definitions.Add([string]$matches[0].Extent.Text)
    }
    return ($definitions -join "`r`n`r`n")
}


function Test-Q017SourceShape {
    param(
        [Parameter(Mandatory = $true)][string]$AdmissionSource,
        [Parameter(Mandatory = $true)][string]$PreflightSource,
        [Parameter(Mandatory = $true)][string]$RunnerSource,
        [Parameter(Mandatory = $true)][string]$FixedLauncherSource
    )
    foreach ($token in @(
        "heist = 'RW06-HEIST-AUDIT-0002'",
        "heist = 'RW06-HEIST-AUDIT-0000'",
        "if (`$EvidenceRole -ceq 'fresh-interactive')",
        "if (`$Ending -cne 'heist')",
        "if (`$Repeat -ne 1)",
        'requires the explicit separately preflighted seed',
        "route_plan = 'count'",
        "scenario_injection_allowed = `$false",
        "plan_b_allowed = `$false",
        "release_qualifying = `$false",
        'Assert-Rw062NoScenarioAuthorityFields -InputObject $Report',
        'Test-Rw062IntegralValue',
        "@('Q-013A', 'Q-017A')"
    )) {
        if ($AdmissionSource.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    foreach ($token in @(
        "'RW06-HEIST-AUDIT-0000'",
        'run_seed -ne 1262406216',
        'stream_seed -ne 501255064',
        'none_roll -ne 96',
        'total_weight -ne 26000',
        'weighted_roll -ne 22402',
        "selected_scenario -cne 'grand_casino_audit_night'",
        "owner_decisions = @('Q-013A', 'Q-017A')"
    )) {
        if ($PreflightSource.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    $roleNormalization = '$EvidenceRole = $EvidenceRole.ToLowerInvariant()'
    $resolveCall = '$script:ReplayAdmission = Resolve-Rw062ReplayAdmission'
    $roleIndex = $RunnerSource.IndexOf($roleNormalization, [StringComparison]::Ordinal)
    $resolveIndex = $RunnerSource.IndexOf($resolveCall, [StringComparison]::Ordinal)
    if ($roleIndex -lt 0 -or $resolveIndex -le $roleIndex -or
        [regex]::Matches($RunnerSource, [regex]::Escape($roleNormalization)).Count -ne 1 -or
        [regex]::Matches($RunnerSource, '(?m)^\s*requested_evidence_role\s*=\s*\$EvidenceRole\s*$').Count -ne 2 -or
        [regex]::Matches($RunnerSource, '(?m)^\s*replay_admission\s*=\s*\$script:ReplayAdmission\s*$').Count -ne 2 -or
        [regex]::Matches($RunnerSource, '(?m)^\s*heist_preflight_admission\s*=\s*\$script:HeistPreflightAdmissionReceipt\s*$').Count -ne 2 -or
        $RunnerSource.IndexOf('Assert-Rw062HeistPreflightAdmission', [StringComparison]::Ordinal) -lt 0) {
        return $false
    }
    $route = [regex]::Match($RunnerSource, '(?ms)^function\s+Invoke-SelectedEndingRoute\s*\{.*?(?=^function |\z)').Value
    if ([string]::IsNullOrWhiteSpace($route) -or
        $route.IndexOf('switch ($Ending)', [StringComparison]::Ordinal) -lt 0 -or
        $route.IndexOf("'heist' { Invoke-HeistEndingRoute }", [StringComparison]::Ordinal) -lt 0 -or
        $route -match 'EvidenceRole|fresh-interactive|plan.?b|whale') {
        return $false
    }
    $heistRoute = [regex]::Match($RunnerSource, '(?ms)^function\s+Invoke-HeistEndingRoute\s*\{.*?(?=^function |\z)').Value
    if ([string]::IsNullOrWhiteSpace($heistRoute) -or
        $heistRoute -match '(?i)EvidenceRole|fresh-interactive|plan.?b|whale|\$Seed|\$script:ReplayAdmission') {
        return $false
    }
    $heistRouteTokens = $null
    $heistRouteErrors = $null
    $heistRouteAst = [Management.Automation.Language.Parser]::ParseInput(
        $heistRoute,
        [ref]$heistRouteTokens,
        [ref]$heistRouteErrors
    )
    if ($heistRouteErrors.Count -ne 0) { return $false }
    $allowedHeistRouteVariables = @('choiceId', 'decisions', 'null', 'round')
    $heistRouteVariables = @($heistRouteAst.FindAll({
        param($node)
        return $node -is [Management.Automation.Language.VariableExpressionAst]
    }, $true) | ForEach-Object { [string]$_.VariablePath.UserPath } | Sort-Object -Unique)
    foreach ($variableName in $heistRouteVariables) {
        if ($variableName -cnotin $allowedHeistRouteVariables) { return $false }
    }
    foreach ($token in @(
        "'-EvidenceRole', 'fixed-repeat'",
        "requested_evidence_role') '') -cne 'fixed-repeat'",
        'Assert-FixedReplayAdmission -Admission $summaryAdmission',
        'Assert-FixedReplayAdmission -Admission $runAdmission',
        'Assert-Rw062HeistPreflightAdmission',
        "evidence_role = 'fixed-repeat'",
        "[string]`$proof.evidence_role -cne 'fixed-repeat'",
        "fresh_interactive_authorized = `$false",
        "'ANSWERED_SEPARATE_FRESH_INTERACTIVE_SCOPE'"
    )) {
        if ($FixedLauncherSource.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    $paramBlock = [regex]::Match($FixedLauncherSource, '(?ms)^\[CmdletBinding\(\)\]\s*param\((?<body>.*?)\)\s*Set-StrictMode').Groups['body'].Value
    if ([string]::IsNullOrWhiteSpace($paramBlock) -or
        $paramBlock -match '(?i)EvidenceRole|FreshSeed|Interactive|\bFresh\b') {
        return $false
    }
    return $true
}


foreach ($path in @($AdmissionPath, $PreflightPath, $RunnerPath, $FixedLauncherPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure "Required Q-017 admission source is missing: $path"
    }
}

$fixedReport = $null
$freshReport = $null
if ($failures.Count -eq 0) {
    foreach ($path in @($AdmissionPath, $PreflightPath, $RunnerPath, $FixedLauncherPath)) {
        $tokens = $null
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
        if ($errors.Count -ne 0) {
            Add-Failure "PowerShell parse failed for $path`: $($errors[0].Message)"
        }
    }
}

if ($failures.Count -eq 0) {
    . $AdmissionPath
    try {
        $fixedReport = Invoke-PreflightReport -Seed 'RW06-HEIST-AUDIT-0002'
        $freshReport = Invoke-PreflightReport -Seed 'RW06-HEIST-AUDIT-0000'
    }
    catch {
        Add-Failure "Could not obtain exact engine-free Q-017 preflight reports: $($_.Exception.Message)"
    }
}

if ($failures.Count -eq 0) {
    $resolverValids = @(
        [pscustomobject]@{ name = 'fixed default'; role = 'fixed-repeat'; seed = ''; repeat = 2; expected_seed = 'RW06-HEIST-AUDIT-0002'; report = $fixedReport },
        [pscustomobject]@{ name = 'fixed explicit'; role = 'fixed-repeat'; seed = 'RW06-HEIST-AUDIT-0002'; repeat = 1; expected_seed = 'RW06-HEIST-AUDIT-0002'; report = $fixedReport },
        [pscustomobject]@{ name = 'fresh explicit'; role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 1; expected_seed = 'RW06-HEIST-AUDIT-0000'; report = $freshReport }
    )
    foreach ($fixture in $resolverValids) {
        try {
            $admission = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole $fixture.role -Seed $fixture.seed -Repeat $fixture.repeat
            if ([string]$admission.evidence_role -cne [string]$fixture.role -or
                [string]$admission.seed -cne [string]$fixture.expected_seed -or
                [int]$admission.repeat -ne [int]$fixture.repeat -or
                [string]$admission.route_plan -cne 'count' -or
                [bool]$admission.scenario_injection_allowed -or [bool]$admission.plan_b_allowed -or
                [bool]$admission.release_qualifying) {
                throw 'Resolved admission fields drifted.'
            }
            $null = Assert-Rw062HeistPreflightAdmission -Admission $admission -Report $fixture.report
            $resolverValidFixtures++
        }
        catch {
            Add-Failure "Valid resolver fixture '$($fixture.name)' failed: $($_.Exception.Message)"
        }
    }

    $resolverHostiles = @(
        [pscustomobject]@{ name = 'unknown role'; ending = 'heist'; role = 'fresh'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 1 },
        [pscustomobject]@{ name = 'case-drifted role'; ending = 'heist'; role = 'Fresh-Interactive'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 1 },
        [pscustomobject]@{ name = 'blank fresh seed'; ending = 'heist'; role = 'fresh-interactive'; seed = ''; repeat = 1 },
        [pscustomobject]@{ name = 'fixed seed in fresh role'; ending = 'heist'; role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0002'; repeat = 1 },
        [pscustomobject]@{ name = 'unapproved natural Audit seed'; ending = 'heist'; role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0007'; repeat = 1 },
        [pscustomobject]@{ name = 'historical non-Audit seed'; ending = 'heist'; role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0013'; repeat = 1 },
        [pscustomobject]@{ name = 'fresh repeat two'; ending = 'heist'; role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 2 },
        [pscustomobject]@{ name = 'fresh clean'; ending = 'clean'; role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 1 },
        [pscustomobject]@{ name = 'fresh cheat'; ending = 'cheat'; role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 1 },
        [pscustomobject]@{ name = 'fresh seed in fixed role'; ending = 'heist'; role = 'fixed-repeat'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 1 }
    )
    foreach ($fixture in $resolverHostiles) {
        $resolverHostileFixtures++
        $copy = $fixture
        if (-not (Test-Throws {
            $null = Resolve-Rw062ReplayAdmission -Ending $copy.ending -EvidenceRole $copy.role -Seed $copy.seed -Repeat $copy.repeat
        })) {
            Add-Failure "Hostile resolver fixture '$($fixture.name)' did not fail closed."
        }
    }

    foreach ($fixture in @(
        [pscustomobject]@{ role = 'fixed-repeat'; seed = 'RW06-HEIST-AUDIT-0002'; repeat = 2; report = $fixedReport },
        [pscustomobject]@{ role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 1; report = $freshReport }
    )) {
        try {
            $admission = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole $fixture.role -Seed $fixture.seed -Repeat $fixture.repeat
            $receipt = Assert-Rw062HeistPreflightAdmission -Admission $admission -Report $fixture.report
            if ([string]$receipt.evidence_role -cne [string]$fixture.role -or
                [string]$receipt.seed -cne [string]$fixture.seed -or
                [string]$receipt.route_plan -cne 'count' -or
                -not [bool]$receipt.natural_first_arrival -or
                [bool]$receipt.scenario_injection_used -or [bool]$receipt.plan_b_used) {
                throw 'Admission receipt drifted.'
            }
            $preflightValidFixtures++
        }
        catch {
            Add-Failure "Valid preflight admission '$($fixture.role)' failed: $($_.Exception.Message)"
        }
    }

    $freshAdmission = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fresh-interactive -Seed 'RW06-HEIST-AUDIT-0000' -Repeat 1
    $admissionMutations = @(
        [pscustomobject]@{ name = 'role'; mutate = { param($a) $a.evidence_role = 'fixed-repeat' } },
        [pscustomobject]@{ name = 'ending'; mutate = { param($a) $a.ending = 'clean' } },
        [pscustomobject]@{ name = 'seed'; mutate = { param($a) $a.seed = 'RW06-HEIST-AUDIT-0002' } },
        [pscustomobject]@{ name = 'repeat'; mutate = { param($a) $a.repeat = 2 } },
        [pscustomobject]@{ name = 'route plan'; mutate = { param($a) $a.route_plan = 'whale' } },
        [pscustomobject]@{ name = 'expected scenario'; mutate = { param($a) $a.expected_initial_scenario = 'Grand_Casino_Audit_Night' } },
        [pscustomobject]@{ name = 'scenario authority'; mutate = { param($a) $a.scenario_authority = 'caller_override' } },
        [pscustomobject]@{ name = 'scenario permission'; mutate = { param($a) $a.scenario_injection_allowed = $true } },
        [pscustomobject]@{ name = 'Plan B permission'; mutate = { param($a) $a.plan_b_allowed = $true } },
        [pscustomobject]@{ name = 'profile isolation'; mutate = { param($a) $a.requires_isolated_profile = $false } },
        [pscustomobject]@{ name = 'direct qualification'; mutate = { param($a) $a.release_qualifying = $true } },
        [pscustomobject]@{ name = 'qualification authority'; mutate = { param($a) $a.qualification_authority = 'direct' } },
        [pscustomobject]@{ name = 'owner decision'; mutate = { param($a) $a.owner_decisions = @('Q-013A') } },
        [pscustomobject]@{ name = 'owner decision order'; mutate = { param($a) $a.owner_decisions = @('Q-017A', 'Q-013A') } },
        [pscustomobject]@{ name = 'extra scenario pin'; mutate = { param($a) $a | Add-Member -NotePropertyName scenario_pin -NotePropertyValue 'grand_casino_audit_night' } },
        [pscustomobject]@{ name = 'extra scenario injection used'; mutate = { param($a) $a | Add-Member -NotePropertyName scenario_injection_used -NotePropertyValue $false } },
        [pscustomobject]@{ name = 'extra Plan B used'; mutate = { param($a) $a | Add-Member -NotePropertyName plan_b_used -NotePropertyValue $false } },
        [pscustomobject]@{ name = 'extra forced scenario'; mutate = { param($a) $a | Add-Member -NotePropertyName forced_scenario -NotePropertyValue '' } },
        [pscustomobject]@{ name = 'extra Whale plan'; mutate = { param($a) $a | Add-Member -NotePropertyName whale_plan -NotePropertyValue $false } }
    )
    foreach ($fixture in $admissionMutations) {
        $admissionObjectHostileFixtures++
        $hostileAdmission = ConvertTo-ContractClone $freshAdmission
        & $fixture.mutate $hostileAdmission
        if (-not (Test-Throws {
            $null = Assert-Rw062HeistPreflightAdmission -Admission $hostileAdmission -Report $freshReport
        })) {
            Add-Failure "Hostile admission-object fixture '$($fixture.name)' did not fail closed."
        }
    }

    $reportMutations = @(
        [pscustomobject]@{ name = 'passed string'; mutate = { param($r) $r.passed = 'true' } },
        [pscustomobject]@{ name = 'passed false'; mutate = { param($r) $r.passed = $false } },
        [pscustomobject]@{ name = 'contract'; mutate = { param($r) $r.contract = 'hostile' } },
        [pscustomobject]@{ name = 'expected scenario'; mutate = { param($r) $r.expected_scenario = 'Grand_Casino_Audit_Night' } },
        [pscustomobject]@{ name = 'owner decisions'; mutate = { param($r) $r.owner_decisions = @('WRONG') } },
        [pscustomobject]@{ name = 'valid fixture count'; mutate = { param($r) $r.valid_fixtures = 2 } },
        [pscustomobject]@{ name = 'hostile fixture count'; mutate = { param($r) $r.hostile_fixtures = 1 } },
        [pscustomobject]@{ name = 'fresh companion selection'; mutate = { param($r) $r.fresh_interactive_selection = [pscustomobject]@{ seed_text = 'RW06-HEIST-AUDIT-0007'; selected_scenario = 'grand_casino_audit_night' } } },
        [pscustomobject]@{ name = 'serialization calibration payload'; mutate = { param($r) $r.serialization_calibration = [pscustomobject]@{ seed_text = 'RW06-HEIST-AUDIT-0000' } } },
        [pscustomobject]@{ name = 'arrival history hostile payload'; mutate = { param($r) $r.arrival_history_hostile = [pscustomobject]@{ whale_plan = $true } } },
        [pscustomobject]@{ name = 'seed'; mutate = { param($r) $r.selection.seed_text = 'rw06-heist-audit-0000' } },
        [pscustomobject]@{ name = 'challenge key'; mutate = { param($r) $r.selection.challenge_key += '-drift' } },
        [pscustomobject]@{ name = 'scenario blank'; mutate = { param($r) $r.selection.selected_scenario = '' } },
        [pscustomobject]@{ name = 'scenario convention'; mutate = { param($r) $r.selection.selected_scenario = 'grand_casino_convention_crowd' } },
        [pscustomobject]@{ name = 'scenario case'; mutate = { param($r) $r.selection.selected_scenario = 'Grand_Casino_Audit_Night' } },
        [pscustomobject]@{ name = 'cycle'; mutate = { param($r) $r.selection.cycle_id = 'day:1' } },
        [pscustomobject]@{ name = 'stream key'; mutate = { param($r) $r.selection.stream_key = 'environment_situation:grand_casino:day:1' } },
        [pscustomobject]@{ name = 'run seed value'; mutate = { param($r) $r.selection.run_seed++ } },
        [pscustomobject]@{ name = 'run seed floating type'; mutate = { param($r) $r.selection.run_seed = [double]1262406216 } },
        [pscustomobject]@{ name = 'stream seed value'; mutate = { param($r) $r.selection.stream_seed++ } },
        [pscustomobject]@{ name = 'stream seed decimal type'; mutate = { param($r) $r.selection.stream_seed = [decimal]501255064 } },
        [pscustomobject]@{ name = 'none roll value'; mutate = { param($r) $r.selection.none_roll-- } },
        [pscustomobject]@{ name = 'none roll floating type'; mutate = { param($r) $r.selection.none_roll = [double]96 } },
        [pscustomobject]@{ name = 'none percent'; mutate = { param($r) $r.selection.none_percent = 24 } },
        [pscustomobject]@{ name = 'absolute minutes'; mutate = { param($r) $r.selection.absolute_minutes = 721 } },
        [pscustomobject]@{ name = 'total weight value'; mutate = { param($r) $r.selection.total_weight-- } },
        [pscustomobject]@{ name = 'total weight floating type'; mutate = { param($r) $r.selection.total_weight = [double]26000 } },
        [pscustomobject]@{ name = 'weighted roll value'; mutate = { param($r) $r.selection.weighted_roll-- } },
        [pscustomobject]@{ name = 'weighted roll decimal type'; mutate = { param($r) $r.selection.weighted_roll = [decimal]22402 } },
        [pscustomobject]@{ name = 'arrival history'; mutate = { param($r) $r.selection.recent_scenario_ids = @('grand_casino_audit_night') } },
        [pscustomobject]@{ name = 'town multiplier type'; mutate = { param($r) $r.selection.town_multiplier = [double]1.0 } },
        [pscustomobject]@{ name = 'weighted entry count'; mutate = { param($r) $r.selection.weighted_entries = @($r.selection.weighted_entries | Select-Object -First 2) } },
        [pscustomobject]@{ name = 'weighted entry order'; mutate = { param($r) $r.selection.weighted_entries = @($r.selection.weighted_entries[1], $r.selection.weighted_entries[0], $r.selection.weighted_entries[2]) } },
        [pscustomobject]@{ name = 'weighted entry id'; mutate = { param($r) $r.selection.weighted_entries[0].id = 'grand_casino_audit_night' } },
        [pscustomobject]@{ name = 'weighted entry type'; mutate = { param($r) $r.selection.weighted_entries[0].scaled_weight = [double]8000 } },
        [pscustomobject]@{ name = 'screen'; mutate = { param($r) $r.launch_model.screen = 'RUN_CONFIG' } },
        [pscustomobject]@{ name = 'run config type'; mutate = { param($r) $r.launch_model.run_config = 'true' } },
        [pscustomobject]@{ name = 'selected challenge'; mutate = { param($r) $r.launch_model.selected_challenge = 'standard' } },
        [pscustomobject]@{ name = 'selected home'; mutate = { param($r) $r.launch_model.selected_home = 'back_alley' } },
        [pscustomobject]@{ name = 'challenge mode'; mutate = { param($r) $r.launch_model.challenge_mode = 'hostile' } },
        [pscustomobject]@{ name = 'challenge id'; mutate = { param($r) $r.launch_model.challenge_id = 'hostile' } },
        [pscustomobject]@{ name = 'modifier text'; mutate = { param($r) $r.launch_model.fresh_profile_modifier_text += ';scenario=hostile' } },
        [pscustomobject]@{ name = 'start minutes'; mutate = { param($r) $r.launch_model.start_absolute_minutes = 721 } },
        [pscustomobject]@{ name = 'content count'; mutate = { param($r) $r.launch_model.selected_content_groups = @($r.launch_model.selected_content_groups | Select-Object -First 13) } },
        [pscustomobject]@{ name = 'content order'; mutate = { param($r) $r.launch_model.selected_content_groups = @($r.launch_model.selected_content_groups[1], $r.launch_model.selected_content_groups[0]) + @($r.launch_model.selected_content_groups | Select-Object -Skip 2) } },
        [pscustomobject]@{ name = 'content type'; mutate = { param($r) $r.launch_model.selected_content_groups[0] = 7 } },
        [pscustomobject]@{ name = 'launch arrival history'; mutate = { param($r) $r.launch_model.first_arrival_recent_scenario_ids = @('grand_casino_audit_night') } },
        [pscustomobject]@{ name = 'scenario pin'; mutate = { param($r) $r.selection | Add-Member -NotePropertyName scenario_pin -NotePropertyValue 'grand_casino_audit_night' } },
        [pscustomobject]@{ name = 'scenario override'; mutate = { param($r) $r.launch_model | Add-Member -NotePropertyName Scenario_Override -NotePropertyValue 'grand_casino_audit_night' } },
        [pscustomobject]@{ name = 'injected scenario'; mutate = { param($r) $r | Add-Member -NotePropertyName injected_scenario -NotePropertyValue 'grand_casino_audit_night' } },
        [pscustomobject]@{ name = 'tutorial override'; mutate = { param($r) $r | Add-Member -NotePropertyName tutorial_overrides -NotePropertyValue @{} } },
        [pscustomobject]@{ name = 'debug scenario'; mutate = { param($r) $r | Add-Member -NotePropertyName debug_scenario -NotePropertyValue 'grand_casino_audit_night' } },
        [pscustomobject]@{ name = 'Plan B'; mutate = { param($r) $r | Add-Member -NotePropertyName plan_b -NotePropertyValue $true } },
        [pscustomobject]@{ name = 'Whale plan'; mutate = { param($r) $r | Add-Member -NotePropertyName whale_plan -NotePropertyValue $true } },
        [pscustomobject]@{ name = 'scenario injection used'; mutate = { param($r) $r | Add-Member -NotePropertyName scenario_injection_used -NotePropertyValue $false } },
        [pscustomobject]@{ name = 'scenario injection allowed'; mutate = { param($r) $r | Add-Member -NotePropertyName scenario_injection_allowed -NotePropertyValue $false } },
        [pscustomobject]@{ name = 'Plan B used'; mutate = { param($r) $r | Add-Member -NotePropertyName plan_b_used -NotePropertyValue $false } },
        [pscustomobject]@{ name = 'Plan B allowed'; mutate = { param($r) $r | Add-Member -NotePropertyName plan_b_allowed -NotePropertyValue $false } },
        [pscustomobject]@{ name = 'forced scenario'; mutate = { param($r) $r | Add-Member -NotePropertyName forced_scenario -NotePropertyValue '' } },
        [pscustomobject]@{ name = 'missing selection arrival history'; mutate = { param($r) $r.selection.PSObject.Properties.Remove('recent_scenario_ids') } },
        [pscustomobject]@{ name = 'null selection arrival history'; mutate = { param($r) $r.selection.recent_scenario_ids = $null } },
        [pscustomobject]@{ name = 'missing launch arrival history'; mutate = { param($r) $r.launch_model.PSObject.Properties.Remove('first_arrival_recent_scenario_ids') } },
        [pscustomobject]@{ name = 'null launch arrival history'; mutate = { param($r) $r.launch_model.first_arrival_recent_scenario_ids = $null } },
        [pscustomobject]@{ name = 'missing failures'; mutate = { param($r) $r.PSObject.Properties.Remove('failures') } },
        [pscustomobject]@{ name = 'null failures'; mutate = { param($r) $r.failures = $null } }
    )
    foreach ($fixture in $reportMutations) {
        $preflightHostileFixtures++
        $hostileReport = ConvertTo-ContractClone $freshReport
        & $fixture.mutate $hostileReport
        if (-not (Test-Throws {
            $null = Assert-Rw062HeistPreflightAdmission -Admission $freshAdmission -Report $hostileReport
        })) {
            Add-Failure "Hostile preflight fixture '$($fixture.name)' did not fail closed."
        }
    }

    $admissionSource = Get-Content -Raw -LiteralPath $AdmissionPath
    $preflightSource = Get-Content -Raw -LiteralPath $PreflightPath
    $runnerSource = Get-Content -Raw -LiteralPath $RunnerPath
    $fixedLauncherSource = Get-Content -Raw -LiteralPath $FixedLauncherPath
    if (Test-Q017SourceShape -AdmissionSource $admissionSource -PreflightSource $preflightSource -RunnerSource $runnerSource -FixedLauncherSource $fixedLauncherSource) {
        $sourceValidFixtures = 1
    }
    else {
        Add-Failure 'Valid Q-017 source shape did not bind fresh admission, the shared Count route, and fixed-lane isolation.'
    }
    $sourceMutations = @(
        [pscustomobject]@{ name = 'fresh seed'; target = 'admission'; from = "heist = 'RW06-HEIST-AUDIT-0000'"; to = "heist = 'RW06-HEIST-AUDIT-0007'" },
        [pscustomobject]@{ name = 'fixed seed'; target = 'admission'; from = "heist = 'RW06-HEIST-AUDIT-0002'"; to = "heist = 'RW06-HEIST-AUDIT-0000'" },
        [pscustomobject]@{ name = 'fresh repeat guard'; target = 'admission'; from = 'if ($Repeat -ne 1)'; to = 'if ($Repeat -ne 2)' },
        [pscustomobject]@{ name = 'scenario permission'; target = 'admission'; from = 'scenario_injection_allowed = $false'; to = 'scenario_injection_allowed = $true' },
        [pscustomobject]@{ name = 'Plan B permission'; target = 'admission'; from = 'plan_b_allowed = $false'; to = 'plan_b_allowed = $true' },
        [pscustomobject]@{ name = '0000 witness'; target = 'preflight'; from = 'run_seed -ne 1262406216'; to = 'run_seed -ne 1262406217' },
        [pscustomobject]@{ name = 'role normalization'; target = 'runner'; from = '$EvidenceRole = $EvidenceRole.ToLowerInvariant()'; to = '$EvidenceRole = $EvidenceRole' },
        [pscustomobject]@{ name = 'summary role'; target = 'runner'; from = 'requested_evidence_role = $EvidenceRole'; to = 'requested_evidence_role = ''fixed-repeat''' },
        [pscustomobject]@{ name = 'shared Count route'; target = 'runner'; from = "'heist' { Invoke-HeistEndingRoute }"; to = "'heist' { Invoke-HeistPlanBRoute }" },
        [pscustomobject]@{ name = 'Heist route role branch'; target = 'runner'; from = 'function Invoke-HeistEndingRoute {'; to = "function Invoke-HeistEndingRoute {`r`n    if (`$EvidenceRole -ceq 'fresh-interactive') { Invoke-HeistPlanBRoute; return }" },
        [pscustomobject]@{ name = 'Heist route seed branch'; target = 'runner'; from = 'function Invoke-HeistEndingRoute {'; to = "function Invoke-HeistEndingRoute {`r`n    if (`$Seed -ceq 'RW06-HEIST-AUDIT-0000') { Invoke-HeistAlternateRoute; return }" },
        [pscustomobject]@{ name = 'Heist route admission-authority branch'; target = 'runner'; from = 'function Invoke-HeistEndingRoute {'; to = "function Invoke-HeistEndingRoute {`r`n    if (`$script:ReplayAdmission.qualification_authority -ceq 'post_run_interactive_review_only') { Invoke-HeistAlternateRoute; return }" },
        [pscustomobject]@{ name = 'Heist route receipt branch'; target = 'runner'; from = 'function Invoke-HeistEndingRoute {'; to = "function Invoke-HeistEndingRoute {`r`n    if (`$script:HeistPreflightAdmissionReceipt.evidence_role -ceq 'fresh-interactive') { Invoke-HeistAlternateRoute; return }" },
        [pscustomobject]@{ name = 'Heist route preflight-report branch'; target = 'runner'; from = 'function Invoke-HeistEndingRoute {'; to = "function Invoke-HeistEndingRoute {`r`n    if (`$heistSeedPreflight.selection.seed_text -ceq 'RW06-HEIST-AUDIT-0000') { Invoke-HeistAlternateRoute; return }" },
        [pscustomobject]@{ name = 'fixed outer role argument'; target = 'outer'; from = "'-EvidenceRole', 'fixed-repeat'"; to = "'-EvidenceRole', 'fresh-interactive'" },
        [pscustomobject]@{ name = 'fixed outer summary check'; target = 'outer'; from = "requested_evidence_role') '') -cne 'fixed-repeat'"; to = "requested_evidence_role') '') -cne 'fresh-interactive'" },
        [pscustomobject]@{ name = 'fixed proof role'; target = 'outer'; from = "[string]`$proof.evidence_role -cne 'fixed-repeat'"; to = "[string]`$proof.evidence_role -cne 'fresh-interactive'" }
    )
    foreach ($fixture in $sourceMutations) {
        $sourceHostileFixtures++
        $mutatedAdmission = $admissionSource
        $mutatedPreflight = $preflightSource
        $mutatedRunner = $runnerSource
        $mutatedOuter = $fixedLauncherSource
        switch ([string]$fixture.target) {
            'admission' { $mutatedAdmission = $mutatedAdmission.Replace([string]$fixture.from, [string]$fixture.to) }
            'preflight' { $mutatedPreflight = $mutatedPreflight.Replace([string]$fixture.from, [string]$fixture.to) }
            'runner' { $mutatedRunner = $mutatedRunner.Replace([string]$fixture.from, [string]$fixture.to) }
            'outer' { $mutatedOuter = $mutatedOuter.Replace([string]$fixture.from, [string]$fixture.to) }
        }
        if (($mutatedAdmission -ceq $admissionSource) -and ($mutatedPreflight -ceq $preflightSource) -and
            ($mutatedRunner -ceq $runnerSource) -and ($mutatedOuter -ceq $fixedLauncherSource)) {
            Add-Failure "Source hostile '$($fixture.name)' could not find its exact mutation token."
        }
        elseif (Test-Q017SourceShape -AdmissionSource $mutatedAdmission -PreflightSource $mutatedPreflight -RunnerSource $mutatedRunner -FixedLauncherSource $mutatedOuter) {
            Add-Failure "Source hostile '$($fixture.name)' did not fail closed."
        }
    }

    try {
        $outerAdmissionFunctionSource = Get-ExactOuterAdmissionFunctionSource -Path $FixedLauncherPath
        . ([scriptblock]::Create($outerAdmissionFunctionSource))

        foreach ($fixture in @(
            [pscustomobject]@{ name = 'clean'; ending = 'clean'; seed = 'RW06-CLEAN-ROUTE-01' },
            [pscustomobject]@{ name = 'cheat'; ending = 'cheat'; seed = 'RW06-CHEAT-ROUTE-01' },
            [pscustomobject]@{ name = 'heist'; ending = 'heist'; seed = 'RW06-HEIST-AUDIT-0002' }
        )) {
            $Ending = [string]$fixture.ending
            $Seed = [string]$fixture.seed
            $actualAdmission = Resolve-Rw062ReplayAdmission -Ending $Ending -EvidenceRole fixed-repeat -Seed $Seed -Repeat 1
            Assert-FixedReplayAdmission -Admission $actualAdmission -Label "valid $($fixture.name) outer admission"
            $outerValidFixtures++
        }

        $outerHostiles = @(
            [pscustomobject]@{
                name = 'fresh role'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0000'
                admission = { Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fresh-interactive -Seed 'RW06-HEIST-AUDIT-0000' -Repeat 1 }
            },
            [pscustomobject]@{
                name = 'clean missing owner decisions'
                ending = 'clean'
                seed = 'RW06-CLEAN-ROUTE-01'
                admission = {
                    $value = ConvertTo-ContractClone (Resolve-Rw062ReplayAdmission -Ending clean -EvidenceRole fixed-repeat -Seed 'RW06-CLEAN-ROUTE-01' -Repeat 1)
                    $value.PSObject.Properties.Remove('owner_decisions')
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'clean nonempty owner decisions'
                ending = 'clean'
                seed = 'RW06-CLEAN-ROUTE-01'
                admission = {
                    $value = ConvertTo-ContractClone (Resolve-Rw062ReplayAdmission -Ending clean -EvidenceRole fixed-repeat -Seed 'RW06-CLEAN-ROUTE-01' -Repeat 1)
                    $value.owner_decisions = @('Q-017A')
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'heist wrong owner decisions'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = ConvertTo-ContractClone (Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1)
                    $value.owner_decisions = @('Q-017A', 'Q-013A')
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'scenario injection allowed'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = ConvertTo-ContractClone (Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1)
                    $value.scenario_injection_allowed = $true
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'extra scenario pin authority'
                ending = 'clean'
                seed = 'RW06-CLEAN-ROUTE-01'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending clean -EvidenceRole fixed-repeat -Seed 'RW06-CLEAN-ROUTE-01' -Repeat 1
                    $value | Add-Member -NotePropertyName scenario_pin -NotePropertyValue 'grand_casino_audit_night'
                    return $value
                }
            }
        )
        foreach ($fixture in $outerHostiles) {
            $outerHostileFixtures++
            $Ending = [string]$fixture.ending
            $Seed = [string]$fixture.seed
            $hostileAdmission = & $fixture.admission
            if (-not (Test-Throws {
                Assert-FixedReplayAdmission -Admission $hostileAdmission -Label "hostile $($fixture.name) outer admission"
            })) {
                Add-Failure "Hostile outer admission fixture '$($fixture.name)' did not fail closed."
            }
        }
    }
    catch {
        Add-Failure "Exact outer admission runtime contract could not execute: $($_.Exception.Message)"
    }
}

$reportDirectory = Split-Path -Parent $ReportPath
if (-not [string]::IsNullOrWhiteSpace($reportDirectory)) {
    [void](New-Item -ItemType Directory -Path $reportDirectory -Force)
}
$sourceHashes = [ordered]@{}
foreach ($entry in ([ordered]@{
    admission = $AdmissionPath
    preflight = $PreflightPath
    runner = $RunnerPath
    fixed_launcher = $FixedLauncherPath
}).GetEnumerator()) {
    $sourceHashes[$entry.Key] = if (Test-Path -LiteralPath $entry.Value -PathType Leaf) {
        (Get-FileHash -LiteralPath $entry.Value -Algorithm SHA256).Hash.ToUpperInvariant()
    }
    else { '' }
}
$report = [ordered]@{
    contract = 'rw06_2_evidence_admission'
    passed = ($failures.Count -eq 0)
    owner_decisions = @('Q-013A', 'Q-017A')
    fixed_heist_seed = 'RW06-HEIST-AUDIT-0002'
    fresh_interactive_seed = 'RW06-HEIST-AUDIT-0000'
    fresh_interactive_route_plan = 'count'
    resolver_valid_fixtures = $resolverValidFixtures
    resolver_hostile_fixtures = $resolverHostileFixtures
    preflight_valid_fixtures = $preflightValidFixtures
    admission_object_hostile_fixtures = $admissionObjectHostileFixtures
    preflight_hostile_fixtures = $preflightHostileFixtures
    source_valid_fixtures = $sourceValidFixtures
    source_hostile_fixtures = $sourceHostileFixtures
    outer_valid_fixtures = $outerValidFixtures
    outer_hostile_fixtures = $outerHostileFixtures
    source_sha256 = $sourceHashes
    failures = @($failures)
}
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ReportPath -Encoding utf8

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure -ErrorAction Continue
    }
    throw "RW06_2_EVIDENCE_ADMISSION_CONTRACT FAIL ($($failures.Count) failure(s)); report: $ReportPath"
}

Write-Output "RW06_2_EVIDENCE_ADMISSION_CONTRACT PASS; report: $ReportPath"
