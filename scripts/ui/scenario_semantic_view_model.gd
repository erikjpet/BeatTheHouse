class_name ScenarioSemanticViewModel
extends RefCounted

const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")


static func prepare_projection(base_records: Array, projection: Dictionary, environment: Dictionary = {}) -> Dictionary:
	return ScenarioLayoutResolverScript.resolve(base_records, projection, environment)


static func failure_authority(base_records: Array = []) -> Dictionary:
	return ScenarioLayoutResolverScript.failure_authority(base_records)


static func actor_character_model(actor: Dictionary) -> Dictionary:
	var behavior := str(actor.get("behavior", "idle"))
	var pose := str(actor.get("pose", "")).strip_edges()
	if pose.is_empty():
		pose = {
			"watch": "watching",
			"guard": "watching",
			"fight": "ready",
			"work": "working",
			"flee": "moving",
			"depart": "moving",
		}.get(behavior, "idle")
	return {
		"presentation": str(actor.get("presentation", "")),
		"role": behavior,
		"pose": pose,
		"behavior": behavior,
		"route_id": str(actor.get("route_id", "")),
		"route_points": _array(actor.get("route_points", [])),
		"route_stage": _dict(actor.get("route_stage", {})),
		"portrait_count": 1,
		"members": [{
			"role": behavior,
			"pose": pose,
			"model": _dict(actor.get("model", {})),
		}],
	}


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
