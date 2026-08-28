extends SceneTree

const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")

const OUTPUT := "res://data/environments/scenario_sequences/env06_7_underground_lounge.json"
const DOSSIERS := "res://docs/plans/env06_7_package_d_sequence_dossiers.json"

const CONFIGS := [
	{"id":"punchline_open_mic_night","archetype":"small_underground_casino","arrival":"A signup lectern, movable stage steps, and half-filled chair banks form a live queue from Layer 1 to the microphone.","verbs":["pin_signup_slot","carry_stage_steps","reseat_late_audience","release_final_act"],"beats":["signup_reorder","steps_move","audience_rotate","microphone_release"],"fact":"town_transition","tags":["act_queue_pressure","stage_support","late_show_layout"],"objects":[["signup_lectern","Open-mic signup lectern","queue_station","left","posted"],["stage_steps","Movable stage steps","route_fixture","center","blocking"],["chair_bank","Open-mic chair bank","seating","right","half_full"]],"actors":[["open_mic_host","Open-mic host","actor_open_mic_host","background","work"],["waiting_comic","Waiting comic","actor_waiting_comic","left","watch"]],"decision":{"at":"arrival","options":[["manage_open_mic_bill","work_1"],["support_waiting_comic","work_1"],["sabotage_open_mic","terminal_failure"]]},"outcomes":["late_show_running","bill_reordered","show_refused","show_interrupted"]},
	{"id":"punchline_headliner_night","archetype":"small_underground_casino","arrival":"Credential ropes seal the L1 stair, an equipment case waits on L2, and a runner holds at the L3 service door.","verbs":["verify_l1_credential","carry_l2_runner_case","signal_l3_door","escort_headliner_route","reset_service_rope"],"beats":["credential_turn","case_transfer","door_release","headliner_move","rope_reset"],"fact":"service_result","tags":["three_layer_credential","runner_relay","backstage_route"],"objects":[["credential_rope","Layer 1 credential rope","barrier","left","sealed"],["runner_case","Layer 2 runner case","equipment","center","waiting"],["service_door","Layer 3 service door","route_fixture","right","locked"]],"actors":[["credential_runner","Headliner runner","actor_headliner_runner","center","wait"],["door_guard","Backstage door guard","actor_door_guard","right","guard"]],"decision":{"at":"work_1","options":[["honor_headliner_route","work_2"],["escort_headliner_direct","work_2"],["divert_headliner_runner","terminal_failure"]]},"outcomes":["headliner_reached","runner_diverted","credential_refused","arrival_interrupted"]},
	{"id":"punchline_bringer_show","archetype":"small_underground_casino","arrival":"Three labeled crowd groups wait behind separate ropes while empty chair blocks face an unlit stage.","verbs":["open_first_crowd_rope","usher_supporters_to_block","count_minimum_seats","close_hostile_pitch"],"beats":["rope_open","crowd_move","seat_count","stage_light"],"fact":"travel_arrived","tags":["occupancy_threshold","crowd_usher","pitch_aftermath"],"objects":[["crowd_ropes","Bringer crowd ropes","barrier","left","segmented"],["seat_blocks","Reserved chair blocks","seating","center","empty"],["unlit_stage","Bringer stage","performance","background","dark"]],"actors":[["bringer_performer","Bringer performer","actor_bringer_performer","background","wait"],["crowd_captain","Crowd captain","actor_crowd_captain","left","queue"]],"decision":{"at":"work_1","options":[["seat_bringer_supporters","work_2"],["defend_bringer_minimum","terminal_success"],["accept_hostile_pitch","terminal_failure"]]},"outcomes":["show_seated","hostile_pitch","ushering_refused","crowd_interrupted"]},
	{"id":"punchline_high_stakes_night","archetype":"small_underground_casino","arrival":"A protected table displaces ordinary chairs while guard sightlines and an observer rail divide the casino floor.","verbs":["clear_ordinary_chairs","mark_guard_sightline","open_observer_rail","restore_public_game_lane"],"beats":["chair_stack","guard_turn","rail_open","floor_restore"],"fact":"game_result","tags":["protected_table_layout","observer_service","game_lane_restoration"],"objects":[["protected_table","Protected high-stakes table","game_fixture","center","reserved"],["observer_rail","High-stakes observer rail","barrier","right","closed"],["chair_stack","Displaced ordinary chairs","furniture","left","stacked"]],"actors":[["high_stakes_guard","High-stakes guard","actor_high_stakes_guard","right","guard"],["floor_service_runner","Floor service runner","actor_floor_runner","left","work"]],"decision":{"at":"work_2","options":[["serve_protected_table","work_3"],["open_public_observer_rail","terminal_success"],["seal_public_game_lane","terminal_failure"]]},"outcomes":["public_lane_restored","floor_remains_protected","service_refused","session_interrupted"]},
	{"id":"punchline_greased_week","archetype":"small_underground_casino","arrival":"Inspection seals mark three layer doors while a payoff ledger and moving inspector define a visible route through the club.","verbs":["read_l1_inspection_seal","carry_ledger_to_l2","shadow_inspector_to_l3","unseal_declared_service","post_route_record"],"beats":["seal_read","ledger_move","inspector_route","service_unseal","record_post"],"fact":"heat_changed","tags":["inspection_route","payoff_chain","service_exposure"],"objects":[["inspection_seals","Layer inspection seals","evidence","left","posted"],["payoff_ledger","Payoff route ledger","ledger","center","sealed"],["service_barrier","Declared service barrier","barrier","right","closed"]],"actors":[["moving_inspector","Moving inspector","actor_inspector","left","patrol"],["payoff_runner","Payoff runner","actor_payoff_runner","center","work"]],"decision":{"at":"work_1","options":[["expose_payoff_chain","terminal_success"],["maintain_payoff_route","terminal_failure"],["redirect_inspector_route","work_2"]]},"outcomes":["chain_exposed","payoff_maintained","route_refused","inspection_interrupted"]},
	{"id":"punchline_debt_court","archetype":"small_underground_casino","arrival":"Hearing chairs replace the L3 poker-night room while an evidence stand and witness mark sit outside the paused table boundary.","verbs":["form_hearing_aisle","place_public_evidence","call_room_witness","clear_chairs_for_work"],"beats":["aisle_form","evidence_place","witness_move","room_restore"],"fact":"game_result","tags":["l3_hearing_layout","public_poker_pause","ruling_aftermath"],"objects":[["hearing_chairs","Debt-court hearing chairs","seating","center","formed"],["evidence_stand","Public evidence stand","evidence","left","empty"],["paused_table_rope","Paused poker table rope","barrier","right","sealed"]],"actors":[["court_steward","Debt-court steward","actor_court_steward","background","work"],["room_witness","Room witness","actor_room_witness","left","wait"]],"decision":{"at":"work_2","options":[["uphold_debt_ruling","terminal_success"],["contest_debt_ruling","terminal_failure"],["adjourn_debt_court","terminal_refused"]]},"outcomes":["room_returns_ordered","ruling_contested","hearing_refused","poker_boundary_interrupted"]},
	{"id":"punchline_new_muscle","archetype":"small_underground_casino","arrival":"New guard posts, inspection trays, and a marked bypass lane create functional checkpoints across the three layers.","verbs":["present_item_at_l1_tray","test_l2_guard_gap","mark_l3_bypass_lane","reassign_checkpoint_posts","open_clean_route"],"beats":["tray_check","guard_gap","bypass_mark","post_rotate","route_open"],"fact":"crew_changed","tags":["checkpoint_procedure","guard_test","layer_route_open"],"objects":[["inspection_tray","Checkpoint inspection tray","workstation","left","ready"],["guard_posts","Three-layer guard posts","barrier","center","staffed"],["bypass_lane","Marked bypass lane","route_marker","right","narrow"]],"actors":[["new_guard_lead","New guard lead","actor_new_guard_lead","center","guard"],["checkpoint_rover","Checkpoint rover","actor_checkpoint_rover","left","patrol"]],"decision":{"at":"arrival","options":[["train_new_guard_posts","work_1"],["test_guard_loyalty","work_1"],["entrench_checkpoint_posts","terminal_failure"]]},"outcomes":["posts_reassigned","checkpoint_entrenched","test_refused","checkpoint_interrupted"]},
	{"id":"punchline_raid_jitters","archetype":"small_underground_casino","arrival":"Hide carts, clear bins, and reopen seals wait on different layers while a lookout listens at the outer knock point.","verbs":["wheel_l1_hide_cart","clear_l2_service_lane","seal_l3_room_screen","answer_outer_knock","reopen_safe_floor"],"beats":["cart_move","lane_clear","screen_seal","lookout_turn","floor_reopen"],"fact":"sweep_changed","tags":["raid_staging","three_layer_clear","public_poker_abort"],"objects":[["hide_cart","Layer 1 hide cart","storage","left","loaded"],["clear_bins","Layer 2 clear bins","workstation","center","open"],["room_screen","Layer 3 room screen","barrier","right","unsealed"]],"actors":[["raid_lookout","Raid lookout","actor_raid_lookout","left","listen"],["reopen_steward","Reopen steward","actor_reopen_steward","background","work"]],"decision":{"at":"work_3","options":[["hide_raid_evidence","work_4"],["abort_raid_night","terminal_failure"],["reopen_after_false_alarm","terminal_success"]]},"outcomes":["altered_floor_reopened","night_aborted","hide_task_refused","raid_interrupted"]},
	{"id":"kitty_cat_lounge_amateur_night","archetype":"kitty_cat_lounge","arrival":"Signup, dressing, stage, and judging stations form a visible four-stop contestant circuit around the lounge.","verbs":["register_amateur_act","carry_costume_to_dressing","set_stage_mark","deliver_judges_card","rotate_final_lineup"],"beats":["signup_cycle","costume_move","stage_mark","judge_card","lineup_rotate"],"fact":"town_transition","tags":["contestant_circuit","bracket_operation","backstage_rotation"],"objects":[["amateur_signup","Amateur signup station","queue_station","left","open"],["dressing_rack","Dressing costume rack","equipment","center","loaded"],["judging_desk","Judging station","scoreboard","right","blank"]],"actors":[["amateur_contestant","Amateur contestant","actor_amateur_contestant","left","watch"],["amateur_judge","Amateur-night judge","actor_amateur_judge","right","watch"]],"decision":{"at":"work_2","options":[["judge_amateur_bracket","work_3"],["reseed_amateur_lineup","work_3"],["stall_amateur_bracket","terminal_failure"]]},"outcomes":["final_lineup_rotated","bracket_stalled","act_refused","show_interrupted"]},
	{"id":"kitty_cat_lounge_buyout","archetype":"kitty_cat_lounge","arrival":"Private-party ropes advance from the entrance toward the stage while a guest desk and request cart split public circulation.","verbs":["verify_first_guest","advance_buyout_rope","carry_request_cart","mark_public_half_floor","reset_entry_desk"],"beats":["guest_verify","rope_advance","cart_move","floor_split","desk_reset"],"fact":"service_result","tags":["progressive_buyout","guest_verification","split_floor_route"],"objects":[["buyout_ropes","Private buyout ropes","barrier","center","advancing"],["guest_desk","Buyout guest desk","workstation","left","checking"],["request_cart","Private request cart","service","right","loaded"]],"actors":[["buyout_host","Buyout host","actor_buyout_host","left","work"],["public_floor_steward","Public floor steward","actor_floor_steward","right","guard"]],"decision":{"at":"work_1","options":[["split_buyout_floor","work_2"],["claim_full_buyout","terminal_failure"],["preserve_public_half","work_2"]]},"outcomes":["split_floor_running","full_buyout_claimed","service_refused","buyout_interrupted"]},
	{"id":"kitty_cat_lounge_slow_night","archetype":"kitty_cat_lounge","arrival":"Closed section ropes consolidate the room around a dark mini-stage, an exposed maintenance panel, and one occupied conversation booth.","verbs":["choose_zone_to_reactivate","coil_closed_section_rope","power_selected_station","move_remaining_staff"],"beats":["zone_choice","rope_coil","station_power","staff_move"],"fact":"world_boundary","tags":["exclusive_zone_reactivation","maintenance_choice","remaining_staff_layout"],"objects":[["closed_section_ropes","Closed section ropes","barrier","center","consolidated"],["mini_stage","Dark mini-stage","performance","left","dark"],["maintenance_panel","Exposed maintenance panel","workstation","right","open"]],"actors":[["slow_night_host","Slow-night host","actor_slow_night_host","center","wait"],["booth_regular","Remaining booth regular","actor_booth_regular","right","idle"]],"decision":{"at":"arrival","options":[["reactivate_mini_stage","work_1"],["maintain_conversation_booth","work_1"],["close_wrong_lounge_zone","terminal_failure"]]},"outcomes":["selected_zone_active","wrong_zone_closed","task_refused","night_interrupted"]},
	{"id":"kitty_cat_lounge_bachelorette_storm","archetype":"kitty_cat_lounge","arrival":"Two party groups, a rolling prop trunk, and a missing-person marker crowd the stage-to-bar lane.","verbs":["separate_party_groups","roll_prop_trunk_off_lane","trace_missing_guest_marker","return_stage_prop","restore_bar_route","seat_orderly_finale"],"beats":["groups_split","trunk_move","marker_trace","prop_return","route_restore","finale_seat"],"fact":"heat_band_changed","tags":["moving_party_pressure","missing_guest_trace","stage_route_recovery"],"objects":[["party_prop_trunk","Rolling party prop trunk","equipment","center","blocking"],["missing_guest_marker","Missing guest marker","evidence","left","fresh"],["bar_route_rope","Bar route rope","route_marker","right","buried"]],"actors":[["party_leader","Bachelorette party leader","actor_party_leader","left","search"],["floor_recovery_host","Floor recovery host","actor_floor_host","right","work"]],"decision":{"at":"work_3","options":[["rescue_missing_guest","work_4"],["commandeer_lounge_stage","terminal_failure"],["evacuate_party_groups","terminal_interrupted"]]},"outcomes":["orderly_finale","stage_commandeered","recovery_refused","storm_interrupted"]},
]


