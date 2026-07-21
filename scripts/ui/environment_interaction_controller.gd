extends RefCounted


static func interactable_object_view_list(host: Variant) -> Array:
	if host.run_state == null or host.library == null:
		return []
	if host._is_meta_session():
		return host._meta_interactable_object_view_list()
	var failed = host._run_failed_without_recovery()
	var failed_reason = host._pressure_status_text(host._run_pressure_view())
	if failed_reason.strip_edges().is_empty():
		failed_reason = "Run failed."
	var game_sources: Array = []
	var game_ids = host._string_array(host.run_state.current_environment.get("game_ids", []))
	for index in range(game_ids.size()):
		var game_id := str(game_ids[index])
		game_sources.append({
			"id": game_id,
			"index": index,
			"definition": host.library.game(game_id),
			"runtime_state": host._environment_game_runtime_state(game_id),
			"object_state": host._environment_game_object_state(game_id),
		})
	var before_travel_objects: Array = []
	before_travel_objects.append_array(host._game_hook_interactable_objects())
	before_travel_objects.append_array(host._home_interactable_objects())
	before_travel_objects.append_array(casino_spatial_interactable_objects(host))
	var after_travel_objects: Array = []
	var room_return_object = host._parent_home_return_interactable_object()
	if not room_return_object.is_empty():
		after_travel_objects.append(room_return_object)
	after_travel_objects.append_array(host._hook_interactable_objects(host.CONTEXT_MODE_SERVICE, host._service_hook_view_list()))
	after_travel_objects.append_array(host._hook_interactable_objects(host.CONTEXT_MODE_LENDER, host._lender_hook_view_list()))
	var travel_choices = host._travel_choice_view_list()
	return host.EnvironmentInteractionViewModelScript.interactable_object_view_list(host.run_state, host.library, {
		"run_failed_without_recovery": failed,
		"failed_reason": failed_reason,
		"selection": {
			"hover_target_id": host.hover_target_id,
			"focus_target_id": host.focus_target_id,
			"selected_object_id": host.selected_object_id,
		},
		"layout": host._current_environment_layout(),
		"risk_cue": host._risk_cue_text(),
		"game_sources": game_sources,
		"event_options": host._eligible_event_option_view_list(),
		"event_choice_summary": Callable(host, "_event_choice_list_summary"),
		"event_inline_actions": Callable(host, "_event_inline_response_actions"),
		"item_offers": host._item_offer_view_list(),
		"shopkeeper_should_draw": host._shopkeeper_should_draw(),
		"shopkeeper_available": host._shopkeeper_available(),
		"shopkeeper_label": host._shopkeeper_label(),
		"shop_description": host._shop_description(),
		"before_travel_objects": before_travel_objects,
		"travel_choices": travel_choices,
		"direct_room_exit": host._local_parent_home_door_travel_choice(host._parent_home_parent_target_id()),
		"travel_risk_summary": Callable(host, "_travel_risk_summary"),
		"travel_preview_summary": Callable(host, "_travel_preview_summary"),
		"after_travel_objects": after_travel_objects,
		"closing_time_locked": host._closing_time_blocks_environment_actions(),
		"closing_time_reason": host._closing_time_disabled_reason(),
	})


