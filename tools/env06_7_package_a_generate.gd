extends SceneTree

const SequenceSchema := preload("res://scripts/core/scenario_sequence_schema.gd")
const OperationRegistry := preload("res://scripts/core/scenario_operation_registry.gd")
const SequenceCatalog := preload("res://scripts/core/scenario_sequence_catalog.gd")
const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_shops_streets.json"

const CONFIGS := [
	{"id":"corner_store_lotto_fever","archetype":"corner_store","arrival":"A ticket queue bends around a stock rack while the last-number board hangs over the counter.","task":"Hold the ticket line","object_a":"queue_rail","object_b":"number_board","actor":"lotto_regular","verb_a":"mark_place","verb_b":"verify_number","fail":"yield_place","tags":["queue_place","number_dispute","stock_pressure"],"world":"economy_stock","success":"celebration_layout","failure":"angry_queue","ignored":"sold_out_counter"},
	{"id":"corner_store_aftermath","archetype":"corner_store","arrival":"Boarded glass narrows the aisle while a tagged object lies between the clerk and a moving plainclothes officer.","task":"Handle the suspect object","object_a":"boarded_glass","object_b":"suspect_object","actor":"plainclothes_officer","verb_a":"trace_evidence","verb_b":"recover_object","fail":"flag_object","tags":["evidence_route","plainclothes_patrol","restricted_access"],"world":"security_evidence","success":"quiet_recovery","failure":"police_hold","ignored":"watched_aisle"},
	{"id":"corner_store_dead_shift","archetype":"corner_store","arrival":"A dark cooler and a flickering breaker split the store into exposed and private aisles.","task":"Restore the cooler circuit","object_a":"breaker_panel","object_b":"cooler_circuit","actor":"night_clerk","verb_a":"isolate_breaker","verb_b":"restore_circuit","fail":"leave_dark","tags":["circuit_stages","visibility_trade","rumor_access"],"world":"rumor_surveillance","success":"lit_service","failure":"private_darkness","ignored":"flicker_lockout"},
	{"id":"corner_store_inventory_night","archetype":"corner_store","arrival":"Rolling count cages close two aisles while shelf tags form a visible discrepancy trail.","task":"Resolve the shelf count","object_a":"count_cage","object_b":"discrepancy_shelf","actor":"inventory_clerk","verb_a":"compare_tags","verb_b":"recount_shelf","fail":"quarantine_stock","tags":["section_count","discrepancy_trail","stock_rearrange"],"world":"economy_inventory","success":"reopened_sections","failure":"quarantined_section","ignored":"closed_aisles"},
	{"id":"back_alley_street_craps","archetype":"back_alley","arrival":"Chalk, a curb backstop, and waiting shooters form a physical dice ring beside a clear escape lane.","task":"Take a street shooter turn","object_a":"chalk_ring","object_b":"lookout_marker","actor":"street_shooter","verb_a":"read_ring","verb_b":"shoot_dice","fail":"answer_lookout","tags":["chalk_assembly","public_craps_fact","lookout_escalation"],"world":"game_craps_public","success":"ring_continues","failure":"ring_relocated","ignored":"ring_dispersed"},
	{"id":"back_alley_cruiser_parked","archetype":"back_alley","arrival":"A parked cruiser throws a hard sightline across stacked cover and the target doorway.","task":"Cross the patrol sightline","object_a":"cruiser_beam","object_b":"stacked_cover","actor":"patrol_officer","verb_a":"map_sightline","verb_b":"move_cover","fail":"create_diversion","tags":["sightline_cover","cruiser_reposition","public_sweep_fact"],"world":"sweep_public_pressure","success":"cruiser_departed","failure":"diverted_patrol","ignored":"watched_route"},
	{"id":"back_alley_fence_night","archetype":"back_alley","arrival":"Three visible goods lots occupy separate stations as buyers rotate toward a contested crate.","task":"Resolve the contested lot","object_a":"goods_lot","object_b":"auth_station","actor":"rotating_buyer","verb_a":"inspect_marks","verb_b":"authenticate_lot","fail":"broker_lot","tags":["lot_rotation","authentication","stall_control"],"world":"economy_fence","success":"verified_stall","failure":"brokered_exit","ignored":"buyer_control"},
	{"id":"back_alley_nothing_moving","archetype":"back_alley","arrival":"Closed shutters expose three physical traces: a wet print, dragged crate line, and snapped seal.","task":"Follow the silent trail","object_a":"three_traces","object_b":"shutter_gap","actor":"returning_regular","verb_a":"compare_traces","verb_b":"follow_trail","fail":"erase_trail","tags":["three_trace_investigation","exit_discovery","returning_actor"],"world":"rumor_route","success":"opened_follow_exit","failure":"erased_rumor_exit","ignored":"empty_alley"},
	{"id":"pawn_shop_estate_lot_day","archetype":"pawn_shop","arrival":"Estate carts divide the floor into appraisal, display, and police-hold lanes.","task":"Establish the estate provenance","object_a":"estate_cart","object_b":"provenance_marks","actor":"estate_appraiser","verb_a":"stage_lot","verb_b":"match_provenance","fail":"return_lot","tags":["appraisal_flow","provenance_clues","lot_zones"],"world":"economy_provenance","success":"displayed_lot","failure":"returned_cart","ignored":"quarantined_lot"},
	{"id":"pawn_shop_serial_check_day","archetype":"pawn_shop","arrival":"A serial station and taped hold zone restrict the cases while records wait beside one tagged object.","task":"Trace the held serial","object_a":"serial_station","object_b":"hold_object","actor":"records_clerk","verb_a":"copy_serial","verb_b":"trace_record","fail":"withdraw_object","tags":["serial_trace","police_hold","record_object_match"],"world":"security_inventory","success":"disclosed_hold","failure":"withdrawn_stock","ignored":"waiting_hold"},
	{"id":"pawn_shop_sals_mood","archetype":"pawn_shop","arrival":"Sal moves between the counter and back room while three concrete shop jobs remain visibly unfinished.","task":"Read and answer Sal's shift","object_a":"unfinished_jobs","object_b":"private_appraisal","actor":"sal_shopkeeper","verb_a":"finish_shop_task","verb_b":"read_sal_route","fail":"close_shutters","tags":["actor_mood_route","shop_task","deal_access"],"world":"service_appraisal","success":"reopened_counter","failure":"closed_shutters","ignored":"private_appraisal"},
]

