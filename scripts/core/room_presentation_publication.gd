extends RefCounted

# A runtime-only, detached publication of a successfully committed room. Never
# retains a mutable input/output alias. At action boundaries its accepted proof
# can be reused only for exactly equal authority inputs; getters never validate.
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")
const MAX_AUTHORITY_GAME_INPUT_BYTES := 64 * 1024

var _environment: Dictionary
var _proof: Dictionary
var _authority_game_inputs: Dictionary = {}
var _proof_reuse_safe := false


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
	return publication


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
