extends SceneTree
## Native, non-instantiating serialization probe. Launch only through the
## admitted bounded QA runner. Baseline PCK is read-only; outputs are own E proof.

const SCENES := {
    "main": ".godot/exported/133200997/export-3ad5c15c4f3250da0cc7c1af1770d85f-main.scn",
    "coin_pusher_export_parity": ".godot/exported/133200997/export-1909ed950b1fa9020d96f3c52e9856db-coin_pusher_export_parity.scn",
    "coin_pusher_export_parity_runner": ".godot/exported/133200997/export-e5420f39fe5487e4855fc6d514991474-coin_pusher_export_parity_runner.scn",
}

var evidence := ""
var baseline_pck := ""
var findings: Array[String] = []
var rows: Array[Dictionary] = []


func _init() -> void:
    evidence = OS.get_environment("BTH_QA_EVIDENCE_DIR").replace("\\", "/").trim_suffix("/")
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--baseline-pck="):
            baseline_pck = argument.trim_prefix("--baseline-pck=").replace("\\", "/")
    call_deferred("_run")


func _fail(message: String) -> void:
    findings.append(message)
    push_error(message)


func _admitted() -> bool:
    if (not evidence.begins_with("E:/CodexQA/BTH/runs/") or
            evidence.simplify_path() != evidence or not DirAccess.dir_exists_absolute(evidence)):
        _fail("Existing explicit admitted E evidence directory is required")
        return false
    var manifest_path := evidence.path_join("storage-manifest.json")
    var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    if not manifest is Dictionary:
        _fail("Prepared guarded storage manifest is absent")
        return false
    var paths: Dictionary = manifest.get("paths", {})
    var actual := str(paths.get("evidence", "")).replace("\\", "/").trim_suffix("/")
    if (manifest.get("schema", "") != "bth-qa-storage/v1" or not bool(manifest.get("prepared", false)) or
            actual != evidence or not FileAccess.file_exists(evidence.path_join("launch-claim.json"))):
        _fail("Worker evidence differs from its prepared launch manifest")
        return false
    if (not baseline_pck.begins_with("E:/CodexQA/BTH/workspaces/") or
            baseline_pck.simplify_path() != baseline_pck or not FileAccess.file_exists(baseline_pck)):
        _fail("Explicit existing E baseline PCK input is required")
        return false
    var outputs: Array[String] = [evidence.path_join("scene-metadata-probe.json")]
    for label: String in SCENES:
        for suffix: String in [".baseline.scn", ".saved.tscn", ".roundtrip.scn"]:
            outputs.append(evidence.path_join(label + suffix))
    for output: String in outputs:
        if FileAccess.file_exists(output) or DirAccess.dir_exists_absolute(output):
            _fail("Probe output already exists; preserve it and use a fresh run: " + output)
            return false
    return true


func _selected_payloads() -> Dictionary:
    var file := FileAccess.open(baseline_pck, FileAccess.READ)
    if file == null or file.get_length() < 112:
        _fail("Cannot read a complete baseline PCK")
        return {}
    file.big_endian = false
    if file.get_buffer(4).get_string_from_ascii() != "GDPC" or file.get_32() != 3:
        _fail("Probe requires standalone Godot PCK v3")
        return {}
    file.seek(20)
    var flags := file.get_32()
    var file_base := file.get_64()
    var directory_offset := file.get_64()
    if flags & ~2 or directory_offset < 112 or directory_offset + 4 > file.get_length():
        _fail("Encrypted/invalid baseline PCK directory")
        return {}
    file.seek(directory_offset)
    var count := file.get_32()
    if count < 1 or count > 10000:
        _fail("Baseline PCK directory count is outside the bounded probe")
        return {}
    var selected: Dictionary = {}
    for _index in range(count):
        var path_bytes := file.get_32()
        if path_bytes < 1 or path_bytes > 4096 or file.get_position() + path_bytes > file.get_length():
            _fail("Invalid baseline PCK path length")
            return {}
        var path_data := file.get_buffer(path_bytes)
        while not path_data.is_empty() and path_data[path_data.size() - 1] == 0:
            path_data.resize(path_data.size() - 1)
        var path := path_data.get_string_from_utf8().trim_prefix("res://")
        var padding := (4 - path_bytes % 4) % 4
        file.seek(file.get_position() + padding)
        var offset := file.get_64()
        var size := file.get_64()
        var md5 := file.get_buffer(16).hex_encode()
        var entry_flags := file.get_32()
        if SCENES.values().has(path):
            if selected.has(path) or entry_flags != 0 or size < 1 or size > 1024 * 1024:
                _fail("Duplicate/invalid selected baseline scene entry")
                return {}
            selected[path] = {"offset": file_base + offset, "bytes": size, "md5": md5}
    if selected.size() != SCENES.size():
        _fail("Baseline PCK does not contain exactly the three requested scenes")
        return {}
    var result: Dictionary = {}
    for path: String in selected:
        var entry: Dictionary = selected[path]
        var start := int(entry["offset"])
        var size := int(entry["bytes"])
        if start < 112 or start + size > file.get_length():
            _fail("Selected scene lies outside the baseline PCK")
            return {}
        file.seek(start)
        var data := file.get_buffer(size)
        var hasher := HashingContext.new()
        hasher.start(HashingContext.HASH_MD5)
        hasher.update(data)
        if data.size() != size or hasher.finish().hex_encode() != entry["md5"]:
            _fail("Actual baseline scene payload does not match its PCK record")
            return {}
        result[path] = data
    file.close()
    return result


