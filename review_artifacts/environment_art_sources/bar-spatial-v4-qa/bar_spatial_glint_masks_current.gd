extends SceneTree
# A distinct QA observer; the archived R4 helper and production painters stay
# unchanged. Only eight explicitly Color-typed Coin Pusher palette fields are
# restored after JSON serialization. No geometry, clock, alpha or art edits.

const CanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const COMPOSITE_SHA256 := "1da980275d04cb5a8af479e88934cc8376abea422612c88aac9e659abe39bc70"
const SUITE_INPUTS_SHA256 := "9b6540045d17aa94f6342f75a54befc85774d5d5a97d39910100510121971149"
const PHASE_SHA256 := "16551dd8f21f26fff8b8a456925c7c9be39c09ae1adb9e8d3ee95d4a3a63b122"
const JOB_SHA256 := "ad550eef23b684f570a9625aed63b8fc6e62d113e18a3901bcbfb10e5546d036"
const CANDIDATE_SHA256 := "a870d3652a72d3ebb5067fe9e46b412f3c2a5b938a40e4c3b2cf72e0be7a2408"
const ARCHIVED_HELPER_SHA256 := "5059b2f9f75dceb0ea220f06e4d9a4541259372ed05b7713a1fb5e4018db91e6"
const COLOR_FIELDS := ["body_color", "side_color", "trim_color", "light_color",
    "glass_color", "deck_color", "platform_color", "backglass_color"]
const CONTEXTS := ["__none", "bar_payday_rush"]

class PaintCanvas:
    extends CanvasScript
    var paint_target: Dictionary = {}
    var paint_clock := 0.0
    var paint_route_clock := 0.0
    var paint_adornments := false
    func _draw() -> void:
        if paint_target.is_empty():
            return
        var old_time := flicker
        var old_route := actor_route_time
        flicker = paint_clock
        actor_route_time = paint_route_clock
        _scale_canvas()
        if paint_adornments:
            _draw_scene_object_adornments(paint_target, false)
        else:
            _draw_scene_object_body(paint_target)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        flicker = old_time
        actor_route_time = old_route

var output := ""
var source_composite := ""
var findings: Array[String] = []
var checks := 0
var restoration_log: Array = []

func _initialize() -> void:
    output = OS.get_environment("BTH_QA_EVIDENCE_DIR").replace("\\", "/").trim_suffix("/")
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--source-composite="):
            source_composite = argument.trim_prefix("--source-composite=").replace("\\", "/")
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        findings.append(message)
        push_error(message)

func _load_dictionary(path: String) -> Dictionary:
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    _check(typeof(value) == TYPE_DICTIONARY, "JSON dictionary input: " + path)
    return value if typeof(value) == TYPE_DICTIONARY else {}

func _guard_production(expected: Dictionary, label: String) -> void:
    _check(not expected.is_empty(), label + " nonempty exact source inventory")
    for relative_path in expected:
        var name := str(relative_path)
        _check(not name.begins_with("/") and not name.contains("..") and not name.contains(":"),
            label + " safe relative source path: " + name)
        if name.begins_with("/") or name.contains("..") or name.contains(":"):
            continue
        _check(FileAccess.get_sha256("res://" + name) == str(expected[relative_path]),
            label + " unchanged production source: " + name)

func _restore_snapshot(original: Dictionary, scenario: String) -> Dictionary:
    var restored := original.duplicate(true)
    var before := JSON.stringify(original)
    var initial_count := restoration_log.size()
    var records: Array = restored.get("interactable_objects", [])
    for index in range(records.size()):
        var record: Dictionary = records[index]
        if str(record.get("source_id", "")) != "coin_pusher":
            continue
        var visual: Dictionary = record.get("visual_state", {})
        if visual.is_empty():
            continue
        for field in COLOR_FIELDS:
            if not visual.has(field):
                continue
            var original_value: Variant = visual[field]
            _check(typeof(original_value) == TYPE_STRING,
                scenario + " serialized Color string at coin_pusher.visual_state." + field)
            if typeof(original_value) != TYPE_STRING:
                continue
            var text := str(original_value).strip_edges()
            _check(text.begins_with("(") and text.ends_with(")"), scenario + " Color tuple delimiters: " + field)
            if not text.begins_with("(") or not text.ends_with(")"):
                continue
            var components := text.substr(1, text.length() - 2).split(",", false)
            _check(components.size() == 4, scenario + " four Color tuple components: " + field)
            if components.size() != 4:
                continue
            var rgba: Array[float] = []
            for component in components:
                var number := str(component).strip_edges()
                _check(number.is_valid_float(), scenario + " numeric Color component: " + field)
                if not number.is_valid_float():
                    break
                var channel := number.to_float()
                _check(is_finite(channel) and channel >= 0.0 and channel <= 1.0,
                    scenario + " unchanged bounded Color channel: " + field)
                if not is_finite(channel) or channel < 0.0 or channel > 1.0:
                    break
                rgba.append(channel)
            if rgba.size() != 4:
                continue
            visual[field] = Color(rgba[0], rgba[1], rgba[2], rgba[3])
            _check(typeof(visual[field]) == TYPE_COLOR, scenario + " typed Color restored: " + field)
            restoration_log.append({"scenario": scenario,
                "path": "source_snapshot.interactable_objects[%d].visual_state.%s" % [index, field],
                "object_id": record.get("object_id", ""), "original_serialized_value": original_value,
                "restored_type": "Color", "restored_rgba": rgba,
                "serialized_restored_value": JSON.parse_string(JSON.stringify(visual[field])),
                "conversion": "Four reported components passed directly to Color; no resampling, recoloring, clamping or alpha adjustment"})
    _check(JSON.parse_string(JSON.stringify(restored)) == original,
        scenario + " serialized snapshot roundtrip is exactly unchanged")
    _check(JSON.stringify(original) == before, scenario + " original input dictionary remains unchanged")
    _check(restoration_log.size() - initial_count == (8 if scenario == "__none" else 0),
        scenario + " exact known palette conversion count")
    return restored

