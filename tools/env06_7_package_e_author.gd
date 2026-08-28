extends SceneTree

const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")

const OUTPUT := "res://data/environments/scenario_sequences/env06_7_queen_public.json"
const DOSSIERS := "res://docs/plans/env06_7_package_e_sequence_dossiers.json"

const CONFIGS := [
	{"id":"delta_queen_wedding_charter","archetype":"delta_queen","arrival":"Ceremony ropes split the promenade while the open bar, a loose ring case, and a losing best man pull guests into competing deck lanes.","verbs":["secure_ceremony_lane","recover_ring_case","steady_best_man","deliver_rings"],"beats":["rope_move","ring_state","guest_route"],"fact":"travel_arrived","tags":["open_bar","loose_tables","best_man_pressure"],"objects":[["ceremony_rope","Ceremony rope","barrier","center","split"],["ring_case","Loose ring case","evidence","left","unattended"],["best_man_table","Best man table","game_station","right","losing"]],"actors":[["best_man","Losing best man","actor_best_man","right","watch"],["deck_coordinator","Deck coordinator","actor_deck_coordinator","background","work"]],"outcomes":["ceremony_delivered","table_opportunity","charter_delayed","departure_interrupted"]},
	{"id":"delta_queen_whale_aboard","archetype":"delta_queen","arrival":"A whale's entourage seals a premium table and bends every adjacent stake placard while staff abandon the public service lane.","verbs":["map_entourage_route","carry_whale_service","read_stake_shift","choose_whale_access"],"beats":["entourage_move","table_state","staff_behavior"],"fact":"game_result","tags":["whale_attention","stake_shift","heist_plan_b_anchor"],"objects":[["premium_table","Whale premium table","game_station","center","reserved"],["stake_placards","Shifted stake placards","scoreboard","right","raised"],["service_lane","Whale service lane","route_marker","left","restricted"]],"actors":[["whale_host","Whale host","actor_whale_host","center","guard"],["entourage_runner","Entourage runner","actor_entourage_runner","left","work"]],"outcomes":["earned_whale_access","shadowed_entourage","security_lock","whale_departed"]},
	{"id":"delta_queen_fog_delay","archetype":"delta_queen","arrival":"Fog shutters the gangway, traps a restless boarding crowd, and raises the visible stake board one phase at a time.","verbs":["read_fog_signal","organize_waiting_crowd","mark_stake_drift","choose_dock_plan"],"beats":["signal_appearance","crowd_position","stake_state"],"fact":"town_transition","tags":["fog_closure","trapped_crowd","phase_stake_drift"],"objects":[["fog_signal","Fog signal lamp","navigation","left","closed"],["gangway_shutter","Closed gangway","barrier","exit_lane","sealed"],["drift_board","Rising stake board","scoreboard","right","phase_one"]],"actors":[["deck_officer","Deck officer","actor_deck_officer","background","work"],["waiting_crowd","Waiting crowd","actor_waiting_crowd","center","watch"]],"outcomes":["assisted_reroute","safe_wait","crowd_exploited","fog_departure"]},
	{"id":"delta_queen_engine_trouble","archetype":"delta_queen","arrival":"A dead engine anchors the boat mid-river; the locked gangway, falling pressure gauge, and evacuation benches make every route visible.","verbs":["seal_engine_lane","diagnose_pressure","fetch_impeller_key","choose_engine_response","restart_engine"],"beats":["bulkhead_state","gauge_appearance","bench_move"],"fact":"world_boundary","tags":["travel_locked","power_decay","rising_tension"],"objects":[["engine_bulkhead","Hot engine bulkhead","barrier","center","sealed"],["pressure_gauge","Falling pressure gauge","instrument","left","critical"],["evacuation_benches","Evacuation benches","safety","right","empty"],["locked_gangway","Locked mid-river gangway","route_marker","exit_lane","locked"]],"actors":[["engine_mate","Engine mate","actor_engine_mate","left","work"],["deck_guard","Gangway guard","actor_deck_guard","right","guard"]],"outcomes":["travel_resumed","limited_power","evacuation_staged","engine_abandoned"]},
	{"id":"delta_queen_captains_invitational","archetype":"delta_queen","arrival":"Entry cards, three bracket tables, and a scorer rail replace the open deck while eliminated players close lanes behind them.","verbs":["verify_entry_card","score_opening_bracket","rotate_eliminated_table","choose_invitational_role","seat_finalists"],"beats":["card_state","bracket_move","spectator_behavior"],"fact":"game_result","tags":["captain_invitational","qualification","disputed_bracket"],"objects":[["entry_cards","Invitational entry cards","credential","left","checking"],["bracket_tables","Captain bracket tables","game_station","center","opening"],["scorer_rail","Scorer rail","scoreboard","right","active"]],"actors":[["captain_scorer","Captain scorer","actor_captain_scorer","right","work"],["eliminated_players","Eliminated players","actor_eliminated_players","background","watch"]],"outcomes":["qualified_final","observed_final","disputed_final","tournament_interrupted"]},
	{"id":"grand_casino_gala_night","archetype":"grand_casino","arrival":"Coat check, charity credentials, and a stalled stage lift replace the normal floor route without touching the duel or invite gate.","verbs":["claim_coat_token","verify_charity_badge","reset_stage_lift","choose_gala_identity"],"beats":["token_move","badge_state","lift_appearance"],"fact":"service_result","tags":["gala_cover","charity_crowd","boss_gate_sacred"],"objects":[["coat_check","Gala coat check","service","left","busy"],["charity_badges","Charity credential desk","credential","center","checking"],["stage_lift","Stalled gala stage lift","workstation","right","stalled"]],"actors":[["gala_host","Gala host","actor_gala_host","center","guard"],["stage_hand","Gala stage hand","actor_stage_hand","right","work"]],"outcomes":["cover_identity_accepted","public_floor_reopened","credential_failed","gala_interrupted"]},
	{"id":"grand_casino_convention_crowd","archetype":"grand_casino","arrival":"Badge-wearing delegations reserve two machine banks and collide at one table block, making camouflage and reduced comps publicly legible.","verbs":["read_booking_board","sort_delegation_badges","move_machine_markers","choose_convention_route"],"beats":["board_state","badge_move","delegation_behavior"],"fact":"game_result","tags":["badge_camouflage","comp_reduction","reservation_rotation"],"objects":[["booking_board","Convention booking board","ledger","left","conflicted"],["machine_banks","Reserved machine banks","game_station","center","split"],["table_block","Contested table block","barrier","right","crowded"]],"actors":[["convention_coordinator","Convention coordinator","actor_convention_coordinator","left","work"],["badge_delegations","Badge delegations","actor_badge_delegations","center","patrol"]],"outcomes":["camouflage_route","split_schedule","floor_standoff","convention_departed"]},
	{"id":"grand_casino_audit_night","archetype":"grand_casino","arrival":"Auditors move from cage seal to pit ledger while staff close each inspected zone; the public route anchors heist Plan A without revealing hidden audit state.","verbs":["acknowledge_audit_route","present_pit_ledger","mark_closed_games","choose_audit_response"],"beats":["seal_state","ledger_move","barrier_appearance"],"fact":"heat_band_changed","tags":["strict_cage","nervous_floor","heist_plan_a_anchor"],"objects":[["cage_seal","Audit cage seal","evidence","left","intact"],["pit_ledger","Pit audit ledger","ledger","center","requested"],["audit_barrier","Audit zone barrier","barrier","right","moving"],["open_exit_marker","Public exit marker","route_marker","exit_lane","open"]],"actors":[["lead_auditor","Lead auditor","actor_lead_auditor","center","work"],["pit_manager","Pit manager","actor_pit_manager","right","guard"]],"outcomes":["compliant_floor","redirected_audit","closed_games","audit_interrupted"]},
]

