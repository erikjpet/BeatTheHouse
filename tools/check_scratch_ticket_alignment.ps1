param(
    [switch]$Regenerate
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$audit = Join-Path $PSScriptRoot "scratch_ticket_alignment_audit.py"
$arguments = @($audit, "--verify")
if ($Regenerate) {
    $arguments = @($audit, "--generate", "--verify", "--overlay")
}

Push-Location $root
try {
    & python @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Scratch ticket alignment verification failed."
    }
}
finally {
    Pop-Location
}
