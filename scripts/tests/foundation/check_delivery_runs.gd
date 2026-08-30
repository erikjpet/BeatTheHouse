extends "res://scripts/tests/foundation/check_items_events_world.gd"

const DeliveryRunModelTestScript := preload("res://scripts/core/delivery_run_model.gd")
const DeliveryWorldMapTestScript := preload("res://scripts/core/world_map.gd")
# SHA-256 of canonical [target_id, path] arrays captured from the public
# WorldMap.path_between implementation at integration baseline 6523054b.
# Entry order: all, visible, hidden-source all, hidden-source visible.
const DELIVERY_PATH_COMPAT_SHA256 := {
	"DELIVERY-PROPERTY-00": ["8dd3f440291825d7fdeb5dafbd9dabbbd812f5f2cc18449c75512bfc7b2f36b3", "bbaac96850c406c7d2f1a72b2b82a8158a7fb4442048f9abebd09775117ee082", "d438edd91519497fe320c5a1da17f12ebb6915af9472d1837144b4ac05da25ce", "8cd7847d0aaaa81432ddb44d88496eb40b66a5a40f09c38f2d51626dbf19f5de"],
	"DELIVERY-PROPERTY-01": ["702aa2a62d5ba00d42bb63bd6843f89e953e9559efdbfc51902faffef9ad6b5e", "e3f3f3eea4b2a12c4ea7602140c7dc4d798ee803631d2c1131be8a372c9e005d", "7cfd3f882dffb1787c13fc3e8a1c64dc36d654011d7a5e7111cc767b079deabe", "e59809e480c9a123899786d48ce71cdaf1657dab328ea96f21912fed238ede2d"],
	"DELIVERY-PROPERTY-02": ["702aa2a62d5ba00d42bb63bd6843f89e953e9559efdbfc51902faffef9ad6b5e", "e3f3f3eea4b2a12c4ea7602140c7dc4d798ee803631d2c1131be8a372c9e005d", "7cfd3f882dffb1787c13fc3e8a1c64dc36d654011d7a5e7111cc767b079deabe", "e59809e480c9a123899786d48ce71cdaf1657dab328ea96f21912fed238ede2d"],
	"DELIVERY-PROPERTY-03": ["702aa2a62d5ba00d42bb63bd6843f89e953e9559efdbfc51902faffef9ad6b5e", "e3f3f3eea4b2a12c4ea7602140c7dc4d798ee803631d2c1131be8a372c9e005d", "7cfd3f882dffb1787c13fc3e8a1c64dc36d654011d7a5e7111cc767b079deabe", "e59809e480c9a123899786d48ce71cdaf1657dab328ea96f21912fed238ede2d"],
	"DELIVERY-PROPERTY-04": ["047c51f66440cc9ac35a5994bf6bb60a73336af842d7f0080832476c6cb5c2a1", "0ec74c2514acf700c0413424188a65cc4be446f9d204fe5318fb33cc47943fb8", "a456f590c93b64ab4aefc9c226b4792241154b18bf51e7d39a613d84e5ada9ff", "c50d4e44675a199ed20522ae7186e05b1f95cb42443320578e57bcb69399d192"],
	"DELIVERY-PROPERTY-05": ["702aa2a62d5ba00d42bb63bd6843f89e953e9559efdbfc51902faffef9ad6b5e", "e3f3f3eea4b2a12c4ea7602140c7dc4d798ee803631d2c1131be8a372c9e005d", "7cfd3f882dffb1787c13fc3e8a1c64dc36d654011d7a5e7111cc767b079deabe", "e59809e480c9a123899786d48ce71cdaf1657dab328ea96f21912fed238ede2d"],
	"DELIVERY-PROPERTY-06": ["702aa2a62d5ba00d42bb63bd6843f89e953e9559efdbfc51902faffef9ad6b5e", "e3f3f3eea4b2a12c4ea7602140c7dc4d798ee803631d2c1131be8a372c9e005d", "7cfd3f882dffb1787c13fc3e8a1c64dc36d654011d7a5e7111cc767b079deabe", "e59809e480c9a123899786d48ce71cdaf1657dab328ea96f21912fed238ede2d"],
	"DELIVERY-PROPERTY-07": ["8dd3f440291825d7fdeb5dafbd9dabbbd812f5f2cc18449c75512bfc7b2f36b3", "bbaac96850c406c7d2f1a72b2b82a8158a7fb4442048f9abebd09775117ee082", "d438edd91519497fe320c5a1da17f12ebb6915af9472d1837144b4ac05da25ce", "8cd7847d0aaaa81432ddb44d88496eb40b66a5a40f09c38f2d51626dbf19f5de"],
	"DELIVERY-PROPERTY-08": ["8dd3f440291825d7fdeb5dafbd9dabbbd812f5f2cc18449c75512bfc7b2f36b3", "bbaac96850c406c7d2f1a72b2b82a8158a7fb4442048f9abebd09775117ee082", "d438edd91519497fe320c5a1da17f12ebb6915af9472d1837144b4ac05da25ce", "8cd7847d0aaaa81432ddb44d88496eb40b66a5a40f09c38f2d51626dbf19f5de"],
	"DELIVERY-PROPERTY-09": ["8dd3f440291825d7fdeb5dafbd9dabbbd812f5f2cc18449c75512bfc7b2f36b3", "bbaac96850c406c7d2f1a72b2b82a8158a7fb4442048f9abebd09775117ee082", "d438edd91519497fe320c5a1da17f12ebb6915af9472d1837144b4ac05da25ce", "8cd7847d0aaaa81432ddb44d88496eb40b66a5a40f09c38f2d51626dbf19f5de"],
	"DELIVERY-PROPERTY-10": ["047c51f66440cc9ac35a5994bf6bb60a73336af842d7f0080832476c6cb5c2a1", "0ec74c2514acf700c0413424188a65cc4be446f9d204fe5318fb33cc47943fb8", "8dd63a0d61962fad6397407d9fe07aa4208fc6f33dbf04172d6349309412ff10", "af65cee6fe1ae77a42a4da7dd4226ac6ff4bcc0758622633eba70db137b8acba"],
	"DELIVERY-PROPERTY-11": ["8dd3f440291825d7fdeb5dafbd9dabbbd812f5f2cc18449c75512bfc7b2f36b3", "bbaac96850c406c7d2f1a72b2b82a8158a7fb4442048f9abebd09775117ee082", "d438edd91519497fe320c5a1da17f12ebb6915af9472d1837144b4ac05da25ce", "8cd7847d0aaaa81432ddb44d88496eb40b66a5a40f09c38f2d51626dbf19f5de"],
	"DELIVERY-PROPERTY-12": ["047c51f66440cc9ac35a5994bf6bb60a73336af842d7f0080832476c6cb5c2a1", "0ec74c2514acf700c0413424188a65cc4be446f9d204fe5318fb33cc47943fb8", "8dd63a0d61962fad6397407d9fe07aa4208fc6f33dbf04172d6349309412ff10", "af65cee6fe1ae77a42a4da7dd4226ac6ff4bcc0758622633eba70db137b8acba"],
	"DELIVERY-PROPERTY-13": ["8dd3f440291825d7fdeb5dafbd9dabbbd812f5f2cc18449c75512bfc7b2f36b3", "bbaac96850c406c7d2f1a72b2b82a8158a7fb4442048f9abebd09775117ee082", "d438edd91519497fe320c5a1da17f12ebb6915af9472d1837144b4ac05da25ce", "8cd7847d0aaaa81432ddb44d88496eb40b66a5a40f09c38f2d51626dbf19f5de"],
	"DELIVERY-PROPERTY-14": ["047c51f66440cc9ac35a5994bf6bb60a73336af842d7f0080832476c6cb5c2a1", "0ec74c2514acf700c0413424188a65cc4be446f9d204fe5318fb33cc47943fb8", "8dd63a0d61962fad6397407d9fe07aa4208fc6f33dbf04172d6349309412ff10", "af65cee6fe1ae77a42a4da7dd4226ac6ff4bcc0758622633eba70db137b8acba"],
	"DELIVERY-PROPERTY-15": ["047c51f66440cc9ac35a5994bf6bb60a73336af842d7f0080832476c6cb5c2a1", "0ec74c2514acf700c0413424188a65cc4be446f9d204fe5318fb33cc47943fb8", "8dd63a0d61962fad6397407d9fe07aa4208fc6f33dbf04172d6349309412ff10", "af65cee6fe1ae77a42a4da7dd4226ac6ff4bcc0758622633eba70db137b8acba"],
	"DELIVERY-PROPERTY-16": ["702aa2a62d5ba00d42bb63bd6843f89e953e9559efdbfc51902faffef9ad6b5e", "e3f3f3eea4b2a12c4ea7602140c7dc4d798ee803631d2c1131be8a372c9e005d", "7cfd3f882dffb1787c13fc3e8a1c64dc36d654011d7a5e7111cc767b079deabe", "e59809e480c9a123899786d48ce71cdaf1657dab328ea96f21912fed238ede2d"],
	"DELIVERY-PROPERTY-17": ["702aa2a62d5ba00d42bb63bd6843f89e953e9559efdbfc51902faffef9ad6b5e", "e3f3f3eea4b2a12c4ea7602140c7dc4d798ee803631d2c1131be8a372c9e005d", "7cfd3f882dffb1787c13fc3e8a1c64dc36d654011d7a5e7111cc767b079deabe", "e59809e480c9a123899786d48ce71cdaf1657dab328ea96f21912fed238ede2d"],
	"DELIVERY-PROPERTY-18": ["702aa2a62d5ba00d42bb63bd6843f89e953e9559efdbfc51902faffef9ad6b5e", "e3f3f3eea4b2a12c4ea7602140c7dc4d798ee803631d2c1131be8a372c9e005d", "7cfd3f882dffb1787c13fc3e8a1c64dc36d654011d7a5e7111cc767b079deabe", "e59809e480c9a123899786d48ce71cdaf1657dab328ea96f21912fed238ede2d"],
	"DELIVERY-PROPERTY-19": ["9e3cb7201b39af731c589534be55edbe768f6024cc564f8aaebf337871041670", "e3f3f3eea4b2a12c4ea7602140c7dc4d798ee803631d2c1131be8a372c9e005d", "7cfd3f882dffb1787c13fc3e8a1c64dc36d654011d7a5e7111cc767b079deabe", "e59809e480c9a123899786d48ce71cdaf1657dab328ea96f21912fed238ede2d"],
}
const DELIVERY_PATH_PUBLIC_SPOT_SEEDS := [
	"DELIVERY-PROPERTY-00",
	"DELIVERY-PROPERTY-01",
	"DELIVERY-PROPERTY-04",
	"DELIVERY-PROPERTY-10",
	"DELIVERY-PROPERTY-19",
]

