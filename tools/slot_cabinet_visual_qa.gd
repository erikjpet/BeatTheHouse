extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SlotMachineGeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const SlotMachineStateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const SlotResolverScript := preload("res://scripts/games/slots/slot_resolver.gd")
const SlotPresentationScript := preload("res://scripts/games/slots/slot_presentation.gd")
const SlotRendererScript := preload("res://scripts/games/slots/slot_renderer.gd")
const SlotFamilyPinballScript := preload("res://scripts/games/slots/slot_family_pinball.gd")
const SlotFamilyBuffaloScript := preload("res://scripts/games/slots/slot_family_buffalo.gd")


func _init() -> void:
	var failures: Array = []
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var definition: Dictionary = library.game("slot")
	var generator = SlotMachineGeneratorScript.new()
	var resolver = SlotResolverScript.new()
	var presentation = SlotPresentationScript.new()
	var renderer = SlotRendererScript.new()
	var distinct: Dictionary = {}
	for family_id in ["pinball", "buffalo"]:
		for format_id in ["classic_3_reel", "line_5x3", "video_feature"]:
			var key := "%s_%s" % [family_id, format_id]
			var run_state: RunState = RunStateScript.new()
			run_state.start_new("SLOT-VISUAL-QA-%s" % key)
			run_state.bankroll = 100000
			var machine: Dictionary = generator.build_machine_from_ids(definition, {
				"format_id": format_id,
				"type_id": family_id,
				"math_variant_id": "standard",
				"bonus_variant_id": "plain",
				"cabinet_variant_id": "neon_magenta",
			}, run_state.create_rng("machine"))
			machine = SlotMachineStateScript.set_selected_bet(machine, "bet_10")
			var idle_a: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": 0})
			var idle_b: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": 1260})
			var sig_idle_a: String = JSON.stringify(renderer.render_signature(idle_a, definition, 0, "attract"))
			var sig_idle_b: String = JSON.stringify(renderer.render_signature(idle_b, definition, 1260, "attract"))
			if sig_idle_a == sig_idle_b:
				failures.append("%s attract signature did not change." % key)
			var resolved: Dictionary = resolver.resolve_spin(machine, "spin", SlotMachineStateScript.selected_bet(machine), run_state.create_rng("spin"), definition, {})
			machine = resolved.get("machine", machine)
			var duration := int(_dict(resolved.get("result", {})).get("slot_animation_duration_msec", 2200))
			var spin_a: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": 120})
			var spin_b: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": maxi(240, duration / 2)})
			var spin_c: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": duration})
			var manifest_spin_a: Dictionary = renderer.render_signature(spin_a, definition, 120, "spin")
			var manifest_spin_b: Dictionary = renderer.render_signature(spin_b, definition, maxi(240, duration / 2), "spin")
			var manifest_spin_c: Dictionary = renderer.render_signature(spin_c, definition, duration, "spin")
			var sig_spin_a: String = JSON.stringify(manifest_spin_a)
			var sig_spin_b: String = JSON.stringify(manifest_spin_b)
			var sig_spin_c: String = JSON.stringify(manifest_spin_c)
			if sig_spin_a == sig_spin_b or sig_spin_b == sig_spin_c:
				failures.append("%s spin signature did not change through reel phases." % key)
			if not _reel_phases_progress(manifest_spin_a, manifest_spin_b, manifest_spin_c):
				failures.append("%s reel manifest did not progress through spin/decel/settle phases." % key)
			if not _stops_are_staggered(_array(manifest_spin_b.get("reel_stop_msec", []))):
				failures.append("%s reel stops were not staggered left-to-right." % key)
			machine["active_bonus"] = _feature_for_machine(machine, family_id, format_id, definition, run_state)
			var feature_surface: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": duration + 600})
			var sig_feature: String = JSON.stringify(renderer.render_signature(feature_surface, definition, duration + 600, "feature"))
			if sig_feature == sig_idle_a or sig_feature == sig_spin_c:
				failures.append("%s feature frame was not distinct from idle/spin." % key)
			distinct[sig_idle_a] = true
			print("VISUAL_QA machine=%s identity=%s attract_change=%s spin_change=%s feature_frame=%s phases=%s stops=%s" % [
				key,
				str(_dict(idle_a.get("slot_skin", {})).get("cabinet_identity", "")),
				str(sig_idle_a != sig_idle_b),
				str(sig_spin_a != sig_spin_b and sig_spin_b != sig_spin_c),
				str(not sig_feature.is_empty()),
				",".join(_string_array(manifest_spin_b.get("reel_phase", []))),
				",".join(_string_array(manifest_spin_b.get("reel_stop_msec", []))),
			])
	_check_true_win_manifest(definition, generator, resolver, presentation, renderer, failures)
	_check_win_tier_celebration_manifest(definition, generator, resolver, presentation, renderer, failures)
	_check_near_miss_manifest(definition, generator, resolver, presentation, renderer, failures)
	_check_pinball_feature_manifests(definition, presentation, renderer, failures)
	_check_buffalo_feature_manifests(definition, presentation, renderer, failures)
	if distinct.size() != 6:
		failures.append("Visual QA did not find six distinct cabinet signatures.")
	if failures.is_empty():
		print("Slot cabinet visual QA passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _feature_for_machine(machine: Dictionary, family_id: String, format_id: String, definition: Dictionary, run_state: RunState) -> Dictionary:
	if family_id == "pinball":
		var pinball = SlotFamilyPinballScript.new()
		return pinball.open_feature(machine, 10, run_state.create_rng("feature_%s_%s" % [family_id, format_id]), definition)
	var buffalo = SlotFamilyBuffaloScript.new()
	var classification := "free_games"
	if format_id == "line_5x3":
		classification = "hold_and_spin"
	elif format_id == "video_feature":
		classification = "monster_feature"
	return buffalo.open_feature(machine, {"classification": classification}, 10, run_state.create_rng("feature_%s_%s" % [family_id, format_id]), definition)


func _check_true_win_manifest(definition: Dictionary, generator, resolver, presentation, renderer, failures: Array) -> void:
	var sample: Dictionary = _spin_until_classification(definition, generator, resolver, "pinball", "line_5x3", "true_win", "SLOT-VISUAL-QA-TRUE-WIN", failures)
	if sample.is_empty():
		return
	var run_state: RunState = sample.get("run_state", null)
	var machine: Dictionary = _dict(sample.get("machine", {}))
	var result: Dictionary = _dict(sample.get("result", {}))
	var duration := int(result.get("slot_animation_duration_msec", 0))
	var settle_msec := _settle_msec(_array(result.get("slot_reel_timeline", [])))
	var surface_early: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": 120})
	var surface_mid: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": maxi(240, duration / 2)})
	var surface_settle: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": settle_msec})
	var manifest_early: Dictionary = renderer.render_signature(surface_early, definition, 120, "spin")
	var manifest_mid: Dictionary = renderer.render_signature(surface_mid, definition, maxi(240, duration / 2), "spin")
	var manifest_settle: Dictionary = renderer.render_signature(surface_settle, definition, settle_msec, "spin")
	var plan: Dictionary = _dict(result.get("slot_animation_plan", {}))
	var celebration_msec := (int(plan.get("count_up_start_msec", 0)) + int(plan.get("count_up_end_msec", 0))) / 2
	var surface_celebration: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": celebration_msec})
	var manifest_celebration: Dictionary = renderer.render_signature(surface_celebration, definition, celebration_msec, "spin")
	var win_cells: Array = _array(result.get("slot_win_cells", []))
	if int(manifest_settle.get("win_cells_highlighted", 0)) != win_cells.size() or win_cells.is_empty():
		failures.append("Visual QA true_win did not highlight exactly the winning cells.")
	if not bool(manifest_settle.get("win_line_drawn", false)):
		failures.append("Visual QA true_win did not draw the win line.")
	if str(manifest_settle.get("win_reason_text", "")).is_empty():
		failures.append("Visual QA true_win did not expose win reason text.")
	if not bool(manifest_celebration.get("count_up_active", false)) or int(manifest_celebration.get("particle_count", 0)) <= 0:
		failures.append("Visual QA true_win celebration did not expose count-up and particles.")
	print("VISUAL_QA_TRUE_WIN early=%s mid=%s settle=%s highlighted=%d line=%s tier=%s count_up=%s particles=%d reason=%s" % [
		",".join(_string_array(manifest_early.get("reel_phase", []))),
		",".join(_string_array(manifest_mid.get("reel_phase", []))),
		",".join(_string_array(manifest_settle.get("reel_phase", []))),
		int(manifest_settle.get("win_cells_highlighted", 0)),
		str(manifest_settle.get("win_line_drawn", false)),
		str(manifest_celebration.get("celebration_tier", "")),
		str(manifest_celebration.get("count_up_active", false)),
		int(manifest_celebration.get("particle_count", 0)),
		str(manifest_settle.get("win_reason_text", "")),
	])


# Forces a guaranteed big/mega/jackpot celebration (Buffalo monster feature award) and
# asserts the full high-tier effect set at an early celebration timestamp: count-up,
# particles, screen shake, and the color-cycling border manifest (build spec section 9.4).
func _check_win_tier_celebration_manifest(definition: Dictionary, generator, resolver, presentation, renderer, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SLOT-VISUAL-QA-WIN-TIER")
	run_state.bankroll = 100000
	var machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": "video_feature",
		"type_id": "buffalo",
		"math_variant_id": "standard",
		"bonus_variant_id": "plain",
		"cabinet_variant_id": "neon_magenta",
	}, run_state.create_rng("win_tier_machine"))
	machine = SlotMachineStateScript.set_selected_bet(machine, "bet_20")
	var buffalo = SlotFamilyBuffaloScript.new()
	var active: Dictionary = buffalo.open_feature(machine, {"classification": "monster_feature"}, 20, run_state.create_rng("win_tier_open"), definition)
	active["choices"] = [
		{"id": "free_games", "label": "Free Games", "route": "free_games"},
		{"id": "hold_and_spin", "label": "Coin Link", "route": "hold_and_spin"},
		{"id": "jackpot_boost", "label": "Jackpot Boost", "route": "jackpot_boost"},
	]
	machine["active_bonus"] = active
	var resolved: Dictionary = resolver.resolve_bonus_action(machine, "slot_bonus_right", run_state.create_rng("win_tier_step"), definition, {})
	var result: Dictionary = _dict(resolved.get("result", {}))
	var completed: Dictionary = _dict(resolved.get("machine", machine))
	var plan: Dictionary = _dict(completed.get("slot_animation_plan", {}))
	var celebration_msec := int(plan.get("count_up_start_msec", 80)) + 120
	var surface: Dictionary = presentation.surface_state(completed, run_state, definition, {"surface_time_msec": celebration_msec})
	var manifest: Dictionary = renderer.render_signature(surface, definition, celebration_msec, "spin")
	var tier := str(manifest.get("celebration_tier", ""))
	if int(result.get("slot_bonus_award", 0)) <= 0:
		failures.append("Visual QA win-tier celebration did not produce a positive jackpot feature award.")
	if tier != "jackpot" and tier != "mega" and tier != "big":
		failures.append("Visual QA win-tier celebration did not reach a big/mega/jackpot tier.")
	if not bool(manifest.get("count_up_active", false)):
		failures.append("Visual QA win-tier celebration did not expose count-up.")
	if int(manifest.get("particle_count", 0)) <= 0:
		failures.append("Visual QA win-tier celebration did not expose celebration particles.")
	if not bool(manifest.get("shake_active", false)):
		failures.append("Visual QA win-tier celebration did not expose screen shake.")
	if not bool(manifest.get("color_cycle_active", false)):
		failures.append("Visual QA win-tier celebration did not expose a color-cycling border.")
	print("VISUAL_QA_WIN_TIER tier=%s count_up=%s particles=%d shake=%s color_cycle=%s phase=%s award=%d" % [
		tier,
		str(manifest.get("count_up_active", false)),
		int(manifest.get("particle_count", 0)),
		str(manifest.get("shake_active", false)),
		str(manifest.get("color_cycle_active", false)),
		str(manifest.get("border_color_phase", -1.0)),
		int(result.get("slot_bonus_award", 0)),
	])


