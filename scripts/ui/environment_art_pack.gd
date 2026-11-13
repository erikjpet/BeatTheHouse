class_name EnvironmentArtPack
extends RefCounted

# The only manifest parsing/texture validation seam. Drawers consume these
# compiled fields, never JSON, string-key animation dictionaries or file IO.
const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")
const INDEX_PATH := "res://data/art/environments/index.json"
const MANIFEST_ROOT := "res://data/art/environments"
const ASSET_ROOT := "res://assets/art/environments"
const SURFACES_PATH := "res://data/environments/placement_surfaces.json"
const ARCHETYPES_PATH := "res://data/environments/archetypes.json"
const SCHEMA := "bth.environment_art/v1"
enum AnimationKind { FRAMES, PULSE, MOVER, SCROLL, SWEEP }
enum LoopMode { LOOP, PINGPONG, ONCE_HOLD }


class AnimationEntry:
	extends RefCounted
	var id: String
	var kind: int
	var texture: Texture2D
	var rect := Rect2()
	var size := Vector2.ZERO
	var from_point := Vector2.ZERO
	var to_point := Vector2.ZERO
	var origin := Vector2.ZERO
	var speed := Vector2.ZERO
	var clip := Rect2()
	var has_clip := false
	var frame_regions: Array[Rect2] = []
	var frame_count := 1
	var fps := 0.0
	var loop_mode := LoopMode.LOOP
	var opacity := 1.0
	var modulation := Color.WHITE
	var min_opacity := 0.0
	var max_opacity := 1.0
	var period := 1.0
	var duration := 1.0
	var gap := 0.0
	var phase := 0.0
	var additive := false
	var web_low_detail := true
	var still_hidden := false
	var still_frame := 0
	var beam_thickness := 0.0


class CounterEntry:
	extends RefCounted
	var texture: Texture2D
	var rect := Rect2()


var environment_id: String
var background: Texture2D
var background_rect := Rect2(Vector2.ZERO, Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE))
var animations: Array[AnimationEntry] = []
var counters: Dictionary[String, CounterEntry] = {}
var texture_paths: Array[String] = []
var estimated_texture_bytes := 0
static var last_error := ""


static func enabled_environment_ids() -> Array[String]:
	var result: Array[String] = []
	if not FileAccess.file_exists(INDEX_PATH):
		return result
	var value: Variant = _read_json(INDEX_PATH)
	if not value is Dictionary or not value.get("enabled") is Array:
		push_warning("Environment art index ignored: expected an enabled array.")
		return result
	for id_value in value["enabled"]:
		if not id_value is String or not _safe_id(id_value):
			push_warning("Environment art index ignored: invalid room id.")
			return []
		if not result.has(id_value):
			result.append(id_value)
	return result


static func load_pack(room_id: String) -> EnvironmentArtPack:
	last_error = ""
	if not _safe_id(room_id) or not enabled_environment_ids().has(room_id):
		return null
	var pack := _load_paths(room_id, MANIFEST_ROOT.path_join(room_id + ".json"), ASSET_ROOT.path_join(room_id), room_counter_rectangles(room_id))
	if pack == null:
		push_warning("Environment art pack '%s' ignored: %s" % [room_id, last_error])
	return pack


static func _load_paths(room_id: String, manifest_path: String, asset_root: String, counter_rects: Dictionary, textures: Dictionary = {}) -> EnvironmentArtPack:
	last_error = ""
	var manifest: Variant = _read_json(manifest_path)
	if not manifest is Dictionary:
		return _invalid("manifest: missing or invalid JSON object at " + manifest_path)
	return compile_manifest(manifest, room_id, asset_root, counter_rects, textures)


