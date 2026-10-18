extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const DeveloperPlacementStoreScript := preload("res://scripts/core/developer_placement_store.gd")
const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")

const SCENARIO_ID := "jazz_club_guest_legend"
const GUEST_ID := "scenario::jazz_club_guest_legend_guest_legend"
const SAFE_EXIT_ID := "scenario::jazz_club_guest_legend_safe_exit"
const TIP_EVENT_OBJECT_ID := "event:scenario_guest_legend_tip"
const TIP_EVENT_ID := "scenario_guest_legend_tip"
const PULL_TABS_ID := "game:pull_tabs"
const SUCCESS_ROUTE := [
	{"phase": "arrival", "task": "scenario::jazz_club_guest_legend_task_0", "action": "find_instrument_case", "next": "work_1"},
	{"phase": "work_1", "task": "scenario::jazz_club_guest_legend_task_1", "action": "open_backstage_lane", "next": "work_2"},
	{"phase": "work_2", "task": "scenario::jazz_club_guest_legend_task_2", "action": "inspect_missing_piece", "next": "work_3"},
	{"phase": "work_3", "task": "scenario::jazz_club_guest_legend_task_3", "action": "prepare_missing_cue", "next": "work_4"},
	{"phase": "work_4", "task": "scenario::jazz_club_guest_legend_task_4", "action": "reorder_set_cards", "next": "work_5"},
	{"phase": "work_5", "task": "scenario::jazz_club_guest_legend_task_5", "action": "time_guest_reveal", "next": "terminal_success"},
]

var app: Control
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	var temp_root := ProjectSettings.globalize_path("res://.tmp/environment_library_guest_legend_action_hosts_check")
	DirAccess.make_dir_recursive_absolute(temp_root)
	OS.set_environment("BTH_USER_SETTINGS_PATH", temp_root.path_join("settings.json"))
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, temp_root.path_join("placement_user.json"))
	DeveloperPlacementStoreScript.reload()
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "environment_library_guest_legend_action_hosts_check")
	root.add_child(app)
	await _settle(4)
	app.call("open_settings_menu")
	await _settle(2)
	var settings_menu := app.get("settings_menu") as Control
	if settings_menu != null:
		settings_menu.call("_on_developer_slot_placement_mode", true)
	app.call("_on_settings_environment_library_requested")
	await _settle(3)
	var archetypes := app.get("environment_test_archetype_option") as OptionButton
	_select_metadata(archetypes, "jazz_club")
	app.call("_on_environment_test_archetype_selected", archetypes.selected)
	var scenarios := app.get("environment_test_scenario_option") as OptionButton
	_select_metadata(scenarios, SCENARIO_ID)
	app.call("_on_environment_test_scenario_selected", scenarios.selected)
	var result: Dictionary = app.call("start_environment_test_session")
	await _settle(6)
	_check(bool(result.get("ok", false)), "Guest Legend must load in Environment Library repair mode: %s" % JSON.stringify(result))
	if not bool(result.get("ok", false)):
		_finish()
		return
	var run_state: Variant = app.get("run_state")
	var authority_proof := EnvironmentInteractionControllerScript._object_manifest_join_proof(
		run_state.current_environment if run_state != null else {}
	)
	_check(
		bool(authority_proof.get("ok", false)),
		"Guest Legend room authority must pass before interaction composition: %s" % JSON.stringify(authority_proof.get("errors", []))
	)

	for step_value in SUCCESS_ROUTE:
		var step := step_value as Dictionary
		var phase_id := str(step.get("phase", ""))
		var records: Array = app.call("_interactable_object_view_list")
		_check_active_attachment(records, phase_id, str(step.get("task", "")), str(step.get("action", "")))
		if not failures.is_empty():
			break
		var carriers := _scenario_action_carriers(records, str(step.get("action", "")))
		var carrier := carriers[0] as Dictionary if carriers.size() == 1 else {}
		var action := _scenario_action(carrier, str(step.get("action", "")))
		_check(not action.is_empty(), "%s must expose action %s on exactly one visible physical carrier." % [phase_id, str(step.get("action", ""))])
		if action.is_empty():
			break
		var activated := bool(app.call("_activate_scenario_sequence_action", carrier, action))
		_check(activated, "%s action %s must be accepted by the production UI route." % [phase_id, str(step.get("action", ""))])
		if not activated:
			break
		await _settle(8)
		var state := _scenario_state()
		var expected_next := str(step.get("next", ""))
		_check(str(state.get("phase_id", "")) == expected_next, "%s action %s must advance to %s, got state=%s." % [phase_id, str(step.get("action", "")), expected_next, JSON.stringify(state)])

	if failures.is_empty():
		_check_terminal_cleanup(app.call("_interactable_object_view_list"))
	_finish()


