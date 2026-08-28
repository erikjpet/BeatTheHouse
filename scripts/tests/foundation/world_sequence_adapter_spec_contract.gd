extends SceneTree

# Executable pre-implementation guard for the world06_1 knowledge contract.
# It binds the adapter vocabulary to frozen env06_6 head 855a2961 while keeping
# owner-scoped composition and outcome-channel behavior implementation-neutral.

const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const AdapterScript := preload("res://scripts/core/crew_world_sequence_adapter.gd")

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
const REQUIRED_SEQUENCE_KEYS := [
	"schema_version", "local_state_schema", "phase_graph", "objectives",
	"reentry_policy", "expiry", "cleanup", "aftermath", "mechanic_tags",
	"sequence_signature", "owner_exceptions", "fact_subscriptions",
	"completion_contract", "declared_targets",
]
const REQUIRED_HANDLERS := [
	"set_local", "increment_local", "complete_objective_step", "resolve_objective",
	"record_outcome", "publish_feedback", "request_cleanup", "event_bridge",
]
const ALLOWED_SOURCE_DOMAINS := ["crew", "world"]


func _initialize() -> void:
	var failures: Array = []
	_check_document(failures)
	_check_inventory(failures)
	_check_frozen_bindings(failures)
	_check_owner_scoped_registration(failures)
	_check_diagnostic_wrapper(failures)
	_check_hidden_identifier_guard(failures)
	if failures.is_empty():
		print("World sequence adapter specification contract passed: events=%d concrete_bindings=24 env=855a2961" % REQUIRED_EVENT_IDS.size())
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
	for section in [
		"## 1. Seam inventory", "## 3. Ownership and composition",
		"### 3.4 Generic owner-scoped multi-sequence composition", "## 4. Lifecycle",
		"## 5. Authoritative action and outcome path", "## 6. Hidden-state isolation",
		"### 9.1 Exact `crew_favor_delivery` worked interface",
		"## 10. Concrete env06_6 binding appendix",
	]:
		if not text.contains(section):
			failures.append("Adapter contract is missing section: %s" % section)
	for index in range(1, 25):
		var binding_id := "ENV-BIND-%02d" % index
		var row_start := text.find("| `%s` |" % binding_id)
		if row_start < 0:
			failures.append("Adapter contract omits concrete binding %s." % binding_id)
			continue
		var row_end := text.find("\n", row_start)
		var row := text.substr(row_start, row_end - row_start if row_end >= 0 else text.length() - row_start)
		if not row.ends_with("| RESOLVED |"):
			failures.append("Adapter contract binding %s is not resolved." % binding_id)
	if text.contains("CONCRETE BINDING UNRESOLVED") or text.contains("| UNRESOLVED |"):
		failures.append("Adapter contract retains an unresolved concrete binding.")
	for marker in [
		"749390ce", "06459402", "78-failure", "855a2961", "sealed host",
		"content fingerprint", "alternate_exit", "turn-boundary grace",
		"visual_objects", "active_stages", "world_sequence_instances",
		"source_domain::owner_id::definition_id::public_instance_token",
		"delivery_handoff", "make_handoff", "+22 bankroll", "+4 heat", "+9 heat",
	]:
		if not text.contains(marker):
			failures.append("Adapter contract is not bound to marker: %s" % marker)
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
	var frozen_inventory := _frozen_inventory()
	var diagnostics := AdapterScript.validate_frozen_event_module_inventory(parsed as Array, source, frozen_inventory)
	if not diagnostics.is_empty():
		failures.append("Frozen EventModule inventory guard rejected production: %s" % JSON.stringify(diagnostics))
	for kind in REQUIRED_DYNAMIC_KINDS:
		if not source.contains('"%s"' % kind):
			failures.append("EventModule dynamic kind is not routed: %s" % kind)
	for hook_id in REQUIRED_HOOKS:
		if not source.contains('"%s"' % hook_id):
			failures.append("EventModule hook is not routed: %s" % hook_id)
	for direct_id in ["crew_planning_table", "heist_live_table", "crew_favor_delivery"]:
		if not source.contains('"%s"' % direct_id):
			failures.append("EventModule direct surface is not routed: %s" % direct_id)
	var hostile_catalog := (parsed as Array).duplicate(true)
	hostile_catalog.append({"id": "crew_unclassified_probe", "payload": {"kind": "crew_unclassified_probe"}})
	var unclassified := AdapterScript.validate_frozen_event_module_inventory(hostile_catalog, source, frozen_inventory)
	if not _diagnostics_include(unclassified, "event_catalog", "crew_unclassified_probe", "Unclassified EventModule crew/world surface."):
		failures.append("Frozen inventory guard did not reject a new data-backed Crew surface.")
	var hostile_source := source + '\nif str(payload.get("kind", "")) == "crew_shadow_surface": pass\n'
	var source_unclassified := AdapterScript.validate_frozen_event_module_inventory(parsed as Array, hostile_source, frozen_inventory)
	if not _diagnostics_include(source_unclassified, "dynamic_kind", "crew_shadow_surface", "Unclassified EventModule crew/world surface."):
		failures.append("Frozen inventory guard did not reject a new source-routed Crew surface.")
	var missing_catalog := (parsed as Array).duplicate(true)
	for index in range(missing_catalog.size() - 1, -1, -1):
		if str(_dict(missing_catalog[index]).get("id", "")) == "crew_favor_delivery": missing_catalog.remove_at(index)
	var missing := AdapterScript.validate_frozen_event_module_inventory(missing_catalog, source, frozen_inventory)
	if not _diagnostics_include(missing, "event_catalog", "crew_favor_delivery", "Frozen EventModule crew/world surface is no longer routed."):
		failures.append("Frozen inventory guard did not reject a removed inventoried Crew surface.")
	if JSON.stringify(unclassified) != JSON.stringify(AdapterScript.validate_frozen_event_module_inventory(hostile_catalog, source, frozen_inventory)):
		failures.append("Frozen inventory diagnostics are not deterministic.")


