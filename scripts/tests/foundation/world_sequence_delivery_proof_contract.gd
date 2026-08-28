extends SceneTree

const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const DeliveryRunModelScript := preload("res://scripts/core/delivery_run_model.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")

const PACKAGE_PATH := "res://data/crew/world06_1_crew_favor_delivery_sequence.json"
const EVENTS_PATH := "res://data/events/events.json"
const EVENT_MODULE_PATH := "res://scripts/core/event_module.gd"
const ADAPTER_PATH := "res://scripts/core/crew_world_sequence_adapter.gd"

const EXPECTED_SOURCE := {
	"domain": "crew",
	"owner_id": "crew",
	"definition_id": "crew_favor_delivery",
}
const FORBIDDEN_PACKAGE_TERMS := [
	"consumer_payload", "payment_shortfall", "traitor", "betrayal",
	"the_turn", "grievance", "clue", "crew_heist_state",
]


func _initialize() -> void:
	var failures: Array = []
	var package := _load_json_dictionary(PACKAGE_PATH, failures)
	var entry := _first_definition(package, failures)
	_check_adapter_envelope(entry, failures)
	_check_shared_definition(entry, failures)
	_check_production_event_contract(failures)
	_check_generic_integration_surface(failures)
	_check_production_schedule(failures)
	_check_delivery_failure_injection_matrix(failures)
	if failures.is_empty():
		print("World sequence delivery proof contract passed: source=crew::crew::crew_favor_delivery proof=crew_favor_delivery")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)


func _check_adapter_envelope(entry: Dictionary, failures: Array) -> void:
	if _dict(entry.get("source", {})) != EXPECTED_SOURCE:
		failures.append("Crew favor source is not the exact registered public source: %s." % JSON.stringify(entry.get("source", {})))
	var mount := _dict(entry.get("mount", {}))
	if mount != {"zone_id": "center"}:
		failures.append("Crew favor template must leave node selection to the public delivery result and declare only its canonical mount zone.")
	var outcomes := _dict(entry.get("outcome_channels", {}))
	if outcomes != {"delivered": "delivery_handoff", "expired": "delivery_handoff", "abandoned": "delivery_handoff"}:
		failures.append("Crew favor reachable outcomes are not mapped only to the neutral delivery_handoff channel.")
	if not _array(entry.get("private_capabilities", [])).is_empty():
		failures.append("Crew favor proof does not require a private capability.")
	var expected_claims := {
		"crew::package_handoff/scene_ops": true,
		"crew::package_handoff/interaction_ops": true,
		"crew::package_handoff_receipt/scene_ops": true,
		"crew::package_handoff_status/interaction_ops": true,
		"crew::package_handoff_expired/scene_ops": true,
		"crew::package_handoff_abandoned/scene_ops": true,
	}
	var actual_claims: Dictionary = {}
	for claim_value in _array(entry.get("ownership_claims", [])):
		var claim := _dict(claim_value)
		if str(claim.get("mode", "")) != "exclusive":
			failures.append("Crew favor proof contains a non-exclusive temporary ownership claim.")
		actual_claims["%s/%s" % [str(claim.get("target", "")), str(claim.get("property", ""))]] = true
	if actual_claims != expected_claims:
		failures.append("Crew favor proof ownership claims are incomplete or overbroad: %s." % JSON.stringify(actual_claims))
	var serialized := JSON.stringify(entry).to_lower()
	for forbidden in FORBIDDEN_PACKAGE_TERMS:
		if serialized.contains(forbidden):
			failures.append("Crew favor public package leaks forbidden owner-private term: %s." % forbidden)