static func game_hook_interactable_objects(host: Variant, apply_failure_lock: bool = true) -> Array:
	var objects: Array = []
	if host.run_state == null or host.library == null:
		return objects
	var run_failed_without_recovery = host._run_failed_without_recovery() if apply_failure_lock else false
	var failed_reason := ""
	if apply_failure_lock:
		failed_reason = host._pressure_status_text(host._run_pressure_view())
		if failed_reason.strip_edges().is_empty():
			failed_reason = "Run failed."
	var hook_index := 0
	for game_id in host._string_array(host.run_state.current_environment.get("game_ids", [])):
		var game = host._game_module_for_id(game_id)
		if game == null:
			continue
		for hook_value in game.environment_interactable_objects(host.run_state, host.run_state.current_environment):
			if typeof(hook_value) != TYPE_DICTIONARY:
				continue
			var hook: Dictionary = hook_value
			var hook_id := str(hook.get("id", hook.get("source_id", "")))
			if hook_id.is_empty():
				continue
			var dialogue_id := str(hook.get("dialogue_id", "")).strip_edges()
			var object_type = host.CONTEXT_MODE_DIALOGUE if not dialogue_id.is_empty() else host.CONTEXT_MODE_GAME_HOOK
			var object_id := str(hook.get("object_id", ""))
			if object_id.is_empty():
				object_id = "dialogue:%s" % dialogue_id if not dialogue_id.is_empty() else "game_hook:%s:%s" % [game_id, hook_id]
			var base_enabled := bool(hook.get("enabled", true))
			var enabled = base_enabled and not run_failed_without_recovery
			var disabled_reason := str(hook.get("disabled_reason", ""))
			if run_failed_without_recovery:
				disabled_reason = failed_reason
			objects.append(host._make_interactable_object({
				"object_id": object_id,
				"object_type": object_type,
				"visual_type": str(hook.get("visual_type", "service")),
				"source_id": dialogue_id if not dialogue_id.is_empty() else hook_id,
				"parent_id": game_id,
				"label": str(hook.get("label", host._label_from_id(hook_id))),
				"short_description": str(hook.get("short_description", "")),
				"enabled": enabled,
				"disabled_reason": disabled_reason if not enabled else "",
				"action_summary": str(hook.get("action_summary", "")),
				"effect_summary": str(hook.get("effect_summary", "")),
				"risk_summary": str(hook.get("risk_summary", "")),
				"cost_summary": str(hook.get("cost_summary", "")),
				"attribute_badges": host._copy_array(hook.get("attribute_badges", [])),
				"visual_key": str(hook.get("visual_key", "")),
				"icon_key": str(hook.get("icon_key", "service")),
				"unique_object_class": str(hook.get("unique_object_class", "")).strip_edges(),
				"unique_object_priority": int(hook.get("unique_object_priority", 0)),
				"allow_duplicate_unique_class": bool(hook.get("allow_duplicate_unique_class", false)),
				"available_actions": [{"id": "start_dialogue", "label": "Talk"}] if enabled and not dialogue_id.is_empty() else host._copy_array(hook.get("available_actions", [])) if enabled else [],
				"confirm_action_id": "start_dialogue" if enabled and not dialogue_id.is_empty() else str(hook.get("confirm_action_id", "")) if enabled else "",
				"focus_rect": host._interaction_rect_for_object(object_id, object_type, hook_index),
			}))
			hook_index += 1
	return objects


