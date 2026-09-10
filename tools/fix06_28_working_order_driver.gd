extends SceneTree

# Runnable production-host interaction proof for fix06_28.  It intentionally
# starts ordinary seeded runs, resolves exact rendered semantic ids, and sends
# physical-mouse InputEvents through the viewport.  It never fabricates an
# EnvironmentInstance and never calls a host's private action callback.

const MainScene := preload("res://scenes/main.tscn")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const ProfileInventoryScript := preload("res://scripts/core/profile_inventory.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")

const SEEDS := ["FIRST-NIGHT-ACE-17", "PLAYTEST-CATALOG-01", "SCENARIO-AUDIT"]
const SETTINGS_PATH := "user://fix06_28_working_order_settings.json"
const META_PATH := "user://fix06_28_working_order_meta.json"
const PROFILE_PATH := "user://fix06_28_working_order_profile.json"
const REQUIRED_SURFACE_FAMILIES := ["scratch_tickets", "pull_tabs", "slots", "dice", "blackjack", "baccarat", "cards", "wheel", "coin_pusher", "craps", "crew_poker"]
const REQUIRED_PUNCHLINE_LAYERS := ["club", "casino", "back_room"]
const REQUIRED_CREW_MILESTONES := ["favor", "job", "delivery"]

var failures: Array[String] = []
var report := {
	"schema_version": 1,
	"check_id": "fix06_28_working_order_driver",
	"authority": {
		"host": "res://scenes/main.tscn",
		"targeting": "exact_rendered_semantic_id",
		"input": "Viewport.push_input(InputEventMouseButton)",
		"consequence_oracle": "explicit_player_observable_channels",
	},
	"seeds": [],
	"failures": [],
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, SETTINGS_PATH)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, META_PATH)
	OS.set_environment(ProfileInventoryScript.INVENTORY_PATH_ENV, PROFILE_PATH)
	var isolated_settings: UserSettings = UserSettingsScript.new()
	isolated_settings.reset()
	if isolated_settings.save() != OK:
		_fail("Could not prepare isolated settings.")
		_finish()
		return
	# This proof covers ordinary runs, not the first-launch lesson. Prepare the
	# same persisted profile state a player has after completing that lesson;
	# every run is still entered through Run Setup and its visible start button.
	var isolated_profile: ProfileInventory = ProfileInventoryScript.new()
	isolated_profile.from_dict({"tutorial_completed": true})
	if isolated_profile.save() != OK:
		_fail("Could not prepare the ordinary-run profile precondition.")
		_finish()
		return
	report["profile_precondition"] = "tutorial_completed"
	var action_probe := _requested_action_probe()
	if not action_probe.is_empty():
		var probed_action := await _verify_action_isolated(
			str(action_probe.get("seed", "")),
			str(action_probe.get("semantic_id", "")),
			int(action_probe.get("action_index", 0)),
			str(action_probe.get("node_id", ""))
		)
		report["action_probe"] = probed_action
		if not bool(probed_action.get("passed", false)):
			_fail("Focused visible action probe did not produce an observable consequence.")
		_finish()
		return
	if OS.get_cmdline_user_args().has("--surface-only"):
		report["seeds"].append({"seed": "VISIBLE-GAME-LIBRARY", "surface_families_resolved": [], "punchline_layers": [], "crew_milestones": [], "room_objects": [], "actions": []})
		await _verify_surface_families_via_visible_library()
		var resolved := _array(report["seeds"][0].get("surface_families_resolved", []))
		var missing := _missing_strings(REQUIRED_SURFACE_FAMILIES, resolved)
		report["surface_only"] = {"resolved": resolved, "missing": missing, "passed": missing.is_empty()}
		if not missing.is_empty():
			_fail("Visible Game Library did not resolve required families: %s" % JSON.stringify(missing))
		_finish()
		return
	if OS.get_cmdline_user_args().has("--crew-only"):
		report["seeds"].append({"seed": "FIRST-NIGHT-ACE-17", "surface_families_resolved": [], "punchline_layers": [], "crew_milestones": [], "room_objects": [], "actions": []})
		await _verify_visible_crew_favor_delivery_route()
		var crew_resolved := _array(report["seeds"][0].get("crew_milestones", []))
		var crew_missing := _missing_strings(REQUIRED_CREW_MILESTONES, crew_resolved)
		report["crew_only"] = {"resolved": crew_resolved, "missing": crew_missing, "passed": crew_missing.is_empty()}
		if not crew_missing.is_empty():
			_fail("Visible production UI did not resolve Crew milestones: %s" % JSON.stringify(crew_missing))
		_finish()
		return
	if OS.get_cmdline_user_args().has("--base-only"):
		var base_seeds: Array = _requested_base_seeds()
		for seed in base_seeds:
			await _verify_seed(seed)
		var passed_seed_count := 0
		for seed_value in _array(report.get("seeds", [])):
			if bool(_dict(seed_value).get("passed", false)):
				passed_seed_count += 1
		report["base_only"] = {
			"passed": passed_seed_count == base_seeds.size(),
			"passed_seed_count": passed_seed_count,
			"required_seed_count": base_seeds.size(),
		}
		if passed_seed_count != base_seeds.size():
			_fail("Visible room/action/travel/save pass completed %d of %d requested seeds." % [passed_seed_count, base_seeds.size()])
		_finish()
		return
	for seed in SEEDS:
		await _verify_seed(seed)
	await _verify_surface_families_via_visible_library()
	await _verify_visible_crew_favor_delivery_route()
	_apply_full_acceptance_bar()
	_finish()


func _requested_base_seeds() -> Array:
	for argument in OS.get_cmdline_user_args():
		var value := str(argument)
		if value.begins_with("--base-seed="):
			var requested := value.trim_prefix("--base-seed=").strip_edges()
			if requested in SEEDS:
				return [requested]
			_fail("Unsupported focused base seed: %s" % requested)
			return []
	return Array(SEEDS)


func _requested_action_probe() -> Dictionary:
	for argument in OS.get_cmdline_user_args():
		var value := str(argument)
		if not value.begins_with("--action-probe="):
			continue
		var fields := value.trim_prefix("--action-probe=").split("|", false)
		if fields.size() != 4:
			_fail("Action probe requires seed|node|semantic-id|action-index.")
			return {}
		return {
			"seed": fields[0],
			"node_id": fields[1],
			"semantic_id": fields[2],
			"action_index": int(fields[3]),
		}
	return {}


func _verify_seed(seed: String) -> void:
	var seed_record := {
		"seed": seed,
		"start_via_visible_ui": false,
		"room_objects": [],
		"actions": [],
		"travel": {"departed": false, "arrived": false, "revisited": false, "rooms": []},
		"save_continue": {"saved": false, "main_menu": false, "continued": false, "revisited_same_node": false},
		"surface_families_resolved": [],
		"punchline_layers": [],
		"crew_milestones": [],
		"passed": false,
	}
	var app := await _start_app(seed)
	if app == null:
		_fail("%s could not start through the production host." % seed)
		report["seeds"].append(seed_record)
		return
	seed_record["start_via_visible_ui"] = true
	await _resolve_visible_blocking_dialogue(app)
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
		_fail("%s opened without a visible production room canvas." % seed)
		await _dispose_app(app)
		report["seeds"].append(seed_record)
		return
	var initial_node_id := _current_visible_node_id(app)
	var object_manifest: Array = _array(canvas.call("current_view_snapshot").get("objects", [])).duplicate(true)
	_verify_single_environment_plane(canvas, seed)
	if object_manifest.is_empty():
		_fail("%s generated a room with no rendered objects." % seed)
	for value in object_manifest:
		var object_data := _dict(value)
		var semantic_id := _object_id(object_data)
		if semantic_id.is_empty() or not bool(object_data.get("visible", true)):
			continue
		var object_record := await _verify_selection(app, canvas, object_data, seed)
		object_record["node_id"] = initial_node_id
		seed_record["room_objects"].append(object_record)
		var actions: Array = _array(object_record.get("actions", []))
		for action_index in range(actions.size()):
			var action_record := await _verify_action_isolated(seed, semantic_id, action_index)
			action_record["node_id"] = initial_node_id
			seed_record["actions"].append(action_record)
	seed_record["travel"] = await _verify_depart_arrive_revisit(app, seed, seed_record)
	seed_record["save_continue"] = await _verify_save_continue(app, seed)
	await _dispose_app(app)
	seed_record["passed"] = _records_passed(_array(seed_record["room_objects"])) \
		and _records_passed(_array(seed_record["actions"])) \
		and bool(_dict(seed_record["travel"]).get("revisited", false)) \
		and bool(_dict(seed_record["save_continue"]).get("continued", false))
	report["seeds"].append(seed_record)


