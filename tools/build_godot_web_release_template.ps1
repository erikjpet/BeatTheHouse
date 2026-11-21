param(
    [string]$SourcePath = "",
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $root ".tools/native_solver"
$lockPath = Join-Path $root "native/coin_pusher/toolchain.lock.json"
$profilePath = Join-Path $root "native/coin_pusher/godot_web_release_build_profile.json"
$lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
$godotRepository = "https://github.com/godotengine/godot.git"
$godotCommit = [string]$lock.godot.commit
$expectedArchiveSha256 = [string]$lock.web.template_sha256

if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $SourcePath = Join-Path $toolRoot "godot-source"
}
$SourcePath = [System.IO.Path]::GetFullPath($SourcePath)
$expectedSourceRoot = [System.IO.Path]::GetFullPath($toolRoot) + [System.IO.Path]::DirectorySeparatorChar
if (-not ($SourcePath + [System.IO.Path]::DirectorySeparatorChar).StartsWith($expectedSourceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Godot template source must stay under the ignored native tool root: $toolRoot"
}

& (Join-Path $PSScriptRoot "bootstrap_native_solver.ps1") -Target Web
if ($LASTEXITCODE -ne 0) {
    throw "Pinned Web toolchain bootstrap failed."
}

if (-not (Test-Path -LiteralPath (Join-Path $SourcePath ".git"))) {
    if (Test-Path -LiteralPath $SourcePath) {
        throw "Refusing to replace a non-repository Godot source path: $SourcePath"
    }
    & git clone --filter=blob:none --no-checkout -- $godotRepository $SourcePath
    if ($LASTEXITCODE -ne 0) {
        throw "Could not clone the pinned Godot source repository."
    }
    & git -C $SourcePath fetch --depth=1 origin $godotCommit
    if ($LASTEXITCODE -ne 0) {
        throw "Could not fetch pinned Godot commit $godotCommit."
    }
    & git -C $SourcePath checkout --detach $godotCommit
    if ($LASTEXITCODE -ne 0) {
        throw "Could not check out pinned Godot commit $godotCommit."
    }
}

$actualCommit = (& git -C $SourcePath rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualCommit -cne $godotCommit) {
    throw "Godot source identity drift: expected $godotCommit, got $actualCommit"
}
$changedTrackedFiles = @(& git -C $SourcePath diff --name-only)
foreach ($changedFile in $changedTrackedFiles) {
    if ($changedFile -cne "platform/web/detect.py" -and $changedFile -cne "platform/web/js/libs/library_godot_os.js") {
        throw "Pinned Godot source contains an unrelated tracked change: $changedFile"
    }
}

# Godot enables Web release assertions unconditionally. The shipped release
# template disables those diagnostics explicitly; engine and extension ABI stay
# pinned to the same 4.6-stable commit and Emscripten 4.0.20 toolchain.
$detectPath = Join-Path $SourcePath "platform/web/detect.py"
$detectText = [System.IO.File]::ReadAllText($detectPath)
$forcedAssertions = "    else:`n        env[`"use_assertions`"] = True`n`n    if env[`"use_assertions`"]:"
$assertionsDisabled = "    if env[`"use_assertions`"]:"
if ($detectText.Contains($forcedAssertions)) {
    [System.IO.File]::WriteAllText($detectPath, $detectText.Replace($forcedAssertions, $assertionsDisabled))
}
elseif (-not $detectText.Contains($assertionsDisabled)) {
    throw "Pinned Web assertions patch no longer matches platform/web/detect.py."
}
$savePatch = Join-Path $root "native/coin_pusher/patches/godot_web_save_sync_r3.patch"
$savePatchSha = "3eb5ccb23cd9e6cd0c9ca8bf5e5595fa561bf21de268b108bbe5701f2397b7d6"
if ((Get-FileHash -LiteralPath $savePatch -Algorithm SHA256).Hash.ToLowerInvariant() -cne $savePatchSha) {
    throw "Reviewed Web Save engine patch hash drift."
}
$saveSource = "platform/web/js/libs/library_godot_os.js"
$saveSourcePath = Join-Path $SourcePath $saveSource
$saveBlob = (& git -C $SourcePath hash-object -- $saveSource).Trim()
if ($LASTEXITCODE -ne 0) { throw "Could not identify pinned Web Save engine source blob." }
if ($saveBlob -ceq "0e931b794e91ac35c5ba57795de10168bb958e33") {
    & git -C $SourcePath apply --check -- $savePatch
    if ($LASTEXITCODE -ne 0) { throw "Reviewed Web Save engine patch does not apply to pinned source." }
    & git -C $SourcePath apply -- $savePatch
    if ($LASTEXITCODE -ne 0) { throw "Could not apply reviewed Web Save engine patch." }
}
elseif ($saveBlob -cne "32cb01b566bd44f26246720f29492e73d753c7fa") {
    throw "Pinned Web Save engine source is neither original nor exact reviewed candidate: $saveBlob"
}
$saveBlob = (& git -C $SourcePath hash-object -- $saveSource).Trim()
if ($LASTEXITCODE -ne 0 -or $saveBlob -cne "32cb01b566bd44f26246720f29492e73d753c7fa") {
    throw "Reviewed Web Save engine source blob drift: $saveBlob"
}
$patchNames = @(& git -C $SourcePath diff --name-only)
if ($patchNames.Count -ne 2 -or $patchNames[0] -cne "platform/web/detect.py" -or $patchNames[1] -cne $saveSource) {
    throw "Godot source patch scope is not exactly the reviewed assertions and Web Save files."
}
$patchText = (& git -C $SourcePath diff -- platform/web/detect.py) -join "`n"
if ($patchText -notmatch '(?m)^-\s*else:' -or $patchText -notmatch 'env\["use_assertions"\] = True') {
    throw "Godot source does not contain the reviewed assertions-only patch."
}

