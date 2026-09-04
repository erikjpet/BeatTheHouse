extends "res://tools/endgame_metrics_probe.gd"

# Opt-in, seeded 0.6 cross-system economy audit. The ordinary game/travel/event
# paths reuse endgame_metrics_probe's production drivers. Specialized strategies
# use the production RunState state machines while modeling only human contact
# selection at explicit action boundaries. Jobs, the Numbers, and The Count's
# tables/deliveries settle through production.

const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const CrewRecruitmentModelScript := preload("res://scripts/core/crew_recruitment_model.gd")
const CrewHeistModelScript := preload("res://scripts/core/crew_heist_model.gd")
const CrewTurnModelScript := preload("res://scripts/core/crew_turn_model.gd")

const TOOL_ID := "cross_economy_audit_v1"
const DEFAULT_SEEDS_PER_STYLE := 64
const DEFAULT_MAX_ACTIONS := 208
const AUDIT_DEFAULT_SEED_PREFIX := "BALANCE06-1"
const DEFAULT_OUTPUT := "res://.tmp/balance06_1/cross_economy_audit.json"
const DEBT_THRESHOLDS := [1, 25, 45, 90]
const SPECIALIST_ACTION_BUDGET := 64
const NUMBERS_SPECIALIST_ACTION_BUDGET := 112
const PUSHER_DROP_BUDGET := 64
const OPPORTUNITY_SYSTEMS := [
	"games", "jobs", "crew", "plays", "numbers", "deliveries", "heists",
	"items", "services", "events", "travel", "lenders_debt", "heat",
	"scenarios", "pusher_machines",
]
const PLAYSTYLES := [
	{"id": "control_crew_ignoring", "policy": "clean", "label": "Crew-ignoring 0.5-compatible control"},
	{"id": "pure_gambler", "policy": "clean", "label": "Pure gambler"},
	{"id": "crew_maximizer", "policy": "tier2", "label": "Crew job maximizer"},
	{"id": "numbers_specialist", "policy": "clean", "label": "Numbers specialist"},
	{"id": "coin_pusher_grinder", "policy": "clean", "label": "Persisted coin-pusher grinder"},
	{"id": "cheater", "policy": "cheat", "label": "Cheater"},
	{"id": "heist_rusher", "policy": "clean", "label": "Crew heist rusher (seed-alternating plans)"},
	{"id": "mixed_opportunist", "policy": "tier2", "label": "Mixed opportunist"},
]

var _active_style := ""


func _run() -> void:
	var options := _audit_options()
	var seeds_per_style := maxi(1, int(options.get("seeds_per_style", DEFAULT_SEEDS_PER_STYLE)))
	var seed_start := maxi(1, int(options.get("seed_start", 1)))
	var max_actions := maxi(8, int(options.get("max_actions", DEFAULT_MAX_ACTIONS)))
	var seed_prefix := str(options.get("seed_prefix", AUDIT_DEFAULT_SEED_PREFIX)).strip_edges()
	var style_filter := str(options.get("playstyle", "")).strip_edges()
	var output := str(options.get("output", DEFAULT_OUTPUT)).strip_edges()
	var build_ref := str(options.get("build_ref", "UNSPECIFIED")).strip_edges()

	library = ContentLibraryScript.new()
	library.load(false)
	for error_value in library.validation_errors:
		failures.append("Content validation error: %s" % str(error_value))
	for warning_value in library.validation_warnings:
		warnings.append("Content validation warning: %s" % str(warning_value))
	generator = RunGeneratorScript.new(library)
	_build_game_modules()
	_check_public_observer_isolation()
	_check_hostile_policy_input_rejection()

	var runs: Array = []
	for style_value in PLAYSTYLES:
		var style: Dictionary = style_value
		if not style_filter.is_empty() and style_filter != str(style.get("id", "")):
			continue
		for seed_offset in range(seeds_per_style):
			var seed_index := seed_start + seed_offset
			var seed := "%s-%s-%03d" % [seed_prefix, str(style.get("id", "")), seed_index]
			runs.append(_simulate_audit_run(style, seed, max_actions))

	var report := {
		"tool": TOOL_ID,
		"build_ref": build_ref,
		"deterministic": true,
		"clock_model": "RunState action boundaries only; no wall-clock reads",
		"seed_prefix": seed_prefix,
		"seeds_per_playstyle": seeds_per_style,
		"seed_start": seed_start,
		"playstyle_filter": style_filter,
		"max_actions": max_actions,
		"run_count": runs.size(),
		"playstyles": PLAYSTYLES,
		"specialized_driver_contract": {
			"ordinary_games_travel_events_services_lenders_endgame": "production module and RunState paths inherited from endgame_metrics_probe.gd",
			"crew_jobs": "one-boundary deterministic contact selection; production acceptance, delivery/stake play, route cost/risk, resolution, trust, and cash",
			"numbers": "production fix bribe delivery, camouflage allocation, slip settlement/payday, and ordinary slip purchase paths",
			"coin_pusher": "paid public travel to a naturally generated casino room; grind only when the seed offers a pusher; never reset; real run RNG, drops, fixed-tick patches, and post-drop COLLECT",
			"heist": "public recruitment, job, planning-table, and live-table actions only; stable seeds alternate both accepted plans through production lock, setup, play, interview/getaway, and terminal paths",
		},
		"measurement_interpretation": {
			"censoring": "Action-cap survivors remain active RunState observations and are excluded from observed-terminal pressure/choice denominators.",
			"specialization_budget": "Crew specializes through action 64, Numbers through action 112 after one real runner route, and pusher for 64 paid drops. They then return to the ordinary endgame driver so the global cap is a censoring guard rather than their planned ending.",
			"pusher": "Unconditional natural availability plus reached-machine conditional distributions.",
			"specialists": "Policies act only on naturally visible Crew contacts and record inaccessible, visible-not-selected, selected, accepted, rejected, and settled opportunity denominators.",
			"heist": "The policy never injects audit_night; unavailable routes remain explicit unavailable/censored observations.",
			"legacy_control": "Current quantitative control plus separate two-seed 0.5 structural compatibility evidence; no historical distribution inference.",
		},
		"source_register": _source_register(),
		"aggregate": _audit_aggregate(runs, max_actions),
		"runs": runs,
		"failures": failures,
		"warnings": warnings,
		"passed": failures.is_empty() and not runs.is_empty(),
	}
	var wrote_report := _write_audit_json(output, report)
	var aggregate := _dict(report.get("aggregate", {}))
	var passed := bool(report["passed"]) and wrote_report
	print("CROSS_ECONOMY_AUDIT_%s runs=%d styles=%d output=%s" % ["PASS" if passed else "FAIL", runs.size(), _array(aggregate.get("playstyles", [])).size(), ProjectSettings.globalize_path(output)])
	await _finish(0 if passed else 1)


func _audit_options() -> Dictionary:
	var options := {}
	for arg_value in OS.get_cmdline_user_args():
		var arg := str(arg_value)
		if arg.begins_with("--seeds-per-style="):
			options["seeds_per_style"] = int(arg.trim_prefix("--seeds-per-style="))
		elif arg.begins_with("--seed-start="):
			options["seed_start"] = int(arg.trim_prefix("--seed-start="))
		elif arg.begins_with("--max-actions="):
			options["max_actions"] = int(arg.trim_prefix("--max-actions="))
		elif arg.begins_with("--seed-prefix="):
			options["seed_prefix"] = arg.trim_prefix("--seed-prefix=")
		elif arg.begins_with("--playstyle="):
			options["playstyle"] = arg.trim_prefix("--playstyle=")
		elif arg.begins_with("--output="):
			options["output"] = arg.trim_prefix("--output=")
		elif arg.begins_with("--build-ref="):
			options["build_ref"] = arg.trim_prefix("--build-ref=")
	return options


func _source_register() -> Dictionary:
	var games := _json_array("res://data/games/games.json")
	var items := _json_array("res://data/items/items.json")
	var events := _json_array("res://data/events/events.json")
	return {
		"contract": "Exact data-defined economy register; production module paths remain authoritative for full-simulation paytables.",
		"economy_checkpoint": _json_value("res://data/economy/content06_1_audit.json"),
		"games": games,
		"crew_jobs": _json_array("res://data/crew/jobs.json"),
		"crew_plays": _json_value("res://data/crew/plays.json"),
		"numbers": _json_value("res://data/crew/numbers.json"),
		"heists": _json_value("res://data/crew/heist.json"),
		"items": items,
		"services": _json_array("res://data/services/services.json"),
		"lenders": _json_array("res://data/debt/lenders.json"),
		"travel_routes": _json_array("res://data/travel/routes.json"),
		"events": events,
		"legacy_control_baseline": _json_value("res://scripts/tests/fixtures/crew06_5_ignored_run_baseline.json"),
	}


func _json_value(path: String) -> Variant:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		failures.append("Could not parse source-register file: %s" % path)
		return {}
	return parsed


func _json_array(path: String) -> Array:
	return _array(_json_value(path))


func _check_public_observer_isolation() -> void:
	var left: RunState = RunStateScript.new()
	var right: RunState = RunStateScript.new()
	var challenge := RunStateScript.standard_challenge("BALANCE06-PUBLIC-OBSERVER")
	left.start_new("BALANCE06-PUBLIC-OBSERVER", challenge)
	right.start_new("BALANCE06-PUBLIC-OBSERVER", challenge)
	generator.next_environment(left)
	generator.next_environment(right)
	var left_heist := _dict(left.crew_heist_state).duplicate(true)
	var right_heist := _dict(right.crew_heist_state).duplicate(true)
	left_heist["x"] = {"future_outcome": "left", "private_roll": 1}
	right_heist["x"] = {"future_outcome": "right", "private_roll": 999}
	left.crew_heist_state = left_heist
	right.crew_heist_state = right_heist
	if JSON.stringify(_policy_observation(left)) != JSON.stringify(_policy_observation(right)):
		failures.append("Public policy observation changed when only private heist authority changed.")


func _check_hostile_policy_input_rejection() -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BALANCE06-HOSTILE-POLICY", RunStateScript.standard_challenge("BALANCE06-HOSTILE-POLICY"))
	generator.next_environment(run_state)
	var baseline := _policy_observation(run_state)
	var hostile := baseline.duplicate(true)
	for key in ["seed", "rng_state", "future_numbers_draw", "turn_traitor", "heist_outcome", "caller_reward", "caller_capability", "terminal_status"]:
		hostile[key] = "forged"
	if JSON.stringify(_sanitize_policy_observation(hostile)) != JSON.stringify(baseline):
		failures.append("Audit policy sanitizer accepted caller-authored authority or hidden state.")

	# Travel is the only audit helper that accepts a structured action selected
	# from a public list. Prove that its id is merely re-resolved against the live
	# action surface and every caller-authored authority field is ignored.
	var canonical_run: RunState = RunStateScript.new()
	var hostile_run: RunState = RunStateScript.new()
	var challenge := RunStateScript.standard_challenge("BALANCE06-HOSTILE-TRAVEL")
	canonical_run.start_new("BALANCE06-HOSTILE-TRAVEL", challenge)
	generator.next_environment(canonical_run)
	# Fork from one exact persisted boundary. Independently created RunStates
	# deliberately have different non-public authority identities, which are not
	# a policy-visible determinism difference.
	hostile_run.from_dict(canonical_run.to_dict())
	var selected := {}
	for choice_value in _travel_choices(canonical_run):
		var public_choice := _dict(choice_value)
		if bool(public_choice.get("enabled", false)):
			selected = public_choice
			break
	if selected.is_empty():
		failures.append("Hostile travel qualification seed exposed no public enabled route.")
	else:
		# Equalize the public-observation call count before comparing action
		# outcomes; the hostile actor sees the same list before substituting its
		# local payload.
		_travel_choices(hostile_run)
		var forged := {"id": str(selected.get("id", ""))}
		forged.merge({
			"seed": "FORGED", "game_id": "FORGED", "node_id": "FORGED",
			"route": {"id": "FORGED", "cost": -999999, "suspicion_delta": -999999, "reward": 999999},
			"status": {"suspicion_delta": -999999, "available": true, "capability": "FORGED"},
			"cost": -999999, "member_id": "FORGED", "job_id": "FORGED",
			"debt": -999999, "receipt": "FORGED", "delivery_status": "complete",
			"reward": 999999, "payout": 999999, "outcome": "victory",
			"availability": true, "capability": "FORGED", "rng_state": 1,
			"value_manifest": {"bankroll": 999999}, "terminal_status": "victory",
		}, true)
		var canonical_audit := {"travel_count": 0, "route_cost_total": 0, "grand_casino_entries": 0}
		var hostile_audit := canonical_audit.duplicate(true)
		var canonical_ok := _apply_travel_choice(canonical_run, canonical_audit, selected)
		var hostile_ok := _apply_travel_choice(hostile_run, hostile_audit, forged)
		var state_equal := CrewTurnModelScript.canonical_json(canonical_run.to_dict()) == CrewTurnModelScript.canonical_json(hostile_run.to_dict())
		var audit_equal := CrewTurnModelScript.canonical_json(canonical_audit) == CrewTurnModelScript.canonical_json(hostile_audit)
		if not canonical_ok or not hostile_ok or not state_equal or not audit_equal:
			failures.append("Audit travel seam consumed caller-authored route/cost/authority fields (canonical_ok=%s hostile_ok=%s state_equal=%s audit_equal=%s state_path=%s state_keys=%s audit_keys=%s)." % [
				str(canonical_ok), str(hostile_ok), str(state_equal), str(audit_equal),
				_first_mismatch_path(canonical_run.to_dict(), hostile_run.to_dict()),
				JSON.stringify(_top_level_mismatch_keys(canonical_run.to_dict(), hostile_run.to_dict())),
				JSON.stringify(_top_level_mismatch_keys(canonical_audit, hostile_audit)),
			])

	# A rejected opaque id must leave the complete serialized root unchanged;
	# that snapshot includes economy, world, crew, machine, queues, receipts,
	# saves, and every persisted RNG stream owned by RunState.
	var rejected_run: RunState = RunStateScript.new()
	rejected_run.start_new("BALANCE06-HOSTILE-REJECTION", RunStateScript.standard_challenge("BALANCE06-HOSTILE-REJECTION"))
	generator.next_environment(rejected_run)
	var rejected_audit := {"travel_count": 0, "route_cost_total": 0, "grand_casino_entries": 0}
	var rejected_state_before := CrewTurnModelScript.canonical_json(rejected_run.to_dict())
	var rejected_audit_before := CrewTurnModelScript.canonical_json(rejected_audit)
	if _apply_travel_choice(rejected_run, rejected_audit, {"id": "FORGED", "route": {"cost": -999999}, "terminal_status": "victory"}) \
			or CrewTurnModelScript.canonical_json(rejected_run.to_dict()) != rejected_state_before or CrewTurnModelScript.canonical_json(rejected_audit) != rejected_audit_before:
		failures.append("Rejected hostile travel proposal changed canonical state.")
	var service := RunActionServiceScript.new()
	service.setup(library, rejected_run)
	if bool(service.use_hook("FORGED", "FORGED").get("ok", false)) or CrewTurnModelScript.canonical_json(rejected_run.to_dict()) != rejected_state_before:
		failures.append("Rejected hostile item/service/lender proposal changed canonical state.")
	if bool(rejected_run.crew_job_accept_definition("FORGED").get("ok", false)) or CrewTurnModelScript.canonical_json(rejected_run.to_dict()) != rejected_state_before:
		failures.append("Rejected hostile member/job proposal changed canonical state.")


