# Downloads and installs the Godot export templates required to export builds.
#
# Godot has no headless command to fetch export templates, so this mirrors what
# the editor's "Manage Export Templates > Download and Install" does: it grabs
# the official .tpz package and extracts it to the path Godot expects.
#
# Examples:
#   .\tools\install_export_templates.ps1            # install 4.6-stable templates
#   .\tools\install_export_templates.ps1 -Force     # re-download and reinstall

param(
    [string]$Version = "4.6-stable",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $root ".tools"
New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null

# Download tag "4.6-stable" maps to the templates folder name "4.6.stable".
$verDir = $Version -replace "-", "."
$templatesRoot = Join-Path $env:APPDATA "Godot/export_templates"
$targetDir = Join-Path $templatesRoot $verDir
$marker = Join-Path $targetDir "web_release.zip"

if ((Test-Path $marker) -and -not $Force) {
    Write-Host "Export templates already installed at: $targetDir"
    Write-Host "(use -Force to reinstall)"
    return
}

$archive = Join-Path $toolRoot "export_templates_$Version.zip"
$extractDir = Join-Path $toolRoot "export_templates_$Version"
$downloadUrl = "https://github.com/godotengine/godot/releases/download/$Version/Godot_v${Version}_export_templates.tpz"

if ($Force -and (Test-Path $archive)) { Remove-Item $archive -Force }
if (-not (Test-Path $archive)) {
    Write-Host "Downloading export templates for $Version (large, ~700 MB)..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $archive
}

if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
Write-Host "Extracting..."
# .tpz is a zip; we downloaded it with a .zip name so Expand-Archive accepts it.
Expand-Archive -LiteralPath $archive -DestinationPath $extractDir -Force

$inner = Join-Path $extractDir "templates"
if (-not (Test-Path $inner)) {
    throw "Unexpected archive layout: a 'templates' folder was not found in $extractDir."
}

New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Copy-Item -Path (Join-Path $inner "*") -Destination $targetDir -Recurse -Force

if (-not (Test-Path $marker)) {
    throw "Install finished but web_release.zip is missing in $targetDir."
}

Write-Host ""
Write-Host "Export templates installed at: $targetDir" -ForegroundColor Green
Write-Host "You can now run: .\tools\export_itch.ps1"
