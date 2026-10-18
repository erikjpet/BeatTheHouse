extends SceneTree

# Long-session stability probe for the 0.3.1 hardening board.
# It accelerates three simulated hours of play and asserts post-warmup memory,
# object, node, serialized RunState, and pinball session-cache growth stays bounded.

const MainScene := preload("res://scenes/main.tscn")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const PinballFeatureScript := preload("res://scripts/games/slots/pinball/pinball_feature.gd")

const REPORT_PATH := "user://foundation_soak_probe_report.json"
const SAMPLE_LOG_PATH := "user://foundation_soak_probe_samples.jsonl"
const DEFAULT_SEED_PREFIX := "FOUNDATION-SOAK"
const DEFAULT_SIM_MINUTES := 180
const DEFAULT_ACTIONS_PER_SAMPLE := 28
const SAMPLE_INTERVAL_MINUTES := 10
const WARMUP_SAMPLE_COUNT := 3
const RETAINED_SLOPE_TAIL_SAMPLE_COUNT := 6
const RETAINED_VALUE_TAIL_SAMPLE_COUNT := 3
const RETAINED_MEASUREMENT_SETTLE_FRAMES := 28
const SAVE_LOAD_ACTION_INTERVAL := 23
const RUN_ROTATION_ACTION_INTERVAL := 160
const SLOT_AUTOPLAY_ACTION_INTERVAL := 97
const SLOT_AUTOPLAY_FRAMES := 150
const SLOT_AUTOPLAY_PREWARM_BLOCKS := 3
const PINBALL_CACHE_STRESS_SESSIONS := 40
const SOAK_SAVE_SLOT := "foundation_soak_probe"
const RETAINED_MEASUREMENT_SEED := "FOUNDATION-SOAK-RETAINED-MEASUREMENT"
const SOAK_PREWARM_GAME_IDS := ["blackjack", "baccarat", "roulette", "craps", "video_poker", "bar_dice", "pull_tabs", "slot"]
const FEATURE_PCM_BOUNDARY_COUNT := 3
const FEATURE_PCM_REQUESTS_PER_BOUNDARY := 32
const FEATURE_PCM_MIN_DISTINCT_CONTEXTS := 25
const FEATURE_PCM_EXPECTED_BUDGET_BYTES := 64 * 1024 * 1024

const MAX_SERIALIZED_RUN_STATE_BYTES := 1500000
const MAX_POST_WARMUP_MEMORY_PEAK_GROWTH_BYTES := 32 * 1024 * 1024
const MAX_POST_WARMUP_MEMORY_RETAINED_GROWTH_BYTES := 4 * 1024 * 1024
const MAX_POST_WARMUP_MEMORY_RETAINED_SLOPE_BYTES_PER_SAMPLE := 256 * 1024
const MAX_POST_WARMUP_RESOURCE_PEAK_GROWTH := 12
const MAX_POST_WARMUP_RESOURCE_RETAINED_GROWTH := 8
const MAX_POST_WARMUP_RESOURCE_RETAINED_SLOPE_PER_SAMPLE := 0.5
const MAX_POST_WARMUP_OBJECT_PEAK_GROWTH := 96
const MAX_POST_WARMUP_OBJECT_RETAINED_GROWTH := 32
const MAX_POST_WARMUP_OBJECT_RETAINED_SLOPE_PER_SAMPLE := 2.0
const MAX_POST_WARMUP_NODE_PEAK_GROWTH := 12
const MAX_POST_WARMUP_NODE_RETAINED_GROWTH := 8
const MAX_POST_WARMUP_NODE_RETAINED_SLOPE_PER_SAMPLE := 0.5
const MAX_POST_WARMUP_ORPHAN_NODE_COUNT := 0

var app: Control
var failures: Array = []
var warnings: Array = []
var samples: Array = []
var retained_samples: Array = []
var coverage: Dictionary = {}
var run_index := 0
var action_counter := 0
var seed_prefix := DEFAULT_SEED_PREFIX
var sim_minutes := DEFAULT_SIM_MINUTES
var actions_per_sample := DEFAULT_ACTIONS_PER_SAMPLE
var sample_log_file: FileAccess
var feature_pcm_evidence: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	seed_prefix = OS.get_environment("BTH_SOAK_SEED_PREFIX")
	if seed_prefix.strip_edges().is_empty():
		seed_prefix = DEFAULT_SEED_PREFIX
	sim_minutes = _configured_int("BTH_SOAK_MINUTES", DEFAULT_SIM_MINUTES)
	actions_per_sample = _configured_int("BTH_SOAK_ACTIONS_PER_SAMPLE", DEFAULT_ACTIONS_PER_SAMPLE)
	feature_pcm_evidence = _new_feature_pcm_evidence()
	PinballFeatureScript.clear_runtime_session_cache()
	sample_log_file = FileAccess.open(SAMPLE_LOG_PATH, FileAccess.WRITE)
	if sample_log_file == null:
		failures.append("Could not open soak sample spool at %s." % SAMPLE_LOG_PATH)
	coverage = {
		"runs_started": 0,
		"save_loads": 0,
		"world_travels": 0,
		"revisits": 0,
		"game_actions": 0,
		"slot_autoplay_blocks": 0,
		"pinball_cache_stress_blocks": 0,
		"event_actions": 0,
		"item_actions": 0,
		"service_actions": 0,
		"lender_actions": 0,
	}
	await _open_fresh_app()
	await _prewarm_runtime_caches()
	await _exercise_feature_pcm_boundaries()
	# The first scheduled autoplay block is action 97, after the action-84
	# retained-growth warmup boundary. Repeated sessions reach their resource
	# high-water on the second block, so cover session creation, replacement,
	# and steady reuse before sampling. Scheduled workload blocks still run.
	for _prewarm_index in range(SLOT_AUTOPLAY_PREWARM_BLOCKS):
		await _exercise_slot_autoplay_block()
	var sample_count := maxi(1, int(ceil(float(sim_minutes) / float(SAMPLE_INTERVAL_MINUTES))))
	var workload_prewarm_actions := sample_count * actions_per_sample
	var measured_start_run_index := run_index
	for _prewarm_action_index in range(workload_prewarm_actions):
		await _drive_action()
	var workload_prewarm_coverage := coverage.duplicate(true)
	var slot_background_textures_prewarmed := int(coverage.get("slot_background_textures_prewarmed", 0))
	var slot_background_texture_cache_cap := int(coverage.get("slot_background_texture_cache_cap", 0))
	coverage = {
		"runs_started": 0,
		"save_loads": 0,
		"world_travels": 0,
		"revisits": 0,
		"game_actions": 0,
		"slot_autoplay_blocks": 0,
		"pinball_cache_stress_blocks": 0,
		"event_actions": 0,
		"item_actions": 0,
		"service_actions": 0,
		"lender_actions": 0,
		"retained_measurement_resets": 0,
		"slot_background_textures_prewarmed": slot_background_textures_prewarmed,
		"slot_background_texture_cache_cap": slot_background_texture_cache_cap,
		"workload_prewarm_actions": workload_prewarm_actions,
		"workload_prewarm_coverage": workload_prewarm_coverage,
	}
	action_counter = 0
	run_index = measured_start_run_index
	await _sample(0)
	await _sample_retained_state(0)
	for sample_index in range(1, sample_count + 1):
		for _action_index in range(actions_per_sample):
			await _drive_action()
		await _sample(sample_index)
		await _sample_retained_state(sample_index)
	_hydrate_metric_samples_from_spool()
	_assert_coverage()
	_assert_growth()
	_write_report()
	_print_summary()
	await _cleanup_app()
	if not failures.is_empty():
		for failure in failures:
			push_error(str(failure))
		quit(1)
		return
	quit(0)


func _open_fresh_app() -> void:
	app = MainScene.instantiate() as Control
	if app == null:
		failures.append("Could not instantiate main scene.")
		return
	get_root().add_child(app)
	await _settle(3)
	if not app.has_method("uses_foundation_runtime") or not bool(app.call("uses_foundation_runtime")):
		failures.append("Main scene did not initialize the foundation runtime.")
	app.set("autosave_slot_id", SOAK_SAVE_SLOT)


