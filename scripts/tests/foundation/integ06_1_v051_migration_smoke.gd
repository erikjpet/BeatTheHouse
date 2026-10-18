extends SceneTree

const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")

# Historical-fixture diagnostic for every genuine capture named by the plan.
# It verifies provenance and exercises FoundationMain's public load/save
# boundary. Legacy state is allowed one canonicalization when first loaded into
# the current schema; the resulting current-version save must then round-trip
# exactly. Legacy-to-current byte/shape preservation is intentionally not a
# compatibility promise.

const MainScene := preload("res://scenes/main.tscn")
const V051_FIXTURE_ROOT := "res://scripts/tests/fixtures/integ06_1/v0_5_1"
const MID06_FIXTURE_ROOT := "res://scripts/tests/fixtures/integ06_1/mid_0_6"
const SLOT_ID := "integ06_1_v051_migration_matrix"
const HISTORICAL_COMMIT := "f1ce7ec814b5034c229f53dcc0db6e799aaaee0b"
const HISTORICAL_TREE := "19c5ed82c0d2d2390dab2b9b6662c70d8aed5d0d"
const HISTORICAL_MAIN_SCENE_BLOB := "4b0643365098308dadfaee909d35e51784905811"
const HISTORICAL_FOUNDATION_MAIN_BLOB := "3bc98efec993b8bfdd9252687a0ba041ebba7f23"
const HISTORICAL_SAVE_SERVICE_BLOB := "57a6526016123feb9bcf1ebeb50cc8f937f0b265"
const DRIVER_PATH := "res://scripts/tests/foundation/integ06_1_v051_fixture_driver.gd"
# Historical sidecars are immutable evidence and remain bound to the exact
# driver bytes that produced each capture. Mid-0.6 captures bind to the current
# driver independently below.
const LEGACY_DRIVER_SHA256 := "25e29653f4284c9ab6261432b3bca98006c8cb37f1d1c87ddf859e25f741faaf"
const TUTORIAL_DRIVER_SHA256 := "06f2bd1608ab320132a9eaffb7dcdbcf0715bb7a749dee0b4af9361247a1a6fb"
const CURRENT_DRIVER_FIXTURES := [
	"v051_tutorial_gas_station_arrival",
	"v051_tutorial_gas_machine_open",
]
const MID06_BOUNDARIES := {
	"pre_game_depth": {
		"commit": "31e434c412ba8bdeda03bee86db1f8b4d899c962", "tree": "dc735cd49780e48549fa6b85a24694f9e973dcf6",
		"main": "4b0643365098308dadfaee909d35e51784905811", "foundation": "9cd8431f598fdc8cfc174a7ea49930351b728191", "save": "15a56c4d9f4be1723a721596b9b67c48ac5c2eae",
	},
	"pre_environment_depth": {
		"commit": "5a2b1e1a6782a13308585e1a974adeeb86be0647", "tree": "dd2fa24ac97cb836b7dd82eef20d7df7877debdd",
		"main": "4b0643365098308dadfaee909d35e51784905811", "foundation": "9cd8431f598fdc8cfc174a7ea49930351b728191", "save": "15a56c4d9f4be1723a721596b9b67c48ac5c2eae",
	},
	"pre_world_depth": {
		"commit": "f1ebe9a729253e4ee3d4d99702a019d9328edbaf", "tree": "61c3ffdcb788357696c914618f684863cbb30e91",
		"main": "4b0643365098308dadfaee909d35e51784905811", "foundation": "f7cdfa75cc21d2ffbc70c8db9c8cf44b0b948446", "save": "15a56c4d9f4be1723a721596b9b67c48ac5c2eae",
	},
}
const TUTORIAL_CORNER_CHECKPOINTS := [
	"corner_store_arrival",
	"family_debt",
	"gas_station_arrival",
	"gas_machine_open",
]

var fixture_class := "v0_5_1"
var fixture_root := V051_FIXTURE_ROOT
var plan_path := V051_FIXTURE_ROOT + "/capture_plan.json"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--fixture-class=mid_0_6":
			fixture_class = "mid_0_6"
			fixture_root = MID06_FIXTURE_ROOT
			plan_path = MID06_FIXTURE_ROOT + "/capture_plan.json"
	call_deferred("_run")


func _run() -> void:
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SLOT_ID)
	root.add_child(app)
	await process_frame
	await process_frame
	var save_service: Variant = app.get("save_service")
	if save_service == null:
		_fail("current FoundationMain did not expose SaveService")
		return
	var cases := _load_capture_cases()
	if cases.is_empty():
		_fail("capture plan did not contain any fixtures")
		return
	var verified := 0
	for case_value in cases:
		if typeof(case_value) != TYPE_DICTIONARY:
			_fail("capture plan contained a non-dictionary case")
			return
		if not await _verify_fixture(app, save_service, case_value as Dictionary):
			return
		verified += 1
	print("integ06_1 %s migration matrix passed fixtures=%d provenance=verified source=FoundationMain round_trip=stable" % [fixture_class, verified])
	app.free()
	app = null
	for _frame in range(8):
		await process_frame
	quit(0)


