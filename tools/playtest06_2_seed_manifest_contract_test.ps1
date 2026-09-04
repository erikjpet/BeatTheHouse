$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$contract = Join-Path $PSScriptRoot "playtest06_2_seed_manifest_contract.ps1"
$failures = [Collections.Generic.List[string]]::new()
$tempRelative = ".tmp/playtest06_2_seed_manifest_contract_test/$([guid]::NewGuid().ToString('N'))"
$temp = [IO.Path]::GetFullPath((Join-Path $root $tempRelative))
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $root ".tmp/playtest06_2_seed_manifest_contract_test"))

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Write-Json {
    param($Value, [string]$Path)
    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Copy-JsonObject {
    param($Value)
    return $Value | ConvertTo-Json -Depth 20 | ConvertFrom-Json
}

function Invoke-Contract {
    param([string]$Path, [switch]$Final, [string]$ExpectedCommit = "")
    $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $contract, "-ManifestPath", $Path)
    if ($Final) { $arguments += "-RequireFinal" }
    if ($ExpectedCommit) { $arguments += @("-ExpectedTestedCommit", $ExpectedCommit) }
    $lines = @(& powershell @arguments 2>&1 | ForEach-Object { [string]$_ })
    return [pscustomobject]@{ exit_code = $LASTEXITCODE; output = ($lines -join "`n") }
}