func _start_next_run() -> void:
	run_index += 1
	var seed := "%s-%03d" % [seed_prefix, run_index]
	var challenge: Dictionary = RunStateScript.custom_challenge("soak", seed, {
		"starting_bankroll": 5000,
		"hidden_seed": true,
	})
	app.set("autosave_slot_id", SOAK_SAVE_SLOT)
	app.call("start_foundation_run", seed, challenge)
	coverage["runs_started"] = int(coverage.get("runs_started", 0)) + 1
	await _settle(4)


func _prewarm_runtime_caches() -> void:
	for game_id_value in SOAK_PREWARM_GAME_IDS:
		var game_id := str(game_id_value)
		app.call("start_game_test_session", game_id)
		await _settle(3)
		if game_id == "slot":
			var slot_module: Variant = app.get("current_game")
			if slot_module != null and slot_module.has_method("prewarm_surface_assets"):
				coverage["slot_background_textures_prewarmed"] = int(slot_module.call("prewarm_surface_assets"))
				var cache_debug: Dictionary = slot_module.call("debug_surface_asset_cache_snapshot")
				coverage["slot_background_texture_cache_cap"] = int(cache_debug.get("background_texture_cache_cap", 0))
	app.call("return_to_main_menu")
	await _settle(4)


func _new_feature_pcm_evidence() -> Dictionary:
	return {
		"schema": "beat_the_house.foundation_feature_pcm_soak/v1",
		"passed": false,
		"seed_prefix": seed_prefix,
		"boundary_count": 0,
		"requests_per_boundary": FEATURE_PCM_REQUESTS_PER_BOUNDARY,
		"request_count": 0,
		"distinct_context_count": 0,
		"successful_load_count": 0,
		"successful_play_count": 0,
		"physical_cache_keys": [],
		"cache_budget_bytes": FEATURE_PCM_EXPECTED_BUDGET_BYTES,
		"maximum_populated_bytes": 0,
		"maximum_combined_bytes": 0,
		"cleanup_to_baseline_count": 0,
		"cleanup_evicted_key_count": 0,
		"baseline": {},
		"boundaries": [],
	}


func _exercise_feature_pcm_boundaries() -> void:
	var failure_count_before := failures.size()
	if app == null:
		failures.append("Feature PCM soak could not run without the foundation app.")
		return
	var player: Variant = app.get("procedural_music_player")
	if player == null \
			or not player.has_method("_feature_stem_set_for_input") \
			or not player.has_method("_play_feature_stem_set") \
			or not player.has_method("pcm_cache_policy_snapshot"):
		failures.append("Feature PCM soak could not reach the production music load/play/accounting path.")
		return
	player.call("stop")
	player.call("clear_run_scoped_caches")
	player.call("_ensure_feature_stem_players")
	await _settle(2)
	var baseline_debug: Dictionary = player.call("debug_soak_snapshot")
	var baseline_policy: Dictionary = player.call("pcm_cache_policy_snapshot")
	var baseline := _feature_pcm_accounting(baseline_policy)
	baseline["cache_bytes"] = int(baseline_policy.get("bytes", -1))
	baseline["cache_raw_bytes"] = int(baseline_policy.get("raw_bytes", -1))
	baseline["cache_encoded_bytes"] = int(baseline_policy.get("encoded_bytes", -1))
	baseline["web_decoded_bytes"] = int(baseline_policy.get("web_decoded_bytes", -1))
	baseline["combined_bytes"] = int(baseline_policy.get("combined_bytes", -1))
	baseline["debug_feature_entry_count"] = int(baseline_debug.get("feature_stem_cache_size", -1))
	if int(baseline.get("feature_entry_count", -1)) != 0 \
			or int(baseline.get("feature_bytes", -1)) != 0 \
			or int(baseline.get("debug_feature_entry_count", -1)) != 0 \
			or not _feature_pcm_policy_within_budget(baseline_policy):
		failures.append("Feature PCM soak could not establish an empty, within-budget production baseline.")

	var all_contexts: Dictionary = {}
	var all_physical_keys: Dictionary = {}
	var boundaries: Array = []
	var successful_load_count := 0
	var successful_play_count := 0
	var cleanup_to_baseline_count := 0
	var cleanup_evicted_key_count := 0
	var maximum_populated_bytes := 0
	var maximum_combined_bytes := 0
	for boundary_index in range(FEATURE_PCM_BOUNDARY_COUNT):
		var boundary_contexts: Dictionary = {}
		var boundary_physical_keys: Dictionary = {}
		var boundary_load_count := 0
		var boundary_play_count := 0
		var boundary_policy_ok := true
		for request_index in range(FEATURE_PCM_REQUESTS_PER_BOUNDARY):
			var cue_id := "buffalo_feature_foundation_%02d_%02d" % [boundary_index, request_index] \
				if request_index % 2 == 0 else "pinball_feature_foundation_%02d_%02d" % [boundary_index, request_index]
			var palette_id := "foundation_feature_%s_%02d_%02d" % [seed_prefix, boundary_index, request_index]
			var bpm := 70.0 + float(request_index)
			var context_key := "%s|%s|%0.2f" % [cue_id, palette_id, bpm]
			boundary_contexts[context_key] = true
			all_contexts[context_key] = true
			player.set("_current_stem_set", {
				"bpm": bpm,
				"profile": {
					"palette_id": palette_id,
					"theme": "slot",
					"root_midi": 45 + request_index % 8,
				},
			})
			var feature_set: Dictionary = player.call("_feature_stem_set_for_input", {"cue_id": cue_id})
			var physical_key := str(feature_set.get("pcm_cache_key", ""))
			if not physical_key.is_empty():
				boundary_physical_keys[physical_key] = true
				all_physical_keys[physical_key] = true
			var request_policy: Dictionary = player.call("pcm_cache_policy_snapshot")
			var request_entry_bytes := _dict(request_policy.get("entry_bytes", {}))
			if not feature_set.is_empty() and not physical_key.is_empty() and int(request_entry_bytes.get(physical_key, 0)) > 0:
				boundary_load_count += 1
				successful_load_count += 1
			if bool(player.call("_play_feature_stem_set", feature_set, 0.0)):
				boundary_play_count += 1
				successful_play_count += 1
			boundary_policy_ok = boundary_policy_ok and _feature_pcm_policy_within_budget(request_policy)
			await process_frame

		var populated_debug: Dictionary = player.call("debug_soak_snapshot")
		var populated_policy: Dictionary = player.call("pcm_cache_policy_snapshot")
		var populated_feature := _feature_pcm_accounting(populated_policy)
		maximum_populated_bytes = maxi(maximum_populated_bytes, int(populated_policy.get("bytes", -1)))
		maximum_combined_bytes = maxi(maximum_combined_bytes, int(populated_policy.get("combined_bytes", -1)))
		var populated_ok := boundary_contexts.size() >= FEATURE_PCM_MIN_DISTINCT_CONTEXTS \
			and boundary_contexts.size() == FEATURE_PCM_REQUESTS_PER_BOUNDARY \
			and boundary_load_count == FEATURE_PCM_REQUESTS_PER_BOUNDARY \
			and boundary_play_count == FEATURE_PCM_REQUESTS_PER_BOUNDARY \
			and boundary_physical_keys.size() == 2 \
			and int(populated_debug.get("feature_stem_cache_size", -1)) == 2 \
			and int(populated_feature.get("feature_entry_count", -1)) == 2 \
			and int(populated_feature.get("feature_bytes", -1)) > 0 \
			and int(populated_feature.get("feature_raw_bytes", -1)) > 0 \
			and int(populated_feature.get("feature_bytes", -1)) == int(populated_feature.get("feature_raw_bytes", -1)) + int(populated_feature.get("feature_encoded_bytes", -1)) \
			and boundary_policy_ok \
			and _feature_pcm_policy_within_budget(populated_policy)

		var boundary_seed := "%s-FEATURE-PCM-%02d" % [seed_prefix, boundary_index]
		var boundary_challenge := RunStateScript.custom_challenge("soak_feature_pcm", boundary_seed, {
			"starting_bankroll": 5000,
			"hidden_seed": true,
		})
		var boundary_started := bool(app.call("start_foundation_run", boundary_seed, boundary_challenge))
		await _settle(4)
		var cleared_debug: Dictionary = player.call("debug_soak_snapshot")
		var cleared_policy: Dictionary = player.call("pcm_cache_policy_snapshot")
		var physical_keys: Array = boundary_physical_keys.keys()
		physical_keys.sort()
		var cleanup_ok := boundary_started and _feature_pcm_cleanup_matches_baseline(
			cleared_debug,
			cleared_policy,
			baseline,
			physical_keys
		)
		var cleared_entry_bytes := _dict(cleared_policy.get("entry_bytes", {}))
		var cleared_keys := _array(cleared_policy.get("keys", []))
		var evicted_key_count := 0
		for physical_key_value in physical_keys:
			var cleared_physical_key := str(physical_key_value)
			if not cleared_entry_bytes.has(cleared_physical_key) and not cleared_keys.has(cleared_physical_key):
				evicted_key_count += 1
		cleanup_evicted_key_count += evicted_key_count
		if cleanup_ok:
			cleanup_to_baseline_count += 1
		var boundary_passed := populated_ok and cleanup_ok and evicted_key_count == physical_keys.size()
		if not populated_ok:
			failures.append("Feature PCM boundary %d did not complete 32 distinct production load/play requests within the shared 64 MiB budget." % boundary_index)
		if not boundary_started:
			failures.append("Feature PCM boundary %d could not start its production run-boundary transition." % boundary_index)
		elif not cleanup_ok or evicted_key_count != physical_keys.size():
			failures.append("Feature PCM boundary %d did not evict its feature packs and return shared accounting to baseline." % boundary_index)
		boundaries.append({
			"index": boundary_index,
			"passed": boundary_passed,
			"request_count": FEATURE_PCM_REQUESTS_PER_BOUNDARY,
			"distinct_context_count": boundary_contexts.size(),
			"successful_load_count": boundary_load_count,
			"successful_play_count": boundary_play_count,
			"physical_cache_keys": physical_keys,
			"populated_feature": populated_feature,
			"populated_cache_bytes": int(populated_policy.get("bytes", -1)),
			"populated_combined_bytes": int(populated_policy.get("combined_bytes", -1)),
			"cleanup_to_baseline": cleanup_ok,
			"cleanup_evicted_key_count": evicted_key_count,
			"cleared_feature": _feature_pcm_accounting(cleared_policy),
			"cleared_cache_bytes": int(cleared_policy.get("bytes", -1)),
			"cleared_combined_bytes": int(cleared_policy.get("combined_bytes", -1)),
		})
		app.call("return_to_main_menu")
		await _settle(4)

	var physical_cache_keys: Array = all_physical_keys.keys()
	physical_cache_keys.sort()
	var expected_request_count := FEATURE_PCM_BOUNDARY_COUNT * FEATURE_PCM_REQUESTS_PER_BOUNDARY
	var aggregate_ok := boundaries.size() == FEATURE_PCM_BOUNDARY_COUNT \
		and all_contexts.size() == expected_request_count \
		and successful_load_count == expected_request_count \
		and successful_play_count == expected_request_count \
		and physical_cache_keys.size() == 2 \
		and cleanup_to_baseline_count == FEATURE_PCM_BOUNDARY_COUNT \
		and cleanup_evicted_key_count == FEATURE_PCM_BOUNDARY_COUNT * physical_cache_keys.size()
	if not aggregate_ok:
		failures.append("Feature PCM soak aggregate did not complete all contextual requests, production handoffs, or run-boundary cleanups.")
	feature_pcm_evidence = {
		"schema": "beat_the_house.foundation_feature_pcm_soak/v1",
		"passed": aggregate_ok and failures.size() == failure_count_before,
		"seed_prefix": seed_prefix,
		"boundary_count": boundaries.size(),
		"requests_per_boundary": FEATURE_PCM_REQUESTS_PER_BOUNDARY,
		"request_count": expected_request_count,
		"distinct_context_count": all_contexts.size(),
		"successful_load_count": successful_load_count,
		"successful_play_count": successful_play_count,
		"physical_cache_keys": physical_cache_keys,
		"cache_budget_bytes": FEATURE_PCM_EXPECTED_BUDGET_BYTES,
		"maximum_populated_bytes": maximum_populated_bytes,
		"maximum_combined_bytes": maximum_combined_bytes,
		"cleanup_to_baseline_count": cleanup_to_baseline_count,
		"cleanup_evicted_key_count": cleanup_evicted_key_count,
		"baseline": baseline,
		"boundaries": boundaries,
	}
	player.call("stop")
	player.call("clear_run_scoped_caches")
	app.call("return_to_main_menu")
	await _settle(4)