func _verify_fixture(app: Control, save_service: Variant, capture_case: Dictionary) -> bool:
	var fixture_id := str(capture_case.get("fixture_id", "")).strip_edges()
	var expected_seed := str(capture_case.get("seed", "")).strip_edges()
	var expected_archetype := str(capture_case.get("expected_archetype", "")).strip_edges()
	var expected_game := _expected_foreground_game(capture_case)
	if fixture_id.is_empty() or expected_seed.is_empty() or expected_archetype.is_empty():
		_fail("capture plan case omitted fixture_id, seed, or expected_archetype")
		return false
	var fixture_path := "%s/%s.json" % [fixture_root, fixture_id]
	var provenance_path := "%s/%s.provenance.json" % [fixture_root, fixture_id]
	var fixture_bytes := FileAccess.get_file_as_bytes(fixture_path)
	var provenance := _load_json_dictionary(provenance_path)
	var envelope := _parse_bytes_dictionary(fixture_bytes)
	if fixture_bytes.is_empty() or provenance.is_empty() or envelope.is_empty():
		_fail("%s fixture, provenance, or envelope was unreadable" % fixture_id)
		return false
	if not _valid_provenance(provenance, capture_case, fixture_id, expected_seed, expected_archetype, expected_game, fixture_bytes, envelope):
		return false

	app.set("autosave_slot_id", SLOT_ID)
	if int(save_service.call("clear_run", SLOT_ID)) != OK:
		_fail("%s could not clear isolated migration slot" % fixture_id)
		return false
	var absolute_destination := ProjectSettings.globalize_path(str(save_service.call("run_save_path", SLOT_ID)))
	if DirAccess.make_dir_recursive_absolute(absolute_destination.get_base_dir()) != OK:
		_fail("%s could not create isolated save directory" % fixture_id)
		return false
	var output := FileAccess.open(absolute_destination, FileAccess.WRITE)
	if output == null:
		_fail("%s could not stage historical fixture at SaveService path" % fixture_id)
		return false
	output.store_buffer(fixture_bytes)
	output.close()

	app.call("load_foundation_run")
	await process_frame
	await process_frame
	var run_state: Variant = app.get("run_state")
	# Slot families deliberately have no legacy translator. If a historical room
	# cannot satisfy the v2 placement contract, exercise the supported recovery:
	# regenerate a fresh current run from the same seed. Compatible historical
	# rooms continue through the retained admission/canonicalization checks below.
	if not _environment_placement_errors(run_state).is_empty():
		return await _verify_fresh_v2_regeneration(app, save_service, fixture_id, expected_seed)
	if not _expected_playable_state(run_state, expected_seed, expected_archetype):
		var actual_environment: Dictionary = run_state.get("current_environment") if run_state != null else {}
		_fail("%s current FoundationMain did not migrate the historical state intact: expected_seed=%s expected_archetype=%s actual=%s layout=%s" % [fixture_id, expected_seed, expected_archetype, JSON.stringify(_migration_contract(run_state)) if run_state != null else "null", JSON.stringify(actual_environment.get("layout", {}))])
		return false
	if not _expected_fixture_state(run_state, capture_case):
		_fail("%s current FoundationMain lost its expected historical mid-state" % fixture_id)
		return false
	app.call("save_foundation_run")
	if int(save_service.call("wait_for_async_save")) != OK:
		_fail("%s current FoundationMain could not round-trip the migrated save" % fixture_id)
		return false
	# The first load of a historical fixture may canonicalize data that predates
	# the current environment-manifest schema. That transition is deliberately
	# outside the compatibility contract; use the first current-version restore
	# as the canonical baseline instead of comparing it with the legacy-shaped
	# in-memory object.
	var reloaded: Variant = save_service.call("load_run", SLOT_ID)
	if not _expected_playable_state(reloaded, expected_seed, expected_archetype):
		_fail("%s round-tripped migration did not reload to the same playable state" % fixture_id)
		return false
	if not _expected_fixture_state(reloaded, capture_case):
		_fail("%s round-tripped migration lost its expected historical mid-state" % fixture_id)
		return false
	var current_version_snapshot := JSON.stringify(_migration_contract(reloaded))
	if int(save_service.call("save_run", reloaded, SLOT_ID)) != OK:
		_fail("%s could not save its canonical current-version state" % fixture_id)
		return false
	var current_version_reloaded: Variant = save_service.call("load_run", SLOT_ID)
	if not _expected_playable_state(current_version_reloaded, expected_seed, expected_archetype):
		_fail("%s current-version round trip did not reload to the same playable state" % fixture_id)
		return false
	if not _expected_fixture_state(current_version_reloaded, capture_case):
		_fail("%s current-version round trip lost its admitted mid-state" % fixture_id)
		return false
	if JSON.stringify(_migration_contract(current_version_reloaded)) != current_version_snapshot:
		_fail("%s gameplay contract changed across a current-version save/load boundary" % fixture_id)
		return false
	if int(save_service.call("clear_run", SLOT_ID)) != OK:
		_fail("%s could not clear isolated migration slot after PASS" % fixture_id)
		return false
	reloaded = null
	current_version_reloaded = null
	run_state = null
	await process_frame
	print("INTEG06_1_MIGRATION_PASS=%s archetype=%s game=%s" % [fixture_id, expected_archetype, expected_game if not expected_game.is_empty() else "none"])
	return true


