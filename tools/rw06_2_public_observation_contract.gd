extends SceneTree

const PublicObservation := preload("res://tools/agent_playtest_public_observation.gd")
const REPORT_PATH := "res://.tmp/rw06_2/public_observation_contract.json"

var failures: Array[String] = []


func _init() -> void:
	_check_hidden_state_redaction()
	_check_bridge_source_contract()
	if failures.is_empty():
		_write_report(true)
		print("RW06_2_PUBLIC_OBSERVATION_CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	_write_report(false)
	quit(1)


func _check_hidden_state_redaction() -> void:
	var hidden_a := _host_fixture("SECRET_HOLE_A", "SECRET_SHOE_A", "SECRET_BRANCH_A")
	var hidden_b := _host_fixture("SECRET_HOLE_B", "SECRET_SHOE_B", "SECRET_BRANCH_B")
	var public_a := PublicObservation.sanitize(hidden_a)
	var public_b := PublicObservation.sanitize(hidden_b)
	_check(str(public_a.get("schema", "")) == PublicObservation.SCHEMA, "Public observation schema id is missing or wrong.")
	_check(int(public_a.get("schema_version", 0)) == PublicObservation.SCHEMA_VERSION, "Public observation schema version is missing or wrong.")
	var game := _dict(public_a.get("game", {}))
	var public_environment := _dict(public_a.get("environment", {}))
	_check(_dict(game.get("dealer_up_card", {})) == {"rank": 10, "suit": "hearts"}, "The visible dealer up-card was not preserved.")
	_check(_array(game.get("dealer_cards", [])).is_empty(), "A concealed dealer hand exposed more than its up-card.")
	_check(_array(game.get("player_hands", [])).size() == 1, "The player's visible blackjack hand was removed.")
	_check(str(public_environment.get("world_node_id", "")) == "grand_casino", "The public environment identity was not preserved.")
	for raw_environment_key in [
		"turns", "game_ids", "event_ids", "resolved_event_ids", "service_ids", "travel_hooks",
		"demo_objective", "event_options", "travel_choices", "item_offers", "service_options",
		"lender_options", "interactable_objects", "world_map",
	]:
		_check(not public_environment.has(raw_environment_key), "Public environment leaked raw model key %s." % raw_environment_key)
	var public_screen_map := _dict(_dict(public_a.get("screen", {})).get("world_map", {}))
	_check(_array(public_screen_map.get("nodes", [])).size() == 1, "The rendered screen world map was removed with the raw environment map.")
	var closed_map_host := hidden_a.duplicate(true)
	var closed_map_screen := _dict(closed_map_host.get("screen", {}))
	closed_map_screen["world_map_overlay_visible"] = false
	closed_map_screen["overlay_state"] = {"world_map_visible": true}
	closed_map_screen["world_map_title_text"] = "SECRET_CLOSED_MAP_TITLE"
	closed_map_screen["selected_world_map_node_id"] = "SECRET_CLOSED_MAP_SELECTED"
	closed_map_screen["world_map_detail_text"] = "SECRET_CLOSED_MAP_DETAIL"
	closed_map_screen["world_map_detail_popup_visible"] = true
	closed_map_screen["world_map_confirm_enabled"] = true
	closed_map_screen["world_map"] = {
		"current_node_id": "SECRET_CLOSED_MAP_CURRENT",
		"nodes": [{
			"id": "SECRET_CLOSED_MAP_TARGET",
			"label": "SECRET_CLOSED_MAP_MARKER",
			"delivery_target": true,
			"travel_enabled": true,
		}],
		"edges": [{
			"id": "SECRET_CLOSED_MAP_EDGE",
			"a": "SECRET_CLOSED_MAP_CURRENT",
			"b": "SECRET_CLOSED_MAP_TARGET",
		}],
	}
	closed_map_host["screen"] = closed_map_screen
	var closed_map_public := PublicObservation.sanitize(closed_map_host)
	var closed_public_map := _dict(_dict(closed_map_public.get("screen", {})).get("world_map", {}))
	_check(closed_public_map.is_empty(), "A populated closed-overlay world map escaped into public observation.")
	_check(not JSON.stringify(closed_map_public).contains("SECRET_CLOSED_MAP"), "Closed-overlay map markers escaped into public observation.")
	var unrendered_map_host := closed_map_host.duplicate(true)
	var unrendered_map_screen := _dict(unrendered_map_host.get("screen", {}))
	unrendered_map_screen["world_map_overlay_visible"] = true
	unrendered_map_screen["overlay_state"] = {"world_map_visible": false}
	unrendered_map_host["screen"] = unrendered_map_screen
	var unrendered_public_map := _dict(_dict(PublicObservation.sanitize(unrendered_map_host).get("screen", {})).get("world_map", {}))
	_check(unrendered_public_map.is_empty(), "An unrendered world-map snapshot escaped through a stale visible flag.")

	var closed_menu_a := hidden_a.duplicate(true)
	var closed_menu_screen_a := _dict(closed_menu_a.get("screen", {}))
	var closed_menu_overlay_a := _dict(closed_menu_screen_a.get("overlay_state", {}))
	closed_menu_screen_a["run_menu_visible"] = false
	closed_menu_overlay_a["run_menu_visible"] = false
	closed_menu_screen_a["overlay_state"] = closed_menu_overlay_a
	closed_menu_screen_a["run_menu"] = {
		"visible": false,
		"has_save": true,
		"status_text": "SECRET_CLOSED_MENU_ASYNC_A",
	}
	closed_menu_a["screen"] = closed_menu_screen_a
	var closed_menu_b := closed_menu_a.duplicate(true)
	var closed_menu_screen_b := _dict(closed_menu_b.get("screen", {}))
	closed_menu_screen_b["run_menu"] = {
		"visible": false,
		"has_save": false,
		"status_text": "SECRET_CLOSED_MENU_ASYNC_B",
	}
	closed_menu_b["screen"] = closed_menu_screen_b
	var closed_menu_public_a := PublicObservation.sanitize(closed_menu_a)
	var closed_menu_public_b := PublicObservation.sanitize(closed_menu_b)
	_check(_dict(_dict(closed_menu_public_a.get("screen", {})).get("run_menu", {})).is_empty(), "Closed run-menu state escaped into public observation.")
	_check(PublicObservation.fingerprint(closed_menu_public_a) == PublicObservation.fingerprint(closed_menu_public_b), "Closed run-menu async state altered the public trace.")
	_check(not JSON.stringify(closed_menu_public_a).contains("SECRET_CLOSED_MENU"), "Closed run-menu text escaped into public observation.")

	var talk_timing_a := hidden_a.duplicate(true)
	talk_timing_a["talk"] = {
		"visible": true,
		"event_id": "linda_counter",
		"speaker": "Linda",
		"summary": "Pick a rendered choice.",
		"choice_count": 2,
		"choice_ids": ["open_chips", "leave_counter"],
		"typewriter_active": true,
	}
	var talk_timing_b := talk_timing_a.duplicate(true)
	var settled_talk := _dict(talk_timing_b.get("talk", {}))
	settled_talk["typewriter_active"] = false
	talk_timing_b["talk"] = settled_talk
	var talk_timing_public_a := PublicObservation.sanitize(talk_timing_a)
	var talk_timing_public_b := PublicObservation.sanitize(talk_timing_b)
	var public_talk := _dict(talk_timing_public_a.get("talk", {}))
	_check(PublicObservation.fingerprint(talk_timing_public_a) == PublicObservation.fingerprint(talk_timing_public_b), "Talk typewriter frame timing altered the canonical public trace.")
	_check(str(public_talk.get("event_id", "")) == "linda_counter" and _array(public_talk.get("choice_ids", [])).size() == 2, "Deterministic talk normalization removed rendered conversation choices.")
	_check(not public_talk.has("typewriter_active"), "Frame-time-dependent typewriter state escaped into the public trace.")

	var generated_seed_a := hidden_a.duplicate(true)
	var generated_seed_screen_a := _dict(generated_seed_a.get("screen", {}))
	generated_seed_screen_a["screen"] = "START"
	generated_seed_screen_a["has_run"] = false
	generated_seed_screen_a["world_map_overlay_visible"] = false
	generated_seed_screen_a["overlay_state"] = {"world_map_visible": false, "run_menu_visible": false}
	generated_seed_screen_a["start_menu"] = {
		"visible": true,
		"primary_action_visible": true,
		"primary_action_text": "PLAY",
		"seed_field_visible": true,
		"seed_text_committed": false,
		"seed_text": "RUN-SECRET-WALL-CLOCK-A",
	}
	generated_seed_a["screen"] = generated_seed_screen_a
	var generated_seed_b := generated_seed_a.duplicate(true)
	var generated_seed_screen_b := _dict(generated_seed_b.get("screen", {}))
	var generated_seed_menu_b := _dict(generated_seed_screen_b.get("start_menu", {}))
	generated_seed_menu_b["seed_text"] = "RUN-SECRET-WALL-CLOCK-B"
	generated_seed_screen_b["start_menu"] = generated_seed_menu_b
	generated_seed_b["screen"] = generated_seed_screen_b
	var generated_seed_public_a := PublicObservation.sanitize(generated_seed_a)
	var generated_seed_public_b := PublicObservation.sanitize(generated_seed_b)
	_check(PublicObservation.fingerprint(generated_seed_public_a) == PublicObservation.fingerprint(generated_seed_public_b), "Uncommitted generated menu seeds made replay traces nondeterministic.")
	_check(not JSON.stringify(generated_seed_public_a).contains("RUN-SECRET-WALL-CLOCK"), "An uncommitted generated menu seed escaped into public observation.")
	var committed_seed_a := generated_seed_a.duplicate(true)
	var committed_seed_screen_a := _dict(committed_seed_a.get("screen", {}))
	var committed_seed_menu_a := _dict(committed_seed_screen_a.get("start_menu", {}))
	committed_seed_menu_a["seed_text_committed"] = true
	committed_seed_menu_a["seed_text"] = "RW06-FIXED-SEED"
	committed_seed_screen_a["start_menu"] = committed_seed_menu_a
	committed_seed_a["screen"] = committed_seed_screen_a
	var committed_seed_b := committed_seed_a.duplicate(true)
	var committed_seed_screen_b := _dict(committed_seed_b.get("screen", {}))
	var committed_seed_menu_b := _dict(committed_seed_screen_b.get("start_menu", {}))
	committed_seed_menu_b["seed_text"] = "RW06-OTHER-FIXED-SEED"
	committed_seed_screen_b["start_menu"] = committed_seed_menu_b
	committed_seed_b["screen"] = committed_seed_screen_b
	_check(str(_dict(_dict(PublicObservation.sanitize(committed_seed_a).get("screen", {})).get("start_menu", {})).get("seed_text", "")) == "RW06-FIXED-SEED", "An explicitly entered visible seed was not preserved.")
	_check(PublicObservation.fingerprint(PublicObservation.sanitize(committed_seed_a)) != PublicObservation.fingerprint(PublicObservation.sanitize(committed_seed_b)), "Distinct explicitly entered visible seeds were incorrectly normalized away.")

	var offscreen_terminal := hidden_a.duplicate(true)
	var offscreen_terminal_screen := _dict(offscreen_terminal.get("screen", {}))
	offscreen_terminal_screen["screen"] = "VICTORY"
	offscreen_terminal_screen["run_report_visible"] = false
	offscreen_terminal_screen["run_report"] = {
		"seed": "SECRET_OFFSCREEN_TERMINAL_SEED",
		"outcome": {"key": "SECRET_OFFSCREEN_TERMINAL_OUTCOME", "won": true},
	}
	offscreen_terminal["screen"] = offscreen_terminal_screen
	var offscreen_terminal_public := PublicObservation.sanitize(offscreen_terminal)
	var offscreen_terminal_public_screen := _dict(offscreen_terminal_public.get("screen", {}))
	_check(_dict(offscreen_terminal_public_screen.get("run_report", {})).is_empty(), "An offscreen terminal report escaped into public observation.")
	_check(not bool(offscreen_terminal_public_screen.get("run_report_visible", true)), "An offscreen terminal report claimed a rendered witness.")
	_check(not JSON.stringify(offscreen_terminal_public).contains("SECRET_OFFSCREEN_TERMINAL"), "Offscreen terminal data escaped into public observation.")
	var rendered_terminal := offscreen_terminal.duplicate(true)
	var rendered_terminal_screen := _dict(rendered_terminal.get("screen", {}))
	rendered_terminal_screen["run_report_visible"] = true
	rendered_terminal["screen"] = rendered_terminal_screen
	var rendered_terminal_public_screen := _dict(PublicObservation.sanitize(rendered_terminal).get("screen", {}))
	_check(bool(rendered_terminal_public_screen.get("run_report_visible", false)), "A rendered terminal report lost its visibility witness.")
	_check(str(_dict(_dict(rendered_terminal_public_screen.get("run_report", {})).get("outcome", {})).get("key", "")) == "SECRET_OFFSCREEN_TERMINAL_OUTCOME", "A rendered terminal report lost its visible outcome.")
	_check(PublicObservation.fingerprint(public_a) == PublicObservation.fingerprint(public_b), "Private blackjack/run-state changes altered the public observation.")
	_check(str(public_a.get("checkpoint_fingerprint", "")) == str(public_b.get("checkpoint_fingerprint", "")), "Private state altered the canonical public checkpoint.")
	var private_transition := PublicObservation.transition_summary(public_a, public_b, "look", true)
	_check(str(private_transition.get("before_fingerprint", "")) == str(private_transition.get("after_fingerprint", "")), "Private twin observations altered the authenticated public trace.")
	_check(not bool(private_transition.get("public_state_changed", true)), "Private twin observations reported a public transition.")

	var serialized := JSON.stringify(public_a)
	for secret in [
		"SECRET_HOLE_A", "SECRET_SHOE_A", "SECRET_BRANCH_A", "SECRET_ROLL_A",
		"SECRET_CANVAS_A", "SECRET_CONTRADICTION_A", "SECRET_TURN_A",
	]:
		_check(not serialized.contains(secret), "Public observation leaked sentinel %s." % secret)
	var keys: Dictionary = {}
	_collect_keys(public_a, keys)
	for forbidden_key in [
		"shoe_composition", "edge_schedule", "private_roll", "session", "narrative_flags",
		"local_narrative_flags", "fork_state", "turn_member_id", "hidden_contradiction",
		"trigger_context", "scenario_layout_audit", "turns", "game_ids", "event_ids",
		"resolved_event_ids", "service_ids", "travel_hooks", "event_options", "travel_choices",
		"item_offers", "service_options", "lender_options", "interactable_objects",
	]:
		_check(not keys.has(forbidden_key), "Public observation leaked forbidden key %s." % forbidden_key)

	var revealed := hidden_a.duplicate(true)
	var revealed_game := _dict(revealed.get("game", {}))
	revealed_game["dealer_hole_visible"] = true
	revealed["game"] = revealed_game
	var revealed_public := PublicObservation.sanitize(revealed)
	var revealed_cards := _array(_dict(revealed_public.get("game", {})).get("dealer_cards", []))
	_check(revealed_cards.size() == 2, "A revealed dealer hand did not publish both now-visible cards.")
	if revealed_cards.size() == 2:
		_check(_dict(revealed_cards[1]).get("rank") == 1, "The revealed dealer hole card was not preserved.")
	_check(PublicObservation.fingerprint(public_a) != PublicObservation.fingerprint(revealed_public), "Revealing the dealer hand did not alter the public observation.")
	var reveal_transition := PublicObservation.transition_summary(public_a, revealed_public, "blackjack_stand", true)
	_check(bool(reveal_transition.get("public_state_changed", false)), "The complete public trace ignored a now-visible dealer reveal.")
	_check(bool(reveal_transition.get("input_emitted", false)), "The public transition lost its accepted-input marker.")

	var economy_shift := hidden_a.duplicate(true)
	var economy_hud := _dict(economy_shift.get("status_hud", {}))
	economy_hud["bankroll"] = 925
	economy_shift["status_hud"] = economy_hud
	var economy_public := PublicObservation.sanitize(economy_shift)
	_check(str(public_a.get("checkpoint_fingerprint", "")) != str(economy_public.get("checkpoint_fingerprint", "")), "A visible bankroll change did not alter the canonical checkpoint.")


func _check_bridge_source_contract() -> void:
	var source := FileAccess.get_file_as_string("res://tools/agent_playtest_session.gd")
	_check(not source.is_empty(), "Could not read the production-input bridge source.")
	_check(source.contains("func _public_observation() -> Dictionary:"), "Bridge is missing its rendered-witness observation boundary.")
	_check(source.contains("return PublicObservation.sanitize(snapshot)"), "Bridge observations do not pass through the strict sanitizer.")
	_check(not source.contains("var observable := Fidelity.observable_host_snapshot(app)"), "Bridge still publishes a raw host observation.")
	_check(not source.contains("var copy := action.duplicate(true)"), "Bridge clickable metadata still duplicates raw action dictionaries.")
	_check(source.contains('const REPLAY_PAUSE_OWNER := "agent_replay"'), "Bridge is missing deterministic action-boundary pause ownership.")
	_check(source.contains('screen["run_report_visible"]'), "Bridge does not witness the rendered RunReport control.")
	_check(source.contains('start_menu["seed_text_committed"]'), "Bridge does not distinguish an entered seed from a generated menu seed.")
	for command in ["focus_field", "set_field", "click_map", "click_choice", "click_inventory"]:
		_check(source.contains('"%s"' % command), "Bridge is missing semantic command %s." % command)
	_check(source.contains('"trace": transition'), "Bridge results are missing a public before/after trace.")


func _host_fixture(hole_secret: String, shoe_secret: String, branch_secret: String) -> Dictionary:
	return {
		"screen": {
			"screen": "game",
			"has_run": true,
			"private_slot": branch_secret,
			"world_map_overlay_visible": true,
			"overlay_state": {"world_map_visible": true},
			"world_map": {
				"current_node_id": "grand_casino",
				"nodes": [{
					"id": "grand_casino",
					"archetype_id": "grand_casino",
					"label": "Grand Casino",
					"current": true,
					"travel_enabled": false,
				}],
				"edges": [],
			},
			"run_report": {},
		},
		"environment": {
			"id": "grand_casino",
			"archetype_id": "grand_casino",
			"world_node_id": "grand_casino",
			"display_name": "The Grand Casino",
			"narrative_flags": {"branch": branch_secret},
			"local_narrative_flags": {"branch": branch_secret},
			"fork_state": {"branch": branch_secret},
			"turn_member_id": "SECRET_TURN_A",
			"hidden_contradiction": "SECRET_CONTRADICTION_A",
			"game_clock_minutes": 111 if branch_secret.ends_with("_A") else 222,
			"game_day": 3 if branch_secret.ends_with("_A") else 4,
			"turns": 101 if branch_secret.ends_with("_A") else 202,
			"objective_hint": branch_secret,
			"travel_lock_remaining": 11 if branch_secret.ends_with("_A") else 22,
			"travel_locked_actions": 1 if branch_secret.ends_with("_A") else 2,
			"selected_event_id": branch_secret,
			"selected_event_choice_id": branch_secret,
			"selected_item_offer_id": branch_secret,
			"selected_lender_hook_id": branch_secret,
			"selected_service_hook_id": branch_secret,
			"selected_travel_target_id": branch_secret,
			"outcome_message": branch_secret,
			"suspicion_level": 13 if branch_secret.ends_with("_A") else 31,
			"game_ids": [branch_secret],
			"event_ids": [branch_secret],
			"resolved_event_ids": [branch_secret],
			"service_ids": [branch_secret],
			"travel_hooks": [branch_secret],
			"demo_objective": {"id": branch_secret, "complete": branch_secret.ends_with("_B")},
			"event_options": [{"id": branch_secret, "label": branch_secret}],
			"travel_choices": [{"id": branch_secret, "label": branch_secret}],
			"item_offers": [{"id": branch_secret, "label": branch_secret}],
			"service_options": [{"id": branch_secret, "label": branch_secret}],
			"lender_options": [{"id": branch_secret, "label": branch_secret}],
			"interactable_objects": [{"id": "game:blackjack", "label": "Blackjack", "object_type": "game", "enabled": true, "private_roll": "SECRET_ROLL_A"}],
			"world_map": {
				"current_node_id": branch_secret,
				"nodes": [{"id": branch_secret, "label": branch_secret}],
				"edges": [{"id": branch_secret, "a": branch_secret, "b": branch_secret}],
			},
		},
		"spatial": {
			"available": true,
			"selected_object_id": "game:blackjack",
			"private_roll": "SECRET_ROLL_A",
		},
		"game": {
			"game_id": "blackjack",
			"phase": "player_turn",
			"dealer_hole_visible": false,
			"dealer_cards": [
				{"rank": 10, "suit": "hearts", "deck": 3},
				{"rank": 1, "suit": "spades", "deck": 4, "secret": hole_secret},
			],
			"player_hands": [{
				"total": 16,
				"soft": false,
				"cards": [{"rank": 9, "suit": "clubs", "deck": 1}, {"rank": 7, "suit": "diamonds", "deck": 2}],
				"private_draw": hole_secret,
			}],
			"can_hit": true,
			"can_stand": true,
			"legal_actions": [{"id": "blackjack_hit", "label": "Hit", "enabled": true, "private_roll": "SECRET_ROLL_A"}],
			"shoe_composition": shoe_secret,
			"edge_schedule": [shoe_secret],
			"private_roll": "SECRET_ROLL_A",
			"session": {"dealer_hole": hole_secret},
		},
		"consequence": {"bankroll": 900, "run_status": "active", "private_roll": "SECRET_ROLL_A"},
		"status_hud": {
			"bankroll": 900,
			"chips": 150,
			"heat_level": 1,
			"clock_minute_of_day": 1260,
			"objective_state": "in_progress",
			"objective_text": "Finish the hand.",
			"run_status": "active",
			"narrative_flags": {"branch": branch_secret},
		},
		"feedback": {"visible": false, "result": {"private_roll": "SECRET_ROLL_A"}},
		"event_popup": {"visible": false, "trigger_context": {"branch": branch_secret}},
		"talk": {"visible": false, "future_nodes": [branch_secret]},
		"inventory": {"visible": false, "private_inventory_roll": "SECRET_ROLL_A"},
		"message": {"visible": true, "text": "Choose Hit or Stand."},
		"room_canvas": {"scenario_layout_audit": {"secret": branch_secret}},
		"game_canvas": {
			"game_id": "blackjack",
			"state": {"dealer_hole": hole_secret, "shoe": shoe_secret, "private": "SECRET_CANVAS_A"},
			"surface_hit_actions": [{"action": "blackjack_hit", "index": 0, "enabled": true, "private_roll": "SECRET_ROLL_A"}],
		},
	}


func _collect_keys(value: Variant, result: Dictionary) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for key_value in (value as Dictionary).keys():
			var key := str(key_value)
			result[key] = true
			_collect_keys((value as Dictionary).get(key_value), result)
	elif typeof(value) == TYPE_ARRAY:
		for item in value as Array:
			_collect_keys(item, result)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _write_report(passed: bool) -> void:
	var absolute_directory := ProjectSettings.globalize_path("res://.tmp/rw06_2")
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		push_error("Could not create public observation contract report directory: %s" % error_string(directory_error))
		return
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write public observation contract report: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({
		"contract": "rw06_2_public_observation",
		"passed": passed,
		"schema": PublicObservation.SCHEMA,
		"schema_version": PublicObservation.SCHEMA_VERSION,
		"failures": failures,
	}, "  "))
	file.store_string("\n")


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
