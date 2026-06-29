extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var failures: Array = []
var warnings: Array = []
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
	var seed_count := 120
	var output_path := "res://.tmp/roulette_seed_audit/report.json"
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--seed-count="):
			seed_count = maxi(1, int(text.trim_prefix("--seed-count=")))
		elif text.begins_with("--output="):
			output_path = text.trim_prefix("--output=")

	stats = {
		"seed_count": seed_count,
		"generated_tables": 0,
		"surface_checks": 0,
		"spin_resolves": 0,
		"read_wheel_checks": 0,
		"draw_checks": 0,
		"fixture_passes": 0,
		"max_resolve_ms": 0.0,
		"max_command_ms": 0.0,
		"min_trajectory_frames": 999999,
		"max_trajectory_frames": 0,
		"outcomes": {},
		"target_types": {},
		"physics_ranges": {},
	}

	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	for error in library.validation_errors:
		failures.append("ContentLibrary validation error: %s" % error)

	var game := _load_roulette(library)
	if game == null:
		_write_report(output_path, seed_count)
		_print_summary()
		await _finish(1)
		return

	for i in range(seed_count):
		_run_generated_seed(game, i)
	_run_forced_payout_fixtures(game)

	_write_report(output_path, seed_count)
	_print_summary()
	await _finish(0 if failures.is_empty() else 1)


func _finish(exit_code: int) -> void:
	await process_frame
	quit(exit_code)


func _load_roulette(library: ContentLibrary) -> GameModule:
	var definition: Dictionary = library.game("roulette")
	if definition.is_empty():
		failures.append("Roulette definition was not found.")
		return null
	var module_path := str(definition.get("module_path", ""))
	var module_script: Script = load(module_path)
	if module_script == null:
		failures.append("Roulette module could not be loaded from %s." % module_path)
		return null
	var instance = module_script.new()
	if not instance is GameModule:
		failures.append("Roulette module does not extend GameModule.")
		return null
	var game: GameModule = instance
	game.setup(definition, library)
	return game


func _run_generated_seed(game: GameModule, index: int) -> void:
	var seed := "ROULETTE-AUDIT-%03d" % index
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	run_state.bankroll = 1000
	var environment := _audit_environment(index)
	run_state.current_environment = environment.duplicate(true)
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("roulette_table_%03d" % index))
	environment["game_states"] = {"roulette": table}
	run_state.current_environment = environment.duplicate(true)
	stats["generated_tables"] = int(stats.get("generated_tables", 0)) + 1
	_audit_generated_table(table, index)
	var surface := game.surface_state(run_state, environment, {})
	_audit_surface(game, surface, index)
	_audit_read_wheel(game, run_state, environment, index)
	_audit_spin(game, run_state, environment, surface, index)


func _audit_environment(index: int) -> Dictionary:
	var strictness_values := ["low", "private", "high", "boss", "uneven"]
	return {
		"id": "roulette_audit_room_%03d" % index,
		"display_name": "Roulette Audit Room %03d" % index,
		"depth": index % 4,
		"game_ids": ["roulette"],
		"economic_profile": {"stake_floor": 1 + (index % 3), "stake_ceiling": 120 + (index % 5) * 20},
		"security_profile": {"strictness": strictness_values[index % strictness_values.size()]},
		"turns": index % 4,
	}


func _audit_generated_table(table: Dictionary, index: int) -> void:
	if str(table.get("schema", "")) != "roulette_table_state":
		failures.append("Seed %d generated an unexpected roulette schema." % index)
	var sequence := _string_array(table.get("wheel_sequence", []))
	if sequence.size() != 38 or not sequence.has("0") or not sequence.has("00"):
		failures.append("Seed %d did not generate a standard American wheel sequence." % index)
	var rules: Dictionary = _dict(table.get("rules", {}))
	if int(rules.get("zero_count", 0)) != 2:
		failures.append("Seed %d did not expose double-zero roulette rules." % index)
	var profile: Dictionary = _dict(table.get("physics_profile", {}))
	for key in ["ball_initial_omega_min", "ball_initial_omega_max", "ball_angular_decel_min", "ball_angular_decel_max", "rotor_initial_omega_min", "rotor_initial_omega_max", "diamond_count", "diamond_scatter_degrees", "pocket_depth", "micro_scatter"]:
		if not profile.has(key):
			failures.append("Seed %d physics profile missing %s." % [index, key])
		else:
			_count_range("physics_ranges", key, float(profile.get(key, 0.0)))
	if (_dictionary_array(table.get("patrons", []))).is_empty():
		failures.append("Seed %d did not generate roulette patrons." % index)
	if _dict(table.get("dealer_profile", {})).is_empty():
		failures.append("Seed %d did not generate a roulette dealer profile." % index)