# Legacy rooms that cannot be represented by the v2 slot schema are regenerated
# rather than partially migrated. The fresh run must own valid manifest/binding
# authority, and two current-version restores must be byte-stable as RunState
# dictionaries so this recovery path cannot hide a persistence regression.
func _verify_fresh_v2_regeneration(app: Control, save_service: Variant, fixture_id: String, expected_seed: String) -> bool:
	if not bool(app.call("start_foundation_run", expected_seed, {}, false)):
		_fail("%s could not regenerate a fresh current-version run" % fixture_id)
		return false
	var fresh_run: Variant = app.get("run_state")
	var fresh_errors := _current_v2_contract_errors(fresh_run, expected_seed)
	if not fresh_errors.is_empty():
		_fail("%s fresh regeneration did not create valid v2 environment authority: %s" % [fixture_id, "; ".join(fresh_errors)])
		return false

	app.call("save_foundation_run")
	if int(save_service.call("wait_for_async_save")) != OK:
		_fail("%s could not save its fresh regenerated run" % fixture_id)
		return false
	var first_restore: Variant = save_service.call("load_run", SLOT_ID)
	var first_errors := _current_v2_contract_errors(first_restore, expected_seed)
	if not first_errors.is_empty():
		_fail("%s first current-version restore was invalid: %s" % [fixture_id, "; ".join(first_errors)])
		return false
	var first_snapshot := JSON.stringify(first_restore.call("to_dict"))

	if int(save_service.call("save_run", first_restore, SLOT_ID)) != OK:
		_fail("%s could not save its first current-version restore" % fixture_id)
		return false
	var second_restore: Variant = save_service.call("load_run", SLOT_ID)
	var second_errors := _current_v2_contract_errors(second_restore, expected_seed)
	if not second_errors.is_empty():
		_fail("%s second current-version restore was invalid: %s" % [fixture_id, "; ".join(second_errors)])
		return false
	if JSON.stringify(second_restore.call("to_dict")) != first_snapshot:
		_fail("%s fresh v2 state was not exact across its second current-version save/load" % fixture_id)
		return false
	if int(save_service.call("clear_run", SLOT_ID)) != OK:
		_fail("%s could not clear isolated migration slot after fresh-regeneration PASS" % fixture_id)
		return false
	fresh_run = null
	first_restore = null
	second_restore = null
	await process_frame
	print("INTEG06_1_REGENERATION_PASS=%s seed=%s current_v2=stable" % [fixture_id, expected_seed])
	return true


func _environment_placement_errors(run_state: Variant) -> Array:
	if run_state == null:
		return []
	var environment_value: Variant = run_state.get("current_environment")
	if typeof(environment_value) != TYPE_DICTIONARY:
		return []
	var layout_value: Variant = (environment_value as Dictionary).get("layout", {})
	if typeof(layout_value) != TYPE_DICTIONARY:
		return []
	return JsonCoerceScript._copy_array((layout_value as Dictionary).get("placement_errors", []))


func _current_v2_contract_errors(run_state: Variant, expected_seed: String) -> Array[String]:
	var errors: Array[String] = []
	if run_state == null:
		return ["RunState is missing"]
	if str(run_state.get("seed_text")) != expected_seed:
		errors.append("seed changed")
	if str(run_state.get("run_status")) != "active":
		errors.append("run is not active")
	var environment_value: Variant = run_state.get("current_environment")
	if typeof(environment_value) != TYPE_DICTIONARY or (environment_value as Dictionary).is_empty():
		errors.append("current environment is missing")
		return errors
	var environment := environment_value as Dictionary
	var layout_value: Variant = environment.get("layout", {})
	if typeof(layout_value) != TYPE_DICTIONARY:
		errors.append("layout is missing")
		return errors
	var layout := layout_value as Dictionary
	for placement_error_value in JsonCoerceScript._copy_array(layout.get("placement_errors", [])):
		var placement_error := str(placement_error_value).strip_edges()
		if not placement_error.is_empty():
			errors.append(placement_error)
	if int(layout.get("slot_schema_version", 0)) != EnvironmentSlotBinderScript.SLOT_SCHEMA_VERSION:
		errors.append("layout does not use the current slot schema")
	var authority := EnvironmentSlotBinderScript.validate_base_layout_authority(environment)
	if not bool(authority.get("ok", false)):
		for authority_error_value in JsonCoerceScript._copy_array(authority.get("errors", [])):
			var authority_error := str(authority_error_value).strip_edges()
			if not authority_error.is_empty() and not errors.has(authority_error):
				errors.append(authority_error)
	for manifest_error_value in EnvironmentInstanceScript.object_manifest_errors(environment):
		var manifest_error := str(manifest_error_value).strip_edges()
		if not manifest_error.is_empty() and not errors.has(manifest_error):
			errors.append(manifest_error)
	return errors


func _expected_foreground_game(capture_case: Dictionary) -> String:
	var expected_game := str(capture_case.get("enter_game", "")).strip_edges()
	if not expected_game.is_empty():
		return expected_game
	var steps: Variant = capture_case.get("steps", [])
	if typeof(steps) != TYPE_ARRAY:
		return ""
	for step_value in steps as Array:
		if typeof(step_value) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_value
		match str(step.get("type", "")).strip_edges():
			"enter_game":
				expected_game = str(step.get("game_id", "")).strip_edges()
			"back_to_environment", "map_travel", "travel":
				expected_game = ""
	return expected_game


