$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$harnessPath = Join-Path $root "scripts/tests/foundation/foundation_test_harness.gd"
$corePath = Join-Path $root "scripts/tests/foundation/check_core_content.gd"
$uiPath = Join-Path $root "scripts/tests/ui_scene/compile_components_and_main_flow.gd"
$failures = [System.Collections.Generic.List[string]]::new()
function Expect-Contract([bool]$Condition, [string]$Message) { if (-not $Condition) { $script:failures.Add($Message) } }

Expect-Contract (Test-Path -LiteralPath $harnessPath) "CH-24: shared foundation test harness is missing."
$harness = if (Test-Path $harnessPath) { Get-Content $harnessPath -Raw } else { "" }
$core = Get-Content $corePath -Raw
$ui = Get-Content $uiPath -Raw
Expect-Contract ($harness.Contains('func _expect(condition: bool, message: String, context: Variant = {}) -> bool:')) "CH-24: shared harness lacks _expect(condition, message, context)."
Expect-Contract ($core.Contains('FoundationTestHarnessScript.new(failures)')) "CH-24: foundation runner does not use the shared harness."
Expect-Contract ($core.Contains('harness._expect(')) "CH-24: foundation runner has not begun replacing raw failure appends."
$run = [regex]::Match($ui, '(?s)func _run\(\) -> void:(.*?)(?=\n\nfunc )')
Expect-Contract ($run.Success -and ($run.Value -split "`n").Count -le 12) "CH-24: UI _run remains a multi-thousand-line function."
Expect-Contract ($ui.Contains('func _check_component_preflight() -> bool:')) "CH-24: component preflight was not split at its _check boundaries."
Expect-Contract ($ui.Contains('func _check_foundation_app_boot() -> Control:')) "CH-24: Foundation app boot was not split at its _check boundaries."

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host "health06_1 test harness source contract passed."
