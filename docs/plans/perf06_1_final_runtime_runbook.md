# perf06_1 Final Runtime Runbook

Status: prepared, not executed. Run only after environment and integration
source freeze, from a clean worktree whose `HEAD` is the exact pushed
`origin/main`. Any producer failure stops qualification; do not retry into a
pass, overwrite an evidence directory, or waive a published budget.

The sequence below uses Godot 4.6 stable, Windows PowerShell, Chrome at CPU
throttle 4 for the maintained Web profile, 1280x720 compatibility rendering,
120 idle frames, 240 active frames and 600-second memory windows. Close every
unrelated Godot, BeatTheHouse and Chrome process before starting and keep the
host otherwise quiescent.

## 1. Bind the candidate and capture both host profiles

Run from the repository root:

```powershell
$ErrorActionPreference = "Stop"
$godot = "D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe"
$candidate = (& git rev-parse HEAD).Trim()
$originMain = (& git rev-parse origin/main).Trim()
if ($candidate -cne $originMain) { throw "HEAD is not the pushed origin/main candidate." }
& tools/perf06_binding_preflight.ps1 -CandidateCommit $candidate
if ($LASTEXITCODE -ne 0) { throw "Exact-source and reserved-port binding preflight failed." }
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) { throw "Godot 4.6 stable is missing." }
$busy = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -in @("Godot_v4.6-stable_win64", "Godot_v4.6-stable_win64_console", "BeatTheHouse", "chrome") })
if ($busy.Count -ne 0) { throw "Qualification host is not quiescent: $($busy.ProcessName -join ', ')" }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$tag = "$($candidate.Substring(0,12))-$stamp"
$normalRoot = ".tmp/perf06-final-$tag-normal"
$lowRoot = ".tmp/perf06-final-$tag-low-end"
$normalProfile = ".tmp/perf06-final-$tag-host.json"
$lowProfile = ".tmp/perf06-final-$tag-low-end-host.json"
$beforeQuiescence = Join-Path $normalRoot "quiescence_before.json"
$afterQuiescence = Join-Path $normalRoot "quiescence_after.json"
$seedPrefix = "PERF06-FINAL"
$workerWitness = [string]$env:BTH_PERF_WORKER_WITNESS
$directorWitness = [string]$env:BTH_PERF_DIRECTOR_WITNESS
if ([string]::IsNullOrWhiteSpace($workerWitness) -or [string]::IsNullOrWhiteSpace($directorWitness)) { throw "Set distinct BTH_PERF_WORKER_WITNESS and BTH_PERF_DIRECTOR_WITNESS identities before qualification." }
if ($workerWitness -ceq $directorWitness) { throw "Worker and director quiescence witnesses must be distinct." }
New-Item -ItemType Directory -Path $normalRoot | Out-Null

& tools/perf06_capture_quiescence.ps1 -Stage before -WorkerWitness $workerWitness -DirectorWitness $directorWitness -CandidateCommit $candidate -Out $beforeQuiescence -SampleCount 3 -RequireNoQualificationProcesses
if ($LASTEXITCODE -ne 0) { throw "Before-run quiescence custody failed." }
& tools/perf06_capture_host_profile.ps1 -ProfileId "perf06-final-$tag-host" -Out $normalProfile -Method physical -WebCpuThrottleRate 4
if ($LASTEXITCODE -ne 0) { throw "Normal host-profile capture failed." }
& tools/perf06_capture_host_profile.ps1 -ProfileId "perf06-final-$tag-low-end" -Out $lowProfile -Method reproducible_whole_matrix_throttle -NativeProcessorAffinityHex 0x1 -NativePriorityClass BelowNormal -WebCpuThrottleRate 4
if ($LASTEXITCODE -ne 0) { throw "Low-end host-profile capture failed." }
$normalProfileHash = (Get-FileHash -LiteralPath $normalProfile -Algorithm SHA256).Hash.ToLowerInvariant()
```

Keep the generated `$tag` and variables in the same PowerShell session for all
remaining commands.

