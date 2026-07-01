extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var failures: Array = []
var warnings: Array = []
var stats: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var seed_count := 120
	var output_path := "res://.tmp/blackjack_seed_audit/report.json"
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--seed-count="):
			seed_count = maxi(1, int(text.trim_prefix("--seed-count=")))
		elif text.begins_with("--output="):
			output_path = text.trim_prefix("--output=")

	stats = {
		"seed_count": seed_count,
		"generated_tables": 0,
		"clean_hands": 0,
		"clean_resolves": 0,
		"count_hands": 0,
		"count_icons": 0,
		"zero_count_icons": 0,
		"safe_peeks": 0,
		"watched_peek_ejections": 0,
		"strategy_confrontations": 0,
		"patron_peek_adjustments": 0,
		"side_bet_tables": 0,
		"side_bet_resolves": 0,
		"compact_ui_states": 0,
		"action_command_samples": 0,
		"max_action_command_ms": 0.0,
		"split_fixture_passes": 0,
		"double_fixture_passes": 0,
		"surrender_fixture_passes": 0,
		"natural_fixture_passes": 0,
		"outcomes": {},
		"deck_counts": {},
		"side_bets": {},
		"rules": {},
	}

	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	if not library.validation_errors.is_empty():
		for error in library.validation_errors:
			failures.append("ContentLibrary validation error: %s" % error)

	var game := _load_blackjack(library)
	if game == null:
		_write_report(output_path, seed_count)
		_print_summary()
		await _finish(1)
		return

	for i in range(seed_count):
		_run_generated_seed(game, i)

	_run_forced_rule_fixtures(game)
	_run_cheat_fixtures(game)
	_write_report(output_path, seed_count)
	_print_summary()
	await _finish(0 if failures.is_empty() else 1)


func _finish(exit_code: int) -> void:
	await process_frame
	quit(exit_code)


func _load_blackjack(library: ContentLibrary) -> GameModule:
	var definition: Dictionary = library.game("blackjack")
	if definition.is_empty():
		failures.append("Blackjack definition was not found.")
		return null
	var module_path := str(definition.get("module_path", ""))
	var module_script: Script = load(module_path)
	if module_script == null:
		failures.append("Blackjack module could not be loaded from %s." % module_path)
		return null
	var instance = module_script.new()
	if not instance is GameModule:
		failures.append("Blackjack module does not extend GameModule.")
		return null
	var game: GameModule = instance
	game.setup(definition, library)
	return game


func _run_generated_seed(game: GameModule, index: int) -> void:
	var seed := "BLACKJACK-AUDIT-%03d" % index
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	run_state.change_bankroll(400)
	var environment := _audit_environment(index)
	run_state.current_environment = environment
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("table_%03d" % index))
	environment["game_states"] = {"blackjack": table}
	run_state.current_environment = environment
	stats["generated_tables"] = int(stats.get("generated_tables", 0)) + 1
	_audit_generated_table(table, index)
	_audit_entry_and_surface(game, run_state, environment, index)
	_audit_clean_hand(game, run_state, environment, index)
	_audit_count_hand(game, index)


func _audit_environment(index: int) -> Dictionary:
	var strictness_values := ["low", "private", "high", "boss", "uneven"]
	return {
		"id": "blackjack_audit_room_%03d" % index,
		"display_name": "Blackjack Audit Room %03d" % index,
		"depth": index % 4,
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 200},
		"security_profile": {"strictness": strictness_values[index % strictness_values.size()]},
	}


