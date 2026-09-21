$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$foundationPath = Join-Path $root "scripts/ui/foundation_main.gd"
$sinkPath = Join-Path $root "scripts/ui/null_perf_sink.gd"
$foundation = Get-Content $foundationPath -Raw
$failures = [System.Collections.Generic.List[string]]::new()
function Expect-Contract([bool]$Condition, [string]$Message) { if (-not $Condition) { $script:failures.Add($Message) } }

Expect-Contract (Test-Path -LiteralPath $sinkPath) "CH-16: the no-op telemetry sink is missing."
$processMatch = [regex]::Match($foundation, '(?s)func _process\(delta: float\) -> void:(.*?)\n\nfunc _advance_run_game_clock')
Expect-Contract ($processMatch.Success) "CH-16: Foundation _process could not be inspected."
$processBody = if ($processMatch.Success) { $processMatch.Groups[1].Value } else { "" }
Expect-Contract (-not $processBody.Contains('if perf_telemetry_overlay == null')) "CH-16: _process still duplicates its body across a null branch."
Expect-Contract (([regex]::Matches($processBody, '_advance_run_game_clock')).Count -eq 1) "CH-16: game-clock advancement is not a single path."
Expect-Contract ($foundation.Contains('func _timed(name: String, operation: Callable) -> void:')) "CH-16: scoped _timed helper is missing."
Expect-Contract ($foundation.Contains('if not bool(_foundation_perf_sink.call("is_live")):')) "CH-16: disabled telemetry does not bypass clock reads."

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host "health06_1 scoped telemetry source contract passed."