func _initialize() -> void:
	var entries: Array = []
	var dossiers: Array = []
	var failures: Array = []
	var signatures: Dictionary = {}
	for config in CONFIGS:
		# Hash the exact JSON numeric/string representation that production loads,
		# not the richer in-memory GDScript integer representation.
		var entry: Dictionary = JSON.parse_string(JSON.stringify(_entry(config)))
		var definition := {"id": config.id, "archetype_id": config.archetype, "sequence": entry.sequence}
		entry["sequence"]["sequence_signature"] = Schema.calculated_signature_hash(definition)
		definition["sequence"] = entry["sequence"]
		var errors := Schema.validate_definition(definition, null, _target_inventory())
		if not errors.is_empty(): failures.append({"id":config.id,"errors":errors})
		var signature := str(entry["sequence"]["sequence_signature"])
		if signatures.has(signature): failures.append({"duplicate_signature":[signatures[signature],config.id]})
		signatures[signature] = config.id
		entries.append(entry)
		dossiers.append(_dossier(config, entry))
	var report := Schema.catalog_uniqueness_report(_definitions(entries), entries.size())
	if not failures.is_empty():
		printerr(JSON.stringify(failures, "  "))
		quit(1)
		return
	_write_json(OUTPUT, {"schema_version":1,"package_id":"env06_7_punchline_clubs","handler_pack":"punchline_clubs","renderer_id":"punchline_clubs","scenarios":entries})
	_write_json(DOSSIERS, {"schema_version":1,"package_id":"env06_7_punchline_clubs","base_head":"855a296126e8b4747b78fbe89cb5a2d02daf61f5","scenario_count":entries.size(),"dossiers":dossiers,"uniqueness_rows":report.rows,"pairwise_similarity":report.pairs,"assembly_evidence_needed":report.failures,"pair_count":report.comparison_count})
	print("ENV06_7_PACKAGE_D_AUTHOR_OK scenarios=%d pairs=%d" % [entries.size(), report.comparison_count])
	quit(0)


