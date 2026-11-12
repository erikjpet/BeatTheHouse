extends "res://scripts/tests/standard_travel_integration_check.gd"

# Extends only the existing production-host assertions/helpers. A fixture is
# always an enabled route settled by Main, never an invented edge or transport.
# --find-fixtures prints the replay recipe and exact progressed conditions.
# --capture-destination=<canonical id> [--capture-mode=<actual mode>] uses the
# same real Main/overlay and naturally rendered Movie Maker frames at 30 FPS.
const Catalog := preload("res://scripts/ui/travel_presentation_catalog.gd")
const Timeline := preload("res://scripts/ui/travel_arrival_timeline.gd")
const DESTINATIONS := ["corner_store", "back_alley", "motel", "bar",
	"gas_station_casino", "small_underground_casino", "jazz_club",
	"kitty_cat_lounge", "delta_queen", "beach", "pawn_shop", "grand_casino",
	"motel_room", "apartment", "house"]
const EXCLUDED_INTERIORS := ["grand_casino_cage", "grand_casino_high_limit", "grand_casino_back_room"]
const PROGRESSED_CONDITIONS := {"bankroll":2000, "game_clock_minutes":1080,
	"environment_history_archive_count":4,
	"narrative_flags":{"underground_tip":true, "grand_casino_invite":true},
	"discovery_api":"WorldMap.unlock_runtime_nodes on existing generated nodes only",
	"description":"Throwaway progressed QA state, not an unmodified generated start. No graph edges, mode, route cost, environment installation or risk result are overridden."}
const DESTINATION_RECIPES := [
	{"seed":"STANDARD-TRAVEL-apartment-0", "home":"apartment", "steps":["pawn_shop"], "target":"corner_store", "mode":"walk"},
	{"seed":"STANDARD-TRAVEL-back_alley-0", "home":"back_alley", "steps":["gas_station_casino"], "target":"motel", "mode":"bus"},
	{"seed":"STANDARD-TRAVEL-back_alley-0", "home":"back_alley", "steps":["corner_store"], "target":"pawn_shop", "mode":"bus"},
	{"seed":"STANDARD-TRAVEL-apartment-0", "home":"apartment", "steps":["bar"], "target":"apartment", "mode":"taxi"},
	{"seed":"STANDARD-TRAVEL-motel_room-0", "home":"motel_room", "steps":["gas_station_casino"], "target":"motel_room", "mode":"bus"},
	{"seed":"STANDARD-TRAVEL-house-0", "home":"house", "steps":["gas_station_casino"], "target":"house", "mode":"taxi"},
	{"seed":"STANDARD-TRAVEL-apartment-0", "home":"apartment", "steps":["grand_casino"], "target":"small_underground_casino", "mode":"taxi", "progressed":true},
	{"seed":"STANDARD-TRAVEL-back_alley-0", "home":"back_alley", "steps":["delta_queen", "service:riverboat_deck_walk", "service:riverboat_deck_walk"], "target":"beach", "mode":"walk", "progressed":true, "discovered":["delta_queen", "beach"]},
]
var capture_destination := ""
var capture_mode := ""
var requested_destinations: Array = DESTINATIONS
var route_fixtures: Dictionary = {}
var fixture_report: Array = []
var exterior_paths: Dictionary = {}
var active_progressed_conditions: Dictionary = {}
var layout_precision_paths: Dictionary = {}
var visual_stage_variants: Array = []
var presentation_path_patterns: Array[RegEx] = []

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	for argument in arguments:
		if argument.begins_with("--capture-destination="):
			capture_destination = argument.trim_prefix("--capture-destination=")
		if argument.begins_with("--capture-mode="):
			capture_mode = argument.trim_prefix("--capture-mode=")
	if not capture_destination.is_empty() and capture_destination not in DESTINATIONS:
		push_error("Unknown canonical --capture-destination")
		quit(1)
		return
	if not capture_mode.is_empty() and capture_mode not in MODES:
		push_error("--capture-mode must be walk, bus, taxi or night_cab")
		quit(1)
		return
	requested_destinations = DESTINATIONS if capture_destination.is_empty() else [capture_destination]
	app = MainScene.instantiate()
	root.add_child(app)
	if not app.has_method("_build_travel_cinematic_overlay"):
		push_error("Production Main failed to compile; destination suite cannot run")
		app.free()
		quit(1)
		return
	app.continuous_environment_clock_enabled = false
	app._build_travel_cinematic_overlay()
	if not is_instance_valid(app.get("travel_cinematic_overlay")):
		push_error("Production travel overlay failed to construct; destination suite cannot run")
		app.free()
		quit(1)
		return
	app.travel_cinematic_overlay.completed.connect(_on_presentation_completed)
	_test_comparison_boundaries()
	_discover_destination_fixtures()
	for destination in requested_destinations:
		_expect(not _destination_fixture(destination, capture_mode).is_empty(), "enabled actual route found for " + destination + "/" + capture_mode)
	if capture_destination.is_empty():
		for mode in MODES:
			_expect(not _mode_fixture(mode).is_empty(), "all modes have an enabled actual route: " + mode)
		_expect(not _walking_door_fixture().is_empty(), "walking fixture explicitly reaches a door destination")
	if failures.is_empty() and "--find-fixtures" not in arguments:
		if not capture_destination.is_empty():
			await _capture_destination()
		else:
			var tested: Dictionary = {}
			for destination in DESTINATIONS:
				var fixture := _destination_fixture(destination)
				await _test_destination(fixture)
				tested[fixture["key"]] = true
			for mode in MODES:
				var fixture := _mode_fixture(mode)
				if not tested.has(fixture["key"]):
					await _test_destination(fixture)
					tested[fixture["key"]] = true
			var walking := _walking_door_fixture()
			if not tested.has(walking["key"]): await _test_destination(walking)
			_test_local_door_excluded()
			_test_exclusions()
	var report := {"suite":"destination_travel", "checks":checks, "passed":failures.is_empty(),
		"failures":failures, "fixtures":fixture_report, "exterior_paths":exterior_paths,
		"comparison_evidence":{"layout_precision_paths":layout_precision_paths, "visual_stage_variants":visual_stage_variants,
			"stage_source":"scripts/core/scenario_sequence_runtime.gd:728-756 deliberately omits active presentation stages for reduced motion while retaining semantic transition delivery.",
			"layout_rule":"Only enumerated normalized rectangles/focus points and music_profile.volume under pending_events[].context.environment_snapshot may differ, and only when their JSON wire strings are exactly equal and their absolute delta is at most four double-precision machine epsilons. Every other gameplay/event/semantic field is strict.",
			"layout_source":"RunState.environment_context_snapshot retains persistent presentation copies; durable_store.gd:43 writes default JSON precision. Allowed families: layout.object_rects; scenario_base_interactions.normalized_hit_rect; scenario_layout_authority label/hit/small-screen rectangles; scenario_layout_base_records copies of those rectangles plus focus_rect/normalized_rect/focus_point; music_profile.volume. Additional exact geometry copies: scenario_engine.gd:1154-1158 baseline layout; environment_semantic_inventory.gd:1493-1504 authority normalized_hit_rect; scenario_engine.gd:314,657-671 semantic base_interactions normalized_hit_rect. No non-geometry semantic sibling is normalized."},
		"capture_destination":capture_destination, "capture_mode":capture_mode}
	_write_report("destination_travel_report.json", report)
	print(JSON.stringify(report))
	app._cancel_travel_presentation()
	app.pending_autosave = false
	app.save_service.wait_for_async_save()
	app.free()
	quit(0 if failures.is_empty() else 1)