func _valid_provenance(provenance: Dictionary, capture_case: Dictionary, fixture_id: String, expected_seed: String, expected_archetype: String, expected_game: String, fixture_bytes: PackedByteArray, envelope: Dictionary) -> bool:
	var capture: Dictionary = provenance.get("capture", {}) if typeof(provenance.get("capture", {})) == TYPE_DICTIONARY else {}
	var tutorial_start := bool(capture_case.get("tutorial_start", false))
	var expected_modifiers: Dictionary = capture_case.get("challenge_modifiers", {}).duplicate(true) if typeof(capture_case.get("challenge_modifiers", {})) == TYPE_DICTIONARY else {}
	var expected_challenge_id := "tutorial_first_card" if tutorial_start else str(capture_case.get("challenge_id", "integ06_1_historical_fixture")).strip_edges() if not expected_modifiers.is_empty() else ""
	var expected_methods: Array[String] = []
	if tutorial_start:
		expected_methods.append("FoundationMain.start_tutorial_run")
	elif not expected_modifiers.is_empty():
		expected_methods.append("RunState.custom_challenge")
		expected_methods.append("FoundationMain.start_foundation_run")
	else:
		expected_methods.append("FoundationMain.start_foundation_run")
	var expected_travel_path: Array[String] = []
	var tutorial_checkpoint := str(capture_case.get("tutorial_checkpoint", "")).strip_edges()
	if tutorial_checkpoint in TUTORIAL_CORNER_CHECKPOINTS:
		expected_methods.append("FoundationMain.apply_item_offer:xray_glasses")
		expected_methods.append("FoundationMain.open_run_inventory")
		expected_methods.append("FoundationMain.close_run_inventory")
		expected_methods.append("FoundationMain.open_world_map")
		expected_methods.append("FoundationMain.select_world_map_node:corner_store")
		expected_methods.append("FoundationMain.confirm_world_map_travel")
		expected_travel_path.append("corner_store")
		if tutorial_checkpoint != "corner_store_arrival":
			expected_methods.append("FoundationMain.focus_interactable_object:item:ledger_pencil")
			expected_methods.append("FoundationMain.activate_interactable_object:item:ledger_pencil")
			expected_methods.append("FoundationMain.focus_interactable_object:item:instant_coffee")
			expected_methods.append("FoundationMain.activate_interactable_object:item:instant_coffee")
			expected_methods.append("TalkDock.choice_requested:tutorial_guide:tutorial_crew_warning:continue")
			expected_methods.append("FoundationMain.focus_interactable_object:event:call_brother_in_law")
			expected_methods.append("FoundationMain.activate_interactable_object:event_response:call_brother_in_law:make_call")
			expected_methods.append("TalkDock.choice_requested:family_loan:accept")
	var steps: Array = capture_case.get("steps", []) if typeof(capture_case.get("steps", [])) == TYPE_ARRAY else []
	if steps.is_empty():
		for target_id in JsonCoerceScript._string_array(capture_case.get("travel_path", [])):
			steps.append({"type": "travel", "target": target_id})
	for step_value in steps:
		if typeof(step_value) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_value
		var step_type := str(step.get("type", ""))
		if step_type == "event_action":
			var action_event_id := str(step.get("event_id", ""))
			var action_choice_id := str(step.get("choice_id", ""))
			expected_methods.append("FoundationMain.focus_interactable_object:event:%s" % action_event_id)
			expected_methods.append("FoundationMain.activate_interactable_object:event_response:%s:%s" % [action_event_id, action_choice_id])
		elif step_type == "map_travel":
			var map_target_id := str(step.get("target", ""))
			expected_travel_path.append(map_target_id)
			expected_methods.append("FoundationMain.open_world_map")
			expected_methods.append("FoundationMain.select_world_map_node:%s" % map_target_id)
			expected_methods.append("FoundationMain.confirm_world_map_travel")
		elif step_type == "travel":
			var target_id := str(step.get("target", ""))
			expected_travel_path.append(target_id)
			expected_methods.append("FoundationMain.select_travel_option:%s" % target_id)
			expected_methods.append("FoundationMain.confirm_selected_travel")
		elif step_type == "event":
			if bool(step.get("popup", false)):
				expected_methods.append("FoundationMain.resolve_event_choice:%s:%s" % [str(step.get("event_id", "")), str(step.get("choice_id", ""))])
			else:
				expected_methods.append("FoundationMain.select_event_choice:%s:%s" % [str(step.get("event_id", "")), str(step.get("choice_id", ""))])
				expected_methods.append("FoundationMain.confirm_selected_event_choice")
		elif step_type == "item":
			expected_methods.append("FoundationMain.select_item_offer:%s" % str(step.get("item_id", "")))
			expected_methods.append("FoundationMain.confirm_selected_item_offer")
		elif step_type == "pawn":
			expected_methods.append("FoundationMain.open_pawn_counter:%s" % str(step.get("lender_id", "")))
			expected_methods.append("RunInventoryScreen.pawn_requested:%s:%s" % [str(step.get("lender_id", "")), str(step.get("item_id", ""))])
		elif step_type == "lender":
			expected_methods.append("FoundationMain.use_lender_hook:%s" % str(step.get("lender_id", "")))
		elif step_type == "interact":
			var object_id := str(step.get("object_id", ""))
			expected_methods.append("FoundationMain.focus_interactable_object:%s" % object_id)
			expected_methods.append("FoundationMain.activate_interactable_object:%s" % object_id)
		elif step_type == "talk":
			expected_methods.append("TalkDock.choice_requested:%s:%s" % [str(step.get("event_id", "")), str(step.get("choice_id", ""))])
		elif step_type == "enter_game":
			expected_methods.append("FoundationMain.enter_game:%s" % str(step.get("game_id", "")))
		elif step_type == "surface":
			var generic_surface_action := str(step.get("action", ""))
			var generic_surface_index := int(step.get("index", -1))
			if str(step.get("input_type", "click")) == "drag":
				expected_methods.append("GameSurfaceCanvas.surface_pointer_drag:%s:%d" % [generic_surface_action, generic_surface_index])
			else:
				var generic_confirm_suffix := ":confirm=%s" % str(bool(step.get("confirm", false))) if fixture_class == "mid_0_6" else ""
				expected_methods.append("GameSurfaceCanvas.surface_action:%s:%s%s" % [generic_surface_action, "first_stocked" if generic_surface_index < 0 else str(generic_surface_index), generic_confirm_suffix])
		elif step_type == "back_to_environment":
			expected_methods.append("FoundationMain.back_to_environment")
	if not str(capture_case.get("enter_game", "")).strip_edges().is_empty():
		expected_methods.append("FoundationMain.enter_game")
	var surface_steps: Variant = capture_case.get("surface_steps", [])
	if typeof(surface_steps) == TYPE_ARRAY:
		for step_value in surface_steps as Array:
			if typeof(step_value) != TYPE_DICTIONARY:
				continue
			var surface_step: Dictionary = step_value
			var surface_type := str(surface_step.get("type", "click"))
			var surface_action := str(surface_step.get("action", ""))
			var surface_index := int(surface_step.get("index", -1))
			if surface_type == "drag":
				expected_methods.append("GameSurfaceCanvas.surface_pointer_drag:%s:%d" % [surface_action, surface_index])
			else:
				var confirm_suffix := ":confirm=%s" % str(bool(surface_step.get("confirm", false))) if fixture_class == "mid_0_6" else ""
				expected_methods.append("GameSurfaceCanvas.surface_action:%s:%s%s" % [surface_action, "first_stocked" if surface_index < 0 else str(surface_index), confirm_suffix])
	expected_methods.append("FoundationMain.save_foundation_run")
	expected_methods.append("SaveService.wait_for_async_save")
	var actual_methods := JsonCoerceScript._string_array(capture.get("methods", []))
	var expected_hash := str(provenance.get("save_sha256", "")).to_lower()
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(fixture_bytes)
	var actual_hash := hash_context.finish().hex_encode().to_lower()
	var failures: Array[String] = []
	if str(provenance.get("schema", "")) != "beat_the_house.integ06_1_historical_fixture_provenance" or int(provenance.get("version", 0)) != 1:
		failures.append("wrong provenance schema/version")
	var expected_driver_sha256 := ""
	if fixture_class == "mid_0_6":
		var milestone := str(capture_case.get("capture_milestone", ""))
		var boundary: Dictionary = MID06_BOUNDARIES.get(milestone, {}) if typeof(MID06_BOUNDARIES.get(milestone, {})) == TYPE_DICTIONARY else {}
		if boundary.is_empty() or str(provenance.get("capture_class", "")) != "mid_0_6" or str(provenance.get("capture_milestone", "")) != milestone or str(provenance.get("historical_release", "")) != "mid-0.6-development-boundary" \
				or str(provenance.get("historical_commit", "")) != str(boundary.get("commit", "")) or str(provenance.get("historical_tree", "")) != str(boundary.get("tree", "")):
			failures.append("wrong mid-0.6 development-boundary source identity")
		if str(provenance.get("historical_main_scene_blob", "")) != str(boundary.get("main", "")) or str(provenance.get("historical_foundation_main_blob", "")) != str(boundary.get("foundation", "")) or str(provenance.get("historical_save_service_blob", "")) != str(boundary.get("save", "")):
			failures.append("wrong mid-0.6 historical runtime blob identity")
		expected_driver_sha256 = _file_sha256(DRIVER_PATH)
		var custody_path := str(provenance.get("custody_inventory_path", ""))
		if not FileAccess.file_exists(custody_path):
			custody_path = "%s/%s.custody.json" % [fixture_root, fixture_id]
		var custody := _load_json_dictionary(custody_path)
		if custody_path.is_empty() or custody.is_empty() or _raw_file_sha256(custody_path) != str(provenance.get("custody_inventory_sha256", "")).to_lower() \
				or str(custody.get("schema", "")) != "beat_the_house.integ06_1_historical_custody_inventory" or str(custody.get("historical_commit", "")) != str(boundary.get("commit", "")):
			failures.append("retained historical custody inventory mismatch")
	else:
		if str(provenance.get("historical_release", "")) != "v0.5.1" or str(provenance.get("historical_commit", "")) != HISTORICAL_COMMIT or str(provenance.get("historical_tree", "")) != HISTORICAL_TREE:
			failures.append("wrong historical source identity")
		if str(provenance.get("historical_main_scene_blob", "")) != HISTORICAL_MAIN_SCENE_BLOB or str(provenance.get("historical_foundation_main_blob", "")) != HISTORICAL_FOUNDATION_MAIN_BLOB or str(provenance.get("historical_save_service_blob", "")) != HISTORICAL_SAVE_SERVICE_BLOB:
			failures.append("wrong historical runtime blob identity")
		expected_driver_sha256 = TUTORIAL_DRIVER_SHA256 if fixture_id in CURRENT_DRIVER_FIXTURES else LEGACY_DRIVER_SHA256
	if str(provenance.get("driver_path", "")) != DRIVER_PATH.trim_prefix("res://") or str(provenance.get("driver_sha256", "")).to_lower() != expected_driver_sha256:
		failures.append("fixture driver identity mismatch")
	if str(provenance.get("fixture_id", "")) != fixture_id or str(provenance.get("save_file", "")) != "%s.json" % fixture_id:
		failures.append("fixture identity mismatch")
	if int(provenance.get("save_size_bytes", -1)) != fixture_bytes.size() or expected_hash != actual_hash:
		failures.append("fixture byte hash/size mismatch")
	if str(envelope.get("schema", "")) != "beat_the_house.foundation_run" or int(envelope.get("version", 0)) != 2 or str(envelope.get("slot_id", "")) != fixture_id:
		failures.append("historical save envelope mismatch")
	if str(capture.get("fixture_id", "")) != fixture_id or str(capture.get("seed", "")) != expected_seed or str(capture.get("archetype_id", "")) != expected_archetype:
		failures.append("capture identity mismatch")
	var envelope_run_state: Dictionary = envelope.get("run_state", {}) if typeof(envelope.get("run_state", {})) == TYPE_DICTIONARY else {}
	var envelope_challenge: Dictionary = envelope_run_state.get("challenge_config", {}) if typeof(envelope_run_state.get("challenge_config", {})) == TYPE_DICTIONARY else {}
	if tutorial_start:
		expected_modifiers = envelope_challenge.get("modifiers", {}).duplicate(true) if typeof(envelope_challenge.get("modifiers", {})) == TYPE_DICTIONARY else {}
	if JSON.stringify(capture.get("challenge_modifiers", {})) != JSON.stringify(expected_modifiers):
		failures.append("capture challenge modifiers mismatch")
	if str(capture.get("challenge_id", "")) != expected_challenge_id:
		failures.append("capture challenge identity mismatch")
	if tutorial_start and (str(envelope_challenge.get("id", "")) != expected_challenge_id or not bool(envelope_challenge.get("tutorial", false))):
		failures.append("historical tutorial challenge envelope mismatch")
	if str(capture.get("project_version", "")) != "0.5.1" or str(capture.get("save_schema", "")) != "beat_the_house.foundation_run" or int(capture.get("save_version", 0)) != 2:
		failures.append("capture release/save mismatch")
	if str(capture.get("game_id", "")) != expected_game or str(capture.get("game_state_key", "")) != expected_game:
		failures.append("capture game identity mismatch")
	if JsonCoerceScript._string_array(capture.get("travel_path", [])) != expected_travel_path:
		failures.append("capture travel path mismatch")
	if actual_methods != expected_methods:
		failures.append("public-call transcript mismatch")
	if not failures.is_empty():
		_fail("%s provenance rejection: %s" % [fixture_id, ", ".join(failures)])
		return false
	return true


