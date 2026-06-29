extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const OUTPUT_PATH := "res://.tmp/roulette_spin_batch_400/report.json"
const SPIN_COUNT := 400
const ANIMATION_SECONDS := 5.6
const SAMPLE_FPS := 60.0
const WHEEL_CENTER := Vector2(150, 182)

var failures: Array[String] = []
var warnings: Array[String] = []
var spin_records: Array[Dictionary] = []
var stats := {
	"spin_count": 0,
	"outcomes": {},
	"colors": {},
	"min_trajectory_frames": 999999,
	"max_trajectory_frames": 0,
	"max_resolve_ms": 0.0,
	"max_command_ms": 0.0,
	"max_visual_step_px": 0.0,
	"max_radius_step_px": 0.0,
	"max_angle_step_rad": 0.0,
	"smooth_spin_count": 0,
	"total_wager": 0,
	"net_bankroll_delta": 0,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	for error in library.validation_errors:
		failures.append("ContentLibrary validation error: %s" % error)
	var game := _load_roulette(library)
	if game == null:
		_finish()
		return
	for index in range(SPIN_COUNT):
		_run_spin(game, index)
	_finish()


func _load_roulette(library: ContentLibrary) -> GameModule:
	var definition: Dictionary = library.game("roulette")
	if definition.is_empty():
		failures.append("Roulette definition was not found.")
		return null
	var module_script: Script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("Roulette module could not be loaded.")
		return null
	var instance = module_script.new()
	if not instance is GameModule:
		failures.append("Roulette module does not extend GameModule.")
		return null
	var game: GameModule = instance
	game.setup(definition, library)
	return game


func _run_spin(game: GameModule, index: int) -> void:
	var seed := "ROULETTE-BATCH-400-%03d" % index
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	run_state.bankroll = 1000
	var environment := _audit_environment(index)
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("roulette_table_%03d" % index))
	environment["game_states"] = {"roulette": table}
	run_state.current_environment = environment.duplicate(true)
	var surface := game.surface_state(run_state, environment, {})
	var ui := _place_batch_bets(game, run_state, environment, surface, index)
	var ready_surface := game.surface_state(run_state, environment, ui)
	if not bool(ready_surface.get("can_spin", false)):
		failures.append("Spin %d did not become spin-ready." % index)
		return
	var before_command := Time.get_ticks_usec()
	var spin_command: Dictionary = game.surface_action_command("roulette_spin", 0, false, ui, run_state, environment)
	var command_ms := float(Time.get_ticks_usec() - before_command) / 1000.0
	stats["max_command_ms"] = maxf(float(stats.get("max_command_ms", 0.0)), command_ms)
	if not bool(spin_command.get("resolve", false)) or str(spin_command.get("action_id", "")) != "spin_roulette":
		failures.append("Spin %d did not produce a resolve command." % index)
		return
	var bankroll_before := run_state.bankroll
	var before_resolve := Time.get_ticks_usec()
	var result: Dictionary = game.resolve_with_context(
		"spin_roulette",
		int(spin_command.get("set_stake", 1)),
		run_state,
		environment,
		run_state.create_rng("roulette_spin_%03d" % index),
		spin_command.get("ui_state", {})
	)
	var resolve_ms := float(Time.get_ticks_usec() - before_resolve) / 1000.0
	stats["max_resolve_ms"] = maxf(float(stats.get("max_resolve_ms", 0.0)), resolve_ms)
	if not bool(result.get("ok", false)):
		failures.append("Spin %d failed: %s" % [index, str(result.get("message", ""))])
		return
	var expected_bankroll := bankroll_before + int(result.get("bankroll_delta", 0))
	if run_state.bankroll != expected_bankroll:
		failures.append("Spin %d applied bankroll incorrectly." % index)
	var trajectory := _dictionary_array(result.get("roulette_spin_trajectory", []))
	var smoothness := _audit_trajectory_smoothness(game, trajectory)
	var winning_number := str(result.get("roulette_winning_number", ""))
	var winning_color := str(result.get("roulette_winning_color", ""))
	var total_wager := int(result.get("roulette_total_wager", 0))
	var bankroll_delta := int(result.get("bankroll_delta", 0))
	_count_key("outcomes", winning_number)
	_count_key("colors", winning_color)
	stats["spin_count"] = int(stats.get("spin_count", 0)) + 1
	stats["total_wager"] = int(stats.get("total_wager", 0)) + total_wager
	stats["net_bankroll_delta"] = int(stats.get("net_bankroll_delta", 0)) + bankroll_delta
	stats["min_trajectory_frames"] = mini(int(stats.get("min_trajectory_frames", 999999)), trajectory.size())
	stats["max_trajectory_frames"] = maxi(int(stats.get("max_trajectory_frames", 0)), trajectory.size())
	stats["max_visual_step_px"] = maxf(float(stats.get("max_visual_step_px", 0.0)), float(smoothness.get("max_visual_step_px", 0.0)))
	stats["max_radius_step_px"] = maxf(float(stats.get("max_radius_step_px", 0.0)), float(smoothness.get("max_radius_step_px", 0.0)))
	stats["max_angle_step_rad"] = maxf(float(stats.get("max_angle_step_rad", 0.0)), float(smoothness.get("max_angle_step_rad", 0.0)))
	if bool(smoothness.get("smooth", false)):
		stats["smooth_spin_count"] = int(stats.get("smooth_spin_count", 0)) + 1
	else:
		failures.append("Spin %d failed smoothness checks: %s" % [index, str(smoothness.get("issues", []))])
	spin_records.append({
		"index": index + 1,
		"seed": seed,
		"winning_number": winning_number,
		"winning_color": winning_color,
		"bankroll_delta": bankroll_delta,
		"total_wager": total_wager,
		"trajectory_frames": trajectory.size(),
		"smooth": bool(smoothness.get("smooth", false)),
		"max_visual_step_px": float(smoothness.get("max_visual_step_px", 0.0)),
		"avg_visual_step_px": float(smoothness.get("avg_visual_step_px", 0.0)),
		"max_radius_step_px": float(smoothness.get("max_radius_step_px", 0.0)),
		"max_angle_step_rad": float(smoothness.get("max_angle_step_rad", 0.0)),
		"phase_sequence": smoothness.get("phase_sequence", []),
		"physics": _spin_physics_summary(result.get("roulette_spin_physics", {})),
	})


