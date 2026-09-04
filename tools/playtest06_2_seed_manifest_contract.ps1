param(
    [string]$ManifestPath = "tools/playtest06_2_candidate_seeds.json",
    [switch]$RequireFinal,
    [string]$ExpectedTestedCommit = ""
)

$ErrorActionPreference = "Stop"

function Add-Failure {
    param([string]$Message)
    $script:Failures.Add($Message)
}

function As-Array {
    param($Value)
    if ($null -eq $Value) { return @() }
    return @($Value)
}

function Require-Text {
    param($Value, [string]$Path)
    if ([string]::IsNullOrWhiteSpace([string]$Value)) {
        Add-Failure "$Path must be non-empty."
    }
}

$Failures = [System.Collections.Generic.List[string]]::new()
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedManifest = if ([System.IO.Path]::IsPathRooted($ManifestPath)) {
    $ManifestPath
} else {
    Join-Path $root $ManifestPath
}

if (-not (Test-Path -LiteralPath $resolvedManifest -PathType Leaf)) {
    throw "Seed manifest not found: $resolvedManifest"
}

try {
    $manifest = Get-Content -LiteralPath $resolvedManifest -Raw | ConvertFrom-Json
} catch {
    throw "Seed manifest is not valid JSON: $($_.Exception.Message)"
}

$validStages = @("PRESTAGE", "FINAL")
$validStatuses = @("CANDIDATE", "VERIFIED", "BLOCKED")
$validAuthorities = @("PRODUCTION_PUBLIC_ACTIONS", "HEADLESS_PRODUCTION_ACTIONS", "DIAGNOSTIC_PREVALIDATED_TRAVEL")
$validShortcuts = @("PREVALIDATED_TRAVEL", "DEBUG_ACTION", "DIRECT_STATE_EDIT", "SAVE_EDIT", "TELEPORT", "BANKROLL_OVERRIDE", "INVITATION_INJECTION", "SYNTHETIC_COLLECTION_PROGRESS")
$requiredSlots = @(
    "ARCHETYPES",
    "SCENARIO-REPRESENTATIVE",
    "SCENARIO-BRANCHES",
    "GAMES",
    "PUSHER-MACHINES",
    "CREW-RECRUIT",
    "HEIST-PLAN-A",
    "HEIST-PLAN-B",
    "TURN-FIRES",
    "TURN-NO-FIRE",
    "CASS-END-1",
    "CASS-END-2",
    "CASS-END-3",
    "VICTORY-ROUTE-1",
    "VICTORY-ROUTE-2",
    "VICTORY-CREW",
    "CREW-IGNORING",
    "NUMBERS-ROUTES",
    "SWEEP",
    "DELIVERY",
    "SAVE-BOUNDARIES",
    "COMPOSITION-MAX",
    "FULL-RUN-CONTROLS"
)

if ([int]$manifest.schema_version -ne 1) { Add-Failure "schema_version must be 1." }
if ($validStages -notcontains [string]$manifest.stage) { Add-Failure "stage must be PRESTAGE or FINAL." }
if ($RequireFinal -and [string]$manifest.stage -ne "FINAL") { Add-Failure "-RequireFinal requires stage FINAL." }
if ([string]$manifest.candidate_base_commit -notmatch '^[0-9a-f]{40}$') {
    Add-Failure "candidate_base_commit must be a full lowercase Git commit id."
} else {
    & git -C $root cat-file -e "$($manifest.candidate_base_commit)^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { Add-Failure "candidate_base_commit does not exist in this repository." }
}
Require-Text $manifest.purpose "purpose"

$gameCatalog = Get-Content -LiteralPath (Join-Path $root "data/games/games.json") -Raw | ConvertFrom-Json
$archetypeCatalog = Get-Content -LiteralPath (Join-Path $root "data/environments/archetypes.json") -Raw | ConvertFrom-Json
$scenarioFiles = Get-ChildItem -LiteralPath (Join-Path $root "data/environments/scenario_sequences") -Filter "*.json" -File
$knownGames = @($gameCatalog | ForEach-Object { [string]$_.id } | Where-Object { $_ })
$knownArchetypes = @($archetypeCatalog | ForEach-Object { [string]$_.id } | Where-Object { $_ })
$knownScenarios = @()
foreach ($scenarioFile in $scenarioFiles) {
    $package = Get-Content -LiteralPath $scenarioFile.FullName -Raw | ConvertFrom-Json
    $knownScenarios += @(As-Array $package.scenarios | ForEach-Object { [string]$_.scenario_id } | Where-Object { $_ })
}
$knownScenarios = @($knownScenarios | Sort-Object -Unique)
$knownPusherMachines = @("quarter_falls", "jackpot_ridge", "vault_drop")