var delivery_test_library: ContentLibrary


func _check_delivery_framework(library: ContentLibrary, failures: Array) -> void:
	delivery_test_library = library
	_check_delivery_target_properties(library, failures)
	_check_delivery_modes(failures)
	_check_delivery_no_soft_lock_worst_cases(failures)
	_check_delivery_sweep_and_map_intel(failures)
	_check_delivery_save_and_migration(failures)
	_check_delivery_ordinary_travel_identity(failures)


func _check_delivery_target_properties(library: ContentLibrary, failures: Array) -> void:
	var pre_generation: RunState = RunStateScript.new()
	pre_generation.start_new("DELIVERY-PRE-GENERATION")
	var rejected := pre_generation.delivery_begin_package({"run_id": "too_early"})
	if bool(rejected.get("ok", false)) or str(rejected.get("message", "")).is_empty() or pre_generation.delivery_has_active_run():
		failures.append("Delivery begin did not reject a pre-generation run cleanly.")
	var saw_unvisited_target := false
	for seed_index in range(20):
		var seed := "DELIVERY-PROPERTY-%02d" % seed_index
		var first := _delivery_map_only_test_run(seed, false)
		_check_prepared_path_query_equivalence(first.world_map, seed, failures)
		var twin := _delivery_selection_twin(first, seed)
		var first_start := first.delivery_begin_multi_stop({"run_id": "property", "target_count": 3, "deadline_actions": 20})
		var twin_start := twin.delivery_begin_multi_stop({"run_id": "property", "target_count": 3, "deadline_actions": 20})
		if not bool(first_start.get("ok", false)) or JSON.stringify(first.delivery_snapshot()) != JSON.stringify(twin.delivery_snapshot()):
			failures.append("Delivery target selection was unavailable or nondeterministic for seed %s: first=%s twin=%s first_map=%s twin_map=%s." % [seed, JSON.stringify(first_start), JSON.stringify(twin_start), str(first.has_world_map()), str(twin.has_world_map())])
			continue
		for target_value in first.delivery_snapshot().get("targets", []):
			if typeof(target_value) != TYPE_DICTIONARY:
				failures.append("Delivery target selection emitted a non-dictionary target for seed %s." % seed)
				continue
			var target: Dictionary = target_value
			var node_id := str(target.get("node_id", ""))
			var node := DeliveryWorldMapTestScript.node_metadata_by_id(first.world_map, node_id)
			var route := DeliveryWorldMapTestScript.path_between(first.world_map, first.current_world_node_id(), node_id, true)
			if node.is_empty() or str(node.get("archetype_id", "")).is_empty() or str(node.get("kind", "")).is_empty() \
				or library.environment_archetype(str(node.get("archetype_id", ""))).is_empty() or route.is_empty():
				failures.append("Delivery offered a synthetic, ungeneratable, or unreachable target %s for seed %s." % [node_id, seed])
				continue
			for path_index in range(route.size() - 1):
				if DeliveryWorldMapTestScript.edge_between(first.world_map, str(route[path_index]), str(route[path_index + 1])).is_empty():
					failures.append("Delivery route to %s contains a synthetic edge for seed %s." % [node_id, seed])
			if bool(target.get("revealed_by_job", false)):
				saw_unvisited_target = true
				if str(node.get("state", "")) == DeliveryWorldMapTestScript.STATE_HIDDEN or str(target.get("label", "")).is_empty():
					failures.append("Delivery did not reveal an unseen target with its real identity for seed %s." % seed)
	var unseen_run := _delivery_map_only_test_run("DELIVERY-EXPLICIT-UNSEEN", false)
	var unseen_target_id := ""
	for node_value in unseen_run.world_map.get("nodes", []):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if str(node.get("state", "")) == DeliveryWorldMapTestScript.STATE_HIDDEN \
			and DeliveryWorldMapTestScript.has_path(unseen_run.world_map, unseen_run.current_world_node_id(), node_id, false):
			unseen_target_id = node_id
			break
	if not unseen_target_id.is_empty():
		var unseen_started := unseen_run.delivery_begin_package({"run_id": "explicit_unseen", "targets": [{"node_id": unseen_target_id}], "deadline_actions": 12})
		var unseen_target: Dictionary = (unseen_run.delivery_snapshot().get("targets", []) as Array)[0] if bool(unseen_started.get("ok", false)) else {}
		var unseen_node := DeliveryWorldMapTestScript.node_metadata_by_id(unseen_run.world_map, unseen_target_id)
		saw_unvisited_target = bool(unseen_started.get("ok", false)) and bool(unseen_target.get("revealed_by_job", false)) \
			and str(unseen_node.get("state", "")) != DeliveryWorldMapTestScript.STATE_HIDDEN
	if not saw_unvisited_target:
		failures.append("Delivery property sweep never proved an unseen real-map target reveal.")

	var preference_run := _delivery_map_only_test_run("DELIVERY-VISITED-PREFERENCE", false)
	var preference_origin := preference_run.current_world_node_id()
	var discovered_ids := DeliveryWorldMapTestScript.travel_target_ids(preference_run.world_map, preference_origin)
	if discovered_ids.is_empty():
		failures.append("Visited-preference fixture had no discovered destination.")
	else:
		var visited_id := str(discovered_ids[0])
		preference_run.world_map = DeliveryWorldMapTestScript.enter_node(preference_run.world_map, visited_id, {})
		preference_run.world_map = DeliveryWorldMapTestScript.enter_node(preference_run.world_map, preference_origin, {})
		var has_unvisited_candidate := false
		for node_value in preference_run.world_map.get("nodes", []):
			if typeof(node_value) != TYPE_DICTIONARY:
				continue
			var node: Dictionary = node_value
			var node_id := str(node.get("id", ""))
			if node_id != preference_origin and node_id != visited_id and str(node.get("state", "hidden")) != DeliveryWorldMapTestScript.STATE_VISITED \
				and DeliveryWorldMapTestScript.has_path(preference_run.world_map, preference_origin, node_id, false):
				has_unvisited_candidate = true
				break
		var preferred := preference_run.delivery_begin_package({"run_id": "visited_preference", "deadline_actions": 8})
		var preferred_target: Dictionary = (preference_run.delivery_snapshot().get("targets", []) as Array)[0] if bool(preferred.get("ok", false)) else {}
		if not has_unvisited_candidate or str(preferred_target.get("node_id", "")) != visited_id or not bool(preferred_target.get("was_visited_at_offer", false)):
			failures.append("Delivery did not prefer the visited real node when visited and unvisited candidates coexisted.")