static func home_interactable_objects(host: Variant) -> Array:
	var objects: Array = []
	if host.run_state == null or host.library == null or not host.run_state.is_current_home_environment():
		return objects
	var tenure_status = host.run_state.home_tenure_status()
	var tenure_action = host.run_state.home_tenure_action_status()
	var tenure_available := bool(tenure_action.get("available", false))
	var tenure_enabled := tenure_available and bool(tenure_action.get("enabled", false))
	var tenure_label := str(tenure_action.get("label", "Home Status"))
	var tenure_description := str(tenure_status.get("summary", host.run_state.home_status_summary()))
	var tenure_actions := [{"id": "home_tenure_action", "label": tenure_label}] if tenure_available else []
	objects.append(host._make_interactable_object({
		"object_id": "home_tenure:status",
		"object_type": host.CONTEXT_MODE_HOME_TENURE,
		"visual_type": host.CONTEXT_MODE_HOME_TENURE,
		"source_id": "status",
		"label": tenure_label,
		"short_description": tenure_description,
		"presence": "fixture",
		"interactive": tenure_available,
		"enabled": tenure_enabled,
		"disabled_reason": "" if tenure_enabled else str(tenure_action.get("disabled_reason", "")),
		"action_summary": "Settle the home clock." if tenure_enabled else tenure_description,
		"status_summary": tenure_description,
		"cost_summary": "Cost: %d" % int(tenure_action.get("cost", 0)) if tenure_available else "",
		"visual_key": "home_tenure",
		"prop": "paper_note",
		"icon_key": "service",
		"available_actions": tenure_actions if tenure_enabled else [],
		"confirm_action_id": "home_tenure_action" if tenure_enabled else "",
		"focus_rect": host._interaction_rect_for_object("home_tenure:status", host.CONTEXT_MODE_HOME_TENURE, 0),
	}))
	objects.append(host._make_interactable_object({
		"object_id": "home_sleep:bed",
		"object_type": host.CONTEXT_MODE_HOME_SLEEP,
		"visual_type": host.CONTEXT_MODE_HOME_SLEEP,
		"source_id": "bed",
		"label": "Sleep",
		"short_description": "Sleep at home for four to eight hours.",
		"presence": "fixture",
		"interactive": true,
		"enabled": true,
		"action_summary": "Sleep until you wake naturally.",
		"status_summary": "Several hours pass.",
		"effect_summary": "Lowers heat and intoxication.",
		"visual_key": "home_sleep",
		"prop": "bed",
		"icon_key": "motel_room",
		"available_actions": [{"id": "home_sleep", "label": "Sleep"}],
		"confirm_action_id": "home_sleep",
		"focus_rect": host._interaction_rect_for_object("home_sleep:bed", host.CONTEXT_MODE_HOME_SLEEP, 0),
	}))
	var held_containers = host._held_container_item_options()
	var storage_enabled = not held_containers.is_empty()
	objects.append(host._make_interactable_object({
		"object_id": "home_storage:place",
		"object_type": host.CONTEXT_MODE_HOME_STORAGE,
		"visual_type": host.CONTEXT_MODE_HOME_STORAGE,
		"source_id": "place",
		"label": "Storage Spot",
		"short_description": "Place a carried container here for home storage.",
		"presence": "fixture",
		"interactive": true,
		"enabled": storage_enabled,
		"disabled_reason": "" if storage_enabled else "Carry a container first.",
		"action_summary": "Place a carried container." if storage_enabled else "No carried container to place.",
		"status_summary": "%d carried container(s)" % held_containers.size(),
		"visual_key": "home_storage",
		"prop": "crate",
		"icon_key": "service",
		"available_actions": [{"id": "place_home_container", "label": "Place"}] if storage_enabled else [],
		"confirm_action_id": "place_home_container" if storage_enabled else "",
		"focus_rect": host._interaction_rect_for_object("home_storage:place", host.CONTEXT_MODE_HOME_STORAGE, 0),
	}))
	var containers = host.run_state.current_home_containers()
	for index in range(containers.size()):
		if typeof(containers[index]) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = containers[index]
		var container_id := str(container.get("id", ""))
		var stored_items = host._string_array(container.get("items", []))
		var capacity := maxi(0, int(container.get("capacity", 0)))
		var object_id := "home_container:%s" % container_id
		objects.append(host._make_interactable_object({
			"object_id": object_id,
			"object_type": host.CONTEXT_MODE_HOME_CONTAINER,
			"visual_type": host.CONTEXT_MODE_HOME_CONTAINER,
			"source_id": container_id,
			"label": str(container.get("display_name", "Container")),
			"short_description": "Home storage. Stored items do not grant effects while stashed.",
			"presence": "fixture",
			"interactive": true,
			"enabled": true,
			"action_summary": "Move items in or out.",
			"status_summary": "%d/%d stored" % [stored_items.size(), capacity],
			"effect_summary": host._home_container_contents_summary(container),
			"visual_key": "home_container",
			"prop": "satchel",
			"icon_key": str(container.get("item_id", "service")),
			"available_actions": [{"id": "manage_home_container", "label": "Open"}],
			"confirm_action_id": "manage_home_container",
			"focus_rect": host._interaction_rect_for_object(object_id, host.CONTEXT_MODE_HOME_CONTAINER, index),
		}))
	return objects


