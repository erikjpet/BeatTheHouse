extends SceneTree

const Main := preload("res://scripts/ui/foundation_main.gd")
const Dock := preload("res://scripts/ui/talk_dock.gd")
const Library := preload("res://scripts/core/content_library.gd")
const TERMS := "Mags at the Corner Store: Day 2, 14:00-16:00."
const FULL_TERMS := TERMS + " Missing the window loses the package and payment, reduces Crew trust by 5 and adds 9 Heat.\nOn delivery: Bankroll +22, heat +4"

# The route provider alone is deterministic. Queue normalization, conditions,
# EventModule, the Main cache, the action view model and TalkDock are real.
# This is an explicitly synthetic old-entry shape, not the original R02 save.
class PreviewRun extends RunState:
	var preview_calls: Array = []
	func delivery_crew_offer(definition_id: String, offered_clock: int = -1) -> Dictionary:
		preview_calls.append([definition_id, offered_clock])
		return {"ok": true, "message": TERMS}

var checks := 0
var failures: Array[String] = []
var observations: Array = []
var requests: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _settle() -> void:
	for _frame in range(4):
		await process_frame


func _fixture(post_miss: bool) -> PreviewRun:
	var run := PreviewRun.new()
	run.start_new("BTH-30-SYNTHETIC-PENDING-PROJECTION")
	run.game_clock_minutes = 2250
	run.narrative_flags["crew_delivery_obligations"] = 2
	run.narrative_flags["crew_favor_pending"] = true
	if post_miss:
		run.narrative_flags["crew_delivery_post_miss"] = true
	run.current_environment = {
		"id": "synthetic_terms_room", "world_node_id": "gas_station_casino",
		"kind": "casino", "tier": 1, "turns": 3,
		"lender_hooks": ["the_crew"], "event_ids": [], "game_states": {},
	}
	# Persisted entries store identity/context, not projected choice metadata.
	# Install the already-pending synthetic shape; never enqueue/reroll an offer.
	run.pending_triggered_events = [run._normalize_triggered_event_entry({
		"event_id": "crew_favor_delivery", "source": "debt", "context": {},
		"environment_id": "synthetic_terms_room", "environment_turns": 3,
		"presentation": "talk", "speaker": {"name": "Velvet", "voice_line": "A quiet favour."},
	})]
	return run


func _choice(option: Dictionary, id: String) -> Dictionary:
	for value in option.get("choices", []):
		if value is Dictionary and str(value.get("id", "")) == id:
			return value
	return {}


func _button(dock: Dock, id: String) -> Button:
	for response in dock.choice_list.get_children():
		for control in response.get_children():
			if control is Button and str(control.get_meta("choice_id", "")) == id:
				return control
	return null


