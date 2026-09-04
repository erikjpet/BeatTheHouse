$ErrorActionPreference = "Stop"
$sourceRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sourceContract = Join-Path $PSScriptRoot "playtest06_2_seed_manifest_contract.ps1"
$failures = [Collections.Generic.List[string]]::new()
$tempRelative = ".tmp/playtest06_2_seed_manifest_contract_test/$([guid]::NewGuid().ToString('N'))"
$temp = [IO.Path]::GetFullPath((Join-Path $sourceRoot $tempRelative))
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $sourceRoot ".tmp/playtest06_2_seed_manifest_contract_test"))
$repo = Join-Path $temp "repo"

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Write-Json {
    param($Value, [string]$Path)
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $Value | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Copy-JsonObject {
    param($Value)
    return $Value | ConvertTo-Json -Depth 24 | ConvertFrom-Json
}

function Invoke-Contract {
    param(
        [string]$ContractPath,
        [string]$ManifestPath,
        [switch]$Final,
        [string]$ExpectedCommit = ""
    )
    $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ContractPath, "-ManifestPath", $ManifestPath)
    if ($Final) { $arguments += "-RequireFinal" }
    if ($ExpectedCommit) { $arguments += @("-ExpectedTestedCommit", $ExpectedCommit) }
    $lines = @(& powershell @arguments 2>&1 | ForEach-Object { [string]$_ })
    return [pscustomobject]@{ exit_code = $LASTEXITCODE; output = ($lines -join "`n") }
}

