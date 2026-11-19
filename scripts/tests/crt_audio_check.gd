extends SceneTree

# Fresh guarded headless qualification of real CRT menu input and Foundation
# audio ownership. Spies observe semantic delivery requests, not audible output.
# Native PCM synthesis/bus assertions below use the actual audio implementation.
const Foundation := preload("res://scripts/ui/foundation_main.gd")
const Music := preload("res://scripts/ui/procedural_music_player.gd")
const Sfx := preload("res://scripts/ui/sfx_player.gd")
const Settings := preload("res://scripts/core/user_settings.gd")
const CrtMenu := preload("res://scripts/ui/crt_practice_menu.gd")

class MusicSpy extends Music:
	var environment: Dictionary = {}
	var requests: Array[Dictionary] = []
	var unlock_environment: Dictionary = {}

	func play_for_environment_state(next_environment: Dictionary, heat: int, state: Dictionary) -> void:
		environment = next_environment.duplicate(true)
		requests.append({"environment": environment, "heat": heat, "state": state.duplicate(true)})

	func stop() -> void:
		environment = {}
		requests.append({"stopped": true})

	func refresh_after_web_audio_unlock(next_environment: Dictionary, _heat: int, _state: Dictionary) -> void:
		unlock_environment = next_environment.duplicate(true)

class Host extends Foundation:
	var cues: Array[Dictionary] = []
	var reject_launch := false
	var music_probe: MusicSpy

	func _initialize_procedural_music() -> void:
		if music_probe == null:
			music_probe = MusicSpy.new()
			procedural_music_player = music_probe
			add_child(music_probe)

	func _play_environment_audio_cue(cue_id: String, volume_db: float = -1.0, profile_id: String = "crew_world", context: Dictionary = {}) -> void:
		cues.append({"id": cue_id, "volume_db": volume_db, "profile_id": profile_id, "context": context.duplicate(true)})

	func start_game_test_session(game_id: String) -> Dictionary:
		if reject_launch:
			return {"ok": false, "errors": ["Injected launch rejection before production generation."]}
		return super.start_game_test_session(game_id)

var app: Host
var checks := 0
var failures: Array[String] = []
var facts: Array[Dictionary] = []
var moves: Array[String] = []
var selections: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for key in ["BTH_DISTRIBUTION_DATA_ROOT", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]:
		var path := OS.get_environment(key).replace("\\", "/").to_lower()
		if not _check(path.begins_with("e:/codexqa/bth/") and not path.contains("/../"), key + " is explicitly isolated under E: QA"):
			_finish()
			return
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	_check_synthesis_and_buses()
	app = Host.new()
	app.continuous_environment_clock_enabled = false
	app.autosave_slot_id = "crt_audio_check"
	root.add_child(app)
	# Host subclasses the production script for audio spies, so reproduce the
	# Main Control's main.tscn layout rather than retaining Control.new()'s zero
	# size. Its live child containers then lay out exactly as the real scene.
	app.set("layout_mode", 3)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.grow_horizontal = Control.GROW_DIRECTION_BOTH
	app.grow_vertical = Control.GROW_DIRECTION_BOTH
	app.position = Vector2.ZERO
	await _frames(4)
	app._ensure_full_content_library_loaded()
	_check_theme_theory()
	_check_silent_configuration()
	await _menu_input_and_launch()
	await _music_owners()
	app.queue_free()
	await process_frame
	_finish()


func _check_silent_configuration() -> void:
	# Observe signals before configure(), rather than inferring silence from a
	# snapshot taken after production menu construction has already completed.
	var menu := CrtMenu.new()
	var initial: Array[String] = []
	menu.user_selection_changed.connect(func(game_id: String): initial.append("move:" + game_id))
	menu.launch_accepted.connect(func(game_id: String): initial.append("select:" + game_id))
	menu.configure(app)
	_check(initial.is_empty(), "initial menu configuration emits no selection/launch sound event")
	menu.free()