func _check_near_miss_manifest(definition: Dictionary, generator, resolver, presentation, renderer, failures: Array) -> void:
	var sample: Dictionary = _spin_until_classification(definition, generator, resolver, "pinball", "line_5x3", "near_miss", "SLOT-VISUAL-QA-NEAR-MISS", failures)
	if sample.is_empty():
		return
	var run_state: RunState = sample.get("run_state", null)
	var machine: Dictionary = _dict(sample.get("machine", {}))
	var result: Dictionary = _dict(sample.get("result", {}))
	var timeline: Array = _array(result.get("slot_reel_timeline", []))
	var tease_msec := _tease_msec(timeline)
	var surface_tease: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": tease_msec})
	var manifest_tease: Dictionary = renderer.render_signature(surface_tease, definition, tease_msec, "spin")
	var stop_msec: Array = _array(manifest_tease.get("reel_stop_msec", []))
	if not bool(manifest_tease.get("tease_active", false)):
		failures.append("Visual QA near_miss did not expose tease_active.")
	if not _string_array(manifest_tease.get("reel_phase", [])).has("tease_slow_roll"):
		failures.append("Visual QA near_miss did not put a reel into tease_slow_roll.")
	if stop_msec.size() >= 2 and int(stop_msec[stop_msec.size() - 1]) <= int(stop_msec[stop_msec.size() - 2]):
		failures.append("Visual QA near_miss did not extend the teasing reel stop.")
	print("VISUAL_QA_NEAR_MISS tease_active=%s phases=%s stops=%s reason=%s" % [
		str(manifest_tease.get("tease_active", false)),
		",".join(_string_array(manifest_tease.get("reel_phase", []))),
		",".join(_string_array(stop_msec)),
		str(manifest_tease.get("win_reason_text", "")),
	])
	var buffalo_sample: Dictionary = _spin_until_classification(definition, generator, resolver, "buffalo", "line_5x3", "near_miss", "SLOT-VISUAL-QA-BUFFALO-TEASE", failures)
	if buffalo_sample.is_empty():
		return
	var buffalo_run_state: RunState = buffalo_sample.get("run_state", null)
	var buffalo_machine: Dictionary = _dict(buffalo_sample.get("machine", {}))
	var buffalo_offer: Dictionary = _dict(buffalo_machine.get("last_nudge_offer", {}))
	var buffalo_window: Dictionary = _dict(buffalo_offer.get("skill_window_msec", {}))
	var buffalo_time := int(buffalo_window.get("perfect", _tease_msec(_array(_dict(buffalo_sample.get("result", {})).get("slot_reel_timeline", [])))))
	var buffalo_surface: Dictionary = presentation.surface_state(buffalo_machine, buffalo_run_state, definition, {"slot_nudge_chain_input_msec": buffalo_time})
	var buffalo_manifest: Dictionary = renderer.render_signature(buffalo_surface, definition, buffalo_time, "nudge_chain")
	var buffalo_cues: Array = []
	for cue_value in _array(buffalo_surface.get("slot_audio_cues", [])):
		var cue: Dictionary = _dict(cue_value)
		buffalo_cues.append(str(cue.get("cue_id", "")))
	if not bool(buffalo_manifest.get("nudge_chain_active", false)) or not bool(buffalo_manifest.get("nudge_chain_zone_visible", false)):
		failures.append("Visual QA buffalo near_miss did not expose coin-chain peek/zone state.")
	if float(buffalo_manifest.get("nudge_chain_peek_amount", 0.0)) <= 0.0:
		failures.append("Visual QA buffalo near_miss did not render a peeking coin.")
	if not bool(buffalo_surface.get("slot_nudge_available", false)):
		failures.append("Visual QA buffalo near_miss did not expose timed nudge availability.")
	if not buffalo_cues.has("gold_coin_tease"):
		failures.append("Visual QA buffalo near_miss did not schedule the gold coin tease cue.")
	print("VISUAL_QA_BUFFALO_COIN_CHAIN coins=%d peek=%.3f nudge=%s window=%s cues=%s" % [
		int(buffalo_manifest.get("nudge_chain_coin_count", 0)),
		float(buffalo_manifest.get("nudge_chain_peek_amount", 0.0)),
		str(buffalo_surface.get("slot_nudge_available", false)),
		JSON.stringify(buffalo_window),
		",".join(_string_array(buffalo_cues)),
	])