func _run() -> void:
    if not output.begins_with("E:/") or not DirAccess.dir_exists_absolute(output):
        push_error("Existing admitted E: evidence output is required; no fallback")
        quit(1)
        return
    _check(source_composite.begins_with("E:/") and FileAccess.file_exists(source_composite),
        "Explicit current V4 E: composite input")
    _check(FileAccess.get_sha256(source_composite) == COMPOSITE_SHA256, "Exact V4 full-composite JSON identity")
    if not findings.is_empty():
        quit(1)
        return
    var source_directory := source_composite.get_base_dir()
    var inputs_path := source_directory.path_join("suite-inputs.json")
    var phase_path := source_directory.path_join("phase-result.json")
    var job_path := source_directory.path_join("job.json")
    _check(FileAccess.get_sha256(inputs_path) == SUITE_INPUTS_SHA256, "Exact source-suite input identity")
    _check(FileAccess.get_sha256(phase_path) == PHASE_SHA256, "Exact source-suite phase receipt")
    _check(FileAccess.get_sha256(job_path) == JOB_SHA256, "Exact source-suite closed Job receipt")
    _check(FileAccess.get_sha256("res://tools/envart_bar_glint_masks_r4.gd") == ARCHIVED_HELPER_SHA256,
        "Rejected archived observer remains unchanged")
    var inputs := _load_dictionary(inputs_path)
    var phase := _load_dictionary(phase_path)
    var job := _load_dictionary(job_path)
    var doc := _load_dictionary(source_composite)
    _check(phase.get("phase", "") == "composite" and phase.get("status", "") == "PASS" and
        phase.get("result", {}).get("sha256", "") == COMPOSITE_SHA256, "Qualified composite source receipt")
    _check(int(job.get("exit_code", -1)) == 0 and int(job.get("active_at_release", -1)) == 0 and
        bool(job.get("assigned_before_execution", false)) and not bool(job.get("timed_out", true)) and
        job.get("error") == null and job.get("cleanup_errors", []).is_empty() and
        not bool(job.get("log_truncated", true)), "Source Job completed without timeout/errors and drained to zero")
    _check(str(inputs.get("identity", {}).get("candidate_sha256", "")) == CANDIDATE_SHA256 and
        str(phase.get("candidate_sha256", "")) == CANDIDATE_SHA256 and
        FileAccess.get_sha256("res://assets/art/environments/bar/background.png") == CANDIDATE_SHA256,
        "Exact V4 art candidate is active only in the QA source")
    _check(int(doc.get("checks", 0)) == 600 and doc.get("findings", []).is_empty() and
        doc.get("scenarios", []).size() == 8, "Exact passing eight-context full-composite evidence")
    var source_files: Dictionary = inputs.get("identity", {}).get("production_source_sha256", {})
    _guard_production(source_files, "before")
    if not findings.is_empty():
        quit(1)
        return
    var results: Array = []
    var completed: Array[String] = []
    for ctx in doc["scenarios"]:
        var name_value := str(ctx["scenario"])
        if name_value not in CONTEXTS:
            continue
        var selected_entries: Array = ctx["entries"].filter(func(entry): return entry["id"] == "warm_glint_0")
        _check(selected_entries.size() == 1, name_value + " exact original warm_glint_0 clock pair")
        if selected_entries.size() != 1:
            continue
        var entry: Dictionary = selected_entries[0]
        var restored := _restore_snapshot(ctx["source_snapshot"], name_value)
        if not findings.is_empty():
            break
        var viewport := SubViewport.new()
        viewport.size = Vector2i(1800, 860)
        viewport.transparent_bg = true
        viewport.disable_3d = true
        viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
        viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        root.add_child(viewport)
        var canvas := PaintCanvas.new()
        canvas.size = Vector2(1800, 860)
        viewport.add_child(canvas)
        canvas.call("render_environment_snapshot", restored)
        await create_timer(4.0).timeout
        var waited := 4.0
        while not (canvas.get("person_transits") as Dictionary).is_empty() and waited < 12.0:
            await create_timer(0.25).timeout
            waited += 0.25
        canvas.paint_clock = entry["view_a"]["scene_animation_time"]
        canvas.paint_route_clock = entry["view_a"]["qa_draw_route_clock"]
        var actual: Dictionary = JSON.parse_string(JSON.stringify(canvas.call("current_view_snapshot")))
        var geometry_equal: bool = actual["object_layout"] == ctx["actual_view"]["object_layout"]
        _check(geometry_equal and (canvas.get("person_transits") as Dictionary).is_empty(),
            name_value + " exact geometry/natural arrival mismatch")
        var objects: Array = canvas.call("current_view_snapshot")["objects"]
        _check(objects.size() == ctx["actual_view"]["objects"].size(), name_value + " all original objects retained")
        var rows: Array = []
        for object_data in objects:
            canvas.paint_target = object_data
            var names: Array = []
            for adorned in [false, true]:
                canvas.paint_adornments = adorned
                for index in range(4):
                    canvas.queue_redraw()
                    await process_frame
                    await RenderingServer.frame_post_draw
                var filename := name_value + "_" + str(rows.size()) + "_" + ("adorn" if adorned else "body") + ".png"
                _check(viewport.get_texture().get_image().save_png(output.path_join(filename)) == OK,
                    name_value + " actual painter PNG saved: " + filename)
                names.append(filename)
            rows.append({"object": object_data, "body_png": names[0], "adorn_png": names[1]})
        results.append({"scenario": name_value, "geometry_equal": geometry_equal, "natural_wait": waited,
            "object_clock": canvas.paint_clock, "route_clock": canvas.paint_route_clock, "objects": rows,
            "source_snapshot_serialized_sha256": JSON.stringify(ctx["source_snapshot"]).sha256_text(),
            "restored_snapshot_serialized_sha256": JSON.stringify(JSON.parse_string(JSON.stringify(restored))).sha256_text()})
        completed.append(name_value)
        viewport.free()
    _check(completed.size() == 2 and completed.has("__none") and completed.has("bar_payday_rush"),
        "Both unchanged original source-paint contexts completed")
    _check(restoration_log.size() == 8, "Exactly eight whitelisted palette Color values restored")
    _guard_production(source_files, "after")
    _check(FileAccess.get_sha256(source_composite) == COMPOSITE_SHA256, "Original composite input remains unchanged")
    var report := {"schema": "bth.bar_glint_current_source_paint/v1", "checks": checks,
        "findings": findings, "contexts": results, "candidate_sha256": CANDIDATE_SHA256,
        "source_composite": source_composite, "source_composite_sha256": COMPOSITE_SHA256,
        "source_suite_inputs_sha256": SUITE_INPUTS_SHA256, "source_job_sha256": JOB_SHA256,
        "observer_sha256": FileAccess.get_sha256("res://tools/bar_spatial_glint_masks_current.gd"),
        "unchanged_archived_observer_sha256": ARCHIVED_HELPER_SHA256,
        "palette_rehydration": restoration_log,
        "scope": "New QA-only transparent target uses the unchanged production body/adornment painters, original two contexts,1800x860 geometry, source pair clocks and natural arrivals. Only eight serialized Coin Pusher Color fields were restored to Color Variants, with exactly unchanged serialized snapshot values. No objects, positions, labels, art, alpha, processing or original evidence changed. Actual RGB components retain the source JSON reporting precision; alpha records actual paint. Machine diagnostic only; no visual, motion or TEST activation approval."}
    var file := FileAccess.open(output.path_join("bar_glint_current_source_paint.json"), FileAccess.WRITE)
    if file == null:
        push_error("Could not write admitted glint observer report")
        quit(1)
        return
    file.store_string(JSON.stringify(report, "\t"))
    file.close()
    print("BAR_CURRENT_PAINT_MASK_RESULT ", JSON.stringify({"checks": checks, "findings": findings,
        "contexts": results.size(), "restored_colors": restoration_log.size()}))
    quit(0 if findings.is_empty() else 1)
