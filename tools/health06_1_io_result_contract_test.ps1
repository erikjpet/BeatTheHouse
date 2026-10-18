$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()
function Expect-Contract([bool]$Condition, [string]$Message) { if (-not $Condition) { $script:failures.Add($Message) } }

$ioPath = Join-Path $root "scripts/core/io_result.gd"
$keysPath = Join-Path $root "scripts/core/keys.gd"
Expect-Contract (Test-Path -LiteralPath $ioPath) "CH-27: IoResult is missing."
Expect-Contract (Test-Path -LiteralPath $keysPath) "CH-27: Keys is missing."
$io = if (Test-Path -LiteralPath $ioPath) { Get-Content $ioPath -Raw } else { "" }
$keys = if (Test-Path -LiteralPath $keysPath) { Get-Content $keysPath -Raw } else { "" }
Expect-Contract ($io.Contains("static func assert_shape(")) "CH-27: IoResult has no shape validator."
Expect-Contract (([regex]::Matches($keys, '(?m)^const [A-Z0-9_]+ := ')).Count -ge 40) "CH-27: fewer than 40 high-frequency keys are constants."
foreach ($relative in @("scripts/core/durable_store.gd", "scripts/core/user_settings.gd", "scripts/core/run_action_service.gd", "scripts/core/game_module.gd")) {
    $source = Get-Content (Join-Path $root $relative) -Raw
    Expect-Contract ($source.Contains('preload("res://scripts/core/io_result.gd")')) "CH-27: $relative does not adopt IoResult."
}
$gameModule = Get-Content (Join-Path $root "scripts/core/game_module.gd") -Raw
Expect-Contract ($gameModule.Contains('static func apply_result(run_state: RunState, result: Dictionary, rng: RngStream = null, trusted_result_fingerprint: String = "") -> Dictionary:')) "CH-27: GameModule.apply_result still has a silent void boundary."

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host "health06_1 IoResult source contract passed."