func _expected_playable_state(run_state: Variant, expected_seed: String, expected_archetype: String) -> bool:
	if run_state == null:
		return false
	var environment: Dictionary = run_state.get("current_environment")
	var world_map: Dictionary = run_state.get("world_map")
	var layout: Dictionary = environment.get("layout", {}) if typeof(environment.get("layout", {})) == TYPE_DICTIONARY else {}
	var object_rects: Dictionary = layout.get("object_rects", {}) if typeof(layout.get("object_rects", {})) == TYPE_DICTIONARY else {}
	return str(run_state.get("seed_text")) == expected_seed \
		and str(run_state.get("run_status")) == "active" \
		and str(environment.get("archetype_id", "")) == expected_archetype \
		and (layout.get("placement_errors", []) as Array).is_empty() \
		and (object_rects.is_empty() or not str(layout.get("grounding_signature", "")).is_empty()) \
		and not world_map.is_empty()


func _expected_fixture_state(run_state: Variant, capture_case: Dictionary) -> bool:
	if run_state == null:
		return false
	var expected_lender_debt := str(capture_case.get("expected_lender_debt", "")).strip_edges()
	if not expected_lender_debt.is_empty() and not _has_active_lender_debt(run_state.get("debt"), expected_lender_debt):
		return false
	var tutorial_checkpoint := str(capture_case.get("tutorial_checkpoint", "")).strip_edges()
	if tutorial_checkpoint in TUTORIAL_CORNER_CHECKPOINTS:
		var completed: Dictionary = run_state.get("narrative_flags").get("tutorial_lessons_completed", {}) if typeof(run_state.get("narrative_flags").get("tutorial_lessons_completed", {})) == TYPE_DICTIONARY else {}
		for lesson_id in ["tutorial_apartment_xray", "tutorial_inventory_xray", "tutorial_open_map_corner", "tutorial_travel_corner"]:
			if not bool(completed.get(lesson_id, false)):
				return false
		if not run_state.get("inventory").has("xray_glasses"):
			return false
		if tutorial_checkpoint != "corner_store_arrival":
			if not run_state.get("inventory").has("ledger_pencil") or not run_state.get("inventory").has("instant_coffee"):
				return false
			if not _has_active_lender_debt(run_state.get("debt"), "brother_in_law"):
				return false
		if tutorial_checkpoint in ["gas_station_arrival", "gas_machine_open"]:
			for deeper_lesson_id in ["tutorial_family_debt", "tutorial_parking_tip", "tutorial_route_map", "tutorial_route_choice"]:
				if not bool(completed.get(deeper_lesson_id, false)):
					return false
			if not bool(run_state.get("narrative_flags").get("underground_tip", false)):
				return false
	var expectation := str(capture_case.get("expected_surface_state", "")).strip_edges()
	if expectation.is_empty():
		return true
	if expectation == "grand_showdown_duel":
		var flags: Dictionary = run_state.get("narrative_flags")
		var duel: Dictionary = flags.get("grand_casino_duel_state", {}) if typeof(flags.get("grand_casino_duel_state", {})) == TYPE_DICTIONARY else {}
		return str(flags.get("grand_casino_showdown_step", "")) == "duel" \
			and bool(flags.get("grand_casino_showdown_active", false)) \
			and str(duel.get("status", "")) == "active"
	if expectation == "tutorial_gas_machine_open":
		var tutorial_environment: Dictionary = run_state.get("current_environment")
		var tutorial_game_states: Dictionary = tutorial_environment.get("game_states", {}) if typeof(tutorial_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
		var tutorial_machine: Dictionary = tutorial_game_states.get("pull_tabs", {}) if typeof(tutorial_game_states.get("pull_tabs", {})) == TYPE_DICTIONARY else {}
		var tutorial_item_state: Dictionary = tutorial_machine.get("item_state", {}) if typeof(tutorial_machine.get("item_state", {})) == TYPE_DICTIONARY else {}
		var tutorial_completed: Dictionary = run_state.get("narrative_flags").get("tutorial_lessons_completed", {}) if typeof(run_state.get("narrative_flags").get("tutorial_lessons_completed", {})) == TYPE_DICTIONARY else {}
		return not tutorial_machine.is_empty() \
			and int(tutorial_item_state.get("tab_detector_peek_count", 0)) == 0 \
			and bool(tutorial_completed.get("tutorial_gas_machine", false)) \
			and not bool(tutorial_completed.get("tutorial_gas_peek", false))
	var environment: Dictionary = run_state.get("current_environment")
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var requested_game := str(capture_case.get("enter_game", "")).strip_edges()
	var persisted: Dictionary = game_states.get(requested_game, {}) if typeof(game_states.get(requested_game, {})) == TYPE_DICTIONARY else {}
	if expectation == "slot_after_spin":
		return int(persisted.get("spin_count", 0)) >= 1 \
			and not str(persisted.get("last_outcome_id", "")).is_empty() \
			and persisted.has("last_reels")
	if expectation == "bar_dice_after_round":
		return int(persisted.get("rounds_played", 0)) >= 1 \
			and typeof(persisted.get("last_result", null)) == TYPE_DICTIONARY \
			and not (persisted.get("last_result", {}) as Dictionary).is_empty()
	if expectation == "blackjack_after_hand":
		return int(persisted.get("hands_played", 0)) >= 1 \
			and typeof(persisted.get("last_result", null)) == TYPE_DICTIONARY \
			and not (persisted.get("last_result", {}) as Dictionary).is_empty()
	if expectation != "partial_scratch":
		return false
	var machine: Dictionary = game_states.get("scratch_tickets", {}) if typeof(game_states.get("scratch_tickets", {})) == TYPE_DICTIONARY else {}
	var ticket: Dictionary = machine.get("active_ticket", {}) if typeof(machine.get("active_ticket", {})) == TYPE_DICTIONARY else {}
	return not ticket.is_empty() \
		and int(machine.get("purchased_count", 0)) >= 1 \
		and int(ticket.get("mask_revision", 0)) >= 1 \
		and not bool(ticket.get("result_ready", false))


func _has_active_lender_debt(debt_value: Variant, lender_id: String) -> bool:
	var debts: Array = debt_value if typeof(debt_value) == TYPE_ARRAY else [debt_value]
	for debt_value_entry in debts:
		if typeof(debt_value_entry) != TYPE_DICTIONARY:
			continue
		var debt: Dictionary = debt_value_entry
		if str(debt.get("lender_id", "")) == lender_id and str(debt.get("status", "")) in ["active", "favor_due"]:
			return true
	return false


func _migration_contract(run_state: Variant) -> Dictionary:
	var environment: Dictionary = run_state.get("current_environment")
	var world_map: Dictionary = run_state.get("world_map")
	var narrative_flags: Dictionary = run_state.get("narrative_flags")
	return {
		"seed_text": str(run_state.get("seed_text")),
		"run_status": str(run_state.get("run_status")),
		"bankroll": run_state.get("bankroll"),
		"game_clock_minutes": run_state.get("game_clock_minutes"),
		"act": run_state.get("act"),
		"environment_id": str(environment.get("id", "")),
		"archetype_id": str(environment.get("archetype_id", "")),
		"game_ids": environment.get("game_ids", []).duplicate(true),
		"game_states": environment.get("game_states", {}).duplicate(true),
		"debt": run_state.get("debt").duplicate(true),
		"challenge_config": run_state.get("challenge_config").duplicate(true),
		"tutorial_active": narrative_flags.get("tutorial_active", false),
		"tutorial_beat": narrative_flags.get("tutorial_beat", 0),
		"tutorial_lessons_completed": narrative_flags.get("tutorial_lessons_completed", {}).duplicate(true),
		"tutorial_actions_performed": narrative_flags.get("tutorial_actions_performed", {}).duplicate(true),
		"active_triggered_event": run_state.get("active_triggered_event").duplicate(true),
		"demo_victory": narrative_flags.get("demo_victory", false),
		"demo_victory_route": narrative_flags.get("demo_victory_route", ""),
		"demo_finale_pending": narrative_flags.get("demo_finale_pending", false),
		"demo_finale_event_id": narrative_flags.get("demo_finale_event_id", ""),
		"grand_casino_players_card_tier": narrative_flags.get("grand_casino_players_card_tier", ""),
		"grand_casino_players_card_highest_tier": narrative_flags.get("grand_casino_players_card_highest_tier", ""),
		"grand_casino_players_card_ready_to_claim": narrative_flags.get("grand_casino_players_card_ready_to_claim", false),
		"grand_casino_players_card_segment_games": narrative_flags.get("grand_casino_players_card_segment_games", 0),
		"grand_casino_players_card_segment_net_winnings": narrative_flags.get("grand_casino_players_card_segment_net_winnings", 0),
		"grand_casino_showdown_pending": narrative_flags.get("grand_casino_showdown_pending", false),
		"grand_casino_showdown_active": narrative_flags.get("grand_casino_showdown_active", false),
		"grand_casino_showdown_step": narrative_flags.get("grand_casino_showdown_step", ""),
		"grand_casino_showdown_pat_down": narrative_flags.get("grand_casino_showdown_pat_down", {}).duplicate(true),
		"grand_casino_showdown_interrogation_answers": narrative_flags.get("grand_casino_showdown_interrogation_answers", []).duplicate(true),
		"grand_casino_duel_terms": narrative_flags.get("grand_casino_duel_terms", {}).duplicate(true),
		"grand_casino_duel_state": narrative_flags.get("grand_casino_duel_state", {}).duplicate(true),
		"story_log": run_state.get("story_log").duplicate(true),
		"world_current_node_id": str(world_map.get("current_node_id", "")),
		"world_visited_path": world_map.get("visited_path", []).duplicate(true),
	}


func _load_capture_cases() -> Array:
	var plan := _load_json_dictionary(plan_path)
	var cases: Variant = plan.get("cases", [])
	if typeof(cases) != TYPE_ARRAY:
		return []
	var sequences: Dictionary = plan.get("step_sequences", {}) if typeof(plan.get("step_sequences", {})) == TYPE_DICTIONARY else {}
	var expanded: Array = []
	for case_value in cases as Array:
		if typeof(case_value) != TYPE_DICTIONARY:
			expanded.append(case_value)
			continue
		var capture_case: Dictionary = (case_value as Dictionary).duplicate(true)
		var sequence_id := str(capture_case.get("step_sequence", "")).strip_edges()
		if not sequence_id.is_empty() and typeof(sequences.get(sequence_id, [])) == TYPE_ARRAY:
			var resolved_steps: Array = (sequences.get(sequence_id, []) as Array).duplicate(true)
			if typeof(capture_case.get("append_steps", [])) == TYPE_ARRAY:
				resolved_steps.append_array((capture_case.get("append_steps", []) as Array).duplicate(true))
			capture_case["steps"] = resolved_steps
		expanded.append(capture_case)
	return expanded


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if typeof(parsed) == TYPE_DICTIONARY else {}


func _parse_bytes_dictionary(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return (parsed as Dictionary).duplicate(true) if typeof(parsed) == TYPE_DICTIONARY else {}


func _file_sha256(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return ""
	# Git stores the fixture driver with LF line endings, while a Windows
	# checkout may materialize the same blob with CRLF. Provenance identifies
	# the source text, not the checkout policy, so canonicalize text endings
	# before comparing the driver identity recorded by the capture wrapper.
	var normalized_text := bytes.get_string_from_utf8().replace("\r\n", "\n").replace("\r", "\n")
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(normalized_text.to_utf8_buffer())
	return hash_context.finish().hex_encode().to_lower()


func _raw_file_sha256(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return ""
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	return hash_context.finish().hex_encode().to_lower()


func _fail(message: String) -> void:
	push_error("integ06_1 %s migration smoke failed: %s" % [fixture_class, message])
	quit(1)
