class_name AgentPlaytestPublicObservation
extends RefCounted

# The production-input bridge is an accessibility surface, not a debug probe.
# Build its JSON from explicit player-facing fields so a newly-added module or
# RunState field is private until it is deliberately reviewed here.

const SCHEMA := "beat_the_house.agent_public_observation"
const SCHEMA_VERSION := 1


static func sanitize(raw_value: Variant) -> Dictionary:
	var raw := _dict(raw_value)
	var result := {
		"schema": SCHEMA,
		"schema_version": SCHEMA_VERSION,
		"screen": _screen(_dict(raw.get("screen", {}))),
		"environment": _environment(_dict(raw.get("environment", {}))),
		"spatial": _spatial(_dict(raw.get("spatial", {}))),
		"game": _game(_dict(raw.get("game", {}))),
		"consequence": _consequence(_dict(raw.get("consequence", {}))),
		"status_hud": _status_hud(_dict(raw.get("status_hud", {}))),
		"feedback": _feedback(_dict(raw.get("feedback", {}))),
		"event_popup": _event_popup(_dict(raw.get("event_popup", {}))),
		"talk": _talk(_dict(raw.get("talk", {}))),
		"inventory": _inventory(_dict(raw.get("inventory", {}))),
		"message": _scalars(_dict(raw.get("message", {})), ["visible", "text"]),
		"room_canvas": _room_canvas(_dict(raw.get("room_canvas", {}))),
		"game_canvas": _game_canvas(_dict(raw.get("game_canvas", {}))),
		"privacy": {
			"policy": "strict_allowlist",
			"dealer_private_state": "redacted",
			"run_authority": "redacted",
		},
	}
	var checkpoint := canonical_checkpoint(result)
	result["checkpoint"] = checkpoint
	result["checkpoint_fingerprint"] = fingerprint(checkpoint)
	return result


static func canonical_checkpoint(observation_value: Variant) -> Dictionary:
	var observation := _dict(observation_value)
	var screen := _dict(observation.get("screen", {}))
	var environment := _dict(observation.get("environment", {}))
	var spatial := _dict(observation.get("spatial", {}))
	var game := _dict(observation.get("game", {}))
	var hud := _dict(observation.get("status_hud", {}))
	var event_popup := _dict(observation.get("event_popup", {}))
	var talk := _dict(observation.get("talk", {}))
	var report := _dict(screen.get("run_report", {}))
	var report_outcome := _dict(report.get("outcome", {}))
	return {
		"screen": str(screen.get("screen", "")),
		"has_run": bool(screen.get("has_run", false)),
		"run_menu_visible": bool(screen.get("run_menu_visible", false)),
		"world_map_visible": bool(screen.get("world_map_overlay_visible", false)),
		"location_id": str(environment.get("id", "")),
		"location_archetype": str(environment.get("archetype_id", "")),
		"world_node_id": str(environment.get("world_node_id", "")),
		"selected_object_id": str(spatial.get("selected_object_id", "")),
		"bankroll": int(hud.get("bankroll", 0)),
		"bankroll_rendered": bool(hud.get("bankroll_rendered", false)),
		"chips": int(hud.get("chips", 0)),
		"chips_rendered": bool(hud.get("chips_rendered", false)),
		"heat": int(hud.get("heat_level", 0)),
		"heat_rendered": bool(hud.get("heat_rendered", false)),
		"game_id": str(game.get("game_id", "")),
		"game_phase": str(game.get("phase", "")),
		"game_outcome": str(game.get("outcome_message", "")),
		"event_id": str(event_popup.get("event_id", "")) if bool(event_popup.get("visible", false)) else "",
		"event_choice_ids": _string_array(event_popup.get("choice_ids", [])) if bool(event_popup.get("visible", false)) else [],
		"talk_event_id": str(talk.get("event_id", "")) if bool(talk.get("visible", false)) else "",
		"talk_choice_ids": _string_array(talk.get("choice_ids", [])) if bool(talk.get("visible", false)) else [],
		"terminal_outcome_key": str(report_outcome.get("key", "")),
		"terminal_won": bool(report_outcome.get("won", false)),
	}