func _audit_environment(index: int) -> Dictionary:
	var strictness_values := ["low", "private", "high", "boss", "uneven"]
	return {
		"id": "roulette_batch_room_%03d" % index,
		"display_name": "Roulette Batch Room %03d" % index,
		"depth": index % 4,
		"game_ids": ["roulette"],
		"economic_profile": {"stake_floor": 1 + (index % 3), "stake_ceiling": 160 + (index % 4) * 20},
		"security_profile": {"strictness": strictness_values[index % strictness_values.size()]},
		"turns": index % 4,
	}


func _place_batch_bets(game: GameModule, run_state: RunState, environment: Dictionary, surface: Dictionary, index: int) -> Dictionary:
	var ui: Dictionary = {}
	var targets := _dictionary_array(surface.get("bet_targets", []))
	var placements := [
		{"type": "straight", "chip": 2 + (index % 4)},
		{"type": "split", "chip": 1 + (index % 3)},
		{"type": "corner", "chip": 1},
		{"type": "six_line", "chip": 1 + (index % 2)},
		{"type": "red" if index % 2 == 0 else "black", "chip": 2},
		{"type": "column", "chip": 2},
		{"type": "dozen", "chip": 2},
	]
	for placement_value in placements:
		var placement: Dictionary = placement_value
		var target_index := _target_index(targets, str(placement.get("type", "")), index)
		if target_index < 0:
			failures.append("Spin %d could not find bet target %s." % [index, str(placement.get("type", ""))])
			continue
		ui["selected_chip"] = int(placement.get("chip", 1))
		var command: Dictionary = game.surface_action_command("roulette_bet", target_index, false, ui, run_state, environment)
		if not bool(command.get("handled", false)):
			failures.append("Spin %d bet command failed for %s: %s" % [index, str(placement.get("type", "")), str(command.get("message", ""))])
			continue
		ui = command.get("ui_state", {})
	return ui


