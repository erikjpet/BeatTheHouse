extends SceneTree

const Heist := preload("res://scripts/core/crew_heist_model.gd")
class WatchedRun extends RunState:
	var premature_failures := 0
	func fail_run(reason: String, message: String = "") -> void:
		premature_failures += 1
		super.fail_run(reason, message)

var checks := 0
var failures: Array[String] = []
var observations: Array = []

func _init() -> void: call_deferred("_run")

func _fixture(plan: String, cash: int) -> RunState:
	var run := WatchedRun.new()
	run.start_new("AUD061-10-" + plan)
	run.crew_change_reputation(0)
	run.change_bankroll(cash - run.bankroll, true)
	run.crew_heist_state = Heist.begin(plan, 0)
	return run

func _run() -> void:
	var run := _fixture(Heist.PLAN_COUNT, 60)
	var result := run.crew_heist_abort("retreated", run._crew_heist_host_capability)
	observations.append({"case":"abort", "result":result, "cash":run.bankroll, "economy":run.economic_state})
	_check(bool(result.get("ok", false)) and run.bankroll == 60 - int(result.get("cost", -1)), "abort pays its existing capped cost")
	_check(run.economic_state == "volatile", "abort immediately refreshes economy")
	_check(run.run_status == RunState.RUN_STATUS_ACTIVE, "abort keeps run active")

	run = _fixture(Heist.PLAN_WHALE, 1)
	run.crew_heist_state.status = Heist.STATUS_PLAY
	run.crew_heist_state.play = {"round":3, "score":100, "decisions":{}, "pot":650}
	run.grand_casino_chips = 650
	result = run._crew_heist_finish_whale_exposure(run.crew_heist_state, 1, {"h":true})
	observations.append({"case":"whale", "result":result, "cash":run.bankroll, "economy":run.economic_state})
	_check(bool(result.get("ok", false)) and run.bankroll == 1 + int(result.get("payout", -1)) and run.grand_casino_chips == 0, "Whale pays exact existing partial payout and clears chips")
	_check(run.economic_state == "growing", "Whale immediately refreshes economy")

	run = _fixture(Heist.PLAN_COUNT, 1)
	run.crew_heist_state.status = Heist.STATUS_GETAWAY
	run.crew_heist_state.play = {"round":3, "score":68, "decisions":{}, "pot":650}
	var expected := Heist.payout_for(run.crew_heist_state, Heist.ladder(68, false))
	var ok := run._crew_heist_apply_delivery_resolution("heist:the_count:getaway", false, {"outcome":"failed"})
	observations.append({"case":"getaway", "ok":ok, "cash":run.bankroll, "economy":run.economic_state, "expected_payout":expected})
	_check(ok and run.bankroll == 1 + expected, "getaway pays exact existing amount")
	_check(run.economic_state == "growing", "getaway immediately refreshes economy")

	for boundary in ["whale", "getaway"]:
		run = _fixture(Heist.PLAN_WHALE, 0)
		run.crew_heist_state.status = Heist.STATUS_GETAWAY
		run.crew_heist_state.play = {"round":3, "score":0, "bust":true, "decisions":{}, "pot":0}
		run.crew_heist_state.x.m = "crew_rook"
		if boundary == "whale": result = run._crew_heist_finish_whale_exposure(run.crew_heist_state, 1, {"h":false})
		else: run._crew_heist_apply_delivery_resolution("heist:the_whale_game:getaway", false, {})
		observations.append({"case":boundary + "_zero", "cash":run.bankroll, "economy":run.economic_state, "status":run.run_status, "premature_failures":run.get("premature_failures")})
		_check(int(run.get("premature_failures")) == 0, boundary + " zero payout never invokes early fail_run")
		_check(run.bankroll == 0 and run.economic_state == "insolvent", boundary + " zero payout remains insolvent")
		_check(run.run_status == RunState.RUN_STATUS_ENDED and not run.story_log.any(func(row): return row.get("type") == "run_failed"), boundary + " zero payout reaches existing ending without early bankroll failure")
	print("AUD061_CREW_BANKROLL " + JSON.stringify({"checks":checks, "failures":failures, "observations":observations}))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("AUD061-10: " + label)