func _start_fixture(seed_text: String, home: String, progressed: bool, discovered: Array = DESTINATIONS) -> bool:
	app._cancel_travel_presentation()
	app.pending_autosave = false
	if not app.start_foundation_run(seed_text, {"modifiers":{"home_archetype_id":home}}, false): return false
	active_progressed_conditions = {}
	if progressed:
		active_progressed_conditions = PROGRESSED_CONDITIONS.duplicate(true)
		active_progressed_conditions["discovered_destinations"] = discovered.duplicate()
		var edges: Array = app.run_state.world_map.get("edges", []).duplicate(true)
		app.run_state.bankroll = PROGRESSED_CONDITIONS["bankroll"]
		app.run_state.game_clock_minutes = PROGRESSED_CONDITIONS["game_clock_minutes"]
		app.run_state.environment_history_archive_count = PROGRESSED_CONDITIONS["environment_history_archive_count"]
		for flag in PROGRESSED_CONDITIONS["narrative_flags"]:
			app.run_state.narrative_flags[flag] = PROGRESSED_CONDITIONS["narrative_flags"][flag]
		app.run_state.world_map = World.unlock_runtime_nodes(app.run_state.world_map, discovered, World.DISCOVERY_SOURCE_EVENT, false)
		_expect(app.run_state.world_map.get("edges", []) == edges, "progressed fixture preserves generated graph edges")
		app._refresh()
	return true

func _discover_destination_fixtures() -> void:
	# Retain the previously verified ordinary replay recipes first. Their exact
	# production modes may not be swapped to meet a requested capture mode.
	for mode in MODES:
		var recipe: Dictionary = KNOWN_FIXTURES[mode]
		if not _start_fixture(recipe["seed"], recipe["home"], false): continue
		var replay_ok := true
		for target in recipe["steps"]:
			if not _take_step(target):
				replay_ok = false
				break
		if replay_ok:
			_consider_route(recipe["target"], recipe["seed"], recipe["home"], recipe["steps"], false)
		if _destination_search_complete(): return
	for recipe in DESTINATION_RECIPES:
		if not capture_destination.is_empty() and (recipe["target"] != capture_destination or (not capture_mode.is_empty() and recipe["mode"] != capture_mode)): continue
		var progressed := bool(recipe.get("progressed", false))
		if not _start_fixture(recipe["seed"], recipe["home"], progressed, recipe.get("discovered", DESTINATIONS)): continue
		var replay_ok := true
		for target in recipe["steps"]:
			if not _take_step(target):
				replay_ok = false
				break
		if replay_ok: _consider_route(recipe["target"], recipe["seed"], recipe["home"], recipe["steps"], progressed)
		if _destination_search_complete(): return
	# Reveal one event-promised destination at a time, rather than making many
	# newly revealed venues compete for the game's capped three-card route list.
	# This is existing discovery behavior, not a target-list or edge override.
	for target in requested_destinations:
		if not _destination_fixture(target, capture_mode).is_empty(): continue
		var home := str(target) if target in HOMES else "back_alley"
		var seed_text := "STANDARD-TRAVEL-%s-0" % home
		if not _start_fixture(seed_text, home, true, [target]): continue
		_consider_route(target, seed_text, home, [], true)
		if _destination_search_complete(): return
	# Generated starts are explored before explicit progressed QA conditions.
	# One visited state per node bounds this fallback search.
	for progressed in [false, true]:
		for home in HOMES:
			if _destination_search_complete(): return
			var seed_text := "STANDARD-TRAVEL-%s-0" % home
			if not _start_fixture(seed_text, home, progressed): continue
			var queue: Array = [{"baseline":app.run_state.to_dict(), "steps":[]}]
			var visited: Dictionary = {}
			var explored := 0
			while not queue.is_empty() and explored < 20:
				if _destination_search_complete(): return
				var entry: Dictionary = queue.pop_front()
				_restore(entry["baseline"])
				var source_id: String = app.run_state.current_world_node_id()
				if visited.has(source_id): continue
				visited[source_id] = true
				explored += 1
				var choices: Array = app._travel_choice_view_list().duplicate(true)
				for candidate in choices:
					if not bool(candidate.get("enabled", false)): continue
					_restore(entry["baseline"])
					var target := str(candidate.get("id", ""))
					if not _consider_route(target, seed_text, home, entry["steps"], progressed): continue
					_finish_receipt()
					var steps: Array = entry["steps"].duplicate()
					steps.append(target)
					if steps.size() < 5 and not visited.has(target) and not app.run_state.is_terminal():
						queue.append({"baseline":app.run_state.to_dict(), "steps":steps})
			print(JSON.stringify({"fixture_search":seed_text, "progressed":progressed, "explored":visited.keys(), "found":route_fixtures.keys()}))

