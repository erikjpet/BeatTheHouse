param(
    [Parameter(Mandatory = $true)][string]$CandidateCommit,
    [Parameter(Mandatory = $true)][string]$ProfilePath,
    [Parameter(Mandatory = $true)][string]$EvidenceProfile,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$GodotPath = "",
    [string]$ToolRoot = "",
    [int]$ShardCount = 3,
    [int]$Cpu = 4,
    [int]$TimeoutMs = 900000,
    [int]$WebPort = 18141,
    [switch]$RequireGodot
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if ($ShardCount -lt 1) { throw "ShardCount must be positive." }
if ($Cpu -lt 1) { throw "Cpu must be positive." }
if ($TimeoutMs -lt 1) { throw "TimeoutMs must be positive." }
$candidate = (& git -C $root rev-parse "$CandidateCommit^{commit}").Trim()
if ($LASTEXITCODE -ne 0 -or -not $candidate) { throw "CandidateCommit does not resolve to a commit." }
$head = (& git -C $root rev-parse HEAD).Trim()
if ($head -cne $candidate) { throw "HEAD $head does not equal CandidateCommit $candidate." }
& git -C $root diff --quiet
if ($LASTEXITCODE -ne 0) { throw "Tracked working tree changes make exact-source evidence invalid." }
& git -C $root diff --cached --quiet
if ($LASTEXITCODE -ne 0) { throw "Staged changes make exact-source evidence invalid." }
$candidateTree = (& git -C $root rev-parse "$candidate^{tree}").Trim()
$resolvedProfile = [IO.Path]::GetFullPath((Join-Path $root $ProfilePath))
if (-not (Test-Path -LiteralPath $resolvedProfile -PathType Leaf)) { throw "Evidence profile not found: $resolvedProfile" }
$profileHash = (Get-FileHash -LiteralPath $resolvedProfile -Algorithm SHA256).Hash.ToLowerInvariant()

if (-not $GodotPath) { $GodotPath = $env:GODOT_BIN }
if (-not $GodotPath) {
    $common = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
    $candidateGodot = Join-Path (Split-Path -Parent $common) ".tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe"
    if (Test-Path -LiteralPath $candidateGodot -PathType Leaf) { $GodotPath = $candidateGodot }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    if ($RequireGodot) { throw "Godot console was not found; pass -GodotPath or set GODOT_BIN." }
    Write-Host "INTEG06_1_TERMINAL_SOAK NOT RUN (Godot unavailable)."
    exit 0
}

$out = [IO.Path]::GetFullPath((Join-Path $root $OutDir))
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $root ".tmp"))
if (-not $out.StartsWith($allowedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutDir must resolve below the repository .tmp directory: $out"
}
if (Test-Path -LiteralPath $out) { throw "OutDir already exists; evidence directories are immutable: $out" }

$toolFiles = @(
    (Join-Path $root "tools\integ06_1_terminal_soak.ps1"),
    (Join-Path $root "tools\integ06_1_terminal_soak_main.gd"),
    (Join-Path $root "tools\integ06_1_terminal_soak_main.tscn"),
    (Join-Path $root "tools\integ06_1_terminal_soak_web_capture.mjs"),
    (Join-Path $root "tools\endgame_metrics_probe.gd")
)
$toolHashInput = ($toolFiles | Sort-Object | ForEach-Object { "$(Split-Path -Leaf $_):$((Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant())" }) -join "`n"
$sha = [Security.Cryptography.SHA256]::Create()
try { $toolHash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($toolHashInput)))).Replace("-", "").ToLowerInvariant() }
finally { $sha.Dispose() }

New-Item -ItemType Directory -Path $out | Out-Null
$project = Join-Path $out "project"
$webBuild = Join-Path $out "web_build"
$nativeBuild = Join-Path $out "native_build"
New-Item -ItemType Directory -Path $project, $webBuild, $nativeBuild | Out-Null

function Invoke-BoundedProcess {
    param([string]$FilePath, [string[]]$ArgumentList, [string]$StdoutPath, [string]$StderrPath, [string]$Label, [switch]$AllowFailure)
    $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath -PassThru -WindowStyle Hidden
    $null = $process.Handle
    if (-not $process.WaitForExit($TimeoutMs)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "$Label timed out after $TimeoutMs ms; see $StdoutPath and $StderrPath."
    }
    $process.WaitForExit()
    $process.Refresh()
    if (-not $AllowFailure -and $process.ExitCode -ne 0) { throw "$Label failed with exit $($process.ExitCode); see $StdoutPath and $StderrPath." }
    return $process.ExitCode
}

