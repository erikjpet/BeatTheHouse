$ErrorActionPreference = "Stop"
$capture = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_capture_quiescence.ps1") -Raw
$runbook = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) "docs/plans/perf06_1_final_runtime_runbook.md") -Raw

foreach ($token in @("WorkerWitness", "DirectorWitness", '[ValidateRange(3, 3)][int]$SampleCount = 3', "idle_cpu_memory_samples", "process_inventory", "Refusing to overwrite immutable quiescence evidence", "RequireNoQualificationProcesses")) {
    if (-not $capture.Contains($token)) { throw "Quiescence capture lost '$token'." }
}
foreach ($token in @('BTH_PERF_WORKER_WITNESS', 'BTH_PERF_DIRECTOR_WITNESS', '-Stage before', '-Stage after', '-SampleCount 3', '$beforeQuiescence', '$afterQuiescence')) {
    if (-not $runbook.Contains($token)) { throw "Final runbook lost quiescence custody '$token'." }
}
$beforeIndex = $runbook.IndexOf('-Stage before')
$nativeIndex = $runbook.IndexOf('## 3. Produce normal native evidence')
$afterIndex = $runbook.IndexOf('-Stage after')
$consumeIndex = $runbook.IndexOf('$matrix = Get-Content')
if ($beforeIndex -lt 0 -or $nativeIndex -lt 0 -or $beforeIndex -gt $nativeIndex) { throw "Before custody is not sequenced before measurement." }
if ($afterIndex -lt 0 -or $consumeIndex -lt 0 -or $afterIndex -lt $consumeIndex) { throw "After custody is not sequenced after the final consumer." }

Write-Host "PERF06 QUIESCENCE CONTRACT PASS samples=3 witnesses=worker,director inventories=before,after"
