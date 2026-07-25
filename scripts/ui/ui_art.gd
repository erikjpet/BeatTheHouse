class_name UIArt
extends RefCounted

# Single runtime door for artist-swappable 0.5 UI raster art.

const ICON_ROOT := "res://assets/art/ui/icons"
const TITLE_ROOT := "res://assets/art/ui/environment_titles"
const PORTRAIT_ROOT := "res://assets/art/ui/portraits"

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
	for icon_id in ICON_IDS:
		paths.append("%s/%s.png" % [ICON_ROOT, icon_id])
	for title_id in ENVIRONMENT_TITLE_IDS:
		paths.append("%s/%s.png" % [TITLE_ROOT, title_id])
	for portrait_id in PORTRAIT_IDS:
		paths.append("%s/%s.png" % [PORTRAIT_ROOT, portrait_id])
	return paths


static func clear_cache() -> void:
	_cache.clear()


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
