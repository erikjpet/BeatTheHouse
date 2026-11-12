extends Control

# Presentation only. Receipts are snapshots; this node never receives RunState
# and has no authority to debit cash, advance a clock, move or resolve a route.
signal completed(journey_id: String)

const PRESENTATION_KEY := "back_alley_bar_typical_v1"
const ArrivalTimeline := preload("res://scripts/ui/travel_arrival_timeline.gd")
const DURATION_SECONDS := ArrivalTimeline.DURATION_SECONDS
const AvatarView := preload("res://scripts/ui/character_avatar_view.gd")
const VehicleView := preload("res://scripts/ui/travel_vehicle_view.gd")
const Catalog := preload("res://scripts/ui/travel_presentation_catalog.gd")
const EntranceView := preload("res://scripts/ui/travel_entrance_view.gd")
const CutoutShader := preload("res://scripts/ui/travel_scene_cutout.gdshader")
const SOURCE_WIDTH_UV := 0.80
const INK := Color("#060912")
const CYAN := Color("#58e9df")
const PAPER := Color("#f6edcc")

var force_missing_art_for_test := false
var focus_scope: RefCounted
var active := false
var phase := "idle"
var elapsed := 0.0
var _receipt: Dictionary = {}
var _scene: Dictionary = {}
var _mode := "bus"
var _completion_latched := false
var _presentation_generation := 0
var _street: Texture2D
var _backdrop: Texture2D
var _doorway: Texture2D
var _vehicle: Texture2D
var _vehicle_interior: Texture2D
var _vehicle_source := Rect2()
var _vehicle_door_uv := Rect2()
var _vehicle_wheels: Array = []
var _vehicle_view: Control
var _avatar_view: Control
var _avatar_clip: Control
var _entrance_back: Control
var _entrance_front: Control
var _main_scene_view: TextureRect
var _main_scene_atlas: AtlasTexture
var _cutout_material: ShaderMaterial
var _vehicle_material: ShaderMaterial
var _stage_tint: ColorRect
var _title: Label
var _details: Label
var _caption: Label
var _summary: Label
var _summary_scroll: ScrollContainer
var _skip: Button
var _continue: Button
var _stage := Rect2()
var _static := false
var _high_contrast := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	set_process(false)
	_cutout_material = ShaderMaterial.new()
	_cutout_material.shader = CutoutShader
	_cutout_material.set_shader_parameter("solid_alpha_threshold", 0.80)
	_vehicle_material = ShaderMaterial.new()
	_vehicle_material.shader = CutoutShader
	_main_scene_atlas = AtlasTexture.new()
	_main_scene_atlas.filter_clip = true
	_main_scene_view = TextureRect.new()
	_main_scene_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_main_scene_view.stretch_mode = TextureRect.STRETCH_SCALE
	_main_scene_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_scene_view.material = _cutout_material
	_main_scene_view.visible = false
	add_child(_main_scene_view)
	_vehicle_view = VehicleView.new()
	_vehicle_view.material = _vehicle_material
	add_child(_vehicle_view)
	_entrance_back = EntranceView.new()
	_entrance_back.material = _cutout_material
	add_child(_entrance_back)
	_avatar_clip = Control.new()
	_avatar_clip.clip_contents = true
	_avatar_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_avatar_clip)
	_avatar_view = AvatarView.new()
	_avatar_view.custom_minimum_size = Vector2.ZERO
	_avatar_view.visible = false
	_avatar_clip.add_child(_avatar_view)
	_entrance_front = EntranceView.new()
	_entrance_front.material = _cutout_material
	add_child(_entrance_front)
	_stage_tint = ColorRect.new()
	_stage_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_tint.visible = false
	add_child(_stage_tint)
	_title = _label(28, PAPER)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_details = _label(17, CYAN)
	_caption = _label(23, PAPER)
	_summary = _label(18, PAPER)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	remove_child(_summary)
	_summary_scroll = ScrollContainer.new()
	_summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_summary_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_summary_scroll)
	_summary_scroll.add_child(_summary)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skip = Button.new()
	_skip.text = "Skip scene"
	_skip.add_theme_font_size_override("font_size", 18)
	_skip.pressed.connect(skip_to_receipt)
	add_child(_skip)
	_continue = Button.new()
	_continue.text = "Continue"
	_continue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_continue.add_theme_font_size_override("font_size", 18)
	_continue.pressed.connect(acknowledge)
	add_child(_continue)
	# Keep retained text/buttons in an explicit UI layer above the redrawable
	# street canvas, including the static receipt's final redraw.
	for child in get_children():
		if child is CanvasItem:
			child.z_index = 1
	for child in [_main_scene_view, _vehicle_view, _entrance_back, _avatar_clip, _entrance_front, _avatar_view, _stage_tint]:
		child.z_index = 0
	resized.connect(_layout)
	_layout()


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func present(receipt: Dictionary, reduced_motion: bool = false, high_contrast: bool = false, text_scale: float = 1.0, receipt_only: bool = false, appearance_snapshot: Dictionary = {}) -> void:
	cancel()
	_receipt = receipt.duplicate(true)
	_scene = Catalog.profile(_receipt)
	_mode = str(_scene["mode"])
	active = true
	_completion_latched = false
	elapsed = 0.0
	_high_contrast = high_contrast
	_static = reduced_motion or receipt_only or not bool(_scene["supported"])
	_street = _load_art(str(_scene["street_path"]))
	_backdrop = _load_art(str(_scene["background_path"]))
	_doorway = _load_art(str(_scene.get("doorway_path", "")))
	var vehicle_contract: Dictionary = _scene["vehicle"]
	_vehicle = _load_art(str(vehicle_contract.get("texture", ""))) if not vehicle_contract.is_empty() else null
	_vehicle_interior = _load_art(str(vehicle_contract.get("interior_texture", ""))) if _mode != "walk" else null
	if _vehicle_interior != null:
		var interior_reference: Array = vehicle_contract.get("interior_reference_size", [])
		if interior_reference.size() != 2 or Vector2(float(interior_reference[0]), float(interior_reference[1])) != Vector2(_vehicle_interior.get_width(), _vehicle_interior.get_height()):
			_vehicle_interior = null
	_prepare_sprite_geometry()
	_avatar_view.set_appearance(appearance_snapshot)
	_vehicle_view.configure(_vehicle, _vehicle_source, _vehicle_door_uv, _vehicle_wheels, vehicle_contract.get("door_animation", {}), _vehicle_interior)
	_entrance_back.configure(_street, _scene.get("exterior", {}), false, _doorway)
	_entrance_front.configure(_street, _scene.get("exterior", {}), true, _doorway)
	_static = _static or not _has_scene_art()
	_main_scene_atlas.atlas = _street
	_main_scene_view.texture = _main_scene_atlas if _street != null else null
	_title.text = str(_scene["title"])
	_details.text = "%s  |  %d game min  |  %s" % [str(receipt.get("travel_method_label", "Travel")), int(receipt.get("base_minutes", 0)), _fare_text(int(receipt.get("quoted_departure_fare", 0)))]
	if not receipt.has("base_minutes"):
		_title.text = "JOURNEY RECEIPT"
		_details.text = "Saved journey summary"
	elif not bool(receipt.get("arrival_context_current", true)):
		_title.text = "PREVIOUS JOURNEY"
		_details.text = "Earlier committed journey  |  " + _details.text
	_continue.text = str(_scene["continue_text"]) if receipt.has("base_minutes") and bool(receipt.get("arrival_context_current", true)) else "Continue"
	_summary.text = str(receipt.get("receipt_text", "Journey complete."))
	var scale_value := clampf(text_scale, 1.0, 1.5)
	_title.add_theme_font_size_override("font_size", int(28 * scale_value))
	_details.add_theme_font_size_override("font_size", int(17 * scale_value))
	_caption.add_theme_font_size_override("font_size", int(23 * scale_value))
	_summary.add_theme_font_size_override("font_size", int(18 * scale_value))
	phase = str(_choreography()["phase"])
	_caption.text = ""
	_caption.visible = false
	_summary.visible = false
	_summary_scroll.visible = false
	_continue.visible = false
	_skip.visible = true
	visible = true
	move_to_front()
	_layout()
	if _static:
		skip_to_receipt()
	else:
		set_process(true)
		_focus_action(_skip)
	_update_scene_views()
	queue_redraw()

