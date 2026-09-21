$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot "check_godot.ps1")

function Assert-HealthContract {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
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

$standaloneInvocations = [regex]::Matches($source, '(?m)^\s*Invoke-StandaloneContracts\s*$')
Assert-HealthContract ($standaloneInvocations.Count -ge 3) "The Contract, Full, and narrowed contracts gates do not all run standalone contracts."

$foundationFiles = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot "scripts/tests/foundation") -Filter "*.gd" -File)
Assert-HealthContract ($foundationFiles.Count -eq 80) "The post-triage CH-23 census changed; re-audit the standalone discovery set."

if ($args -notcontains "-Quiet") {
    Write-Host "health06_1 standalone contract gate contract passed."
}