function Read-TerminalMarker {
    param([string]$StdoutPath, [string]$Label)
    $line = Get-Content -LiteralPath $StdoutPath | Where-Object { $_.StartsWith("INTEG06_1_TERMINAL_SOAK=") } | Select-Object -Last 1
    if (-not $line) { throw "$Label emitted no INTEG06_1_TERMINAL_SOAK marker." }
    return ($line.Substring("INTEG06_1_TERMINAL_SOAK=".Length) | ConvertFrom-Json)
}

function Assert-Provenance {
    param($Report, [string]$Label, [string]$Platform)
    if ([string]$Report.schema -cne "beat_the_house.integ06_1_terminal_soak_shard/v1" -or [int]$Report.version -ne 1) { throw "$Label has the wrong schema." }
    if ([string]$Report.candidate_commit -cne $candidate -or [string]$Report.candidate_tree -cne $candidateTree) { throw "$Label has stale candidate provenance." }
    if ([string]$Report.tool_source_sha256 -cne $toolHash) { throw "$Label has stale tool provenance." }
    if ([string]$Report.profile.sha256 -cne $profileHash -or [string]$Report.profile.evidence_profile -cne $EvidenceProfile) { throw "$Label has stale evidence-profile provenance." }
    if ([string]$Report.platform -cne $Platform) { throw "$Label reported platform $([string]$Report.platform), expected $Platform." }
}

foreach ($fileName in @("icon.svg", "project.godot", "export_presets.cfg")) {
    Copy-Item -LiteralPath (Join-Path $root $fileName) -Destination (Join-Path $project $fileName)
}
foreach ($directoryName in @("assets", "data", "scenes", "scripts", "tools", "native")) {
    $source = Join-Path $root $directoryName
    if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw "Transient project source is missing: $source" }
    Copy-Item -LiteralPath $source -Destination $project -Recurse
}
$common = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
$canonicalRepoRoot = Split-Path -Parent $common
$canonicalAddon = Join-Path $canonicalRepoRoot "addons\coin_pusher_native"
$requiredHostLibraries = @(
    "bin\coin_pusher_native.windows.template_debug.x86_64.nothreads.dll",
    "bin\coin_pusher_native.windows.template_release.x86_64.nothreads.dll"
)
if (-not (Test-Path -LiteralPath $canonicalAddon -PathType Container)) { throw "Canonical read-only native addon prerequisite is missing: $canonicalAddon" }
foreach ($relativeHostLibrary in $requiredHostLibraries) {
    if (-not (Test-Path -LiteralPath (Join-Path $canonicalAddon $relativeHostLibrary) -PathType Leaf)) { throw "Required Windows host library is unavailable: $relativeHostLibrary" }
}
New-Item -ItemType Directory -Path (Join-Path $project "addons") | Out-Null
Copy-Item -LiteralPath $canonicalAddon -Destination (Join-Path $project "addons") -Recurse
$transientSource = Join-Path $project "native\coin_pusher"
$transientAddon = Join-Path $project "addons\coin_pusher_native"
Copy-Item -LiteralPath (Join-Path $transientSource "coin_pusher_native.gdextension.template") -Destination (Join-Path $transientAddon "coin_pusher_native.gdextension") -Force

