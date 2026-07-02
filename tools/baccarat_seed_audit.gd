extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var failures: Array = []
var stats: Dictionary = {}


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

	func surface_label_centered(text: String, _rect: Rect2, _font_size: int, _color: Color) -> void:
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
	var hands := 400
	var seed_text := "BACCARAT-AUDIT-20260624"
	var output_path := "res://.tmp/baccarat_seed_audit/report.json"
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--hands="):
			hands = maxi(1, int(text.trim_prefix("--hands=")))
		elif text.begins_with("--seed="):
			seed_text = text.trim_prefix("--seed=")
		elif text.begins_with("--output="):
			output_path = text.trim_prefix("--output=")

	stats = {
		"seed": seed_text,
		"hands": hands,
		"generated_tables": 0,
		"surface_checks": 0,
		"draw_checks": 0,
		"resolved_hands": 0,
		"max_resolve_ms": 0.0,
		"outcomes": {"player": 0, "banker": 0, "tie": 0},
		"player_pairs": 0,
		"banker_pairs": 0,
		"naturals": 0,
		"reshuffles": 0,
		"bankroll_delta_flat_banker": 0,
		"cards_used": 0,
		"hands_log": [],
	}

	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	for error in library.validation_errors:
		failures.append("ContentLibrary validation error: %s" % error)
	var game := _load_baccarat(library)
	if game == null:
		_write_report(output_path)
		_print_summary()
		await _finish(1)
		return

	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000
	var environment := _audit_environment()
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("baccarat_audit_table"))
	environment["game_states"] = {"baccarat": table}
	run_state.current_environment = environment.duplicate(true)
	stats["generated_tables"] = 1
	_audit_generated_table(table)
	_audit_surface(game, run_state, environment)

	for i in range(hands):
		_run_hand(game, run_state, environment, i)

	_finalize_rates()
	_write_report(output_path)
	_print_summary()
	await _finish(0 if failures.is_empty() else 1)


func _finish(exit_code: int) -> void:
	await process_frame
	quit(exit_code)


func _load_baccarat(library: ContentLibrary) -> GameModule:
	var definition: Dictionary = library.game("baccarat")
	if definition.is_empty():
		failures.append("Baccarat definition was not found.")
		return null
	var module_path := str(definition.get("module_path", ""))
	var module_script: Script = load(module_path)
	if module_script == null:
		failures.append("Baccarat module could not be loaded from %s." % module_path)
		return null
	var instance = module_script.new()
	if not instance is GameModule:
		failures.append("Baccarat module does not extend GameModule.")
		return null
	var game: GameModule = instance
	game.setup(definition, library)
	return game


func _audit_environment() -> Dictionary:
	return {
		"id": "baccarat_audit_room",
		"display_name": "Baccarat Audit Room",
		"depth": 3,
		"game_ids": ["baccarat"],
		"economic_profile": {"stake_floor": 20, "stake_ceiling": 200},
		"security_profile": {"strictness": "boss"},
		"turns": 0,
	}


func _audit_generated_table(table: Dictionary) -> void:
	if str(table.get("schema", "")) != "baccarat_table_state":
		failures.append("Generated baccarat table used an unexpected schema.")
	if int(table.get("deck_count", 0)) != 8:
		failures.append("Generated baccarat table was not eight-deck.")
	if _dictionary_array(table.get("patrons", [])).is_empty():
		failures.append("Generated baccarat table omitted patrons.")
	if _dict(table.get("dealer_profile", {})).is_empty():
		failures.append("Generated baccarat table omitted dealer profile.")
	var rules := _dict(table.get("rules", {}))
	if str(rules.get("variant", "")) != "mini_baccarat":
		failures.append("Generated baccarat table did not declare mini-baccarat rules.")
	if not is_equal_approx(float(rules.get("banker_commission_rate", 0.0)), 0.05):
		failures.append("Generated baccarat table did not declare 5% Banker commission.")
	if int(rules.get("tie_payout", 0)) != 8 or int(rules.get("player_pair_payout", 0)) != 11 or int(rules.get("banker_pair_payout", 0)) != 11:
		failures.append("Generated baccarat table did not expose standard Tie/Pair odds.")