func _check_pinball_feature_manifests(definition: Dictionary, presentation, renderer, failures: Array) -> void:
	var pinball = SlotFamilyPinballScript.new()
	var prelaunch_run: RunState = RunStateScript.new()
	prelaunch_run.start_new("SLOT-VISUAL-QA-PINBALL-PRELAUNCH")
	prelaunch_run.bankroll = 100000
	var generator = SlotMachineGeneratorScript.new()
	var prelaunch_machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": "video_feature",
		"type_id": "pinball",
		"math_variant_id": "standard",
		"bonus_variant_id": "plain",
		"cabinet_variant_id": "neon_magenta",
	}, prelaunch_run.create_rng("machine"))
	prelaunch_machine["active_bonus"] = pinball.open_feature(prelaunch_machine, 10, prelaunch_run.create_rng("feature"), definition)
	var prelaunch_surface: Dictionary = presentation.surface_state(prelaunch_machine, prelaunch_run, definition, {"surface_time_msec": 240})
	var prelaunch_manifest: Dictionary = renderer.render_signature(prelaunch_surface, definition, 240, "feature")
	if str(prelaunch_manifest.get("pinball_feature_music_id", "")) != "bonus_music_pinball":
		failures.append("Visual QA pinball prelaunch did not expose feature music.")
	if not bool(prelaunch_manifest.get("pinball_guideline_active", false)):
		failures.append("Visual QA pinball prelaunch did not expose launch guideline.")
	if int(prelaunch_manifest.get("pinball_sampled_power", 0)) <= 0:
		failures.append("Visual QA pinball prelaunch did not expose sampled launch power.")
	if not bool(prelaunch_manifest.get("pinball_power_meter_controlled", false)):
		failures.append("Visual QA pinball prelaunch did not expose controlled launch power.")
	if float(prelaunch_manifest.get("pinball_launch_start_y", 1.0)) > 0.20:
		failures.append("Visual QA pinball prelaunch launch point was not at the top of the board.")
	if float(prelaunch_manifest.get("pinball_playback_speed", 0.0)) <= 1.0:
		failures.append("Visual QA pinball playback speed was not upgraded.")
	print("VISUAL_QA_PINBALL_PRELAUNCH music=%s guideline=%s lane=%s angle=%d start_y=%.2f power=%d controlled=%s rating=%s speed=%.2f gravity=%.2f" % [
		str(prelaunch_manifest.get("pinball_feature_music_id", "")),
		str(prelaunch_manifest.get("pinball_guideline_active", false)),
		str(prelaunch_manifest.get("pinball_aim_lane", "")),
		int(prelaunch_manifest.get("pinball_launch_angle_degrees", 0)),
		float(prelaunch_manifest.get("pinball_launch_start_y", 0.0)),
		int(prelaunch_manifest.get("pinball_sampled_power", 0)),
		str(prelaunch_manifest.get("pinball_power_meter_controlled", false)),
		str(prelaunch_manifest.get("pinball_power_rating", "")),
		float(prelaunch_manifest.get("pinball_playback_speed", 0.0)),
		float(prelaunch_manifest.get("pinball_gravity_y", 0.0)),
	])
	var scenarios: Array = [
		{"format": "classic_3_reel", "mode": "em_bumper_drop", "inputs": ["slot_bonus_left", "slot_bonus_launch"], "bumpers": 4, "ramps": 0},
		{"format": "line_5x3", "mode": "lane_multiball", "inputs": ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"], "bumpers": 3, "ramps": 2},
		{"format": "video_feature", "mode": "video_feature", "inputs": ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch", "slot_bonus_left", "slot_bonus_launch"], "bumpers": 4, "ramps": 5},
	]
	for scenario_value in scenarios:
		var scenario: Dictionary = _dict(scenario_value)
		var sample: Dictionary = _pinball_visual_sample(definition, str(scenario.get("format", "")), _array(scenario.get("inputs", [])), "SLOT-VISUAL-QA-PINBALL-%s" % str(scenario.get("mode", "")))
		var run_state: RunState = sample.get("run_state", null)
		var machine: Dictionary = _dict(sample.get("machine", {}))
		var active: Dictionary = _dict(sample.get("active_bonus", {}))
		var trajectory: Array = _array(active.get("trajectory", []))
		if trajectory.is_empty():
			failures.append("Visual QA pinball feature had no trajectory for %s." % str(scenario.get("mode", "")))
			continue
		var times: Array = _pinball_manifest_time_pair(trajectory)
		var time_a := int(times[0])
		var time_b := int(times[1])
		var manifest_push: Dictionary = renderer.render_signature(presentation.surface_state(machine, run_state, definition, {"surface_time_msec": 200}), definition, 200, "feature")
		var manifest_a: Dictionary = renderer.render_signature(presentation.surface_state(machine, run_state, definition, {"surface_time_msec": time_a}), definition, time_a, "feature")
		var manifest_b: Dictionary = renderer.render_signature(presentation.surface_state(machine, run_state, definition, {"surface_time_msec": time_b}), definition, time_b, "feature")
		var pos_a := JSON.stringify(manifest_a.get("pinball_ball_positions", []))
		var pos_b := JSON.stringify(manifest_b.get("pinball_ball_positions", []))
		if str(manifest_push.get("transition_phase", "")) != "push_in":
			failures.append("Visual QA pinball feature did not expose push-in transition for %s." % str(scenario.get("mode", "")))
		if int(manifest_a.get("bumper_count", 0)) < int(scenario.get("bumpers", 0)):
			failures.append("Visual QA pinball feature missing bumper geometry for %s." % str(scenario.get("mode", "")))
		if int(manifest_a.get("ramp_count", 0)) < int(scenario.get("ramps", 0)):
			failures.append("Visual QA pinball feature missing ramp/orbit geometry for %s." % str(scenario.get("mode", "")))
		if int(manifest_a.get("ball_count", 0)) < 1 or int(manifest_b.get("ball_count", 0)) < 1:
			failures.append("Visual QA pinball feature did not expose a moving playback ball for %s." % str(scenario.get("mode", "")))
		if pos_a == pos_b:
			failures.append("Visual QA pinball feature ball position did not move for %s." % str(scenario.get("mode", "")))
		if not bool(manifest_a.get("dmd_active", false)):
			failures.append("Visual QA pinball feature did not expose cabinet display state for %s." % str(scenario.get("mode", "")))
		if str(scenario.get("mode", "")) == "video_feature":
			var multiball_time := _pinball_multiball_manifest_time(trajectory)
			var manifest_multi: Dictionary = renderer.render_signature(presentation.surface_state(machine, run_state, definition, {"surface_time_msec": multiball_time}), definition, multiball_time, "feature")
			if int(manifest_multi.get("ball_count", 0)) <= 1:
				failures.append("Visual QA pinball feature did not expose multiball frame.")
			print("VISUAL_QA_PINBALL_MULTIBALL balls=%d time=%d positions=%s" % [
				int(manifest_multi.get("ball_count", 0)),
				multiball_time,
				JSON.stringify(manifest_multi.get("pinball_ball_positions", [])),
			])
		print("VISUAL_QA_PINBALL_FEATURE machine=pinball_%s push=%s play=%s bumpers=%d ramps=%d lit=%d dmd=%s balls=%d/%d pos_a=%s pos_b=%s" % [
			str(scenario.get("format", "")),
			str(manifest_push.get("transition_phase", "")),
			str(manifest_b.get("transition_phase", "")),
			int(manifest_a.get("bumper_count", 0)),
			int(manifest_a.get("ramp_count", 0)),
			int(manifest_b.get("lit_inserts", 0)),
			str(manifest_a.get("dmd_active", false)),
			int(manifest_a.get("ball_count", 0)),
			int(manifest_b.get("ball_count", 0)),
			pos_a,
			pos_b,
		])


func _pinball_visual_sample(definition: Dictionary, format_id: String, inputs: Array, seed: String) -> Dictionary:
	var pinball = SlotFamilyPinballScript.new()
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	run_state.bankroll = 100000
	var generator = SlotMachineGeneratorScript.new()
	var machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": format_id,
		"type_id": "pinball",
		"math_variant_id": "standard",
		"bonus_variant_id": "plain",
		"cabinet_variant_id": "neon_magenta",
	}, run_state.create_rng("machine"))
	machine = SlotMachineStateScript.set_selected_bet(machine, "bet_10")
	var rng: RngStream = run_state.create_rng("feature")
	var active: Dictionary = pinball.open_feature(machine, 10, rng, definition)
	machine["active_bonus"] = active
	var guard := 0
	var input_index := 0
	while bool(active.get("active", false)) and guard < 32:
		var action_id := "slot_bonus_launch"
		if input_index < inputs.size():
			action_id = str(inputs[input_index])
			input_index += 1
		var step: Dictionary = pinball.step_bonus(machine, action_id, rng, definition, {"surface_time_msec": 240 + guard * 180})
		active = _dict(step.get("active_bonus", {}))
		machine["active_bonus"] = active
		guard += 1
	return {
		"run_state": run_state,
		"machine": machine,
		"active_bonus": active,
	}