func _audit_generated_table(table: Dictionary, index: int) -> void:
	var deck_count := int(table.get("deck_count", 0))
	_count_key("deck_counts", str(deck_count))
	if not [2, 3, 4, 6].has(deck_count):
		failures.append("Seed %d generated unsupported deck count %d." % [index, deck_count])
	var shoe: Array = table.get("shoe", []) as Array
	if shoe.size() != deck_count * 52:
		failures.append("Seed %d generated shoe size %d for %d decks." % [index, shoe.size(), deck_count])
	if int(table.get("shoe_remaining", 0)) != shoe.size():
		failures.append("Seed %d generated mismatched shoe_remaining." % index)
	var side_bets: Array = table.get("side_bets", []) as Array
	if side_bets.size() > 2:
		failures.append("Seed %d generated more than two blackjack side bets." % index)
	if not side_bets.is_empty():
		stats["side_bet_tables"] = int(stats.get("side_bet_tables", 0)) + 1
	for side_bet_value in side_bets:
		if typeof(side_bet_value) == TYPE_DICTIONARY:
			var side_bet: Dictionary = side_bet_value
			_count_key("side_bets", str(side_bet.get("id", "")))
			if (side_bet.get("rules", []) as Array).is_empty() or (side_bet.get("payouts", []) as Array).is_empty():
				failures.append("Seed %d generated side bet without rule/payout help." % index)
	var rules: Dictionary = table.get("rules", {}) if typeof(table.get("rules", {})) == TYPE_DICTIONARY else {}
	_count_key("rules", "h17_%s" % str(bool(rules.get("dealer_hits_soft_17", false))))
	_count_key("rules", "das_%s" % str(bool(rules.get("double_after_split", false))))
	_count_key("rules", "surrender_%s" % str(bool(rules.get("late_surrender", false))))


func _audit_entry_and_surface(game: GameModule, run_state: RunState, environment: Dictionary, index: int) -> void:
	var before := JSON.stringify(environment)
	var enter_result := game.enter(run_state, environment)
	if not bool(enter_result.get("ok", false)):
		failures.append("Seed %d blackjack enter failed." % index)
	if JSON.stringify(environment) != before:
		failures.append("Seed %d blackjack enter mutated environment state." % index)
	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "blackjack":
		failures.append("Seed %d surface renderer was not blackjack." % index)
	for key in ["dealer_focus", "patrons", "chip_denominations", "side_bets_available", "surface_animation_channels"]:
		if not surface.has(key):
			failures.append("Seed %d surface omitted %s." % [index, key])
	_audit_blackjack_audio_spec(surface, index)
	if bool(surface.get("table_barred", false)):
		failures.append("Seed %d generated table started barred." % index)


func _audit_blackjack_audio_spec(surface: Dictionary, index: int) -> void:
	var audio: Dictionary = surface.get("surface_audio", {}) if typeof(surface.get("surface_audio", {})) == TYPE_DICTIONARY else {}
	if str(audio.get("profile_id", "")) != "blackjack_table":
		failures.append("Seed %d blackjack surface audio profile was not blackjack_table." % index)
	var action_cues: Dictionary = audio.get("action_cues", {}) if typeof(audio.get("action_cues", {})) == TYPE_DICTIONARY else {}
	for action in ["blackjack_deal", "blackjack_hit", "blackjack_stand", "blackjack_double", "blackjack_split", "blackjack_surrender", "blackjack_side_bet", "blackjack_peek", "blackjack_count_toggle", "blackjack_count_icon", "blackjack_distraction", "blackjack_chip"]:
		if not action_cues.has(action):
			failures.append("Seed %d blackjack surface audio omitted cue for %s." % [index, action])
	var sync: Dictionary = audio.get("state_sync", {}) if typeof(audio.get("state_sync", {})) == TYPE_DICTIONARY else {}
	if str(sync.get("method", "")) != "blackjack_table_state":
		failures.append("Seed %d blackjack surface audio sync method was not blackjack_table_state." % index)
	if str(sync.get("deal_animation_channel", "")).is_empty() or str(sync.get("payout_animation_channel", "")).is_empty():
		failures.append("Seed %d blackjack surface audio sync omitted animation channels." % index)