$toolRoot = if ($ToolRoot) { [IO.Path]::GetFullPath($ToolRoot) } else { Join-Path $canonicalRepoRoot ".tools\native_solver" }
$python = Join-Path $toolRoot "python\python.exe"
$wheel = Join-Path $toolRoot "downloads\scons-4.10.1-py3-none-any.whl"
$godotCpp = Join-Path $toolRoot "godot-cpp"
$emsdkEnvironment = Join-Path $toolRoot "emsdk\emsdk_env.ps1"
foreach ($required in @($python, $wheel, (Join-Path $godotCpp "SConstruct"), $emsdkEnvironment)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Pinned Web compiler prerequisite is missing: $required" }
}
$nativeLock = Get-Content -LiteralPath (Join-Path $transientSource "toolchain.lock.json") -Raw | ConvertFrom-Json
. $emsdkEnvironment | Out-Null
$sconsArguments = @("scons", "-C", $transientSource, "-j", "15", "platform=web", "target=template_release", "arch=wasm32", "threads=no", "api_version=$([string]$nativeLock.godot_cpp.api_version)", "godot_cpp_dir=$godotCpp")
$env:BTH_INTEG06_1_SCONS_WHEEL = $wheel
$env:BTH_INTEG06_1_SCONS_ARGUMENTS = ConvertTo-Json -Compress $sconsArguments
$buildRunner = Join-Path $out "run_transient_scons.py"
@'
import json, os, sys
sys.path.insert(0, os.environ["BTH_INTEG06_1_SCONS_WHEEL"])
from SCons.Script import main
sys.argv = json.loads(os.environ["BTH_INTEG06_1_SCONS_ARGUMENTS"])
main()
'@ | Set-Content -LiteralPath $buildRunner
Invoke-BoundedProcess -FilePath $python -ArgumentList @($buildRunner) -StdoutPath (Join-Path $out "web_native_build.stdout.txt") -StderrPath (Join-Path $out "web_native_build.stderr.txt") -Label "fresh transient Web native-solver build" | Out-Null
if (@(Get-ChildItem -LiteralPath (Join-Path $transientAddon "bin") -Filter "*.wasm" -File).Count -lt 1) { throw "Fresh transient Web native-solver build emitted no side module." }

$projectPath = Join-Path $project "project.godot"
$projectText = (Get-Content -LiteralPath $projectPath -Raw).Replace('run/main_scene="res://scenes/main.tscn"', 'run/main_scene="res://tools/integ06_1_terminal_soak_main.tscn"')
if (-not $projectText.Contains('run/main_scene="res://tools/integ06_1_terminal_soak_main.tscn"')) { throw "Transient project main-scene replacement failed." }
Set-Content -LiteralPath $projectPath -Value $projectText
$presetsPath = Join-Path $project "export_presets.cfg"
$presetsText = (Get-Content -LiteralPath $presetsPath -Raw).Replace(',tools/*,tools/**', '').Replace('binary_format/embed_pck=true', 'binary_format/embed_pck=false')
if ($presetsText.Contains(',tools/*,tools/**')) { throw "Transient export preset still excludes probe tools." }
Set-Content -LiteralPath $presetsPath -Value $presetsText

$nativeExe = Join-Path $nativeBuild "integ06_1_terminal_soak.exe"
Invoke-BoundedProcess -FilePath $GodotPath -ArgumentList @("--headless", "--path", $project, "--editor", "--export-release", '"Windows Steam"', $nativeExe) -StdoutPath (Join-Path $out "native_export.stdout.txt") -StderrPath (Join-Path $out "native_export.stderr.txt") -Label "fresh transient Windows release export" | Out-Null
if (-not (Test-Path -LiteralPath $nativeExe -PathType Leaf)) { throw "Windows release export emitted no executable." }

function Invoke-NativeShard {
    param([int]$ShardIndex, [int]$Repeat)
    $stem = "shard_${ShardIndex}_native_$Repeat"
    $stdout = Join-Path $out "$stem.stdout.txt"
    $stderr = Join-Path $out "$stem.stderr.txt"
    $dataRoot = Join-Path $out "${stem}_data"
    New-Item -ItemType Directory -Path $dataRoot | Out-Null
    $previousData = $env:BTH_DISTRIBUTION_DATA_ROOT
    $previousBuild = $env:BTH_DISTRIBUTION_BUILD
    try {
        $env:BTH_DISTRIBUTION_BUILD = "1"
        $env:BTH_DISTRIBUTION_DATA_ROOT = $dataRoot
        Invoke-BoundedProcess -FilePath $nativeExe -ArgumentList @("--headless", "--rendering-method", "gl_compatibility", "--", "--candidate-commit=$candidate", "--candidate-tree=$candidateTree", "--tool-source-sha256=$toolHash", "--evidence-profile=$EvidenceProfile", "--profile-path=$resolvedProfile", "--profile-sha256=$profileHash", "--shard-index=$ShardIndex", "--shard-count=$ShardCount") -StdoutPath $stdout -StderrPath $stderr -Label $stem -AllowFailure | Out-Null
    } finally {
        $env:BTH_DISTRIBUTION_DATA_ROOT = $previousData
        $env:BTH_DISTRIBUTION_BUILD = $previousBuild
    }
    $report = Read-TerminalMarker -StdoutPath $stdout -Label $stem
    Assert-Provenance -Report $report -Label $stem -Platform "Windows"
    $report | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $out "$stem.json")
    return $report
}

