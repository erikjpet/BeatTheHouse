class_name SupportDiagnostics
extends RefCounted

const BuildIdentityScript := preload("res://scripts/core/build_identity.gd")

# A fresh allowlisted report, never a serialized SaveService outcome/manifest.
static func snapshot(save_outcome: Dictionary, load_outcome: Dictionary, autosave_code: String) -> Dictionary:
	var identity := BuildIdentityScript.telemetry_identity()
	return {
		"schema": "beat_the_house.support_diagnostics/v1",
		"build": {
			"version": _token(BuildIdentityScript.display_version(), true),
			"source_commit": _digest(identity.get("source_commit", ""), 40),
			"source_tree": _digest(identity.get("source_tree", ""), 40),
			"export_sha256": _digest(identity.get("export_sha256", ""), 64),
			"identity_source": _token(identity.get("identity_source", "")),
		},
		"platform": OS.get_name(),
		"last_save": {
			"ok": save_outcome.get("ok", false) == true,
			"error": int(save_outcome.get("error", FAILED)) if typeof(save_outcome.get("error")) == TYPE_INT else FAILED,
			"error_code": _token(save_outcome.get("error_code", "")),
		},
		"last_load": {
			"outcome": _load_status(load_outcome.get("outcome", "")),
			"primary_exists": load_outcome.get("primary_exists", false) == true,
			"primary_loadable": load_outcome.get("primary_loadable", false) == true,
			"backup_exists": load_outcome.get("backup_exists", false) == true,
			"backup_loadable": load_outcome.get("backup_loadable", false) == true,
		},
		"autosave_failure_code": _token(autosave_code),
	}


static func desktop_platform(platform: String) -> bool:
	return platform in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]


static func _load_status(value: Variant) -> String:
	return value if typeof(value) == TYPE_STRING and value in ["loaded-primary", "loaded-backup", "nothing-loadable"] else "unavailable"


static func _digest(value: Variant, length: int) -> String:
	if typeof(value) != TYPE_STRING or value.length() != length or not value.is_valid_hex_number(false):
		return ""
	return value.to_lower()


static func _token(value: Variant, version: bool = false) -> String:
	if typeof(value) != TYPE_STRING or value.length() > 96:
		return "unavailable"
	for index in range(value.length()):
		var code: int = value.unicode_at(index)
		if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code in [45, 95]:
			continue
		if version and code in [43, 46]:
			continue
		return "unavailable"
	return value
