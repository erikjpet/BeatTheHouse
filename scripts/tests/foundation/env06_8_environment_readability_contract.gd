class_name Env068EnvironmentReadabilityContract
extends RefCounted

const SequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")

const EXPECTED_SCENARIOS := 55
const EXPECTED_PHASE_OBJECT_OPS := 1108
const EXPECTED_ACTIONS := 673
const GENERATED_PROSE_MARKERS := [
	"the room advances to a new physical station",
	"beat moves props and actors",
	"shared aftermath fixes a distinct",
]


static func check(library: Variant, failures: Array) -> void:
	var definitions: Array = []
	for pool_value in library.environment_scenarios.values():
		for definition_value in _array(pool_value):
			if typeof(definition_value) != TYPE_DICTIONARY: continue
			var definition := SequenceCatalogScript.apply_overlay(definition_value as Dictionary, library.scenario_sequence_catalog)
			if not _dict(definition.get("sequence", {})).is_empty(): definitions.append(definition)
	if definitions.size() != EXPECTED_SCENARIOS:
		failures.append("env06_8 expected %d scenario definitions, got %d." % [EXPECTED_SCENARIOS, definitions.size()])
		return
	var counts := {"phase_object_ops": 0, "create_records": 0, "described": 0, "zoned": 0, "actions": 0, "handlers": {}}
	var presentation_records: Array = []
	for definition_value in definitions:
		_check_definition(_dict(definition_value), counts, presentation_records, failures)
	if int(counts.get("phase_object_ops", 0)) != EXPECTED_PHASE_OBJECT_OPS:
		failures.append("env06_8 object census changed: expected %d, got %d." % [EXPECTED_PHASE_OBJECT_OPS, int(counts.get("phase_object_ops", 0))])
	if int(counts.get("actions", 0)) != EXPECTED_ACTIONS:
		failures.append("env06_8 action census changed: expected %d, got %d." % [EXPECTED_ACTIONS, int(counts.get("actions", 0))])
	if int(counts.get("create_records", 0)) != int(counts.get("described", 0)) or int(counts.get("create_records", 0)) != int(counts.get("zoned", 0)):
		failures.append("env06_8 creation surfaces are not completely described and zoned: %s" % JSON.stringify(counts))
	var handlers := _dict(counts.get("handlers", {}))
	if int(handlers.get("<none>", 0)) != 0:
		failures.append("env06_8 still has actions without handlers.")
	for handler_id in ["event_bridge", "grant_item", "grant_cash", "change_scene_object", "play_cue"]:
		if int(handlers.get(handler_id, 0)) <= 0:
			failures.append("env06_8 consequence vocabulary is not exercised by %s." % handler_id)
	_check_hidden_state_neutrality(presentation_records, failures)


static func _check_definition(definition: Dictionary, counts: Dictionary, presentation_records: Array, failures: Array) -> void:
	var sequence := _dict(definition.get("sequence", {}))
	var scenario_id := str(definition.get("id", ""))
	var creates: Dictionary = {}
	_collect_create_records(sequence, scenario_id, counts, creates, presentation_records, failures)
	for phase_value in _array(_dict(sequence.get("phase_graph", {})).get("phases", [])):
		var phase := _dict(phase_value)
		counts["phase_object_ops"] = int(counts.get("phase_object_ops", 0)) + _array(phase.get("scene_ops", [])).size() + _array(phase.get("actor_ops", [])).size()
		for operation_value in _array(phase.get("interaction_ops", [])):
			var operation := _dict(operation_value)
			for action_value in _array(_dict(operation.get("interaction", {})).get("available_actions", operation.get("available_actions", []))):
				var action := _dict(action_value)
				var handler_id := str(action.get("handler", "<none>"))
				if handler_id.is_empty(): handler_id = "<none>"
				counts["actions"] = int(counts.get("actions", 0)) + 1
				var handlers := _dict(counts.get("handlers", {}))
				handlers[handler_id] = int(handlers.get(handler_id, 0)) + 1
				counts["handlers"] = handlers
		for family in ["scene_ops", "actor_ops"]:
			for operation_value in _array(phase.get(family, [])):
				var operation := _dict(operation_value)
				if str(operation.get("op", "")) not in ["move", "set_position", "set_state", "set_appearance", "set_pose", "set_behavior"]: continue
				var variant_key := ""
				for key in ["state", "appearance", "pose", "behavior", "anchor_id", "zone_id"]:
					if not str(operation.get(key, "")).is_empty(): variant_key = str(operation.get(key, "")); break
				if variant_key.is_empty(): continue
				var covered := false
				for payload_value in _array(creates.get(str(operation.get("stable_object_id", "")), [])):
					if _dict(_dict(payload_value).get("description_variants", {})).has(variant_key): covered = true
				if not covered:
					failures.append("env06_8 %s/%s lacks description variant %s." % [scenario_id, str(operation.get("stable_object_id", "")), variant_key])
	_check_generated_prose(sequence, scenario_id, failures)


