extends SceneTree

const State := preload("res://scripts/core/run_state.gd")
const Generator := preload("res://scripts/core/run_generator.gd")
const Host := preload("res://scripts/ui/foundation_main.gd")
const Travel := preload("res://scripts/ui/foundation_travel_view_model.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	var generator := Generator.new(ContentLibrary.new())
	for room in ["grand_casino", "grand_casino_high_limit", "grand_casino_cage", "grand_casino_back_room"]:
		for phase in ["pending", "active", "duel"]:
			var run := State.new()
			run.start_new("ROURKE-TRAVEL-LOCK")
			run.current_environment = {"id":room,"archetype_id":room}
			if phase == "duel": run.narrative_flags["grand_casino_duel_state"] = {"status":"active"}
			else: run.narrative_flags["grand_casino_showdown_" + phase] = true
			var before := JSON.stringify(run.to_dict())
			_expect(run.grand_casino_outward_travel_locked(), "summons and active duel lock each Grand room")
			for target in ["motel", "back_alley", "kitty_cat_lounge", "small_underground_casino"]:
				var status := run.travel_route_status({"id":target,"cost":0,"distance":"near"})
				_expect(not bool(status.get("available",true)) and str(status.get("disabled_reason","")).contains("Rourke"), "outward map/ride route is disabled even when free")
				var preflight := run.scenario_preflight_environment_change(room,target,"world")
				_expect(not bool(preflight.get("ok",true)), "authoritative world boundary rejects stale route")
			_expect(not bool(generator.travel_environment_result(run,"motel",true).get("ok",true)), "generator cannot bypass restriction with prevalidated target")
			_expect(bool(run.scenario_preflight_environment_change(room,"grand_casino_back_room","grand_room").get("ok",false)), "required casino room transitions remain allowed")
			for target in ["grand_casino", "grand_casino_high_limit", "grand_casino_cage", "grand_casino_back_room"]:
				var inside := run.travel_route_status({"id":target,"destination_archetype":target,"target_node_id":"grand_casino","local_casino_room":true,"cost":0})
				_expect(bool(inside.get("available",false)), "actual internal room route projection remains available to existing room access checks")
				_expect(bool(run.scenario_preflight_environment_change(room,target,"world").get("ok",false)), "Grand destination is preserved even through world-kind preflight")
			_expect(bool(run.scenario_preflight_environment_change(room,"","layer").get("ok",false)), "internal layer transitions remain allowed")
			_expect(JSON.stringify(run.to_dict()) == before, "blocked routes and projections change no money, RNG, clock or state")
			run.run_status = State.RUN_STATUS_ENDED
			_expect(not run.grand_casino_outward_travel_locked(), "completed ending releases Rourke restriction without overriding terminal navigation")
	var ordinary := State.new()
	ordinary.start_new("NO-ROURKE-TRAVEL-LOCK")
	ordinary.current_environment = {"id":"grand_casino","archetype_id":"grand_casino"}
	_expect(not ordinary.grand_casino_outward_travel_locked(), "ordinary casino visit remains free to leave")
	ordinary.narrative_flags["grand_casino_showdown_pending"] = true
	ordinary.current_environment = {"id":"motel","archetype_id":"motel"}
	_expect(not ordinary.grand_casino_outward_travel_locked(), "legacy already-offsite save is not stranded or teleported")
	ordinary.current_environment = {"id":"grand_casino","archetype_id":"grand_casino"}
	ordinary.narrative_flags["grand_casino_showdown_pending"] = false
	var cache_host := Host.new()
	cache_host.run_state = ordinary
	var count_before := ordinary.narrative_flags.size()
	var unlocked_key: String = Travel.travel_base_cache_key(cache_host)
	ordinary.narrative_flags["grand_casino_showdown_pending"] = true
	_expect(Travel.travel_base_cache_key(cache_host) != unlocked_key and ordinary.narrative_flags.size() == count_before, "cached map choices cannot retain enabled routes when an existing summons flag changes")
	cache_host.free()
	var f := FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"fidelity":"Synthetic read-only route/preflight/generator boundary checks across pending/active/duel and casino rooms. Actual saved/UI/Continue paths separately qualified."},"  ")); f.close()
	print("ROURKE_TRAVEL_LOCK checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
