extends SceneTree

const Schema := preload("res://scripts/core/scenario_sequence_schema.gd")

const OUTPUT := "res://data/environments/scenario_sequences/env06_7_bars_road.json"
const DOSSIERS := "res://docs/plans/env06_7_package_c_sequence_dossiers.json"

const CONFIGS := [
	{"id":"bar_wake","archetype":"bar","arrival":"Memorial tables join across the center aisle while a remembrance tray waits by the first patron.","verbs":["receive_remembrance","carry_to_regular","offer_before_toast"],"beats":["tray_move","patron_pose"],"fact":"crew_changed","tags":["memorial_relay","toast_deadline","crew_memory"],"objects":[["memorial_tables","Joined memorial tables","furniture","center","joined"],["remembrance_tray","Remembrance tray","memorial","left","sealed"]],"actors":[["wake_regular","Mourning regular","ada_corner_merchant","left","watch"],["wake_host","Wake host","priya_travel_merchant","background","work"]],"outcomes":["toast_shared","toast_withheld","declined","interrupted"]},
	{"id":"bar_fight_night","archetype":"bar","arrival":"Two argument lines split the room and a toppled chair narrows the marked door lane.","verbs":["brace_exit","warn_brawlers","separate_sides","reset_chairs"],"beats":["chair_move","actor_behavior","table_state"],"fact":"heat_changed","tags":["escalation_control","exit_defense","security_aftermath"],"objects":[["toppled_chair","Toppled chair","obstacle","center","fallen"],["split_table","Split fight table","furniture","right","shoved"],["door_buffer","Marked door buffer","route_marker","exit_lane","narrow"]],"actors":[["left_brawler","Left-side brawler","actor_left_brawler","left","fight"],["right_brawler","Right-side brawler","actor_right_brawler","right","fight"]],"outcomes":["deescalated","broken_room","side_chosen","security_controlled"]},
	{"id":"bar_payday_rush","archetype":"bar","arrival":"Order rails fill the counter while settlement envelopes and carrying trays divide service lanes.","verbs":["lift_first_tray","deliver_table_round","settle_open_tab"],"beats":["tray_move","counter_state"],"fact":"service_result","tags":["order_carry","tab_settlement","service_rotation"],"objects":[["order_rail","Loaded order rail","workstation","service_lane","queued"],["carrying_tray","Carrying tray","service","left","loaded"],["tab_envelopes","Open tab envelopes","ledger","right","unsettled"]],"actors":[["rush_bartender","Rush bartender","actor_bartender","background","work"],["payday_runner","Payday runner","actor_runner","center","work"]],"outcomes":["queue_cleared","orders_spilled","tabs_deferred","rush_abandoned"]},
	{"id":"bar_lock_in","archetype":"bar","arrival":"Shutters seal the legal door while a cellar hatch and private task bench become visible.","verbs":["check_shutter_latch","complete_private_task","signal_reopening"],"beats":["shutter_state","hatch_move"],"fact":"sweep_changed","tags":["sealed_exit","private_task","alternate_egress"],"objects":[["locked_shutters","Locked front shutters","barrier","exit_lane","sealed"],["cellar_hatch","Quiet cellar hatch","alternate_route","left","closed"],["private_bench","After-hours task bench","workstation","right","ready"]],"actors":[["lockin_host","Lock-in host","actor_lockin_host","center","guard"],["afterhours_regular","After-hours regular","actor_regular","background","watch"]],"outcomes":["included","quiet_exit","reopened","sweep_interrupted"]},
	{"id":"bar_darts_league_night","archetype":"bar","arrival":"Two throw lanes and a bracket easel replace ordinary seating around the oche.","verbs":["mark_throw_line","score_opening_round","inspect_disputed_dart","post_final_bracket"],"beats":["oche_move","score_state","crowd_position"],"fact":"game_result","tags":["round_officiation","disputed_throw","bracket_layout"],"objects":[["darts_oche","Darts throw line","game_lane","center","round_one"],["bracket_easel","League bracket easel","scoreboard","right","open"],["disputed_dart","Disputed board dart","evidence","background","embedded"]],"actors":[["league_captain","League captain","actor_league_captain","left","watch"],["darts_scorer","Darts scorer","actor_darts_scorer","right","work"]],"outcomes":["bracket_confirmed","dispute_upheld","match_forfeited","league_paused"]},
	{"id":"bar_live_band","archetype":"bar","arrival":"Speaker stacks, a cable crossing, and an unfinished stage consume the usual service route.","verbs":["trace_dead_cable","patch_soundcheck","reroute_crowd","strike_stage"],"beats":["cable_appearance","speaker_move","crowd_behavior"],"fact":"town_transition","tags":["soundcheck_repair","crowd_reroute","postshow_strike"],"objects":[["speaker_stack","Speaker stack","equipment","center","unpowered"],["cable_crossing","Cable crossing","route_hazard","service_lane","loose"],["band_stage","Band stage","performance","background","soundcheck"]],"actors":[["band_leader","Band leader","actor_band_leader","background","work"],["floor_runner","Floor runner","actor_floor_runner","left","patrol"]],"outcomes":["set_completed","set_failed","service_only","show_interrupted"]},
	{"id":"bar_dead_tuesday","archetype":"bar","arrival":"Three isolated task zones glow around the bartender, lone patron, and closed back booth.","verbs":["inspect_three_zones","choose_bartender_task","close_other_zones"],"beats":["zone_state","booth_appearance"],"fact":"world_boundary","tags":["exclusive_company","zone_activation","night_commitment"],"objects":[["bartender_zone","Bartender work zone","task_zone","left","available"],["patron_zone","Lone patron table","task_zone","center","available"],["booth_zone","Back booth task","task_zone","right","available"]],"actors":[["dead_tuesday_bartender","Quiet bartender","actor_bartender","left","idle"],["lone_patron","Lone Tuesday patron","actor_lone_patron","center","idle"]],"outcomes":["bartender_zone_kept","patron_zone_kept","booth_zone_kept","night_left_empty"]},
	{"id":"jazz_club_guest_legend","archetype":"jazz_club","arrival":"A reserved guest table blocks the stage stair while an empty instrument stand waits backstage.","verbs":["find_instrument_case","prepare_missing_cue","time_guest_reveal"],"beats":["case_move","stage_state"],"fact":"travel_arrived","tags":["instrument_retrieval","reveal_timing","set_reorder"],"objects":[["guest_table","Reserved legend table","furniture","center","reserved"],["instrument_case","Missing instrument case","instrument","left","latched"],["cue_stand","Empty cue stand","performance","background","waiting"]],"actors":[["guest_legend","Guest legend","actor_guest_legend","right","watch"],["stage_manager","Jazz stage manager","actor_stage_manager","background","work"]],"outcomes":["legend_revealed","cue_missed","guest_withheld","arrival_interrupted"]},
	{"id":"jazz_club_rent_party","archetype":"jazz_club","arrival":"Donation stations and moved chairs form a visible funding circuit around the bandstand.","verbs":["open_donation_station","run_record_sale","count_rent_marker","answer_creditor"],"beats":["station_move","furniture_state","creditor_behavior"],"fact":"crew_job_changed","tags":["revenue_circuit","rent_threshold","creditor_pressure"],"objects":[["donation_station","Donation station","economy_station","left","open"],["record_crate","Benefit record crate","stock","center","sealed"],["rent_marker","Rent progress marker","scoreboard","right","short"]],"actors":[["rent_host","Rent party host","actor_rent_host","background","work"],["club_creditor","Waiting creditor","actor_creditor","right","watch"]],"outcomes":["music_continues","creditor_occupies","terms_challenged","party_interrupted"]},
	{"id":"jazz_club_recording_night","archetype":"jazz_club","arrival":"Microphone trees and taped silence zones create a narrow, quiet route to the recording desk.","verbs":["enter_silence_route","reset_microphone_tree","mark_clean_take"],"beats":["microphone_move","take_state"],"fact":"scenario_command","tags":["silence_navigation","take_reset","recording_receipt"],"objects":[["microphone_tree","Microphone tree","recording_equipment","center","armed"],["silence_tape","Taped silence zone","route_marker","left","active"],["recording_desk","Recording desk","workstation","background","ready"]],"actors":[["recording_engineer","Recording engineer","actor_engineer","background","work"],["waiting_audience","Relocated audience","actor_audience","right","watch"]],"outcomes":["take_saved","session_ruined","audience_relocated","recording_interrupted"]},
	{"id":"jazz_club_union_trouble","archetype":"jazz_club","arrival":"A picket line and management rope split the two entrances while the stage remains unbuilt.","verbs":["read_both_lines","carry_neutral_stand","assemble_agreed_stage","open_entry_route"],"beats":["stand_move","stage_appearance","picket_behavior"],"fact":"heat_band_changed","tags":["entrance_split","setup_mediation","labor_aftermath"],"objects":[["picket_line","Musicians picket line","barrier","left","holding"],["management_rope","Management entry rope","barrier","right","closed"],["unbuilt_stage","Unbuilt jazz stage","worksite","background","stopped"]],"actors":[["union_delegate","Union delegate","actor_union_delegate","left","guard"],["club_manager","Club manager","actor_club_manager","right","guard"]],"outcomes":["mediated_entry","union_entry","management_entry","club_closed"]},
]


