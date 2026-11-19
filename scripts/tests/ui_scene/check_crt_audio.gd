extends SceneTree

# Native rendered acceptance, launched only in a fresh maintained E: QA Job.
# AudioEffectCapture records this game's Master effect input before its fader.
# Separate AudioServer Master meters observe post-fader/post-mute output. Neither
# is an OS system-loopback recording or evidence of physical speaker output.

const MainScene := preload("res://scenes/main.tscn")
const APPROVED_ROOT := "e:/codexqa/bth/"
const CAPTURE_SECONDS := 42
const MAX_MIX_RATE := 48000
const CHUNK_FRAMES := 4096
const MUSIC_READY_TIMEOUT_MSEC := 60000
const CRT_MASTER_PATH := "res://assets/audio/music_features/crt_title_v3/master.wav"
const CRT_MASTER_SHA256 := "2412bb82073f500b68cd9a1f95988da970af141282f1dbe15cb077c67ff30028"
const CRT_MASTER_RATE := 44100
const CRT_MASTER_FRAMES := 1512000
const CRT_MASTER_SECONDS := 1512000.0 / 44100.0

var app: Control
var menu: Control
var player: Node
var settings: RefCounted
var original_volumes := {}
var capture: AudioEffectCapture
var capture_slot := -1
var master_bus := -1
var mix_rate := 0
var evidence_dir := ""
var wav: FileAccess
var wav_path := ""
var wav_frames := 0
var started_msec := 0
var checks := 0
var failures: Array[String] = []
var phases: Array[Dictionary] = []
var owners: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var selection_events := 0
var metadata := {}
var stream_receipts: Dictionary = {}
var approved_master_pcm_sha256 := ""
var fixed_master_cache_key := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	started_msec = Time.get_ticks_msec()
	if not _guarded_environment():
		_finish()
		return
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "crt_audio_capture_fresh")
	root.add_child(app)
	await _frames(4)
	_check(not bool(app.call("_has_foundation_save")), "Fresh disposable slot has no Continue save.")
	_check(app.get("run_state") == null and str(app.get("current_screen")) == "START", "Production MainScene starts at the title without a run.")
	settings = app.get("user_settings") as RefCounted
	player = app.get("procedural_music_player") as Node
	if settings == null or player == null or not failures.is_empty():
		_check(settings != null and player != null, "Production settings and procedural Music player exist.")
		_finish()
		return
	original_volumes = {"master": settings.get("master_volume"), "music": settings.get("music_volume"), "sfx": settings.get("sfx_volume")}
	master_bus = AudioServer.get_bus_index("Master")
	mix_rate = int(AudioServer.get_mix_rate())
	metadata = {
		"driver": AudioServer.get_driver_name(), "output_device": AudioServer.get_output_device(),
		"display_driver": DisplayServer.get_name(), "mix_rate": mix_rate,
		"speaker_mode": AudioServer.get_speaker_mode(), "original_volumes": original_volumes.duplicate(),
		"capture_point": "Master AudioEffectCapture, before Master volume/mute; stereo PCM16 WAV",
		"meter_point": "AudioServer Master bus peak, after Master volume/mute",
		"claim_limit": "Game-owned bus capture and engine output meter only; no OS loopback or physical speaker claim.",
		"reference_master": {"path": CRT_MASTER_PATH, "sha256": CRT_MASTER_SHA256, "sample_rate": CRT_MASTER_RATE, "channels": 2, "bits": 16, "frames": CRT_MASTER_FRAMES, "seconds": CRT_MASTER_SECONDS, "bpm": 112, "bars": 16},
		"loop_seam_verification": "Pending offline reference/capture alignment; live wrap observations alone do not establish waveform continuity.",
	}
	_check(AudioServer.get_driver_name().to_lower() == "wasapi", "Native v3 acceptance uses the actual WASAPI driver.")
	_check(master_bus >= 0 and mix_rate == MAX_MIX_RATE, "Master capture uses the declared 48kHz native output mix rate.")
	_check(FileAccess.get_sha256(CRT_MASTER_PATH) == CRT_MASTER_SHA256, "The source master exactly matches the approved v3 SHA256.")
	var master_reference := AudioStreamWAV.load_from_file(CRT_MASTER_PATH)
	_check(master_reference != null and master_reference.mix_rate == CRT_MASTER_RATE and master_reference.stereo and master_reference.format == AudioStreamWAV.FORMAT_16_BITS and master_reference.data.size() == CRT_MASTER_FRAMES * 4, "The source master has the approved complete stereo PCM16 frame contract.")
	if master_reference != null:
		approved_master_pcm_sha256 = _sha256_bytes(master_reference.data)
		metadata["reference_master"]["pcm_sha256"] = approved_master_pcm_sha256
	_check(AudioServer.get_speaker_mode() == AudioServer.SPEAKER_MODE_STEREO, "This capture explicitly requires stereo output.")
	_check(is_equal_approx(float(settings.get("master_volume")), 1.0), "Fresh default Master setting is unity.")
	_check(float(settings.get("music_volume")) > 0.0, "Fresh default Music setting is audible.")
	_check(not AudioServer.is_bus_mute(master_bus) and absf(AudioServer.get_bus_volume_db(master_bus)) < 0.001, "Fresh default Master bus is unmuted at 0 dB.")
	for index in range(AudioServer.get_bus_count()):
		_check(not AudioServer.is_bus_solo(index), "Fresh audio has no solo bus overriding normal mute semantics: %s." % AudioServer.get_bus_name(index))
	if not failures.is_empty():
		_finish()
		return
	# Apply the production mix settings; the main recording excludes every SFX.
	_set_volumes(1.0, float(original_volumes["music"]), 0.0)
	if not await _click(app.get("game_library_button") as Control, "Title Games"):
		_finish()
		return
	menu = app.get("game_test_menu") as Control
	_check(menu != null and menu.is_visible_in_tree() and str(app.get("current_screen")) == "CRT", "Actual title Games mouse input opens CRT.")
	if menu == null or not failures.is_empty():
		_finish()
		return
	menu.connect("user_selection_changed", _on_selection_changed)
	if not await _wait_for_crt_music("initial CRT"):
		_finish()
		return
	_check(AudioServer.get_bus_channels(master_bus) == 1, "Master exposes one stereo channel pair.")
	if not failures.is_empty():
		_finish()
		return
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.75
	capture_slot = AudioServer.get_bus_effect_count(master_bus)
	AudioServer.add_bus_effect(master_bus, capture, capture_slot)
	await _frames(4)
	metadata["unity_recording_state"] = _bus_state()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty(), "CRT has an actual rendered game viewport.")
	if image != null and not image.is_empty():
		_check(image.save_png(evidence_dir.path_join("crt-audio-native.png")) == OK, "Rendered CRT image saves to fresh QA evidence.")
	wav_path = evidence_dir.path_join("crt-music-master-pregain-42s.wav")
	wav = FileAccess.open(wav_path, FileAccess.WRITE)
	_check(wav != null, "Fresh streaming PCM WAV opens in guarded evidence.")
	if wav == null or not failures.is_empty():
		_finish()
		return
	wav.big_endian = false
	_write_wav_header(0)
	var music := await _collect("music_only_42_seconds", float(CAPTURE_SECONDS), true)
	_close_wav()
	_check(int(music["frames"]) == CAPTURE_SECONDS * mix_rate, "The streamed WAV contains exactly 42 seconds of stereo audio.")
	_check(float(music["rms"]) > 0.00001, "Music is nonzero while the SFX bus is muted.")
	_check(float(music["max_master_peak_db"]) > -80.0, "Unmuted unity Master also reports nonzero post-gain output.")
	_check(bool(app.get("crt_music_owner_active")), "CRT retains Music ownership throughout its full loop capture.")
	_owner("after full loop")
	_set_volumes(1.0, 0.0, 1.0)
	await _frames(20)
	var before_selection := selection_events
	var sfx := await _collect("sfx_only_actual_keyboard_selection", 1.6, false, true)
	_check(selection_events > before_selection, "Actual keyboard input changes CRT selection and emits user selection events.")
	_check(float(sfx["rms"]) > 0.00001, "Movement SFX is nonzero while the Music bus is muted.")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Music-zero production settings hard-mute the Music bus.")
	_set_volumes(0.0, float(original_volumes["music"]), 0.0)
	await _frames(20)
	var muted := await _collect("master_zero_hard_mute", 0.6)
	_check(AudioServer.is_bus_mute(master_bus), "Master-zero production settings hard-mute Master.")
	_check(float(muted["max_master_peak_db"]) <= -80.0, "Master-zero has silent post-gain AudioServer output meters.")
	# Raw pre-fader PCM is deliberately not required to vanish under Master mute.
	_restore_volumes()
	await _frames(4)
	await _practice_return_and_exit()
	_finish()