func _feature_pcm_policy_within_budget(policy: Dictionary) -> bool:
	var budget_bytes := int(policy.get("budget_bytes", -1))
	var raw_bytes := int(policy.get("raw_bytes", -1))
	var encoded_bytes := int(policy.get("encoded_bytes", -1))
	var cache_bytes := int(policy.get("bytes", -1))
	var web_decoded_bytes := int(policy.get("web_decoded_bytes", -1))
	var combined_bytes := int(policy.get("combined_bytes", -1))
	var combined_budget_bytes := int(policy.get("combined_budget_bytes", -1))
	return budget_bytes == FEATURE_PCM_EXPECTED_BUDGET_BYTES \
		and combined_budget_bytes == FEATURE_PCM_EXPECTED_BUDGET_BYTES \
		and cache_bytes >= 0 \
		and raw_bytes >= 0 \
		and encoded_bytes >= 0 \
		and web_decoded_bytes >= 0 \
		and cache_bytes == raw_bytes + encoded_bytes \
		and combined_bytes == cache_bytes + web_decoded_bytes \
		and cache_bytes <= budget_bytes \
		and combined_bytes <= combined_budget_bytes \
		and bool(policy.get("combined_within_budget", false))


func _feature_pcm_accounting(policy: Dictionary) -> Dictionary:
	var entry_bytes := _dict(policy.get("entry_bytes", {}))
	var entry_raw_bytes := _dict(policy.get("entry_raw_bytes", {}))
	var entry_encoded_bytes := _dict(policy.get("entry_encoded_bytes", {}))
	var feature_keys: Array = []
	var feature_bytes := 0
	var feature_raw_bytes := 0
	var feature_encoded_bytes := 0
	for key_value in entry_bytes.keys():
		var key := str(key_value)
		if not key.begins_with("feature_"):
			continue
		feature_keys.append(key)
		feature_bytes += int(entry_bytes.get(key_value, 0))
		feature_raw_bytes += int(entry_raw_bytes.get(key_value, 0))
		feature_encoded_bytes += int(entry_encoded_bytes.get(key_value, 0))
	feature_keys.sort()
	return {
		"feature_entry_count": feature_keys.size(),
		"feature_bytes": feature_bytes,
		"feature_raw_bytes": feature_raw_bytes,
		"feature_encoded_bytes": feature_encoded_bytes,
		"feature_keys": feature_keys,
	}


func _feature_pcm_cleanup_matches_baseline(debug_snapshot: Dictionary, policy: Dictionary, baseline: Dictionary, physical_keys: Array) -> bool:
	var feature := _feature_pcm_accounting(policy)
	var feature_entry_count := int(feature.get("feature_entry_count", -1))
	var feature_bytes := int(feature.get("feature_bytes", -1))
	var entry_bytes := _dict(policy.get("entry_bytes", {}))
	var policy_keys := _array(policy.get("keys", []))
	for physical_key_value in physical_keys:
		var physical_key := str(physical_key_value)
		if entry_bytes.has(physical_key) or policy_keys.has(physical_key):
			return false
	return feature_entry_count == int(baseline.get("feature_entry_count", -1)) \
		and feature_bytes == int(baseline.get("feature_bytes", -1)) \
		and int(debug_snapshot.get("feature_stem_cache_size", -1)) == int(baseline.get("debug_feature_entry_count", -1)) \
		and int(policy.get("bytes", -1)) == int(baseline.get("cache_bytes", -1)) \
		and int(policy.get("raw_bytes", -1)) == int(baseline.get("cache_raw_bytes", -1)) \
		and int(policy.get("encoded_bytes", -1)) == int(baseline.get("cache_encoded_bytes", -1)) \
		and int(policy.get("web_decoded_bytes", -1)) == int(baseline.get("web_decoded_bytes", -1)) \
		and int(policy.get("combined_bytes", -1)) == int(baseline.get("combined_bytes", -1)) \
		and _feature_pcm_policy_within_budget(policy)


