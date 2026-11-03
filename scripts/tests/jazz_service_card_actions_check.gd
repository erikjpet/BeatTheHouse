extends SceneTree

# Synthetic presentation regression. Real campaign service application is QA's
# separate acceptance; no Save, service transaction, RNG or campaign is used here.
const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _service(id: String, host: String, label: String, cost: int) -> Dictionary:
	return {
		"object_id": "service:" + id, "object_type": "service", "source_id": id,
		"label": label, "enabled": true, "interactive": true,
		"slot_binding_source_id": host,
		"available_actions": [{"id": "use_service_hook", "label": "Use"}],
		"action_summary": "Double-click to use.", "cost_summary": "Cost: %d" % cost,
		"effect_summary": "Heat -1" if cost == 0 else "Authored service effect.",
		"status_summary": "Takes 15 minutes.",
	}

func _actions(canvas: Control, host: Dictionary) -> Array:
	var view := host.duplicate(true)
	view["id"] = str(view.object_id)
	canvas.set("selected_object_id", str(view.id))
	return canvas.call("_selected_info_inline_actions", view)

func _run() -> void:
	var private_root := OS.get_environment("BTH_JAZZ_CARD_ROOT").replace("\\", "/")
	_check(not private_root.is_empty() and ProjectSettings.globalize_path("user://").replace("\\", "/").begins_with(private_root + "/"), "Fresh private synthetic storage is required.")
	if not failures.is_empty():
		_finish()
		return
	var canvas := Canvas.new()
	root.add_child(canvas)
	await process_frame
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/services/services.json"))
	var service_definitions: Dictionary = {}
	for value in definitions:
		service_definitions[str(value.get("id", ""))] = value
	var surfaces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/environments/placement_surfaces.json"))
	var jazz: Dictionary = {}
	for map_value in surfaces.get("maps", []):
		if typeof(map_value) == TYPE_DICTIONARY and str(map_value.get("archetype_id", "")) == "jazz_club":
			jazz = map_value
			break
	_check(not jazz.is_empty(), "The authored Jazz surface map loads from the actual maps array.")
	if jazz.is_empty():
		canvas.queue_free()
		_finish()
		return
	for case in [
		["listen_to_jazz", "fixture:jazz_band_stage", 0],
		["jazz_sax_round", "musician:jazz_sax", 8],
		["jazz_cello_round", "musician:jazz_cello", 8],
		["jazz_drummer_round", "musician:jazz_drummer", 8],
	]:
		var id := str(case[0])
		var host_id := str(case[1])
		var definition: Dictionary = service_definitions[id]
		var cost := int(definition.get("cost", -1))
		_check(cost == int(case[2]), "%s keeps authored price." % id)
		var authored_host := false
		for fixed in jazz.fixed_objects:
			if str(fixed.get("presentation_id", "")) == host_id and ("service:" + id) in fixed.get("action_ids", []):
				authored_host = true
		_check(authored_host, "%s uses the authored physical host." % id)
		var host := {"object_id": host_id, "object_type": "character" if id != "listen_to_jazz" else "fixture", "enabled": true, "manifest_physical": true}
		var source := _service(id, host_id, str(definition.display_name), cost)
		var inputs := [host, source]
		var service_before := var_to_bytes(source)
		var published: Array = Controller._attach_action_only_records(inputs)
		# Attachment deliberately annotates the mutable host record. The service
		# transaction data and the new renderer's input must remain unchanged.
		_check(var_to_bytes(source) == service_before, "%s attachment preserves its service source bytes." % id)
		_check(published.size() == 1 and published[0].attached_room_actions.size() == 1, "%s attaches once to its exact host." % id)
		var view: Dictionary = published[0].duplicate(true)
		view["id"] = host_id
		canvas.set("selected_object_id", host_id)
		var presentation_before := var_to_bytes(view)
		var actions: Array = canvas.call("_selected_info_inline_actions", view)
		_check(var_to_bytes(view) == presentation_before, "%s card projection leaves its published descriptor bytes unchanged." % id)
		_check(actions.size() == 1, "%s visible card exposes exactly one service." % id)
		if actions.is_empty():
			continue
		var action: Dictionary = actions[0]
		_check(action.label == definition.display_name, "%s displays its actual service name." % id)
		_check(action.text.contains("Cost: %d" % cost) and action.text.contains(source.effect_summary) and action.text.contains(source.status_summary), "%s discloses unchanged published price/effect/time." % id)
		_check(bool(action.enabled), "%s preserves descriptor eligibility." % id)
		var token: String = action.emit_object_id
		var parts := token.split(":")
		_check(parts.size() == 3 and parts[0] == "room_action" and parts[1].uri_decode() == host_id and parts[2].uri_decode() == str(published[0].attached_room_actions[0].key), "%s dispatches the exact existing descriptor token." % id)
		_check(_actions(canvas, published[0]) == actions, "%s repeated rendering is stable." % id)
		var restored: Dictionary = bytes_to_var(var_to_bytes(published[0]))
		_check(_actions(canvas, restored) == actions, "%s restored presentation keeps the same service metadata." % id)
		var disabled := restored.duplicate(true)
		disabled.attached_room_actions[0].enabled = false
		disabled.attached_room_actions[0].disabled_reason = "Service unavailable."
		var blocked: Array = _actions(canvas, disabled)
		_check(blocked.size() == 1 and not bool(blocked[0].enabled) and bool(blocked[0].disabled) and str(blocked[0].text).contains("Service unavailable."), "%s remains disabled with its published reason." % id)
		for visibility in ["visible", "presentation_visible", "hidden", "hidden_only"]:
			var hidden := restored.duplicate(true)
			hidden.attached_room_actions[0].action[visibility] = visibility in ["hidden", "hidden_only"]
			_check(_actions(canvas, hidden).is_empty(), "%s honors %s on the source action." % [id, visibility])
		facts[id] = {"label": action.label, "detail": action.text, "token": token}
	var host := {"object_id": "synthetic:counter", "id": "synthetic:counter", "enabled": false, "disabled": true, "available_actions": [], "attached_room_actions": [{"key": "redeem", "label": "Cash In Tickets", "enabled": true, "record": {"object_type": "game_hook", "action_summary": "Cash out."}, "action": {"id": "redeem_pull_tab_winners"}}]}
	var cash := _actions(canvas, host)
	_check(cash.size() == 1 and bool(cash[0].host_independent_service) and cash[0].label == "Cash In Tickets", "Existing host-independent ticket redemption remains available.")
	var service_host := {"object_id": "synthetic:host", "id": "synthetic:host", "enabled": false, "disabled": true, "attached_room_actions": [{"key": "service", "label": "Use", "enabled": true, "record": {"object_type": "service", "label": "Published service", "cost_summary": "Cost: 0"}, "action": {"id": "use_service_hook"}}]}
	var independent := _actions(canvas, service_host)
	var entries: Array = canvas.call("_selected_info_action_entries_for_rect", {"object": service_host}, Rect2(0, 0, 220, 260))
	_check(independent.size() == 1 and entries.size() == 1 and bool(entries[0].enabled), "Service descriptor eligibility is independent of its decorative host's own action.")
	for invalid in ["unknown", "buy_item", "use_lender_hook"]:
		var other := service_host.duplicate(true)
		other.attached_room_actions[0].action.id = invalid
		_check(_actions(canvas, other).is_empty(), "Unrelated attached %s is not promoted by the service fix." % invalid)
	var wrong_type := service_host.duplicate(true)
	wrong_type.attached_room_actions[0].record.object_type = "event"
	_check(_actions(canvas, wrong_type).is_empty(), "Service-shaped action cannot promote an unrelated event.")
	var blank_key := service_host.duplicate(true)
	blank_key.attached_room_actions[0].key = ""
	_check(_actions(canvas, blank_key).is_empty(), "Missing authoritative descriptor key remains non-dispatchable.")
	var with_talk := service_host.duplicate(true)
	with_talk.enabled = true
	with_talk.disabled = false
	with_talk.available_actions = [{"id": "talk", "label": "Talk"}]
	var talked := _actions(canvas, with_talk)
	_check(talked.size() == 2 and talked[1].label == "Talk" and talked[1].emit_object_id == "synthetic:host", "The host's existing primary action remains accessible.")
	var unselected := with_talk.duplicate(true)
	canvas.set("selected_object_id", "different")
	_check((canvas.call("_selected_info_inline_actions", unselected) as Array).is_empty(), "Unselected hosts cannot expose response actions.")
	canvas.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	for failure in failures:
		push_error(failure)
	print("JAZZ_SERVICE_CARD_CHECK ", JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "scope": "Synthetic controller-to-real-canvas presentation. No actual campaign, transaction, disk Save/cold or browser acceptance."}))
	quit(0 if failures.is_empty() else 1)
