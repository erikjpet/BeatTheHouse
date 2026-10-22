extends RefCounted

# A runtime-only, detached publication of a successfully committed room. Never
# retains a mutable input/output alias. At action boundaries its accepted proof
# can be reused only for exactly equal authority inputs; getters never validate.
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentObjectManifestScript := preload("res://scripts/core/environment_object_manifest.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")
const ScenarioSequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const MAX_AUTHORITY_GAME_INPUT_BYTES := 64 * 1024

var _environment: Dictionary
var _proof: Dictionary
var _authority_game_inputs: Dictionary = {}
var _proof_reuse_safe := false
var _surface_input_bytes := PackedByteArray()
var _compilation_input_bytes := PackedByteArray()
var _compilation_kind := ""
var _empty_flush_definition_bytes := PackedByteArray()
var _empty_flush_input_bytes := PackedByteArray()
var _empty_flush_boundary := -1
var _empty_flush_result: Dictionary = {}


func retain_verified_empty_flush(definition: Dictionary, boundary: int, result: Dictionary) -> void:
	# Called only after RunState's real Runtime/Engine flush and physical commit.
	# A physical publication or a saved readiness flag alone cannot mint this.
	_empty_flush_result = {}
	if not _proof_reuse_safe or not bool(result.get("ok", false)): return
	var state := _dict(_environment.get("scenario_sequence_state", {}))
	if str(state.get("status", "")) == "cleaned" \
			or typeof(state.get("fact_queue")) != TYPE_ARRAY \
			or not (state["fact_queue"] as Array).is_empty(): return
	# Verify the next empty batch's status/capacity/counter rules, not just the
	# preceding operation's success. Retain only Runtime's exact no-op outcome.
	var next_empty := ScenarioSequenceRuntimeScript.flush_facts(state, definition, boundary, true)
	if not bool(next_empty.get("ok", false)) or not is_same(next_empty.get("state"), state) \
			or not (next_empty.get("processed", []) as Array).is_empty(): return
	var fields := {
		"state": state, "projection": _environment.get("scenario_sequence_projection", {}),
		"layout_authority": _environment.get("scenario_layout_authority", {}),
		"layout_authority_digest": _environment.get("scenario_layout_authority_digest", ""),
		"layout_audit": _environment.get("scenario_layout_audit", {}),
		"renderer_snapshot": _environment.get("scenario_render_snapshot", {}),
	}
	var offered: Dictionary = {}
	for key in fields: offered[key] = result.get(key)
	if var_to_bytes(fields) != var_to_bytes(offered): return
	var definition_bytes := var_to_bytes(definition)
	var input_bytes := _empty_flush_inputs(_environment)
	if definition_bytes.size() + input_bytes.size() > 256 * 1024: return
	_empty_flush_definition_bytes = definition_bytes
	_empty_flush_input_bytes = input_bytes
	_empty_flush_boundary = boundary
	# Every child belongs to this immutable publication. Getters still detach it.
	_empty_flush_result = {"ok": true, "unchanged": true, "processed": [], "errors": [],
		"state": fields["state"], "projection": fields["projection"],
		"layout_authority": fields["layout_authority"], "layout_authority_digest": fields["layout_authority_digest"],
		"layout_audit": fields["layout_audit"], "renderer_snapshot": fields["renderer_snapshot"], "warnings": []}


func repeat_verified_empty_flush(environment: Dictionary, definition: Dictionary, boundary: int) -> Dictionary:
	if _empty_flush_result.is_empty() or boundary != _empty_flush_boundary \
			or var_to_bytes(definition) != _empty_flush_definition_bytes \
			or not matches_environment(environment) \
			or _empty_flush_inputs(environment) != _empty_flush_input_bytes: return {}
	return _empty_flush_result.duplicate(true)


static func _empty_flush_inputs(environment: Dictionary) -> PackedByteArray:
	var inputs := environment.duplicate(false)
	# The owned event-removal compiler changes only this physical envelope and
	# resolved journal. None is read by Runtime's empty batch or Engine's scenario
	# projection/materialization. Match EVERY other field exactly, including state,
	# causal digests, scenario geometry, baselines and materialized catalogs.
	# Full live physical/game authority also remains bound by matches_environment.
	for key in ["game_states", "layout", "object_manifest", "object_manifest_digest", "object_manifest_revision", "resolved_event_ids"]:
		inputs.erase(key)
	return var_to_bytes(inputs)


