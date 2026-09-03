extends SceneTree

# Qualification-only probe for the exact opening segment of the locked
# blackjack_seed_audit payout sequence. This never substitutes for, changes,
# or reports a verdict on the required 1,000-hand acceptance sample.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")
const DriverScript := preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")
const MILESTONES := [1, 5, 10, 25]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hand_count := 25
	var output_path := "res://.tmp/game06_accel/blackjack_payout_prefix.json"
	var source_label := "unspecified"
	for argument in OS.get_cmdline_user_args():
		var text := str(argument)
		if text.begins_with("--hand-count="):
			hand_count = int(text.trim_prefix("--hand-count="))
		elif text.begins_with("--output="):
			output_path = text.trim_prefix("--output=")
		elif text.begins_with("--source-label="):
			source_label = text.trim_prefix("--source-label=").strip_edges()
	if hand_count < 1 or hand_count > 25:
		failures.append("Qualification hand count must be between 1 and 25.")
		_write_report(output_path, source_label, hand_count, [], [], [], 0)
		await process_frame
		quit(1)
		return

	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	for error in library.validation_errors:
		failures.append("ContentLibrary validation error: %s" % error)
	var game := _load_blackjack(library)
	if game == null:
		_write_report(output_path, source_label, hand_count, [], [], [], 0)
		await process_frame
		quit(1)
		return

	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BLACKJACK-AUDIT-PAYOUT-DRIFT")
	run_state.bankroll = 100000
	var environment := _audit_environment(30000)
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("payout_drift_table"))
	table["side_bets"] = []
	table["patrons"] = []
	table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	environment["game_states"] = {"blackjack": table}
	run_state.current_environment = environment

	var outcome_chain: Array = []
	var checkpoint_chain: Array = []
	var milestones: Array = []
	var started_msec := Time.get_ticks_msec()
	for i in range(hand_count):
		_clear_prior_heat(run_state, environment)
		var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, run_state, environment)
		if not bool(deal.get("handled", false)):
			failures.append("Could not deal qualification hand %d." % i)
			break
		var place_result := DriverScript.resolve(game, "blackjack_place_bet", 5, run_state, environment, run_state.create_rng("payout_drift_place_%04d" % i), deal.get("ui_state", {}))
		if not bool(place_result.get("ok", false)):
			failures.append("Could not commit qualification hand %d." % i)
			break
		environment = run_state.current_environment
		var result := _play_authoritative_to_resolve(game, run_state, 5, "payout_drift_%04d" % i)
		if result.is_empty():
			failures.append("Could not resolve qualification hand %d." % i)
			break
		environment = run_state.current_environment
		var outcome_projection := {
			"hand_index": i,
			"blackjack_hand_results": (result.get("blackjack_hand_results", []) as Array).duplicate(true),
			"blackjack_main_delta": int(result.get("blackjack_main_delta", 0)),
			"bankroll_delta": int(result.get("bankroll_delta", 0)),
			"bankroll": run_state.bankroll,
		}
		outcome_chain.append(RuntimeScript.canonical_fingerprint(outcome_projection))
		var terminal := DriverScript.advance_terminal_presentation(game, 5, run_state, environment)
		if not bool(terminal.get("ok", false)):
			failures.append("Could not clear terminal presentation after qualification hand %d." % i)
			break
		environment = run_state.current_environment
		checkpoint_chain.append(run_state.blackjack_authority_checkpoint_fingerprint())
		var resolved := i + 1
		if resolved in MILESTONES or resolved == hand_count:
			milestones.append(_state_measurement(run_state, resolved, Time.get_ticks_msec() - started_msec))
			print("BLACKJACK_PREFIX_PROGRESS hands=%d/%d elapsed_msec=%d snapshot_bytes=%d ledger_bytes=%d" % [
				resolved,
				hand_count,
				Time.get_ticks_msec() - started_msec,
				int((milestones[-1] as Dictionary).get("snapshot_bytes", 0)),
				int((milestones[-1] as Dictionary).get("ledger_bytes", 0)),
			])

	_write_report(output_path, source_label, hand_count, outcome_chain, checkpoint_chain, milestones, Time.get_ticks_msec() - started_msec)
	await process_frame
	quit(0 if failures.is_empty() and outcome_chain.size() == hand_count else 1)


