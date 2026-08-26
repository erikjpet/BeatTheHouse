class_name EnvironmentInteractionViewModel
extends RefCounted

const VisualStyle := preload("res://scripts/ui/visual_style.gd")
const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")
const CharacterRosterScript := preload("res://scripts/core/character_roster.gd")


static func snapshot_signature(run_state: RunState) -> String:
	if run_state == null:
		return ""
	var environment := run_state.current_environment
	return "|".join([
		str(environment.get("id", "")),
		str(environment.get("archetype_id", "")),
		str(environment.get("world_node_id", "")),
		str(environment.get("kind", "")),
		str(environment.get("display_name", "")),
		str(environment.get("game_ids", [])),
		str(environment.get("event_ids", [])),
		str(environment.get("item_offers", [])),
		str(environment.get("service_ids", [])),
		str(environment.get("lender_hooks", [])),
		str(environment.get("next_archetypes", [])),
		str(environment.get("travel_hooks", [])),
		str(environment.get("object_fixtures", [])),
		str(environment.get("current_layer_id", "")),
		str(environment.get("layer_discovery", {})),
		str(environment.get("layer_ambient_line", "")),
		str(environment.get("scenario_id", "")),
		str(environment.get("scenario_phase_index", 0)),
		str(environment.get("scenario_presentation", {})),
		str(environment.get("scenario_sequence_projection", {})),
		str(environment.get("scenario_render_snapshot", {})),
		str(environment.get("crew_presence", [])),
		str(environment.get("home_containers", [])),
		str(environment.get("cage_gift_shop_state", {})),
		str(environment.get("layout", {})),
		str(run_state.rourke_current_room),
		str(run_state.rourke_current_spot),
		str(run_state.rourke_facing),
		str(run_state.rourke_actions_until_move),
		str(run_state.rourke_off_floor_actions),
		str(run_state.linda_cage_state),
		str(run_state.grand_casino_room_heat_accumulators),
		str(run_state.rival_cheaters),
		str(run_state.rourke_escort_state),
		str(run_state.grand_casino_staffing),
		str(run_state.game_clock_minutes),
		str(run_state.closing_time_status()),
	])