func _entry(c: Dictionary) -> Dictionary:
	var prefix := str(c.id)
	var phases: Array = []
	var cleanup: Array = []
	var objective_steps: Array = []
	var scene_ops: Array = []
	for object_index in range(c.objects.size()):
		var o: Array = c.objects[object_index]
		var object_id := "%s_%s" % [prefix, o[0]]
		scene_ops.append(_scene_spawn(prefix, "arrival", object_id, str(o[1]), str(o[2]), str(o[3]), str(o[4]), 52 + object_index * 8, 46 + object_index * 6))
		cleanup.append(_remove("scene_ops", prefix, object_id))
	var actor_ops: Array = []
	for actor_index in range(c.actors.size()):
		var a: Array = c.actors[actor_index]
		var actor_id := "%s_%s" % [prefix, a[0]]
		actor_ops.append(_actor_spawn(prefix, "arrival", actor_id, str(a[1]), str(a[2]), str(a[3]), str(a[4])))
		cleanup.append(_despawn(prefix, actor_id))
	var exit_id := "%s_safe_exit" % prefix
	var first_task_id := "%s_task_0" % prefix
	var arrival_interactions := [
		_interaction_add(prefix, "arrival", exit_id, "%s clean exit" % prefix.replace("_"," ").capitalize(), "Leave or refuse the %s task without crossing its active work zone." % prefix.replace("_"," "), [_action("ignore_%s" % prefix, "Ignore the sequence", "ui_down"), _action("refuse_%s" % prefix, "Refuse the task", "ui_cancel")], true),
		_interaction_add(prefix, "arrival", first_task_id, str(c.verbs[0]).replace("_", " ").capitalize(), "Begin the first physical task or commit to this scenario's named strategy.", [_step_action(str(c.verbs[0]), prefix, str(c.verbs[0])), _action("fail_%s" % prefix, "Let the pressure win", "ui_right")] + _decision_actions(c, "arrival", prefix), false),
	]
	cleanup.append(_remove("interaction_ops", prefix, exit_id))
	cleanup.append(_remove("interaction_ops", prefix, first_task_id))
	objective_steps.append({"id":str(c.verbs[0]),"label":str(c.verbs[0]).replace("_"," ").capitalize(),"kind":"command","command_id":str(c.verbs[0])})
	var arrival_branches := [
		_branch(prefix,"arrival_begin",{"type":"command","command_id":str(c.verbs[0])},"work_1","",{"main_task":"success"}),
		_branch(prefix,"arrival_fail",{"type":"command","command_id":"fail_%s" % prefix},"terminal_failure","",{"main_task":"failure"}),
		_branch(prefix,"arrival_refuse",{"type":"command","command_id":"refuse_%s" % prefix},"terminal_refused","",{"main_task":"ignore"}),
		_branch(prefix,"arrival_interrupt",{"type":"fact","fact_type":"travel_departed"},"terminal_interrupted","",{"main_task":"cancel"}),
	]
	arrival_branches.append_array(_decision_branches(c, "arrival", prefix))
	phases.append(_phase("arrival", "Arrival", str(c.arrival), "The marked clean exit remains available.", ["main_task"], scene_ops, arrival_interactions, actor_ops, [_transition(prefix,"arrival","stage","The %s station opens around %s." % [prefix.replace("_"," "),str(c.verbs[0]).replace("_"," ")])], arrival_branches))
	for index in range(1, c.verbs.size()):
		var task_id := "%s_task_%d" % [prefix, index]
		var previous_task_id := "%s_task_%d" % [prefix, index - 1]
		var gate_id := "%s_gate_%d" % [prefix, index - 1]
		var operations := _beat_operations(c, index - 1)
		var phase_id := "work_%d" % index
		var interactions := [_gate(prefix,phase_id,gate_id,previous_task_id), _interaction_add(prefix,phase_id,task_id,str(c.verbs[index]).replace("_"," ").capitalize(),"Complete this distinct room operation or take its identity-specific branch.",[_step_action(str(c.verbs[index]),prefix,str(c.verbs[index])),_action("fail_%s" % prefix,"Let the pressure win","ui_right")] + _decision_actions(c, phase_id, prefix),false)]
		# Remove gate overlays before their underlying task interactions so cleanup
		# cannot restore an already-removed target and leak it across revisit.
		cleanup.push_front(_remove("interaction_ops",prefix,gate_id))
		cleanup.append(_remove("interaction_ops",prefix,task_id))
		objective_steps.append({"id":str(c.verbs[index]),"label":str(c.verbs[index]).replace("_"," ").capitalize(),"kind":"command","command_id":str(c.verbs[index])})
		var next_phase := "terminal_success" if index == c.verbs.size() - 1 else "work_%d" % (index + 1)
		var branches := [
			_branch(prefix,"work_%d_complete" % index,{"type":"command","command_id":str(c.verbs[index])},next_phase,"",{"main_task":"success"}),
			_branch(prefix,"work_%d_pressure" % index,_fact_condition(c),"terminal_failure","",{"main_task":"failure"}),
			_branch(prefix,"work_%d_fail" % index,{"type":"command","command_id":"fail_%s" % prefix},"terminal_failure","",{"main_task":"failure"}),
			_branch(prefix,"work_%d_refuse" % index,{"type":"command","command_id":"refuse_%s" % prefix},"terminal_refused","",{"main_task":"ignore"}),
			_branch(prefix,"work_%d_interrupt" % index,{"type":"fact","fact_type":"travel_departed"},"terminal_interrupted","",{"main_task":"cancel"}),
		]
		branches.append_array(_decision_branches(c, phase_id, prefix))
		phases.append(_phase("work_%d" % index,"Work beat %d" % index,"The room advances to a new physical station and actor arrangement.","The marked clean exit remains available.",["main_task"],operations.scene,interactions,operations.actor,[_transition(prefix,"work_%d" % index,str(["scene_change","feedback","stage"][index % 3]),"The %s beat moves props and actors for %s." % [str(c.beats[(index - 1) % c.beats.size()]).replace("_"," "),str(c.verbs[index]).replace("_"," ")])],branches))
	for terminal in [["success",c.outcomes[0]],["failure",c.outcomes[1]],["refused",c.outcomes[2]],["interrupted",c.outcomes[3]]]:
		phases.append(_phase("terminal_%s" % terminal[0],str(terminal[0]).capitalize(),"The active task gives way to a branch-specific room arrangement.","The marked exit remains readable through cleanup.",[],[],[],[],[_transition(prefix,"terminal_%s" % terminal[0],"feedback","The %s aftermath fixes a distinct %s room state for revisit." % [str(terminal[1]).replace("_"," "),prefix.replace("_"," ")])],[{"id":"%s_terminal_%s" % [prefix,terminal[0]],"condition":{"type":"always"},"outcome":terminal[1]}],true))
	var aftermath := _aftermath(c)
	var declared_zones: Array = ["base::zone:left", "base::zone:center", "base::zone:right", "base::zone:background", "base::zone:exit_lane", "base::zone:service_lane"]
	for zone_index in range(c.verbs.size()): declared_zones.append("base::zone:work_%d" % zone_index)
	var sequence := {
		"schema_version":2,
		"local_state_schema":{"pressure_seen":{"type":"bool","default":false,"visibility":"public"}},
		"phase_graph":{"initial_phase":"arrival","phases":phases},
		"objectives":[{"id":"main_task","label":"%s room sequence" % str(c.id).replace("_"," ").capitalize(),"progress_label":"Physical task progress","steps":objective_steps,"outcomes":["success","failure","ignore","cancel"]}],
		"reentry_policy":{"partial":"resume","terminal":"aftermath","expired":"expired"},
		"expiry":{"boundary":"night_end","after":1,"policy":"cleanup"},
		"cleanup":{"operations":cleanup},
		"aftermath":aftermath,
		"declared_targets":{"scene_objects":[],"interactions":[],"actors":[],"services":[],"games":[],"routes":[],"anchors":[],"zones":declared_zones},
		"mechanic_tags":c.tags,
		"sequence_signature":"pending",
		"owner_exceptions":[],
		"fact_subscriptions":[_fact_subscription(c),"travel_departed"],
		"completion_contract":{"arrival_readable":true,"semantic_changes":true,"scenario_interaction":true,"action_boundaries":true,"choice_or_failure":true,"material_outcomes":true,"revisit_coverage":true,"world_connection":true,"primary_verb":true,"feedback_and_exit":true},
	}
	return {"scenario_id":c.id,"sequence":sequence,"authoring":{"arrival_summary":c.arrival,"player_verbs":c.verbs + ["refuse_%s" % prefix,"ignore_%s" % prefix],"world_connections":[str(c.fact),"travel_departed"],"references":{"objects":["base::travel:leave"]},"capture_ids":["%s_arrival" % prefix,"%s_partial" % prefix,"%s_success" % prefix,"%s_failure" % prefix,"%s_refused" % prefix,"%s_interrupted" % prefix,"%s_reduced_motion" % prefix,"%s_small_screen" % prefix,"%s_hit_overlay" % prefix],"seed_evidence":{"proof_seed":"%s_seed" % prefix,"save_boundaries":["arrival","partial","success","failure","refused","interrupted"],"minimum_target_size":44,"expected_outcomes":c.outcomes},"masked_visual_explanations":{}}}


