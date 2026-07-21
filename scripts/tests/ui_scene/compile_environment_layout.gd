extends "res://scripts/tests/ui_scene/compile_components_and_main_flow.gd"

func _use_isolated_user_settings(path: String) -> void:
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, path)
	var isolated_settings: UserSettings = UserSettingsScript.new()
	isolated_settings.reset()
	var error := isolated_settings.save()
	if error != OK:
		push_error("Could not prepare isolated UI test settings.")
		quit(1)


func _check_meta_home_launcher_opens_room(app: Control) -> bool:
	var collections_button := app.get("collections_button") as Button
	if collections_button == null:
		push_error("Meta home launcher button was missing.")
		return false
	collections_button.emit_signal("pressed")
	await process_frame
	await process_frame
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		push_error("Home launcher did not enter a meta room session.")
		return false
	var environment: Dictionary = run_state.current_environment
	if not bool(environment.get("meta_session", false)) or str(environment.get("meta_location", "")) != "home":
		push_error("Home launcher opened the wrong environment instead of the meta home room: %s." % str(environment))
		return false
	var inventory_page := app.get("inventory_page") as Control
	if inventory_page != null and inventory_page.visible:
		push_error("Home launcher still opened the rejected collection menu page.")
		return false
	var canvas := app.get("environment_canvas") as Control
	var viewport_rect := app.get_viewport().get_visible_rect()
	if not _control_fits_viewport(canvas, viewport_rect, "meta home environment canvas"):
		return false
	var spatial: Dictionary = app.call("current_spatial_interaction_snapshot")
	var objects := _copy_array(spatial.get("objects", []))
	var container_id := ""
	var has_map_door := false
	var bag_prop_count := 0
	var item_prop_count := 0
	for object_value in objects:
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		var object_id := str(object_data.get("object_id", ""))
		if object_id.begins_with("meta_container:") and container_id.is_empty():
			container_id = object_id
		if object_id == "travel:leave":
			has_map_door = true
		if object_id.begins_with("meta_bag:"):
			bag_prop_count += 1
		if object_id.begins_with("meta_item:"):
			item_prop_count += 1
	if container_id.is_empty() or not has_map_door:
		push_error("Meta home room did not expose container and map-door props.")
		return false
	if bag_prop_count != 0 or item_prop_count != 0:
		push_error("Fresh meta home rendered phantom collection props: bags=%d items=%d." % [bag_prop_count, item_prop_count])
		return false
	var meta_hud: Dictionary = app.call("current_objective_hud_snapshot")
	if str(meta_hud.get("mode", "")) != "meta":
		push_error("Meta home did not switch the top bar to meta mode.")
		return false
	var hud_fields := _copy_array(meta_hud.get("fields", []))
	if hud_fields.size() != 2 or str(_copy_dict(hud_fields[0]).get("id", "")) != "gold" or str(_copy_dict(hud_fields[1]).get("id", "")) != "next_home_price":
		push_error("Meta top bar should expose only gold and next home price, got %s." % str(hud_fields))
		return false
	if int(meta_hud.get("gold", -1)) != 0 or str(meta_hud.get("next_home_label", "")) != "Motel Room" or int(meta_hud.get("next_home_price", 0)) != 60:
		push_error("Fresh meta top bar had wrong values: %s." % str(meta_hud))
		return false
	var top_inventory_button := app.get("top_inventory_button") as Button
	var active_item_button := app.get("active_item_button") as Button
	if top_inventory_button != null and top_inventory_button.visible:
		push_error("Meta top bar still showed the in-run inventory button.")
		return false
	if active_item_button != null and active_item_button.visible:
		push_error("Meta top bar still showed the in-run active item button.")
		return false
	var pre_meta_map_canvas := app.get("world_map_nodes_layer") as Control
	if pre_meta_map_canvas != null and pre_meta_map_canvas.has_method("set_map_snapshot"):
		pre_meta_map_canvas.call("set_map_snapshot", {})
	app.set("world_map_canvas_snapshot_key", "")
	app.set("world_map_snapshot_cache_key", "")
	if not bool(app.call("open_world_map", true)):
		push_error("Meta home could not open the shared world map.")
		return false
	await process_frame
	var meta_map_screen: Dictionary = app.call("current_screen_snapshot")
	if not bool(meta_map_screen.get("world_map_overlay_visible", false)):
		push_error("Meta world map overlay was not visible.")
		return false
	var meta_map_canvas := app.get("world_map_nodes_layer") as Control
	if meta_map_canvas == null or not meta_map_canvas.has_method("current_view_snapshot"):
		push_error("Meta world map did not expose the shared canvas.")
		return false
	var meta_map_view: Dictionary = meta_map_canvas.call("current_view_snapshot")
	var meta_map_bounds: Dictionary = meta_map_view.get("map_bounds", {}) if typeof(meta_map_view.get("map_bounds", {})) == TYPE_DICTIONARY else {}
	var meta_map_markers: Array = _copy_array(meta_map_view.get("icon_markers", []))
	var meta_home_marker := _map_icon_marker(meta_map_markers, "home")
	if meta_home_marker.is_empty():
		push_error("Meta world map did not draw the home icon marker.")
		return false
	var meta_home_icon := str(meta_home_marker.get("icon_path", ""))
	if meta_home_icon.strip_edges().is_empty() or not FileAccess.file_exists(meta_home_icon):
		push_error("Meta world map home marker used a missing icon path: %s." % meta_home_icon)
		return false
	var meta_pawn_marker := _map_icon_marker(meta_map_markers, "pawn_shop")
	if meta_pawn_marker.is_empty():
		push_error("Meta world map did not draw the pawn shop icon marker.")
		return false
	var meta_pawn_icon := str(meta_pawn_marker.get("icon_path", ""))
	if meta_pawn_icon != "res://assets/art/map_icons/pawn_shop.png" or not FileAccess.file_exists(meta_pawn_icon):
		push_error("Meta world map pawn shop marker used the wrong icon path: %s." % meta_pawn_icon)
		return false
	var meta_target_ids: Array = _copy_array(_copy_dict(meta_map_screen.get("world_map", {})).get("travel_target_ids", []))
	if meta_target_ids.is_empty():
		push_error("Meta world map did not expose a travel target.")
		return false
	var meta_target_id := str(meta_target_ids[0])
	if not bool(app.call("select_world_map_node", meta_target_id)):
		push_error("Meta world map rejected selecting %s." % meta_target_id)
		return false
	var immediate_meta_map_view: Dictionary = meta_map_canvas.call("current_view_snapshot")
	var immediate_meta_bounds: Dictionary = immediate_meta_map_view.get("map_bounds", {}) if typeof(immediate_meta_map_view.get("map_bounds", {})) == TYPE_DICTIONARY else {}
	var target_meta_bounds: Dictionary = immediate_meta_map_view.get("target_map_bounds", {}) if typeof(immediate_meta_map_view.get("target_map_bounds", {})) == TYPE_DICTIONARY else {}
	if not _map_bounds_equal(meta_map_bounds, immediate_meta_bounds):
		push_error("Selecting a meta world-map node snapped the view window instead of animating: before %s immediate %s." % [JSON.stringify(meta_map_bounds), JSON.stringify(immediate_meta_bounds)])
		return false
	if _map_bounds_equal(immediate_meta_bounds, target_meta_bounds) or not bool(immediate_meta_map_view.get("selected_focus_zoom_animating", false)):
		push_error("Selecting a meta world-map node did not expose an animated selected-location focus target.")
		return false
	for _layout_index in range(54):
		await process_frame
	var selected_meta_map_view: Dictionary = meta_map_canvas.call("current_view_snapshot")
	var selected_meta_bounds: Dictionary = selected_meta_map_view.get("map_bounds", {}) if typeof(selected_meta_map_view.get("map_bounds", {})) == TYPE_DICTIONARY else {}
	if not _map_bounds_equal(target_meta_bounds, selected_meta_bounds) or bool(selected_meta_map_view.get("selected_focus_zoom_animating", true)):
		push_error("Selecting a meta world-map node did not settle on the animated focus target: target %s after %s." % [JSON.stringify(target_meta_bounds), JSON.stringify(selected_meta_bounds)])
		return false
	if not _map_canvas_size_equal(meta_map_view, selected_meta_map_view):
		push_error("Selecting a meta world-map node changed the canvas size: before %s after %s." % [JSON.stringify(meta_map_view.get("canvas_size", {})), JSON.stringify(selected_meta_map_view.get("canvas_size", {}))])
		return false
	var selected_meta_screen: Dictionary = app.call("current_screen_snapshot")
	var selected_meta_detail := str(selected_meta_screen.get("world_map_detail_text", ""))
	if not selected_meta_detail.contains("Travel: Walk · Cost: $0") or not selected_meta_detail.contains("Distance: Near / 1 block"):
		push_error("Meta world-map detail omitted its travel method, distance, or cost: %s" % selected_meta_detail)
		return false
	var selected_meta_badges: Array = _copy_array(selected_meta_screen.get("world_map_detail_badges", []))
	if selected_meta_badges.size() != 2 or str(_copy_dict(selected_meta_badges[0]).get("glyph_id", "")) != "environment_shop" or str(_copy_dict(selected_meta_badges[1]).get("glyph_id", "")) != "suspicion":
		push_error("Meta pawn-shop detail should show only Shop and Heat icons: %s" % str(selected_meta_badges))
		return false
	app.call("close_world_map")
	await process_frame
	if not bool(app.call("activate_interactable_object", container_id)):
		push_error("Meta home container prop did not activate.")
		return false
	await process_frame
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if not bool(popup.get("visible", false)) or str(popup.get("popup_type", "")) != "meta_container":
		push_error("Meta home container did not open its contents popup.")
		return false
	var popup_rect := _snapshot_rect(popup.get("popup_rect", {}))
	var screen_rect := _snapshot_rect(popup.get("screen_rect", {}))
	if popup_rect.size.x <= 0.0 or popup_rect.size.y <= 0.0 or not screen_rect.grow(1.0).encloses(popup_rect):
		push_error("Meta home popup did not fit inside the viewport: popup=%s screen=%s." % [str(popup_rect), str(screen_rect)])
		return false
	app.call("_hide_event_choice_popup")
	await process_frame
	if not bool(app.call("open_world_map", true)):
		push_error("Meta home could not reopen the shared world map for pawn-shop travel.")
		return false
	await process_frame
	if not bool(app.call("select_world_map_node", meta_target_id)):
		push_error("Meta world map rejected selecting %s for travel." % meta_target_id)
		return false
	app.call("confirm_world_map_travel")
	await process_frame
	await process_frame
	run_state = app.get("run_state")
	if run_state == null:
		push_error("Meta world map travel cleared the meta session.")
		return false
	var pawn_environment: Dictionary = run_state.current_environment
	if str(pawn_environment.get("archetype_id", "")) != "pawn_shop" or str(pawn_environment.get("display_name", "")) != "Sal's Pawn Shop":
		push_error("Meta pawn travel did not open the custom pawn-shop room: %s." % str(pawn_environment))
		return false
	var pawn_spatial: Dictionary = app.call("current_spatial_interaction_snapshot")
	var pawn_objects := _copy_array(pawn_spatial.get("objects", []))
	if _object_by_id(pawn_objects, "meta_pawn_counter:sell").is_empty() or _object_by_id(pawn_objects, "meta_sal:talk").is_empty() or _object_by_id(pawn_objects, "travel:leave").is_empty():
		push_error("Custom pawn-shop room did not expose separate Sal, sell-counter, and map-door interactions.")
		return false
	var shelf_offer_ids: Array = []
	for offer_value in _copy_array(pawn_environment.get("item_offers", [])):
		shelf_offer_ids.append(str(_copy_dict(offer_value).get("id", "")))
	for slot_index in range(6):
		if _object_by_id(pawn_objects, "meta_sal_shelf:%d" % slot_index).is_empty() or not shelf_offer_ids.has("sal_shelf_%d" % slot_index):
			push_error("Custom pawn-shop room did not preserve stable shelf slot %d." % slot_index)
			return false
	var authored_shelf_points := [
		Vector2(120.0 / 900.0, 164.0 / 430.0),
		Vector2(186.0 / 900.0, 164.0 / 430.0),
		Vector2(720.0 / 900.0, 156.0 / 430.0),
		Vector2(786.0 / 900.0, 156.0 / 430.0),
		Vector2(110.0 / 900.0, 238.0 / 430.0),
		Vector2(794.0 / 900.0, 232.0 / 430.0),
	]
	for slot_index in range(authored_shelf_points.size()):
		var shelf_object := _object_by_id(pawn_objects, "meta_sal_shelf:%d" % slot_index)
		var focus_point := _copy_dict(shelf_object.get("focus_point", {}))
		var actual_point := Vector2(float(focus_point.get("x", -1.0)), float(focus_point.get("y", -1.0)))
		if actual_point.distance_to(authored_shelf_points[slot_index]) > 0.0001:
			push_error("Sal shelf slot %d moved off its authored item spot: expected %s got %s." % [slot_index, str(authored_shelf_points[slot_index]), str(actual_point)])
			return false
	var pawn_canvas := app.get("environment_canvas") as Control
	var pawn_canvas_view: Dictionary = pawn_canvas.call("current_view_snapshot")
	var pawn_layout := _copy_dict(pawn_canvas_view.get("object_layout", {}))
	if int(pawn_layout.get("overlap_count", -1)) != 0:
		push_error("Sal shelf fixtures overlap in the authored pawn-shop layout: %s." % JSON.stringify(pawn_layout.get("overlaps", [])))
		return false
	if _copy_array(pawn_environment.get("item_offers", [])).size() != 6:
		push_error("Custom pawn-shop room did not author exactly six physical shelf spots.")
		return false
	var meta_service: Variant = app.get("meta_collection_service")
	var starter := _copy_dict(meta_service.sal_shelf_row(0))
	var starter_item := _copy_dict(starter.get("item", {}))
	var starter_price := int(starter.get("asking_price", 0))
	meta_service.add_gold(starter_price)
	var starter_arm: Dictionary = meta_service.arm_sal_shelf_purchase(0)
	app.call("_confirm_meta_sal_purchase", str(starter_arm.get("token", "")))
	await process_frame
	run_state = app.get("run_state")
	var starter_entry: Dictionary = run_state.pending_talk_event("dialogue:sal_starter_offer")
	var starter_option := _copy_dict(app.call("_dialogue_option_for_entry", starter_entry))
	var pending_offer := _copy_dict(meta_service.pending_starter_buyback())
	var expected_float_text := str(pending_offer.get("rare_channel", "")).replace("_", " ").capitalize()
	if starter_entry.is_empty() or str(starter_option.get("summary", "")).find(expected_float_text) < 0 or str(starter_option.get("summary", "")).find(str(int(pending_offer.get("offer_price", 0)))) < 0:
		push_error("Starter purchase did not open persisted Sal dialogue naming the exact rare float and offer: %s" % str(starter_option))
		return false
	app.call("resolve_event_choice", "dialogue:sal_starter_offer", "sal_starter_keep")
	await process_frame
	if not meta_service.pending_starter_buyback().is_empty() or meta_service.owned_instances().filter(func(instance: Dictionary) -> bool: return int(instance.get("instance_id", 0)) == int(starter_item.get("instance_id", -1))).is_empty():
		push_error("Starter Keep dialogue did not retain the exact item and resolve the offer.")
		return false
	app.call("resolve_event_choice", "dialogue:sal_starter_kept", "move_on")
	await process_frame
	meta_service.generate_and_insert_sal_stock("ui-sal-normal-purchase")
	app.call("_apply_meta_environment", app.get("meta_session_location_id"))
	var normal := {}
	for row_value in meta_service.sal_shelf_rows():
		var candidate := _copy_dict(row_value)
		if bool(candidate.get("occupied", false)) and str(candidate.get("listing_mode", "")) == "normal":
			normal = candidate
			break
	var normal_price := int(normal.get("asking_price", 0))
	meta_service.add_gold(normal_price)
	var normal_arm: Dictionary = meta_service.arm_sal_shelf_purchase(int(normal.get("slot_index", -1)))
	app.call("_confirm_meta_sal_purchase", str(normal_arm.get("token", "")))
	await process_frame
	var normal_dialogue_open := not run_state.pending_talk_event("dialogue:sal_purchase_1").is_empty() or not run_state.pending_talk_event("dialogue:sal_purchase_2").is_empty()
	if not normal_dialogue_open:
		push_error("Committed ordinary Sal purchase did not open an authored purchase reaction.")
		return false
	var purchase_dialogue_id := "sal_purchase_1" if not run_state.pending_talk_event("dialogue:sal_purchase_1").is_empty() else "sal_purchase_2"
	app.call("resolve_event_choice", "dialogue:%s" % purchase_dialogue_id, "move_on")
	await process_frame
	var normal_instance_id := int(_copy_dict(normal.get("item", {})).get("instance_id", 0))
	var shelf_before_sale := JSON.stringify(meta_service.sal_shelf_rows())
	var sale_arm: Dictionary = meta_service.arm_sale("item", normal_instance_id)
	app.call("_confirm_meta_sale", str(sale_arm.get("token", "")))
	await process_frame
	var sale_dialogue_open := not run_state.pending_talk_event("dialogue:sal_sale_1").is_empty() or not run_state.pending_talk_event("dialogue:sal_sale_2").is_empty()
	if not sale_dialogue_open or JSON.stringify(meta_service.sal_shelf_rows()) != shelf_before_sale:
		push_error("Committed ordinary Sal sale did not trigger dialogue or changed resale stock.")
		return false
	meta_service.remove_instance(int(starter_item.get("instance_id", 0)))
	meta_service.save()
	app.call("return_to_main_menu")
	await process_frame
	if app.get("run_state") != null:
		push_error("Returning from the meta room did not clear the meta session.")
		return false
	var start_menu_controls := app.get("start_menu_controls") as Control
	if start_menu_controls == null or not start_menu_controls.visible:
		push_error("Returning from the meta room did not restore the main menu.")
		return false
	app.call("start_foundation_run", "UI-META-BAR-RUN-CHECK")
	await process_frame
	var run_hud: Dictionary = app.call("current_objective_hud_snapshot")
	if str(run_hud.get("mode", "")) == "meta" or not run_hud.has("bankroll") or not run_hud.has("heat"):
		push_error("In-run screen did not restore the standard top bar after leaving meta home.")
		return false
	app.call("return_to_main_menu")
	await process_frame
	return true