static func environment_snapshot(run_state: RunState, data: Dictionary) -> Dictionary:
	if run_state == null:
		return {}
	# The room canvas is a read-only presentation surface. Machine state can
	# contain large masks/decks and is neither rendered nor mutated here.
	var snapshot := RunState.environment_context_snapshot(run_state.current_environment)
	var recent_result: Dictionary = data.get("recent_result", {})
	var recent_deltas: Dictionary = recent_result.get("deltas", {})
	snapshot["suspicion_level"] = run_state.suspicion_level()
	snapshot["drunk_level"] = run_state.drunk_level
	snapshot["drunk_time_scale"] = run_state.drunk_time_scale()
	snapshot["drunk_time_scale_percent"] = run_state.drunk_time_scale_percent()
	snapshot["drunk_world_speed_percent"] = run_state.drunk_time_scale_percent()
	snapshot["pending_drunk_absorption"] = run_state.pending_drunk_absorption_amount()
	snapshot["drunk_distortion_suppression_turns"] = run_state.drunk_distortion_suppression_turns
	snapshot["drunk_effect_mode"] = str(data.get("drunk_effect_mode", ""))
	snapshot["reduce_motion"] = bool(data.get("reduce_motion", false))
	snapshot["high_contrast"] = bool(data.get("high_contrast", false))
	snapshot["accessibility"] = data.get("accessibility", {})
	snapshot["alcoholic_level"] = run_state.alcoholic_level
	snapshot["baseline_luck"] = run_state.baseline_luck
	snapshot["luck_modifier"] = run_state.effective_luck()
	snapshot["alcohol_condition"] = run_state.alcohol_condition_label()
	snapshot["demo_objective"] = run_state.demo_objective_status()
	snapshot["pit_boss_watch"] = run_state.pit_boss_watch_status(run_state.current_environment)
	snapshot["grand_casino_living_floor"] = run_state.grand_casino_living_floor_snapshot(run_state.current_environment)
	snapshot["linda_cage"] = run_state.linda_cage_snapshot()
	snapshot["grand_casino_staffing"] = run_state.grand_casino_staffing_snapshot(run_state.current_environment)
	snapshot["grand_casino_entry_cue"] = run_state.pending_grand_casino_entry_cue()
	snapshot["travel_choices"] = data.get("travel_choices", [])
	snapshot["selected_travel_target_id"] = str(data.get("selected_travel_target_id", ""))
	snapshot["selected_travel_label"] = str(data.get("selected_travel_label", ""))
	snapshot["event_cadence"] = run_state.event_cadence_summary()
	snapshot["game_clock_minutes"] = run_state.game_clock_minutes
	snapshot["game_day"] = run_state.game_day()
	snapshot["clock_text"] = run_state.clock_display_text()
	snapshot["venue_open_status"] = data.get("venue_open_status", {})
	snapshot["venue_open_status_text"] = str(data.get("venue_open_status_text", ""))
	snapshot["closing_time_state"] = run_state.closing_time_status()
	snapshot["home_state"] = run_state.home_state.duplicate(true)
	snapshot["home_status_summary"] = run_state.home_status_summary()
	snapshot["world_map_overlay_visible"] = bool(data.get("world_map_overlay_visible", false))
	snapshot["world_map"] = data.get("world_map", {}) if bool(snapshot["world_map_overlay_visible"]) else {}
	snapshot["event_options"] = data.get("event_options", [])
	snapshot["selected_event_id"] = str(data.get("selected_event_id", ""))
	snapshot["selected_event_choice_id"] = str(data.get("selected_event_choice_id", ""))
	snapshot["selected_event_label"] = str(data.get("selected_event_label", ""))
	snapshot["selected_event_choice_label"] = str(data.get("selected_event_choice_label", ""))
	snapshot["item_offers"] = data.get("item_offers", [])
	snapshot["inventory_items"] = data.get("inventory_items", [])
	snapshot["shopkeeper_available"] = bool(data.get("shopkeeper_available", false))
	snapshot["selected_item_offer_id"] = str(data.get("selected_item_offer_id", ""))
	snapshot["selected_item_offer_label"] = str(data.get("selected_item_offer_label", ""))
	snapshot["selected_item_offer_price"] = int(data.get("selected_item_offer_price", 0))
	snapshot["last_item_result"] = _copy_dict(data.get("last_item_result", {}))
	snapshot["service_options"] = data.get("service_options", [])
	snapshot["lender_options"] = data.get("lender_options", [])
	snapshot["selected_service_hook_id"] = str(data.get("selected_service_hook_id", ""))
	snapshot["selected_service_hook_label"] = str(data.get("selected_service_hook_label", ""))
	snapshot["selected_lender_hook_id"] = str(data.get("selected_lender_hook_id", ""))
	snapshot["selected_lender_hook_label"] = str(data.get("selected_lender_hook_label", ""))
	snapshot["last_hook_result"] = _copy_dict(data.get("last_hook_result", {}))
	snapshot["interactable_objects"] = data.get("interactable_objects", [])
	snapshot["recent_result"] = recent_result
	snapshot["outcome_object_id"] = str(data.get("outcome_object_id", ""))
	snapshot["outcome_message"] = str(data.get("outcome_message", ""))
	snapshot["outcome_bankroll_delta"] = int(recent_result.get("bankroll_delta", recent_deltas.get("bankroll_delta", 0)))
	snapshot["outcome_suspicion_delta"] = int(recent_result.get("suspicion_delta", recent_deltas.get("suspicion_delta", 0)))
	return snapshot