func _guarded_environment() -> bool:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		_check(false, "Native audio capture requires a rendered native display.")
		return false
	for key in ["BTH_QA_WORKSPACE", "BTH_QA_RUN_DIR", "BTH_QA_PROFILE_DIR", "BTH_SAVE_DIR", "BTH_USER_SETTINGS_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_QA_EVIDENCE_DIR"]:
		if not _approved_path(OS.get_environment(key)):
			_check(false, "Missing approved fresh E: QA path: %s." % key)
			return false
	if not _approved_path(ProjectSettings.globalize_path("res://")) or not _approved_path(OS.get_user_data_dir()):
		_check(false, "Project and user data must remain inside the guarded E: QA root.")
		return false
	for key in ["BTH_USER_SETTINGS_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH"]:
		if FileAccess.file_exists(OS.get_environment(key)):
			_check(false, "Native capture requires a fresh disposable profile: %s already exists." % key)
			return false
	evidence_dir = OS.get_environment("BTH_QA_EVIDENCE_DIR").replace("\\", "/").simplify_path()
	if not DirAccess.dir_exists_absolute(evidence_dir):
		_check(false, "The storage guard must prepare the evidence directory.")
		return false
	for name_value in ["crt-audio.json", "crt-audio-native.png", "crt-music-master-pregain-42s.wav"]:
		if FileAccess.file_exists(evidence_dir.path_join(name_value)):
			_check(false, "Capture evidence must be fresh: %s." % name_value)
			evidence_dir = ""
			return false
	return true


