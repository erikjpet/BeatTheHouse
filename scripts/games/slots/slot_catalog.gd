class_name SlotCatalog
extends RefCounted

const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")


func skin_for_machine(machine: Dictionary, definition: Dictionary) -> Dictionary:
	var family_id := str(machine.get("type_id", "pinball"))
	var format_id := str(machine.get("format_id", "classic_3_reel"))
	var geometry: Dictionary = StateScript.canonical_geometry(definition, family_id, format_id)
	var cabinet: Dictionary = variant_by_id(definition.get("slot_cabinet_variants", []), str(machine.get("cabinet_variant_id", "neon_magenta")))
	var identity: Dictionary = _identity_for(family_id, format_id)
	var reel_count := int(geometry.get("reel_count", 3))
	var row_count := int(geometry.get("row_count", 1))
	var window: Dictionary = _copy_dict(identity.get("reel_window", _window_rect(reel_count, row_count)))
	var base_palette: Dictionary = _copy_dict(identity.get("palette", {}))
	return {
		"id": "%s:%s" % [family_id, format_id],
		"family": family_id,
		"format_id": format_id,
		"cabinet_identity": str(identity.get("id", "%s_%s" % [family_id, format_id])),
		"cabinet_title": str(identity.get("title", "%s %s" % [family_id, format_id])),
		"feature_name": str(identity.get("feature_name", "")),
		"era": str(identity.get("era", "")),
		"material": str(identity.get("material", "")),
		"topper_style": str(identity.get("topper_style", "")),
		"motion_style": str(identity.get("motion_style", "")),
		"reel_count": reel_count,
		"row_count": row_count,
		"pay_model": str(geometry.get("pay_model", "")),
		"silhouette": _copy_dict(identity.get("silhouette", {})),
		"topper_rect": _copy_dict(identity.get("topper_rect", {"x": 36, "y": 18, "w": 888, "h": 54})),
		"reel_window": window,
		"feature_panel": _copy_dict(identity.get("feature_panel", {"x": 650, "y": 92, "w": 270, "h": 260})),
		"tease_panel": _copy_dict(identity.get("tease_panel", {"x": 40, "y": 92, "w": 190, "h": 260})),
		"playfield_rect": _copy_dict(identity.get("playfield_rect", {"x": 652, "y": 112, "w": 250, "h": 220})),
		"belly_rect": _copy_dict(identity.get("belly_rect", {"x": 42, "y": 356, "w": 876, "h": 68})),
		"result_strip": _copy_dict(identity.get("result_strip", {"x": 52, "y": 378, "w": 856, "h": 42})),
		"controls": _copy_dict(identity.get("controls", {"x": 42, "y": 432, "w": 876, "h": 84})),
		"side_rails": _copy_array(identity.get("side_rails", [])),
		"palette": {
			"primary": str(cabinet.get("primary", base_palette.get("primary", "#24112f"))),
			"secondary": str(cabinet.get("secondary", base_palette.get("secondary", "#090b13"))),
			"accent": str(cabinet.get("accent", base_palette.get("accent", "#ff4fb3"))),
			"light": str(cabinet.get("light", base_palette.get("light", "#35e0ff"))),
			"trim": str(base_palette.get("trim", cabinet.get("accent", "#f7c845"))),
			"glass": str(base_palette.get("glass", "#8ddcff")),
			"shadow": str(base_palette.get("shadow", "#020308")),
		},
	}


func all_skins(definition: Dictionary) -> Array:
	var result: Array = []
	for family_value in _dictionary_array(definition.get("slot_types", [])):
		var family: Dictionary = family_value
		for format_value in _dictionary_array(definition.get("slot_formats", [])):
			var format: Dictionary = format_value
			var ids := {
				"type_id": str(family.get("id", "pinball")),
				"format_id": str(format.get("id", "classic_3_reel")),
				"cabinet_variant_id": "neon_magenta",
			}
			result.append(skin_for_machine(ids, definition))
	return result


func cabinet_identities(definition: Dictionary) -> Array:
	var result: Array = []
	for skin_value in all_skins(definition):
		var skin: Dictionary = skin_value
		result.append({
			"id": str(skin.get("cabinet_identity", "")),
			"family": str(skin.get("family", "")),
			"format_id": str(skin.get("format_id", "")),
			"title": str(skin.get("cabinet_title", "")),
			"topper_style": str(skin.get("topper_style", "")),
			"material": str(skin.get("material", "")),
			"motion_style": str(skin.get("motion_style", "")),
		})
	return result


