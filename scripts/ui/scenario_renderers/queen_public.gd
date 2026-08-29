extends RefCounted

const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")

# Package E supplies only public semantic objects, actors, and interactions.
# Shared layout authority resolves them inside Delta Queen and Grand Casino.

func extension_id() -> String:
	return "queen_public"


func prepare(environment: Dictionary, projection: Dictionary) -> Dictionary:
	return ScenarioLayoutResolverScript.prepare(environment, projection)
