extends "res://scripts/tests/bar_dice_venue_terms_restore_check.gd"

# Test-only shutdown discriminator over the unchanged NEW warm venue fixture.
# Invoke with BTH_BAR_DICE_RESTORE_STAGE=warm and a fresh private case root.
# No Call/new gameplay, manual process disabling, pool sweep or forced exit.
# A WeakRef is the ONLY service reference retained across the two-frame wait.


func _close() -> void:
	var mode: String = OS.get_environment("BTH_DICE_SHUTDOWN_PROBE")
	_check(stage == "warm" and mode in ["observe", "drain_owned_save", "require_host_drain"], "Shutdown probe requires fresh warm fixture and explicit observe/drain_owned_save/require_host_drain mode")
	facts["shutdown_probe"] = {"mode": mode, "observations": [], "extra_drain_attempted": false, "additional_game_inputs": 0, "scope": "Weak observation of the exact Host-owned SaveService only; same wait/queue_free/two-frame ordering as the base test. Inherited warm inputs remain separately recorded.", "save_service_source_sha256": FileAccess.get_sha256("res://scripts/core/save_service.gd")}
	if app != null and is_instance_valid(app):
		var service_ref: WeakRef = weakref(app.save_service)
		var host_ref: WeakRef = weakref(app)
		# Bind only WeakRefs. The callback stores scalar observations, never a
		# service, Host, snapshot, callable or game-state dictionary.
		app.tree_exiting.connect(Callable(self, "_on_probe_tree_exiting").bind(service_ref, host_ref), CONNECT_ONE_SHOT)
		_record_shutdown("before_base_wait", service_ref, host_ref)
		var wait_error: int = _wait_known_service(service_ref)
		facts.shutdown_probe["base_wait_error"] = wait_error
		_record_shutdown("after_base_wait", service_ref, host_ref)
		app.queue_free()
		_record_shutdown("after_queue_free", service_ref, host_ref)
		# Preserve the base fixture's exact two-frame wait. There is no strong
		# SaveService local in this coroutine and no extra frame/process mutation.
		await _frames(2)
		_record_shutdown("after_two_frames", service_ref, host_ref)
		if mode == "require_host_drain":
			var tree_exit: Dictionary = {}
			var after_two: Dictionary = {}
			for row: Dictionary in facts.shutdown_probe.observations:
				if str(row.get("label", "")) == "tree_exiting_after_host_exit_tree": tree_exit = row
				if str(row.get("label", "")) == "after_two_frames": after_two = row
			_check(not tree_exit.is_empty() and int(tree_exit.get("async_task_id", -2)) == -1 and not bool(tree_exit.get("async_save_in_flight", true)) and bool(tree_exit.get("last_outcome_ok", false)) and int(tree_exit.get("last_outcome_error", FAILED)) == OK, "Host exit itself drains its owned save and retains the successful outcome")
			_check(not after_two.is_empty() and (not bool(after_two.get("service_alive", false)) or (int(after_two.get("async_task_id", -2)) == -1 and not bool(after_two.get("async_save_in_flight", true)))), "After Host destruction the weak service is released or has no registered task")
			facts.shutdown_probe["service_released_after_host"] = not bool(after_two.get("service_alive", false))
		if mode == "drain_owned_save" and _known_task_id(service_ref) >= 0:
			facts.shutdown_probe["extra_drain_attempted"] = true
			_record_shutdown("before_owned_extra_drain", service_ref, host_ref)
			var drain_error: int = _wait_known_service(service_ref)
			facts.shutdown_probe["owned_extra_drain_error"] = drain_error
			_record_shutdown("after_owned_extra_drain", service_ref, host_ref)
	_finish()


func _on_probe_tree_exiting(service_ref: WeakRef, host_ref: WeakRef) -> void:
	_record_shutdown("tree_exiting_after_host_exit_tree", service_ref, host_ref)


func _record_shutdown(label: String, service_ref: WeakRef, host_ref: WeakRef) -> void:
	var row: Dictionary = _shutdown_scalars(label, service_ref, host_ref)
	facts.shutdown_probe.observations.append(row)
	print("BAR_DICE_SHUTDOWN_SAVE_OBSERVATION " + JSON.stringify(row))


func _shutdown_scalars(label: String, service_ref: WeakRef, host_ref: WeakRef) -> Dictionary:
	# This synchronous function releases both temporary references on return.
	# Nothing returned/bound here can extend the service lifetime across await.
	var service: Variant = service_ref.get_ref()
	var host: Variant = host_ref.get_ref()
	var row: Dictionary = {"label": label, "process_frame": Engine.get_process_frames(), "ticks_msec": Time.get_ticks_msec(), "service_alive": is_instance_valid(service), "host_alive": is_instance_valid(host), "async_task_id": -1}
	if is_instance_valid(service):
		var task_id: int = int(service.get("async_task_id"))
		row["service_instance_id"] = service.get_instance_id()
		row["async_task_id"] = task_id
		row["async_save_in_flight"] = bool(service.async_save_in_flight())
		row["async_slot_id"] = str(service.get("async_slot_id"))
		row["last_outcome_ok"] = bool(service.last_save_outcome.get("ok", false))
		row["last_outcome_error"] = int(service.last_save_outcome.get("error", FAILED))
		if task_id >= 0: row["known_owned_task_completed"] = WorkerThreadPool.is_task_completed(task_id)
	if is_instance_valid(host):
		row["host_queued_for_deletion"] = bool(host.is_queued_for_deletion())
		row["host_processing"] = bool(host.is_processing())
		row["pending_autosave"] = bool(host.get("pending_autosave"))
		row["dirty_generation"] = int(host.get("autosave_dirty_generation"))
		row["completed_generation"] = int(host.get("autosave_completed_generation"))
		row["pending_after_frame"] = int(host.get("pending_autosave_after_frame"))
		row["pending_not_before_msec"] = int(host.get("pending_autosave_not_before_msec"))
	return row


func _known_task_id(service_ref: WeakRef) -> int:
	var service: Variant = service_ref.get_ref()
	return int(service.get("async_task_id")) if is_instance_valid(service) else -1


func _wait_known_service(service_ref: WeakRef) -> int:
	# No WorkerThreadPool ID sweep or cached-ID fallback is permitted here.
	var service: Variant = service_ref.get_ref()
	return int(service.wait_for_async_save()) if is_instance_valid(service) else ERR_DOES_NOT_EXIST
