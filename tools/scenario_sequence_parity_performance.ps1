param(
    [string]$GodotPath = "",
    [ValidateSet("chrome")]
    [string]$Browser = "chrome",
    [int]$Cpu = 4,
    [int]$TimeoutMs = 600000,
    [string]$OutDir = ".tmp\env06_6\parity_performance",
    [int]$WebPort = 18131,
    [switch]$RequireGodot
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if ($Cpu -lt 1) { throw "Cpu must be at least 1." }
if ($TimeoutMs -lt 1) { throw "TimeoutMs must be positive." }
if (-not $GodotPath) { $GodotPath = $env:GODOT_BIN }
if (-not $GodotPath) {
    $common = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
    $candidate = Join-Path (Split-Path -Parent $common) ".tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe"
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $GodotPath = $candidate }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    if ($RequireGodot) { throw "Godot console was not found; pass -GodotPath or set GODOT_BIN." }
    Write-Host "SCENARIO_SEQUENCE_PARITY_PERFORMANCE NOT RUN (Godot unavailable)."
    exit 0
}

$out = [IO.Path]::GetFullPath((Join-Path $root $OutDir))
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $root ".tmp"))
if (-not $out.StartsWith($allowedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutDir must resolve below the repository .tmp directory: $out"
}
if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Recurse -Force }
New-Item -ItemType Directory -Force -Path $out | Out-Null
$relativeOut = [IO.Path]::GetRelativePath($root, $out).Replace('\', '/')
$resourceOut = "res://$relativeOut"

function Invoke-BoundedProcess {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$StdoutPath,
        [string]$StderrPath,
        [string]$Label
    )
    $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath -PassThru -WindowStyle Hidden
    if (-not $process.WaitForExit($TimeoutMs)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "$Label timed out after $TimeoutMs ms; see $StdoutPath and $StderrPath."
    }
    if ($process.ExitCode -ne 0) { throw "$Label failed with exit $($process.ExitCode); see $StdoutPath and $StderrPath." }
}

function Read-ProbeMarker {
    param([string]$StdoutPath, [string]$Label)
    $line = Get-Content -LiteralPath $StdoutPath | Where-Object { $_.StartsWith("ENV06_6_SEQUENCE_PROBE=") } | Select-Object -Last 1
    if (-not $line) { throw "$Label emitted no ENV06_6_SEQUENCE_PROBE marker." }
    $report = $line.Substring("ENV06_6_SEQUENCE_PROBE=".Length) | ConvertFrom-Json
    if (-not $report.ok -or @($report.failures).Count -ne 0) { throw "$Label report did not pass." }
    return $report
}

function Invoke-NativeProbe {
    param([string]$Stem)
    $stdout = Join-Path $out "$Stem.stdout.txt"
    $stderr = Join-Path $out "$Stem.stderr.txt"
    $arguments = @(
        "--headless", "--path", $root, "--rendering-method", "gl_compatibility",
        "res://tools/scenario_sequence_probe_main.tscn", "--", "--mode=probe", "--out=$resourceOut/$Stem"
    )
    $dataRoot = Join-Path $out "${Stem}_data"
    New-Item -ItemType Directory -Force -Path $dataRoot | Out-Null
    $environmentNames = @("BTH_DISTRIBUTION_BUILD", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_USER_SETTINGS_PATH")
    $previousEnvironment = @{}
    foreach ($name in $environmentNames) { $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process") }
    try {
        $env:BTH_DISTRIBUTION_BUILD = "1"
        $env:BTH_DISTRIBUTION_DATA_ROOT = $dataRoot
        $env:BTH_USER_SETTINGS_PATH = Join-Path $dataRoot "settings.json"
        Invoke-BoundedProcess -FilePath $GodotPath -ArgumentList $arguments -StdoutPath $stdout -StderrPath $stderr -Label $Stem
    }
    finally {
        foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], "Process") }
    }
    $report = Read-ProbeMarker -StdoutPath $stdout -Label $Stem
    $report | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $out "$Stem.json")
    if ([string]$report.platform -cne "Windows") { throw "$Stem did not report the Windows native platform." }
    return $report
}

