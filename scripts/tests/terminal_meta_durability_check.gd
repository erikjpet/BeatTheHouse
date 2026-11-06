extends SceneTree

# Six fresh native processes exercise public host actions and a phased acknowledgement control.
# No fixture authority, callback, codec, key or private handler is supplied.
const HostScript := preload("res://scripts/ui/foundation_main.gd")
const MainScene := preload("res://scenes/main.tscn")
const MetaScript := preload("res://scripts/core/meta_collection_service.gd")
const DropScript := preload("res://scripts/core/collection_drop_service.gd")
const RunScript := preload("res://scripts/core/run_state.gd")
const SEED := "AUDIT029-NATIVE"
const SENTINEL := "Preserved phase029 ordinary temporary-path obstruction.\n"

var checks: int = 0
var failures: Array = []
var observations: Array = []
var stage: String = ""
var owned_root: String = ""
var meta_path: String = ""
var blocked: String = ""
var preserved: String = ""
var active_host: FoundationMain

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if _check(arguments.size() == 1 and ["produce", "pending-continue", "continue", "ack-produce", "ack-continue", "tutorial"].has(arguments[0]), "One fixed process stage selected") and _paths():
		stage = arguments[0]
		_step("begin")
		if stage == "produce":
			await _produce()
		elif stage == "pending-continue":
			await _pending_continue()
		elif stage == "continue":
			await _continue_saved()
		elif stage == "ack-produce":
			await _ack_produce()
		elif stage == "ack-continue":
			await _ack_continue()
		else:
			await _tutorial_delivery()
	if is_instance_valid(active_host):
		active_host.queue_free()
		await active_host.tree_exited
		active_host = null
		await process_frame
	print("META029_HOST_OBSERVATIONS " + JSON.stringify({"stage": stage, "pid": OS.get_process_id(), "checks": checks, "failures": failures, "observations": observations}))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
	return condition

func _step(point: String) -> void:
	print("META029_STEP " + JSON.stringify({"stage": stage, "point": point, "msec": Time.get_ticks_msec()}))

func _paths() -> bool:
	owned_root = OS.get_environment("BTH_AUDIO_LEGACY_PRIVATE_ROOT").replace("\\", "/").trim_suffix("/").simplify_path()
	meta_path = MetaScript.store_path().replace("\\", "/").simplify_path()
	blocked = meta_path + ".tmp"
	preserved = meta_path + ".tmp-blocker-preserved"
	return _check(not OS.has_feature("web"), "Actual native host path selected") \
		and _check(owned_root.is_absolute_path() and owned_root.ends_with("/meta029-terminal-host-r5"), "Exact fresh launcher private case selected") \
		and _check(meta_path == owned_root.path_join("meta/collection.json"), "Exact launcher-owned meta path selected") \
		and _check(OS.get_environment("BTH_SAVE_DIR").replace("\\", "/").simplify_path() == owned_root.path_join("saves"), "Exact launcher-owned run storage selected") \
		and _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").replace("\\", "/").simplify_path() == owned_root.path_join("data"), "Exact launcher-owned production distribution root selected") \
		and _check(blocked.begins_with(owned_root + "/") and preserved.begins_with(owned_root + "/"), "Both nonrecursive move paths remain inside owned storage")

func _mount_host() -> bool:
	active_host = MainScene.instantiate() as FoundationMain
	root.add_child(active_host)
	if not active_host.is_node_ready():
		await active_host.ready
	await process_frame
	_step("normal_host_ready")
	return _check(active_host.library != null and active_host.save_service != null, "Normal host ready initializes production services") \
		and _check(active_host.run_state == null, "Fresh normal host has no inherited live run")

func _status() -> Dictionary:
	var data: Dictionary = active_host.save_status_snapshot()
	return {"has_save": data.get("has_save", false), "load_available": data.get("load_available", false), "status_text": data.get("status_text", ""), "pending_autosave": data.get("pending_autosave", false), "autosave_last_error": data.get("autosave_last_error", 0), "autosave_last_error_code": data.get("autosave_last_error_code", ""), "visible_run_status": data.get("visible_run_status", "")}