func _init(environment: Dictionary, proof: Dictionary) -> void:
	# Game modules own opaque, often large machine buffers. They are live view
	# inputs, never room geometry/semantic authority; do not include them here.
	var shell := environment.duplicate(false)
	shell.erase("game_states")
	_environment = shell.duplicate(true)
	_proof = proof.duplicate(true)
	# Opaque machine simulations do not affect geometry, but environment_hooks
	# and ticket-machine installation do. Own exactly those live validator inputs.
	var game_inputs := _game_authority_input_view(environment)
	_proof_reuse_safe = not _has_opaque_reference(_environment) and not _has_opaque_reference(game_inputs) \
			and var_to_bytes(game_inputs).size() <= MAX_AUTHORITY_GAME_INPUT_BYTES
	if _proof_reuse_safe:
		_authority_game_inputs = game_inputs.duplicate(true)
	if not environment.is_empty() and _proof_reuse_safe:
		var surface := EnvironmentPlacementScript.surface_map(environment)
		_proof_reuse_safe = not _has_opaque_reference(surface)
		_surface_input_bytes = var_to_bytes(surface)


func snapshot() -> Dictionary:
	var projection := _dict(_environment.get("scenario_sequence_projection", {}))
	return {
		"environment": _environment.duplicate(true),
		"proof": _proof.duplicate(true),
		"finalized": {
			"ok": true,
			"inactive": projection.is_empty(),
			"records": _array(_environment.get("scenario_layout_base_records", [])).duplicate(true),
			"state": _dict(_environment.get("scenario_sequence_state", {})).duplicate(true),
			"projection": projection.duplicate(true),
			"layout_authority": _dict(_environment.get("scenario_layout_authority", {})).duplicate(true),
			"layout_authority_digest": str(_environment.get("scenario_layout_authority_digest", "")),
			"layout_audit": _dict(_environment.get("scenario_layout_audit", {})).duplicate(true),
			"errors": [],
		},
	}


func matches_environment(environment: Dictionary) -> bool:
	# Used only at a causal mutation boundary, never by a catalog getter. Compare
	# against the owned publication, not a caller-provided readiness flag/digest.
	# Opaque game buffers are excluded by the same capture policy as _init().
	var shell := environment.duplicate(false)
	shell.erase("game_states")
	return _proof_reuse_safe and shell == _environment \
			and _game_authority_input_view(environment) == _authority_game_inputs


func proof_for_live_environment(environment: Dictionary) -> Dictionary:
	# No public readiness flag is sufficient. Every live authority input must
	# equal the graph accepted at publication; callers receive an owned proof.
	if not bool(_proof.get("ok", false)) or not matches_environment(environment):
		return {}
	return _proof.duplicate(true)


func advanced_turn_counter(environment: Dictionary, previous: int, next: int) -> RefCounted:
	# Called synchronously by the host immediately after its scalar clock write.
	# Turns is excluded from the manifest source, slot and scenario layout proof
	# inputs. Match EVERY other field against the owned accepted publication;
	# this cannot excuse a simultaneous mutable alias or authority change.
	if previous < 0 or next <= previous \
			or typeof(_environment.get("turns")) != TYPE_INT \
			or typeof(environment.get("turns")) != TYPE_INT \
			or _environment.get("turns") != previous or environment.get("turns") != next:
		return null
	var shell := environment.duplicate(false)
	shell.erase("game_states")
	shell["turns"] = previous
	if not _proof_reuse_safe or shell != _environment \
			or _game_authority_input_view(environment) != _authority_game_inputs:
		return null
	# These child graphs already belong to this immutable publication. A new
	# private root can share them: neither generation mutates them, and every
	# public snapshot/proof is detached. Do not recopy/rescan the accepted graph
	# merely to replace this one scalar; no live input alias enters the new root.
	var publication: RefCounted = get_script().new({}, {})
	publication._environment = _environment.duplicate(false)
	publication._environment["turns"] = next
	publication._proof = _proof
	publication._authority_game_inputs = _authority_game_inputs
	publication._proof_reuse_safe = _proof_reuse_safe
	publication._surface_input_bytes = _surface_input_bytes
	return publication