func _phase(id:String,label:String,feedback:String,exit_prompt:String,objectives:Array,scene:Array,interactions:Array,actors:Array,transitions:Array,branches:Array,terminal:bool=false)->Dictionary:
	var result := {"id":id,"label":label,"arrival_feedback":feedback,"exit_prompt":exit_prompt,"entry_conditions":[],"objective_ids":objectives,"advance_after_actions":0,"scene_ops":scene,"interaction_ops":interactions,"actor_ops":actors,"transition_ops":transitions,"branches":branches}
	if terminal: result["terminal"] = true
	return result


func _decision_actions(c: Dictionary, phase_id: String, prefix: String) -> Array:
	var decision := _dict(c.get("decision", {}))
	if str(decision.get("at", "")) != phase_id:
		return []
	var result: Array = []
	var inputs := ["ui_left", "ui_up", "ui_right"]
	for index in range(_array(decision.get("options", [])).size()):
		var option := _array(decision.get("options", []))[index] as Array
		result.append(_action(str(option[0]), str(option[0]).replace("_", " ").capitalize(), inputs[index]))
	return result


func _decision_branches(c: Dictionary, phase_id: String, prefix: String) -> Array:
	var decision := _dict(c.get("decision", {}))
	if str(decision.get("at", "")) != phase_id:
		return []
	var result: Array = []
	for index in range(_array(decision.get("options", [])).size()):
		var option := _array(decision.get("options", []))[index] as Array
		var target := str(option[1])
		var status := "success"
		if target == "terminal_failure": status = "failure"
		elif target == "terminal_refused": status = "ignore"
		elif target == "terminal_interrupted": status = "cancel"
		result.append(_branch(prefix, "%s_identity_%d" % [phase_id, index], {"type":"command", "command_id":str(option[0])}, target, "", {"main_task":status}))
	return result


