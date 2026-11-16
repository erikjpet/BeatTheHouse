extends SceneTree

# Synthetic read-only projection contracts. No captured profile is loaded,
# copied, ranked, recruited, accepted, saved or otherwise changed. Presence and
# ranks below are explicit fixture inputs, not claims about the live campaign.
const Event := preload("res://scripts/core/event_module.gd")
const Crew := preload("res://scripts/core/crew_state_model.gd")
const Schedule := preload("res://scripts/core/crew_delivery_schedule.gd")
const ROUTES := ["rook_quiet_package", "switch_two_stop_signal", "bishop_camera_window", "knuckles_friendly_collection"]
const STAKE := "mags_low_roller_stake"

class FixtureRun:
	extends "res://scripts/core/run_state.gd"
	var fixture_active := false
	var fixture_scene_allowed := true
	var fixture_board: Variant
	var quote_calls: Array[String] = []
	func delivery_has_active_run() -> bool:
		return fixture_active
	func crew_package_scene_allows_offer(_environment: Dictionary = {}) -> bool:
		return fixture_scene_allowed
	func delivery_crew_offer(definition_id: String, _offered_clock: int = -1) -> Dictionary:
		quote_calls.append(definition_id)
		return {"ok": true, "message": "Synthetic current appointment terms."}
	func crew_job_board_choices(payload: Dictionary = {}) -> Array:
		return fixture_board.crew_job_board_choices(payload) if fixture_board != null else []

class FixtureFacade:
	extends "res://scripts/core/crew_run_facade.gd"
	var fixture_members: Array = []
	var fixture_ranks: Dictionary = {}
	func crew_member_present(member_id: String, _environment: Dictionary = {}) -> bool:
		return fixture_members.has(member_id)
	func crew_rank(member_id: String) -> String:
		return str(fixture_ranks.get(member_id, "stranger"))

var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _fixture() -> FixtureRun:
	var run := FixtureRun.new()
	run.start_new("SYNTHETIC-CONCURRENT-CREW-OFFERS")
	run.bankroll = 100
	run.game_clock_minutes = 1234
	run.current_environment = {"id": "synthetic_board", "archetype_id": "small_underground_casino", "kind": "crew", "current_layer_id": "back_room", "turns": 3}
	run.narrative_flags["crew_delivery_obligations"] = 1
	var facade := FixtureFacade.new()
	facade.bind(run)
	facade.fixture_members = Crew.MEMBER_IDS.duplicate()
	for member in facade.fixture_members:
		facade.fixture_ranks[member] = "associate"
	run.fixture_board = facade
	return run

func _state(run: FixtureRun) -> String:
	var facade: FixtureFacade = run.fixture_board
	return JSON.stringify({"cash": run.bankroll, "debt": run.debt, "inventory": run.inventory, "flags": run.narrative_flags, "rng": str(run.rng_state), "clock": run.game_clock_minutes, "cadence": run.event_cadence, "delivery": run.active_delivery_run, "run_jobs": run.crew_jobs, "facade_jobs": facade.jobs, "job_sequence": facade.job_sequence, "trust": facade.trust_by_member, "active_fixture": run.fixture_active})

func _offer_ids(offers: Array) -> Array:
	var result: Array = []
	for offer in offers:
		result.append(str(offer.get("definition_id", "")))
	return result

func _choice_ids(rows: Array) -> Array:
	var result: Array = []
	for row in rows:
		result.append(str(row.get("id", "")))
	return result

func _row(definition_id: String) -> Dictionary:
	return {"id": "accept_" + definition_id, "label": "Authored " + definition_id, "text": "Authored response.", "requires_confirm": true, "conditions": {"fixture_guard": true}, "consequences": {"event_hooks": [{"type": "crew_job_accept", "definition_id": definition_id}]}}

func _cached_rows() -> Array:
	var rows: Array = []
	for id in ROUTES:
		rows.append(_row(str(id)))
	var stake := _row(STAKE)
	stake["disabled"] = true
	stake["enabled"] = false
	stake["disabled_reason"] = "Authored stake reason."
	rows.append(stake)
	rows.append({"id": "leave", "label": "Leave the board", "text": "No promise made.", "consequences": {}})
	return rows

func _module() -> Variant:
	var event := Event.new()
	event.setup({"id": "crew_job_board", "payload": {"kind": "crew_job_board"}})
	return event