func compile_resolved_event_membership(environment: Dictionary, event_id: String, next_archetype_additions: Array = []) -> RefCounted:
	if not _proof_reuse_safe or not bool(_proof.get("ok", false)) or event_id.is_empty(): return null
	# Construct the only supported transition from PRIVATE immutable input. No
	# live child is recaptured, recursively rescanned or shared into the candidate.
	var input := _environment.duplicate(false)
	var resolved := _array(_environment.get("resolved_event_ids", [])).duplicate(true)
	if not resolved.has(event_id): resolved.append(event_id)
	input["resolved_event_ids"] = resolved
	# The event owner captured these authored additions before applying its result.
	# Reconstruct the exact same bounded append from PRIVATE prior input; never
	# accept an arbitrary replacement copied from the changed live environment.
	if not next_archetype_additions.is_empty():
		if next_archetype_additions.size() > 16 or typeof(input.get("next_archetypes", [])) != TYPE_ARRAY: return null
		var next := _array(input.get("next_archetypes", [])).duplicate(true)
		for value in next_archetype_additions:
			if typeof(value) != TYPE_STRING: return null
			var id := str(value).strip_edges()
			if not id.is_empty() and not next.has(id): next.append(id)
		input["next_archetypes"] = next
	var shell := environment.duplicate(false)
	shell.erase("game_states")
	var expected_bytes := var_to_bytes(input)
	if var_to_bytes(shell) != expected_bytes \
			or var_to_bytes(_game_authority_input_view(environment)) != var_to_bytes(_authority_game_inputs): return null
	var surface := EnvironmentPlacementScript.surface_map(environment)
	if var_to_bytes(surface) != _surface_input_bytes: return null
	var game_inputs := _authority_game_inputs
	var candidate := input.duplicate(false)
	# These are the complete game-state inputs consumed by physical compilation;
	# opaque simulations never enter this owned geometry/semantic transaction.
	var machines: Dictionary = {}
	for id in game_inputs:
		var game := _dict(game_inputs[id])
		if bool(game.get("installed", false)):
			machines[id] = {"environment_hooks": game.get("environment_hooks", []), "scalper_present": game.get("scalper_present", false)}
	candidate["game_states"] = machines
	var prior_rows := _array(_dict(input.get("object_manifest", {})).get("rows", []))
	var prior_ids: Dictionary = {}
	var resolved_ids: Dictionary = {}
	for value in prior_rows:
		var row := _dict(value)
		if not bool(row.get("active", true)) or not bool(row.get("physical", true)): continue
		var instance := str(row.get("instance_object_id", "")).strip_edges()
		var presentation := str(row.get("presentation_object_id", row.get("object_id", instance))).strip_edges()
		for id in [instance, presentation]:
			if id.is_empty(): continue
			prior_ids[id] = true
			if str(row.get("family", "")) == "event" and str(row.get("source_id", "")).strip_edges() == event_id:
				resolved_ids[id] = true
	var entries := EnvironmentInstanceScript._physical_manifest_layout_entries(candidate, surface)
	var canonical := EnvironmentObjectManifestScript.reconcile(candidate, entries, surface, _dict(candidate.get("object_manifest", {})))
	candidate["object_manifest"] = canonical
	candidate["object_manifest_digest"] = str(canonical.get("digest", ""))
	candidate["object_manifest_revision"] = maxi(0, int(canonical.get("revision", 0)))
	var live_ids: Dictionary = {}
	for value in _array(canonical.get("rows", [])):
		var row := _dict(value)
		if not bool(row.get("active", true)) or not bool(row.get("physical", true)): continue
		var instance := str(row.get("instance_object_id", "")).strip_edges()
		var presentation := str(row.get("presentation_object_id", row.get("object_id", instance))).strip_edges()
		for id in [instance, presentation]:
			if id.is_empty(): continue
			if not prior_ids.has(id): return null
			live_ids[id] = true
	var layout := _dict(candidate.get("layout", {})).duplicate(true)
	var bindings := _dict(layout.get("slot_bindings", {})).duplicate(true)
	var rects := _dict(layout.get("object_rects", {})).duplicate(true)
	var overflow := JsonCoerceScript._string_array(layout.get("slot_overflow_ids", []))
	var changed := false
	for id in resolved_ids:
		if live_ids.has(id): continue
		changed = bindings.has(id) or rects.has(id) or overflow.has(id) or changed
		bindings.erase(id)
		rects.erase(id)
		overflow.erase(id)
	if changed:
		overflow.sort()
		layout["slot_bindings"] = bindings
		layout["object_rects"] = rects
		layout["slot_overflow_ids"] = overflow
		layout["slot_binding_digest"] = EnvironmentSlotBinderScript.binding_digest(bindings)
		layout.erase("grounding_signature")
		candidate["layout"] = layout
	# Releasing geometry cannot alter canonical membership inputs. Authenticate
	# that invariant before using the locally generated canonical rows, instead
	# of constructing the same canonical manifest again in the validator.
	var released_surface := EnvironmentPlacementScript.surface_map(candidate)
	var released_entries := EnvironmentInstanceScript._physical_manifest_layout_entries(candidate, released_surface)
	if released_surface != surface or released_entries != entries: return null
	# This canonical envelope was just built from owned input, so retain its
	# schema/digest validation and the ticket-host boundary. Rebuilding it again
	# to compare each freshly generated row with itself adds no authority.
	var manifest_errors := EnvironmentObjectManifestScript.validate(canonical)
	manifest_errors.append_array(EnvironmentInstanceScript.ticket_redemption_manifest_errors(candidate))
	if not manifest_errors.is_empty() or _array(canonical.get("rows", [])).is_empty(): return null
	var proof := _authenticated_event_removal_proof(input, candidate, event_id, game_inputs, _surface_input_bytes)
	if not bool(proof.get("ok", false)): return null
	# Match the original base-plane cleanup, including its second strong proof.
	# Such rooms use the established path until that separate compiler owns it.
	for value in _array(canonical.get("rows", [])):
		var row := _dict(value)
		if str(row.get("source_kind", "")) == "scenario_projection":
			var id := str(row.get("presentation_object_id", row.get("object_id", row.get("instance_object_id", ""))))
			if _dict(_dict(candidate.get("layout", {})).get("slot_bindings", {})).has(id): return null
	candidate.erase("game_states")
	var publication: RefCounted = get_script().new({}, {})
	publication._environment = candidate
	publication._proof = proof
	publication._authority_game_inputs = game_inputs
	publication._proof_reuse_safe = true
	publication._compilation_input_bytes = expected_bytes
	publication._compilation_kind = "authenticated_event_removal"
	publication._surface_input_bytes = _surface_input_bytes
	# The compiler preserves all scenario inputs/outputs byte-exact and changes
	# only the explicitly excluded physical envelope above. Carry this private
	# verified empty-batch receipt, never a caller-provided readiness token.
	publication._empty_flush_definition_bytes = _empty_flush_definition_bytes
	publication._empty_flush_input_bytes = _empty_flush_input_bytes
	publication._empty_flush_boundary = _empty_flush_boundary
	publication._empty_flush_result = _empty_flush_result
	return publication