func _check_shared_definition(entry: Dictionary, failures: Array) -> void:
	var definition := _dict(entry.get("definition", {}))
	if str(definition.get("id", "")) != "crew_favor_delivery" or definition.has("archetype_id"):
		failures.append("Crew favor shared definition must use its production id and remain target-archetype neutral.")
	var sequence := _dict(definition.get("sequence", {}))
	var calculated_signature := SequenceSchemaScript.calculated_signature_hash(definition)
	if str(sequence.get("sequence_signature", "")) != calculated_signature:
		failures.append("Crew favor sequence signature mismatch; calculated=%s." % calculated_signature)
	var target_inventory := {
		"scene_objects": [], "interactions": [], "actors": [], "services": [],
		"games": [], "routes": [], "anchors": [], "zones": ["base::zone:center"],
	}
	for error_value in SequenceSchemaScript.validate_definition(definition, OperationRegistryScript, target_inventory):
		failures.append("Shared sequence validator rejected production proof: %s" % str(error_value))
	var graph := _dict(sequence.get("phase_graph", {}))
	var phases := _array(graph.get("phases", []))
	if str(graph.get("initial_phase", "")) != "handoff" or phases.size() != 4:
		failures.append("Crew favor proof must have one playable handoff phase plus exact delivered/expired/abandoned terminal phases.")
		return
	var phase := _dict(phases[0])
	var scene_ops := _array(phase.get("scene_ops", []))
	var interaction_ops := _array(phase.get("interaction_ops", []))
	if scene_ops.size() != 1 or str(_dict(scene_ops[0]).get("owner_namespace", "")) != "crew" \
			or str(_dict(scene_ops[0]).get("stable_object_id", "")) != "package_handoff":
		failures.append("Crew favor proof lacks its crew-owned physical handoff scene object.")
	if interaction_ops.size() != 1 or str(_dict(interaction_ops[0]).get("owner_namespace", "")) != "crew":
		failures.append("Crew favor proof lacks its crew-owned handoff interaction.")
	else:
		var interaction := _dict(_dict(interaction_ops[0]).get("interaction", {}))
		var actions := _array(interaction.get("available_actions", []))
		if actions.size() != 1 or str(_dict(actions[0]).get("id", "")) != "make_handoff" \
				or bool(interaction.get("safe_exit", true)) or bool(interaction.get("alternate_exit", true)):
			failures.append("Crew favor handoff does not expose exactly one bounded public verb while leaving exit authority untouched.")
	var objectives := _array(sequence.get("objectives", []))
	if objectives.size() != 1 or str(_dict(objectives[0]).get("id", "")) != "deliver_package":
		failures.append("Crew favor proof lacks the real public delivery objective.")
	var branches := _array(phase.get("branches", []))
	if branches.size() != 3 or str(_dict(branches[0]).get("next_phase", "")) != "delivered_result" \
			or str(_dict(branches[1]).get("next_phase", "")) != "expired_result" \
			or str(_dict(branches[2]).get("next_phase", "")) != "abandoned_result":
		failures.append("Crew favor proof does not bind command delivery and trusted owner expiry/abandon lifecycle to separate terminals.")
	var expiry := _dict(sequence.get("expiry", {}))
	if str(expiry.get("boundary", "")) != "none" or int(expiry.get("after", -1)) != 0 or str(expiry.get("policy", "")) != "cancel":
		failures.append("Adapter data must not duplicate the delivery model's deadline or expiry authority.")
	var cleanup_ops := _array(_dict(sequence.get("cleanup", {})).get("operations", []))
	if cleanup_ops.size() != 2:
		failures.append("Crew favor proof cleanup does not remove exactly its temporary object and interaction.")
	var aftermaths := _dict(sequence.get("aftermath", {}))
	if aftermaths.keys().size() != 3:
		failures.append("Crew favor proof lacks exact delivered/expired/abandoned aftermath.")
	for outcome_id in ["delivered", "expired", "abandoned"]:
		var aftermath := _dict(aftermaths.get(outcome_id, {}))
		if _array(aftermath.get("scene_ops", [])).size() != 1 or str(aftermath.get("revisit_feedback", "")).is_empty():
			failures.append("Crew favor proof lacks visible, persistent %s aftermath." % outcome_id)


