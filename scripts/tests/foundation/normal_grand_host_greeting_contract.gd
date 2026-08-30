extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const TALK_EVENT_ID := "dialogue:normal_grand_host_greeting"


func _init() -> void:
	var failures: Array[String] = []
	var library = ContentLibraryScript.new()
	library.load(true)
	var host = FoundationMainScript.new()
	host.set("library", library)

	var minimal_run := _normal_run({"id": "minimal_grand", "archetype_id": RunStateScript.GRAND_CASINO_ARCHETYPE_ID})
	host.set("run_state", minimal_run)
	if not bool(host.call("_enqueue_normal_grand_host_greeting_without_refresh")):
		failures.append("Fixed Host enqueue rejected an active minimal Grand room.")
	var direct_entry: Dictionary = minimal_run.pending_talk_event(TALK_EVENT_ID)
	if minimal_run.is_terminal() or bool(minimal_run.narrative_flags.get("grand_host_greeting_seen", false)) or str(direct_entry.get("dialogue_id", "")) != "normal_grand_host_greeting":
		failures.append("Direct Host enqueue changed terminal/seen authority or lost the fixed dialogue.")
	host.call("_queue_normal_grand_host_greeting", {"id": "previous_bar", "archetype_id": "bar"})
	if not bool(minimal_run.narrative_flags.get("grand_host_greeting_seen", false)) or minimal_run.pending_talk_event_count() != 1:
		failures.append("Identical pending Host greeting was not accepted idempotently.")
	host.call("_queue_normal_grand_host_greeting", {"id": "previous_bar_again", "archetype_id": "bar"})
	if minimal_run.pending_talk_event_count() != 1:
		failures.append("Second valid Host greeting call queued a duplicate.")

	var terminal_run := _normal_run({"id": "terminal_grand", "archetype_id": RunStateScript.GRAND_CASINO_ARCHETYPE_ID})
	terminal_run.run_status = RunStateScript.RUN_STATUS_FAILED
	host.set("run_state", terminal_run)
	host.call("_queue_normal_grand_host_greeting", {"id": "previous_bar", "archetype_id": "bar"})
	if terminal_run.pending_talk_event_count() != 0 or bool(terminal_run.narrative_flags.get("grand_host_greeting_seen", false)):
		failures.append("Terminal Host enqueue consumed the one-time greeting authority.")

	var invalid_run := _normal_run({"id": "invalid_grand", "archetype_id": RunStateScript.GRAND_CASINO_ARCHETYPE_ID})
	host.set("run_state", invalid_run)
	host.set("library", ContentLibraryScript.new())
	host.call("_queue_normal_grand_host_greeting", {"id": "previous_bar", "archetype_id": "bar"})
	if invalid_run.pending_talk_event_count() != 0 or bool(invalid_run.narrative_flags.get("grand_host_greeting_seen", false)):
		failures.append("Unavailable Host dialogue consumed the one-time greeting authority.")

	host.set("library", library)
	var travel_run := RunStateScript.new()
	travel_run.start_new("GRAND-HOST-TRAVEL-ORDER")
	var grand_environment := EnvironmentInstanceScript.from_archetype(library.environment_archetype(RunStateScript.GRAND_CASINO_ARCHETYPE_ID), 3, travel_run.create_rng("grand_arrival"), library).to_dict()
	travel_run.set_environment(grand_environment)
	host.set("run_state", travel_run)
	host.call("_queue_normal_grand_host_greeting", {"id": "travel_bar", "archetype_id": "bar"})
	var travel_entry := travel_run.pending_talk_event(TALK_EVENT_ID)
	var travel_context: Dictionary = travel_entry.get("context", {}) if typeof(travel_entry.get("context", {})) == TYPE_DICTIONARY else {}
	var travel_speaker: Dictionary = travel_entry.get("speaker", {}) if typeof(travel_entry.get("speaker", {})) == TYPE_DICTIONARY else {}
	if travel_run.is_terminal() or str(travel_context.get("source", "")) != "grand_casino_entry" or str(travel_context.get("source_object_id", "")) != "casino_fixture:host_desk" or str(travel_speaker.get("character_id", "")) != "vivienne_grand_host":
		failures.append("Production Grand arrival lost the fixed Host source/speaker resolution.")
	var source := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	var queue_at := source.find("\t_queue_normal_grand_host_greeting(previous_environment)")
	var triggered_at := source.find("\tvar travel_context := {", queue_at)
	var caller_refresh_at := source.find("\t\t\t_refresh()", triggered_at)
	if queue_at < 0 or triggered_at <= queue_at or caller_refresh_at <= triggered_at:
		failures.append("Travel no longer queues the Host greeting before triggered events and the caller-owned refresh.")

	host.free()
	if failures.is_empty():
		print("NORMAL_GRAND_HOST_GREETING PASS minimal_active=1 idempotent=1 terminal_rejected=1 invalid_rejected=1 travel_order=1")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _normal_run(environment: Dictionary) -> RunState:
	var run := RunStateScript.new()
	run.start_new("GRAND-HOST-MINIMAL")
	run.current_environment = environment.duplicate(true)
	return run