func _load_blackjack(library: ContentLibrary) -> GameModule:
	var definition: Dictionary = library.game("blackjack")
	if definition.is_empty():
		failures.append("Blackjack definition was not found.")
		return null
	var module_script: Script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("Blackjack module could not be loaded.")
		return null
	var instance = module_script.new()
	if not instance is GameModule:
		failures.append("Blackjack module does not extend GameModule.")
		return null
	var game: GameModule = instance
	game.setup(definition, library)
	return game


func _audit_environment(index: int) -> Dictionary:
	var strictness_values := ["low", "private", "high", "boss", "uneven"]
	return {
		"id": "blackjack_audit_room_%03d" % index,
		"display_name": "Blackjack Audit Room %03d" % index,
		"depth": index % 4,
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 200},
		"security_profile": {"strictness": strictness_values[index % strictness_values.size()]},
	}


func _clear_prior_heat(run_state: RunState, environment: Dictionary) -> void:
	if run_state.suspicion_level() > 0:
		run_state.add_suspicion("payout_drift_heat_reset", -run_state.suspicion_level(), "audit", false, {"environment_id": str(environment.get("id", ""))})
	var game_states: Dictionary = environment.get("game_states", {})
	var table: Dictionary = game_states.get("blackjack", {})
	if bool(table.get("heat_backoff", false)):
		for key in ["barred", "heat_backoff", "barred_reason", "barred_scope", "barred_at_heat", "barred_action_id"]:
			table.erase(key)
		game_states["blackjack"] = table
		environment["game_states"] = game_states


func _play_authoritative_to_resolve(game: GameModule, run_state: RunState, stake: int, rng_key: String) -> Dictionary:
	var rng := run_state.create_rng(rng_key)
	for _iteration in range(16):
		var environment: Dictionary = run_state.current_environment
		var surface := game.surface_state(run_state, environment, {})
		var action := "blackjack_deal"
		var confirm_requested := false
		if bool(surface.get("settle_available", false)) or bool(surface.get("round_complete", false)):
			confirm_requested = true
		else:
			action = _choose_clean_action(surface, rng)
		var command := DriverScript.surface_intent(game, action, stake, run_state, environment, 0, confirm_requested)
		if not bool(command.get("handled", false)) and action != "blackjack_stand":
			command = DriverScript.surface_intent(game, "blackjack_stand", stake, run_state, run_state.current_environment)
		if str(command.get("action_id", "")).is_empty():
			continue
		var result: Dictionary = DriverScript.resolve_surface_command(game, command, stake, run_state, run_state.current_environment)
		if bool(result.get("ok", false)):
			return result
	return {}


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


func _dealer_up_value(card: Dictionary) -> int:
	var rank := int(card.get("rank", 10))
	return 11 if rank == 14 else mini(rank, 10)


func _state_measurement(run_state: RunState, hand_count: int, elapsed_msec: int) -> Dictionary:
	var snapshot := run_state.to_save_snapshot()
	var environment: Dictionary = snapshot.get("current_environment", {})
	var game_states: Dictionary = environment.get("game_states", {})
	var table: Dictionary = game_states.get("blackjack", {})
	var ledger: Dictionary = table.get("_blackjack_action_authority", {})
	var cache: Dictionary = ledger.get("request_cache", {})
	var response_bytes_total := 0
	var response_bytes_max := 0
	var response_shape := {"max_depth": 0, "max_dictionary_size": 0, "max_array_size": 0, "node_count": 0, "suspicious_key_paths": []}
	for entry_value in cache.values():
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var response: Dictionary = (entry_value as Dictionary).get("response", {})
		var response_bytes := RuntimeScript.canonical_json(response).to_utf8_buffer().size()
		response_bytes_total += response_bytes
		response_bytes_max = maxi(response_bytes_max, response_bytes)
		_merge_shape(response_shape, _shape_measurement(response))
	return {
		"hand_count": hand_count,
		"elapsed_msec": elapsed_msec,
		"snapshot_bytes": RuntimeScript.canonical_json(snapshot).to_utf8_buffer().size(),
		"snapshot_fingerprint": RuntimeScript.canonical_fingerprint(snapshot),
		"snapshot_shape": _shape_measurement(snapshot),
		"authority_checkpoint_fingerprint": run_state.blackjack_authority_checkpoint_fingerprint(),
		"ledger_bytes": RuntimeScript.canonical_json(ledger).to_utf8_buffer().size(),
		"request_order_size": (ledger.get("request_order", []) as Array).size(),
		"request_cache_size": cache.size(),
		"journal_size": (ledger.get("journal", []) as Array).size(),
		"cached_response_bytes_total": response_bytes_total,
		"cached_response_bytes_max": response_bytes_max,
		"cached_response_shape": response_shape,
	}