func _idle_saved(label: String) -> bool:
	var data: Dictionary = _status()
	return _check(bool(data.get("has_save", false)) and bool(data.get("load_available", false)), label + ": public slot is loadable") \
		and _check(not bool(data.get("pending_autosave", true)) and not active_host.save_service.async_save_in_flight(), label + ": normal native save is idle") \
		and _check(int(data.get("autosave_last_error", -1)) == OK, label + ": no run save error")

func _disk_count(label: String) -> int:
	var service: MetaCollectionService = MetaScript.new()
	service.load()
	if not _check(bool(service.last_load_result().get("ok", false)), label + ": fresh meta service loads valid disk state"):
		return -1
	return service.owned_instances().size()

func _produce() -> void:
	if not _check(not FileAccess.file_exists(meta_path) and not DirAccess.dir_exists_absolute(blocked) and not DirAccess.dir_exists_absolute(preserved), "Produce stage begins with fresh owned meta and obstruction names"):
		return
	var baseline: MetaCollectionService = MetaScript.new()
	baseline.load()
	var minted: Dictionary = baseline.mint_players_card({"seed": SEED, "route": "high_roller_cashout", "tier_reached": "gold"})
	if not _check(not minted.is_empty() and baseline.owned_instances().size() == 1, "Public mint creates one owned baseline card"):
		return
	if not _check(baseline.save() == OK and _disk_count("Baseline") == 1, "Healthy baseline meta save and reload succeed"):
		return
	var baseline_meta_hash: String = FileAccess.get_sha256(meta_path)
	var mounted: bool = await _mount_host()
	if not mounted:
		return
	if not _check(active_host.start_foundation_run(SEED, {"mode": "standard", "id": "standard"}, true), "Normal public host start generates a playable run"):
		return
	_step("normal_run_generated")
	if not _check(active_host.run_state != null and not active_host.run_state.is_terminal() and active_host.current_screen == HostScript.SCREEN_ENVIRONMENT, "Generated host remains on its active environment screen"):
		return
	var run: RunState = active_host.run_state
	var authority: Dictionary = run.validate_room_action_authority()
	if not _check(run.room_presentation_revision() != 0 and not run.room_presentation_snapshot().is_empty() and bool(authority.get("ok", false)), "Naturally generated room publication and authority are valid without repair"):
		observations.append({"case": "natural_room_failure", "authority": authority})
		return
	if not _check(run.meta_collection_enabled_for_run() and active_host.meta_collection_service != null and active_host.meta_collection_service.owned_instances().size() == 1, "Normal host imports the saved meta collection"):
		return
	var carried: Array = run.challenge_modifiers().get("meta_collection_carried_instance_ids", [])
	if not _check(carried.has(int(minted.get("instance_id", 0))), "Normal generated run carries the baseline card"):
		return
	active_host.save_run_from_menu()
	if not _idle_saved("Healthy initial public Save"):
		observations.append({"case": "initial_save_failure", "save_status": _status()})
		return
	_step("healthy_initial_save_complete")
	var save_path: String = ProjectSettings.globalize_path(str(active_host.save_status_snapshot().get("save_path", ""))).replace("\\", "/").simplify_path()
	if not _check(save_path.begins_with(owned_root.path_join("data/saves") + "/") and FileAccess.file_exists(save_path), "Public save path is a real owned run file"):
		return
	var initial_save_hash: String = FileAccess.get_sha256(save_path)
	if not _check(DirAccess.make_dir_absolute(blocked) == OK, "Real owned meta temporary-path directory obstruction created"):
		return
	var sentinel: FileAccess = FileAccess.open(blocked.path_join("preserve.txt"), FileAccess.WRITE)
	if not _check(sentinel != null, "Owned obstruction sentinel opens"):
		return
	sentinel.store_string(SENTINEL)
	var sentinel_error: Error = sentinel.get_error()
	sentinel.close()
	if not _check(sentinel_error == OK and DirAccess.dir_exists_absolute(blocked) and not FileAccess.file_exists(blocked), "Actual obstruction is a directory, with a preserved sentinel"):
		return
	active_host.abandon_run_from_menu()
	_step("public_abandon_returned")
	if not _check(run.is_terminal() and run.run_status == RunScript.RUN_STATUS_FAILED and run.run_failure_reason == RunScript.FAILURE_ABANDONED, "Production Abandon callback establishes the terminal failure"):
		return
	observations.append({"case": "actual_abandon_with_meta_write_obstructed", "live_meta_count": active_host.meta_collection_service.owned_instances().size(), "durable_meta_count": _disk_count("After actual Abandon"), "processed_flag": run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG, false), "decay_flag": run.narrative_flags.get(MetaScript.FAILURE_DECAY_FLAG, false), "terminal_checkpoint_flag": run.narrative_flags.get(HostScript.TERMINAL_RESUME_CHECKPOINT_FLAG, false), "meta_primary_unchanged": FileAccess.get_sha256(meta_path) == baseline_meta_hash, "run_file_changed": FileAccess.get_sha256(save_path) != initial_save_hash, "save_status": _status(), "screen": active_host.current_screen})
	if not _check(FileAccess.get_sha256(meta_path) == baseline_meta_hash, "Real obstructed meta write preserves baseline primary bytes"):
		return
	_check(active_host.meta_collection_service.owned_instances().size() == 1 and _disk_count("Rollback") == 1, "Failed collection transaction restores live and durable card")
	_check(not bool(run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG, false)) and not bool(run.narrative_flags.get(MetaScript.FAILURE_DECAY_FLAG, false)), "Failed transaction leaves both outcome flags unprocessed")
	var pending_record: Dictionary = run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_RECORD_FLAG, {}).duplicate(true)
	_check(not pending_record.is_empty() and active_host.collection_drop_service.terminal_special_outcome_pending(run), "Failed transaction retains a pending receipt")
	var saved_pending: RunState = active_host.save_service.load_run(active_host.autosave_slot_id)
	var loaded_record: Dictionary = saved_pending.narrative_flags.get(DropScript.SPECIAL_OUTCOME_RECORD_FLAG, {}) if saved_pending != null else {}
	observations.append({"case": "public_pending_load_components", "non_null": saved_pending != null, "terminal": saved_pending.is_terminal() if saved_pending != null else false, "run_status": saved_pending.run_status if saved_pending != null else "", "record": loaded_record, "expected_record": pending_record, "dictionary_equal": loaded_record == pending_record, "schema_type_loaded": typeof(loaded_record.get("schema_version")), "schema_type_prepared": typeof(pending_record.get("schema_version")), "processed": saved_pending.narrative_flags.get(DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG, false) if saved_pending != null else false, "load_outcome": active_host.save_service.last_load_result().get("outcome", "")})
	_check(saved_pending != null and saved_pending.is_terminal() and int(loaded_record.get("schema_version", 0)) == 1 and typeof(loaded_record.get("receipt")) == TYPE_STRING and loaded_record.get("receipt") == pending_record.get("receipt") and typeof(loaded_record.get("intent_json")) == TYPE_STRING and loaded_record.get("intent_json") == pending_record.get("intent_json") and not bool(saved_pending.narrative_flags.get(DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG, false)), "Real Resume Slot durably contains the same unprocessed receipt and exact intent bytes")
	_check(not active_host.start_foundation_run(SEED + "-REPLACE") and active_host.run_state == run, "Direct Start preserves pending terminal run while collection write fails")
	active_host.open_meta_home()
	_check(active_host.run_state == run, "Direct Home preserves pending terminal run while collection write fails")
	_check(not active_host.load_foundation_run() and active_host.run_state == run, "Direct Load preserves live pending terminal run while collection write fails")
	active_host.confirm_delete_saved_run()
	_check(FileAccess.file_exists(save_path) and active_host.run_state == run, "Delete preserves pending Resume Slot while collection write fails")
	_check(not active_host.return_to_main_menu() and active_host.run_state == run, "Main Menu preserves pending terminal run while collection write fails")
	_check(run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_RECORD_FLAG, {}) == pending_record and active_host.meta_collection_service.owned_instances().size() == 1 and FileAccess.get_sha256(meta_path) == baseline_meta_hash, "All failed navigation retries preserve exact intent and collection")
	observations.append({"case": "pending_meta_failure_left_for_fresh_process", "record": pending_record, "live_meta_count": active_host.meta_collection_service.owned_instances().size(), "durable_meta_count": _disk_count("Pending producer exit"), "processed": run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG, false)})