function Invoke-Git {
    param([string[]]$Arguments)
    $priorErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = @(& git -C $script:repo @Arguments 2>&1 | ForEach-Object { [string]$_ })
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $priorErrorPreference
    }
    if ($exitCode -ne 0) { throw "git $($Arguments -join ' ') failed: $($output -join "`n")" }
    return $output
}

try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null

    $prestage = Invoke-Contract $sourceContract (Join-Path $sourceRoot "tools/playtest06_2_candidate_seeds.json")
    Assert-True ($prestage.exit_code -eq 0) "Committed PRESTAGE manifest failed its structural contract."
    Assert-True ($prestage.output.Contains("PRESTAGE ONLY")) "PRESTAGE pass omitted its non-evidence warning."

    foreach ($directory in @(
        "tools",
        "data/games",
        "data/environments/scenario_sequences",
        "docs/plans/evidence/playtest06_2"
    )) {
        New-Item -ItemType Directory -Path (Join-Path $repo $directory) -Force | Out-Null
    }
    Copy-Item -LiteralPath $sourceContract -Destination (Join-Path $repo "tools/playtest06_2_seed_manifest_contract.ps1")
    Copy-Item -LiteralPath (Join-Path $sourceRoot "data/games/games.json") -Destination (Join-Path $repo "data/games/games.json")
    Copy-Item -LiteralPath (Join-Path $sourceRoot "data/environments/archetypes.json") -Destination (Join-Path $repo "data/environments/archetypes.json")
    Copy-Item -LiteralPath (Join-Path $sourceRoot "data/environments/scenarios.json") -Destination (Join-Path $repo "data/environments/scenarios.json")
    Copy-Item -Path (Join-Path $sourceRoot "data/environments/scenario_sequences/*.json") -Destination (Join-Path $repo "data/environments/scenario_sequences")
    ".tmp/" | Set-Content -LiteralPath (Join-Path $repo ".gitignore") -Encoding ascii

    Invoke-Git @("init", "-q") | Out-Null
    Invoke-Git @("config", "user.name", "Playtest Contract Selftest") | Out-Null
    Invoke-Git @("config", "user.email", "playtest-selftest@example.invalid") | Out-Null
    Invoke-Git @("config", "core.autocrlf", "false") | Out-Null
    Invoke-Git @("add", "--", ".") | Out-Null
    Invoke-Git @("commit", "-q", "-m", "candidate source") | Out-Null
    $candidateCommit = (Invoke-Git @("rev-parse", "HEAD") | Select-Object -Last 1).Trim()
    $candidateTree = (Invoke-Git @("rev-parse", "HEAD^{tree}") | Select-Object -Last 1).Trim()

    $gameCatalog = Get-Content -LiteralPath (Join-Path $repo "data/games/games.json") -Raw | ConvertFrom-Json
    $games = @($gameCatalog | ForEach-Object { [string]$_.id })
    $archetypes = Get-Content -LiteralPath (Join-Path $repo "data/environments/archetypes.json") -Raw | ConvertFrom-Json
    $archetypeIds = @($archetypes | ForEach-Object { [string]$_.id })
    $layerIds = @()
    foreach ($archetype in $archetypes) {
        if ($archetype.PSObject.Properties.Name -contains "layers" -and $null -ne $archetype.layers) {
            foreach ($layer in $archetype.layers.PSObject.Properties) {
                $layerIds += "$([string]$archetype.id)::$($layer.Name)"
            }
        }
    }
    $scenarioCatalog = Get-Content -LiteralPath (Join-Path $repo "data/environments/scenarios.json") -Raw | ConvertFrom-Json
    $representativeScenarios = @()
    foreach ($pool in $scenarioCatalog.PSObject.Properties) {
        $representativeScenarios += [string]@($pool.Value)[0].id
    }
    $materialBranches = @()
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repo "data/environments/scenario_sequences") -Filter "*.json" -File) {
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
        candidate_commit = $candidateCommit
        candidate_tree = $candidateTree
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
    $sessionRelative = "docs/plans/evidence/playtest06_2/selftest_owner_session.json"
    $sessionPath = Join-Path $repo $sessionRelative
    Write-Json $session $sessionPath
    $sessionHash = (Get-FileHash -LiteralPath $sessionPath -Algorithm SHA256).Hash.ToLowerInvariant()
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
        source_evidence = "Committed contract selftest evidence."
        pending_verification = "None; contract selftest only."
        tested_commit = $candidateCommit
        tested_tree = $candidateTree
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
        candidate_base_commit = $candidateCommit
        candidate_base_tree = $candidateTree
        purpose = "Positive final contract selftest."
        coverage_policy = [ordered]@{
            representative_scenario_ids = $representativeScenarios
            material_scenario_branch_ids = $materialBranches
            notes = "One live-catalog representative per scenario pool."
        }
        seeds = @($seed)
    }
    $manifestPath = Join-Path $repo "tools/final.json"
    Write-Json $manifest $manifestPath
    Invoke-Git @("add", "--", $sessionRelative, "tools/final.json") | Out-Null
    Invoke-Git @("commit", "-q", "-m", "retain owner evidence") | Out-Null
    $custodyHead = (Invoke-Git @("rev-parse", "HEAD") | Select-Object -Last 1).Trim()
    $sandboxContract = Join-Path $repo "tools/playtest06_2_seed_manifest_contract.ps1"

    $withoutFinalFlag = Invoke-Contract $sandboxContract $manifestPath -ExpectedCommit $candidateCommit
    Assert-True ($withoutFinalFlag.exit_code -ne 0 -and $withoutFinalFlag.output.Contains("must be invoked with -RequireFinal")) "FINAL stage passed without -RequireFinal."
    $withoutExpected = Invoke-Contract $sandboxContract $manifestPath -Final
    Assert-True ($withoutExpected.exit_code -ne 0 -and $withoutExpected.output.Contains("requires -ExpectedTestedCommit")) "-RequireFinal passed without an exact expected commit."
    $positive = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($positive.exit_code -eq 0) "Valid FINAL fixture backed by committed evidence failed: $($positive.output)"

    $wrongCommitResult = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $custodyHead
    Assert-True ($wrongCommitResult.exit_code -ne 0 -and $wrongCommitResult.output.Contains("does not equal ExpectedTestedCommit")) "FINAL accepted evidence for a different expected commit/tree."

    $authority = Copy-JsonObject $manifest
    $authority.seeds[0].platform = "potato"
    $authority.seeds[0].verification_date = "never"
    $authority.seeds[0].route_shortcuts = @("DEBUG_ACTION")
    $authority.seeds[0].setup = "Use DEBUG_ACTION and TELEPORT."
    $authorityPath = Join-Path $temp "authority_shortcut.json"
    Write-Json $authority $authorityPath
    $authorityResult = Invoke-Contract $sandboxContract $authorityPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($authorityResult.exit_code -ne 0) "FINAL accepted invalid platform/date/authority."
    foreach ($message in @("platform is not an allowed", "must be an ISO", "cannot use debug", "forbidden shortcut token")) {
        Assert-True ($authorityResult.output.Contains($message)) "Authority adversarial fixture did not fail on '$message'."
    }

    $catalog = Copy-JsonObject $manifest
    $catalog.coverage_policy.material_scenario_branch_ids[0] = "not_a_real_branch"
    $catalog.seeds[0].scenario_branch_ids[0] = "not_a_real_branch"
    $catalog.seeds[0].layer_ids = @($catalog.seeds[0].layer_ids | Select-Object -Skip 1)
    $catalogPath = Join-Path $temp "catalog_shortfall.json"
    Write-Json $catalog $catalogPath
    $catalogResult = Invoke-Contract $sandboxContract $catalogPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($catalogResult.exit_code -ne 0) "FINAL accepted an unknown branch and missing Punchline layer."
    Assert-True ($catalogResult.output.Contains("unknown scenario branch")) "Catalog adversarial fixture did not reject the bogus branch."
    Assert-True ($catalogResult.output.Contains("layer_ids versus retained owner evidence")) "Catalog adversarial fixture did not reject missing layer evidence."

    $ignoredRelative = ".tmp/valid_looking_owner_session.json"
    $ignoredPath = Join-Path $repo $ignoredRelative
    New-Item -ItemType Directory -Path (Split-Path -Parent $ignoredPath) -Force | Out-Null
    Copy-Item -LiteralPath $sessionPath -Destination $ignoredPath
    $ignoredHash = (Get-FileHash -LiteralPath $ignoredPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $ignoredCheck = @(& git -C $repo check-ignore -- $ignoredRelative 2>&1)
    Assert-True ($LASTEXITCODE -eq 0) "Ignored evidence fixture was not actually Git-ignored."
    $ignored = Copy-JsonObject $manifest
    $ignored.seeds[0].evidence[0].path = $ignoredRelative
    $ignored.seeds[0].evidence[0].sha256 = $ignoredHash
    $ignoredManifestPath = Join-Path $temp "ignored_evidence.json"
    Write-Json $ignored $ignoredManifestPath
    $ignoredResult = Invoke-Contract $sandboxContract $ignoredManifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($ignoredResult.exit_code -ne 0 -and $ignoredResult.output.Contains("must remain under docs/plans/evidence/playtest06_2")) "FINAL accepted valid-looking hash-correct ignored .tmp evidence: exit=$($ignoredResult.exit_code) output=$($ignoredResult.output)"

    $untrackedRelative = "docs/plans/evidence/playtest06_2/untracked_owner_session.json"
    $untrackedPath = Join-Path $repo $untrackedRelative
    Copy-Item -LiteralPath $sessionPath -Destination $untrackedPath
    $untrackedHash = (Get-FileHash -LiteralPath $untrackedPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $untracked = Copy-JsonObject $manifest
    $untracked.seeds[0].evidence[0].path = $untrackedRelative
    $untracked.seeds[0].evidence[0].sha256 = $untrackedHash
    $untrackedManifestPath = Join-Path $temp "untracked_evidence.json"
    Write-Json $untracked $untrackedManifestPath
    $untrackedResult = Invoke-Contract $sandboxContract $untrackedManifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($untrackedResult.exit_code -ne 0 -and $untrackedResult.output.Contains("must be Git-tracked and committed at HEAD")) "FINAL accepted valid-looking hash-correct untracked evidence inside the custody directory."

    Add-Content -LiteralPath $sessionPath -Value " " -Encoding utf8
    $modifiedHash = (Get-FileHash -LiteralPath $sessionPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $modified = Copy-JsonObject $manifest
    $modified.seeds[0].evidence[0].sha256 = $modifiedHash
    $modifiedManifestPath = Join-Path $temp "modified_evidence.json"
    Write-Json $modified $modifiedManifestPath
    $modifiedResult = Invoke-Contract $sandboxContract $modifiedManifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($modifiedResult.exit_code -ne 0 -and $modifiedResult.output.Contains("working-tree bytes do not exactly match the committed HEAD blob")) "FINAL accepted hash-correct unstaged modifications to tracked evidence."
    Invoke-Git @("add", "--", $sessionRelative) | Out-Null
    $stagedResult = Invoke-Contract $sandboxContract $modifiedManifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($stagedResult.exit_code -ne 0 -and $stagedResult.output.Contains("Git index blob does not exactly match the committed HEAD blob")) "FINAL accepted hash-correct staged modifications to tracked evidence."

    Invoke-Git @("restore", "--worktree", "--source=HEAD", "--", $sessionRelative) | Out-Null
    $stagedOnlyResult = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($stagedOnlyResult.exit_code -ne 0 -and $stagedOnlyResult.output.Contains("Git index blob does not exactly match the committed HEAD blob")) "FINAL accepted staged-only modifications after the working file was restored to HEAD."

    if ($failures.Count -gt 0) {
        Write-Host "playtest06_2 seed manifest selftest: FAIL ($($failures.Count))" -ForegroundColor Red
        foreach ($failure in $failures) { Write-Host " - $failure" }
        exit 1
    }
    Write-Host "playtest06_2 seed manifest selftest: PASS checks=23 custody=committed_HEAD_and_index_blob catalogs=18_archetypes/3_layers/11_games/55_scenarios/$($materialBranches.Count)_selected_branches"
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
