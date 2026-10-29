extends SceneTree

const Host := preload("res://scripts/ui/foundation_main.gd")
const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")
const Model := preload("res://scripts/ui/scenario_semantic_view_model.gd")
const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
const HOST_ID := "event:town_rumor_staff"
const COMMAND := "move_remaining_staff"
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var mode := OS.get_environment("BTH_UI032_MODE")
	if mode.is_empty(): mode = "inspect"
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "private distribution root required"):
		_finish(); return
	if mode != "cold": _install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "official captured-save Continue"):
		app.queue_free(); await process_frame; _finish(); return
	var run: RunState = app.run_state
	if mode == "cold":
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_UI032_EXPECTED_RESULT")))
		_check(not expected.is_empty() and expected.get("failures", [1]).is_empty(), "qualified previous completion receipt required")
		var want: Dictionary = expected.get("facts", {})
		var protected_reference: Variant = bytes_to_var(Marshalls.base64_to_raw(str(want.get("protected_variant_base64", ""))))
		_check(_protected(run) == protected_reference, "independent-process protected state exactly restored")
		_check(run.current_environment.scenario_sequence_state.command_receipts == want.get("command_receipts", []), "independent-process exact four receipts restored")
		_check(str(run.current_environment.scenario_sequence_state.status) == "aftermath", "independent-process terminal aftermath restored")
		_check(run.current_environment.scenario_sequence_state.resolved_outcomes == want.get("resolved_outcomes", []), "independent-process same outcome without replay")
		_check(_find_entry(app, COMMAND).is_empty(), "independent-process completed command is absent")
		facts = {"mode": mode, "cash": run.bankroll, "Heat": run.suspicion_level(), "command_count": run.current_environment.scenario_sequence_state.command_receipts.size()}
		app.queue_free(); await process_frame; _finish(); return
	_check(run.bankroll == 48 and run.suspicion_level() == 4, "preserved cash48 Heat4")
	_check(str(run.current_environment.scenario_sequence_state.phase_id) == "work_3", "preserved work3 active phase")
	var receipts: Array = run.current_environment.scenario_sequence_state.command_receipts.duplicate(true)
	_check(receipts.size() == 3, "three prior commands accepted exactly once")
	var protected := _protected(run)
	app.focus_interactable_object(HOST_ID)
	for frame in range(3): await process_frame
	var record: Dictionary = app._interactable_object(HOST_ID)
	var entry := _find_entry(app, COMMAND)
	facts = {"mode": mode, "host_id": HOST_ID, "host_label": record.get("label", ""), "sequence_action_count": record.get("scenario_sequence_actions", []).size(), "inline_labels": record.get("inline_actions", []).map(func(x): return x.get("label", "")), "paid_inputs": 0}
	if not _check(not entry.is_empty() and bool(entry.get("enabled", false)), "actual floating host card exposes enabled Move Remaining Staff"):
		app.queue_free(); await process_frame; _finish(); return
	_check(_count_label(app, "Talk") == 1, "ordinary Talk retained exactly once")
	_check(_count_label(app, "Move Remaining Staff") == 1, "task shown exactly once")
	var token := str(entry.get("emit_object_id", ""))
	var descriptor := Model.action_descriptor_for_token(app._interactable_object_view_list(), token)
	_check(str(descriptor.get("sequence_record", {}).get("object_id", "")) == HOST_ID, "public token resolves exact existing physical host")
	var action: Dictionary = descriptor.get("sequence_action", {})
	_check(str(action.get("attached_stable_object_id", "")) == "kitty_cat_lounge_slow_night_task_3", "attached task identity retained")
	_check(not str(action.get("action_origin_receipt_key", "")).is_empty() and not str(action.get("action_origin_fingerprint", "")).is_empty(), "original action proof retained")
	for repeat in range(3): app._refresh()
	_check(_count_label(app, "Talk") == 1 and _count_label(app, "Move Remaining Staff") == 1, "repeated publication creates no duplicate controls")
	_check(_protected(run) == protected and run.current_environment.scenario_sequence_state.command_receipts == receipts, "projection is read-only for gameplay and three accepted commands")
	if mode == "inspect":
		_synthetic_controls()
		app.save_foundation_run()
		_check(app.return_to_main_menu(), "normal Menu after active-stage Save")
		await process_frame
		app.save_service = SaveService.new()
		_check(app.load_foundation_run(), "fresh SaveService active-stage Continue")
		run = app.run_state
		app.focus_interactable_object(HOST_ID)
		for frame in range(3): await process_frame
		_check(not _find_entry(app, COMMAND).is_empty() and _count_label(app, "Talk") == 1, "cold active stage retains both task and ordinary action")
		_check(_protected(run) == protected and run.current_environment.scenario_sequence_state.command_receipts == receipts, "active-stage Save/Continue preserves accepted state")
	else:
		# Use the actual rendered Canvas action entry, not a reducer/debug command.
		entry = _find_entry(app, COMMAND)
		_check(app.environment_canvas._activate_selected_info_action_entry(entry), "actual Canvas action dispatch accepted")
		for frame in range(8): await process_frame
		var state: Dictionary = run.current_environment.scenario_sequence_state
		_check(str(state.status) == "aftermath", "normal final action reaches terminal aftermath")
		_check(state.command_receipts.size() == 4 and state.command_receipts.slice(0, 3) == receipts, "one final command appends to unchanged prior three receipts")
		_check(state.resolved_outcomes == ["selected_zone_active"], "authored selected-zone outcome reached")
		_check(_protected(run) == protected, "completion preserves cash/Heat/ledger/inventory/Numbers/RNG and accepted history")
		_check(_find_entry(app, COMMAND).is_empty(), "completed task removed from live card")
		var after_receipts: Array = state.command_receipts.duplicate(true)
		app.environment_canvas._activate_selected_info_action_entry(entry)
		for frame in range(5): await process_frame
		_check(run.current_environment.scenario_sequence_state.command_receipts == after_receipts and _protected(run) == protected, "stale repeated input cannot complete or reward twice")
		_check(Model.action_descriptor_for_token(app._interactable_object_view_list(), token).is_empty(), "old task token is no longer a live authority")
		app.save_foundation_run()
		_check(app.return_to_main_menu(), "normal Menu after completed Save")
		await process_frame
		app.save_service = SaveService.new()
		_check(app.load_foundation_run(), "fresh SaveService completed Continue")
		run = app.run_state
		_check(str(run.current_environment.scenario_sequence_state.status) == "aftermath" and run.current_environment.scenario_sequence_state.command_receipts == after_receipts, "completed state restores once without replay")
		_check(_protected(run) == protected and _find_entry(app, COMMAND).is_empty(), "restored completion preserves gameplay and removes task")
		facts["protected_variant_base64"] = Marshalls.raw_to_base64(var_to_bytes(protected))
		facts["command_receipts"] = after_receipts
		facts["resolved_outcomes"] = run.current_environment.scenario_sequence_state.resolved_outcomes
	facts["cash"] = run.bankroll; facts["Heat"] = run.suspicion_level()
	facts["command_count"] = run.current_environment.scenario_sequence_state.command_receipts.size()
	app.queue_free()
	for frame in range(3): await process_frame
	_finish()

