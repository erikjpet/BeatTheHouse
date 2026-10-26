extends SceneTree

const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	var sealed := {"object_id":"event:chain06_cass_first_contact","object_type":"event","source_id":"chain06_cass_first_contact","owner_namespace":"event","label":"Cass Venn","enabled":true,"available_actions":[{"id":"inspect_event_choices","label":"Review responses"}],"focus_rect":{"x":0.4,"y":0.6,"w":0.05,"h":0.17},"scenario_layout_authority_digest":"sealed-geometry"}
	var before := sealed.duplicate(true)
	_check(Controller.restore_live_presentation_fields([sealed],[]).is_empty(),"Unavailable unresolved Cass must not survive solely through its sealed projection")
	var placeholder := {"object_id":sealed.object_id,"object_type":"event","visible":false,"enabled":false,"interactive":false,"manifest_live_membership_missing_event":true}
	_check(Controller.restore_live_presentation_fields([sealed],[placeholder]).is_empty(),"Inert manifest placement authority must not revive a missing live event")
	_check(sealed==before,"Filtering must leave sealed producer input unchanged")
	var live := {"object_id":sealed.object_id,"object_type":"event","source_id":sealed.source_id,"enabled":true,"visual_type":"character","short_description":"Come back when you are actually counting.","available_actions":[{"id":"inspect_event_choices","label":"Talk"}],"inline_actions":[],"focus_rect":{"x":0.1,"y":0.1,"w":0.1,"h":0.1},"scenario_layout_authority_digest":"not-geometry-authority"}
	var live_before := live.duplicate(true)
	var restored: Array=Controller.restore_live_presentation_fields([sealed],[live])
	_check(restored.size()==1,"An eligible live event must remain available")
	if restored.size()==1:
		_check(restored[0].available_actions==live.available_actions,"Conversation-first live action must replace generic sealed action")
		_check(restored[0].short_description==live.short_description,"Live condition summary must remain visible")
		_check(restored[0].focus_rect==sealed.focus_rect,"Live presence must not replace sealed geometry")
		_check(restored[0].scenario_layout_authority_digest==sealed.scenario_layout_authority_digest,"Live presence must not replace sealed layout authority")
		_check(restored[0].inline_actions.is_empty(),"Talk must not acquire direct consequence-bearing response tokens")
	_check(live==live_before,"Restoration must not mutate live producer input")
	var hidden_by_scenario := sealed.duplicate(true);hidden_by_scenario["visible"]=false;hidden_by_scenario["owner_namespace"]="scenario"
	var visible_live := live.duplicate(true);visible_live["visible"]=true
	var hidden: Array=Controller.restore_live_presentation_fields([hidden_by_scenario],[visible_live])
	_check(hidden.size()==1 and not bool(hidden[0].get("visible",true)),"Live fields must preserve an authoritative projection's visibility decision")
	var scenario_owned := sealed.duplicate(true);scenario_owned["owner_namespace"]="scenario"
	_check(Controller.restore_live_presentation_fields([scenario_owned],[]).size()==1,"Scenario-owned event records retain their independent producer authority")
	_check(Controller.restore_live_presentation_fields([sealed],[live],[sealed.source_id]).is_empty(),"Resolved events must stay retired even if an old live row exists")
	var fixture := {"object_id":"casino_fixture:host_desk","object_type":"casino_fixture","owner_namespace":"base","enabled":true}
	_check(Controller.restore_live_presentation_fields([fixture],[]).size()==1,"Static fixtures must not be mistaken for dynamic event membership")
	var service := {"object_id":"service:house_drink","object_type":"service","owner_namespace":"base"}
	_check(Controller.restore_live_presentation_fields([service],[]).is_empty(),"Existing service retirement must remain authoritative")
	var filtered: Array=Controller.restore_live_presentation_fields([sealed],[placeholder])
	_check(Controller.append_unsealed_live_records(filtered,[placeholder],[sealed]).is_empty(),"The later append pass must not resurrect a retired sealed event")
	var new_live := live.duplicate(true);new_live["object_id"]="event:new_contact"
	_check(Controller.append_unsealed_live_records([], [new_live], [sealed]).size()==1,"A newly available unsealed event still appears through its ordinary producer")
	_check(Controller.restore_live_presentation_fields([sealed],[live])==restored,"Repeated projection is deterministic and does not consume event state")
	var consumed := sealed.duplicate(true);consumed["slot_family"]="event"
	var fixed_consumed := consumed.duplicate(true);fixed_consumed["slot_family"]="fixed"
	var owned_consumed := consumed.duplicate(true);owned_consumed["owner_namespace"]="scenario"
	_check(Controller._without_resolved_event_presence([consumed,fixed_consumed,owned_consumed],[sealed.source_id])==[fixed_consumed,owned_consumed],"Consumed ordinary event is removed before finalized layout validation; fixed/scenario ownership remains")
	for failure in failures:push_error(failure)
	print("LIVE_EVENT_MEMBERSHIP checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