func _consider_route(target: String, seed_text: String, home: String, steps: Array, progressed: bool) -> bool:
	var choice: Dictionary = app._travel_choice(target)
	if not bool(choice.get("enabled", false)): return false
	var before: Dictionary = app.run_state.to_dict()
	var result: Dictionary = app._travel_to(target, str(choice.get("label", "")), choice, true)
	if not bool(result.get("ok", false)): return false
	var receipt: Dictionary = app.run_state.travel_journey_receipt
	var mode := World.travel_method_kind(choice.get("route", {}))
	var key := target + "/" + mode
	var local := bool(choice.get("local_door", false)) or str(choice.get("route", {}).get("travel_method", "")).to_lower() in ["door", "inside", "begin"]
	if target not in DESTINATIONS or mode not in MODES or local or receipt.is_empty() or bool(receipt.get("route_risk", {}).get("triggered", false)) or route_fixtures.has(key): return true
	var info := {"key":key, "seed":seed_text, "home":home, "steps":steps.duplicate(),
		"source":receipt.get("origin_node_id"), "target":target, "mode":mode,
		"fixture_kind":"explicit_progressed_qa" if progressed else "ordinary_generated_replay",
		"progressed_conditions":active_progressed_conditions.duplicate(true) if progressed else {},
		"clock":before["game_clock_minutes"], "cost":choice.get("cost"),
		"travel_minutes":choice.get("travel_minutes"), "route":choice.get("route", {}),
		"receipt":receipt.duplicate(true)}
	var fixture: Dictionary = info.duplicate(true)
	fixture["baseline"] = before
	fixture["choice"] = choice.duplicate(true)
	route_fixtures[key] = fixture
	fixture_report.append(info)
	print(JSON.stringify({"destination_fixture":info}))
	return true

func _take_step(target: String) -> bool:
	if target.begins_with("service:"):
		var service_id := target.trim_prefix("service:")
		app._refresh_run_action_service()
		var option: Dictionary = app.run_action_service.service_hook(service_id)
		if not bool(option.get("enabled", false)):
			print(JSON.stringify({"fixture_service_rejected":service_id, "option":option}))
			return false
		var lock_before: int = app.run_state.current_travel_lock_remaining()
		var cash_before: int = app.run_state.bankroll
		var resolved: Dictionary = app.run_action_service.use_hook("service", service_id)
		if not bool(resolved.get("ok", false)):
			print(JSON.stringify({"fixture_service_rejected":service_id, "result":resolved}))
			return false
		_expect(app.run_state.current_travel_lock_remaining() == maxi(0, lock_before - 1), "real fixture service consumes one departure-lock action")
		_expect(cash_before - app.run_state.bankroll == int(option.get("cost", 0)), "real fixture service pays its quoted cost")
		app._refresh()
		print(JSON.stringify({"fixture_service_completed":service_id, "cost":option.get("cost", 0), "remaining_departure_lock":app.run_state.current_travel_lock_remaining()}))
		return true
	var choice: Dictionary = app._travel_choice(target)
	if not bool(choice.get("enabled", false)): return false
	var result: Dictionary = app._travel_to(target, str(choice.get("label", "")), choice, true)
	_finish_receipt()
	return bool(result.get("ok", false))

func _finish_receipt() -> void:
	if app.travel_presentation_active:
		app.travel_cinematic_overlay.skip_to_receipt()
		app.travel_cinematic_overlay.acknowledge()

func _destination_search_complete() -> bool:
	for destination in requested_destinations:
		if _destination_fixture(destination, capture_mode).is_empty(): return false
	if not capture_destination.is_empty(): return true
	for mode in MODES:
		if _mode_fixture(mode).is_empty(): return false
	return not _walking_door_fixture().is_empty()

func _destination_fixture(destination: String, mode: String = "") -> Dictionary:
	for fixture in route_fixtures.values():
		if fixture["target"] == destination and (mode.is_empty() or fixture["mode"] == mode): return fixture
	return {}

func _mode_fixture(mode: String) -> Dictionary:
	for fixture in route_fixtures.values():
		if fixture["mode"] == mode: return fixture
	return {}

