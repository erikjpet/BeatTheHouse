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

function Get-ExportPresetCustomFeatures {
    param([string]$PresetName)
    $presetPath = Join-Path $root "export_presets.cfg"
    $activeName = ""
    foreach ($line in Get-Content -LiteralPath $presetPath) {
        if ($line -match '^name="([^"]+)"$') {
            $activeName = $Matches[1]
            continue
        }
        if ($activeName -eq $PresetName -and $line -match '^custom_features="([^"]*)"$') {
            return @($Matches[1].Split(',', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Trim() })
        }
    }
    throw "Could not read custom features for export preset '$PresetName'."
}

function Assert-CleanDistributionOutput {
    param([string]$Directory)
    $forbiddenNames = @(
        "profile_inventory.json",
        "meta_collection.json",
        "settings.json",
        "autosave.json",
        "autosave.json.bak"
    )
    $leakedFiles = @(Get-ChildItem -LiteralPath $Directory -File -Recurse -Force | Where-Object { $forbiddenNames -contains $_.Name })
    if ($leakedFiles.Count -gt 0) {
        $leakedPaths = ($leakedFiles | ForEach-Object { $_.FullName }) -join ", "
        throw "Refusing to package persistent player data: $leakedPaths"
    }
}

function Get-ExportPresetOption {
    param(
        [string]$PresetName,
        [string]$OptionName
    )
    $presetPath = Join-Path $root "export_presets.cfg"
    $activeName = ""
    $escapedOptionName = [System.Text.RegularExpressions.Regex]::Escape($OptionName)
    foreach ($line in Get-Content -LiteralPath $presetPath) {
        if ($line -match '^name="([^"]+)"$') {
            $activeName = $Matches[1]
            continue
        }
        if ($activeName -eq $PresetName -and $line -match "^$escapedOptionName=(.+)$") {
            return $Matches[1]
        }
    }
    throw "Could not read option '$OptionName' for export preset '$PresetName'."
}

function Invoke-WebExportWithLockedTemplate {
    param(
        [string]$GodotPath,
        [string]$ExportFlag,
        [string]$PresetName,
        [string]$OutputPath
    )
    $lock = Get-Content -LiteralPath (Join-Path $root "native/coin_pusher/toolchain.lock.json") -Raw | ConvertFrom-Json
    $templatePath = Join-Path $env:APPDATA "Godot/export_templates/$(([string]$lock.godot.version).Replace('-', '.'))/$([string]$lock.web.template)"
    $presetPath = Join-Path $root "export_presets.cfg"
    $originalBytes = [System.IO.File]::ReadAllBytes($presetPath)
    $presetText = [System.Text.Encoding]::UTF8.GetString($originalBytes)
    $escapedTemplatePath = $templatePath.Replace('\', '/')
    $webOptionsPattern = '(?ms)(\[preset\.3\.options\]\s*.*?^custom_template/release=)"[^"]*"'
    if ($presetText -notmatch $webOptionsPattern) {
        throw "Could not locate the Web release-template option in export_presets.cfg."
    }
    $patchedText = [System.Text.RegularExpressions.Regex]::Replace(
        $presetText,
        $webOptionsPattern,
        ('$1"' + $escapedTemplatePath + '"'),
        1
    )
    try {
        [System.IO.File]::WriteAllText($presetPath, $patchedText, [System.Text.UTF8Encoding]::new($false))
        & $GodotPath --headless --path $root $ExportFlag $PresetName $OutputPath | ForEach-Object { Write-Host $_ }
        return $LASTEXITCODE
    }
    finally {
        [System.IO.File]::WriteAllBytes($presetPath, $originalBytes)
    }
}

function Assert-NativeSolverExport {
    param(
        [string]$Directory,
        [ValidateSet("web", "windows")]
        [string]$ExportTarget
    )
    $extension = if ($ExportTarget -eq "web") { ".wasm" } else { ".dll" }
    $nativeLibraries = @(
        Get-ChildItem -LiteralPath $Directory -File -Recurse -Force |
            Where-Object {
                $_.Name -like "coin_pusher_native*$extension" -and
                $_.Name -like "*.nothreads$extension"
            }
    )
    if ($nativeLibraries.Count -ne 1) {
        throw "Expected exactly one exported Coin Pusher native $ExportTarget library, found $($nativeLibraries.Count). Refusing to package a build without the native solver."
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
$presetFeatures = Get-ExportPresetCustomFeatures $cfg.Preset
if ($presetFeatures -notcontains "distribution_build") {
    throw "Export preset '$($cfg.Preset)' must include the distribution_build feature so itch builds cannot read development saves."
}
if ($Target -eq "web" -and (Get-ExportPresetOption $cfg.Preset "variant/extensions_support") -cne "true") {
    throw "Web export preset '$($cfg.Preset)' must set variant/extensions_support=true before the native solver can be built or exported."
}

Write-Host "Release version from project.godot: $projectVersion"
Write-Host "Fresh-install storage namespace: user://distribution (isolated from editor saves)"
$godot = Resolve-Godot
$nativeBuildTarget = if ($Debug) { "template_debug" } else { "template_release" }

# 1. Export from Godot.
if (-not $SkipExport) {
    $nativePlatform = if ($Target -eq "web") { "Web" } else { "Windows" }
    Write-Host "Building and verifying the locked native Coin Pusher solver ($nativePlatform/$nativeBuildTarget) ..."
    & (Join-Path $PSScriptRoot "build_native_solver.ps1") -Platform $nativePlatform -Target $nativeBuildTarget -GodotPath $godot
    if ($LASTEXITCODE -ne 0) {
        throw "Native Coin Pusher solver build or runtime preflight failed."
    }
    Clear-DirectoryContents $outDir
    if ($Debug) { $exportFlag = "--export-debug" } else { $exportFlag = "--export-release" }
    Write-Host "Exporting preset '$($cfg.Preset)' ($exportFlag) with: $godot"
    $exportExitCode = if ($Target -eq "web" -and -not $Debug) {
        Invoke-WebExportWithLockedTemplate $godot $exportFlag $cfg.Preset $cfg.Out
    }
    else {
        & $godot --headless --path $root $exportFlag $cfg.Preset $cfg.Out
        $LASTEXITCODE
    }
    if ($exportExitCode -ne 0) {
        throw "Godot export failed (exit $exportExitCode). Most common cause: export templates not installed (Editor > Manage Export Templates)."
    }
    if (-not (Test-Path $outFile)) {
        throw "Export reported success but output is missing: $outFile"
    }
}
else {
    & (Join-Path $PSScriptRoot "verify_native_solver_runtime.ps1") -GodotPath $godot -RequireWebTemplate:($Target -eq "web")
    if ($LASTEXITCODE -ne 0) {
        throw "Native solver runtime preflight failed; refusing to repackage an unverified build."
    }
    if (-not (Test-Path $outFile)) {
        throw "-SkipExport was set but no existing build was found at: $outFile"
    }
}

Assert-CleanDistributionOutput $outDir
Assert-NativeSolverExport -Directory $outDir -ExportTarget $Target

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
        Write-Host "  4. Enable SharedArrayBuffer support. Web GDExtension loading requires cross-origin isolation even though this build is single-threaded."
        Write-Host "  5. Butler channel: $($cfg.DefaultChannel); user version: $projectVersion."
    }
    else {
        Write-Host "  1. Upload $($cfg.Zip) to your itch.io project as a Windows download."
        Write-Host "  2. Tag the platform as Windows."
        Write-Host "  3. Butler channel: $($cfg.DefaultChannel); user version: $projectVersion."
    }
}