static func transition_summary(before_value: Variant, after_value: Variant, command: String, accepted: bool) -> Dictionary:
	var before_observation := _dict(before_value)
	var after_observation := _dict(after_value)
	var before := canonical_checkpoint(before_observation)
	var after := canonical_checkpoint(after_observation)
	# Authenticate the complete allowlisted player surface. The canonical
	# checkpoint remains the compact persistence comparison, while the trace must
	# notice public dialogue, action, card, feedback, and map changes too.
	var before_fingerprint := fingerprint(before_observation)
	var after_fingerprint := fingerprint(after_observation)
	return {
		"command": command,
		"input_emitted": accepted,
		"before_fingerprint": before_fingerprint,
		"after_fingerprint": after_fingerprint,
		"public_state_changed": before_fingerprint != after_fingerprint,
		"screen_changed": str(before.get("screen", "")) != str(after.get("screen", "")),
		"location_changed": str(before.get("location_id", "")) != str(after.get("location_id", "")),
		"modal_changed": str(before.get("event_id", "")) != str(after.get("event_id", "")) \
			or str(before.get("talk_event_id", "")) != str(after.get("talk_event_id", "")),
		"economy_changed": int(before.get("bankroll", 0)) != int(after.get("bankroll", 0)) \
			or int(before.get("chips", 0)) != int(after.get("chips", 0)),
		"heat_changed": int(before.get("heat", 0)) != int(after.get("heat", 0)),
	}


static func fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical(value)).sha256_text()


static func _screen(source: Dictionary) -> Dictionary:
	var result := _scalars(source, [
		"screen", "selected_category", "has_run", "has_game",
		"run_journal_visible", "travel_transition_active", "travel_transition_target_id",
		"travel_transition_target_label",
	])
	var overlay_state := _dict(source.get("overlay_state", {}))
	result["overlay_state"] = _scalars(overlay_state, [
		"screen", "event_choice_popup_visible", "event_choice_popup_type", "talk_dock_visible",
		"world_map_visible", "run_inventory_visible", "run_journal_visible", "run_menu_visible",
		"settings_visible", "travel_transition_active", "contract_valid",
	])
	# Cached screen snapshots remain populated after their controls close. Publish
	# each overlay payload only when independent rendered-state witnesses agree.
	var screen_id := str(source.get("screen", ""))
	var start_menu_source := _dict(source.get("start_menu", {}))
	var start_menu_rendered := screen_id == "START" and _is_true_bool(start_menu_source.get("visible", false))
	result["start_menu"] = _start_menu(start_menu_source) if start_menu_rendered else {}
	var run_menu_rendered := _is_true_bool(source.get("run_menu_visible", false)) \
		and _is_true_bool(overlay_state.get("run_menu_visible", false))
	result["run_menu_visible"] = run_menu_rendered
	result["run_menu"] = _scalars(_dict(source.get("run_menu", {})), [
		"visible", "screen", "slot_id", "has_save", "status_text", "resume_disabled",
		"save_disabled", "load_disabled", "journal_disabled", "settings_disabled",
		"abandon_disabled", "main_menu_disabled",
	]) if run_menu_rendered else {}
	# FoundationMain keeps a populated map snapshot warm even while its overlay is
	# closed. It is model/cache state until both rendered visibility witnesses say
	# the player can actually see it, so fail closed instead of publishing markers.
	var map_rendered := _is_true_bool(source.get("world_map_overlay_visible", false)) \
		and _is_true_bool(overlay_state.get("world_map_visible", false))
	result["world_map_overlay_visible"] = map_rendered
	if map_rendered:
		for key in [
			"world_map_title_text", "selected_world_map_node_id", "world_map_detail_text",
			"world_map_detail_popup_visible", "world_map_confirm_enabled",
		]:
			if source.has(key):
				result[key] = source[key]
	result["world_map"] = _world_map(_dict(source.get("world_map", {}))) if map_rendered else {}
	var run_report_rendered := screen_id in ["VICTORY", "FAILURE"] \
		and _is_true_bool(source.get("run_report_visible", false))
	result["run_report_visible"] = run_report_rendered
	result["run_report"] = _run_report(_dict(source.get("run_report", {}))) if run_report_rendered else {}
	return result