## 2. Re-run the parser and non-measurement gates

```powershell
& $godot --headless --path . --editor --quit
if ($LASTEXITCODE -ne 0) { throw "Godot parser/import gate failed." }
& tools/perf06_required_matrix_contract_test.ps1
if ($LASTEXITCODE -ne 0) { throw "Required-matrix contract failed." }
& tools/perf06_budget_contract_test.ps1
if ($LASTEXITCODE -ne 0) { throw "Budget contract failed." }
& tools/perf06_phase_qualification_contract_test.ps1
if ($LASTEXITCODE -ne 0) { throw "Native timing/liveness qualification contract failed." }
& tools/perf06_quiescence_contract_test.ps1
if ($LASTEXITCODE -ne 0) { throw "Quiescence custody contract failed." }
& tools/perf06_binding_preflight_contract_test.ps1
if ($LASTEXITCODE -ne 0) { throw "Binding preflight hostile-fixture contract failed." }
& tools/perf06_allocation_contract_test.ps1
if ($LASTEXITCODE -ne 0) { throw "Allocation negative-fixture contract failed." }
& tools/web_perf_idle_liveness_contract_test.ps1
if ($LASTEXITCODE -ne 0) { throw "Web idle-liveness contract failed." }
& tools/web_perf_coin_pusher_clock_contract_test.ps1
if ($LASTEXITCODE -ne 0) { throw "Coin Pusher clock contract failed." }
& tools/web_perf_prestage_contract_test.ps1
if ($LASTEXITCODE -ne 0) { throw "Web prestage contract failed." }
& tools/perf06_coin_pusher_action_diagnostic_contract.ps1
if ($LASTEXITCODE -ne 0) { throw "Coin Pusher action diagnostic contract failed." }
& tools/perf06_web_complementary_startup_contract.ps1
if ($LASTEXITCODE -ne 0) { throw "Complementary-startup contract failed." }
& tools/perf06_web_run_ui_deferral_contract.ps1
if ($LASTEXITCODE -ne 0) { throw "Run-UI deferral contract failed." }
& tools/coin_pusher_backglass_readability_contract.ps1
if ($LASTEXITCODE -ne 0) { throw "Backglass readability contract failed." }
& tools/perf06_deferred_validation_contract.ps1 -GodotPath $godot
if ($LASTEXITCODE -ne 0) { throw "Deferred-validation runtime contract failed." }
& $godot --headless --path . --script res://tools/perf06_web_ready_snapshot_contract.gd
if ($LASTEXITCODE -ne 0) { throw "Web READY snapshot runtime contract failed." }
& $godot --headless --path . --script res://tools/perf06_idle_liveness_runtime_contract.gd
if ($LASTEXITCODE -ne 0) { throw "Idle-liveness runtime contract failed." }
$candidateTree = (& git rev-parse "HEAD^{tree}").Trim()
& tools/coin_pusher_static_cache_contract.ps1 -GodotPath $godot -OutDir (Join-Path $normalRoot "coin_pusher_static_cache") -SourceHead $candidate -SourceTree $candidateTree
if ($LASTEXITCODE -ne 0) { throw "Coin Pusher production static-cache contract failed." }
```

## 3. Produce normal native evidence

