param(
    [Parameter(Mandatory = $true)][string]$ProfilePath,
    [string]$GodotPath = "",
    [string]$OutDir = ".tmp/perf06_1/native_runtime",
    [ValidateSet("l02", "grand_casino", "coin_pusher")][string]$Plan = "l02",
    [ValidatePattern("^[A-Za-z0-9_.:-]+$")][string]$EvidenceProfile = "native",
    [int]$Frames = 120,
    [int]$ActiveFrames = 240,
    [int]$MemorySeconds = 600,
    [int]$TimeoutMs = 900000
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$head = (& git -C $root rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or -not $head) { throw "Could not resolve candidate commit." }
if (@(& git -C $root status --short --untracked-files=no).Count -ne 0) { throw "Native runtime measurement requires a clean tracked candidate." }
$profileFile = if ([IO.Path]::IsPathRooted($ProfilePath)) { [IO.Path]::GetFullPath($ProfilePath) } else { [IO.Path]::GetFullPath((Join-Path $root $ProfilePath)) }
if (-not (Test-Path -LiteralPath $profileFile -PathType Leaf)) { throw "Evidence profile is missing: $profileFile" }
$profile = Get-Content -LiteralPath $profileFile -Raw | ConvertFrom-Json
foreach ($field in @("schema", "profile_id", "method", "computer_name", "resolution", "renderer", "power_plan", "hardware_fingerprint_sha256", "hardware")) {
    if (-not ($profile.PSObject.Properties.Name -contains $field)) { throw "Evidence profile is missing '$field'." }
}
$profileHash = (Get-FileHash -LiteralPath $profileFile -Algorithm SHA256).Hash.ToLowerInvariant()
$out = if ([IO.Path]::IsPathRooted($OutDir)) { [IO.Path]::GetFullPath($OutDir) } else { [IO.Path]::GetFullPath((Join-Path $root $OutDir)) }
$tmpRoot = [IO.Path]::GetFullPath((Join-Path $root ".tmp"))
if (-not $out.StartsWith($tmpRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "OutDir must resolve below .tmp." }
if (Test-Path -LiteralPath $out) { throw "Refusing to overwrite immutable native evidence: $out" }
New-Item -ItemType Directory -Path $out | Out-Null

if (-not $GodotPath) { $GodotPath = $env:GODOT_BIN }
if (-not $GodotPath) {
    $common = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
    $GodotPath = Join-Path (Split-Path -Parent $common) ".tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Godot console was not found: $GodotPath" }
$godotHash = (Get-FileHash -LiteralPath $GodotPath -Algorithm SHA256).Hash.ToLowerInvariant()
$exe = Join-Path $out "BeatTheHouse.exe"
$rawReport = Join-Path $out "runtime_report.json"
$exportStdout = Join-Path $out "export.stdout.txt"
$exportStderr = Join-Path $out "export.stderr.txt"

# A Web solver build can legitimately leave only the Web side-module in the
# shared add-on bin directory. Rebuild the locked Windows release input before
# every fresh native export so platform execution order cannot invalidate the
# matrix.
& (Join-Path $PSScriptRoot "build_native_solver.ps1") -Platform Windows -Target template_release -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) { throw "Locked Windows native solver build failed." }
$nativePlugin = Join-Path $root "addons\coin_pusher_native\bin\coin_pusher_native_v3_10.windows.template_release.x86_64.nothreads.dll"
if (-not (Test-Path -LiteralPath $nativePlugin -PathType Leaf)) { throw "Locked Windows native solver binary is missing after build: $nativePlugin" }
$nativePluginHash = (Get-FileHash -LiteralPath $nativePlugin -Algorithm SHA256).Hash.ToLowerInvariant()

$export = Start-Process -FilePath $GodotPath -ArgumentList @("--headless", "--path", $root, "--editor", "--export-release", '"Windows Steam"', $exe) -RedirectStandardOutput $exportStdout -RedirectStandardError $exportStderr -PassThru -WindowStyle Hidden -Wait
if ($export.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Windows release export failed with exit code $($export.ExitCode)." }
$buildHash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
$runStdout = Join-Path $out "runtime.stdout.txt"
$runStderr = Join-Path $out "runtime.stderr.txt"
$args = @(
    "--headless", "--rendering-method", "gl_compatibility", "--",
    "--bth_perf=1", "--bth_perf_plan=$Plan", "--bth_perf_auto_quit=1",
    "--bth_perf_frames=$Frames", "--bth_perf_active_frames=$ActiveFrames",
    "--bth_perf_memory_seconds=$MemorySeconds", "--bth_perf_report=$rawReport",
    "--bth_perf_source_commit=$head", "--bth_perf_export_sha256=$buildHash",
    "--bth_perf_evidence_profile=$EvidenceProfile"
)
$started = Get-Date
$process = Start-Process -FilePath $exe -ArgumentList $args -RedirectStandardOutput $runStdout -RedirectStandardError $runStderr -PassThru -WindowStyle Hidden
if (-not $process.WaitForExit($TimeoutMs)) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    throw "Native runtime matrix timed out after $TimeoutMs ms."
}
$process.Refresh()
$exitCode = $null
try { $exitCode = $process.ExitCode } catch { $exitCode = $null }
if ($null -ne $exitCode -and $exitCode -ne 0) { throw "Native runtime matrix exited $exitCode." }
if (-not (Test-Path -LiteralPath $rawReport -PathType Leaf)) { throw "Native runtime emitted no report." }
if ((& git -C $root rev-parse HEAD).Trim() -cne $head -or @(& git -C $root status --short --untracked-files=no).Count -ne 0) { throw "Tracked candidate changed during native measurement." }
$report = Get-Content -LiteralPath $rawReport -Raw | ConvertFrom-Json
if ([string]$report.build_identity.source_commit -cne $head -or [string]$report.build_identity.export_sha256 -cne $buildHash) { throw "Native report identity does not match the exported candidate." }
if ([string]$report.platform -cne "windows" -or [string]$report.plan -cne $Plan) { throw "Native report platform/plan identity is invalid." }
if ($Plan -eq "coin_pusher") {
    $pusherScenarios = @($report.scenarios | Where-Object { [string]$_.tags.perf06_surface_id -ceq "coin_pusher" })
    if ($pusherScenarios.Count -eq 0) { throw "Native Coin Pusher runtime emitted no canonical phase scenarios." }
    foreach ($scenario in $pusherScenarios) {
        if ([string]$scenario.tags.solver_backend -cne "native_v3") { throw "Native Coin Pusher scenario '$($scenario.name)' used '$($scenario.tags.solver_backend)' instead of native_v3." }
    }
}

$summary = [ordered]@{
    schema = "beat_the_house.perf06_native_runtime/v1"
    passed = $true
    failures = @()
    candidate_commit = $head
    candidate_tree = (& git -C $root rev-parse "HEAD^{tree}").Trim()
    plan = $Plan
    evidence_profile = $EvidenceProfile
    profile_manifest_path = $profileFile
    profile_manifest_sha256 = $profileHash
    host_id = [string]$env:COMPUTERNAME
    resolution = "1280x720"
    renderer = "compatibility"
    power_plan = [string]$profile.power_plan
    actual_cpu_throttle_rate = if ([string]$profile.method -eq "reproducible_whole_matrix_throttle") { [string]$profile.native_processor_affinity_hex } else { "physical" }
    actual_device_scale_factor = 1.0
    godot_sha256 = $godotHash
    native_plugin_sha256 = $nativePluginHash
    build_sha256 = $buildHash
    build_size_bytes = (Get-Item -LiteralPath $exe).Length
    started_utc = $started.ToUniversalTime().ToString("o")
    completed_utc = [DateTime]::UtcNow.ToString("o")
    runtime_report = $rawReport
    runtime_report_sha256 = (Get-FileHash -LiteralPath $rawReport -Algorithm SHA256).Hash.ToLowerInvariant()
    scenario_count = @($report.scenarios).Count
}
$summaryPath = Join-Path $out "summary.json"
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Host "PERF06 NATIVE RUNTIME PASS plan=$Plan scenarios=$(@($report.scenarios).Count) commit=$head out=$out"