func _check_prepared_path_query_equivalence(map_data: Dictionary, seed: String, failures: Array) -> void:
	var source_id := DeliveryWorldMapTestScript.current_node_id(map_data)
	var all_node_ids: Array = []
	var hidden_source_id := ""
	for node_value in map_data.get("nodes", []):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node_id := str((node_value as Dictionary).get("id", "")).strip_edges()
		if not node_id.is_empty():
			all_node_ids.append(node_id)
			if hidden_source_id.is_empty() and str((node_value as Dictionary).get("state", "hidden")) == DeliveryWorldMapTestScript.STATE_HIDDEN:
				hidden_source_id = node_id
	all_node_ids.sort()
	if not all_node_ids.has(source_id):
		all_node_ids.append(source_id)
	var payload_map := map_data.duplicate(true)
	var payload_nodes: Array = payload_map.get("nodes", [])
	if not payload_nodes.is_empty() and typeof(payload_nodes[0]) == TYPE_DICTIONARY:
		var payload_node: Dictionary = payload_nodes[0]
		payload_node["environment"] = {"delivery_query_sentinel": {"seed": seed, "values": [3, 1, 4]}}
		payload_nodes[0] = payload_node
		payload_map["nodes"] = payload_nodes
	var before := JSON.stringify(payload_map)
	var expected_value: Variant = DELIVERY_PATH_COMPAT_SHA256.get(seed, [])
	if typeof(expected_value) != TYPE_ARRAY or (expected_value as Array).size() != 4:
		failures.append("Prepared path query has no 6523054b compatibility golden for seed %s." % seed)
		return
	var expected: Array = expected_value
	for visible_only in [false, true]:
		var query := DeliveryWorldMapTestScript.prepare_path_query(payload_map, source_id, visible_only)
		if JSON.stringify(payload_map) != before:
			failures.append("Prepared path query mutated map/environment payloads for seed %s visible=%s." % [seed, str(visible_only)])
		var serialized_query := JSON.stringify(query)
		if serialized_query.contains("\"environment\"") or serialized_query.contains("delivery_query_sentinel"):
			failures.append("Prepared path query retained an environment payload for seed %s visible=%s." % [seed, str(visible_only)])
		var digest := _delivery_prepared_path_digest(query, all_node_ids)
		var expected_digest := str(expected[1 if visible_only else 0])
		if digest != expected_digest:
			failures.append("Prepared all-node paths differ from 6523054b for seed %s visible=%s: actual=%s expected=%s." % [seed, str(visible_only), digest, expected_digest])
		for target_id_value in all_node_ids:
			var target_id := str(target_id_value)
			var batch_path := DeliveryWorldMapTestScript.prepared_path(query, target_id)
			var expected_real := _delivery_test_path_uses_real_edges(payload_map, batch_path)
			if DeliveryWorldMapTestScript.prepared_path_uses_real_edges(query, batch_path) != expected_real:
				failures.append("Prepared real-edge legality differs for seed %s visible=%s source=%s target=%s." % [seed, str(visible_only), source_id, target_id])
		if DELIVERY_PATH_PUBLIC_SPOT_SEEDS.has(seed):
			var spot_target := hidden_source_id if not hidden_source_id.is_empty() else str(all_node_ids[0])
			for spot_id in [source_id, spot_target]:
				var public_path := DeliveryWorldMapTestScript.path_between(payload_map, source_id, spot_id, visible_only)
				if JSON.stringify(DeliveryWorldMapTestScript.prepared_path(query, spot_id)) != JSON.stringify(public_path):
					failures.append("Prepared path lost public path_between linkage for seed %s visible=%s target=%s." % [seed, str(visible_only), spot_id])
	if not hidden_source_id.is_empty():
		var hidden_targets: Array = [hidden_source_id, source_id]
		for visible_only in [false, true]:
			var hidden_query := DeliveryWorldMapTestScript.prepare_path_query(payload_map, hidden_source_id, visible_only)
			var hidden_digest := _delivery_prepared_path_digest(hidden_query, hidden_targets)
			var expected_hidden_digest := str(expected[3 if visible_only else 2])
			if hidden_digest != expected_hidden_digest:
				failures.append("Prepared hidden-source paths differ from 6523054b for seed %s visible=%s: actual=%s expected=%s." % [seed, str(visible_only), hidden_digest, expected_hidden_digest])
			if DELIVERY_PATH_PUBLIC_SPOT_SEEDS.has(seed):
				var public_singleton := DeliveryWorldMapTestScript.path_between(payload_map, hidden_source_id, hidden_source_id, visible_only)
				if JSON.stringify(DeliveryWorldMapTestScript.prepared_path(hidden_query, hidden_source_id)) != JSON.stringify(public_singleton):
					failures.append("Prepared hidden-source singleton lost public path_between linkage for seed %s visible=%s." % [seed, str(visible_only)])
	else:
		failures.append("Prepared path compatibility fixture has no hidden source for seed %s." % seed)
	if JSON.stringify(payload_map) != before:
		failures.append("Prepared path query/accessors leaked a mutation into the source map for seed %s." % seed)


