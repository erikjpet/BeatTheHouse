extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const CrewIgnoredGoldenProbeScript := preload("res://scripts/tests/foundation/crew_ignored_golden_probe.gd")
const TARGET := "res://scripts/tests/fixtures/crew06_5_ignored_run_baseline.json"
const EXPECTED_SEEDS := ["CREW-IGNORED-GOLDEN-A", "CREW-IGNORED-GOLDEN-B"]
const EXPECTED_CHECKPOINTS := [
	"initial_bar",
	"bar_action_boundary",
	"ordinary_travel",
	"bar_revisit",
	"save_load_round_trip",
]
const CAPTURE_KEYS := ["schema_version", "runs"]
const RUN_KEYS := ["seed", "checkpoints"]
const CHECKPOINT_KEYS := [
	"label",
	"run_state_bytes",
	"run_state_sha256",
	"current_environment_bytes",
	"current_environment_sha256",
	"world_environments_bytes",
	"world_environments_sha256",
]
const BYTE_FIELDS := ["run_state_bytes", "current_environment_bytes", "world_environments_bytes"]
const SHA_FIELDS := ["run_state_sha256", "current_environment_sha256", "world_environments_sha256"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var argument_failures := _argument_failures()
	if not argument_failures.is_empty():
		_fail(argument_failures)
		return
	var dry_run := OS.get_cmdline_user_args().has("--dry-run")
	var library := ContentLibraryScript.new()
	library.load()
	var existing_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(TARGET))
	if typeof(existing_value) != TYPE_DICTIONARY:
		_fail(["Crew ignored golden fixture is missing or malformed."])
		return

	var failures: Array = []
	for failure_value in CrewIgnoredGoldenProbeScript.ignored_ambient_noop_failures():
		failures.append("Crew-ignored ambient no-op proof failed: %s" % str(failure_value))
	for failure_value in CrewIgnoredGoldenProbeScript.world_sequence_noop_failures(library):
		failures.append("Crew-ignored inactive world-sequence proof failed: %s" % str(failure_value))
	var audited_a := CrewIgnoredGoldenProbeScript.audited_capture(library)
	var audited_b := CrewIgnoredGoldenProbeScript.audited_capture(library)
	var capture_a: Variant = audited_a.get("capture", null)
	var capture_b: Variant = audited_b.get("capture", null)
	for failure_value in audited_a.get("failures", []):
		failures.append("First Crew-ignored capture invariant failed: %s" % str(failure_value))
	for failure_value in audited_b.get("failures", []):
		failures.append("Second Crew-ignored capture invariant failed: %s" % str(failure_value))
	failures.append_array(_capture_validation_failures(capture_a, "first capture"))
	failures.append_array(_capture_validation_failures(capture_b, "second capture"))
	if typeof(capture_a) == TYPE_DICTIONARY and typeof(capture_b) == TYPE_DICTIONARY \
			and JSON.stringify(capture_a) != JSON.stringify(capture_b):
		failures.append("Crew-ignored same-seed captures were not byte-identical.")
	if not failures.is_empty():
		_fail(failures)
		return
	if dry_run:
		var capture_json := JSON.stringify(capture_a)
		print("FIXSWEEP06_1_CREW_GOLDEN_DRY_RUN_PASS bytes=%d sha256=%s" % [capture_json.to_utf8_buffer().size(), capture_json.sha256_text()])
		quit(0)
		return

	var document: Dictionary = (existing_value as Dictionary).duplicate(true)
	document["capture"] = (capture_a as Dictionary).duplicate(true)
	document["baseline_commit"] = "environment-slot-family-manifest-v2"
	var provenance: Dictionary = document.get("provenance", {}) if typeof(document.get("provenance", {})) == TYPE_DICTIONARY else {}
	provenance["change_commit"] = "environment-slot-family-manifest-v2"
	provenance["reason"] = "The completed fixed, event, scenario, and exit migration intentionally adds durable object-manifest ownership and independent coexistence capacity to generated and persisted rooms without changing Crew state."
	provenance["proof"] = "Both fixed Crew-ignored seeds were recaptured through all five production checkpoints after the final slot-family manifest and capacity corrections; the contract still requires exact normalized bytes and hashes, inactive world-sequence no-ops, and zero Crew trust."
	document["provenance"] = provenance
	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not open Crew ignored golden fixture for update.")
		quit(1)
		return
	file.store_string(JSON.stringify(document, "    ") + "\n")
	file.close()
	print("FIXSWEEP06_1_CREW_GOLDEN_UPDATED")
	quit(0)


