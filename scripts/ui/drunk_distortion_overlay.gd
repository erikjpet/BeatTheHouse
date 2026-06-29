class_name DrunkDistortionOverlay
extends ColorRect

# Presentation-only screen-space filter for alcohol distortion. It samples the
# already-rendered surface behind this overlay, then bends the sampled image.

const DISTORTION_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity = 0.0;
uniform int ui_protected_rect_count = 0;
uniform float ui_intensity_scale = 0.333333;
uniform vec4 ui_rect_0 = vec4(-1.0);
uniform vec4 ui_rect_1 = vec4(-1.0);
uniform vec4 ui_rect_2 = vec4(-1.0);
uniform vec4 ui_rect_3 = vec4(-1.0);
uniform vec4 ui_rect_4 = vec4(-1.0);
uniform vec4 ui_rect_5 = vec4(-1.0);
uniform vec4 ui_rect_6 = vec4(-1.0);
uniform vec4 ui_rect_7 = vec4(-1.0);
uniform vec4 ui_rect_8 = vec4(-1.0);
uniform vec4 ui_rect_9 = vec4(-1.0);
uniform vec4 ui_rect_10 = vec4(-1.0);
uniform vec4 ui_rect_11 = vec4(-1.0);
uniform vec4 ui_rect_12 = vec4(-1.0);
uniform vec4 ui_rect_13 = vec4(-1.0);
uniform vec4 ui_rect_14 = vec4(-1.0);
uniform vec4 ui_rect_15 = vec4(-1.0);

float readable_rect_mask(vec4 rect, vec2 uv) {
	if (rect.z <= rect.x || rect.w <= rect.y) {
		return 0.0;
	}
	vec2 feather = vec2(0.008, 0.012);
	float left = smoothstep(rect.x, rect.x + feather.x, uv.x);
	float right = 1.0 - smoothstep(rect.z - feather.x, rect.z, uv.x);
	float top = smoothstep(rect.y, rect.y + feather.y, uv.y);
	float bottom = 1.0 - smoothstep(rect.w - feather.y, rect.w, uv.y);
	return clamp(left * right * top * bottom, 0.0, 1.0);
}

