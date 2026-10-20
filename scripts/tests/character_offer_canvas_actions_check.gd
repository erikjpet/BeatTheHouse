extends SceneTree

# Pure presentation/dispatch contract: no scene is added to the tree and no
# renderer or autonomous game simulation starts.
# godot --headless --path . --script res://scripts/tests/character_offer_canvas_actions_check.gd
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const Offers := preload("res://scripts/core/character_offer_model.gd")
const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")
const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")

class OfferHost extends RefCounted:
	var run_state: RunState
	var library: ContentLibrary

	func _character_offer_route_preview(_offer: Dictionary) -> Dictionary:
		# Route safety has its production contract in character_offers_check.gd.
		# This fixture owns only the final card's existing-host presentation.
		return {"summary": "Home: actual home. Wait: 360 min. Depart: 05:00. Travel: 10 min. Arrive: 05:10."}

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	var canvas: PixelSceneCanvas = Canvas.new()
	for definition_value in Offers.definitions():
		var definition: Dictionary = definition_value
		var host := OfferHost.new()
		host.library = library
		host.run_state = _winning_run(definition, library)
		if host.run_state == null:
			continue
		var hosts: Dictionary = definition.get("hosts", {})
		var archetype_id := str(hosts.keys()[0])
		var object_id := str(hosts[archetype_id])
		var base := _base_record(object_id)
		var decorated: Array = Controller._attach_character_offers(host, [base.duplicate(true)])
		_expect(decorated.size() == 1, "Offer keeps one existing physical host.")
		var record: Dictionary = decorated[0]
		_expect(record.get("manifest_action_ids", []) == base.get("manifest_action_ids", []), "Offer preserves the sealed manifest actions.")
		_expect((record.get("attached_room_actions", []) as Array).size() == 2, "Offer preserves the original attached action.")
		_expect((record.get("inline_actions", []) as Array).size() == 2, "Offer preserves the original canvas action.")
		var objects: Array = canvas.call("_objects_from_interactable_records", decorated)
		_expect(objects.size() == 1, "Canvas converts the offered host without adding a person.")
		if objects.is_empty():
			continue
		canvas.selected_object_id = object_id
		var actions: Array = canvas.call("_selected_info_inline_actions", objects[0])
		var expected_label := str(definition.get("label", ""))
		var action := _action_with_label(actions, expected_label)
		_expect(not action.is_empty(), "%s is reachable on the visible canvas card." % expected_label)
		_expect(not _action_with_label(actions, "Existing action").is_empty(), "Canvas retains the host's previous action.")
		if not action.is_empty():
			var emitted := str(action.get("emit_object_id", ""))
			var parts := emitted.split(":")
			_expect(parts.size() == 3 and str(parts[0]) == "room_action", "Offer uses the existing attached-room dispatch route.")
			if parts.size() == 3:
				_expect(str(parts[1]).uri_decode() == object_id, "Dispatch restores the exact host identity.")
				_expect(str(parts[2]).uri_decode() == "character_offer:%s" % str(definition.get("id", "")), "Dispatch restores the exact live descriptor key.")
			_expect(bool(action.get("enabled", false)), "The eligible canvas offer action is enabled.")
		Offers.expire_departure(host.run_state)
		var expired: Array = Controller._attach_character_offers(host, [base.duplicate(true)])
		var expired_objects: Array = canvas.call("_objects_from_interactable_records", expired)
		var expired_actions: Array = canvas.call("_selected_info_inline_actions", expired_objects[0])
		_expect(_action_with_label(expired_actions, expected_label).is_empty(), "A fresh expired projection removes the offer label.")
		_expect(not _action_with_label(expired_actions, "Existing action").is_empty(), "Expiry keeps the existing host action.")
	canvas.free()
	for failure in failures:
		printerr("CHARACTER OFFER CANVAS: %s" % failure)
	print("CHARACTER OFFER CANVAS CHECK assertions=%d failures=%d ok=%s" % [assertions, failures.size(), str(failures.is_empty())])
	quit(0 if failures.is_empty() else 1)


func _winning_run(definition: Dictionary, library: ContentLibrary) -> RunState:
	var hosts: Dictionary = definition.get("hosts", {})
	var archetype_id := str(hosts.keys()[0])
	var object_id := str(hosts[archetype_id])
	for index in range(128):
		var run: RunState = RunStateScript.new()
		run.start_new("OFFER-CANVAS-%03d" % index)
		run.game_clock_minutes = 1380
		run.bankroll = 100
		run.drunk_level = 12
		run.suspicion["level"] = 20
		run.inventory = ["cheap_sunglasses"]
		run.home_state = {"active": true, "lost": false, "home_node_id": "actual_home"}
		run.current_environment = {
			"id": "offer_canvas:%s" % archetype_id, "archetype_id": archetype_id,
			"display_name": archetype_id, "world_node_id": archetype_id,
			"object_manifest": {"rows": [{"instance_object_id": object_id, "active": true, "physical": true}]},
		}
		if not Offers.view(run, library, str(definition.get("id", ""))).is_empty():
			return run
	_expect(false, "A bounded seed probe finds an eligible %s offer." % str(definition.get("id", "")))
	return null


func _base_record(object_id: String) -> Dictionary:
	return {
		"object_id": object_id, "object_type": "character", "visual_type": "character",
		"label": "Existing character", "enabled": true, "visible": true,
		"manifest_object_id": object_id, "manifest_physical": true, "manifest_action_ids": [],
		"presentation_mode": "room", "fixed_slot_geometry": true,
		"normalized_rect": {"x": 0.4, "y": 0.3, "w": 0.1, "h": 0.2},
		"inline_actions": [{"label": "Existing action", "enabled": true, "emit_object_id": "existing_action"}],
		"attached_room_actions": [{"key": "existing", "label": "Existing attached action", "enabled": true}],
	}


func _action_with_label(actions: Array, label: String) -> Dictionary:
	for value in actions:
		if typeof(value) == TYPE_DICTIONARY and str(value.get("label", "")) == label:
			return value
	return {}


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
