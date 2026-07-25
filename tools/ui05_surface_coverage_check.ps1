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
$missing = [System.Collections.Generic.List[string]]::new()
$uiRoot = Join-Path $Root "scripts/ui"
$surfaceFiles = @(Get-ChildItem -LiteralPath $uiRoot -File -Filter "*.gd" | Sort-Object Name)
foreach ($file in $surfaceFiles) {
    $relative = "scripts/ui/$($file.Name)"
    if ($report -notmatch [regex]::Escape($relative)) {
        $missing.Add($relative)
    }
}
if ($missing.Count -gt 0) {
    throw "UI redesign report omits scripts/ui files: $($missing -join ', ')"
}
Write-Host ("UI05_SURFACE_COVERAGE_CHECK PASS ({0} scripts/ui files accounted)" -f $surfaceFiles.Count)
