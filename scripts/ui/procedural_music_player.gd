class_name ProceduralMusicPlayer
extends Node

signal authored_phrase_event(event: Dictionary)
signal authored_arrangement_selected(selection: Dictionary)

const WebAudioBridgeScript := preload("res://scripts/ui/web_audio_bridge.gd")
const MusicArrangementSelectorScript := preload("res://scripts/ui/music_arrangement_selector.gd")
const MusicDeliveryIndexScript := preload("res://scripts/core/music_delivery_index.gd")
const MusicFloatPcmStreamScript := preload("res://scripts/ui/music_float_pcm_stream.gd")

# Procedural background music for the foundation UI.
# The synth shape is ported from the old baseline: generated PCM WAV themes,
# cached per room/heat profile, played through the Music bus.

const MUSIC_BUS := "Music"
const AMBIENT_VERSION := 11
const MUSIC_FX_GRAPH_VERSION := 2
const MUSIC_STEM_CONTRACT_VERSION := 2
const SAMPLE_RATE := 44100
const EMPTY_NOTE := -999.0
const BASE_PHRASE_STEPS := 32
const STEPS_PER_BAR := 8
const PRIMER_STEPS := 8
const INSTANT_BED_SECONDS := 1.25
const DEFAULT_ARRANGEMENT_PHRASES := 4
const MIN_ARRANGEMENT_PHRASES := 2
const MAX_ARRANGEMENT_PHRASES := 6
const TRANSITION_BREAK_STEPS := 8
const TRANSITION_BREAK_WINDOW_SECONDS := 0.10
const PCM_BYTES_PER_FRAME := 2
const AMBIENT_RENDER_STRIDE_FRAMES := 4
const GENERATION_CANCEL_CHECK_FRAMES := 4096
const AMBIENT_STAGE_PRIMER := "primer"
const AMBIENT_STAGE_FULL := "full"
const MUSIC_FX_ATTACK_SECONDS := 0.25
const MUSIC_FX_RELEASE_SECONDS := 2.0
const MUSIC_MIX_ATTACK_SECONDS := 0.25
const MUSIC_MIX_RELEASE_SECONDS := 2.0
const MUSIC_FX_RESOURCE_PREFIX := "BTHMusicFx"
const MUSIC_STEM_BUS_PREFIX := "MusicStem"
const MUSIC_FX_EFFECT_ORDER := ["low_pass", "chorus", "limiter"]
const MUSIC_FX_EFFECT_TYPES := {
	"low_pass": "AudioEffectLowPassFilter",
	"chorus": "AudioEffectChorus",
	"limiter": "AudioEffectLimiter",
}
const MUSIC_SEND_BUS_PREFIX := "MusicSend"
const MUSIC_SEND_EFFECT_ORDER := ["band_pass", "delay", "distortion", "reverb", "compressor"]
const MUSIC_SEND_EFFECT_TYPES := {
	"band_pass": "AudioEffectBandPassFilter",
	"delay": "AudioEffectDelay",
	"distortion": "AudioEffectDistortion",
	"reverb": "AudioEffectReverb",
	"compressor": "AudioEffectCompressor",
}
const MUSIC_SEND_ROLE_ORDER := ["pad", "bass", "lead", "drums_low", "drums_high", "texture", "tension", "bass_dark", "drums_high_double"]
const MUSIC_FX_LERP_KEYS := [
	"lowpass_amount",
	"chorus_depth",
	"pitch_wobble_cents",
	"distortion_drive",
	"watch_tinge",
	"bandpass_q",
	"delay_amount",
	"reverb_size",
	"reverb_damping",
	"reverb_wet",
	"compressor_pump",
	"bankroll_pressure",
	"room_scale",
]
const MUSIC_STEM_ROLES := ["pad", "bass", "lead", "drums_low", "drums_high", "tension", "texture"]
const MUSIC_STEM_VARIANT_ROLES := ["bass_dark", "drums_high_double"]
const MUSIC_STEM_PLAYBACK_ROLES := ["pad", "bass", "bass_dark", "lead", "drums_low", "drums_high", "drums_high_double", "tension", "texture"]
const MUSIC_MIX_LERP_KEYS := ["pad", "bass", "bass_dark", "lead", "drums_low", "drums_high", "drums_high_double", "tension", "texture"]
const MUSIC_MIX_QUANTIZED_KEYS := ["bass", "bass_dark", "lead", "drums_high_double", "tension"]
const MUSIC_FEATURE_LERP_KEYS := ["feature", "venue_duck"]
const MUSIC_FEATURE_ROLE_WEIGHTS := {
	"pad": 0.42,
	"bass": 0.48,
	"bass_dark": 0.16,
	"lead": 0.86,
	"drums_low": 0.78,
	"drums_high": 0.92,
	"drums_high_double": 0.24,
	"tension": 0.72,
	"texture": 0.30,
}
const MUSIC_STINGER_PLAYER_COUNT := 4
const MUSIC_STINGER_PENDING_LIMIT := 8
const MUSIC_STINGER_CUE_COOLDOWN_BEATS := 2
const FLOAT_PCM_FEED_MAX_FRAMES := 4096
const BIG_WIN_ENVELOPE_BARS := 4
const BIG_WIN_COOLDOWN_BARS := 2
const MUSIC_FEATURE_ATTACK_SECONDS := 0.25
const MUSIC_FEATURE_RELEASE_SECONDS := 2.0
const MUSIC_AUTHORED_MANIFEST_PATH := "res://data/audio/music_manifest.json"
const MUSIC_AUTHORED_ROOT := "res://assets/audio/music"
const AUTHORED_MANIFEST_CACHE_LIMIT := 32
const MUSIC_MIN_VOLUME_DB := -80.0
const WEB_AUDIO_MUSIC_STEM_MAX_PCM_BYTES := 393216
const WEB_AUDIO_MUSIC_BED_SECONDS := 60.0
const WEB_AUDIO_MUSIC_BED_SAMPLE_RATE := 3000
const WEB_MIXDOWN_ROLE_WEIGHTS := {
	"pad": 0.74,
	"bass": 0.52,
	"bass_dark": 0.42,
	"lead": 0.46,
	"drums_low": 0.42,
	"drums_high": 0.36,
	"drums_high_double": 0.22,
	"tension": 0.64,
	"texture": 0.38,
}
const SCALE_MINOR := [0, 2, 3, 5, 7, 8, 10]
const SCALE_DORIAN := [0, 2, 3, 5, 7, 9, 10]
const SCALE_PHRYGIAN := [0, 1, 3, 5, 7, 8, 10]
const SCALE_HARMONIC_MINOR := [0, 2, 3, 5, 7, 8, 11]
const DEFAULT_PROGRESSION := [0, 5, 2, 6]
const DEFAULT_MOTIF := [0, EMPTY_NOTE, 2, EMPTY_NOTE, 4, EMPTY_NOTE, 2, EMPTY_NOTE, 0, EMPTY_NOTE, 3, EMPTY_NOTE, 4, EMPTY_NOTE, 2, EMPTY_NOTE]

static var _effect_property_name_cache: Dictionary = {}

var audio_enabled: bool = true
var audio_calm: bool = false

var _ambient_player: AudioStreamPlayer
var _ambient_stream_cache: Dictionary = {}
var _ambient_primer_cache: Dictionary = {}
var _ambient_instant_cache: Dictionary = {}
var _web_music_bed_cache: Dictionary = {}
var _ambient_profile_cache: Dictionary = {}
var _current_cache_key: String = ""
var _current_web_music_bed_cache_key: String = ""
var _current_web_music_bed_stem_key: String = ""
var _current_stream_is_primer: bool = false
var _current_music_context: Dictionary = {}
var _pending_cache_key: String = ""
var _transition_target_cache_key: String = ""
var _transition_target_profile: Dictionary = {}
var _deferred_transition_cache_key: String = ""
var _deferred_transition_stream: AudioStreamWAV
var _deferred_transition_stem_set: Dictionary = {}
var _deferred_transition_plan: Dictionary = {}
var _generation_token: int = 0
var _generation_mutex: Mutex = Mutex.new()
var _generation_thread: Thread
var _thread_cache_key: String = ""
var _thread_token: int = 0
var _thread_stage: String = ""
var _queued_generation_profile: Dictionary = {}
var _queued_generation_cache_key: String = ""
var _queued_generation_token: int = 0
var _music_fx_target: Dictionary = {}
var _music_fx_live: Dictionary = {}
var _music_fx_input_snapshot: Dictionary = {}
var _stem_players: Dictionary = {}
var _current_stem_set: Dictionary = {}
var _current_stem_stage: String = ""
var _music_mix_target: Dictionary = {}
var _music_mix_live: Dictionary = {}
var _music_mix_applied_target: Dictionary = {}
var _music_mix_pending: Dictionary = {}
var _music_mix_input_snapshot: Dictionary = {}
var _authored_manifest_cache: Dictionary = {}
var _authored_manifest_cache_order: Array[String] = []
var _authored_manifest_entries_cache: Array = []
var _authored_manifest_entries_by_id: Dictionary = {}
var _authored_manifest_entries_loaded := false
var _feature_stem_players: Dictionary = {}
var _feature_stinger_players: Array = []
var _feature_stem_cache: Dictionary = {}
var _current_feature_stem_set: Dictionary = {}
var _current_feature_music_id: String = ""
var _feature_mix_target: Dictionary = {}
var _feature_mix_live: Dictionary = {}
var _feature_mix_applied_target: Dictionary = {}
var _feature_mix_pending: Dictionary = {}
var _feature_input_snapshot: Dictionary = {}
var _feature_stinger_pending: Array = []
var _feature_stinger_history: Array = []
var _stinger_last_target_by_cue: Dictionary = {}
var _music_fx_runtime_bus_index := -1
var _music_fx_runtime_indices: Dictionary = {}
var _music_send_players: Dictionary = {}
var _feature_send_players: Dictionary = {}
var _music_send_matrix: Dictionary = {}
var _last_music_state: Dictionary = {}
var _music_event_envelope: Dictionary = {}
var _last_big_win_event_token := ""
var _music_event_last_bar := -1
var _float_pcm_player_states: Dictionary = {}
var _float_pcm_phase_launches: Dictionary = {}
var _authored_phrase_track_id := ""
var _authored_phrase_visit_id := ""
var _authored_phrase_slot := -1
var _authored_phrase_event_index := -1
var _last_arrangement_selection_notice := ""
var _authored_phrase_boundary_dispatch := false
var _last_authored_boundary_applied_cache_key := ""
var _authored_phrase_boundary_position := -1.0
var _pending_authored_arrangement_restore: Dictionary = {}


func _ready() -> void:
	ensure_music_fx_bus_graph()
	ensure_music_send_bus_graph()
	_ensure_music_stem_buses()
	_music_fx_target = _neutral_music_fx_vector()
	_music_fx_live = _neutral_music_fx_vector()
	_music_mix_target = _neutral_music_mix_vector()
	_music_mix_live = _neutral_music_mix_vector()
	_music_mix_applied_target = _music_mix_target.duplicate(true)
	_feature_mix_target = _neutral_feature_mix_vector()
	_feature_mix_live = _neutral_feature_mix_vector()
	_feature_mix_applied_target = _feature_mix_target.duplicate(true)
	_apply_music_fx_vector(_music_fx_live, true)
	if WebAudioBridgeScript.available():
		WebAudioBridgeScript.ensure()
	if _running_headless():
		# Headless playback requests stop before creating players or generation
		# work. Direct snapshot APIs remain callable, but there is no live audio
		# transport for this per-frame callback to advance.
		set_process(false)
	else:
		_ensure_stem_players()


func _process(delta: float) -> void:
	_feed_float_pcm_players()
	_poll_generation_thread()
	_poll_breakpoint_transition()
	_advance_music_fx(delta)
	_advance_music_mix(delta)
	_advance_feature_mix(delta)
	_advance_music_event_envelope()
	_advance_authored_arrangement()
	_poll_feature_stingers()


func _exit_tree() -> void:
	stop()
	_join_generation_thread()
	_ambient_stream_cache.clear()
	_ambient_primer_cache.clear()
	_ambient_instant_cache.clear()
	_web_music_bed_cache.clear()
	_ambient_profile_cache.clear()
	_authored_manifest_cache.clear()
	_authored_manifest_cache_order.clear()
	_authored_manifest_entries_cache.clear()
	_authored_manifest_entries_by_id.clear()
	_authored_manifest_entries_loaded = false


func debug_soak_snapshot() -> Dictionary:
	return {
		"ambient_stream_cache_size": _ambient_stream_cache.size(),
		"ambient_primer_cache_size": _ambient_primer_cache.size(),
		"ambient_instant_cache_size": _ambient_instant_cache.size(),
		"web_music_bed_cache_size": _web_music_bed_cache.size(),
		"ambient_profile_cache_size": _ambient_profile_cache.size(),
		"authored_manifest_cache_size": _authored_manifest_cache.size(),
		"authored_manifest_cache_limit": AUTHORED_MANIFEST_CACHE_LIMIT,
		"feature_stem_cache_size": _feature_stem_cache.size(),
		"feature_stinger_pending_count": _feature_stinger_pending.size(),
		"feature_stinger_history_count": _feature_stinger_history.size(),
		"stem_player_count": _stem_players.size(),
		"feature_stem_player_count": _feature_stem_players.size(),
		"feature_stinger_player_count": _feature_stinger_players.size(),
		"current_cache_key": _current_cache_key,
		"pending_cache_key": _pending_cache_key,
		"thread_cache_key": _thread_cache_key,
		"last_authored_boundary_applied_cache_key": _last_authored_boundary_applied_cache_key,
	}


# Starts or updates the generated theme for the current environment.
func play_for_environment(environment: Dictionary, heat_level: int) -> void:
	play_for_environment_state(environment, heat_level, {})


# Starts or updates the generated theme and live FX from one run-state snapshot.
func play_for_environment_state(environment: Dictionary, heat_level: int, music_state: Dictionary) -> void:
	var snapshot := _music_fx_state_from_environment(environment, heat_level, music_state)
	update_music_state(snapshot)
	if not audio_enabled or environment.is_empty() or _running_headless():
		stop()
		return
	_ensure_stem_players()
	var profile := _music_profile_from_environment(environment, heat_level)
	var cache_key := _ambient_cache_key(profile)
	var authored_selection_state := _music_mix_input_snapshot.duplicate(true)
	authored_selection_state["musical_bar"] = floori(_director_playback_position() / maxf(0.001, _music_director_bar_seconds()))
	var authored_stem_set := _authored_stem_set_from_profile(profile, authored_selection_state)
	if not authored_stem_set.is_empty():
		cache_key = "%s:selection:%s" % [cache_key, str(authored_stem_set.get("selection_key", "base"))]
	_remember_profile(cache_key, profile)
	if not authored_stem_set.is_empty():
		_ambient_stream_cache[cache_key] = authored_stem_set
		if _pending_restore_matches_authored_stem_set(authored_stem_set):
			_apply_pending_authored_arrangement_restore(cache_key, authored_stem_set)
			return
		if cache_key == _current_cache_key and _music_is_playing() and not _current_stream_is_primer:
			if WebAudioBridgeScript.available() and _current_web_music_bed_cache_key != cache_key:
				_play_web_music_bed_for_cache(cache_key, _director_playback_position(), _current_stem_set)
			return
		if WebAudioBridgeScript.available():
			_play_web_music_bed_for_cache(cache_key, 0.0, authored_stem_set)
		if _authored_phrase_boundary_dispatch:
			_accept_authored_boundary_stem_set(cache_key, authored_stem_set)
			return
		if _should_defer_music_change(cache_key):
			_transition_target_cache_key = cache_key
			_transition_target_profile = profile.duplicate(true)
			_set_deferred_transition_stem_set(cache_key, authored_stem_set)
			return
		_accept_full_stem_set(cache_key, authored_stem_set)
		return
	if cache_key == _current_cache_key and _music_is_playing() and not _current_stream_is_primer:
		if WebAudioBridgeScript.available() and _current_web_music_bed_cache_key != cache_key:
			_play_web_music_bed_for_cache(cache_key, _director_playback_position(), _current_stem_set)
		return
	if WebAudioBridgeScript.available():
		# Web keeps the compact browser bed as final procedural music; applying
		# the desktop full-stem result hitches Chrome when generation completes.
		_play_web_full_bed(profile, cache_key)
		return
	if _should_defer_music_change(cache_key):
		_schedule_breakpoint_music_change(profile, cache_key)
		return
	if _ambient_stream_cache.has(cache_key):
		_play_full_stem_set(cache_key, _ambient_stream_cache[cache_key])
		return
	if _pending_cache_key == cache_key:
		if _current_cache_key != cache_key and _ambient_instant_cache.has(cache_key):
			_play_primer_stem_set(cache_key, _ambient_instant_cache[cache_key])
		return
	_pending_cache_key = cache_key
	var token := _advance_generation_token()
	_play_instant_stem_bed(profile, cache_key)
	_request_ambient_generation(profile, cache_key, token)


# Web browsers resume the audio graph from a user gesture. If streams were
# started during the same frame as that gesture, replay them once the graph is
# running so the worklet receives live samples instead of persistent silence.
func refresh_after_web_audio_unlock(environment: Dictionary, heat_level: int, music_state: Dictionary) -> void:
	if not audio_enabled or environment.is_empty() or _running_headless():
		return
	if WebAudioBridgeScript.available():
		WebAudioBridgeScript.unlock()
	var snapshot := _music_fx_state_from_environment(environment, heat_level, music_state)
	update_music_state(snapshot)
	_ensure_stem_players()
	if not _current_stem_set.is_empty() and _stem_set_contract_valid(_current_stem_set):
		var resume_position := _director_playback_position()
		var stem_set := _current_stem_set.duplicate(true)
		var stage := _current_stem_stage
		if stage.is_empty():
			stage = str(stem_set.get("stage", AMBIENT_STAGE_FULL))
		_play_stem_set(stem_set, resume_position, stage)
		if WebAudioBridgeScript.available() and stage == AMBIENT_STAGE_FULL:
			var refresh_profile := _music_profile_from_environment(environment, heat_level)
			var refresh_cache_key := _ambient_cache_key(refresh_profile)
			_remember_profile(refresh_cache_key, refresh_profile)
			_play_web_music_bed_for_cache(refresh_cache_key, resume_position, stem_set)
		return
	play_for_environment_state(environment, heat_level, music_state)


func web_audio_user_gesture() -> void:
	if WebAudioBridgeScript.available() and audio_enabled:
		WebAudioBridgeScript.unlock()


# Stops current music without clearing generated stream cache.
func stop() -> void:
	if WebAudioBridgeScript.available():
		WebAudioBridgeScript.stop_music()
	_current_cache_key = ""
	_current_web_music_bed_cache_key = ""
	_current_web_music_bed_stem_key = ""
	_current_stream_is_primer = false
	_pending_cache_key = ""
	_transition_target_cache_key = ""
	_transition_target_profile = {}
	_deferred_transition_cache_key = ""
	_deferred_transition_stream = null
	_deferred_transition_stem_set = {}
	_deferred_transition_plan = {}
	_advance_generation_token()
	_queued_generation_profile = {}
	_queued_generation_cache_key = ""
	_queued_generation_token = 0
	for player_value in _stem_players.values():
		if player_value is AudioStreamPlayer:
			var player := player_value as AudioStreamPlayer
			player.stop()
			player.stream = null
			player.pitch_scale = 1.0
	for player_value in _feature_stem_players.values():
		if player_value is AudioStreamPlayer:
			var feature_player := player_value as AudioStreamPlayer
			feature_player.stop()
			feature_player.stream = null
			feature_player.pitch_scale = 1.0
	_stop_music_send_players(_music_send_players, true)
	_stop_music_send_players(_feature_send_players, true)
	_stop_feature_stinger_players()
	if _ambient_player != null:
		_ambient_player.stop()
		_ambient_player.stream = null
		_ambient_player.pitch_scale = 1.0
	_current_music_context = {}
	_current_stem_set = {}
	_current_stem_stage = ""
	_current_feature_stem_set = {}
	_current_feature_music_id = ""
	_feature_stinger_pending = []
	_feature_stinger_history = []
	_stinger_last_target_by_cue = {}
	_last_music_state = {}
	_music_event_envelope = {}
	_last_big_win_event_token = ""
	_music_event_last_bar = -1
	_authored_phrase_track_id = ""
	_authored_phrase_visit_id = ""
	_authored_phrase_slot = -1
	_authored_phrase_event_index = -1
	_last_arrangement_selection_notice = ""
	_authored_phrase_boundary_dispatch = false
	_last_authored_boundary_applied_cache_key = ""
	_authored_phrase_boundary_position = -1.0
	_pending_authored_arrangement_restore = {}
	_float_pcm_player_states.clear()
	_float_pcm_phase_launches.clear()
	_reset_music_fx()
	_reset_music_mix()
	_reset_feature_mix()


# Builds a stream without starting playback; used by headless validation.
func preview_stream_for_environment(environment: Dictionary, heat_level: int):
	if environment.is_empty():
		return null
	return _ambient_music_stream(_music_profile_from_environment(environment, heat_level))


# Exposes the generated composition plan for validation without building PCM.
func music_theory_snapshot_for_environment(environment: Dictionary, heat_level: int) -> Dictionary:
	if environment.is_empty():
		return {}
	var context := _ambient_generation_context(_music_profile_from_environment(environment, heat_level))
	return {
		"mode": str(context.get("mode", "")),
		"scale": (context.get("scale", []) as Array).duplicate(true),
		"progression_degrees": (context.get("progression_degrees", []) as Array).duplicate(true),
		"chord_roots": (context.get("chord_roots", []) as Array).duplicate(true),
		"chord_intervals": (context.get("chord_intervals", []) as Array).duplicate(true),
		"chord_voicings": (context.get("chord_voicings", []) as Array).duplicate(true),
		"voicing_inversions": (context.get("voicing_inversions", []) as Array).duplicate(true),
		"motif": (context.get("motif", []) as Array).duplicate(true),
		"phrase_count": int(context.get("phrase_count", 0)),
		"swing_amount": snappedf(float(context.get("swing_amount", 0.0)), 0.0001),
		"arrangement_form": str(context.get("arrangement_form", "")),
		"bridge_phrase_index": int(context.get("bridge_phrase_index", 0)),
		"answer_transform": str(context.get("answer_transform", "")),
		"instrument_palette": _copy_dict(context.get("instrument_palette", {})),
		"palette_id": str(context.get("palette_id", "")),
	}


# Exposes staged live-generation sizing for validation without starting threads.
func music_generation_latency_snapshot_for_environment(environment: Dictionary, heat_level: int) -> Dictionary:
	if environment.is_empty():
		return {}
	var profile := _music_profile_from_environment(environment, heat_level)
	var context := _ambient_generation_context(profile)
	var full_frames := int(context.get("frames", 0))
	var primer_context := _primer_context(context)
	var primer_frames := int(primer_context.get("frames", 0))
	var instant_frames := int(INSTANT_BED_SECONDS * float(SAMPLE_RATE))
	var web_bed_seconds := _web_music_bed_duration_seconds(context, WEB_AUDIO_MUSIC_BED_SECONDS)
	var web_bed_frames := int(web_bed_seconds * float(WEB_AUDIO_MUSIC_BED_SAMPLE_RATE))
	var web_bed_track_id := "web_%s_%s" % [str(profile.get("archetype_id", "environment")), str(profile.get("palette_id", ""))]
	var authored_stem_set := _authored_stem_set_from_profile(profile)
	var web_mixdown_source := "procedural"
	var web_mixdown_source_seconds := float(full_frames) / float(SAMPLE_RATE)
	if not authored_stem_set.is_empty():
		web_mixdown_source = "authored"
		var authored_sample_rate := _stem_set_source_sample_rate(authored_stem_set)
		web_mixdown_source_seconds = float(int(authored_stem_set.get("loop_frames", 0))) / float(authored_sample_rate)
	var web_mixdown_frames := mini(
		maxi(1, int(WEB_AUDIO_MUSIC_STEM_MAX_PCM_BYTES / PCM_BYTES_PER_FRAME)),
		maxi(1, int(clampf(web_mixdown_source_seconds, 1.0, WEB_AUDIO_MUSIC_BED_SECONDS) * float(WEB_AUDIO_MUSIC_BED_SAMPLE_RATE)))
	)
	return {
		"full_frames": full_frames,
		"full_seconds": float(full_frames) / float(SAMPLE_RATE),
		"instant_frames": instant_frames,
		"instant_seconds": INSTANT_BED_SECONDS,
		"primer_frames": primer_frames,
		"primer_seconds": float(primer_frames) / float(SAMPLE_RATE),
		"primer_steps": PRIMER_STEPS,
		"web_bed_frames": web_bed_frames,
		"web_bed_seconds": web_bed_seconds,
		"web_bed_sample_rate": WEB_AUDIO_MUSIC_BED_SAMPLE_RATE,
		"web_bed_pcm_bytes": web_bed_frames * PCM_BYTES_PER_FRAME,
		"web_bed_bridge_cap_bytes": WEB_AUDIO_MUSIC_STEM_MAX_PCM_BYTES,
		"web_bed_cache_key": _ambient_cache_key(profile),
		"web_bed_track_id": web_bed_track_id,
		"web_mixdown_source": web_mixdown_source,
		"web_mixdown_source_seconds": web_mixdown_source_seconds,
		"web_mixdown_frames": web_mixdown_frames,
		"web_mixdown_seconds": float(web_mixdown_frames) / float(WEB_AUDIO_MUSIC_BED_SAMPLE_RATE),
		"web_mixdown_pcm_bytes": web_mixdown_frames * PCM_BYTES_PER_FRAME,
	}


func music_stem_manifest_snapshot_for_environment(environment: Dictionary, heat_level: int, music_state: Dictionary = {}, bake: bool = false) -> Dictionary:
	if environment.is_empty():
		return {}
	var profile := _music_profile_from_environment(environment, heat_level)
	var cache_key := _ambient_cache_key(profile)
	var authored_state := _normalize_music_mix_input(_music_fx_state_from_environment(environment, heat_level, music_state))
	var authored := _authored_stem_set_from_profile(profile, authored_state)
	if not authored.is_empty():
		cache_key = "%s:selection:%s" % [cache_key, str(authored.get("selection_key", "base"))]
		var authored_manifest := _stem_manifest_from_contract(authored)
		authored_manifest["cache_key"] = cache_key
		authored_manifest["cache_key_uses_heat"] = not (_copy_dict(authored.get("selected_variants", {}))).is_empty()
		authored_manifest["music_state"] = _normalize_music_mix_input(_music_fx_state_from_environment(environment, heat_level, music_state))
		return authored_manifest
	var context := _ambient_generation_context(profile)
	var stem_set := _procedural_stem_contract_from_context(profile, context, AMBIENT_STAGE_FULL)
	if bake:
		stem_set["bake_requested"] = true
	var manifest := _stem_manifest_from_contract(stem_set)
	manifest["cache_key"] = cache_key
	manifest["cache_key_uses_heat"] = false
	manifest["music_state"] = _normalize_music_mix_input(_music_fx_state_from_environment(environment, heat_level, music_state))
	return manifest


func music_mix_snapshot(music_state: Dictionary = {}, playback_position: float = -1.0) -> Dictionary:
	if playback_position >= 0.0:
		_apply_music_mix_pending_for_position(playback_position)
	var input := _music_mix_input_snapshot.duplicate(true)
	var target := _music_mix_target.duplicate(true)
	if not music_state.is_empty():
		input = _normalize_music_mix_input(music_state)
		target = _music_mix_vector_from_input(input)
		if audio_calm:
			target = _calm_music_mix_vector(target)
	return {
		"input": input,
		"target": _music_mix_public_vector(target),
		"live": _music_mix_public_vector(_music_mix_live if not _music_mix_live.is_empty() else _neutral_music_mix_vector()),
		"applied_target": _music_mix_public_vector(_music_mix_applied_target if not _music_mix_applied_target.is_empty() else _neutral_music_mix_vector()),
		"pending": _copy_dict(_music_mix_pending),
		"source": str(_current_stem_set.get("source", "procedural" if _current_stem_set.is_empty() else "")),
		"stage": _current_stem_stage,
		"cache_key": _current_cache_key,
		"bar_seconds": _music_director_bar_seconds(),
		"attack_seconds": MUSIC_MIX_ATTACK_SECONDS,
		"release_seconds": MUSIC_MIX_RELEASE_SECONDS,
		"headless": _running_headless(),
		"player_instantiated": _any_audio_player_instantiated(),
		"stem_manifest": _stem_manifest_from_contract(_current_stem_set),
		"feature": music_feature_snapshot({}, playback_position),
		"audio_calm": audio_calm,
	}


func update_feature_music_state(feature_state: Dictionary) -> void:
	var input := _normalize_feature_music_input(feature_state)
	_update_feature_mix_state(input)
	if bool(input.get("active", false)):
		var music_id := str(input.get("music_id", ""))
		if music_id != _current_feature_music_id:
			_current_feature_music_id = music_id
			if audio_enabled and not _running_headless():
				_ensure_feature_stem_players()
				_play_feature_stem_set(_feature_stem_set_for_input(input), 0.0)
	else:
		_current_feature_music_id = ""


func stop_feature_music() -> void:
	_current_feature_music_id = ""
	_current_feature_stem_set = {}
	_feature_stinger_pending = []
	_feature_stinger_history = []
	_stinger_last_target_by_cue = {}
	_reset_feature_mix()
	_stop_feature_stem_players()
	_stop_feature_stinger_players()


func play_feature_stinger(cue_id: String, context: Dictionary = {}) -> void:
	var normalized := cue_id.strip_edges()
	if normalized.is_empty():
		return
	var step_period := _music_director_step_seconds()
	var position := _director_playback_position()
	var target_step := ceili((position + 0.0001) / maxf(0.001, step_period))
	var target_position := snappedf(float(target_step) * step_period, 0.0001)
	var last_target := float(_stinger_last_target_by_cue.get(normalized, -9999.0))
	var cooldown_beats := maxi(0, int(context.get("cooldown_beats", MUSIC_STINGER_CUE_COOLDOWN_BEATS)))
	if target_position - last_target < step_period * float(cooldown_beats):
		return
	var pending := {
		"cue_id": normalized,
		"context": context.duplicate(true),
		"target_position": target_position,
		"step_seconds": snappedf(step_period, 0.0001),
		"volume_db": clampf(float(context.get("volume_db", -2.0)), -24.0, 3.0),
	}
	_stinger_last_target_by_cue[normalized] = target_position
	while _feature_stinger_pending.size() >= MUSIC_STINGER_PENDING_LIMIT:
		_feature_stinger_pending.pop_front()
	_feature_stinger_pending.append(pending)