func _continue_saved() -> void:
	if not _check(FileAccess.get_file_as_string(preserved.path_join("preserve.txt")) == SENTINEL and not DirAccess.dir_exists_absolute(blocked), "Fresh process sees preserved obstruction and restored temporary path"):
		return
	var durable_before: int = _disk_count("Fresh process before Continue")
	if durable_before < 0:
		return
	var mounted: bool = await _mount_host()
	if not mounted:
		return
	var startup_status: Dictionary = active_host.save_status_snapshot()
	if not _check(str(startup_status.get("visible_pressure", "missing")) == "" and str(startup_status.get("visible_run_status", "missing")) == "", "Fresh menu save snapshot returns empty no-run fields"):
		return
	observations.append({"case": "fresh_menu_save_snapshot_after_guard", "visible_pressure": startup_status.get("visible_pressure", "missing"), "visible_run_status": startup_status.get("visible_run_status", "missing"), "load_available": startup_status.get("load_available", false)})
	_step("cold_menu_snapshot_returned")
	if not _check(bool(startup_status.get("load_available", false)), "Fresh normal host discovers the real saved slot"):
		return
	if not _check(active_host.start_or_continue_primary(), "Actual public Continue loads the saved run"):
		observations.append({"case": "continue_failure", "save_status": _status()})
		return
	_step("cold_public_continue_returned")
	var run: RunState = active_host.run_state
	if not _check(run != null and run.seed_text == SEED and run.is_terminal() and run.run_status == RunScript.RUN_STATUS_FAILED and run.run_failure_reason == RunScript.FAILURE_ABANDONED, "Cold public Continue restores the actual abandoned terminal run"):
		return
	if not _check(active_host.current_screen == HostScript.SCREEN_FAILURE and active_host.meta_collection_service != null, "Cold terminal Continue presents its real failure host and fresh meta service"):
		return
	if not _idle_saved("Cold terminal Continue"):
		return
	observations.append({"case": "cold_process_public_continue", "durable_meta_before_continue": durable_before, "host_meta_after_continue": active_host.meta_collection_service.owned_instances().size(), "durable_meta_after_continue": _disk_count("After cold public Continue"), "processed_flag": run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG, false), "decay_flag": run.narrative_flags.get(MetaScript.FAILURE_DECAY_FLAG, false), "terminal_checkpoint_flag": run.narrative_flags.get(HostScript.TERMINAL_RESUME_CHECKPOINT_FLAG, false), "save_status": _status(), "screen": active_host.current_screen})
	active_host.save_run_from_menu()
	if not _idle_saved("Cold host public Save retry"):
		return
	observations.append({"case": "cold_host_public_terminal_save_retry", "live_meta_count": active_host.meta_collection_service.owned_instances().size(), "durable_meta_count": _disk_count("After cold public Save retry"), "processed_flag": run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG, false), "decay_flag": run.narrative_flags.get(MetaScript.FAILURE_DECAY_FLAG, false), "terminal_checkpoint_flag": run.narrative_flags.get(HostScript.TERMINAL_RESUME_CHECKPOINT_FLAG, false), "save_status": _status(), "screen": active_host.current_screen})

	_check(durable_before == 0 and active_host.meta_collection_service.owned_instances().is_empty() and _disk_count("Cold stable") == 0, "Cold Continue and repeated Save preserve durable card destruction")
	_check(bool(run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_ACK_FLAG, false)) and _story_count(run, "meta_players_card_destroyed") == 1, "Cold Continue preserves exactly one acknowledgement story")