func _fact_payload(c: Dictionary) -> Dictionary:
	if str(c.id) == "punchline_debt_court": return {"game_id":"crew_draw_poker","action_id":"room_duty_boundary"}
	if str(c.id) == "punchline_high_stakes_night": return {"game_id":"underground_high_stakes","action_id":"session_ended"}
	return {}


func _fact_condition(c: Dictionary) -> Dictionary:
	var result := {"type":"fact","fact_type":str(c.fact)}
	var payload := _fact_payload(c)
	if not payload.is_empty(): result["payload_equals"] = payload
	return result


func _fact_subscription(c: Dictionary) -> Variant:
	var payload := _fact_payload(c)
	return {"fact_type":str(c.fact),"payload_equals":payload} if not payload.is_empty() else str(c.fact)


func _branch(prefix:String,id:String,condition:Dictionary,next_phase:String,outcome:String,objective_outcomes:Dictionary={})->Dictionary:
	var result := {"id":"%s_%s" % [prefix,id],"condition":condition}
	if not next_phase.is_empty(): result["next_phase"] = next_phase
	else: result["outcome"] = outcome
	if not objective_outcomes.is_empty(): result["objective_outcomes"] = objective_outcomes
	return result


func _scene_spawn(prefix:String,boundary:String,id:String,label:String,role:String,zone:String,state:String,w:int,h:int)->Dictionary:
	return {"family":"scene_ops","op":"spawn","receipt_id":"%s_%s_spawn_%s" % [prefix,boundary,id],"owner_namespace":"scenario","stable_object_id":id,"object":{"label":label,"role":role,"zone_id":zone,"bounds":{"w":w,"h":h},"visible":true,"enabled":true,"state":state,"appearance":state}}


