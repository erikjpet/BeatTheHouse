extends SceneTree

const ManifestScript := preload("res://scripts/core/surface_sfx_manifest.gd")
const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")
const WebAudioBridgeScript := preload("res://scripts/ui/web_audio_bridge.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")

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
	print("AUDIO06_1 audit: manifest and coverage")
	var entries := ManifestScript.load_entries()
	var profiles := ManifestScript.profile_map(entries)
	for failure in ManifestScript.validation_errors(entries):
		failures.append("Manifest validation: %s" % failure)
	_run_negative_manifest_cases(entries)
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

	print("AUDIO06_1 audit: deterministic native/Web and hidden-state traces")
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
				var native_trace := JSON.stringify(trace_a)
				var web_trace := JSON.stringify(trace_b)
				_check(native_trace == web_trace, "%s.%s diverged between native and Web selection" % [profile_id, class_id])
				# Hidden fields never enter the selector. Paired observers with the
				# same public boundary therefore receive byte-identical traces.
				var hidden_a := {"traitor": true, "future_draw": [1, 2, 3], "rigged": true}
				var hidden_b := {"traitor": false, "future_draw": [9], "rigged": false}
				_check(hidden_a != hidden_b and native_trace == web_trace, "%s.%s hidden-state observer pair diverged" % [profile_id, class_id])

	var sfx := SfxPlayerScript.new()
	var unique_events: Dictionary = {}
	for profile_value in profiles.values():
		var profile: Dictionary = _dict(profile_value)
		for event_value in _dict(profile.get("event_classes", {})).values():
			unique_events[str(event_value)] = true
		var motor := _dict(profile.get("motor_loop", {}))
		if not str(motor.get("event_id", "")).is_empty():
			unique_events[str(motor.get("event_id", ""))] = true
	print("AUDIO06_1 audit: %d delivery signal probes" % unique_events.size())
	for event_value in unique_events.keys():
		_check(bool(sfx.call("debug_event_delivery_has_signal", str(event_value))), "Declared event %s has no generated/delivered signal" % event_value)
	_check(not bool(sfx.call("debug_event_delivery_has_signal", "audio06_missing_delivery")), "An undeclared/missing delivery produced audible output")
	print("AUDIO06_1 audit: authority, voice, mixer, and frame-budget probes")
	_run_authority_and_budget_cases(sfx)
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
	_check(web_source.contains("var globalMaxVoices = 10") and web_source.contains("this.sfxOneShots.length >= globalMaxVoices"), "Web playback lacks the hard global cap and oldest-global steal")
	_check(web_source.contains("_sync_output_levels()") and web_source.contains("_audio_bus_linear(\"SFX\")"), "Web playback does not honor the shipped SFX mixer setting")
	_check(SfxPlayerScript.ONE_SHOT_PLAYER_COUNT <= ManifestScript.MAX_VOICES, "Native voice pool exceeds the manifest hard maximum")
	_check(sfx_source.contains("func _process(_delta: float) -> void:\n\t_process_prewarm_chunk()"), "SFX frame processing gained work outside bounded prewarm")

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


func _run_negative_manifest_cases(entries: Array) -> void:
	var duplicate := entries.duplicate(true)
	duplicate.append((entries[0] as Dictionary).duplicate(true))
	_expect_invalid(duplicate, "duplicate profile")

	var unknown_key := entries.duplicate(true)
	(unknown_key[0] as Dictionary)["caller_asset_path"] = "res://secret.wav"
	_expect_invalid(unknown_key, "unknown entry key")

	var unbounded := entries.duplicate(true)
	_dict((unbounded[0] as Dictionary).get("profile", {}))["max_voices"] = ManifestScript.MAX_VOICES + 1
	_expect_invalid(unbounded, "unbounded voice count")

	var unsafe_event := entries.duplicate(true)
	var unsafe_classes := _dict(_dict((unsafe_event[0] as Dictionary).get("profile", {})).get("event_classes", {}))
	unsafe_classes["impact_metal"] = "../outside_delivery"
	_expect_invalid(unsafe_event, "traversal event id")

	var unknown_class := entries.duplicate(true)
	var unknown_counterparts := _dict(_dict((unknown_class[0] as Dictionary).get("profile", {})).get("visual_counterparts", {}))
	unknown_counterparts["not_an_event_class"] = "cabinet.fake"
	_expect_invalid(unknown_class, "unknown event class")

	var nonfinite := entries.duplicate(true)
	_dict((nonfinite[0] as Dictionary).get("profile", {}))["variation_pitch_steps"] = [0.0, NAN]
	_expect_invalid(nonfinite, "non-finite variation")

	var ambiguous := entries.duplicate(true)
	var wildcard_entry := (entries[5] as Dictionary).duplicate(true)
	wildcard_entry["id"] = "slot_machine:deluxe*"
	ambiguous.append(wildcard_entry)
	_expect_invalid(ambiguous, "ambiguous wildcard profile")

	_check(ManifestScript.resolve_profile("undeclared_profile", entries).is_empty(), "Undeclared profile resolved")
	_check(ManifestScript.select_event("coin_pusher", "undeclared_class", 1, 0, -1, entries).is_empty(), "Unknown event class selected a delivery")