func _audit_trajectory_smoothness(game: GameModule, trajectory: Array) -> Dictionary:
	var issues: Array[String] = []
	if trajectory.size() != 96:
		issues.append("trajectory frame count was %d, expected 96" % trajectory.size())
	var last_t := -1.0
	var phase_rank := {"rim": 0, "deflect": 1, "scatter": 2, "capture": 3}
	var last_phase_rank := -1
	var phase_sequence: Array[String] = []
	var max_radius_step := 0.0
	for i in range(trajectory.size()):
		var frame: Dictionary = trajectory[i]
		var t := float(frame.get("t", -1.0))
		if t <= last_t and i > 0:
			issues.append("non-monotonic trajectory t at frame %d" % i)
		last_t = t
		var phase := str(frame.get("phase", ""))
		if phase_sequence.is_empty() or phase_sequence.back() != phase:
			phase_sequence.append(phase)
		var rank := int(phase_rank.get(phase, -1))
		if rank < last_phase_rank:
			issues.append("phase moved backward at frame %d" % i)
		last_phase_rank = maxi(last_phase_rank, rank)
		if i > 0:
			var previous: Dictionary = trajectory[i - 1]
			var radius_step := absf(float(frame.get("ball_radius", 0.0)) - float(previous.get("ball_radius", 0.0)))
			max_radius_step = maxf(max_radius_step, radius_step)
	var visual_sample_count := int(ceil(ANIMATION_SECONDS * SAMPLE_FPS))
	var last_pos := Vector2.ZERO
	var last_radius := 0.0
	var last_angle := 0.0
	var total_step := 0.0
	var max_step := 0.0
	var max_angle_step := 0.0
	var sampled_radius_step := 0.0
	for i in range(visual_sample_count + 1):
		var progress := float(i) / float(maxi(1, visual_sample_count))
		var keyframe: Dictionary = game.call("_trajectory_keyframe", trajectory, progress)
		var angle := float(keyframe.get("ball_angle", 0.0))
		var radius := float(keyframe.get("ball_radius", 0.0)) + float(keyframe.get("bounce", 0.0))
		var pos := WHEEL_CENTER + Vector2(cos(angle), sin(angle)) * radius
		if i > 0:
			var step := pos.distance_to(last_pos)
			max_step = maxf(max_step, step)
			total_step += step
			sampled_radius_step = maxf(sampled_radius_step, absf(radius - last_radius))
			max_angle_step = maxf(max_angle_step, absf(angle_difference(last_angle, angle)))
		last_pos = pos
		last_radius = radius
		last_angle = angle
	if max_step > 100.0:
		issues.append("max visual step %.2fpx exceeded 100px at 60fps" % max_step)
	if max_radius_step > 8.0:
		issues.append("max keyframe radius step %.2fpx exceeded 8px" % max_radius_step)
	return {
		"smooth": issues.is_empty(),
		"issues": issues,
		"phase_sequence": phase_sequence,
		"max_visual_step_px": max_step,
		"avg_visual_step_px": total_step / float(maxi(1, visual_sample_count)),
		"max_radius_step_px": maxf(max_radius_step, sampled_radius_step),
		"max_angle_step_rad": max_angle_step,
	}


func _spin_physics_summary(value: Variant) -> Dictionary:
	var physics := _dict(value)
	return {
		"drop_time": float(physics.get("drop_time", 0.0)),
		"settle_time": float(physics.get("settle_time", 0.0)),
		"deflector_index": int(physics.get("deflector_index", 0)),
		"relative_angle": float(physics.get("relative_angle", 0.0)),
		"capture_energy": float(physics.get("capture_energy", 0.0)),
		"winning_index": int(physics.get("winning_index", 0)),
	}


func _target_index(targets: Array, target_type: String, offset: int = 0) -> int:
	var matches: Array[int] = []
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


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var report := {
		"tool": "roulette_spin_batch_report",
		"spin_count_requested": SPIN_COUNT,
		"passed": failures.is_empty(),
		"failure_count": failures.size(),
		"warning_count": warnings.size(),
		"failures": failures,
		"warnings": warnings,
		"stats": stats,
		"spins": spin_records,
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT_PATH), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("Roulette 400-spin batch report complete.")
	print("Spins: %d / %d" % [int(stats.get("spin_count", 0)), SPIN_COUNT])
	print("Smooth spins: %d" % int(stats.get("smooth_spin_count", 0)))
	print("Trajectory frames min=%d max=%d" % [int(stats.get("min_trajectory_frames", 0)), int(stats.get("max_trajectory_frames", 0))])
	print("Max visual step %.3f px, max resolve %.3f ms" % [float(stats.get("max_visual_step_px", 0.0)), float(stats.get("max_resolve_ms", 0.0))])
	quit(0 if failures.is_empty() else 1)
