extends SceneTree

# Callback boundary unit tests. The checked turn executor is injected here;
# the separate actual Web-save host reproduction exercises real authority,
# normal turn application and Save/Continue without a synthetic player state.
class ClosingHost extends "res://scripts/ui/foundation_main.gd":
	var advances: Array[int] = []
	var reject_advance := false
	var saved := 0
	var maps := 0
	func _ready() -> void: set_process(false)
	func _advance_environment_turns_checked(amount: int = 1, _timing: Dictionary = {}) -> bool:
		advances.append(amount)
		if reject_advance: return false
		run_state._advance_travel_lock(amount)
		return true
	func _refresh_talk_dock() -> void: pass
	func _show_message(_text: String) -> void: pass
	func _autosave_foundation_run(_text: String = "Autosaved.", _force: bool = false) -> bool:
		saved += 1
		return true
	func open_world_map(_closing: bool = false, _recovery: bool = false) -> bool:
		maps += 1
		return true

var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text)
func _fixture(lock: int = 1, archetype: String = "delta_queen", source: String = "") -> ClosingHost:
	var host := ClosingHost.new()
	root.add_child(host)
	host.run_state = RunState.new()
	host.run_state.bankroll = 298
	host.run_state.rng_state = 12345
	host.run_state.current_environment = {"id":"closing_fixture", "world_node_id":"riverboat_casino", "archetype_id":archetype,"travel_locked_actions":lock,"travel_lock_remaining":lock,"travel_lock_source":source}
	host.run_state.begin_closing_time(host.run_state.current_environment, 240, 0)
	host.run_state.force_closing_time_travel()
	host.run_state.enqueue_dialogue(host.CLOSING_TIME_DIALOGUE_ID,host.CLOSING_TIME_TALK_EVENT_ID,{},"notice","closing_time")
	return host
func _respond(host) -> void:
	host._on_talk_dock_choice_requested(host.CLOSING_TIME_TALK_EVENT_ID,host.CLOSING_TIME_TALK_CHOICE_ID)
func _run() -> void:
	for remaining in [1,2]:
		var host := _fixture(remaining)
		_respond(host)
		_check(host.advances == [remaining] and host.run_state.current_travel_lock_remaining()==0,"Closing response did not serve the remaining ride beats through checked turns.")
		_check(host.run_state.pending_talk_event(host.CLOSING_TIME_TALK_EVENT_ID).is_empty() and host.saved==1,"Successful response did not complete and save once.")
		_respond(host)
		await process_frame
		_check(host.advances == [remaining] and host.saved==1 and host.maps==1,"Duplicate response advanced, saved or opened a second map.")
		_check(host.run_state.bankroll==298 and host.run_state.rng_state==12345,"Presentation callback directly charged or rerolled outside the checked executor.")
		host.free()
	for params in [[1,"bar",""],[1,"delta_queen","police_sweep"],[0,"delta_queen",""]]:
		var host := _fixture(params[0],params[1],params[2]);_respond(host);await process_frame
		_check(host.advances.is_empty() and host.run_state.current_travel_lock_remaining()==params[0],"Ordinary closing or independent sweep lock was altered.")
		_check(host.saved==1 and host.maps==1,"Existing ordinary departure behavior changed.")
		host.free()
	var failed := _fixture();failed.reject_advance=true;_respond(failed);await process_frame
	_check(failed.run_state.current_travel_lock_remaining()==1 and not failed.run_state.pending_talk_event(failed.CLOSING_TIME_TALK_EVENT_ID).is_empty(),"Rejected turn consumed its pending response or lock.")
	_check(failed.saved==0 and failed.maps==0,"Rejected turn published a save or departure map.")
	failed.reject_advance=false;_respond(failed);await process_frame
	_check(failed.run_state.current_travel_lock_remaining()==0 and failed.saved==1 and failed.maps==1,"A rejected docking wait could not be retried once.")
	failed.free()
	var invalid := _fixture();invalid._on_talk_dock_choice_requested(invalid.CLOSING_TIME_TALK_EVENT_ID,"wrong_choice");await process_frame
	_check(invalid.advances.is_empty() and invalid.saved==0 and not invalid.run_state.pending_talk_event(invalid.CLOSING_TIME_TALK_EVENT_ID).is_empty(),"Invalid response advanced or consumed the notice.")
	invalid.run_state.closing_time_state["environment_id"]="different_room";invalid.run_state.closing_time_state["world_node_id"]="different_node";_respond(invalid);await process_frame
	_check(invalid.advances.is_empty(),"Stale closing state advanced a different room.")
	invalid.free()
	for failure in failures: push_error(failure)
	print("Riverboat closing departure checks: ",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
