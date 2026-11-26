class_name GameModuleRegistry
extends RefCounted

# Shared game-module script authority. Capability metadata is deliberately read
# from validated definitions before a heavyweight game instance is considered.

const SCRIPT_CACHE_MAX_ENTRIES := 32
# Travel and the room catalog need seeded game data, not the cabinet renderer
# or action code. Only these exact authored modules share a smaller room base.
const ROOM_SOURCE_PATHS := {
	"res://scripts/games/video_poker.gd": "res://scripts/games/video_poker_room_source.gd",
	"res://scripts/games/scratch_tickets.gd": "res://scripts/games/scratch_ticket_room_game.gd",
	"res://scripts/games/pull_tabs.gd": "res://scripts/games/pull_tab_room_game.gd",
}

static var _script_cache: Dictionary = {}


static func definition_declares_recovery_hook(definition: Dictionary) -> bool:
	return bool(definition.get("declares_recovery_hook", false))


static func definition_defers_bankroll_zero(definition: Dictionary) -> bool:
	return bool(definition.get("defers_bankroll_zero", false))


static func cache_script(module_path: String, module_script: Script) -> void:
	module_path = module_path.strip_edges()
	if _valid_module_path(module_path) and module_script != null:
		if not _script_cache.has(module_path) and _script_cache.size() >= SCRIPT_CACHE_MAX_ENTRIES:
			_script_cache.clear()
		_script_cache[module_path] = module_script


static func script_for_definition(definition: Dictionary) -> Script:
	return _load_script(str(definition.get("module_path", "")).strip_edges())


static func _load_script(module_path: String) -> Script:
	if not _valid_module_path(module_path):
		return null
	var module_script: Script = _script_cache.get(module_path) as Script
	if module_script == null:
		module_script = load(module_path) as Script
		cache_script(module_path, module_script)
	return module_script


static func create_module(definition: Dictionary, library: ContentLibrary) -> GameModule:
	return _instantiate(script_for_definition(definition), definition, library)


static func room_source_path(definition: Dictionary) -> String:
	return str(ROOM_SOURCE_PATHS.get(str(definition.get("module_path", "")).strip_edges(), ""))


static func create_room_source(definition: Dictionary, library: ContentLibrary) -> GameModule:
	var room_path := room_source_path(definition)
	if room_path.is_empty():
		return create_module(definition, library)
	return _instantiate(_load_script(room_path), definition, library)


static func _instantiate(module_script: Script, definition: Dictionary, library: ContentLibrary) -> GameModule:
	if module_script == null:
		return null
	var module_instance: Variant = module_script.new()
	if not module_instance is GameModule:
		return null
	var game: GameModule = module_instance
	game.setup(definition, library)
	return game


static func _valid_module_path(module_path: String) -> bool:
	return not module_path.is_empty() \
		and not module_path.ends_with("_ui.gd") \
		and not module_path.begins_with("res://data/runtime/")