func _drive_action() -> void:
	if app == null:
		return
	action_counter += 1
	await _resolve_blocking_popup()
	if _run_is_terminal():
		await _start_next_run()
		return
	if action_counter % RUN_ROTATION_ACTION_INTERVAL == 0:
		await _start_next_run()
		return
	if action_counter % SAVE_LOAD_ACTION_INTERVAL == 0:
		app.call("save_foundation_run")
		await _settle(2)
		app.call("load_foundation_run")
		coverage["save_loads"] = int(coverage.get("save_loads", 0)) + 1
		await _settle(3)
		return
	if action_counter % SLOT_AUTOPLAY_ACTION_INTERVAL == 0:
		await _exercise_slot_autoplay_block()
		return
	if action_counter % 5 == 0:
		var did_travel: bool = await _try_world_map_travel()
		if did_travel:
			return
	if action_counter % 7 == 0:
		var did_object: bool = await _try_interactable_object(["lender", "service", "event", "item", "game_hook"])
		if did_object:
			return
	var did_game: bool = await _try_play_environment_game()
	if did_game:
		return
	var fallback_travel: bool = await _try_world_map_travel()
	if fallback_travel:
		return
	await _try_interactable_object(["event", "lender", "service", "item", "game_hook"])


func _try_world_map_travel() -> bool:
	if _run_is_terminal():
		return false
	var before_state: Dictionary = app.call("serialized_run_state")
	var before_node := _current_world_node_id(before_state)
	if not bool(app.call("open_world_map")):
		return false
	await _settle(2)
	var screen: Dictionary = app.call("current_screen_snapshot")
	var map_snapshot: Dictionary = _dict(screen.get("world_map", {}))
	var target_id := _preferred_world_target(map_snapshot, before_node)
	if target_id.is_empty():
		target_id = _preferred_travel_choice_id()
	if target_id.is_empty():
		app.call("close_world_map")
		await _settle(1)
		return false
	if not bool(app.call("select_world_map_node", target_id)):
		app.call("close_world_map")
		await _settle(1)
		return false
	app.call("confirm_world_map_travel")
	await _settle(6)
	await _resolve_blocking_popup()
	var after_state: Dictionary = app.call("serialized_run_state")
	var after_node := _current_world_node_id(after_state)
	if after_node == before_node and target_id != before_node:
		warnings.append("World-map travel target %s did not change node from %s." % [target_id, before_node])
		return false
	coverage["world_travels"] = int(coverage.get("world_travels", 0)) + 1
	if _world_node_was_visited(map_snapshot, target_id):
		coverage["revisits"] = int(coverage.get("revisits", 0)) + 1
	app.call("back_to_environment")
	await _settle(2)
	return true


func _preferred_world_target(map_snapshot: Dictionary, current_node_id: String) -> String:
	var enabled_ids := _string_array(map_snapshot.get("travel_enabled_node_ids", []))
	if enabled_ids.is_empty():
		return ""
	var nodes := _array(map_snapshot.get("nodes", []))
	if action_counter % 2 == 0:
		for node_value in nodes:
			var node := _dict(node_value)
			var node_id := str(node.get("id", ""))
			if node_id == current_node_id or not enabled_ids.has(node_id):
				continue
			if str(node.get("state", "")) == "visited" or bool(node.get("visited", false)):
				return node_id
	for target_id in enabled_ids:
		if str(target_id) != current_node_id:
			return str(target_id)
	return ""


func _world_node_was_visited(map_snapshot: Dictionary, target_id: String) -> bool:
	for node_value in _array(map_snapshot.get("nodes", [])):
		var node := _dict(node_value)
		if str(node.get("id", "")) != target_id:
			continue
		return str(node.get("state", "")) == "visited" or bool(node.get("visited", false))
	return false


func _preferred_travel_choice_id() -> String:
	var environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	for choice_value in _array(environment_snapshot.get("travel_choices", [])):
		var choice := _dict(choice_value)
		if bool(choice.get("enabled", true)):
			return str(choice.get("id", ""))
	return ""


func _try_interactable_object(preferred_types: Array) -> bool:
	if _run_is_terminal():
		return false
	var spatial: Dictionary = app.call("current_spatial_interaction_snapshot")
	var objects := _array(spatial.get("objects", []))
	for preferred_type_value in preferred_types:
		var preferred_type := str(preferred_type_value)
		for object_value in objects:
			var object_data := _dict(object_value)
			if str(object_data.get("object_type", "")) != preferred_type:
				continue
			if not bool(object_data.get("enabled", true)):
				continue
			var object_id := str(object_data.get("object_id", ""))
			if object_id.is_empty():
				continue
			var activated := bool(app.call("activate_interactable_object", object_id))
			await _settle(3)
			await _resolve_blocking_popup()
			if activated:
				_increment_object_coverage(preferred_type)
				app.call("back_to_environment")
				await _settle(2)
				return true
	return false


func _try_play_environment_game() -> bool:
	if _run_is_terminal():
		return false
	var environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var game_ids := _string_array(environment_snapshot.get("game_ids", []))
	if game_ids.is_empty():
		return false
	var game_id := _preferred_game_id(game_ids)
	if game_id.is_empty():
		return false
	app.call("enter_game", game_id)
	await _settle(3)
	var game_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if not bool(game_snapshot.get("has_valid_stake", false)):
		app.call("back_to_environment")
		await _settle(1)
		return false
	var stake_min := maxi(1, int(game_snapshot.get("stake_min", 1)))
	var stake_max := maxi(stake_min, int(game_snapshot.get("stake_max", stake_min)))
	app.call("set_selected_stake", clampi(10, stake_min, stake_max))
	var action := _preferred_game_action(game_id, _array(game_snapshot.get("legal_actions", [])))
	if action.is_empty():
		app.call("back_to_environment")
		await _settle(1)
		return false
	app.call("select_game_action", str(action.get("id", "")), "legal")
	app.call("resolve_selected_game_action")
	await _settle(5)
	await _resolve_blocking_popup()
	coverage["game_actions"] = int(coverage.get("game_actions", 0)) + 1
	coverage["game:%s" % game_id] = int(coverage.get("game:%s" % game_id, 0)) + 1
	app.call("back_to_environment")
	await _settle(2)
	return true


func _preferred_game_id(game_ids: Array) -> String:
	if game_ids.has("slot"):
		return "slot"
	var index := posmod(action_counter, game_ids.size())
	return str(game_ids[index])


func _preferred_game_action(game_id: String, actions: Array) -> Dictionary:
	var preferred_ids := {
		"slot": "spin",
		"pull_tabs": "buy_tab",
		"bar_dice": "roll",
		"blackjack": "play_basic",
		"baccarat": "deal_baccarat",
		"roulette": "spin_roulette",
		"craps": "roll_craps",
		"video_poker": "draw",
	}
	var preferred_id := str(preferred_ids.get(game_id, ""))
	for action_value in actions:
		var action := _dict(action_value)
		if str(action.get("id", "")) == preferred_id:
			return action
	for action_value in actions:
		var action := _dict(action_value)
		if not str(action.get("id", "")).is_empty():
			return action
	return {}


func _exercise_slot_autoplay_block() -> void:
	app.call("start_game_test_session", "slot")
	await _settle(5)
	var canvas := app.get("game_surface_canvas") as Control
	if canvas == null:
		failures.append("Soak probe could not find game_surface_canvas for slot autoplay.")
	else:
		canvas.emit_signal("surface_action", "slot_auto_toggle", 0, false)
		coverage["slot_autoplay_blocks"] = int(coverage.get("slot_autoplay_blocks", 0)) + 1
		for frame_index in range(SLOT_AUTOPLAY_FRAMES):
			await process_frame
			if frame_index % 30 == 0:
				await _resolve_blocking_popup()
	_stress_pinball_session_cache()
	app.call("return_to_main_menu")
	await _settle(4)
	await _start_next_run()


