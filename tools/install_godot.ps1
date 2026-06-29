param(
    [string]$Version = "4.6-stable"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $root ".tools"
$installDir = Join-Path $toolRoot "godot-$Version"
$archive = Join-Path $toolRoot "Godot_v${Version}_win64.exe.zip"
$downloadUrl = "https://github.com/godotengine/godot/releases/download/$Version/Godot_v${Version}_win64.exe.zip"

New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

if (-not (Get-ChildItem -LiteralPath $installDir -Filter "Godot*.exe" -ErrorAction SilentlyContinue)) {
    Write-Host "Downloading Godot $Version..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $installDir -Force
}

$godot = Get-ChildItem -LiteralPath $installDir -Filter "Godot*_console.exe" | Select-Object -First 1
if ($null -eq $godot) {
    $godot = Get-ChildItem -LiteralPath $installDir -Filter "Godot*.exe" | Select-Object -First 1
}
if ($null -eq $godot) {
    throw "Godot executable was not found after install."
}

Write-Host "Godot command-line executable installed at: $($godot.FullName)"
Write-Host "Use this for the current shell:"
Write-Host "`$env:GODOT_BIN = '$($godot.FullName)'"