func _find_entry(app: Host, command: String) -> Dictionary:
	var canvas: Canvas = app.environment_canvas
	canvas.set_selected_object(HOST_ID)
	for value in canvas._selected_info_action_entries_from_info(canvas._selected_object_info()):
		var token := str(value.get("emit_object_id", ""))
		var descriptor := Model.action_descriptor_for_token(app._interactable_object_view_list(), token)
		if str(descriptor.get("sequence_action", {}).get("id", "")) == command: return value
	return {}

func _count_label(app: Host, label: String) -> int:
	var canvas: Canvas = app.environment_canvas
	var count := 0
	for value in canvas._selected_info_action_entries_from_info(canvas._selected_object_info()):
		if str(value.get("label", "")) == label: count += 1
	return count

func _synthetic_controls() -> void:
	var action := {"id": "move_staff", "label": "Move staff", "enabled": true, "attached_owner_namespace": "scenario", "attached_stable_object_id": "task_3", "action_origin_receipt_key": "receipt", "action_origin_boundary_id": "phase3", "action_origin_fingerprint": "proof"}
	var base := {"object_id": "event:staff", "object_type": "event", "owner_namespace": "event", "stable_object_id": "event:staff", "source_id": "staff", "enabled": true, "interactive": true, "available_actions": [{"id": "talk", "label": "Talk"}], "confirm_action_id": "talk", "inline_actions": []}
	var semantic := {"owner_namespace": "event", "stable_object_id": "event:staff", "presentation_object_id": "event:staff", "enabled": true, "available_actions": [action]}
	var authority := {"presentation_object_id": "event:staff"}
	var original := semantic.duplicate(true)
	var projected := Controller._merge_projected_interaction(base, semantic, authority, "", 7)
	var live := Controller.restore_live_presentation_fields([projected], [base])[0] as Dictionary
	_check(live.inline_actions.map(func(x): return x.label) == ["Talk", "Move staff"], "synthetic base-event host preserves own Talk plus attached command")
	_check(semantic == original, "synthetic reader does not mutate authored interaction")
	var token := str(live.inline_actions[1].emit_object_id)
	_check(Model.action_descriptor_for_token([live], token).get("sequence_action", {}) == action, "synthetic attached proof exact")
	_check(Model.action_descriptor_for_token([live], token + "forged").is_empty(), "forged token rejected")
	var restored := Controller.restore_live_presentation_fields([live], [base])[0] as Dictionary
	_check(restored.inline_actions == live.inline_actions, "repeated live restore does not duplicate controls")
	var next := Controller._merge_projected_interaction(base, semantic, authority, "", 8)
	_check(Model.action_descriptor_for_token([next], token).is_empty(), "stale-boundary token rejected")
	var hidden := semantic.duplicate(true); hidden.available_actions[0].hidden = true
	_check(Controller._merge_projected_interaction(base, hidden, authority, "", 7).get("scenario_augmented_inline_actions", []).is_empty(), "hidden attached command never published")
	var disabled := semantic.duplicate(true); disabled.available_actions[0].enabled = false
	var disabled_record := Controller.restore_live_presentation_fields([Controller._merge_projected_interaction(base, disabled, authority, "", 7)], [base])[0] as Dictionary
	_check(not bool(disabled_record.inline_actions[-1].enabled) and Model.action_descriptor_for_token([disabled_record], token).is_empty(), "disabled attached command remains disabled and unresolvable")
	var own_inline := base.duplicate(true); own_inline.inline_actions = [{"label": "Hear rumor", "emit_object_id": "event_response:staff:hear", "enabled": true}, {"label": "Leave", "emit_object_id": "event_response:staff:leave", "enabled": true}]
	var multi := Controller.restore_live_presentation_fields([projected], [own_inline])[0] as Dictionary
	_check(multi.inline_actions.map(func(x): return x.label) == ["Hear rumor", "Leave", "Move staff"], "ordinary multiple inline choices remain intact without extra Talk")
	var scenario := semantic.duplicate(true); scenario.owner_namespace = "scenario"; scenario.stable_object_id = "prop"; scenario.available_actions = [action, {"id": "refuse", "label": "Refuse"}]
	var scenario_record := Controller._merge_projected_interaction({}, scenario, {"presentation_object_id": "scenario::prop"}, "", 7)
	_check(scenario_record.inline_actions.size() == 2 and scenario_record.get("scenario_augmented_inline_actions", []).is_empty(), "scenario-owned multiple actions keep existing path")
	var world := semantic.duplicate(true); world.world_sequence_owner_token = "world_token"
	_check(Controller._merge_projected_interaction(base, world, authority, "", 7).get("scenario_augmented_inline_actions", []).is_empty(), "world-owned dispatch remains unchanged")