static func interactable_object_view_list(run_state: RunState, library: ContentLibrary, data: Dictionary) -> Array:
	if run_state == null or library == null:
		return []
	var objects: Array = []
	var failed := bool(data.get("run_failed_without_recovery", false))
	var failed_reason := str(data.get("failed_reason", "Run failed."))
	var selection: Dictionary = data.get("selection", {})
	var layout: Dictionary = data.get("layout", {})
	var game_fixture_counts := _copy_dict(layout.get("game_fixture_counts", {}))
	var risk_cue := str(data.get("risk_cue", ""))
	var game_layout_index := 0
	for source_value in data.get("game_sources", []):
		if typeof(source_value) != TYPE_DICTIONARY:
			continue
		var game_source: Dictionary = source_value
		var game_id := str(game_source.get("id", ""))
		var definition: Dictionary = game_source.get("definition", {})
		var runtime_state := _copy_dict(game_source.get("runtime_state", {}))
		var object_state := _copy_dict(game_source.get("object_state", {}))
		var fixture_object_states := _copy_dict(game_source.get("fixture_object_states", {}))
		for runtime_key in _copy_dict(object_state.get("runtime_state", {})).keys():
			runtime_state[runtime_key] = (object_state.get("runtime_state", {}) as Dictionary)[runtime_key]
		var enabled := not definition.is_empty() and not failed
		var fixture_count := maxi(1, int(game_fixture_counts.get(game_id, 1)))
		for fixture_index in range(fixture_count):
			var object_id := "game:%s" % game_id if fixture_index == 0 else "game:%s:%d" % [game_id, fixture_index + 1]
			var fixture_object_state := _copy_dict(fixture_object_states.get(object_id, object_state))
			var fixture_runtime_state := runtime_state.duplicate(true)
			for runtime_key in _copy_dict(fixture_object_state.get("runtime_state", {})).keys():
				fixture_runtime_state[runtime_key] = (fixture_object_state.get("runtime_state", {}) as Dictionary)[runtime_key]
			var description := str(definition.get("description", ""))
			if description.is_empty():
				description = str(definition.get("intro", "Choose a stake on the surface, then click an action."))
			var runtime_status := str(fixture_runtime_state.get("status_label", "")).strip_edges()
			if not runtime_status.is_empty():
				description = "%s Status: %s." % [description, runtime_status]
			var label := str(definition.get("display_name", _label_from_id(game_id)))
			if fixture_count > 1:
				label = "%s %d" % [label, fixture_index + 1]
			objects.append(_object_with_rect({
				"object_id": object_id,
				"object_type": "game",
				"source_id": game_id,
				"label": label,
				"short_description": description,
				"presence": "fixture",
				"enabled": enabled,
				"disabled_reason": "" if enabled else failed_reason if failed else "Game definition is missing.",
				"action_summary": "Double-click this machine to enter." if enabled else "This game is unavailable.",
				"status_summary": str(fixture_object_state.get("status_summary", "")),
				"effect_summary": str(fixture_object_state.get("effect_summary", "")),
				"impact_summary": str(fixture_object_state.get("impact_summary", "")),
				"state_badge": str(fixture_object_state.get("state_badge", "")),
				"risk_summary": risk_cue,
				"runtime_state": fixture_runtime_state,
				"visual_state": _copy_dict(fixture_object_state.get("visual_state", {})),
				"visual_key": str(definition.get("family", definition.get("type", "game"))),
				"prop": str(definition.get("environment_prop", definition.get("prop", "card_table"))),
				"icon_key": str(definition.get("icon_key", game_id)),
				"asset_path": str(definition.get("asset_path", "")),
				"available_actions": [{"id": "enter_game", "label": "Double-click to enter"}] if enabled else [],
				"confirm_action_id": "enter_game" if enabled else "",
			}, selection, layout, game_layout_index))
			game_layout_index += 1
	var event_index := 0
	for event_value in data.get("event_options", []):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event_data: Dictionary = event_value
		var event_id := str(event_data.get("id", ""))
		if event_id.is_empty():
			continue
		var choices: Array = event_data.get("choices", [])
		var enabled := not choices.is_empty() and not failed
		var object_id := "event:%s" % event_id
		var event_speaker: Dictionary = event_data.get("speaker", {}) if typeof(event_data.get("speaker", {})) == TYPE_DICTIONARY else {}
		var character_actor := event_speaker if str(event_data.get("presentation", "")) == "talk" and bool(event_speaker.get("environment_actor", true)) and not event_speaker.is_empty() else {}
		objects.append(_object_with_rect({
			"object_id": object_id,
			"object_type": "event",
			"visual_type": "character" if not character_actor.is_empty() else "event",
			"source_id": event_id,
			"label": str(event_data.get("display_name", _label_from_id(event_id))),
			"short_description": str(event_data.get("summary", "Something is happening here.")),
			"identity_summary": character_identity_summary(character_actor),
			"presence": "dynamic",
			"enabled": enabled,
			"disabled_reason": "" if enabled else failed_reason if failed else "No event choice is currently available.",
			"action_summary": str(event_data.get("start_summary", "Choose a response.")) if enabled else "No response is available right now.",
			"classification_summary": str(event_data.get("discovery_summary", "New lead")),
			"choice_summary": str(_call(data.get("event_choice_summary", Callable()), [choices], "")),
			"attribute_badges": AttributeBadgesScript.for_event_choice({"event_type": str(event_data.get("presentation_class", event_data.get("type", "")))}),
			"visual_key": str(event_data.get("visual_key", event_data.get("type", "event"))),
			"prop": str(event_data.get("environment_prop", event_data.get("prop", ""))),
			"icon_key": str(event_data.get("icon_key", event_id)),
			"asset_path": str(event_data.get("asset_path", "")),
			"character_actor": character_actor,
			"unique_object_class": str(event_data.get("unique_object_class", "")).strip_edges(),
			"unique_object_priority": int(event_data.get("unique_object_priority", 0)),
			"allow_duplicate_unique_class": bool(event_data.get("allow_duplicate_unique_class", false)),
			"available_actions": [{"id": "inspect_event_choices", "label": "Review responses"}] if enabled else [],
			"inline_actions": _call(data.get("event_inline_actions", Callable()), [event_id, choices], []) if enabled else [],
			"confirm_action_id": "inspect_event_choices" if enabled else "",
		}, selection, layout, event_index))
		event_index += 1
	var item_index := 0
	for offer_value in data.get("item_offers", []):
		if typeof(offer_value) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = offer_value
		var item_id := str(offer.get("id", ""))
		if item_id.is_empty():
			continue
		var enabled := bool(offer.get("affordable", true)) and not failed
		var object_id := str(offer.get("object_id", "item:%s" % item_id))
		var action_label := "Pickup" if bool(offer.get("pickup", false)) else str(offer.get("action_label", "Buy"))
		var price := maxi(0, int(offer.get("price", 0)))
		var currency := str(offer.get("currency", "cash"))
		var cost_summary := "Pickup"
		if not bool(offer.get("pickup", false)):
			cost_summary = "Cost: $%d · Bankroll after: $%d" % [price, maxi(0, run_state.bankroll - price)]
		if not bool(offer.get("pickup", false)) and currency == "chips":
			cost_summary = "Cost: %d chips · Chips after: %d" % [price, maxi(0, run_state.grand_casino_chips - price)]
		var layout_index := int(offer.get("layout_index", item_index))
		objects.append(_object_with_rect({
			"object_id": object_id,
			"object_type": "item",
			"source_id": item_id,
			"label": str(offer.get("display_name", _label_from_id(item_id))),
			"short_description": str(offer.get("description", "")),
			"presence": "dynamic",
			"enabled": enabled,
			"disabled_reason": "" if enabled else failed_reason if failed else str(offer.get("disabled_reason", "Not enough chips." if currency == "chips" else "Not enough bankroll.")),
			"action_summary": "" if enabled else "Needs more chips before it can be bought." if currency == "chips" else "Needs more bankroll before it can be used.",
			"effect_summary": str(offer.get("effect_summary", "")),
			"addition_count": maxi(0, int(offer.get("addition_count", 0))),
			"impact_summary": str(offer.get("purpose_summary", "")).strip_edges(),
			"cost_summary": cost_summary,
			"currency": currency,
			"price": price,
			"attribute_badges": _copy_array(offer.get("attribute_badges", [])),
			"visual_key": "item",
			"prop": str(offer.get("environment_prop", "")),
			"surface": str(offer.get("surface", "counter")),
			"icon_key": str(offer.get("icon_key", item_id)),
			"asset_path": str(offer.get("asset_path", "")),
			"available_actions": [{"id": "buy_item", "label": action_label}] if enabled else [],
			"confirm_action_id": "buy_item" if enabled else "",
		}, selection, layout, layout_index))
		item_index += 1
	if bool(data.get("shopkeeper_should_draw", false)):
		var enabled := bool(data.get("shopkeeper_available", false)) and not failed
		var disabled_reason := "" if enabled else failed_reason if failed else "The counter is quiet right now."
		var shopkeeper_speaker := {
			"role": "staff",
			"name": str(data.get("shopkeeper_label", "Shopkeeper")),
			"character_id": "sal_pawn_broker" if str(run_state.current_environment.get("archetype_id", "")) == "pawn_shop" else "",
			"character_pool_id": "" if str(run_state.current_environment.get("archetype_id", "")) == "pawn_shop" else "shop_staff",
			"character_identity_key": str(run_state.current_environment.get("id", run_state.current_environment.get("archetype_id", "merchant"))),
			"voice_line_key": "shop_greeting",
		}
		var shopkeeper_actor := CharacterRosterScript.resolve_speaker(
			shopkeeper_speaker,
			library,
			run_state,
			str(shopkeeper_speaker.get("character_identity_key", "merchant")),
			"shop_greeting"
		)
		var shopkeeper_name := str(shopkeeper_actor.get("speaking_character_name", data.get("shopkeeper_label", "Shopkeeper")))
		objects.append(_object_with_rect({
			"object_id": "shopkeeper:merchant",
			"object_type": "shopkeeper",
			"visual_type": "character",
			"source_id": "merchant",
			"label": shopkeeper_name,
			"short_description": str(data.get("shop_description", "")),
			"identity_summary": character_identity_summary(shopkeeper_actor),
			"presence": "fixture",
			"interactive": enabled,
			"enabled": enabled,
			"disabled_reason": disabled_reason,
			"action_summary": "Double-click to sell gear." if enabled else disabled_reason,
			"effect_summary": "Merchant sales.",
			"visual_key": "shopkeeper",
			"icon_key": "service",
			"character_actor": shopkeeper_actor,
			"available_actions": [{"id": "talk_shopkeeper", "label": "Talk"}] if enabled else [],
			"confirm_action_id": "talk_shopkeeper" if enabled else "",
		}, selection, layout, 0))
	objects.append_array(data.get("before_travel_objects", []))
	var travel_choices: Array = data.get("travel_choices", [])
	if not travel_choices.is_empty():
		var first_choice: Dictionary = travel_choices[0] if typeof(travel_choices[0]) == TYPE_DICTIONARY else {}
		var direct_room_exit: Dictionary = data.get("direct_room_exit", {})
		if not direct_room_exit.is_empty():
			first_choice = direct_room_exit
		var any_enabled := false
		for choice_value in travel_choices:
			if typeof(choice_value) == TYPE_DICTIONARY and bool((choice_value as Dictionary).get("enabled", true)):
				any_enabled = true
				break
		var enabled := not failed
		var direct := not direct_room_exit.is_empty()
		objects.append(_object_with_rect({
			"object_id": "travel:leave",
			"object_type": "travel",
			"source_id": "leave",
			"label": str(direct_room_exit.get("label", "Lobby")) if direct else "Leave",
			"short_description": "Enter motel lobby." if direct else "Open city map.",
			"enabled": enabled,
			"disabled_reason": failed_reason if failed else "",
			"action_summary": "Enter lobby." if direct else "Open map." if any_enabled else "Inspect locked routes.",
			"risk_summary": str(_call(data.get("travel_risk_summary", Callable()), [first_choice], "")),
			"impact_summary": str(_call(data.get("travel_preview_summary", Callable()), [first_choice], "")),
			"cost_summary": "%d route(s)" % travel_choices.size(),
			"attribute_badges": _copy_array(first_choice.get("attribute_badges", [])),
			"preview_lines": travel_leave_preview_lines(travel_choices, direct_room_exit),
			"unlock_conditions": [],
			"visual_key": "travel",
			"prop": "door",
			"icon_key": "travel",
			"available_actions": [{"id": "enter_lobby", "label": "Enter Lobby"}] if direct and enabled else [{"id": "open_map", "label": "Open Map"}] if enabled else [],
			"confirm_action_id": "enter_lobby" if direct and enabled else "open_map" if enabled else "",
		}, selection, layout, 0))
	objects.append_array(data.get("after_travel_objects", []))
	if bool(data.get("closing_time_locked", false)):
		objects = objects_with_closing_time_lock(objects, str(data.get("closing_time_reason", "")))
	return filter_unique_objects(objects)


