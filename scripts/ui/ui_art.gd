class_name UIArt
extends RefCounted

# Single runtime door for bundled UI raster art and original control SVGs.

const ICON_ROOT := "res://assets/art/ui/icons"
const TITLE_ROOT := "res://assets/art/ui/environment_titles"
const PORTRAIT_ROOT := "res://assets/art/ui/portraits"

# Explicit dependencies are exported with the UI. These contain geometry only,
# never text, a system font, a remote reference or an emoji fallback.
const CONTROL_ICONS := {
	"settings": preload("res://assets/art/ui/icons/controls/settings.svg"),
	"run_setup": preload("res://assets/art/ui/icons/controls/run_setup.svg"),
	"close": preload("res://assets/art/ui/icons/controls/close.svg"),
	"previous": preload("res://assets/art/ui/icons/controls/previous.svg"),
	"next": preload("res://assets/art/ui/icons/controls/next.svg"),
	"decrease": preload("res://assets/art/ui/icons/controls/decrease.svg"),
	"increase": preload("res://assets/art/ui/icons/controls/increase.svg"),
	"play": preload("res://assets/art/ui/icons/controls/play.svg"),
	"replay": preload("res://assets/art/ui/icons/controls/replay.svg"),
	"selected": preload("res://assets/art/ui/icons/controls/selected.svg"),
	"focused": preload("res://assets/art/ui/icons/controls/focused.svg"),
	"hovered": preload("res://assets/art/ui/icons/controls/hovered.svg"),
	"cash_transfer": preload("res://assets/art/ui/icons/controls/cash_transfer.svg"),
}

const ICON_IDS := [
	"wallet",
	"casino_chips",
	"heat",
	"drink",
	"alert",
	"debt",
	"home",
	"save",
	"time",
	"luck",
	"cheat",
	"danger",
]

const PORTRAIT_IDS := [
	"motel_clerk",
	"pit_boss",
	"bartender",
	"pawn_broker",
	"riverboat_dealer",
	"faceless_lender",
]

const ENVIRONMENT_TITLE_IDS := [
	"corner_store",
	"back_alley",
	"motel",
	"bar",
	"gas_station_casino",
	"small_underground_casino",
	"jazz_club",
	"kitty_cat_lounge",
	"delta_queen",
	"beach",
	"pawn_shop",
	"grand_casino",
	"grand_casino_high_limit",
	"grand_casino_back_room",
	"grand_casino_cage",
	"motel_room",
	"apartment",
	"house",
]

static var _cache: Dictionary = {}


static func icon(icon_id: String) -> Texture2D:
	return _texture_or_fallback("%s/%s.png" % [ICON_ROOT, icon_id], "icon:%s" % icon_id, Vector2i(64, 64))


static func control_icon(icon_id: String) -> Texture2D:
	return CONTROL_ICONS.get(icon_id) as Texture2D


static func apply_control_icon(button: Button, icon_id: String, accessible_label: String, size: int = 24, icon_only: bool = false) -> void:
	button.icon = control_icon(icon_id)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", size)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if icon_only else HORIZONTAL_ALIGNMENT_LEFT
	button.accessibility_name = accessible_label
	button.set_meta("local_ui_icon_id", icon_id)
	if button.tooltip_text.is_empty():
		button.tooltip_text = accessible_label
	if icon_only:
		# Unknown IDs remain usable text controls, never empty glyph boxes.
		button.text = "" if button.icon != null else accessible_label


static func environment_title(archetype_id: String) -> Texture2D:
	return _texture_or_fallback(
		"%s/%s.png" % [TITLE_ROOT, archetype_id],
		"title:%s" % archetype_id,
		Vector2i(384, 64)
	)


static func portrait(portrait_id: String) -> Texture2D:
	return _texture_or_fallback(
		"%s/%s.png" % [PORTRAIT_ROOT, portrait_id],
		"portrait:%s" % portrait_id,
		Vector2i(192, 224)
	)


static func expected_runtime_paths() -> Array[String]:
	var paths: Array[String] = []
	for texture in CONTROL_ICONS.values():
		paths.append(texture.resource_path)
	for icon_id in ICON_IDS:
		paths.append("%s/%s.png" % [ICON_ROOT, icon_id])
	for title_id in ENVIRONMENT_TITLE_IDS:
		paths.append("%s/%s.png" % [TITLE_ROOT, title_id])
	for portrait_id in PORTRAIT_IDS:
		paths.append("%s/%s.png" % [PORTRAIT_ROOT, portrait_id])
	return paths


static func fallback_for_test(kind: String, key: String) -> Texture2D:
	var size := Vector2i(64, 64)
	if kind == "title":
		size = Vector2i(384, 64)
	elif kind == "portrait":
		size = Vector2i(192, 224)
	return _texture_or_fallback(
		"res://.tmp/ui05_missing/%s/%s.png" % [kind, key],
		"%s:%s" % [kind, key],
		size
	)


static func _texture_or_fallback(path: String, fallback_key: String, size: Vector2i) -> Texture2D:
	if _cache.has(path):
		return _cache[path] as Texture2D
	var texture: Texture2D
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture == null:
		texture = _fallback_texture(fallback_key, size)
	_cache[path] = texture
	return texture


static func _fallback_texture(key: String, size: Vector2i) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(VisualStyle.role("surface_raised"))
	var border := VisualStyle.role("accent_primary")
	var accent := VisualStyle.role("focus")
	for x in range(size.x):
		for y in range(size.y):
			if x < VisualStyle.BORDER_STANDARD or y < VisualStyle.BORDER_STANDARD:
				image.set_pixel(x, y, border)
			elif x >= size.x - VisualStyle.BORDER_STANDARD or y >= size.y - VisualStyle.BORDER_STANDARD:
				image.set_pixel(x, y, border)
			elif (x + y + key.hash()) % VisualStyle.SPACE_6 == 0:
				image.set_pixel(x, y, Color(accent, 0.34))
	var middle := size / 2
	var mark_half := maxi(VisualStyle.SPACE_2, mini(size.x, size.y) / VisualStyle.SPACE_6)
	for x in range(middle.x - mark_half, middle.x + mark_half + 1):
		for y in range(middle.y - VisualStyle.BORDER_STANDARD, middle.y + VisualStyle.BORDER_STANDARD + 1):
			image.set_pixel(x, y, accent)
	for x in range(middle.x - VisualStyle.BORDER_STANDARD, middle.x + VisualStyle.BORDER_STANDARD + 1):
		for y in range(middle.y - mark_half, middle.y + mark_half + 1):
			image.set_pixel(x, y, accent)
	return ImageTexture.create_from_image(image)