const DECISIONS := {
	"delta_queen_wedding_charter":{"at":"work_1","options":[["return_rings_to_best_man","work_2"],["exploit_loose_wedding_tables","terminal_success"],["delay_wedding_charter","terminal_refused"]]},
	"delta_queen_whale_aboard":{"at":"work_2","options":[["earn_whale_service_access","work_3"],["shadow_whale_entourage","terminal_success"],["trigger_whale_security_lock","terminal_failure"]]},
	"delta_queen_fog_delay":{"at":"work_1","options":[["assist_fog_reroute","work_2"],["wait_out_fog_safely","terminal_success"],["exploit_trapped_fog_crowd","terminal_failure"]]},
	"delta_queen_engine_trouble":{"at":"work_3","options":[["repair_engine_for_departure","work_4"],["ration_limited_engine_power","terminal_success"],["stage_engine_evacuation","terminal_failure"]]},
	"delta_queen_captains_invitational":{"at":"work_3","options":[["qualify_for_captains_final","work_4"],["observe_captains_final","terminal_success"],["dispute_captains_bracket","terminal_failure"]]},
	"grand_casino_gala_night":{"at":"work_2","options":[["assume_gala_cover_identity","work_3"],["reopen_public_gala_floor","terminal_success"],["fail_gala_credentials","terminal_failure"]]},
	"grand_casino_convention_crowd":{"at":"work_2","options":[["blend_with_badge_crowd","work_3"],["split_convention_schedule","terminal_success"],["trigger_convention_standoff","terminal_failure"]]},
	"grand_casino_audit_night":{"at":"work_1","options":[["comply_with_audit_route","work_2"],["redirect_public_audit","terminal_success"],["close_audited_games","terminal_failure"]]},
}


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
	_write_json(OUTPUT, {"schema_version":1,"package_id":"env06_7_queen_public","handler_pack":"queen_public","renderer_id":"queen_public","scenarios":entries})
	_write_json(DOSSIERS, {"schema_version":1,"package_id":"env06_7_queen_public","base_head":"855a296126e8b4747b78fbe89cb5a2d02daf61f5","scenario_count":entries.size(),"dossiers":dossiers,"uniqueness_rows":report.rows,"pairwise_similarity":report.pairs,"assembly_evidence_needed":report.failures,"pair_count":report.comparison_count})
	print("ENV06_7_PACKAGE_E_AUTHOR_OK scenarios=%d pairs=%d" % [entries.size(), report.comparison_count])
	quit(0)