static func _collect_create_records(value: Variant, scenario_id: String, counts: Dictionary, creates: Dictionary, presentation_records: Array, failures: Array) -> void:
	if typeof(value) == TYPE_ARRAY:
		for child in value: _collect_create_records(child, scenario_id, counts, creates, presentation_records, failures)
		return
	if typeof(value) != TYPE_DICTIONARY: return
	var row := value as Dictionary
	var family := str(row.get("family", ""))
	var payload := _dict(row.get("object", row.get("actor", {})))
	if family in ["scene_ops", "actor_ops"] and not payload.is_empty():
		counts["create_records"] = int(counts.get("create_records", 0)) + 1
		counts["described"] = int(counts.get("described", 0)) + int(not str(payload.get("description", "")).strip_edges().is_empty())
		counts["zoned"] = int(counts.get("zoned", 0)) + int(not str(payload.get("zone_id", "")).strip_edges().is_empty())
		var stable_id := str(row.get("stable_object_id", ""))
		var payloads := _array(creates.get(stable_id, [])); payloads.append(payload); creates[stable_id] = payloads
		presentation_records.append({"scenario_id": scenario_id, "family": family, "stable_object_id": stable_id, "payload": payload})
	for child in row.values(): _collect_create_records(child, scenario_id, counts, creates, presentation_records, failures)


static func _check_hidden_state_neutrality(records: Array, failures: Array) -> void:
	for record_value in records:
		var record := _dict(record_value)
		var semantic := _dict(record.get("payload", {})).duplicate(true)
		semantic["owner_namespace"] = "scenario"
		semantic["stable_object_id"] = str(record.get("stable_object_id", ""))
		semantic["semantic_kind"] = "actor" if str(record.get("family", "")) == "actor_ops" else "scene_object"
		var hidden := semantic.duplicate(true)
		hidden["turned_member_id"] = "hidden_traitor"
		hidden["grievance_weight"] = 999
		hidden["rigged_numbers_draw"] = true
		hidden["unrevealed_ticket_contents"] = "winner"
		var authority := {"presentation_object_id": "scenario::%s" % str(record.get("stable_object_id", "")), "normalized_hit_rect": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.1}, "small_screen_rect": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.1}}
		var clean := EnvironmentInteractionControllerScript._merge_projected_actor({}, semantic, authority, "digest") if str(record.get("family", "")) == "actor_ops" else EnvironmentInteractionControllerScript._merge_projected_scene_object({}, semantic, authority, "digest")
		var tainted := EnvironmentInteractionControllerScript._merge_projected_actor({}, hidden, authority, "digest") if str(record.get("family", "")) == "actor_ops" else EnvironmentInteractionControllerScript._merge_projected_scene_object({}, hidden, authority, "digest")
		for key in ["label", "short_description", "icon_key", "state_label"]:
			if clean.get(key) != tainted.get(key): failures.append("env06_8 hidden state changed %s for %s." % [key, str(record.get("stable_object_id", ""))])
		if str(clean.get("label", "")).is_empty() or str(clean.get("short_description", "")).is_empty() or str(clean.get("icon_key", "")).is_empty() or not bool(clean.get("interactive", false)):
			failures.append("env06_8 projected object %s lacks complete inspectable presentation." % str(record.get("stable_object_id", "")))


static func _check_generated_prose(value: Variant, scenario_id: String, failures: Array) -> void:
	if typeof(value) == TYPE_STRING:
		var text := str(value).to_lower()
		for marker in GENERATED_PROSE_MARKERS:
			if text.contains(marker): failures.append("env06_8 %s retains generated prose marker %s." % [scenario_id, marker])
	elif typeof(value) == TYPE_ARRAY:
		for child in value: _check_generated_prose(child, scenario_id, failures)
	elif typeof(value) == TYPE_DICTIONARY:
		for child in (value as Dictionary).values(): _check_generated_prose(child, scenario_id, failures)


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