static func compile_manifest(manifest: Dictionary, room_id: String, asset_root: String, counter_rects: Dictionary, provided_textures: Dictionary = {}) -> EnvironmentArtPack:
	last_error = ""
	if manifest.get("schema") != SCHEMA:
		return _invalid("schema: expected bth.environment_art/v1")
	if manifest.get("environment_id") != room_id:
		return _invalid("environment_id: does not match requested room")
	var board: Variant = manifest.get("board_size")
	if not _vector_valid(board, 2) or float(board[0]) != ArtContractsScript.ENVIRONMENT_BOARD_SIZE.x or float(board[1]) != ArtContractsScript.ENVIRONMENT_BOARD_SIZE.y:
		return _invalid("board_size: expected [900, 430]")
	if not _number(manifest.get("pixel_scale")) or float(manifest["pixel_scale"]) != 2.0:
		return _invalid("pixel_scale: expected 2")
	var pack := EnvironmentArtPack.new()
	pack.environment_id = room_id
	var texture_cache := provided_textures.duplicate()
	pack.background = _texture(manifest.get("background"), Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE), 1, "background", asset_root, texture_cache, pack)
	if pack.background == null:
		return null
	var entries: Variant = manifest.get("animations", [])
	if not entries is Array:
		return _invalid("animations: expected an array")
	for index in range(entries.size()):
		var value: Variant = entries[index]
		if not value is Dictionary:
			return _invalid("animations[%d]: expected an object" % index)
		var entry := _compile_animation(value, index, asset_root, texture_cache, pack)
		if entry == null:
			return null
		pack.animations.append(entry)
	var counter_values: Variant = manifest.get("counters", {})
	if not counter_values is Dictionary:
		return _invalid("counters: expected an object")
	for key in counter_values:
		if not counter_rects.has(key):
			return _invalid("counters.%s: not a foreground_art_id in this room" % key)
		var value: Variant = counter_values[key]
		if not value is Dictionary:
			return _invalid("counters.%s: expected an object" % key)
		var bleed: Variant = value.get("bleed", [0, 0, 0, 0])
		if not _vector_valid(bleed, 4):
			return _invalid("counters.%s.bleed: expected four finite nonnegative values" % key)
		for amount in bleed:
			if float(amount) < 0.0:
				return _invalid("counters.%s.bleed: expected four finite nonnegative values" % key)
		var rect: Rect2 = counter_rects[key]
		rect = rect.grow_individual(float(bleed[0]), float(bleed[1]), float(bleed[2]), float(bleed[3]))
		if not _board_rect_valid(rect):
			return _invalid("counters.%s: rectangle must intersect the board" % key)
		var counter := CounterEntry.new()
		counter.rect = rect
		counter.texture = _texture(value, rect.size, 1, "counters." + str(key), asset_root, texture_cache, pack)
		if counter.texture == null:
			return null
		pack.counters[str(key)] = counter
	return pack


