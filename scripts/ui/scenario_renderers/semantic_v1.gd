extends RefCounted

# Default scenario render-extension adapter. It prepares semantic-v1 projection
# data but does not draw, mutate RunState, or bypass sealed scenario authority.

const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")


func extension_id() -> String:
	return "semantic_v1"


func prepare(environment: Dictionary, projection: Dictionary) -> Dictionary:
	return ScenarioLayoutResolverScript.prepare(environment, projection)