function Assert-PerformanceRows {
    param($Report, [string]$Label)
    $requiredRows = @(
        "content_schema_catalog_preparation", "command", "command_request_drain_event_delivery", "fact_publish_flush_terminal_cleanup",
        "projection_layout", "save", "load_rebuild", "reentry", "expiry", "terminal_cleanup", "steady_prepared_frame"
    )
    foreach ($rowId in $requiredRows) {
        $property = $Report.performance.named_rows.PSObject.Properties[$rowId]
        if (-not $property -or [int]$property.Value.count -lt 1 -or [double]$property.Value.max_ms -le 0) {
            throw "$Label is missing nonzero required performance row: $rowId"
        }
    }
    if ([int]$Report.performance.failed_transitions -ne 0 -or [int]$Report.performance.missing_transitions -ne 0) {
        throw "$Label contains failed or missing transitions."
    }
    if (-not $Report.performance.steady_frame.unchanged) { throw "$Label failed steady prepared-frame reconstruction evidence." }
    if ([string]$Report.platform -ceq "Web") {
        if ([double]$Report.performance.transition.p95_ms -gt 120 -or [double]$Report.performance.transition.max_ms -gt 1200 -or [double]$Report.performance.prepared_frame.p95_ms -gt 120) {
            throw "$Label exceeded a locked Web CPU4 timing budget."
        }
    }
    else {
        if ([double]$Report.performance.transition.p95_ms -gt 16 -or [double]$Report.performance.transition.max_ms -gt 45 -or [double]$Report.performance.prepared_frame.p95_ms -gt 16.6) {
            throw "$Label exceeded a locked native timing budget."
        }
    }
}

$native1 = Invoke-NativeProbe "native_process_1"
$native2 = Invoke-NativeProbe "native_process_2"
Assert-PerformanceRows $native1 "native_process_1"
Assert-PerformanceRows $native2 "native_process_2"

$webProject = Join-Path $out "web_project"
$webBuild = Join-Path $out "web_build"
New-Item -ItemType Directory -Force -Path $webProject, $webBuild | Out-Null
$rootProjectHashBefore = (Get-FileHash -LiteralPath (Join-Path $root "project.godot") -Algorithm SHA256).Hash
$rootPresetsHashBefore = (Get-FileHash -LiteralPath (Join-Path $root "export_presets.cfg") -Algorithm SHA256).Hash
$buildStdout = Join-Path $out "web_native_build.stdout.txt"
$buildStderr = Join-Path $out "web_native_build.stderr.txt"
$common = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
$canonicalRepoRoot = Split-Path -Parent $common

foreach ($fileName in @("icon.svg", "project.godot", "export_presets.cfg")) {
    Copy-Item -LiteralPath (Join-Path $root $fileName) -Destination (Join-Path $webProject $fileName) -Force
}
foreach ($directoryName in @("assets", "branding", "data", "scenes", "scripts", "tools")) {
    $target = Join-Path $root $directoryName
    if (-not (Test-Path -LiteralPath $target -PathType Container)) { throw "Transient Web project source is missing: $target" }
    New-Item -ItemType Junction -Path (Join-Path $webProject $directoryName) -Target $target | Out-Null
}
$transientNativeRoot = Join-Path $webProject "native"
New-Item -ItemType Directory -Force -Path $transientNativeRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $root "native\coin_pusher") -Destination $transientNativeRoot -Recurse -Force
$transientSource = Join-Path $transientNativeRoot "coin_pusher"
$canonicalAddon = Join-Path $canonicalRepoRoot "addons\coin_pusher_native"
$requiredHostLibraries = @(
    "bin\coin_pusher_native.windows.template_debug.x86_64.nothreads.dll",
    "bin\coin_pusher_native.windows.template_release.x86_64.nothreads.dll"
)
if (-not (Test-Path -LiteralPath $canonicalAddon -PathType Container)) {
    throw "Canonical read-only native addon prerequisite is missing: $canonicalAddon"
}
foreach ($relativeHostLibrary in $requiredHostLibraries) {
    $hostLibrary = Join-Path $canonicalAddon $relativeHostLibrary
    if (-not (Test-Path -LiteralPath $hostLibrary -PathType Leaf)) {
        throw "Required Windows host library is unavailable for the transient Web export: $hostLibrary"
    }
}
New-Item -ItemType Directory -Force -Path (Join-Path $webProject "addons") | Out-Null
Copy-Item -LiteralPath $canonicalAddon -Destination (Join-Path $webProject "addons") -Recurse -Force
$transientAddon = Join-Path $webProject "addons\coin_pusher_native"
New-Item -ItemType Directory -Force -Path (Join-Path $transientAddon "bin") | Out-Null
Copy-Item -LiteralPath (Join-Path $transientSource "coin_pusher_native.gdextension.template") -Destination (Join-Path $transientAddon "coin_pusher_native.gdextension") -Force
Get-ChildItem -LiteralPath (Join-Path $transientAddon "bin") -Filter "*.wasm" -File -ErrorAction SilentlyContinue | Remove-Item -Force