$nativeFirst = @{}
$nativeSecond = @{}
for ($shard = 0; $shard -lt $ShardCount; $shard++) {
    $nativeFirst[$shard] = Invoke-NativeShard -ShardIndex $shard -Repeat 1
    $nativeSecond[$shard] = Invoke-NativeShard -ShardIndex $shard -Repeat 2
}

$webIndex = Join-Path $webBuild "index.html"
Invoke-BoundedProcess -FilePath $GodotPath -ArgumentList @("--headless", "--path", $project, "--editor", "--export-release", "Web", $webIndex) -StdoutPath (Join-Path $out "web_export.stdout.txt") -StderrPath (Join-Path $out "web_export.stderr.txt") -Label "fresh transient Web release export" | Out-Null
if (-not (Test-Path -LiteralPath $webIndex -PathType Leaf)) { throw "Web release export emitted no index.html." }

$server = Start-Process -FilePath "powershell" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $root "tools\serve_web.ps1"), "-Port", $WebPort, "-ServeRoot", $webBuild, "-NoBrowser") -RedirectStandardOutput (Join-Path $out "web_server.stdout.txt") -RedirectStandardError (Join-Path $out "web_server.stderr.txt") -PassThru -WindowStyle Hidden
$webReports = @{}
try {
    $ready = $false
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    do {
        try { $ready = (Invoke-WebRequest -Uri "http://127.0.0.1:$WebPort/index.html" -UseBasicParsing -TimeoutSec 1).StatusCode -eq 200 } catch { $ready = $false }
        if (-not $ready) { Start-Sleep -Milliseconds 100 }
    } while (-not $ready -and [DateTime]::UtcNow -lt $deadline)
    if (-not $ready) { throw "Transient Web server did not become ready." }
    $playwrightPackage = Join-Path $canonicalRepoRoot ".tmp\l02_playwright\package.json"
    $chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
    for ($shard = 0; $shard -lt $ShardCount; $shard++) {
        $stem = "shard_${shard}_web"
        $webJson = Join-Path $out "$stem.json"
        $query = "candidate-commit=$candidate&candidate-tree=$candidateTree&tool-source-sha256=$toolHash&evidence-profile=$([Uri]::EscapeDataString($EvidenceProfile))&profile-path=$([Uri]::EscapeDataString($resolvedProfile))&profile-sha256=$profileHash&shard-index=$shard&shard-count=$ShardCount"
        Invoke-BoundedProcess -FilePath "node" -ArgumentList @((Join-Path $root "tools\integ06_1_terminal_soak_web_capture.mjs"), "--url=http://127.0.0.1:$WebPort/index.html?$query", "--out=$webJson", "--profile=$(Join-Path $out "${stem}_profile")", "--cpu=$Cpu", "--timeout-ms=$TimeoutMs", "--playwright-package=$playwrightPackage", ('--chrome={0}' -f $chrome)) -StdoutPath (Join-Path $out "$stem.stdout.txt") -StderrPath (Join-Path $out "$stem.stderr.txt") -Label $stem -AllowFailure | Out-Null
        if (-not (Test-Path -LiteralPath $webJson -PathType Leaf)) { throw "$stem emitted no report." }
        $report = Get-Content -LiteralPath $webJson -Raw | ConvertFrom-Json
        Assert-Provenance -Report $report -Label $stem -Platform "Web"
        $webReports[$shard] = $report
    }
} finally {
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
}

