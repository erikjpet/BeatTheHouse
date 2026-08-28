extends SceneTree

# Executable pre-implementation guard for the world06_1 knowledge contract.
# This validates the independently inventoried seam and stable adapter rules;
# it intentionally refuses to bless unresolved env06_6 implementation bindings.

const DOC_PATH := "res://docs/plans/world06_1_crew_sequence_adapter_contract.md"
const EVENT_MODULE_PATH := "res://scripts/core/event_module.gd"
const EVENTS_PATH := "res://data/events/events.json"

const REQUIRED_EVENT_IDS := [
	"police_sweep_pass_over", "police_sweep_shakedown", "police_sweep_confiscation",
	"police_sweep_travel_lock", "police_sweep_punchline_l2_near_miss",
	"police_sweep_adjacent_sighting", "crew_favor_delivery",
	"numbers_knuckles_collection", "numbers_lucky_swept_collection", "numbers_desk",
	"recruitment_rook_signpost", "recruitment_rook_leads", "recruitment_switch",
	"recruitment_mags", "recruitment_knuckles", "recruitment_velvet",
	"recruitment_bishop", "recruitment_lucky", "crew_contact_rook",
	"crew_contact_switch", "crew_contact_mags", "crew_contact_knuckles",
	"crew_contact_velvet", "crew_contact_bishop", "crew_contact_lucky",
	"crew_job_board", "crew_planning_table", "crew_practice_rig", "crew_rook_ride",
	"crew_mags_bench", "crew_stake_horse_loss", "crew_collection_press",
	"heist_live_table",
]
const REQUIRED_DYNAMIC_KINDS := [
	"crew_rook_signpost", "crew_rook_leads", "crew_contact", "crew_job_board",
	"crew_practice_rig", "crew_stake_horse_loss", "crew_collection_press",
	"crew_rook_ride", "crew_mags_bench",
]
const REQUIRED_HOOKS := [
	"crew_switch_reveal", "crew_knuckles_stash", "crew_knuckles_retrieve",
	"crew_lucky_collection", "crew_job_accept", "crew_practice_rig",
	"crew_stake_loss_choice", "crew_collection_choice", "crew_rook_ride",
	"crew_heist", "crew_recruit", "crew_meet", "crew_rook_lead_closed",
]
const REQUIRED_FIELDS := [
	"contract_version", "sequence_id", "source", "mount", "local_state_schema",
	"phase_graph", "scene_ops", "interaction_ops", "actor_ops", "objectives",
	"transition_ops", "reentry_policy", "expiry", "cleanup", "aftermath",
	"mechanic_tags", "sequence_signature", "ownership_claims", "outcome_channels",
	"private_capabilities",
]
const HIDDEN_WORDS := ["traitor", "betrayal", "the_turn", "grievance", "clue"]


func _initialize() -> void:
	var failures: Array = []
	_check_document(failures)
	_check_inventory(failures)
	_check_stable_definition_rules(failures)
	if failures.is_empty():
		print("World sequence adapter specification contract passed: events=%d concrete_bindings=24 handoff=749390ce" % REQUIRED_EVENT_IDS.size())
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)


func _check_document(failures: Array) -> void:
	var text := FileAccess.get_file_as_string(DOC_PATH)
	if text.is_empty():
		failures.append("Adapter contract document is missing.")
		return
	for section in ["## 1. Seam inventory", "## 3. Ownership and composition", "## 4. Lifecycle", "## 5. Authoritative action and outcome path", "## 6. Hidden-state isolation", "## 10. Concrete env06_6 binding appendix"]:
		if not text.contains(section):
			failures.append("Adapter contract is missing section: %s" % section)
	for index in range(1, 25):
		var binding_id := "ENV-BIND-%02d" % index
		if not text.contains("`%s`" % binding_id) or not text.contains("| UNRESOLVED |"):
			failures.append("Adapter contract does not preserve unresolved binding %s." % binding_id)
	for normative_marker in ["749390ce", "06459402", "78 failures", "sealed host", "content fingerprint", "alternate_exit", "turn-boundary grace", "visual_objects", "active_stages"]:
		if not text.contains(normative_marker):
			failures.append("Adapter contract is not bound to handoff marker: %s" % normative_marker)
	for event_id in REQUIRED_EVENT_IDS:
		if not text.contains("`%s`" % event_id):
			failures.append("Seam inventory omits event %s." % event_id)


