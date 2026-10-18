extends SceneTree

const ProceduralMusicPlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const WebAudioBridgeScript := preload("res://scripts/ui/web_audio_bridge.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const SettingsMenuScript := preload("res://scripts/ui/settings_menu.gd")
const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_music_identity()
	_check_cache_ownership()
	_check_hard_mute()
	_check_settings_recovery()
	_check_web_bridge_contract()
	_check_sfx_failure_recovery()
	if failures.is_empty():
		print("FIXSWEEP06_1_AUDIO_RECOVERY PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_music_identity() -> void:
	var player := ProceduralMusicPlayerScript.new()
	var bar_a := {"id": "bar_a", "archetype_id": "bar", "mood": "local bar", "music_profile": {"theme": "bar", "palette_id": "bar", "bpm": 65.0, "mode": "minor", "texture": "jazz", "generated_signature": "bar-a"}}
	var bar_b := {"id": "bar_b", "archetype_id": "bar", "mood": "local bar", "music_profile": {"theme": "bar", "palette_id": "bar", "bpm": 104.0, "mode": "dorian", "texture": "funk_jazz", "generated_signature": "bar-b"}}
	var profile_a: Dictionary = player.call("_music_profile_from_environment", bar_a, 0)
	var profile_b: Dictionary = player.call("_music_profile_from_environment", bar_b, 0)
	var key_a := str(player.call("_ambient_cache_key", profile_a))
	var key_b := str(player.call("_ambient_cache_key", profile_b))
	if key_a == key_b:
		failures.append("BTH-046: distinct same-archetype compositions still share a stem cache key: %s" % key_a)
	if not player.has_method("composition_fingerprint") or not player.has_method("live_mix_fingerprint"):
		failures.append("BTH-046: composition and live-mix identities are not exposed separately.")
	else:
		var mix_a := profile_a.duplicate(true)
		var mix_b := profile_a.duplicate(true)
		mix_a["ambience"] = 0.2
		mix_a["volume"] = 0.15
		mix_b["ambience"] = 0.9
		mix_b["volume"] = 0.42
		if str(player.call("composition_fingerprint", mix_a)) != str(player.call("composition_fingerprint", mix_b)):
			failures.append("BTH-046: ambience/volume incorrectly change composition identity.")
		if str(player.call("live_mix_fingerprint", mix_a)) == str(player.call("live_mix_fingerprint", mix_b)):
			failures.append("BTH-046: ambience/volume do not change live-mix identity.")
	player.free()


func _check_cache_ownership() -> void:
	var player := ProceduralMusicPlayerScript.new()
	if not player.has_method("debug_configure_pcm_cache_budget") or not player.has_method("debug_store_pcm_cache_entry") or not player.has_method("clear_run_scoped_caches"):
		failures.append("BTH-048: procedural PCM cache has no byte-budgeted/run-boundary ownership contract.")
		player.free()
		return
	player.call("debug_configure_pcm_cache_budget", 140)
	player.call("debug_store_pcm_cache_entry", "protected", 60, false)
	player.set("_current_cache_key", "protected")
	player.call("debug_store_pcm_cache_entry", "evicted", 60, false)
	player.call("debug_store_pcm_cache_entry", "newest", 60, false)
	var snapshot: Dictionary = player.call("pcm_cache_policy_snapshot")
	var keys: Array = snapshot.get("keys", [])
	if int(snapshot.get("budget_bytes", 0)) != 140 or int(snapshot.get("bytes", 0)) > 140 or not keys.has("protected") or not keys.has("newest") or keys.has("evicted"):
		failures.append("BTH-048: LRU did not evict the least-recent inactive key while protecting the active key: %s" % JSON.stringify(snapshot))
	player.call("debug_store_pcm_cache_entry", "menu-hot", 20, true)
	player.call("clear_run_scoped_caches")
	snapshot = player.call("pcm_cache_policy_snapshot")
	keys = snapshot.get("keys", [])
	if keys.has("protected") or keys.has("newest") or not keys.has("menu-hot"):
		failures.append("BTH-048: run boundary did not clear run-scoped PCM while retaining the menu hot set: %s" % JSON.stringify(snapshot))
	player.free()


func _check_hard_mute() -> void:
	var settings := UserSettingsScript.new()
	settings.apply()
	var master := AudioServer.get_bus_index("Master")
	settings.master_volume = 0.0
	settings.apply()
	if master < 0 or not AudioServer.is_bus_mute(master) or float(WebAudioBridgeScript._audio_bus_linear("Master")) != 0.0:
		failures.append("BTH-049: 0% Master volume is not a native/Web hard mute.")
	settings.master_volume = 0.37
	settings.apply()
	if AudioServer.is_bus_mute(master) or absf(AudioServer.get_bus_volume_db(master) - linear_to_db(0.37)) > 0.01:
		failures.append("BTH-049: raising volume above zero did not unmute and restore the slider dB.")


func _check_settings_recovery() -> void:
	for fixture in [{"suffix": "json", "text": "{broken", "detail": "malformed_json"}, {"suffix": "array", "text": "[1,2,3]", "detail": "invalid_schema"}]:
		var path := "user://fixsweep06_1_settings_%s_%d.json" % [fixture.suffix, Time.get_ticks_usec()]
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(fixture.text)
		file.close()
		OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, path)
		var settings := UserSettingsScript.new()
		var outcome: Variant = settings.call("load")
		if typeof(outcome) != TYPE_DICTIONARY:
			failures.append("BTH-050: settings load still has no structured outcome for %s." % fixture.suffix)
			continue
		var result := outcome as Dictionary
		if str(result.get("code", "")) != "recovered_defaults" or str(result.get("detail", "")) != fixture.detail or not FileAccess.file_exists(str(result.get("preserved_path", ""))):
			failures.append("BTH-050: invalid settings outcome/preservation is incomplete: %s" % JSON.stringify(result))
		var menu := SettingsMenuScript.new()
		menu.setup(settings)
		if not menu.has_method("set_recovery_banner"):
			failures.append("BTH-050: Settings has no player-visible recovery banner contract.")
		else:
			menu.call("set_recovery_banner", result)
			menu.open()
			var menu_snapshot: Dictionary = menu.call("current_settings_snapshot")
			if str(menu_snapshot.get("status", "")).findn("defaults") < 0:
				failures.append("BTH-050: recovery banner is not visible in Settings: %s" % JSON.stringify(menu_snapshot))
		menu.free()
	OS.unset_environment(UserSettingsScript.SETTINGS_PATH_ENV)


func _check_web_bridge_contract() -> void:
	WebAudioBridgeScript._mark_pcm_registered({"key": "fixsweep-observational", "data": "AA==", "frames": 1, "channels": 1})
	var registered_before := int(WebAudioBridgeScript.debug_stats().get("registered_pcm_count", 0))
	WebAudioBridgeScript.reset_debug_stats()
	var registered_after := int(WebAudioBridgeScript.debug_stats().get("registered_pcm_count", 0))
	var contract := WebAudioBridgeScript.mix_contract_snapshot()
	if registered_before <= 0 or registered_after != registered_before:
		failures.append("BTH-048: debug-stat reset still falsifies live PCM ownership diagnostics.")
	for field in ["script_has_pcm_byte_lru", "script_has_pcm_disposal", "diagnostics_report_actual_pcm", "pcm_budget_bytes"]:
		if not contract.has(field) or (typeof(contract[field]) == TYPE_BOOL and not bool(contract[field])) or (field == "pcm_budget_bytes" and int(contract[field]) != 64 * 1024 * 1024):
			failures.append("BTH-048: WebAudio cache contract is missing %s: %s" % [field, JSON.stringify(contract)])


func _check_sfx_failure_recovery() -> void:
	var player := SfxPlayerScript.new()
	if not player.has_method("debug_web_delivery_contract"):
		failures.append("BTH-051: SFX player has no injectable bounded retry/fallback/status contract.")
		player.free()
		return
	var recovered: Dictionary = player.call("debug_web_delivery_contract", [false, true])
	if not bool(recovered.get("loop_active", false)) or int(recovered.get("attempts", 0)) != 2 or int(recovered.get("retry_count", 0)) != 1:
		failures.append("BTH-051: a transient bridge failure did not recover through bounded retry: %s" % JSON.stringify(recovered))
	var exhausted: Dictionary = player.call("debug_web_delivery_contract", [false, false, false])
	if bool(exhausted.get("loop_active", false)) or int(exhausted.get("attempts", 0)) != 3 or int(exhausted.get("dropped_cue_count", 0)) < 1 or str(exhausted.get("status", "")).findn("audio unavailable") < 0:
		failures.append("BTH-051: repeated bridge failures did not stop retrying and expose player-visible status: %s" % JSON.stringify(exhausted))
	player.free()
