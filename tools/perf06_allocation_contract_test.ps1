$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$matrix = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_required_matrix.json") -Raw | ConvertFrom-Json
$budget = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_budget_table.json") -Raw | ConvertFrom-Json
$fixture = Get-Content -LiteralPath (Join-Path $root "scripts/tests/fixtures/perf06/uninstrumented_phase_samples.json") -Raw | ConvertFrom-Json
$validatorText = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_matrix_contract.ps1") -Raw
$overlayText = Get-Content -LiteralPath (Join-Path $root "scripts/ui/perf_telemetry_overlay.gd") -Raw
$builderText = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_build_surface_report.ps1") -Raw
. (Join-Path $PSScriptRoot "perf06_phase_qualification_contract.ps1")

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
foreach ($row in @($fixture.assertion_rows)) {
    $evaluation = Get-Perf06AllocationCopyAssertion -Counters $row.allocation_copy_counters -FrameCount ([int]$row.frame_count) -SteadyStateDeepCopiesMaximum ([int64]$budget.policy.steady_state_deep_copies_max)
    if ([bool]$evaluation.passed -ne [bool]$row.expected_pass) { throw "Allocation assertion fixture '$($row.id)' expected pass=$($row.expected_pass), got pass=$($evaluation.passed)." }
    if ([bool]$row.expected_pass -and ([double]$evaluation.allocations_per_frame -ne 0.1 -or [double]$evaluation.deep_copies_per_frame -ne 0.0)) { throw "Allocation assertion did not retain per-frame rates." }
}
$orderedCounters = [ordered]@{ allocations=12; shallow_copies=2; deep_copies=0; bytes=4096; source="explicit_instrumented_probe"; scope="steady_state_frame"; evidence_kind="explicit_counter" }
if (-not (Get-Perf06AllocationCopyAssertion -Counters $orderedCounters -FrameCount 120).passed) { throw "Real producer ordered-dictionary allocation counters did not pass." }
foreach ($needle in @("audited_call_roots", "required allocation roots", "static_call_root_audit_sha256", "coverage_complete")) {
    if (-not $validatorText.Contains($needle)) { throw "Matrix validator lost fail-closed allocation check '$needle'." }
}
foreach ($needle in @("ALLOCATION_COPY_SOURCE_IDS", "mark_allocation_root_audited", "explicit_allocation_audited_sources", '"coverage_complete"')) {
    if (-not $overlayText.Contains($needle)) { throw "Opt-in allocation seam lost '$needle'." }
}
if ($overlayText -notmatch 'allocation_source := "foundation_snapshot" if subsystem == "snapshot_builds" else subsystem' -or $overlayText -notmatch 'mark_allocation_root_audited\(allocation_source\)') {
    throw "Measured foundation subsystem execution no longer marks its allocation call root without shared foundation_main instrumentation."
}
foreach ($needle in @("Get-Perf06AllocationCopyAssertion", "allocation_copy_assertion")) {
    if (-not $builderText.Contains($needle)) { throw "Surface-report producer lost allocation assertion wiring '$needle'." }
}
foreach ($needle in @("Get-Perf06AllocationCopyAssertion", "allocation/copy assertion is absent, stale, or failed")) {
    if (-not $validatorText.Contains($needle)) { throw "Final matrix consumer lost allocation assertion wiring '$needle'." }
}
Write-Host "PERF06 ALLOCATION CONTRACT PASS coverage_negative=empty,partial assertion_negative=deep_copy,negative_counter,warmup_scope"