func _check_inventory(failures: Array) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		failures.append("Production events catalog did not parse as an array.")
		return
	var actual_ids: Array = []
	for value in parsed:
		if typeof(value) == TYPE_DICTIONARY:
			actual_ids.append(str((value as Dictionary).get("id", "")))
	for event_id in REQUIRED_EVENT_IDS:
		if not actual_ids.has(event_id):
			failures.append("Inventoried EventModule surface disappeared: %s" % event_id)
	var source := FileAccess.get_file_as_string(EVENT_MODULE_PATH)
	for kind in REQUIRED_DYNAMIC_KINDS:
		if not source.contains('"%s"' % kind):
			failures.append("EventModule dynamic kind is not routed: %s" % kind)
	for hook_id in REQUIRED_HOOKS:
		if not source.contains('"%s"' % hook_id):
			failures.append("EventModule hook is not routed: %s" % hook_id)
	for direct_id in ["crew_planning_table", "heist_live_table", "crew_favor_delivery"]:
		if not source.contains('"%s"' % direct_id):
			failures.append("EventModule direct surface is not routed: %s" % direct_id)


func _check_stable_definition_rules(failures: Array) -> void:
	var valid := _valid_definition()
	_failures_must_be(valid, 0, "neutral definition", failures)
	var missing_cleanup := valid.duplicate(true)
	missing_cleanup.erase("cleanup")
	_failures_must_be(missing_cleanup, 1, "missing cleanup", failures)
	var unowned := valid.duplicate(true)
	unowned["outcome_channels"] = [{"id": "job_resolution", "owner_id": ""}]
	_failures_must_be(unowned, 1, "unowned outcome", failures)
	var no_expiry_policy := valid.duplicate(true)
	no_expiry_policy["expiry"] = {"boundary": "action"}
	_failures_must_be(no_expiry_policy, 1, "expiry without policy", failures)
	var conflict := valid.duplicate(true)
	conflict["ownership_claims"] = [
		{"target": "job_board", "property": "visible", "mode": "exclusive"},
		{"target": "job_board", "property": "visible", "mode": "exclusive"},
	]
	_failures_must_be(conflict, 1, "exclusive ownership conflict", failures)
	var hidden := valid.duplicate(true)
	hidden["private_capabilities"] = ["traitor_identity"]
	_failures_must_be(hidden, 1, "hidden semantic identifier", failures)


func _validate_stable(definition: Dictionary) -> Array:
	var failures: Array = []
	for field in REQUIRED_FIELDS:
		if not definition.has(field):
			failures.append("missing:%s" % field)
	var expiry := _dict(definition.get("expiry", {}))
	if not expiry.has("policy") or not ["resume", "fail", "cancel"].has(str(expiry.get("policy", ""))):
		failures.append("expiry:policy")
	for channel_value in _array(definition.get("outcome_channels", [])):
		var channel := _dict(channel_value)
		if str(channel.get("id", "")).is_empty() or str(channel.get("owner_id", "")).is_empty():
			failures.append("outcome:unowned")
	var claim_keys: Dictionary = {}
	for claim_value in _array(definition.get("ownership_claims", [])):
		var claim := _dict(claim_value)
		if str(claim.get("mode", "")) != "exclusive":
			continue
		var key := "%s/%s" % [str(claim.get("target", "")), str(claim.get("property", ""))]
		if claim_keys.has(key):
			failures.append("ownership:conflict:%s" % key)
		claim_keys[key] = true
	var serialized := JSON.stringify(definition).to_lower()
	for word in HIDDEN_WORDS:
		if serialized.contains(word):
			failures.append("hidden:%s" % word)
	return failures


func _valid_definition() -> Dictionary:
	return {
		"contract_version": "ENV-BIND-01",
		"sequence_id": "proof_package_run",
		"source": {"domain": "crew_or_world", "owner_id": "delivery", "definition_id": "proof"},
		"mount": {"node": "ENV-BIND-04", "zone": "ENV-BIND-04"},
		"local_state_schema": {}, "phase_graph": {}, "scene_ops": [],
		"interaction_ops": [], "actor_ops": [], "objectives": [], "transition_ops": [],
		"reentry_policy": "ENV-BIND-12", "expiry": {"boundary": "action", "policy": "resume"},
		"cleanup": {"policy": "owner_scoped"}, "aftermath": [],
		"mechanic_tags": ["route_objective"], "sequence_signature": "NON_BINDING_INTENT",
		"ownership_claims": [{"target": "job_board", "property": "interaction", "mode": "exclusive"}],
		"outcome_channels": [{"id": "job_resolution", "owner_id": "delivery"}],
		"private_capabilities": ["private_condition_01"],
	}


func _failures_must_be(definition: Dictionary, expected: int, label: String, failures: Array) -> void:
	var actual := _validate_stable(definition).size()
	if actual != expected:
		failures.append("Stable validator %s returned %d failures, expected %d." % [label, actual, expected])


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
