extends RefCounted

# Test-fixture admission for the current fresh bth_qa_storage.py layout. This
# reads the launcher's receipt and exact environment; it never changes either,
# changes a guard, creates directories or admits an old/resident player profile.
const APPROVED_ROOT := "e:/codexqa/bth"
const LEAVES := ["profile", "temp", "evidence", "appdata", "localappdata", "home", "cache", "save_dir", "pycache"]
const ENV_PATHS := {
	"TEMP": "temp", "TMP": "temp", "TMPDIR": "temp", "APPDATA": "appdata", "LOCALAPPDATA": "localappdata",
	"USERPROFILE": "home", "HOME": "home", "XDG_CACHE_HOME": "cache", "XDG_CONFIG_HOME": "appdata",
	"XDG_DATA_HOME": "localappdata", "XDG_STATE_HOME": "localappdata", "PYTHONPYCACHEPREFIX": "pycache",
	"BTH_QA_WORKSPACE": "workspace", "BTH_QA_PROFILE_DIR": "profile", "BTH_WEB_EVIDENCE_DIR": "evidence",
	"BTH_QA_EVIDENCE_DIR": "evidence", "BTH_SAVE_DIR": "save_dir", "BTH_QA_TEMP_DIR": "temp", "BTH_QA_RUN_DIR": "run_root",
}
const ENV_RELATIVE := {
	"BTH_DISTRIBUTION_DATA_ROOT": ["save_dir", "distribution"],
	"BTH_WORLD_REENTRY_ROOT": ["save_dir", "world-reentry"],
	"BTH_USER_SETTINGS_PATH": ["localappdata", "settings.json"],
	"BTH_PROFILE_INVENTORY_PATH": ["localappdata", "profile-inventory.json"],
	"BTH_META_COLLECTION_PATH": ["localappdata", "meta-collection.json"],
}


static func validate() -> Dictionary:
	var errors: Array[String] = []
	var run_root := _path(OS.get_environment("BTH_QA_RUN_DIR"))
	if not _inside(APPROVED_ROOT.path_join("runs"), run_root):
		return {"ok": false, "errors": ["BTH_QA_RUN_DIR must identify a fresh run under the approved E QA root"]}
	var manifest_path := run_root.path_join("evidence/storage-manifest.json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "errors": ["Prepared fresh QA storage manifest is absent or malformed"]}
	var manifest: Dictionary = parsed
	if str(manifest.get("schema", "")) != "bth-qa-storage/v1" or manifest.get("prepared") != true \
			or str(manifest.get("token", "")).length() < 16 or str(manifest.get("run_id", "")).to_lower() != run_root.get_file() \
			or _path(str(manifest.get("manifest_path", ""))) != manifest_path:
		errors.append("Manifest must identify this exact prepared fresh run")
	var paths: Dictionary = manifest.get("paths", {}) if typeof(manifest.get("paths")) == TYPE_DICTIONARY else {}
	if _path(str(paths.get("root", ""))) != APPROVED_ROOT or _path(str(paths.get("run_root", ""))) != run_root:
		errors.append("Manifest root and run_root differ from the approved fresh layout")
	var workspace := _path(str(paths.get("workspace", "")))
	if not _inside(APPROVED_ROOT.path_join("workspaces"), workspace) \
			or workspace != _path(ProjectSettings.globalize_path("res://")):
		errors.append("Manifest workspace differs from the running E source workspace")
	for leaf in LEAVES:
		if _path(str(paths.get(leaf, ""))) != run_root.path_join(leaf) or not DirAccess.dir_exists_absolute(str(paths.get(leaf, ""))):
			errors.append("Manifest dedicated directory mismatch: " + leaf)
	for key in ENV_PATHS:
		if _path(OS.get_environment(key)) != _path(str(paths.get(ENV_PATHS[key], ""))):
			errors.append("Guarded environment mapping mismatch: " + str(key))
	for key in ENV_RELATIVE:
		var mapping: Array = ENV_RELATIVE[key]
		var expected := _path(str(paths.get(mapping[0], ""))).path_join(str(mapping[1]))
		if _path(OS.get_environment(key)) != expected:
			errors.append("Guarded relative environment mismatch: " + str(key))
	var user_path := _path(ProjectSettings.globalize_path("user://"))
	if not _inside(_path(str(paths.get("appdata", ""))), user_path):
		errors.append("Godot user:// is outside this fresh run's admitted APPDATA")
	if OS.get_environment("PYTHONDONTWRITEBYTECODE") != "1":
		errors.append("Guarded bytecode environment is absent")
	if not OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() or not OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty():
		errors.append("Original captured saves and browser profiles are not admitted")
	var output := _path(OS.get_environment("BTH_TARGET_OUTPUT"))
	if not output.is_empty() and not _inside(_path(str(paths.get("evidence", ""))), output):
		errors.append("BTH_TARGET_OUTPUT must remain within this run's admitted evidence directory")
	return {"ok": errors.is_empty(), "errors": errors, "manifest_path": manifest_path, "paths": paths.duplicate(true), "private_root": OS.get_environment("BTH_WORLD_REENTRY_ROOT")}


static func _path(value: String) -> String:
	if value.strip_edges().is_empty():
		return ""
	return value.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()


static func _inside(parent: String, child: String) -> bool:
	return not parent.is_empty() and not child.is_empty() and child.begins_with(parent.trim_suffix("/") + "/")
