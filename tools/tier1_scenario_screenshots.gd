extends SceneTree

# Captures two contrasting authored nights per selected archetype in the real app.
# Run windowed so the viewport texture contains the rendered room.

const MainScene := preload("res://scenes/main.tscn")

const TIER1_SMOKE_SCENARIOS := {
	"corner_store": ["corner_store_delivery_day", "corner_store_aftermath"],
	"back_alley": ["back_alley_street_craps", "back_alley_cruiser_parked"],
	"motel": ["motel_conventioneers", "motel_stakeout"],
	"bar": ["bar_wake", "bar_fight_night"],
	"gas_station_casino": ["gas_station_trucker_convoy", "gas_station_graveyard_shift"],
}

const TIER2_SMOKE_SCENARIOS := {
	"small_underground_casino": ["punchline_open_mic_night", "punchline_high_stakes_night"],
	"jazz_club": ["jazz_club_guest_legend", "jazz_club_recording_night"],
	"kitty_cat_lounge": ["kitty_cat_lounge_amateur_night", "kitty_cat_lounge_buyout"],
	"delta_queen": ["delta_queen_wedding_charter", "delta_queen_engine_trouble"],
	"beach": ["beach_bonfire_night", "beach_storm_coming"],
	"pawn_shop": ["pawn_shop_estate_lot_day", "pawn_shop_serial_check_day"],
	"grand_casino": ["grand_casino_gala_night", "grand_casino_audit_night"],
}

var app: Control
var out_dir := "res://.tmp/tier1_scenario_screenshots"
var report: Dictionary = {}
var failed := false
var tier2_mode := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=").strip_edges()
		elif argument == "--tier2":
			tier2_mode = true
			if out_dir == "res://.tmp/tier1_scenario_screenshots":
				out_dir = "res://.tmp/tier2_scenario_screenshots"
	call_deferred("_run")


func _run() -> void:
	var absolute_dir := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	app = MainScene.instantiate()
	root.add_child(app)
	await _settle(4)
	app.call("start_foundation_run", "TIER1-SCENARIO-VISUAL", {})
	await _settle(6)
	var library: Variant = app.get("library")
	var run_state: Variant = app.get("run_state")
	if library == null or run_state == null:
		push_error("Scenario screenshot QA could not start the real app run.")
		quit(1)
		return
	var smoke_scenarios: Dictionary = TIER2_SMOKE_SCENARIOS if tier2_mode else TIER1_SMOKE_SCENARIOS
	for archetype_id_value in smoke_scenarios.keys():
		var archetype_id := str(archetype_id_value)
		for scenario_id_value in smoke_scenarios.get(archetype_id, []):
			await _capture(archetype_id, str(scenario_id_value), library, run_state, absolute_dir)
	var report_path := "%s/report.json" % absolute_dir
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write scenario screenshot report.")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	var suite_label := "TIER2_SCENARIO_SCREENSHOTS" if tier2_mode else "TIER1_SCENARIO_SCREENSHOTS"
	print("%s %s count=%d out=%s" % [suite_label, "FAIL" if failed else "PASS", report.size(), absolute_dir])
	quit(1 if failed else 0)


func _capture(archetype_id: String, scenario_id: String, library: Variant, run_state: Variant, absolute_dir: String) -> void:
	var definition: Dictionary = library.scenario(scenario_id)
	var rng: RngStream = run_state.create_rng("visual:%s" % scenario_id)
	var layer_id := str(definition.get("layer_id", ""))
	var archetype: Dictionary = library.environment_archetype(archetype_id)
	var environment: Variant = EnvironmentInstance.from_archetype_layer(archetype, layer_id, 1, rng, library, {}, definition) if not layer_id.is_empty() else EnvironmentInstance.from_archetype(archetype, 1, rng, library, {}, definition)
	var data: Dictionary = environment.to_dict()
	data["world_node_id"] = archetype_id
	# Match the production RunGenerator boundary: machine state owns dynamic
	# environment hooks, so it must exist before stable object rects are resolved.
	var generator := RunGenerator.new(library)
	data["game_states"] = generator._generated_game_states(run_state, data, rng)
	var layout_stress_fixture := _apply_layout_stress_fixture(data, scenario_id)
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
	run_state.set_environment(data)
	app.call("_clear_selected_game_action")
	app.call("_refresh")
	await _settle(4)
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var file_name := "%s.png" % scenario_id
	var save_error := image.save_png("%s/%s" % [absolute_dir, file_name])
	var canvas: Variant = app.get("environment_canvas")
	var view: Dictionary = canvas.call("current_view_snapshot") if canvas != null else {}
	var presentation: Dictionary = data.get("scenario_presentation", {}) if typeof(data.get("scenario_presentation", {})) == TYPE_DICTIONARY else {}
	var object_layout: Dictionary = view.get("object_layout", {}) if typeof(view.get("object_layout", {})) == TYPE_DICTIONARY else {}
	var overlap_count := int(object_layout.get("overlap_count", 0))
	var capture_ok := save_error == OK \
		and image.get_width() >= 1280 \
		and image.get_height() >= 720 \
		and str(view.get("scenario_signage", "")) == str(presentation.get("signage_line", "")) \
		and bool(view.get("scenario_palette_active", false)) \
		and overlap_count == 0
	if not capture_ok:
		failed = true
		push_error("Scenario screenshot failed presentation/layout QA: %s (overlaps=%d)" % [scenario_id, overlap_count])
	report[scenario_id] = {
		"passed": capture_ok,
		"file": file_name,
		"size": [image.get_width(), image.get_height()],
		"archetype_id": archetype_id,
		"event_ids": data.get("event_ids", []),
		"stake_floor": int((data.get("economic_profile", {}) as Dictionary).get("stake_floor", 0)),
		"stake_ceiling": int((data.get("economic_profile", {}) as Dictionary).get("stake_ceiling", 0)),
		"scenario_presentation": presentation,
		"canvas_scenario_presentation": view.get("scenario_presentation", {}),
		"canvas_object_layout": object_layout,
		"environment_object_rects": ((run_state.current_environment.get("layout", {}) as Dictionary).get("object_rects", {}) as Dictionary).duplicate(true),
		"layout_stress_fixture": layout_stress_fixture,
	}


# Keeps one valid, reachable late-hook state in the visual matrix. Empty scratch
# machines always spawn the Scalper, which previously exposed a fallback-layout
# overlap that the screenshot harness silently ignored.
func _apply_layout_stress_fixture(data: Dictionary, scenario_id: String) -> String:
	if scenario_id != "gas_station_graveyard_shift":
		return ""
	var states: Dictionary = data.get("game_states", {}) if typeof(data.get("game_states", {})) == TYPE_DICTIONARY else {}
	var scratch_state: Dictionary = states.get("scratch_tickets", {}) if typeof(states.get("scratch_tickets", {})) == TYPE_DICTIONARY else {}
	if scratch_state.is_empty():
		return ""
	var stock: Array = scratch_state.get("stock", []) if typeof(scratch_state.get("stock", [])) == TYPE_ARRAY else []
	for slot_value in stock:
		if typeof(slot_value) == TYPE_DICTIONARY:
			(slot_value as Dictionary)["remaining"] = 0
	scratch_state["stock"] = stock
	scratch_state["scalper_present"] = true
	states["scratch_tickets"] = scratch_state
	data["game_states"] = states
	return "empty_scratch_machine_with_scalper"


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