func _delivery_prepared_path_digest(query: Dictionary, target_ids: Array) -> String:
	var canonical: Array = []
	for target_id_value in target_ids:
		var target_id := str(target_id_value)
		canonical.append([target_id, DeliveryWorldMapTestScript.prepared_path(query, target_id)])
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(canonical).to_utf8_buffer())
	return context.finish().hex_encode()


func _delivery_test_path_uses_real_edges(map_data: Dictionary, path: Array) -> bool:
	if path.size() == 1:
		return true
	for path_index in range(path.size() - 1):
		if DeliveryWorldMapTestScript.edge_between(map_data, str(path[path_index]), str(path[path_index + 1])).is_empty():
			return false
	return path.size() >= 2


func _check_delivery_modes(failures: Array) -> void:
	var package_run := _delivery_test_run("DELIVERY-PACKAGE")
	var package_start := package_run.delivery_begin_package({"run_id": "package", "deadline_actions": 8})
	if not bool(package_start.get("ok", false)) or not _delivery_complete_all_targets(package_run):
		failures.append("Package delivery did not complete through a real-room handoff: start=%s snapshot=%s." % [JSON.stringify(package_start), JSON.stringify(package_run.delivery_snapshot())])
	elif str((package_run.delivery_snapshot().get("resolution", {}) as Dictionary).get("outcome", "")) != "success":
		failures.append("Package delivery did not resolve success after its handoff.")

	var multi_run := _delivery_test_run("DELIVERY-MULTI")
	var multi_start := multi_run.delivery_begin_multi_stop({"run_id": "multi", "target_count": 3, "deadline_actions": 16})
	if not bool(multi_start.get("ok", false)) or not _delivery_complete_all_targets(multi_run):
		failures.append("Multi-stop delivery did not complete every real-room handoff.")
	elif int(multi_run.delivery_snapshot().get("delivered_count", 0)) != 3:
		failures.append("Multi-stop delivery lost stop progress.")
	var failed_multi := _delivery_test_run("DELIVERY-MULTI-FAILURE")
	var failed_multi_start := failed_multi.delivery_begin_multi_stop({"run_id": "multi_failure", "target_count": 2, "deadline_actions": 1})
	failed_multi.advance_environment_turns(1)
	if not bool(failed_multi_start.get("ok", false)) or failed_multi.delivery_has_active_run() \
		or str((failed_multi.delivery_snapshot().get("resolution", {}) as Dictionary).get("reason", "")) != "deadline" \
		or int(failed_multi.delivery_snapshot().get("delivered_count", -1)) != 0:
		failures.append("Multi-stop deadline failure did not resolve every pending stop cleanly.")

	var deadline_run := _delivery_test_run("DELIVERY-DEADLINE")
	deadline_run.delivery_begin_package({"run_id": "deadline", "deadline_actions": 1})
	var deadline_target := _delivery_first_target(deadline_run)
	_delivery_enter_node(deadline_run, deadline_target)
	if deadline_run.delivery_has_active_run() or str((deadline_run.delivery_snapshot().get("resolution", {}) as Dictionary).get("reason", "")) != "deadline":
		failures.append("A deadline expiring during travel did not fail cleanly without blocking the arrival.")

	var hold_run := _delivery_test_run("DELIVERY-HOLD")
	var hold_node := hold_run.current_world_node_id()
	var hold_start := hold_run.delivery_begin_hold({"run_id": "hold", "targets": [{"node_id": hold_node}], "deadline_actions": 6, "hold_required_actions": 2, "hold_attention_limit": 100})
	if not bool(hold_start.get("ok", false)):
		failures.append("Hold mode could not bind to the current real venue.")
	else:
		hold_run.advance_environment_turns(2)
		if hold_run.delivery_has_active_run() or str((hold_run.delivery_snapshot().get("resolution", {}) as Dictionary).get("reason", "")) != "held_window":
			failures.append("Hold mode did not resolve against real-venue action boundaries.")
	var hot_hold := _delivery_test_run("DELIVERY-HOLD-ATTENTION")
	hot_hold.add_suspicion("fixture", 90, "test", false)
	hot_hold.delivery_begin_hold({"run_id": "hot_hold", "targets": [{"node_id": hot_hold.current_world_node_id()}], "deadline_actions": 6, "hold_required_actions": 2, "hold_attention_limit": 40})
	hot_hold.advance_environment_turns(1)
	if hot_hold.delivery_has_active_run() or str((hot_hold.delivery_snapshot().get("resolution", {}) as Dictionary).get("reason", "")) != "attention":
		failures.append("Hold mode did not fail when existing attention exceeded its condition.")

	var getaway_run := _delivery_test_run("DELIVERY-GETAWAY")
	var getaway_start := getaway_run.delivery_begin_getaway({"run_id": "getaway", "enabled": true, "deadline_actions": 8, "assists": ["rook_cutoff"], "pursuit_pressure": 4, "assist_relief": 3})
	if not bool(getaway_start.get("ok", false)):
		failures.append("Flagged getaway test harness could not start on the real map.")
	else:
		var pressure_before := int(getaway_run.delivery_snapshot().get("pursuit_pressure", 0))
		var assist := getaway_run.delivery_use_getaway_assist("rook_cutoff")
		var repeated := getaway_run.delivery_use_getaway_assist("rook_cutoff")
		if not bool(assist.get("ok", false)) or bool(repeated.get("ok", false)) or int(getaway_run.delivery_snapshot().get("pursuit_pressure", 0)) >= pressure_before:
			failures.append("Getaway one-use crew assist did not reduce pursuit exactly once.")
		_delivery_enter_node(getaway_run, _delivery_first_target(getaway_run))
		if getaway_run.delivery_has_active_run() or str((getaway_run.delivery_snapshot().get("resolution", {}) as Dictionary).get("reason", "")) != "escaped":
			failures.append("Getaway did not resolve on normal travel arrival.")
	var caught_run := _delivery_test_run("DELIVERY-GETAWAY-CAUGHT")
	caught_run.delivery_begin_getaway({"run_id": "caught", "enabled": true, "deadline_actions": 8, "pursuit_pressure": 3, "pursuit_per_boundary": 2, "pursuit_limit": 5})
	caught_run.advance_environment_turns(1)
	if caught_run.delivery_has_active_run() or str((caught_run.delivery_snapshot().get("resolution", {}) as Dictionary).get("reason", "")) != "caught":
		failures.append("Getaway pursuit failure did not resolve at an action boundary.")

	var abandoned_run := _delivery_test_run("DELIVERY-ABANDON")
	abandoned_run.delivery_begin_package({"run_id": "abandon", "deadline_actions": 5})
	if not bool(abandoned_run.delivery_abandon().get("ok", false)) or abandoned_run.delivery_has_active_run():
		failures.append("Impossible delivery could not be abandoned into a clean non-blocking state.")