static func hook_interactable_objects(host: Variant, object_type: String, options: Array) -> Array:
	var objects: Array = []
	var run_failed_without_recovery = host._run_failed_without_recovery()
	var failed_reason = host._pressure_status_text(host._run_pressure_view())
	if failed_reason.strip_edges().is_empty():
		failed_reason = "Run failed."
	for index in range(options.size()):
		if typeof(options[index]) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = options[index]
		var hook_id := str(option.get("id", ""))
		if hook_id.is_empty():
			continue
		var object_id := "%s:%s" % [object_type, hook_id]
		var presence := "fixture" if host._object_fixture_declared(object_id) else "dynamic"
		if bool(option.get("hidden", false)) and presence != "fixture":
			continue
		var supported := bool(option.get("mutation_supported", false))
		var enabled = bool(option.get("enabled", supported)) and not run_failed_without_recovery
		var disabled_reason = "" if enabled else failed_reason if run_failed_without_recovery else str(option.get("disabled_reason", option.get("status", "Display-only.")))
		var availability_class := str(option.get("availability_class", RunState.AVAILABILITY_AVAILABLE))
		var category := str(option.get("category", ""))
		var duration_minutes := maxi(0, int(option.get("duration_minutes", 0)))
		var duration_summary := "Takes 1 hour." if duration_minutes == 60 else "Takes %d minutes." % duration_minutes if duration_minutes > 0 else ""
		var visual_type := "drink" if object_type == host.CONTEXT_MODE_SERVICE and category == "alcohol" else object_type
		var icon_key := str(option.get("icon_key", visual_type)).strip_edges()
		if icon_key.is_empty():
			icon_key = visual_type
		objects.append(host._make_interactable_object({
			"object_id": object_id,
			"object_type": object_type,
			"visual_type": visual_type,
			"source_id": hook_id,
			"label": str(option.get("display_name", host._label_from_id(hook_id))),
			"short_description": str(option.get("summary", "")),
			"presence": presence,
			"interactive": enabled or availability_class == RunState.AVAILABILITY_TRANSIENT_BLOCKED,
			"enabled": enabled,
			"disabled_reason": disabled_reason,
			"action_summary": "Double-click to use." if enabled else "",
			"status_summary": duration_summary,
			"risk_summary": "",
			"cost_summary": "Cost: %d" % int(option.get("cost", 0)) if option.has("cost") else "",
			"effect_summary": str(option.get("delta_summary", "")),
			"attribute_badges": host._copy_array(option.get("attribute_badges", [])),
			"visual_key": visual_type,
			"prop": str(option.get("environment_prop", "")),
			"surface": str(option.get("surface", "")),
			"icon_key": icon_key,
			"asset_path": str(option.get("asset_path", "")),
			"available_actions": [{"id": "use_%s_hook" % object_type, "label": "Use"}] if enabled else [],
			"confirm_action_id": "use_%s_hook" % object_type if enabled else "",
			"focus_rect": host._interaction_rect_for_object(object_id, object_type, index),
		}))
	return objects


static func interactable_object(host: Variant, object_id: String) -> Dictionary:
	for object_data in host._interactable_object_view_list():
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("object_id", "")) == object_id:
			return (object_data as Dictionary).duplicate(true)
	if object_id == "travel:leave":
		return host._travel_leave_interactable_object()
	return {}


static func parent_home_return_interactable_object(host: Variant) -> Dictionary:
	var room_node_id = host._parent_home_node_id()
	if room_node_id.is_empty():
		return {}
	var choice = host._local_parent_home_door_travel_choice(room_node_id)
	if choice.is_empty():
		return {}
	return host._make_interactable_object({
		"object_id": "travel:%s" % room_node_id,
		"object_type": host.CONTEXT_MODE_TRAVEL,
		"source_id": room_node_id,
		"label": "Room Door",
		"short_description": "Return to your room.",
		"enabled": bool(choice.get("enabled", true)),
		"disabled_reason": str(choice.get("disabled_reason", "")),
		"action_summary": "Enter room.",
		"risk_summary": "",
		"impact_summary": "No fare. No street exposure.",
		"cost_summary": "Cost: 0",
		"attribute_badges": host._copy_array(choice.get("attribute_badges", [])),
		"preview_lines": host._copy_array(choice.get("preview_lines", [])),
		"unlock_conditions": [],
		"visual_key": "travel",
		"prop": "door",
		"icon_key": "travel",
		"available_actions": [{"id": "enter_room", "label": "Enter Room"}] if bool(choice.get("enabled", true)) else [],
		"confirm_action_id": "enter_room" if bool(choice.get("enabled", true)) else "",
		"focus_rect": host._interaction_rect_for_object("travel:%s" % room_node_id, host.CONTEXT_MODE_TRAVEL, 1),
	})