func _top_level_mismatch_keys(left: Dictionary, right: Dictionary) -> Array:
	var keys: Array = left.keys()
	for key_value in right.keys():
		if not keys.has(key_value):
			keys.append(key_value)
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	var result: Array = []
	for key_value in keys:
		if not left.has(key_value) or not right.has(key_value) or CrewTurnModelScript.canonical_json(left.get(key_value)) != CrewTurnModelScript.canonical_json(right.get(key_value)):
			result.append(str(key_value))
	return result


func _first_mismatch_path(left: Variant, right: Variant, path: String = "root") -> String:
	if typeof(left) != typeof(right):
		return "%s:type" % path
	if typeof(left) == TYPE_DICTIONARY:
		var left_dict := _dict(left)
		var right_dict := _dict(right)
		var keys: Array = left_dict.keys()
		for key_value in right_dict.keys():
			if not keys.has(key_value):
				keys.append(key_value)
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key_value in keys:
			if not left_dict.has(key_value) or not right_dict.has(key_value):
				return "%s.%s:missing" % [path, str(key_value)]
			var nested := _first_mismatch_path(left_dict.get(key_value), right_dict.get(key_value), "%s.%s" % [path, str(key_value)])
			if not nested.is_empty():
				return nested
		return ""
	if typeof(left) == TYPE_ARRAY:
		var left_array := _array(left)
		var right_array := _array(right)
		if left_array.size() != right_array.size():
			return "%s:size" % path
		for index in range(left_array.size()):
			var nested := _first_mismatch_path(left_array[index], right_array[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return ""
	return "" if left == right else path


func _sanitize_policy_observation(value: Dictionary) -> Dictionary:
	var clean := {}
	for key in ["world_node_id", "archetype_id", "bankroll", "heat", "terminal", "game_ids", "crew_presence", "delivery_active", "numbers", "numbers_desk", "heist", "heist_planning"]:
		if value.has(key):
			clean[key] = value[key]
	return clean


func _policy_observation(run_state: RunState) -> Dictionary:
	var public_crew: Array = []
	for value in _array(run_state.current_environment.get("crew_presence", [])):
		var source := _dict(value)
		var member := {}
		for key in ["member_id", "presentation_id", "pose", "public_state"]:
			if source.has(key):
				member[key] = source[key]
		if not member.is_empty():
			public_crew.append(member)
	return {
		"world_node_id": run_state.current_world_node_id(),
		"archetype_id": str(run_state.current_environment.get("archetype_id", "")),
		"bankroll": run_state.bankroll,
		"heat": run_state.suspicion_level(),
		"terminal": run_state.is_terminal(),
		"game_ids": _string_array(run_state.current_environment.get("game_ids", [])),
		"crew_presence": public_crew,
		"delivery_active": run_state.delivery_has_active_run(),
		"numbers": run_state.numbers_status(),
		"numbers_desk": run_state.numbers_desk_status(),
		"heist": run_state.crew_heist_snapshot(),
		"heist_planning": run_state.crew_heist_planning_status(),
	}


func _empty_opportunity_ledger() -> Dictionary:
	var ledger := {}
	for system_id in OPPORTUNITY_SYSTEMS:
		ledger[system_id] = {"observations": 0, "available_actions": 0, "visible": 0, "inaccessible": 0, "selected": 0, "accepted": 0, "rejected": 0, "settled": 0, "visible_not_selected": 0}
	return ledger


func _public_opportunity_ids(run_state: RunState) -> Dictionary:
	var result := {}
	for system_id in OPPORTUNITY_SYSTEMS:
		result[system_id] = []
	var environment := run_state.current_environment
	var game_ids := _string_array(environment.get("game_ids", []))
	for game_id in game_ids:
		_append_offer_id(result, "games", "game:%s" % game_id)
	if game_ids.has("coin_pusher"):
		_append_offer_id(result, "pusher_machines", "game:coin_pusher")
	for offer_value in run_state.crew_job_board_offers():
		_append_offer_id(result, "jobs", "job:%s" % str(_dict(offer_value).get("definition_id", "")))
	for presence_value in _array(environment.get("crew_presence", [])):
		var member_id := str(_dict(presence_value).get("member_id", ""))
		if not member_id.is_empty():
			_append_offer_id(result, "crew", "crew:%s" % member_id)
	var recruitment_ids := CrewRecruitmentModelScript.recruitment_event_ids()
	for event_id_value in _current_event_ids(run_state):
		var event_id := str(event_id_value)
		_append_offer_id(result, "events", "event:%s" % event_id)
		if recruitment_ids.has(event_id):
			_append_offer_id(result, "crew", "recruit:%s" % event_id)
	var active_game_id := str(environment.get("active_game_id", ""))
	if not active_game_id.is_empty():
		for play_value in run_state.crew_play_actions(active_game_id, environment):
			_append_offer_id(result, "plays", str(_dict(play_value).get("id", "")))
	var numbers := run_state.numbers_status()
	for venue_value in _array(numbers.get("venue_status", [])):
		var venue := _dict(venue_value)
		if bool(venue.get("open", false)):
			_append_offer_id(result, "numbers", "numbers:book:%s" % str(venue.get("id", "")))
	var desk := run_state.numbers_desk_status()
	if bool(desk.get("runner_available", false)):
		_append_offer_id(result, "numbers", "numbers:runner")
	if bool(desk.get("fix_available", false)) or str(desk.get("fix_stage", "locked")) != "locked":
		_append_offer_id(result, "numbers", "numbers:fix:%s" % str(desk.get("fix_stage", "locked")))
	if run_state.delivery_has_active_run():
		_append_offer_id(result, "deliveries", "delivery:%s" % str(run_state.delivery_snapshot().get("run_id", "active")))
	var planning := run_state.crew_heist_planning_status()
	for plan_value in _array(planning.get("plans", [])):
		var plan := _dict(plan_value)
		if bool(plan.get("live", false)):
			_append_offer_id(result, "heists", "heist:%s" % str(plan.get("id", "")))
	var heist := run_state.crew_heist_snapshot()
	if str(heist.get("status", "")) not in ["", "idle", "available"]:
		_append_offer_id(result, "heists", "heist:%s:%s" % [str(heist.get("plan_id", "active")), str(heist.get("status", "active"))])
	var service := RunActionServiceScript.new()
	service.setup(library, run_state)
	for item_value in service.item_offer_view_list():
		_append_offer_id(result, "items", "item:%s" % str(_dict(item_value).get("id", "")))
	for service_value in service.service_hook_view_list():
		_append_offer_id(result, "services", "service:%s" % str(_dict(service_value).get("id", "")))
	for lender_value in service.lender_hook_view_list():
		_append_offer_id(result, "lenders_debt", "lender:%s" % str(_dict(lender_value).get("id", "")))
	for choice_value in _travel_choices(run_state):
		var choice := _dict(choice_value)
		if bool(choice.get("enabled", false)):
			_append_offer_id(result, "travel", "travel:%s" % str(choice.get("id", "")))
	_append_offer_id(result, "heat", "heat:current")
	var scenario_state := _dict(environment.get("scenario_state", {}))
	var scenario_id := str(scenario_state.get("scenario_id", environment.get("scenario_id", "")))
	if not scenario_id.is_empty():
		_append_offer_id(result, "scenarios", "scenario:%s" % scenario_id)
	return result


func _append_offer_id(result: Dictionary, system_id: String, offer_id: String) -> void:
	var clean_id := offer_id.strip_edges()
	if clean_id.is_empty() or clean_id.ends_with(":"):
		return
	var ids := _array(result.get(system_id, []))
	if not ids.has(clean_id):
		ids.append(clean_id)
	result[system_id] = ids


func _record_public_opportunities(opportunity_ids: Dictionary, run: Dictionary) -> void:
	var ledger := _dict(run.get("opportunities", {}))
	for system_id in OPPORTUNITY_SYSTEMS:
		var row := _dict(ledger.get(system_id, {}))
		var offered_count := _array(opportunity_ids.get(system_id, [])).size()
		row["observations"] = int(row.get("observations", 0)) + 1
		if offered_count > 0:
			row["available_actions"] = int(row.get("available_actions", 0)) + 1
			row["visible"] = int(row.get("visible", 0)) + offered_count
		else:
			row["inaccessible"] = int(row.get("inaccessible", 0)) + 1
		ledger[system_id] = row
	run["opportunities"] = ledger


func _selected_opportunity_events(label: String) -> Array:
	var events: Array = []
	if label.begins_with("game:") or label.begins_with("heist_identity_session") or label.begins_with("heist_live_round"):
		events.append({"system": "games", "settled": true})
	if label == "coin_pusher_drop":
		events.append_array([{"system": "games", "settled": true}, {"system": "pusher_machines", "settled": true}])
	if label == "coin_pusher_seek_travel" or label.begins_with("crew_recruit_seek:") or label.begins_with("crew_seek:"):
		events.append({"system": "travel", "settled": true})
	if label == "crew_job_accept":
		events.append({"system": "jobs", "settled": false})
	if label.begins_with("crew_recruitment_event:"):
		events.append_array([{"system": "crew", "settled": true}, {"system": "events", "settled": true}])
	if label.begins_with("numbers") or label == "mixed_numbers_slip":
		if label.contains("travel"):
			events.append({"system": "travel", "settled": true})
		elif not label.ends_with("_wait"):
			events.append({"system": "numbers", "settled": not label.ends_with("_begin")})
	if label.contains("delivery") or label.contains("schedule") or label.contains("swap_cart") or label.contains("getaway") or label.ends_with("_work"):
		events.append({"system": "deliveries", "settled": not label.contains("travel") and not label.ends_with("_begin")})
	if label.begins_with("heist"):
		events.append({"system": "heists", "settled": label.contains("round") or label.contains("getaway")})
	if label.begins_with("item:"):
		events.append({"system": "items", "settled": true})
	if label.begins_with("service:"):
		events.append({"system": "services", "settled": true})
	if label in ["event", "progression", "endgame", "specialist_visible_event"]:
		events.append({"system": "events", "settled": true})
	if label.begins_with("travel:") or label.contains("_travel"):
		events.append({"system": "travel", "settled": true})
	if label in ["lender", "crew_marker_loan"]:
		events.append({"system": "lenders_debt", "settled": true})
	var unique: Array = []
	var seen := {}
	for event_value in events:
		var event := _dict(event_value)
		var system_id := str(event.get("system", ""))
		if system_id.is_empty() or seen.has(system_id):
			continue
		seen[system_id] = true
		unique.append(event)
	return unique


func _record_selected_opportunity(run_state: RunState, run: Dictionary, label: String, opportunity_ids: Dictionary) -> void:
	var ledger := _dict(run.get("opportunities", {}))
	var records := _array(run.get("opportunity_records", []))
	var selected_events := _selected_opportunity_events(label)
	if label in ["event", "progression", "endgame", "specialist_visible_event"] and not _array(opportunity_ids.get("scenarios", [])).is_empty():
		selected_events.append({"system": "scenarios", "settled": true})
	for event_value in selected_events:
		var event := _dict(event_value)
		var system_id := str(event.get("system", ""))
		var offered_ids := _array(opportunity_ids.get(system_id, []))
		if offered_ids.is_empty():
			failures.append("Policy selected %s for %s without a public pre-action opportunity in seed %s." % [label, system_id, run_state.seed_text])
			continue
		var row := _dict(ledger.get(system_id, {}))
		row["selected"] = int(row.get("selected", 0)) + 1
		row["accepted"] = int(row.get("accepted", 0)) + 1
		if bool(event.get("settled", false)):
			row["settled"] = int(row.get("settled", 0)) + 1
		ledger[system_id] = row
		records.append({"action": int(run.get("actions", 0)), "system": system_id, "offered_ids": offered_ids, "selection": label, "outcome": "settled" if bool(event.get("settled", false)) else "accepted"})
	run["opportunities"] = ledger
	run["opportunity_records"] = records


func _record_new_job_settlements(run_state: RunState, run: Dictionary) -> void:
	var observed := _array(run.get("observed_settled_job_ids", []))
	var ledger := _dict(run.get("opportunities", {}))
	var records := _array(run.get("opportunity_records", []))
	for job_id_value in run_state.crew_jobs.keys():
		var job_id := str(job_id_value)
		var job := _dict(run_state.crew_jobs.get(job_id_value, {}))
		if str(job.get("status", "")) != "resolved" or observed.has(job_id):
			continue
		observed.append(job_id)
		var row := _dict(ledger.get("jobs", {}))
		row["settled"] = int(row.get("settled", 0)) + 1
		ledger["jobs"] = row
		records.append({"action": int(run.get("actions", 0)), "system": "jobs", "selection": "job:%s" % str(job.get("definition_id", job_id)), "outcome": "settled"})
	run["observed_settled_job_ids"] = observed
	run["opportunities"] = ledger
	run["opportunity_records"] = records


func _visible_opportunity_ids(run_state: RunState) -> Array:
	var ids: Array = []
	var visibility := _public_opportunity_ids(run_state)
	for system_id in OPPORTUNITY_SYSTEMS:
		if not _array(visibility.get(system_id, [])).is_empty():
			ids.append(system_id)
	return ids


func _finalize_opportunity_ledger(run: Dictionary) -> void:
	var ledger := _dict(run.get("opportunities", {}))
	for system_id in OPPORTUNITY_SYSTEMS:
		var row := _dict(ledger.get(system_id, {}))
		var visible := int(row.get("visible", 0))
		var selected := int(row.get("selected", 0))
		var accepted := int(row.get("accepted", 0))
		var rejected := int(row.get("rejected", 0))
		var settled := int(row.get("settled", 0))
		if selected > visible or accepted + rejected != selected or settled > accepted:
			failures.append("Opportunity accounting invariant failed for %s in seed %s: visible=%d selected=%d accepted=%d rejected=%d settled=%d." % [system_id, str(run.get("seed", "")), visible, selected, accepted, rejected, settled])
		row["visible_not_selected"] = visible - selected
		ledger[system_id] = row
	run["opportunities"] = ledger


func _simulate_audit_run(style: Dictionary, seed: String, max_actions: int) -> Dictionary:
	_active_style = str(style.get("id", ""))
	# A UI run owns a fresh module lifetime. Replace only the stateful pusher
	# module per seed so completed live simulations do not accumulate across the
	# 512-run audit process.
	game_modules.erase("coin_pusher")
	var pusher_game := _create_game_module(library.game("coin_pusher"))
	if pusher_game != null:
		# The production module persists one live cabinet per room/context. Give
		# every audit run a deterministic context so a machine persists within a
		# seed but never leaks opening stock or physics state into the next seed.
		pusher_game.set_transient_state_key_context("balance06_1:%s" % seed)
		game_modules["coin_pusher"] = pusher_game
	var policy := str(style.get("policy", "clean"))
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed, RunStateScript.standard_challenge(seed))
	generator.next_environment(run_state)
	var run := {
		"seed": seed,
		"playstyle": _active_style,
		"policy": policy,
		"start_bankroll": run_state.bankroll,
		"actions": 0,
		"game_actions": 0,
		"legal_actions": 0,
		"cheat_actions": 0,
		"travel_count": 0,
		"tier2_visits": 0,
		"lender_uses": 0,
		"service_uses": 0,
		"item_purchases": 0,
		"events_resolved": 0,
		"grand_casino_entries": 0,
		"route_cost_total": 0,
		"service_use_keys": {},
		"showdown_attempted": false,
		"showdown_won": false,
		"showdown_trace": [],
		"duel_attempted": false,
		"duel_hands": 0,
		"duel_callouts": 0,
		"duel_correct_callouts": 0,
		"duel_false_callouts": 0,
		"duel_outcome": "",
		"duel_margin": 0,
		"pat_down_tier": "",
		"players_card_highest_tier": "none",
		"players_card_comp_uses": 0,
		"grand_casino_chip_buys": 0,
		"grand_casino_chip_cashouts": 0,
		"grand_casino_room_moves": 0,
		"rourke_watched_actions_avoided": 0,
		"rourke_clear_cheat_actions": 0,
		"stopped_reason": "action_cap",
		"failure_reason": "",
		"victory_route": "",
		"conditioned_probe": false,
		"conditioning": "none",
		"pusher_machine_reached": false,
		"pusher_variation": "",
		"curve": [],
		"visited_archetypes": [],
		"travel_decisions": [],
		"game_mix": {},
		"ledger": [],
		"source_totals": {},
		"sink_totals": {},
		"first_debt_action": {},
		"first_bankroll_action": {},
		"first_heat_50_action": -1,
		"first_heat_80_action": -1,
		"debt_was_open": false,
		"first_debt_recovery_action": -1,
		"victory_action": -1,
		"peak_bankroll": run_state.bankroll,
		"minimum_bankroll": run_state.bankroll,
		"peak_heat": run_state.suspicion_level(),
		"peak_debt": 0,
		"style_state": {},
		"opportunities": _empty_opportunity_ledger(),
		"opportunity_records": [],
		"observed_settled_job_ids": [],
		"remaining_reachable_routes": [],
	}
	_prepare_style_fixture(run_state, run)
	_record_curve(run, run_state, "start")
	_record_visit(run, run_state)

	for _action_index in range(max_actions):
		if run_state.is_terminal():
			break
		var opportunity_ids := _public_opportunity_ids(run_state)
		_record_public_opportunities(opportunity_ids, run)
		var before_bankroll := run_state.bankroll
		var before_heat := run_state.suspicion_level()
		var before_debt := _total_debt_balance(run_state)
		var label := _try_style_action(run_state, run, policy)
		if label.is_empty():
			label = _try_general_action(run_state, run, policy)
		if label.is_empty():
			run_state.advance_environment_turns(1)
			label = "idle"
			_count_action(run, "idle")
		_record_selected_opportunity(run_state, run, label, opportunity_ids)
		_record_new_job_settlements(run_state, run)
		_record_economy_boundary(run, run_state, label, before_bankroll, before_heat, before_debt)
		_record_curve(run, run_state, label)
		_record_thresholds(run, run_state)

	if not run_state.is_terminal():
		run["stopped_reason"] = "censored_action_cap"
		run["remaining_reachable_routes"] = _visible_opportunity_ids(run_state)
	else:
		run["stopped_reason"] = "terminal"
	_finalize_opportunity_ledger(run)
	_finalize_run(run, run_state)
	var final_debt_components := _debt_components(run_state)
	run["debt_principal"] = int(final_debt_components.get("principal", 0))
	run["debt_interest"] = int(final_debt_components.get("interest", 0))
	run["inventory_value"] = _inventory_resale_value(run_state)
	run["liquid_cash"] = run_state.bankroll
	run["net_position"] = run_state.bankroll + int(run.get("inventory_value", 0)) - int(run.get("debt_balance", 0))
	var source_total := _sum_int_map(_dict(run.get("source_totals", {})))
	var sink_total := _sum_int_map(_dict(run.get("sink_totals", {})))
	run["bankroll_reconciliation_delta"] = int(run.get("start_bankroll", 0)) + source_total - sink_total - run_state.bankroll
	run["censored"] = not run_state.is_terminal()
	run["pressure_terminal"] = _is_pressure_terminal(run)
	run["choice_terminal"] = bool(run.get("won", false)) or str(run.get("failure_reason", "")) == RunState.FAILURE_ABANDONED
	return run


func _record_curve(run: Dictionary, run_state: RunState, label: String) -> void:
	super._record_curve(run, run_state, label)
	var curve := _array(run.get("curve", []))
	if curve.is_empty():
		return
	var row := _dict(curve[-1])
	var inventory_value := _inventory_resale_value(run_state)
	var debt_components := _debt_components(run_state)
	row["liquid_cash"] = run_state.bankroll
	row["inventory_value"] = inventory_value
	row["net_position"] = run_state.bankroll + inventory_value - _total_debt_balance(run_state)
	row["debt_principal"] = int(debt_components.get("principal", 0))
	row["debt_interest"] = int(debt_components.get("interest", 0))
	curve[-1] = row
	run["curve"] = curve


func _inventory_resale_value(run_state: RunState) -> int:
	var total := 0
	for item_value in run_state.inventory:
		total += maxi(0, int(library.item(str(item_value)).get("sale_price", 0)))
	return total


func _sum_int_map(value: Dictionary) -> int:
	var total := 0
	for amount in value.values():
		total += int(amount)
	return total


func _debt_components(run_state: RunState) -> Dictionary:
	var principal := 0
	var interest := 0
	for debt_value in run_state.debt:
		var debt := _dict(debt_value)
		var balance := maxi(0, int(debt.get("balance", 0)))
		var original_principal := maxi(0, int(debt.get("principal", balance)))
		var outstanding_principal := mini(balance, original_principal)
		principal += outstanding_principal
		interest += maxi(0, balance - outstanding_principal)
	return {"principal": principal, "interest": interest, "balance": principal + interest}


func _prepare_style_fixture(run_state: RunState, run: Dictionary) -> void:
	match _active_style:
		"coin_pusher_grinder":
			_prepare_pusher(run_state, run)
		_:
			pass


func _try_style_action(run_state: RunState, run: Dictionary, policy: String) -> String:
	match _active_style:
		"crew_maximizer":
			if int(run.get("actions", 0)) < SPECIALIST_ACTION_BUDGET:
				var marker_label := _crew_marker_boundary(run_state, run)
				if not marker_label.is_empty():
					return marker_label
				var crew_label := _natural_crew_job_boundary(run_state, run, true)
				return crew_label if not crew_label.is_empty() else _specialist_visible_event_boundary(run_state, run, policy)
		"numbers_specialist":
			if int(run.get("actions", 0)) < NUMBERS_SPECIALIST_ACTION_BUDGET:
				var marker_label := _crew_marker_boundary(run_state, run)
				if not marker_label.is_empty():
					return marker_label
				var numbers_label := _numbers_boundary(run_state, run)
				return numbers_label if not numbers_label.is_empty() else _specialist_visible_event_boundary(run_state, run, policy)
		"coin_pusher_grinder":
			if int(_dict(run.get("style_state", {})).get("drops", 0)) < PUSHER_DROP_BUDGET:
				return _pusher_boundary(run_state, run)
		"heist_rusher":
			var marker_label := _crew_marker_boundary(run_state, run)
			if not marker_label.is_empty():
				return marker_label
			var heist_label := _heist_boundary(run_state, run)
			return heist_label if not heist_label.is_empty() else _specialist_visible_event_boundary(run_state, run, policy)
		"mixed_opportunist":
			if int(run.get("actions", 0)) % 7 == 0:
				var marker_label := _crew_marker_boundary(run_state, run)
				if not marker_label.is_empty():
					return marker_label
				var crew_label := _natural_crew_job_boundary(run_state, run, false)
				if not crew_label.is_empty():
					return crew_label
				var event_label := _specialist_visible_event_boundary(run_state, run, policy)
				if not event_label.is_empty():
					return event_label
			if int(run.get("actions", 0)) % 11 == 0 and run_state.bankroll >= 60:
				return _buy_numbers_slip_boundary(run_state, run, "mixed_numbers_slip")
		_:
			pass
	return ""


func _specialist_visible_event_boundary(run_state: RunState, run: Dictionary, policy: String) -> String:
	var recruitment_label := _crew_recruitment_event_boundary(run_state, run)
	if not recruitment_label.is_empty():
		return recruitment_label
	var seek_label := _seek_ranked_crew_boundary(run_state, run)
	if not seek_label.is_empty():
		return seek_label
	var recruitment_seek_label := _seek_recruitment_boundary(run_state, run)
	if not recruitment_seek_label.is_empty():
		return recruitment_seek_label
	if not _try_resolve_event(run_state, run, policy):
		return ""
	_count_action(run, "event")
	return "specialist_visible_event"


func _crew_recruitment_event_boundary(run_state: RunState, run: Dictionary) -> String:
	var recruitment_event_ids := CrewRecruitmentModelScript.recruitment_event_ids()
	for event_id_value in _current_event_ids(run_state):
		var event_id := str(event_id_value)
		if not recruitment_event_ids.has(event_id):
			continue
		var definition := library.event(event_id)
		if definition.is_empty():
			continue
		var event := EventModuleScript.new()
		event.setup(definition, library)
		if not event.can_trigger(run_state, run_state.current_environment):
			continue
		var selected_choice_id := ""
		for choice_value in event.choices(run_state, run_state.current_environment):
			var choice := _dict(choice_value)
			var choice_id := str(choice.get("id", ""))
			if choice_id.begins_with("work_with_"):
				selected_choice_id = choice_id
				break
		if selected_choice_id.is_empty():
			continue
		var result := event.resolve(run_state, run_state.current_environment, selected_choice_id)
		if not bool(result.get("ok", false)):
			continue
		run["events_resolved"] = int(run.get("events_resolved", 0)) + 1
		_count_action(run, "event")
		return "crew_recruitment_event:%s" % event_id
	return ""


func _try_resolve_required_progression_event(run_state: RunState, run: Dictionary, _policy: String) -> bool:
	if bool(run_state.narrative_flags.get("grand_casino_invite", false)) or not _current_event_ids(run_state).has("grand_casino_invite"):
		return false
	var event := EventModuleScript.new()
	event.setup(library.event("grand_casino_invite"), library)
	if not event.can_trigger(run_state, run_state.current_environment):
		return false
	var result := event.resolve(run_state, run_state.current_environment, "accept_invite")
	if not bool(result.get("ok", false)):
		return false
	run["events_resolved"] = int(run.get("events_resolved", 0)) + 1
	return true


func _try_resolve_event(run_state: RunState, run: Dictionary, policy: String) -> bool:
	var best_event_id := ""
	var best_choice_id := ""
	var best_score := -999
	for event_id_value in _current_event_ids(run_state):
		var event_id := str(event_id_value)
		var definition := library.event(event_id)
		if definition.is_empty():
			continue
		var event := EventModuleScript.new()
		event.setup(definition, library)
		if not event.can_trigger(run_state, run_state.current_environment):
			continue
		for choice_value in event.choices(run_state, run_state.current_environment):
			var choice := _dict(choice_value)
			var choice_id := str(choice.get("id", ""))
			var score := _event_choice_score(choice, policy, run_state)
			if not bool(choice.get("disabled", false)) and score > best_score:
				best_score = score
				best_event_id = event_id
				best_choice_id = choice_id
	if best_event_id.is_empty() or best_score < 0:
		return false
	var selected_event := EventModuleScript.new()
	selected_event.setup(library.event(best_event_id), library)
	var result := selected_event.resolve(run_state, run_state.current_environment, best_choice_id)
	if not bool(result.get("ok", false)):
		return false
	run["events_resolved"] = int(run.get("events_resolved", 0)) + 1
	return true


func _seek_ranked_crew_boundary(run_state: RunState, run: Dictionary) -> String:
	if not _array(run_state.current_environment.get("crew_presence", [])).is_empty():
		return ""
	var desired_member_ids: Array[String] = []
	match _active_style:
		"numbers_specialist":
			desired_member_ids.assign(["crew_lucky", "crew_mags"])
		"heist_rusher":
			desired_member_ids.assign(["crew_bishop"])
		"crew_maximizer", "mixed_opportunist":
			# Lucky's fallback is a public Numbers route across several early
			# venues. Prefer it before the narrower scenario-only contacts so
			# this deterministic policy keeps sampling legal recruitment
			# opportunities instead of camping a hidden destination.
			desired_member_ids.assign(["crew_lucky", "crew_mags", "crew_knuckles", "crew_switch", "crew_velvet", "crew_bishop"])
		_:
			for member_id_value in CrewStateModelScript.MEMBER_IDS:
				desired_member_ids.append(str(member_id_value))
	for member_id in desired_member_ids:
		if not _crew_at_least_rank(run_state, member_id, "associate"):
			continue
		var definition := CrewRecruitmentModelScript.member_definition(member_id)
		var label := _travel_toward_archetypes_boundary(run_state, run, _array(definition.get("presence", [])), "crew_seek:%s" % member_id)
		if not label.is_empty():
			return label
	return ""


func _seek_recruitment_boundary(run_state: RunState, run: Dictionary) -> String:
	var desired_member_ids: Array[String] = []
	match _active_style:
		"numbers_specialist":
			desired_member_ids.assign(["crew_lucky", "crew_mags"])
		"heist_rusher":
			desired_member_ids.assign(["crew_bishop"])
		"crew_maximizer", "mixed_opportunist":
			desired_member_ids.assign(["crew_lucky", "crew_mags", "crew_knuckles", "crew_switch", "crew_velvet", "crew_bishop"])
		_:
			for member_id_value in CrewStateModelScript.MEMBER_IDS:
				var member_id := str(member_id_value)
				if member_id != "crew_rook":
					desired_member_ids.append(member_id)
	for member_id in desired_member_ids:
		if _crew_at_least_rank(run_state, member_id, "associate"):
			continue
		var archetype_ids: Array = []
		for path_kind in ["primary", "fallback"]:
			for archetype_id_value in _array(CrewRecruitmentModelScript.meeting_path_public(member_id, path_kind).get("archetype_ids", [])):
				var archetype_id := str(archetype_id_value)
				if not archetype_id.is_empty() and not archetype_ids.has(archetype_id):
					archetype_ids.append(archetype_id)
		var label := _travel_toward_archetypes_boundary(run_state, run, archetype_ids, "crew_recruit_seek:%s" % member_id)
		if not label.is_empty():
			return label
	return ""


func _travel_toward_archetypes_boundary(run_state: RunState, run: Dictionary, archetype_ids: Array, label_prefix: String) -> String:
	var candidates: Array[Dictionary] = []
	for archetype_id_value in archetype_ids:
		var archetype_id := str(archetype_id_value)
		# Recruitment data predates the world-map schema and its
		# `archetype_ids` entries can name either a public node id (for example
		# `motel`) or an environment archetype (for example `bar`). Resolve only
		# against the currently disclosed map so the policy can visit every legal
		# fallback without learning which seeded location owns the meeting.
		var target_node_id := _world_node_for_public_location(run_state, archetype_id)
		if target_node_id.is_empty() or target_node_id == run_state.current_world_node_id():
			continue
		# The policy may route through only nodes already disclosed by the public
		# map. A hidden destination or hidden intermediate is not audit input.
		var path := WorldMapScript.path_between(run_state.world_map, run_state.current_world_node_id(), target_node_id, true)
		if path.size() < 2:
			continue
		candidates.append({"archetype_id": archetype_id, "target_node_id": target_node_id, "path_size": path.size()})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("path_size", 999)) != int(b.get("path_size", 999)):
			return int(a.get("path_size", 999)) < int(b.get("path_size", 999))
		return str(a.get("archetype_id", "")) < str(b.get("archetype_id", ""))
	)
	for candidate in candidates:
		var label := _travel_to_node_boundary(run_state, run, str(candidate.get("target_node_id", "")), false, "%s:%s" % [label_prefix, str(candidate.get("archetype_id", ""))])
		if not label.is_empty():
			return label
	return ""