func _pinball_manifest_time_pair(trajectory: Array) -> Array:
	var visual_start_msec := 520
	var playback_speed := 1.45
	var distinct_times: Array = _pinball_distinct_times(trajectory)
	if distinct_times.size() < 2:
		return [visual_start_msec + 40, visual_start_msec + 240]
	var index_a := mini(2, distinct_times.size() - 1)
	var index_b := mini(maxi(index_a + 6, distinct_times.size() / 3), distinct_times.size() - 1)
	var first_msec := visual_start_msec + int(round(float(distinct_times[index_a]) * 1000.0 / playback_speed))
	var second_msec := visual_start_msec + int(round(float(distinct_times[index_b]) * 1000.0 / playback_speed))
	return [first_msec, maxi(second_msec, first_msec + 220)]


func _pinball_multiball_manifest_time(trajectory: Array) -> int:
	var visual_start_msec := 520
	var playback_speed := 1.45
	var current_time := -1.0
	var balls: Dictionary = {}
	for point_value in trajectory:
		var point: Dictionary = _dict(point_value)
		var point_time := float(point.get("time", 0.0))
		if absf(point_time - current_time) > 0.0001:
			current_time = point_time
			balls = {}
		balls[int(point.get("ball_index", 0))] = true
		if balls.size() > 1:
			return visual_start_msec + 4 + int(ceil(point_time * 1000.0 / playback_speed))
	return int(_pinball_manifest_time_pair(trajectory)[1])


