$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptsRoot = Join-Path $projectRoot "scripts"
$excludedPaths = @(
	(Join-Path $scriptsRoot "core/json_coerce.gd"),
	(Join-Path $scriptsRoot "core/game_module.gd")
)
$helperNames = @(
	"_copy_dict",
	"_copy_array",
	"_string_array",
	"_dictionary_array",
	"_int_array",
	"_stable_hash",
	"_valid_sha256"
)
$declarationPattern = '^(?:static )?func (?:JsonCoerce\.)?(' + (($helperNames | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\('
$callPattern = '(?<![A-Za-z0-9_.])(' + (($helperNames | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\('
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Test-CodePosition {
	param([string]$Line, [int]$Index)
	$quote = [char]0
	$escaped = $false
	for ($offset = 0; $offset -lt $Index; $offset++) {
		$character = $Line[$offset]
		if ($escaped) {
			$escaped = $false
			continue
		}
		if ($quote -ne [char]0 -and $character -eq '\') {
			$escaped = $true
			continue
		}
		if ($quote -eq [char]0 -and $character -eq '#') {
			return $false
		}
		if ($character -eq '"' -or $character -eq "'") {
			if ($quote -eq [char]0) {
				$quote = $character
			}
			elseif ($quote -eq $character) {
				$quote = [char]0
			}
		}
	}
	return $quote -eq [char]0
}

function Add-JsonCoerceQualifier {
	param([string]$Line)
	$Line = $Line.Replace("JsonCoerce._", "JsonCoerceScript._")
	$matches = @([regex]::Matches($Line, $callPattern))
	for ($index = $matches.Count - 1; $index -ge 0; $index--) {
		$match = $matches[$index]
		if (-not (Test-CodePosition -Line $Line -Index $match.Index)) {
			continue
		}
		$Line = $Line.Insert($match.Index, "JsonCoerceScript.")
	}
	return $Line
}

foreach ($file in Get-ChildItem -LiteralPath $scriptsRoot -Recurse -Filter "*.gd" -File) {
	if ($file.FullName -in $excludedPaths) {
		continue
	}
	$source = [System.IO.File]::ReadAllText($file.FullName)
	$inheritsGameModule = $source -match '(?m)^extends GameModule\s*$'
	$lines = [regex]::Split($source, "\r?\n")
	$output = New-Object System.Collections.Generic.List[string]
	$skippingHelper = $false
	foreach ($line in $lines) {
		if (-not $skippingHelper -and $line -match $declarationPattern) {
			$skippingHelper = $true
			continue
		}
		if ($skippingHelper) {
			if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\s') {
				continue
			}
			$skippingHelper = $false
		}
		if ($line -match $declarationPattern) {
			$skippingHelper = $true
			continue
		}
		$outputLine = if ($inheritsGameModule) { $line } else { Add-JsonCoerceQualifier -Line $line }
		$output.Add($outputLine)
	}
	$outputText = $output -join "`n"
	if (-not $inheritsGameModule -and $outputText.Contains("JsonCoerceScript._") -and -not $outputText.Contains("const JsonCoerceScript :=")) {
		$extendsIndex = -1
		for ($index = 0; $index -lt $output.Count; $index++) {
			if ($output[$index] -match '^extends\s') {
				$extendsIndex = $index
				break
			}
		}
		if ($extendsIndex -lt 0) {
			throw "Cannot add JsonCoerce preload to $($file.FullName): no extends declaration."
		}
		$output.Insert($extendsIndex + 1, "")
		$output.Insert($extendsIndex + 2, 'const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")')
		$outputText = $output -join "`n"
	}
	$updated = $outputText
	if ($updated -ne $source) {
		try {
			[System.IO.File]::WriteAllText($file.FullName, $updated, $utf8NoBom)
		}
		catch {
			$tempPath = "$($file.FullName).health06_1.tmp"
			$backupPath = "$($file.FullName).health06_1.bak"
			try {
				[System.IO.File]::WriteAllText($tempPath, $updated, $utf8NoBom)
				[System.IO.File]::Replace($tempPath, $file.FullName, $backupPath)
				Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
			}
			catch {
				Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
				Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
				throw "Failed to rewrite $($file.FullName): $($_.Exception.Message)"
			}
		}
	}
}

# Preserve the intentionally different policies that the removed helpers implemented.
$rawOmitEmpty = @(
	"scripts/core/event_module.gd", "scripts/core/item_effect.gd", "scripts/core/run_generator.gd",
	"scripts/games/blackjack.gd", "scripts/games/pull_tabs.gd", "scripts/games/roulette.gd",
	"scripts/tests/foundation/check_core_content.gd", "scripts/ui/foundation_main.gd",
	"scripts/ui/game_surface_canvas.gd", "scripts/ui/pixel_scene_canvas.gd",
	"tools/environment_generation_audit.gd", "tools/foundation_performance_probe.gd",
	"tools/foundation_soak_probe.gd", "tools/roulette_seed_audit.gd"
)
$rawKeepEmpty = @(
	"scripts/games/craps.gd", "scripts/games/scratch_tickets.gd",
	"scripts/games/slots/slot_family_buffalo.gd", "scripts/ui/inventory_container_surface.gd",
	"tools/coin_pusher_copy_visual_probe.gd", "tools/roulette_rule_audit.gd",
	"tools/slot_cabinet_visual_qa.gd", "tools/slot_pinball_items_probe.gd",
	"tools/tutorial_seed_audit.gd", "tools/wave_a_coexistence_probe.gd"
)
$trimUnique = @(
	"scripts/core/content_library.gd", "scripts/core/scenario_engine.gd",
	"scripts/core/scenario_host_transaction.gd", "scripts/core/scenario_operation_registry.gd",
	"scripts/core/scenario_sequence_runtime.gd", "scripts/core/scenario_sequence_schema.gd",
	"scripts/ui/coach_overlay.gd",
	"tools/archive/tier1/tier1_scenario_audit.gd"
)
foreach ($relativePath in $rawOmitEmpty) {
	$path = Join-Path $projectRoot $relativePath
	if (Test-Path -LiteralPath $path) {
		$text = [System.IO.File]::ReadAllText($path).Replace("JsonCoerceScript._string_array(", "JsonCoerceScript._raw_string_array(")
		[System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
	}
}
foreach ($relativePath in $rawKeepEmpty) {
	$path = Join-Path $projectRoot $relativePath
	if (Test-Path -LiteralPath $path) {
		$text = [System.IO.File]::ReadAllText($path).Replace("JsonCoerceScript._string_array(", "JsonCoerceScript._literal_string_array(")
		[System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
	}
}
foreach ($relativePath in $trimUnique) {
	$path = Join-Path $projectRoot $relativePath
	if (Test-Path -LiteralPath $path) {
		$text = [System.IO.File]::ReadAllText($path).Replace("JsonCoerceScript._string_array(", "JsonCoerceScript._unique_string_array(")
		[System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
	}
}

$hashPolicies = @{
	"scripts/core/character_chain_model.gd" = "_utf8_stable_hash"
	"scripts/games/bar_dice.gd" = "_stable_hash"
	"scripts/games/blackjack.gd" = "_stable_hash"
	"scripts/games/coin_pusher.gd" = "_overflow_stable_hash"
	"scripts/games/coin_pusher/coin_pusher_export_parity_runner.gd" = "_utf8_stable_hash"
	"scripts/games/video_poker.gd" = "_stable_hash"
	"scripts/ui/music_arrangement_selector.gd" = "_stable_hash_allow_zero"
	"scripts/ui/procedural_music_player.gd" = "_stable_hash_allow_zero"
}
foreach ($entry in $hashPolicies.GetEnumerator()) {
	$path = Join-Path $projectRoot $entry.Key
	if (-not (Test-Path -LiteralPath $path)) { continue }
	$text = [System.IO.File]::ReadAllText($path)
	$text = [regex]::Replace($text, '(?<![A-Za-z0-9_.])_stable_hash\(', "JsonCoerceScript.$($entry.Value)(")
	$text = $text.Replace("JsonCoerceScript._stable_hash(", "JsonCoerceScript.$($entry.Value)(")
	[System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
}

# View-model collaborators previously reached into FoundationMain's deleted copies.
foreach ($relativePath in @(
	"scripts/ui/environment_interaction_controller.gd",
	"scripts/ui/foundation_action_view_model.gd",
	"scripts/ui/foundation_travel_view_model.gd"
)) {
	$path = Join-Path $projectRoot $relativePath
	$text = [System.IO.File]::ReadAllText($path)
	$text = $text.Replace("host._copy_array(", "JsonCoerceScript._copy_array(")
	$text = $text.Replace("host._copy_dict(", "JsonCoerceScript._copy_dict(")
	$text = $text.Replace("host._string_array(", "JsonCoerceScript._raw_string_array(")
	if (-not $text.Contains("const JsonCoerceScript :=")) {
		$text = $text.Replace("extends RefCounted`n", "extends RefCounted`n`nconst JsonCoerceScript := preload(`"res://scripts/core/json_coerce.gd`")`n")
	}
	[System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
}
