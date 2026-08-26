param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "split_test_runner_helpers.ps1")

function Get-ProjectRelativePath {
    param([string]$Path)
    $rootPath = [System.IO.Path]::GetFullPath($root)
    if (-not $rootPath.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootPath += [System.IO.Path]::DirectorySeparatorChar
    }
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $rootUri = [System.Uri]$rootPath
    $pathUri = [System.Uri]$fullPath
    return [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString()) -replace "\\", "/"
}

function Test-JsonObjectRoot {
    param([AllowNull()][object]$Value)
    return $null -ne $Value -and $Value.GetType() -eq [System.Management.Automation.PSCustomObject]
}

$requiredFiles = @(
    "README.md",
    "project.godot",
    "export_presets.cfg",
    "scenes/main.tscn",
    "scripts/core/run_state.gd",
    "scripts/core/environment_instance.gd",
    "scripts/core/game_module.gd",
    "scripts/core/item_effect.gd",
    "scripts/core/event_module.gd",
    "scripts/core/platform_services.gd",
    "scripts/core/profile_inventory.gd",
    "scripts/core/attribute_badges.gd",
    "scripts/core/content_library.gd",
    "scripts/core/scenario_sequence_catalog.gd",
    "scripts/core/scenario_sequence_schema.gd",
    "scripts/core/scenario_sequence_runtime.gd",
    "scripts/core/scenario_operation_registry.gd",
    "scripts/core/character_roster.gd",
    "scripts/core/crew_state_model.gd",
    "scripts/core/crew_recruitment_model.gd",
    "scripts/core/crew_heist_model.gd",
    "scripts/core/rng_stream.gd",
    "scripts/core/run_generator.gd",
    "scripts/core/save_service.gd",
    "scripts/ui/foundation_main.gd",
    "scripts/ui/attribute_badge_row.gd",
    "scripts/ui/visual_style.gd",
    "scripts/tests/foundation/check_lenders_release_saves.gd",
    "scripts/tests/foundation/interactable_event_class_guard.gd",
    "scripts/tests/foundation/crew_recruitment_contract.gd",
    "scripts/tests/foundation/crew_layer3_jobs_contract.gd",
    "scripts/tests/foundation/crew_plays_contract.gd",
    "scripts/tests/foundation/crew_heist_contract.gd",
    "scripts/tests/foundation/crew_turn_contract.gd",
    "scripts/tests/foundation/character_chains_contract.gd",
    "scripts/tests/foundation/content_depth_contract.gd",
    "scripts/tests/foundation/scenario_sequence_contract.gd",
    "scripts/tests/foundation/crew_ignored_golden_probe.gd",
    "scripts/tests/fixtures/crew06_5_ignored_run_baseline.json",
    "scripts/tests/foundation/check_scratch_tickets.gd",
    "scripts/tests/ui_scene/compile_run_menu_and_game_flows.gd",
    "tools/check_godot.ps1",
    "tools/split_test_runner_helpers.ps1",
    "tools/function_census.ps1",
    "tools/gdscript_load_check.gd",
    "tools/foundation_visual_qa.ps1",
    "tools/foundation_visual_qa.gd",
    "tools/scenario_sequence_audit.ps1",
    "tools/scenario_sequence_audit.gd",
    "tools/scenario_sequence_probe_support.gd",
    "tools/scenario_sequence_probe_main.gd",
    "tools/scenario_sequence_probe_main.tscn",
    "tools/scenario_sequence_visual_capture.ps1",
    "tools/scenario_sequence_web_capture.mjs",
    "tools/scenario_sequence_parity_performance.ps1",
    "data/art/art_manifest.json",
    "data/art/attribute_glyphs.json",
    "data/environments/archetypes.json",
    "data/environments/scenario_sequences/env06_7_shops_streets.json",
    "data/items/items.json",
    "data/events/events.json",
    "data/characters/characters.json",
    "data/characters/pools.json",
    "data/games/games.json",
    "data/games/scratch_tickets.json",
    "data/debt/lenders.json",
    "data/crew/crew.json",
    "data/crew/recruitment.json",
    "data/crew/jobs.json",
    "data/crew/plays.json",
    "data/crew/heist.json",
    "data/services/services.json",
    "data/travel/routes.json",
    "scripts/games/slot.gd",
    "scripts/games/pull_tabs.gd",
    "scripts/games/scratch_tickets.gd",
    "scripts/games/bar_dice.gd",
    "scripts/games/blackjack.gd",
    "scripts/games/video_poker.gd",
    "assets/art/environments/corner_store.png",
    "assets/art/environments/back_alley.png",
    "assets/art/environments/motel.png",
    "assets/art/environments/bar.png",
    "assets/art/environments/jazz_club.png",
    "assets/art/environments/gas_station_casino.png",
    "assets/art/environments/small_underground_casino.png",
    "assets/art/environments/grand_casino.png",
    "assets/art/game_scenes/slot.png",
    "assets/art/game_scenes/pull_tabs.png",
    "assets/art/game_scenes/bar_dice.png",
    "assets/art/game_scenes/blackjack.png",
    "assets/art/game_scenes/video_poker.png",
    "assets/art/game_scenes/poker.png"
)

$failures = New-Object System.Collections.Generic.List[string]

$objectRootContractFixtures = @(
    @{ Label = "object"; Value = ('{"fixture":true}' | ConvertFrom-Json); Expected = $true },
    @{ Label = "array"; Value = ('[1,2]' | ConvertFrom-Json); Expected = $false },
    @{ Label = "null"; Value = ('null' | ConvertFrom-Json); Expected = $false },
    @{ Label = "string"; Value = ('"fixture"' | ConvertFrom-Json); Expected = $false },
    @{ Label = "number"; Value = ('7' | ConvertFrom-Json); Expected = $false },
    @{ Label = "boolean"; Value = ('true' | ConvertFrom-Json); Expected = $false }
)
foreach ($fixture in $objectRootContractFixtures) {
    if ((Test-JsonObjectRoot $fixture.Value) -ne $fixture.Expected) {
        $failures.Add("JSON object-root classifier contract failed for $($fixture.Label).")
    }
}

foreach ($relative in $requiredFiles) {
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("Missing required file: $relative")
    }
}

