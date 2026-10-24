extends SceneTree

const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")
const SceneView := preload("res://scripts/ui/environment_interaction_view_model.gd")
const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")

class ProjectionHost extends RefCounted:
	const CONTEXT_MODE_LENDER := "lender"
	const CONTEXT_MODE_SERVICE := "service"
	const EnvironmentInteractionViewModelScript := SceneView
	var library: ContentLibrary
	var run_state: RunState
	var failed := false
	func _run_failed_without_recovery() -> bool: return failed
	func _run_pressure_view() -> Dictionary: return {}
	func _pressure_status_text(_view: Dictionary) -> String: return "Run failed."
	func _object_fixture_declared(_id: String) -> bool: return false
	func _label_from_id(id: String) -> String: return id
	func _normalized_talk_speaker(speaker: Dictionary) -> Dictionary: return speaker
	func _resolve_character_speaker(speaker: Dictionary, _id: String, _line: String) -> Dictionary: return speaker
	func _interaction_rect_for_object(_id: String, _type: String, _index: int) -> Rect2: return Rect2(0.1, 0.1, 0.2, 0.2)
	func _make_interactable_object(source: Dictionary) -> Dictionary: return SceneView.make_interactable_object(source, {})

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
	_check_scene_payment(library, state, service, "brother_in_law", 33, true)
	cases.append("active_debt_payable_borrow_blocked_readonly")

	state.bankroll = 20
	option = service.lender_hook("brother_in_law")
	repayment = state.lender_repayment_status("brother_in_law")
	_check(not option.is_empty() and not bool(option.get("hidden", true)), "Insufficient funds still show repayment guidance")
	_check(bool(repayment.get("available", false)) and not bool(repayment.get("enabled", true)), "Insufficient funds do not permit payment")
	_check_scene_payment(library, state, service, "brother_in_law", 33, false)
	cases.append("insufficient_funds_visible_disabled")

	state.bankroll = 121
	state.debt[0]["status"] = "overdue"
	option = service.lender_hook("brother_in_law")
	_check(not option.is_empty() and bool(state.lender_repayment_status("brother_in_law").get("enabled", false)), "Overdue cash debt remains repayable")
	_check_scene_payment(library, state, service, "brother_in_law", 33, true)
	cases.append("overdue_repayment_visible")

	state.debt.clear()
	_check(service.lender_hook("brother_in_law").is_empty(), "Used one-time contact without debt stays hidden")
	state.debt = [{"id": "favor", "lender_id": "brother_in_law", "debt_kind": "favor", "balance": 33, "status": "active"}]
	_check(service.lender_hook("brother_in_law").is_empty(), "Noncash favor does not invent a cash repayment")
	cases.append("no_cash_debt_no_contact_override")
	state.current_environment["lender_hooks"] = ["motel_friend"]
	state.bankroll = 103
	state.narrative_flags = {}
	state.debt = [{"id": "motel_friend_note", "lender_id": "motel_friend", "debt_kind": "cash", "balance": 22, "principal": 20, "status": "active", "turns_remaining": 4}]
	_check_scene_payment(library, state, service, "motel_friend", 22, true)
	var failed_host := ProjectionHost.new()
	failed_host.library = library
	failed_host.run_state = state
	failed_host.failed = true
	var failed_objects := Controller.hook_interactable_objects(failed_host, "lender", [service.lender_hook("motel_friend")])
	_check(not bool(failed_objects[0].get("enabled", true)), "A payable loan cannot enable actions on a failed run.")
	state.debt.clear()
	var borrow_host := ProjectionHost.new()
	borrow_host.library = library
	borrow_host.run_state = state
	var borrow_objects := Controller.hook_interactable_objects(borrow_host, "lender", [service.lender_hook("motel_friend")])
	_check(str(borrow_objects[0].get("confirm_action_id", "")) == "use_lender_hook", "An available new loan retains the borrowing route.")
	state.debt = [{"id": "favor", "lender_id": "the_crew", "debt_kind": "favor", "balance": 70, "status": "favor_due"}]
	state.current_environment["lender_hooks"] = ["the_crew", "sals_pawn_counter"]
	var crew_objects := Controller.hook_interactable_objects(borrow_host, "lender", [service.lender_hook("the_crew")])
	_check(str(crew_objects[0].get("confirm_action_id", "")) != "repay_lender_debt", "Crew favors must not invent a cash payoff.")
	var pawn_objects := Controller.hook_interactable_objects(borrow_host, "lender", [service.lender_hook("sals_pawn_counter")])
	_check(bool(pawn_objects[0].get("enabled", false)) and str(pawn_objects[0].get("confirm_action_id", "")) == "use_lender_hook", "Pawn counters retain their existing open/redeem route.")
	cases.append("scene_nico_pay_failed_run_borrow_favor_pawn_parity")

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


func _check_scene_payment(library: ContentLibrary, state: RunState, service: RunActionService, lender_id: String, amount: int, affordable: bool) -> void:
	var host := ProjectionHost.new()
	host.library = library
	host.run_state = state
	var original := JSON.stringify([state.bankroll, state.debt, state.narrative_flags, state.rng_state])
	var objects := Controller.hook_interactable_objects(host, "lender", [service.lender_hook(lender_id)])
	_check(objects.size() == 1, "The current scene retains the visible lender.")
	if objects.size() != 1: return
	var object: Dictionary = objects[0]
	_check(bool(object.get("enabled", false)) == affordable, "Scene repayment affordability must match the existing cash-debt contract.")
	var canvas := Canvas.new()
	if affordable:
		_check(str(object.get("confirm_action_id", "")) == "repay_lender_debt", "A lender with a payable debt must advertise repayment instead of blocked borrowing.")
		_check(canvas._selected_info_single_action_enabled(object) and canvas._selected_info_action_label(object) == "Pay $%d" % amount, "The real canvas card must expose the existing payoff amount.")
	else:
		_check(str(object.get("disabled_reason", "")) == "Need $%d to settle this loan." % amount, "An unaffordable loan must explain its payoff requirement.")
		_check(not canvas._selected_info_single_action_enabled(object), "An unaffordable payoff must remain disabled.")
	canvas.free()
	_check(JSON.stringify([state.bankroll, state.debt, state.narrative_flags, state.rng_state]) == original, "Scene projection preserves money, debt, flags and RNG.")