func _verify_visible_crew_favor_delivery_route() -> void:
	var route := {"seed": "FIRST-NIGHT-ACE-17", "favor": false, "job": false, "delivery": false, "events": [], "errors": []}
	var app := await _start_app("FIRST-NIGHT-ACE-17")
	if app == null:
		route["errors"].append("ordinary run did not start")
		report["crew_route"] = route
		return
	await _resolve_visible_blocking_dialogue(app)
	var home_target := _current_visible_node_id(app)
	if not await _travel_until_exact_node(app, "FIRST-NIGHT-ACE-17", "corner_store"):
		route["errors"].append("visible route could not reach Corner Store")
		await _dispose_app(app)
		report["crew_route"] = route
		return
	var lender_target := _current_visible_node_id(app)
	await _resolve_visible_blocking_dialogue(app)
	var lender_open := await _activate_exact_room_action(app, "lender:the_crew", 0)
	route["lender_probe"] = lender_open
	if not bool(lender_open.get("ok", false)):
		route["errors"].append("exact lender interaction did not open")
		report["crew_route"] = route
		await _dispose_app(app)
		return
	else:
		var accepted := await _choose_visible_talk_choice(app, "accept", "lender_conversation:borrow:the_crew")
		route["events"].append(accepted)
		route["favor"] = bool(accepted.get("resolved", false)) and not str(accepted.get("visible_message", "")).is_empty()
	var alternate_target := home_target
	for attempt in range(48):
		var live_run: RunState = app.get("run_state")
		if live_run != null and live_run.delivery_has_active_run():
			route["job"] = not _first_visible_room_object_with_prefix(app, "delivery:pickup:").is_empty()
			break
		var talk := _visible_talk_snapshot(app)
		if str(talk.get("event_id", "")) == "crew_favor_delivery":
			var job_choice := await _choose_visible_talk_choice(app, "run_package", "crew_favor_delivery")
			route["events"].append(job_choice)
			route["job"] = bool(job_choice.get("resolved", false)) and not str(job_choice.get("visible_message", "")).is_empty()
			break
		var event_popup := _visible_event_popup_snapshot(app)
		if str(event_popup.get("event_id", "")) == "crew_favor_delivery":
			var popup_job_choice := await _choose_visible_event_popup_choice(app, "run_package", "crew_favor_delivery")
			route["events"].append(popup_job_choice)
			route["job"] = bool(popup_job_choice.get("resolved", false)) and not str(popup_job_choice.get("visible_message", "")).is_empty()
			break
		if bool(talk.get("visible", false)):
			await _resolve_visible_blocking_dialogue(app)
			continue
		var ordinary_action := await _activate_first_ordinary_room_action(app)
		if bool(ordinary_action.get("ok", false)):
			route["events"].append(ordinary_action)
			var after_action_talk := _visible_talk_snapshot(app)
			if str(after_action_talk.get("event_id", "")) == "crew_favor_delivery":
				continue
			var after_action_popup := _visible_event_popup_snapshot(app)
			if str(after_action_popup.get("event_id", "")) == "crew_favor_delivery":
				continue
			if bool(after_action_talk.get("visible", false)):
				await _resolve_visible_blocking_dialogue(app)
		await _resolve_visible_blocking_dialogue(app, "crew_favor_delivery")
		if str(_visible_event_popup_snapshot(app).get("event_id", "")) == "crew_favor_delivery" \
				or str(_visible_talk_snapshot(app).get("event_id", "")) == "crew_favor_delivery":
			continue
		# Stay in the room while it still exposes a genuine action boundary. The
		# old driver paid for a round trip after every click, exhausting the seeded
		# run before the random-but-budget-bypassing favor could be selected.
		if not bool(ordinary_action.get("ok", false)):
			if not await _travel_until_exact_node(app, "FIRST-NIGHT-ACE-17", alternate_target, "crew_favor_delivery"):
				route["errors"].append("favor cadence travel failed at attempt %d" % attempt)
				break
			alternate_target = lender_target if alternate_target == home_target else home_target
	if bool(route["job"]):
		# The authored route begins with a physical pickup in the current room.
		var pickup_id := _first_visible_room_object_with_prefix(app, "delivery:pickup:")
		if not pickup_id.is_empty():
			route["events"].append(await _activate_exact_room_action(app, pickup_id, 0))
		var target_id := await _open_map_and_visible_delivery_target(app)
		if target_id.is_empty():
			route["errors"].append("delivery map exposed no marked target")
		else:
			var map := _dict(_dict(app.call("current_screen_snapshot")).get("world_map", {}))
			var target_node: Dictionary = {}
			for node_value in _array(map.get("nodes", [])):
				var node := _dict(node_value)
				if str(node.get("id", "")) == target_id:
					target_node = node.duplicate(true)
					break
			route["delivery_map"] = {
				"target_id": target_id,
				"enabled_ids": _array(map.get("travel_enabled_node_ids", [])).duplicate(),
				"target": target_node,
			}
			var target_directly_enabled := _array(map.get("travel_enabled_node_ids", [])).has(target_id)
			var arrived := await _confirm_open_map_target(app, target_id) if target_directly_enabled else false
			if not target_directly_enabled:
				if await _close_visible_world_map(app):
					arrived = await _travel_until_exact_node(app, "FIRST-NIGHT-ACE-17", target_id)
				else:
					route["errors"].append("delivery map could not close for an indirect marked route")
			if not arrived:
				route["errors"].append("marked delivery target could not be reached through visible routes")
			else:
				await _resolve_visible_blocking_dialogue(app)
				var handoff_id := _first_visible_room_object_with_prefix(app, "delivery:handoff:")
				if handoff_id.is_empty():
					handoff_id = _first_visible_room_object_with_prefix(app, "crew::package_handoff")
				if not handoff_id.is_empty():
					var handoff := await _activate_exact_room_action(app, handoff_id, 0)
					route["events"].append(handoff)
					route["delivery"] = bool(handoff.get("ok", false)) and not str(handoff.get("visible_message", "")).is_empty()
				else:
					route["errors"].append("marked destination exposed no exact handoff object")
	for milestone in REQUIRED_CREW_MILESTONES:
		if bool(route.get(milestone, false)) and not _array(report["seeds"][0]["crew_milestones"]).has(milestone):
			report["seeds"][0]["crew_milestones"].append(milestone)
	if not bool(route["favor"]) or not bool(route["job"]) or not bool(route["delivery"]):
		_fail("Visible Crew favor/job/delivery route did not complete: %s" % JSON.stringify(route))
	report["crew_route"] = route
	await _dispose_app(app)


func _verify_surface_families_via_visible_library() -> void:
	var representatives := [
		{"family": "scratch_tickets", "game_id": "scratch_tickets", "label": "Scratch Tickets"},
		{"family": "pull_tabs", "game_id": "pull_tabs", "label": "Pull Tabs"},
		{"family": "slots", "game_id": "slot", "label": "Slot"},
		{"family": "dice", "game_id": "bar_dice", "label": "Bar Dice"},
		{"family": "blackjack", "game_id": "blackjack", "label": "Blackjack"},
		{"family": "baccarat", "game_id": "baccarat", "label": "Baccarat"},
		{"family": "cards", "game_id": "video_poker", "label": "Video Poker"},
		{"family": "wheel", "game_id": "roulette", "label": "Roulette"},
		{"family": "coin_pusher", "game_id": "coin_pusher", "label": "Quarter Falls"},
		{"family": "craps", "game_id": "craps", "label": "Craps"},
		{"family": "crew_poker", "game_id": "crew_draw_poker", "label": "Back-Room Poker"},
	]
	var records: Array = []
	for representative_value in representatives:
		var representative := _dict(representative_value)
		var record := await _play_library_surface(representative)
		records.append(record)
		if bool(record.get("resolved", false)) and not _array(report["seeds"][0].get("surface_families_resolved", [])).has(str(representative.get("family", ""))):
			report["seeds"][0]["surface_families_resolved"].append(str(representative.get("family", "")))
	report["surface_family_runs"] = records