static func filter_unique_objects(objects: Array) -> Array:
	var result: Array = []
	var class_indexes: Dictionary = {}
	for object_value in objects:
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		var unique_class := str(object_data.get("unique_object_class", "")).strip_edges()
		if unique_class.is_empty() or bool(object_data.get("allow_duplicate_unique_class", false)):
			result.append(object_data)
			continue
		if not class_indexes.has(unique_class):
			class_indexes[unique_class] = result.size()
			result.append(object_data)
			continue
		var existing_index := int(class_indexes[unique_class])
		var existing: Dictionary = result[existing_index]
		result[existing_index] = merge_unique_object(existing, object_data)
	return result


static func merge_unique_object(existing: Dictionary, incoming: Dictionary) -> Dictionary:
	var existing_priority := int(existing.get("unique_object_priority", 0))
	var incoming_priority := int(incoming.get("unique_object_priority", 0))
	var primary := incoming.duplicate(true) if incoming_priority > existing_priority else existing.duplicate(true)
	var secondary := existing if incoming_priority > existing_priority else incoming
	primary["available_actions"] = _merged_actions(_copy_array(primary.get("available_actions", [])), _copy_array(secondary.get("available_actions", [])))
	primary["action_summary"] = _joined_summary_lines([existing.get("action_summary", ""), incoming.get("action_summary", "")])
	primary["effect_summary"] = _joined_summary_lines([existing.get("effect_summary", ""), incoming.get("effect_summary", "")])
	primary["status_summary"] = _joined_summary_lines([existing.get("status_summary", ""), incoming.get("status_summary", "")])
	primary["risk_summary"] = _joined_summary_lines([existing.get("risk_summary", ""), incoming.get("risk_summary", "")])
	if str(primary.get("label", "")).strip_edges().is_empty():
		primary["label"] = str(secondary.get("label", ""))
	if str(primary.get("short_description", "")).strip_edges().is_empty():
		primary["short_description"] = str(secondary.get("short_description", ""))
	return primary


