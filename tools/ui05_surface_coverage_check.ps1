param(
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = [System.IO.Path]::GetFullPath($Root)
$reportPath = Join-Path $Root "docs/plans/0.5_ui_redesign_report.md"
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "UI 0.5 redesign report is missing."
}
$report = Get-Content -Raw -LiteralPath $reportPath
$supplementPath = Join-Path $Root "docs/plans/0.5_ui_surface_coverage_supplement.json"
$supplementCoverage = @{}
if (Test-Path -LiteralPath $supplementPath -PathType Leaf) {
    $supplement = Get-Content -Raw -LiteralPath $supplementPath | ConvertFrom-Json
    if ([int]$supplement.schema_version -ne 1) {
        throw "UI surface coverage supplement has an unsupported schema version."
    }
    foreach ($entry in @($supplement.coverage)) {
        $path = [string]$entry.path
        $owner = [string]$entry.owner
        $verification = [string]$entry.verification
        if ([string]::IsNullOrWhiteSpace($path) -or [string]::IsNullOrWhiteSpace($owner) -or [string]::IsNullOrWhiteSpace($verification)) {
            throw "UI surface coverage supplement contains an incomplete entry."
        }
        if ($supplementCoverage.ContainsKey($path)) {
            throw "UI surface coverage supplement duplicates '$path'."
        }
        if (-not (Test-Path -LiteralPath (Join-Path $Root $path) -PathType Leaf)) {
            throw "UI surface coverage supplement names missing UI file '$path'."
        }
        if (-not (Test-Path -LiteralPath (Join-Path $Root $verification) -PathType Leaf)) {
            throw "UI surface coverage supplement verification for '$path' is missing: '$verification'."
        }
        $supplementCoverage[$path] = $entry
    }
}
$missing = [System.Collections.Generic.List[string]]::new()
$uiRoot = Join-Path $Root "scripts/ui"
$surfaceFiles = @(Get-ChildItem -LiteralPath $uiRoot -File -Filter "*.gd" | Sort-Object Name)
foreach ($file in $surfaceFiles) {
    $relative = "scripts/ui/$($file.Name)"
    if ($report -notmatch [regex]::Escape($relative) -and -not $supplementCoverage.ContainsKey($relative)) {
        $missing.Add($relative)
    }
}
if ($missing.Count -gt 0) {
    throw "UI redesign report omits scripts/ui files: $($missing -join ', ')"
}
Write-Host ("UI05_SURFACE_COVERAGE_CHECK PASS ({0} scripts/ui files accounted; {1} post-report supplement entries)" -f $surfaceFiles.Count, $supplementCoverage.Count)