func _frozen_inventory() -> Dictionary:
	return {
		"event_catalog": REQUIRED_EVENT_IDS,
		"dynamic_kind": REQUIRED_DYNAMIC_KINDS,
		"direct_surface": ["crew_planning_table", "heist_live_table", "crew_favor_delivery"],
		"event_hook": REQUIRED_HOOKS,
	}


func _check_frozen_bindings(failures: Array) -> void:
	if SequenceSchemaScript.SCHEMA_VERSION != 2:
		failures.append("ENV-BIND-01 drift: sequence schema is not 2.")
	if SequenceRuntimeScript.STATE_SCHEMA_VERSION != 4 \
			or SequenceRuntimeScript.COMMAND_SCHEMA_VERSION != 1 \
			or SequenceRuntimeScript.FACT_SCHEMA_VERSION != 1:
		failures.append("ENV-BIND-01 drift: runtime/command/fact schema versions changed.")
	if SequenceSchemaScript.ALLOWED_SEQUENCE_KEYS != REQUIRED_SEQUENCE_KEYS:
		failures.append("ENV-BIND-02 drift: allowed sequence envelope changed.")
	_check_exact_array("ENV-BIND-05 local types", SequenceSchemaScript.LOCAL_TYPES,
		["bool", "int", "float", "string", "enum", "string_array", "int_array"], failures)
	_check_exact_array("ENV-BIND-07 scene ops", OperationRegistryScript.SCENE_OPS,
		["spawn", "remove", "move", "replace", "reveal", "hide", "enable", "disable", "set_state", "set_appearance"], failures)
	_check_exact_array("ENV-BIND-08 interaction ops", OperationRegistryScript.INTERACTION_OPS,
		["add", "remove", "replace", "gate", "retarget", "augment"], failures)
	_check_exact_array("ENV-BIND-09 actor ops", OperationRegistryScript.ACTOR_OPS,
		["spawn", "despawn", "set_position", "set_route", "set_pose", "set_behavior"], failures)
	_check_exact_array("ENV-BIND-10 outcomes", SequenceSchemaScript.OBJECTIVE_OUTCOMES,
		["success", "failure", "ignore", "cancel"], failures)
	_check_exact_array("ENV-BIND-11 transition ops", OperationRegistryScript.TRANSITION_OPS,
		["stage", "sound", "music", "scene_change", "feedback"], failures)
	_check_exact_array("ENV-BIND-13 expiry boundaries", SequenceSchemaScript.EXPIRY_BOUNDARIES,
		["none", "leave", "visit_end", "night_end", "town_action"], failures)
	_check_exact_array("ENV-BIND-13 expiry policies", SequenceSchemaScript.EXPIRY_POLICIES,
		["resume", "fail", "ignore", "cancel", "cleanup"], failures)
	var handlers := OperationRegistryScript.registered_handlers()
	var handler_ids := handlers.keys()
	handler_ids.sort()
	var expected_handlers := REQUIRED_HANDLERS.duplicate()
	expected_handlers.sort()
	if handler_ids != expected_handlers:
		failures.append("ENV-BIND-19 drift: registered handler set changed.")
	for handler_id in REQUIRED_HANDLERS:
		var contract: Dictionary = handlers.get(handler_id, {})
		if contract.is_empty() or str(contract.get("rng", "")) != "none" \
				or not bool(contract.get("persistent", false)) or not bool(contract.get("atomic", false)):
			failures.append("ENV-BIND-19 handler contract is not persistent/atomic/RNG-free: %s" % handler_id)
	if OperationRegistryScript.MIN_TARGET_SIZE != 44.0:
		failures.append("ENV-BIND-08 drift: minimum target size is not 44px.")
	var identity := OperationRegistryScript.parse_owned_identity("crew::favor:package")
	if str(identity.get("owner_namespace", "")) != "crew" or str(identity.get("stable_object_id", "")) != "favor:package":
		failures.append("ENV-BIND-03/04 owned identity parser changed.")


