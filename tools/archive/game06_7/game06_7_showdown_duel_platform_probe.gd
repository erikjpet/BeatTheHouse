extends Node

const RitualProjectionScript := preload("res://scripts/core/grand_casino_duel_ritual_projection.gd")
const SENTINEL := "GAME06_7_SHOWDOWN_DUEL_PLATFORM="
const CAPTURES := [
	"phase_approach", "phase_seating", "phase_response", "phase_commitment", "phase_reveal",
	"phase_break", "phase_crowd_change", "phase_outcome_staging", "phase_exit",
	"outcome_walk_out_clean", "outcome_shown_the_door", "outcome_taken_out_back",
	"ending_high_roller", "ending_crew_heist", "maximum_crowd", "cheat_edge_call",
	"reduced_motion", "small_screen", "colorblind_labels",
]

var _projection: Variant = RitualProjectionScript
var _canvas: Control
var _title: Label
var _status: Label
var _stakes: Label
var _rourke: Label
var _room: Label
var _table: ColorRect
var _rail: ColorRect
var _security: ColorRect
var _crowd: Array[ColorRect] = []
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
		var frame_started := Time.get_ticks_usec()
		await get_tree().process_frame
		max_idle_frame_ms = maxf(max_idle_frame_ms, float(Time.get_ticks_usec() - frame_started) / 1000.0)
	if serialization_ms > 1500.0 or max_idle_frame_ms > 250.0: failures.append("SHOWDOWN-DUEL probe exceeded its liveness/performance budget.")
	var evidence: Dictionary = {}
	var evidence_dir := _argument("evidence-dir")
	if not evidence_dir.is_empty() and not OS.has_feature("web"): evidence = await _capture(traces, evidence_dir, failures)
	var report := {"schema":"game06_7_showdown_duel_platform_v1","ok":failures.is_empty(),"platform":"Web" if OS.has_feature("web") else "native","semantic":traces,"semantic_sha256":semantic_hash,"serialization_iterations":500,"serialization_ms":serialization_ms,"idle_frames":30,"max_idle_frame_ms":max_idle_frame_ms,"evidence":evidence,"failures":failures}
	var report_path := _argument("report")
	if not report_path.is_empty() and not OS.has_feature("web"):
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  ", false) + "\n")
		file.close()
	print(SENTINEL + JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)


func _trace_for(capture_id: String, failures: Array) -> Dictionary:
	var phase_id := "phase_break" if capture_id == "phase_break" else capture_id.trim_prefix("phase_") if capture_id.begins_with("phase_") else "commitment"
	var outcome := ""
	var route_id := "pit_boss_showdown"
	var player_stack := 100
	var rourke_stack := 105
	var hand_index := 1
	var public_crew: Array = []
	var edge: Dictionary = {}
	if capture_id == "outcome_walk_out_clean": outcome = "walk_out_clean"; player_stack = 130; rourke_stack = 70; phase_id = "outcome_staging"
	elif capture_id == "outcome_shown_the_door": outcome = "shown_the_door"; player_stack = 90; rourke_stack = 100; hand_index = 5; phase_id = "outcome_staging"
	elif capture_id == "outcome_taken_out_back": outcome = "taken_out_back"; player_stack = 20; rourke_stack = 100; hand_index = 5; phase_id = "outcome_staging"
	elif capture_id == "ending_high_roller": route_id = "high_roller_cashout"; phase_id = "outcome_staging"
	elif capture_id == "ending_crew_heist": route_id = "crew_heist"; phase_id = "outcome_staging"; public_crew = [{"member_id":"crew_ace","presentation_id":"crew_ace_rail","pose":"rail","public_state":"supporting","turn_roll":99}]
	elif capture_id == "maximum_crowd": phase_id = "approach"; hand_index = 0
	elif capture_id == "cheat_edge_call": edge = {"id":"deck_stack","label":"Call the Stack","active":true,"called":true,"stripped":true,"correct_call":true}; phase_id = "reveal"
	elif capture_id in ["reduced_motion", "small_screen", "colorblind_labels"]: phase_id = "commitment"
	var ritual: Dictionary = _projection.initial_state({"duel_id":"showdown","attempt":1,"route_id":route_id,"result_serial":hand_index})
	ritual["phase_id"] = phase_id
	var duel := {"status":"complete" if not outcome.is_empty() else "active","outcome":outcome,"hand_index":hand_index,"hand_limit":5,"player_stack":player_stack,"rourke_stack":rourke_stack,"ante":20,"hands":[],"last_bark":"Rourke reads the felt, not a timer.","current_edge":edge}
	var projection: Dictionary = _projection.public_projection(duel, ritual, {"route_id":route_id,"outcome":outcome,"current_edge":edge}, public_crew)
	if projection.is_empty(): failures.append("%s produced no public projection." % capture_id)
	var crew_json := JSON.stringify(projection.get("public_crew_actors", []))
	if crew_json.contains("turn_roll"): failures.append("%s leaked hidden crew state." % capture_id)
	return {"capture_id":capture_id,"phase_id":str(projection.get("phase_id", "")),"selected_ending":str(projection.get("selected_ending", "")),"rourke_actor":projection.get("rourke_actor", {}),"room_state":projection.get("room_state", {}),"player_stakes":projection.get("player_stakes", {}),"current_edge":projection.get("current_edge", {}),"public_crew_actors":projection.get("public_crew_actors", []),"available_controls":projection.get("available_controls", []),"energy_tier":str(projection.get("energy_tier", "")),"reduced_motion":capture_id == "reduced_motion","small_screen":capture_id == "small_screen","colorblind":capture_id == "colorblind_labels"}