func _actor_spawn(prefix:String,boundary:String,id:String,label:String,actor_id:String,zone:String,behavior:String)->Dictionary:
	var bounded_behavior := behavior if ["idle", "watch", "patrol", "guard", "flee", "fight", "work", "depart"].has(behavior) else "watch"
	return {"family":"actor_ops","op":"spawn","receipt_id":"%s_%s_spawn_%s" % [prefix,boundary,id],"owner_namespace":"scenario","stable_object_id":id,"actor":{"label":label,"actor_id":actor_id,"zone_id":zone,"behavior":bounded_behavior,"pose":"arrival"}}


func _interaction_add(prefix:String,boundary:String,id:String,label:String,prompt:String,actions:Array,safe_exit:bool)->Dictionary:
	var inputs: Array = []
	for action in actions:
		if not inputs.has(action.input_action): inputs.append(action.input_action)
	return {"family":"interaction_ops","op":"add","receipt_id":"%s_%s_add_%s" % [prefix,boundary,id],"owner_namespace":"scenario","stable_object_id":id,"interaction":{"owner_namespace":"scenario","stable_object_id":id,"presentation_object_id":"scenario::%s" % id,"label":label,"state_label":"%s station" % boundary.replace("_"," ").capitalize(),"prompt":"%s: %s" % [prefix.replace("_"," ").capitalize(),prompt],"enabled":true,"disabled_reason":"","available_actions":actions,"input_actions":inputs,"non_color_state":"%s_ready" % boundary,"focus_order":1,"hit_bounds":{"w":64,"h":56},"min_target_size":44,"safe_exit":safe_exit,"alternate_exit":false}}