func _check_production_event_contract(failures: Array) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		failures.append("Production event catalog did not parse as an array.")
		return
	var event: Dictionary = {}
	for event_value in parsed as Array:
		if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("id", "")) == "crew_favor_delivery":
			event = (event_value as Dictionary).duplicate(true)
			break
	if event.is_empty():
		failures.append("Production crew_favor_delivery event disappeared.")
		return
	var choices := _array(_dict(event.get("payload", {})).get("choices", []))
	var run_package := _choice(choices, "run_package")
	var refuse := _choice(choices, "refuse")
	if run_package.is_empty() or refuse.is_empty():
		failures.append("Proof conversion must retain the production offer and genuine refusal choices.")
		return
	var success := _dict(run_package.get("consequences", {}))
	var failure := _dict(run_package.get("streets_failure", {}))
	var refused := _dict(refuse.get("consequences", {}))
	if int(success.get("bankroll_delta", 0)) != 22 or int(success.get("suspicion_delta", 0)) != 4 \
			or int(failure.get("suspicion_delta", 0)) != 9 or int(refused.get("suspicion_delta", 0)) != 9:
		failures.append("Proof conversion changed the shipped Crew favor cash/heat contract.")
	if _dict(success.get("flags", {})) != {"crew_favor_pending": false, "crew_favor_completed": true} \
			or _dict(failure.get("flags", {})) != {"crew_favor_pending": false, "crew_favor_failed": true} \
			or _dict(refused.get("flags", {})) != {"crew_favor_pending": false, "crew_favor_refused": true}:
		failures.append("Proof conversion changed the shipped Crew favor completion/failure/refusal flags.")


func _check_generic_integration_surface(failures: Array) -> void:
	if EventModuleScript == null:
		failures.append("EventModule proof integration did not load.")
	var event_source := FileAccess.get_file_as_string(EVENT_MODULE_PATH)
	if not event_source.contains("world_sequence_schedule_mount"):
		failures.append("EventModule does not schedule the accepted offer through the generic future-node mount seam.")
	var adapter_source := FileAccess.get_file_as_string(ADAPTER_PATH)
	for forbidden_special_case in ["crew_favor_delivery", "run_package", "package_handoff"]:
		if adapter_source.contains(forbidden_special_case):
			failures.append("Generic adapter contains proof-specific special case: %s." % forbidden_special_case)


