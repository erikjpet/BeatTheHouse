# Exports a Beat the House build and packages an itch.io-ready upload.
#
# Examples:
#   .\tools\export_itch.ps1                       # export Web, produce builds/itch/BeatTheHouse-web.zip
#   .\tools\export_itch.ps1 -Target windows       # export Windows, produce BeatTheHouse-windows.zip
#   .\tools\export_itch.ps1 -Debug                # export a debug build instead of release
#   .\tools\export_itch.ps1 -SkipExport           # repackage existing build output without re-exporting
#   .\tools\export_itch.ps1 -Push -ItchTarget you/beat-the-house
#                                                 # also push via butler (channel defaults: web=html, windows=windows)
#
# Requires Godot export templates installed (Editor > Manage Export Templates).
# Pushing requires butler installed and 'butler login' run once: https://itch.io/docs/butler/

param(
    [ValidateSet("web", "windows")]
    [string]$Target = "web",
    [switch]$Debug,
    [switch]$SkipExport,
    [switch]$Push,
    [string]$ItchTarget = "",
    [string]$Channel = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Resolve-Godot {
    if ($env:GODOT_BIN) { return $env:GODOT_BIN }
    $toolsDir = Join-Path $root ".tools"
    $local = Get-ChildItem -LiteralPath $toolsDir -Filter "Godot*_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $local) {
        $local = Get-ChildItem -LiteralPath $toolsDir -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($local) { return $local.FullName }
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "Godot was not found. Run tools/install_godot.ps1 or set GODOT_BIN."
}

# Per-target configuration.
$config = @{
    "web"     = @{ Preset = "Web";          Out = "builds/web/index.html";          Dir = "builds/web";     Zip = "BeatTheHouse-web.zip";     DefaultChannel = "html" }
    "windows" = @{ Preset = "Windows Steam"; Out = "builds/windows/BeatTheHouse.exe"; Dir = "builds/windows"; Zip = "BeatTheHouse-windows.zip"; DefaultChannel = "windows" }
}
$cfg = $config[$Target]

$outDir  = Join-Path $root $cfg.Dir
$outFile = Join-Path $root $cfg.Out
$distDir = Join-Path $root "builds/itch"
$zipPath = Join-Path $distDir $cfg.Zip

# 1. Export from Godot.
if (-not $SkipExport) {
    $godot = Resolve-Godot
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    if ($Debug) { $exportFlag = "--export-debug" } else { $exportFlag = "--export-release" }
    Write-Host "Exporting preset '$($cfg.Preset)' ($exportFlag) with: $godot"
    & $godot --headless --path $root $exportFlag $cfg.Preset $cfg.Out
    if ($LASTEXITCODE -ne 0) {
        throw "Godot export failed (exit $LASTEXITCODE). Most common cause: export templates not installed (Editor > Manage Export Templates)."
    }
    if (-not (Test-Path $outFile)) {
        throw "Export reported success but output is missing: $outFile"
    }
}
else {
    if (-not (Test-Path $outFile)) {
        throw "-SkipExport was set but no existing build was found at: $outFile"
    }
}

# 2. Package the uploadable zip.
#    For web the zip MUST contain index.html at its root, so we archive the
#    folder contents (builds/web/*), not the folder itself.
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $outDir '*') -DestinationPath $zipPath -Force
$zipSize = "{0:N1} MB" -f ((Get-Item $zipPath).Length / 1MB)
Write-Host ""
Write-Host "Uploadable file ready: $zipPath ($zipSize)" -ForegroundColor Green

# 3. Optional: push to itch.io via butler.
if ($Push) {
    $butler = Get-Command butler -ErrorAction SilentlyContinue
    if (-not $butler) {
        throw "butler not found on PATH. Install it (https://itch.io/docs/butler/) and run 'butler login' once."
    }
    if (-not $ItchTarget) {
        throw "-Push requires -ItchTarget in the form 'user/game-slug' (your itch.io project URL)."
    }
    if (-not $Channel) { $Channel = $cfg.DefaultChannel }
    $pushTarget = "{0}:{1}" -f $ItchTarget, $Channel
    Write-Host "Pushing '$outDir' to itch.io target '$pushTarget' ..."
    # butler pushes the folder directly and handles its own diffing/patching.
    & butler push $outDir $pushTarget
    if ($LASTEXITCODE -ne 0) { throw "butler push failed (exit $LASTEXITCODE)." }
    Write-Host "Pushed to itch.io: $pushTarget" -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "Next steps for manual upload:" -ForegroundColor Cyan
    if ($Target -eq "web") {
        Write-Host "  1. Upload $($cfg.Zip) to your itch.io project."
        Write-Host "  2. Tick 'This file will be played in the browser'."
        Write-Host "  3. Embed options: set size 1280 x 720, enable the fullscreen button."
        Write-Host "  4. Enable 'SharedArrayBuffer support' (required - the game uses threads)."
    }
    else {
        Write-Host "  1. Upload $($cfg.Zip) to your itch.io project as a Windows download."
        Write-Host "  2. Tag the platform as Windows."
    }
}