static func _start_menu(source: Dictionary) -> Dictionary:
	var result := _scalars(source, [
		"visible", "content_group_config_visible", "challenge_config_visible", "run_config_visible",
		"primary_action_visible", "release_version_visible", "seed_field_visible", "seed_text_committed",
	])
	if _is_true_bool(source.get("primary_action_visible", false)):
		result["primary_action_text"] = str(source.get("primary_action_text", ""))
	if _is_true_bool(source.get("release_version_visible", false)):
		result["release_version_text"] = str(source.get("release_version_text", ""))
	if _is_true_bool(source.get("seed_field_visible", false)) and _is_true_bool(source.get("seed_text_committed", false)):
		result["seed_text"] = str(source.get("seed_text", ""))
	if _is_true_bool(source.get("content_group_config_visible", false)) or _is_true_bool(source.get("run_config_visible", false)):
		result["selected_home_type_id"] = str(source.get("selected_home_type_id", ""))
		result["selected_content_groups"] = _string_array(source.get("selected_content_groups", []))
	if _is_true_bool(source.get("challenge_config_visible", false)) or _is_true_bool(source.get("run_config_visible", false)):
		result["selected_challenge_id"] = str(source.get("selected_challenge_id", ""))
	return result


static func _run_report(source: Dictionary) -> Dictionary:
	if source.is_empty():
		return {}
	var result := _scalars(source, ["seed", "score", "score_total", "status", "title", "summary"])
	var outcome := _dict(source.get("outcome", {}))
	result["outcome"] = _scalars(outcome, ["key", "title", "how", "won", "tone", "act_two_seam_text"])
	return result


static func _world_map(source: Dictionary) -> Dictionary:
	if source.is_empty():
		return {}
	var result := _scalars(source, ["current_node_id", "selected_node_id", "title", "summary"])
	var nodes: Array = []
	for value in _array(source.get("nodes", [])):
		var node := _dict(value)
		if node.is_empty():
			continue
		var public_node := _scalars(node, [
			"id", "archetype_id", "display_name", "label", "kind", "tier", "state", "current",
			"selected", "travel_target", "travel_enabled", "enabled", "open", "locked",
			"disabled_reason", "travel_disabled_reason", "open_now", "open_status_text",
			"closing_soon", "cost", "distance", "distance_blocks", "risk", "risk_decay",
			"travel_method", "travel_method_kind", "delivery_target", "delivery_target_status",
			"delivery_deadline_remaining", "delivery_marker_label",
		])
		public_node["position"] = _scalars(_dict(node.get("position", {})), ["x", "y"])
		nodes.append(public_node)
	result["nodes"] = nodes
	var edges: Array = []
	for value in _array(source.get("edges", [])):
		var edge := _dict(value)
		if edge.is_empty():
			continue
		edges.append(_scalars(edge, [
			"id", "a", "b", "state", "enabled", "distance", "distance_blocks", "risk",
			"risk_decay", "base_cost", "cost", "travel_method", "travel_method_kind",
		]))
	result["edges"] = edges
	return result


static func _environment(source: Dictionary) -> Dictionary:
	# Environment is identity/label context only. Rendered room objects come from
	# room_canvas/clickable metadata, progress comes from the HUD, and the map is
	# admitted only through screen.world_map while its overlay is rendered. Raw
	# event/resolution lists and option catalogs are model state, not observation.
	return _scalars(source, [
		"id", "archetype_id", "world_node_id", "display_name", "kind", "tier",
		"clock_text", "venue_open_status", "venue_open_status_text",
	])