func _audit_clean_hand(game: GameModule, run_state: RunState, environment: Dictionary, index: int) -> void:
	var ui: Dictionary = {"selected_stake": 5}
	var surface := game.surface_state(run_state, environment, ui)
	var side_bets: Array = surface.get("side_bets_available", []) as Array
	if not side_bets.is_empty() and index % 3 == 0:
		var side_click := game.surface_action_command("blackjack_side_bet", 0, false, ui, run_state, environment)
		ui = side_click.get("ui_state", {})
	var deal_start_usec := Time.get_ticks_usec()
	var deal := game.surface_action_command("blackjack_deal", 0, false, ui, run_state, environment)
	_record_action_command_time(deal_start_usec)
	if not bool(deal.get("handled", false)):
		failures.append("Seed %d clean hand deal was not handled." % index)
		return
	ui = deal.get("ui_state", {})
	_audit_compact_ui_state(ui, "seed %d deal" % index)
	stats["clean_hands"] = int(stats.get("clean_hands", 0)) + 1
	var result := _play_to_resolve(game, run_state, environment, ui, "clean_%03d" % index)
	if result.is_empty():
		failures.append("Seed %d clean hand did not resolve." % index)
		return
	_validate_result(result, environment, "seed %d clean hand" % index)
	stats["clean_resolves"] = int(stats.get("clean_resolves", 0)) + 1
	for hand_value in result.get("blackjack_hand_results", []):
		if typeof(hand_value) == TYPE_DICTIONARY:
			_count_key("outcomes", str((hand_value as Dictionary).get("outcome", "")))
	if not (result.get("blackjack_side_bet_results", []) as Array).is_empty():
		stats["side_bet_resolves"] = int(stats.get("side_bet_resolves", 0)) + 1


func _audit_count_hand(game: GameModule, index: int) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BLACKJACK-AUDIT-COUNT-%03d" % index)
	run_state.change_bankroll(400)
	var environment := _audit_environment(10000 + index)
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("count_table_%03d" % index))
	environment["game_states"] = {"blackjack": table}
	var count_toggle := game.surface_action_command("blackjack_count_toggle", 0, false, {"selected_stake": 5}, run_state, environment)
	var deal := game.surface_action_command("blackjack_deal", 0, false, count_toggle.get("ui_state", {}), run_state, environment)
	var ui: Dictionary = deal.get("ui_state", {})
	var challenge: Dictionary = ui.get("count_challenge", {}) if typeof(ui.get("count_challenge", {})) == TYPE_DICTIONARY else {}
	if challenge.is_empty():
		failures.append("Seed %d count hand did not create count challenge." % index)
		return
	stats["count_hands"] = int(stats.get("count_hands", 0)) + 1
	_audit_count_challenge(challenge, "seed %d initial count" % index)
	var icons: Array = challenge.get("icons", []) as Array
	if not icons.is_empty() and index % 4 == 0:
		var now := Time.get_ticks_msec()
		for i in range(icons.size()):
			if typeof(icons[i]) == TYPE_DICTIONARY:
				var icon: Dictionary = icons[i]
				icon["spawn_msec"] = now - 10
				icon["duration_msec"] = 5000
				icons[i] = icon
		challenge["icons"] = icons
		ui["count_challenge"] = challenge
		for i in range(icons.size()):
			var pulse := game.surface_action_command("blackjack_count_icon", i, false, ui, run_state, environment)
			ui = pulse.get("ui_state", {})
		var clean_count_result := game.resolve_with_context("count_cards", 0, run_state, environment, run_state.create_rng("count_resolve_%03d" % index), ui)
		if int(clean_count_result.get("suspicion_delta", 0)) != 0:
			failures.append("Seed %d clean count pulse run created heat." % index)


func _audit_count_challenge(challenge: Dictionary, label: String) -> void:
	var cards: Array = challenge.get("cards", []) as Array
	var icons: Array = challenge.get("icons", []) as Array
	var countable := 0
	for card_value in cards:
		if typeof(card_value) == TYPE_DICTIONARY and _count_value_for_card(card_value as Dictionary) != 0:
			countable += 1
	if icons.size() != countable:
		failures.append("%s had %d icons for %d count-changing cards." % [label, icons.size(), countable])
	for icon_value in icons:
		if typeof(icon_value) != TYPE_DICTIONARY:
			failures.append("%s had non-dictionary count icon." % label)
			continue
		var icon: Dictionary = icon_value
		var value := int(icon.get("count_value", 0))
		stats["count_icons"] = int(stats.get("count_icons", 0)) + 1
		if value == 0:
			stats["zero_count_icons"] = int(stats.get("zero_count_icons", 0)) + 1
			failures.append("%s created a zero-value count icon." % label)
		if not icon.has("spawn_msec") or not icon.has("duration_msec"):
			failures.append("%s count icon lacked timing fields." % label)