func _init() -> void:
	var package_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE_PATH))
	if typeof(package_value) != TYPE_DICTIONARY:
		push_error("Package JSON is unreadable.")
		quit(1)
		return
	var package := package_value as Dictionary
	var entries := package.get("scenarios", []) as Array
	var retained: Array = []
	for entry_value in entries:
		var entry := entry_value as Dictionary
		if str(entry.get("scenario_id", "")) == "corner_store_delivery_day": retained.append(entry)
	for config in CONFIGS:
		# Calculate from the exact JSON type envelope that production reloads;
		# Godot's JSON parser normalizes authored number types.
		var entry := JSON.parse_string(JSON.stringify(_entry(config))) as Dictionary
		var definition := {"id": config.id, "archetype_id": config.archetype, "sequence": entry.sequence}
		entry.sequence.sequence_signature = SequenceSchema.calculated_signature_hash(definition)
		var failures := SequenceSchema.validate_definition(definition, OperationRegistry, {})
		if not failures.is_empty():
			push_error("%s: %s" % [config.id, "; ".join(failures)])
			quit(1)
			return
		retained.append(entry)
	package.scenarios = retained
	var file := FileAccess.open(PACKAGE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(package, "  ", false) + "\n")
	file.close()
	var catalog := SequenceCatalog.load_catalog()
	if not bool(catalog.get("ok", false)):
		push_error("Generated catalog rejected: %s" % "; ".join(catalog.get("failures", [])))
		quit(1)
		return
	var expected := ["corner_store_delivery_day"]
	for config in CONFIGS: expected.append(str(config.id))
	var package_rows: Array = catalog.get("packages", [])
	var actual: Array = []
	for package_row_value in package_rows:
		var package_row := package_row_value as Dictionary
		if str(package_row.get("package_id", "")) == "env06_7_shops_streets": actual = package_row.get("scenario_ids", [])
	expected.sort()
	actual.sort()
	if actual != expected:
		push_error("Generated Package A inventory mismatch: %s" % JSON.stringify(actual))
		quit(1)
		return
	print("ENV06_7_PACKAGE_A_GENERATED count=%d" % retained.size())
	quit(0)

