param(
    [ValidateSet("template_debug", "template_release")]
    [string]$Target = "template_debug",
    [string]$GodotPath = "",
    [switch]$SkipBootstrap
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $root ".tools/native_solver"
if (-not $SkipBootstrap) {
    & (Join-Path $PSScriptRoot "bootstrap_native_solver.ps1") -Target Windows
    if ($LASTEXITCODE -ne 0) {
        throw "Native solver bootstrap failed."
    }
}

$python = Join-Path $toolRoot "python/python.exe"
$wheel = Join-Path $toolRoot "downloads/scons-4.10.1-py3-none-any.whl"
$godotCpp = Join-Path $toolRoot "godot-cpp"
$mingwPackage = Join-Path $toolRoot "llvm-mingw-package"
$mingwChildren = @(Get-ChildItem -LiteralPath $mingwPackage -Directory -ErrorAction SilentlyContinue)
if ($mingwChildren.Count -ne 1) {
    throw "Pinned LLVM-MinGW package must contain exactly one toolchain root."
}
$mingw = $mingwChildren[0].FullName
$source = Join-Path $root "native/coin_pusher"
$output = Join-Path $root "addons/coin_pusher_native"
foreach ($required in @($python, $wheel, (Join-Path $godotCpp "SConstruct"), (Join-Path $mingw "bin/clang++.exe"))) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Native solver prerequisite is missing: $required"
    }
}

& (Join-Path $PSScriptRoot "verify_native_solver_runtime.ps1") -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) {
    throw "Native solver runtime preflight failed."
}

New-Item -ItemType Directory -Force -Path (Join-Path $output "bin") | Out-Null
Copy-Item -LiteralPath (Join-Path $source "coin_pusher_native.gdextension.template") -Destination (Join-Path $output "coin_pusher_native.gdextension") -Force

$previousPath = $env:PATH
$previousWheel = $env:BTH_NATIVE_SCONS_WHEEL
$previousArguments = $env:BTH_NATIVE_SCONS_ARGUMENTS
try {
    $env:PATH = (Join-Path $mingw "bin") + [System.IO.Path]::PathSeparator + $env:PATH
    $arguments = @(
        "scons",
        "-C", $source,
        "-j", "15",
        "platform=windows",
        "target=$Target",
        "arch=x86_64",
        "threads=no",
        "use_mingw=yes",
        "use_llvm=yes",
        "mingw_prefix=$mingw",
        "godot_cpp_dir=$godotCpp"
    )
    $env:BTH_NATIVE_SCONS_WHEEL = $wheel
    $env:BTH_NATIVE_SCONS_ARGUMENTS = ConvertTo-Json -Compress $arguments
    & $python -c "import json, os, sys; sys.path.insert(0, os.environ['BTH_NATIVE_SCONS_WHEEL']); from SCons.Script import main; sys.argv=json.loads(os.environ['BTH_NATIVE_SCONS_ARGUMENTS']); main()"
    if ($LASTEXITCODE -ne 0) {
        throw "Native solver $Target build failed with exit $LASTEXITCODE."
    }
}
finally {
    $env:PATH = $previousPath
    $env:BTH_NATIVE_SCONS_WHEEL = $previousWheel
    $env:BTH_NATIVE_SCONS_ARGUMENTS = $previousArguments
}

Write-Host "Native Coin Pusher $Target build complete." -ForegroundColor Green