func _stress_pinball_session_cache() -> void:
	var rng := RngStream.new()
	rng.configure(910000 + action_counter, 910000 + action_counter)
	var feature := PinballFeatureScript.new()
	for session_index in range(PINBALL_CACHE_STRESS_SESSIONS):
		var mode := _pinball_mode_for_index(session_index)
		var machine := {
			"format_id": _pinball_format_for_mode(mode),
			"type_id": "pinball",
			"bet_ladder": {"selected_id": "bet_10"},
		}
		var active: Dictionary = feature.open(machine, mode, 10, rng, {"cap": 180, "ball_budget": 3})
		machine["active_bonus"] = active
	coverage["pinball_cache_stress_blocks"] = int(coverage.get("pinball_cache_stress_blocks", 0)) + 1


func _pinball_mode_for_index(index: int) -> String:
	match index % 3:
		1:
			return "lane_multiball"
		2:
			return "video_feature"
		_:
			return "em_bumper_drop"


func _pinball_format_for_mode(mode: String) -> String:
	match mode:
		"lane_multiball":
			return "line_5x3"
		"video_feature":
			return "video_feature"
		_:
			return "classic_3_reel"


func _resolve_blocking_popup() -> bool:
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot") if app != null else {}
	if not bool(popup.get("visible", false)):
		return false
	var popup_type := str(popup.get("popup_type", ""))
	if popup_type == "active_item_confirmation":
		app.call("cancel_pending_active_item_use")
		await _settle(2)
		return true
	if popup_type == "wager_confirmation":
		app.call("cancel_pending_wager_confirmation")
		await _settle(2)
		return true
	var event_id := str(popup.get("event_id", ""))
	var choices := _array(popup.get("choices", []))
	for choice_value in choices:
		var choice := _dict(choice_value)
		if bool(choice.get("dismissal", false)):
			continue
		var choice_id := str(choice.get("id", ""))
		if not event_id.is_empty() and not choice_id.is_empty():
			app.call("resolve_event_choice", event_id, choice_id)
			coverage["event_actions"] = int(coverage.get("event_actions", 0)) + 1
			await _settle(3)
			return true
	if not choices.is_empty() and not event_id.is_empty():
		var fallback_choice := _dict(choices[0])
		var fallback_id := str(fallback_choice.get("id", ""))
		if not fallback_id.is_empty():
			app.call("resolve_event_choice", event_id, fallback_id)
			await _settle(3)
			return true
	app.call("_hide_event_choice_popup")
	await _settle(1)
	return true


func _sample_retained_state(sample_index: int) -> void:
	var challenge: Dictionary = RunStateScript.custom_challenge("soak_retained_measurement", RETAINED_MEASUREMENT_SEED, {
		"starting_bankroll": 5000,
		"hidden_seed": true,
	})
	app.set("autosave_slot_id", SOAK_SAVE_SLOT)
	app.call("start_foundation_run", RETAINED_MEASUREMENT_SEED, challenge)
	coverage["retained_measurement_resets"] = int(coverage.get("retained_measurement_resets", 0)) + 1
	await _settle(RETAINED_MEASUREMENT_SETTLE_FRAMES)
	await _sample(sample_index, true)


func _sample(sample_index: int, retained_measurement: bool = false) -> void:
	await _settle(2)
	var state: Dictionary = app.call("serialized_run_state") if app != null else {}
	var serialized_text := JSON.stringify(state)
	var app_debug := _app_debug_snapshot()
	var pinball_debug := PinballFeatureScript.runtime_session_debug_snapshot()
	var node_class_counts := _node_class_counts()
	var environment_debug := _dict(app_debug.get("environment_canvas", {}))
	var sample := {
		"sample_index": sample_index,
		"sim_minute": sample_index * SAMPLE_INTERVAL_MINUTES,
		"action_count": action_counter,
		"run_index": run_index,
		"memory_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"scene_tree_node_count": _scene_tree_node_count(),
		"serialized_run_state_bytes": serialized_text.length(),
		"environment_history_length": _array_size(state.get("environment_history", [])),
		"environment_history_archive_count": int(state.get("environment_history_archive_count", 0)),
		"environment_travel_count": int(state.get("environment_history_archive_count", 0)) + _array_size(state.get("environment_history", [])),
		"story_log_length": _array_size(state.get("story_log", [])),
		"story_log_archive_count": int(state.get("story_log_archive_count", 0)),
		"story_log_entry_count": int(state.get("story_log_archive_count", 0)) + _array_size(state.get("story_log", [])),
		"world_map_visited_path_length": _world_map_visited_path_length(state),
		"pinball_session_cache_size": PinballFeatureScript.runtime_session_cache_size(),
		"node_class_counts": node_class_counts,
		"diagnostics": {
			"app": app_debug,
			"pinball": pinball_debug,
		},
	}
	if sample_log_file != null:
		sample_log_file.store_line(JSON.stringify({
			"retained": retained_measurement,
			"sample": sample,
		}))
		sample_log_file.flush()
	print("%s index=%d sim_minute=%d memory=%d objects=%d resources=%d nodes=%d orphans=%d serialized=%d env_history=%d/%d story=%d/%d pinball_cache=%d pinball_view_bytes=%d room_icon_cache=%d run_icon_cache=%d" % [
		"SOAK_RETAINED_SAMPLE" if retained_measurement else "SOAK_SAMPLE",
		sample_index,
		int(sample.get("sim_minute", 0)),
		int(sample.get("memory_static_bytes", 0)),
		int(sample.get("object_count", 0)),
		int(sample.get("resource_count", 0)),
		int(sample.get("node_count", 0)),
		int(sample.get("orphan_node_count", 0)),
		int(sample.get("serialized_run_state_bytes", 0)),
		int(sample.get("environment_history_length", 0)),
		int(sample.get("environment_travel_count", 0)),
		int(sample.get("story_log_length", 0)),
		int(sample.get("story_log_entry_count", 0)),
		int(sample.get("pinball_session_cache_size", 0)),
		int(pinball_debug.get("cached_view_bytes", 0)),
		int(environment_debug.get("item_icon_texture_cache_size", 0)),
		int(app_debug.get("run_item_icon_texture_cache_size", 0)),
	])
	if int(sample.get("orphan_node_count", 0)) > 0 and str(OS.get_environment("BTH_SOAK_PRINT_ORPHANS")).to_lower() in ["1", "true", "yes"]:
		Node.print_orphan_nodes()


func _assert_coverage() -> void:
	for key in ["runs_started", "save_loads", "world_travels", "game_actions", "slot_autoplay_blocks", "pinball_cache_stress_blocks"]:
		if _total_coverage_count(key) <= 0:
			failures.append("Soak probe did not exercise required path: %s." % key)
	if _total_coverage_count("runs_started") < 3:
		failures.append("Soak probe expected at least 3 back-to-back runs, got %d." % _total_coverage_count("runs_started"))
	if _total_coverage_count("event_actions") + _total_coverage_count("lender_actions") + _total_coverage_count("service_actions") <= 0:
		failures.append("Soak probe did not exercise any event/lender/service lifecycle path.")
	var slot_background_cache_cap := int(coverage.get("slot_background_texture_cache_cap", 0))
	if slot_background_cache_cap <= 0 or int(coverage.get("slot_background_textures_prewarmed", 0)) != slot_background_cache_cap:
		failures.append("Soak probe did not prewarm the bounded slot background cache to its cap.")
	_assert_feature_pcm_coverage()


