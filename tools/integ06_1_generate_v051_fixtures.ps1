param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$GodotPath = "",
    [string]$HistoricalCommit = "f1ce7ec814b5034c229f53dcc0db6e799aaaee0b",
    [string]$FixtureId = "v051_smoke_foundation_run",
    [string]$Seed = "INTEG06-1-V051-SMOKE-001",
    [string]$OutputDirectory = "",
    [switch]$KeepHistoricalArchive
)

$ErrorActionPreference = "Stop"
$PinnedV051Commit = "f1ce7ec814b5034c229f53dcc0db6e799aaaee0b"
$HarnessRelativePath = "scripts/tests/foundation/integ06_1_v051_fixture_driver.gd"

function Invoke-Git([string[]]$Arguments) {
    $output = & git -C $ProjectRoot @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed:`n$($output -join [Environment]::NewLine)"
    }
    return ($output -join "`n").Trim()
}

function Resolve-GodotExecutable([string]$RequestedPath) {
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
        return (Resolve-Path -LiteralPath $env:GODOT_BIN).Path
    }
    $commonGitDirectory = Invoke-Git @("rev-parse", "--path-format=absolute", "--git-common-dir")
    $checkoutRoot = Split-Path -Parent $commonGitDirectory
    $bundled = Join-Path $checkoutRoot ".tools/godot-4.6-stable/Godot_v4.6-stable_win64_console.exe"
    if (Test-Path -LiteralPath $bundled) {
        return (Resolve-Path -LiteralPath $bundled).Path
    }
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }
    throw "Godot executable not found. Pass -GodotPath or set GODOT_BIN."
}

function Get-GitObject([string]$RevisionPath) {
    return Invoke-Git @("rev-parse", $RevisionPath)
}

$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$ProjectRoot = $resolvedProjectRoot
$resolvedCommit = Get-GitObject "$HistoricalCommit^{commit}"
if ($resolvedCommit -ne $PinnedV051Commit) {
    throw "Historical commit resolved to $resolvedCommit; this driver is pinned to v0.5.1 $PinnedV051Commit."
}
$tag = Invoke-Git @("describe", "--tags", "--exact-match", $resolvedCommit)
if ($tag -ne "v0.5.1") {
    throw "Historical commit $resolvedCommit is not exactly tag v0.5.1."
}

$godot = Resolve-GodotExecutable $GodotPath
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $ProjectRoot ".tmp/integ06_1/v0_5_1"
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("bth-integ06-1-v051-" + [guid]::NewGuid().ToString("N"))
$archivePath = Join-Path $temporaryRoot "v051.zip"
$historicalRoot = Join-Path $temporaryRoot "project"
$userDataRoot = Join-Path $temporaryRoot "user_data"
New-Item -ItemType Directory -Force -Path $temporaryRoot, $historicalRoot, $userDataRoot | Out-Null

