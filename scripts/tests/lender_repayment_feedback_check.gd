extends SceneTree

# Focused synthetic presentation fixture. Captured-save pointer dispatch and
# actual Web repayment are qualified separately on disposable profiles.
class RepaymentHost:
	extends "res://scripts/ui/foundation_main.gd"
	var prior_result := {"message":"Borrow $28. Repay $31.","outcome_bankroll_delta":28,"suspicion_delta":-1}
	var save_requests := 0
	func _recent_result_snapshot() -> Dictionary:return prior_result.duplicate(true)
	func _current_game_embeds_result_feedback() -> bool:return false
	func _refresh() -> void:pass
	func _autosave_foundation_run(_status_text: String="Autosaved.",_force: bool=false) -> bool:
		save_requests+=1
		return true

var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	var host:=RepaymentHost.new()
	host.TerminalConsequenceViewModelScript=preload("res://scripts/ui/terminal_consequence_view_model.gd")
	host.run_state=RunState.new()
	host.run_state.current_environment={"id":"motel_feedback","archetype_id":"motel","lender_hooks":["motel_friend"]}
	host.run_state.bankroll=142
	host.run_state.rng_state=531239944
	host.run_state.debt=[{"id":"motel_friend_note","lender_id":"motel_friend","debt_kind":"cash","balance":31,"principal":28,"status":"active","turns_remaining":4}]
	host.message_label=Label.new();host.message_label.visible=false
	var prior:=host.prior_result.duplicate(true)
	var rng:=host.run_state.rng_state
	_check(host._execute_lender_repayment("motel_friend"),"Payable lender debt settles")
	var view: Dictionary=host._environment_result_feedback_view()
	_check(host.run_state.bankroll==111 and host.run_state.debt.is_empty(),"Exactly one payoff removes31 and retires the debt")
	_check(bool(view.get("visible",false)) and str(view.get("message",""))=="Paid off Motel Friend.","Visible Result shows the completed repayment")
	_check(int(view.get("bankroll_delta",-1))==0 and int(view.get("suspicion_delta",-1))==0,"Acknowledgement cannot replay prior borrowing money or heat")
	_check((view.get("result",{}) as Dictionary).is_empty(),"Repayment acknowledgement retires the old money-bearing presentation")
	_check(host.message_label.text==view.message and not host.message_label.visible,"Public feedback remains available while the legacy label is hidden")
	_check(host.prior_result==prior,"Borrowing history remains immutable")
	_check(host.run_state.rng_state==rng,"Repayment presentation does not consume RNG")
	_check(host.save_requests==1,"Accepted payoff requests its existing save once")
	var after:=var_to_bytes(host.run_state.to_dict())
	_check(not host._execute_lender_repayment("motel_friend"),"A duplicate payoff is rejected")
	_check(var_to_bytes(host.run_state.to_dict())==after and host.save_requests==1,"Rejected duplicate preserves state and does not request another save")
	host.run_state.bankroll=20
	host.run_state.debt=[{"id":"unaffordable","lender_id":"motel_friend","debt_kind":"cash","balance":31,"principal":28,"status":"active","turns_remaining":4}]
	var insufficient:=var_to_bytes(host.run_state.to_dict())
	_check(not host._execute_lender_repayment("motel_friend"),"Insufficient funds remain rejected")
	_check(var_to_bytes(host.run_state.to_dict())==insufficient and host.save_requests==1,"Unaffordable payoff preserves money/debt/RNG and save count")
	host.message_label.free();host.message_label=null;host.free()
	for failure in failures:push_error(failure)
	print("LENDER_REPAYMENT_FEEDBACK checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