func _action(id:String,label:String,input:String)->Dictionary:
	return {"id":id,"label":label,"input_action":input,"non_color_state":"ready"}


func _step_action(id:String,prefix:String,step:String)->Dictionary:
	return {"id":id,"label":id.replace("_"," ").capitalize(),"input_action":"ui_accept","non_color_state":"work","handler":"complete_objective_step","inputs":{"objective_id":"main_task","step_id":step}}


func _gate(prefix:String,boundary:String,id:String,target:String)->Dictionary:
	return {"family":"interaction_ops","op":"gate","receipt_id":"%s_%s_gate_%s" % [prefix,boundary,id],"owner_namespace":"scenario","stable_object_id":id,"mode":"gate","target_owner_namespace":"scenario","target_stable_object_id":target,"enabled":false,"disabled_reason":"%s has advanced beyond %s to its next physical station." % [prefix.replace("_"," ").capitalize(),target.replace("_"," ")]}


func _remove(family:String,prefix:String,id:String)->Dictionary:
	return {"family":family,"op":"remove","receipt_id":"%s_cleanup_remove_%s" % [prefix,id],"owner_namespace":"scenario","stable_object_id":id}


func _despawn(prefix:String,id:String)->Dictionary:
	return {"family":"actor_ops","op":"despawn","receipt_id":"%s_cleanup_despawn_%s" % [prefix,id],"owner_namespace":"scenario","stable_object_id":id}


func _transition(prefix:String,boundary:String,kind:String,message:String)->Dictionary:
	var result := {"family":"transition_ops","op":kind,"receipt_id":"%s_%s_transition_%s" % [prefix,boundary,kind],"owner_namespace":"scenario","stable_object_id":"%s_%s_transition" % [prefix,boundary],"channel":"room"}
	if kind == "stage": result.merge({"message":message,"stage_id":"%s_%s_stage" % [prefix,boundary],"duration_boundaries":1,"reduced_motion_message":"%s reaches the same semantic state without motion." % prefix.replace("_"," ").capitalize()})
	elif kind == "scene_change": result.merge({"message":message,"change_id":"%s_%s_change" % [prefix,boundary]})
	else: result["message"] = message
	return result