func _play_library_surface(representative: Dictionary) -> Dictionary:
	var family := str(representative.get("family", ""))
	var game_id := str(representative.get("game_id", ""))
	var label := str(representative.get("label", ""))
	var record := {"family": family, "game_id": game_id, "entered": false, "resolved": false, "actions": [], "public_result": {}}
	var app := MainScene.instantiate() as Control
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "fix06_28_library_%s" % game_id)
	root.add_child(app)
	await _settle(6)
	var library_button := app.get("game_library_button") as Button
	if library_button == null or not library_button.is_visible_in_tree() or library_button.disabled:
		_fail("%s surface has no visible Game Library entry." % family)
		await _dispose_app(app)
		return record
	await _push_click(app.get_viewport(), library_button.get_global_rect().get_center())
	await _settle(5)
	var game_menu := app.get("game_test_menu") as Control
	var game_button := _find_button_with_text(game_menu, label)
	if game_button == null:
		_fail("%s surface has no visible exact %s card." % [family, label])
		await _dispose_app(app)
		return record
	await _scroll_control_into_view(app.get_viewport(), game_button)
	await _push_click(app.get_viewport(), game_button.get_global_rect().get_center())
	await _settle(10)
	var game_view := _dict(app.call("current_game_view_snapshot"))
	record["entered"] = str(_dict(app.call("current_screen_snapshot")).get("screen", "")) == "GAME" and str(game_view.get("game_id", "")) == game_id
	if not bool(record["entered"]):
		_fail("%s/%s visible library card did not open its production surface." % [family, game_id])
		await _dispose_app(app)
		return record
	for _turn in range(48):
		var canvas := app.get("game_surface_canvas") as Control
		if canvas == null or not canvas.visible or not canvas.has_method("current_view_snapshot"):
			break
		if family == "coin_pusher" and canvas.has_method("global_rect_for_surface_action"):
			var rail_rect: Rect2 = canvas.call("global_rect_for_surface_action", "coin_pusher_carriage_drag", -1)
			if rail_rect.has_area():
				var rail_target_x := lerpf(rail_rect.position.x + 6.0, rail_rect.end.x - 6.0, float(_turn % 7) / 6.0)
				await _push_drag(app.get_viewport(), rail_rect.get_center(), Vector2(rail_target_x, rail_rect.get_center().y))
		var surface := _dict(canvas.call("current_view_snapshot"))
		var binding := _preferred_surface_binding(_array(surface.get("surface_hit_actions", [])))
		if binding.is_empty() or not canvas.has_method("local_position_for_surface_action"):
			break
		var action := str(binding.get("action", ""))
		var index := int(binding.get("index", 0))
		var local_position: Vector2 = canvas.call("local_position_for_surface_action", action, index)
		if local_position.x < 0.0:
			break
		var before_result := JSON.stringify(app.get("last_game_result"))
		var before_outcome := str(surface.get("outcome_message", "")).strip_edges()
		await _push_click(app.get_viewport(), canvas.get_global_rect().position + local_position)
		var resolution := await _wait_for_surface_public_resolution(app, canvas, before_result, before_outcome)
		var public_result := _dict(resolution.get("public_result", {}))
		var action_record := {
			"action": action,
			"index": index,
			"input_class": "InputEventMouseButton",
			"result_changed": bool(resolution.get("result_changed", false)),
			"visible_outcome_changed": bool(resolution.get("visible_outcome_changed", false)),
			"public_result": public_result,
		}
		record["actions"].append(action_record)
		if family == "coin_pusher" and bool(resolution.get("result_changed", false)) \
				and action in ["coin_pusher_drop_charge", "coin_pusher_drop"] \
				and str(public_result.get("action_id", "")) == "drop_quarter":
			record["accepted_drop"] = public_result
			# Feed one bounded visible batch before waiting once for the physical
			# cascade; per-quarter settlement polling adds no player-route proof.
			var collection := await _wait_for_coin_pusher_collection(app, canvas) if _turn == 47 else {"attempted": false, "resolved": false, "settlement": {"deferred_until_batch": 48}}
			action_record["settlement_wait"] = _dict(collection.get("settlement", {}))
			record["actions"][-1] = action_record
			if bool(collection.get("attempted", false)):
				record["actions"].append(_dict(collection.get("action_record", {})))
			if bool(collection.get("resolved", false)):
				record["resolved"] = true
				record["public_result"] = _dict(collection.get("public_result", {}))
				record["settlement"] = _dict(collection.get("settlement", {}))
				break
			continue
		if family != "coin_pusher" and bool(resolution.get("resolved", false)):
			record["resolved"] = true
			record["public_result"] = public_result
			break
	if not bool(record["resolved"]):
		_fail("%s/%s opened through visible UI but did not reach both a changed public result and changed visible outcome after %d pointer actions." % [family, game_id, _array(record["actions"]).size()])
	await _dispose_app(app)
	return record


func _wait_for_coin_pusher_collection(app: Control, canvas: Control) -> Dictionary:
	var settlement := {"waited_frames": 0, "queue_drained": false, "tray_count": 0, "tray_value": 0}
	var collect_binding: Dictionary = {}
	for frame_index in range(900):
		await process_frame
		settlement["waited_frames"] = frame_index + 1
		if not is_instance_valid(canvas) or not canvas.has_method("current_view_snapshot"):
			break
		var snapshot := _dict(canvas.call("current_view_snapshot"))
		var state := _dict(snapshot.get("state", {}))
		settlement["queue_drained"] = int(state.get("coin_pusher_drop_queue_count", -1)) == 0
		settlement["tray_count"] = int(state.get("coin_pusher_tray_count", 0))
		settlement["tray_value"] = int(state.get("coin_pusher_tray_value", 0))
		var settlement_outcome := str(state.get("coin_pusher_settlement_outcome", "")).strip_edges()
		var settlement_message := str(snapshot.get("outcome_message", "")).strip_edges()
		if settlement_outcome == "no_payout" and not settlement_message.is_empty():
			settlement["terminal_outcome"] = settlement_outcome
			settlement["settled_drop_count"] = int(state.get("coin_pusher_settled_drop_count", 0))
			var public_result := _surface_public_result_summary(_dict(app.get("last_game_result")), settlement_message)
			public_result["outcome"] = settlement_outcome
			public_result["settlement_source"] = "visible_realtime_surface"
			public_result["settled_drop_count"] = int(settlement["settled_drop_count"])
			return {"attempted": false, "resolved": true, "settlement": settlement, "public_result": public_result}
		for value in _array(snapshot.get("surface_hit_actions", [])):
			var candidate := _dict(value)
			# Hit-region snapshots contain only enabled regions and therefore omit a
			# redundant enabled field.
			if str(candidate.get("action", "")) == "coin_pusher_collect" and bool(candidate.get("enabled", true)):
				collect_binding = candidate
				break
		if bool(settlement["queue_drained"]) and int(settlement["tray_count"]) > 0 and not collect_binding.is_empty():
			break
	if collect_binding.is_empty() or not bool(settlement["queue_drained"]) or int(settlement["tray_count"]) <= 0:
		return {"attempted": false, "resolved": false, "settlement": settlement}
	var before_result := JSON.stringify(app.get("last_game_result"))
	var before_outcome := str(_dict(canvas.call("current_view_snapshot")).get("outcome_message", "")).strip_edges()
	var local_position: Vector2 = canvas.call("local_position_for_surface_action", "coin_pusher_collect", int(collect_binding.get("index", 0)))
	if local_position.x < 0.0:
		return {"attempted": false, "resolved": false, "settlement": settlement}
	await _push_click(app.get_viewport(), canvas.get_global_transform_with_canvas() * local_position)
	var resolution := await _wait_for_surface_public_resolution(app, canvas, before_result, before_outcome)
	var public_result := _dict(resolution.get("public_result", {}))
	var resolved := bool(resolution.get("resolved", false)) and str(public_result.get("action_id", "")) == "coin_pusher_collect"
	return {
		"attempted": true,
		"resolved": resolved,
		"settlement": settlement,
		"public_result": public_result,
		"action_record": {
			"action": "coin_pusher_collect",
			"index": int(collect_binding.get("index", 0)),
			"input_class": "InputEventMouseButton",
			"result_changed": bool(resolution.get("result_changed", false)),
			"visible_outcome_changed": bool(resolution.get("visible_outcome_changed", false)),
			"public_result": public_result,
		},
	}


func _wait_for_surface_public_resolution(app: Control, canvas: Control, before_result: String, before_outcome: String) -> Dictionary:
	var latest_result: Dictionary = {}
	var latest_outcome := ""
	for _frame in range(120):
		await process_frame
		var result_value: Variant = app.get("last_game_result")
		if typeof(result_value) == TYPE_DICTIONARY:
			latest_result = (result_value as Dictionary).duplicate(true)
		if is_instance_valid(canvas) and canvas.has_method("current_view_snapshot"):
			latest_outcome = str(_dict(canvas.call("current_view_snapshot")).get("outcome_message", "")).strip_edges()
		var result_changed := not latest_result.is_empty() and JSON.stringify(latest_result) != before_result
		var visible_changed := not latest_outcome.is_empty() and latest_outcome != before_outcome
		if result_changed and visible_changed:
			return {
				"resolved": true,
				"result_changed": true,
				"visible_outcome_changed": true,
				"public_result": _surface_public_result_summary(latest_result, latest_outcome),
			}
	return {
		"resolved": false,
		"result_changed": not latest_result.is_empty() and JSON.stringify(latest_result) != before_result,
		"visible_outcome_changed": not latest_outcome.is_empty() and latest_outcome != before_outcome,
		"public_result": _surface_public_result_summary(latest_result, latest_outcome),
	}


func _surface_public_result_summary(result: Dictionary, visible_outcome: String) -> Dictionary:
	var deltas := _dict(result.get("deltas", {}))
	return {
		"action_id": _bounded_text(result.get("action_id", "")),
		"resolution_id": _bounded_text(result.get("resolution_id", "")),
		"outcome": _bounded_text(result.get("outcome", result.get("result", ""))),
		"message": _bounded_text(result.get("message", "")),
		"visible_outcome_message": _bounded_text(visible_outcome),
		"ok": bool(result.get("ok", false)),
		"won": bool(result.get("won", false)),
		"bankroll_delta": int(deltas.get("bankroll_delta", result.get("bankroll_delta", 0))),
	}


