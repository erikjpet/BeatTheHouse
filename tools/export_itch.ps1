# Exports a Beat the House build and packages an itch.io-ready upload.
#
# Examples:
#   .\tools\export_itch.ps1                       # export Web, produce builds/itch/BeatTheHouse-web.zip
#   .\tools\export_itch.ps1 -Target windows       # export Windows, produce BeatTheHouse-windows.zip
#   .\tools\export_itch.ps1 -Debug                # export a debug build instead of release
#   .\tools\export_itch.ps1 -SkipExport           # repackage existing build output without re-exporting
#   .\tools\export_itch.ps1 -Push -ItchTarget you/beat-the-house
#                                                 # push via butler (default channels: web=html, windows=windows)
#   .\tools\export_itch.ps1 -Push -DryRun -ItchTarget you/beat-the-house
#                                                 # print the butler command without publishing
#
# Requires Godot export templates installed (Editor > Manage Export Templates).
# Pushing requires butler installed and 'butler login' run once: https://itch.io/docs/butler/

param(
    [ValidateSet("web", "windows")]
    [string]$Target = "web",
    [switch]$Debug,
    [switch]$SkipExport,
    [switch]$Push,
    [switch]$DryRun,
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

function Get-ProjectVersion {
    $projectPath = Join-Path $root "project.godot"
    $versionLine = Get-Content -LiteralPath $projectPath | Where-Object { $_ -match '^config/version=' } | Select-Object -First 1
    if ($versionLine -and $versionLine -match '^config/version="([^"]+)"') {
        return $Matches[1]
    }
    throw "Could not read application/config version from project.godot."
}

function Format-CommandArgument {
    param([string]$Argument)
    if ($Argument -match '[\s"]') {
        return '"' + ($Argument -replace '"', '\"') + '"'
    }
    return $Argument
}

function Clear-DirectoryContents {
    param([string]$Directory)
    $fullRoot = [System.IO.Path]::GetFullPath($root)
    $fullDirectory = [System.IO.Path]::GetFullPath($Directory)
    if (-not $fullDirectory.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clear directory outside workspace: $fullDirectory"
    }
    if (Test-Path -LiteralPath $fullDirectory) {
        Get-ChildItem -LiteralPath $fullDirectory -Force | Remove-Item -Recurse -Force
    }
    else {
        New-Item -ItemType Directory -Force -Path $fullDirectory | Out-Null
    }
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
$projectVersion = Get-ProjectVersion

Write-Host "Release version from project.godot: $projectVersion"

# 1. Export from Godot.
if (-not $SkipExport) {
    $godot = Resolve-Godot
    Clear-DirectoryContents $outDir
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
$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
Write-Host ""
Write-Host "Uploadable file ready: $zipPath ($zipSize)" -ForegroundColor Green
Write-Host "SHA256: $zipHash"

# 3. Optional: push to itch.io via butler.
if ($Push) {
    if (-not $ItchTarget) {
        throw "-Push requires -ItchTarget in the form 'user/game-slug' (your itch.io project URL)."
    }
    if (-not $Channel) { $Channel = $cfg.DefaultChannel }
    $pushTarget = "{0}:{1}" -f $ItchTarget, $Channel
    $butlerArgs = @("push", "--userversion", $projectVersion, $outDir, $pushTarget)
    $butlerCommand = "butler " + (($butlerArgs | ForEach-Object { Format-CommandArgument $_ }) -join " ")
    if ($DryRun) {
        Write-Host ""
        Write-Host "Butler dry run (no upload performed):" -ForegroundColor Cyan
        Write-Host "  $butlerCommand"
        Write-Host "  Channel: $Channel"
        Write-Host "  User version: $projectVersion"
        return
    }
    $butler = Get-Command butler -ErrorAction SilentlyContinue
    if (-not $butler) {
        throw "butler not found on PATH. Install it (https://itch.io/docs/butler/) and run 'butler login' once."
    }
    Write-Host "Pushing '$outDir' to itch.io target '$pushTarget' as version '$projectVersion' ..."
    # butler pushes the folder directly and handles its own diffing/patching.
    & butler @butlerArgs
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
        Write-Host "  5. Butler channel: $($cfg.DefaultChannel); user version: $projectVersion."
    }
    else {
        Write-Host "  1. Upload $($cfg.Zip) to your itch.io project as a Windows download."
        Write-Host "  2. Tag the platform as Windows."
        Write-Host "  3. Butler channel: $($cfg.DefaultChannel); user version: $projectVersion."
    }
}