$scenarioAuditSource = Get-Content -LiteralPath (Join-Path $root "tools/scenario_sequence_audit.gd") -Raw
if ($scenarioAuditSource -match 'definitions\.size\(\)\s*==\s*1') {
    $failures.Add("Scenario sequence audit must not require a singleton catalog for hostile fixtures.")
}
foreach ($requiredAuditSeam in @(
    'HOSTILE_FIXTURE_SCENARIO_ID := "corner_store_delivery_day"',
    'static func hostile_fixture_report_for_definitions',
    'static func report_has_exact_shape'
)) {
    if (-not $scenarioAuditSource.Contains($requiredAuditSeam)) {
        $failures.Add("Scenario sequence audit is missing rollout seam: $requiredAuditSeam")
    }
}
$scenarioContractSource = Get-Content -LiteralPath (Join-Path $root "scripts/tests/foundation/scenario_sequence_contract.gd") -Raw
foreach ($requiredGrowthProbe in @(
    'for rollout_count_value in [13, 55]',
	'hostile_fixture_report_for_definitions(reversed_definitions)',
	'package_for_scenario(DELIVERY_SCENARIO_ID, expanded_catalog)',
	'"label": "unsupported_choice"',
	'base_collision_result',
	'broad_only_event_bridge'
)) {
    if (-not $scenarioContractSource.Contains($requiredGrowthProbe)) {
        $failures.Add("Scenario sequence contract is missing growth/authority probe: $requiredGrowthProbe")
    }
}
$scenarioEvidenceFiles = @(
    "tools/scenario_sequence_probe_support.gd",
    "tools/scenario_sequence_probe_main.gd",
    "tools/scenario_sequence_probe_main.tscn",
    "tools/scenario_sequence_visual_capture.ps1",
    "tools/scenario_sequence_web_capture.mjs",
    "tools/scenario_sequence_parity_performance.ps1"
)
foreach ($relative in $scenarioEvidenceFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)) {
        $failures.Add("Executable scenario evidence file is missing: $relative")
    }
}
foreach ($relative in @("tools/scenario_sequence_visual_capture.ps1", "tools/scenario_sequence_parity_performance.ps1")) {
    $parseTokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $relative), [ref]$parseTokens, [ref]$parseErrors)
    foreach ($parseError in @($parseErrors)) {
        $failures.Add("Executable scenario evidence PowerShell syntax error in $relative`: $($parseError.Message)")
    }
}
$scenarioProbeSupportSource = Get-Content -LiteralPath (Join-Path $root "tools/scenario_sequence_probe_support.gd") -Raw
$scenarioProbeMainSource = Get-Content -LiteralPath (Join-Path $root "tools/scenario_sequence_probe_main.gd") -Raw
$scenarioProbeSceneSource = Get-Content -LiteralPath (Join-Path $root "tools/scenario_sequence_probe_main.tscn") -Raw
$scenarioVisualWrapperSource = Get-Content -LiteralPath (Join-Path $root "tools/scenario_sequence_visual_capture.ps1") -Raw
$scenarioWebCaptureSource = Get-Content -LiteralPath (Join-Path $root "tools/scenario_sequence_web_capture.mjs") -Raw
$scenarioParityWrapperSource = Get-Content -LiteralPath (Join-Path $root "tools/scenario_sequence_parity_performance.ps1") -Raw
foreach ($requiredEvidenceSeam in @(
    'PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_shops_streets.json"',
    'SCENARIO_ID := "corner_store_delivery_day"',
    'PROOF_SEED := "corner_store_delivery_day_env06_6"',
    'static func canonical_semantic_sha256',
    'static func validate_probe_report',
    'static func validate_capture_manifest',
    'REQUIRED_PERFORMANCE_ROWS'
)) {
    if (-not $scenarioProbeSupportSource.Contains($requiredEvidenceSeam)) {
        $failures.Add("Scenario evidence support is missing fail-closed authority: $requiredEvidenceSeam")
    }
}
foreach ($requiredMainSeam in @(
    'extends Node',
    'res://scenes/main.tscn',
    'start_foundation_run", ProbeSupport.PROOF_SEED, {}, false',
    'current_environment_view_snapshot',
    'activate_interactable_object',
    'global_rect_for_object',
    'object_id_at_local_position',
    'scenario_reenter_current',
    'scenario_apply_expiry',
    'RenderingServer.frame_post_draw',
    'current_environment_result_feedback_snapshot',
    'environment_reserved_global_rect',
    'load_foundation_run',
    'ENV06_6_SEQUENCE_PROBE='
)) {
    if (-not $scenarioProbeMainSource.Contains($requiredMainSeam)) {
        $failures.Add("Scenario evidence main scene is missing production seam: $requiredMainSeam")
    }
}
if ($scenarioProbeMainSource.Contains('scenario_flush_facts') -or $scenarioProbeMainSource.Contains('_interactable_object_view_list')) {
    $failures.Add("Scenario evidence main scene must not manually flush facts or use the private interactable list.")
}
if (-not $scenarioProbeSceneSource.Contains('type="Node"') -or -not $scenarioProbeSceneSource.Contains('scenario_sequence_probe_main.gd')) {
    $failures.Add("Scenario evidence entry scene must attach the Node-backed probe script.")
}
if ($scenarioVisualWrapperSource.Contains('"--headless"') -or -not $scenarioVisualWrapperSource.Contains('scenario_sequence_probe_main.tscn') -or -not $scenarioVisualWrapperSource.Contains('Get-FileHash') -or -not $scenarioVisualWrapperSource.Contains('BTH_DISTRIBUTION_DATA_ROOT')) {
    $failures.Add("Scenario visual wrapper must be direct, windowed, isolated, and byte-hash fail-closed.")
}
foreach ($requiredWebSeam in @('launchPersistentContext', 'Emulation.setCPUThrottlingRate', 'pageerror', 'requestfailed', 'ENV06_6_SEQUENCE_PROBE=')) {
    if (-not $scenarioWebCaptureSource.Contains($requiredWebSeam)) {
        $failures.Add("Scenario Web capture is missing fail-closed browser seam: $requiredWebSeam")
    }
}
foreach ($requiredParitySeam in @(
    'native_process_1', 'native_process_2', 'web_process_1', 'web_process_2', 'native_web_semantic_exact',
    'transientAddon', 'BTH_DISTRIBUTION_DATA_ROOT', 'run_transient_scons.py',
    'Copy-Item -LiteralPath $canonicalAddon', 'Required Windows host library is unavailable',
    'Get-ChildItem -LiteralPath (Join-Path $transientAddon "bin") -Filter "*.wasm"'
)) {
    if (-not $scenarioParityWrapperSource.Contains($requiredParitySeam)) {
        $failures.Add("Scenario parity/performance wrapper is missing acceptance seam: $requiredParitySeam")
    }
}
if ($scenarioParityWrapperSource.Contains('tools\build_native_solver.ps1') -or $scenarioParityWrapperSource.Contains('Join-Path $root "addons"')) {
    $failures.Add("Scenario parity/performance Web build must keep compiler outputs inside its ignored OutDir.")
}
$scenarioPresentationSource = Get-Content -LiteralPath (Join-Path $root "scripts/tests/foundation/scenario_presentation_contract.gd") -Raw
foreach ($requiredOverlayProbe in @('collision_overlay', 'z_equal_augment', 'sweep_unique')) {
    if (-not $scenarioPresentationSource.Contains($requiredOverlayProbe)) {
        $failures.Add("Scenario presentation contract is missing collision probe: $requiredOverlayProbe")
    }
}

$assetDimensions = @{
    "assets/art/environments/corner_store.png" = @(900, 430)
    "assets/art/environments/back_alley.png" = @(900, 430)
    "assets/art/environments/motel.png" = @(900, 430)
    "assets/art/environments/bar.png" = @(900, 430)
    "assets/art/environments/jazz_club.png" = @(900, 430)
    "assets/art/environments/gas_station_casino.png" = @(900, 430)
    "assets/art/environments/small_underground_casino.png" = @(900, 430)
    "assets/art/environments/grand_casino.png" = @(900, 430)
    "assets/art/game_scenes/slot.png" = @(900, 430)
    "assets/art/game_scenes/pull_tabs.png" = @(900, 430)
    "assets/art/game_scenes/bar_dice.png" = @(900, 430)
    "assets/art/game_scenes/blackjack.png" = @(900, 430)
    "assets/art/game_scenes/video_poker.png" = @(900, 430)
    "assets/art/game_scenes/poker.png" = @(900, 430)
}

$iconFolders = @("assets/art/items", "assets/art/events", "assets/art/games", "assets/art/ui")
foreach ($folder in $iconFolders) {
    $iconRoot = Join-Path $root $folder
    if (Test-Path -LiteralPath $iconRoot) {
        foreach ($iconFile in Get-ChildItem -LiteralPath $iconRoot -Filter "*.png" -File) {
            $relativeIcon = Get-ProjectRelativePath $iconFile.FullName
            $assetDimensions[$relativeIcon] = @(32, 32)
        }
    }
}

# These are scalable menu surfaces stored beside the 32x32 UI icons. Keep
# their authored source dimensions explicit so the generic icon contract does
# not misclassify them as HUD glyphs.
$assetDimensions["assets/art/ui/beat_the_house_logo.png"] = @(1141, 440)
$assetDimensions["assets/art/ui/main_menu_button_plate.png"] = @(384, 192)

foreach ($entry in $assetDimensions.GetEnumerator()) {
    $path = Join-Path $root $entry.Key
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("Missing required art asset: $($entry.Key)")
        continue
    }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    if ($bytes.Length -lt 24 -or $bytes[0] -ne 0x89 -or $bytes[1] -ne 0x50 -or $bytes[2] -ne 0x4e -or $bytes[3] -ne 0x47) {
        $failures.Add("Art asset is not a readable PNG: $($entry.Key)")
        continue
    }
    $width = [BitConverter]::ToUInt32(([byte[]]($bytes[19], $bytes[18], $bytes[17], $bytes[16])), 0)
    $height = [BitConverter]::ToUInt32(([byte[]]($bytes[23], $bytes[22], $bytes[21], $bytes[20])), 0)
    $expected = $entry.Value
    if ($width -ne $expected[0] -or $height -ne $expected[1]) {
        $failures.Add("Art asset has wrong dimensions: $($entry.Key) is ${width}x${height}, expected $($expected[0])x$($expected[1])")
    }
}

$objectJsonFiles = @(
    "data/art/art_manifest.json",
    "data/art/attribute_glyphs.json",
    "data/games/scratch_ticket_regions.json",
    "data/environments/scenarios.json",
    "data/story/character_chains.json"
)
$objectJsonDirectories = @(
    "data/environments/scenario_sequences/"
)

$jsonFiles = Get-ChildItem -LiteralPath (Join-Path $root "data") -Filter "*.json" -File -Recurse -ErrorAction SilentlyContinue

foreach ($jsonFile in $jsonFiles) {
    try {
        $content = Get-Content -LiteralPath $jsonFile.FullName -Raw
        $parsed = $content | ConvertFrom-Json
        if ($null -eq $parsed) {
            $failures.Add("JSON file parsed to null: $($jsonFile.FullName)")
        }
        $relativeJson = Get-ProjectRelativePath $jsonFile.FullName
        $requiresObject = $objectJsonFiles -contains $relativeJson
        foreach ($directory in $objectJsonDirectories) {
            if ($relativeJson.StartsWith($directory, [System.StringComparison]::OrdinalIgnoreCase)) {
                $requiresObject = $true
                break
            }
        }
        if ($requiresObject) {
            if (-not (Test-JsonObjectRoot $parsed)) {
                $failures.Add("JSON file must contain an object: $($jsonFile.FullName)")
            }
        }
        elseif ($parsed -isnot [System.Array]) {
            $failures.Add("JSON file must contain an array: $($jsonFile.FullName)")
        }
    }
    catch {
        $failures.Add("Invalid JSON in $($jsonFile.FullName): $($_.Exception.Message)")
    }
}

$readme = Get-Content -LiteralPath (Join-Path $root "README.md") -Raw
$mojibakeMarkers = @(
    [string][char]0x00E2,
    [string][char]0xFFFD,
    [string][char]0x20AC
)
foreach ($marker in $mojibakeMarkers) {
    if ($readme.Contains($marker)) {
        $failures.Add("README still contains broken character marker with code point U+$('{0:X4}' -f [int][char]$marker)")
    }
}

$expectedClasses = @{
    "scripts/core/run_state.gd" = "class_name RunState"
    "scripts/core/environment_instance.gd" = "class_name EnvironmentInstance"
    "scripts/core/game_module.gd" = "class_name GameModule"
    "scripts/core/item_effect.gd" = "class_name ItemEffect"
    "scripts/core/event_module.gd" = "class_name EventModule"
    "scripts/core/platform_services.gd" = "class_name PlatformServices"
    "scripts/core/profile_inventory.gd" = "class_name ProfileInventory"
    "scripts/core/content_library.gd" = "class_name ContentLibrary"
    "scripts/core/scenario_engine.gd" = "class_name ScenarioEngine"
    "scripts/core/crew_recruitment_model.gd" = "class_name CrewRecruitmentModel"
    "scripts/core/rng_stream.gd" = "class_name RngStream"
    "scripts/core/run_generator.gd" = "class_name RunGenerator"
    "scripts/core/save_service.gd" = "class_name SaveService"
}