func _entry(c: Dictionary) -> Dictionary:
	var prefix := str(c.id)
	var decision := _dict(DECISIONS.get(prefix, {}))
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
		_interaction_add(prefix, "arrival", first_task_id, str(c.verbs[0]).replace("_", " ").capitalize(), "Begin the first physical task or choose this identity's named route.", [_step_action(str(c.verbs[0]), prefix, str(c.verbs[0])), _action("fail_%s" % prefix, "Let the pressure win", "ui_right")] + _decision_actions(decision, "arrival"), false),
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
	arrival_branches.append_array(_decision_branches(decision, "arrival", prefix))
	phases.append(_phase("arrival", "Arrival", str(c.arrival), "The marked clean exit remains available.", ["main_task"], scene_ops, arrival_interactions, actor_ops, [_transition(prefix,"arrival","stage","The %s station opens around %s." % [prefix.replace("_"," "),str(c.verbs[0]).replace("_"," ")])], arrival_branches))
	for index in range(1, c.verbs.size()):
		var task_id := "%s_task_%d" % [prefix, index]
		var previous_task_id := "%s_task_%d" % [prefix, index - 1]
		var gate_id := "%s_gate_%d" % [prefix, index - 1]
		var operations := _beat_operations(c, index - 1)
		var phase_id := "work_%d" % index
		var interactions := [_gate(prefix,phase_id,gate_id,previous_task_id), _interaction_add(prefix,phase_id,task_id,str(c.verbs[index]).replace("_"," ").capitalize(),"Complete this operation or choose its identity-specific route.",[_step_action(str(c.verbs[index]),prefix,str(c.verbs[index])),_action("fail_%s" % prefix,"Let the pressure win","ui_right"),_action("refuse_%s" % prefix,"Refuse and leave","ui_cancel")] + _decision_actions(decision, phase_id),false)]
		# Remove gate overlays before their underlying task interactions so cleanup
		# cannot restore an already-removed target and leak it across revisit.
		cleanup.push_front(_remove("interaction_ops",prefix,gate_id))
		cleanup.append(_remove("interaction_ops",prefix,task_id))
		objective_steps.append({"id":str(c.verbs[index]),"label":str(c.verbs[index]).replace("_"," ").capitalize(),"kind":"command","command_id":str(c.verbs[index])})
		var next_phase := "terminal_success" if index == c.verbs.size() - 1 else "work_%d" % (index + 1)
		var branches := [
			_branch(prefix,"work_%d_complete" % index,{"type":"command","command_id":str(c.verbs[index])},next_phase,"",{"main_task":"success"}),
			_branch(prefix,"work_%d_pressure" % index,{"type":"fact","fact_type":str(c.fact)},"terminal_failure","",{"main_task":"failure"}),
			_branch(prefix,"work_%d_fail" % index,{"type":"command","command_id":"fail_%s" % prefix},"terminal_failure","",{"main_task":"failure"}),
			_branch(prefix,"work_%d_refuse" % index,{"type":"command","command_id":"refuse_%s" % prefix},"terminal_refused","",{"main_task":"ignore"}),
			_branch(prefix,"work_%d_interrupt" % index,{"type":"fact","fact_type":"travel_departed"},"terminal_interrupted","",{"main_task":"cancel"}),
		]
		branches.append_array(_decision_branches(decision, phase_id, prefix))
		phases.append(_phase("work_%d" % index,"Work beat %d" % index,"The room advances to a new physical station and actor arrangement.","The marked clean exit remains available.",["main_task"],operations.scene,interactions,operations.actor,[_transition(prefix,"work_%d" % index,str(["scene_change","feedback","stage"][index % 3]),"The %s beat moves props and actors for %s." % [str(c.beats[(index - 1) % c.beats.size()]).replace("_"," "),str(c.verbs[index]).replace("_"," ")])],branches))
	for terminal in [["success",c.outcomes[0]],["failure",c.outcomes[1]],["refused",c.outcomes[2]],["interrupted",c.outcomes[3]]]:
		phases.append(_phase("terminal_%s" % terminal[0],str(terminal[0]).capitalize(),"The active task gives way to a branch-specific room arrangement.","The marked exit remains readable through cleanup.",[],[],[],[],[_transition(prefix,"terminal_%s" % terminal[0],"feedback","The %s aftermath fixes a distinct %s room state for revisit." % [str(terminal[1]).replace("_"," "),prefix.replace("_"," ")])],[{"id":"%s_terminal_%s" % [prefix,terminal[0]],"condition":{"type":"always"},"outcome":terminal[1]}],true))
	var aftermath := _aftermath(c)
	var sequence := {
		"schema_version":2,
		"local_state_schema":{"pressure_seen":{"type":"bool","default":false,"visibility":"public"}},
		"phase_graph":{"initial_phase":"arrival","phases":phases},
		"objectives":[{"id":"main_task","label":"%s room sequence" % str(c.id).replace("_"," ").capitalize(),"progress_label":"Physical task progress","steps":objective_steps,"outcomes":["success","failure","ignore","cancel"]}],
		"reentry_policy":{"partial":"resume","terminal":"aftermath","expired":"expired"},
		"expiry":{"boundary":"night_end","after":1,"policy":"cleanup"},
		"cleanup":{"operations":cleanup},
		"aftermath":aftermath,
		"declared_targets":{"scene_objects":[],"interactions":[],"actors":[],"services":[],"games":[],"routes":[],"anchors":[],"zones":_target_inventory().zones},
		"mechanic_tags":c.tags,
		"sequence_signature":"pending",
		"owner_exceptions":[],
		"fact_subscriptions":[str(c.fact),"travel_departed"],
		"completion_contract":{"arrival_readable":true,"semantic_changes":true,"scenario_interaction":true,"action_boundaries":true,"choice_or_failure":true,"material_outcomes":true,"revisit_coverage":true,"world_connection":true,"primary_verb":true,"feedback_and_exit":true},
	}
	var decision_verbs: Array = []
	for option_value in _array(decision.get("options", [])): decision_verbs.append(str((option_value as Array)[0]))
	return {"scenario_id":c.id,"sequence":sequence,"authoring":{"arrival_summary":c.arrival,"player_verbs":c.verbs + decision_verbs + ["refuse_%s" % prefix,"ignore_%s" % prefix],"world_connections":[str(c.fact),"travel_departed"],"references":{"objects":["base::travel:leave"]},"capture_ids":["%s_arrival" % prefix,"%s_partial" % prefix,"%s_success" % prefix,"%s_failure" % prefix,"%s_refused" % prefix,"%s_interrupted" % prefix,"%s_reduced_motion" % prefix,"%s_small_screen" % prefix,"%s_hit_overlay" % prefix,"%s_obstruction" % prefix],"seed_evidence":{"proof_seed":"%s_seed" % prefix,"save_boundaries":["arrival","partial","success","failure","refused","interrupted"],"minimum_target_size":44,"expected_outcomes":c.outcomes,"identity_decision_phase":decision.at,"identity_decision_verbs":decision_verbs},"masked_visual_explanations":{}}}


