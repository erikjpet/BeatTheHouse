param([string]$GodotPath = "")

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if (-not $GodotPath) { $GodotPath = $env:GODOT_BIN }
if (-not $GodotPath) {
    $common = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
    $GodotPath = Join-Path (Split-Path -Parent $common) ".tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Godot console was not found: $GodotPath" }
& $GodotPath --headless --path $root --script res://tools/perf06_deferred_validation_contract.gd
if ($LASTEXITCODE -ne 0) { throw "Deferred runtime validation contract failed." }
