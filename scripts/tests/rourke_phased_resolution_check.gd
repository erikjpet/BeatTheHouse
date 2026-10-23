extends SceneTree

const Main := preload("res://scripts/ui/foundation_main.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const Driver := preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")
const FIXTURE := "res://scripts/tests/fixtures/integ06_1/v0_5_1/v051_grand_casino_back_room_duel.json"
var failures: Array[String] = []

class ObservedMain extends Main:
	var phased := true
	var input_clock := 100000
	var phase_frames: Array = []
	var actual_resolutions := 0
	var completed_snapshot: Dictionary = {}
	var auto_clock := false
	var background_calls := 0

	func _rourke_resolution_uses_frames(command: Dictionary) -> bool:
		# Native emulation of the production Web predicate, retaining real UI/host.
		return phased and bool(command.get("direct_resolve", false)) and command.has("_sealed_action_host_prepared")

	func _current_game_surface_input_time_msec() -> int:
		return input_clock

	func _environment_simulation_time_msec() -> int:
		return input_clock if auto_clock else super._environment_simulation_time_msec()

	func _advance_environment_game_runtime() -> void:
		if auto_clock: background_calls += 1
		super._advance_environment_game_runtime()

	func _advance_rourke_resolution(schedule_next: bool = true, generation: int = -1) -> void:
		var before := int(_rourke_resolution.get("step", -1))
		var presentation: float = float(game_surface_canvas.get("surface_presentation_clock_msec")) if game_surface_canvas != null else -1.0
		super._advance_rourke_resolution(schedule_next, generation)
		if before >= 0 and int(_rourke_resolution.get("step", -1)) != before:
			phase_frames.append({"step": before, "frame": Engine.get_process_frames(), "presentation_before": presentation})
			if before == 3: completed_snapshot = run_state.to_save_snapshot().duplicate(true)

	func _sealed_action_host_resolve_intent(action_id: String, stake: int, delivery: Dictionary = {}, prepared: Dictionary = {}) -> Dictionary:
		if not (_rourke_resolution_dispatch_active and int(_rourke_resolution.get("step", -1)) == 1):
			actual_resolutions += 1
		return super._sealed_action_host_resolve_intent(action_id, stake, delivery, prepared)

func _initialize() -> void:
	call_deferred("_run")

func _open(slot: String, phased: bool = true) -> ObservedMain:
	var app := ObservedMain.new()
	app.phased = phased
	app.autosave_slot_id = "rourke_phase_" + slot
	root.add_child(app)
	app.continuous_environment_clock_enabled = false
	app._ensure_run_ui_built()
	var path: String = app.save_service.run_save_path(app.autosave_slot_id)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(FIXTURE))
	file.close()
	_check(app.load_foundation_run(), slot + ": fixture loads")
	if app.current_game == null: _check(app.activate_interactable_object("game:blackjack"), slot + ": table enters")
	return app

func _deal(app: ObservedMain) -> void:
	app._on_game_surface_action("blackjack_deal", 0)
	app.input_clock += 5000

