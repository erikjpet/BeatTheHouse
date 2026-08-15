$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$wrapper = Join-Path $PSScriptRoot "crew_poker_visual_capture.ps1"
$contractDir = Join-Path $root ".tmp\crew_poker_wrapper_contract"
$manifestPath = Join-Path $contractDir "manifest.json"
New-Item -ItemType Directory -Path $contractDir -Force | Out-Null

if (Test-Path -LiteralPath $manifestPath) {
    Remove-Item -LiteralPath $manifestPath -Force
}
& powershell -NoProfile -ExecutionPolicy Bypass -File $wrapper -ManifestOnly -ManifestPath $manifestPath
if ($LASTEXITCODE -eq 0) {
    throw "Crew poker wrapper accepted a missing manifest."
}

Set-Content -LiteralPath $manifestPath -Encoding UTF8 -Value '{"passed":false}'
& powershell -NoProfile -ExecutionPolicy Bypass -File $wrapper -ManifestOnly -ManifestPath $manifestPath
if ($LASTEXITCODE -eq 0) {
    throw "Crew poker wrapper accepted passed=false."
}

Set-Content -LiteralPath $manifestPath -Encoding UTF8 -Value '{"passed":true}'
& powershell -NoProfile -ExecutionPolicy Bypass -File $wrapper -ManifestOnly -ManifestPath $manifestPath
if ($LASTEXITCODE -ne 0) {
    throw "Crew poker wrapper rejected passed=true."
}

Remove-Item -LiteralPath $manifestPath -Force
Write-Host "CREW_POKER_VISUAL_CAPTURE_WRAPPER_CHECK_PASS"