func _check_run_pawn_credit_is_immediate(app: Control) -> bool:
	app.call("start_foundation_run", "UI-PAWN-IMMEDIATE-CREDIT")
	await process_frame
	await process_frame
	var run_state := app.get("run_state") as RunState
	if run_state == null:
		push_error("Pawn immediate-credit check could not start a run.")
		return false
	run_state.bankroll = 100
	run_state.current_environment = {
		"id": "ui_pawn_credit_room",
		"display_name": "Sal's Pawn Shop",
		"kind": "shop",
		"tier": 2,
		"archetype_id": "pawn_shop",
		"service_ids": [],
		"lender_hooks": ["sals_pawn_counter"],
		"layout": {},
	}
	run_state.add_item("creased_luck_card")
	app.call("_refresh_run_action_service")
	var service := app.get("run_action_service") as RunActionService
	var quote: Dictionary = {}
	for quote_value in service.pawn_quote_options("sals_pawn_counter"):
		if typeof(quote_value) == TYPE_DICTIONARY and str((quote_value as Dictionary).get("item_id", "")) == "creased_luck_card":
			quote = (quote_value as Dictionary).duplicate(true)
			break
	var loan_amount := int(quote.get("loan_amount", 0))
	if loan_amount <= 0:
		push_error("Pawn immediate-credit check could not quote its collateral item.")
		return false
	# Reproduce the stale presentation state that previously survived the pawn
	# transaction until a later navigation sync.
	app.set("presented_bankroll_hold_active", true)
	app.set("presented_bankroll_value", run_state.bankroll)
	app.call("_pawn_counter_pawn_item", "sals_pawn_counter", "creased_luck_card")
	var expected_bankroll := 100 + loan_amount
	if run_state.bankroll != expected_bankroll:
		push_error("Pawn transaction did not credit the authoritative bankroll immediately: expected %d, got %d." % [expected_bankroll, run_state.bankroll])
		return false
	var hud: Dictionary = app.call("current_run_status_hud_snapshot")
	if int(hud.get("bankroll", -1)) != expected_bankroll or bool(app.get("presented_bankroll_hold_active")):
		push_error("Pawn transaction left the live bankroll presentation stale: %s." % str(hud))
		return false
	var pawn_model: Dictionary = app.call("_run_inventory_popup_model", "pawn_counter", "sals_pawn_counter")
	if str(pawn_model.get("summary", "")).find("Cash $%d" % expected_bankroll) == -1:
		push_error("Pawn popup did not show the immediately credited cash balance: %s." % str(pawn_model.get("summary", "")))
		return false
	app.call("return_to_main_menu")
	await process_frame
	return true


