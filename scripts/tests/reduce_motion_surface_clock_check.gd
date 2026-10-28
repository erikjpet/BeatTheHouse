extends SceneTree

const Canvas := preload("res://scripts/ui/game_surface_canvas.gd")
const Blackjack := preload("res://scripts/games/blackjack.gd")
var checks := 0
var failures: Array[String] = []
var samples: Array = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var canvas := Canvas.new()
	canvas.size = Vector2(900,430)
	root.add_child(canvas)
	await process_frame
	canvas.set_game_module(Blackjack.new())
	for reduced in [false,true]:
		canvas.render_game_snapshot({"game_id":"clock_probe","surface_renderer":"blackjack","surface_renderer_opaque":true,"surface_animates_idle":true,"surface_native_low_detail_idle":true,"surface_native_idle_animation_fps":15.0,"phase":"betting","between_hands":true,"dealer_name":"Clock probe","dealer_profile":{"blink_offset":0},"patrons":[],"reduce_motion":reduced,"surface_time_msec":1000,"surface_presentation_time_msec":2000})
		canvas.set_process(false) # Explicit deterministic native delta fixture.
		canvas.set_modal_activity_paused(false)
		canvas.reset_performance_counters()
		var state_before := canvas.state.duplicate(true)
		canvas._process(2.5)
		check(canvas.surface_simulation_time_msec() == 3500,"input/simulation clock advances once through2.5s idle, reduced=%s" % reduced)
		check(canvas.surface_presentation_time_msec() == (2000 if reduced else 4500),"presentation time preserves visual Reduce Motion intent")
		check(canvas.surface_render_elapsed_sec == (0.0 if reduced else 2.5),"visual elapsed time remains frozen only when reduced")
		check(canvas.surface_animation_redraw_count == 0 if reduced else canvas.surface_animation_redraw_count > 0,"reduced visuals stay still; ordinary autonomous redraw scheduling continues")
		canvas._process(0.5)
		check(canvas.surface_simulation_time_msec() == 4000,"second tick does not double count")
		canvas._process(-1.0)
		check(canvas.surface_simulation_time_msec() == 4000,"negative delta cannot rewind simulation time")
		canvas.set_environment_activity_paused(true,false)
		var before_pause := canvas.debug_pause_contract_snapshot()
		canvas._process(2.0)
		check(canvas.surface_simulation_time_msec() == before_pause.surface_simulation_time_msec,"environment/tutorial pause freezes input clock")
		check(canvas.surface_presentation_time_msec() == int(before_pause.surface_presentation_time_msec) + (0 if reduced else 2000),"existing presentation-only pause behavior retained")
		canvas.set_modal_activity_paused(true)
		before_pause = canvas.debug_pause_contract_snapshot()
		canvas._process(3.0)
		check(canvas.surface_simulation_time_msec() == before_pause.surface_simulation_time_msec and canvas.surface_presentation_time_msec() == before_pause.surface_presentation_time_msec,"modal/timed-feedback pause freezes both clocks")
		canvas.handle_application_lifecycle(false)
		canvas._process(1.0)
		check(canvas.reject_orphan_surface_events and canvas.surface_simulation_time_msec() == before_pause.surface_simulation_time_msec,"application lifecycle preserves owner pause and cancels stale input")
		canvas.handle_application_lifecycle(true)
		canvas.set_modal_activity_paused(false)
		canvas._process(0.1)
		check(canvas.surface_simulation_time_msec() == int(before_pause.surface_simulation_time_msec)+100,"resume counts current delta without paused-time jump")
		canvas.hide()
		var hidden_time := canvas.surface_simulation_time_msec()
		canvas._process(2.0)
		check(canvas.surface_simulation_time_msec() == hidden_time,"hidden surface retains existing clock freeze")
		canvas.show()
		canvas.set_process(false)
		canvas._process(0.2)
		check(canvas.surface_simulation_time_msec() == hidden_time+200,"visible resume does not catch up hidden time")
		var transition_time := canvas.surface_simulation_time_msec()
		var transition_presentation := canvas.surface_presentation_time_msec()
		canvas.reduce_motion = not reduced
		canvas._process(0.25)
		check(canvas.surface_simulation_time_msec() == transition_time+250,"ON/OFF transition advances input once without reset")
		check(canvas.surface_presentation_time_msec() == transition_presentation + (250 if reduced else 0),"ON/OFF transition keeps visual clock contract")
		check(canvas.state == state_before,"clock ticks do not mutate game snapshot/cards/wallet/authority inputs")
		samples.append({"initial_reduce_motion":reduced,"final":canvas.debug_pause_contract_snapshot(),"redraw_count":canvas.surface_animation_redraw_count})
	canvas.queue_free()
	await process_frame
	var report := {"checks":checks,"failures":failures,"samples":samples,"fidelity":"Deterministic native canvas delta/pause contract. No game outcome, RNG or trusted pointer claim; normal-player Web timing remains separate."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	print("REDUCE_MOTION_CLOCK checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