$toolRoot = Join-Path $canonicalRepoRoot ".tools\native_solver"
$python = Join-Path $toolRoot "python\python.exe"
$wheel = Join-Path $toolRoot "downloads\scons-4.10.1-py3-none-any.whl"
$godotCpp = Join-Path $toolRoot "godot-cpp"
$emsdkEnvironment = Join-Path $toolRoot "emsdk\emsdk_env.ps1"
foreach ($required in @($python, $wheel, (Join-Path $godotCpp "SConstruct"), $emsdkEnvironment)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Pinned Web compiler prerequisite is missing: $required" }
}
$nativeLock = Get-Content -LiteralPath (Join-Path $transientSource "toolchain.lock.json") -Raw | ConvertFrom-Json
. $emsdkEnvironment | Out-Null
$sconsArguments = @(
    "scons", "-C", $transientSource, "-j", "15", "platform=web", "target=template_release", "arch=wasm32",
    "threads=no", "api_version=$([string]$nativeLock.godot_cpp.api_version)", "godot_cpp_dir=$godotCpp"
)
$env:BTH_ENV06_6_SCONS_WHEEL = $wheel
$env:BTH_ENV06_6_SCONS_ARGUMENTS = ConvertTo-Json -Compress $sconsArguments
$buildRunner = Join-Path $out "run_transient_scons.py"
@'
import json, os, sys
sys.path.insert(0, os.environ["BTH_ENV06_6_SCONS_WHEEL"])
from SCons.Script import main
sys.argv = json.loads(os.environ["BTH_ENV06_6_SCONS_ARGUMENTS"])
main()
'@ | Set-Content -LiteralPath $buildRunner
Invoke-BoundedProcess -FilePath $python -ArgumentList @($buildRunner) -StdoutPath $buildStdout -StderrPath $buildStderr -Label "fresh transient Web native-solver build"
$webLibraries = @(Get-ChildItem -LiteralPath (Join-Path $transientAddon "bin") -Filter "*.wasm" -File -ErrorAction SilentlyContinue)
if ($webLibraries.Count -lt 1) { throw "Fresh transient Web native-solver build emitted no side module under OutDir." }
$projectPath = Join-Path $webProject "project.godot"
$projectText = (Get-Content -LiteralPath $projectPath -Raw).Replace('run/main_scene="res://scenes/main.tscn"', 'run/main_scene="res://tools/scenario_sequence_probe_main.tscn"')
if (-not $projectText.Contains('run/main_scene="res://tools/scenario_sequence_probe_main.tscn"')) { throw "Transient project main-scene replacement failed." }
Set-Content -LiteralPath $projectPath -Value $projectText
$presetsPath = Join-Path $webProject "export_presets.cfg"
$presetsText = (Get-Content -LiteralPath $presetsPath -Raw).Replace(',tools/*,tools/**', '')
if ($presetsText.Contains(',tools/*,tools/**')) { throw "Transient Web preset still excludes the dedicated probe tools." }
Set-Content -LiteralPath $presetsPath -Value $presetsText

$webIndex = Join-Path $webBuild "index.html"
$exportStdout = Join-Path $out "web_export.stdout.txt"
$exportStderr = Join-Path $out "web_export.stderr.txt"
Invoke-BoundedProcess -FilePath $GodotPath -ArgumentList @(
    "--headless", "--path", $webProject, "--editor", "--export-release", "Web", $webIndex
) -StdoutPath $exportStdout -StderrPath $exportStderr -Label "fresh transient Web export"
if (-not (Test-Path -LiteralPath $webIndex -PathType Leaf)) { throw "Fresh transient Web export emitted no index.html." }
$rootProjectHashAfter = (Get-FileHash -LiteralPath (Join-Path $root "project.godot") -Algorithm SHA256).Hash
$rootPresetsHashAfter = (Get-FileHash -LiteralPath (Join-Path $root "export_presets.cfg") -Algorithm SHA256).Hash
if ($rootProjectHashBefore -cne $rootProjectHashAfter -or $rootPresetsHashBefore -cne $rootPresetsHashAfter) {
    throw "Transient Web preparation changed the root project configuration."
}