static func _merged_actions(primary_actions: Array, secondary_actions: Array) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for source in [primary_actions, secondary_actions]:
		for action_value in source:
			if typeof(action_value) != TYPE_DICTIONARY:
				continue
			var action_data: Dictionary = (action_value as Dictionary).duplicate(true)
			var key := "%s|%s|%s|%s" % [
				str(action_data.get("object_type", "")),
				str(action_data.get("parent_id", "")),
				str(action_data.get("source_id", action_data.get("hook_id", ""))),
				str(action_data.get("id", "")),
			]
			if seen.has(key):
				continue
			seen[key] = true
			result.append(action_data)
	return result


static func _joined_summary_lines(values: Array) -> String:
	var lines: Array[String] = []
	for value in values:
		var text := str(value).strip_edges()
		if text.is_empty() or lines.has(text):
			continue
		lines.append(text)
	return " ".join(lines)


static func objects_with_closing_time_lock(objects: Array, disabled_reason: String) -> Array:
	var locked: Array = []
	for object_value in objects:
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = (object_value as Dictionary).duplicate(true)
		if str(object_data.get("object_type", "")) == "travel":
			locked.append(object_data)
			continue
		object_data["enabled"] = false
		object_data["interactive"] = bool(object_data.get("interactive", true))
		object_data["disabled_reason"] = disabled_reason
		object_data["action_summary"] = "Open the map and leave."
		object_data["available_actions"] = []
		object_data["confirm_action_id"] = ""
		locked.append(object_data)
	return locked


