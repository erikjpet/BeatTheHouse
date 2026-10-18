$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "repository_root.ps1")
$root = Resolve-BthRepositoryRoot -StartPath $PSScriptRoot
$launcher = Get-Content -LiteralPath (Join-Path $root "tools/archive/integ06_1/integ06_1_terminal_soak.ps1") -Raw

function Assert-Contains([string]$Needle, [string]$Message) {
    if (-not $launcher.Contains($Needle)) { throw $Message }
}

Assert-Contains '$candidateAddon = Join-Path $root "addons\coin_pusher_native"' "Terminal soak must source host libraries from the exact candidate worktree."
Assert-Contains 'coin_pusher_native.gdextension.template' "Terminal soak must derive versioned host-library names from the candidate descriptor."
Assert-Contains "^windows\.(debug|release)\." "Terminal soak must select the descriptor's Windows debug and release keys."
Assert-Contains '$requiredHostLibraries.Count -ne 2' "Terminal soak must fail closed on incomplete or ambiguous Windows library declarations."
if ($launcher.Contains('"bin\coin_pusher_native.windows.template_debug.x86_64.nothreads.dll"') -or $launcher.Contains('"bin\coin_pusher_native.windows.template_release.x86_64.nothreads.dll"')) {
    throw "Terminal soak must not hardcode obsolete unversioned host-library names."
}
if ($launcher.Contains('$canonicalAddon = Join-Path $canonicalRepoRoot')) {
    throw "Terminal soak must not copy host binaries from another worktree."
}

Write-Host "INTEG06_1 TERMINAL SOAK LAUNCHER CONTRACT PASS"
