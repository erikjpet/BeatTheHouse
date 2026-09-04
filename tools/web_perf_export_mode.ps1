function Assert-WebPerfExportMode {
    param([string]$Plan, [bool]$SkipExport, [bool]$NoPackageFreshExport)
    if ($SkipExport -and $NoPackageFreshExport) { throw "-SkipExport cannot be combined with -NoPackageFreshExport." }
    if ($Plan -eq "distribution_fresh_start" -and $SkipExport) { throw "Distribution fresh-start evidence requires a fresh Web export." }
}

function Invoke-WebPerfExport {
    param([string]$ExportScript, [bool]$NoPackageFreshExport)
    $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ExportScript, "-Target", "web")
    if ($NoPackageFreshExport) { $arguments += "-NoPackage" }
    & powershell @arguments
    if ($LASTEXITCODE -ne 0) { throw "Web export failed with exit code $LASTEXITCODE." }
}