func _check_owner_scoped_registration(failures: Array) -> void:
	var valid := {
		"source": {"domain": "crew", "owner_id": "crew", "definition_id": "crew_favor_delivery"},
		"public_instance_token": "attempt_7",
		"node_id": "gas_station_casino",
		"definition": {"id": "crew_favor_delivery", "sequence": {}},
	}
	var expected_key := "crew::crew::crew_favor_delivery::attempt_7"
	if _instance_key(valid) != expected_key or not _validate_registration(valid).is_empty():
		failures.append("Generic owner-scoped registration rejected the worked interface.")
	var missing_owner := valid.duplicate(true)
	missing_owner["source"]["owner_id"] = ""
	_failures_must_be(missing_owner, 1, "missing owner", failures)
	var hidden := valid.duplicate(true)
	hidden["public_instance_token"] = "traitor_candidate"
	_failures_must_be(hidden, 1, "hidden semantic id", failures)
	var proof_special_case := valid.duplicate(true)
	proof_special_case["dispatch_special_case"] = "crew_favor_delivery"
	_failures_must_be(proof_special_case, 1, "proof special-case field", failures)


func _check_diagnostic_wrapper(failures: Array) -> void:
	var wrapped := AdapterScript.wrap_validation_errors(
		"crew_package", "crew_favor_delivery", "crew_favor_delivery", "attempt_7",
		["Shared validator message preserved.", "res://private/validator.gd:17 rejected content"]
	)
	if wrapped.size() != 2 or str(_dict(wrapped[0]).get("error", "")) == str(_dict(wrapped[1]).get("error", "")):
		failures.append("Diagnostic wrapper did not retain one safe message and redact one path-bearing message.")
	var expected_keys := ["definition_id", "error", "error_id", "instance_id", "source_id", "source_kind"]
	for diagnostic_value in wrapped:
		var diagnostic := _dict(diagnostic_value)
		var keys := diagnostic.keys()
		keys.sort()
		if keys != expected_keys or not str(diagnostic.get("error_id", "")).begins_with("world_sequence_validation_") \
				or JSON.stringify(diagnostic).contains("res://"):
			failures.append("Diagnostic wrapper schema, stable id, or path redaction drifted: %s" % JSON.stringify(diagnostic))
	var reversed := AdapterScript.wrap_validation_errors(
		"crew_package", "crew_favor_delivery", "crew_favor_delivery", "attempt_7",
		["res://private/validator.gd:17 rejected content", "Shared validator message preserved."]
	)
	if JSON.stringify(wrapped) != JSON.stringify(reversed):
		failures.append("Diagnostic wrapper order depends on shared-validator error order.")
	var hidden_source := AdapterScript.wrap_validation_errors("crew_package", "traitor_candidate", "safe_definition", "attempt_7", ["traitor identity rejected"])
	if JSON.stringify(hidden_source).contains("traitor") or str(_dict(hidden_source[0]).get("source_id", "")) != "redacted":
		failures.append("Diagnostic wrapper leaked a forbidden hidden identifier or message.")