func _control_fits_viewport(control: Variant, viewport_rect, label: String) -> bool:
	if control == null or not (control is Control):
		push_error("%s was not available for viewport layout verification." % label)
		return false
	var rect := (control as Control).get_global_rect()
	var min_x := float(viewport_rect.position.x) - 1.0
	var min_y := float(viewport_rect.position.y) - 1.0
	var max_x := float(viewport_rect.position.x + viewport_rect.size.x) + 1.0
	var max_y := float(viewport_rect.position.y + viewport_rect.size.y) + 1.0
	if rect.position.x < min_x or rect.position.y < min_y or rect.end.x > max_x or rect.end.y > max_y:
		push_error("%s is clipped outside the visible viewport: %s within %s." % [label, str(rect), str(viewport_rect)])
		return false
	return true


func _control_rect_inside(inner: Control, outer: Control) -> bool:
	if inner == null or outer == null:
		return false
	var inner_rect := inner.get_global_rect()
	var outer_rect := outer.get_global_rect()
	return inner_rect.position.x >= outer_rect.position.x - 1.0 \
		and inner_rect.position.y >= outer_rect.position.y - 1.0 \
		and inner_rect.end.x <= outer_rect.end.x + 1.0 \
		and inner_rect.end.y <= outer_rect.end.y + 1.0


