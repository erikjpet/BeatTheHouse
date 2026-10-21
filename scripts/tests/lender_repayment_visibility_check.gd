extends SceneTree

# Focused synthetic projection check for the genuine Store-loan/Motel finding.
# No player save, room authority, loan terms or repayment transaction is changed.
var failures: Array[String] = []
var cases: Array = []


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _run() -> void:
	var library := ContentLibrary.new()
	library.lenders = JSON.parse_string(FileAccess.get_file_as_string("res://data/debt/lenders.json"))
	var state := RunState.new()
	state.current_environment = {"id": "motel_005", "archetype_id": "motel", "tier": 1, "lender_hooks": ["brother_in_law"]}
	state.bankroll = 121
	state.narrative_flags = {"brother_in_law_loan_used": true, "brother_in_law_phone_ready": false}
	state.debt = [{"id": "brother_in_law_note", "lender_id": "brother_in_law", "debt_kind": "cash", "balance": 33, "principal": 30, "status": "active", "turns_remaining": 6}]
	var service := RunActionService.new()
	service.setup(library, state)
	var original := JSON.stringify([state.bankroll, state.debt, state.narrative_flags, state.rng_state])
	var borrowing := state.lender_hook_status(library.lender("brother_in_law"))
	_check(not bool(borrowing.get("available", true)), "Single-use borrowing remains unavailable")
	var option := service.lender_hook("brother_in_law")
	_check(not option.is_empty() and not bool(option.get("hidden", true)), "Active family debt retains visible contact")
	_check(not bool(option.get("enabled", true)), "Visible contact does not reenable borrowing")
	_check(str(option.get("availability_class", "")) == RunState.AVAILABILITY_TRANSIENT_BLOCKED, "Existing selectable blocked-card route remains reachable")
	var repayment := state.lender_repayment_status("brother_in_law")
	_check(bool(repayment.get("available", false)) and bool(repayment.get("enabled", false)) and int(repayment.get("payoff_amount", 0)) == 33, "Existing Pay33 action stays available")
	_check(not bool(service.use_hook("lender", "brother_in_law").get("ok", true)), "Repeat borrowing is rejected before a transaction")
	_check(JSON.stringify([state.bankroll, state.debt, state.narrative_flags, state.rng_state]) == original, "Projection and rejected borrow preserve money/debt/flags/RNG")
	cases.append("active_debt_payable_borrow_blocked_readonly")

	state.bankroll = 20
	option = service.lender_hook("brother_in_law")
	repayment = state.lender_repayment_status("brother_in_law")
	_check(not option.is_empty() and not bool(option.get("hidden", true)), "Insufficient funds still show repayment guidance")
	_check(bool(repayment.get("available", false)) and not bool(repayment.get("enabled", true)), "Insufficient funds do not permit payment")
	cases.append("insufficient_funds_visible_disabled")

	state.bankroll = 121
	state.debt[0]["status"] = "overdue"
	option = service.lender_hook("brother_in_law")
	_check(not option.is_empty() and bool(state.lender_repayment_status("brother_in_law").get("enabled", false)), "Overdue cash debt remains repayable")
	cases.append("overdue_repayment_visible")

	state.debt.clear()
	_check(service.lender_hook("brother_in_law").is_empty(), "Used one-time contact without debt stays hidden")
	state.debt = [{"id": "favor", "lender_id": "brother_in_law", "debt_kind": "favor", "balance": 33, "status": "active"}]
	_check(service.lender_hook("brother_in_law").is_empty(), "Noncash favor does not invent a cash repayment")
	cases.append("no_cash_debt_no_contact_override")

	var report := {"passed": failures.is_empty(), "failures": failures, "cases": cases, "scope": "Synthetic repayment visibility only; real Web repayment remains separately qualified"}
	var report_path := OS.get_environment("BTH_LENDER_VISIBILITY_REPORT")
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
	print("LENDER_REPAYMENT_VISIBILITY " + JSON.stringify(report))
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)