func symbol_metadata(definition: Dictionary, family_id: String, symbol_id: String) -> Dictionary:
	var config_key := "slot_%s_config" % family_id
	var config: Dictionary = _copy_dict(definition.get(config_key, {}))
	for entry_value in _dictionary_array(config.get("symbols", [])):
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == symbol_id:
			return entry.duplicate(true)
	return {"id": symbol_id, "shape": "backplate", "colors": ["#1b2230", "#3f5269", "#6d88a8"]}


func variant_by_id(entries_value: Variant, variant_id: String) -> Dictionary:
	for entry_value in _dictionary_array(entries_value):
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == variant_id:
			return entry.duplicate(true)
	return {}


func _identity_for(family_id: String, format_id: String) -> Dictionary:
	var key := "%s:%s" % [family_id, format_id]
	match key:
		"pinball:classic_3_reel":
			return {
				"id": "em_bumper_drop",
				"title": "EM Bumper Drop",
				"feature_name": "Bumper Drop",
				"era": "1960s electromechanical",
				"material": "wood_brass_glass",
				"topper_style": "replay_backglass",
				"motion_style": "relay_chase",
				"silhouette": {"x": 36, "y": 18, "w": 888, "h": 494, "lean": 0},
				"topper_rect": {"x": 92, "y": 22, "w": 776, "h": 72},
				"reel_window": {"x": 270, "y": 104, "w": 420, "h": 106},
				"tease_panel": {"x": 72, "y": 116, "w": 160, "h": 220},
				"feature_panel": {"x": 708, "y": 112, "w": 176, "h": 224},
				"playfield_rect": {"x": 272, "y": 226, "w": 416, "h": 120},
				"belly_rect": {"x": 92, "y": 350, "w": 776, "h": 72},
				"result_strip": {"x": 116, "y": 370, "w": 728, "h": 40},
				"controls": {"x": 110, "y": 432, "w": 740, "h": 72},
				"palette": {"primary": "#3b2418", "secondary": "#15100c", "accent": "#c99242", "light": "#ffe48a", "trim": "#b77b35", "glass": "#9bd5ff", "shadow": "#060302"},
			}
		"pinball:line_5x3":
			return {
				"id": "lane_multiball",
				"title": "Lane Multiball",
				"feature_name": "Lane Multiball",
				"era": "1980s solid-state",
				"material": "painted_metal_dmd",
				"topper_style": "orange_dmd",
				"motion_style": "insert_lamp_wave",
				"silhouette": {"x": 26, "y": 12, "w": 908, "h": 508, "lean": 1},
				"topper_rect": {"x": 62, "y": 18, "w": 836, "h": 58},
				"reel_window": {"x": 246, "y": 92, "w": 468, "h": 208},
				"tease_panel": {"x": 54, "y": 92, "w": 168, "h": 260},
				"feature_panel": {"x": 738, "y": 92, "w": 160, "h": 260},
				"playfield_rect": {"x": 248, "y": 310, "w": 466, "h": 78},
				"belly_rect": {"x": 54, "y": 356, "w": 844, "h": 68},
				"result_strip": {"x": 72, "y": 374, "w": 808, "h": 40},
				"controls": {"x": 54, "y": 432, "w": 844, "h": 76},
				"palette": {"primary": "#20304d", "secondary": "#080b14", "accent": "#ff7a2f", "light": "#ffd45a", "trim": "#59d8ff", "glass": "#7ce3ff", "shadow": "#030511"},
			}
		"pinball:video_feature":
			return {
				"id": "full_table",
				"title": "Full Table",
				"feature_name": "Full Table",
				"era": "modern lcd",
				"material": "black_chrome_lcd",
				"topper_style": "rgb_lcd_crown",
				"motion_style": "orchestral_rgb_sweep",
				"silhouette": {"x": 18, "y": 8, "w": 924, "h": 516, "lean": 2},
				"topper_rect": {"x": 42, "y": 14, "w": 876, "h": 52},
				"reel_window": {"x": 62, "y": 78, "w": 508, "h": 290},
				"tease_panel": {"x": 592, "y": 78, "w": 128, "h": 290},
				"feature_panel": {"x": 732, "y": 72, "w": 170, "h": 312},
				"playfield_rect": {"x": 732, "y": 88, "w": 170, "h": 292},
				"belly_rect": {"x": 42, "y": 376, "w": 876, "h": 50},
				"result_strip": {"x": 56, "y": 382, "w": 848, "h": 38},
				"controls": {"x": 42, "y": 432, "w": 876, "h": 78},
				"palette": {"primary": "#141827", "secondary": "#05070f", "accent": "#6ff3ff", "light": "#ff4fd8", "trim": "#f8fafc", "glass": "#a7f3ff", "shadow": "#01020a"},
			}
		"buffalo:classic_3_reel":
			return {
				"id": "heritage",
				"title": "Heritage",
				"feature_name": "Stampede Free Games",
				"era": "mechanical western",
				"material": "dark_wood_brass",
				"topper_style": "brass_buffalo_head",
				"motion_style": "steam_snort_chase",
				"silhouette": {"x": 44, "y": 18, "w": 872, "h": 494, "lean": 0},
				"topper_rect": {"x": 112, "y": 22, "w": 736, "h": 66},
				"reel_window": {"x": 300, "y": 104, "w": 360, "h": 108},
				"tease_panel": {"x": 78, "y": 112, "w": 174, "h": 232},
				"feature_panel": {"x": 708, "y": 112, "w": 174, "h": 232},
				"playfield_rect": {"x": 286, "y": 228, "w": 388, "h": 108},
				"belly_rect": {"x": 92, "y": 346, "w": 776, "h": 80},
				"result_strip": {"x": 116, "y": 370, "w": 728, "h": 42},
				"controls": {"x": 104, "y": 432, "w": 752, "h": 72},
				"palette": {"primary": "#352110", "secondary": "#160d07", "accent": "#d09a42", "light": "#f3d27a", "trim": "#7b3f1a", "glass": "#ffd07a", "shadow": "#050201"},
			}
		"buffalo:line_5x3":
			return {
				"id": "ways",
				"title": "Ways",
				"feature_name": "Gold Stampede Lock",
				"era": "sunset ways",
				"material": "copper_sunset_glass",
				"topper_style": "day_dusk_backbox",
				"motion_style": "herd_stampede_wipe",
				"silhouette": {"x": 28, "y": 12, "w": 904, "h": 508, "lean": -1},
				"topper_rect": {"x": 54, "y": 18, "w": 852, "h": 64},
				"reel_window": {"x": 216, "y": 92, "w": 528, "h": 244},
				"tease_panel": {"x": 54, "y": 94, "w": 140, "h": 250},
				"feature_panel": {"x": 764, "y": 94, "w": 140, "h": 250},
				"playfield_rect": {"x": 214, "y": 346, "w": 530, "h": 42},
				"belly_rect": {"x": 54, "y": 356, "w": 852, "h": 68},
				"result_strip": {"x": 72, "y": 374, "w": 816, "h": 40},
				"controls": {"x": 54, "y": 432, "w": 852, "h": 76},
				"palette": {"primary": "#5b2c17", "secondary": "#130907", "accent": "#ef6a24", "light": "#ffd16a", "trim": "#f4c15d", "glass": "#ffba68", "shadow": "#050201"},
			}
		_:
			return {
				"id": "link_arena",
				"title": "Link Arena",
				"feature_name": "Sunset Wheel",
				"era": "flagship video link",
				"material": "bronze_led_arena",
				"topper_style": "jackpot_ladder_wheel",
				"motion_style": "arena_light_storm",
				"silhouette": {"x": 18, "y": 8, "w": 924, "h": 516, "lean": -2},
				"topper_rect": {"x": 38, "y": 12, "w": 884, "h": 56},
				"reel_window": {"x": 54, "y": 78, "w": 530, "h": 290},
				"tease_panel": {"x": 604, "y": 78, "w": 126, "h": 290},
				"feature_panel": {"x": 744, "y": 72, "w": 170, "h": 312},
				"playfield_rect": {"x": 744, "y": 88, "w": 170, "h": 292},
				"belly_rect": {"x": 42, "y": 376, "w": 876, "h": 50},
				"result_strip": {"x": 56, "y": 382, "w": 848, "h": 38},
				"controls": {"x": 42, "y": 432, "w": 876, "h": 78},
				"palette": {"primary": "#25140d", "secondary": "#070504", "accent": "#ffb44f", "light": "#65f0ff", "trim": "#d94c26", "glass": "#ffd26a", "shadow": "#010100"},
			}


func _window_rect(reel_count: int, row_count: int) -> Dictionary:
	var width := clampf(float(reel_count) * 86.0 + 28.0, 300.0, 590.0)
	var height := clampf(float(row_count) * 58.0 + 26.0, 96.0, 270.0)
	return {"x": 480.0 - width * 0.5, "y": 92.0, "w": width, "h": height}


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var source: Array = value as Array
	for entry in source:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