func _check_production_schedule(failures: Array) -> void:
	var library := ContentLibraryScript.new()
	library.load(false)
	var run_state := _production_run(library, "WORLD-SEQUENCE-PROOF-SCHEDULE")
	run_state.narrative_flags["crew_favor_pending"] = true
	var module := EventModuleScript.new()
	module.setup(library.event("crew_favor_delivery"), library)
	var bankroll_before := run_state.bankroll
	var heat_before := run_state.suspicion_level()
	var started := module.resolve(run_state, run_state.current_environment, "run_package")
	var token := str(started.get("world_sequence_owner_token", ""))
	if not bool(started.get("delivery_started", false)) or not bool(started.get("world_sequence_scheduled", false)) or token.is_empty():
		failures.append("Production Crew favor acceptance did not schedule its real delivery sequence: %s." % JSON.stringify(started))
		return
	if run_state.bankroll != bankroll_before or run_state.suspicion_level() != heat_before or bool(run_state.narrative_flags.get("crew_favor_completed", false)):
		failures.append("Scheduling the Crew favor sequence applied owner consequences before handoff.")
	var registration := _dict(run_state.world_sequence_registrations.get(token, {}))
	var delivery_snapshot := run_state.delivery_snapshot()
	var targets := _array(delivery_snapshot.get("targets", []))
	var target_node_id := str(_dict(targets[0]).get("node_id", "")) if not targets.is_empty() else ""
	if str(registration.get("lifecycle", "")) != "eligible" or str(registration.get("node_id", "")) != target_node_id \
			or str(_dict(registration.get("source", {})).get("definition_id", "")) != "crew_favor_delivery":
		failures.append("Scheduled Crew favor registration is not bound to the exact public delivery target and owner: %s." % JSON.stringify(registration))
	var registration_text := JSON.stringify(registration).to_lower()
	for forbidden in FORBIDDEN_PACKAGE_TERMS:
		if registration_text.contains(forbidden):
			failures.append("Scheduled Crew favor registration leaks owner-private term: %s." % forbidden)
	var restored := RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	if JSON.stringify(restored.world_sequence_registrations) != JSON.stringify(run_state.world_sequence_registrations) \
			or JSON.stringify(restored.delivery_snapshot()) != JSON.stringify(delivery_snapshot):
		failures.append("Scheduled Crew favor sequence and delivery authority did not survive save/load together.")
	_check_target_handoff(run_state, library, token, target_node_id, bankroll_before, heat_before, failures)

	var refused_run := _production_run(library, "WORLD-SEQUENCE-PROOF-REFUSAL")
	refused_run.narrative_flags["crew_favor_pending"] = true
	refused_run.crew_add_trust("crew_rook", 5, "proof_fixture")
	var refused_bankroll := refused_run.bankroll
	var refused_heat := refused_run.suspicion_level()
	var refused := module.resolve(refused_run, refused_run.current_environment, "refuse")
	if not refused_run.world_sequence_registrations.is_empty() or refused_run.delivery_has_active_run() \
			or refused_run.bankroll != refused_bankroll or refused_run.suspicion_level() != refused_heat + 9 \
			or refused_run.crew_trust("crew_rook") != 0 or not bool(refused_run.narrative_flags.get("crew_favor_refused", false)) \
			or str(refused.get("message", "")) != "The night stays quiet. Quieter, even.":
		failures.append("Production Crew favor refusal no longer stays on its unchanged unmounted dialogue path.")


