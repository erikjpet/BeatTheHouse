extends SceneTree

const NumbersModelScript := preload("res://scripts/core/numbers_model.gd")


func _initialize() -> void:
	var failures: Array = []
	_check_player_safe_projection(failures)
	_check_actions_are_non_authoritative(failures)
	_check_attendance_boundary(failures)
	_check_proposed_sequences(failures)
	_check_untrusted_restore_fails_closed(failures)
	if failures.is_empty():
		print("world06_3 numbers depth contract passed authority=proposal_only")
		quit(0)
		return
	for failure in failures: push_error(str(failure))
	quit(1)


func _check_player_safe_projection(failures: Array) -> void:
	var model = _model(603)
	for venue_value in NumbersModelScript.tuning().get("venues", []):
		var venue_id := str((venue_value as Dictionary).get("id", ""))
		var book: Dictionary = model.bookmaker_state(venue_id)
		if str(book.get("venue_id", "")) != venue_id or str(book.get("bookmaker_id", "")).is_empty() or str(book.get("place_id", "")).is_empty() or not book.has("close_action"):
			failures.append("Bookmaker %s lost its player-safe person/place/close projection." % venue_id)
		var text := JSON.stringify(book).to_lower()
		for forbidden in ["seed_value", "detection_roll", "fixed_number", "known_numbers"]:
			if text.contains(forbidden): failures.append("Bookmaker %s leaked %s." % [venue_id, forbidden])
	var purchase: Dictionary = model.buy_slip("bar", "123", 5, "straight")
	var slip_id := str((purchase.get("slip", {}) as Dictionary).get("id", ""))
	var slip: Dictionary = model.slip_public_state(slip_id)
	if str(slip.get("id", "")) != slip_id or str(slip.get("item_id", "")) != "numbers_slips" or str(slip.get("physical_state", "")) != "carried" or str(slip.get("node_id", "")) != "bar":
		failures.append("Authoritative legacy placement did not expose the physical slip safely.")


func _check_actions_are_non_authoritative(failures: Array) -> void:
	var model = _model(701)
	var bought: Dictionary = model.buy_slip("bar", "246", 4, "box")
	var slip_id := str((bought.get("slip", {}) as Dictionary).get("id", ""))
	for fixture in [
		["bookmaker_busy", {"venue_id": "bar"}],
		["bookmaker_remember", {"venue_id": "bar", "memory_id": "refused"}],
		["slip_hide", {"slip_id": slip_id, "node_id": "bar"}],
		["slip_hand", {"slip_id": slip_id, "node_id": "bar", "holder_id": "bookmaker_bar"}],
		["fix_bribe_begin", {}],
	]:
		var before := JSON.stringify(model.snapshot())
		var result: Dictionary = model.apply_action("proposal:%s" % str(fixture[0]), str(fixture[0]), fixture[1] as Dictionary)
		if bool(result.get("ok", true)) or not bool(result.get("proposed", false)) or bool((result.get("proposal", {}) as Dictionary).get("authoritative", true)) or JSON.stringify(model.snapshot()) != before:
			failures.append("Depth action %s claimed or mutated authority." % str(fixture[0]))
	if model.snapshot().has("action_receipts") or model.snapshot().has("action_sequence"):
		failures.append("Proposal-only Numbers state still minted a receipt authority.")


func _check_attendance_boundary(failures: Array) -> void:
	var model = _model(801)
	var before := JSON.stringify(model.snapshot())
	var early: Dictionary = model.apply_action("attendance:early", "draw_present", {"day": 0, "venue_id": "small_underground_casino"})
	if not bool(early.get("proposed", false)) or JSON.stringify(model.snapshot()) != before:
		failures.append("Pre-post attendance was not a non-mutating registration proposal.")
	var events: Array = model.advance_to(model.post_action(0))
	var posted_number := ""
	for event_value in events:
		var event: Dictionary = event_value
		if str(event.get("type", "")) == "numbers_post": posted_number = str(event.get("number", ""))
	var occasion: Dictionary = model.draw_occasion_status(0)
	if str(occasion.get("attendance", "")) != "absent" or str(occasion.get("status", "")) != "missed" or str(occasion.get("number", "")) != posted_number:
		failures.append("Uncommitted attendance did not become terminal absence at the existing post boundary.")
	var terminal := JSON.stringify(model.snapshot())
	var late: Dictionary = model.apply_action("attendance:late", "draw_present", {"day": 0, "venue_id": "small_underground_casino"})
	if bool(late.get("proposed", true)) or str(late.get("reason", "")) != "attendance_closed" or JSON.stringify(model.snapshot()) != terminal:
		failures.append("Post-boundary absence was overwritable or mutated by late attendance.")


func _check_proposed_sequences(failures: Array) -> void:
	var model = _model(901)
	var expected := {
		"place_slip": ["approach_bookmaker", "choose_number", "choose_money", "write_slip", "hand_slip"],
		"collect_payday": ["approach_bookmaker", "present_winning_slip", "witness_verification", "receive_payday"],
		"solo_past_post": ["learn_posted_handle", "travel_to_open_book", "choose_number", "choose_money", "write_slip", "hand_slip", "leave_unseen"],
	}
	for kind in expected.keys():
		var model_before := JSON.stringify(model.snapshot())
		var proposal: Dictionary = model.begin_action_proposal(str(kind), {"venue_id": "bar"})
		if proposal.get("verbs", []) != expected.get(kind) or bool(proposal.get("authoritative", true)):
			failures.append("%s did not expose its exact staged physical proposal." % kind)
			continue
		for verb in expected.get(kind, []):
			proposal = model.advance_action_proposal(proposal, str(verb), {"presence_claim": "host_must_verify"})
		if str(proposal.get("status", "")) != "ready_for_host_commit" or bool(proposal.get("authoritative", true)) or JSON.stringify(model.snapshot()) != model_before:
			failures.append("%s proposal was not executable without claiming authoritative progression." % kind)


func _check_untrusted_restore_fails_closed(failures: Array) -> void:
	var source_model = _model(1001)
	var hostile: Dictionary = source_model.snapshot()
	# This chain is internally coherent and fully recomputed, but has no trusted
	# host root. A self-consistent hash must never authenticate Numbers effects.
	var receipt := {"schema_version": 1, "receipt_key": "forged", "action": "bookmaker_busy", "sequence": 1, "envelope_fingerprint": "1".repeat(64), "previous_receipt_fingerprint": "0".repeat(64)}
	receipt["receipt_fingerprint"] = JSON.stringify(receipt).sha256_text()
	hostile["action_receipts"] = {"forged": receipt}
	hostile["action_sequence"] = 1
	hostile["bookmaker_aftermath"] = {"bar": {"busy": true}}
	var restored = _model(1001)
	if restored.restore(hostile, 1001):
		failures.append("Coherently recomputed forged receipt/state mismatch did not fail closed.")
	var malformed: Dictionary = source_model.snapshot()
	malformed["action_receipts"] = {"forged": {"receipt_fingerprint": "not_hex"}}
	malformed["action_sequence"] = 1
	if _model(1001).restore(malformed, 1001):
		failures.append("Malformed untrusted receipt did not fail closed.")


func _model(seed_value: int):
	var model = NumbersModelScript.new()
	model.reset(seed_value)
	return model