$representativeScenarioTargets = As-Array $manifest.coverage_policy.representative_scenario_ids
$materialBranchTargets = As-Array $manifest.coverage_policy.material_scenario_branch_ids
foreach ($scenarioId in $representativeScenarioTargets) {
    if ($knownScenarios -notcontains [string]$scenarioId) { Add-Failure "coverage_policy references unknown scenario '$scenarioId'." }
}
if (($RequireFinal -or [string]$manifest.stage -eq "FINAL") -and $representativeScenarioTargets.Count -eq 0) {
    Add-Failure "FINAL requires a non-empty representative_scenario_ids policy."
}
if (($RequireFinal -or [string]$manifest.stage -eq "FINAL") -and $materialBranchTargets.Count -eq 0) {
    Add-Failure "FINAL requires a non-empty material_scenario_branch_ids policy."
}

$seedIds = @{}
$seedValues = @{}
$verifiedCoverage = @{}
$verifiedArchetypes = @{}
$verifiedGames = @{}
$verifiedMachines = @{}
$verifiedScenarios = @{}
$verifiedScenarioBranches = @{}
$seeds = As-Array $manifest.seeds
if ($seeds.Count -eq 0) { Add-Failure "seeds must contain at least one record." }

foreach ($seed in $seeds) {
    $id = [string]$seed.id
    $value = [string]$seed.seed
    Require-Text $id "seeds[].id"
    Require-Text $value "seeds[$id].seed"
    Require-Text $seed.purpose "seeds[$id].purpose"
    Require-Text $seed.source_evidence "seeds[$id].source_evidence"
    Require-Text $seed.pending_verification "seeds[$id].pending_verification"
    if ($seedIds.ContainsKey($id)) { Add-Failure "Duplicate seed id '$id'." } else { $seedIds[$id] = $true }
    if ($seedValues.ContainsKey($value)) { Add-Failure "Duplicate seed value '$value'." } else { $seedValues[$value] = $true }
    if ($validStatuses -notcontains [string]$seed.status) { Add-Failure "seeds[$id].status is invalid." }
    if ($validAuthorities -notcontains [string]$seed.route_authority) { Add-Failure "seeds[$id].route_authority is invalid." }
    if ($seed.PSObject.Properties.Name -notcontains "route_shortcuts") { Add-Failure "seeds[$id].route_shortcuts must be explicit, even when empty." }
    foreach ($shortcut in As-Array $seed.route_shortcuts) {
        if ($validShortcuts -notcontains [string]$shortcut) { Add-Failure "seeds[$id] references unknown route shortcut '$shortcut'." }
    }
    if ([bool]$seed.owner_playtest_eligible -and [string]$seed.route_authority -ne "PRODUCTION_PUBLIC_ACTIONS") {
        Add-Failure "seeds[$id] cannot be owner-playtest eligible without PRODUCTION_PUBLIC_ACTIONS authority."
    }

    foreach ($slot in As-Array $seed.coverage_slots) {
        if ($requiredSlots -notcontains [string]$slot) { Add-Failure "seeds[$id] references unknown coverage slot '$slot'." }
    }
    foreach ($archetypeId in As-Array $seed.archetype_ids) {
        if ($knownArchetypes -notcontains [string]$archetypeId) { Add-Failure "seeds[$id] references unknown archetype '$archetypeId'." }
    }
    foreach ($gameId in As-Array $seed.game_ids) {
        if ($knownGames -notcontains [string]$gameId) { Add-Failure "seeds[$id] references unknown game '$gameId'." }
    }
    foreach ($machineId in As-Array $seed.pusher_machine_ids) {
        if ($knownPusherMachines -notcontains [string]$machineId) { Add-Failure "seeds[$id] references unknown pusher machine '$machineId'." }
    }
    foreach ($scenarioId in As-Array $seed.scenario_ids) {
        if ($knownScenarios -notcontains [string]$scenarioId) { Add-Failure "seeds[$id] references unknown scenario '$scenarioId'." }
    }

    if ([string]$seed.status -eq "VERIFIED") {
        if ([string]$seed.route_authority -ne "PRODUCTION_PUBLIC_ACTIONS") {
            Add-Failure "seeds[$id] VERIFIED owner coverage must use PRODUCTION_PUBLIC_ACTIONS."
        }
        if ((As-Array $seed.route_shortcuts).Count -gt 0) {
            Add-Failure "seeds[$id] VERIFIED owner coverage cannot use debug, injection, edit, teleport, override, or prevalidated-travel shortcuts."
        }
        if (-not [bool]$seed.owner_playtest_eligible) { Add-Failure "seeds[$id] VERIFIED must be owner-playtest eligible." }
        foreach ($field in @("tested_commit", "tested_tree", "platform", "setup", "expected", "actual", "evidence", "verification_date")) {
            Require-Text $seed.$field "seeds[$id].$field"
        }
        if ([string]$seed.tested_commit -notmatch '^[0-9a-f]{40}$') { Add-Failure "seeds[$id].tested_commit must be a full commit id." }
        if ([string]$seed.tested_tree -notmatch '^[0-9a-f]{40}$') { Add-Failure "seeds[$id].tested_tree must be a full tree id." }
        if ([string]$seed.tested_commit -match '^[0-9a-f]{40}$') {
            $actualTree = (& git -C $root rev-parse "$($seed.tested_commit)^{tree}" 2>$null)
            if ($LASTEXITCODE -ne 0) {
                Add-Failure "seeds[$id].tested_commit does not exist in this repository."
            } elseif ([string]$actualTree -ne [string]$seed.tested_tree) {
                Add-Failure "seeds[$id].tested_tree does not match tested_commit."
            }
        }
        if ($ExpectedTestedCommit -and [string]$seed.tested_commit -ne $ExpectedTestedCommit) {
            Add-Failure "seeds[$id] was not verified at expected commit $ExpectedTestedCommit."
        }
        foreach ($slot in As-Array $seed.coverage_slots) { $verifiedCoverage[[string]$slot] = $true }
        foreach ($item in As-Array $seed.archetype_ids) { $verifiedArchetypes[[string]$item] = $true }
        foreach ($item in As-Array $seed.game_ids) { $verifiedGames[[string]$item] = $true }
        foreach ($item in As-Array $seed.pusher_machine_ids) { $verifiedMachines[[string]$item] = $true }
        foreach ($item in As-Array $seed.scenario_ids) { $verifiedScenarios[[string]$item] = $true }
        foreach ($item in As-Array $seed.scenario_branch_ids) { $verifiedScenarioBranches[[string]$item] = $true }
    }
}