func _entry(c: Dictionary) -> Dictionary:
	var sid := str(c.id)
	var task := str(c.task)
	var sequence := {
		"schema_version": 2,
		"local_state_schema": {"path":{"type":"enum","default":"none","values":["none","success","failure","ignored","refused","interrupted"],"visibility":"private"}},
		"phase_graph": {"initial_phase":"arrival","phases":[
			_phase_arrival(c), _phase_work(c), _phase_resolution(c)
		]},
		"objectives": [{"id":"complete_%s" % c.object_a,"label":task,"progress_label":"%s progression" % task,"steps":[
			{"id":c.verb_a,"label":_label(c.verb_a),"kind":"command","command_id":c.verb_a},
			{"id":c.verb_b,"label":_label(c.verb_b),"kind":"command","command_id":c.verb_b}
		],"outcomes":["success","failure","ignore","cancel"]}],
		"reentry_policy":{"partial":"resume","terminal":"aftermath","expired":"expired"},
		"expiry":{"boundary":"night_end","after":1,"policy":"ignore"},
		"cleanup":{"operations":[
			_remove("scene_ops",sid+"_cleanup_a",c.object_a), _remove("scene_ops",sid+"_cleanup_b",c.object_b),
			_remove("interaction_ops",sid+"_cleanup_task",c.object_a), _remove("interaction_ops",sid+"_cleanup_work",c.object_b), _remove("interaction_ops",sid+"_cleanup_exit",sid+"_exit"),
			{"family":"actor_ops","op":"despawn","receipt_id":sid+"_cleanup_actor","owner_namespace":"scenario","stable_object_id":c.actor}
		]},
		"aftermath":{
			"success":_aftermath(c,"success",c.success,"open"),
			"failure":_aftermath(c,"failure",c.failure,"restricted"),
			"ignored":_aftermath(c,"ignored",c.ignored,"occupied"),
			"refused":_aftermath(c,"refused",str(c.ignored)+"_refused","closed"),
			"interrupted":_aftermath(c,"interrupted",str(c.object_b)+"_abandoned","paused")
		},
		"mechanic_tags":c.tags + [c.world], "sequence_signature":"", "owner_exceptions":[], "fact_subscriptions":[
			{"fact_type":"travel_departed","handler":"set_local","inputs":{"key":"path","value":"interrupted"}}
		],
		"completion_contract":{"arrival_readable":true,"semantic_changes":true,"scenario_interaction":true,"action_boundaries":true,"choice_or_failure":true,"material_outcomes":true,"revisit_coverage":true,"world_connection":true,"primary_verb":true,"feedback_and_exit":true},
		"declared_targets":{"scene_objects":[],"interactions":[],"actors":[],"services":[],"games":[],"routes":[],"anchors":[],"zones":[]}
	}
	return {"scenario_id":sid,"sequence":sequence,"authoring":{
		"arrival_summary":c.arrival,"player_verbs":[c.verb_a,c.verb_b,c.fail,"ignore_sequence","refuse_sequence"],
		"world_connections":[c.world,"travel_interruption","safe_exit"],
		"references":{"objects":["scenario::%s" % c.object_a,"scenario::%s" % c.object_b]},
		"capture_ids":[sid+"_arrival",sid+"_work",sid+"_success",sid+"_failure",sid+"_ignored",sid+"_refused",sid+"_interrupted",sid+"_partial_revisit",sid+"_terminal_revisit",sid+"_reduced_motion",sid+"_small_screen",sid+"_hit_overlay"],
		"seed_evidence":{"proof_seed":sid+"_seed","expected_outcomes":["success","failure","ignored","refused","interrupted"],"save_boundaries":["arrival","work","resolution"],"cleanup_idempotent":true,"reentry_idempotent":true,"minimum_target_size":44},
		"masked_visual_explanations":{}
	}}