func _check_hidden_identifier_guard(failures: Array) -> void:
	var ordinary_prose := {"label": "A traitor is mentioned in ordinary authored dialogue.", "prompt": "Ask about the clue in public."}
	if not AdapterScript.validate_public_identifiers(ordinary_prose).is_empty():
		failures.append("Hidden identifier guard rejected ordinary prose instead of identifier-bearing fields only.")
	for hostile in [
		{"stable_object_id": "traitor_candidate"},
		{"actor_id": "turncoat_actor"},
		{"capability": "clue_eligibility"},
		{"public_instance_token": "actor_0123456789abcdef0123456789abcdef"},
		{"local_state_schema": {"grievance_weight": {"type": "int"}}},
	]:
		if AdapterScript.validate_public_identifiers(hostile).is_empty():
			failures.append("Hidden identifier guard accepted hostile public identity: %s" % JSON.stringify(hostile))
	var signature_only := {"sequence_signature": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}
	if not AdapterScript.validate_public_identifiers(signature_only).is_empty():
		failures.append("Hidden identifier guard confused the required content signature with a public identity hash.")


func _validate_registration(value: Dictionary) -> Array:
	var failures: Array = []
	var allowed := ["source", "public_instance_token", "node_id", "definition"]
	for key_value in value.keys():
		if not allowed.has(str(key_value)):
			failures.append("unknown:%s" % str(key_value))
	var source: Dictionary = value.get("source", {})
	for field in ["owner_id", "definition_id"]:
		var item := str(source.get(field, ""))
		if not _canonical_id(item):
			failures.append("invalid:%s" % field)
	if not _canonical_id(str(value.get("public_instance_token", ""))):
		failures.append("invalid:public_instance_token")
	if not ALLOWED_SOURCE_DOMAINS.has(str(source.get("domain", ""))):
		failures.append("invalid:source_domain")
	if str(value.get("node_id", "")).strip_edges().is_empty():
		failures.append("invalid:node_id")
	var serialized := JSON.stringify(value).to_lower()
	for hidden_word in ["traitor", "betrayal", "the_turn", "grievance", "clue"]:
		if serialized.contains(hidden_word):
			failures.append("hidden:%s" % hidden_word)
	return failures


func _instance_key(value: Dictionary) -> String:
	return "%s::%s::%s::%s" % [
		str(_dict(value.get("source", {})).get("domain", "")), str(_dict(value.get("source", {})).get("owner_id", "")),
		str(_dict(value.get("source", {})).get("definition_id", "")), str(value.get("public_instance_token", "")),
	]


func _canonical_id(value: String) -> bool:
	if value.is_empty() or value != value.strip_edges():
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) \
				and code != 95 and code != 45:
			return false
	return true


func _check_exact_array(label: String, actual: Array, expected: Array, failures: Array) -> void:
	if actual != expected:
		failures.append("%s changed: expected %s, got %s." % [label, JSON.stringify(expected), JSON.stringify(actual)])


func _diagnostics_include(diagnostics: Array, source_kind: String, source_id: String, error: String) -> bool:
	for diagnostic_value in diagnostics:
		var diagnostic := _dict(diagnostic_value)
		if str(diagnostic.get("source_kind", "")) == source_kind and str(diagnostic.get("source_id", "")) == source_id \
				and str(diagnostic.get("error", "")) == error:
			return true
	return false


func _failures_must_be(value: Dictionary, expected: int, label: String, failures: Array) -> void:
	var actual := _validate_registration(value).size()
	if actual != expected:
		failures.append("Adapter registration %s returned %d failures, expected %d." % [label, actual, expected])


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary) if typeof(value) == TYPE_DICTIONARY else {}