func _initialize() -> void:
	var entries: Array = []
	var dossiers: Array = []
	var failures: Array = []
	for config in CONFIGS:
		var entry := _entry(config)
		var definition := {"id": config.id, "archetype_id": config.archetype, "sequence": entry.sequence}
		entry.sequence.sequence_signature = Schema.calculated_signature_hash(definition)
		definition.sequence = entry.sequence
		var errors := Schema.validate_definition(definition)
		if not errors.is_empty(): failures.append({"id":config.id,"errors":errors})
		entries.append(entry)
		dossiers.append(_dossier(config, entry))
	var report := Schema.catalog_uniqueness_report(_definitions(entries), entries.size())
	if not bool(report.get("ok", false)): failures.append({"uniqueness":report.get("failures", [])})
	if not failures.is_empty():
		printerr(JSON.stringify(failures, "  "))
		quit(1)
		return
	_write_json(OUTPUT, {"schema_version":1,"package_id":"env06_7_bars_road","handler_pack":"bars_road","renderer_id":"bars_road","scenarios":entries})
	_write_json(DOSSIERS, {"schema_version":1,"package_id":"env06_7_bars_road","base_head":"855a296126e8b4747b78fbe89cb5a2d02daf61f5","scenario_count":entries.size(),"dossiers":dossiers,"uniqueness_rows":report.rows,"pair_count":report.comparison_count})
	print("ENV06_7_PACKAGE_C_AUTHOR_OK scenarios=%d pairs=%d" % [entries.size(), report.comparison_count])
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
		_interaction_add(prefix, "arrival", exit_id, "Marked clean exit", "Leave or refuse without crossing the active work zone.", [_action("ignore_%s" % prefix, "Ignore the sequence", "ui_down"), _action("refuse_%s" % prefix, "Refuse the task", "ui_cancel")], true),
		_interaction_add(prefix, "arrival", first_task_id, str(c.verbs[0]).replace("_", " ").capitalize(), "Begin the first physical task.", [_step_action(str(c.verbs[0]), prefix, str(c.verbs[0])), _action("fail_%s" % prefix, "Let the pressure win", "ui_right")], false),
	]
	cleanup.append(_remove("interaction_ops", prefix, exit_id))
	cleanup.append(_remove("interaction_ops", prefix, first_task_id))
	objective_steps.append({"id":str(c.verbs[0]),"label":str(c.verbs[0]).replace("_"," ").capitalize(),"kind":"command","command_id":str(c.verbs[0])})
	phases.append(_phase("arrival", "Arrival", str(c.arrival), "The marked clean exit remains available.", ["main_task"], scene_ops, arrival_interactions, actor_ops, [_transition(prefix,"arrival","stage","The room settles into its new working layout.")], [
		_branch(prefix,"arrival_begin",{"type":"command","command_id":str(c.verbs[0])},"work_1","",{"main_task":"success"}),
		_branch(prefix,"arrival_fail",{"type":"command","command_id":"fail_%s" % prefix},"terminal_failure","",{"main_task":"failure"}),
		_branch(prefix,"arrival_refuse",{"type":"command","command_id":"refuse_%s" % prefix},"terminal_refused","",{"main_task":"ignore"}),
		_branch(prefix,"arrival_interrupt",{"type":"fact","fact_type":"travel_departed"},"terminal_interrupted","",{"main_task":"cancel"}),
	]))
	for index in range(1, c.verbs.size()):
		var task_id := "%s_task_%d" % [prefix, index]
		var previous_task_id := "%s_task_%d" % [prefix, index - 1]
		var gate_id := "%s_gate_%d" % [prefix, index - 1]
		var operations := _beat_operations(c, index - 1)
		var interactions := [_gate(prefix,"work_%d" % index,gate_id,previous_task_id), _interaction_add(prefix,"work_%d" % index,task_id,str(c.verbs[index]).replace("_"," ").capitalize(),"Complete this distinct room operation before the aftermath can settle.",[_step_action(str(c.verbs[index]),prefix,str(c.verbs[index])),_action("fail_%s" % prefix,"Let the pressure win","ui_right")],false)]
		cleanup.append(_gate(prefix,"cleanup",gate_id,previous_task_id))
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
		phases.append(_phase("work_%d" % index,"Work beat %d" % index,"The room advances to a new physical station and actor arrangement.","The marked clean exit remains available.",["main_task"],operations.scene,interactions,operations.actor,[_transition(prefix,"work_%d" % index,str(["scene_change","feedback","stage"][index % 3]),"The next station, route, and actor cue become readable.")],branches))
	for terminal in [["success",c.outcomes[0]],["failure",c.outcomes[1]],["refused",c.outcomes[2]],["interrupted",c.outcomes[3]]]:
		phases.append(_phase("terminal_%s" % terminal[0],str(terminal[0]).capitalize(),"The active task gives way to a branch-specific room arrangement.","The marked exit remains readable through cleanup.",[],[],[],[],[_transition(prefix,"terminal_%s" % terminal[0],"feedback","The aftermath is fixed and will be restored on revisit.")],[{"id":"%s_terminal_%s" % [prefix,terminal[0]],"condition":{"type":"always"},"outcome":terminal[1]}],true))
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
		"declared_targets":{"scene_objects":[],"interactions":[],"actors":[],"services":[],"games":[],"routes":[],"anchors":[],"zones":[]},
		"mechanic_tags":c.tags,
		"sequence_signature":"pending",
		"owner_exceptions":[],
		"fact_subscriptions":[str(c.fact),"travel_departed"],
		"completion_contract":{"arrival_readable":true,"semantic_changes":true,"scenario_interaction":true,"action_boundaries":true,"choice_or_failure":true,"material_outcomes":true,"revisit_coverage":true,"world_connection":true,"primary_verb":true,"feedback_and_exit":true},
	}
	return {"scenario_id":c.id,"sequence":sequence,"authoring":{"arrival_summary":c.arrival,"player_verbs":c.verbs + ["refuse_%s" % prefix,"ignore_%s" % prefix],"world_connections":[str(c.fact),"travel_departed"],"references":{"objects":["base::travel:leave"]},"capture_ids":["%s_arrival" % prefix,"%s_partial" % prefix,"%s_success" % prefix,"%s_failure" % prefix,"%s_refused" % prefix,"%s_interrupted" % prefix,"%s_reduced_motion" % prefix,"%s_small_screen" % prefix,"%s_hit_overlay" % prefix],"seed_evidence":{"proof_seed":"%s_seed" % prefix,"save_boundaries":["arrival","partial","success","failure","refused","interrupted"],"minimum_target_size":44,"expected_outcomes":c.outcomes},"masked_visual_explanations":{}}}


