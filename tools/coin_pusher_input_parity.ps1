param(
    [string]$GodotPath = "",
    [string]$OutDir = ".tmp\coin_pusher_input_parity",
    [string]$WebResult = "",
    [string]$WebResult2 = "",
    [int]$WebPort = 18061
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath = $env:GODOT_BIN }
if (-not $GodotPath) {
    $common = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
    $candidate = Join-Path (Split-Path -Parent $common) ".tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe"
    if (Test-Path -LiteralPath $candidate) { $GodotPath = $candidate }
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Godot console not found; pass -GodotPath or set GODOT_BIN." }
$out = [IO.Path]::GetFullPath((Join-Path $root $OutDir))
New-Item -ItemType Directory -Force -Path $out | Out-Null

function Invoke-Parity([string]$stem) {
    $stdout = Join-Path $out "$stem.stdout.txt"
    $stderr = Join-Path $out "$stem.stderr.txt"
    $process = Start-Process -FilePath $GodotPath -ArgumentList @("--headless", "--path", $root, "--script", "res://tools/native_coin_pusher_smoke.gd") -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden -Wait
    $line = Get-Content -LiteralPath $stdout | Where-Object { $_.StartsWith("COIN_PUSHER_V3_SMOKE_RESULT=") } | Select-Object -Last 1
    if (-not $line) { throw "$stem emitted no parity result marker. stderr: $(Get-Content $stderr -Raw)" }
    $report = $line.Substring("COIN_PUSHER_V3_SMOKE_RESULT=".Length) | ConvertFrom-Json
    $report | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $out "$stem.json")
    if ($process.ExitCode -ne 0 -or -not $report.ok) { throw "$stem failed; see $stdout and $stderr" }
    return $report
}

function Read-ParityResult([string]$path) {
    $raw = Get-Content -LiteralPath $path -Raw
    try { return $raw | ConvertFrom-Json } catch {}
    $line = Get-Content -LiteralPath $path | Where-Object { $_.StartsWith("COIN_PUSHER_V3_SMOKE_RESULT=") } | Select-Object -Last 1
    if (-not $line) { throw "Web result contains neither JSON nor the parity marker: $path" }
    return $line.Substring("COIN_PUSHER_V3_SMOKE_RESULT=".Length) | ConvertFrom-Json
}