func _walking_door_fixture() -> Dictionary:
	for destination in ["motel", "corner_store", "bar"]:
		var fixture := _destination_fixture(destination, "walk")
		if not fixture.is_empty(): return fixture
	return {}

func _test_destination(fixture: Dictionary) -> void:
	var target := str(fixture["target"])
	var mode := str(fixture["mode"])
	var reference: Dictionary = {}
	for flow in ["watch", "skip", "reduced", "missing", "web_atomic"]:
		# Restore refreshes the host, so preferences must already describe this
		# flow before scenario projections and cached presentation state rebuild.
		app.user_settings.reduce_motion = flow == "reduced"
		app.travel_cinematic_overlay.force_missing_art_for_test = flow == "missing"
		app.travel_transition_force_web_runtime_for_test = flow == "web_atomic"
		_restore(fixture["baseline"])
		var before := _state(app.run_state)
		var choice: Dictionary = app._travel_choice(target)
		var result: Dictionary = _menu_travel(target, flow == "web_atomic")
		var prefix: String = target + "/" + mode + "/" + str(flow) + ": "
		_expect(bool(result.get("ok", false)) and app.travel_presentation_active and not app.travel_transition_active, prefix + "actual Main settles once and owns presentation")
		if not app.travel_presentation_active: continue
		var overlay: Control = app.travel_cinematic_overlay
		var view: Dictionary = app.current_travel_presentation_snapshot()
		var duration := float(view.get("duration_seconds", 0.0))
		var receipt: Dictionary = app.run_state.travel_journey_receipt
		var settled := _state(app.run_state)
		_expect(app.run_state.current_world_node_id() == target and receipt.get("effective_destination_environment_id") == app.run_state.current_environment.get("id"), prefix + "destination installation is authoritative")
		_expect(receipt.get("destination_label") == app.run_state.current_environment.get("display_name") and view.get("destination_label") == receipt.get("destination_label") and str(view.get("title", "")).contains(str(receipt.get("destination_label", "")).to_upper()), prefix + "actual destination label appears in shared title")
		_expect(view.get("mode") == mode and receipt.get("travel_method_kind") == mode and World.travel_method_kind(choice.get("route", {})) == mode, prefix + "renderer uses unchanged actual selected transport")
		_expect(view.get("exterior_id") == target, prefix + "exact canonical destination exterior selected")
		if target == "small_underground_casino":
			_expect(str(app.run_state.current_environment.get("current_layer_id", "")) == "club", prefix + "new Punchline arrival installs the public comedy-club layer of one venue")
		var path := str(view.get("background_path", view.get("street_path", "")))
		_expect(not path.is_empty() and ResourceLoader.exists(path), prefix + "selected background asset exists")
		if not exterior_paths.has(target):
			_expect(path not in exterior_paths.values(), prefix + "distinct destination uses distinct exterior asset")
			exterior_paths[target] = path
		_expect(is_equal_approx(duration, float(Timeline.DURATION_SECONDS)) and is_equal_approx(duration, 8.0), prefix + "shared eight-second sequence uses the current production duration")
		_expect(view.get("stage_rect") == Rect2(64, 116, 1152, 500) and not bool(view.get("narration_visible", true)) and str(view.get("caption", "")).is_empty(), prefix + "enlarged stage has no narration over the destination")
		_expect(view.get("appearance", {}) == Appearance.normalized(Appearance.from_run(app.run_state, app.library)), prefix + "shared avatar matches actual player")
		var contract := _ui_contract()
		if shared_ui_contract.is_empty(): shared_ui_contract = contract
		else: _expect(contract == shared_ui_contract, prefix + "shared UI geometry controls and styling retained")
		_expect(app._modal_contract_blocks_player_input() and app._simulation_progression_paused(), prefix + "input and simulation paused")
		_expect(app.coach_overlay.presentation_suspended and not app.coach_overlay.visible and overlay.z_index > app.coach_overlay.z_index, prefix + "coach remains behind travel scene")
		_expect(bool(view.get("static", false)) == (flow in ["reduced", "missing"]), prefix + "reduced motion and missing art fail safely to static receipt")
		app.continuous_environment_clock_enabled = true
		app._advance_run_game_clock(20.0)
		app.continuous_environment_clock_enabled = false
		_expect(_state(app.run_state) == settled, prefix + "presentation cannot advance game clock")
		var duplicate: Dictionary = app._travel_to(target, str(choice.get("label", "")), choice, true)
		_expect(not bool(duplicate.get("ok", true)) and _state(app.run_state) == settled, prefix + "repeated departure cannot charge twice")
		_expect(not app._show_next_pending_triggered_event(), prefix + "events cannot overlap travel")
		var completed_before := completion_count
		if flow in ["watch", "web_atomic"]:
			_test_choreography(prefix, mode, view)
			for fraction in [0.08, 0.20, 0.40, 0.60, 0.74, 0.82, 0.89, 0.95, 1.0]:
				seed(80123)
				var expected_rng := randi()
				seed(80123)
				overlay.advance_presentation(duration * fraction - float(overlay.elapsed))
				_expect(randi() == expected_rng and _state(app.run_state) == settled, prefix + "presentation sample is RNG and gameplay neutral")
		else: overlay.skip_to_receipt()
		_expect(overlay.phase == "receipt" and app.travel_presentation_active and completion_count == completed_before, prefix + "completion waits for the deferred safe boundary")
		await process_frame
		if flow in ["reduced", "missing"]:
			_expect(app.travel_presentation_active and completion_count == completed_before, prefix + "static outcome remains readable until Continue")
		else:
			_expect(not app.travel_presentation_active and completion_count == completed_before + 1, prefix + "cinematic enters the prepared destination automatically")
		overlay.acknowledge()
		overlay.acknowledge()
		_expect(completion_count == completed_before + 1 and not app.travel_presentation_active and not bool(app.run_state.travel_journey_receipt.get("receipt_pending", true)), prefix + "acknowledgment completes exactly once")
		_expect(_state(app.run_state) == settled, prefix + "watch skip and acknowledgment never settle again")
		_expect(int(settled["count"]) == int(before["count"]) + 1 and int(settled["clock"]) - int(before["clock"]) == int(receipt.get("base_minutes", -1)) and int(before["bankroll"]) - int(settled["bankroll"]) == int(receipt.get("quoted_departure_fare", -1)), prefix + "one journey has exactly one fare clock and move settlement")
		if reference.is_empty(): reference = settled
		else: _expect(_same_flow_outcome(reference, settled, str(flow), prefix), prefix + "watch skip fallback and web gameplay and event outcomes are identical")
		await process_frame
	app.user_settings.reduce_motion = false
	app.travel_cinematic_overlay.force_missing_art_for_test = false
	app.travel_transition_force_web_runtime_for_test = false
	await _test_reload(target + "_" + mode, fixture)
	print(JSON.stringify({"destination_complete":target, "mode":mode, "checks":checks, "failures":failures.size()}))

