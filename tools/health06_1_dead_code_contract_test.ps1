$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Test-Contract {
	param([bool]$Condition, [string]$Message)
	if (-not $Condition) { $failures.Add($Message) }
}

$scheduler = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/environment_runtime_scheduler.gd")
Test-Contract (-not $scheduler.Contains("stale_pop_count")) "CH-17: permanently-zero stale_pop_count still exists."

$platform = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/platform_services.gd")
Test-Contract (-not $platform.Contains("Pretends to save cloud run data")) "CH-18: orphaned cloud-save comment still precedes unlock_achievement."
Test-Contract (-not $platform.Contains("Reports that no local cloud save exists")) "CH-18: orphaned cloud-load comment still precedes unlock_achievement."

$economy = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/cage_economy_model.gd")
$runState = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/run_state.gd")
$atmView = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/ui/cage_atm_view_model.gd")
Test-Contract (-not $economy.Contains("ORIGINATION_FEE")) "CH-19: dead origination-fee constant still exists."
Test-Contract (-not $runState.Contains('"origination_fee"')) "CH-19: RunState still publishes a zero origination fee."
Test-Contract (-not $atmView.Contains('"origination_fee"')) "CH-19: ATM UI still publishes a zero origination fee."

$tutorial = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/tutorial_flow.gd")
$foundation = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/ui/foundation_main.gd")
$scriptsRoot = Join-Path $projectRoot "scripts"
$vestigialCalls = @(Get-ChildItem -LiteralPath $scriptsRoot -Recurse -Filter "*.gd" -File | Select-String -Pattern 'apply_caught_transition|repair_legacy_frontier|repair_legacy_blackjack_count_skip')
Test-Contract ($vestigialCalls.Count -eq 0) ("CH-20: vestigial tutorial API or alias remains: " + (($vestigialCalls | ForEach-Object { "$($_.Path):$($_.LineNumber)" }) -join ", "))
Test-Contract ($tutorial.Contains("static func repair_legacy_tutorial_save(")) "CH-20: public 0.5.1 tutorial save migration was removed without a safe proof."
Test-Contract ($tutorial.Contains("0.5.1")) "CH-20: retained legacy migration decision is not recorded beside the code."
Test-Contract ($foundation.Contains("TutorialFlowScript.repair_legacy_tutorial_save(run_state)")) "CH-20: production does not call the retained migration directly."
Test-Contract (-not $foundation.Contains("blackjack_")) "CH-20: retained migration leaks game-specific vocabulary into the foundation shell."

foreach ($stylePath in @(
	(Join-Path $projectRoot "scripts/core/game_ritual_layout.gd"),
	(Join-Path $projectRoot "scripts/core/crew_turn_model.gd")
)) {
	$singleLineBodies = @(Select-String -LiteralPath $stylePath -Pattern '^\s*(if|elif|else|for|while)\b.*:\s+\S')
	Test-Contract ($singleLineBodies.Count -eq 0) ("CH-21: single-line control bodies remain in $stylePath at lines " + (($singleLineBodies | ForEach-Object { $_.LineNumber }) -join ", "))
	$continuedSingleLineBodies = @(Select-String -LiteralPath $stylePath -Pattern ':\s+(return|continue|break)(\s|$)')
	Test-Contract ($continuedSingleLineBodies.Count -eq 0) ("CH-21: continued single-line control bodies remain in $stylePath at lines " + (($continuedSingleLineBodies | ForEach-Object { $_.LineNumber }) -join ", "))
	$multiStatementLines = @(Select-String -LiteralPath $stylePath -Pattern '^[^#]*;\s*\S')
	Test-Contract ($multiStatementLines.Count -eq 0) ("CH-21: semicolon-joined statements remain in $stylePath at lines " + (($multiStatementLines | ForEach-Object { $_.LineNumber }) -join ", "))
}

$orphans = @()
foreach ($rootName in @("scripts", "tools")) {
	$rootPath = Join-Path $projectRoot $rootName
	$orphans += @(Get-ChildItem -LiteralPath $rootPath -Recurse -File -Filter "*.gd.uid" | Where-Object { -not (Test-Path -LiteralPath ($_.FullName -replace '\.uid$', '')) })
}
Test-Contract ($orphans.Count -eq 0) ("CH-22: orphaned GDScript UID files remain: " + (($orphans | ForEach-Object { $_.FullName }) -join ", "))

if ($failures.Count -gt 0) {
	$failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
	throw "health06_1 dead-code source contract failed with $($failures.Count) issue(s)."
}

Write-Host "health06_1 dead-code source contract passed."
