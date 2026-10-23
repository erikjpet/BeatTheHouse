extends SceneTree

const Codec := preload("res://scripts/core/run_save_codec.gd")
var failures: Array[String] = []
var cases: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _case(label: String, source: String, require_valid: bool = false) -> void:
	var parser := JSON.new()
	var expected: bool = parser.parse(source) == OK and typeof(parser.data) == TYPE_DICTIONARY and Codec._required_content_roots(parser.data)
	if require_valid and not expected: failures.append(label + ": required genuine/normal content invalid")
	cases.append({"label":label,"source":source,"expected":expected})
	var bytes := source.to_utf8_buffer()
	var compressed := bytes.compress(FileAccess.COMPRESSION_ZSTD)
	var packed := {Codec.STORAGE_MARKER_KEY:Codec.STORAGE_FORMAT,Codec.STORAGE_DATA_KEY:Codec._z85_encode(compressed),
		Codec.STORAGE_HASH_KEY:Codec._sha256(bytes),Codec.STORAGE_SIZE_KEY:bytes.size(),Codec.STORAGE_COMPRESSED_SIZE_KEY:compressed.size()}
	if Codec.storage_contents_valid(packed) != expected: failures.append(label + ": native content parity")
	packed[Codec.STORAGE_HASH_KEY] = "0".repeat(64)
	if Codec.storage_contents_valid(packed): failures.append(label + ": damaged content accepted")

func _run() -> void:
	var output := OS.get_environment("BTH_CONTENT_VALIDATION_CORPUS")
	if output.is_empty(): quit(2); return
	var root_prefix := '{"seed_text":"probe","rng_state":"9223372036854775806","current_environment":'
	for token in ['{}','null','[]','true','0','"room"','{"__proto__":{"polluted":true}}']:
		_case("root value " + token, root_prefix + token + '}', true)
	for token in ['0','-0','1','-1','3.0','0e+0','01','1.','.1','+1','1E400','-1e400','1e308','1e-999','9223372036854775807','-9223372036854775808']:
		_case("number " + token, root_prefix + '{"number":' + token + '}}')
	for token in ['"plain"','"\\u0000"','"\\ud800"','"\\udc00"','"\\ud800\\udc00"','"\\udbff\\udfff"','"\\ud800x"','"\\uD83D\\uDE00"','"a\\nb"','"a\\u2028b"']:
		_case("Unicode " + token, root_prefix + '{"text":' + token + '}}')
	for depth in [1, 16, 32, 62, 64, 65, 128]:
		_case("depth %d" % depth, root_prefix + '['.repeat(depth) + '0' + ']'.repeat(depth) + '}')
	for source in ['{}','[]','null','true','"root"','{"seed_text":"x","rng_state":1}','{"seed_text":"x","current_environment":{}}',
		'{"__proto__":{"seed_text":"x","rng_state":1,"current_environment":{}}}',
		'{"seed_text":"x","rng_state":1,"current_environment":{},}',
		'{"seed_text":"x","rng_state":1,"current_environment":{"trailing":1,}}',
		'{"seed_text":"x","rng_state":1,"current_environment":{},"current_environment":null}',
		'{"seed\\u005ftext":"x","rng_state":1,"current_environment":{}}',
		root_prefix + '{"text":"a\tb"}}', root_prefix + '{"unterminated":"x}}']:
		_case("grammar %d" % cases.size(), source)
	var fixture_paths := OS.get_environment("BTH_CONTENT_VALIDATION_FIXTURES").split(";", false)
	for path in fixture_paths:
		var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(payload) != TYPE_DICTIONARY: failures.append("fixture not parsed: " + path); continue
		var raw := Codec._validated_storage_source(payload.get("run_state", {}))
		if raw.is_empty(): failures.append("fixture content damaged: " + path); continue
		_case("genuine " + path.get_file(), raw.get_string_from_utf8(), true)
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null: quit(3); return
	file.store_string(JSON.stringify(cases))
	file.close()
	print("SAVE_CONTENT_VALIDATION ", JSON.stringify({"cases":cases.size(),"failures":failures,"oracle":"Godot JSON parse + identical required roots; each packed case also checks content hash rejection"}))
	quit(0 if failures.is_empty() else 1)