func _play_to_resolve(game: GameModule, run_state: RunState, environment: Dictionary, ui: Dictionary, rng_key: String) -> Dictionary:
	var rng := run_state.create_rng(rng_key)
	for _i in range(16):
		var surface := game.surface_state(run_state, environment, ui)
		if bool(surface.get("settle_available", false)) or bool(surface.get("round_complete", false)):
			var settle_start_usec := Time.get_ticks_usec()
			var settle := game.surface_action_command("blackjack_deal", 0, true, ui, run_state, environment)
			_record_action_command_time(settle_start_usec)
			ui = settle.get("ui_state", {})
			_audit_compact_ui_state(ui, "settle command")
			if bool(settle.get("resolve", false)):
				return game.resolve_with_context(str(settle.get("action_id", "play_basic")), int(ui.get("locked_stake", ui.get("selected_stake", 5))), run_state, environment, rng, ui)
			continue
		var action := _choose_clean_action(surface, rng)
		var command_start_usec := Time.get_ticks_usec()
		var command := game.surface_action_command(action, 0, false, ui, run_state, environment)
		_record_action_command_time(command_start_usec)
		if not bool(command.get("handled", false)):
			var fallback_start_usec := Time.get_ticks_usec()
			command = game.surface_action_command("blackjack_stand", 0, false, ui, run_state, environment)
			_record_action_command_time(fallback_start_usec)
		ui = command.get("ui_state", {})
		_audit_compact_ui_state(ui, "hand command %s" % action)
		if bool(command.get("resolve", false)):
			return game.resolve_with_context(str(command.get("action_id", "play_basic")), int(ui.get("locked_stake", ui.get("selected_stake", 5))), run_state, environment, rng, ui)
	return {}


func _audit_compact_ui_state(ui: Dictionary, label: String) -> void:
	var shoe: Array = ui.get("shoe", []) as Array
	if not bool(ui.get("shoe_refilled_during_hand", false)) and not shoe.is_empty():
		failures.append("%s retained %d shoe cards in transient UI state." % [label, shoe.size()])
	if int(ui.get("cards_consumed", 0)) > 0 and int(ui.get("shoe_remaining", 0)) <= 0 and not bool(ui.get("shoe_refilled_during_hand", false)):
		failures.append("%s lost compact shoe remaining metadata." % label)
	stats["compact_ui_states"] = int(stats.get("compact_ui_states", 0)) + 1


func _record_action_command_time(start_usec: int) -> void:
	var elapsed_ms := float(Time.get_ticks_usec() - start_usec) / 1000.0
	stats["action_command_samples"] = int(stats.get("action_command_samples", 0)) + 1
	stats["max_action_command_ms"] = maxf(float(stats.get("max_action_command_ms", 0.0)), elapsed_ms)


func _choose_clean_action(surface: Dictionary, rng: RngStream) -> String:
	var total := int(surface.get("blackjack_total", 0))
	var dealer_cards: Array = surface.get("dealer_cards", []) as Array
	var dealer_up := 10
	if not dealer_cards.is_empty() and typeof(dealer_cards[0]) == TYPE_DICTIONARY:
		dealer_up = _dealer_up_value(dealer_cards[0] as Dictionary)
	if bool(surface.get("can_surrender", false)) and total == 16 and dealer_up >= 9:
		return "blackjack_surrender"
	if bool(surface.get("can_split", false)) and rng.randi_range(1, 100) <= 18:
		return "blackjack_split"
	if bool(surface.get("can_double", false)) and total >= 9 and total <= 11 and rng.randi_range(1, 100) <= 45:
		return "blackjack_double"
	if bool(surface.get("can_hit", false)) and (total <= 11 or (total <= 16 and dealer_up >= 7)):
		return "blackjack_hit"
	if bool(surface.get("can_stand", false)):
		return "blackjack_stand"
	if bool(surface.get("can_hit", false)):
		return "blackjack_hit"
	return "blackjack_deal"


