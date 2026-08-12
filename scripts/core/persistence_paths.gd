class_name PersistencePaths
extends RefCounted

# Exported distributions must never share the editor/development save namespace.
# Keep this root stable so saves created by an installed build survive updates.
const DISTRIBUTION_FEATURE := "distribution_build"
const DISTRIBUTION_ROOT := "user://distribution"
const DISTRIBUTION_ROOT_ENV := "BTH_DISTRIBUTION_DATA_ROOT"
const DISTRIBUTION_FEATURE_ENV := "BTH_DISTRIBUTION_BUILD"


static func distribution_build() -> bool:
	var override := OS.get_environment(DISTRIBUTION_FEATURE_ENV).strip_edges().to_lower()
	return OS.has_feature(DISTRIBUTION_FEATURE) or ["1", "true", "yes", "on"].has(override)


static func distribution_root() -> String:
	var override := OS.get_environment(DISTRIBUTION_ROOT_ENV).strip_edges().trim_suffix("/")
	if not override.is_empty():
		return override
	return DISTRIBUTION_ROOT if distribution_build() else ""


static func file_path(development_path: String, file_name: String) -> String:
	var root := distribution_root()
	if root.is_empty():
		return development_path
	return "%s/%s" % [root, file_name.trim_prefix("/")]


static func directory_path(development_path: String, directory_name: String) -> String:
	var root := distribution_root()
	if root.is_empty():
		return development_path
	return "%s/%s" % [root, directory_name.trim_prefix("/")]