func _world_node_for_public_location(run_state: RunState, location_id: String) -> String:
	var visible_node_ids := WorldMapScript.visible_node_ids(run_state.world_map) if run_state.has_world_map() else []
	if visible_node_ids.has(location_id):
		return location_id
	return _world_node_for_archetype(run_state, location_id)


func _crew_marker_boundary(run_state: RunState, run: Dictionary) -> String:
	var state := _dict(run.get("style_state", {}))
	if bool(state.get("crew_marker_used", false)):
		return ""
	var service := RunActionServiceScript.new()
	service.setup(library, run_state)
	var option := service.lender_hook("the_crew")
	if option.is_empty() or not bool(option.get("enabled", false)) or not bool(option.get("mutation_supported", false)):
		return ""
	var used := service.use_hook("lender", "the_crew")
	if not bool(used.get("ok", false)):
		return ""
	state["crew_marker_used"] = true
	run["style_state"] = state
	run["lender_uses"] = int(run.get("lender_uses", 0)) + 1
	_count_action(run, "hook")
	return "crew_marker_loan"


func _natural_crew_job_boundary(run_state: RunState, run: Dictionary, keep_working: bool) -> String:
	var member_ids: Array[String] = []
	for value in _array(run_state.current_environment.get("crew_presence", [])):
		var member_id := str(_dict(value).get("member_id", "")).strip_edges()
		if not member_id.is_empty() and not member_ids.has(member_id):
			member_ids.append(member_id)
	member_ids.sort()
	for member_id in member_ids:
		var label := _crew_job_boundary(run_state, run, member_id, "inner_circle" if keep_working else "made", keep_working)
		if not label.is_empty():
			return label
	return ""


