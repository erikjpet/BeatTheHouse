class_name ProceduralMusicPlayer
extends Node

# Procedural background music for the foundation UI.
# The synth shape is ported from the old baseline: generated PCM WAV themes,
# cached per room/heat profile, played through the Music bus.

const MUSIC_BUS := "Music"
const AMBIENT_VERSION := 7
const SAMPLE_RATE := 22050
const EMPTY_NOTE := -999.0
const BASE_PHRASE_STEPS := 32
const PRIMER_STEPS := 8
const INSTANT_BED_SECONDS := 1.25
const DEFAULT_ARRANGEMENT_PHRASES := 4
const MIN_ARRANGEMENT_PHRASES := 2
const MAX_ARRANGEMENT_PHRASES := 6
const TRANSITION_BREAK_STEPS := 8
const TRANSITION_BREAK_WINDOW_SECONDS := 0.10
const PCM_BYTES_PER_FRAME := 2
const GENERATION_CANCEL_CHECK_FRAMES := 4096
const AMBIENT_STAGE_PRIMER := "primer"
const AMBIENT_STAGE_FULL := "full"
const SCALE_MINOR := [0, 2, 3, 5, 7, 8, 10]
const SCALE_DORIAN := [0, 2, 3, 5, 7, 9, 10]
const SCALE_PHRYGIAN := [0, 1, 3, 5, 7, 8, 10]
const SCALE_HARMONIC_MINOR := [0, 2, 3, 5, 7, 8, 11]
const DEFAULT_PROGRESSION := [0, 5, 2, 6]
const DEFAULT_MOTIF := [0, EMPTY_NOTE, 2, EMPTY_NOTE, 4, EMPTY_NOTE, 2, EMPTY_NOTE, 0, EMPTY_NOTE, 3, EMPTY_NOTE, 4, EMPTY_NOTE, 2, EMPTY_NOTE]

var audio_enabled: bool = true

var _ambient_player: AudioStreamPlayer
var _ambient_stream_cache: Dictionary = {}
var _ambient_primer_cache: Dictionary = {}
var _ambient_instant_cache: Dictionary = {}
var _ambient_profile_cache: Dictionary = {}
var _current_cache_key: String = ""
var _current_stream_is_primer: bool = false
var _current_music_context: Dictionary = {}
var _pending_cache_key: String = ""
var _transition_target_cache_key: String = ""
var _transition_target_profile: Dictionary = {}
var _deferred_transition_cache_key: String = ""
var _deferred_transition_stream: AudioStreamWAV
var _generation_token: int = 0
var _generation_mutex: Mutex = Mutex.new()
var _generation_thread: Thread
var _thread_cache_key: String = ""
var _thread_token: int = 0
var _thread_stage: String = ""
var _queued_generation_profile: Dictionary = {}
var _queued_generation_cache_key: String = ""
var _queued_generation_token: int = 0


func _ready() -> void:
	if not _running_headless():
		_ensure_player()


func _process(_delta: float) -> void:
	_poll_generation_thread()
	_poll_breakpoint_transition()


func _exit_tree() -> void:
	stop()
	_join_generation_thread()
	_ambient_stream_cache.clear()
	_ambient_primer_cache.clear()
	_ambient_instant_cache.clear()
	_ambient_profile_cache.clear()


# Starts or updates the generated theme for the current environment.
func play_for_environment(environment: Dictionary, heat_level: int) -> void:
	if not audio_enabled or environment.is_empty() or _running_headless():
		stop()
		return
	_ensure_player()
	var profile := _music_profile_from_environment(environment, heat_level)
	var cache_key := _ambient_cache_key(profile)
	_remember_profile(cache_key, profile)
	if cache_key == _current_cache_key and _ambient_player.playing and not _current_stream_is_primer:
		return
	if _should_defer_music_change(cache_key):
		_schedule_breakpoint_music_change(profile, cache_key)
		return
	if _ambient_stream_cache.has(cache_key):
		_play_full_stream(cache_key, _ambient_stream_cache[cache_key])
		return
	if _pending_cache_key == cache_key:
		if _current_cache_key != cache_key and _ambient_instant_cache.has(cache_key):
			_play_primer_stream(cache_key, _ambient_instant_cache[cache_key])
		return
	_pending_cache_key = cache_key
	var token := _advance_generation_token()
	_play_instant_bed(profile, cache_key)
	_request_ambient_generation(profile, cache_key, token)


