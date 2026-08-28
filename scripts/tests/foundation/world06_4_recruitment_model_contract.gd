extends SceneTree

const Recruitment := preload("res://scripts/core/crew_recruitment_model.gd")
const MEMBERS := [
	"crew_rook", "crew_switch", "crew_mags", "crew_knuckles",
	"crew_velvet", "crew_bishop", "crew_lucky",
]
const OUTCOMES := ["refused", "deferred", "accepted"]


func _initialize() -> void:
	var failures: Array = []
	_check_landed_definitions_unchanged(failures)
	_check_all_first_meetings_and_fallbacks(failures)
	_check_distinct_aftermath_and_transitions(failures)
	_check_contact_standing(failures)
	_check_save_determinism_and_fail_closed(failures)
	_check_hidden_state_privacy(failures)
	if failures.is_empty():
		print("world06_4 recruitment model contract passed")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)


func _check_landed_definitions_unchanged(failures: Array) -> void:
	var config := Recruitment.config()
	if int(config.get("schema_version", 0)) != 1 or int(config.get("associate_trust", -1)) != 30 \
			or int(config.get("presence_rotate_actions", -1)) != 6:
		failures.append("Recruitment depth changed the landed schema, Associate threshold, or six-action presence rotation.")
	if Recruitment.MEMBER_IDS != MEMBERS or not Recruitment.validate_content().is_empty():
		failures.append("Recruitment depth changed the landed seven-member order or invalidated authored content.")
	var expected_events := ["recruitment_rook_signpost", "recruitment_switch", "recruitment_mags", "recruitment_knuckles", "recruitment_velvet", "recruitment_bishop", "recruitment_lucky"]
	var expected_contacts := ["crew_contact_rook", "crew_contact_switch", "crew_contact_mags", "crew_contact_knuckles", "crew_contact_velvet", "crew_contact_bishop", "crew_contact_lucky"]
	if Recruitment.recruitment_event_ids() != expected_events or Recruitment.contact_event_ids() != expected_contacts:
		failures.append("Recruitment depth changed the landed recruitment/contact event identities.")
	for member_id in MEMBERS:
		var definition := Recruitment.member_definition(member_id)
		if _dict(definition.get("primary", {})).is_empty() or _dict(definition.get("fallback", {})).is_empty() \
				or _array(definition.get("presence", [])).is_empty():
			failures.append("Recruitment depth lost %s primary, fallback, or seeded itinerary data." % member_id)


func _check_all_first_meetings_and_fallbacks(failures: Array) -> void:
	for member_id in MEMBERS:
		for path_kind in ["primary", "fallback"]:
			var path := Recruitment.meeting_path_public(member_id, path_kind)
			if str(path.get("member_id", "")) != member_id or str(path.get("path_kind", "")) != path_kind \
					or str(path.get("event_id", "")).is_empty() or str(path.get("contact_event_id", "")).is_empty():
				failures.append("%s %s meeting did not retain its landed event and placement identity." % [member_id, path_kind])
			for outcome in OUTCOMES:
				var state := Recruitment.record_first_meeting(Recruitment.new_encounter_state(), member_id, path_kind, outcome, 7)
				var public := Recruitment.encounter_public_state(state, member_id)
				if str(public.get("meeting_state", "")) != outcome or str(public.get("path_kind", "")) != path_kind \
						or str(public.get("aftermath_id", "")) != "%s_%s" % [member_id, outcome] \
						or bool(public.get("contact_available", false)) != (outcome == "accepted"):
					failures.append("%s %s %s meeting lacked its distinct public aftermath." % [member_id, path_kind, outcome])
				var expected_actor := "guarded" if outcome == "refused" else ("waiting" if outcome == "deferred" else "contact")
				if str(public.get("actor_state", "")) != expected_actor:
					failures.append("%s %s aftermath did not preserve actor state %s." % [member_id, outcome, expected_actor])


func _check_distinct_aftermath_and_transitions(failures: Array) -> void:
	var state := Recruitment.new_encounter_state()
	state = Recruitment.record_first_meeting(state, "crew_bishop", "fallback", "deferred", 3)
	state = Recruitment.record_first_meeting(state, "crew_bishop", "primary", "accepted", 8)
	var public := Recruitment.encounter_public_state(state, "crew_bishop")
	if str(public.get("first_path_kind", "")) != "fallback" or str(public.get("first_outcome", "")) != "deferred" \
			or str(public.get("path_kind", "")) != "primary" or str(public.get("meeting_state", "")) != "accepted":
		failures.append("Bishop's landed two-beat deferral did not survive into accepted aftermath.")
	var history := _array(_dict(_dict(state.get("meetings", {})).get("crew_bishop", {})).get("history", []))
	if history.size() != 2:
		failures.append("Distinct deferral and acceptance facts were not both retained.")
	var accepted_exact := JSON.stringify(state)
	state = Recruitment.record_first_meeting(state, "crew_bishop", "fallback", "refused", 9)
	if JSON.stringify(state) != accepted_exact:
		failures.append("A completed recruitment could be downgraded by later refusal staging.")
	var deferred := Recruitment.record_first_meeting(Recruitment.new_encounter_state(), "crew_switch", "primary", "deferred", 2)
	var replay := Recruitment.record_first_meeting(deferred, "crew_switch", "primary", "deferred", 2)
	if JSON.stringify(replay) != JSON.stringify(deferred):
		failures.append("Identical meeting fact replay duplicated aftermath.")