func _pinball_distinct_times(trajectory: Array) -> Array:
	var result: Array = []
	var last_time := -999.0
	for point_value in trajectory:
		var point: Dictionary = _dict(point_value)
		var point_time := float(point.get("time", 0.0))
		if absf(point_time - last_time) > 0.0001:
			result.append(point_time)
			last_time = point_time
	return result


func _check_buffalo_feature_manifests(definition: Dictionary, presentation, renderer, failures: Array) -> void:
	var buffalo = SlotFamilyBuffaloScript.new()
	var generator = SlotMachineGeneratorScript.new()
	var scenarios: Array = [
		{"format": "classic_3_reel", "classification": "free_games", "label": "heritage", "expect_ladder": false},
		{"format": "line_5x3", "classification": "hold_and_spin", "label": "ways", "expect_ladder": true},
		{"format": "video_feature", "classification": "monster_feature", "label": "link_arena", "expect_ladder": true},
	]
	for scenario_value in scenarios:
		var scenario: Dictionary = _dict(scenario_value)
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("SLOT-VISUAL-QA-BUFFALO-%s" % str(scenario.get("label", "")))
		run_state.bankroll = 100000
		var machine: Dictionary = generator.build_machine_from_ids(definition, {
			"format_id": str(scenario.get("format", "")),
			"type_id": "buffalo",
			"math_variant_id": "standard",
			"bonus_variant_id": "plain",
			"cabinet_variant_id": "neon_magenta",
		}, run_state.create_rng("machine"))
		machine = SlotMachineStateScript.set_selected_bet(machine, "bet_20")
		var active: Dictionary = buffalo.open_feature(machine, {"classification": str(scenario.get("classification", ""))}, 20, run_state.create_rng("feature"), definition)
		if str(active.get("mode", "")) == "free_games":
			machine["bonus_reel_strips"] = _coin_heavy_reel_strips(maxi(1, int(machine.get("reel_count", 5))))
			active["remaining_steps"] = 4
			active["total_steps"] = 4
		machine["active_bonus"] = active
		var rng: RngStream = run_state.create_rng("feature_steps")
		if str(active.get("mode", "")) == "hold_and_spin":
			for _hold_step in range(8):
				var hold_step_result: Dictionary = buffalo.step_bonus(machine, "slot_bonus_launch", rng, definition)
				active = _dict(hold_step_result.get("active_bonus", {}))
				machine["active_bonus"] = active
				machine["last_grid"] = _array(hold_step_result.get("grid", machine.get("last_grid", [])))
				machine["reel_stops"] = _array(hold_step_result.get("reel_stops", machine.get("reel_stops", [])))
				if _array(active.get("last_lock_events", [])).size() > 0:
					break
		elif str(active.get("mode", "")) == "free_games":
			for _free_step in range(12):
				var free_step_result: Dictionary = buffalo.step_bonus(machine, "slot_bonus_launch", rng, definition)
				active = _dict(free_step_result.get("active_bonus", {}))
				machine["active_bonus"] = active
				machine["last_grid"] = _array(free_step_result.get("grid", []))
				machine["reel_stops"] = _array(free_step_result.get("reel_stops", []))
				if int(active.get("coins_collected", 0)) >= 3:
					break
		var surface_transition: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": 200})
		var play_msec := 2200 if str(active.get("mode", "")) == "hold_and_spin" else 1600
		var surface_play: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": play_msec})
		var manifest_transition: Dictionary = renderer.render_signature(surface_transition, definition, 200, "feature")
		var manifest_play: Dictionary = renderer.render_signature(surface_play, definition, play_msec, "feature")
		if str(manifest_transition.get("stampede_phase", "")) != "transition":
			failures.append("Visual QA buffalo %s did not expose stampede transition." % str(scenario.get("label", "")))
		if str(manifest_play.get("stampede_phase", "")) == "transition":
			failures.append("Visual QA buffalo %s did not progress to feature play." % str(scenario.get("label", "")))
		if bool(scenario.get("expect_ladder", false)) and not bool(manifest_play.get("ladder_visible", false)):
			failures.append("Visual QA buffalo %s did not expose the jackpot ladder." % str(scenario.get("label", "")))
		if str(manifest_play.get("buffalo_feature_music_id", "")) != "bonus_music_buffalo":
			failures.append("Visual QA buffalo %s did not expose the feature music cue." % str(scenario.get("label", "")))
		if str(active.get("mode", "")) == "hold_and_spin" and (int(manifest_play.get("locked_cells", 0)) <= 0 or float(manifest_play.get("fill_meter", 0.0)) <= 0.0):
			failures.append("Visual QA buffalo hold feature did not expose locks and fill meter.")
		if str(active.get("mode", "")) == "hold_and_spin" and (int(manifest_play.get("buffalo_main_board_coin_value_count", 0)) <= 0 or not bool(manifest_play.get("buffalo_main_board_coin_values_visible", false))):
			failures.append("Visual QA buffalo hold feature did not expose main-board coin values.")
		if str(active.get("mode", "")) == "hold_and_spin" and not _array(active.get("last_lock_events", [])).is_empty() and not bool(manifest_play.get("buffalo_coin_bump_active", false)):
			failures.append("Visual QA buffalo hold feature did not expose the new-coin bump/glow marker.")
		if str(active.get("mode", "")) == "hold_and_spin" and int(manifest_play.get("buffalo_main_board_visible_lock_count", 0)) != int(manifest_play.get("locked_cells", 0)):
			failures.append("Visual QA buffalo hold feature visible locks did not match locked cells after the reveal beat.")
		if str(active.get("mode", "")) == "free_games" and (int(manifest_play.get("buffalo_coin_count", 0)) <= 0 or int(manifest_play.get("buffalo_coin_total", 0)) <= 0):
			failures.append("Visual QA buffalo free games did not expose coin collection state.")
		if str(active.get("mode", "")) == "free_games" and (int(manifest_play.get("buffalo_main_board_coin_value_count", 0)) <= 0 or not bool(manifest_play.get("buffalo_main_board_coin_values_visible", false))):
			failures.append("Visual QA buffalo free games did not expose main-board coin values.")
		if str(active.get("mode", "")) == "free_games" and not bool(manifest_play.get("buffalo_coin_bump_active", false)):
			failures.append("Visual QA buffalo free games did not expose the coin-reveal bump/glow marker.")
		if str(active.get("mode", "")) != "wheel" and int(manifest_play.get("buffalo_main_board_unlocked_cell_count", 0)) > 0 and bool(manifest_play.get("buffalo_unlocked_spin_active", false)):
			failures.append("Visual QA buffalo %s kept unlocked feature cells spinning after the reel animation settled." % str(scenario.get("label", "")))
		if str(active.get("mode", "")) == "wheel" and not bool(manifest_play.get("trophy_pick_active", false)):
			failures.append("Visual QA buffalo link arena did not expose trophy pick.")
		print("VISUAL_QA_BUFFALO_FEATURE machine=buffalo_%s transition=%s play=%s ladder=%s locked=%d fill=%.3f trophy=%s coins=%d coin_total=%d board_values=%d open_cells=%d music=%s bump=%s spinning=%s topper=%s" % [
			str(scenario.get("label", "")),
			str(manifest_transition.get("stampede_phase", "")),
			str(manifest_play.get("stampede_phase", "")),
			str(manifest_play.get("ladder_visible", false)),
			int(manifest_play.get("locked_cells", 0)),
			float(manifest_play.get("fill_meter", 0.0)),
			str(manifest_play.get("trophy_pick_active", false)),
			int(manifest_play.get("buffalo_coin_count", 0)),
			int(manifest_play.get("buffalo_coin_total", 0)),
			int(manifest_play.get("buffalo_main_board_coin_value_count", 0)),
			int(manifest_play.get("buffalo_main_board_unlocked_cell_count", 0)),
			str(manifest_play.get("buffalo_feature_music_id", "")),
			str(manifest_play.get("buffalo_coin_bump_active", false)),
			str(manifest_play.get("buffalo_unlocked_spin_active", false)),
			str(manifest_play.get("topper_reaction", "")),
		])