try {
    # Export only the real runtime closure. Historical docs, reports, visual-QA
    # captures, and test suites are not dependencies of scenes/main.tscn and
    # would make every clean provenance run import hundreds of irrelevant files.
    $runtimePaths = @(
        "project.godot",
        "default_bus_layout.tres",
        "icon.svg",
        "scenes",
        "scripts/core",
        "scripts/games",
        "scripts/ui",
        "data",
        "assets"
    )
    & git -C $ProjectRoot archive --format=zip --output=$archivePath $resolvedCommit @runtimePaths
    if ($LASTEXITCODE -ne 0) {
        throw "Could not archive historical commit $resolvedCommit."
    }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $historicalRoot
    $sourceHarness = Join-Path $ProjectRoot $HarnessRelativePath
    $archiveHarness = Join-Path $historicalRoot $HarnessRelativePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $archiveHarness) | Out-Null
    Copy-Item -LiteralPath $sourceHarness -Destination $archiveHarness -Force

    $oldDistributionBuild = $env:BTH_DISTRIBUTION_BUILD
    $oldDistributionRoot = $env:BTH_DISTRIBUTION_DATA_ROOT
    $oldSettingsPath = $env:BTH_USER_SETTINGS_PATH
    $oldProfilePath = $env:BTH_PROFILE_INVENTORY_PATH
    $oldCollectionPath = $env:BTH_META_COLLECTION_PATH
    try {
        $dataRootForGodot = $userDataRoot.Replace("\", "/")
        $env:BTH_DISTRIBUTION_BUILD = "1"
        $env:BTH_DISTRIBUTION_DATA_ROOT = $dataRootForGodot
        $env:BTH_USER_SETTINGS_PATH = "$dataRootForGodot/settings.json"
        $env:BTH_PROFILE_INVENTORY_PATH = "$dataRootForGodot/profile_inventory.json"
        $env:BTH_META_COLLECTION_PATH = "$dataRootForGodot/meta_collection.json"
        # A Git archive deliberately contains no .godot editor cache. Import
        # the isolated archive first so its historical global class registry is
        # built from that tree rather than borrowed from a modern checkout.
        # Windows PowerShell promotes native stderr (including ordinary Godot
        # warnings) to ErrorRecord objects when Stop is active. Capture the
        # process output and trust its exit code at this boundary.
        $oldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $importOutput = & $godot --headless --import --path $historicalRoot 2>&1
        $importExit = $LASTEXITCODE
        if ($importExit -ne 0) {
            throw "Historical Godot archive import exited $importExit`n$($importOutput -join [Environment]::NewLine)"
        }
        Write-Host "Imported isolated historical archive at $resolvedCommit."
        Write-Host "Starting bounded historical FoundationMain capture for $FixtureId."
        $captureLog = Join-Path $temporaryRoot "historical_capture.log"
        $godotOutput = & $godot --headless --audio-driver Dummy --log-file $captureLog --path $historicalRoot --script "res://$HarnessRelativePath" -- --fixture-id $FixtureId --seed $Seed 2>&1
        $godotExit = $LASTEXITCODE
        $ErrorActionPreference = $oldErrorActionPreference
    }
    finally {
        $env:BTH_DISTRIBUTION_BUILD = $oldDistributionBuild
        $env:BTH_DISTRIBUTION_DATA_ROOT = $oldDistributionRoot
        $env:BTH_USER_SETTINGS_PATH = $oldSettingsPath
        $env:BTH_PROFILE_INVENTORY_PATH = $oldProfilePath
        $env:BTH_META_COLLECTION_PATH = $oldCollectionPath
    }
    $godotOutput | ForEach-Object { Write-Host $_ }
    if ($godotExit -ne 0) {
        $logTail = if (Test-Path -LiteralPath $captureLog) { (Get-Content -LiteralPath $captureLog -Tail 40) -join [Environment]::NewLine } else { "capture log unavailable" }
        throw "Historical Godot capture exited $godotExit.`n$logTail"
    }
    $resultLine = $godotOutput | Where-Object { "$_" -like "INTEG06_1_FIXTURE_RESULT=*" } | Select-Object -Last 1
    if ($null -eq $resultLine) {
        throw "Historical capture did not emit its provenance result."
    }
    $capture = ("$resultLine" -replace '^INTEG06_1_FIXTURE_RESULT=', '') | ConvertFrom-Json
    $sourceSave = [IO.Path]::GetFullPath([string]$capture.save_path)
    $expectedSaveRoot = [IO.Path]::GetFullPath($userDataRoot)
    if (-not $sourceSave.StartsWith($expectedSaveRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Historical SaveService wrote outside the isolated data root: $sourceSave"
    }
    if (-not (Test-Path -LiteralPath $sourceSave)) {
        throw "Historical SaveService output is missing: $sourceSave"
    }

    $destinationSave = Join-Path $OutputDirectory "$FixtureId.json"
    Copy-Item -LiteralPath $sourceSave -Destination $destinationSave -Force
    $saveHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destinationSave).Hash
    $harnessHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceHarness).Hash
    $manifest = [ordered]@{
        schema = "beat_the_house.integ06_1_historical_fixture_provenance"
        version = 1
        fixture_id = $FixtureId
        historical_release = $tag
        historical_commit = $resolvedCommit
        historical_tree = Get-GitObject "$resolvedCommit^{tree}"
        historical_main_scene_blob = Get-GitObject "$resolvedCommit`:scenes/main.tscn"
        historical_foundation_main_blob = Get-GitObject "$resolvedCommit`:scripts/ui/foundation_main.gd"
        historical_save_service_blob = Get-GitObject "$resolvedCommit`:scripts/core/save_service.gd"
        driver_path = $HarnessRelativePath
        driver_sha256 = $harnessHash
        capture = $capture
        save_file = [IO.Path]::GetFileName($destinationSave)
        save_size_bytes = (Get-Item -LiteralPath $destinationSave).Length
        save_sha256 = $saveHash
    }
    $manifestPath = Join-Path $OutputDirectory "$FixtureId.provenance.json"
    $manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    Write-Host "Generated genuine $tag fixture: $destinationSave"
    Write-Host "SHA-256: $saveHash"
    Write-Host "Provenance: $manifestPath"
}
finally {
    if ($KeepHistoricalArchive) {
        Write-Host "Kept temporary historical archive at $temporaryRoot"
    }
    elseif (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