func _try_general_action(run_state: RunState, run: Dictionary, policy: String) -> String:
	if _try_claim_or_resolve_endgame(run_state, run):
		_count_action(run, "event")
		if run_state.is_terminal():
			run["victory_action"] = int(run.get("actions", 0))
		return "endgame"
	if _try_resolve_required_progression_event(run_state, run, policy):
		_count_action(run, "event")
		return "progression"
	if _active_style != "pure_gambler" and _try_use_grand_casino_facility(run_state, run, policy):
		_count_action(run, "hook")
		_record_visit(run, run_state)
		return "casino_facility"
	var inventory_before := _string_array(run_state.inventory)
	if _active_style in ["control_crew_ignoring", "mixed_opportunist"] and _try_buy_helpful_item(run_state, run, policy):
		_count_action(run, "item")
		return "item:%s" % _added_string(inventory_before, _string_array(run_state.inventory), "unknown")
	var services_before := _dict(run.get("service_use_keys", {}))
	if _active_style in ["control_crew_ignoring", "mixed_opportunist", "cheater"] and _try_use_pressure_service(run_state, run, policy):
		_count_action(run, "hook")
		return "service:%s" % _incremented_map_key(services_before, _dict(run.get("service_use_keys", {})), "unknown")
	if _active_style != "pure_gambler" and _try_use_lender(run_state, run, policy):
		_count_action(run, "hook")
		return "lender"
	if _should_travel_now(run_state, run, policy) and _try_travel(run_state, run, policy):
		_count_action(run, "travel")
		_record_visit(run, run_state)
		return "travel:%s" % str(run_state.current_environment.get("archetype_id", "unknown"))
	var game_mix_before := _dict(run.get("game_mix", {}))
	if _try_play_game(run_state, run, policy):
		_count_action(run, "game")
		return "game:%s" % _incremented_map_key(game_mix_before, _dict(run.get("game_mix", {})), "unknown")
	if _active_style in ["control_crew_ignoring", "mixed_opportunist"] and _try_resolve_event(run_state, run, policy):
		_count_action(run, "event")
		return "event"
	if _try_travel(run_state, run, policy) or _try_any_visible_travel(run_state, run, policy):
		_count_action(run, "travel")
		_record_visit(run, run_state)
		return "travel:%s" % str(run_state.current_environment.get("archetype_id", "unknown"))
	return ""


func _try_any_visible_travel(run_state: RunState, run: Dictionary, policy: String) -> bool:
	var best_choice := {}
	var best_score := -99999
	for choice_value in _travel_choices(run_state):
		var choice := _dict(choice_value)
		var target_id := str(choice.get("id", ""))
		if target_id.is_empty() or target_id == run_state.current_world_node_id() or not bool(choice.get("enabled", false)):
			continue
		var cost := maxi(0, int(choice.get("cost", 0)))
		if cost > run_state.bankroll or run_state.bankroll - cost < _destination_minimum_bankroll(target_id):
			continue
		var score := _travel_score(run_state, run, choice, policy)
		if score > best_score:
			best_score = score
			best_choice = choice
	if best_choice.is_empty():
		return false
	return _apply_travel_choice(run_state, run, best_choice)


func _incremented_map_key(before: Dictionary, after: Dictionary, fallback: String) -> String:
	for key_value in after.keys():
		var key := str(key_value)
		if int(after.get(key_value, 0)) > int(before.get(key, 0)):
			return key
	return fallback


func _added_string(before: Array, after: Array, fallback: String) -> String:
	for value in after:
		var text := str(value)
		if not before.has(text):
			return text
	return fallback