func _beat_operations(c:Dictionary,index:int)->Dictionary:
	var prefix := str(c.id)
	var beat := str(c.beats[index % c.beats.size()])
	var object_id := "%s_%s" % [prefix,c.objects[index % c.objects.size()][0]]
	var actor_id := "%s_%s" % [prefix,c.actors[index % c.actors.size()][0]]
	var scene: Array = []
	var actor: Array = []
	match index % 5:
		0:
			scene.append({"family":"scene_ops","op":"move","receipt_id":"%s_%s_move" % [prefix,beat],"owner_namespace":"scenario","stable_object_id":object_id,"zone_id":"work_%d" % index})
			actor.append({"family":"actor_ops","op":"set_pose","receipt_id":"%s_%s_pose" % [prefix,beat],"owner_namespace":"scenario","stable_object_id":actor_id,"pose":beat})
		1:
			scene.append({"family":"scene_ops","op":"set_appearance","receipt_id":"%s_%s_appearance" % [prefix,beat],"owner_namespace":"scenario","stable_object_id":object_id,"appearance":"%s_changed" % beat})
			actor.append({"family":"actor_ops","op":"set_position","receipt_id":"%s_%s_position" % [prefix,beat],"owner_namespace":"scenario","stable_object_id":actor_id,"zone_id":"work_%d" % index})
		2:
			scene.append({"family":"scene_ops","op":"set_state","receipt_id":"%s_%s_state" % [prefix,beat],"owner_namespace":"scenario","stable_object_id":object_id,"state":"%s_resolved" % beat})
			actor.append({"family":"actor_ops","op":"set_behavior","receipt_id":"%s_%s_behavior" % [prefix,beat],"owner_namespace":"scenario","stable_object_id":actor_id,"behavior":"watch"})
		3:
			scene.append({"family":"scene_ops","op":"hide","receipt_id":"%s_%s_hide" % [prefix,beat],"owner_namespace":"scenario","stable_object_id":object_id})
			actor.append({"family":"actor_ops","op":"set_behavior","receipt_id":"%s_%s_depart" % [prefix,beat],"owner_namespace":"scenario","stable_object_id":actor_id,"behavior":"depart"})
		_:
			scene.append({"family":"scene_ops","op":"disable","receipt_id":"%s_%s_disable" % [prefix,beat],"owner_namespace":"scenario","stable_object_id":object_id,"disabled_reason":"This station closes after its task."})
			actor.append({"family":"actor_ops","op":"set_pose","receipt_id":"%s_%s_final_pose" % [prefix,beat],"owner_namespace":"scenario","stable_object_id":actor_id,"pose":"finished"})
	return {"scene":scene,"actor":actor}


func _aftermath(c:Dictionary)->Dictionary:
	var result := {}
	var prefix := str(c.id)
	var axes := [["scene","actor"],["scene","service"],["actor"],["scene"]]
	for index in range(c.outcomes.size()):
		var outcome := str(c.outcomes[index])
		var row := {"label":outcome.replace("_"," ").capitalize(),"revisit_feedback":"The %s arrangement remains physically readable on revisit." % outcome}
		for axis in axes[index]:
			if axis == "scene": row["scene_ops"] = [_scene_spawn(prefix,"aftermath_%s" % outcome,"%s_aftermath_%s_prop" % [prefix,outcome],"%s room marker" % outcome.replace("_"," ").capitalize(),["arrangement","debris","closed_zone","route_marker"][index],["center","right","left","exit_lane"][index],outcome,64 + index * 8,48 + index * 6)]
			elif axis == "actor": row["actor_ops"] = [_actor_spawn(prefix,"aftermath_%s" % outcome,"%s_aftermath_%s_actor" % [prefix,outcome],"%s remaining actor" % outcome.replace("_"," ").capitalize(),"actor_%s" % outcome,["center","right","left","background"][index],["work","guard","watch","depart"][index])]
			elif axis == "service": row["service_ops"] = [{"family":"service_ops","op":"add","receipt_id":"%s_aftermath_%s_service" % [prefix,outcome],"owner_namespace":"scenario","stable_object_id":"%s_%s_service" % [prefix,outcome],"object":{"id":"%s_%s_service" % [prefix,outcome],"label":"%s aftermath service" % outcome.replace("_"," ").capitalize(),"enabled":false,"disabled_reason":"The failed branch closes this service."}}]
		result[outcome] = row
	return result


func _definitions(entries:Array)->Array:
	var result: Array = []
	for entry in entries:
		result.append({"id":entry.scenario_id,"sequence":entry.sequence,"sequence_package_id":"env06_7_punchline_clubs","sequence_handler_pack":"punchline_clubs","sequence_renderer_id":"punchline_clubs","sequence_authoring":entry.authoring})
	return result


func _target_inventory() -> Dictionary:
	var zones := ["base::zone:left", "base::zone:center", "base::zone:right", "base::zone:background", "base::zone:exit_lane", "base::zone:service_lane"]
	for index in range(6): zones.append("base::zone:work_%d" % index)
	return {"scene_objects":[],"interactions":[],"actors":[],"services":[],"games":[],"routes":[],"anchors":[],"zones":zones,"event_choices":{}}


func _dossier(c:Dictionary,entry:Dictionary)->Dictionary:
	return {"id":c.id,"archetype_id":c.archetype,"definition_path":OUTPUT,"phase_ids":entry.sequence.phase_graph.phases.map(func(p): return p.id),"terminal_outcomes":c.outcomes,"player_verbs":c.verbs,"changed_objects":c.objects.map(func(o): return o[0]),"changed_actors":c.actors.map(func(a): return a[0]),"world_connections":[c.fact,"travel_departed"],"reentry_policy":entry.sequence.reentry_policy,"sequence_signature":entry.sequence.sequence_signature,"capture_ids":entry.authoring.capture_ids,"exact_receipt_prefix":c.id}


func _write_json(path:String,value:Variant)->void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"  ",false)+"\n")
	file.close()


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
