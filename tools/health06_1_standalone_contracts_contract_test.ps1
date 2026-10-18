$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot "check_godot.ps1")

function Assert-HealthContract {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-ExactPathSet {
    param([object[]]$Expected, [object[]]$Actual, [string]$Label)
    $expectedPaths = @($Expected | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    $actualPaths = @($Actual | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    $difference = @(Compare-Object -ReferenceObject $expectedPaths -DifferenceObject $actualPaths)
    Assert-HealthContract ($difference.Count -eq 0) "$Label changed; review and classify these paths: $($difference | Out-String)"
}

$priorityContracts = @(
    "fixsweep06_1_accessibility_contract.gd",
    "fixsweep06_1_audio_recovery_contract.gd",
    "fixsweep06_1_lifecycle_contract.gd",
    "fixsweep06_1_packaging_runtime_contract.gd",
    "fixsweep06_1_player_text_contract.gd"
)

Assert-HealthContract $source.Contains("function Invoke-StandaloneContracts") "check_godot has no standalone contract stage."
Assert-HealthContract $source.Contains("function Get-StandaloneContractScripts") "check_godot does not discover standalone contracts."
foreach ($fileName in $priorityContracts) {
    Assert-HealthContract $source.Contains($fileName) "The standalone stage does not explicitly prioritize $fileName."
}
Assert-HealthContract (-not $source.Contains('"--exclude=res://scripts/tests/foundation,res://scripts/tests/ui_scene"')) "The load check still excludes the entire foundation test directory."
Assert-HealthContract (-not $source.Contains('if ($resourcePath.StartsWith("res://scripts/tests/foundation/") -or $resourcePath.StartsWith("res://scripts/tests/ui_scene/"))')) "The exhaustive parse still excludes the entire foundation test directory."
Assert-HealthContract ($source.Contains('standalone_user_data') -and $source.Contains('$env:BTH_DISTRIBUTION_DATA_ROOT = $stageUserRoot')) "Standalone contracts do not isolate persistent user data per stage."
Assert-HealthContract ($source.Contains('$maxConcurrentShardProcesses = 1')) "Foundation shard execution can still start more than one headless Godot process at a time."
Assert-HealthContract ($source.Contains('"foundation_contracts" = 1349.566')) "The serial foundation-contract budget does not equal the sum of the captured per-shard baseline durations."

# Qualification stages must inherit the caller override or a reviewed measured
# baseline. Literal 120/180-second ceilings have already killed the 162.1-second
# validator and the roughly 221-second exhaustive environment contract.
$timeoutFailures = [Collections.Generic.List[string]]::new()
$validatorBaselineMatch = [regex]::Match($source, '"validate_project"\s*=\s*([0-9]+(?:\.[0-9]+)?)')
if (-not $validatorBaselineMatch.Success -or [double]$validatorBaselineMatch.Groups[1].Value -lt 162.1) {
    $timeoutFailures.Add("validate_project has no reviewed >=162.1-second measured baseline")
}
$standaloneBaselineMatch = [regex]::Match($source, '"standalone_contract"\s*=\s*([0-9]+(?:\.[0-9]+)?)')
if (-not $standaloneBaselineMatch.Success -or [double]$standaloneBaselineMatch.Groups[1].Value -lt 221.0) {
    $timeoutFailures.Add("standalone_contract has no reviewed >=221.0-second measured baseline")
}
$validatorInvocation = [regex]::Match($source, '(?m)^Invoke-ProcessStage -Name "validate_project"[^\r\n]+\r?$')
if (-not $validatorInvocation.Success -or -not $validatorInvocation.Value.Contains('-StageTimeoutSec (Get-StageTimeout "validate_project")')) {
    $timeoutFailures.Add("validate_project still bypasses its caller/stage-derived timeout")
}
$standaloneBlock = [regex]::Match($source, '(?ms)function Invoke-StandaloneContracts\s*\{(.*?)(?=\r?\nfunction )')
if (-not $standaloneBlock.Success -or -not $standaloneBlock.Value.Contains('-StageTimeoutSec (Get-StageTimeout "standalone_contract")')) {
    $timeoutFailures.Add("standalone contracts still bypass their caller/stage-derived timeout")
}
Assert-HealthContract ($timeoutFailures.Count -eq 0) "Qualification timeout custody failed: $($timeoutFailures -join '; ')."

# Runtime-heavy qualification is serialized, so the games aggregate must use
# one monolithic Godot process instead of paying four private-project startups.
# Contracts retain their reviewed serial shard isolation and measured budget.
$narrowedFoundationBlock = [regex]::Match($source, '(?ms)if \(-not \[string\]::IsNullOrWhiteSpace\(\$foundationSuiteKey\)\) \{(.*?)(?=\r?\nswitch \(\$suiteKey\))')
Assert-HealthContract ($narrowedFoundationBlock.Success -and $narrowedFoundationBlock.Value.Contains('elseif ($foundationSuiteKey -eq "systems" -or $foundationSuiteKey -eq "contracts")') -and -not $narrowedFoundationBlock.Value.Contains('$foundationSuiteKey -eq "games" -or $foundationSuiteKey -eq "contracts"') -and $narrowedFoundationBlock.Value.Contains('Invoke-FoundationSuite -FoundationSuite $foundationSuiteKey')) "Narrowed games qualification is not routed through one monolithic Godot process while systems and contracts retain serial shards."
$contractSuiteBlocks = [regex]::Matches($source, '(?ms)^\s*"contract"\s*\{(.*?)(?=^\s*"audit"\s*\{)')
$contractSuiteBlock = if ($contractSuiteBlocks.Count -gt 0) { $contractSuiteBlocks[$contractSuiteBlocks.Count - 1] } else { $null }
Assert-HealthContract ($null -ne $contractSuiteBlock -and $contractSuiteBlock.Value.Contains('Invoke-FoundationSystemsSharded -FoundationSuite "contracts" -StageTimeoutSec (Get-StageTimeout "foundation_contracts") | Out-Null')) "Suite Contract does not use the reviewed serialized contract shards and their derived stage timeout."
Assert-HealthContract (-not $source.Contains('Invoke-FoundationSuite -FoundationSuite "contracts" -StageTimeoutSec 360')) "Suite Contract still uses the stale monolithic 360-second route."

$standaloneInvocations = [regex]::Matches($source, '(?m)^\s*Invoke-StandaloneContracts\s*$')
Assert-HealthContract ($standaloneInvocations.Count -ge 3) "The Contract, Full, and narrowed contracts gates do not all run standalone contracts."

$manifestPath = Join-Path $PSScriptRoot "health06_1_standalone_contract_manifest.json"
Assert-HealthContract (Test-Path -LiteralPath $manifestPath -PathType Leaf) "The reviewed standalone classification manifest is missing."
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-HealthContract ([string]$manifest.schema -ceq "beat_the_house.health06_1_standalone_contract_manifest/v1") "The standalone classification manifest schema changed."

$splitBlock = [regex]::Match($source, '(?ms)\$script:FoundationSplitSourceRelativePaths\s*=\s*@\((.*?)\r?\n\)')
Assert-HealthContract $splitBlock.Success "The foundation split-source declaration cannot be reviewed."
$declaredSplitNames = @([regex]::Matches($splitBlock.Groups[1].Value, '"scripts/tests/foundation/([^"\r\n]+\.gd)"') | ForEach-Object { $_.Groups[1].Value })
Assert-ExactPathSet @($manifest.foundation_split_sources) $declaredSplitNames "Foundation split-source declaration"

$foundationFiles = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot "scripts/tests/foundation") -Filter "*.gd" -File | Sort-Object Name)
$splitSet = @{}
foreach ($fileName in $declaredSplitNames) { $splitSet[$fileName] = $true }
$standaloneNames = [Collections.Generic.List[string]]::new()
$supportNames = [Collections.Generic.List[string]]::new()
foreach ($file in $foundationFiles) {
    if ($splitSet.ContainsKey($file.Name)) { continue }
    $firstLine = ([string](Get-Content -LiteralPath $file.FullName -TotalCount 1)).Trim()
    if ($firstLine -eq "extends SceneTree" -or $firstLine -eq 'extends "res://scripts/tests/tutorial_dialogue_trigger_cadence_check.gd"') {
        $standaloneNames.Add($file.Name)
    }
    else { $supportNames.Add($file.Name) }
}
Assert-ExactPathSet @($manifest.foundation_standalone_sources) $standaloneNames.ToArray() "Foundation standalone discovery"
Assert-ExactPathSet @($manifest.foundation_support_sources) $supportNames.ToArray() "Foundation support-script exclusion"

$classifiedNames = @($declaredSplitNames) + @($standaloneNames) + @($supportNames)
Assert-ExactPathSet @($foundationFiles.Name) $classifiedNames "Foundation source classification"
Assert-HealthContract ($source.Contains('$splitSet.ContainsKey($relativePath)')) "Standalone discovery no longer excludes the reviewed split sources."
Assert-HealthContract ($source.Contains('$firstLine.Trim() -eq "extends SceneTree"') -and $source.Contains('tutorial_dialogue_trigger_cadence_check.gd')) "Standalone discovery no longer uses the reviewed first-line contract rule."

if ($args -notcontains "-Quiet") {
    Write-Host "health06_1 standalone contract gate contract passed."
}
