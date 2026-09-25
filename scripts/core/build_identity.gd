class_name BuildIdentity
extends RefCounted

const MANIFEST_PATH := "res://build_manifest.json"
const DEVELOPMENT_VERSION := "0.6.0"
const REQUIRED_FIELDS := [
	"build_version",
	"source_commit",
	"source_tree",
	"dirty_state_digest",
	"engine_sha256",
	"export_presets_sha256",
	"platform",
	"native_library_sha256",
]

static var _manifest_loaded := false
static var _manifest_cache: Dictionary = {}


static func manifest() -> Dictionary:
	if _manifest_loaded:
		return _manifest_cache.duplicate(true)
	_manifest_loaded = true
	_manifest_cache = {}
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		_manifest_cache = (parsed as Dictionary).duplicate(true)
	return _manifest_cache.duplicate(true)


static func manifest_is_valid(value: Dictionary = {}) -> bool:
	var candidate := value if not value.is_empty() else manifest()
	if str(candidate.get("schema", "")) != "beat_the_house.build_manifest/v1":
		return false
	for field in REQUIRED_FIELDS:
		if str(candidate.get(field, "")).strip_edges().is_empty():
			return false
	return true


static func display_version() -> String:
	var value := manifest()
	if manifest_is_valid(value):
		return str(value.get("build_version", DEVELOPMENT_VERSION))
	if _distribution_build():
		return "UNBOUND-DISTRIBUTION-BUILD"
	return DEVELOPMENT_VERSION


static func telemetry_identity(runtime_options: Dictionary = {}) -> Dictionary:
	var value := manifest()
	if manifest_is_valid(value):
		# The complete export-tree hash is non-circular evidence computed only
		# after the export exists, so it cannot be embedded in the tree it hashes.
		# Accept only the runner's exact SHA-256 shape when the authoritative
		# embedded manifest has no export hash of its own.
		var export_sha256 := str(value.get("export_identity_sha256", "")).strip_edges()
		if export_sha256.is_empty():
			var runtime_export_sha256 := str(runtime_options.get("bth_perf_export_sha256", "")).strip_edges()
			if runtime_export_sha256.length() == 64 and runtime_export_sha256.is_valid_hex_number(false):
				export_sha256 = runtime_export_sha256.to_lower()
		return {
			"source_commit": str(value.get("source_commit", "")),
			"source_tree": str(value.get("source_tree", "")),
			"dirty_state_digest": str(value.get("dirty_state_digest", "")),
			"export_sha256": export_sha256,
			"build_version": str(value.get("build_version", "")),
			"platform": str(value.get("platform", "")),
			"manifest_schema": str(value.get("schema", "")),
			"identity_source": "embedded_manifest",
		}
	# Source-tree telemetry may still accept an explicit harness identity. A
	# distribution export never does: a missing manifest stays visibly unbound.
	if not _distribution_build():
		return {
			"source_commit": str(runtime_options.get("bth_perf_source_commit", "")),
			"export_sha256": str(runtime_options.get("bth_perf_export_sha256", "")),
			"identity_source": "source_harness",
		}
	return {"source_commit": "", "export_sha256": "", "identity_source": "missing_embedded_manifest"}


static func _distribution_build() -> bool:
	var override := OS.get_environment("BTH_FORCE_DISTRIBUTION_BUILD").strip_edges().to_lower()
	return OS.has_feature("distribution_build") or ["1", "true", "yes", "on"].has(override)


static func reset_cache_for_test() -> void:
	_manifest_loaded = false
	_manifest_cache = {}