func _crew_job_boundary(run_state: RunState, run: Dictionary, member_id: String, target_rank: String, keep_working: bool) -> String:
	var state := _dict(run.get("style_state", {}))
	var pending_job_id := str(state.get("pending_job_id", ""))
	if not pending_job_id.is_empty():
		var job := _dict(run_state.crew_jobs.get(pending_job_id, {}))
		var status := str(job.get("status", ""))
		if status == "resolved":
			state.erase("pending_job_id")
			run["style_state"] = state
			return _crew_job_boundary(run_state, run, member_id, target_rank, keep_working)
		if run_state.delivery_has_active_run():
			return _drive_active_delivery_boundary(run_state, run, "crew_job:%s" % str(job.get("definition_id", "unknown")))
		if str(job.get("kind", "")) == "stake_horse":
			return _drive_stake_job_boundary(run_state, run, job)
		if str(job.get("kind", "")) == "collection":
			var collected := run_state.crew_resolve_collection("friendly")
			if bool(collected.get("ok", false)):
				run_state.advance_environment_turns(1)
				_count_action(run, "hook")
				return "crew_job:%s:collection" % str(job.get("definition_id", "unknown"))
		return ""
	var public_rank := _public_crew_rank(run_state, member_id)
	if public_rank == "stranger" or public_rank == "marker":
		return ""
	var rank_index := CrewStateModelScript.RANK_IDS.find(public_rank)
	var target_index := CrewStateModelScript.RANK_IDS.find(target_rank)
	if rank_index >= target_index and not keep_working:
		return ""
	var offer := _best_public_job_for_member(run_state, member_id)
	if offer.is_empty():
		return ""
	# A policy may act only on a naturally visible contact. It never rewrites
	# presence, rank, route, capability, or any other production authority.
	var contact_presence := _array(run_state.current_environment.get("crew_presence", []))
	var naturally_present := contact_presence.any(func(value: Variant) -> bool: return typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("member_id", "")) == member_id)
	if not naturally_present:
		return ""
	var accepted := run_state.crew_job_accept_definition(str(offer.get("definition_id", "")))
	var job_id := str(accepted.get("job_id", ""))
	if not bool(accepted.get("ok", false)) or job_id.is_empty():
		return ""
	state["pending_job_id"] = job_id
	run["style_state"] = state
	run_state.advance_environment_turns(1)
	_count_action(run, "hook")
	return "crew_job_accept"


func _mark_conditioning(run: Dictionary, note: String) -> void:
	run["conditioned_probe"] = true
	var existing := str(run.get("conditioning", "none"))
	if existing == "none" or existing.is_empty():
		run["conditioning"] = note
	elif not existing.contains(note):
		run["conditioning"] = "%s %s" % [existing, note]


func _best_public_job_for_member(run_state: RunState, member_id: String) -> Dictionary:
	var best := {}
	var best_cash := -1
	for value in run_state.crew_job_board_offers():
		var offer := _dict(value)
		if str(offer.get("member_id", "")) != member_id:
			continue
		var cash := int(offer.get("cash", 0))
		if cash > best_cash or cash == best_cash and str(offer.get("definition_id", "")) < str(best.get("definition_id", "~")):
			best_cash = cash
			best = offer
	return best


func _crew_at_least_rank(run_state: RunState, member_id: String, target_rank: String) -> bool:
	return CrewStateModelScript.RANK_IDS.find(_public_crew_rank(run_state, member_id)) >= CrewStateModelScript.RANK_IDS.find(target_rank)


func _public_crew_rank(run_state: RunState, member_id: String) -> String:
	return str(run_state.crew_recruitment_public_state(member_id).get("standing", "stranger"))


func _drive_stake_job_boundary(run_state: RunState, run: Dictionary, job: Dictionary) -> String:
	var payload := _dict(job.get("payload", {}))
	var definition_id := str(job.get("definition_id", "unknown"))
	if bool(payload.get("loss_choice_pending", false)):
		var resolved := run_state.crew_resolve_stake_horse_loss("repay")
		if bool(resolved.get("ok", false)):
			run_state.advance_environment_turns(1)
			_count_action(run, "hook")
			return "crew_job:%s:stake_repay" % definition_id
		return ""
	var venue_id := str(payload.get("venue_id", ""))
	if str(run_state.current_environment.get("archetype_id", "")) != venue_id:
		var target_node_id := _world_node_for_archetype(run_state, venue_id)
		return _travel_to_node_boundary(run_state, run, target_node_id, false, "crew_job:%s:stake_travel" % definition_id)
	return _play_specific_game_boundary(run_state, run, str(payload.get("game_id", "")), "clean", 0, "crew_job:%s:stake_play" % definition_id)


func _world_node_for_archetype(run_state: RunState, archetype_id: String) -> String:
	var visible_node_ids := WorldMapScript.visible_node_ids(run_state.world_map) if run_state.has_world_map() else []
	for node_value in _array(run_state.world_map.get("nodes", [])):
		var node := _dict(node_value)
		var node_id := str(node.get("id", ""))
		if visible_node_ids.has(node_id) and str(node.get("archetype_id", "")) == archetype_id:
			return node_id
	return ""


func _apply_travel_choice(run_state: RunState, run: Dictionary, choice: Dictionary) -> bool:
	var target_node_id := str(choice.get("id", "")).strip_edges()
	# The policy selects only an opaque public id. Re-read every authoritative
	# route/cost/status field from the live public action surface so an adapter
	# caller cannot smuggle a cheaper route, different heat, or forged access in
	# the dictionary it passes back.
	var canonical_choice := {}
	for public_value in _travel_choices(run_state):
		var public_choice := _dict(public_value)
		if str(public_choice.get("id", "")).strip_edges() == target_node_id and bool(public_choice.get("enabled", false)):
			canonical_choice = public_choice
			break
	var route := _dict(canonical_choice.get("route", {}))
	if target_node_id.is_empty() or canonical_choice.is_empty() or route.is_empty() or target_node_id == run_state.current_world_node_id():
		return false
	var route_status := _dict(canonical_choice.get("status", {}))
	route["cost"] = int(canonical_choice.get("cost", route.get("cost", 0)))
	if route_status.has("suspicion_delta"):
		route["suspicion_delta"] = int(route_status.get("suspicion_delta", route.get("suspicion_delta", 0)))
	var previous_environment := run_state.current_environment.duplicate(true)
	var route_risk := run_state.travel_route_risk(route, target_node_id)
	var travel_heat := run_state.begin_travel_suspicion_decay(route, target_node_id)
	generator.next_environment(run_state, target_node_id, true)
	if run_state.has_world_map() and run_state.current_world_node_id() != target_node_id:
		return false
	var travel_decay := run_state.finish_travel_suspicion_decay(travel_heat)
	var result := _travel_result(target_node_id, previous_environment, run_state.current_environment, route, travel_decay, route_risk)
	GameModule.apply_result(run_state, result)
	run_state.advance_environment_turns(1)
	run["travel_count"] = int(run.get("travel_count", 0)) + 1
	run["route_cost_total"] = int(run.get("route_cost_total", 0)) + maxi(0, int(canonical_choice.get("cost", route.get("cost", 0))))
	if str(run_state.current_environment.get("archetype_id", "")) == GRAND_CASINO_ID:
		run["grand_casino_entries"] = int(run.get("grand_casino_entries", 0)) + 1
	return true


func _drive_active_delivery_boundary(run_state: RunState, run: Dictionary, label_prefix: String) -> String:
	if not run_state.delivery_has_active_run():
		return ""
	var snapshot := run_state.delivery_snapshot()
	var target_node_id := str(snapshot.get("handoff_pending_node_id", ""))
	if target_node_id.is_empty():
		for target_value in _array(snapshot.get("targets", [])):
			var target := _dict(target_value)
			if str(target.get("status", "pending")) == "pending":
				target_node_id = str(target.get("node_id", ""))
				break
	if target_node_id.is_empty():
		return ""
	if run_state.current_world_node_id() != target_node_id:
		return _travel_to_node_boundary(run_state, run, target_node_id, true, "%s_travel" % label_prefix)
	var interaction := run_state.delivery_arrival_interaction()
	if not interaction.is_empty():
		run_state.delivery_complete_handoff(target_node_id)
	else:
		run_state.advance_environment_turns(1)
		interaction = run_state.delivery_arrival_interaction()
		if not interaction.is_empty():
			run_state.delivery_complete_handoff(target_node_id)
	_count_action(run, "hook")
	return "%s_work" % label_prefix


func _travel_to_node_boundary(run_state: RunState, run: Dictionary, target_node_id: String, delivery_active: bool, label: String) -> String:
	if target_node_id.is_empty() or run_state.current_world_node_id() == target_node_id:
		return ""
	var selected := {}
	var choices := _travel_choices(run_state)
	for choice_value in choices:
		var choice := _dict(choice_value)
		var choice_id := str(choice.get("id", ""))
		var choice_cost := maxi(0, int(choice.get("cost", 0)))
		var keeps_reserve := delivery_active or run_state.bankroll - choice_cost >= _destination_minimum_bankroll(choice_id)
		if choice_id == target_node_id and bool(choice.get("enabled", false)) and choice_cost <= run_state.bankroll and keeps_reserve:
			selected = choice
			break
	if selected.is_empty() and run_state.has_world_map():
		var path := WorldMapScript.path_between(run_state.world_map, run_state.current_world_node_id(), target_node_id, true)
		for path_index in range(path.size() - 1, 0, -1):
			var waypoint_id := str(path[path_index])
			for choice_value in choices:
				var choice := _dict(choice_value)
				var choice_id := str(choice.get("id", ""))
				var choice_cost := maxi(0, int(choice.get("cost", 0)))
				var keeps_reserve := delivery_active or run_state.bankroll - choice_cost >= _destination_minimum_bankroll(choice_id)
				if choice_id == waypoint_id and bool(choice.get("enabled", false)) and choice_cost <= run_state.bankroll and keeps_reserve:
					selected = choice
					break
			if not selected.is_empty():
				break
	if selected.is_empty():
		return ""
	if not delivery_active:
		if not _apply_travel_choice(run_state, run, selected):
			return ""
		_record_visit(run, run_state)
		_count_action(run, "travel")
		return label
	var selected_target_id := str(selected.get("id", ""))
	var route := _dict(selected.get("route", {}))
	var route_status := _dict(selected.get("status", {}))
	route["cost"] = int(selected.get("cost", route.get("cost", 0)))
	if route_status.has("suspicion_delta"):
		route["suspicion_delta"] = int(route_status.get("suspicion_delta", route.get("suspicion_delta", 0)))
	var previous_environment := run_state.current_environment.duplicate(true)
	var route_risk := run_state.travel_route_risk(route, selected_target_id)
	var travel_heat := run_state.begin_travel_suspicion_decay(route, selected_target_id)
	generator.next_environment(run_state, selected_target_id, true)
	if run_state.has_world_map() and run_state.current_world_node_id() != selected_target_id:
		return ""
	var travel_decay := run_state.finish_travel_suspicion_decay(travel_heat)
	var arrival := run_state.delivery_resolve_travel_arrival(route, route_risk)
	var result := _travel_result(selected_target_id, previous_environment, run_state.current_environment, route, travel_decay, route_risk)
	GameModule.apply_result(run_state, result)
	if bool(arrival.get("handoff_ready", false)):
		run_state.delivery_complete_handoff(selected_target_id)
	run["travel_count"] = int(run.get("travel_count", 0)) + 1
	run["route_cost_total"] = int(run.get("route_cost_total", 0)) + maxi(0, int(selected.get("cost", route.get("cost", 0))))
	if str(run_state.current_environment.get("archetype_id", "")) == GRAND_CASINO_ID:
		run["grand_casino_entries"] = int(run.get("grand_casino_entries", 0)) + 1
	_record_visit(run, run_state)
	_count_action(run, "travel")
	return label


func _play_specific_game_boundary(run_state: RunState, run: Dictionary, game_id: String, policy: String, forced_stake: int, label: String) -> String:
	if not _string_array(run_state.current_environment.get("game_ids", [])).has(game_id):
		return ""
	var game: GameModule = game_modules.get(game_id, null)
	if game == null:
		return ""
	var action_id := _pick_game_action_id(game, run_state, run_state.current_environment, policy)
	if action_id.is_empty():
		return ""
	var stake := forced_stake if forced_stake > 0 else _stake_for_game(run_state, game, action_id, policy)
	if stake <= 0 or stake > run_state.bankroll:
		return ""
	var rng := run_state.create_rng()
	var ui_state := _prepared_metrics_ui_state(game, run_state, game_id, action_id, stake, policy)
	var result := game.resolve_with_context(action_id, stake, run_state, run_state.current_environment, rng, ui_state)
	if not bool(result.get("ok", false)):
		return ""
	if bool(result.get("host_apply_result", false)):
		GameModule.apply_result(run_state, result, rng)
	else:
		run_state.save_rng(rng)
	if not bool(result.get("slot_runtime_tick", false)):
		run_state.advance_environment_turns(1)
	run["game_actions"] = int(run.get("game_actions", 0)) + 1
	var action_kind := str(result.get("action_kind", ""))
	if action_kind in ["cheat", "risky", "advantage"]:
		run["cheat_actions"] = int(run.get("cheat_actions", 0)) + 1
	else:
		run["legal_actions"] = int(run.get("legal_actions", 0)) + 1
	var mix := _dict(run.get("game_mix", {}))
	mix[game_id] = int(mix.get(game_id, 0)) + 1
	run["game_mix"] = mix
	_count_action(run, "game")
	return label