func _run_forced_rule_fixtures(game: GameModule) -> void:
	_force_natural(game)
	_force_split_double(game)
	_force_surrender(game)


func _force_natural(game: GameModule) -> void:
	var data := _fixture_env("natural")
	var table: Dictionary = data.table
	table["patrons"] = []
	table["side_bets"] = []
	table["shoe"] = [
		{"rank": 14, "suit": 0}, {"rank": 9, "suit": 2}, {"rank": 13, "suit": 1}, {"rank": 7, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 6, "suit": 1}, {"rank": 8, "suit": 2}, {"rank": 4, "suit": 3}
	]
	data.environment["game_states"] = {"blackjack": table}
	var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, data.run_state, data.environment)
	var settle := game.surface_action_command("blackjack_deal", 0, false, deal.get("ui_state", {}), data.run_state, data.environment)
	var result := game.resolve_with_context("play_basic", 5, data.run_state, data.environment, data.run_state.create_rng("natural_resolve"), settle.get("ui_state", {}))
	var hands: Array = result.get("blackjack_hand_results", []) as Array
	if hands.is_empty() or str((hands[0] as Dictionary).get("outcome", "")) != "blackjack":
		failures.append("Natural blackjack fixture did not settle as blackjack.")
	else:
		stats["natural_fixture_passes"] = int(stats.get("natural_fixture_passes", 0)) + 1


func _force_split_double(game: GameModule) -> void:
	var data := _fixture_env("split_double")
	var table: Dictionary = data.table
	table["patrons"] = []
	table["side_bets"] = []
	table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	table["shoe"] = [
		{"rank": 8, "suit": 0}, {"rank": 6, "suit": 2}, {"rank": 8, "suit": 1}, {"rank": 10, "suit": 3},
		{"rank": 3, "suit": 0}, {"rank": 2, "suit": 1}, {"rank": 10, "suit": 2}, {"rank": 5, "suit": 3},
		{"rank": 4, "suit": 0}, {"rank": 7, "suit": 1}, {"rank": 9, "suit": 2}, {"rank": 6, "suit": 3}
	]
	data.environment["game_states"] = {"blackjack": table}
	var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, data.run_state, data.environment)
	var split := game.surface_action_command("blackjack_split", 0, false, deal.get("ui_state", {}), data.run_state, data.environment)
	var split_ui: Dictionary = split.get("ui_state", {})
	if (split_ui.get("player_hands", []) as Array).size() != 2:
		failures.append("Split fixture did not create two hands.")
	else:
		stats["split_fixture_passes"] = int(stats.get("split_fixture_passes", 0)) + 1
	var double := game.surface_action_command("blackjack_double", 0, false, split_ui, data.run_state, data.environment)
	var double_ui: Dictionary = double.get("ui_state", {})
	var doubled_seen := false
	for hand_value in (double_ui.get("player_hands", []) as Array):
		if typeof(hand_value) == TYPE_DICTIONARY and bool((hand_value as Dictionary).get("doubled", false)):
			doubled_seen = true
	if not doubled_seen:
		failures.append("Double-after-split fixture did not mark a doubled hand.")
	else:
		stats["double_fixture_passes"] = int(stats.get("double_fixture_passes", 0)) + 1


func _force_surrender(game: GameModule) -> void:
	var data := _fixture_env("surrender")
	var table: Dictionary = data.table
	table["patrons"] = []
	table["side_bets"] = []
	table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 10, "suit": 2}, {"rank": 6, "suit": 1}, {"rank": 7, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 9, "suit": 2}, {"rank": 4, "suit": 3}
	]
	data.environment["game_states"] = {"blackjack": table}
	var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, data.run_state, data.environment)
	var surrender := game.surface_action_command("blackjack_surrender", 0, false, deal.get("ui_state", {}), data.run_state, data.environment)
	var result := game.resolve_with_context("play_basic", 5, data.run_state, data.environment, data.run_state.create_rng("surrender_resolve"), surrender.get("ui_state", {}))
	var hands: Array = result.get("blackjack_hand_results", []) as Array
	if hands.is_empty() or str((hands[0] as Dictionary).get("outcome", "")) != "surrender":
		failures.append("Surrender fixture did not settle as surrender.")
	else:
		stats["surrender_fixture_passes"] = int(stats.get("surrender_fixture_passes", 0)) + 1


