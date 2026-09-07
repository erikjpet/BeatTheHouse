param(
    [Parameter(Mandatory = $true)][string]$CandidateCommit,
    [string]$GodotPath = "",
    [string]$EvidenceOut = "docs/plans/evidence/playtest06_2/owner_build_manifest.json",
    [int]$WindowsSmokeSeconds = 8,
    [int]$WebPort = 18926,
    [int]$WebTimeoutMs = 600000,
    [switch]$RequireGodot
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
. (Join-Path $PSScriptRoot "export_tree_identity.ps1")
$evidenceRoot = [IO.Path]::GetFullPath((Join-Path $root "docs/plans/evidence/playtest06_2"))
$evidencePath = if ([IO.Path]::IsPathRooted($EvidenceOut)) { [IO.Path]::GetFullPath($EvidenceOut) } else { [IO.Path]::GetFullPath((Join-Path $root $EvidenceOut)) }
$requiredEvidencePath = Join-Path $evidenceRoot "owner_build_manifest.json"
if ($evidencePath -cne $requiredEvidencePath) { throw "EvidenceOut must be docs/plans/evidence/playtest06_2/owner_build_manifest.json." }
foreach ($immutableEvidence in @($evidencePath, (Join-Path $evidenceRoot "owner_build_windows_smoke.json"), (Join-Path $evidenceRoot "owner_build_web_smoke.json"))) {
    if (Test-Path -LiteralPath $immutableEvidence) { throw "Owner build evidence is immutable; refusing to overwrite $immutableEvidence." }
}
if ($WindowsSmokeSeconds -lt 3) { throw "WindowsSmokeSeconds must be at least 3." }
if ($WebTimeoutMs -lt 1) { throw "WebTimeoutMs must be positive." }

function Get-RepoHash {
    param([string]$RelativePath)
    $path = Join-Path $script:root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required custody input is missing: $RelativePath" }
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-DirectoryFingerprint {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return "ABSENT" }
    $rows = @(Get-ChildItem -LiteralPath $Path -File -Recurse | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($Path.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
        "$relative`t$($_.Length)`t$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())"
    })
    return ($rows -join "`n")
}

function Get-BuildFiles {
    param([string]$RelativeRoot)
    $directory = [IO.Path]::GetFullPath((Join-Path $script:root $RelativeRoot))
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { throw "Build output directory is missing: $RelativeRoot" }
    return @(Get-ChildItem -LiteralPath $directory -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{
            path = $_.FullName.Substring($script:root.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
            bytes = [int64]$_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    })
}

$candidate = (& git -C $root rev-parse "$CandidateCommit^{commit}").Trim()
if ($LASTEXITCODE -ne 0 -or -not $candidate) { throw "CandidateCommit does not resolve to a commit." }
$head = (& git -C $root rev-parse HEAD).Trim()
if ($head -cne $candidate) { throw "HEAD $head does not equal CandidateCommit $candidate." }
if (@(& git -C $root status --short --untracked-files=all).Count -ne 0) { throw "Owner build requires exact HEAD with no tracked changes or nonignored untracked files." }
$candidateTree = (& git -C $root rev-parse "$candidate^{tree}").Trim()

if (-not $GodotPath) { $GodotPath = $env:GODOT_BIN }
if (-not $GodotPath) {
    $common = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
    $candidateGodot = Join-Path (Split-Path -Parent $common) ".tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe"
    if (Test-Path -LiteralPath $candidateGodot -PathType Leaf) { $GodotPath = $candidateGodot }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    if ($RequireGodot) { throw "Godot console was not found; pass -GodotPath or set GODOT_BIN." }
    throw "Owner build cannot qualify without the exact Godot console."
}
$GodotPath = [IO.Path]::GetFullPath($GodotPath)
$godotHash = (Get-FileHash -LiteralPath $GodotPath -Algorithm SHA256).Hash.ToLowerInvariant()
$toolchainLockPath = Join-Path $root "native/coin_pusher/toolchain.lock.json"
$toolchainLock = Get-Content -LiteralPath $toolchainLockPath -Raw | ConvertFrom-Json
$webTemplate = Join-Path $env:APPDATA "Godot/export_templates/$(([string]$toolchainLock.godot.version).Replace('-', '.'))/$([string]$toolchainLock.web.template)"
if (-not (Test-Path -LiteralPath $webTemplate -PathType Leaf)) { throw "Locked Web template is missing: $webTemplate" }
$webTemplateHash = (Get-FileHash -LiteralPath $webTemplate -Algorithm SHA256).Hash.ToLowerInvariant()
if ($webTemplateHash -cne [string]$toolchainLock.web.template_sha256) { throw "Locked Web template SHA-256 mismatch." }

$itchPath = Join-Path $root "builds/itch"
$itchBefore = Get-DirectoryFingerprint $itchPath
$priorGodot = $env:GODOT_BIN
$smokeRoot = Join-Path $root ".tmp/playtest06_owner_build"
New-Item -ItemType Directory -Path $smokeRoot -Force | Out-Null
$windows = $null
try {
    $env:GODOT_BIN = $GodotPath
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "export_itch.ps1") -Target windows -NoPackage
    if ($LASTEXITCODE -ne 0) { throw "No-package Windows export failed." }
    $windowsExe = Join-Path $root "builds/windows/BeatTheHouse.exe"
    if (-not (Test-Path -LiteralPath $windowsExe -PathType Leaf)) { throw "Windows owner build is missing." }
    $windows = Start-Process -FilePath $windowsExe -PassThru -WindowStyle Hidden
    if (-not $windows.WaitForExit($WindowsSmokeSeconds * 1000)) {
        $windowsSmokePassed = $true
        Stop-Process -Id $windows.Id -Force
        $windows.WaitForExit()
    } else {
        throw "Windows owner build exited during its $WindowsSmokeSeconds-second launch smoke (exit $($windows.ExitCode))."
    }

    $webReport = ".tmp/playtest06_owner_build/web_smoke.json"
    if (Test-Path -LiteralPath (Join-Path $root $webReport)) { Remove-Item -LiteralPath (Join-Path $root $webReport) -Force }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "web_perf_smoke.ps1") -Browser chrome -Cpu 1 -Port $WebPort -Frames 45 -ActiveFrames 60 -MemorySeconds 20 -TimeoutMs $WebTimeoutMs -Out $webReport -CacheMode cold -Plan distribution_fresh_start -EvidenceProfile playtest06_owner_build -NoPackageFreshExport
    if ($LASTEXITCODE -ne 0) { throw "Web owner build did not complete its Chrome launch smoke." }
}
finally {
    if ($null -ne $windows -and -not $windows.HasExited) { Stop-Process -Id $windows.Id -Force -ErrorAction SilentlyContinue }
    $env:GODOT_BIN = $priorGodot
}