func _check_target_handoff(run_state: RunState, library: ContentLibrary, token: String, target_node_id: String, bankroll_before: int, heat_before: int, failures: Array) -> void:
	if target_node_id.is_empty():
		failures.append("Production delivery did not expose a public target for the proof conversion.")
		return
	RunGeneratorScript.new(library).next_environment(run_state, target_node_id, true)
	if run_state.current_world_node_id() != target_node_id:
		failures.append("Production world generation did not install the exact public Crew favor target.")
		return
	var arrival := run_state.delivery_resolve_travel_arrival({}, {})
	if not bool(arrival.get("ok", false)) or not bool(arrival.get("handoff_ready", false)):
		failures.append("Production delivery did not reach its real public handoff boundary: %s." % JSON.stringify(arrival))
		return
	var finalized := run_state.world_sequence_finalize_base_semantics([], library, {"viewport_size": {"x": 1280, "y": 720}})
	if not bool(finalized.get("ok", false)):
		failures.append("Crew favor sequence did not mount after exact-target semantic finalization: %s." % JSON.stringify(finalized))
		return
	var projection := _dict(finalized.get("projection", {}))
	var semantic := _dict(projection.get("semantic_state", {}))
	var interactions := _dict(semantic.get("interactions", {}))
	var handoff := _dict(interactions.get("crew::package_handoff", {}))
	if str(handoff.get("world_sequence_owner_token", "")) != token:
		failures.append("Composed target-room handoff is not routed by its exact owner-scoped sequence token: %s." % JSON.stringify(handoff))
	if run_state.world_sequence_mounted_owner_for_channel("delivery_handoff", target_node_id) != token:
		failures.append("Mounted Crew favor sequence did not become the sole delivery_handoff presentation owner.")
	var bankroll_at_command := run_state.bankroll
	var heat_at_command := run_state.suspicion_level()
	var actions := _array(handoff.get("available_actions", []))
	var handoff_action := _dict(actions[0]) if not actions.is_empty() else {}
	var command := run_state.world_sequence_command(
		token,
		"make_handoff",
		"proof:crew_favor:handoff",
		{},
		"crew",
		"package_handoff",
		{"crew::package_handoff": true},
		str(handoff_action.get("action_origin_owner_namespace", "")),
		str(handoff_action.get("action_origin_stable_object_id", "")),
		str(handoff_action.get("action_origin_receipt_key", "")),
		str(handoff_action.get("action_origin_boundary_id", "")),
		str(handoff_action.get("action_origin_fingerprint", ""))
	)
	if not bool(command.get("ok", false)):
		failures.append("Authenticated Crew favor handoff command failed: %s." % JSON.stringify(command))
		return
	if run_state.bankroll != bankroll_at_command or run_state.suspicion_level() != heat_at_command:
		failures.append("Adapter command applied Crew economy consequences before the owning delivery model consumed the neutral outcome.")
	var pending := run_state.world_sequence_pending_outcomes(token)
	if pending.size() != 1 or str(_dict(pending[0]).get("channel_id", "")) != "delivery_handoff" \
			or str(_dict(pending[0]).get("outcome", "")) != "delivered":
		failures.append("Crew favor handoff did not emit exactly one neutral delivered receipt: %s." % JSON.stringify(pending))
		return
	var owner_result := run_state.delivery_complete_handoff(target_node_id)
	if not bool(owner_result.get("ok", false)) or run_state.bankroll != bankroll_before + 22 \
			or run_state.suspicion_level() != heat_before + 4 or not bool(run_state.narrative_flags.get("crew_favor_completed", false)):
		failures.append("Existing delivery authority did not apply the unchanged Crew favor result exactly at outcome consumption: %s." % JSON.stringify(owner_result))
		return
	var receipt_id := str(_dict(pending[0]).get("receipt_id", ""))
	var public_result := {"ok": true, "resolved": bool(owner_result.get("resolved", false)), "message": str(owner_result.get("message", ""))}
	var acknowledgement := run_state.world_sequence_ack_outcome(token, receipt_id, public_result)
	var cleanup := run_state.world_sequence_sync_owner(token, false, "owner_ended")
	if not bool(acknowledgement.get("ok", false)) or not bool(cleanup.get("ok", false)) or not run_state.world_sequence_pending_outcomes(token).is_empty():
		failures.append("Crew favor delivered outcome did not acknowledge and clean up through the generic lifecycle seam.")
	var replay_command := run_state.world_sequence_command(token, "make_handoff", "proof:crew_favor:handoff", {}, "crew", "package_handoff", {"crew::package_handoff": true})
	var replay_owner := run_state.delivery_complete_handoff(target_node_id)
	if bool(replay_owner.get("ok", false)) or run_state.bankroll != bankroll_before + 22 or run_state.suspicion_level() != heat_before + 4:
		failures.append("Crew favor replay applied the owning delivery result more than once: command=%s owner=%s." % [JSON.stringify(replay_command), JSON.stringify(replay_owner)])


