$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "web_perf_export_mode.ps1")
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$temp = [IO.Path]::GetFullPath((Join-Path $root ".tmp/web_perf_export_mode_contract/$([guid]::NewGuid().ToString('N'))"))
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $root ".tmp/web_perf_export_mode_contract"))
$failures = [Collections.Generic.List[string]]::new()

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { $script:failures.Add($Message) } }
function Capture-Failure([scriptblock]$Action) {
    try { & $Action; return "" } catch { return $_.Exception.Message }
}

try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $receipt = Join-Path $temp "receipt.json"
    $stub = Join-Path $temp "stub_export.ps1"
    $stubSource = @'
param([string]$Target, [switch]$NoPackage)
[ordered]@{ target = $Target; no_package = [bool]$NoPackage } | ConvertTo-Json | Set-Content -LiteralPath $env:PLAYTEST06_EXPORT_RECEIPT -Encoding utf8
'@
    Set-Content -LiteralPath $stub -Value $stubSource -Encoding utf8
    $priorReceipt = $env:PLAYTEST06_EXPORT_RECEIPT
    try {
        $env:PLAYTEST06_EXPORT_RECEIPT = $receipt
        Assert-WebPerfExportMode -Plan "distribution_fresh_start" -SkipExport:$false -NoPackageFreshExport:$true
        Invoke-WebPerfExport -ExportScript $stub -NoPackageFreshExport:$true
    } finally { $env:PLAYTEST06_EXPORT_RECEIPT = $priorReceipt }
    $positive = Get-Content -LiteralPath $receipt -Raw | ConvertFrom-Json
    Assert-True ([string]$positive.target -eq "web" -and [bool]$positive.no_package) "Fresh Web export integration did not pass -Target web -NoPackage."

    $message = Capture-Failure { Assert-WebPerfExportMode -Plan "distribution_fresh_start" -SkipExport:$true -NoPackageFreshExport:$false }
    Assert-True ($message.Contains("requires a fresh Web export")) "Distribution fresh-start accepted SkipExport."
    $message = Capture-Failure { Assert-WebPerfExportMode -Plan "distribution_fresh_start" -SkipExport:$true -NoPackageFreshExport:$true }
    Assert-True ($message.Contains("cannot be combined")) "Export mode accepted SkipExport plus NoPackageFreshExport."

    if ($failures.Count -gt 0) {
        Write-Host "web perf export mode contract: FAIL ($($failures.Count))" -ForegroundColor Red
        foreach ($failure in $failures) { Write-Host " - $failure" }
        exit 1
    }
    Write-Host "web perf export mode contract: PASS fresh_web_no_package=executed hostile_modes=2"
}
finally {
    if (Test-Path -LiteralPath $temp) {
        $resolved = [IO.Path]::GetFullPath($temp)
        if (-not $resolved.StartsWith($allowedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing to remove export-mode test output outside its dedicated root." }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