static func _spatial(source: Dictionary) -> Dictionary:
	var result := _scalars(source, [
		"available", "loading", "hover_target_id", "focus_target_id", "selected_object_id",
		"current_context_mode", "selected_stake", "selected_action_id",
	])
	result["objects"] = _objects(source.get("objects", []))
	return result


static func _game(source: Dictionary) -> Dictionary:
	var result := _scalars(source, [
		"game_id", "display_name", "description", "family", "surface_renderer", "surface_life",
		"surface_cast", "has_recent_outcome", "outcome_message", "outcome_bankroll_delta",
		"outcome_suspicion_delta", "result_message", "bankroll", "suspicion_level", "stake_min",
		"stake_max", "selected_stake", "has_valid_stake", "selected_action_id",
		"selected_action_kind", "selected_action_label", "selected_action_summary", "risk_cue",
		"result_stake", "won", "state", "summary_source", "phase", "round_complete",
		"message", "blackjack_total", "blackjack_soft", "active_hand_index", "active_hand_status",
		"can_deal", "can_hit", "can_stand", "can_double", "can_split", "can_surrender",
		"dealer_hole_visible", "peek_available", "peek_window_open", "settle_available", "counting_enabled",
		"boss_variant", "boss_duel_active", "boss_player_stack", "boss_rourke_stack",
		"boss_hand_number", "boss_hand_limit", "boss_bark", "boss_tell", "boss_callout_used",
		"table_name", "table_notice", "table_rules_text", "wager_currency", "main_wager_cost",
		"total_wager_cost", "bankroll_delta", "chips", "chips_delta", "currency",
	])
	result["legal_actions"] = _actions(source.get("legal_actions", []))
	result["cheat_actions"] = _actions(source.get("cheat_actions", []))
	result["boss_callouts"] = _actions(source.get("boss_callouts", []))
	result["player_hands"] = _public_player_hands(source.get("player_hands", []))
	var dealer_cards := _array(source.get("dealer_cards", []))
	if not dealer_cards.is_empty():
		result["dealer_up_card"] = _card(_dict(dealer_cards[0]))
	else:
		result["dealer_up_card"] = {}
	var visible_dealer_cards: Array = []
	if _is_true_bool(source.get("dealer_hole_visible", false)):
		for card_value in dealer_cards:
			visible_dealer_cards.append(_card(_dict(card_value)))
	result["dealer_cards"] = visible_dealer_cards
	return result


static func _public_player_hands(value: Variant) -> Array:
	var source_hands := _array(value)
	if source_hands.is_empty() and typeof(value) == TYPE_DICTIONARY:
		source_hands = [value]
	var result: Array = []
	for hand_value in source_hands:
		var hand := _dict(hand_value)
		if hand.is_empty():
			continue
		var public_hand := _scalars(hand, [
			"total", "soft", "blackjack_eligible", "doubled", "split", "stood", "surrendered",
			"terminal_reason", "wager_multiplier",
		])
		var cards: Array = []
		for card_value in _array(hand.get("cards", [])):
			cards.append(_card(_dict(card_value)))
		public_hand["cards"] = cards
		result.append(public_hand)
	return result


static func _card(source: Dictionary) -> Dictionary:
	return _scalars(source, ["rank", "suit"])


static func _consequence(source: Dictionary) -> Dictionary:
	var rendered_value: Variant = source.get("rendered", false)
	var rendered := typeof(rendered_value) == TYPE_BOOL and bool(rendered_value)
	return {
		"rendered": rendered,
		"rendered_lines": _string_array(source.get("rendered_lines", [])) if rendered else [],
	}