func _check_active_attachment(records: Array, phase_id: String, task_id: String, action_id: String) -> void:
	var state := _scenario_state()
	_check(str(state.get("status", "")) == "active", "%s must remain active while its room hosts are checked: %s" % [phase_id, JSON.stringify(state)])
	_check(str(state.get("phase_id", "")) == phase_id, "Expected Guest Legend phase %s, got %s." % [phase_id, str(state.get("phase_id", ""))])
	_check(_record_count(records, TIP_EVENT_OBJECT_ID) == 0, "%s must not render Tip the Guest Legend as a standalone room marker." % phase_id)
	var pull_tabs := _record(records, PULL_TABS_ID)
	_check(
		str(pull_tabs.get("presentation_mode", "")) == "room"
			and str(pull_tabs.get("slot_id", "")) == "fixed.pulltab_game"
			and str(pull_tabs.get("slot_binding_source_id", "")).is_empty(),
		"%s must keep Pull Tabs on its physical machine slot instead of rebinding it to the bartender: %s" % [phase_id, JSON.stringify(_record_summary(pull_tabs))]
	)

	var guest_records := _records(records, GUEST_ID)
	_check(guest_records.size() == 1, "%s must render exactly one Guest Legend host, got %d." % [phase_id, guest_records.size()])
	if guest_records.size() == 1:
		var guest := guest_records[0] as Dictionary
		_check(bool(guest.get("visible", true)) and str(guest.get("presentation_mode", "room")) == "room", "%s Guest Legend host must remain a visible room object: %s" % [phase_id, JSON.stringify(guest)])
		_check(bool(guest.get("scenario_layout_resolved", false)), "%s Guest Legend host must retain sealed scenario layout authority." % phase_id)
		_check(_has_attached_source(guest, TIP_EVENT_OBJECT_ID), "%s must attach Tip the Guest Legend to the visible Guest Legend actor." % phase_id)

	var exit_records := _records(records, SAFE_EXIT_ID)
	_check(exit_records.size() == 1, "%s must render exactly one Guest Legend safe exit, got %d." % [phase_id, exit_records.size()])
	if exit_records.size() == 1:
		var safe_exit := exit_records[0] as Dictionary
		_check(bool(safe_exit.get("visible", true)) and str(safe_exit.get("presentation_mode", "room")) == "room", "%s safe exit must remain a visible room object: %s" % [phase_id, JSON.stringify(safe_exit)])
		_check(bool(safe_exit.get("scenario_layout_resolved", false)), "%s safe exit must retain sealed scenario layout authority." % phase_id)
		_check(not _scenario_action(safe_exit, "refuse_jazz_club_guest_legend").is_empty(), "%s safe exit must retain its refuse action directly." % phase_id)

	var carriers := _scenario_action_carriers(records, action_id)
	_check(carriers.size() == 1, "%s must expose %s on exactly one visible physical carrier, got %d (%s)." % [phase_id, action_id, carriers.size(), JSON.stringify(_record_id_list(carriers))])
	if carriers.size() == 1:
		var carrier := carriers[0] as Dictionary
		_check(bool(carrier.get("visible", true)) and str(carrier.get("presentation_mode", "room")) == "room", "%s action %s must remain on a visible room object: %s" % [phase_id, action_id, JSON.stringify(_record_summary(carrier))])
		_check(bool(carrier.get("scenario_layout_resolved", false)), "%s action %s carrier must retain sealed scenario layout authority." % [phase_id, action_id])
		var action := _scenario_action(carrier, action_id)
		_check(str(action.get("action_origin_stable_object_id", "")) == task_id.trim_prefix("scenario::"), "%s action %s must retain abstract task origin %s: %s" % [phase_id, action_id, task_id, JSON.stringify(action)])
	_check(_lifecycle_errors().is_empty(), "%s produced scenario lifecycle errors: %s" % [phase_id, JSON.stringify(_lifecycle_errors())])


