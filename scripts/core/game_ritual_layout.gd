class_name GameRitualLayout
extends RefCounted

const Z_LAYERS := ["background", "gameplay", "actors", "effects", "hud"]


static func validate_definition(definition: Dictionary, design_size: Vector2 = Vector2(900, 430), minimum_touch: int = 42) -> Array[String]:
	var errors: Array[String] = []
	var canvas := Rect2(Vector2.ZERO, design_size)
	var text_regions: Array[Rect2] = []
	var interactive: Array[Dictionary] = []
	for object_value in definition.get("scene_objects", []):
		if typeof(object_value) != TYPE_DICTIONARY: continue
		var object: Dictionary = object_value
		var bounds := _rect(object.get("bounds", {}))
		if not canvas.encloses(bounds): errors.append("scene object %s leaves design space" % str(object.get("id", "")))
		if not Z_LAYERS.has(str(object.get("z_layer", ""))): errors.append("scene object %s has unknown z layer" % str(object.get("id", "")))
		for region_value in object.get("text_safety_regions", []):
			if typeof(region_value) == TYPE_DICTIONARY: text_regions.append(_rect((region_value as Dictionary).get("bounds", {})))
		for hit_value in object.get("hit_regions", []):
			if typeof(hit_value) != TYPE_DICTIONARY: continue
			var hit: Dictionary = hit_value
			var rect := _rect(hit.get("bounds", {}))
			if not bounds.encloses(rect): errors.append("hit region %s leaves its scene object" % str(hit.get("id", "")))
			if rect.size.x < minimum_touch or rect.size.y < minimum_touch or int(hit.get("minimum_touch_target", 0)) < minimum_touch: errors.append("hit region %s is below the touch minimum" % str(hit.get("id", "")))
			interactive.append({"id": str(hit.get("id", "")), "rect": rect, "z": Z_LAYERS.find(str(object.get("z_layer", "")))})
	for hit in interactive:
		for text_rect in text_regions:
			if (hit.get("rect", Rect2()) as Rect2).intersects(text_rect): errors.append("interactive region %s overlaps text safety" % str(hit.get("id", "")))
	for index in range(interactive.size()):
		for other_index in range(index + 1, interactive.size()):
			var left: Dictionary = interactive[index]; var right: Dictionary = interactive[other_index]
			if int(left.get("z", -1)) == int(right.get("z", -1)) and (left.get("rect", Rect2()) as Rect2).intersects(right.get("rect", Rect2())): errors.append("same-layer interactive regions overlap: %s/%s" % [left.get("id", ""), right.get("id", "")])
	for pointer_value in definition.get("pointer_verbs", []):
		if typeof(pointer_value) != TYPE_DICTIONARY: continue
		var equivalents: Dictionary = (pointer_value as Dictionary).get("equivalents", {})
		for path in ["keyboard", "controller", "reduced_motion"]:
			if not equivalents.has(path): errors.append("pointer %s lacks %s equivalent" % [(pointer_value as Dictionary).get("id", ""), path])
	return errors


static func compile_pointer_hits(definition: Dictionary, phase_id: String) -> Array:
	var regions := {}
	for object_value in definition.get("scene_objects", []):
		if typeof(object_value) != TYPE_DICTIONARY: continue
		for hit_value in (object_value as Dictionary).get("hit_regions", []):
			if typeof(hit_value) == TYPE_DICTIONARY: regions[str((hit_value as Dictionary).get("id", ""))] = _rect((hit_value as Dictionary).get("bounds", {}))
	var result: Array = []
	for pointer_value in definition.get("pointer_verbs", []):
		if typeof(pointer_value) != TYPE_DICTIONARY: continue
		var pointer: Dictionary = pointer_value
		if not (pointer.get("phases", []) as Array).has(phase_id): continue
		var source := str(pointer.get("source_region", ""))
		if regions.has(source): result.append({"rect": regions[source], "action": str(pointer.get("accepted_action", "")), "pointer_id": str(pointer.get("id", "")), "verb": str(pointer.get("verb", "")), "capture": str(pointer.get("verb", "")) in ["drag", "hold", "flick", "reveal"]})
	return result


static func _rect(value: Variant) -> Rect2:
	var record: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	return Rect2(float(record.get("x", 0)), float(record.get("y", 0)), float(record.get("w", 0)), float(record.get("h", 0)))