static func casino_spatial_interactable_objects(host: Variant) -> Array:
	var objects: Array = []
	if host.run_state == null or not host.run_state.is_grand_casino_environment():
		return objects
	var flags: Dictionary = host.run_state.current_environment.get("local_narrative_flags", {}) if typeof(host.run_state.current_environment.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	var fixture_index := 0
	for fixture_value in host._copy_array(flags.get("casino_fixtures", [])):
		if typeof(fixture_value) != TYPE_DICTIONARY:
			continue
		var fixture: Dictionary = fixture_value
		var fixture_id := str(fixture.get("id", "")).strip_edges()
		if fixture_id.is_empty():
			continue
		var object_id := "casino_fixture:%s" % fixture_id
		var object_data := {
			"object_id": object_id,
			"object_type": host.CONTEXT_MODE_CASINO_FIXTURE,
			"source_id": fixture_id,
			"label": str(fixture.get("label", host._label_from_id(fixture_id))),
			"short_description": str(fixture.get("description", "A Grand Casino fixture.")),
			"presence": "fixture",
			"interactive": true,
			"enabled": true,
			"action_summary": str(fixture.get("action_summary", "Inspect.")),
			"interaction_message": str(fixture.get("interaction_message", "The casino staff acknowledge you.")),
			"visual_key": str(fixture.get("visual_key", "casino_fixture")),
			"prop": str(fixture.get("prop", "counter")),
			"surface": str(fixture.get("surface", "counter_case")),
			"icon_key": str(fixture.get("icon_key", "service")),
			"available_actions": [{"id": "inspect_casino_fixture", "label": "Inspect"}],
			"confirm_action_id": "inspect_casino_fixture",
			"focus_rect": host._interaction_rect_for_object(object_id, host.CONTEXT_MODE_CASINO_FIXTURE, fixture_index),
		}
		if fixture_id == "cage_atm":
			object_data["inline_actions"] = host._cage_atm_inline_actions()
		objects.append(host._make_interactable_object(object_data))
		fixture_index += 1
	var door_index := 0
	for target_id_value in host._copy_array(flags.get("casino_room_targets", [])):
		var target_id := str(target_id_value).strip_edges()
		var choice := casino_room_door_travel_choice(host, target_id)
		if choice.is_empty():
			continue
		var object_id := "travel:%s" % target_id
		var enabled := bool(choice.get("enabled", true))
		objects.append(host._make_interactable_object({
			"object_id": object_id,
			"object_type": host.CONTEXT_MODE_TRAVEL,
			"source_id": target_id,
			"label": str(choice.get("label", host._label_from_id(target_id))),
			"short_description": str(choice.get("description", "An interior casino door.")),
			"presence": "fixture",
			"interactive": true,
			"enabled": enabled,
			"disabled_reason": str(choice.get("disabled_reason", "")),
			"action_summary": "Enter room." if enabled else str(choice.get("disabled_reason", "Locked.")),
			"cost_summary": "Cost: %d" % int(choice.get("cost", 0)),
			"attribute_badges": host._copy_array(choice.get("attribute_badges", [])),
			"preview_lines": host._copy_array(choice.get("preview_lines", [])),
			"unlock_conditions": host._copy_array(choice.get("unlock_conditions", [])),
			"visual_key": "travel",
			"prop": "door",
			"icon_key": "travel",
			"available_actions": [{"id": "enter_room", "label": "Enter Room"}] if enabled else [],
			"confirm_action_id": "enter_room" if enabled else "",
			"focus_rect": host._interaction_rect_for_object(object_id, host.CONTEXT_MODE_TRAVEL, door_index + 1),
		}))
		door_index += 1
	return objects


static func travel_leave_interactable_object(host: Variant) -> Dictionary:
	if host.run_state == null:
		return {}
	var travel_choices = host._travel_choice_view_list()
	if travel_choices.is_empty():
		return {}
	var first_choice: Dictionary = travel_choices[0] if typeof(travel_choices[0]) == TYPE_DICTIONARY else {}
	var direct_room_exit = host._local_parent_home_door_travel_choice(host._parent_home_parent_target_id())
	if not direct_room_exit.is_empty():
		first_choice = direct_room_exit
	var any_enabled := false
	for choice_value in travel_choices:
		if typeof(choice_value) == TYPE_DICTIONARY and bool((choice_value as Dictionary).get("enabled", true)):
			any_enabled = true
			break
	var travel_enabled = not host._run_failed_without_recovery()
	var preview_lines = host._travel_leave_preview_lines(travel_choices, direct_room_exit)
	var travel_label := str(direct_room_exit.get("label", "Lobby")) if not direct_room_exit.is_empty() else "Leave"
	var travel_description := "Enter motel lobby." if not direct_room_exit.is_empty() else "Open city map."
	var travel_action_summary := "Enter lobby." if not direct_room_exit.is_empty() else "Open map." if any_enabled else "Inspect locked routes."
	var travel_available_actions := [{"id": "enter_lobby", "label": "Enter Lobby"}] if not direct_room_exit.is_empty() and travel_enabled else [{"id": "open_map", "label": "Open Map"}] if travel_enabled else []
	var travel_confirm_action := "enter_lobby" if not direct_room_exit.is_empty() and travel_enabled else "open_map" if travel_enabled else ""
	return host._make_interactable_object({
		"object_id": "travel:leave",
		"object_type": host.CONTEXT_MODE_TRAVEL,
		"source_id": "leave",
		"label": travel_label,
		"short_description": travel_description,
		"enabled": travel_enabled,
		"disabled_reason": host._pressure_status_text(host._run_pressure_view()) if not travel_enabled else "",
		"action_summary": travel_action_summary,
		"risk_summary": host._travel_risk_summary(first_choice),
		"impact_summary": host._travel_preview_summary(first_choice),
		"cost_summary": "%d route(s)" % travel_choices.size(),
		"attribute_badges": host._copy_array(first_choice.get("attribute_badges", [])),
		"preview_lines": preview_lines,
		"unlock_conditions": [],
		"visual_key": "travel",
		"prop": "door",
		"icon_key": "travel",
		"available_actions": travel_available_actions,
		"confirm_action_id": travel_confirm_action,
		"focus_rect": host._interaction_rect_for_object("travel:leave", host.CONTEXT_MODE_TRAVEL, 0),
	})


static func local_parent_home_door_travel_choice(host: Variant, target_id: String) -> Dictionary:
	var casino_choice := casino_room_door_travel_choice(host, target_id)
	if not casino_choice.is_empty():
		return casino_choice
	var door_kind = host._local_parent_home_door_kind(target_id)
	if door_kind.is_empty():
		return {}
	if not host._travel_target_ids().has(target_id):
		return {}
	var route = host._world_route_for_target(target_id)
	if route.is_empty():
		route = host.library.route(target_id) if host.library != null else {}
	route["cost"] = 0
	route["base_cost"] = 0
	route["distance"] = "near"
	route["distance_blocks"] = 1
	route["risk"] = ""
	route["suspicion_delta"] = 0
	route["risk_decay"] = 0
	route["travel_method"] = "Door"
	var archetype = host._environment_archetype(target_id)
	var label = host._travel_label_from_archetype(archetype, target_id)
	var preview_line := "Step through the door into the lobby."
	if door_kind == "return":
		label = str(host.run_state.home_state.get("display_name", "Room"))
		preview_line = "Step through the door back into your room."
	elif label.is_empty() or label == target_id:
		label = "Lobby"
	var status = host.run_state.travel_route_status(route)
	if bool(status.get("hidden", false)):
		return {}
	return {
		"id": target_id,
		"label": label,
		"kind": str(archetype.get("kind", "")),
		"tier": int(archetype.get("tier", 1)),
		"description": "A local door between your room and the lobby.",
		"route": route.duplicate(true),
		"cost": 0,
		"risk": "",
		"suspicion_delta": 0,
		"distance": "near",
		"distance_blocks": 1,
		"risk_decay": 0,
		"travel_method": "Door",
		"risk_text": "",
		"risk_event": {},
		"attribute_badges": host.AttributeBadgesScript.for_route(route, {}),
		"unlock_conditions": host._copy_array(status.get("unlock_conditions", [])),
		"unlock_summary": str(status.get("unlock_summary", "")),
		"preview": {"level": "full", "lines": [preview_line]},
		"preview_level": "full",
		"preview_lines": [preview_line],
		"enabled": bool(status.get("available", true)),
		"disabled_reason": str(status.get("disabled_reason", "")),
		"local_door": true,
		"door_kind": door_kind,
	}


static func casino_room_door_travel_choice(host: Variant, target_id: String) -> Dictionary:
	if host.run_state == null or not host.run_state.is_grand_casino_environment():
		return {}
	var clean_target_id := target_id.strip_edges()
	var flags: Dictionary = host.run_state.current_environment.get("local_narrative_flags", {}) if typeof(host.run_state.current_environment.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	if not host._string_array(flags.get("casino_room_targets", [])).has(clean_target_id):
		return {}
	var archetype = host._environment_archetype(clean_target_id)
	if archetype.is_empty():
		return {}
	var travel_minutes := maxi(1, int(flags.get("casino_room_travel_minutes", 5)))
	var buy_in := maxi(0, int(flags.get("casino_high_limit_buy_in", 60)))
	var room_access: Dictionary = host.run_state.grand_casino_room_access_status(clean_target_id, buy_in)
	var requires_buy_in := bool(room_access.get("cash_buy_in_required", false))
	var locked_back_room := clean_target_id == RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID
	var route := {
		"id": clean_target_id,
		"destination_archetype": clean_target_id,
		"target_node_id": RunState.GRAND_CASINO_ARCHETYPE_ID,
		"cost": buy_in if requires_buy_in else 0,
		"base_cost": buy_in if requires_buy_in else 0,
		"distance": "near",
		"distance_blocks": 0,
		"risk": "",
		"suspicion_delta": 0,
		"risk_decay": 0,
		"travel_method": "Inside",
		"method": "Inside",
		"travel_minutes": travel_minutes,
		"local_casino_room": true,
	}
	var status = host.run_state.travel_route_status(route)
	var enabled := bool(status.get("available", true)) and bool(room_access.get("available", false))
	var disabled_reason := str(status.get("disabled_reason", room_access.get("reason", "")))
	var unlock_conditions: Array = []
	var preview_line := "Cross the Grand Casino interior in %d minutes." % travel_minutes
	if locked_back_room:
		enabled = false
		disabled_reason = "Locked. Rourke opens the Back Room only for a showdown."
		unlock_conditions = ["Rourke must take you there."]
		preview_line = "The Back Room door is visible, but Rourke controls the lock."
	elif requires_buy_in:
		unlock_conditions = ["Silver Players Card or a $%d cash buy-in." % buy_in]
		preview_line = "Pay the $%d cash buy-in, or enter later with Silver card access." % buy_in
		if not bool(room_access.get("available", false)):
			enabled = false
			disabled_reason = str(room_access.get("reason", "High-Limit requires Silver card access or a $%d cash buy-in." % buy_in))
	var label := str(archetype.get("display_name", "")).strip_edges()
	if label.is_empty():
		label = host._travel_label_from_archetype(archetype, clean_target_id)
	return {
		"id": clean_target_id,
		"label": label,
		"kind": str(archetype.get("kind", "boss")),
		"tier": int(archetype.get("tier", 3)),
		"description": str(archetype.get("room_description", "An interior Grand Casino room.")),
		"route": route.duplicate(true),
		"cost": int(route.get("cost", 0)),
		"risk": "",
		"suspicion_delta": 0,
		"distance": "near",
		"distance_blocks": 0,
		"risk_decay": 0,
		"travel_method": "Inside",
		"travel_minutes": travel_minutes,
		"local_door": true,
		"local_casino_room": true,
		"high_limit_buy_in": requires_buy_in,
		"attribute_badges": host.AttributeBadgesScript.for_route(route, {}),
		"unlock_conditions": unlock_conditions,
		"unlock_summary": "; ".join(unlock_conditions),
		"preview": {"level": "full", "lines": [preview_line]},
		"preview_level": "full",
		"preview_lines": [preview_line],
		"enabled": enabled,
		"disabled_reason": disabled_reason,
	}


static func local_parent_home_door_kind(host: Variant, target_id: String) -> String:
	if host.run_state == null or target_id.strip_edges().is_empty():
		return ""
	var room_node_id = host._parent_home_node_id()
	if room_node_id.is_empty():
		return ""
	var current_id = host._current_environment_archetype_id()
	var parent_id = host._parent_home_parent_target_id()
	if current_id == room_node_id and target_id == parent_id:
		return "exit"
	if current_id == parent_id and target_id == room_node_id:
		return "return"
	return ""


static func current_environment_archetype_id(host: Variant) -> String:
	if host.run_state == null:
		return ""
	return str(host.run_state.current_environment.get("world_node_id", host.run_state.current_environment.get("archetype_id", host.run_state.current_environment.get("id", "")))).strip_edges()


static func parent_home_node_id(host: Variant) -> String:
	if host.run_state == null or not host.run_state.home_is_active():
		return ""
	var home_id := str(host.run_state.home_state.get("home_archetype_id", "")).strip_edges()
	var home_archetype = host._environment_archetype(home_id)
	if str(home_archetype.get("parent_archetype", "")).strip_edges().is_empty():
		return ""
	var node_id := str(host.run_state.home_state.get("home_node_id", home_id)).strip_edges()
	return node_id if not node_id.is_empty() else home_id


static func parent_home_parent_target_id(host: Variant) -> String:
	if host.run_state == null:
		return ""
	var room_node_id = host._parent_home_node_id()
	if room_node_id.is_empty():
		return ""
	var room_archetype = host._environment_archetype(room_node_id)
	var parent_id := str(room_archetype.get("parent_archetype", "")).strip_edges()
	return parent_id