func _control_tree_has_scroll_container(node: Node) -> bool:
	if node == null:
		return false
	if node is CanvasItem and not (node as CanvasItem).visible:
		return false
	if node is ScrollContainer:
		return true
	for child in node.get_children():
		if _control_tree_has_scroll_container(child):
			return true
	return false


func _control_clips_contents(control: Variant, label: String) -> bool:
	if control == null or not (control is Control):
		push_error("%s was not available for clipping verification." % label)
		return false
	if not bool((control as Control).get("clip_contents")):
		push_error("%s does not clip its drawing to the assigned visual area." % label)
		return false
	return true


func _canvas_preserves_art_aspect(snapshot: Dictionary, label: String) -> bool:
	if not bool(snapshot.get("preserves_aspect_ratio", false)):
		push_error("%s does not report aspect-preserving art rendering." % label)
		return false
	var board_rect := _snapshot_rect(snapshot.get("board_rect", {}))
	var board_aspect := float(snapshot.get("board_aspect_ratio", 0.0))
	if board_rect.size.x <= 0.0 or board_rect.size.y <= 0.0 or board_aspect <= 0.0:
		push_error("%s did not expose a usable rendered board rect." % label)
		return false
	var rendered_aspect := board_rect.size.x / board_rect.size.y
	if absf(rendered_aspect - board_aspect) > 0.01:
		push_error("%s stretches art: rendered aspect %.3f, board aspect %.3f." % [label, rendered_aspect, board_aspect])
		return false
	return true