func _menu_input_and_launch() -> void:
	app.open_game_test_menu()
	await _frames(3)
	var menu: CrtPracticeMenu = app.game_test_menu
	if not _check(menu != null and menu.is_visible_in_tree(), "real host opens its production CRT menu"):
		return
	await _rendered_frames(2)
	var display: Control = menu.get("_display")
	if not _check(app.size.is_equal_approx(Vector2(root.size)) and display != null and display.size.x > 0 and display.size.y > 0, "production-sized host exposes a nonzero CRT display before pointer qualification"):
		facts.append({"case": "host_layout", "app_size": app.size, "root_size": root.size, "display_size": display.size if display != null else Vector2.ZERO})
		return
	menu.user_selection_changed.connect(func(game_id: String): moves.append(game_id))
	menu.launch_accepted.connect(func(game_id: String): selections.append(game_id))
	var ids: Array = app._implemented_game_ids()
	var first := str(ids[0])
	var second := str(ids[1])
	var buttons: Dictionary = menu.get("_game_buttons")
	var a: Button = buttons[first]
	var b: Button = buttons[second]
	_clear_events()
	menu.focus_selected_game()
	menu.focus_selected_game()
	app.game_test_seed_input.text = "AUDIO-SEED-ONLY"
	menu.generation_button.button_pressed = true
	menu.generation_button.pressed.emit()
	menu.consume_back()
	menu.focus_selected_game()
	await _frames(2)
	_expect_events(0, 0, "restore focus, seed edits and Generation Setup are silent")
	# An invalid selection must not replace a valid retained choice.
	var retained := menu.selected_game_id
	menu.call("_remember_selection", "__invalid_audio_game")
	_check(menu.selected_game_id == retained, "invalid game selection leaves the existing choice intact")
	_expect_events(0, 0, "invalid selection emits no navigation event")
	_clear_events()
	await _key(KEY_RIGHT)
	_check(menu.selected_game_id == second, "actual Right key changes focused cartridge")
	await _key(KEY_LEFT)
	_check(menu.selected_game_id == first, "actual Left key restores the first cartridge")
	a.grab_focus()
	await _frames(1)
	_expect_events(2, 0, "keyboard A to B to A emits exactly two moves; same focused ID emits zero")
	_clear_events()
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	await _joy(JOY_BUTTON_DPAD_LEFT)
	_check(menu.selected_game_id == first, "controller D-pad returns to the original cartridge")
	_expect_events(2, 0, "controller A to B to A emits exactly two moves")
	_clear_events()
	await _hover_control(b, "second-game first hover")
	await _hover_control(b, "second-game repeated hover")
	await _hover_control(a, "first-game return hover")
	_expect_events(2, 0, "real mouse hover changes emit once per changed game, never for repeated hover")
	_clear_events()
	await _touch(menu.display_hit_point(b), true, false)
	await _touch(menu.display_hit_point(b), false, true)
	_check(menu.selected_game_id == second and app.current_game == null, "canceled touch changes the hovered choice without launching")
	_expect_events(1, 0, "one canceled touch selection emits one move and zero confirms")
	_clear_events()
	app.reject_launch = true
	await _click_control(b, "rejected selected-game click")
	_check(menu.is_visible_in_tree() and app.current_game == null, "real valid cartridge click survives an injected production launch rejection")
	_expect_events(0, 0, "failed launch of the selected game emits zero confirmation cues")
	app.reject_launch = false
	_clear_events()
	await _touch(menu.display_hit_point(b), true, false)
	await _touch(menu.display_hit_point(b), false, false)
	_check(app.current_game != null and app.current_game.get_id() == second, "real touch release launches the actual selected game")
	_expect_events(0, 1, "successful same-game touch launch emits exactly one confirmation")
	_clear_events()
	await _leave()
	menu.focus_selected_game()
	await _frames(2)
	_expect_events(0, 0, "Leave and retained-selection focus restoration emit no move/select cue")
	app.close_game_test_menu()
	_clear_events()
	app._on_crt_user_selection_changed(first)
	app._on_crt_launch_accepted(first)
	_expect_events(0, 0, "stale callbacks outside CRT cannot deliver console audio")
	facts.append({"case": "menu_inputs", "keyboard": true, "controller_injected_dpad": true, "mouse_hover": true, "touch_cancel_and_accept": true, "launch_failure_injected_before_generation": true})


