extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")

const EVENT_ID := "dave_bus_warning"
const SEEN_FLAG := "dave_bus_warning_seen"
const DAVE_LINE := "Seek out the cruel and unusual."


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	if not library.validation_errors.is_empty():
		failures.append("Content validation failed: %s" % "; ".join(library.validation_errors))
	_check_authored_contract(library, failures)
	_check_method_normalization(failures)
	_check_context_eligibility(library, failures)
	await _check_ui_queue_resolution_and_save(library, failures)
	if not failures.is_empty():
		for failure_value in failures:
			push_error(str(failure_value))
		quit(1)
		return
	print("DAVE_BUS_ENCOUNTER_CHECK: PASS")
	quit(0)


func _check_authored_contract(library: ContentLibrary, failures: Array) -> void:
	var definition := library.event(EVENT_ID)
	if definition.is_empty():
		failures.append("Dave bus event is missing.")
		return
	var speaker: Dictionary = definition.get("speaker", {})
	var payload: Dictionary = definition.get("payload", {})
	var choices: Array = payload.get("choices", [])
	if str(definition.get("presentation", "")) != "talk" or str(speaker.get("name", "")) != "Dave":
		failures.append("Dave event does not use the existing talk presentation with Dave as speaker.")
	if str(payload.get("summary", "")) != DAVE_LINE:
		failures.append("Dave event does not contain the exact required sentence.")
	if choices.size() != 1 or str((choices[0] as Dictionary).get("id", "")) != "acknowledge":
		failures.append("Dave event must expose exactly one acknowledgement choice.")
	if not choices.is_empty():
		var consequences: Dictionary = (choices[0] as Dictionary).get("consequences", {})
		for forbidden_key in ["bankroll_delta", "suspicion_delta", "inventory_add", "inventory_remove", "debt", "debt_changes"]:
			if consequences.has(forbidden_key):
				failures.append("Dave acknowledgement invents a reward or penalty: %s." % forbidden_key)


func _check_method_normalization(failures: Array) -> void:
	var fixtures := [
		[{"distance": "near"}, "walk", "Walk"],
		[{"distance": "local"}, "bus", "Bus ticket"],
		[{"distance": "far"}, "taxi", "Taxi ride"],
		[{"distance": "remote"}, "night_cab", "Night cab"],
		[{"travel_method": "Bus ticket", "distance": "near"}, "bus", "Bus ticket"],
	]
	for fixture_value in fixtures:
		var fixture: Array = fixture_value
		var kind := WorldMapScript.travel_method_kind(fixture[0])
		var label := WorldMapScript.travel_method_label(kind)
		if kind != str(fixture[1]) or label != str(fixture[2]):
			failures.append("Travel method normalization mismatch for %s: %s / %s." % [JSON.stringify(fixture[0]), kind, label])


func _check_context_eligibility(library: ContentLibrary, failures: Array) -> void:
	var definition := library.event(EVENT_ID)
	for kind in ["walk", "bus", "taxi", "night_cab"]:
		var state: RunState = RunStateScript.new()
		state.start_new("DAVE-CONTEXT-%s" % kind)
		state.set_environment(_fixture_environment())
		var event_module: EventModule = EventModuleScript.new()
		event_module.setup(definition, library)
		var eligible := event_module.can_trigger(state, state.current_environment, {
			"trigger": "travel",
			"type": "travel",
			"source": "travel",
			"travel_method_kind": kind,
		})
		if eligible != (kind == "bus"):
			failures.append("Dave eligibility for %s was %s." % [kind, str(eligible)])


func _check_ui_queue_resolution_and_save(_library: ContentLibrary, failures: Array) -> void:
	var app: Control = MainScene.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.call("start_foundation_run", "DAVE-BUS-UI")
	await process_frame
	var state: RunState = app.get("run_state")
	if state == null:
		failures.append("Dave UI fixture could not start a run.")
		app.queue_free()
		return
	state.set_environment(_fixture_environment())
	state.event_cadence["visit_should_fire"] = false
	state.event_cadence["last_modal_closed_action"] = int(state.event_cadence.get("action_index", 0))
	state.enqueue_triggered_event("family_loan", "fixture_modal", {}, {"presentation": "modal"})
	state.begin_triggered_event_resolution(state.next_pending_triggered_event())
	var context := {
		"trigger": "travel",
		"type": "travel",
		"source": "travel",
		"target_id": "bar",
		"travel_method_kind": "bus",
		"travel_method": "Bus ticket",
	}
	if not bool(app.call("_enqueue_triggered_events_for_context", "travel", context, state.current_environment)):
		failures.append("First bus ride did not deterministically queue Dave while another modal was active.")
	var queued := state.pending_talk_event(EVENT_ID)
	if queued.is_empty() or str((queued.get("context", {}) as Dictionary).get("travel_method_kind", "")) != "bus":
		failures.append("Queued Dave encounter did not preserve canonical bus context.")
	var restored: RunState = RunStateScript.new()
	restored.from_dict(state.to_dict())
	if restored.pending_talk_event(EVENT_ID).is_empty() or str(restored.active_triggered_event.get("event_id", "")) != "family_loan":
		failures.append("Save/load did not preserve the queued Dave encounter and active modal.")
	state.complete_triggered_event_resolution("family_loan")
	app.call("_refresh_talk_dock")
	await process_frame
	var talk: Dictionary = app.call("current_talk_dock_snapshot")
	if not bool(talk.get("visible", false)) or str(talk.get("event_id", "")) != EVENT_ID:
		failures.append("Dave did not become the next talk encounter after the modal cleared.")
	if str(talk.get("speaker", "")) != "Dave" or str(talk.get("summary", "")) != DAVE_LINE:
		failures.append("Dave talk presentation did not show his name and exact sentence: %s" % JSON.stringify(talk))
	var bankroll_before := state.bankroll
	var heat_before := state.suspicion_level()
	app.call("resolve_event_choice", EVENT_ID, "acknowledge")
	await process_frame
	if not bool(state.story_flags.get(SEEN_FLAG, false)):
		failures.append("Acknowledging Dave did not set the one-time seen flag.")
	if state.bankroll != bankroll_before or state.suspicion_level() != heat_before:
		failures.append("Acknowledging Dave changed bankroll or heat.")
	if not _has_dave_story_lead(state.story_log):
		failures.append("Acknowledging Dave did not write the followable story-log lead.")
	if bool(app.call("_enqueue_triggered_events_for_context", "travel", context, state.current_environment)) or not state.pending_talk_event(EVENT_ID).is_empty():
		failures.append("A second bus ride repeated Dave after acknowledgement.")
	var after_resolution: RunState = RunStateScript.new()
	after_resolution.from_dict(state.to_dict())
	if not bool(after_resolution.story_flags.get(SEEN_FLAG, false)) or not _has_dave_story_lead(after_resolution.story_log):
		failures.append("Dave's resolved one-time status did not survive save/load.")
	app.queue_free()
	await process_frame


func _has_dave_story_lead(entries: Array) -> bool:
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("type", "")) == "story_lead" and str(entry.get("event_id", "")) == EVENT_ID and str(entry.get("message", "")).contains(DAVE_LINE):
			return true
	return false


func _fixture_environment() -> Dictionary:
	return {
		"id": "dave_bus_fixture_room",
		"archetype_id": "bar",
		"display_name": "Bus Stop Bar",
		"kind": "bar",
		"tier": 1,
		"turns": 0,
		"event_ids": [],
		"resolved_event_ids": [],
		"next_archetypes": ["motel"],
		"travel_hooks": ["motel"],
		"layout": {},
	}
