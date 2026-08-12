extends SceneTree

# Focused regression gate for the momentary Heat-gain response and the shared
# persistent police-light presentation.

const MainScene := preload("res://scenes/main.tscn")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")

var failures: Array[String] = []
var emitted_heat_events: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app: Control = MainScene.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame

	var overlay: Control = app.get("heat_gain_feedback_overlay")
	var hud: Control = app.get("structured_hud")
	var run_screen: Control = app.get("run_screen")
	if overlay == null or hud == null or run_screen == null:
		_fail("The run UI did not create the Heat feedback overlay and HUD.")
		_finish({})
		return
	if overlay.get_parent() != run_screen:
		_fail("The Heat feedback overlay is not attached above the complete run screen.")
	if overlay.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("The Heat feedback overlay can intercept player input.")

	app.call("start_foundation_run", "HEAT-FEEDBACK-REGRESSION")
	await process_frame
	var state: RunState = app.get("run_state")
	var callback := Callable(app, "_on_run_state_heat_changed")
	if state == null or not state.heat_changed.is_connected(callback):
		_fail("The active run is not connected to the Heat feedback presentation.")

	var integrated_applied := state.add_suspicion("probe_small", 2, "probe", true)
	if integrated_applied != 2:
		_fail("The active run did not apply the expected +2 Heat integration fixture.")
	var small_overlay: Dictionary = overlay.call("debug_snapshot")
	var small_hud: Dictionary = hud.call("current_snapshot")
	_assert_active_feedback(small_overlay, small_hud, 2, "small gain")
	if float(small_overlay.get("peak_alpha", 0.0)) < 0.23:
		_fail("The +2 Heat response is not visually strong enough.")
	if float(small_overlay.get("edge_fraction", 0.0)) < 0.16:
		_fail("The +2 Heat response does not extend far enough into the screen.")
	if small_overlay.has("inner_rim_alpha"):
		_fail("The Heat response still exposes the removed opaque inner rim.")

	overlay.call("cancel")
	hud.call("reset_wallet_delta")
	app.call("_on_run_state_heat_changed", 20, 20, "probe_large", {})
	var large_overlay: Dictionary = overlay.call("debug_snapshot")
	var large_hud: Dictionary = hud.call("current_snapshot")
	_assert_active_feedback(large_overlay, large_hud, 20, "large gain")
	if float(large_overlay.get("intensity", 0.0)) <= float(small_overlay.get("intensity", 0.0)):
		_fail("A large Heat gain is not stronger than a small Heat gain.")
	if float(large_overlay.get("peak_alpha", 0.0)) <= float(small_overlay.get("peak_alpha", 0.0)):
		_fail("A large Heat gain does not produce a stronger edge treatment.")
	if float(large_overlay.get("edge_fraction", 0.0)) <= float(small_overlay.get("edge_fraction", 0.0)):
		_fail("A large Heat gain does not produce a wider edge treatment.")
	if str(large_overlay.get("edge_color_hex", "")).to_lower() != "ff2d35":
		_fail("The momentary Heat-gain border is not using the approved red warning color.")

	overlay.call("cancel")
	hud.call("reset_wallet_delta")
	app.call("_on_run_state_heat_changed", 2, 2, "probe_rapid_a", {})
	app.call("_on_run_state_heat_changed", 3, 5, "probe_rapid_b", {})
	var rapid_overlay: Dictionary = overlay.call("debug_snapshot")
	var rapid_hud: Dictionary = hud.call("current_snapshot")
	_assert_active_feedback(rapid_overlay, rapid_hud, 5, "rapid combined gain")

	overlay.call("_process", 0.51)
	hud.call("_process", 0.51)
	var expired_overlay: Dictionary = overlay.call("debug_snapshot")
	var expired_hud: Dictionary = hud.call("current_snapshot")
	if bool(expired_overlay.get("active", true)) or bool(expired_overlay.get("visible", true)):
		_fail("The screen-edge Heat response lasts longer than 0.5 seconds.")
	if bool(expired_hud.get("heat_feedback_active", true)) or not str(expired_hud.get("heat_delta_badge", "")).is_empty():
		_fail("The HUD Heat response lasts longer than 0.5 seconds.")

	overlay.call("set_reduce_motion", true)
	hud.call("set_reduce_motion", true)
	app.call("_on_run_state_heat_changed", 4, 4, "probe_reduced_motion", {})
	var reduced_overlay: Dictionary = overlay.call("debug_snapshot")
	var reduced_hud: Dictionary = hud.call("current_snapshot")
	if bool(reduced_overlay.get("visible", true)):
		_fail("Reduced-motion mode still flashes the screen-edge response.")
	if str(reduced_hud.get("heat_delta_badge", "")) != "+4":
		_fail("Reduced-motion mode removed the non-animated +Heat HUD cue.")

	var cap_report := _heat_cap_report()
	var parity_report := _police_overlay_parity_report()
	var audio_report := _heat_audio_report()
	_finish({
		"small": small_overlay,
		"large": large_overlay,
		"rapid": rapid_overlay,
		"expired": expired_overlay,
		"reduced_motion": reduced_overlay,
		"cap": cap_report,
		"police_overlay_parity": parity_report,
		"audio": audio_report,
	})