func _shape_measurement(root: Variant) -> Dictionary:
	var queue: Array = [{"value": root, "depth": 0, "path": "$"}]
	var cursor := 0
	var result := {"max_depth": 0, "max_dictionary_size": 0, "max_array_size": 0, "node_count": 0, "suspicious_key_paths": []}
	while cursor < queue.size():
		var item: Dictionary = queue[cursor]
		cursor += 1
		var value: Variant = item.get("value")
		var depth := int(item.get("depth", 0))
		var path := str(item.get("path", "$"))
		result["node_count"] = int(result.get("node_count", 0)) + 1
		result["max_depth"] = maxi(int(result.get("max_depth", 0)), depth)
		if typeof(value) == TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			result["max_dictionary_size"] = maxi(int(result.get("max_dictionary_size", 0)), dictionary.size())
			for key_value in dictionary.keys():
				var key := str(key_value)
				var child_path := "%s.%s" % [path, key]
				if key in ["_blackjack_action_authority", "_sealed_action_host_ledger", "request_cache", "request_order"]:
					var paths: Array = result.get("suspicious_key_paths", [])
					if paths.size() < 64:
						paths.append(child_path)
				queue.append({"value": dictionary.get(key_value), "depth": depth + 1, "path": child_path})
		elif typeof(value) == TYPE_ARRAY:
			var array: Array = value
			result["max_array_size"] = maxi(int(result.get("max_array_size", 0)), array.size())
			for index in range(array.size()):
				queue.append({"value": array[index], "depth": depth + 1, "path": "%s[%d]" % [path, index]})
	return result


func _merge_shape(target: Dictionary, source: Dictionary) -> void:
	for key in ["max_depth", "max_dictionary_size", "max_array_size"]:
		target[key] = maxi(int(target.get(key, 0)), int(source.get(key, 0)))
	target["node_count"] = int(target.get("node_count", 0)) + int(source.get("node_count", 0))
	var paths: Array = target.get("suspicious_key_paths", [])
	for path in source.get("suspicious_key_paths", []) as Array:
		if paths.size() >= 64:
			break
		paths.append(path)


func _write_report(output_path: String, source_label: String, hand_count: int, outcome_chain: Array, checkpoint_chain: Array, milestones: Array, elapsed_msec: int) -> void:
	var global_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
	var report := {
		"tool": "blackjack_payout_prefix_probe",
		"qualification_only": true,
		"source_label": source_label,
		"requested_hands": hand_count,
		"resolved_hands": outcome_chain.size(),
		"elapsed_msec": elapsed_msec,
		"passed": failures.is_empty() and outcome_chain.size() == hand_count,
		"failure_count": failures.size(),
		"failures": failures,
		"outcome_chain": outcome_chain,
		"outcome_chain_fingerprint": RuntimeScript.canonical_fingerprint(outcome_chain),
		"checkpoint_chain": checkpoint_chain,
		"checkpoint_chain_fingerprint": RuntimeScript.canonical_fingerprint(checkpoint_chain),
		"milestones": milestones,
	}
	var file := FileAccess.open(global_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write Blackjack prefix report: %s" % global_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("BLACKJACK_PREFIX_RESULT passed=%s hands=%d elapsed_msec=%d outcome=%s checkpoints=%s output=%s" % [
		str(bool(report.get("passed", false))),
		outcome_chain.size(),
		elapsed_msec,
		str(report.get("outcome_chain_fingerprint", "")),
		str(report.get("checkpoint_chain_fingerprint", "")),
		global_path,
	])
	for failure in failures:
		push_error(failure)