func _phase_arrival(c: Dictionary) -> Dictionary:
	var sid := str(c.id)
	return {"id":"arrival","label":_label(c.object_a),"arrival_feedback":c.arrival,"exit_prompt":"A marked exit remains open while you inspect the scene.","entry_conditions":[{"type":"always"}],"objective_ids":["complete_%s" % c.object_a],"advance_after_actions":0,
		"scene_ops":[_spawn(sid+"_arrival_a",c.object_a,_label(c.object_a),"primary_task","left","arrival"),_spawn(sid+"_arrival_b",c.object_b,_label(c.object_b),"evidence","right","unread")],
		"interaction_ops":[_interaction(sid+"_arrival_task",c.object_a,c.task,[ _action(c.verb_a,"Begin: "+_label(c.verb_a),"ui_accept","path","none"), _action("ignore_sequence","Ignore the scene","ui_down","path","ignored"), _action("refuse_sequence","Refuse the task","ui_cancel","path","refused")],false),_exit(c)],
		"actor_ops":[{"family":"actor_ops","op":"spawn","receipt_id":sid+"_arrival_actor","owner_namespace":"scenario","stable_object_id":c.actor,"actor":{"label":_label(c.actor),"actor_id":c.actor,"zone_id":"background","behavior":"work","route_id":sid+"_arrival_route","pose":"observing"}}],
		"transition_ops":[_transition(sid+"_arrival_stage","stage",str(c.arrival))],
		"branches":[{"id":sid+"_begin","condition":{"type":"command","command_id":c.verb_a},"next_phase":"work"},{"id":sid+"_ignore","condition":{"type":"command","command_id":"ignore_sequence"},"next_phase":"resolution"},{"id":sid+"_refuse","condition":{"type":"command","command_id":"refuse_sequence"},"next_phase":"resolution"},{"id":sid+"_depart","condition":{"type":"fact","fact_type":"travel_departed"},"next_phase":"resolution"}]}

func _phase_work(c: Dictionary) -> Dictionary:
	var sid := str(c.id)
	return {"id":"work","label":str(c.task),"arrival_feedback":"The first physical step exposes the second station and changes the actor's route.","exit_prompt":"The marked exit remains clear during the second step.","entry_conditions":[],"objective_ids":["complete_%s" % c.object_a],"advance_after_actions":0,
		"scene_ops":[{"family":"scene_ops","op":"move","receipt_id":sid+"_work_move","owner_namespace":"scenario","stable_object_id":c.object_a,"zone_id":"center"},{"family":"scene_ops","op":"set_appearance","receipt_id":sid+"_work_reveal","owner_namespace":"scenario","stable_object_id":c.object_b,"appearance":"active_station"}],
		"interaction_ops":[_interaction(sid+"_work_task",c.object_b,c.task,[_action(c.verb_b,_label(c.verb_b),"ui_accept","path","success"),_action(c.fail,_label(c.fail),"ui_right","path","failure")],false)],
		"actor_ops":[{"family":"actor_ops","op":"set_position","receipt_id":sid+"_work_actor","owner_namespace":"scenario","stable_object_id":c.actor,"zone_id":"service_lane"}],
		"transition_ops":[_transition(sid+"_work_change","scene_change","The scene physically shifts into its decisive second step.")],
		"branches":[{"id":sid+"_success","condition":{"type":"command","command_id":c.verb_b},"next_phase":"resolution"},{"id":sid+"_failure","condition":{"type":"command","command_id":c.fail},"next_phase":"resolution"},{"id":sid+"_work_depart","condition":{"type":"fact","fact_type":"travel_departed"},"next_phase":"resolution"}]}

