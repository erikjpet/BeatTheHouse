$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

function Assert-Contract {
	param([bool]$Condition, [string]$Message)
	if (-not $Condition) { throw $Message }
}

$catalog = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/world_sequence_package_catalog.gd")
Assert-Contract ($catalog.Contains("const MAX_PACKAGES_PER_FILE")) "CH-07: explicit package-file bound is missing."
Assert-Contract ($catalog.Contains("static func entry_result(")) "CH-07: package lookup does not expose failure modes."
Assert-Contract ($catalog.Contains("FileAccess.open(")) "CH-07: package IO still uses the ambiguous convenience read."
Assert-Contract ($catalog.Contains("push_error(")) "CH-07: package IO failure is still silent."
Assert-Contract (-not $catalog.Contains("(parsed as Array).size() > PACKAGE_PATHS.size()")) "CH-07: package count is still coupled to path-map size."

$itemEffect = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/item_effect.gd")
$contentLibrary = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/content_library.gd")
Assert-Contract ($itemEffect.Contains("_modifier_type_family")) "CH-08: runtime modifier merge has no type guard."
Assert-Contract ($contentLibrary.Contains("_validate_item_modifier_type_conflicts")) "CH-08: item content validation has no modifier-type conflict check."

$hours = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/environment_hours.gd")
$hud = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/ui/foundation_hud_bar.gd")
Assert-Contract ($hours.Contains("PlayerTextScript.format_time_of_day")) "CH-09: environment hours does not use PlayerText."
Assert-Contract (-not $hours.Contains("static func _clock_label(")) "CH-09: environment hours retains its local formatter."
Assert-Contract ($hud.Contains("PlayerTextScript.format_time_of_day")) "CH-09: HUD retains a second AM/PM formatter."
$testsRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "scripts/tests"))
$formatters = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot "scripts") -Recurse -Filter "*.gd" -File | Where-Object { $_.FullName -ne (Join-Path $projectRoot "scripts/ui/player_text.gd") -and -not $_.FullName.StartsWith($testsRoot) } | Select-String -SimpleMatch 'return "%d:%02d %s"')
Assert-Contract ($formatters.Count -eq 0) ("CH-09: production AM/PM formatter remains outside PlayerText: " + (($formatters | ForEach-Object { "$($_.Path):$($_.LineNumber)" }) -join ", "))

$terminal = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/run_terminal_evaluator.gd")
Assert-Contract ($terminal.Contains("static func _route_is_affordable(")) "CH-10: shared route affordability helper is missing."
Assert-Contract (([regex]::Matches($terminal, '_route_is_affordable\(run_state\.bankroll, cost\)')).Count -eq 2) "CH-10: both route checks do not use the shared affordability rule."

Write-Host "health06_1 correctness source contract passed."