func _check_delivery_no_soft_lock_worst_cases(failures: Array) -> void:
	var locked_run := _delivery_test_run("DELIVERY-TRAVEL-LOCK")
	var locked_started := locked_run.delivery_begin_package({"run_id": "travel_lock", "deadline_actions": 8})
	var locked_target := _delivery_first_target(locked_run)
	var locked_route := DeliveryWorldMapTestScript.new(null).route_for_target(locked_run.world_map, locked_run.current_world_node_id(), locked_target)
	locked_run.current_environment["travel_lock_remaining"] = 2
	locked_run.current_environment["travel_lock_source"] = "police_sweep"
	var initially_locked := locked_run.travel_route_status(locked_route)
	var first_wait := locked_run.perform_sweep_wait_action()
	var second_wait := locked_run.perform_sweep_wait_action()
	var reopened := locked_run.travel_route_status(locked_route)
	var generated_arrival := _delivery_generate_and_arrive(locked_run, locked_target)
	if not bool(locked_started.get("ok", false)) or bool(initially_locked.get("available", true)) \
		or not bool(first_wait.get("ok", false)) or not bool(second_wait.get("travel_reopened", false)) \
		or not bool(reopened.get("available", false)) or locked_run.current_world_node_id() != locked_target \
		or not bool(generated_arrival.get("handoff_ready", false)):
		failures.append("A travel-locked delivery target did not reopen and complete normal generated arrival without a soft-lock.")

	var camped_run := _delivery_test_run("DELIVERY-SWEEP-CAMPED-ONLY-ROUTE")
	var origin_id := camped_run.current_world_node_id()
	var leaf_target := ""
	for node_value in camped_run.world_map.get("nodes", []):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node_id := str((node_value as Dictionary).get("id", ""))
		if node_id == origin_id or not DeliveryWorldMapTestScript.has_path(camped_run.world_map, origin_id, node_id, false):
			continue
		var degree := 0
		for edge_value in camped_run.world_map.get("edges", []):
			if typeof(edge_value) == TYPE_DICTIONARY and (str((edge_value as Dictionary).get("a", "")) == node_id or str((edge_value as Dictionary).get("b", "")) == node_id):
				degree += 1
		if degree == 1:
			leaf_target = node_id
			break
	var camped_started := camped_run.delivery_begin_package({"run_id": "sweep_camped", "targets": [{"node_id": leaf_target}], "deadline_actions": 8, "cargo_heat_per_travel": 0}) if not leaf_target.is_empty() else {}
	if camped_run.town_state != null and camped_run.town_state.police_sweep != null and not leaf_target.is_empty():
		var sweep: PoliceSweepModel = camped_run.town_state.police_sweep
		sweep.configured = true
		sweep.disabled = false
		sweep.start_action = int(camped_run.town_state.action_index)
		sweep.end_action = sweep.start_action + 20
		sweep.segments = [{"node_id": leaf_target, "start_action": sweep.start_action, "end_action": sweep.end_action}]
		sweep.segment_index = 0
		sweep.action_index = int(camped_run.town_state.action_index)
	var camped_arrival := _delivery_generate_and_arrive(camped_run, leaf_target) if bool(camped_started.get("ok", false)) else {}
	if leaf_target.is_empty() or not bool(camped_started.get("ok", false)) or camped_run.current_world_node_id() != leaf_target \
		or (camped_run.delivery_has_active_run() and not bool(camped_arrival.get("handoff_ready", false))) \
		or (not camped_run.delivery_has_active_run() and str((camped_run.delivery_snapshot().get("resolution", {}) as Dictionary).get("reason", "")).is_empty()):
		failures.append("A Police Sweep camped at the leaf target's only graph route blocked travel or left the delivery unresolved.")