func _run_cheat_fixtures(game: GameModule) -> void:
	_force_safe_peek(game)
	_force_watched_peek(game)
	_force_strategy_confrontation(game)
	_force_patron_peek_adjustment(game)


func _force_safe_peek(game: GameModule) -> void:
	var data := _fixture_env("safe_peek")
	var table: Dictionary = data.table
	table["patrons"] = []
	table["side_bets"] = []
	table["dealer_profile"] = {"attention_base": 8, "gaze_speed": 95, "blink_offset": 0, "tell": "test", "strategy_scrutiny": 8, "strategy_threshold": 4, "strategy_response": "watch"}
	table["distractions"] = [{"id": "safe_window", "label": "Safe Window", "summary": "safe peek", "duration_msec": 4000, "cover": 20, "noise": 0}]
	table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 9, "suit": 1}, {"rank": 7, "suit": 2}, {"rank": 10, "suit": 3},
		{"rank": 4, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 3, "suit": 2}, {"rank": 2, "suit": 3}
	]
	data.environment["game_states"] = {"blackjack": table}
	var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, data.run_state, data.environment)
	var distract := game.surface_action_command("blackjack_distraction", 0, false, deal.get("ui_state", {}), data.run_state, data.environment)
	var peek := game.surface_action_command("blackjack_peek", 0, false, distract.get("ui_state", {}), data.run_state, data.environment)
	var peek_ui: Dictionary = peek.get("ui_state", {})
	if bool(peek_ui.get("dealer_hole_visible", false)) and not bool(peek_ui.get("peek_caught_watching", false)):
		stats["safe_peeks"] = int(stats.get("safe_peeks", 0)) + 1
	else:
		failures.append("Safe peek fixture did not reveal the hole card cleanly.")


func _force_watched_peek(game: GameModule) -> void:
	var data := _fixture_env("watched_peek")
	var table: Dictionary = data.table
	table["patrons"] = []
	table["side_bets"] = []
	table["dealer_profile"] = {"attention_base": 100, "gaze_speed": 95, "blink_offset": 0, "tell": "test", "strategy_scrutiny": 8, "strategy_threshold": 4, "strategy_response": "watch"}
	table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 9, "suit": 1}, {"rank": 7, "suit": 2}, {"rank": 10, "suit": 3},
		{"rank": 4, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 3, "suit": 2}, {"rank": 2, "suit": 3}
	]
	data.environment["game_states"] = {"blackjack": table}
	var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, data.run_state, data.environment)
	var peek := game.surface_action_command("blackjack_peek", 0, false, deal.get("ui_state", {}), data.run_state, data.environment)
	if not bool(peek.get("resolve", false)):
		failures.append("Watched peek fixture did not resolve immediately.")
		return
	var result := game.resolve_with_context("peek_hole_card", 0, data.run_state, data.environment, data.run_state.create_rng("watched_peek_resolve"), peek.get("ui_state", {}))
	if bool(result.get("blackjack_table_barred", false)) and int(result.get("suspicion_delta", 0)) >= 60:
		stats["watched_peek_ejections"] = int(stats.get("watched_peek_ejections", 0)) + 1
	else:
		failures.append("Watched peek fixture did not bar table with high heat.")