func _bounded_text(value: Variant, limit: int = 240) -> String:
	var rendered := str(value).strip_edges()
	return rendered.substr(0, mini(limit, rendered.length()))


func _preferred_surface_binding(hit_actions: Array) -> Dictionary:
	var preferred := [
		"scratch_all", "scratch_file_ticket", "scratch_buy", "pull_tab_buy", "slot_spin", "bar_dice_ack_cover", "bar_dice_throw", "bar_dice_reveal", "bar_dice_ack_call", "bar_dice_resolve", "bar_dice_roll", "bar_dice_press", "bar_dice_stake",
		"blackjack_deal", "blackjack_hit", "blackjack_stand", "blackjack_double", "blackjack_chip", "baccarat_deal", "baccarat_bet", "baccarat_chip",
		"video_poker_draw", "video_poker_deal", "video_poker_mark", "roulette_spin", "roulette_bet", "roulette_place_bet", "coin_pusher_collect", "coin_pusher_drop_charge", "coin_pusher_drop", "coin_pusher_skill_stop", "coin_pusher_insert", "coin_pusher_play",
		"craps_roll", "craps_bet", "crew_poker_draw", "crew_poker_deal", "crew_poker_call", "crew_poker_check", "crew_poker_fold", "crew_poker_mark",
	]
	for preferred_action in preferred:
		for value in hit_actions:
			var binding := _dict(value)
			if str(binding.get("action", "")) == preferred_action and bool(binding.get("enabled", true)):
				return {"action": preferred_action, "index": int(binding.get("index", 0))}
	for value in hit_actions:
		var binding := _dict(value)
		var action := str(binding.get("action", ""))
		if bool(binding.get("enabled", true)) and not action.is_empty() and not action.contains("cheat") and not action.contains("back"):
			return {"action": action, "index": int(binding.get("index", 0))}
	return {}


