param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$catalogPath = Join-Path $repoRoot "data/games/games.json"
$referencePath = Join-Path $repoRoot "docs/game_reference.md"
$readmePath = Join-Path $repoRoot "README.md"
$projectPath = Join-Path $repoRoot "project.godot"
$exportPath = Join-Path $repoRoot "export_presets.cfg"
$errors = [System.Collections.Generic.List[string]]::new()

function Add-DocumentationError([string]$message) {
    $errors.Add($message)
}

$games = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$reference = Get-Content -LiteralPath $referencePath -Raw
$readme = Get-Content -LiteralPath $readmePath -Raw

if ($games.Count -ne 11) {
    Add-DocumentationError "The 0.6 catalog must contain exactly 11 games; found $($games.Count)."
}

$seenIds = @{}
foreach ($game in $games) {
    $id = [string]$game.id
    $displayName = [string]$game.display_name
    $modulePath = [string]$game.module_path
    if ([string]::IsNullOrWhiteSpace($id) -or $seenIds.ContainsKey($id)) {
        Add-DocumentationError "The game catalog contains a missing or duplicate id: '$id'."
        continue
    }
    $seenIds[$id] = $true

    if ($game.gameplay_model -ne "full_simulation") {
        Add-DocumentationError "$id is not marked full_simulation."
    }
    if (-not $modulePath.StartsWith("res://scripts/games/")) {
        Add-DocumentationError "$id has an unexpected module path: $modulePath"
        continue
    }

    $relativeModule = $modulePath.Substring("res://".Length).Replace("\", "/")
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relativeModule) -PathType Leaf)) {
        Add-DocumentationError "$id points to a missing module: $relativeModule"
    }
    foreach ($requiredText in @($id, $displayName, $relativeModule)) {
        if (-not $reference.Contains($requiredText)) {
            Add-DocumentationError "docs/game_reference.md does not mention '$requiredText'."
        }
    }
    if (-not $readme.Contains($relativeModule)) {
        Add-DocumentationError "README.md does not include the production module $relativeModule."
    }
}

$gameScripts = Get-ChildItem -LiteralPath (Join-Path $repoRoot "scripts/games") -Recurse -File -Filter "*.gd"
foreach ($script in $gameScripts) {
    $relativePath = $script.FullName.Substring($repoRoot.Length + 1).Replace("\", "/")
    if (-not $reference.Contains($relativePath)) {
        Add-DocumentationError "docs/game_reference.md does not account for $relativePath."
    }
}

if ($gameScripts.Count -ne 47) {
    Add-DocumentationError "The documented 0.6 inventory expects 47 game scripts; found $($gameScripts.Count)."
}

$gameDataFiles = Get-ChildItem -LiteralPath (Join-Path $repoRoot "data/games") -Recurse -File
foreach ($dataFile in $gameDataFiles) {
    $relativePath = $dataFile.FullName.Substring($repoRoot.Length + 1).Replace("\", "/")
    if (-not $reference.Contains($relativePath)) {
        Add-DocumentationError "docs/game_reference.md does not account for $relativePath."
    }
}

if ($gameDataFiles.Count -ne 9) {
    Add-DocumentationError "The documented 0.6 inventory expects 9 game-data files; found $($gameDataFiles.Count)."
}

$projectText = Get-Content -LiteralPath $projectPath -Raw
$exportText = Get-Content -LiteralPath $exportPath -Raw
if (-not $projectText.Contains('config/version="0.6.0"')) {
    Add-DocumentationError "project.godot is not stamped 0.6.0."
}
foreach ($requiredExportVersion in @(
    'application/product_version="0.6.0.0"',
    'version/name="0.6.0"',
    'application/version="0.6.0"'
)) {
    if (-not $exportText.Contains($requiredExportVersion)) {
        Add-DocumentationError "export_presets.cfg is missing $requiredExportVersion."
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "PASS: documented 11 full-simulation games, all $($gameScripts.Count) game scripts, and all $($gameDataFiles.Count) game-data files."