function Invoke-WebParity([string]$stem, [int]$port) {
    $project = Join-Path $out "$stem-project"
    $webBuild = Join-Path $out "$stem-build"
    foreach ($target in @($project, $webBuild)) {
        if (Test-Path -LiteralPath $target) {
            $resolved = [IO.Path]::GetFullPath($target)
            if (-not $resolved.StartsWith($out, [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing to replace path outside parity output: $resolved" }
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path $target | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path $root "scripts") -Destination $project -Recurse
    Copy-Item -LiteralPath (Join-Path $root "data") -Destination $project -Recurse
    Copy-Item -LiteralPath (Join-Path $root "tools") -Destination $project -Recurse
    Copy-Item -LiteralPath (Join-Path $root "icon.svg") -Destination $project
    $projectText = (Get-Content -LiteralPath (Join-Path $root "project.godot") -Raw).Replace('run/main_scene="res://scenes/main.tscn"', 'run/main_scene="res://tools/coin_pusher_input_parity_main.tscn"')
    Set-Content -LiteralPath (Join-Path $project "project.godot") -Value $projectText
    $presets = (Get-Content -LiteralPath (Join-Path $root "export_presets.cfg") -Raw).Replace(',tools/*,tools/**', '')
    Set-Content -LiteralPath (Join-Path $project "export_presets.cfg") -Value $presets

    $exportStdout = Join-Path $out "web_export.stdout.txt"
    $exportStderr = Join-Path $out "web_export.stderr.txt"
    $webIndex = Join-Path $webBuild "index.html"
    $export = Start-Process -FilePath $GodotPath -ArgumentList @("--headless", "--path", $project, "--editor", "--export-release", "Web", $webIndex) -RedirectStandardOutput $exportStdout -RedirectStandardError $exportStderr -PassThru -WindowStyle Hidden -Wait
    if ($export.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $webIndex)) { throw "Transient Web export failed; see $exportStdout and $exportStderr" }

    $serverScript = Join-Path $out "web_server.py"
    @'
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler
class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=sys.argv[2], **kwargs)
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()
HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
'@ | Set-Content -LiteralPath $serverScript
    $serverStdout = Join-Path $out "web_server.stdout.txt"
    $serverStderr = Join-Path $out "web_server.stderr.txt"
    $server = Start-Process -FilePath "python" -ArgumentList @($serverScript, $port, $webBuild) -RedirectStandardOutput $serverStdout -RedirectStandardError $serverStderr -PassThru -WindowStyle Hidden
    try {
        $deadline = [DateTime]::UtcNow.AddSeconds(15)
        do {
            try { $response = Invoke-WebRequest -Uri "http://127.0.0.1:$port/index.html" -UseBasicParsing -TimeoutSec 1 } catch { $response = $null }
            if ($response -and $response.StatusCode -eq 200) { break }
            Start-Sleep -Milliseconds 100
        } while ([DateTime]::UtcNow -lt $deadline)
        if (-not $response -or $response.StatusCode -ne 200) { throw "Transient Web server did not become ready; see $serverStderr" }
        $common = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
        $playwrightPackage = Join-Path (Split-Path -Parent $common) ".tmp\l02_playwright\package.json"
        $chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
        $capture = Join-Path $root "tools\coin_pusher_input_parity_web_capture.mjs"
        $webJson = Join-Path $out "$stem.json"
        & node $capture "--url=http://127.0.0.1:$port/index.html" "--out=$webJson" "--playwright-package=$playwrightPackage" "--chrome=$chrome"
        if ($LASTEXITCODE -ne 0) { throw "Web browser capture failed." }
        return Read-ParityResult $webJson
    } finally {
        if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
    }
}

$first = Invoke-Parity "windows_process_1"
$second = Invoke-Parity "windows_process_2"
$repeat = $first.parity_payload_sha256 -ceq $second.parity_payload_sha256
if (-not $repeat) { throw "Independent Windows processes diverged: $($first.parity_payload_sha256) != $($second.parity_payload_sha256)" }
if ($first.platform -cne "Windows" -or $first.solver_backend -cne "native_v3" -or -not $first.native_backend_available) { throw "Windows evidence did not use native_v3." }

$web = $null
$webSecond = $null
if ($WebResult) {
    if (-not $WebResult2) { throw "-WebResult requires an independent -WebResult2." }
    $web = Read-ParityResult ([IO.Path]::GetFullPath($WebResult))
    $webSecond = Read-ParityResult ([IO.Path]::GetFullPath($WebResult2))
} else {
    $web = Invoke-WebParity "web_process_1" $WebPort
    $webSecond = Invoke-WebParity "web_process_2" ($WebPort + 1)
}
$webRepeat = $web.parity_payload_sha256 -ceq $webSecond.parity_payload_sha256
$webExact = $webRepeat -and $web.web_feature -and $webSecond.web_feature -and $web.platform -ceq "Web" -and $webSecond.platform -ceq "Web" -and $web.solver_backend -ceq "gdscript_v3" -and $webSecond.solver_backend -ceq "gdscript_v3" -and ($web.parity_payload_sha256 -ceq $first.parity_payload_sha256)
$machineDiffs = @()
for ($index = 0; $index -lt $first.parity_machines.Count; $index++) {
    $nativeMachine = $first.parity_machines[$index]
    $webMachine = $web.parity_machines[$index]
    $fields = @()
    foreach ($property in $nativeMachine.PSObject.Properties.Name) {
        $nativeValue = $nativeMachine.$property | ConvertTo-Json -Compress -Depth 100
        $webValue = $webMachine.$property | ConvertTo-Json -Compress -Depth 100
        if ($nativeValue -cne $webValue) { $fields += $property }
    }
    if ($fields.Count -gt 0) {
        $machineDiffs += [ordered]@{ machine_id = $nativeMachine.machine_id; mismatched_fields = $fields }
    }
}
$rawEventCounts = @()
for ($index = 0; $index -lt $first.machines.Count; $index++) {
    $rawEventCounts += [ordered]@{
        machine_id = $first.machines[$index].machine_id
        windows_native = $first.machines[$index].raw_event_kind_counts
        web_reference = $web.machines[$index].raw_event_kind_counts
    }
}

$manifest = [ordered]@{
    schema = "coin_pusher_v3_input_parity_manifest_v2"
    passed = $repeat -and $webExact
    windows_process_repeat_exact = $repeat
    windows_native_backend = $first.solver_backend
    windows_payload_sha256 = $first.parity_payload_sha256
    web_compared = $true
    web_reference_backend = $web.solver_backend
    web_process_repeat_exact = $webRepeat
    web_payload_exact = $webExact
    web_payload_sha256 = if ($web) { $web.parity_payload_sha256 } else { "" }
    exact_machine_field_mismatches = $machineDiffs
    host_bookkeeping_event_kinds = @("insert")
    raw_event_kind_counts = $rawEventCounts
    production_machine_ids = @($first.machines | ForEach-Object machine_id)
    reports = @("windows_process_1.json", "windows_process_2.json", "web_process_1.json", "web_process_2.json")
    reproducible_web_entry_scene = "res://tools/coin_pusher_input_parity_main.tscn"
    reproduction_command = "tools/coin_pusher_input_parity.ps1"
}
$manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $out "manifest.json")
if (-not $webExact) { throw "Web reference-v3 payload does not exactly match Windows native-v3 production trace evidence; see manifest.json." }
Write-Host "COIN_PUSHER_INPUT_PARITY PASS manifest=$(Join-Path $out 'manifest.json') payload=$($first.parity_payload_sha256) windows=native_v3 web=gdscript_v3"
