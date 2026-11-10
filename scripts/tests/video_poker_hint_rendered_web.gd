extends Node

# Test-only synthetic pre-Deal fixture. Player actions after setup arrive only
# through real pointer events on the rendered production FoundationMain canvas.
const MainScene := preload("res://scenes/main.tscn")
var app: Control
var canvas: Control
var observed: Array = []
var last_phase := ""
var first_input_usec := 0
var first_hold_usec := 0
var first_hold_hint_samples := -1
var pending_frames := 0
var setup_done := false

func _ready() -> void:
	call_deferred("_setup")

func _setup() -> void:
	print("VP_HOST_SETUP: instantiate")
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "vp_hint_rendered_check")
	add_child(app)
	print("VP_HOST_SETUP: scene added")
	for _frame in range(6): await get_tree().process_frame
	if not app.call("start_foundation_run", "VP-HINT-RENDERED-20261110"):
		push_error("Could not create the rendered hint fixture.")
		return
	for _frame in range(6): await get_tree().process_frame
	print("VP_HOST_SETUP: run started")
	var run: RunState = app.get("run_state")
	run.bankroll = 10000
	run.add_item("freds_poker_hat")
	var library: ContentLibrary = app.get("library")
	var rng := run.create_rng("vp_hint_rendered_environment")
	var instance := EnvironmentInstance.from_archetype(library.environment_archetype("delta_queen"), 1, rng, library, run.challenge_config)
	var environment := instance.to_dict()
	environment["world_node_id"] = "delta_queen"
	environment["game_ids"] = ["video_poker"]
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 200}
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	var game: GameModule = app.call("_game_module_for_id", "video_poker")
	environment["game_states"] = {"video_poker": game.generate_environment_state(run, environment, run.create_rng("vp_hint_rendered_machine"))}
	run.set_environment(environment)
	app.call("_clear_selected_game_action")
	app.call("clear_interaction_focus")
	app.call("_refresh")
	print("VP_HOST_SETUP: synthetic pre-Deal room ready")
	for _frame in range(6): await get_tree().process_frame
	if not app.call("enter_game", "video_poker", "video_poker"):
		push_error("Could not enter the rendered hint cabinet.")
		return
	for _frame in range(8): await get_tree().process_frame
	print("VP_HOST_SETUP: cabinet entered")
	canvas = app.get("game_surface_canvas")
	setup_done = true
	RenderingServer.frame_post_draw.connect(_observe)
	_observe()
	print("VP_HOST_SETUP: ready for pointer Deal")

func _input(event: InputEvent) -> void:
	if setup_done and event is InputEventMouseButton and event.pressed:
		if first_input_usec == 0: first_input_usec = Time.get_ticks_usec()

func _observe() -> void:
	if not setup_done or not is_instance_valid(canvas): return
	var state: Dictionary = canvas.call("realtime_surface_state")
	var game: GameModule = app.get("current_game")
	var job: Dictionary = game.get("_strategy_hint_job") if game != null else {}
	var phase := str(state.get("phase", ""))
	var pending := bool(state.get("strategy_hint_pending", false))
	if phase == "hold" and first_hold_usec == 0:
		first_hold_usec = Time.get_ticks_usec()
		first_hold_hint_samples = int(job.get("completed_samples", 0))
	if pending: pending_frames += 1
	if phase != last_phase:
		observed.append({"phase": phase, "pending": pending})
		last_phase = phase
	var targets := {}
	for action in ["video_poker_deal", "video_poker_draw", "video_poker_hold"]:
		var local: Vector2 = canvas.call("_local_position_for_hit_region", action, 0 if action == "video_poker_hold" else -1)
		if local.x >= 0:
			var point: Vector2 = canvas.get_global_transform_with_canvas() * local
			targets[action] = {"x": point.x, "y": point.y}
	var snapshot := {"ready": true, "phase": phase, "pending": pending, "pending_rendered_frames": pending_frames,
		"recommended_holds": state.get("recommended_holds", []), "text": state.get("recommended_hold_text", ""),
		"holds": state.get("holds", []), "targets": targets, "observed_phases": observed,
		"first_deal_to_rendered_hold_usec": maxi(0, first_hold_usec - first_input_usec) if first_input_usec > 0 and first_hold_usec > 0 else 0,
		"first_hold_hint_samples": first_hold_hint_samples,
		"transition_animation_active": bool(canvas.call("surface_transition_animation_active")),
		"hint_max_slice_usec": int(game.get("_strategy_hint_max_slice_usec")) if game != null else 0,
		"job_samples": int(job.get("completed_samples", 0)), "job_active": not job.is_empty(),
		"cabinet_id": state.get("cabinet_id", ""), "hand": state.get("hand", []),
		"bankroll": int((app.get("run_state") as RunState).bankroll)}
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__bth_vp_host_snapshot = JSON.parse(%s);" % JSON.stringify(JSON.stringify(snapshot)), true)
