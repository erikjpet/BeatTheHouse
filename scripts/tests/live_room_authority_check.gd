extends RefCounted

const PublicationScript := preload("res://scripts/core/room_presentation_publication.gd")
const InstanceScript := preload("res://scripts/core/environment_instance.gd")
const RngScript := preload("res://scripts/core/rng_stream.gd")

class OriginalAuthorityRun extends RunState:
	func validate_room_action_authority(require_renderer_proofs: bool = true) -> Dictionary:
		return PublicationScript.validate(current_environment, require_renderer_proofs)


static func check(restored: RunState, library: ContentLibrary) -> Dictionary:
	var checks: Array = []
	var failures: Array = []
	var expect := func(ok: bool, label: String) -> void:
		checks.append(label)
		if not ok: failures.append(label)
	var source_before := var_to_bytes(restored.to_dict())
	var fast := _clone(restored, false)
	var reference := PublicationScript.validate(fast.current_environment)
	var started := Time.get_ticks_usec()
	PublicationScript.validate(fast.current_environment)
	var original_usec := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var accepted := fast.validate_room_action_authority()
	var reused_usec := Time.get_ticks_usec() - started
	expect.call(bool(reference.get("ok", false)) and accepted == reference and fast.validate_room_action_authority(false) == PublicationScript.validate(fast.current_environment, false), "unchanged_live_authority_exact_strong_and_weak_result")
	expect.call(not fast._room_presentation_publication.proof_for_live_environment(fast.current_environment).is_empty(), "genuine_room_uses_owned_proof")
	accepted["layout_authority"]["slot_bindings"].clear()
	expect.call(fast.validate_room_action_authority() == reference, "returned_proof_cannot_poison_accepted_generation")
	for field in ["layout", "object_manifest", "scenario_layout_authority", "scenario_layout_audit", "scenario_render_snapshot", "scenario_sequence_projection", "service_ids", "description", "unknown_future_input"]:
		fast = _clone(restored, false)
		if field == "description": fast.current_environment[field] = "changed caller alias"
		elif typeof(fast.current_environment.get(field)) == TYPE_DICTIONARY: fast.current_environment[field]["unexpected"] = true
		elif typeof(fast.current_environment.get(field)) == TYPE_ARRAY: fast.current_environment[field].append("unexpected")
		else: fast.current_environment[field] = {"unexpected":true}
		expect.call(fast._room_presentation_publication.proof_for_live_environment(fast.current_environment).is_empty() and fast.validate_room_action_authority() == PublicationScript.validate(fast.current_environment), "aliased_" + field + "_takes_identical_full_validation")
	fast = _clone(restored, false)
	fast._room_presentation_publication = null
	expect.call(fast.validate_room_action_authority() == reference, "missing_publication_uses_original_validation")
	fast = _clone(restored, false)
	fast.current_environment["unknown_opaque_input"] = RefCounted.new()
	var opaque_publish := fast.publish_room_presentation()
	expect.call(bool(opaque_publish.get("ok", false)) and fast._room_presentation_publication.proof_for_live_environment(fast.current_environment).is_empty() and fast.validate_room_action_authority() == PublicationScript.validate(fast.current_environment), "opaque_alias_declines_proof_reuse")
	var deep: Dictionary = {}
	var child := deep
	for index in range(34):
		child["child"] = {}
		child = child["child"]
	expect.call(PublicationScript._has_opaque_reference(deep), "deep_runtime_graph_declines_reuse")

	# Begin with a generated, uninstalled ticket machine. Installation changes a
	# live validation dependency even while every non-game room field is equal.
	var rng := RngScript.new()
	rng.configure(RngScript.derive_seed(902806, 902806, "bar:live-authority"))
	var environment: Dictionary = InstanceScript.from_archetype(library.environment_archetype("bar"), 2, rng, library).to_dict()
	environment["game_ids"] = ["pull_tabs"]
	environment["game_states"] = {}
	# Production counters already supply redemption before installation. Exercise
	# the supported legacy/custom separate-host case by removing that policy.
	environment["local_narrative_flags"].erase("lottery_counter")
	environment["layout"] = InstanceScript.ensure_generated_layout(environment, library)
	var ticket := RunState.new()
	ticket.current_environment = environment
	var published := ticket.publish_room_presentation()
	expect.call(bool(published.get("ok", false)), "uninstalled_ticket_room_has_valid_physical_authority")
	ticket.current_environment["game_states"]["pull_tabs"] = {"installed":true}
	var denied := ticket.validate_room_action_authority()
	expect.call(not bool(denied.get("ok", true)) and denied == PublicationScript.validate(ticket.current_environment) and ticket._room_presentation_publication.proof_for_live_environment(ticket.current_environment).is_empty(), "ticket_installation_without_cashout_host_rejected_identically")
	ticket.current_environment["game_states"]["pull_tabs"]["environment_hooks"] = [{"id":"ticket_redeemer", "object_id":"game_hook:pull_tabs:ticket_redeemer", "unique_object_class":"pull_tab_clerk"}]
	ticket.current_environment["layout"] = InstanceScript.ensure_generated_layout(ticket.current_environment, library)
	published = ticket.publish_room_presentation()
	expect.call(bool(published.get("ok", false)) and ticket.validate_room_action_authority() == PublicationScript.validate(ticket.current_environment), "installed_ticket_cashout_authority_valid")
	var ticket_reference := ticket.validate_room_action_authority()
	ticket.current_environment["game_states"]["pull_tabs"]["opaque_simulation"] = {"packed":PackedInt64Array([9007199254740993]), "frames":[1,2,3]}
	ticket.current_environment["game_states"]["pull_tabs"]["opaque_simulation"]["packed"][0] = 7
	expect.call(not ticket._room_presentation_publication.proof_for_live_environment(ticket.current_environment).is_empty() and ticket.validate_room_action_authority() == ticket_reference and ticket_reference == PublicationScript.validate(ticket.current_environment), "simulation_buffer_mutation_does_not_change_authority_inputs")
	ticket.current_environment["game_states"]["pull_tabs"]["scalper_present"] = true
	expect.call(ticket._room_presentation_publication.proof_for_live_environment(ticket.current_environment).is_empty() and ticket.validate_room_action_authority() == PublicationScript.validate(ticket.current_environment), "scalper_presence_alias_uses_full_validation")
	ticket.current_environment["game_states"]["pull_tabs"].erase("scalper_present")
	var previous_publication: RefCounted = ticket._room_presentation_publication
	var previous_snapshot: Dictionary = previous_publication.snapshot()
	var previous_turn := int(ticket.current_environment.get("turns", 0))
	ticket.current_environment["turns"] = previous_turn + 1
	var advanced: RefCounted = previous_publication.advanced_turn_counter(ticket.current_environment, previous_turn, previous_turn + 1)
	expect.call(advanced != null and not advanced.proof_for_live_environment(ticket.current_environment).is_empty() and previous_snapshot == previous_publication.snapshot(), "counter_generation_keeps_previous_owned_graph_unchanged")
	var advanced_snapshot: Dictionary = advanced.snapshot()
	advanced_snapshot["environment"]["layout"].clear()
	advanced_snapshot["proof"].clear()
	ticket.current_environment["turns"] = previous_turn
	expect.call(previous_snapshot == previous_publication.snapshot() and not advanced.snapshot()["environment"]["layout"].is_empty() and not advanced.snapshot()["proof"].is_empty(), "shared_private_generation_children_never_escape_through_output_aliases")
	var original_turn := int(ticket.current_environment.get("turns", 0))
	ticket.current_environment["turns"] = original_turn + 1
	ticket.current_environment["game_states"]["pull_tabs"]["environment_hooks"][0]["id"] = "removed_cashout"
	expect.call(ticket._room_presentation_publication.advanced_turn_counter(ticket.current_environment, original_turn, original_turn + 1) == null, "counter_write_cannot_authenticate_changed_game_hook")
	expect.call(ticket._room_presentation_publication.proof_for_live_environment(ticket.current_environment).is_empty() and ticket.validate_room_action_authority() == PublicationScript.validate(ticket.current_environment), "aliased_game_hook_uses_original_rejection")

	# The complete genuine action still owns validation, ordering and rollback.
	fast = _clone(restored, false)
	var legacy := _clone(restored, true)
	var event := EventModule.new()
	event.setup(library.event("back_alley_offer"), library)
	var result := event.resolve(fast, fast.current_environment, "take_cash", true, false)
	var legacy_result := event.resolve(legacy, legacy.current_environment, "take_cash", true, false)
	expect.call(bool(result.get("ok", false)) and result == legacy_result and fast.to_dict() == legacy.to_dict() and [fast.rng_seed,fast.rng_state] == [legacy.rng_seed,legacy.rng_state], "genuine_offer_full_state_clock_rng_exact")
	var rollback := fast._environment_turn_snapshot()
	var state_before := var_to_bytes(fast.to_dict())
	fast.current_environment["description"] = "rejected later mutation"
	fast._apply_environment_turn_snapshot(rollback, false)
	expect.call(state_before == var_to_bytes(fast.to_dict()) and fast.validate_room_action_authority() == PublicationScript.validate(fast.current_environment), "rollback_restores_owned_authority_generation")
	expect.call(source_before == var_to_bytes(restored.to_dict()), "original_genuine_fixture_unchanged")
	return {"passed":failures.is_empty(), "checks":checks, "failures":failures,
		"same_input_native_authority_usec":{"original":original_usec,"reused":reused_usec},
		"timing_scope":"native diagnostic; actual Web comparison required"}


static func _clone(source: RunState, original: bool) -> RunState:
	var result: RunState = OriginalAuthorityRun.new() if original else RunState.new()
	result._apply_environment_turn_snapshot(source._environment_turn_snapshot(), false)
	result.current_environment = source.current_environment.duplicate(true)
	result.publish_room_presentation()
	return result