func _load_art(path: String) -> Texture2D:
	if force_missing_art_for_test or path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D


func _fare_text(fare: int) -> String:
	return "No fare" if fare <= 0 else "$%d fare" % fare


func _process(delta: float) -> void:
	advance_presentation(delta)


func advance_presentation(delta: float) -> void:
	if not active or phase == "receipt":
		return
	elapsed = minf(DURATION_SECONDS, elapsed + maxf(0.0, delta))
	if elapsed >= DURATION_SECONDS:
		skip_to_receipt()
		return
	var choreography := _choreography()
	phase = str(choreography["phase"])
	_caption.text = ""
	_update_scene_views()
	queue_redraw()

func _prepare_sprite_geometry() -> void:
	_vehicle_source = Rect2()
	_vehicle_wheels.clear()
	var contract: Dictionary = _scene.get("vehicle", {})
	if _vehicle == null or contract.is_empty():
		return
	var reference: Array = contract.get("reference_size", [])
	if reference.size() != 2 or float(reference[0]) <= 0 or float(reference[1]) <= 0:
		return
	var reference_size := Vector2(float(reference[0]), float(reference[1]))
	_vehicle_source = _contract_rect(contract.get("source_px", []), Vector2(_vehicle.get_width(), _vehicle.get_height()) / reference_size)
	_vehicle_door_uv = _contract_rect(contract.get("door_rect_uv", []), Vector2.ONE)
	_vehicle_wheels = contract.get("wheels", []).duplicate(true)