func _check_terminal_cleanup(records: Array) -> void:
	var state := _scenario_state()
	_check(str(state.get("status", "")) == "aftermath", "Guest Legend success route must publish aftermath state: %s" % JSON.stringify(state))
	_check(str(state.get("phase_id", "")) == "terminal_success", "Guest Legend success route must end in terminal_success: %s" % JSON.stringify(state))
	_check(_record_count(records, GUEST_ID) == 0, "Terminal Guest Legend must remove the original guest actor and its actions.")
	_check(_record_count(records, SAFE_EXIT_ID) == 0, "Terminal Guest Legend must remove the scenario safe exit and its actions.")
	_check(_record_count(records, TIP_EVENT_OBJECT_ID) == 0, "Terminal Guest Legend must not leave its hosted tip event as an orphan room action.")
	_check(not _records_reference_attached_source(records, TIP_EVENT_OBJECT_ID), "Terminal Guest Legend must remove the hosted tip action from every room record.")
	var environment := app.get("run_state").current_environment as Dictionary
	var resolved: Array = environment.get("resolved_event_ids", []) if typeof(environment.get("resolved_event_ids", [])) == TYPE_ARRAY else []
	_check(resolved.has(TIP_EVENT_ID), "Terminal Guest Legend must atomically resolve its hosted tip event: %s" % JSON.stringify(resolved))
	_check(_lifecycle_errors().is_empty(), "Terminal Guest Legend produced scenario lifecycle errors: %s" % JSON.stringify(_lifecycle_errors()))


func _scenario_state() -> Dictionary:
	var run_state: Variant = app.get("run_state")
	if run_state == null or typeof(run_state.current_environment.get("scenario_sequence_state", {})) != TYPE_DICTIONARY:
		return {}
	return (run_state.current_environment.get("scenario_sequence_state", {}) as Dictionary).duplicate(true)


func _lifecycle_errors() -> Array:
	var run_state: Variant = app.get("run_state")
	if run_state == null or typeof(run_state.current_environment.get("scenario_sequence_lifecycle_errors", [])) != TYPE_ARRAY:
		return []
	return (run_state.current_environment.get("scenario_sequence_lifecycle_errors", []) as Array).duplicate(true)


func _scenario_action(record: Dictionary, action_id: String) -> Dictionary:
	for value in record.get("scenario_sequence_actions", []) as Array:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == action_id:
			return (value as Dictionary).duplicate(true)
	return {}


func _scenario_action_carriers(records: Array, action_id: String) -> Array:
	var result: Array = []
	for value in records:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var record := value as Dictionary
		if not _scenario_action(record, action_id).is_empty():
			result.append(record)
	return result


func _record_summary(record: Dictionary) -> Dictionary:
	return {
		"object_id": str(record.get("object_id", "")),
		"object_type": str(record.get("object_type", "")),
		"presentation_mode": str(record.get("presentation_mode", "")),
		"slot_id": str(record.get("slot_id", "")),
		"scenario_layout_resolved": bool(record.get("scenario_layout_resolved", false)),
	}


func _record_id_list(records: Array) -> Array:
	var result: Array = []
	for value in records:
		if typeof(value) == TYPE_DICTIONARY:
			result.append(str((value as Dictionary).get("object_id", "")))
	return result


func _has_attached_source(record: Dictionary, source_object_id: String) -> bool:
	for value in record.get("attached_room_actions", []) as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var descriptor := value as Dictionary
		var source: Dictionary = descriptor.get("record", {}) if typeof(descriptor.get("record", {})) == TYPE_DICTIONARY else {}
		if str(source.get("object_id", "")) == source_object_id:
			return true
	return false


func _records_reference_attached_source(records: Array, source_object_id: String) -> bool:
	for value in records:
		if typeof(value) == TYPE_DICTIONARY and _has_attached_source(value as Dictionary, source_object_id):
			return true
	return false


func _record(records: Array, object_id: String) -> Dictionary:
	var matches := _records(records, object_id)
	return matches[0] as Dictionary if not matches.is_empty() else {}


func _record_count(records: Array, object_id: String) -> int:
	return _records(records, object_id).size()


func _records(records: Array, object_id: String) -> Array:
	var result: Array = []
	for value in records:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("object_id", "")) == object_id:
			result.append(value)
	return result


func _select_metadata(option: OptionButton, wanted: String) -> void:
	if option == null:
		failures.append("Missing selector for %s." % wanted)
		return
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == wanted:
			option.select(index)
			return
	failures.append("Selector did not contain %s." % wanted)


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ENVIRONMENT_LIBRARY_GUEST_LEGEND_ACTION_HOSTS_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