func _check_delivery_sweep_and_map_intel(failures: Array) -> void:
	var sweep_run := _delivery_test_run("DELIVERY-SWEEP")
	sweep_run.delivery_begin_package({"run_id": "sweep", "deadline_actions": 9, "cargo_id": "proof_case", "consumer_payload": {"failure": {"heat": 0}}})
	_delivery_pickup_if_needed(sweep_run)
	sweep_run.add_suspicion("fixture", 50, "test", false)
	var swept := sweep_run.resolve_police_sweep_encounter_for_test({"node_id": sweep_run.current_world_node_id(), "segment_index": 0, "encounter_seed": 44})
	if str(swept.get("outcome", "")) != "confiscation" or not str(swept.get("confiscated_item_id", "")).begins_with("delivery:") \
		or sweep_run.delivery_has_active_run() or str((sweep_run.delivery_snapshot().get("resolution", {}) as Dictionary).get("reason", "")) != "swept":
		failures.append("Police Sweep did not confiscate active delivery cargo and fail the run.")

	var intel_run := _delivery_test_run("DELIVERY-SWEEP-INTEL")
	intel_run.delivery_begin_package({"run_id": "intel", "deadline_actions": 9})
	var hidden_layer := intel_run.delivery_map_layer()
	if not intel_run.sweep_status().is_empty() or JSON.stringify(hidden_layer).find("reported sweep") >= 0 \
		or JSON.stringify(hidden_layer).find("current_node_id") >= 0 or JSON.stringify(hidden_layer).find("heading_node_id") >= 0:
		failures.append("Courier risk read leaked unearned Police Sweep position or heading.")
	if (hidden_layer.get("edge_reads", []) as Array).is_empty() or str((hidden_layer.get("cargo", {}) as Dictionary).get("label", "")).is_empty():
		failures.append("Courier map layer omitted edge risk or contraband presentation while active.")


