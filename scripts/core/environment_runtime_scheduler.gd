class_name EnvironmentRuntimeScheduler
extends RefCounted

# Deterministic due-time queues for background game fixtures. Queues are
# rebuilt at explicit state boundaries and periodically reconciled as a safety
# net; ordinary frames inspect only the earliest entry.

const RECONCILE_INTERVAL_MSEC := 1000

var _queues: Dictionary = {}
var stale_pop_count := 0
var _last_inspection_usec := 0
var _last_due_lateness_msec := 0


func clear() -> void:
	_queues.clear()
	stale_pop_count = 0
	_last_inspection_usec = 0
	_last_due_lateness_msec = 0


func invalidate(environment_id: String) -> void:
	_queues.erase(environment_id)


func needs_reconcile(environment_id: String, now_msec: int, revision: int = 0) -> bool:
	var record_value: Variant = _queues.get(environment_id)
	if typeof(record_value) != TYPE_DICTIONARY:
		return true
	var record: Dictionary = record_value
	return int(record.get("revision", -1)) != revision or now_msec - int(record.get("reconciled_msec", 0)) >= RECONCILE_INTERVAL_MSEC


func replace(environment_id: String, entries: Array, now_msec: int, revision: int = 0) -> void:
	var queue: Array = []
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (entry_value as Dictionary).duplicate(true)
		if int(entry.get("due_msec", -1)) < 0:
			continue
		queue.append(entry)
	queue.sort_custom(_entry_before)
	_queues[environment_id] = {
		"entries": queue,
		"reconciled_msec": now_msec,
		"revision": revision,
	}


func take_due(environment_id: String, now_msec: int) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var record_value: Variant = _queues.get(environment_id)
	if typeof(record_value) != TYPE_DICTIONARY:
		_last_inspection_usec = Time.get_ticks_usec() - started_usec
		return {}
	var record: Dictionary = record_value
	var entries_value: Variant = record.get("entries", [])
	if typeof(entries_value) != TYPE_ARRAY:
		_last_inspection_usec = Time.get_ticks_usec() - started_usec
		return {}
	var entries: Array = entries_value
	if entries.is_empty() or int((entries[0] as Dictionary).get("due_msec", -1)) > now_msec:
		_last_due_lateness_msec = 0
		_last_inspection_usec = Time.get_ticks_usec() - started_usec
		return {}
	var entry: Dictionary = entries.pop_front()
	_last_due_lateness_msec = maxi(0, now_msec - int(entry.get("due_msec", now_msec)))
	record["entries"] = entries
	_queues[environment_id] = record
	_last_inspection_usec = Time.get_ticks_usec() - started_usec
	return entry


func upsert(environment_id: String, entry: Dictionary, revision: int = -1) -> void:
	var record_value: Variant = _queues.get(environment_id)
	if typeof(record_value) != TYPE_DICTIONARY:
		return
	var record: Dictionary = record_value
	var entries: Array = record.get("entries", []) if typeof(record.get("entries", [])) == TYPE_ARRAY else []
	var game_id := str(entry.get("game_id", ""))
	var state_key := str(entry.get("state_key", ""))
	var preserved_tie_key := ""
	for index in range(entries.size() - 1, -1, -1):
		var existing: Dictionary = entries[index] if typeof(entries[index]) == TYPE_DICTIONARY else {}
		if str(existing.get("game_id", "")) == game_id and str(existing.get("state_key", "")) == state_key:
			preserved_tie_key = str(existing.get("tie_key", ""))
			entries.remove_at(index)
	if int(entry.get("due_msec", -1)) >= 0:
		var next := entry.duplicate(true)
		if not preserved_tie_key.is_empty():
			next["tie_key"] = preserved_tie_key
		entries.append(next)
		entries.sort_custom(_entry_before)
	record["entries"] = entries
	if revision >= 0:
		record["revision"] = revision
	_queues[environment_id] = record


func queue_depth(environment_id: String) -> int:
	var record_value: Variant = _queues.get(environment_id)
	if typeof(record_value) != TYPE_DICTIONARY:
		return 0
	var entries: Variant = (record_value as Dictionary).get("entries", [])
	return (entries as Array).size() if typeof(entries) == TYPE_ARRAY else 0


func debug_snapshot(environment_id: String) -> Dictionary:
	return {
		"environment_id": environment_id,
		"queue_depth": queue_depth(environment_id),
		"last_inspection_usec": _last_inspection_usec,
		"last_due_lateness_msec": _last_due_lateness_msec,
		"stale_pop_count": stale_pop_count,
	}


func _entry_before(a: Dictionary, b: Dictionary) -> bool:
	var a_due := int(a.get("due_msec", 0))
	var b_due := int(b.get("due_msec", 0))
	if a_due != b_due:
		return a_due < b_due
	return str(a.get("tie_key", "")) < str(b.get("tie_key", ""))
