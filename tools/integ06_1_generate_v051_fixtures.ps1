param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$GodotPath = "",
    [string]$HistoricalCommit = "f1ce7ec814b5034c229f53dcc0db6e799aaaee0b",
    [ValidateSet("v0_5_1", "mid_0_6")]
    [string]$CaptureClass = "v0_5_1",
    [string]$CaptureMilestone = "",
    [string]$FixtureId = "v051_smoke_foundation_run",
    [string]$Seed = "INTEG06-1-V051-SMOKE-001",
    [string]$PlanPath = "",
    [string]$OutputDirectory = "",
    [ValidateRange(30, 600)]
    [int]$CaptureTimeoutSeconds = 120,
    [switch]$KeepHistoricalArchive
)

$ErrorActionPreference = "Stop"
$PinnedV051Commit = "f1ce7ec814b5034c229f53dcc0db6e799aaaee0b"
$PinnedMid06Commits = @{
    "31e434c412ba8bdeda03bee86db1f8b4d899c962" = "pre_game_depth"
    "5a2b1e1a6782a13308585e1a974adeeb86be0647" = "pre_environment_depth"
    "f1ebe9a729253e4ee3d4d99702a019d9328edbaf" = "pre_world_depth"
}
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

function Stop-DisposableProcessTree([int]$ProcessId) {
    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue)
    foreach ($child in $children) {
        Stop-DisposableProcessTree ([int]$child.ProcessId)
    }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

function Invoke-BoundedNative(
    [string]$FilePath,
    [string[]]$Arguments,
    [int]$TimeoutSeconds,
    [string]$StdoutPath,
    [string]$StderrPath
) {
    $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -NoNewWindow -PassThru -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-DisposableProcessTree $process.Id
        throw "Process $($process.Id) exceeded the $TimeoutSeconds-second bound: $FilePath $($Arguments -join ' ')"
    }
    $process.WaitForExit()
    $output = @()
    if (Test-Path -LiteralPath $StdoutPath) {
        $output += @(Get-Content -LiteralPath $StdoutPath)
    }
    if (Test-Path -LiteralPath $StderrPath) {
        $output += @(Get-Content -LiteralPath $StderrPath)
    }
    return @{ ExitCode = $process.ExitCode; Output = $output }
}

$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$ProjectRoot = $resolvedProjectRoot
if ([string]::IsNullOrWhiteSpace($PlanPath) -and $FixtureId -notmatch '^[A-Za-z0-9_-]+$') {
    throw "FixtureId may contain only letters, numbers, underscores, and hyphens."
}
if ([string]::IsNullOrWhiteSpace($PlanPath) -and $Seed -notmatch '^[A-Za-z0-9_.:-]+$') {
    throw "Seed may contain only letters, numbers, underscores, periods, colons, and hyphens."
}
$resolvedCommit = Get-GitObject "$HistoricalCommit^{commit}"
$historicalRelease = ""
$resolvedMilestone = $CaptureMilestone
if ($CaptureClass -eq "v0_5_1") {
    if ($resolvedCommit -ne $PinnedV051Commit) {
        throw "Historical commit resolved to $resolvedCommit; v0_5_1 capture is pinned to $PinnedV051Commit."
    }
    $tag = Invoke-Git @("describe", "--tags", "--exact-match", $resolvedCommit)
    if ($tag -ne "v0.5.1") {
        throw "Historical commit $resolvedCommit is not exactly tag v0.5.1."
    }
    $historicalRelease = $tag
    if ([string]::IsNullOrWhiteSpace($resolvedMilestone)) { $resolvedMilestone = "v0_5_1_release" }
}
else {
    if (-not $PinnedMid06Commits.ContainsKey($resolvedCommit)) {
        throw "Historical commit $resolvedCommit is not one of the reviewed mid-0.6 capture boundaries."
    }
    $expectedMilestone = [string]$PinnedMid06Commits[$resolvedCommit]
    if (-not [string]::IsNullOrWhiteSpace($resolvedMilestone) -and $resolvedMilestone -ne $expectedMilestone) {
        throw "Capture milestone $resolvedMilestone does not match reviewed boundary $expectedMilestone for $resolvedCommit."
    }
    $resolvedMilestone = $expectedMilestone
    $historicalRelease = "mid-0.6-development-boundary"
}

