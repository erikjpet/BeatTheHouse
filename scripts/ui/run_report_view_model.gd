class_name RunReportViewModel
extends RefCounted

const OUTCOME_REGISTRY_PATH := "res://data/art/run_outcome_icons.json"


static func build(run_data: Dictionary, catalogs: Dictionary = {}) -> Dictionary:
	var story_log := _dict_array(run_data.get("story_log", []))
	var outcome := build_outcome(run_data, _copy_dict(catalogs.get("outcomes", {})))
	var score := _copy_dict(run_data.get("terminal_score", {}))
	if score.is_empty():
		var base := maxi(0, int(run_data.get("run_spending_score", 0)))
		var won := str(run_data.get("run_status", "")) == "ended" and bool(_copy_dict(run_data.get("narrative_flags", {})).get("demo_victory", false))
		var multiplier := RunState.TERMINAL_SCORE_VICTORY_MULTIPLIER if won else 1
		score = {"base_spending": base, "multiplier": multiplier, "score": base * multiplier}
	var timeline := build_timeline(
		_dict_array(run_data.get("heat_history", [])),
		_copy_dict(run_data.get("world_map", {})),
		maxi(0, int(_copy_dict(run_data.get("event_cadence", {})).get("action_index", 0)))
	)
	return {
		"outcome": outcome,
		"score": {
			"money_put_to_work": int(score.get("base_spending", 0)),
			"winner_bonus": maxi(1, int(score.get("multiplier", 1))),
			"show_winner_bonus": bool(outcome.get("won", false)),
			"final_score": int(score.get("score", 0)),
		},
		"items": build_item_fates(_string_array(run_data.get("inventory", [])), _dict_array(run_data.get("debt", [])), story_log, _copy_dict(catalogs.get("items", {}))),
		"debts": build_debt_ledger(_dict_array(run_data.get("debt", [])), story_log),
		"money_rows": build_money_rows(story_log, catalogs),
		"timeline": timeline,
		"map_snapshot": _copy_dict(run_data.get("world_map", {})),
		"seed": _player_facing_seed(run_data),
	}


static func build_outcome(run_data: Dictionary, registry: Dictionary) -> Dictionary:
	var flags := _copy_dict(run_data.get("narrative_flags", {}))
	var won := str(run_data.get("run_status", "")) == "ended" and bool(flags.get("demo_victory", false))
	var outcome_key := str(run_data.get("run_failure_reason", RunState.FAILURE_BANKROLL_ZERO))
	if won:
		outcome_key = "players_card" if str(flags.get("demo_victory_route", "")) == RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID else "showdown_survived"
	var entries := _copy_dict(registry.get("outcomes", registry))
	var definition := _copy_dict(entries.get(outcome_key, {}))
	var title := str(definition.get("title", outcome_key.replace("_", " ").capitalize()))
	var how := str(run_data.get("run_failure_message", ""))
	if won:
		how = str(flags.get("demo_victory_message", definition.get("how", "You beat the house and made it out.")))
	elif how.strip_edges().is_empty():
		how = str(definition.get("how", "The run ended here."))
	var environment := _copy_dict(run_data.get("current_environment", {}))
	var environment_name := str(environment.get("display_name", environment.get("id", "Unknown room")))
	var total_minutes := maxi(0, int(run_data.get("game_clock_minutes", RunState.GAME_CLOCK_START_MINUTE)))
	var day := int(floor(float(total_minutes) / 1440.0)) + 1
	var minute_of_day := total_minutes % 1440
	var hour := int(floor(float(minute_of_day) / 60.0))
	var minute := minute_of_day % 60
	return {
		"key": outcome_key,
		"won": won,
		"title": title,
		"how": how,
		"where": "%s · Day %d, %02d:%02d" % [environment_name, day, hour, minute],
		"environment_name": environment_name,
		"icon_key": str(definition.get("icon_key", outcome_key)),
		"icon_path": str(definition.get("icon_path", "res://assets/art/run_outcomes/%s.png" % str(definition.get("icon_key", outcome_key)))),
	}


