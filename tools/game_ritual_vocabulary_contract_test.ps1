param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$fixturePath = Join-Path $ProjectRoot "scripts/tests/fixtures/game_ritual_vocabulary_v1.json"
$envelopeFixturePath = Join-Path $ProjectRoot "scripts/tests/fixtures/game_ritual_shared_envelopes_v1.json"
$contractPath = Join-Path $ProjectRoot "docs/plans/game06_1_table_machine_ritual_vocabulary.md"
$checklistPath = Join-Path $ProjectRoot "docs/plans/game06_1_ritual_contract_acceptance_checklist.md"

function Copy-Definition {
    param([Parameter(Mandatory)]$Value)
    return ($Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json)
}

function Property-Names {
    param($Value)
    if ($null -eq $Value) { return @() }
    return @($Value.PSObject.Properties.Name)
}

function Add-Error {
    param([System.Collections.Generic.List[string]]$Errors, [string]$Message)
    $Errors.Add($Message)
}

function Test-LocalId {
    param([string]$Value)
    return $Value -cmatch '^[a-z][a-z0-9_]{0,63}$'
}

function Test-QualifiedId {
    param([string]$Value)
    if ($Value.Length -gt 192) { return $false }
    $parts = @($Value -split '\.')
    return $parts.Count -ge 2 -and @($parts | Where-Object { -not (Test-LocalId $_) }).Count -eq 0
}

function Add-ClosedShapeErrors {
    param(
        [System.Collections.Generic.List[string]]$Errors,
        [string]$Label,
        $Value,
        [string[]]$Required
    )
    $actual = @(Property-Names $Value)
    foreach ($key in $Required) {
        if ($key -notin $actual) { Add-Error $Errors "$Label missing field: $key" }
    }
    foreach ($key in $actual) {
        if ($key -notin $Required) { Add-Error $Errors "$Label unknown field: $key" }
    }
}

