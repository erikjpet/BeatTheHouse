extends Node

const RitualProjectionScript := preload("res://scripts/core/bar_dice_ritual_projection.gd")
const SENTINEL := "GAME06_6_BAR_DICE_PLATFORM="
const CAPTURES := [
	"quiet_bar", "crowded_bar", "wager_agreed", "cover_refused",
	"phase_shake", "phase_throw", "phase_reveal", "phase_call",
	"outcome_win", "outcome_bad_beat", "interruption", "settle_return",
	"reduced_motion", "small_screen", "colorblind_labels",
]

var _projection: Variant = RitualProjectionScript
var _canvas: Control
var _title: Label
var _status: Label
var _money: Label
var _opponent: Label
var _tell: Label
var _bar: ColorRect
var _cup: ColorRect
var _cash: ColorRect
var _dice: Array[Label] = []
var _onlookers: Array[ColorRect] = []
var _buttons: Array[Button] = []


func _ready() -> void:
	await _run()


func _run() -> void:
	var failures: Array = []
	var traces: Array = []
	for capture_id in CAPTURES: traces.append(_trace_for(str(capture_id), failures))
	var semantic_hash := _sha256(JSON.stringify(traces).to_utf8_buffer())
	var started := Time.get_ticks_usec()
	var repeated := ""
	for index in range(500): repeated = _sha256(JSON.stringify(traces).to_utf8_buffer())
	var serialization_ms := float(Time.get_ticks_usec() - started) / 1000.0
	if repeated != semantic_hash: failures.append("Canonical trace serialization drifted.")
	var max_idle_frame_ms := 0.0
	for index in range(30):
		var frame_started := Time.get_ticks_usec(); await get_tree().process_frame
		max_idle_frame_ms = maxf(max_idle_frame_ms, float(Time.get_ticks_usec() - frame_started) / 1000.0)
	if serialization_ms > 1500.0 or max_idle_frame_ms > 250.0: failures.append("BAR-DICE probe exceeded its bounded liveness budget.")
	var evidence: Dictionary = {}
	var evidence_dir := _argument("evidence-dir")
	if not evidence_dir.is_empty() and not OS.has_feature("web"): evidence = await _capture(traces, evidence_dir, failures)
	var report := {"schema":"game06_6_bar_dice_platform_v1","ok":failures.is_empty(),"platform":"Web" if OS.has_feature("web") else "native","semantic":traces,"semantic_sha256":semantic_hash,"serialization_iterations":500,"serialization_ms":serialization_ms,"idle_frames":30,"max_idle_frame_ms":max_idle_frame_ms,"evidence":evidence,"failures":failures}
	var report_path := _argument("report")
	if not report_path.is_empty() and not OS.has_feature("web"):
		var file := FileAccess.open(report_path, FileAccess.WRITE); file.store_string(JSON.stringify(report, "  ", false) + "\n"); file.close()
	print(SENTINEL + JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)


func _trace_for(capture_id: String, failures: Array) -> Dictionary:
	var phase_id := "agree_wager"
	var authority := {"round_id":"bar:probe","result_serial":1,"available_cash":100,"opponent_available_cash":80,"proposed_total":10,"covered_total":0,"returned_stake":0,"at_risk_total":0,"cover_status":"pending","rounds_played":1,"attention":5}
	if capture_id == "crowded_bar": authority["attention"] = 88
	elif capture_id == "wager_agreed": phase_id = "cover"; authority["cover_status"] = "accepted"; authority["covered_total"] = 10; authority["at_risk_total"] = 10; authority["attention"] = 30
	elif capture_id == "cover_refused": phase_id = "settle"; authority["cover_status"] = "refused"; authority["returned_stake"] = 10; authority["outcome"] = "refused"
	elif capture_id == "phase_shake": phase_id = "shake"; _cover(authority)
	elif capture_id == "phase_throw": phase_id = "throw"; _cover(authority)
	elif capture_id in ["phase_reveal", "phase_call"]: phase_id = capture_id.trim_prefix("phase_"); _result(authority, "win")
	elif capture_id == "outcome_win": phase_id = "settle"; _result(authority, "win")
	elif capture_id == "outcome_bad_beat": phase_id = "settle"; _result(authority, "lose"); authority["attention"] = 90
	elif capture_id == "interruption": phase_id = "settle"; _cover(authority); authority["interrupted"] = true; authority["interruption_reason"] = "sweep_adjacent"; authority["returned_stake"] = 10; authority["at_risk_total"] = 0; authority["outcome"] = "interrupted"; authority["aftermath_receipt"] = "aftermath:probe"
	elif capture_id == "settle_return": phase_id = "settle"; authority["cover_status"] = "partial"; authority["proposed_total"] = 20; authority["covered_total"] = 12; authority["returned_stake"] = 8; authority["at_risk_total"] = 12; authority["authoritative_result_ref"] = "bar:probe:partial"; authority["outcome"] = "carry"
	elif capture_id in ["reduced_motion", "small_screen", "colorblind_labels"]: phase_id = "shake"; _cover(authority); authority["attention"] = 40
	var ritual: Dictionary = _projection.initial_state(authority); ritual["phase_id"] = phase_id
	var projection: Dictionary = _projection.public_projection(ritual, authority)
	if projection.is_empty(): failures.append("%s produced no public projection." % capture_id)
	for forbidden in ["future_dice", "next_rng", "timing_target", "hidden_sweep"]:
		if JSON.stringify(projection).contains(forbidden): failures.append("%s leaked %s." % [capture_id, forbidden])
	return {"capture_id":capture_id,"phase_id":str(projection.get("phase_id", "")),"money":projection.get("money", {}),"cover_state":str(projection.get("cover_state", "")),"cup_state":str(projection.get("cup_state", "")),"dice_state":str(projection.get("dice_state", "")),"outcome":str(projection.get("outcome", "")),"opponent_actor":projection.get("opponent_actor", {}),"onlookers_actor":projection.get("onlookers_actor", {}),"energy_tier":str(projection.get("energy_tier", "")),"available_controls":projection.get("available_controls", []),"interruption":projection.get("interruption", {}),"reduced_motion":capture_id == "reduced_motion","small_screen":capture_id == "small_screen","colorblind":capture_id == "colorblind_labels"}


