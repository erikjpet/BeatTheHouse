class_name SfxPlayer
extends Node

const WebAudioBridgeScript := preload("res://scripts/ui/web_audio_bridge.gd")

# Central procedural SFX router for game surfaces and environment UI.
#
# The rest of the app should call the generic play/sync methods below and pass
# cue ids from surface_audio specs. To redesign or add sounds later, keep the
# app-facing cue ids stable and update this file's cue routes, event aliases, or
# procedural samples in one place.

signal music_cue_requested(cue_id: String, context: Dictionary)

const SFX_BUS := "SFX"
const SAMPLE_RATE := 22050
const WEB_SAMPLE_RATE := 6000
const TELEPHONE_SAMPLE_RATE := 4000
const PCM_BYTES_PER_FRAME := 2
const SLOT_CLASSIC_REEL_STOP_TIMES := [1.05, 1.55, 2.15]
const SLOT_POST_REEL_BONUS_DELAY := 0.40
const SLOT_BONUS_STEP_TIME := 0.72
const ONE_SHOT_PLAYER_COUNT := 10
const WEB_SURFACE_LOOP_ID := "sfx:surface_loop"
const BLACKJACK_PREWARM_EVENTS := [
	"blackjack_card",
	"blackjack_chip",
	"blackjack_felt",
	"blackjack_payout",
	"blackjack_bust",
	"blackjack_peek",
	"blackjack_count",
	"blackjack_distraction",
]
const ROULETTE_PREWARM_EVENTS := [
	"roulette_chip_select",
	"roulette_chip_place",
	"roulette_chip_lift",
	"roulette_chip_stack",
	"roulette_chip_sweep",
	"roulette_rotor_launch",
	"roulette_ball_loop",
	"roulette_ball_rim_tick",
	"roulette_ball_drop",
	"roulette_ball_scatter",
	"roulette_ball_bounce",
	"roulette_ball_pocket",
	"roulette_dolly_tap",
	"roulette_payout",
]
const ENVIRONMENT_PREWARM_EVENTS := [
	"phone_call",
	"drink_consumed",
	"scratch_paper_foley_loop",
	"scratch_box_pop",
]
const WEB_PREWARM_SAMPLES_PER_FRAME := 32
const NATIVE_PREWARM_BUDGET_USEC := 500
const NATIVE_PREWARM_TIME_CHECK_INTERVAL := 8
const WEB_CRITICAL_PREWARM_EVENTS := [
	"blackjack_card",
	"blackjack_chip",
	"roulette_chip_select",
	"roulette_chip_place",
	"roulette_rotor_launch",
	"roulette_ball_loop",
]
const ROULETTE_RIM_TIMES := [0.42, 0.82, 1.26, 1.78, 2.34, 2.94, 3.32]
const ROULETTE_SCATTER_TIMES := [3.66, 3.86, 4.08, 4.32]
const MUSIC_DIRECTOR_CUES := {
	"bonus_music_buffalo": true,
	"bonus_music_pinball": true,
	"pinball_feature_intro": true,
	"pinball_multiball": true,
	"pinball_jackpot_lane": true,
	"pinball_super_jackpot": true,
	"jackpot_buffalo": true,
	"jackpot_hit_buffalo": true,
	"bonus_total_buffalo": true,
	"buffalo_gateway_jackpot_boost": true,
	"buffalo_grand_escalation": true,
	"buffalo_retrigger": true,
	"buffalo_spin_reset": true,
}
const SURFACE_CUE_ROUTES := {
	"machine_button": "slot_button",
	"ticket_dispenser": "pull_tab",
	"ticket_peel": "pull_tab",
	"ticket_navigation": "pull_tab",
	"blackjack_deal": "blackjack",
	"blackjack_hit": "blackjack",
	"blackjack_stand": "blackjack",
	"blackjack_double": "blackjack",
	"blackjack_split": "blackjack",
	"blackjack_surrender": "blackjack",
	"blackjack_side_bet": "blackjack",
	"blackjack_chip": "blackjack",
	"blackjack_patron_bet": "blackjack",
	"blackjack_clear_bet": "blackjack",
	"blackjack_max_bet": "blackjack",
	"blackjack_distraction": "blackjack",
	"blackjack_patron_cover": "blackjack",
	"blackjack_peek": "blackjack",
	"blackjack_count": "blackjack",
	"blackjack_count_toggle": "blackjack",
	"blackjack_count_icon": "blackjack",
	"baccarat_bet": "baccarat",
	"baccarat_chip": "baccarat",
	"baccarat_patron_bet": "baccarat",
	"baccarat_clear": "baccarat",
	"baccarat_undo": "baccarat",
	"baccarat_rebet": "baccarat",
	"baccarat_max_bet": "baccarat",
	"baccarat_deal": "baccarat",
	"baccarat_read_shoe": "baccarat",
	"roulette_bet": "roulette",
	"roulette_chip": "roulette",
	"roulette_patron_bet": "roulette",
	"roulette_clear": "roulette",
	"roulette_undo": "roulette",
	"roulette_rebet": "roulette",
	"roulette_double": "roulette",
	"roulette_max_bet": "roulette",
	"roulette_spin": "roulette",
	"roulette_read_wheel": "roulette",
	"surface_stake_up": "surface",
	"surface_stake_down": "surface",
	"surface_stake_max": "surface",
}

var audio_enabled: bool = true

var _players: Array = []
var _loop_player: AudioStreamPlayer
var _stream_cache: Dictionary = {}
var _animation_id: String = ""
var _feature_scene_audio_id: String = ""
var _feature_music_id: String = ""
var _blackjack_deal_id: String = ""
var _blackjack_payout_id: String = ""
var _roulette_spin_id: String = ""
var _roulette_payout_id: String = ""
var _baccarat_deal_id: String = ""
var _baccarat_payout_id: String = ""
var _web_surface_loop_active := false
var _surface_loop_event_id := ""
var _surface_loop_fade_tween: Tween
var _played_markers: Dictionary = {}
var _normalized_event_cache: Dictionary = {}
var _prewarm_queue: Array[String] = []
var _prewarm_event_override: Array[String] = []
var _prewarm_started := false
var _prewarm_active_event_id := ""
var _prewarm_active_seconds := 0.0
var _prewarm_active_sample_rate := 0
var _prewarm_active_frame_count := 0
var _prewarm_active_frame_cursor := 0
var _prewarm_active_data := PackedByteArray()


func set_prewarm_events(event_ids: Array) -> void:
	_prewarm_event_override.clear()
	for event_id in event_ids:
		var normalized := _normalized_event_id(str(event_id))
		if not normalized.is_empty() and not _prewarm_event_override.has(normalized):
			_prewarm_event_override.append(normalized)
	if _prewarm_started:
		_prewarm_started = false
		_clear_prewarm_event()
		_begin_incremental_prewarm()


func _ready() -> void:
	if WebAudioBridgeScript.available():
		WebAudioBridgeScript.ensure()
	if not _running_headless():
		set_process(false)
		_ensure_players()
		call_deferred("_begin_incremental_prewarm")


func _process(_delta: float) -> void:
	_process_prewarm_chunk()


func play_surface_cue(cue_id: String, context: Dictionary = {}, surface_state: Dictionary = {}) -> void:
	if not audio_enabled or _running_headless():
		return
	var normalized_cue := cue_id.strip_edges()
	if normalized_cue.is_empty():
		return
	if _emit_music_director_cue(normalized_cue, context):
		return
	_ensure_players()
	var action := str(context.get("action", normalized_cue))
	var route := str(context.get("route", SURFACE_CUE_ROUTES.get(normalized_cue, SURFACE_CUE_ROUTES.get(action, ""))))
	match route:
		"slot_button":
			play_slot_button(action, surface_state)
		"pull_tab":
			play_pull_tab_event(action)
		"blackjack":
			play_blackjack_event(action)
		"baccarat":
			play_baccarat_event(action)
		"roulette":
			play_roulette_event(action)
		"surface":
			_play_surface_stake_event(action, surface_state)
		_:
			if normalized_cue.begins_with("blackjack_"):
				play_blackjack_event(action)
			elif normalized_cue.begins_with("baccarat_"):
				play_baccarat_event(action)
			elif normalized_cue.begins_with("roulette_") and not _is_known_event(normalized_cue):
				play_roulette_event(action)
			else:
				_play(normalized_cue, float(context.get("volume_db", -3.0)), float(context.get("pitch", 1.0)))


func start_surface_loop(cue_id: String, volume_db: float = -10.0, pitch: float = 1.0) -> void:
	if not audio_enabled or _running_headless():
		return
	var clean_cue := cue_id.strip_edges()
	if clean_cue.is_empty():
		return
	var normalized_cue := _normalized_event_id(clean_cue)
	_ensure_players()
	if normalized_cue == _surface_loop_event_id and ((_loop_player != null and _loop_player.playing) or _web_surface_loop_active):
		if _surface_loop_fade_tween != null and _surface_loop_fade_tween.is_valid():
			_surface_loop_fade_tween.kill()
		if _loop_player != null:
			_loop_player.volume_db = volume_db
			_loop_player.pitch_scale = pitch
		return
	_stop_reel_loop()
	_start_reel_loop(normalized_cue, volume_db, pitch)


func stop_surface_loop(cue_id: String = "") -> void:
	var normalized_cue := _normalized_event_id(cue_id.strip_edges()) if not cue_id.strip_edges().is_empty() else ""
	if not normalized_cue.is_empty() and normalized_cue != _surface_loop_event_id:
		return
	if _surface_loop_event_id == "scratch_paper_foley_loop" and not _web_surface_loop_active and _loop_player != null and _loop_player.playing:
		if _surface_loop_fade_tween != null and _surface_loop_fade_tween.is_valid():
			_surface_loop_fade_tween.kill()
		_surface_loop_fade_tween = create_tween()
		_surface_loop_fade_tween.tween_property(_loop_player, "volume_db", -36.0, 0.07)
		_surface_loop_fade_tween.tween_callback(Callable(self, "_stop_reel_loop"))
		return
	_stop_reel_loop()


func sync_surface_state(surface_state: Dictionary, sync_spec: Dictionary, timing: Dictionary) -> void:
	if not audio_enabled or _running_headless():
		return
	var method := str(sync_spec.get("method", ""))
	match method:
		"reel_machine_state":
			var channel_id := str(sync_spec.get("animation_channel", ""))
			var feature_channel_id := str(sync_spec.get("feature_animation_channel", "slot_feature"))
			var nudge_chain_channel_id := str(sync_spec.get("nudge_chain_channel", "slot_nudge_chain"))
			var slot_state := surface_state.duplicate(false)
			slot_state["_surface_audio_timing"] = {
				"spin_elapsed": _timing_elapsed(timing, "animation_channel"),
				"spin_active": _timing_active(timing, "animation_channel"),
				"spin_active_id": _timing_active_id(timing, "animation_channel"),
				"feature_elapsed": _timing_elapsed(timing, "feature_animation_channel"),
				"feature_active": _timing_active(timing, "feature_animation_channel"),
				"feature_active_id": _timing_active_id(timing, "feature_animation_channel"),
				"nudge_chain_elapsed": _timing_elapsed(timing, "nudge_chain_channel"),
				"nudge_chain_active": _timing_active(timing, "nudge_chain_channel"),
				"nudge_chain_active_id": _timing_active_id(timing, "nudge_chain_channel"),
				"spin_channel_id": channel_id,
				"feature_channel_id": feature_channel_id,
				"nudge_chain_channel_id": nudge_chain_channel_id,
			}
			var slot_elapsed := _timing_elapsed(timing, "animation_channel")
			var slot_active := _timing_active(timing, "animation_channel")
			if bool(surface_state.get("slot_nudge_chain_active", false)):
				slot_elapsed = _timing_elapsed(timing, "nudge_chain_channel")
				slot_active = _timing_active(timing, "nudge_chain_channel")
			sync_slot_state(slot_state, slot_elapsed, slot_active)
		"pull_tab_dispense_state":
			sync_pull_tab_dispense(
				surface_state,
				_timing_elapsed(timing, "animation_channel"),
				_timing_active(timing, "animation_channel"),
				_timing_active_id(timing, "animation_channel")
			)
		"blackjack_table_state":
			sync_blackjack_state(
				surface_state,
				_timing_elapsed(timing, "deal_animation_channel"),
				_timing_active(timing, "deal_animation_channel"),
				_timing_active_id(timing, "deal_animation_channel"),
				_timing_elapsed(timing, "payout_animation_channel"),
				_timing_active(timing, "payout_animation_channel"),
				_timing_active_id(timing, "payout_animation_channel")
			)
		"roulette_table_state":
			sync_roulette_state(
				surface_state,
				_timing_elapsed(timing, "spin_animation_channel"),
				_timing_active(timing, "spin_animation_channel"),
				_timing_active_id(timing, "spin_animation_channel"),
				_timing_elapsed(timing, "payout_animation_channel"),
				_timing_active(timing, "payout_animation_channel"),
				_timing_active_id(timing, "payout_animation_channel")
			)
		"baccarat_table_state":
			sync_baccarat_state(
				surface_state,
				_timing_elapsed(timing, "deal_animation_channel"),
				_timing_active(timing, "deal_animation_channel"),
				_timing_active_id(timing, "deal_animation_channel"),
				_timing_elapsed(timing, "payout_animation_channel"),
				_timing_active(timing, "payout_animation_channel"),
				_timing_active_id(timing, "payout_animation_channel")
			)


func _play_surface_stake_event(action: String, surface_state: Dictionary) -> void:
	var audio := _dict(surface_state.get("surface_audio", {}))
	var profile_id := str(audio.get("profile_id", ""))
	if profile_id == "roulette_table":
		play_roulette_event(action)
	elif profile_id == "baccarat_table":
		play_baccarat_event(action)
	elif profile_id == "blackjack_table":
		play_blackjack_event(action)
	else:
		_play("button", -6.0, 1.0)


func _timing_entry(timing: Dictionary, key: String) -> Dictionary:
	return _dict(timing.get(key, {}))


func _timing_elapsed(timing: Dictionary, key: String) -> float:
	return float(_timing_entry(timing, key).get("elapsed", 999.0))


func _timing_active(timing: Dictionary, key: String) -> bool:
	return bool(_timing_entry(timing, key).get("active", false))


func _timing_active_id(timing: Dictionary, key: String) -> String:
	return str(_timing_entry(timing, key).get("active_id", ""))


func _is_known_event(event_id: String) -> bool:
	return _normalized_event_id(event_id) == event_id


func _emit_music_director_cue(cue_id: String, context: Dictionary = {}) -> bool:
	var raw_cue := cue_id.strip_edges()
	if raw_cue.is_empty():
		return false
	var normalized := _normalized_event_id(raw_cue)
	if not bool(MUSIC_DIRECTOR_CUES.get(raw_cue, false)) and not bool(MUSIC_DIRECTOR_CUES.get(normalized, false)):
		return false
	var payload := context.duplicate(true)
	payload["cue_id"] = raw_cue
	payload["normalized_event_id"] = normalized
	music_cue_requested.emit(raw_cue, payload)
	return true


