[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [ValidateRange(1, 1000)]
    [int]$Keep = 3,
    [string[]]$Stage = @("*"),
    [string]$TmpRoot = "",
    [switch]$Apply
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($TmpRoot)) {
    $TmpRoot = Join-Path $root ".tmp"
}
$resolvedRoot = [IO.Path]::GetFullPath($TmpRoot)
$requiredRoot = [IO.Path]::GetFullPath((Join-Path $root ".tmp"))
if ($resolvedRoot -cne $requiredRoot) {
    throw "TmpRoot must resolve to the repository .tmp directory: $requiredRoot"
}
if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
    Write-Host "No .tmp directory exists; nothing to rotate."
    exit 0
}

$selectedStages = New-Object System.Collections.Generic.List[object]
foreach ($pattern in $Stage) {
    foreach ($directory in Get-ChildItem -LiteralPath $resolvedRoot -Directory) {
        if ($directory.Name -like $pattern -and -not $selectedStages.Contains($directory)) {
            $selectedStages.Add($directory)
        }
    }
}

$candidates = New-Object System.Collections.Generic.List[object]
foreach ($stageDirectory in $selectedStages) {
    $runs = @(Get-ChildItem -LiteralPath $stageDirectory.FullName -Directory | Sort-Object LastWriteTimeUtc -Descending)
    foreach ($run in @($runs | Select-Object -Skip $Keep)) {
        $candidatePath = [IO.Path]::GetFullPath($run.FullName)
        if (-not $candidatePath.StartsWith($stageDirectory.FullName + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Retention candidate escaped its stage directory: $candidatePath"
        }
        $candidates.Add($run)
    }
}

if (-not $Apply) {
    Write-Host "Dry run: $($candidates.Count) run directories would be removed; pass -Apply to enable deletion."
    $candidates | ForEach-Object { Write-Host $_.FullName }
    exit 0
}

foreach ($candidate in $candidates) {
    if ($PSCmdlet.ShouldProcess($candidate.FullName, "Remove retained .tmp run")) {
        Remove-Item -LiteralPath $candidate.FullName -Recurse -Force
    }
}
Write-Host "Removed $($candidates.Count) expired .tmp run directories; kept the newest $Keep per selected stage."