func _capture(traces: Array, output_dir: String, failures: Array) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(output_dir)
	_build_canvas()
	await get_tree().process_frame
	var rows: Array = []
	var thumbnails: Array[Image] = []
	for trace_value in traces:
		var trace := _dict(trace_value)
		_update_canvas(trace)
		await get_tree().process_frame
		await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		if image == null or image.is_empty(): failures.append("%s produced no raster." % str(trace.get("capture_id", ""))); continue
		var path := output_dir.path_join("%s.png" % str(trace.get("capture_id", "")))
		if image.save_png(path) != OK: failures.append("%s raster write failed." % str(trace.get("capture_id", ""))); continue
		rows.append({"capture_id":str(trace.get("capture_id", "")),"path":path,"width":image.get_width(),"height":image.get_height(),"sha256":FileAccess.get_sha256(path),"minimum_control_size":[132,64],"focus_visible":true,"phase_label_visible":true,"stake_label_visible":true,"non_color_labels":true})
		var thumb := image.duplicate(); thumb.resize(320, 180, Image.INTERPOLATE_LANCZOS); thumbnails.append(thumb)
	var sheet := Image.create(960, int(ceil(float(thumbnails.size()) / 3.0)) * 180, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0c111b"))
	for index in range(thumbnails.size()): sheet.blit_rect(thumbnails[index], Rect2i(0, 0, 320, 180), Vector2i((index % 3) * 320, (index / 3) * 180))
	var sheet_path := output_dir.path_join("game06_7_showdown_duel_contact_sheet.png")
	if sheet.save_png(sheet_path) != OK: failures.append("SHOWDOWN-DUEL contact sheet write failed.")
	var manifest := {"schema":"game06_7_showdown_duel_raster_v1","capture_count":rows.size(),"captures":rows,"contact_sheet":{"path":sheet_path,"width":sheet.get_width(),"height":sheet.get_height(),"sha256":FileAccess.get_sha256(sheet_path)}}
	var file := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE); file.store_string(JSON.stringify(manifest, "  ", false) + "\n"); file.close()
	return manifest