func _same_flow_outcome(a: Dictionary, b: Dictionary, flow: String, prefix: String) -> bool:
	if a.get("node") != "grand_casino": return _same_saved_values(a, b)
	var before := a.duplicate(true)
	var after := b.duplicate(true)
	var before_sequence := _grand_greeting_sequence(before)
	var after_sequence := _grand_greeting_sequence(after)
	if before_sequence.is_empty() or after_sequence.is_empty(): return _same_saved_values(a, b)
	var original_stages: Array = before_sequence.get("active_stages", [])
	var actual_stages: Array = after_sequence.get("active_stages", [])
	var semantic_receipts_same := _same_saved_values(before_sequence.get("transition_delivery_receipts", []), after_sequence.get("transition_delivery_receipts", []))
	_expect(semantic_receipts_same, prefix + "semantic transition delivery receipts are preserved")
	if flow == "reduced":
		var declared_stage: bool = original_stages.size() == 1 and original_stages[0].get("stage_id") == "grand_casino_convention_crowd_arrival_stage" and original_stages[0].get("stable_object_id") == "grand_casino_convention_crowd_arrival_transition" and original_stages[0].get("op") == "stage" and original_stages[0].get("channel") == "room" and original_stages[0].get("owner_namespace") == "scenario" and int(original_stages[0].get("duration_boundaries", -1)) == 1
		_expect(declared_stage and actual_stages.is_empty(), prefix + "only the declared one-beat Grand room-animation stage is omitted in reduced motion")
		visual_stage_variants.append({"flow":flow, "path":"pending_events[].context.environment_snapshot.scenario_sequence_state.active_stages", "stage_id":"grand_casino_convention_crowd_arrival_stage", "reference":original_stages, "actual":actual_stages, "semantic_transition_receipts_preserved":semantic_receipts_same})
		if not declared_stage or not actual_stages.is_empty() or not semantic_receipts_same: return false
		# Only after validating that exact declared presentation difference do
		# both copies use its reduced representation. Every other field remains.
		before_sequence["active_stages"] = []
	else:
		_expect(_same_saved_values(original_stages, actual_stages), prefix + "ordinary flows retain identical Grand room-animation stages")
	return _same_saved_values(before, after)

func _grand_greeting_sequence(state: Dictionary) -> Dictionary:
	for event in state.get("pending_events", []):
		if event is Dictionary and event.get("event_id") == "dialogue:normal_grand_host_greeting":
			return event.get("context", {}).get("environment_snapshot", {}).get("scenario_sequence_state", {})
	return {}

func _same_saved_values(a: Variant, b: Variant) -> bool:
	return _same_state_value(a, b, "state")

func _same_state_value(a: Variant, b: Variant, path: String) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _same_state_value(a[key], b[key], path + "." + str(key)): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not _same_state_value(a[index], b[index], path + "[%d]" % index): return false
		return true
	if a == b: return true
	if _presentation_precision_path(path) and a is float and b is float and is_finite(a) and is_finite(b) and a >= 0.0 and a <= 1.0 and b >= 0.0 and b <= 1.0:
		var delta: float = absf(a - b)
		# Both checks are required: equal wire text alone could conceal a larger
		# change, while epsilon alone could conceal a different persisted value.
		if delta <= 4.0 * 2.220446049250313e-16 and JSON.stringify(a) == JSON.stringify(b):
			layout_precision_paths[path] = {"before_17":"%.17f" % a, "after_17":"%.17f" % b, "absolute_delta":delta, "wire_value":JSON.stringify(a)}
			return true
	return false