func music_feature_snapshot(feature_state: Dictionary = {}, playback_position: float = -1.0) -> Dictionary:
	if playback_position >= 0.0:
		_apply_feature_mix_pending_for_position(playback_position)
		_apply_feature_stingers_for_position(playback_position, false)
	var input := _feature_input_snapshot.duplicate(true)
	var target := _feature_mix_target.duplicate(true)
	if not feature_state.is_empty():
		input = _normalize_feature_music_input(feature_state)
		target = _feature_mix_vector_from_input(input)
	return {
		"input": input,
		"target": _feature_mix_public_vector(target),
		"live": _feature_mix_public_vector(_feature_mix_live if not _feature_mix_live.is_empty() else _neutral_feature_mix_vector()),
		"applied_target": _feature_mix_public_vector(_feature_mix_applied_target if not _feature_mix_applied_target.is_empty() else _neutral_feature_mix_vector()),
		"pending": _copy_dict(_feature_mix_pending),
		"active_music_id": _current_feature_music_id,
		"stem_manifest": _stem_manifest_from_contract(_current_feature_stem_set),
		"pending_stingers": _copy_array(_feature_stinger_pending),
		"stinger_history": _copy_array(_feature_stinger_history),
		"bar_seconds": _music_director_bar_seconds(),
		"beat_seconds": _music_director_step_seconds(),
		"headless": _running_headless(),
		"player_instantiated": _any_audio_player_instantiated(),
	}


# Exposes the live transition policy for validation and tuning.
func music_transition_policy_snapshot_for_environment(environment: Dictionary, heat_level: int) -> Dictionary:
	if environment.is_empty():
		return {}
	var context := _ambient_generation_context(_music_profile_from_environment(environment, heat_level))
	var step_period := float(context.get("step_period", 0.36))
	var authored := _authored_stem_set_from_profile(_music_profile_from_environment(environment, heat_level), _music_mix_input_snapshot)
	var transitions := _copy_dict(authored.get("transitions", {}))
	return {
		"deferred_stream_changes": true,
		"break_steps": TRANSITION_BREAK_STEPS,
		"break_seconds": step_period * float(TRANSITION_BREAK_STEPS),
		"break_window_seconds": TRANSITION_BREAK_WINDOW_SECONDS,
		"quantize": str(transitions.get("quantize", "phrase")),
		"phrase_bars": maxi(1, int(transitions.get("phrase_bars", 4))),
		"filler_clips": true,
		"destination_time": str(transitions.get("destination_time", "same_position")),
		"parallel_stem_phase_lock": true,
		"audio_stream_interactive_semantics": ClassDB.class_exists("AudioStreamInteractive"),
	}


# Updates live DSP targets from a run-state music snapshot. This does not start
# audio playback, so headless tests can drive the mapping safely.
func update_music_state(music_state: Dictionary) -> void:
	_last_music_state = music_state.duplicate(true)
	_consume_music_events(_last_music_state, _director_playback_position())
	var effective_state := _music_state_with_event_envelope(_last_music_state, _director_playback_position())
	_music_fx_input_snapshot = _normalize_music_fx_input(effective_state)
	_music_fx_target = _music_fx_vector_from_input(_music_fx_input_snapshot)
	if audio_calm:
		_music_fx_target = _calm_music_fx_vector(_music_fx_target)
	if _music_fx_live.is_empty():
		_music_fx_live = _music_fx_target.duplicate(true)
	_update_music_mix_state(effective_state)


func music_event_envelope_snapshot(music_state: Dictionary = {}, playback_position: float = -1.0) -> Dictionary:
	var position := _director_playback_position() if playback_position < 0.0 else maxf(0.0, playback_position)
	if not music_state.is_empty():
		_consume_music_events(music_state, position)
	var effective := _music_state_with_event_envelope(_last_music_state if music_state.is_empty() else music_state, position)
	return {
		"envelope": _copy_dict(_music_event_envelope),
		"event_token": _last_big_win_event_token,
		"active": bool(effective.get("big_win", false)),
		"bars_remaining": int(effective.get("big_win_bars_remaining", 0)),
		"cooldown_bars": BIG_WIN_COOLDOWN_BARS,
		"voice_limit": MUSIC_STINGER_PLAYER_COUNT,
		"pending_voice_limit": MUSIC_STINGER_PENDING_LIMIT,
	}


func _consume_music_events(music_state: Dictionary, playback_position: float) -> void:
	var event_token := str(music_state.get("big_win_event_token", music_state.get("win_event_token", ""))).strip_edges()
	var delta := int(music_state.get("last_bankroll_delta", 0))
	var is_big_win := bool(music_state.get("big_win", false)) or delta >= int(music_state.get("big_win_threshold", 50))
	if event_token.is_empty() or event_token == _last_big_win_event_token or not is_big_win:
		return
	_last_big_win_event_token = event_token
	var bar_seconds := _music_director_bar_seconds()
	var current_bar := floori(maxf(0.0, playback_position) / maxf(0.001, bar_seconds))
	if not _music_event_envelope.is_empty() and current_bar < int(_music_event_envelope.get("cooldown_until_bar", 0)):
		return
	var start_bar := current_bar + 1
	_music_event_envelope = {
		"type": "big_win",
		"event_token": event_token,
		"start_bar": start_bar,
		"end_bar": start_bar + BIG_WIN_ENVELOPE_BARS,
		"cooldown_until_bar": start_bar + BIG_WIN_ENVELOPE_BARS + BIG_WIN_COOLDOWN_BARS,
		"trigger_delta": delta,
	}
	_music_event_last_bar = current_bar
	play_feature_stinger("big_win", {"volume_db": -1.0, "cooldown_beats": STEPS_PER_BAR})


func _music_state_with_event_envelope(music_state: Dictionary, playback_position: float) -> Dictionary:
	var result := music_state.duplicate(true)
	result["big_win"] = false
	result["big_win_bars_remaining"] = 0
	if _music_event_envelope.is_empty():
		return result
	var bar_seconds := _music_director_bar_seconds()
	var current_bar := floori(maxf(0.0, playback_position) / maxf(0.001, bar_seconds))
	var start_bar := int(_music_event_envelope.get("start_bar", 0))
	var end_bar := int(_music_event_envelope.get("end_bar", 0))
	if current_bar < end_bar:
		result["big_win"] = true
		result["big_win_bars_remaining"] = BIG_WIN_ENVELOPE_BARS if current_bar < start_bar else maxi(0, end_bar - current_bar)
	return result


func _advance_music_event_envelope() -> void:
	if _music_event_envelope.is_empty() or _last_music_state.is_empty():
		return
	var position := _director_playback_position()
	var current_bar := floori(position / maxf(0.001, _music_director_bar_seconds()))
	if current_bar == _music_event_last_bar:
		return
	_music_event_last_bar = current_bar
	_update_music_mix_state(_music_state_with_event_envelope(_last_music_state, position))


func _advance_authored_arrangement() -> void:
	if str(_current_stem_set.get("source", "")) != "authored" or _current_cache_key.is_empty():
		return
	var track_id := str(_current_stem_set.get("track_id", ""))
	if not str(_current_stem_set.get("harmony_recipe_id", "")).is_empty():
		_advance_harmony_recipe_phrase_event(track_id)
		return
	var arrangement_value: Variant = _current_stem_set.get("authored_arrangement", [])
	if typeof(arrangement_value) != TYPE_ARRAY or (arrangement_value as Array).is_empty():
		return
	var arrangement: Array = arrangement_value
	var bar_seconds := _music_director_bar_seconds()
	var current_bar := floori(_director_playback_position() / maxf(0.001, bar_seconds))
	var current_section := str(arrangement[posmod(current_bar, arrangement.size())]).to_upper()
	var next_section := str(arrangement[posmod(current_bar + 1, arrangement.size())]).to_upper()
	if current_section == next_section:
		return
	var profile := _copy_dict(_ambient_profile_cache.get(_current_cache_key, {}))
	if profile.is_empty():
		return
	var selection_state := _last_music_state.duplicate(true)
	selection_state["harmonic_section"] = next_section
	selection_state["musical_bar"] = current_bar + 1
	var next_stem_set := _authored_stem_set_from_profile(profile, selection_state)
	if next_stem_set.is_empty():
		return
	var base_cache_key := _ambient_cache_key(profile)
	var next_cache_key := "%s:selection:%s" % [base_cache_key, str(next_stem_set.get("selection_key", "base"))]
	if next_cache_key == _current_cache_key or next_cache_key == _deferred_transition_cache_key:
		return
	_remember_profile(next_cache_key, profile)
	_ambient_stream_cache[next_cache_key] = next_stem_set
	_transition_target_cache_key = next_cache_key
	_transition_target_profile = profile.duplicate(true)
	_set_deferred_transition_stem_set(next_cache_key, next_stem_set)


func _advance_harmony_recipe_phrase_event(track_id: String) -> void:
	var recipe_id := str(_current_stem_set.get("harmony_recipe_id", ""))
	if recipe_id.is_empty():
		return
	var phrase_bars := maxi(1, int(_current_stem_set.get("harmony_phrase_bars", 4)))
	var current_bar := floori(_director_playback_position() / maxf(0.001, _music_director_bar_seconds()))
	var phrase_slot := current_bar / phrase_bars
	_emit_harmony_phrase_boundaries(track_id, phrase_slot, current_bar)


func _emit_harmony_phrase_boundaries(track_id: String, phrase_slot: int, current_bar: int) -> void:
	var recipe_id := str(_current_stem_set.get("harmony_recipe_id", ""))
	var phrase_bars := maxi(1, int(_current_stem_set.get("harmony_phrase_bars", 4)))
	var visit_id := str(_current_stem_set.get("harmony_visit_id", ""))
	if _authored_phrase_track_id != track_id or _authored_phrase_visit_id != visit_id:
		_authored_phrase_track_id = track_id
		_authored_phrase_visit_id = visit_id
		_authored_phrase_slot = phrase_slot
		_authored_phrase_event_index = int(_current_stem_set.get("harmony_last_phrase_event_index", -1))
		return
	if phrase_slot == _authored_phrase_slot:
		return
	var phrase_slots_per_loop := maxi(1, ceili(float(maxi(1, int(_current_stem_set.get("bars", phrase_bars)))) / float(phrase_bars)))
	var crossed := posmod(phrase_slot - _authored_phrase_slot, phrase_slots_per_loop)
	if crossed <= 0:
		crossed = 1
	for step in range(crossed):
		_authored_phrase_event_index += 1
		var recipe_length := maxi(1, int(_current_stem_set.get("harmony_recipe_length", 1)))
		var phrase_index := posmod(_authored_phrase_event_index, recipe_length)
		var event_token := "%s:%s:%d" % [track_id, visit_id, _authored_phrase_event_index]
		_authored_phrase_boundary_dispatch = true
		_authored_phrase_boundary_position = float(current_bar) * _music_director_bar_seconds()
		authored_phrase_event.emit({
			"track_id": track_id,
			"recipe_id": recipe_id,
			"phrase_event_index": _authored_phrase_event_index,
			"phrase_index": phrase_index,
			"cycle_index": _authored_phrase_event_index / recipe_length,
			"event_token": event_token,
			"phrase_slot": posmod(_authored_phrase_slot + step + 1, phrase_slots_per_loop),
			"musical_bar": current_bar,
			"boundary_position": _authored_phrase_boundary_position,
		})
		_authored_phrase_boundary_dispatch = false
		_authored_phrase_boundary_position = -1.0
	_authored_phrase_slot = phrase_slot


# Rebinds the live phrase counter after a RunState load without rebuilding the
# transport. The next boundary continues from the restored event index.
func sync_authored_arrangement_state(state: Dictionary) -> void:
	_pending_authored_arrangement_restore = state.duplicate(true)
	_authored_phrase_track_id = ""
	_authored_phrase_visit_id = ""
	_authored_phrase_slot = -1
	_authored_phrase_event_index = int(state.get("last_phrase_event_index", -1))
	_last_arrangement_selection_notice = ""


func _pending_restore_matches_authored_stem_set(stem_set: Dictionary) -> bool:
	return not _pending_authored_arrangement_restore.is_empty() and str(_pending_authored_arrangement_restore.get("track_id", "")) == str(stem_set.get("track_id", ""))


func _apply_pending_authored_arrangement_restore(cache_key: String, stem_set: Dictionary) -> void:
	var restored := _pending_authored_arrangement_restore.duplicate(true)
	_pending_authored_arrangement_restore = {}
	_authored_phrase_track_id = str(restored.get("track_id", ""))
	_authored_phrase_visit_id = str(restored.get("visit_id", ""))
	_authored_phrase_slot = maxi(0, int(restored.get("phrase_slot", 0)))
	_authored_phrase_event_index = int(restored.get("last_phrase_event_index", -1))
	var resume_position := _phrase_slot_music_position(stem_set, _authored_phrase_slot)
	_play_full_stem_set(cache_key, stem_set, resume_position)


static func _phrase_slot_music_position(stem_set: Dictionary, phrase_slot: int) -> float:
	var sample_rate := maxi(1, int(stem_set.get("sample_rate", SAMPLE_RATE)))
	var loop_frames := maxi(1, int(stem_set.get("loop_frames", 1)))
	var bars := maxi(1, int(stem_set.get("bars", 1)))
	var phrase_bars := maxi(1, int(stem_set.get("harmony_phrase_bars", 1)))
	var loop_seconds := float(loop_frames) / float(sample_rate)
	var bar_seconds := loop_seconds / float(bars)
	return fmod(float(maxi(0, phrase_slot) * phrase_bars) * bar_seconds, loop_seconds)


func music_fx_snapshot(music_state: Dictionary = {}) -> Dictionary:
	var input := _music_fx_input_snapshot.duplicate(true)
	var target := _music_fx_target.duplicate(true)
	if not music_state.is_empty():
		input = _normalize_music_fx_input(music_state)
		target = _music_fx_vector_from_input(input)
		if audio_calm:
			target = _calm_music_fx_vector(target)
	return {
		"graph": music_fx_bus_graph_snapshot(),
		"input": input,
		"target": _music_fx_public_vector(target),
		"send_matrix": _music_send_matrix_from_vector(target),
		"live": _music_fx_public_vector(_music_fx_live if not _music_fx_live.is_empty() else _neutral_music_fx_vector()),
		"attack_seconds": MUSIC_FX_ATTACK_SECONDS,
		"release_seconds": MUSIC_FX_RELEASE_SECONDS,
		"headless": _running_headless(),
		"player_instantiated": _any_audio_player_instantiated(),
		"audio_calm": audio_calm,
	}


static func ensure_music_fx_bus_graph() -> Dictionary:
	var bus_index := _ensure_audio_bus(MUSIC_BUS)
	if not _music_fx_graph_matches(bus_index):
		while AudioServer.get_bus_effect_count(bus_index) > 0:
			AudioServer.remove_bus_effect(bus_index, AudioServer.get_bus_effect_count(bus_index) - 1)
		for key_value in MUSIC_FX_EFFECT_ORDER:
			var key := str(key_value)
			var effect := _new_music_fx_effect(key)
			effect.resource_name = _music_fx_resource_name(key)
			_configure_music_fx_effect(key, effect)
			AudioServer.add_bus_effect(bus_index, effect)
		_set_music_fx_startup_enabled(bus_index)
	else:
		_set_music_fx_safety_enabled(bus_index)
	ensure_music_send_bus_graph()
	return music_fx_bus_graph_snapshot()


func _ensure_music_fx_runtime_refs() -> int:
	var current_bus_index := AudioServer.get_bus_index(MUSIC_BUS)
	if _music_fx_runtime_bus_index >= 0 \
			and current_bus_index == _music_fx_runtime_bus_index \
			and AudioServer.get_bus_effect_count(_music_fx_runtime_bus_index) == MUSIC_FX_EFFECT_ORDER.size() \
			and _music_fx_runtime_indices.size() == MUSIC_FX_EFFECT_ORDER.size():
		return _music_fx_runtime_bus_index
	var graph := ensure_music_fx_bus_graph()
	_music_fx_runtime_bus_index = int(graph.get("bus_index", -1))
	_music_fx_runtime_indices = {}
	if _music_fx_runtime_bus_index < 0:
		return -1
	for key_value in MUSIC_FX_EFFECT_ORDER:
		var key := str(key_value)
		_music_fx_runtime_indices[key] = _music_fx_effect_index(_music_fx_runtime_bus_index, key)
	return _music_fx_runtime_bus_index


static func music_fx_bus_graph_snapshot() -> Dictionary:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS)
	var effects: Array = []
	if bus_index >= 0:
		for index in range(AudioServer.get_bus_effect_count(bus_index)):
			var effect := AudioServer.get_bus_effect(bus_index, index)
			effects.append({
				"index": index,
				"resource_name": effect.resource_name if effect != null else "",
				"type": effect.get_class() if effect != null else "",
				"enabled": AudioServer.is_bus_effect_enabled(bus_index, index),
			})
	return {
		"version": MUSIC_FX_GRAPH_VERSION,
		"bus": MUSIC_BUS,
		"bus_index": bus_index,
		"effect_count": effects.size(),
		"effects": effects,
		"effect_order": MUSIC_FX_EFFECT_ORDER.duplicate(true),
		"idempotent": bus_index >= 0 and _music_fx_graph_matches(bus_index),
		"send_buses": music_send_bus_graph_snapshot(),
	}


static func ensure_music_send_bus_graph() -> Dictionary:
	_ensure_audio_bus(MUSIC_BUS)
	for effect_value in MUSIC_SEND_EFFECT_ORDER:
		var effect_key := str(effect_value)
		var bus_name := _music_send_bus_name(effect_key)
		var bus_index := _ensure_audio_bus(bus_name)
		AudioServer.set_bus_send(bus_index, MUSIC_BUS)
		var matches := AudioServer.get_bus_effect_count(bus_index) == 1
		if matches:
			var existing := AudioServer.get_bus_effect(bus_index, 0)
			matches = existing != null and existing.resource_name == _music_fx_resource_name("send_%s" % effect_key) and existing.get_class() == str(MUSIC_SEND_EFFECT_TYPES.get(effect_key, ""))
		if not matches:
			while AudioServer.get_bus_effect_count(bus_index) > 0:
				AudioServer.remove_bus_effect(bus_index, AudioServer.get_bus_effect_count(bus_index) - 1)
			var effect := _new_music_fx_effect(effect_key)
			effect.resource_name = _music_fx_resource_name("send_%s" % effect_key)
			_configure_music_fx_effect(effect_key, effect)
			AudioServer.add_bus_effect(bus_index, effect)
		AudioServer.set_bus_effect_enabled(bus_index, 0, true)
	return music_send_bus_graph_snapshot()


static func music_send_bus_graph_snapshot() -> Dictionary:
	var buses := {}
	for effect_value in MUSIC_SEND_EFFECT_ORDER:
		var effect_key := str(effect_value)
		var bus_name := _music_send_bus_name(effect_key)
		var bus_index := AudioServer.get_bus_index(bus_name)
		var effect := AudioServer.get_bus_effect(bus_index, 0) if bus_index >= 0 and AudioServer.get_bus_effect_count(bus_index) > 0 else null
		buses[effect_key] = {
			"bus": bus_name,
			"bus_index": bus_index,
			"send": AudioServer.get_bus_send(bus_index) if bus_index >= 0 else "",
			"effect_type": effect.get_class() if effect != null else "",
			"independent_role_sends": true,
		}
	return {"effects": MUSIC_SEND_EFFECT_ORDER.duplicate(true), "buses": buses}


static func ensure_music_stem_bus_graph() -> Dictionary:
	_ensure_music_stem_buses()
	return music_stem_bus_graph_snapshot()


func _ensure_stem_players() -> void:
	_ensure_music_stem_buses()
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		if _stem_players.has(role) and _stem_players[role] is AudioStreamPlayer:
			continue
		var player := AudioStreamPlayer.new()
		player.name = "MusicStem_%s" % role
		player.bus = _music_stem_bus_name(role)
		player.volume_db = MUSIC_MIN_VOLUME_DB
		add_child(player)
		_stem_players[role] = player
	if _ambient_player == null and _stem_players.has("pad"):
		_ambient_player = _stem_players["pad"] as AudioStreamPlayer


func _ensure_feature_stem_players() -> void:
	_ensure_music_stem_buses()
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		if _feature_stem_players.has(role) and _feature_stem_players[role] is AudioStreamPlayer:
			continue
		var player := AudioStreamPlayer.new()
		player.name = "FeatureMusicStem_%s" % role
		player.bus = _music_stem_bus_name(role)
		player.volume_db = MUSIC_MIN_VOLUME_DB
		add_child(player)
		_feature_stem_players[role] = player


