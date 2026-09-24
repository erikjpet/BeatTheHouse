param([string]$Root = "")

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$checker = Join-Path $Root "tools/environment_fixed_slot_static_check.py"
if (-not (Test-Path -LiteralPath $checker)) {
    throw "Fixed-slot static checker is missing: $checker"
}

& python $checker $Root
if ($LASTEXITCODE -ne 0) {
    throw "Environment fixed-slot static check failed."
}