static func _compile_animation(value: Dictionary, index: int, asset_root: String, cache: Dictionary, pack: EnvironmentArtPack) -> AnimationEntry:
	var label := "animations[%d]" % index
	var entry := AnimationEntry.new()
	match value.get("type"):
		"frames": entry.kind = AnimationKind.FRAMES
		"pulse": entry.kind = AnimationKind.PULSE
		"mover": entry.kind = AnimationKind.MOVER
		"scroll": entry.kind = AnimationKind.SCROLL
		"sweep": entry.kind = AnimationKind.SWEEP
		_:
			last_error = label + ".type: unknown animation type"
			return null
	entry.id = str(value.get("id", "animation_%d" % index))
	if value.get("blend", "mix") not in ["mix", "add"]:
		last_error = label + ".blend: expected mix or add"
		return null
	entry.additive = value.get("blend", "mix") == "add"
	if not _number(value.get("opacity", 1)) or float(value.get("opacity", 1)) < 0.0 or float(value.get("opacity", 1)) > 1.0 or not _number(value.get("phase", 0)):
		last_error = label + ": opacity must be finite in 0..1; phase must be finite"
		return null
	if not value.get("web_low_detail", true) is bool:
		last_error = label + ".web_low_detail: expected boolean"
		return null
	entry.web_low_detail = value.get("web_low_detail", true)
	entry.opacity = float(value.get("opacity", 1))
	entry.modulation = Color(1.0, 1.0, 1.0, entry.opacity)
	entry.phase = float(value.get("phase", 0))
	if not _integer(value.get("frames", 1)) or float(value.get("frames", 1)) < 1.0:
		last_error = label + ".frames: expected integer >= 1"
		return null
	entry.frame_count = int(value.get("frames", 1))
	if entry.kind == AnimationKind.FRAMES or (entry.kind == AnimationKind.MOVER and (value.has("frames") or value.has("fps"))):
		if not value.has("frames") or not _positive(value.get("fps")):
			last_error = label + ": frames and positive fps are required together"
			return null
		entry.fps = float(value["fps"])
	match value.get("loop", "loop"):
		"loop": entry.loop_mode = LoopMode.LOOP
		"pingpong": entry.loop_mode = LoopMode.PINGPONG
		"once_hold": entry.loop_mode = LoopMode.ONCE_HOLD
		_:
			last_error = label + ".loop: unknown loop mode"
			return null
	var still: Variant = value.get("still", "first")
	if still is String:
		if still not in ["first", "hide"]:
			last_error = label + ".still: expected first, hide or an existing frame number"
			return null
		entry.still_hidden = still == "hide"
	elif _integer(still) and float(still) >= 0.0 and float(still) < entry.frame_count:
		entry.still_frame = int(still)
	else:
		last_error = label + ".still: expected first, hide or an existing frame number"
		return null
	var expected_size := Vector2.ZERO
	if entry.kind in [AnimationKind.FRAMES, AnimationKind.PULSE, AnimationKind.SCROLL]:
		if not _rect_valid(value.get("rect")):
			last_error = label + ".rect: finite positive rectangle must intersect the board"
			return null
		entry.rect = _rect(value["rect"])
		expected_size = entry.rect.size
	if entry.kind == AnimationKind.PULSE:
		if not _number(value.get("min_opacity")) or not _number(value.get("max_opacity")) or not _positive(value.get("period")):
			last_error = label + ": pulse needs finite opacity bounds and positive period"
			return null
		entry.min_opacity = float(value["min_opacity"])
		entry.max_opacity = float(value["max_opacity"])
		entry.period = float(value["period"])
		if entry.min_opacity < 0.0 or entry.max_opacity > 1.0 or entry.min_opacity > entry.max_opacity:
			last_error = label + ": pulse needs 0 <= min_opacity <= max_opacity <= 1"
			return null
	if entry.kind == AnimationKind.MOVER:
		if not _vector_valid(value.get("size"), 2) or not _vector_valid(value.get("from"), 2) or not _vector_valid(value.get("to"), 2) or not _positive(value.get("duration")) or not _number(value.get("gap", 0)) or float(value.get("gap", 0)) < 0.0:
			last_error = label + ": mover needs finite size/from/to, positive duration and nonnegative gap"
			return null
		entry.size = _point(value["size"])
		if entry.size.x <= 0.0 or entry.size.y <= 0.0:
			last_error = label + ".size: expected positive finite size"
			return null
		expected_size = entry.size
		entry.from_point = _point(value["from"])
		entry.to_point = _point(value["to"])
		entry.duration = float(value["duration"])
		entry.gap = float(value.get("gap", 0))
		if value.has("clip"):
			if not _rect_valid(value["clip"]):
				last_error = label + ".clip: finite positive rectangle must intersect the board"
				return null
			entry.clip = _rect(value["clip"])
			entry.has_clip = true
	if entry.kind == AnimationKind.SCROLL:
		if not _vector_valid(value.get("speed"), 2):
			last_error = label + ".speed: expected two finite values"
			return null
		entry.speed = _point(value["speed"])
	if entry.kind == AnimationKind.SWEEP:
		if not _vector_valid(value.get("origin"), 2) or not _vector_valid(value.get("from"), 2) or not _vector_valid(value.get("to"), 2) or not _positive(value.get("period")):
			last_error = label + ": sweep needs finite origin/from/to and positive period"
			return null
		entry.origin = _point(value["origin"])
		entry.from_point = _point(value["from"])
		entry.to_point = _point(value["to"])
		entry.period = float(value["period"])
	var strip_frames := entry.frame_count if entry.kind in [AnimationKind.FRAMES, AnimationKind.MOVER] else 1
	entry.texture = _texture(value, expected_size, strip_frames, label, asset_root, cache, pack)
	if entry.texture == null:
		return null
	var frame_size := Vector2(float(entry.texture.get_width()) / float(strip_frames), float(entry.texture.get_height()))
	for frame in range(strip_frames):
		entry.frame_regions.append(Rect2(Vector2(frame * frame_size.x, 0.0), frame_size))
	entry.beam_thickness = float(entry.texture.get_height()) / 2.0
	return entry