func _check_delivery_failure_injection_matrix(failures: Array) -> void:
	var library := ContentLibraryScript.new()
	library.load(false)
	for stage in ["before_owner_apply", "after_owner_apply", "before_ack", "after_ack", "save_load", "refresh", "travel_revisit"]:
		var fixture := _prepared_delivery_outcome(library, "WORLD-SEQUENCE-P1-%s" % stage, failures)
		if fixture.is_empty():
			continue
		var run_state: RunState = fixture.get("run_state")
		var token := str(fixture.get("token", ""))
		var receipt_id := str(fixture.get("receipt_id", ""))
		var target_node_id := str(fixture.get("target_node_id", ""))
		var bankroll_before := int(fixture.get("bankroll_before", 0))
		var heat_before := int(fixture.get("heat_before", 0))
		var command_receipts_before := _world_sequence_command_receipt_count(run_state, token)
		match stage:
			"before_owner_apply":
				var before := JSON.stringify(run_state.to_dict())
				var rejected := run_state.world_sequence_consume_delivery_outcome(token, receipt_id, "wrong_node")
				if bool(rejected.get("ok", false)) or JSON.stringify(run_state.to_dict()) != before:
					failures.append("P1 before-owner injection did not reject byte-identically.")
			"after_owner_apply":
				var owner_result := run_state.delivery_complete_handoff(target_node_id)
				if not bool(owner_result.get("ok", false)):
					failures.append("P1 after-owner injection could not establish the committed owner consequence.")
					continue
			"before_ack":
				var owner_result := run_state.delivery_complete_handoff(target_node_id)
				if not bool(owner_result.get("ok", false)):
					failures.append("P1 before-ack injection could not establish the committed owner consequence.")
					continue
				_persist_owner_result_checkpoint(run_state, token, receipt_id, owner_result)
			"after_ack", "save_load", "refresh", "travel_revisit":
				var owner_result := run_state.delivery_complete_handoff(target_node_id)
				if not bool(owner_result.get("ok", false)):
					failures.append("P1 %s injection could not establish the committed owner consequence." % stage)
					continue
				var public_result := _persist_owner_result_checkpoint(run_state, token, receipt_id, owner_result)
				var acknowledged := run_state.world_sequence_ack_outcome(token, receipt_id, public_result)
				if not bool(acknowledged.get("ok", false)):
					failures.append("P1 %s injection could not establish the acknowledged cleanup checkpoint." % stage)
					continue
				if stage == "save_load" or stage == "refresh":
					run_state = _round_trip_run(run_state)
				elif stage == "travel_revisit":
					if not _travel_away_and_revisit(run_state, library, target_node_id):
						failures.append("P1 travel/revisit injection could not cross the real room boundary and revisit its owner state.")
						continue
		var resumed: Dictionary
		if stage == "refresh":
			var app := FoundationMainScript.new()
			app.set("run_state", run_state)
			resumed = _dict(app.call("_resume_pending_world_sequence_outcomes"))
			app.free()
		else:
			resumed = run_state.world_sequence_consume_delivery_outcome(token, receipt_id, target_node_id)
		_assert_delivered_resume(stage, run_state, token, receipt_id, resumed, bankroll_before, heat_before, command_receipts_before, failures)

	_check_owner_lifecycle_retry(library, "expired", false, failures)
	_check_owner_lifecycle_retry(library, "abandoned", true, failures)


func _prepared_delivery_outcome(library: ContentLibrary, seed: String, failures: Array) -> Dictionary:
	# Reuse the accepted production proof seed so every injected checkpoint is
	# exercised against the same catalog-proven target semantic inventory.
	var run_state := _production_run(library, "WORLD-SEQUENCE-PROOF-SCHEDULE")
	run_state.narrative_flags["crew_favor_pending"] = true
	var module := EventModuleScript.new()
	module.setup(library.event("crew_favor_delivery"), library)
	var bankroll_before := run_state.bankroll
	var heat_before := run_state.suspicion_level()
	var started := module.resolve(run_state, run_state.current_environment, "run_package")
	var token := str(started.get("world_sequence_owner_token", ""))
	var delivery_snapshot := run_state.delivery_snapshot()
	var targets := _array(delivery_snapshot.get("targets", []))
	var target_node_id := str(_dict(targets[0]).get("node_id", "")) if not targets.is_empty() else ""
	if token.is_empty() or target_node_id.is_empty():
		failures.append("P1 injection fixture could not schedule a public delivery owner.")
		return {}
	RunGeneratorScript.new(library).next_environment(run_state, target_node_id, true)
	var arrival := run_state.delivery_resolve_travel_arrival({}, {})
	var finalized := run_state.world_sequence_finalize_base_semantics([], library, {"viewport_size": {"x": 1280, "y": 720}})
	if run_state.current_world_node_id() != target_node_id or not bool(arrival.get("ok", false)) or not bool(finalized.get("ok", false)):
		failures.append("P1 injection fixture could not mount at the delivery target: current=%s target=%s arrival=%s finalized=%s." % [run_state.current_world_node_id(), target_node_id, JSON.stringify(arrival), JSON.stringify(finalized)])
		return {}
	var interactions := _dict(_dict(_dict(finalized.get("projection", {})).get("semantic_state", {})).get("interactions", {}))
	var handoff := _dict(interactions.get("crew::package_handoff", {}))
	var actions := _array(handoff.get("available_actions", []))
	var action := _dict(actions[0]) if not actions.is_empty() else {}
	var command := run_state.world_sequence_command(
		token, "make_handoff", "p1:%s:handoff" % seed, {}, "crew", "package_handoff",
		{"crew::package_handoff": true},
		str(action.get("action_origin_owner_namespace", "")),
		str(action.get("action_origin_stable_object_id", "")),
		str(action.get("action_origin_receipt_key", "")),
		str(action.get("action_origin_boundary_id", "")),
		str(action.get("action_origin_fingerprint", ""))
	)
	var pending := run_state.world_sequence_pending_outcomes(token)
	if not bool(command.get("ok", false)) or pending.size() != 1:
		failures.append("P1 injection fixture did not produce exactly one authenticated neutral outcome.")
		return {}
	return {
		"run_state": run_state,
		"token": token,
		"receipt_id": str(_dict(pending[0]).get("receipt_id", "")),
		"target_node_id": target_node_id,
		"bankroll_before": bankroll_before,
		"heat_before": heat_before,
	}


