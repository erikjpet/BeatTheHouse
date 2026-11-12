extends SceneTree

# Faithful native Host path: fresh ordinary seed, offered Parking Tip,
# admitted paid map travel, offered Side Door response and projected controls.
# The rejection case alone substitutes a RunState subclass after a genuine
# Casino arrival. No captured save, scenario pin or rendered Web claim.
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")

class RejectArrivalRun extends RunState:
	var rejected_arrivals := 0
	func scenario_flush_facts(boundary_serial: int = -1) -> Dictionary:
		for value in current_environment.get("scenario_sequence_state", {}).get("fact_queue", []):
			if str(value.get("fact_type", "")) == "travel_arrived":
				rejected_arrivals += 1
				return {"ok": false, "errors": ["Synthetic layer arrival flush rejection."]}
		return super.scenario_flush_facts(boundary_serial)

const Host:=preload("res://scripts/ui/foundation_main.gd")
const Binder:=preload("res://scripts/core/environment_slot_binder.gd")
var app:Node
var checks:=0
var failures:Array=[]
func _initialize()->void:call_deferred("_run")
func check(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);print("CHECK_FAILED ",label)
	return ok
func frames(n:int=5)->void:
	for i in range(n):await process_frame
func public_command(id:String)->bool:
	for value in app._interactable_object_view_list():
		for action in value.get("scenario_sequence_actions",[]):
			if str(action.get("id",""))==id:return app._activate_scenario_sequence_action(value,action)
	return false
func authority(room:Dictionary)->Dictionary:
	var bindings:Dictionary=room.get("layout",{}).get("slot_bindings",{})
	var has_leave:=false
	for key in bindings:
		if str(key).contains("travel:leave"):has_leave=true
	var proof:=Binder.validate_base_layout_authority(room)
	return {"layer":str(room.get("current_layer_id","")),"has_leave_binding":has_leave,"binding_count":bindings.size(),"authority_ok":bool(proof.get("ok",false)),"authority_error_count":proof.get("errors",[]).size()}
func pending_arrivals()->int:
	var count:=0
	for fact in app.run_state.current_environment.get("scenario_sequence_state",{}).get("fact_queue",[]):
		if str(fact.get("fact_type",""))=="travel_arrived":count+=1
	return count
func phase()->String:
	return str(app.run_state.current_environment.get("scenario_sequence_state",{}).get("phase_id",""))
func stage(label:String)->void:
	var state:Dictionary=app.run_state.current_environment.get("scenario_sequence_state",{})
	var arrivals:=0
	for fact in state.get("fact_queue",[]):
		if str(fact.get("fact_type",""))=="travel_arrived":arrivals+=1
	print("PUBLIC_LAYER_STAGE ",JSON.stringify({"stage":label,"authority":authority(app.run_state.current_environment),"public_phase":str(state.get("phase_id","")),"status":str(state.get("status","")),"pending_arrival_count":arrivals,"wallet":app.run_state.bankroll}))
