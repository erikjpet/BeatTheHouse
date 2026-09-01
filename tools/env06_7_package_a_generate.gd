extends SceneTree

const SequenceSchema := preload("res://scripts/core/scenario_sequence_schema.gd")
const OperationRegistry := preload("res://scripts/core/scenario_operation_registry.gd")
const SequenceCatalog := preload("res://scripts/core/scenario_sequence_catalog.gd")
const PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_shops_streets.json"

const CONFIGS := [
	{"id":"corner_store_lotto_fever","archetype":"corner_store","arrival":"A ticket queue bends around a stock rack while the last-number board hangs over the counter.","task":"Hold the ticket line","object_a":"queue_rail","object_a_anchor":"package_a_lotto_queue","object_b":"number_board","actor":"lotto_regular","verb_a":"mark_place","verb_b":"verify_number","fail":"yield_place","tags":["queue_place","number_dispute","stock_pressure"],"world":"economy_stock","success":"celebration_layout","failure":"angry_queue","ignored":"sold_out_counter"},
	{"id":"corner_store_aftermath","archetype":"corner_store","arrival":"Boarded glass narrows the aisle while a tagged object lies between the clerk and a moving plainclothes officer.","task":"Handle the suspect object","object_a":"boarded_glass","object_b":"suspect_object","actor":"plainclothes_officer","verb_a":"trace_evidence","verb_b":"recover_object","fail":"flag_object","tags":["evidence_route","plainclothes_patrol","restricted_access"],"world":"security_evidence","success":"quiet_recovery","failure":"police_hold","ignored":"watched_aisle"},
	{"id":"corner_store_dead_shift","archetype":"corner_store","arrival":"A dark cooler and a flickering breaker split the store into exposed and private aisles.","task":"Restore the cooler circuit","object_a":"breaker_panel","object_a_anchor":"package_a_dead_breaker","object_a_zone":"foreground","object_b":"cooler_circuit","actor":"night_clerk","exit_anchor":"package_a_dead_shift_exit","verb_a":"isolate_breaker","verb_b":"restore_circuit","fail":"leave_dark","tags":["circuit_stages","visibility_trade","rumor_access"],"world":"rumor_surveillance","success":"lit_service","failure":"private_darkness","ignored":"flicker_lockout"},
	{"id":"corner_store_inventory_night","archetype":"corner_store","arrival":"Rolling count cages close two aisles while shelf tags form a visible discrepancy trail.","task":"Resolve the shelf count","object_a":"count_cage","object_a_anchor":"delivery_manifest","object_b":"discrepancy_shelf","actor":"inventory_clerk","actor_anchor":"package_a_inventory_clerk_arrival","actor_work_anchor":"package_a_inventory_clerk_work","verb_a":"compare_tags","verb_b":"recount_shelf","fail":"quarantine_stock","tags":["section_count","discrepancy_trail","stock_rearrange"],"world":"economy_inventory","success":"reopened_sections","failure":"quarantined_section","ignored":"closed_aisles"},
	{"id":"back_alley_street_craps","archetype":"back_alley","arrival":"Chalk, a curb backstop, and waiting shooters form a physical dice ring beside a clear escape lane.","task":"Take a street shooter turn","object_a":"chalk_ring","object_b":"lookout_marker","actor":"street_shooter","actor_anchor":"alley_background_left","actor_work_anchor":"alley_background_right","verb_a":"read_ring","verb_b":"shoot_dice","fail":"answer_lookout","tags":["chalk_assembly","public_craps_fact","lookout_escalation"],"world":"game_craps_public","success":"ring_continues","failure":"ring_relocated","ignored":"ring_dispersed"},
	{"id":"back_alley_cruiser_parked","archetype":"back_alley","arrival":"A parked cruiser throws a hard sightline across stacked cover and the target doorway.","task":"Cross the patrol sightline","object_a":"cruiser_beam","object_b":"stacked_cover","actor":"patrol_officer","verb_a":"map_sightline","verb_b":"move_cover","fail":"create_diversion","tags":["sightline_cover","cruiser_reposition","public_sweep_fact"],"world":"sweep_public_pressure","success":"cruiser_departed","failure":"diverted_patrol","ignored":"watched_route"},
	{"id":"back_alley_fence_night","archetype":"back_alley","arrival":"Three visible goods lots occupy separate stations as buyers rotate toward a contested crate.","task":"Resolve the contested lot","object_a":"goods_lot","object_b":"auth_station","actor":"rotating_buyer","seal_exit_visual":true,"verb_a":"inspect_marks","verb_b":"authenticate_lot","fail":"broker_lot","tags":["lot_rotation","authentication","stall_control"],"world":"economy_fence","success":"verified_stall","failure":"brokered_exit","ignored":"buyer_control"},
	{"id":"back_alley_nothing_moving","archetype":"back_alley","arrival":"Closed shutters expose three physical traces: a wet print, dragged crate line, and snapped seal.","task":"Follow the silent trail","object_a":"three_traces","object_b":"shutter_gap","actor":"returning_regular","verb_a":"compare_traces","verb_b":"follow_trail","fail":"erase_trail","tags":["three_trace_investigation","exit_discovery","returning_actor"],"world":"rumor_route","success":"opened_follow_exit","failure":"erased_rumor_exit","ignored":"empty_alley"},
	{"id":"pawn_shop_estate_lot_day","archetype":"pawn_shop","arrival":"Estate carts divide the floor into appraisal, display, and police-hold lanes.","task":"Establish the estate provenance","object_a":"estate_cart","object_b":"provenance_marks","actor":"estate_appraiser","actor_anchor":"pawn_service_counter","actor_zone":"service_lane","verb_a":"stage_lot","verb_b":"match_provenance","fail":"return_lot","tags":["appraisal_flow","provenance_clues","lot_zones"],"world":"economy_provenance","success":"displayed_lot","failure":"returned_cart","ignored":"quarantined_lot"},
	{"id":"pawn_shop_serial_check_day","archetype":"pawn_shop","arrival":"A serial station and taped hold zone restrict the cases while records wait beside one tagged object.","task":"Trace the held serial","object_a":"serial_station","object_b":"hold_object","actor":"records_clerk","actor_anchor":"pawn_service_counter","actor_zone":"service_lane","verb_a":"copy_serial","verb_b":"trace_record","fail":"withdraw_object","tags":["serial_trace","police_hold","record_object_match"],"world":"security_inventory","success":"disclosed_hold","failure":"withdrawn_stock","ignored":"waiting_hold"},
	{"id":"pawn_shop_sals_mood","archetype":"pawn_shop","arrival":"Sal moves between the counter and back room while three concrete shop jobs remain visibly unfinished.","task":"Read and answer Sal's shift","object_a":"unfinished_jobs","object_b":"private_appraisal","actor":"sal_shopkeeper","actor_anchor":"pawn_service_counter","actor_zone":"service_lane","verb_a":"finish_shop_task","verb_b":"read_sal_route","fail":"close_shutters","tags":["actor_mood_route","shop_task","deal_access"],"world":"service_appraisal","success":"reopened_counter","failure":"closed_shutters","ignored":"private_appraisal"},
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
		if str(entry.get("scenario_id", "")) == "corner_store_delivery_day":
			entry = _repair_delivery_day(entry)
			var definition := {"id":"corner_store_delivery_day","archetype_id":"corner_store","sequence":entry.sequence}
			entry.sequence.sequence_signature = SequenceSchema.calculated_signature_hash(definition)
			retained.append(entry)
	for config in CONFIGS:
		# Calculate from the exact JSON type envelope that production reloads;
		# Godot's JSON parser normalizes authored number types.
		var entry := JSON.parse_string(JSON.stringify(_entry(config))) as Dictionary
		var definition := {"id": config.id, "archetype_id": config.archetype, "sequence": entry.sequence}
		entry.sequence.sequence_signature = SequenceSchema.calculated_signature_hash(definition)
		var failures := SequenceSchema.validate_definition(definition, OperationRegistry, _target_inventory(config))
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
	var world := _world_contract(c)
	var cleanup_operations := [
		_remove("scene_ops",sid+"_cleanup_a",c.object_a), _remove("scene_ops",sid+"_cleanup_b",c.object_b),
	]
	if bool(c.get("seal_exit_visual", true)):
		cleanup_operations.append(_remove("scene_ops",sid+"_cleanup_exit_visual",sid+"_exit"))
	cleanup_operations.append_array([
		_remove("interaction_ops",sid+"_cleanup_task",c.object_a), _remove("interaction_ops",sid+"_cleanup_work",c.object_b), _remove("interaction_ops",sid+"_cleanup_exit",sid+"_exit"),
		{"family":"actor_ops","op":"despawn","receipt_id":sid+"_cleanup_actor","owner_namespace":"scenario","stable_object_id":c.actor},
	])
	var sequence := {
		"schema_version": 2,
		"local_state_schema": {"path":{"type":"enum","default":"none","values":["none","success","failure","ignored","refused","interrupted","public"],"visibility":"private"},str(world.field):world.local_schema},
		"phase_graph": {"initial_phase":"arrival","phases":[
			_phase_arrival(c), _phase_work(c), _phase_resolution(c)
		]},
		"objectives": [{"id":"complete_%s" % c.object_a,"label":task,"progress_label":"%s progression" % task,"steps":[
			{"id":c.verb_a,"label":_label(c.verb_a),"kind":"command","command_id":c.verb_a},
			{"id":c.verb_b,"label":_label(c.verb_b),"kind":"command","command_id":c.verb_b}
		],"outcomes":["success","failure","ignore","cancel"]}],
		"reentry_policy":{"partial":"resume","terminal":"aftermath","expired":"expired"},
		"expiry":{"boundary":"night_end","after":1,"policy":"ignore"},
		"cleanup":{"operations":cleanup_operations},
		"aftermath":{
			"success":_aftermath(c,"success",c.success,"open"),
			"failure":_aftermath(c,"failure",c.failure,"restricted"),
			"ignored":_aftermath(c,"ignored",c.ignored,"occupied"),
			"refused":_aftermath(c,"refused",str(c.ignored)+"_refused","closed"),
			"interrupted":_aftermath(c,"interrupted",str(c.object_b)+"_abandoned","paused"),
			"public":_aftermath(c,"public",str(world.aftermath),str(world.state))
		},
		"mechanic_tags":c.tags + [c.world], "sequence_signature":"", "owner_exceptions":[], "fact_subscriptions":[
			{"fact_type":"travel_departed","handler":"set_local","inputs":{"key":"path","value":"interrupted"}},
			_world_subscription(world, str(world.field), true),
			_world_subscription(world, "path", false)
		],
		"completion_contract":{"arrival_readable":true,"semantic_changes":true,"scenario_interaction":true,"action_boundaries":true,"choice_or_failure":true,"material_outcomes":true,"revisit_coverage":true,"world_connection":true,"primary_verb":true,"feedback_and_exit":true},
		"declared_targets":{"scene_objects":[],"interactions":[],"actors":[],"services":[],"games":[],"routes":[],"anchors":_declared_anchors(c),"zones":["base::zone:left","base::zone:right","base::zone:center","base::zone:background","base::zone:service_lane","base::zone:foreground","base::zone:exit_lane"]}
	}
	return {"scenario_id":sid,"sequence":sequence,"authoring":{
		"arrival_summary":c.arrival,"player_verbs":[c.verb_a,c.verb_b,c.fail,"ignore_sequence","refuse_sequence"],
		"world_connections":[c.world,"travel_interruption","safe_exit"],
		"references":{"objects":["scenario::%s" % c.object_a,"scenario::%s" % c.object_b]},
		"capture_ids":[sid+"_arrival",sid+"_work",sid+"_success",sid+"_failure",sid+"_ignored",sid+"_refused",sid+"_interrupted",sid+"_partial_revisit",sid+"_terminal_revisit",sid+"_reduced_motion",sid+"_small_screen",sid+"_hit_overlay",sid+"_obstruction"],
		"seed_evidence":{"proof_seed":sid+"_seed","expected_outcomes":["success","failure","ignored","refused","interrupted","public"],"save_boundaries":["arrival","work","resolution"],"cleanup_idempotent":true,"reentry_idempotent":true,"minimum_target_size":44,"public_fact_type":world.fact_type,"public_fact_producer":world.producer,"public_payload_predicate":JSON.stringify(world.payload_equals),"public_projected_field":world.field,"public_projected_payload_key":world.selector,"public_material_aftermath":world.aftermath,"public_exactly_once_receipt":true,"accepted_public_facts":JSON.stringify(world.accepted_public_facts)},
		"masked_visual_explanations":{}
	}}

func _phase_arrival(c: Dictionary) -> Dictionary:
	var sid := str(c.id)
	var actor := {"label":_label(c.actor),"actor_id":c.actor,"zone_id":str(c.get("actor_zone", "background")),"behavior":"work","pose":"observing"}
	var actor_anchor := str(c.get("actor_anchor", "")).strip_edges()
	if not actor_anchor.is_empty(): actor["anchor_id"] = actor_anchor
	var object_a := _spawn(sid+"_arrival_a",c.object_a,_label(c.object_a),"primary_task",str(c.get("object_a_zone", "left")),"arrival")
	var object_a_anchor := str(c.get("object_a_anchor", "")).strip_edges()
	if not object_a_anchor.is_empty(): object_a["object"]["anchor_id"] = object_a_anchor
	var scene_ops := [object_a,_spawn(sid+"_arrival_b",c.object_b,_label(c.object_b),"evidence","right","unread")]
	if bool(c.get("seal_exit_visual", true)):
		var exit_visual := _spawn(sid+"_exit_visual",sid+"_exit","Marked Clear Exit","exit","exit_lane","clear")
		exit_visual["object"]["appearance"] = "marked_lane"
		var exit_anchor := str(c.get("exit_anchor", "")).strip_edges()
		if not exit_anchor.is_empty(): exit_visual["object"]["anchor_id"] = exit_anchor
		scene_ops.append(exit_visual)
	return {"id":"arrival","label":_label(c.object_a),"arrival_feedback":c.arrival,"exit_prompt":"A marked exit remains open while you inspect the scene.","entry_conditions":[{"type":"always"}],"objective_ids":["complete_%s" % c.object_a],"advance_after_actions":0,
		"scene_ops":scene_ops,
		"interaction_ops":[_interaction(sid+"_arrival_task",c.object_a,c.task,[ _action(c.verb_a,"Begin: "+_label(c.verb_a),"ui_accept","path","none"), _action("ignore_sequence","Ignore the scene","ui_down","path","ignored"), _action("refuse_sequence","Refuse the task","ui_cancel","path","refused")],false),_exit(c)],
		"actor_ops":[{"family":"actor_ops","op":"spawn","receipt_id":sid+"_arrival_actor","owner_namespace":"scenario","stable_object_id":c.actor,"actor":actor}],
		"transition_ops":[_transition(sid+"_arrival_stage","stage",str(c.arrival))],
		"branches":[{"id":sid+"_begin","condition":{"type":"command","command_id":c.verb_a},"next_phase":"work"},{"id":sid+"_ignore","condition":{"type":"command","command_id":"ignore_sequence"},"next_phase":"resolution"},{"id":sid+"_refuse","condition":{"type":"command","command_id":"refuse_sequence"},"next_phase":"resolution"},{"id":sid+"_leave_safely_arrival","condition":{"type":"command","command_id":"leave_safely"},"next_phase":"resolution"},{"id":sid+"_depart","condition":{"type":"fact","fact_type":"travel_departed"},"next_phase":"resolution"},{"id":sid+"_public_arrival","condition":{"type":"local_equals","key":"path","value":"public"},"next_phase":"resolution"}]}

func _phase_work(c: Dictionary) -> Dictionary:
	var sid := str(c.id)
	var actor_operation := {"family":"actor_ops","op":"set_position","receipt_id":sid+"_work_actor","owner_namespace":"scenario","stable_object_id":c.actor,"zone_id":"service_lane"}
	var actor_work_anchor := str(c.get("actor_work_anchor", "")).strip_edges()
	if not actor_work_anchor.is_empty(): actor_operation["anchor_id"] = actor_work_anchor
	var identity_ops := _identity_work_operations(c)
	var scene_ops := [{"family":"scene_ops","op":"move","receipt_id":sid+"_work_move","owner_namespace":"scenario","stable_object_id":c.object_a,"zone_id":"center"},{"family":"scene_ops","op":"set_appearance","receipt_id":sid+"_work_reveal","owner_namespace":"scenario","stable_object_id":c.object_b,"appearance":"active_station"}]
	scene_ops.append_array(identity_ops.scene_ops)
	var actor_ops := [actor_operation]
	actor_ops.append_array(identity_ops.actor_ops)
	var transition_ops := [_transition(sid+"_work_change","scene_change","The scene physically shifts into its decisive second step.")]
	transition_ops.append_array(identity_ops.transition_ops)
	return {"id":"work","label":str(c.task),"arrival_feedback":"The first physical step exposes the second station and changes the actor's route.","exit_prompt":"The marked exit remains clear during the second step.","entry_conditions":[],"objective_ids":["complete_%s" % c.object_a],"advance_after_actions":0,
		"scene_ops":scene_ops,
		"interaction_ops":[_remove("interaction_ops",sid+"_work_remove_"+str(c.object_a),c.object_a),_interaction(sid+"_work_task",c.object_b,c.task,[_action(c.verb_b,_label(c.verb_b),"ui_accept","path","success"),_action(c.fail,_label(c.fail),"ui_right","path","failure")],false)],
		"actor_ops":actor_ops,
		"transition_ops":transition_ops,
		"branches":[{"id":sid+"_success","condition":{"type":"command","command_id":c.verb_b},"next_phase":"resolution"},{"id":sid+"_failure","condition":{"type":"command","command_id":c.fail},"next_phase":"resolution"},{"id":sid+"_leave_safely_work","condition":{"type":"command","command_id":"leave_safely"},"next_phase":"resolution"},{"id":sid+"_work_depart","condition":{"type":"fact","fact_type":"travel_departed"},"next_phase":"resolution"},{"id":sid+"_public_work","condition":{"type":"local_equals","key":"path","value":"public"},"next_phase":"resolution"}]}

func _identity_work_operations(c: Dictionary) -> Dictionary:
	var sid := str(c.id)
	var scene_ops: Array = []
	var actor_ops: Array = []
	var transition_ops: Array = []
	match sid:
		"corner_store_lotto_fever":
			scene_ops = [_scene_change(sid, "queue_places", c.object_a, "set_state", "places_marked"), _scene_change(sid, "draw_digits", c.object_b, "set_appearance", "verified_digits"), _scene_move(sid, "queue_turn", c.object_a, "left")]
			actor_ops = [_actor_change(sid, "draw_pose", c.actor, "set_pose", "watching_draw"), _actor_change(sid, "draw_behavior", c.actor, "set_behavior", "watch")]
			transition_ops = [_cue(sid, "ticket_rattle", "sound"), _transition(sid+"_number_feedback", "feedback", "The called number and the held place are both visible."), _cue(sid, "lotto_counter", "music"), _transition(sid+"_draw_stage", "stage", "The queue turns toward the verified number board.")]
		"corner_store_aftermath":
			scene_ops = [_scene_move(sid, "evidence_lane", c.object_a, "foreground"), _scene_simple(sid, "evidence_reveal", c.object_b, "reveal"), _scene_change(sid, "evidence_state", c.object_b, "set_state", "bagged_for_trace")]
			actor_ops = [_actor_move(sid, "officer_lane", c.actor, "left")]
			transition_ops = [_transition(sid+"_evidence_stage", "stage", "The evidence route is isolated before the object is handled."), _cue(sid, "evidence_bag", "sound"), _transition(sid+"_custody_feedback", "feedback", "The officer holds a visible chain-of-custody lane.")]
		"corner_store_dead_shift":
			scene_ops = [_scene_change(sid, "breaker_open", c.object_a, "set_appearance", "open_breaker"), _scene_change(sid, "cooler_dark", c.object_b, "set_state", "circuit_isolated"), _scene_simple(sid, "cooler_reveal", c.object_b, "reveal")]
			actor_ops = [_actor_change(sid, "clerk_pose", c.actor, "set_pose", "holding_flashlight")]
			transition_ops = [_cue(sid, "breaker_snap", "sound"), _transition(sid+"_power_feedback", "feedback", "The private aisle stays dark while the cooler circuit is isolated.")]
		"corner_store_inventory_night":
			scene_ops = [_scene_move(sid, "cage_split", c.object_a, "right"), _scene_change(sid, "cage_counted", c.object_a, "set_state", "section_counted"), _scene_change(sid, "shelf_tags", c.object_b, "set_appearance", "discrepancy_tags"), _scene_simple(sid, "shelf_reveal", c.object_b, "reveal")]
			actor_ops = [_actor_change(sid, "counter_pose", c.actor, "set_pose", "recounting_shelf"), _actor_change(sid, "counter_behavior", c.actor, "set_behavior", "work")]
			transition_ops = [_cue(sid, "scanner_beep", "sound"), _transition(sid+"_count_stage", "stage", "The count cage closes one section while the discrepancy shelf remains accessible."), _transition(sid+"_count_feedback", "feedback", "The visible tag trail now identifies the mismatched section.")]
		"back_alley_street_craps":
			scene_ops = [_scene_change(sid, "ring_marked", c.object_a, "set_appearance", "chalk_point_ring"), _scene_move(sid, "lookout_turn", c.object_b, "foreground"), _scene_change(sid, "lookout_state", c.object_b, "set_state", "warning_active")]
			actor_ops = [_actor_change(sid, "shooter_pose", c.actor, "set_pose", "setting_dice"), _actor_change(sid, "shooter_behavior", c.actor, "set_behavior", "watch"), _actor_move(sid, "shooter_lane", c.actor, "right")]
			transition_ops = [_cue(sid, "dice_curb", "sound"), _cue(sid, "street_game", "music"), _transition(sid+"_point_feedback", "feedback", "The chalk point and lookout warning define the live street game.")]
		"back_alley_cruiser_parked":
			scene_ops = [_scene_simple(sid, "beam_hidden", c.object_a, "hide"), _scene_move(sid, "cover_shift", c.object_b, "right"), _scene_change(sid, "cover_state", c.object_b, "set_state", "diversion_ready")]
			actor_ops = [_actor_change(sid, "patrol_behavior", c.actor, "set_behavior", "patrol"), _actor_change(sid, "patrol_pose", c.actor, "set_pose", "scanning_doorway"), _actor_move(sid, "patrol_lane", c.actor, "center")]
			transition_ops = [_cue(sid, "police_radio", "sound"), _cue(sid, "sightline_tension", "music"), _transition(sid+"_sightline_feedback", "feedback", "The shifted cover breaks one patrol sightline but exposes another."), _transition(sid+"_diversion_stage", "stage", "The patrol turns while the cover crosses the beam.")]
		"back_alley_fence_night":
			scene_ops = [_scene_move(sid, "lot_rotation", c.object_a, "left"), _scene_change(sid, "lot_marks", c.object_a, "set_appearance", "marked_goods_lots"), _scene_change(sid, "auth_ready", c.object_b, "set_state", "authentication_open"), _scene_simple(sid, "station_enable", c.object_b, "enable")]
			actor_ops = [_actor_change(sid, "buyer_pose", c.actor, "set_pose", "checking_marks"), _actor_move(sid, "buyer_rotation", c.actor, "foreground")]
			transition_ops = [_cue(sid, "crate_latch", "sound"), _transition(sid+"_auction_stage", "stage", "The rotating buyer yields the authentication station to the contested crate."), _transition(sid+"_authentication_feedback", "feedback", "The marked lot and authentication result remain independently visible.")]
		"back_alley_nothing_moving":
			scene_ops = [_scene_change(sid, "trace_pattern", c.object_a, "set_state", "three_traces_compared"), _scene_move(sid, "shutter_gap", c.object_b, "background"), _scene_change(sid, "gap_appearance", c.object_b, "set_appearance", "opened_trace_gap")]
			actor_ops = [_actor_change(sid, "regular_behavior", c.actor, "set_behavior", "flee"), _actor_change(sid, "regular_pose", c.actor, "set_pose", "pointing_to_exit")]
			transition_ops = [_cue(sid, "shutter_scrape", "sound"), _cue(sid, "silent_alley", "music"), _transition(sid+"_trace_stage", "stage", "The wet print, crate drag, and snapped seal converge on the shutter gap."), _transition(sid+"_trail_feedback", "feedback", "The silent trail now exposes a route rather than a stall.")]
		"pawn_shop_estate_lot_day":
			scene_ops = [_scene_change(sid, "cart_display", c.object_a, "set_appearance", "segmented_appraisal_cart"), _scene_change(sid, "marks_matched", c.object_b, "set_state", "provenance_matched"), _scene_move(sid, "cart_lane", c.object_a, "service_lane"), _scene_simple(sid, "marks_enable", c.object_b, "enable")]
			actor_ops = [_actor_change(sid, "appraiser_pose", c.actor, "set_pose", "comparing_marks"), _actor_change(sid, "appraiser_behavior", c.actor, "set_behavior", "guard"), _actor_move(sid, "appraiser_lane", c.actor, "foreground")]
			transition_ops = [_transition(sid+"_appraisal_feedback", "feedback", "The cart now separates display, return, and police-hold provenance."), _cue(sid, "appraisal_stamp", "sound"), _transition(sid+"_provenance_stage", "stage", "Each provenance mark is matched before the cart changes lanes."), _cue(sid, "estate_floor", "music")]
		"pawn_shop_serial_check_day":
			scene_ops = [_scene_change(sid, "serial_lit", c.object_a, "set_appearance", "serial_lamp"), _scene_change(sid, "hold_sealed", c.object_b, "set_state", "record_hold_sealed"), _scene_move(sid, "hold_lane", c.object_b, "right"), _scene_simple(sid, "station_hidden", c.object_a, "hide")]
			actor_ops = [_actor_change(sid, "records_pose", c.actor, "set_pose", "copying_serial"), _actor_change(sid, "records_behavior", c.actor, "set_behavior", "guard"), _actor_move(sid, "records_lane", c.actor, "left")]
			transition_ops = [_cue(sid, "record_stamp", "sound"), _transition(sid+"_serial_feedback", "feedback", "The copied serial links the sealed object to the hold record."), _transition(sid+"_hold_stage", "stage", "The station closes while the records clerk seals the hold lane.")]
		"pawn_shop_sals_mood":
			scene_ops = [_scene_change(sid, "jobs_sorted", c.object_a, "set_state", "jobs_prioritized"), _scene_move(sid, "appraisal_privacy", c.object_b, "background"), _scene_change(sid, "appraisal_hidden", c.object_b, "set_appearance", "privacy_screen")]
			actor_ops = [_actor_change(sid, "sal_behavior", c.actor, "set_behavior", "work"), _actor_change(sid, "sal_pose", c.actor, "set_pose", "checking_finished_job")]
			transition_ops = [_cue(sid, "shop_bell", "sound"), _transition(sid+"_mood_stage", "stage", "Sal checks the finished job before choosing the counter or back room."), _transition(sid+"_mood_feedback", "feedback", "The finished job changes Sal's route and access to the private appraisal.")]
	return {"scene_ops":scene_ops, "actor_ops":actor_ops, "transition_ops":transition_ops}

func _scene_change(sid: String, receipt: String, stable_id: String, op: String, value: String) -> Dictionary:
	var row := {"family":"scene_ops","op":op,"receipt_id":sid+"_"+receipt,"owner_namespace":"scenario","stable_object_id":stable_id}
	row["state" if op == "set_state" else "appearance"] = value
	return row

func _scene_move(sid: String, receipt: String, stable_id: String, zone_id: String) -> Dictionary:
	return {"family":"scene_ops","op":"move","receipt_id":sid+"_"+receipt,"owner_namespace":"scenario","stable_object_id":stable_id,"zone_id":zone_id}

func _scene_simple(sid: String, receipt: String, stable_id: String, op: String) -> Dictionary:
	return {"family":"scene_ops","op":op,"receipt_id":sid+"_"+receipt,"owner_namespace":"scenario","stable_object_id":stable_id}

func _actor_change(sid: String, receipt: String, stable_id: String, op: String, value: String) -> Dictionary:
	var row := {"family":"actor_ops","op":op,"receipt_id":sid+"_"+receipt,"owner_namespace":"scenario","stable_object_id":stable_id}
	row["behavior" if op == "set_behavior" else "pose"] = value
	return row

func _actor_move(sid: String, receipt: String, stable_id: String, zone_id: String) -> Dictionary:
	return {"family":"actor_ops","op":"set_position","receipt_id":sid+"_"+receipt,"owner_namespace":"scenario","stable_object_id":stable_id,"zone_id":zone_id}

func _cue(sid: String, cue_id: String, op: String) -> Dictionary:
	return {"family":"transition_ops","op":op,"receipt_id":sid+"_"+cue_id,"owner_namespace":"scenario","stable_object_id":sid+"_"+cue_id,"channel":"room","cue_id":cue_id}

func _phase_resolution(c: Dictionary) -> Dictionary:
	var sid := str(c.id)
	return {"id":"resolution","label":"Physical aftermath","arrival_feedback":"The room holds the chosen physical aftermath for revisit.","exit_prompt":"Leave through the marked clear route.","terminal":true,"entry_conditions":[],"objective_ids":[],"advance_after_actions":0,"scene_ops":[],"interaction_ops":[],"actor_ops":[],"transition_ops":[_transition(sid+"_resolution_feedback","feedback","The outcome is recorded once and its room changes persist.")],"branches":[
		{"id":sid+"_out_success","condition":{"type":"local_equals","key":"path","value":"success"},"outcome":"success"},{"id":sid+"_out_failure","condition":{"type":"local_equals","key":"path","value":"failure"},"outcome":"failure"},{"id":sid+"_out_ignored","condition":{"type":"local_equals","key":"path","value":"ignored"},"outcome":"ignored"},{"id":sid+"_out_refused","condition":{"type":"local_equals","key":"path","value":"refused"},"outcome":"refused"},{"id":sid+"_out_interrupted","condition":{"type":"local_equals","key":"path","value":"interrupted"},"outcome":"interrupted"},{"id":sid+"_out_public","condition":{"type":"local_equals","key":"path","value":"public"},"outcome":"public"}]}

func _world_contract(c: Dictionary) -> Dictionary:
	var world_id := str(c.world)
	var result := {"fact_type":"service_result","producer":"service","payload_equals":{"kind":"scenario_service","service_id":world_id},"selector":"ok","field":"public_service_ok","local_schema":{"type":"bool","default":false,"visibility":"public"},"aftermath":"%s_public_service" % world_id,"state":"public_service","accepted_public_facts":["service_result"]}
	match world_id:
		"security_evidence":
			result = {"fact_type":"sweep_changed","producer":"sweep","payload_equals":{"node_id":"corner_store"},"selector":"active","field":"security_pressure_active","local_schema":{"type":"bool","default":false,"visibility":"public"},"aftermath":"evidence_sweep_hold","state":"security_pressure","accepted_public_facts":["sweep_changed"]}
		"rumor_surveillance":
			result = {"fact_type":"heat_changed","producer":"heat","payload_equals":{"source":"corner_store_surveillance"},"selector":"current","field":"surveillance_heat","local_schema":{"type":"float","default":0.0,"min":0.0,"max":100.0,"visibility":"public"},"aftermath":"surveillance_rumor_route","state":"rumor_pressure","accepted_public_facts":["heat_changed"]}
		"game_craps_public":
			result = {"fact_type":"game_result","producer":"game","payload_equals":{"game_id":"craps","action_id":"street_craps_disperse"},"selector":"bankroll_delta","field":"stake_recovery_delta","local_schema":{"type":"float","default":0.0,"min":0.0,"max":1000000.0,"visibility":"public"},"aftermath":"street_stake_recovered","state":"stake_recovery","accepted_public_facts":["craps.roll_resolved","craps.come_out","craps.point_set","craps.point_made","craps.seven_out","craps.table_cooled","craps.streak_tier","craps.large_swing","craps.street_lookout_warning","craps.dispersal"]}
		"sweep_public_pressure":
			result = {"fact_type":"sweep_changed","producer":"sweep","payload_equals":{"node_id":"back_alley"},"selector":"active","field":"cruiser_sweep_active","local_schema":{"type":"bool","default":false,"visibility":"public"},"aftermath":"cruiser_pressure_route","state":"active_sweep","accepted_public_facts":["sweep_changed"]}
		"rumor_route":
			result = {"fact_type":"town_transition","producer":"town","payload_equals":{"day_type":"weekday"},"selector":"weather","field":"rumor_weather_route","local_schema":{"type":"string","default":"","visibility":"public"},"aftermath":"weather_rumor_exit","state":"rumor_route","accepted_public_facts":["town_transition"]}
		"security_inventory":
			result = {"fact_type":"sweep_changed","producer":"sweep","payload_equals":{"node_id":"pawn_shop"},"selector":"active","field":"serial_sweep_active","local_schema":{"type":"bool","default":false,"visibility":"public"},"aftermath":"serial_sweep_hold","state":"security_inventory","accepted_public_facts":["sweep_changed"]}
	return result

func _world_subscription(world: Dictionary, local_key: String, project_payload: bool) -> Dictionary:
	var inputs := {"key":local_key,"value_from_payload":str(world.selector)} if project_payload else {"key":local_key,"value":"public"}
	return {"fact_type":str(world.fact_type),"payload_equals":(world.payload_equals as Dictionary).duplicate(true),"handler":"set_local","inputs":inputs}

func _declared_anchors(c: Dictionary) -> Array:
	var result: Array = []
	for key in ["object_a_anchor", "actor_anchor", "actor_work_anchor", "exit_anchor"]:
		var anchor_id := str(c.get(key, "")).strip_edges()
		if not anchor_id.is_empty() and not result.has("base::anchor:%s" % anchor_id): result.append("base::anchor:%s" % anchor_id)
	return result

func _target_inventory(c: Dictionary) -> Dictionary:
	return {"scene_objects":[],"interactions":[],"actors":[],"services":[],"games":[],"routes":[],"anchors":_declared_anchors(c),"zones":["base::zone:left","base::zone:right","base::zone:center","base::zone:background","base::zone:service_lane","base::zone:foreground","base::zone:exit_lane"],"event_choices":{}}

func _repair_delivery_day(entry: Dictionary) -> Dictionary:
	var repaired := entry.duplicate(true)
	var sequence := repaired.get("sequence", {}) as Dictionary
	var aftermath := sequence.get("aftermath", {}) as Dictionary
	var copy := {
		"refused": {
			"revisit_feedback": "A sealed pallet remains under Ada's watch; the cashier tip is disabled and the bar route is closed.",
			"receipt_id": "aftermath_refused_bar_route",
			"stable_object_id": "world:bar",
			"disabled_reason": "The return pickup occupies the bar route.",
		},
		"interrupted": {
			"revisit_feedback": "An abandoned manifest remains after Priya departs; the cashier tip stays enabled and the bar route is closed.",
			"receipt_id": "aftermath_interrupted_bar_route",
			"stable_object_id": "world:bar",
			"disabled_reason": "The interrupted unloading closes the bar route for this visit.",
		},
	}
	for outcome_value in copy.keys():
		var outcome := str(outcome_value)
		var row := aftermath.get(outcome, {}) as Dictionary
		var wording := copy[outcome] as Dictionary
		row["revisit_feedback"] = wording.revisit_feedback
		var route_ops := row.get("route_ops", []) as Array
		if not route_ops.is_empty():
			var route_op := route_ops[0] as Dictionary
			route_op["receipt_id"] = wording.receipt_id
			route_op["stable_object_id"] = wording.stable_object_id
			route_op["disabled_reason"] = wording.disabled_reason
			route_ops[0] = route_op
		row["route_ops"] = route_ops
		aftermath[outcome] = row
	for outcome_value in aftermath.keys():
		var outcome := str(outcome_value)
		var row := aftermath.get(outcome, {}) as Dictionary
		var actor_ops := row.get("actor_ops", []) as Array
		for operation_index in range(actor_ops.size()):
			var operation := actor_ops[operation_index] as Dictionary
			if str(operation.get("stable_object_id", "")) != "delivery_clerk":
				continue
			var actor := operation.get("actor", {}) as Dictionary
			actor.erase("route_id")
			operation["actor"] = actor
			actor_ops[operation_index] = operation
		row["actor_ops"] = actor_ops
		aftermath[outcome] = row
	var phase_graph := sequence.get("phase_graph", {}) as Dictionary
	var phases := phase_graph.get("phases", []) as Array
	for phase_index in range(phases.size()):
		var phase := phases[phase_index] as Dictionary
		if str(phase.get("id", "")) == "awaiting_stock":
			var waiting_scene_ops := phase.get("scene_ops", []) as Array
			for operation_index in range(waiting_scene_ops.size()):
				var waiting_operation := waiting_scene_ops[operation_index] as Dictionary
				if str(waiting_operation.get("stable_object_id", "")) != "delivery_cartons" or str(waiting_operation.get("op", "")) != "move":
					continue
				waiting_operation.erase("zone_id")
				waiting_operation["anchor_id"] = "package_a_delivery_cartons_wait"
				waiting_scene_ops[operation_index] = waiting_operation
			phase["scene_ops"] = waiting_scene_ops
			phases[phase_index] = phase
		if str(phase.get("id", "")) != str(phase_graph.get("initial_phase", "")):
			continue
		var scene_ops := phase.get("scene_ops", []) as Array
		for operation_index in range(scene_ops.size()):
			var operation := scene_ops[operation_index] as Dictionary
			var stable_id := str(operation.get("stable_object_id", ""))
			if stable_id in ["mismarked_crate", "delivery_event_gate"]:
				var object := operation.get("object", {}) as Dictionary
				object["anchor_id"] = "package_a_delivery_crate" if stable_id == "mismarked_crate" else "package_a_delivery_gate"
				operation["object"] = object
				scene_ops[operation_index] = operation
		phase["scene_ops"] = scene_ops
		var actor_ops := phase.get("actor_ops", []) as Array
		for operation_index in range(actor_ops.size()):
			var operation := actor_ops[operation_index] as Dictionary
			if str(operation.get("stable_object_id", "")) != "delivery_runner":
				continue
			var actor := operation.get("actor", {}) as Dictionary
			actor["anchor_id"] = "package_a_delivery_runner"
			operation["actor"] = actor
			actor_ops[operation_index] = operation
		phase["actor_ops"] = actor_ops
		phases[phase_index] = phase
	phase_graph["phases"] = phases
	sequence["phase_graph"] = phase_graph
	sequence["aftermath"] = aftermath
	var targets := sequence.get("declared_targets", {}) as Dictionary
	targets["routes"] = ["base::world:bar"]
	var anchors := targets.get("anchors", []) as Array
	for anchor_id in ["base::anchor:package_a_delivery_cartons_wait", "base::anchor:package_a_delivery_crate", "base::anchor:package_a_delivery_gate", "base::anchor:package_a_delivery_runner"]:
		if not anchors.has(anchor_id):
			anchors.append(anchor_id)
	anchors.sort()
	targets["anchors"] = anchors
	sequence["declared_targets"] = targets
	repaired["sequence"] = sequence
	var evidence_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/plans/evidence/env06_7_masked_visual_evidence.json"))
	if typeof(evidence_value) != TYPE_DICTIONARY or typeof((evidence_value as Dictionary).get("pairs")) != TYPE_DICTIONARY:
		push_error("Package A masked visual evidence is unreadable.")
		return {}
	var authoring := repaired.get("authoring", {}) as Dictionary
	authoring["masked_visual_explanations"] = ((evidence_value as Dictionary).get("pairs", {}) as Dictionary).duplicate(true)
	repaired["authoring"] = authoring
	return repaired

func _spawn(receipt: String, stable_id: String, label: String, role: String, zone: String, state: String) -> Dictionary:
	return {"family":"scene_ops","op":"spawn","receipt_id":receipt,"owner_namespace":"scenario","stable_object_id":stable_id,"object":{"label":label,"role":role,"zone_id":zone,"bounds":{"w":72,"h":56},"visible":true,"enabled":true,"state":state,"appearance":stable_id}}

func _interaction(receipt: String, stable_id: String, label: String, actions: Array, safe: bool) -> Dictionary:
	var inputs: Array=[]
	for action in actions:
		if not inputs.has(action.input_action): inputs.append(action.input_action)
	return {"family":"interaction_ops","op":"add","receipt_id":receipt,"owner_namespace":"scenario","stable_object_id":stable_id,"interaction":{"owner_namespace":"scenario","stable_object_id":stable_id,"label":label,"state_label":"Available","prompt":"Choose a physical action at this station.","enabled":true,"disabled_reason":"","available_actions":actions,"input_actions":inputs,"non_color_state":"ready","focus_order":1,"hit_bounds":{"w":64,"h":56},"min_target_size":44,"safe_exit":safe,"alternate_exit":false}}

func _exit(c: Dictionary) -> Dictionary:
	return _interaction(str(c.id)+"_exit_add",str(c.id)+"_exit","Marked clear exit",[_action("leave_safely","Leave safely","ui_focus_next","path","refused")],true)

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