func _persist_owner_result_checkpoint(run_state: RunState, token: String, receipt_id: String, owner_result: Dictionary) -> Dictionary:
	var public_result := {
		"ok": true,
		"resolved": bool(owner_result.get("resolved", false)),
		"message": str(owner_result.get("message", "")),
	}
	var registration := _dict(run_state.world_sequence_registrations.get(token, {}))
	var results := _dict(registration.get("owner_outcome_results", {}))
	results[receipt_id] = public_result.duplicate(true)
	registration["owner_outcome_results"] = results
	run_state.world_sequence_registrations[token] = registration
	return public_result


func _assert_delivered_resume(stage: String, run_state: RunState, token: String, receipt_id: String, resumed: Dictionary, bankroll_before: int, heat_before: int, command_receipts_before: int, failures: Array) -> void:
	if not bool(resumed.get("ok", false)) or run_state.bankroll != bankroll_before + 22 or run_state.suspicion_level() != heat_before + 4:
		failures.append("P1 %s resume did not finish the owner transaction exactly once: %s." % [stage, JSON.stringify(resumed)])
		return
	if not run_state.world_sequence_pending_outcomes(token).is_empty() or _world_sequence_command_receipt_count(run_state, token) != command_receipts_before:
		failures.append("P1 %s resume reran the terminal command or retained pending work." % stage)
	var after := JSON.stringify(run_state.to_dict())
	var replay := run_state.world_sequence_consume_delivery_outcome(token, receipt_id, run_state.current_world_node_id())
	if bool(replay.get("ok", false)) or JSON.stringify(run_state.to_dict()) != after:
		failures.append("P1 %s replay was not an exact idempotent no-op." % stage)


