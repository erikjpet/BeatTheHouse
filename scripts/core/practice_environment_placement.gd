extends RefCounted

# Isolated authority for the existing six-cabinet Slot practice room. The
# shipped Grand Casino map/hashes remain unchanged for ordinary runs and saves.
const PROFILE := "slot_cabinet_bank"
const POSITIONS := [Vector2(85, 150), Vector2(220, 150), Vector2(355, 150), Vector2(525, 150), Vector2(675, 150), Vector2(825, 150)]


static func profile_id(environment: Dictionary) -> String:
	var flags: Dictionary = environment.get("local_narrative_flags", {})
	return PROFILE if bool(flags.get("practice_session", false)) and str(flags.get("practice_placement_id", "")) == PROFILE else ""


static func surface_map(environment: Dictionary, base: Dictionary) -> Dictionary:
	if profile_id(environment).is_empty():
		return base
	var result := base.duplicate(true)
	var removed: Dictionary = {}
	var slots: Array = []
	for value in result.get("fixed_slots", []):
		var slot: Dictionary = value
		var identity := str(slot.get("id", ""))
		if identity.begins_with("fixed.game_machine_"):
			removed[identity] = true
		else:
			slots.append(slot)
	for field in ["fixed_object_slot_ids", "fixed_category_slot_ids"]:
		var mapping: Dictionary = result.get(field, {})
		for key in mapping.keys():
			var value: Variant = mapping[key]
			if typeof(value) == TYPE_STRING and removed.has(value):
				mapping.erase(key)
			elif typeof(value) == TYPE_ARRAY:
				var retained: Array = []
				for slot_id in value:
					if not removed.has(slot_id):
						retained.append(slot_id)
				mapping[key] = retained
	var exact: Dictionary = result.get("fixed_object_slot_ids", {})
	var families: Dictionary = result.get("object_family_ids", {})
	for index in range(POSITIONS.size()):
		var position: Vector2 = POSITIONS[index]
		var identity := "game:slot" if index == 0 else "game:slot:%d" % (index + 1)
		var slot_id := "fixed.practice_cabinet_%d" % (index + 1)
		var classes: Dictionary = base.get("class_overrides", {})
		var placement_class := str(classes.get(identity, "floor_fixture"))
		slots.append({
			"id": slot_id, "kind": "fixed", "pos": [position.x, position.y],
			"footprint_class": placement_class, "physical_role": "Practice cabinet %d" % (index + 1),
			"occupant_ids": [identity], "runtime_reserve": false, "reserve_reason": "",
			"hit_rect": [position.x - 46.0, position.y - 64.0, 92.0, 64.0],
			"label_anchor": [position.x, position.y - 70.0], "facing": "none",
			"priority": index, "zone_id": "room", "support_id": "floor",
			"walk_lane_ids": [], "occupancy_required": false,
		})
		exact[identity] = slot_id
		families[identity] = "fixed"
	result["fixed_slots"] = slots
	result["fixed_object_slot_ids"] = exact
	result["object_family_ids"] = families
	result["id"] = "%s::%s" % [str(base.get("id", "")), PROFILE]
	return result
