extends SceneTree

const Main := preload("res://scripts/ui/foundation_main.gd")
const Video := preload("res://scripts/games/video_poker.gd")
const Renderer := preload("res://scripts/games/video_poker_renderer.gd")
const PlayerText := preload("res://scripts/ui/player_text.gd")
const Sfx := preload("res://scripts/ui/sfx_player.gd")

class ObservedSfx extends Sfx:
	var cues: Array[String] = []
	func play_surface_cue(cue_id: String, _context: Dictionary = {}, _state: Dictionary = {}, authority: Variant = null) -> void:
		if _has_surface_audio_authority(authority): cues.append(cue_id)

class ClockHost extends Main:
	var test_msec := 100000
	func _environment_simulation_time_msec() -> int: return test_msec
	func _current_game_surface_input_time_msec() -> int: return test_msec
	func _game_test_archetype() -> Dictionary:
		if OS.get_cmdline_user_args().has("--cash"):
			for value in library.environment_archetypes:
				if str((value as Dictionary).get("id", "")) == "bar": return (value as Dictionary).duplicate(true)
		return super._game_test_archetype()

class LabelSurface extends RefCounted:
	var canvas: Control
	var labels: Array[String] = []
	func surface_animation_active(channel: String) -> bool: return canvas.surface_animation_active(channel)
	func surface_animation_progress(channel: String) -> float: return canvas.surface_animation_progress(channel)
	func surface_region_hovered(_action: String, _index: int) -> bool: return false
	func draw_rect(_r: Rect2, _c: Color, _f: bool = true, _w: float = -1.0) -> void: pass
	func draw_circle(_p: Vector2, _radius: float, _c: Color) -> void: pass
	func draw_line(_a: Vector2, _b: Vector2, _c: Color, _w: float = -1.0) -> void: pass
	func surface_label(text: String, _p: Vector2, _s: int, _c: Color) -> void: labels.append(text)
	func surface_label_centered(text: String, _r: Rect2, _s: int, _c: Color) -> void: labels.append(text)
	func surface_add_exact_hit(_r: Rect2, _a: String, _i: int) -> void: pass

class ObservedRenderer extends Renderer:
	var face_down: Array = []
	func _draw_card(_s, _c: Dictionary, _r: Rect2, _h: bool, _w: bool, hidden: bool = false) -> void:
		face_down.append(hidden)