func _ensure_feature_stinger_players() -> void:
	if not _feature_stinger_players.is_empty():
		return
	for index in range(MUSIC_STINGER_PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "MusicFeatureStinger_%d" % index
		player.bus = MUSIC_BUS
		player.volume_db = -2.5
		add_child(player)
		_feature_stinger_players.append(player)


func _any_audio_player_instantiated() -> bool:
	if _ambient_player != null:
		return true
	for player_value in _stem_players.values():
		if player_value is AudioStreamPlayer:
			return true
	for player_value in _feature_stem_players.values():
		if player_value is AudioStreamPlayer:
			return true
	for player_value in _feature_stinger_players:
		if player_value is AudioStreamPlayer:
			return true
	return false


func _running_headless() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"


func _reset_music_fx() -> void:
	_music_fx_input_snapshot = _normalize_music_fx_input({})
	_music_fx_target = _neutral_music_fx_vector()
	_music_fx_live = _neutral_music_fx_vector()
	_apply_music_fx_vector(_music_fx_live, true)


func _reset_music_mix() -> void:
	_music_mix_input_snapshot = _normalize_music_mix_input({})
	_music_mix_target = _neutral_music_mix_vector()
	_music_mix_live = _neutral_music_mix_vector()
	_music_mix_applied_target = _music_mix_target.duplicate(true)
	_music_mix_pending = {}
	_apply_music_mix_vector(_music_mix_live, true)


func _reset_feature_mix() -> void:
	_feature_input_snapshot = _normalize_feature_music_input({})
	_feature_mix_target = _neutral_feature_mix_vector()
	_feature_mix_live = _neutral_feature_mix_vector()
	_feature_mix_applied_target = _feature_mix_target.duplicate(true)
	_feature_mix_pending = {}
	_apply_feature_mix_vector(_feature_mix_live, true)


func _advance_music_fx(delta: float) -> void:
	if _music_fx_target.is_empty():
		_music_fx_target = _neutral_music_fx_vector()
	if _music_fx_live.is_empty():
		_music_fx_live = _neutral_music_fx_vector()
	var safe_delta := maxf(0.0, delta)
	for key_value in MUSIC_FX_LERP_KEYS:
		var key := str(key_value)
		var live_value := float(_music_fx_live.get(key, 0.0))
		var target_value := float(_music_fx_target.get(key, 0.0))
		var time_constant := MUSIC_FX_ATTACK_SECONDS if target_value > live_value else MUSIC_FX_RELEASE_SECONDS
		var amount := 1.0 if safe_delta <= 0.0 else clampf(safe_delta / maxf(0.001, time_constant), 0.0, 1.0)
		_music_fx_live[key] = lerpf(live_value, target_value, amount)
	_music_fx_live["heat"] = float(_music_fx_target.get("heat", 0.0))
	_music_fx_live["alcohol_tier"] = int(_music_fx_target.get("alcohol_tier", 0))
	_music_fx_live["boss_floor"] = bool(_music_fx_target.get("boss_floor", false))
	_music_fx_live["showdown"] = bool(_music_fx_target.get("showdown", false))
	_music_fx_live["watched"] = bool(_music_fx_target.get("watched", false))
	_apply_music_fx_vector(_music_fx_live, false)


func _advance_music_mix(delta: float) -> void:
	if _music_mix_target.is_empty():
		_music_mix_target = _neutral_music_mix_vector()
	if _music_mix_live.is_empty():
		_music_mix_live = _neutral_music_mix_vector()
	_apply_music_mix_pending_for_position(_director_playback_position())
	var safe_delta := maxf(0.0, delta)
	for key_value in MUSIC_MIX_LERP_KEYS:
		var key := str(key_value)
		var live_value := float(_music_mix_live.get(key, 0.0))
		var target_value := float(_music_mix_target.get(key, 0.0))
		var time_constant := MUSIC_MIX_ATTACK_SECONDS if target_value > live_value else MUSIC_MIX_RELEASE_SECONDS
		var amount := 1.0 if safe_delta <= 0.0 else clampf(safe_delta / maxf(0.001, time_constant), 0.0, 1.0)
		_music_mix_live[key] = lerpf(live_value, target_value, amount)
	_apply_music_mix_vector(_music_mix_live, false)


func _apply_music_mix_vector(vector: Dictionary, _force: bool) -> void:
	var role_volumes := _music_role_volume_db_map(vector)
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		var player: AudioStreamPlayer = _stem_players.get(role, null)
		if player == null:
			continue
		player.volume_db = float(role_volumes.get(role, MUSIC_MIN_VOLUME_DB))
	if WebAudioBridgeScript.available():
		WebAudioBridgeScript.set_music_mix("music", role_volumes)


func _music_role_volume_db_map(vector: Dictionary) -> Dictionary:
	var duck := clampf(float(_feature_mix_live.get("venue_duck", 0.0)), 0.0, 0.82)
	var result := {}
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		var gain := clampf(float(vector.get(role, 0.0)), 0.0, 1.35)
		if role == "pad":
			gain *= lerpf(1.0, 0.42, duck)
		elif role == "lead" or role == "texture":
			gain *= lerpf(1.0, 0.62, duck)
		elif role == "bass" or role == "bass_dark":
			gain *= lerpf(1.0, 0.78, duck)
		result[role] = _gain_to_db(gain)
	return result


func _update_music_mix_state(music_state: Dictionary) -> void:
	_music_mix_input_snapshot = _normalize_music_mix_input(music_state)
	var next_target := _music_mix_vector_from_input(_music_mix_input_snapshot)
	if audio_calm:
		next_target = _calm_music_mix_vector(next_target)
	if _music_mix_target.is_empty() or _music_mix_live.is_empty():
		_music_mix_target = next_target.duplicate(true)
		_music_mix_live = next_target.duplicate(true)
		_music_mix_applied_target = next_target.duplicate(true)
		_music_mix_pending = {}
		return
	_schedule_or_apply_music_mix_target(next_target, _director_playback_position())


func _schedule_or_apply_music_mix_target(next_target: Dictionary, playback_position: float) -> void:
	var bar_seconds := _music_director_bar_seconds()
	var current_bar := floori(maxf(0.0, playback_position) / maxf(0.001, bar_seconds))
	var target_bar := current_bar + 1
	var pending_changes := {}
	for key_value in MUSIC_MIX_QUANTIZED_KEYS:
		var key := str(key_value)
		var old_value := float(_music_mix_target.get(key, 0.0))
		var new_value := float(next_target.get(key, 0.0))
		if absf(old_value - new_value) > 0.001:
			pending_changes[key] = snappedf(new_value, 0.0001)
	for key_value in MUSIC_MIX_LERP_KEYS:
		var key := str(key_value)
		if bool(pending_changes.has(key)):
			continue
		_music_mix_target[key] = float(next_target.get(key, 0.0))
	if pending_changes.is_empty():
		_music_mix_pending = {}
		_music_mix_applied_target = _music_mix_target.duplicate(true)
		return
	_music_mix_pending = {
		"changes": pending_changes,
		"target_bar": target_bar,
		"target_position": snappedf(float(target_bar) * bar_seconds, 0.0001),
		"bar_seconds": snappedf(bar_seconds, 0.0001),
	}
	_music_mix_applied_target = _music_mix_target.duplicate(true)


func _apply_music_mix_pending_for_position(playback_position: float) -> void:
	if _music_mix_pending.is_empty():
		return
	var target_position := float(_music_mix_pending.get("target_position", 0.0))
	if playback_position + 0.0001 < target_position:
		return
	var changes: Dictionary = _music_mix_pending.get("changes", {}) as Dictionary
	for key_value in changes.keys():
		var key := str(key_value)
		_music_mix_target[key] = float(changes.get(key_value, 0.0))
	_music_mix_pending = {}
	_music_mix_applied_target = _music_mix_target.duplicate(true)


func _advance_feature_mix(delta: float) -> void:
	if _feature_mix_target.is_empty():
		_feature_mix_target = _neutral_feature_mix_vector()
	if _feature_mix_live.is_empty():
		_feature_mix_live = _neutral_feature_mix_vector()
	_apply_feature_mix_pending_for_position(_director_playback_position())
	var safe_delta := maxf(0.0, delta)
	for key_value in MUSIC_FEATURE_LERP_KEYS:
		var key := str(key_value)
		var live_value := float(_feature_mix_live.get(key, 0.0))
		var target_value := float(_feature_mix_target.get(key, 0.0))
		var time_constant := MUSIC_FEATURE_ATTACK_SECONDS if target_value > live_value else MUSIC_FEATURE_RELEASE_SECONDS
		var amount := 1.0 if safe_delta <= 0.0 else clampf(safe_delta / maxf(0.001, time_constant), 0.0, 1.0)
		_feature_mix_live[key] = lerpf(live_value, target_value, amount)
	_apply_feature_mix_vector(_feature_mix_live, false)
	_apply_music_mix_vector(_music_mix_live if not _music_mix_live.is_empty() else _neutral_music_mix_vector(), false)
	if float(_feature_mix_target.get("feature", 0.0)) <= 0.001 and float(_feature_mix_live.get("feature", 0.0)) <= 0.002:
		_stop_feature_stem_players()


func _apply_feature_mix_vector(vector: Dictionary, _force: bool) -> void:
	var role_volumes := _feature_role_volume_db_map(vector)
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		var player: AudioStreamPlayer = _feature_stem_players.get(role, null)
		if player == null:
			continue
		player.volume_db = float(role_volumes.get(role, MUSIC_MIN_VOLUME_DB))
	if WebAudioBridgeScript.available() and _web_audio_stem_set_bridge_allowed(_current_feature_stem_set, "feature", AMBIENT_STAGE_FULL):
		WebAudioBridgeScript.set_music_mix("feature", role_volumes)


func _feature_role_volume_db_map(vector: Dictionary) -> Dictionary:
	var feature_gain := clampf(float(vector.get("feature", 0.0)), 0.0, 1.2)
	var result := {}
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		var role_weight := clampf(float(MUSIC_FEATURE_ROLE_WEIGHTS.get(role, 0.0)), 0.0, 1.0)
		result[role] = _gain_to_db(feature_gain * role_weight)
	return result


func _update_feature_mix_state(feature_state: Dictionary) -> void:
	_feature_input_snapshot = _normalize_feature_music_input(feature_state)
	var next_target := _feature_mix_vector_from_input(_feature_input_snapshot)
	_schedule_or_apply_feature_mix_target(next_target, _director_playback_position())


func _schedule_or_apply_feature_mix_target(next_target: Dictionary, playback_position: float) -> void:
	var bar_seconds := _music_director_bar_seconds()
	var current_bar := floori(maxf(0.0, playback_position) / maxf(0.001, bar_seconds))
	var target_bar := current_bar + 1
	var pending_changes := {}
	for key_value in MUSIC_FEATURE_LERP_KEYS:
		var key := str(key_value)
		var old_value := float(_feature_mix_target.get(key, 0.0))
		var new_value := float(next_target.get(key, 0.0))
		if absf(old_value - new_value) > 0.001:
			pending_changes[key] = snappedf(new_value, 0.0001)
	if pending_changes.is_empty():
		_feature_mix_pending = {}
		_feature_mix_applied_target = _feature_mix_target.duplicate(true)
		return
	_feature_mix_pending = {
		"changes": pending_changes,
		"target_bar": target_bar,
		"target_position": snappedf(float(target_bar) * bar_seconds, 0.0001),
		"bar_seconds": snappedf(bar_seconds, 0.0001),
	}
	_feature_mix_applied_target = _feature_mix_target.duplicate(true)


func _apply_feature_mix_pending_for_position(playback_position: float) -> void:
	if _feature_mix_pending.is_empty():
		return
	var target_position := float(_feature_mix_pending.get("target_position", 0.0))
	if playback_position + 0.0001 < target_position:
		return
	var changes: Dictionary = _feature_mix_pending.get("changes", {}) as Dictionary
	for key_value in changes.keys():
		var key := str(key_value)
		_feature_mix_target[key] = float(changes.get(key_value, 0.0))
	_feature_mix_pending = {}
	_feature_mix_applied_target = _feature_mix_target.duplicate(true)


func _apply_music_fx_vector(vector: Dictionary, _force: bool) -> void:
	var bus_index := _ensure_music_fx_runtime_refs()
	if bus_index < 0:
		return
	var lowpass_amount := clampf(float(vector.get("lowpass_amount", 0.0)), 0.0, 1.0)
	var chorus_depth := clampf(float(vector.get("chorus_depth", 0.0)), 0.0, 1.0)
	var distortion_drive := clampf(float(vector.get("distortion_drive", 0.0)), 0.0, 1.0)
	var reverb_wet := clampf(float(vector.get("reverb_wet", 0.0)), 0.0, 1.0)
	var watch_tinge := clampf(float(vector.get("watch_tinge", 0.0)), 0.0, 1.0)
	var compressor_pump := clampf(float(vector.get("compressor_pump", 0.0)), 0.0, 1.0)
	var lowpass_cutoff_hz := snappedf(lerpf(18000.0, 4200.0, lowpass_amount), 0.01)
	var lowpass_resonance := 0.18
	var compressor_threshold_db := snappedf(lerpf(-6.0, -22.0, compressor_pump), 0.001)
	var compressor_ratio := snappedf(lerpf(2.0, 5.2, compressor_pump), 0.001)
	var compressor_gain_db := snappedf(lerpf(0.0, 2.2, compressor_pump), 0.001)
	var low_pass_index := int(_music_fx_runtime_indices.get("low_pass", -1))
	if low_pass_index >= 0:
		var effect := AudioServer.get_bus_effect(bus_index, low_pass_index)
		_set_effect_property(effect, "cutoff_hz", lowpass_cutoff_hz)
		_set_effect_property(effect, "resonance", lowpass_resonance)
		AudioServer.set_bus_effect_enabled(bus_index, low_pass_index, lowpass_amount > 0.012)
	var chorus_index := int(_music_fx_runtime_indices.get("chorus", -1))
	if chorus_index >= 0:
		var effect := AudioServer.get_bus_effect(bus_index, chorus_index)
		_set_effect_property(effect, "dry", 1.0)
		_set_effect_property(effect, "wet", clampf(chorus_depth * 0.34, 0.0, 0.34))
		_set_effect_property(effect, "voice_count", 2)
		_set_effect_property(effect, "voice/1/rate_hz", 0.18)
		_set_effect_property(effect, "voice/1/depth_ms", 2.0 + chorus_depth * 12.0)
		_set_effect_property(effect, "voice/1/level_db", -18.0 + chorus_depth * 8.0)
		_set_effect_property(effect, "voice/2/rate_hz", 0.11)
		_set_effect_property(effect, "voice/2/depth_ms", 1.0 + chorus_depth * 7.0)
		_set_effect_property(effect, "voice/2/level_db", -22.0 + chorus_depth * 7.0)
		AudioServer.set_bus_effect_enabled(bus_index, chorus_index, chorus_depth > 0.012)
	var distortion_index := int(_music_fx_runtime_indices.get("distortion", -1))
	if distortion_index >= 0:
		var effect := AudioServer.get_bus_effect(bus_index, distortion_index)
		_set_effect_property(effect, "drive", distortion_drive)
		_set_effect_property(effect, "pre_gain", 0.0)
		_set_effect_property(effect, "post_gain", -4.0 * distortion_drive)
		_set_effect_property(effect, "keep_hf_hz", 7200.0)
		AudioServer.set_bus_effect_enabled(bus_index, distortion_index, distortion_drive > 0.012)
	var reverb_index := int(_music_fx_runtime_indices.get("reverb", -1))
	if reverb_index >= 0:
		var effect := AudioServer.get_bus_effect(bus_index, reverb_index)
		_set_effect_property(effect, "room_size", snappedf(clampf(float(vector.get("reverb_size", 0.22)), 0.0, 1.0), 0.0001))
		_set_effect_property(effect, "damping", snappedf(clampf(float(vector.get("reverb_damping", 0.72)), 0.0, 1.0), 0.0001))
		_set_effect_property(effect, "wet", reverb_wet)
		_set_effect_property(effect, "dry", 1.0)
		_set_effect_property(effect, "spread", 0.42)
		AudioServer.set_bus_effect_enabled(bus_index, reverb_index, reverb_wet > 0.008)
	var compressor_index := int(_music_fx_runtime_indices.get("compressor", -1))
	if compressor_index >= 0:
		var effect := AudioServer.get_bus_effect(bus_index, compressor_index)
		_set_effect_property(effect, "threshold", compressor_threshold_db)
		_set_effect_property(effect, "ratio", compressor_ratio)
		_set_effect_property(effect, "gain", compressor_gain_db)
		_set_effect_property(effect, "attack_us", 8500.0)
		_set_effect_property(effect, "release_ms", 220.0)
		_set_effect_property(effect, "mix", 1.0)
		AudioServer.set_bus_effect_enabled(bus_index, compressor_index, true)
	var limiter_index := int(_music_fx_runtime_indices.get("limiter", -1))
	if limiter_index >= 0:
		var effect := AudioServer.get_bus_effect(bus_index, limiter_index)
		_set_effect_property(effect, "ceiling_db", -0.5)
		_set_effect_property(effect, "threshold_db", -0.7)
		_set_effect_property(effect, "soft_clip_db", 1.0)
		_set_effect_property(effect, "soft_clip_ratio", 8.0)
		AudioServer.set_bus_effect_enabled(bus_index, limiter_index, true)
	_configure_music_send_effects(vector)
	_music_send_matrix = _music_send_matrix_from_vector(vector)
	_music_send_matrix = _merge_authored_send_preferences(_music_send_matrix, _current_stem_set)
	_apply_music_send_matrix(_music_send_matrix, _current_stem_set, _music_send_players, false)
	_apply_music_send_matrix(_scaled_music_send_matrix(_music_send_matrix, 0.72), _current_feature_stem_set, _feature_send_players, true)
	var wobble_cents := clampf(float(vector.get("pitch_wobble_cents", 0.0)), 0.0, 18.0)
	var pitch_scale := 1.0
	if wobble_cents > 0.001:
		var wobble := sin(TAU * 0.18 * (float(Time.get_ticks_msec()) / 1000.0))
		pitch_scale = pow(2.0, (wobble_cents * wobble) / 1200.0)
	for player_value in _stem_players.values():
		if player_value is AudioStreamPlayer:
			(player_value as AudioStreamPlayer).pitch_scale = pitch_scale
	for player_value in _feature_stem_players.values():
		if player_value is AudioStreamPlayer:
			(player_value as AudioStreamPlayer).pitch_scale = pitch_scale
	if _ambient_player != null:
		_ambient_player.pitch_scale = pitch_scale
	for group_value in [_music_send_players, _feature_send_players]:
		for player_value in (group_value as Dictionary).values():
			if player_value is AudioStreamPlayer:
				(player_value as AudioStreamPlayer).pitch_scale = pitch_scale


func _configure_music_send_effects(vector: Dictionary) -> void:
	ensure_music_send_bus_graph()
	var watch_tinge := clampf(float(vector.get("watch_tinge", 0.0)), 0.0, 1.0)
	var bandpass_q := clampf(float(vector.get("bandpass_q", 0.45)), 0.35, 4.0)
	var band_pass := _music_send_effect("band_pass")
	_set_effect_property(band_pass, "cutoff_hz", lerpf(1250.0, 2250.0, watch_tinge))
	_set_effect_property(band_pass, "resonance", clampf(bandpass_q / (bandpass_q + 1.0), 0.18, 0.82))
	var quarter_note_ms := (_music_director_bar_seconds() / 4.0) * 1000.0
	var delay := _music_send_effect("delay")
	_set_effect_property(delay, "dry", 0.0)
	_set_effect_property(delay, "tap1_delay_ms", clampf(quarter_note_ms * 0.75, 1.0, 1500.0))
	_set_effect_property(delay, "tap2_delay_ms", clampf(quarter_note_ms * 1.50, 1.0, 1500.0))
	_set_effect_property(delay, "feedback_delay_ms", clampf(quarter_note_ms * 1.50, 1.0, 1500.0))
	var distortion_drive := clampf(float(vector.get("distortion_drive", 0.0)), 0.0, 1.0)
	var distortion := _music_send_effect("distortion")
	_set_effect_property(distortion, "drive", distortion_drive)
	_set_effect_property(distortion, "pre_gain", lerpf(-2.0, 3.0, distortion_drive))
	_set_effect_property(distortion, "post_gain", -4.0 * distortion_drive)
	var reverb := _music_send_effect("reverb")
	_set_effect_property(reverb, "room_size", clampf(float(vector.get("reverb_size", 0.22)), 0.0, 1.0))
	_set_effect_property(reverb, "damping", clampf(float(vector.get("reverb_damping", 0.72)), 0.0, 1.0))
	_set_effect_property(reverb, "wet", 1.0)
	_set_effect_property(reverb, "dry", 0.0)
	var compressor_pump := clampf(float(vector.get("compressor_pump", 0.0)), 0.0, 1.0)
	var compressor := _music_send_effect("compressor")
	_set_effect_property(compressor, "threshold", lerpf(-6.0, -22.0, compressor_pump))
	_set_effect_property(compressor, "ratio", lerpf(2.0, 5.2, compressor_pump))
	_set_effect_property(compressor, "gain", lerpf(0.0, 2.2, compressor_pump))
	_set_effect_property(compressor, "attack_us", 8500.0)
	_set_effect_property(compressor, "release_ms", 220.0)
	_set_effect_property(compressor, "mix", 1.0)


func _music_send_effect(effect_key: String) -> AudioEffect:
	var bus_index := AudioServer.get_bus_index(_music_send_bus_name(effect_key))
	if bus_index < 0 or AudioServer.get_bus_effect_count(bus_index) <= 0:
		return null
	return AudioServer.get_bus_effect(bus_index, 0)


static func _music_send_matrix_from_vector(vector: Dictionary) -> Dictionary:
	var heat := clampf(float(vector.get("heat", 0.0)), 0.0, 100.0)
	var distortion := clampf(float(vector.get("distortion_drive", 0.0)), 0.0, 1.0)
	var watched := clampf(float(vector.get("watch_tinge", 0.0)), 0.0, 1.0)
	var delay := clampf(float(vector.get("delay_amount", 0.0)), 0.0, 1.0)
	var reverb := clampf(float(vector.get("reverb_wet", 0.0)), 0.0, 1.0)
	var compressor := clampf(float(vector.get("compressor_pump", 0.0)), 0.0, 1.0)
	var distortion_roles := {}
	var active_heat_roles := clampi(int(floor(heat / 10.0)), 0, MUSIC_SEND_ROLE_ORDER.size())
	for index in range(MUSIC_SEND_ROLE_ORDER.size()):
		var role := str(MUSIC_SEND_ROLE_ORDER[index])
		distortion_roles[role] = distortion * (0.32 + float(active_heat_roles - index) * 0.055) if index < active_heat_roles else 0.0
	return {
		"band_pass": {
			"pad": watched * 0.26,
			"lead": watched * 0.48,
			"tension": watched * 0.58,
			"texture": watched * 0.22,
		},
		"delay": {
			"pad": delay * 0.24,
			"lead": delay * 0.52,
			"drums_high": delay * 0.18,
			"texture": delay * 0.30,
		},
		"distortion": distortion_roles,
		"reverb": {
			"pad": reverb * 0.80,
			"bass": reverb * 0.16,
			"bass_dark": reverb * 0.10,
			"lead": reverb,
			"drums_low": reverb * 0.12,
			"drums_high": reverb * 0.45,
			"drums_high_double": reverb * 0.32,
			"tension": reverb * 0.36,
			"texture": reverb * 0.68,
		},
		"compressor": {
			"bass": compressor,
			"bass_dark": compressor,
			"drums_low": compressor * 0.78,
			"drums_high": compressor * 0.44,
		},
	}


static func _scaled_music_send_matrix(matrix: Dictionary, scale: float) -> Dictionary:
	var result := {}
	for effect_value in matrix.keys():
		var roles := _copy_dict_static(matrix.get(effect_value, {}))
		var scaled_roles := {}
		for role_value in roles.keys():
			scaled_roles[role_value] = float(roles.get(role_value, 0.0)) * scale
		result[effect_value] = scaled_roles
	return result


static func _merge_authored_send_preferences(matrix: Dictionary, stem_set: Dictionary) -> Dictionary:
	if stem_set.is_empty():
		return matrix
	var preferences := stem_set.get("preferred_dsp_sends", {}) as Dictionary if typeof(stem_set.get("preferred_dsp_sends", {})) == TYPE_DICTIONARY else {}
	if preferences.is_empty():
		return matrix
	var result := matrix.duplicate(true)
	for role_value in preferences.keys():
		var role := str(role_value)
		var role_preferences := preferences.get(role_value, {}) as Dictionary if typeof(preferences.get(role_value, {})) == TYPE_DICTIONARY else {}
		for effect_value in role_preferences.keys():
			var effect_key := str(effect_value)
			if not MUSIC_SEND_EFFECT_ORDER.has(effect_key):
				continue
			var effect_roles := result.get(effect_key, {}) as Dictionary if typeof(result.get(effect_key, {})) == TYPE_DICTIONARY else {}
			effect_roles[role] = maxf(float(effect_roles.get(role, 0.0)), clampf(float(role_preferences.get(effect_value, 0.0)), 0.0, 1.0))
			result[effect_key] = effect_roles
	return result


func _apply_music_send_matrix(matrix: Dictionary, stem_set: Dictionary, players: Dictionary, feature: bool) -> void:
	if _running_headless() or WebAudioBridgeScript.available():
		return
	var stems := _copy_dict(stem_set.get("stems", {}))
	var phase_group := "feature_sends" if feature else "venue_sends"
	for effect_value in MUSIC_SEND_EFFECT_ORDER:
		var effect_key := str(effect_value)
		var role_sends := _copy_dict(matrix.get(effect_key, {}))
		for role_value in MUSIC_STEM_PLAYBACK_ROLES:
			var role := str(role_value)
			var key := "%s:%s" % [effect_key, role]
			var gain := clampf(float(role_sends.get(role, 0.0)), 0.0, 1.0)
			var stream: AudioStream = stems.get(role, null)
			var player: AudioStreamPlayer = players.get(key, null)
			if gain <= 0.0001 or stream == null:
				if player != null:
					player.volume_db = MUSIC_MIN_VOLUME_DB
				continue
			if player == null:
				player = AudioStreamPlayer.new()
				player.name = "%sSend_%s_%s" % ["Feature" if feature else "Music", effect_key, role]
				player.bus = _music_send_bus_name(effect_key)
				player.volume_db = MUSIC_MIN_VOLUME_DB
				add_child(player)
				players[key] = player
			if player.stream != stream:
				player.stream = stream
				_play_audio_player(player, _director_playback_position(), phase_group)
			elif not player.playing:
				_play_audio_player(player, _director_playback_position(), phase_group)
			player.volume_db = _gain_to_db(gain)


func _stop_music_send_players(players: Dictionary, clear_streams: bool) -> void:
	for player_value in players.values():
		if player_value is AudioStreamPlayer:
			var player := player_value as AudioStreamPlayer
			player.stop()
			if clear_streams:
				player.stream = null


func _play_audio_player(player: AudioStreamPlayer, source_position_seconds: float = 0.0, phase_group: String = "") -> void:
	_float_pcm_player_states.erase(player.get_instance_id())
	if not (player.stream is MusicFloatPcmStream):
		player.play(maxf(0.0, source_position_seconds))
		return
	var stream := player.stream as MusicFloatPcmStream
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		player.stop()
		return
	# A newly instantiated generator playback starts empty. Godot rejects
	# clear_buffer() after the playback becomes active, so prefill it directly.
	var process_frame := Engine.get_process_frames()
	var launch_key := "%s:%d" % [phase_group, process_frame] if not phase_group.is_empty() else ""
	var authority_frame := -1
	if not launch_key.is_empty() and _float_pcm_phase_launches.has(launch_key):
		authority_frame = int((_float_pcm_phase_launches.get(launch_key, {}) as Dictionary).get("source_frame", -1))
	var launch := float_pcm_launch_frame_snapshot(source_position_seconds, stream.mix_rate, stream.loop_begin_frame, stream.loop_end_frame, stream.loop_enabled, authority_frame)
	var cursor := int(launch.get("source_frame", 0))
	if not launch_key.is_empty():
		var group_launch := _float_pcm_phase_launches.get(launch_key, {
			"phase_group": phase_group,
			"process_frame": process_frame,
			"source_frame": cursor,
			"max_phase_error_frames": 0,
			"players": 0,
		}) as Dictionary
		group_launch["players"] = int(group_launch.get("players", 0)) + 1
		group_launch["max_phase_error_frames"] = maxi(int(group_launch.get("max_phase_error_frames", 0)), int(launch.get("phase_error_frames", 0)))
		_float_pcm_phase_launches[launch_key] = group_launch
		while _float_pcm_phase_launches.size() > 32:
			_float_pcm_phase_launches.erase(_float_pcm_phase_launches.keys()[0])
	var state := {
		"player": player,
		"playback": playback,
		"stream": stream,
		"cursor": cursor,
		"source_start_frame": cursor,
		"phase_group": phase_group,
		"launch_process_frame": process_frame,
		"finished": false,
		"drain_deadline_msec": 0,
	}
	_float_pcm_player_states[player.get_instance_id()] = state
	_feed_float_pcm_player(player.get_instance_id(), true)


static func float_pcm_launch_frame_snapshot(source_position_seconds: float, mix_rate: int, loop_begin: int, loop_end: int, loop_enabled: bool, authoritative_frame: int = -1) -> Dictionary:
	var requested := maxi(0, int(round(maxf(0.0, source_position_seconds) * float(maxi(1, mix_rate)))))
	var source_frame := requested
	if loop_enabled:
		var loop_length := maxi(1, loop_end - loop_begin)
		source_frame = loop_begin + posmod(requested - loop_begin, loop_length)
	else:
		source_frame = mini(requested, maxi(loop_begin, loop_end))
	var requested_wrapped := source_frame
	if authoritative_frame >= 0:
		source_frame = authoritative_frame
	return {
		"requested_frame": requested_wrapped,
		"source_frame": source_frame,
		"authoritative": authoritative_frame >= 0,
		"phase_error_frames": absi(source_frame - (authoritative_frame if authoritative_frame >= 0 else requested_wrapped)),
		"phase_model": "director_position_authoritative_group_launch",
	}


func float_pcm_provider_snapshot() -> Dictionary:
	return {
		"active_players": _float_pcm_player_states.size(),
		"launches": _float_pcm_phase_launches.duplicate(true),
		"phase_model": "director_position_authoritative_group_launch_then_native_mixer_clock",
		"launch_phase_tolerance_frames": 0,
	}


func _feed_float_pcm_players() -> void:
	if _float_pcm_player_states.is_empty():
		return
	for player_id_value in _float_pcm_player_states.keys():
		_feed_float_pcm_player(int(player_id_value), false)


func _feed_float_pcm_player(player_id: int, prefill: bool) -> void:
	if not _float_pcm_player_states.has(player_id):
		return
	var state: Dictionary = _float_pcm_player_states.get(player_id, {})
	var player: AudioStreamPlayer = state.get("player", null)
	var playback: AudioStreamGeneratorPlayback = state.get("playback", null)
	var stream: MusicFloatPcmStream = state.get("stream", null)
	if player == null or playback == null or stream == null or not player.playing:
		_float_pcm_player_states.erase(player_id)
		return
	if bool(state.get("finished", false)):
		if Time.get_ticks_msec() >= int(state.get("drain_deadline_msec", 0)):
			player.stop()
			_float_pcm_player_states.erase(player_id)
		return
	var available := playback.get_frames_available()
	if available <= 0:
		return
	var requested := available if prefill else mini(available, FLOAT_PCM_FEED_MAX_FRAMES)
	var buffer := PackedVector2Array()
	buffer.resize(requested)
	var cursor := int(state.get("cursor", 0))
	var written := 0
	while written < requested:
		if cursor >= stream.loop_end_frame:
			if stream.loop_enabled:
				cursor = stream.loop_begin_frame
			else:
				state["finished"] = true
				break
		buffer[written] = stream.frame_at(cursor)
		cursor += 1
		written += 1
	if written > 0:
		if written < buffer.size():
			buffer.resize(written)
		playback.push_buffer(buffer)
	state["cursor"] = cursor
	if bool(state.get("finished", false)):
		state["drain_deadline_msec"] = Time.get_ticks_msec() + int(ceil(float(written) * 1000.0 / float(stream.mix_rate))) + 300
	_float_pcm_player_states[player_id] = state


static func _music_fx_state_from_environment(environment: Dictionary, heat_level: int, music_state: Dictionary) -> Dictionary:
	var result := music_state.duplicate(true)
	result["heat"] = clampi(int(result.get("heat", result.get("heat_level", heat_level))), 0, 100)
	if not environment.is_empty():
		result["environment"] = _music_environment_payload_static(environment)
		if not result.has("visual_context"):
			result["visual_context"] = _copy_dict_static(environment.get("visual_context", {}))
		if not result.has("boss_floor"):
			result["boss_floor"] = str(environment.get("kind", "")) == "boss" or str(_copy_dict_static(environment.get("visual_context", {})).get("scene_type", "")) == "boss"
	return result


static func _music_environment_payload_static(environment: Dictionary) -> Dictionary:
	return {
		"id": str(environment.get("id", "")),
		"name": str(environment.get("name", "")),
		"display_name": str(environment.get("display_name", environment.get("name", ""))),
		"archetype_id": str(environment.get("archetype_id", "")),
		"kind": str(environment.get("kind", "")),
		"tier": str(environment.get("tier", "")),
		"mood": str(environment.get("mood", "")),
		"visual_context": _copy_dict_static(environment.get("visual_context", {})),
		"music_profile": _copy_dict_static(environment.get("music_profile", {})),
		"security_profile": _copy_dict_static(environment.get("security_profile", {})),
	}


static func _normalize_music_fx_input(music_state: Dictionary) -> Dictionary:
	var environment := _copy_dict_static(music_state.get("environment", {}))
	var visual := _copy_dict_static(music_state.get("visual_context", environment.get("visual_context", {})))
	var watch := _copy_dict_static(music_state.get("pit_boss_watch", music_state.get("watch", {})))
	var staff := _copy_dict_static(music_state.get("staff_attention", {}))
	var objective := _copy_dict_static(music_state.get("demo_objective", music_state.get("objective", {})))
	var heat := clampf(float(music_state.get("heat", music_state.get("heat_level", music_state.get("suspicion_level", 0)))), 0.0, 100.0)
	var drunk_level := clampi(int(music_state.get("drunk_level", music_state.get("alcohol_level", 0))), 0, 100)
	var alcohol_tier := clampi(int(music_state.get("alcohol_tier", _alcohol_tier_for_level(drunk_level))), 0, 3)
	var watched := bool(music_state.get("watched", false)) or bool(watch.get("watched", false))
	var watch_active := bool(music_state.get("watch_active", false)) or bool(watch.get("active", false))
	var staff_attention := bool(music_state.get("staff_attention_active", false)) or bool(staff.get("active", false))
	var attention_level := clampf(float(music_state.get("attention_level", staff.get("attention", staff.get("level", 100.0 if watched else 65.0 if staff_attention else 0.0)))), 0.0, 100.0)
	var showdown_pending := bool(music_state.get("showdown_pending", false)) or bool(objective.get("showdown_pending", false))
	var showdown_active := bool(music_state.get("showdown_active", false)) or bool(objective.get("showdown_active", false))
	var scene_type := str(visual.get("scene_type", environment.get("kind", ""))).strip_edges().to_lower()
	var boss_floor := bool(music_state.get("boss_floor", false)) or str(environment.get("kind", "")).strip_edges() == "boss" or scene_type == "boss"
	var room_scale := clampf(float(music_state.get("room_scale", _room_scale_from_visual_context(visual, environment))), 0.0, 1.0)
	var bankroll_pressure := clampf(float(music_state.get("bankroll_pressure", 0.0)), 0.0, 1.0)
	return {
		"heat": heat,
		"drunk_level": drunk_level,
		"alcohol_tier": alcohol_tier,
		"watch_active": watch_active,
		"watched": watched,
		"staff_attention": staff_attention,
		"attention_level": attention_level,
		"showdown_pending": showdown_pending,
		"showdown_active": showdown_active,
		"showdown": showdown_pending or showdown_active,
		"boss_floor": boss_floor,
		"room_scale": room_scale,
		"bankroll_pressure": bankroll_pressure,
		"scene_type": scene_type,
		"environment_id": str(environment.get("id", "")),
		"archetype_id": str(environment.get("archetype_id", "")),
	}


static func _music_fx_vector_from_input(input: Dictionary) -> Dictionary:
	var heat := clampf(float(input.get("heat", 0.0)), 0.0, 100.0)
	var alcohol_tier := clampi(int(input.get("alcohol_tier", 0)), 0, 3)
	var drunk_level := clampi(int(input.get("drunk_level", 0)), 0, 100)
	var drunk_overlay_amount := pow(clampf(float(drunk_level - 12) / 88.0, 0.0, 1.0), 1.35)
	var drunk_amount := maxf(float(alcohol_tier) / 3.0, drunk_overlay_amount)
	var heat_drive := pow(clampf((heat - 70.0) / 30.0, 0.0, 1.0), 1.35) * 0.16
	var watched := bool(input.get("watched", false))
	var staff_attention := bool(input.get("staff_attention", false))
	var attention_amount := clampf(float(input.get("attention_level", 100.0 if watched else 65.0 if staff_attention else 0.0)) / 100.0, 0.0, 1.0)
	var watch_tinge := maxf(attention_amount, 0.20 if watched else 0.12 if staff_attention else 0.0)
	var showdown := bool(input.get("showdown", false))
	var boss_floor := bool(input.get("boss_floor", false))
	var showdown_amount := 1.0 if showdown else 0.45 if boss_floor else 0.0
	var room_scale := clampf(float(input.get("room_scale", 0.35)), 0.0, 1.0)
	var bankroll_pressure := clampf(float(input.get("bankroll_pressure", 0.0)), 0.0, 1.0)
	var lowpass_amount := clampf(drunk_amount * 0.62 if drunk_level >= 35 else drunk_amount * 0.18, 0.0, 0.82)
	var distortion_drive := clampf(maxf(maxf(heat_drive, showdown_amount * 0.42), watch_tinge * 0.035), 0.0, 0.58)
	var compressor_pump := clampf(maxf(showdown_amount * 0.82, bankroll_pressure * 0.62), 0.0, 0.92)
	return {
		"heat": heat,
		"alcohol_tier": alcohol_tier,
		"lowpass_amount": lowpass_amount,
		"chorus_depth": clampf(drunk_amount * 0.48, 0.0, 0.62),
		"pitch_wobble_cents": clampf(drunk_amount * 13.0, 0.0, 16.0),
		"distortion_drive": distortion_drive,
		"watch_tinge": watch_tinge,
		"bandpass_q": lerpf(0.45, 3.8, watch_tinge),
		"delay_amount": clampf(drunk_amount * 0.46, 0.0, 0.52),
		"reverb_size": lerpf(0.20, 0.88, room_scale),
		"reverb_damping": lerpf(0.72, 0.34, room_scale),
		"reverb_wet": clampf(0.012 + room_scale * 0.105 + showdown_amount * 0.018, 0.0, 0.16),
		"compressor_pump": compressor_pump,
		"bankroll_pressure": bankroll_pressure,
		"room_scale": room_scale,
		"boss_floor": boss_floor,
		"showdown": showdown,
		"watched": watched,
	}


static func _music_fx_public_vector(vector: Dictionary) -> Dictionary:
	var result := vector.duplicate(true)
	var lowpass_amount := clampf(float(result.get("lowpass_amount", 0.0)), 0.0, 1.0)
	var watch_tinge := clampf(float(result.get("watch_tinge", 0.0)), 0.0, 1.0)
	var compressor_pump := clampf(float(result.get("compressor_pump", 0.0)), 0.0, 1.0)
	result["lowpass_cutoff_hz"] = snappedf(lerpf(18000.0, 4200.0, lowpass_amount), 0.01)
	result["lowpass_resonance"] = 0.18
	result["watch_bandpass_amount"] = snappedf(watch_tinge, 0.001)
	result["watch_bandpass_center_hz"] = snappedf(lerpf(1250.0, 2250.0, watch_tinge), 0.01)
	result["watch_bandpass_q"] = snappedf(float(result.get("bandpass_q", 0.45)), 0.001)
	result["compressor_threshold_db"] = snappedf(lerpf(-6.0, -22.0, compressor_pump), 0.001)
	result["compressor_ratio"] = snappedf(lerpf(2.0, 5.2, compressor_pump), 0.001)
	result["compressor_gain_db"] = snappedf(lerpf(0.0, 2.2, compressor_pump), 0.001)
	for key_value in MUSIC_FX_LERP_KEYS:
		var key := str(key_value)
		if result.has(key):
			result[key] = snappedf(float(result.get(key, 0.0)), 0.0001)
	return result


static func _neutral_music_fx_vector() -> Dictionary:
	return {
		"heat": 0.0,
		"alcohol_tier": 0,
		"lowpass_amount": 0.0,
		"chorus_depth": 0.0,
		"pitch_wobble_cents": 0.0,
		"distortion_drive": 0.0,
		"watch_tinge": 0.0,
		"bandpass_q": 0.45,
		"delay_amount": 0.0,
		"reverb_size": 0.20,
		"reverb_damping": 0.72,
		"reverb_wet": 0.0,
		"compressor_pump": 0.0,
		"bankroll_pressure": 0.0,
		"room_scale": 0.0,
		"boss_floor": false,
		"showdown": false,
		"watched": false,
	}


static func _normalize_music_mix_input(music_state: Dictionary) -> Dictionary:
	var fx_input := _normalize_music_fx_input(music_state)
	var debt_items := _copy_array_static(music_state.get("debt", music_state.get("debt_items", [])))
	var overdue_count := int(music_state.get("overdue_debt_count", 0))
	var active_debt_count := int(music_state.get("debt_count", debt_items.size()))
	for debt_value in debt_items:
		if typeof(debt_value) != TYPE_DICTIONARY:
			continue
		var debt_data: Dictionary = debt_value
		var status := str(debt_data.get("status", "")).strip_edges().to_lower()
		if status == "overdue" or status == "favor_due":
			overdue_count += 1
	var bankroll := int(music_state.get("bankroll", 100))
	var bankroll_pressure_amount := clampf(float(music_state.get("bankroll_pressure", 1.0 if bankroll < 50 else 0.0)), 0.0, 1.0)
	var economy := str(music_state.get("economy", "")).strip_edges().to_lower()
	if economy == "distressed" or economy == "volatile" or economy == "insolvent":
		bankroll_pressure_amount = maxf(bankroll_pressure_amount, 0.72 if economy == "distressed" else 0.55)
	var last_bankroll_delta := int(music_state.get("last_bankroll_delta", 0))
	var big_win := bool(music_state.get("big_win", false)) or last_bankroll_delta >= int(music_state.get("big_win_threshold", 50))
	var win_streak := maxi(0, int(music_state.get("win_streak", 0)))
	var big_win_bars := maxi(0, int(music_state.get("big_win_bars_remaining", 4 if big_win else 0)))
	return {
		"heat": float(fx_input.get("heat", 0.0)),
		"watched": bool(fx_input.get("watched", false)),
		"watch_active": bool(fx_input.get("watch_active", false)),
		"staff_attention": bool(fx_input.get("staff_attention", false)),
		"showdown": bool(fx_input.get("showdown", false)),
		"showdown_pending": bool(fx_input.get("showdown_pending", false)),
		"showdown_active": bool(fx_input.get("showdown_active", false)),
		"boss_floor": bool(fx_input.get("boss_floor", false)),
		"alcohol_tier": int(fx_input.get("alcohol_tier", 0)),
		"bankroll": bankroll,
		"bankroll_pressure": bankroll_pressure_amount,
		"debt_count": maxi(0, active_debt_count),
		"overdue_debt_count": maxi(0, overdue_count),
		"overdue_debt": overdue_count > 0,
		"economy": economy,
		"win_streak": win_streak,
		"big_win": big_win,
		"big_win_bars_remaining": big_win_bars,
		"music_intensity": clampf(float(music_state.get("music_intensity", float(fx_input.get("heat", 0.0)) / 100.0)), 0.0, 1.0),
		"music_tags": _copy_array_static(music_state.get("music_tags", [])),
		"harmonic_section": str(music_state.get("harmonic_section", "")).strip_edges().to_upper(),
		"musical_bar": maxi(0, int(music_state.get("musical_bar", 0))),
		"run_seed": str(music_state.get("run_seed", "")),
		"music_visit_id": str(music_state.get("music_visit_id", "")),
		"music_arrangement_state": _copy_dict_static(music_state.get("music_arrangement_state", music_state.get("arrangement_state", {}))),
		"source_environment_id": str(fx_input.get("environment_id", "")),
	}


static func _music_mix_vector_from_input(input: Dictionary) -> Dictionary:
	var heat := clampf(float(input.get("heat", 0.0)), 0.0, 100.0)
	var heat_amount := heat / 100.0
	var high_heat := pow(clampf((heat - 55.0) / 45.0, 0.0, 1.0), 1.15)
	var watched := bool(input.get("watched", false))
	var staff_attention := bool(input.get("staff_attention", false))
	var watch_amount := 1.0 if watched else 0.58 if staff_attention else 0.0
	var showdown := bool(input.get("showdown", false))
	var boss_floor := bool(input.get("boss_floor", false))
	var danger_amount := 1.0 if showdown else 0.45 if boss_floor else 0.0
	var bankroll_pressure := clampf(float(input.get("bankroll_pressure", 0.0)), 0.0, 1.0)
	var debt_pressure := 1.0 if bool(input.get("overdue_debt", false)) else clampf(float(int(input.get("debt_count", 0))) / 3.0, 0.0, 0.75)
	var pressure := clampf(maxf(bankroll_pressure, debt_pressure), 0.0, 1.0)
	var big_win_bars := maxi(0, int(input.get("big_win_bars_remaining", 0)))
	var win_boost := clampf((float(maxi(0, int(input.get("win_streak", 0)))) * 0.12) + (0.34 if big_win_bars > 0 or bool(input.get("big_win", false)) else 0.0), 0.0, 0.50)
	if showdown:
		return {
			"pad": 0.08,
			"bass": 0.0,
			"bass_dark": 0.56,
			"lead": 0.04,
			"drums_low": 0.78,
			"drums_high": 0.58,
			"drums_high_double": 0.22,
			"tension": 1.0,
			"texture": 0.28,
		}
	return {
		"pad": clampf(0.76 - pressure * 0.30 - danger_amount * 0.20, 0.18, 0.86),
		"bass": clampf(0.62 - pressure * 0.48, 0.0, 0.72),
		"bass_dark": clampf(pressure * 0.70 + danger_amount * 0.18, 0.0, 0.78),
		"lead": clampf(0.48 + win_boost - watch_amount * 0.30 - danger_amount * 0.20, 0.06, 0.95),
		"drums_low": clampf(0.42 + high_heat * 0.18 + danger_amount * 0.16, 0.22, 0.78),
		"drums_high": clampf(0.16 + high_heat * 0.58 + win_boost * 0.55, 0.05, 0.92),
		"drums_high_double": clampf(pow(clampf((heat - 78.0) / 22.0, 0.0, 1.0), 1.2) * 0.42 + win_boost * 0.24, 0.0, 0.62),
		"tension": clampf(pow(clampf((heat - 60.0) / 40.0, 0.0, 1.0), 1.3) * 0.38 + watch_amount * 0.62 + danger_amount * 0.32, 0.0, 0.95),
		"texture": clampf(0.48 + (1.0 - heat_amount) * 0.10 - danger_amount * 0.16, 0.18, 0.62),
	}


static func _music_mix_public_vector(vector: Dictionary) -> Dictionary:
	var result := {}
	for key_value in MUSIC_MIX_LERP_KEYS:
		var key := str(key_value)
		result[key] = snappedf(clampf(float(vector.get(key, 0.0)), 0.0, 1.35), 0.0001)
	return result


static func _feature_mix_public_vector(vector: Dictionary) -> Dictionary:
	var result := {}
	for key_value in MUSIC_FEATURE_LERP_KEYS:
		var key := str(key_value)
		result[key] = snappedf(clampf(float(vector.get(key, 0.0)), 0.0, 1.2), 0.0001)
	return result


static func _neutral_music_mix_vector() -> Dictionary:
	return {
		"pad": 0.76,
		"bass": 0.62,
		"bass_dark": 0.0,
		"lead": 0.48,
		"drums_low": 0.42,
		"drums_high": 0.16,
		"drums_high_double": 0.0,
		"tension": 0.0,
		"texture": 0.58,
	}


static func _neutral_feature_mix_vector() -> Dictionary:
	return {
		"feature": 0.0,
		"venue_duck": 0.0,
	}


static func _calm_music_fx_vector(vector: Dictionary) -> Dictionary:
	var result := vector.duplicate(true)
	result["lowpass_amount"] = float(result.get("lowpass_amount", 0.0)) * 0.78
	result["chorus_depth"] = float(result.get("chorus_depth", 0.0)) * 0.66
	result["pitch_wobble_cents"] = float(result.get("pitch_wobble_cents", 0.0)) * 0.58
	result["distortion_drive"] = float(result.get("distortion_drive", 0.0)) * 0.54
	result["watch_tinge"] = float(result.get("watch_tinge", 0.0)) * 0.64
	result["delay_amount"] = float(result.get("delay_amount", 0.0)) * 0.58
	result["reverb_wet"] = float(result.get("reverb_wet", 0.0)) * 0.74
	result["compressor_pump"] = float(result.get("compressor_pump", 0.0)) * 0.50
	return result


static func _calm_music_mix_vector(vector: Dictionary) -> Dictionary:
	var result := vector.duplicate(true)
	result["lead"] = float(result.get("lead", 0.0)) * 0.86
	result["drums_high"] = float(result.get("drums_high", 0.0)) * 0.72
	result["drums_high_double"] = float(result.get("drums_high_double", 0.0)) * 0.52
	result["tension"] = float(result.get("tension", 0.0)) * 0.62
	result["texture"] = float(result.get("texture", 0.0)) * 0.88
	result["pad"] = minf(0.86, float(result.get("pad", 0.0)) + 0.06)
	return result


static func _normalize_feature_music_input(feature_state: Dictionary) -> Dictionary:
	var scene := _copy_dict_static(feature_state.get("feature_scene", feature_state.get("scene", {})))
	var music := _copy_dict_static(feature_state.get("feature_music", feature_state.get("music", scene.get("feature_music", {}))))
	var active := bool(feature_state.get("active", scene.get("active", false)))
	var cue_id := str(feature_state.get("cue_id", music.get("cue_id", "feature_music"))).strip_edges()
	if cue_id.is_empty():
		cue_id = "feature_music"
	var scene_id := str(scene.get("scene_id", scene.get("mode", feature_state.get("scene_id", "")))).strip_edges()
	var music_id := "%s|%s" % [scene_id, cue_id]
	if scene_id.is_empty():
		music_id = cue_id
	return {
		"active": active,
		"cue_id": cue_id,
		"music_id": music_id,
		"scene_id": scene_id,
		"duck_background_music": bool(music.get("duck_background_music", feature_state.get("duck_background_music", active))),
		"volume_db": float(music.get("volume_db", feature_state.get("volume_db", -10.0))),
		"pitch": float(music.get("pitch", feature_state.get("pitch", 1.0))),
		"feature_scene": scene,
	}


static func _feature_mix_vector_from_input(input: Dictionary) -> Dictionary:
	if not bool(input.get("active", false)):
		return _neutral_feature_mix_vector()
	var volume_db := clampf(float(input.get("volume_db", -10.0)), -24.0, -2.0)
	var normalized_volume := clampf(db_to_linear(volume_db + 10.0), 0.35, 1.15)
	var duck_amount := 0.58 if bool(input.get("duck_background_music", true)) else 0.20
	return {
		"feature": clampf(0.86 * normalized_volume, 0.30, 1.05),
		"venue_duck": duck_amount,
	}


static func _alcohol_tier_for_level(level: int) -> int:
	if level >= 71:
		return 3
	if level >= 46:
		return 2
	if level >= 12:
		return 1
	return 0


static func _room_scale_from_visual_context(visual: Dictionary, environment: Dictionary) -> float:
	if visual.has("room_scale"):
		return clampf(float(visual.get("room_scale", 0.35)), 0.0, 1.0)
	if visual.has("scale"):
		return clampf(float(visual.get("scale", 0.35)), 0.0, 1.0)
	var scene_type := str(visual.get("scene_type", environment.get("kind", ""))).strip_edges().to_lower()
	var kind := str(environment.get("kind", "")).strip_edges().to_lower()
	var tier := clampi(int(environment.get("tier", 1)), 0, 3)
	var room_scale := 0.26 + float(tier) * 0.14
	if kind == "boss" or scene_type.find("boss") >= 0:
		room_scale = maxf(room_scale, 0.86)
	elif scene_type.find("river") >= 0 or scene_type.find("queen") >= 0:
		room_scale = maxf(room_scale, 0.72)
	elif scene_type.find("jazz") >= 0 or scene_type.find("club") >= 0:
		room_scale = maxf(room_scale, 0.62)
	elif kind.find("casino") >= 0 or scene_type.find("bar") >= 0:
		room_scale = maxf(room_scale, 0.48)
	elif kind == "shop":
		room_scale -= 0.08
	return clampf(room_scale, 0.18, 0.90)


func _music_profile_from_environment(environment: Dictionary, heat_level: int) -> Dictionary:
	var source := _copy_dict(environment.get("music_profile", {}))
	var visual := _copy_dict(environment.get("visual_context", {}))
	var security := _copy_dict(environment.get("security_profile", {}))
	var mood := str(environment.get("mood", ""))
	var theme := str(source.get("theme", ""))
	if theme.is_empty():
		theme = str(source.get("texture", ""))
	if theme.is_empty():
		theme = mood
	if theme.is_empty():
		theme = str(visual.get("scene_type", visual.get("art_key", "neon")))

	var base_safety := clampf(float(source.get("safety", _safety_from_security(security))), 0.0, 1.0)
	var effective_safety := base_safety
	var base_bpm := float(source.get("bpm", _theme_bpm(theme)))
	var bpm := clampf(base_bpm + (1.0 - base_safety) * 3.0, 58.0, 112.0)
	var palette_id := str(source.get("palette_id", _theme_texture(theme))).strip_edges()
	if palette_id.is_empty():
		palette_id = _theme_texture(theme)
	var seed := _stable_hash("%s:%s:%d" % [
		str(environment.get("archetype_id", "")),
		theme,
		_stable_hash(palette_id),
	])

	var profile := {
		"environment_id": str(environment.get("id", "")),
		"archetype_id": str(environment.get("archetype_id", "")),
		"theme": theme,
		"palette_id": palette_id,
		"authored_track_id": str(source.get("authored_track_id", "")).strip_edges(),
		"mood": mood,
		"mode": str(source.get("mode", _theme_mode(theme))).to_lower(),
		"texture": str(source.get("texture", _theme_texture(theme))),
		"texture_rate": float(source.get("texture_rate", _theme_texture_rate(theme))),
		"texture_seed": seed % 997,
		"bpm": bpm,
		"root_midi": int(source.get("root_midi", _theme_root_midi(theme))),
		"base_safety": base_safety,
		"safety": effective_safety,
		"ambience": clampf(float(source.get("ambience", _theme_ambience(theme))), 0.0, 1.0),
		"heat_pressure": 0.0,
		"heat_band": 0,
		"volume": float(source.get("volume", 0.26)),
		"arrangement_phrases": clampi(int(source.get("arrangement_phrases", DEFAULT_ARRANGEMENT_PHRASES)), MIN_ARRANGEMENT_PHRASES, MAX_ARRANGEMENT_PHRASES),
	}
	profile["progression"] = _number_array(source.get("progression", _theme_progression(theme)), _theme_progression(theme))
	profile["motif"] = _number_array(source.get("motif", _theme_motif(theme)), _theme_motif(theme))
	return profile


func _ambient_cache_key(profile: Dictionary) -> String:
	var authored_track_id := str(profile.get("authored_track_id", ""))
	return "stem:%d:%s:%s:%s:%s" % [
		AMBIENT_VERSION,
		str(profile.get("archetype_id", "")),
		str(profile.get("theme", "")),
		str(profile.get("palette_id", "")),
		authored_track_id if not authored_track_id.is_empty() else "procedural",
	]


func _ambient_music_stream(profile: Dictionary) -> AudioStreamWAV:
	var context := _ambient_generation_context(profile)
	var frames := int(context.get("frames", 0))
	var data := _ambient_pcm_data(context)
	return _ambient_stream_from_data(data, frames)


func _request_ambient_generation(profile: Dictionary, cache_key: String, token: int) -> void:
	_remember_profile(cache_key, profile)
	if _generation_thread != null:
		if _ambient_primer_cache.has(cache_key):
			_play_primer_stem_set(cache_key, _ambient_primer_cache[cache_key])
		_queued_generation_profile = profile.duplicate(true)
		_queued_generation_cache_key = cache_key
		_queued_generation_token = token
		return
	if _ambient_primer_cache.has(cache_key):
		_play_primer_stem_set(cache_key, _ambient_primer_cache[cache_key])
		_start_ambient_generation(profile, cache_key, token, AMBIENT_STAGE_FULL)
		return
	_start_ambient_generation(profile, cache_key, token, AMBIENT_STAGE_PRIMER)


func _start_ambient_generation(profile: Dictionary, cache_key: String, token: int, stage: String) -> void:
	_remember_profile(cache_key, profile)
	if _generation_thread != null:
		_queued_generation_profile = profile.duplicate(true)
		_queued_generation_cache_key = cache_key
		_queued_generation_token = token
		return
	_thread_cache_key = cache_key
	_thread_token = token
	_thread_stage = stage
	_generation_thread = Thread.new()
	var error := _generation_thread.start(Callable(self, "_generate_ambient_data_thread").bind(profile.duplicate(true), cache_key, token, stage))
	if error != OK:
		push_warning("Procedural music generation thread failed to start: %s" % str(error))
		_generation_thread = null
		_thread_cache_key = ""
		_thread_token = 0
		_thread_stage = ""
		_pending_cache_key = ""


func _generate_ambient_data_thread(profile: Dictionary, cache_key: String, token: int, stage: String) -> Dictionary:
	var context := _ambient_generation_context(profile)
	if stage == AMBIENT_STAGE_PRIMER:
		context = _primer_context(context)
	var frames := int(context.get("frames", 0))
	if _generation_was_cancelled(token):
		return {
			"cancelled": true,
			"cache_key": cache_key,
			"stage": stage,
			"token": token,
		}
	var stem_set := _procedural_stem_set_from_context(profile, context, stage, token)
	if _generation_was_cancelled(token):
		return {
			"cancelled": true,
			"cache_key": cache_key,
			"stage": stage,
			"token": token,
		}
	return {
		"cancelled": false,
		"cache_key": cache_key,
		"token": token,
		"stage": stage,
		"profile": profile,
		"frames": frames,
		"stem_set": stem_set,
	}


func _poll_generation_thread() -> void:
	if _generation_thread == null:
		return
	if _generation_thread.is_alive():
		return
	var result: Variant = _generation_thread.wait_to_finish()
	_generation_thread = null
	_thread_cache_key = ""
	_thread_token = 0
	_thread_stage = ""
	if typeof(result) == TYPE_DICTIONARY:
		_apply_generated_ambient_data(result as Dictionary)
	_start_queued_generation()


func _join_generation_thread() -> void:
	if _generation_thread == null:
		return
	_generation_thread.wait_to_finish()
	_generation_thread = null
	_thread_cache_key = ""
	_thread_token = 0
	_thread_stage = ""


func _start_queued_generation() -> void:
	if _queued_generation_cache_key.is_empty() or _queued_generation_profile.is_empty():
		return
	var profile := _queued_generation_profile.duplicate(true)
	var cache_key := _queued_generation_cache_key
	var token := _queued_generation_token
	_queued_generation_profile = {}
	_queued_generation_cache_key = ""
	_queued_generation_token = 0
	if token != _current_generation_token() or cache_key != _pending_cache_key:
		return
	if _ambient_stream_cache.has(cache_key):
		_accept_full_stem_set(cache_key, _ambient_stream_cache[cache_key])
		return
	_request_ambient_generation(profile, cache_key, token)


func _apply_generated_ambient_data(result: Dictionary) -> void:
	if bool(result.get("cancelled", false)):
		return
	var cache_key := str(result.get("cache_key", ""))
	var token := int(result.get("token", 0))
	if cache_key.is_empty() or token != _current_generation_token() or cache_key != _pending_cache_key:
		return
	var stem_set: Dictionary = result.get("stem_set", {}) as Dictionary
	if not _stem_set_contract_valid(stem_set):
		_pending_cache_key = ""
		return
	var stage := str(result.get("stage", AMBIENT_STAGE_FULL))
	if stage == AMBIENT_STAGE_PRIMER:
		_ambient_primer_cache[cache_key] = stem_set
		_play_primer_stem_set(cache_key, stem_set)
		var profile: Dictionary = result.get("profile", {})
		if profile.is_empty():
			_pending_cache_key = ""
			return
		_start_ambient_generation(profile, cache_key, token, AMBIENT_STAGE_FULL)
		return
	_ambient_stream_cache[cache_key] = stem_set
	_accept_full_stem_set(cache_key, stem_set)


func _ambient_pcm_data(context: Dictionary, token: int = -1) -> PackedByteArray:
	var frames := int(context.get("frames", 0))
	var data := PackedByteArray()
	data.resize(maxi(0, frames * PCM_BYTES_PER_FRAME))
	# Match the full stem renderer's production sampling policy while retaining
	# the preview stream's exact frame count, byte size, and loop duration.
	var render_stride := maxi(1, AMBIENT_RENDER_STRIDE_FRAMES)
	var i := 0
	while i < frames:
		if token > 0 and i % GENERATION_CANCEL_CHECK_FRAMES == 0 and _generation_was_cancelled(token):
			return PackedByteArray()
		_write_ambient_frame(data, context, i)
		var source_byte_index := i * PCM_BYTES_PER_FRAME
		var low_byte := data[source_byte_index]
		var high_byte := data[source_byte_index + 1]
		var repeat_count := mini(render_stride, frames - i)
		for repeat_index in range(1, repeat_count):
			var byte_index := (i + repeat_index) * PCM_BYTES_PER_FRAME
			data[byte_index] = low_byte
			data[byte_index + 1] = high_byte
		i += render_stride
	return data


func _procedural_stem_contract_from_context(profile: Dictionary, context: Dictionary, stage: String) -> Dictionary:
	var frames := int(context.get("frames", 0))
	var stems := {}
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		stems[role] = {
			"planned": true,
			"loop_begin": 0,
			"loop_end": frames,
			"frames": frames,
		}
	var contract := _stem_set_contract("procedural", stems, float(context.get("bpm", profile.get("bpm", 82.0))), int(context.get("bars", 1)), frames, str(profile.get("palette_id", "")), {}, stage)
	contract["step_period"] = float(context.get("step_period", 0.36))
	contract["profile"] = profile.duplicate(true)
	return contract


func _procedural_stem_set_from_context(profile: Dictionary, context: Dictionary, stage: String, token: int = -1) -> Dictionary:
	var frames := int(context.get("frames", 0))
	if frames <= 0:
		return {}
	var stem_data := _ambient_stem_pcm_data(context, token)
	if stem_data.is_empty():
		return {}
	var stems := _streams_from_stem_data(stem_data, frames)
	var contract := _stem_set_contract("procedural", stems, float(context.get("bpm", profile.get("bpm", 82.0))), int(context.get("bars", 1)), frames, str(profile.get("palette_id", "")), {}, stage)
	contract["step_period"] = float(context.get("step_period", 0.36))
	contract["profile"] = profile.duplicate(true)
	return contract


func _ambient_stem_pcm_data(context: Dictionary, token: int = -1) -> Dictionary:
	var frames := int(context.get("frames", 0))
	var pad_data := _empty_pcm(frames)
	var bass_data := _empty_pcm(frames)
	var bass_dark_data := _empty_pcm(frames)
	var lead_data := _empty_pcm(frames)
	var drums_low_data := _empty_pcm(frames)
	var drums_high_data := _empty_pcm(frames)
	var drums_high_double_data := _empty_pcm(frames)
	var tension_data := _empty_pcm(frames)
	var texture_data := _empty_pcm(frames)
	var step_period := float(context.get("step_period", 0.36))
	var beat_period := float(context.get("beat_period", 0.72))
	var phrase_steps := int(context.get("phrase_steps", BASE_PHRASE_STEPS))
	var phrase_count := int(context.get("phrase_count", DEFAULT_ARRANGEMENT_PHRASES))
	var total_steps := int(context.get("total_steps", 32))
	var duration := float(context.get("duration", step_period * float(total_steps)))
	var root_midi := int(context.get("root_midi", 45))
	var danger := float(context.get("danger", 0.5))
	var volume := float(context.get("volume", 0.22))
	var pad_gain := float(context.get("pad_gain", 0.38))
	var bass_gain := float(context.get("bass_gain", 0.20))
	var lead_gain := float(context.get("lead_gain", 0.08))
	var drum_gain := float(context.get("drum_gain", 0.07))
	var texture_gain := float(context.get("texture_gain", 0.45))
	var heartbeat_gain := float(context.get("heartbeat_gain", 0.02))
	var siren_gain := float(context.get("siren_gain", 0.0))
	var scale: Array = context.get("scale", SCALE_MINOR)
	var progression_degrees: Array = context.get("progression_degrees", DEFAULT_PROGRESSION)
	var chord_roots: Array = context.get("chord_roots", [0])
	var chord_voicings: Array = context.get("chord_voicings", [])
	var motif: Array = context.get("motif", DEFAULT_MOTIF)
	var palette: Dictionary = context.get("instrument_palette", {}) as Dictionary
	var swing_amount := float(context.get("swing_amount", 0.0))
	var answer_transform := str(context.get("answer_transform", "inversion"))
	var bridge_phrase_index := int(context.get("bridge_phrase_index", 2))
	var texture_kind := str(context.get("texture_kind", "fluorescent"))
	var texture_rate := float(context.get("texture_rate", 0.33))
	var texture_seed := int(context.get("texture_seed", 0))
	var variation_seed := int(context.get("variation_seed", texture_seed))
	var humanize_seed := int(context.get("humanize_seed", variation_seed))
	var render_stride := maxi(1, AMBIENT_RENDER_STRIDE_FRAMES)
	var i := 0
	while i < frames:
		if token > 0 and i % GENERATION_CANCEL_CHECK_FRAMES == 0 and _generation_was_cancelled(token):
			return {}
		var t := float(i) / float(SAMPLE_RATE)
		var step_index := int(t / step_period) % total_steps
		var step_local := fposmod(t, step_period)
		var phrase_index := int(step_index / phrase_steps) % maxi(1, phrase_count)
		var phrase_step := step_index % phrase_steps
		var bar_index := int(phrase_step / STEPS_PER_BAR) % maxi(1, chord_roots.size())
		var beat_step := phrase_step % STEPS_PER_BAR
		var chord_root := root_midi + int(chord_roots[bar_index])
		var chord_voicing: Array = []
		if not chord_voicings.is_empty():
			chord_voicing = chord_voicings[bar_index % chord_voicings.size()] as Array
		var phrase_energy := _phrase_energy(phrase_index, phrase_count, danger)
		var fill_amount := _phrase_fill_amount(phrase_step, phrase_index, phrase_count, phrase_energy)
		var loop_edge := _loop_edge_envelope(t, duration)
		var stem_scale := volume * loop_edge
		var pad := _music_pad_voiced(root_midi, chord_voicing, chord_root, t, palette) * pad_gain * lerpf(0.94, 1.06, phrase_energy) * stem_scale
		var bass := 0.0
		var bass_dark := 0.0
		var bass_offset := _bass_offset_for_step(scale, progression_degrees, chord_roots, bar_index, beat_step, phrase_index, phrase_count, variation_seed)
		if bass_offset > -900:
			var bass_freq := _midi_freq(root_midi + bass_offset)
			var bass_note := _music_bass(bass_freq, step_local) * bass_gain * lerpf(0.92, 1.13, phrase_energy) * _palette_value(palette, "bass_weight", 1.0)
			bass = bass_note * stem_scale
			bass_dark = _music_dark_bass(bass_freq, step_local) * bass_gain * 1.08 * lerpf(0.95, 1.18, phrase_energy) * stem_scale
		var lead := 0.0
		var lead_offset := _lead_offset_for_step(scale, progression_degrees, motif, bar_index, phrase_step, phrase_index, phrase_count, variation_seed, answer_transform, bridge_phrase_index)
		if lead_offset > -900:
			var lead_local := _swing_step_local(beat_step, step_local, step_period, swing_amount)
			var lead_velocity := _step_humanization(humanize_seed, phrase_step, phrase_index, 0.08)
			lead = _music_lead(_midi_freq(root_midi + lead_offset), lead_local, palette) * lead_gain * lerpf(0.70, 1.28, phrase_energy) * lead_velocity * stem_scale
		var drum_frame := i + texture_seed
		var drum_local := _swing_step_local(beat_step, step_local, step_period, swing_amount)
		var hat_velocity := _step_humanization(humanize_seed + 29, phrase_step, phrase_index, 0.10)
		var drums_low := _music_drums_low(beat_step, drum_local, drum_frame, phrase_index, phrase_count, variation_seed, fill_amount, palette) * drum_gain * stem_scale
		var drums_high := _music_drums_high(beat_step, drum_local, step_period, drum_frame, phrase_index, phrase_count, variation_seed, fill_amount, palette) * drum_gain * hat_velocity * stem_scale
		var drums_high_double := _music_drums_high_double(beat_step, drum_local, step_period, drum_frame + 17, phrase_index, phrase_count, variation_seed, fill_amount, palette) * drum_gain * 0.82 * hat_velocity * stem_scale
		var heartbeat := _heartbeat_shape(fposmod(t, beat_period), beat_period) * heartbeat_gain
		var siren := _music_siren(t) * siren_gain
		var tension := (heartbeat + siren) * stem_scale
		var texture := _ambient_texture_sample(texture_kind, texture_rate, t, i, texture_seed) * texture_gain * stem_scale
		var pad_sample := _soft_limit(pad)
		var bass_sample := _soft_limit(bass)
		var bass_dark_sample := _soft_limit(bass_dark)
		var lead_sample := _soft_limit(lead)
		var drums_low_sample := _soft_limit(drums_low)
		var drums_high_sample := _soft_limit(drums_high)
		var drums_high_double_sample := _soft_limit(drums_high_double)
		var tension_sample := _soft_limit(tension)
		var texture_sample := _soft_limit(texture)
		var repeat_count := mini(render_stride, frames - i)
		for repeat_index in range(repeat_count):
			var byte_index := (i + repeat_index) * PCM_BYTES_PER_FRAME
			_write_i16(pad_data, byte_index, pad_sample)
			_write_i16(bass_data, byte_index, bass_sample)
			_write_i16(bass_dark_data, byte_index, bass_dark_sample)
			_write_i16(lead_data, byte_index, lead_sample)
			_write_i16(drums_low_data, byte_index, drums_low_sample)
			_write_i16(drums_high_data, byte_index, drums_high_sample)
			_write_i16(drums_high_double_data, byte_index, drums_high_double_sample)
			_write_i16(tension_data, byte_index, tension_sample)
			_write_i16(texture_data, byte_index, texture_sample)
		i += render_stride
	return {
		"pad": pad_data,
		"bass": bass_data,
		"bass_dark": bass_dark_data,
		"lead": lead_data,
		"drums_low": drums_low_data,
		"drums_high": drums_high_data,
		"drums_high_double": drums_high_double_data,
		"tension": tension_data,
		"texture": texture_data,
	}


func _remember_profile(cache_key: String, profile: Dictionary) -> void:
	if cache_key.is_empty() or profile.is_empty():
		return
	_ambient_profile_cache[cache_key] = profile.duplicate(true)


func _should_defer_music_change(cache_key: String) -> bool:
	if cache_key.is_empty() or cache_key == _current_cache_key:
		return false
	if not _music_is_playing():
		return false
	return not _current_cache_key.is_empty()


func _schedule_breakpoint_music_change(profile: Dictionary, cache_key: String) -> void:
	if cache_key.is_empty():
		return
	_remember_profile(cache_key, profile)
	if cache_key == _transition_target_cache_key:
		if _ambient_stream_cache.has(cache_key):
			_set_deferred_transition_stem_set(cache_key, _ambient_stream_cache[cache_key])
		return
	_transition_target_cache_key = cache_key
	_transition_target_profile = profile.duplicate(true)
	_deferred_transition_cache_key = ""
	_deferred_transition_stream = null
	_deferred_transition_plan = {}
	_pending_cache_key = cache_key
	var token := _advance_generation_token()
	if _ambient_stream_cache.has(cache_key):
		_set_deferred_transition_stem_set(cache_key, _ambient_stream_cache[cache_key])
		return
	_start_ambient_generation(profile, cache_key, token, AMBIENT_STAGE_FULL)


func _accept_full_stem_set(cache_key: String, stem_set: Dictionary) -> void:
	if cache_key == _transition_target_cache_key and _should_defer_music_change(cache_key):
		_set_deferred_transition_stem_set(cache_key, stem_set)
		return
	_play_full_stem_set(cache_key, stem_set)


func _accept_authored_boundary_stem_set(cache_key: String, stem_set: Dictionary) -> void:
	_deferred_transition_cache_key = ""
	_deferred_transition_stem_set = {}
	_deferred_transition_plan = {}
	_transition_target_cache_key = ""
	_transition_target_profile = {}
	var exact_position := _authored_phrase_boundary_position if _authored_phrase_boundary_position >= 0.0 else _director_playback_position()
	if _play_full_stem_set(cache_key, stem_set, exact_position):
		_last_authored_boundary_applied_cache_key = cache_key


func _set_deferred_transition_stem_set(cache_key: String, stem_set: Dictionary) -> void:
	if not _stem_set_contract_valid(stem_set):
		return
	_deferred_transition_cache_key = cache_key
	_deferred_transition_stem_set = stem_set.duplicate(true)
	_deferred_transition_plan = _build_transition_plan(stem_set, _director_playback_position())


func _poll_breakpoint_transition() -> void:
	if _deferred_transition_cache_key.is_empty() or _deferred_transition_stem_set.is_empty():
		return
	var position := _director_playback_position()
	if not _deferred_transition_plan.is_empty():
		if not bool(_deferred_transition_plan.get("fill_started", false)) and position + TRANSITION_BREAK_WINDOW_SECONDS >= float(_deferred_transition_plan.get("fill_position", 999999.0)):
			_play_transition_fill(str(_deferred_transition_plan.get("fill_id", "")))
			_deferred_transition_plan["fill_started"] = true
		if position + TRANSITION_BREAK_WINDOW_SECONDS < float(_deferred_transition_plan.get("target_position", 0.0)):
			return
	elif not _ready_for_music_breakpoint():
		return
	var cache_key := _deferred_transition_cache_key
	var stem_set := _deferred_transition_stem_set.duplicate(true)
	var destination_time := str(_deferred_transition_plan.get("destination_time", "same_position"))
	var transition_resume_position := position if destination_time == "same_position" else 0.0
	_deferred_transition_cache_key = ""
	_deferred_transition_stream = null
	_deferred_transition_stem_set = {}
	_deferred_transition_plan = {}
	_transition_target_cache_key = ""
	_transition_target_profile = {}
	_play_full_stem_set(cache_key, stem_set, transition_resume_position)


func _build_transition_plan(destination_stem_set: Dictionary, playback_position: float) -> Dictionary:
	var transitions := _copy_dict(destination_stem_set.get("transitions", _current_stem_set.get("transitions", {})))
	var quantize := str(transitions.get("quantize", "phrase")).strip_edges().to_lower()
	var bar_seconds := _music_director_bar_seconds()
	var quantum := _music_director_step_seconds() * 2.0 if quantize == "beat" else bar_seconds
	if quantize == "phrase":
		quantum = bar_seconds * float(maxi(1, int(transitions.get("phrase_bars", 4))))
	var target_index := ceili((maxf(0.0, playback_position) + TRANSITION_BREAK_WINDOW_SECONDS) / maxf(0.001, quantum))
	var target_position := float(maxi(1, target_index)) * quantum
	var fill_id := str(transitions.get("fill_id", transitions.get("default_fill", ""))).strip_edges()
	var fill_bars := clampf(float(transitions.get("fill_bars", 0.0)), 0.0, 4.0)
	return {
		"quantize": quantize,
		"quantum_seconds": snappedf(quantum, 0.0001),
		"target_position": snappedf(target_position, 0.0001),
		"destination_time": str(transitions.get("destination_time", "same_position")),
		"fade_beats": maxf(0.0, float(transitions.get("fade_beats", 0.25))),
		"fill_id": fill_id,
		"fill_position": snappedf(maxf(playback_position, target_position - fill_bars * bar_seconds), 0.0001) if not fill_id.is_empty() else 999999.0,
		"fill_started": fill_id.is_empty(),
	}


func _play_transition_fill(fill_id: String) -> void:
	if fill_id.is_empty():
		return
	var fills := _copy_dict(_current_stem_set.get("fills", {}))
	if not fills.has(fill_id):
		fills = _copy_dict(_deferred_transition_stem_set.get("fills", {}))
	var stream: AudioStream = fills.get(fill_id, null)
	if stream == null:
		return
	_ensure_feature_stinger_players()
	for player_value in _feature_stinger_players:
		if player_value is AudioStreamPlayer and not (player_value as AudioStreamPlayer).playing:
			var player := player_value as AudioStreamPlayer
			player.stream = stream
			player.volume_db = -1.5
			_play_audio_player(player)
			return


func _ready_for_music_breakpoint() -> bool:
	if not _music_is_playing():
		return true
	if _current_music_context.is_empty():
		return true
	var step_period := float(_current_music_context.get("step_period", 0.36))
	var break_period := maxf(0.25, step_period * float(TRANSITION_BREAK_STEPS))
	var position := _director_playback_position()
	var phase := fposmod(position, break_period)
	return phase <= TRANSITION_BREAK_WINDOW_SECONDS or phase >= break_period - TRANSITION_BREAK_WINDOW_SECONDS


func _remember_current_music_context(cache_key: String) -> void:
	var profile: Dictionary = _ambient_profile_cache.get(cache_key, {})
	if profile.is_empty():
		_current_music_context = {}
		return
	_current_music_context = _ambient_generation_context(profile)


func _play_instant_stem_bed(profile: Dictionary, cache_key: String) -> void:
	if _stem_players.is_empty():
		return
	if WebAudioBridgeScript.available():
		if not _web_music_bed_cache.has(cache_key):
			_web_music_bed_cache[cache_key] = _web_music_bed_stem_set(profile, WEB_AUDIO_MUSIC_BED_SECONDS, "web_full")
		_play_primer_stem_set(cache_key, _web_music_bed_cache[cache_key])
		return
	if not _ambient_instant_cache.has(cache_key):
		_ambient_instant_cache[cache_key] = _instant_bed_stem_set(profile)
	_play_primer_stem_set(cache_key, _ambient_instant_cache[cache_key])


func _play_web_full_bed(profile: Dictionary, cache_key: String) -> void:
	if _stem_players.is_empty() or not WebAudioBridgeScript.available():
		return
	_pending_cache_key = ""
	_queued_generation_profile = {}
	_queued_generation_cache_key = ""
	_queued_generation_token = 0
	_advance_generation_token()
	if not _web_music_bed_cache.has(cache_key):
		_web_music_bed_cache[cache_key] = _web_music_bed_stem_set(profile, WEB_AUDIO_MUSIC_BED_SECONDS, "web_full")
	var stem_set: Dictionary = _web_music_bed_cache.get(cache_key, {}) as Dictionary
	if not _stem_set_contract_valid(stem_set):
		return
	_current_cache_key = cache_key
	_current_stream_is_primer = false
	_remember_current_music_context(cache_key)
	_play_stem_set(stem_set, 0.0, AMBIENT_STAGE_FULL)


func _instant_bed_stream(profile: Dictionary) -> AudioStreamWAV:
	var context := _ambient_generation_context(profile)
	var frames := maxi(1, int(INSTANT_BED_SECONDS * float(SAMPLE_RATE)))
	var data := _instant_bed_pcm_data(context, frames)
	return _ambient_stream_from_data(data, frames)


func _instant_bed_stem_set(profile: Dictionary) -> Dictionary:
	var context := _ambient_generation_context(profile)
	var frames := maxi(1, int(INSTANT_BED_SECONDS * float(SAMPLE_RATE)))
	var stem_data := _instant_bed_stem_pcm_data(context, frames)
	var stems := _streams_from_stem_data(stem_data, frames)
	var contract := _stem_set_contract("procedural", stems, float(context.get("bpm", profile.get("bpm", 82.0))), 1, frames, str(profile.get("palette_id", "")), {}, AMBIENT_STAGE_PRIMER)
	contract["step_period"] = float(context.get("step_period", 0.36))
	contract["profile"] = profile.duplicate(true)
	return contract


func _web_music_bed_stem_set(profile: Dictionary, seconds: float = WEB_AUDIO_MUSIC_BED_SECONDS, source_id: String = "web_compact") -> Dictionary:
	var context := _ambient_generation_context(profile)
	var sample_rate := maxi(1, WEB_AUDIO_MUSIC_BED_SAMPLE_RATE)
	var safe_seconds := _web_music_bed_duration_seconds(context, seconds)
	var frames := maxi(1, int(safe_seconds * float(sample_rate)))
	var data := _web_music_bed_pcm_data(context, frames, sample_rate)
	var stems := {
		"pad": _ambient_stream_from_data_with_rate(data, frames, sample_rate),
	}
	var step_period := float(context.get("step_period", 0.36))
	var bars := maxi(1, int(ceil(safe_seconds / maxf(step_period * float(STEPS_PER_BAR), 0.001))))
	var contract := _stem_set_contract(source_id, stems, float(context.get("bpm", profile.get("bpm", 82.0))), bars, frames, str(profile.get("palette_id", "")), {}, AMBIENT_STAGE_PRIMER)
	contract["step_period"] = step_period
	contract["profile"] = profile.duplicate(true)
	contract["sample_rate"] = sample_rate
	contract["track_id"] = "%s_%s_%s" % [source_id, str(profile.get("archetype_id", "environment")), str(profile.get("palette_id", ""))]
	contract["web_bridge_bed"] = true
	return contract


static func _web_music_bed_duration_seconds(context: Dictionary, requested_seconds: float = WEB_AUDIO_MUSIC_BED_SECONDS) -> float:
	var cap_seconds := maxf(1.0, WEB_AUDIO_MUSIC_BED_SECONDS)
	var target_seconds := clampf(requested_seconds, 1.0, cap_seconds)
	var cycle_seconds := maxf(1.0, float(context.get("duration", target_seconds)))
	if cycle_seconds >= cap_seconds:
		return cap_seconds
	var cycle_count := maxi(1, int(floor(target_seconds / cycle_seconds)))
	return clampf(cycle_seconds * float(cycle_count), 1.0, cap_seconds)


func _web_music_bed_pcm_data(context: Dictionary, frames: int, sample_rate: int) -> PackedByteArray:
	var data := _empty_pcm(frames)
	var safe_rate := maxi(1, sample_rate)
	var step_period := float(context.get("step_period", 0.36))
	var beat_period := float(context.get("beat_period", 0.72))
	var phrase_steps := maxi(1, int(context.get("phrase_steps", BASE_PHRASE_STEPS)))
	var phrase_count := maxi(1, int(context.get("phrase_count", DEFAULT_ARRANGEMENT_PHRASES)))
	var duration := float(frames) / float(safe_rate)
	var total_steps := maxi(1, int(ceil(duration / maxf(step_period, 0.001))))
	var root_midi := int(context.get("root_midi", 45))
	var danger := float(context.get("danger", 0.5))
	var volume := float(context.get("volume", 0.22)) * 0.92
	var pad_gain := float(context.get("pad_gain", 0.38))
	var bass_gain := float(context.get("bass_gain", 0.20)) * 0.82
	var lead_gain := float(context.get("lead_gain", 0.08)) * 0.72
	var drum_gain := float(context.get("drum_gain", 0.07)) * 0.58
	var texture_gain := float(context.get("texture_gain", 0.45)) * 0.68
	var heartbeat_gain := float(context.get("heartbeat_gain", 0.02))
	var siren_gain := float(context.get("siren_gain", 0.0))
	var scale: Array = context.get("scale", SCALE_MINOR)
	var progression_degrees: Array = context.get("progression_degrees", DEFAULT_PROGRESSION)
	var chord_roots: Array = context.get("chord_roots", [0])
	var chord_voicings: Array = context.get("chord_voicings", [])
	var motif: Array = context.get("motif", DEFAULT_MOTIF)
	var palette: Dictionary = context.get("instrument_palette", {}) as Dictionary
	var swing_amount := float(context.get("swing_amount", 0.0))
	var answer_transform := str(context.get("answer_transform", "inversion"))
	var bridge_phrase_index := int(context.get("bridge_phrase_index", 2))
	var texture_kind := str(context.get("texture_kind", "fluorescent"))
	var texture_rate := float(context.get("texture_rate", 0.33))
	var texture_seed := int(context.get("texture_seed", 0))
	var variation_seed := int(context.get("variation_seed", texture_seed))
	var humanize_seed := int(context.get("humanize_seed", variation_seed))
	for i in range(frames):
		var t := float(i) / float(safe_rate)
		var step_index := int(t / step_period) % total_steps
		var step_local := fposmod(t, step_period)
		var phrase_index := int(step_index / phrase_steps) % phrase_count
		var phrase_step := step_index % phrase_steps
		var bar_index := int(phrase_step / STEPS_PER_BAR) % maxi(1, chord_roots.size())
		var beat_step := phrase_step % STEPS_PER_BAR
		var chord_root := root_midi + int(chord_roots[bar_index])
		var chord_voicing: Array = []
		if not chord_voicings.is_empty():
			chord_voicing = chord_voicings[bar_index % chord_voicings.size()] as Array
		var phrase_energy := _phrase_energy(phrase_index, phrase_count, danger)
		var fill_amount := _phrase_fill_amount(phrase_step, phrase_index, phrase_count, phrase_energy) * 0.5
		var loop_edge := _loop_edge_envelope(t, duration)
		var pad := _music_pad_voiced(root_midi, chord_voicing, chord_root, t, palette) * pad_gain * lerpf(0.94, 1.06, phrase_energy)
		var bass := 0.0
		var bass_offset := _bass_offset_for_step(scale, progression_degrees, chord_roots, bar_index, beat_step, phrase_index, phrase_count, variation_seed)
		if bass_offset > -900:
			bass = _music_bass(_midi_freq(root_midi + bass_offset), step_local) * bass_gain * lerpf(0.92, 1.13, phrase_energy) * _palette_value(palette, "bass_weight", 1.0)
		var lead := 0.0
		var lead_offset := _lead_offset_for_step(scale, progression_degrees, motif, bar_index, phrase_step, phrase_index, phrase_count, variation_seed, answer_transform, bridge_phrase_index)
		if lead_offset > -900:
			var lead_local := _swing_step_local(beat_step, step_local, step_period, swing_amount)
			lead = _music_lead(_midi_freq(root_midi + lead_offset), lead_local, palette) * lead_gain * lerpf(0.70, 1.28, phrase_energy) * _step_humanization(humanize_seed, phrase_step, phrase_index, 0.08)
		var drum_local := _swing_step_local(beat_step, step_local, step_period, swing_amount)
		var drums := _music_drums(beat_step, drum_local, step_period, i + texture_seed, phrase_index, phrase_count, variation_seed, fill_amount, palette) * drum_gain * _step_humanization(humanize_seed + 29, phrase_step, phrase_index, 0.10)
		var heartbeat := _heartbeat_shape(fposmod(t, beat_period), beat_period) * heartbeat_gain
		var siren := _music_siren(t) * siren_gain
		var texture := _ambient_texture_sample(texture_kind, texture_rate, t, i, texture_seed) * texture_gain
		var mixed := (pad + bass + lead + drums + heartbeat + siren + texture) * volume * loop_edge
		_write_i16(data, i * PCM_BYTES_PER_FRAME, _soft_limit(mixed))
	return data


func _web_music_mixdown_stem_set(profile: Dictionary, source_stem_set: Dictionary) -> Dictionary:
	if not _stem_set_contract_valid(source_stem_set):
		return {}
	var source_sample_rate := _stem_set_source_sample_rate(source_stem_set)
	var source_loop_frames := int(source_stem_set.get("loop_frames", 0))
	var source_seconds := float(source_loop_frames) / float(source_sample_rate)
	if source_seconds <= 0.0:
		return {}
	var sample_rate := maxi(1, WEB_AUDIO_MUSIC_BED_SAMPLE_RATE)
	var max_frames := maxi(1, int(WEB_AUDIO_MUSIC_STEM_MAX_PCM_BYTES / PCM_BYTES_PER_FRAME))
	var target_seconds := clampf(source_seconds, 1.0, WEB_AUDIO_MUSIC_BED_SECONDS)
	var frames := mini(max_frames, maxi(1, int(target_seconds * float(sample_rate))))
	var data := _web_music_mixdown_pcm_data(source_stem_set, frames, sample_rate)
	var stems := {
		"pad": _ambient_stream_from_data_with_rate(data, frames, sample_rate),
	}
	var bpm := float(source_stem_set.get("bpm", profile.get("bpm", 82.0)))
	var step_period := _step_period_from_bpm(bpm)
	var bars := maxi(1, int(ceil((float(frames) / float(sample_rate)) / maxf(step_period * float(STEPS_PER_BAR), 0.001))))
	var contract := _stem_set_contract("web_mixdown", stems, bpm, bars, frames, str(source_stem_set.get("palette_id", profile.get("palette_id", ""))), {}, AMBIENT_STAGE_PRIMER)
	contract["step_period"] = step_period
	contract["profile"] = profile.duplicate(true)
	contract["sample_rate"] = sample_rate
	contract["track_id"] = "web_mixdown_%s_%s_%s" % [
		str(profile.get("archetype_id", "environment")),
		str(source_stem_set.get("source", "")),
		str(source_stem_set.get("palette_id", profile.get("palette_id", ""))),
	]
	contract["web_bridge_bed"] = true
	contract["web_bridge_mixdown"] = true
	return contract


func _web_music_mixdown_pcm_data(source_stem_set: Dictionary, frames: int, sample_rate: int) -> PackedByteArray:
	var data := _empty_pcm(frames)
	var stems_value: Variant = source_stem_set.get("stems", {})
	if typeof(stems_value) != TYPE_DICTIONARY:
		return data
	var stems: Dictionary = stems_value
	var safe_rate := maxi(1, sample_rate)
	for i in range(frames):
		var t := float(i) / float(safe_rate)
		var mixed := 0.0
		var total_weight := 0.0
		for role_value in MUSIC_STEM_PLAYBACK_ROLES:
			var role := str(role_value)
			var stream_value: Variant = stems.get(role, null)
			if not (stream_value is AudioStreamWAV):
				continue
			var weight := float(WEB_MIXDOWN_ROLE_WEIGHTS.get(role, 0.0))
			if weight <= 0.0:
				continue
			mixed += _wav_sample_mono_at_time(stream_value as AudioStreamWAV, t) * weight
			total_weight += weight
		if total_weight > 1.25:
			mixed /= total_weight * 0.82
		_write_i16(data, i * PCM_BYTES_PER_FRAME, _soft_limit(mixed * 0.84))
	return data


func _stem_set_source_sample_rate(stem_set: Dictionary) -> int:
	var explicit_rate := int(stem_set.get("sample_rate", 0))
	if explicit_rate > 0:
		return explicit_rate
	var stems_value: Variant = stem_set.get("stems", {})
	if typeof(stems_value) == TYPE_DICTIONARY:
		var stems: Dictionary = stems_value
		for role_value in MUSIC_STEM_PLAYBACK_ROLES:
			var stream_value: Variant = stems.get(str(role_value), null)
			if stream_value is AudioStreamWAV:
				return maxi(1, (stream_value as AudioStreamWAV).mix_rate)
	return SAMPLE_RATE


func _wav_sample_mono_at_time(wav: AudioStreamWAV, time_seconds: float) -> float:
	return _wav_sample_mono_at_frame(wav, maxf(0.0, time_seconds) * float(maxi(1, wav.mix_rate)))


func _wav_sample_mono_at_frame(wav: AudioStreamWAV, frame_position: float) -> float:
	var frame_count := _wav_frame_count(wav)
	if frame_count <= 0:
		return 0.0
	var loop_begin := clampi(int(wav.loop_begin), 0, maxi(0, frame_count - 1))
	var loop_end := int(wav.loop_end)
	if loop_end <= loop_begin:
		loop_end = frame_count
	loop_end = clampi(loop_end, loop_begin + 1, frame_count)
	var loop_length := maxi(1, loop_end - loop_begin)
	var local_position := fposmod(frame_position - float(loop_begin), float(loop_length)) + float(loop_begin)
	var frame_a := clampi(int(floor(local_position)), loop_begin, loop_end - 1)
	var frame_b := frame_a + 1
	if frame_b >= loop_end:
		frame_b = loop_begin
	var blend := clampf(local_position - floor(local_position), 0.0, 1.0)
	return lerpf(_wav_frame_mono_sample(wav, frame_a), _wav_frame_mono_sample(wav, frame_b), blend)


func _wav_frame_count(wav: AudioStreamWAV) -> int:
	var channels := 2 if wav.stereo else 1
	return int(wav.data.size() / maxi(1, channels * PCM_BYTES_PER_FRAME))


func _wav_frame_mono_sample(wav: AudioStreamWAV, frame_index: int) -> float:
	var channels := 2 if wav.stereo else 1
	var byte_index := frame_index * channels * PCM_BYTES_PER_FRAME
	var left := _read_i16_float(wav.data, byte_index)
	if channels <= 1:
		return left
	var right := _read_i16_float(wav.data, byte_index + PCM_BYTES_PER_FRAME)
	return (left + right) * 0.5


func _read_i16_float(data: PackedByteArray, byte_index: int) -> float:
	if byte_index < 0 or byte_index + 1 >= data.size():
		return 0.0
	var sample := int(data[byte_index]) | (int(data[byte_index + 1]) << 8)
	if sample >= 32768:
		sample -= 65536
	return clampf(float(sample) / 32768.0, -1.0, 1.0)


func _instant_bed_pcm_data(context: Dictionary, frames: int) -> PackedByteArray:
	var root_midi := int(context.get("root_midi", 45))
	var chord_roots: Array = context.get("chord_roots", [0])
	var chord_voicings: Array = context.get("chord_voicings", [])
	var palette: Dictionary = context.get("instrument_palette", {}) as Dictionary
	var chord_root := root_midi
	if not chord_roots.is_empty():
		chord_root += int(chord_roots[0])
	var chord_voicing: Array = []
	if not chord_voicings.is_empty():
		chord_voicing = chord_voicings[0] as Array
	var volume := float(context.get("volume", 0.22)) * 0.82
	var pad_gain := float(context.get("pad_gain", 0.38))
	var texture_gain := float(context.get("texture_gain", 0.45)) * 0.72
	var texture_kind := str(context.get("texture_kind", "fluorescent"))
	var texture_rate := float(context.get("texture_rate", 0.33))
	var texture_seed := int(context.get("texture_seed", 0))
	var data := PackedByteArray()
	data.resize(maxi(0, frames * PCM_BYTES_PER_FRAME))
	for i in range(frames):
		var t := float(i) / float(SAMPLE_RATE)
		var loop_edge := _loop_edge_envelope(t, INSTANT_BED_SECONDS)
		var pad := _music_pad_voiced(root_midi, chord_voicing, chord_root, t, palette) * pad_gain
		var texture := _ambient_texture_sample(texture_kind, texture_rate, t, i, texture_seed) * texture_gain
		_write_i16(data, i * PCM_BYTES_PER_FRAME, _soft_limit((pad + texture) * volume * loop_edge))
	return data


func _instant_bed_stem_pcm_data(context: Dictionary, frames: int) -> Dictionary:
	var root_midi := int(context.get("root_midi", 45))
	var chord_roots: Array = context.get("chord_roots", [0])
	var chord_voicings: Array = context.get("chord_voicings", [])
	var palette: Dictionary = context.get("instrument_palette", {}) as Dictionary
	var chord_root := root_midi
	if not chord_roots.is_empty():
		chord_root += int(chord_roots[0])
	var chord_voicing: Array = []
	if not chord_voicings.is_empty():
		chord_voicing = chord_voicings[0] as Array
	var volume := float(context.get("volume", 0.22)) * 0.82
	var pad_gain := float(context.get("pad_gain", 0.38))
	var texture_gain := float(context.get("texture_gain", 0.45)) * 0.72
	var texture_kind := str(context.get("texture_kind", "fluorescent"))
	var texture_rate := float(context.get("texture_rate", 0.33))
	var texture_seed := int(context.get("texture_seed", 0))
	var pad_data := _empty_pcm(frames)
	var texture_data := _empty_pcm(frames)
	for i in range(frames):
		var t := float(i) / float(SAMPLE_RATE)
		var loop_edge := _loop_edge_envelope(t, INSTANT_BED_SECONDS)
		var pad := _music_pad_voiced(root_midi, chord_voicing, chord_root, t, palette) * pad_gain * volume * loop_edge
		var texture := _ambient_texture_sample(texture_kind, texture_rate, t, i, texture_seed) * texture_gain * volume * loop_edge
		_write_i16(pad_data, i * PCM_BYTES_PER_FRAME, _soft_limit(pad))
		_write_i16(texture_data, i * PCM_BYTES_PER_FRAME, _soft_limit(texture))
	return {
		"pad": pad_data,
		"texture": texture_data,
	}


func _primer_context(context: Dictionary) -> Dictionary:
	var primer := context.duplicate(true)
	var step_period := float(primer.get("step_period", 0.36))
	var full_frames := int(primer.get("frames", 0))
	var primer_frames := mini(full_frames, maxi(1, int(step_period * float(PRIMER_STEPS) * float(SAMPLE_RATE))))
	primer["frames"] = primer_frames
	primer["duration"] = float(primer_frames) / float(SAMPLE_RATE)
	return primer


func _play_primer_stem_set(cache_key: String, stem_set: Dictionary) -> void:
	if _stem_players.is_empty() or not _stem_set_contract_valid(stem_set):
		return
	_current_cache_key = cache_key
	_current_stream_is_primer = true
	_remember_current_music_context(cache_key)
	_play_stem_set(stem_set, 0.0, AMBIENT_STAGE_PRIMER)


func _play_full_stem_set(cache_key: String, stem_set: Dictionary, resume_position_override: float = -1.0) -> bool:
	_pending_cache_key = ""
	var resume_position := maxf(0.0, resume_position_override) if resume_position_override >= 0.0 else 0.0
	if resume_position_override < 0.0 and _music_is_playing() and _current_cache_key == cache_key and _current_stream_is_primer:
		resume_position = maxf(0.0, _director_playback_position())
	if _stem_players.is_empty() or not _stem_set_contract_valid(stem_set):
		return false
	_current_cache_key = cache_key
	_current_stream_is_primer = false
	_remember_current_music_context(cache_key)
	_play_stem_set(stem_set, resume_position, AMBIENT_STAGE_FULL)
	_play_web_music_bed_for_cache(cache_key, resume_position, stem_set)
	return true


func _play_web_music_bed_for_cache(cache_key: String, resume_position: float, source_stem_set: Dictionary = {}) -> void:
	if not WebAudioBridgeScript.available() or cache_key.is_empty():
		return
	var profile: Dictionary = _ambient_profile_cache.get(cache_key, {}) as Dictionary
	if profile.is_empty():
		return
	if not source_stem_set.is_empty() and str(source_stem_set.get("source", "")) == "authored":
		var cached_source := ""
		if _web_music_bed_cache.has(cache_key):
			var cached_stem_set: Dictionary = _web_music_bed_cache.get(cache_key, {}) as Dictionary
			cached_source = str(cached_stem_set.get("source", ""))
		if cached_source != "web_mixdown":
			var mixdown := _web_music_mixdown_stem_set(profile, source_stem_set)
			if not mixdown.is_empty():
				_web_music_bed_cache[cache_key] = mixdown
	if not _web_music_bed_cache.has(cache_key):
		_web_music_bed_cache[cache_key] = _web_music_bed_stem_set(profile, WEB_AUDIO_MUSIC_BED_SECONDS, "web_full")
	var stem_set: Dictionary = _web_music_bed_cache.get(cache_key, {}) as Dictionary
	if not _stem_set_contract_valid(stem_set):
		return
	var role_volumes := _music_role_volume_db_map(_music_mix_live if not _music_mix_live.is_empty() else _neutral_music_mix_vector())
	_play_web_music_stems_if_needed(cache_key, stem_set, role_volumes, maxf(0.0, resume_position))


func _advance_generation_token() -> int:
	_generation_mutex.lock()
	_generation_token += 1
	var token := _generation_token
	_generation_mutex.unlock()
	return token


func _current_generation_token() -> int:
	_generation_mutex.lock()
	var token := _generation_token
	_generation_mutex.unlock()
	return token


func _generation_was_cancelled(token: int) -> bool:
	return token != _current_generation_token()


func _ambient_generation_context(profile: Dictionary) -> Dictionary:
	var bpm := float(profile.get("bpm", 82.0))
	var beat_period := 60.0 / bpm
	var step_period := beat_period * 0.5
	var phrase_steps := BASE_PHRASE_STEPS
	var phrase_count := clampi(int(profile.get("arrangement_phrases", DEFAULT_ARRANGEMENT_PHRASES)), MIN_ARRANGEMENT_PHRASES, MAX_ARRANGEMENT_PHRASES)
	var total_steps := phrase_steps * phrase_count
	var duration := step_period * float(total_steps)
	var frames := int(duration * SAMPLE_RATE)
	var root_midi := int(profile.get("root_midi", 45))
	var safety := clampf(float(profile.get("safety", 0.5)), 0.0, 1.0)
	var ambience := clampf(float(profile.get("ambience", 0.7)), 0.0, 1.0)
	var heat_pressure := clampf(float(profile.get("heat_pressure", 0.0)), 0.0, 1.0)
	var danger := 1.0 - safety
	var volume := float(profile.get("volume", 0.26)) * lerpf(0.82, 1.0, ambience)
	var pad_gain := lerpf(0.34, 0.50, ambience) * lerpf(0.96, 1.08, safety)
	var bass_gain := lerpf(0.16, 0.29, danger)
	var lead_gain := lerpf(0.055, 0.12, safety) * lerpf(1.0, 0.74, ambience)
	var drum_gain := lerpf(0.052, 0.115, danger) * lerpf(1.0, 0.68, ambience)
	var texture_gain := lerpf(0.34, 0.78, ambience)
	var heartbeat_gain := lerpf(0.010, 0.034, danger) + heat_pressure * 0.018
	var siren_gain := clampf((heat_pressure - 0.52) / 0.48, 0.0, 1.0) * 0.020
	var mode := str(profile.get("mode", "minor")).to_lower()
	var scale := _mode_scale(mode)
	var progression := _degree_array(profile.get("progression", DEFAULT_PROGRESSION), DEFAULT_PROGRESSION)
	var motif := _number_array(profile.get("motif", DEFAULT_MOTIF), DEFAULT_MOTIF)
	var harmony := _harmony_plan(scale, progression)
	var texture_kind := str(profile.get("texture", "fluorescent"))
	var texture_rate := float(profile.get("texture_rate", 0.33))
	var texture_seed := int(profile.get("texture_seed", 0))
	var variation_seed := int(profile.get("texture_seed", 0)) + _stable_hash("%s:%s" % [str(profile.get("theme", "")), str(profile.get("palette_id", ""))]) % 4099
	var theme := str(profile.get("theme", texture_kind))
	var palette := _theme_instrument_palette(theme)
	var swing_amount := clampf(float(profile.get("swing_amount", _theme_swing_amount(theme))), 0.0, 0.22)
	return {
		"bpm": bpm,
		"beat_period": beat_period,
		"step_period": step_period,
		"phrase_steps": phrase_steps,
		"phrase_count": phrase_count,
		"bars": maxi(1, int(ceil(float(total_steps) / float(STEPS_PER_BAR)))),
		"total_steps": total_steps,
		"duration": duration,
		"frames": frames,
		"root_midi": root_midi,
		"safety": safety,
		"danger": danger,
		"volume": volume,
		"pad_gain": pad_gain,
		"bass_gain": bass_gain,
		"lead_gain": lead_gain,
		"drum_gain": drum_gain,
		"texture_gain": texture_gain,
		"heartbeat_gain": heartbeat_gain,
		"siren_gain": siren_gain,
		"mode": mode,
		"scale": scale,
		"progression_degrees": progression,
		"chord_roots": harmony.get("roots", []),
		"chord_intervals": harmony.get("intervals", []),
		"chord_voicings": harmony.get("voicings", []),
		"voicing_inversions": harmony.get("inversions", []),
		"motif": motif,
		"arrangement_form": "AABA",
		"bridge_phrase_index": mini(2, maxi(0, phrase_count - 1)),
		"answer_transform": "inversion" if int(abs(variation_seed)) % 2 == 0 else "transposition",
		"swing_amount": swing_amount,
		"humanize_seed": variation_seed + 193,
		"instrument_palette": palette,
		"palette_id": str(palette.get("id", profile.get("palette_id", ""))),
		"texture_kind": texture_kind,
		"texture_rate": texture_rate,
		"texture_seed": texture_seed,
		"variation_seed": variation_seed,
	}


func _write_ambient_frame(data: PackedByteArray, context: Dictionary, frame_index: int) -> void:
	var step_period := float(context.get("step_period", 0.36))
	var beat_period := float(context.get("beat_period", 0.72))
	var phrase_steps := int(context.get("phrase_steps", BASE_PHRASE_STEPS))
	var phrase_count := int(context.get("phrase_count", DEFAULT_ARRANGEMENT_PHRASES))
	var total_steps := int(context.get("total_steps", 32))
	var duration := float(context.get("duration", step_period * float(total_steps)))
	var root_midi := int(context.get("root_midi", 45))
	var danger := float(context.get("danger", 0.5))
	var volume := float(context.get("volume", 0.22))
	var pad_gain := float(context.get("pad_gain", 0.38))
	var bass_gain := float(context.get("bass_gain", 0.20))
	var lead_gain := float(context.get("lead_gain", 0.08))
	var drum_gain := float(context.get("drum_gain", 0.07))
	var texture_gain := float(context.get("texture_gain", 0.45))
	var heartbeat_gain := float(context.get("heartbeat_gain", 0.02))
	var siren_gain := float(context.get("siren_gain", 0.0))
	var scale: Array = context.get("scale", SCALE_MINOR)
	var progression_degrees: Array = context.get("progression_degrees", DEFAULT_PROGRESSION)
	var chord_roots: Array = context.get("chord_roots", [0])
	var chord_voicings: Array = context.get("chord_voicings", [])
	var motif: Array = context.get("motif", DEFAULT_MOTIF)
	var palette: Dictionary = context.get("instrument_palette", {}) as Dictionary
	var swing_amount := float(context.get("swing_amount", 0.0))
	var answer_transform := str(context.get("answer_transform", "inversion"))
	var bridge_phrase_index := int(context.get("bridge_phrase_index", 2))
	var texture_kind := str(context.get("texture_kind", "fluorescent"))
	var texture_rate := float(context.get("texture_rate", 0.33))
	var texture_seed := int(context.get("texture_seed", 0))
	var variation_seed := int(context.get("variation_seed", texture_seed))
	var humanize_seed := int(context.get("humanize_seed", variation_seed))
	var t := float(frame_index) / float(SAMPLE_RATE)
	var step_index := int(t / step_period) % total_steps
	var step_local := fposmod(t, step_period)
	var phrase_index := int(step_index / phrase_steps) % maxi(1, phrase_count)
	var phrase_step := step_index % phrase_steps
	var bar_index := int(phrase_step / 8) % maxi(1, chord_roots.size())
	var beat_step := phrase_step % 8
	var chord_root := root_midi + int(chord_roots[bar_index])
	var chord_voicing: Array = []
	if not chord_voicings.is_empty():
		chord_voicing = chord_voicings[bar_index % chord_voicings.size()] as Array
	var phrase_energy := _phrase_energy(phrase_index, phrase_count, danger)
	var fill_amount := _phrase_fill_amount(phrase_step, phrase_index, phrase_count, phrase_energy)
	var pad := _music_pad_voiced(root_midi, chord_voicing, chord_root, t, palette) * pad_gain * lerpf(0.94, 1.06, phrase_energy)
	var bass := 0.0
	var bass_offset := _bass_offset_for_step(scale, progression_degrees, chord_roots, bar_index, beat_step, phrase_index, phrase_count, variation_seed)
	if bass_offset > -900:
		bass = _music_bass(_midi_freq(root_midi + bass_offset), step_local) * bass_gain * lerpf(0.92, 1.13, phrase_energy) * _palette_value(palette, "bass_weight", 1.0)
	var lead := 0.0
	var lead_offset := _lead_offset_for_step(scale, progression_degrees, motif, bar_index, phrase_step, phrase_index, phrase_count, variation_seed, answer_transform, bridge_phrase_index)
	if lead_offset > -900:
		var lead_local := _swing_step_local(beat_step, step_local, step_period, swing_amount)
		lead = _music_lead(_midi_freq(root_midi + lead_offset), lead_local, palette) * lead_gain * lerpf(0.70, 1.28, phrase_energy) * _step_humanization(humanize_seed, phrase_step, phrase_index, 0.08)
	var drum_local := _swing_step_local(beat_step, step_local, step_period, swing_amount)
	var drums := _music_drums(beat_step, drum_local, step_period, frame_index + texture_seed, phrase_index, phrase_count, variation_seed, fill_amount, palette) * drum_gain * _step_humanization(humanize_seed + 29, phrase_step, phrase_index, 0.10)
	var heartbeat := _heartbeat_shape(fposmod(t, beat_period), beat_period) * heartbeat_gain
	var texture := _ambient_texture_sample(texture_kind, texture_rate, t, frame_index, texture_seed) * texture_gain
	var siren := _music_siren(t) * siren_gain
	var loop_edge := _loop_edge_envelope(t, duration)
	var mixed := (pad + bass + lead + drums + heartbeat + texture + siren) * volume * loop_edge
	_write_i16(data, frame_index * PCM_BYTES_PER_FRAME, _soft_limit(mixed))


func _ambient_stream_from_data(data: PackedByteArray, frames: int) -> AudioStreamWAV:
	return _ambient_stream_from_data_with_rate(data, frames, SAMPLE_RATE)


func _ambient_stream_from_data_with_rate(data: PackedByteArray, frames: int, sample_rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = maxi(1, sample_rate)
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	return stream


func _empty_pcm(frames: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(maxi(0, frames * PCM_BYTES_PER_FRAME))
	return data


func _streams_from_stem_data(stem_data: Dictionary, frames: int) -> Dictionary:
	var stems := {}
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		var data: PackedByteArray = stem_data.get(role, PackedByteArray())
		if data.is_empty():
			data = _empty_pcm(frames)
		stems[role] = _ambient_stream_from_data(data, frames)
	return stems


func _feature_stem_set_for_input(input: Dictionary) -> Dictionary:
	var cue_id := str(input.get("cue_id", "feature_music"))
	var base_profile: Dictionary = _current_stem_set.get("profile", {}) as Dictionary
	var bpm := float(_current_stem_set.get("bpm", base_profile.get("bpm", 96.0)))
	if bpm <= 1.0:
		bpm = 96.0
	var style := _feature_music_style(cue_id)
	var palette_id := "%s_feature" % style
	var cache_key := "feature:%d:%s:%s:%0.2f" % [AMBIENT_VERSION, cue_id, str(base_profile.get("palette_id", "")), bpm]
	if _feature_stem_cache.has(cache_key):
		return (_feature_stem_cache.get(cache_key, {}) as Dictionary).duplicate(true)
	var bars := 2
	var step_period := _step_period_from_bpm(bpm)
	var frames := maxi(1, int(step_period * float(STEPS_PER_BAR * bars) * float(SAMPLE_RATE)))
	var root_midi := int(base_profile.get("root_midi", 45))
	if root_midi <= 0:
		root_midi = 43 if style == "buffalo" else 52
	var stem_data := _feature_stem_pcm_data(style, root_midi, bpm, frames, bars)
	var stems := _streams_from_stem_data(stem_data, frames)
	var stingers := _feature_stinger_streams_for_style(style, bpm)
	var contract := _stem_set_contract("procedural", stems, bpm, bars, frames, palette_id, stingers, AMBIENT_STAGE_FULL)
	contract["step_period"] = step_period
	contract["profile"] = {
		"theme": str(base_profile.get("theme", style)),
		"palette_id": palette_id,
		"root_midi": root_midi,
	}
	_feature_stem_cache[cache_key] = contract.duplicate(true)
	return contract


func _play_feature_stem_set(stem_set: Dictionary, resume_position: float) -> void:
	if _feature_stem_players.is_empty() or not _stem_set_contract_valid(stem_set):
		return
	var stems: Dictionary = stem_set.get("stems", {}) as Dictionary
	var safe_position := maxf(0.0, resume_position)
	var role_volumes := _feature_role_volume_db_map(_feature_mix_live if not _feature_mix_live.is_empty() else _neutral_feature_mix_vector())
	var web_audio_playback := WebAudioBridgeScript.available()
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		var player: AudioStreamPlayer = _feature_stem_players.get(role, null)
		if player == null:
			continue
		var stream: AudioStream = stems.get(role, null)
		if stream == null or web_audio_playback:
			player.stop()
			player.stream = null
			player.volume_db = float(role_volumes.get(role, MUSIC_MIN_VOLUME_DB)) if web_audio_playback else MUSIC_MIN_VOLUME_DB
			continue
		player.stream = stream
		player.volume_db = float(role_volumes.get(role, MUSIC_MIN_VOLUME_DB))
	if not web_audio_playback:
		for role_value in MUSIC_STEM_PLAYBACK_ROLES:
			var role := str(role_value)
			var player: AudioStreamPlayer = _feature_stem_players.get(role, null)
			if player == null or player.stream == null:
				continue
			_play_audio_player(player, safe_position, "feature_stems")
	_current_feature_stem_set = stem_set.duplicate(true)
	_stop_music_send_players(_feature_send_players, true)
	if _web_audio_stem_set_bridge_allowed(stem_set, "feature", AMBIENT_STAGE_FULL):
		WebAudioBridgeScript.play_music_stems("feature", _web_stem_set_key(stem_set, AMBIENT_STAGE_FULL, "feature"), stem_set, role_volumes, safe_position)
	_apply_feature_mix_vector(_feature_mix_live if not _feature_mix_live.is_empty() else _neutral_feature_mix_vector(), true)


func _stop_feature_stem_players() -> void:
	if WebAudioBridgeScript.available():
		WebAudioBridgeScript.stop_music("feature")
	for player_value in _feature_stem_players.values():
		if player_value is AudioStreamPlayer:
			var player := player_value as AudioStreamPlayer
			if player.playing:
				player.stop()
	_stop_music_send_players(_feature_send_players, false)


func _stop_feature_stinger_players() -> void:
	for player_value in _feature_stinger_players:
		if player_value is AudioStreamPlayer:
			var player := player_value as AudioStreamPlayer
			player.stop()
			player.stream = null


func _feature_stem_pcm_data(style: String, root_midi: int, bpm: float, frames: int, bars: int) -> Dictionary:
	var pad_data := _empty_pcm(frames)
	var bass_data := _empty_pcm(frames)
	var lead_data := _empty_pcm(frames)
	var drums_low_data := _empty_pcm(frames)
	var drums_high_data := _empty_pcm(frames)
	var tension_data := _empty_pcm(frames)
	var texture_data := _empty_pcm(frames)
	var step_period := _step_period_from_bpm(bpm)
	var total_steps := maxi(1, STEPS_PER_BAR * bars)
	var duration := float(frames) / float(SAMPLE_RATE)
	var root_freq := _midi_freq(root_midi)
	for i in range(frames):
		var t := float(i) / float(SAMPLE_RATE)
		var step_index := int(t / step_period) % total_steps
		var step_local := fposmod(t, step_period)
		var beat_step := step_index % STEPS_PER_BAR
		var loop_edge := _loop_edge_envelope(t, duration)
		var pulse := _pulse_window(step_local, 0.0, minf(0.10, step_period * 0.28))
		var pad := _music_pad(root_midi, t) * 0.10 * loop_edge
		var bass := 0.0
		if beat_step == 0 or beat_step == 4:
			bass = _music_bass(root_freq * 0.5, step_local) * (0.20 if style == "buffalo" else 0.12) * loop_edge
		var lead := 0.0
		if beat_step == 1 or beat_step == 3 or beat_step == 6:
			var arp_freq := root_freq * (1.5 if beat_step == 3 else 1.25 if beat_step == 6 else 2.0)
			lead = _music_lead(arp_freq, step_local) * (0.20 if style != "buffalo" else 0.12) * loop_edge
		var drums_low := _music_kick(step_local) * (0.16 if beat_step == 0 else 0.08 if beat_step == 4 else 0.0) * loop_edge
		if style == "buffalo" and beat_step == 6:
			drums_low += _music_snare(step_local, i + 71) * 0.11 * loop_edge
		var drums_high := _music_hat(step_local, step_period, i + 131) * (0.08 if beat_step % 2 == 1 else 0.032) * loop_edge
		var tension := sin(TAU * (root_freq * 2.0) * t) * pulse * 0.045 * loop_edge
		var texture := _soft_noise(i, 401 if style == "buffalo" else 409) * pulse * 0.020 * loop_edge
		_write_i16(pad_data, i * PCM_BYTES_PER_FRAME, _soft_limit(pad))
		_write_i16(bass_data, i * PCM_BYTES_PER_FRAME, _soft_limit(bass))
		_write_i16(lead_data, i * PCM_BYTES_PER_FRAME, _soft_limit(lead))
		_write_i16(drums_low_data, i * PCM_BYTES_PER_FRAME, _soft_limit(drums_low))
		_write_i16(drums_high_data, i * PCM_BYTES_PER_FRAME, _soft_limit(drums_high))
		_write_i16(tension_data, i * PCM_BYTES_PER_FRAME, _soft_limit(tension))
		_write_i16(texture_data, i * PCM_BYTES_PER_FRAME, _soft_limit(texture))
	return {
		"pad": pad_data,
		"bass": bass_data,
		"lead": lead_data,
		"drums_low": drums_low_data,
		"drums_high": drums_high_data,
		"tension": tension_data,
		"texture": texture_data,
	}


func _feature_stinger_streams_for_style(style: String, bpm: float) -> Dictionary:
	var result := {}
	for cue_id in [
		"feature_intro",
		"multiball",
		"jackpot",
		"super_jackpot",
		"feature_total",
		"pinball_feature_intro",
		"pinball_multiball",
		"pinball_jackpot_lane",
		"pinball_super_jackpot",
		"jackpot_buffalo",
		"jackpot_hit_buffalo",
		"bonus_total_buffalo",
	]:
		var cue := str(cue_id)
		result[cue] = _feature_stinger_stream(cue, style, bpm)
	return result


func _feature_stinger_stream(cue_id: String, style: String, bpm: float) -> AudioStreamWAV:
	var lowered := cue_id.to_lower()
	var seconds := 0.58
	if lowered.find("super") >= 0 or lowered.find("jackpot") >= 0:
		seconds = 0.92
	elif lowered.find("total") >= 0:
		seconds = 1.12
	var frames := maxi(1, int(seconds * float(SAMPLE_RATE)))
	var data := PackedByteArray()
	data.resize(frames * PCM_BYTES_PER_FRAME)
	var root := 196.0 if style == "buffalo" else 261.63
	for i in range(frames):
		var t := float(i) / float(SAMPLE_RATE)
		var env := _loop_edge_envelope(t, seconds) * exp(-t / maxf(0.12, seconds * 0.52))
		var rise := clampf(t / maxf(0.001, seconds), 0.0, 1.0)
		var sweep := sin(TAU * lerpf(root, root * (3.0 if lowered.find("jackpot") >= 0 else 2.0), rise) * t) * 0.24
		var bell := sin(TAU * root * 4.0 * t) * _pulse_window(t, 0.0, minf(0.16, seconds * 0.28)) * 0.22
		var hit := _music_kick(t) * (0.34 if lowered.find("jackpot") >= 0 else 0.20)
		var sparkle := _soft_noise(i, 503 + cue_id.length()) * _pulse_train(t, 18.0, 0.48) * 0.045
		_write_i16(data, i * PCM_BYTES_PER_FRAME, _soft_limit((sweep + bell + hit + sparkle) * env))
	return _one_shot_stream_from_data(data, frames, SAMPLE_RATE)


func _one_shot_stream_from_data(data: PackedByteArray, frames: int, sample_rate: int) -> AudioStreamWAV:
	var stream := _ambient_stream_from_data_with_rate(data, frames, sample_rate)
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.loop_begin = 0
	stream.loop_end = 0
	return stream


func _feature_stinger_stream_for_cue(cue_id: String) -> AudioStream:
	var stingers: Dictionary = _current_feature_stem_set.get("stingers", {}) as Dictionary
	if stingers.has(cue_id) and stingers[cue_id] is AudioStream:
		return stingers[cue_id] as AudioStream
	var current_stingers: Dictionary = _current_stem_set.get("stingers", {}) as Dictionary
	if current_stingers.has(cue_id) and current_stingers[cue_id] is AudioStream:
		return current_stingers[cue_id] as AudioStream
	var style := _feature_music_style(cue_id)
	return _feature_stinger_stream(cue_id, style, float(_current_stem_set.get("bpm", 96.0)))


func _poll_feature_stingers() -> void:
	if _feature_stinger_pending.is_empty():
		return
	_apply_feature_stingers_for_position(_director_playback_position(), true)


func _apply_feature_stingers_for_position(playback_position: float, play_audio: bool) -> void:
	if _feature_stinger_pending.is_empty():
		return
	var remaining: Array = []
	for pending_value in _feature_stinger_pending:
		if typeof(pending_value) != TYPE_DICTIONARY:
			continue
		var pending: Dictionary = pending_value
		if playback_position + 0.0001 < float(pending.get("target_position", 0.0)):
			remaining.append(pending)
			continue
		_feature_stinger_history.append({
			"cue_id": str(pending.get("cue_id", "")),
			"played_position": snappedf(playback_position, 0.0001),
			"target_position": snappedf(float(pending.get("target_position", 0.0)), 0.0001),
		})
		if _feature_stinger_history.size() > 16:
			_feature_stinger_history.pop_front()
		if play_audio and audio_enabled and not _running_headless():
			_play_feature_stinger_now(str(pending.get("cue_id", "")), float(pending.get("volume_db", -2.0)))
	_feature_stinger_pending = remaining


func _play_feature_stinger_now(cue_id: String, volume_db: float = -2.0) -> void:
	_ensure_feature_stinger_players()
	var stream := _feature_stinger_stream_for_cue(cue_id)
	if stream == null:
		return
	if WebAudioBridgeScript.available():
		WebAudioBridgeScript.play_stream(stream, "music_stinger:%s" % cue_id, volume_db, 1.0)
		return
	for player_value in _feature_stinger_players:
		if player_value is AudioStreamPlayer and not (player_value as AudioStreamPlayer).playing:
			var player := player_value as AudioStreamPlayer
			player.stream = stream
			player.volume_db = volume_db
			_play_audio_player(player)
			return
	if _feature_stinger_players[0] is AudioStreamPlayer:
		var fallback := _feature_stinger_players[0] as AudioStreamPlayer
		fallback.stop()
		fallback.stream = stream
		fallback.volume_db = volume_db
		_play_audio_player(fallback)


func _feature_music_style(cue_id: String) -> String:
	var lowered := cue_id.to_lower()
	if lowered.find("buffalo") >= 0 or lowered.find("stampede") >= 0:
		return "buffalo"
	return "arcade"


func _stem_set_contract(source: String, stems: Dictionary, bpm: float, bars: int, loop_frames: int, palette_id: String, stingers: Dictionary, stage: String) -> Dictionary:
	return {
		"version": MUSIC_STEM_CONTRACT_VERSION,
		"source": source,
		"stems": stems.duplicate(true),
		"bpm": clampf(bpm, 1.0, 260.0),
		"bars": maxi(1, bars),
		"loop_frames": maxi(1, loop_frames),
		"palette_id": palette_id,
		"stingers": stingers.duplicate(true),
		"stage": stage,
	}


func _stem_set_contract_valid(stem_set: Dictionary) -> bool:
	if stem_set.is_empty():
		return false
	if int(stem_set.get("loop_frames", 0)) <= 0:
		return false
	if float(stem_set.get("bpm", 0.0)) <= 0.0:
		return false
	if typeof(stem_set.get("stems", {})) != TYPE_DICTIONARY:
		return false
	var stems: Dictionary = stem_set.get("stems", {})
	for role_value in stems.keys():
		var value: Variant = stems.get(role_value)
		if value is AudioStream:
			continue
		if typeof(value) == TYPE_DICTIONARY and bool((value as Dictionary).get("planned", false)):
			continue
		return false
	return true


func _stem_manifest_from_contract(stem_set: Dictionary) -> Dictionary:
	if stem_set.is_empty():
		return {
			"source": "",
			"roles": {},
			"present_roles": [],
			"missing_roles": MUSIC_STEM_PLAYBACK_ROLES.duplicate(true),
			"sync_ok": false,
			"sparse": true,
			"loop_frames": 0,
			"bpm": 0.0,
			"bars": 0,
			"palette_id": "",
			"player_count": _stem_players.size(),
		}
	var loop_frames := int(stem_set.get("loop_frames", 0))
	var stems: Dictionary = stem_set.get("stems", {})
	var roles := {}
	var present_roles: Array = []
	var missing_roles: Array = []
	var float_pcm_precision := {}
	var sync_ok := loop_frames > 0
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		var value: Variant = stems.get(role)
		var present := value is AudioStream or (typeof(value) == TYPE_DICTIONARY and bool((value as Dictionary).get("planned", false)))
		var frames := 0
		var loop_begin := 0
		var loop_end := 0
		if value is MusicFloatPcmStream:
			var float_stream := value as MusicFloatPcmStream
			frames = float_stream.frame_count
			loop_begin = float_stream.loop_begin_frame
			loop_end = float_stream.loop_end_frame
			float_pcm_precision[role] = float_stream.precision_snapshot()
		elif value is AudioStreamWAV:
			var stream := value as AudioStreamWAV
			frames = int(stream.loop_end)
			loop_begin = int(stream.loop_begin)
			loop_end = int(stream.loop_end)
		elif typeof(value) == TYPE_DICTIONARY:
			var planned := value as Dictionary
			frames = int(planned.get("frames", planned.get("loop_end", loop_frames)))
			loop_begin = int(planned.get("loop_begin", 0))
			loop_end = int(planned.get("loop_end", loop_frames))
		elif value is AudioStream:
			frames = loop_frames
			loop_begin = 0
			loop_end = loop_frames
		if present:
			present_roles.append(role)
			if loop_begin != 0 or loop_end != loop_frames or frames != loop_frames:
				sync_ok = false
		else:
			missing_roles.append(role)
		roles[role] = {
			"present": present,
			"frames": frames,
			"loop_begin": loop_begin,
			"loop_end": loop_end,
			"bus": _music_stem_bus_name(role),
		}
	return {
		"version": int(stem_set.get("version", 0)),
		"source": str(stem_set.get("source", "")),
		"stage": str(stem_set.get("stage", "")),
		"roles": roles,
		"present_roles": present_roles,
		"missing_roles": missing_roles,
		"sync_ok": sync_ok,
		"sparse": not missing_roles.is_empty(),
		"loop_frames": loop_frames,
		"bpm": snappedf(float(stem_set.get("bpm", 0.0)), 0.001),
		"bars": int(stem_set.get("bars", 0)),
		"palette_id": str(stem_set.get("palette_id", "")),
		"sample_rate": int(stem_set.get("sample_rate", SAMPLE_RATE)),
		"channels": int(stem_set.get("channels", 1)),
		"bit_depth": int(stem_set.get("bit_depth", 16)),
		"delivery_files": _copy_array(stem_set.get("delivery_files", [])),
		"source_audio_format": _copy_dict(stem_set.get("source_audio_format", {})),
		"playback_audio_format": _copy_dict(stem_set.get("playback_audio_format", {})),
		"preferred_dsp_sends": _copy_dict(stem_set.get("preferred_dsp_sends", {})),
		"float_pcm_precision": float_pcm_precision,
		"selection_key": str(stem_set.get("selection_key", "base")),
		"selected_variants": _copy_dict(stem_set.get("selected_variants", {})),
		"selected_role_epochs": _copy_dict(stem_set.get("selected_role_epochs", {})),
		"selected_tags": _copy_array(stem_set.get("selected_tags", [])),
		"selection_context": _copy_dict(stem_set.get("selection_context", {})),
		"compatibility_set_id": str(stem_set.get("compatibility_set_id", "")),
		"progression_id": str(stem_set.get("progression_id", "")),
		"recipe_state": _copy_dict(stem_set.get("recipe_state", {})),
		"recipe_id": str(stem_set.get("recipe_id", "")),
		"phrase_index": int(stem_set.get("phrase_index", 0)),
		"cycle_index": int(stem_set.get("cycle_index", 0)),
		"excluded_candidates": _copy_array(stem_set.get("excluded_candidates", [])),
		"transitions": _copy_dict(stem_set.get("transitions", {})),
		"stinger_loop_modes": _audio_stream_loop_mode_snapshot(_copy_dict(stem_set.get("stingers", {}))),
		"fill_loop_modes": _audio_stream_loop_mode_snapshot(_copy_dict(stem_set.get("fills", {}))),
		"step_period": snappedf(float(stem_set.get("step_period", _step_period_from_bpm(float(stem_set.get("bpm", 82.0))))), 0.0001),
		"player_count": _stem_players.size(),
	}


func _audio_stream_loop_mode_snapshot(streams: Dictionary) -> Dictionary:
	var result := {}
	for cue_value in streams.keys():
		var stream: AudioStream = streams.get(cue_value, null)
		if stream is AudioStreamWAV:
			result[str(cue_value)] = int((stream as AudioStreamWAV).loop_mode)
		elif stream is MusicFloatPcmStream:
			result[str(cue_value)] = AudioStreamWAV.LOOP_FORWARD if (stream as MusicFloatPcmStream).loop_enabled else AudioStreamWAV.LOOP_DISABLED
		else:
			result[str(cue_value)] = -1
	return result


func _play_stem_set(stem_set: Dictionary, resume_position: float, stage: String) -> void:
	if _stem_players.is_empty() or not _stem_set_contract_valid(stem_set):
		return
	var stems: Dictionary = stem_set.get("stems", {})
	var safe_position := maxf(0.0, resume_position)
	var started_frame := Engine.get_process_frames()
	var started_msec := Time.get_ticks_msec()
	var role_volumes := _music_role_volume_db_map(_music_mix_live if not _music_mix_live.is_empty() else _neutral_music_mix_vector())
	var web_audio_playback := WebAudioBridgeScript.available()
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		var player: AudioStreamPlayer = _stem_players.get(role, null)
		if player == null:
			continue
		var stream: AudioStream = stems.get(role, null)
		if stream == null or web_audio_playback:
			player.stop()
			player.stream = null
			player.volume_db = float(role_volumes.get(role, MUSIC_MIN_VOLUME_DB)) if web_audio_playback else MUSIC_MIN_VOLUME_DB
			continue
		player.stream = stream
		player.volume_db = float(role_volumes.get(role, MUSIC_MIN_VOLUME_DB))
	if not web_audio_playback:
		for role_value in MUSIC_STEM_PLAYBACK_ROLES:
			var role := str(role_value)
			var player: AudioStreamPlayer = _stem_players.get(role, null)
			if player == null or player.stream == null:
				continue
			_play_audio_player(player, safe_position, "venue_stems")
	_current_stem_set = stem_set.duplicate(true)
	_stop_music_send_players(_music_send_players, true)
	_current_stem_stage = stage
	_current_stem_set["started_frame"] = started_frame
	_current_stem_set["started_ticks_msec"] = started_msec
	_current_stem_set["started_position"] = safe_position
	_current_music_context = _context_from_stem_set(stem_set)
	if _web_audio_stem_set_bridge_allowed(stem_set, "music", stage):
		_play_web_music_stems_if_needed(_current_cache_key, stem_set, role_volumes, safe_position)
	_apply_music_mix_vector(_music_mix_live if not _music_mix_live.is_empty() else _neutral_music_mix_vector(), true)


func _play_web_music_stems_if_needed(cache_key: String, stem_set: Dictionary, role_volumes: Dictionary, resume_position: float) -> void:
	if not _web_audio_stem_set_bridge_allowed(stem_set, "music", AMBIENT_STAGE_PRIMER):
		return
	var stem_key := _web_stem_set_key(stem_set, AMBIENT_STAGE_PRIMER, "music")
	if _current_web_music_bed_cache_key == cache_key and _current_web_music_bed_stem_key == stem_key:
		return
	if WebAudioBridgeScript.play_music_stems("music", stem_key, stem_set, role_volumes, resume_position):
		_current_web_music_bed_cache_key = cache_key
		_current_web_music_bed_stem_key = stem_key


func _web_audio_stem_set_bridge_allowed(stem_set: Dictionary, group_id: String, stage: String) -> bool:
	if not WebAudioBridgeScript.available():
		return false
	if group_id != "music" and group_id != "feature":
		return false
	if group_id == "music" and stage != AMBIENT_STAGE_PRIMER and not bool(stem_set.get("web_bridge_bed", false)):
		return false
	if group_id == "feature" and stage != AMBIENT_STAGE_FULL:
		return false
	var total_bytes := _web_audio_stem_set_pcm_bytes(stem_set)
	return total_bytes > 0 and total_bytes <= WEB_AUDIO_MUSIC_STEM_MAX_PCM_BYTES


func _web_audio_stem_set_pcm_bytes(stem_set: Dictionary) -> int:
	var stems_value: Variant = stem_set.get("stems", {})
	if typeof(stems_value) != TYPE_DICTIONARY:
		return 0
	var stems: Dictionary = stems_value
	var total := 0
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		var stream_value: Variant = stems.get(role, null)
		if not (stream_value is AudioStreamWAV):
			continue
		var stream := stream_value as AudioStreamWAV
		if not _web_audio_wav_has_signal(stream):
			continue
		total += stream.data.size()
	return total


func _web_audio_wav_has_signal(wav: AudioStreamWAV) -> bool:
	var data := wav.data
	var size := data.size()
	if size <= 0:
		return false
	var edge_count := mini(size, 256)
	for index in range(edge_count):
		if int(data[index]) != 0:
			return true
	var suffix_start := maxi(edge_count, size - 256)
	for index in range(suffix_start, size):
		if int(data[index]) != 0:
			return true
	var interior_count := suffix_start - edge_count
	if interior_count <= 0:
		return false
	var sample_count := mini(256, interior_count)
	var step := maxi(1, int(interior_count / sample_count))
	var index := edge_count
	var checked := 0
	while index < suffix_start and checked < sample_count:
		if int(data[index]) != 0:
			return true
		index += step
		checked += 1
	return false


func _web_stem_set_key(stem_set: Dictionary, stage: String, group_id: String) -> String:
	var profile: Dictionary = stem_set.get("profile", {}) as Dictionary
	var identity := str(stem_set.get("track_id", profile.get("palette_id", stem_set.get("palette_id", group_id)))).strip_edges()
	if identity.is_empty():
		identity = group_id
	return "%s:%s:%s:%s:%d:%d" % [
		group_id,
		str(stem_set.get("source", "")),
		identity,
		stage,
		int(stem_set.get("loop_frames", 0)),
		int(stem_set.get("version", 0)),
	]


func _context_from_stem_set(stem_set: Dictionary) -> Dictionary:
	return {
		"step_period": float(stem_set.get("step_period", _step_period_from_bpm(float(stem_set.get("bpm", 82.0))))),
		"frames": int(stem_set.get("loop_frames", 0)),
		"bpm": float(stem_set.get("bpm", 82.0)),
		"bars": int(stem_set.get("bars", 1)),
	}


func _authored_stem_set_from_profile(profile: Dictionary, music_state: Dictionary = {}) -> Dictionary:
	var track_id := str(profile.get("authored_track_id", "")).strip_edges()
	if track_id.is_empty():
		return {}
	var entry := _authored_track_entry(track_id)
	if entry.is_empty() or not _authored_track_entry_valid(entry):
		return {}
	var selection := MusicArrangementSelectorScript.select(entry, profile, music_state)
	_notify_authored_arrangement_selection(track_id, selection)
	var selection_key := str(selection.get("selection_key", "base"))
	var cache_key := "authored:%s:%s" % [track_id, selection_key]
	if _authored_manifest_cache.has(cache_key):
		var cached := (_authored_manifest_cache.get(cache_key, {}) as Dictionary).duplicate(true)
		cached["recipe_state"] = _copy_dict(selection.get("recipe_state", {}))
		cached["selected_role_epochs"] = _copy_dict(selection.get("selected_role_epochs", {}))
		cached["selection_context"] = _copy_dict(selection.get("selection_context", {}))
		cached["recipe_id"] = str((cached.get("recipe_state", {}) as Dictionary).get("recipe_id", ""))
		var cached_cursor := int((cached.get("recipe_state", {}) as Dictionary).get("cursor", -1)) if typeof(cached.get("recipe_state", {})) == TYPE_DICTIONARY else -1
		var cached_recipe := MusicArrangementSelectorScript.recipe_definition(entry, str((cached.get("recipe_state", {}) as Dictionary).get("recipe_id", "")) if typeof(cached.get("recipe_state", {})) == TYPE_DICTIONARY else "")
		var cached_recipe_length := maxi(1, _copy_array(cached_recipe.get("sections", [])).size())
		cached["phrase_index"] = posmod(maxi(0, cached_cursor), cached_recipe_length)
		cached["cycle_index"] = maxi(0, cached_cursor) / cached_recipe_length
		cached["harmony_recipe_id"] = str(cached_recipe.get("id", ""))
		cached["harmony_phrase_bars"] = maxi(1, int(cached_recipe.get("phrase_bars", 4)))
		cached["harmony_recipe_length"] = cached_recipe_length
		cached["harmony_visit_id"] = str((cached.get("recipe_state", {}) as Dictionary).get("visit_id", ""))
		cached["harmony_last_phrase_event_index"] = int((cached.get("recipe_state", {}) as Dictionary).get("last_phrase_event_index", -1))
		cached["excluded_candidates"] = _copy_array(selection.get("excluded_candidates", []))
		return cached
	var stems_value: Variant = selection.get("stems", {})
	if typeof(stems_value) != TYPE_DICTIONARY:
		return {}
	var stems_data: Dictionary = stems_value
	var loop_frames := int(entry.get("loop_frames", 0))
	var stems := {}
	for role_value in stems_data.keys():
		var role := str(role_value).strip_edges()
		if not MUSIC_STEM_PLAYBACK_ROLES.has(role):
			continue
		var filename := _authored_stem_filename(stems_data.get(role_value))
		if filename.is_empty():
			continue
		var path := _authored_music_path(track_id, filename)
		var stream: AudioStream = _load_authored_audio_stream(path, loop_frames)
		if stream == null:
			return {}
		stems[role] = stream
	if stems.is_empty():
		return {}
	var stingers := _authored_stingers(track_id, entry)
	var contract := _stem_set_contract("authored", stems, float(entry.get("bpm", 82.0)), int(entry.get("bars", 1)), loop_frames, str(entry.get("palette_id", track_id)), stingers, AMBIENT_STAGE_FULL)
	contract["track_id"] = track_id
	contract["sample_rate"] = int(entry.get("sample_rate", SAMPLE_RATE))
	contract["channels"] = int(entry.get("channels", 1))
	contract["bit_depth"] = int(entry.get("bit_depth", 16))
	var delivery_snapshot := _authored_delivery_snapshot(entry, stems_data)
	contract["delivery_files"] = _copy_array(delivery_snapshot.get("files", []))
	contract["source_audio_format"] = _copy_dict(delivery_snapshot.get("source_audio_format", {}))
	contract["playback_audio_format"] = _copy_dict(delivery_snapshot.get("playback_audio_format", {}))
	contract["preferred_dsp_sends"] = _copy_dict(delivery_snapshot.get("preferred_dsp_sends", {}))
	contract["selection_key"] = selection_key
	contract["selected_variants"] = _copy_dict(selection.get("selected_variants", {}))
	contract["selected_role_epochs"] = _copy_dict(selection.get("selected_role_epochs", {}))
	contract["selected_tags"] = _copy_array(selection.get("selected_tags", []))
	contract["selection_context"] = _copy_dict(selection.get("selection_context", {}))
	contract["compatibility_set_id"] = str(selection.get("compatibility_set_id", ""))
	contract["progression_id"] = str(selection.get("progression_id", ""))
	contract["recipe_state"] = _copy_dict(selection.get("recipe_state", {}))
	contract["recipe_id"] = str((contract.get("recipe_state", {}) as Dictionary).get("recipe_id", ""))
	var recipe_cursor := int((contract.get("recipe_state", {}) as Dictionary).get("cursor", -1)) if typeof(contract.get("recipe_state", {})) == TYPE_DICTIONARY else -1
	var recipe := MusicArrangementSelectorScript.recipe_definition(entry, str((contract.get("recipe_state", {}) as Dictionary).get("recipe_id", "")) if typeof(contract.get("recipe_state", {})) == TYPE_DICTIONARY else "")
	var recipe_length := maxi(1, _copy_array(recipe.get("sections", [])).size())
	contract["phrase_index"] = posmod(maxi(0, recipe_cursor), recipe_length)
	contract["cycle_index"] = maxi(0, recipe_cursor) / recipe_length
	contract["harmony_recipe_id"] = str(recipe.get("id", ""))
	contract["harmony_phrase_bars"] = maxi(1, int(recipe.get("phrase_bars", 4)))
	contract["harmony_recipe_length"] = recipe_length
	contract["harmony_visit_id"] = str((contract.get("recipe_state", {}) as Dictionary).get("visit_id", ""))
	contract["harmony_last_phrase_event_index"] = int((contract.get("recipe_state", {}) as Dictionary).get("last_phrase_event_index", -1))
	contract["excluded_candidates"] = _copy_array(selection.get("excluded_candidates", []))
	contract["transitions"] = _copy_dict(entry.get("transitions", {}))
	contract["authored_arrangement"] = _copy_array(entry.get("arrangement", []))
	contract["fills"] = _authored_one_shots(track_id, _copy_dict(entry.get("fills", {})))
	contract["step_period"] = _step_period_from_bpm(float(contract.get("bpm", 82.0)))
	_store_authored_manifest_cache(cache_key, contract)
	return contract


func _notify_authored_arrangement_selection(track_id: String, selection: Dictionary) -> void:
	if str(selection.get("compatibility_set_id", "")).is_empty():
		return
	var recipe_state := _copy_dict(selection.get("recipe_state", {}))
	var notice := "%s|%s|%d|%s" % [track_id, str(recipe_state.get("visit_id", "")), int(recipe_state.get("cursor", -1)), str(selection.get("selection_key", ""))]
	if notice == _last_arrangement_selection_notice:
		return
	_last_arrangement_selection_notice = notice
	authored_arrangement_selected.emit({"track_id": track_id, "selected_variant_ids": _copy_dict(selection.get("selection_memory_ids", {})), "selected_role_epochs": _copy_dict(selection.get("selection_memory_epochs", {})), "selection_key": str(selection.get("selection_key", ""))})


func _store_authored_manifest_cache(cache_key: String, contract: Dictionary) -> void:
	if _authored_manifest_cache.has(cache_key):
		_authored_manifest_cache_order.erase(cache_key)
	_authored_manifest_cache[cache_key] = contract.duplicate(true)
	_authored_manifest_cache_order.append(cache_key)
	while _authored_manifest_cache_order.size() > AUTHORED_MANIFEST_CACHE_LIMIT:
		var evicted: String = str(_authored_manifest_cache_order.pop_front())
		_authored_manifest_cache.erase(evicted)


func _authored_delivery_snapshot(entry: Dictionary, selected_stems: Dictionary) -> Dictionary:
	var delivery := entry.get("delivery", {}) as Dictionary if typeof(entry.get("delivery", {})) == TYPE_DICTIONARY else {}
	var aliases := delivery.get("classification_aliases", {}) as Dictionary if typeof(delivery.get("classification_aliases", {})) == TYPE_DICTIONARY else {}
	var files: Array = []
	var preferred_dsp_sends := {}
	var roles := selected_stems.keys()
	roles.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for role_value in roles:
		var role := str(role_value)
		var metadata_value: Variant = selected_stems.get(role_value)
		var filename := _authored_stem_filename(metadata_value)
		var parsed := MusicDeliveryIndexScript.parse_filename(filename, aliases)
		if bool(parsed.get("ok", false)):
			files.append(parsed.duplicate(true))
		else:
			files.append({"ok": false, "original_filename": filename, "role": role, "error": str(parsed.get("error", "legacy filename"))})
		if typeof(metadata_value) == TYPE_DICTIONARY:
			var sends_value: Variant = (metadata_value as Dictionary).get("dsp_sends", {})
			if typeof(sends_value) == TYPE_DICTIONARY:
				preferred_dsp_sends[role] = (sends_value as Dictionary).duplicate(true)
	var source_bits := int(entry.get("bit_depth", 16))
	return {
		"files": files,
		"preferred_dsp_sends": preferred_dsp_sends,
		"source_audio_format": {
			"codec": "pcm_integer_wav",
			"sample_rate": int(entry.get("sample_rate", SAMPLE_RATE)),
			"channels": int(entry.get("channels", 1)),
			"bit_depth": source_bits,
			"master_preserved": true,
		},
		"playback_audio_format": {
			"codec": "godot_audiostreamgenerator_float_pcm",
			"sample_rate": int(entry.get("sample_rate", SAMPLE_RATE)),
			"channels": int(entry.get("channels", 1)),
			"sample_type": "float32",
			"bit_depth": 32,
			"decoded_from_24_bit": source_bits == 24,
			"decode_policy": "exact_signed_pcm24_normalization_cached_at_load",
			"phase_alignment": "director_position_authoritative_group_launch_then_native_mixer_clock",
		},
	}


func _authored_track_entry(track_id: String) -> Dictionary:
	if not _authored_manifest_entries_loaded:
		_authored_manifest_entries()
	return (_authored_manifest_entries_by_id.get(track_id, {}) as Dictionary).duplicate(true) if _authored_manifest_entries_by_id.has(track_id) else {}


func _authored_manifest_entries() -> Array:
	if _authored_manifest_entries_loaded:
		return _authored_manifest_entries_cache.duplicate(true)
	_authored_manifest_entries_loaded = true
	if not FileAccess.file_exists(MUSIC_AUTHORED_MANIFEST_PATH):
		return []
	var text := FileAccess.get_file_as_string(MUSIC_AUTHORED_MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		return []
	_authored_manifest_entries_cache = (parsed as Array).duplicate(true)
	_authored_manifest_entries_by_id = {}
	for entry_value in _authored_manifest_entries_cache:
		if typeof(entry_value) == TYPE_DICTIONARY:
			var entry: Dictionary = entry_value
			var track_id := str(entry.get("id", "")).strip_edges()
			if not track_id.is_empty():
				_authored_manifest_entries_by_id[track_id] = entry
	return _authored_manifest_entries_cache.duplicate(true)


func _authored_track_entry_valid(entry: Dictionary) -> bool:
	var track_id := str(entry.get("id", "")).strip_edges()
	if track_id.is_empty():
		return false
	if float(entry.get("bpm", 0.0)) <= 0.0:
		return false
	if int(entry.get("bars", 0)) <= 0:
		return false
	var loop_frames := int(entry.get("loop_frames", 0))
	if loop_frames <= 0:
		return false
	var stems_value: Variant = entry.get("stems", {})
	if typeof(stems_value) != TYPE_DICTIONARY:
		return false
	var stems: Dictionary = stems_value
	var stem_banks := _copy_dict(entry.get("stem_banks", {}))
	if stems.is_empty() and stem_banks.is_empty():
		return false
	for role_value in stems.keys():
		var role := str(role_value).strip_edges()
		if not MUSIC_STEM_PLAYBACK_ROLES.has(role):
			return false
		var filename := _authored_stem_filename(stems.get(role_value))
		if filename.is_empty() or not FileAccess.file_exists(_authored_music_path(track_id, filename)):
			return false
	for role_value in stem_banks.keys():
		if not MUSIC_STEM_PLAYBACK_ROLES.has(str(role_value)):
			return false
		var bank_value: Variant = stem_banks.get(role_value)
		var variants: Array = bank_value as Array if typeof(bank_value) == TYPE_ARRAY else _copy_array((bank_value as Dictionary).get("variants", [])) if typeof(bank_value) == TYPE_DICTIONARY else []
		if variants.is_empty():
			return false
		for variant_value in variants:
			if typeof(variant_value) != TYPE_DICTIONARY:
				return false
			var filename := _authored_stem_filename(variant_value)
			if filename.is_empty() or not FileAccess.file_exists(_authored_music_path(track_id, filename)):
				return false
	return true


func _authored_stem_filename(value: Variant) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		return str((value as Dictionary).get("file", "")).strip_edges()
	return str(value).strip_edges()


func _authored_stingers(track_id: String, entry: Dictionary) -> Dictionary:
	var result := {}
	var stingers_value: Variant = entry.get("stingers", {})
	if typeof(stingers_value) != TYPE_DICTIONARY:
		return result
	var stingers: Dictionary = stingers_value
	for cue_value in stingers.keys():
		var cue_id := str(cue_value).strip_edges()
		var stinger_value: Variant = stingers.get(cue_value)
		var filename := _authored_stem_filename(stinger_value)
		if cue_id.is_empty() or filename.is_empty():
			continue
		var loop_enabled := typeof(stinger_value) == TYPE_DICTIONARY and bool((stinger_value as Dictionary).get("loop", false))
		var loop_frames := int((stinger_value as Dictionary).get("loop_frames", 0)) if loop_enabled else 0
		var stream: AudioStream = _load_authored_audio_stream(_authored_music_path(track_id, filename), loop_frames, loop_enabled)
		if stream != null:
			result[cue_id] = stream
	return result


func _authored_one_shots(track_id: String, entries: Dictionary) -> Dictionary:
	var result := {}
	for cue_value in entries.keys():
		var cue_id := str(cue_value).strip_edges()
		var value: Variant = entries.get(cue_value)
		var filename := _authored_stem_filename(value)
		if cue_id.is_empty() or filename.is_empty():
			continue
		var loop_enabled := typeof(value) == TYPE_DICTIONARY and bool((value as Dictionary).get("loop", false))
		var loop_frames := int((value as Dictionary).get("loop_frames", 0)) if loop_enabled else 0
		var stream: AudioStream = _load_authored_audio_stream(_authored_music_path(track_id, filename), loop_frames, loop_enabled)
		if stream != null:
			result[cue_id] = stream
	return result


func _authored_music_path(track_id: String, filename: String) -> String:
	return "%s/%s/%s" % [MUSIC_AUTHORED_ROOT, track_id, filename]


func _load_authored_audio_stream(path: String, loop_frames: int, loop_enabled: bool = true):
	var lowered := path.to_lower()
	if lowered.ends_with(".wav"):
		# Decode the untouched source master ourselves. This keeps 24-bit source
		# validation deterministic across editor/import settings; 24-bit masters
		# enter the cached float provider rather than a 16-bit WAV container.
		return _load_authored_wav_stream(path, loop_frames, loop_enabled)
	var loaded: Resource = load(path)
	if loaded is AudioStreamWAV:
		var wav_stream := (loaded as AudioStreamWAV).duplicate(true) as AudioStreamWAV
		_configure_wav_loop(wav_stream, loop_frames, loop_enabled)
		return wav_stream
	if loaded is AudioStream:
		return loaded
	return null


func _configure_wav_loop(stream: AudioStreamWAV, loop_frames: int, loop_enabled: bool = true) -> void:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop_enabled else AudioStreamWAV.LOOP_DISABLED
	stream.loop_begin = 0
	if loop_enabled and loop_frames > 0:
		stream.loop_end = loop_frames


func _load_authored_wav_stream(path: String, loop_frames: int, loop_enabled: bool = true):
	if not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 12:
		return null
	if _ascii_from_bytes(bytes, 0, 4) != "RIFF" or _ascii_from_bytes(bytes, 8, 4) != "WAVE":
		return null
	var offset := 12
	var audio_format := 0
	var channels := 0
	var sample_rate := 0
	var bits_per_sample := 0
	var block_align := 0
	var data_start := -1
	var data_size := 0
	while offset + 8 <= bytes.size():
		var chunk_id := _ascii_from_bytes(bytes, offset, 4)
		var chunk_size := _u32_le(bytes, offset + 4)
		var chunk_data := offset + 8
		if chunk_data + chunk_size > bytes.size():
			return null
		if chunk_id == "fmt " and chunk_size >= 16:
			audio_format = _u16_le(bytes, chunk_data)
			channels = _u16_le(bytes, chunk_data + 2)
			sample_rate = _u32_le(bytes, chunk_data + 4)
			block_align = _u16_le(bytes, chunk_data + 12)
			bits_per_sample = _u16_le(bytes, chunk_data + 14)
		elif chunk_id == "data" and data_start < 0:
			data_start = chunk_data
			data_size = chunk_size
		offset = chunk_data + chunk_size + (chunk_size % 2)
	if audio_format != 1 or channels < 1 or channels > 2 or sample_rate <= 0 or not [16, 24].has(bits_per_sample) or data_start < 0 or data_size <= 0:
		return null
	var source_bytes_per_sample := int(bits_per_sample / 8)
	var source_frame_bytes := channels * source_bytes_per_sample
	if block_align != source_frame_bytes or data_size % source_frame_bytes != 0:
		return null
	var source_frames := int(data_size / source_frame_bytes)
	if loop_enabled and loop_frames > 0 and source_frames != loop_frames:
		return null
	if bits_per_sample == 24:
		var float_frames := PackedVector2Array()
		float_frames.resize(source_frames)
		var precision_samples := 0
		var max_reconstruction_error_lsb := 0
		for frame_index in range(source_frames):
			var source_offset := data_start + frame_index * source_frame_bytes
			var left_24 := _s24_le(bytes, source_offset)
			var right_24 := _s24_le(bytes, source_offset + 3) if channels > 1 else left_24
			var frame := Vector2(MusicFloatPcmStream.pcm24_to_float(left_24), MusicFloatPcmStream.pcm24_to_float(right_24))
			float_frames[frame_index] = frame
			if (left_24 & 0xff) != 0:
				precision_samples += 1
			if channels > 1 and (right_24 & 0xff) != 0:
				precision_samples += 1
			max_reconstruction_error_lsb = maxi(max_reconstruction_error_lsb, absi(int(round(float(frame.x) * 8388608.0)) - left_24))
			if channels > 1:
				max_reconstruction_error_lsb = maxi(max_reconstruction_error_lsb, absi(int(round(float(frame.y) * 8388608.0)) - right_24))
		var float_stream := MusicFloatPcmStream.new()
		float_stream.configure(float_frames, sample_rate, channels, loop_enabled, 0, loop_frames if loop_enabled and loop_frames > 0 else source_frames, precision_samples, max_reconstruction_error_lsb)
		return float_stream
	var data := PackedByteArray()
	if bits_per_sample == 16:
		data = bytes.slice(data_start, data_start + data_size)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = channels > 1
	stream.data = data
	_configure_wav_loop(stream, loop_frames, loop_enabled)
	return stream


static func _ascii_from_bytes(bytes: PackedByteArray, offset: int, length: int) -> String:
	var chars := PackedByteArray()
	chars.resize(length)
	for index in range(length):
		chars[index] = bytes[offset + index] if offset + index < bytes.size() else 0
	return chars.get_string_from_ascii()


static func _u16_le(bytes: PackedByteArray, offset: int) -> int:
	if offset + 1 >= bytes.size():
		return 0
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8)


static func _u32_le(bytes: PackedByteArray, offset: int) -> int:
	if offset + 3 >= bytes.size():
		return 0
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8) | (int(bytes[offset + 2]) << 16) | (int(bytes[offset + 3]) << 24)


static func _s24_le(bytes: PackedByteArray, offset: int) -> int:
	if offset + 2 >= bytes.size():
		return 0
	var value := int(bytes[offset]) | (int(bytes[offset + 1]) << 8) | (int(bytes[offset + 2]) << 16)
	return value - 0x1000000 if (value & 0x800000) != 0 else value


func _midi_freq(midi_note: int) -> float:
	return 440.0 * pow(2.0, float(midi_note - 69) / 12.0)


func _phrase_energy(phrase_index: int, phrase_count: int, danger: float) -> float:
	if phrase_count <= 1:
		return 0.5
	var progress := float(phrase_index) / float(maxi(1, phrase_count - 1))
	var wave := 0.5 + 0.5 * sin(PI * progress)
	var heat_lift := clampf(danger, 0.0, 1.0) * 0.22
	return clampf(progress * 0.58 + wave * 0.32 + heat_lift, 0.0, 1.0)


func _phrase_fill_amount(phrase_step: int, phrase_index: int, phrase_count: int, phrase_energy: float) -> float:
	if phrase_step < BASE_PHRASE_STEPS - 6:
		return 0.0
	var phrase_pressure := clampf(float(phrase_index + 1) / float(maxi(1, phrase_count)), 0.0, 1.0)
	return clampf(phrase_energy * phrase_pressure, 0.0, 1.0)


func _swing_step_local(beat_step: int, local_t: float, step_period: float, swing_amount: float) -> float:
	if swing_amount <= 0.001 or beat_step % 2 == 0:
		return local_t
	return maxf(0.0, local_t - step_period * clampf(swing_amount, 0.0, 0.22))


func _step_humanization(seed: int, phrase_step: int, phrase_index: int, amount: float) -> float:
	var raw := int(abs(seed + phrase_step * 37 + phrase_index * 101)) % 2001
	var centered := (float(raw) / 1000.0) - 1.0
	return clampf(1.0 + centered * clampf(amount, 0.0, 0.18), 0.72, 1.24)


static func _palette_value(palette: Dictionary, key: String, fallback: float) -> float:
	return float(palette.get(key, fallback))


func _mode_scale(mode: String) -> Array:
	match mode:
		"dorian":
			return SCALE_DORIAN.duplicate(true)
		"phrygian":
			return SCALE_PHRYGIAN.duplicate(true)
		"harmonic_minor":
			return SCALE_HARMONIC_MINOR.duplicate(true)
		_:
			return SCALE_MINOR.duplicate(true)


func _harmony_plan(scale: Array, progression: Array) -> Dictionary:
	var roots: Array = []
	var intervals: Array = []
	var voicings: Array = []
	var inversions: Array = []
	var usable_progression := progression
	if usable_progression.is_empty():
		usable_progression = DEFAULT_PROGRESSION
	var previous_center := 0
	var has_previous := false
	for degree_value in usable_progression:
		var degree := int(degree_value)
		var root_offset := _scale_degree_offset(degree, scale)
		var chord_intervals := _chord_intervals_for_degree(degree, scale)
		roots.append(root_offset)
		intervals.append(chord_intervals)
		var voiced := _nearest_chord_voicing(root_offset, chord_intervals, previous_center if has_previous else root_offset + 9)
		voicings.append(voiced.get("notes", []))
		inversions.append(int(voiced.get("inversion", 0)))
		var notes: Array = voiced.get("notes", [])
		if not notes.is_empty():
			var total := 0
			for note_value in notes:
				total += int(note_value)
			previous_center = int(round(float(total) / float(notes.size())))
			has_previous = true
	return {
		"roots": roots,
		"intervals": intervals,
		"voicings": voicings,
		"inversions": inversions,
	}


func _nearest_chord_voicing(root_offset: int, intervals: Array, previous_center: int) -> Dictionary:
	var best_notes: Array = []
	var best_inversion := 0
	var best_distance := 999999
	for inversion in range(maxi(1, intervals.size())):
		var notes: Array = []
		for index in range(intervals.size()):
			var interval_index := (index + inversion) % intervals.size()
			var note := root_offset + int(intervals[interval_index])
			if interval_index < inversion:
				note += 12
			while note < -2:
				note += 12
			while note > 24:
				note -= 12
			notes.append(note)
		notes.sort()
		var total := 0
		for note_value in notes:
			total += int(note_value)
		var center := int(round(float(total) / float(maxi(1, notes.size()))))
		var distance := absi(center - previous_center)
		if distance < best_distance:
			best_notes = notes.duplicate(true)
			best_inversion = inversion
			best_distance = distance
	return {
		"notes": best_notes,
		"inversion": best_inversion,
	}


func _chord_intervals_for_degree(degree: int, scale: Array) -> Array:
	var root_offset := _scale_degree_offset(degree, scale)
	var intervals: Array = []
	for chord_step in [0, 2, 4, 6]:
		intervals.append(_scale_degree_offset(degree + chord_step, scale) - root_offset)
	return intervals


func _scale_degree_offset(degree: int, scale: Array) -> int:
	var size := maxi(1, scale.size())
	var octave := floori(float(degree) / float(size))
	var wrapped := posmod(degree, size)
	return int(scale[wrapped]) + octave * 12


func _bass_offset_for_step(scale: Array, progression: Array, chord_roots: Array, bar_index: int, beat_step: int, phrase_index: int, phrase_count: int, seed: int) -> int:
	if progression.is_empty() or chord_roots.is_empty():
		return int(EMPTY_NOTE)
	var bar := bar_index % chord_roots.size()
	var degree := int(progression[bar % progression.size()])
	var root_offset := int(chord_roots[bar])
	match beat_step:
		0:
			return _fit_bass_range(root_offset - 12)
		2:
			if phrase_index > 0:
				return _fit_bass_range(_scale_degree_offset(degree + 4, scale) - 12)
		4:
			return _fit_bass_range(root_offset - 12)
		6:
			if phrase_index > 0:
				var next_degree := int(progression[(bar + 1) % progression.size()])
				var approach_degree := next_degree - 1
				if int(abs(seed + phrase_index * 11 + bar_index * 3)) % 2 == 0:
					approach_degree = next_degree + 1
				return _fit_bass_range(_scale_degree_offset(approach_degree, scale) - 12)
		7:
			if phrase_index == phrase_count - 1 and bar == chord_roots.size() - 1:
				return _fit_bass_range(-12)
	return int(EMPTY_NOTE)


func _lead_offset_for_step(scale: Array, progression: Array, motif: Array, bar_index: int, phrase_step: int, phrase_index: int, phrase_count: int, seed: int, answer_transform: String = "inversion", bridge_phrase_index: int = 2) -> int:
	if progression.is_empty() or motif.is_empty():
		return int(EMPTY_NOTE)
	var beat_step := phrase_step % 8
	var bar := bar_index % progression.size()
	var chord_degree := int(progression[bar])
	var motif_value := float(motif[phrase_step % motif.size()])
	var degree := 0
	if motif_value <= -900.0:
		if phrase_index <= 0 or (beat_step != 3 and beat_step != 7):
			return int(EMPTY_NOTE)
		if int(abs(seed + phrase_index * 17 + phrase_step * 5)) % 3 != 0:
			return int(EMPTY_NOTE)
		var next_degree := int(progression[(bar + 1) % progression.size()])
		degree = next_degree - 1
		if int(abs(seed + phrase_step + phrase_index)) % 2 == 0:
			degree = next_degree + 1
	else:
		degree = int(round(motif_value))

	if phrase_index == bridge_phrase_index:
		degree += 3 if (bar % 2 == 0) else 2
	elif phrase_step >= 16:
		if answer_transform == "inversion":
			degree = -degree + int(progression[bar])
		else:
			degree += 2

	if beat_step == 0 or beat_step == 4:
		degree = _nearest_chord_tone_degree(degree, chord_degree)
	elif phrase_index == 1 and (beat_step == 2 or beat_step == 6):
		degree += 1
	elif phrase_index >= 2 and (beat_step == 1 or beat_step == 5):
		degree -= 1

	if phrase_index == phrase_count - 1:
		if phrase_step >= BASE_PHRASE_STEPS - 2:
			degree = 0
		elif phrase_step >= BASE_PHRASE_STEPS - 4:
			degree = 2
	elif phrase_index == phrase_count - 2 and beat_step >= 5:
		degree += 1

	return _fit_melody_range(_scale_degree_offset(degree, scale) + 12)


func _nearest_chord_tone_degree(target_degree: int, chord_degree: int) -> int:
	var chord_tones := [chord_degree, chord_degree + 2, chord_degree + 4, chord_degree + 6]
	var best := int(chord_tones[0])
	var best_distance := absi(target_degree - best)
	for tone in chord_tones:
		var tone_degree := int(tone)
		var distance := absi(target_degree - tone_degree)
		if distance < best_distance:
			best = tone_degree
			best_distance = distance
	return best


func _fit_bass_range(offset: int) -> int:
	var fitted := offset
	while fitted > 0:
		fitted -= 12
	while fitted < -24:
		fitted += 12
	return fitted


func _fit_melody_range(offset: int) -> int:
	var fitted := offset
	while fitted < 12:
		fitted += 12
	while fitted > 31:
		fitted -= 12
	return fitted


func _loop_edge_envelope(t: float, duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	var fade := minf(0.045, duration * 0.01)
	if t < fade:
		return smoothstep(0.0, fade, t)
	if t > duration - fade:
		return smoothstep(0.0, fade, duration - t)
	return 1.0


func _music_pad(root_midi: int, t: float) -> float:
	var chord := [0, 3, 7, 10]
	var sample := 0.0
	for i in range(chord.size()):
		var freq := _midi_freq(root_midi + int(chord[i]))
		var phase := TAU * freq * t
		sample += (sin(phase) * 0.72 + sin(phase * 2.0) * 0.08) / float(chord.size())
	var tremolo := 0.72 + 0.18 * sin(TAU * 0.30 * t) + 0.10 * sin(TAU * 0.50 * t)
	return sample * tremolo


func _music_pad_voiced(root_midi: int, voicing: Array, fallback_root_midi: int, t: float, palette: Dictionary = {}) -> float:
	if voicing.is_empty():
		return _music_pad(fallback_root_midi, t) * _palette_value(palette, "pad_warmth", 1.0)
	var sample := 0.0
	var warmth := _palette_value(palette, "pad_warmth", 1.0)
	var phaser := _palette_value(palette, "pad_phaser", 0.0)
	for i in range(voicing.size()):
		var freq := _midi_freq(root_midi + int(voicing[i]))
		var phase := TAU * freq * t
		var partial := sin(phase) * 0.74 + sin(phase * 2.0) * 0.06 * warmth
		if phaser > 0.001:
			partial *= 0.84 + sin(TAU * (0.08 + phaser * 0.08) * t + float(i)) * 0.16 * phaser
		sample += partial / float(voicing.size())
	var tremolo := 0.74 + 0.16 * sin(TAU * 0.25 * t) + 0.08 * sin(TAU * 0.43 * t)
	return sample * tremolo * warmth


func _music_bass(freq: float, local_t: float) -> float:
	var env := _note_decay(local_t, 0.020, 0.54)
	var phase := TAU * freq * local_t
	return (sin(phase) * 0.78 + sin(phase * 2.0) * 0.10 + sin(phase * 0.5) * 0.14) * env


func _music_dark_bass(freq: float, local_t: float) -> float:
	var env := _note_decay(local_t, 0.028, 0.72)
	var phase := TAU * freq * local_t
	return (sin(phase * 0.5) * 0.38 + sin(phase) * 0.58 + sin(phase * 2.0) * 0.05) * env


func _music_lead(freq: float, local_t: float, palette: Dictionary = {}) -> float:
	var env := _note_decay(local_t, 0.018, 0.30)
	var phase := TAU * freq * local_t
	var detune := _palette_value(palette, "lead_detune", 0.0)
	var vib := _palette_value(palette, "vibraphone", 0.0)
	var soft_square := sin(phase) * 0.82 + sin(phase * 3.0) * 0.08 + sin(phase * 5.0) * 0.03
	if detune > 0.001:
		soft_square += sin(phase * (1.0 + detune * 0.012)) * 0.16 * detune
	if vib > 0.001:
		soft_square = soft_square * (0.82 + 0.18 * sin(TAU * 5.8 * local_t)) + sin(phase * 2.0) * 0.05 * vib
	return soft_square * env


func _music_drums(beat_step: int, local_t: float, step_period: float, frame: int, phrase_index: int, phrase_count: int, seed: int, fill_amount: float = 0.0, palette: Dictionary = {}) -> float:
	return _music_drums_low(beat_step, local_t, frame, phrase_index, phrase_count, seed, fill_amount, palette) + _music_drums_high(beat_step, local_t, step_period, frame, phrase_index, phrase_count, seed, fill_amount, palette)


func _music_drums_low(beat_step: int, local_t: float, frame: int, phrase_index: int, phrase_count: int, seed: int, fill_amount: float = 0.0, _palette: Dictionary = {}) -> float:
	var drums := 0.0
	if beat_step == 0:
		drums += _music_kick(local_t) * 0.62
	elif beat_step == 1:
		drums += _music_kick(local_t) * 0.20
	elif beat_step == 4:
		drums += _music_snare(local_t, frame) * 0.18
	if phrase_index > 0 and beat_step == 6 and ((seed + phrase_index) % 2 == 0):
		drums += _music_snare(local_t, frame + seed) * 0.10
	if fill_amount > 0.001 and (beat_step == 6 or beat_step == 7):
		drums += _music_snare(local_t, frame + seed + beat_step * 31) * 0.18 * fill_amount
	return drums


func _music_drums_high(beat_step: int, local_t: float, step_period: float, frame: int, phrase_index: int, phrase_count: int, seed: int, fill_amount: float = 0.0, palette: Dictionary = {}) -> float:
	var drums := 0.0
	if phrase_index == phrase_count - 1 and beat_step == 7:
		drums += _music_hat(local_t, step_period, frame + seed) * 0.13
	if beat_step % 2 == 1:
		drums += _music_hat(local_t, step_period, frame) * 0.07 * _palette_value(palette, "hat_softness", 1.0)
	if fill_amount > 0.001 and beat_step >= 5:
		drums += _music_hat(fposmod(local_t + step_period * 0.33, step_period), step_period * 0.66, frame + seed + 17) * 0.10 * fill_amount
	return drums


func _music_drums_high_double(beat_step: int, local_t: float, step_period: float, frame: int, phrase_index: int, phrase_count: int, seed: int, fill_amount: float = 0.0, palette: Dictionary = {}) -> float:
	var drums := _music_drums_high(beat_step, local_t, step_period, frame, phrase_index, phrase_count, seed, fill_amount, palette)
	if beat_step % 2 == 0:
		drums += _music_hat(local_t, step_period * 0.5, frame + seed + beat_step * 13) * 0.045
	if phrase_index >= maxi(0, phrase_count - 2):
		drums += _music_hat(fposmod(local_t + step_period * 0.5, step_period), step_period * 0.5, frame + seed + 37) * 0.035
	return drums


func _music_kick(local_t: float) -> float:
	var env := _note_decay(local_t, 0.014, 0.23)
	var drop := 42.0 + 28.0 * maxf(0.0, 1.0 - local_t / 0.18)
	return (sin(TAU * drop * local_t) * 0.72 + sin(TAU * 24.0 * local_t) * 0.12) * env


func _music_snare(local_t: float, frame: int) -> float:
	var env := _note_decay(local_t, 0.010, 0.16)
	return (_soft_noise(frame, 97) * 0.34 + sin(TAU * 155.0 * local_t) * 0.22) * env


func _music_hat(local_t: float, step_period: float, frame: int) -> float:
	var env := _note_decay(local_t, 0.001, minf(0.070, step_period * 0.30))
	return _soft_noise(frame, 131) * env


func _music_siren(t: float) -> float:
	var sweep := 0.5 + 0.5 * sin(TAU * 0.18 * t)
	var freq := lerpf(420.0, 680.0, sweep)
	return sin(TAU * freq * t) * (0.55 + 0.45 * sweep)


func _note_decay(local_t: float, attack: float, decay: float) -> float:
	if local_t < 0.0:
		return 0.0
	if local_t < attack:
		return local_t / maxf(attack, 0.0001)
	return exp(-(local_t - attack) / maxf(decay, 0.0001))


func _heartbeat_shape(phase: float, beat_period: float) -> float:
	return _pulse_window(phase, 0.0, beat_period * 0.070) + _pulse_window(phase, beat_period * 0.16, beat_period * 0.085) * 0.56


func _pulse_window(phase: float, start: float, length: float) -> float:
	if phase < start or phase > start + length:
		return 0.0
	var x := (phase - start) / length
	return sin(PI * x) * (1.0 - x * 0.35)


func _pulse_train(t: float, rate: float, width: float) -> float:
	var phase := fposmod(t * rate, 1.0)
	if phase > width:
		return 0.0
	return 1.0 - phase / maxf(width, 0.0001)


func _ambient_texture_sample(kind: String, rate: float, t: float, frame: int, seed: int) -> float:
	match kind:
		"fluorescent":
			var flicker := 0.55 + 0.45 * sin(TAU * rate * t)
			return (sin(TAU * 123.0 * t) * 0.004 + sin(TAU * 246.0 * t) * 0.002) * flicker
		"rain":
			var drip := _pulse_window(fposmod(t, rate), 0.0, 0.045) * sin(TAU * 940.0 * t) * 0.010
			var pavement := sin(TAU * 71.0 * t) * 0.003 + _soft_noise(frame, 17 + seed) * 0.002
			return drip + pavement
		"static":
			var tv_gate := 0.45 + 0.55 * sin(TAU * rate * t)
			return _soft_noise(frame, 31 + seed) * 0.004 * tv_gate + sin(TAU * 60.0 * t) * 0.002
		"bar":
			var glass := _pulse_window(fposmod(t + 0.13, rate * 3.0), 0.0, 0.030) * sin(TAU * 1320.0 * t) * 0.006
			return glass + sin(TAU * 110.0 * t) * 0.004 + sin(TAU * 176.0 * t) * 0.003
		"jazz", "funk_jazz":
			var brush := _soft_noise(frame, 73 + seed) * _pulse_window(fposmod(t + 0.05, rate * 0.62), 0.0, 0.18) * 0.004
			var ride := sin(TAU * 880.0 * t) * _pulse_window(fposmod(t, rate), 0.0, 0.040) * 0.004
			var room := sin(TAU * 147.0 * t) * 0.0025 + sin(TAU * 196.0 * t) * 0.002
			if kind == "funk_jazz":
				room += sin(TAU * 98.0 * t) * _pulse_window(fposmod(t + 0.11, rate * 0.5), 0.0, 0.11) * 0.006
			return brush + ride + room
		"highway":
			var highway_wash := 0.5 + 0.5 * sin(TAU * rate * t)
			return (sin(TAU * 88.0 * t) * 0.004 + sin(TAU * 132.0 * t) * 0.002 + _soft_noise(frame, 43 + seed) * 0.002) * highway_wash
		"basement":
			var bulb := 0.5 + 0.5 * sin(TAU * rate * t)
			return sin(TAU * 32.0 * t) * 0.006 + sin(TAU * 97.0 * t) * 0.002 + bulb * sin(TAU * 388.0 * t) * 0.0015
		"boss":
			var camera_tick := _pulse_window(fposmod(t, rate * 4.0), 0.0, 0.035) * sin(TAU * 620.0 * t) * 0.004
			var floor_hum := sin(TAU * 41.0 * t) * 0.003 + sin(TAU * 82.0 * t) * 0.0015
			return floor_hum + camera_tick
		_:
			return 0.0


func _soft_noise(frame: int, seed: int) -> float:
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
	return value / (1.0 + (amount - 0.72) * 0.75)


func _safety_from_security(security: Dictionary) -> float:
	match str(security.get("strictness", "low")):
		"private":
			return 0.62
		"loose":
			return 0.70
		"low":
			return 0.78
		"uneven":
			return 0.32
		"high":
			return 0.14
		"elite":
			return 0.08
		_:
			return 0.50


func _theme_texture(theme: String) -> String:
	var lowered := theme.to_lower()
	if lowered.find("wet") != -1 or lowered.find("alley") != -1:
		return "rain"
	if lowered.find("bar") != -1 or lowered.find("local") != -1 or lowered.find("noisy") != -1:
		return "bar"
	if lowered.find("jazz") != -1 or lowered.find("sax") != -1 or lowered.find("funk") != -1:
		return "jazz"
	if lowered.find("quiet") != -1:
		return "static"
	if lowered.find("gas") != -1 or lowered.find("highway") != -1:
		return "highway"
	if lowered.find("underground") != -1 or lowered.find("basement") != -1 or lowered.find("tight") != -1:
		return "basement"
	if lowered.find("grand") != -1 or lowered.find("boss") != -1:
		return "boss"
	return "fluorescent"


func _theme_texture_rate(theme: String) -> float:
	match _theme_texture(theme):
		"rain":
			return 0.37
		"bar":
			return 0.31
		"jazz":
			return 0.46
		"funk_jazz":
			return 0.52
		"static":
			return 0.41
		"highway":
			return 0.27
		"basement":
			return 0.19
		"boss":
			return 0.15
		_:
			return 0.23


func _theme_swing_amount(theme: String) -> float:
	match _theme_texture(theme):
		"jazz":
			return 0.16
		"funk_jazz":
			return 0.12
		"bar":
			return 0.07
		"static":
			return 0.04
		_:
			return 0.0


func _theme_instrument_palette(theme: String) -> Dictionary:
	match _theme_texture(theme):
		"jazz", "funk_jazz":
			return {
				"id": "jazz_brushes_upright",
				"pad_warmth": 1.14,
				"pad_phaser": 0.06,
				"lead_detune": 0.05,
				"hat_softness": 0.72,
				"bass_weight": 1.12,
				"vibraphone": 0.18,
			}
		"boss":
			return {
				"id": "grand_casino_strings_vibes",
				"pad_warmth": 1.22,
				"pad_phaser": 0.02,
				"lead_detune": 0.02,
				"hat_softness": 0.86,
				"bass_weight": 1.04,
				"vibraphone": 0.42,
			}
		"bar", "basement":
			return {
				"id": "dive_dual_osc",
				"pad_warmth": 0.94,
				"pad_phaser": 0.18,
				"lead_detune": 0.32,
				"hat_softness": 0.92,
				"bass_weight": 1.08,
				"vibraphone": 0.04,
			}
		"static":
			return {
				"id": "motel_sparse_phaser",
				"pad_warmth": 0.82,
				"pad_phaser": 0.44,
				"lead_detune": 0.12,
				"hat_softness": 0.66,
				"bass_weight": 0.88,
				"vibraphone": 0.0,
			}
		_:
			return {
				"id": "casino_floor_straight",
				"pad_warmth": 1.0,
				"pad_phaser": 0.04,
				"lead_detune": 0.04,
				"hat_softness": 1.0,
				"bass_weight": 1.0,
				"vibraphone": 0.08,
			}


func _theme_bpm(theme: String) -> float:
	match _theme_texture(theme):
		"rain":
			return 74.0
		"bar":
			return 86.0
		"jazz":
			return 96.0
		"funk_jazz":
			return 108.0
		"static":
			return 78.0
		"highway":
			return 82.0
		"basement":
			return 76.0
		"boss":
			return 72.0
		_:
			return 82.0


func _theme_root_midi(theme: String) -> int:
	match _theme_texture(theme):
		"rain":
			return 43
		"bar":
			return 49
		"jazz", "funk_jazz":
			return 46
		"static":
			return 46
		"highway":
			return 48
		"basement":
			return 41
		"boss":
			return 40
		_:
			return 45


func _theme_ambience(theme: String) -> float:
	match _theme_texture(theme):
		"rain":
			return 0.86
		"bar":
			return 0.82
		"jazz", "funk_jazz":
			return 0.74
		"static":
			return 0.78
		"highway":
			return 0.66
		"basement":
			return 0.92
		"boss":
			return 0.96
		_:
			return 0.56


func _theme_mode(theme: String) -> String:
	match _theme_texture(theme):
		"rain":
			return "minor"
		"bar":
			return "dorian"
		"jazz", "funk_jazz":
			return "dorian"
		"static":
			return "harmonic_minor"
		"basement", "boss":
			return "phrygian"
		_:
			return "minor"


func _theme_progression(theme: String) -> Array:
	match _theme_texture(theme):
		"rain":
			return [0, 6, 5, 4]
		"bar":
			return [0, 6, 3, 5]
		"jazz":
			return [0, 3, 4, 5]
		"funk_jazz":
			return [0, 5, 3, 4]
		"static":
			return [0, 3, 5, 4]
		"highway":
			return [0, 2, 6, 3]
		"basement", "boss":
			return [0, 1, 5, 4]
		_:
			return DEFAULT_PROGRESSION.duplicate(true)


func _theme_motif(theme: String) -> Array:
	match _theme_texture(theme):
		"rain":
			return [EMPTY_NOTE, 4, EMPTY_NOTE, EMPTY_NOTE, 2, EMPTY_NOTE, 1, EMPTY_NOTE, 0, EMPTY_NOTE, EMPTY_NOTE, EMPTY_NOTE, 2, EMPTY_NOTE, 1, EMPTY_NOTE]
		"bar":
			return [0, EMPTY_NOTE, 2, EMPTY_NOTE, 4, EMPTY_NOTE, 5, EMPTY_NOTE, 4, EMPTY_NOTE, 2, EMPTY_NOTE, 0, EMPTY_NOTE, 6, EMPTY_NOTE]
		"jazz":
			return [0, EMPTY_NOTE, 3, 4, EMPTY_NOTE, 5, 4, EMPTY_NOTE, 2, EMPTY_NOTE, 4, 6, EMPTY_NOTE, 5, 3, EMPTY_NOTE]
		"funk_jazz":
			return [0, 2, EMPTY_NOTE, 3, 5, EMPTY_NOTE, 4, EMPTY_NOTE, 0, 3, EMPTY_NOTE, 5, 6, EMPTY_NOTE, 4, EMPTY_NOTE]
		"static":
			return [0, EMPTY_NOTE, 2, EMPTY_NOTE, 3, EMPTY_NOTE, 2, EMPTY_NOTE, 0, EMPTY_NOTE, EMPTY_NOTE, 4, 5, EMPTY_NOTE, 4, EMPTY_NOTE]
		"highway":
			return [0, EMPTY_NOTE, 4, EMPTY_NOTE, 2, EMPTY_NOTE, 6, EMPTY_NOTE, 4, EMPTY_NOTE, EMPTY_NOTE, 2, 3, EMPTY_NOTE, 2, EMPTY_NOTE]
		"basement":
			return [0, EMPTY_NOTE, 1, EMPTY_NOTE, 3, EMPTY_NOTE, 1, EMPTY_NOTE, 0, EMPTY_NOTE, 4, EMPTY_NOTE, 5, EMPTY_NOTE, 4, EMPTY_NOTE]
		"boss":
			return [0, EMPTY_NOTE, 1, EMPTY_NOTE, 4, EMPTY_NOTE, 3, EMPTY_NOTE, 1, EMPTY_NOTE, EMPTY_NOTE, 4, 5, EMPTY_NOTE, 6, EMPTY_NOTE]
		_:
			return DEFAULT_MOTIF.duplicate(true)


func _degree_array(value: Variant, fallback: Array = []) -> Array:
	var source := _number_array(value, fallback)
	var result: Array = []
	for entry in source:
		result.append(int(round(float(entry))))
	if result.is_empty():
		for fallback_entry in fallback:
			result.append(int(round(float(fallback_entry))))
	return result


func _number_array(value: Variant, fallback: Array = []) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return fallback.duplicate(true)
	var result: Array = []
	for entry in value as Array:
		result.append(float(entry))
	return result


static func _ensure_audio_bus(bus_name: String) -> int:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		return bus_index
	AudioServer.add_bus(AudioServer.get_bus_count())
	bus_index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	return bus_index


static func _ensure_music_stem_buses() -> Dictionary:
	var music_index := _ensure_audio_bus(MUSIC_BUS)
	var result := {}
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		var bus_name := _music_stem_bus_name(role)
		var bus_index := _ensure_audio_bus(bus_name)
		AudioServer.set_bus_send(bus_index, MUSIC_BUS)
		result[role] = {
			"bus": bus_name,
			"bus_index": bus_index,
			"send": MUSIC_BUS,
			"music_bus_index": music_index,
		}
	return result


static func music_stem_bus_graph_snapshot() -> Dictionary:
	var buses := {}
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		var bus_name := _music_stem_bus_name(role)
		var bus_index := AudioServer.get_bus_index(bus_name)
		buses[role] = {
			"bus": bus_name,
			"bus_index": bus_index,
			"send": AudioServer.get_bus_send(bus_index) if bus_index >= 0 else "",
		}
	return {
		"music_bus": MUSIC_BUS,
		"roles": MUSIC_STEM_PLAYBACK_ROLES.duplicate(true),
		"buses": buses,
	}


static func _music_fx_graph_matches(bus_index: int) -> bool:
	if bus_index < 0:
		return false
	if AudioServer.get_bus_effect_count(bus_index) != MUSIC_FX_EFFECT_ORDER.size():
		return false
	for index in range(MUSIC_FX_EFFECT_ORDER.size()):
		var effect := AudioServer.get_bus_effect(bus_index, index)
		if effect == null:
			return false
		var key := str(MUSIC_FX_EFFECT_ORDER[index])
		if effect.resource_name != _music_fx_resource_name(key):
			return false
		if effect.get_class() != str(MUSIC_FX_EFFECT_TYPES.get(key, "")):
			return false
	return true


static func _new_music_fx_effect(key: String) -> AudioEffect:
	match key:
		"low_pass":
			return AudioEffectLowPassFilter.new()
		"band_pass":
			return AudioEffectBandPassFilter.new()
		"delay":
			return AudioEffectDelay.new()
		"chorus":
			return AudioEffectChorus.new()
		"distortion":
			return AudioEffectDistortion.new()
		"reverb":
			return AudioEffectReverb.new()
		"compressor":
			return AudioEffectCompressor.new()
		"limiter":
			return AudioEffectLimiter.new()
		_:
			return AudioEffectLimiter.new()


static func _configure_music_fx_effect(key: String, effect: AudioEffect) -> void:
	match key:
		"low_pass":
			_set_effect_property(effect, "cutoff_hz", 18000.0)
			_set_effect_property(effect, "resonance", 0.18)
		"chorus":
			_set_effect_property(effect, "dry", 1.0)
			_set_effect_property(effect, "wet", 0.0)
			_set_effect_property(effect, "voice_count", 2)
			_set_effect_property(effect, "voice/1/depth_ms", 0.0)
			_set_effect_property(effect, "voice/2/depth_ms", 0.0)
		"band_pass":
			_set_effect_property(effect, "cutoff_hz", 1800.0)
			_set_effect_property(effect, "resonance", 0.35)
		"delay":
			_set_effect_property(effect, "dry", 0.0)
			_set_effect_property(effect, "tap1_active", true)
			_set_effect_property(effect, "tap1_delay_ms", 375.0)
			_set_effect_property(effect, "tap1_level_db", -7.0)
			_set_effect_property(effect, "tap1_pan", 0.24)
			_set_effect_property(effect, "tap2_active", true)
			_set_effect_property(effect, "tap2_delay_ms", 750.0)
			_set_effect_property(effect, "tap2_level_db", -13.0)
			_set_effect_property(effect, "tap2_pan", -0.22)
			_set_effect_property(effect, "feedback_active", true)
			_set_effect_property(effect, "feedback_delay_ms", 750.0)
			_set_effect_property(effect, "feedback_level_db", -15.0)
			_set_effect_property(effect, "feedback_lowpass", 7200.0)
		"distortion":
			_set_effect_property(effect, "drive", 0.0)
			_set_effect_property(effect, "pre_gain", 0.0)
			_set_effect_property(effect, "post_gain", 0.0)
			_set_effect_property(effect, "keep_hf_hz", 7200.0)
		"reverb":
			_set_effect_property(effect, "room_size", 0.20)
			_set_effect_property(effect, "damping", 0.72)
			_set_effect_property(effect, "wet", 1.0)
			_set_effect_property(effect, "dry", 0.0)
		"compressor":
			_set_effect_property(effect, "threshold", -6.0)
			_set_effect_property(effect, "ratio", 2.0)
			_set_effect_property(effect, "gain", 0.0)
			_set_effect_property(effect, "attack_us", 8500.0)
			_set_effect_property(effect, "release_ms", 220.0)
			_set_effect_property(effect, "mix", 1.0)
		"limiter":
			_set_effect_property(effect, "ceiling_db", -0.5)
			_set_effect_property(effect, "threshold_db", -0.7)
			_set_effect_property(effect, "soft_clip_db", 1.0)
			_set_effect_property(effect, "soft_clip_ratio", 8.0)


static func _set_music_fx_startup_enabled(bus_index: int) -> void:
	for index in range(MUSIC_FX_EFFECT_ORDER.size()):
		var key := str(MUSIC_FX_EFFECT_ORDER[index])
		AudioServer.set_bus_effect_enabled(bus_index, index, key == "limiter")


static func _set_music_fx_safety_enabled(bus_index: int) -> void:
	var limiter_index := _music_fx_effect_index(bus_index, "limiter")
	if limiter_index >= 0:
		AudioServer.set_bus_effect_enabled(bus_index, limiter_index, true)


static func _music_fx_effect_index(bus_index: int, key: String) -> int:
	if bus_index < 0:
		return -1
	var target_name := _music_fx_resource_name(key)
	for index in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect := AudioServer.get_bus_effect(bus_index, index)
		if effect != null and effect.resource_name == target_name:
			return index
	return -1


static func _music_fx_resource_name(key: String) -> String:
	return "%s:%s:v%d" % [MUSIC_FX_RESOURCE_PREFIX, key, MUSIC_FX_GRAPH_VERSION]


static func _music_stem_bus_name(role: String) -> String:
	return "%s_%s" % [MUSIC_STEM_BUS_PREFIX, role]


static func _music_send_bus_name(effect_key: String) -> String:
	return "%s_%s" % [MUSIC_SEND_BUS_PREFIX, effect_key]


static func _step_period_from_bpm(bpm: float) -> float:
	return 60.0 / maxf(1.0, bpm) * 0.5


func _music_director_bar_seconds() -> float:
	if not _current_music_context.is_empty():
		return maxf(0.001, float(_current_music_context.get("step_period", 0.36)) * float(STEPS_PER_BAR))
	if not _current_stem_set.is_empty():
		return maxf(0.001, _step_period_from_bpm(float(_current_stem_set.get("bpm", 82.0))) * float(STEPS_PER_BAR))
	return _step_period_from_bpm(82.0) * float(STEPS_PER_BAR)


func _music_director_step_seconds() -> float:
	if not _current_music_context.is_empty():
		return maxf(0.001, float(_current_music_context.get("step_period", 0.36)))
	if not _current_stem_set.is_empty():
		return maxf(0.001, _step_period_from_bpm(float(_current_stem_set.get("bpm", 82.0))))
	return _step_period_from_bpm(82.0)


func _music_is_playing() -> bool:
	if WebAudioBridgeScript.available() and not _current_stem_set.is_empty():
		return true
	for player_value in _stem_players.values():
		if player_value is AudioStreamPlayer and (player_value as AudioStreamPlayer).playing:
			return true
	return _ambient_player != null and _ambient_player.playing


func _director_playback_position() -> float:
	if WebAudioBridgeScript.available() and not _current_stem_set.is_empty():
		var started_msec := int(_current_stem_set.get("started_ticks_msec", 0))
		var loop_frames := int(_current_stem_set.get("loop_frames", 0))
		var sample_rate := maxi(1, int(_current_stem_set.get("sample_rate", SAMPLE_RATE)))
		var duration := float(loop_frames) / float(sample_rate)
		if started_msec > 0 and duration > 0.0:
			var elapsed := maxf(0.0, float(Time.get_ticks_msec() - started_msec) / 1000.0)
			return fposmod(float(_current_stem_set.get("started_position", 0.0)) + elapsed, duration)
	for role_value in MUSIC_STEM_PLAYBACK_ROLES:
		var role := str(role_value)
		var player: AudioStreamPlayer = _stem_players.get(role, null)
		if player != null and player.playing:
			return maxf(0.0, player.get_playback_position())
	if _ambient_player != null and _ambient_player.playing:
		return maxf(0.0, _ambient_player.get_playback_position())
	return 0.0


static func _gain_to_db(gain: float) -> float:
	var safe_gain := maxf(0.0, gain)
	if safe_gain <= 0.0001:
		return MUSIC_MIN_VOLUME_DB
	return clampf(linear_to_db(safe_gain), MUSIC_MIN_VOLUME_DB, 6.0)


static func _set_effect_property(effect: AudioEffect, property_name: String, value: Variant) -> void:
	if effect == null:
		return
	var effect_class := effect.get_class()
	var property_names: Dictionary = _effect_property_name_cache.get(effect_class, {})
	if property_names.is_empty():
		for property_value in effect.get_property_list():
			if typeof(property_value) == TYPE_DICTIONARY:
				property_names[str((property_value as Dictionary).get("name", ""))] = true
		_effect_property_name_cache[effect_class] = property_names
	if bool(property_names.get(property_name, false)):
		effect.set(property_name, value)


static func _copy_dict_static(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


static func _copy_array_static(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value.duplicate(true)


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return value.duplicate(true)


func _stable_hash(text: String) -> int:
	var value := 2166136261
	for index in range(text.length()):
		value = int((value ^ text.unicode_at(index)) * 16777619) & 0x7fffffff
	return value
