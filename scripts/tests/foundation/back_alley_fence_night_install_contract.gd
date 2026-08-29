extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const SEED := "UI-ALL-IN-RESULT"
const SCENARIO_ID := "back_alley_fence_night"
const EXIT_IDENTITY := "scenario::back_alley_fence_night_exit"
const BUYER_IDENTITY := "scenario::rotating_buyer"
const EXPECTED_CHALLENGE_KEY := "standard|standard|UI-ALL-IN-RESULT|home_archetype_id=back_alley;meta_collection_carried_instance_ids=[];meta_collection_containers=[{ \"id\": \"meta_bag_01\", \"item_id\": \"bag\", \"capacity\": 3, \"items\": [], \"item_definitions\": {  }, \"meta_loadout\": true, \"meta_container_instance_id\": 0 }];meta_collection_enabled=true;meta_collection_loadout=[]"


func _init() -> void:
	var failures: Array[String] = []
	var library = ContentLibraryScript.new()
	library.load(false)
	if library.scenario(SCENARIO_ID).is_empty():
		failures.append("Deferred production content load omitted Fence Night.")
	var run_state = RunStateScript.new()
	run_state.start_new(SEED, _persisted_meta_home_challenge())
	run_state.begin_act(1)
	if RunStateScript.challenge_key(run_state.challenge_config) != EXPECTED_CHALLENGE_KEY:
		failures.append("Focused fixture diverged from the exact persisted production challenge key before generation.")
	var generated = RunGeneratorScript.new(library).next_environment(run_state)
	var environment: Dictionary = run_state.current_environment
	if environment.is_empty() \
			or str(generated.archetype_id) != "back_alley" \
			or str(environment.get("archetype_id", "")) != "back_alley" \
			or str(environment.get("scenario_id", "")) != SCENARIO_ID:
		failures.append("Production generator did not install the persisted-meta Fence Night start room.")
	if run_state.is_terminal() or not bool(environment.get("scenario_semantic_ready", false)):
		failures.append("Production Fence Night install did not remain active with sealed semantic authority.")

	var audit: Dictionary = environment.get("scenario_layout_audit", {}) if typeof(environment.get("scenario_layout_audit", {})) == TYPE_DICTIONARY else {}
	if not bool(audit.get("valid", false)) \
			or int(audit.get("normal_overlap_count", -1)) != 0 \
			or int(audit.get("small_screen_overlap_count", -1)) != 0:
		failures.append("Fence Night did not pass exact normal and expanded small-screen spatial validation.")
	var safe_exit_ids: Array = audit.get("safe_exit_ids", []) if typeof(audit.get("safe_exit_ids", [])) == TYPE_ARRAY else []
	if not safe_exit_ids.has(EXIT_IDENTITY):
		failures.append("Fence Night's required safe exit is absent from sealed reachable layout authority.")
	var authority: Dictionary = environment.get("scenario_layout_authority", {}) if typeof(environment.get("scenario_layout_authority", {})) == TYPE_DICTIONARY else {}
	var exit_authority: Dictionary = authority.get(EXIT_IDENTITY, {}) if typeof(authority.get(EXIT_IDENTITY, {})) == TYPE_DICTIONARY else {}
	if exit_authority.is_empty() \
			or not _valid_rect(exit_authority.get("normalized_hit_rect", {})) \
			or not _valid_rect(exit_authority.get("small_screen_rect", {})):
		failures.append("Fence Night's safe exit lacks exact normal and expanded sealed rectangles.")

	var projection: Dictionary = environment.get("scenario_sequence_projection", {}) if typeof(environment.get("scenario_sequence_projection", {})) == TYPE_DICTIONARY else {}
	var semantic_state: Dictionary = projection.get("semantic_state", {}) if typeof(projection.get("semantic_state", {})) == TYPE_DICTIONARY else {}
	var actors: Dictionary = semantic_state.get("actors", {}) if typeof(semantic_state.get("actors", {})) == TYPE_DICTIONARY else {}
	var buyer: Dictionary = actors.get(BUYER_IDENTITY, {}) if typeof(actors.get(BUYER_IDENTITY, {})) == TYPE_DICTIONARY else {}
	var buyer_route_points: Array = buyer.get("route_points", []) if typeof(buyer.get("route_points", [])) == TYPE_ARRAY else []
	if buyer.is_empty() or not str(buyer.get("route_id", "")).is_empty() or not buyer_route_points.is_empty():
		failures.append("Fence Night's arrival buyer retained the colliding base route authority.")
	var definition: Dictionary = library.scenario(SCENARIO_ID)
	if not _work_phase_moves_buyer_to_service_lane(definition):
		failures.append("Fence Night lost its authored work-phase buyer move to service_lane.")
	if not _cleanup_removes_exit_scene_and_interaction(definition):
		failures.append("Fence Night cleanup does not remove both halves of the sealed exit authority.")

	if failures.is_empty():
		print("BACK_ALLEY_FENCE_NIGHT_INSTALL PASS installed=1 normal=1 small_screen=1 exit=1 route_free=1 work_move=1")
		quit(0)
		return
	for failure in failures:
		printerr("BACK_ALLEY_FENCE_NIGHT_INSTALL FAIL: %s" % failure)
	quit(1)