func _contract_rect(value: Variant, scale_value: Vector2) -> Rect2:
	if not value is Array or value.size() != 4:
		return Rect2()
	return Rect2(Vector2(float(value[0]), float(value[1])) * scale_value, Vector2(float(value[2]), float(value[3])) * scale_value)


func skip_to_receipt() -> void:
	if not active or phase == "receipt":
		return
	phase = "receipt"
	elapsed = DURATION_SECONDS
	_caption.text = ""
	_caption.visible = false
	_summary.visible = true
	_summary_scroll.visible = true
	_summary_scroll.scroll_vertical = 0
	_skip.visible = false
	_continue.visible = true
	set_process(false)
	_layout()
	_focus_action(_continue)
	_update_scene_views()
	queue_redraw()
	if not _static:
		# Natural finish and Skip use the same exactly-once arrival path. Defer
		# emission so the host can refresh/free views without reentering input,
		# drawing or present(). Static outcome text still waits for Continue.
		call_deferred("_acknowledge_finished_cinematic", _presentation_generation)


func _acknowledge_finished_cinematic(generation: int) -> void:
	if generation != _presentation_generation or _static or not is_inside_tree():
		return
	acknowledge()


func acknowledge() -> void:
	if not active or phase != "receipt" or _completion_latched:
		return
	_completion_latched = true
	var journey_id := str(_receipt.get("journey_id", ""))
	cancel()
	completed.emit(journey_id)


func cancel() -> void:
	# Invalidate queued completion even when a replacement has the same receipt.
	_presentation_generation += 1
	if focus_scope != null:
		focus_scope.call("pop_scope", self)
	active = false
	phase = "idle"
	visible = false
	set_process(false)
	for view in [_main_scene_view, _vehicle_view, _entrance_back, _avatar_clip, _entrance_front, _avatar_view, _stage_tint]:
		if is_instance_valid(view): view.visible = false


