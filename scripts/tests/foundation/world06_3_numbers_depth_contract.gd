extends SceneTree

const NumbersModelScript := preload("res://scripts/core/numbers_model.gd")
const VENUES := ["small_underground_casino", "bar", "motel", "gas_station_casino", "corner_store"]
const BOOK_STATES := ["open", "busy", "closing", "closed"]


func _initialize() -> void:
	var failures: Array = []
	var probe = _model(603)
	var required_methods := ["bookmaker_state", "bookmaker_states_public", "slip_public_state", "draw_occasion_status", "apply_action"]
	var missing: Array = []
	for method_name in required_methods:
		if not probe.has_method(method_name): missing.append(method_name)
	if not missing.is_empty():
		failures.append("NumbersModel is missing its declared pure depth surface: %s." % ", ".join(missing))
	else:
		_check_five_bookmakers_and_memory(failures)
		_check_physical_slip_lifecycle(failures)
		_check_draw_present_absent_privacy(failures)
		_check_receipts_and_hostile_restore(failures)
		_check_staged_fix_locked_outcomes(failures)
		_check_save_revisit_determinism(failures)
	_check_no_heist_coupling(failures)
	if failures.is_empty():
		print("world06_3 numbers depth contract passed")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)


func _check_five_bookmakers_and_memory(failures: Array) -> void:
	for venue_id in VENUES:
		var model = _model(610 + VENUES.find(venue_id))
		var close: int = int(model.call("close_action", venue_id, 0))
		for fixture in [[0, "open"], [close - 2, "closing"], [close, "closed"]]:
			model.advance_to(int(fixture[0]))
			var book := _book(model, venue_id)
			if str(book.get("venue_id", "")) != venue_id or str(book.get("service_state", "")) != str(fixture[1]) \
					or int(book.get("close_action", -1)) != close or str(book.get("bookmaker_id", "")).is_empty() or str(book.get("place_id", "")).is_empty():
				failures.append("Bookmaker %s did not expose exact place, actor, visible close, and %s state." % [venue_id, str(fixture[1])])
		model = _model(700 + VENUES.find(venue_id))
		var busy := _depth_act(model, "bookmaker_busy", "book:%s:busy" % venue_id, {"venue_id": venue_id})
		if not bool(busy.get("ok", false)) or str(_book(model, venue_id).get("service_state", "")) != "busy":
			failures.append("Bookmaker %s could not enter its receipted busy state." % venue_id)
		_depth_act(model, "bookmaker_remember", "book:%s:memory" % venue_id, {"venue_id": venue_id, "memory_id": "refused"})
		var remembered := _book(model, venue_id)
		var memory := _dict(remembered.get("memory", {}))
		if not bool(memory.get("refused", false)):
			failures.append("Bookmaker %s did not retain player-visible local memory." % venue_id)
		var memory_text := JSON.stringify(memory).to_lower()
		for forbidden in ["fixed_number", "known_numbers", "detection_roll", "rng", "seed_value"]:
			if memory_text.contains(forbidden):
				failures.append("Bookmaker %s exposed hidden memory authority %s." % [venue_id, forbidden])
		var demeanor := str(remembered.get("demeanor", ""))
		if demeanor not in ["friendly", "wary", "suspicious"]:
			failures.append("Bookmaker %s omitted its authored player-readable demeanor." % venue_id)


func _check_physical_slip_lifecycle(failures: Array) -> void:
	var model = _model(801)
	var purchase: Dictionary = model.buy_slip("bar", "123", 5, "straight")
	var slip_id := str(_dict(purchase.get("slip", {})).get("id", ""))
	var initial := _slip(model, slip_id)
	_assert_slip_identity(initial, slip_id, "carried", "bar", failures, "placed")
	for step in [
		["slip_show", "shown", "slip:show", {"slip_id": slip_id, "node_id": "bar"}],
		["slip_hide", "hidden", "slip:hide", {"slip_id": slip_id, "node_id": "bar"}],
		["slip_hand", "handed", "slip:hand", {"slip_id": slip_id, "node_id": "bar", "holder_id": "bookmaker_bar"}],
	]:
		var result := _depth_act(model, str(step[0]), str(step[2]), _dict(step[3]))
		if not bool(result.get("ok", false)):
			failures.append("Physical slip action %s rejected an authentic local transaction." % str(step[0]))
		_assert_slip_identity(_slip(model, slip_id), slip_id, str(step[1]), "bar", failures, str(step[0]))
	var before_remote := JSON.stringify(model.snapshot())
	_depth_act(model, "slip_hide", "slip:remote", {"slip_id": slip_id, "node_id": "motel"})
	if JSON.stringify(model.snapshot()) != before_remote:
		failures.append("Remote slip manipulation was not an exact no-op.")
	var lost_model = _model(802)
	var lost_id := str(_dict(lost_model.buy_slip("motel", "321", 4, "box").get("slip", {})).get("id", ""))
	_depth_act(lost_model, "slip_lose", "slip:lose", {"slip_id": lost_id, "node_id": "motel", "place_id": "motel::hall"})
	_assert_slip_identity(_slip(lost_model, lost_id), lost_id, "lost", "motel", failures, "lost")
	var lost_before := JSON.stringify(lost_model.snapshot())
	_depth_act(lost_model, "slip_collect", "slip:lost:collect", {"slip_id": lost_id, "node_id": "motel"})
	if JSON.stringify(lost_model.snapshot()) != lost_before:
		failures.append("A lost slip could be collected or recreated.")