func sync_slot_state(slot_state: Dictionary, elapsed: float, animation_active: bool) -> void:
	if not audio_enabled or _running_headless():
		return
	var timing := _dict(slot_state.get("_surface_audio_timing", {}))
	var feature_scene := _dict(slot_state.get("slot_feature_scene", {}))
	var feature_active := bool(feature_scene.get("active", false))
	var incoming_id := _active_slot_audio_id(slot_state, feature_scene, timing)
	if incoming_id.is_empty():
		_stop_reel_loop()
		_stop_one_shot_loops()
		_animation_id = ""
		_feature_scene_audio_id = ""
		_feature_music_id = ""
		_played_markers.clear()
		return
	_ensure_players()
	var profile := _slot_audio_profile(slot_state)
	var cue_stream := _slot_audio_cues(slot_state)
	var reel_stop_times := _slot_reel_stop_times(slot_state)
	var last_stop_time := float(reel_stop_times[reel_stop_times.size() - 1]) if not reel_stop_times.is_empty() else 0.0
	var bonus_start_time := float(slot_state.get("slot_bonus_start_time", last_stop_time + SLOT_POST_REEL_BONUS_DELAY))
	var spin_audio_active := animation_active or bool(timing.get("spin_active", false))
	if feature_active:
		_stop_reel_loop()
		_stop_one_shot_loops()
	if incoming_id != _animation_id:
		_animation_id = incoming_id
		_played_markers.clear()
		if spin_audio_active and not feature_active:
			var start_cue := _cue_by_phase(cue_stream, "spin_start")
			if not start_cue.is_empty():
				_trigger_cue(incoming_id, start_cue, true, profile, float(profile.get("start_volume_db", 0.0)), float(profile.get("start_pitch", 1.0)))
			else:
				var start_event := str(profile.get("nudge_event", "nudge")) if bool(slot_state.get("slot_nudge_applied", false)) else str(profile.get("lever_event", "lever"))
				_play(start_event, float(profile.get("start_volume_db", 0.0)), float(profile.get("start_pitch", 1.0)))
			var loop_cue := _cue_by_phase(cue_stream, "spin_loop")
			var loop_event := _cue_id(loop_cue, str(profile.get("loop_event", "reel_loop"))) if not loop_cue.is_empty() else str(profile.get("loop_event", "reel_loop"))
			_start_reel_loop(loop_event, float(profile.get("loop_volume_db", -13.0)), float(profile.get("loop_pitch", 1.0)))

	var stop_cues := _cues_by_phase(cue_stream, "reel_stop")
	if not stop_cues.is_empty():
		for cue in stop_cues:
			var reel_index := int(cue.get("reel_index", 0))
			var pitch := float(profile.get("stop_pitch", 1.0)) + float(reel_index) * float(profile.get("stop_pitch_step", -0.035))
			var volume := float(profile.get("stop_volume_db", -2.5)) + minf(0.9, float(reel_index) * 0.12)
			_trigger_cue(incoming_id, cue, elapsed >= _cue_time(cue, 0.0), profile, volume, pitch)
	else:
		for index in range(reel_stop_times.size()):
			var stop_time := float(reel_stop_times[index])
			var pitch := float(profile.get("stop_pitch", 1.0)) + float(index) * float(profile.get("stop_pitch_step", -0.035))
			var volume := float(profile.get("stop_volume_db", -2.5)) + minf(0.9, float(index) * 0.12)
			_trigger("reel_stop_%d" % index, elapsed >= stop_time, str(profile.get("stop_event", "reel_stop")), volume, pitch)
	if elapsed >= last_stop_time or not animation_active:
		_stop_reel_loop()

	if not cue_stream.is_empty():
		_sync_slot_audio_cues(incoming_id, cue_stream, elapsed, profile)

	if feature_active:
		_sync_feature_music(feature_scene, profile)
		_sync_feature_scene_cues(slot_state, profile, elapsed)
		return
	if not _feature_music_id.is_empty():
		_feature_music_id = ""

	var bonus_steps := _dictionary_array(slot_state.get("slot_bonus_steps", []))
	if cue_stream.is_empty() and not bonus_steps.is_empty():
		_trigger("bonus_start", elapsed >= bonus_start_time, str(profile.get("bonus_start_event", "bonus_start")), -1.0, float(profile.get("bonus_pitch", 1.0)))
		for i in range(bonus_steps.size()):
			var step: Dictionary = bonus_steps[i]
			var step_time := bonus_start_time + float(i) * SLOT_BONUS_STEP_TIME + 0.28
			var event_id := str(profile.get("jackpot_step_event", "jackpot_hit")) if bool(step.get("jackpot", false)) else str(profile.get("step_event", "bumper"))
			var pitch := float(profile.get("step_pitch", 0.92)) + float(i % 4) * float(profile.get("step_pitch_delta", 0.08))
			_trigger("bonus_step_%d" % i, elapsed >= step_time, event_id, -2.0, pitch)

	var final_time := last_stop_time + 0.35
	if not bonus_steps.is_empty():
		final_time = bonus_start_time + float(bonus_steps.size()) * SLOT_BONUS_STEP_TIME + 0.22
	if cue_stream.is_empty() and animation_active and elapsed >= final_time:
		_trigger_final(slot_state, profile)


func play_slot_button(action: String = "", slot_state: Dictionary = {}) -> void:
	if not audio_enabled or _running_headless():
		return
	_ensure_players()
	var profile := _slot_audio_profile(slot_state)
	var event_id := str(profile.get("nudge_button_event", "nudge")) if action == "slot_nudge" else str(profile.get("button_event", "button"))
	var pitch := float(profile.get("button_pitch", 1.0))
	if action == "slot_nudge":
		pitch = float(profile.get("nudge_button_pitch", 0.86))
	_play(event_id, -5.0, pitch)


func play_slot_event(event_id: String, volume_db: float = -3.0, pitch: float = 1.0) -> void:
	if not audio_enabled or _running_headless():
		return
	if _emit_music_director_cue(event_id, {"volume_db": volume_db, "pitch": pitch}):
		return
	_ensure_players()
	_play(event_id, volume_db, pitch)


func play_pull_tab_event(action: String = "") -> void:
	if not audio_enabled or _running_headless():
		return
	_ensure_players()
	match action:
		"pull_tab_buy", "pull_tab_buy_all":
			_play("pull_tab_click", -4.5, 1.0)
		"pull_tab_peek":
			_play("paper_peek", -5.0, 0.92)
		"pull_tab_reveal_next":
			_play("paper_peel", -4.0, 1.0)
		_:
			_play("button", -6.0, 1.0)


func play_blackjack_event(action: String = "") -> void:
	if not audio_enabled or _running_headless():
		return
	_ensure_players()
	match action:
		"blackjack_deal":
			_play("blackjack_chip", -5.0, 0.92)
			_play("blackjack_card", -4.0, 1.0)
		"blackjack_hit":
			_play("blackjack_card", -3.5, 1.04)
		"blackjack_double":
			_play("blackjack_chip", -4.2, 1.08)
			_play("blackjack_card", -3.8, 0.96)
		"blackjack_split":
			_play("blackjack_chip", -4.6, 0.95)
			_play("blackjack_card", -3.8, 1.12)
		"blackjack_stand", "blackjack_surrender":
			_play("blackjack_felt", -5.0, 1.0)
		"blackjack_side_bet", "blackjack_chip", "surface_stake_up", "surface_stake_down", "surface_stake_max", "blackjack_clear_bet", "blackjack_max_bet":
			_play("blackjack_chip", -4.5, 1.0)
		"blackjack_peek":
			_play("blackjack_peek", -5.0, 0.96)
		"blackjack_count", "blackjack_count_toggle":
			_play("blackjack_count", -5.0, 1.0)
		"blackjack_count_icon":
			_play("blackjack_count", -4.8, 1.18)
		"blackjack_distraction", "blackjack_patron_cover":
			_play("blackjack_distraction", -4.8, 1.0)
		"blackjack_card":
			_play("blackjack_card", -3.8, 1.0)
		"blackjack_payout":
			_play("blackjack_payout", -3.0, 1.0)
		"blackjack_bust":
			_play("blackjack_bust", -5.2, 1.0)
		_:
			_play("button", -6.0, 1.0)


func play_roulette_event(action: String = "") -> void:
	if not audio_enabled or _running_headless():
		return
	_ensure_players()
	match action:
		"roulette_bet":
			_play("roulette_chip_place", -4.0, 0.98)
		"roulette_chip", "surface_stake_up":
			_play("roulette_chip_select", -5.0, 1.02)
		"roulette_undo", "surface_stake_down":
			_play("roulette_chip_lift", -5.2, 0.96)
		"roulette_clear":
			_play("roulette_chip_sweep", -4.0, 0.94)
		"roulette_rebet", "roulette_double", "roulette_max_bet", "surface_stake_max":
			_play("roulette_chip_stack", -3.8, 1.0)
		"roulette_spin":
			_play("roulette_dolly_tap", -4.8, 1.02)
		"roulette_read_wheel":
			_play("roulette_dolly_tap", -5.2, 0.92)
		"roulette_payout":
			_play("roulette_payout", -3.0, 0.96)
		_:
			_play("button", -6.0, 0.95)


func play_baccarat_event(action: String = "") -> void:
	if not audio_enabled or _running_headless():
		return
	_ensure_players()
	match action:
		"baccarat_bet", "baccarat_chip", "baccarat_clear", "baccarat_undo", "baccarat_rebet", "baccarat_max_bet", "surface_stake_up", "surface_stake_down", "surface_stake_max":
			_play("blackjack_chip", -4.5, 1.02)
		"baccarat_deal":
			_play("blackjack_chip", -5.0, 0.95)
			_play("blackjack_card", -3.8, 0.92)
		"baccarat_read_shoe":
			_play("blackjack_peek", -5.0, 0.88)
		"baccarat_payout":
			_play("blackjack_payout", -3.0, 0.98)
		_:
			_play("button", -6.0, 1.0)


func sync_pull_tab_dispense(surface_state: Dictionary, elapsed: float, animation_active: bool, active_id: String) -> void:
	if not audio_enabled or _running_headless():
		return
	if active_id.is_empty():
		_animation_id = ""
		_played_markers.clear()
		return
	_ensure_players()
	if active_id != _animation_id:
		_animation_id = active_id
		_played_markers.clear()
	if not animation_active:
		return
	var events := _dictionary_array(surface_state.get("pull_tab_dispense_events", []))
	for event_value in events:
		var event: Dictionary = event_value
		var marker := "pull_tab_thud_%s" % str(event.get("ticket_id", event.get("sequence_index", events.find(event_value))))
		var thud_time := float(maxi(0, int(event.get("start_msec", 0)) + int(event.get("drop_start_msec", 240)))) / 1000.0
		_trigger(marker, elapsed >= thud_time, "pull_tab_thump", -3.5, 0.96 + float(int(event.get("deal_index", 0))) * 0.035)


func sync_blackjack_state(surface_state: Dictionary, deal_elapsed: float, deal_animation_active: bool, deal_active_id: String, payout_elapsed: float, payout_animation_active: bool, payout_active_id: String) -> void:
	if not audio_enabled or _running_headless():
		return
	_ensure_players()
	if deal_active_id.is_empty() or not deal_animation_active:
		_blackjack_deal_id = ""
	else:
		if deal_active_id != _blackjack_deal_id:
			_blackjack_deal_id = deal_active_id
			_clear_markers_with_prefix("blackjack_deal_")
		var events := _dictionary_array(surface_state.get("deal_animation_events", []))
		for i in range(events.size()):
			var event: Dictionary = events[i]
			var delay := float(maxi(0, int(event.get("delay_msec", 0)))) / 1000.0
			var target := str(event.get("target", ""))
			var pitch := 0.94 + float(i % 5) * 0.035
			if target == "dealer":
				pitch -= 0.04
			elif target == "patron":
				pitch += 0.04
			_trigger("blackjack_deal_%s_%d" % [deal_active_id, i], deal_elapsed >= delay, "blackjack_card", -4.2, pitch)
	if payout_active_id.is_empty() or not payout_animation_active:
		_blackjack_payout_id = ""
		return
	if payout_active_id != _blackjack_payout_id:
		_blackjack_payout_id = payout_active_id
		_clear_markers_with_prefix("blackjack_payout_")
	var result: Dictionary = surface_state.get("last_result", {}) if typeof(surface_state.get("last_result", {})) == TYPE_DICTIONARY else {}
	var delta := int(result.get("bankroll_delta", 0))
	var caught := bool(result.get("caught", false)) or int(result.get("suspicion_delta", 0)) >= 40
	var event_id := "blackjack_felt"
	if caught or delta < 0:
		event_id = "blackjack_bust"
	elif delta > 0:
		event_id = "blackjack_payout"
	_trigger("blackjack_payout_%s" % payout_active_id, payout_elapsed >= 0.08, event_id, -3.2 if delta > 0 else -5.2, 1.0)


func sync_roulette_state(surface_state: Dictionary, spin_elapsed: float, spin_animation_active: bool, spin_active_id: String, payout_elapsed: float, payout_animation_active: bool, payout_active_id: String) -> void:
	if not audio_enabled or _running_headless():
		return
	_ensure_players()
	if spin_active_id.is_empty() or not spin_animation_active:
		_stop_reel_loop()
		_stop_one_shot_loops()
		_roulette_spin_id = ""
	else:
		if spin_active_id != _roulette_spin_id:
			_roulette_spin_id = spin_active_id
			_clear_markers_with_prefix("roulette_spin_")
			_start_reel_loop("roulette_ball_loop", -18.5, 1.0)
		if spin_elapsed >= 3.42:
			_stop_reel_loop()
		_trigger("roulette_spin_start_%s" % spin_active_id, spin_elapsed >= 0.02, "roulette_rotor_launch", -2.4, 0.96)
		for i in range(ROULETTE_RIM_TIMES.size()):
			_trigger(
				"roulette_spin_rim_%s_%d" % [spin_active_id, i],
				spin_elapsed >= float(ROULETTE_RIM_TIMES[i]),
				"roulette_ball_rim_tick",
				-8.8 + float(i) * 0.25,
				1.18 - float(i) * 0.035
			)
		_trigger("roulette_spin_ball_drop_%s" % spin_active_id, spin_elapsed >= 3.36, "roulette_ball_drop", -5.4, 0.98)
		for i in range(ROULETTE_SCATTER_TIMES.size()):
			_trigger(
				"roulette_spin_ball_scatter_%s_%d" % [spin_active_id, i],
				spin_elapsed >= float(ROULETTE_SCATTER_TIMES[i]),
				"roulette_ball_scatter",
				-4.8 + float(i) * 0.35,
				1.02 - float(i) * 0.045
			)
		_trigger("roulette_spin_ball_bounce_%s" % spin_active_id, spin_elapsed >= 4.72, "roulette_ball_bounce", -3.4, 0.94)
		_trigger("roulette_spin_ball_pocket_%s" % spin_active_id, spin_elapsed >= 5.14, "roulette_ball_pocket", -2.8, 0.98)
	if payout_active_id.is_empty() or not payout_animation_active:
		_roulette_payout_id = ""
		return
	if payout_active_id != _roulette_payout_id:
		_roulette_payout_id = payout_active_id
		_clear_markers_with_prefix("roulette_payout_")
	var last_result: Dictionary = _dict(surface_state.get("last_result", {}))
	var delta := int(last_result.get("bankroll_delta", 0))
	var payout_event := "roulette_chip_sweep"
	if delta > 0:
		payout_event = "roulette_payout"
	_trigger("roulette_payout_collect_%s" % payout_active_id, payout_elapsed >= 0.08, "roulette_chip_sweep", -5.0 if delta > 0 else -4.3, 0.90)
	if delta > 0:
		_trigger("roulette_payout_pay_%s" % payout_active_id, payout_elapsed >= 0.22, payout_event, -3.0, 0.96)
		_trigger("roulette_payout_stack_%s" % payout_active_id, payout_elapsed >= 0.58, "roulette_chip_stack", -4.2, 1.06)