```powershell
$normalAudit = Join-Path $normalRoot "allocation_call_root_audit.json"
& tools/perf06_allocation_call_root_audit.ps1 -CandidateCommit $candidate -Out $normalAudit
if ($LASTEXITCODE -ne 0) { throw "Allocation call-root audit failed." }
& tools/foundation_performance_probe.ps1 -RunCount 8 -FramesPerSurface 120 -ResolveSampleCount 48 -SeedPrefix $seedPrefix -Out (Join-Path $normalRoot "foundation_probe.json") -CandidateCommit $candidate -ProfileManifestSha256 $normalProfileHash -EvidenceProfile native -RequireGodot
if ($LASTEXITCODE -ne 0) { throw "Foundation native probe failed." }

$surfaceReports = [Collections.Generic.List[string]]::new()
$nativeDistribution = Join-Path $normalRoot "native_distribution_fresh_start"
& tools/perf06_native_runtime_matrix.ps1 -ProfilePath $normalProfile -GodotPath $godot -OutDir $nativeDistribution -Plan distribution_fresh_start -EvidenceProfile native -Frames 120 -ActiveFrames 240 -MemorySeconds 600 -TimeoutMs 900000
if ($LASTEXITCODE -ne 0) { throw "Native distribution fresh-start failed." }

foreach ($plan in @("l02", "grand_casino", "coin_pusher")) {
    $run = Join-Path $normalRoot "native_$plan"
    & tools/perf06_native_runtime_matrix.ps1 -ProfilePath $normalProfile -GodotPath $godot -OutDir $run -Plan $plan -EvidenceProfile native -Frames 120 -ActiveFrames 240 -MemorySeconds 600 -TimeoutMs 900000
    if ($LASTEXITCODE -ne 0) { throw "Native $plan runtime failed." }
    $surface = Join-Path $run "surface_report.json"
    & tools/perf06_build_surface_report.ps1 -CandidateCommit $candidate -Platform native -Profile native -ProfilePath $normalProfile -LaunchSummary (Join-Path $run "summary.json") -StaticAudit $normalAudit -Out $surface
    if ($LASTEXITCODE -ne 0) { throw "Native $plan surface report failed." }
    $surfaceReports.Add($surface)
}
```

## 4. Produce normal Web evidence

Run in this order so the L0.2 warm capture immediately follows its cold
capture. Every invocation creates a fresh export; each cold capture clears the
persistent Chrome profile.

```powershell
$webRuns = @(
    @{ plan="distribution_fresh_start"; cache="cold"; port=18730; surface=$false },
    @{ plan="l02"; cache="cold"; port=18731; surface=$true },
    @{ plan="l02"; cache="warm"; port=18732; surface=$true },
    @{ plan="grand_casino"; cache="cold"; port=18733; surface=$true },
    @{ plan="coin_pusher"; cache="cold"; port=18734; surface=$true }
)
foreach ($spec in $webRuns) {
    $webOut = Join-Path $normalRoot ("web_{0}_{1}.json" -f $spec.plan, $spec.cache)
    & tools/web_perf_smoke.ps1 -Browser chrome -Cpu 4 -Port $spec.port -Frames 120 -ActiveFrames 240 -MemorySeconds 600 -TimeoutMs 900000 -Out $webOut -CacheMode $spec.cache -Plan $spec.plan -EvidenceProfile web
    if ($LASTEXITCODE -ne 0) { throw "Web $($spec.plan)/$($spec.cache) runtime failed." }
    if (-not $spec.surface) { continue }
    $summary = [IO.Path]::ChangeExtension($webOut, ".summary.json")
    $surface = [IO.Path]::ChangeExtension($webOut, ".surface.json")
    & tools/perf06_build_surface_report.ps1 -CandidateCommit $candidate -Platform web -Profile web -ProfilePath $normalProfile -LaunchSummary $summary -StaticAudit $normalAudit -Out $surface
    if ($LASTEXITCODE -ne 0) { throw "Web $($spec.plan)/$($spec.cache) surface report failed." }
    $surfaceReports.Add($surface)
}
```

## 5. Produce exact-source integration manifests