func _story_count(run: RunState, kind: String) -> int:
	var count := 0
	for entry in run.story_log:
		if str(entry.get("type", "")) == kind:
			count += 1
	return count

func _ack_produce() -> void:
	# Domain boundary control: public RunState failure plus public preparation /
	# commit APIs place an actual run in the durable-Meta / unacknowledged-run
	# window. The separate produce stage above covers the player Abandon path.
	var baseline: MetaCollectionService = MetaScript.new()
	baseline.load()
	var minted: Dictionary = baseline.mint_players_card({"seed": SEED + "-ACK", "route": "high_roller_cashout"})
	if not _check(not minted.is_empty() and baseline.save() == OK, "Acknowledgement control creates a fresh durable card"):
		return
	var mounted: bool = await _mount_host()
	if not mounted or not _check(active_host.start_foundation_run(SEED + "-ACK"), "Acknowledgement control starts a normal generated host"):
		return
	var run: RunState = active_host.run_state
	active_host.save_run_from_menu()
	if not _idle_saved("Acknowledgement control active baseline"):
		return
	run.fail_run(RunScript.FAILURE_ABANDONED, "Acknowledgement boundary control")
	var prepared: Dictionary = active_host.collection_drop_service.prepare_terminal_special_outcome(run, active_host.meta_collection_service)
	if not _check(bool(prepared.get("ok", false)) and active_host.save_service.save_run(run, active_host.autosave_slot_id) == OK, "Public preparation is durably saved before effects"):
		return
	var result: Dictionary = active_host.collection_drop_service.commit_terminal_special_outcome(run, active_host.meta_collection_service)
	if not _check(bool(result.get("ok", false)) and _disk_count("Before ack failure") == 0, "Collection and outcome receipt are durable before run acknowledgement"):
		return
	var save_path := ProjectSettings.globalize_path(active_host.save_service.run_save_path(active_host.autosave_slot_id)).replace("\\", "/").simplify_path()
	var run_block := save_path + ".tmp"
	var run_preserved := save_path + ".tmp-ack-blocker-preserved"
	if not _check(run_block.begins_with(owned_root + "/") and run_preserved.begins_with(owned_root + "/") and not DirAccess.dir_exists_absolute(run_block) and not DirAccess.dir_exists_absolute(run_preserved), "Exact owned run temporary paths selected"):
		return
	if not _check(DirAccess.make_dir_absolute(run_block) == OK, "Actual run temporary-path obstruction created"):
		return
	var sentinel := FileAccess.open(run_block.path_join("preserve.txt"), FileAccess.WRITE)
	if not _check(sentinel != null, "Run acknowledgement obstruction sentinel opens"):
		return
	sentinel.store_string(SENTINEL)
	sentinel.close()
	var before_hash := FileAccess.get_sha256(save_path)
	active_host.save_run_from_menu()
	_check(FileAccess.get_sha256(save_path) == before_hash and not bool(run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_ACK_FLAG, false)), "Failed public Save leaves durable pending run and live acknowledgement retryable")
	_check(active_host.collection_drop_service.terminal_special_outcome_pending(run) and _story_count(run, "meta_players_card_destroyed") == 1 and _disk_count("Ack failed") == 0, "Ack failure keeps exactly one durable effect and one live story")
	var disk_pending: RunState = active_host.save_service.load_run(active_host.autosave_slot_id)
	_check(disk_pending != null and not bool(disk_pending.narrative_flags.get(DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG, false)), "Actual disk run remains at pre-effect preparation checkpoint")
	_check(DirAccess.rename_absolute(run_block, run_preserved) == OK and FileAccess.get_file_as_string(run_preserved.path_join("preserve.txt")) == SENTINEL, "Nonrecursive rename preserves run obstruction and restores path")
	observations.append({"case": "domain_ack_write_failure", "run_seed": run.seed_text, "pending": active_host.collection_drop_service.terminal_special_outcome_pending(run), "processed": run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG, false), "ack": run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_ACK_FLAG, false), "durable_card_count": _disk_count("Ack exit"), "story_count": _story_count(run, "meta_players_card_destroyed")})

