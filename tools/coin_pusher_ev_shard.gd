extends SceneTree

const CoinPusherGame := preload("res://scripts/games/coin_pusher.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const Ridge := preload("res://scripts/games/coin_pusher/jackpot_ridge.gd")
const Vault := preload("res://scripts/games/coin_pusher/vault_drop.gd")

const DEFAULT_ACCEPTED := 25000
const POLICY_TICKS := 20
const PHASE_BIN_COUNT := 12
const RAIL_FRACTIONS := [0, 250, 500, 750, 1000]

var machine_id := "quarter_falls"
var shard_index := 0
var accepted_target := DEFAULT_ACCEPTED
var out_path := "res://.tmp/coin_pusher_ev_shard.json"
var gutter_x_override := -1
var failed := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--machine="):
			machine_id = argument.trim_prefix("--machine=").strip_edges()
		elif argument.begins_with("--shard="):
			shard_index = int(argument.trim_prefix("--shard="))
		elif argument.begins_with("--accepted="):
			accepted_target = maxi(1, int(argument.trim_prefix("--accepted=")))
		elif argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=").strip_edges()
		elif argument.begins_with("--gutter-x="):
			gutter_x_override = int(argument.trim_prefix("--gutter-x="))
	call_deferred("_run")


func _run() -> void:
	var started_usec := Time.get_ticks_usec()
	var library = ContentLibraryScript.new()
	library.load(false)
	var game = CoinPusherGame.new()
	game.setup(library.game("coin_pusher"), library)
	var definition: Dictionary = game.call("_machine_definition", machine_id)
	var variation_config: Dictionary = game.call("_variation_config", machine_id)
	if definition.is_empty() or not machine_id in ["quarter_falls", "jackpot_ridge", "vault_drop"]:
		_finish({"passed": false, "error": "Unknown production machine definition: %s" % machine_id})
		return
	if gutter_x_override >= 0:
		var overridden_geometry: Dictionary = (definition.get("geometry", {}) as Dictionary).duplicate(true)
		overridden_geometry["gutter_x"] = gutter_x_override
		definition["geometry"] = overridden_geometry
	var seed := "pusherv3_4_ev:%s:shard:%d" % [machine_id, shard_index]
	var root_rng := _rng(seed)
	var opening_count := int(game.call("_opening_coin_count"))
	var simulation := Solver.create_machine(root_rng.fork("opening"), definition, opening_count)
	var variation_state := {}
	if machine_id == "jackpot_ridge":
		variation_state = Ridge.initial_state(variation_config, root_rng.fork("ridge"), int(game.call("_lane_count")), int(game.call("_cell_count")))
	elif machine_id == "vault_drop":
		variation_state = Vault.initial_state(variation_config, root_rng.fork("vault"), int(game.call("_lane_count")), int(game.call("_cell_count")), "ev_shard_%d" % shard_index)
	var machine := {
		"variation_id": machine_id,
		"variation_state": variation_state,
		"simulation": simulation,
		"riders": [],
		"action_count": 0,
	}
	game.call("_sync_physical_features", machine)
	var opening_stock := _body_kind_counts(simulation.get("bodies", []))
	var opening_origin := int(simulation.get("opening_body_count", 0))
	var policy := _policy_descriptor(definition)
	var policy_hash := _sha256(policy)
	var geometry_hash := _sha256({
		"geometry": definition.get("geometry", {}),
		"stroke": definition.get("stroke", {}),
		"apparatus": definition.get("apparatus", {}),
		"coins": definition.get("coins", {}),
		"ceiling": definition.get("ceiling", 0),
	})
	var phase_bins: Array = []
	for _index in range(PHASE_BIN_COUNT):
		phase_bins.append(0)
	var apparatus_counts := {}
	var player_accepted := 0
	var player_refused := 0
	var progression_ticks := 0
	var invariant_failures := 0
	var base_tray_coin_count := 0
	var base_tray_coin_value := 0
	var ridge_credited_coin_value := 0
	var opening_tray_coin_count := 0
	var opening_tray_coin_value := 0
	var feature_tray_count := 0
	var feature_gutter_count := 0
	var physically_banked_fragments := 0
	var drop_rng := root_rng.fork("accepted_inserts")
	var event_rng := root_rng.fork("physical_events")
	while player_accepted < accepted_target:
		var apparatus_label := _apply_apparatus_policy(simulation, definition, player_accepted)
		var before_features := int(simulation.get("accepted_inserts", 0))
		game.call("_prepare_variation_action", machine)
		game.call("_sync_physical_features", machine)
		var feature_insert_delta := int(simulation.get("accepted_inserts", 0)) - before_features
		if feature_insert_delta < 0:
			_fail("Feature reconciliation reduced accepted insert count.")
		var dropped: Dictionary = Solver.add_coin(simulation, drop_rng, int(simulation.get("carriage_x", _definition_width(definition) / 2)), 1, {"ev_shard": shard_index, "ev_insert": player_accepted})
		if not bool(dropped.get("accepted", false)):
			player_refused += 1
			var relief := _advance_and_consume(game, machine, event_rng, POLICY_TICKS)
			progression_ticks += POLICY_TICKS
			invariant_failures += 0 if bool(relief.get("invariants_ok", false)) else 1
			var relief_accounting := _drain_tray(simulation, game)
			base_tray_coin_count += int(relief_accounting["coin_count"])
			base_tray_coin_value += int(relief_accounting["coin_value"])
			ridge_credited_coin_value += int(relief_accounting["credited_coin_value"])
			opening_tray_coin_count += int(relief_accounting["opening_coin_count"])
			opening_tray_coin_value += int(relief_accounting["opening_coin_value"])
			feature_tray_count += int(relief_accounting["feature_count"])
			physically_banked_fragments += int(relief.get("fragments_banked", 0))
			feature_gutter_count += int(relief.get("feature_gutter_count", 0))
			continue
		var period_ticks := maxi(1, int((definition.get("stroke", {}) as Dictionary).get("period_ticks", 240)))
		var phase_bin := clampi(int(int(simulation.get("phase_fp", 0)) * PHASE_BIN_COUNT / (period_ticks * Solver.FP)), 0, PHASE_BIN_COUNT - 1)
		phase_bins[phase_bin] = int(phase_bins[phase_bin]) + 1
		apparatus_counts[apparatus_label] = int(apparatus_counts.get(apparatus_label, 0)) + 1
		player_accepted += 1
		machine["action_count"] = player_accepted
		var advanced := _advance_and_consume(game, machine, event_rng, POLICY_TICKS)
		progression_ticks += POLICY_TICKS
		invariant_failures += 0 if bool(advanced.get("invariants_ok", false)) else 1
		physically_banked_fragments += int(advanced.get("fragments_banked", 0))
		feature_gutter_count += int(advanced.get("feature_gutter_count", 0))
		if player_accepted % 128 == 0:
			var accounting := _drain_tray(simulation, game)
			base_tray_coin_count += int(accounting["coin_count"])
			base_tray_coin_value += int(accounting["coin_value"])
			ridge_credited_coin_value += int(accounting["credited_coin_value"])
			opening_tray_coin_count += int(accounting["opening_coin_count"])
			opening_tray_coin_value += int(accounting["opening_coin_value"])
			feature_tray_count += int(accounting["feature_count"])
	var final_accounting := _drain_tray(simulation, game)
	base_tray_coin_count += int(final_accounting["coin_count"])
	base_tray_coin_value += int(final_accounting["coin_value"])
	ridge_credited_coin_value += int(final_accounting["credited_coin_value"])
	opening_tray_coin_count += int(final_accounting["opening_coin_count"])
	opening_tray_coin_value += int(final_accounting["opening_coin_value"])
	feature_tray_count += int(final_accounting["feature_count"])
	var ending_stock := _body_kind_counts(simulation.get("bodies", []))
	var gutter_stock := _ledger_kind_counts(simulation.get("gutter_ledger", []))
	var ending_origin := _body_origin_counts(simulation.get("bodies", []))
	var gutter_origin := _ledger_origin_counts(simulation.get("gutter_ledger", []))
	var origin := int(simulation.get("opening_body_count", 0)) + int(simulation.get("accepted_inserts", 0))
	var terminal := (simulation.get("bodies", []) as Array).size() + (simulation.get("tray_ledger", []) as Array).size() + (simulation.get("gutter_ledger", []) as Array).size() + int(simulation.get("collected_count", 0))
	var drop_cost := maxi(1, int((definition.get("coins", {}) as Dictionary).get("drop_cost", 1)))
	var wagered := player_accepted * drop_cost
	var physical_roi := float(base_tray_coin_value) / float(maxi(1, wagered))
	var credited_roi := float(ridge_credited_coin_value) / float(maxi(1, wagered))
	var coverage_ok := phase_bins.all(func(value): return int(value) > 0) and apparatus_counts.values().all(func(value): return int(value) > 0)
	var conservation_ok := origin == terminal
	var report := {
		"schema": "coin_pusher_v3_physical_ev_shard_v1",
		"machine_id": machine_id,
		"shard_index": shard_index,
		"seed": seed,
		"accepted_target": accepted_target,
		"accepted_player_inserts": player_accepted,
		"refused_attempts_returned": player_refused,
		"progression_ticks": progression_ticks,
		"machine_instances": 1,
		"pile_resets": 0,
		"no_favorable_reset": true,
		"diagnostic_geometry_override": {"gutter_x": gutter_x_override} if gutter_x_override >= 0 else {},
		"solver_backend": Solver.last_step_backend_for_test(),
		"policy": policy,
		"policy_sha256": policy_hash,
		"geometry_sha256": geometry_hash,
		"coverage": {"phase_bins": phase_bins, "apparatus": apparatus_counts, "complete": coverage_ok},
		"accounting": {
			"opening_origin_count": opening_origin,
			"opening_stock_by_kind": opening_stock,
			"solver_accepted_inserts_including_features": int(simulation.get("accepted_inserts", 0)),
			"player_accepted_inserts": player_accepted,
			"feature_accepted_inserts": int(simulation.get("accepted_inserts", 0)) - player_accepted,
			"ending_active_by_kind": ending_stock,
			"ending_active_by_origin": ending_origin,
			"ending_active_count": (simulation.get("bodies", []) as Array).size(),
			"tray_after_collection_count": (simulation.get("tray_ledger", []) as Array).size(),
			"gutter_by_kind": gutter_stock,
			"gutter_by_origin": gutter_origin,
			"gutter_count": (simulation.get("gutter_ledger", []) as Array).size(),
			"collected_count": int(simulation.get("collected_count", 0)),
			"origin_count": origin,
			"terminal_count": terminal,
			"conservation_ok": conservation_ok,
		},
		"economy": {
			"wagered": wagered,
			"base_physical_coin_tray_count": base_tray_coin_count,
			"base_physical_coin_tray_value": base_tray_coin_value,
			"base_physical_coin_to_tray_roi": physical_roi,
			"opening_coin_tray_count_excluded_from_roi": opening_tray_coin_count,
			"opening_coin_tray_value_excluded_from_roi": opening_tray_coin_value,
			"ridge_credited_coin_tray_value": ridge_credited_coin_value,
			"ridge_credited_roi": credited_roi,
			"feature_tray_count_excluded_from_base_roi": feature_tray_count,
			"feature_gutter_count": feature_gutter_count,
			"physically_banked_fragments_excluded_from_base_roi": physically_banked_fragments,
			"vault_banked_fragments_state": int(variation_state.get("banked_fragments", 0)) if machine_id == "vault_drop" else 0,
			"vault_option_value_basis": variation_config.get("documented_ev_by_meter", {}) if machine_id == "vault_drop" else {},
			"vault_option_value_merged_into_physical_roi": false,
			"documented_physical_roi_band": (definition.get("economy", {}) as Dictionary).get("documented_ev_band", []),
		},
		"assertions": {
			"accepted_exact": player_accepted == accepted_target,
			"real_solver_progression": progression_ticks > player_accepted,
			"coverage_complete": coverage_ok,
			"conservation": conservation_ok,
			"invariants": invariant_failures == 0,
			"no_favorable_reset": true,
			"native_solver": Solver.last_step_backend_for_test() == "native_v3",
		},
		"elapsed_seconds": float(Time.get_ticks_usec() - started_usec) / 1000000.0,
	}
	report["passed"] = (report["assertions"] as Dictionary).values().all(func(value): return bool(value))
	_finish(report)


func _advance_and_consume(game, machine: Dictionary, rng: RngStream, ticks: int) -> Dictionary:
	var simulation: Dictionary = machine["simulation"]
	var stepped := Solver.step_ticks(simulation, {"motor_enabled": true}, ticks)
	var events: Array = stepped.get("events", []) if typeof(stepped.get("events", [])) == TYPE_ARRAY else []
	game.call("_consume_physics_events", null, machine, events, rng)
	var fragments_banked := 0
	var feature_gutter_count := 0
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var body_kind := str(event.get("body_kind", ""))
		var outcome := str(event.get("outcome", ""))
		if body_kind == "fragment" and outcome == "tray":
			fragments_banked += 1
		if body_kind != "coin" and outcome == "gutter":
			feature_gutter_count += 1
	var invariants: Dictionary = stepped.get("invariants", {}) if typeof(stepped.get("invariants", {})) == TYPE_DICTIONARY else {}
	return {"invariants_ok": bool(invariants.get("energy_ok", false)) and bool(invariants.get("conservation_ok", false)), "fragments_banked": fragments_banked, "feature_gutter_count": feature_gutter_count}


func _drain_tray(simulation: Dictionary, game) -> Dictionary:
	var coin_count := 0
	var coin_value := 0
	var credited_coin_value := 0
	var opening_coin_count := 0
	var opening_coin_value := 0
	var feature_count := 0
	var ledger: Array = simulation.get("tray_ledger", []) if typeof(simulation.get("tray_ledger", [])) == TYPE_ARRAY else []
	for entry_value in ledger:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("kind", "coin")) == "coin":
			var provenance: Dictionary = entry.get("provenance", {}) if typeof(entry.get("provenance", {})) == TYPE_DICTIONARY else {}
			var value := maxi(0, int(entry.get("value", 0)))
			if provenance.has("ev_shard"):
				coin_count += 1
				coin_value += value
				credited_coin_value += value * maxi(1, int(provenance.get("ridge_multiplier", 1)))
			else:
				opening_coin_count += 1
				opening_coin_value += value
		else:
			feature_count += 1
	Solver.collect_tray(simulation)
	return {"coin_count": coin_count, "coin_value": coin_value, "credited_coin_value": credited_coin_value, "opening_coin_count": opening_coin_count, "opening_coin_value": opening_coin_value, "feature_count": feature_count}


