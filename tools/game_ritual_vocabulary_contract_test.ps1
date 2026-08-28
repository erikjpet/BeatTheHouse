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

function Test-ReceiptCondition {
    param([System.Collections.Generic.List[string]]$Errors, $Condition)
    if ([string]$Condition.receipt_kind -notin @("command", "result", "rejection", "fact", "operation", "state", "transition", "phase_entry", "cleanup", "aftermath")) {
        Add-Error $Errors "receipt condition has unknown receipt kind"
    }
    if ([string]$Condition.receipt_key -cnotmatch '^[a-z0-9][a-z0-9_.:-]{0,191}$') {
        Add-Error $Errors "receipt condition has invalid exact receipt key"
    }
    if ([string]$Condition.content_fingerprint -cnotmatch '^[0-9a-f]{64}$') {
        Add-Error $Errors "receipt condition has invalid exact fingerprint"
    }
}

function ConvertTo-CanonicalJson {
    param($Value)
    if ($null -eq $Value) { return "null" }
    if ($Value -is [string]) { return ($Value | ConvertTo-Json -Compress) }
    if ($Value -is [bool]) { return $(if ($Value) { "true" } else { "false" }) }
    if ($Value -is [byte] -or $Value -is [sbyte] -or $Value -is [int16] -or $Value -is [uint16] -or $Value -is [int32] -or $Value -is [uint32] -or $Value -is [int64] -or $Value -is [uint64]) {
        return $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) {
        $number = [double]$Value
        if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) { throw "noncanonical number" }
        return $number.ToString("R", [System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [System.Array]) {
        $items = @($Value | ForEach-Object { ConvertTo-CanonicalJson $_ })
        return "[" + ($items -join ",") + "]"
    }
    $names = @(Property-Names $Value | Sort-Object -CaseSensitive)
    if ($names.Count -gt 0 -or $Value -is [pscustomobject]) {
        $members = foreach ($name in $names) {
            (ConvertTo-CanonicalJson ([string]$name)) + ":" + (ConvertTo-CanonicalJson $Value.$name)
        }
        return "{" + (@($members) -join ",") + "}"
    }
    throw "unsupported canonical value type: $($Value.GetType().FullName)"
}

function Get-CanonicalFingerprint {
    param($Envelope)
    $copy = Copy-Definition $Envelope
    $copy.PSObject.Properties.Remove("content_fingerprint")
    $canonical = ConvertTo-CanonicalJson $copy
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($canonical)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $hash = $sha.ComputeHash($bytes) } finally { $sha.Dispose() }
    return ([System.BitConverter]::ToString($hash).Replace("-", "")).ToLowerInvariant()
}

function Test-CanonicalFingerprint {
    param([System.Collections.Generic.List[string]]$Errors, [string]$Label, $Envelope)
    if ([string]$Envelope.content_fingerprint -cnotmatch '^[0-9a-f]{64}$') {
        Add-Error $Errors "$Label invalid content fingerprint"
        return
    }
    $actual = Get-CanonicalFingerprint $Envelope
    if ([string]$Envelope.content_fingerprint -cne $actual) { Add-Error $Errors "$Label canonical fingerprint mismatch" }
}

function Test-DeclaredValueType {
    param($Value, [string]$Type)
    switch ($Type) {
        "bool" { return $Value -is [bool] }
        "int" { return $Value -is [int64] -or $Value -is [int32] }
        "float" { return $Value -is [double] -or $Value -is [single] -or $Value -is [decimal] }
        "string" { return $Value -is [string] }
        "qualified_id" { return $Value -is [string] -and (Test-QualifiedId ([string]$Value)) }
        "string_array" { return $Value -is [System.Array] -and @($Value | Where-Object { $_ -isnot [string] }).Count -eq 0 }
        "int_array" { return $Value -is [System.Array] -and @($Value | Where-Object { $_ -isnot [int64] -and $_ -isnot [int32] }).Count -eq 0 }
        default { return $false }
    }
}

