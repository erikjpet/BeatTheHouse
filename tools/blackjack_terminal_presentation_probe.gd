extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var definition := library.game("blackjack")
	var module_script: Script = load(str(definition.get("module_path", "")))
	var game: GameModule = module_script.new()
	game.setup(definition, library)

	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BLACKJACK-TERMINAL-PRESENTATION")
	run_state.change_bankroll(1000)
	var environment := {
		"id": "blackjack_terminal_presentation_room",
		"display_name": "Terminal Presentation Room",
		"depth": 1,
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 100},
		"security_profile": {"strictness": "low"},
	}
	var table := game.generate_environment_state(run_state, environment, run_state.create_rng("table"))
	var original_shoe: Array = table.get("shoe", [])
	var forced_opening: Array = [
		{"rank": 5, "suit": 0, "deck": 90},
		{"rank": 14, "suit": 1, "deck": 90},
		{"rank": 6, "suit": 2, "deck": 90},
		{"rank": 13, "suit": 3, "deck": 90},
	]
	forced_opening.append_array(original_shoe)
	table["shoe"] = forced_opening
	table["shoe_remaining"] = forced_opening.size()
	table["patrons"] = []
	table["counting_enabled"] = true
	environment["game_states"] = {"blackjack": table}
	run_state.current_environment = environment

	var opening_msec := 10000
	var ui_state := {
		"selected_stake": 5,
		"surface_time_msec": opening_msec,
		"counting_enabled": true,
	}
	var deal_command := game.surface_action_command("blackjack_deal", 0, false, ui_state, run_state, environment)
	var deal_ui: Dictionary = deal_command.get("ui_state", {})
	var place_result := game.resolve_with_context("blackjack_place_bet", 5, run_state, environment, run_state.create_rng("place"), deal_ui)
	deal_ui = place_result.get("ui_state", {})
	_check(not deal_ui.is_empty(), "Opening deal did not preserve its live UI state.")
	_check(_dealer_blackjack(deal_ui), "Forced fixture did not produce dealer blackjack.")
	_check(not (deal_ui.get("count_challenge", {}) as Dictionary).is_empty(), "Counting did not start on the opening deal.")

	var deal_started_msec := int(deal_ui.get("deal_started_msec", 0))
	deal_ui["surface_time_msec"] = deal_started_msec + 1
	_check(not game.surface_needs_auto_tick(deal_ui, run_state, environment), "Dealer blackjack requested settlement before the opening cards finished moving.")
	var premature := game.surface_auto_action_command(deal_ui, run_state, environment, {})
	_check(not bool(premature.get("handled", false)), "Dealer blackjack settled during its opening deal animation.")

	var surface := game.surface_state(run_state, environment, deal_ui)
	var deal_duration := int(surface.get("deal_animation_duration_msec", 0))
	_check(deal_duration > 0, "Opening deal did not expose a finite presentation duration.")
	deal_ui["surface_time_msec"] = deal_started_msec + deal_duration + 1
	_check(game.surface_needs_auto_tick(deal_ui, run_state, environment), "Dealer blackjack did not become eligible after the opening animation.")
	var preview := game.surface_auto_action_command(deal_ui, run_state, environment, {})
	var preview_ui: Dictionary = preview.get("ui_state", {})
	_check(bool(preview.get("handled", false)) and str(preview.get("action_id", "")).is_empty(), "Counting dealer blackjack skipped its post-reveal preview.")
	_check(bool(preview_ui.get("settlement_count_revealed", false)), "Dealer blackjack did not reveal terminal cards to the count challenge.")
	_check(not bool(preview_ui.get("count_answered", false)), "Count challenge finalized before terminal bubbles could appear.")
	_check(str(preview_ui.get("deal_animation_id", "")).contains("count_settlement_preview"), "Terminal dealer cards did not receive their own reveal animation.")

	var challenge: Dictionary = preview_ui.get("count_challenge", {})
	var saw_hole_card := false
	var last_bubble_end := int(preview_ui.get("surface_time_msec", opening_msec))
	var first_terminal_spawn := 0
	for card_value in challenge.get("cards", []):
		if typeof(card_value) == TYPE_DICTIONARY and str((card_value as Dictionary).get("_count_source_key", "")).begins_with("dealer:1:"):
			saw_hole_card = true
	for icon_value in challenge.get("icons", []):
		if typeof(icon_value) != TYPE_DICTIONARY:
			continue
		var icon: Dictionary = icon_value
		var spawn := int(icon.get("spawn_msec", 0))
		last_bubble_end = maxi(last_bubble_end, spawn + int(icon.get("duration_msec", 0)))
		var card: Dictionary = icon.get("card", {})
		if str(card.get("_count_source_key", "")).begins_with("dealer:1:"):
			first_terminal_spawn = spawn
	_check(saw_hole_card, "Dealer hole card was not added to the terminal count challenge.")
	var terminal_reveal_duration := 0
	for event_value in preview_ui.get("deal_animation_events", []):
		if typeof(event_value) == TYPE_DICTIONARY:
			terminal_reveal_duration = maxi(terminal_reveal_duration, int((event_value as Dictionary).get("delay_msec", 0)) + int((event_value as Dictionary).get("duration_msec", 0)) + 120)
	_check(first_terminal_spawn >= int(preview_ui.get("surface_time_msec", 0)) + terminal_reveal_duration, "Terminal count bubble was not scheduled after the hand reveal.")

	preview_ui["surface_time_msec"] = first_terminal_spawn + 1
	_check(not game.surface_needs_auto_tick(preview_ui, run_state, environment), "Dealer blackjack settled while its terminal count bubble was active.")
	var bubble_command := game.surface_auto_action_command(preview_ui, run_state, environment, {})
	_check(not bool(bubble_command.get("handled", false)), "An active terminal count bubble was bypassed by settlement automation.")

	preview_ui["surface_time_msec"] = last_bubble_end + 1
	var miss_update := game.surface_auto_action_command(preview_ui, run_state, environment, {})
	var resolved_ui: Dictionary = miss_update.get("ui_state", preview_ui)
	resolved_ui["surface_time_msec"] = last_bubble_end + 2
	var settle := game.surface_auto_action_command(resolved_ui, run_state, environment, {})
	_check(str(settle.get("action_id", "")) == "play_basic" and bool(settle.get("resolve", false)), "Dealer blackjack did not settle after every count bubble resolved.")

	if failures.is_empty():
		print("BLACKJACK_TERMINAL_PRESENTATION_PROBE_PASS deal_duration=%d terminal_bubble_spawn=%d" % [deal_duration, first_terminal_spawn])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _dealer_blackjack(ui_state: Dictionary) -> bool:
	var cards: Array = ui_state.get("dealer_cards", [])
	if cards.size() != 2:
		return false
	var first := int((cards[0] as Dictionary).get("rank", 0))
	var second := int((cards[1] as Dictionary).get("rank", 0))
	return (first == 14 and second >= 10) or (second == 14 and first >= 10)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