$emsdkRoot = Join-Path $toolRoot "emsdk"
$sconsWheel = Join-Path $toolRoot "downloads/scons-$($lock.scons.version)-py3-none-any.whl"
. (Join-Path $emsdkRoot "emsdk_env.ps1") | Out-Null
$previousPythonPath = [string]$env:PYTHONPATH
try {
    $env:PYTHONPATH = $sconsWheel
    $arguments = @(
        "-m", "SCons",
        "-C", $SourcePath,
        "-j", "1",
        "platform=web",
        "target=template_release",
        "arch=wasm32",
        "dlink_enabled=yes",
        "threads=no",
        "production=yes",
        "optimize=size",
        "lto=none",
        "build_profile=$($profilePath.Replace('\', '/'))",
        "modules_enabled_by_default=no",
        "module_gdscript_enabled=yes",
        "module_freetype_enabled=yes",
        "module_text_server_fb_enabled=yes",
        "module_webp_enabled=yes",
        # Crew private-state capsules use Godot's reviewed AESContext and
        # HMACContext implementations. Keep mbedTLS in the thin template even
        # though all modules are disabled by default above.
        "module_mbedtls_enabled=yes",
        "disable_3d=yes",
        "disable_navigation_2d=yes",
        "disable_navigation_3d=yes",
        "disable_physics_2d=yes",
        "disable_physics_3d=yes",
        "disable_xr=yes",
        "module_godot_physics_2d_enabled=no",
        "module_godot_physics_3d_enabled=no",
        "module_jolt_physics_enabled=no",
        "module_openxr_enabled=no",
        "module_msdfgen_enabled=no",
        "use_assertions=no",
        "wasm_simd=yes"
    )
    & $env:EMSDK_PYTHON @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Pinned Godot Web release-template build failed."
    }
}
finally {
    $env:PYTHONPATH = $previousPythonPath
}

$builtArchive = Join-Path $SourcePath "bin/godot.web.template_release.wasm32.nothreads.dlink.zip"
if (-not (Test-Path -LiteralPath $builtArchive -PathType Leaf)) {
    throw "Godot did not produce the expected dlink/non-threaded release archive."
}
$artifactRoot = Join-Path $toolRoot "artifacts"
New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
$deterministicArchive = Join-Path $artifactRoot ([string]$lock.web.template)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$sourceZip = [System.IO.Compression.ZipFile]::OpenRead($builtArchive)
try {
    $archiveStream = [System.IO.File]::Open($deterministicArchive, [System.IO.FileMode]::Create)
    try {
        $outputZip = [System.IO.Compression.ZipArchive]::new($archiveStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
        try {
            foreach ($entry in @($sourceZip.Entries | Sort-Object FullName)) {
                $outputEntry = $outputZip.CreateEntry($entry.FullName, [System.IO.Compression.CompressionLevel]::Optimal)
                $outputEntry.LastWriteTime = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
                $input = $entry.Open()
                $output = $outputEntry.Open()
                try { $input.CopyTo($output) } finally { $output.Dispose(); $input.Dispose() }
            }
        }
        finally { $outputZip.Dispose() }
    }
    finally { $archiveStream.Dispose() }
}
finally { $sourceZip.Dispose() }

$actualArchiveSha256 = (Get-FileHash -LiteralPath $deterministicArchive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualArchiveSha256 -cne $expectedArchiveSha256) {
    throw "Deterministic Web template hash drift: expected $expectedArchiveSha256, got $actualArchiveSha256"
}
if (-not $SkipInstall) {
    $templateRoot = Join-Path $env:APPDATA "Godot/export_templates/$(([string]$lock.godot.version).Replace('-', '.'))"
    New-Item -ItemType Directory -Force -Path $templateRoot | Out-Null
    Copy-Item -LiteralPath $deterministicArchive -Destination (Join-Path $templateRoot ([string]$lock.web.template)) -Force
}

Write-Host "Pinned deterministic Godot Web release template ready: $actualArchiveSha256" -ForegroundColor Green