func _find_button_with_text(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is Button and node.is_visible_in_tree() and not (node as Button).disabled and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button_with_text(child, text)
		if found != null:
			return found
	return null


func _scroll_control_into_view(viewport: Viewport, control: Control) -> void:
	var scroll: ScrollContainer = null
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			scroll = ancestor as ScrollContainer
			break
		ancestor = ancestor.get_parent()
	if scroll == null:
		return
	for _attempt in range(24):
		var control_rect := control.get_global_rect()
		var clip_rect := scroll.get_global_rect()
		if clip_rect.encloses(control_rect):
			return
		var global_position := clip_rect.get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = global_position
		motion.global_position = global_position
		viewport.push_input(motion, true)
		await process_frame
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if control_rect.get_center().y > clip_rect.get_center().y else MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.factor = 4.0
		wheel.position = global_position
		wheel.global_position = global_position
		viewport.push_input(wheel, true)
		await process_frame
		wheel = wheel.duplicate()
		wheel.pressed = false
		viewport.push_input(wheel, true)
		await process_frame


func _visible_talk_snapshot(app: Control) -> Dictionary:
	var dock: Variant = app.get("talk_dock")
	return _dict(dock.call("current_snapshot")) if dock != null and dock.has_method("current_snapshot") else {}


func _visible_event_popup_snapshot(app: Control) -> Dictionary:
	return _dict(app.call("current_event_choice_popup_snapshot")) if app.has_method("current_event_choice_popup_snapshot") else {}


func _resolve_visible_blocking_dialogue(app: Control, preserve_event_id: String = "") -> void:
	for _attempt in range(12):
		var item_popup := _dict(app.call("current_item_found_popup_snapshot")) if app.has_method("current_item_found_popup_snapshot") else {}
		if bool(item_popup.get("visible", false)):
			# This toast deliberately ignores input and owns a fixed three-second
			# presentation window. Waiting is the only route available to a player;
			# once it clears, any conversation it temporarily hid becomes clickable.
			await create_timer(3.2).timeout
			await _settle(3)
			continue
		var coach: Variant = app.get("coach_overlay")
		var ok_button: Button = coach.get("ok_button") as Button if coach != null else null
		if ok_button != null and ok_button.is_visible_in_tree() and not ok_button.disabled:
			await _push_click(app.get_viewport(), ok_button.get_global_rect().get_center())
			await _settle(3)
			continue
		var popup := _visible_event_popup_snapshot(app)
		if bool(popup.get("visible", false)):
			if str(popup.get("event_id", "")) == preserve_event_id:
				return
			var popup_ids := _array(popup.get("choice_ids", []))
			if popup_ids.is_empty():
				return
			await _choose_visible_event_popup_choice(app, str(popup_ids[0]), str(popup.get("event_id", "")))
			continue
		var talk := _visible_talk_snapshot(app)
		if not bool(talk.get("visible", false)):
			return
		if str(talk.get("event_id", "")) == preserve_event_id:
			return
		var ids := _array(talk.get("choice_ids", []))
		if ids.is_empty():
			# Linear/final TalkDock beats have no choice buttons. A player advances
			# them by clicking the visible dock itself; leaving that beat open makes
			# the host's modal guard correctly reject the next room action.
			var dock: Variant = app.get("talk_dock")
			var panel: Control = dock.get("panel") as Control if dock != null else null
			if panel == null or not panel.is_visible_in_tree():
				return
			await _push_click(app.get_viewport(), panel.get_global_rect().get_center())
			await _settle(3)
			continue
		await _choose_visible_talk_choice(app, str(ids[0]), str(talk.get("event_id", "")))


func _choose_visible_event_popup_choice(app: Control, choice_id: String, expected_event_id: String) -> Dictionary:
	var result := {"event_id": expected_event_id, "choice_id": choice_id, "resolved": false, "visible_message": ""}
	var popup := _visible_event_popup_snapshot(app)
	if not bool(popup.get("visible", false)) or str(popup.get("event_id", "")) != expected_event_id:
		return result
	var ids := _array(popup.get("choice_ids", []))
	var choice_index := ids.find(choice_id)
	var choice_list: Node = app.get("event_choice_popup_choices_list") as Node
	var buttons: Array[Button] = []
	_collect_enabled_buttons(choice_list, buttons)
	if choice_index < 0 or choice_index >= buttons.size():
		return result
	await _push_click(app.get_viewport(), buttons[choice_index].get_global_rect().get_center())
	await _settle(8)
	result["resolved"] = not bool(_visible_event_popup_snapshot(app).get("visible", false))
	result["visible_message"] = _observable_visible_message(app)
	return result


func _choose_visible_talk_choice(app: Control, choice_id: String, expected_event_id: String) -> Dictionary:
	var result := {"event_id": expected_event_id, "choice_id": choice_id, "resolved": false, "visible_message": ""}
	for _confirm_attempt in range(3):
		var dock: Variant = app.get("talk_dock")
		var talk := _visible_talk_snapshot(app)
		if dock == null or not bool(talk.get("visible", false)) or str(talk.get("event_id", "")) != expected_event_id:
			result["resolved"] = _confirm_attempt > 0
			break
		if bool(talk.get("typewriter_active", false)):
			var panel: Control = dock.get("panel") as Control
			if panel != null and panel.is_visible_in_tree():
				await _push_click(app.get_viewport(), panel.get_global_rect().get_center())
				await _settle(2)
		var ids := _array(_visible_talk_snapshot(app).get("choice_ids", []))
		var choice_index := ids.find(choice_id)
		var choice_list: Node = dock.get("choice_list") as Node
		var buttons: Array[Button] = []
		_collect_enabled_buttons(choice_list, buttons)
		if choice_index < 0 or choice_index >= buttons.size():
			break
		await _push_click(app.get_viewport(), buttons[choice_index].get_global_rect().get_center())
		await _settle(6)
	result["visible_message"] = _observable_visible_message(app)
	return result


func _collect_enabled_buttons(node: Node, output: Array[Button]) -> void:
	if node == null:
		return
	if node is Button and (node as Button).is_visible_in_tree() and not (node as Button).disabled:
		output.append(node as Button)
	for child in node.get_children():
		_collect_enabled_buttons(child, output)


func _activate_exact_room_action(app: Control, semantic_id: String, action_index: int) -> Dictionary:
	var result := {"ok": false, "semantic_id": semantic_id, "action_index": action_index, "visible_message": "", "visible_object_ids": [], "route_errors": []}
	await _resolve_visible_blocking_dialogue(app, "crew_favor_delivery")
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible:
		result["route_errors"].append("room canvas unavailable")
		return result
	for value in _array(_dict(canvas.call("current_view_snapshot")).get("objects", [])):
		var visible_id := _object_id(_dict(value))
		if not visible_id.is_empty():
			result["visible_object_ids"].append(visible_id)
	var local_failures: Array = []
	var focused := Fidelity.push_exact_canvas_mouse_click(app.get_viewport(), canvas, semantic_id, local_failures, "fix06_28 exact route action")
	await _settle(4)
	if not bool(focused.get("ok", false)):
		result["route_errors"] = local_failures.duplicate(true)
		result["overlay_state"] = _dict(app.call("current_overlay_state_snapshot")) if app.has_method("current_overlay_state_snapshot") else {}
		result["talk"] = _visible_talk_snapshot(app)
		result["event_popup"] = _visible_event_popup_snapshot(app)
		return result
	var panel := _dict(_dict(canvas.call("current_view_snapshot")).get("selected_info", {}))
	result["selected_panel"] = panel.duplicate(true)
	var actions := _array(panel.get("actions", []))
	if action_index < 0 or action_index >= actions.size():
		result["route_errors"].append("selected panel exposed %d actions" % actions.size())
		result["selected_panel"] = panel
		return result
	var action := _dict(actions[action_index])
	var local_position: Vector2 = canvas.call("local_position_for_selected_info_action_button", action_index) if canvas.has_method("local_position_for_selected_info_action_button") else _board_to_canvas_local(canvas, _rect(action.get("button_rect", {})).get_center())
	if local_position.x < 0.0:
		result["route_errors"].append("selected action has no production hit position")
		return result
	await _push_click(app.get_viewport(), canvas.get_global_transform_with_canvas() * local_position)
	await _settle(8)
	result["ok"] = true
	result["visible_message"] = _observable_visible_message(app)
	return result


func _observable_visible_message(app: Control) -> String:
	var snapshot := Fidelity.observable_host_snapshot(app)
	var message := _dict(snapshot.get("message", {}))
	if bool(message.get("visible", false)) and not str(message.get("text", "")).strip_edges().is_empty():
		return _bounded_text(message.get("text", ""))
	for channel in ["talk", "feedback", "consequence", "event_popup"]:
		var visible := _dict(snapshot.get(channel, {}))
		for key in ["message", "summary", "body", "text", "outcome_message"]:
			if bool(visible.get("visible", true)) and not str(visible.get(key, "")).strip_edges().is_empty():
				return _bounded_text(visible.get(key, ""))
	return ""


func _first_visible_room_object_with_prefix(app: Control, prefix: String) -> String:
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible:
		return ""
	for value in _array(_dict(canvas.call("current_view_snapshot")).get("objects", [])):
		var object_id := _object_id(_dict(value))
		if object_id.begins_with(prefix):
			return object_id
	return ""


func _activate_first_ordinary_room_action(app: Control) -> Dictionary:
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible:
		return {"ok": false}
	var objects := _array(_dict(canvas.call("current_view_snapshot")).get("objects", []))
	# Favor cadence must not spend the route's travel bankroll merely because a
	# shop item happens to render first. Prefer ordinary narrative/room actions;
	# a purchase remains the last visible fallback.
	for preferred_prefix in ["event:", "scenario::", "home_sleep:", "service:", "game:", "item:"]:
		for value in objects:
			var object_id := _object_id(_dict(value))
			if object_id.is_empty() or not object_id.begins_with(preferred_prefix) \
					or object_id == "lender:the_crew" or object_id.begins_with("travel:") or object_id.begins_with("delivery:"):
				continue
			var local_failures: Array = []
			var focused := Fidelity.push_exact_canvas_mouse_click(app.get_viewport(), canvas, object_id, local_failures, "fix06_28 favor cadence action")
			await _settle(3)
			if not bool(focused.get("ok", false)):
				continue
			var panel := _dict(_dict(canvas.call("current_view_snapshot")).get("selected_info", {}))
			if not _array(panel.get("actions", [])).is_empty():
				return await _activate_exact_room_action(app, object_id, 0)
	return {"ok": false}


func _open_map_and_visible_delivery_target(app: Control) -> String:
	# Picking up the package uses the production item-found toast. It owns input
	# for its fixed presentation window, so a player must wait for it to clear
	# before the room's Travel target can receive the next click.
	await _resolve_visible_blocking_dialogue(app)
	var canvas := app.get("environment_canvas") as Control
	var local_failures: Array = []
	var opened := Fidelity.push_exact_canvas_mouse_click(app.get_viewport(), canvas, "travel:leave", local_failures, "fix06_28 delivery map", true)
	await _settle(8)
	await create_timer(0.3).timeout
	if not bool(opened.get("ok", false)):
		return ""
	var map := _dict(_dict(app.call("current_screen_snapshot")).get("world_map", {}))
	for value in _array(map.get("nodes", [])):
		var node := _dict(value)
		if bool(node.get("delivery_target", false)) and str(node.get("delivery_target_status", "pending")) != "delivered":
			return str(node.get("id", ""))
	await _close_visible_world_map(app)
	return ""


func _confirm_open_map_target(app: Control, target_id: String) -> bool:
	# The map's opening animation owns pointer routing for its first few frames.
	# A human cannot click the destination before it is visibly settled.
	await create_timer(0.2).timeout
	var node_button := _find_world_map_node_button(app, target_id)
	if node_button == null:
		return false
	await _push_click(app.get_viewport(), node_button.get_global_rect().get_center())
	await _settle(4)
	await create_timer(0.2).timeout
	var confirm := app.get("world_map_confirm_button") as Button
	if confirm == null or not confirm.is_visible_in_tree() or confirm.disabled:
		return false
	await _push_click(app.get_viewport(), confirm.get_global_rect().get_center())
	await _settle(24)
	var screen := _dict(app.call("current_screen_snapshot"))
	return not bool(screen.get("world_map_overlay_visible", false)) \
			and str(_dict(screen.get("world_map", {})).get("current_node_id", "")) == target_id


func _close_visible_world_map(app: Control) -> bool:
	var overlay := app.get("world_map_overlay") as Control
	var close_button := _find_button_with_text(overlay, "Close")
	if close_button == null:
		return false
	await _push_click(app.get_viewport(), close_button.get_global_rect().get_center())
	await _settle(5)
	return not bool(_dict(app.call("current_screen_snapshot")).get("world_map_overlay_visible", false))


func _verify_depart_arrive_revisit(app: Control, seed: String, seed_record: Dictionary) -> Dictionary:
	var travel := {"departed": false, "arrived": false, "revisited": false, "rooms": [], "errors": []}
	var start_node := ""
	for leg in range(2):
		var canvas := app.get("environment_canvas") as Control
		if canvas == null or not canvas.visible:
			travel["errors"].append("room canvas unavailable on leg %d" % leg)
			break
		await _clear_room_focus_by_pointer(app, canvas)
		var local_failures: Array = []
		var departure := Fidelity.push_exact_canvas_mouse_click(app.get_viewport(), canvas, "travel:leave", local_failures, "fix06_28 %s travel leg %d" % [seed, leg], true)
		await _settle(8)
		await create_timer(0.3).timeout
		var screen := _dict(app.call("current_screen_snapshot"))
		if not bool(departure.get("ok", false)) or not bool(screen.get("world_map_overlay_visible", false)):
			travel["errors"].append("exact travel:leave double-click did not open map on leg %d: %s" % [leg, JSON.stringify(local_failures)])
			break
		travel["departed"] = true
		var map := _dict(screen.get("world_map", {}))
		var current_node := str(map.get("current_node_id", ""))
		if leg == 0:
			start_node = current_node
		var enabled_ids := _array(map.get("travel_enabled_node_ids", []))
		var target_id := start_node if leg == 1 and enabled_ids.has(start_node) else ""
		if target_id.is_empty():
			for id_value in enabled_ids:
				var candidate := str(id_value)
				if not candidate.is_empty() and candidate != current_node:
					target_id = candidate
					break
		if target_id.is_empty():
			travel["errors"].append("world map had no enabled exact node on leg %d" % leg)
			break
		var node_button := _find_world_map_node_button(app, target_id)
		if node_button == null:
			travel["errors"].append("world map did not expose pointer button for exact node %s" % target_id)
			break
		await _push_click(app.get_viewport(), node_button.get_global_rect().get_center())
		await _settle(4)
		var confirm := app.get("world_map_confirm_button") as Button
		if confirm == null or not confirm.is_visible_in_tree() or confirm.disabled:
			travel["errors"].append("exact node %s did not enable visible travel confirmation" % target_id)
			break
		await _push_click(app.get_viewport(), confirm.get_global_rect().get_center())
		await _settle(24)
		await create_timer(0.4).timeout
		var after_screen := _dict(app.call("current_screen_snapshot"))
		var arrived_canvas := app.get("environment_canvas") as Control
		if bool(after_screen.get("world_map_overlay_visible", false)) or arrived_canvas == null or not arrived_canvas.visible:
			travel["errors"].append("confirmed exact node %s but no production room arrived" % target_id)
			break
		travel["arrived"] = true
		travel["rooms"].append(target_id)
		await _resolve_visible_blocking_dialogue(app)
		arrived_canvas = app.get("environment_canvas") as Control
		if arrived_canvas == null or not arrived_canvas.visible:
			travel["errors"].append("blocking dialogue resolution did not restore room %s" % target_id)
			break
		var arrived_objects := _array(arrived_canvas.call("current_view_snapshot").get("objects", [])).duplicate(true)
		_verify_single_environment_plane(arrived_canvas, "%s travel%d" % [seed, leg])
		for value in arrived_objects:
			var data := _dict(value)
			if _object_id(data).is_empty() or not bool(data.get("visible", true)):
				continue
			var object_record := await _verify_selection(app, arrived_canvas, data, "%s travel%d" % [seed, leg])
			object_record["travel_leg"] = leg
			object_record["node_id"] = target_id
			seed_record["room_objects"].append(object_record)
			if leg == 0:
				var arrived_actions := _array(object_record.get("actions", []))
				for action_index in range(arrived_actions.size()):
					var action_record := await _verify_action_isolated(seed, _object_id(data), action_index, target_id)
					action_record["travel_leg"] = leg
					action_record["node_id"] = target_id
					seed_record["actions"].append(action_record)
		if leg == 1 and target_id == start_node:
			travel["revisited"] = true
	if not bool(travel.get("revisited", false)):
		_fail("%s did not complete exact pointer depart/arrive/revisit: %s" % [seed, JSON.stringify(travel.get("errors", []))])
	return travel


func _verify_save_continue(app: Control, seed: String) -> Dictionary:
	var result := {"saved": false, "main_menu": false, "continued": false, "revisited_same_node": false, "errors": []}
	var before_screen := _dict(app.call("current_screen_snapshot"))
	var before_node := str(_dict(before_screen.get("world_map", {})).get("current_node_id", ""))
	var menu := app.get("top_menu_button") as Button
	if menu == null or not menu.is_visible_in_tree() or menu.disabled:
		result["errors"].append("visible run menu button unavailable")
		_fail("%s save/Continue could not open the visible run menu." % seed)
		return result
	await _push_click(app.get_viewport(), menu.get_global_rect().get_center())
	await create_timer(0.35).timeout
	await _settle(3)
	var save := app.get("run_menu_save_button") as Button
	var main_menu := app.get("run_menu_main_menu_button") as Button
	if save != null and main_menu != null and (not save.is_visible_in_tree() or not main_menu.is_visible_in_tree()):
		await _push_click(app.get_viewport(), menu.get_global_rect().get_center())
		await create_timer(0.35).timeout
		await _settle(3)
	if save == null or not save.is_visible_in_tree() or save.disabled or main_menu == null or not main_menu.is_visible_in_tree():
		result["errors"].append("Save/Main Menu controls unavailable")
		_fail("%s save/Continue menu did not expose Save and Main Menu." % seed)
		return result
	await _push_click(app.get_viewport(), save.get_global_rect().get_center())
	await _settle(5)
	result["saved"] = true
	await _push_click(app.get_viewport(), main_menu.get_global_rect().get_center())
	await _settle(6)
	result["main_menu"] = str(_dict(app.call("current_screen_snapshot")).get("screen", "")) == "START"
	var continue_button := app.get("new_run_button") as Button
	if continue_button == null or not continue_button.is_visible_in_tree() or continue_button.disabled or continue_button.text != "CONTINUE":
		result["errors"].append("main menu did not expose CONTINUE")
		_fail("%s saved run did not expose visible CONTINUE." % seed)
		return result
	await _push_click(app.get_viewport(), continue_button.get_global_rect().get_center())
	await _settle(12)
	result["continued"] = str(_dict(app.call("current_screen_snapshot")).get("screen", "")) == "ENVIRONMENT"
	var after_node := str(_dict(_dict(app.call("current_screen_snapshot")).get("world_map", {})).get("current_node_id", ""))
	result["revisited_same_node"] = not before_node.is_empty() and before_node == after_node
	if not bool(result["continued"]) or not bool(result["revisited_same_node"]):
		_fail("%s visible save/Main Menu/Continue did not restore the same room." % seed)
	return result


func _find_world_map_node_button(node: Node, target_id: String) -> Button:
	if node is Button and node.is_visible_in_tree() and not (node as Button).disabled and str(node.get_meta("node_id", "")) == target_id:
		return node as Button
	for child in node.get_children():
		var found := _find_world_map_node_button(child, target_id)
		if found != null:
			return found
	return null


func _verify_selection(app: Control, canvas: Control, object_data: Dictionary, seed: String) -> Dictionary:
	var semantic_id := _object_id(object_data)
	var label := str(object_data.get("label", "")).strip_edges()
	# Some ordinary fixtures are drawn by their renderer family rather than an
	# authored texture key. The rendered object type is their icon authority.
	var icon := _first_visible_text(object_data, ["icon_key", "asset_path", "prop", "visual_key", "type"])
	var description := _first_visible_text(object_data, ["description", "short_description", "action_summary"])
	var interactive := bool(object_data.get("visible", true)) \
		and bool(object_data.get("enabled", true)) \
		and not bool(object_data.get("disabled", false)) \
		and bool(object_data.get("interactive", true))
	if not interactive:
		var passive_ok := not label.is_empty() and not icon.is_empty() and not description.is_empty()
		if not passive_ok:
			_fail("%s visible noninteractive object %s lacks icon, label, or description metadata." % [seed, semantic_id])
		return {
			"semantic_id": semantic_id,
			"type": str(object_data.get("type", "")),
			"label": label,
			"icon_authority": icon,
			"description": description,
			"panel_title": label,
			"panel_lines": [description],
			"actions": [],
			"input_class": "none_noninteractive",
			"visible_noninteractive": true,
			"passed": passive_ok,
		}
	await _clear_room_focus_by_pointer(app, canvas)
	var local_failures: Array = []
	var routed := Fidelity.push_exact_canvas_mouse_click(
		app.get_viewport(), canvas, semantic_id, local_failures,
		"fix06_28 %s room selection" % seed
	)
	await _settle()
	await create_timer(0.25).timeout
	var view: Dictionary = canvas.call("current_view_snapshot")
	var panel := _dict(view.get("selected_info", {}))
	var lines := _array(panel.get("lines", []))
	if description.is_empty() and not lines.is_empty():
		description = str(lines[0]).strip_edges()
	var ok := bool(routed.get("ok", false)) \
		and Fidelity.exact_selection_matches(app, semantic_id) \
		and bool(panel.get("visible", false)) \
		and str(panel.get("object_id", "")) == semantic_id \
		and not label.is_empty() and not icon.is_empty() \
		and (not description.is_empty() or not lines.is_empty()) \
		and not str(panel.get("title", "")).strip_edges().is_empty() \
		and not lines.is_empty()
	if not ok:
		_fail("%s exact object %s did not yield icon, label, description, and populated exact panel; helper=%s" % [seed, semantic_id, JSON.stringify(local_failures)])
	return {
		"semantic_id": semantic_id,
		"type": str(object_data.get("type", "")),
		"label": label,
		"icon_authority": icon,
		"description": description,
		"panel_title": str(panel.get("title", "")),
		"panel_lines": lines.duplicate(true),
		"actions": _array(panel.get("actions", [])).duplicate(true),
		"input_class": str(routed.get("input_class", "")),
		"passed": ok,
	}


func _verify_action_isolated(seed: String, semantic_id: String, action_index: int, travel_target_id: String = "") -> Dictionary:
	var action_record := {"semantic_id": semantic_id, "action_index": action_index, "node_id": travel_target_id, "passed": false}
	var app := await _start_app(seed)
	if app == null:
		_fail("%s/%s action %d could not restart ordinary production host." % [seed, semantic_id, action_index])
		return action_record
	if not travel_target_id.is_empty() and not await _travel_one_exact_leg(app, seed, travel_target_id):
		_fail("%s/%s action %d could not reach exact ordinary node %s." % [seed, semantic_id, action_index, travel_target_id])
		await _dispose_app(app)
		return action_record
	await _resolve_visible_blocking_dialogue(app)
	if str(action_record.get("node_id", "")).is_empty():
		action_record["node_id"] = _current_visible_node_id(app)
	var canvas := app.get("environment_canvas") as Control
	var local_failures: Array = []
	var routed := Fidelity.push_exact_canvas_mouse_click(app.get_viewport(), canvas, semantic_id, local_failures, "fix06_28 %s action focus" % seed)
	await _settle()
	await create_timer(0.25).timeout
	var focus_view := _dict(canvas.call("current_view_snapshot")) if canvas != null and canvas.has_method("current_view_snapshot") else {}
	var visible_object_ids: Array = []
	var visible_object_layouts: Array = []
	var target_object: Dictionary = {}
	for value in _array(focus_view.get("objects", [])):
		var visible_object := _dict(value)
		var visible_id := _object_id(visible_object)
		if not visible_id.is_empty():
			visible_object_ids.append(visible_id)
			visible_object_layouts.append({
				"id": visible_id,
				"position": visible_object.get("position", Vector2.ZERO),
				"size": visible_object.get("size", Vector2.ZERO),
				"scenario_layout_resolved": bool(visible_object.get("scenario_layout_resolved", false)),
			})
			if visible_id == semantic_id:
				target_object = visible_object.duplicate(true)
	action_record["focus_probe"] = {
		"current_node_id": _current_visible_node_id(app),
		"routed_ok": bool(routed.get("ok", false)),
		"routed_stage": str(routed.get("stage", "")),
		"route_errors": local_failures.duplicate(true),
		"visible_object_ids": visible_object_ids,
		"visible_object_layouts": visible_object_layouts,
		"target_object": target_object,
		"object_layout": _dict(focus_view.get("object_layout", {})),
		"scenario_layout_audit": _dict(focus_view.get("scenario_layout_audit", {})),
		"canvas_selected_object_id": str(focus_view.get("selected_object_id", "")),
		"host_selected_object_id": str(_dict(app.call("current_spatial_interaction_snapshot")).get("selected_object_id", "")),
		"screen": str(_dict(app.call("current_screen_snapshot")).get("screen", "")),
	}
	if not bool(routed.get("ok", false)) or not Fidelity.exact_selection_matches(app, semantic_id):
		_fail("%s/%s action %d could not focus exact rendered target." % [seed, semantic_id, action_index])
		await _dispose_app(app)
		return action_record
	var panel := _dict(canvas.call("current_view_snapshot").get("selected_info", {}))
	var actions := _array(panel.get("actions", []))
	if action_index >= actions.size():
		_fail("%s/%s lost exact action %d after deterministic restart." % [seed, semantic_id, action_index])
		await _dispose_app(app)
		return action_record
	var action := _dict(actions[action_index])
	var button_rect := _rect(action.get("button_rect", {}))
	if not button_rect.has_area():
		_fail("%s/%s action %d has no rendered hit rectangle." % [seed, semantic_id, action_index])
		await _dispose_app(app)
		return action_record
	var local_action_position := Vector2(-1.0, -1.0)
	if canvas.has_method("local_position_for_selected_info_action_button"):
		local_action_position = canvas.call("local_position_for_selected_info_action_button", action_index)
	else:
		local_action_position = _board_to_canvas_local(canvas, button_rect.get_center())
	if local_action_position.x < 0.0:
		_fail("%s/%s action %d has no production local hit position." % [seed, semantic_id, action_index])
		await _dispose_app(app)
		return action_record
	var before := Fidelity.observable_host_snapshot(app)
	await _push_click(app.get_viewport(), canvas.get_global_transform_with_canvas() * local_action_position)
	var evidence := await _await_observable_action_evidence(app, before, semantic_id)
	var ok := bool(evidence.get("ok", false))
	if not ok:
		_fail("%s/%s action %d (%s) accepted pointer input without an admissible visible consequence." % [seed, semantic_id, action_index, str(action.get("label", ""))])
	action_record.merge({
		"label": str(action.get("label", "")),
		"emit_object_id": str(action.get("emit_object_id", "")),
		"input_class": "InputEventMouseButton",
		"visible_evidence": evidence,
		"passed": ok,
	}, true)
	await _dispose_app(app)
	return action_record


func _verify_single_environment_plane(canvas: Control, context: String) -> void:
	if canvas == null or not canvas.has_method("current_view_snapshot"):
		_fail("%s has no environment canvas for single-plane verification." % context)
		return
	var layout := _dict(_dict(canvas.call("current_view_snapshot")).get("object_layout", {}))
	var overlap_count := maxi(0, int(layout.get("overlap_count", 0)))
	if overlap_count > 0:
		_fail("%s rendered %d overlapping room objects on the environment plane: %s" % [context, overlap_count, JSON.stringify(layout.get("overlaps", []))])


func _await_observable_action_evidence(app: Control, before: Dictionary, semantic_id: String) -> Dictionary:
	var evidence := Fidelity.observable_consequence_evidence(before, Fidelity.observable_host_snapshot(app), semantic_id)
	# Scenario actions commit synchronously but intentionally publish their room
	# rebuild and acknowledgement on deferred UI boundaries. Observe those real
	# boundaries instead of sampling an arbitrary early frame.
	for _frame in range(120):
		if bool(evidence.get("ok", false)):
			return evidence
		await process_frame
		evidence = Fidelity.observable_consequence_evidence(before, Fidelity.observable_host_snapshot(app), semantic_id)
	return evidence


func _travel_one_exact_leg(app: Control, seed: String, target_id: String) -> bool:
	var canvas := app.get("environment_canvas") as Control
	if canvas == null or not canvas.visible:
		return false
	await _clear_room_focus_by_pointer(app, canvas)
	var local_failures: Array = []
	var departure := Fidelity.push_exact_canvas_mouse_click(app.get_viewport(), canvas, "travel:leave", local_failures, "fix06_28 %s isolated travel" % seed, true)
	await _settle(8)
	await create_timer(0.3).timeout
	if not bool(departure.get("ok", false)) or not bool(_dict(app.call("current_screen_snapshot")).get("world_map_overlay_visible", false)):
		return false
	# Map cards finish their entrance layout after the overlay becomes visible.
	# Resolve and click the live target rect only after that layout settles, then
	# require the public selected-node snapshot to name the exact requested node.
	await create_timer(0.8).timeout
	var selected_exact := false
	for _selection_attempt in range(2):
		var node_button := _find_world_map_node_button(app, target_id)
		if node_button == null:
			return false
		await _push_click(app.get_viewport(), node_button.get_global_rect().get_center())
		await _settle(4)
		if str(_dict(app.call("current_screen_snapshot")).get("selected_world_map_node_id", "")) == target_id:
			selected_exact = true
			break
		await create_timer(0.5).timeout
	if not selected_exact:
		return false
	# The detail sheet reflows after selection. Wait for its Travel button only
	# after that visible motion completes so the click cannot land on its old rect.
	await create_timer(0.8).timeout
	var confirm := app.get("world_map_confirm_button") as Button
	if confirm == null or not confirm.is_visible_in_tree() or confirm.disabled:
		return false
	await _push_click(app.get_viewport(), confirm.get_global_rect().get_center())
	await _settle(24)
	await create_timer(0.4).timeout
	var after := _dict(app.call("current_screen_snapshot"))
	return not bool(after.get("world_map_overlay_visible", false)) and app.get("environment_canvas") != null


func _travel_until_exact_node(app: Control, seed: String, target_id: String, preserve_event_id: String = "") -> bool:
	var visited: Dictionary = {}
	for _hop in range(12):
		if not preserve_event_id.is_empty() and (str(_visible_event_popup_snapshot(app).get("event_id", "")) == preserve_event_id \
				or str(_visible_talk_snapshot(app).get("event_id", "")) == preserve_event_id):
			return true
		var map := _dict(_dict(app.call("current_screen_snapshot")).get("world_map", {}))
		var current_id := str(map.get("current_node_id", ""))
		if current_id == target_id:
			return true
		visited[current_id] = true
		var enabled_ids := _array(map.get("travel_enabled_node_ids", []))
		var next_id := target_id if enabled_ids.has(target_id) else ""
		if next_id.is_empty():
			for id_value in enabled_ids:
				var candidate := str(id_value)
				if not candidate.is_empty() and not visited.has(candidate):
					next_id = candidate
					break
		if next_id.is_empty() and not enabled_ids.is_empty():
			next_id = str(enabled_ids[0])
		if next_id.is_empty() or not await _travel_one_exact_leg(app, seed, next_id):
			return false
		await _resolve_visible_blocking_dialogue(app, preserve_event_id)
	return _current_visible_node_id(app) == target_id


func _start_app(seed: String) -> Control:
	var app := MainScene.instantiate() as Control
	app.set("continuous_environment_clock_enabled", false)
	var slot_id := "fix06_28_working_order_%s" % seed.to_lower().replace("-", "_")
	app.set("autosave_slot_id", slot_id)
	var save_service := SaveServiceScript.new()
	if save_service.clear_run(slot_id) != OK:
		_fail("%s could not clear its isolated save slot." % seed)
	root.add_child(app)
	await _settle(5)
	var run_config_button := app.get("run_config_button") as Button
	if run_config_button == null or not run_config_button.is_visible_in_tree() or run_config_button.disabled:
		_fail("%s start menu did not expose visible Run Setup." % seed)
		await _dispose_app(app)
		return null
	await _push_click(app.get_viewport(), run_config_button.get_global_rect().get_center())
	await _settle(4)
	var seed_input := app.get("seed_input") as LineEdit
	if seed_input == null or not seed_input.is_visible_in_tree():
		_fail("%s Run Setup did not expose its visible seed field." % seed)
		await _dispose_app(app)
		return null
	await _replace_line_edit_text_by_input(app.get_viewport(), seed_input, seed)
	var start_button := app.get("run_config_start_button") as Button
	if start_button == null or not start_button.is_visible_in_tree() or start_button.disabled:
		_fail("%s Run Setup did not expose enabled START NEW RUN." % seed)
		await _dispose_app(app)
		return null
	await _push_click(app.get_viewport(), start_button.get_global_rect().get_center())
	await _settle(10)
	if str(_dict(app.call("current_screen_snapshot")).get("screen", "")) != "ENVIRONMENT":
		_fail("%s visible START NEW RUN did not enter the production room." % seed)
		await _dispose_app(app)
		return null
	return app


func _dispose_app(app: Control) -> void:
	if app != null and is_instance_valid(app):
		app.queue_free()
	await _settle(3)


func _push_click(viewport: Viewport, global_position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = global_position
	motion.global_position = global_position
	viewport.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = global_position
	press.global_position = global_position
	viewport.push_input(press, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.button_mask = 0
	release.position = global_position
	release.global_position = global_position
	viewport.push_input(release, true)
	await process_frame


func _push_drag(viewport: Viewport, start_position: Vector2, end_position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = start_position
	motion.global_position = start_position
	viewport.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start_position
	press.global_position = start_position
	viewport.push_input(press, true)
	await process_frame
	for step in range(1, 5):
		var drag := InputEventMouseMotion.new()
		drag.position = start_position.lerp(end_position, float(step) / 4.0)
		drag.global_position = drag.position
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		viewport.push_input(drag, true)
		await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = end_position
	release.global_position = end_position
	viewport.push_input(release, true)
	await process_frame


func _replace_line_edit_text_by_input(viewport: Viewport, input: LineEdit, text: String) -> void:
	await _push_click(viewport, input.get_global_rect().get_center())
	var select_all := InputEventKey.new()
	select_all.pressed = true
	select_all.ctrl_pressed = true
	select_all.keycode = KEY_A
	viewport.push_input(select_all, true)
	await process_frame
	select_all = select_all.duplicate()
	select_all.pressed = false
	viewport.push_input(select_all, true)
	var erase := InputEventKey.new()
	erase.pressed = true
	erase.keycode = KEY_BACKSPACE
	viewport.push_input(erase, true)
	await process_frame
	erase = erase.duplicate()
	erase.pressed = false
	viewport.push_input(erase, true)
	for character in text:
		var key := InputEventKey.new()
		key.pressed = true
		key.unicode = character.unicode_at(0)
		viewport.push_input(key, true)
		await process_frame
		key = key.duplicate()
		key.pressed = false
		viewport.push_input(key, true)
	_require(input.text == text, "Visible seed field received '%s' instead of '%s' through keyboard input." % [input.text, text])


func _clear_room_focus_by_pointer(app: Control, canvas: Control) -> void:
	if canvas == null or not canvas.has_method("object_id_at_local_position"):
		return
	for local_position in [Vector2(8.0, 8.0), Vector2(canvas.size.x - 8.0, 8.0), Vector2(8.0, canvas.size.y - 8.0)]:
		if str(canvas.call("object_id_at_local_position", local_position)).is_empty():
			await _push_click(app.get_viewport(), canvas.get_global_rect().position + local_position)
			await _settle(4)
			await create_timer(0.2).timeout
			return


func _first_visible_text(source: Dictionary, keys: Array) -> String:
	for key_value in keys:
		var value := str(source.get(str(key_value), "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _settle(frames: int = 4) -> void:
	for _frame in range(frames):
		await process_frame


func _finish() -> void:
	report["failures"] = failures.duplicate()
	report["passed"] = failures.is_empty()
	var report_path := _report_path()
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	if failures.is_empty():
		print("FIX06_28_WORKING_ORDER PASS seeds=%d" % SEEDS.size())
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("FIX06_28_WORKING_ORDER FAIL failures=%d report=%s" % [failures.size(), report_path])
	quit(1)


func _apply_full_acceptance_bar() -> void:
	var surface_families: Array = []
	var punchline_layers: Array = []
	var crew_milestones: Array = []
	var discovered_action_identities: Dictionary = {}
	var exercised_action_identities: Dictionary = {}
	for seed_value in _array(report.get("seeds", [])):
		var seed_record := _dict(seed_value)
		for family in _array(seed_record.get("surface_families_resolved", [])):
			if not surface_families.has(str(family)):
				surface_families.append(str(family))
		for layer in _array(seed_record.get("punchline_layers", [])):
			if not punchline_layers.has(str(layer)):
				punchline_layers.append(str(layer))
		for milestone in _array(seed_record.get("crew_milestones", [])):
			if not crew_milestones.has(str(milestone)):
				crew_milestones.append(str(milestone))
		var seed_id := str(seed_record.get("seed", ""))
		for action_value in _array(seed_record.get("actions", [])):
			var action_record := _dict(action_value)
			var action_key := _action_identity(seed_id, str(action_record.get("node_id", "")), str(action_record.get("semantic_id", "")), int(action_record.get("action_index", -1)))
			if not action_key.is_empty():
				exercised_action_identities[action_key] = true
		for object_value in _array(seed_record.get("room_objects", [])):
			var object_record := _dict(object_value)
			for action_index in range(_array(object_record.get("actions", [])).size()):
				var action_key := _action_identity(seed_id, str(object_record.get("node_id", "")), str(object_record.get("semantic_id", "")), action_index)
				if not action_key.is_empty():
					discovered_action_identities[action_key] = true
	var missing_action_identities: Array = []
	for action_key_value in discovered_action_identities.keys():
		var action_key := str(action_key_value)
		if not exercised_action_identities.has(action_key):
			missing_action_identities.append(action_key)
	missing_action_identities.sort()
	var discovered_action_count := discovered_action_identities.size()
	var exercised_action_count := exercised_action_identities.size()
	var missing_surfaces := _missing_strings(REQUIRED_SURFACE_FAMILIES, surface_families)
	var missing_layers := _missing_strings(REQUIRED_PUNCHLINE_LAYERS, punchline_layers)
	var missing_crew := _missing_strings(REQUIRED_CREW_MILESTONES, crew_milestones)
	report["full_acceptance"] = {
		"passed": missing_surfaces.is_empty() and missing_layers.is_empty() and missing_crew.is_empty() and missing_action_identities.is_empty(),
		"surface_families_resolved": surface_families,
		"missing_surface_families": missing_surfaces,
		"punchline_layers": punchline_layers,
		"missing_punchline_layers": missing_layers,
		"crew_milestones": crew_milestones,
		"missing_crew_milestones": missing_crew,
		"discovered_actions": discovered_action_count,
		"exercised_actions": exercised_action_count,
		"missing_action_identities": missing_action_identities,
	}
	if not missing_action_identities.is_empty():
		_fail("Production routes left %d of %d unique visited-room actions unexercised: %s" % [missing_action_identities.size(), discovered_action_count, JSON.stringify(missing_action_identities)])
	if not missing_surfaces.is_empty():
		_fail("Production route did not play required surface families to resolution: %s" % JSON.stringify(missing_surfaces))
	if not missing_layers.is_empty():
		_fail("Production route did not verify Punchline L1/L2/L3: %s" % JSON.stringify(missing_layers))
	if not missing_crew.is_empty():
		_fail("Production route did not verify Crew favors/jobs/deliveries: %s" % JSON.stringify(missing_crew))


func _missing_strings(required: Array, actual: Array) -> Array:
	var missing: Array = []
	for value in required:
		if not actual.has(value):
			missing.append(value)
	return missing


func _action_identity(seed: String, node_id: String, semantic_id: String, action_index: int) -> String:
	if seed.is_empty() or node_id.is_empty() or semantic_id.is_empty() or action_index < 0:
		return ""
	return "%s|%s|%s|%d" % [seed, node_id, semantic_id, action_index]


func _current_visible_node_id(app: Control) -> String:
	return str(_dict(_dict(app.call("current_screen_snapshot")).get("world_map", {})).get("current_node_id", "")).strip_edges()


func _report_path() -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		if args[index] == "--report" and index + 1 < args.size():
			return str(args[index + 1])
		if str(args[index]).begins_with("--report="):
			return str(args[index]).trim_prefix("--report=")
	return "res://.tmp/fix06_28_working_order.json"


func _records_passed(records: Array) -> bool:
	for value in records:
		if not bool(_dict(value).get("passed", false)):
			return false
	return true


func _fail(message: String) -> void:
	failures.append(message)


func _require(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _object_id(object_data: Dictionary) -> String:
	return str(object_data.get("id", object_data.get("object_id", ""))).strip_edges()


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []


func _rect(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value
	var data := _dict(value)
	return Rect2(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("w", data.get("width", 0.0))), float(data.get("h", data.get("height", 0.0))))


func _board_to_canvas_local(canvas: Control, board_position: Vector2) -> Vector2:
	var view := _dict(canvas.call("current_view_snapshot"))
	var board_rect := _rect(view.get("board_rect", {}))
	if not board_rect.has_area():
		return Vector2(-1.0, -1.0)
	return board_rect.position + board_position * (board_rect.size.x / 960.0)
