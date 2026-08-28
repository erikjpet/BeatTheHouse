extends RefCounted

const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")

# Motel, roadside, and beach props all resolve through the shared semantic
# layout engine.  Package B only supplies semantic objects, actors, routes, and
# interactions; it never owns pixel-canvas placement.

func extension_id() -> String:
	return "roadside_shelter"


func prepare(environment: Dictionary, projection: Dictionary) -> Dictionary:
	return ScenarioLayoutResolverScript.prepare(environment, projection)
