extends SceneTree

const Model:=preload("res://scripts/core/crew_recruitment_model.gd")
const Codec:=preload("res://scripts/core/run_save_codec.gd")
var checks:=0
var failures:Array[String]=[]

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var original:Dictionary={"schema_version":1,"meetings":{"crew_switch":{
		"member_id":"crew_switch","outcome":"accepted","path_kind":"primary",
		"first_outcome":"accepted","first_path_kind":"primary","action_index":17,
		"aftermath_id":"crew_switch_accepted","history":[{"action_index":17,"outcome":"accepted","path_kind":"primary"}]}},
		"contacts":{"crew_switch":{"action_index":17,"member_id":"crew_switch","standing":"associate","contact_state":"trusted"}}}
	_check(Model.normalize_encounter_state(original)==original,"strict runtime fixture is valid")
	var legacy:Variant=JSON.parse_string(JSON.stringify(original))
	_check(Model.normalize_encounter_state(legacy).is_empty(),"runtime normalizer still rejects float counters")
	_check(Model.encounter_state_from_save(legacy)==original,"legacy integral JSON counters restore exact public facts")
	_check(typeof(legacy.schema_version)==TYPE_FLOAT,"save migration does not mutate its input")
	var run:=RunState.new();run.start_new("CREW-ENCOUNTER-RESTORE")
	run.crew_recruitment_encounters=original.duplicate(true)
	var before:=run.to_save_snapshot()
	var restored:=RunState.new()
	restored.from_dict(Codec.decode(JSON.parse_string(JSON.stringify(Codec.encode(before)))))
	_check(restored.crew_recruitment_encounters==original,"official codec/RunState roundtrip retains all encounters")
	_check(restored.bankroll==run.bankroll and restored.rng_state==run.rng_state and restored.crew_trust_by_member==run.crew_trust_by_member,"restore replays no money/RNG/trust reward")
	for bad_value in [-1.0,0.5,NAN,INF,"17",null,9007199254740992.0]:
		for target in ["schema","meeting","history","contact"]:
			var bad:=original.duplicate(true)
			match target:
				"schema":bad.schema_version=bad_value
				"meeting":bad.meetings.crew_switch.action_index=bad_value
				"history":bad.meetings.crew_switch.history[0].action_index=bad_value
				"contact":bad.contacts.crew_switch.action_index=bad_value
			_check(Model.encounter_state_from_save(bad).is_empty(),"malformed %s counter rejected: %s"%[target,str(bad_value)])
	var unknown:=original.duplicate(true);unknown.meetings.crew_switch.untrusted_reward=1
	_check(Model.encounter_state_from_save(unknown).is_empty(),"unknown keys remain rejected")
	var schema:=original.duplicate(true);schema.schema_version=2.0
	_check(Model.encounter_state_from_save(schema).is_empty(),"unknown schema remains rejected")
	var output:=OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Synthetic declared counters plus official codec/RunState; no original QA state or gameplay mutation"},"  "));file.close()
	print("CREW_ENCOUNTER_RESTORE checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func _check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