static func make_interactable_object(source: Dictionary, selection: Dictionary) -> Dictionary:
	var focus_rect := rect_from_dict(source.get("focus_rect", {}))
	var focus_point := focus_rect.position + focus_rect.size * 0.5
	var enabled := bool(source.get("enabled", true))
	var interactive := bool(source.get("interactive", true))
	var object_id := str(source.get("object_id", ""))
	return {
		"object_id": object_id,
		"object_type": str(source.get("object_type", "info")),
		"visual_type": str(source.get("visual_type", source.get("object_type", "info"))),
		"presence": str(source.get("presence", "dynamic")),
		"interactive": interactive,
		"decorative": not interactive,
		"source_id": str(source.get("source_id", "")),
		"parent_id": str(source.get("parent_id", "")),
		"owner_namespace": str(source.get("owner_namespace", "")),
		"stable_object_id": str(source.get("stable_object_id", "")),
		"scenario_owner_namespace": str(source.get("scenario_owner_namespace", "")),
		"scenario_stable_object_id": str(source.get("scenario_stable_object_id", "")),
		"scenario_command_id": str(source.get("scenario_command_id", "")),
		"label": str(source.get("label", "")),
		"short_description": str(source.get("short_description", "")),
		"identity_summary": str(source.get("identity_summary", "")),
		"enabled": enabled,
		"disabled_reason": str(source.get("disabled_reason", "")) if not enabled else "",
		"normalized_rect": rect_to_dict(focus_rect),
		"focus_rect": rect_to_dict(focus_rect),
		"focus_point": vector2_to_dict(focus_point),
		"action_summary": str(source.get("action_summary", "")),
		"status_summary": str(source.get("status_summary", "")),
		"effect_summary": str(source.get("effect_summary", "")),
		"impact_summary": str(source.get("impact_summary", "")),
		"choice_summary": str(source.get("choice_summary", "")),
		"risk_summary": str(source.get("risk_summary", "")),
		"classification_summary": str(source.get("classification_summary", "")),
		"addition_count": maxi(0, int(source.get("addition_count", 0))),
		"cost_summary": str(source.get("cost_summary", "")),
		"currency": str(source.get("currency", "")),
		"price": maxi(0, int(source.get("price", 0))),
		"attribute_badges": AttributeBadgesScript.for_object_overlay(_copy_array(source.get("attribute_badges", []))),
		"runtime_state": _copy_dict(source.get("runtime_state", {})),
		"visual_state": _copy_dict(source.get("visual_state", {})),
		"character_actor": _copy_dict(source.get("character_actor", {})),
		"state_badge": str(source.get("state_badge", "")),
		"non_color_state": str(source.get("non_color_state", "")),
		"safe_exit": bool(source.get("safe_exit", false)),
		"focus_order": maxi(0, int(source.get("focus_order", 0))),
		"role": str(source.get("role", "")),
		"state": str(source.get("state", "")),
		"appearance": str(source.get("appearance", "")),
		"pose": str(source.get("pose", "")),
		"behavior": str(source.get("behavior", "")),
		"route_id": str(source.get("route_id", "")),
		"z_order": int(source.get("z_order", 0)),
		"visible": bool(source.get("visible", true)),
		"visual_key": str(source.get("visual_key", "")),
		"prop": str(source.get("prop", "")),
		"surface": str(source.get("surface", "")),
		"icon_key": str(source.get("icon_key", "")),
		"asset_path": str(source.get("asset_path", "")),
		"unique_object_class": str(source.get("unique_object_class", "")).strip_edges(),
		"unique_object_priority": int(source.get("unique_object_priority", 0)),
		"allow_duplicate_unique_class": bool(source.get("allow_duplicate_unique_class", false)),
		"available_actions": _copy_array(source.get("available_actions", [])),
		"inline_actions": _copy_array(source.get("inline_actions", [])),
		"confirm_action_id": str(source.get("confirm_action_id", "")),
		"hovered": object_id == str(selection.get("hover_target_id", "")),
		"focused": object_id == str(selection.get("focus_target_id", "")),
		"selected": object_id == str(selection.get("selected_object_id", "")),
	}


static func character_identity_summary(speaker: Dictionary) -> String:
	var members: Array = speaker.get("members", []) if typeof(speaker.get("members", [])) == TYPE_ARRAY else []
	var identities: Array[String] = []
	for member_value in members:
		if typeof(member_value) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = member_value
		var display_name := str(member.get("display_name", "")).strip_edges()
		var title := str(member.get("title", "")).strip_edges()
		if not display_name.is_empty():
			identities.append("%s (%s)" % [display_name, title] if not title.is_empty() else display_name)
	if not identities.is_empty():
		return "Present: %s." % ", ".join(identities)
	if str(speaker.get("presentation", "")) == "faceless_silhouette":
		return "Identity concealed."
	var speaker_name := str(speaker.get("name", "")).strip_edges()
	return "Present: %s." % speaker_name if not speaker_name.is_empty() else ""


