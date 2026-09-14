param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ReportPath = ""
)

$ErrorActionPreference = 'Stop'

function Add-Failure([System.Collections.Generic.List[string]]$Failures, [string]$Message) {
    $Failures.Add($Message)
}

function Require-SourceToken(
    [System.Collections.Generic.List[string]]$Failures,
    [string]$Source,
    [string]$Token,
    [string]$Context
) {
    if (-not $Source.Contains($Token)) {
        Add-Failure $Failures "$Context is missing required production-authority token: $Token"
    }
}

$failures = [System.Collections.Generic.List[string]]::new()
$legacySurfacePath = Join-Path $ProjectRoot 'tools/playtest06_surface_family_playability_contract.gd'
$legacyVisualPath = Join-Path $ProjectRoot 'tools/foundation_visual_qa.gd'
$fidelityPath = Join-Path $ProjectRoot 'scripts/tests/foundation/harness_production_fidelity.gd'
$workingOrderPath = Join-Path $ProjectRoot 'tools/fix06_28_working_order_driver.gd'

foreach ($requiredPath in @($legacySurfacePath, $legacyVisualPath, $fidelityPath, $workingOrderPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        Add-Failure $failures "Missing acceptance source: $requiredPath"
    }
}

$legacySurface = if (Test-Path -LiteralPath $legacySurfacePath) { Get-Content -Raw -LiteralPath $legacySurfacePath } else { '' }
$legacyVisual = if (Test-Path -LiteralPath $legacyVisualPath) { Get-Content -Raw -LiteralPath $legacyVisualPath } else { '' }
$fidelity = if (Test-Path -LiteralPath $fidelityPath) { Get-Content -Raw -LiteralPath $fidelityPath } else { '' }
$workingOrder = if (Test-Path -LiteralPath $workingOrderPath) { Get-Content -Raw -LiteralPath $workingOrderPath } else { '' }

# These calls created the false green: a practice session fabricated the target
# and a private callback skipped the shipped room object and mouse routing.
foreach ($forbidden in @('start_game_test_session', '_on_game_surface_action')) {
    if ($legacySurface.Contains($forbidden)) {
        Add-Failure $failures "Surface-family acceptance still bypasses production authority via '$forbidden'."
    }
}

# Fixture construction may remain useful for visual development, but a report
# produced by that path is not admissible as production working-order evidence.
$fixtureTokens = @('_prepare_visual_qa_fixture_environment', 'EnvironmentInstance.from_archetype', 'set_environment(')
$fixtureTokensPresent = @($fixtureTokens | Where-Object { $legacyVisual.Contains($_) })
if (-not $legacyVisual.Contains('"production_acceptance_admissible": false')) {
    Add-Failure $failures 'foundation_visual_qa must identify its fixture-backed report as inadmissible for production acceptance.'
}

Require-SourceToken $failures $fidelity 'resolve_exact_canvas_object' 'Shared fidelity helper'
Require-SourceToken $failures $fidelity 'InputEventMouseButton' 'Shared fidelity helper'
Require-SourceToken $failures $fidelity 'viewport.push_input' 'Shared fidelity helper'
Require-SourceToken $failures $fidelity 'observable_host_snapshot' 'Shared fidelity helper'
Require-SourceToken $failures $fidelity 'Serialized RunState is' 'Shared fidelity helper'
Require-SourceToken $failures $workingOrder 'run_config_button' 'Working-order driver visible start'
Require-SourceToken $failures $workingOrder 'InputEventKey' 'Working-order driver seed input'
Require-SourceToken $failures $workingOrder 'travel:leave' 'Working-order driver exact departure'
Require-SourceToken $failures $workingOrder 'world_map_confirm_button' 'Working-order driver travel confirmation'
Require-SourceToken $failures $workingOrder 'run_menu_save_button' 'Working-order driver save path'
Require-SourceToken $failures $workingOrder 'CONTINUE' 'Working-order driver Continue path'
foreach ($forbidden in @('start_game_test_session', '_on_game_surface_action', '_prepare_visual_qa_fixture_environment')) {
    if ($workingOrder.Contains($forbidden)) {
        Add-Failure $failures "Working-order driver bypasses production authority via '$forbidden'."
    }
}

$report = [ordered]@{
    schema_version = 1
    check_id = 'fix06_28_acceptance_authority_contract'
    passed = ($failures.Count -eq 0)
    failures = @($failures)
    inadmissible_for_production_acceptance = [ordered]@{
        path = 'tools/foundation_visual_qa.gd'
        reason = 'Fixture environments and direct state preparation are present; this producer may support visual development but cannot prove a naturally generated owner route.'
        fixture_tokens_present = $fixtureTokensPresent
    }
    required_authority = @(
        'production host scene',
        'exact rendered semantic object id',
        'Viewport InputEvent mouse routing',
        'visible before/after consequence excluding hidden RunState-only deltas'
    )
}

if ($ReportPath) {
    $resolvedReport = if ([System.IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $ProjectRoot $ReportPath }
    $reportDirectory = Split-Path -Parent $resolvedReport
    if ($reportDirectory -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory | Out-Null
    }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedReport -Encoding utf8
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    Write-Host "FIX06_28_ACCEPTANCE_AUTHORITY FAIL failures=$($failures.Count)"
    exit 1
}

Write-Host 'FIX06_28_ACCEPTANCE_AUTHORITY PASS'
exit 0