func _audit_surface(game: GameModule, run_state: RunState, environment: Dictionary) -> void:
	stats["surface_checks"] = int(stats.get("surface_checks", 0)) + 1
	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "baccarat":
		failures.append("Baccarat surface renderer was not baccarat.")
	if not bool(surface.get("surface_controls_native", false)):
		failures.append("Baccarat surface did not expose native controls.")
	var targets := _dictionary_array(surface.get("bet_targets", []))
	if targets.size() < 5:
		failures.append("Baccarat surface exposed too few bet targets.")
	var road := _dict(surface.get("baccarat_road", {}))
	if str(road.get("type", "")) != "bead_plate" or int(road.get("rows", 0)) <= 0:
		failures.append("Baccarat surface omitted bead-plate road state.")
	var penetration := _dict(surface.get("shoe_penetration", {}))
	if int(penetration.get("total_cards", 0)) < 416 or int(penetration.get("remaining", 0)) <= 0:
		failures.append("Baccarat surface omitted shoe penetration state.")
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	if not bool(game.draw_surface(harness, surface, {"contract_harness": true})):
		failures.append("Baccarat draw_surface returned false.")
	else:
		stats["draw_checks"] = int(stats.get("draw_checks", 0)) + 1
	if _hit_count(harness, "baccarat_bet") < 5:
		failures.append("Baccarat renderer omitted one or more bet hit regions.")
	for action_id in ["baccarat_chip", "baccarat_read_shoe"]:
		if not _has_hit(harness, action_id):
			failures.append("Baccarat renderer omitted hit action %s." % action_id)
	if not harness.labels.has("BEAD PLATE"):
		failures.append("Baccarat renderer omitted the bead-plate label.")


func _run_hand(game: GameModule, run_state: RunState, environment: Dictionary, index: int) -> void:
	var before_reshuffle := int(((environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary).get("reshuffle_count", 0))
	var started := Time.get_ticks_usec()
	var result: Dictionary = game.resolve_with_context(
		"deal_baccarat",
		20,
		run_state,
		environment,
		run_state.create_rng("baccarat_audit_hand_%05d" % index),
		{"selected_chip": 20, "baccarat_bets": {"banker": 20}}
	)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	stats["max_resolve_ms"] = maxf(float(stats.get("max_resolve_ms", 0.0)), elapsed_ms)
	if not bool(result.get("ok", false)):
		failures.append("Hand %d failed to resolve: %s" % [index, str(result.get("message", ""))])
		return
	stats["resolved_hands"] = int(stats.get("resolved_hands", 0)) + 1
	var hand: Dictionary = _dict(result.get("baccarat_hand", {}))
	var winner := str(hand.get("winner", ""))
	var outcomes: Dictionary = stats.get("outcomes", {})
	outcomes[winner] = int(outcomes.get(winner, 0)) + 1
	stats["outcomes"] = outcomes
	if bool(hand.get("player_pair", false)):
		stats["player_pairs"] = int(stats.get("player_pairs", 0)) + 1
	if bool(hand.get("banker_pair", false)):
		stats["banker_pairs"] = int(stats.get("banker_pairs", 0)) + 1
	if bool(hand.get("natural", false)):
		stats["naturals"] = int(stats.get("naturals", 0)) + 1
	stats["cards_used"] = int(stats.get("cards_used", 0)) + int(hand.get("cards_used", 0))
	stats["bankroll_delta_flat_banker"] = int(stats.get("bankroll_delta_flat_banker", 0)) + int(result.get("bankroll_delta", 0))
	_check_hand_cards_unique(hand, index)
	_audit_hand_tableau(hand, index)
	var table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary)
	if int(table.get("shoe_remaining", 0)) < 0:
		failures.append("Hand %d produced negative shoe remaining." % index)
	var road := _dict(game.surface_state(run_state, environment, {"surface_time_msec": Time.get_ticks_msec() + 7000}).get("baccarat_road", {}))
	if int(road.get("visible_count", 0)) <= 0:
		failures.append("Hand %d did not publish road history after settlement." % index)
	var after_reshuffle := int(table.get("reshuffle_count", 0))
	if after_reshuffle > before_reshuffle:
		stats["reshuffles"] = int(stats.get("reshuffles", 0)) + (after_reshuffle - before_reshuffle)
	var log: Array = stats.get("hands_log", [])
	if log.size() < 400:
		log.append({
			"index": index,
			"winner": winner,
			"player_total": int(hand.get("player_total", 0)),
			"banker_total": int(hand.get("banker_total", 0)),
			"cards_used": int(hand.get("cards_used", 0)),
			"shoe_remaining": int(hand.get("shoe_remaining_after", 0)),
			"bankroll_delta": int(result.get("bankroll_delta", 0)),
		})
	stats["hands_log"] = log


func _check_hand_cards_unique(hand: Dictionary, index: int) -> void:
	var seen := {}
	for card in _card_array(hand.get("player_cards", [])) + _card_array(hand.get("banker_cards", [])):
		var key := "%d:%d:%d" % [int(card.get("deck", -1)), int(card.get("suit", -1)), int(card.get("rank", -1))]
		if seen.has(key):
			failures.append("Hand %d dealt duplicate card identity %s." % [index, key])
		seen[key] = true


