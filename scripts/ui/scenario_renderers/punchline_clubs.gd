extends RefCounted

const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")

# Package D supplies semantic Punchline and Kitty objects, actors, routes, and
# interactions. Shared layout authority resolves the existing named anchors.

func extension_id() -> String:
	return "punchline_clubs"


func prepare(environment: Dictionary, projection: Dictionary) -> Dictionary:
	return ScenarioLayoutResolverScript.prepare(environment, projection)