func _snapshot_rect(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0)))
	)


func _focus_camera_animation_is_stable(canvas: Control, label: String) -> bool:
	if canvas == null or not canvas.has_method("current_view_snapshot"):
		push_error("%s could not expose camera motion diagnostics." % label)
		return false
	var start_snapshot: Dictionary = canvas.call("current_view_snapshot")
	var target_offset: Vector2 = start_snapshot.get("target_camera_offset", Vector2.ZERO)
	var target_zoom := float(start_snapshot.get("target_camera_zoom", 1.0))
	var previous_offset: Vector2 = start_snapshot.get("camera_offset", Vector2.ZERO)
	var previous_zoom := float(start_snapshot.get("camera_zoom", 1.0))
	var previous_distance := previous_offset.distance_to(target_offset) + absf(previous_zoom - target_zoom) * 120.0
	var target_refresh_count := int(start_snapshot.get("camera_target_refresh_count", -1))
	if target_refresh_count < 0:
		push_error("%s did not expose camera target refresh diagnostics." % label)
		return false
	for _index in range(8):
		await process_frame
		var snapshot: Dictionary = canvas.call("current_view_snapshot")
		if int(snapshot.get("camera_target_refresh_count", -1)) != target_refresh_count:
			push_error("%s recalculated its focus target during camera glide, which can cause visible stutter." % label)
			return false
		var current_target_offset: Vector2 = snapshot.get("target_camera_offset", Vector2.ZERO)
		var current_target_zoom := float(snapshot.get("target_camera_zoom", 1.0))
		if current_target_offset.distance_to(target_offset) > 0.25 or absf(current_target_zoom - target_zoom) > 0.001:
			push_error("%s focus camera target drifted while animating." % label)
			return false
		var current_offset: Vector2 = snapshot.get("camera_offset", Vector2.ZERO)
		var current_zoom := float(snapshot.get("camera_zoom", 1.0))
		var distance := current_offset.distance_to(target_offset) + absf(current_zoom - target_zoom) * 120.0
		if distance > previous_distance + 1.0:
			push_error("%s focus camera moved away from its target during animation." % label)
			return false
		var offset_step := current_offset.distance_to(previous_offset)
		var remaining_offset := previous_offset.distance_to(target_offset)
		if offset_step > maxf(remaining_offset * 0.45, 3.0):
			push_error("%s focus camera jumped too far in one frame: %.2f px." % [label, offset_step])
			return false
		if absf(current_zoom - previous_zoom) > 0.16:
			push_error("%s focus camera zoom jumped too far in one frame." % label)
			return false
		previous_offset = current_offset
		previous_zoom = current_zoom
		previous_distance = distance
	return true