func _assert_feature_pcm_coverage() -> void:
	var expected_request_count := FEATURE_PCM_BOUNDARY_COUNT * FEATURE_PCM_REQUESTS_PER_BOUNDARY
	if not bool(feature_pcm_evidence.get("passed", false)):
		failures.append("Soak probe feature PCM evidence did not pass.")
	if str(feature_pcm_evidence.get("seed_prefix", "")) != seed_prefix:
		failures.append("Soak probe feature PCM evidence lost its seed-prefix provenance.")
	if int(feature_pcm_evidence.get("boundary_count", 0)) != FEATURE_PCM_BOUNDARY_COUNT:
		failures.append("Soak probe did not exercise feature PCM across %d run boundaries." % FEATURE_PCM_BOUNDARY_COUNT)
	if int(feature_pcm_evidence.get("requests_per_boundary", 0)) != FEATURE_PCM_REQUESTS_PER_BOUNDARY \
			or int(feature_pcm_evidence.get("distinct_context_count", 0)) != expected_request_count:
		failures.append("Soak probe did not exercise %d distinct feature contexts per boundary." % FEATURE_PCM_REQUESTS_PER_BOUNDARY)
	if int(feature_pcm_evidence.get("successful_load_count", 0)) != expected_request_count \
			or int(feature_pcm_evidence.get("successful_play_count", 0)) != expected_request_count:
		failures.append("Soak probe did not complete every production feature PCM load/play handoff.")
	if _array(feature_pcm_evidence.get("physical_cache_keys", [])).size() != 2:
		failures.append("Soak probe feature contexts did not deduplicate to the two delivered physical packs.")
	if int(feature_pcm_evidence.get("cache_budget_bytes", 0)) != FEATURE_PCM_EXPECTED_BUDGET_BYTES:
		failures.append("Soak probe feature PCM evidence changed the declared 64 MiB budget.")
	if int(feature_pcm_evidence.get("cleanup_to_baseline_count", 0)) != FEATURE_PCM_BOUNDARY_COUNT \
			or int(feature_pcm_evidence.get("cleanup_evicted_key_count", 0)) < FEATURE_PCM_BOUNDARY_COUNT * 2:
		failures.append("Soak probe feature PCM did not return to baseline after every run boundary.")


func _assert_growth() -> void:
	if samples.size() <= WARMUP_SAMPLE_COUNT or retained_samples.size() <= WARMUP_SAMPLE_COUNT:
		failures.append("Soak probe did not collect enough samples for post-warmup growth checks.")
		return
	_assert_metric_growth(
		"memory_static_bytes",
		MAX_POST_WARMUP_MEMORY_PEAK_GROWTH_BYTES,
		MAX_POST_WARMUP_MEMORY_RETAINED_GROWTH_BYTES,
		MAX_POST_WARMUP_MEMORY_RETAINED_SLOPE_BYTES_PER_SAMPLE
	)
	_assert_metric_growth(
		"resource_count",
		MAX_POST_WARMUP_RESOURCE_PEAK_GROWTH,
		MAX_POST_WARMUP_RESOURCE_RETAINED_GROWTH,
		MAX_POST_WARMUP_RESOURCE_RETAINED_SLOPE_PER_SAMPLE
	)
	_assert_metric_growth(
		"object_count",
		MAX_POST_WARMUP_OBJECT_PEAK_GROWTH,
		MAX_POST_WARMUP_OBJECT_RETAINED_GROWTH,
		MAX_POST_WARMUP_OBJECT_RETAINED_SLOPE_PER_SAMPLE
	)
	_assert_metric_growth(
		"node_count",
		MAX_POST_WARMUP_NODE_PEAK_GROWTH,
		MAX_POST_WARMUP_NODE_RETAINED_GROWTH,
		MAX_POST_WARMUP_NODE_RETAINED_SLOPE_PER_SAMPLE,
		true
	)
	for sample_value in samples:
		var sample := _dict(sample_value)
		if int(sample.get("serialized_run_state_bytes", 0)) > MAX_SERIALIZED_RUN_STATE_BYTES:
			failures.append("Serialized RunState size %d exceeded cap %d at sample %d." % [
				int(sample.get("serialized_run_state_bytes", 0)),
				MAX_SERIALIZED_RUN_STATE_BYTES,
				int(sample.get("sample_index", 0)),
			])
		if int(sample.get("environment_history_length", 0)) > RunStateScript.MAX_ENVIRONMENT_HISTORY_ENTRIES:
			failures.append("Environment history length exceeded cap at sample %d." % int(sample.get("sample_index", 0)))
		if int(sample.get("story_log_length", 0)) > RunStateScript.MAX_STORY_LOG_ENTRIES:
			failures.append("Story log length exceeded cap at sample %d." % int(sample.get("sample_index", 0)))
		if int(sample.get("pinball_session_cache_size", 0)) > PinballFeatureScript.MAX_RUNTIME_SESSIONS:
			failures.append("Pinball runtime session cache exceeded cap at sample %d." % int(sample.get("sample_index", 0)))
		if int(sample.get("orphan_node_count", 0)) > MAX_POST_WARMUP_ORPHAN_NODE_COUNT:
			failures.append("Orphan node count %d exceeded cap at sample %d." % [
				int(sample.get("orphan_node_count", 0)),
				int(sample.get("sample_index", 0)),
			])
	for sample_value in retained_samples:
		var sample := _dict(sample_value)
		if int(sample.get("orphan_node_count", 0)) > MAX_POST_WARMUP_ORPHAN_NODE_COUNT:
			failures.append("Retained-state orphan node count %d exceeded cap at sample %d." % [
				int(sample.get("orphan_node_count", 0)),
				int(sample.get("sample_index", 0)),
			])


func _assert_metric_growth(metric_key: String, max_peak_growth: float, max_retained_growth: float, max_retained_slope: float, comparable_peak: bool = false) -> void:
	var workload_warmup_sample := _dict(samples[WARMUP_SAMPLE_COUNT])
	var workload_warmup_value := float(workload_warmup_sample.get(metric_key, 0.0))
	var retained_warmup_sample := _dict(retained_samples[WARMUP_SAMPLE_COUNT])
	var retained_warmup_value := float(retained_warmup_sample.get(metric_key, 0.0))
	# Godot's static allocator monitor can acquire a page on a single sample and
	# release/reuse it later even when resources, objects, nodes, serialized state,
	# and every application cache are unchanged. Use the median of the final three
	# comparable resets as the retained endpoint; sustained growth still moves the
	# median, while an isolated allocator-page outlier remains covered by the peak
	# budget and the exact object/resource/node caps below.
	var final_value := _median_tail_value(retained_samples, metric_key, RETAINED_VALUE_TAIL_SAMPLE_COUNT)
	var peak_samples := retained_samples if comparable_peak else samples
	var max_value := retained_warmup_value if comparable_peak else workload_warmup_value
	for index in range(WARMUP_SAMPLE_COUNT, peak_samples.size()):
		var sample := _dict(peak_samples[index])
		max_value = maxf(max_value, float(sample.get(metric_key, 0.0)))
	var peak_growth := max_value - (retained_warmup_value if comparable_peak else workload_warmup_value)
	var retained_growth := final_value - retained_warmup_value
	var retained_slope := _retained_trend_slope(retained_samples, metric_key, WARMUP_SAMPLE_COUNT)
	var retained_recent_growth := _retained_recent_growth(retained_samples, metric_key)
	if peak_growth > max_peak_growth:
		failures.append("%s post-warmup peak growth %.3f exceeded %.3f." % [metric_key, peak_growth, max_peak_growth])
	if retained_growth > max_retained_growth:
		failures.append("%s post-warmup retained growth %.3f exceeded %.3f." % [metric_key, retained_growth, max_retained_growth])
	if retained_slope > max_retained_slope and (retained_growth > max_retained_growth or retained_recent_growth > max_retained_slope):
		failures.append("%s post-warmup retained slope %.3f/sample exceeded %.3f/sample." % [metric_key, retained_slope, max_retained_slope])


func _retained_slope(source_samples: Array, metric_key: String, start_index: int) -> float:
	if source_samples.size() <= start_index + 1:
		return 0.0
	var start_value := float(_dict(source_samples[start_index]).get(metric_key, 0.0))
	var final_value := float(_dict(source_samples[source_samples.size() - 1]).get(metric_key, 0.0))
	var intervals := float(source_samples.size() - 1 - start_index)
	if intervals <= 0.0:
		return 0.0
	return maxf(0.0, (final_value - start_value) / intervals)


func _retained_trend_slope(source_samples: Array, metric_key: String, minimum_start_index: int) -> float:
	var tail_start_index := maxi(minimum_start_index, source_samples.size() - RETAINED_SLOPE_TAIL_SAMPLE_COUNT)
	return _median_pairwise_slope(source_samples, metric_key, tail_start_index)


