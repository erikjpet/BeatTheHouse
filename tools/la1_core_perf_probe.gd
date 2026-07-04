extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")
const CardShoeScript := preload("res://scripts/core/card_shoe.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")

const DEFAULT_REPORT_PATH := "res://.tmp/la1_core_perf_probe/report.json"

var report_path := DEFAULT_REPORT_PATH


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg_value in OS.get_cmdline_user_args():
		var arg := str(arg_value)
		if arg.begins_with("--report="):
			report_path = arg.substr("--report=".length())

	var library: ContentLibrary = ContentLibraryScript.new()
	var load_started := Time.get_ticks_usec()
	var load_report := library.load()
	var load_usec := Time.get_ticks_usec() - load_started
	var failures: Array = []
	if load_report.is_empty() or not library.validation_errors.is_empty():
		failures.append("ContentLibrary load failed: %s" % str(load_report))
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("LA1-CORE-PERF")
	var generator: RunGenerator = RunGeneratorScript.new(library)
	generator.next_environment(run_state)
	_prepare_world_map(run_state)
	var action_service: RunActionService = RunActionServiceScript.new()
	action_service.setup(library, run_state)

	var observations := {}
	observations["content_library_load"] = _observation_from_single(load_usec)
	print("LA1_PROBE_STEP content_library_lookup_mix")
	observations["content_library_lookup_mix"] = _measure_content_lookup(library, 5000)
	print("LA1_PROBE_STEP run_state_to_dict")
	observations["run_state_to_dict"] = _measure_run_state_to_dict(run_state, 60)
	print("LA1_PROBE_STEP run_state_to_json")
	observations["run_state_to_json"] = _measure_run_state_to_json(run_state, 30)
	print("LA1_PROBE_STEP save_service_save_run")
	observations["save_service_save_run"] = _measure_save_run(run_state, 6)
	print("LA1_PROBE_STEP world_map_travel_target_ids")
	observations["world_map_travel_target_ids"] = _measure_world_targets(run_state, 3)
	print("LA1_PROBE_STEP world_map_snapshot")
	observations["world_map_snapshot"] = _measure_world_snapshot(run_state, 60)
	print("LA1_PROBE_STEP run_action_service_views")
	observations["run_action_service_views"] = _measure_action_views(action_service, 240)
	print("LA1_PROBE_STEP card_shoe_draw_cards")
	observations["card_shoe_draw_cards"] = _measure_card_draws(400)
	print("LA1_PROBE_STEP card_shoe_remaining_count")
	observations["card_shoe_remaining_count"] = _measure_card_remaining_count(1000)
	print("LA1_PROBE_STEP card_shoe_remaining_composition")
	observations["card_shoe_remaining_composition"] = _measure_card_remaining_composition(400)
	print("LA1_PROBE_STEP rng_stream_draws")
	observations["rng_stream_draws"] = _measure_rng_draws(20000)
	print("LA1_PROBE_STEP rng_stream_forks")
	observations["rng_stream_forks"] = _measure_rng_forks(3000)
	var report := {
		"tool": "la1_core_perf_probe",
		"observations": observations,
		"failures": failures,
		"failure_count": failures.size(),
		"passed": failures.is_empty(),
	}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print(JSON.stringify(report, "\t"))
	if failures.is_empty():
		quit(0)
	else:
		quit(1)


func _prepare_world_map(run_state: RunState) -> void:
	var ids: Array = []
	for node_value in run_state.world_map.get("nodes", []):
		if typeof(node_value) == TYPE_DICTIONARY:
			var node: Dictionary = node_value
			var node_id := str(node.get("id", "")).strip_edges()
			if not node_id.is_empty():
				ids.append(node_id)
	run_state.world_map = WorldMapScript.unlock_nodes(run_state.world_map, ids)


func _measure_content_lookup(library: ContentLibrary, reps: int) -> Dictionary:
	var ids := ["blackjack", "slot", "basic_strategy_card", "parking_lot_tip", "cash_advance"]
	var started := Time.get_ticks_usec()
	for index in range(reps):
		match index % ids.size():
			0:
				library.game(str(ids[index % ids.size()]))
			1:
				library.item(str(ids[index % ids.size()]))
			2:
				library.event(str(ids[index % ids.size()]))
			3:
				library.service(str(ids[index % ids.size()]))
			_:
				library.lender(str(ids[index % ids.size()]))
	return _observation(started, reps)


func _measure_run_state_to_dict(run_state: RunState, reps: int) -> Dictionary:
	var started := Time.get_ticks_usec()
	var size_sum := 0
	for _index in range(reps):
		size_sum += run_state.to_dict().size()
	var result := _observation(started, reps)
	result["size_sum"] = size_sum
	return result