$godot = Resolve-GodotExecutable $GodotPath
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $ProjectRoot ".tmp/integ06_1/v0_5_1"
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("bth-integ06-1-historical-" + [guid]::NewGuid().ToString("N"))
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
	$captureCases = @($null)
	$expectedResultCount = 1
	if (-not [string]::IsNullOrWhiteSpace($PlanPath)) {
		$resolvedPlan = (Resolve-Path -LiteralPath $PlanPath).Path
		$parsedPlan = Get-Content -LiteralPath $resolvedPlan -Raw | ConvertFrom-Json
		$captureCases = @($parsedPlan.cases)
		$expectedResultCount = $captureCases.Count
		if ($expectedResultCount -lt 1) {
			throw "Capture plan must contain at least one case."
		}
		$archivePlan = Join-Path $historicalRoot "integ06_1_fixture_plan.json"
	}

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
        $importResult = Invoke-BoundedNative $godot @("--headless", "--import", "--path", $historicalRoot) 300 (Join-Path $temporaryRoot "import.stdout.log") (Join-Path $temporaryRoot "import.stderr.log")
        if ([int]$importResult.ExitCode -ne 0) {
            throw "Historical Godot archive import exited $($importResult.ExitCode)`n$($importResult.Output -join [Environment]::NewLine)"
	        }
	        Write-Host "Imported isolated historical archive at $resolvedCommit."
			$godotOutput = @()
			for ($caseIndex = 0; $caseIndex -lt $captureCases.Count; $caseIndex++) {
				$captureCase = $captureCases[$caseIndex]
				$captureArguments = @("--", "--fixture-id", $FixtureId, "--seed", $Seed, "--expected-version", "0.5.1")
				$captureLabel = $FixtureId
				if ($null -ne $captureCase) {
					$captureLabel = [string]$captureCase.fixture_id
					$singleCasePlan = [ordered]@{
						schema = [string]$parsedPlan.schema
						version = [int]$parsedPlan.version
						historical_commit = [string]$parsedPlan.historical_commit
						step_sequences = $parsedPlan.step_sequences
						cases = @($captureCase)
					}
					$singleCasePlan | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $archivePlan -Encoding utf8
					$captureArguments = @("--", "--plan", "res://integ06_1_fixture_plan.json", "--expected-version", "0.5.1")
				}
				Write-Host "Starting bounded historical FoundationMain capture for $captureLabel."
				$captureLog = Join-Path $temporaryRoot "historical_capture_$caseIndex.log"
				$godotArguments = @("--headless", "--audio-driver", "Dummy", "--log-file", $captureLog, "--path", $historicalRoot, "--script", "res://$HarnessRelativePath") + $captureArguments
				$captureResult = Invoke-BoundedNative $godot $godotArguments $CaptureTimeoutSeconds (Join-Path $temporaryRoot "capture_$caseIndex.stdout.log") (Join-Path $temporaryRoot "capture_$caseIndex.stderr.log")
				$caseOutput = @($captureResult.Output)
				$caseOutput | ForEach-Object { Write-Host $_ }
				$godotExit = [int]$captureResult.ExitCode
				if ($godotExit -ne 0) {
					$logTail = if (Test-Path -LiteralPath $captureLog) { (Get-Content -LiteralPath $captureLog -Tail 40) -join [Environment]::NewLine } else { "capture log unavailable" }
					throw "Historical Godot capture for $captureLabel exited $godotExit.`n$logTail"
				}
				$errorLines = @($caseOutput | Where-Object { "$_" -match '(^|\s)(SCRIPT ERROR|ERROR):' })
				if ($errorLines.Count -gt 0) {
					throw "Historical Godot capture for $captureLabel emitted an error despite exit code ${godotExit}:`n$($errorLines -join [Environment]::NewLine)"
				}
				$caseResultLines = @($caseOutput | Where-Object { "$_" -like "INTEG06_1_FIXTURE_RESULT=*" })
				if ($caseResultLines.Count -ne 1) {
					throw "Historical capture for $captureLabel emitted $($caseResultLines.Count) provenance results; expected 1."
				}
				$godotOutput += $caseOutput
			}
	    }
    finally {
        $env:BTH_DISTRIBUTION_BUILD = $oldDistributionBuild
        $env:BTH_DISTRIBUTION_DATA_ROOT = $oldDistributionRoot
        $env:BTH_USER_SETTINGS_PATH = $oldSettingsPath
        $env:BTH_PROFILE_INVENTORY_PATH = $oldProfilePath
        $env:BTH_META_COLLECTION_PATH = $oldCollectionPath
    }
	    $resultLines = @($godotOutput | Where-Object { "$_" -like "INTEG06_1_FIXTURE_RESULT=*" })
	if ($resultLines.Count -ne $expectedResultCount) {
		throw "Historical capture emitted $($resultLines.Count) provenance results; expected $expectedResultCount."
    }
    # Provenance is stable across Git's LF/CRLF checkout policy. The historical
    # driver is source text, so identify its canonical LF bytes rather than the
    # platform-specific working-tree representation.
    $harnessText = [IO.File]::ReadAllText($sourceHarness).Replace("`r`n", "`n").Replace("`r", "`n")
    $utf8NoBom = New-Object Text.UTF8Encoding($false)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $harnessHash = ([BitConverter]::ToString($sha256.ComputeHash($utf8NoBom.GetBytes($harnessText)))).Replace('-', '')
    }
    finally {
        $sha256.Dispose()
    }
	$custodyInventoryPath = ""
	$custodyInventoryHash = ""
	if ($KeepHistoricalArchive) {
		$custodyInventoryPath = Join-Path $temporaryRoot "custody_inventory.json"
		$inventoryEntries = @(Get-ChildItem -LiteralPath $temporaryRoot -Recurse -File | Where-Object { $_.FullName -ne $custodyInventoryPath } | Sort-Object FullName | ForEach-Object {
			$relativePath = $_.FullName.Substring($temporaryRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar).Replace("\", "/")
			[ordered]@{
				path = $relativePath
				size_bytes = $_.Length
				sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
			}
		})
		$custodyInventory = [ordered]@{
			schema = "beat_the_house.integ06_1_historical_custody_inventory"
			version = 1
			capture_class = $CaptureClass
			capture_milestone = $resolvedMilestone
			historical_commit = $resolvedCommit
			custody_root = $temporaryRoot
			files = $inventoryEntries
		}
		$custodyInventory | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $custodyInventoryPath -Encoding utf8
		$custodyInventoryHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $custodyInventoryPath).Hash
	}
	foreach ($resultLine in $resultLines) {
		$capture = ("$resultLine" -replace '^INTEG06_1_FIXTURE_RESULT=', '') | ConvertFrom-Json
		$capturedFixtureId = [string]$capture.fixture_id
		if ($capturedFixtureId -notmatch '^[A-Za-z0-9_-]+$') {
			throw "Historical capture emitted unsafe fixture id: $capturedFixtureId"
		}
		$sourceSave = [IO.Path]::GetFullPath([string]$capture.save_path)
		$expectedSaveRoot = [IO.Path]::GetFullPath($userDataRoot)
		if (-not $sourceSave.StartsWith($expectedSaveRoot, [StringComparison]::OrdinalIgnoreCase)) {
			throw "Historical SaveService wrote outside the isolated data root: $sourceSave"
		}
		if (-not (Test-Path -LiteralPath $sourceSave)) {
			throw "Historical SaveService output is missing: $sourceSave"
		}
		$capture.save_path = "isolated_distribution_root/saves/$capturedFixtureId.json"
		$destinationSave = Join-Path $OutputDirectory "$capturedFixtureId.json"
		Copy-Item -LiteralPath $sourceSave -Destination $destinationSave -Force
		if ($KeepHistoricalArchive) {
			Copy-Item -LiteralPath $custodyInventoryPath -Destination (Join-Path $OutputDirectory "$capturedFixtureId.custody.json") -Force
		}
		$saveHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destinationSave).Hash
		$manifest = [ordered]@{
			schema = "beat_the_house.integ06_1_historical_fixture_provenance"
			version = 1
			fixture_id = $capturedFixtureId
			capture_class = $CaptureClass
			capture_milestone = $resolvedMilestone
			historical_release = $historicalRelease
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
			custody_root = if ($KeepHistoricalArchive) { $temporaryRoot } else { "" }
			custody_inventory_path = if ($KeepHistoricalArchive) { $custodyInventoryPath } else { "" }
			custody_inventory_sha256 = if ($KeepHistoricalArchive) { $custodyInventoryHash } else { "" }
		}
		$manifestPath = Join-Path $OutputDirectory "$capturedFixtureId.provenance.json"
		$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding utf8
		Write-Host "Generated genuine $historicalRelease fixture at $resolvedMilestone`: $destinationSave"
		Write-Host "SHA-256: $saveHash"
		Write-Host "Provenance: $manifestPath"
	}
}
finally {
    if ($KeepHistoricalArchive) {
        Write-Host "Kept temporary historical archive at $temporaryRoot"
    }
    elseif (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