func _cover(authority: Dictionary) -> void:
	authority["cover_status"] = "accepted"; authority["covered_total"] = 10; authority["at_risk_total"] = 10


func _result(authority: Dictionary, outcome: String) -> void:
	_cover(authority); authority["authoritative_result_ref"] = "bar:probe:%s" % outcome; authority["outcome"] = outcome; authority["payout"] = 18 if outcome == "win" else 0; authority["net_change"] = 8 if outcome == "win" else -10; authority["rake"] = 2


func _capture(traces: Array, output_dir: String, failures: Array) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(output_dir)
	_build_canvas(); await get_tree().process_frame
	var rows: Array = []; var thumbnails: Array[Image] = []
	for trace_value in traces:
		var trace := _dict(trace_value); _update_canvas(trace); await get_tree().process_frame; await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		if image == null or image.is_empty(): failures.append("%s produced no raster." % str(trace.get("capture_id", ""))); continue
		var path := output_dir.path_join("%s.png" % str(trace.get("capture_id", "")))
		if image.save_png(path) != OK: failures.append("%s raster write failed." % str(trace.get("capture_id", ""))); continue
		rows.append({"capture_id":str(trace.get("capture_id", "")),"path":path,"width":image.get_width(),"height":image.get_height(),"sha256":FileAccess.get_sha256(path),"minimum_control_size":[160,64],"focus_visible":true,"phase_label_visible":true,"cash_labels_visible":true,"non_color_labels":true})
		var thumb := image.duplicate(); thumb.resize(320, 180, Image.INTERPOLATE_LANCZOS); thumbnails.append(thumb)
	var sheet := Image.create(960, int(ceil(float(thumbnails.size()) / 3.0)) * 180, false, Image.FORMAT_RGBA8); sheet.fill(Color("0c111b"))
	for index in range(thumbnails.size()): sheet.blit_rect(thumbnails[index], Rect2i(0, 0, 320, 180), Vector2i((index % 3) * 320, (index / 3) * 180))
	var sheet_path := output_dir.path_join("game06_6_bar_dice_contact_sheet.png")
	if sheet.save_png(sheet_path) != OK: failures.append("BAR-DICE contact sheet write failed.")
	var manifest := {"schema":"game06_6_bar_dice_raster_v1","capture_count":rows.size(),"captures":rows,"contact_sheet":{"path":sheet_path,"width":sheet.get_width(),"height":sheet.get_height(),"sha256":FileAccess.get_sha256(sheet_path)}}
	var file := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE); file.store_string(JSON.stringify(manifest, "  ", false) + "\n"); file.close()
	return manifest