foreach ($entry in $expectedClasses.GetEnumerator()) {
    $path = Join-Path $root $entry.Key
    if (Test-Path -LiteralPath $path) {
        $content = Get-Content -LiteralPath $path -Raw
        if (-not $content.Contains($entry.Value)) {
            $failures.Add("Expected $($entry.Value) in $($entry.Key)")
        }
    }
}

$exportPresets = Get-Content -LiteralPath (Join-Path $root "export_presets.cfg") -Raw
$windowsPresetPattern = '(?s)name="Windows Steam".*?\[preset\.0\.options\].*?binary_format/embed_pck=true'
if ($exportPresets -notmatch $windowsPresetPattern) {
    $failures.Add("Windows Steam export must embed its PCK so BeatTheHouse.exe is standalone.")
}

$authoredMusicRoot = Join-Path $root "assets/audio/music"
foreach ($wavFile in Get-ChildItem -LiteralPath $authoredMusicRoot -Filter "*.wav" -File -Recurse -ErrorAction SilentlyContinue) {
    $importPath = "$($wavFile.FullName).import"
    if (-not (Test-Path -LiteralPath $importPath)) {
        $failures.Add("Authored music source is missing its portable Keep File import contract: $(Get-ProjectRelativePath $wavFile.FullName)")
        continue
    }
    $importContent = Get-Content -LiteralPath $importPath -Raw
    if ($importContent -notmatch '(?m)^importer="keep"\s*$') {
        $failures.Add("Authored music source must use Keep File for exact runtime PCM decoding: $(Get-ProjectRelativePath $wavFile.FullName)")
    }
}

$trackedGeneratedFiles = @()
try {
    $trackedGeneratedFiles = @(git -C $root ls-files "*.import" "*.uid" 2>$null)
}
catch {
    $failures.Add("Could not inspect git-tracked generated files: $($_.Exception.Message)")
}
foreach ($trackedGeneratedFile in $trackedGeneratedFiles) {
    $relativeGeneratedPath = ([string]$trackedGeneratedFile).Trim()
    $isAuthoredMusicKeepContract = $relativeGeneratedPath -match '^assets/audio/music/.+\.wav\.import$'
    if (-not [string]::IsNullOrWhiteSpace($relativeGeneratedPath) -and -not $isAuthoredMusicKeepContract) {
        $failures.Add("Generated Godot metadata must not be git-tracked: $relativeGeneratedPath")
    }
}

try {
    $censusScript = Join-Path $root "tools/function_census.ps1"
    if (Test-Path -LiteralPath $censusScript) {
        $censusOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $censusScript -Check -Quiet 2>&1
        $censusExitCode = $LASTEXITCODE
        if ($censusExitCode -ne 0) {
            $message = ($censusOutput | ForEach-Object { [string]$_ }) -join " "
            if ([string]::IsNullOrWhiteSpace($message)) {
                $message = "tools/function_census.ps1 exited with code $censusExitCode."
            }
            $failures.Add("Function census generation failed: $message")
        }
    }
}
catch {
    $failures.Add("Function census generation failed: $($_.Exception.Message)")
}

function Get-ProjectText {
    param([string]$RelativePath)
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        return ""
    }
    return Get-Content -LiteralPath $path -Raw
}

function Require-Text {
    param([string]$RelativePath, [string]$Needle, [string]$Message)
    $content = Get-ProjectText $RelativePath
    if (-not $content.Contains($Needle)) {
        $failures.Add($Message)
    }
}

function Require-TextInAny {
    param([string[]]$RelativePaths, [string]$Needle, [string]$Message)
    foreach ($relativePath in $RelativePaths) {
        $content = Get-ProjectText $relativePath
        if ($content.Contains($Needle)) {
            return
        }
    }
    $failures.Add($Message)
}

function Forbid-Text {
    param([string]$RelativePath, [string]$Needle, [string]$Message)
    $content = Get-ProjectText $RelativePath
    if ($content.Contains($Needle)) {
        $failures.Add($Message)
    }
}

function Read-JsonArray {
    param([string]$RelativePath)
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        return @()
    }
    try {
        $parsed = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        if ($parsed -is [System.Array]) {
            return @($parsed)
        }
        return @($parsed)
    }
    catch {
        return @()
    }
}

function Get-JsonProperty {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    if ($property.Value -is [System.Array]) {
        return ,$property.Value
    }
    return $property.Value
}

function Test-JsonProperty {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object) {
        return $false
    }
    return $null -ne $Object.PSObject.Properties[$Name]
}

function New-ContentIdSet {
    param([string]$RelativePath)
    $ids = @{}
    foreach ($entry in (Read-JsonArray $RelativePath)) {
        $id = [string](Get-JsonProperty $entry "id")
        if (-not [string]::IsNullOrWhiteSpace($id)) {
            $ids[$id] = $true
        }
    }
    return $ids
}

function Assert-JsonRequiredFields {
    param([string]$RelativePath, [string]$Label, [string[]]$Fields)
    $entries = Read-JsonArray $RelativePath
    for ($index = 0; $index -lt $entries.Count; $index++) {
        $entry = $entries[$index]
        $id = [string](Get-JsonProperty $entry "id")
        if ([string]::IsNullOrWhiteSpace($id)) {
            $failures.Add("$Label[$index] is missing required id.")
        }
        foreach ($field in $Fields) {
            if (-not (Test-JsonProperty $entry $field)) {
                $name = if ([string]::IsNullOrWhiteSpace($id)) { "[$index]" } else { $id }
                $failures.Add("$Label $name is missing required field: $field")
            }
        }
    }
}

function Assert-JsonUniqueIds {
    param([string]$RelativePath, [string]$Label)
    $seen = @{}
    $entries = Read-JsonArray $RelativePath
    for ($index = 0; $index -lt $entries.Count; $index++) {
        $id = [string](Get-JsonProperty $entries[$index] "id")
        if ([string]::IsNullOrWhiteSpace($id)) {
            continue
        }
        if ($seen.ContainsKey($id)) {
            $failures.Add("$Label contains duplicate id: $id")
        }
        else {
            $seen[$id] = $true
        }
    }
}

function Assert-IdArrayReferences {
    param([string]$Label, [object]$Values, [hashtable]$ValidIds)
    if ($null -eq $Values) {
        return
    }
    $normalizedValues = if ($Values -is [System.Array]) { @($Values) } else { @($Values) }
    foreach ($value in $normalizedValues) {
        $id = [string]$value
        if ([string]::IsNullOrWhiteSpace($id)) {
            $failures.Add("$Label contains an empty id.")
        }
        elseif (-not $ValidIds.ContainsKey($id)) {
            $failures.Add("$Label references unknown id: $id")
        }
    }
}

function ConvertTo-ValueArray {
    param([object]$Value)
    if ($null -eq $Value) {
        return @()
    }
    if ($Value -is [System.Array]) {
        return @($Value)
    }
    return @($Value)
}

function Assert-DeltaKeys {
    param([string]$Label, [object]$Delta, [string[]]$AllowedKeys)
    if ($null -eq $Delta) {
        return
    }
    if ($Delta -isnot [pscustomobject]) {
        $failures.Add("$Label must be an object when present.")
        return
    }
    foreach ($property in $Delta.PSObject.Properties) {
        if ($AllowedKeys -notcontains $property.Name) {
            $failures.Add("$Label uses unsupported result key: $($property.Name)")
        }
    }
}

function Assert-NonNegativeIntProperty {
    param([string]$Label, [object]$Object, [string]$PropertyName)
    if (-not (Test-JsonProperty $Object $PropertyName)) {
        return
    }
    try {
        $value = [int](Get-JsonProperty $Object $PropertyName)
        if ($value -lt 0) {
            $failures.Add("$Label $PropertyName must be non-negative.")
        }
    }
    catch {
        $failures.Add("$Label $PropertyName must be an integer.")
    }
}

function Assert-ArtAssetPath {
    param([string]$Label, [object]$Object)
    $assetPath = [string](Get-JsonProperty $Object "asset_path")
    if ([string]::IsNullOrWhiteSpace($assetPath)) {
        $failures.Add("$Label must define asset_path for replaceable object art.")
        return
    }
    if (-not $assetPath.StartsWith("res://assets/art/")) {
        $failures.Add("$Label asset_path must stay under res://assets/art/: $assetPath")
        return
    }
    $relativeAssetPath = $assetPath.Substring(6).Replace("/", "\")
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativeAssetPath))) {
        $failures.Add("$Label references missing asset_path: $assetPath")
    }
}