func _authenticated_event_removal_proof(input: Dictionary, candidate: Dictionary, event_id: String, game_inputs: Dictionary, surface_bytes: PackedByteArray) -> Dictionary:
	if not bool(_proof.get("ok", false)) or var_to_bytes(game_inputs) != var_to_bytes(_authority_game_inputs): return {}
	if surface_bytes != _surface_input_bytes: return {}
	var old_manifest := _dict(_environment.get("object_manifest", {}))
	var new_manifest := _dict(candidate.get("object_manifest", {}))
	var old_by_id: Dictionary = {}
	for value in _array(old_manifest.get("rows", [])):
		var row := _dict(value)
		old_by_id[str(row.get("instance_object_id", ""))] = row
	var base_rows: Array = []
	var scenario_rows: Array = []
	var retained_ids: Dictionary = {}
	for value in _array(new_manifest.get("rows", [])):
		var row := _dict(value)
		var id := str(row.get("instance_object_id", ""))
		if not old_by_id.has(id): return {}
		retained_ids[id] = true
		var old := _dict(old_by_id[id])
		# Canonical ordering/selection metadata may change when an event leaves;
		# each retained row must keep exactly its validated spatial identity.
		for key in ["instance_object_id", "presentation_object_id", "object_id", "source_kind", "family", "physical", "active", "placement_class", "exact_slot_id", "required", "object_type", "spot_field"]:
			if var_to_bytes(old.get(key)) != var_to_bytes(row.get(key)): return {}
		if str(row.get("source_kind", "")) == "scenario_projection": scenario_rows.append(row)
		else: base_rows.append(row)
	for id in old_by_id:
		var row := _dict(old_by_id[id])
		if retained_ids.has(id) or not bool(row.get("active", true)) or not bool(row.get("physical", true)): continue
		if str(row.get("family", "")) != "event" or str(row.get("source_id", "")).strip_edges() != event_id: return {}
	var layout := _dict(candidate.get("layout", {}))
	var base := _dict(_proof.get("layout_authority", {})).duplicate(false)
	base["slot_bindings"] = _dict(layout.get("slot_bindings", {}))
	base["object_rects"] = _dict(layout.get("object_rects", {}))
	base["overflow_ids"] = _array(layout.get("slot_overflow_ids", []))
	base["binding_digest"] = str(layout.get("slot_binding_digest", ""))
	# The owned compiler only erases resolved event bindings/rectangles. Removing
	# those occupants preserves the old slot geometry, capacities and non-overlap;
	# correlation below still checks every retained manifest row and exact host.
	var errors := _manifest_layout_correlation_errors(base_rows, _dict(base.get("slot_bindings", {})))
	errors.append_array(_manifest_layout_correlation_errors(scenario_rows, _dict(candidate.get("scenario_layout_authority", {}))))
	return {"ok":true,"layout_authority":base,"errors":[]} if errors.is_empty() else {}