func _audit_surface(game: GameModule, surface: Dictionary, index: int) -> void:
	stats["surface_checks"] = int(stats.get("surface_checks", 0)) + 1
	if str(surface.get("surface_renderer", "")) != "roulette":
		failures.append("Seed %d surface renderer was not roulette." % index)
	if not bool(surface.get("surface_controls_native", false)):
		failures.append("Seed %d did not expose native roulette controls." % index)
	var targets := _dictionary_array(surface.get("bet_targets", []))
	if targets.size() < 140:
		failures.append("Seed %d exposed too few roulette bet targets: %d." % [index, targets.size()])
	for target in targets:
		_count_key("target_types", str((target as Dictionary).get("type", "")))
	for target_type in ["straight", "split", "street", "corner", "six_line", "trio", "top_line", "dozen", "column", "red", "black", "odd", "even", "low", "high"]:
		if _target_index(targets, target_type) < 0:
			failures.append("Seed %d missing roulette target type %s." % [index, target_type])
	var audio: Dictionary = _dict(surface.get("surface_audio", {}))
	var sync: Dictionary = _dict(audio.get("state_sync", {}))
	if str(audio.get("profile_id", "")) != "roulette_table" or str(sync.get("method", "")) != "roulette_table_state":
		failures.append("Seed %d omitted roulette surface audio profile/sync metadata." % index)
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	if not bool(game.draw_surface(harness, surface, {"contract_harness": true})):
		failures.append("Seed %d roulette draw_surface returned false." % index)
	else:
		stats["draw_checks"] = int(stats.get("draw_checks", 0)) + 1
	if _hit_count(harness, "roulette_bet") < targets.size():
		failures.append("Seed %d roulette renderer did not expose every bet target as a hit region." % index)
	for action_id in ["roulette_read_wheel", "roulette_chip"]:
		if not _has_hit(harness, action_id):
			failures.append("Seed %d roulette renderer omitted hit action %s." % [index, action_id])


func _audit_read_wheel(game: GameModule, run_state: RunState, environment: Dictionary, index: int) -> void:
	var command: Dictionary = game.surface_action_command("roulette_read_wheel", 0, false, {}, run_state, environment)
	if not bool(command.get("handled", false)) or str(command.get("action_id", "")) != "read_wheel_bias":
		failures.append("Seed %d read-wheel command was not staged as roulette cheat context." % index)
		return
	var result: Dictionary = game.resolve_with_context("read_wheel_bias", 0, run_state, environment, run_state.create_rng("roulette_read_%03d" % index), command.get("ui_state", {}))
	if not bool(result.get("ok", false)):
		failures.append("Seed %d read-wheel resolve failed." % index)
	elif int(result.get("suspicion_delta", 0)) <= 0:
		failures.append("Seed %d read-wheel resolve did not add heat." % index)
	stats["read_wheel_checks"] = int(stats.get("read_wheel_checks", 0)) + 1


