extends SceneTree
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
var failures: Array[String] = []
var checked := 0

func _initialize() -> void:
	var corpus: Array = [null,true,false,0,9223372036854775807,-9223372036854775807,0.0,-0.0,0.125,1e-19,1e21,"\"\\\nπ😀",{},[],{1:"integer","1":"string"},{&"name":1},[Vector2.ONE,Rect2(1,2,3,4),PackedInt32Array([1,2]),&"name"]]
	var random := RandomNumberGenerator.new()
	random.seed=834391
	for n in range(300):
		var dictionary: Dictionary = {}
		for index in range(6):
			var key: String = ["z","α","A","","a","😀"][index]
			dictionary[key] = [corpus[random.randi_range(0,corpus.size()-1)],random.randi_range(-100000,100000),random.randf_range(-100,100)]
		_check(dictionary)
	for value in corpus: _check(value)
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/integ06_1/v0_5_1/v051_grand_casino_back_room_duel.json"))
	var started:=Time.get_ticks_usec()
	var legacy:=Runtime.canonical_json(fixture)
	var legacy_usec:=Time.get_ticks_usec()-started
	started=Time.get_ticks_usec()
	var native:=Runtime.canonical_json_native(fixture)
	var native_usec:=Time.get_ticks_usec()-started
	_check(fixture)
	print("CANONICAL_NATIVE_EVIDENCE ",JSON.stringify({"checked":checked,"failures":failures,"legacy_usec":legacy_usec,"native_usec":native_usec,"exact":legacy==native}))
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check(value: Variant) -> void:
	checked+=1
	if Runtime.canonical_json(value)!=Runtime.canonical_json_native(value):failures.append("canonical bytes differ in case%d"%checked)
