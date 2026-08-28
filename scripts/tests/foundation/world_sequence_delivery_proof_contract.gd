extends SceneTree

const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")

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
	if outcomes != {"delivered": "delivery_handoff"}:
		failures.append("Crew favor reachable outcome is not mapped only to the neutral delivery_handoff channel.")
	if not _array(entry.get("private_capabilities", [])).is_empty():
		failures.append("Crew favor proof does not require a private capability.")
	var expected_claims := {
		"crew::package_handoff/scene_object": true,
		"crew::package_handoff/interaction": true,
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
	if str(graph.get("initial_phase", "")) != "handoff" or phases.size() != 1:
		failures.append("Crew favor proof must have one real handoff phase, not a staged wrapper around the old choice list.")
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
	if branches.size() != 1 or str(_dict(branches[0]).get("outcome", "")) != "delivered":
		failures.append("Crew favor proof handoff does not terminate through its registered neutral outcome.")
	var expiry := _dict(sequence.get("expiry", {}))
	if str(expiry.get("boundary", "")) != "none" or int(expiry.get("after", -1)) != 0 or str(expiry.get("policy", "")) != "cancel":
		failures.append("Adapter data must not duplicate the delivery model's deadline or expiry authority.")
	var cleanup_ops := _array(_dict(sequence.get("cleanup", {})).get("operations", []))
	if cleanup_ops.size() != 2:
		failures.append("Crew favor proof cleanup does not remove exactly its temporary object and interaction.")
	var aftermath := _dict(_dict(sequence.get("aftermath", {})).get("delivered", {}))
	if _array(aftermath.get("scene_ops", [])).size() != 1 or str(aftermath.get("revisit_feedback", "")).is_empty():
		failures.append("Crew favor proof lacks visible, persistent delivered aftermath.")


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
	var event_source := FileAccess.get_file_as_string(EVENT_MODULE_PATH)
	if not event_source.contains("world_sequence_schedule_mount"):
		failures.append("EventModule does not schedule the accepted offer through the generic future-node mount seam.")
	var adapter_source := FileAccess.get_file_as_string(ADAPTER_PATH)
	for forbidden_special_case in ["crew_favor_delivery", "run_package", "package_handoff"]:
		if adapter_source.contains(forbidden_special_case):
			failures.append("Generic adapter contains proof-specific special case: %s." % forbidden_special_case)


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