func _ack_continue() -> void:
	var mounted: bool = await _mount_host()
	if not mounted or not _check(active_host.start_or_continue_primary(), "Fresh process public Continue loads the unacknowledged terminal run"):
		return
	var run: RunState = active_host.run_state
	_check(run != null and run.seed_text == SEED + "-ACK" and run.is_terminal(), "Fresh acknowledgement Continue restores the exact terminal control")
	_check(bool(run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG, false)) and bool(run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_ACK_FLAG, false)), "Cold receipt replay durably acknowledges the run")
	_check(_disk_count("Ack cold") == 0 and active_host.meta_collection_service.owned_instances().is_empty(), "Cold receipt replay does not restore or regrant destroyed card")
	_check(_story_count(run, "meta_players_card_destroyed") == 1, "Cold replay adds exactly one outcome story to pre-effect checkpoint")
	active_host.save_run_from_menu()
	_check(_story_count(run, "meta_players_card_destroyed") == 1 and not active_host.collection_drop_service.terminal_special_outcome_pending(run), "Further public Save remains idempotent")
	var receipt_map: Dictionary = active_host.meta_collection_service.snapshot().get("terminal_special_outcomes", {})
	_check(receipt_map.size() == 2, "Exactly one durable outcome receipt per actual failed run")
	observations.append({"case": "cold_ack_replay", "run_seed": run.seed_text, "ack": run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_ACK_FLAG, false), "story_count": _story_count(run, "meta_players_card_destroyed"), "receipts": receipt_map.size(), "durable_card_count": _disk_count("Ack done")})