var checks := 0
var failures: Array[String] = []
var rows: Array = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var app := ClockHost.new()
	app.continuous_environment_clock_enabled = false
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	var start: Dictionary = app.start_game_test_session("video_poker")
	_check(bool(start.get("ok", false)), "Normal host opens Video Poker.")
	if not bool(start.get("ok", false)):
		_finish(app)
		return
	var audio := ObservedSfx.new()
	app.game_surface_canvas.surface_sfx_player.queue_free()
	app.game_surface_canvas.surface_sfx_player = audio
	app.game_surface_canvas.add_child(audio)
	audio.bind_surface_audio_authority(app._game_surface_audio_authority)
	var seen_return := false
	var seen_loss := false
	for round_index in range(6):
		if app.run_state == null:
			_check(false, "Fixture must remain a playable restored room.")
			break
		_sample(app, 100000 + round_index * 10000)
		var before := app.run_state.wager_capacity_for_game("video_poker", app.run_state.current_environment)
		app._on_game_surface_action("video_poker_deal", 0)
		for frame in range(12): await process_frame
		_sample(app, app.test_msec + 1000)
		await process_frame
		_check(app.run_state.wager_capacity_for_game("video_poker", app.run_state.current_environment) == before, "Opening preview does not charge a second wager.")
		var hand: Array = app.game_surface_canvas.state.get("hand", [])
		var holds := _normal_holds(hand)
		for index in holds: app._on_game_surface_action("video_poker_hold", index)
		var win_cues_before := audio.cues.count("video_poker_win")
		app._on_game_surface_action("video_poker_draw", 0)
		for frame in range(12): await process_frame
		var result: Dictionary = app.last_game_result.duplicate(true)
		_check(bool(result.get("ok", false)) and str(result.get("action_id", "")) == "draw", "One normal Draw reaches accepted settlement.")
		if not bool(result.get("ok", false)) or str(result.get("action_id", "")) != "draw": break
		var actual := app.run_state.wager_capacity_for_game("video_poker", app.run_state.current_environment)
		var cash := app.run_state.bankroll
		var chips := app.run_state.grand_casino_chips
		var rng := app.run_state.rng_state
		var stake := int(result.get("video_poker_bet", 0))
		seen_return = seen_return or int(result.get("video_poker_gross", 0)) > 0
		seen_loss = seen_loss or int(result.get("video_poker_gross", 0)) == 0
		var deltas: Dictionary = result.get("deltas", {})
		_check(actual == before + int(deltas.get("bankroll_delta", 0)) + int(deltas.get("chips_delta", 0)), "Accepted draw applies its net money exactly once.")
		var channel: Dictionary = app.game_surface_canvas.surface_animation_channels.get(Video.FLIP_CHANNEL, {})
		var started := int(channel.get("started_msec", 0))
		var duration := int(channel.get("duration_msec", 0))
		rows.append({"round": round_index, "before": before, "actual": actual, "cash": cash, "chips": chips, "rng": str(rng), "gross": result.get("video_poker_gross"), "hand_results": result.get("video_poker_hand_results"), "started": started, "duration": duration})
		_check(duration > 0, "Accepted draw retains the existing finite card flip.")
		_sample(app, started)
		_check(app.presented_bankroll_hold_active and app._presented_game_funds() == before - stake, "Wallet shows only stake while replacement cards reveal.")
		_check(app._current_game_result_snapshot().is_empty(), "Generic result cannot expose the draw outcome early.")
		_check(audio.cues.count("video_poker_win") == win_cues_before, "Cabinet win cue cannot expose an outcome before card reveal.")
		var labels := _labels(app)
		_check(not _contains(labels, "NO PAY") and not _contains(labels, "PAID ") and not _contains(labels, "PAY "), "Real renderer hides guidance, hand payout and readout until final card.")
		_check(_contains(labels, "WIN --"), "Win meter stays neutral during card replacement.")
		_check(app.game_surface_canvas.surface_action_is_blocked("video_poker_deal"), "A new deal cannot replace a pending reveal.")
		if app.game_surface_canvas.surface_action_is_blocked("video_poker_deal"):
			# A cached pointer region can outlive the frame that accepted Draw.
			# Exercise the real canvas gate rather than bypassing it at the host.
			var canvas: Control = app.game_surface_canvas
			var old_hits: Array = canvas.hit_regions.duplicate()
			canvas.hit_regions.append({"rect": Rect2(0, 0, 20, 20), "action": "video_poker_deal", "index": 0})
			canvas._activate_surface_at_position(canvas._board_to_screen(Vector2(10, 10)), false)
			canvas.hit_regions = old_hits
			_check(str(app.game_surface_canvas.state.get("phase", "")) == "settled" and app.run_state.rng_state == rng and app.run_state.bankroll == cash and app.run_state.grand_casino_chips == chips, "Repeated pending Deal cannot replace cards, transact or consume RNG.")
		_sample(app, started + duration - 1)
		_check(app.presented_bankroll_hold_active and app._presented_game_funds() == before - stake, "Wallet stays masked up to final flip boundary.")
		if round_index == 3:
			app.game_surface_canvas.reduce_motion = true
			_sample(app, started + duration - 1)
			_check(not app.presented_bankroll_hold_active and app._presented_game_funds() == actual, "Reduced motion reveals without waiting for disabled animation.")
			app.game_surface_canvas.reduce_motion = false
		_sample(app, started + duration)
		_check(not app.presented_bankroll_hold_active and app._presented_game_funds() == actual, "Final card releases accepted funds.")
		labels = _labels(app)
		_check(_contains(labels, str(result.get("video_poker_pay_label", "")).to_upper()), "Real renderer restores final pay label.")
		if round_index < 4:
			_check(audio.cues.count("video_poker_win") == win_cues_before + (1 if int(result.get("video_poker_gross", 0)) > 0 else 0), "Cabinet win cue plays once at reveal.")
		var released_win_cues := audio.cues.count("video_poker_win")
		_sample(app, started + duration + 1)
		_check(app.run_state.bankroll == cash and app.run_state.grand_casino_chips == chips and app.run_state.rng_state == rng, "Repeated presentation frame cannot transact or consume RNG.")
		_check(audio.cues.count("video_poker_win") == released_win_cues, "Repeated presentation frame cannot repeat cabinet win cue.")
	_check(seen_return and seen_loss, "Bounded ordinary holds/draws cover a returned payout and no pay.")
	_finish(app)

func _normal_holds(hand: Array) -> Array:
	for a in range(hand.size()):
		for b in range(a + 1, hand.size()):
			if int(hand[a].get("rank", 0)) == int(hand[b].get("rank", 0)): return [a, b]
	for index in range(hand.size()):
		if int(hand[index].get("rank", 0)) == 1 or int(hand[index].get("rank", 0)) >= 11: return [index]
	return []

func _sample(app: ClockHost, msec: int) -> void:
	app.test_msec = msec
	app.game_surface_canvas.surface_simulation_clock_msec = msec
	app.game_surface_canvas.surface_presentation_clock_msec = msec
	app._advance_presented_bankroll()
	app._refresh_financial_hud_if_dirty()
	app._flush_money_feedback()

func _labels(app: ClockHost) -> Array[String]:
	var state: Dictionary = app.game_surface_canvas.state
	var original := JSON.stringify(state)
	var surface := LabelSurface.new()
	surface.canvas = app.game_surface_canvas
	var renderer := ObservedRenderer.new()
	var palette: Dictionary = renderer._palette(state)
	renderer._draw_hands(surface, state, palette)
	renderer._draw_controls(surface, state, palette)
	renderer._draw_machine_ritual_layer(surface, state, palette)
	if str(state.get("phase", "")) == "settled":
		if app.game_surface_canvas.surface_animation_active(Video.FLIP_CHANNEL):
			_check(renderer.face_down.has(true), "Pending result still renders replacement card backs.")
		else:
			_check(not renderer.face_down.has(true), "Final result renders every card face up.")
	_check(JSON.stringify(state) == original, "Rendering does not mutate authoritative cards or outcome.")
	return surface.labels

func _contains(labels: Array[String], text: String) -> bool:
	if text.is_empty(): return false
	for label in labels:
		if label.contains(text): return true
	return false

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _finish(app: ClockHost) -> void:
	if app.save_service.async_save_in_flight(): app.save_service.wait_for_async_save()
	app.free()
	print("VIDEO_POKER_REVEAL_RESULT " + JSON.stringify({"checks": checks, "rows": rows, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