func _selected_info_text_fits(canvas_value: Variant, label: String, required_fragments: Array = []) -> bool:
	if canvas_value == null or not (canvas_value is Control):
		push_error("%s did not have an environment canvas for info-card verification." % label)
		return false
	var canvas := canvas_value as Control
	if not canvas.has_method("current_view_snapshot"):
		push_error("%s canvas did not expose a view snapshot." % label)
		return false
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var selected_info: Dictionary = snapshot.get("selected_info", {})
	if not bool(selected_info.get("visible", false)):
		push_error("%s did not expose a visible in-scene info card." % label)
		return false
	var lines: Array = selected_info.get("lines", [])
	if lines.is_empty():
		push_error("%s info card did not expose any body text." % label)
		return false
	var card_rect := _snapshot_rect(selected_info.get("rect", {}))
	var visible_board_rect := _snapshot_rect(selected_info.get("visible_board_rect", {}))
	if card_rect.size.x <= 0.0 or card_rect.size.y <= 0.0 or visible_board_rect.size.x <= 0.0 or visible_board_rect.size.y <= 0.0:
		push_error("%s info card did not expose valid placement rects." % label)
		return false
	if card_rect.position.x < visible_board_rect.position.x - 0.01 or card_rect.position.y < visible_board_rect.position.y - 0.01 or card_rect.end.x > visible_board_rect.end.x + 0.01 or card_rect.end.y > visible_board_rect.end.y + 0.01:
		push_error("%s info card was clipped outside the visible environment plane." % label)
		return false
	var object_rect := _snapshot_rect(selected_info.get("object_rect", {}))
	if object_rect.size.x > 0.0 and object_rect.size.y > 0.0 and card_rect.intersects(object_rect):
		push_error("%s info card covered the selected environment object." % label)
		return false
	var max_chars := int(selected_info.get("max_line_chars", 42))
	var badge_entries: Array = selected_info.get("badge_hit_entries", [])
	var body_text_start_y := float(selected_info.get("body_text_start_y", card_rect.position.y))
	for badge_entry_value in badge_entries:
		if typeof(badge_entry_value) != TYPE_DICTIONARY:
			continue
		var badge_entry: Dictionary = badge_entry_value
		var badge_rect := _snapshot_rect(badge_entry.get("rect", {}))
		if badge_rect.size.x <= 0.0 or badge_rect.size.y <= 0.0:
			push_error("%s info-card badge exposed an invalid hover rect." % label)
			return false
		if badge_rect.end.y > body_text_start_y - 0.01:
			push_error("%s info-card badge row overlaps body text." % label)
			return false
		if body_text_start_y - badge_rect.end.y < 8.0:
			push_error("%s info-card badge row does not leave enough clearance above body text." % label)
			return false
		if str(badge_entry.get("tooltip", "")).strip_edges().is_empty():
			push_error("%s info-card badge did not expose hover details." % label)
			return false
	var joined := ""
	for line in lines:
		var text := str(line)
		joined += "%s\n" % text
		if text.find("\n") != -1 or text.find("\t") != -1:
			push_error("%s info card contains multiline text that can clip: %s" % [label, text])
			return false
		if text.find("...") != -1:
			push_error("%s info card still uses ellipsis truncation instead of fitted copy: %s" % [label, text])
			return false
		if text.length() > max_chars:
			push_error("%s info card line exceeds the compact text limit: %s" % [label, text])
			return false
	for fragment in required_fragments:
		if joined.find(str(fragment)) == -1:
			push_error("%s info card omitted expected context: %s" % [label, str(fragment)])
			return false
	return true


