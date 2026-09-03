extends SceneTree

# Fast current-build smoke for the first genuine historical fixture. The full
# migration matrix remains opt-in work owned by integ06_1.

const MainScene := preload("res://scenes/main.tscn")
const FIXTURE_PATH := "res://scripts/tests/fixtures/integ06_1/v0_5_1/v051_smoke_foundation_run.json"
const SLOT_ID := "integ06_1_v051_migration_smoke"
const EXPECTED_SEED := "INTEG06-1-V051-SMOKE-001"


func _init() -> void:
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
	if int(save_service.call("clear_run", SLOT_ID)) != OK:
		_fail("could not clear isolated migration smoke slot")
		return
	var destination := str(save_service.call("run_save_path", SLOT_ID))
	var absolute_destination := ProjectSettings.globalize_path(destination)
	if DirAccess.make_dir_recursive_absolute(absolute_destination.get_base_dir()) != OK:
		_fail("could not create isolated save directory")
		return
	var fixture_bytes := FileAccess.get_file_as_bytes(FIXTURE_PATH)
	if fixture_bytes.is_empty():
		_fail("historical fixture was empty")
		return
	var output := FileAccess.open(absolute_destination, FileAccess.WRITE)
	if output == null:
		_fail("could not stage historical fixture at SaveService path")
		return
	output.store_buffer(fixture_bytes)
	output.close()

	app.call("load_foundation_run")
	await process_frame
	await process_frame
	var run_state: Variant = app.get("run_state")
	if not _expected_playable_state(run_state):
		_fail("current FoundationMain did not migrate the historical state intact")
		return
	app.call("save_foundation_run")
	if int(save_service.call("wait_for_async_save")) != OK:
		_fail("current FoundationMain could not round-trip the migrated save")
		return
	var reloaded: Variant = save_service.call("load_run", SLOT_ID)
	if not _expected_playable_state(reloaded):
		_fail("round-tripped migration did not reload to the same playable state")
		return
	var cleanup_error := int(save_service.call("clear_run", SLOT_ID))
	if cleanup_error != OK:
		_fail("could not clear isolated migration smoke slot after PASS")
		return
	print("integ06_1 v0.5.1 migration smoke passed source=FoundationMain save=v2 round_trip=stable archetype=house")
	app.queue_free()
	await process_frame
	quit(0)


func _expected_playable_state(run_state: Variant) -> bool:
	if run_state == null:
		return false
	var environment: Dictionary = run_state.get("current_environment")
	var world_map: Dictionary = run_state.get("world_map")
	return str(run_state.get("seed_text")) == EXPECTED_SEED \
		and str(run_state.get("run_status")) == "active" \
		and int(run_state.get("bankroll")) == 20 \
		and int(run_state.get("game_clock_minutes")) == 720 \
		and str(environment.get("archetype_id", "")) == "house" \
		and not world_map.is_empty()


func _fail(message: String) -> void:
	push_error("integ06_1 v0.5.1 migration smoke failed: %s" % message)
	quit(1)