# Stops current music without clearing generated stream cache.
func stop() -> void:
	_current_cache_key = ""
	_current_stream_is_primer = false
	_pending_cache_key = ""
	_transition_target_cache_key = ""
	_transition_target_profile = {}
	_deferred_transition_cache_key = ""
	_deferred_transition_stream = null
	_advance_generation_token()
	_queued_generation_profile = {}
	_queued_generation_cache_key = ""
	_queued_generation_token = 0
	if _ambient_player == null:
		return
	_ambient_player.stop()
	_ambient_player.stream = null
	_current_music_context = {}


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
		"motif": (context.get("motif", []) as Array).duplicate(true),
		"phrase_count": int(context.get("phrase_count", 0)),
	}


# Exposes staged live-generation sizing for validation without starting threads.
func music_generation_latency_snapshot_for_environment(environment: Dictionary, heat_level: int) -> Dictionary:
	if environment.is_empty():
		return {}
	var context := _ambient_generation_context(_music_profile_from_environment(environment, heat_level))
	var full_frames := int(context.get("frames", 0))
	var primer_context := _primer_context(context)
	var primer_frames := int(primer_context.get("frames", 0))
	var instant_frames := int(INSTANT_BED_SECONDS * float(SAMPLE_RATE))
	return {
		"full_frames": full_frames,
		"full_seconds": float(full_frames) / float(SAMPLE_RATE),
		"instant_frames": instant_frames,
		"instant_seconds": INSTANT_BED_SECONDS,
		"primer_frames": primer_frames,
		"primer_seconds": float(primer_frames) / float(SAMPLE_RATE),
		"primer_steps": PRIMER_STEPS,
	}


# Exposes the live transition policy for validation and tuning.
func music_transition_policy_snapshot_for_environment(environment: Dictionary, heat_level: int) -> Dictionary:
	if environment.is_empty():
		return {}
	var context := _ambient_generation_context(_music_profile_from_environment(environment, heat_level))
	var step_period := float(context.get("step_period", 0.36))
	return {
		"deferred_stream_changes": true,
		"break_steps": TRANSITION_BREAK_STEPS,
		"break_seconds": step_period * float(TRANSITION_BREAK_STEPS),
		"break_window_seconds": TRANSITION_BREAK_WINDOW_SECONDS,
	}


func _ensure_player() -> void:
	if _ambient_player != null:
		return
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = MUSIC_BUS
	add_child(_ambient_player)


func _running_headless() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"


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

	var heat := clampi(heat_level, 0, 100)
	var heat_pressure := float(heat) / 100.0
	var heat_band := clampi(int(floor(float(heat) / 10.0)), 0, 10)
	var base_safety := clampf(float(source.get("safety", _safety_from_security(security))), 0.0, 1.0)
	var effective_safety := clampf(base_safety - heat_pressure * 0.42, 0.02, 0.98)
	var base_bpm := float(source.get("bpm", _theme_bpm(theme)))
	var bpm := clampf(base_bpm + heat_pressure * 10.0 + (1.0 - base_safety) * 3.0, 58.0, 112.0)
	var seed := _stable_hash("%s:%s:%s:%d" % [
		str(environment.get("id", "")),
		str(environment.get("archetype_id", "")),
		theme,
		heat_band,
	])

	var profile := {
		"environment_id": str(environment.get("id", "")),
		"archetype_id": str(environment.get("archetype_id", "")),
		"theme": theme,
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
		"heat_pressure": heat_pressure,
		"heat_band": heat_band,
		"volume": float(source.get("volume", 0.26)),
		"arrangement_phrases": clampi(int(source.get("arrangement_phrases", DEFAULT_ARRANGEMENT_PHRASES)), MIN_ARRANGEMENT_PHRASES, MAX_ARRANGEMENT_PHRASES),
	}
	profile["progression"] = _number_array(source.get("progression", _theme_progression(theme)), _theme_progression(theme))
	profile["motif"] = _number_array(source.get("motif", _theme_motif(theme)), _theme_motif(theme))
	return profile