func _coin_heavy_reel_strips(reel_count: int) -> Array:
	var strips: Array = []
	if reel_count <= 3:
		for reel_index in range(maxi(1, reel_count)):
			if reel_index == 0:
				strips.append(["GOLD_TOKEN", "GOLD_TOKEN", "GOLD_TOKEN", "GOLD_TOKEN"])
			else:
				strips.append(["BUFFALO", "SUNSET", "WOLF", "ELK"])
		return strips
	for _reel in range(maxi(1, reel_count)):
		strips.append(["GOLD_TOKEN", "BUFFALO", "GOLD_TOKEN", "SUNSET", "GOLD_TOKEN", "WOLF"])
	return strips


func _spin_until_classification(definition: Dictionary, generator, resolver, family_id: String, format_id: String, classification: String, seed: String, failures: Array) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	run_state.bankroll = 100000
	var machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": format_id,
		"type_id": family_id,
		"math_variant_id": "standard",
		"bonus_variant_id": "plain",
		"cabinet_variant_id": "neon_magenta",
	}, run_state.create_rng("machine"))
	machine = SlotMachineStateScript.set_selected_bet(machine, "bet_10")
	var rng: RngStream = run_state.create_rng("spin_seek_%s" % classification)
	for _index in range(1600):
		var resolved: Dictionary = resolver.resolve_spin(machine, "spin", SlotMachineStateScript.selected_bet(machine), rng, definition, {})
		machine = _dict(resolved.get("machine", machine))
		var result: Dictionary = _dict(resolved.get("result", {}))
		if str(result.get("slot_classification", "")) == classification:
			return {"run_state": run_state, "machine": machine, "result": result}
		if SlotMachineStateScript.active_bonus_incomplete(machine):
			machine["active_bonus"] = {"active": false, "complete": true}
	failures.append("Visual QA could not find %s/%s %s sample." % [family_id, format_id, classification])
	return {}