function Test-RitualDefinition {
    param([Parameter(Mandatory)]$Definition)

    $errors = [System.Collections.Generic.List[string]]::new()
    $allowedTop = @(
        "contract", "ritual_id", "initial_phase", "ritual_phases", "action_declarations",
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
        Add-ClosedShapeErrors $errors "phase" $phase @("id", "entry_conditions", "permitted_actions", "entry_operations", "transitions", "terminal")
        $phaseId = [string]$phase.id
        if (-not (Test-LocalId $phaseId)) {
            Add-Error $errors "phase id must be a local id"
        } elseif ($phaseById.ContainsKey($phaseId)) {
            Add-Error $errors "duplicate phase id: $phaseId"
        } else {
            $phaseById[$phaseId] = $phase
        }
        foreach ($condition in @($phase.entry_conditions)) {
            $conditionFields = @{
                accepted_action = @("kind", "action_id")
                fact = @("kind", "fact_type", "payload_equals")
                receipt_present = @("kind", "receipt_kind", "receipt_key", "content_fingerprint")
                authoritative_result_present = @("kind")
                public_state_equals = @("kind", "key", "value")
            }
            $kind = [string]$condition.kind
            if (-not $conditionFields.ContainsKey($kind)) { Add-Error $errors "unknown condition kind: $kind" }
            else {
                Add-ClosedShapeErrors $errors "condition" $condition $conditionFields[$kind]
                if ($kind -eq "receipt_present") { Test-ReceiptCondition $errors $condition }
            }
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
            Add-ClosedShapeErrors $errors "transition" $transition @("id", "condition", "next_phase", "operations")
            $transitionConditionFields = @{
                accepted_action = @("kind", "action_id")
                fact = @("kind", "fact_type", "payload_equals")
                receipt_present = @("kind", "receipt_kind", "receipt_key", "content_fingerprint")
                authoritative_result_present = @("kind")
                public_state_equals = @("kind", "key", "value")
            }
            $transitionKind = [string]$transition.condition.kind
            if (-not $transitionConditionFields.ContainsKey($transitionKind)) { Add-Error $errors "unknown transition condition kind: $transitionKind" }
            else { Add-ClosedShapeErrors $errors "transition condition" $transition.condition $transitionConditionFields[$transitionKind] }
            if ($transitionKind -eq "receipt_present") {
                Test-ReceiptCondition $errors $transition.condition
            }
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

    $actionById = @{}
    foreach ($declaration in @($Definition.action_declarations)) {
        Add-ClosedShapeErrors $errors "action declaration" $declaration @("action_id", "handler_id", "parameters")
        $actionId = [string]$declaration.action_id
        if (-not (Test-QualifiedId $actionId)) { Add-Error $errors "action declaration id must be qualified" }
        elseif ($actionById.ContainsKey($actionId)) { Add-Error $errors "duplicate action declaration: $actionId" }
        else { $actionById[$actionId] = $declaration }
        if (-not (Test-QualifiedId ([string]$declaration.handler_id))) { Add-Error $errors "action declaration handler id must be qualified" }
        foreach ($parameterName in (Property-Names $declaration.parameters)) {
            if (-not (Test-LocalId $parameterName)) { Add-Error $errors "action parameter name must be a local id" }
            if ([string]$declaration.parameters.$parameterName -notin @("bool", "int", "float", "string", "qualified_id", "string_array", "int_array")) {
                Add-Error $errors "action parameter type is not registered"
            }
        }
    }

    Add-ClosedShapeErrors $errors "staged commitment" $Definition.staged_commitment @("pending_collection", "working_collection", "resolution_collection", "funds_authority", "actions", "readable_totals")
    foreach ($commitAction in @($Definition.staged_commitment.actions)) {
        Add-ClosedShapeErrors $errors "commitment action" $commitAction @("id", "effect")
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
    foreach ($action in $commitActions) { [void]$allActions.Add([string]$action) }
    foreach ($action in $allActions) {
        if (-not $actionById.ContainsKey([string]$action)) { Add-Error $errors "permitted action lacks declaration: $action" }
    }
    foreach ($action in $actionById.Keys) {
        if (-not $allActions.Contains([string]$action)) { Add-Error $errors "action declaration is not used by any phase: $action" }
    }
    foreach ($verb in @($Definition.pointer_verbs)) {
        Add-ClosedShapeErrors $errors "pointer verb" $verb @("id", "verb", "source_region", "target_regions", "bounds", "phases", "accepted_action", "rejection", "rejection_effects", "equivalents")
        Add-ClosedShapeErrors $errors "pointer bounds" $verb.bounds @("space", "min_distance", "max_distance")
        Add-ClosedShapeErrors $errors "pointer equivalents" $verb.equivalents @("keyboard", "controller", "reduced_motion")
        Add-ClosedShapeErrors $errors "keyboard equivalent" $verb.equivalents.keyboard @("action_id", "target_selection")
        Add-ClosedShapeErrors $errors "controller equivalent" $verb.equivalents.controller @("action_id", "target_selection")
        Add-ClosedShapeErrors $errors "reduced motion equivalent" $verb.equivalents.reduced_motion @("action_id", "target_selection", "staging")
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
        Add-ClosedShapeErrors $errors "actor" $actor @("id", "role", "anchor", "poses", "behavior_states", "initial_pose", "initial_behavior", "fact_reactions")
        [void]$actorIds.Add([string]$actor.id)
        if ([string]::IsNullOrWhiteSpace([string]$actor.anchor)) { Add-Error $errors "actor anchor is required" }
        if (@($actor.poses).Count -eq 0) { Add-Error $errors "actor poses must be bounded and nonempty" }
        if (@($actor.behavior_states).Count -eq 0) { Add-Error $errors "actor behavior states must be bounded and nonempty" }
        if ([string]$actor.initial_pose -notin @($actor.poses)) { Add-Error $errors "actor initial pose is not declared" }
        if ([string]$actor.initial_behavior -notin @($actor.behavior_states)) { Add-Error $errors "actor initial behavior is not declared" }
        foreach ($reaction in @($actor.fact_reactions)) {
            Add-ClosedShapeErrors $errors "actor fact reaction" $reaction @("fact_type", "operation_ids")
        }
    }

    $objectIds = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($object in @($Definition.scene_objects)) {
        Add-ClosedShapeErrors $errors "scene object" $object @("id", "anchor", "bounds", "z_layer", "visual_states", "functional_states", "initial_visual_state", "initial_functional_state", "hit_regions", "text_safety_regions")
        Add-ClosedShapeErrors $errors "scene object bounds" $object.bounds @("space", "x", "y", "w", "h")
        [void]$objectIds.Add([string]$object.id)
        if ([string]::IsNullOrWhiteSpace([string]$object.anchor)) { Add-Error $errors "scene object anchor is required" }
        if ($null -eq $object.bounds -or [int]$object.bounds.w -le 0 -or [int]$object.bounds.h -le 0) {
            Add-Error $errors "scene object requires positive bounds"
        }
        if (@($object.visual_states).Count -eq 0 -and @($object.functional_states).Count -eq 0) {
            Add-Error $errors "metadata-only scene object is forbidden"
        }
        foreach ($region in @($object.hit_regions)) {
            Add-ClosedShapeErrors $errors "hit region" $region @("id", "bounds", "minimum_touch_target")
            Add-ClosedShapeErrors $errors "hit region bounds" $region.bounds @("space", "x", "y", "w", "h")
            if ([int]$region.bounds.w -le 0 -or [int]$region.bounds.h -le 0) {
                Add-Error $errors "hit region requires positive bounds"
            }
        }
        foreach ($region in @($object.text_safety_regions)) {
            Add-ClosedShapeErrors $errors "text safety region" $region @("id", "bounds")
            Add-ClosedShapeErrors $errors "text safety bounds" $region.bounds @("space", "x", "y", "w", "h")
            if ([int]$region.bounds.w -le 0 -or [int]$region.bounds.h -le 0) { Add-Error $errors "text safety region requires positive bounds" }
        }
    }

    Add-ClosedShapeErrors $errors "energy" $Definition.energy @("initial_tier", "tiers")
    foreach ($tier in @($Definition.energy.tiers)) {
        Add-ClosedShapeErrors $errors "energy tier" $tier @("id", "actor_operations", "object_operations", "interaction_operations", "audio_cues")
        $materialCount = @($tier.actor_operations).Count + @($tier.object_operations).Count + @($tier.interaction_operations).Count
        if ($materialCount -eq 0) { Add-Error $errors "energy tier must change actor, object, or interactable: $($tier.id)" }
    }

    foreach ($fact in @($Definition.game_facts)) {
        Add-ClosedShapeErrors $errors "fact declaration" $fact @("fact_type", "fact_version", "boundary", "visibility", "payload")
        if (-not (Test-QualifiedId ([string]$fact.fact_type))) { Add-Error $errors "fact type must be a qualified id" }
        if ([int]$fact.fact_version -lt 1) { Add-Error $errors "fact version must be positive" }
        if ([string]$fact.boundary -ne "action") { Add-Error $errors "fact must publish at an action boundary" }
        if ([string]$fact.visibility -ne "public") { Add-Error $errors "fixture fact must have public visibility" }
        if (@(Property-Names $fact.payload).Count -eq 0) { Add-Error $errors "fact payload must be typed" }
        foreach ($payloadKey in (Property-Names $fact.payload)) {
            if (-not (Test-LocalId $payloadKey)) { Add-Error $errors "fact payload key must be a local id" }
            if ([string]$fact.payload.$payloadKey -notin @("bool", "int", "float", "string", "qualified_id", "string_array", "int_array")) { Add-Error $errors "fact payload type is not registered" }
        }
    }

    $handlerById = @{}
    $actionHandlerBindings = @{}
    $operationHandlerBindings = @{}
    foreach ($handler in @($Definition.handler_registry)) {
        Add-ClosedShapeErrors $errors "handler" $handler @("handler_id", "version", "accepted_actions", "accepted_operations", "inputs", "outputs", "authority", "persisted_state", "transient_state", "rng", "emitted_facts", "rejection")
        Add-ClosedShapeErrors $errors "handler rng" $handler.rng @("owner", "stream", "consumption")
        $handlerId = [string]$handler.handler_id
        if (-not (Test-QualifiedId $handlerId)) { Add-Error $errors "handler id must be a qualified id" }
        elseif ($handlerById.ContainsKey($handlerId)) { Add-Error $errors "duplicate handler id: $handlerId" }
        else { $handlerById[$handlerId] = $handler }
        foreach ($key in @("inputs", "outputs", "authority", "persisted_state", "transient_state", "rng", "rejection")) {
            if ($key -notin (Property-Names $handler)) { Add-Error $errors "handler is missing contract field: $key" }
        }
        foreach ($schemaName in @("inputs", "outputs")) {
            foreach ($schemaKey in (Property-Names $handler.$schemaName)) {
                if (-not (Test-LocalId $schemaKey)) { Add-Error $errors "handler $schemaName key must be a local id" }
                if ([string]$handler.$schemaName.$schemaKey -notin @("bool", "int", "float", "string", "qualified_id", "string_array", "int_array")) { Add-Error $errors "handler $schemaName type is not registered" }
            }
        }
        foreach ($actionId in @($handler.accepted_actions)) {
            $actionId = [string]$actionId
            if (-not $actionById.ContainsKey($actionId)) { Add-Error $errors "handler accepts undeclared action: $actionId" }
            elseif ([string]$actionById[$actionId].handler_id -ne $handlerId) { Add-Error $errors "action declaration handler mismatch: $actionId" }
            if ($actionHandlerBindings.ContainsKey($actionId)) { Add-Error $errors "action accepted by multiple handlers: $actionId" }
            else { $actionHandlerBindings[$actionId] = $handlerId }
        }
        foreach ($operationId in @($handler.accepted_operations)) {
            $operationId = [string]$operationId
            if ($operationHandlerBindings.ContainsKey($operationId)) { Add-Error $errors "operation accepted by multiple handlers: $operationId" }
            else { $operationHandlerBindings[$operationId] = $handlerId }
        }
    }
    foreach ($actionId in $actionById.Keys) {
        if (-not $handlerById.ContainsKey([string]$actionById[$actionId].handler_id)) { Add-Error $errors "action declaration references unknown handler: $actionId" }
        if (-not $actionHandlerBindings.ContainsKey($actionId)) { Add-Error $errors "action is not accepted by its handler: $actionId" }
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
    $authoredOperationIds = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($operation in $allOperations) {
        Add-ClosedShapeErrors $errors "operation" $operation @("operation_id", "family", "verb", "source_owner_id", "target_id", "arguments")
        if (-not (Test-LocalId ([string]$operation.operation_id))) { Add-Error $errors "operation id must be a local id" }
        elseif (-not $authoredOperationIds.Add([string]$operation.operation_id)) { Add-Error $errors "duplicate operation id: $($operation.operation_id)" }
        $family = [string]$operation.family
        if (-not $operationFamilies.ContainsKey($family)) {
            Add-Error $errors "unknown operation family: $family"
        } elseif ([string]$operation.verb -notin @($operationFamilies[$family])) {
            Add-Error $errors "unknown operation verb: $family.$($operation.verb)"
        }
        if (-not (Test-QualifiedId ([string]$operation.source_owner_id))) { Add-Error $errors "operation source owner must be qualified" }
        if (-not (Test-QualifiedId ([string]$operation.target_id))) { Add-Error $errors "operation target must be qualified" }
        $argumentShapes = @{
            "scene_ops.spawn" = @("anchor_id", "zone_id", "state")
            "scene_ops.replace" = @("replacement_id")
            "scene_ops.remove" = @("reason")
            "scene_ops.move" = @("anchor_id", "zone_id")
            "scene_ops.set_position" = @("anchor_id")
            "scene_ops.set_visibility" = @("visible")
            "scene_ops.set_enabled" = @("enabled")
            "scene_ops.set_state" = @("state_slot", "state")
            "scene_ops.set_appearance" = @("appearance")
            "interaction_ops.add" = @("anchor_id", "actions", "enabled", "safe_exit", "alternate_exit")
            "interaction_ops.remove" = @("reason")
            "interaction_ops.replace" = @("replacement_id")
            "interaction_ops.gate" = @("enabled", "reason")
            "interaction_ops.augment" = @("actions")
            "interaction_ops.retarget" = @("target_id")
            "actor_ops.spawn" = @("anchor_id", "pose", "behavior", "route_request_id")
            "actor_ops.despawn" = @("reason")
            "actor_ops.replace" = @("replacement_id")
            "actor_ops.set_position" = @("anchor_id")
            "actor_ops.set_route" = @("route_request_id")
            "actor_ops.set_pose" = @("pose")
            "actor_ops.set_behavior" = @("behavior")
            "transition_ops.feedback" = @("message")
            "transition_ops.stage" = @("stage_id", "duration_boundaries", "reduced_motion_text")
            "transition_ops.sound" = @("cue_id")
            "transition_ops.music" = @("cue_id")
            "transition_ops.scene_change" = @("scene_state_id")
        }
        $operationKey = "$family.$($operation.verb)"
        if ($argumentShapes.ContainsKey($operationKey)) {
            Add-ClosedShapeErrors $errors "operation arguments $operationKey" $operation.arguments $argumentShapes[$operationKey]
        }
    }
    foreach ($operationId in $authoredOperationIds) {
        if (-not $operationHandlerBindings.ContainsKey([string]$operationId)) { Add-Error $errors "authored operation lacks handler binding: $operationId" }
    }
    foreach ($operationId in $operationHandlerBindings.Keys) {
        if (-not $authoredOperationIds.Contains([string]$operationId)) { Add-Error $errors "handler accepts unknown operation: $operationId" }
    }

    foreach ($requiredPersistence in @("authoritative_serialized", "derived_projection", "transient_presentation", "one_shot_receipted", "save_boundaries", "restore_policy")) {
        if ($requiredPersistence -notin (Property-Names $Definition.ritual_persistence)) {
            Add-Error $errors "persistence is missing: $requiredPersistence"
        }
    }
    Add-ClosedShapeErrors $errors "ritual persistence" $Definition.ritual_persistence @("authoritative_serialized", "derived_projection", "transient_presentation", "one_shot_receipted", "save_boundaries", "restore_policy")
    Add-ClosedShapeErrors $errors "declared targets" $Definition.declared_targets @("anchors", "regions", "sealed_host_targets")
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
    param([Parameter(Mandatory)]$Fixture, [Parameter(Mandatory)]$Definition)
    $errors = [System.Collections.Generic.List[string]]::new()
    Add-ClosedShapeErrors $errors "envelope fixture" $Fixture @("vocabulary_source", "boundary", "command", "result", "rejection", "fact", "operation", "operation_result", "receipt", "request_cache")
    Add-ClosedShapeErrors $errors "vocabulary source" $Fixture.vocabulary_source @("commit", "path")
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

    $fingerprinted = @($Fixture.command, $Fixture.result, $Fixture.rejection, $Fixture.fact, $Fixture.operation_result)
    $receiptOwners = @{}
    foreach ($record in $fingerprinted) {
        if ([string]$record.receipt_key -cnotmatch '^[a-z0-9][a-z0-9_.:-]{0,191}$') { Add-Error $errors "invalid receipt key" }
        $receiptKey = [string]$record.receipt_key
        if ($receiptOwners.ContainsKey($receiptKey)) { Add-Error $errors "one receipt key identifies multiple envelopes: $receiptKey" }
        else { $receiptOwners[$receiptKey] = $record }
    }

    Test-CanonicalFingerprint $errors "command" $Fixture.command
    Test-CanonicalFingerprint $errors "result" $Fixture.result
    Test-CanonicalFingerprint $errors "rejection" $Fixture.rejection
    Test-CanonicalFingerprint $errors "fact" $Fixture.fact
    Test-CanonicalFingerprint $errors "operation result" $Fixture.operation_result

    Add-ClosedShapeErrors $errors "command" $Fixture.command @("envelope_version", "ritual_id", "session_id", "command_id", "request_key", "action_id", "expected_phase", "source_id", "target_id", "parameters", "authenticated_action", "boundary", "receipt_key", "content_fingerprint")
    Add-ClosedShapeErrors $errors "authenticated action" $Fixture.command.authenticated_action @("action_id", "origin_owner_id", "origin_stable_id", "operation_receipt_key", "boundary_id", "content_fingerprint")
    if ([int]$Fixture.command.envelope_version -ne 1) { Add-Error $errors "command envelope version must be 1" }
    if (-not (Test-QualifiedId ([string]$Fixture.command.action_id))) { Add-Error $errors "command action id must be qualified" }

    $actionDeclaration = @($Definition.action_declarations | Where-Object { [string]$_.action_id -eq [string]$Fixture.command.action_id })
    if ($actionDeclaration.Count -ne 1) { Add-Error $errors "command action must resolve to one declaration" }
    else {
        $schema = $actionDeclaration[0].parameters
        Add-ClosedShapeErrors $errors "command parameters" $Fixture.command.parameters @(Property-Names $schema)
        foreach ($parameterName in (Property-Names $schema)) {
            if (-not (Test-DeclaredValueType $Fixture.command.parameters.$parameterName ([string]$schema.$parameterName))) {
                Add-Error $errors "command parameter has wrong declared type: $parameterName"
            }
        }
    }

    Add-ClosedShapeErrors $errors "result" $Fixture.result @("envelope_version", "ok", "ritual_id", "session_id", "command_id", "request_key", "phase_before", "phase_after", "authoritative_result_ref", "state_receipts", "operation_receipts", "fact_receipts", "boundary", "receipt_key", "content_fingerprint", "public_projection")
    if (-not [bool]$Fixture.result.ok) { Add-Error $errors "result must be accepted" }

    Add-ClosedShapeErrors $errors "rejection" $Fixture.rejection @("envelope_version", "ok", "ritual_id", "session_id", "command_id", "request_key", "phase", "error_code", "public_message", "retryable", "return_policy", "boundary", "receipt_key", "content_fingerprint", "public_projection")
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
    Add-ClosedShapeErrors $errors "request cache" $Fixture.request_cache @("request_key", "command_receipt_key", "command_content_fingerprint", "response_receipt_key", "response_content_fingerprint", "status")
    if ([string]$Fixture.request_cache.status -notin @("pending", "resolved", "rejected")) { Add-Error $errors "request cache has unknown status" }
    foreach ($cacheFingerprint in @($Fixture.request_cache.command_content_fingerprint, $Fixture.request_cache.response_content_fingerprint)) {
        if ([string]$cacheFingerprint -cnotmatch '^[0-9a-f]{64}$') { Add-Error $errors "request cache has invalid envelope fingerprint" }
    }
    foreach ($requestKey in @($Fixture.command.request_key, $Fixture.result.request_key, $Fixture.rejection.request_key, $Fixture.request_cache.request_key)) {
        if ([string]$requestKey -cnotmatch '^[a-z0-9][a-z0-9_.:-]{0,191}$') { Add-Error $errors "invalid request key" }
    }
    if ([string]$Fixture.command.request_key -cne [string]$Fixture.result.request_key) { Add-Error $errors "result request identity does not match command" }
    if ([string]$Fixture.command.receipt_key -ceq [string]$Fixture.result.receipt_key) { Add-Error $errors "command and result must own distinct receipt keys" }
    if ([string]$Fixture.request_cache.request_key -cne [string]$Fixture.command.request_key -or
        [string]$Fixture.request_cache.command_receipt_key -cne [string]$Fixture.command.receipt_key -or
        [string]$Fixture.request_cache.command_content_fingerprint -cne [string]$Fixture.command.content_fingerprint -or
        [string]$Fixture.request_cache.response_receipt_key -cne [string]$Fixture.result.receipt_key -or
        [string]$Fixture.request_cache.response_content_fingerprint -cne [string]$Fixture.result.content_fingerprint) {
        Add-Error $errors "request cache does not bind exact command and response envelopes"
    }
    if ([string]$Fixture.receipt.receipt_key -cne [string]$Fixture.operation_result.receipt_key -or
        [string]$Fixture.receipt.content_fingerprint -cne [string]$Fixture.operation_result.content_fingerprint -or
        [string]$Fixture.receipt.envelope_kind -cne "operation") {
        Add-Error $errors "receipt record does not identify exactly one operation envelope"
    }
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
    param([string]$Name, $Fixture, $Definition, [string]$Expected)
    $errors = @(Test-EnvelopeFixture $Fixture $Definition)
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
$envelopeErrors = @(Test-EnvelopeFixture $envelopes $definition)
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

$bad = Copy-Definition $definition
$bad.ritual_phases[1].entry_conditions[0].PSObject.Properties.Remove("receipt_key")
Assert-Rejected "receipt condition missing exact key" $bad "condition missing field: receipt_key"; $negativeCount++

$bad = Copy-Definition $definition
$bad.ritual_phases[1].entry_conditions[0].receipt_kind = "commitment"
Assert-Rejected "receipt condition open kind" $bad "unknown receipt kind"; $negativeCount++

$bad = Copy-Definition $definition
$bad.ritual_phases[1].entry_conditions[0].receipt_key = "UPPER/unsafe"
Assert-Rejected "receipt condition malformed key" $bad "invalid exact receipt key"; $negativeCount++

$bad = Copy-Definition $definition
$bad.ritual_phases[1].entry_conditions[0].content_fingerprint = "same-key-is-not-enough"
Assert-Rejected "receipt condition malformed fingerprint" $bad "invalid exact fingerprint"; $negativeCount++

$bad = Copy-Definition $definition
$bad.ritual_phases[0].permitted_actions += @("undeclared.action")
Assert-Rejected "undeclared permitted action" $bad "permitted action lacks declaration"; $negativeCount++

$bad = Copy-Definition $definition
$bad.action_declarations[0].parameters.amount = "variant"
Assert-Rejected "open action parameter type" $bad "action parameter type is not registered"; $negativeCount++

$bad = Copy-Definition $definition
$bad.handler_registry[0].accepted_actions = @($bad.handler_registry[0].accepted_actions | Where-Object { $_ -ne "commit.place" })
Assert-Rejected "handler omits declared action" $bad "action is not accepted by its handler"; $negativeCount++

$bad = Copy-Definition $definition
$bad.handler_registry[0].accepted_operations += @("unknown_operation")
Assert-Rejected "handler accepts unknown operation" $bad "handler accepts unknown operation"; $negativeCount++

$bad = Copy-Definition $definition
$bad.handler_registry[1].accepted_operations += @("staff_offer")
Assert-Rejected "operation bound to two handlers" $bad "operation accepted by multiple handlers"; $negativeCount++

$unknownFieldCases = @(
    @{ name = "phase"; expected = "phase unknown field"; mutate = { param($x) $x.ritual_phases[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "action declaration"; expected = "action declaration unknown field"; mutate = { param($x) $x.action_declarations[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "condition"; expected = "condition unknown field"; mutate = { param($x) $x.ritual_phases[1].entry_conditions[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "transition"; expected = "transition unknown field"; mutate = { param($x) $x.ritual_phases[0].transitions[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "transition condition"; expected = "transition condition unknown field"; mutate = { param($x) $x.ritual_phases[0].transitions[0].condition | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "staged commitment"; expected = "staged commitment unknown field"; mutate = { param($x) $x.staged_commitment | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "commitment action"; expected = "commitment action unknown field"; mutate = { param($x) $x.staged_commitment.actions[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "pointer verb"; expected = "pointer verb unknown field"; mutate = { param($x) $x.pointer_verbs[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "pointer bounds"; expected = "pointer bounds unknown field"; mutate = { param($x) $x.pointer_verbs[0].bounds | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "pointer equivalents"; expected = "pointer equivalents unknown field"; mutate = { param($x) $x.pointer_verbs[0].equivalents | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "equivalent action"; expected = "keyboard equivalent unknown field"; mutate = { param($x) $x.pointer_verbs[0].equivalents.keyboard | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "actor"; expected = "actor unknown field"; mutate = { param($x) $x.actors[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "actor fact reaction"; expected = "actor fact reaction unknown field"; mutate = { param($x) $x.actors[0].fact_reactions[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "scene object"; expected = "scene object unknown field"; mutate = { param($x) $x.scene_objects[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "scene object bounds"; expected = "scene object bounds unknown field"; mutate = { param($x) $x.scene_objects[0].bounds | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "hit region"; expected = "hit region unknown field"; mutate = { param($x) $x.scene_objects[0].hit_regions[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "hit region bounds"; expected = "hit region bounds unknown field"; mutate = { param($x) $x.scene_objects[0].hit_regions[0].bounds | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "text safety region"; expected = "text safety region unknown field"; mutate = { param($x) $x.scene_objects[0].text_safety_regions[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "text safety bounds"; expected = "text safety bounds unknown field"; mutate = { param($x) $x.scene_objects[0].text_safety_regions[0].bounds | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "energy"; expected = "energy unknown field"; mutate = { param($x) $x.energy | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "energy tier"; expected = "energy tier unknown field"; mutate = { param($x) $x.energy.tiers[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "operation"; expected = "operation unknown field"; mutate = { param($x) $x.ritual_phases[0].transitions[0].operations[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "operation arguments"; expected = "operation arguments actor_ops.set_pose unknown field"; mutate = { param($x) $x.ritual_phases[0].transitions[0].operations[0].arguments | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "fact declaration"; expected = "fact declaration unknown field"; mutate = { param($x) $x.game_facts[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "persistence"; expected = "ritual persistence unknown field"; mutate = { param($x) $x.ritual_persistence | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "handler"; expected = "handler unknown field"; mutate = { param($x) $x.handler_registry[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "handler rng"; expected = "handler rng unknown field"; mutate = { param($x) $x.handler_registry[0].rng | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "declared targets"; expected = "declared targets unknown field"; mutate = { param($x) $x.declared_targets | Add-Member -NotePropertyName extra -NotePropertyValue $true } }
)
foreach ($case in $unknownFieldCases) {
    $bad = Copy-Definition $definition
    & $case.mutate $bad
    Assert-Rejected "nested unknown field $($case.name)" $bad $case.expected
    $negativeCount++
}

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.command | Add-Member -NotePropertyName caller_authority -NotePropertyValue $true
Assert-EnvelopeRejected "open command envelope" $badEnvelope $definition "command unknown field"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.operation_result.content_fingerprint = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
Assert-EnvelopeRejected "invalid receipt fingerprint" $badEnvelope $definition "canonical fingerprint mismatch"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.command.parameters | Add-Member -NotePropertyName caller_hint -NotePropertyValue 1
Assert-EnvelopeRejected "open action parameters" $badEnvelope $definition "command parameters unknown field"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.command.parameters.PSObject.Properties.Remove("amount")
Assert-EnvelopeRejected "missing action parameter" $badEnvelope $definition "command parameters missing field"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.command.parameters.amount = "5"
Assert-EnvelopeRejected "wrong action parameter type" $badEnvelope $definition "wrong declared type"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.result.receipt_key = $badEnvelope.command.receipt_key
Assert-EnvelopeRejected "command/result receipt alias" $badEnvelope $definition "distinct receipt keys"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.result.content_fingerprint = $badEnvelope.command.content_fingerprint
Assert-EnvelopeRejected "copied command fingerprint on result" $badEnvelope $definition "result canonical fingerprint mismatch"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.request_cache.response_receipt_key = "receipt:result:wrong"
Assert-EnvelopeRejected "request cache wrong response" $badEnvelope $definition "request cache does not bind"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.rejection.error_code = "game_specific_error"
Assert-EnvelopeRejected "open error taxonomy" $badEnvelope $definition "unknown rejection code"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.fact.visibility = "private"
Assert-EnvelopeRejected "private outward fact" $badEnvelope $definition "fact visibility must be public"; $negativeCount++

$badEnvelope = Copy-Definition $envelopes
$badEnvelope.command.authenticated_action.PSObject.Properties.Remove("content_fingerprint")
Assert-EnvelopeRejected "unauthenticated action" $badEnvelope $definition "authenticated action missing field"; $negativeCount++

$envelopeUnknownCases = @(
    @{ name = "vocabulary source"; expected = "vocabulary source unknown field"; mutate = { param($x) $x.vocabulary_source | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "boundary"; expected = "boundary unknown field"; mutate = { param($x) $x.boundary | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "result"; expected = "result unknown field"; mutate = { param($x) $x.result | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "rejection"; expected = "rejection unknown field"; mutate = { param($x) $x.rejection | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "fact"; expected = "fact unknown field"; mutate = { param($x) $x.fact | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "operation envelope"; expected = "operation envelope unknown field"; mutate = { param($x) $x.operation | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "operation result"; expected = "operation result unknown field"; mutate = { param($x) $x.operation_result | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "receipt"; expected = "receipt unknown field"; mutate = { param($x) $x.receipt | Add-Member -NotePropertyName extra -NotePropertyValue $true } },
    @{ name = "request cache"; expected = "request cache unknown field"; mutate = { param($x) $x.request_cache | Add-Member -NotePropertyName extra -NotePropertyValue $true } }
)
foreach ($case in $envelopeUnknownCases) {
    $badEnvelope = Copy-Definition $envelopes
    & $case.mutate $badEnvelope
    Assert-EnvelopeRejected "nested envelope unknown field $($case.name)" $badEnvelope $definition $case.expected
    $negativeCount++
}

$canonicalCommand = ConvertTo-CanonicalJson $envelopes.command
$reorderedCommand = [pscustomobject][ordered]@{}
foreach ($name in @((Property-Names $envelopes.command) | Sort-Object -CaseSensitive -Descending)) {
    $reorderedCommand | Add-Member -NotePropertyName $name -NotePropertyValue $envelopes.command.$name
}
if ((ConvertTo-CanonicalJson $reorderedCommand) -cne $canonicalCommand) { throw "Canonical semantics depend on dictionary insertion order" }
if ((ConvertTo-CanonicalJson 1) -ceq (ConvertTo-CanonicalJson "1")) { throw "Canonical semantics coerce integer and string" }
if ((ConvertTo-CanonicalJson @("a", "b")) -ceq (ConvertTo-CanonicalJson @("b", "a"))) { throw "Canonical semantics do not preserve authored array order" }

$contractText = Get-Content -LiteralPath $contractPath -Raw
$checklistText = Get-Content -LiteralPath $checklistPath -Raw
for ($index = 1; $index -le 14; $index++) {
    $marker = "ENV-VOCAB-{0:D2}" -f $index
    if (-not ($contractText.Contains($marker) -or $checklistText.Contains($marker))) {
        throw "Missing frozen handoff mapping marker: $marker"
    }
}

$consumerMarkers = @(
    "ordinary staffed casino table", "hot/high-stakes table",
    "security/audit table", "ordinary street circle",
    "interrupted/relocated street circle", "blackjack", "baccarat",
    "roulette", "machine games", "counter games", "bar dice",
    "Rourke showdown duel"
)
foreach ($consumer in $consumerMarkers) {
    if ($contractText.IndexOf("| $consumer |", [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Missing concrete consumer matrix row: $consumer"
    }
}

$seamMarkers = @(
    "scripts/core/game_module.gd::surface_state",
    "GameModule::draw_surface",
    "surface_action_command",
    "surface_pointer_command",
    "checkpoint_surface_ui_state",
    "scripts/games/table_game_visuals.gd",
    "scripts/ui/game_surface_canvas.gd",
    "scripts/games/scratch_tickets.gd",
    "scripts/games/coin_pusher.gd",
    "performance_liveness_guard.gd",
    "RunState"
)
foreach ($seam in $seamMarkers) {
    if ($contractText.IndexOf($seam, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Missing current seam inventory entry: $seam"
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
