$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$matrix = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_required_matrix.json") -Raw | ConvertFrom-Json
$fixture = Get-Content -LiteralPath (Join-Path $root "scripts/tests/fixtures/perf06/uninstrumented_phase_samples.json") -Raw | ConvertFrom-Json
$validatorText = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_matrix_contract.ps1") -Raw
$overlayText = Get-Content -LiteralPath (Join-Path $root "scripts/ui/perf_telemetry_overlay.gd") -Raw

function Test-AllocationCoverage($Row) {
    $required = @($matrix.allocation_roots.PSObject.Properties[[string]$Row.surface_id].Value)
    $audited = @($Row.allocation_copy_counters.audited_call_roots)
    if (-not [bool]$Row.allocation_copy_counters.coverage_complete -or $audited.Count -eq 0) { return $false }
    foreach ($rootName in $required) { if ($audited -cnotcontains [string]$rootName) { return $false } }
    return $true
}

foreach ($row in @($fixture.rows)) {
    if (Test-AllocationCoverage $row) { throw "Negative allocation fixture '$($row.id)' unexpectedly passed." }
}
foreach ($needle in @("audited_call_roots", "required allocation roots", "static_call_root_audit_sha256", "coverage_complete")) {
    if (-not $validatorText.Contains($needle)) { throw "Matrix validator lost fail-closed allocation check '$needle'." }
}
foreach ($needle in @("ALLOCATION_COPY_SOURCE_IDS", "mark_allocation_root_audited", "explicit_allocation_audited_sources", '"coverage_complete"')) {
    if (-not $overlayText.Contains($needle)) { throw "Opt-in allocation seam lost '$needle'." }
}
Write-Host "PERF06 ALLOCATION CONTRACT PASS negative=empty,partial"
