extends RefCounted

const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")

# Package C contributes semantic room objects, actors, routes, and interactions.
# Shared pixel placement remains exclusively in the env06_7 assembly lane.

func extension_id() -> String:
	return "bars_road"


func prepare(environment: Dictionary, projection: Dictionary) -> Dictionary:
	return ScenarioLayoutResolverScript.prepare(environment, projection)