static func build_money_rows(story_log: Array, catalogs: Dictionary = {}) -> Array:
	var totals := {}
	var labels := {}
	for value in story_log:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var entry_type := str(entry.get("type", ""))
		if entry_type == "travel_risk_event":
			continue
		var delta := _story_bankroll_delta(entry)
		if delta == 0:
			continue
		var source := _money_source(entry)
		var key := str(source.get("key", "other"))
		totals[key] = int(totals.get(key, 0)) + delta
		labels[key] = _source_label(entry, source, catalogs)
	var rows: Array = []
	for key_value in totals.keys():
		var key := str(key_value)
		rows.append({"key": key, "label": str(labels.get(key, key.replace("_", " ").capitalize())), "net": int(totals[key])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var absolute_a := absi(int(a.get("net", 0)))
		var absolute_b := absi(int(b.get("net", 0)))
		return absolute_a > absolute_b if absolute_a != absolute_b else str(a.get("label", "")) < str(b.get("label", ""))
	)
	return rows


static func build_item_fates(inventory: Array, live_debt: Array, story_log: Array, item_catalog: Dictionary = {}) -> Dictionary:
	var owned_counts := {}
	for item_id in inventory:
		owned_counts[str(item_id)] = int(owned_counts.get(str(item_id), 0)) + 1
	var kept: Array = []
	for item_id_value in owned_counts.keys():
		var item_id := str(item_id_value)
		kept.append(_item_row(item_id, int(owned_counts[item_id]), "kept", 0, item_catalog))
	kept.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("label", "")) < str(b.get("label", "")))
	var pawn_by_debt := {}
	for entry in live_debt:
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("debt_kind", "")) == "pawn":
			var debt_entry: Dictionary = entry
			pawn_by_debt[str(debt_entry.get("id", ""))] = _pawn_row(debt_entry, "still held", item_catalog)
	var sold_counts := {}
	var sold_totals := {}
	for value in story_log:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var entry_type := str(entry.get("type", ""))
		var debt_id := str(entry.get("debt_id", ""))
		if entry_type == "lender_hook":
			for debt_value in _dict_array(entry.get("debt_changes", [])):
				if str(debt_value.get("debt_kind", "")) == "pawn":
					pawn_by_debt[str(debt_value.get("id", ""))] = _pawn_row(debt_value, "still held", item_catalog)
		elif entry_type == "debt_paid" and not str(entry.get("collateral_item_id", "")).is_empty() and pawn_by_debt.has(debt_id):
			var redeemed: Dictionary = pawn_by_debt[debt_id]
			redeemed["fate"] = "redeemed"
			pawn_by_debt[debt_id] = redeemed
		elif entry_type == "debt_default" and pawn_by_debt.has(debt_id):
			var forfeited: Dictionary = pawn_by_debt[debt_id]
			forfeited["fate"] = "forfeited"
			pawn_by_debt[debt_id] = forfeited
		elif entry_type == "item_sale":
			var item_id := str(entry.get("item_id", "unknown_item"))
			sold_counts[item_id] = int(sold_counts.get(item_id, 0)) + 1
			sold_totals[item_id] = int(sold_totals.get(item_id, 0)) + maxi(0, int(entry.get("sale_price", entry.get("bankroll_delta", 0))))
	var pawned: Array = pawn_by_debt.values()
	pawned.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("label", "")) < str(b.get("label", "")))
	var sold: Array = []
	for item_id_value in sold_counts.keys():
		var item_id := str(item_id_value)
		sold.append(_item_row(item_id, int(sold_counts[item_id]), "sold", int(sold_totals.get(item_id, 0)), item_catalog))
	sold.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("label", "")) < str(b.get("label", "")))
	return {"kept": kept, "pawned": pawned, "sold": sold}


static func build_debt_ledger(live_debt: Array, story_log: Array) -> Array:
	var loans := {}
	for value in story_log:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var entry_type := str(entry.get("type", ""))
		if entry_type == "lender_hook":
			for debt_value in _dict_array(entry.get("debt_changes", [])):
				var loan := _loan_row(debt_value, str(entry.get("label", entry.get("id", "Lender"))))
				loans[str(loan.get("id", ""))] = loan
		elif entry_type.begins_with("debt_"):
			var debt_id := str(entry.get("debt_id", ""))
			if debt_id.is_empty():
				continue
			var loan: Dictionary = _copy_dict(loans.get(debt_id, {"id": debt_id, "lender": str(entry.get("lender_id", "Lender")).replace("_", " ").capitalize(), "amount": 0, "kind": "cash", "outcome": "outstanding", "tone": "outstanding"}))
			match entry_type:
				"debt_paid", "debt_favor_completed":
					loan["outcome"] = "redeemed" if not str(entry.get("collateral_item_id", "")).is_empty() else "settled"
					loan["tone"] = "settled"
				"debt_default":
					loan["outcome"] = "collateral kept" if str(loan.get("kind", "")) == "pawn" else "defaulted"
					loan["tone"] = "burned"
				"debt_favor_due", "debt_favor_refused":
					loan["outcome"] = "outstanding"
					loan["tone"] = "outstanding"
			loans[debt_id] = loan
	for value in live_debt:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var debt_entry: Dictionary = value
		var debt_id := str(debt_entry.get("id", ""))
		var existing := _copy_dict(loans.get(debt_id, _loan_row(debt_entry, str(debt_entry.get("lender_id", "Lender")))))
		existing["outcome"] = "still held" if str(debt_entry.get("debt_kind", "")) == "pawn" else "outstanding"
		existing["tone"] = "outstanding"
		loans[debt_id] = existing
	var rows: Array = loans.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("lender", "")) < str(b.get("lender", "")))
	return rows