func _approved_path(value: String) -> bool:
	return value.replace("\\", "/").simplify_path().to_lower().begins_with(APPROVED_ROOT)


func _set_volumes(master: float, music: float, sfx: float) -> void:
	settings.set("master_volume", master)
	settings.set("music_volume", music)
	settings.set("sfx_volume", sfx)
	settings.call("_apply_audio")


func _restore_volumes() -> void:
	if is_instance_valid(settings) and not original_volumes.is_empty():
		_set_volumes(float(original_volumes["master"]), float(original_volumes["music"]), float(original_volumes["sfx"]))


func _bus_state() -> Dictionary:
	var result := {}
	for bus_name in ["Master", "Music", "SFX"]:
		var index := AudioServer.get_bus_index(bus_name)
		result[bus_name] = {"muted": AudioServer.is_bus_mute(index), "volume_db": AudioServer.get_bus_volume_db(index)} if index >= 0 else {"missing": true}
	return result


func _owner(label: String, readiness_msec: int = -1) -> void:
	var stem_players: Dictionary = player.get("_stem_players")
	var native_stems: Array[Dictionary] = []
	var playing_count := 0
	for role in stem_players:
		var stem := stem_players[role] as AudioStreamPlayer
		if stem == null:
			continue
		playing_count += int(stem.playing)
		native_stems.append({"role": str(role), "playing": stem.playing, "bus": str(stem.bus), "volume_db": stem.volume_db, "stream_seconds": stem.stream.get_length() if stem.stream != null else 0.0})
	var ambient := player.get("_ambient_player") as AudioStreamPlayer
	owners.append({
		"label": label, "screen": str(app.get("current_screen")),
		"readiness_msec": readiness_msec,
		"crt_owner": bool(app.get("crt_music_owner_active")),
		"cache_key": str(player.get("_current_cache_key")), "pending_cache_key": str(player.get("_pending_cache_key")),
		"context": player.get("_current_music_context"), "stem_stage": str(player.get("_current_stem_stage")),
		"primer": bool(player.get("_current_stream_is_primer")), "mix": _bus_state(),
		"native_stem_playing_count": playing_count, "native_stems": native_stems,
		"legacy_ambient_playing": ambient != null and ambient.playing,
		"feature_cache_key": str(player.get("_current_feature_cache_key")),
		"playback": _playhead_snapshot(),
	})


func _wait_for_crt_music(label: String) -> bool:
	var readiness_started := Time.get_ticks_msec()
	var deadline := readiness_started + MUSIC_READY_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if bool(app.get("crt_music_owner_active")) and _fixed_master_ready() and not bool(player.get("_current_stream_is_primer")) and str(player.get("_pending_cache_key")).is_empty():
			var current_key := str(player.get("_current_cache_key"))
			if fixed_master_cache_key.is_empty():
				fixed_master_cache_key = current_key
			_check(current_key == fixed_master_cache_key, "%s retains the same fixed master identity." % label)
			_owner(label, Time.get_ticks_msec() - readiness_started)
			_check(true, "%s owns one ready complete approved v3 master with no old primer." % label)
			return true
		await process_frame
	_owner("%s timed out" % label, Time.get_ticks_msec() - readiness_started)
	_check(false, "%s never obtained the complete approved fixed v3 master within 60 seconds." % label)
	return false


