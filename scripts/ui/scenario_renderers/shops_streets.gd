extends RefCounted

const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")

# Package visuals use the shared semantic resolver so object bounds, safe exits,
# target sizes, reduced-motion staging, and small-screen geometry have one
# deterministic implementation.

func extension_id() -> String:
	return "shops_streets"


func prepare(environment: Dictionary, projection: Dictionary) -> Dictionary:
	return ScenarioLayoutResolverScript.prepare(environment, projection)
