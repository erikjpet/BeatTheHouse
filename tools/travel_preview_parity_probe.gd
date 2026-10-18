extends SceneTree

# Verifies that the lightweight scout projection remains byte-identical to the
# player-visible fields produced by full environment generation, and that the
# direct late-run preview candidate matches the former persistence round-trip.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const MainScene := preload("res://scenes/main.tscn")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const FIXTURE_SLOT := "pathological_continue_save_probe_copy"

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
	var late_run_targets := await _check_late_run_candidate(failures)
	print("TRAVEL_PREVIEW_PARITY checked=%d late_run_targets=%d failures=%d" % [checked, late_run_targets, failures.size()])
	print("TRAVEL_PREVIEW_LAYERED checked=%d full_total_ms=%.3f preview_total_ms=%.3f" % [layered_checked, float(layered_full_usec) / 1000.0, float(layered_preview_usec) / 1000.0])
	for failure in failures:
		push_error(str(failure))
	quit(1 if not failures.is_empty() else 0)


func _check_late_run_candidate(failures: Array) -> int:
	var host = MainScene.instantiate()
	host.autosave_slot_id = FIXTURE_SLOT
	host.dev_game_test_mode = true
	root.add_child(host)
	await process_frame
	host.load_foundation_run()
	if host.run_state == null:
		failures.append("Pathological late-run preview fixture did not load.")
		host.queue_free()
		return 0
	var before := JSON.stringify(host.run_state.to_save_snapshot())
	var targets: Array = host._travel_target_ids()
	for target_value in targets:
		var target_id := str(target_value)
		var optimized: Dictionary = host.generator.preview_environment(host.run_state, target_id, true)
		var expected: Dictionary = host.generator._stored_world_environment_preview(host.run_state, target_id)
		if expected.is_empty():
			var legacy := RunStateScript.new()
			legacy.from_dict(host.run_state.to_travel_preview_snapshot())
			legacy.configure_town_world(legacy.world_map)
			var legacy_environment: Dictionary = host.generator._preview_world_environment_data(legacy, target_id, true)
			expected = host.generator._travel_preview_environment_projection(legacy_environment)
		if JSON.stringify(optimized) != JSON.stringify(expected):
			failures.append("Late-run preview mismatch for %s: optimized=%s expected=%s" % [target_id, JSON.stringify(optimized), JSON.stringify(expected)])
	var after := JSON.stringify(host.run_state.to_save_snapshot())
	if before != after:
		failures.append("Optimized late-run previews mutated the live run.")
	host.queue_free()
	return targets.size()
