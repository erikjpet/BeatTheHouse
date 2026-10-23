extends SceneTree

const Check := preload("res://scripts/tests/rourke_phased_resolution_check.gd")
const WebSaveCheck := preload("res://scripts/tests/rourke_terminal_web_save_check.gd")
const Driver := preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")
const Store := preload("res://scripts/core/durable_store.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
var failures: Array[String] = []

class TerminalMain extends Check.ObservedMain:
	func _terminal_checkpoint_uses_web_phases() -> bool:
		return true

func _initialize() -> void:
	call_deferred("_run")

func _open(slot: String, fixture: bool = true) -> TerminalMain:
	var app := TerminalMain.new()
	app.autosave_slot_id = "rourke_interrupt_" + slot
	root.add_child(app)
	app.continuous_environment_clock_enabled = false
	app.save_service = WebSaveCheck.PhasedSave.new()
	app._ensure_run_ui_built()
	if fixture:
		var path: String = app.save_service.run_save_path(app.autosave_slot_id)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(Check.FIXTURE))
		file.close()
	_check(app.load_foundation_run(), slot + ": production load")
	if app.current_game == null: _check(app.activate_interactable_object("game:blackjack"), slot + ": table enters")
	return app

func _driver_hand(app: TerminalMain, run: RunState, now: int) -> void:
	Driver.surface_intent(app.current_game, "blackjack_deal", 20, run, run.current_environment, 0, false, now)
	var command := Driver.surface_intent(app.current_game, "blackjack_stand", 20, run, run.current_environment, 0, false, now + 5000)
	var host := Driver._new_production_host()
	host.current_game = app.current_game
	host.game_module_cache = {"blackjack": app.current_game}
	host.run_state = run
	host.current_game_state_key = "blackjack"
	host.selected_stake = 20
	var delivery: Dictionary = command.get("_sealed_action_host_delivery", {})
	var result: Dictionary = host._sealed_action_host_resolve_intent(str(command.get("action_id", "")), 20, delivery, command.get("_sealed_action_host_prepared", {}))
	_check(bool(result.get("ok", false)), "native setup uses accepted production sealed hand")
	host.free()

func _queue(app: TerminalMain) -> void:
	app._on_game_surface_action("blackjack_deal", 0)
	app.input_clock += 5000
	app._on_game_surface_action("blackjack_stand", 0)
	_check(not app._rourke_resolution.is_empty(), "completed-hand command is queued")

func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():
		quit(2)
		return
	var app := _open("terminal")
	for hand in range(4): _driver_hand(app, app.run_state, (hand + 1) * 100000)
	var reference := app.run_state.detached_host_action_candidate("blackjack")
	_driver_hand(app, reference, 500000)
	_queue(app)
	_check(not app.run_state.is_terminal(), "pending terminal proposal is not presented as a final commit")
	for step in range(5): app._advance_rourke_resolution(false)
	_check(app.run_state.is_terminal() and app.current_screen == app.SCREEN_GAME, "terminal authority commits before report presentation")
	_check(app.run_state.rng_state == reference.rng_state and app.run_state.bankroll == reference.bankroll and app.run_state.grand_casino_duel_status() == reference.grand_casino_duel_status(), "terminal money, RNG and complete duel match synchronous resolution")
	app._advance_rourke_resolution(false)
	_check(app.current_screen == app.SCREEN_FAILURE and app.run_report_model.is_empty() and bool(app._rourke_resolution.get("terminal_presentation_pending", false)), "profile/result processing yields before terminal report construction")
	var rng: int = app.run_state.rng_state
	var service: SaveService = app.save_service
	var slot: String = app.autosave_slot_id
	_check(app.return_to_main_menu(), "Main Menu drains committed result/report and durable terminal save")
	var restored: RunState = service.load_run(slot)
	_check(restored != null and restored.is_terminal() and restored.rng_state == rng and restored.terminal_score() == 382, "terminal cold Continue retains ending, score and RNG")
	_check(app.actual_resolutions == 1 and app._rourke_resolution.is_empty(), "terminal navigation never repeats settlement")
	app.free()
	await process_frame
	app = _open("failed_save")
	_queue(app)
	Store.debug_force_write_failure = true
	var left := app.return_to_main_menu()
	Store.debug_force_write_failure = false
	_check(not left and app.run_state != null and app.run_state.grand_casino_duel_status().get("player_stack") == 112, "failed navigation save retains the once-settled open run")
	_check(app.actual_resolutions == 1 and app._rourke_resolution.is_empty(), "failed Save does not retain a replayable prepared action")
	_check(app.return_to_main_menu() and app.actual_resolutions == 1, "retry writes the same settlement without repeating money/RNG")
	app.free()
	await process_frame
	app = _open("pending_restore")
	app._on_game_surface_action("blackjack_deal", 0)
	var cards := Runtime.canonical_json(app.run_state.grand_casino_duel_session_readonly())
	rng = app.run_state.rng_state
	app.input_clock += 5000
	app._on_game_surface_action("blackjack_stand", 0)
	_check(app.save_service.save_run(app.run_state, app.autosave_slot_id) == OK, "interruption fixture persists a genuine published pending delivery")
	var retained: RunState = app.run_state
	app.free()
	_check(retained.rng_state == rng and Runtime.canonical_json(retained.grand_casino_duel_session_readonly()) == cards, "scene teardown cancels an uncommitted action without losing dealt cards")
	await process_frame
	app = _open("pending_restore", false)
	app._advance_game_surface_automation()
	_check(app.run_state.rng_state == rng and Runtime.canonical_json(app.run_state.grand_casino_duel_session_readonly()) == cards, "normal auto recovery restores both saved pending session copies")
	app.input_clock += 5000
	app._on_game_surface_action("blackjack_stand", 0)
	app._drain_rourke_resolution()
	_check(app.run_state.grand_casino_duel_status().get("player_stack") == 112 and app.actual_resolutions == 1, "recovered hand settles once through normal input")
	app.free()
	await process_frame
	for message in failures: push_error(message)
	print("ROURKE_PHASED_INTERRUPTION_CHECK ", JSON.stringify({"failures": failures, "cases": ["terminal parity", "delayed report", "terminal Main Menu and cold Continue", "failed Save and retry", "scene teardown", "pending save auto recovery"]}))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