func _fixed_master_ready() -> bool:
	var approved := 0
	var unrelated := 0
	for voice_value in (player.get("_stem_players") as Dictionary).values():
		var voice := voice_value as AudioStreamPlayer
		if voice == null or not voice.playing or voice.stream == null:
			continue
		var receipt := _stream_receipt(voice.stream)
		if bool(receipt.get("matches_approved_master_pcm", false)) and int(receipt.get("loop_mode", 0)) == AudioStreamWAV.LOOP_FORWARD and int(receipt.get("loop_begin", -1)) == 0 and int(receipt.get("loop_end", 0)) == CRT_MASTER_FRAMES:
			approved += 1
		else:
			unrelated += 1
	return approved == 1 and unrelated == 0


func _collect(label: String, seconds: float, write_wav: bool = false, movement: bool = false) -> Dictionary:
	var target_frames := mini(int(round(seconds * mix_rate)), CAPTURE_SECONDS * MAX_MIX_RATE)
	var total := 0
	var squares := 0.0
	var peak := 0.0
	var peak_db := -200.0
	var discarded_before := capture.get_discarded_frames()
	var capture_start := _playhead_snapshot()
	capture.clear_buffer()
	var buffer_cleared_usec := Time.get_ticks_usec()
	var loop_wraps: Array[Dictionary] = []
	var last_master_position := _master_playback_position()
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0) + 5000
	var next_input := Time.get_ticks_msec() + 80
	var movement_index := 0
	var held_key: Key = KEY_NONE
	while total < target_frames and Time.get_ticks_msec() < deadline:
		await process_frame
		if write_wav:
			var current_master_position := _master_playback_position()
			if current_master_position >= 0 and last_master_position >= 0 and current_master_position + 0.1 < last_master_position:
				loop_wraps.append({"capture_frames_read": total, "capture_seconds_read": float(total) / mix_rate, "tick_usec": Time.get_ticks_usec(), "source_position_before": last_master_position, "source_position_after": current_master_position})
			last_master_position = current_master_position
		if held_key != KEY_NONE:
			_key_event(held_key, false)
			held_key = KEY_NONE
		elif movement and Time.get_ticks_msec() >= next_input:
			held_key = KEY_RIGHT if movement_index % 2 == 0 else KEY_LEFT
			_key_event(held_key, true)
			movement_index += 1
			next_input = Time.get_ticks_msec() + 220
		for channel in range(AudioServer.get_bus_channels(master_bus)):
			peak_db = maxf(peak_db, AudioServer.get_bus_peak_volume_left_db(master_bus, channel))
			peak_db = maxf(peak_db, AudioServer.get_bus_peak_volume_right_db(master_bus, channel))
		while capture.get_frames_available() > 0 and total < target_frames:
			var amount := mini(CHUNK_FRAMES, mini(capture.get_frames_available(), target_frames - total))
			var buffer := capture.get_buffer(amount)
			if buffer.is_empty():
				break
			var encoded := PackedByteArray()
			if write_wav:
				encoded.resize(buffer.size() * 4)
			for index in range(buffer.size()):
				var frame := buffer[index]
				peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
				squares += frame.x * frame.x + frame.y * frame.y
				if write_wav:
					encoded.encode_u16(index * 4, int(round(clampf(frame.x, -1.0, 1.0) * 32767.0)) & 0xffff)
					encoded.encode_u16(index * 4 + 2, int(round(clampf(frame.y, -1.0, 1.0) * 32767.0)) & 0xffff)
			if write_wav:
				wav.store_buffer(encoded)
				wav_frames += buffer.size()
			total += buffer.size()
	if held_key != KEY_NONE:
		_key_event(held_key, false)
	var discarded := capture.get_discarded_frames() - discarded_before
	var result := {
		"label": label, "frames": total, "target_frames": target_frames,
		"seconds": float(total) / mix_rate, "rms": sqrt(squares / maxf(1.0, total * 2.0)),
		"raw_pre_master_peak": peak, "max_master_peak_db": peak_db, "discarded_frames": discarded,
		"selection_events": selection_events, "actual_keyboard_presses": movement_index,
		"mix": _bus_state(), "wav": wav_path if write_wav else "",
		"capture_start_playheads": capture_start, "buffer_cleared_usec": buffer_cleared_usec,
		"capture_end_playheads": _playhead_snapshot(), "source_loop_wraps": loop_wraps,
	}
	phases.append(result)
	_check(total == target_frames, "%s receives every bounded target audio frame." % label)
	_check(discarded == 0, "%s loses no AudioEffectCapture frames." % label)
	if write_wav:
		_check(not loop_wraps.is_empty(), "The 42-second capture observes an actual approved-master playback wrap.")
	return result