func _pending_continue() -> void:
	if not _check(DirAccess.dir_exists_absolute(blocked) and FileAccess.get_file_as_string(blocked.path_join("preserve.txt")) == SENTINEL and not DirAccess.dir_exists_absolute(preserved), "Fresh pending process sees actual uncommitted Meta fault"):
		return
	if not _check(_disk_count("Pending cold baseline") == 1, "Fresh pending process loads the original durable card"):
		return
	var mounted: bool = await _mount_host()
	if not mounted:
		return
	var save_path := ProjectSettings.globalize_path(active_host.save_service.run_save_path(active_host.autosave_slot_id)).replace("\\", "/").simplify_path()
	var pending: RunState = active_host.save_service.load_run(active_host.autosave_slot_id)
	if not _check(pending != null and pending.is_terminal(), "Cold pending checkpoint loads through normal SaveService"):
		return
	var record: Dictionary = pending.narrative_flags.get(DropScript.SPECIAL_OUTCOME_RECORD_FLAG, {}).duplicate(true)
	active_host.open_meta_home()
	_check(active_host.run_state == null and FileAccess.file_exists(save_path), "Cold menu Home preserves uncommitted terminal obligation")
	_check(not active_host.start_foundation_run(SEED + "-COLD-REPLACE") and active_host.run_state == null, "Cold direct Start preserves uncommitted terminal obligation")
	active_host.confirm_delete_saved_run()
	_check(FileAccess.file_exists(save_path) and active_host.run_state == null, "Cold menu Delete preserves uncommitted terminal checkpoint")
	if not _check(active_host.start_or_continue_primary(), "Actual cold Continue loads pending failed run while Meta remains obstructed"):
		return
	var run: RunState = active_host.run_state
	var restored: Dictionary = run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_RECORD_FLAG, {})
	_check(run.is_terminal() and run.run_status == RunScript.RUN_STATUS_FAILED and not bool(run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG, false)) and active_host.collection_drop_service.terminal_special_outcome_pending(run), "Cold pending Continue keeps uncommitted flags retryable")
	_check(restored.get("receipt") == record.get("receipt") and restored.get("intent_json") == record.get("intent_json"), "Cold pending Continue preserves exact receipt and intent bytes")
	_check(active_host.meta_collection_service.owned_instances().size() == 1 and _disk_count("Pending cold fault") == 1 and _story_count(run, "meta_players_card_destroyed") == 0, "Cold failed commit preserves card and adds no destruction story")
	if not _check(DirAccess.rename_absolute(blocked, preserved) == OK and FileAccess.get_file_as_string(preserved.path_join("preserve.txt")) == SENTINEL, "Cold process preserves obstruction using checked nonrecursive rename"):
		return
	active_host.save_run_from_menu()
	if not _idle_saved("Cold public pending Save retry"):
		return
	_check(active_host.meta_collection_service.owned_instances().is_empty() and _disk_count("Pending cold durable retry") == 0, "Cold public Save retry durably destroys carried card")
	_check(bool(run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_ACK_FLAG, false)) and _story_count(run, "meta_players_card_destroyed") == 1, "Cold public Save retry acknowledges exactly once")
	var acknowledged: RunState = active_host.save_service.load_run(active_host.autosave_slot_id)
	_check(acknowledged != null and bool(acknowledged.narrative_flags.get(DropScript.SPECIAL_OUTCOME_ACK_FLAG, false)), "Actual disk contains final run acknowledgement")
	observations.append({"case": "cold_uncommitted_meta_retry", "ack": run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_ACK_FLAG, false), "durable_card_count": _disk_count("Pending cold done"), "story_count": _story_count(run, "meta_players_card_destroyed"), "receipt": restored.get("receipt")})

