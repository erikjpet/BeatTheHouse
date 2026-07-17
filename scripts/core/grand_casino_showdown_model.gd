class_name GrandCasinoShowdownModel
extends RefCounted

# Pure action-boundary calculations for the Grand Casino showdown front half.

const CREW_LENDER_ID := "the_crew"


static func crew_interacted(flags: Dictionary, debts: Array) -> bool:
	for flag_id in [
		"crew_marker_open",
		"crew_favor_pending",
		"crew_favor_completed",
		"crew_favor_refused",
		"crew_marker_clear",
		"crew_marker_converted_to_cash",
	]:
		if bool(flags.get(flag_id, false)):
			return true
	for debt_value in debts:
		if typeof(debt_value) != TYPE_DICTIONARY:
			continue
		if str((debt_value as Dictionary).get("lender_id", "")) == CREW_LENDER_ID:
			return true
	return false


static func pat_down(inventory: Array, config: Dictionary, watched_cheat: bool) -> Dictionary:
	var contraband_ids: Array = []
	var surveillance_ids: Array = []
	for classification_value in _copy_array(config.get("classifications", [])):
		if typeof(classification_value) != TYPE_DICTIONARY:
			continue
		var classification: Dictionary = classification_value
		var target := surveillance_ids if str(classification.get("id", "")) == "surveillance" else contraband_ids
		for item_value in _copy_array(classification.get("item_ids", [])):
			var item_id := str(item_value).strip_edges()
			if not item_id.is_empty() and inventory.has(item_id) and not target.has(item_id):
				target.append(item_id)
	var carried: Array = contraband_ids.duplicate()
	for item_id in surveillance_ids:
		if not carried.has(item_id):
			carried.append(item_id)
	var blatant_min := maxi(1, int(config.get("blatant_min_items", 3)))
	var tier := "clean"
	if contraband_ids.size() >= blatant_min or watched_cheat and not contraband_ids.is_empty():
		tier = "blatant"
	elif not surveillance_ids.is_empty() or contraband_ids.size() >= 2:
		tier = "serious"
	elif contraband_ids.size() == 1:
		tier = "minor"
	return {
		"tier": tier,
		"contraband_items": contraband_ids,
		"surveillance_items": surveillance_ids,
		"classified_items": carried,
		"confiscated_items": [] if tier == "clean" else carried.duplicate(),
		"handicap": maxi(0, int(config.get("serious_handicap", 18))) if tier == "serious" else 0,
		"watched_escalation": watched_cheat and not contraband_ids.is_empty(),
	}


static func select_evidence(snapshot: Dictionary, definitions: Array, count: int, rng: RngStream) -> Array:
	var matching: Array = []
	for definition_value in definitions:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition := (definition_value as Dictionary).duplicate(true)
		if _evidence_matches(str(definition.get("condition", "always")), snapshot):
			matching.append(definition)
	if rng == null:
		return matching.slice(0, mini(matching.size(), maxi(0, count)))
	return rng.pick_many(matching, mini(matching.size(), maxi(0, count)))


static func evidence_text(definition: Dictionary, snapshot: Dictionary) -> String:
	var text := str(definition.get("text", "Rourke studies the run ledger."))
	for key in ["heat", "open_debt_count", "drunk_level", "games_played", "net_winnings"]:
		text = text.replace("{%s}" % key, str(snapshot.get(key, 0)))
	return text


static func response_strength(choice_id: String, snapshot: Dictionary) -> Dictionary:
	var modifiers := _copy_dict(snapshot.get("modifiers", {}))
	var social_support := social_support_modifier(snapshot)
	var pressure_modifier := 0
	var fact_modifier := 0
	var fact_label := "the run record"
	match choice_id:
		"hold_steady":
			pressure_modifier = -4 if bool(snapshot.get("cheat_evidence", false)) or bool(snapshot.get("watched_cheat", false)) else 8
			fact_modifier = int(modifiers.get("clean_play_modifier", 0)) + maxi(0, int(modifiers.get("item_modifier", 0)))
			fact_label = "clean play and held items"
		"talk_down":
			pressure_modifier = 4
			fact_modifier = social_support - mini(6, int(floor(float(int(modifiers.get("alcohol_debt_penalty", 0))) / 3.0)))
			fact_label = "Linda, Crew, drink, and debt"
		"take_the_edge":
			pressure_modifier = 16
			fact_modifier = mini(4, maxi(0, int(modifiers.get("item_modifier", 0)))) - (4 if bool(snapshot.get("watched_cheat", false)) else 0)
			fact_label = "held tools against Rourke's watch"
	return {
		"strength": clampi(pressure_modifier + fact_modifier, -16, 20),
		"pressure_modifier": pressure_modifier,
		"fact_modifier": fact_modifier,
		"fact_label": fact_label,
	}