func _phase_resolution(c: Dictionary) -> Dictionary:
	var sid := str(c.id)
	return {"id":"resolution","label":"Physical aftermath","arrival_feedback":"The room holds the chosen physical aftermath for revisit.","exit_prompt":"Leave through the marked clear route.","terminal":true,"entry_conditions":[],"objective_ids":[],"advance_after_actions":0,"scene_ops":[],"interaction_ops":[],"actor_ops":[],"transition_ops":[_transition(sid+"_resolution_feedback","feedback","The outcome is recorded once and its room changes persist.")],"branches":[
		{"id":sid+"_out_success","condition":{"type":"local_equals","key":"path","value":"success"},"outcome":"success"},{"id":sid+"_out_failure","condition":{"type":"local_equals","key":"path","value":"failure"},"outcome":"failure"},{"id":sid+"_out_ignored","condition":{"type":"local_equals","key":"path","value":"ignored"},"outcome":"ignored"},{"id":sid+"_out_refused","condition":{"type":"local_equals","key":"path","value":"refused"},"outcome":"refused"},{"id":sid+"_out_interrupted","condition":{"type":"local_equals","key":"path","value":"interrupted"},"outcome":"interrupted"}]}

func _spawn(receipt: String, stable_id: String, label: String, role: String, zone: String, state: String) -> Dictionary:
	return {"family":"scene_ops","op":"spawn","receipt_id":receipt,"owner_namespace":"scenario","stable_object_id":stable_id,"object":{"label":label,"role":role,"zone_id":zone,"bounds":{"w":72,"h":56},"visible":true,"enabled":true,"state":state,"appearance":stable_id}}

func _interaction(receipt: String, stable_id: String, label: String, actions: Array, safe: bool) -> Dictionary:
	var inputs: Array=[]
	for action in actions:
		if not inputs.has(action.input_action): inputs.append(action.input_action)
	return {"family":"interaction_ops","op":"add","receipt_id":receipt,"owner_namespace":"scenario","stable_object_id":stable_id,"interaction":{"owner_namespace":"scenario","stable_object_id":stable_id,"label":label,"state_label":"Available","prompt":"Choose a physical action at this station.","enabled":true,"disabled_reason":"","available_actions":actions,"input_actions":inputs,"non_color_state":"ready","focus_order":1,"hit_bounds":{"w":64,"h":56},"min_target_size":44,"safe_exit":safe,"alternate_exit":false}}

func _exit(c: Dictionary) -> Dictionary:
	return _interaction(str(c.id)+"_exit_add",str(c.id)+"_exit","Marked clear exit",[{"id":"leave_safely","label":"Leave safely","input_action":"ui_focus_next","non_color_state":"exit"}],true)

func _action(id: String, label: String, input: String, key: String, value: String) -> Dictionary:
	return {"id":id,"label":label,"input_action":input,"non_color_state":id,"handler":"set_local","inputs":{"key":key,"value":value}}

func _transition(receipt: String, op: String, message: String) -> Dictionary:
	var row := {"family":"transition_ops","op":op,"receipt_id":receipt,"owner_namespace":"scenario","stable_object_id":receipt,"channel":"room","message":message}
	if op == "stage": row.merge({"stage_id":receipt,"duration_boundaries":1,"reduced_motion_message":"The physical state is now in place."})
	elif op == "scene_change": row["change_id"] = receipt
	return row

func _aftermath(c: Dictionary, outcome: String, stable_id: String, state: String) -> Dictionary:
	var sid := str(c.id)
	return {"label":_label(stable_id),"revisit_feedback":"%s remains visible when the player returns." % _label(stable_id),"scene_ops":[_spawn(sid+"_after_"+outcome,stable_id,_label(stable_id),"aftermath","foreground",state)],"service_ops":[{"family":"service_ops","op":"add","receipt_id":sid+"_service_"+outcome,"owner_namespace":"scenario","stable_object_id":sid+"_service_"+outcome,"object":{"id":sid+"_service_"+outcome,"label":_label(outcome)+" access","enabled":outcome=="success","disabled_reason":"The physical aftermath restricts this service." if outcome!="success" else ""}}]}

func _remove(family: String, receipt: String, stable_id: String) -> Dictionary:
	var op := "despawn" if family=="actor_ops" else "remove"
	return {"family":family,"op":op,"receipt_id":receipt,"owner_namespace":"scenario","stable_object_id":stable_id}

func _label(value: String) -> String:
	return value.replace("_"," ").capitalize()