# The inherited metrics helper reads challenge answers and target timing from
# private surface payloads. Audit actors instead use a predeclared reaction
# offset and answer choice derived only from public run identity and action
# count; misses remain legitimate measured outcomes.
func _prepared_metrics_ui_state(game: GameModule, run_state: RunState, game_id: String, action_id: String, stake: int, policy: String) -> Dictionary:
	var ui_state := _ui_state_for_game(game_id, action_id, stake, policy)
	var environment := run_state.current_environment
	var policy_key := "%s:%s:%s:%d" % [run_state.seed_text, game_id, action_id, run_state.crew_action_index()]
	var reaction_msec := 900 + posmod(_stable_hash(policy_key + ":reaction"), 3201)
	match action_id:
		"read_wheel_bias":
			var wheel_start := game.surface_action_command("roulette_read_wheel", 0, false, ui_state, run_state, environment)
			ui_state = _dict(wheel_start.get("ui_state", ui_state))
			ui_state["surface_time_msec"] = int(ui_state.get("surface_time_msec", 0)) + reaction_msec
			var wheel_lock := game.surface_action_command("roulette_read_wheel", 0, false, ui_state, run_state, environment)
			return _dict(wheel_lock.get("ui_state", ui_state))
		"read_baccarat_shoe":
			var shoe_start := game.surface_action_command("baccarat_read_shoe", 0, false, ui_state, run_state, environment)
			ui_state = _dict(shoe_start.get("ui_state", ui_state))
			ui_state["surface_time_msec"] = int(ui_state.get("surface_time_msec", 0)) + reaction_msec
			var answer_index := posmod(_stable_hash(policy_key + ":answer"), 3)
			var shoe_answer := game.surface_action_command("baccarat_shoe_read_answer", answer_index, false, ui_state, run_state, environment)
			return _dict(shoe_answer.get("ui_state", ui_state))
		"palmed_swap":
			var dice_roll := game.surface_action_command("bar_dice_roll", 0, false, ui_state, run_state, environment)
			ui_state = _dict(dice_roll.get("ui_state", ui_state))
			var shake_count := posmod(_stable_hash(policy_key + ":shakes"), 3)
			for _shake_index in range(shake_count):
				var dice_shake := game.surface_action_command("bar_dice_shake", 0, false, ui_state, run_state, environment)
				if not bool(dice_shake.get("handled", false)):
					break
				ui_state = _dict(dice_shake.get("ui_state", ui_state))
			var palm_start := game.surface_action_command("bar_dice_palm", 0, false, ui_state, run_state, environment)
			ui_state = _dict(palm_start.get("ui_state", ui_state))
			ui_state["surface_time_msec"] = int(ui_state.get("surface_time_msec", 0)) + reaction_msec
			var palm_lock := game.surface_action_command("bar_dice_palm", 0, false, ui_state, run_state, environment)
			return _dict(palm_lock.get("ui_state", ui_state))
	return ui_state


func _numbers_boundary(run_state: RunState, run: Dictionary) -> String:
	var state := _dict(run.get("style_state", {}))
	if int(run.get("actions", 0)) % 5 == 0:
		var ordinary_slip := _buy_numbers_slip_boundary(run_state, run, "numbers_visible_slip")
		if not ordinary_slip.is_empty():
			return ordinary_slip
	var phase := str(state.get("numbers_phase", "runner"))
	if phase == "runner":
		var runner_label := _numbers_runner_boundary(run_state, run)
		if not runner_label.is_empty():
			return runner_label
		if not bool(run_state.narrative_flags.get("numbers_route_paid", false)) and not bool(run_state.narrative_flags.get("numbers_route_failed", false)):
			return ""
		state = _dict(run.get("style_state", {}))
		state["numbers_phase"] = "rank_lucky"
		run["style_state"] = state
		return _numbers_boundary(run_state, run)
	if phase == "rank_lucky":
		var label := _crew_job_boundary(run_state, run, "crew_lucky", "made", false)
		if label.is_empty() and _crew_at_least_rank(run_state, "crew_lucky", "made"):
			state = _dict(run.get("style_state", {}))
			state["numbers_phase"] = "rank_mags"
			run["style_state"] = state
			return _numbers_boundary(run_state, run)
		return label
	if phase == "rank_mags":
		var label := _crew_job_boundary(run_state, run, "crew_mags", "made", false)
		if label.is_empty() and _crew_at_least_rank(run_state, "crew_mags", "made"):
			state = _dict(run.get("style_state", {}))
			state["numbers_phase"] = "operate"
			run["style_state"] = state
			return _numbers_boundary(run_state, run)
		return label
	return _numbers_fix_boundary(run_state, run)


func _numbers_runner_boundary(run_state: RunState, run: Dictionary) -> String:
	if run_state.delivery_has_active_run():
		return _drive_active_delivery_boundary(run_state, run, "numbers_runner")
	if not _crew_at_least_rank(run_state, "crew_lucky", "associate"):
		return _crew_job_boundary(run_state, run, "crew_lucky", "associate", false)
	if str(run_state.current_environment.get("archetype_id", "")) != "small_underground_casino":
		return _travel_to_node_boundary(run_state, run, _world_node_for_archetype(run_state, "small_underground_casino"), false, "numbers_runner_desk_travel")
	if not bool(run_state.numbers_desk_status().get("runner_available", false)):
		run_state.advance_environment_turns(1)
		_count_action(run, "hook")
		return "numbers_runner_wait"
	var begun := run_state.numbers_begin_collection_route()
	if not bool(begun.get("ok", false)):
		return ""
	run_state.advance_environment_turns(1)
	_count_action(run, "hook")
	return "numbers_runner_begin"


func _numbers_fix_boundary(run_state: RunState, run: Dictionary) -> String:
	if run_state.delivery_has_active_run():
		return _drive_active_delivery_boundary(run_state, run, "numbers_fix_bribe")
	var desk := run_state.numbers_desk_status()
	var stage := str(desk.get("fix_stage", "locked"))
	if stage in ["ready", "camouflage"] and str(run_state.current_environment.get("archetype_id", "")) != "small_underground_casino":
		var desk_node_id := _world_node_for_archetype(run_state, "small_underground_casino")
		return _travel_to_node_boundary(run_state, run, desk_node_id, false, "numbers_desk_travel")
	if stage == "ready":
		if run_state.bankroll < 60:
			return ""
		var begun := run_state.numbers_begin_fix_bribe()
		if not bool(begun.get("ok", false)):
			return ""
		run_state.advance_environment_turns(1)
		_count_action(run, "hook")
		return "numbers_fix_bribe_begin"
	if stage == "camouflage":
		if run_state.bankroll < 60:
			return ""
		var allocated := run_state.numbers_fix_allocate({
			"small_underground_casino": 18,
			"bar": 16,
			"motel": 14,
			"gas_station_casino": 12,
		})
		if not bool(allocated.get("ok", false)):
			return ""
		run_state.advance_environment_turns(1)
		_count_action(run, "hook")
		return "numbers_fix_allocate"
	if stage == "payday":
		var slip_label := _buy_numbers_slip_boundary(run_state, run, "numbers_payday_clock")
		if not slip_label.is_empty():
			return slip_label
		run_state.advance_environment_turns(1)
		_count_action(run, "hook")
		return "numbers_payday_clock"
	return ""


func _buy_numbers_slip_boundary(run_state: RunState, run: Dictionary, label: String) -> String:
	if run_state.bankroll < 4:
		return ""
	var status := run_state.numbers_status()
	var venue_id := str(run_state.current_environment.get("archetype_id", ""))
	var venue_open := false
	for venue_value in _array(status.get("venue_status", [])):
		var venue := _dict(venue_value)
		if str(venue.get("id", "")) == venue_id:
			venue_open = bool(venue.get("open", false))
			break
	if not venue_open:
		return ""
	var digits := "%03d" % posmod(_stable_hash(run_state.seed_text + ":numbers:" + str(run.get("actions", 0))), 1000)
	var bought := run_state.numbers_buy_slip(digits, 4, "straight")
	if not bool(bought.get("ok", false)):
		return ""
	run_state.advance_environment_turns(1)
	run["game_actions"] = int(run.get("game_actions", 0)) + 1
	run["legal_actions"] = int(run.get("legal_actions", 0)) + 1
	var mix := _dict(run.get("game_mix", {}))
	mix["the_numbers"] = int(mix.get("the_numbers", 0)) + 1
	run["game_mix"] = mix
	_count_action(run, "game")
	return label


func _prepare_pusher(run_state: RunState, run: Dictionary) -> void:
	var state := _dict(run.get("style_state", {}))
	state["pusher_phase"] = "seek_natural_machine"
	state["surface_time_msec"] = 0
	state["drops"] = 0
	run["style_state"] = state


func _pusher_boundary(run_state: RunState, run: Dictionary) -> String:
	var game: GameModule = game_modules.get("coin_pusher", null)
	if game == null:
		return ""
	var state := _dict(run.get("style_state", {}))
	var phase := str(state.get("pusher_phase", "seek_natural_machine"))
	if phase == "seek_natural_machine":
		if not _string_array(run_state.current_environment.get("game_ids", [])).has("coin_pusher"):
			return _seek_public_casino_boundary(run_state, run, "coin_pusher_seek_travel")
		game.enter(run_state, run_state.current_environment)
		var surface := game.surface_state(run_state, run_state.current_environment, {})
		state["pusher_phase"] = "grind"
		state["pusher_variation"] = str(surface.get("coin_pusher_variation_id", "quarter_falls"))
		run["style_state"] = state
		run["pusher_machine_reached"] = true
		run["pusher_variation"] = str(state.get("pusher_variation", "quarter_falls"))
		return _pusher_boundary(run_state, run)
	# Keep one travel/debt dollar in reserve instead of intentionally triggering
	# the global bankroll-zero terminal before a physical tray can be collected.
	if run_state.bankroll <= 1:
		return ""
	# Use the same default run stream as the shipped Foundation action path.
	var rng := run_state.create_rng()
	var result := game.resolve_with_context("drop_quarter", 1, run_state, run_state.current_environment, rng, {})
	if not bool(result.get("ok", false)):
		return ""
	if bool(result.get("host_apply_result", false)):
		GameModule.apply_result(run_state, result, rng)
	else:
		run_state.save_rng(rng)
	var surface_time := int(state.get("surface_time_msec", 0))
	for _tick in range(20):
		surface_time += 17
		game.surface_realtime_state_patch(run_state, run_state.current_environment, {"surface_time_msec": surface_time}, {})
	state["surface_time_msec"] = surface_time
	state["drops"] = int(state.get("drops", 0)) + 1
	# The tray is economically inert until COLLECT. Use that real boundary after
	# every fixed-tick drop so an arbitrary action cap cannot strand claimable
	# cash in the presentation tray and understate the grinder's bankroll.
	game.surface_action_command("coin_pusher_collect", 0, false, {}, run_state, run_state.current_environment)
	run["style_state"] = state
	run_state.advance_environment_turns(1)
	run["game_actions"] = int(run.get("game_actions", 0)) + 1
	run["legal_actions"] = int(run.get("legal_actions", 0)) + 1
	var mix := _dict(run.get("game_mix", {}))
	mix["coin_pusher"] = int(mix.get("coin_pusher", 0)) + 1
	run["game_mix"] = mix
	_count_action(run, "game")
	return "coin_pusher_drop"


func _seek_public_casino_boundary(run_state: RunState, run: Dictionary, label: String) -> String:
	var choices := _travel_choices(run_state)
	var visited := _array(run.get("visited_archetypes", []))
	var candidates: Array[Dictionary] = []
	for choice_value in choices:
		var choice := _dict(choice_value)
		var target_id := str(choice.get("id", ""))
		var cost := maxi(0, int(choice.get("cost", 0)))
		if target_id.is_empty() or not bool(choice.get("enabled", false)) or str(choice.get("kind", "")) != "casino" \
				or cost > run_state.bankroll or run_state.bankroll - cost < _destination_minimum_bankroll(target_id):
			continue
		candidates.append({"choice": choice, "unvisited": not visited.has(target_id), "target_id": target_id, "cost": cost})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("unvisited", false)) != bool(b.get("unvisited", false)):
			return bool(a.get("unvisited", false))
		if int(a.get("cost", 0)) != int(b.get("cost", 0)):
			return int(a.get("cost", 0)) < int(b.get("cost", 0))
		return str(a.get("target_id", "")) < str(b.get("target_id", ""))
	)
	if candidates.is_empty() or not _apply_travel_choice(run_state, run, _dict(candidates[0].get("choice", {}))):
		return ""
	_record_visit(run, run_state)
	_count_action(run, "travel")
	return label