func _audit_spin(game: GameModule, run_state: RunState, environment: Dictionary, surface: Dictionary, index: int) -> void:
	var targets := _dictionary_array(surface.get("bet_targets", []))
	var ui: Dictionary = {}
	var placements := [
		{"type": "straight", "chip": 2 + (index % 3)},
		{"type": "split", "chip": 1 + (index % 2)},
		{"type": "corner", "chip": 1},
		{"type": "red" if index % 2 == 0 else "black", "chip": 2},
		{"type": "column", "chip": 2},
	]
	for placement_value in placements:
		var placement: Dictionary = placement_value
		var target_index := _target_index(targets, str(placement.get("type", "")), index)
		if target_index < 0:
			failures.append("Seed %d could not find roulette target %s." % [index, str(placement.get("type", ""))])
			continue
		ui["selected_chip"] = int(placement.get("chip", 1))
		var before_command := Time.get_ticks_usec()
		var command: Dictionary = game.surface_action_command("roulette_bet", target_index, false, ui, run_state, environment)
		var command_ms := float(Time.get_ticks_usec() - before_command) / 1000.0
		stats["max_command_ms"] = maxf(float(stats.get("max_command_ms", 0.0)), command_ms)
		if not bool(command.get("handled", false)):
			failures.append("Seed %d roulette bet command failed for %s." % [index, str(placement.get("type", ""))])
			continue
		ui = command.get("ui_state", {})
	var ready_surface := game.surface_state(run_state, environment, ui)
	var ready_harness := SurfaceHarness.new()
	ready_harness.setup(ready_surface)
	game.draw_surface(ready_harness, ready_surface, {"contract_harness": true})
	for action_id in ["roulette_spin", "roulette_clear"]:
		if not _has_hit(ready_harness, action_id):
			failures.append("Seed %d roulette ready renderer omitted hit action %s." % [index, action_id])
	var spin_command: Dictionary = game.surface_action_command("roulette_spin", 0, false, ui, run_state, environment)
	if not bool(spin_command.get("resolve", false)) or str(spin_command.get("action_id", "")) != "spin_roulette":
		failures.append("Seed %d roulette spin command did not request legal resolution." % index)
		return
	var bankroll_before := run_state.bankroll
	var before_resolve := Time.get_ticks_usec()
	var result: Dictionary = game.resolve_with_context("spin_roulette", int(spin_command.get("set_stake", 1)), run_state, environment, run_state.create_rng("roulette_spin_%03d" % index), spin_command.get("ui_state", {}))
	var resolve_ms := float(Time.get_ticks_usec() - before_resolve) / 1000.0
	stats["max_resolve_ms"] = maxf(float(stats.get("max_resolve_ms", 0.0)), resolve_ms)
	if not bool(result.get("ok", false)):
		failures.append("Seed %d roulette spin resolve failed: %s." % [index, str(result.get("message", ""))])
		return
	if run_state.bankroll != bankroll_before + int(result.get("bankroll_delta", 0)):
		failures.append("Seed %d roulette result was not applied exactly once to bankroll." % index)
	var trajectory_size := (result.get("roulette_spin_trajectory", []) as Array).size()
	stats["min_trajectory_frames"] = mini(int(stats.get("min_trajectory_frames", 999999)), trajectory_size)
	stats["max_trajectory_frames"] = maxi(int(stats.get("max_trajectory_frames", 0)), trajectory_size)
	if trajectory_size < 48:
		failures.append("Seed %d roulette trajectory was too sparse: %d frames." % [index, trajectory_size])
	var spin_physics: Dictionary = _dict(result.get("roulette_spin_physics", {}))
	for key in ["drop_time", "deflector_index", "settle_time", "relative_angle", "capture_energy"]:
		if not spin_physics.has(key):
			failures.append("Seed %d spin physics missing %s." % [index, key])
	_count_key("outcomes", str(result.get("roulette_winning_number", "")))
	stats["spin_resolves"] = int(stats.get("spin_resolves", 0)) + 1