func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():
		quit(2)
		return
	var app := _open("sync", false)
	_deal(app)
	app._on_game_surface_action("blackjack_stand", 0)
	var expected := _public(app.run_state)
	app.free()
	await process_frame
	app = _open("scheduled")
	_deal(app)
	var before := _public(app.run_state)
	app._on_game_surface_action("blackjack_stand", 0)
	_check(not app._rourke_resolution.is_empty() and app.actual_resolutions == 0, "input only prepares a recoverable delivery")
	var pending := _public(app.run_state)
	app._on_game_surface_action("blackjack_deal", 0)
	_check(_public(app.run_state) == pending, "repeated input cannot mutate the pending action")
	for frame in range(7): await process_frame
	_check(app._rourke_resolution.is_empty(), "finite scheduled transaction finishes")
	_check(_public_data(app.completed_snapshot) == expected, "all public state, money and RNG match at the completed action boundary")
	if _public_data(app.completed_snapshot) != expected: _diff(JSON.parse_string(expected), JSON.parse_string(_public_data(app.completed_snapshot)))
	_check(app.actual_resolutions == 1, "post-action presentation reuses the committed result exactly once")
	_check(app.phase_frames.size() == 4, "all scheduled phases execute once")
	if app.phase_frames.size() >= 2:
		_check(app.phase_frames[1].presentation_before > app.phase_frames[0].presentation_before, "presentation animation advances while host simulation/input wait")
	for i in range(1, app.phase_frames.size()):
		_check(app.phase_frames[i].frame > app.phase_frames[i-1].frame, "scheduled phases have separate real engine frames")
	print("ROURKE_PHASE_FRAMES ", JSON.stringify(app.phase_frames))
	app.free()
	await process_frame
	app = _open("cancel")
	_deal(app)
	before = _public(app.run_state)
	app._on_game_surface_action("blackjack_stand", 0)
	var stale_generation: int = app._rourke_resolution_generation
	_check(app._cancel_rourke_resolution(), "cancellation before commit uses pending-delivery rollback")
	_check(_public(app.run_state) == before and app.actual_resolutions == 0, "cancel preserves cards, balances and RNG")
	if _public(app.run_state) != before: _diff(JSON.parse_string(before), JSON.parse_string(_public(app.run_state)))
	app._advance_rourke_resolution(false, stale_generation)
	_check(_public(app.run_state) == before, "late callback cannot settle a cancelled hand")
	var prior_rng: int = app.run_state.rng_state
	var prior_stack: int = int(app.run_state.grand_casino_duel_status().get("player_stack"))
	app._on_game_surface_action("blackjack_stand", 0)
	app._advance_rourke_resolution(false, stale_generation)
	_check(int(app._rourke_resolution.get("step", -1)) == 0, "old generation cannot advance the replacement hand")
	app.run_state.narrative_flags["phase_stale_probe"] = true
	app._advance_rourke_resolution(false)
	_check(str(app._rourke_resolution.get("result", {}).get("error_code")) == "stale_boundary", "authority is rechecked after the asynchronous boundary")
	app._drain_rourke_resolution()
	_check(app.actual_resolutions == 0 and app.run_state.rng_state == prior_rng and int(app.run_state.grand_casino_duel_status().get("player_stack")) == prior_stack, "stale rejection cannot execute or account the isolated proposal")
	app.free()
	await process_frame
	app = _open("automatic")
	app.auto_clock = true
	app._on_game_surface_action("blackjack_deal", 0)
	app._on_game_surface_action("blackjack_stand", 0)
	_check(app._rourke_resolution.is_empty(), "card animation owns an early Stand before automatic settlement")
	app.input_clock += 5000
	app._process(0.0)
	_check(not app._rourke_resolution.is_empty() and app.background_calls == 0, "automatic settlement locks remaining host work in its preparation frame")
	app._drain_rourke_resolution()
	_check(app.actual_resolutions == 1 and app.run_state.grand_casino_duel_status().get("player_stack") == 112, "automatic prepared delivery settles exactly once")
	app.free()
	await process_frame
	for boundary in range(2):
		app = _open("menu_%d" % boundary)
		_deal(app)
		app._on_game_surface_action("blackjack_stand", 0)
		if boundary == 1: app._advance_rourke_resolution(false)
		var service: SaveService = app.save_service
		var slot: String = app.autosave_slot_id
		_check(app.return_to_main_menu(), "Main Menu drains pending boundary %d" % boundary)
		_check(app._rourke_resolution.is_empty() and app.actual_resolutions == 1, "navigation settles exactly once")
		var restored: RunState = service.load_run(slot)
		_check(restored != null and restored.grand_casino_duel_status().get("player_stack") == 112 and restored.grand_casino_duel_status().get("rourke_stack") == 95, "cold Continue retains settled stacks")
		app.free()
		await process_frame
	for message in failures: push_error(message)
	print("ROURKE_PHASED_RESOLUTION_CHECK ", JSON.stringify({"failures": failures, "cases": ["synchronous parity", "separate scheduled frames", "input lock", "cancel", "late callback", "pre/post commit Main Menu and cold Continue"]}))
	quit(0 if failures.is_empty() else 1)

static func _public(run: RunState) -> String:
	return _public_data(run.to_save_snapshot())

static func _public_data(snapshot: Dictionary) -> String:
	var data := snapshot.duplicate(true)
	data.erase("music_tempo_state")
	data.erase("music_choreography_state")
	var crew: Dictionary = data.get("crew_state", {})
	crew.erase("a")
	crew.erase("z")
	_strip(data)
	return Runtime.canonical_json(data)

static func _strip(value: Variant) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for key in [Authority.LEDGER_KEY, Authority.PENDING_APPLY_RECEIPT_KEY, "environment_runtime_revision"]: value.erase(key)
		for key in value: _strip(value[key])
	elif typeof(value) == TYPE_ARRAY:
		for child in value: _strip(child)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _diff(a: Variant, b: Variant, path: String = "", count: Array = [0]) -> void:
	if count[0] >= 16: return
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		for key in a:
			if b.has(key): _diff(a[key], b[key], path + "." + str(key), count)
			else: print("PHASE_DIFF missing ",path,".",key); count[0] += 1
		for key in b:
			if not a.has(key): print("PHASE_DIFF added ",path,".",key); count[0] += 1
	elif typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if a.size() != b.size(): print("PHASE_DIFF size ",path," ",a.size()," -> ",b.size()); count[0] += 1
		for i in mini(a.size(), b.size()): _diff(a[i], b[i], path + "." + str(i), count)
	elif a != b:
		print("PHASE_DIFF ",path," ",str(a).left(90)," -> ",str(b).left(90)); count[0] += 1