func _normalized(value: Variant) -> Variant:
    match typeof(value):
        TYPE_DICTIONARY:
            var result: Dictionary = {}
            for key: Variant in value:
                result[str(key)] = _normalized(value[key])
            return result
        TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
            var result: Array = []
            for item: Variant in value:
                result.append(_normalized(item))
            return result
        TYPE_OBJECT:
            if value is Resource:
                return {"resource_class": value.get_class(), "resource_path": value.resource_path}
            return {"object_class": value.get_class() if value != null else "null"}
        TYPE_STRING_NAME, TYPE_NODE_PATH:
            return str(value)
        _:
            return value


func _inspect(label: String, data: PackedByteArray) -> void:
    var binary_path := evidence.path_join(label + ".baseline.scn")
    var text_path := evidence.path_join(label + ".saved.tscn")
    var roundtrip_path := evidence.path_join(label + ".roundtrip.scn")
    var output := FileAccess.open(binary_path, FileAccess.WRITE)
    if output == null:
        _fail("Cannot write own E baseline scene copy")
        return
    output.store_buffer(data)
    output.close()
    var scene := ResourceLoader.load(binary_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
    if scene == null:
        _fail("Native loader rejected baseline PackedScene: " + label)
        return
    var original: Dictionary = scene.get("_bundled")
    var normalized_before: Variant = _normalized(original)
    if ResourceSaver.save(scene, text_path) != OK:
        _fail("Native text scene saver failed: " + label)
        return
    var saved_text := FileAccess.get_file_as_string(text_path)
    var headers: Array[String] = []
    for line: String in saved_text.split("\n"):
        if line.begins_with("[gd_scene") or line.begins_with("[node "):
            headers.append(line)
    var reloaded := ResourceLoader.load(text_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
    if reloaded == null:
        _fail("Native loader rejected its own saved text scene: " + label)
        return
    var roundtrip: Dictionary = reloaded.get("_bundled")
    var equal: bool = normalized_before == _normalized(roundtrip)
    if not equal:
        _fail("PackedScene bundle changed during native text roundtrip: " + label)
    if ResourceSaver.save(reloaded, roundtrip_path) != OK:
        _fail("Native binary roundtrip saver failed: " + label)
        return
    rows.append({"label": label, "baseline_pck_entry": SCENES[label],
        "baseline_copy": binary_path, "baseline_copy_sha256": FileAccess.get_sha256(binary_path),
        "native_saved_text": text_path, "native_saved_text_sha256": FileAccess.get_sha256(text_path),
        "native_text_headers": headers, "node_ids_before": original.get("node_ids", []),
        "node_ids_after": roundtrip.get("node_ids", []), "bundle_before": normalized_before,
        "bundle_after": _normalized(roundtrip), "bundle_equal": equal,
        "roundtrip_binary": roundtrip_path, "roundtrip_binary_sha256": FileAccess.get_sha256(roundtrip_path),
        "binary_bytes_equal": data == FileAccess.get_file_as_bytes(roundtrip_path),
        "scene_instantiated": false})


func _run() -> void:
    if not _admitted():
        quit(1)
        return
    var payloads := _selected_payloads()
    if not payloads.is_empty():
        for label: String in SCENES:
            _inspect(label, payloads[SCENES[label]])
    var report := {"schema": "bth.scene_metadata_native_probe/v1", "status": "PASS" if findings.is_empty() and rows.size() == 3 else "FAIL",
        "baseline_pck": baseline_pck, "baseline_pck_sha256": FileAccess.get_sha256(baseline_pck),
        "probe_source_sha256": FileAccess.get_sha256(get_script().resource_path),
        "scenes": rows, "findings": findings, "source_or_production_files_written": false,
        "scope": "Native serialization only; no scene instantiated, no gameplay or rendering acceptance."}
    var output := FileAccess.open(evidence.path_join("scene-metadata-probe.json"), FileAccess.WRITE)
    if output == null:
        _fail("Cannot write own E probe report")
        quit(1)
        return
    output.store_string(JSON.stringify(report, "\t") + "\n")
    output.close()
    print("BAR_SCENE_METADATA_PROBE ", JSON.stringify({"status": report["status"], "scenes": rows.size(), "findings": findings}))
    quit(0 if report["status"] == "PASS" else 1)
