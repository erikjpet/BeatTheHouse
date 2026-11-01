extends SceneTree

# Source-prepared trusted visit-binding probe. Prior e320/56941/ca803 failures retained.
# This is outside the staged Gold/practice index. All injected failures reject;
# no validator is replaced by acceptance. No historical/paid state is imported.
const Host := preload("res://scripts/ui/foundation_main.gd")
const EVENT := "recruitment_lucky"
const OBJECT := "event:recruitment_lucky"
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

class RejectRun extends RunState:
	var reject_membership := false
	var reject_publication := false
	var membership_calls := 0
	var membership_rejections := 0
	var publication_rejections := 0

	func prepare_current_environment_object_membership_for_publication() -> Dictionary:
		membership_calls += 1
		if reject_membership:
			membership_rejections += 1
			return {"ok": false, "changed": false, "errors": ["Synthetic post-transfer membership rejection."]}
		return super.prepare_current_environment_object_membership_for_publication()

	func publish_room_presentation() -> Dictionary:
		if reject_publication:
			publication_rejections += 1
			_room_presentation_publication = null
			return {"ok": false, "errors": ["Synthetic post-transfer publication rejection."]}
		return super.publish_room_presentation()

	func retry_context_view() -> Dictionary:
		return {"current": _room_event_membership_context(current_environment), "pending": _room_event_membership_pending_context.duplicate(true)}

	func event_retry_pending() -> bool:
		return not _room_event_membership_pending_context.is_empty()

	func accepted_publication_matches_live() -> bool:
		if _room_presentation_publication == null: return false
		var proof: Dictionary = _room_presentation_publication.proof_for_live_environment(current_environment)
		return not proof.is_empty() and bool(proof.get("ok", false))

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var mode := OS.get_environment("BTH_CW_PUBLICATION_FAILURE_MODE")
	var alias_case := OS.get_environment("BTH_ROOM_EVENT_ALIAS_CASE")
	if alias_case.is_empty(): alias_case = "layer"
	if not _check(alias_case in ["layer", "world", "grand", "new-run", "restore-reset", "context-reset", "visit-reset"], "explicit alias fixture case required"): _finish(); return
	if not _check(mode in ["membership", "publication"], "explicit rejection mode required"): _finish(); return
	for name in ["APPDATA", "LOCALAPPDATA", "USERPROFILE", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH", "BTH_DISTRIBUTION_DATA_ROOT"]:
		if not _check(OS.get_environment(name).contains("native-private-cw-pub-failure-"), "original private native path required: " + name): _finish(); return
	if not _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no captured/browser profile installation"): _finish(); return
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app._ensure_run_ui_built(), "normal private Host initializes"): await _finish_app(app); return
	app._ensure_full_content_library_loaded()
	var run := RejectRun.new()
	if not _check(run.has_method("prepare_new_room_event_membership_for_publication"), "third candidate present; not the Gold/practice-only index"): await _finish_app(app); return
	var seed := "ENVIRONMENT-PRACTICE-v1:CW-PUBLICATION-REJECTION-001"
	run.start_new(seed, RunState.custom_challenge("environment_practice", seed, {"environment_practice": true}))
	run.bankroll = 200
	var generator := RunGenerator.new(app.library)
	var archetype_id := RunState.GRAND_CASINO_ARCHETYPE_ID if alias_case == "grand" else "small_underground_casino"
	var generated := generator.environment_test_result(run, {"archetype_id": archetype_id, "scenario_id": "__none", "layer_id": "" if alias_case == "grand" else "casino", "generation_key": "cw-publication-contract", "depth": 0})
	if not _check(bool(generated.get("ok", false)), "fresh pristine practice Casino generates"): await _finish_app(app); return
	app.run_state = run; app.generator = generator
	app.dev_game_test_mode = true; app.dev_environment_test_mode = true
	app._bind_run_state_presentation_signals()
	app._prepare_room_presentation_at_boundary()
	if alias_case in ["world", "grand"]:
		# Ordinary generated graph installed only as declared synthetic fixture setup.
		# No trip, fare, hidden choice, reward or outcome is executed.
		run.world_map = WorldMap.new(app.library).build(run, run.create_rng("alias-transaction-world-fixture"))
		var node_id := str(run.current_environment.get("world_node_id", run.current_environment.get("archetype_id", "")))
		if not _check(not WorldMap.node_by_id(run.world_map, node_id).is_empty(), "generated graph contains actual installed fixture node"): await _finish_app(app); return
		run.world_map = WorldMap.enter_node(run.world_map, node_id)
		if not _check(bool(run.prepare_current_environment_object_membership_for_publication().get("ok", false)), "strict fixture boundary initializes real world and Grand aliases"): await _finish_app(app); return
	# Declared synthetic INITIAL projection, before measurement. Select a known
	# unresolved non-CrewMoney event and build via the real libraryless boundary,
	# matching the observed missing-hint shape. No original envelope is repaired,
	# no digest manually signed, and no paid result/job/funding is fabricated.
	var events: Array = run.current_environment.get("event_ids", []).duplicate()
	events.append(EVENT); run.current_environment["event_ids"] = events
	if not _check(bool(run.prepare_current_environment_object_membership_for_publication().get("ok", false)) and bool(run.publish_room_presentation().get("ok", false)), "synthetic selected-event fixture has valid incoming authority"): await _finish_app(app); return
	if not _check(not run.current_environment.get("layout", {}).get("object_placement_hints", {}).has(OBJECT), "fixture reaches missing-known-event metadata branch"): await _finish_app(app); return
	_check(run.accepted_publication_matches_live(), "accepted baseline publication matches exact fixture inputs")
	var initial_context := run.retry_context_view()
	if not _check(str(initial_context.current.get("environment_visit_id", "")).is_empty(), "declared fixture starts with the actual uninitialized visit regression shape"): await _finish_app(app); return
	# Reject edited incoming authority BEFORE minting even public host context.
	var initial_digest := str(run.current_environment.get("object_manifest_digest", ""))
	run.current_environment["object_manifest_digest"] = "invalid-before-visit-initialization"
	var invalid_initial := run.current_environment.duplicate(true)
	var initial_calls := run.membership_calls
	var invalid_result := run.prepare_new_room_event_membership_for_publication(app.library)
	_check(not bool(invalid_result.get("ok", false)) and run.membership_calls == initial_calls, "first-attempt incoming tamper rejects before membership")
	_check(run.current_environment == invalid_initial and not run.event_retry_pending(), "authentication failure cannot initialize visit, rewrite envelope or mark an attempt")
	run.current_environment["object_manifest_digest"] = initial_digest
	var before := _protected(run)
	var world_control := _world_control(run)
	var other_grand := _other_grand_rooms(run)
	var envelope: Dictionary = {}
	for key in ["layout", "object_manifest", "object_manifest_digest", "object_manifest_revision"]:
		var value: Variant = run.current_environment.get(key)
		envelope[key] = value.duplicate(true) if typeof(value) in [TYPE_ARRAY, TYPE_DICTIONARY] else value
	run.reject_membership = mode == "membership"
	run.reject_publication = mode == "publication"
	app._prepare_room_presentation_at_boundary()
	_check((run.membership_rejections > 0 if mode == "membership" else run.publication_rejections > 0), "injected post-transfer seam reached")
	_check(app._room_catalog_publication.is_empty() and not app.interactable_object_catalog_cache_valid and not app.interactable_object_view_cache_valid, "real Main caller clears usable catalog/cache on rejection")
	_check(_protected(run) == before, "rejection preserves all non-physical state, scenario/world owners, games, history, action and RNG")
	_check(run.room_presentation_revision() == 0, "rejected changed envelope retires only derived publication cache")
	_check(EnvironmentInstance.object_manifest_errors(run.current_environment).is_empty(), "failure retains strictly validated physical envelope rather than erasing authority")
	_check(run.event_retry_pending(), "rejected attempt stays pending despite completed hint")
	var bound_context := run.retry_context_view()
	_check(not str(bound_context.current.get("environment_visit_id", "")).is_empty() and bound_context.current == bound_context.pending, "first authenticated attempt binds pending intent to assigned trusted visit")
	_check(str(bound_context.current.get("id", "")) == str(initial_context.current.get("id", "")) and str(bound_context.current.get("archetype_id", "")) == str(initial_context.current.get("archetype_id", "")) and str(bound_context.current.get("current_layer_id", "")) == str(initial_context.current.get("current_layer_id", "")), "binding trusted visit does not substitute room or layer")
	_check(not run.to_dict().has("_room_event_membership_pending_context"), "retry bookkeeping is runtime-only, not a new saved gameplay field")
	# A pending retry must still reject edited live authority before touching aliases.
	var valid_digest := str(run.current_environment.get("object_manifest_digest", ""))
	run.current_environment["object_manifest_digest"] = "deliberately-invalid-native-control"
	var calls_before_tamper := run.membership_calls
	var rejected := run.prepare_new_room_event_membership_for_publication(app.library)
	_check(not bool(rejected.get("ok", false)) and run.membership_calls == calls_before_tamper, "pending hint-complete retry authenticates exact incoming envelope before membership")
	_check(str(run.current_environment.get("object_manifest_digest", "")) == "deliberately-invalid-native-control" and run.event_retry_pending(), "tamper rejection neither heals authority nor forgets interrupted attempt")
	run.current_environment["object_manifest_digest"] = valid_digest
	# Restore only the deliberately changed mirror; no proof is manufactured.
	var rejected_count := run.membership_rejections if mode == "membership" else run.publication_rejections
	app._prepare_room_presentation_at_boundary()
	_check((run.membership_rejections if mode == "membership" else run.publication_rejections) > rejected_count, "second normal boundary retries still-rejecting hint-complete owner seam")
	_check(run.event_retry_pending() and run.room_presentation_revision() == 0 and app._room_catalog_publication.is_empty(), "second rejection stays pending and fail-closed")
	_check(run.retry_context_view() == bound_context, "normal compiler cannot change already-bound trusted visit or discard pending intent")
	_check(_protected(run) == before, "repeated rejection has no gameplay/owner/history/RNG effects")
	if alias_case == "context-reset":
		# Change rooms through the actual authoritative practice installer, not by
		# assigning a fabricated identity or bypassing membership validation.
		var prior_context: Dictionary = run.retry_context_view().current
		run.reject_membership = false; run.reject_publication = false
		var moved := generator.environment_test_result(run, {"archetype_id": "gas_station_casino", "scenario_id": "__none", "generation_key": "alias-authentic-context-switch", "depth": 0})
		if not _check(bool(moved.get("ok", false)) and str(run.current_environment.get("archetype_id", "")) == "gas_station_casino", "normal authoritative installer selects a real different room"): await _finish_app(app); return
		_check(run.retry_context_view().current != prior_context, "normal installation really changes pending-token context")
		if not _check(_all_event_metadata_present(run, app.library), "new room has no independent missing-metadata work in this negative control"): await _finish_app(app); return
		var calls_before_other_room := run.membership_calls
		var other_room := run.prepare_new_room_event_membership_for_publication(app.library)
		_check(not run.event_retry_pending() and run.membership_calls == calls_before_other_room, "unfinished source-room token cannot reconcile the new room")
		_check(bool(other_room.get("ok", false)) and not bool(other_room.get("changed", true)), "complete new room remains a no-op after discarding foreign token")
		facts = {"case": alias_case, "fidelity": "Real authoritative practice room selection, not a paid trip or historical-state replay.", "paid_calls": 0}
		await _finish_app(app); return
	if alias_case == "visit-reset":
		# Separate unit-level same-room/different-known-visit negative, not travel.
		var calls_before_context := run.membership_calls
		run.current_environment["environment_visit_id"] = str(run.current_environment.get("environment_visit_id", "")) + "_other_native_visit"
		var other_context := run.prepare_new_room_event_membership_for_publication(app.library)
		_check(not run.event_retry_pending() and run.membership_calls == calls_before_context, "old retry token cannot reconcile a different visit")
		_check(bool(other_context.get("ok", false)) and not bool(other_context.get("changed", true)), "complete metadata in new context remains a no-op")
		facts = {"case": alias_case, "fidelity": "Unit-level known-different-visit token isolation only; no authority regeneration or travel proof.", "paid_calls": 0}
		await _finish_app(app); return
	if alias_case in ["new-run", "restore-reset"]:
		# Reset only this disposable synthetic fixture after its real rejected attempt.
		if alias_case == "new-run": run.start_new("ALIAS-RETRY-RESET-CONTROL")
		else: run.from_dict(run.to_dict())
		_check(not run.event_retry_pending(), "new-run or restore boundary clears old runtime attempt")
		facts = {"case": alias_case, "fidelity": "Lifecycle reset of a disposable rejected synthetic fixture only; NOT failed-save/cold alias qualification.", "paid_calls": 0, "funding_credits": 0}
		await _finish_app(app); return
	var changed: Array[String] = []
	for key in envelope:
		if run.current_environment.get(key) != envelope[key]: changed.append(key)
	facts = {"mode": mode, "fidelity": "Fresh synthetic missing-known-event fixture and rejection-only overrides; actual Main publication caller/retry. Not a paid CrewMoney producer, threshold, historical save, browser or field rollback proof.", "physical_fields_changed_on_failure": changed, "publication_matches_after_rejection": run.accepted_publication_matches_live(), "layer_alias_after_rejection": _layer_alias(run), "membership_rejections": run.membership_rejections, "publication_rejections": run.publication_rejections, "paid_calls": 0, "funding_credits": 0}
	# Do not dictate a broad rollback implementation. Either restoring the old
	# envelope or retaining validated metadata must make the ordinary caller retry
	# safe, with an accepted live proof rather than an ok/no-op over stale caches.
	run.reject_membership = false; run.reject_publication = false
	app._prepare_room_presentation_at_boundary()
	_check(run.accepted_publication_matches_live() and bool(run.validate_room_action_authority().get("ok", false)), "ordinary caller retry publishes an accepted proof for exact live inputs")
	_check(not app._room_catalog_publication.is_empty() and app.interactable_object_catalog_cache_valid, "ordinary retry restores a usable base room catalog")
	_check(run.current_environment.get("layout", {}).get("object_placement_hints", {}).has(OBJECT), "retry retains authored metadata")
	var rows: Array = run.current_environment.get("object_manifest", {}).get("rows", [])
	_check(rows.filter(func(row): return str(row.get("object_id", "")) == OBJECT and bool(row.get("active", false))).size() == 1, "retry produces one physical selected-event row")
	var alias := _layer_alias(run)
	if run.is_layered_environment():
		_check(bool(alias.get("present", false)) and bool(alias.get("manifest_valid", false)) and int(alias.get("selected_event_rows", 0)) == 1, "successful retry leaves a valid cached layer with the same selected physical member")
	else:
		_check(alias_case == "grand", "non-layered fixture is explicit Grand main floor control")
	_check(not run.event_retry_pending(), "successful strict membership and publication clear attempt")
	_check(_world_control(run) == world_control and _other_grand_rooms(run) == other_grand, "retry preserves topology/discovery/other node rooms and other Grand rooms")
	if alias_case in ["world", "grand"]:
		_check(_alias_view(_world_room(run)).get("ready", false), "retry commits one valid selected event into generated world-node alias")
	if alias_case == "grand":
		var grand_room: Dictionary = run.grand_casino_room_states.get(RunState.GRAND_CASINO_ARCHETYPE_ID, {})
		_check(is_same(grand_room, run.current_environment) and bool(_alias_view(grand_room).get("ready", false)), "Grand keeps intended active reference and valid selected-event membership")
	_check(_protected(run) == before, "retry cannot replay or mutate gameplay state")
	var settled := run.current_environment.duplicate(true)
	var settled_world := run.world_map.duplicate(true)
	var settled_grand := run.grand_casino_room_states.duplicate(true)
	var settled_calls := run.membership_calls
	var settled_publication := run.room_presentation_revision()
	app._prepare_room_presentation_at_boundary()
	_check(run.accepted_publication_matches_live() and run.current_environment == settled and _protected(run) == before, "second normal preparation is idempotent with current publication")
	_check(run.membership_calls == settled_calls and run.room_presentation_revision() == settled_publication, "successful idle boundary does not blanket reconcile or republish")
	_check(run.world_map == settled_world and run.grand_casino_room_states == settled_grand, "idle preparation leaves every storage alias and world revision exact")
	var idle := run.prepare_new_room_event_membership_for_publication(app.library)
	_check(bool(idle.get("ok", false)) and not bool(idle.get("changed", true)) and run.membership_calls == settled_calls, "direct completed metadata helper stays a true no-op")
	facts["publication_matches_after_retry"] = run.accepted_publication_matches_live()
	facts["layer_alias_after_retry"] = alias
	facts["case"] = alias_case
	facts["initial_context"] = initial_context
	facts["bound_context_after_rejection"] = bound_context
	facts["world_alias_after_retry"] = _alias_view(_world_room(run)) if alias_case in ["world", "grand"] else {}
	await _finish_app(app)