func _badge_slot_icon_only_with_tooltips(root: Control, label: String) -> bool:
	var badge_cells := _badge_cell_controls(root)
	if badge_cells.is_empty():
		push_error("%s did not expose any badge cells." % label)
		return false
	for cell_value in badge_cells:
		var cell := cell_value as Control
		if cell == null or not cell.visible:
			continue
		if cell.tooltip_text.strip_edges().is_empty():
			push_error("%s badge cell did not expose hover details." % label)
			return false
		if _visible_badge_text_label_count(cell) > 0:
			push_error("%s badge cell still rendered text next to the icon." % label)
			return false
	return true


func _world_map_detail_popup_fits(screen_snapshot: Dictionary) -> bool:
	if not bool(screen_snapshot.get("world_map_detail_popup_visible", false)):
		push_error("World map detail should be shown as an overlay popup.")
		return false
	var popup_rect := _snapshot_rect(screen_snapshot.get("world_map_detail_popup_rect", {}))
	var holder_rect := _snapshot_rect(screen_snapshot.get("world_map_holder_rect", {}))
	if popup_rect.size.x <= 0.0 or popup_rect.size.y <= 0.0 or holder_rect.size.x <= 0.0 or holder_rect.size.y <= 0.0:
		push_error("World map popup or holder did not expose valid bounds: popup=%s holder=%s." % [str(popup_rect), str(holder_rect)])
		return false
	if not holder_rect.grow(1.0).encloses(popup_rect):
		push_error("World map detail popup was not clamped inside the map: popup=%s holder=%s." % [str(popup_rect), str(holder_rect)])
		return false
	return true


func _badge_cell_controls(root: Control) -> Array:
	var result: Array = []
	if root.tooltip_text.strip_edges() != "":
		result.append(root)
	for child in root.get_children():
		var child_control := child as Control
		if child_control == null:
			continue
		result.append_array(_badge_cell_controls(child_control))
	return result


func _visible_badge_text_label_count(root: Control) -> int:
	var count := 0
	for child in root.get_children():
		var label := child as Label
		if label != null and label.visible and label.text.strip_edges() != "":
			count += 1
		var child_control := child as Control
		if child_control != null:
			count += _visible_badge_text_label_count(child_control)
	return count


