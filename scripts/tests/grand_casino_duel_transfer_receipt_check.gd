extends SceneTree

const Model := preload("res://scripts/core/grand_casino_duel_model.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	for row in [
		{"player": 14, "house": 169, "requested": -20, "penalty": 0, "actual": -14},
		{"player": 169, "house": 14, "requested": 20, "penalty": 0, "actual": 14},
		{"player": 14, "house": 169, "requested": -20, "penalty": 18, "actual": -14},
		{"player": 100, "house": 100, "requested": -20, "penalty": 18, "actual": -38},
		{"player": 100, "house": 100, "requested": 20, "penalty": 18, "actual": 2},
		{"player": 100, "house": 100, "requested": 0, "penalty": 0, "actual": 0},
	]:
		var state := {"status": "active", "player_stack": row.player, "rourke_stack": row.house, "hands": [], "hand_index": 0, "hand_limit": 5}
		var before := JSON.stringify(state)
		var result := Model.apply_hand(state, {"transfer": row.requested, "caught_penalty": row.penalty}, {})
		var next: Dictionary = result.get("state", {})
		var hands: Array = next.get("hands", [])
		_expect(bool(result.get("ok", false)), "valid hand is accepted")
		_expect(int(next.get("player_stack", -1)) == row.player + row.actual and int(next.get("rourke_stack", -1)) == row.house - row.actual, "actual settlement stays unchanged")
		_expect(int(next.get("player_stack", -1)) + int(next.get("rourke_stack", -1)) == row.player + row.house, "chips remain conserved")
		_expect(int(result.get("transfer", -999)) == row.actual and hands.size() == 1 and int(hands[0].get("transfer", -999)) == row.actual, "receipt and return match actual movement")
		_expect(int(hands[0].get("caught_penalty", -1)) == row.penalty, "configured caught penalty evidence stays unchanged")
		_expect(JSON.stringify(state) == before, "prior state snapshot is not modified")
		if str(next.get("status", "")) == "complete":
			var repeat := Model.apply_hand(next, {"transfer": row.requested}, {})
			_expect(not bool(repeat.get("ok", true)) and repeat.get("state") == next, "completed hand cannot transfer again")
	var report := {"checks": checks, "failures": failures, "fidelity": "Synthetic native model comparisons of requested/actual transfers with unchanged settlement, conservation, penalty evidence and completed-repeat rejection. Actual saved H2 UI separately qualified."}
	var f := FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("DUEL_TRANSFER_RECEIPT checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
