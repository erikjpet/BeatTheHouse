extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const BlackjackScript := preload("res://scripts/games/blackjack.gd")

const OUTPUT_JSON := "res://.tmp/tutorial_seed_audit/tutorial_first_card.json"
const OUTPUT_MARKDOWN := "res://.tmp/tutorial_seed_audit/tutorial_first_card.md"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	var library := ContentLibraryScript.new()
	library.load()
	for error_value in library.validation_errors:
		failures.append("Content validation: %s" % str(error_value))
	var config := library.challenge_config_for("tutorial_first_card", "IGNORED-BY-FIXED-SEED")
	var run_state := RunStateScript.new()
	run_state.start_new(str(config.get("seed_text", "")), config)
	run_state.begin_act(1)
	var generator := RunGeneratorScript.new(library)
	generator.next_environment(run_state)
	var home := run_state.current_environment.duplicate(true)
	_check(str(home.get("archetype_id", "")) == "motel_room", "Tutorial did not start in motel_room.", failures)
	_check(run_state.bankroll == 80, "Tutorial did not start with exactly $80.", failures)
	_check(run_state.inventory.is_empty(), "Tutorial carried inventory was not empty.", failures)
	var containers: Array = home.get("home_containers", []) if typeof(home.get("home_containers", [])) == TYPE_ARRAY else []
	_check(containers.size() == 1, "Tutorial home did not generate one backpack.", failures)
	if not containers.is_empty():
		_check((containers[0] as Dictionary).get("item_ids", []).is_empty(), "Tutorial backpack was not empty.", failures)

	var node_ids: Array = []
	for node_value in run_state.world_map.get("nodes", []):
		if typeof(node_value) == TYPE_DICTIONARY:
			node_ids.append(str((node_value as Dictionary).get("id", "")))
	for required_id in ["motel_room", "motel", "corner_store", "bar", "grand_casino"]:
		_check(node_ids.has(required_id), "Tutorial map omitted %s." % required_id, failures)

	generator.next_environment(run_state, "motel", true)
	var motel := run_state.current_environment.duplicate(true)
	_check(str(motel.get("archetype_id", "")) == "motel", "Tutorial room exit did not reach the motel.", failures)
	generator.next_environment(run_state, "corner_store", true)
	var store := run_state.current_environment.duplicate(true)
	var offers: Array = store.get("item_offers", []) if typeof(store.get("item_offers", [])) == TYPE_ARRAY else []
	_check(offers.size() == 1, "Tutorial store did not generate exactly one offer.", failures)
	if not offers.is_empty():
		var offer: Dictionary = offers[0]
		_check(str(offer.get("id", "")) == "instant_coffee", "Tutorial store offer was not Instant Coffee.", failures)
		_check(int(offer.get("price", 999)) <= 9, "Tutorial store offer was not cheap.", failures)
	generator.next_environment(run_state, "bar", true)
	var bar := run_state.current_environment.duplicate(true)
	_check((bar.get("game_ids", []) as Array) == ["blackjack"], "Tutorial bar did not contain only blackjack.", failures)
	var event_ids: Array = bar.get("event_ids", []) if typeof(bar.get("event_ids", [])) == TYPE_ARRAY else []
	_check(event_ids.has("tutorial_friendly_choice") and event_ids.has("tutorial_grand_casino_invitation"), "Tutorial bar omitted a required conversation.", failures)

	var blackjack := BlackjackScript.new()
	var enter_result: Dictionary = blackjack.enter(run_state, bar)
	_check(bool(enter_result.get("ok", false)), "Tutorial blackjack table could not be entered.", failures)
	var count_command: Dictionary = blackjack.surface_action_command("blackjack_count_toggle", 0, false, {"selected_stake": 2}, run_state, bar)
	_check(bool(count_command.get("handled", false)), "Tutorial count control was unavailable.", failures)
	var deal_command: Dictionary = blackjack.surface_action_command("blackjack_deal", 0, false, count_command.get("ui_state", {}), run_state, bar)
	_check(bool(deal_command.get("handled", false)), "Tutorial blackjack hand could not be dealt.", failures)
	var opening_cards: Array = deal_command.get("ui_state", {}).get("initial_player_cards", []) if typeof(deal_command.get("ui_state", {}).get("initial_player_cards", [])) == TYPE_ARRAY else []
	_check(opening_cards.size() == 2, "Fixed seed did not produce a normal two-card opening hand.", failures)

	var report := {
		"challenge_id": "tutorial_first_card",
		"fixed_seed": str(config.get("seed_text", "")),
		"map_node_ids": node_ids,
		"home_container_count": containers.size(),
		"store_offers": offers,
		"store_archetype_id": str(store.get("archetype_id", "")),
		"effective_store_pool": library.environment_archetype_for_challenge(library.environment_archetype("corner_store"), config).get("item_pool", []),
		"bar_game_ids": bar.get("game_ids", []),
		"bar_event_ids": event_ids,
		"blackjack_opening_ui": deal_command.get("ui_state", {}),
		"failures": failures,
		"passed": failures.is_empty(),
	}
	_write_report(report)
	if failures.is_empty():
		print("TUTORIAL SEED AUDIT PASS: %s" % str(config.get("seed_text", "")))
		quit(0)
	else:
		for failure in failures:
			push_error(str(failure))
		quit(1)


func _check(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append(message)


func _write_report(report: Dictionary) -> void:
	var absolute_json := ProjectSettings.globalize_path(OUTPUT_JSON)
	DirAccess.make_dir_recursive_absolute(absolute_json.get_base_dir())
	var json_file := FileAccess.open(OUTPUT_JSON, FileAccess.WRITE)
	json_file.store_string(JSON.stringify(report, "\t"))
	json_file.close()
	var lines := [
		"# Tutorial fixed-seed audition",
		"",
		"- Challenge: `%s`" % str(report.get("challenge_id", "")),
		"- Seed: `%s`" % str(report.get("fixed_seed", "")),
		"- Result: **%s**" % ("PASS" if bool(report.get("passed", false)) else "FAIL"),
		"- Map nodes: `%s`" % ", ".join(report.get("map_node_ids", [])),
		"- Store offers: `%s`" % JSON.stringify(report.get("store_offers", [])),
		"- Bar games: `%s`" % ", ".join(report.get("bar_game_ids", [])),
		"- Bar events: `%s`" % ", ".join(report.get("bar_event_ids", [])),
	]
	if not report.get("failures", []).is_empty():
		lines.append("")
		lines.append("## Failures")
		for failure in report.get("failures", []):
			lines.append("- %s" % str(failure))
	var markdown_file := FileAccess.open(OUTPUT_MARKDOWN, FileAccess.WRITE)
	markdown_file.store_string("\n".join(lines) + "\n")
	markdown_file.close()