func _apply_apparatus_policy(simulation: Dictionary, definition: Dictionary, accepted_index: int) -> String:
	var apparatus: Dictionary = definition.get("apparatus", {}) if typeof(definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
	if str(apparatus.get("type", "rail_slot")) == "hole_set":
		var holes: Array = apparatus.get("holes", []) if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else []
		var hole_index := accepted_index % maxi(1, holes.size())
		Solver.select_hole(simulation, hole_index)
		return "hole_%d" % hole_index
	var rail: Dictionary = apparatus.get("rail", {}) if typeof(apparatus.get("rail", {})) == TYPE_DICTIONARY else {}
	var rail_min := int(rail.get("x_min", 8000))
	var rail_max := int(rail.get("x_max", 92000))
	var fraction := int(RAIL_FRACTIONS[accepted_index % RAIL_FRACTIONS.size()])
	Solver.set_carriage(simulation, rail_min + (rail_max - rail_min) * fraction / 1000)
	return "rail_%d" % fraction


func _policy_descriptor(definition: Dictionary) -> Dictionary:
	return {
		"id": "persistent_round_robin_v1",
		"ticks_after_each_attempt": POLICY_TICKS,
		"phase_bin_count": PHASE_BIN_COUNT,
		"rail_fractions_milli": RAIL_FRACTIONS,
		"hole_selection": "accepted_index_mod_hole_count",
		"ceiling_behavior": "refused coin returned; same persistent machine advances and retries",
		"collection": "tray collected every 128 accepted drops; collection does not advance or reset physics",
		"tail_progression": "none beyond the same policy ticks following the final accepted insert",
		"apparatus_type": str((definition.get("apparatus", {}) as Dictionary).get("type", "")),
	}


func _body_kind_counts(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			var kind := str((value as Dictionary).get("kind", "coin"))
			result[kind] = int(result.get(kind, 0)) + 1
	return result


func _ledger_kind_counts(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			var kind := str((value as Dictionary).get("kind", "coin"))
			result[kind] = int(result.get(kind, 0)) + 1
	return result


func _body_origin_counts(values: Array) -> Dictionary:
	var result := {"paid_coin": 0, "opening_coin": 0, "feature": 0}
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = value
		if str(body.get("kind", "coin")) != "coin":
			result["feature"] = int(result["feature"]) + 1
			continue
		var meta: Dictionary = body.get("meta", {}) if typeof(body.get("meta", {})) == TYPE_DICTIONARY else {}
		var provenance: Dictionary = meta.get("provenance", {}) if typeof(meta.get("provenance", {})) == TYPE_DICTIONARY else {}
		var key := "paid_coin" if provenance.has("ev_shard") else "opening_coin"
		result[key] = int(result[key]) + 1
	return result


func _ledger_origin_counts(values: Array) -> Dictionary:
	var result := {"paid_coin": 0, "opening_coin": 0, "feature": 0}
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		if str(entry.get("kind", "coin")) != "coin":
			result["feature"] = int(result["feature"]) + 1
			continue
		var provenance: Dictionary = entry.get("provenance", {}) if typeof(entry.get("provenance", {})) == TYPE_DICTIONARY else {}
		var key := "paid_coin" if provenance.has("ev_shard") else "opening_coin"
		result[key] = int(result[key]) + 1
	return result


func _definition_width(definition: Dictionary) -> int:
	return int((definition.get("geometry", {}) as Dictionary).get("width", Solver.WIDTH))


func _sha256(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(value, "", true).to_utf8_buffer())
	return context.finish().hex_encode()


func _rng(seed: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(seed.hash() & 0x7fffffff)
	return rng


func _fail(message: String) -> void:
	failed = true
	push_error(message)


func _finish(report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write EV shard report: %s" % out_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	var passed := bool(report.get("passed", false)) and not failed
	print("COIN_PUSHER_EV_SHARD_%s machine=%s shard=%d accepted=%d out=%s" % ["PASS" if passed else "FAIL", machine_id, shard_index, int(report.get("accepted_player_inserts", 0)), ProjectSettings.globalize_path(out_path)])
	quit(0 if passed else 1)
