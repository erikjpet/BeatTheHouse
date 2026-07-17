extends SceneTree

# Fresh-process UI compile smoke test. This catches missing palette tokens,
# scene preload failures, and startup control construction errors before the
# longer production playtest starts driving gameplay.

const MainScene := preload("res://scenes/main.tscn")
const VisualStyleScript := preload("res://scripts/ui/visual_style.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const PerformanceLivenessGuardScript := preload("res://scripts/ui/performance_liveness_guard.gd")
const RunInventoryScreenScript := preload("res://scripts/ui/run_inventory_screen.gd")
const TalkDockScript := preload("res://scripts/ui/talk_dock.gd")
const ItemFoundPopupScript := preload("res://scripts/ui/item_found_popup.gd")
const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")
const WorldMapCanvasScript := preload("res://scripts/ui/world_map_canvas.gd")
const SlotMachineStateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const SmallScreenPolicyScript := preload("res://scripts/ui/small_screen_policy.gd")
const RunReportScreenScript := preload("res://scripts/ui/run_report_screen.gd")
const RunReportViewModelScript := preload("res://scripts/ui/run_report_view_model.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const CollectionDropServiceScript := preload("res://scripts/core/collection_drop_service.gd")
const TEST_SETTINGS_PATH := "user://settings_ui_scene_compile_check.json"
const TEST_META_COLLECTION_PATH := "user://ui_scene_compile_meta_collection.json"


func _check_run_report_screen_component() -> bool:
	var screen: RunReportScreen = RunReportScreenScript.new()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	await process_frame
	var claimed_marker_ids: Array[String] = []
	screen.bag_claim_requested.connect(func(marker_id: String) -> void: claimed_marker_ids.append(marker_id))
	var report_world_map := {"current_node_id": "casino", "visited_path": ["bar", "casino"], "nodes": [{"id": "bar", "display_name": "Bar", "icon_path": "res://assets/art/map_icons/bar.png", "state": "visited", "position": {"x": 0.2, "y": 0.4}}, {"id": "casino", "display_name": "Casino", "icon_path": "res://assets/art/map_icons/grand_casino.png", "state": "visited", "position": {"x": 0.8, "y": 0.5}}, {"id": "pawn", "display_name": "Pawn Shop", "icon_path": "res://assets/art/map_icons/pawn_shop.png", "state": "revealed", "position": {"x": 0.5, "y": 0.9}}], "edges": [{"a": "bar", "b": "casino", "distance": "near"}, {"a": "casino", "b": "pawn", "distance": "near"}]}
	var timeline := RunReportViewModelScript.build_timeline([
		{"action_index": 0, "game_clock_minutes": 720, "heat_value": 4, "environment_id": "bar", "environment_name": "Bar", "world_node_id": "bar", "transition": true},
		{"action_index": 4, "game_clock_minutes": 748, "heat_value": 72, "environment_id": "casino", "environment_name": "Casino", "world_node_id": "casino", "transition": true},
		{"action_index": 8, "game_clock_minutes": 788, "heat_value": 18, "environment_id": "casino", "environment_name": "Casino", "world_node_id": "casino", "transition": false},
	], report_world_map, 8, [{"type": "travel", "from_world_node_id": "bar", "to_world_node_id": "casino", "travel_minutes": 12, "departed_game_clock_minutes": 736, "arrived_game_clock_minutes": 748}], 720, 788)
	var report_map := RunReportViewModelScript.build_report_map_snapshot(report_world_map, timeline)
	var replay_segments: Array = timeline.get("replay_segments", [])
	if replay_segments.size() != 3 or str((replay_segments[0] as Dictionary).get("kind", "")) != "dwell" or str((replay_segments[1] as Dictionary).get("kind", "")) != "travel" or str((replay_segments[2] as Dictionary).get("kind", "")) != "dwell":
		push_error("Run report timeline did not split venue dwell time from travel time.")
		return false
	if int((replay_segments[0] as Dictionary).get("end_game_clock_minutes", -1)) != 736 or int((replay_segments[1] as Dictionary).get("end_game_clock_minutes", -1)) != 748:
		push_error("Run report timeline did not preserve the existing game-clock departure and arrival times.")
		return false
	if (report_map.get("nodes", []) as Array).size() != 2 or JSON.stringify(report_map).find("Pawn Shop") != -1:
		push_error("Run report map did not limit its fitted content to visited environments.")
		return false
	screen.set_report({
		"outcome": {"title": "Players Card earned", "how": "You cashed out clean.", "where": "Casino · Day 1, 20:00", "won": true},
		"score": {"money_put_to_work": 40, "winner_bonus": 3, "show_winner_bonus": true, "final_score": 120},
		"items": {"kept": [{"label": "Coffee", "count": 2, "fate": "kept", "icon_path": ""}], "pawned": [{"label": "Card", "fate": "forfeited", "icon_path": ""}], "sold": [{"label": "Watch", "count": 1, "price": 9, "icon_path": ""}]},
		"bag_reward": {"visible": true, "pending": true, "choices": [{"marker_id": "run-victory-bag", "display_name": "Roadside Luck Blue Bag", "collection_name": "Roadside Luck", "tier_label": "Blue"}], "summary_lines": []},
		"meta_reward": {"visible": true, "kind": "grand_casino_chips", "title": "CHIPS KEPT · Grand Casino Chips ×37", "detail": "Face value 37 · Sal offers 22 gold"},
		"debts": [{"lender": "Sal", "amount": 20, "outcome": "redeemed", "tone": "settled"}],
		"money_rows": [{"label": "Slots", "net": 100}, {"label": "Bar Dice", "net": -50}],
		"timeline": timeline,
		"map_snapshot": report_map,
		"seed": "REPORT-UI",
	})
	await process_frame
	var snapshot: Dictionary = screen.debug_layout_snapshot()
	if bool(snapshot.get("has_scroll_container", true)):
		push_error("Run report component contains a ScrollContainer.")
		return false
	if not bool(snapshot.get("bag_reward_visible", false)) or not bool(snapshot.get("bag_reward_pending", false)) or int(snapshot.get("bag_reward_choice_count", 0)) != 1:
		push_error("Run report did not present the earned collection-bag choice.")
		return false
	if not bool(snapshot.get("meta_reward_visible", false)) or not str(snapshot.get("meta_reward_text", "")).contains("Grand Casino Chips ×37"):
		push_error("Run report RESULT did not present the uncashed Grand Casino Chips reward.")
		return false
	if not bool(snapshot.get("new_run_disabled", false)) or not bool(snapshot.get("home_disabled", false)):
		push_error("Run report allowed navigation before the earned collection bag was stored.")
		return false
	screen.call("_on_bag_claim_pressed")
	if claimed_marker_ids != ["run-victory-bag"]:
		push_error("Run report collection-bag action did not emit the selected marker id.")
		return false
	var bounds := Rect2(Vector2.ZERO, screen.size)
	for rect_value in (snapshot.get("section_rects", {}) as Dictionary).values():
		var rect: Rect2 = rect_value
		if not bounds.encloses(rect) or rect.size.x <= 0.0 or rect.size.y <= 0.0:
			push_error("Run report section is clipped outside the 1280x720 design surface: %s." % str(rect))
			return false
	if int(snapshot.get("timeline_install_count", 0)) != 1:
		push_error("Run report did not precompute/install its shared timeline exactly once.")
		return false
	screen.call("_on_timeline_seek", 0.1)
	var dwell_replay: Dictionary = (screen.get("map_canvas") as Node).call("current_view_snapshot").get("run_report_replay", {})
	if str(dwell_replay.get("kind", "")) != "dwell" or str(dwell_replay.get("node_id", "")) != "bar" or not is_zero_approx(float(dwell_replay.get("amount", -1.0))):
		push_error("Run report replay marker moved while the player was still at the first venue.")
		return false
	screen.call("_on_timeline_seek", 22.0 / 68.0)
	var travel_replay: Dictionary = (screen.get("map_canvas") as Node).call("current_view_snapshot").get("run_report_replay", {})
	if str(travel_replay.get("kind", "")) != "travel" or absf(float(travel_replay.get("amount", 0.0)) - 0.5) > 0.01:
		push_error("Run report replay marker did not move only during the recorded travel interval.")
		return false
	screen.call("_on_timeline_seek", 0.5)
	if str(screen.debug_layout_snapshot().get("replay_clock_text", "")).find("Day 1 12:34 PM") == -1:
		push_error("Run report replay did not showcase the existing game clock at the selected time.")
		return false
	await process_frame
	if int(screen.debug_layout_snapshot().get("timeline_install_count", 0)) != 1:
		push_error("Run report rebuilt timeline keyframes during an idle frame.")
		return false
	screen.set_small_screen_mode(true)
	await process_frame
	var small_snapshot := screen.debug_layout_snapshot()
	if not bool(small_snapshot.get("small_screen_mode", false)) or bool(small_snapshot.get("has_scroll_container", true)):
		push_error("Run report small-screen mode did not remain a no-scroll surface.")
		return false
	screen.set_reduce_motion(true)
	if float(screen.debug_layout_snapshot().get("replay_progress", 0.0)) != 1.0:
		push_error("Run report reduce-motion mode did not show the full path instantly.")
		return false
	screen.call("_on_timeline_seek", 0.0)
	if float(screen.debug_layout_snapshot().get("replay_progress", -1.0)) != 0.0:
		push_error("Run report heat scrubber did not seek to the first action boundary.")
		return false
	screen.call("_on_timeline_seek", 1.0)
	if float(screen.debug_layout_snapshot().get("replay_progress", -1.0)) != 1.0:
		push_error("Run report heat scrubber did not seek to the final action boundary.")
		return false
	screen.queue_free()
	await process_frame
	return true


func _player_facing_effect_summary_is_clean(text: String, label: String) -> bool:
	var lowered := text.to_lower()
	for forbidden in ["delta", "msec", "serialized", "foundation", "contract", "module", "suspicion", "_"]:
		if lowered.find(forbidden) != -1:
			push_error("%s exposes technical text: %s in %s." % [label, forbidden, text])
			return false
	return true


func _visible_buttons_meet_touch_target(node: Node, label: String, minimum_height: float = 39.5) -> bool:
	if node == null:
		return true
	if node is CanvasItem and not (node as CanvasItem).visible:
		return true
	if node is Button:
		var button := node as Button
		if button.visible and button.is_visible_in_tree():
			var rect := button.get_global_rect()
			if rect.size.y < minimum_height:
				push_error("%s has a visible button below touch target height: %s at %s." % [label, button.text, str(rect)])
				return false
	for child in node.get_children():
		if not _visible_buttons_meet_touch_target(child, label, minimum_height):
			return false
	return true


func _check_run_inventory_screen_component() -> bool:
	var parent := Control.new()
	parent.size = Vector2(900, 520)
	root.add_child(parent)
	var screen: RunInventoryScreen = RunInventoryScreenScript.new()
	screen.configure(Callable(self, "_run_inventory_test_texture"))
	parent.add_child(screen)
	var emitted := {
		"selected": "",
		"selected_source": "",
		"active": "",
		"sell": "",
		"repair": "",
		"pawn_lender": "",
		"pawn_item": "",
		"redeem_lender": "",
		"redeem_debt": "",
		"place": "",
		"store": "",
		"store_container": "",
		"take": "",
		"take_container": "",
	}
	screen.item_selected.connect(func(item_id: String, source: String) -> void:
		emitted["selected"] = item_id
		emitted["selected_source"] = source
	)
	screen.set_active_requested.connect(func(item_id: String) -> void:
		emitted["active"] = item_id
	)
	screen.sell_requested.connect(func(item_id: String) -> void:
		emitted["sell"] = item_id
	)
	screen.repair_requested.connect(func(item_id: String) -> void:
		emitted["repair"] = item_id
	)
	screen.pawn_requested.connect(func(lender_id: String, item_id: String) -> void:
		emitted["pawn_lender"] = lender_id
		emitted["pawn_item"] = item_id
	)
	screen.redeem_pawn_requested.connect(func(lender_id: String, debt_id: String) -> void:
		emitted["redeem_lender"] = lender_id
		emitted["redeem_debt"] = debt_id
	)
	screen.place_container_requested.connect(func(item_id: String) -> void:
		emitted["place"] = item_id
	)
	screen.store_item_requested.connect(func(container_id: String, item_id: String) -> void:
		emitted["store_container"] = container_id
		emitted["store"] = item_id
	)
	screen.take_item_requested.connect(func(container_id: String, item_id: String) -> void:
		emitted["take_container"] = container_id
		emitted["take"] = item_id
	)
	screen.open(_run_inventory_component_model("inspect"))
	await process_frame
	if not screen.is_open() or screen.rendered_item_child_count() < 2 or not _has_visible_text(screen, "Odds Notebook") or not _has_visible_text(screen, "Standalone component item."):
		parent.queue_free()
		push_error("Standalone run inventory screen did not render inspect grid and detail content.")
		return false
	if not _click_visible_button(screen, "Set Active") or str(emitted.get("active", "")) != "odds_notebook":
		parent.queue_free()
		push_error("Standalone run inventory screen did not emit active-item intent.")
		return false
	screen.update_model(_run_inventory_component_model("merchant_sale"))
	await process_frame
	if not _click_visible_button(screen, "Repair for 3") or str(emitted.get("repair", "")) != "odds_notebook":
		parent.queue_free()
		push_error("Standalone run inventory merchant mode did not emit repair intent.")
		return false
	if not _click_visible_button(screen, "Sell for 12") or str(emitted.get("sell", "")) != "odds_notebook":
		parent.queue_free()
		push_error("Standalone run inventory merchant mode did not emit sale intent.")
		return false
	screen.update_model(_run_inventory_component_model("pawn_counter", "sals_pawn_counter"))
	await process_frame
	if not _click_visible_button(screen, "Pawn for $24") or str(emitted.get("pawn_lender", "")) != "sals_pawn_counter" or str(emitted.get("pawn_item", "")) != "odds_notebook":
		parent.queue_free()
		push_error("Standalone pawn counter did not match merchant overlay styling and emit pawn intent.")
		return false
	screen.select_item("lucky_coin", "pawn_ticket", false)
	await process_frame
	if not _click_visible_button(screen, "Redeem for $15") or str(emitted.get("redeem_lender", "")) != "sals_pawn_counter" or str(emitted.get("redeem_debt", "")) != "sals_lucky_coin_ticket":
		parent.queue_free()
		push_error("Standalone pawn counter did not render a redeemable ticket in the shared merchant overlay.")
		return false
	screen.update_model(_run_inventory_component_model("place_container"))
	await process_frame
	if not _click_visible_button(screen, "Place at Home") or str(emitted.get("place", "")) != "canvas_bag":
		parent.queue_free()
		push_error("Standalone run inventory place-container mode did not emit placement intent.")
		return false
	screen.update_model(_run_inventory_component_model("home_container", "home_box", {"id": "odds_notebook", "source": "carried"}))
	await process_frame
	if not _click_visible_button(screen, "Move to Storage") or str(emitted.get("store_container", "")) != "home_box" or str(emitted.get("store", "")) != "odds_notebook":
		parent.queue_free()
		push_error("Standalone run inventory home-container mode did not emit store intent.")
		return false
	screen.select_item("odds_notebook", "container", false)
	await process_frame
	var selected_key: Dictionary = screen.selected_item_key()
	if str(selected_key.get("id", "")) != "odds_notebook" or str(selected_key.get("source", "")) != "container":
		parent.queue_free()
		push_error("Standalone run inventory did not preserve item/source pair selection.")
		return false
	if not _click_visible_button(screen, "Move to Inventory") or str(emitted.get("take_container", "")) != "home_box" or str(emitted.get("take", "")) != "odds_notebook":
		parent.queue_free()
		push_error("Standalone run inventory home-container mode did not emit take intent.")
		return false
	screen.update_model(_run_inventory_component_model("home_container", "home_box", {"id": "odds_notebook", "source": "container"}))
	selected_key = screen.selected_item_key()
	if str(selected_key.get("source", "")) != "container":
		parent.queue_free()
		push_error("Standalone run inventory update_model did not keep an existing selected item/source pair.")
		return false
	screen.update_model(_run_inventory_component_model("inspect", "", {"id": "missing", "source": "carried"}))
	selected_key = screen.selected_item_key()
	if str(selected_key.get("id", "")) != "odds_notebook" or str(selected_key.get("source", "")) != "carried":
		parent.queue_free()
		push_error("Standalone run inventory did not auto-select the first item when selection was absent.")
		return false
	screen.set_small_screen_mode(true)
	await process_frame
	if not bool(screen.layout_rects().get("small_screen_mode", false)) or not _visible_buttons_meet_touch_target(screen, "small-screen run inventory", SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT - 0.5):
		parent.queue_free()
		push_error("Standalone run inventory did not adopt the small-screen control target policy.")
		return false
	screen.set_small_screen_mode(false)
	parent.size = Vector2(640, 360)
	screen.size = parent.size
	await process_frame
	screen.refresh_layout()
	await process_frame
	var rects: Dictionary = screen.layout_rects()
	var popup_rect := _snapshot_rect(rects.get("popup_rect", Rect2()))
	var screen_rect := _snapshot_rect(rects.get("screen_rect", Rect2()))
	if popup_rect.size.x <= 0.0 or popup_rect.size.y <= 0.0 or not screen_rect.grow(1.0).encloses(popup_rect):
		parent.queue_free()
		push_error("Standalone run inventory popup did not clamp inside a small viewport: popup=%s screen=%s." % [str(popup_rect), str(screen_rect)])
		return false
	screen.close()
	if screen.is_open():
		parent.queue_free()
		push_error("Standalone run inventory close did not hide the component.")
		return false
	parent.queue_free()
	return true


func _check_talk_dock_component() -> bool:
	var parent := Control.new()
	parent.size = Vector2(640, 360)
	root.add_child(parent)
	var dock: TalkDock = TalkDockScript.new()
	dock.size = parent.size
	parent.add_child(dock)
	await process_frame
	var emitted := {"event_id": "", "choice_id": "", "count": 0}
	dock.choice_requested.connect(func(event_id: String, choice_id: String) -> void:
		emitted["event_id"] = event_id
		emitted["choice_id"] = choice_id
		emitted["count"] = int(emitted.get("count", 0)) + 1
	)
	dock.set_entry(_talk_dock_entry_fixture(), _talk_dock_option_fixture(), 2)
	await process_frame
	var snapshot: Dictionary = dock.current_snapshot()
	if not bool(snapshot.get("visible", false)) or not bool(snapshot.get("expanded", false)) or int(snapshot.get("choice_count", 0)) != 3:
		parent.queue_free()
		push_error("Talk dock fixture did not render an expanded timed entry.")
		return false
	if not bool(snapshot.get("speaker_label_visible", false)) or str(snapshot.get("speaker_text", "")).find("Mara") == -1:
		parent.queue_free()
		push_error("Expanded talk dock did not showcase the active speaker identity: %s." % str(snapshot.get("speaker_text", "")))
		return false
	var animation_redraw_before := int(snapshot.get("portrait_animation_redraw_count", 0))
	for _frame in range(20):
		await process_frame
	snapshot = dock.current_snapshot()
	if not bool(snapshot.get("portrait_animation_active", false)) or int(snapshot.get("portrait_animation_redraw_count", 0)) <= animation_redraw_before:
		parent.queue_free()
		push_error("Talk dock speaker portrait did not animate while the conversation was expanded.")
		return false
	dock.set_reduce_motion(true)
	if bool(dock.current_snapshot().get("portrait_animation_active", true)):
		parent.queue_free()
		push_error("Talk dock speaker portrait ignored the reduced-motion setting.")
		return false
	dock.set_reduce_motion(false)
	if not _has_visible_text(dock, "Mara") or not _has_visible_text(dock, "Hear Them Out") or not _has_visible_text(dock, "Someone at the table leans in with a read on the room."):
		parent.queue_free()
		push_error("Talk dock fixture did not expose the speaker, spoken line, and choice copy.")
		return false
	dock.set_small_screen_mode(true)
	await process_frame
	if not _visible_buttons_meet_touch_target(dock, "small-screen talk dock", SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT - 0.5):
		parent.queue_free()
		return false
	dock.set_small_screen_mode(false)
	await process_frame
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_2
	if not dock.handle_hotkey(key_event) or str(emitted.get("choice_id", "")) != "pass":
		parent.queue_free()
		push_error("Talk dock hotkey did not emit the second choice.")
		return false
	dock.set_entry(_talk_dock_entry_fixture(), _talk_dock_option_fixture(), 1)
	await process_frame
	if not _click_visible_button(dock, "Risk It") or int(emitted.get("count", 0)) != 1:
		parent.queue_free()
		push_error("Talk dock risky choice did not arm without resolving.")
		return false
	if not _click_visible_button(dock, "Confirm: Risk It") or str(emitted.get("choice_id", "")) != "risk":
		parent.queue_free()
		push_error("Talk dock risky choice did not resolve on second click.")
		return false
	var bad_key := InputEventKey.new()
	bad_key.pressed = true
	bad_key.keycode = KEY_9
	if dock.handle_hotkey(bad_key):
		parent.queue_free()
		push_error("Talk dock consumed an out-of-range hotkey.")
		return false
	snapshot = dock.current_snapshot()
	var panel_rect := _snapshot_rect(snapshot.get("panel_rect", Rect2()))
	var portrait_rect := _snapshot_rect(snapshot.get("portrait_rect", Rect2()))
	var screen_rect := _snapshot_rect(snapshot.get("screen_rect", Rect2()))
	if panel_rect.size.x <= 0.0 or panel_rect.size.y <= 0.0 or not screen_rect.grow(1.0).encloses(panel_rect):
		parent.queue_free()
		push_error("Talk dock did not clamp inside a small viewport: panel=%s screen=%s." % [str(panel_rect), str(screen_rect)])
		return false
	if panel_rect.size.x > 540.0 or panel_rect.size.x >= screen_rect.size.x - 80.0 or panel_rect.size.x < 280.0 or panel_rect.size.y > 220.0:
		parent.queue_free()
		push_error("Talk dock did not present a compact selection overlay: panel=%s screen=%s." % [str(panel_rect), str(screen_rect)])
		return false
	if portrait_rect.position.x > 48.0 or panel_rect.position.x > portrait_rect.end.x + 2.0 or absf(panel_rect.end.y - screen_rect.end.y) > 28.0:
		parent.queue_free()
		push_error("Talk dock cluster did not anchor to the bottom left: panel=%s portrait=%s screen=%s." % [str(panel_rect), str(portrait_rect), str(screen_rect)])
		return false
	if portrait_rect.size.x < 170.0 or portrait_rect.size.y < 220.0 or absf(portrait_rect.end.y - screen_rect.end.y) > 28.0:
		parent.queue_free()
		push_error("Talk dock speaker was not staged as a large environment portrait: portrait=%s screen=%s." % [str(portrait_rect), str(screen_rect)])
		return false
	var response_icon_kinds: Array = snapshot.get("response_icon_kinds", [])
	if str(snapshot.get("presentation", "")) != "environment_overlay" or bool(snapshot.get("choice_effects_visible", true)) or _has_visible_text(dock, "Heat -1") or not response_icon_kinds.has("heat_down") or not response_icon_kinds.has("heat_up") or not response_icon_kinds.has("leave"):
		parent.queue_free()
		push_error("Talk dock did not pair concealed effect values with qualitative response icons: %s." % str(response_icon_kinds))
		return false
	dock.clear_entry()
	if bool(dock.current_snapshot().get("visible", true)):
		parent.queue_free()
		push_error("Talk dock clear_entry did not hide the dock.")
		return false
	parent.queue_free()
	return true


func _check_item_found_popup_component() -> bool:
	var parent := Control.new()
	parent.size = Vector2(640, 360)
	root.add_child(parent)
	var popup: ItemFoundPopup = ItemFoundPopupScript.new()
	popup.size = parent.size
	parent.add_child(popup)
	await process_frame
	popup.show_item({"id": "fixture_key", "display_name": "Fixture Key"}, _item_found_test_texture())
	await process_frame
	var snapshot := popup.current_snapshot()
	var panel_rect := _snapshot_rect(snapshot.get("panel_rect", Rect2()))
	var screen_rect := _snapshot_rect(snapshot.get("screen_rect", Rect2()))
	if not bool(snapshot.get("visible", false)) or str(snapshot.get("item_id", "")) != "fixture_key" or str(snapshot.get("message", "")) != "You found the Fixture Key item.":
		parent.queue_free()
		push_error("Item-found popup did not render the internal item discovery line.")
		return false
	if str(snapshot.get("presentation", "")) != "internal_dialogue" or not bool(snapshot.get("has_item_texture", false)) or not is_equal_approx(float(snapshot.get("duration_seconds", 0.0)), 3.0):
		parent.queue_free()
		push_error("Item-found popup did not expose item art and the three-second transient contract.")
		return false
	if panel_rect.size.x > 410.0 or panel_rect.size.y > 130.0 or panel_rect.position.x > screen_rect.position.x + 24.0 or absf(panel_rect.end.y - screen_rect.end.y) > 24.0:
		parent.queue_free()
		push_error("Item-found popup was not a small bottom-left overlay: panel=%s screen=%s snapshot=%s." % [str(panel_rect), str(screen_rect), JSON.stringify(snapshot)])
		return false
	popup.dismiss_timer.start(0.01)
	await process_frame
	await process_frame
	if bool(popup.current_snapshot().get("visible", true)):
		parent.queue_free()
		push_error("Item-found popup did not dismiss itself when its timeout elapsed.")
		return false
	root.remove_child(parent)
	parent.free()
	await process_frame
	return true


func _item_found_test_texture() -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color("#36d7ff"))
	return ImageTexture.create_from_image(image)


func _talk_dock_entry_fixture() -> Dictionary:
	return {
		"event_id": "talk_fixture",
		"speaker": {"role": "patron", "name": "Mara", "silhouette": "coat", "bind": "table_patron", "patron_index": 0},
		"timing": {"expires": true, "duration_actions": 3, "remaining_actions": 3, "timeout_choice_id": "pass"},
	}


func _talk_dock_option_fixture() -> Dictionary:
	return {
		"display_name": "Table Whisper",
		"summary": "Someone at the table leans in with a read on the room.",
		"choices": [
			{"id": "hear", "label": "Hear Them Out", "text": "Listen.", "consequence_summary": "Heat -1."},
			{"id": "pass", "label": "Pass", "text": "Let it go.", "consequence_summary": "Event closes."},
			{"id": "risk", "label": "Risk It", "text": "Push the room.", "consequence_summary": "Heat +3.", "requires_confirm": true},
		],
	}


func _check_talk_dock_main_flow(app: Control) -> bool:
	var modal_heat := await _resolve_talk_event_fixture(app, "modal")
	if modal_heat < 0:
		return false
	var talk_heat := await _resolve_talk_event_fixture(app, "talk")
	if talk_heat < 0:
		return false
	if talk_heat != modal_heat:
		push_error("Talk dock event resolution did not match modal consequence result: talk=%d modal=%d." % [talk_heat, modal_heat])
		return false
	var talk_snapshot: Dictionary = app.call("current_talk_dock_snapshot")
	if bool(talk_snapshot.get("visible", false)):
		push_error("Talk dock remained visible after resolving its focused entry.")
		return false
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if bool(popup.get("visible", false)):
		push_error("Talk dock resolution left a blocking event popup visible.")
		return false
	return true


func _resolve_talk_event_fixture(app: Control, presentation: String) -> int:
	app.call("start_foundation_run", "UI-TALK-%s" % presentation)
	await process_frame
	var run_state: RunState = app.get("run_state")
	var library: ContentLibrary = app.get("library")
	if run_state == null or library == null:
		push_error("Talk dock fixture could not access run state or content library.")
		return -1
	var event_id := "blackjack_counter_probe" if presentation == "talk" else "family_loan"
	var choice_id := "ignore" if presentation == "talk" else "deny"
	var event_definition := library.event(event_id)
	if event_definition.is_empty():
		push_error("Talk dock fixture event is missing: %s." % event_id)
		return -1
	var environment := run_state.current_environment.duplicate(true)
	environment["id"] = "ui_talk_table"
	environment["archetype_id"] = "bar"
	environment["kind"] = "bar"
	environment["tier"] = 1
	environment["game_ids"] = ["blackjack"]
	environment["event_ids"] = []
	environment["resolved_event_ids"] = []
	run_state.set_environment(environment)
	run_state.suspicion["level"] = 10
	if presentation == "modal":
		run_state.narrative_flags["brother_in_law_phone_ready"] = true
	var context := {
		"trigger": "table_approach",
		"type": "table_approach",
		"game_id": "blackjack",
		"hands_played": 2,
		"environment_snapshot": run_state.current_environment.duplicate(true),
	}
	var speaker := {
		"role": "patron",
		"name": "Mara",
		"silhouette": "coat",
		"bind": "table_patron",
		"patron_index": 0,
	}
	var overrides: Dictionary = app.call("_triggered_entry_overrides", event_definition, speaker)
	overrides["presentation"] = presentation
	if not run_state.enqueue_triggered_event(event_id, "ui_fixture", context, overrides):
		push_error("Talk dock fixture could not enqueue %s as %s." % [event_id, presentation])
		return -1
	app.call("_refresh")
	await process_frame
	if presentation == "modal":
		if not bool(app.call("_show_next_pending_triggered_event")):
			push_error("Talk dock modal comparison could not open the triggered popup.")
			return -1
		await process_frame
		var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
		if not bool(popup.get("visible", false)):
			push_error("Talk dock modal comparison did not expose a blocking popup.")
			return -1
	else:
		var talk_snapshot: Dictionary = app.call("current_talk_dock_snapshot")
		if not bool(talk_snapshot.get("visible", false)) or str(talk_snapshot.get("event_id", "")) != event_id:
			push_error("Talk dock fixture did not expose the queued talk event.")
			return -1
		var before_screen: Dictionary = app.call("current_screen_snapshot")
		if not bool(app.call("select_action_category", "items")):
			push_error("Talk dock pending entry blocked normal action-category routing.")
			return -1
		await process_frame
		var after_screen: Dictionary = app.call("current_screen_snapshot")
		if str(before_screen.get("screen", "")) == str(after_screen.get("screen", "")):
			push_error("Talk dock route probe did not exercise a visible screen change.")
			return -1
	app.call("resolve_event_choice", event_id, choice_id)
	await process_frame
	return run_state.suspicion_level()


func _check_dialogue_dock_main_flow(app: Control) -> bool:
	app.call("start_foundation_run", "UI-DIALOGUE-SEED")
	await process_frame
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		push_error("Dialogue dock fixture could not access run state.")
		return false
	var environment := run_state.current_environment.duplicate(true)
	environment["id"] = "ui_dialogue_pull_tabs"
	environment["archetype_id"] = "corner_store"
	environment["kind"] = "shop"
	environment["tier"] = 1
	environment["game_ids"] = ["pull_tabs"]
	environment["event_ids"] = []
	environment["resolved_event_ids"] = []
	environment["next_archetypes"] = ["bar"]
	run_state.set_environment(environment)
	if not bool(app.call("start_dialogue", "pull_tab_clerk", {})):
		push_error("Dialogue dock fixture could not start pull_tab_clerk.")
		return false
	await process_frame
	var snapshot: Dictionary = app.call("current_talk_dock_snapshot")
	if not bool(snapshot.get("visible", false)) or str(snapshot.get("event_id", "")) != "dialogue:pull_tab_clerk":
		push_error("Dialogue dock fixture did not expose the pilot dialogue.")
		return false
	if not bool(snapshot.get("speaker_label_visible", false)) or str(snapshot.get("speaker_text", "")).strip_edges().is_empty() or str(snapshot.get("speaker_text", "")) != "Speaking with %s" % str(snapshot.get("speaker", "")):
		push_error("Dialogue dock fixture did not show the active speaker inside the expanded popup: %s." % str(snapshot.get("speaker_text", "")))
		return false
	var panel_rect := _snapshot_rect(snapshot.get("panel_rect", Rect2()))
	var portrait_rect := _snapshot_rect(snapshot.get("portrait_rect", Rect2()))
	var screen_rect := _snapshot_rect(snapshot.get("screen_rect", Rect2()))
	if panel_rect.size.x < 420.0 or panel_rect.size.x > 540.0 or panel_rect.size.y > 220.0 or panel_rect.size.x >= screen_rect.size.x - 160.0:
		push_error("Dialogue dock fixture did not use the compact selection overlay: panel=%s screen=%s." % [str(panel_rect), str(screen_rect)])
		return false
	if screen_rect.size.x <= 0.0 or screen_rect.size.y <= 0.0 or portrait_rect.position.x > screen_rect.position.x + 48.0 or panel_rect.position.x > portrait_rect.end.x + 2.0 or absf(panel_rect.end.y - screen_rect.end.y) > 28.0:
		push_error("Dialogue dock main flow did not anchor its cluster to the bottom left: panel=%s portrait=%s screen=%s." % [str(panel_rect), str(portrait_rect), str(screen_rect)])
		return false
	if portrait_rect.size.x < 240.0 or portrait_rect.size.y < 340.0 or absf(portrait_rect.end.y - screen_rect.end.y) > 28.0:
		push_error("Dialogue dock main flow did not stage a large speaker over the environment: portrait=%s screen=%s." % [str(portrait_rect), str(screen_rect)])
		return false
	var response_icon_kinds: Array = snapshot.get("response_icon_kinds", [])
	if str(snapshot.get("presentation", "")) != "environment_overlay" or bool(snapshot.get("choice_effects_visible", true)) or response_icon_kinds.is_empty() or not _has_visible_text(app, str(snapshot.get("summary", ""))):
		push_error("Dialogue dock main flow did not expose spoken context with qualitative response icons and concealed values: %s." % str(response_icon_kinds))
		return false
	app.call("resolve_event_choice", "dialogue:pull_tab_clerk", "ask_routes")
	await process_frame
	if not bool(run_state.story_flags.get("pull_tab_clerk_route_tip", false)) or not run_state.unlocked_travel.has("gas_station_casino"):
		push_error("Dialogue dock route branch did not apply story flag and route unlock.")
		return false
	var travel_count := 0
	for travel_id in run_state.unlocked_travel:
		if str(travel_id) == "gas_station_casino":
			travel_count += 1
	app.call("resolve_event_choice", "dialogue:pull_tab_clerk", "ask_routes")
	await process_frame
	var after_repeat_count := 0
	for travel_id in run_state.unlocked_travel:
		if str(travel_id) == "gas_station_casino":
			after_repeat_count += 1
	if after_repeat_count != travel_count:
		push_error("Dialogue dock rapid repeat applied the route unlock twice.")
		return false
	app.call("resolve_event_choice", "dialogue:pull_tab_clerk", "done")
	await process_frame
	snapshot = app.call("current_talk_dock_snapshot")
	if bool(snapshot.get("visible", false)):
		push_error("Dialogue dock stayed visible after the end choice.")
		return false
	return true


func _check_event_item_found_main_flow(app: Control) -> bool:
	app.call("start_foundation_run", "UI-ITEM-FOUND-SEED")
	await process_frame
	var run_state: RunState = app.get("run_state")
	var library: ContentLibrary = app.get("library")
	if run_state == null or library == null:
		push_error("Item-found event fixture could not access runtime state.")
		return false
	var environment := run_state.current_environment.duplicate(true)
	environment["id"] = "ui_item_found_jazz"
	environment["archetype_id"] = "jazz_club"
	environment["kind"] = "shop"
	environment["tier"] = 2
	environment["turns"] = 3
	environment["resolved_event_ids"] = []
	run_state.set_environment(environment)
	run_state.set_story_flag("jazz_trio_backed_player", true)
	var event_definition := library.event("jazz_after_hours_invitation")
	var context := {
		"trigger": "action",
		"type": "action",
		"turns": 3,
		"environment_snapshot": run_state.current_environment.duplicate(true),
	}
	var overrides: Dictionary = app.call("_triggered_entry_overrides", event_definition, event_definition.get("speaker", {}) as Dictionary)
	overrides["presentation"] = "talk"
	if not run_state.enqueue_triggered_event("jazz_after_hours_invitation", "ui_item_found", context, overrides):
		push_error("Item-found event fixture could not enqueue the authored item-grant event.")
		return false
	app.call("_refresh")
	await process_frame
	var talk_dock: TalkDock = app.get("talk_dock")
	if not talk_dock.visible:
		push_error("Item-found event fixture could not stage the speaker portrait being replaced.")
		return false
	app.call("resolve_event_choice", "jazz_after_hours_invitation", "take_the_shades")
	await process_frame
	var snapshot: Dictionary = app.call("current_item_found_popup_snapshot")
	if not run_state.inventory.has("cheap_sunglasses") or not bool(snapshot.get("visible", false)) or str(snapshot.get("item_id", "")) != "cheap_sunglasses":
		push_error("An event item grant did not open the item-found popup: %s." % JSON.stringify(snapshot))
		return false
	if str(snapshot.get("display_name", "")) != "Cheap Sunglasses" or not bool(snapshot.get("has_item_texture", false)) or str(snapshot.get("message", "")) != "You found the Cheap Sunglasses item.":
		push_error("Event item-found popup did not use the granted item's authored name and icon.")
		return false
	if talk_dock.visible or not bool(snapshot.get("replaces_talk_portrait", false)):
		push_error("Event item-found popup did not replace the active speaker portrait during its internal-dialogue presentation.")
		return false
	var popup: ItemFoundPopup = app.get("item_found_popup")
	popup.dismiss_current()
	await process_frame
	return true


func _check_service_item_found_main_flow(app: Control) -> bool:
	app.call("start_foundation_run", "UI-CUMQUAT-FOUND-SEED")
	await process_frame
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		push_error("Cumquat item-found service fixture could not access runtime state.")
		return false
	var environment := run_state.current_environment.duplicate(true)
	environment["id"] = "ui_item_found_beach"
	environment["archetype_id"] = "beach"
	environment["display_name"] = "Low Tide Beach"
	environment["kind"] = "recovery"
	environment["tier"] = 2
	environment["service_ids"] = ["beach_sand_pile"]
	environment["resolved_event_ids"] = []
	run_state.set_environment(environment)
	app.call("_refresh")
	await process_frame
	if not bool(app.call("use_service_hook", "beach_sand_pile")):
		push_error("Cumquat item-found fixture could not use the real beach sand-pile service.")
		return false
	await process_frame
	var snapshot: Dictionary = app.call("current_item_found_popup_snapshot")
	if not run_state.inventory.has("cumquat_sandwich") or not bool(run_state.narrative_flags.get("beach_sand_pile_found", false)):
		push_error("Beach sand pile did not grant and persist the Cumquat Sandwich before presentation.")
		return false
	if not bool(snapshot.get("visible", false)) or str(snapshot.get("item_id", "")) != "cumquat_sandwich":
		push_error("Cumquat Sandwich service grant did not open the item-found popup: %s." % JSON.stringify(snapshot))
		return false
	if str(snapshot.get("display_name", "")) != "Cumquat Sandwich" or not bool(snapshot.get("has_item_texture", false)) or str(snapshot.get("message", "")) != "You found the Cumquat Sandwich item.":
		push_error("Cumquat Sandwich popup did not use the authored item name, icon, and discovery line.")
		return false
	if str(snapshot.get("presentation", "")) != "internal_dialogue" or not is_equal_approx(float(snapshot.get("duration_seconds", 0.0)), 3.0):
		push_error("Cumquat Sandwich popup did not use the three-second internal-dialogue presentation.")
		return false
	var popup: ItemFoundPopup = app.get("item_found_popup")
	popup.dismiss_current()
	await process_frame
	return true


func _check_world_map_selection_stable_component() -> bool:
	var canvas: Control = WorldMapCanvasScript.new()
	canvas.size = Vector2(560, 360)
	root.add_child(canvas)
	var base_snapshot := {
		"current_node_id": "center",
		"selected_node_id": "west",
		"nodes": [
			{"id": "center", "label": "Center", "state": "visited", "position": {"x": 0.50, "y": 0.50}, "icon_path": "res://assets/art/map_icons/back_alley.png"},
			{"id": "west", "label": "West", "state": "revealed", "position": {"x": 0.10, "y": 0.50}, "travel_target": true, "travel_enabled": true, "icon_path": "res://assets/art/map_icons/bar.png"},
			{"id": "east", "label": "East", "state": "revealed", "position": {"x": 0.90, "y": 0.50}, "travel_target": true, "travel_enabled": true, "icon_path": "res://assets/art/map_icons/corner_store.png"},
		],
		"edges": [
			{"id": "center-west", "a": "center", "b": "west", "distance": "near"},
			{"id": "center-east", "a": "center", "b": "east", "distance": "near"},
		],
		"visited_path": ["center"],
		"map_focus_node_ids": ["west"],
	}
	canvas.call("set_map_snapshot", base_snapshot)
	var before_view: Dictionary = canvas.call("current_view_snapshot")
	var before_bounds: Dictionary = before_view.get("map_bounds", {}) if typeof(before_view.get("map_bounds", {})) == TYPE_DICTIONARY else {}
	if not _world_map_background_aspect_is_stable(before_view):
		push_error("World map canvas stretched its background before the selected-location zoom: %s." % JSON.stringify(before_view))
		return false
	var selected_snapshot := base_snapshot.duplicate(true)
	selected_snapshot["selected_node_id"] = "east"
	selected_snapshot["map_focus_node_ids"] = ["east"]
	canvas.call("set_map_snapshot", selected_snapshot)
	var immediate_view: Dictionary = canvas.call("current_view_snapshot")
	var immediate_bounds: Dictionary = immediate_view.get("map_bounds", {}) if typeof(immediate_view.get("map_bounds", {})) == TYPE_DICTIONARY else {}
	var target_bounds: Dictionary = immediate_view.get("target_map_bounds", {}) if typeof(immediate_view.get("target_map_bounds", {})) == TYPE_DICTIONARY else {}
	if not _world_map_background_aspect_is_stable(immediate_view):
		push_error("World map canvas stretched its background at the start of the selected-location zoom: %s." % JSON.stringify(immediate_view))
		return false
	if not _map_bounds_equal(before_bounds, immediate_bounds):
		push_error("World map canvas selected-location zoom snapped instead of starting from the previous view window: before %s immediate %s." % [JSON.stringify(before_bounds), JSON.stringify(immediate_bounds)])
		return false
	if _map_bounds_equal(immediate_bounds, target_bounds) or not bool(immediate_view.get("selected_focus_zoom_animating", false)):
		push_error("World map canvas selected-location zoom did not expose an animated target window.")
		return false
	await process_frame
	var animated_view: Dictionary = canvas.call("current_view_snapshot")
	var animated_bounds: Dictionary = animated_view.get("map_bounds", {}) if typeof(animated_view.get("map_bounds", {})) == TYPE_DICTIONARY else {}
	if not _world_map_background_aspect_is_stable(animated_view):
		push_error("World map canvas changed its background aspect ratio during the selected-location zoom: %s." % JSON.stringify(animated_view))
		return false
	if _map_bounds_equal(before_bounds, animated_bounds) or _map_bounds_equal(animated_bounds, target_bounds):
		push_error("World map canvas selected-location zoom did not move partway toward the focused icon.")
		return false
	for _animation_index in range(54):
		await process_frame
	canvas.size = Vector2(561, 360)
	var jitter_view: Dictionary = canvas.call("current_view_snapshot")
	var jitter_bounds: Dictionary = jitter_view.get("map_bounds", {}) if typeof(jitter_view.get("map_bounds", {})) == TYPE_DICTIONARY else {}
	canvas.size = Vector2(560, 360)
	var after_view: Dictionary = canvas.call("current_view_snapshot")
	var after_bounds: Dictionary = after_view.get("map_bounds", {}) if typeof(after_view.get("map_bounds", {})) == TYPE_DICTIONARY else {}
	root.remove_child(canvas)
	canvas.free()
	if not _map_bounds_equal(target_bounds, jitter_bounds):
		push_error("World map canvas live size jitter changed the focused view window: target %s jitter %s." % [JSON.stringify(target_bounds), JSON.stringify(jitter_bounds)])
		return false
	if not bool(jitter_view.get("selected_focus_zoom_active", false)):
		push_error("World map canvas lost selected-location focus after the animated zoom settled.")
		return false
	if not _map_bounds_equal(target_bounds, after_bounds):
		push_error("World map canvas selected-location zoom did not settle on its target: target %s after %s." % [JSON.stringify(target_bounds), JSON.stringify(after_bounds)])
		return false
	if not _map_canvas_size_equal(before_view, after_view):
		push_error("World map canvas selection changed the rendered canvas size: before %s after %s." % [JSON.stringify(before_view.get("canvas_size", {})), JSON.stringify(after_view.get("canvas_size", {}))])
		return false
	if bool(after_view.get("selected_focus_zoom_animating", true)):
		push_error("World map canvas selected-location zoom did not finish animating.")
		return false
	if not _world_map_background_aspect_is_stable(after_view):
		push_error("World map canvas stretched its background after the selected-location zoom: %s." % JSON.stringify(after_view))
		return false
	return true


func _world_map_background_aspect_is_stable(view: Dictionary) -> bool:
	var source_aspect := float(view.get("background_source_aspect", 0.0))
	var destination_aspect := float(view.get("background_destination_aspect", -1.0))
	return source_aspect > 0.0 and bool(view.get("background_fills_canvas", false)) and absf(source_aspect - destination_aspect) <= 0.001


func _check_performance_liveness_guard_component() -> bool:
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(VisualStyleScript.GAME_BOARD_SIZE)
	root.add_child(canvas)
	canvas.call("render_game_snapshot", {
		"game_id": "blackjack",
		"surface_renderer": "blackjack",
		"surface_animates_idle": true,
		"reduce_motion": false,
		"table_round_timer": {
			"active": true,
			"started_msec": Time.get_ticks_msec(),
			"duration_msec": 12000,
			"remaining_msec": 12000,
		},
	})
	await process_frame
	canvas.set_process(false)
	canvas.call("reset_performance_counters")
	for _frame_index in range(24):
		await process_frame
	var counter := "surface_animation_redraw_count"
	var suppressed: Dictionary = canvas.call("performance_counters")
	var suppressed_check := PerformanceLivenessGuardScript.evaluate("UI regression blackjack surface", counter, 1, int(suppressed.get(counter, 0)))
	var expected_message := "UI regression blackjack surface liveness counter surface_animation_redraw_count advanced 0 time(s), below floor 1."
	if bool(suppressed_check.get("passed", true)) or str(suppressed_check.get("message", "")) != expected_message:
		canvas.queue_free()
		push_error("Forced idle-animation scheduling suppression did not fail with the surface/counter message: %s" % str(suppressed_check.get("message", "")))
		return false
	canvas.set_process(true)
	canvas.call("reset_performance_counters")
	for _frame_index in range(120):
		await process_frame
	var restored: Dictionary = canvas.call("performance_counters")
	var restored_check := PerformanceLivenessGuardScript.evaluate("UI regression blackjack surface", counter, 1, int(restored.get(counter, 0)))
	canvas.queue_free()
	await process_frame
	if not bool(restored_check.get("passed", false)):
		push_error("Restored idle-animation scheduling did not pass the liveness guard: %s" % str(restored_check.get("message", "")))
		return false
	return true


func _run_inventory_component_model(mode: String, container_id: String = "", selected: Dictionary = {}) -> Dictionary:
	var items: Array = []
	match mode:
		"pawn_counter":
			var pawn_item := _run_inventory_component_item("odds_notebook", "Odds Notebook", "carried", false)
			pawn_item["pawn_action"] = "pawn"
			pawn_item["lender_id"] = container_id
			pawn_item["loan_amount"] = 24
			var ticket_item := _run_inventory_component_item("lucky_coin", "Lucky Coin", "pawn_ticket", false)
			ticket_item["pawn_action"] = "redeem"
			ticket_item["lender_id"] = container_id
			ticket_item["debt_id"] = "sals_lucky_coin_ticket"
			ticket_item["payoff_amount"] = 15
			ticket_item["turns_remaining"] = 3
			ticket_item["pawn_action_enabled"] = true
			items = [pawn_item, ticket_item]
		"place_container":
			items = [_run_inventory_component_item("canvas_bag", "Canvas Bag", "carried", true)]
		"home_container":
			items = [
				_run_inventory_component_item("odds_notebook", "Odds Notebook", "carried", false),
				_run_inventory_component_item("odds_notebook", "Odds Notebook", "container", false),
			]
		_:
			items = [
				_run_inventory_component_item("odds_notebook", "Odds Notebook", "carried", false),
				_run_inventory_component_item("lucky_coin", "Lucky Coin", "carried", false),
			]
	var selected_value := selected
	if selected_value.is_empty():
		selected_value = {"id": str((items[0] as Dictionary).get("id", "")), "source": str((items[0] as Dictionary).get("storage_source", "carried"))}
	return {
		"mode": mode,
		"title": "Sell Items" if mode == "merchant_sale" else "Pawn Counter" if mode == "pawn_counter" else "Place Storage" if mode == "place_container" else "Home Box" if mode == "home_container" else "Inventory",
		"summary": "Standalone inventory component fixture.",
		"container_id": container_id,
		"selected": selected_value,
		"empty_text": "No run items yet.",
		"items": items,
		"layout": {"columns": 2},
	}


func _run_inventory_component_item(item_id: String, display_name: String, source: String, container: bool) -> Dictionary:
	var item := {
		"id": item_id,
		"display_name": display_name,
		"description": "Standalone component item.",
		"effect_summary": "Fixture effect.",
		"asset_path": "",
		"item_class": "container" if container else "tool",
		"domain": "global",
		"item_type": "fixture",
		"storage_source": source,
		"capacity": 4 if container else 0,
		"sellable": not container and source != "container",
		"sale_price": 12,
		"repairable": not container and source != "container",
		"repair_cost": 3,
		"active_item": not container and source != "container",
		"active_selected": false,
	}
	item["attribute_badges"] = AttributeBadgesScript.for_item({
		"id": item_id,
		"class": str(item.get("item_class", "tool")),
		"domain": str(item.get("domain", "global")),
		"sale_price": int(item.get("sale_price", 0)),
		"capacity": int(item.get("capacity", 0)),
		"effect": {"baseline_luck_delta": 1} if not container else {},
	})
	return item


func _run_inventory_test_texture(_asset_path: String) -> Texture2D:
	return null


class AllInLosingFixtureGame:
	extends GameModule

	func _init() -> void:
		setup({
			"id": "all_in_losing_fixture",
			"display_name": "All-In Fixture",
			"family": "fixture",
			"legal_actions": [{
				"id": "all_in_loss",
				"label": "All-in loss",
				"summary": "Guaranteed losing all-in wager.",
			}],
			"cheat_actions": [],
		})

	func actions(run_state: RunState, environment: Dictionary) -> Dictionary:
		return {
			"ok": true,
			"type": "game_actions",
			"game_id": get_id(),
			"legal_actions": legal_actions(run_state, environment),
			"cheat_actions": [],
			"stake_floor": 1,
			"stake_ceiling": maxi(1, run_state.bankroll),
			"base_stake_ceiling": maxi(1, run_state.bankroll),
			"economy_stake_ceiling": maxi(1, run_state.bankroll),
			"economy_state": run_state.economy(),
			"economy_pressure_applied": false,
		}

	func wager_cost_for_context(_action_id: String, stake: int, _run_state: RunState, _environment: Dictionary, _ui_state: Dictionary = {}) -> int:
		return maxi(0, stake)

	func resolve_with_context(action_id: String, stake: int, _run_state: RunState, environment: Dictionary, _rng: RngStream, _ui_state: Dictionary = {}) -> Dictionary:
		var deltas := GameModule.empty_result_deltas()
		deltas["bankroll_delta"] = -maxi(1, stake)
		deltas["messages"] = ["Fixture all-in wager lost after the bet resolved."]
		deltas["story_log"] = [{
			"type": "game_action",
			"game_id": get_id(),
			"action_id": action_id,
			"won": false,
			"stake_cost": maxi(1, stake),
			"bankroll_delta": -maxi(1, stake),
			"suspicion_delta": 0,
			"environment_id": str(environment.get("id", "")),
		}]
		var result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": get_id(),
			"game_id": get_id(),
			"action_id": action_id,
			"action_kind": "legal",
			"stake": maxi(1, stake),
			"bankroll_delta": -maxi(1, stake),
			"deltas": deltas,
			"won": false,
			"environment_id": str(environment.get("id", "")),
			"message": "Fixture all-in wager lost after the bet resolved.",
		})
		result["host_apply_result"] = true
		return result


