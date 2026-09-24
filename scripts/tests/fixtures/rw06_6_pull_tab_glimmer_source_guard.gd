extends SceneTree

const PULL_TABS_SCRIPT_PATH := "res://scripts/games/pull_tabs.gd"
const REQUIRED_CONSTANT_LINES := [
	"const PULL_TAB_GLIMMER_MIN_INTERVAL_MSEC := 25000",
	"const PULL_TAB_GLIMMER_MAX_INTERVAL_MSEC := 35000",
	"const PULL_TAB_GLIMMER_VISIBLE_MSEC := 1100",
	"const PULL_TAB_GLIMMER_CANDIDATE_LIMIT := 16",
]
const REQUIRED_FUNCTION_SIGNATURES := {
	"surface_state": "func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:",
	"surface_auto_action_command": "func surface_auto_action_command(ui_state: Dictionary, _run_state: RunState, environment: Dictionary, _surface_status: Dictionary = {}) -> Dictionary:",
	"_pull_tab_glimmer_auto_command": "func _pull_tab_glimmer_auto_command(ui_state: Dictionary, run_state: RunState, environment: Dictionary, machine: Dictionary, surface_time: int) -> Dictionary:",
	"_pull_tab_glimmer_candidate_pool": "func _pull_tab_glimmer_candidate_pool(machine: Dictionary) -> Array:",
	"_pull_tab_glimmer_public_projection": "func _pull_tab_glimmer_public_projection(machine: Dictionary, environment: Dictionary, ui_state: Dictionary) -> Dictionary:",
}
const REQUIRED_FUNCTION_SEAMS := {
	"surface_state": [
		"var glimmer_projection := _pull_tab_glimmer_public_projection(machine, environment, ui_state)",
		"\"pull_tab_glimmer\": glimmer_projection",
	],
	"surface_auto_action_command": [
		"var glimmer_command := _pull_tab_glimmer_auto_command(ui_state, _run_state, environment, machine, glimmer_surface_time)",
		"if bool(glimmer_command.get(\"handled\", false)):",
		"return glimmer_command",
	],
	"_pull_tab_glimmer_auto_command": [
		"_pull_tab_glimmer_target = _pull_tab_glimmer_choose_target(candidates, run_state, environment, machine, event_ordinal)",
		"event_state[\"pull_tab_glimmer_hide_due_msec\"] = surface_time + PULL_TAB_GLIMMER_VISIBLE_MSEC",
	],
	"_pull_tab_glimmer_candidate_pool": [
		"candidates.sort_custom(",
		"if candidates.size() > PULL_TAB_GLIMMER_CANDIDATE_LIMIT:",
		"candidates.resize(PULL_TAB_GLIMMER_CANDIDATE_LIMIT)",
	],
	"_pull_tab_glimmer_public_projection": [
		"var hidden := {\"visible\": false, \"deal_index\": -1, \"offset\": -1}",
		"if _pull_tab_glimmer_target_machine_fingerprint != _pull_tab_glimmer_machine_fingerprint(machine, environment):",
		"if int(sleeve[offset]) != prize_index:",
		"return {\"visible\": true, \"deal_index\": deal_index, \"offset\": offset}",
	],
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not FileAccess.file_exists(PULL_TABS_SCRIPT_PATH):
		printerr("RW06_6_GUARD_INFRA_FAILURE: pull-tabs production source is missing.")
		quit(2)
		return
	var pull_tabs_source := FileAccess.get_file_as_string(PULL_TABS_SCRIPT_PATH)
	if pull_tabs_source.is_empty():
		printerr("RW06_6_GUARD_INFRA_FAILURE: pull-tabs production source is empty or unreadable.")
		quit(2)
		return
	var failures := _source_contract_failures(pull_tabs_source)
	if not failures.is_empty():
		print("RW06_6_PRODUCT_RED: %s" % JSON.stringify(failures))
		quit(10)
		return
	print("RW06_6_GUARD_PASS")
	quit(0)


func _source_contract_failures(source: String) -> Array[String]:
	var failures: Array[String] = []
	for constant_line in REQUIRED_CONSTANT_LINES:
		if not _has_exact_top_level_line(source, str(constant_line)):
			failures.append("missing exact constant: %s" % constant_line)
	for function_name_value in REQUIRED_FUNCTION_SIGNATURES:
		var function_name := str(function_name_value)
		var signature := str(REQUIRED_FUNCTION_SIGNATURES[function_name])
		var body := _top_level_function_body(source, signature)
		if body.is_empty():
			failures.append("missing exact function definition: %s" % function_name)
			continue
		for seam_value in REQUIRED_FUNCTION_SEAMS.get(function_name, []):
			var seam := str(seam_value)
			if not body.contains(seam):
				failures.append("missing %s seam: %s" % [function_name, seam])
	return failures


func _has_exact_top_level_line(source: String, required_line: String) -> bool:
	for line in source.split("\n"):
		if str(line).trim_suffix("\r") == required_line:
			return true
	return false


func _top_level_function_body(source: String, signature: String) -> String:
	var lines := source.split("\n")
	var start_index := -1
	for index in range(lines.size()):
		if str(lines[index]).trim_suffix("\r") == signature:
			start_index = index
			break
	if start_index < 0:
		return ""
	var body_lines: Array[String] = []
	for index in range(start_index + 1, lines.size()):
		var line := str(lines[index]).trim_suffix("\r")
		if line.begins_with("func "):
			break
		body_lines.append(line)
	return "\n".join(body_lines)
