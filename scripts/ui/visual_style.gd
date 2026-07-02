class_name VisualStyle
extends RefCounted

# Shared visual contract for Beat the House.
# Artists and UI engineers should change palette, board sizes, and common
# control styling here first before touching gameplay scripts.

const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")

const DARK := Color("#05060a")
const DARK_2 := Color("#0b0b18")
const DARK_3 := Color("#101427")
const PINK := Color("#ff2d78")
const PINK_2 := Color("#ff6eb4")
const HOT := PINK
const CYAN := Color("#00f5ff")
const CYAN_2 := Color("#0096a6")
const TEAL := Color("#00ffd5")
const YELLOW := Color("#ffe45c")
const AMBER := Color("#ffb32d")
const PURPLE := Color("#7b3cff")
const PURPLE_2 := Color("#c44dff")
const ORANGE := Color("#ff6a27")
const WHITE := Color("#ffffff")
const SOFT := Color("#d8e8ea")
const SHADOW := Color("#171022")
const BLUE := Color("#1d2140")

const PALETTE := {
	"dark": DARK,
	"dark_2": DARK_2,
	"dark_3": DARK_3,
	"pink": PINK,
	"pink_2": PINK_2,
	"hot": HOT,
	"cyan": CYAN,
	"cyan_2": CYAN_2,
	"teal": TEAL,
	"yellow": YELLOW,
	"amber": AMBER,
	"purple": PURPLE,
	"purple_2": PURPLE_2,
	"orange": ORANGE,
	"white": WHITE,
	"soft": SOFT,
	"shadow": SHADOW,
	"blue": BLUE,
}

const HIGH_CONTRAST_PALETTE := {
	"dark": Color("#000000"),
	"dark_2": Color("#050505"),
	"dark_3": Color("#101010"),
	"pink": Color("#ff4fa3"),
	"pink_2": Color("#ff9bd2"),
	"hot": Color("#ff4fa3"),
	"cyan": Color("#00e5ff"),
	"cyan_2": Color("#80f6ff"),
	"teal": Color("#00ff9a"),
	"yellow": Color("#fff05a"),
	"amber": Color("#ffd166"),
	"purple": Color("#b28dff"),
	"purple_2": Color("#d9b8ff"),
	"orange": Color("#ffb000"),
	"white": Color("#ffffff"),
	"soft": Color("#f5f7ff"),
	"shadow": Color("#303040"),
	"blue": Color("#5aa7ff"),
}

const ENVIRONMENT_BOARD_SIZE := ArtContractsScript.ENVIRONMENT_BOARD_SIZE
const GAME_BOARD_SIZE := ArtContractsScript.GAME_BOARD_SIZE
const ICON_SIZE := ArtContractsScript.ICON_SIZE
const UI_BORDER_WIDTH := 2
const UI_FONT_NAMES := ["Courier New", "Consolas", "monospace"]

static var high_contrast_enabled := false


static func set_high_contrast_enabled(enabled: bool) -> void:
	high_contrast_enabled = enabled


static func color(id: String, fallback: Color = WHITE) -> Color:
	var palette := HIGH_CONTRAST_PALETTE if high_contrast_enabled else PALETTE
	var value: Variant = palette.get(id, fallback)
	return value if typeof(value) == TYPE_COLOR else fallback


static func accessible_color(value: Color) -> Color:
	if not high_contrast_enabled:
		return value
	var token := _palette_token_for_color(value)
	if token.is_empty():
		return value
	return color(token, value)


static func accessibility_snapshot() -> Dictionary:
	return {
		"high_contrast_enabled": high_contrast_enabled,
		"palette": "high_contrast" if high_contrast_enabled else "standard",
		"soft": color("soft").to_html(false),
		"cyan": color("cyan").to_html(false),
		"yellow": color("yellow").to_html(false),
		"hot": color("hot").to_html(false),
	}


static func pixel_box(fill: Color, border: Color, width: int = UI_BORDER_WIDTH) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accessible_color(fill)
	style.border_color = accessible_color(border)
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func _palette_token_for_color(value: Color) -> String:
	for key in PALETTE.keys():
		var palette_value: Variant = PALETTE.get(key, WHITE)
		if typeof(palette_value) == TYPE_COLOR and _colors_match(value, palette_value):
			return str(key)
	return ""


static func _colors_match(a: Color, b: Color) -> bool:
	return (
		absf(a.r - b.r) <= 0.001
		and absf(a.g - b.g) <= 0.001
		and absf(a.b - b.b) <= 0.001
		and absf(a.a - b.a) <= 0.001
	)