$serverStdout = Join-Path $out "web_server.stdout.txt"
$serverStderr = Join-Path $out "web_server.stderr.txt"
$server = Start-Process -FilePath "powershell" -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $root "tools\serve_web.ps1"),
    "-Port", $WebPort, "-ServeRoot", $webBuild, "-NoBrowser"
) -RedirectStandardOutput $serverStdout -RedirectStandardError $serverStderr -PassThru -WindowStyle Hidden
try {
    $ready = $false
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    do {
        try {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:$WebPort/index.html" -UseBasicParsing -TimeoutSec 1
            $ready = $response.StatusCode -eq 200
        }
        catch { $ready = $false }
        if (-not $ready) { Start-Sleep -Milliseconds 100 }
    } while (-not $ready -and [DateTime]::UtcNow -lt $deadline)
    if (-not $ready) { throw "Transient Web server did not become ready; see $serverStderr." }

    $common = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
    $playwrightPackage = Join-Path (Split-Path -Parent $common) ".tmp\l02_playwright\package.json"
    $chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
    $captureScript = Join-Path $root "tools\scenario_sequence_web_capture.mjs"
    for ($index = 1; $index -le 2; $index++) {
        $stem = "web_process_$index"
        $webJson = Join-Path $out "$stem.json"
        $profile = Join-Path $out "${stem}_profile"
        $captureStdout = Join-Path $out "$stem.stdout.txt"
        $captureStderr = Join-Path $out "$stem.stderr.txt"
        $url = "http://127.0.0.1:$WebPort/index.html?mode=probe&run=$index"
        Invoke-BoundedProcess -FilePath "node" -ArgumentList @(
            $captureScript, "--url=$url", "--out=$webJson", "--profile=$profile", "--cpu=$Cpu",
            "--timeout-ms=$TimeoutMs", "--playwright-package=$playwrightPackage", "--chrome=$chrome"
        ) -StdoutPath $captureStdout -StderrPath $captureStderr -Label $stem
    }
}
finally {
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
}

$web1 = Get-Content -LiteralPath (Join-Path $out "web_process_1.json") -Raw | ConvertFrom-Json
$web2 = Get-Content -LiteralPath (Join-Path $out "web_process_2.json") -Raw | ConvertFrom-Json
Assert-PerformanceRows $web1 "web_process_1"
Assert-PerformanceRows $web2 "web_process_2"
foreach ($report in @($web1, $web2)) {
    if (-not $report.ok -or [string]$report.platform -cne "Web" -or [int]$report.browser_capture.cpu_throttle_rate -ne $Cpu) {
        throw "Web report did not use the required passing Chrome CPU$Cpu path."
    }
}

$nativeSemantic = $native1.semantic | ConvertTo-Json -Compress -Depth 100
$nativeSemantic2 = $native2.semantic | ConvertTo-Json -Compress -Depth 100
$webSemantic = $web1.semantic | ConvertTo-Json -Compress -Depth 100
$webSemantic2 = $web2.semantic | ConvertTo-Json -Compress -Depth 100
$repeatNative = ([string]$native1.semantic_sha256 -ceq [string]$native2.semantic_sha256) -and ($nativeSemantic -ceq $nativeSemantic2)
$repeatWeb = ([string]$web1.semantic_sha256 -ceq [string]$web2.semantic_sha256) -and ($webSemantic -ceq $webSemantic2)
$crossPlatform = ([string]$native1.semantic_sha256 -ceq [string]$web1.semantic_sha256) -and ($nativeSemantic -ceq $webSemantic)
if (-not $repeatNative) { throw "Two independent native processes produced different canonical traces." }
if (-not $repeatWeb) { throw "Two fresh-profile Web processes produced different canonical traces." }
if (-not $crossPlatform) { throw "Native and Web canonical scenario traces differ." }

$manifest = [ordered]@{
    schema = "env06_6_scenario_sequence_parity_performance_manifest_v1"
    passed = $true
    scenario_id = "corner_store_delivery_day"
    seed = "corner_store_delivery_day_env06_6"
    browser = $Browser
    cpu_throttle_rate = $Cpu
    native_process_repeat_exact = $repeatNative
    web_process_repeat_exact = $repeatWeb
    native_web_semantic_exact = $crossPlatform
    semantic_sha256 = [string]$native1.semantic_sha256
    timings_excluded_from_semantic_hash = $true
    budgets = [ordered]@{
        native_transition_p95_ms = 16.0
        native_transition_max_ms = 45.0
        native_prepared_frame_p95_ms = 16.6
        web_transition_p95_ms = 120.0
        web_transition_max_ms = 1200.0
        web_prepared_frame_p95_ms = 120.0
    }
    fresh_web_export = $true
    transient_web_project = $webProject
    reports = @("native_process_1.json", "native_process_2.json", "web_process_1.json", "web_process_2.json")
    reproduction_command = "powershell -NoProfile -ExecutionPolicy Bypass -File tools\scenario_sequence_parity_performance.ps1 -RequireGodot -Browser chrome -Cpu 4 -TimeoutMs 600000 -OutDir .tmp\env06_6\parity_performance"
}
$manifestPath = Join-Path $out "manifest.json"
$manifest | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $manifestPath
Write-Host "SCENARIO_SEQUENCE_PARITY_PERFORMANCE PASS manifest=$manifestPath semantic=$($native1.semantic_sha256) native=2 web=2 cpu=$Cpu"