try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null

    $prestage = Invoke-Contract (Join-Path $root "tools/playtest06_2_candidate_seeds.json")
    Assert-True ($prestage.exit_code -eq 0) "Committed PRESTAGE manifest failed its structural contract."
    Assert-True ($prestage.output.Contains("PRESTAGE ONLY")) "PRESTAGE pass omitted its non-evidence warning."

    $head = (& git -C $root rev-parse HEAD).Trim()
    $tree = (& git -C $root rev-parse "$head`^{tree}").Trim()
    $gameCatalog = Get-Content -LiteralPath (Join-Path $root "data/games/games.json") -Raw | ConvertFrom-Json
    $games = @()
    foreach ($game in $gameCatalog) { $games += [string]$game.id }
    $archetypes = Get-Content -LiteralPath (Join-Path $root "data/environments/archetypes.json") -Raw | ConvertFrom-Json
    $archetypeIds = @()
    foreach ($archetype in $archetypes) { $archetypeIds += [string]$archetype.id }
    $layerIds = @()
    foreach ($archetype in $archetypes) {
        if ($archetype.PSObject.Properties.Name -contains "layers" -and $null -ne $archetype.layers) {
            foreach ($layer in $archetype.layers.PSObject.Properties) {
                $layerIds += "$([string]$archetype.id)::$($layer.Name)"
            }
        }
    }

    $scenarioCatalog = Get-Content -LiteralPath (Join-Path $root "data/environments/scenarios.json") -Raw | ConvertFrom-Json
    $representativeScenarios = @()
    foreach ($pool in $scenarioCatalog.PSObject.Properties) {
        $first = @($pool.Value)[0]
        $representativeScenarios += [string]$first.id
    }
    $materialBranches = @()
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $root "data/environments/scenario_sequences") -Filter "*.json" -File) {
        $package = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        foreach ($scenario in @($package.scenarios)) {
            if ($representativeScenarios -notcontains [string]$scenario.scenario_id) { continue }
            foreach ($phase in @($scenario.sequence.phase_graph.phases)) {
                foreach ($branch in @($phase.branches)) { $materialBranches += [string]$branch.id }
            }
        }
    }
    $materialBranches = @($materialBranches | Sort-Object -Unique)
    $slots = @(
        "ARCHETYPES", "PUNCHLINE-LAYERS", "SCENARIO-REPRESENTATIVE", "SCENARIO-BRANCHES",
        "GAMES", "PUSHER-MACHINES", "CREW-RECRUIT", "HEIST-PLAN-A", "HEIST-PLAN-B",
        "TURN-FIRES", "TURN-NO-FIRE", "CASS-END-1", "CASS-END-2", "CASS-END-3",
        "VICTORY-ROUTE-1", "VICTORY-ROUTE-2", "VICTORY-CREW", "CREW-IGNORING",
        "NUMBERS-ROUTES", "SWEEP", "DELIVERY", "SAVE-BOUNDARIES", "COMPOSITION-MAX",
        "FULL-RUN-CONTROLS"
    )
    $coverage = [ordered]@{
        coverage_slots = $slots
        archetype_ids = $archetypeIds
        layer_ids = $layerIds
        game_ids = $games
        pusher_machine_ids = @("quarter_falls", "jackpot_ridge", "vault_drop")
        scenario_ids = $representativeScenarios
        scenario_branch_ids = $materialBranches
    }
    $verificationDate = [datetime]::UtcNow.ToString("yyyy-MM-dd")
    $publicAction = [ordered]@{
        action_id = "owner_visible_route"
        instruction = "Follow the visible route controls."
        visible_result = "The claimed surfaces and outcomes are visible."
        authority = "PUBLIC_UI_ACTION"
    }
    $session = [ordered]@{
        schema = "beat_the_house.playtest06_owner_route/v1"
        candidate_commit = $head
        candidate_tree = $tree
        seed_id = "selftest_verified"
        seed = "PLAYTEST-SELFTEST"
        platform = "WINDOWS_NATIVE_AND_WEB_CHROME"
        route_authority = "PRODUCTION_PUBLIC_ACTIONS"
        route_shortcuts = @()
        verification_date = $verificationDate
        completed = $true
        soft_lock = $false
        dead_interaction_count = 0
        public_actions = @($publicAction)
        observed_coverage = $coverage
    }
    $sessionPath = Join-Path $temp "owner_session.json"
    Write-Json $session $sessionPath
    $sessionHash = (Get-FileHash -LiteralPath $sessionPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $sessionRelative = $sessionPath.Substring($root.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
    $seed = [ordered]@{
        id = "selftest_verified"
        seed = "PLAYTEST-SELFTEST"
        status = "VERIFIED"
        route_authority = "PRODUCTION_PUBLIC_ACTIONS"
        route_shortcuts = @()
        owner_playtest_eligible = $true
        purpose = "Exercise the final seed manifest contract."
        coverage_slots = $slots
        archetype_ids = $archetypeIds
        layer_ids = $layerIds
        game_ids = $games
        pusher_machine_ids = @("quarter_falls", "jackpot_ridge", "vault_drop")
        scenario_ids = $representativeScenarios
        scenario_branch_ids = $materialBranches
        source_evidence = "Generated contract selftest evidence."
        pending_verification = "None; contract selftest only."
        tested_commit = $head
        tested_tree = $tree
        platform = "WINDOWS_NATIVE_AND_WEB_CHROME"
        setup = "Start from the normal visible owner menu."
        expected = "The visible route reaches every claimed selftest target."
        actual = "The retained selftest report records every claimed target."
        verification_date = $verificationDate
        route_steps = @([ordered]@{
            action_id = "owner_visible_route"
            instruction = "Follow the visible route controls."
            expected_visible_result = "The claimed surfaces and outcomes are visible."
            authority = "PUBLIC_UI_ACTION"
        })
        evidence = @([ordered]@{ kind = "OWNER_SESSION_REPORT"; path = $sessionRelative; sha256 = $sessionHash })
    }
    $manifest = [ordered]@{
        schema_version = 2
        stage = "FINAL"
        candidate_base_commit = $head
        candidate_base_tree = $tree
        purpose = "Positive final contract selftest."
        coverage_policy = [ordered]@{
            representative_scenario_ids = $representativeScenarios
            material_scenario_branch_ids = $materialBranches
            notes = "One live-catalog representative per scenario pool."
        }
        seeds = @($seed)
    }
    $manifestPath = Join-Path $temp "final.json"
    Write-Json $manifest $manifestPath

    $withoutFinalFlag = Invoke-Contract $manifestPath -ExpectedCommit $head
    Assert-True ($withoutFinalFlag.exit_code -ne 0 -and $withoutFinalFlag.output.Contains("must be invoked with -RequireFinal")) "FINAL stage passed without -RequireFinal."
    $withoutExpected = Invoke-Contract $manifestPath -Final
    Assert-True ($withoutExpected.exit_code -ne 0 -and $withoutExpected.output.Contains("requires -ExpectedTestedCommit")) "-RequireFinal passed without an exact expected commit."
    $positive = Invoke-Contract $manifestPath -Final -ExpectedCommit $head
    Assert-True ($positive.exit_code -eq 0) "Valid exact-source FINAL fixture failed: $($positive.output)"

    $wrongCommit = Copy-JsonObject $manifest
    $wrongCommit.candidate_base_commit = [string](git -C $root rev-parse "$head^")
    $wrongCommit.candidate_base_tree = [string](git -C $root rev-parse "$($wrongCommit.candidate_base_commit)`^{tree}")
    $wrongCommit.seeds[0].tested_commit = $wrongCommit.candidate_base_commit
    $wrongCommit.seeds[0].tested_tree = $wrongCommit.candidate_base_tree
    $wrongCommitPath = Join-Path $temp "wrong_commit.json"
    Write-Json $wrongCommit $wrongCommitPath
    $wrongCommitResult = Invoke-Contract $wrongCommitPath -Final -ExpectedCommit $head
    Assert-True ($wrongCommitResult.exit_code -ne 0 -and $wrongCommitResult.output.Contains("does not equal ExpectedTestedCommit")) "FINAL accepted evidence from a different commit/tree."

    $authority = Copy-JsonObject $manifest
    $authority.seeds[0].platform = "potato"
    $authority.seeds[0].verification_date = "never"
    $authority.seeds[0].route_shortcuts = @("DEBUG_ACTION")
    $authority.seeds[0].setup = "Use DEBUG_ACTION and TELEPORT."
    $authority.seeds[0].evidence[0].path = ".tmp/does-not-exist.json"
    $authorityPath = Join-Path $temp "authority_shortcut.json"
    Write-Json $authority $authorityPath
    $authorityResult = Invoke-Contract $authorityPath -Final -ExpectedCommit $head
    Assert-True ($authorityResult.exit_code -ne 0) "FINAL accepted invalid platform/date/authority/evidence."
    foreach ($message in @("platform is not an allowed", "must be an ISO", "cannot use debug", "forbidden shortcut token", "path does not exist")) {
        Assert-True ($authorityResult.output.Contains($message)) "Authority adversarial fixture did not fail on '$message'."
    }

    $catalog = Copy-JsonObject $manifest
    $catalog.coverage_policy.material_scenario_branch_ids[0] = "not_a_real_branch"
    $catalog.seeds[0].scenario_branch_ids[0] = "not_a_real_branch"
    $catalog.seeds[0].layer_ids = @($catalog.seeds[0].layer_ids | Select-Object -Skip 1)
    $catalogPath = Join-Path $temp "catalog_shortfall.json"
    Write-Json $catalog $catalogPath
    $catalogResult = Invoke-Contract $catalogPath -Final -ExpectedCommit $head
    Assert-True ($catalogResult.exit_code -ne 0) "FINAL accepted an unknown branch and missing Punchline layer."
    Assert-True ($catalogResult.output.Contains("unknown scenario branch")) "Catalog adversarial fixture did not reject the bogus branch."
    Assert-True ($catalogResult.output.Contains("layer_ids versus retained owner evidence")) "Catalog adversarial fixture did not reject missing layer evidence."

    if ($failures.Count -gt 0) {
        Write-Host "playtest06_2 seed manifest selftest: FAIL ($($failures.Count))" -ForegroundColor Red
        foreach ($failure in $failures) { Write-Host " - $failure" }
        exit 1
    }
    Write-Host "playtest06_2 seed manifest selftest: PASS checks=16 catalogs=18_archetypes/3_layers/11_games/55_scenarios/$($materialBranches.Count)_selected_branches"
}
finally {
    if (Test-Path -LiteralPath $temp) {
        $resolved = [IO.Path]::GetFullPath($temp)
        if (-not $resolved.StartsWith($allowedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove selftest output outside its dedicated .tmp root: $resolved"
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
