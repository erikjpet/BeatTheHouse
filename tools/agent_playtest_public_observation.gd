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
		"run_status": str(hud.get("run_status", "")),
		"bankroll": int(hud.get("bankroll", 0)),
		"chips": int(hud.get("chips", 0)),
		"heat": int(hud.get("heat_level", 0)),
		"clock_minute": int(hud.get("clock_minute_of_day", 0)),
		"objective_state": str(hud.get("objective_state", "")),
		"objective_text": str(hud.get("objective_text", "")),
		"next_text": str(hud.get("next_text", "")),
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
		"run_status_changed": str(before.get("run_status", "")) != str(after.get("run_status", "")),
		"modal_changed": str(before.get("event_id", "")) != str(after.get("event_id", "")) \
			or str(before.get("talk_event_id", "")) != str(after.get("talk_event_id", "")),
		"economy_changed": int(before.get("bankroll", 0)) != int(after.get("bankroll", 0)) \
			or int(before.get("chips", 0)) != int(after.get("chips", 0)),
		"heat_changed": int(before.get("heat", 0)) != int(after.get("heat", 0)),
		"clock_changed": int(before.get("clock_minute", 0)) != int(after.get("clock_minute", 0)),
		"objective_changed": str(before.get("objective_state", "")) != str(after.get("objective_state", "")) \
			or str(before.get("objective_text", "")) != str(after.get("objective_text", "")),
	}


static func fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical(value)).sha256_text()


static func _screen(source: Dictionary) -> Dictionary:
	var result := _scalars(source, [
		"screen", "selected_category", "has_run", "has_game", "run_menu_visible",
		"run_journal_visible", "travel_transition_active", "travel_transition_target_id",
		"travel_transition_target_label", "world_map_overlay_visible", "world_map_title_text",
		"selected_world_map_node_id", "world_map_detail_text", "world_map_detail_popup_visible",
		"world_map_confirm_enabled",
	])
	result["start_menu"] = _start_menu(_dict(source.get("start_menu", {})))
	result["run_menu"] = _scalars(_dict(source.get("run_menu", {})), [
		"visible", "screen", "slot_id", "has_save", "status_text", "resume_disabled",
		"save_disabled", "load_disabled", "journal_disabled", "settings_disabled",
		"abandon_disabled", "main_menu_disabled",
	])
	result["overlay_state"] = _scalars(_dict(source.get("overlay_state", {})), [
		"screen", "event_choice_popup_visible", "event_choice_popup_type", "talk_dock_visible",
		"world_map_visible", "run_inventory_visible", "run_journal_visible", "run_menu_visible",
		"settings_visible", "travel_transition_active", "contract_valid",
	])
	result["world_map"] = _world_map(_dict(source.get("world_map", {})))
	result["run_report"] = _run_report(_dict(source.get("run_report", {})))
	return result


static func _start_menu(source: Dictionary) -> Dictionary:
	var result := _scalars(source, [
		"seed_text", "selected_home_type_id", "selected_challenge_id", "content_group_config_visible",
		"challenge_config_visible", "run_config_visible", "primary_action_text", "release_version_text",
	])
	result["selected_content_groups"] = _string_array(source.get("selected_content_groups", []))
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


static func _demo_objective(source: Dictionary) -> Dictionary:
	return _scalars(source, [
		"id", "active", "complete", "title", "summary", "authored_summary", "goal_text",
		"objective_state", "grand_casino_objective", "grand_casino_games_played",
		"grand_casino_net_winnings", "grand_casino_max_heat", "high_roller_ready",
		"high_roller_remaining_games", "high_roller_remaining_net_winnings",
		"players_card_tier", "players_card_tier_label", "players_card_next_tier",
		"players_card_next_tier_label", "players_card_next_min_games",
		"players_card_next_net_winnings", "players_card_next_max_heat",
		"players_card_segment_games", "players_card_segment_net_winnings",
		"players_card_segment_max_heat", "players_card_next_remaining_games",
		"players_card_next_remaining_net_winnings", "players_card_ready_to_claim",
		"players_card_can_claim", "players_card_eligible", "players_card_ineligible_reason",
		"players_card_claim_block_reason", "grand_casino_atm_debt", "showdown_pending",
		"showdown_active", "finale_pending",
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
	if bool(source.get("dealer_hole_visible", false)):
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
	var result := _scalars(source, [
		"bankroll", "suspicion_level", "run_status", "has_recent_consequence",
		"recent_bankroll_delta", "recent_suspicion_delta", "recent_result_message",
		"recent_result_text", "current_state_text", "inventory_summary", "debt_summary",
		"story_text", "travel_available", "travel_count", "travel_summary", "pressure_text",
		"suspicion_text", "alcohol_text",
	])
	result["story_messages"] = _string_array(source.get("story_messages", []))
	return result


static func _status_hud(source: Dictionary) -> Dictionary:
	var result := _scalars(source, [
		"bankroll", "bankroll_delta", "bankroll_text", "chips", "chips_delta", "show_chips",
		"heat_level", "heat_delta", "heat_text", "clock_day", "clock_minute_of_day",
		"clock_display", "clock_exact_display", "clock_text", "environment_text", "goal_text",
		"objective_state", "objective_text", "next_text", "run_status", "run_text", "save_text",
		"status_text", "inventory_text", "debt_text", "town_status_text", "home_text",
	])
	result["demo_objective"] = _demo_objective(_dict(source.get("demo_objective", {})))
	result["objective_guidance"] = _objective_guidance(_dict(source.get("objective_guidance", {})))
	result["next_objective"] = _scalars(_dict(source.get("next_objective", {})), [
		"enabled", "hint", "object_id", "object_type", "label",
	])
	return result


static func _objective_guidance(source: Dictionary) -> Dictionary:
	var result := _scalars(source, [
		"state", "text", "route", "clean_progress_close", "heat_pressure_close", "staff_attention",
	])
	result["next"] = _scalars(_dict(source.get("next", {})), ["enabled", "hint", "object_id", "object_type", "label"])
	return result


static func _feedback(source: Dictionary) -> Dictionary:
	return _scalars(source, [
		"visible", "title", "text", "message", "interaction_kind", "dismissible", "object_id",
		"bankroll_delta", "suspicion_delta",
	])


static func _event_popup(source: Dictionary) -> Dictionary:
	var result := _scalars(source, [
		"visible", "blocking", "popup_type", "interaction_kind", "dismissible", "event_id",
		"summary", "title", "source_id", "venue_id", "book_open",
	])
	result["choices"] = _choices(source.get("choices", []))
	result["choice_ids"] = _string_array(source.get("choice_ids", []))
	return result


static func _talk(source: Dictionary) -> Dictionary:
	var result := _scalars(source, [
		"visible", "expanded", "event_id", "speaker", "speaker_text", "summary", "topic",
		"voice_line", "choice_count", "queue_count", "typewriter_active", "urgency_bar_visible",
	])
	result["choice_ids"] = _string_array(source.get("choice_ids", []))
	var timing := _dict(source.get("timing", {}))
	result["timing"] = _scalars(timing, ["expires", "remaining_actions", "duration_actions"])
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
		result.append(_scalars(choice, [
			"id", "label", "text", "summary", "consequence_summary", "impact_summary", "enabled",
			"disabled", "disabled_reason", "selected", "dismissal", "requires_confirm",
		]))
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
			"id", "action", "action_id", "emit_object_id", "label", "text", "summary", "kind",
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