class BankrollPresentationFixtureGame:
	extends GameModule

	const PRESENTATION_CHANNEL := "bankroll_fixture_reveal"
	const PRESENTATION_DURATION_MSEC := 300

	func _init() -> void:
		setup({
			"id": "bankroll_presentation_fixture",
			"display_name": "Bankroll Presentation Fixture",
			"family": "fixture",
			"full_simulation": true,
			"legal_actions": [{
				"id": "bankroll_fixture_win",
				"label": "Reveal win",
				"summary": "Deterministic animated win.",
			}],
			"cheat_actions": [],
		})

	func actions(run_state: RunState, environment: Dictionary) -> Dictionary:
		var ceiling := maxi(1, run_state.bankroll)
		var economic_profile: Dictionary = environment.get("economic_profile", {}) if typeof(environment.get("economic_profile", {})) == TYPE_DICTIONARY else {}
		if economic_profile.has("stake_ceiling"):
			ceiling = mini(ceiling, int(economic_profile.get("stake_ceiling", ceiling)))
		return {
			"ok": true,
			"type": "game_actions",
			"game_id": get_id(),
			"legal_actions": legal_actions(run_state, environment),
			"cheat_actions": [],
			"stake_floor": 10,
			"stake_ceiling": ceiling,
			"base_stake_ceiling": ceiling,
			"economy_stake_ceiling": ceiling,
			"economy_state": run_state.economy(),
			"economy_pressure_applied": false,
		}

	func wager_cost_for_context(_action_id: String, stake: int, _run_state: RunState, _environment: Dictionary, _ui_state: Dictionary = {}) -> int:
		return maxi(0, stake)

	func surface_state(_run_state: RunState, environment: Dictionary, _ui_state: Dictionary = {}) -> Dictionary:
		var fixture_state := _fixture_state(environment)
		var last_result: Dictionary = _ui_state.get("bankroll_fixture_last_result", {}) if typeof(_ui_state.get("bankroll_fixture_last_result", {})) == TYPE_DICTIONARY else {}
		if last_result.is_empty():
			last_result = fixture_state.get("last_result", {}) if typeof(fixture_state.get("last_result", {})) == TYPE_DICTIONARY else {}
		var animation_id := str(last_result.get("animation_id", ""))
		var started_msec := int(last_result.get("resolved_at_msec", 0))
		var active := not animation_id.is_empty() and started_msec > 0 and Time.get_ticks_msec() - started_msec < PRESENTATION_DURATION_MSEC
		return GameModule.surface_spec({
			"surface_renderer": "result",
			"surface_life": "result",
			"surface_controls_native": false,
			"surface_stake_controls_required": true,
			"surface_embeds_outcomes": true,
			"surface_realtime_state_refresh": false,
			"surface_animation_channels": [
				GameModule.surface_animation_channel(
					PRESENTATION_CHANNEL,
					animation_id if active else "",
					PRESENTATION_DURATION_MSEC if active else 0,
					started_msec
				),
			],
			"result_message": "" if active else str(last_result.get("summary", "")),
		})

	func resolve_with_context(action_id: String, stake: int, _run_state: RunState, environment: Dictionary, _rng: RngStream, _ui_state: Dictionary = {}) -> Dictionary:
		var wager := maxi(1, stake)
		var bankroll_delta := 40
		var started_msec := Time.get_ticks_msec()
		var fixture_state := _fixture_state(environment)
		var last_result := {
			"summary": "Fixture win revealed.",
			"bankroll_delta": bankroll_delta,
			"animation_id": "fixture:%d" % started_msec,
			"resolved_at_msec": started_msec,
		}
		fixture_state["last_result"] = last_result.duplicate(true)
		_store_fixture_state(environment, fixture_state)
		var deltas := GameModule.empty_result_deltas()
		deltas["bankroll_delta"] = bankroll_delta
		deltas["messages"] = ["Fixture win revealed."]
		deltas["story_log"] = [{
			"type": "game_action",
			"game_id": get_id(),
			"action_id": action_id,
			"won": true,
			"stake_cost": wager,
			"bankroll_delta": bankroll_delta,
			"suspicion_delta": 0,
			"environment_id": str(environment.get("id", "")),
		}]
		var result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": get_id(),
			"game_id": get_id(),
			"action_id": action_id,
			"action_kind": "legal",
			"stake": wager,
			"bankroll_delta": bankroll_delta,
			"deltas": deltas,
			"won": true,
			"environment_id": str(environment.get("id", "")),
			"message": "Fixture win revealed.",
			"surface_embeds_outcomes": true,
		})
		result["host_apply_result"] = true
		result["ui_state"] = {"bankroll_fixture_last_result": last_result}
		result["preserve_surface_ui_state"] = true
		return result

	func _fixture_state(environment: Dictionary) -> Dictionary:
		var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
		var state: Dictionary = states.get(get_id(), {}) if typeof(states.get(get_id(), {})) == TYPE_DICTIONARY else {}
		return state.duplicate(true)

	func _store_fixture_state(environment: Dictionary, fixture_state: Dictionary) -> void:
		var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
		states[get_id()] = fixture_state.duplicate(true)
		environment["game_states"] = states


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_use_isolated_user_settings(TEST_SETTINGS_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TEST_META_COLLECTION_PATH)
	if FileAccess.file_exists(TEST_META_COLLECTION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_META_COLLECTION_PATH))
	if VisualStyleScript.HOT != VisualStyleScript.PINK:
		push_error("VisualStyle.HOT should alias the production hot/pink token.")
		quit(1)
		return
	if not await _check_run_report_screen_component():
		quit(1)
		return
	if not await _check_run_inventory_screen_component():
		quit(1)
		return
	if not await _check_talk_dock_component():
		quit(1)
		return
	if not await _check_item_found_popup_component():
		quit(1)
		return
	if not await _check_world_map_selection_stable_component():
		quit(1)
		return
	if not await _check_performance_liveness_guard_component():
		quit(1)
		return

	var app: Control = MainScene.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	if app.get_script().resource_path != "res://scripts/ui/foundation_main.gd":
		push_error("Main scene is not wired to the foundation UI shell.")
		quit(1)
		return
	if not app.has_method("uses_foundation_runtime") or not bool(app.call("uses_foundation_runtime")):
		push_error("Foundation UI shell did not initialize the README runtime contracts.")
		quit(1)
		return
	if app.get("start_screen") == null:
		push_error("Main UI did not build the start screen.")
		quit(1)
		return
	if app.get("run_screen") == null:
		push_error("Main UI did not build the run screen.")
		quit(1)
		return
	if app.get("run_state") != null:
		push_error("Foundation UI shell should wait for player start before creating RunState.")
		quit(1)
		return
	var start_screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	if str(start_screen_snapshot.get("screen", "")) != "START":
		push_error("Foundation screen router did not start in START state.")
		quit(1)
		return
	var start_screen: Control = app.get("start_screen")
	var run_screen: Control = app.get("run_screen")
	if not start_screen.visible or run_screen.visible:
		push_error("Main UI should show the start/setup state before a run begins.")
		quit(1)
		return
	if not _visible_buttons_meet_touch_target(app, "start menu"):
		quit(1)
		return
	var save_service: SaveService = app.get("save_service")
	var continue_button: Button = app.get("continue_button")
	if continue_button == null:
		push_error("Main UI did not build the conditional Continue button.")
		quit(1)
		return
	var compile_save_slot := "foundation_ui_compile_autosave"
	var remove_error := _remove_save_slot(save_service, compile_save_slot)
	if remove_error != OK:
		push_error("Could not prepare an empty compile-test save slot.")
		quit(1)
		return
	app.set("autosave_slot_id", compile_save_slot)
	app.call("_refresh_start_screen")
	await process_frame
	var has_start_save := save_service.has_run(compile_save_slot)
	if not continue_button.visible:
		push_error("Main menu should keep the Continue selection visible in the 2x2 sign layout.")
		quit(1)
		return
	if has_start_save:
		push_error("Compile-test save slot should start empty.")
		quit(1)
		return
	if not continue_button.disabled:
		push_error("Continue button should be disabled when no foundation save exists.")
		quit(1)
		return
	if not _write_save_slot_text(save_service, compile_save_slot, "{}"):
		push_error("Could not create corrupt compile-test save for Continue state.")
		quit(1)
		return
	app.call("_refresh_start_screen")
	await process_frame
	var corrupt_status_label: Label = app.get("start_status_label")
	if corrupt_status_label == null or corrupt_status_label.text.find("corrupt") == -1:
		push_error("Main menu should surface corrupt unrecoverable save state.")
		quit(1)
		return
	if not continue_button.disabled:
		push_error("Continue button should stay disabled for an unrecoverable corrupt save.")
		quit(1)
		return
	remove_error = _remove_save_slot(save_service, compile_save_slot)
	if remove_error != OK:
		push_error("Could not clean corrupt compile-test save slot.")
		quit(1)
		return
	var continue_test_run: RunState = RunStateScript.new()
	continue_test_run.start_new("UI-COMPILE-CONTINUE-SAVE")
	var save_error := save_service.save_run(continue_test_run, compile_save_slot)
	if save_error != OK:
		push_error("Could not create compile-test save for Continue state.")
		quit(1)
		return
	app.call("_refresh_start_screen")
	await process_frame
	if continue_button.disabled:
		push_error("Continue button should be enabled when a foundation save exists.")
		quit(1)
		return
	var start_status_label: Label = app.get("start_status_label")
	if start_status_label == null or not start_status_label.visible or start_status_label.text.is_empty():
		push_error("Main menu should show clear Continue/save availability text.")
		quit(1)
		return
	if not _has_visible_text(app, "Simulated gambling only") or not _has_visible_text(app, "no real-money wagering"):
		push_error("Main menu did not present the simulated/no-real-money framing.")
		quit(1)
		return
	if _has_visible_text(app, "Game Test"):
		push_error("Release main menu exposed the temporary Game Test launcher.")
		quit(1)
		return
	var game_library_button: Button = app.get("game_library_button")
	var game_library_page: Control = app.get("game_test_menu")
	if game_library_button == null or game_library_page == null or not game_library_button.visible or game_library_button.disabled:
		push_error("Main menu did not expose the Games page.")
		quit(1)
		return
	var daily_run_button: Button = app.get("daily_run_button")
	if daily_run_button == null or not daily_run_button.visible or daily_run_button.disabled or not _has_visible_text(app, "Daily Run"):
		push_error("Release main menu did not expose the Daily Run challenge button.")
		quit(1)
		return
	var challenge_select_button: Button = app.get("challenge_select_button")
	var challenge_new_run_button: Button = app.get("new_run_button")
	var challenge_seed_input: LineEdit = app.get("seed_input")
	var menu_library: ContentLibrary = app.get("library")
	var challenge_snapshot: Dictionary = app.call("current_start_menu_snapshot")
	var menu_challenges: Array = challenge_snapshot.get("challenges", [])
	if menu_library == null or menu_library.challenges.is_empty():
		if challenge_select_button != null and challenge_select_button.visible:
			push_error("Main menu showed challenge selection without a loaded challenge pack.")
			quit(1)
			return
	else:
		if challenge_select_button == null or challenge_new_run_button == null or challenge_seed_input == null or not challenge_select_button.visible or challenge_select_button.disabled or menu_challenges.size() < 6:
			push_error("Main menu did not expose loaded challenge content.")
			quit(1)
			return
		var original_challenges: Array = menu_library.challenges.duplicate(true)
		menu_library.challenges = []
		app.call("_refresh_start_screen")
		await process_frame
		challenge_snapshot = app.call("current_start_menu_snapshot")
		if challenge_select_button.visible or not (challenge_snapshot.get("challenges", []) as Array).is_empty():
			push_error("Main menu showed challenges after the pack was empty.")
			quit(1)
			return
		menu_library.challenges = original_challenges
		app.call("_rebuild_challenge_options")
		app.call("_refresh_start_screen")
		await process_frame
		if not challenge_select_button.visible:
			push_error("Main menu did not restore challenge selection after the pack reloaded.")
			quit(1)
			return
		challenge_select_button.emit_signal("pressed")
		await process_frame
		challenge_snapshot = app.call("current_start_menu_snapshot")
		if not bool(challenge_snapshot.get("challenge_config_visible", false)):
			push_error("Challenge selector did not open from the main menu.")
			quit(1)
			return
		var challenge_buttons: Dictionary = app.get("challenge_buttons")
		var dry_run_button := challenge_buttons.get("dry_run", null) as Button
		if dry_run_button == null or not dry_run_button.visible:
			push_error("Challenge selector did not list Dry Run.")
			quit(1)
			return
		dry_run_button.emit_signal("pressed")
		await process_frame
		challenge_snapshot = app.call("current_start_menu_snapshot")
		if str(challenge_snapshot.get("selected_challenge_id", "")) != "dry_run":
			push_error("Challenge selector did not store the selected challenge id.")
			quit(1)
			return
		challenge_seed_input.text = "UI-DRY-RUN-SEED"
		challenge_new_run_button.emit_signal("pressed")
		await process_frame
		var dry_run_state: RunState = app.get("run_state")
		if dry_run_state == null or str(dry_run_state.challenge_config.get("id", "")) != "dry_run":
			push_error("New Run did not launch the selected authored challenge.")
			quit(1)
			return
		if bool(dry_run_state.service_hook_status(menu_library.service("house_drink")).get("available", true)):
			push_error("Dry Run challenge did not apply its alcohol service modifier in UI launch.")
			quit(1)
			return
		dry_run_state.run_status = RunState.RUN_STATUS_ENDED
		dry_run_state.narrative_flags["demo_victory"] = true
		dry_run_state.narrative_flags["demo_victory_message"] = "Demo Victory: challenge compile check."
		app.call("_route_ended_run_if_needed", {"message": "Challenge complete."})
		await process_frame
		var challenge_profile: ProfileInventory = app.get("profile_inventory")
		if challenge_profile == null or not challenge_profile.has_challenge_completion("challenge_dry_run_complete"):
			push_error("Challenge victory did not record the completion flag to the profile.")
			quit(1)
			return
		app.call("return_to_main_menu")
		await process_frame
		challenge_select_button = app.get("challenge_select_button")
		challenge_select_button.emit_signal("pressed")
		await process_frame
		challenge_buttons = app.get("challenge_buttons")
		var standard_button := challenge_buttons.get("", null) as Button
		if standard_button != null:
			standard_button.emit_signal("pressed")
			await process_frame
			app.call("close_challenge_selection")
			await process_frame
		if str((app.call("current_start_menu_snapshot") as Dictionary).get("selected_challenge_id", "")) != "":
			push_error("Challenge selector did not return to Standard Run.")
			quit(1)
			return
	var settings_button: Button = app.get("settings_button")
	var inventory_button: Button = app.get("inventory_button")
	var collections_button: Button = app.get("collections_button")
	var exit_game_button: Button = app.get("exit_game_button")
	var settings_menu: SettingsMenu = app.get("settings_menu")
	var inventory_page: Control = app.get("inventory_page")
	var start_menu_controls: Control = app.get("start_menu_controls")
	if settings_button == null or inventory_button == null or collections_button == null or exit_game_button == null or settings_menu == null or inventory_page == null or start_menu_controls == null:
		push_error("Main menu did not expose the required run, settings, inventory, and exit controls.")
		quit(1)
		return
	if collections_button.text != "Home":
		push_error("Meta collection launcher should be labeled Home on the main menu.")
		quit(1)
		return
	if not await _check_meta_home_launcher_opens_room(app):
		quit(1)
		return
	if not await _check_run_pawn_credit_is_immediate(app):
		quit(1)
		return
	if not exit_game_button.visible or exit_game_button.disabled:
		push_error("Main menu Exit Game button should be visible and enabled.")
		quit(1)
		return
	game_library_button.emit_signal("pressed")
	await process_frame
	if not game_library_page.visible or start_menu_controls.visible:
		push_error("Games button did not open the main-menu Games page.")
		quit(1)
		return
	if not _has_visible_text(game_library_page, "Game Library") or not _has_visible_text(game_library_page, "Practice any available table"):
		push_error("Games page did not present release-facing practice copy.")
		quit(1)
		return
	var library_for_games: ContentLibrary = app.get("library")
	var expected_game_names := _implemented_game_display_names(library_for_games)
	if expected_game_names.is_empty():
		push_error("Games page test could not find implemented game modules.")
		quit(1)
		return
	for display_name in expected_game_names:
		if not _has_visible_text(game_library_page, str(display_name)):
			push_error("Games page did not expose implemented game: %s." % str(display_name))
			quit(1)
			return
	if app.get("run_state") != null:
		push_error("Opening the Games page should not start or mutate a run.")
		quit(1)
		return
	app.call("close_game_test_menu")
	await process_frame
	if game_library_page.visible or not start_menu_controls.visible:
		push_error("Games page Back did not return to the main menu controls.")
		quit(1)
		return
	if not await _check_pull_tab_buy_button_single_activation(app):
		quit(1)
		return
	if not await _check_slot_autoplay_button_one_click(app):
		quit(1)
		return
	if not await _check_all_in_wager_confirmation_recovery(app):
		quit(1)
		return
	if not await _check_confirmed_all_in_wager_result_then_failure(app):
		quit(1)
		return
	if not await _check_presented_bankroll_waits_for_result_reveal(app):
		quit(1)
		return
	if not await _check_background_slot_autoplay_isolated_from_active_game(app):
		quit(1)
		return
	if not await _check_background_slot_all_in_confirmation(app):
		quit(1)
		return
	if settings_menu.visible:
		push_error("Settings menu should start closed on the main menu.")
		quit(1)
		return
	settings_button.emit_signal("pressed")
	await process_frame
	if not settings_menu.visible or start_menu_controls.visible:
		push_error("Settings button did not open the main menu settings panel.")
		quit(1)
		return
	if settings_menu.get("resolution") == null or settings_menu.get("master") == null or settings_menu.get("music") == null or settings_menu.get("sfx") == null or settings_menu.get("drunk_effect") == null or settings_menu.get("high_contrast") == null or settings_menu.get("play_on_small_screen") == null:
		push_error("Settings menu did not expose resolution, audio, drunk visual, and high-contrast controls.")
		quit(1)
		return
	var resolution_option: OptionButton = settings_menu.get("resolution")
	var mode_option: OptionButton = settings_menu.get("mode")
	var drunk_effect_option: OptionButton = settings_menu.get("drunk_effect")
	var high_contrast_check: CheckBox = settings_menu.get("high_contrast")
	var reduce_motion_check: CheckBox = settings_menu.get("reduce_motion")
	var audio_calm_check: CheckBox = settings_menu.get("audio_calm")
	var small_screen_check: CheckBox = settings_menu.get("play_on_small_screen")
	var ui_scale_slider: HSlider = settings_menu.get("ui")
	var text_size_option: OptionButton = settings_menu.get("text_size")
	if resolution_option.item_count < 2 or mode_option.item_count < 1:
		push_error("Settings menu did not populate resolution or window mode choices.")
		quit(1)
		return
	if drunk_effect_option.item_count < 2:
		push_error("Settings menu did not populate the drunk visual mode choices.")
		quit(1)
		return
	if high_contrast_check == null or reduce_motion_check == null or audio_calm_check == null or small_screen_check == null or ui_scale_slider == null or text_size_option == null:
		push_error("Settings menu did not expose release accessibility controls.")
		quit(1)
		return
	var user_settings: UserSettings = app.get("user_settings")
	var original_settings := {}
	if user_settings != null:
		original_settings = user_settings.to_dict()
	resolution_option.select(resolution_option.item_count - 1)
	resolution_option.item_selected.emit(resolution_option.item_count - 1)
	mode_option.select(0)
	mode_option.item_selected.emit(0)
	var target_high_contrast := true
	if not original_settings.is_empty():
		target_high_contrast = not bool(original_settings.get("high_contrast", false))
	high_contrast_check.button_pressed = target_high_contrast
	high_contrast_check.toggled.emit(target_high_contrast)
	reduce_motion_check.button_pressed = true
	reduce_motion_check.toggled.emit(true)
	audio_calm_check.button_pressed = true
	audio_calm_check.toggled.emit(true)
	small_screen_check.button_pressed = true
	small_screen_check.toggled.emit(true)
	ui_scale_slider.value = 130
	ui_scale_slider.value_changed.emit(130)
	text_size_option.select(2)
	text_size_option.item_selected.emit(2)
	settings_menu.call("_on_apply")
	await process_frame
	var accessibility_snapshot: Dictionary = app.call("current_accessibility_snapshot")
	if user_settings != null:
		if bool(user_settings.high_contrast) != target_high_contrast:
			push_error("Settings apply did not persist the high-contrast draft to live settings.")
			quit(1)
			return
		if not bool(user_settings.reduce_motion):
			push_error("Settings apply did not persist reduce motion.")
			quit(1)
			return
		if not bool(user_settings.audio_calm):
			push_error("Settings apply did not persist calmer music.")
			quit(1)
			return
		if not bool(user_settings.play_on_small_screen):
			push_error("Settings apply did not persist Play on small screen.")
			quit(1)
			return
		if str(user_settings.text_size) != "large" or absf(float(user_settings.ui_scale) - 1.3) > 0.001:
			push_error("Settings apply did not persist large text and UI scale.")
			quit(1)
			return
	if bool(VisualStyleScript.accessibility_snapshot().get("high_contrast_enabled", false)) != target_high_contrast:
		push_error("VisualStyle did not reflect the high-contrast setting.")
		quit(1)
		return
	if bool(accessibility_snapshot.get("showdown_motion_enabled", true)) or bool(accessibility_snapshot.get("terminal_motion_enabled", true)):
		push_error("Reduced motion did not disable showdown and terminal motion policy.")
		quit(1)
		return
	if bool(accessibility_snapshot.get("haptics_supported", true)) or str(accessibility_snapshot.get("haptics_cut_reason", "")).is_empty():
		push_error("Settings did not document the haptics release cut.")
		quit(1)
		return
	var small_screen_snapshot: Dictionary = accessibility_snapshot.get("small_screen", {}) if typeof(accessibility_snapshot.get("small_screen", {})) == TYPE_DICTIONARY else {}
	if not bool(small_screen_snapshot.get("enabled", false)) or float(small_screen_snapshot.get("minimum_control_height", 0.0)) < SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT:
		push_error("Play on small screen did not expose the centralized larger-target policy.")
		quit(1)
		return
	if not _visible_buttons_meet_touch_target(settings_menu, "small-screen settings", SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT - 0.5):
		quit(1)
		return
	var small_environment_snapshot: Dictionary = (app.get("environment_canvas") as Control).call("current_view_snapshot")
	var small_game_snapshot: Dictionary = (app.get("game_surface_canvas") as Control).call("current_view_snapshot")
	if not bool(small_environment_snapshot.get("small_screen_mode", false)) or not bool(small_game_snapshot.get("small_screen_mode", false)):
		push_error("Play on small screen did not reach both canvas interaction layers.")
		quit(1)
		return
	var map_controller: Variant = app.get("world_map_overlay_controller")
	var map_mode_snapshot: Dictionary = map_controller.call("export_state") if map_controller != null else {}
	var map_target_size: Variant = map_mode_snapshot.get("node_touch_target_size", Vector2.ZERO)
	if not bool(map_mode_snapshot.get("small_screen_mode", false)) or typeof(map_target_size) != TYPE_VECTOR2 or (map_target_size as Vector2).x < SmallScreenPolicyScript.MAP_NODE_TOUCH_TARGET_SIZE:
		push_error("Play on small screen did not enlarge world-map node targets.")
		quit(1)
		return
	var reloaded_settings: UserSettings = UserSettingsScript.new()
	reloaded_settings.load()
	if bool(reloaded_settings.high_contrast) != target_high_contrast or not bool(reloaded_settings.reduce_motion) or not bool(reloaded_settings.audio_calm) or not bool(reloaded_settings.play_on_small_screen) or str(reloaded_settings.text_size) != "large":
		push_error("Settings save/load did not preserve accessibility settings after restart.")
		quit(1)
		return
	if user_settings != null and not original_settings.is_empty():
		user_settings.from_dict(original_settings)
		user_settings.apply()
		VisualStyleScript.set_high_contrast_enabled(bool(original_settings.get("high_contrast", false)))
		user_settings.save()
		app.call("_on_settings_applied")
	if app.get("run_state") != null:
		push_error("Opening Settings should not start or mutate a run.")
		quit(1)
		return
	app.call("close_settings_menu")
	await process_frame
	if settings_menu.visible or not start_menu_controls.visible:
		push_error("Settings menu did not return to the main menu controls.")
		quit(1)
		return
	inventory_button.emit_signal("pressed")
	await process_frame
	if not inventory_page.visible or start_menu_controls.visible:
		push_error("Inventory button did not open the profile inventory page.")
		quit(1)
		return
	if app.get("profile_inventory") == null or app.get("acquire_chip_button") == null or app.get("inventory_items_list") == null:
		push_error("Profile inventory page did not expose storage controls.")
		quit(1)
		return
	if not _has_visible_text(app, "Profile Summary") or not _has_visible_text(app, "Recent Runs") or not _has_visible_text(app, "Completed Challenges"):
		push_error("Profile page did not expose summary, recent run, and completed challenge sections.")
		quit(1)
		return
	app.call("close_inventory_page")
	await process_frame
	if inventory_page.visible or not start_menu_controls.visible:
		push_error("Inventory page did not return to the main menu controls.")
		quit(1)
		return
	if app.get("save_status_label") == null:
		push_error("Main UI did not build the save status label.")
		quit(1)
		return
	var seed_input: LineEdit = app.get("seed_input")
	var new_run_button: Button = app.get("new_run_button")
	if seed_input == null or new_run_button == null:
		push_error("Main UI did not expose seed input and New Run button.")
		quit(1)
		return
	if seed_input.placeholder_text != "Enter run seed" or seed_input.tooltip_text.is_empty():
		push_error("Seed entry did not expose clear release menu guidance.")
		quit(1)
		return
	daily_run_button.emit_signal("pressed")
	await process_frame
	var daily_run_state: RunState = app.get("run_state")
	if daily_run_state == null:
		push_error("Daily Run button did not create a foundation RunState.")
		quit(1)
		return
	var today: Dictionary = Time.get_datetime_dict_from_system()
	var expected_daily_seed := str(app.call("_daily_challenge_seed_for_date", int(today.get("day", 1)), int(today.get("month", 1))))
	if daily_run_state.seed_text != expected_daily_seed:
		push_error("Daily Run did not use the date-derived hidden seed formula.")
		quit(1)
		return
	if str(daily_run_state.challenge_config.get("mode", "")) != "daily" or not daily_run_state.seed_is_hidden():
		push_error("Daily Run did not mark the run as a hidden-seed daily challenge.")
		quit(1)
		return
	if _has_visible_text(app, expected_daily_seed):
		push_error("Daily Run leaked the hidden seed into visible run UI.")
		quit(1)
		return
	app.call("open_run_menu")
	await process_frame
	var daily_run_menu: Dictionary = app.call("current_run_menu_snapshot")
	if str(daily_run_menu.get("status_text", "")).find(expected_daily_seed) != -1 or str(daily_run_menu.get("status_text", "")).find("Hidden daily challenge") == -1:
		push_error("Daily Run menu status did not hide the challenge seed.")
		quit(1)
		return
	app.call("close_run_menu")
	daily_run_state.fail_run(RunState.FAILURE_ABANDONED, "")
	app.call("_refresh")
	await process_frame
	var daily_failure_summary: Dictionary = app.call("current_run_report_snapshot")
	if str(daily_failure_summary.get("seed", "")).find(expected_daily_seed) != -1 or str(daily_failure_summary.get("seed", "")) != "Hidden daily challenge":
		push_error("Daily Run terminal summary did not hide the challenge seed.")
		quit(1)
		return
	if _has_visible_text(app, expected_daily_seed):
		push_error("Daily Run leaked the hidden seed into terminal UI.")
		quit(1)
		return
	app.call("return_to_main_menu")
	await process_frame
	var generated_seed_after_daily := seed_input.text.strip_edges()
	if generated_seed_after_daily.is_empty() or not generated_seed_after_daily.begins_with("RUN-"):
		push_error("Main menu did not generate a fresh random seed when it was accessed.")
		quit(1)
		return
	app.call("start_foundation_run", "UI-MENU-SEED-ROUNDTRIP")
	await process_frame
	app.call("return_to_main_menu")
	await process_frame
	var generated_seed_after_return := seed_input.text.strip_edges()
	if generated_seed_after_return.is_empty() or not generated_seed_after_return.begins_with("RUN-") or generated_seed_after_return == generated_seed_after_daily:
		push_error("Main menu did not regenerate the random seed on repeated access.")
		quit(1)
		return
	var start_menu_snapshot: Dictionary = app.call("current_start_menu_snapshot")
	if _has_visible_text(app, "READ") or _has_visible_text(app, "BUILD") or _has_visible_text(app, "ESCAPE"):
		push_error("Main menu still shows the old READ / BUILD / ESCAPE pillar boxes.")
		quit(1)
		return
	var collapsed_panel_size: Vector2 = start_menu_snapshot.get("menu_panel_size", Vector2.ZERO)
	if collapsed_panel_size.x > 800.0 or collapsed_panel_size.y > 560.0:
		push_error("Main menu panel did not shrink to fit the collapsed internal controls.")
		quit(1)
		return
	var menu_panel: Control = app.get("main_menu_panel")
	var collapsed_start_menu_controls: Control = app.get("start_menu_controls")
	var start_menu_stack: Control = app.get("start_menu_stack")
	if _control_tree_has_scroll_container(menu_panel):
		push_error("Main menu should fit its interface without a scrollbar.")
		quit(1)
		return
	if menu_panel == null or collapsed_start_menu_controls == null or not _control_rect_inside(collapsed_start_menu_controls, menu_panel):
		push_error("Main menu controls do not fit inside the menu panel.")
		quit(1)
		return
	if start_menu_stack == null or not _control_rect_inside(start_menu_stack, menu_panel):
		push_error("Main menu stack does not fit inside the menu panel.")
		quit(1)
		return
	var collapsed_menu_rect := _snapshot_rect(start_menu_snapshot.get("menu_panel_rect", {}))
	var collapsed_stack_rect := _snapshot_rect(start_menu_snapshot.get("start_menu_stack_rect", {}))
	if collapsed_menu_rect.size.x <= 0.0 or collapsed_stack_rect.size.x <= 0.0 or not collapsed_menu_rect.grow(1.0).encloses(collapsed_stack_rect):
		push_error("Main menu snapshot shows clipped collapsed content: panel=%s stack=%s." % [str(collapsed_menu_rect), str(collapsed_stack_rect)])
		quit(1)
		return
	var content_group_options: Array = start_menu_snapshot.get("content_groups", [])
	if content_group_options.size() < 8:
		push_error("Main menu did not expose modular run content groups.")
		quit(1)
		return
	var content_group_config_button: Button = app.get("content_group_config_button")
	var content_group_panel: Control = app.get("content_group_panel")
	if content_group_config_button == null or content_group_panel == null:
		push_error("Main menu did not expose the seed-box content gear and panel.")
		quit(1)
		return
	if content_group_config_button.text != "⚙" or content_group_config_button.icon != null:
		push_error("Main menu content configuration button did not use the seed-box gear icon.")
		quit(1)
		return
	if not content_group_config_button.visible or content_group_panel.visible:
		push_error("Main menu content configuration should start collapsed behind the seed-box gear.")
		quit(1)
		return
	content_group_config_button.emit_signal("pressed")
	await process_frame
	await process_frame
	start_menu_snapshot = app.call("current_start_menu_snapshot")
	if not content_group_panel.visible or not bool(start_menu_snapshot.get("content_group_config_visible", false)):
		push_error("Seed-box content gear did not open the run content configuration panel.")
		quit(1)
		return
	var expanded_panel_size: Vector2 = start_menu_snapshot.get("menu_panel_size", Vector2.ZERO)
	if expanded_panel_size.x < 880.0 or expanded_panel_size.y < 340.0 or expanded_panel_size.y > 520.0:
		push_error("Main menu panel did not resize cleanly around the opened run content controls.")
		quit(1)
		return
	var expanded_menu_rect := _snapshot_rect(start_menu_snapshot.get("menu_panel_rect", {}))
	var expanded_stack_rect := _snapshot_rect(start_menu_snapshot.get("start_menu_stack_rect", {}))
	if expanded_menu_rect.size.x <= 0.0 or expanded_stack_rect.size.x <= 0.0 or not expanded_menu_rect.grow(1.0).encloses(expanded_stack_rect):
		push_error("Main menu snapshot shows clipped expanded content: panel=%s stack=%s." % [str(expanded_menu_rect), str(expanded_stack_rect)])
		quit(1)
		return
	var viewport_size := root.get_visible_rect().size
	var menu_rect := menu_panel.get_global_rect() if menu_panel != null else Rect2()
	var content_panel_rect := content_group_panel.get_global_rect()
	if menu_rect.position.y < 16.0 or menu_rect.end.y > viewport_size.y - 16.0:
		push_error("Expanded main menu panel did not remain inside the viewport with a readable margin.")
		quit(1)
		return
	if content_panel_rect.size.x < 700.0 or content_panel_rect.size.y < 200.0:
		push_error("Run Content drawer is too small to present the content groups cleanly.")
		quit(1)
		return
	if content_panel_rect.position.x < menu_rect.position.x or content_panel_rect.end.x > menu_rect.end.x or content_panel_rect.end.y > menu_rect.end.y:
		push_error("Run Content drawer does not fit inside the expanded main menu panel.")
		quit(1)
		return
	var content_group_toggles: Dictionary = app.get("content_group_toggles")
	var pull_tabs_toggle := content_group_toggles.get("pull_tabs_pack", null) as CheckBox
	if pull_tabs_toggle == null:
		push_error("Main menu did not expose a pull-tabs content group toggle.")
		quit(1)
		return
	for toggle_value in content_group_toggles.values():
		var toggle := toggle_value as CheckBox
		if toggle == null:
			continue
		var toggle_rect := toggle.get_global_rect()
		if toggle_rect.size.x < 260.0 or toggle_rect.size.y < 28.0 or not content_panel_rect.encloses(toggle_rect):
			push_error("Run Content group toggle layout is cramped or outside the drawer.")
			quit(1)
			return
	pull_tabs_toggle.button_pressed = false
	await process_frame
	seed_input.text = "UI-CONTENT-GROUP-SEED"
	new_run_button.emit_signal("pressed")
	await process_frame
	var grouped_run_state: RunState = app.get("run_state")
	if grouped_run_state == null:
		push_error("New Run with content groups did not create a RunState.")
		quit(1)
		return
	var group_modifiers: Dictionary = grouped_run_state.challenge_config.get("modifiers", {})
	var enabled_groups: Array = group_modifiers.get("content_groups", [])
	if enabled_groups.has("pull_tabs_pack") or enabled_groups.is_empty():
		push_error("New Run did not preserve the disabled pull-tabs content group selection.")
		quit(1)
		return
	var grouped_environment: Dictionary = app.call("current_environment_view_snapshot")
	for offer_value in (grouped_environment.get("item_offers", []) as Array):
		if typeof(offer_value) == TYPE_DICTIONARY and str((offer_value as Dictionary).get("id", "")) == "xray_glasses":
			push_error("Disabled pull-tabs group still surfaced a pull-tab item in the first shop.")
			quit(1)
			return
	app.call("return_to_main_menu")
	await process_frame
	pull_tabs_toggle = (app.get("content_group_toggles") as Dictionary).get("pull_tabs_pack", null) as CheckBox
	if pull_tabs_toggle != null:
		pull_tabs_toggle.button_pressed = true
		await process_frame
	seed_input.text = "UI-COMPILE-SEED"
	new_run_button.emit_signal("pressed")
	await process_frame
	if app.get("run_state") == null:
		push_error("New Run button did not create a foundation RunState.")
		quit(1)
		return
	var started_run_state: RunState = app.get("run_state")
	if started_run_state.seed_text != "UI-COMPILE-SEED":
		push_error("New Run did not start with the entered seed.")
		quit(1)
		return
	var run_screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	if str(run_screen_snapshot.get("screen", "")) != "ENVIRONMENT":
		push_error("Foundation screen router did not move to ENVIRONMENT after starting a run.")
		quit(1)
		return
	if start_screen.visible or not run_screen.visible:
		push_error("Main UI did not move from setup to run state after New Run.")
		quit(1)
		return
	if app.get("top_menu_button") == null or app.get("top_settings_button") == null or app.get("top_inventory_button") == null:
		push_error("Run HUD did not expose Menu, Settings, and Inventory buttons together.")
		quit(1)
		return
	var procedural_music_player = app.get("procedural_music_player")
	if procedural_music_player == null:
		push_error("Main UI did not create the procedural music player.")
		quit(1)
		return
	var generated_music: AudioStreamWAV = procedural_music_player.call("preview_stream_for_environment", app.get("run_state").current_environment, 70)
	if generated_music == null:
		push_error("Procedural music player did not generate an environment stream.")
		quit(1)
		return
	if generated_music.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		push_error("Generated environment music stream should loop.")
		quit(1)
		return
	if generated_music.format != AudioStreamWAV.FORMAT_16_BITS \
			or generated_music.mix_rate != 44100 \
			or generated_music.stereo \
			or generated_music.loop_begin != 0 \
			or generated_music.data.size() != generated_music.loop_end * 2:
		push_error("Generated environment music stream did not preserve its exact mono PCM/loop contract.")
		quit(1)
		return
	if generated_music.data.size() <= 22050:
		push_error("Generated environment music stream did not contain enough PCM data.")
		quit(1)
		return
	if generated_music.loop_end < 22050 * 24:
		push_error("Generated environment music should be a longer arranged theme, not a short repeated loop.")
		quit(1)
		return
	var preview_profile: Dictionary = procedural_music_player.call("_music_profile_from_environment", app.get("run_state").current_environment, 70)
	var preview_probe_context: Dictionary = procedural_music_player.call("_ambient_generation_context", preview_profile)
	preview_probe_context["frames"] = 13
	preview_probe_context["duration"] = 13.0 / 44100.0
	var preview_probe_a: PackedByteArray = procedural_music_player.call("_ambient_pcm_data", preview_probe_context)
	var preview_probe_b: PackedByteArray = procedural_music_player.call("_ambient_pcm_data", preview_probe_context)
	if preview_probe_a != preview_probe_b or preview_probe_a.size() != 26:
		push_error("Procedural music preview generation was not deterministic for identical context.")
		quit(1)
		return
	for stride_start in range(0, 13, 4):
		var stride_end := mini(stride_start + 4, 13)
		for frame_index in range(stride_start + 1, stride_end):
			var source_byte_index := stride_start * 2
			var frame_byte_index := frame_index * 2
			if preview_probe_a[source_byte_index] != preview_probe_a[frame_byte_index] \
					or preview_probe_a[source_byte_index + 1] != preview_probe_a[frame_byte_index + 1]:
				push_error("Procedural music preview render stride did not repeat exact PCM samples.")
				quit(1)
				return
	var music_theory: Dictionary = procedural_music_player.call("music_theory_snapshot_for_environment", app.get("run_state").current_environment, 70)
	if music_theory.is_empty() or str(music_theory.get("mode", "")).is_empty():
		push_error("Procedural music player did not expose a generated mode/harmony plan.")
		quit(1)
		return
	if (music_theory.get("progression_degrees", []) as Array).size() < 4:
		push_error("Generated environment music should use a multi-chord progression.")
		quit(1)
		return
	if (music_theory.get("chord_intervals", []) as Array).size() < 4:
		push_error("Generated environment music did not derive diatonic chord voicings.")
		quit(1)
		return
	if (music_theory.get("motif", []) as Array).size() < 8:
		push_error("Generated environment music did not expose a reusable melodic motif.")
		quit(1)
		return
	if str(music_theory.get("arrangement_form", "")) != "AABA" or float(music_theory.get("swing_amount", -1.0)) < 0.0:
		push_error("Procedural music theory snapshot did not expose swing and AABA form.")
		quit(1)
		return
	if (music_theory.get("voicing_inversions", []) as Array).is_empty() or (music_theory.get("instrument_palette", {}) as Dictionary).is_empty():
		push_error("Procedural music theory snapshot did not expose voice-led inversions and palette fields.")
		quit(1)
		return
	var music_latency: Dictionary = procedural_music_player.call("music_generation_latency_snapshot_for_environment", app.get("run_state").current_environment, 70)
	if music_latency.is_empty():
		push_error("Procedural music player did not expose staged generation timing.")
		quit(1)
		return
	if int(music_latency.get("primer_frames", 0)) <= 0 or int(music_latency.get("full_frames", 0)) <= 0:
		push_error("Staged procedural music generation did not produce usable frame counts.")
		quit(1)
		return
	if int(music_latency.get("full_frames", 0)) != generated_music.loop_end:
		push_error("Generated environment music loop frames did not match its generation contract.")
		quit(1)
		return
	if int(music_latency.get("instant_frames", 0)) <= 0:
		push_error("Live procedural music did not expose an immediate bed frame count.")
		quit(1)
		return
	if int(music_latency.get("primer_frames", 0)) >= int(music_latency.get("full_frames", 0)):
		push_error("Live procedural music primer should be shorter than the full arranged stream.")
		quit(1)
		return
	if float(music_latency.get("instant_seconds", 999.0)) > 1.5:
		push_error("Live procedural music immediate bed is too long to generate at travel arrival.")
		quit(1)
		return
	if float(music_latency.get("primer_seconds", 999.0)) > 4.0:
		push_error("Live procedural music primer is too long to solve first-playback latency.")
		quit(1)
		return
	if float(music_latency.get("web_bed_seconds", 0.0)) < 30.0:
		push_error("Web procedural music bed should not collapse to a short repeated loop.")
		quit(1)
		return
	if int(music_latency.get("web_bed_pcm_bytes", 0)) > int(music_latency.get("web_bed_bridge_cap_bytes", 0)):
		push_error("Web procedural music bed exceeded the browser PCM bridge budget.")
		quit(1)
		return
	var transition_policy: Dictionary = procedural_music_player.call("music_transition_policy_snapshot_for_environment", app.get("run_state").current_environment, 70)
	if transition_policy.is_empty() or not bool(transition_policy.get("deferred_stream_changes", false)):
		push_error("Procedural music player did not expose deferred breakpoint transitions.")
		quit(1)
		return
	if int(transition_policy.get("break_steps", 0)) < 4 or float(transition_policy.get("break_seconds", 0.0)) <= 0.0:
		push_error("Procedural music transitions should wait for a musical break point.")
		quit(1)
		return
	var music_fx_state: Dictionary = app.call("music_fx_state_snapshot")
	var music_fx_environment: Dictionary = music_fx_state.get("environment", {}) as Dictionary
	if music_fx_environment.has("game_states"):
		push_error("Music FX snapshot leaked environment game_states into the live refresh payload.")
		quit(1)
		return
	var music_fx_snapshot: Dictionary = procedural_music_player.call("music_fx_snapshot", music_fx_state)
	var music_fx_graph: Dictionary = music_fx_snapshot.get("graph", {}) as Dictionary
	var music_fx_target: Dictionary = music_fx_snapshot.get("target", {}) as Dictionary
	if int(music_fx_graph.get("effect_count", 0)) != 4 or JSON.stringify(music_fx_graph.get("effects", [])).find("AudioEffectPitchShift") < 0:
		push_error("Procedural music FX graph did not expose shared pitch compensation plus the character/safety chain.")
		quit(1)
		return
	var music_send_graph: Dictionary = music_fx_graph.get("send_buses", {}) as Dictionary
	var music_send_buses: Dictionary = music_send_graph.get("buses", {}) as Dictionary
	var expected_music_sends := {
		"band_pass": "AudioEffectBandPassFilter",
		"delay": "AudioEffectDelay",
		"distortion": "AudioEffectDistortion",
		"reverb": "AudioEffectReverb",
		"compressor": "AudioEffectCompressor",
	}
	for send_key in expected_music_sends.keys():
		var send_bus: Dictionary = music_send_buses.get(send_key, {}) as Dictionary
		if str(send_bus.get("send", "")) != "Music" \
				or str(send_bus.get("effect_type", "")) != str(expected_music_sends.get(send_key, "")) \
				or not bool(send_bus.get("independent_role_sends", false)):
			push_error("Procedural music %s send bus did not expose independent per-instrument routing." % send_key)
			quit(1)
			return
	if float(music_fx_target.get("reverb_size", 0.0)) <= 0.0 or not music_fx_target.has("lowpass_cutoff_hz"):
		push_error("Procedural music FX snapshot did not expose mapped DSP parameters.")
		quit(1)
		return
	if bool(music_fx_snapshot.get("player_instantiated", true)):
		push_error("Headless UI should not instantiate procedural music playback.")
		quit(1)
		return
	var music_manifest_environment: Dictionary = (app.get("run_state").current_environment as Dictionary).duplicate(true)
	var music_manifest_game_states: Dictionary = music_manifest_environment.get("game_states", {}) if typeof(music_manifest_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	music_manifest_game_states["ui_compile_perf_fixture"] = {"large_runtime_state": ["not_for_music_payloads"]}
	music_manifest_environment["game_states"] = music_manifest_game_states
	var music_stem_manifest: Dictionary = procedural_music_player.call("music_stem_manifest_snapshot_for_environment", music_manifest_environment, 70)
	var manifest_music_state: Dictionary = music_stem_manifest.get("music_state", {}) as Dictionary
	var manifest_environment: Dictionary = manifest_music_state.get("environment", {}) as Dictionary
	if manifest_environment.has("game_states"):
		push_error("Procedural music environment snapshots should strip game_states before normalization.")
		quit(1)
		return
	if music_stem_manifest.is_empty() or not bool(music_stem_manifest.get("sync_ok", false)):
		push_error("Procedural music stem manifest did not expose synchronized loop metadata.")
		quit(1)
		return
	if str(music_stem_manifest.get("source", "")) == "authored" and int(music_stem_manifest.get("loop_frames", 0)) < 44100 * 12:
		push_error("Authored environment music should be a long ambient bed, not a short repeated fixture loop.")
		quit(1)
		return
	if str(music_stem_manifest.get("source", "")) == "authored" and not bool(music_stem_manifest.get("sparse", false)):
		push_error("Authored sparse music fixture should expose absent roles as silent.")
		quit(1)
		return
	var music_mix_snapshot: Dictionary = procedural_music_player.call("music_mix_snapshot", music_fx_state)
	var music_mix_target: Dictionary = music_mix_snapshot.get("target", {}) as Dictionary
	if not music_mix_target.has("drums_high") or not music_mix_target.has("tension") or not music_mix_target.has("bass_dark"):
		push_error("MusicDirector mix snapshot did not expose stem gain targets.")
		quit(1)
		return
	if bool(music_mix_snapshot.get("player_instantiated", true)):
		push_error("Headless UI should not instantiate stem music playback.")
		quit(1)
		return
	var feature_music_snapshot: Dictionary = procedural_music_player.call("music_feature_snapshot", {
		"active": true,
		"cue_id": "bonus_music_fixture",
		"feature_music": {"cue_id": "bonus_music_fixture", "duck_background_music": true},
	}, 0.25)
	var feature_music_target: Dictionary = feature_music_snapshot.get("target", {}) as Dictionary
	if float(feature_music_target.get("feature", 0.0)) <= 0.0 or float(feature_music_target.get("venue_duck", 0.0)) <= 0.0:
		push_error("MusicDirector feature snapshot did not expose feature layer and duck targets.")
		quit(1)
		return
	if bool(feature_music_snapshot.get("player_instantiated", true)):
		push_error("Headless UI should not instantiate feature music playback.")
		quit(1)
		return
	app.call("_on_game_surface_music_cue", "bonus_music_pinball", {
		"feature_scene": {
			"active": true,
			"scene_id": "pinball_fixture",
		},
		"feature_music": {
			"cue_id": "bonus_music_pinball",
			"loop": true,
			"volume_db": -21.0,
		},
	})
	var pinball_feature_snapshot: Dictionary = procedural_music_player.call("music_feature_snapshot", {}, 0.05)
	var pinball_feature_input: Dictionary = pinball_feature_snapshot.get("input", {}) as Dictionary
	if str(pinball_feature_snapshot.get("active_music_id", "")) != "pinball_fixture|bonus_music_pinball":
		push_error("Pinball feature music cue did not become the active MusicDirector feature layer.")
		quit(1)
		return
	if bool(pinball_feature_input.get("duck_background_music", true)):
		push_error("Pinball feature music should not depend on background ducking to stay active.")
		quit(1)
		return
	if float(pinball_feature_input.get("volume_db", 0.0)) > -20.5:
		push_error("Pinball feature music should use the quieter release alert volume.")
		quit(1)
		return
	procedural_music_player.call("play_feature_stinger", "pinball_feature_intro", {"volume_db": -8.5})
	app.call("_sync_surface_feature_music_state", {
		"slot_feature_scene": {
			"active": false,
		},
	})
	var stopped_feature_snapshot: Dictionary = procedural_music_player.call("music_feature_snapshot", {}, 0.05)
	if not str(stopped_feature_snapshot.get("active_music_id", "")).is_empty():
		push_error("Slot feature music did not clear when the surface bonus scene ended.")
		quit(1)
		return
	if not (stopped_feature_snapshot.get("pending_stingers", []) as Array).is_empty():
		push_error("Slot feature stingers did not clear when feature music was force-stopped.")
		quit(1)
		return
	var slot_sfx := SfxPlayerScript.new()
	var lever_sfx: AudioStreamWAV = slot_sfx.preview_event_stream("lever")
	var reel_loop_sfx: AudioStreamWAV = slot_sfx.preview_event_stream("reel_loop")
	var jackpot_sfx: AudioStreamWAV = slot_sfx.preview_event_stream("jackpot")
	var pull_tab_thump_sfx: AudioStreamWAV = slot_sfx.preview_event_stream("pull_tab_thump")
	var paper_peel_sfx: AudioStreamWAV = slot_sfx.preview_event_stream("paper_peel")
	var pinball_money_sfx: AudioStreamWAV = slot_sfx.preview_event_stream("pinball_money_ding")
	if lever_sfx == null or reel_loop_sfx == null or jackpot_sfx == null or pull_tab_thump_sfx == null or paper_peel_sfx == null or pinball_money_sfx == null:
		push_error("SFX player did not generate required procedural streams.")
		quit(1)
		return
	if lever_sfx.data.size() <= 2048 or jackpot_sfx.data.size() <= lever_sfx.data.size():
		push_error("SFX streams are too small to represent distinct machine events.")
		quit(1)
		return
	if pull_tab_thump_sfx.data.size() <= 2048 or paper_peel_sfx.data.size() <= 2048:
		push_error("Pull-tab SFX streams are too small to represent dispenser and paper events.")
		quit(1)
		return
	if pinball_money_sfx.data.size() <= 2048:
		push_error("Pinball money ding SFX is too small to represent a positive hit cue.")
		quit(1)
		return
	if reel_loop_sfx.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		push_error("Slot reel whirr SFX should loop while reels are spinning.")
		quit(1)
		return
	slot_sfx.free()
	var viewport_rect := app.get_viewport().get_visible_rect()
	if viewport_rect.size.x < 1279.0 or viewport_rect.size.y < 719.0:
		push_error("UI scene compile check is not running at the 1280x720 target viewport: %s." % str(viewport_rect))
		quit(1)
		return
	if not _control_fits_viewport(run_screen, viewport_rect, "run screen"):
		quit(1)
		return
	if not _control_fits_viewport(app.get("environment_canvas"), viewport_rect, "environment canvas"):
		quit(1)
		return
	if not _control_fits_viewport(app.get("game_surface_canvas"), viewport_rect, "game surface canvas"):
		quit(1)
		return
	if not _control_fits_viewport(app.get("consequence_cards_scroll"), viewport_rect, "consequence cards scroll"):
		quit(1)
		return
	if not _check_game_surface_touch_hit_policy():
		quit(1)
		return
	if not _visible_buttons_meet_touch_target(app, "initial run screen"):
		quit(1)
		return
	var initial_environment_canvas: Control = app.get("environment_canvas")
	var initial_game_surface: Control = app.get("game_surface_canvas")
	if initial_environment_canvas == null or not initial_environment_canvas.visible:
		push_error("M1.6B environment mode did not keep the environment canvas primary and visible.")
		quit(1)
		return
	if not _control_clips_contents(initial_environment_canvas, "environment canvas"):
		quit(1)
		return
	if not _environment_canvas_keeps_critical_ui_clear(app, initial_environment_canvas, viewport_rect, "environment canvas"):
		quit(1)
		return
	if initial_game_surface != null and initial_game_surface.visible:
		push_error("M1.6B environment mode still showed the game surface as a competing preview.")
		quit(1)
		return
	var layout_serialized_before := JSON.stringify(app.call("serialized_run_state"))
	var spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	var spatial_objects: Array = spatial_snapshot.get("objects", [])
	if spatial_objects.is_empty():
		push_error("M1.6 spatial interaction model did not expose interactable objects.")
		quit(1)
		return
	for field in ["hover_target_id", "focus_target_id", "selected_object_id", "camera_focus_rect", "camera_focus_point", "current_context_mode"]:
		if not spatial_snapshot.has(field):
			push_error("M1.6 spatial interaction snapshot is missing UI-local field: %s." % field)
			quit(1)
			return
	var has_shop_start_objects := not _interactable_by_type(spatial_objects, "item").is_empty() and not _interactable_by_type(spatial_objects, "shopkeeper").is_empty()
	var has_home_start_objects := not _interactable_by_type(spatial_objects, "home_tenure").is_empty() and not _interactable_by_type(spatial_objects, "home_sleep").is_empty() and not _interactable_by_type(spatial_objects, "home_storage").is_empty()
	if not has_shop_start_objects and not has_home_start_objects:
		push_error("M1.6 spatial interaction model did not expose the expected shop-start or home-start objects.")
		quit(1)
		return
	if _interactable_by_type(spatial_objects, "travel").is_empty():
		push_error("M1.6 spatial interaction model did not expose travel objects from foundation state.")
		quit(1)
		return
	if not _interactable_copy_is_concise(spatial_objects, "initial room objects"):
		quit(1)
		return
	var first_interactable: Dictionary = spatial_objects[0]
	for field in ["object_id", "object_type", "source_id", "label", "enabled", "normalized_rect", "focus_point", "available_actions"]:
		if not first_interactable.has(field):
			push_error("M1.6 interactable object is missing field: %s." % field)
			quit(1)
			return
	var serialized_before_focus := JSON.stringify(app.call("serialized_run_state"))
	var focus_object_id := str(first_interactable.get("object_id", ""))
	if not bool(app.call("focus_interactable_object", focus_object_id)):
		push_error("M1.6 spatial interaction model rejected a valid focus object.")
		quit(1)
		return
	await process_frame
	if serialized_before_focus != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.6 focusing an interactable object mutated serialized RunState.")
		quit(1)
		return
	var focused_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	if str(focused_snapshot.get("selected_object_id", "")) != focus_object_id or str(focused_snapshot.get("focus_target_id", "")) != focus_object_id:
		push_error("M1.6 focus state was not stored as UI-local state.")
		quit(1)
		return
	if str(first_interactable.get("object_type", "")) == "game":
		var focused_summary_label := app.get("summary_label") as Label
		if focused_summary_label == null or focused_summary_label.text.find("Double-click") == -1:
			push_error("M1.6 focused game object did not expose world-surface interaction guidance.")
			quit(1)
			return
	var focus_canvas: Control = app.get("environment_canvas")
	var focus_canvas_snapshot: Dictionary = focus_canvas.call("current_view_snapshot")
	if not bool(focus_canvas_snapshot.get("camera_focus_active", false)) or float(focus_canvas_snapshot.get("target_camera_zoom", 1.0)) <= 1.0:
		push_error("M1.6 camera focus did not zoom/emphasize a selected object.")
		quit(1)
		return
	if not await _focus_camera_animation_is_stable(focus_canvas, "focused environment canvas"):
		quit(1)
		return
	if not bool(focus_canvas_snapshot.get("clip_contents", false)) or not _control_clips_contents(focus_canvas, "focused environment canvas"):
		quit(1)
		return
	if not _canvas_preserves_art_aspect(focus_canvas_snapshot, "focused environment canvas"):
		quit(1)
		return
	if not _environment_canvas_keeps_critical_ui_clear(app, focus_canvas, viewport_rect, "focused environment canvas"):
		quit(1)
		return
	if not bool(app.call("hover_interactable_object", focus_object_id)):
		push_error("M1.6 spatial interaction model rejected a valid hover object.")
		quit(1)
		return
	if serialized_before_focus != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.6 hovering an interactable object mutated serialized RunState.")
		quit(1)
		return
	app.call("clear_interaction_focus")
	await process_frame
	var cleared_spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	if str(cleared_spatial_snapshot.get("current_context_mode", "")) != "room" or not str(cleared_spatial_snapshot.get("selected_object_id", "")).is_empty():
		push_error("M1.6 clear focus did not return to room presentation state.")
		quit(1)
		return
	var cleared_canvas_snapshot: Dictionary = focus_canvas.call("current_view_snapshot")
	if bool(cleared_canvas_snapshot.get("camera_focus_active", true)) or float(cleared_canvas_snapshot.get("target_camera_zoom", 0.0)) != 1.0:
		push_error("M1.6 Back to room did not restore the full-room camera target.")
		quit(1)
		return
	if not _environment_canvas_keeps_critical_ui_clear(app, focus_canvas, viewport_rect, "cleared environment canvas"):
		quit(1)
		return
	if serialized_before_focus != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.6 clearing focus mutated serialized RunState.")
		quit(1)
		return
	var live_environment_canvas: Control = app.get("environment_canvas")
	var canvas_snapshot: Dictionary = live_environment_canvas.call("current_view_snapshot")
	var object_layout: Dictionary = canvas_snapshot.get("object_layout", {})
	if int(object_layout.get("overlap_count", -1)) != 0:
		push_error("Environment object layout allowed overlapping room props: %s." % str(object_layout.get("overlaps", [])))
		quit(1)
		return
	var canvas_object := _canvas_object_by_id(canvas_snapshot.get("objects", []), focus_object_id)
	if canvas_object.is_empty():
		push_error("M1.6 canvas did not receive InteractableObject records for visible hotspots.")
		quit(1)
		return
	if not _canvas_preserves_art_aspect(canvas_snapshot, "live environment canvas"):
		quit(1)
		return
	var click_position := _canvas_local_center_for_object(live_environment_canvas, canvas_object)
	var serialized_before_canvas_click := JSON.stringify(app.call("serialized_run_state"))
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = click_position
	live_environment_canvas.call("_gui_input", motion_event)
	await process_frame
	var hovered_spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	if str(hovered_spatial_snapshot.get("hover_target_id", "")) != focus_object_id:
		push_error("M1.6 hovering a canvas hotspot did not update UI-local hover state.")
		quit(1)
		return
	if serialized_before_canvas_click != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.6 hovering a canvas hotspot mutated serialized RunState.")
		quit(1)
		return
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = click_position
	live_environment_canvas.call("_gui_input", click_event)
	await process_frame
	var clicked_spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	if str(clicked_spatial_snapshot.get("selected_object_id", "")) != focus_object_id:
		push_error("M1.6 clicking a canvas hotspot did not update UI-local selection state.")
		quit(1)
		return
	var clicked_canvas_snapshot: Dictionary = live_environment_canvas.call("current_view_snapshot")
	var selected_info: Dictionary = clicked_canvas_snapshot.get("selected_info", {})
	var selected_info_lines: Array = selected_info.get("lines", [])
	if not bool(selected_info.get("visible", false)) or str(selected_info.get("object_id", "")) != focus_object_id:
		push_error("M1.6 selected canvas hotspot did not expose an in-scene description card.")
		quit(1)
		return
	if str(selected_info.get("title", "")).strip_edges().is_empty() and selected_info_lines.is_empty():
		push_error("M1.6 selected canvas hotspot description card was empty.")
		quit(1)
		return
	if not _selected_info_text_fits(live_environment_canvas, "selected canvas hotspot"):
		quit(1)
		return
	if serialized_before_canvas_click != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.6 clicking a canvas hotspot mutated serialized RunState.")
		quit(1)
		return
	if str(first_interactable.get("object_type", "")) == "game":
		if not bool(selected_info.get("action_available", false)) or str(selected_info.get("action_label", "")).strip_edges().is_empty():
			push_error("M1.6 selected canvas hotspot did not expose an info-card action button.")
			quit(1)
			return
		var info_button_position: Vector2 = live_environment_canvas.call("local_position_for_selected_info_action_button")
		if info_button_position.x < 0.0 or info_button_position.y < 0.0:
			push_error("M1.6 selected canvas hotspot action button did not expose a valid click position.")
			quit(1)
			return
		var serialized_before_info_button := JSON.stringify(app.call("serialized_run_state"))
		var info_button_click := InputEventMouseButton.new()
		info_button_click.button_index = MOUSE_BUTTON_LEFT
		info_button_click.pressed = true
		info_button_click.position = info_button_position
		live_environment_canvas.call("_gui_input", info_button_click)
		await process_frame
		if str(app.call("current_screen_snapshot").get("screen", "")) != "GAME":
			push_error("M1.6 selected info-card action button did not activate the selected object.")
			quit(1)
			return
		if serialized_before_info_button != JSON.stringify(app.call("serialized_run_state")):
			push_error("M1.6 selected info-card game activation mutated serialized RunState.")
			quit(1)
			return
		app.call("back_to_environment")
		await process_frame
		live_environment_canvas = app.get("environment_canvas")
	var blank_position := _blank_canvas_position(live_environment_canvas)
	if blank_position.x < 0.0:
		push_error("M1.6 could not find a blank environment canvas area for room-reset verification.")
		quit(1)
		return
	var blank_click_event := InputEventMouseButton.new()
	blank_click_event.button_index = MOUSE_BUTTON_LEFT
	blank_click_event.pressed = true
	blank_click_event.position = blank_position
	live_environment_canvas.call("_gui_input", blank_click_event)
	await process_frame
	var blank_spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	if str(blank_spatial_snapshot.get("current_context_mode", "")) != "room" or not str(blank_spatial_snapshot.get("selected_object_id", "")).is_empty():
		push_error("M1.6 clicking blank environment space did not return to room presentation state.")
		quit(1)
		return
	var blank_canvas_snapshot: Dictionary = live_environment_canvas.call("current_view_snapshot")
	if bool(blank_canvas_snapshot.get("camera_focus_active", true)) or float(blank_canvas_snapshot.get("target_camera_zoom", 0.0)) != 1.0:
		push_error("M1.6 clicking blank environment space did not restore the full-room camera target.")
		quit(1)
		return
	var blank_selected_info: Dictionary = blank_canvas_snapshot.get("selected_info", {})
	if bool(blank_selected_info.get("visible", false)):
		push_error("M1.6 clicking blank environment space left an object description card visible.")
		quit(1)
		return
	if serialized_before_canvas_click != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.6 clicking blank environment space mutated serialized RunState.")
		quit(1)
		return
	var title_label: Label = app.get("title_label")
	var summary_label: Label = app.get("summary_label")
	var status_label: Label = app.get("status_label")
	var objective_label: Label = app.get("objective_label")
	var actions_list: Control = app.get("actions_list")
	var action_panel_container: Control = app.get("action_panel_container")
	if title_label == null or title_label.text.strip_edges().is_empty():
		push_error("M1.5 environment layout did not show a visible venue title.")
		quit(1)
		return
	if status_label == null or status_label.text.find("Bankroll") == -1 or status_label.text.find("Risk:") == -1:
		push_error("M1.5 top HUD did not show bankroll and risk cue.")
		quit(1)
		return
	if objective_label == null or objective_label.text.find("Goal:") == -1 or objective_label.text.find("Cash:") == -1 or objective_label.text.find("Heat:") == -1 or objective_label.text.find("Next:") == -1:
		push_error("M2-FUN objective HUD did not explain goal, cash, heat, and next opportunity.")
		quit(1)
		return
	if not _control_fits_viewport(objective_label, viewport_rect, "objective HUD"):
		quit(1)
		return
	var objective_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if str(objective_snapshot.get("text", "")) != objective_label.text:
		push_error("M2-FUN objective HUD snapshot did not match visible objective text.")
		quit(1)
		return
	var run_hud_snapshot: Dictionary = app.call("current_run_status_hud_snapshot")
	for field in ["status_text", "objective_text", "save_text", "bankroll_text", "heat_text", "heat_meter", "debt_text", "environment_text", "inventory_text", "run_text", "goal_text"]:
		if str(run_hud_snapshot.get(field, "")).strip_edges().is_empty():
			push_error("R100 dynamic run-status HUD is missing field: %s." % field)
			quit(1)
			return
	if status_label.text.find("[$]") == -1 or status_label.text.find("[HEAT]") == -1 or status_label.text.find("[DEBT]") == -1 or status_label.text.find("[RUN]") == -1:
		push_error("R100 dynamic run-status HUD did not show compact bankroll, heat, debt, and run indicators.")
		quit(1)
		return
	if objective_label.text.find("[GOAL]") == -1 or objective_label.text.find("[ENV]") == -1 or objective_label.text.find("[GEAR]") == -1:
		push_error("R100 dynamic run-status HUD did not show objective, environment, and inventory indicators.")
		quit(1)
		return
	if str(run_hud_snapshot.get("heat_meter", "")).find("[") == -1 or str(run_hud_snapshot.get("heat_meter", "")).find("]") == -1:
		push_error("R100 dynamic run-status HUD did not expose a heat meter.")
		quit(1)
		return
	var save_status_label: Label = app.get("save_status_label")
	if save_status_label == null or save_status_label.text.find("[AUTO]") == -1:
		push_error("R100 dynamic run-status HUD did not show autosave status as a compact indicator.")
		quit(1)
		return
	for forbidden_hud_text in ["serialized", "foundation", "contract", "module", "_"]:
		if status_label.text.findn(forbidden_hud_text) != -1 or objective_label.text.findn(forbidden_hud_text) != -1 or save_status_label.text.findn(forbidden_hud_text) != -1:
			push_error("R100 dynamic run-status HUD exposes technical text: %s." % forbidden_hud_text)
			quit(1)
			return
	if action_panel_container == null or action_panel_container.visible or action_panel_container.is_visible_in_tree():
		push_error("World-first UI still shows the old room-object/game-surface side panel.")
		quit(1)
		return
	if _has_visible_text(app, "What can I do?") or _has_visible_text(app, "Use the machine"):
		push_error("R100 UI still exposes the old side-box labels as normal play requirements.")
		quit(1)
		return
	var initial_consequence_panel := app.get("consequence_panel") as Control
	if initial_consequence_panel == null:
		push_error("R100 UI did not expose the compact consequence panel.")
		quit(1)
		return
	if initial_consequence_panel.visible or _has_visible_text(app, "What just happened") or _has_visible_text(app, "Recent consequence"):
		push_error("R100 UI shows an empty consequence panel before the player has a result.")
		quit(1)
		return
	var initial_game_prompt: Dictionary = app.call("current_game_view_snapshot")
	if str(initial_game_prompt.get("display_name", "")) == "No game selected":
		push_error("M1.5 game surface still uses the dead-end 'No game selected' copy.")
		quit(1)
		return
	if summary_label == null or summary_label.text.find("double-click glowing props to act") == -1:
		push_error("World-first environment summary did not prompt the player to inspect and act through room objects.")
		quit(1)
		return
	var initial_environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var initial_archetype_id := str(initial_environment_snapshot.get("archetype_id", initial_environment_snapshot.get("id", "")))
	var starts_in_home := str(initial_environment_snapshot.get("kind", "")) == "home"
	var starts_homeless := initial_archetype_id == "back_alley"
	if not starts_in_home and not starts_homeless:
		push_error("The first environment should be the meta home start or the homeless back alley.")
		quit(1)
		return
	var initial_item_offers: Array = initial_environment_snapshot.get("item_offers", [])
	if starts_in_home and initial_item_offers.is_empty():
		push_error("The starting home did not expose starter item pickups.")
		quit(1)
		return
	if starts_in_home:
		for offer_value in initial_item_offers:
			if typeof(offer_value) != TYPE_DICTIONARY:
				continue
			var starter_offer: Dictionary = offer_value
			if int(starter_offer.get("price", -1)) != 0 or not bool(starter_offer.get("pickup", false)):
				push_error("The starting home exposed a non-pickup starter item offer.")
				quit(1)
				return
	var initial_objects: Array = app.call("current_spatial_interaction_snapshot").get("objects", [])
	if starts_in_home and (_interactable_by_type(initial_objects, "item").is_empty() or not _interactable_by_type(initial_objects, "shopkeeper").is_empty()):
		push_error("The starting home should expose pickup item room objects without a shopkeeper.")
		quit(1)
		return
	if not _check_final_demo_objective_hud_matrix(app):
		quit(1)
		return
	if not await _check_in_run_menu_flow(app, save_service, viewport_rect):
		quit(1)
		return
	if not await _check_run_journal_flow(app, save_service, viewport_rect):
		quit(1)
		return
	app.call("start_foundation_run", "UI-COMPILE-SEED")
	await process_frame
	if not await _check_talk_dock_main_flow(app):
		quit(1)
		return
	if not await _check_dialogue_dock_main_flow(app):
		quit(1)
		return
	if not await _check_event_item_found_main_flow(app):
		quit(1)
		return
	if not await _check_service_item_found_main_flow(app):
		quit(1)
		return
	app.call("start_foundation_run", "UI-COMPILE-SEED")
	await process_frame
	if not await _check_preview_focus_keeps_serialized_run_state(app):
		quit(1)
		return
	app.call("start_foundation_run", "UI-COMPILE-SEED")
	await process_frame
	var category_snapshot: Dictionary = app.call("current_action_category_snapshot")
	var categories: Array = category_snapshot.get("categories", [])
	var required_categories := [
		{"id": "games", "title": "Games", "screen": "ENVIRONMENT"},
		{"id": "events", "title": "Events", "screen": "EVENT"},
		{"id": "items", "title": "Items", "screen": "ITEMS"},
		{"id": "travel", "title": "Travel", "screen": "TRAVEL"},
	]
	for required in required_categories:
		var category := _category_by_id(categories, str(required.get("id", "")))
		if category.is_empty():
			push_error("M1.5 action category is missing: %s." % str(required.get("title", "")))
			quit(1)
			return
		if str(category.get("description", "")).is_empty() or not category.has("enabled") or not category.has("empty_text"):
			push_error("M1.5 action category lacks description, enabled state, or empty-state copy: %s." % str(required.get("title", "")))
			quit(1)
			return
	var serialized_before_category_clicks := JSON.stringify(app.call("serialized_run_state"))
	for required in required_categories:
		if not bool(app.call("select_action_category", str(required.get("id", "")))):
			push_error("M1.6 compatibility category could not route context: %s." % str(required.get("title", "")))
			quit(1)
			return
		await process_frame
		if serialized_before_category_clicks != JSON.stringify(app.call("serialized_run_state")):
			push_error("Routing an M1.6 context category mutated serialized RunState: %s." % str(required.get("title", "")))
			quit(1)
			return
		var selected_screen: Dictionary = app.call("current_screen_snapshot")
		if str(selected_screen.get("screen", "")) != str(required.get("screen", "")):
			push_error("Foundation screen router did not match selected category: %s." % str(required.get("title", "")))
			quit(1)
			return
	if not (initial_environment_snapshot.get("travel_choices", []) as Array).is_empty():
		app.call("select_action_category", "travel")
		await process_frame
		if _interactable_by_type(app.call("current_spatial_interaction_snapshot").get("objects", []), "travel").is_empty():
			push_error("World-first Travel category did not expose travel choices as room objects.")
			quit(1)
			return
	app.call("select_action_category", "games")
	await process_frame
	await process_frame
	var game_focus_snapshot: Dictionary = (app.get("environment_canvas") as Control).call("current_view_snapshot")
	var game_focus_info: Dictionary = game_focus_snapshot.get("selected_info", {})
	if bool(game_focus_info.get("visible", false)) and not _selected_info_text_fits(app.get("environment_canvas"), "game object info"):
		quit(1)
		return
	if layout_serialized_before != JSON.stringify(app.call("serialized_run_state")):
		push_error("M1.5 layout-only inspection mutated serialized RunState.")
		quit(1)
		return

	app.call("clear_interaction_focus")
	await process_frame
	var first_seed_environment := JSON.stringify(app.call("current_environment_view_snapshot"))
	app.call("start_foundation_run", "UI-COMPILE-SEED")
	await process_frame
	var same_seed_environment := JSON.stringify(app.call("current_environment_view_snapshot"))
	if first_seed_environment != same_seed_environment:
		push_error("Starting the same seed did not produce the same first environment.")
		quit(1)
		return
	app.call("start_foundation_run", "UI-COMPILE-OTHER-SEED")
	await process_frame
	var different_seed_environment := JSON.stringify(app.call("current_environment_view_snapshot"))
	if same_seed_environment == different_seed_environment:
		push_error("Starting a different seed did not change the deterministic first environment.")
		quit(1)
		return
	var custom_challenge := RunStateScript.custom_challenge("ui_compile_variant", "UI-COMPILE-SEED", {"variant": "m1_01"})
	app.call("start_foundation_run", "UI-COMPILE-SEED", custom_challenge)
	await process_frame
	var challenge_seed_value := int(app.get("run_state").seed_value)
	app.call("start_foundation_run", "UI-COMPILE-SEED")
	await process_frame
	if challenge_seed_value == int(app.get("run_state").seed_value):
		push_error("Custom challenge config did not alter the deterministic run seed.")
		quit(1)
		return

	var environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var environment_canvas: Control = PixelSceneCanvasScript.new()
	environment_canvas.call("render_environment_snapshot", environment_snapshot)
	root.add_child(environment_canvas)
	await process_frame
	if not bool(environment_canvas.get("uses_foundation_snapshot")):
		push_error("Environment canvas did not render from a foundation snapshot.")
		quit(1)
		return
	environment_canvas.call("render_environment_snapshot", {
		"id": "grand_casino_living_fixture",
		"archetype_id": "grand_casino",
		"display_name": "Grand Casino Main Floor",
		"pit_boss_watch": {"active": true, "watched": true},
		"grand_casino_living_floor": {
			"player_room": "grand_casino",
			"rourke": {"present": true, "on_floor": true, "room": "grand_casino", "spot": "main_center", "facing": "right", "actions_until_move": 2, "off_floor_actions": 0},
			"rivals": [
				{"id": "rival_one", "tell": "chip_riffle", "spot": 0, "idle_phase": 10},
				{"id": "rival_two", "tell": "heel_tap", "spot": 1, "idle_phase": 20},
				{"id": "rival_three", "tell": "glance_loop", "spot": 2, "idle_phase": 30},
			],
			"rival_count": 3,
			"escort": {},
		},
		"interactable_objects": [],
	})
	await process_frame
	var living_canvas_snapshot: Dictionary = environment_canvas.call("current_view_snapshot")
	var living_floor_snapshot: Dictionary = living_canvas_snapshot.get("grand_casino_living_floor", {}) if typeof(living_canvas_snapshot.get("grand_casino_living_floor", {})) == TYPE_DICTIONARY else {}
	var living_rourke: Dictionary = living_floor_snapshot.get("rourke", {}) if typeof(living_floor_snapshot.get("rourke", {})) == TYPE_DICTIONARY else {}
	if not bool(living_rourke.get("present", false)) or str(living_rourke.get("spot", "")) != "main_center" or str(living_rourke.get("facing", "")) != "right" or (living_floor_snapshot.get("rivals", []) as Array).size() != 3:
		push_error("Grand Casino canvas did not retain the immutable Rourke/rival living-floor snapshot.")
		quit(1)
		return
	var living_redraw_start := int(living_canvas_snapshot.get("scene_idle_animation_redraw_count", 0))
	for _living_frame in range(6):
		environment_canvas.call("_process", 1.0 / 60.0)
	var living_redraw_end := int((environment_canvas.call("current_view_snapshot") as Dictionary).get("scene_idle_animation_redraw_count", 0))
	if living_redraw_end - living_redraw_start < 6:
		push_error("Rourke and rival character animation did not preserve idle-animation liveness.")
		quit(1)
		return
	environment_canvas.call("render_environment_snapshot", {
		"id": "beach",
		"display_name": "The Beach",
		"interactable_objects": [
			{
				"object_id": "service:beach_relax",
				"object_type": "service",
				"visual_type": "service",
				"source_id": "beach_relax",
				"label": "Relax",
				"short_description": "Lower heat.",
				"enabled": true,
				"normalized_rect": {"x": 0.24, "y": 0.62, "w": 0.12, "h": 0.16},
				"available_actions": [{"id": "use_service_hook", "label": "Use"}],
				"confirm_action_id": "use_service_hook",
			},
			{
				"object_id": "service:beach_sand_pile",
				"object_type": "service",
				"visual_type": "service",
				"source_id": "beach_sand_pile",
				"label": "Sand Pile",
				"short_description": "Inspect the pile.",
				"effect_summary": "Hidden service effect.",
				"impact_summary": "Hidden service impact.",
				"enabled": true,
				"prop": "sand_pile",
				"surface": "floor",
				"normalized_rect": {"x": 0.64, "y": 0.68, "w": 0.12, "h": 0.14},
				"available_actions": [{"id": "use_service_hook", "label": "Use"}],
				"confirm_action_id": "use_service_hook",
			},
		],
	})
	environment_canvas.call("set_selected_object", "service:beach_sand_pile")
	await process_frame
	var beach_canvas_snapshot: Dictionary = environment_canvas.call("current_view_snapshot")
	var beach_sand_object := _canvas_object_by_id(beach_canvas_snapshot.get("objects", []), "service:beach_sand_pile")
	if beach_sand_object.is_empty():
		push_error("Beach canvas did not retain the sand-pile service object.")
		quit(1)
		return
	if str(beach_sand_object.get("prop", "")) != "sand_pile" or str(beach_sand_object.get("surface", "")) != "floor":
		push_error("Beach sand-pile object lost its floor/sand-pile draw hints.")
		quit(1)
		return
	if not _selected_info_text_fits(environment_canvas, "beach sand pile info", ["Inspect the pile."]):
		quit(1)
		return
	var beach_info: Dictionary = beach_canvas_snapshot.get("selected_info", {}) if typeof(beach_canvas_snapshot.get("selected_info", {})) == TYPE_DICTIONARY else {}
	var beach_info_lines: Array = beach_info.get("lines", []) if typeof(beach_info.get("lines", [])) == TYPE_ARRAY else []
	var beach_info_text := "\n".join(beach_info_lines)
	if beach_info_text.find("Hidden service effect.") != -1 or beach_info_text.find("Hidden service impact.") != -1 or beach_info_text.find("Effect:") != -1 or beach_info_text.find("Impact:") != -1:
		push_error("Non-item object summary exposed effect or impact copy: %s." % beach_info_text)
		quit(1)
		return
	var beach_info_rect := _snapshot_rect(beach_info.get("rect", {}))
	if beach_info_rect.size.x > 160.0 or beach_info_rect.size.y > 80.0:
		push_error("Non-item object tooltip did not compact around its visible content: %s." % str(beach_info_rect))
		quit(1)
		return
	environment_canvas.call("set_small_screen_mode", true)
	await process_frame
	var small_environment_canvas_snapshot: Dictionary = environment_canvas.call("current_view_snapshot")
	var minimum_environment_hit: Variant = small_environment_canvas_snapshot.get("minimum_environment_hit_size", Vector2.ZERO)
	var small_selected_info: Dictionary = small_environment_canvas_snapshot.get("selected_info", {}) if typeof(small_environment_canvas_snapshot.get("selected_info", {})) == TYPE_DICTIONARY else {}
	var small_info_actions: Array = small_selected_info.get("actions", []) if typeof(small_selected_info.get("actions", [])) == TYPE_ARRAY else []
	var small_action_rect: Dictionary = (small_info_actions[0] as Dictionary).get("button_rect", {}) if not small_info_actions.is_empty() and typeof(small_info_actions[0]) == TYPE_DICTIONARY else {}
	if not bool(small_environment_canvas_snapshot.get("small_screen_mode", false)) or typeof(minimum_environment_hit) != TYPE_VECTOR2 or (minimum_environment_hit as Vector2).x < SmallScreenPolicyScript.ENVIRONMENT_OBJECT_HIT_SIZE.x or float(small_action_rect.get("h", 0.0)) < SmallScreenPolicyScript.ENVIRONMENT_ACTION_HEIGHT:
		push_error("Small-screen environment canvas did not enlarge object and selected-action hit targets.")
		quit(1)
		return
	environment_canvas.call("set_small_screen_mode", false)
	environment_canvas.call("render_environment_snapshot", {
		"id": "classic_drunk_room",
		"display_name": "Classic Drunk Room",
		"drunk_level": 35,
		"drunk_effect_mode": "classic",
		"interactable_objects": [],
	})
	await process_frame
	var classic_environment_snapshot: Dictionary = environment_canvas.call("current_view_snapshot")
	if str(classic_environment_snapshot.get("drunk_effect_mode", "")) != "classic" or bool(classic_environment_snapshot.get("drunk_distortion_visible", true)):
		push_error("Classic drunk visual mode should disable the wavy distortion overlay on environment canvases.")
		quit(1)
		return
	environment_canvas.size = Vector2(VisualStyleScript.ENVIRONMENT_BOARD_SIZE)
	environment_canvas.call("render_environment_snapshot", {
		"id": "distortion_drunk_room",
		"display_name": "Distortion Drunk Room",
		"drunk_level": 70,
		"drunk_effect_mode": "distortion",
		"interactable_objects": [{
			"object_id": "service:test_readable_drink",
			"object_type": "service",
			"visual_type": "drink",
			"source_id": "test_readable_drink",
			"label": "Readable Drink",
			"enabled": true,
			"normalized_rect": {"x": 0.45, "y": 0.42, "w": 0.10, "h": 0.16},
		}],
	})
	environment_canvas.call("set_selected_object", "service:test_readable_drink")
	await process_frame
	var distortion_environment_snapshot: Dictionary = environment_canvas.call("current_view_snapshot")
	var environment_distortion_debug: Dictionary = distortion_environment_snapshot.get("drunk_distortion_debug", {})
	if not bool(distortion_environment_snapshot.get("drunk_distortion_visible", false)):
		push_error("Distortion drunk visual mode should enable the wavy overlay on environment canvases.")
		quit(1)
		return
	if absf(float(environment_distortion_debug.get("global_distortion_scale", 0.0)) - 0.80) > 0.001:
		push_error("Environment drunk distortion did not apply the toned-down global strength.")
		quit(1)
		return
	if absf(float(environment_distortion_debug.get("ui_distortion_scale", 0.0)) - (1.0 / 3.0)) > 0.001:
		push_error("Environment drunk distortion did not apply the reduced readable-UI strength.")
		quit(1)
		return
	if int(environment_distortion_debug.get("ui_protected_rect_count", 0)) <= 0:
		push_error("Environment drunk distortion did not protect readable UI regions.")
		quit(1)
		return
	environment_canvas.call("render_environment_snapshot", {
		"id": "slow_drunk_room",
		"display_name": "Slow Drunk Room",
		"drunk_level": 100,
		"drunk_time_scale": RunState.DRUNK_TIME_SCALE_MIN,
		"drunk_effect_mode": "distortion",
		"interactable_objects": [],
	})
	await process_frame
	var slow_environment_snapshot: Dictionary = environment_canvas.call("current_view_snapshot")
	if absf(float(slow_environment_snapshot.get("drunk_time_scale", 0.0)) - RunState.DRUNK_TIME_SCALE_MIN) > 0.001:
		push_error("Environment canvas did not expose drunk world-speed scaling.")
		quit(1)
		return
	environment_canvas.call("render_environment_snapshot", {
		"id": "reduced_motion_drunk_room",
		"display_name": "Reduced Motion Drunk Room",
		"drunk_level": 70,
		"drunk_effect_mode": "distortion",
		"reduce_motion": true,
		"interactable_objects": [],
	})
	await process_frame
	var reduced_motion_environment_snapshot: Dictionary = environment_canvas.call("current_view_snapshot")
	var reduced_motion_debug: Dictionary = reduced_motion_environment_snapshot.get("drunk_distortion_debug", {})
	if not bool(reduced_motion_environment_snapshot.get("reduce_motion", false)) or bool(reduced_motion_environment_snapshot.get("drunk_distortion_visible", true)) or not bool(reduced_motion_debug.get("reduce_motion", false)):
		push_error("Reduced motion should disable wavy drunk distortion on environment canvases.")
		quit(1)
		return
	environment_canvas.call("render_environment_snapshot", environment_snapshot)
	await process_frame
	var idle_animation_start_snapshot: Dictionary = environment_canvas.call("current_view_snapshot")
	var idle_animation_start_time := float(idle_animation_start_snapshot.get("scene_animation_time", 0.0))
	var idle_animation_start_redraw_count := int(idle_animation_start_snapshot.get("scene_idle_animation_redraw_count", 0))
	for _idle_animation_frame in range(12):
		await process_frame
	var idle_animation_end_snapshot: Dictionary = environment_canvas.call("current_view_snapshot")
	if not bool(idle_animation_end_snapshot.get("scene_idle_animation_active", false)):
		push_error("Environment canvas should keep room-life animation active outside reduced-motion mode.")
		quit(1)
		return
	if float(idle_animation_end_snapshot.get("scene_animation_time", 0.0)) <= idle_animation_start_time:
		push_error("Environment room-life animation time did not advance while idle.")
		quit(1)
		return
	if int(idle_animation_end_snapshot.get("scene_idle_animation_redraw_count", 0)) <= idle_animation_start_redraw_count:
		push_error("Environment room-life animation did not schedule idle redraws without input.")
		quit(1)
		return
	if int(round(float(idle_animation_end_snapshot.get("scene_idle_animation_fps", 0.0)))) != 60:
		push_error("Environment room-life animation target should be 60 FPS.")
		quit(1)
		return
	var manual_idle_redraw_start := int(idle_animation_end_snapshot.get("scene_idle_animation_redraw_count", 0))
	for _manual_idle_animation_frame in range(6):
		environment_canvas.call("_process", 1.0 / 60.0)
	var manual_idle_snapshot: Dictionary = environment_canvas.call("current_view_snapshot")
	if int(manual_idle_snapshot.get("scene_idle_animation_redraw_count", 0)) - manual_idle_redraw_start < 6:
		push_error("Environment room-life animation did not maintain a 60 FPS redraw cadence.")
		quit(1)
		return
	var reduced_motion_game_canvas: Control = GameSurfaceCanvasScript.new()
	root.add_child(reduced_motion_game_canvas)
	reduced_motion_game_canvas.call("render_game_snapshot", {
		"game_id": "reduced_motion_surface",
		"reduce_motion": true,
		"surface_animation_channels": [{
			"id": "test_channel",
			"active_id": "animating",
			"active": true,
			"duration_msec": 5000,
		}],
	})
	await process_frame
	var reduced_motion_game_snapshot: Dictionary = reduced_motion_game_canvas.call("current_view_snapshot")
	var reduced_motion_animations: Dictionary = reduced_motion_game_snapshot.get("surface_animations", {})
	var reduced_motion_channel: Dictionary = reduced_motion_animations.get("test_channel", {})
	if not bool(reduced_motion_game_snapshot.get("reduce_motion", false)) or bool(reduced_motion_channel.get("active", true)) or float(reduced_motion_channel.get("progress", 0.0)) < 1.0:
		push_error("Reduced motion should complete game-surface animation channels immediately.")
		quit(1)
		return
	var active_game_canvas: Control = GameSurfaceCanvasScript.new()
	root.add_child(active_game_canvas)
	active_game_canvas.call("render_game_snapshot", {
		"game_id": "active_surface_animation",
		"reduce_motion": false,
		"surface_animates_idle": true,
		"surface_animation_channels": [{
			"id": "test_channel",
			"active_id": "animating",
			"active": true,
			"duration_msec": 5000,
		}],
	})
	await process_frame
	var active_game_start_snapshot: Dictionary = active_game_canvas.call("current_view_snapshot")
	if int(round(float(active_game_start_snapshot.get("surface_animation_target_fps", 0.0)))) != 60:
		push_error("Game surface animation target should be 60 FPS.")
		quit(1)
		return
	if not bool(active_game_start_snapshot.get("surface_continuous_redraw_active", false)):
		push_error("Game surface did not recognize active animation redraw demand.")
		quit(1)
		return
	var active_game_redraw_start := int(active_game_start_snapshot.get("surface_animation_redraw_count", 0))
	for _active_game_animation_frame in range(6):
		active_game_canvas.call("_process", 1.0 / 60.0)
	var active_game_end_snapshot: Dictionary = active_game_canvas.call("current_view_snapshot")
	if int(active_game_end_snapshot.get("surface_animation_redraw_count", 0)) - active_game_redraw_start < 6:
		push_error("Game surface animation did not maintain a 60 FPS redraw cadence.")
		quit(1)
		return
	var roulette_full_idle_canvas: Control = GameSurfaceCanvasScript.new()
	root.add_child(roulette_full_idle_canvas)
	roulette_full_idle_canvas.call("render_game_snapshot", {
		"game_id": "roulette",
		"surface_renderer": "roulette",
		"surface_animates_idle": true,
		"reduce_motion": false,
	})
	await process_frame
	var roulette_full_idle_start_snapshot: Dictionary = roulette_full_idle_canvas.call("current_view_snapshot")
	if not bool(roulette_full_idle_start_snapshot.get("surface_continuous_redraw_active", false)):
		push_error("Roulette full-wheel idle must animate through the single main surface.")
		quit(1)
		return
	var roulette_full_redraw_start := int(roulette_full_idle_start_snapshot.get("surface_animation_redraw_count", 0))
	for _roulette_full_frame in range(6):
		roulette_full_idle_canvas.call("_process", 1.0 / 60.0)
	var roulette_full_idle_end_snapshot: Dictionary = roulette_full_idle_canvas.call("current_view_snapshot")
	if int(roulette_full_idle_end_snapshot.get("surface_animation_redraw_count", 0)) - roulette_full_redraw_start < 6:
		push_error("Roulette main-surface idle did not maintain a 60 FPS redraw cadence.")
		quit(1)
		return
	var table_idle_canvas: Control = GameSurfaceCanvasScript.new()
	root.add_child(table_idle_canvas)
	table_idle_canvas.call("render_game_snapshot", {
		"game_id": "baccarat",
		"surface_renderer": "baccarat",
		"surface_animates_idle": true,
		"reduce_motion": false,
		"dealer_profile": {"attention_base": 24},
		"dealer_attention_pressure": 6,
		"suspicion_level": 0,
		"patrons": [
			{"name": "Seat 1", "snitch_risk": 22, "watching_player": true, "animation_offset": 0},
			{"name": "Seat 2", "snitch_risk": 10, "watching_player": false, "animation_offset": 300},
		],
		"table_round_timer": {
			"active": true,
			"started_msec": Time.get_ticks_msec(),
			"duration_msec": 12000,
			"remaining_msec": 12000,
		},
	})
	await process_frame
	var table_idle_start_snapshot: Dictionary = table_idle_canvas.call("current_view_snapshot")
	if not bool(table_idle_start_snapshot.get("surface_continuous_redraw_active", false)):
		push_error("Table idle must animate through the single main surface.")
		quit(1)
		return
	var table_overlay_redraw_start := int(table_idle_start_snapshot.get("surface_animation_redraw_count", 0))
	for _table_overlay_frame in range(6):
		table_idle_canvas.call("_process", 1.0 / 60.0)
	var table_idle_end_snapshot: Dictionary = table_idle_canvas.call("current_view_snapshot")
	if int(table_idle_end_snapshot.get("surface_animation_redraw_count", 0)) - table_overlay_redraw_start < 6:
		push_error("Table main-surface idle did not maintain a 60 FPS redraw cadence.")
		quit(1)
		return
	var duplicate_input_canvas: Control = PixelSceneCanvasScript.new()
	duplicate_input_canvas.size = Vector2(VisualStyleScript.ENVIRONMENT_BOARD_SIZE)
	root.add_child(duplicate_input_canvas)
	duplicate_input_canvas.call("render_environment_snapshot", {
		"id": "duplicate_input_room",
		"display_name": "Duplicate Input Room",
		"interactable_objects": [{
			"object_id": "service:test_drink",
			"object_type": "service",
			"visual_type": "drink",
			"source_id": "test_drink",
			"label": "Test Drink",
			"enabled": true,
			"normalized_rect": {"x": 0.45, "y": 0.42, "w": 0.10, "h": 0.16},
		}],
	})
	await process_frame
	var activation_counter := {"count": 0}
	duplicate_input_canvas.object_activated.connect(func(_object_id: String) -> void:
		activation_counter["count"] = int(activation_counter.get("count", 0)) + 1
	)
	var duplicate_click_position := Vector2(
		float(VisualStyleScript.ENVIRONMENT_BOARD_SIZE.x) * 0.50,
		float(VisualStyleScript.ENVIRONMENT_BOARD_SIZE.y) * 0.50
	)
	var duplicate_mouse_event := InputEventMouseButton.new()
	duplicate_mouse_event.button_index = MOUSE_BUTTON_LEFT
	duplicate_mouse_event.pressed = true
	duplicate_mouse_event.double_click = true
	duplicate_mouse_event.position = duplicate_click_position
	duplicate_input_canvas.call("_gui_input", duplicate_mouse_event)
	duplicate_input_canvas.set("last_mouse_press_msec", Time.get_ticks_msec() - 500)
	var duplicate_touch_event := InputEventScreenTouch.new()
	duplicate_touch_event.pressed = true
	duplicate_touch_event.double_tap = true
	duplicate_touch_event.position = duplicate_click_position
	duplicate_input_canvas.call("_gui_input", duplicate_touch_event)
	await process_frame
	if int(activation_counter.get("count", 0)) != 1:
		push_error("Environment canvas applied both mouse and emulated-touch activation for one object.")
		quit(1)
		return
	duplicate_input_canvas.queue_free()
	var duplicate_reverse_canvas: Control = PixelSceneCanvasScript.new()
	duplicate_reverse_canvas.size = Vector2(VisualStyleScript.ENVIRONMENT_BOARD_SIZE)
	root.add_child(duplicate_reverse_canvas)
	duplicate_reverse_canvas.call("render_environment_snapshot", {
		"id": "duplicate_reverse_input_room",
		"display_name": "Duplicate Reverse Input Room",
		"interactable_objects": [{
			"object_id": "service:test_drink",
			"object_type": "service",
			"visual_type": "drink",
			"source_id": "test_drink",
			"label": "Test Drink",
			"enabled": true,
			"normalized_rect": {"x": 0.45, "y": 0.42, "w": 0.10, "h": 0.16},
		}],
	})
	await process_frame
	var reverse_activation_counter := {"count": 0}
	duplicate_reverse_canvas.object_activated.connect(func(_object_id: String) -> void:
		reverse_activation_counter["count"] = int(reverse_activation_counter.get("count", 0)) + 1
	)
	var duplicate_reverse_touch_event := InputEventScreenTouch.new()
	duplicate_reverse_touch_event.pressed = true
	duplicate_reverse_touch_event.double_tap = true
	duplicate_reverse_touch_event.position = duplicate_click_position
	duplicate_reverse_canvas.call("_gui_input", duplicate_reverse_touch_event)
	duplicate_reverse_canvas.set("last_touch_press_msec", Time.get_ticks_msec() - 500)
	var duplicate_reverse_mouse_event := InputEventMouseButton.new()
	duplicate_reverse_mouse_event.button_index = MOUSE_BUTTON_LEFT
	duplicate_reverse_mouse_event.pressed = true
	duplicate_reverse_mouse_event.double_click = true
	duplicate_reverse_mouse_event.position = duplicate_click_position
	duplicate_reverse_canvas.call("_gui_input", duplicate_reverse_mouse_event)
	await process_frame
	if int(reverse_activation_counter.get("count", 0)) != 1:
		push_error("Environment canvas applied both touch and emulated-mouse activation for one object.")
		quit(1)
		return
	duplicate_reverse_canvas.queue_free()

	var serialized_before_selection := JSON.stringify(app.call("serialized_run_state"))
	app.call("select_environment_view_object", 0)
	await process_frame
	var serialized_after_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_selection != serialized_after_selection:
		push_error("UI-local environment selection changed serialized RunState.")
		quit(1)
		return

	app.call("start_foundation_run", "UI-COMPILE-GAME-SEED", RunStateScript.custom_challenge("ui_compile_game_fixture", "UI-COMPILE-GAME-SEED", {"home_archetype_id": "bar"}))
	await process_frame
	if not await _travel_to_first_game_environment(app):
		push_error("Foundation screen router could not reach a gambling environment after the shop start.")
		quit(1)
		return
	var serialized_before_game_entry := JSON.stringify(app.call("serialized_run_state"))
	if not _enter_ui_test_game(app):
		push_error("Foundation screen router did not find a game after reaching a gambling environment.")
		quit(1)
		return
	await process_frame
	if serialized_before_game_entry != JSON.stringify(app.call("serialized_run_state")):
		push_error("Entering a game panel mutated serialized RunState before action resolution.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "GAME":
		push_error("Foundation screen router did not move to GAME after entering a game.")
		quit(1)
		return
	var focused_environment_canvas: Control = app.get("environment_canvas")
	var focused_game_surface: Control = app.get("game_surface_canvas")
	if focused_game_surface == null or not focused_game_surface.visible:
		push_error("M1.6B game mode did not make the game surface visible.")
		quit(1)
		return
	if focused_environment_canvas != null and focused_environment_canvas.visible:
		push_error("M1.6B game mode left the environment canvas competing with the game surface.")
		quit(1)
		return
	if focused_game_surface.size.y < 260.0:
		push_error("M1.6B game mode did not enlarge the game surface enough to be primary.")
		quit(1)
		return
	if not _control_fits_viewport(status_label, viewport_rect, "game-mode HUD status"):
		quit(1)
		return
	if not _control_fits_viewport(objective_label, viewport_rect, "game-mode objective HUD"):
		quit(1)
		return
	if not _control_fits_viewport(app.get("save_status_label"), viewport_rect, "game-mode save status"):
		quit(1)
		return
	if not _control_fits_viewport(focused_game_surface, viewport_rect, "focused game surface"):
		quit(1)
		return
	var focused_game_surface_snapshot: Dictionary = focused_game_surface.call("current_view_snapshot")
	if not _canvas_preserves_art_aspect(focused_game_surface_snapshot, "focused game surface"):
		quit(1)
		return
	if str(focused_game_surface_snapshot.get("game_id", "")) == "blackjack" and not _surface_hit_groups_disjoint(
		focused_game_surface_snapshot,
		["blackjack_chip"],
		["blackjack_clear_bet", "blackjack_max_bet"],
		"blackjack betting chips and clear/max buttons"
	):
		quit(1)
		return
	var surface_back_position: Vector2 = focused_game_surface.call("local_position_for_surface_action", "surface_back", -1)
	if surface_back_position.x < 0.0 or surface_back_position.y < 0.0:
		push_error("World-first game surface did not expose a visible back-to-environment hit region.")
		quit(1)
		return
	if not bool(app.call("_autosave_foundation_run", "Queued animation autosave.")):
		push_error("Game-mode autosave could not be queued for deferred flush.")
		quit(1)
		return
	var queued_autosave_status: Dictionary = app.call("save_status_snapshot")
	if not bool(queued_autosave_status.get("pending_autosave", false)):
		push_error("Game-mode autosave wrote immediately instead of waiting for the surface to settle.")
		quit(1)
		return
	var serialized_before_back := JSON.stringify(app.call("serialized_run_state"))
	var surface_back_event := InputEventMouseButton.new()
	surface_back_event.button_index = MOUSE_BUTTON_LEFT
	surface_back_event.pressed = true
	surface_back_event.position = surface_back_position
	focused_game_surface.call("_gui_input", surface_back_event)
	await process_frame
	var flushed_autosave_status: Dictionary = app.call("save_status_snapshot")
	if bool(flushed_autosave_status.get("pending_autosave", false)):
		push_error("Deferred game-mode autosave did not flush after leaving the game surface.")
		quit(1)
		return
	if serialized_before_back != JSON.stringify(app.call("serialized_run_state")):
		push_error("Surface back to environment mutated serialized RunState.")
		quit(1)
		return
	var backed_out_game_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if str(backed_out_game_snapshot.get("display_name", "")) != "Choose a game":
		push_error("Back to environment did not return the game panel to the game-choice prompt.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "ENVIRONMENT":
		push_error("Foundation screen router did not return to ENVIRONMENT after backing out of a game.")
		quit(1)
		return
	if focused_environment_canvas != null and not focused_environment_canvas.visible:
		push_error("M1.6B Back to environment did not restore the full environment canvas.")
		quit(1)
		return
	if focused_game_surface != null and focused_game_surface.visible:
		push_error("M1.6B Back to environment left the game surface visible in room mode.")
		quit(1)
		return
	if not _enter_ui_test_game(app):
		push_error("Foundation screen router did not find a game after backing out.")
		quit(1)
		return
	await process_frame
	var game_snapshot_before: Dictionary = app.call("current_game_view_snapshot")
	var legal_actions: Array = game_snapshot_before.get("legal_actions", [])
	if legal_actions.is_empty():
		push_error("Foundation game did not expose selectable legal actions.")
		quit(1)
		return
	var cheat_actions: Array = game_snapshot_before.get("cheat_actions", [])
	if cheat_actions.is_empty():
		push_error("Foundation game did not expose selectable cheat/advantage actions.")
		quit(1)
		return
	var game_surface_rect := focused_game_surface.get_global_rect()
	if action_panel_container != null and action_panel_container.is_visible_in_tree():
		push_error("World-first game mode still shows the old game-surface side panel.")
		quit(1)
		return
	if game_surface_rect.size.x * game_surface_rect.size.y < viewport_rect.size.x * viewport_rect.size.y * 0.35:
		push_error("World-first game surface is not large enough to carry normal play: surface %s viewport %s." % [str(game_surface_rect), str(viewport_rect)])
		quit(1)
		return
	var legal_action_label := _qa_action_label(legal_actions[0] as Dictionary)
	var cheat_action_label := _qa_action_label(cheat_actions[0] as Dictionary)
	if not bool(game_snapshot_before.get("has_valid_stake", false)):
		push_error("Foundation game did not expose a valid stake range.")
		quit(1)
		return
	var min_stake := int(game_snapshot_before.get("stake_min", 0))
	var max_stake := int(game_snapshot_before.get("stake_max", 0))
	if min_stake <= 0 or max_stake < min_stake:
		push_error("Foundation game stake range is invalid.")
		quit(1)
		return
	if int(game_snapshot_before.get("selected_stake", 0)) != min_stake:
		push_error("Foundation UI did not default to the minimum valid stake.")
		quit(1)
		return
	var serialized_before_surface_sweep := JSON.stringify(app.call("serialized_run_state"))
	var available_game_ids: Array = app.call("current_environment_view_snapshot").get("game_ids", [])
	var presentation_modes := {}
	for available_game_id in available_game_ids:
		app.call("back_to_environment")
		await process_frame
		app.call("enter_game", str(available_game_id))
		await process_frame
		var available_game_snapshot: Dictionary = app.call("current_game_view_snapshot")
		var available_surface_renderer := str(available_game_snapshot.get("surface_renderer", ""))
		if available_surface_renderer.is_empty() or available_surface_renderer == "result":
			push_error("Available foundation game did not choose a distinct presentation surface.")
			quit(1)
			return
		presentation_modes[available_surface_renderer] = true
	if available_game_ids.size() > 1 and presentation_modes.size() < 2:
		push_error("Multiple available foundation games collapsed to one generic presentation surface.")
		quit(1)
		return
	app.call("back_to_environment")
	await process_frame
	if not _enter_ui_test_game(app):
		push_error("Foundation screen router did not find a game after presentation sweep.")
		quit(1)
		return
	await process_frame
	game_snapshot_before = app.call("current_game_view_snapshot")
	if serialized_before_surface_sweep != JSON.stringify(app.call("serialized_run_state")):
		push_error("Sweeping foundation game presentation surfaces mutated serialized RunState.")
		quit(1)
		return

	var game_canvas: Control = GameSurfaceCanvasScript.new()
	game_canvas.call("render_game_snapshot", game_snapshot_before)
	root.add_child(game_canvas)
	await process_frame
	if not bool(game_canvas.get("uses_foundation_snapshot")):
		push_error("Game surface canvas did not render from a foundation snapshot.")
		quit(1)
		return
	var surface_renderer := str(game_snapshot_before.get("surface_renderer", ""))
	if surface_renderer.is_empty() or surface_renderer == "result":
		push_error("Foundation game snapshot did not choose a distinct presentation surface.")
		quit(1)
		return
	var game_canvas_snapshot: Dictionary = game_canvas.call("current_view_snapshot")
	if str(game_canvas_snapshot.get("surface_renderer", "")) != surface_renderer:
		push_error("Game surface canvas did not preserve the requested presentation surface.")
		quit(1)
		return
	var classic_game_snapshot := game_snapshot_before.duplicate(true)
	classic_game_snapshot["drunk_level"] = 35
	classic_game_snapshot["drunk_effect_mode"] = "classic"
	classic_game_snapshot["reduce_motion"] = false
	game_canvas.call("render_game_snapshot", classic_game_snapshot)
	await process_frame
	var classic_game_canvas_snapshot: Dictionary = game_canvas.call("current_view_snapshot")
	if str(classic_game_canvas_snapshot.get("drunk_effect_mode", "")) != "classic" or bool(classic_game_canvas_snapshot.get("drunk_distortion_visible", true)):
		push_error("Classic drunk visual mode should disable the wavy distortion overlay on game surfaces.")
		quit(1)
		return
	var distortion_game_snapshot := game_snapshot_before.duplicate(true)
	distortion_game_snapshot["drunk_level"] = 70
	distortion_game_snapshot["drunk_effect_mode"] = "distortion"
	distortion_game_snapshot["reduce_motion"] = false
	distortion_game_snapshot["surface_ui_protected_regions"] = [{"x": 38, "y": 258, "w": 220, "h": 42}]
	game_canvas.call("render_game_snapshot", distortion_game_snapshot)
	await process_frame
	var distortion_game_canvas_snapshot: Dictionary = game_canvas.call("current_view_snapshot")
	var game_distortion_debug: Dictionary = distortion_game_canvas_snapshot.get("drunk_distortion_debug", {})
	if not bool(distortion_game_canvas_snapshot.get("drunk_distortion_visible", false)):
		push_error("Distortion drunk visual mode should enable the wavy overlay on game surfaces.")
		quit(1)
		return
	if absf(float(game_distortion_debug.get("global_distortion_scale", 0.0)) - 0.80) > 0.001:
		push_error("Game drunk distortion did not apply the toned-down global strength.")
		quit(1)
		return
	if absf(float(game_distortion_debug.get("ui_distortion_scale", 0.0)) - (1.0 / 3.0)) > 0.001:
		push_error("Game drunk distortion did not apply the reduced readable-UI strength.")
		quit(1)
		return
	if int(game_distortion_debug.get("ui_protected_rect_count", 0)) <= 0:
		push_error("Game drunk distortion did not protect readable UI regions.")
		quit(1)
		return
	var slow_game_snapshot := game_snapshot_before.duplicate(true)
	slow_game_snapshot["drunk_level"] = 100
	slow_game_snapshot["drunk_time_scale"] = RunState.DRUNK_TIME_SCALE_MIN
	slow_game_snapshot["drunk_effect_mode"] = "distortion"
	slow_game_snapshot["reduce_motion"] = false
	slow_game_snapshot["surface_animation_channels"] = [{
		"id": "drunk_time_test",
		"active_id": "slow_world",
		"duration_msec": 10000,
		"started_msec": Time.get_ticks_msec() - 3000,
		"active": true,
	}]
	game_canvas.call("render_game_snapshot", slow_game_snapshot)
	await process_frame
	var slow_game_canvas_snapshot: Dictionary = game_canvas.call("current_view_snapshot")
	var scaled_elapsed := float(game_canvas.call("surface_elapsed", "drunk_time_test"))
	if scaled_elapsed < 0.85 or scaled_elapsed > 1.25:
		push_error("Game surface animations did not use drunk-scaled elapsed time.")
		quit(1)
		return
	var slow_surface_animations: Dictionary = slow_game_canvas_snapshot.get("surface_animations", {})
	var slow_channel: Dictionary = slow_surface_animations.get("drunk_time_test", {})
	if not bool(slow_channel.get("active", false)) or absf(float(slow_channel.get("time_scale", 0.0)) - RunState.DRUNK_TIME_SCALE_MIN) > 0.001:
		push_error("Game surface animation snapshot did not expose drunk-time scaling.")
		quit(1)
		return
	game_canvas.call("render_game_snapshot", game_snapshot_before)
	await process_frame

	focused_game_surface.queue_redraw()
	await process_frame
	var legal_surface_binding := _game_surface_action_binding(app, "legal")
	var legal_surface_action := str(legal_surface_binding.get("action", "surface_legal"))
	var legal_surface_index := int(legal_surface_binding.get("index", 0))
	var surface_click_position: Vector2 = focused_game_surface.call(
		"local_position_for_surface_action",
		legal_surface_action,
		legal_surface_index
	)
	if surface_click_position.x < 0.0 or surface_click_position.y < 0.0:
		push_error("M1.6B game surface did not expose a visible legal action hit region.")
		quit(1)
		return
	var generic_surface_selection := legal_surface_action == "surface_legal"
	if generic_surface_selection:
		var serialized_before_surface_selection := JSON.stringify(app.call("serialized_run_state"))
		var surface_click_event := InputEventMouseButton.new()
		surface_click_event.button_index = MOUSE_BUTTON_LEFT
		surface_click_event.pressed = true
		surface_click_event.position = surface_click_position
		focused_game_surface.call("_gui_input", surface_click_event)
		await process_frame
		if serialized_before_surface_selection != JSON.stringify(app.call("serialized_run_state")):
			var mutation_snapshot: Dictionary = app.call("current_game_view_snapshot")
			push_error("M1.6B clicking a game surface action mutated serialized RunState before confirmation: game=%s action=%s index=%d." % [str(mutation_snapshot.get("game_id", "")), legal_surface_action, legal_surface_index])
			quit(1)
			return
		var surface_selected_snapshot: Dictionary = app.call("current_game_view_snapshot")
		if str(surface_selected_snapshot.get("selected_action_id", "")) != str(legal_actions[0].get("id", "")):
			push_error("M1.6B clicking a game surface action did not update UI-local action selection.")
			quit(1)
			return
		var focused_canvas_snapshot: Dictionary = focused_game_surface.call("current_view_snapshot")
		if int(focused_canvas_snapshot.get("selected_view_index", -1)) < 0:
			push_error("M1.6B game surface did not expose selected surface state after a surface click.")
			quit(1)
			return
	if generic_surface_selection:
		if not _visible_text_fits_viewport(actions_list, "Click the highlighted surface action", viewport_rect, "game-mode surface resolve guidance"):
			quit(1)
			return
	if not _control_fits_viewport(app.get("consequence_cards_scroll"), viewport_rect, "game-mode recent consequence strip"):
		quit(1)
		return

	var legal_action: Dictionary = legal_actions[0]
	var serialized_before_invalid_stake := JSON.stringify(app.call("serialized_run_state"))
	if bool(app.call("set_selected_stake", max_stake + 1)):
		push_error("Foundation UI accepted an invalid stake.")
		quit(1)
		return
	await process_frame
	var serialized_after_invalid_stake := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_invalid_stake != serialized_after_invalid_stake:
		push_error("Invalid stake selection mutated serialized RunState.")
		quit(1)
		return
	var serialized_before_min_stake := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("set_selected_stake", min_stake)):
		push_error("Foundation UI rejected the minimum valid stake.")
		quit(1)
		return
	await process_frame
	var selected_min_stake_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if int(selected_min_stake_snapshot.get("selected_stake", 0)) != min_stake:
		push_error("Foundation UI did not store the selected minimum stake.")
		quit(1)
		return
	var serialized_after_min_stake := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_min_stake != serialized_after_min_stake:
		push_error("Selecting a valid stake mutated serialized RunState.")
		quit(1)
		return
	var serialized_before_legal_selection := JSON.stringify(app.call("serialized_run_state"))
	app.call("select_game_action", str(legal_action.get("id", "")), "legal")
	await process_frame
	var serialized_after_legal_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_legal_selection != serialized_after_legal_selection:
		push_error("Selecting a legal action mutated serialized RunState.")
		quit(1)
		return
	var selected_legal_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if str(selected_legal_snapshot.get("selected_action_id", "")) != str(legal_action.get("id", "")):
		push_error("Foundation UI did not store the selected legal action as UI-local state.")
		quit(1)
		return
	var legal_embeds_outcome := bool(selected_legal_snapshot.get("surface_embeds_outcomes", false)) or bool(selected_legal_snapshot.get("surface_suppresses_game_result_burst", false))
	if str(selected_legal_snapshot.get("selected_action_summary", "")).is_empty() or not _has_visible_text(actions_list, "Click the highlighted surface action"):
		push_error("M1.5 dedicated game panel did not show selected legal action summary and surface resolve guidance.")
		quit(1)
		return
	app.call("resolve_selected_game_action")
	await process_frame
	var serialized_after_action := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_legal_selection == serialized_after_action:
		push_error("Resolving a foundation game action did not update serialized RunState.")
		quit(1)
		return
	var screen_after_legal := str(app.call("current_screen_snapshot").get("screen", ""))
	if (legal_embeds_outcome and screen_after_legal != "GAME") or (not legal_embeds_outcome and screen_after_legal != "RESULT"):
		push_error("Foundation screen router did not move to the expected post-action screen.")
		quit(1)
		return
	var min_result_snapshot: Dictionary = app.call("current_game_view_snapshot")
	var result_stake := int(min_result_snapshot.get("result_stake", 0))
	var fixed_price_legal := bool(game_snapshot_before.get("surface_fixed_price_actions", false)) or not bool(game_snapshot_before.get("surface_stake_controls_required", true))
	if fixed_price_legal and result_stake <= 0:
		push_error("Fixed-price foundation game result did not report a positive authored stake.")
		quit(1)
		return
	if not fixed_price_legal and result_stake != min_stake:
		push_error("Foundation game result did not use the selected minimum stake.")
		quit(1)
		return
	var min_bankroll_delta := int(min_result_snapshot.get("bankroll_delta", 0))
	if not legal_embeds_outcome:
		var legal_environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
		if str(legal_environment_snapshot.get("outcome_message", "")).is_empty() or str(legal_environment_snapshot.get("outcome_object_id", "")).is_empty():
			push_error("Resolved legal action did not create in-scene outcome feedback for the focused object.")
			quit(1)
			return
		var result_environment_canvas: Control = app.get("environment_canvas")
		var live_environment_canvas_snapshot: Dictionary = result_environment_canvas.call("current_view_snapshot")
		if str(live_environment_canvas_snapshot.get("outcome_message", "")).is_empty():
			push_error("Environment canvas did not receive in-scene consequence feedback.")
			quit(1)
			return
		if str(live_environment_canvas_snapshot.get("outcome_anchor", "")) != "environment_panel_top_right" or str(live_environment_canvas_snapshot.get("outcome_interaction_kind", "")) != "informational_result":
			push_error("Environment result feedback was not separated as top-right informational output.")
			quit(1)
			return
		var result_feedback_snapshot: Dictionary = app.call("current_environment_result_feedback_snapshot")
		if str(result_feedback_snapshot.get("anchor", "")) != "environment_panel_top_right" or str(result_feedback_snapshot.get("interaction_kind", "")) != "informational_result":
			push_error("Environment result feedback panel did not expose the top-right informational contract.")
			quit(1)
			return
		var outcome_popup_rect: Dictionary = result_feedback_snapshot.get("popup_rect", {})
		var surface_rect: Dictionary = result_feedback_snapshot.get("surface_rect", {})
		var environment_panel_rect: Dictionary = result_feedback_snapshot.get("panel_rect", {})
		var outcome_right := float(outcome_popup_rect.get("x", 0.0)) + float(outcome_popup_rect.get("w", 0.0))
		var panel_right := float(environment_panel_rect.get("x", 0.0)) + float(environment_panel_rect.get("w", 0.0))
		var outcome_bottom := float(outcome_popup_rect.get("y", 0.0)) + float(outcome_popup_rect.get("h", 0.0))
		var surface_top := float(surface_rect.get("y", 0.0))
		var viewport_top := float(viewport_rect.position.y)
		var popup_left := float(outcome_popup_rect.get("x", 0.0))
		var panel_left := float(environment_panel_rect.get("x", 0.0))
		if outcome_popup_rect.is_empty() or surface_rect.is_empty() or environment_panel_rect.is_empty() or outcome_bottom > surface_top or absf(outcome_right - panel_right) > 24.0 or popup_left < panel_left or float(outcome_popup_rect.get("y", 0.0)) < viewport_top:
			push_error("Environment result feedback was not placed in the top-right HUD band above the environment panel.")
			quit(1)
			return
	if min_bankroll_delta != 0 and not legal_embeds_outcome and not fixed_price_legal and status_label.text.find("%+d" % min_bankroll_delta) == -1:
		push_error("Top HUD did not visually emphasize the recent bankroll delta.")
		quit(1)
		return
	var legal_consequence_snapshot: Dictionary = app.call("current_consequence_view_snapshot")
	var legal_consequence_panel := app.get("consequence_panel") as Control
	if legal_consequence_panel == null:
		push_error("Legal action did not expose the consequence data boundary.")
		quit(1)
		return
	if legal_consequence_panel.visible or _has_visible_text(app, "Recent consequence"):
		push_error("Legal action should not consume play space with the old Recent consequence panel.")
		quit(1)
		return
	if int(legal_consequence_snapshot.get("bankroll", 0)) != int(app.call("serialized_run_state").get("bankroll", -1)):
		push_error("Consequence snapshot did not track current bankroll after legal action.")
		quit(1)
		return
	var serialized_before_consequence_view := JSON.stringify(app.call("serialized_run_state"))
	if legal_embeds_outcome:
		if str(min_result_snapshot.get("result_message", "")).is_empty():
			push_error("Embedded legal action did not expose a game-surface result message.")
			quit(1)
			return
	else:
		var legal_cards: Array = legal_consequence_snapshot.get("cards", [])
		if _card_by_title(legal_cards, "Play resolved").is_empty():
			push_error("Legal action did not produce a readable consequence outcome card.")
			quit(1)
			return
		if _card_by_title(legal_cards, "Bankroll").is_empty():
			push_error("Legal action consequence cards did not show bankroll change.")
			quit(1)
			return
		if _card_by_title(legal_cards, "Story").is_empty():
			push_error("Legal action consequence cards did not show story/result message.")
			quit(1)
			return
		if _card_by_title(legal_cards, "Next").is_empty():
			push_error("Legal action consequence cards did not suggest next actions.")
			quit(1)
			return
		if _has_visible_text(app, "Play resolved") or _has_visible_text(app, "Recent consequence"):
			push_error("Resolved play leaked old consequence-card text into the normal play layout.")
			quit(1)
			return
		if not _control_fits_viewport(app.get("consequence_cards_scroll"), viewport_rect, "consequence cards scroll after result"):
			quit(1)
			return
	if serialized_before_consequence_view != JSON.stringify(app.call("serialized_run_state")):
		push_error("Displaying legal consequence cards mutated serialized RunState.")
		quit(1)
		return
	if not legal_embeds_outcome:
		if int(legal_consequence_snapshot.get("recent_bankroll_delta", 0)) != min_bankroll_delta:
			push_error("Consequence snapshot did not show the recent legal bankroll delta.")
			quit(1)
			return
		if str(legal_consequence_snapshot.get("recent_result_message", "")).is_empty():
			push_error("Consequence snapshot did not show a recent legal result message.")
			quit(1)
			return
	if not bool(legal_consequence_snapshot.get("travel_available", false)):
		push_error("Consequence snapshot did not show travel availability.")
		quit(1)
		return
	game_canvas.call("render_game_snapshot", app.call("current_game_view_snapshot"))
	await process_frame
	var game_canvas_view: Dictionary = game_canvas.call("current_view_snapshot")
	var game_canvas_state: Dictionary = game_canvas_view.get("state", {})
	if str(game_canvas_state.get("result_message", "")).is_empty():
		push_error("Game surface did not render a foundation game result snapshot.")
		quit(1)
		return
	if str(game_canvas_view.get("outcome_message", "")).is_empty() or int(game_canvas_view.get("outcome_bankroll_delta", 0)) != min_bankroll_delta:
		push_error("Game surface did not expose in-scene result feedback from result-delta data.")
		quit(1)
		return
	app.call("start_foundation_run", "UI-COMPILE-SEED")
	await process_frame
	if not _enter_action_fixture_game(app, "bar_dice"):
		push_error("Higher-stake check could not enter the bar dice action fixture.")
		quit(1)
		return
	await process_frame
	var higher_snapshot: Dictionary = app.call("current_game_view_snapshot")
	var higher_legal_actions: Array = higher_snapshot.get("legal_actions", [])
	if higher_legal_actions.is_empty():
		push_error("Foundation game did not expose legal actions for higher stake check.")
		quit(1)
		return
	var higher_cheat_actions: Array = higher_snapshot.get("cheat_actions", [])
	if higher_cheat_actions.is_empty():
		push_error("Foundation game did not expose cheat/advantage actions for the action fixture.")
		quit(1)
		return
	var higher_min_stake := int(higher_snapshot.get("stake_min", 0))
	var higher_max_stake := int(higher_snapshot.get("stake_max", 0))
	if higher_max_stake <= higher_min_stake:
		push_error("Foundation stake validation needs a higher valid stake for the smoke test.")
		quit(1)
		return
	var higher_stake := higher_min_stake + 1
	var higher_legal_action: Dictionary = higher_legal_actions[0]
	if bool(higher_snapshot.get("slot_fixed_bet_ladder", false)):
		if not bool(app.call("_handle_module_surface_action", "select_bet_option:bet_5", 0, true)):
			push_error("Foundation slot UI could not select fixed bet_5.")
			quit(1)
			return
		await process_frame
		var fixed_bet_snapshot: Dictionary = app.call("current_game_view_snapshot")
		if str(fixed_bet_snapshot.get("selected_bet_id", "")) != "bet_5" or int(fixed_bet_snapshot.get("selected_bet_total_credits", 0)) != 5:
			push_error("Foundation slot UI did not persist the selected fixed bet_5 option.")
			quit(1)
			return
		var serialized_before_fixed_selection := JSON.stringify(app.call("serialized_run_state"))
		app.call("select_game_action", str(higher_legal_action.get("id", "")), "legal")
		await process_frame
		var serialized_after_fixed_selection := JSON.stringify(app.call("serialized_run_state"))
		if serialized_before_fixed_selection != serialized_after_fixed_selection:
			push_error("Selecting a fixed-bet slot action mutated serialized RunState.")
			quit(1)
			return
		app.call("resolve_selected_game_action")
		await process_frame
		var fixed_result_snapshot: Dictionary = app.call("current_game_view_snapshot")
		if int(fixed_result_snapshot.get("result_stake", fixed_result_snapshot.get("bet_total_credits", 0))) != 5:
			push_error("Foundation slot result did not use selected fixed bet_5 cost.")
			quit(1)
			return
		if int(fixed_result_snapshot.get("bankroll_delta", 0)) == min_bankroll_delta:
			push_error("Fixed bet_5 did not change the deterministic bankroll delta from the minimum bet.")
			quit(1)
			return
	elif bool(higher_snapshot.get("surface_fixed_price_actions", false)) or not bool(higher_snapshot.get("surface_stake_controls_required", true)):
		var serialized_before_fixed_price_selection := JSON.stringify(app.call("serialized_run_state"))
		app.call("select_game_action", str(higher_legal_action.get("id", "")), "legal")
		await process_frame
		var serialized_after_fixed_price_selection := JSON.stringify(app.call("serialized_run_state"))
		if serialized_before_fixed_price_selection != serialized_after_fixed_price_selection:
			push_error("Selecting a fixed-price action mutated serialized RunState.")
			quit(1)
			return
		app.call("resolve_selected_game_action")
		await process_frame
		var fixed_price_result_snapshot: Dictionary = app.call("current_game_view_snapshot")
		if int(fixed_price_result_snapshot.get("result_stake", 0)) <= 0:
			push_error("Fixed-price game result did not report its authored stake.")
			quit(1)
			return
	else:
		if not bool(app.call("set_selected_stake", higher_stake)):
			push_error("Foundation UI rejected a higher valid stake.")
			quit(1)
			return
		var serialized_before_higher_selection := JSON.stringify(app.call("serialized_run_state"))
		app.call("select_game_action", str(higher_legal_action.get("id", "")), "legal")
		await process_frame
		var serialized_after_higher_selection := JSON.stringify(app.call("serialized_run_state"))
		if serialized_before_higher_selection != serialized_after_higher_selection:
			push_error("Selecting a higher-stake action mutated serialized RunState.")
			quit(1)
			return
		app.call("resolve_selected_game_action")
		await process_frame
		var higher_result_snapshot: Dictionary = app.call("current_game_view_snapshot")
		if int(higher_result_snapshot.get("result_stake", 0)) != higher_stake:
			push_error("Foundation game result did not use the selected higher stake.")
			quit(1)
			return
		if int(higher_result_snapshot.get("bankroll_delta", 0)) == min_bankroll_delta:
			push_error("Higher valid stake did not change the deterministic bankroll delta.")
			quit(1)
			return

	if not await _resolve_visible_event_popup(app, "before cheat/advantage action selection"):
		quit(1)
		return
	if not _enter_action_fixture_game(app, "bar_dice"):
		push_error("Game interrupt regression could not enter the bar dice action fixture.")
		quit(1)
		return
	await process_frame
	var game_interrupt_run_state: RunState = app.get("run_state")
	game_interrupt_run_state.event_cadence_advance_actions(4)
	var game_interrupt_resolved: Array = game_interrupt_run_state.current_environment.get("resolved_event_ids", []) if typeof(game_interrupt_run_state.current_environment.get("resolved_event_ids", [])) == TYPE_ARRAY else []
	game_interrupt_resolved.erase("suspicious_patron")
	game_interrupt_run_state.current_environment["resolved_event_ids"] = game_interrupt_resolved
	game_interrupt_run_state.current_environment["turns"] = maxi(2, int(game_interrupt_run_state.current_environment.get("turns", 0)))
	var game_interrupt_context: Dictionary = {
		"trigger": "action",
		"type": "action",
		"source": "game_action",
		"turns": int(game_interrupt_run_state.current_environment.get("turns", 0)),
	}
	if not game_interrupt_run_state.enqueue_triggered_event("suspicious_patron", "game_action", game_interrupt_context):
		push_error("Game interrupt regression could not enqueue a triggered event.")
		quit(1)
		return
	if not bool(app.call("_show_next_pending_triggered_event")):
		push_error("Game interrupt regression could not open the triggered event popup.")
		quit(1)
		return
	await process_frame
	var game_interrupt_popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	var game_interrupt_choices: Array = game_interrupt_popup.get("choices", []) if typeof(game_interrupt_popup.get("choices", [])) == TYPE_ARRAY else []
	if not bool(game_interrupt_popup.get("visible", false)) or str(game_interrupt_popup.get("event_id", "")) != "suspicious_patron" or game_interrupt_choices.is_empty():
		push_error("Game interrupt regression popup did not expose the expected triggered event.")
		quit(1)
		return
	var game_interrupt_choice: Dictionary = game_interrupt_choices[0] if typeof(game_interrupt_choices[0]) == TYPE_DICTIONARY else {}
	if game_interrupt_choice.is_empty():
		push_error("Game interrupt regression popup choice was malformed.")
		quit(1)
		return
	app.call("resolve_event_choice", "suspicious_patron", str(game_interrupt_choice.get("id", "")))
	await process_frame
	var game_interrupt_after_popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if bool(game_interrupt_after_popup.get("visible", false)):
		push_error("Game interrupt regression left the triggered event popup visible.")
		quit(1)
		return
	var game_interrupt_screen := str(app.call("current_screen_snapshot").get("screen", ""))
	if game_interrupt_screen != "GAME":
		push_error("Resolving a triggered event from a game left the surface on %s instead of GAME." % game_interrupt_screen)
		quit(1)
		return
	var cheat_action: Dictionary = higher_cheat_actions[0]
	var serialized_before_cheat_selection := JSON.stringify(app.call("serialized_run_state"))
	app.call("select_game_action", str(cheat_action.get("id", "")), "cheat")
	await process_frame
	var serialized_after_cheat_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_cheat_selection != serialized_after_cheat_selection:
		push_error("Selecting a cheat/advantage action mutated serialized RunState.")
		quit(1)
		return
	var selected_cheat_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if str(selected_cheat_snapshot.get("selected_action_id", "")) != str(cheat_action.get("id", "")):
		push_error("Foundation UI did not store the selected cheat/advantage action as UI-local state.")
		quit(1)
		return
	var cheat_embeds_outcome := bool(selected_cheat_snapshot.get("surface_embeds_outcomes", false)) or bool(selected_cheat_snapshot.get("surface_suppresses_game_result_burst", false))
	if str(selected_cheat_snapshot.get("risk_cue", "")).is_empty() or not _has_visible_text(actions_list, "Click the highlighted surface action"):
		push_error("M1.5 dedicated game panel did not show selected risky action cue and surface resolve guidance.")
		quit(1)
		return
	app.call("resolve_selected_game_action")
	await process_frame
	var serialized_after_cheat_action := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_cheat_selection == serialized_after_cheat_action:
		push_error("Resolving a cheat/advantage action did not update serialized RunState.")
		quit(1)
		return
	var screen_after_cheat := str(app.call("current_screen_snapshot").get("screen", ""))
	if (cheat_embeds_outcome and screen_after_cheat != "GAME") or (not cheat_embeds_outcome and screen_after_cheat != "RESULT"):
		push_error("Foundation screen router did not stay on the expected post-risky-action screen.")
		quit(1)
		return
	var cheat_result_snapshot: Dictionary = app.call("current_game_view_snapshot")
	var cheat_consequence_snapshot: Dictionary = app.call("current_consequence_view_snapshot")
	var cheat_run_state: Dictionary = app.call("serialized_run_state")
	var cheat_suspicion_delta := int(cheat_result_snapshot.get("suspicion_delta", 0))
	if cheat_suspicion_delta != 0 and not cheat_embeds_outcome and status_label.text.find("%+d" % cheat_suspicion_delta) == -1:
		push_error("Top HUD did not visually emphasize the recent risk/suspicion delta.")
		quit(1)
		return
	if cheat_embeds_outcome:
		if str(cheat_result_snapshot.get("result_message", "")).is_empty():
			push_error("Embedded cheat/advantage action did not expose a game-surface result message.")
			quit(1)
			return
	else:
		var cheat_cards: Array = cheat_consequence_snapshot.get("cards", [])
		if _card_by_title(cheat_cards, "Risky play resolved").is_empty():
			push_error("Cheat/advantage action did not produce a readable consequence outcome card.")
			quit(1)
			return
		if _card_by_title(cheat_cards, "Risk").is_empty():
			push_error("Cheat/advantage consequence cards did not show risk/suspicion cue.")
			quit(1)
			return
		if _has_visible_text(app, "Risky play resolved") or _has_visible_text(app, "Recent consequence"):
			push_error("Cheat/advantage result leaked old consequence-card text into the normal play layout.")
			quit(1)
			return
	if int(cheat_consequence_snapshot.get("suspicion_level", -1)) != int(cheat_run_state.get("suspicion", {}).get("level", -2)):
		push_error("Consequence snapshot did not track current suspicion after cheat action.")
		quit(1)
		return
	if not cheat_embeds_outcome:
		if int(cheat_consequence_snapshot.get("recent_suspicion_delta", 0)) != int(cheat_result_snapshot.get("suspicion_delta", 0)):
			push_error("Consequence snapshot did not show the recent cheat suspicion delta.")
			quit(1)
			return
	if (cheat_consequence_snapshot.get("suspicion_cues", []) as Array).is_empty() and (cheat_consequence_snapshot.get("security_cues", []) as Array).is_empty():
		push_error("Consequence snapshot did not expose suspicion or security cues.")
		quit(1)
		return
	var save_ux_state: Dictionary = {}
	var save_status_before: Dictionary = app.call("save_status_snapshot")
	if str(save_status_before.get("status_text", "")).is_empty():
		push_error("Save status text should be visible before saving.")
		quit(1)
		return
	var save_path := str(save_status_before.get("save_path", ""))
	if save_path.find("beat_the_house_demo_save") != -1:
		push_error("Foundation save status referenced the demo save path.")
		quit(1)
		return
	app.call("save_foundation_run")
	await process_frame
	var save_status_after: Dictionary = app.call("save_status_snapshot")
	if not bool(save_status_after.get("has_save", false)) or not bool(save_status_after.get("load_available", false)):
		push_error("Saving did not make the foundation Continue/Load state available.")
		quit(1)
		return
	if str(save_status_after.get("status_text", "")).find("Saved") == -1:
		push_error("Save status did not report a saved foundation run.")
		quit(1)
		return
	save_ux_state = app.call("serialized_run_state")
	var save_objects := _interactable_by_type(app.call("current_spatial_interaction_snapshot").get("objects", []), "save")
	var load_objects := _interactable_by_type(app.call("current_spatial_interaction_snapshot").get("objects", []), "load")
	if not save_objects.is_empty() or not load_objects.is_empty():
		push_error("Save/load should not appear as room objects; runs autosave and Continue loads from the main menu.")
		quit(1)
		return
	var saved_visible_environment := str(app.call("current_environment_view_snapshot").get("display_name", ""))
	var saved_game_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if str(saved_game_snapshot.get("result_message", "")).is_empty():
		push_error("Saved active game state did not expose a visible game summary.")
		quit(1)
		return
	app.call("return_to_main_menu")
	await process_frame
	var menu_continue: Button = app.get("continue_button")
	if menu_continue == null or menu_continue.disabled:
		push_error("Autosaved run was not available through the main menu Continue button.")
		quit(1)
		return
	menu_continue.emit_signal("pressed")
	await process_frame
	var loaded_save_ux_state: Dictionary = app.call("serialized_run_state")
	if int(loaded_save_ux_state.get("bankroll", 0)) != int(save_ux_state.get("bankroll", -1)):
		push_error("Load did not restore visible bankroll.")
		quit(1)
		return
	var saved_suspicion: Dictionary = save_ux_state.get("suspicion", {})
	var loaded_suspicion: Dictionary = loaded_save_ux_state.get("suspicion", {})
	if int(loaded_suspicion.get("level", -1)) != int(saved_suspicion.get("level", -2)):
		push_error("Load did not restore visible suspicion level.")
		quit(1)
		return
	if (loaded_suspicion.get("cues", []) as Array).size() != (saved_suspicion.get("cues", []) as Array).size():
		push_error("Load did not restore suspicion cue state.")
		quit(1)
		return
	var saved_flags_json := _stable_json(save_ux_state.get("narrative_flags", {}))
	var loaded_flags_json := _stable_json(loaded_save_ux_state.get("narrative_flags", {}))
	if loaded_flags_json != saved_flags_json:
		push_error("Load did not restore flags. expected=%s loaded=%s" % [saved_flags_json, loaded_flags_json])
		quit(1)
		return
	var expected_story: Array = save_ux_state.get("story_log", [])
	var loaded_story: Array = loaded_save_ux_state.get("story_log", [])
	var normalized_expected_story: Variant = _normalize_json_numbers(expected_story)
	var normalized_loaded_story: Variant = _normalize_json_numbers(loaded_story)
	if JSON.stringify(normalized_loaded_story) != JSON.stringify(normalized_expected_story):
		push_error("Load did not restore story state. expected=%d loaded=%d expected_last=%s loaded_last=%s" % [
			expected_story.size(),
			loaded_story.size(),
			JSON.stringify(_normalize_json_numbers(expected_story[expected_story.size() - 1])) if not expected_story.is_empty() else "{}",
			JSON.stringify(_normalize_json_numbers(loaded_story[loaded_story.size() - 1])) if not loaded_story.is_empty() else "{}",
		])
		quit(1)
		return
	var saved_environment: Dictionary = save_ux_state.get("current_environment", {})
	var loaded_environment: Dictionary = loaded_save_ux_state.get("current_environment", {})
	if str(loaded_environment.get("id", "")) != str(saved_environment.get("id", "")) or str(app.call("current_environment_view_snapshot").get("display_name", "")) != saved_visible_environment:
		push_error("Load did not restore the visible environment.")
		quit(1)
		return
	if JSON.stringify(loaded_environment.get("travel_hooks", [])) != JSON.stringify(saved_environment.get("travel_hooks", [])) or JSON.stringify(loaded_environment.get("next_archetypes", [])) != JSON.stringify(saved_environment.get("next_archetypes", [])):
		push_error("Load did not restore travel state.")
		quit(1)
		return
	var loaded_game_summary: Dictionary = app.call("current_game_view_snapshot")
	if str(loaded_game_summary.get("summary_source", "")) != "saved_story_log" or str(loaded_game_summary.get("result_message", "")).is_empty():
		push_error("Load did not restore a visible saved game state summary.")
		quit(1)
		return
	var loaded_consequence_snapshot: Dictionary = app.call("current_consequence_view_snapshot")
	if int(loaded_consequence_snapshot.get("bankroll", 0)) != int(save_ux_state.get("bankroll", -1)):
		push_error("Consequence panel did not restore bankroll after load.")
		quit(1)
		return
	if (loaded_consequence_snapshot.get("cards", []) as Array).is_empty():
		push_error("Load did not restore coherent consequence cards from saved run state/story.")
		quit(1)
		return
	if int(loaded_consequence_snapshot.get("suspicion_level", -1)) != int(saved_suspicion.get("level", -2)):
		push_error("Consequence panel did not restore suspicion after load.")
		quit(1)
		return
	if (loaded_consequence_snapshot.get("story_messages", []) as Array).is_empty():
		push_error("Consequence panel did not restore story messages after load.")
		quit(1)
		return
	if not bool(loaded_consequence_snapshot.get("travel_available", false)):
		push_error("Consequence panel did not restore travel availability after load.")
		quit(1)
		return
	var loaded_save_status: Dictionary = app.call("save_status_snapshot")
	if str(loaded_save_status.get("status_text", "")).find("Loaded") == -1:
		push_error("Load status did not report the loaded foundation run.")
		quit(1)
		return
	if int(loaded_save_status.get("visible_bankroll", -1)) != int(loaded_save_ux_state.get("bankroll", -2)):
		push_error("Save/load status did not restore visible bankroll summary.")
		quit(1)
		return
	if str(loaded_save_status.get("visible_environment", "")) != saved_visible_environment:
		push_error("Save/load status did not restore visible environment summary.")
		quit(1)
		return
	if str(loaded_save_status.get("visible_risk", "")).is_empty() or str(loaded_save_status.get("visible_story", "")).is_empty() or str(loaded_save_status.get("visible_travel", "")).is_empty():
		push_error("Save/load status did not expose restored risk, story, and travel summaries.")
		quit(1)
		return
	var event_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var event_options: Array = event_snapshot.get("event_options", [])
	if event_options.is_empty():
		var event_fixture_run_state: RunState = app.get("run_state")
		event_fixture_run_state.current_environment["kind"] = "shop"
		event_fixture_run_state.current_environment["display_name"] = "Fixture Shop"
		event_fixture_run_state.current_environment["event_ids"] = ["late_shift_discount"]
		event_fixture_run_state.current_environment["resolved_event_ids"] = []
		event_fixture_run_state.current_environment["item_offers"] = []
		event_fixture_run_state.current_environment["service_ids"] = []
		event_fixture_run_state.current_environment["lender_hooks"] = []
		event_fixture_run_state.current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(event_fixture_run_state.current_environment)
		app.call("clear_interaction_focus")
		await process_frame
		event_snapshot = app.call("current_environment_view_snapshot")
		event_options = event_snapshot.get("event_options", [])
	if event_options.is_empty():
		push_error("Foundation UI did not expose an eligible event option.")
		quit(1)
		return
	var event_option: Dictionary = event_options[0]
	var event_id := str(event_option.get("id", ""))
	var event_choices: Array = event_option.get("choices", [])
	if event_choices.is_empty():
		push_error("Foundation UI did not expose event choices.")
		quit(1)
		return
	var event_definition: Dictionary = app.get("library").event(event_id)
	var event_module := EventModuleScript.new()
	event_module.setup(event_definition)
	if event_choices.size() != event_module.choices().size():
		push_error("Foundation UI did not show all currently valid event choices.")
		quit(1)
		return
	var serialized_before_event_category := JSON.stringify(app.call("serialized_run_state"))
	app.call("select_action_category", "events")
	await process_frame
	if serialized_before_event_category != JSON.stringify(app.call("serialized_run_state")):
		push_error("Selecting the Events card category mutated serialized RunState.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "EVENT":
		push_error("Foundation screen router did not move to EVENT for event cards.")
		quit(1)
		return
	if not _has_visible_text(actions_list, str(event_option.get("display_name", ""))):
		push_error("Event card did not show the eligible event title.")
		quit(1)
		return
	var event_choice: Dictionary = event_choices[0]
	for candidate_value in event_choices:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate_choice: Dictionary = candidate_value
		if not _event_choice_has_trigger_event(event_definition, str(candidate_choice.get("id", ""))):
			event_choice = candidate_choice
			break
	var event_choice_id := str(event_choice.get("id", ""))
	if not _has_visible_text(actions_list, str(event_choice.get("label", ""))):
		push_error("Event card did not show the available event choice.")
		quit(1)
		return
	if str(event_choice.get("text", "")).is_empty() or str(event_choice.get("consequence_summary", "")).is_empty():
		push_error("Event choices did not expose player-facing text and impact summaries.")
		quit(1)
		return
	if str(event_choice.get("identity_summary", "")).find("Choice ID:") == -1 or str(event_choice.get("impact_summary", "")).is_empty():
		push_error("Event choices did not expose normalized choice identity and impact metadata.")
		quit(1)
		return
	var serialized_before_event_selection := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("select_event_choice", event_id, event_choice_id)):
		push_error("Foundation UI rejected an eligible event choice.")
		quit(1)
		return
	await process_frame
	var serialized_after_event_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_event_selection != serialized_after_event_selection:
		push_error("Selecting an event choice mutated serialized RunState.")
		quit(1)
		return
	if not _selected_info_text_fits(app.get("environment_canvas"), "event object info", ["Risk:"]):
		quit(1)
		return
	var event_canvas_snapshot: Dictionary = (app.get("environment_canvas") as Control).call("current_view_snapshot")
	if _canvas_has_object_type(event_canvas_snapshot.get("objects", []), "event_choice"):
		push_error("Selecting an event should not create separate environment response-choice objects.")
		quit(1)
		return
	if _canvas_object_id_with_prefix(event_canvas_snapshot.get("objects", []), "event_choice:"):
		push_error("Selecting an event created legacy event_choice object ids.")
		quit(1)
		return
	var event_selected_info: Dictionary = event_canvas_snapshot.get("selected_info", {})
	var event_selected_info_lines: Array = event_selected_info.get("lines", []) if typeof(event_selected_info.get("lines", [])) == TYPE_ARRAY else []
	var event_selected_info_text := "\n".join(event_selected_info_lines)
	if event_selected_info_text.find("Choices:") != -1 or event_selected_info_text.find("Choices / impact:") != -1 or event_selected_info_text.find("Effect:") != -1 or event_selected_info_text.find("Impact:") != -1 or event_selected_info_text.find(str(event_choice.get("consequence_summary", ""))) != -1:
		push_error("Event object tooltip exposed choice, effect, or impact summary copy: %s." % event_selected_info_text)
		quit(1)
		return
	var event_info_actions: Array = event_selected_info.get("actions", [])
	if event_info_actions.is_empty():
		push_error("Expanded event card did not expose inline response actions on the canvas.")
		quit(1)
		return
	var first_event_info_action: Dictionary = event_info_actions[0]
	var first_event_info_detail := str(first_event_info_action.get("detail", ""))
	var expected_event_action_id := "event_response:%s:%s" % [event_id, event_choice_id]
	if str(first_event_info_action.get("label", "")) != str(event_choice.get("label", "")):
		push_error("Expanded event card did not show the choice label in the selected canvas info tab.")
		quit(1)
		return
	if first_event_info_detail.find(str(event_choice.get("text", ""))) == -1 or first_event_info_detail.find(str(event_choice.get("consequence_summary", ""))) != -1 or first_event_info_detail.find("Effect:") != -1 or first_event_info_detail.find("Impact:") != -1:
		push_error("Expanded event card did not limit inline subtext to the player-facing choice text.")
		quit(1)
		return
	if str(first_event_info_action.get("emit_object_id", "")) != expected_event_action_id:
		push_error("Expanded event card did not route the response through an inline event action id.")
		quit(1)
		return
	var selected_event_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	if str(selected_event_snapshot.get("selected_event_id", "")) != event_id or str(selected_event_snapshot.get("selected_event_choice_id", "")) != event_choice_id:
		push_error("Foundation UI did not store selected event choice as UI-local state.")
		quit(1)
		return
	for object_value in selected_event_snapshot.get("interactable_objects", []):
		if typeof(object_value) == TYPE_DICTIONARY and str((object_value as Dictionary).get("object_id", "")).begins_with("event_response:"):
			push_error("Selecting an event choice created a separate event response room object.")
			quit(1)
			return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "EVENT":
		push_error("Foundation screen router left EVENT during event choice selection.")
		quit(1)
		return
	for popup_attempt in range(6):
		var blocking_popup_before_activation: Dictionary = app.call("current_event_choice_popup_snapshot")
		if not bool(blocking_popup_before_activation.get("visible", false)) or not bool(blocking_popup_before_activation.get("blocking", false)):
			break
		if bool(app.call("activate_interactable_object", "event:%s" % event_id)):
			push_error("Triggered event popup did not block other room-object activation.")
			quit(1)
			return
		var blocking_choices: Array = blocking_popup_before_activation.get("choices", [])
		if blocking_choices.is_empty():
			push_error("Triggered event popup did not expose a required resolution choice.")
			quit(1)
			return
		var blocking_choice: Dictionary = blocking_choices[0]
		app.call("resolve_event_choice", str(blocking_popup_before_activation.get("event_id", "")), str(blocking_choice.get("id", "")))
		await process_frame
	var unresolved_popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if bool(unresolved_popup.get("visible", false)) and bool(unresolved_popup.get("blocking", false)):
		push_error("Triggered event popup queue did not clear after repeated required resolutions.")
		quit(1)
		return
	var serialized_before_event_activation := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("activate_interactable_object", "event:%s" % event_id)):
		push_error("Foundation UI did not activate a visible event object.")
		quit(1)
		return
	await process_frame
	var popup_snapshot: Dictionary = app.call("current_event_choice_popup_snapshot")
	if not bool(popup_snapshot.get("visible", false)) or bool(popup_snapshot.get("blocking", true)) or not bool(popup_snapshot.get("dismissible", false)):
		push_error("Activating an interactable event should open a dismissible non-blocking popup.")
		quit(1)
		return
	if _has_visible_text(app.get("event_choice_popup_overlay"), "Effect:") or _has_visible_text(app.get("event_choice_popup_overlay"), "Impact:"):
		push_error("Interactable event popup exposed effect or impact copy.")
		quit(1)
		return
	if serialized_before_event_activation != JSON.stringify(app.call("serialized_run_state")):
		push_error("Activating an event object mutated serialized RunState.")
		quit(1)
		return
	var serialized_before_event_resolve := JSON.stringify(app.call("serialized_run_state"))
	app.call("resolve_event_choice", event_id, event_choice_id)
	await process_frame
	var event_run_state: Dictionary = app.call("serialized_run_state")
	if JSON.stringify(event_run_state) == serialized_before_event_resolve:
		push_error("Resolving an event choice did not update serialized RunState.")
		quit(1)
		return
	if bool(app.call("current_event_choice_popup_snapshot").get("visible", true)):
		push_error("Event choice popup did not close after resolving a choice.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "RESULT":
		push_error("Foundation screen router did not move to RESULT after resolving an event.")
		quit(1)
		return
	var resolved_events: Array = event_run_state.get("current_environment", {}).get("resolved_event_ids", [])
	if not resolved_events.has(event_id):
		push_error("Resolved event was not recorded in RunState.")
		quit(1)
		return
	var event_story_log: Array = event_run_state.get("story_log", [])
	if event_story_log.is_empty() or str((event_story_log[event_story_log.size() - 1] as Dictionary).get("type", "")) != "event":
		push_error("Event resolution did not record an event story entry.")
		quit(1)
		return
	app.call("save_foundation_run")
	app.call("load_foundation_run")
	await process_frame
	var loaded_event_run_state: Dictionary = app.call("serialized_run_state")
	var expected_event_story: Array = event_run_state.get("story_log", [])
	var loaded_event_story: Array = loaded_event_run_state.get("story_log", [])
	if JSON.stringify(_normalize_json_numbers(loaded_event_story)) != JSON.stringify(_normalize_json_numbers(expected_event_story)):
		push_error("Event story result did not survive SaveService save/load. expected=%d loaded=%d expected_last=%s loaded_last=%s" % [
			expected_event_story.size(),
			loaded_event_story.size(),
			JSON.stringify(_normalize_json_numbers(expected_event_story[expected_event_story.size() - 1])) if not expected_event_story.is_empty() else "{}",
			JSON.stringify(_normalize_json_numbers(loaded_event_story[loaded_event_story.size() - 1])) if not loaded_event_story.is_empty() else "{}",
		])
		quit(1)
		return
	if JSON.stringify(loaded_event_run_state.get("current_environment", {}).get("resolved_event_ids", [])) != JSON.stringify(resolved_events):
		push_error("Resolved event state did not survive SaveService save/load.")
		quit(1)
		return
	var ui_settings: UserSettings = app.get("user_settings")
	var previous_reduce_motion := false
	if ui_settings != null:
		previous_reduce_motion = ui_settings.reduce_motion
		ui_settings.reduce_motion = true
	app.call("_start_conclusion_animation", {
		"ok": true,
		"conclusion_animation": "bankroll_transfer",
		"bankroll_delta": 30,
		"deltas": {"bankroll_delta": 30},
	}, Rect2(Vector2(120, 120), Vector2(220, 160)))
	await process_frame
	var reduced_conclusion_snapshot: Dictionary = app.call("current_conclusion_animation_snapshot")
	if not bool(reduced_conclusion_snapshot.get("reduce_motion", false)) or bool(reduced_conclusion_snapshot.get("active", true)) or not bool(reduced_conclusion_snapshot.get("pulse", false)):
		push_error("bankroll_transfer conclusion animation did not honor reduce-motion snapshot state.")
		quit(1)
		return
	if ui_settings != null:
		ui_settings.reduce_motion = false
	app.call("_start_conclusion_animation", {
		"ok": true,
		"conclusion_animation": "bankroll_transfer",
		"bankroll_delta": 30,
		"deltas": {"bankroll_delta": 30},
	}, Rect2(Vector2(120, 120), Vector2(220, 160)))
	await process_frame
	var animated_conclusion_debug: Dictionary = app.call("debug_soak_snapshot")
	if int(animated_conclusion_debug.get("conclusion_animation_child_count", 0)) <= 0 or int(animated_conclusion_debug.get("conclusion_animation_tween_count", 0)) <= 0:
		push_error("bankroll_transfer conclusion animation did not expose owned runtime nodes and tweens.")
		quit(1)
		return
	if ui_settings != null:
		ui_settings.reduce_motion = previous_reduce_motion

	app.call("start_foundation_run", "UI-ITEM-SEED", RunStateScript.custom_challenge("ui_item_home_fixture", "UI-ITEM-SEED", {"home_archetype_id": "motel_room"}))
	await process_frame
	await process_frame
	var restarted_conclusion_debug: Dictionary = app.call("debug_soak_snapshot")
	if int(restarted_conclusion_debug.get("conclusion_animation_child_count", -1)) != 0 or int(restarted_conclusion_debug.get("conclusion_animation_tween_count", -1)) != 0:
		push_error("Starting a new run retained conclusion-animation nodes or tweens.")
		quit(1)
		return
	var home_pickup_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var home_pickup_offers: Array = home_pickup_snapshot.get("item_offers", [])
	if home_pickup_offers.is_empty():
		push_error("Starting home did not expose item pickups before shop fixture setup.")
		quit(1)
		return
	var home_pickup_offer: Dictionary = home_pickup_offers[0]
	if int(home_pickup_offer.get("price", -1)) != 0 or not bool(home_pickup_offer.get("pickup", false)):
		push_error("Starting home item offer was not exposed as a free pickup.")
		quit(1)
		return
	var home_pickup_objects: Array = app.call("current_spatial_interaction_snapshot").get("objects", [])
	if _interactable_by_type(home_pickup_objects, "item").is_empty() or not _interactable_by_type(home_pickup_objects, "shopkeeper").is_empty():
		push_error("Starting home did not expose pickup items without a shopkeeper.")
		quit(1)
		return
	var item_fixture_run_state: RunState = app.get("run_state")
	item_fixture_run_state.current_environment["kind"] = "shop"
	item_fixture_run_state.current_environment["archetype_id"] = "corner_store"
	item_fixture_run_state.current_environment["display_name"] = "Fixture Corner Store"
	item_fixture_run_state.current_environment["object_fixtures"] = ["shopkeeper:merchant"]
	item_fixture_run_state.current_environment["item_offers"] = [{"id": "creased_luck_card", "price": 8}]
	item_fixture_run_state.current_environment["event_ids"] = []
	item_fixture_run_state.current_environment["service_ids"] = []
	item_fixture_run_state.current_environment["lender_hooks"] = []
	item_fixture_run_state.current_environment["resolved_event_ids"] = []
	var item_fixture_archetype := _archetype_by_id(app.get("library"), "corner_store")
	item_fixture_run_state.current_environment["layout"] = (item_fixture_archetype.get("layout", {}) as Dictionary).duplicate(true) if typeof(item_fixture_archetype.get("layout", {})) == TYPE_DICTIONARY else {}
	item_fixture_run_state.current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(item_fixture_run_state.current_environment)
	app.call("clear_interaction_focus")
	await process_frame
	var item_start_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var item_snapshot: Dictionary = item_start_snapshot
	var item_offers: Array = item_snapshot.get("item_offers", [])
	if item_offers.is_empty():
		push_error("Foundation UI did not expose generated item offers.")
		quit(1)
		return
	var item_offer: Dictionary = item_offers[0]
	var item_id := str(item_offer.get("id", ""))
	var item_price := int(item_offer.get("price", -1))
	if item_id.is_empty() or item_price < 0:
		push_error("Foundation item offer view data is missing id or price.")
		quit(1)
		return
	if str(item_offer.get("description", "")).is_empty():
		push_error("Foundation item offer did not expose a short description from data.")
		quit(1)
		return
	var item_purpose := str(item_offer.get("purpose_summary", "")).strip_edges()
	if item_purpose.is_empty():
		push_error("Foundation item offer did not expose a purpose summary for shop object info.")
		quit(1)
		return
	if not str(item_offer.get("effect_summary", "")).is_empty():
		push_error("Foundation item offer should not expose specific stat changes in player-facing item text.")
		quit(1)
		return
	var summary_service := RunActionServiceScript.new()
	var generated_effect_summary := str(summary_service.effect_summary({
		"blackjack_peek_heat_delta": -3,
		"skill_cheat_drunk_window_offset_msec": 8,
	}))
	if not _player_facing_effect_summary_is_clean(generated_effect_summary, "Generated item effect summary"):
		quit(1)
		return
	var item_asset_path := str(item_offer.get("asset_path", ""))
	if item_asset_path.is_empty() or not ResourceLoader.exists(item_asset_path):
		push_error("Foundation item offer did not expose a valid item icon asset path.")
		quit(1)
		return
	var item_canvas_snapshot: Dictionary = (app.get("environment_canvas") as Control).call("current_view_snapshot")
	var item_canvas_object := _canvas_object_by_id(item_canvas_snapshot.get("objects", []), "item:%s" % item_id)
	if item_canvas_object.is_empty() or str(item_canvas_object.get("asset_path", "")) != item_asset_path:
		push_error("Environment item holder did not receive the item's icon asset path.")
		quit(1)
		return
	var shopkeeper_interactable := _interactable_by_type(app.call("current_spatial_interaction_snapshot").get("objects", []), "shopkeeper")
	if shopkeeper_interactable.is_empty():
		push_error("Item-selling environment did not expose a shopkeeper object.")
		quit(1)
		return
	if not bool(app.call("activate_interactable_object", str(shopkeeper_interactable.get("object_id", "")))):
		push_error("Shopkeeper object could not be activated.")
		quit(1)
		return
	await process_frame
	var shopkeeper_sale_popup: Dictionary = app.call("current_run_inventory_snapshot")
	if not bool(shopkeeper_sale_popup.get("visible", false)) or str(shopkeeper_sale_popup.get("mode", "")) != "merchant_sale" or not bool(shopkeeper_sale_popup.get("merchant_available", false)):
		push_error("Shopkeeper did not open the merchant sell page directly.")
		quit(1)
		return
	if str(shopkeeper_sale_popup.get("anchor", "")) != "screen_center" or str(shopkeeper_sale_popup.get("interaction_kind", "")) != "merchant_sale":
		push_error("Shopkeeper sell page did not use the centered shared popup format.")
		quit(1)
		return
	app.call("close_run_inventory")
	await process_frame
	var item_environment: Dictionary = app.call("serialized_run_state").get("current_environment", {})
	var generated_item_layout: Dictionary = item_environment.get("layout", {})
	var generated_object_rects: Dictionary = generated_item_layout.get("object_rects", {})
	if not generated_object_rects.has("item:%s" % item_id):
		push_error("Generated environment layout did not persist item object placement by item id.")
		quit(1)
		return
	var item_archetype := _archetype_by_id(app.get("library"), str(item_environment.get("archetype_id", "")))
	var item_layout: Dictionary = item_archetype.get("layout", {})
	var item_spots: Array = item_layout.get("item_spots", [])
	if item_spots.is_empty():
		push_error("Foundation item-offer map does not define item_spots for authored placement.")
		quit(1)
		return
	if not _canvas_object_position_matches_board_spot(item_canvas_object, item_spots[0]):
		push_error("Environment item holder ignored the archetype item_spots authored placement.")
		quit(1)
		return
	var serialized_before_item_category := JSON.stringify(app.call("serialized_run_state"))
	app.call("select_action_category", "items")
	await process_frame
	if serialized_before_item_category != JSON.stringify(app.call("serialized_run_state")):
		push_error("Selecting the Items card category mutated serialized RunState.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "ITEMS":
		push_error("Foundation screen router did not move to ITEMS for item cards.")
		quit(1)
		return
	if not _has_visible_text(actions_list, str(item_offer.get("display_name", ""))) or not _has_visible_text(actions_list, "Cost:") or not _has_visible_text(actions_list, str(item_offer.get("description", ""))):
		push_error("Item card did not show title, short description, and cost.")
		quit(1)
		return
	var serialized_before_item_selection := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("select_item_offer", item_id)):
		push_error("Foundation UI rejected an available item offer.")
		quit(1)
		return
	await process_frame
	var serialized_after_item_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_item_selection != serialized_after_item_selection:
		push_error("Selecting an item offer mutated serialized RunState.")
		quit(1)
		return
	var selected_item_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	if str(selected_item_snapshot.get("selected_item_offer_id", "")) != item_id:
		push_error("Foundation UI did not store selected item offer as UI-local state.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "ITEMS":
		push_error("Foundation screen router left ITEMS during item offer selection.")
		quit(1)
		return
	if not _has_visible_text(actions_list, "Buy"):
		push_error("Item card did not show a buy action after selection.")
		quit(1)
		return
	var item_canvas_after_selection: Dictionary = (app.get("environment_canvas") as Control).call("current_view_snapshot")
	if not _canvas_surviving_object_positions_match(item_canvas_snapshot.get("objects", []), item_canvas_after_selection.get("objects", []), ""):
		push_error("Selecting an item offer reflowed environment objects.")
		quit(1)
		return
	if not _selected_info_text_fits(app.get("environment_canvas"), "shop item object info", ["Cost:", str(item_offer.get("description", ""))]):
		quit(1)
		return
	var selected_item_info_snapshot: Dictionary = (app.get("environment_canvas") as Control).call("current_view_snapshot").get("selected_info", {})
	var selected_item_info_lines: Array = selected_item_info_snapshot.get("lines", []) if typeof(selected_item_info_snapshot.get("lines", [])) == TYPE_ARRAY else []
	var selected_item_info_text := "\n".join(selected_item_info_lines)
	if selected_item_info_text.find("Effect:") != -1 or selected_item_info_text.find("Impact:") != -1 or selected_item_info_text.find(item_purpose) != -1:
		push_error("Shop item object info still exposed effect or impact copy: %s." % selected_item_info_text)
		quit(1)
		return
	var selected_item_info_rect := _snapshot_rect(selected_item_info_snapshot.get("rect", {}))
	if selected_item_info_rect.size.x > 200.0 or selected_item_info_rect.size.y > 125.0:
		push_error("Shop item object info did not compact around its remaining content: %s." % str(selected_item_info_rect))
		quit(1)
		return
	var item_run_state: RunState = app.get("run_state")
	var original_item_bankroll := item_run_state.bankroll
	if original_item_bankroll <= item_price:
		push_error("Foundation item-offer test setup unexpectedly cannot afford the selected offer.")
		quit(1)
		return
	item_run_state.change_bankroll((item_price - 1) - item_run_state.bankroll)
	var serialized_before_unaffordable_item := JSON.stringify(app.call("serialized_run_state"))
	if bool(app.call("confirm_selected_item_offer")):
		push_error("Foundation UI allowed an unaffordable item purchase.")
		quit(1)
		return
	await process_frame
	var serialized_after_unaffordable_item := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_unaffordable_item != serialized_after_unaffordable_item:
		push_error("Unaffordable item purchase mutated serialized RunState.")
		quit(1)
		return
	item_run_state.change_bankroll(original_item_bankroll - item_run_state.bankroll)
	var item_canvas_before_purchase: Dictionary = (app.get("environment_canvas") as Control).call("current_view_snapshot")
	var serialized_before_item_purchase: Dictionary = app.call("serialized_run_state")
	if not bool(app.call("confirm_selected_item_offer")):
		push_error("Foundation UI rejected an affordable item purchase.")
		quit(1)
		return
	await process_frame
	if str(app.call("current_screen_snapshot").get("screen", "")) != "RESULT":
		push_error("Foundation screen router did not move to RESULT after item purchase.")
		quit(1)
		return
	var purchased_item_state: Dictionary = app.call("serialized_run_state")
	var purchased_item_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var item_canvas_after_purchase: Dictionary = (app.get("environment_canvas") as Control).call("current_view_snapshot")
	if not _canvas_surviving_object_positions_match(item_canvas_before_purchase.get("objects", []), item_canvas_after_purchase.get("objects", []), "item:%s" % item_id):
		push_error("Item purchase reflowed surviving environment objects instead of only removing the bought item.")
		quit(1)
		return
	var item_result: Dictionary = purchased_item_snapshot.get("last_item_result", {})
	if str(item_result.get("type", "")) != "item_effect" or str(item_result.get("item_effect_id", "")) != item_id:
		push_error("Item purchase did not resolve through the ItemEffect result path.")
		quit(1)
		return
	if not _player_facing_effect_summary_is_clean(str(item_result.get("message", "")), "Item purchase result message"):
		quit(1)
		return
	var item_result_deltas: Dictionary = item_result.get("deltas", {})
	var item_result_effect: Dictionary = item_result.get("effect", {})
	var expected_item_bankroll_delta := int(item_result_effect.get("bankroll_delta", 0)) - item_price
	if int(item_result_deltas.get("bankroll_delta", 0)) != expected_item_bankroll_delta:
		push_error("Item purchase did not include the expected cost delta.")
		quit(1)
		return
	if int(purchased_item_state.get("bankroll", 0)) != int(serialized_before_item_purchase.get("bankroll", 0)) + expected_item_bankroll_delta:
		push_error("Affordable item purchase did not update bankroll as expected.")
		quit(1)
		return
	var purchased_inventory: Array = purchased_item_state.get("inventory", [])
	if not purchased_inventory.has(item_id):
		push_error("Affordable item purchase did not add the item to RunState inventory.")
		quit(1)
		return
	var item_consequence_snapshot: Dictionary = app.call("current_consequence_view_snapshot")
	if (item_consequence_snapshot.get("inventory_items", []) as Array).is_empty() or str(item_consequence_snapshot.get("inventory_summary", "")) == "empty":
		push_error("Consequence panel did not show current inventory after item purchase.")
		quit(1)
		return
	app.call("open_run_inventory")
	await process_frame
	var run_inventory_snapshot: Dictionary = app.call("current_run_inventory_snapshot")
	if not bool(run_inventory_snapshot.get("visible", false)) or str(run_inventory_snapshot.get("mode", "")) != "inspect":
		push_error("Run inventory button did not open the inspect inventory view.")
		quit(1)
		return
	if str(run_inventory_snapshot.get("anchor", "")) != "screen_center" or str(run_inventory_snapshot.get("interaction_kind", "")) != "inventory":
		push_error("Run inventory did not use the centered shared popup format.")
		quit(1)
		return
	if not bool(run_inventory_snapshot.get("grid", false)):
		push_error("Run inventory did not expose the item-icon grid contract.")
		quit(1)
		return
	var run_inventory_popup_rect := _snapshot_rect(run_inventory_snapshot.get("popup_rect", {}))
	var run_inventory_screen_rect := _snapshot_rect(run_inventory_snapshot.get("screen_rect", {}))
	if run_inventory_popup_rect.size.x <= 0.0 or run_inventory_popup_rect.size.y <= 0.0 or not run_inventory_screen_rect.grow(1.0).encloses(run_inventory_popup_rect):
		push_error("Run inventory popup did not stay inside the visible screen: %s within %s." % [str(run_inventory_popup_rect), str(run_inventory_screen_rect)])
		quit(1)
		return
	if run_inventory_popup_rect.get_center().distance_to(run_inventory_screen_rect.get_center()) > 1.5:
		push_error("Run inventory popup was not centered: %s within %s." % [str(run_inventory_popup_rect), str(run_inventory_screen_rect)])
		quit(1)
		return
	var run_inventory_grid_rect := _snapshot_rect(run_inventory_snapshot.get("grid_rect", {}))
	var run_inventory_detail_rect := _snapshot_rect(run_inventory_snapshot.get("detail_rect", {}))
	if run_inventory_grid_rect.size.x <= 0.0 or run_inventory_detail_rect.size.x <= run_inventory_grid_rect.size.x:
		push_error("Run inventory detail panel did not receive more horizontal space than the item grid: grid %s detail %s." % [str(run_inventory_grid_rect), str(run_inventory_detail_rect)])
		quit(1)
		return
	var run_inventory_items: Array = run_inventory_snapshot.get("items", [])
	if run_inventory_items.is_empty():
		push_error("Run inventory view did not expose purchased inventory items.")
		quit(1)
		return
	var purchased_inventory_item: Dictionary = run_inventory_items[0]
	if str(purchased_inventory_item.get("id", "")) != item_id or str(purchased_inventory_item.get("display_name", "")).is_empty() or str(purchased_inventory_item.get("item_type", "")).is_empty() or str(purchased_inventory_item.get("domain", "")).is_empty():
		push_error("Run inventory item details did not identify id, display name, type, and domain.")
		quit(1)
		return
	var selected_inventory_item: Dictionary = run_inventory_snapshot.get("selected_item", {}) if typeof(run_inventory_snapshot.get("selected_item", {})) == TYPE_DICTIONARY else {}
	if str(run_inventory_snapshot.get("selected_item_id", "")) != item_id or selected_inventory_item.is_empty() or str(selected_inventory_item.get("description", "")).is_empty() or not str(selected_inventory_item.get("effect_summary", "")).is_empty():
		push_error("Run inventory did not select the item with short description-only detail text.")
		quit(1)
		return
	app.call("select_run_inventory_item", item_id, str(purchased_inventory_item.get("storage_source", "carried")))
	await process_frame
	var selected_layout_snapshot: Dictionary = app.call("current_run_inventory_snapshot")
	var selected_popup_rect := _snapshot_rect(selected_layout_snapshot.get("popup_rect", {}))
	var selected_screen_rect := _snapshot_rect(selected_layout_snapshot.get("screen_rect", {}))
	if absf(selected_popup_rect.size.x - run_inventory_popup_rect.size.x) > 0.5 or absf(selected_popup_rect.size.y - run_inventory_popup_rect.size.y) > 0.5:
		push_error("Run inventory popup changed size after item selection: before %s after %s." % [str(run_inventory_popup_rect), str(selected_popup_rect)])
		quit(1)
		return
	if selected_popup_rect.get_center().distance_to(selected_screen_rect.get_center()) > 1.5 or not selected_screen_rect.grow(1.0).encloses(selected_popup_rect):
		push_error("Run inventory popup moved off-center or off-screen after item selection: %s within %s." % [str(selected_popup_rect), str(selected_screen_rect)])
		quit(1)
		return
	if not str(purchased_inventory_item.get("effect_summary", "")).is_empty() or int(purchased_inventory_item.get("sale_price", -1)) < 0 or not bool(purchased_inventory_item.get("sellable", false)):
		push_error("Run inventory item details exposed stat text or missed sale price/sellable status.")
		quit(1)
		return
	app.call("close_run_inventory")
	await process_frame
	for remaining_offer in purchased_item_state.get("current_environment", {}).get("item_offers", []):
		if typeof(remaining_offer) == TYPE_DICTIONARY and str((remaining_offer as Dictionary).get("id", "")) == item_id:
			push_error("Purchased item offer was not removed from the environment.")
			quit(1)
			return
	var item_story_log: Array = purchased_item_state.get("story_log", [])
	if item_story_log.is_empty() or str((item_story_log[item_story_log.size() - 1] as Dictionary).get("type", "")) != "item_purchase":
		push_error("Item purchase did not record a serializable story entry.")
		quit(1)
		return
	app.call("save_foundation_run")
	app.call("load_foundation_run")
	await process_frame
	var loaded_item_state: Dictionary = app.call("serialized_run_state")
	if JSON.stringify(loaded_item_state.get("inventory", [])) != JSON.stringify(purchased_item_state.get("inventory", [])):
		push_error("Item purchase inventory state did not survive SaveService save/load.")
		quit(1)
		return
	if int(loaded_item_state.get("bankroll", 0)) != int(purchased_item_state.get("bankroll", 0)):
		push_error("Item purchase bankroll state did not survive SaveService save/load.")
		quit(1)
		return
	var loaded_item_story_log: Array = loaded_item_state.get("story_log", [])
	if loaded_item_story_log.is_empty():
		push_error("Item purchase story state did not survive SaveService save/load.")
		quit(1)
		return
	var loaded_item_story_entry: Dictionary = loaded_item_story_log[loaded_item_story_log.size() - 1]
	if str(loaded_item_story_entry.get("type", "")) != "item_purchase" or str(loaded_item_story_entry.get("item_id", "")) != item_id or int(loaded_item_story_entry.get("price", -1)) != item_price:
		push_error("Loaded item purchase story entry did not preserve purchase details.")
		quit(1)
		return
	if not bool(app.call("open_shopkeeper_sale_page")):
		push_error("Shopkeeper sale page could not be opened in an item-selling environment.")
		quit(1)
		return
	await process_frame
	var sale_inventory_snapshot: Dictionary = app.call("current_run_inventory_snapshot")
	if not bool(sale_inventory_snapshot.get("visible", false)) or str(sale_inventory_snapshot.get("mode", "")) != "merchant_sale" or not bool(sale_inventory_snapshot.get("merchant_available", false)):
		push_error("Shopkeeper sale page did not open merchant sale mode.")
		quit(1)
		return
	if str(sale_inventory_snapshot.get("anchor", "")) != "screen_center" or str(sale_inventory_snapshot.get("interaction_kind", "")) != "merchant_sale":
		push_error("Shopkeeper sale page did not use the centered shared popup format.")
		quit(1)
		return
	var sale_items: Array = sale_inventory_snapshot.get("items", [])
	if sale_items.is_empty():
		push_error("Shopkeeper sale page did not show sellable inventory.")
		quit(1)
		return
	var sale_item: Dictionary = sale_items[0]
	var sale_item_id := str(sale_item.get("id", ""))
	var sale_price := int(sale_item.get("sale_price", -1))
	if sale_item_id.is_empty() or sale_price < 0 or not bool(sale_item.get("sellable", false)):
		push_error("Shopkeeper sale page did not expose sellable item details and sale price.")
		quit(1)
		return
	var serialized_before_item_sale: Dictionary = app.call("serialized_run_state")
	if not bool(app.call("sell_inventory_item", sale_item_id)):
		push_error("Shopkeeper rejected a sellable inventory item.")
		quit(1)
		return
	await process_frame
	var sold_item_state: Dictionary = app.call("serialized_run_state")
	if (sold_item_state.get("inventory", []) as Array).has(sale_item_id):
		push_error("Selling an item did not remove it from RunState inventory.")
		quit(1)
		return
	if int(sold_item_state.get("bankroll", 0)) != int(serialized_before_item_sale.get("bankroll", 0)) + sale_price:
		push_error("Selling an item did not add the expected sale price to bankroll.")
		quit(1)
		return
	var sold_item_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var sale_result: Dictionary = sold_item_snapshot.get("last_item_result", {})
	if str(sale_result.get("type", "")) != "item_sale" or str(sale_result.get("item_id", "")) != sale_item_id:
		push_error("Item sale did not report through the item_sale result path.")
		quit(1)
		return
	var sale_story_log: Array = sold_item_state.get("story_log", [])
	if sale_story_log.is_empty() or str((sale_story_log[sale_story_log.size() - 1] as Dictionary).get("type", "")) != "item_sale":
		push_error("Item sale did not record a serializable story entry.")
		quit(1)
		return
	app.call("save_foundation_run")
	app.call("load_foundation_run")
	await process_frame
	var loaded_sale_state: Dictionary = app.call("serialized_run_state")
	if JSON.stringify(loaded_sale_state.get("inventory", [])) != JSON.stringify(sold_item_state.get("inventory", [])) or int(loaded_sale_state.get("bankroll", 0)) != int(sold_item_state.get("bankroll", 0)):
		push_error("Item sale state did not survive SaveService save/load.")
		quit(1)
		return

	var hook_run_state: RunState = app.get("run_state")
	var hook_library: ContentLibrary = app.get("library")
	var original_hook_services: Array = hook_library.services.duplicate(true)
	var original_hook_lenders: Array = hook_library.lenders.duplicate(true)
	hook_run_state.game_clock_minutes = 20 * 60
	hook_run_state.clear_closing_time_state()
	hook_library.services = [{
		"id": "fixture_ui_service",
		"display_name": "Fixture Service",
		"description": "A contract fixture service resolved through result deltas.",
		"deltas": {
			"bankroll_delta": 3,
			"flags_set": {"fixture_ui_service_used": true},
		},
	}]
	hook_run_state.current_environment["kind"] = "fixture_room"
	hook_run_state.current_environment["object_fixtures"] = ["shopkeeper:merchant"]
	hook_run_state.current_environment["service_ids"] = ["fixture_ui_service"]
	hook_run_state.current_environment["lender_hooks"] = ["fixture_missing_lender"]
	hook_run_state.current_environment["item_offers"] = []
	hook_run_state.current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(hook_run_state.current_environment)
	var hook_spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	var service_interactable := _interactable_by_type(hook_spatial_snapshot.get("objects", []), "service")
	var lender_interactable := _interactable_by_type(hook_spatial_snapshot.get("objects", []), "lender")
	var shopkeeper_fixture := _interactable_by_type(hook_spatial_snapshot.get("objects", []), "shopkeeper")
	if service_interactable.is_empty():
		push_error("M1.6 spatial model did not expose a supported service hook as an interactable object.")
		quit(1)
		return
	if not lender_interactable.is_empty():
		push_error("T6.7 spatial model exposed a missing lender hook instead of hiding it.")
		quit(1)
		return
	if shopkeeper_fixture.is_empty() or bool(shopkeeper_fixture.get("enabled", true)) or bool(shopkeeper_fixture.get("interactive", true)):
		push_error("T6.7 unavailable shopkeeper fixture did not render as a noninteractive fixture.")
		quit(1)
		return
	app.call("focus_interactable_object", str(service_interactable.get("object_id", "")))
	await process_frame
	if not _has_visible_text(actions_list, "Fixture Service"):
		push_error("Focused service context did not show the supported service hook.")
		quit(1)
		return
	var service_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var service_options: Array = service_snapshot.get("service_options", [])
	if service_options.is_empty():
		push_error("Foundation UI did not expose service hooks when present.")
		quit(1)
		return
	if not (service_snapshot.get("lender_options", []) as Array).is_empty():
		push_error("T6.7 Foundation UI exposed a missing lender option.")
		quit(1)
		return
	if bool(app.call("select_lender_hook", "fixture_missing_lender")):
		push_error("T6.7 Foundation UI allowed selection of a hidden missing lender.")
		quit(1)
		return
	var service_option: Dictionary = service_options[0]
	var service_id := str(service_option.get("id", ""))
	if service_id.is_empty() or not bool(service_option.get("mutation_supported", false)):
		push_error("Foundation UI did not recognize a result-delta service hook.")
		quit(1)
		return
	var serialized_before_service_selection := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("select_service_hook", service_id)):
		push_error("Foundation UI rejected an available service hook.")
		quit(1)
		return
	await process_frame
	var serialized_after_service_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_service_selection != serialized_after_service_selection:
		push_error("Selecting a service hook mutated serialized RunState.")
		quit(1)
		return
	if not bool(app.call("confirm_selected_service_hook")):
		push_error("Foundation UI rejected a supported service hook result.")
		quit(1)
		return
	await process_frame
	var service_result_state: Dictionary = app.call("serialized_run_state")
	if not bool(service_result_state.get("flags", service_result_state.get("narrative_flags", {})).get("fixture_ui_service_used", false)):
		push_error("Supported service hook did not apply flags through result-delta.")
		quit(1)
		return
	var service_result_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var service_result: Dictionary = service_result_snapshot.get("last_hook_result", {})
	if str(service_result.get("type", "")) != "service_hook" or str(service_result.get("source_id", "")) != service_id:
		push_error("Supported service hook did not report a foundation hook result.")
		quit(1)
		return
	app.call("back_to_environment")
	await process_frame
	app.call("_hide_event_choice_popup")
	await process_frame
	hook_run_state.game_clock_minutes = 20 * 60
	hook_run_state.clear_closing_time_state()

	hook_library.lenders = [{
		"id": "fixture_ui_lender",
		"display_name": "Fixture Lender",
		"description": "A contract fixture lender resolved through debt_changes.",
		"deltas": {
			"debt_changes": [{"id": "fixture_ui_debt", "lender_id": "fixture_ui_lender", "balance": 12, "status": "active"}],
		},
	}]
	hook_run_state.current_environment["lender_hooks"] = ["fixture_ui_lender"]
	hook_run_state.current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(hook_run_state.current_environment)
	var supported_lender_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var supported_lenders: Array = supported_lender_snapshot.get("lender_options", [])
	if supported_lenders.is_empty() or not bool((supported_lenders[0] as Dictionary).get("mutation_supported", false)):
		push_error("Foundation UI did not recognize a result-delta lender hook.")
		quit(1)
		return
	var lender_id := str((supported_lenders[0] as Dictionary).get("id", ""))
	var debt_count_before_lender := hook_run_state.debt.size()
	var serialized_before_lender_selection := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("select_lender_hook", lender_id)):
		var blocker := str(app.call("_blocking_modal_message")) if app.has_method("_blocking_modal_message") else ""
		var option: Dictionary = app.call("_lender_hook", lender_id) if app.has_method("_lender_hook") else {}
		push_error("Foundation UI rejected an available lender hook. blocker=%s option=%s" % [blocker, JSON.stringify(option)])
		quit(1)
		return
	await process_frame
	var serialized_after_lender_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_lender_selection != serialized_after_lender_selection:
		push_error("Selecting a lender hook mutated serialized RunState.")
		quit(1)
		return
	if not bool(app.call("confirm_selected_lender_hook")):
		push_error("Foundation UI rejected a supported lender hook result.")
		quit(1)
		return
	await process_frame
	var lender_result_state: Dictionary = app.call("serialized_run_state")
	if (lender_result_state.get("debt", []) as Array).size() != debt_count_before_lender + 1:
		push_error("Supported lender hook did not apply debt through result-delta.")
		quit(1)
		return
	var lender_consequence_snapshot: Dictionary = app.call("current_consequence_view_snapshot")
	if (lender_consequence_snapshot.get("debt_items", []) as Array).is_empty() or str(lender_consequence_snapshot.get("debt_summary", "")) == "none":
		push_error("Consequence panel did not show current debt after lender hook.")
		quit(1)
		return
	app.call("save_foundation_run")
	app.call("load_foundation_run")
	await process_frame
	var loaded_hook_state: Dictionary = app.call("serialized_run_state")
	if JSON.stringify(loaded_hook_state.get("debt", [])) != JSON.stringify(lender_result_state.get("debt", [])):
		push_error("Supported lender hook result did not survive SaveService save/load.")
		quit(1)
		return
	if not bool(loaded_hook_state.get("narrative_flags", {}).get("fixture_ui_service_used", false)):
		push_error("Supported service hook result did not survive SaveService save/load.")
		quit(1)
		return
	hook_library.services = original_hook_services
	hook_library.lenders = original_hook_lenders
	app.call("_refresh_run_action_service")

	if not await _resolve_visible_event_popup(app, "before travel card category routing"):
		quit(1)
		return
	var loaded_environment_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var travel_choices: Array = loaded_environment_snapshot.get("travel_choices", [])
	if travel_choices.is_empty():
		push_error("Foundation UI did not expose travel choices when travel was available.")
		quit(1)
		return
	var travel_choice: Dictionary = travel_choices[0]
	var travel_target_id := str(travel_choice.get("id", ""))
	var serialized_before_travel_category := JSON.stringify(app.call("serialized_run_state"))
	app.call("select_action_category", "travel")
	await process_frame
	if serialized_before_travel_category != JSON.stringify(app.call("serialized_run_state")):
		push_error("Selecting the Travel card category mutated serialized RunState.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "TRAVEL":
		push_error("Foundation screen router did not move to TRAVEL for travel cards.")
		quit(1)
		return
	var selected_travel_label_visible := _has_visible_text(actions_list, str(travel_choice.get("label", "")))
	if not selected_travel_label_visible:
		var focused_travel_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
		var focused_travel_label := _label_for_object_id(focused_travel_snapshot.get("objects", []), str(focused_travel_snapshot.get("selected_object_id", "")))
		selected_travel_label_visible = not focused_travel_label.is_empty() and _has_visible_text(actions_list, focused_travel_label)
	if not selected_travel_label_visible:
		push_error("Travel card did not show the destination label.")
		quit(1)
		return
	var spatial_travel_objects: Array = app.call("current_spatial_interaction_snapshot").get("objects", [])
	var leave_object_found := false
	for object_value in spatial_travel_objects:
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		if str(object_data.get("object_type", "")) != "travel":
			continue
		if str(object_data.get("object_id", "")) == "travel:leave":
			leave_object_found = true
		elif str(object_data.get("object_id", "")).begins_with("travel:"):
			push_error("World-map travel should expose only travel:leave as a room object.")
			quit(1)
			return
	if not leave_object_found:
		push_error("World-map travel did not expose the Leave room object.")
		quit(1)
		return
	var map_open_state_before: Dictionary = app.call("serialized_run_state")
	var serialized_before_map_open := JSON.stringify(map_open_state_before)
	if not bool(app.call("open_world_map")):
		push_error("World map could not be opened from the travel card.")
		quit(1)
		return
	await process_frame
	var map_open_state_after: Dictionary = app.call("serialized_run_state")
	if serialized_before_map_open != JSON.stringify(map_open_state_after):
		push_error("Opening the world map mutated serialized RunState.")
		quit(1)
		return
	var map_screen: Dictionary = app.call("current_screen_snapshot")
	if not bool(map_screen.get("world_map_overlay_visible", false)):
		push_error("Leave did not show the modal world map overlay.")
		quit(1)
		return
	if not str(map_screen.get("selected_world_map_node_id", "")).is_empty() or bool(map_screen.get("world_map_detail_popup_visible", false)):
		push_error("World map should open in browse mode without a selected detail popup.")
		quit(1)
		return
	var map_title_text := str(map_screen.get("world_map_title_text", ""))
	if not map_title_text.contains("World Map") or (not map_title_text.contains("AM") and not map_title_text.contains("PM")):
		push_error("World map header did not expose the in-run clock.")
		quit(1)
		return
	if map_title_text.contains("\n") or not map_title_text.contains("Day") or not map_title_text.contains("Here:"):
		push_error("World map header should be a single compact line with day, time, and current location: %s." % map_title_text)
		quit(1)
		return
	if not _visible_buttons_meet_touch_target(app, "world map overlay"):
		quit(1)
		return
	var map_snapshot: Dictionary = map_screen.get("world_map", {}) if typeof(map_screen.get("world_map", {})) == TYPE_DICTIONARY else {}
	var map_narrative_flags: Dictionary = map_open_state_after.get("narrative_flags", {}) if typeof(map_open_state_after.get("narrative_flags", {})) == TYPE_DICTIONARY else {}
	if (map_snapshot.get("nodes", []) as Array).size() < 2:
		push_error("World map overlay did not render the current node and currently travelable stops.")
		quit(1)
		return
	var revealed_fixture := {
		"id": "unvisited_fixture",
		"state": WorldMapScript.STATE_REVEALED,
		"discovered_at_spawn": true,
		"discovery_source": WorldMapScript.DISCOVERY_SOURCE_SPAWN,
	}
	if bool(app.call("_world_map_node_should_render", revealed_fixture, false, false)):
		push_error("World map visibility contract exposed an unvisited location that cannot currently be traveled to.")
		quit(1)
		return
	if not bool(app.call("_world_map_node_should_render", revealed_fixture, false, true)):
		push_error("World map visibility contract hid an unvisited location that can currently be traveled to.")
		quit(1)
		return
	var visited_fixture := revealed_fixture.duplicate(true)
	visited_fixture["state"] = WorldMapScript.STATE_VISITED
	if not bool(app.call("_world_map_node_should_render", visited_fixture, false, false)):
		push_error("World map visibility contract hid a previously visited location that is not currently travelable.")
		quit(1)
		return
	if not str(map_snapshot.get("background_path", "")).contains("map_backgrounds"):
		push_error("World map overlay did not expose the cyberpunk city map background.")
		quit(1)
		return
	var map_target_ids: Array = map_snapshot.get("travel_target_ids", []) if typeof(map_snapshot.get("travel_target_ids", [])) == TYPE_ARRAY else []
	if map_target_ids.size() > 3:
		push_error("World map exposed more than three travel targets.")
		quit(1)
		return
	var map_canvas := app.get("world_map_nodes_layer") as Control
	if map_canvas == null or not map_canvas.has_method("current_view_snapshot"):
		push_error("World map canvas did not expose a view snapshot.")
		quit(1)
		return
	var map_view: Dictionary = map_canvas.call("current_view_snapshot")
	var map_bounds: Dictionary = map_view.get("map_bounds", {}) if typeof(map_view.get("map_bounds", {})) == TYPE_DICTIONARY else {}
	if map_bounds.is_empty():
		push_error("World map canvas did not report zoom bounds.")
		quit(1)
		return
	var map_focus_ids: Array = map_snapshot.get("map_focus_node_ids", []) if typeof(map_snapshot.get("map_focus_node_ids", [])) == TYPE_ARRAY else []
	if not map_focus_ids.has(str(map_snapshot.get("current_node_id", ""))):
		push_error("World map did not include the current stop in the focused camera window.")
		quit(1)
		return
	var map_enabled_ids: Array = map_snapshot.get("travel_enabled_node_ids", []) if typeof(map_snapshot.get("travel_enabled_node_ids", [])) == TYPE_ARRAY else []
	for enabled_id_value in map_enabled_ids:
		var enabled_id := str(enabled_id_value)
		if not map_focus_ids.has(enabled_id):
			push_error("World map did not focus the camera on travelable node %s." % enabled_id)
			quit(1)
			return
		var enabled_node := _world_map_node_by_id(app.call("serialized_run_state").get("world_map", {}), enabled_id)
		if not _world_map_position_in_bounds(enabled_node.get("position", {}), map_bounds):
			push_error("World map focused bounds did not contain travelable node %s." % enabled_id)
			quit(1)
			return
	var map_markers: Array = map_view.get("icon_markers", []) if typeof(map_view.get("icon_markers", [])) == TYPE_ARRAY else []
	var marker_ids: Array = []
	for marker_value in map_markers:
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker_data: Dictionary = marker_value
		var node_id := str(marker_data.get("id", ""))
		if node_id.is_empty():
			continue
		marker_ids.append(node_id)
		var node_button := map_canvas.get_node_or_null("WorldMapNode_%s" % node_id) as Button
		if node_button == null:
			push_error("World map first-open hit target was missing for node %s." % node_id)
			quit(1)
			return
		var marker_center := map_canvas.call("local_position_for_node", node_id) as Vector2
		var button_center := node_button.position + node_button.size * 0.5
		if button_center.distance_to(marker_center) > 2.0:
			push_error("World map first-open hit target for %s was %.1fpx away from the drawn icon." % [node_id, button_center.distance_to(marker_center)])
			quit(1)
			return
	for enabled_id_value in map_enabled_ids:
		var enabled_marker_id := str(enabled_id_value)
		if not marker_ids.has(enabled_marker_id):
			push_error("World map did not draw a marker for travelable node %s inside the focused camera window." % enabled_marker_id)
			quit(1)
			return
	var full_map: Dictionary = app.call("serialized_run_state").get("world_map", {}) if typeof(app.call("serialized_run_state").get("world_map", {})) == TYPE_DICTIONARY else {}
	var hidden_map_ids := _hidden_world_map_ids(full_map)
	var travel_enabled_found := false
	var current_map_id := str(map_snapshot.get("current_node_id", ""))
	for node_value in (map_snapshot.get("nodes", []) as Array):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node_data: Dictionary = node_value
		var node_id := str(node_data.get("id", ""))
		if hidden_map_ids.has(node_id):
			push_error("World map snapshot leaked hidden node %s." % node_id)
			quit(1)
			return
		if str(node_data.get("icon_path", "")).strip_edges().is_empty():
			push_error("World map node %s did not expose generated icon metadata." % node_id)
			quit(1)
			return
		var full_node := _world_map_node_by_id(full_map, node_id)
		if JSON.stringify(node_data.get("position", {})) != JSON.stringify(full_node.get("position", {})):
			push_error("World map icon position for %s moved away from the generated node position." % node_id)
			quit(1)
			return
		if not node_data.has("travel_enabled"):
			push_error("World map node %s did not expose travel-enabled metadata." % node_id)
			quit(1)
			return
		var was_visited := str(full_node.get("state", WorldMapScript.STATE_HIDDEN)) == WorldMapScript.STATE_VISITED
		if node_id != current_map_id and not was_visited and not bool(node_data.get("travel_enabled", false)):
			push_error("World map displayed unvisited location %s even though it cannot currently be traveled to." % node_id)
			quit(1)
			return
		if node_id == WorldMapScript.GRAND_CASINO_ID and not bool(map_narrative_flags.get("grand_casino_invite", false)):
			push_error("World map exposed the Grand Casino before the player received an invitation.")
			quit(1)
			return
		if bool(node_data.get("travel_target", false)) and node_id != current_map_id:
			if not node_data.has("open_now") or not node_data.has("open_status_text"):
				push_error("World map travel target %s did not expose open-hours metadata." % node_id)
				quit(1)
				return
		if str(node_data.get("discovery_source", "")).strip_edges() == WorldMapScript.DISCOVERY_SOURCE_TRAVEL and str(node_data.get("state", "")) != WorldMapScript.STATE_VISITED and not bool(node_data.get("travel_target", false)):
			push_error("World map displayed travel-discovered non-target node %s." % node_id)
			quit(1)
			return
		if bool(node_data.get("travel_enabled", false)):
			travel_enabled_found = true
			if not map_target_ids.has(node_id):
				push_error("World map node %s was travel-enabled without being a capped target." % node_id)
				quit(1)
				return
	if not travel_enabled_found:
		push_error("World map did not highlight any currently travelable node.")
		quit(1)
		return
	if not bool(app.call("select_world_map_node", current_map_id)):
		push_error("World map did not allow selecting the current node.")
		quit(1)
		return
	for _layout_index in range(3):
		await process_frame
	var current_node_screen: Dictionary = app.call("current_screen_snapshot")
	if not str(current_node_screen.get("world_map_detail_text", "")).contains("You are here."):
		push_error("Selecting the current world-map node did not show the You are here state.")
		quit(1)
		return
	if not _world_map_detail_popup_fits(current_node_screen):
		quit(1)
		return
	var current_node_map_view: Dictionary = map_canvas.call("current_view_snapshot")
	var current_node_bounds: Dictionary = current_node_map_view.get("map_bounds", {}) if typeof(current_node_map_view.get("map_bounds", {})) == TYPE_DICTIONARY else {}
	if _map_bounds_equal(map_bounds, current_node_bounds) or not bool(current_node_map_view.get("selected_focus_zoom_active", false)):
		push_error("Selecting the current world-map node did not apply the selected-location focus zoom.")
		quit(1)
		return
	if not _map_canvas_size_equal(map_view, current_node_map_view):
		push_error("Selecting the current world-map node changed the canvas size: before %s after %s." % [JSON.stringify(map_view.get("canvas_size", {})), JSON.stringify(current_node_map_view.get("canvas_size", {}))])
		quit(1)
		return
	if not _world_map_position_in_bounds(_world_map_node_by_id(full_map, current_map_id).get("position", {}), current_node_bounds):
		push_error("Selecting the current world-map node focused bounds away from the current stop.")
		quit(1)
		return
	var serialized_before_map_select := JSON.stringify(app.call("serialized_run_state"))
	var target_node_button := map_canvas.get_node_or_null("WorldMapNode_%s" % travel_target_id) as Button
	if target_node_button == null:
		push_error("World map first-open target icon button was missing for %s." % travel_target_id)
		quit(1)
		return
	target_node_button.emit_signal("pressed")
	for _layout_index in range(3):
		await process_frame
	var selected_map_screen: Dictionary = app.call("current_screen_snapshot")
	if str(selected_map_screen.get("selected_world_map_node_id", "")) != travel_target_id:
		push_error("World map first-open icon press did not select %s." % travel_target_id)
		quit(1)
		return
	var selected_map_view: Dictionary = map_canvas.call("current_view_snapshot")
	var selected_map_bounds: Dictionary = selected_map_view.get("map_bounds", {}) if typeof(selected_map_view.get("map_bounds", {})) == TYPE_DICTIONARY else {}
	if _map_bounds_equal(map_bounds, selected_map_bounds) or not bool(selected_map_view.get("selected_focus_zoom_active", false)):
		push_error("Selecting a world-map target did not apply the selected-location focus zoom.")
		quit(1)
		return
	if not _map_canvas_size_equal(map_view, selected_map_view):
		push_error("Selecting a world-map target changed the canvas size: before %s after %s." % [JSON.stringify(map_view.get("canvas_size", {})), JSON.stringify(selected_map_view.get("canvas_size", {}))])
		quit(1)
		return
	var selected_focus_node := _world_map_node_by_id(full_map, travel_target_id)
	if not _world_map_position_in_bounds(selected_focus_node.get("position", {}), selected_map_bounds):
		push_error("Selecting a world-map target focused bounds away from the selected stop.")
		quit(1)
		return
	var detail_text := str(selected_map_screen.get("world_map_detail_text", ""))
	var travel_detail_line := ""
	for detail_line_value in detail_text.split("\n"):
		var detail_line := str(detail_line_value)
		if detail_line.begins_with("Travel:"):
			travel_detail_line = detail_line
			break
	if travel_detail_line.is_empty() or not travel_detail_line.contains(" · Cost: $") or not detail_text.contains("Distance:"):
		push_error("World map selection popup did not show travel method and cost together with distance: %s" % detail_text)
		quit(1)
		return
	if detail_text.split("\n").size() > 6:
		push_error("World map selection popup put required travel text below its six visible lines: %s" % detail_text)
		quit(1)
		return
	if not _world_map_detail_popup_fits(selected_map_screen):
		quit(1)
		return
	var detail_badges: Array = _copy_array(selected_map_screen.get("world_map_detail_badges", []))
	if detail_badges.is_empty() or detail_badges.size() > 2:
		push_error("World map selection popup should show only a location-type icon and one heat icon: %s" % str(detail_badges))
		quit(1)
		return
	var heat_badge_count := 0
	var location_badge_count := 0
	for badge_value in detail_badges:
		var glyph_id := str(_copy_dict(badge_value).get("glyph_id", ""))
		if glyph_id == "suspicion":
			heat_badge_count += 1
		elif ["environment_casino", "environment_shop"].has(glyph_id):
			location_badge_count += 1
		else:
			push_error("World map selection popup retained a redundant route icon: %s" % glyph_id)
			quit(1)
			return
	if heat_badge_count != 1 or location_badge_count > 1:
		push_error("World map selection popup did not reduce its icons to destination type plus heat: %s" % str(detail_badges))
		quit(1)
		return
	var badge_slot := app.get("world_map_badge_slot") as VBoxContainer
	if badge_slot == null or badge_slot.get_child_count() <= 0:
		push_error("World map route glyph slot was empty after selecting a route.")
		quit(1)
		return
	if not _badge_slot_icon_only_with_tooltips(badge_slot, "World map route glyphs"):
		quit(1)
		return
	var badge_child_count := badge_slot.get_child_count()
	var badge_child_instance_id := int(badge_slot.get_child(0).get_instance_id())
	for _repeat_index in range(4):
		if not bool(app.call("select_world_map_node", travel_target_id)):
			push_error("World map repeated target selection unexpectedly failed.")
			quit(1)
			return
		await process_frame
	if badge_slot.get_child_count() != badge_child_count or int(badge_slot.get_child(0).get_instance_id()) != badge_child_instance_id:
		push_error("World map route glyph row was rebuilt during an unchanged detail refresh.")
		quit(1)
		return
	if not detail_text.contains("Hours:"):
		push_error("World map selection popup did not show destination open-hours status.")
		quit(1)
		return
	if serialized_before_map_select != JSON.stringify(app.call("serialized_run_state")):
		push_error("Selecting a world-map node mutated serialized RunState before confirmation.")
		quit(1)
		return
	var blank_map_click := InputEventMouseButton.new()
	blank_map_click.button_index = MOUSE_BUTTON_LEFT
	blank_map_click.pressed = true
	blank_map_click.position = Vector2(5.0, 5.0)
	app.call("_on_world_map_holder_gui_input", blank_map_click)
	await process_frame
	var deselected_map_screen: Dictionary = app.call("current_screen_snapshot")
	if not str(deselected_map_screen.get("selected_world_map_node_id", "")).is_empty() or bool(deselected_map_screen.get("world_map_detail_popup_visible", false)):
		push_error("Clicking blank world-map space did not clear the selected location popup.")
		quit(1)
		return
	var deselected_map_view: Dictionary = map_canvas.call("current_view_snapshot")
	if bool(deselected_map_view.get("selected_focus_zoom_active", true)):
		push_error("Clicking blank world-map space did not clear the selected-location focus zoom.")
		quit(1)
		return
	if not _map_canvas_size_equal(map_view, deselected_map_view):
		push_error("Deselecting the world map changed the canvas size.")
		quit(1)
		return
	app.call("close_world_map")
	await process_frame
	var serialized_before_travel_selection := JSON.stringify(app.call("serialized_run_state"))
	if not bool(app.call("select_travel_option", travel_target_id)):
		push_error("Foundation UI rejected an available travel choice.")
		quit(1)
		return
	await process_frame
	var serialized_after_travel_selection := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before_travel_selection != serialized_after_travel_selection:
		push_error("Selecting travel mutated serialized RunState before confirmation.")
		quit(1)
		return
	var selected_travel_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	if str(selected_travel_snapshot.get("selected_travel_target_id", "")) != travel_target_id:
		push_error("Foundation UI did not store selected travel as UI-local state.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "TRAVEL":
		push_error("Foundation screen router left TRAVEL during destination selection.")
		quit(1)
		return
	if not _has_visible_text(actions_list, "Travel to"):
		push_error("Travel card did not show a travel/leave confirmation action after selection.")
		quit(1)
		return
	app.call("confirm_selected_travel")
	await process_frame
	if app.get("run_state") == null:
		push_error("Foundation UI shell did not keep an active RunState.")
		quit(1)
		return
	if str(app.call("current_screen_snapshot").get("screen", "")) != "RESULT":
		push_error("Foundation screen router did not move to RESULT after travel confirmation.")
		quit(1)
		return
	var post_travel_spatial_snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	if not str(post_travel_spatial_snapshot.get("selected_object_id", "")).is_empty():
		push_error("Foundation travel kept the previous room object selected after changing environments.")
		quit(1)
		return
	var traveled_environment: Dictionary = app.call("serialized_run_state").get("current_environment", {})
	if str(traveled_environment.get("archetype_id", "")) != travel_target_id:
		push_error("Selected travel target did not determine the generated environment.")
		quit(1)
		return
	var story_log: Array = app.call("serialized_run_state").get("story_log", [])
	if story_log.is_empty() or str((story_log[story_log.size() - 1] as Dictionary).get("type", "")) != "travel":
		push_error("Foundation travel did not record a travel story entry.")
		quit(1)
		return
	app.call("start_foundation_run", "UI-TRAVEL-SEED")
	await process_frame
	var deterministic_choices_a: Array = app.call("current_environment_view_snapshot").get("travel_choices", [])
	if deterministic_choices_a.is_empty():
		push_error("Foundation deterministic travel check did not expose choices.")
		quit(1)
		return
	var deterministic_target_id := str((deterministic_choices_a[0] as Dictionary).get("id", ""))
	app.call("select_travel_option", deterministic_target_id)
	app.call("confirm_selected_travel")
	await process_frame
	var deterministic_environment_a := JSON.stringify(app.call("current_environment_view_snapshot"))
	app.call("start_foundation_run", "UI-TRAVEL-SEED")
	await process_frame
	app.call("select_travel_option", deterministic_target_id)
	app.call("confirm_selected_travel")
	await process_frame
	var deterministic_environment_b := JSON.stringify(app.call("current_environment_view_snapshot"))
	if deterministic_environment_a != deterministic_environment_b:
		push_error("Same seed/state/travel choice did not generate deterministic travel.")
		quit(1)
		return
	app.call("start_foundation_run", "UI-COMPILE-SEED", RunStateScript.custom_challenge("ui_failure_game_fixture", "UI-COMPILE-SEED", {"home_archetype_id": "bar"}))
	await process_frame
	if not await _travel_to_first_game_environment(app):
		push_error("Failure screen check could not reach a gambling environment after the shop start.")
		quit(1)
		return
	if not _enter_ui_test_game(app):
		push_error("Failure screen check did not find a game after reaching a gambling environment.")
		quit(1)
		return
	await process_frame
	if str(app.call("current_screen_snapshot").get("screen", "")) != "GAME":
		push_error("Failure screen check could not enter a game first.")
		quit(1)
		return
	var failure_fixture_run: RunState = app.get("run_state")
	failure_fixture_run.record_score_spending(19, "ui_failure_fixture")
	var expected_failure_score := failure_fixture_run.run_spending_score
	failure_fixture_run.add_suspicion("ui_failure_screen:police", 100, "behavior", true, {"environment_id": str(failure_fixture_run.current_environment.get("id", ""))})
	app.call("_refresh")
	await process_frame
	var failure_screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	if str(failure_screen_snapshot.get("screen", "")) != "FAILURE":
		push_error("Failed run did not route to the dedicated FAILURE screen.")
		quit(1)
		return
	if bool(failure_screen_snapshot.get("has_game", true)):
		push_error("Failure inside a game did not clear the active game surface.")
		quit(1)
		return
	var failure_panel: Control = app.get("run_report_screen")
	if failure_panel == null or not failure_panel.visible:
		push_error("Unified run report was not visible for failure.")
		quit(1)
		return
	if (app.get("game_surface_canvas") as Control).visible:
		push_error("Game surface remained visible over the failure summary.")
		quit(1)
		return
	var failure_summary: Dictionary = app.call("current_run_report_snapshot")
	var failure_outcome: Dictionary = failure_summary.get("outcome", {})
	var failure_score: Dictionary = failure_summary.get("score", {})
	if str(failure_outcome.get("key", "")) != RunState.FAILURE_POLICE_CAPTURE or str(failure_outcome.get("icon_key", "")) != "police_capture":
		push_error("Run report did not preserve the police-capture reason and icon.")
		quit(1)
		return
	if int(failure_score.get("money_put_to_work", -1)) != expected_failure_score or int(failure_score.get("winner_bonus", -1)) != 1 or int(failure_score.get("final_score", -1)) != expected_failure_score:
		push_error("Failure run report did not show the unmultiplied run score.")
		quit(1)
		return
	if str(failure_outcome.get("where", "")).is_empty() or typeof(failure_summary.get("timeline", {})) != TYPE_DICTIONARY or typeof(failure_summary.get("money_rows", [])) != TYPE_ARRAY:
		push_error("Failure run report did not include where, replay, and money-flow context.")
		quit(1)
		return
	if not _has_visible_text(app, "Captured by police") or not _has_visible_text(app, "STORY · MONEY FLOW") or not _has_visible_text(app, "$%d = %d" % [expected_failure_score, expected_failure_score]):
		push_error("Failure run report did not present player-facing reason, money flow, and score.")
		quit(1)
		return
	app.call("start_foundation_run", "UI-FAILURE-SUMMARY-CLEANUP")
	await process_frame
	await process_frame
	if (app.get("run_report_screen") as Control).visible or not (app.get("run_report_model") as Dictionary).is_empty():
		push_error("Starting a new run retained the prior terminal report.")
		quit(1)
		return
	var cleared_failure_surface: Dictionary = (app.get("game_surface_canvas") as Node).call("debug_soak_snapshot")
	if not str(cleared_failure_surface.get("game_id", "")).is_empty() or int(cleared_failure_surface.get("state_key_count", -1)) != 0 or int(cleared_failure_surface.get("hit_region_count", -1)) != 0:
		push_error("Starting a new run retained the prior failure-path game canvas runtime.")
		quit(1)
		return
	var failure_reason_cases := [
		{"reason": RunState.FAILURE_BANKROLL_ZERO, "icon": "broke"},
		{"reason": RunState.FAILURE_STRANDED, "icon": "stranded"},
		{"reason": RunState.FAILURE_POLICE_CAPTURE, "icon": "police_capture"},
		{"reason": RunState.FAILURE_CASINO_TAKEN_OUT_BACK, "icon": "taken_out_back"},
		{"reason": RunState.FAILURE_ABANDONED, "icon": "walked_away"},
	]
	for reason_case in failure_reason_cases:
		var reason_data: Dictionary = reason_case
		app.call("start_foundation_run", "UI-FAILURE-%s" % str(reason_data.get("reason", "")))
		await process_frame
		var reason_fixture_run: RunState = app.get("run_state")
		var reason := str(reason_data.get("reason", ""))
		reason_fixture_run.fail_run(reason, "")
		app.call("_refresh")
		await process_frame
		var reason_screen_snapshot: Dictionary = app.call("current_screen_snapshot")
		var reason_summary: Dictionary = app.call("current_run_report_snapshot")
		var reason_outcome: Dictionary = reason_summary.get("outcome", {})
		if str(reason_screen_snapshot.get("screen", "")) != "FAILURE":
			push_error("Failure reason %s did not route to the FAILURE screen." % reason)
			quit(1)
			return
		if str(reason_outcome.get("key", "")) != reason or str(reason_outcome.get("icon_key", "")) != str(reason_data.get("icon", "")) or str(reason_outcome.get("how", "")).is_empty() or str(reason_outcome.get("where", "")).is_empty():
			push_error("Run report did not distinguish failure reason %s with icon/where/how." % reason)
			quit(1)
			return
	app.call("start_foundation_run", "UI-VICTORY-SEED")
	await process_frame
	if not await _travel_to_first_game_environment(app):
		push_error("Victory screen check could not reach a gambling environment after the shop start.")
		quit(1)
		return
	if not _enter_ui_test_game(app):
		push_error("Victory screen check did not find a game after reaching a gambling environment.")
		quit(1)
		return
	await process_frame
	if str(app.call("current_screen_snapshot").get("screen", "")) != "GAME":
		push_error("Victory screen check could not enter a game first.")
		quit(1)
		return
	var victory_fixture_run: RunState = app.get("run_state")
	victory_fixture_run.bankroll = 540
	victory_fixture_run.record_score_spending(21, "ui_victory_fixture")
	var expected_victory_score_spending := victory_fixture_run.run_spending_score
	victory_fixture_run.suspicion = {"level": 0, "cues": [], "local_levels": {}}
	victory_fixture_run.add_suspicion("ui_victory_heat", 18, "behavior", true, {"environment_id": str(victory_fixture_run.current_environment.get("id", ""))})
	victory_fixture_run.log_story({
		"type": "demo_victory",
		"objective_id": "grand_casino_demo_bankroll",
		"environment_id": str(victory_fixture_run.current_environment.get("id", "")),
		"bankroll": victory_fixture_run.bankroll,
		"message": "The host issues you a Grand Casino Players Card and lets you leave with your winnings.",
		"ended": true,
	})
	victory_fixture_run.narrative_flags["demo_victory"] = true
	victory_fixture_run.narrative_flags["demo_victory_route"] = "high_roller_cashout"
	victory_fixture_run.narrative_flags["demo_victory_message"] = RunState.GRAND_CASINO_HIGH_ROLLER_DEFAULT_SUCCESS_MESSAGE
	victory_fixture_run.narrative_flags["demo_finale_completed"] = true
	victory_fixture_run.run_status = RunState.RUN_STATUS_ENDED
	app.call("_refresh")
	await process_frame
	var victory_screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	if str(victory_screen_snapshot.get("screen", "")) != "VICTORY":
		push_error("Ended demo victory did not route to the dedicated VICTORY screen.")
		quit(1)
		return
	if bool(victory_screen_snapshot.get("has_game", true)):
		push_error("Victory inside a game did not clear the active game surface.")
		quit(1)
		return
	var victory_panel: Control = app.get("run_report_screen")
	if victory_panel == null or not victory_panel.visible:
		push_error("Unified run report was not visible for victory.")
		quit(1)
		return
	if (app.get("game_surface_canvas") as Control).visible:
		push_error("Game surface remained visible over the victory summary.")
		quit(1)
		return
	var victory_summary: Dictionary = app.call("current_run_report_snapshot")
	var victory_outcome: Dictionary = victory_summary.get("outcome", {})
	var victory_score: Dictionary = victory_summary.get("score", {})
	if str(victory_outcome.get("key", "")) != "players_card" or str(victory_outcome.get("icon_key", "")) != "players_card":
		push_error("Victory run report did not preserve the Players Card route/icon.")
		quit(1)
		return
	if str(victory_summary.get("seed", "")) != "UI-VICTORY-SEED" or str(victory_outcome.get("where", "")).is_empty():
		push_error("Victory run report did not include seed and final location/time.")
		quit(1)
		return
	if int(victory_score.get("money_put_to_work", -1)) != expected_victory_score_spending or int(victory_score.get("winner_bonus", -1)) != 3 or int(victory_score.get("final_score", -1)) != expected_victory_score_spending * 3:
		push_error("Victory run report did not triple the current score formula.")
		quit(1)
		return
	if typeof(victory_summary.get("items", {})) != TYPE_DICTIONARY or typeof(victory_summary.get("debts", [])) != TYPE_ARRAY or typeof(victory_summary.get("money_rows", [])) != TYPE_ARRAY:
		push_error("Victory run report did not include items, debt, and money-flow sections.")
		quit(1)
		return
	var victory_report_map: Dictionary = victory_summary.get("map_snapshot", {})
	var visited_node_lookup := {}
	for visited_node_id in victory_fixture_run.world_map.get("visited_path", []):
		visited_node_lookup[str(visited_node_id)] = true
	if (victory_report_map.get("nodes", []) as Array).size() != visited_node_lookup.size():
		push_error("Victory run report map did not contain exactly the environments visited during the run.")
		quit(1)
		return
	var victory_timeline: Dictionary = victory_summary.get("timeline", {})
	var victory_replay_segments: Array = victory_timeline.get("replay_segments", []) if typeof(victory_timeline.get("replay_segments", [])) == TYPE_ARRAY else []
	var recorded_travel: Dictionary = {}
	for story_value in victory_fixture_run.story_log:
		if typeof(story_value) == TYPE_DICTIONARY and str((story_value as Dictionary).get("type", "")) == "travel":
			recorded_travel = story_value
	var timed_travel_segment: Dictionary = {}
	for segment_value in victory_replay_segments:
		if typeof(segment_value) == TYPE_DICTIONARY and str((segment_value as Dictionary).get("kind", "")) == "travel":
			timed_travel_segment = segment_value
			break
	if recorded_travel.is_empty() or timed_travel_segment.is_empty():
		push_error("Victory run report did not retain its recorded travel interval.")
		quit(1)
		return
	if int(recorded_travel.get("arrived_game_clock_minutes", -1)) - int(recorded_travel.get("departed_game_clock_minutes", -1)) != int(recorded_travel.get("travel_minutes", -2)):
		push_error("Travel story timing did not match the game clock's travel duration.")
		quit(1)
		return
	if int(timed_travel_segment.get("start_game_clock_minutes", -1)) != int(recorded_travel.get("departed_game_clock_minutes", -2)) or int(timed_travel_segment.get("end_game_clock_minutes", -1)) != int(recorded_travel.get("arrived_game_clock_minutes", -2)):
		push_error("Victory replay movement was not limited to the recorded game-clock travel interval.")
		quit(1)
		return
	var victory_bag_reward: Dictionary = victory_summary.get("bag_reward", {})
	var victory_bag_choices: Array = victory_bag_reward.get("choices", []) if typeof(victory_bag_reward.get("choices", [])) == TYPE_ARRAY else []
	if not bool(victory_bag_reward.get("pending", false)) or victory_bag_choices.is_empty():
		push_error("Victory run report did not offer an earned collection bag.")
		quit(1)
		return
	var victory_report_layout: Dictionary = victory_panel.call("debug_layout_snapshot")
	if not bool(victory_report_layout.get("new_run_disabled", false)) or not bool(victory_report_layout.get("home_disabled", false)):
		push_error("Victory run report allowed the earned collection bag to be skipped.")
		quit(1)
		return
	var selected_bag_marker := str((victory_bag_choices[0] as Dictionary).get("marker_id", ""))
	var victory_meta_service: Variant = app.get("meta_collection_service")
	var unopened_bag_count_before: int = victory_meta_service.unopened_bags().size()
	app.call("claim_victory_collection_bag", selected_bag_marker)
	await process_frame
	var unopened_bag_count_after: int = victory_meta_service.unopened_bags().size()
	if unopened_bag_count_after != unopened_bag_count_before + 1:
		push_error("Claiming the victory report reward did not immediately add exactly one unopened bag.")
		quit(1)
		return
	if not victory_fixture_run.pending_bag_markers().is_empty() or not bool(victory_fixture_run.narrative_flags.get(CollectionDropServiceScript.FLUSHED_FLAG, false)):
		push_error("Claiming the victory report reward did not finalize the run's pending bag state.")
		quit(1)
		return
	var claimed_victory_summary: Dictionary = app.call("current_run_report_snapshot")
	var claimed_bag_reward: Dictionary = claimed_victory_summary.get("bag_reward", {})
	var claimed_report_layout: Dictionary = victory_panel.call("debug_layout_snapshot")
	if bool(claimed_bag_reward.get("pending", true)) or (claimed_bag_reward.get("summary_lines", []) as Array).is_empty() or bool(claimed_report_layout.get("new_run_disabled", true)) or bool(claimed_report_layout.get("home_disabled", true)):
		push_error("Victory report did not confirm the stored bag and release terminal navigation.")
		quit(1)
		return
	var persisted_meta_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(MetaCollectionServiceScript.store_path()))
	var persisted_meta: Dictionary = persisted_meta_value if typeof(persisted_meta_value) == TYPE_DICTIONARY else {}
	var persisted_bags: Array = persisted_meta.get("unopened_bags", []) if typeof(persisted_meta.get("unopened_bags", [])) == TYPE_ARRAY else []
	if persisted_bags.size() != unopened_bag_count_after:
		push_error("Claimed victory bag did not persist to the meta-home store immediately.")
		quit(1)
		return
	app.call("claim_victory_collection_bag", selected_bag_marker)
	await process_frame
	if victory_meta_service.unopened_bags().size() != unopened_bag_count_after:
		push_error("Repeated victory report bag claim duplicated the reward.")
		quit(1)
		return
	if not _has_visible_text(app, "Players Card earned"):
		push_error("Victory screen did not present the Players Card outcome title.")
		quit(1)
		return
	if not _has_visible_text(app, "Players Card"):
		push_error("Victory screen did not present the Players Card victory route.")
		quit(1)
		return
	if not _has_visible_text(app, "$%d × 3 = %d" % [expected_victory_score_spending, expected_victory_score_spending * 3]):
		push_error("Victory screen did not present the final score multiplier.")
		quit(1)
		return
	if not _has_visible_text(app, "Home") or not _has_visible_text(app, "New Run") or not _has_visible_text(app, "Copy Seed"):
		push_error("Victory screen did not present terminal actions.")
		quit(1)
		return
	app.call("start_foundation_run", "UI-VICTORY-SUMMARY-CLEANUP")
	await process_frame
	await process_frame
	if (app.get("run_report_screen") as Control).visible or not (app.get("run_report_model") as Dictionary).is_empty():
		push_error("Starting a new run retained the prior victory report.")
		quit(1)
		return
	var cleared_victory_surface: Dictionary = (app.get("game_surface_canvas") as Node).call("debug_soak_snapshot")
	if not str(cleared_victory_surface.get("game_id", "")).is_empty() or int(cleared_victory_surface.get("state_key_count", -1)) != 0 or int(cleared_victory_surface.get("hit_region_count", -1)) != 0:
		push_error("Starting a new run retained the prior victory-path game canvas runtime.")
		quit(1)
		return
	if not await _check_lender_acceptance_does_not_open_motel_popup(app):
		quit(1)
		return
	environment_canvas.queue_free()
	game_canvas.queue_free()
	app.queue_free()
	await process_frame
	print("UI scene compile check passed.")
	quit(0)