func _run() -> void:
	if not OS.get_environment("BTH_QA_RUN_DIR").replace("\\", "/").begins_with("E:/CodexQA/BTH/runs/"):
		_expect(false, "admitted isolated E QA run required")
		_finish()
		return
	var run := _fixture()
	var facade: FixtureFacade = run.fixture_board
	var before := _state(run)
	var idle_ids := _offer_ids(facade.crew_job_board_offers())
	for id in ROUTES:
		_expect(idle_ids.has(id), "eligible idle fixture retains real authored route " + str(id))
	_expect(idle_ids.has(STAKE), "eligible idle fixture retains the stake offer")
	_expect(_state(run) == before, "idle board projection consumes no game state")
	facts["idle_offer_ids"] = idle_ids
	var cached_rows := _cached_rows()
	var rows_before := JSON.stringify(cached_rows)
	# Each mode occupies the same authoritative route slot. No mission is begun.
	for mode in ["package", "multi_stop", "hold", "getaway"]:
		run.fixture_active = true
		run.active_delivery_run = {"status": "active", "run_id": "synthetic-" + str(mode), "mode": mode}
		before = _state(run)
		var offers: Array = facade.crew_job_board_offers()
		var route_count := 0
		for offer in offers:
			if Schedule.is_route_kind(str(offer.get("kind", ""))):
				route_count += 1
		_expect(route_count == 0, "active " + str(mode) + " suppresses every competing route offer")
		_expect(_offer_ids(offers).has(STAKE), "active " + str(mode) + " leaves stake availability unchanged")
		var event = _module()
		run.quote_calls.clear()
		var projected: Array = event._crew_timed_choices(cached_rows, run)
		_expect(_choice_ids(projected) == ["accept_" + STAKE, "leave"], "cached contact/board rows cannot re-advertise routes during " + str(mode))
		_expect(projected[0] == cached_rows[4] and projected[1] == cached_rows[5], "stake authored disabled reason confirmation and Leave survive " + str(mode))
		_expect(run.quote_calls.is_empty(), "active " + str(mode) + " previews no new timed package")
		var public_rows: Array = event.choice_views(run, run.current_environment)
		for id in ROUTES:
			_expect(not _choice_ids(public_rows).has("accept_" + str(id)), "public board omits competing " + str(id) + " during " + str(mode))
		_expect(_choice_ids(public_rows).has("accept_" + STAKE) and _choice_ids(public_rows).has("leave"), "public board keeps stake and Leave during " + str(mode))
		_expect(_state(run) == before and JSON.stringify(cached_rows) == rows_before, "active " + str(mode) + " projection changes no money debt RNG clock jobs duties or input rows")
		# Existing acceptance remains the owner. These are rejected stale calls on
		# detached fixtures, not player progression or a successful job acceptance.
		for id in ROUTES:
			var rejected: Dictionary = facade.crew_job_accept_definition(str(id))
			_expect(not bool(rejected.get("ok", true)) and str(rejected.get("message", "")).contains("current delivery"), "host still rejects concurrent stale route " + str(id) + " during " + str(mode))
		_expect(_state(run) == before, "rejected concurrent routes mutate no game state during " + str(mode))
	run.fixture_active = false
	run.active_delivery_run = {}
	run.fixture_scene_allowed = false
	before = _state(run)
	var encounter_ids := _offer_ids(facade.crew_job_board_offers())
	_expect(encounter_ids.has("knuckles_friendly_collection") and encounter_ids.has("bishop_camera_window"), "package-specific encounter gate does not expand to collection or lookout")
	_expect(encounter_ids.has(STAKE), "package-specific encounter gate leaves stake available")
	_expect(not encounter_ids.has("rook_quiet_package") and not encounter_ids.has("switch_two_stop_signal"), "package and numbers routes retain their authored encounter gate")
	var event = _module()
	run.quote_calls.clear()
	var encounter_rows: Array = event._crew_timed_choices(cached_rows, run)
	_expect(_choice_ids(encounter_rows) == ["accept_bishop_camera_window", "accept_knuckles_friendly_collection", "accept_" + STAKE, "leave"], "cached row revalidation retains collection lookout and stake outside the package encounter window")
	_expect(run.quote_calls.is_empty() and _state(run) == before, "blocked package encounter previews no route and changes no game state")
	run.fixture_scene_allowed = true
	run.quote_calls.clear()
	var ordinary_rows: Array = event._crew_timed_choices(cached_rows, run)
	_expect(ordinary_rows.size() == cached_rows.size(), "idle eligible rows retain all original identities")
	_expect(run.quote_calls == ["rook_quiet_package", "switch_two_stop_signal"], "only package kinds obtain timed appointment previews")
	for index in [2, 3, 4, 5]:
		_expect(ordinary_rows[index] == cached_rows[index], "non-package authored row remains byte-equivalent " + str(index))
	for index in [0, 1]:
		var hook: Dictionary = ordinary_rows[index].consequences.event_hooks[0]
		_expect(int(hook.get("offered_clock", -1)) == run.game_clock_minutes and ordinary_rows[index].has("package_offer_terms"), "existing package terms and quote clock retained " + str(index))
	_expect(JSON.stringify(cached_rows) == rows_before and _state(run) == before, "ordinary quote projection changes no input rows or game state")
	facade.fixture_members.erase("crew_knuckles")
	_expect(not _offer_ids(facade.crew_job_board_offers()).has("knuckles_friendly_collection"), "authored member-presence gate remains intact")
	facade.fixture_members.append("crew_knuckles")
	facade.fixture_ranks["crew_knuckles"] = "stranger"
	_expect(not _offer_ids(facade.crew_job_board_offers()).has("knuckles_friendly_collection"), "authored individual-rank gate remains intact")
	facade.fixture_ranks["crew_knuckles"] = "associate"
	facade.jobs["synthetic-pending"] = {"definition_id": "knuckles_friendly_collection", "status": "active"}
	_expect(not _offer_ids(facade.crew_job_board_offers()).has("knuckles_friendly_collection"), "existing pending-definition gate remains intact")
	_finish()

func _finish() -> void:
	print("CREW_CONCURRENT_ROUTE_OFFERS " + JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "fidelity": "Synthetic detached real-job-definition facade and EventModule projection contracts; fixture presence/rank are explicit. No captured state, successful acceptance, gameplay, Save/Continue or browser coverage."}))
	quit(0 if failures.is_empty() else 1)