func _case(content: ContentLibrary, post_miss: bool, hydrate: bool) -> void:
	var run := _fixture(post_miss)
	var pending_before := var_to_bytes(run.pending_triggered_events)
	if hydrate:
		var saved_shape := run.to_dict()
		_check(not JSON.stringify(saved_shape.get("pending_triggered_events", [])).contains("package_offer_terms"), "old saved entry has no new preview metadata")
		var restored := PreviewRun.new()
		restored.from_dict(saved_shape)
		run = restored
	_check(var_to_bytes(run.pending_triggered_events) == pending_before, "hydration preserves the pending identity/context bytes")
	_check(run.crew_delivery_request_context_valid() and run.triggered_event_pending("crew_favor_delivery"), "synthetic pending request satisfies real eligibility")
	var host := Main.new()
	host.run_state = run
	host.library = content
	host.continuous_environment_clock_enabled = false
	host.script_prewarm_stopping = true
	var dependencies_ready: bool = host._ensure_run_ui_stage_scripts(0)
	_check(dependencies_ready, "Main loads real run-UI dependencies before projecting choices")
	if not dependencies_ready:
		host.free()
		return
	var dock := Dock.new()
	root.add_child(dock)
	dock.size = Vector2(1280, 720)
	dock.set_reduce_motion(true)
	host.talk_dock = dock
	requests.clear()
	dock.choice_requested.connect(func(event_id, choice_id): requests.append([event_id, choice_id]))
	var before := var_to_bytes(run.to_dict())
	if hydrate:
		_check(host.crew_delivery_event_modules.is_empty(), "fresh hydrated host starts with no primed offer cache")
		host._refresh_talk_dock()
		await _settle()
		_check(dock.package_terms_scroll.is_visible_in_tree(), "cold Main-first refresh exposes terms without producer priming")
		_check(dock.package_terms_label.text.contains(FULL_TERMS), "cold Main-first refresh receives complete original preview")
		_check(var_to_bytes(run.to_dict()) == before, "cold Main-first refresh preserves all serialized state")
	var event_module: EventModule = host._crew_delivery_event_module(content.event("crew_favor_delivery"))
	var raw_choices := event_module.choice_views(run, run.current_environment)
	var id := "run_package_after_miss" if post_miss else "run_package"
	var raw := _choice({"choices": raw_choices}, id)
	_check(raw.get("package_offer_terms", "") == FULL_TERMS, "existing producer supplies complete exact terms")
	var projected: Dictionary = host._eligible_event_option_with_context("crew_favor_delivery", {}, run.current_environment)
	var projected_choice := _choice(projected, id)
	_check(projected_choice.get("package_offer_terms", "") == raw.get("package_offer_terms", ""), "real action view model forwards producer terms byte-exact")
	_check(projected_choice.get("text", "") == raw.get("text", ""), "existing displayed text stays exact")
	_check(projected_choice.get("consequences", {}) == raw.get("consequences", {}), "projection changes no consequence instructions")
	_check(projected_choice.get("check", {}) == raw.get("check", {}), "projection changes no check instructions")
	var refused_id := "refuse_after_miss" if post_miss else "refuse"
	_check(not _choice(projected, refused_id).has("package_offer_terms"), "ordinary response gains no package panel metadata")
	_check(event_module._crew_offer_clock == 2250, "existing quote cache keeps original offered clock")
	_check(host._crew_delivery_event_module(content.event("crew_favor_delivery")) == event_module, "projection reuses the existing offer module")
	host._refresh_talk_dock()
	await _settle()
	_check(dock.visible and dock.package_terms_scroll.is_visible_in_tree(), "actual Main refresh opens terms for already-pending entry")
	_check(dock.package_terms_label.text.contains(FULL_TERMS), "actual TalkDock receives destination/window/all penalties")
	_check(_choice(dock.option, id).get("package_offer_terms", "") == FULL_TERMS, "Main summary/voice projection retains explicit terms")
	_check(not dock.body_label.visible, "package panel replaces duplicate generic body")
	_check(dock.panel.get_global_rect().encloses(dock.package_terms_scroll.get_global_rect()), "real projected terms viewport stays inside panel")
	var button := _button(dock, id)
	_check(button != null, "real projected acceptance control exists")
	if button != null:
		dock.package_terms_scroll.ensure_control_visible(button)
		await _settle()
		button.pressed.emit()
		await _settle()
		_check(dock.armed_choice_id == id and requests.is_empty(), "first connected press arms only, no choice request")
		_check(dock.package_terms_label.text.contains(FULL_TERMS), "real projected terms remain when armed")
	_check(var_to_bytes(run.pending_triggered_events) == pending_before, "reading/arming neither completes nor recreates pending offer")
	_check(var_to_bytes(run.to_dict()) == before, "full serialized finance/clock/history/jobs/RNG remains byte-exact")
	_check(run.preview_calls.all(func(item): return item == ["crew_favor_delivery", 2250]), "all existing read-only preview calls keep same original clock")
	observations.append({"post_miss": post_miss, "hydrated_old_entry_shape": hydrate,
		"panel_visible": dock.package_terms_scroll.visible, "full_terms": dock.package_terms_label.text,
		"preview_calls": run.preview_calls.duplicate(true), "choice_requests": requests.duplicate(true)})
	host.talk_dock = null
	host.free()
	dock.queue_free()
	await process_frame


func _run() -> void:
	var private_root := OS.get_environment("BTH_PACKAGE_PROJECTION_ROOT")
	if private_root.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(private_root + "/"):
		push_error("Fresh explicit synthetic isolation root required; no profile/key copy.")
		quit(2)
		return
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var content := Library.new()
	content.load()
	var mode := OS.get_environment("BTH_PACKAGE_PROJECTION_CASE")
	if mode == "warm" or mode == "hydrated":
		await _case(content, false, mode == "hydrated")
		await _case(content, true, mode == "hydrated")
	else:
		_check(false, "explicit warm/hydrated mode required")
	var result := {"task_id": "BTH-30", "checks": checks, "failures": failures, "mode": mode,
		"observations": observations,
		"fidelity": "Actual EventModule, action-view projection, Main refresh and TalkDock; deterministic synthetic route provider and already-pending old-entry fixture. Hydrated mode uses ordinary from_dict on synthetic save-shaped data, not disk Save/fresh-process Continue or original R02. No job acceptance, clock advancement, payment, offer reroll, or existing profile/key access."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("CREW_PACKAGE_TERMS_PROJECTION ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