static func build_timeline(heat_entries: Array, world_map: Dictionary, final_action_index: int = 0) -> Dictionary:
	var samples := RunState.normalize_heat_history(heat_entries)
	if samples.is_empty():
		samples = [{"action_index": 0, "heat_value": 0, "environment_id": "", "environment_name": "", "world_node_id": "", "transition": true}]
	var max_action := maxi(1, final_action_index)
	for sample in samples:
		max_action = maxi(max_action, int((sample as Dictionary).get("action_index", 0)))
	var normalized_samples: Array = []
	var transitions: Array = []
	for sample_value in samples:
		var sample: Dictionary = sample_value
		var row := sample.duplicate(false)
		row["progress"] = clampf(float(int(sample.get("action_index", 0))) / float(max_action), 0.0, 1.0)
		normalized_samples.append(row)
		if bool(sample.get("transition", false)):
			transitions.append(row)
	var nodes_by_id := {}
	for node_value in _dict_array(world_map.get("nodes", [])):
		nodes_by_id[str(node_value.get("id", ""))] = node_value
	var path := _string_array(world_map.get("visited_path", []))
	var keyframes: Array = []
	for index in range(path.size()):
		var node_id := str(path[index])
		var node := _copy_dict(nodes_by_id.get(node_id, {}))
		var action_index := int(round(float(index) * float(max_action) / float(maxi(1, path.size() - 1))))
		if index < transitions.size():
			action_index = int((transitions[index] as Dictionary).get("action_index", action_index))
		var position := _copy_dict(node.get("position", {}))
		keyframes.append({
			"node_id": node_id,
			"label": str(node.get("display_name", node.get("label", node_id.replace("_", " ").capitalize()))),
			"action_index": action_index,
			"progress": clampf(float(action_index) / float(max_action), 0.0, 1.0),
			"position": {"x": float(position.get("x", 0.5)), "y": float(position.get("y", 0.5))},
		})
	var bands: Array = []
	for index in range(transitions.size()):
		var transition: Dictionary = transitions[index]
		var start_action := int(transition.get("action_index", 0))
		var end_action := max_action if index + 1 >= transitions.size() else int((transitions[index + 1] as Dictionary).get("action_index", max_action))
		bands.append({
			"environment_id": str(transition.get("environment_id", "")),
			"label": str(transition.get("environment_name", transition.get("environment_id", "Venue"))),
			"start_progress": clampf(float(start_action) / float(max_action), 0.0, 1.0),
			"end_progress": clampf(float(maxi(start_action, end_action)) / float(max_action), 0.0, 1.0),
			"color_index": index % 6,
		})
	return {"max_action_index": max_action, "heat_samples": normalized_samples, "environment_bands": bands, "travel_keyframes": keyframes, "precomputed": true}


static func cursor_for_action(timeline: Dictionary, action_index: int) -> Dictionary:
	var max_action := maxi(1, int(timeline.get("max_action_index", 1)))
	return cursor_for_progress(timeline, clampf(float(action_index) / float(max_action), 0.0, 1.0))


static func cursor_for_progress(timeline: Dictionary, progress: float) -> Dictionary:
	var clamped := clampf(progress, 0.0, 1.0)
	var max_action := maxi(1, int(timeline.get("max_action_index", 1)))
	var sample_index := 0
	var leg_index := 0
	var samples: Array = timeline.get("heat_samples", [])
	for index in range(samples.size()):
		if float((samples[index] as Dictionary).get("progress", 0.0)) <= clamped:
			sample_index = index
		else:
			break
	var frames: Array = timeline.get("travel_keyframes", [])
	for index in range(maxi(0, frames.size() - 1)):
		if float((frames[index + 1] as Dictionary).get("progress", 1.0)) <= clamped:
			leg_index = index + 1
		else:
			break
	return {"progress": clamped, "action_index": int(round(clamped * float(max_action))), "sample_index": sample_index, "leg_index": leg_index}


