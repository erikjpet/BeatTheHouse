param([switch]$Quiet)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$validatorPath = Join-Path $PSScriptRoot "validate_project.ps1"
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($validatorPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw "Validator source must parse before its content classifier can be tested." }
$definitions = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq "Get-FoundationUiContentSelectionScan" }, $false))
if ($definitions.Count -ne 1) { throw "Expected one production content classifier." }
Invoke-Expression $definitions[0].Extent.Text

function Assert-ContentClassification {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$source = (Get-Content -LiteralPath (Join-Path $root "scripts/ui/foundation_main.gd") -Raw).Replace("`r`n", "`n")
$actual = Get-FoundationUiContentSelectionScan $source -RequireReviewedBindings
Assert-ContentClassification ($actual.HostSecurityAllowlistCount -eq 1 -and $actual.ReviewedBindingCount -eq 24 -and $actual.Issues.Count -eq 0) "Production must have exactly 24 unambiguous reviewed bindings and its sole security allowlist."
$contentIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($relative in @("data/environments/archetypes.json", "data/games/games.json", "data/items/items.json", "data/events/events.json", "data/debt/lenders.json", "data/services/services.json", "data/travel/routes.json")) {
    foreach ($entry in (Get-Content -LiteralPath (Join-Path $root $relative) -Raw | ConvertFrom-Json)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$entry.id)) { $null = $contentIds.Add([string]$entry.id) }
    }
}
foreach ($id in $contentIds) {
    Assert-ContentClassification (-not $actual.ScanText.Contains('"' + $id + '"') -and -not $actual.ScanText.Contains("'" + $id + "'")) "Production has an unclassified content literal: $id"
}

$outside = Get-FoundationUiContentSelectionScan ($source + "`nvar hostile_content_choice := `"motel`"") -RequireReviewedBindings
Assert-ContentClassification ($outside.ScanText.Contains('"motel"') -and $outside.ReviewedBindingCount -eq 24) "An unbound future content choice must remain visible."
$inside = Get-FoundationUiContentSelectionScan ($source.Replace("func _advance_run_game_clock(delta: float) -> void:", "func _advance_run_game_clock(delta: float) -> void:`n`tvar hostile_content_choice := `"motel`"")) -RequireReviewedBindings
Assert-ContentClassification ($inside.ScanText.Contains('"motel"') -and $inside.ReviewedBindingCount -eq 24) "A new literal inside an approved function must remain visible."
$approvedLine = "`t`tvar queued := run_state.enqueue_triggered_event(`"crew_favor_delivery`", `"crew_hourly`", {}, _triggered_entry_overrides(library.event(`"crew_favor_delivery`")))"
Assert-ContentClassification ($source.Contains($approvedLine)) "Hostile probe requires the current hourly callback binding."
$duplicated = Get-FoundationUiContentSelectionScan ($source.Replace($approvedLine, $approvedLine + "`n" + $approvedLine)) -RequireReviewedBindings
Assert-ContentClassification ($duplicated.Issues.Count -gt 0 -and $duplicated.ScanText.Contains('"crew_favor_delivery"')) "Duplicate approved text must fail classification instead of masking both copies."
$movedSource = $source.Replace($approvedLine, "") + "`nfunc _hostile_content_owner() -> void:`n" + $approvedLine
$moved = Get-FoundationUiContentSelectionScan $movedSource -RequireReviewedBindings
Assert-ContentClassification ($moved.Issues.Count -gt 0 -and $moved.ScanText.Contains('"crew_favor_delivery"')) "Approved text moved to a different function must remain unclassified."
$changed = Get-FoundationUiContentSelectionScan ($source.Replace($approvedLine, $approvedLine.Replace('"crew_favor_delivery"', '"motel"'))) -RequireReviewedBindings
Assert-ContentClassification ($changed.Issues.Count -gt 0 -and $changed.ScanText.Contains('"motel"')) "Changed binding semantics must require review."
$duplicateOwner = Get-FoundationUiContentSelectionScan ($source + "`nfunc _coach_context_snapshot() -> Dictionary:`n`treturn {`"game_id`": `"pull_tabs`"}") -RequireReviewedBindings
Assert-ContentClassification ($duplicateOwner.Issues.Count -gt 0 -and $duplicateOwner.ScanText.Contains('"pull_tabs"')) "Duplicate owner declarations must not classify any matching fragment."
$tripleQuote = '"""'
$ambiguousSource = $source.Replace("func _advance_run_game_clock(delta: float) -> void:", "func _advance_run_game_clock(delta: float) -> void:`n`tvar embedded := $tripleQuote`n$tripleQuote")
$ambiguous = Get-FoundationUiContentSelectionScan $ambiguousSource -RequireReviewedBindings
Assert-ContentClassification (($ambiguous.Issues -join "`n").Contains("multiline-string ambiguity") -and $ambiguous.ScanText.Contains('"crew_favor_delivery"')) "String-delimiter ambiguity must preserve literals and fail classification."
$securityBlock = "const SEALED_ACTION_HOST_SKIP_ENVIRONMENT_TURN_ALLOWLIST := {`n`t`"slot`": [`"slot_handpay_acknowledge`"],`n}"
$duplicateSecurity = Get-FoundationUiContentSelectionScan ($source + "`n" + $securityBlock) -RequireReviewedBindings
Assert-ContentClassification ($duplicateSecurity.HostSecurityAllowlistCount -eq 2 -and $duplicateSecurity.ScanText.Contains('"slot"')) "Duplicate security allowlists must remain unclassified."

if (-not $Quiet) { Write-Host "Foundation content selection classifier passed: 24 production bindings, current catalog scan, eight hostile classes." }