function Assert-EnvironmentLayoutSpots {
    param([string]$ArchetypeId, [object]$Layout)
    if ($null -eq $Layout) {
        return
    }
    if ($Layout -isnot [pscustomobject]) {
        $failures.Add("environment $ArchetypeId layout must be an object when present.")
        return
    }
    $spotFields = @("game_spots", "event_spots", "item_spots", "shopkeeper_spots", "travel_spots", "service_spots", "lender_spots", "numbers_spots", "numbers_silas_spots")
    foreach ($field in $spotFields) {
        $spots = Get-JsonProperty $Layout $field
        if ($null -eq $spots) {
            continue
        }
        if ($spots -isnot [array]) {
            $failures.Add("environment $ArchetypeId layout.$field must be an array of [x, y] board coordinates.")
            continue
        }
        $spotList = @($spots)
        if ($spotList.Count -ge 2 -and $spotList[0] -isnot [array] -and $spotList[0] -isnot [pscustomobject] -and $spotList[1] -isnot [array] -and $spotList[1] -isnot [pscustomobject]) {
            $spotList = @(, @($spotList[0], $spotList[1]))
        }
        for ($i = 0; $i -lt $spotList.Count; $i++) {
            $spot = $spotList[$i]
            $x = $null
            $y = $null
            if ($spot -is [array] -and $spot.Count -ge 2) {
                $x = $spot[0]
                $y = $spot[1]
            }
            elseif ($spot -is [pscustomobject]) {
                $x = Get-JsonProperty $spot "x"
                $y = Get-JsonProperty $spot "y"
            }
            else {
                $failures.Add("environment $ArchetypeId layout.$field[$i] must be [x, y] or an object with x/y.")
                continue
            }
            try {
                $xi = [int]$x
                $yi = [int]$y
                if ($xi -lt 0 -or $xi -gt 900 -or $yi -lt 0 -or $yi -gt 430) {
                    $failures.Add("environment $ArchetypeId layout.$field[$i] must stay within the 900x430 board.")
                }
            }
            catch {
                $failures.Add("environment $ArchetypeId layout.$field[$i] must use numeric x/y coordinates.")
            }
        }
    }
}

$deprecatedDemoFiles = @(
    "scripts/ui/main.gd",
    "scripts/core/runtime_content.gd",
    "scripts/core/game_ui_module.gd",
    "scripts/games/bar_dice_ui.gd",
    "scripts/games/blackjack_ui.gd",
    "scripts/games/last_chance_ui.gd",
    "scripts/games/poker_ui.gd",
    "scripts/games/pull_tabs_ui.gd",
    "scripts/games/scratch_tickets_ui.gd",
    "scripts/games/slots_ui.gd",
    "scripts/games/street_dice_ui.gd",
    "scripts/games/three_card_monte_ui.gd",
    "scripts/games/video_poker_ui.gd",
    "data/runtime/core_content.json",
    "data/runtime/environment_slots.json",
    "data/runtime/icon_sprites.json",
    "tools/capture_environment_screens.gd",
    "tools/capture_game_screens.gd",
    "tools/export_runtime_content.gd",
    "tools/generate_pixel_art.gd",
    "tools/playtest_30_victories.gd",
    "tools/playtest_demo.gd",
    "docs/RUNTIME_CONTENT.md"
)
foreach ($relativeDemoPath in $deprecatedDemoFiles) {
    if (Test-Path -LiteralPath (Join-Path $root $relativeDemoPath)) {
        $failures.Add("Deprecated demo runtime file remains in the production path: $relativeDemoPath")
    }
}

$mainSceneText = Get-ProjectText "scenes/main.tscn"
if (-not $mainSceneText.Contains('path="res://scripts/ui/foundation_main.gd"')) {
    $failures.Add("Active main scene is not wired to the foundation UI shell.")
}
if ($mainSceneText.Contains('path="res://scripts/ui/main.gd"')) {
    $failures.Add("Active main scene is still wired to the demo runtime main.gd.")
}

$foundationUi = "scripts/ui/foundation_main.gd"
Require-Text $foundationUi "ContentLibrary.new()" "Foundation UI shell must load content through ContentLibrary."
Require-Text $foundationUi "RunState.new()" "Foundation UI shell must own runs through RunState."
Require-Text $foundationUi "RunGenerator.new(library)" "Foundation UI shell must generate environments through RunGenerator."
Require-Text $foundationUi "GameModule" "Foundation UI shell must route gameplay through GameModule."
Require-Text $foundationUi "RunActionServiceScript.new()" "Foundation UI shell must route item/hook actions through RunActionService."
Require-Text "scripts/core/run_action_service.gd" "ItemEffectScript.new()" "RunActionService must route item effects through ItemEffect."
Require-Text $foundationUi "EventModule.new()" "Foundation UI shell must route events through EventModule."
Require-Text $foundationUi "save_service.save_run" "Foundation UI shell must save runs through SaveService."
Require-Text $foundationUi "save_service.load_run" "Foundation UI shell must load runs through SaveService."
Require-Text $foundationUi "PlatformServices.new()" "Foundation UI shell must keep platform calls behind PlatformServices."
Require-Text $foundationUi "run_state.create_rng()" "Foundation UI shell must resolve simulation through RunState/RngStream."
Forbid-Text $foundationUi "RuntimeContent" "Foundation UI shell must not depend on RuntimeContent."
Forbid-Text $foundationUi "GameUiModule" "Foundation UI shell must not instantiate GameUiModule."
Forbid-Text $foundationUi "core_content.json" "Foundation UI shell must not depend on data/runtime/core_content.json."
Forbid-Text $foundationUi 'preload("res://data/runtime' "Foundation UI shell must not load data/runtime paths."
Forbid-Text $foundationUi 'load("res://data/runtime' "Foundation UI shell must not load data/runtime paths."

$contentLibrary = "scripts/core/content_library.gd"
$requiredPackStrings = @(
    "res://data/environments/archetypes.json",
    "res://data/games/games.json",
    "res://data/items/items.json",
    "res://data/events/events.json",
    "res://data/characters/characters.json",
    "res://data/characters/pools.json",
    "res://data/challenges/challenges.json",
    "res://data/debt/lenders.json",
    "res://data/services/services.json",
    "res://data/travel/routes.json"
)
foreach ($packPath in $requiredPackStrings) {
    Require-Text $contentLibrary $packPath "ContentLibrary is missing README data pack path: $packPath"
}
Forbid-Text $contentLibrary "RuntimeContent" "ContentLibrary must not use RuntimeContent as a foundation loader."
Forbid-Text $contentLibrary "core_content.json" "ContentLibrary must not load data/runtime/core_content.json."
Forbid-Text $contentLibrary "res://data/runtime" "ContentLibrary must not load data/runtime paths."

$foundationTestFiles = @()
$foundationTestFiles += @(Get-ChildItem -LiteralPath (Join-Path $root "scripts/tests/foundation") -Filter "*.gd" | ForEach-Object { Get-ProjectRelativePath $_.FullName })
$foundationTestFiles += @(Get-ChildItem -LiteralPath (Join-Path $root "scripts/tests/ui_scene") -Filter "*.gd" | ForEach-Object { Get-ProjectRelativePath $_.FullName })
$foundationCheckFiles = @(Get-ChildItem -LiteralPath (Join-Path $root "scripts/tests/foundation") -Filter "*.gd" | ForEach-Object { Get-ProjectRelativePath $_.FullName })
$uiSceneCheckFiles = @(Get-ChildItem -LiteralPath (Join-Path $root "scripts/tests/ui_scene") -Filter "*.gd" | ForEach-Object { Get-ProjectRelativePath $_.FullName })

# Game surface modules render against the real canvas in production and the
# compact SurfaceHarness in Foundation checks. Keep every directly reachable
# surface/draw call represented in the harness so production API growth cannot
# turn a Contract run into a late RefCounted method-not-found failure.
$surfaceHarnessPath = Join-Path $root "scripts/tests/foundation/check_core_content.gd"
$surfaceHarnessSource = [System.IO.File]::ReadAllText($surfaceHarnessPath)
$surfaceHarnessBlock = [regex]::Match($surfaceHarnessSource, '(?ms)^class SurfaceHarness:\r?\n(?<body>.*?)(?=^[^\t\r\n])')
if (-not $surfaceHarnessBlock.Success) {
    $failures.Add("Could not locate the Foundation SurfaceHarness class body.")
} else {
    $surfaceHarnessMethods = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    foreach ($methodMatch in [regex]::Matches($surfaceHarnessBlock.Groups['body'].Value, '(?m)^\tfunc\s+([A-Za-z0-9_]+)\s*\(')) {
        [void]$surfaceHarnessMethods.Add($methodMatch.Groups[1].Value)
    }
    $requiredSurfaceMethods = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.HashSet[string]]' ([System.StringComparer]::Ordinal)
    $directSurfaceCallPattern = [regex]'\bsurface\s*\.\s*((?:surface|draw)_[A-Za-z0-9_]+)\s*\('
    $dynamicSurfaceCallPattern = [regex]'\bsurface\s*\.\s*(?:call|has_method)\s*\(\s*["''](surface_[A-Za-z0-9_]+)["'']'
    foreach ($gameScript in Get-ChildItem -LiteralPath (Join-Path $root "scripts/games") -Filter "*.gd" -File -Recurse) {
        $gameSource = [System.IO.File]::ReadAllText($gameScript.FullName)
        foreach ($callMatch in @($directSurfaceCallPattern.Matches($gameSource)) + @($dynamicSurfaceCallPattern.Matches($gameSource))) {
            $methodName = $callMatch.Groups[1].Value
            if (-not $requiredSurfaceMethods.ContainsKey($methodName)) {
                $requiredSurfaceMethods[$methodName] = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
            }
            [void]$requiredSurfaceMethods[$methodName].Add((Get-ProjectRelativePath $gameScript.FullName))
        }
    }
    foreach ($methodName in @($requiredSurfaceMethods.Keys | Sort-Object)) {
        if (-not $surfaceHarnessMethods.Contains($methodName)) {
            $sources = @($requiredSurfaceMethods[$methodName] | Sort-Object)
            $failures.Add("SurfaceHarness is missing game-called method $methodName (sources=$($sources -join ', ')).")
        }
    }
    if (-not $surfaceHarnessSource.Contains('surface_add_invisible_hit(rect, action, index, false)')) {
        $failures.Add("SurfaceHarness exact-invisible hits must disable touch-target expansion.")
    }
    if (-not $surfaceHarnessSource.Contains('return hovered_index if hovered_action == action else -1')) {
        $failures.Add("SurfaceHarness hovered-index lookup must mirror GameSurfaceCanvas semantics.")
    }
}
$forbiddenFoundationTestTokens = @(
    "RuntimeContentScript",
    "runtime_content.gd",
    "RuntimeContent.new",
    "GameUiModuleScript",
    "game_ui_module.gd",
    "GameUiModule.new",
    "core_content.json"
)
foreach ($testFile in $foundationTestFiles) {
    foreach ($token in $forbiddenFoundationTestTokens) {
        Forbid-Text $testFile $token "Foundation validation test $testFile must not depend on demo runtime token: $token"
    }
}