func _run_forced_payout_fixtures(game: GameModule) -> void:
	var table := {"rules": {"zero_count": 2, "la_partage": false}}
	var bets := [
		{"id": "straight", "type": "straight", "label": "17", "numbers": ["17"], "stake": 2, "payout": 35, "family": "inside"},
		{"id": "split", "type": "split", "label": "17/20", "numbers": ["17", "20"], "stake": 2, "payout": 17, "family": "inside"},
		{"id": "street", "type": "street", "label": "16-18", "numbers": ["16", "17", "18"], "stake": 2, "payout": 11, "family": "inside"},
		{"id": "corner", "type": "corner", "label": "14/15/17/18", "numbers": ["14", "15", "17", "18"], "stake": 2, "payout": 8, "family": "inside"},
		{"id": "six", "type": "six_line", "label": "13-18", "numbers": ["13", "14", "15", "16", "17", "18"], "stake": 2, "payout": 5, "family": "inside"},
		{"id": "black", "type": "black", "label": "BLACK", "numbers": ["2", "4", "6", "8", "10", "11", "13", "15", "17", "20", "22", "24", "26", "28", "29", "31", "33", "35"], "stake": 2, "payout": 1, "family": "outside"},
	]
	var settled := _array(game.call("_settle_roulette_bets", "17", bets, table))
	var expected := {"straight": 70, "split": 34, "street": 22, "corner": 16, "six_line": 10, "black": 2}
	for result_value in settled:
		var result: Dictionary = _dict(result_value)
		var result_type := str(result.get("type", ""))
		if int(result.get("bankroll_delta", 0)) != int(expected.get(result_type, 999999)):
			failures.append("Fixture payout for %s was %d." % [result_type, int(result.get("bankroll_delta", 0))])
			return
	var partage_table := {"rules": {"zero_count": 2, "la_partage": true}}
	var zero_bet := {"id": "red_half", "type": "red", "label": "RED", "numbers": ["1", "3"], "stake": 4, "payout": 1, "family": "outside"}
	var zero_loss := _array(game.call("_settle_roulette_bets", "0", [zero_bet], partage_table))
	if zero_loss.is_empty() or int(_dict(zero_loss[0]).get("bankroll_delta", 0)) != -2:
		failures.append("Fixture La Partage zero loss did not halve the even-money bet.")
		return
	stats["fixture_passes"] = int(stats.get("fixture_passes", 0)) + 1


func _target_index(targets: Array, target_type: String, offset: int = 0) -> int:
	var matches: Array = []
	for i in range(targets.size()):
		if typeof(targets[i]) == TYPE_DICTIONARY and str((targets[i] as Dictionary).get("type", "")) == target_type:
			matches.append(i)
	if matches.is_empty():
		return -1
	return int(matches[abs(offset) % matches.size()])


func _count_key(group: String, key: String) -> void:
	var values: Dictionary = _dict(stats.get(group, {}))
	values[key] = int(values.get(key, 0)) + 1
	stats[group] = values


func _count_range(group: String, key: String, value: float) -> void:
	var ranges: Dictionary = _dict(stats.get(group, {}))
	var entry: Dictionary = _dict(ranges.get(key, {}))
	if entry.is_empty():
		entry = {"min": value, "max": value}
	else:
		entry["min"] = minf(float(entry.get("min", value)), value)
		entry["max"] = maxf(float(entry.get("max", value)), value)
	ranges[key] = entry
	stats[group] = ranges


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


func _write_report(output_path: String, seed_count: int) -> void:
	var global_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
	var report := {
		"tool": "roulette_seed_audit",
		"seed_count": seed_count,
		"passed": failures.is_empty(),
		"failure_count": failures.size(),
		"warning_count": warnings.size(),
		"stats": stats,
		"failures": failures,
		"warnings": warnings,
	}
	var file := FileAccess.open(global_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()


func _print_summary() -> void:
	print("Roulette seed audit complete.")
	print("Generated tables: %d" % int(stats.get("generated_tables", 0)))
	print("Surface checks: %d" % int(stats.get("surface_checks", 0)))
	print("Draw checks: %d" % int(stats.get("draw_checks", 0)))
	print("Spin resolves: %d" % int(stats.get("spin_resolves", 0)))
	print("Resolve max %.3f ms, command max %.3f ms" % [
		float(stats.get("max_resolve_ms", 0.0)),
		float(stats.get("max_command_ms", 0.0)),
	])
	print("Trajectory frames min=%d max=%d" % [
		int(stats.get("min_trajectory_frames", 0)),
		int(stats.get("max_trajectory_frames", 0)),
	])
	if failures.is_empty():
		print("Roulette seed audit passed.")
	else:
		for failure in failures:
			push_error(failure)


func _array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var text := str(entry)
		if not text.is_empty():
			result.append(text)
	return result


func _dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