func _persisted_meta_home_challenge() -> Dictionary:
	return {
		"daily_id": "",
		"hidden_seed": false,
		"id": "standard",
		"mode": "standard",
		"modifiers": {
			"home_archetype_id": "back_alley",
			"meta_collection_carried_instance_ids": [],
			"meta_collection_containers": [{
				"id": "meta_bag_01",
				"item_id": "bag",
				"capacity": 3,
				"items": [],
				"item_definitions": {},
				"meta_loadout": true,
				"meta_container_instance_id": 0,
			}],
			"meta_collection_enabled": true,
			"meta_collection_loadout": [],
		},
		"seed_text": SEED,
	}


func _valid_rect(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var rect: Dictionary = value
	return float(rect.get("w", 0.0)) > 0.0 and float(rect.get("h", 0.0)) > 0.0


func _work_phase_moves_buyer_to_service_lane(definition: Dictionary) -> bool:
	var sequence: Dictionary = definition.get("sequence", {}) if typeof(definition.get("sequence", {})) == TYPE_DICTIONARY else {}
	var graph: Dictionary = sequence.get("phase_graph", {}) if typeof(sequence.get("phase_graph", {})) == TYPE_DICTIONARY else {}
	for phase_value in graph.get("phases", []):
		if typeof(phase_value) != TYPE_DICTIONARY:
			continue
		var phase: Dictionary = phase_value
		if str(phase.get("id", "")) != "work":
			continue
		for operation_value in phase.get("actor_ops", []):
			if typeof(operation_value) == TYPE_DICTIONARY \
					and str((operation_value as Dictionary).get("op", "")) == "set_position" \
					and str((operation_value as Dictionary).get("stable_object_id", "")) == "rotating_buyer" \
					and str((operation_value as Dictionary).get("zone_id", "")) == "service_lane":
				return true
	return false


func _cleanup_removes_exit_scene_and_interaction(definition: Dictionary) -> bool:
	var sequence: Dictionary = definition.get("sequence", {}) if typeof(definition.get("sequence", {})) == TYPE_DICTIONARY else {}
	var cleanup: Dictionary = sequence.get("cleanup", {}) if typeof(sequence.get("cleanup", {})) == TYPE_DICTIONARY else {}
	var scene_removed := false
	var interaction_removed := false
	for operation_value in cleanup.get("operations", []):
		if typeof(operation_value) != TYPE_DICTIONARY:
			continue
		var operation: Dictionary = operation_value
		if str(operation.get("op", "")) != "remove" or str(operation.get("stable_object_id", "")) != "back_alley_fence_night_exit":
			continue
		scene_removed = scene_removed or str(operation.get("family", "")) == "scene_ops"
		interaction_removed = interaction_removed or str(operation.get("family", "")) == "interaction_ops"
	return scene_removed and interaction_removed