func _stream_receipt(stream: AudioStream) -> Dictionary:
	if stream == null:
		return {"missing": true}
	var key := stream.get_instance_id()
	if stream_receipts.has(key):
		return stream_receipts[key]
	var result := {"class": stream.get_class(), "resource_path": stream.resource_path, "seconds": stream.get_length()}
	if stream is AudioStreamWAV:
		var pcm := stream as AudioStreamWAV
		result.merge({"mix_rate": pcm.mix_rate, "stereo": pcm.stereo, "format": pcm.format, "pcm_bytes": pcm.data.size(), "pcm_sha256": _sha256_bytes(pcm.data), "loop_mode": pcm.loop_mode, "loop_begin": pcm.loop_begin, "loop_end": pcm.loop_end})
		result["matches_approved_master_pcm"] = str(result["pcm_sha256"]) == approved_master_pcm_sha256 and pcm.mix_rate == CRT_MASTER_RATE and pcm.stereo and pcm.format == AudioStreamWAV.FORMAT_16_BITS and pcm.data.size() == CRT_MASTER_FRAMES * 4
	stream_receipts[key] = result
	return result


func _playhead_snapshot() -> Dictionary:
	var stems: Array[Dictionary] = []
	for role in (player.get("_stem_players") as Dictionary):
		var voice := (player.get("_stem_players") as Dictionary)[role] as AudioStreamPlayer
		if voice == null:
			continue
		stems.append({"role": str(role), "playing": voice.playing, "playback_seconds": voice.get_playback_position(), "pitch_scale": voice.pitch_scale, "volume_db": voice.volume_db, "bus": str(voice.bus), "stream": _stream_receipt(voice.stream)})
	return {"tick_usec": Time.get_ticks_usec(), "director_seconds": player.call("_director_playback_position"), "mix_rate": mix_rate, "time_since_last_mix": AudioServer.get_time_since_last_mix(), "time_to_next_mix": AudioServer.get_time_to_next_mix(), "output_latency_seconds": AudioServer.get_output_latency(), "native_stems": stems, "stem_stage": str(player.get("_current_stem_stage")), "primer": bool(player.get("_current_stream_is_primer"))}


func _master_playback_position() -> float:
	for voice_value in (player.get("_stem_players") as Dictionary).values():
		var voice := voice_value as AudioStreamPlayer
		if voice != null and voice.playing and bool(_stream_receipt(voice.stream).get("matches_approved_master_pcm", false)):
			return voice.get_playback_position()
	return -1.0