func _force_strategy_confrontation(game: GameModule) -> void:
	var data := _fixture_env("strategy")
	var table: Dictionary = data.table
	table["patrons"] = []
	table["side_bets"] = []
	table["dealer_profile"] = {"attention_base": 10, "gaze_speed": 95, "blink_offset": 0, "tell": "tracks deviations", "strategy_scrutiny": 18, "strategy_threshold": 2, "strategy_response": "both"}
	table["distractions"] = [{"id": "safe_window", "label": "Safe Window", "summary": "safe peek", "duration_msec": 4000, "cover": 20, "noise": 0}]
	table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 10, "suit": 1}, {"rank": 7, "suit": 2}, {"rank": 10, "suit": 3},
		{"rank": 2, "suit": 0}, {"rank": 5, "suit": 1}, {"rank": 6, "suit": 2}, {"rank": 8, "suit": 3}
	]
	data.environment["game_states"] = {"blackjack": table}
	var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, data.run_state, data.environment)
	var distract := game.surface_action_command("blackjack_distraction", 0, false, deal.get("ui_state", {}), data.run_state, data.environment)
	var peek := game.surface_action_command("blackjack_peek", 0, false, distract.get("ui_state", {}), data.run_state, data.environment)
	var hit := game.surface_action_command("blackjack_hit", 0, false, peek.get("ui_state", {}), data.run_state, data.environment)
	var stand := game.surface_action_command("blackjack_stand", 0, false, hit.get("ui_state", {}), data.run_state, data.environment)
	var result := game.resolve_with_context("play_basic", 5, data.run_state, data.environment, data.run_state.create_rng("strategy_resolve"), stand.get("ui_state", {}))
	if bool(result.get("blackjack_strategy_confronted", false)) and int(result.get("suspicion_delta", 0)) > 0:
		stats["strategy_confrontations"] = int(stats.get("strategy_confrontations", 0)) + 1
	else:
		failures.append("Strategy deviation fixture did not create a heat-bearing confrontation.")


func _force_patron_peek_adjustment(game: GameModule) -> void:
	var data := _fixture_env("patron_peek")
	var table: Dictionary = data.table
	table["side_bets"] = []
	table["patrons"] = [{
		"id": "sharp_patron",
		"name": "Sharp Seat",
		"temper": "sharp",
		"snitch_risk": 0,
		"watching": false,
		"chip_stack": 40,
	}]
	table["dealer_profile"] = {"attention_base": 8, "gaze_speed": 95, "blink_offset": 0, "tell": "test", "strategy_scrutiny": 8, "strategy_threshold": 4, "strategy_response": "watch"}
	table["distractions"] = [{"id": "safe_window", "label": "Safe Window", "summary": "safe peek", "duration_msec": 4000, "cover": 20, "noise": 0}]
	table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 10, "suit": 1}, {"rank": 9, "suit": 2}, {"rank": 10, "suit": 3},
		{"rank": 10, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 2, "suit": 2}, {"rank": 6, "suit": 3}
	]
	data.environment["game_states"] = {"blackjack": table}
	var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, data.run_state, data.environment)
	var distract := game.surface_action_command("blackjack_distraction", 0, false, deal.get("ui_state", {}), data.run_state, data.environment)
	var peek := game.surface_action_command("blackjack_peek", 0, false, distract.get("ui_state", {}), data.run_state, data.environment)
	var stand := game.surface_action_command("blackjack_stand", 0, false, peek.get("ui_state", {}), data.run_state, data.environment)
	var result := game.resolve_with_context("play_basic", 5, data.run_state, data.environment, data.run_state.create_rng("patron_peek_resolve"), stand.get("ui_state", {}))
	var found_peek_hit := false
	for event_value in result.get("blackjack_patron_action_events", []) as Array:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		if int(event.get("patron_index", -1)) == 0 and str(event.get("action", "")) == "hit" and bool(event.get("peek_informed", false)):
			found_peek_hit = true
			break
	var surface := game.surface_state(data.run_state, data.environment, {})
	var surface_events: Array = surface.get("patron_action_events", []) as Array
	if found_peek_hit and not surface_events.is_empty():
		stats["patron_peek_adjustments"] = int(stats.get("patron_peek_adjustments", 0)) + 1
	else:
		failures.append("Patron peek fixture did not record a peek-informed patron hit.")


