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
Assert-ContentClassification ($actual.HostSecurityAllowlistCount -eq 1 -and $actual.ReviewedBindingCount -eq 29 -and $actual.Issues.Count -eq 0) "Production must have exactly 29 unambiguous reviewed bindings and its sole security allowlist."
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
Assert-ContentClassification ($outside.ScanText.Contains('"motel"') -and $outside.ReviewedBindingCount -eq 29) "An unbound future content choice must remain visible."
$inside = Get-FoundationUiContentSelectionScan ($source.Replace("func _advance_run_game_clock(delta: float) -> void:", "func _advance_run_game_clock(delta: float) -> void:`n`tvar hostile_content_choice := `"motel`"")) -RequireReviewedBindings
Assert-ContentClassification ($inside.ScanText.Contains('"motel"') -and $inside.ReviewedBindingCount -eq 29) "A new literal inside an approved function must remain visible."
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

# Each current feedback fragment must remain tied to its exact function and
# predicate. Module-owned feedback replaces shell game-id selection. A global
# Blackjack exception or whole-function mask would hide
# the extra, moved, changed, duplicated, or ambiguous literals exercised here.
$blackjackFeedbackBindings = @(
    @{ Function = '_environment_result_feedback_view'; Lines = @('	if _recorded_result_game(result) != null and _recorded_result_game(result).uses_round_net_feedback() and round_net_lead.is_empty() and str(result.get("currency", "")) not in ["cash", "chips"]:'); ContentFrom = '_recorded_result_game(result)'; ContentTo = '_recorded_result_game({"game_id": "motel"})'; PredicateFrom = 'uses_round_net_feedback()'; PredicateTo = 'story_is_unmeasured_penalty(result)' },
    @{ Function = '_round_net_feedback_delta'; Lines = @('	var game := _recorded_result_game(result)', '	return game.round_net_feedback_delta(result) if game != null else null'); ContentFrom = '_recorded_result_game(result)'; ContentTo = '_recorded_result_game({"game_id": "motel"})'; PredicateFrom = 'if game != null else null'; PredicateTo = 'if game == null else null' },
    @{ Function = '_story_is_unwagered_game_observation'; Lines = @('	var game := _recorded_result_game(entry)', '	return game != null and game.story_is_unwagered_observation(entry)'); ContentFrom = '_recorded_result_game(entry)'; ContentTo = '_recorded_result_game({"game_id": "motel"})'; PredicateFrom = 'game != null and'; PredicateTo = 'game == null and' },
    @{ Function = '_result_from_story_log'; Lines = @('		var recorded_game := _recorded_result_game(story_entry)', '		if recorded_game != null:', '			feedback_keys.append_array(recorded_game.story_feedback_keys())'); ContentFrom = '_recorded_result_game(story_entry)'; ContentTo = '_recorded_result_game({"game_id": "motel"})'; PredicateFrom = 'if recorded_game != null:'; PredicateTo = 'if recorded_game == null:' },
    @{ Function = '_result_from_story_log'; Lines = @('		if not restored.has("currency") and _round_net_feedback_delta(restored) != null:'); ContentFrom = '_round_net_feedback_delta(restored)'; ContentTo = '_round_net_feedback_delta({"game_id": "motel"})'; PredicateFrom = 'if not restored.has'; PredicateTo = 'if restored.has' }
)
$feedbackHostileCount = 0
foreach ($binding in $blackjackFeedbackBindings) {
    $fragment = $binding.Lines -join "`n"
    Assert-ContentClassification ([regex]::Matches($source, [regex]::Escape($fragment)).Count -eq 1) "Feedback hostile fixture requires one exact current fragment: $($binding.Function)."
    $duplicatedFeedback = Get-FoundationUiContentSelectionScan ($source.Replace($fragment, $fragment + "`n" + $fragment)) -RequireReviewedBindings
    Assert-ContentClassification ($duplicatedFeedback.Issues.Count -gt 0 -and $duplicatedFeedback.ScanText.Contains($fragment)) "Duplicate feedback text must remain unclassified: $($binding.Function)."
    $feedbackHostileCount += 1
    $movedFeedbackSource = $source.Replace($fragment, "") + "`nfunc _hostile_blackjack_feedback_owner() -> void:`n" + $fragment
    $movedFeedback = Get-FoundationUiContentSelectionScan $movedFeedbackSource -RequireReviewedBindings
    Assert-ContentClassification ($movedFeedback.Issues.Count -gt 0 -and $movedFeedback.ScanText.Contains($fragment)) "Feedback text moved to another function must remain unclassified: $($binding.Function)."
    $feedbackHostileCount += 1
    $changedContentFragment = $fragment.Replace($binding.ContentFrom, $binding.ContentTo)
    Assert-ContentClassification ($changedContentFragment -cne $fragment) "Content mutation must change its current feedback fragment."
    $changedFeedback = Get-FoundationUiContentSelectionScan ($source.Replace($fragment, $changedContentFragment)) -RequireReviewedBindings
    Assert-ContentClassification ($changedFeedback.Issues.Count -gt 0 -and $changedFeedback.ScanText.Contains('"motel"')) "Changed feedback content identity must require review: $($binding.Function)."
    $feedbackHostileCount += 1
    $changedPredicate = $fragment.Replace($binding.PredicateFrom, $binding.PredicateTo)
    Assert-ContentClassification ($changedPredicate -cne $fragment) "Predicate mutation must change its current feedback fragment."
    $changedFeedbackPredicate = Get-FoundationUiContentSelectionScan ($source.Replace($fragment, $changedPredicate)) -RequireReviewedBindings
    Assert-ContentClassification ($changedFeedbackPredicate.Issues.Count -gt 0 -and $changedFeedbackPredicate.ScanText.Contains($changedPredicate)) "Changed feedback predicate must require review: $($binding.Function)."
    $feedbackHostileCount += 1
}
foreach ($ownerName in @($blackjackFeedbackBindings | ForEach-Object { $_.Function } | Select-Object -Unique)) {
    $ownerDeclarations = [regex]::Matches($source, '(?m)^func ' + [regex]::Escape($ownerName) + '\([^\n]*$')
    Assert-ContentClassification ($ownerDeclarations.Count -eq 1) "Feedback hostile fixture requires one function declaration: $ownerName."
    $declaration = $ownerDeclarations[0].Value
    $extraFeedback = Get-FoundationUiContentSelectionScan ($source.Replace($declaration, $declaration + "`n`tvar hostile_blackjack_choice := `"blackjack`"")) -RequireReviewedBindings
    Assert-ContentClassification ($extraFeedback.ReviewedBindingCount -eq 29 -and $extraFeedback.ScanText.Contains('"blackjack"')) "An extra Blackjack literal inside a reviewed feedback function must remain visible: $ownerName."
    $feedbackHostileCount += 1
    $duplicateFeedbackOwner = Get-FoundationUiContentSelectionScan ($source + "`n" + $declaration + "`n`treturn {`"game_id`": `"blackjack`"}") -RequireReviewedBindings
    Assert-ContentClassification ($duplicateFeedbackOwner.Issues.Count -gt 0 -and $duplicateFeedbackOwner.ScanText.Contains('"blackjack"')) "Duplicate feedback function owners must remain unclassified: $ownerName."
    $feedbackHostileCount += 1
    $ambiguousFeedbackSource = $source.Replace($declaration, $declaration + "`n`tvar embedded := $tripleQuote`n$tripleQuote`n`tvar hostile_blackjack_choice := `"blackjack`"")
    $ambiguousFeedback = Get-FoundationUiContentSelectionScan $ambiguousFeedbackSource -RequireReviewedBindings
    Assert-ContentClassification (($ambiguousFeedback.Issues -join "`n").Contains("multiline-string ambiguity") -and $ambiguousFeedback.ScanText.Contains('"blackjack"')) "Ambiguous feedback function text must remain unclassified: $ownerName."
    $feedbackHostileCount += 1
}
$outsideFeedback = Get-FoundationUiContentSelectionScan ($source + "`nvar hostile_blackjack_choice := `"blackjack`"") -RequireReviewedBindings
Assert-ContentClassification ($outsideFeedback.ReviewedBindingCount -eq 29 -and $outsideFeedback.ScanText.Contains('"blackjack"')) "An unbound Blackjack literal outside reviewed functions must remain visible."
$feedbackHostileCount += 1
Assert-ContentClassification ($feedbackHostileCount -eq 33) "All 33 current-feedback hostile mutations must execute."

if (-not $Quiet) { Write-Host "Foundation content selection classifier passed: 29 production bindings, current catalog scan, eight existing hostile classes and 33 Blackjack feedback hostiles." }