func _phase(id:String,label:String,feedback:String,exit_prompt:String,objectives:Array,scene:Array,interactions:Array,actors:Array,transitions:Array,branches:Array,terminal:bool=false)->Dictionary:
	var result := {"id":id,"label":label,"arrival_feedback":feedback,"exit_prompt":exit_prompt,"entry_conditions":[],"objective_ids":objectives,"advance_after_actions":0,"scene_ops":scene,"interaction_ops":interactions,"actor_ops":actors,"transition_ops":transitions,"branches":branches}
	if terminal: result.terminal = true
	return result


func _branch(prefix:String,id:String,condition:Dictionary,next_phase:String,outcome:String,objective_outcomes:Dictionary={})->Dictionary:
	var result := {"id":"%s_%s" % [prefix,id],"condition":condition}
	if not next_phase.is_empty(): result.next_phase = next_phase
	else: result.outcome = outcome
	if not objective_outcomes.is_empty(): result.objective_outcomes = objective_outcomes
	return result


func _scene_spawn(prefix:String,boundary:String,id:String,label:String,role:String,zone:String,state:String,w:int,h:int)->Dictionary:
	return {"family":"scene_ops","op":"spawn","receipt_id":"%s_%s_spawn_%s" % [prefix,boundary,id],"owner_namespace":"scenario","stable_object_id":id,"object":{"label":label,"role":role,"zone_id":zone,"bounds":{"w":w,"h":h},"visible":true,"enabled":true,"state":state,"appearance":state}}