static func _texture(value: Variant, expected_size: Vector2, frames: int, label: String, asset_root: String, cache: Dictionary, pack: EnvironmentArtPack) -> Texture2D:
	if not value is Dictionary or not value.get("texture") is String:
		last_error = label + ".texture: expected a relative PNG path"
		return null
	var relative: String = value["texture"]
	if relative.is_empty() or relative.is_absolute_path() or relative.contains(":") or relative.contains("\\") or relative.split("/").has("..") or relative.get_extension().to_lower() != "png":
		last_error = label + ".texture: must stay within the room asset folder"
		return null
	var path := asset_root.path_join(relative)
	var texture: Texture2D = cache.get(relative) as Texture2D
	if texture == null:
		if ResourceLoader.exists(path, "Texture2D"):
			texture = load(path) as Texture2D
		if texture == null:
			last_error = label + ".texture: missing or unloadable texture at " + path
			return null
		cache[relative] = texture
	if texture.get_width() % frames != 0:
		last_error = label + ": uneven horizontal frame strip"
		return null
	var wanted := expected_size * 2.0
	wanted.x *= frames
	if expected_size != Vector2.ZERO:
		if texture.get_width() != wanted.x or texture.get_height() != wanted.y:
			last_error = "%s: texture is %dx%d; expected %sx%s" % [label, texture.get_width(), texture.get_height(), wanted.x, wanted.y]
			return null
	elif texture.get_width() % 2 != 0 or texture.get_height() % 2 != 0:
		last_error = label + ": sweep texture must be authored at 2x"
		return null
	if not pack.texture_paths.has(path):
		pack.texture_paths.append(path)
		pack.estimated_texture_bytes += texture.get_width() * texture.get_height() * 4
	return texture


static func room_counter_rectangles(room_id: String) -> Dictionary:
	var result := {}
	var surfaces: Variant = _read_json(SURFACES_PATH)
	if not surfaces is Dictionary or not surfaces.get("maps") is Array:
		return result
	var map_id := room_id
	var archetypes: Variant = _read_json(ARCHETYPES_PATH)
	if archetypes is Array:
		for archetype in archetypes:
			if not archetype is Dictionary or not archetype.get("layers", {}) is Dictionary:
				continue
			var layers: Dictionary = archetype.get("layers", {})
			for layer_id in layers:
				var layer: Dictionary = layers[layer_id]
				var context: Dictionary = layer.get("visual_context", {})
				if str(layer.get("art_key", context.get("art_key", ""))) == room_id:
					map_id = str(archetype.get("id", "")) + ":" + str(layer_id)
	for map_value in surfaces["maps"]:
		if not map_value is Dictionary or str(map_value.get("id", "")) != map_id:
			continue
		for counter in map_value.get("counters", []):
			if counter is Dictionary and counter.has("foreground_art_id"):
				result[str(counter["foreground_art_id"])] = Rect2(float(counter["x0"]), float(counter["top_y"]), float(counter["x1"]) - float(counter["x0"]), float(counter["front_y"]) - float(counter["top_y"]))
	return result


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func _invalid(reason: String) -> EnvironmentArtPack:
	last_error = reason
	return null


static func _safe_id(value: String) -> bool:
	if value.is_empty():
		return false
	for character in value:
		if not ((character >= "a" and character <= "z") or (character >= "A" and character <= "Z") or (character >= "0" and character <= "9") or character == "_"):
			return false
	return true


static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _positive(value: Variant) -> bool:
	return _number(value) and float(value) > 0.0


static func _integer(value: Variant) -> bool:
	return _number(value) and absf(float(value)) < 9007199254740992.0 and floorf(float(value)) == float(value)


static func _vector_valid(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for component in value:
		if not _number(component):
			return false
	return true


static func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


static func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))


static func _rect_valid(value: Variant) -> bool:
	return _vector_valid(value, 4) and _board_rect_valid(_rect(value))


static func _board_rect_valid(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite() and rect.size.x > 0.0 and rect.size.y > 0.0 and rect.intersects(Rect2(Vector2.ZERO, Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE)))
