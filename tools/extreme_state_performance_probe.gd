extends SceneTree

# Scale regression probe for states that are far larger than ordinary play.
# The thresholds are intentionally generous; this catches algorithmic growth,
# unbounded persisted histories, and UI model explosions rather than dev-box
# timing noise.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const MetaCollectionViewModelScript := preload("res://scripts/ui/meta_collection_view_model.gd")
const MetaItemInteractionViewModelScript := preload("res://scripts/ui/meta_item_interaction_view_model.gd")
const MetaSessionControllerScript := preload("res://scripts/ui/meta_session_controller.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const RunInventoryViewModelScript := preload("res://scripts/ui/run_inventory_view_model.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const REPORT_PATH := "user://extreme_state_performance_probe_report.json"
const DEFAULT_COLLECTION_SIZE := 2000
const DEFAULT_CORRUPT_RUN_ENTRY_COUNT := 10000
const MAX_META_CACHE_KEY_AVG_MS := 0.25
const MAX_META_QUOTES_TOTAL_MS := 350.0
const MAX_META_MODEL_BUILD_MS := 1200.0
const MAX_RUN_RESTORE_MS := 800.0
const MAX_RUN_INVENTORY_MODEL_MS := 120.0
const MAX_NORMALIZED_RUN_INVENTORY_ENTRIES := 256

var failures: Array = []
var observations: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var collection_size := _configured_int("BTH_EXTREME_COLLECTION_SIZE", DEFAULT_COLLECTION_SIZE)
	var corrupt_entry_count := _configured_int("BTH_EXTREME_RUN_ENTRIES", DEFAULT_CORRUPT_RUN_ENTRY_COUNT)
	_probe_meta_collection(collection_size)
	_probe_corrupt_large_run(corrupt_entry_count)
	var report := {
		"tool": "extreme_state_performance_probe",
		"collection_size": collection_size,
		"corrupt_run_entry_count": corrupt_entry_count,
		"observations": observations,
		"failures": failures,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print(JSON.stringify(report, "\t"))
	print("Extreme-state report written to %s" % ProjectSettings.globalize_path(REPORT_PATH))
	if not failures.is_empty():
		for failure in failures:
			push_error(str(failure))
		quit(1)
		return
	quit(0)


func _probe_meta_collection(count: int) -> void:
	var service: MetaCollectionService = MetaCollectionServiceScript.new()
	var store: Dictionary = service.call("_default_store")
	var owned: Array = []
	for index in range(count):
		owned.append({
			"schema_version": MetaCollectionServiceScript.SCHEMA_VERSION,
			"instance_id": index + 1,
			"itemdef_id": 1000,
			"potency": 0.5,
			"condition": 0.5,
			"resonance": 0.5,
			"usage": 0.5,
			"source": "extreme_probe",
			"source_id": "extreme:%d" % index,
		})
	store["owned_instances"] = owned
	store["next_instance_id"] = count + 1
	store["housing_tier"] = MetaCollectionServiceScript.HOUSING_HOUSE
	var oversized_history: Array = []
	for index in range(count):
		oversized_history.append({"instance_id": index + 1, "price": 1})
	store["sale_history"] = oversized_history
	store["trade_up_history"] = oversized_history

	var normalize_started := Time.get_ticks_usec()
	store = service.call("_normalize_store", store)
	service.set("_store", store)
	service.snapshot()
	var normalize_ms := _elapsed_ms(normalize_started)

	var quote_started := Time.get_ticks_usec()
	var valid_quotes := 0
	for instance_id in range(1, count + 1):
		var quote: Dictionary = service.sale_quote(MetaCollectionServiceScript.SALE_KIND_ITEM, instance_id)
		if bool(quote.get("ok", false)):
			valid_quotes += 1
	var quote_ms := _elapsed_ms(quote_started)

	var controller: MetaSessionController = MetaSessionControllerScript.new()
	controller.configure(null, service)
	var cache_samples := 40
	var cache_started := Time.get_ticks_usec()
	var last_key := ""
	for _sample in range(cache_samples):
		last_key = str(controller.call("_interactable_object_view_cache_key", "home"))
	var cache_total_ms := _elapsed_ms(cache_started)
	var cache_avg_ms := cache_total_ms / float(cache_samples)

	var collection_model_started := Time.get_ticks_usec()
	var collection_model: Dictionary = MetaCollectionViewModelScript.build(service)
	var collection_model_ms := _elapsed_ms(collection_model_started)

	var interaction_model_started := Time.get_ticks_usec()
	var interaction_model: Dictionary = MetaItemInteractionViewModelScript.build(service, MetaItemInteractionViewModelScript.MODE_CONTAINER)
	var interaction_model_ms := _elapsed_ms(interaction_model_started)

	observations["meta_collection"] = {
		"normalize_and_snapshot_ms": normalize_ms,
		"quote_count": valid_quotes,
		"all_quotes_ms": quote_ms,
		"cache_key_avg_ms": cache_avg_ms,
		"cache_key_length": last_key.length(),
		"collection_model_ms": collection_model_ms,
		"collection_model_owned_count": int(collection_model.get("owned_count", -1)),
		"interaction_model_ms": interaction_model_ms,
		"interaction_model_item_count": _array_size(interaction_model.get("items", [])),
		"sale_history_entries": _array_size(store.get("sale_history", [])),
		"trade_up_history_entries": _array_size(store.get("trade_up_history", [])),
	}
	if valid_quotes != count:
		failures.append("Only %d/%d extreme collection instances produced sale quotes." % [valid_quotes, count])
	if quote_ms > MAX_META_QUOTES_TOTAL_MS:
		failures.append("Extreme collection quote pass took %.1f ms, above %.1f ms." % [quote_ms, MAX_META_QUOTES_TOTAL_MS])
	if cache_avg_ms > MAX_META_CACHE_KEY_AVG_MS:
		failures.append("Meta interaction cache key averaged %.3f ms, above %.3f ms." % [cache_avg_ms, MAX_META_CACHE_KEY_AVG_MS])
	if interaction_model_ms > MAX_META_MODEL_BUILD_MS:
		failures.append("Extreme meta inventory model took %.1f ms, above %.1f ms." % [interaction_model_ms, MAX_META_MODEL_BUILD_MS])
	if _array_size(store.get("sale_history", [])) > MetaCollectionServiceScript.META_TRANSACTION_HISTORY_LIMIT:
		failures.append("Permanent sale history was not compacted.")
	if _array_size(store.get("trade_up_history", [])) > MetaCollectionServiceScript.META_TRANSACTION_HISTORY_LIMIT:
		failures.append("Permanent trade-up history was not compacted.")


func _probe_corrupt_large_run(count: int) -> void:
	var source := RunStateScript.new()
	source.start_new("EXTREME-STATE-PROBE")
	var data: Dictionary = source.to_dict()
	var oversized_inventory: Array = []
	var oversized_story: Array = []
	var oversized_environment_history: Array = []
	var oversized_events: Array = []
	var oversized_bags: Array = []
	var oversized_notifications: Array = []
	for index in range(count):
		oversized_inventory.append("cheap_sunglasses" if index % 2 == 0 else "lucky_keychain")
		oversized_story.append({"type": "extreme", "message": "Entry %d" % index, "action_index": index})
		oversized_environment_history.append({"id": "extreme_%d" % index, "archetype_id": "corner_store"})
		oversized_events.append({"event_id": "extreme_event_%d" % index, "presentation": "modal"})
		oversized_bags.append({"marker_id": "extreme_bag_%d" % index, "bagdef_id": 9000})
		oversized_notifications.append({"boundary_index": index, "interest": 1})
	data["inventory"] = oversized_inventory
	data["story_log"] = oversized_story
	data["environment_history"] = oversized_environment_history
	data["pending_triggered_events"] = oversized_events
	data["pending_bags"] = oversized_bags
	data["grand_casino_atm_interest_notifications"] = oversized_notifications

	var restore_started := Time.get_ticks_usec()
	var restored := RunStateScript.new()
	restored.from_dict(data)
	var restore_ms := _elapsed_ms(restore_started)
	for index in range(100):
		restored.enqueue_triggered_event("runtime_overflow_%d" % index)
		restored.add_pending_bag_marker({"marker_id": "runtime_overflow_bag_%d" % index, "bagdef_id": 9000})

	var library: ContentLibrary = ContentLibraryScript.new()
	library.load(false)
	var actions: RunActionService = RunActionServiceScript.new()
	actions.setup(library, restored)
	var inventory_model_started := Time.get_ticks_usec()
	var inventory_model: Dictionary = RunInventoryViewModelScript.build(restored, actions, "inspect", "", {})
	var inventory_model_ms := _elapsed_ms(inventory_model_started)
	var serialized := JSON.stringify(restored.to_dict())

	observations["corrupt_large_run"] = {
		"restore_ms": restore_ms,
		"normalized_inventory_entries": restored.inventory.size(),
		"normalized_story_entries": restored.story_log.size(),
		"normalized_environment_history_entries": restored.environment_history.size(),
		"normalized_pending_event_entries": restored.pending_triggered_events.size(),
		"normalized_pending_bag_entries": restored.pending_bags.size(),
		"normalized_atm_notification_entries": restored.grand_casino_atm_interest_notifications.size(),
		"inventory_model_ms": inventory_model_ms,
		"inventory_model_items": _array_size(inventory_model.get("items", [])),
		"serialized_bytes": serialized.to_utf8_buffer().size(),
	}
	if restore_ms > MAX_RUN_RESTORE_MS:
		failures.append("Oversized run restore took %.1f ms, above %.1f ms." % [restore_ms, MAX_RUN_RESTORE_MS])
	if restored.inventory.size() > MAX_NORMALIZED_RUN_INVENTORY_ENTRIES:
		failures.append("Oversized run inventory retained %d entries instead of normalizing impossible duplicates." % restored.inventory.size())
	if restored.story_log.size() > RunStateScript.MAX_STORY_LOG_ENTRIES:
		failures.append("Oversized story log was not compacted.")
	if restored.environment_history.size() > RunStateScript.MAX_ENVIRONMENT_HISTORY_ENTRIES:
		failures.append("Oversized environment history was not compacted.")
	if restored.pending_triggered_events.size() > RunStateScript.MAX_PENDING_TRIGGERED_EVENTS:
		failures.append("Oversized pending event queue was not compacted.")
	if restored.pending_bags.size() > RunStateScript.MAX_PENDING_BAG_MARKERS:
		failures.append("Oversized pending bag queue was not compacted.")
	if restored.grand_casino_atm_interest_notifications.size() > RunStateScript.MAX_ATM_INTEREST_NOTIFICATIONS:
		failures.append("Oversized ATM notification queue was not compacted.")
	if inventory_model_ms > MAX_RUN_INVENTORY_MODEL_MS:
		failures.append("Extreme run inventory model took %.1f ms, above %.1f ms." % [inventory_model_ms, MAX_RUN_INVENTORY_MODEL_MS])


func _configured_int(name: String, fallback: int) -> int:
	var raw := OS.get_environment(name).strip_edges()
	if raw.is_empty() or not raw.is_valid_int():
		return fallback
	return maxi(1, int(raw))


func _elapsed_ms(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0


func _array_size(value: Variant) -> int:
	return (value as Array).size() if typeof(value) == TYPE_ARRAY else 0