static func interaction_rect_for_object(object_id: String, object_type: String, index: int, layout: Dictionary) -> Rect2:
	var object_rects: Variant = layout.get("object_rects", {})
	if not object_id.is_empty() and typeof(object_rects) == TYPE_DICTIONARY and (object_rects as Dictionary).has(object_id):
		var generated := rect_from_dict((object_rects as Dictionary).get(object_id, {}))
		if generated.size.x > 0.0 and generated.size.y > 0.0:
			return generated
	var authored := authored_interaction_rect(object_type, index, layout)
	return authored if authored.size.x > 0.0 and authored.size.y > 0.0 else normalized_interaction_rect(object_type, index)


static func authored_interaction_rect(object_type: String, index: int, layout: Dictionary) -> Rect2:
	var field_name := layout_spot_field_name(object_type)
	var spots: Variant = layout.get(field_name, [])
	if field_name.is_empty() or typeof(spots) != TYPE_ARRAY or index < 0 or index >= (spots as Array).size():
		return Rect2()
	var spot := layout_spot_to_board_position((spots as Array)[index])
	if spot.x < 0.0 or spot.y < 0.0:
		return Rect2()
	var fallback_rect := normalized_interaction_rect(object_type, index)
	var board_size := Vector2(VisualStyle.ENVIRONMENT_BOARD_SIZE)
	var center := Vector2(clampf(spot.x / board_size.x, 0.0, 1.0), clampf(spot.y / board_size.y, 0.0, 1.0))
	return Rect2(center - fallback_rect.size * 0.5, fallback_rect.size)


static func layout_spot_field_name(object_type: String) -> String:
	match object_type:
		"game": return "game_spots"
		"event": return "event_spots"
		"item": return "item_spots"
		"shopkeeper": return "shopkeeper_spots"
		"game_hook", "dialogue": return "game_hook_spots"
		"travel": return "travel_spots"
		"service": return "service_spots"
		"lender": return "lender_spots"
		"home_tenure": return "home_tenure_spots"
		"home_sleep": return "home_sleep_spots"
		"home_storage": return "home_storage_spots"
		"home_container": return "home_container_spots"
		"numbers": return "numbers_spots"
		"numbers_silas": return "numbers_silas_spots"
		"meta_bag": return "home_bag_spots"
		"meta_upgrade": return "home_upgrade_spots"
		"meta_trade_up": return "home_trade_up_spots"
		"meta_pawn_counter": return "pawn_counter_spots"
	return ""


static func layout_spot_to_board_position(value: Variant) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value as Vector2
	if typeof(value) == TYPE_VECTOR2I:
		var point := value as Vector2i
		return Vector2(float(point.x), float(point.y))
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float((value as Dictionary).get("x", -1.0)), float((value as Dictionary).get("y", -1.0)))
	return Vector2(-1.0, -1.0)


static func normalized_interaction_rect(object_type: String, index: int) -> Rect2:
	var board_size := Vector2(VisualStyle.ENVIRONMENT_BOARD_SIZE)
	var center := Vector2(0.5, 0.5)
	var size := Vector2(0.12, 0.18)
	match object_type:
		"game":
			center = Vector2(0.28 + float(index % 3) * 0.18, 0.56 + float(index / 3) * 0.13)
			size = Vector2(118.0 / board_size.x, 72.0 / board_size.y)
		"event":
			center = Vector2(0.68 + float(index % 2) * 0.12, 0.42 + float(index / 2) * 0.14)
			size = Vector2(100.0 / board_size.x, 64.0 / board_size.y)
		"item":
			center = Vector2(0.30 + float(index % 4) * 0.12, 0.76)
			size = Vector2(90.0 / board_size.x, 54.0 / board_size.y)
		"shopkeeper":
			center = Vector2(0.80, 0.34)
			size = Vector2(108.0 / board_size.x, 70.0 / board_size.y)
		"game_hook", "dialogue":
			center = Vector2(0.66 + float(index % 2) * 0.12, 0.76)
			size = Vector2(104.0 / board_size.x, 58.0 / board_size.y)
		"travel":
			center = Vector2(0.78, 0.64 + float(index) * 0.12)
			size = Vector2(118.0 / board_size.x, 64.0 / board_size.y)
		"service":
			center = Vector2(0.50 + float(index % 2) * 0.14, 0.76)
			size = Vector2(96.0 / board_size.x, 54.0 / board_size.y)
		"lender":
			center = Vector2(0.62 + float(index % 2) * 0.12, 0.72)
			size = Vector2(102.0 / board_size.x, 58.0 / board_size.y)
		"numbers", "numbers_silas":
			center = Vector2(0.42 + float(index % 2) * 0.24, 0.68)
			size = Vector2(106.0 / board_size.x, 62.0 / board_size.y)
		"delivery":
			var delivery_centers := [
				Vector2(0.72, 0.28), Vector2(0.84, 0.48),
				Vector2(0.68, 0.66), Vector2(0.42, 0.28),
				Vector2(0.30, 0.48), Vector2(0.46, 0.66),
				Vector2(0.82, 0.72), Vector2(0.20, 0.28),
			]
			center = delivery_centers[index % delivery_centers.size()]
			size = Vector2(100.0 / board_size.x, 70.0 / board_size.y)
		"home_tenure":
			center = Vector2(0.78, 0.46)
			size = Vector2(116.0 / board_size.x, 58.0 / board_size.y)
		"home_sleep":
			center = Vector2(0.50, 0.42)
			size = Vector2(150.0 / board_size.x, 74.0 / board_size.y)
		"home_storage":
			center = Vector2(0.20, 0.72)
			size = Vector2(108.0 / board_size.x, 58.0 / board_size.y)
		"home_container":
			center = Vector2(0.22 + float(index % 4) * 0.18, 0.76 + float(index / 4) * 0.11)
			size = Vector2(104.0 / board_size.x, 58.0 / board_size.y)
		"meta_bag":
			center = Vector2(0.42 + float(index % 3) * 0.12, 0.66 + float(index / 3) * 0.11)
			size = Vector2(90.0 / board_size.x, 54.0 / board_size.y)
		"meta_upgrade":
			center = Vector2(0.78, 0.34)
			size = Vector2(118.0 / board_size.x, 64.0 / board_size.y)
		"meta_trade_up":
			center = Vector2(0.62, 0.72)
			size = Vector2(118.0 / board_size.x, 64.0 / board_size.y)
		"meta_pawn_counter":
			center = Vector2(0.50, 0.48)
			size = Vector2(136.0 / board_size.x, 72.0 / board_size.y)
	return Rect2(center - size * 0.5, size)


