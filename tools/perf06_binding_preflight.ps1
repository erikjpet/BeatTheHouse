param(
    [Parameter(Mandatory = $true)][string]$CandidateCommit
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
. (Join-Path $PSScriptRoot "perf06_binding_preflight_contract.ps1")

$candidate = (& git -C $root rev-parse "$CandidateCommit^{commit}").Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($candidate)) {
    throw "CandidateCommit does not resolve to a commit."
}
$head = (& git -C $root rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $head -cne $candidate) {
    throw "Binding preflight candidate '$candidate' is not checked-out HEAD '$head'."
}

Assert-Perf06CleanWorktree -RepositoryRoot $root
$ports = @(Get-Perf06BindingPorts)
Assert-Perf06BindingPortsAvailable -Ports $ports

Write-Host "PERF06 BINDING PREFLIGHT PASS commit=$candidate ports=$($ports.Count)"