func _check_contact_standing(failures: Array) -> void:
	for member_id in MEMBERS:
		var accepted := Recruitment.record_first_meeting(Recruitment.new_encounter_state(), member_id, "primary", "accepted", 1)
		for fixture in [
			["marker", false, false, "familiar"],
			["associate", false, true, "job_out"],
			["made", false, false, "trusted"],
			["inner_circle", true, false, "aggrieved"],
		]:
			var contacted := Recruitment.record_contact(accepted, member_id, str(fixture[0]), bool(fixture[1]), bool(fixture[2]), 12)
			var public := Recruitment.encounter_public_state(contacted, member_id)
			if str(public.get("standing", "")) != str(fixture[0]) or str(public.get("contact_state", "")) != str(fixture[3]):
				failures.append("%s contact did not reflect public standing/job/aggrieved greeting state." % member_id)
	var unmet := Recruitment.new_encounter_state()
	if JSON.stringify(Recruitment.record_contact(unmet, "crew_switch", "associate", false, false, 1)) != JSON.stringify(unmet):
		failures.append("An unmet member acquired contact standing before acceptance.")


func _check_save_determinism_and_fail_closed(failures: Array) -> void:
	var first := Recruitment.new_encounter_state()
	var second := Recruitment.new_encounter_state()
	for member_id in MEMBERS:
		first = Recruitment.record_first_meeting(first, member_id, "fallback", "accepted", MEMBERS.find(member_id) + 1)
		second = Recruitment.record_first_meeting(second, member_id, "fallback", "accepted", MEMBERS.find(member_id) + 1)
		first = Recruitment.record_contact(first, member_id, "associate", false, false, 20)
		second = Recruitment.record_contact(second, member_id, "associate", false, false, 20)
	if JSON.stringify(first) != JSON.stringify(second):
		failures.append("Same recruitment facts did not reproduce byte-identically.")
	var restored := Recruitment.normalize_encounter_state(first)
	if JSON.stringify(restored) != JSON.stringify(first):
		failures.append("Recruitment meeting/contact aftermath did not save round-trip byte-identically.")
	for mutation in ["schema", "extra", "member", "outcome", "path", "contact"]:
		var hostile := first.duplicate(true)
		match mutation:
			"schema": hostile["schema_version"] = 2
			"extra": hostile["hidden"] = true
			"member":
				var meetings := _dict(hostile.get("meetings", {})); meetings["crew_switch"]["member_id"] = "crew_other"; hostile["meetings"] = meetings
			"outcome":
				var meetings := _dict(hostile.get("meetings", {})); meetings["crew_switch"]["outcome"] = "maybe"; hostile["meetings"] = meetings
			"path":
				var meetings := _dict(hostile.get("meetings", {})); meetings["crew_switch"]["path_kind"] = "remote"; hostile["meetings"] = meetings
			"contact":
				var contacts := _dict(hostile.get("contacts", {})); contacts["crew_switch"]["contact_state"] = "weighted"; hostile["contacts"] = contacts
		if not Recruitment.normalize_encounter_state(hostile).is_empty():
			failures.append("Malformed recruitment save did not fail closed: %s." % mutation)


func _check_hidden_state_privacy(failures: Array) -> void:
	var state := Recruitment.record_first_meeting(Recruitment.new_encounter_state(), "crew_knuckles", "primary", "accepted", 1)
	state = Recruitment.record_contact(state, "crew_knuckles", "associate", true, false, 2)
	var public_text := JSON.stringify(Recruitment.encounter_public_state(state, "crew_knuckles")).to_lower()
	var path_text := JSON.stringify(Recruitment.meeting_path_public("crew_knuckles", "primary")).to_lower()
	for forbidden in ["turn_eligible", "turn_eligibility", "grievance_weight", "selection_weight", "betrayal_score", "rng_state", "seed_value"]:
		if public_text.contains(forbidden) or path_text.contains(forbidden):
			failures.append("Recruitment public model exposed hidden Turn/grievance authority: %s." % forbidden)
	var source := FileAccess.get_file_as_string("res://scripts/core/crew_recruitment_model.gd").to_lower()
	for forbidden in ["turn_eligibility", "grievance_weight", "selection_weight"]:
		if source.contains(forbidden):
			failures.append("Recruitment model coupled to hidden Turn weighting: %s." % forbidden)


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