func _audit_hand_tableau(hand: Dictionary, index: int) -> void:
	var player_initial := int(hand.get("player_initial_total", -1))
	var banker_initial := int(hand.get("banker_initial_total", -1))
	var natural := player_initial >= 8 or banker_initial >= 8
	if bool(hand.get("natural", false)) != natural:
		failures.append("Hand %d natural flag did not match initial totals." % index)
	var expected_player_draw := not natural and player_initial <= 5
	if bool(hand.get("player_drew", false)) != expected_player_draw:
		failures.append("Hand %d Player draw flag did not match mini-baccarat tableau." % index)
	var expected_banker_draw := false
	if not natural:
		expected_banker_draw = _expected_banker_draw(
			banker_initial,
			int(hand.get("player_third_value", -1)),
			not bool(hand.get("player_drew", false))
		)
	if bool(hand.get("banker_drew", false)) != expected_banker_draw:
		failures.append("Hand %d Banker draw flag did not match mini-baccarat tableau." % index)
	var events := _dictionary_array(hand.get("animation_events", []))
	if not natural and abs(int(hand.get("player_total", 0)) - int(hand.get("banker_total", 0))) <= 1:
		var found_squeeze := false
		for event_value in events:
			var event: Dictionary = event_value
			if str(event.get("type", "")) == "squeeze":
				found_squeeze = true
		if not found_squeeze:
			failures.append("Hand %d was close but did not include a squeeze reveal event." % index)


func _expected_banker_draw(banker_total: int, player_third_value: int, player_stood: bool) -> bool:
	if player_stood:
		return banker_total <= 5
	match banker_total:
		0, 1, 2:
			return true
		3:
			return player_third_value != 8
		4:
			return player_third_value >= 2 and player_third_value <= 7
		5:
			return player_third_value >= 4 and player_third_value <= 7
		6:
			return player_third_value == 6 or player_third_value == 7
		_:
			return false


func _finalize_rates() -> void:
	var hands := maxi(1, int(stats.get("resolved_hands", 0)))
	var outcomes: Dictionary = stats.get("outcomes", {})
	stats["rates"] = {
		"player": float(outcomes.get("player", 0)) / float(hands),
		"banker": float(outcomes.get("banker", 0)) / float(hands),
		"tie": float(outcomes.get("tie", 0)) / float(hands),
		"player_pair": float(stats.get("player_pairs", 0)) / float(hands),
		"banker_pair": float(stats.get("banker_pairs", 0)) / float(hands),
		"natural": float(stats.get("naturals", 0)) / float(hands),
	}
	stats["average_cards_used"] = float(stats.get("cards_used", 0)) / float(hands)
	stats["expected_anchors"] = {
		"banker": 0.4586,
		"player": 0.4462,
		"tie": 0.0952,
	}
	var rates: Dictionary = stats.get("rates", {})
	var bounds := {
		"banker": [0.36, 0.56],
		"player": [0.34, 0.54],
		"tie": [0.03, 0.17],
		"player_pair": [0.01, 0.14],
		"banker_pair": [0.01, 0.14],
		"natural": [0.18, 0.42],
	}
	for key in bounds.keys():
		var range_values: Array = bounds.get(key, [])
		var rate := float(rates.get(key, 0.0))
		if rate < float(range_values[0]) or rate > float(range_values[1]):
			failures.append("Baccarat %s rate %.3f outside audit bounds %.3f..%.3f." % [str(key), rate, float(range_values[0]), float(range_values[1])])
	var flat_banker_delta := int(stats.get("bankroll_delta_flat_banker", 0))
	if flat_banker_delta > 2000 or flat_banker_delta < -5000:
		failures.append("Flat Banker bankroll delta %+d was outside expected 400-hand drift bounds." % flat_banker_delta)


func _write_report(output_path: String) -> void:
	var report := {
		"ok": failures.is_empty(),
		"failures": failures,
		"stats": stats,
	}
	var absolute := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))


func _print_summary() -> void:
	print("Baccarat seed audit: %d hands, failures %d, max resolve %.3f ms." % [int(stats.get("resolved_hands", 0)), failures.size(), float(stats.get("max_resolve_ms", 0.0))])
	var rates: Dictionary = stats.get("rates", {})
	if not rates.is_empty():
		print("Rates: Banker %.3f Player %.3f Tie %.3f. Flat banker delta %+d." % [
			float(rates.get("banker", 0.0)),
			float(rates.get("player", 0.0)),
			float(rates.get("tie", 0.0)),
			int(stats.get("bankroll_delta_flat_banker", 0)),
		])
	for failure in failures:
		push_error(failure)


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _card_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _hit_count(harness: SurfaceHarness, action_prefix: String) -> int:
	var count := 0
	for hit_value in harness.hit_regions:
		if typeof(hit_value) == TYPE_DICTIONARY and str((hit_value as Dictionary).get("action", "")).begins_with(action_prefix):
			count += 1
	return count


func _has_hit(harness: SurfaceHarness, action_id: String) -> bool:
	for hit_value in harness.hit_regions:
		if typeof(hit_value) == TYPE_DICTIONARY and str((hit_value as Dictionary).get("action", "")) == action_id:
			return true
	return false
