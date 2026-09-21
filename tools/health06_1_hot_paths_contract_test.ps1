$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Test-Contract {
	param([bool]$Condition, [string]$Message)
	if (-not $Condition) { $failures.Add($Message) }
}

$registryPath = Join-Path $projectRoot "scripts/core/game_module_registry.gd"
Test-Contract (Test-Path -LiteralPath $registryPath) "CH-12: GameModuleRegistry is missing."
if (Test-Path -LiteralPath $registryPath) {
	$registry = Get-Content -Raw -LiteralPath $registryPath
	Test-Contract ($registry.Contains("static func definition_declares_recovery_hook(")) "CH-12: static recovery capability query is missing."
	Test-Contract ($registry.Contains("static func definition_defers_bankroll_zero(")) "CH-12: static bankroll-zero capability query is missing."
	Test-Contract ($registry.Contains("static func cache_script(")) "CH-12: shared game-module script cache is missing."
}

$terminal = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/run_terminal_evaluator.gd")
Test-Contract ($terminal.Contains("GameModuleRegistryScript.definition_declares_recovery_hook")) "CH-12: terminal recovery checks do not use the static capability query."
Test-Contract ($terminal.Contains("GameModuleRegistryScript.definition_defers_bankroll_zero")) "CH-12: terminal bankroll checks do not use the static capability query."
Test-Contract (-not $terminal.Contains("static func _create_game_module(")) "CH-12: terminal evaluator still owns the load/new/setup path."
Test-Contract (-not $terminal.Contains("for archetype in library.environment_archetypes")) "CH-12: terminal evaluator still linear-scans archetypes."

$generator = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/run_generator.gd")
Test-Contract (-not $generator.Contains("var _game_module_script_cache")) "CH-12: RunGenerator still owns a duplicate script cache."
Test-Contract ($generator.Contains("GameModuleRegistryScript.create_module")) "CH-12: RunGenerator does not construct modules through the shared registry."

$library = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/content_library.gd")
Test-Contract ($library.Contains("var archetype_by_id: Dictionary")) "CH-12: ContentLibrary has no explicit archetype_by_id index."
Test-Contract ($library.Contains("archetype_by_id = _index_by_id(environment_archetypes)")) "CH-12: archetype_by_id is not rebuilt with content indexes."

$shoe = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/card_shoe.gd")
Test-Contract (-not $shoe.Contains("shoe.append(card.duplicate(true))")) "CH-13: every remaining shoe card is still deep-copied on draw."
Test-Contract (-not $shoe.Contains("result.append((card_value as Dictionary).duplicate(true))")) "CH-13: card_array still deep-copies every card."
Test-Contract ($shoe.Contains("drawn.append(card.duplicate(true))")) "CH-13: handed-out cards no longer retain copy isolation."

$rng = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/rng_stream.gd")
Test-Contract ($rng.Contains("func shuffled(values: Array) -> Array:")) "CH-14: RngStream.shuffled is missing."
Test-Contract ($rng.Contains("values.duplicate(false)")) "CH-14: RNG selection does not use a shallow copy."
Test-Contract (-not $rng.Contains("values.duplicate(true)")) "CH-14: pick_many still deep-copies its pool."

$eventResolver = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/environment_event_resolver.gd")
$environmentInstance = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "scripts/core/environment_instance.gd")
Test-Contract ($eventResolver.Contains("rng.shuffled(resolved)")) "CH-14: event resolver still implements a full shuffle with pick_many."
Test-Contract (([regex]::Matches($environmentInstance, 'rng\.shuffled\(')).Count -ge 3) "CH-14: all three audited EnvironmentInstance full shuffles were not migrated."

if ($failures.Count -gt 0) {
	$failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
	throw "health06_1 hot-path source contract failed with $($failures.Count) issue(s)."
}

Write-Host "health06_1 hot-path source contract passed."
