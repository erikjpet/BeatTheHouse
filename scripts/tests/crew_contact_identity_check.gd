extends SceneTree
const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	var id := "event:crew_contact_rook"
	var row := {"presentation_id":id,"active":true,"physical":true}
	var environment := {"object_manifest":{"rows":[row]}}
	var before := environment.duplicate(true)
	_check(Controller._crew_contact_has_physical_manifest_row(environment,id),"exact active physical contact retains its identity")
	_check(environment == before,"identity lookup does not mutate authority")
	_check(not Controller._crew_contact_has_physical_manifest_row({},id),"missing manifest cannot mint contact identity")
	for field in ["active","physical"]:
		var changed := environment.duplicate(true)
		changed.object_manifest.rows[0][field] = false
		_check(not Controller._crew_contact_has_physical_manifest_row(changed,id),field + " false cannot retain contact identity")
	_check(not Controller._crew_contact_has_physical_manifest_row(environment,"event:crew_contact_switch"),"other contact cannot borrow geometry")
	var retired := environment.duplicate(true)
	retired["resolved_event_ids"] = ["crew_contact_rook"]
	_check(not Controller._crew_contact_has_physical_manifest_row(retired,id),"resolved contact is not resurrected")
	for field in ["presentation_object_id","instance_object_id","object_id","stable_object_id"]:
		_check(Controller._crew_contact_has_physical_manifest_row({"object_manifest":{"rows":[{field:id,"active":true,"physical":true}]}},id),"supported manifest identity field " + field)
	print("CREW_CONTACT_IDENTITY checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
func _check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