func _focus_action(control: Control) -> void:
	if focus_scope != null:
		if focus_scope.call("active_root") == self:
			focus_scope.call("refresh_scope", self, control, [control])
		else:
			focus_scope.call("push_scope", self, control, null, [control])
	else:
		# Standalone previews have no host focus manager. Still prevent traversal
		# escaping into covered controls with keyboard or directional input.
		for property in ["focus_next", "focus_previous", "focus_neighbor_left", "focus_neighbor_right", "focus_neighbor_top", "focus_neighbor_bottom"]:
			control.set(property, control.get_path())
		control.grab_focus()


func _input(event: InputEvent) -> void:
	if not active:
		return
	if phase == "receipt" and (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down")):
		_summary_scroll.scroll_vertical += -60 if event.is_action_pressed("ui_up") else 60
		get_viewport().set_input_as_handled()
		return
	# One press performs at most one action. Skip can never cancel settlement.
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if phase == "receipt": acknowledge()
		else: skip_to_receipt()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		if phase == "receipt": acknowledge()
		else: skip_to_receipt()
		get_viewport().set_input_as_handled()


func snapshot() -> Dictionary:
	var vehicle_frame: Dictionary = _vehicle_view.draw_snapshot() if is_instance_valid(_vehicle_view) else {}
	return {"active": active, "phase": phase, "journey_id": str(_receipt.get("journey_id", "")),
		"elapsed_seconds": elapsed, "duration_seconds": DURATION_SECONDS, "static": _static,
		"mode": _mode, "origin_label": _scene.get("origin_label", ""),
		"exterior_id": _scene.get("exterior_id", ""), "background_path": _scene.get("background_path", ""),
		"main_scene_path": _scene.get("main_scene_path", ""), "backdrop_path": _scene.get("backdrop_path", ""),
		"doorway_path": _scene.get("doorway_path", ""), "doorway_has_art": _doorway != null,
		"vehicle_interior_path": _scene.get("vehicle", {}).get("interior_texture", ""), "vehicle_interior_has_art": _vehicle_interior != null,
		"foreground_kind": _scene.get("foreground_kind", "integrated_scene"),
		"cutout_shader": CutoutShader.resource_path, "solid_alpha_threshold": 0.80,
		"stage_rect": _stage, "arrival_progress": choreography_snapshot().get("arrival_progress", 0.0),
		"narration_visible": _caption.visible if _caption != null else false,
		"entry_progress": choreography_snapshot().get("entry_progress", 0.0),
		"entrance_front": _entrance_front.draw_snapshot() if is_instance_valid(_entrance_front) else {},
		"destination_label": _scene.get("destination_label", ""), "entrance_kind": _scene.get("entrance_kind", "open"),
		"receipt_text": str(_receipt.get("receipt_text", "")), "has_art": _has_scene_art(),
		"title": _title.text if _title != null else "", "continue_text": _continue.text if _continue != null else "",
		"choreography": choreography_snapshot(),
		"appearance": _avatar_view.snapshot() if is_instance_valid(_avatar_view) else {},
		"avatar_pose": _avatar_view.pose_snapshot() if is_instance_valid(_avatar_view) else {},
		"wheel_angle": vehicle_frame.get("wheel_angle", 0.0), "body_bob": vehicle_frame.get("body_bob", 0.0),
		"caption": _caption.text if _caption != null else "", "vehicle_renderer": "shared"}

func _layout() -> void:
	if _title == null:
		return
	var sx := size.x / 1280.0
	var sy := size.y / 720.0
	_stage = Rect2(64 * sx, 116 * sy, 1152 * sx, 500 * sy)
	_title.position = Vector2(64 * sx, 26 * sy)
	_title.size = Vector2(890 * sx, 50 * sy)
	_details.position = Vector2(64 * sx, 76 * sy)
	_details.size = Vector2(960 * sx, 34 * sy)
	_skip.position = Vector2(1040 * sx, 40 * sy)
	_skip.size = Vector2(176 * sx, 48 * sy)
	_caption.position = Vector2(64 * sx, 536 * sy)
	_caption.size = Vector2(1152 * sx, 42 * sy)
	_summary_scroll.position = Vector2(64 * sx, 636 * sy)
	_summary_scroll.size = Vector2(890 * sx, 70 * sy)
	_continue.position = Vector2(980 * sx, 646 * sy)
	_continue.size = Vector2(236 * sx, 58 * sy)
	_update_scene_views()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK if _high_contrast else INK)
	if _stage.size.x <= 0:
		return
	var choreography := _choreography()
	if _backdrop != null:
		_draw_environment_layer(_backdrop, choreography)
	else:
		draw_rect(_stage, Color("#18212d"))
	draw_rect(_stage, CYAN if _high_contrast else Color("#255b62"), false, 2.0)
	var progress := float(choreography["arrival_progress"])
	var line_y := _stage.end.y + 12.0
	draw_line(Vector2(_stage.position.x, line_y), Vector2(_stage.end.x, line_y), Color("#243540"), 3.0)
	draw_line(Vector2(_stage.position.x, line_y), Vector2(_stage.position.x + _stage.size.x * progress, line_y), CYAN, 3.0)