if ($RequireFinal -or [string]$manifest.stage -eq "FINAL") {
    foreach ($slot in $requiredSlots) {
        if (-not $verifiedCoverage.ContainsKey($slot)) { Add-Failure "FINAL verified coverage is missing slot '$slot'." }
    }
    foreach ($id in $knownArchetypes) {
        if (-not $verifiedArchetypes.ContainsKey($id)) { Add-Failure "FINAL verified coverage is missing archetype '$id'." }
    }
    foreach ($id in $knownGames) {
        if (-not $verifiedGames.ContainsKey($id)) { Add-Failure "FINAL verified coverage is missing game '$id'." }
    }
    foreach ($id in $knownPusherMachines) {
        if (-not $verifiedMachines.ContainsKey($id)) { Add-Failure "FINAL verified coverage is missing pusher machine '$id'." }
    }
    foreach ($id in $representativeScenarioTargets) {
        if (-not $verifiedScenarios.ContainsKey([string]$id)) { Add-Failure "FINAL verified coverage is missing representative scenario '$id'." }
    }
    foreach ($id in $materialBranchTargets) {
        if (-not $verifiedScenarioBranches.ContainsKey([string]$id)) { Add-Failure "FINAL verified coverage is missing scenario branch '$id'." }
    }
}

if ($Failures.Count -gt 0) {
    Write-Host "playtest06_2 seed manifest: FAIL ($($Failures.Count))" -ForegroundColor Red
    foreach ($failure in $Failures) { Write-Host " - $failure" }
    exit 1
}

$candidateCount = @($seeds | Where-Object { [string]$_.status -eq "CANDIDATE" }).Count
$verifiedCount = @($seeds | Where-Object { [string]$_.status -eq "VERIFIED" }).Count
$blockedCount = @($seeds | Where-Object { [string]$_.status -eq "BLOCKED" }).Count
Write-Host "playtest06_2 seed manifest: PASS stage=$($manifest.stage) seeds=$($seeds.Count) candidates=$candidateCount verified=$verifiedCount blocked=$blockedCount"
Write-Host "catalog: archetypes=$($knownArchetypes.Count) games=$($knownGames.Count) scenarios=$($knownScenarios.Count) pusher_machines=$($knownPusherMachines.Count)"
if ([string]$manifest.stage -eq "PRESTAGE") {
    Write-Host "PRESTAGE ONLY: this pass validates structure and candidate provenance fields; it does not prove owner-route reachability."
}
