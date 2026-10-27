extends SceneTree

const Report = preload("res://scripts/ui/run_report_view_model.gd")
const Cage = preload("res://scripts/core/cage_economy_model.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	var marker = {"id": Cage.ATM_DEBT_ID, "lender_id": "grand_casino_atm", "debt_kind": "casino_marker", "balance": 50}
	var borrow = {"type": "lender_hook", "label": "Grand Casino ATM", "debt_changes": [marker]}
	var paid = {"type": "grand_casino_chip_cashout", "debt_paid": 55, "debt_remaining": 0, "cash_paid": 49}
	var history = [borrow, {"type": "debt_payment", "debt_id": Cage.ATM_DEBT_ID, "payment": 1}, paid]
	var before = history.duplicate(true)
	var rows = Report.build_debt_ledger([], history)
	check(rows.size() == 1 and rows[0].outcome == "settled" and rows[0].tone == "settled", "chip payoff left historical marker outstanding")
	check(rows.size() == 1 and rows[0].amount == 50, "payoff lost historical amount")
	check(history == before, "report mutated payment history")
	check(Report.build_debt_ledger([], history) == rows, "repeated report changed settlement")
	var partial = marker.duplicate(true); partial.balance = 30
	rows = Report.build_debt_ledger([partial], [borrow, {"type": "grand_casino_chip_cashout", "debt_paid": 20, "debt_remaining": 30}])
	check(rows.size() == 1 and rows[0].outcome == "outstanding" and rows[0].amount == 30, "partial redemption hid live balance")
	check(Report.build_debt_ledger([], [{"type": "grand_casino_chip_cashout", "debt_paid": 0, "debt_remaining": 0}]).is_empty(), "ordinary chip redemption fabricated a loan")
	rows = Report.build_debt_ledger([], [borrow, {"type": "grand_casino_chip_cashout", "debt_paid": 20}])
	check(rows[0].outcome == "outstanding", "incomplete legacy receipt falsely settled marker")
	rows = Report.build_debt_ledger([], [borrow, {"type": "grand_casino_chip_cashout", "debt_paid": 0, "debt_remaining": 0}])
	check(rows[0].outcome == "outstanding", "zero payment falsely settled marker")
	rows = Report.build_debt_ledger([], [borrow, {"type": "debt_paid", "debt_id": Cage.ATM_DEBT_ID}])
	check(rows[0].outcome == "settled", "cash repayment no longer settles")
	rows = Report.build_debt_ledger([marker], history + [borrow])
	check(rows.size() == 1 and rows[0].outcome == "outstanding" and rows[0].amount == 50, "later borrow inherited old settled state")
	var street = {"id": "street_note", "lender_id": "street_lender", "balance": 21}
	var pawn = {"id": "pawn_note", "lender_id": "pawn_shop", "debt_kind": "pawn", "principal": 10}
	rows = Report.build_debt_ledger([street, pawn], history)
	check(rows.filter(func(row): return row.id == "street_note" and row.outcome == "outstanding").size() == 1, "marker settlement changed unrelated debt")
	check(rows.filter(func(row): return row.id == "pawn_note" and row.outcome == "still held").size() == 1, "marker settlement changed pawn collateral")
	print("RUN_REPORT_MARKER_SETTLEMENT checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
