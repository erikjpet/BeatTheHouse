extends RefCounted

const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")


func extension_id() -> String:
	return "semantic_v1"


func prepare(environment: Dictionary, projection: Dictionary) -> Dictionary:
	return ScenarioLayoutResolverScript.prepare(environment, projection)