func _median_tail_value(source_samples: Array, metric_key: String, tail_count: int) -> float:
	if source_samples.is_empty():
		return 0.0
	var values: Array[float] = []
	var start_index := maxi(0, source_samples.size() - maxi(1, tail_count))
	for index in range(start_index, source_samples.size()):
		values.append(float(_dict(source_samples[index]).get(metric_key, 0.0)))
	values.sort()
	var middle := values.size() / 2
	if values.size() % 2 == 1:
		return values[middle]
	return (values[middle - 1] + values[middle]) * 0.5


func _median_pairwise_slope(source_samples: Array, metric_key: String, start_index: int) -> float:
	var slopes: Array[float] = []
	for left_index in range(start_index, source_samples.size() - 1):
		var left_value := float(_dict(source_samples[left_index]).get(metric_key, 0.0))
		for right_index in range(left_index + 1, source_samples.size()):
			var right_value := float(_dict(source_samples[right_index]).get(metric_key, 0.0))
			slopes.append((right_value - left_value) / float(right_index - left_index))
	if slopes.is_empty():
		return 0.0
	slopes.sort()
	var middle := slopes.size() / 2
	var median := slopes[middle] if slopes.size() % 2 == 1 else (slopes[middle - 1] + slopes[middle]) * 0.5
	return maxf(0.0, median)


func _retained_recent_growth(source_samples: Array, metric_key: String) -> float:
	if source_samples.size() < 2:
		return 0.0
	var previous_value := float(_dict(source_samples[source_samples.size() - 2]).get(metric_key, 0.0))
	var final_value := float(_dict(source_samples[source_samples.size() - 1]).get(metric_key, 0.0))
	return maxf(0.0, final_value - previous_value)


func _linear_slope(source_samples: Array, metric_key: String, start_index: int) -> float:
	var count := source_samples.size() - start_index
	if count <= 1:
		return 0.0
	var sum_x := 0.0
	var sum_y := 0.0
	var sum_xy := 0.0
	var sum_x2 := 0.0
	for index in range(start_index, source_samples.size()):
		var x := float(index - start_index)
		var y := float(_dict(source_samples[index]).get(metric_key, 0.0))
		sum_x += x
		sum_y += y
		sum_xy += x * y
		sum_x2 += x * x
	var denominator := float(count) * sum_x2 - sum_x * sum_x
	if is_zero_approx(denominator):
		return 0.0
	return maxf(0.0, (float(count) * sum_xy - sum_x * sum_y) / denominator)


func _print_summary() -> void:
	var warmup_sample := _dict(retained_samples[WARMUP_SAMPLE_COUNT]) if retained_samples.size() > WARMUP_SAMPLE_COUNT else {}
	var retained_memory := _median_tail_value(retained_samples, "memory_static_bytes", RETAINED_VALUE_TAIL_SAMPLE_COUNT)
	var retained_objects := _median_tail_value(retained_samples, "object_count", RETAINED_VALUE_TAIL_SAMPLE_COUNT)
	var retained_nodes := _median_tail_value(retained_samples, "node_count", RETAINED_VALUE_TAIL_SAMPLE_COUNT)
	print("FOUNDATION_SOAK_OVERALL status=%s seed_prefix=%s samples=%d sim_minutes=%d actions=%d feature_boundaries=%d feature_contexts=%d feature_loads=%d feature_plays=%d feature_cleanups=%d feature_evicted_keys=%d pcm_budget=%d memory_growth=%d object_growth=%d node_growth=%d serialized_max=%d coverage=%s report=%s" % [
		"PASS" if failures.is_empty() else "FAIL",
		seed_prefix,
		samples.size(),
		sim_minutes,
		action_counter,
		int(feature_pcm_evidence.get("boundary_count", 0)),
		int(feature_pcm_evidence.get("distinct_context_count", 0)),
		int(feature_pcm_evidence.get("successful_load_count", 0)),
		int(feature_pcm_evidence.get("successful_play_count", 0)),
		int(feature_pcm_evidence.get("cleanup_to_baseline_count", 0)),
		int(feature_pcm_evidence.get("cleanup_evicted_key_count", 0)),
		int(feature_pcm_evidence.get("cache_budget_bytes", 0)),
		int(retained_memory) - int(warmup_sample.get("memory_static_bytes", 0)),
		int(retained_objects) - int(warmup_sample.get("object_count", 0)),
		int(retained_nodes) - int(warmup_sample.get("node_count", 0)),
		_max_sample_int("serialized_run_state_bytes"),
		JSON.stringify(coverage),
		REPORT_PATH,
	])


func _write_report() -> void:
	var detailed_samples := []
	var detailed_retained_samples := []
	if sample_log_file != null:
		sample_log_file.flush()
		sample_log_file = null
	var sample_log := FileAccess.open(SAMPLE_LOG_PATH, FileAccess.READ)
	if sample_log == null:
		failures.append("Could not read soak sample spool at %s." % SAMPLE_LOG_PATH)
	else:
		while sample_log.get_position() < sample_log.get_length():
			var parsed: Variant = JSON.parse_string(sample_log.get_line())
			if typeof(parsed) != TYPE_DICTIONARY:
				continue
			var entry := parsed as Dictionary
			var detailed_sample: Variant = entry.get("sample", {})
			if typeof(detailed_sample) != TYPE_DICTIONARY:
				continue
			if bool(entry.get("retained", false)):
				detailed_retained_samples.append(detailed_sample)
			else:
				detailed_samples.append(detailed_sample)
	var report := {
		"passed": failures.is_empty(),
		"failures": failures.duplicate(),
		"warnings": warnings.duplicate(),
		"coverage": coverage.duplicate(true),
		"total_coverage": _total_coverage_snapshot(),
		"feature_pcm": feature_pcm_evidence.duplicate(true),
		"config": {
			"seed_prefix": seed_prefix,
			"sim_minutes": sim_minutes,
			"sample_interval_minutes": SAMPLE_INTERVAL_MINUTES,
			"actions_per_sample": actions_per_sample,
			"warmup_sample_count": WARMUP_SAMPLE_COUNT,
			"retained_slope_tail_sample_count": RETAINED_SLOPE_TAIL_SAMPLE_COUNT,
			"retained_value_tail_sample_count": RETAINED_VALUE_TAIL_SAMPLE_COUNT,
			"retained_measurement_settle_frames": RETAINED_MEASUREMENT_SETTLE_FRAMES + 2,
			"serialized_run_state_cap_bytes": MAX_SERIALIZED_RUN_STATE_BYTES,
			"environment_history_cap": RunStateScript.MAX_ENVIRONMENT_HISTORY_ENTRIES,
			"story_log_cap": RunStateScript.MAX_STORY_LOG_ENTRIES,
			"pinball_session_cache_cap": PinballFeatureScript.MAX_RUNTIME_SESSIONS,
			"slot_autoplay_prewarm_blocks": SLOT_AUTOPLAY_PREWARM_BLOCKS,
			"workload_prewarm_actions": int(coverage.get("workload_prewarm_actions", 0)),
			"memory_peak_growth_cap_bytes": MAX_POST_WARMUP_MEMORY_PEAK_GROWTH_BYTES,
			"memory_retained_growth_cap_bytes": MAX_POST_WARMUP_MEMORY_RETAINED_GROWTH_BYTES,
			"memory_retained_slope_cap_bytes_per_sample": MAX_POST_WARMUP_MEMORY_RETAINED_SLOPE_BYTES_PER_SAMPLE,
			"resource_peak_growth_cap": MAX_POST_WARMUP_RESOURCE_PEAK_GROWTH,
			"resource_retained_growth_cap": MAX_POST_WARMUP_RESOURCE_RETAINED_GROWTH,
			"resource_retained_slope_cap_per_sample": MAX_POST_WARMUP_RESOURCE_RETAINED_SLOPE_PER_SAMPLE,
			"object_peak_growth_cap": MAX_POST_WARMUP_OBJECT_PEAK_GROWTH,
			"object_retained_growth_cap": MAX_POST_WARMUP_OBJECT_RETAINED_GROWTH,
			"object_retained_slope_cap_per_sample": MAX_POST_WARMUP_OBJECT_RETAINED_SLOPE_PER_SAMPLE,
			"node_peak_growth_cap": MAX_POST_WARMUP_NODE_PEAK_GROWTH,
			"node_retained_growth_cap": MAX_POST_WARMUP_NODE_RETAINED_GROWTH,
			"node_retained_slope_cap_per_sample": MAX_POST_WARMUP_NODE_RETAINED_SLOPE_PER_SAMPLE,
		},
		"samples": detailed_samples,
		"retained_measurement_samples": detailed_retained_samples,
		"measurement_storage": "incremental_jsonl_spool",
		"post_warmup_slopes": {
			"memory_static_bytes": _linear_slope(retained_samples, "memory_static_bytes", WARMUP_SAMPLE_COUNT),
			"resource_count": _linear_slope(retained_samples, "resource_count", WARMUP_SAMPLE_COUNT),
			"object_count": _linear_slope(retained_samples, "object_count", WARMUP_SAMPLE_COUNT),
			"node_count": _linear_slope(retained_samples, "node_count", WARMUP_SAMPLE_COUNT),
		},
		"post_warmup_workload_slopes": {
			"memory_static_bytes": _linear_slope(samples, "memory_static_bytes", WARMUP_SAMPLE_COUNT),
			"resource_count": _linear_slope(samples, "resource_count", WARMUP_SAMPLE_COUNT),
			"object_count": _linear_slope(samples, "object_count", WARMUP_SAMPLE_COUNT),
			"node_count": _linear_slope(samples, "node_count", WARMUP_SAMPLE_COUNT),
		},
		"post_warmup_retained_slopes": {
			"memory_static_bytes": _retained_trend_slope(retained_samples, "memory_static_bytes", WARMUP_SAMPLE_COUNT),
			"resource_count": _retained_trend_slope(retained_samples, "resource_count", WARMUP_SAMPLE_COUNT),
			"object_count": _retained_trend_slope(retained_samples, "object_count", WARMUP_SAMPLE_COUNT),
			"node_count": _retained_trend_slope(retained_samples, "node_count", WARMUP_SAMPLE_COUNT),
		},
		"post_warmup_retained_full_window_average_growth_per_sample": {
			"memory_static_bytes": _retained_slope(retained_samples, "memory_static_bytes", WARMUP_SAMPLE_COUNT),
			"resource_count": _retained_slope(retained_samples, "resource_count", WARMUP_SAMPLE_COUNT),
			"object_count": _retained_slope(retained_samples, "object_count", WARMUP_SAMPLE_COUNT),
			"node_count": _retained_slope(retained_samples, "node_count", WARMUP_SAMPLE_COUNT),
		},
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write soak report to %s." % REPORT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t"))