static func social_support_modifier(snapshot: Dictionary) -> int:
	var linda_standing := clampi(int(snapshot.get("linda_standing", 0)), 0, 6)
	var crew_support := 3 if bool(snapshot.get("crew_ties", false)) else 0
	return clampi(linda_standing + crew_support, 0, 8)


static func build_duel_terms(snapshot: Dictionary, pat_down_data: Dictionary, answers: Array, evidence_ids: Array, config: Dictionary) -> Dictionary:
	var response_total := 0
	var edge_count := 0
	var answer_ids: Array = []
	for answer_value in answers:
		if typeof(answer_value) != TYPE_DICTIONARY:
			continue
		var answer: Dictionary = answer_value
		response_total += int(answer.get("strength", 0))
		var choice_id := str(answer.get("choice_id", ""))
		answer_ids.append(choice_id)
		if choice_id == "take_the_edge":
			edge_count += 1
	var response_modifier := int(round(float(response_total) / float(maxi(1, answer_ids.size()))))
	var modifiers := _copy_dict(snapshot.get("modifiers", {}))
	modifiers["pressure_choice_modifier"] = response_modifier
	var social_support := social_support_modifier(snapshot)
	var pat_down_handicap := maxi(0, int(pat_down_data.get("handicap", 0)))
	var leverage := (
		response_modifier
		+ int(modifiers.get("prior_boss_event_modifier", 0))
		- int(modifiers.get("heat_penalty", 0))
		- int(modifiers.get("evidence_penalty", 0))
		- int(modifiers.get("alcohol_debt_penalty", 0))
		- pat_down_handicap
	)
	var base_stack := maxi(25, int(config.get("base_stack", 100)))
	var player_stack := maxi(25, base_stack + leverage)
	var aggression := clampi(
		1
		+ int(floor(float(int(modifiers.get("heat_penalty", 0))) / 8.0))
		+ int(floor(float(int(modifiers.get("evidence_penalty", 0))) / 10.0))
		+ edge_count
		+ (1 if str(pat_down_data.get("tier", "clean")) == "serious" else 0),
		1,
		5
	)
	var cheat_level := clampi(
		(2 if bool(snapshot.get("watched_cheat", false)) else 1 if bool(snapshot.get("cheat_evidence", false)) else 0)
		+ (1 if edge_count > 0 else 0)
		+ (1 if str(pat_down_data.get("tier", "clean")) == "serious" else 0),
		0,
		3
	)
	var margin_thresholds := _copy_dict(config.get("margin_thresholds", {}))
	if margin_thresholds.is_empty():
		margin_thresholds = {"walk_out_clean_min": 12, "shown_the_door_min": -8}
	return {
		"version": 1,
		"starting_stacks": {
			"player": player_stack,
			"rourke": base_stack + aggression * maxi(1, int(config.get("rourke_stack_per_aggression", 5))),
		},
		"handicaps": {
			"player": pat_down_handicap,
			"forced_ante": maxi(0, int(config.get("serious_forced_ante", 5))) if str(pat_down_data.get("tier", "clean")) == "serious" else 0,
		},
		"rourke_aggression": aggression,
		"rourke_cheat_level": cheat_level,
		"margin_thresholds": margin_thresholds,
		"rules": _copy_dict(config.get("rules", {})),
		"edge_catalog": _copy_array(config.get("edge_catalog", [])),
		"barks": _copy_dict(config.get("barks", {})),
		"pat_down": pat_down_data.duplicate(true),
		"interrogation": {
			"evidence_ids": evidence_ids.duplicate(true),
			"answer_ids": answer_ids,
			"answers": answers.duplicate(true),
			"response_modifier": response_modifier,
			"leverage": leverage,
			"social_support": social_support,
		},
	}


static func _evidence_matches(condition: String, snapshot: Dictionary) -> bool:
	match condition:
		"watched_cheat":
			return bool(snapshot.get("watched_cheat", false))
		"cheat_evidence":
			return bool(snapshot.get("cheat_evidence", false))
		"attention":
			return not _copy_array(snapshot.get("attention_sources", [])).is_empty()
		"open_debt":
			return int(snapshot.get("open_debt_count", 0)) > 0
		"drunk":
			return int(snapshot.get("drunk_level", 0)) > 10
		"prior_cameo":
			return bool(snapshot.get("prior_cameo", false))
		"card_ineligible":
			return bool(snapshot.get("card_ineligible", false))
		"clean_play":
			return not bool(snapshot.get("cheat_evidence", false)) and not bool(snapshot.get("watched_cheat", false)) and int(snapshot.get("games_played", 0)) > 0
		"linda_standing":
			return int(snapshot.get("linda_standing", 0)) > 0
		"crew_ties":
			return bool(snapshot.get("crew_ties", false))
		_:
			return true


static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
