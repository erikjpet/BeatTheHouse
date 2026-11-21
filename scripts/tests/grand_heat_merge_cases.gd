extends RefCounted

# LAND-02 additive synthetic unit snippet, not a standalone runtime launcher.
# Call exercise() from the admitted harness and append its checks/failures.
# No meta store, player profile, save, route offer or fare is accessed here.
const Run := preload("res://scripts/core/run_state.gd")

static func exercise() -> Dictionary:
	var report := {"checks": 0, "failures": [], "cases": [], "fidelity": "Synthetic RunState heat-boundary unit cases; not generated arrival, UI, external re-entry, persistence or full-travel rollback evidence."}
	for row in [
		{"id": "remembered_wins", "prestige": true, "destination": "grand_casino", "source_heat": 20, "remembered": 30, "carried": 10, "expected": 20},
		{"id": "carried_wins", "prestige": true, "destination": "grand_casino", "source_heat": 40, "remembered": 5, "carried": 20, "expected": 10},
		{"id": "ordinary_grand_control", "prestige": false, "destination": "grand_casino", "source_heat": 20, "remembered": 30, "carried": 10, "expected": 30},
		{"id": "prestige_non_grand_control", "prestige": true, "destination": "motel", "source_heat": 20, "remembered": 30, "carried": 10, "expected": 30},
	]:
		_case(row, report)
	return report

static func _case(row: Dictionary, report: Dictionary) -> void:
	var run := Run.new()
	var modifiers := {"grand_casino_prestige": bool(row.prestige), "grand_casino_prestige_recognition_heat_delta": -10}
	run.start_new("LAND02-" + str(row.id), {"mode": "standard", "id": "standard", "seed_text": "LAND02-" + str(row.id), "modifiers": modifiers})
	# Declared synthetic initial state, not a claim of an ordinary offered route.
	run.current_environment = {"id": "back_alley", "archetype_id": "back_alley"}
	run.suspicion["level"] = int(row.source_heat)
	run.suspicion["local_levels"] = {"back_alley": int(row.source_heat)}
	run.suspicion["local_levels"][str(row.destination)] = int(row.remembered)
	var cash_before := run.bankroll
	var clock_before := run.game_clock_minutes
	var heat: Dictionary = run.begin_travel_suspicion_decay({"distance": "near", "risk_decay": 50}, str(row.destination))
	var recognized := bool(row.prestige) and str(row.destination) == "grand_casino"
	_expect(int(heat.get("carried_heat", -1)) == int(row.carried), str(row.id) + ": carried heat", report)
	_expect(bool(heat.get("grand_prestige_heat_preinstalled", false)) == recognized, str(row.id) + ": preinstall gate", report)
	if recognized:
		_expect(int(run.suspicion.local_levels.get("grand_casino", -1)) == maxi(int(row.remembered), int(row.carried)), str(row.id) + ": max merge before install", report)
	var destination := {"id": str(row.destination), "archetype_id": str(row.destination)}
	if str(row.destination) == "grand_casino":
		# Same minimal objective fixture contract as collection_meta_check.gd:962.
		destination["demo_objective"] = {"id": Run.GRAND_CASINO_OBJECTIVE_ID, "type": "bankroll", "target_bankroll": 500, "high_roller_target_bankroll": 500, "high_roller_net_winnings": 30, "high_roller_min_grand_casino_games": 5, "high_roller_max_heat": 30, "players_card_bronze_max_heat": 30, "players_card_silver_max_heat": 30, "players_card_gold_max_heat": 30}
	var installed: Dictionary = run.set_environment(destination)
	_expect(bool(installed.get("ok", false)), str(row.id) + ": synthetic installation accepted", report)
	if not bool(installed.get("ok", false)):
		report.cases.append({"input": row, "install": installed})
		return
	var finished: Dictionary = run.finish_travel_suspicion_decay(heat)
	_expect(run.suspicion_level() == int(row.expected), str(row.id) + ": finish retains correct winner and recognition", report)
	_expect(bool(run.grand_casino_prestige_status().get("recognition_applied", false)) == recognized, str(row.id) + ": recognition control", report)
	if recognized:
		_expect(int(run.narrative_flags.get("grand_casino_max_heat", -1)) == int(row.expected), str(row.id) + ": entry maximum uses recognized heat", report)
		_expect(int(run.narrative_flags.get("grand_casino_players_card_segment_max_heat", -1)) == int(row.expected), str(row.id) + ": segment maximum uses recognized heat", report)
	_expect(run.bankroll == cash_before and run.game_clock_minutes == clock_before, str(row.id) + ": unit seam does not charge fare/time", report)
	report.cases.append({"input": row.duplicate(true), "begin": heat, "finish": finished, "prestige": run.grand_casino_prestige_status()})

static func _expect(ok: bool, label: String, report: Dictionary) -> void:
	report.checks = int(report.checks) + 1
	if not ok:
		report.failures.append(label)