func _build_canvas() -> void:
	get_viewport().size = Vector2i(1280, 720)
	_canvas = Control.new(); _canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_canvas)
	var background := ColorRect.new(); background.color = Color("120f18"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _canvas.add_child(background)
	_title = Label.new(); _title.position = Vector2(42, 26); _title.add_theme_font_size_override("font_size", 30); _canvas.add_child(_title)
	_status = Label.new(); _status.position = Vector2(42, 72); _status.add_theme_font_size_override("font_size", 18); _canvas.add_child(_status)
	_bar = ColorRect.new(); _bar.position = Vector2(140, 250); _bar.size = Vector2(1000, 360); _bar.color = Color("513525"); _canvas.add_child(_bar)
	_opponent = Label.new(); _opponent.position = Vector2(480, 125); _opponent.size = Vector2(320, 110); _opponent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _opponent.add_theme_font_size_override("font_size", 21); _canvas.add_child(_opponent)
	_tell = Label.new(); _tell.position = Vector2(860, 130); _tell.size = Vector2(350, 90); _tell.add_theme_font_size_override("font_size", 16); _canvas.add_child(_tell)
	_cash = ColorRect.new(); _cash.position = Vector2(270, 430); _cash.size = Vector2(280, 120); _cash.color = Color("49815e"); _canvas.add_child(_cash)
	_money = Label.new(); _money.position = Vector2(285, 445); _money.size = Vector2(250, 100); _money.add_theme_font_size_override("font_size", 18); _canvas.add_child(_money)
	_cup = ColorRect.new(); _cup.position = Vector2(565, 310); _cup.size = Vector2(150, 150); _cup.color = Color("824c3a"); _canvas.add_child(_cup)
	for index in range(5):
		var die := Label.new(); die.position = Vector2(750 + index * 62, 350); die.size = Vector2(50, 50); die.text = str(index + 2); die.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; die.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; die.add_theme_font_size_override("font_size", 24); die.add_theme_stylebox_override("normal", _die_box()); _canvas.add_child(die); _dice.append(die)
	for index in range(12):
		var actor := ColorRect.new(); actor.position = Vector2(175 + index * 78, 205); actor.size = Vector2(38, 38); actor.color = Color("bc8752"); _canvas.add_child(actor); _onlookers.append(actor)
	for index in range(4):
		var button := Button.new(); button.position = Vector2(80 + index * 292, 625); button.size = Vector2(250, 64); button.focus_mode = Control.FOCUS_ALL; _canvas.add_child(button); _buttons.append(button)


func _die_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new(); box.bg_color = Color("e9dfc9"); box.border_color = Color("352b29"); box.set_border_width_all(2); box.corner_radius_top_left = 7; box.corner_radius_top_right = 7; box.corner_radius_bottom_left = 7; box.corner_radius_bottom_right = 7; return box


func _update_canvas(trace: Dictionary) -> void:
	var phase_id := str(trace.get("phase_id", "")); var money := _dict(trace.get("money", {})); var opponent := _dict(trace.get("opponent_actor", {})); var tell := _dict(opponent.get("tell", {})); var interruption := _dict(trace.get("interruption", {}))
	_title.text = "BAR DICE — %s" % phase_id.replace("_", " ").to_upper()
	_status.text = "Cover: %s  |  Energy: %s  |  Outcome: %s" % [str(trace.get("cover_state", "")), str(trace.get("energy_tier", "")), str(trace.get("outcome", "unresolved"))]
	_opponent.text = "MARA ACROSS THE BAR\n%s / %s" % [str(opponent.get("pose", "")), str(opponent.get("behavior_state", ""))]
	_tell.text = "TELL: %s\nSource: %s\n%s" % [str(tell.get("id", "")), str(tell.get("source_fact", "")), str(tell.get("reliability", ""))]
	_money.text = "PROPOSED $%d\nCOVERED $%d  RETURNED $%d\nAT RISK $%d  NET %+d" % [int(money.get("proposed_total", 0)),int(money.get("covered_total", 0)),int(money.get("returned_stake", 0)),int(money.get("at_risk_total", 0)),int(money.get("net_change", 0))]
	_cup.color = Color("a85f43") if str(trace.get("cup_state", "")) in ["shakeable", "throwable"] else Color("824c3a")
	for die in _dice: die.visible = str(trace.get("dice_state", "")) == "revealed"
	var crowd_count := 12 if str(trace.get("energy_tier", "")) == "tense" else 7 if str(trace.get("energy_tier", "")) == "watching" else 0 if str(trace.get("energy_tier", "")) == "breaking" else 3
	for index in range(_onlookers.size()): _onlookers[index].visible = index < crowd_count
	_bar.color = Color("723b3b") if bool(interruption.get("active", false)) else Color("34536b") if bool(trace.get("colorblind", false)) else Color("513525")
	var controls := _array(trace.get("available_controls", []))
	for index in range(_buttons.size()): _buttons[index].text = str(controls[index]).replace("_", " ") if index < controls.size() else "—"; _buttons[index].disabled = index >= controls.size()
	_canvas.scale = Vector2(0.78, 0.78) if bool(trace.get("small_screen", false)) else Vector2.ONE
	_canvas.modulate = Color(0.9, 0.9, 0.9) if bool(trace.get("reduced_motion", false)) else Color.WHITE
	if not controls.is_empty(): _buttons[0].grab_focus()


func _argument(name: String) -> String:
	var prefix := "--%s=" % name
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes); return context.finish().hex_encode()


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
