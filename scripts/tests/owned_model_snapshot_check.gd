extends SceneTree
const Runtime:=preload("res://scripts/core/game_ritual_runtime.gd")
const FIXTURE:="res://scripts/tests/fixtures/integ06_1/v0_5_1/v051_grand_casino_back_room_duel.json"
var failures:Array[String]=[]

class LegacyRun extends RunState:
	func _apply_environment_turn_snapshot(snapshot:Dictionary,preserve:bool)->void:
		var old:=snapshot.duplicate(false)
		for key in ["town_state_object","numbers_state_object"]:
			var record:Dictionary=snapshot.get(key,{}).duplicate(true)
			for member in ["state","conditions","config"]:
				if typeof(record.get(member))==TYPE_DICTIONARY:record[member]=record[member].duplicate(true)
			old[key]=record
		super._apply_environment_turn_snapshot(old,preserve)

func _initialize()->void:call_deferred("_run")
func _run()->void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():quit(2);return
	var save:=SaveService.new()
	var path:=save.run_save_path("owned_model_fixture")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(FIXTURE));file.close()
	var source:RunState=save.load_run("owned_model_fixture")
	if source==null:quit(1);return
	source.town_state._conditions=source.town_state._conditions.duplicate(true)
	source.town_state._conditions["clone_probe"]={"nested":[1]}
	var legacy:=LegacyRun.new()
	legacy._apply_environment_turn_snapshot(source._environment_turn_snapshot(),false)
	var candidate:=source.detached_host_action_candidate("blackjack")
	var old_candidate:=legacy.detached_host_action_candidate("blackjack")
	_check(_public(candidate)==_public(old_candidate),"owned snapshot restoration matches the previous copying path")
	var before:=_public(source)
	var old_conditions:=Runtime.canonical_json(source.town_state._conditions)
	var old_numbers:=Runtime.canonical_json(source.numbers_state.get("config"))
	_mutate(candidate)
	_check(_public(source)==before,"discarded candidate cannot alter any public source state")
	_check(Runtime.canonical_json(source.town_state._conditions)==old_conditions,"nested condition definitions remain detached")
	_check(Runtime.canonical_json(source.numbers_state.get("config"))==old_numbers,"numbers configuration remains detached")
	_mutate(old_candidate)
	var town_identity:=source.town_state
	var numbers_identity:=source.numbers_state
	_check(source.publish_host_action_candidate(candidate) and legacy.publish_host_action_candidate(old_candidate),"both accepted candidates publish")
	_check(_public(source)==_public(legacy),"publication preserves complete old/new state parity")
	_check(is_same(town_identity,source.town_state) and is_same(numbers_identity,source.numbers_state),"publication retains external model identities")
	print("OWNED_MODEL_SNAPSHOT ",JSON.stringify({"failures":failures,"fixture":"preserved migrated Rourke fixture","covers":["legacy value parity","nested isolation","discarded proposal","publication identities"]}))
	for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _mutate(run:RunState)->void:
	run.town_state._conditions.clone_probe.nested[0]=2
	run.town_state.living_world.reputation_incidents.append({"probe":[1,2]})
	run.town_state.living_world.seeded_scenario_definitions_by_node["probe"]={"nested":[3]}
	var config:Dictionary=run.numbers_state.get("config")
	config["clone_probe"]={"nested":[4]}
	run.narrative_flags["candidate_probe"]={"nested":[5]}

func _public(run:RunState)->String:
	var data:=run.to_save_snapshot().duplicate(true)
	var crew:Dictionary=data.get("crew_state",{})
	crew.erase("a");crew.erase("z")
	return Runtime.canonical_json(data)
func _check(ok:bool,message:String)->void:
	if not ok:failures.append(message)