func _presentation_precision_path(path: String) -> bool:
	if presentation_path_patterns.is_empty():
		var prefix := "^state\\.pending_events\\[[0-9]+\\]\\.context\\.environment_snapshot\\."
		for suffix in [
			"layout\\.object_rects\\.[^.]+\\.[xywh]",
			"scenario_sequence_base_layout_object_rects\\.[^.]+\\.[xywh]",
			"scenario_base_interactions\\[[0-9]+\\]\\.normalized_hit_rect\\.[xywh]",
			"scenario_semantic_inventory\\.source_provenance\\.base_interaction_authority\\[[0-9]+\\]\\.normalized_hit_rect\\.[xywh]",
			"scenario_sequence_state\\.semantic_state\\.base_interactions\\[[0-9]+\\]\\.normalized_hit_rect\\.[xywh]",
			"scenario_layout_authority\\.[^.]+\\.(normalized_hit_rect|label_rect|small_screen_label_rect|small_screen_rect)\\.[xywh]",
			"scenario_layout_base_records\\[[0-9]+\\]\\.(normalized_hit_rect|label_rect|small_screen_label_rect|small_screen_rect|focus_rect|normalized_rect)\\.[xywh]",
			"scenario_layout_base_records\\[[0-9]+\\]\\.focus_point\\.[xy]",
			"music_profile\\.volume",
		]:
			var pattern := RegEx.new()
			pattern.compile(prefix + str(suffix) + "$")
			presentation_path_patterns.append(pattern)
	for pattern in presentation_path_patterns:
		if pattern.search(path) != null: return true
	return false

func _test_comparison_boundaries() -> void:
	var prior_evidence := layout_precision_paths.duplicate(true)
	for key in ["bankroll", "clock", "count", "rng_seed", "rng_state", "travel_log_entries"]:
		_expect(not _same_saved_values({key:1.0}, {key:1.0 + 2.220446049250313e-16}), "comparison never tolerates a change to " + key)
	_expect(not _same_saved_values({"pending_events":[{"event_id":"a"}]}, {"pending_events":[{"event_id":"b"}]}), "comparison retains queued event identity")
	_expect(not _same_saved_values({"suspicion":0.1}, {"suspicion":0.10000000000000002}), "comparison retains exact non-layout float values")
	var prefix := "state.pending_events[0].context.environment_snapshot."
	var accepted_before := 0.2576
	var accepted_after := 0.25760000000000005
	_expect(accepted_before != accepted_after and JSON.stringify(accepted_before) == JSON.stringify(accepted_after), "precision control is binary-different but exactly wire-equivalent")
	for suffix in ["layout.object_rects.host.x", "scenario_sequence_base_layout_object_rects.host.x", "scenario_base_interactions[0].normalized_hit_rect.h", "scenario_semantic_inventory.source_provenance.base_interaction_authority[0].normalized_hit_rect.y", "scenario_sequence_state.semantic_state.base_interactions[0].normalized_hit_rect.w", "scenario_layout_authority.host.label_rect.y", "scenario_layout_authority.host.small_screen_rect.w", "scenario_layout_base_records[0].normalized_hit_rect.x", "scenario_layout_base_records[0].focus_rect.h", "scenario_layout_base_records[0].normalized_rect.w", "scenario_layout_base_records[0].focus_point.y", "music_profile.volume"]:
		var path: String = prefix + str(suffix)
		_expect(_same_state_value(accepted_before, accepted_after, path), "known presentation copy accepts only wire-equivalent binary rounding: " + str(suffix))
		_expect(not _same_state_value(0.0001, 0.0001 + 1.0e-16, path), "presentation comparison rejects an under-bound change to JSON wire value: " + str(suffix))
		_expect(not _same_state_value(0.5, 0.5 + 5.0 * 2.220446049250313e-16, path), "presentation comparison rejects an over-bound change: " + str(suffix))
	for suffix in ["bankroll", "game_clock_minutes", "travel_move_counter", "rng_state", "scenario_sequence_state.semantic_state.transition_queue[0].duration_boundaries", "scenario_sequence_state.transition_delivery_receipts[0]", "scenario_semantic_inventory.source_provenance.base_interaction_authority[0].source_record_id", "scenario_sequence_state.semantic_state.base_interactions[0].enabled", "scenario_sequence_state.semantic_state.base_interactions[0].available_actions[0].cost", "scenario_semantic_action_digest", "scenario_layout_base_records[0].min_target_size", "scenario_layout_authority.host.z_order", "unknown.normalized_hit_rect.x", "music_profile.pitch"]:
		_expect(not _same_state_value(accepted_before, accepted_after, prefix + str(suffix)), "no precision tolerance outside the exact presentation leaf allowlist: " + str(suffix))
	_expect(not _same_state_value(accepted_before, accepted_after, "state.layout.object_rects.host.x"), "presentation tolerance does not leak outside queued-event snapshots")
	layout_precision_paths = prior_evidence

