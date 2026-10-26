extends SceneTree

# Synthetic presentation fixture. Actual captured-save renderer dispatch is
# qualified separately; this test never loads a player save or changes economy.
class FixtureHost:
	extends "res://scripts/ui/foundation_main.gd"
	var prior_result := {"message":"Prior travel cost 60.","outcome_bankroll_delta":-60,"suspicion_delta":-2}
	func _recent_result_snapshot() -> Dictionary:return prior_result.duplicate(true)
	func _current_game_embeds_result_feedback() -> bool:return false
	func _refresh() -> void:pass

var checks := 0
var failures: Array[String]=[]

func _initialize() -> void:
	var host := FixtureHost.new()
	host.TerminalConsequenceViewModelScript=preload("res://scripts/ui/terminal_consequence_view_model.gd")
	host.run_state=RunState.new()
	host.run_state.bankroll=121
	host.run_state.grand_casino_chips=19
	host.message_label=Label.new()
	host.message_label.visible=false
	var before := var_to_bytes(host.run_state.to_dict())
	var prior := host.prior_result.duplicate(true)
	var expected := "The host desk points you toward Linda's barred counter in the Cage."
	_check(host._inspect_casino_fixture({"source_id":"host_desk"}),"Host Desk Inspect succeeds")
	var view: Dictionary=host._environment_result_feedback_view()
	_check(bool(view.get("visible",false)) and str(view.get("message",""))==expected,"Inspect guidance reaches the visible environment Result contract")
	_check(int(view.get("bankroll_delta",-1))==0 and int(view.get("suspicion_delta",-1))==0,"Informational inspection cannot replay prior travel money/heat deltas")
	_check((view.get("result",{}) as Dictionary).is_empty(),"Inspection presentation does not retain the prior money-bearing result")
	_check(host.message_label.text==expected and not host.message_label.visible,"Legacy label may stay hidden while the public acknowledgement remains available")
	_check(var_to_bytes(host.run_state.to_dict())==before,"Inspection preserves full run state, wallet, inventory and RNG")
	_check(host.prior_result==prior,"Prior outcome/history remains immutable")
	host._inspect_casino_fixture({"source_id":"host_desk"})
	_check(host._environment_result_feedback_view()==view and var_to_bytes(host.run_state.to_dict())==before,"Repeated read-only inspection is idempotent")
	host.message_label.free();host.message_label=null;host.free()
	for failure in failures:push_error(failure)
	print("CASINO_FIXTURE_INSPECTION_FEEDBACK checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