function Test-RitualDefinition {
    param([Parameter(Mandatory)]$Definition)

    $errors = [System.Collections.Generic.List[string]]::new()
    $allowedTop = @(
        "contract", "ritual_id", "initial_phase", "ritual_phases",
        "staged_commitment", "pointer_verbs", "actors", "scene_objects",
        "energy", "game_facts", "ritual_persistence", "handler_registry",
        "declared_targets"
    )
    foreach ($key in (Property-Names $Definition)) {
        if ($key -notin $allowedTop) { Add-Error $errors "unknown top-level field: $key" }
    }
    foreach ($key in $allowedTop) {
        if ($key -notin (Property-Names $Definition)) { Add-Error $errors "missing top-level field: $key" }
    }
    if ($Definition.contract -ne "game_ritual/1") { Add-Error $errors "unsupported contract version" }
    if (-not (Test-QualifiedId ([string]$Definition.ritual_id))) { Add-Error $errors "ritual_id must be a qualified id" }

    $phaseById = @{}
    foreach ($phase in @($Definition.ritual_phases)) {
        $phaseId = [string]$phase.id
        if (-not (Test-LocalId $phaseId)) {
            Add-Error $errors "phase id must be a local id"
        } elseif ($phaseById.ContainsKey($phaseId)) {
            Add-Error $errors "duplicate phase id: $phaseId"
        } else {
            $phaseById[$phaseId] = $phase
        }
    }
    if ($phaseById.Count -eq 0) { Add-Error $errors "ritual_phases must not be empty" }
    if (-not $phaseById.ContainsKey([string]$Definition.initial_phase)) {
        Add-Error $errors "initial_phase does not resolve"
    }

    $reachable = [System.Collections.Generic.HashSet[string]]::new()
    $queue = [System.Collections.Generic.Queue[string]]::new()
    if ($phaseById.ContainsKey([string]$Definition.initial_phase)) {
        $queue.Enqueue([string]$Definition.initial_phase)
    }
    while ($queue.Count -gt 0) {
        $phaseId = $queue.Dequeue()
        if (-not $reachable.Add($phaseId)) { continue }
        $phase = $phaseById[$phaseId]
        $permitted = @($phase.permitted_actions)
        $transitionKeys = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($transition in @($phase.transitions)) {
            if (-not (Test-LocalId ([string]$transition.id))) { Add-Error $errors "transition id must be a local id" }
            $next = [string]$transition.next_phase
            if (-not $phaseById.ContainsKey($next)) {
                Add-Error $errors "transition target does not resolve: $next"
            } else {
                $queue.Enqueue($next)
            }
            $conditionKind = [string]$transition.condition.kind
            $conditionAction = [string]$transition.condition.action_id
            $ambiguityKey = "$conditionKind|$conditionAction"
            if (-not $transitionKeys.Add($ambiguityKey)) {
                Add-Error $errors "ambiguous transition in phase: $phaseId"
            }
            if ($conditionKind -eq "accepted_action" -and $conditionAction -notin $permitted) {
                Add-Error $errors "transition action is not permitted in phase: $conditionAction"
            }
        }
        if (-not [bool]$phase.terminal -and @($phase.transitions).Count -eq 0) {
            Add-Error $errors "nonterminal phase has no transition: $phaseId"
        }
    }
    foreach ($phaseId in $phaseById.Keys) {
        if (-not $reachable.Contains($phaseId)) { Add-Error $errors "unreachable phase: $phaseId" }
    }

    $commitActions = @($Definition.staged_commitment.actions | ForEach-Object { [string]$_.id })
    if ("commit.confirm" -notin $commitActions) { Add-Error $errors "staged commitment requires confirm" }
    if (("commit.remove" -notin $commitActions) -and ("commit.correct" -notin $commitActions)) {
        Add-Error $errors "staged commitment requires single-item correction or removal"
    }
    foreach ($total in @("available_funds", "pending_total", "at_risk_total", "returned_stake", "payout")) {
        if ($total -notin @($Definition.staged_commitment.readable_totals)) {
            Add-Error $errors "missing readable total: $total"
        }
    }

    $regionIds = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($region in @($Definition.declared_targets.regions)) { [void]$regionIds.Add([string]$region) }
    $phaseIds = @($phaseById.Keys)
    $allActions = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($phase in @($Definition.ritual_phases)) {
        foreach ($action in @($phase.permitted_actions)) { [void]$allActions.Add([string]$action) }
    }
    foreach ($verb in @($Definition.pointer_verbs)) {
        if ([string]$verb.verb -notin @("drag", "hold", "flick", "place", "reveal")) {
            Add-Error $errors "unregistered pointer verb: $($verb.verb)"
        }
        if (-not $regionIds.Contains([string]$verb.source_region)) {
            Add-Error $errors "unbound pointer source region: $($verb.source_region)"
        }
        foreach ($target in @($verb.target_regions)) {
            if (-not $regionIds.Contains([string]$target)) { Add-Error $errors "unbound pointer target region: $target" }
        }
        foreach ($phaseId in @($verb.phases)) {
            if ($phaseId -notin $phaseIds) { Add-Error $errors "unbound pointer phase: $phaseId" }
        }
        if (-not $allActions.Contains([string]$verb.accepted_action)) {
            Add-Error $errors "unbound pointer action: $($verb.accepted_action)"
        }
        foreach ($equivalent in @("keyboard", "controller", "reduced_motion")) {
            if ($equivalent -notin (Property-Names $verb.equivalents)) {
                Add-Error $errors "missing pointer equivalent: $equivalent"
            }
        }
        foreach ($equivalent in @("keyboard", "controller", "reduced_motion")) {
            $record = $verb.equivalents.$equivalent
            if ([string]$record.action_id -ne [string]$verb.accepted_action) {
                Add-Error $errors "pointer equivalent must use accepted action: $equivalent"
            }
            if ([string]$record.target_selection -notin @("focus", "cycle", "direct_semantic")) {
                Add-Error $errors "pointer equivalent has invalid target selection: $equivalent"
            }
        }
        if ([string]$verb.equivalents.reduced_motion.staging -notin @("instant", "short", "authored_text")) {
            Add-Error $errors "reduced-motion equivalent has invalid staging"
        }
        if (@($verb.rejection_effects).Count -ne 0) {
            Add-Error $errors "pointer rejection must be side-effect-free"
        }
    }

    $actorIds = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($actor in @($Definition.actors)) {
        [void]$actorIds.Add([string]$actor.id)
        if ([string]::IsNullOrWhiteSpace([string]$actor.anchor)) { Add-Error $errors "actor anchor is required" }
        if (@($actor.poses).Count -eq 0) { Add-Error $errors "actor poses must be bounded and nonempty" }
        if (@($actor.behavior_states).Count -eq 0) { Add-Error $errors "actor behavior states must be bounded and nonempty" }
        if ([string]$actor.initial_pose -notin @($actor.poses)) { Add-Error $errors "actor initial pose is not declared" }
        if ([string]$actor.initial_behavior -notin @($actor.behavior_states)) { Add-Error $errors "actor initial behavior is not declared" }
    }

    $objectIds = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($object in @($Definition.scene_objects)) {
        [void]$objectIds.Add([string]$object.id)
        if ([string]::IsNullOrWhiteSpace([string]$object.anchor)) { Add-Error $errors "scene object anchor is required" }
        if ($null -eq $object.bounds -or [int]$object.bounds.w -le 0 -or [int]$object.bounds.h -le 0) {
            Add-Error $errors "scene object requires positive bounds"
        }
        if (@($object.visual_states).Count -eq 0 -and @($object.functional_states).Count -eq 0) {
            Add-Error $errors "metadata-only scene object is forbidden"
        }
        foreach ($region in @($object.hit_regions)) {
            if ([int]$region.bounds.w -le 0 -or [int]$region.bounds.h -le 0) {
                Add-Error $errors "hit region requires positive bounds"
            }
        }
    }

    foreach ($tier in @($Definition.energy.tiers)) {
        $materialCount = @($tier.actor_operations).Count + @($tier.object_operations).Count + @($tier.interaction_operations).Count
        if ($materialCount -eq 0) { Add-Error $errors "energy tier must change actor, object, or interactable: $($tier.id)" }
    }

    foreach ($fact in @($Definition.game_facts)) {
        if (-not (Test-QualifiedId ([string]$fact.fact_type))) { Add-Error $errors "fact type must be a qualified id" }
        if ([int]$fact.fact_version -lt 1) { Add-Error $errors "fact version must be positive" }
        if ([string]$fact.boundary -ne "action") { Add-Error $errors "fact must publish at an action boundary" }
        if ([string]$fact.visibility -ne "public") { Add-Error $errors "fixture fact must have public visibility" }
        if (@(Property-Names $fact.payload).Count -eq 0) { Add-Error $errors "fact payload must be typed" }
    }

    foreach ($handler in @($Definition.handler_registry)) {
        if (-not (Test-QualifiedId ([string]$handler.handler_id))) { Add-Error $errors "handler id must be a qualified id" }
        foreach ($key in @("inputs", "outputs", "authority", "persisted_state", "transient_state", "rng", "rejection")) {
            if ($key -notin (Property-Names $handler)) { Add-Error $errors "handler is missing contract field: $key" }
        }
    }

    $operationFamilies = @{
        scene_ops = @("spawn", "replace", "remove", "move", "set_position", "set_visibility", "set_enabled", "set_state", "set_appearance")
        interaction_ops = @("add", "remove", "replace", "gate", "augment", "retarget")
        actor_ops = @("spawn", "despawn", "replace", "set_position", "set_route", "set_pose", "set_behavior")
        transition_ops = @("feedback", "stage", "sound", "music", "scene_change")
    }
    $allOperations = @()
    foreach ($phase in @($Definition.ritual_phases)) {
        $allOperations += @($phase.entry_operations)
        foreach ($transition in @($phase.transitions)) { $allOperations += @($transition.operations) }
    }
    foreach ($tier in @($Definition.energy.tiers)) {
        $allOperations += @($tier.actor_operations) + @($tier.object_operations) + @($tier.interaction_operations)
    }
    foreach ($operation in $allOperations) {
        Add-ClosedShapeErrors $errors "operation" $operation @("operation_id", "family", "verb", "source_owner_id", "target_id", "arguments")
        if (-not (Test-LocalId ([string]$operation.operation_id))) { Add-Error $errors "operation id must be a local id" }
        $family = [string]$operation.family
        if (-not $operationFamilies.ContainsKey($family)) {
            Add-Error $errors "unknown operation family: $family"
        } elseif ([string]$operation.verb -notin @($operationFamilies[$family])) {
            Add-Error $errors "unknown operation verb: $family.$($operation.verb)"
        }
        if (-not (Test-QualifiedId ([string]$operation.source_owner_id))) { Add-Error $errors "operation source owner must be qualified" }
        if (-not (Test-QualifiedId ([string]$operation.target_id))) { Add-Error $errors "operation target must be qualified" }
    }

    foreach ($requiredPersistence in @("authoritative_serialized", "derived_projection", "transient_presentation", "one_shot_receipted", "save_boundaries", "restore_policy")) {
        if ($requiredPersistence -notin (Property-Names $Definition.ritual_persistence)) {
            Add-Error $errors "persistence is missing: $requiredPersistence"
        }
    }
    foreach ($receiptField in @("phase_id", "authoritative_result_refs", "receipts", "fingerprints")) {
        if ($receiptField -notin @($Definition.ritual_persistence.authoritative_serialized)) {
            Add-Error $errors "authoritative persistence is missing: $receiptField"
        }
    }

    $serialized = $Definition | ConvertTo-Json -Depth 100 -Compress
    foreach ($unsafe in @("res://", "NodePath", "preload(", "load(", "class_name", "reflection_target", "script_path")) {
        if ($serialized.IndexOf($unsafe, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            Add-Error $errors "unsafe executable or resource reference: $unsafe"
        }
    }
    return @($errors)
}

function Test-EnvelopeFixture {
    param([Parameter(Mandatory)]$Fixture)
    $errors = [System.Collections.Generic.List[string]]::new()
    Add-ClosedShapeErrors $errors "envelope fixture" $Fixture @("vocabulary_source", "boundary", "command", "result", "rejection", "fact", "operation", "operation_result", "receipt")
    if ([string]$Fixture.vocabulary_source.commit -ne "749390ce") { Add-Error $errors "vocabulary source commit mismatch" }
    if ([string]$Fixture.vocabulary_source.path -ne "docs/todo/env06_6_runtime_vocabulary_and_delivery_handoff.md") { Add-Error $errors "vocabulary source path mismatch" }

    $boundaryFields = @("boundary_id", "kind", "ritual_id", "session_id", "phase_id", "ordinal", "cause_receipt_key")
    foreach ($boundary in @($Fixture.boundary, $Fixture.command.boundary, $Fixture.result.boundary, $Fixture.rejection.boundary, $Fixture.fact.boundary, $Fixture.operation_result.boundary)) {
        Add-ClosedShapeErrors $errors "boundary" $boundary $boundaryFields
        if ([string]$boundary.kind -notin @("phase_entry", "fact_flush", "command", "cleanup", "aftermath_application")) { Add-Error $errors "invalid boundary kind" }
        if (-not (Test-QualifiedId ([string]$boundary.boundary_id))) { Add-Error $errors "boundary id must be qualified" }
        if (-not (Test-QualifiedId ([string]$boundary.ritual_id))) { Add-Error $errors "boundary ritual id must be qualified" }
        if (-not (Test-QualifiedId ([string]$boundary.session_id))) { Add-Error $errors "boundary session id must be qualified" }
        if (-not (Test-LocalId ([string]$boundary.phase_id))) { Add-Error $errors "boundary phase id must be local" }
        if ([int]$boundary.ordinal -lt 1) { Add-Error $errors "boundary ordinal must be positive" }
    }

    $fingerprinted = @($Fixture.command, $Fixture.result, $Fixture.rejection, $Fixture.fact, $Fixture.operation_result, $Fixture.receipt)
    foreach ($record in $fingerprinted) {
        if ([string]$record.receipt_key -cnotmatch '^[a-z0-9][a-z0-9_.:-]{0,191}$') { Add-Error $errors "invalid receipt key" }
        if ([string]$record.content_fingerprint -cnotmatch '^[0-9a-f]{64}$') { Add-Error $errors "invalid content fingerprint" }
    }

    Add-ClosedShapeErrors $errors "command" $Fixture.command @("envelope_version", "ritual_id", "session_id", "command_id", "action_id", "expected_phase", "source_id", "target_id", "parameters", "authenticated_action", "boundary", "receipt_key", "content_fingerprint")
    Add-ClosedShapeErrors $errors "authenticated action" $Fixture.command.authenticated_action @("action_id", "origin_owner_id", "origin_stable_id", "operation_receipt_key", "boundary_id", "content_fingerprint")
    if ([int]$Fixture.command.envelope_version -ne 1) { Add-Error $errors "command envelope version must be 1" }
    if (-not (Test-QualifiedId ([string]$Fixture.command.action_id))) { Add-Error $errors "command action id must be qualified" }

    Add-ClosedShapeErrors $errors "result" $Fixture.result @("envelope_version", "ok", "ritual_id", "session_id", "command_id", "phase_before", "phase_after", "authoritative_result_ref", "state_receipts", "operation_receipts", "fact_receipts", "boundary", "receipt_key", "content_fingerprint", "public_projection")
    if (-not [bool]$Fixture.result.ok) { Add-Error $errors "result must be accepted" }

    Add-ClosedShapeErrors $errors "rejection" $Fixture.rejection @("envelope_version", "ok", "ritual_id", "session_id", "command_id", "phase", "error_code", "public_message", "retryable", "return_policy", "boundary", "receipt_key", "content_fingerprint", "public_projection")
    if ([bool]$Fixture.rejection.ok) { Add-Error $errors "rejection must have ok=false" }
    $errorCodes = @("invalid_envelope", "unsupported_version", "invalid_id", "unknown_reference", "stale_phase", "action_not_permitted", "disabled_action", "blocked_action", "unavailable_source", "unavailable_target", "unsealed_authority", "authority_mismatch", "ambiguous_target", "invalid_parameters", "incomplete_gesture", "out_of_bounds", "inaccessible_target", "precondition_failed", "insufficient_funds", "receipt_content_conflict", "handler_rejected", "invalid_restore", "ambiguous_transition", "internal_fail_closed")
    if ([string]$Fixture.rejection.error_code -notin $errorCodes) { Add-Error $errors "unknown rejection code" }
    if ([string]$Fixture.rejection.return_policy -notin @("none", "return_to_source", "restore_focus")) { Add-Error $errors "unknown rejection return policy" }

    Add-ClosedShapeErrors $errors "fact" $Fixture.fact @("envelope_version", "fact_id", "fact_type", "fact_version", "payload", "visibility", "boundary", "receipt_key", "content_fingerprint")
    if ([string]$Fixture.fact.visibility -ne "public") { Add-Error $errors "fact visibility must be public" }
    if ([int]$Fixture.fact.fact_version -lt 1) { Add-Error $errors "fact version must be positive" }

    $operationFields = @("envelope_version", "operation_id", "family", "verb", "source_owner_id", "target_id", "arguments")
    Add-ClosedShapeErrors $errors "operation envelope" $Fixture.operation $operationFields
    if ([string]$Fixture.operation.family -notin @("scene_ops", "interaction_ops", "actor_ops", "transition_ops")) { Add-Error $errors "unknown operation family" }
    Add-ClosedShapeErrors $errors "operation result" $Fixture.operation_result @("envelope_version", "operation_id", "family", "verb", "target_id", "boundary", "receipt_key", "content_fingerprint", "applied")
    Add-ClosedShapeErrors $errors "receipt" $Fixture.receipt @("receipt_key", "content_fingerprint", "boundary_id", "envelope_kind", "status")
    return @($errors)
}

function Assert-NoErrors {
    param([string]$Name, $Definition)
    $errors = @(Test-RitualDefinition $Definition)
    if ($errors.Count -ne 0) { throw "$Name expected no errors; got: $($errors -join '; ')" }
}

function Assert-Rejected {
    param([string]$Name, $Definition, [string]$Expected)
    $errors = @(Test-RitualDefinition $Definition)
    if ($errors.Count -eq 0) { throw "$Name expected rejection but passed" }
    if (($errors -join "`n").IndexOf($Expected, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "$Name expected '$Expected'; got: $($errors -join '; ')"
    }
}

function Assert-EnvelopeRejected {
    param([string]$Name, $Fixture, [string]$Expected)
    $errors = @(Test-EnvelopeFixture $Fixture)
    if ($errors.Count -eq 0) { throw "$Name expected envelope rejection but passed" }
    if (($errors -join "`n").IndexOf($Expected, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "$Name expected '$Expected'; got: $($errors -join '; ')"
    }
}

if (-not (Test-Path -LiteralPath $fixturePath)) { throw "Missing fixture: $fixturePath" }
if (-not (Test-Path -LiteralPath $envelopeFixturePath)) { throw "Missing fixture: $envelopeFixturePath" }
if (-not (Test-Path -LiteralPath $contractPath)) { throw "Missing contract: $contractPath" }
if (-not (Test-Path -LiteralPath $checklistPath)) { throw "Missing checklist: $checklistPath" }

$definition = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
Assert-NoErrors "worked example" $definition
$envelopes = Get-Content -LiteralPath $envelopeFixturePath -Raw | ConvertFrom-Json
$envelopeErrors = @(Test-EnvelopeFixture $envelopes)
if ($envelopeErrors.Count -ne 0) { throw "shared envelope fixture expected no errors; got: $($envelopeErrors -join '; ')" }

$negativeCount = 0

$bad = Copy-Definition $definition
$bad.contract = "game_ritual/999"
Assert-Rejected "bad version" $bad "unsupported contract version"; $negativeCount++

$bad = Copy-Definition $definition
$bad | Add-Member -NotePropertyName unexpected -NotePropertyValue $true
Assert-Rejected "unknown field" $bad "unknown top-level field"; $negativeCount++

$bad = Copy-Definition $definition
$bad.initial_phase = "missing"
Assert-Rejected "missing initial phase" $bad "initial_phase does not resolve"; $negativeCount++

$bad = Copy-Definition $definition
$bad.ritual_phases[2].id = "orphan"
$bad.ritual_phases[1].transitions[0].next_phase = "resolving"
$bad.ritual_phases[2].transitions[0].next_phase = "open"
Assert-Rejected "unreachable phase" $bad "transition target does not resolve"; $negativeCount++

$bad = Copy-Definition $definition
$duplicate = Copy-Definition $bad.ritual_phases[0].transitions[0]
$bad.ritual_phases[0].transitions = @($bad.ritual_phases[0].transitions) + @($duplicate)
Assert-Rejected "ambiguous transition" $bad "ambiguous transition"; $negativeCount++

$bad = Copy-Definition $definition
$bad.staged_commitment.actions = @($bad.staged_commitment.actions | Where-Object { $_.id -notin @("commit.remove", "commit.correct") })
Assert-Rejected "no single correction" $bad "single-item correction or removal"; $negativeCount++

$bad = Copy-Definition $definition
$bad.pointer_verbs[0].target_regions = @("missing.region")
Assert-Rejected "unbound pointer region" $bad "unbound pointer target region"; $negativeCount++

$bad = Copy-Definition $definition
$bad.pointer_verbs[0].equivalents.PSObject.Properties.Remove("controller")
Assert-Rejected "missing equivalent" $bad "missing pointer equivalent"; $negativeCount++

$bad = Copy-Definition $definition
$bad.pointer_verbs[0].rejection_effects = @("charge")
Assert-Rejected "charged rejection" $bad "rejection must be side-effect-free"; $negativeCount++

$bad = Copy-Definition $definition
$bad.actors[0].behavior_states = @()
Assert-Rejected "actor without states" $bad "actor behavior states"; $negativeCount++

$bad = Copy-Definition $definition
$bad.scene_objects[0].bounds.w = 0
Assert-Rejected "object without bounds" $bad "positive bounds"; $negativeCount++

$bad = Copy-Definition $definition
$bad.scene_objects[0].visual_states = @()
$bad.scene_objects[0].functional_states = @()
Assert-Rejected "metadata-only object" $bad "metadata-only"; $negativeCount++

$bad = Copy-Definition $definition
$bad.energy.tiers[0].object_operations = @()
$bad.energy.tiers[0].audio_cues = @("music_only")
Assert-Rejected "music-only energy" $bad "energy tier must change"; $negativeCount++

$bad = Copy-Definition $definition
$bad.handler_registry[0] | Add-Member -NotePropertyName script_path -NotePropertyValue "res://unsafe.gd"
Assert-Rejected "unsafe executable reference" $bad "unsafe executable or resource reference"; $negativeCount++

$bad = Copy-Definition $definition
$bad.ritual_persistence.authoritative_serialized = @($bad.ritual_persistence.authoritative_serialized | Where-Object { $_ -ne "receipts" })
Assert-Rejected "missing receipts" $bad "authoritative persistence is missing: receipts"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.command | Add-Member -NotePropertyName caller_authority -NotePropertyValue $true
Assert-EnvelopeRejected "open command envelope" $badEnvelope "command unknown field"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.receipt.content_fingerprint = "not-a-fingerprint"
Assert-EnvelopeRejected "invalid receipt fingerprint" $badEnvelope "invalid content fingerprint"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.rejection.error_code = "game_specific_error"
Assert-EnvelopeRejected "open error taxonomy" $badEnvelope "unknown rejection code"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.fact.visibility = "private"
Assert-EnvelopeRejected "private outward fact" $badEnvelope "fact visibility must be public"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.command.authenticated_action.PSObject.Properties.Remove("content_fingerprint")
Assert-EnvelopeRejected "unauthenticated action" $badEnvelope "authenticated action missing field"; $negativeCount++

$contractText = Get-Content -LiteralPath $contractPath -Raw
$checklistText = Get-Content -LiteralPath $checklistPath -Raw
for ($index = 1; $index -le 14; $index++) {
    $marker = "ENV-VOCAB-{0:D2}" -f $index
    if (-not ($contractText.Contains($marker) -or $checklistText.Contains($marker))) {
        throw "Missing frozen handoff mapping marker: $marker"
    }
}

$neutralTargets = @(
    $fixturePath,
    $envelopeFixturePath,
    (Join-Path $ProjectRoot "scripts/core/game_module.gd"),
    (Join-Path $ProjectRoot "scripts/games/table_game_visuals.gd"),
    (Join-Path $ProjectRoot "scripts/ui/game_surface_canvas.gd")
)
foreach ($optionalTarget in @(
    (Join-Path $ProjectRoot "scripts/core/game_ritual_schema.gd"),
    (Join-Path $ProjectRoot "scripts/core/game_ritual_runtime.gd")
)) {
    if (Test-Path -LiteralPath $optionalTarget) { $neutralTargets += $optionalTarget }
}
$forbiddenSharedTerms = @("craps", "come_out", "seven_out", "stickperson", "point_puck")
foreach ($path in $neutralTargets) {
    $text = Get-Content -LiteralPath $path -Raw
    foreach ($term in $forbiddenSharedTerms) {
        if ($text.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw "Shared vocabulary neutrality failure: '$term' in $path"
        }
    }
}

[pscustomobject]@{
    status = "PASS"
    contract = "game_ritual/1"
    fixture = $fixturePath
    negative_fixtures = $negativeCount
    neutrality_targets = $neutralTargets.Count
    env_vocabulary_handoff = "ACCEPTED_749390ce"
} | ConvertTo-Json -Depth 5