func _actor_spawn(prefix:String,boundary:String,id:String,label:String,actor_id:String,zone:String,behavior:String)->Dictionary:
	return {"family":"actor_ops","op":"spawn","receipt_id":"%s_%s_spawn_%s" % [prefix,boundary,id],"owner_namespace":"scenario","stable_object_id":id,"actor":{"label":label,"actor_id":actor_id,"zone_id":zone,"behavior":behavior,"pose":"arrival"}}


func _interaction_add(prefix:String,boundary:String,id:String,label:String,prompt:String,actions:Array,safe_exit:bool)->Dictionary:
	var inputs: Array = []
	for action in actions:
		if not inputs.has(action.input_action): inputs.append(action.input_action)
	return {"family":"interaction_ops","op":"add","receipt_id":"%s_%s_add_%s" % [prefix,boundary,id],"owner_namespace":"scenario","stable_object_id":id,"interaction":{"owner_namespace":"scenario","stable_object_id":id,"presentation_object_id":"scenario::%s" % id,"label":label,"state_label":"Available","prompt":prompt,"enabled":true,"disabled_reason":"","available_actions":actions,"input_actions":inputs,"non_color_state":"available","focus_order":1,"hit_bounds":{"w":64,"h":56},"min_target_size":44,"safe_exit":safe_exit,"alternate_exit":false}}