if ((Get-DirectoryFingerprint $itchPath) -cne $itchBefore) { throw "No-package owner build changed builds/itch; refusing release-like output." }
if (@(& git -C $root status --short --untracked-files=all).Count -ne 0 -or (& git -C $root rev-parse HEAD).Trim() -cne $candidate) { throw "Candidate changed or gained a nonignored untracked file while producing the owner build." }

$windowsFiles = @(Get-BuildFiles "builds/windows")
$webFiles = @(Get-BuildFiles "builds/web")
$windowsExportIdentity = [string](Get-ExportTreeIdentityFromRows -Rows $windowsFiles -PathPrefix "builds/windows").aggregate_sha256
$webExportIdentity = [string](Get-ExportTreeIdentityFromRows -Rows $webFiles -PathPrefix "builds/web").aggregate_sha256
if (@($windowsFiles | Where-Object { $_.path -like "*coin_pusher_native*.dll" }).Count -ne 1) { throw "Windows build must contain exactly one Coin Pusher native solver DLL." }
if (@($webFiles | Where-Object { $_.path -like "*coin_pusher_native*.wasm" }).Count -ne 1) { throw "Web build must contain exactly one Coin Pusher native solver WASM." }

New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
$windowsSmokeRelative = "docs/plans/evidence/playtest06_2/owner_build_windows_smoke.json"
$windowsSmokePath = Join-Path $root $windowsSmokeRelative
[ordered]@{
    schema = "beat_the_house.playtest06_owner_build_smoke/v1"
    candidate_commit = $candidate
    candidate_tree = $candidateTree
    platform = "WINDOWS_NATIVE"
    executable = "builds/windows/BeatTheHouse.exe"
    stayed_alive_seconds = $WindowsSmokeSeconds
    passed = $windowsSmokePassed
    export_identity_sha256 = $windowsExportIdentity
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $windowsSmokePath -Encoding utf8
$webSmokeRelative = "docs/plans/evidence/playtest06_2/owner_build_web_smoke.json"
$webSmokePath = Join-Path $root $webSmokeRelative
$webRawReport = Join-Path $root ".tmp/playtest06_owner_build/web_smoke.json"
$webSummaryPath = [IO.Path]::ChangeExtension($webRawReport, ".summary.json")
$webSummary = Get-Content -LiteralPath $webSummaryPath -Raw | ConvertFrom-Json
[ordered]@{
    schema = "beat_the_house.playtest06_owner_build_smoke/v1"
    candidate_commit = $candidate
    candidate_tree = $candidateTree
    platform = "WEB_CHROME"
    passed = [bool]$webSummary.passed
    export_identity_sha256 = $webExportIdentity
    runtime_source_commit = [string]$webSummary.source_commit
    runtime_export_sha256 = [string]$webSummary.web_export_identity.aggregate_sha256
    raw_report_sha256 = (Get-FileHash -LiteralPath $webRawReport -Algorithm SHA256).Hash.ToLowerInvariant()
    summary_report_sha256 = (Get-FileHash -LiteralPath $webSummaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $webSmokePath -Encoding utf8
if (-not [bool]$webSummary.passed -or [string]$webSummary.source_commit -cne $candidate -or [string]$webSummary.web_export_identity.aggregate_sha256 -cne $webExportIdentity) {
    throw "Web owner-build smoke did not bind the candidate and complete export identity."
}

$toolFiles = @("tools/playtest06_owner_build.ps1", "tools/export_itch.ps1", "tools/build_native_solver.ps1", "tools/verify_native_solver_runtime.ps1", "tools/web_perf_smoke.ps1", "tools/web_perf_export_mode.ps1", "tools/export_tree_identity.ps1", "tools/l02_web_perf_probe.mjs", "tools/serve_web.ps1")
$manifest = [ordered]@{
    schema = "beat_the_house.playtest06_owner_build/v1"
    candidate_commit = $candidate
    candidate_tree = $candidateTree
    generated_at_utc = [datetime]::UtcNow.ToString("o")
    distribution_artifact = $false
    archive_created = $false
    upload_performed = $false
    builder_script_sha256 = Get-RepoHash "tools/playtest06_owner_build.ps1"
    godot_path = $GodotPath
    godot_sha256 = $godotHash
    toolchain_lock_sha256 = Get-RepoHash "native/coin_pusher/toolchain.lock.json"
    web_template_sha256 = $webTemplateHash
    export_presets_sha256 = Get-RepoHash "export_presets.cfg"
    tool_hashes = @($toolFiles | ForEach-Object { [ordered]@{ path = $_; sha256 = Get-RepoHash $_ } })
    windows = [ordered]@{ platform = "WINDOWS_NATIVE"; output_root = "builds/windows"; export_identity_sha256 = $windowsExportIdentity; smoke_passed = $windowsSmokePassed; smoke_seconds = $WindowsSmokeSeconds; smoke_evidence = [ordered]@{ path = $windowsSmokeRelative; sha256 = Get-RepoHash $windowsSmokeRelative }; files = $windowsFiles }
    web = [ordered]@{ platform = "WEB_CHROME"; output_root = "builds/web"; export_identity_sha256 = $webExportIdentity; smoke_passed = $true; smoke_evidence = [ordered]@{ path = $webSmokeRelative; sha256 = Get-RepoHash $webSmokeRelative }; files = $webFiles }
}
$manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding utf8
Write-Host "PLAYTEST06_OWNER_BUILD PASS candidate=$candidate windows_files=$($windowsFiles.Count) web_files=$($webFiles.Count) evidence=$EvidenceOut"