float readable_ui_mask(vec2 uv) {
	float mask = 0.0;
	if (ui_protected_rect_count > 0) { mask = max(mask, readable_rect_mask(ui_rect_0, uv)); }
	if (ui_protected_rect_count > 1) { mask = max(mask, readable_rect_mask(ui_rect_1, uv)); }
	if (ui_protected_rect_count > 2) { mask = max(mask, readable_rect_mask(ui_rect_2, uv)); }
	if (ui_protected_rect_count > 3) { mask = max(mask, readable_rect_mask(ui_rect_3, uv)); }
	if (ui_protected_rect_count > 4) { mask = max(mask, readable_rect_mask(ui_rect_4, uv)); }
	if (ui_protected_rect_count > 5) { mask = max(mask, readable_rect_mask(ui_rect_5, uv)); }
	if (ui_protected_rect_count > 6) { mask = max(mask, readable_rect_mask(ui_rect_6, uv)); }
	if (ui_protected_rect_count > 7) { mask = max(mask, readable_rect_mask(ui_rect_7, uv)); }
	if (ui_protected_rect_count > 8) { mask = max(mask, readable_rect_mask(ui_rect_8, uv)); }
	if (ui_protected_rect_count > 9) { mask = max(mask, readable_rect_mask(ui_rect_9, uv)); }
	if (ui_protected_rect_count > 10) { mask = max(mask, readable_rect_mask(ui_rect_10, uv)); }
	if (ui_protected_rect_count > 11) { mask = max(mask, readable_rect_mask(ui_rect_11, uv)); }
	if (ui_protected_rect_count > 12) { mask = max(mask, readable_rect_mask(ui_rect_12, uv)); }
	if (ui_protected_rect_count > 13) { mask = max(mask, readable_rect_mask(ui_rect_13, uv)); }
	if (ui_protected_rect_count > 14) { mask = max(mask, readable_rect_mask(ui_rect_14, uv)); }
	if (ui_protected_rect_count > 15) { mask = max(mask, readable_rect_mask(ui_rect_15, uv)); }
	return mask;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 local_uv = UV;
	float local_intensity = intensity * mix(1.0, ui_intensity_scale, readable_ui_mask(local_uv));
	float sway = sin((local_uv.y * 7.0) + TIME * 1.55);
	float slow_sway = sin((local_uv.y * 2.6) - TIME * 0.72);
	float swim = sin((local_uv.x * 5.4) + (local_uv.y * 2.2) + TIME * 1.18);
	vec2 wave_offset = vec2(
		(sway * 0.010 + slow_sway * 0.007) * local_intensity,
		swim * 0.0045 * local_intensity
	);
	float chroma = 0.0025 * local_intensity;
	vec4 center = texture(screen_texture, uv + wave_offset);
	vec4 soft_a = texture(screen_texture, uv + wave_offset * 1.55 + vec2(0.0, chroma));
	vec4 soft_b = texture(screen_texture, uv - wave_offset * 0.65 - vec2(0.0, chroma));
	vec4 blurred = (center * 0.58) + (soft_a * 0.22) + (soft_b * 0.20);
	vec4 red = texture(screen_texture, uv + wave_offset + vec2(chroma, 0.0));
	vec4 blue = texture(screen_texture, uv + wave_offset - vec2(chroma, 0.0));
	vec3 separated = vec3(red.r, blurred.g, blue.b);
	float lens = smoothstep(0.82, 0.18, distance(local_uv, vec2(0.5, 0.5)));
	vec3 woozy_tint = vec3(0.04, 0.025, 0.075) * local_intensity * (0.35 + lens * 0.45);
	COLOR.rgb = mix(blurred.rgb, separated, 0.38 * local_intensity) + woozy_tint;
	COLOR.a = clamp(0.72 + local_intensity * 0.28, 0.0, 1.0);
}
"""

const GLOBAL_DISTORTION_SCALE := 0.80
const UI_DISTORTION_SCALE := 1.0 / 3.0
const MAX_UI_PROTECTED_RECTS := 16

var _shader_material: ShaderMaterial
var _drunk_level: int = 0
var _intensity: float = 0.0
var _ui_protected_rects: Array = []
var _reduce_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	var shader := Shader.new()
	shader.code = DISTORTION_SHADER
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	material = _shader_material
	_shader_material.set_shader_parameter("ui_intensity_scale", UI_DISTORTION_SCALE)
	set_drunk_level(_drunk_level)
	_apply_ui_protected_rects()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_ui_protected_rects()


func set_drunk_level(level: int) -> void:
	_drunk_level = clampi(level, 0, 100)
	visible = _drunk_level >= 12 and not _reduce_motion
	_intensity = 0.0
	if visible:
		var normalized := clampf(float(_drunk_level - 12) / 88.0, 0.0, 1.0)
		_intensity = pow(normalized, 1.75) * GLOBAL_DISTORTION_SCALE
	if _shader_material != null:
		_shader_material.set_shader_parameter("intensity", _intensity)


func set_reduce_motion(enabled: bool) -> void:
	_reduce_motion = enabled
	set_drunk_level(_drunk_level)


func set_ui_protected_rects(rects: Array) -> void:
	_ui_protected_rects = []
	for rect_value in rects:
		if typeof(rect_value) != TYPE_RECT2:
			continue
		var rect: Rect2 = rect_value
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		_ui_protected_rects.append(rect)
		if _ui_protected_rects.size() >= MAX_UI_PROTECTED_RECTS:
			break
	_apply_ui_protected_rects()


func ui_protected_rect_count() -> int:
	return _ui_protected_rects.size()


func debug_snapshot() -> Dictionary:
	return {
		"drunk_level": _drunk_level,
		"visible": visible,
		"intensity": _intensity,
		"global_distortion_scale": GLOBAL_DISTORTION_SCALE,
		"ui_distortion_scale": UI_DISTORTION_SCALE,
		"ui_protected_rect_count": _ui_protected_rects.size(),
		"reduce_motion": _reduce_motion,
	}


func _apply_ui_protected_rects() -> void:
	if _shader_material == null:
		return
	var safe_size := Vector2(maxf(1.0, size.x), maxf(1.0, size.y))
	_shader_material.set_shader_parameter("ui_protected_rect_count", _ui_protected_rects.size())
	for i in range(MAX_UI_PROTECTED_RECTS):
		var uv_rect := Vector4(-1.0, -1.0, -1.0, -1.0)
		if i < _ui_protected_rects.size():
			var rect: Rect2 = _ui_protected_rects[i]
			var top_left := Vector2(
				clampf(rect.position.x / safe_size.x, 0.0, 1.0),
				clampf(rect.position.y / safe_size.y, 0.0, 1.0)
			)
			var bottom_right := Vector2(
				clampf(rect.end.x / safe_size.x, 0.0, 1.0),
				clampf(rect.end.y / safe_size.y, 0.0, 1.0)
			)
			uv_rect = Vector4(top_left.x, top_left.y, bottom_right.x, bottom_right.y)
		_shader_material.set_shader_parameter("ui_rect_%d" % i, uv_rect)
