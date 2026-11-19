extends RefCounted

# Additive room-native fixture authority. Existing accepted furniture, storage,
# upgrade controls and developer placements retain their own slots unchanged.
const OBJECT_ID := "home_console:tv"
const OBJECT_TYPE := "home_console"
const SLOT_ID := "fixed.home_console"
const PROFILE := "home_practice_console_v1"
const ROOM_RECTS := {
	"motel_room": Rect2(88, 224, 148, 64),
	# The accepted Apartment sleep override occupies the lower-left wall. Keep
	# the new console below both that bed and the shipping container footprint.
	"apartment": Rect2(88, 360, 148, 56),
	"house": Rect2(76, 234, 144, 56),
}


static func eligible(environment: Dictionary) -> bool:
	return str(environment.get("kind", "")) == "home" \
		and ROOM_RECTS.has(str(environment.get("archetype_id", ""))) \
		and not bool(environment.get("home_lost", false))


static func profile_id(environment: Dictionary) -> String:
	return PROFILE if eligible(environment) else ""


static func interactable_record(focus_rect: Rect2 = Rect2()) -> Dictionary:
	return {
		"object_id": OBJECT_ID, "object_type": OBJECT_TYPE, "visual_type": OBJECT_TYPE,
		"source_id": "tv", "label": "Practice Console",
		"short_description": "An old television and game console. Practice any game.",
		"presence": "fixture", "interactive": true, "enabled": true,
		"action_summary": "Turn on Beat the House.",
		"effect_summary": "Practice uses its own money, time and game state.",
		"visual_key": OBJECT_TYPE, "prop": "crt_console", "surface": "floor",
		"placement_class": "floor_fixture", "icon_key": "game",
		"available_actions": [{"id": "open_practice_console", "label": "Play"}],
		"confirm_action_id": "open_practice_console", "focus_rect": focus_rect,
	}


static func surface_map(environment: Dictionary, base: Dictionary) -> Dictionary:
	if not eligible(environment):
		return base
	var result := base.duplicate(true)
	var rect: Rect2 = ROOM_RECTS[str(environment.get("archetype_id", ""))]
	var center := rect.get_center()
	var slots: Array = result.get("fixed_slots", [])
	slots.append({
		"id": SLOT_ID, "kind": "fixed", "pos": [center.x, rect.end.y],
		"footprint_class": "floor_fixture", "physical_role": "Television and practice game console",
		"occupant_ids": [OBJECT_ID], "runtime_reserve": false, "reserve_reason": "",
		"hit_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"label_anchor": [center.x, rect.position.y - 6], "facing": "none",
		"priority": 10, "zone_id": "room", "support_id": "floor",
		"walk_lane_ids": [], "occupancy_required": false,
	})
	result["fixed_slots"] = slots
	for field in ["fixed_object_slot_ids", "object_family_ids", "class_overrides", "fixed_category_slot_ids"]:
		var mapping: Dictionary = result.get(field, {})
		match field:
			"fixed_object_slot_ids": mapping[OBJECT_ID] = SLOT_ID
			"object_family_ids": mapping[OBJECT_ID] = "fixed"
			"class_overrides": mapping[OBJECT_ID] = "floor_fixture"
			"fixed_category_slot_ids": mapping["home_console_spots:0"] = SLOT_ID
		result[field] = mapping
	return result