static func travel_leave_preview_lines(travel_choices: Array, direct_room_exit: Dictionary) -> Array:
	var result: Array = []
	for choice_value in travel_choices.slice(0, 3):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		var label := str(choice.get("label", choice.get("id", "Route"))).strip_edges()
		if label.is_empty():
			continue
		if bool(choice.get("locked", false)):
			result.append("%s: %s" % [label, str(choice.get("disabled_reason", "locked"))])
		else:
			result.append("%s: %s, cost %d" % [label, str(choice.get("distance", "near")), int(choice.get("cost", 0))])
	for line_value in _copy_array(direct_room_exit.get("preview_lines", [])):
		var line := str(line_value).strip_edges()
		if not line.is_empty() and not result.has(line):
			result.append(line)
	return result


static func context_border_color(object_type: String, enabled: bool) -> Color:
	if not enabled:
		return VisualStyle.ORANGE
	match object_type:
		"game": return VisualStyle.CYAN
		"event": return VisualStyle.AMBER
		"item": return VisualStyle.TEAL
		"shopkeeper", "game_hook", "home_tenure", "meta_bag", "meta_upgrade", "meta_trade_up", "meta_pawn_counter", "service", "lender": return VisualStyle.YELLOW
		"dialogue": return VisualStyle.CYAN_2
		"home_sleep": return VisualStyle.CYAN
		"home_storage", "home_container": return VisualStyle.TEAL
		"travel": return VisualStyle.PURPLE_2
	return VisualStyle.CYAN_2


static func context_type_label(object_type: String) -> String:
	match object_type:
		"game": return "Game"
		"event": return "Event"
		"item": return "Item"
		"shopkeeper": return "Shopkeeper"
		"game_hook": return "Game Clerk"
		"dialogue": return "Talk"
		"home_tenure": return "Home"
		"home_sleep": return "Rest"
		"home_storage": return "Storage"
		"home_container": return "Container"
		"meta_bag": return "Bag"
		"meta_upgrade": return "Upgrade"
		"meta_trade_up": return "Trade-Up"
		"meta_pawn_counter": return "Pawn Shop"
		"travel": return "Travel"
		"service": return "Service"
		"lender": return "Lender"
	return "Info"


static func rect_to_dict(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}


static func rect_from_dict(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))), Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0))))


static func vector2_to_dict(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


static func vector2_from_dict(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var data: Dictionary = value
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))


static func _object_with_rect(source: Dictionary, selection: Dictionary, layout: Dictionary, index: int) -> Dictionary:
	var object_data := source.duplicate(false)
	object_data["focus_rect"] = interaction_rect_for_object(
		str(object_data.get("object_id", "")),
		str(object_data.get("object_type", "")),
		index,
		layout
	)
	return make_interactable_object(object_data, selection)


static func _call(callback_value: Variant, args: Array, fallback: Variant) -> Variant:
	if typeof(callback_value) != TYPE_CALLABLE:
		return fallback
	var callback := callback_value as Callable
	return fallback if callback.is_null() else callback.callv(args)


static func _label_from_id(value: String) -> String:
	return value.replace("_", " ").capitalize()


static func _copy_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