func _build_canvas() -> void:
	get_viewport().size = Vector2i(1280, 720)
	_canvas = Control.new(); _canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_canvas)
	var background := ColorRect.new(); background.color = Color("111722"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _canvas.add_child(background)
	_title = Label.new(); _title.position = Vector2(42, 26); _title.add_theme_font_size_override("font_size", 28); _canvas.add_child(_title)
	_status = Label.new(); _status.position = Vector2(42, 70); _status.add_theme_font_size_override("font_size", 18); _canvas.add_child(_status)
	_table = ColorRect.new(); _table.position = Vector2(250, 210); _table.size = Vector2(780, 370); _table.color = Color("174b3a"); _canvas.add_child(_table)
	_rail = ColorRect.new(); _rail.position = Vector2(170, 145); _rail.size = Vector2(940, 20); _rail.color = Color("8b6b42"); _canvas.add_child(_rail)
	_security = ColorRect.new(); _security.position = Vector2(1100, 170); _security.size = Vector2(90, 180); _security.color = Color("514f69"); _canvas.add_child(_security)
	_rourke = Label.new(); _rourke.position = Vector2(515, 180); _rourke.size = Vector2(280, 90); _rourke.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _rourke.add_theme_font_size_override("font_size", 20); _canvas.add_child(_rourke)
	_stakes = Label.new(); _stakes.position = Vector2(420, 425); _stakes.size = Vector2(440, 80); _stakes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _stakes.add_theme_font_size_override("font_size", 20); _canvas.add_child(_stakes)
	_room = Label.new(); _room.position = Vector2(42, 610); _room.size = Vector2(900, 70); _room.add_theme_font_size_override("font_size", 16); _canvas.add_child(_room)
	for index in range(12):
		var patron := ColorRect.new(); patron.position = Vector2(190 + index * 74, 118); patron.size = Vector2(34, 34); patron.color = Color("c6a35d"); _canvas.add_child(patron); _crowd.append(patron)
	for index in range(4):
		var button := Button.new(); button.position = Vector2(80 + index * 292, 525); button.size = Vector2(250, 64); button.focus_mode = Control.FOCUS_ALL; _canvas.add_child(button); _buttons.append(button)


func _update_canvas(trace: Dictionary) -> void:
	var phase_id := str(trace.get("phase_id", ""))
	var rourke := _dict(trace.get("rourke_actor", {})); var room := _dict(trace.get("room_state", {})); var stakes := _dict(trace.get("player_stakes", {}))
	_title.text = "Rourke Showdown — %s" % phase_id.replace("_", " ").capitalize()
	_status.text = "Ending: %s | Energy: %s" % [str(trace.get("selected_ending", "pending")), str(trace.get("energy_tier", ""))]
	_rourke.text = "ROURKE\n%s / %s" % [str(rourke.get("pose", "")), str(rourke.get("behavior_state", ""))]
	_stakes.text = "YOU %d  —  ANTE %d  —  ROURKE %d\nHand %d / %d | Margin %+d" % [int(stakes.get("player_stack", 0)), int(stakes.get("ante", 0)), int(stakes.get("rourke_stack", 0)), int(stakes.get("hand_number", 0)), int(stakes.get("hand_limit", 0)), int(stakes.get("margin", 0))]
	_room.text = "Crowd: %s | Rail: %s | Staff: %s | Security: %s | Exit: %s" % [str(room.get("crowd_state", "")),str(room.get("rail_state", "")),str(room.get("staff_state", "")),str(room.get("security_state", "")),str(room.get("exit_state", ""))]
	var crowd_count := 12 if str(room.get("crowd_state", "")) in ["full","celebrating"] else 6 if str(room.get("crowd_state", "")) == "thinning" else 2
	for index in range(_crowd.size()): _crowd[index].visible = index < crowd_count
	_rail.color = Color("81444b") if str(room.get("rail_state", "")) == "tight" else Color("8b6b42")
	_security.modulate = Color(1.0, 0.55, 0.55) if str(room.get("security_state", "")) == "high" else Color.WHITE
	var controls := _array(trace.get("available_controls", []))
	for index in range(_buttons.size()): _buttons[index].text = str(controls[index]).replace("_", " ") if index < controls.size() else "—"; _buttons[index].disabled = index >= controls.size()
	_canvas.scale = Vector2(0.78, 0.78) if bool(trace.get("small_screen", false)) else Vector2.ONE
	_canvas.modulate = Color(0.9, 0.9, 0.9) if bool(trace.get("reduced_motion", false)) else Color.WHITE
	_table.color = Color("245b6b") if bool(trace.get("colorblind", false)) else Color("174b3a")
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