func _action(id:String,label:String,input:String)->Dictionary:
	return {"id":id,"label":label,"input_action":input,"non_color_state":"ready"}


func _step_action(id:String,prefix:String,step:String)->Dictionary:
	return {"id":id,"label":id.replace("_"," ").capitalize(),"input_action":"ui_accept","non_color_state":"work","handler":"complete_objective_step","inputs":{"objective_id":"main_task","step_id":step}}


func _gate(prefix:String,boundary:String,id:String,target:String)->Dictionary:
	return {"family":"interaction_ops","op":"gate","receipt_id":"%s_%s_gate_%s" % [prefix,boundary,id],"owner_namespace":"scenario","stable_object_id":id,"mode":"gate","target_owner_namespace":"scenario","target_stable_object_id":target,"enabled":false,"disabled_reason":"The sequence has advanced to the next physical station."}


func _remove(family:String,prefix:String,id:String)->Dictionary:
	return {"family":family,"op":"remove","receipt_id":"%s_cleanup_remove_%s" % [prefix,id],"owner_namespace":"scenario","stable_object_id":id}


func _despawn(prefix:String,id:String)->Dictionary:
	return {"family":"actor_ops","op":"despawn","receipt_id":"%s_cleanup_despawn_%s" % [prefix,id],"owner_namespace":"scenario","stable_object_id":id}


func _transition(prefix:String,boundary:String,kind:String,message:String)->Dictionary:
	var result := {"family":"transition_ops","op":kind,"receipt_id":"%s_%s_transition_%s" % [prefix,boundary,kind],"owner_namespace":"scenario","stable_object_id":"%s_%s_transition" % [prefix,boundary],"channel":"room"}
	if kind == "stage": result.merge({"message":message,"stage_id":"%s_%s_stage" % [prefix,boundary],"duration_boundaries":1,"reduced_motion_message":"The same room state appears without motion."})
	elif kind == "scene_change": result.merge({"message":message,"change_id":"%s_%s_change" % [prefix,boundary]})
	else: result.message = message
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
		result.append({"id":entry.scenario_id,"sequence":entry.sequence,"sequence_package_id":"env06_7_bars_road","sequence_handler_pack":"bars_road","sequence_renderer_id":"bars_road","sequence_authoring":entry.authoring})
	return result


func _dossier(c:Dictionary,entry:Dictionary)->Dictionary:
	return {"id":c.id,"archetype_id":c.archetype,"definition_path":OUTPUT,"phase_ids":entry.sequence.phase_graph.phases.map(func(p): return p.id),"terminal_outcomes":c.outcomes,"player_verbs":c.verbs,"changed_objects":c.objects.map(func(o): return o[0]),"changed_actors":c.actors.map(func(a): return a[0]),"world_connections":[c.fact,"travel_departed"],"reentry_policy":entry.sequence.reentry_policy,"sequence_signature":entry.sequence.sequence_signature,"capture_ids":entry.authoring.capture_ids,"exact_receipt_prefix":c.id}


func _write_json(path:String,value:Variant)->void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"  ",false)+"\n")
	file.close()