func _tutorial_delivery() -> void:
	# Authored queued-dialogue terminal-delivery integration. Directly starting
	# Linda's published dialogue does not prove the full earned Bronze journey
	# or visible TalkDock priority; the actual public snapshot is recorded.
	var mounted: bool = await _mount_host()
	if not mounted or not _check(active_host.start_tutorial_run(), "Public host starts actual authored tutorial"):
		return
	var run: RunState = active_host.run_state
	if not _check(run != null and run.is_tutorial_run() and not run.is_terminal(), "Generated tutorial is active before authored final dialogue"):
		return
	var next_instance_before := int(active_host.meta_collection_service.snapshot().get("next_instance_id", 0))
	var event_id := "dialogue:tutorial_linda_bronze_finish"
	if not _check(active_host.start_dialogue("tutorial_linda_bronze_finish", {"event_id": event_id}), "Public dialogue start queues authored Linda boundary"):
		return
	var entry: Dictionary = run.pending_talk_event(event_id)
	if not _check(str(entry.get("dialogue_id", "")) == "tutorial_linda_bronze_finish" and str(entry.get("current_node", "")) == "goal", "Actual queued dialogue begins at authored goal node"):
		return
	observations.append({"case": "tutorial_authored_queued_dialogue", "talk_snapshot": active_host.current_talk_dock_snapshot(), "scope": "Queued public authored-dialogue delivery; visible focus and earned Bronze progression are not claimed."})
	var choice: Dictionary = active_host.resolve_event_choice(event_id, "review_persistence")
	entry = run.pending_talk_event(event_id)
	if not _check(bool(choice.get("ok", false)) and bool(choice.get("delegated", false)) and str(entry.get("current_node", "")) == "persistence", "Public first authored choice advances to persistence"):
		return
	choice = active_host.resolve_event_choice(event_id, "review_next_goal")
	entry = run.pending_talk_event(event_id)
	if not _check(bool(choice.get("ok", false)) and bool(choice.get("delegated", false)) and str(entry.get("current_node", "")) == "next_goal", "Public second authored choice advances to next goal"):
		return
	var tutorial_preserved := meta_path + ".tmp-tutorial-blocker-preserved"
	if not _check(blocked.begins_with(owned_root + "/") and tutorial_preserved.begins_with(owned_root + "/") and not DirAccess.dir_exists_absolute(blocked) and not DirAccess.dir_exists_absolute(tutorial_preserved) and DirAccess.make_dir_absolute(blocked) == OK, "Fresh owned tutorial Meta temporary-path obstruction created"):
		return
	var sentinel := FileAccess.open(blocked.path_join("preserve.txt"), FileAccess.WRITE)
	if not _check(sentinel != null, "Tutorial obstruction sentinel opens"):
		return
	sentinel.store_string(SENTINEL)
	sentinel.close()
	choice = active_host.resolve_event_choice(event_id, "finish_tutorial")
	if not _check(bool(choice.get("ok", false)) and bool(choice.get("delegated", false)) and run.is_terminal() and str(run.narrative_flags.get("demo_victory_route", "")) == "tutorial_bronze_card", "Public authored final choice establishes tutorial Bronze ending"):
		observations.append({"case": "tutorial_final_choice_failure", "result": choice})
		return
	await process_frame
	_check(active_host.run_state == run and not active_host.tutorial_meta_home_handoff_scheduled and active_host.collection_drop_service.terminal_special_outcome_pending(run), "Failed tutorial collection save keeps terminal host and handoff pending")
	_check(active_host.meta_collection_service.owned_instances().is_empty() and _disk_count("Tutorial blocked") == 0, "Failed tutorial grant rolls back live and durable starter card")
	var saved_pending: RunState = active_host.save_service.load_run(active_host.autosave_slot_id)
	_check(saved_pending != null and saved_pending.is_tutorial_run() and saved_pending.is_terminal() and saved_pending.narrative_flags.has(DropScript.SPECIAL_OUTCOME_RECORD_FLAG), "Tutorial Resume Slot preserves the pending terminal record instead of clearing")
	active_host.open_meta_home()
	_check(active_host.run_state == run, "Direct Home cannot bypass pending tutorial grant")
	if not _check(DirAccess.rename_absolute(blocked, tutorial_preserved) == OK and FileAccess.get_file_as_string(tutorial_preserved.path_join("preserve.txt")) == SENTINEL, "Nonrecursive rename preserves tutorial obstruction"):
		return
	active_host.save_run_from_menu()
	await process_frame
	await process_frame
	_check(bool(run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_ACK_FLAG, false)) and _story_count(run, "meta_players_card_minted") == 1, "Tutorial retry durably acknowledges exactly one starter card")
	_check(active_host.meta_collection_service.owned_instances().size() == 1 and _disk_count("Tutorial retry") == 1, "Tutorial starter card survives actual durable reload")
	var reward: Dictionary = run.narrative_flags.get(DropScript.PLAYERS_CARD_REWARD_FLAG, {})
	_check(int(reward.get("instance_id", 0)) == next_instance_before + 1, "Sal stock keeps shared instance allocation before tutorial reward")
	_check(active_host.meta_session_active and active_host.run_state != run and not FileAccess.file_exists(active_host.save_service.run_save_path(active_host.autosave_slot_id)), "Successful tutorial acknowledgement permits ordinary deferred Home handoff and slot retirement")
	observations.append({"case": "tutorial_terminal_delivery_retry", "ack": run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_ACK_FLAG, false), "reward_instance_id": reward.get("instance_id"), "expected_reward_id_after_sal": next_instance_before + 1, "meta_home_entered": active_host.meta_session_active, "durable_card_count": _disk_count("Tutorial final"), "story_count": _story_count(run, "meta_players_card_minted")})