Require-TextInAny $foundationCheckFiles "ContentLibraryScript.new()" "Foundation tests must load content through ContentLibrary."
Require-TextInAny $foundationCheckFiles "RunGeneratorScript.new" "Foundation tests must exercise RunGenerator."
Require-TextInAny $foundationCheckFiles "EnvironmentInstance" "Foundation tests must exercise EnvironmentInstance."
Require-TextInAny $foundationCheckFiles "GameModule" "Foundation tests must exercise GameModule."
Require-TextInAny $foundationCheckFiles "ItemEffect.new()" "Foundation tests must exercise ItemEffect."
Require-TextInAny $foundationCheckFiles "EventModule.new()" "Foundation tests must exercise EventModule."
Require-TextInAny $foundationCheckFiles "SaveServiceScript.new()" "Foundation tests must exercise SaveService."
Require-TextInAny $foundationCheckFiles "RngStream.new()" "Foundation tests must exercise RngStream."
Require-TextInAny $foundationCheckFiles "PlatformServicesScript.new()" "Foundation tests must exercise PlatformServices."
Require-TextInAny $uiSceneCheckFiles "res://scenes/main.tscn" "UI scene compile check must instantiate the active main scene."
Require-TextInAny $uiSceneCheckFiles "res://scripts/ui/foundation_main.gd" "UI scene compile check must verify the foundation UI shell."
Require-TextInAny $uiSceneCheckFiles "render_environment_snapshot" "UI scene compile check must verify environment snapshot rendering."
Require-TextInAny $uiSceneCheckFiles "render_game_snapshot" "UI scene compile check must verify game snapshot rendering."
Require-Text "tools/check_godot.ps1" 'Get-FoundationSplitRunnerPath' "Godot check script must assemble the split foundation check runner."
Require-Text "tools/check_godot.ps1" 'scripts/tests/foundation/check_lenders_release_saves.gd' "Godot check script must include the split foundation terminal source."
Require-Text "tools/check_godot.ps1" 'Get-UiSceneSplitRunnerPath' "Godot check script must assemble the split UI scene compile runner."
Require-Text "tools/check_godot.ps1" 'scripts/tests/ui_scene/compile_run_menu_and_game_flows.gd' "Godot check script must include the split UI scene terminal source."
Require-Text "tools/check_godot.ps1" 'Get-SplitTestRunnerLines' "Godot check script must use the marker-aware split runner assembler."
Require-Text "tools/check_godot.ps1" 'ValidateSet("Smoke", "Contract", "Audit", "Full")' "Godot check script must expose suite selection."
Require-Text "tools/check_godot.ps1" 'gdscript_load_check.gd' "Godot check script must run the one-process GDScript load checker."
Require-Text "tools/check_godot.ps1" 'Stop-NewGodotProcesses' "Godot check script must clean up timed-out Godot child processes."
Require-TextInAny $foundationCheckFiles '--suite=' "Foundation check must support suite selection."
Require-TextInAny $foundationCheckFiles 'FOUNDATION_SUITES' "Foundation check must declare available suites."
Require-TextInAny $foundationCheckFiles 'FOUNDATION_DEFAULT_REPORT_PATH' "Foundation check must write a structured report."
Require-Text "tools/gdscript_load_check.gd" 'checked_files' "GDScript load check must report checked files."
Require-Text "tools/gdscript_load_check.gd" 'res://scripts' "GDScript load check must cover live scripts by default."
Require-Text "tools/gdscript_load_check.gd" 'res://tools' "GDScript load check must cover tool scripts by default."

$uiSplitSources = @(
    "scripts/tests/ui_scene/compile_components_and_main_flow.gd",
    "scripts/tests/ui_scene/compile_environment_layout.gd",
    "scripts/tests/ui_scene/compile_run_menu_and_game_flows.gd"
)
$splitBeginMarker = Get-SplitTestRunnerOmitBeginMarker
$splitEndMarker = Get-SplitTestRunnerOmitEndMarker
$parentSplitLines = [System.IO.File]::ReadAllLines((Join-Path $root $uiSplitSources[0]))
$beginMarkerCount = @($parentSplitLines | Where-Object { $_.Trim() -eq $splitBeginMarker }).Count
$endMarkerCount = @($parentSplitLines | Where-Object { $_.Trim() -eq $splitEndMarker }).Count
if ($beginMarkerCount -ne 1 -or $endMarkerCount -ne 1) {
    $failures.Add("UI split parent must contain exactly one balanced descendant-stub marker block.")
}

# Hostile tool fixtures prove the assembler rejects malformed marker structure
# and removes only the explicitly marked span from a multi-source runner.
$hostileMarkedLines = @(
    "func _unmarked_before() -> void:",
    $splitBeginMarker,
    "func _hostile_duplicate_stub() -> void:",
    $splitEndMarker,
    "func _unmarked_after() -> void:"
)
$hostileFilteredLines = @(Remove-SplitTestRunnerOmittedBlocks -Lines $hostileMarkedLines -SourceLabel "hostile balanced fixture" -OmitMarkedBlocks $true)
if (($hostileFilteredLines -join "`n") -ne "func _unmarked_before() -> void:`nfunc _unmarked_after() -> void:") {
    $failures.Add("Split-runner omit markers must remove only marked content and preserve adjacent unmarked lines exactly.")
}
$hostileStandaloneLines = @(Remove-SplitTestRunnerOmittedBlocks -Lines $hostileMarkedLines -SourceLabel "hostile standalone fixture" -OmitMarkedBlocks $false)
if (($hostileStandaloneLines -join "`n") -ne ($hostileMarkedLines -join "`n")) {
    $failures.Add("Single-source split runners must preserve marked standalone fixture stubs byte-for-byte.")
}
$malformedMarkerFixtures = @(
    @($splitBeginMarker, "func _never_closed() -> void:"),
    @($splitEndMarker),
    @($splitBeginMarker, $splitBeginMarker, $splitEndMarker, $splitEndMarker)
)
foreach ($fixture in $malformedMarkerFixtures) {
    $rejected = $false
    try {
        [void](Remove-SplitTestRunnerOmittedBlocks -Lines $fixture -SourceLabel "hostile malformed fixture" -OmitMarkedBlocks $true)
    }
    catch {
        $rejected = $true
    }
    if (-not $rejected) {
        $failures.Add("Split-runner assembler must reject unbalanced or nested omit markers.")
    }
}

$generatedUiLines = @()
try {
    $generatedUiLines = @(Get-SplitTestRunnerLines -ProjectRoot $root -SourceRelativePaths $uiSplitSources)
}
catch {
    $failures.Add("Could not assemble marker-aware UI split runner: $($_.Exception.Message)")
}
$generatedUiFunctionNames = @($generatedUiLines | ForEach-Object {
    if ($_ -match '^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(') {
        $Matches[1]
    }
})
$descendantFunctionNames = @($uiSplitSources[1..($uiSplitSources.Count - 1)] | ForEach-Object {
    [System.IO.File]::ReadAllLines((Join-Path $root $_)) | ForEach-Object {
        if ($_ -match '^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(') {
            $Matches[1]
        }
    }
})
foreach ($functionName in ($descendantFunctionNames | Sort-Object -Unique)) {
    $generatedCount = @($generatedUiFunctionNames | Where-Object { $_ -eq $functionName }).Count
    if ($generatedCount -ne 1) {
        $failures.Add("Generated UI split runner must contain descendant function $functionName exactly once; found $generatedCount.")
    }
}

$insideStubBlock = $false
$stubFunctionNames = New-Object System.Collections.Generic.List[string]
$stubCallNames = New-Object System.Collections.Generic.List[string]
$stubBlockHasUnexpectedContent = $false
foreach ($line in $parentSplitLines) {
    if ($line.Trim() -eq $splitBeginMarker) {
        $insideStubBlock = $true
        continue
    }
    if ($line.Trim() -eq $splitEndMarker) {
        $insideStubBlock = $false
        continue
    }
    if (-not $insideStubBlock) {
        continue
    }
    $trimmedStubLine = $line.Trim()
    if (-not [string]::IsNullOrWhiteSpace($trimmedStubLine) -and
        $trimmedStubLine -notmatch '^func\s+' -and
        $trimmedStubLine -notmatch '^_missing_descendant_fixture\(' -and
        $trimmedStubLine -notmatch '^return\s+') {
        $stubBlockHasUnexpectedContent = $true
    }
    if ($line -match '^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(') {
        $stubFunctionNames.Add($Matches[1])
    }
    if ($line -match '_missing_descendant_fixture\("([A-Za-z_][A-Za-z0-9_]*)"\)') {
        $stubCallNames.Add($Matches[1])
    }
}
if (($stubFunctionNames -join "`n") -ne ($stubCallNames -join "`n") -or $stubFunctionNames.Count -eq 0 -or $stubBlockHasUnexpectedContent) {
    $failures.Add("UI split omit block may contain only declared descendant-fixture stubs with matching guards.")
}
foreach ($functionName in $stubFunctionNames) {
    $descendantCount = @($descendantFunctionNames | Where-Object { $_ -eq $functionName }).Count
    if ($descendantCount -ne 1) {
        $failures.Add("Omitted UI parent stub $functionName must have exactly one descendant implementation; found $descendantCount.")
    }
}
if (@($generatedUiLines | Where-Object { $_.Trim() -eq $splitBeginMarker -or $_.Trim() -eq $splitEndMarker }).Count -ne 0) {
    $failures.Add("Generated multi-source UI runner must not retain split-runner omit markers.")
}