func _music_owners() -> void:
	app._update_procedural_music()
	var title := app.music_probe.environment.duplicate(true)
	app.open_game_test_menu()
	_check_crt_owner("title to CRT")
	var stops_before := _music_stops()
	app._update_procedural_music()
	app._update_procedural_music()
	_check(_music_stops() == stops_before and app.crt_music_owner_active, "repeated CRT refresh preserves the music owner without stopping/restarting it")
	var began: Dictionary = app.start_game_test_session("blackjack")
	if _check(bool(began.get("ok", false)), "music owner fixture opens normal Blackjack practice"):
		app._update_procedural_music()
		_check(str(app.music_probe.environment.get("id", "")) == str(app.run_state.current_environment.get("id", "")), "practice gameplay receives its normal environment music owner")
		await _leave()
		_check_crt_owner("practice Leave to CRT")
	app.close_game_test_menu()
	app._update_procedural_music()
	_check(app.music_probe.environment == title, "Exit CRT restores the original title music owner")
	# One ordinary generated home is enough to test owner routing; the separate
	# CRT state suite retains exhaustive room/save/seed qualification.
	if not _check(app.start_foundation_run("CRT-AUDIO-OWNER-061", {"modifiers": {"home_archetype_id": "apartment"}}, false), "ordinary room music fixture generates"):
		return
	await _frames(3)
	var original := app.run_state
	app._update_procedural_music()
	var room_music := app.music_probe.environment.duplicate(true)
	var protected := {"seed": original.rng_seed, "rng": original.rng_state, "cash": original.bankroll, "heat": original.suspicion.duplicate(true), "clock": original.game_clock_minutes, "inventory": original.inventory.duplicate(true)}
	app.open_game_test_menu()
	_check_crt_owner("ordinary room to CRT")
	app.close_game_test_menu()
	app._update_procedural_music()
	_check(app.run_state == original and app.music_probe.environment == room_music, "Exit restores the ordinary room music owner")
	_check(protected == {"seed": original.rng_seed, "rng": original.rng_state, "cash": original.bankroll, "heat": original.suspicion.duplicate(true), "clock": original.game_clock_minutes, "inventory": original.inventory.duplicate(true)}, "menu music and navigation do not consume ordinary RNG or player state")
	app.return_to_main_menu()
	app.meta_collection_service._store["housing_tier"] = "apartment"
	app.open_meta_home()
	app._update_procedural_music()
	var meta_music := app.music_probe.environment.duplicate(true)
	var meta_before := app.meta_collection_service.snapshot().duplicate(true)
	app.open_game_test_menu()
	_check_crt_owner("meta home to CRT")
	app.close_game_test_menu()
	app._update_procedural_music()
	_check(app._is_meta_session() and app.music_probe.environment == meta_music and app.meta_collection_service.snapshot() == meta_before, "Exit restores meta-home music without collection changes")
	app._exit_meta_session()


func _check_crt_owner(label: String) -> void:
	var expected: Dictionary = app.music_probe.crt_practice_theme_environment()
	_check(app._crt_menu_audio_active() and app.crt_music_owner_active and app.music_probe.environment == expected, label + " owns the dedicated console music environment")
	# Exercise the deferred unlock decision where it exists. A headless native
	# build cannot claim the browser AudioContext unlock itself was tested.
	if OS.has_feature("web"):
		app._run_web_audio_unlock_refresh()
		_check(app.music_probe.unlock_environment == expected, label + " deferred Web unlock retains CRT ownership")


