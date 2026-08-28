param(
    [string]$GodotPath = "",
    [string]$OutDir = ".tmp\coin_pusher_native_live_batch_contract",
    [int]$WebPort = 18063
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
$project = Join-Path $out "project"
$webBuild = Join-Path $out "build"
foreach ($target in @($project, $webBuild)) {
    if (Test-Path -LiteralPath $target) {
        $resolved = [IO.Path]::GetFullPath($target)
        if (-not $resolved.StartsWith($out, [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing to replace path outside contract output: $resolved" }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $target | Out-Null
}

& (Join-Path $PSScriptRoot "build_native_solver.ps1") -Platform Web -Target template_release -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) { throw "Web native solver build failed." }

foreach ($directory in @("addons", "data", "scripts", "tools")) {
    Copy-Item -LiteralPath (Join-Path $root $directory) -Destination $project -Recurse
}
Copy-Item -LiteralPath (Join-Path $root "icon.svg") -Destination $project
$projectText = (Get-Content -LiteralPath (Join-Path $root "project.godot") -Raw).Replace('run/main_scene="res://scenes/main.tscn"', 'run/main_scene="res://tools/coin_pusher_native_live_batch_contract.tscn"')
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
$server = Start-Process -FilePath "python" -ArgumentList @($serverScript, $WebPort, $webBuild) -RedirectStandardOutput $serverStdout -RedirectStandardError $serverStderr -PassThru -WindowStyle Hidden
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        try { $response = Invoke-WebRequest -Uri "http://127.0.0.1:$WebPort/index.html" -UseBasicParsing -TimeoutSec 1 } catch { $response = $null }
        if ($response -and $response.StatusCode -eq 200) { break }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    if (-not $response -or $response.StatusCode -ne 200) { throw "Transient Web server did not become ready; see $serverStderr" }
    $common = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
    $playwrightPackage = Join-Path (Split-Path -Parent $common) ".tmp\l02_playwright\package.json"
    $chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
    $capture = Join-Path $root "tools\coin_pusher_input_parity_web_capture.mjs"
    $webJson = Join-Path $out "web_contract.json"
    & node $capture "--url=http://127.0.0.1:$WebPort/index.html" "--out=$webJson" "--playwright-package=$playwrightPackage" "--chrome=$chrome"
    if ($LASTEXITCODE -ne 0) { throw "Web browser contract capture failed." }
} finally {
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
}

$report = Get-Content -LiteralPath (Join-Path $out "web_contract.json") -Raw | ConvertFrom-Json
if (-not $report.ok -or -not $report.web_feature -or -not $report.native_live_batch_supported) { throw "Native live-batch Web contract failed; see web_contract.json." }
$manifest = [ordered]@{
    schema = "coin_pusher_native_live_batch_contract_manifest_v1"
    passed = $true
    git_head = (& git -C $root rev-parse HEAD).Trim()
    web_contract_sha256 = (Get-FileHash -LiteralPath (Join-Path $out "web_contract.json") -Algorithm SHA256).Hash
    web_native_sha256 = (Get-FileHash -LiteralPath (Join-Path $root "addons\coin_pusher_native\bin\coin_pusher_native_v3_10.web.template_release.wasm32.nothreads.wasm") -Algorithm SHA256).Hash
    browser = $report.browser_capture.browser
    browser_version = $report.browser_capture.browser_version
    parity_payload_sha256 = $report.parity_payload_sha256
    reproduction_command = "tools/coin_pusher_native_live_batch_contract.ps1"
}
$manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $out "manifest.json")
Write-Host "COIN_PUSHER_NATIVE_LIVE_BATCH_CONTRACT PASS manifest=$(Join-Path $out 'manifest.json') payload=$($report.parity_payload_sha256)" -ForegroundColor Green