static func _status_hud(source: Dictionary) -> Dictionary:
	var result := {}
	for definition in [
		["bankroll", "bankroll_rendered"],
		["chips", "chips_rendered"],
		["heat_level", "heat_rendered"],
	]:
		var value_key := str(definition[0])
		var witness_key := str(definition[1])
		var witness_value: Variant = source.get(witness_key, false)
		var rendered := typeof(witness_value) == TYPE_BOOL and bool(witness_value)
		result[witness_key] = rendered
		var value: Variant = source.get(value_key, null)
		if rendered and typeof(value) == TYPE_INT:
			result[value_key] = value
	var drunk_rendered_value: Variant = source.get("drunk_rendered", false)
	var drunk_rendered := typeof(drunk_rendered_value) == TYPE_BOOL and bool(drunk_rendered_value)
	result["drunk_rendered"] = drunk_rendered
	if drunk_rendered:
		result["drunk_text"] = str(source.get("drunk_text", ""))
	var save_visible_value: Variant = source.get("save_text_visible", false)
	result["save_text_visible"] = typeof(save_visible_value) == TYPE_BOOL and bool(save_visible_value)
	if bool(result["save_text_visible"]):
		result["save_text"] = str(source.get("save_text", ""))
	result["debt_indicator"] = _debt_indicator(_dict(source.get("debt_indicator", {})))
	return result


static func _debt_indicator(source: Dictionary) -> Dictionary:
	var rendered_value: Variant = source.get("rendered", false)
	var present_value: Variant = source.get("present", false)
	var rendered := typeof(rendered_value) == TYPE_BOOL and bool(rendered_value)
	var present := typeof(present_value) == TYPE_BOOL and bool(present_value)
	var result := {"rendered": rendered, "present": present if rendered else false}
	if rendered and present:
		result["tooltip"] = str(source.get("tooltip", ""))
	return result


static func _feedback(source: Dictionary) -> Dictionary:
	var visible_value: Variant = source.get("visible", false)
	if typeof(visible_value) != TYPE_BOOL or not bool(visible_value):
		return {"visible": false}
	return _scalars(source, [
		"visible", "title", "text",
	])


static func _event_popup(source: Dictionary) -> Dictionary:
	var visible_value: Variant = source.get("visible", false)
	if typeof(visible_value) != TYPE_BOOL or not bool(visible_value):
		return {"visible": false, "render_valid": false}
	var render_valid_value: Variant = source.get("render_valid", false)
	var render_valid := typeof(render_valid_value) == TYPE_BOOL and bool(render_valid_value)
	var result := {"visible": true, "render_valid": render_valid}
	if not render_valid:
		return result
	result["event_id"] = str(source.get("event_id", ""))
	result["summary"] = str(source.get("summary", ""))
	result["title"] = str(source.get("title", ""))
	result["choices"] = _choices(source.get("choices", []))
	result["choice_ids"] = _string_array(source.get("choice_ids", []))
	return result


static func _talk(source: Dictionary) -> Dictionary:
	var visible_value: Variant = source.get("visible", false)
	if typeof(visible_value) != TYPE_BOOL or not bool(visible_value):
		return {"visible": false, "expanded": false, "render_valid": false, "body_complete": false}
	var expanded_value: Variant = source.get("expanded", false)
	var render_valid_value: Variant = source.get("render_valid", false)
	var expanded := typeof(expanded_value) == TYPE_BOOL and bool(expanded_value)
	var render_valid := typeof(render_valid_value) == TYPE_BOOL and bool(render_valid_value)
	var result := {"visible": true, "expanded": expanded, "render_valid": render_valid}
	var complete_value: Variant = source.get("body_complete", false)
	var typewriter_value: Variant = source.get("typewriter_active", true)
	var typewriter_valid := typeof(typewriter_value) == TYPE_BOOL
	var complete := render_valid and typeof(complete_value) == TYPE_BOOL and bool(complete_value) and typewriter_valid
	var typewriter := bool(typewriter_value) if typewriter_valid else true
	result["body_complete"] = complete
	result["typewriter_active"] = typewriter
	if not render_valid or not expanded:
		return result
	result["event_id"] = str(source.get("event_id", ""))
	if complete and not typewriter:
		result["summary"] = str(source.get("summary", ""))
	result["choice_ids"] = _string_array(source.get("choice_ids", []))
	return result