static func load_outcome_registry() -> Dictionary:
	if not FileAccess.file_exists(OUTCOME_REGISTRY_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUTCOME_REGISTRY_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	if typeof(parsed) == TYPE_ARRAY:
		return {"outcomes": catalog_by_id(parsed as Array)}
	return {}


static func catalog_by_id(entries: Array) -> Dictionary:
	var result := {}
	for value in entries:
		if typeof(value) == TYPE_DICTIONARY:
			var entry: Dictionary = value
			result[str(entry.get("id", ""))] = entry
	return result


static func _story_bankroll_delta(entry: Dictionary) -> int:
	if entry.has("bankroll_delta"):
		return int(entry.get("bankroll_delta", 0))
	match str(entry.get("type", "")):
		"item_sale": return maxi(0, int(entry.get("sale_price", 0)))
		"item_purchase": return -maxi(0, int(entry.get("price", 0)))
	return 0


static func _money_source(entry: Dictionary) -> Dictionary:
	var entry_type := str(entry.get("type", "other"))
	if entry_type == "game_action":
		var game_id := str(entry.get("game_id", entry.get("id", "game")))
		return {"key": "game:%s" % game_id, "id": game_id, "kind": "game"}
	if entry_type == "travel": return {"key": "travel", "id": "travel", "kind": "travel"}
	if entry_type == "item_purchase": return {"key": "items_bought", "id": "items_bought", "kind": "items"}
	if entry_type == "item_sale": return {"key": "items_sold", "id": "items_sold", "kind": "items"}
	if entry_type == "lender_hook" or entry_type.begins_with("debt_"): return {"key": "lender:%s" % str(entry.get("lender_id", entry.get("id", "loans"))), "id": str(entry.get("lender_id", entry.get("id", "loans"))), "kind": "lender"}
	if entry_type == "service_hook": return {"key": "services", "id": "services", "kind": "service"}
	if entry_type.find("event") != -1 or entry.has("event_id"): return {"key": "events", "id": "events", "kind": "event"}
	return {"key": entry_type, "id": str(entry.get("id", entry_type)), "kind": entry_type}


static func _source_label(entry: Dictionary, source: Dictionary, catalogs: Dictionary) -> String:
	var kind := str(source.get("kind", ""))
	var source_id := str(source.get("id", ""))
	if kind == "game":
		var game := _copy_dict(_copy_dict(catalogs.get("games", {})).get(source_id, {}))
		return str(game.get("display_name", source_id.replace("_", " ").capitalize()))
	if kind == "travel": return "Travel"
	if str(source.get("key", "")) == "items_bought": return "Items bought"
	if str(source.get("key", "")) == "items_sold": return "Items sold"
	if kind == "service": return "Services"
	if kind == "event": return "Events"
	return str(entry.get("label", source_id.replace("_", " ").capitalize()))


static func _item_row(item_id: String, count: int, fate: String, price: int, item_catalog: Dictionary) -> Dictionary:
	var definition := _copy_dict(item_catalog.get(item_id, {}))
	return {"item_id": item_id, "label": str(definition.get("display_name", item_id.replace("_", " ").capitalize())), "count": maxi(1, count), "fate": fate, "price": price, "icon_path": str(definition.get("asset_path", "res://assets/art/items/%s.png" % str(definition.get("icon_key", item_id))))}


static func _pawn_row(debt_entry: Dictionary, fate: String, item_catalog: Dictionary) -> Dictionary:
	var item_id := str(debt_entry.get("collateral_item_id", ""))
	var row := _item_row(item_id, 1, fate, 0, item_catalog)
	row["debt_id"] = str(debt_entry.get("id", ""))
	row["label"] = str(debt_entry.get("collateral_item_name", row.get("label", item_id)))
	return row


static func _loan_row(debt_entry: Dictionary, lender_label: String) -> Dictionary:
	var kind := str(debt_entry.get("debt_kind", "cash"))
	return {"id": str(debt_entry.get("id", "")), "lender": lender_label.replace("_", " ").capitalize(), "amount": maxi(0, int(debt_entry.get("principal", debt_entry.get("balance", 0)))), "kind": kind, "outcome": "still held" if kind == "pawn" else "outstanding", "tone": "outstanding"}


static func _player_facing_seed(run_data: Dictionary) -> String:
	var challenge := _copy_dict(run_data.get("challenge_config", {}))
	return "Hidden daily challenge" if bool(challenge.get("hidden_seed", false)) else str(run_data.get("seed_text", ""))


static func _dict_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry)
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value as Array:
			result.append(str(entry))
	return result


static func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