func _layer_alias(run: RunState) -> Dictionary:
	var id := str(run.current_environment.get("current_layer_id", ""))
	var cached: Dictionary = run.current_environment.get("layer_states", {}).get(id, {})
	var rows: Array = cached.get("object_manifest", {}).get("rows", [])
	return {"present": not cached.is_empty(), "manifest_valid": not cached.is_empty() and EnvironmentInstance.object_manifest_errors(cached).is_empty(), "selected_event_rows": rows.filter(func(row): return str(row.get("object_id", "")) == OBJECT and bool(row.get("active", false))).size()}

func _protected(run: RunState) -> Dictionary:
	var value := run.to_dict().duplicate(true)
	for key in ["current_environment", "world_map", "grand_casino_room_states"]: value.erase(key)
	for key in ["game_states", "scenario_sequence_state", "world_sequence_instances"]:
		var field: Variant = run.current_environment.get(key, {})
		value["preserved_room_" + key] = field.duplicate(true) if typeof(field) in [TYPE_ARRAY, TYPE_DICTIONARY] else field
	return value

func _finish_app(app: Node) -> void:
	app.queue_free()
	for frame in range(3): await process_frame
	_finish()

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "  ")); file.close()
	print("CW_PUBLICATION_FAILURE checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func _world_room(run: RunState) -> Dictionary:
	var node_id := str(run.current_environment.get("world_node_id", run.current_environment.get("archetype_id", "")))
	return WorldMap.node_by_id(run.world_map, node_id).get("environment", {})

func _alias_view(room: Dictionary) -> Dictionary:
	var rows: Array = room.get("object_manifest", {}).get("rows", [])
	var count := rows.filter(func(row): return str(row.get("object_id", "")) == OBJECT and bool(row.get("active", false))).size()
	var valid := not room.is_empty() and EnvironmentInstance.object_manifest_errors(room).is_empty()
	return {"ready": valid and count == 1, "manifest_valid": valid, "selected_event_rows": count}

func _world_control(run: RunState) -> Dictionary:
	var value := run.world_map.duplicate(true)
	value.erase("revision") # Only the existing target environment store may bump this.
	var node_id := str(run.current_environment.get("world_node_id", run.current_environment.get("archetype_id", "")))
	for node in value.get("nodes", []):
		if node is Dictionary and str(node.get("id", "")) == node_id: node.erase("environment")
	return value

func _other_grand_rooms(run: RunState) -> Dictionary:
	var value := run.grand_casino_room_states.duplicate(true)
	value.erase(str(run.current_environment.get("archetype_id", "")))
	return value

func _all_event_metadata_present(run: RunState, library: ContentLibrary) -> bool:
	var hints: Dictionary = run.current_environment.get("layout", {}).get("object_placement_hints", {})
	var resolved: Array = run.current_environment.get("resolved_event_ids", [])
	for event_id in run.current_environment.get("event_ids", []):
		if not resolved.has(event_id) and not library.event(str(event_id)).is_empty() and not hints.has("event:" + str(event_id)): return false
	return true