```powershell
$compositionOut = Join-Path $normalRoot "integ06_1_composition_matrix"
$terminalOut = Join-Path $normalRoot "integ06_1_terminal_soak"
& tools/integ06_1_composition_matrix.ps1 -CandidateCommit $candidate -ProfilePath $normalProfile -EvidenceProfile final -OutDir $compositionOut -GodotPath $godot -SeedCount 512 -ShardCount 8 -CaseTimeoutSeconds 120 -RequireGodot
if ($LASTEXITCODE -ne 0) { throw "Composition matrix failed." }
& tools/integ06_1_terminal_soak.ps1 -CandidateCommit $candidate -ProfilePath $normalProfile -EvidenceProfile final -OutDir $terminalOut -GodotPath $godot -ShardCount 3 -Cpu 4 -TimeoutMs 900000 -WebPort 18735 -RequireGodot
if ($LASTEXITCODE -ne 0) { throw "Terminal soak failed." }
$compositionManifest = Join-Path $compositionOut "manifest.json"
$terminalManifest = Join-Path $terminalOut "manifest.json"

& tools/perf06_matrix_contract.ps1 -CandidateCommit $candidate -CompositionManifest $compositionManifest -TerminalManifest $terminalManifest -SurfaceReports $surfaceReports.ToArray() -RequiredProfiles @("native", "web") -Out (Join-Path $normalRoot "matrix_contract_native_web.json")
if ($LASTEXITCODE -ne 0) { throw "Native/Web matrix contract failed." }
```

## 6. Run the declared low-end whole matrix

The low-end launcher repeats the same native, Web and integration producers
under the declared one-logical-CPU/BelowNormal whole-process constraint and
Web CPU throttle 4. Its own preflight and matrix consumer are mandatory.

```powershell
& tools/perf06_low_end_matrix.ps1 -ProfilePath $lowProfile -GodotPath $godot -OutDir "$lowRoot-preflight" -PreflightOnly -RequireGodot
if ($LASTEXITCODE -ne 0) { throw "Low-end preflight failed." }
& tools/perf06_low_end_matrix.ps1 -ProfilePath $lowProfile -GodotPath $godot -OutDir $lowRoot -SeedPrefix $seedPrefix -RequireGodot
if ($LASTEXITCODE -ne 0) { throw "Low-end matrix failed." }
```

## 7. Consume all three profiles and freeze the evidence

```powershell
$lowSurfaceReports = @(Get-ChildItem -LiteralPath $lowRoot -Recurse -File | Where-Object { $_.Name -eq "surface_report.json" -or $_.Name -like "*.surface.json" } | ForEach-Object FullName)
$allSurfaceReports = @($surfaceReports.ToArray()) + $lowSurfaceReports
$finalMatrix = Join-Path $normalRoot "matrix_contract_all_profiles.json"
& tools/perf06_matrix_contract.ps1 -CandidateCommit $candidate -CompositionManifest $compositionManifest -TerminalManifest $terminalManifest -SurfaceReports $allSurfaceReports -RequiredProfiles @("native", "web", "low_end") -Out $finalMatrix
if ($LASTEXITCODE -ne 0) { throw "Combined three-profile matrix contract failed." }
if (& git status --porcelain=v1 --untracked-files=all) { throw "Tracked, index or nonignored untracked source changed during qualification." }

$matrix = Get-Content -LiteralPath $finalMatrix -Raw | ConvertFrom-Json
if (-not $matrix.passed) { throw "Final matrix did not pass." }
if (@($matrix.coverage | Where-Object { -not $_.present }).Count -ne 0) { throw "Final matrix has missing cells." }
if (@($matrix.coverage | Where-Object { $_.samples -le 0 }).Count -ne 0) { throw "Final matrix contains an empty coverage row." }
& tools/perf06_capture_quiescence.ps1 -Stage after -WorkerWitness $workerWitness -DirectorWitness $directorWitness -CandidateCommit $candidate -Out $afterQuiescence -SampleCount 3 -RequireNoQualificationProcesses
if ($LASTEXITCODE -ne 0) { throw "After-run quiescence custody failed." }
Get-ChildItem -LiteralPath $normalRoot, $lowRoot -Recurse -File |
    Get-FileHash -Algorithm SHA256 |
    Sort-Object Path |
    ForEach-Object { "{0}  {1}" -f $_.Hash.ToLowerInvariant(), $_.Path } |
    Set-Content -LiteralPath (Join-Path $normalRoot "artifact_sha256.txt") -Encoding utf8
```

Only after this final consumer passes every published timing check, every real
liveness floor and its 336-cell matrix may the producer findings and artifact
hashes be copied into the performance report and the board row be considered
for DONE. A red budget remains red unless the owner records an explicit
exception; this runbook does not create one.
