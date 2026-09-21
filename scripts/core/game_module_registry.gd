class_name GameModuleRegistry
extends RefCounted

# Shared game-module script authority. Capability metadata is deliberately read
# from validated definitions before a heavyweight game instance is considered.

const SCRIPT_CACHE_MAX_ENTRIES := 32

static var _script_cache: Dictionary = {}


static func definition_declares_recovery_hook(definition: Dictionary) -> bool:
	return bool(definition.get("declares_recovery_hook", false))


static func definition_defers_bankroll_zero(definition: Dictionary) -> bool:
	return bool(definition.get("defers_bankroll_zero", false))


static func cache_script(module_path: String, module_script: Script) -> void:
	var normalized_path := module_path.strip_edges()
	if _valid_module_path(normalized_path) and module_script != null:
		if not _script_cache.has(normalized_path) and _script_cache.size() >= SCRIPT_CACHE_MAX_ENTRIES:
			_script_cache.clear()
		_script_cache[normalized_path] = module_script


static func script_for_definition(definition: Dictionary) -> Script:
	var module_path := str(definition.get("module_path", "")).strip_edges()
	if not _valid_module_path(module_path):
		return null
	var module_script: Script = _script_cache.get(module_path) as Script
	if module_script == null:
		module_script = load(module_path) as Script
		if module_script != null:
			if not _script_cache.has(module_path) and _script_cache.size() >= SCRIPT_CACHE_MAX_ENTRIES:
				_script_cache.clear()
			_script_cache[module_path] = module_script
	return module_script


static func create_module(definition: Dictionary, library: ContentLibrary) -> GameModule:
	var module_script := script_for_definition(definition)
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