func commit_compiled_event_membership(environment: Dictionary) -> bool:
	if _compilation_input_bytes.is_empty(): return false
	var shell := environment.duplicate(false)
	shell.erase("game_states")
	if var_to_bytes(shell) != _compilation_input_bytes \
			or var_to_bytes(_game_authority_input_view(environment)) != var_to_bytes(_authority_game_inputs) \
			or var_to_bytes(EnvironmentPlacementScript.surface_map(environment)) != _surface_input_bytes: return false
	for key in ["object_manifest", "object_manifest_digest", "object_manifest_revision", "layout"]:
		var value: Variant = _environment.get(key)
		if key == "layout" and var_to_bytes(value) == var_to_bytes(environment.get(key)): continue
		# Live state never receives a mutable alias to a private generation.
		environment[key] = value.duplicate(true) if typeof(value) == TYPE_DICTIONARY else value
	_compilation_input_bytes = PackedByteArray()
	return true


static func _game_authority_input_view(environment: Dictionary) -> Dictionary:
	var result := {}
	var states := _dict(environment.get("game_states", {}))
	for game_id in JsonCoerceScript._string_array(environment.get("game_ids", [])):
		var machine := _dict(states.get(game_id, {}))
		result[game_id] = {
			"installed": not machine.is_empty(),
			"environment_hooks": _array(machine.get("environment_hooks", [])),
			"scalper_present": bool(machine.get("scalper_present", false)),
		}
	return result


static func _has_opaque_reference(value: Variant, depth: int = 0) -> bool:
	# Unusually deep/cyclic runtime graphs decline reuse instead of recursively
	# extending cache admission. The original validator remains authoritative.
	if depth > 32: return true
	if typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL]: return true
	if typeof(value) == TYPE_DICTIONARY:
		for key in value:
			if _has_opaque_reference(key, depth + 1) or _has_opaque_reference(value[key], depth + 1): return true
	elif typeof(value) == TYPE_ARRAY:
		for child in value:
			if _has_opaque_reference(child, depth + 1): return true
	return false


static func validate(environment: Dictionary, require_renderer_proofs: bool = true) -> Dictionary:
	return _object_manifest_join_proof(environment, require_renderer_proofs)


