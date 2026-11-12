extends SceneTree

const Appearance := preload("res://scripts/ui/character_appearance_snapshot.gd")
const Avatar := preload("res://scripts/ui/character_avatar_view.gd")
const TableVisuals := preload("res://scripts/games/table_game_visuals.gd")
const RunState := preload("res://scripts/core/run_state.gd")
const ContentLibrary := preload("res://scripts/core/content_library.gd")

class SurfaceProbe:
	extends RefCounted
	var commands: Array = []
	func draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0) -> void:
		commands.append(["rect", rect, color, filled, width])
	func draw_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0) -> void:
		commands.append(["line", from, to, color, width])
	func surface_label(label: String, pos: Vector2, font_size: int, color: Color) -> void:
		commands.append(["label", label, pos, font_size, color])

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _run() -> void:
	var characters: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/characters.json"))
	var items: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json"))
	var library := ContentLibrary.new()
	library.items = items.duplicate(true)
	var original_library := var_to_str(library.items)
	var run := RunState.new()
	run.inventory = ["xray_glasses", "jazz_drummer_glasses", "cheap_sunglasses", "freds_poker_hat", "tab_detector"]
	run.rng_seed = 5321
	run.rng_state = 87531
	var original_run := var_to_str(run.to_dict())
	seed(73915)
	var expected_random := randi()
	seed(73915)
	var player := Appearance.from_run(run, library)
	_expect(randi() == expected_random, "Snapshot construction consumed global RNG")
	_expect(var_to_str(run.to_dict()) == original_run, "Snapshot construction mutated run/save/RNG")
	_expect(var_to_str(library.items) == original_library, "Snapshot construction mutated catalog")
	_expect(player["model"] == Appearance.DEFAULT_MODEL, "Player did not use canonical model defaults")
	_expect(player["character_id"] == "", "Player borrowed an NPC identity")
	_expect(player["accessories"].is_empty(), "Owned passive glasses became equipped")
	_expect(player["active_item_status"] == "none", "Empty active slot was not empty")

	run.active_item_id = "tab_detector"
	var active := Appearance.from_run(run, library)
	_expect(active["active_item_status"] == "unsupported_visual", "Valid detector must report unsupported visual")
	_expect(active["unsupported_visual_ids"] == ["tab_detector"] and active["accessories"].is_empty(), "Unsupported active detector misrepresented")
	run.active_item_id = "xray_glasses"
	var passive_active := Appearance.from_run(run, library)
	_expect(passive_active["active_item_status"] == "not_active_item" and passive_active["accessories"].is_empty(), "Invalid passive active selection drew glasses")
	for passive_id in ["cheap_sunglasses", "freds_poker_hat"]:
		run.active_item_id = passive_id
		var invalid_active := Appearance.from_run(run, library)
		_expect(invalid_active["active_item_status"] == "not_active_item" and invalid_active["accessories"].is_empty(), "Catalog alias bypassed active-slot validity: " + passive_id)
	run.active_item_id = "not_carried"
	_expect(Appearance.from_run(run, library)["active_item_status"] == "not_carried", "Uncarried selection accepted")
	run.inventory.append("missing_definition")
	run.active_item_id = "missing_definition"
	_expect(Appearance.from_run(run, library)["active_item_status"] == "unknown_item", "Missing active definition accepted")
	# A supplied explicit future definition can opt into existing wearable visuals.
	# This is a fixture, not a new catalog item or invented saved wearable slot.
	var supported_item := {"id": "explicit_active_glasses", "environment_prop": "glasses", "effect": {"active_item": true}}
	var supported := Appearance.from_run({"inventory": [supported_item["id"]], "active_item_id": supported_item["id"]}, {"items": [supported_item]})
	_expect(supported["active_item_status"] == "supported" and supported["accessories"][0]["kind"] == "glasses", "Explicit active-item visual not resolved")
	var malformed := Appearance.from_character({"model": {
		"skin_color": "not-a-color", "hair_color": Color(NAN, 0.0, 0.0),
		"jacket_color": Color(4.0, -2.0, 0.5, 0.0), "scale": INF, "silhouette": "unknown",
	}})
	_expect(malformed["model"]["skin_color"] == Appearance.DEFAULT_MODEL["skin_color"], "Invalid color fallback")
	_expect(malformed["model"]["hair_color"] == Appearance.DEFAULT_MODEL["hair_color"], "Non-finite color fallback")
	_expect(malformed["model"]["jacket_color"] == "#ff0080", "Color not clamped/opaque")
	_expect(malformed["model"]["scale"] == 1.0 and malformed["model"]["silhouette"] == "coat", "Invalid scale/silhouette fallback")
	_expect(Appearance.from_character({"scale": 9.0})["model"]["scale"] == 1.25, "High scale unbounded")
	_expect(Appearance.from_character({"scale": -9.0})["model"]["scale"] == 0.75, "Low scale unbounded")

	var signatures: Dictionary = {}
	for definition in characters:
		var saved := var_to_str(definition)
		var appearance := Appearance.from_character(definition)
		_expect(appearance["character_id"] == definition["id"], "Character identity lost: %s" % definition["id"])
		for field in ["skin_color", "hair_color", "jacket_color", "accent_color", "silhouette"]:
			_expect(appearance["model"][field] == definition["model"][field], "Authored model changed: %s/%s" % [definition["id"], field])
		var surface := SurfaceProbe.new()
		Avatar.draw_avatar(surface, appearance, Avatar.DESIGN_SIZE, "idle", 0.0)
		signatures[var_to_str(surface.commands)] = true
		_expect(var_to_str(definition) == saved, "Character or draw mutated source")
	_expect(signatures.size() > 3, "Existing character definitions rendered identically")
	var sunglasses_definition: Dictionary = {}
	var hat_definition: Dictionary = {}
	for item in items:
		if str(item.get("id", "")) == "cheap_sunglasses": sunglasses_definition = item
		if str(item.get("id", "")) == "freds_poker_hat": hat_definition = item
	_expect(sunglasses_definition.get("environment_prop", "") == "sunglasses", "Missing actual sunglasses catalog fixture")
	_expect(hat_definition.get("environment_prop", "") == "poker_hat", "Missing actual poker hat catalog fixture")
	var actual_equipped := Appearance.from_character(characters[0], [sunglasses_definition, hat_definition])
	_expect(actual_equipped["accessories"] == [
		{"kind": "glasses", "item_id": "cheap_sunglasses"},
		{"kind": "cap", "item_id": "freds_poker_hat"},
	], "Actual catalog sunglasses/poker hat aliases did not resolve")
	_expect(actual_equipped["unsupported_visual_ids"].is_empty(), "Supported catalog aliases marked unsupported")
	_expect(actual_equipped["model"] == Appearance.from_character(characters[0])["model"], "Catalog equipment aliases replaced character identity/model")

	var explicit_equipment := [
		{"id": "xray_glasses", "environment_prop": "glasses"},
		{"id": "explicit_cap", "environment_prop": "cap"},
		{"id": "explicit_rings", "environment_prop": "rings"},
		{"id": "tab_detector", "environment_prop": "scanner"},
	]
	var selected: Dictionary = characters[0].duplicate(true)
	var appearance := Appearance.from_character(selected, explicit_equipment)
	_expect(appearance["accessories"].size() == 3 and appearance["unsupported_visual_ids"] == ["tab_detector"], "Explicit accessories and unsupported IDs not separated")
	selected["model"]["skin_color"] = "#ffffff"
	explicit_equipment[0]["environment_prop"] = "scanner"
	_expect(appearance["model"]["skin_color"] == characters[0]["model"]["skin_color"] and appearance["accessories"][0]["kind"] == "glasses", "Snapshot aliases caller model or equipment")
	var view := Avatar.new()
	root.add_child(view)
	view.size = Vector2(224, 240)
	view.set_appearance(appearance)
	var frozen := view.snapshot()
	appearance["model"]["hair_color"] = "#ffffff"
	appearance["accessories"][0]["kind"] = "rings"
	var returned := view.snapshot()
	returned["model"]["hair_color"] = "#000000"
	returned["accessories"].clear()
	_expect(view.snapshot() == frozen, "View retains mutable snapshot references")
	_expect(view.foot_position() == Vector2(112, 240), "Foot anchor not bottom center")
	_expect(view.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Avatar intercepts UI input")
	view.set_pose("walking", 0.2)
	_expect(view.pose_snapshot() == {"pose": "walking", "clock": 0.2, "locomotion": {}}, "Pose API lost caller clock")
	view.set_pose("unrecognized", NAN)
	_expect(view.pose_snapshot() == {"pose": "idle", "clock": 0.0, "locomotion": {}}, "Pose inputs not sanitized")
	_expect(view.snapshot() == frozen, "Pose mutated appearance")

	var first := SurfaceProbe.new()
	var repeated := SurfaceProbe.new()
	var moved := SurfaceProbe.new()
	Avatar.draw_avatar(first, frozen, Avatar.DESIGN_SIZE, "walk", 0.0)
	Avatar.draw_avatar(repeated, frozen, Avatar.DESIGN_SIZE, "walk", 0.0)
	Avatar.draw_avatar(moved, frozen, Avatar.DESIGN_SIZE, "walk", 0.2)
	_expect(first.commands == repeated.commands, "Same walk clock not deterministic")
	_expect(first.commands != moved.commands, "Walk has no visible movement")
	_expect(first.commands[1] != moved.commands[1], "Walk legs did not move")
	var small := SurfaceProbe.new()
	Avatar.draw_avatar(small, frozen, Avatar.DESIGN_SIZE * 0.5, "idle", 0.0)
	_expect(small.commands.size() == first.commands.size(), "Responsive view lost details")
	var empty := SurfaceProbe.new()
	Avatar.draw_avatar(empty, frozen, Vector2.ZERO, "idle", 0.0)
	_expect(empty.commands.is_empty(), "Zero-size view drew outside bounds")
	_check_shared_painter(frozen)
	_check_away_painter(characters, frozen)
	view.free()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("CHARACTER_AVATAR_VIEW_CHECK PASS: %d assertions; %d real character definitions; canonical painter reuse, bounded models, explicit layered accessories, no inferred owned wearables, active-slot validity, immutable snapshots and deterministic walking" % [_checks, characters.size()])
	quit(0)


func _check_shared_painter(appearance: Dictionary) -> void:
	for silhouette in ["coat", "cap", "glasses", "rings"]:
		var old_defaults := SurfaceProbe.new()
		var explicit_defaults := SurfaceProbe.new()
		TableVisuals._draw_table_character(old_defaults, {"silhouette": silhouette}, Vector2(56, 120), 1.0, 0.3)
		TableVisuals._draw_table_character(explicit_defaults, {"silhouette": silhouette, "accessories": [], "walk_stride": 0.0, "show_shadow": true}, Vector2(56, 120), 1.0, 0.3)
		_expect(old_defaults.commands == explicit_defaults.commands, "Legacy default changed: " + silhouette)
	var resting := SurfaceProbe.new()
	var legacy_walk := SurfaceProbe.new()
	var explicit_walk := SurfaceProbe.new()
	var advancing_walk := SurfaceProbe.new()
	TableVisuals._draw_table_character(resting, {"pose": "idle"}, Vector2(56, 120), 1.0, 0.3)
	TableVisuals._draw_table_character(legacy_walk, {"pose": "walk"}, Vector2(56, 120), 1.0, 0.3)
	TableVisuals._draw_table_character(explicit_walk, {"pose": "walk", "walk_stride": 0.0}, Vector2(56, 120), 1.0, 0.3)
	TableVisuals._draw_table_character(advancing_walk, {"pose": "walk", "walk_stride": 0.6}, Vector2(56, 120), 1.0, 0.3)
	_expect(legacy_walk.commands == resting.commands, "Legacy walk caller without explicit stride changed resting arm commands")
	_expect(explicit_walk.commands != legacy_walk.commands, "Explicit zero-stride walk did not opt into walking arms")
	_expect(advancing_walk.commands != explicit_walk.commands, "Explicit walking stride did not move arms")
	var model: Dictionary = appearance["model"]
	var scale_value := lerpf(0.90, 1.08, (float(model["scale"]) - 0.75) / 0.50)
	var shared := SurfaceProbe.new()
	TableVisuals._draw_table_character(shared, {
		"skin": Color(model["skin_color"]), "hair": Color(model["hair_color"]),
		"jacket": Color(model["jacket_color"]), "accent": Color(model["accent_color"]),
		"silhouette": model["silhouette"], "accessories": ["glasses", "cap", "rings"],
		"sway_amount": 0.0, "show_shadow": false,
	}, Vector2(56, 120 - 29 * scale_value), scale_value, 0.0)
	var avatar := SurfaceProbe.new()
	Avatar.draw_avatar(avatar, appearance, Avatar.DESIGN_SIZE, "idle", 0.0)
	_expect(avatar.commands.slice(7) == shared.commands, "View did not render exact shared character painter commands")
	var glasses_count := 0
	var cap_count := 0
	var rings_count := 0
	for command in shared.commands:
		if command[0] != "rect":
			continue
		var rect: Rect2 = command[1]
		if not bool(command[3]): glasses_count += 1
		if rect.size.is_equal_approx(Vector2(32, 5) * scale_value): cap_count += 1
		if command[2] == TableVisuals.C_YELLOW: rings_count += 1
	_expect(glasses_count == 2 and cap_count == 1 and rings_count == 1, "Layered glasses + cap + rings missing or duplicated")


func _check_away_painter(characters: Array, equipped: Dictionary) -> void:
	for definition in characters:
		var appearance := Appearance.from_character(definition)
		var immutable := var_to_str(appearance)
		var first := SurfaceProbe.new()
		var moving := SurfaceProbe.new()
		Avatar.draw_avatar(first, appearance, Avatar.DESIGN_SIZE, "walk_away", 0.1)
		Avatar.draw_avatar(moving, appearance, Avatar.DESIGN_SIZE, "walk_away", 0.25)
		var model: Dictionary = appearance["model"]
		var scale_value := lerpf(0.90, 1.08, (float(model["scale"]) - 0.75) / 0.50)
		var hair_head := false
		for command in first.commands:
			if command[0] == "rect" and Rect2(command[1]).size.is_equal_approx(Vector2(24, 24) * scale_value):
				hair_head = command[2] == Color(model["hair_color"])
		_expect(hair_head, "Away pose retains authored back-of-head color: " + str(definition["id"]))
		_expect(first.commands != moving.commands, "Away pose keeps canonical walking stride: " + str(definition["id"]))
		_expect(var_to_str(appearance) == immutable, "Away drawing mutates no identity/equipment: " + str(definition["id"]))
	var front := SurfaceProbe.new()
	var back := SurfaceProbe.new()
	Avatar.draw_avatar(front, equipped, Avatar.DESIGN_SIZE, "idle", 0.0)
	Avatar.draw_avatar(back, equipped, Avatar.DESIGN_SIZE, "away_idle", 0.0)
	var front_glasses := 0
	var back_glasses := 0
	for command in front.commands:
		if command[0] == "rect" and not bool(command[3]): front_glasses += 1
	for command in back.commands:
		if command[0] == "rect" and not bool(command[3]): back_glasses += 1
	_expect(front_glasses == 2 and back_glasses == 0, "Front glasses stay equipped but do not float on back of head")
	var view := Avatar.new()
	view.set_appearance(equipped)
	view.set_pose("walk_away", 0.2)
	_expect(view.pose_snapshot() == {"pose":"walk_away", "clock":0.2, "locomotion":{}}, "Away pose keeps explicit caller clock")
	view.set_pose("away_idle", 0.3)
	_expect(view.pose_snapshot() == {"pose":"away_idle", "clock":0.3, "locomotion":{}} and view.snapshot() == equipped, "Away idle keeps identity and explicit clock")
	view.free()
