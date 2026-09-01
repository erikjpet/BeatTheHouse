extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")

var out_path := "res://.tmp/coin_pusher_pusherv3_10_opening_audit.json"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=").strip_edges()
	call_deferred("_run")


func _run() -> void:
	var library := ContentLibraryScript.new()
	library.load(false)
	var root_definition: Dictionary = (library.game("coin_pusher") as Dictionary).get("coin_pusher_machine", {})
	var variants: Dictionary = root_definition.get("machines", {})
	var definitions := {
		"quarter_falls": root_definition,
		"jackpot_ridge": variants.get("jackpot_ridge", {}),
		"vault_drop": variants.get("vault_drop", {}),
	}
	var machine_reports := {}
	var passed := true
	for machine_id in definitions:
		var definition: Dictionary = definitions[machine_id]
		var contexts: Array = []
		for seed_index in range(4):
			var opening_count := 154 if machine_id == "vault_drop" else 150
			var state := Solver.create_machine(_rng("PUSHER-V3-10-OPENING-%s-%d" % [machine_id, seed_index]), definition, opening_count, true)
			var matrix := _matrix(state, definition)
			var settle: Dictionary = state.get("opening_settle_report", {})
			var context_passed := _matrix_passed(matrix) and int(settle.get("physical_ticks", 0)) > 0 and int(settle.get("awake_count", -1)) == 0 and int(settle.get("unsupported_count", -1)) == 0 and int(settle.get("tray_count", -1)) == 0 and int(settle.get("gutter_count", -1)) == 0
			var idle := {}
			if seed_index == 0:
				var before := Solver.canonical_digest(state)
				var stepped := Solver.step_ticks_reference_for_test(state, {"motor_enabled": false}, 1200)
				var after := Solver.canonical_digest(state)
				before.erase("tick")
				after.erase("tick")
				idle = {
					"ticks": 1200,
					"bodies_and_ledgers_unchanged": before == after,
					"event_count": (stepped.get("events", []) as Array).size(),
					"motor_rate_fp": int(state.get("motor_rate_fp", -1)),
				}
				context_passed = context_passed and bool(idle["bodies_and_ledgers_unchanged"]) and int(idle["event_count"]) == 0 and int(idle["motor_rate_fp"]) == 0
			contexts.append({"seed_index": seed_index, "body_count": (state.get("bodies", []) as Array).size(), "occupancy": matrix["occupancy"], "contacts": matrix["contacts"], "settle": settle, "idle_five_periods": idle, "passed": context_passed})
			passed = passed and context_passed
		machine_reports[machine_id] = {"contexts": contexts, "ranges": _ranges(contexts), "passed": contexts.all(func(context): return bool((context as Dictionary).get("passed", false)))}
	var report := {"schema": "coin_pusher_pusherv3_10_opening_audit_v1", "generated_at": Time.get_datetime_string_from_system(false, true), "region_order": ["lower_deck", "upper_platform"], "third_order": ["left", "center", "right"], "machines": machine_reports, "passed": passed}
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write pusherv3_10 opening audit: %s" % out_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("COIN_PUSHER_PUSHERV3_10_OPENING_AUDIT_%s out=%s" % ["PASS" if passed else "FAIL", ProjectSettings.globalize_path(out_path)])
	quit(0 if passed else 1)


func _matrix(state: Dictionary, definition: Dictionary) -> Dictionary:
	var occupancy := [[0, 0], [0, 0], [0, 0]]
	var contacts := [[0, 0], [0, 0], [0, 0]]
	var bodies: Array = state.get("bodies", [])
	var width := int((definition.get("geometry", {}) as Dictionary).get("width", 100000))
	for body_value in bodies:
		var body: Dictionary = body_value
		var third := clampi(int(body.get("x", 0)) * 3 / maxi(1, width), 0, 2)
		var region := 1 if int(body.get("y", 0)) >= int(state.get("face_y", 43000)) else 0
		occupancy[third][region] += 1
		if _has_contact(body, bodies):
			contacts[third][region] += 1
	return {"occupancy": occupancy, "contacts": contacts}


func _has_contact(body: Dictionary, bodies: Array) -> bool:
	if not (body.get("support_ids", []) as Array).is_empty():
		return true
	for other_value in bodies:
		var other: Dictionary = other_value
		if str(other.get("id", "")) == str(body.get("id", "")):
			continue
		var dx := int(other.get("x", 0)) - int(body.get("x", 0))
		var dy := int(other.get("y", 0)) - int(body.get("y", 0))
		var reach := int(other.get("radius", 0)) + int(body.get("radius", 0)) + 120
		var body_bottom := int(body.get("z", 0))
		var body_top := body_bottom + int(body.get("height", 0))
		var other_bottom := int(other.get("z", 0))
		var other_top := other_bottom + int(other.get("height", 0))
		if maxi(0, maxi(body_bottom - other_top, other_bottom - body_top)) <= 120 and dx * dx + dy * dy <= reach * reach:
			return true
	return false


func _matrix_passed(matrix: Dictionary) -> bool:
	var occupancy: Array = matrix.get("occupancy", [])
	var contacts: Array = matrix.get("contacts", [])
	for third in range(3):
		for region in range(2):
			if int((occupancy[third] as Array)[region]) < 2 or int((contacts[third] as Array)[region]) < 1:
				return false
	return int((occupancy[1] as Array)[0]) <= maxi(int((occupancy[0] as Array)[0]), int((occupancy[2] as Array)[0])) * 2 and int((occupancy[1] as Array)[1]) <= maxi(int((occupancy[0] as Array)[1]), int((occupancy[2] as Array)[1])) * 2


func _ranges(contexts: Array) -> Dictionary:
	var result := {"occupancy_min": [[999, 999], [999, 999], [999, 999]], "occupancy_max": [[0, 0], [0, 0], [0, 0]], "contacts_min": [[999, 999], [999, 999], [999, 999]], "contacts_max": [[0, 0], [0, 0], [0, 0]]}
	for context_value in contexts:
		var context: Dictionary = context_value
		for third in range(3):
			for region in range(2):
				for kind in ["occupancy", "contacts"]:
					var value := int(((context.get(kind, []) as Array)[third] as Array)[region])
					var minimum_row: Array = (result["%s_min" % kind] as Array)[third]
					var maximum_row: Array = (result["%s_max" % kind] as Array)[third]
					minimum_row[region] = mini(int(minimum_row[region]), value)
					maximum_row[region] = maxi(int(maximum_row[region]), value)
	return result


func _rng(seed: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(seed.hash() & 0x7fffffff)
	return rng