func sync_baccarat_state(surface_state: Dictionary, deal_elapsed: float, deal_animation_active: bool, deal_active_id: String, payout_elapsed: float, payout_animation_active: bool, payout_active_id: String) -> void:
	if not audio_enabled or _running_headless():
		return
	_ensure_players()
	if deal_active_id.is_empty() or not deal_animation_active:
		_baccarat_deal_id = ""
	else:
		if deal_active_id != _baccarat_deal_id:
			_baccarat_deal_id = deal_active_id
			_clear_markers_with_prefix("baccarat_deal_")
		var events := _dictionary_array(surface_state.get("deal_animation_events", []))
		for i in range(events.size()):
			var event: Dictionary = events[i]
			if str(event.get("type", "card")) != "card":
				continue
			var delay := float(maxi(0, int(event.get("delay_msec", 0)))) / 1000.0
			var zone := str(event.get("zone", ""))
			var pitch := 0.92 + float(i % 4) * 0.04
			if zone == "banker":
				pitch -= 0.035
			_trigger("baccarat_deal_%s_%d" % [deal_active_id, i], deal_elapsed >= delay, "blackjack_card", -4.0, pitch)
		_trigger("baccarat_marker_%s" % deal_active_id, deal_elapsed >= 3.55, "blackjack_felt", -4.8, 0.92)
	if payout_active_id.is_empty() or not payout_animation_active:
		_baccarat_payout_id = ""
		return
	if payout_active_id != _baccarat_payout_id:
		_baccarat_payout_id = payout_active_id
		_clear_markers_with_prefix("baccarat_payout_")
	var last_result: Dictionary = _dict(surface_state.get("last_result", {}))
	var delta := int(last_result.get("bankroll_delta", 0))
	var event_id := "blackjack_chip"
	if delta > 0:
		event_id = "blackjack_payout"
	elif delta < 0:
		event_id = "blackjack_felt"
	_trigger("baccarat_payout_%s" % payout_active_id, payout_elapsed >= 0.08, event_id, -3.0 if delta > 0 else -5.0, 1.0)


func stop_all() -> void:
	_stop_reel_loop()
	_animation_id = ""
	_feature_scene_audio_id = ""
	_feature_music_id = ""
	_blackjack_deal_id = ""
	_blackjack_payout_id = ""
	_roulette_spin_id = ""
	_roulette_payout_id = ""
	_baccarat_deal_id = ""
	_baccarat_payout_id = ""
	_played_markers.clear()
	for player in _players:
		if player is AudioStreamPlayer:
			(player as AudioStreamPlayer).stop()


func preview_event_stream(event_id: String) -> AudioStreamWAV:
	return _event_stream(event_id)


func debug_slot_cue_markers(slot_state: Dictionary) -> Array:
	var timing := _dict(slot_state.get("_surface_audio_timing", {}))
	var scene := _dict(slot_state.get("slot_feature_scene", {}))
	var active_id := _active_slot_audio_id(slot_state, scene, timing)
	var result: Array = []
	for cue in _slot_audio_cues(slot_state):
		result.append(_cue_marker(active_id, cue))
	for cue in _dictionary_array(scene.get("audio_cues", [])):
		result.append(_cue_marker(active_id, cue))
	return result


func debug_normalized_event_id(event_id: String) -> String:
	return _normalized_event_id(event_id)


func debug_music_director_cue_ids() -> Array:
	var result: Array = []
	for cue_value in MUSIC_DIRECTOR_CUES.keys():
		result.append(str(cue_value))
	result.sort()
	return result


func debug_slot_final_cue_armed(slot_state: Dictionary, elapsed: float, animation_active: bool) -> bool:
	var timing := _dict(slot_state.get("_surface_audio_timing", {}))
	var feature_scene := _dict(slot_state.get("slot_feature_scene", {}))
	if _active_slot_audio_id(slot_state, feature_scene, timing).is_empty():
		return false
	if bool(feature_scene.get("active", false)):
		return false
	var cue_stream := _slot_audio_cues(slot_state)
	if not cue_stream.is_empty() or not animation_active:
		return false
	var reel_stop_times := _slot_reel_stop_times(slot_state)
	var last_stop_time := float(reel_stop_times[reel_stop_times.size() - 1]) if not reel_stop_times.is_empty() else 0.0
	var final_time := last_stop_time + 0.35
	var bonus_steps := _dictionary_array(slot_state.get("slot_bonus_steps", []))
	if not bonus_steps.is_empty():
		var bonus_start_time := float(slot_state.get("slot_bonus_start_time", last_stop_time + SLOT_POST_REEL_BONUS_DELAY))
		final_time = bonus_start_time + float(bonus_steps.size()) * SLOT_BONUS_STEP_TIME + 0.22
	return elapsed >= final_time


func debug_soak_snapshot() -> Dictionary:
	return {
		"player_count": _players.size(),
		"has_loop_player": _loop_player != null,
		"stream_cache_size": _stream_cache.size(),
		"normalized_event_cache_size": _normalized_event_cache.size(),
		"played_marker_count": _played_markers.size(),
		"prewarm_queue_size": _prewarm_queue.size(),
		"prewarm_active": not _prewarm_active_event_id.is_empty(),
		"prewarm_active_frame_cursor": _prewarm_active_frame_cursor,
		"prewarm_active_frame_count": _prewarm_active_frame_count,
	}


func _active_slot_audio_id(slot_state: Dictionary, feature_scene: Dictionary, timing: Dictionary) -> String:
	if bool(slot_state.get("slot_nudge_chain_active", false)):
		var chain_id := str(timing.get("nudge_chain_active_id", ""))
		if chain_id.strip_edges().is_empty():
			chain_id = str(slot_state.get("slot_nudge_chain_event_id", ""))
		if not chain_id.strip_edges().is_empty():
			return chain_id
	var incoming_id := str(slot_state.get("slot_animation_id", timing.get("spin_active_id", "")))
	if incoming_id.strip_edges().is_empty():
		incoming_id = str(timing.get("spin_active_id", ""))
	if incoming_id.strip_edges().is_empty() and bool(feature_scene.get("active", false)):
		incoming_id = str(timing.get("feature_active_id", feature_scene.get("scene_id", feature_scene.get("mode", ""))))
		if incoming_id.strip_edges().is_empty():
			incoming_id = "feature:%s" % str(feature_scene.get("scene_id", feature_scene.get("mode", "")))
	return incoming_id


func _sync_slot_audio_cues(active_id: String, cues: Array, elapsed: float, profile: Dictionary) -> void:
	for cue in cues:
		var phase := str(cue.get("phase", cue.get("id", "")))
		if phase in ["spin_start", "spin_loop", "reel_stop"]:
			continue
		var default_pitch := float(profile.get("bonus_pitch", profile.get("final_pitch", 1.0)))
		var default_volume := -2.5
		if phase == "final_loss":
			default_volume = -6.0
		elif phase == "jackpot":
			default_volume = -1.0
		_trigger_cue(active_id, cue, elapsed >= _cue_time(cue, 0.0), profile, default_volume, default_pitch)


func _trigger_cue(active_id: String, cue: Dictionary, condition: bool, _profile: Dictionary, volume_db: float, pitch: float) -> void:
	_trigger(_cue_marker(active_id, cue), condition, _cue_id(cue), float(cue.get("volume_db", volume_db)), float(cue.get("pitch", pitch)))


func _slot_audio_cues(slot_state: Dictionary) -> Array:
	var result: Array = []
	var raw: Variant = slot_state.get("slot_audio_cues", [])
	if typeof(raw) != TYPE_ARRAY:
		return result
	for entry in raw:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry)
		elif typeof(entry) == TYPE_STRING:
			var cue_id := str(entry)
			result.append({"id": cue_id, "cue_id": cue_id, "phase": cue_id, "marker": cue_id, "scene_id": "string_cue", "stage_id": cue_id})
	return result


func _cue_by_phase(cues: Array, phase: String) -> Dictionary:
	for cue in cues:
		if typeof(cue) == TYPE_DICTIONARY and str((cue as Dictionary).get("phase", "")) == phase:
			return cue as Dictionary
	return {}


func _cues_by_phase(cues: Array, phase: String) -> Array:
	var result: Array = []
	for cue in cues:
		if typeof(cue) == TYPE_DICTIONARY and str((cue as Dictionary).get("phase", "")) == phase:
			result.append(cue)
	return result


func _cue_id(cue: Dictionary, fallback: String = "") -> String:
	return str(cue.get("cue_id", cue.get("id", fallback)))


func _cue_time(cue: Dictionary, fallback: float) -> float:
	return float(cue.get("time_sec", cue.get("cue_time", fallback)))


func _cue_marker(active_id: String, cue: Dictionary) -> String:
	var cue_id := _cue_id(cue)
	var scene_id := str(cue.get("scene_id", "base"))
	var stage_id := str(cue.get("stage_id", cue.get("phase", "")))
	var marker := str(cue.get("marker", cue_id))
	return "%s|%s|%s|%s" % [active_id, scene_id, stage_id, marker]


func _slot_reel_stop_times(slot_state: Dictionary) -> Array:
	var raw: Variant = slot_state.get("slot_reel_stop_times", [])
	var result: Array = []
	if typeof(raw) == TYPE_ARRAY:
		for value in raw:
			result.append(float(value))
	var reel_count := maxi(1, int(slot_state.get("slot_reel_count", 3)))
	while result.size() < reel_count:
		if result.is_empty():
			result.append(float(SLOT_CLASSIC_REEL_STOP_TIMES[0]))
		else:
			result.append(float(result[result.size() - 1]) + 0.42)
	if result.size() > reel_count:
		result = result.slice(0, reel_count)
	return result


func _slot_audio_profile(slot_state: Dictionary) -> Dictionary:
	var format_id := str(slot_state.get("slot_format_id", "classic_3_reel"))
	var type_id := str(slot_state.get("slot_type_id", "pinball"))
	var math_id := str(slot_state.get("slot_math_variant_id", "standard"))
	var bonus_id := str(slot_state.get("slot_bonus_variant_id", "plain"))
	var cabinet_id := str(slot_state.get("slot_cabinet_variant_id", ""))
	var pitch_bias := 0.0
	match math_id:
		"steady":
			pitch_bias -= 0.04
		"volatile":
			pitch_bias += 0.07
	match bonus_id:
		"jackpot_chase":
			pitch_bias += 0.04
		"skill_window":
			pitch_bias += 0.02
		"retrigger":
			pitch_bias -= 0.02
	match cabinet_id:
		"cyan_gold", "toxic_teal":
			pitch_bias += 0.025
		"hot_orange":
			pitch_bias -= 0.025
		"blacklight":
			pitch_bias += 0.045
	var profile := {
		"button_event": "button_pinball",
		"nudge_button_event": "nudge_pinball",
		"lever_event": "lever",
		"nudge_event": "nudge_pinball",
		"loop_event": "reel_loop_pinball",
		"stop_event": "reel_stop_pinball",
		"bonus_start_event": "bonus_start_pinball",
		"step_event": "bumper",
		"jackpot_step_event": "jackpot_hit",
		"payout_event": "payout",
		"bonus_total_event": "bonus_total",
		"jackpot_event": "jackpot",
		"lose_event": "lose",
		"button_pitch": 1.0 + pitch_bias,
		"nudge_button_pitch": 0.86 + pitch_bias,
		"start_pitch": 1.0 + pitch_bias,
		"loop_pitch": 1.0 + pitch_bias * 0.50,
		"stop_pitch": 1.08 + pitch_bias,
		"stop_pitch_step": -0.045,
		"step_pitch": 0.92 + pitch_bias,
		"step_pitch_delta": 0.08,
		"bonus_pitch": 1.0 + pitch_bias,
		"final_pitch": 1.0 + pitch_bias,
		"loop_volume_db": -13.0,
		"stop_volume_db": -3.0,
		"start_volume_db": 0.0,
	}
	if type_id == "buffalo":
		profile.merge({
			"button_event": "button_buffalo",
			"nudge_button_event": "nudge_buffalo",
			"lever_event": "lever_buffalo",
			"nudge_event": "nudge_buffalo",
			"loop_event": "reel_loop_buffalo",
			"stop_event": "reel_stop_buffalo",
			"bonus_start_event": "bonus_start_buffalo",
			"step_event": "bonus_step_buffalo",
			"jackpot_step_event": "jackpot_hit_buffalo",
			"bonus_total_event": "bonus_total_buffalo",
			"jackpot_event": "jackpot_buffalo",
			"button_pitch": 0.92 + pitch_bias,
			"nudge_button_pitch": 0.82 + pitch_bias,
			"loop_pitch": 0.88 + pitch_bias * 0.35,
			"stop_pitch": 0.92 + pitch_bias,
			"stop_pitch_step": 0.025,
			"step_pitch": 0.86 + pitch_bias,
			"step_pitch_delta": 0.055,
			"loop_volume_db": -12.0,
			"stop_volume_db": -2.4,
		}, true)
	if format_id == "video_feature":
		profile.merge({
			"button_event": "button_digital",
			"nudge_button_event": "nudge_digital",
			"lever_event": "lever_digital",
			"nudge_event": "nudge_digital",
			"loop_event": "reel_loop_digital",
			"stop_event": "reel_stop_digital",
			"bonus_start_event": "bonus_start_digital",
			"step_event": "bonus_step_digital" if type_id != "buffalo" else "bonus_step_buffalo",
			"jackpot_step_event": "jackpot_hit_digital" if type_id != "buffalo" else "jackpot_hit_buffalo",
			"payout_event": "payout_digital",
			"bonus_total_event": "bonus_total_digital" if type_id != "buffalo" else "bonus_total_buffalo",
			"jackpot_event": "jackpot_digital" if type_id != "buffalo" else "jackpot_buffalo",
			"button_pitch": 1.14 + pitch_bias,
			"nudge_button_pitch": 0.98 + pitch_bias,
			"loop_pitch": 1.08 + pitch_bias * 0.55,
			"stop_pitch": 1.18 + pitch_bias,
			"stop_pitch_step": -0.025,
			"step_pitch": 1.04 + pitch_bias,
			"step_pitch_delta": 0.10,
			"loop_volume_db": -14.0,
			"stop_volume_db": -3.6,
		}, true)
	elif format_id == "line_5x3":
		profile["loop_pitch"] = float(profile.get("loop_pitch", 1.0)) * 0.97
		profile["stop_pitch_step"] = float(profile.get("stop_pitch_step", -0.04)) - 0.010
		profile["bonus_pitch"] = float(profile.get("bonus_pitch", 1.0)) + 0.03
	return profile