func _check_delivery_save_and_migration(failures: Array) -> void:
	var source := _delivery_test_run("DELIVERY-SAVE")
	source.delivery_begin_multi_stop({"run_id": "save", "target_count": 2, "deadline_actions": 12})
	var first_target := _delivery_first_target(source)
	_delivery_enter_node(source, first_target)
	source.delivery_complete_handoff(first_target)
	var restored: RunState = RunStateScript.new()
	restored.from_dict(source.to_dict())
	if JSON.stringify(restored.delivery_snapshot()) != JSON.stringify(source.delivery_snapshot()) or int(restored.delivery_snapshot().get("schema_version", 0)) != DeliveryRunModelTestScript.SCHEMA_VERSION:
		failures.append("Schema-versioned delivery state did not round-trip mid-job.")

	var legacy := source.to_dict()
	legacy.erase("active_delivery_run")
	legacy["active_streets_run"] = {"status": "active", "run_id": "legacy_board", "job_id": ""}
	var migrated: RunState = RunStateScript.new()
	migrated.from_dict(legacy)
	if migrated.delivery_has_active_run() or not migrated.active_delivery_run.is_empty():
		failures.append("Legacy synthetic-board save did not load into a clean non-blocking state.")


func _check_delivery_ordinary_travel_identity(failures: Array) -> void:
	var ordinary := _delivery_test_run("DELIVERY-ORDINARY")
	var before := JSON.stringify(ordinary.to_dict())
	if not ordinary.active_delivery_run.is_empty() or ordinary.delivery_has_active_run() or not ordinary.delivery_map_layer().is_empty() \
		or not ordinary.delivery_arrival_interaction().is_empty() or JSON.stringify(ordinary.to_dict()) != before:
		failures.append("Inactive delivery reads mutated or leaked into the ordinary core run.")