$failures = @()
$rows = @()
$seedIds = @()
$artifacts = @()
$activeSystems = @()
for ($shard = 0; $shard -lt $ShardCount; $shard++) {
    $first = $nativeFirst[$shard]
    $second = $nativeSecond[$shard]
    $web = $webReports[$shard]
    if (-not $first.passed) { $failures += "Native shard $shard did not pass: $(@($first.failures) -join '; ')" }
    if (-not $second.passed) { $failures += "Native repeat shard $shard did not pass: $(@($second.failures) -join '; ')" }
    if (-not $web.passed) { $failures += "Web shard $shard did not pass: $(@($web.failures) -join '; ')" }
    if ([string]$first.semantic_trace_sha256 -cne [string]$second.semantic_trace_sha256) { $failures += "Native shard $shard repeat trace differs." }
    if ([string]$first.semantic_trace_sha256 -cne [string]$web.semantic_trace_sha256) { $failures += "Native/Web shard $shard trace differs." }
    $rows += @($first.rows)
    $seedIds += @($first.shard.seed_ids)
    $activeSystems += @($first.active_systems)
    $artifacts += @("shard_${shard}_native_1.json", "shard_${shard}_native_2.json", "shard_${shard}_web.json")
}
$routeRows = @($rows | Where-Object { [string]$_.terminal.status -eq "ended" } | ForEach-Object { [string]$_.terminal.route } | Sort-Object -Unique)
$failureRows = @($rows | Where-Object { [string]$_.terminal.status -eq "failed" } | ForEach-Object { [string]$_.terminal.failure_reason } | Sort-Object -Unique)
$expectedVictoryRoutes = @("high_roller_cashout", "pit_boss_showdown", "crew_heist")
foreach ($route in $expectedVictoryRoutes) { if ($routeRows -cnotcontains $route) { $failures += "Missing terminal victory route: $route" } }
if ($failureRows.Count -lt 2) { $failures += "Terminal soak covered fewer than two distinct failure routes." }
$control = @($rows | Where-Object { $_.crew_ignoring_control })
if ($control.Count -ne 1 -or @($control[0].lender_ids) -ccontains "the_crew") { $failures += "Crew-ignoring control was missing or used the Crew lender." }
if ($rows.Count -ne 9) { $failures += "Expected 9 documented terminal seed cases, got $($rows.Count)." }

$manifest = [ordered]@{
    schema = "beat_the_house.integ06_1_terminal_soak_manifest/v1"
    version = 1
    candidate_commit = $candidate
    candidate_tree = $candidateTree
    tool_source_sha256 = $toolHash
    profile = [ordered]@{ evidence_profile = $EvidenceProfile; path = $resolvedProfile; sha256 = $profileHash }
    shard = [ordered]@{ count = $ShardCount; seed_ids = @($seedIds | Sort-Object -Unique) }
    platform = @("Windows", "Web")
    active_systems = @($activeSystems | Sort-Object -Unique)
    authored_max_counts = [ordered]@{ documented_seed_cases = 9; victory_routes = 3; representative_failure_routes_min = 2 }
    phase_samples = @()
    phase_samples_status = [ordered]@{ available = $false; reason = "Frame trajectory is consumed from the exact-candidate perf06_1 release manifest." }
    lifecycle_status = if ($failures.Count -eq 0) { "clean" } else { "failed" }
    terminal = [ordered]@{ status = if ($failures.Count -eq 0) { "covered" } else { "incomplete" }; routes = $routeRows; failure_reasons = $failureRows; profile_recorded = @($rows | Where-Object { -not $_.terminal.profile_recorded }).Count -eq 0 }
    semantic_trace_sha256 = (($nativeFirst.Keys | Sort-Object | ForEach-Object { [string]$nativeFirst[$_].semantic_trace_sha256 }) -join ":")
    save_load_points = ($rows | Measure-Object -Property save_load_count -Sum).Sum
    retained_counters = [ordered]@{ available = $true; measured = @("state_bytes"); nodes = $null; resources = $null; objects = $null; orphans = $null; state_bytes = ($rows | Measure-Object -Property state_bytes -Maximum).Maximum }
    allocation_copy_counters = [ordered]@{ available = $false; allocations = $null; shallow_copies = $null; deep_copies = $null; bytes = $null; source = "not_instrumented_by_terminal_policy_driver" }
    rows = $rows
    artifacts = $artifacts
    failures = $failures
    passed = $failures.Count -eq 0
    reproduction_command = "powershell -NoProfile -ExecutionPolicy Bypass -File tools\integ06_1_terminal_soak.ps1 -CandidateCommit $candidate -ProfilePath $ProfilePath -EvidenceProfile $EvidenceProfile -OutDir $OutDir -RequireGodot"
}
$manifestPath = Join-Path $out "manifest.json"
$manifest | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $manifestPath
if ($failures.Count -gt 0) { throw "INTEG06_1_TERMINAL_SOAK FAIL manifest=$manifestPath failures=$($failures.Count)" }
Write-Host "INTEG06_1_TERMINAL_SOAK PASS manifest=$manifestPath rows=$($rows.Count) saves=$($manifest.save_load_points)"