func _trigger(marker: String, condition: bool, event_id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not condition or bool(_played_markers.get(marker, false)):
		return
	_played_markers[marker] = true
	if _emit_music_director_cue(event_id, {"marker": marker, "volume_db": volume_db, "pitch": pitch}):
		return
	_play(event_id, volume_db, pitch)


func _trigger_final(slot_state: Dictionary, profile: Dictionary = {}) -> void:
	if bool(_played_markers.get("final", false)):
		return
	_played_markers["final"] = true
	var payout := int(slot_state.get("slot_payout", slot_state.get("last_payout", 0)))
	var stake_cost := maxi(1, int(slot_state.get("slot_stake_cost", slot_state.get("selected_stake", 1))))
	var bonus_total := int(slot_state.get("slot_bonus_total", 0))
	if bool(slot_state.get("slot_jackpot_won", false)):
		_play(str(profile.get("jackpot_event", "jackpot")), -1.0, float(profile.get("final_pitch", 1.0)))
	elif bonus_total > 0 or payout >= stake_cost * 4:
		_play(str(profile.get("bonus_total_event", "bonus_total")), -2.0, float(profile.get("final_pitch", 1.0)))
	elif payout > 0:
		_play(str(profile.get("payout_event", "payout")), -3.0, float(profile.get("final_pitch", 1.0)))
	else:
		_play(str(profile.get("lose_event", "lose")), -6.0, float(profile.get("final_pitch", 1.0)))


func _sync_feature_music(feature_scene: Dictionary, profile: Dictionary) -> void:
	var music: Dictionary = _dict(feature_scene.get("feature_music", {}))
	if music.is_empty() or not bool(music.get("loop", false)):
		if not _feature_music_id.is_empty():
			_feature_music_id = ""
		return
	var event_id := str(music.get("cue_id", "bonus_music_buffalo"))
	var music_id := "%s|%s" % [str(feature_scene.get("scene_id", feature_scene.get("mode", ""))), event_id]
	if music_id == _feature_music_id:
		return
	_feature_music_id = music_id
	_emit_music_director_cue(event_id, {
		"feature_scene": feature_scene.duplicate(true),
		"feature_music": music.duplicate(true),
		"profile": profile.duplicate(true),
		"volume_db": float(music.get("volume_db", profile.get("loop_volume_db", -13.0))),
		"pitch": float(music.get("pitch", profile.get("bonus_pitch", 1.0))),
	})


func _sync_feature_scene_cues(slot_state: Dictionary, profile: Dictionary, fallback_elapsed: float) -> void:
	var scene := _dict(slot_state.get("slot_feature_scene", {}))
	var scene_id := str(scene.get("scene_id", scene.get("mode", "")))
	if scene_id.is_empty():
		return
	if scene_id != _feature_scene_audio_id:
		_feature_scene_audio_id = scene_id
		_clear_markers_with_prefix("feature_scene_")
	var timing := _dict(slot_state.get("_surface_audio_timing", {}))
	var elapsed := float(timing.get("feature_elapsed", fallback_elapsed))
	var stages: Array = scene.get("stages", []) if typeof(scene.get("stages", [])) == TYPE_ARRAY else []
	var start_times: Array = []
	var cursor := 0.0
	for stage_value in stages:
		start_times.append(cursor)
		if typeof(stage_value) == TYPE_DICTIONARY:
			cursor += float(maxi(1, int((stage_value as Dictionary).get("duration_msec", 1)))) / 1000.0
	var cues := _dictionary_array(scene.get("audio_cues", []))
	for cue in cues:
		var stage_index := int(cue.get("stage_index", 0))
		var cue_time := 0.0
		if cue.has("time_sec") or cue.has("cue_time"):
			cue_time = _cue_time(cue, 0.0)
		elif stage_index >= 0 and stage_index < start_times.size():
			cue_time = float(start_times[stage_index])
		var cue_id := str(cue.get("cue_id", cue.get("id", "")))
		var marker := _cue_marker(_animation_id, cue)
		var pitch := float(profile.get("bonus_pitch", 1.0)) + float(maxi(0, stage_index % 4)) * 0.035
		var volume_db := float(cue.get("volume_db", -2.5))
		_trigger(marker, elapsed >= cue_time, cue_id, volume_db, pitch)


func _start_reel_loop(event_id: String = "reel_loop", volume_db: float = -13.0, pitch: float = 1.0) -> void:
	var stream := _event_stream(event_id)
	_surface_loop_event_id = _normalized_event_id(event_id)
	if WebAudioBridgeScript.available():
		WebAudioBridgeScript.play_stream(stream, "sfx:%s" % _normalized_event_id(event_id), volume_db, pitch, WEB_SURFACE_LOOP_ID, true)
		_web_surface_loop_active = true
		return
	if _loop_player == null:
		return
	_loop_player.stream = stream
	_loop_player.volume_db = volume_db
	_loop_player.pitch_scale = pitch
	_loop_player.play()


func _stop_reel_loop() -> void:
	if _surface_loop_fade_tween != null and _surface_loop_fade_tween.is_valid():
		_surface_loop_fade_tween.kill()
	_surface_loop_fade_tween = null
	if WebAudioBridgeScript.available() and _web_surface_loop_active:
		WebAudioBridgeScript.stop_loop(WEB_SURFACE_LOOP_ID)
		_web_surface_loop_active = false
	if _loop_player != null and _loop_player.playing:
		_loop_player.stop()
	_surface_loop_event_id = ""


func _stop_one_shot_loops() -> void:
	for player in _players:
		if not (player is AudioStreamPlayer):
			continue
		var audio_player := player as AudioStreamPlayer
		if not audio_player.playing or not (audio_player.stream is AudioStreamWAV):
			continue
		var wav := audio_player.stream as AudioStreamWAV
		if wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			audio_player.stop()


func _play(event_id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	_remove_from_prewarm_queue(_normalized_event_id(event_id))
	var stream := _event_stream(event_id)
	if WebAudioBridgeScript.available():
		WebAudioBridgeScript.play_stream(stream, "sfx:%s" % _normalized_event_id(event_id), volume_db, pitch)
		return
	var player := _next_player()
	if player == null:
		return
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func _next_player() -> AudioStreamPlayer:
	_ensure_players()
	for player in _players:
		if player is AudioStreamPlayer and not (player as AudioStreamPlayer).playing:
			return player
	if _players.is_empty():
		return null
	return _players[0]


func _ensure_players() -> void:
	if _loop_player != null:
		return
	for _i in range(ONE_SHOT_PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)
	_loop_player = AudioStreamPlayer.new()
	_loop_player.bus = SFX_BUS
	add_child(_loop_player)


func _begin_incremental_prewarm() -> void:
	if _running_headless():
		return
	if _prewarm_started:
		return
	_prewarm_started = true
	_prewarm_queue.clear()
	if _prewarm_event_override.is_empty():
		if OS.has_feature("web"):
			for event_id in WEB_CRITICAL_PREWARM_EVENTS:
				_queue_prewarm_event(str(event_id))
		else:
			for event_id in BLACKJACK_PREWARM_EVENTS:
				_queue_prewarm_event(str(event_id))
			for event_id in ROULETTE_PREWARM_EVENTS:
				_queue_prewarm_event(str(event_id))
			for event_id in ENVIRONMENT_PREWARM_EVENTS:
				_queue_prewarm_event(str(event_id))
	else:
		for event_id in _prewarm_event_override:
			_queue_prewarm_event(str(event_id))
	if not _prewarm_queue.is_empty():
		set_process(true)


func _process_prewarm_chunk() -> void:
	if _prewarm_active_event_id.is_empty():
		while not _prewarm_queue.is_empty():
			var event_id := str(_prewarm_queue.pop_front())
			if _stream_cache.has(event_id):
				continue
			_begin_prewarm_event(event_id)
			break
	if _prewarm_active_event_id.is_empty():
		set_process(false)
		return
	var started_usec := Time.get_ticks_usec()
	var web_prewarm := OS.has_feature("web")
	var chunk_limit := mini(
		_prewarm_active_frame_cursor + WEB_PREWARM_SAMPLES_PER_FRAME,
		_prewarm_active_frame_count
	) if web_prewarm else _prewarm_active_frame_count
	while _prewarm_active_frame_cursor < chunk_limit:
		var frame := _prewarm_active_frame_cursor
		var t := float(frame) / float(_prewarm_active_sample_rate)
		_write_i16(
			_prewarm_active_data,
			frame * PCM_BYTES_PER_FRAME,
			_soft_limit(_event_sample(_prewarm_active_event_id, t, frame, _prewarm_active_seconds))
		)
		_prewarm_active_frame_cursor += 1
		if (
			not web_prewarm
			and _prewarm_active_frame_cursor % NATIVE_PREWARM_TIME_CHECK_INTERVAL == 0
			and Time.get_ticks_usec() - started_usec >= NATIVE_PREWARM_BUDGET_USEC
		):
			break
	if _prewarm_active_frame_cursor < _prewarm_active_frame_count:
		return
	_stream_cache[_prewarm_active_event_id] = _audio_stream_from_pcm(
		_prewarm_active_event_id,
		_prewarm_active_sample_rate,
		_prewarm_active_frame_count,
		_prewarm_active_data
	)
	_clear_prewarm_event()


func _begin_prewarm_event(event_id: String) -> void:
	_prewarm_active_event_id = _normalized_event_id(event_id)
	_prewarm_active_seconds = _event_seconds(_prewarm_active_event_id)
	_prewarm_active_sample_rate = _event_sample_rate(_prewarm_active_event_id)
	_prewarm_active_frame_count = maxi(1, int(_prewarm_active_seconds * float(_prewarm_active_sample_rate)))
	_prewarm_active_frame_cursor = 0
	_prewarm_active_data = PackedByteArray()
	_prewarm_active_data.resize(_prewarm_active_frame_count * PCM_BYTES_PER_FRAME)


func _clear_prewarm_event() -> void:
	_prewarm_active_event_id = ""
	_prewarm_active_seconds = 0.0
	_prewarm_active_sample_rate = 0
	_prewarm_active_frame_count = 0
	_prewarm_active_frame_cursor = 0
	_prewarm_active_data = PackedByteArray()


func _queue_prewarm_event(event_id: String) -> void:
	var normalized := _normalized_event_id(event_id)
	if _stream_cache.has(normalized) or _prewarm_queue.has(normalized):
		return
	_prewarm_queue.append(normalized)


func _remove_from_prewarm_queue(event_id: String) -> void:
	if _prewarm_queue.is_empty():
		return
	var index := _prewarm_queue.find(_normalized_event_id(event_id))
	if index >= 0:
		_prewarm_queue.remove_at(index)


func _event_stream(event_id: String) -> AudioStreamWAV:
	var normalized := _normalized_event_id(event_id)
	if _stream_cache.has(normalized):
		return _stream_cache[normalized]
	if normalized == _prewarm_active_event_id:
		_clear_prewarm_event()
	var seconds := _event_seconds(normalized)
	var sample_rate := _event_sample_rate(normalized)
	var frames := maxi(1, int(seconds * float(sample_rate)))
	var data := PackedByteArray()
	data.resize(frames * PCM_BYTES_PER_FRAME)
	for i in range(frames):
		var t := float(i) / float(sample_rate)
		_write_i16(data, i * PCM_BYTES_PER_FRAME, _soft_limit(_event_sample(normalized, t, i, seconds)))
	var stream := _audio_stream_from_pcm(normalized, sample_rate, frames, data)
	_stream_cache[normalized] = stream
	return stream


func _audio_stream_from_pcm(event_id: String, sample_rate: int, frames: int, data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if event_id.begins_with("reel_loop") or event_id in ["roulette_ball_loop", "scratch_paper_foley_loop"] else AudioStreamWAV.LOOP_DISABLED
	stream.loop_begin = 0
	stream.loop_end = frames
	return stream


func _event_sample_rate(event_id: String) -> int:
	if event_id == "phone_call":
		return TELEPHONE_SAMPLE_RATE
	if OS.has_feature("web"):
		return WEB_SAMPLE_RATE
	return SAMPLE_RATE


func _normalized_event_id(event_id: String) -> String:
	var cached: Variant = _normalized_event_cache.get(event_id)
	if typeof(cached) == TYPE_STRING:
		return str(cached)
	var normalized := _normalized_event_id_uncached(event_id)
	if _normalized_event_cache.size() > 512:
		_normalized_event_cache.clear()
	_normalized_event_cache[event_id] = normalized
	return normalized


func _normalized_event_id_uncached(event_id: String) -> String:
	var family_event := event_id.strip_edges()
	if family_event.begins_with("classic_pinball_mechanical_"):
		return _normalized_family_event(family_event, {
			"spin_start": "lever",
			"spin_loop": "reel_loop_pinball",
			"reel_stop": "reel_stop_pinball",
			"near_miss": "reel_stop_pinball",
			"returned": "payout",
			"true_win": "bonus_total",
			"feature_transition": "bonus_start_pinball",
			"jackpot": "jackpot",
			"loss": "lose",
		})
	if family_event.begins_with("pinball_5x3_arcade_"):
		return _normalized_family_event(family_event, {
			"spin_start": "lever_digital",
			"spin_loop": "reel_loop_digital",
			"reel_stop": "reel_stop_digital",
			"near_miss": "reel_stop_digital",
			"returned": "payout_digital",
			"true_win": "bonus_total_digital",
			"feature_transition": "bonus_start_digital",
			"jackpot": "jackpot_digital",
			"loss": "lose",
		})
	if family_event.begins_with("video_pinball_table_"):
		return _normalized_family_event(family_event, {
			"spin_start": "lever_digital",
			"spin_loop": "reel_loop_digital",
			"reel_stop": "reel_stop_digital",
			"near_miss": "reel_stop_digital",
			"returned": "payout_digital",
			"true_win": "bonus_total_digital",
			"feature_transition": "bonus_start_digital",
			"jackpot": "jackpot_digital",
			"loss": "lose",
		})
	if family_event.begins_with("classic_buffalo_heritage_"):
		return _normalized_family_event(family_event, {
			"spin_start": "lever_buffalo",
			"spin_loop": "reel_loop_buffalo",
			"reel_stop": "reel_stop_buffalo",
			"near_miss": "reel_stop_buffalo",
			"returned": "payout",
			"true_win": "bonus_total_buffalo",
			"feature_transition": "bonus_start_buffalo",
			"jackpot": "jackpot_buffalo",
			"loss": "lose",
		})
	if family_event.begins_with("buffalo_5x4_stampede_gold_"):
		return _normalized_family_event(family_event, {
			"spin_start": "lever_buffalo",
			"spin_loop": "reel_loop_buffalo",
			"reel_stop": "reel_stop_buffalo",
			"near_miss": "reel_stop_buffalo",
			"returned": "payout_digital",
			"true_win": "bonus_total_buffalo",
			"feature_transition": "bonus_start_buffalo",
			"jackpot": "jackpot_buffalo",
			"loss": "lose",
		})
	if family_event.begins_with("video_buffalo_hold_spin_wheel_"):
		return _normalized_family_event(family_event, {
			"spin_start": "lever_digital",
			"spin_loop": "reel_loop_digital",
			"reel_stop": "reel_stop_digital",
			"near_miss": "reel_stop_digital",
			"returned": "payout_digital",
			"true_win": "bonus_total_buffalo",
			"feature_transition": "bonus_start_buffalo",
			"jackpot": "jackpot_buffalo",
			"loss": "lose",
		})
	if family_event == "drink_consumed" or family_event == "phone_call":
		return family_event
	if family_event == "scratch_paper_foley_loop" or family_event == "scratch_box_pop":
		return family_event
	match family_event:
		"button", "button_pinball", "button_buffalo", "button_digital", "lever", "lever_buffalo", "lever_digital", "nudge", "nudge_pinball", "nudge_buffalo", "nudge_digital", "reel_loop", "reel_loop_pinball", "reel_loop_buffalo", "reel_loop_digital", "reel_stop", "reel_stop_pinball", "reel_stop_buffalo", "reel_stop_digital", "gold_coin_tease", "double_gold_coin_tease", "bonus_start", "bonus_start_pinball", "bonus_start_buffalo", "bonus_start_digital", "bumper", "pinball_money_ding", "bonus_step_buffalo", "bonus_step_digital", "jackpot_hit", "jackpot_hit_buffalo", "jackpot_hit_digital", "payout", "payout_digital", "bonus_total", "bonus_total_buffalo", "bonus_total_digital", "jackpot", "jackpot_buffalo", "jackpot_digital", "lose", "pull_tab_click", "pull_tab_thump", "paper_peek", "paper_peel", "blackjack_card", "blackjack_chip", "blackjack_felt", "blackjack_payout", "blackjack_bust", "blackjack_peek", "blackjack_count", "blackjack_distraction", "video_poker_button", "video_poker_deal", "video_poker_hold", "video_poker_draw", "video_poker_cheat", "video_poker_cheat_beat", "video_poker_double", "video_poker_win", "roulette_chip_select", "roulette_chip_place", "roulette_chip_lift", "roulette_chip_stack", "roulette_chip_sweep", "roulette_rotor_launch", "roulette_ball_loop", "roulette_ball_rim_tick", "roulette_ball_roll", "roulette_ball_drop", "roulette_ball_scatter", "roulette_ball_bounce", "roulette_ball_pocket", "roulette_dolly_tap", "roulette_payout":
			return event_id
		"slot_reel_spin_loop":
			return "reel_loop"
		"slot_bonus_transition":
			return "bonus_start"
		"slot_tease_slow_roll":
			return "reel_stop_digital"
		"slot_tease_resolve", "slot_returned_soft", "slot_true_win_countup":
			return "payout"
		"slot_jackpot_escalation":
			return "jackpot"
		"pinball_plunger", "pinball_plunger_charge", "pinball_feature_intro", "pinball_bonus_trigger":
			return "bonus_start_pinball"
		"pinball_flipper", "pinball_cup_hit", "pinball_shot_counter", "pinball_lane_lit", "pinball_history_tick", "pinball_peg_tick", "pinball_bumper_pop", "pinball_target_hit", "pinball_gate_chime":
			return "bumper"
		"pinball_award", "pinball_good_hit", "pinball_money":
			return "pinball_money_ding"
		"pinball_launcher_fire", "pinball_multiball":
			return "bonus_start_pinball"
		"pinball_tilt", "pinball_drain":
			return "nudge_pinball"
		"pinball_jackpot_lane", "pinball_super_jackpot":
			return "jackpot_hit"
		"buffalo_start_feature", "buffalo_bonus_trigger", "buffalo_free_games_intro", "buffalo_hold_spin_intro", "buffalo_meter_feature", "buffalo_gateway_wheel_spin":
			return "bonus_start_buffalo"
		"buffalo_cash_lock", "buffalo_stampede_step", "buffalo_feature_advance", "buffalo_quick_advance":
			return "bonus_step_buffalo"
		"buffalo_retrigger", "buffalo_spin_reset", "buffalo_gateway_choice_reveal":
			return "bonus_total_buffalo"
		"buffalo_gateway_jackpot_boost", "buffalo_grand_escalation":
			return "jackpot_buffalo"
		_:
			return "button"


func _normalized_family_event(event_id: String, mapping: Dictionary) -> String:
	var phases := ["feature_transition", "spin_start", "spin_loop", "reel_stop", "near_miss", "true_win", "returned", "jackpot", "loss"]
	for phase in phases:
		if event_id.ends_with("_%s" % phase):
			return str(mapping.get(phase, "button"))
	return "button"


func _event_seconds(event_id: String) -> float:
	match event_id:
		"button", "button_pinball", "button_buffalo", "button_digital":
			return 0.09
		"drink_consumed":
			return 0.56
		"phone_call":
			return 1.08
		"scratch_paper_foley_loop":
			return 0.28
		"scratch_box_pop":
			return 0.16
		"lever", "lever_buffalo", "lever_digital":
			return 0.34
		"nudge", "nudge_pinball", "nudge_buffalo", "nudge_digital":
			return 0.30
		"reel_loop", "reel_loop_pinball", "reel_loop_buffalo", "reel_loop_digital":
			return 0.52
		"reel_stop", "reel_stop_pinball", "reel_stop_buffalo", "reel_stop_digital":
			return 0.20
		"gold_coin_tease":
			return 0.52
		"double_gold_coin_tease":
			return 0.68
		"bonus_start", "bonus_start_pinball", "bonus_start_buffalo", "bonus_start_digital":
			return 0.44
		"bumper", "bonus_step_buffalo", "bonus_step_digital":
			return 0.22
		"pinball_money_ding":
			return 0.36
		"jackpot_hit", "jackpot_hit_buffalo", "jackpot_hit_digital":
			return 0.46
		"payout", "payout_digital":
			return 0.72
		"bonus_total", "bonus_total_buffalo", "bonus_total_digital":
			return 0.92
		"jackpot", "jackpot_buffalo", "jackpot_digital":
			return 1.35
		"lose":
			return 0.22
		"pull_tab_click":
			return 0.16
		"pull_tab_thump":
			return 0.24
		"paper_peek":
			return 0.18
		"paper_peel":
			return 0.30
		"blackjack_card":
			return 0.18
		"blackjack_chip":
			return 0.32
		"blackjack_felt":
			return 0.18
		"blackjack_payout":
			return 0.72
		"blackjack_bust":
			return 0.36
		"blackjack_peek":
			return 0.24
		"blackjack_count":
			return 0.16
		"blackjack_distraction":
			return 0.44
		"video_poker_button":
			return 0.10
		"video_poker_deal":
			return 0.30
		"video_poker_hold":
			return 0.14
		"video_poker_draw":
			return 0.48
		"video_poker_cheat":
			return 0.42
		"video_poker_cheat_beat":
			return 0.22
		"video_poker_double":
			return 0.34
		"video_poker_win":
			return 0.78
		"roulette_chip_select":
			return 0.14
		"roulette_chip_place":
			return 0.28
		"roulette_chip_lift":
			return 0.20
		"roulette_chip_stack":
			return 0.42
		"roulette_chip_sweep":
			return 0.48
		"roulette_rotor_launch":
			return 0.54
		"roulette_ball_loop":
			return 0.72
		"roulette_ball_rim_tick":
			return 0.16
		"roulette_ball_roll":
			return 0.62
		"roulette_ball_drop":
			return 0.38
		"roulette_ball_scatter":
			return 0.46
		"roulette_ball_bounce":
			return 0.56
		"roulette_ball_pocket":
			return 0.42
		"roulette_dolly_tap":
			return 0.22
		"roulette_payout":
			return 0.78
		_:
			return 0.12


func _event_sample(event_id: String, t: float, frame: int, seconds: float) -> float:
	match event_id:
		"button", "button_pinball":
			return _sample_button(t, frame, seconds)
		"button_buffalo":
			return _sample_buffalo_button(t, frame, seconds)
		"button_digital":
			return _sample_digital_button(t, frame, seconds)
		"drink_consumed":
			return _sample_drink_consumed(t, frame, seconds)
		"phone_call":
			return _sample_phone_call(t, frame, seconds)
		"scratch_paper_foley_loop":
			return _sample_scratch_paper_foley_loop(t, frame, seconds)
		"scratch_box_pop":
			return _sample_scratch_box_pop(t, frame, seconds)
		"lever":
			return _sample_lever(t, frame, seconds)
		"lever_buffalo":
			return _sample_lever(t, frame, seconds) * 0.55 + _sample_buffalo_reel_stop(t, frame, seconds) * 0.55
		"lever_digital":
			return _sample_digital_button(t, frame, seconds) * 0.70 + _sample_bonus_start_digital(t, frame, seconds) * 0.35
		"nudge", "nudge_pinball":
			return _sample_nudge(t, frame, seconds)
		"nudge_buffalo":
			return _sample_nudge(t, frame, seconds) * 0.45 + _sample_buffalo_reel_stop(t, frame, seconds) * 0.80
		"nudge_digital":
			return _sample_digital_glitch(t, frame, seconds)
		"reel_loop", "reel_loop_pinball":
			return _sample_reel_loop(t, frame, seconds)
		"reel_loop_buffalo":
			return _sample_buffalo_reel_loop(t, frame, seconds)
		"reel_loop_digital":
			return _sample_digital_reel_loop(t, frame, seconds)
		"reel_stop", "reel_stop_pinball":
			return _sample_reel_stop(t, frame, seconds)
		"reel_stop_buffalo":
			return _sample_buffalo_reel_stop(t, frame, seconds)
		"reel_stop_digital":
			return _sample_digital_reel_stop(t, frame, seconds)
		"gold_coin_tease":
			return _sample_gold_coin_tease(t, frame, seconds)
		"double_gold_coin_tease":
			return _sample_double_gold_coin_tease(t, frame, seconds)
		"bonus_start", "bonus_start_pinball":
			return _sample_bonus_start(t, frame, seconds)
		"bonus_start_buffalo":
			return _sample_bonus_start_buffalo(t, frame, seconds)
		"bonus_start_digital":
			return _sample_bonus_start_digital(t, frame, seconds)
		"bumper":
			return _sample_bumper(t, frame, seconds)
		"pinball_money_ding":
			return _sample_pinball_money_ding(t, frame, seconds)
		"bonus_step_buffalo":
			return _sample_bonus_step_buffalo(t, frame, seconds)
		"bonus_step_digital":
			return _sample_bonus_step_digital(t, frame, seconds)
		"jackpot_hit":
			return _sample_jackpot_hit(t, frame, seconds)
		"jackpot_hit_buffalo":
			return _sample_bonus_start_buffalo(t, frame, seconds) * 0.55 + _sample_coin_cascade(t, frame, seconds, 5) * 0.50
		"jackpot_hit_digital":
			return _sample_jackpot_hit(t, frame, seconds) * 0.45 + _sample_bonus_step_digital(t, frame, seconds) * 0.85
		"payout":
			return _sample_coin_cascade(t, frame, seconds, 7)
		"payout_digital":
			return _sample_coin_cascade(t, frame, seconds, 5) * 0.65 + _sample_bonus_step_digital(t, frame, seconds) * 0.45
		"bonus_total":
			return _sample_bonus_total(t, frame, seconds)
		"bonus_total_buffalo":
			return _sample_bonus_start_buffalo(t, frame, seconds) * 0.42 + _sample_coin_cascade(t, frame, seconds, 10) * 0.68
		"bonus_total_digital":
			return _sample_bonus_total(t, frame, seconds) * 0.45 + _sample_bonus_start_digital(t, frame, seconds) * 0.85
		"jackpot":
			return _sample_jackpot(t, frame, seconds)
		"jackpot_buffalo":
			return _sample_bonus_start_buffalo(t, frame, seconds) * 0.54 + _sample_jackpot(t, frame, seconds) * 0.62
		"jackpot_digital":
			return _sample_jackpot(t, frame, seconds) * 0.42 + _sample_bonus_start_digital(t, frame, seconds) * 0.95
		"lose":
			return _sample_lose(t, frame, seconds)
		"pull_tab_click":
			return _sample_pull_tab_click(t, frame, seconds)
		"pull_tab_thump":
			return _sample_pull_tab_thump(t, frame, seconds)
		"paper_peek":
			return _sample_paper_peek(t, frame, seconds)
		"paper_peel":
			return _sample_paper_peel(t, frame, seconds)
		"blackjack_card":
			return _sample_blackjack_card(t, frame, seconds)
		"blackjack_chip":
			return _sample_blackjack_chip(t, frame, seconds)
		"blackjack_felt":
			return _sample_blackjack_felt(t, frame, seconds)
		"blackjack_payout":
			return _sample_blackjack_payout(t, frame, seconds)
		"blackjack_bust":
			return _sample_blackjack_bust(t, frame, seconds)
		"blackjack_peek":
			return _sample_blackjack_peek(t, frame, seconds)
		"blackjack_count":
			return _sample_blackjack_count(t, frame, seconds)
		"blackjack_distraction":
			return _sample_blackjack_distraction(t, frame, seconds)
		"video_poker_button":
			return _sample_button(t, frame, seconds) * 0.72 + _sample_rounded_cabinet_click(t, frame, seconds) * 0.35
		"video_poker_deal":
			return _sample_blackjack_card(t, frame, seconds) * 0.70 + _sample_blackjack_card(t - 0.090, frame + 31, maxf(0.01, seconds - 0.090)) * 0.50 + _sample_rounded_cabinet_click(t, frame, seconds) * 0.35
		"video_poker_hold":
			return _sample_rounded_cabinet_click(t, frame, seconds)
		"video_poker_draw":
			return _sample_blackjack_card(t, frame, seconds) * 0.60 + _sample_blackjack_card(t - 0.105, frame + 37, maxf(0.01, seconds - 0.105)) * 0.52 + _sample_blackjack_card(t - 0.220, frame + 71, maxf(0.01, seconds - 0.220)) * 0.44 + _sample_rounded_cabinet_click(t, frame, seconds) * 0.22
		"video_poker_cheat":
			return _sample_bonus_start_digital(t, frame, seconds) * 0.38 + _sample_blackjack_peek(t, frame, seconds) * 0.65
		"video_poker_cheat_beat":
			return _sample_bonus_step_digital(t, frame, seconds) * 0.45 + _sample_rounded_cabinet_click(t, frame, seconds) * 0.55
		"video_poker_double":
			return _sample_gold_coin_tease(t, frame, seconds) * 0.42 + _sample_rounded_cabinet_click(t, frame, seconds) * 0.45
		"video_poker_win":
			return _sample_coin_cascade(t, frame, seconds, 7) * 0.60 + _sample_bonus_total(t, frame, seconds) * 0.35
		"roulette_chip_select":
			return _sample_roulette_chip_select(t, frame, seconds)
		"roulette_chip_place":
			return _sample_roulette_chip_place(t, frame, seconds)
		"roulette_chip_lift":
			return _sample_roulette_chip_lift(t, frame, seconds)
		"roulette_chip_stack":
			return _sample_roulette_chip_stack(t, frame, seconds)
		"roulette_chip_sweep":
			return _sample_roulette_chip_sweep(t, frame, seconds)
		"roulette_rotor_launch":
			return _sample_roulette_rotor_launch(t, frame, seconds)
		"roulette_ball_loop":
			return _sample_roulette_ball_loop(t, frame, seconds)
		"roulette_ball_rim_tick":
			return _sample_roulette_ball_rim_tick(t, frame, seconds)
		"roulette_ball_roll":
			return _sample_roulette_ball_roll(t, frame, seconds)
		"roulette_ball_drop":
			return _sample_roulette_ball_drop(t, frame, seconds)
		"roulette_ball_scatter":
			return _sample_roulette_ball_scatter(t, frame, seconds)
		"roulette_ball_bounce":
			return _sample_roulette_ball_bounce(t, frame, seconds)
		"roulette_ball_pocket":
			return _sample_roulette_ball_pocket(t, frame, seconds)
		"roulette_dolly_tap":
			return _sample_roulette_dolly_tap(t, frame, seconds)
		"roulette_payout":
			return _sample_roulette_payout(t, frame, seconds)
		_:
			return 0.0


func _sample_button(t: float, frame: int, seconds: float) -> float:
	var press := _cabinet_button_click(t, frame, 3, 0.92)
	var return_tick := _cabinet_button_click(t - 0.052, frame + 17, 19, 0.38)
	return (press + return_tick) * _decay_env(t, seconds, 0.001, 0.070)


func _sample_drink_consumed(t: float, frame: int, seconds: float) -> float:
	var glass_lift := _glass_tick(t, frame, 1709, 0.60)
	var sip_window := _pulse_window(t, 0.055, 0.270)
	var liquid := (_soft_noise(frame, 1711, 3) - _soft_noise(frame, 1721, 17)) * 0.075 * _pulse_train(t, 18.0, 0.70) * sip_window
	var pour := _warm_tone(t, lerpf(260.0, 122.0, clampf(t / 0.30, 0.0, 1.0)), 0.28) * 0.030 * sip_window
	var bubbles := _rounded_bell(t, 520.0 + 70.0 * sin(TAU * 4.7 * t), 0.09, 0.008) * 0.040 * _pulse_train(t, 13.0, 0.22) * sip_window
	var swallow_t := t - 0.270
	var swallow := 0.0
	if swallow_t >= 0.0:
		var swallow_progress := clampf(swallow_t / 0.24, 0.0, 1.0)
		var swallow_frequency := lerpf(175.0, 82.0, swallow_progress)
		var swallow_env := _decay_env(swallow_t, 0.25, 0.018, 0.13)
		swallow = (_warm_tone(swallow_t, swallow_frequency, 0.40) * 0.15 + _soft_noise(frame, 1913, 19) * 0.020) * swallow_env
	var settle := _glass_tick(t - 0.455, frame + 29, 1741, 0.45)
	return glass_lift + liquid + pour + bubbles + swallow + settle


func _sample_phone_call(t: float, frame: int, seconds: float) -> float:
	var dial_click := 0.0
	if t <= 0.040:
		var click_env := 1.0 - clampf(t / 0.040, 0.0, 1.0)
		dial_click = (sin(TAU * 880.0 * t) * 0.060 + _noise(frame, 6029) * 0.035) * click_env
	var ring_one := _telephone_ring_segment(t, frame, 0.025, 0.315)
	var ring_two := _telephone_ring_segment(t, frame + 2300, 0.425, 0.315)
	var line_hiss := _noise(frame, 6043) * 0.004 * _pulse_window(t, 0.04, seconds - 0.04)
	var cradle_tail_t := t - 0.96
	var cradle := 0.0
	if cradle_tail_t >= 0.0 and cradle_tail_t <= 0.12:
		var cradle_env := 1.0 - clampf(cradle_tail_t / 0.12, 0.0, 1.0)
		cradle = (sin(TAU * 135.0 * cradle_tail_t) * 0.060 + _noise(frame, 6053) * 0.012) * cradle_env
	return dial_click + ring_one + ring_two + line_hiss + cradle


func _sample_scratch_paper_foley_loop(t: float, frame: int, seconds: float) -> float:
	var coin_grit := _scratch_coin_grit(t, frame, seconds, 2719, 0.85)
	var latex_drag := _warm_tone(t, 72.0 + 12.0 * sin(TAU * 2.4 * t), 0.18) * 0.020
	return coin_grit + latex_drag


func _sample_scratch_box_pop(t: float, frame: int, seconds: float) -> float:
	var foil_snap := _pulse_window(t, 0.0, 0.038) * (_soft_noise(frame, 4547, 3) * 0.100 + _body_thump(t, seconds, 240.0, 0.16) * 0.16)
	var coin_lift := _inharmonic_coin_ping(t - 0.018, frame, 4561, 680.0, 0.26)
	var dust := _scratch_coin_grit(t, frame + 53, seconds, 4567, 0.34) * _pulse_window(t, 0.012, 0.100)
	return foil_snap + coin_lift + dust


func _sample_lever(t: float, frame: int, seconds: float) -> float:
	var handle_pull := _pulse_window(t, 0.0, 0.145) * _warm_tone(t, lerpf(96.0, 45.0, clampf(t / 0.145, 0.0, 1.0)), 0.30) * 0.28
	var ratchet := 0.0
	for i in range(5):
		var local := t - (0.032 + float(i) * 0.034)
		ratchet += _clay_chip_clack(local, frame + i * 41, 11 + i * 13, 0.34)
	var spring_local := t - 0.170
	var spring := 0.0
	if spring_local >= 0.0:
		spring = sin(TAU * lerpf(18.0, 8.0, clampf(spring_local / 0.14, 0.0, 1.0)) * spring_local) * _rounded_bell(spring_local, 360.0, 0.16, 0.003) * 0.090
	var return_clunk := _pulse_window(t, 0.255, 0.075) * (_body_thump(t - 0.255, 0.10, 92.0, 0.45) + _soft_noise(frame, 31, 5) * 0.080)
	return (handle_pull + ratchet + spring + return_clunk) * _decay_env(t, seconds, 0.004, 0.260)


func _sample_nudge(t: float, frame: int, seconds: float) -> float:
	var thump := _body_thump(t, seconds, 72.0, 0.38) * 0.92
	var rattle := _soft_noise(frame, 29, 5) * 0.12 * _pulse_train(t, 20.0, 0.45) * _decay_env(t, seconds, 0.012, 0.260)
	var buzz := _warm_tone(t, 104.0, 0.25) * 0.060 * _decay_env(t, seconds, 0.012, 0.240)
	return thump + rattle + buzz


func _sample_reel_loop(t: float, frame: int, seconds: float) -> float:
	var local := fposmod(t, seconds)
	var motor := _warm_tone(t, 58.0, 0.34) * 0.044 + _warm_tone(t, 116.0, 0.20) * 0.020
	var tick_phase := fposmod(local * 18.0, 1.0)
	var detent := _pulse_window(tick_phase, 0.0, 0.115) * (_clay_chip_clack(tick_phase * 0.035, frame, 41, 0.28) + _soft_noise(frame, 43, 5) * 0.018)
	var belt := (_soft_noise(frame, 53, 17) - _soft_noise(frame, 59, 29)) * 0.016
	return motor + detent + belt


func _sample_reel_stop(t: float, frame: int, seconds: float) -> float:
	var brake := _clay_chip_clack(t, frame, 61, 0.92)
	var detent := _clay_chip_clack(t - 0.055, frame + 23, 67, 0.56)
	var lock := _pulse_window(t, 0.070, 0.110) * _warm_tone(t - 0.070, lerpf(190.0, 82.0, clampf((t - 0.070) / 0.11, 0.0, 1.0)), 0.28) * 0.16
	return (brake + detent + lock) * _decay_env(t, seconds, 0.001, 0.170)


func _sample_buffalo_button(t: float, frame: int, seconds: float) -> float:
	var click := _sample_button(t, frame, seconds) * 0.60
	var wood := _body_thump(t, seconds, 120.0, 0.22) * 0.55
	return click + wood + _soft_noise(frame, 211, 7) * 0.025 * _pulse_window(t, 0.0, 0.050)


func _sample_digital_button(t: float, frame: int, seconds: float) -> float:
	var plastic := _cabinet_button_click(t, frame, 223, 0.55)
	var chirp := _rounded_bell(t, 760.0, 0.050, 0.004) * 0.050 * _pulse_window(t, 0.0, 0.045)
	return plastic + chirp + _soft_noise(frame, 229, 5) * 0.010


func _sample_buffalo_reel_loop(t: float, frame: int, seconds: float) -> float:
	var rumble := _warm_tone(t, 38.0, 0.40) * 0.052 + _warm_tone(t, 76.0, 0.25) * 0.025
	var hoof_phase := fposmod(t * 7.0, 1.0)
	var hoof := _pulse_window(hoof_phase, 0.0, 0.22) * (_body_thump(t, seconds, 108.0, 0.18) * 0.34 + _soft_noise(frame, 233, 5) * 0.040)
	var belt := _sample_reel_loop(t, frame, seconds) * 0.28
	return rumble + hoof + belt


func _sample_digital_reel_loop(t: float, frame: int, seconds: float) -> float:
	var carrier := _warm_tone(t, 138.0, 0.30) * 0.034 + _warm_tone(t, 276.0, 0.20) * 0.020
	var shimmer := _rounded_bell(t, 620.0 + 52.0 * sin(TAU * 1.4 * t), 0.20, 0.010) * 0.022
	var data_tick := _pulse_train(t, 18.0, 0.48) * (_rounded_bell(t, 680.0, 0.08, 0.004) * 0.036 + _soft_noise(frame, 241, 7) * 0.020)
	return carrier + shimmer + data_tick


func _sample_buffalo_reel_stop(t: float, frame: int, seconds: float) -> float:
	var thud := _body_thump(t, seconds, 88.0, 0.44) * _decay_env(t, seconds, 0.002, 0.150)
	var latch := _pulse_window(t, 0.055, 0.13) * (_soft_noise(frame, 251, 5) * 0.11 + _warm_tone(t, 180.0, 0.28) * 0.15)
	var dust := _soft_noise(frame, 257, 11) * 0.040 * _decay_env(t, seconds, 0.010, 0.180)
	return thud + latch + dust


func _sample_gold_coin_tease(t: float, frame: int, seconds: float) -> float:
	var coin := _inharmonic_coin_ping(t, frame, 269, 610.0, 1.0)
	var table := _body_thump(t, seconds, 110.0, 0.18) * _decay_env(t, seconds, 0.002, 0.180)
	return coin + table


func _sample_double_gold_coin_tease(t: float, frame: int, seconds: float) -> float:
	var first := _sample_gold_coin_tease(t, frame, seconds) * 0.82
	var local := t - 0.13
	var second := 0.0
	if local >= 0.0:
		second = _sample_gold_coin_tease(local, frame + 17, maxf(0.01, seconds - 0.13)) * 1.05
	var rise := _rounded_bell(t, lerpf(240.0, 520.0, clampf(t / seconds, 0.0, 1.0)), 0.52, 0.020) * 0.085
	return first + second + rise


func _sample_digital_reel_stop(t: float, frame: int, seconds: float) -> float:
	var zip := _rounded_bell(t, lerpf(760.0, 360.0, clampf(t / 0.09, 0.0, 1.0)), 0.10, 0.004) * 0.13
	var lock := _pulse_window(t, 0.060, 0.060) * _rounded_bell(t, 540.0, 0.08, 0.004) * 0.10
	var static_tick := _soft_noise(frame, 263, 5) * 0.045 * _pulse_window(t, 0.018, 0.070)
	return zip + lock + static_tick


func _sample_bonus_start_buffalo(t: float, frame: int, seconds: float) -> float:
	var horn := _warm_tone(t, lerpf(150.0, 92.0, clampf(t / seconds, 0.0, 1.0)), 0.44) * 0.20 * _decay_env(t, seconds, 0.020, 0.360)
	var stampede := _pulse_train(t, 10.0, 0.62) * (_warm_tone(t, 78.0, 0.34) * 0.14 + _soft_noise(frame, 271, 7) * 0.065) * _decay_env(t, seconds, 0.012, 0.380)
	var token := _rounded_bell(t, 520.0, 0.14, 0.006) * 0.060 * _pulse_window(t, 0.22, 0.12)
	return horn + stampede + token


func _sample_bonus_start_digital(t: float, frame: int, seconds: float) -> float:
	var sweep := _rounded_bell(t, lerpf(260.0, 760.0, clampf(t / seconds, 0.0, 1.0)), 0.34, 0.014) * 0.15
	var glitch := _sample_digital_glitch(t, frame, seconds) * 0.32
	var gate := _pulse_train(t, 14.0, 0.48) * _rounded_bell(t, 640.0, 0.10, 0.006) * 0.030
	return sweep + glitch + gate


func _sample_bonus_step_buffalo(t: float, frame: int, seconds: float) -> float:
	var hoof := _sample_buffalo_reel_stop(t, frame, seconds) * 0.62
	var token := _rounded_bell(t, 460.0, 0.16, 0.006) * 0.090 * _decay_env(t, seconds, 0.004, 0.150)
	return hoof + token


func _sample_bonus_step_digital(t: float, frame: int, seconds: float) -> float:
	var arpeggio := 0.0
	var notes := [523.25, 659.25, 783.99]
	for i in range(notes.size()):
		var local := t - float(i) * 0.045
		if local >= 0.0:
			arpeggio += _rounded_bell(local, float(notes[i]), 0.20, 0.006) * 0.080 * _decay_env(local, 0.18, 0.004, 0.130)
	return arpeggio + _soft_noise(frame, 281, 7) * 0.012 * _decay_env(t, seconds, 0.006, 0.180)


func _sample_digital_glitch(t: float, frame: int, seconds: float) -> float:
	var gate := _pulse_train(t, 22.0, 0.56)
	var bit := _rounded_bell(t, 360.0 + float((frame * 37) % 220), 0.08, 0.004) * 0.060
	var snap := _pulse_window(t, 0.0, 0.050) * (_soft_noise(frame, 293, 3) * 0.12 + _rounded_bell(t, 720.0, 0.07, 0.004) * 0.060)
	return (bit * gate + snap) * _decay_env(t, seconds, 0.002, 0.210)


func _sample_bonus_start(t: float, frame: int, seconds: float) -> float:
	var plunger := _pulse_window(t, 0.0, 0.25) * _rounded_bell(t, lerpf(180.0, 520.0, clampf(t / 0.25, 0.0, 1.0)), 0.30, 0.012) * 0.15
	var spring := sin(TAU * 11.0 * t) * _rounded_bell(t, 560.0, 0.32, 0.014) * 0.070
	var launch := _pulse_window(t, 0.24, 0.12) * (_soft_noise(frame, 71, 5) * 0.11 + _rounded_bell(t, 640.0, 0.12, 0.006) * 0.080)
	return plunger + spring + launch


func _sample_bumper(t: float, frame: int, seconds: float) -> float:
	var solenoid := _body_thump(t, seconds, 155.0, 0.34) * _pulse_window(t, 0.0, 0.115)
	var rubber_pop := _rounded_bell(t, lerpf(760.0, 420.0, clampf(t / 0.13, 0.0, 1.0)), 0.15, 0.003) * 0.16
	var contact := _soft_noise(frame, 83, 3) * 0.055 * _pulse_window(t, 0.0, 0.040)
	var rebound := _rounded_bell(t - 0.066, 540.0, 0.11, 0.003) * 0.070
	return solenoid + rubber_pop + contact + rebound


func _sample_pinball_money_ding(t: float, frame: int, seconds: float) -> float:
	var notes := [523.25, 659.25, 783.99]
	var sample := 0.0
	for i in range(notes.size()):
		var local := t - float(i) * 0.052
		if local < 0.0:
			continue
		sample += _win_bell(local, frame + i * 13, 89 + i * 19, float(notes[i]), 0.74)
	var body := _warm_tone(t, 261.63, 0.38) * 0.045 * _decay_env(t, seconds, 0.012, 0.260)
	var strike := _soft_noise(frame, 89, 5) * 0.022 * _pulse_window(t, 0.0, 0.040)
	return (sample + body + strike) * _decay_env(t, seconds, 0.002, 0.300)


func _sample_jackpot_hit(t: float, frame: int, seconds: float) -> float:
	var bell := 0.0
	for i in range(3):
		var local := t - float(i) * 0.060
		if local >= 0.0:
			bell += _win_bell(local, frame + i * 17, 91 + i * 23, 659.25 + float(i) * 110.0, 0.70)
	var coins := _sample_coin_cascade(t, frame, seconds, 4) * 0.42
	return bell + coins


func _sample_coin_cascade(t: float, frame: int, seconds: float, count: int) -> float:
	var sample := 0.0
	for i in range(count):
		var scatter := float((i * 37) % 23) * 0.0015
		var start := 0.024 + float(i) * seconds / float(count + 1) + scatter
		var local := t - start
		if local < 0.0:
			continue
		var freq := 470.0 + float((i * 113) % 520)
		sample += _inharmonic_coin_ping(local, frame + i * 31, 97 + i * 17, freq, 0.72)
		var tabletop := _soft_noise(frame + i * 19, 101, 5) * 0.012 * _pulse_window(local, 0.030, 0.065)
		sample += tabletop
	return sample * _decay_env(t, seconds, 0.006, seconds * 0.82)


func _sample_bonus_total(t: float, frame: int, seconds: float) -> float:
	var arp_notes := [523.25, 659.25, 783.99, 1046.50]
	var sample := _sample_coin_cascade(t, frame, seconds, 9) * 0.74
	for i in range(arp_notes.size()):
		var start := float(i) * 0.085
		var local := t - start
		if local >= 0.0:
			sample += _rounded_bell(local, float(arp_notes[i]), 0.36, 0.008) * 0.080 * _decay_env(local, 0.36, 0.008, 0.280)
	return sample


func _sample_jackpot(t: float, frame: int, seconds: float) -> float:
	var notes := [392.0, 523.25, 659.25, 783.99, 1046.5, 1318.5]
	var sample := _sample_coin_cascade(t, frame, seconds, 16) * 0.58
	for i in range(notes.size()):
		var start := float(i) * 0.105
		var local := t - start
		if local < 0.0:
			continue
		sample += _win_bell(local, frame + i * 29, 121 + i * 11, float(notes[i]), 0.78)
	sample += _warm_tone(t, 196.0, 0.36) * 0.050 * _decay_env(t, seconds, 0.020, seconds * 0.90)
	return sample


func _sample_lose(t: float, frame: int, seconds: float) -> float:
	var clunk := _body_thump(t, seconds, 98.0, 0.24) * 0.62
	var cabinet := _soft_noise(frame, 113, 7) * 0.055 * _pulse_window(t, 0.0, 0.070)
	return clunk + cabinet


func _sample_pull_tab_thump(t: float, frame: int, seconds: float) -> float:
	var thump := _body_thump(t, seconds, 82.0, 0.32) * _decay_env(t, seconds, 0.004, 0.190)
	var cardboard := _paper_friction(t, frame, 127, seconds, 0.70) * _pulse_window(t, 0.010, 0.105)
	var latch := _clay_chip_clack(t - 0.026, frame, 131, 0.34)
	var drop := _pulse_window(t, 0.140, 0.090) * (_soft_noise(frame, 137, 7) * 0.060 + _body_thump(t - 0.14, 0.12, 150.0, 0.22) * 0.30)
	return thump + cardboard + latch + drop


func _sample_pull_tab_click(t: float, frame: int, seconds: float) -> float:
	var tab_snap := _pulse_window(t, 0.0, 0.050) * (_soft_noise(frame, 125, 3) * 0.095 + _rounded_bell(t, 620.0, 0.070, 0.003) * 0.060)
	var paper_tear := _paper_friction(t - 0.030, frame + 17, 129, 0.12, 0.62)
	var spring := _warm_tone(t, 108.0, 0.22) * 0.040 * _decay_env(t, seconds, 0.006, 0.120)
	return (tab_snap + paper_tear + spring) * _decay_env(t, seconds, 0.002, 0.130)


func _sample_paper_peek(t: float, frame: int, seconds: float) -> float:
	var crinkle := _paper_friction(t, frame, 137, seconds, 0.82)
	var bend := _warm_tone(t, 190.0, 0.26) * 0.034 * _decay_env(t, seconds, 0.008, 0.130)
	return crinkle + bend


func _sample_paper_peel(t: float, frame: int, seconds: float) -> float:
	var tear := _paper_friction(t, frame, 149, seconds, 1.10) * _pulse_train(t, 46.0, 0.65)
	var zipper := _warm_tone(t, lerpf(320.0, 210.0, clampf(t / seconds, 0.0, 1.0)), 0.20) * 0.038 * _decay_env(t, seconds, 0.006, 0.260)
	var snap := _pulse_window(t, 0.225, 0.055) * (_soft_noise(frame, 151, 5) * 0.070 + _rounded_bell(t, 520.0, 0.08, 0.004) * 0.040)
	return tear + zipper + snap


func _sample_blackjack_card(t: float, frame: int, seconds: float) -> float:
	var slide := _paper_friction(t, frame, 163, seconds, 0.72) * _pulse_train(t, 54.0, 0.58)
	var snap := _pulse_window(t, 0.070, 0.060) * (_rounded_bell(t, 430.0, 0.08, 0.003) * 0.060 + _soft_noise(frame, 167, 5) * 0.090)
	var felt := _warm_tone(t, lerpf(132.0, 70.0, clampf(t / seconds, 0.0, 1.0)), 0.18) * 0.038 * _decay_env(t, seconds, 0.004, 0.110)
	return slide + snap + felt


func _sample_blackjack_chip(t: float, frame: int, seconds: float) -> float:
	var sample := 0.0
	for i in range(4):
		var start := 0.012 + float(i) * 0.050
		var local := t - start
		sample += _clay_chip_clack(local, frame + i * 23, 173 + i * 17, 0.62)
	var stack := _body_thump(t, seconds, 112.0, 0.18) * 0.22
	return (sample + stack) * _decay_env(t, seconds, 0.002, 0.260)


func _sample_blackjack_felt(t: float, frame: int, seconds: float) -> float:
	var tap := _body_thump(t, seconds, 118.0, 0.20) * 0.58
	var cloth := _soft_noise(frame, 181, 7) * 0.040 * _pulse_window(t, 0.0, 0.100)
	return tap + cloth


func _sample_blackjack_payout(t: float, frame: int, seconds: float) -> float:
	var chips := 0.0
	for i in range(8):
		chips += _clay_chip_clack(t - (0.030 + float(i) * 0.066), frame + i * 17, 199 + i * 11, 0.50)
	var table := _warm_tone(t, 96.0, 0.28) * 0.060 * _decay_env(t, seconds, 0.012, 0.540)
	var accent := 0.0
	for i in range(3):
		var start := 0.11 + float(i) * 0.12
		var local := t - start
		if local >= 0.0:
			accent += _clay_chip_clack(local, frame + i * 21, 211 + i * 13, 0.34)
	return chips + table + accent


func _sample_blackjack_bust(t: float, frame: int, seconds: float) -> float:
	var thud := _body_thump(t, seconds, 102.0, 0.25) * 0.70
	var scrape := _soft_noise(frame, 191, 5) * 0.080 * _pulse_train(t, 34.0, 0.48) * _decay_env(t, seconds, 0.008, 0.260)
	var low := _warm_tone(t, 42.0, 0.18) * 0.090 * _decay_env(t, seconds, 0.012, 0.320)
	return thud + scrape + low


func _sample_blackjack_peek(t: float, frame: int, seconds: float) -> float:
	var card_lift := _sample_paper_peek(t, frame, seconds) * 0.72
	var sting := _rounded_bell(t, lerpf(720.0, 430.0, clampf(t / seconds, 0.0, 1.0)), 0.16, 0.008) * 0.045
	var tension := _warm_tone(t, 72.0, 0.24) * 0.040 * _decay_env(t, seconds, 0.020, 0.210)
	return card_lift + sting + tension


func _sample_blackjack_count(t: float, frame: int, seconds: float) -> float:
	var blip := _rounded_bell(t, lerpf(420.0, 610.0, clampf(t / seconds, 0.0, 1.0)), 0.13, 0.008) * 0.085
	var tick := _pulse_window(t, 0.055, 0.040) * (_rounded_bell(t, 680.0, 0.07, 0.004) * 0.060 + _soft_noise(frame, 197, 5) * 0.030)
	return blip + tick


func _sample_blackjack_distraction(t: float, frame: int, seconds: float) -> float:
	var glass := _glass_tick(t, frame, 211, 0.62) + _glass_tick(t - 0.095, frame + 23, 223, 0.38)
	var chatter := _soft_noise(frame, 211, 11) * 0.055 * _pulse_train(t, 20.0, 0.56) * _decay_env(t, seconds, 0.012, 0.360)
	var bump := _body_thump(t, seconds, 140.0, 0.18) * 0.38
	return glass + chatter + bump


func _sample_rounded_cabinet_click(t: float, frame: int, seconds: float) -> float:
	return _cabinet_button_click(t, frame, 503, 0.72) * _decay_env(t, seconds, 0.001, 0.090)


func _sample_roulette_chip_select(t: float, frame: int, seconds: float) -> float:
	var snap := _clay_chip_clack(t, frame, 337, 0.76)
	var ceramic := _clay_chip_clack(t - 0.038, frame + 19, 347, 0.34)
	var tray := _body_thump(t, seconds, 132.0, 0.12) * 0.18
	return (snap + ceramic + tray) * _decay_env(t, seconds, 0.001, 0.120)


func _sample_roulette_chip_place(t: float, frame: int, seconds: float) -> float:
	var sample := 0.0
	var starts := [0.0, 0.038, 0.082]
	for i in range(starts.size()):
		var local := t - float(starts[i])
		sample += _clay_chip_clack(local, frame + i * 19, 347 + i * 17, 0.55)
	var felt := _warm_tone(t, 88.0, 0.30) * 0.060 * _decay_env(t, seconds, 0.004, 0.210)
	return (sample + felt) * _decay_env(t, seconds, 0.001, 0.240)


func _sample_roulette_chip_lift(t: float, frame: int, seconds: float) -> float:
	var scrape := _soft_noise(frame, 359, 3) * 0.050 * _pulse_train(t, 42.0, 0.48) * _decay_env(t, seconds, 0.006, 0.140)
	var click := _clay_chip_clack(t - 0.070, frame, 367, 0.46)
	var felt := _warm_tone(t, 74.0, 0.26) * 0.038 * _decay_env(t, seconds, 0.006, 0.170)
	return scrape + click + felt


func _sample_roulette_chip_stack(t: float, frame: int, seconds: float) -> float:
	var sample := 0.0
	for i in range(7):
		var local := t - (0.012 + float(i) * 0.044)
		sample += _clay_chip_clack(local, frame + i * 29, 373 + i * 17, 0.48)
	var stack_body := _warm_tone(t, 112.0, 0.28) * 0.060 * _decay_env(t, seconds, 0.006, 0.320)
	return (sample + stack_body) * _decay_env(t, seconds, 0.001, 0.360)


func _sample_roulette_chip_sweep(t: float, frame: int, seconds: float) -> float:
	var scrape := _soft_noise(frame, 389, 3) * 0.090 * _pulse_train(t, 48.0, 0.62) * _decay_env(t, seconds, 0.008, 0.380)
	var sample := scrape + _warm_tone(t, 62.0, 0.22) * 0.060 * _decay_env(t, seconds, 0.010, 0.420)
	for i in range(6):
		var local := t - (0.030 + float(i) * 0.058)
		sample += _clay_chip_clack(local, frame + i * 31, 397 + i * 19, 0.38)
	return sample


func _sample_roulette_rotor_launch(t: float, frame: int, seconds: float) -> float:
	var hand_push := _body_thump(t, seconds, 76.0, 0.28) * 0.48
	var wood := _soft_noise(frame, 409, 7) * 0.036 * _pulse_train(t, 30.0, 0.52) * _decay_env(t, seconds, 0.012, 0.420)
	var spindle := _warm_tone(t, lerpf(108.0, 156.0, clampf(t / seconds, 0.0, 1.0)), 0.26) * 0.066 * _decay_env(t, seconds, 0.024, 0.500)
	var ball_throw := _pulse_window(t, 0.240, 0.110) * (_ivory_ball_tick(t - 0.240, frame, 419, 0.62) + _soft_noise(frame, 421, 5) * 0.025)
	return hand_push + wood + spindle + ball_throw


func _sample_roulette_ball_loop(t: float, frame: int, seconds: float) -> float:
	var local := fposmod(t, seconds)
	var tick_phase := fposmod(local * 30.0, 1.0)
	var tick := _pulse_window(tick_phase, 0.0, 0.115) * (_ivory_ball_tick(tick_phase * 0.028, frame, 431, 0.22) + _soft_noise(frame, 433, 5) * 0.010)
	var rim := _warm_tone(t, 92.0, 0.16) * 0.020 + _warm_tone(t, 184.0, 0.10) * 0.011
	var air := _soft_noise(frame, 439, 23) * 0.010
	var rotor := _warm_tone(t, 37.0, 0.16) * 0.016
	return tick + rim + air + rotor


func _sample_roulette_ball_rim_tick(t: float, frame: int, seconds: float) -> float:
	var ivory := _ivory_ball_tick(t, frame, 443, 0.72)
	var rail := _warm_tone(t, 230.0, 0.24) * 0.040 * _decay_env(t, seconds, 0.004, 0.120)
	var grain := _soft_noise(frame, 443, 5) * 0.030 * _pulse_window(t, 0.0, 0.055)
	return ivory + rail + grain


func _sample_roulette_ball_roll(t: float, frame: int, seconds: float) -> float:
	var tick_rate := lerpf(33.0, 13.0, clampf(t / seconds, 0.0, 1.0))
	var tick := _pulse_train(t, tick_rate, 0.28) * (_ivory_ball_tick(t, frame, 307, 0.40) + _soft_noise(frame, 309, 5) * 0.016)
	var rim := _warm_tone(t, 84.0, 0.20) * 0.030 + _warm_tone(t, 168.0, 0.13) * 0.016
	var hiss := _soft_noise(frame, 311, 17) * 0.014
	return (tick + rim + hiss) * _decay_env(t, seconds, 0.006, 0.240)


func _sample_roulette_ball_drop(t: float, frame: int, seconds: float) -> float:
	var whirr := _warm_tone(t, lerpf(220.0, 150.0, clampf(t / seconds, 0.0, 1.0)), 0.18) * 0.030 * _decay_env(t, seconds, 0.006, 0.280)
	var rail := _sample_roulette_ball_rim_tick(t, frame, seconds) * 0.68
	var diamonds := 0.0
	for i in range(4):
		var local := t - (0.105 + float(i) * 0.052)
		diamonds += _ivory_ball_tick(local, frame + i * 23, 449 + i * 17, 0.38)
	return whirr + rail + diamonds


func _sample_roulette_ball_scatter(t: float, frame: int, seconds: float) -> float:
	var sample := 0.0
	for i in range(5):
		var start := 0.018 + float(i) * 0.052
		var local := t - start
		if local < 0.0:
			continue
		var click := _ivory_ball_tick(local, frame + i * 19, 317 + i * 11, 0.66)
		var body := _warm_tone(local, 190.0 - float(i) * 14.0, 0.20) * 0.038
		sample += (click + body) * _decay_env(local, 0.13, 0.001, 0.105)
	return sample * _decay_env(t, seconds, 0.002, 0.360)


func _sample_roulette_ball_bounce(t: float, frame: int, seconds: float) -> float:
	var sample := 0.0
	var starts := [0.0, 0.090, 0.178, 0.282, 0.404]
	for i in range(starts.size()):
		var local := t - float(starts[i])
		if local < 0.0:
			continue
		var strength := pow(0.72, float(i))
		var ivory := _ivory_ball_tick(local, frame + i * 31, 331 + i * 13, 0.72)
		var pocket := _warm_tone(local, 180.0 - float(i) * 14.0, 0.26) * 0.105
		var scrape := _soft_noise(frame + i * 31, 331, 5) * 0.040
		sample += (ivory + pocket + scrape) * strength * _decay_env(local, 0.17 + float(i) * 0.025, 0.001, 0.145)
	return sample * _decay_env(t, seconds, 0.001, 0.500)


func _sample_roulette_ball_pocket(t: float, frame: int, seconds: float) -> float:
	var clack := _pulse_window(t, 0.0, 0.075) * (_ivory_ball_tick(t, frame, 461, 0.72) + _soft_noise(frame, 461, 5) * 0.035)
	var pocket := _body_thump(t, seconds, 190.0, 0.26) * 0.62
	var settle := _pulse_window(t, 0.155, 0.110) * (_ivory_ball_tick(t - 0.155, frame + 17, 467, 0.38) + _soft_noise(frame, 467, 7) * 0.020)
	return (clack + pocket + settle) * _decay_env(t, seconds, 0.001, 0.360)


func _sample_roulette_dolly_tap(t: float, frame: int, seconds: float) -> float:
	var wood := _body_thump(t, seconds, 165.0, 0.18) * 0.42
	var tap := _pulse_window(t, 0.035, 0.060) * (_clay_chip_clack(t - 0.035, frame, 479, 0.30) + _soft_noise(frame, 479, 5) * 0.018)
	var felt := _soft_noise(frame, 487, 11) * 0.024 * _pulse_window(t, 0.0, 0.090)
	return wood + tap + felt


func _sample_roulette_payout(t: float, frame: int, seconds: float) -> float:
	var chips := _sample_roulette_chip_stack(t, frame, seconds) * 0.84
	var tray := _sample_roulette_chip_sweep(t, frame, seconds) * 0.42
	var accent := 0.0
	for i in range(4):
		var local := t - (0.180 + float(i) * 0.095)
		accent += _clay_chip_clack(local, frame + i * 19, 491 + i * 13, 0.34)
	return chips + tray + accent


func _telephone_ring_segment(t: float, frame: int, start: float, duration: float) -> float:
	var local := t - start
	if local < 0.0 or local > duration:
		return 0.0
	var attack := clampf(local / 0.018, 0.0, 1.0)
	var release := clampf((duration - local) / 0.045, 0.0, 1.0)
	var envelope := minf(attack, release)
	var warble_phase := sin(TAU * 12.5 * local)
	var tremolo := 0.58 + 0.42 * absf(sin(TAU * 18.0 * local))
	var tone_a := sin(TAU * 440.0 * local + warble_phase * 0.18)
	var tone_b := sin(TAU * 480.0 * local - warble_phase * 0.12 + 0.15)
	var striker := _noise(frame, 6071) * 0.020 * (1.0 - clampf(local / 0.022, 0.0, 1.0))
	return (tone_a * 0.52 + tone_b * 0.48) * envelope * tremolo * 0.145 + striker


func _inharmonic_coin_ping(local: float, frame: int, seed: int, base_frequency: float, strength: float) -> float:
	if local < 0.0:
		return 0.0
	var strike := _soft_noise(frame, seed, 3) * 0.065 * _pulse_window(local, 0.0, 0.018)
	var env := _decay_env(local, 0.30, 0.002, 0.235)
	var p1 := sin(TAU * base_frequency * local)
	var p2 := sin(TAU * base_frequency * 2.62 * local + 0.17) * 0.46
	var p3 := sin(TAU * base_frequency * 3.83 * local + 0.31) * 0.24
	var p4 := sin(TAU * base_frequency * 5.07 * local + 0.43) * 0.12
	return ((p1 + p2 + p3 + p4) * 0.105 * env + strike) * strength


func _win_bell(local: float, frame: int, seed: int, base_frequency: float, strength: float) -> float:
	if local < 0.0:
		return 0.0
	var strike := _soft_noise(frame, seed, 3) * 0.030 * _pulse_window(local, 0.0, 0.022)
	var bell := _rounded_bell(local, base_frequency, 0.42, 0.006) * 0.092
	var shimmer := sin(TAU * base_frequency * 2.01 * local + 0.12) * 0.026 * _decay_env(local, 0.50, 0.006, 0.400)
	return (bell + shimmer + strike) * strength


func _clay_chip_clack(local: float, frame: int, seed: int, strength: float) -> float:
	if local < 0.0:
		return 0.0
	var edge := _soft_noise(frame, seed, 3) * 0.070 * _pulse_window(local, 0.0, 0.030)
	var body := _warm_tone(local, 176.0 + float(seed % 37), 0.16) * 0.085 * _decay_env(local, 0.13, 0.001, 0.095)
	var low := _body_thump(local, 0.14, 118.0 + float(seed % 23), 0.20)
	var faint_ring := sin(TAU * (330.0 + float(seed % 71)) * local) * 0.030 * _decay_env(local, 0.16, 0.002, 0.110)
	return (edge + body + low + faint_ring) * strength


func _cabinet_button_click(local: float, frame: int, seed: int, strength: float) -> float:
	if local < 0.0:
		return 0.0
	var cap_snap := _soft_noise(frame, seed, 3) * 0.065 * _pulse_window(local, 0.0, 0.026)
	var plunger := _body_thump(local, 0.11, 138.0 + float(seed % 19), 0.20)
	var plastic := _rounded_bell(local, 360.0 + float(seed % 90), 0.070, 0.003) * 0.035
	return (cap_snap + plunger + plastic) * _decay_env(local, 0.10, 0.001, 0.080) * strength


func _paper_friction(t: float, frame: int, seed: int, seconds: float, strength: float) -> float:
	if t < 0.0 or t > seconds:
		return 0.0
	var fibers := (_soft_noise(frame, seed, 3) - _soft_noise(frame, seed + 7, 13)) * 0.062
	var crinkle := _soft_noise(frame, seed + 17, 5) * 0.040 * _pulse_train(t, 38.0, 0.54)
	return (fibers + crinkle) * _decay_env(t, seconds, 0.006, seconds * 0.78) * strength


func _scratch_coin_grit(t: float, frame: int, seconds: float, seed: int, strength: float) -> float:
	if t < 0.0 or t > seconds:
		return 0.0
	var coarse := (_soft_noise(frame, seed, 3) - _soft_noise(frame, seed + 11, 23)) * 0.064
	var latex := _soft_noise(frame, seed + 23, 5) * 0.038 * _pulse_train(t, 54.0, 0.58)
	var foil_edge := _inharmonic_coin_ping(fposmod(t, 0.082), frame, seed + 41, 860.0, 0.16) * _pulse_train(t, 13.0, 0.20)
	return (coarse + latex + foil_edge) * strength


func _ivory_ball_tick(local: float, frame: int, seed: int, strength: float) -> float:
	if local < 0.0:
		return 0.0
	var tick := _rounded_bell(local, 760.0 + float(seed % 80), 0.060, 0.002) * 0.075
	var hard_edge := _soft_noise(frame, seed, 3) * 0.045 * _pulse_window(local, 0.0, 0.018)
	var wheel := _warm_tone(local, 210.0 + float(seed % 30), 0.14) * 0.026 * _decay_env(local, 0.09, 0.001, 0.070)
	return (tick + hard_edge + wheel) * strength


func _glass_tick(local: float, frame: int, seed: int, strength: float) -> float:
	if local < 0.0:
		return 0.0
	var glass := _rounded_bell(local, 720.0 + float(seed % 90), 0.18, 0.006) * 0.070
	var high := _rounded_bell(local, 1180.0 + float(seed % 170), 0.12, 0.004) * 0.035
	var contact := _soft_noise(frame, seed + 5, 3) * 0.024 * _pulse_window(local, 0.0, 0.020)
	return (glass + high + contact) * strength


func _clear_markers_with_prefix(prefix: String) -> void:
	for marker in _played_markers.keys():
		if str(marker).begins_with(prefix):
			_played_markers.erase(marker)


func _decay_env(t: float, seconds: float, attack: float, release: float) -> float:
	if t < 0.0 or t > seconds:
		return 0.0
	var attack_part := 1.0 if attack <= 0.0 else clampf(t / attack, 0.0, 1.0)
	var release_part := 1.0 if release <= 0.0 else clampf((seconds - t) / release, 0.0, 1.0)
	return minf(attack_part, release_part)


func _pulse_window(t: float, start: float, duration: float) -> float:
	if t < start or t > start + duration or duration <= 0.0:
		return 0.0
	var p := clampf((t - start) / duration, 0.0, 1.0)
	return sin(p * PI)


func _pulse_train(t: float, rate: float, width: float) -> float:
	var phase := fposmod(t * rate, 1.0)
	if phase > width:
		return 0.0
	return 1.0 - phase / maxf(0.001, width)


func _warm_tone(t: float, frequency: float, harmonic_mix: float = 0.35) -> float:
	var base := sin(TAU * frequency * t)
	var second := sin(TAU * frequency * 2.0 * t + 0.18) * harmonic_mix * 0.42
	var third := sin(TAU * frequency * 3.0 * t + 0.31) * harmonic_mix * 0.16
	return (base + second + third) / (1.0 + harmonic_mix * 0.58)


func _rounded_bell(t: float, frequency: float, release: float, attack: float = 0.004) -> float:
	if t < 0.0:
		return 0.0
	var env := _decay_env(t, release, attack, release)
	var body := _warm_tone(t, frequency, 0.30)
	var soft_partial := sin(TAU * frequency * 1.498 * t + 0.2) * 0.18
	return (body + soft_partial) * env


func _body_thump(t: float, seconds: float, frequency: float, amount: float = 0.28) -> float:
	if t < 0.0:
		return 0.0
	var progress := clampf(t / maxf(0.001, seconds), 0.0, 1.0)
	var swept := lerpf(frequency, maxf(28.0, frequency * 0.42), progress)
	return _warm_tone(t, swept, 0.22) * amount * _decay_env(t, seconds, 0.004, seconds * 0.62)


func _soft_noise(frame: int, seed: int, stride: int = 5) -> float:
	var current := _noise(frame, seed)
	var previous := _noise(frame - stride, seed + 17)
	var older := _noise(frame - stride * 2, seed + 31)
	return current * 0.50 + previous * 0.32 + older * 0.18


func _noise(frame: int, seed: int) -> float:
	var n := int((frame * 1103515245 + seed * 12345) & 0x7fffffff)
	return (float(n % 2000) / 1000.0) - 1.0


func _write_i16(data: PackedByteArray, byte_index: int, value: float) -> void:
	var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
	if sample < 0:
		sample += 65536
	if byte_index < 0 or byte_index + 1 >= data.size():
		return
	data[byte_index] = sample & 0xff
	data[byte_index + 1] = (sample >> 8) & 0xff


func _soft_limit(value: float) -> float:
	var amount := absf(value)
	if amount <= 0.72:
		return value
	return value / (1.0 + (amount - 0.72) * 0.80)


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry)
	return result


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _running_headless() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"
