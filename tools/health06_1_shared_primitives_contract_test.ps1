$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$jsonCoercePath = Join-Path $projectRoot "scripts/core/json_coerce.gd"
$staticCachePath = Join-Path $projectRoot "scripts/core/static_data_cache.gd"
$resolverPath = Join-Path $projectRoot "scripts/core/collection_item_resolver.gd"
$dropServicePath = Join-Path $projectRoot "scripts/core/collection_drop_service.gd"
$gameModulePath = Join-Path $projectRoot "scripts/core/game_module.gd"
$checkGodotPath = Join-Path $projectRoot "tools/check_godot.ps1"
$splitHelpersPath = Join-Path $projectRoot "tools/split_test_runner_helpers.ps1"

function Assert-HealthContract {
	param([bool]$Condition, [string]$Message)
	if (-not $Condition) {
		throw $Message
	}
}

Assert-HealthContract (Test-Path -LiteralPath $staticCachePath) "CH-11: StaticDataCache is missing."
$jsonSource = Get-Content -Raw -LiteralPath $jsonCoercePath
foreach ($helper in @("_copy_dict", "_copy_array", "_string_array", "_dictionary_array", "_int_array", "_stable_hash", "_valid_sha256", "coerce_enum")) {
	Assert-HealthContract $jsonSource.Contains("static func $helper(") "CH-29: JsonCoerce is missing $helper."
}
foreach ($policy in @("_raw_string_array", "_literal_string_array", "_unique_string_array", "_stable_hash_allow_zero", "_utf8_stable_hash", "_overflow_stable_hash")) {
	Assert-HealthContract $jsonSource.Contains("static func $policy(") "CH-29: JsonCoerce is missing compatibility policy $policy."
}

$resolverSource = Get-Content -Raw -LiteralPath $resolverPath
Assert-HealthContract ($resolverSource.Contains("StaticDataCacheScript.get_or_load") -and $resolverSource.Contains("debug_definition_parse_count")) "CH-11: collection definitions are not backed by the measured static cache."
$dropSource = Get-Content -Raw -LiteralPath $dropServicePath
Assert-HealthContract (([regex]::Matches($dropSource, [regex]::Escape("CollectionItemResolverScript.new()"))).Count -eq 1) "CH-11: CollectionDropService still constructs resolvers inside its loops/helpers."

$checkGodotSource = Get-Content -Raw -LiteralPath $checkGodotPath
$splitHelpersSource = Get-Content -Raw -LiteralPath $splitHelpersPath
Assert-HealthContract (-not $checkGodotSource.Contains('"_harness_arrive",`r`n        "_copy_dict"')) "CH-29: split composition still requires deleted local copy helpers."
Assert-HealthContract ($splitHelpersSource.Contains('$seenJsonCoercePreload')) "CH-29: split composition does not deduplicate the shared JsonCoerce preload."
foreach ($viewModelPath in @(
	(Join-Path $projectRoot "scripts/ui/environment_interaction_controller.gd"),
	(Join-Path $projectRoot "scripts/ui/foundation_action_view_model.gd"),
	(Join-Path $projectRoot "scripts/ui/foundation_travel_view_model.gd")
)) {
	$viewModelSource = Get-Content -Raw -LiteralPath $viewModelPath
	Assert-HealthContract (-not ($viewModelSource -match 'host\._(copy_dict|copy_array|string_array)\(')) "CH-29: split view-model still calls a deleted host coercion helper: $viewModelPath"
}

$uiCompileInheritanceChain = @(
	(Join-Path $projectRoot "scripts/tests/ui_scene/compile_components_and_main_flow.gd"),
	(Join-Path $projectRoot "scripts/tests/ui_scene/compile_environment_layout.gd"),
	(Join-Path $projectRoot "scripts/tests/ui_scene/compile_run_menu_and_game_flows.gd")
)
$uiCompilePreloadCount = 0
foreach ($uiCompilePath in $uiCompileInheritanceChain) {
	$uiCompileSource = Get-Content -Raw -LiteralPath $uiCompilePath
	$uiCompilePreloadCount += ([regex]::Matches($uiCompileSource, 'const JsonCoerceScript := preload\("res://scripts/core/json_coerce\.gd"\)')).Count
}
Assert-HealthContract ($uiCompilePreloadCount -eq 1) "CH-29: UI compile inheritance chain must declare the shared JsonCoerce preload exactly once."

$helperPattern = '^(?:static )?func (?:JsonCoerce\.)?(_copy_dict|_copy_array|_string_array|_dictionary_array|_int_array|_stable_hash|_valid_sha256)\('
$allowed = @($jsonCoercePath, $gameModulePath)
$stragglers = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot "scripts") -Recurse -Filter "*.gd" -File | Where-Object { $_.FullName -notin $allowed } | Select-String -Pattern $helperPattern)
Assert-HealthContract ($stragglers.Count -eq 0) ("CH-29: local coercion helpers remain: " + (($stragglers | ForEach-Object { "$($_.Path):$($_.LineNumber)" }) -join ", "))

if ($args -notcontains "-Quiet") {
	Write-Host "health06_1 shared-primitives source contract passed."
}