func _test_choreography(prefix: String, mode: String, view: Dictionary) -> void:
	var overlay: Control = app.travel_cinematic_overlay
	var kind := str(view.get("entrance_kind", ""))
	var duration := float(view.get("duration_seconds", 0.0))
	var scene: Dictionary = overlay.get("_scene")
	var depth_approach := bool(scene.get("motion", {}).get("walkaway_scale_during_approach", false))
	var near_scale := float(scene.get("motion", {}).get("walkaway_start_scale", 1.0))
	var end_scale := float(scene.get("motion", {}).get("walkaway_end_scale", 0.58))
	var road := float(scene.get("exterior", {}).get("road_y_uv", 0.0))
	_expect(road > 0.0 and road < 1.0 and is_equal_approx(float(scene.get("view_bottom_uv", 0)), 1.0), prefix + "integrated road remains within the authored main PNG")
	var door_opened := false
	var door_closed_after := false
	var entry_advanced := false
	var previous_entry := 0.0
	var previous_position := Vector2.ZERO
	var positions_changed := false
	var entry_position := Vector2.ZERO
	var entry_positions_changed := false
	var previous_progress := 0.0
	for frame in range(361):
		var t := duration * float(frame) / 360.0
		var pose: Dictionary = overlay.choreography_snapshot(t)
		var visible := bool(pose.get("player_visible", false))
		var alpha := float(pose.get("player_alpha", -1))
		var entry := float(pose.get("entry_progress", -1))
		var progress := float(pose.get("arrival_progress", -1))
		_expect(progress >= previous_progress and progress <= 1.0, prefix + "path-distance arrival progress is explicit and monotonic")
		previous_progress = progress
		_expect(entry >= 0 and entry >= previous_entry, prefix + "entry progress is explicit and monotonic")
		previous_entry = entry
		if visible: _expect(is_equal_approx(alpha, 1.0), prefix + "visible player never alpha fades")
		if visible: _expect(float(pose.get("player_position_uv", Vector2.ZERO).y) < 1.0, prefix + "visible player stays inside the authored main scene")
		if bool(pose.get("vehicle_visible", false)): _expect(is_equal_approx(float(pose.get("vehicle_road_y_uv", 0)), road), prefix + "vehicle wheels use this venue's integrated road baseline")
		if visible and (kind == "door" or (t <= 6.15 and not depth_approach)): _expect(is_equal_approx(float(pose.get("player_scale", 0)), 1.0), prefix + "exit and approach keep a uniform adult height")
		if mode == "walk" and t < 5.8: _expect(visible, prefix + "walking approach stays visible")
		if t > 4.8:
			var position: Vector2 = pose.get("player_position_uv", Vector2.ZERO)
			if previous_position != Vector2.ZERO and position.distance_to(previous_position) > 0.00001: positions_changed = true
			previous_position = position
		var openness := float(pose.get("destination_door_open", 0))
		if openness > 0.9: door_opened = true
		if door_opened and openness < 0.05: door_closed_after = true
		if entry > 0.05 and entry < 0.95:
			entry_advanced = true
			if kind == "door":
				_expect(openness > 0.9 and visible and bool(pose.get("player_moving", false)), prefix + "player visibly crosses threshold through fully open door")
				var position: Vector2 = pose.get("player_position_uv", Vector2.ZERO)
				if entry_position != Vector2.ZERO and position.distance_to(entry_position) > 0.00001: entry_positions_changed = true
				entry_position = position
		if kind == "door" and entry >= 0.99 and openness > 0.05:
			_expect(visible and is_equal_approx(alpha, 1.0), prefix + "closing door covers the still-opaque player")
	var final_pose: Dictionary = overlay.choreography_snapshot(duration - 0.01)
	_expect(is_equal_approx(float(final_pose.get("arrival_progress", 0)), 1.0), prefix + "progress reaches completion only at physical arrival")
	var start: float = overlay.choreography_snapshot(0).get("player_approach_start_seconds", -1.0)
	var just_before: Dictionary = overlay.choreography_snapshot(start - 0.001)
	var just_after: Dictionary = overlay.choreography_snapshot(start + 0.04)
	_expect(bool(just_after.get("player_moving", false)), prefix + "pedestrian approach begins at its declared clearance boundary")
	if mode == "walk":
		_expect(is_equal_approx(start, 3.30), prefix + "walk transit reaches its curb waypoint at3.30 seconds")
		_expect(is_equal_approx(float(just_before.get("player_scale", 0)), 1.0), prefix + "walking approach retains normal facade perspective")
	else:
		var clearance: Dictionary = overlay.choreography_snapshot(start)
		_expect(not bool(just_before.get("player_moving", true)) and is_equal_approx(float(clearance.get("vehicle_left_uv", -1)), float(clearance.get("player_curb_uv", Vector2.ZERO).x) + 0.02), prefix + "approach starts as vehicle rear clears the pedestrian, without an extra wait")
		var curb_wait: Dictionary = overlay.choreography_snapshot(2.60)
		_expect(curb_wait.get("player_position_uv") == just_before.get("player_position_uv") and curb_wait.get("arrival_progress") == just_before.get("arrival_progress"), prefix + "progress pauses while the player waits at the curb")
		var step_start: Dictionary = overlay.choreography_snapshot(1.80)
		var approach_middle: Dictionary = overlay.choreography_snapshot((start + 6.15) * 0.5)
		var threshold_pose: Dictionary = overlay.choreography_snapshot(6.15)
		_expect(is_equal_approx(float(curb_wait.get("player_position_uv", Vector2.ZERO).y), road) and is_equal_approx(float(curb_wait.get("player_position_uv", Vector2.ZERO).y), float(curb_wait.get("vehicle_road_y_uv", 0))), prefix + "dropoff ends on the authored near-wheel ground rather than floating behind the vehicle")
		_expect(float(step_start.get("player_position_uv", Vector2.ZERO).y) < float(curb_wait.get("player_position_uv", Vector2.ZERO).y), prefix + "player steps down toward the viewer from the vehicle floor")
		_expect(is_equal_approx(float(step_start.get("player_scale", 0)), 1.0) and is_equal_approx(float(curb_wait.get("player_scale", 0)), 1.0) and float(approach_middle.get("player_scale", 0)) >= near_scale and float(approach_middle.get("player_scale", 0)) <= 1.0 and is_equal_approx(float(threshold_pose.get("player_scale", 0)), near_scale), prefix + "adult exit and curb scale lead continuously to the authored threshold perspective")
		var base_width := 0.48 if mode == "bus" else 0.34
		_expect(is_equal_approx(float(curb_wait.get("vehicle_width_uv", 0)), base_width * float(scene.get("actor_scene_scale", 1.0))), prefix + "vehicle dimensions retain the restored close-view mode scale")
	if kind == "door":
		_expect(door_opened and door_closed_after and entry_advanced and positions_changed and entry_positions_changed, prefix + "door opens player crosses and door closes over player")
		_expect(float(final_pose.get("entry_progress", 0)) >= 0.99 and float(final_pose.get("destination_door_open", 1)) <= 0.05, prefix + "door entry finishes behind closed door")
		var opening_start: Dictionary = overlay.choreography_snapshot(6.15)
		var opening_end: Dictionary = overlay.choreography_snapshot(6.64)
		_expect(opening_start.get("player_position_uv") == opening_end.get("player_position_uv") and opening_start.get("arrival_progress") == opening_end.get("arrival_progress"), prefix + "progress pauses while the entrance door opens")
	else:
		_expect(kind in ["open", "passage", "dock"], prefix + "outdoor entrance type is explicit")
		_expect(not door_opened and bool(final_pose.get("player_visible", false)) and is_equal_approx(float(final_pose.get("player_alpha", 0)), 1.0) and not bool(final_pose.get("player_moving", true)), prefix + "outdoor arrival remains visibly standing")
		_expect(bool(final_pose.get("player_facing_away", false)) and is_equal_approx(float(final_pose.get("player_scale", 0)), end_scale) and final_pose.get("player_position_uv") == final_pose.get("destination_inside_uv"), prefix + "outdoor player walks away into the measured scene and recedes to its arrival point")

