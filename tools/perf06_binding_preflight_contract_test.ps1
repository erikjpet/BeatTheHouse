$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
. (Join-Path $PSScriptRoot "perf06_binding_preflight_contract.ps1")

function Assert-Rejected {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$ExpectedMessage
    )
    $rejected = $false
    try { & $Action }
    catch {
        if (-not $_.Exception.Message.Contains($ExpectedMessage)) {
            throw "Hostile fixture failed for the wrong reason. Expected '$ExpectedMessage', got '$($_.Exception.Message)'."
        }
        $rejected = $true
    }
    if (-not $rejected) { throw "Hostile fixture was accepted; expected '$ExpectedMessage'." }
}

$expectedPorts = @(18141, 18619, 18620, 18621, 18622, 18623, 18730, 18731, 18732, 18733, 18734, 18735)
$actualPorts = @(Get-Perf06BindingPorts)
if (($actualPorts -join ",") -cne ($expectedPorts -join ",")) {
    throw "Binding port inventory drifted. expected=$($expectedPorts -join ',') actual=$($actualPorts -join ',')"
}
$runbook = Get-Content -LiteralPath (Join-Path $root "docs/plans/perf06_1_final_runtime_runbook.md") -Raw
$lowEndLauncher = Get-Content -LiteralPath (Join-Path $root "tools/perf06_low_end_matrix.ps1") -Raw
$terminalLauncher = Get-Content -LiteralPath (Join-Path $root "tools/integ06_1_terminal_soak.ps1") -Raw
foreach ($port in @(18730, 18731, 18732, 18733, 18734, 18735)) {
    if (-not $runbook.Contains([string]$port)) { throw "Binding inventory includes normal-run port $port but the runbook no longer names it." }
}
foreach ($port in @(18619, 18620, 18621, 18622, 18623)) {
    if (-not $lowEndLauncher.Contains([string]$port)) { throw "Binding inventory includes low-end port $port but the launcher no longer names it." }
}
if (-not $terminalLauncher.Contains('[int]$WebPort = 18141')) {
    throw "Binding inventory lost the low-end terminal launcher's implicit port 18141."
}

$fixtureRoot = Join-Path $root (".tmp/perf06-binding-preflight-selftest-{0}" -f [guid]::NewGuid().ToString("N"))
$tmpRoot = [IO.Path]::GetFullPath((Join-Path $root ".tmp"))
$fixtureRoot = [IO.Path]::GetFullPath($fixtureRoot)
if (-not $fixtureRoot.StartsWith($tmpRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Self-test fixture escaped the repository .tmp directory."
}

$listener = $null
try {
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    & git -C $fixtureRoot init --quiet
    if ($LASTEXITCODE -ne 0) { throw "Could not initialize clean-worktree fixture." }
    & git -C $fixtureRoot config user.email "perf06-selftest@example.invalid"
    & git -C $fixtureRoot config user.name "perf06 selftest"
    Set-Content -LiteralPath (Join-Path $fixtureRoot ".gitignore") -Value "ignored.txt" -Encoding ascii
    Set-Content -LiteralPath (Join-Path $fixtureRoot "tracked.txt") -Value "baseline" -Encoding ascii
    & git -C $fixtureRoot add .gitignore tracked.txt
    & git -C $fixtureRoot commit --quiet -m "fixture"
    if ($LASTEXITCODE -ne 0) { throw "Could not commit clean-worktree fixture." }

    Assert-Perf06CleanWorktree -RepositoryRoot $fixtureRoot
    Set-Content -LiteralPath (Join-Path $fixtureRoot "ignored.txt") -Value "allowed ignored prerequisite" -Encoding ascii
    Assert-Perf06CleanWorktree -RepositoryRoot $fixtureRoot

    $roguePath = Join-Path $fixtureRoot "rogue.gd"
    Set-Content -LiteralPath $roguePath -Value "extends Node" -Encoding ascii
    Assert-Rejected -ExpectedMessage "nonignored untracked files" -Action { Assert-Perf06CleanWorktree -RepositoryRoot $fixtureRoot }
    Remove-Item -LiteralPath $roguePath -Force

    Set-Content -LiteralPath (Join-Path $fixtureRoot "tracked.txt") -Value "staged mutation" -Encoding ascii
    & git -C $fixtureRoot add tracked.txt
    Assert-Rejected -ExpectedMessage "tracked/index changes" -Action { Assert-Perf06CleanWorktree -RepositoryRoot $fixtureRoot }
    & git -C $fixtureRoot reset --quiet --hard HEAD

    Set-Content -LiteralPath (Join-Path $fixtureRoot "tracked.txt") -Value "unstaged mutation" -Encoding ascii
    Assert-Rejected -ExpectedMessage "tracked/index changes" -Action { Assert-Perf06CleanWorktree -RepositoryRoot $fixtureRoot }

    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $occupiedPort = [int](($listener.LocalEndpoint).Port)
    Assert-Rejected -ExpectedMessage "port=$occupiedPort" -Action { Assert-Perf06BindingPortsAvailable -Ports @($occupiedPort) }
}
finally {
    if ($null -ne $listener) { $listener.Stop() }
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

Write-Host "PERF06 BINDING PREFLIGHT CONTRACT PASS ports=$($actualPorts.Count) hostile=untracked,staged,unstaged,occupied_port ignored=allowed"
