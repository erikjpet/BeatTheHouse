extends RefCounted

const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")

# Caller supplies the real, active Bar sequence. These are ordinary book results,
# distinct from the existing Knuckles event_bridge correlation. No save/profile
# path, fabricated delivery receipt, money mutation or RNG override is embedded.
static func check(source: Dictionary, definition: Dictionary) -> Dictionary:
	var failures: Array = []
	var checks := 0
	var expect := func(ok: bool, label: String) -> void:
		if not ok: failures.append(label)
	var state := Runtime.normalize_state(source, definition)
	if state.is_empty() or str(state.get("scenario_id", "")) != "bar_fight_night":
		return {"passed":false,"failures":["An active real Bar Fight Night sequence is required."]}
	expect.call(Schema.calculated_signature_hash(definition) == str(Schema.sequence(definition).get("sequence_signature", "")), "authored signature remains valid")
	checks += 1
	for choice in ["take_the_other_corner", "keep_off_the_book"]:
		var payload := {"event_id":"scenario_fight_night_swing_bet","choice_id":choice,"resolution_id":"","resolved":true,"ok":true}
		var fact_id: String = "test:bar_book:" + str(choice)
		var fact := Runtime.fact("event_result","event",str(state["node_id"]),fact_id,int(state["fact_serial_next"]),int(state["boundary_serial"]),payload)
		var admitted := Runtime.enqueue_fact(state,definition,fact)
		expect.call(bool(admitted.get("ok",false)), "admit ordinary " + choice)
		var flushed := Runtime.flush_facts(admitted.get("state",{}),definition,int(state["boundary_serial"]))
		expect.call(bool(flushed.get("ok",false)), "consume ordinary " + choice)
		var final: Dictionary=flushed.get("state",{})
		expect.call((final.get("fact_receipts",[]) as Array).has(fact_id), "retain exactly-once receipt " + choice)
		var duplicate := Runtime.enqueue_fact(final,definition,fact)
		expect.call(bool(duplicate.get("ok",false)) and bool(duplicate.get("duplicate",false)) and var_to_bytes(duplicate.get("state",{}))==var_to_bytes(final), "duplicate ordinary result is inert " + choice)
		checks += 4
	for mutation in ["wrong_event","wrong_choice","not_resolved","not_ok","invented_correlation","undelivered_existing_correlation"]:
		var payload := {"event_id":"scenario_fight_night_swing_bet","choice_id":"take_the_other_corner","resolution_id":"","resolved":true,"ok":true}
		match mutation:
			"wrong_event": payload["event_id"]="machine_jam"
			"wrong_choice": payload["choice_id"]="not_an_authored_choice"
			"not_resolved": payload["resolved"]=false
			"not_ok": payload["ok"]=false
			"invented_correlation": payload["resolution_id"]="take_the_other_corner"
			"undelivered_existing_correlation":
				payload["choice_id"]="keep_off_the_book"
				payload["resolution_id"]="keep_off_the_book"
		var fact := Runtime.fact("event_result","event",str(state["node_id"]),"test:bar_guard:"+mutation,int(state["fact_serial_next"]),int(state["boundary_serial"]),payload)
		var admitted := Runtime.enqueue_fact(state,definition,fact)
		var queued: Dictionary=admitted.get("state",{})
		var rejected := Runtime.flush_facts(queued,definition,int(state["boundary_serial"]))
		expect.call(bool(admitted.get("ok",false)) and not bool(rejected.get("ok",true)), "reject unowned result " + mutation)
		expect.call(var_to_bytes(rejected.get("state",{}))==var_to_bytes(queued), "rejection leaves queue/state unchanged " + mutation)
		checks += 2
	return {"passed":failures.is_empty(),"checks":checks,"failures":failures}