func _check_owner_lifecycle_retry(library: ContentLibrary, outcome: String, inject_after_sync: bool, failures: Array) -> void:
	var fixture := _prepared_delivery_outcome(library, "WORLD-SEQUENCE-P1-%s-SYNC" % outcome, failures)
	if fixture.is_empty(): return
	var run_state: RunState = fixture.get("run_state")
	var token := str(fixture.get("token", ""))
	var target_node_id := str(fixture.get("target_node_id", ""))
	var bankroll_before := int(fixture.get("bankroll_before", 0))
	var heat_before := int(fixture.get("heat_before", 0))
	var command_count := _world_sequence_command_receipt_count(run_state, token)
	# Lifecycle outcomes are owner-driven and must not reuse the delivered command.
	var registration := _dict(run_state.world_sequence_registrations.get(token, {}))
	run_state.world_sequence_registrations.erase(token)
	run_state.active_delivery_run = DeliveryRunModelScript.abandon(run_state.active_delivery_run, "deadline" if outcome == "expired" else "abandoned")
	run_state.call("_apply_delivery_resolution")
	run_state.world_sequence_registrations[token] = registration
	run_state.active_delivery_run["world_sequence_lifecycle_retry"] = {"owner_token": token, "outcome": outcome}
	if inject_after_sync:
		var synced := run_state.world_sequence_sync_owner(token, false, outcome)
		if not bool(synced.get("ok", false)):
			failures.append("P1 %s after-sync injection could not establish its pending outcome." % outcome)
			return
		run_state = _round_trip_run(run_state)
	var first := _dict(run_state.call("_retry_delivery_world_sequence_lifecycle"))
	var expected_heat := heat_before + (9 if outcome == "expired" else 0)
	if not bool(first.get("ok", false)) or run_state.bankroll != bankroll_before or run_state.suspicion_level() != expected_heat \
			or run_state.active_delivery_run.has("world_sequence_lifecycle_retry") or _world_sequence_command_receipt_count(run_state, token) != command_count:
		failures.append("P1 %s lifecycle retry did not resume exactly once without a terminal command: %s." % [outcome, JSON.stringify(first)])
		return
	var exact := JSON.stringify(run_state.to_dict())
	var replay := _dict(run_state.call("_retry_delivery_world_sequence_lifecycle"))
	if not bool(replay.get("inactive", false)) or JSON.stringify(run_state.to_dict()) != exact:
		failures.append("P1 %s lifecycle retry replay was not byte-identical and inactive." % outcome)


func _round_trip_run(run_state: RunState) -> RunState:
	var restored := RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	return restored


func _travel_away_and_revisit(run_state: RunState, library: ContentLibrary, target_node_id: String) -> bool:
	var away_id := ""
	for edge_value in _array(run_state.world_map.get("edges", [])):
		var edge := _dict(edge_value)
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		if from_id == target_node_id:
			away_id = to_id
			break
		if to_id == target_node_id:
			away_id = from_id
			break
	if away_id.is_empty(): return false
	var generator := RunGeneratorScript.new(library)
	generator.next_environment(run_state, away_id, true)
	if run_state.current_world_node_id() != away_id: return false
	generator.next_environment(run_state, target_node_id, true)
	return run_state.current_world_node_id() == target_node_id


func _world_sequence_command_receipt_count(run_state: RunState, token: String) -> int:
	var container := _dict(run_state.current_environment.get("world_sequence_instances", {}))
	var entry := _dict(container.get(token, {}))
	return _array(_dict(entry.get("state", {})).get("command_receipt_records", [])).size()


func _production_run(library: ContentLibrary, seed: String) -> RunState:
	var run_state := RunStateScript.new()
	run_state.start_new(seed)
	RunGeneratorScript.new(library).next_environment(run_state)
	run_state.current_environment = {
		"id": run_state.current_world_node_id(),
		"archetype_id": run_state.current_world_node_id(),
		"world_node_id": run_state.current_world_node_id(),
		"kind": "casino",
		"tier": 1,
		"turns": 0,
		"resolved_event_ids": [],
	}
	return run_state


func _load_json_dictionary(path: String, failures: Array) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("JSON document did not parse as a dictionary: %s." % path)
		return {}
	return (parsed as Dictionary).duplicate(true)


func _first_definition(package: Dictionary, failures: Array) -> Dictionary:
	var definitions := _array(package.get("definitions", []))
	if definitions.size() != 1 or typeof(definitions[0]) != TYPE_DICTIONARY:
		failures.append("Crew favor proof package must contain exactly one production definition.")
		return {}
	return _dict(definitions[0])


func _choice(choices: Array, choice_id: String) -> Dictionary:
	for choice_value in choices:
		if typeof(choice_value) == TYPE_DICTIONARY and str((choice_value as Dictionary).get("id", "")) == choice_id:
			return (choice_value as Dictionary).duplicate(true)
	return {}


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
