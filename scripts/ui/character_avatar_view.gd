class_name CharacterAvatarView
extends Control

const Appearance := preload("res://scripts/ui/character_appearance_snapshot.gd")
const TableVisuals := preload("res://scripts/games/table_game_visuals.gd")
const DESIGN_SIZE := Vector2(112.0, 120.0)

var _appearance: Dictionary = Appearance.from_character({})
var _pose := "idle"
var _clock := 0.0
var _locomotion: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = DESIGN_SIZE
	resized.connect(queue_redraw)


func set_appearance(value: Dictionary) -> void:
	_appearance = Appearance.normalized(value)
	queue_redraw()


func set_pose(pose: String, clock: float, locomotion: Dictionary = {}) -> void:
	_pose = pose if pose in ["idle", "walk", "walking", "arrive", "enter", "walk_away", "away_idle"] else "idle"
	_clock = maxf(0.0, clock) if is_finite(clock) else 0.0
	_locomotion = locomotion.duplicate(true)
	queue_redraw()


func snapshot() -> Dictionary:
	return _appearance.duplicate(true)


func pose_snapshot() -> Dictionary:
	return {"pose": _pose, "clock": _clock, "locomotion": _locomotion.duplicate(true)}


func foot_position() -> Vector2:
	return Vector2(size.x * 0.5, size.y)


func _draw() -> void:
	draw_avatar(self, _appearance, size, _pose, _clock, _locomotion)


static func draw_avatar(surface, appearance: Dictionary, bounds: Vector2, pose: String, clock: float, locomotion: Dictionary = {}) -> void:
	# Deliberately supplied clock: travel owns timeline; another future view can
	# own its idle schedule. No wall clock, random generator, or run reads here.
	if bounds.x <= 0.0 or bounds.y <= 0.0:
		return
	var model: Dictionary = appearance["model"]
	var scale_value := minf(bounds.x / DESIGN_SIZE.x, bounds.y / DESIGN_SIZE.y)
	# Same authored scale mapping as PixelSceneCanvas._character_actor_scale.
	scale_value *= lerpf(0.90, 1.08, (float(model["scale"]) - 0.75) / 0.50)
	var foot := Vector2(bounds.x * 0.5, bounds.y)
	var walking := pose in ["walk", "walking", "enter", "walk_away"]
	var stride := sin(clock * 8.0) if walking else 0.0
	var bob := -absf(stride) * 1.6 if walking else sin(clock * 1.8) * 0.45
	var sway := 0.0 if walking else sin(clock * 1.8) * 1.0
	var arm_stride := stride
	var walk_weight := 1.0
	if not locomotion.is_empty():
		# Travel supplies a continuous gait independently of semantic pose. An
		# idle clock never changes source when the arms settle after stopping.
		walk_weight = clampf(_motion_number(locomotion, "walk_weight", 1.0 if walking else 0.0), 0.0, 1.0)
		var walk_phase := _motion_number(locomotion, "walk_phase", clock * 8.0)
		var amplitude := clampf(_motion_number(locomotion, "walk_amplitude", 1.0), 0.0, 1.0)
		var idle_seconds := _motion_number(locomotion, "idle_seconds", clock)
		arm_stride = sin(walk_phase) * amplitude
		stride = arm_stride * walk_weight
		bob = lerpf(sin(idle_seconds * 1.8) * 0.45, -absf(arm_stride) * 1.6, walk_weight)
		sway = sin(idle_seconds * 1.8) * (1.0 - walk_weight)
		walking = walk_weight > 0.0
	var hip := foot + Vector2(sway, -29.0 + bob) * scale_value
	var jacket := Color(model["jacket_color"])
	var trouser := jacket.darkened(0.30)
	surface.draw_rect(Rect2(foot + Vector2(-24, -3) * scale_value, Vector2(48, 3) * scale_value), Color(0, 0, 0, 0.26))
	for side in [-1.0, 1.0]:
		var step: float = stride * side
		var ankle := foot + Vector2(side * 10.0 + step * 8.0, -4.0 - maxf(0.0, step) * 5.0) * scale_value
		var leg_top := hip + Vector2(side * 10, -5) * scale_value
		surface.draw_line(leg_top, ankle, Color("#05060a"), 11.0 * scale_value)
		surface.draw_line(leg_top, ankle, trouser, 7.0 * scale_value)
		surface.draw_rect(Rect2(ankle + Vector2(-6, 0) * scale_value, Vector2(14, 4) * scale_value), Color("#05060a"))
	var kinds: Array = []
	for accessory in appearance.get("accessories", []):
		var kind := str(accessory.get("kind", ""))
		if kind in Appearance.ACCESSORY_KINDS and not kinds.has(kind):
			kinds.append(kind)
	# Identity, torso, arms, head, facial features and accessory primitives all
	# remain in the actual game painter. Only the full-body legs are added here.
	TableVisuals._draw_table_character(surface, {
		"name": "", "skin": Color(model["skin_color"]),
		"hair": Color(model["hair_color"]), "jacket": jacket,
		"accent": Color(model["accent_color"]),
		"silhouette": str(model["silhouette"]), "accessories": kinds,
		"pose": "walk" if walking else "idle", "walk_stride": arm_stride,
		"gesture_amount": walk_weight,
		"facing_away": pose in ["walk_away", "away_idle"],
		"sway_amount": 0.0, "show_shadow": false,
	}, hip, scale_value, clock)


static func _motion_number(locomotion: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = locomotion.get(key, fallback)
	if not (value is float or value is int):
		return fallback
	var number := float(value)
	return number if is_finite(number) else fallback