func _measure_run_state_to_json(run_state: RunState, reps: int) -> Dictionary:
	var started := Time.get_ticks_usec()
	var byte_sum := 0
	for _index in range(reps):
		byte_sum += JSON.stringify(run_state.to_dict()).length()
	var result := _observation(started, reps)
	result["byte_sum"] = byte_sum
	return result


func _measure_save_run(run_state: RunState, reps: int) -> Dictionary:
	var service: SaveService = SaveServiceScript.new()
	var started := Time.get_ticks_usec()
	var error_count := 0
	for index in range(reps):
		var error := service.save_run(run_state, "la1_core_perf_%d" % index)
		if error != OK:
			error_count += 1
	var result := _observation(started, reps)
	result["error_count"] = error_count
	return result


func _measure_world_targets(run_state: RunState, reps: int) -> Dictionary:
	var source_id := run_state.current_world_node_id()
	var started := Time.get_ticks_usec()
	var count_sum := 0
	for _index in range(reps):
		count_sum += WorldMapScript.travel_target_ids(run_state.world_map, source_id).size()
	var result := _observation(started, reps)
	result["count_sum"] = count_sum
	return result


func _measure_world_snapshot(run_state: RunState, reps: int) -> Dictionary:
	var source_id := run_state.current_world_node_id()
	var started := Time.get_ticks_usec()
	var count_sum := 0
	for _index in range(reps):
		var snapshot := WorldMapScript.snapshot(run_state.world_map, source_id)
		count_sum += int((snapshot.get("nodes", []) as Array).size())
	var result := _observation(started, reps)
	result["count_sum"] = count_sum
	return result


func _measure_action_views(service: RunActionService, reps: int) -> Dictionary:
	var started := Time.get_ticks_usec()
	var count_sum := 0
	for _index in range(reps):
		count_sum += service.item_offer_view_list().size()
		count_sum += service.inventory_item_view_list().size()
		count_sum += service.service_hook_view_list().size()
		count_sum += service.lender_hook_view_list().size()
	return _observation_with_sum(started, reps, count_sum)


func _measure_card_draws(reps: int) -> Dictionary:
	var rng: RngStream = RngStreamScript.new()
	rng.configure(31031)
	var shoe: Array = CardShoeScript.build_shoe(6, rng)
	var started := Time.get_ticks_usec()
	var count_sum := 0
	for _index in range(reps):
		var result: Dictionary = CardShoeScript.draw_cards(shoe, 2)
		count_sum += int(result.get("remaining", 0))
	return _observation_with_sum(started, reps, count_sum)


func _measure_card_remaining_count(reps: int) -> Dictionary:
	var rng: RngStream = RngStreamScript.new()
	rng.configure(9981)
	var shoe: Array = CardShoeScript.build_shoe(6, rng)
	var started := Time.get_ticks_usec()
	var count_sum := 0
	for _index in range(reps):
		count_sum += CardShoeScript.remaining_count(shoe)
	return _observation_with_sum(started, reps, count_sum)


func _measure_card_remaining_composition(reps: int) -> Dictionary:
	var rng: RngStream = RngStreamScript.new()
	rng.configure(4411)
	var shoe: Array = CardShoeScript.build_shoe(6, rng)
	var started := Time.get_ticks_usec()
	var count_sum := 0
	for _index in range(reps):
		var composition: Dictionary = CardShoeScript.remaining_composition(shoe)
		count_sum += int(composition.get("total", 0))
	return _observation_with_sum(started, reps, count_sum)


func _measure_rng_draws(reps: int) -> Dictionary:
	var rng: RngStream = RngStreamScript.new()
	rng.configure(77117)
	var started := Time.get_ticks_usec()
	var total := 0
	for _index in range(reps):
		total += rng.randi_range(1, 100)
	return _observation_with_sum(started, reps, total)


func _measure_rng_forks(reps: int) -> Dictionary:
	var rng: RngStream = RngStreamScript.new()
	rng.configure(88117)
	var started := Time.get_ticks_usec()
	var total := 0
	for index in range(reps):
		total += rng.fork("la1:%d" % index).randi_range(1, 100)
	return _observation_with_sum(started, reps, total)


func _observation_from_single(usec: int) -> Dictionary:
	return {
		"reps": 1,
		"total_usec": usec,
		"avg_usec": float(usec),
		"avg_ms": float(usec) / 1000.0,
	}


func _observation(started_usec: int, reps: int) -> Dictionary:
	var total_usec := Time.get_ticks_usec() - started_usec
	return {
		"reps": reps,
		"total_usec": total_usec,
		"avg_usec": float(total_usec) / float(maxi(1, reps)),
		"avg_ms": (float(total_usec) / float(maxi(1, reps))) / 1000.0,
	}


func _observation_with_sum(started_usec: int, reps: int, count_sum: int) -> Dictionary:
	var result := _observation(started_usec, reps)
	result["count_sum"] = count_sum
	return result