func _source_height_uv() -> float:
	return float(_scene.get("view_height_uv", 1.0 - float(_scene.get("source_top_y_uv", 0.5375))))


func _draw_environment_layer(texture: Texture2D, choreography: Dictionary) -> void:
	# Far city first; the retained alpha facade/road is drawn above it and
	# below every actor. No extra ground image or near strip is composited.
	draw_texture_rect_region(texture, _stage, _environment_source_rect(texture, choreography))


func _environment_source_rect(texture: Texture2D, choreography: Dictionary, main_layer: bool = false) -> Rect2:
	var native := Vector2(texture.get_width(), texture.get_height())
	var height_uv := _source_height_uv() if main_layer else float(_scene.get("backdrop_view_height_uv", _source_height_uv()))
	var width_uv := _source_width_uv() if main_layer else float(_scene.get("backdrop_source_width_uv", _source_width_uv()))
	var camera_key := "camera_x_uv" if main_layer else "background_camera_x_uv"
	var top := float(_scene.get("source_top_y_uv", 0.30)) if main_layer else float(_scene.get("backdrop_source_top_y_uv", 0.25))
	return Rect2(float(choreography[camera_key]) * native.x, top * native.y, width_uv * native.x, height_uv * native.y)


func _world_point(uv: Vector2, choreography: Dictionary) -> Vector2:
	var height_uv := _source_height_uv()
	return _stage.position + Vector2((uv.x - float(choreography["camera_x_uv"])) / _source_width_uv(), (uv.y - float(_scene.get("source_top_y_uv", 0.5375))) / height_uv) * _stage.size