func _expect_invalid(entries: Array, label: String) -> void:
	_check(not ManifestScript.validation_errors(entries).is_empty(), "Manifest accepted %s" % label)


func _run_authority_and_budget_cases(sfx: Node) -> void:
	var authority_a := RefCounted.new()
	var authority_b := RefCounted.new()
	sfx.call("bind_surface_audio_authority", authority_a)
	sfx.call("bind_surface_audio_authority", authority_b)
	_check(sfx.get("_surface_audio_authority") == authority_a, "SFX authority capability was rebound by a hostile caller")
	var before := sfx.call("debug_soak_snapshot") as Dictionary
	sfx.call("play_surface_cue", "impact_metal", {"profile_id": "coin_pusher"}, {"surface_audio": {"profile_id": "coin_pusher"}}, authority_b)
	sfx.call("start_surface_loop", "coin_pusher_motor", -12.0, 1.0, authority_b)
	sfx.call("sync_surface_state", {"surface_audio": {"profile_id": "coin_pusher"}}, {"method": "coin_pusher_state"}, {}, authority_b)
	sfx.call("prewarm_surface_profile", "coin_pusher", authority_b)
	var after := sfx.call("debug_soak_snapshot") as Dictionary
	_check(int(after.get("rejected_surface_authority_calls", 0)) == int(before.get("rejected_surface_authority_calls", 0)) + 4, "Unauthorized cue/loop/sync/prewarm calls were not all rejected")
	_check(str(after.get("surface_loop_event_id", "")).is_empty(), "Unauthorized caller changed loop state")
	_check(int(after.get("prewarm_queue_size", 0)) == int(before.get("prewarm_queue_size", 0)), "Unauthorized caller loaded a profile")

	var canvas := GameSurfaceCanvasScript.new()
	canvas.call("bind_surface_audio_authority", authority_a)
	canvas.call("bind_surface_audio_authority", authority_b)
	_check(canvas.get("_surface_audio_authority") == authority_a, "Canvas authority capability was rebound by a hostile caller")
	canvas.call("_ensure_surface_sfx_player")
	var canvas_sfx := canvas.get("surface_sfx_player") as Node
	_check(canvas_sfx != null and canvas_sfx.get("_surface_audio_authority") == authority_a, "Canvas did not preserve host authority into SFX renderer")
	canvas.call("surface_play_audio_cue", "impact_metal", {"profile_id": "coin_pusher"}, authority_b)
	canvas.call("surface_start_audio_loop", "coin_pusher_motor", -12.0, 1.0, authority_b)
	var canvas_after := canvas_sfx.call("debug_soak_snapshot") as Dictionary
	_check(str(canvas_after.get("surface_loop_event_id", "")).is_empty(), "Hostile Canvas rebind changed loop state")
	canvas.free()

	var under_cap := [
		{"source_index": 0, "profile_id": "a", "serial": 3},
		{"source_index": 1, "profile_id": "b", "serial": 1},
	]
	var allocate := ManifestScript.voice_slot_decision(under_cap, "a", 5, 10)
	_check(str(allocate.get("kind", "")) == "allocate_idle", "Voice planner did not allocate below both caps")
	var at_profile_cap: Array = [{"source_index": 0, "profile_id": "other", "serial": 1}]
	for index in range(5):
		at_profile_cap.append({"source_index": index + 1, "profile_id": "target", "serial": 10 + index})
	var same_steal := ManifestScript.voice_slot_decision(at_profile_cap, "target", 5, 10)
	_check(str(same_steal.get("kind", "")) == "steal_same_surface" and int(same_steal.get("source_index", -1)) == 1, "Voice planner did not steal oldest same-surface voice before idle/global")
	var at_global_cap: Array = []
	for index in range(10):
		at_global_cap.append({"source_index": index, "profile_id": "p%d" % index, "serial": index + 1})
	var global_steal := ManifestScript.voice_slot_decision(at_global_cap, "new", 5, 10)
	_check(str(global_steal.get("kind", "")) == "steal_oldest_global" and int(global_steal.get("source_index", -1)) == 0, "Voice planner did not deterministically steal oldest global voice")

	sfx.call("_ensure_players")
	var bounded := sfx.call("debug_soak_snapshot") as Dictionary
	_check(int(bounded.get("player_count", 0)) == SfxPlayerScript.ONE_SHOT_PLAYER_COUNT, "Native one-shot pool is not hard bounded")
	for child in sfx.get_children():
		if child is AudioStreamPlayer:
			_check((child as AudioStreamPlayer).bus == "SFX", "Native surface voice bypasses SFX mixer bus")
	var frame_before := sfx.call("debug_soak_snapshot") as Dictionary
	sfx.call("_process", 1.0 / 60.0)
	var frame_after := sfx.call("debug_soak_snapshot") as Dictionary
	_check(int(frame_after.get("stream_cache_size", 0)) == int(frame_before.get("stream_cache_size", 0)), "Idle frame generated or loaded audio")
	_check(int(frame_after.get("surface_selection_trace_size", 0)) == int(frame_before.get("surface_selection_trace_size", 0)), "Frame advance created an audio event without a fact/op")




func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