func _fixture_env(label: String) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BLACKJACK-AUDIT-%s" % label.to_upper())
	run_state.change_bankroll(400)
	var environment := {
		"id": "blackjack_audit_%s" % label,
		"display_name": "Blackjack Audit %s" % label,
		"depth": 0,
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 200},
		"security_profile": {"strictness": "low"},
	}
	var table: Dictionary = {
		"schema": "blackjack_table_state",
		"version": 2,
		"table_name": "Audit Table",
		"dealer_name": "Audit Dealer",
		"deck_count": 4,
		"shoe": [],
		"shoe_cursor": 0,
		"cut_card_at": 4 * 52 - 40,
		"cut_card_remaining": 40,
		"shoe_remaining": 0,
		"shoe_composition": {},
		"shoe_label": "4 deck shoe",
		"count_efficiency": "high",
		"hands_played": 0,
		"running_count": 0,
		"recorded_running_count": 0,
		"count_accuracy_streak": 0,
		"rules": {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true},
		"side_bets": [],
		"dealer_profile": {"attention_base": 12, "gaze_speed": 95, "blink_offset": 0, "tell": "test", "strategy_scrutiny": 10, "strategy_threshold": 4, "strategy_response": "watch"},
		"patrons": [],
		"distractions": [],
		"chip_denominations": [1, 5, 10, 25],
		"table_layout": "immersive_blackjack",
		"dealer_catch_base": 9,
		"catch_heat": 17,
		"last_result": {},
	}
	run_state.current_environment = environment
	return {"run_state": run_state, "environment": environment, "table": table}


func _validate_result(result: Dictionary, environment: Dictionary, label: String) -> void:
	if not bool(result.get("ok", false)):
		failures.append("%s result was not ok: %s" % [label, str(result.get("message", ""))])
	if (result.get("blackjack_hand_results", []) as Array).is_empty():
		failures.append("%s result omitted hand results." % label)
	if (result.get("blackjack_dealer", []) as Array).size() < 2:
		failures.append("%s result omitted dealer showdown cards." % label)
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var table: Dictionary = game_states.get("blackjack", {}) if typeof(game_states.get("blackjack", {})) == TYPE_DICTIONARY else {}
	if table.is_empty():
		failures.append("%s did not persist blackjack table state." % label)
	elif int(table.get("shoe_remaining", 0)) <= 0:
		failures.append("%s persisted an empty shoe without reshuffle." % label)


func _count_key(group: String, key: String) -> void:
	var groups: Dictionary = stats.get(group, {}) if typeof(stats.get(group, {})) == TYPE_DICTIONARY else {}
	groups[key] = int(groups.get(key, 0)) + 1
	stats[group] = groups


func _count_value_for_card(card: Dictionary) -> int:
	var rank := int(card.get("rank", 2))
	if rank >= 2 and rank <= 6:
		return 1
	if rank == 10 or rank == 11 or rank == 12 or rank == 13 or rank == 14:
		return -1
	return 0


func _dealer_up_value(card: Dictionary) -> int:
	var rank := int(card.get("rank", 10))
	if rank == 14:
		return 11
	return mini(rank, 10)


func _write_report(output_path: String, seed_count: int) -> void:
	var global_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
	var report := {
		"tool": "blackjack_seed_audit",
		"seed_count": seed_count,
		"passed": failures.is_empty(),
		"failure_count": failures.size(),
		"warning_count": warnings.size(),
		"stats": stats,
		"failures": failures,
		"warnings": warnings,
	}
	var file := FileAccess.open(global_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()


func _print_summary() -> void:
	print("Blackjack seed audit complete.")
	print("Generated tables: %d" % int(stats.get("generated_tables", 0)))
	print("Clean hand resolves: %d" % int(stats.get("clean_resolves", 0)))
	print("Compact blackjack UI states checked: %d" % int(stats.get("compact_ui_states", 0)))
	print("Blackjack action command samples: %d, max %.3f ms" % [
		int(stats.get("action_command_samples", 0)),
		float(stats.get("max_action_command_ms", 0.0)),
	])
	print("Count hands: %d, count icons: %d, zero icons: %d" % [
		int(stats.get("count_hands", 0)),
		int(stats.get("count_icons", 0)),
		int(stats.get("zero_count_icons", 0)),
	])
	print("Safe peeks: %d, watched peek ejections: %d, strategy confrontations: %d" % [
		int(stats.get("safe_peeks", 0)),
		int(stats.get("watched_peek_ejections", 0)),
		int(stats.get("strategy_confrontations", 0)),
	])
	if failures.is_empty():
		print("Blackjack seed audit passed.")
	else:
		for failure in failures:
			push_error(failure)