static func _capture_validation_failures(value: Variant, label: String = "capture") -> Array:
	var failures: Array = []
	if typeof(value) != TYPE_DICTIONARY:
		return ["%s is not a dictionary." % label]
	var capture: Dictionary = value
	if capture.has("harness_failure"):
		failures.append("%s reported harness_failure: %s" % [label, str(capture.get("harness_failure", ""))])
	_append_exact_key_failures(capture, CAPTURE_KEYS, label, failures)
	if typeof(capture.get("schema_version")) != TYPE_INT or int(capture.get("schema_version", -1)) != 1:
		failures.append("%s must have integer schema_version 1." % label)
	var runs_value: Variant = capture.get("runs")
	if typeof(runs_value) != TYPE_ARRAY:
		failures.append("%s runs is not an array." % label)
		return failures
	var runs: Array = runs_value
	if runs.size() != EXPECTED_SEEDS.size():
		failures.append("%s must contain exactly %d runs, found %d." % [label, EXPECTED_SEEDS.size(), runs.size()])
	for run_index in range(runs.size()):
		var run_label := "%s run[%d]" % [label, run_index]
		if typeof(runs[run_index]) != TYPE_DICTIONARY:
			failures.append("%s is not a dictionary." % run_label)
			continue
		var run: Dictionary = runs[run_index]
		_append_exact_key_failures(run, RUN_KEYS, run_label, failures)
		if typeof(run.get("seed")) != TYPE_STRING or run_index >= EXPECTED_SEEDS.size() or str(run.get("seed", "")) != str(EXPECTED_SEEDS[run_index]):
			failures.append("%s has unexpected seed/order %s." % [run_label, str(run.get("seed", ""))])
		var checkpoints_value: Variant = run.get("checkpoints")
		if typeof(checkpoints_value) != TYPE_ARRAY:
			failures.append("%s checkpoints is not an array." % run_label)
			continue
		var checkpoints: Array = checkpoints_value
		if checkpoints.size() != EXPECTED_CHECKPOINTS.size():
			failures.append("%s must contain exactly %d checkpoints, found %d." % [run_label, EXPECTED_CHECKPOINTS.size(), checkpoints.size()])
		for checkpoint_index in range(checkpoints.size()):
			var checkpoint_label := "%s checkpoint[%d]" % [run_label, checkpoint_index]
			if typeof(checkpoints[checkpoint_index]) != TYPE_DICTIONARY:
				failures.append("%s is not a dictionary." % checkpoint_label)
				continue
			var checkpoint: Dictionary = checkpoints[checkpoint_index]
			_append_exact_key_failures(checkpoint, CHECKPOINT_KEYS, checkpoint_label, failures)
			if typeof(checkpoint.get("label")) != TYPE_STRING or checkpoint_index >= EXPECTED_CHECKPOINTS.size() or str(checkpoint.get("label", "")) != str(EXPECTED_CHECKPOINTS[checkpoint_index]):
				failures.append("%s has unexpected label/order %s." % [checkpoint_label, str(checkpoint.get("label", ""))])
			for field in BYTE_FIELDS:
				if typeof(checkpoint.get(field)) != TYPE_INT or int(checkpoint.get(field, 0)) <= 0:
					failures.append("%s field %s must be a positive integer." % [checkpoint_label, field])
			for field in SHA_FIELDS:
				if not _is_lower_sha256(checkpoint.get(field)):
					failures.append("%s field %s must be a lowercase SHA-256." % [checkpoint_label, field])
	return failures


static func _append_exact_key_failures(value: Dictionary, expected_keys: Array, label: String, failures: Array) -> void:
	if value.keys().size() != expected_keys.size():
		failures.append("%s has %d keys; expected exactly %d." % [label, value.keys().size(), expected_keys.size()])
	for expected_key_value in expected_keys:
		var expected_key := str(expected_key_value)
		if not value.has(expected_key):
			failures.append("%s is missing key %s." % [label, expected_key])
	for actual_key_value in value.keys():
		if typeof(actual_key_value) != TYPE_STRING or not expected_keys.has(str(actual_key_value)):
			failures.append("%s has unexpected key %s." % [label, str(actual_key_value)])


static func _is_lower_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var digest := str(value)
	if digest.length() != 64 or digest != digest.to_lower():
		return false
	for index in range(digest.length()):
		if "0123456789abcdef".find(digest.substr(index, 1)) < 0:
			return false
	return true


static func _argument_failures() -> Array:
	var failures: Array = []
	for raw_argument in OS.get_cmdline_user_args():
		if str(raw_argument) != "--dry-run":
			failures.append("Unknown Crew golden updater argument: %s" % str(raw_argument))
	return failures


func _fail(failures: Array) -> void:
	for failure_value in failures:
		push_error(str(failure_value))
	quit(1)