func _ambient_cache_key(profile: Dictionary) -> String:
	return "ambient:%d:%s:%s:%s:%s:%d:%d:%d:%s:%s" % [
		AMBIENT_VERSION,
		str(profile.get("environment_id", "")),
		str(profile.get("archetype_id", "")),
		str(profile.get("theme", "")),
		str(profile.get("mode", "")),
		int(profile.get("heat_band", 0)),
		int(profile.get("root_midi", 0)),
		int(profile.get("arrangement_phrases", DEFAULT_ARRANGEMENT_PHRASES)),
		JSON.stringify(profile.get("progression", [])),
		JSON.stringify(profile.get("motif", [])),
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
			_play_primer_stream(cache_key, _ambient_primer_cache[cache_key])
		_queued_generation_profile = profile.duplicate(true)
		_queued_generation_cache_key = cache_key
		_queued_generation_token = token
		return
	if _ambient_primer_cache.has(cache_key):
		_play_primer_stream(cache_key, _ambient_primer_cache[cache_key])
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
	var data := _ambient_pcm_data(context, token)
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
		"data": data,
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
		_accept_full_stream(cache_key, _ambient_stream_cache[cache_key])
		return
	_request_ambient_generation(profile, cache_key, token)


func _apply_generated_ambient_data(result: Dictionary) -> void:
	if bool(result.get("cancelled", false)):
		return
	var cache_key := str(result.get("cache_key", ""))
	var token := int(result.get("token", 0))
	if cache_key.is_empty() or token != _current_generation_token() or cache_key != _pending_cache_key:
		return
	var frames := int(result.get("frames", 0))
	var data: PackedByteArray = result.get("data", PackedByteArray())
	if frames <= 0 or data.is_empty():
		_pending_cache_key = ""
		return
	var stage := str(result.get("stage", AMBIENT_STAGE_FULL))
	var stream := _ambient_stream_from_data(data, frames)
	if stage == AMBIENT_STAGE_PRIMER:
		_ambient_primer_cache[cache_key] = stream
		_play_primer_stream(cache_key, stream)
		var profile: Dictionary = result.get("profile", {})
		if profile.is_empty():
			_pending_cache_key = ""
			return
		_start_ambient_generation(profile, cache_key, token, AMBIENT_STAGE_FULL)
		return
	_ambient_stream_cache[cache_key] = stream
	_accept_full_stream(cache_key, stream)


func _ambient_pcm_data(context: Dictionary, token: int = -1) -> PackedByteArray:
	var frames := int(context.get("frames", 0))
	var data := PackedByteArray()
	data.resize(maxi(0, frames * PCM_BYTES_PER_FRAME))
	for i in range(frames):
		if token > 0 and i % GENERATION_CANCEL_CHECK_FRAMES == 0 and _generation_was_cancelled(token):
			return PackedByteArray()
		_write_ambient_frame(data, context, i)
	return data


func _remember_profile(cache_key: String, profile: Dictionary) -> void:
	if cache_key.is_empty() or profile.is_empty():
		return
	_ambient_profile_cache[cache_key] = profile.duplicate(true)


func _should_defer_music_change(cache_key: String) -> bool:
	if cache_key.is_empty() or cache_key == _current_cache_key:
		return false
	if _ambient_player == null or not _ambient_player.playing:
		return false
	return not _current_cache_key.is_empty()


func _schedule_breakpoint_music_change(profile: Dictionary, cache_key: String) -> void:
	if cache_key.is_empty():
		return
	_remember_profile(cache_key, profile)
	if cache_key == _transition_target_cache_key:
		if _ambient_stream_cache.has(cache_key):
			_set_deferred_transition_stream(cache_key, _ambient_stream_cache[cache_key])
		return
	_transition_target_cache_key = cache_key
	_transition_target_profile = profile.duplicate(true)
	_deferred_transition_cache_key = ""
	_deferred_transition_stream = null
	_pending_cache_key = cache_key
	var token := _advance_generation_token()
	if _ambient_stream_cache.has(cache_key):
		_set_deferred_transition_stream(cache_key, _ambient_stream_cache[cache_key])
		return
	_start_ambient_generation(profile, cache_key, token, AMBIENT_STAGE_FULL)


func _accept_full_stream(cache_key: String, stream: AudioStreamWAV) -> void:
	if cache_key == _transition_target_cache_key and _should_defer_music_change(cache_key):
		_set_deferred_transition_stream(cache_key, stream)
		return
	_play_full_stream(cache_key, stream)


func _set_deferred_transition_stream(cache_key: String, stream: AudioStreamWAV) -> void:
	if stream == null:
		return
	_deferred_transition_cache_key = cache_key
	_deferred_transition_stream = stream


func _poll_breakpoint_transition() -> void:
	if _deferred_transition_cache_key.is_empty() or _deferred_transition_stream == null:
		return
	if not _ready_for_music_breakpoint():
		return
	var cache_key := _deferred_transition_cache_key
	var stream := _deferred_transition_stream
	_deferred_transition_cache_key = ""
	_deferred_transition_stream = null
	_transition_target_cache_key = ""
	_transition_target_profile = {}
	_play_full_stream(cache_key, stream)


func _ready_for_music_breakpoint() -> bool:
	if _ambient_player == null or not _ambient_player.playing:
		return true
	if _current_music_context.is_empty():
		return true
	var step_period := float(_current_music_context.get("step_period", 0.36))
	var break_period := maxf(0.25, step_period * float(TRANSITION_BREAK_STEPS))
	var position := _ambient_player.get_playback_position()
	var phase := fposmod(position, break_period)
	return phase <= TRANSITION_BREAK_WINDOW_SECONDS or phase >= break_period - TRANSITION_BREAK_WINDOW_SECONDS


func _remember_current_music_context(cache_key: String) -> void:
	var profile: Dictionary = _ambient_profile_cache.get(cache_key, {})
	if profile.is_empty():
		_current_music_context = {}
		return
	_current_music_context = _ambient_generation_context(profile)


func _play_instant_bed(profile: Dictionary, cache_key: String) -> void:
	if _ambient_player == null:
		return
	if not _ambient_instant_cache.has(cache_key):
		_ambient_instant_cache[cache_key] = _instant_bed_stream(profile)
	_play_primer_stream(cache_key, _ambient_instant_cache[cache_key])


func _instant_bed_stream(profile: Dictionary) -> AudioStreamWAV:
	var context := _ambient_generation_context(profile)
	var frames := maxi(1, int(INSTANT_BED_SECONDS * float(SAMPLE_RATE)))
	var data := _instant_bed_pcm_data(context, frames)
	return _ambient_stream_from_data(data, frames)


func _instant_bed_pcm_data(context: Dictionary, frames: int) -> PackedByteArray:
	var root_midi := int(context.get("root_midi", 45))
	var chord_roots: Array = context.get("chord_roots", [0])
	var chord_root := root_midi
	if not chord_roots.is_empty():
		chord_root += int(chord_roots[0])
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
		var pad := _music_pad(chord_root, t) * pad_gain
		var texture := _ambient_texture_sample(texture_kind, texture_rate, t, i, texture_seed) * texture_gain
		_write_i16(data, i * PCM_BYTES_PER_FRAME, _soft_limit((pad + texture) * volume * loop_edge))
	return data


func _primer_context(context: Dictionary) -> Dictionary:
	var primer := context.duplicate(true)
	var step_period := float(primer.get("step_period", 0.36))
	var full_frames := int(primer.get("frames", 0))
	var primer_frames := mini(full_frames, maxi(1, int(step_period * float(PRIMER_STEPS) * float(SAMPLE_RATE))))
	primer["frames"] = primer_frames
	primer["duration"] = float(primer_frames) / float(SAMPLE_RATE)
	return primer


func _play_primer_stream(cache_key: String, stream: AudioStreamWAV) -> void:
	if _ambient_player == null:
		return
	_current_cache_key = cache_key
	_current_stream_is_primer = true
	_remember_current_music_context(cache_key)
	_ambient_player.stream = stream
	_ambient_player.play()


func _play_full_stream(cache_key: String, stream: AudioStreamWAV) -> void:
	_pending_cache_key = ""
	var resume_position := 0.0
	if _ambient_player != null and _ambient_player.playing and _current_cache_key == cache_key and _current_stream_is_primer:
		resume_position = maxf(0.0, _ambient_player.get_playback_position())
	if _ambient_player == null:
		return
	_current_cache_key = cache_key
	_current_stream_is_primer = false
	_remember_current_music_context(cache_key)
	_ambient_player.stream = stream
	_ambient_player.play(resume_position)


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
	var variation_seed := int(profile.get("texture_seed", 0)) + int(profile.get("heat_band", 0)) * 37 + _stable_hash(str(profile.get("theme", ""))) % 4099
	return {
		"beat_period": beat_period,
		"step_period": step_period,
		"phrase_steps": phrase_steps,
		"phrase_count": phrase_count,
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
		"motif": motif,
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
	var motif: Array = context.get("motif", DEFAULT_MOTIF)
	var texture_kind := str(context.get("texture_kind", "fluorescent"))
	var texture_rate := float(context.get("texture_rate", 0.33))
	var texture_seed := int(context.get("texture_seed", 0))
	var variation_seed := int(context.get("variation_seed", texture_seed))
	var t := float(frame_index) / float(SAMPLE_RATE)
	var step_index := int(t / step_period) % total_steps
	var step_local := fposmod(t, step_period)
	var phrase_index := int(step_index / phrase_steps) % maxi(1, phrase_count)
	var phrase_step := step_index % phrase_steps
	var bar_index := int(phrase_step / 8) % maxi(1, chord_roots.size())
	var beat_step := phrase_step % 8
	var chord_root := root_midi + int(chord_roots[bar_index])
	var phrase_energy := _phrase_energy(phrase_index, phrase_count, danger)
	var pad := _music_pad(chord_root, t) * pad_gain * lerpf(0.94, 1.06, phrase_energy)
	var bass := 0.0
	var bass_offset := _bass_offset_for_step(scale, progression_degrees, chord_roots, bar_index, beat_step, phrase_index, phrase_count, variation_seed)
	if bass_offset > -900:
		bass = _music_bass(_midi_freq(root_midi + bass_offset), step_local) * bass_gain * lerpf(0.92, 1.13, phrase_energy)
	var lead := 0.0
	var lead_offset := _lead_offset_for_step(scale, progression_degrees, motif, bar_index, phrase_step, phrase_index, phrase_count, variation_seed)
	if lead_offset > -900:
		lead = _music_lead(_midi_freq(root_midi + lead_offset), step_local) * lead_gain * lerpf(0.70, 1.28, phrase_energy)
	var drums := _music_drums(beat_step, step_local, step_period, frame_index + texture_seed, phrase_index, phrase_count, variation_seed) * drum_gain
	var heartbeat := _heartbeat_shape(fposmod(t, beat_period), beat_period) * heartbeat_gain
	var texture := _ambient_texture_sample(texture_kind, texture_rate, t, frame_index, texture_seed) * texture_gain
	var siren := _music_siren(t) * siren_gain
	var loop_edge := _loop_edge_envelope(t, duration)
	var mixed := (pad + bass + lead + drums + heartbeat + texture + siren) * volume * loop_edge
	_write_i16(data, frame_index * PCM_BYTES_PER_FRAME, _soft_limit(mixed))


func _ambient_stream_from_data(data: PackedByteArray, frames: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	return stream


func _midi_freq(midi_note: int) -> float:
	return 440.0 * pow(2.0, float(midi_note - 69) / 12.0)


func _phrase_energy(phrase_index: int, phrase_count: int, danger: float) -> float:
	if phrase_count <= 1:
		return 0.5
	var progress := float(phrase_index) / float(maxi(1, phrase_count - 1))
	var wave := 0.5 + 0.5 * sin(PI * progress)
	var heat_lift := clampf(danger, 0.0, 1.0) * 0.22
	return clampf(progress * 0.58 + wave * 0.32 + heat_lift, 0.0, 1.0)


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
	var usable_progression := progression
	if usable_progression.is_empty():
		usable_progression = DEFAULT_PROGRESSION
	for degree_value in usable_progression:
		var degree := int(degree_value)
		roots.append(_scale_degree_offset(degree, scale))
		intervals.append(_chord_intervals_for_degree(degree, scale))
	return {
		"roots": roots,
		"intervals": intervals,
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


func _lead_offset_for_step(scale: Array, progression: Array, motif: Array, bar_index: int, phrase_step: int, phrase_index: int, phrase_count: int, seed: int) -> int:
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


func _music_bass(freq: float, local_t: float) -> float:
	var env := _note_decay(local_t, 0.020, 0.54)
	var phase := TAU * freq * local_t
	return (sin(phase) * 0.78 + sin(phase * 2.0) * 0.10 + sin(phase * 0.5) * 0.14) * env


func _music_lead(freq: float, local_t: float) -> float:
	var env := _note_decay(local_t, 0.018, 0.30)
	var phase := TAU * freq * local_t
	var soft_square := sin(phase) * 0.82 + sin(phase * 3.0) * 0.08 + sin(phase * 5.0) * 0.03
	return soft_square * env


func _music_drums(beat_step: int, local_t: float, step_period: float, frame: int, phrase_index: int, phrase_count: int, seed: int) -> float:
	var drums := 0.0
	if beat_step == 0:
		drums += _music_kick(local_t) * 0.62
	elif beat_step == 1:
		drums += _music_kick(local_t) * 0.20
	elif beat_step == 4:
		drums += _music_snare(local_t, frame) * 0.18
	if phrase_index > 0 and beat_step == 6 and ((seed + phrase_index) % 2 == 0):
		drums += _music_snare(local_t, frame + seed) * 0.10
	if phrase_index == phrase_count - 1 and beat_step == 7:
		drums += _music_hat(local_t, step_period, frame + seed) * 0.13
	if beat_step % 2 == 1:
		drums += _music_hat(local_t, step_period, frame) * 0.07
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
	if lowered.find("motel") != -1 or lowered.find("quiet") != -1:
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


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value.duplicate(true)


func _stable_hash(text: String) -> int:
	var value := 2166136261
	for index in range(text.length()):
		value = int((value ^ text.unicode_at(index)) * 16777619) & 0x7fffffff
	return value