func _check_theme_theory() -> void:
	var player := Music.new()
	var environment: Dictionary = player.crt_practice_theme_environment()
	var profile: Dictionary = player._music_profile_from_environment(environment, 0)
	var context: Dictionary = player._ambient_generation_context(profile)
	_check(is_equal_approx(float(context.get("bpm", 0)), 96.0) and int(context.get("phrase_count", 0)) == 4, "console theme uses its declared tempo and four musical phrases")
	_check(is_equal_approx(float(context.get("duration", 0)), 40.0) and int(context.get("total_steps", 0)) == 128, "actual procedural composition context forms a 40-second complete loop")
	var title_profile: Dictionary = player._music_profile_from_environment(player.main_menu_theme_environment(), 0)
	_check(player.composition_fingerprint(profile) != player.composition_fingerprint(title_profile), "console composition is distinct from the main title theme")
	facts.append({"case": "composition", "duration_seconds": context.get("duration"), "bpm": context.get("bpm"), "phrases": context.get("phrase_count"), "audible_playback": false})
	player.free()


func _check_synthesis_and_buses() -> void:
	var settings := Settings.new()
	settings.apply()
	var master := AudioServer.get_bus_index("Master")
	var music := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	settings.master_volume = 0.73
	settings.music_volume = 0.0
	settings.sfx_volume = 0.42
	settings.apply()
	_check(AudioServer.is_bus_mute(music) and not AudioServer.is_bus_mute(sfx_bus) and not AudioServer.is_bus_mute(master), "Music mute independently leaves SFX and Master unmuted")
	settings.music_volume = 0.36
	settings.sfx_volume = 0.0
	settings.apply()
	_check(not AudioServer.is_bus_mute(music) and AudioServer.is_bus_mute(sfx_bus), "SFX mute independently leaves Music unmuted")
	_check(absf(AudioServer.get_bus_volume_db(music) - linear_to_db(0.36)) < 0.01, "Music slider applies its real bus gain")
	settings.master_volume = 0.0
	settings.sfx_volume = 0.51
	settings.apply()
	_check(AudioServer.is_bus_mute(master) and not AudioServer.is_bus_mute(music) and not AudioServer.is_bus_mute(sfx_bus), "Master zero hard-mutes the native parent bus without rewriting child settings")
	settings.master_volume = 0.73
	settings.apply()
	_check(not AudioServer.is_bus_mute(master) and absf(AudioServer.get_bus_volume_db(sfx_bus) - linear_to_db(0.51)) < 0.01, "unmuting Master retains the separate SFX gain")
	var player := Sfx.new()
	player._ensure_players()
	for voice in player.get("_players"):
		_check(voice is AudioStreamPlayer and voice.bus == "SFX", "real one-shot voice routes through the independently controlled SFX bus")
	var profile: Dictionary = player._surface_sfx_profile("crt_practice_console")
	_check(str(profile.get("bus", "")) == "SFX" and int(profile.get("max_voices", 0)) == 2, "console cue profile retains bounded SFX-bus voice ownership")
	for event_id in ["crt_move", "crt_select"]:
		var resolved: Dictionary = player._resolve_manifest_surface_event("crt_practice_console", event_id, {}, {})
		_check(str(resolved.get("event_id", "")) == event_id, "console semantic cue resolves to its own PCM event: " + event_id)
	var move: AudioStreamWAV = player._event_stream("crt_move")
	var select: AudioStreamWAV = player._event_stream("crt_select")
	_check(move != null and absf(move.get_length() - 0.095) < 0.002, "actual navigation synthesis has a short 95ms envelope")
	_check(select != null and absf(select.get_length() - 0.380) < 0.002, "actual accepted-launch synthesis has a distinct 380ms envelope")
	_check(move != null and select != null and move.data != select.data and _has_nonzero(move.data) and _has_nonzero(select.data), "both actual PCM cues are non-silent and distinct")
	_check(move != null and select != null and move.loop_mode == AudioStreamWAV.LOOP_DISABLED and select.loop_mode == AudioStreamWAV.LOOP_DISABLED, "navigation and accepted-launch cues are finite one-shots")
	player.free()
	settings.reset()
	settings.apply()