static func _object_manifest_join_proof(environment: Dictionary, require_renderer_proofs: bool = true) -> Dictionary:
	var errors: Array = []
	var manifest := _dict(environment.get("object_manifest", {}))
	var manifest_rows := _array(manifest.get("rows", []))
	if manifest_rows.is_empty():
		errors.append("Object manifest is missing.")
	errors.append_array(EnvironmentInstanceScript.object_manifest_errors(environment))
	var layout_authority := EnvironmentSlotBinderScript.validate_base_layout_authority(environment)
	if not bool(layout_authority.get("ok", false)):
		errors.append_array(_array(layout_authority.get("errors", [])))
		if _array(layout_authority.get("errors", [])).is_empty():
			errors.append("Object slot authority is invalid.")
		return {"ok": false, "layout_authority": {}, "errors": errors}
	var base_rows: Array = []
	var scenario_rows: Array = []
	for row_value in manifest_rows:
		var row := _dict(row_value)
		if str(row.get("source_kind", "")) == "scenario_projection":
			scenario_rows.append(row)
		else:
			base_rows.append(row)
	errors.append_array(_manifest_layout_correlation_errors(
		base_rows,
		_dict(layout_authority.get("slot_bindings", {}))
	))
	if not scenario_rows.is_empty():
		var scenario_authority_result := _validated_manifest_scenario_authority(environment, require_renderer_proofs)
		errors.append_array(_array(scenario_authority_result.get("errors", [])))
		if bool(scenario_authority_result.get("ok", false)):
			errors.append_array(_manifest_layout_correlation_errors(
				scenario_rows,
				_dict(scenario_authority_result.get("authority", {}))
			))
	return {
		"ok": errors.is_empty(),
		"layout_authority": layout_authority if errors.is_empty() else {},
		"errors": errors,
	}


static func _validated_manifest_scenario_authority(environment: Dictionary, require_renderer_proofs: bool = true) -> Dictionary:
	var errors: Array = []
	var authority := _dict(environment.get("scenario_layout_authority", {}))
	var digest := str(environment.get("scenario_layout_authority_digest", ""))
	var audit := _dict(environment.get("scenario_layout_audit", {}))
	var snapshot := _dict(environment.get("scenario_render_snapshot", {}))
	var projection_semantic := _dict(_dict(environment.get("scenario_sequence_projection", {})).get("semantic_state", {}))
	if authority.is_empty():
		errors.append("Scenario manifest rows have no sealed scenario layout authority.")
	elif digest.length() != 64 or _layout_authority_digest(authority) != digest:
		errors.append("Scenario manifest layout authority digest is invalid.")
	if require_renderer_proofs and (not bool(audit.get("valid", false)) or str(audit.get("authority_digest", "")) != digest):
		errors.append("Scenario manifest layout audit does not match its sealed authority.")
	if require_renderer_proofs and (not bool(snapshot.get("ok", false)) or str(snapshot.get("layout_authority_digest", "")) != digest):
		errors.append("Scenario manifest renderer snapshot does not match its sealed authority.")
	if require_renderer_proofs and str(projection_semantic.get("layout_authority_digest", "")) != digest:
		errors.append("Scenario manifest semantic projection does not match its sealed authority.")
	return {
		"ok": errors.is_empty(),
		"authority": authority,
		"errors": errors,
	}


static func _manifest_layout_correlation_errors(manifest_rows: Array, bindings: Dictionary) -> Array:
	var errors: Array = []
	for row_value in manifest_rows:
		var row := _dict(row_value)
		if row.is_empty() or not bool(row.get("active", true)) or not bool(row.get("physical", true)):
			continue
		var instance_id := str(row.get("instance_object_id", "")).strip_edges()
		var presentation_id := str(row.get("presentation_object_id", row.get("object_id", instance_id))).strip_edges()
		var binding_id := presentation_id if bindings.has(presentation_id) else instance_id if bindings.has(instance_id) else ""
		var binding := _dict(bindings.get(binding_id, {}))
		if binding.is_empty():
			errors.append("Manifest object %s has no authenticated slot binding." % presentation_id)
			continue
		var family := str(row.get("family", ""))
		if str(binding.get("slot_family", "")) != family:
			errors.append("Manifest object %s crosses slot families." % presentation_id)
		# Exact exit slots describe the room-native affordance (doorway, floor mark,
		# attendant) and may intentionally refine the generic travel-row class.
		if family != "exit" and str(binding.get("placement_class", "")) != str(row.get("placement_class", "")):
			errors.append("Manifest object %s changes placement class in its slot binding." % presentation_id)
		var exact_slot_id := str(row.get("exact_slot_id", "")).strip_edges()
		if family in ["fixed", "exit"] and not exact_slot_id.is_empty() \
				and str(binding.get("slot_id", "")) != exact_slot_id:
			errors.append("Manifest object %s is not bound to its exact authored slot." % presentation_id)
	return errors


static func _layout_authority_digest(authority: Dictionary) -> String:
	var canonical: Array = []
	var identities := authority.keys()
	identities.sort()
	for identity_value in identities:
		canonical.append(_dict(authority.get(identity_value, {})))
	return JSON.stringify(canonical).sha256_text()


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
