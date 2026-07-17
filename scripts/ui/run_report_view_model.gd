class_name RunReportViewModel
extends RefCounted

const OUTCOME_REGISTRY_PATH := "res://data/art/run_outcome_icons.json"
const BAG_GRANTS_FLAG := "_meta_bag_grants"
const BAG_SELECTED_FLAG := "_meta_bag_selected"
const BAG_FLUSHED_FLAG := "_meta_bag_grants_flushed"
const PLAYERS_CARD_REWARD_FLAG := "_meta_players_card_reward"
const PLAYERS_CARD_DESTROYED_FLAG := "_meta_players_card_destroyed"
const PRESTIGE_RESULT_FLAG := "_meta_prestige_result"


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
		maxi(0, int(_copy_dict(run_data.get("event_cadence", {})).get("action_index", 0))),
		story_log,
		RunState.GAME_CLOCK_START_MINUTE,
		maxi(RunState.GAME_CLOCK_START_MINUTE, int(run_data.get("game_clock_minutes", RunState.GAME_CLOCK_START_MINUTE)))
	)
	var report_map := build_report_map_snapshot(_copy_dict(run_data.get("world_map", {})), timeline)
	return {
		"outcome": outcome,
		"score": {
			"money_put_to_work": int(score.get("base_spending", 0)),
			"winner_bonus": maxi(1, int(score.get("multiplier", 1))),
			"show_winner_bonus": bool(outcome.get("won", false)),
			"final_score": int(score.get("score", 0)),
		},
		"items": build_item_fates(_string_array(run_data.get("inventory", [])), _dict_array(run_data.get("debt", [])), story_log, _copy_dict(catalogs.get("items", {}))),
		"bag_reward": build_bag_reward(run_data),
		"meta_reward": build_meta_reward(run_data),
		"debts": build_debt_ledger(_dict_array(run_data.get("debt", [])), story_log),
		"money_rows": build_money_rows(story_log, catalogs),
		"timeline": timeline,
		"map_snapshot": report_map,
		"seed": _player_facing_seed(run_data),
	}


static func build_meta_reward(run_data: Dictionary) -> Dictionary:
	var flags := _copy_dict(run_data.get("narrative_flags", {}))
	var card := _copy_dict(flags.get(PLAYERS_CARD_REWARD_FLAG, {}))
	var destroyed := _dict_array(flags.get(PLAYERS_CARD_DESTROYED_FLAG, []))
	var prestige := _copy_dict(flags.get(PRESTIGE_RESULT_FLAG, {}))
	if not card.is_empty():
		var stamp := _copy_dict(card.get("instance_data", {}))
		return {
			"visible": true,
			"kind": "players_card_minted",
			"title": "CARD MINTED · %s" % str(card.get("display_name", "Grand Casino Players Card")),
			"detail": "Gold · Score %d · Day %d · %s" % [int(stamp.get("final_score", 0)), int(stamp.get("days_survived", 1)), str(stamp.get("seed", ""))],
			"instance_id": int(card.get("instance_id", 0)),
		}
	if not destroyed.is_empty():
		return {
			"visible": true,
			"kind": "players_card_destroyed",
			"title": "CARD LOST FOREVER · Grand Casino Players Card",
			"detail": "The prestige card carried into this failed run was destroyed.",
			"instance_id": int(_copy_dict(destroyed[0]).get("instance_id", 0)),
		}
	if bool(prestige.get("active", false)):
		return {
			"visible": true,
			"kind": "prestige_retained",
			"title": "PRESTIGE RUN · Players Card retained",
			"detail": "Recognition applied; the carried card returned safely.",
		}
	return {"visible": false}