$m2DataPacks = @{
    "lenders" = @{
        Path = "data/debt/lenders.json"
        RequiredFields = @("id", "display_name", "lender_type", "description", "debt_profile", "consequences")
    }
    "services" = @{
        Path = "data/services/services.json"
        RequiredFields = @("id", "display_name", "category", "description", "cost", "effect")
    }
    "travel_routes" = @{
        Path = "data/travel/routes.json"
        RequiredFields = @("id", "label", "destination_archetype", "description", "cost", "risk")
    }
}
foreach ($pack in $m2DataPacks.GetEnumerator()) {
    Assert-JsonRequiredFields $pack.Value.Path $pack.Key $pack.Value.RequiredFields
    Assert-JsonUniqueIds $pack.Value.Path $pack.Key
    if ((Read-JsonArray $pack.Value.Path).Count -eq 0) {
        $failures.Add("M2 data pack must contain at least one vertical-slice entry: $($pack.Value.Path)")
    }
}

$environmentIds = New-ContentIdSet "data/environments/archetypes.json"
$gameIds = New-ContentIdSet "data/games/games.json"
$itemIds = New-ContentIdSet "data/items/items.json"
$eventIds = New-ContentIdSet "data/events/events.json"
$lenderIds = New-ContentIdSet "data/debt/lenders.json"
$serviceIds = New-ContentIdSet "data/services/services.json"
$routeIds = New-ContentIdSet "data/travel/routes.json"
$resultDeltaKeys = @(
    "bankroll_delta",
    "suspicion_delta",
    "alcohol_intake",
    "drunk_delta",
    "pending_drunk_absorption_delta",
    "drunk_distortion_suppression_turns",
    "heat_cooldown_actions",
    "heat_cooldown_per_action",
    "alcoholic_delta",
    "baseline_luck_delta",
    "debt_changes",
    "inventory_add",
    "inventory_remove",
    "flags_set",
    "story_flags_set",
    "travel_hooks_add",
    "travel_changes",
    "story_log",
    "messages",
    "pending_bags",
    "ended",
    "item_hooks",
    "event_hooks",
    "environment_layer_discovery",
    "demo_finale"
)
$eventConsequenceKeys = $resultDeltaKeys + @(
    "debt",
    "flags",
    "flags_set",
    "set_story_flag",
    "set_story_flags",
    "story_flags_set",
    "unlock_travel_route",
    "unlock_travel_routes",
    "set_next_archetypes",
    "add_next_archetypes",
    "check",
    "resolve_event",
    "trigger_event",
    "crew_recruit_member",
    "crew_meet_member",
    "lender_hook",
    "debt_settlement_discount_percent"
)
$objectInfoTextLimit = 64