func _canvas_local_center_for_object(canvas: Control, object_data: Dictionary) -> Vector2:
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	var position: Vector2 = object_data.get("position", Vector2(0.5, 0.5))
	var board_point := Vector2(position.x * VisualStyleScript.ENVIRONMENT_BOARD_SIZE.x, position.y * VisualStyleScript.ENVIRONMENT_BOARD_SIZE.y)
	var board_rect := _snapshot_rect(snapshot.get("board_rect", {}))
	if board_rect.size.x > 0.0 and board_rect.size.y > 0.0:
		var scale := board_rect.size.x / float(VisualStyleScript.ENVIRONMENT_BOARD_SIZE.x)
		return board_rect.position + board_point * scale
	return Vector2(position.x * canvas.size.x, position.y * canvas.size.y)


func _blank_canvas_position(canvas: Control) -> Vector2:
	var candidates := [
		Vector2(8.0, 8.0),
		Vector2(canvas.size.x - 8.0, 8.0),
		Vector2(8.0, canvas.size.y - 8.0),
		Vector2(canvas.size.x - 8.0, canvas.size.y - 8.0),
		Vector2(canvas.size.x * 0.5, 8.0),
		Vector2(canvas.size.x * 0.5, canvas.size.y - 8.0),
	]
	for candidate in candidates:
		if _canvas_position_is_blank(canvas, candidate):
			return candidate
	for row in range(1, 6):
		for column in range(1, 8):
			var candidate := Vector2(canvas.size.x * float(column) / 8.0, canvas.size.y * float(row) / 6.0)
			if _canvas_position_is_blank(canvas, candidate):
				return candidate
	return Vector2(-1.0, -1.0)


func _canvas_position_is_blank(canvas: Control, local_position: Vector2) -> bool:
	if local_position.x < 0.0 or local_position.y < 0.0 or local_position.x > canvas.size.x or local_position.y > canvas.size.y:
		return false
	if canvas.has_method("object_id_at_local_position"):
		return str(canvas.call("object_id_at_local_position", local_position)).is_empty()
	return true


func _environment_canvas_keeps_critical_ui_clear(app: Control, canvas: Control, viewport_rect, label: String) -> bool:
	if not _control_fits_viewport(canvas, viewport_rect, label):
		return false
	var critical_controls := [
		{"name": "status_label", "label": "HUD status"},
		{"name": "objective_label", "label": "objective HUD"},
		{"name": "save_status_label", "label": "save status"},
		{"name": "actions_list", "label": "context controls"},
		{"name": "consequence_cards_scroll", "label": "result controls"},
		{"name": "game_surface_canvas", "label": "game surface"},
	]
	var canvas_rect := canvas.get_global_rect()
	for entry in critical_controls:
		var control := app.get(str(entry.get("name", ""))) as Control
		if control == null or not control.visible or not control.is_visible_in_tree():
			continue
		var control_label := "%s near %s" % [str(entry.get("label", "")), label]
		if not _control_fits_viewport(control, viewport_rect, control_label):
			return false
		if control != canvas and canvas_rect.intersects(control.get_global_rect()):
			push_error("%s overlaps %s: canvas %s, control %s." % [label, str(entry.get("label", "")), str(canvas_rect), str(control.get_global_rect())])
			return false
	return true


func _visible_text_fits_viewport(node: Node, text: String, viewport_rect, label: String) -> bool:
	if text.is_empty():
		push_error("%s had no text to verify." % label)
		return false
	var control := _find_visible_text_control(node, text)
	if control == null:
		push_error("%s was not visible in the critical game UI: %s." % [label, text])
		return false
	return _control_fits_viewport(control, viewport_rect, label)


func _find_visible_text_control(node: Node, text: String) -> Control:
	if node == null:
		return null
	if node is CanvasItem and not (node as CanvasItem).visible:
		return null
	if node is Label and (node as Label).text.find(text) != -1:
		return node as Control
	if node is Button and (node as Button).text.find(text) != -1:
		return node as Control
	if node is LineEdit and (node as LineEdit).text.find(text) != -1:
		return node as Control
	if node is SpinBox:
		var spin_line := (node as SpinBox).get_line_edit()
		if spin_line != null and spin_line.text.find(text) != -1:
			return node as Control
	for child in node.get_children():
		var found := _find_visible_text_control(child, text)
		if found != null:
			return found
	return null


func _qa_action_label(action: Dictionary) -> String:
	var label := str(action.get("label", ""))
	if not label.is_empty():
		return label
	var action_id := str(action.get("id", ""))
	if action_id.is_empty():
		return "Action"
	return action_id.replace("_", " ").capitalize()


