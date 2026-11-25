extends SceneTree

const MAIN := preload("res://scripts/ui/foundation_main.gd")
const REPORT := preload("res://scripts/ui/run_report_view_model.gd")


class CollectionWriteFailure extends MetaCollectionService:
	func save() -> Error:
		return ERR_CANT_CREATE


class ProfileWriteFailure extends ProfileInventory:
	func save() -> Error:
		return ERR_CANT_CREATE


class RunAcknowledgementFailure extends SaveService:
	func save_run(state: RunState, slot_id: String = "autosave") -> Error:
		if bool(state.narrative_flags.get(REPORT.TAKE_HOME_ITEM_EXTRACTED_FLAG, false)):
			return ERR_CANT_CREATE
		return super.save_run(state, slot_id)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var app := MAIN.new()
	app.RunReportViewModelScript = REPORT
	var failure := _check_container_recovery(app)
	if failure.is_empty():
		failure = _check_profile_recovery(app)
	app.free()
	if not failure.is_empty():
		push_error(failure)
	quit(0 if failure.is_empty() else 1)


func _check_container_recovery(app: FoundationMain) -> String:
	app.library = ContentLibrary.new()
	app.library.load(false)
	app.run_state = RunState.new()
	app.run_state.start_new("CORE-TERMINAL", {"mode": "standard", "modifiers": {"meta_collection_enabled": true}})
	if not app.run_state.meta_collection_enabled_for_run():
		return "The terminal reward fixture could not enable the Home collection."
	app.run_state.run_status = RunState.RUN_STATUS_ENDED
	app.run_state.add_item("backpack")
	app.run_state.add_item("suitcase")
	app.autosave_slot_id = "terminal-container"
	app.save_service = RunAcknowledgementFailure.new()
	app.meta_collection_service = CollectionWriteFailure.new()
	var original_count := _container_count(app.meta_collection_service)

	var rejected := app._persist_victory_container_claim("backpack")
	if bool(rejected.get("ok", false)) or _container_count(app.meta_collection_service) != original_count \
			or bool(app.run_state.narrative_flags.get(REPORT.TAKE_HOME_ITEM_EXTRACTED_FLAG, false)):
		return "A failed Home write kept or acknowledged an uncommitted container."

	app.meta_collection_service = MetaCollectionService.new()
	var interrupted := app._persist_victory_container_claim("backpack")
	if bool(interrupted.get("ok", false)) or _container_count(app.meta_collection_service) != original_count + 1 \
			or bool(app.run_state.narrative_flags.get(REPORT.TAKE_HOME_ITEM_EXTRACTED_FLAG, false)):
		return "The run write did not leave one saved Home claim pending: %s" % str(interrupted)

	app.save_service = SaveService.new()
	app.run_state = app.save_service.load_run(app.autosave_slot_id) as RunState
	if app.run_state == null:
		return "No run was available to reconcile after the interrupted write."
	app.meta_collection_service = MetaCollectionService.new()
	app.meta_collection_service.load()
	var recovered := app._persist_victory_container_claim("suitcase")
	var restored := app.save_service.load_run(app.autosave_slot_id) as RunState
	if not bool(recovered.get("resolved", false)) or restored == null \
			or str(restored.narrative_flags.get(REPORT.TAKE_HOME_ITEM_ID_FLAG, "")) != "backpack" \
			or _container_count(app.meta_collection_service) != original_count + 1:
		return "The stored claim failed to recover the original container exactly once."
	return ""


func _container_count(collection: MetaCollectionService) -> int:
	var containers: Array = collection.snapshot()["owned_containers"]
	return containers.size()


func _check_profile_recovery(app: FoundationMain) -> String:
	app.run_state = RunState.new()
	app.run_state.start_new("CORE-CAREER")
	app.run_state.run_status = RunState.RUN_STATUS_FAILED
	app.run_state.run_failure_reason = RunState.FAILURE_BANKROLL_ZERO
	app.autosave_slot_id = "terminal-career"
	app.save_service = SaveService.new()
	app.profile_inventory = ProfileWriteFailure.new()
	app._record_profile_run_result_once()
	if not app.profile_inventory.run_history.is_empty() or not app.profile_inventory.lifetime_stats.is_empty():
		return "A failed profile write left a staged career result in memory."

	app.profile_inventory = ProfileInventory.new()
	app._record_profile_run_result_once()
	if not bool(app.run_state.narrative_flags.get("profile_run_result_recorded", false)):
		return "The terminal career result was not recorded."
	# The run acknowledgement in memory intentionally has not been saved.
	app.save_service = SaveService.new()
	app.run_state = app.save_service.load_run(app.autosave_slot_id) as RunState
	if app.run_state == null or bool(app.run_state.narrative_flags.get("profile_run_result_recorded", false)):
		return "The test failed to restore the pre-acknowledgement generation."
	app.profile_inventory = ProfileInventory.new()
	app.profile_inventory.load()
	app._record_profile_run_result_once()
	if app.profile_inventory.run_history.size() != 1 or int(app.profile_inventory.lifetime_stats.get("total_runs", 0)) != 1:
		return "Cold Continue recorded a career result twice."
	return ""