static func _inventory(source: Dictionary) -> Dictionary:
	var result := _scalars(source, [
		"available", "loading", "visible", "mode", "grid", "selected_item_id",
		"selected_item_source", "selected_key", "active_container_key", "container_id",
		"merchant_available", "shop_description",
	])
	result["items"] = _items(source.get("items", []))
	result["selected_item"] = _item(_dict(source.get("selected_item", {})))
	return result


static func _room_canvas(source: Dictionary) -> Dictionary:
	var result := _scalars(source, [
		"environment_id", "environment_name", "selected_object_id", "hovered_object_id",
		"outcome_message", "outcome_bankroll_delta", "outcome_suspicion_delta", "suspicion_level",
	])
	result["objects"] = _objects(source.get("objects", []))
	var selected := _dict(source.get("selected_info", {}))
	var public_selected := _scalars(selected, [
		"id", "object_id", "label", "title", "description", "object_type", "type", "enabled",
	])
	public_selected["actions"] = _actions(selected.get("actions", []))
	result["selected_info"] = public_selected
	return result


static func _game_canvas(source: Dictionary) -> Dictionary:
	var result := _scalars(source, [
		"game_id", "surface_renderer", "surface_life", "surface_cast", "selected_view_index",
		"outcome_message", "outcome_bankroll_delta", "outcome_suspicion_delta",
	])
	result["surface_hit_actions"] = _actions(source.get("surface_hit_actions", []))
	return result


static func _choices(value: Variant) -> Array:
	var result: Array = []
	for choice_value in _array(value):
		var choice := _dict(choice_value)
		if choice.is_empty():
			continue
		result.append(_scalars(choice, ["id", "label", "text", "enabled"]))
	return result


static func _objects(value: Variant) -> Array:
	var result: Array = []
	for object_value in _array(value):
		var object_data := _dict(object_value)
		if object_data.is_empty():
			continue
		var public_object := _scalars(object_data, [
			"id", "object_id", "semantic_id", "label", "title", "description", "object_type", "type",
			"enabled", "disabled", "disabled_reason", "visible", "interactive", "selected", "state",
		])
		public_object["actions"] = _actions(object_data.get("actions", []))
		result.append(public_object)
	return result


static func _actions(value: Variant) -> Array:
	var result: Array = []
	for action_value in _array(value):
		var action := _dict(action_value)
		if action.is_empty():
			continue
		var public_action := _scalars(action, [
			"id", "action", "action_id", "emit_object_id", "label", "kind",
			"enabled", "disabled", "disabled_reason", "selected", "index", "cost", "stake",
		])
		if action.has("rect"):
			public_action["rect"] = _rect(_dict(action.get("rect", {})))
		result.append(public_action)
	return result


static func _items(value: Variant) -> Array:
	var result: Array = []
	for item_value in _array(value):
		var public_item := _item(_dict(item_value))
		if not public_item.is_empty():
			result.append(public_item)
	return result


static func _item(source: Dictionary) -> Dictionary:
	return _scalars(source, [
		"id", "item_id", "display_name", "label", "description", "count", "quantity", "tier",
		"condition", "storage_source", "source", "selection_key", "active_selected", "enabled",
		"disabled_reason", "usable", "price", "sale_price", "action_label",
	])


static func _rect(source: Dictionary) -> Dictionary:
	return _scalars(source, ["x", "y", "w", "h"])


static func _scalars(source: Dictionary, keys: Array) -> Dictionary:
	var result: Dictionary = {}
	for key_value in keys:
		var key := str(key_value)
		if not source.has(key):
			continue
		var value: Variant = source.get(key)
		if typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]:
			result[key] = str(value) if typeof(value) == TYPE_STRING_NAME else value
	return result


static func _canonical(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var source := value as Dictionary
		var keys: Array = source.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var result: Dictionary = {}
		for key in keys:
			result[str(key)] = _canonical(source.get(key))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value as Array:
			result.append(_canonical(item))
		return result
	return value


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	for item in _array(value):
		var text := str(item).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result


static func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _is_true_bool(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL and bool(value)
