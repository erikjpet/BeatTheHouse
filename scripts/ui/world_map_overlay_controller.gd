class_name WorldMapOverlayController
extends RefCounted

signal refresh_requested()
signal message_requested(text: String)
signal travel_requested(target_id: String, label: String, choice: Dictionary)
signal meta_travel_requested(target_id: String)

var selected_node_id: String = ""
var selected_travel_target_id: String = ""
var selected_travel_label: String = ""
var snapshot_cache_key: String = ""
var canvas_snapshot_key: String = ""


func clear_selection() -> void:
	selected_node_id = ""
	selected_travel_target_id = ""
	selected_travel_label = ""
	snapshot_cache_key = ""
	canvas_snapshot_key = ""


func select_run_node(node_id: String, current_node_id: String, visible_node_ids: Array, choice: Dictionary) -> Dictionary:
	var clean_id := node_id.strip_edges()
	if clean_id.is_empty():
		return _result(false, "", true)
	if not visible_node_ids.has(clean_id):
		return _result(false, "That stop is not on your map from here.", true)
	selected_node_id = clean_id
	if clean_id == current_node_id:
		selected_travel_target_id = ""
		selected_travel_label = ""
		return _result(true, "You are here.", true)
	if choice.is_empty():
		selected_travel_target_id = ""
		selected_travel_label = ""
		return _result(true, "That stop is not available from here right now.", true)
	var enabled := bool(choice.get("enabled", true))
	selected_travel_target_id = clean_id if enabled else ""
	selected_travel_label = str(choice.get("label", clean_id)) if enabled else ""
	var message := "Selected travel: %s." % str(choice.get("label", clean_id))
	if not enabled:
		message = str(choice.get("disabled_reason", "That route is not available right now."))
	return _result(enabled, message, true)


func select_meta_node(node_id: String, location_id: String, node_ids: Array, choice: Dictionary) -> Dictionary:
	if not node_ids.has(node_id):
		return _result(false, "That meta stop is not available.", true)
	selected_node_id = node_id
	if node_id == location_id:
		selected_travel_target_id = ""
		selected_travel_label = ""
		return _result(true, "You are here.", true)
	selected_travel_target_id = node_id
	selected_travel_label = str(choice.get("label", node_id))
	return _result(true, "Selected travel: %s." % selected_travel_label, true)


func confirm_run_selection(choice: Dictionary) -> Dictionary:
	var confirmed_target_id := selected_node_id
	if confirmed_target_id.is_empty() and not selected_travel_target_id.is_empty():
		confirmed_target_id = selected_travel_target_id
	if confirmed_target_id.is_empty():
		return _confirm_result("message", "", "", {}, "Select a map stop first.", true)
	if choice.is_empty():
		return _confirm_result("message", confirmed_target_id, "", {}, "That stop is not available from here right now.", true)
	if not bool(choice.get("enabled", true)):
		return _confirm_result("message", confirmed_target_id, "", {}, str(choice.get("disabled_reason", "That route is not available right now.")), true)
	selected_travel_target_id = str(choice.get("id", ""))
	selected_travel_label = str(choice.get("label", selected_travel_target_id))
	return _confirm_result("travel", selected_travel_target_id, selected_travel_label, choice, "", false)


func confirm_meta_selection(location_id: String, choice: Dictionary) -> Dictionary:
	if selected_node_id == location_id:
		return _confirm_result("message", selected_node_id, "", {}, "You are here.", true)
	if choice.is_empty():
		return _confirm_result("message", selected_node_id, "", {}, "That meta stop is not available.", true)
	return _confirm_result("meta_travel", str(choice.get("id", "home")), str(choice.get("label", choice.get("id", ""))), choice, "", false)


func sync_from_host(node_id: String, target_id: String, target_label: String, cache_key: String, canvas_key: String) -> void:
	selected_node_id = node_id
	selected_travel_target_id = target_id
	selected_travel_label = target_label
	snapshot_cache_key = cache_key
	canvas_snapshot_key = canvas_key


func export_state() -> Dictionary:
	return {
		"selected_node_id": selected_node_id,
		"selected_travel_target_id": selected_travel_target_id,
		"selected_travel_label": selected_travel_label,
		"snapshot_cache_key": snapshot_cache_key,
		"canvas_snapshot_key": canvas_snapshot_key,
	}


func _result(ok: bool, message: String, refresh: bool) -> Dictionary:
	return {
		"ok": ok,
		"message": message,
		"refresh": refresh,
		"selected_node_id": selected_node_id,
		"selected_travel_target_id": selected_travel_target_id,
		"selected_travel_label": selected_travel_label,
	}


func _confirm_result(action: String, target_id: String, label: String, choice: Dictionary, message: String, refresh: bool) -> Dictionary:
	return {
		"action": action,
		"target_id": target_id,
		"label": label,
		"choice": choice.duplicate(true),
		"message": message,
		"refresh": refresh,
		"selected_node_id": selected_node_id,
		"selected_travel_target_id": selected_travel_target_id,
		"selected_travel_label": selected_travel_label,
	}