func _heist_boundary(run_state: RunState, run: Dictionary) -> String:
	var state := _dict(run.get("style_state", {}))
	var plan_id := str(state.get("heist_plan_id", ""))
	if plan_id.is_empty():
		plan_id = CrewHeistModelScript.PLAN_IDS[posmod(_stable_hash(run_state.seed_text + ":heist_plan"), CrewHeistModelScript.PLAN_IDS.size())]
		state["heist_plan_id"] = plan_id
		run["style_state"] = state
	var heist := run_state.crew_heist_snapshot()
	if heist.is_empty():
		var architect_id := "crew_bishop" if plan_id == CrewHeistModelScript.PLAN_COUNT else "crew_velvet"
		var rank_label := _crew_job_boundary(run_state, run, architect_id, "inner_circle", false)
		if not rank_label.is_empty():
			return rank_label
		if not _crew_at_least_rank(run_state, architect_id, "inner_circle"):
			return ""
		var planning_label := _travel_to_planning_table_boundary(run_state, run, "heist_planning_travel")
		if not planning_label.is_empty():
			return planning_label
		var planning := run_state.crew_heist_planning_status()
		var plan_live := false
		for plan_value in _array(planning.get("plans", [])):
			var plan := _dict(plan_value)
			if str(plan.get("id", "")) == plan_id:
				plan_live = bool(plan.get("live", false))
				break
		if not plan_live:
			return ""
		if not _resolve_public_event_choice(run_state, "crew_planning_table", "lock_%s" % plan_id):
			failures.append("Public planning-table lock failed for %s in seed %s." % [plan_id, run_state.seed_text])
			return ""
		_count_action(run, "event")
		return "heist_lock:%s" % plan_id
	heist = run_state.crew_heist_snapshot()
	plan_id = str(heist.get("plan_id", plan_id))
	state = _dict(run.get("style_state", {}))
	state["heist_plan_id"] = plan_id
	run["style_state"] = state
	match str(heist.get("status", "")):
		CrewHeistModelScript.STATUS_SETUP:
			return _heist_count_setup_boundary(run_state, run, heist) if plan_id == CrewHeistModelScript.PLAN_COUNT else _heist_whale_setup_boundary(run_state, run, heist)
		CrewHeistModelScript.STATUS_PLAY:
			return _heist_live_play_boundary(run_state, run, heist)
		CrewHeistModelScript.STATUS_INTERVIEW:
			var interview_choice := "interview_show_receipt" if _public_event_choice_enabled(run_state, "heist_live_table", "interview_show_receipt") else "interview_cut_short"
			if _resolve_public_event_choice(run_state, "heist_live_table", interview_choice):
				_count_action(run, "event")
				return "heist_interview"
		CrewHeistModelScript.STATUS_GETAWAY:
			var getaway_label := _drive_active_delivery_boundary(run_state, run, "heist_getaway")
			if run_state.is_terminal():
				run["victory_action"] = int(run.get("actions", 0))
			return getaway_label
	return ""


func _travel_to_planning_table_boundary(run_state: RunState, run: Dictionary, label: String) -> String:
	if str(run_state.current_environment.get("archetype_id", "")) == "small_underground_casino":
		return ""
	return _travel_to_node_boundary(run_state, run, _world_node_for_archetype(run_state, "small_underground_casino"), false, label)


func _heist_count_setup_boundary(run_state: RunState, run: Dictionary, heist: Dictionary) -> String:
	var setup := _dict(heist.get("setup", {}))
	var state := _dict(run.get("style_state", {}))
	if not bool(setup.get("identity", false)):
		if bool(state.get("identity_leave_required", false)) and str(run_state.current_environment.get("archetype_id", "")) == GRAND_CASINO_ID:
			for reset_archetype in ["bar", "motel", "gas_station_casino"]:
				var reset_label := _travel_to_node_boundary(run_state, run, _world_node_for_archetype(run_state, reset_archetype), false, "heist_identity_reset")
				if not reset_label.is_empty():
					state["identity_leave_required"] = false
					run["style_state"] = state
					return reset_label
		var grand_node_id := _world_node_for_archetype(run_state, GRAND_CASINO_ID)
		if str(run_state.current_environment.get("archetype_id", "")) != GRAND_CASINO_ID:
			return _travel_to_node_boundary(run_state, run, grand_node_id, false, "heist_identity_travel")
		var session := int(setup.get("identity_sessions", 0))
		var bet := 8 + posmod(_stable_hash(run_state.seed_text + ":identity:" + str(session)), 23)
		var label := _play_specific_game_boundary(run_state, run, "blackjack", "clean", bet, "heist_identity_session")
		if not label.is_empty() and int(_dict(run_state.crew_heist_snapshot().get("setup", {})).get("identity_sessions", session)) > session:
			state = _dict(run.get("style_state", {}))
			state["identity_leave_required"] = true
			run["style_state"] = state
		return label
	if run_state.delivery_has_active_run():
		var step := "heist_schedule" if not bool(setup.get("schedule", false)) else "heist_swap_cart"
		return _drive_active_delivery_boundary(run_state, run, step)
	var planning_label := _travel_to_planning_table_boundary(run_state, run, "heist_planning_travel")
	if not planning_label.is_empty():
		return planning_label
	for setup_choice in ["count_schedule", "count_cart"]:
		if setup_choice == "count_schedule" and bool(setup.get("schedule", false)):
			continue
		if setup_choice == "count_cart" and bool(setup.get("swap_cart", false)):
			continue
		if _resolve_public_event_choice(run_state, "crew_planning_table", setup_choice):
			_count_action(run, "event")
			return "heist_%s_begin" % setup_choice
		return ""
	return _heist_begin_play_boundary(run_state, run, heist)


func _heist_whale_setup_boundary(run_state: RunState, run: Dictionary, heist: Dictionary) -> String:
	if CrewHeistModelScript.setup_complete(heist):
		return _heist_begin_play_boundary(run_state, run, heist)
	if _try_buy_helpful_item(run_state, run, "clean"):
		_count_action(run, "item")
		return "heist_whale_setup_item"
	for game_id_value in _string_array(run_state.current_environment.get("game_ids", [])):
		var game_id := str(game_id_value)
		var label := _play_specific_game_boundary(run_state, run, game_id, "clean", 0, "heist_whale_setup_game:%s" % game_id)
		if not label.is_empty():
			return label
	return _seek_public_casino_boundary(run_state, run, "heist_whale_setup_travel")


func _heist_begin_play_boundary(run_state: RunState, run: Dictionary, _heist: Dictionary) -> String:
	var planning_label := _travel_to_planning_table_boundary(run_state, run, "heist_planning_travel")
	if not planning_label.is_empty():
		return planning_label
	if not _resolve_public_event_choice(run_state, "crew_planning_table", "begin_play"):
		return ""
	_count_action(run, "event")
	return "heist_begin_play"


func _heist_live_play_boundary(run_state: RunState, run: Dictionary, heist: Dictionary) -> String:
	var plan_id := str(heist.get("plan_id", ""))
	var grand_node_id := _world_node_for_archetype(run_state, GRAND_CASINO_ID)
	if not run_state.is_grand_casino_environment():
		return _travel_to_node_boundary(run_state, run, grand_node_id, false, "heist_live_table_travel")
	if plan_id == CrewHeistModelScript.PLAN_WHALE and str(run_state.current_environment.get("archetype_id", "")) != RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID:
		if generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID):
			_count_action(run, "travel")
			_record_visit(run, run_state)
			return "heist_high_limit_room"
		return ""
	var play := _dict(heist.get("play", {}))
	var round_index := int(play.get("round", 0))
	for choice_value in run_state.crew_heist_live_table_choices():
		var choice := _dict(choice_value)
		var choice_id := str(choice.get("id", ""))
		if choice_id.begins_with("go_") or choice_id.begins_with("distraction_") or choice_id.begins_with("exit_"):
			if _resolve_public_event_choice(run_state, "heist_live_table", choice_id):
				_count_action(run, "event")
				return "heist_decision:%s" % choice_id
	for terminal_choice in ["begin_interview", "begin_getaway"]:
		if _public_event_choice_enabled(run_state, "heist_live_table", terminal_choice) and _resolve_public_event_choice(run_state, "heist_live_table", terminal_choice):
			_count_action(run, "event")
			return "heist_%s" % terminal_choice
	var game_id := "blackjack"
	if plan_id == CrewHeistModelScript.PLAN_WHALE:
		var sequence := _string_array(_dict(CrewHeistModelScript.plan(plan_id).get("play", {})).get("game_sequence", []))
		if round_index < sequence.size():
			game_id = str(sequence[round_index])
	var bet := 8 + posmod(_stable_hash(run_state.seed_text + ":heist_bet:" + str(round_index)), 23)
	return _play_specific_game_boundary(run_state, run, game_id, "clean", bet, "heist_live_round:%s" % game_id)


func _public_event_choice_enabled(run_state: RunState, event_id: String, choice_id: String) -> bool:
	if not _current_event_ids(run_state).has(event_id):
		return false
	var event := EventModuleScript.new()
	event.setup(library.event(event_id), library)
	if not event.can_trigger(run_state, run_state.current_environment):
		return false
	for choice_value in event.choices(run_state, run_state.current_environment):
		var choice := _dict(choice_value)
		if str(choice.get("id", "")) == choice_id:
			return not bool(choice.get("disabled", false))
	return false


func _resolve_public_event_choice(run_state: RunState, event_id: String, choice_id: String) -> bool:
	if not _public_event_choice_enabled(run_state, event_id, choice_id):
		return false
	var event := EventModuleScript.new()
	event.setup(library.event(event_id), library)
	return bool(event.resolve(run_state, run_state.current_environment, choice_id).get("ok", false))


func _record_economy_boundary(run: Dictionary, run_state: RunState, label: String, before_bankroll: int, before_heat: int, before_debt: int) -> void:
	var bankroll_delta := run_state.bankroll - before_bankroll
	var heat_delta := run_state.suspicion_level() - before_heat
	var debt_delta := _total_debt_balance(run_state) - before_debt
	var entry := {
		"action": int(run.get("actions", 0)),
		"label": label,
		"bankroll_delta": bankroll_delta,
		"heat_delta": heat_delta,
		"debt_delta": debt_delta,
		"bankroll": run_state.bankroll,
		"heat": run_state.suspicion_level(),
		"debt": _total_debt_balance(run_state),
	}
	var ledger := _array(run.get("ledger", []))
	ledger.append(entry)
	run["ledger"] = ledger
	if bankroll_delta > 0:
		var sources := _dict(run.get("source_totals", {}))
		sources[label] = int(sources.get(label, 0)) + bankroll_delta
		run["source_totals"] = sources
	elif bankroll_delta < 0:
		var sinks := _dict(run.get("sink_totals", {}))
		sinks[label] = int(sinks.get(label, 0)) - bankroll_delta
		run["sink_totals"] = sinks
	run["peak_bankroll"] = maxi(int(run.get("peak_bankroll", run_state.bankroll)), run_state.bankroll)
	run["minimum_bankroll"] = mini(int(run.get("minimum_bankroll", run_state.bankroll)), run_state.bankroll)
	run["peak_heat"] = maxi(int(run.get("peak_heat", 0)), run_state.suspicion_level())
	run["peak_debt"] = maxi(int(run.get("peak_debt", 0)), _total_debt_balance(run_state))


func _record_thresholds(run: Dictionary, run_state: RunState) -> void:
	var action := int(run.get("actions", 0))
	var debt := _total_debt_balance(run_state)
	if debt > 0:
		run["debt_was_open"] = true
	elif bool(run.get("debt_was_open", false)) and int(run.get("first_debt_recovery_action", -1)) < 0:
		run["first_debt_recovery_action"] = action
	var debt_actions := _dict(run.get("first_debt_action", {}))
	for threshold in DEBT_THRESHOLDS:
		var key := str(threshold)
		if debt >= int(threshold) and not debt_actions.has(key):
			debt_actions[key] = action
	run["first_debt_action"] = debt_actions
	var bankroll_actions := _dict(run.get("first_bankroll_action", {}))
	for threshold in [75, 50, 25, 0]:
		var key := str(threshold)
		if run_state.bankroll <= threshold and not bankroll_actions.has(key):
			bankroll_actions[key] = action
	run["first_bankroll_action"] = bankroll_actions
	if run_state.suspicion_level() >= 50 and int(run.get("first_heat_50_action", -1)) < 0:
		run["first_heat_50_action"] = action
	if run_state.suspicion_level() >= 80 and int(run.get("first_heat_80_action", -1)) < 0:
		run["first_heat_80_action"] = action


func _is_pressure_terminal(run: Dictionary) -> bool:
	return str(run.get("failure_reason", "")) in [RunState.FAILURE_BANKROLL_ZERO, RunState.FAILURE_STRANDED, RunState.FAILURE_POLICE_CAPTURE, RunState.FAILURE_CASINO_TAKEN_OUT_BACK]