func _update_scene_views() -> void:
	if _vehicle_view == null or _stage.size.x <= 0 or _stage.size.y <= 0:
		return
	var choreography := _choreography()
	_main_scene_view.position = _stage.position
	_main_scene_view.size = _stage.size
	_main_scene_view.visible = active and _street != null and _backdrop != null
	if _street != null:
		_main_scene_atlas.region = _environment_source_rect(_street, choreography, true)
	_vehicle_view.position = _stage.position
	_vehicle_view.size = _stage.size
	var show_vehicle := active and _mode != "walk" and bool(choreography["vehicle_visible"])
	var target := Rect2()
	if _vehicle_source.has_area():
		var foot := _world_point(Vector2(float(choreography["vehicle_left_uv"]), float(choreography["vehicle_road_y_uv"])), choreography) - _stage.position
		var width := float(choreography["vehicle_width_uv"]) * _stage.size.x / _source_width_uv()
		var height := width * _vehicle_source.size.y / _vehicle_source.size.x
		target = Rect2(foot - Vector2(0, height), Vector2(width, height))
	_vehicle_view.set_frame(target, float(choreography["vehicle_wheel_angle"]), float(choreography["vehicle_body_bob"]) * _stage.size.y / 370.0, float(choreography["vehicle_door_open"]), show_vehicle)
	var inside := bool(choreography["player_in_entrance"])
	var doorway := str(choreography["entrance_kind"]) == "door"
	var window := Rect2(float(choreography["camera_x_uv"]), float(_scene.get("source_top_y_uv", 0.30)), _source_width_uv(), _source_height_uv())
	for entrance in [_entrance_back, _entrance_front]:
		entrance.position = _stage.position
		entrance.size = _stage.size
		entrance.set_frame(window, float(choreography["destination_door_open"]), inside, active and doorway)
	_avatar_clip.visible = active
	_avatar_clip.position = _stage.position
	_avatar_clip.size = _stage.size
	if doorway and inside and _entrance_back.is_configured():
		var portal: Rect2 = _entrance_back.portal_rect().intersection(Rect2(Vector2.ZERO, _stage.size))
		_avatar_clip.position = _stage.position + portal.position
		_avatar_clip.size = portal.size
	_avatar_view.visible = active and bool(choreography["player_visible"])
	if _avatar_view.visible:
		var foot := _world_point(choreography["player_position_uv"], choreography)
		var height := float(_scene.get("avatar_height_uv", 0.14)) * _stage.size.y / _source_height_uv() * float(choreography["player_scale"])
		var bounds := AvatarView.DESIGN_SIZE * height / 107.0
		_avatar_view.size = bounds
		_avatar_view.position = foot - _avatar_clip.position - Vector2(bounds.x * 0.5, bounds.y)
		_avatar_view.modulate = Color(1, 1, 1, float(choreography["player_alpha"]))
		var pose := "walk" if bool(choreography["player_moving"]) else "idle"
		if str(choreography["beat"]) == "enter": pose = "enter"
		if bool(choreography.get("player_facing_away", false)): pose = "walk_away" if bool(choreography["player_moving"]) else "away_idle"
		_avatar_view.set_pose(pose, float(choreography["player_animation_seconds"]), {
			"walk_weight": choreography["player_walk_weight"],
			"walk_phase": choreography["player_walk_phase"],
			"walk_amplitude": choreography["player_walk_amplitude"],
			"idle_seconds": choreography["player_idle_seconds"],
		})
	_stage_tint.position = _stage.position
	_stage_tint.size = _stage.size
	var minute := int(_receipt.get("departed_game_clock_minutes", 0)) % 1440
	_stage_tint.visible = active and not _high_contrast and (minute < 360 or minute >= 1200)
	_stage_tint.color = Color(0.04, 0.07, 0.22, 0.18)


func choreography_snapshot(seconds: float = -1.0) -> Dictionary:
	return _choreography(elapsed if seconds < 0 else seconds)

func layer_window_snapshot(seconds: float) -> Dictionary:
	if _street == null or _backdrop == null:
		return {}
	var choreography := _choreography(seconds)
	var far_rect := _environment_source_rect(_backdrop, choreography)
	var main_rect := _environment_source_rect(_street, choreography, true)
	var far_native := Vector2(_backdrop.get_width(), _backdrop.get_height())
	var main_native := Vector2(_street.get_width(), _street.get_height())
	var far_window := Rect2(far_rect.position / far_native, far_rect.size / far_native)
	var main_window := Rect2(main_rect.position / main_native, main_rect.size / main_native)
	return {"main": main_window, "backdrop": far_window, "foreground": main_window, "background": far_window}


func _choreography(seconds: float = -1.0) -> Dictionary:
	return ArrivalTimeline.sample(elapsed if seconds < 0 else seconds, _mode, _scene.get("motion", {}))


func _has_scene_art() -> bool:
	var entrance_ready: bool = _scene.get("entrance_kind") != "door" or (_doorway != null and is_instance_valid(_entrance_back) and _entrance_back.is_configured())
	return _street != null and _backdrop != null and entrance_ready and (_mode == "walk" or (_vehicle_interior != null and is_instance_valid(_vehicle_view) and _vehicle_view.is_configured()))


func _source_width_uv() -> float:
	return float(_scene.get("source_width_uv", SOURCE_WIDTH_UV))