func _check_draw_present_absent_privacy(failures: Array) -> void:
	var present = _model(901)
	var absent = _model(901)
	var pre_snapshot := JSON.stringify(present.snapshot())
	var premature := _depth_act(present, "draw_present", "draw:early", {"day": 0, "venue_id": "small_underground_casino"})
	if bool(premature.get("ok", false)) or premature.has("number") or JSON.stringify(present.snapshot()) != pre_snapshot:
		failures.append("A pre-boundary draw occasion previewed or persisted the handle.")
	var post: int = int(present.call("post_action", 0))
	var present_events: Array = present.advance_to(post)
	var absent_events: Array = absent.advance_to(post)
	var present_number := _event_number(present_events)
	var absent_number := _event_number(absent_events)
	_depth_act(present, "draw_present", "draw:present", {"day": 0, "venue_id": "small_underground_casino"})
	_depth_act(absent, "draw_absent", "draw:absent", {"day": 0})
	var staged_present := _dict(present.call("draw_occasion_status", 0))
	var staged_absent := _dict(absent.call("draw_occasion_status", 0))
	if present_number.is_empty() or present_number != absent_number or str(staged_present.get("number", "")) != present_number or str(staged_absent.get("number", "")) != absent_number:
		failures.append("Present and absent draw occasions did not consume the same already-posted seeded handle.")
	if str(staged_present.get("attendance", "")) != "present" or str(staged_absent.get("attendance", "")) != "absent":
		failures.append("Draw occasion did not distinguish present and absent staging without changing outcome.")


func _check_receipts_and_hostile_restore(failures: Array) -> void:
	var model = _model(1001)
	_depth_act(model, "bookmaker_busy", "receipt:one", {"venue_id": "bar"})
	var exact := JSON.stringify(model.snapshot())
	_depth_act(model, "bookmaker_busy", "receipt:one", {"venue_id": "bar"})
	if JSON.stringify(model.snapshot()) != exact:
		failures.append("Authentic Numbers depth action replay was not an exact no-op.")
	_depth_act(model, "bookmaker_remember", "receipt:one", {"venue_id": "bar", "memory_id": "refused"})
	if JSON.stringify(model.snapshot()) != exact:
		failures.append("Conflicting Numbers receipt envelope mutated state.")
	var receipts := _dict(model.snapshot().get("action_receipts", {}))
	var receipt := _dict(receipts.get("receipt:one", {}))
	var expected := ["action", "envelope_fingerprint", "previous_receipt_fingerprint", "receipt_fingerprint", "receipt_key", "schema_version", "sequence"]
	var keys: Array = receipt.keys()
	keys.sort()
	if keys != expected or str(receipt.get("receipt_key", "")) != "receipt:one" or int(receipt.get("sequence", 0)) != 1:
		failures.append("Numbers depth receipt did not use the closed authenticated shape.")
	for digest_key in ["envelope_fingerprint", "previous_receipt_fingerprint", "receipt_fingerprint"]:
		if not _lower_hex_sha256(str(receipt.get(digest_key, ""))):
			failures.append("Numbers depth receipt %s was not lowercase 64-hex." % digest_key)
	for mutation in ["extra", "key", "action", "sequence", "envelope", "previous", "receipt", "malformed"]:
		var hostile: Dictionary = model.call("snapshot")
		var hostile_receipts := _dict(hostile.get("action_receipts", {}))
		var hostile_receipt := _dict(hostile_receipts.get("receipt:one", {}))
		match mutation:
			"extra": hostile_receipt["unexpected"] = true
			"key": hostile_receipt["receipt_key"] = "forged"
			"action": hostile_receipt["action"] = "slip_lose"
			"sequence": hostile_receipt["sequence"] = 9
			"envelope": hostile_receipt["envelope_fingerprint"] = "0".repeat(64)
			"previous": hostile_receipt["previous_receipt_fingerprint"] = "1".repeat(64)
			"receipt": hostile_receipt["receipt_fingerprint"] = "2".repeat(64)
			"malformed": hostile_receipt["receipt_fingerprint"] = "not_hex"
		hostile_receipts["receipt:one"] = hostile_receipt
		hostile["action_receipts"] = hostile_receipts
		var restored = _model(1001)
		if restored.restore(hostile, 1001):
			failures.append("Malformed Numbers depth receipt restore did not fail closed: %s." % mutation)