func _audit_aggregate(runs: Array, max_actions: int) -> Dictionary:
	var rows: Array = []
	for style_value in PLAYSTYLES:
		var style_id := str(_dict(style_value).get("id", ""))
		var selected := _filter_runs(runs, "playstyle", style_id)
		if selected.is_empty():
			continue
		var observed_terminals := _uncensored_runs(selected)
		var pusher_reached := _bool_runs(selected, "pusher_machine_reached")
		rows.append({
			"playstyle": style_id,
			"run_count": selected.size(),
			"final_bankroll": _distribution(selected, "final_bankroll"),
			"peak_bankroll": _distribution(selected, "peak_bankroll"),
			"minimum_bankroll": _distribution(selected, "minimum_bankroll"),
			"actions": _distribution(selected, "actions"),
			"final_heat": _distribution(selected, "final_heat"),
			"peak_heat": _distribution(selected, "peak_heat"),
			"final_debt": _distribution(selected, "debt_balance"),
			"final_debt_principal": _distribution(selected, "debt_principal"),
			"final_debt_interest": _distribution(selected, "debt_interest"),
			"inventory_value": _distribution(selected, "inventory_value"),
			"liquid_cash": _distribution(selected, "liquid_cash"),
			"net_position": _distribution(selected, "net_position"),
			"bankroll_reconciliation_delta": _distribution(selected, "bankroll_reconciliation_delta"),
			"peak_debt": _distribution(selected, "peak_debt"),
			"route_cost_total": _distribution(selected, "route_cost_total"),
			"game_actions": _distribution(selected, "game_actions"),
			"travel_count": _distribution(selected, "travel_count"),
			"victory_action": _distribution_nonnegative(selected, "victory_action"),
			"first_debt_recovery_action": _distribution_nonnegative(selected, "first_debt_recovery_action"),
			"victory_action_by_route": _grouped_nonnegative_distribution(selected, "victory_route", "victory_action"),
			"victory_rate": _rate_stat(_won_count(selected), selected.size()),
			"conditioned_probe_rate": _rate_stat(_bool_count(selected, "conditioned_probe"), selected.size()),
			"pusher_machine_reached_rate": _rate_stat(pusher_reached.size(), selected.size()),
			"pusher_variation_counts": _value_counts(pusher_reached, "pusher_variation"),
			"pusher_reached_final_bankroll": _distribution(pusher_reached, "final_bankroll"),
			"pusher_reached_final_bankroll_by_variation": _grouped_nonnegative_distribution(pusher_reached, "pusher_variation", "final_bankroll"),
			"pusher_reached_actions": _distribution(pusher_reached, "actions"),
			"terminal_observation_rate": _rate_stat(observed_terminals.size(), selected.size()),
			"censored_action_cap_rate": _rate_stat(_bool_count(selected, "censored"), selected.size()),
			"pressure_terminal_rate_observed_terminals": _rate_stat(_bool_count(observed_terminals, "pressure_terminal"), observed_terminals.size()),
			"choice_terminal_rate_observed_terminals": _rate_stat(_bool_count(observed_terminals, "choice_terminal"), observed_terminals.size()),
			"pressure_terminal_share_all_runs": _rate_stat(_bool_count(selected, "pressure_terminal"), selected.size()),
			"choice_terminal_share_all_runs": _rate_stat(_bool_count(selected, "choice_terminal"), selected.size()),
			"failure_causes_observed_terminals": _value_counts(observed_terminals, "failure_reason"),
			"victory_routes": _value_counts(selected, "victory_route"),
			"debt_threshold_actions": _threshold_distributions(selected),
			"bankroll_threshold_actions": _bankroll_threshold_distributions(selected),
			"source_totals": _map_value_distributions(selected, "source_totals"),
			"sink_totals": _map_value_distributions(selected, "sink_totals"),
			"game_mix": _map_value_distributions(selected, "game_mix"),
			"game_action_share": _map_share_distributions(selected, "game_mix", "game_actions"),
			"opportunity_denominators": _opportunity_aggregate(selected),
			"bankroll_curve": _curve_distribution(selected, max_actions),
		})
	return {"playstyles": rows}


func _distribution(runs: Array, key: String) -> Dictionary:
	var values: Array = []
	for run_value in runs:
		if typeof(run_value) == TYPE_DICTIONARY:
			values.append(float((run_value as Dictionary).get(key, 0)))
	return _distribution_values(values)


func _distribution_nonnegative(runs: Array, key: String) -> Dictionary:
	var values: Array = []
	for run_value in runs:
		if typeof(run_value) != TYPE_DICTIONARY:
			continue
		var value := float((run_value as Dictionary).get(key, -1))
		if value >= 0:
			values.append(value)
	return _distribution_values(values)


func _grouped_nonnegative_distribution(runs: Array, group_key: String, value_key: String) -> Dictionary:
	var grouped := {}
	for run_value in runs:
		if typeof(run_value) != TYPE_DICTIONARY:
			continue
		var run: Dictionary = run_value
		var group := str(run.get(group_key, "")).strip_edges()
		var value := float(run.get(value_key, -1))
		if group.is_empty() or value < 0:
			continue
		var values := _array(grouped.get(group, []))
		values.append(value)
		grouped[group] = values
	var result := {}
	for group_value in grouped.keys():
		result[str(group_value)] = _distribution_values(_array(grouped.get(group_value, [])))
	return result


func _distribution_values(values: Array) -> Dictionary:
	if values.is_empty():
		return {"n": 0}
	values.sort()
	var total := 0.0
	for value in values:
		total += float(value)
	var mean := total / float(values.size())
	var squared := 0.0
	for value in values:
		squared += pow(float(value) - mean, 2.0)
	var standard_deviation := sqrt(squared / float(maxi(1, values.size() - 1)))
	var margin_95 := 1.96 * standard_deviation / sqrt(float(values.size()))
	return {
		"n": values.size(),
		"min": float(values[0]),
		"p05": _percentile(values, 0.05),
		"p25": _percentile(values, 0.25),
		"median": _percentile(values, 0.50),
		"p75": _percentile(values, 0.75),
		"p95": _percentile(values, 0.95),
		"max": float(values[-1]),
		"mean": mean,
		"sample_standard_deviation": standard_deviation,
		"mean_ci95_lower": mean - margin_95,
		"mean_ci95_upper": mean + margin_95,
	}


func _rate_stat(numerator: int, denominator: int) -> Dictionary:
	if denominator <= 0:
		return {"n": 0, "numerator": numerator, "rate": null, "ci95": null, "method": "wilson_score"}
	var n := float(denominator)
	var p := float(numerator) / n
	var z := 1.959963984540054
	var z2 := z * z
	var denominator_adjusted := 1.0 + z2 / n
	var center := (p + z2 / (2.0 * n)) / denominator_adjusted
	var radius := z * sqrt((p * (1.0 - p) + z2 / (4.0 * n)) / n) / denominator_adjusted
	return {
		"n": denominator,
		"numerator": numerator,
		"rate": p,
		"ci95": {"lower": maxf(0.0, center - radius), "upper": minf(1.0, center + radius)},
		"method": "wilson_score",
	}


func _opportunity_aggregate(runs: Array) -> Dictionary:
	var result := _empty_opportunity_ledger()
	for run_value in runs:
		var run := _dict(run_value)
		var ledger := _dict(run.get("opportunities", {}))
		for system_id in OPPORTUNITY_SYSTEMS:
			var total := _dict(result.get(system_id, {}))
			var row := _dict(ledger.get(system_id, {}))
			for key in ["observations", "available_actions", "visible", "inaccessible", "selected", "accepted", "rejected", "settled", "visible_not_selected"]:
				total[key] = int(total.get(key, 0)) + int(row.get(key, 0))
			result[system_id] = total
	for system_id in OPPORTUNITY_SYSTEMS:
		var row := _dict(result.get(system_id, {}))
		row["rates"] = {
			"selected_per_visible_offer": _rate_stat(int(row.get("selected", 0)), int(row.get("visible", 0))),
			"accepted_per_selection": _rate_stat(int(row.get("accepted", 0)), int(row.get("selected", 0))),
			"rejected_per_selection": _rate_stat(int(row.get("rejected", 0)), int(row.get("selected", 0))),
			"settled_per_acceptance": _rate_stat(int(row.get("settled", 0)), int(row.get("accepted", 0))),
			"available_per_observed_action": _rate_stat(int(row.get("available_actions", 0)), int(row.get("observations", 0))),
			"inaccessible_per_observed_action": _rate_stat(int(row.get("inaccessible", 0)), int(row.get("observations", 0))),
		}
		result[system_id] = row
	return result


func _percentile(sorted_values: Array, fraction: float) -> float:
	if sorted_values.size() == 1:
		return float(sorted_values[0])
	var position := clampf(fraction, 0.0, 1.0) * float(sorted_values.size() - 1)
	var low := int(floor(position))
	var high := int(ceil(position))
	var weight := position - float(low)
	return lerpf(float(sorted_values[low]), float(sorted_values[high]), weight)


func _bool_count(runs: Array, key: String) -> int:
	var count := 0
	for run_value in runs:
		if typeof(run_value) == TYPE_DICTIONARY and bool((run_value as Dictionary).get(key, false)):
			count += 1
	return count


func _uncensored_runs(runs: Array) -> Array:
	var result: Array = []
	for run_value in runs:
		if typeof(run_value) == TYPE_DICTIONARY and not bool((run_value as Dictionary).get("censored", false)):
			result.append(run_value)
	return result


func _bool_runs(runs: Array, key: String) -> Array:
	var result: Array = []
	for run_value in runs:
		if typeof(run_value) == TYPE_DICTIONARY and bool((run_value as Dictionary).get(key, false)):
			result.append(run_value)
	return result


func _value_counts(runs: Array, key: String) -> Dictionary:
	var counts := {}
	for run_value in runs:
		if typeof(run_value) != TYPE_DICTIONARY:
			continue
		var value := str((run_value as Dictionary).get(key, ""))
		if value.is_empty():
			value = "none"
		counts[value] = int(counts.get(value, 0)) + 1
	return counts


func _threshold_distributions(runs: Array) -> Dictionary:
	var result := {}
	for threshold in DEBT_THRESHOLDS:
		var values: Array = []
		for run_value in runs:
			if typeof(run_value) != TYPE_DICTIONARY:
				continue
			var row := _dict((run_value as Dictionary).get("first_debt_action", {}))
			if row.has(str(threshold)):
				values.append(float(row[str(threshold)]))
		result[str(threshold)] = _distribution_values(values)
	return result


func _bankroll_threshold_distributions(runs: Array) -> Dictionary:
	var result := {}
	for threshold in [75, 50, 25, 0]:
		var values: Array = []
		for run_value in runs:
			if typeof(run_value) != TYPE_DICTIONARY:
				continue
			var row := _dict((run_value as Dictionary).get("first_bankroll_action", {}))
			if row.has(str(threshold)):
				values.append(float(row[str(threshold)]))
		result[str(threshold)] = _distribution_values(values)
	return result


func _map_value_distributions(runs: Array, key: String) -> Dictionary:
	var all_keys: Array = []
	for run_value in runs:
		if typeof(run_value) != TYPE_DICTIONARY:
			continue
		for value_key in _dict((run_value as Dictionary).get(key, {})).keys():
			var text_key := str(value_key)
			if not all_keys.has(text_key):
				all_keys.append(text_key)
	all_keys.sort()
	var result := {}
	for value_key in all_keys:
		var values: Array = []
		for run_value in runs:
			if typeof(run_value) == TYPE_DICTIONARY:
				values.append(float(_dict((run_value as Dictionary).get(key, {})).get(value_key, 0)))
		result[value_key] = _distribution_values(values)
	return result


func _map_share_distributions(runs: Array, map_key: String, denominator_key: String) -> Dictionary:
	var all_keys: Array = []
	for run_value in runs:
		if typeof(run_value) != TYPE_DICTIONARY:
			continue
		for value_key in _dict((run_value as Dictionary).get(map_key, {})).keys():
			var text_key := str(value_key)
			if not all_keys.has(text_key):
				all_keys.append(text_key)
	all_keys.sort()
	var result := {}
	for value_key in all_keys:
		var values: Array = []
		for run_value in runs:
			if typeof(run_value) != TYPE_DICTIONARY:
				continue
			var run: Dictionary = run_value
			var denominator := maxi(0, int(run.get(denominator_key, 0)))
			if denominator > 0:
				values.append(float(_dict(run.get(map_key, {})).get(value_key, 0)) / float(denominator))
		result[value_key] = _distribution_values(values)
	return result


func _curve_distribution(runs: Array, max_actions: int) -> Array:
	var rows: Array = []
	for action in range(0, max_actions + 1, 8):
		var bankrolls: Array = []
		var heats: Array = []
		var debts: Array = []
		var principals: Array = []
		var interests: Array = []
		var inventory_values: Array = []
		var liquid_values: Array = []
		var net_positions: Array = []
		for run_value in runs:
			if typeof(run_value) != TYPE_DICTIONARY:
				continue
			var curve := _array((run_value as Dictionary).get("curve", []))
			if curve.is_empty():
				continue
			var index := mini(action, curve.size() - 1)
			var point := _dict(curve[index])
			bankrolls.append(float(point.get("bankroll", 0)))
			heats.append(float(point.get("heat", 0)))
			debts.append(float(point.get("debt_balance", 0)))
			principals.append(float(point.get("debt_principal", 0)))
			interests.append(float(point.get("debt_interest", 0)))
			inventory_values.append(float(point.get("inventory_value", 0)))
			liquid_values.append(float(point.get("liquid_cash", point.get("bankroll", 0))))
			net_positions.append(float(point.get("net_position", 0)))
		rows.append({
			"action": action,
			"bankroll": _distribution_values(bankrolls),
			"liquid_cash": _distribution_values(liquid_values),
			"inventory_value": _distribution_values(inventory_values),
			"debt": _distribution_values(debts),
			"debt_principal": _distribution_values(principals),
			"debt_interest": _distribution_values(interests),
			"net_position": _distribution_values(net_positions),
			"heat": _distribution_values(heats),
		})
	return rows


func _write_audit_json(path: String, report: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write audit report: %s" % absolute)
		return false
	file.store_string(JSON.stringify(report, "\t", false) + "\n")
	file.close()
	return true
