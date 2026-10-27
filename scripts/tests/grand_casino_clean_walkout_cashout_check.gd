extends SceneTree

const State := preload("res://scripts/core/run_state.gd")
const Duel := preload("res://scripts/core/grand_casino_duel_model.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _fixture(chips: int, marker: int = 0, rate: int = 1) -> RunState:
	var run := State.new()
	run.start_new("CLEAN-WALKOUT-CASHOUT")
	run.current_environment = {"id": "grand_casino_back_room", "archetype_id": "grand_casino_back_room", "local_narrative_flags": {"casino_chip_cash_rate": rate}}
	run.bankroll = 49
	run.grand_casino_chips = chips
	run._set_grand_casino_atm_debt(marker)
	run.narrative_flags["grand_casino_showdown_active"] = true
	return run

func _cashouts(run: RunState) -> Array:
	return run.story_log.filter(func(row): return row.get("type", "") == "grand_casino_chip_cashout")

func _run() -> void:
	for row in [{"chips":29,"debt":0,"rate":1,"cash":78,"remaining":0}, {"chips":29,"debt":20,"rate":1,"cash":58,"remaining":0}, {"chips":29,"debt":50,"rate":1,"cash":49,"remaining":21}, {"chips":29,"debt":20,"rate":2,"cash":87,"remaining":0}, {"chips":0,"debt":20,"rate":1,"cash":49,"remaining":20}]:
		var run := _fixture(row.chips, row.debt, row.rate)
		var rng := run.rng_state
		var complete := {"status":"complete", "outcome":Duel.OUTCOME_WALK_OUT_CLEAN, "player_stack":116, "rourke_stack":75, "margin":41, "hands":[]}
		run._finalize_grand_casino_duel_if_complete(complete)
		_expect(run.run_status == State.RUN_STATUS_ENDED, "clean ending completes after settlement")
		_expect(run.bankroll == row.cash and run.grand_casino_chips == 0 and run.grand_casino_atm_debt() == row.remaining, "cash/chips/marker agree with unchanged Cage arithmetic")
		_expect(int(run.narrative_flags.get("grand_casino_duel_cashed_chip_amount", -1)) == row.chips, "ending records redeemed chips")
		var receipts := _cashouts(run)
		_expect(receipts.size() == (1 if row.chips > 0 else 0), "exactly one receipt for positive conversion")
		if not receipts.is_empty():
			_expect(int(receipts[0].chips_redeemed) == row.chips and int(receipts[0].cash_paid) == row.cash - 49 and int(receipts[0].debt_remaining) == row.remaining, "receipt records actual conversion")
		var saved := JSON.stringify(run.to_dict())
		run._finalize_grand_casino_duel_if_complete(complete)
		_expect(JSON.stringify(run.to_dict()) == saved, "repeated finalization cannot duplicate payout or ending")
		_expect(run.rng_state == rng, "cashout spends no RNG")
	var wrong_room := _fixture(29)
	_expect(not bool(wrong_room.cash_out_grand_casino_chips().get("ok", true)) and wrong_room.bankroll == 49 and wrong_room.grand_casino_chips == 29, "ordinary redemption still requires Cage")
	wrong_room.current_environment["archetype_id"] = "grand_casino_cage"
	_expect(not bool(wrong_room.cash_out_grand_casino_chips().get("ok", true)), "ordinary Cage closed during non-clean active duel")
	wrong_room.narrative_flags["grand_casino_showdown_active"] = false
	_expect(bool(wrong_room.cash_out_grand_casino_chips(10).get("ok", false)) and wrong_room.bankroll == 59 and wrong_room.grand_casino_chips == 19, "ordinary partial Cage redemption unchanged")
	for outcome in [Duel.OUTCOME_SHOWN_THE_DOOR, Duel.OUTCOME_TAKEN_OUT_BACK]:
		var other := _fixture(29)
		other._finalize_grand_casino_duel_if_complete({"status":"complete", "outcome":outcome, "hands":[]})
		_expect(other.bankroll == 49 and other.grand_casino_chips == 29 and _cashouts(other).is_empty(), "other endings do not gain clean cashout")
	var file := FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"fidelity":"Synthetic native finale boundary; normal Cage restrictions, marker-first/rate math, zero chips, other endings, repeats and RNG. Genuine QA/Web saves separately qualified."}, "  ")); file.close()
	print("CLEAN_WALKOUT_CASHOUT checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
