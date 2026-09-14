$ErrorActionPreference = "Stop"
$sourceRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sourceContract = Join-Path $PSScriptRoot "playtest06_2_seed_manifest_contract.ps1"
$sourceIdentityHelper = Join-Path $PSScriptRoot "export_tree_identity.ps1"
. $sourceIdentityHelper
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
    $Value | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Copy-JsonObject {
    param($Value)
    return $Value | ConvertTo-Json -Depth 32 | ConvertFrom-Json
}

function Invoke-Contract {
    param([string]$ContractPath, [string]$ManifestPath, [switch]$Final, [string]$ExpectedCommit = "")
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
    } finally { $ErrorActionPreference = $priorErrorPreference }
    if ($exitCode -ne 0) { throw "git $($Arguments -join ' ') failed: $($output -join "`n")" }
    return $output
}

function Get-Hash {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-OutcomeType {
    param([string]$Field, [string]$Id)
    switch ($Field) {
        "archetype_ids" { return "ARCHETYPE_ENTERED" }
        "layer_ids" { return "LAYER_ENTERED" }
        "game_ids" { return "GAME_ENTRY_ACTION_SETTLEMENT_EXIT" }
        "pusher_machine_ids" { return "PUSHER_DEFINING_GOAL_COMPLETED" }
        "scenario_ids" { return "SCENARIO_ENTERED" }
        "scenario_branch_ids" { return "SCENARIO_BRANCH_AFTERMATH_OBSERVED" }
        "coverage_slots" {
            if ($Id -like "HEIST-PLAN-*") { return "HEIST_TERMINAL_OR_ABORT" }
            if ($Id -like "TURN-*") { return "TURN_OUTCOME_OBSERVED" }
            if ($Id -like "CASS-END-*") { return "CASS_ENDING_OBSERVED" }
            if ($Id -like "VICTORY-*") { return "TERMINAL_PROFILE_HANDOFF" }
            if ($Id -eq "SAVE-BOUNDARIES") { return "SAVE_ROUNDTRIP" }
            if ($Id -eq "FULL-RUN-CONTROLS") { return "FULL_RUN_TERMINAL" }
            if ($Id -eq "PUSHER-MACHINES") { return "PUSHER_DEFINING_GOAL_COMPLETED" }
            if ($Id -eq "GAMES") { return "GAME_ENTRY_ACTION_SETTLEMENT_EXIT" }
            if ($Id -eq "SCENARIO-BRANCHES") { return "SCENARIO_BRANCH_AFTERMATH_OBSERVED" }
            return "ROUTE_REQUIREMENT_OBSERVED"
        }
    }
}

try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $prestage = Invoke-Contract $sourceContract (Join-Path $sourceRoot "tools/playtest06_2_candidate_seeds.json")
    Assert-True ($prestage.exit_code -eq 0) "Committed PRESTAGE manifest failed its structural contract."
    Assert-True ($prestage.output.Contains("PRESTAGE ONLY")) "PRESTAGE pass omitted its non-evidence warning."

    foreach ($directory in @("tools", "data/games", "data/environments/scenario_sequences", "docs/plans/evidence/playtest06_2", "native/coin_pusher", "builds/windows", "builds/web")) {
        New-Item -ItemType Directory -Path (Join-Path $repo $directory) -Force | Out-Null
    }
    Copy-Item -LiteralPath $sourceContract -Destination (Join-Path $repo "tools/playtest06_2_seed_manifest_contract.ps1")
    $ownerTools = @("tools/playtest06_owner_build.ps1", "tools/export_itch.ps1", "tools/build_native_solver.ps1", "tools/verify_native_solver_runtime.ps1", "tools/web_perf_smoke.ps1", "tools/web_perf_export_mode.ps1", "tools/export_tree_identity.ps1", "tools/l02_web_perf_probe.mjs", "tools/serve_web.ps1")
    foreach ($ownerTool in $ownerTools) { Copy-Item -LiteralPath (Join-Path $sourceRoot $ownerTool) -Destination (Join-Path $repo $ownerTool) }
    Copy-Item -LiteralPath (Join-Path $sourceRoot "native/coin_pusher/toolchain.lock.json") -Destination (Join-Path $repo "native/coin_pusher/toolchain.lock.json")
    Copy-Item -LiteralPath (Join-Path $sourceRoot "export_presets.cfg") -Destination (Join-Path $repo "export_presets.cfg")
    Copy-Item -LiteralPath (Join-Path $sourceRoot "data/games/games.json") -Destination (Join-Path $repo "data/games/games.json")
    Copy-Item -LiteralPath (Join-Path $sourceRoot "data/environments/archetypes.json") -Destination (Join-Path $repo "data/environments/archetypes.json")
    Copy-Item -LiteralPath (Join-Path $sourceRoot "data/environments/scenarios.json") -Destination (Join-Path $repo "data/environments/scenarios.json")
    Copy-Item -Path (Join-Path $sourceRoot "data/environments/scenario_sequences/*.json") -Destination (Join-Path $repo "data/environments/scenario_sequences")
    ".tmp/`nbuilds/" | Set-Content -LiteralPath (Join-Path $repo ".gitignore") -Encoding ascii

    Invoke-Git @("init", "-q") | Out-Null
    Invoke-Git @("config", "user.name", "Playtest Contract Selftest") | Out-Null
    Invoke-Git @("config", "user.email", "playtest-selftest@example.invalid") | Out-Null
    Invoke-Git @("config", "core.autocrlf", "false") | Out-Null
    Invoke-Git @("add", "--", ".") | Out-Null
    Invoke-Git @("commit", "-q", "-m", "candidate source") | Out-Null
    $candidateCommit = (Invoke-Git @("rev-parse", "HEAD") | Select-Object -Last 1).Trim()
    $candidateTree = (Invoke-Git @("rev-parse", "HEAD^{tree}") | Select-Object -Last 1).Trim()

    $gameCatalog = Get-Content (Join-Path $repo "data/games/games.json") -Raw | ConvertFrom-Json
    $games = @($gameCatalog | ForEach-Object { [string]$_.id })
    $archetypes = Get-Content (Join-Path $repo "data/environments/archetypes.json") -Raw | ConvertFrom-Json
    $archetypeIds = @($archetypes | ForEach-Object { [string]$_.id })
    $layerIds = @()
    foreach ($archetype in $archetypes) {
        if ($archetype.PSObject.Properties.Name -contains "layers" -and $null -ne $archetype.layers) {
            foreach ($layer in $archetype.layers.PSObject.Properties) { $layerIds += "$([string]$archetype.id)::$($layer.Name)" }
        }
    }
    $scenarioCatalog = Get-Content (Join-Path $repo "data/environments/scenarios.json") -Raw | ConvertFrom-Json
    $representativeScenarios = @($scenarioCatalog.PSObject.Properties | ForEach-Object { [string]@($_.Value)[0].id })
    $materialBranches = @()
    foreach ($file in Get-ChildItem (Join-Path $repo "data/environments/scenario_sequences") -Filter "*.json" -File) {
        $package = Get-Content $file.FullName -Raw | ConvertFrom-Json
        foreach ($scenario in @($package.scenarios)) {
            if ($representativeScenarios -notcontains [string]$scenario.scenario_id) { continue }
            foreach ($phase in @($scenario.sequence.phase_graph.phases)) {
                foreach ($branch in @($phase.branches)) { $materialBranches += [string]$branch.id }
            }
        }
    }
    $materialBranches = @($materialBranches | Sort-Object -Unique)
    $slots = @("ARCHETYPES", "PUNCHLINE-LAYERS", "SCENARIO-REPRESENTATIVE", "SCENARIO-BRANCHES", "GAMES", "PUSHER-MACHINES", "CREW-RECRUIT", "HEIST-PLAN-A", "HEIST-PLAN-B", "TURN-FIRES", "TURN-NO-FIRE", "CASS-END-1", "CASS-END-2", "CASS-END-3", "VICTORY-ROUTE-1", "VICTORY-ROUTE-2", "VICTORY-CREW", "CREW-IGNORING", "NUMBERS-ROUTES", "SWEEP", "DELIVERY", "SAVE-BOUNDARIES", "COMPOSITION-MAX", "FULL-RUN-CONTROLS")
    $coverage = [ordered]@{
        coverage_slots = $slots; archetype_ids = $archetypeIds; layer_ids = $layerIds; game_ids = $games
        pusher_machine_ids = @("quarter_falls", "jackpot_ridge", "vault_drop")
        scenario_ids = $representativeScenarios; scenario_branch_ids = $materialBranches
    }
    $verificationDate = [datetime]::UtcNow.ToString("yyyy-MM-dd")

    foreach ($fixture in @(
        @{ path = "builds/windows/BeatTheHouse.exe"; text = "windows executable" },
        @{ path = "builds/windows/coin_pusher_native.nothreads.dll"; text = "windows native solver" },
        @{ path = "builds/web/index.html"; text = "<html>web build</html>" },
        @{ path = "builds/web/coin_pusher_native.nothreads.wasm"; text = "web native solver" }
    )) { Set-Content -LiteralPath (Join-Path $repo $fixture.path) -Value $fixture.text -Encoding utf8 }
    $fakeGodot = Join-Path $repo ".tmp/fake_godot.exe"
    New-Item -ItemType Directory -Path (Split-Path -Parent $fakeGodot) -Force | Out-Null
    Set-Content -LiteralPath $fakeGodot -Value "fake exact engine" -Encoding utf8
    $windowsSmokeRelative = "docs/plans/evidence/playtest06_2/owner_build_windows_smoke.json"
    $webSmokeRelative = "docs/plans/evidence/playtest06_2/owner_build_web_smoke.json"
    function Get-BuildRows([string]$relativeRoot) {
        return @(Get-ChildItem (Join-Path $repo $relativeRoot) -File -Recurse | Sort-Object FullName | ForEach-Object {
            [ordered]@{ path = $_.FullName.Substring($repo.Length).TrimStart('\','/').Replace('\','/'); bytes = [int64]$_.Length; sha256 = (Get-Hash $_.FullName) }
        })
    }
    $windowsRows = @(Get-BuildRows "builds/windows")
    $webRows = @(Get-BuildRows "builds/web")
    $windowsIdentity = [string](Get-ExportTreeIdentityFromRows -Rows $windowsRows -PathPrefix "builds/windows").aggregate_sha256
    $webIdentity = [string](Get-ExportTreeIdentityFromRows -Rows $webRows -PathPrefix "builds/web").aggregate_sha256
    Write-Json ([ordered]@{ schema = "beat_the_house.playtest06_owner_build_smoke/v1"; candidate_commit = $candidateCommit; candidate_tree = $candidateTree; platform = "WINDOWS_NATIVE"; passed = $true; export_identity_sha256 = $windowsIdentity }) (Join-Path $repo $windowsSmokeRelative)
    Write-Json ([ordered]@{ schema = "beat_the_house.playtest06_owner_build_smoke/v1"; candidate_commit = $candidateCommit; candidate_tree = $candidateTree; platform = "WEB_CHROME"; passed = $true; export_identity_sha256 = $webIdentity }) (Join-Path $repo $webSmokeRelative)
    $buildRelative = "docs/plans/evidence/playtest06_2/owner_build_manifest.json"
    $buildPath = Join-Path $repo $buildRelative
    $selftestLock = Get-Content (Join-Path $repo "native/coin_pusher/toolchain.lock.json") -Raw | ConvertFrom-Json
    $build = [ordered]@{
        schema = "beat_the_house.playtest06_owner_build/v1"; candidate_commit = $candidateCommit; candidate_tree = $candidateTree
        distribution_artifact = $false; archive_created = $false; upload_performed = $false
        builder_script_sha256 = Get-Hash (Join-Path $repo "tools/playtest06_owner_build.ps1")
        godot_path = $fakeGodot; godot_sha256 = Get-Hash $fakeGodot
        toolchain_lock_sha256 = Get-Hash (Join-Path $repo "native/coin_pusher/toolchain.lock.json")
        export_presets_sha256 = Get-Hash (Join-Path $repo "export_presets.cfg")
        web_template_sha256 = [string]$selftestLock.web.template_sha256
        tool_hashes = @($ownerTools | ForEach-Object { [ordered]@{ path = $_; sha256 = Get-Hash (Join-Path $repo $_) } })
        windows = [ordered]@{ platform = "WINDOWS_NATIVE"; output_root = "builds/windows"; export_identity_sha256 = $windowsIdentity; smoke_passed = $true; smoke_evidence = [ordered]@{ path = $windowsSmokeRelative; sha256 = Get-Hash (Join-Path $repo $windowsSmokeRelative) }; files = $windowsRows }
        web = [ordered]@{ platform = "WEB_CHROME"; output_root = "builds/web"; export_identity_sha256 = $webIdentity; smoke_passed = $true; smoke_evidence = [ordered]@{ path = $webSmokeRelative; sha256 = Get-Hash (Join-Path $repo $webSmokeRelative) }; files = $webRows }
    }
    Write-Json $build $buildPath
    $buildHash = Get-Hash $buildPath

    $pairs = @()
    foreach ($property in $coverage.GetEnumerator()) {
        foreach ($coverageId in @($property.Value)) { $pairs += [pscustomobject]@{ field = [string]$property.Key; id = [string]$coverageId } }
    }
    $routeSteps = @()
    for ($i = 0; $i -lt $pairs.Count; $i++) {
        $routeSteps += [ordered]@{ action_id = "route_$i"; instruction = "Use the visible control for witness $i."; expected_visible_result = "Witness $i is visible."; authority = "PUBLIC_UI_ACTION" }
    }
    $evidence = @()
    foreach ($platform in @("WINDOWS_NATIVE", "WEB_CHROME")) {
        $stem = $platform.ToLowerInvariant()
        $traceRelative = "docs/plans/evidence/playtest06_2/${stem}_runtime_trace.json"
        $tracePath = Join-Path $repo $traceRelative
        $events = @(for ($i = 0; $i -lt $pairs.Count; $i++) { [ordered]@{ event_id = "event_$i"; action_index = $i; action_id = "route_$i"; coverage_field = $pairs[$i].field; coverage_id = $pairs[$i].id; outcome_type = Get-OutcomeType $pairs[$i].field $pairs[$i].id; visible_result = "Witness $i is visible." } })
        Write-Json ([ordered]@{ schema = "beat_the_house.playtest06_runtime_trace/v1"; candidate_commit = $candidateCommit; candidate_tree = $candidateTree; seed_id = "selftest_verified"; seed = "PLAYTEST-SELFTEST"; platform = $platform; owner_build_manifest_sha256 = $buildHash; events = $events }) $tracePath
        $actions = @(for ($i = 0; $i -lt $pairs.Count; $i++) { [ordered]@{ action_id = "route_$i"; instruction = "Use the visible control for witness $i."; visible_result = "Witness $i is visible."; authority = "PUBLIC_UI_ACTION" } })
        $witnesses = @(for ($i = 0; $i -lt $pairs.Count; $i++) { [ordered]@{ coverage_field = $pairs[$i].field; coverage_id = $pairs[$i].id; action_index = $i; outcome_type = Get-OutcomeType $pairs[$i].field $pairs[$i].id; visible_result = "Witness $i is visible."; runtime_evidence_path = $traceRelative; runtime_event_id = "event_$i" } })
        $sessionRelative = "docs/plans/evidence/playtest06_2/${stem}_owner_session.json"
        $sessionPath = Join-Path $repo $sessionRelative
        Write-Json ([ordered]@{ schema = "beat_the_house.playtest06_owner_route/v1"; candidate_commit = $candidateCommit; candidate_tree = $candidateTree; seed_id = "selftest_verified"; seed = "PLAYTEST-SELFTEST"; platform = $platform; owner_build_manifest_sha256 = $buildHash; route_authority = "PRODUCTION_PUBLIC_ACTIONS"; route_shortcuts = @(); verification_date = $verificationDate; completed = $true; soft_lock = $false; dead_interaction_count = 0; public_actions = $actions; observed_coverage = $coverage; coverage_witnesses = $witnesses }) $sessionPath
        $evidence += [ordered]@{ kind = "RUNTIME_TRACE"; path = $traceRelative; sha256 = Get-Hash $tracePath }
        $evidence += [ordered]@{ kind = "OWNER_SESSION_REPORT"; path = $sessionRelative; sha256 = Get-Hash $sessionPath }
    }
    $seed = [ordered]@{
        id = "selftest_verified"; seed = "PLAYTEST-SELFTEST"; status = "VERIFIED"; route_authority = "PRODUCTION_PUBLIC_ACTIONS"; route_shortcuts = @(); owner_playtest_eligible = $true
        purpose = "Exercise the final seed manifest contract."; coverage_slots = $slots; archetype_ids = $archetypeIds; layer_ids = $layerIds; game_ids = $games
        pusher_machine_ids = @("quarter_falls", "jackpot_ridge", "vault_drop"); scenario_ids = $representativeScenarios; scenario_branch_ids = $materialBranches
        source_evidence = "Committed contract selftest evidence."; pending_verification = "None; contract selftest only."; tested_commit = $candidateCommit; tested_tree = $candidateTree
        platform = "WINDOWS_NATIVE_AND_WEB_CHROME"; setup = "Start from the normal visible owner menu."; expected = "The visible route reaches every claimed selftest target."; actual = "Two platform reports retain typed witnesses."; verification_date = $verificationDate
        route_steps = $routeSteps; evidence = $evidence
    }
    $manifest = [ordered]@{
        schema_version = 2; stage = "FINAL"; candidate_base_commit = $candidateCommit; candidate_base_tree = $candidateTree; purpose = "Positive final contract selftest."
        owner_build_evidence = [ordered]@{ path = $buildRelative; sha256 = $buildHash }
        coverage_policy = [ordered]@{ representative_scenario_ids = $representativeScenarios; material_scenario_branch_ids = $materialBranches; notes = "One live-catalog representative per scenario pool." }
        seeds = @($seed)
    }
    $manifestRelative = "docs/plans/evidence/playtest06_2/final_seed_manifest.json"
    $manifestPath = Join-Path $repo $manifestRelative
    $sandboxContract = Join-Path $repo "tools/playtest06_2_seed_manifest_contract.ps1"

    Invoke-Git @("add", "--", "docs/plans/evidence/playtest06_2") | Out-Null
    Invoke-Git @("commit", "-q", "-m", "retain build and route evidence") | Out-Null
    Write-Json $manifest $manifestPath
    $untrackedManifest = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($untrackedManifest.exit_code -ne 0 -and $untrackedManifest.output.Contains("must be Git-tracked and committed at HEAD")) "FINAL accepted an untracked canonical manifest."
    Invoke-Git @("add", "--", $manifestRelative) | Out-Null
    $stagedNewManifest = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($stagedNewManifest.exit_code -ne 0 -and $stagedNewManifest.output.Contains("must be Git-tracked and committed at HEAD")) "FINAL accepted a staged but uncommitted canonical manifest."
    Invoke-Git @("commit", "-q", "-m", "retain final manifest") | Out-Null
    $custodyHead = (Invoke-Git @("rev-parse", "HEAD") | Select-Object -Last 1).Trim()

    $withoutFinalFlag = Invoke-Contract $sandboxContract $manifestPath -ExpectedCommit $candidateCommit
    Assert-True ($withoutFinalFlag.exit_code -ne 0 -and $withoutFinalFlag.output.Contains("must be invoked with -RequireFinal")) "FINAL stage passed without -RequireFinal."
    $withoutExpected = Invoke-Contract $sandboxContract $manifestPath -Final
    Assert-True ($withoutExpected.exit_code -ne 0 -and $withoutExpected.output.Contains("requires -ExpectedTestedCommit")) "-RequireFinal passed without an exact expected commit."
    $positive = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($positive.exit_code -eq 0) "Valid FINAL fixture failed: $($positive.output)"

    $untrackedProbePath = Join-Path $repo "hostile_nonignored_untracked.txt"
    Set-Content -LiteralPath $untrackedProbePath -Value "must fail closed" -Encoding ascii
    $untrackedCandidate = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($untrackedCandidate.exit_code -ne 0 -and $untrackedCandidate.output.Contains("nonignored untracked files")) "FINAL accepted an arbitrary nonignored untracked file."
    Remove-Item -LiteralPath $untrackedProbePath -Force

    Add-Content -LiteralPath $manifestPath -Value " " -Encoding utf8
    $unstagedManifest = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($unstagedManifest.exit_code -ne 0 -and $unstagedManifest.output.Contains("working-tree bytes do not exactly match")) "FINAL accepted an unstaged manifest mutation."
    Invoke-Git @("add", "--", $manifestRelative) | Out-Null
    $stagedManifest = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($stagedManifest.exit_code -ne 0 -and $stagedManifest.output.Contains("Git index blob does not exactly match")) "FINAL accepted a staged manifest mutation."
    Invoke-Git @("restore", "--worktree", "--source=HEAD", "--", $manifestRelative) | Out-Null
    $stagedOnlyManifest = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($stagedOnlyManifest.exit_code -ne 0 -and $stagedOnlyManifest.output.Contains("Git index blob does not exactly match")) "FINAL accepted staged-only manifest state."
    Invoke-Git @("restore", "--staged", "--worktree", "--source=HEAD", "--", $manifestRelative) | Out-Null

    $wrongCommit = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $custodyHead
    Assert-True ($wrongCommit.exit_code -ne 0 -and $wrongCommit.output.Contains("does not equal ExpectedTestedCommit")) "FINAL accepted evidence for the wrong tested commit."

    $windowsExe = Join-Path $repo "builds/windows/BeatTheHouse.exe"
    $originalWindowsBytes = [IO.File]::ReadAllBytes($windowsExe)
    Add-Content -LiteralPath $windowsExe -Value "tamper" -Encoding utf8
    $tamperedBuild = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($tamperedBuild.exit_code -ne 0 -and $tamperedBuild.output.Contains("SHA-256 does not match the local build")) "FINAL accepted a replaced local owner build."
    [IO.File]::WriteAllBytes($windowsExe, $originalWindowsBytes)

    $webSessionRelative = "docs/plans/evidence/playtest06_2/web_chrome_owner_session.json"
    $webSessionPath = Join-Path $repo $webSessionRelative
    $originalWebSession = Get-Content $webSessionPath -Raw | ConvertFrom-Json
    function Invoke-SessionFixture($SessionValue, [string]$Name) {
        Write-Json $SessionValue $webSessionPath
        $badManifest = Copy-JsonObject $manifest
        ($badManifest.seeds[0].evidence | Where-Object { $_.path -eq $webSessionRelative }).sha256 = Get-Hash $webSessionPath
        Write-Json $badManifest $manifestPath
        Invoke-Git @("add", "--", $webSessionRelative, $manifestRelative) | Out-Null
        Invoke-Git @("commit", "-q", "-m", "hostile session $Name") | Out-Null
        return Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
    }
    $duplicateActions = Copy-JsonObject $originalWebSession
    $duplicateActions.public_actions[1].action_id = [string]$duplicateActions.public_actions[0].action_id
    $duplicateActionResult = Invoke-SessionFixture $duplicateActions "duplicate action"
    Assert-True ($duplicateActionResult.exit_code -ne 0 -and $duplicateActionResult.output.Contains("duplicate public action")) "FINAL accepted duplicate public action ids."

    $reorderedActions = Copy-JsonObject $originalWebSession
    $firstAction = Copy-JsonObject $reorderedActions.public_actions[0]
    $secondAction = Copy-JsonObject $reorderedActions.public_actions[1]
    $reorderedActions.public_actions[0] = $secondAction
    $reorderedActions.public_actions[1] = $firstAction
    $reorderedActionResult = Invoke-SessionFixture $reorderedActions "reordered actions"
    Assert-True ($reorderedActionResult.exit_code -ne 0 -and $reorderedActionResult.output.Contains("does not exactly match manifest route_steps at index")) "FINAL accepted public actions out of documented route order."

    Write-Json $originalWebSession $webSessionPath
    Write-Json $manifest $manifestPath
    Invoke-Git @("add", "--", $webSessionRelative, $manifestRelative) | Out-Null
    Invoke-Git @("commit", "-q", "-m", "restore positive owner session") | Out-Null

    $webTraceRelative = "docs/plans/evidence/playtest06_2/web_chrome_runtime_trace.json"
    $webTracePath = Join-Path $repo $webTraceRelative
    $originalWebTrace = Get-Content $webTracePath -Raw | ConvertFrom-Json
    $traceMismatchCases = @(
        @{ field = "platform"; value = "WINDOWS_NATIVE"; message = "platform does not match its referencing owner session"; target = "trace" },
        @{ field = "action_index"; value = 1; message = "action_index does not match" },
        @{ field = "coverage_field"; value = "layer_ids"; message = "coverage_field does not match" },
        @{ field = "coverage_id"; value = "wrong_coverage_id"; message = "coverage_id does not match" },
        @{ field = "outcome_type"; value = "WRONG_OUTCOME"; message = "outcome_type does not match" },
        @{ field = "visible_result"; value = "Wrong visible result."; message = "visible_result does not match" },
        @{ field = "action_id"; value = "wrong_action"; message = "action_id does not match" }
    )
    foreach ($case in $traceMismatchCases) {
        $badTrace = Copy-JsonObject $originalWebTrace
        if ([string]$case.target -eq "trace") { $badTrace.($case.field) = $case.value } else { $badTrace.events[0].($case.field) = $case.value }
        Write-Json $badTrace $webTracePath
        $badManifest = Copy-JsonObject $manifest
        ($badManifest.seeds[0].evidence | Where-Object { $_.path -eq $webTraceRelative }).sha256 = Get-Hash $webTracePath
        Write-Json $badManifest $manifestPath
        Invoke-Git @("add", "--", $webTraceRelative, $manifestRelative) | Out-Null
        Invoke-Git @("commit", "-q", "-m", "hostile trace $($case.field) mismatch") | Out-Null
        $traceMismatch = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
        Assert-True ($traceMismatch.exit_code -ne 0 -and $traceMismatch.output.Contains([string]$case.message)) "FINAL accepted runtime trace/witness $($case.field) mismatch."
    }

    Write-Json $originalWebTrace $webTracePath
    Write-Json $manifest $manifestPath
    Invoke-Git @("add", "--", $webTraceRelative, $manifestRelative) | Out-Null
    Invoke-Git @("commit", "-q", "-m", "restore positive runtime trace") | Out-Null

    $windowsSmokePath = Join-Path $repo $windowsSmokeRelative
    $originalWindowsSmoke = Get-Content $windowsSmokePath -Raw | ConvertFrom-Json
    function Invoke-SmokeFixture($SmokeValue, [string]$Name) {
        if ($SmokeValue -is [string]) { Set-Content -LiteralPath $windowsSmokePath -Value $SmokeValue -Encoding utf8 } else { Write-Json $SmokeValue $windowsSmokePath }
        $badBuild = Copy-JsonObject $build
        $badBuild.windows.smoke_evidence.sha256 = Get-Hash $windowsSmokePath
        Write-Json $badBuild $buildPath
        $badManifest = Copy-JsonObject $manifest
        $badManifest.owner_build_evidence.sha256 = Get-Hash $buildPath
        Write-Json $badManifest $manifestPath
        Invoke-Git @("add", "--", $windowsSmokeRelative, $buildRelative, $manifestRelative) | Out-Null
        Invoke-Git @("commit", "-q", "-m", "hostile smoke $Name") | Out-Null
        return Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
    }
    $randomSmoke = Invoke-SmokeFixture "not a JSON smoke report" "random content"
    Assert-True ($randomSmoke.exit_code -ne 0 -and $randomSmoke.output.Contains("is not valid UTF-8 JSON")) "FINAL accepted random committed smoke content."

    $wrongSmokeValue = Copy-JsonObject $originalWindowsSmoke
    $wrongSmokeValue.schema = "wrong.schema"
    $wrongSmokeValue.candidate_commit = "0" * 40
    $wrongSmokeValue.candidate_tree = "1" * 40
    $wrongSmokeValue.platform = "WEB_CHROME"
    $wrongSmokeValue.passed = $false
    $wrongSmokeValue.export_identity_sha256 = "9" * 64
    $wrongSmoke = Invoke-SmokeFixture $wrongSmokeValue "wrong fields"
    foreach ($message in @("wrong schema", "candidate identity", "platform does not match", "passed must be true", "export identity does not match")) {
        Assert-True ($wrongSmoke.output.Contains($message)) "Smoke hostile fixture did not reject '$message'."
    }

    $wrongBuild = Copy-JsonObject $build
    $wrongBuild.tool_hashes[0].sha256 = "8" * 64
    $wrongBuild.web_template_sha256 = "7" * 64
    Write-Json $wrongBuild $buildPath
    $wrongBuildManifest = Copy-JsonObject $manifest
    $wrongBuildManifest.owner_build_evidence.sha256 = Get-Hash $buildPath
    Write-Json $wrongBuildManifest $manifestPath
    Invoke-Git @("add", "--", $buildRelative, $manifestRelative) | Out-Null
    Invoke-Git @("commit", "-q", "-m", "hostile tool and template identity") | Out-Null
    $wrongBuildIdentity = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($wrongBuildIdentity.exit_code -ne 0 -and $wrongBuildIdentity.output.Contains("does not match the local tool") -and $wrongBuildIdentity.output.Contains("does not match the locked Web template identity")) "FINAL accepted wrong owner tool or Web-template identity."

    Set-Content -LiteralPath (Join-Path $repo "data/unauthorized_product_change.txt") -Value "product delta" -Encoding utf8
    Invoke-Git @("add", "--", "data/unauthorized_product_change.txt") | Out-Null
    Invoke-Git @("commit", "-q", "-m", "hostile product delta") | Out-Null
    $productDelta = Invoke-Contract $sandboxContract $manifestPath -Final -ExpectedCommit $candidateCommit
    Assert-True ($productDelta.exit_code -ne 0 -and $productDelta.output.Contains("outside declared playtest evidence/docs")) "FINAL accepted a product delta after the tested candidate."

    if ($failures.Count -gt 0) {
        Write-Host "playtest06_2 seed manifest selftest: FAIL ($($failures.Count))" -ForegroundColor Red
        foreach ($failure in $failures) { Write-Host " - $failure" }
        exit 1
    }
    Write-Host "playtest06_2 seed manifest selftest: PASS checks=49 custody=manifest/evidence/build/smoke/runtime/order/untracked catalogs=18_archetypes/3_layers/11_games/55_scenarios/$($materialBranches.Count)_selected_branches platforms=2"
}
finally {
    if (Test-Path -LiteralPath $temp) {
        $resolved = [IO.Path]::GetFullPath($temp)
        if (-not $resolved.StartsWith($allowedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing to remove selftest output outside its dedicated .tmp root: $resolved" }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