func _reel_phases_progress(a: Dictionary, b: Dictionary, c: Dictionary) -> bool:
	var early: Array = _string_array(a.get("reel_phase", []))
	var mid: Array = _string_array(b.get("reel_phase", []))
	var settle: Array = _string_array(c.get("reel_phase", []))
	if early.is_empty() or mid.is_empty() or settle.is_empty():
		return false
	if early == mid or mid == settle:
		return false
	for phase_value in settle:
		if str(phase_value) != "settled":
			return false
	return true


func _stops_are_staggered(stops: Array) -> bool:
	if stops.size() < 2:
		return true
	for index in range(1, stops.size()):
		if int(stops[index]) <= int(stops[index - 1]):
			return false
	return true


func _settle_msec(timeline: Array) -> int:
	var result := 0
	for entry_value in timeline:
		var entry: Dictionary = _dict(entry_value)
		result = maxi(result, int(round(float(entry.get("settle_end", 0.0)) * 1000.0)) + 24)
	return maxi(100, result)


func _tease_msec(timeline: Array) -> int:
	for entry_value in timeline:
		var entry: Dictionary = _dict(entry_value)
		if bool(entry.get("tease", false)):
			var decel := float(entry.get("decel_start", 0.0))
			var stop := float(entry.get("stop_time", decel + 0.2))
			return int(round((decel + (stop - decel) * 0.55) * 1000.0))
	return _settle_msec(timeline)


func _array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		result.append(str(entry))
	return result


func _dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value as Dictionary