func _test_exclusions() -> void:
	for destination in EXCLUDED_INTERIORS:
		var profile: Dictionary = Catalog.profile({"presentation_key":Catalog.STANDARD_KEY, "travel_method_kind":"walk", "effective_destination_archetype_id":destination})
		_expect(not bool(profile.get("supported", true)), "Grand interior is excluded from standard exterior presentation: " + destination)

func _capture_destination() -> void:
	var evidence := OS.get_environment("BTH_QA_EVIDENCE_DIR")
	_expect(evidence.replace("\\", "/").begins_with("E:/CodexQA/BTH/"), "capture writes only admitted E: evidence")
	# Godot strips reserved --write-movie from script arguments. The guarded
	# launch receipt, engine Movie Maker log and resulting movie verify recording;
	# this in-engine guard only rejects a non-rendering/headless capture.
	_expect(DisplayServer.get_name() != "headless", "capture requires the actual graphical renderer")
	if not failures.is_empty(): return
	var fixture := _destination_fixture(capture_destination, capture_mode)
	_restore(fixture["baseline"])
	app.user_settings.reduce_motion = false
	app.travel_cinematic_overlay.force_missing_art_for_test = false
	app.travel_transition_force_web_runtime_for_test = false
	for _frame in range(15): await process_frame
	var choice: Dictionary = app._travel_choice(capture_destination)
	var result: Dictionary = _menu_travel(capture_destination, true)
	var initial: Dictionary = app.current_travel_presentation_snapshot()
	_expect(bool(result.get("ok", false)) and app.travel_presentation_active and not bool(initial.get("static", true)) and initial.get("mode") == fixture["mode"] and initial.get("exterior_id") == capture_destination, "capture uses actual destination installation and selected production overlay")
	if not failures.is_empty(): return
	var settled := _state(app.run_state)
	var sample_frames := [1, 30, 58, 78, 100, 120, 145, 165, 195, 220, 245, 265, 280, 295, 310, 325, 340, 355, 380]
	var samples: Array = []
	var completed_before := completion_count
	var frames := int(ceil(float(initial.get("duration_seconds", 0.0)) * 30.0)) + 45
	for frame in range(frames):
		await process_frame
		_expect(_state(app.run_state) == settled, "capture naturally rendered frame %d preserves gameplay" % frame)
		if frame in sample_frames:
			await RenderingServer.frame_post_draw
			var path := evidence.path_join("destination_%s_%s_%03d.png" % [capture_destination, fixture["mode"], frame])
			_expect(root.get_texture().get_image().save_png(path) == OK, "capture sample saved")
			samples.append({"frame":frame, "view":app.current_travel_presentation_snapshot(), "path":path})
	_expect(not app.travel_cinematic_overlay.active and not app.travel_presentation_active, "capture naturally enters destination without Continue")
	app.travel_cinematic_overlay.acknowledge()
	app.travel_cinematic_overlay.acknowledge()
	_expect(completion_count == completed_before + 1 and not app.travel_presentation_active and _state(app.run_state) == settled, "capture acknowledgment releases exactly once without effects")
	for _frame in range(30): await process_frame
	var recipe: Dictionary = fixture.duplicate(true)
	recipe.erase("baseline")
	recipe.erase("choice")
	_write_report("destination_%s_%s_capture.json" % [capture_destination, fixture["mode"]], {"fixture":recipe,
		"initial_view":initial, "receipt":app.run_state.travel_journey_receipt, "samples":samples,
		"settled_state":settled, "final_state":_state(app.run_state), "passed":failures.is_empty(), "failures":failures})

func _write_report(name: String, report: Dictionary) -> void:
	var evidence := OS.get_environment("BTH_QA_EVIDENCE_DIR")
	if not evidence.replace("\\", "/").begins_with("E:/CodexQA/BTH/"): return
	var file := FileAccess.open(evidence.path_join(name), FileAccess.WRITE)
	_expect(file != null, "open report " + name)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