func _phase(id:String,label:String,feedback:String,exit_prompt:String,objectives:Array,scene:Array,interactions:Array,actors:Array,transitions:Array,branches:Array,terminal:bool=false)->Dictionary:
	var result := {"id":id,"label":label,"arrival_feedback":feedback,"exit_prompt":exit_prompt,"entry_conditions":[],"objective_ids":objectives,"advance_after_actions":0,"scene_ops":scene,"interaction_ops":interactions,"actor_ops":actors,"transition_ops":transitions,"branches":branches}
	if terminal: result["terminal"] = true
	return result

func _decision_actions(decision: Dictionary, phase_id: String) -> Array:
	if str(decision.get("at", "")) != phase_id: return []
	var result: Array = []
	var inputs := ["ui_left","ui_up","ui_right"]
	for index in range(_array(decision.get("options", [])).size()):
		var option := _array(decision.get("options", []))[index] as Array
		result.append(_action(str(option[0]),str(option[0]).replace("_"," ").capitalize(),inputs[index]))
	return result

func _decision_branches(decision: Dictionary, phase_id: String, prefix: String) -> Array:
	if str(decision.get("at", "")) != phase_id: return []
	var result: Array = []
	for index in range(_array(decision.get("options", [])).size()):
		var option := _array(decision.get("options", []))[index] as Array
		var target := str(option[1])
		var objective := "success"
		if target == "terminal_failure": objective = "failure"
		elif target == "terminal_refused": objective = "ignore"
		elif target == "terminal_interrupted": objective = "cancel"
		result.append(_branch(prefix,"%s_identity_%d" % [phase_id,index],{"type":"command","command_id":str(option[0])},target,"",{"main_task":objective}))
	return result