func _assert_active_feedback(overlay: Dictionary, hud: Dictionary, expected_amount: int, label: String) -> void:
	if not bool(overlay.get("active", false)) or not bool(overlay.get("visible", false)):
		_fail("The %s did not show a screen-edge response." % label)
	if int(overlay.get("amount", -1)) != expected_amount:
		_fail("The %s edge response showed +%d instead of +%d." % [label, int(overlay.get("amount", -1)), expected_amount])
	if not is_equal_approx(float(overlay.get("duration_sec", 0.0)), 0.5):
		_fail("The %s edge response is not configured for exactly 0.5 seconds." % label)
	if str(hud.get("heat_delta_badge", "")) != "+%d" % expected_amount:
		_fail("The %s HUD badge did not show the applied amount." % label)
	if int(hud.get("heat_feedback_amount", -1)) != expected_amount:
		_fail("The %s HUD pulse did not retain the applied amount." % label)


func _heat_cap_report() -> Dictionary:
	emitted_heat_events.clear()
	var state: RunState = RunStateScript.new()
	state.start_new("HEAT-CAP-REGRESSION")
	state.suspicion["level"] = 98
	state.heat_changed.connect(_capture_heat_event)
	var applied := state.add_suspicion("probe_cap", 10, "probe", true)
	if applied != 2 or state.suspicion_level() != 100:
		_fail("Heat cap handling did not apply exactly the remaining 2 Heat.")
	if emitted_heat_events.size() != 1 or int(emitted_heat_events[0].get("amount", -1)) != 2:
		_fail("Heat feedback did not receive the actual capped amount of +2.")
	return {
		"requested": 10,
		"applied": applied,
		"level": state.suspicion_level(),
		"events": emitted_heat_events.duplicate(true),
	}


func _capture_heat_event(applied_amount: int, level: int, cue_id: String, context: Dictionary) -> void:
	emitted_heat_events.append({
		"amount": applied_amount,
		"level": level,
		"cue_id": cue_id,
		"context": context.duplicate(true),
	})


func _police_overlay_parity_report() -> Dictionary:
	var environment_canvas = PixelSceneCanvasScript.new()
	var game_canvas = GameSurfaceCanvasScript.new()
	var samples: Array[Dictionary] = []
	for level in [1, 25, 49, 50, 75, 100]:
		environment_canvas.set("suspicion_level", level)
		game_canvas.set("state", {"suspicion_level": level})
		var environment_profile: Dictionary = environment_canvas.call("pressure_overlay_debug_profile", 0.37)
		var game_profile: Dictionary = game_canvas.call("pressure_overlay_debug_profile", 0.37)
		var matches := environment_profile == game_profile
		if not matches:
			_fail("Police-light Heat overlay drifted between environment and game views at Heat %d." % level)
		samples.append({"level": level, "matches": matches, "profile": environment_profile})
	environment_canvas.free()
	game_canvas.free()
	return {"all_match": failures.filter(func(message: String) -> bool: return message.contains("overlay drifted")).is_empty(), "samples": samples}


func _heat_audio_report() -> Dictionary:
	var player = SfxPlayerScript.new()
	var small: Dictionary = player.call("heat_gain_audio_profile", 2)
	var large: Dictionary = player.call("heat_gain_audio_profile", 20)
	var stream: AudioStreamWAV = player.call("render_event_master_stream", "heat_gain")
	if str(small.get("event_id", "")) != "heat_gain" or not is_equal_approx(float(small.get("duration_sec", 0.0)), 0.30):
		_fail("The Heat-gain sound is not routed as a short 0.30-second cue.")
	if float(large.get("volume_db", -100.0)) <= float(small.get("volume_db", -100.0)):
		_fail("A large Heat gain does not produce a slightly stronger sound cue.")
	if float(large.get("pitch", 0.0)) <= float(small.get("pitch", 0.0)):
		_fail("A large Heat gain does not produce a slightly higher sound cue.")
	if str(player.call("debug_normalized_event_id", "heat_gain")) != "heat_gain":
		_fail("The Heat-gain sound is not preserved by the central SFX cue router.")
	if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.mix_rate != 22050 or stream.data.size() < 12000:
		_fail("The Heat-gain procedural sound did not generate valid 16-bit PCM audio.")
	var report := {
		"small": small,
		"large": large,
		"sample_rate": stream.mix_rate if stream != null else 0,
		"pcm_bytes": stream.data.size() if stream != null else 0,
	}
	player.free()
	return report


func _fail(message: String) -> void:
	failures.append(message)


func _finish(details: Dictionary) -> void:
	var report := {
		"tool": "heat_feedback_probe",
		"passed": failures.is_empty(),
		"failures": failures,
		"details": details,
	}
	print(JSON.stringify(report, "\t"))
	quit(0 if failures.is_empty() else 1)
