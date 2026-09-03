extends SceneTree

const ManifestScript := preload("res://scripts/core/surface_sfx_manifest.gd")
const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")
const WebAudioBridgeScript := preload("res://scripts/ui/web_audio_bridge.gd")

const EXPECTED_PROFILES := [
	"coin_pusher", "craps_table", "blackjack_table", "baccarat_table",
	"roulette_table", "slot_machine:*", "video_poker_machine",
	"pull_tab_dispenser", "scratch_ticket_machine", "bar_dice_table",
	"crew_cards", "crew_world", "scenario_transition",
]
const REQUIRED_CLASSES := {
	"craps_table": ["dice_shake", "dice_offer", "dice_roll", "table_contact", "dice_settle", "public_call", "chip_place", "chip_collect", "payout", "crowd_swell", "crowd_drop", "street_warning", "street_scatter"],
	"blackjack_table": ["blackjack_chip", "blackjack_deal", "clear", "payout", "shift_change"],
	"baccarat_table": ["baccarat_chip", "shoe", "cut_card", "card_squeeze", "clear", "payout", "dealer_procedure", "shift_change"],
	"roulette_table": ["roulette_chip_place", "wheel", "ball", "dolly", "clear", "payout", "dealer_procedure"],
	"slot_machine:*": ["machine_button", "wager_accept", "settlement", "reel_stop", "feature_entry", "jackpot_ack", "tower_light", "attract"],
	"video_poker_machine": ["video_poker_button", "wager_accept", "settlement", "video_poker_deal", "video_poker_draw", "attract"],
	"pull_tab_dispenser": ["ticket_dispenser", "ticket_handoff", "ticket_peel", "redemption", "refusal"],
	"scratch_ticket_machine": ["ticket_dispenser", "scratch", "ticket_peel", "redemption", "refusal"],
	"bar_dice_table": ["cup_shake", "cup_slam", "cup_lift", "dice_reveal", "cash_bar"],
	"crew_cards": ["chips_place", "card_deal", "card_draw", "public_tell_beat"],
	"crew_world": ["door", "handoff", "package", "stash", "duck", "pursuit", "sweep_proximity", "book_close", "slip_written", "draw_called", "confrontation"],
}

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var entries := ManifestScript.load_entries()
	var profiles := ManifestScript.profile_map(entries)
	for failure in ManifestScript.validation_errors(entries):
		failures.append("Manifest validation: %s" % failure)
	var actual_ids: Array[String] = []
	for key in profiles.keys():
		actual_ids.append(str(key))
	actual_ids.sort()
	var expected_ids := EXPECTED_PROFILES.duplicate()
	expected_ids.sort()
	_check(actual_ids == expected_ids, "Profile coverage differs: %s" % JSON.stringify(actual_ids))
	for profile_id in REQUIRED_CLASSES:
		var classes: Dictionary = _dict(_dict(profiles.get(profile_id, {})).get("event_classes", {}))
		for class_id in REQUIRED_CLASSES[profile_id]:
			_check(classes.has(class_id), "%s is missing event class %s" % [profile_id, class_id])
	var scenario_classes: Dictionary = _dict(_dict(profiles.get("scenario_transition", {})).get("event_classes", {}))
	_check(scenario_classes.size() == 16, "Scenario transitions must declare the 16 host-authored cue classes, got %d" % scenario_classes.size())
	var profile_declarations := {
		"res://scripts/games/craps.gd": "craps_table",
		"res://scripts/games/blackjack.gd": "blackjack_table",
		"res://scripts/games/baccarat.gd": "baccarat_table",
		"res://scripts/games/roulette.gd": "roulette_table",
		"res://scripts/games/video_poker.gd": "video_poker_machine",
		"res://scripts/games/pull_tabs.gd": "pull_tab_dispenser",
		"res://scripts/games/scratch_tickets.gd": "scratch_ticket_machine",
		"res://scripts/games/bar_dice.gd": "bar_dice_table",
		"res://scripts/games/crew_draw_poker.gd": "crew_cards",
		"res://scripts/games/coin_pusher.gd": "coin_pusher",
		"res://scripts/games/slots/slot_presentation.gd": "slot_machine:",
	}
	for source_path in profile_declarations:
		var source := FileAccess.get_file_as_string(str(source_path))
		var declared_profile := str(profile_declarations[source_path])
		_check(source.contains("\"profile_id\": \"%s" % declared_profile), "%s does not declare expected profile %s" % [source_path, declared_profile])
		var resolved_id := declared_profile + "audit" if declared_profile.ends_with(":") else declared_profile
		_check(not ManifestScript.resolve_profile(resolved_id, entries).is_empty(), "%s declares an unresolved profile %s" % [source_path, resolved_id])

	# The same pure selector is used before both native and Web playback. Ten seed
	# traces must be stable, and repeated classes may not reuse adjacent steps.
	for seed_index in range(10):
		for profile_id in profiles:
			var classes: Dictionary = _dict(_dict(profiles.get(profile_id, {})).get("event_classes", {}))
			for class_value in classes.keys():
				var class_id := str(class_value)
				var trace_a: Array = []
				var trace_b: Array = []
				var last_step := -1
				for occurrence in range(5):
					var selected_a: Dictionary = ManifestScript.select_event(str(profile_id), class_id, seed_index + 1, occurrence, last_step, entries)
					var selected_b: Dictionary = ManifestScript.select_event(str(profile_id), class_id, seed_index + 1, occurrence, last_step, entries)
					trace_a.append(selected_a)
					trace_b.append(selected_b)
					var step := int(selected_a.get("variation_step", -1))
					_check(step != last_step, "%s.%s repeated adjacent variation step %d" % [profile_id, class_id, step])
					last_step = step
				_check(trace_a == trace_b, "%s.%s changed an identical seed trace" % [profile_id, class_id])

	var sfx := SfxPlayerScript.new()
	var unique_events: Dictionary = {}
	for profile_value in profiles.values():
		var profile: Dictionary = _dict(profile_value)
		for event_value in _dict(profile.get("event_classes", {})).values():
			unique_events[str(event_value)] = true
		var motor := _dict(profile.get("motor_loop", {}))
		if not str(motor.get("event_id", "")).is_empty():
			unique_events[str(motor.get("event_id", ""))] = true
	for event_value in unique_events.keys():
		var stream: AudioStreamWAV = sfx.preview_event_stream(str(event_value))
		_check(stream != null and not stream.data.is_empty(), "Declared event %s has no generated/delivered stream" % event_value)
	sfx.free()

	var sfx_source := FileAccess.get_file_as_string("res://scripts/ui/sfx_player.gd")
	var manifest_source := FileAccess.get_file_as_string("res://scripts/core/surface_sfx_manifest.gd")
	var host_source := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	var web_source := FileAccess.get_file_as_string("res://scripts/ui/web_audio_bridge.gd")
	_check(not manifest_source.contains("Time."), "Manifest selection depends on wall-clock time")
	_check(sfx_source.contains("Unknown surface SFX profile") and sfx_source.contains("Unknown surface SFX event class"), "Unknown profiles or event classes do not fail loudly")
	_check(sfx_source.contains("_sync_manifest_timed_events") and sfx_source.contains("boundary\": \"animation_fact"), "Ritual sounds are not bound to authored animation facts")
	_check(host_source.contains("scenario_transition") and host_source.contains("transition_op"), "Scenario sounds are not bound to transition operations")
	_check(web_source.contains("sfxOneShots") and web_source.contains("max_voices") and web_source.contains("profile_id"), "Web playback lacks the per-surface bounded voice policy")
	_check(web_source.contains("_sync_output_levels()") and web_source.contains("_audio_bus_linear(\"SFX\")"), "Web playback does not honor the shipped SFX mixer setting")
	_check(SfxPlayerScript.ONE_SHOT_PLAYER_COUNT <= ManifestScript.MAX_VOICES, "Native voice pool exceeds the manifest hard maximum")

	if failures.is_empty():
		print("AUDIO06_1 SURFACE SFX AUDIT PASS: %d profiles, %d event streams, 10 deterministic seed traces." % [profiles.size(), unique_events.size()])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, failure: String) -> void:
	if not condition:
		failures.append(failure)


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
