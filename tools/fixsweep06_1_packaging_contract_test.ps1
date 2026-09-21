$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$evidenceRoot = Join-Path $root ".tmp/fixsweep06_1/wave9"
New-Item -ItemType Directory -Force -Path $evidenceRoot | Out-Null
$failures = [Collections.Generic.List[string]]::new()

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { $script:failures.Add($Message) }
}

$project = Get-Content -LiteralPath (Join-Path $root "project.godot") -Raw
$presets = Get-Content -LiteralPath (Join-Path $root "export_presets.cfg") -Raw
$exportTool = Get-Content -LiteralPath (Join-Path $root "tools/export_itch.ps1") -Raw
$main = Get-Content -LiteralPath (Join-Path $root "scripts/ui/foundation_main.gd") -Raw
$telemetry = Get-Content -LiteralPath (Join-Path $root "scripts/ui/perf_telemetry_overlay.gd") -Raw
$solver = Get-Content -LiteralPath (Join-Path $root "scripts/games/coin_pusher/coin_pusher_solver.gd") -Raw

Assert-True ($project -match 'config/version="0\.5\.1"') "D3 violation: project.godot release stamp changed."
$identityPath = Join-Path $root "scripts/core/build_identity.gd"
Assert-True (Test-Path -LiteralPath $identityPath -PathType Leaf) "BTH-033: manifest-backed runtime build identity is missing."
if (Test-Path -LiteralPath $identityPath -PathType Leaf) {
    $identity = Get-Content -LiteralPath $identityPath -Raw
    foreach ($field in @("build_version", "source_commit", "source_tree", "dirty_state_digest", "engine_sha256", "export_presets_sha256", "platform", "native_library_sha256")) {
        Assert-True ($identity.Contains($field)) "BTH-033: runtime manifest contract omits '$field'."
    }
}
Assert-True ($main.Contains("BuildIdentityScript.display_version")) "BTH-033: the player-visible menu still reads the immutable project release stamp directly."
Assert-True ($telemetry.Contains("BuildIdentityScript.telemetry_identity")) "BTH-033: performance telemetry still trusts caller-provided source identity."
foreach ($token in @("0.6.0-dev+", "dirty_state_digest", "engine_sha256", "export_presets_sha256", "native_library_sha256", "build_manifest.json")) {
    Assert-True ($exportTool.Contains($token)) "BTH-033: export custody tool is missing '$token'."
}
Assert-True ($presets -notmatch 'application/(file|product)_version="0\.5\.1"') "BTH-033: Windows development export metadata still claims 0.5.1."

foreach ($token in @("builds/staging", "source_tree", "candidate_manifest", "Verify-ArchiveAgainstStaging", "Move-SupersededBuildArtifacts")) {
    Assert-True ($exportTool.Contains($token)) "BTH-034: immutable cross-platform staging/custody contract is missing '$token'."
}
Assert-True ($exportTool.Contains('Target = "all"')) "BTH-034: the default packaging route does not build one bound Windows/Web candidate."

foreach ($pattern in @("reports/*", "reports/**", "native/*", "native/**", "**/*.log", "**/*.pem", "**/*.key")) {
    Assert-True ($presets.Contains($pattern)) "BTH-040: export exclusions omit '$pattern'."
}
$auditPath = Join-Path $root "tools/audit_pck_manifest.py"
Assert-True (Test-Path -LiteralPath $auditPath -PathType Leaf) "BTH-040: post-export PCK manifest audit is missing."
Assert-True ($exportTool.Contains("audit_pck_manifest.py")) "BTH-040: export flow does not invoke the packed-resource audit."

Assert-True (-not (Test-Path -LiteralPath (Join-Path $root "builds/itch/BeatTheHouse.exe"))) "BTH-041: loose itch executable remains outside quarantine."
$quarantinedLoose = @(Get-ChildItem -LiteralPath (Join-Path $root "builds/quarantine") -Filter "BeatTheHouse.exe" -File -Recurse -ErrorAction SilentlyContinue)
Assert-True ($quarantinedLoose.Count -ge 1) "BTH-041: loose itch executable has no reversible quarantine copy."
Assert-True ($solver.Contains("native_extension_required")) "BTH-041: distribution Coin Pusher still silently falls back without its native extension."
Assert-True ($exportTool.Contains("unexpected executable-looking artifact")) "BTH-041: upload-directory preflight does not reject unowned executables."

if ($failures.Count -gt 0) {
    Write-Host "FIXSWEEP06_1_PACKAGING_CONTRACT FAIL ($($failures.Count))" -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host " - $failure" }
    exit 1
}
Write-Host "FIXSWEEP06_1_PACKAGING_CONTRACT PASS" -ForegroundColor Green