static func build_bag_reward(run_data: Dictionary) -> Dictionary:
	var flags := _copy_dict(run_data.get("narrative_flags", {}))
	var won := str(run_data.get("run_status", "")) == RunState.RUN_STATUS_ENDED and bool(flags.get("demo_victory", false))
	var choices: Array = []
	for marker_value in _dict_array(run_data.get("pending_bags", [])):
		var marker := _copy_dict(marker_value)
		var marker_id := str(marker.get("marker_id", "")).strip_edges()
		if marker_id.is_empty():
			continue
		var display_name := str(marker.get("display_name", "Collection Bag")).strip_edges()
		if display_name.is_empty():
			display_name = "Collection Bag"
		var collection_name := str(marker.get("collection_display_name", marker.get("collection_id", "Collection"))).strip_edges()
		var tier_label := str(marker.get("tier_label", str(marker.get("tier", "")).capitalize())).strip_edges()
		choices.append({
			"marker_id": marker_id,
			"display_name": display_name,
			"collection_name": collection_name,
			"tier_label": tier_label,
		})
	var summary_lines := _string_array(flags.get(BAG_GRANTS_FLAG, []))
	var flushed := bool(flags.get(BAG_FLUSHED_FLAG, false))
	return {
		"visible": won and (not choices.is_empty() or flushed or not summary_lines.is_empty()),
		"pending": won and not flushed and not choices.is_empty(),
		"choices": choices,
		"summary_lines": summary_lines,
		"selected_marker_id": str(flags.get(BAG_SELECTED_FLAG, "")),
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


static func build_timeline(heat_entries: Array, world_map: Dictionary, final_action_index: int = 0, story_log: Array = [], start_game_clock_minutes: int = RunState.GAME_CLOCK_START_MINUTE, end_game_clock_minutes: int = -1) -> Dictionary:
	var samples := RunState.normalize_heat_history(heat_entries)
	if samples.is_empty():
		samples = [{"action_index": 0, "game_clock_minutes": start_game_clock_minutes, "heat_value": 0, "environment_id": "", "environment_name": "", "world_node_id": "", "transition": true}]
	var max_action := maxi(1, final_action_index)
	for sample in samples:
		max_action = maxi(max_action, int((sample as Dictionary).get("action_index", 0)))
	var start_clock := maxi(0, start_game_clock_minutes)
	var end_clock := end_game_clock_minutes
	if end_clock < start_clock:
		end_clock = start_clock + max_action * RunState.ACTION_CLOCK_MINUTES
	end_clock = maxi(start_clock, end_clock)
	var duration_minutes := maxi(1, end_clock - start_clock)
	var normalized_samples: Array = []
	var transitions: Array = []
	for sample_value in samples:
		var sample: Dictionary = sample_value
		var row := sample.duplicate(false)
		var sample_clock := int(sample.get("game_clock_minutes", -1))
		if sample_clock >= start_clock:
			row["progress"] = _clock_progress(sample_clock, start_clock, duration_minutes)
		else:
			row["progress"] = clampf(float(int(sample.get("action_index", 0))) / float(max_action), 0.0, 1.0)
		normalized_samples.append(row)
		if bool(sample.get("transition", false)):
			transitions.append(row)
	var nodes_by_id := {}
	for node_value in _dict_array(world_map.get("nodes", [])):
		nodes_by_id[str(node_value.get("id", ""))] = node_value
	var path := _string_array(world_map.get("visited_path", []))
	if path.is_empty():
		var current_node_id := str(world_map.get("current_node_id", "")).strip_edges()
		if not current_node_id.is_empty():
			path.append(current_node_id)
	var travel_entries: Array = []
	for entry_value in _dict_array(story_log):
		if str(entry_value.get("type", "")) == "travel":
			travel_entries.append(entry_value)
	var keyframes: Array = []
	var segments: Array = []
	var arrival_clock := start_clock
	for index in range(path.size()):
		var node_id := str(path[index])
		var node := _copy_dict(nodes_by_id.get(node_id, {}))
		var label := str(node.get("display_name", node.get("label", node_id.replace("_", " ").capitalize())))
		var position := _copy_dict(node.get("position", {}))
		keyframes.append({
			"node_id": node_id,
			"label": label,
			"action_index": int(round(_clock_progress(arrival_clock, start_clock, duration_minutes) * float(max_action))),
			"game_clock_minutes": arrival_clock,
			"progress": _clock_progress(arrival_clock, start_clock, duration_minutes),
			"position": {"x": float(position.get("x", 0.5)), "y": float(position.get("y", 0.5))},
		})
		if index + 1 >= path.size():
			_append_replay_segment(segments, "dwell", node_id, node_id, label, label, arrival_clock, end_clock, start_clock, duration_minutes, index)
			continue
		var next_node_id := str(path[index + 1])
		var next_node := _copy_dict(nodes_by_id.get(next_node_id, {}))
		var next_label := str(next_node.get("display_name", next_node.get("label", next_node_id.replace("_", " ").capitalize())))
		var travel_entry := _copy_dict(travel_entries[index]) if index < travel_entries.size() else {}
		var travel_minutes := maxi(1, int(travel_entry.get("travel_minutes", 1)))
		var next_arrival_clock := int(travel_entry.get("arrived_game_clock_minutes", -1))
		if next_arrival_clock < 0 and index + 1 < transitions.size():
			var transition_clock := int((transitions[index + 1] as Dictionary).get("game_clock_minutes", -1))
			if transition_clock >= 0:
				next_arrival_clock = transition_clock
		if next_arrival_clock < 0:
			var transition_progress := float((transitions[index + 1] as Dictionary).get("progress", float(index + 1) / float(maxi(1, path.size() - 1)))) if index + 1 < transitions.size() else float(index + 1) / float(maxi(1, path.size() - 1))
			next_arrival_clock = start_clock + int(round(transition_progress * float(duration_minutes)))
		next_arrival_clock = clampi(next_arrival_clock, arrival_clock, end_clock)
		var departure_clock := int(travel_entry.get("departed_game_clock_minutes", next_arrival_clock - travel_minutes))
		departure_clock = clampi(departure_clock, arrival_clock, next_arrival_clock)
		_append_replay_segment(segments, "dwell", node_id, node_id, label, label, arrival_clock, departure_clock, start_clock, duration_minutes, index)
		_append_replay_segment(segments, "travel", node_id, next_node_id, label, next_label, departure_clock, next_arrival_clock, start_clock, duration_minutes, index)
		arrival_clock = next_arrival_clock
	if segments.is_empty() and not path.is_empty():
		var only_node_id := str(path[0])
		var only_node := _copy_dict(nodes_by_id.get(only_node_id, {}))
		var only_label := str(only_node.get("display_name", only_node_id.replace("_", " ").capitalize()))
		segments.append({"kind": "dwell", "node_id": only_node_id, "from_node_id": only_node_id, "to_node_id": only_node_id, "from_label": only_label, "to_label": only_label, "start_game_clock_minutes": start_clock, "end_game_clock_minutes": end_clock, "start_progress": 0.0, "end_progress": 1.0, "leg_index": 0})
	var bands: Array = []
	for segment_value in segments:
		var segment: Dictionary = segment_value
		if str(segment.get("kind", "")) != "dwell":
			continue
		bands.append({
			"environment_id": str(segment.get("node_id", "")),
			"label": str(segment.get("from_label", "Venue")),
			"start_progress": float(segment.get("start_progress", 0.0)),
			"end_progress": float(segment.get("end_progress", 0.0)),
			"color_index": int(segment.get("leg_index", 0)) % 6,
		})
	return {"max_action_index": max_action, "start_game_clock_minutes": start_clock, "end_game_clock_minutes": end_clock, "duration_minutes": end_clock - start_clock, "heat_samples": normalized_samples, "environment_bands": bands, "travel_keyframes": keyframes, "replay_segments": segments, "visited_node_ids": path, "precomputed": true}


static func _append_replay_segment(segments: Array, kind: String, from_node_id: String, to_node_id: String, from_label: String, to_label: String, start_clock: int, end_clock: int, run_start_clock: int, duration_minutes: int, leg_index: int) -> void:
	var safe_start := maxi(run_start_clock, start_clock)
	var safe_end := maxi(safe_start, end_clock)
	if safe_end == safe_start and not segments.is_empty():
		return
	segments.append({
		"kind": kind,
		"node_id": from_node_id if kind == "dwell" else "",
		"from_node_id": from_node_id,
		"to_node_id": to_node_id,
		"from_label": from_label,
		"to_label": to_label,
		"start_game_clock_minutes": safe_start,
		"end_game_clock_minutes": safe_end,
		"start_progress": _clock_progress(safe_start, run_start_clock, duration_minutes),
		"end_progress": _clock_progress(safe_end, run_start_clock, duration_minutes),
		"leg_index": leg_index,
	})


static func _clock_progress(game_clock_minutes: int, start_clock: int, duration_minutes: int) -> float:
	return clampf(float(game_clock_minutes - start_clock) / float(maxi(1, duration_minutes)), 0.0, 1.0)


static func build_report_map_snapshot(world_map: Dictionary, timeline: Dictionary) -> Dictionary:
	var report_map := world_map.duplicate(true)
	var path := _string_array(timeline.get("visited_node_ids", world_map.get("visited_path", [])))
	var visited_lookup := {}
	for node_id in path:
		visited_lookup[str(node_id)] = true
	var nodes: Array = []
	for node_value in _dict_array(world_map.get("nodes", [])):
		var node_id := str(node_value.get("id", ""))
		if not visited_lookup.has(node_id):
			continue
		var node: Dictionary = node_value.duplicate(true)
		node["state"] = "visited"
		node["travel_target"] = false
		node["travel_enabled"] = false
		nodes.append(node)
	var edges: Array = []
	for edge_value in _dict_array(world_map.get("edges", [])):
		if visited_lookup.has(str(edge_value.get("a", ""))) and visited_lookup.has(str(edge_value.get("b", ""))):
			edges.append(edge_value.duplicate(true))
	report_map["nodes"] = nodes
	report_map["edges"] = edges
	report_map["visited_path"] = path
	report_map["map_focus_node_ids"] = visited_lookup.keys()
	report_map["travel_paths"] = []
	report_map["selected_node_id"] = ""
	if not path.is_empty():
		report_map["current_node_id"] = str(path[-1])
	return report_map


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
	var phase := "dwell"
	for segment_value in timeline.get("replay_segments", []):
		if typeof(segment_value) != TYPE_DICTIONARY:
			continue
		var segment: Dictionary = segment_value
		if str(segment.get("kind", "")) != "travel":
			continue
		var start := float(segment.get("start_progress", 0.0))
		var finish := float(segment.get("end_progress", start))
		if clamped >= finish:
			leg_index = int(segment.get("leg_index", leg_index)) + 1
		elif clamped >= start:
			leg_index = int(segment.get("leg_index", leg_index))
			phase = "travel"
			break
	var start_clock := int(timeline.get("start_game_clock_minutes", RunState.GAME_CLOCK_START_MINUTE))
	var end_clock := maxi(start_clock, int(timeline.get("end_game_clock_minutes", start_clock)))
	return {"progress": clamped, "action_index": int(round(clamped * float(max_action))), "game_clock_minutes": int(round(lerpf(float(start_clock), float(end_clock), clamped))), "sample_index": sample_index, "leg_index": leg_index, "phase": phase}


static func format_game_clock(game_clock_minutes: int) -> String:
	var total_minutes := maxi(0, game_clock_minutes)
	var day := int(floor(float(total_minutes) / 1440.0)) + 1
	var minute_of_day := total_minutes % 1440
	var hour_24 := int(floor(float(minute_of_day) / 60.0)) % 24
	var hour_12 := hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	var suffix := "AM" if hour_24 < 12 else "PM"
	return "Day %d %d:%02d %s" % [day, hour_12, minute_of_day % 60, suffix]


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