func _sha256_bytes(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _write_wav_header(frames: int) -> void:
	wav.seek(0)
	wav.store_buffer("RIFF".to_ascii_buffer())
	wav.store_32(36 + frames * 4)
	wav.store_buffer("WAVEfmt ".to_ascii_buffer())
	wav.store_32(16)
	wav.store_16(1)
	wav.store_16(2)
	wav.store_32(mix_rate)
	wav.store_32(mix_rate * 4)
	wav.store_16(4)
	wav.store_16(16)
	wav.store_buffer("data".to_ascii_buffer())
	wav.store_32(frames * 4)


func _close_wav() -> void:
	if wav != null:
		_write_wav_header(wav_frames)
		wav.flush()
		wav.close()
		wav = null


func _practice_return_and_exit() -> void:
	if not await _click(menu.find_child("Launch_scratch_tickets", true, false) as Control, "Scratch Ticket practice"):
		return
	for _frame in range(300):
		if app.get("current_game") != null and str(app.get("current_screen")) == "GAME":
			break
		await process_frame
	_check(app.get("current_game") != null and str(app.get("current_screen")) == "GAME", "Normal mouse launch enters production practice gameplay.")
	_check(not bool(app.get("crt_music_owner_active")), "Practice launch releases CRT Music ownership.")
	_check(str(player.get("_current_cache_key")) != fixed_master_cache_key and str(player.get("_pending_cache_key")) != fixed_master_cache_key and _master_playback_position() < 0, "Practice launch cancels the exact current/pending fixed CRT master and its native voice.")
	_owner("practice launch")
	if app.get("current_game") == null:
		return
	await _frames(4)
	var surface := app.get("game_surface_canvas") as Control
	if surface == null:
		_check(false, "Production practice has a rendered surface for Leave.")
		return
	var leave_rect: Rect2 = surface.call("global_rect_for_surface_action", "surface_back", -1)
	_check(leave_rect.has_area(), "Production practice exposes its normal Leave pointer target.")
	if not leave_rect.has_area():
		return
	await _mouse_tap(leave_rect.get_center())
	for _frame in range(300):
		if str(app.get("current_screen")) == "CRT" and app.get("current_game") == null:
			break
		await process_frame
	_check(str(app.get("current_screen")) == "CRT" and menu.is_visible_in_tree() and app.get("current_game") == null, "Actual rendered Leave restores the same CRT selector.")
	if not await _wait_for_crt_music("CRT after Leave"):
		return
	if not await _click(menu.get("exit_button") as Control, "Exit TV"):
		return
	await _frames(6)
	_check(str(app.get("current_screen")) == "START" and app.get("run_state") == null and not bool(app.call("_crt_practice_active")), "Actual Exit TV returns to the originating title without a run.")
	_check(not bool(app.get("crt_music_owner_active")), "Exit TV releases CRT Music ownership.")
	_check(str(player.get("_current_cache_key")) != fixed_master_cache_key and str(player.get("_pending_cache_key")) != fixed_master_cache_key and _master_playback_position() < 0, "Title has neither the exact current/pending fixed CRT master nor its native voice.")
	_owner("title after Exit TV")
	_check(not bool(app.call("_has_foundation_save")), "Practice audio acceptance leaves the ordinary Continue slot empty.")


func _click(control: Control, label: String) -> bool:
	if control == null or not control.is_visible_in_tree():
		_check(false, "%s has a visible real UI target." % label)
		return false
	for attempt in range(3):
		await _frames(2)
		var before := control.get_global_rect()
		var point := before.get_center()
		var current_menu := app.get("game_test_menu") as Control
		if current_menu != null and control.get_viewport() == current_menu.call("get_display_viewport"):
			point = current_menu.call("display_hit_point", control, Vector2(0.5, 0.5))
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.relative = point - root.get_mouse_position()
		Input.parse_input_event(motion)
		await _frames(2)
		var hovered := control.get_viewport().gui_get_hovered_control()
		var correct := hovered == control or (hovered != null and control.is_ancestor_of(hovered))
		inputs.append({"label": label, "attempt": attempt + 1, "position": [point.x, point.y], "hovered": str(hovered.name) if hovered != null else "", "correct_hover": correct})
		if before.has_area() and before.is_equal_approx(control.get_global_rect()) and correct:
			await _mouse_tap(point)
			return true
	_check(false, "%s never exposed a stable uncovered rendered target." % label)
	return false


func _mouse_tap(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	Input.parse_input_event(event)
	await _frames(2)


func _key_event(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _on_selection_changed(_game_id: String) -> void:
	selection_events += 1


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame
		await RenderingServer.frame_post_draw


func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures.append(message)
		push_error(message)


func _finish() -> void:
	_close_wav()
	_restore_volumes()
	if capture != null and master_bus >= 0 and capture_slot >= 0 and capture_slot < AudioServer.get_bus_effect_count(master_bus) and AudioServer.get_bus_effect(master_bus, capture_slot) == capture:
		AudioServer.remove_bus_effect(master_bus, capture_slot)
	var result := {
		"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"metadata": metadata, "phases": phases, "music_ownership": owners, "inputs": inputs,
		"selection_events": selection_events, "wav": wav_path, "wav_frames": wav_frames,
		"elapsed_msec": Time.get_ticks_msec() - started_msec,
		"limits": "Rendered fresh native game; actual parsed mouse and keyboard input. Settings use production audio application, not slider hit testing. No controller/touch, Web, OS-loopback, or speaker claim.",
	}
	if not evidence_dir.is_empty():
		var report := FileAccess.open(evidence_dir.path_join("crt-audio.json"), FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify(result, "\t") + "\n")
			report.close()
		else:
			_check(false, "Native audio JSON evidence opens for writing.")
			result["passed"] = false
	print("CRT_AUDIO_NATIVE %s" % JSON.stringify(result))
	if is_instance_valid(app):
		app.queue_free()
	quit(0 if failures.is_empty() else 1)