func _hydrate_metric_samples_from_spool() -> void:
	samples = []
	retained_samples = []
	if sample_log_file != null:
		sample_log_file.flush()
	var sample_log := FileAccess.open(SAMPLE_LOG_PATH, FileAccess.READ)
	if sample_log == null:
		failures.append("Could not hydrate soak metrics from %s." % SAMPLE_LOG_PATH)
		return
	while sample_log.get_position() < sample_log.get_length():
		var parsed: Variant = JSON.parse_string(sample_log.get_line())
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var entry := parsed as Dictionary
		var detailed_sample: Variant = entry.get("sample", {})
		if typeof(detailed_sample) != TYPE_DICTIONARY:
			continue
		if bool(entry.get("retained", false)):
			retained_samples.append(_metric_sample(detailed_sample as Dictionary))
		else:
			samples.append(_metric_sample(detailed_sample as Dictionary))


func _metric_sample(sample: Dictionary) -> Dictionary:
	return {
		"sample_index": int(sample.get("sample_index", 0)),
		"sim_minute": int(sample.get("sim_minute", 0)),
		"action_count": int(sample.get("action_count", 0)),
		"run_index": int(sample.get("run_index", 0)),
		"memory_static_bytes": int(sample.get("memory_static_bytes", 0)),
		"object_count": int(sample.get("object_count", 0)),
		"node_count": int(sample.get("node_count", 0)),
		"orphan_node_count": int(sample.get("orphan_node_count", 0)),
		"resource_count": int(sample.get("resource_count", 0)),
		"serialized_run_state_bytes": int(sample.get("serialized_run_state_bytes", 0)),
		"environment_history_length": int(sample.get("environment_history_length", 0)),
		"environment_history_archive_count": int(sample.get("environment_history_archive_count", 0)),
		"story_log_length": int(sample.get("story_log_length", 0)),
		"story_log_archive_count": int(sample.get("story_log_archive_count", 0)),
		"pinball_session_cache_size": int(sample.get("pinball_session_cache_size", 0)),
	}


func _cleanup_app() -> void:
	if app == null:
		return
	var parent := app.get_parent()
	if parent != null:
		parent.remove_child(app)
	app.queue_free()
	app = null
	for _index in range(8):
		await process_frame


func _run_is_terminal() -> bool:
	var state: Dictionary = app.call("serialized_run_state") if app != null else {}
	var status := str(state.get("run_status", ""))
	return status == "failed" or status == "ended"


func _current_world_node_id(state: Dictionary) -> String:
	var world_map := _dict(state.get("world_map", {}))
	return str(world_map.get("current_node_id", ""))


func _world_map_visited_path_length(state: Dictionary) -> int:
	var world_map := _dict(state.get("world_map", {}))
	return _array_size(world_map.get("visited_path", []))


func _app_debug_snapshot() -> Dictionary:
	if app == null or not app.has_method("debug_soak_snapshot"):
		return {}
	var value: Variant = app.call("debug_soak_snapshot")
	return _dict(value)


func _node_class_counts() -> Dictionary:
	var counts := {}
	if app == null:
		return counts
	_count_node_classes(app, counts)
	return counts


func _count_node_classes(node: Node, counts: Dictionary) -> void:
	var class_id := node.get_class()
	counts[class_id] = int(counts.get(class_id, 0)) + 1
	for child in node.get_children():
		if child is Node:
			_count_node_classes(child as Node, counts)


func _scene_tree_node_count() -> int:
	return _count_nodes(get_root())


func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total


func _increment_object_coverage(object_type: String) -> void:
	match object_type:
		"event":
			coverage["event_actions"] = int(coverage.get("event_actions", 0)) + 1
		"item":
			coverage["item_actions"] = int(coverage.get("item_actions", 0)) + 1
		"service":
			coverage["service_actions"] = int(coverage.get("service_actions", 0)) + 1
		"lender":
			coverage["lender_actions"] = int(coverage.get("lender_actions", 0)) + 1
		_:
			coverage["object:%s" % object_type] = int(coverage.get("object:%s" % object_type, 0)) + 1


func _total_coverage_count(key: String) -> int:
	var total := int(coverage.get(key, 0))
	var prewarm: Variant = coverage.get("workload_prewarm_coverage", {})
	if typeof(prewarm) == TYPE_DICTIONARY:
		total += int((prewarm as Dictionary).get(key, 0))
	return total


func _total_coverage_snapshot() -> Dictionary:
	var keys := {}
	for key in coverage.keys():
		if str(key) != "workload_prewarm_coverage":
			keys[str(key)] = true
	var prewarm: Variant = coverage.get("workload_prewarm_coverage", {})
	if typeof(prewarm) == TYPE_DICTIONARY:
		for key in (prewarm as Dictionary).keys():
			keys[str(key)] = true
	var result := {}
	for key in keys.keys():
		result[str(key)] = _total_coverage_count(str(key))
	return result


func _max_sample_int(metric_key: String) -> int:
	var result := 0
	for sample_value in samples:
		result = maxi(result, int(_dict(sample_value).get(metric_key, 0)))
	return result


func _configured_int(name: String, fallback: int) -> int:
	var raw := OS.get_environment(name).strip_edges()
	if raw.is_empty() or not raw.is_valid_int():
		return fallback
	return maxi(1, int(raw))


func _settle(frames: int) -> void:
	for _index in range(maxi(0, frames)):
		await process_frame


func _dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _array_size(value: Variant) -> int:
	if typeof(value) != TYPE_ARRAY:
		return 0
	return (value as Array).size()


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in (value as Array):
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result
