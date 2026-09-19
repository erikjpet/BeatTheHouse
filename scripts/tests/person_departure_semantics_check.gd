extends SceneTree

const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")


class DeliveryRunStub:
	extends RefCounted

	var current_environment := {
		"id": "gas_station_casino",
		"archetype_id": "gas_station_casino",
		"world_node_id": "gas_station_casino",
	}

	func delivery_physical_interactions() -> Array:
		return [{
			"object_id": "delivery:pickup:gas_station_casino",
			"verb": "pickup",
			"label": "Take the package",
			"cargo_label": "Crew package",
			"message": "Take the package from this room.",
		}]

	func delivery_arrival_interaction() -> Dictionary:
		return {}


class DeliveryHostStub:
	extends RefCounted

	var CONTEXT_MODE_DELIVERY := "delivery"
	var run_state := DeliveryRunStub.new()

	func _current_environment_layout() -> Dictionary:
		return {}

	func _interaction_rect_for_object(_object_id: String, _object_type: String, _index: int) -> Rect2:
		return Rect2(0.42, 0.56, 0.10, 0.14)

	func _make_interactable_object(source: Dictionary) -> Dictionary:
		return source.duplicate(true)


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var host := DeliveryHostStub.new()
	var delivery_objects: Array = EnvironmentInteractionControllerScript.delivery_interactable_objects(host)
	_check(delivery_objects.size() == 1, "Delivery pickup did not produce exactly one physical object.")
	var package: Dictionary = delivery_objects[0] if not delivery_objects.is_empty() else {}
	_check(str(package.get("visual_type", "")) == "prop", "Take the package was still projected as a character.")
	_check(str(package.get("presence", "")) == "fixture", "Take the package still claimed character presence.")
	_check(str(package.get("prop", "")) == "crate", "Take the package did not use its package prop.")
	_check(not EnvironmentPlacementScript.is_person_class(str(package.get("placement_class", ""))), "Take the package still received a person placement class.")

	var holder := Control.new()
	root.add_child(holder)
	var canvas: Control = PixelSceneCanvasScript.new()
	holder.add_child(canvas)
	var person := _record("dialogue:person", "character", "standing_person", 0.30)
	var legacy_package := _record("delivery:pickup:legacy", "prop", "standing_person", 0.62)
	var base_room := _room([person])
	canvas.call("render_environment_snapshot", base_room)
	var with_package := _room([person, legacy_package])
	canvas.call("render_environment_snapshot", with_package)
	_check(not (canvas.get("person_transit_ids") as Array).has("delivery:pickup:legacy"), "A package with stale person placement metadata walked into the room.")
	canvas.call("render_environment_snapshot", base_room)
	_check(_canvas_object(canvas, "delivery:pickup:legacy").is_empty(), "A removed package walked away instead of disappearing in place.")

	var without_person := _room([])
	canvas.call("render_environment_snapshot", without_person)
	var departing_person := _canvas_object(canvas, "dialogue:person")
	_check(bool(departing_person.get("person_transit_active", false)), "A real departing person no longer received a departure transit.")
	_check(str(departing_person.get("person_transit_kind", "")) == "departure", "A real departing person received the wrong transit kind.")

	holder.queue_free()
	await process_frame
	if failures.is_empty():
		print("PERSON_DEPARTURE_SEMANTICS_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("PERSON_DEPARTURE_SEMANTICS_CHECK FAIL count=%d" % failures.size())
	quit(1)


func _room(objects: Array) -> Dictionary:
	return {
		"id": "person_departure_semantics",
		"world_node_id": "gas_station_casino",
		"archetype_id": "gas_station_casino",
		"environment_visit_id": "person-departure-semantics-visit",
		"interactable_objects": objects,
	}


func _record(object_id: String, visual_type: String, placement_class: String, center_x: float) -> Dictionary:
	return {
		"object_id": object_id,
		"object_type": "dialogue" if visual_type == "character" else "delivery",
		"visual_type": visual_type,
		"label": "Person" if visual_type == "character" else "Take the package",
		"short_description": "Fixture record.",
		"visible": true,
		"interactive": true,
		"enabled": true,
		"placement_class": placement_class,
		"scenario_layout_resolved": true,
		"normalized_rect": {"x": center_x - 0.04, "y": 0.55, "w": 0.08, "h": 0.20},
	}


func _canvas_object(canvas: Control, object_id: String) -> Dictionary:
	for value in canvas.get("foundation_scene_objects") as Array:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == object_id:
			return value as Dictionary
	return {}
