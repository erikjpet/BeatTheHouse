class_name PersistencePaths
extends RefCounted

# Exported distributions must never share the editor/development save namespace.
# Keep this root stable so saves created by an installed build survive updates.
const DISTRIBUTION_FEATURE := "distribution_build"
const DISTRIBUTION_ROOT := "user://distribution"
# Browser storage survives itch upload replacements and is keyed by the page
# origin/project, not by the exported files.  The original distribution root
# therefore exposed 0.6 to saves, home progression, settings, and developer
# placement data left by pre-release web builds.  Keep the current public web
# line in its own epoch: the first launch is clean, while data created by this
# line still persists across ordinary reloads and compatible updates.
const WEB_DISTRIBUTION_ROOT := "user://distribution/web_0_6_1"
const DISTRIBUTION_ROOT_ENV := "BTH_DISTRIBUTION_DATA_ROOT"
const DISTRIBUTION_FEATURE_ENV := "BTH_DISTRIBUTION_BUILD"


static func distribution_build() -> bool:
	var override := OS.get_environment(DISTRIBUTION_FEATURE_ENV).strip_edges().to_lower()
	return OS.has_feature(DISTRIBUTION_FEATURE) or ["1", "true", "yes", "on"].has(override)


static func distribution_root() -> String:
	var override := _normalized_distribution_root(OS.get_environment(DISTRIBUTION_ROOT_ENV))
	if _distribution_root_valid(override):
		return override
	if not distribution_build():
		return ""
	return WEB_DISTRIBUTION_ROOT if OS.has_feature("web") else DISTRIBUTION_ROOT


static func _normalized_distribution_root(value: String) -> String:
	var normalized := value.strip_edges().replace("\\", "/")
	while normalized.ends_with("/") and not normalized.ends_with("://"):
		normalized = normalized.trim_suffix("/")
	return normalized


static func _distribution_root_valid(path: String) -> bool:
	if path.is_empty():
		return false
	for segment in path.split("/", false):
		if segment == "..":
			return false
	return path.begins_with("user://") or path.is_absolute_path()


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