func _branch(prefix:String,id:String,condition:Dictionary,next_phase:String,outcome:String,objective_outcomes:Dictionary={})->Dictionary:
	var result := {"id":"%s_%s" % [prefix,id],"condition":condition}
	if not next_phase.is_empty(): result["next_phase"] = next_phase
	else: result["outcome"] = outcome
	if not objective_outcomes.is_empty(): result["objective_outcomes"] = objective_outcomes
	return result


func _scene_spawn(prefix:String,boundary:String,id:String,label:String,role:String,zone:String,state:String,w:int,h:int)->Dictionary:
	return {"family":"scene_ops","op":"spawn","receipt_id":"%s_%s_spawn_%s" % [prefix,boundary,id],"owner_namespace":"scenario","stable_object_id":id,"object":{"label":label,"role":role,"zone_id":zone,"bounds":{"w":w,"h":h},"visible":true,"enabled":true,"state":state,"appearance":state}}


func _actor_spawn(prefix:String,boundary:String,id:String,label:String,actor_id:String,zone:String,behavior:String)->Dictionary:
	return {"family":"actor_ops","op":"spawn","receipt_id":"%s_%s_spawn_%s" % [prefix,boundary,id],"owner_namespace":"scenario","stable_object_id":id,"actor":{"label":label,"actor_id":actor_id,"zone_id":zone,"behavior":behavior,"pose":"arrival"}}


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
		result.append({"id":entry.scenario_id,"sequence":entry.sequence,"sequence_package_id":"env06_7_queen_public","sequence_handler_pack":"queen_public","sequence_renderer_id":"queen_public","sequence_authoring":entry.authoring})
	return result


func _dossier(c:Dictionary,entry:Dictionary)->Dictionary:
	return {"id":c.id,"archetype_id":c.archetype,"definition_path":OUTPUT,"phase_ids":entry.sequence.phase_graph.phases.map(func(p): return p.id),"terminal_outcomes":c.outcomes,"player_verbs":c.verbs,"changed_objects":c.objects.map(func(o): return o[0]),"changed_actors":c.actors.map(func(a): return a[0]),"world_connections":[c.fact,"travel_departed"],"reentry_policy":entry.sequence.reentry_policy,"sequence_signature":entry.sequence.sequence_signature,"capture_ids":entry.authoring.capture_ids,"exact_receipt_prefix":c.id}

func _target_inventory() -> Dictionary:
	var zones := ["base::zone:left","base::zone:right","base::zone:center","base::zone:background","base::zone:service_lane","base::zone:foreground","base::zone:exit_lane"]
	for index in range(6): zones.append("base::zone:work_%d" % index)
	return {"scene_objects":[],"interactions":[],"actors":[],"services":[],"games":[],"routes":[],"anchors":[],"zones":zones,"event_choices":{}}

func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []

func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _write_json(path:String,value:Variant)->void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"  ",false)+"\n")
	file.close()