func _expect_events(move_count: int, select_count: int, label: String) -> void:
	var delivered_moves := 0
	var delivered_selects := 0
	for cue in app.cues:
		if str(cue.get("id", "")) == "crt_move": delivered_moves += 1
		if str(cue.get("id", "")) == "crt_select": delivered_selects += 1
		_check(str(cue.get("id", "")) not in ["crt_move", "crt_select"] or str(cue.get("profile_id", "")) == "crt_practice_console", "console event uses its authorized dedicated SFX profile")
	_check(moves.size() == move_count and selections.size() == select_count and delivered_moves == move_count and delivered_selects == select_count, label + " (signals and real host delivery agree)")
	if moves.size() != move_count or selections.size() != select_count or delivered_moves != move_count or delivered_selects != select_count:
		facts.append({"case": label, "expected": [move_count, select_count], "signals": [moves.duplicate(), selections.duplicate()], "cues": app.cues.duplicate(true)})


func _clear_events() -> void:
	moves.clear()
	selections.clear()
	app.cues.clear()


func _music_stops() -> int:
	var count := 0
	for request in app.music_probe.requests:
		if bool(request.get("stopped", false)): count += 1
	return count


func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	app.get_viewport().push_input(event, true)
	await _frames(1)
	event = event.duplicate()
	event.pressed = false
	app.get_viewport().push_input(event, true)
	await _frames(1)


func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	app.get_viewport().push_input(event, true)
	await _frames(1)
	event = event.duplicate()
	event.pressed = false
	app.get_viewport().push_input(event, true)
	await _frames(1)


func _hover(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - root.get_mouse_position()
	# Match the established rendered navigation harness. Root push_input alone
	# bypasses Input's mouse position/button state used by the CRT forwarding path.
	Input.parse_input_event(event)
	await _rendered_frames(2)


func _hover_control(control: Control, label: String) -> bool:
	var menu: CrtPracticeMenu = app.game_test_menu
	var observations: Array[Dictionary] = []
	for _attempt in range(3):
		await _rendered_frames(2)
		var before := control.get_global_rect()
		var point := menu.display_hit_point(control)
		await _hover(point)
		var hovered := control.get_viewport().gui_get_hovered_control()
		var local_point := menu.global_to_display(point)
		var stable := before.is_equal_approx(control.get_global_rect())
		var correct := hovered == control or (hovered != null and control.is_ancestor_of(hovered))
		if stable and before.has_point(local_point) and correct:
			return true
		observations.append({"requested": point, "display_point": local_point, "root_mouse": root.get_mouse_position(), "root_rect": root.get_visible_rect(), "target_rect": before, "stable": stable, "hovered": str(hovered.name) if hovered != null else "nothing", "root_hovered": str(root.gui_get_hovered_control().name) if root.gui_get_hovered_control() != null else "nothing", "display_size": (menu.get("_display") as Control).size})
	_check(false, label + " has a stable, uncovered real GUI hit target")
	facts.append({"case": label, "pointer_target_attempts": observations, "display_server": DisplayServer.get_name()})
	return false


func _click_control(control: Control, label: String) -> void:
	if not await _hover_control(control, label):
		return
	var point: Vector2 = app.game_test_menu.call("display_hit_point", control)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)
		await _rendered_frames(2)


func _touch(point: Vector2, pressed: bool, canceled: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 1
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	await _rendered_frames(2)


func _leave() -> void:
	app.back_to_environment()
	for _frame in range(600):
		if app.game_test_menu.is_visible_in_tree() and app.current_game == null:
			return
		await process_frame
	_check(false, "normal practice Leave reaches CRT within bounded frames")


func _has_nonzero(bytes: PackedByteArray) -> bool:
	for value in bytes:
		if value != 0: return true
	return false


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _rendered_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame
		if DisplayServer.get_name().to_lower() != "headless":
			await RenderingServer.frame_post_draw


func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok


func _finish() -> void:
	print("CRT_AUDIO_CHECK " + JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "scope": "Real production menu input/host ownership with logical audio spies; real native bus controls and PCM cues. No audible quality, browser AudioContext, physical controller, or full save-state regression claim."}))
	quit(0 if failures.is_empty() else 1)