func _protected(run: RunState) -> Dictionary:
	var result: Dictionary = {}
	var state := run.to_dict()
	for key in ["bankroll", "grand_casino_chips", "debt", "grand_casino_atm_debt", "suspicion", "inventory", "home_state", "crew_state", "numbers_state", "rng_seed", "rng_state", "story_log", "story_flags", "narrative_flags", "event_cadence", "run_spending_score", "game_clock_minutes", "run_status"]: result[key] = state.get(key)
	result["game_states"] = run.current_environment.get("game_states", {}).duplicate(true)
	result["turns"] = run.current_environment.get("turns", 0)
	return result.duplicate(true)

func _install(bundle: String) -> void:
	_check(not bundle.is_empty(), "unchanged captured bundle required")
	var user := ProjectSettings.globalize_path("user://")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(user); DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "copy private save")
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user.path_join(".crew_host_authority_v1")) == OK, "copy private authority")
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"]]:
		for suffix in ["", ".bak"]:
			if FileAccess.file_exists(bundle.path_join(pair[0] + suffix)):
				_check(DirAccess.copy_absolute(bundle.path_join(pair[0] + suffix), OS.get_environment(pair[1]) + suffix) == OK, "copy private profile")

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "  ")); file.close()
	print("ATTACHED_SCENARIO_PUBLICATION checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
