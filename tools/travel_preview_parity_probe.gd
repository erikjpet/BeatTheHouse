extends SceneTree

# Verifies that the lightweight scout projection remains byte-identical to the
# player-visible fields produced by full environment generation.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const PROJECTION_FIELDS := [
	"tier", "kind", "game_ids", "service_ids", "lender_hooks",
	"item_offers", "travel_locked_actions",
]


func _init() -> void:
	call_deferred("_run")


func _projection(environment: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field_name in PROJECTION_FIELDS:
		if environment.has(field_name):
			result[field_name] = environment.get(field_name)
	return result


func _run() -> void:
	var failures: Array = []
	var checked := 0
	var layered_checked := 0
	var layered_full_usec := 0
	var layered_preview_usec := 0
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	for error_value in library.validation_errors:
		failures.append("Content validation error: %s" % str(error_value))
	var challenge := RunStateScript.standard_challenge("TRAVEL-PREVIEW-PARITY")
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var archetype_id := str(archetype.get("id", "")).strip_edges()
		if archetype_id.is_empty():
			continue
		var scenarios: Array = [{}]
		var scenario_pool: Array = library._scenarios_for_archetype_readonly(archetype_id)
		for scenario_value in scenario_pool:
			if typeof(scenario_value) == TYPE_DICTIONARY:
				scenarios.append(library._runtime_scenario_definition_unvalidated(scenario_value as Dictionary))
		for scenario_value in scenarios:
			var scenario: Dictionary = scenario_value
			var seed := RngStreamScript.derive_seed(77123, checked + 1, "%s:%s" % [archetype_id, str(scenario.get("id", "base"))])
			var full_rng: RngStream = RngStreamScript.new()
			full_rng.configure(seed)
			var preview_rng: RngStream = RngStreamScript.new()
			preview_rng.configure(seed)
			var full_started_usec := Time.get_ticks_usec()
			var full := EnvironmentInstanceScript.from_archetype(archetype, 7, full_rng, library, challenge, scenario).to_dict()
			var full_elapsed_usec := Time.get_ticks_usec() - full_started_usec
			var preview_started_usec := Time.get_ticks_usec()
			var preview := EnvironmentInstanceScript.travel_preview_from_archetype(archetype, 7, preview_rng, library, challenge, scenario)
			var preview_elapsed_usec := Time.get_ticks_usec() - preview_started_usec
			if typeof(archetype.get("layers", {})) == TYPE_DICTIONARY and not (archetype.get("layers", {}) as Dictionary).is_empty():
				layered_checked += 1
				layered_full_usec += full_elapsed_usec
				layered_preview_usec += preview_elapsed_usec
			checked += 1
			var full_projection := _projection(full)
			var preview_projection := _projection(preview)
			if JSON.stringify(full_projection) != JSON.stringify(preview_projection):
				failures.append("%s scenario %s scout projection differs from full generation: full=%s preview=%s" % [archetype_id, str(scenario.get("id", "base")), JSON.stringify(full_projection), JSON.stringify(preview_projection)])
	print("TRAVEL_PREVIEW_PARITY checked=%d failures=%d" % [checked, failures.size()])
	print("TRAVEL_PREVIEW_LAYERED checked=%d full_total_ms=%.3f preview_total_ms=%.3f" % [layered_checked, float(layered_full_usec) / 1000.0, float(layered_preview_usec) / 1000.0])
	for failure in failures:
		push_error(str(failure))
	quit(1 if not failures.is_empty() else 0)
