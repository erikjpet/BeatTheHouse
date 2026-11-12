extends "res://scripts/tests/standard_travel_integration_check.gd"

# Production-host scope regression. Only actual Travel menu confirmation may
# start a world cutscene. Fixtures never edit a route, graph edge, cost or mode.
# Interior fixtures use production generation plus explicitly progressed QA
# credentials, not a user's save. Internal movement remains unanimated.
const CASES := ["menu_selection", "menu_map", "menu_leave_object", "direct_world", "stale_travel_screen", "flag_string", "flag_integer", "forced_world", "offered_ride",
	"motel_exit", "motel_enter", "grand_cage", "grand_high_limit", "punchline_layer", "punchline_event", "meta_map"]
var scope_rows: Array = []
var offered_ride: Dictionary = {}
const Offers := preload("res://scripts/core/character_offer_model.gd")

func _run() -> void:
	_test_nonmenu_reload_comparison()
	var selected := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): selected = argument.trim_prefix("--case=")
	if not selected.is_empty() and selected not in CASES:
		push_error("Unknown --case=" + selected)
		quit(1)
		return
	app = MainScene.instantiate()
	app.continuous_environment_clock_enabled = false
	root.add_child(app)
	app._build_travel_cinematic_overlay()
	app.travel_cinematic_overlay.completed.connect(_on_presentation_completed)
	for case_id in CASES:
		if not selected.is_empty() and case_id != selected: continue
		await _check_case(case_id)
	var report := {"suite":"travel_menu_scope", "platform":OS.get_name(), "actual_web":OS.has_feature("web"),
		"checks":checks, "passed":failures.is_empty(), "failures":failures, "cases":scope_rows,
		"scope":"Only Travel menu confirmation animates; local/internal/meta/offered/forced transfers do not opt in."}
	var evidence := OS.get_environment("BTH_QA_EVIDENCE_DIR")
	if evidence.replace("\\", "/").begins_with("E:/CodexQA/BTH/runs/"):
		var file := FileAccess.open(evidence.path_join("travel_menu_scope.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print(JSON.stringify(report))
	app._cancel_travel_presentation()
	app.pending_autosave = false
	app.save_service.wait_for_async_save()
	app.free()
	quit(0 if failures.is_empty() else 1)

func _check_case(case_id: String) -> void:
	var menu := case_id.begins_with("menu_")
	var outcomes: Dictionary = {}
	var row := {"case":case_id, "expected_animation":menu, "flows":[]}
	for flow in (["watch", "skip", "reduced", "missing"] if menu else ["watch"]):
		if not _setup_scope_case(case_id):
			_expect(false, case_id + ": production fixture prepared")
			break
		app.user_settings.reduce_motion = flow == "reduced"
		app.travel_cinematic_overlay.force_missing_art_for_test = flow == "missing"
		app.travel_transition_force_web_runtime_for_test = false
		var before := _state(app.run_state)
		var origin: Dictionary = app.run_state.current_environment.duplicate(true)
		var accepted := _perform_scope_action(case_id)
		_expect(accepted, case_id + "/" + flow + ": production entry action succeeds")
		for frame in range(3): await process_frame
		var settled := _state(app.run_state)
		var prefix: String = case_id + "/" + flow + ": "
		var receipt: Dictionary = app.run_state.travel_journey_receipt.duplicate(true)
		if menu:
			_expect(app.travel_presentation_active and not app.travel_transition_active, prefix + "confirmed Travel menu owns presentation")
			_expect(not receipt.is_empty() and int(receipt.get("schema_version", 0)) in [1, 2], prefix + "only supported world receipt schema")
			_expect(str(receipt.get("origin_environment_id", "")) == str(origin.get("id", "")) and receipt.get("effective_destination_environment_id") == app.run_state.current_environment.get("id"), prefix + "receipt names installed origin and destination")
			for cached in app._travel_choice_view_list():
				_expect(not cached.has("presentation_from_travel_menu"), prefix + "menu opt-in never leaks to cached choices")
			if app.travel_presentation_active:
				var overlay: Control = app.travel_cinematic_overlay
				var snapshot: Dictionary = app.current_travel_presentation_snapshot()
				_expect(bool(snapshot.get("static", false)) == (flow in ["reduced", "missing"]), prefix + "accessibility/missing-art safely select static receipt")
				_expect(app._modal_contract_blocks_player_input() and app._simulation_progression_paused(), prefix + "gameplay pauses behind Travel menu cutscene")
				var completed_before := completion_count
				_expect(not app.confirm_selected_travel(true) and _state(app.run_state) == settled, prefix + "duplicate menu confirmation cannot settle twice")
				if flow == "watch":
					for seconds in [1.0, 2.1, 3.8, 5.3, 6.4, 7.6, 8.0]:
						overlay.advance_presentation(seconds - float(overlay.elapsed))
						_expect(_state(app.run_state) == settled, prefix + "watch sample leaves gameplay unchanged")
				else:
					overlay.skip_to_receipt()
				_expect(overlay.phase == "receipt" and completion_count == completed_before, prefix + "completion does not reenter the animation callback")
				if flow == "skip":
					await _check_menu_reload(prefix, settled)
					overlay = app.travel_cinematic_overlay
					settled = _state(app.run_state)
				await process_frame
				_expect(app.travel_presentation_active == (flow != "watch"), prefix + "natural finish enters automatically; static/reloaded receipts wait")
				overlay.acknowledge()
				overlay.acknowledge()
				_expect(not app.travel_presentation_active and completion_count == completed_before + 1, prefix + "Continue releases exactly once")
				_expect(_same_saved_values(_state(app.run_state), settled), prefix + "Continue never charges or rerolls")
		else:
			_expect(not app.travel_presentation_active and not app.travel_transition_active, prefix + "nonmenu/internal travel has no cinematic owner")
			_expect(not bool(receipt.get("receipt_pending", false)), prefix + "nonmenu travel leaves no pending cinematic to replay on Continue")
			if not receipt.is_empty():
				app.autosave_slot_id = "menu_scope_nonmenu"
				# Compare the exact persisted representation. Pending Grand host
				# dialogue includes layout floats rounded by the production JSON codec.
				var persisted_settled: Dictionary = JSON.parse_string(JSON.stringify(settled))
				_expect(app.save_service.save_run(app.run_state, app.autosave_slot_id) == OK, prefix + "nonmenu settled journey saves")
				_expect(app.load_foundation_run(), prefix + "normal Continue loads nonmenu journey")
				_check_exact_settlement(_state(app.run_state), settled, prefix)
				if not _same_nonmenu_reload_values(_state(app.run_state), persisted_settled):
					print(JSON.stringify({"scope_reload_difference":case_id, "before":persisted_settled, "after":_state(app.run_state)}))
				_expect(not app.travel_presentation_active and _same_nonmenu_reload_values(_state(app.run_state), persisted_settled), prefix + "nonmenu reload never creates a cinematic or resettles travel")
			if case_id in ["motel_exit", "motel_enter", "grand_cage", "grand_high_limit", "punchline_layer", "punchline_event", "meta_map"]:
				_expect(receipt.is_empty(), prefix + "internal movement creates no world receipt")
		if not outcomes.has("state"):
			outcomes["state"] = _state(app.run_state)
		else:
			_expect(_same_saved_values(outcomes.state, _state(app.run_state)), prefix + "watch/skip/reduced/missing settle the same gameplay")
		row.flows.append({"flow":flow, "accepted":accepted, "origin":str(origin.get("archetype_id", "")),
			"destination":str(app.run_state.current_environment.get("archetype_id", "")),
			"layer":str(app.run_state.current_environment.get("current_layer_id", "")),
			"cash_delta":int(_state(app.run_state).bankroll)-int(before.bankroll), "clock_delta":int(_state(app.run_state).clock)-int(before.clock),
			"travel_count_delta":int(_state(app.run_state).count)-int(before.count), "receipt_schema":int(receipt.get("schema_version", 0))})
		app._cancel_travel_presentation()
		app.user_settings.reduce_motion = false
		app.travel_cinematic_overlay.force_missing_art_for_test = false
	scope_rows.append(row)
	print(JSON.stringify({"case_complete":case_id, "checks":checks, "failures":failures.size()}))

func _setup_scope_case(case_id: String) -> bool:
	app._cancel_travel_presentation()
	if app.run_state != null: app._clear_input_guard_modal_state()
	app.pending_autosave = false
	app.save_service.wait_for_async_save()
	app.meta_session_active = false
	if case_id == "offered_ride": return _setup_offered_ride()
	if case_id == "forced_world": return _setup_forced_world()
	var home := "motel_room" if case_id.begins_with("motel_") else "back_alley"
	var seed_text := "STANDARD-TRAVEL-LOCAL-DOOR" if case_id.begins_with("motel_") else "STANDARD-TRAVEL-back_alley-0"
	if not app.start_foundation_run(seed_text, {"modifiers":{"home_archetype_id":home}}, false): return false
	app.continuous_environment_clock_enabled = false
	if case_id == "motel_enter":
		if not app.activate_interactable_object("travel:leave"): return false
	elif case_id.begins_with("grand_"):
		# Same production-generated progressed fixture used by Cage access checks.
		app.run_state.bankroll = 2000
		var generated: Dictionary = app.generator.travel_environment_result(app.run_state, "grand_casino", true)
		if not bool(generated.get("ok", false)): return false
		app.run_state.narrative_flags["grand_casino_high_limit_access"] = true
		app.run_state.narrative_flags["grand_casino_high_limit_access_method"] = "card"
		app._set_current_screen(app.SCREEN_ENVIRONMENT)
		app._refresh_run_action_service()
		app._refresh()
	elif case_id.begins_with("punchline_"):
		app.run_state.bankroll = 2000
		var generated: Dictionary = app.generator.travel_environment_result(app.run_state, "small_underground_casino", true)
		if not bool(generated.get("ok", false)): return false
		if case_id == "punchline_layer": app.run_state.discover_environment_layer("casino", "qa_progressed_fixture")
		app._set_current_screen(app.SCREEN_ENVIRONMENT)
		app._refresh_run_action_service()
		app._refresh()
	elif case_id == "meta_map":
		app.open_meta_home()
		app._hide_event_choice_popup()
		if not app.meta_session_active: return false
	return true

func _perform_scope_action(case_id: String) -> bool:
	match case_id:
		"menu_selection":
			return app.select_travel_option("corner_store") and app.confirm_selected_travel(true)
		"menu_map":
			return app.open_world_map() and app.select_world_map_node("corner_store") and bool(app.confirm_world_map_travel().get("ok", false))
		"menu_leave_object":
			return app.activate_interactable_object("travel:leave") and app.select_world_map_node("corner_store") and bool(app.confirm_world_map_travel().get("ok", false))
		"direct_world", "stale_travel_screen", "flag_string", "flag_integer":
			var choice: Dictionary = app._travel_choice("corner_store")
			if case_id == "stale_travel_screen": app._set_current_screen(app.SCREEN_TRAVEL)
			if case_id == "flag_string": choice["presentation_from_travel_menu"] = "true"
			if case_id == "flag_integer": choice["presentation_from_travel_menu"] = 1
			return bool(app._travel_to("corner_store", str(choice.get("label", "")), choice, true).get("ok", false))
		"offered_ride":
			if not app._review_character_offer(str(offered_ride.id)): return false
			return bool(app._resolve_character_offer_response(str(offered_ride.id), offered_ride.token, true).get("ok", false))
		"forced_world":
			var result: Dictionary = app._apply_forced_environment_travel("qa_health_inspector")
			return bool(result.get("ok", false)) and bool(result.get("applied", false))
		"motel_exit": return app.activate_interactable_object("travel:leave")
		"motel_enter":
			var card := VBoxContainer.new()
			root.add_child(card)
			app._add_context_travel_actions(card, "motel_room")
			var button := _button_named(card, "Enter Room")
			if button == null:
				card.free()
				return false
			button.pressed.emit()
			card.free()
			return str(app.run_state.current_environment.get("archetype_id", "")) == "motel_room"
		"grand_cage": return app._inspect_casino_fixture({"source_id":"cage"})
		"grand_high_limit": return app.select_travel_option("grand_casino_high_limit") and app.confirm_selected_travel(true)
		"punchline_layer": return app.activate_interactable_object("environment_layer:casino")
		"punchline_event": return app.activate_event_choice_action("side_door", "punchline_password")
		"meta_map":
			return app.open_world_map() and app.select_world_map_node(app._meta_pawn_location_id()) and bool(app.confirm_world_map_travel().get("ok", false))
	return false

func _button_named(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found := _button_named(child, label)
		if found != null: return found
	return null

func _setup_forced_world() -> bool:
	# Use current-main's supported inspector fixture: generated Bar and routes,
	# synthetic queued event, and the real offered finish_one response. Merely
	# setting an unowned closing counter is deliberately rejected by venue scope.
	if not app.start_foundation_run("RUN-20261025-440400-001", {}, false): return false
	app.continuous_environment_clock_enabled = false
	for choice in app._travel_choice_view_list():
		if str(choice.get("id", "")) == "bar" and bool(choice.get("enabled", false)):
			if not bool(app._travel_to("bar", "Roadside Bar", choice, true).get("ok", false)): return false
			break
	if app.run_state.current_world_node_id() != "bar": return false
	app.run_state.current_environment["turns"] = 1
	var context: Dictionary = app._event_action_trigger_context("event")
	context["environment_snapshot"] = app.run_state.current_environment.duplicate(true)
	if not app.run_state.enqueue_triggered_event("health_inspector", "event", context): return false
	var entry: Dictionary = app.run_state.begin_triggered_event_resolution(app.run_state.next_pending_triggered_event())
	if not app._show_triggered_event_popup(entry): return false
	var result: Dictionary = app.resolve_event_choice("health_inspector", "finish_one")
	return bool(result.get("ok", false)) and int(app.run_state.narrative_flags.get("health_inspector_closing_actions", 0)) == 1 \
		and str(app.run_state.narrative_flags.get("health_inspector_origin_environment_id", "")) == str(app.run_state.current_environment.get("id", ""))


func _setup_offered_ride() -> bool:
	# Search bounded ordinary generated worlds and the real deterministic offer
	# roll. Progressed wallet/credentials unlock Rafi; no route is fabricated.
	for index in range(64):
		if not app.start_foundation_run("MENU-SCOPE-RAFI-%02d" % index, {"modifiers":{"home_archetype_id":"apartment"}}, false): continue
		app.continuous_environment_clock_enabled = false
		app.run_state.bankroll = 2000
		app.run_state.narrative_flags["grand_casino_invite"] = true
		app.run_state.environment_history_archive_count = 4
		app.run_state.world_map = World.unlock_runtime_nodes(app.run_state.world_map, ["grand_casino"])
		var generated: Dictionary = app.generator.travel_environment_result(app.run_state, "bar", true)
		if not bool(generated.get("ok", false)): continue
		app._set_current_screen(app.SCREEN_ENVIRONMENT)
		app._refresh_run_action_service()
		app._refresh()
		var offer: Dictionary = Offers.view(app.run_state, app.library, "rafi_grand_casino_ride")
		print(JSON.stringify({"offer_fixture_seed":index, "offer_available":not offer.is_empty()}))
		if not offer.is_empty() and not app._character_offer_route_preview(offer).is_empty():
			offered_ride = offer
			return true
	return false

func _check_menu_reload(prefix: String, settled: Dictionary) -> void:
	app.autosave_slot_id = "menu_scope_pending"
	_expect(app.save_service.save_run(app.run_state, app.autosave_slot_id) == OK, prefix + "pending receipt saves through actual service")
	app._cancel_travel_presentation()
	_expect(app.load_foundation_run(), prefix + "normal Continue loads pending receipt")
	for frame in range(2): await process_frame
	_expect(app.travel_presentation_active and app.travel_cinematic_overlay.phase == "receipt", prefix + "pending reload presents static receipt rather than replaying travel")
	_check_exact_settlement(_state(app.run_state), settled, prefix)
	_expect(_same_saved_values(_state(app.run_state), settled), prefix + "reload preserves settled gameplay")

func _check_exact_settlement(actual: Dictionary, expected: Dictionary, prefix: String) -> void:
	# Never route RNG or settlement scalars through JSON or floating comparison.
	# In particular, a one-unit difference in a 64-bit RNG integer must fail.
	for key in ["rng_seed", "rng_state"]:
		_expect(typeof(actual[key]) == TYPE_INT and typeof(expected[key]) == TYPE_INT and actual[key] == expected[key], prefix + "reload preserves exact integer " + key)
	for key in ["bankroll", "clock", "node", "count", "travel_log_entries", "drunk_level"]:
		_expect(typeof(actual[key]) == typeof(expected[key]) and actual[key] == expected[key], prefix + "reload preserves exact settlement " + key)


func _same_nonmenu_reload_values(a: Variant, b: Variant, path: String = "") -> bool:
	# Pristine current main and the integrated host reproduce byte-identical Rafi
	# reload evidence: only these pending-dialogue presentation leaves rebuild
	# below JSON wire precision. All semantic siblings and raw settlement stay exact.
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _same_nonmenu_reload_values(a[key], b[key], path + ("." if not path.is_empty() else "") + str(key)): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not _same_nonmenu_reload_values(a[index], b[index], path + "[%d]" % index): return false
		return true
	if a == b: return true
	if typeof(a) != TYPE_FLOAT or typeof(b) != TYPE_FLOAT: return false
	var leaf := RegEx.new()
	leaf.compile("^pending_events\\[[0-9]+\\]\\.context\\.environment_snapshot\\.(layout\\.object_rects\\.[^.]+\\.[xywh]|music_profile\\.volume)$")
	return leaf.search(path) != null and JSON.stringify(a) == JSON.stringify(b) and abs(a - b) <= 4.440892098500626e-16


func _test_nonmenu_reload_comparison() -> void:
	var leaf := "pending_events[0].context.environment_snapshot.layout.object_rects.travel:leave.x"
	var volume := "pending_events[0].context.environment_snapshot.music_profile.volume"
	var wire_same := 0.5 + 2.220446049250313e-16
	_expect(_same_nonmenu_reload_values(0.5, wire_same, leaf), "reload comparison admits only sub-wire presentation coordinate precision")
	_expect(_same_nonmenu_reload_values(0.5, wire_same, volume), "reload comparison admits observed sub-wire music volume precision")
	_expect(not _same_nonmenu_reload_values(0.5, 0.500000000001, leaf), "reload comparison rejects larger geometry perturbations")
	_expect(not _same_nonmenu_reload_values(0.5, wire_same, "current_environment.layout.object_rects.travel:leave.x"), "reload comparison rejects unrelated environment geometry")
	_expect(not _same_nonmenu_reload_values(0.5, wire_same, "pending_events[0].context.environment_snapshot.scenario_layout_authority.x"), "reload comparison rejects authority changes")
	_expect(not _same_nonmenu_reload_values(0.5, wire_same, "pending_events[0].context.environment_snapshot.layout.object_rects.travel:leave.money"), "reload comparison rejects non-coordinate siblings")
	_expect(not _same_nonmenu_reload_values(0.5, wire_same, "pending_events[0].bankroll"), "reload comparison rejects event gameplay changes")
	_expect(not _same_nonmenu_reload_values(9223372036854775700, 9223372036854775701, "rng_state"), "reload comparison rejects one-unit 64-bit RNG changes")
	_expect(not _same_nonmenu_reload_values({"bankroll":5}, {"bankroll":6}), "reload comparison rejects settlement changes")
	_expect(not _same_nonmenu_reload_values({"node":"bar"}, {"node":"bar", "extra":0}), "reload comparison rejects changed key sets")