function Assert-ObjectInfoTextLength {
    param([string]$Label, [string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return
    }
    if ($Text.Length -gt $objectInfoTextLimit) {
        $failures.Add("$Label must fit the in-scene object info card ($($Text.Length)/$objectInfoTextLimit chars): $Text")
    }
    if ($Text.Contains("...")) {
        $failures.Add("$Label must use fitted authored copy instead of ellipsis truncation: $Text")
    }
}

foreach ($archetype in (Read-JsonArray "data/environments/archetypes.json")) {
    $archetypeId = [string](Get-JsonProperty $archetype "id")
    $gamePool = Get-JsonProperty $archetype "game_pool"
    $requiredGameIds = Get-JsonProperty $archetype "required_game_ids"
    Assert-IdArrayReferences "environment $archetypeId game_pool" $gamePool $gameIds
    Assert-IdArrayReferences "environment $archetypeId required_game_ids" $requiredGameIds $gameIds
    $gamePoolValues = ConvertTo-ValueArray $gamePool
    foreach ($requiredGameId in (ConvertTo-ValueArray $requiredGameIds)) {
        if (-not $gamePoolValues.Contains($requiredGameId)) {
            $failures.Add("environment $archetypeId required_game_ids includes $requiredGameId but game_pool does not.")
        }
    }
    Assert-IdArrayReferences "environment $archetypeId item_pool" (Get-JsonProperty $archetype "item_pool") $itemIds
    Assert-IdArrayReferences "environment $archetypeId event_pool" (Get-JsonProperty $archetype "event_pool") $eventIds
    Assert-IdArrayReferences "environment $archetypeId service_pool" (Get-JsonProperty $archetype "service_pool") $serviceIds
    Assert-IdArrayReferences "environment $archetypeId lender_hooks" (Get-JsonProperty $archetype "lender_hooks") $lenderIds
    Assert-IdArrayReferences "environment $archetypeId travel_hooks" (Get-JsonProperty $archetype "travel_hooks") $environmentIds
    if ($routeIds.Count -gt 0) {
        Assert-IdArrayReferences "environment $archetypeId travel_hooks route metadata" (Get-JsonProperty $archetype "travel_hooks") $routeIds
    }
    Assert-EnvironmentLayoutSpots $archetypeId (Get-JsonProperty $archetype "layout")
}

foreach ($route in (Read-JsonArray "data/travel/routes.json")) {
    $routeId = [string](Get-JsonProperty $route "id")
    Assert-ObjectInfoTextLength "travel_routes $routeId description" ([string](Get-JsonProperty $route "description"))
    Assert-NonNegativeIntProperty "travel_routes $routeId" $route "cost"
    Assert-NonNegativeIntProperty "travel_routes $routeId" $route "risk_decay"
    if (Test-JsonProperty $route "risk_decay") {
        try {
            $riskDecay = [int](Get-JsonProperty $route "risk_decay")
            if ($riskDecay -gt 100) {
                $failures.Add("travel_routes $routeId risk_decay must be between 0 and 100.")
            }
        }
        catch {
        }
    }
    $distance = [string](Get-JsonProperty $route "distance")
    $validDistances = @("same", "near", "local", "far", "remote")
    if (-not [string]::IsNullOrWhiteSpace($distance) -and -not $validDistances.Contains($distance.ToLowerInvariant())) {
        $failures.Add("travel_routes $routeId distance must be one of: same, near, local, far, remote.")
    }
    Assert-NonNegativeIntProperty "travel_routes $routeId" $route "requires_travel_count_min"
    if ((Test-JsonProperty $route "hide_until_travel_count_met") -and (Get-JsonProperty $route "hide_until_travel_count_met") -isnot [bool]) {
        $failures.Add("travel_routes $routeId hide_until_travel_count_met must be a boolean.")
    }
    $destination = [string](Get-JsonProperty $route "destination_archetype")
    if (-not [string]::IsNullOrWhiteSpace($destination) -and -not $environmentIds.ContainsKey($destination)) {
        $failures.Add("travel_routes $routeId references unknown destination_archetype: $destination")
    }
    $requiresFlags = Get-JsonProperty $route "requires_flags"
    if ($null -ne $requiresFlags -and $requiresFlags -isnot [pscustomobject]) {
        $failures.Add("travel_routes $routeId requires_flags must be an object when present.")
    }
}

foreach ($item in (Read-JsonArray "data/items/items.json")) {
    $itemId = [string](Get-JsonProperty $item "id")
    Assert-ObjectInfoTextLength "items $itemId description" ([string](Get-JsonProperty $item "description"))
    Assert-ArtAssetPath "items $itemId" $item
    if ([string]::IsNullOrWhiteSpace([string](Get-JsonProperty $item "icon_key"))) {
        $failures.Add("items $itemId must define icon_key for environment/inventory art.")
    }
    if ([string]::IsNullOrWhiteSpace([string](Get-JsonProperty $item "environment_prop"))) {
        $failures.Add("items $itemId must define environment_prop for room presentation.")
    }
    if ([string]::IsNullOrWhiteSpace([string](Get-JsonProperty $item "surface"))) {
        $failures.Add("items $itemId must define surface for room presentation.")
    }
    if (-not (Test-JsonProperty $item "sellable")) {
        $failures.Add("items $itemId must define sellable for merchant sale rules.")
    }
    elseif ((Get-JsonProperty $item "sellable") -isnot [bool]) {
        $failures.Add("items $itemId sellable must be a boolean.")
    }
    if (-not (Test-JsonProperty $item "sale_price")) {
        $failures.Add("items $itemId must define sale_price for merchant sale values.")
    }
    else {
        Assert-NonNegativeIntProperty "items $itemId" $item "sale_price"
    }
}

foreach ($service in (Read-JsonArray "data/services/services.json")) {
    $serviceId = [string](Get-JsonProperty $service "id")
    Assert-ObjectInfoTextLength "services $serviceId description" ([string](Get-JsonProperty $service "description"))
    Assert-NonNegativeIntProperty "services $serviceId" $service "cost"
    Assert-DeltaKeys "services $serviceId effect" (Get-JsonProperty $service "effect") $resultDeltaKeys
}

foreach ($lender in (Read-JsonArray "data/debt/lenders.json")) {
    $lenderId = [string](Get-JsonProperty $lender "id")
    Assert-ObjectInfoTextLength "lenders $lenderId description" ([string](Get-JsonProperty $lender "description"))
    $profile = Get-JsonProperty $lender "debt_profile"
    if ($profile -isnot [pscustomobject]) {
        $failures.Add("lenders $lenderId debt_profile must be an object.")
    }
    else {
        Assert-NonNegativeIntProperty "lenders $lenderId debt_profile" $profile "principal_min"
        Assert-NonNegativeIntProperty "lenders $lenderId debt_profile" $profile "principal_max"
        Assert-NonNegativeIntProperty "lenders $lenderId debt_profile" $profile "deadline_turns"
        $principalMin = [int](Get-JsonProperty $profile "principal_min")
        $principalMax = [int](Get-JsonProperty $profile "principal_max")
        if ($principalMin -gt $principalMax) {
            $failures.Add("lenders $lenderId principal_min greater than principal_max.")
        }
    }
    Assert-DeltaKeys "lenders $lenderId effect" (Get-JsonProperty $lender "effect") $resultDeltaKeys
    $effect = Get-JsonProperty $lender "effect"
    $debtChanges = Get-JsonProperty $effect "debt_changes"
    if ($null -ne $debtChanges) {
        foreach ($debtChange in (ConvertTo-ValueArray $debtChanges)) {
            $debtLenderId = [string](Get-JsonProperty $debtChange "lender_id")
            if (-not [string]::IsNullOrWhiteSpace($debtLenderId) -and -not $lenderIds.ContainsKey($debtLenderId)) {
                $failures.Add("lenders $lenderId effect debt_changes references unknown lender_id: $debtLenderId")
            }
        }
    }
}

$grandCasino = $null
$undergroundCasino = $null
foreach ($archetype in (Read-JsonArray "data/environments/archetypes.json")) {
    $archetypeId = [string](Get-JsonProperty $archetype "id")
    if ($archetypeId -eq "grand_casino") {
        $grandCasino = $archetype
    }
    elseif ($archetypeId -eq "small_underground_casino") {
        $undergroundCasino = $archetype
    }
}
if ($null -eq $grandCasino) {
    $failures.Add("Demo objective requires a grand_casino environment archetype.")
}
else {
    $objective = Get-JsonProperty $grandCasino "demo_objective"
    if ($objective -isnot [pscustomobject]) {
        $failures.Add("grand_casino must define a demo_objective object.")
    }
    else {
        if ([string](Get-JsonProperty $objective "type") -ne "bankroll_target") {
            $failures.Add("grand_casino demo_objective type must be bankroll_target.")
        }
        $targetBankroll = [int](Get-JsonProperty $objective "target_bankroll")
        if ($targetBankroll -ne 0) {
            $failures.Add("grand_casino demo_objective target_bankroll must stay 0 because the clean win uses Grand Casino net winnings.")
        }
        $highRollerTargetBankroll = [int](Get-JsonProperty $objective "high_roller_target_bankroll")
        if ($highRollerTargetBankroll -ne 0) {
            $failures.Add("grand_casino high_roller_target_bankroll must stay 0 because the Players Card is not gated by total bankroll.")
        }
        $highRollerNetWinnings = [int](Get-JsonProperty $objective "high_roller_net_winnings")
        $highRollerMinGames = [int](Get-JsonProperty $objective "high_roller_min_grand_casino_games")
        if ($highRollerNetWinnings -ne 30 -or $highRollerMinGames -ne 5) {
            $failures.Add("grand_casino Gold review must require exactly five settled games and 30 net winnings.")
        }
        $bronzeGames = [int](Get-JsonProperty $objective "players_card_bronze_min_games")
        $bronzeNet = [int](Get-JsonProperty $objective "players_card_bronze_net_winnings")
        $silverGames = [int](Get-JsonProperty $objective "players_card_silver_min_games")
        $silverNet = [int](Get-JsonProperty $objective "players_card_silver_net_winnings")
        $goldGames = [int](Get-JsonProperty $objective "players_card_gold_min_games")
        $goldNet = [int](Get-JsonProperty $objective "players_card_gold_net_winnings")
        if ($bronzeGames -ne 1 -or $bronzeNet -ne 5 -or $silverGames -ne 3 -or $silverNet -ne 15 -or $goldGames -ne 5 -or $goldNet -ne 30) {
            $failures.Add("grand_casino Players Card tiers must use Bronze 1/5, Silver 3/15, and Gold 5/30 thresholds.")
        }
        if ([int](Get-JsonProperty $objective "players_card_look_away_max_heat_gain") -ne 5) {
            $failures.Add("grand_casino Linda look-away threshold must remain data-tuned at five heat.")
        }
    }
    $securityProfile = Get-JsonProperty $grandCasino "security_profile"
    $pitBoss = Get-JsonProperty $securityProfile "pit_boss"
    if ($pitBoss -isnot [pscustomobject]) {
        $failures.Add("grand_casino security_profile must define pit_boss watch data.")
    }
    else {
        if ((Get-JsonProperty $pitBoss "enabled") -ne $true) {
            $failures.Add("grand_casino pit_boss must be enabled.")
        }
        if ([int](Get-JsonProperty $pitBoss "cheat_heat_bonus") -lt 20) {
            $failures.Add("grand_casino pit_boss cheat_heat_bonus should be a meaningful danger.")
        }
    }
}
if ($null -eq $undergroundCasino) {
    $failures.Add("Demo objective route requires small_underground_casino.")
}
else {
    Assert-IdArrayReferences "small_underground_casino next_archetypes" (Get-JsonProperty $undergroundCasino "next_archetypes") $environmentIds
    $undergroundTargets = ConvertTo-ValueArray (Get-JsonProperty $undergroundCasino "next_archetypes")
    if (-not ($undergroundTargets -contains "grand_casino")) {
        $failures.Add("small_underground_casino must route to grand_casino.")
    }
}
$grandRoute = $null
foreach ($route in (Read-JsonArray "data/travel/routes.json")) {
    if ([string](Get-JsonProperty $route "id") -eq "grand_casino") {
        $grandRoute = $route
        break
    }
}
if ($null -eq $grandRoute) {
    $failures.Add("Demo objective requires a grand_casino travel route.")
}
elseif ([int](Get-JsonProperty $grandRoute "cost") -lt 70) {
    $failures.Add("grand_casino travel route should keep the release-tuned meaningful buy-in.")
}

foreach ($event in (Read-JsonArray "data/events/events.json")) {
    $eventId = [string](Get-JsonProperty $event "id")
    Assert-ArtAssetPath "events $eventId" $event
    $eventInteractionMode = [string](Get-JsonProperty $event "interaction_mode")
    if ([string]::IsNullOrWhiteSpace($eventInteractionMode)) {
        $failures.Add("events $eventId must define interaction_mode.")
    }
    elseif (($eventInteractionMode -ne "interactable") -and ($eventInteractionMode -ne "triggered")) {
        $failures.Add("events $eventId has unknown interaction_mode: $eventInteractionMode.")
    }
    $eventIconKey = [string](Get-JsonProperty $event "icon_key")
    $eventEnvironmentProp = [string](Get-JsonProperty $event "environment_prop")
    if ($eventInteractionMode -eq "triggered") {
        if (-not [string]::IsNullOrWhiteSpace($eventIconKey)) {
            $failures.Add("events $eventId is triggered and must not define icon_key.")
        }
        if (-not [string]::IsNullOrWhiteSpace($eventEnvironmentProp)) {
            $failures.Add("events $eventId is triggered and must not define environment_prop.")
        }
    }
    else {
        if ([string]::IsNullOrWhiteSpace($eventIconKey)) {
            $failures.Add("events $eventId must define icon_key for room art.")
        }
        elseif ($eventIconKey -eq "event") {
            $failures.Add("events $eventId must not use the generic event icon_key.")
        }
        if ([string]::IsNullOrWhiteSpace($eventEnvironmentProp)) {
            $failures.Add("events $eventId must define environment_prop such as patron_talk, paper_note, side_door, or security_camera.")
        }
        if ([string]::IsNullOrWhiteSpace([string](Get-JsonProperty $event "start_summary"))) {
            $failures.Add("events $eventId must define start_summary for the player-facing interaction starter.")
        }
    }
    $payload = Get-JsonProperty $event "payload"
    Assert-ObjectInfoTextLength "events $eventId payload.summary" ([string](Get-JsonProperty $payload "summary"))
    $choices = Get-JsonProperty $payload "choices"
    if ($choices -isnot [System.Array]) {
        $failures.Add("events $eventId payload choices must be an array.")
        continue
    }
    foreach ($choice in $choices) {
        $choiceId = [string](Get-JsonProperty $choice "id")
        $consequences = Get-JsonProperty $choice "consequences"
        Assert-DeltaKeys "events $eventId choice $choiceId consequences" $consequences $eventConsequenceKeys
        Assert-IdArrayReferences "events $eventId choice $choiceId set_next_archetypes" (Get-JsonProperty $consequences "set_next_archetypes") $environmentIds
        Assert-IdArrayReferences "events $eventId choice $choiceId add_next_archetypes" (Get-JsonProperty $consequences "add_next_archetypes") $environmentIds
        $debt = Get-JsonProperty $consequences "debt"
        if ($debt -is [pscustomobject]) {
            $debtLenderId = [string](Get-JsonProperty $debt "lender_id")
            if (-not [string]::IsNullOrWhiteSpace($debtLenderId) -and -not $lenderIds.ContainsKey($debtLenderId)) {
                $failures.Add("events $eventId choice $choiceId debt references unknown lender_id: $debtLenderId")
            }
        }
    }
}

Require-Text "scripts/core/run_state.gd" "var economic_state" "M2 economy state must live in RunState."
Require-Text "scripts/core/run_state.gd" "var debt" "M2 debt state must live in RunState."
Require-Text "scripts/core/run_state.gd" "var suspicion" "M2 suspicion/security state must live in RunState."
Require-Text "scripts/core/run_state.gd" "var unlocked_travel" "M2 travel state must live in RunState."
Require-Text "scripts/core/run_state.gd" "func travel_route_status" "Travel conditions must be evaluated through RunState."
Require-Text "scripts/core/run_state.gd" "func service_hook_status" "Service availability must be evaluated through RunState."
Require-Text "scripts/core/run_state.gd" "func lender_hook_status" "Lender availability must be evaluated through RunState."
Require-Text "scripts/core/game_module.gd" "func apply_result" "M2 result-deltas must apply through the shared GameModule/RunState path."
Require-Text "scripts/core/item_effect.gd" "class_name ItemEffect" "Items must use ItemEffect."
Require-Text "scripts/core/event_module.gd" "class_name EventModule" "Events must use EventModule."
Require-Text "scripts/core/save_service.gd" "class_name SaveService" "Foundation run save/load must use SaveService."

$forbiddenM2Managers = @(
    "scripts/core/economy_service.gd",
    "scripts/core/debt_manager.gd",
    "scripts/core/suspicion_service.gd",
    "scripts/core/security_manager.gd",
    "scripts/core/travel_service.gd",
    "scripts/core/service_manager.gd",
    "scripts/core/narrative_service.gd"
)
foreach ($managerPath in $forbiddenM2Managers) {
    if (Test-Path -LiteralPath (Join-Path $root $managerPath)) {
        $failures.Add("M2 architecture must stay in RunState/module contracts; unexpected manager/service file exists: $managerPath")
    }
}

Require-TextInAny $foundationCheckFiles "_check_m2_pack_availability" "Foundation tests must validate canonical M2 pack availability."
Require-TextInAny $foundationCheckFiles "_check_economy_pressure_foundation" "Foundation tests must cover economy pressure."
Require-TextInAny $foundationCheckFiles "_check_travel_route_foundation" "Foundation tests must cover route cost/risk/conditions."
Require-TextInAny $foundationCheckFiles "_check_service_hook_foundation" "Foundation tests must cover services."
Require-TextInAny $foundationCheckFiles "_check_lender_debt_foundation" "Foundation tests must cover debt/lenders."
Require-TextInAny $foundationCheckFiles "_check_suspicion_security_foundation" "Foundation tests must cover suspicion/security."
Require-TextInAny $foundationCheckFiles "_check_item_build_interaction_foundation" "Foundation tests must cover item build interactions."
Require-TextInAny $foundationCheckFiles "_check_event_system_state_foundation" "Foundation tests must cover event state conditions."
Require-TextInAny $foundationCheckFiles "_check_m2_system_interaction_scenario" "Foundation tests must cover an M2 system interaction scenario."

$visualQa = "tools/foundation_visual_qa.gd"
$environmentInteractionController = "scripts/ui/environment_interaction_controller.gd"
$environmentInteractionControllerText = Get-ProjectText $environmentInteractionController
$environmentInteractionControllerApi = @(
    "interactable_object_view_list",
    "numbers_interactable_objects",
    "game_hook_interactable_objects",
    "home_interactable_objects",
    "hook_interactable_objects",
    "interactable_object",
    "parent_home_return_interactable_object",
    "casino_spatial_interactable_objects",
    "environment_layer_interactable_objects",
    "travel_leave_interactable_object",
    "local_parent_home_door_travel_choice",
    "casino_room_door_travel_choice",
    "local_parent_home_door_kind",
    "current_environment_archetype_id",
    "parent_home_node_id",
    "parent_home_parent_target_id"
)
foreach ($methodName in $environmentInteractionControllerApi) {
    $methodPattern = "(?m)^static func " + [regex]::Escape($methodName) + "\("
    if ($environmentInteractionControllerText -notmatch $methodPattern) {
        $failures.Add("Environment interaction controller must expose public static API method: $methodName")
    }
}
Require-Text $environmentInteractionController 'var silas_here: bool =' "Silas itinerary presence must keep an explicit bool type so the controller compiles under warnings-as-errors."
Require-Text "scripts/core/run_state.gd" "func numbers_silas_is_here" "Silas interactable generation and paid exchange must share the production physical-presence predicate."
Require-Text "scripts/ui/foundation_main.gd" "EnvironmentInteractionControllerScript.game_hook_interactable_objects" "Foundation UI must route Poker and other game hooks through the controller public API."
Require-Text "scripts/ui/foundation_main.gd" "EnvironmentInteractionControllerScript.interactable_object_view_list" "Foundation UI must route Numbers and room interactables through the controller public API."
Require-Text $visualQa '"interaction_mode": "visible_controls"' "Foundation visual QA must identify visible control interaction mode."
Require-Text $visualQa '"core_flow_driver": "visible_canvas_and_controls"' "Foundation visual QA must drive the core flow through visible controls."
Require-Text $visualQa '"direct_debug_helper_methods_used": false' "Foundation visual QA must declare that it avoids debug helper gameplay paths."
Require-Text $visualQa "visible_button_signal" "Foundation visual QA must click visible buttons."
Require-Text $visualQa "canvas_mouse_double_click" "Foundation visual QA must double-click visible world objects."
Require-Text $visualQa "game_surface_mouse_click" "Foundation visual QA must click visible game surface regions."
Require-Text $visualQa "serialized_before_legal_click == _serialized_run_text()" "Foundation visual QA must prove surface selection does not mutate RunState."
Require-Text $visualQa "serialized_before_legal_resolve != _serialized_run_text()" "Foundation visual QA must prove visible resolve changes RunState."
Require-Text "tools/foundation_visual_qa.ps1" 'res://tools/foundation_visual_qa.gd' "Visual QA PowerShell wrapper must run the foundation visual QA script."
Forbid-Text $visualQa "RuntimeContent" "Foundation visual QA must not use RuntimeContent."
Forbid-Text $visualQa "GameUiModule" "Foundation visual QA must not instantiate GameUiModule."
Forbid-Text $visualQa "core_content.json" "Foundation visual QA must not depend on data/runtime/core_content.json."
Forbid-Text $visualQa "res://data/runtime" "Foundation visual QA must not load data/runtime paths."

$gameDefinitions = Read-JsonArray "data/games/games.json"
foreach ($gameDefinition in $gameDefinitions) {
    $gameId = [string]$gameDefinition.id
    Assert-ObjectInfoTextLength "games $gameId description" ([string](Get-JsonProperty $gameDefinition "description"))
    Assert-ObjectInfoTextLength "games $gameId intro" ([string](Get-JsonProperty $gameDefinition "intro"))
    $modulePath = [string]$gameDefinition.module_path
    if ($modulePath.EndsWith("_ui.gd") -or $modulePath.Contains("data/runtime")) {
        $failures.Add("Foundation game definition routes through demo/runtime module: $gameId -> $modulePath")
        continue
    }
    if ($modulePath.StartsWith("res://")) {
        $relativeModule = $modulePath.Substring(6)
        $moduleText = Get-ProjectText $relativeModule
        if (-not $moduleText.Contains("extends GameModule")) {
            $failures.Add("Foundation game module does not extend GameModule: $gameId -> $modulePath")
        }
    }
}

$contentIdFiles = @(
    "data/environments/archetypes.json",
    "data/games/games.json",
    "data/items/items.json",
    "data/events/events.json",
    "data/debt/lenders.json",
    "data/services/services.json",
    "data/travel/routes.json"
)
$contentIds = New-Object System.Collections.Generic.HashSet[string]
foreach ($contentFile in $contentIdFiles) {
    foreach ($entry in (Read-JsonArray $contentFile)) {
        $id = [string]$entry.id
        if (-not [string]::IsNullOrWhiteSpace($id)) {
            [void]$contentIds.Add($id)
        }
    }
}
$foundationUiText = Get-ProjectText $foundationUi
foreach ($id in $contentIds) {
    if ($foundationUiText.Contains('"' + $id + '"') -or $foundationUiText.Contains("'" + $id + "'")) {
        $failures.Add("Foundation UI shell hardcodes content id instead of deriving it from ContentLibrary: $id")
    }
}

$simulationSearchRoots = @(
    "scripts/core",
    "scripts/games"
)
foreach ($searchRoot in $simulationSearchRoots) {
    $absoluteSearchRoot = Join-Path $root $searchRoot
    if (-not (Test-Path -LiteralPath $absoluteSearchRoot)) {
        continue
    }
    foreach ($script in Get-ChildItem -LiteralPath $absoluteSearchRoot -Filter "*.gd" -Recurse) {
        $relativeScript = Get-ProjectRelativePath $script.FullName
        $scriptText = Get-Content -LiteralPath $script.FullName -Raw
        if ($scriptText -match '\brandomize\s*\(' -or $scriptText -match '\brandf\s*\(' -or $scriptText -match '\brandi\s*\(' -or $scriptText.Contains("RandomNumberGenerator")) {
            $failures.Add("Foundation simulation must use RngStream instead of engine-global randomness: $relativeScript")
        }
    }
}

try {
    & (Join-Path $root "tools/foundation_systems_shards_test.ps1") -Quiet
}
catch {
    $failures.Add("Foundation systems shard hostile contracts failed: $($_.Exception.Message)")
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure
    }
    exit 1
}

if (-not $Quiet) {
    Write-Host "Beat the House foundation architecture validation passed."
}