func _check_staged_fix_locked_outcomes(failures: Array) -> void:
	var model = _model(1101)
	model.fix_unlock(true)
	var begin := _depth_act(model, "fix_bribe_begin", "fix:begin", {})
	var bribe := _depth_act(model, "fix_bribe_resolve", "fix:bribe", {"success": true, "clean": true, "fast": true})
	for fixture in [
		["bar", 20, "fix:camouflage:bar"], ["motel", 20, "fix:camouflage:motel"], ["corner_store", 20, "fix:camouflage:corner"],
	]:
		_depth_act(model, "fix_camouflage_place", str(fixture[2]), {"venue_id": str(fixture[0]), "stake": int(fixture[1])})
	var commit := _depth_act(model, "fix_camouflage_commit", "fix:commit", {})
	if not bool(begin.get("ok", false)) or not bool(bribe.get("ok", false)) or not bool(commit.get("ok", false)):
		failures.append("Crew fix did not proceed through receipted bribe and player-performed camouflage substeps.")
	var fix := _dict(model.fix_state)
	if str(fix.get("status", "")) != "payday" or int(fix.get("allocation_total", 0)) != 60 or _dict(fix.get("allocations", {})) != {"bar": 20, "corner_store": 20, "motel": 20} \
			or int(fix.get("bribe_score", 0)) != 100 or bool(fix.get("too_concentrated", true)):
		failures.append("Staged fix changed the locked $60 spread or strong bribe/camouflage outcome.")
	var before_duplicate := JSON.stringify(model.snapshot())
	_depth_act(model, "fix_camouflage_commit", "fix:commit", {})
	if JSON.stringify(model.snapshot()) != before_duplicate:
		failures.append("Fix commit replay duplicated slips or changed the locked outcome.")
	var poor = _model(1102)
	poor.fix_unlock(true)
	_depth_act(poor, "fix_bribe_begin", "poor:begin", {})
	_depth_act(poor, "fix_bribe_resolve", "poor:bribe", {"success": true})
	_depth_act(poor, "fix_camouflage_place", "poor:bar", {"venue_id": "bar", "stake": 20})
	var poor_commit := _depth_act(poor, "fix_camouflage_commit", "poor:commit", {})
	if bool(poor_commit.get("ok", false)) or str(poor.fix_state.get("status", "")) != "camouflage":
		failures.append("A badly performed one-book camouflage escaped the locked minimum-three-books rule.")


func _check_save_revisit_determinism(failures: Array) -> void:
	var first = _model(1201)
	var second = _model(1201)
	for model in [first, second]:
		var bought: Dictionary = model.call("buy_slip", "gas_station_casino", "246", 6, "box")
		var slip_id := str(_dict(bought.get("slip", {})).get("id", ""))
		_depth_act(model, "slip_show", "save:show", {"slip_id": slip_id, "node_id": "gas_station_casino"})
		_depth_act(model, "bookmaker_remember", "save:visit", {"venue_id": "gas_station_casino", "memory_id": "visit_count"})
	if JSON.stringify(first.snapshot()) != JSON.stringify(second.snapshot()):
		failures.append("Identical Numbers depth actions were not deterministic.")
	var saved: Dictionary = first.call("snapshot")
	var restored = _model(1201)
	if not restored.restore(saved, 1201) or JSON.stringify(restored.snapshot()) != JSON.stringify(saved):
		failures.append("Numbers physical slip, bookmaker memory, or receipts did not survive save/revisit byte-identically.")
	var before_revisit := JSON.stringify(restored.snapshot())
	_depth_act(restored, "bookmaker_remember", "save:visit", {"venue_id": "gas_station_casino", "memory_id": "visit_count"})
	if JSON.stringify(restored.snapshot()) != before_revisit:
		failures.append("Revisit replay duplicated bookmaker aftermath.")


func _check_no_heist_coupling(failures: Array) -> void:
	var source := FileAccess.get_file_as_string("res://scripts/core/numbers_model.gd").to_lower()
	for forbidden in ["crew_heist", "heist_state", "heist_model"]:
		if source.contains(forbidden):
			failures.append("Numbers depth introduced forbidden cross-system coupling: %s." % forbidden)


func _model(seed_value: int):
	var model = NumbersModelScript.new()
	model.reset(seed_value)
	return model


func _depth_act(model: Variant, action: String, receipt_key: String, context: Dictionary) -> Dictionary:
	var value: Variant = model.call("apply_action", receipt_key, action, context.duplicate(true))
	return _dict(value)


func _book(model: Variant, venue_id: String) -> Dictionary:
	return _dict(model.call("bookmaker_state", venue_id))


func _slip(model: Variant, slip_id: String) -> Dictionary:
	return _dict(model.call("slip_public_state", slip_id))


func _assert_slip_identity(slip: Dictionary, slip_id: String, physical_state: String, node_id: String, failures: Array, label: String) -> void:
	if str(slip.get("id", "")) != slip_id or str(slip.get("item_id", "")) != "numbers_slips" or str(slip.get("physical_state", "")) != physical_state \
			or str(slip.get("node_id", "")) != node_id or str(slip.get("instance_id", "")).is_empty():
		failures.append("%s slip lost exact object identity, location, or %s physical state." % [label, physical_state])


func _event_number(events: Array) -> String:
	for event_value in events:
		var event := _dict(event_value)
		if str(event.get("type", "")) == "numbers_post":
			return str(event.get("number", ""))
	return ""


func _lower_hex_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower():
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