func _delivery_test_run(seed: String) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	var generator: RunGenerator = RunGeneratorScript.new(delivery_test_library)
	generator.next_environment(run_state)
	return run_state


func _delivery_map_only_test_run(seed: String, configure_town: bool = true) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	var rng := run_state.create_rng("delivery_property_map")
	var map := DeliveryWorldMapTestScript.new(delivery_test_library).build(run_state, rng)
	run_state.set_world_map(map)
	var origin_id := run_state.current_world_node_id()
	var origin := DeliveryWorldMapTestScript.node_metadata_by_id(run_state.world_map, origin_id)
	run_state.current_environment = {
		"id": "%s_property" % origin_id,
		"archetype_id": str(origin.get("archetype_id", origin_id)),
		"world_node_id": origin_id,
		"turns": 0,
		"security_profile": {},
	}
	if configure_town:
		run_state.configure_town_world(run_state.world_map)
	run_state.save_rng(rng)
	return run_state


func _delivery_selection_twin(source: RunState, seed: String) -> RunState:
	# Independent same-seed state with the exact offered map inputs. A full save
	# normalization here was redundant with the dedicated mid-job save/load test
	# and dominated this 20-seed property gate.
	var twin: RunState = RunStateScript.new()
	twin.start_new(seed)
	twin.world_map = source.world_map.duplicate(true)
	twin.current_environment = source.current_environment.duplicate(true)
	twin.rng_seed = source.rng_seed
	twin.rng_state = source.rng_state
	return twin


func _delivery_first_target(run_state: RunState) -> String:
	var targets: Array = run_state.delivery_snapshot().get("targets", [])
	return str((targets[0] as Dictionary).get("node_id", "")) if not targets.is_empty() else ""


func _delivery_enter_node(run_state: RunState, node_id: String) -> Dictionary:
	_delivery_pickup_if_needed(run_state)
	var node := DeliveryWorldMapTestScript.node_metadata_by_id(run_state.world_map, node_id)
	run_state.world_map = DeliveryWorldMapTestScript.enter_node(run_state.world_map, node_id, {})
	run_state.current_environment = {
		"id": node_id,
		"archetype_id": str(node.get("archetype_id", node_id)),
		"world_node_id": node_id,
		"turns": 0,
		"security_profile": {},
	}
	return run_state.delivery_resolve_travel_arrival({"target_node_id": node_id}, {})


func _delivery_generate_and_arrive(run_state: RunState, node_id: String) -> Dictionary:
	_delivery_pickup_if_needed(run_state)
	var route := DeliveryWorldMapTestScript.new(null).route_for_target(run_state.world_map, run_state.current_world_node_id(), node_id)
	RunGeneratorScript.new(delivery_test_library).next_environment(run_state, node_id, true)
	return run_state.delivery_resolve_travel_arrival(route, run_state.travel_route_risk(route, node_id))


func _delivery_pickup_if_needed(run_state: RunState) -> void:
	var physical_value: Variant = run_state.delivery_snapshot().get("physical", {})
	var physical: Dictionary = (physical_value as Dictionary).duplicate(true) if typeof(physical_value) == TYPE_DICTIONARY else {}
	if str(physical.get("cargo_state", "")) == "pickup_pending":
		run_state.delivery_apply_physical_action("pickup", "foundation:pickup:%s" % str(run_state.active_delivery_run.get("run_id", "delivery")))


func _delivery_complete_all_targets(run_state: RunState) -> bool:
	var target_ids: Array = []
	for target_value in run_state.delivery_snapshot().get("targets", []):
		if typeof(target_value) == TYPE_DICTIONARY:
			target_ids.append(str((target_value as Dictionary).get("node_id", "")))
	for node_id_value in target_ids:
		var node_id := str(node_id_value)
		var arrival := _delivery_enter_node(run_state, node_id)
		if not bool(arrival.get("handoff_ready", false)) or run_state.delivery_arrival_interaction().is_empty():
			return false
		if not bool(run_state.delivery_complete_handoff(node_id).get("ok", false)):
			return false
	return not run_state.delivery_has_active_run()
