extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const OUTPUT_PATH := "res://.tmp/roulette_rule_audit/report.json"

var failures: Array[String] = []
var stats := {
	"target_count": 0,
	"target_types": {},
	"payout_targets_checked": 0,
	"hitbox_targets_checked": 0,
}


class SurfaceHarness:
	extends RefCounted

	var surface_state: Dictionary = {}
	var hit_regions: Array = []
	var labels: Array = []
	var hovered_action := ""
	var hovered_index := -1

	func setup(state: Dictionary) -> void:
		surface_state = state.duplicate(true)
		hit_regions = []
		labels = []
		hovered_action = ""
		hovered_index = -1

	func surface_board_size() -> Vector2:
		return Vector2(900, 430)

	func surface_begin_design_space(_design_size: Vector2) -> void:
		pass

	func surface_begin_design_space_inset(design_size: Vector2, _inset: Vector2) -> void:
		surface_begin_design_space(design_size)

	func surface_end_design_space() -> void:
		pass

	func surface_flicker() -> float:
		return 0.0

	func surface_elapsed(_channel_id: String) -> float:
		return 999.0

	func surface_animation_active(_channel_id: String) -> bool:
		return false

	func surface_animation_duration(_channel_id: String) -> float:
		return 2.4

	func surface_animation_progress(_channel_id: String) -> float:
		return 1.0

	func surface_animation_active_id(_channel_id: String) -> String:
		return ""

	func surface_animation_metadata(_channel_id: String) -> Dictionary:
		return {}

	func surface_region_hovered(action: String, index: int = -1) -> bool:
		return hovered_action == action and (index < 0 or hovered_index == index)

	func surface_native_action_selected(_action: String) -> bool:
		return false

	func surface_label(text: String, _pos: Vector2, _font_size: int, _color: Color) -> void:
		labels.append(text)

	func surface_label_plain(text: String, _pos: Vector2, _font_size: int, _color: Color) -> void:
		labels.append(text)

	func surface_label_centered(text: String, _rect: Rect2, _font_size: int, _color: Color) -> void:
		labels.append(text)

	func surface_label_centered_plain(text: String, _rect: Rect2, _font_size: int, _color: Color) -> void:
		labels.append(text)

	func surface_title(text: String, _pos: Vector2, _color: Color) -> void:
		labels.append(text)

	func surface_add_hit(rect: Rect2, action: String, index: int = -1) -> void:
		hit_regions.append({"rect": rect, "action": action, "index": index})

	func surface_add_invisible_hit(rect: Rect2, action: String, index: int = -1) -> void:
		surface_add_hit(rect, action, index)

	func surface_add_exact_hit(rect: Rect2, action: String, index: int = -1) -> void:
		surface_add_hit(rect, action, index)

	func surface_add_exact_invisible_hit(rect: Rect2, action: String, index: int = -1) -> void:
		surface_add_invisible_hit(rect, action, index)

	func draw_rect(_rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_circle(_position: Vector2, _radius: float, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_line(_from: Vector2, _to: Vector2, _color: Color, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_polygon(_points: Array, _colors: Array, _uvs: Array = [], _texture: Texture2D = null) -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	for error in library.validation_errors:
		failures.append("ContentLibrary validation error: %s" % error)
	var definition := library.game("roulette")
	if definition.is_empty():
		failures.append("Roulette definition was not found.")
		_finish()
		return
	var module_script: Script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("Roulette module could not be loaded.")
		_finish()
		return
	var instance = module_script.new()
	if not instance is GameModule:
		failures.append("Roulette module does not extend GameModule.")
		_finish()
		return
	var game: GameModule = instance
	game.setup(definition, library)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("ROULETTE-RULE-AUDIT")
	run_state.bankroll = 1000
	var environment := {
		"id": "roulette_rule_audit_room",
		"display_name": "Roulette Rule Audit Room",
		"depth": 4,
		"game_ids": ["roulette"],
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 200},
		"security_profile": {"strictness": "high"},
	}
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("roulette_rule_table"))
	environment["game_states"] = {"roulette": table}
	run_state.current_environment = environment.duplicate(true)
	var surface := game.surface_state(run_state, environment, {})
	var targets := _dictionary_array(surface.get("bet_targets", []))
	if str(surface.get("variant", "")) != "american_double_zero":
		failures.append("Roulette surface did not expose the explicit American double-zero variant.")
	if not _dictionary_array(surface.get("recent_numbers", [])).is_empty():
		failures.append("Roulette rule audit surface should start with empty recent-number history.")
	stats["target_count"] = targets.size()
	_audit_target_counts(targets)
	_audit_hitbox_priority(game, surface, targets)
	_audit_every_target_settles(game, table, targets)
	_audit_zero_rules(game, table, targets)
	_finish()


func _audit_target_counts(targets: Array) -> void:
	var counts: Dictionary = {}
	for target in targets:
		var target_type := str((target as Dictionary).get("type", ""))
		counts[target_type] = int(counts.get(target_type, 0)) + 1
	stats["target_types"] = counts
	var expected := {
		"straight": 38,
		"split": 58,
		"street": 12,
		"corner": 22,
		"six_line": 11,
		"trio": 3,
		"top_line": 1,
		"dozen": 3,
		"column": 3,
		"red": 1,
		"black": 1,
		"odd": 1,
		"even": 1,
		"low": 1,
		"high": 1,
	}
	for key in expected.keys():
		if int(counts.get(key, 0)) != int(expected.get(key, 0)):
			failures.append("Roulette target count for %s was %d, expected %d." % [key, int(counts.get(key, 0)), int(expected.get(key, 0))])
	if targets.size() != 157:
		failures.append("Roulette exposed %d betting targets, expected 157." % targets.size())


func _audit_every_target_settles(game: GameModule, table: Dictionary, targets: Array) -> void:
	for i in range(targets.size()):
		var target: Dictionary = targets[i]
		var numbers := _string_array(target.get("numbers", []))
		if numbers.is_empty():
			failures.append("Roulette target %d has no covered numbers." % i)
			continue
		var bet := target.duplicate(true)
		bet["stake"] = 2
		var settled := _dictionary_array(game.call("_settle_roulette_bets", numbers[0], [bet], table))
		if settled.size() != 1:
			failures.append("Roulette target %s did not settle exactly once." % str(target.get("id", i)))
			continue
		var result: Dictionary = settled[0]
		var expected_delta := 2 * int(target.get("payout", 0))
		if int(result.get("bankroll_delta", 0)) != expected_delta:
			failures.append("Roulette target %s paid %d on %s, expected %d." % [str(target.get("id", i)), int(result.get("bankroll_delta", 0)), numbers[0], expected_delta])
		if int(result.get("celebration_score", 0)) <= 0:
			failures.append("Roulette target %s won without proportional celebration metadata." % str(target.get("id", i)))
		stats["payout_targets_checked"] = int(stats.get("payout_targets_checked", 0)) + 1


func _audit_hitbox_priority(game: GameModule, surface: Dictionary, targets: Array) -> void:
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	if not bool(game.draw_surface(harness, surface, {"contract_harness": true})):
		failures.append("Roulette draw_surface failed during hitbox audit.")
		return
	if not harness.labels.has("RECENT"):
		failures.append("Roulette renderer did not draw a recent-number panel.")
	var board := Rect2(Vector2.ZERO, Vector2(900, 430))
	var bet_hits: Dictionary = {}
	for hit_value in harness.hit_regions:
		if typeof(hit_value) != TYPE_DICTIONARY:
			continue
		var hit: Dictionary = hit_value
		if str(hit.get("action", "")) != "roulette_bet":
			continue
		bet_hits[int(hit.get("index", -1))] = hit.get("rect", Rect2())
	for i in range(targets.size()):
		var target: Dictionary = targets[i]
		var target_rect := _rect_from_dict(target.get("rect", {}))
		var target_id := "%s #%d" % [str(target.get("id", target.get("type", "bet"))), i]
		if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
			failures.append("Roulette target %s has an empty hitbox." % target_id)
			continue
		if target_rect.position.x < -0.1 or target_rect.position.y < -0.1 or target_rect.end.x > board.end.x + 0.1 or target_rect.end.y > board.end.y + 0.1:
			failures.append("Roulette target %s hitbox is outside the board: %s." % [target_id, str(target_rect)])
		if not bet_hits.has(i):
			failures.append("Roulette target %s did not render a hit region." % target_id)
			continue
		var hit_rect: Rect2 = bet_hits.get(i, Rect2())
		if not _rect_close(hit_rect, target_rect):
			failures.append("Roulette target %s rendered hitbox %s but advertised %s." % [target_id, str(hit_rect), str(target_rect)])
		var center := target_rect.get_center()
		var top_hit := _top_hit_at(harness.hit_regions, center)
		if top_hit.is_empty():
			failures.append("Roulette target %s center is not clickable." % target_id)
			continue
		if str(top_hit.get("action", "")) != "roulette_bet" or int(top_hit.get("index", -1)) != i:
			failures.append("Roulette target %s center resolves to %s #%d instead." % [target_id, str(top_hit.get("action", "")), int(top_hit.get("index", -1))])
			continue
		stats["hitbox_targets_checked"] = int(stats.get("hitbox_targets_checked", 0)) + 1


func _audit_zero_rules(game: GameModule, table: Dictionary, targets: Array) -> void:
	var red_target := _first_target(targets, "red")
	if red_target.is_empty():
		failures.append("Roulette red outside target was missing.")
		return
	red_target["stake"] = 4
	var zero_loss := _dictionary_array(game.call("_settle_roulette_bets", "0", [red_target], table))
	if zero_loss.is_empty() or int((zero_loss[0] as Dictionary).get("bankroll_delta", 0)) != -4:
		failures.append("American roulette zero did not take the full even-money outside bet.")
	var partage_table := table.duplicate(true)
	var rules: Dictionary = (partage_table.get("rules", {}) as Dictionary).duplicate(true)
	rules["la_partage"] = true
	partage_table["rules"] = rules
	var partage_loss := _dictionary_array(game.call("_settle_roulette_bets", "0", [red_target], partage_table))
	if partage_loss.is_empty() or int((partage_loss[0] as Dictionary).get("bankroll_delta", 0)) != -2:
		failures.append("La Partage zero did not halve the even-money outside loss.")


func _first_target(targets: Array, target_type: String) -> Dictionary:
	for target in targets:
		if str((target as Dictionary).get("type", "")) == target_type:
			return (target as Dictionary).duplicate(true)
	return {}


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		result.append(str(entry))
	return result


func _top_hit_at(hit_regions: Array, point: Vector2) -> Dictionary:
	for i in range(hit_regions.size() - 1, -1, -1):
		if typeof(hit_regions[i]) != TYPE_DICTIONARY:
			continue
		var hit: Dictionary = hit_regions[i]
		var rect: Rect2 = hit.get("rect", Rect2())
		if rect.has_point(point):
			return hit.duplicate(true)
	return {}


func _rect_from_dict(value: Variant) -> Rect2:
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("w", 0.0)), float(data.get("h", 0.0)))


func _rect_close(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) <= 0.01 and a.size.distance_to(b.size) <= 0.01


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var report := {
		"tool": "roulette_rule_audit",
		"passed": failures.is_empty(),
		"failure_count": failures.size(),
		"failures": failures,
		"stats": stats,
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT_PATH), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