func _run()->void:
	root.size=Vector2i(1280,720)
	app=Host.new();root.add_child(app);await frames()
	for mode in ["arrival","work_1"]:
		if not check(app.start_foundation_run("UF061-BRINGER-8"),mode+" fresh normal run"):break
		await frames()
		if not check(app.activate_event_choice_action("parking_lot_tip","follow_tip"),mode+" real available Parking Tip"):break
		await frames()
		if not check(app.select_travel_option("small_underground_casino") and app.confirm_selected_travel(true),mode+" visible admitted source trip"):break
		await wait_for_travel_arrival(mode)
		check(str(app.run_state.current_environment.get("scenario_id",""))=="punchline_bringer_show",mode+" actual Bringer Show")
		stage(mode+" initial")
		if mode=="work_1":
			if not check(public_command("open_first_crowd_rope"),"real projected Open First Crowd Rope"):break
			await frames()
			stage("work_1 after first rope")
		if not check(app.activate_event_choice_action("side_door","punchline_password"),mode+" offered Try the word"):break
		await frames()
		stage(mode+" after word")
		# The offered Try the word response itself enters Casino. Do not
		# activate a redundant same-layer door after that real transition.
		if not check(str(app.run_state.current_environment.get("current_layer_id",""))=="casino",mode+" Try the word enters Casino"):break
		stage(mode+" Casino")
		if mode == "arrival":
			check_rejected_return()
		var cached:Dictionary=app.run_state.current_environment.get("layer_states",{}).get("club",{})
		print("PUBLIC_CACHED_CLUB ",mode," ",JSON.stringify(authority(cached)))
		check(not cached.is_empty() and bool(authority(cached).get("authority_ok",false)) and bool(authority(cached).get("has_leave_binding",false)),mode+" cached Club retains valid base exit")
		if not check(app.activate_interactable_object("environment_layer:club"),mode+" normal Club return"):break
		await frames()
		stage(mode+" returned Club")
		check(pending_arrivals()==0,mode+" admitted layer arrival consumed before returning control")
		if mode=="arrival":
			check(public_command("open_first_crowd_rope"),"begin task after the completed layer return")
			await frames()
			stage("arrival after first rope")
			check(app.activate_interactable_object("service:punchline_two_drink_minimum"),"ordinary public two-drink action")
			await frames()
			stage("arrival after ordinary room action")
			check(phase()=="work_1","past layer arrival must not fail a task accepted afterward")
			await check_completion_boundaries()
		else:
			check(phase()=="terminal_failure","genuine return during work1 preserves immediate authored arrival pressure")
		check(bool(authority(app.run_state.current_environment).get("authority_ok",false)) and bool(authority(app.run_state.current_environment).get("has_leave_binding",false)),mode+" returned Club authority/exit")
		var rows:Array=[]
		for value in app._interactable_object_view_list():
			var actions:Array=[]
			for action in value.get("scenario_sequence_actions",[]):actions.append({"id":str(action.get("id","")),"label":str(action.get("label",""))})
			if not actions.is_empty():rows.append({"object_id":str(value.get("object_id","")),"label":str(value.get("label","")),"actions":actions})
		print("PUBLIC_RETURNED_COMMANDS ",mode," ",JSON.stringify(rows))
	await check_abort_boundary()
	app.queue_free();await frames()
	print("BRINGER_LAYER_ARRIVAL_ORDER checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func protected_state() -> String:
	var run: RunState = app.run_state
	return Runtime.content_fingerprint({
		"cash": run.bankroll, "chips": run.grand_casino_chips,
		"inventory": run.inventory, "rng": run.rng_state,
	})

func receipt_count() -> int:
	return app.run_state.current_environment.get("scenario_sequence_state", {}).get("command_receipts", []).size()

func save_continue(label: String) -> void:
	var before := protected_state()
	var previous_phase := phase()
	var receipts := receipt_count()
	app.save_foundation_run()
	await frames()
	check(app.load_foundation_run(), label + " normal Host Continue")
	await frames()
	check(protected_state() == before, label + " Continue preserves money inventory and RNG")
	check(phase() == previous_phase and receipt_count() == receipts and pending_arrivals() == 0,
		label + " Continue preserves phase and receipts without replay")

func check_completion_boundaries() -> void:
	await save_continue("partial")
	var before := protected_state()
	for command in ["usher_supporters_to_block", "count_minimum_seats", "close_hostile_pitch"]:
		check(public_command(command), "projected completion " + command)
		await frames()
	check(phase() == "terminal_success", "real projected route reaches authored show_seated")
	check(protected_state() == before, "nonfinancial success invents no money inventory or RNG reward")
	var receipts := receipt_count()
	check(not public_command("close_hostile_pitch"), "completed command unavailable for duplicate settlement")
	check(receipt_count() == receipts and protected_state() == before, "duplicate attempt changes no receipt or account")
	await save_continue("success")
	check(app.activate_interactable_object("environment_layer:casino"), "completed normal departure")
	await frames()
	check(app.activate_interactable_object("environment_layer:club"), "completed normal revisit")
	await frames()
	check(phase() == "terminal_success" and pending_arrivals() == 0, "revisit retains terminal success without queued pressure")
	check(protected_state() == before and receipt_count() == receipts, "travel revisit grants no repeat reward")

func check_rejected_return() -> void:
	# Supplemental synthetic fault injection; genuine source room and cached
	# destination are authenticated before the injected arrival rejection.
	var source := RejectArrivalRun.new()
	source.from_dict(app.run_state.to_dict())
	check(bool(source.scenario_finalize_installed_environment(app.library).get("ok", false)),
		"rejection fixture finalizes ordinary restored Casino")
	check(bool(source.publish_room_presentation().get("ok", false)), "rejection fixture publishes authenticated Casino")
	var before := Runtime.content_fingerprint(source.to_dict())
	var result: Dictionary = app.generator.enter_environment_layer(source, "club", true)
	check(not bool(result.get("ok", true)) and result.get("errors", []).has("Synthetic layer arrival flush rejection."),
		"layer transaction exposes injected arrival rejection")
	check(source.rejected_arrivals == 1, "fault injected only after genuine installed Club arrival")
	check(Runtime.content_fingerprint(source.to_dict()) == before,
		"rejected layer return restores full durable room map money clock and RNG")
	check(bool(authority(source.current_environment).get("authority_ok", false)),
		"rejected return preserves authenticated source authority")

func check_abort_boundary() -> void:
	check(app.start_foundation_run("UF061-BRINGER-8"), "abort fresh normal run")
	await frames()
	check(app.activate_event_choice_action("parking_lot_tip", "follow_tip"), "abort real offered tip")
	await frames()
	check(app.select_travel_option("small_underground_casino") and app.confirm_selected_travel(true), "abort admitted route")
	await wait_for_travel_arrival("abort")
	var before := protected_state()
	check(public_command("refuse_punchline_bringer_show"), "normal offered refusal")
	await frames()
	check(phase() == "terminal_refused" and protected_state() == before, "abort grants no reward")
	await save_continue("refusal")
	check(not public_command("open_first_crowd_rope") and protected_state() == before, "aborted route cannot grant late reward")


func wait_for_travel_arrival(label: String) -> void:
	# Menu travel now finishes its cinematic before room input becomes available.
	# Observe ordinary time; do not skip, alter the timeline or acknowledge it here.
	var deadline := Time.get_ticks_msec() + 15000
	while app.travel_presentation_active and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not app.travel_presentation_active, label + " menu journey automatically returns room input")
	await frames()
