param(
    [switch]$Editor
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

if ($env:GODOT_BIN) {
    $godot = $env:GODOT_BIN
}
else {
    $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $localGodot) {
        $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($localGodot) {
        $godot = $localGodot.FullName
    }
    else {
        $command = Get-Command godot -ErrorAction SilentlyContinue
        if ($command) {
            $godot = $command.Source
        }
    }
}

if (-not $godot) {
    throw "Godot was not found. Run tools/install_godot.ps1 or set GODOT_BIN."
}

if ($Editor) {
    & $godot --path $root -e
}
else {
    & $godot --path $root
}
