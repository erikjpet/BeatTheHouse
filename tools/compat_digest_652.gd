extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var result: Dictionary = {}
	for seed_index in range(20):
		var seed := "DELIVERY-PROPERTY-%02d" % seed_index
		var run_state: RunState = RunStateScript.new()
		run_state.start_new(seed)
		var rng := run_state.create_rng("delivery_property_map")
		var map_data := WorldMapScript.new(library).build(run_state, rng)
		var source_id := WorldMapScript.current_node_id(map_data)
		var node_ids: Array = []
		var hidden_source_id := ""
		for node_value in map_data.get("nodes", []):
			if typeof(node_value) != TYPE_DICTIONARY:
				continue
			var node: Dictionary = node_value
			var node_id := str(node.get("id", "")).strip_edges()
			if node_id.is_empty():
				continue
			node_ids.append(node_id)
			if hidden_source_id.is_empty() and str(node.get("state", "hidden")) == WorldMapScript.STATE_HIDDEN:
				hidden_source_id = node_id
		node_ids.sort()
		var hidden_targets: Array = [hidden_source_id, source_id] if not hidden_source_id.is_empty() else [source_id]
		result[seed] = {
			"all": _path_digest(map_data, source_id, node_ids, false),
			"visible": _path_digest(map_data, source_id, node_ids, true),
			"hidden_all": _path_digest(map_data, hidden_source_id, hidden_targets, false),
			"hidden_visible": _path_digest(map_data, hidden_source_id, hidden_targets, true),
		}
	print(JSON.stringify(result, "  "))
	quit(0)


func _path_digest(map_data: Dictionary, source_id: String, target_ids: Array, visible_only: bool) -> String:
	var canonical: Array = []
	for target_id_value in target_ids:
		var target_id := str(target_id_value)
		canonical.append([target_id, WorldMapScript.path_between(map_data, source_id, target_id, visible_only)])
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(canonical).to_utf8_buffer())
	return context.finish().hex_encode()
