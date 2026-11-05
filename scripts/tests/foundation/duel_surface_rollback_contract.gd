extends RefCounted

const ExistingContract := preload("res://scripts/tests/foundation/scenario_sequence_contract.gd")
const TalkDockScript := preload("res://scripts/ui/talk_dock.gd")
const CoachOverlayScript := preload("res://scripts/ui/coach_overlay.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const EVENT_ID := RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID
const ERROR_TEXT := "Rourke's Back Room table could not open."

class RecordingSaveService:
	extends SaveService
	var synchronous_writes := 0
	var async_starts := 0
	func save_run(state: RunState, slot_id: String = "autosave") -> Error:
		synchronous_writes += 1
		return super.save_run(state, slot_id)
	func begin_save_run(state: RunState, slot_id: String = "autosave") -> Error:
		async_starts += 1
		return super.begin_save_run(state, slot_id)

class DuelProbe:
	extends "res://scripts/ui/foundation_main.gd"
	var fail_duel_factory := false
	var factory_rejection_count := 0
	var factory_rejection_context: Dictionary = {}
	var message_log: Array[String] = []
	var autosave_requests := 0
	var save_preparations := 0
	var save_queues := 0
	var save_flush_attempts := 0
	var item_publications := 0
	var conclusion_publications := 0
	var broad_refresh_count := 0
	var fixture_scripts_ready := false

	func _init() -> void:
		fixture_scripts_ready = _ensure_run_ui_stage_scripts(0) and _ensure_run_ui_stage_scripts(4) and _ensure_run_ui_stage_scripts(10) and _ensure_run_ui_stage_scripts(12)
		run_ui_built = true
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		# The runner explicitly drives the ordinary autosave flush after taking
		# synchronous before/after evidence. No unrelated shell clock is advanced.
		pass
	func _refresh() -> void:
		# This owned shell installs the actual controls used by this action. The
		# broad all-screen refresh is counted; TalkDock refresh remains production.
		broad_refresh_count += 1
	func _show_message(text: String) -> void:
		message_log.append(text)
		super._show_message(text)
	func _autosave_foundation_run(status_text: String = "Autosaved.", force: bool = false) -> bool:
		autosave_requests += 1
		return super._autosave_foundation_run(status_text, force)
	func _prepare_foundation_run_save() -> void:
		save_preparations += 1
		super._prepare_foundation_run_save()
	func _queue_pending_autosave(status_text: String, defer_frames: int, debounce_override_msec: int = -1, max_defer_override_msec: int = -1) -> void:
		save_queues += 1
		super._queue_pending_autosave(status_text, defer_frames, debounce_override_msec, max_defer_override_msec)
	func _write_foundation_run_save(status_text: String = "Autosaved.", synchronous: bool = false) -> bool:
		save_flush_attempts += 1
		return super._write_foundation_run_save(status_text, synchronous)
	func _show_item_found_popups(_result: Dictionary, _inventory_before: Dictionary) -> void:
		item_publications += 1
	func _start_conclusion_animation(_result: Dictionary, _popup_rect: Rect2) -> void:
		conclusion_publications += 1
	func _game_module_for_id(game_id: String) -> GameModule:
		var flags: Dictionary = run_state.current_environment.get("local_narrative_flags", {}) if run_state != null else {}
		if fail_duel_factory and game_id == str(flags.get("showdown_game_id", "")) and not game_id.is_empty():
			factory_rejection_count += 1
			factory_rejection_context = {
				"archetype_id": str(run_state.current_environment.get("archetype_id", "")),
				"game_id": game_id, "game_ids": run_state.current_environment.get("game_ids", []).duplicate(true),
				"duel_active": run_state.grand_casino_duel_active(run_state.current_environment),
				"step": str(run_state.narrative_flags.get("grand_casino_showdown_step", "")),
			}
			return null
		return super._game_module_for_id(game_id)

func run(library: ContentLibrary, tree: SceneTree) -> Dictionary:
	var failures: Array = []
	var cases: Array = []
	for owner in ["direct", "outer"]:
		for reject in [true, false]:
			cases.append(await _run_case(library, tree, owner, reject, failures))
	return {"cases": cases, "failures": failures}

func _run_case(library: ContentLibrary, tree: SceneTree, owner: String, reject: bool, failures: Array) -> Dictionary:
	var label := "%s_%s" % [owner, "surface_failure" if reject else "success_control"]
	var result := {"case": label, "setup_ok": false, "checks": {}}
	var probe := DuelProbe.new()
	probe.name = "Duel010_%s" % label
	probe.size = Vector2(960.0, 640.0)
	probe.library = library
	# Existing producer uses a real generated Grand Casino and the real event
	# sequence, and verifies interrogation beat 2. No duel_ready result is forged.
	probe.run_state = ExistingContract._showdown_caller_run(library)
	probe.generator = RunGenerator.new(library)
	probe.save_service = RecordingSaveService.new()
	probe.autosave_slot_id = "duel010_%s" % label
	probe.current_screen = FoundationMain.SCREEN_ENVIRONMENT
	probe.selected_action_category = FoundationMain.ACTION_CATEGORY_EVENTS
	tree.root.add_child(probe)
	if probe.run_state == null or not probe.fixture_scripts_ready:
		failures.append("%s: actual producer or stage collaborators failed setup." % label)
		probe.free()
		return result
	var membership := probe.run_state.reconcile_environment_object_membership(probe.run_state.current_environment)
	probe._prepare_room_presentation_at_boundary()
	var authority := probe.run_state.validate_room_action_authority()
	if not bool(membership.get("ok", false)) or not bool(authority.get("ok", false)):
		failures.append("%s: generated source room did not have valid current authority." % label)
		result["membership"] = membership
		result["authority"] = authority
		probe.free()
		return result
	_install_ui(probe)
	probe._build_event_choice_popup_overlay()
	var popup_ok := probe._show_interactable_event_popup(EVENT_ID)
	await tree.process_frame
	await tree.process_frame
	# Reach a settled layout through the same lifecycle restoration producer.
	var settled := probe._foundation_lifecycle_snapshot()
	probe._restore_foundation_lifecycle_snapshot(settled)
	probe.message_label.text = "Before the final interrogation answer."
	var saves: RecordingSaveService = probe.save_service
	# Setup may itself legitimately queue a save. Settle it normally before
	# seeding the measured generation; do not relabel setup work as rejected work.
	var setup_deadline := Time.get_ticks_msec() + 5000
	while (probe.pending_autosave or saves.async_save_in_flight()) and Time.get_ticks_msec() < setup_deadline:
		await tree.process_frame
		probe._flush_pending_autosave_if_ready()
	if probe.pending_autosave or saves.async_save_in_flight():
		failures.append("%s: setup autosave did not quiesce." % label)
		probe.free()
		return result
	var seed_error := saves.save_run(probe.run_state, probe.autosave_slot_id)
	if not popup_ok or seed_error != OK:
		failures.append("%s: actual showdown popup or owned baseline save failed setup." % label)
		result["popup_ok"] = popup_ok
		result["baseline_save_error"] = seed_error
		probe.free()
		return result
	_reset_counters(probe, saves)
	probe.fail_duel_factory = reject
	var source_run := probe.run_state
	var before_state := _full_state(probe)
	var before_bytes := var_to_bytes(before_state)
	var before_ui := _ui_state(probe)
	var files_before := _save_files(saves, probe.autosave_slot_id)
	result["setup_ok"] = true
	result["before_sha256"] = before_bytes.hex_encode().sha256_text()
	result["before_interrogation_beat"] = int(source_run.narrative_flags.get("grand_casino_showdown_interrogation_beat", -1))
	var accepted := false
	var event_result: Dictionary = {}
	if owner == "direct":
		event_result = probe.resolve_event_choice(EVENT_ID, "hold_steady")
		accepted = bool(event_result.get("ok", false))
	else:
		accepted = probe.activate_event_choice_action(EVENT_ID, "hold_steady")
	var immediate_state := _full_state(probe)
	var immediate_ui := _ui_state(probe)
	var immediate_files := _save_files(saves, probe.autosave_slot_id)
	var requests_at_return := _counter_state(probe, saves)
	var checks: Dictionary = result["checks"]
	checks["same_run_reference"] = probe.run_state == source_run
	checks["return_matches_case"] = accepted == (not reject)
	checks["no_synchronous_write_during_action"] = saves.synchronous_writes == 0 and saves.async_starts == 0
	checks["installed_bytes_unchanged_at_return"] = immediate_files == files_before
	if reject:
		checks["real_late_surface_lookup_reached"] = probe.factory_rejection_count == 1 and bool(probe.factory_rejection_context.get("duel_active", false)) and str(probe.factory_rejection_context.get("archetype_id", "")) == RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID and str(probe.factory_rejection_context.get("game_id", "")) == "blackjack"
		checks["full_lifecycle_state_restored"] = var_to_bytes(immediate_state) == before_bytes
		checks["actual_ui_restored"] = var_to_bytes(immediate_ui) == var_to_bytes(before_ui)
		checks["one_terminal_error"] = probe.message_log.count(ERROR_TEXT) == 1 and probe.message_log.back() == ERROR_TEXT and probe.message_label.text == ERROR_TEXT
		checks["no_success_message"] = probe.message_log.size() == (1 if owner == "direct" else 2)
		checks["no_success_publication"] = probe.item_publications == 0 and probe.conclusion_publications == 0
		checks["no_autosave_requested_prepared_or_queued"] = probe.autosave_requests == 0 and probe.save_preparations == 0 and probe.save_queues == 0
		if owner == "direct":
			checks["direct_error_result"] = event_result.get("errors", []) == [ERROR_TEXT]
	else:
		var surface: Dictionary = probe.current_game.surface_state(probe.run_state, probe.run_state.current_environment, probe.game_surface_ui_state) if probe.current_game != null else {}
		result["success_surface"] = surface
		checks["actual_duel_surface_entered"] = probe.current_screen == FoundationMain.SCREEN_GAME and probe.current_game != null and probe.current_game.get_id() == "blackjack" and bool(surface.get("boss_duel_active", false)) and str(surface.get("dealer_name", "")) == "Rourke"
		checks["no_injected_rejection"] = probe.factory_rejection_count == 0
		checks["success_autosave_queued"] = probe.autosave_requests > 0 and probe.save_preparations > 0 and probe.save_queues > 0 and probe.pending_autosave
	result["accepted"] = accepted
	result["event_result"] = event_result
	result["messages"] = probe.message_log.duplicate()
	result["failure_injection"] = probe.factory_rejection_context.duplicate(true)
	result["immediate_counters"] = requests_at_return
	result["immediate_state_diff"] = _diff_paths(before_state, immediate_state)
	result["immediate_ui_diff"] = _diff_paths(before_ui, immediate_ui)
	result["files_before"] = files_before
	result["files_at_return"] = immediate_files
	# Preserve ordinary one-frame/debounce scheduling. Drive only the real flush
	# and worker poll, never force-save the rejected result. This phase also proves
	# whether a queued generation actually installs, independently of invocation.
	var deadline := Time.get_ticks_msec() + 5000
	var waited_frames := 0
	while waited_frames < 3 or ((probe.pending_autosave or saves.async_save_in_flight()) and Time.get_ticks_msec() < deadline):
		await tree.process_frame
		waited_frames += 1
		probe._flush_pending_autosave_if_ready()
	checks["owned_save_worker_quiesced"] = not saves.async_save_in_flight() and not probe.pending_autosave
	var files_after := _save_files(saves, probe.autosave_slot_id)
	var loaded: RunState = saves.load_run(probe.autosave_slot_id)
	checks["owned_slot_still_loadable"] = loaded != null
	if reject:
		checks["installed_bytes_unchanged_after_natural_flush"] = files_after == files_before
		checks["no_save_worker_started"] = saves.async_starts == 0 and saves.synchronous_writes == 0
	else:
		checks["actual_success_generation_installed"] = saves.async_starts > 0 and files_after != files_before and loaded != null and loaded.grand_casino_duel_active(loaded.current_environment)
	result["files_after_natural_flush"] = files_after
	result["final_counters"] = _counter_state(probe, saves)
	result["flush_frames"] = waited_frames
	result["loaded_showdown_step"] = str(loaded.narrative_flags.get("grand_casino_showdown_step", "")) if loaded != null else ""
	result["loaded_archetype_id"] = str(loaded.current_environment.get("archetype_id", "")) if loaded != null else ""
	result["loaded_duel_active"] = loaded.grand_casino_duel_active(loaded.current_environment) if loaded != null else false
	for key in checks:
		if not bool(checks[key]): failures.append("%s: %s" % [label, key])
	result["passed"] = true
	for key in checks:
		if not bool(checks[key]): result["passed"] = false
	probe.free()
	return result

func _install_ui(probe: DuelProbe) -> void:
	probe.message_label = Label.new()
	probe.add_child(probe.message_label)
	probe.environment_canvas = PixelSceneCanvasScript.new()
	probe.environment_canvas.size = probe.size
	probe.add_child(probe.environment_canvas)
	probe.environment_canvas.render_environment_snapshot(probe.run_state.current_environment.duplicate(true))
	probe.game_surface_canvas = GameSurfaceCanvasScript.new()
	probe.game_surface_canvas.size = probe.size
	probe.add_child(probe.game_surface_canvas)
	probe.game_surface_canvas.render_game_snapshot({"game_id": "blackjack", "surface_time_msec": 2100.0, "reduce_motion": false})
	probe.talk_dock = TalkDockScript.new()
	probe.add_child(probe.talk_dock)
	probe.talk_dock.choice_requested.connect(Callable(probe, "_on_talk_dock_choice_requested"))
	probe.talk_dock.occupied_rect_changed.connect(Callable(probe, "_on_talk_dock_occupied_rect_changed"))
	probe.talk_dock.conversation_active_changed.connect(Callable(probe, "_on_talk_dock_conversation_active_changed"))
	probe.coach_overlay = CoachOverlayScript.new()
	probe.add_child(probe.coach_overlay)
	probe.coach_overlay.set_lessons(probe.library.tutorial_lessons)
	var dialogue: Dictionary = probe.library.dialogue("pull_tab_clerk")
	probe.run_state.enqueue_dialogue("pull_tab_clerk", "duel010:before-final-answer", dialogue.get("speaker", {}), "greeting", "dialogue", {"source": "dialogue"})
	probe._refresh_talk_dock()
	probe.talk_dock._complete_body_reveal()

func _reset_counters(probe: DuelProbe, saves: RecordingSaveService) -> void:
	probe.message_log.clear()
	probe.autosave_requests = 0
	probe.save_preparations = 0
	probe.save_queues = 0
	probe.save_flush_attempts = 0
	probe.item_publications = 0
	probe.conclusion_publications = 0
	probe.broad_refresh_count = 0
	saves.synchronous_writes = 0
	saves.async_starts = 0

func _counter_state(probe: DuelProbe, saves: RecordingSaveService) -> Dictionary:
	return {"requests": probe.autosave_requests, "preparations": probe.save_preparations, "queues": probe.save_queues, "write_attempts": probe.save_flush_attempts, "async_starts": saves.async_starts, "synchronous_writes": saves.synchronous_writes, "pending": probe.pending_autosave, "dirty_generation": probe.autosave_dirty_generation, "inflight_generation": probe.autosave_inflight_generation, "completed_generation": probe.autosave_completed_generation, "item_publications": probe.item_publications, "conclusion_publications": probe.conclusion_publications, "broad_refreshes": probe.broad_refresh_count}

func _save_files(saves: RecordingSaveService, slot: String) -> Dictionary:
	var result := {}
	for path in [saves.run_save_path(slot), saves.backup_save_path(slot)]:
		result[path] = {"exists": FileAccess.file_exists(path), "sha256": FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""}
	return result

func _full_state(probe: DuelProbe) -> Dictionary:
	return _freeze({"lifecycle": probe._foundation_lifecycle_snapshot(), "run_dict": probe.run_state.to_dict(), "ui": _ui_state(probe)})

func _ui_state(probe: DuelProbe) -> Dictionary:
	# Error copy has its own exact assertion; it is the intentional visible change.
	return _freeze({"popup_visible": probe.event_choice_popup_overlay.visible, "popup_title": probe.event_choice_popup_title_label.text, "popup_summary": probe.event_choice_popup_summary_label.text, "popup_choices": _control_tree(probe.event_choice_popup_choices_list), "environment_canvas": probe.environment_canvas.current_view_snapshot(), "game_canvas": probe.game_surface_canvas.current_view_snapshot()})

func _control_tree(node: Node) -> Dictionary:
	var result := {"class": node.get_class(), "children": []}
	if node is Control:
		result["visible"] = (node as Control).visible
		result["mouse_filter"] = (node as Control).mouse_filter
		result["position"] = (node as Control).position
		result["size"] = (node as Control).size
	if node is Label: result["text"] = (node as Label).text
	if node is BaseButton:
		result["disabled"] = (node as BaseButton).disabled
		if node is Button: result["text"] = (node as Button).text
	for child in node.get_children(): result["children"].append(_control_tree(child))
	return result

func _freeze(value: Variant) -> Variant:
	if value is Object:
		return {"_object_id": (value as Object).get_instance_id() if is_instance_valid(value) else 0, "_class": (value as Object).get_class() if is_instance_valid(value) else "freed"}
	if value is Dictionary:
		var result := {}
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key in keys: result[key] = _freeze(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value: result.append(_freeze(entry))
		return result
	return value

func _diff_paths(before: Variant, after: Variant, path: String = "") -> Array:
	var result: Array = []
	if typeof(before) != typeof(after): return [path + ":type"]
	if before is Dictionary:
		var keys: Array = before.keys()
		for key in after.keys():
			if not keys.has(key): keys.append(key)
		for key in keys:
			var child_path := "%s/%s" % [path, str(key)]
			if not before.has(key) or not after.has(key): result.append(child_path + ":presence")
			else: result.append_array(_diff_paths(before[key], after[key], child_path))
	elif before is Array:
		if before.size() != after.size(): result.append(path + ":size")
		for index in mini(before.size(), after.size()): result.append_array(_diff_paths(before[index], after[index], "%s/%d" % [path, index]))
	elif before != after: result.append(path)
	return result
