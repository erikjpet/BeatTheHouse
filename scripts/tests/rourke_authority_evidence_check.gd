extends SceneTree

const Blackjack := preload("res://scripts/games/blackjack.gd")
const Driver := preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
const FIXTURE := "res://scripts/tests/fixtures/integ06_1/v0_5_1/v051_grand_casino_back_room_duel.json"
var failures: Array[String] = []
var last_hand_elapsed_usec := 0

class AuditedGame extends Blackjack:
	var world_mutations := 0
	var resolution_calls := 0
	var corrupt_replay := false
	var corrupt_reputation_replay := false

	func _blackjack_resolve_candidate(action_id: String, stake: int, candidate: RunState, rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
		var world := candidate.world_map.duplicate(true)
		var rooms := _readonly_room_storage(candidate)
		var town := _readonly_town_storage(candidate)
		var result := super._blackjack_resolve_candidate(action_id, stake, candidate, rng, ui_state)
		resolution_calls += 1
		if corrupt_replay and resolution_calls % 2 == 0:
			candidate.narrative_flags["rourke_replay_probe_mismatch"] = true
		if corrupt_reputation_replay and resolution_calls % 2 == 0:
			candidate.town_state.living_world.reputation_sequence += 1
		var room_storage := _readonly_room_storage(candidate)
		var stored_room: Dictionary = candidate.grand_casino_room_states.get(str(candidate.current_environment.get("archetype_id", "")), {})
		var mirrored_table: Dictionary = stored_room.get("game_states", {}).get("blackjack", {})
		var current_table: Dictionary = candidate.current_environment.get("game_states", {}).get("blackjack", {})
		if not world.recursive_equal(candidate.world_map, 0) or not rooms.recursive_equal(room_storage, 0) or not town.recursive_equal(_readonly_town_storage(candidate), 0) or not mirrored_table.recursive_equal(current_table, 0):
			world_mutations += 1
			var paths: Array = []
			_changed_paths(world, candidate.world_map, "world", paths)
			_changed_paths(rooms, room_storage, "rooms", paths)
			_changed_paths(town, _readonly_town_storage(candidate), "town", paths)
			print("ROURKE_WORLD_MUTATIONS ", JSON.stringify(paths))
		return result

	func _readonly_room_storage(candidate: RunState) -> Dictionary:
		var rooms := candidate.grand_casino_room_states.duplicate(true)
		var active: Dictionary = rooms.get(str(candidate.current_environment.get("archetype_id", "")), {})
		var states: Dictionary = active.get("game_states", {})
		# The stored Back Room mirrors the current room's bound table. Its exact
		# table equality is checked separately; all other storage remains read-only.
		states.erase("blackjack")
		active.erase("environment_runtime_revision")
		return rooms

	func _readonly_town_storage(candidate: RunState) -> Dictionary:
		var town: Dictionary = candidate.town_state.snapshot(false).duplicate(true)
		# The final ending's reputation writes are covered explicitly by the proof.
		var network: Dictionary = town.get("living_world", {})
		network.erase("reputation_incidents")
		network.erase("reputation_sequence")
		return town

	func _changed_paths(a: Variant, b: Variant, prefix: String, paths: Array) -> void:
		if paths.size() >= 12: return
		if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
			for key in a:
				if not b.has(key): paths.append(prefix + "." + str(key))
				else: _changed_paths(a[key], b[key], prefix + "." + str(key), paths)
			for key in b:
				if not a.has(key): paths.append(prefix + "." + str(key))
		elif typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
			if a.size() != b.size(): paths.append(prefix + ".size")
			for i in mini(a.size(), b.size()): _changed_paths(a[i], b[i], prefix + "." + str(i), paths)
		elif a != b: paths.append(prefix)

class LegacyGame extends AuditedGame:
	func _blackjack_compact_authority_allowed(_candidate: RunState, _action_id: String, _stake: int, _ui_state: Dictionary = {}) -> bool:
		return false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():
		push_error("Rourke check requires an isolated distribution data root.")
		quit(2)
		return
	var library := ContentLibrary.new()
	library.load()
	var fixture_save := SaveService.new()
	var fixture_path := fixture_save.run_save_path("rourke_evidence_fixture")
	DirAccess.make_dir_recursive_absolute(fixture_path.get_base_dir())
	var fixture_file := FileAccess.open(fixture_path, FileAccess.WRITE)
	fixture_file.store_buffer(FileAccess.get_file_as_bytes(FIXTURE))
	fixture_file.close()
	# The preserved version-2 envelope contains RunSaveCodec values; use the
	# production decoder/migration path rather than treating it as a raw RunState.
	var original: RunState = fixture_save.load_run("rourke_evidence_fixture")
	if original == null:
		push_error("Preserved Rourke fixture failed production load.")
		quit(1)
		return
	var current := original.detached_host_action_candidate("blackjack")
	var legacy := original.detached_host_action_candidate("blackjack")
	var game := AuditedGame.new()
	var old_game := LegacyGame.new()
	game.setup(library.game("blackjack"), library)
	old_game.setup(library.game("blackjack"), library)
	game.enter(current, current.current_environment)
	old_game.enter(legacy, legacy.current_environment)
	_check(game._is_rourke_duel(current, current.current_environment), "preserved fixture reaches the real Rourke variant")
	var times: Array = []
	var terminal_rejection_source: RunState
	for hand in range(5):
		var now := current.simulation_msec + (hand + 1) * 100000
		var result := _hand(game, current, now)
		var current_usec := last_hand_elapsed_usec
		var old_result := _hand(old_game, legacy, now)
		var legacy_usec := last_hand_elapsed_usec
		if not bool(result.get("ok", false)) or not bool(old_result.get("ok", false)):
			push_error("Rourke parity fixture did not reach settlement; see ROURKE_REJECTION.")
			quit(1)
			return
		_check(bool(result.get(Authority.HOST_COMMITTED_KEY, false)) and bool(old_result.get(Authority.HOST_COMMITTED_KEY, false)), "hand %d commits both paths" % (hand + 1))
		_check(_public_snapshot(current) == _public_snapshot(legacy), "hand %d full-state parity including world, rules, balances and RNG" % (hand + 1))
		_check(Runtime.canonical_json(result.get("grand_casino_duel_status", {})) == Runtime.canonical_json(old_result.get("grand_casino_duel_status", {})), "hand %d duel progression parity" % (hand + 1))
		var committed := _public_snapshot(current, true)
		var host: Control = Driver._new_production_host()
		host.current_game = game
		host.game_module_cache = {"blackjack":game}
		host.run_state = current
		host.current_game_state_key = "blackjack"
		var replay: Dictionary = host._sealed_action_host_resolve_intent("play_basic", 20, result.get(Authority.HOST_DELIVERY_KEY, {}))
		_check(replay.has(Authority.HOST_REPLAY_KEY) and committed == _public_snapshot(current, true), "hand %d exactly-once replay" % (hand + 1))
		host.free()
		times.append({"hand":hand + 1,"current_usec":current_usec,"legacy_usec":legacy_usec})
		var evidence := game._blackjack_authority_evidence(current,"play_basic",20)
		_check(Runtime.canonical_json_native(evidence)==Runtime.canonical_json(evidence), "hand %d compact fingerprint bytes remain identical"%(hand+1))
		if hand == 3: terminal_rejection_source = current.detached_host_action_candidate("blackjack")
	_check(game.world_mutations == 0 and old_game.world_mutations == 0, "every proposal preserves unrelated world storage and mirrors only its proved table")
	_check(current.is_terminal() and legacy.is_terminal(), "fifth-hand ending reached through both paths")
	var prior_payload := SaveService._save_payload_result(current.to_save_snapshot(), "rourke_evidence_check")
	var compact_payload := SaveService._save_payload_result(current.to_save_snapshot_for_encoding(), "rourke_evidence_check")
	_check(bool(prior_payload.get("ok", false)) and Runtime.canonical_json(prior_payload) == Runtime.canonical_json(compact_payload), "synchronous terminal save encoding is identical with compiled room snapshots")
	var save := SaveService.new()
	_check(save.save_run(current, "rourke_evidence_check") == OK, "terminal save succeeds")
	var restored: RunState = save.load_run("rourke_evidence_check")
	_check(restored != null and restored.is_terminal() and restored.rng_state == current.rng_state, "Continue retains terminal run and RNG")
	if restored != null:
		var continued := restored.grand_casino_duel_status()
		var completed := current.grand_casino_duel_status()
		for key in ["hand_index", "player_stack", "rourke_stack", "margin"]:
			_check(int(continued.get(key, -1)) == int(completed.get(key, -2)), "Continue retains duel %s" % key)
		_check(str(continued.get("outcome", "")) == str(completed.get("outcome", "")), "Continue retains ending")
	var rejected_run := original.detached_host_action_candidate("blackjack")
	var corrupt := AuditedGame.new()
	corrupt.setup(library.game("blackjack"), library)
	corrupt.enter(rejected_run, rejected_run.current_environment)
	corrupt.corrupt_replay = true
	var rejected := _hand(corrupt, rejected_run, rejected_run.simulation_msec + 100000)
	_check(not bool(rejected.get("ok", false)), "broad narrative replay mismatch fails closed")
	_check(not rejected_run.narrative_flags.has("rourke_replay_probe_mismatch") and int(rejected_run.grand_casino_duel_status().get("hand_index", -1)) == 0, "rejected proposals leave live narrative and duel stacks unchanged")
	var reputation_run := original.detached_host_action_candidate("blackjack")
	var reputation_game := AuditedGame.new()
	reputation_game.setup(library.game("blackjack"), library)
	reputation_game.enter(reputation_run, reputation_run.current_environment)
	reputation_game.corrupt_reputation_replay = true
	var before_sequence := reputation_run.town_state.living_world.reputation_sequence
	var reputation_rejected := _hand(reputation_game, reputation_run, reputation_run.simulation_msec + 100000)
	_check(not bool(reputation_rejected.get("ok", false)) and reputation_run.town_state.living_world.reputation_sequence == before_sequence, "reputation replay mismatch fails closed without touching the live town")
	var ending_game := AuditedGame.new()
	ending_game.setup(library.game("blackjack"), library)
	ending_game.enter(terminal_rejection_source, terminal_rejection_source.current_environment)
	ending_game.corrupt_reputation_replay = true
	var ending_rejected := _hand(ending_game, terminal_rejection_source, terminal_rejection_source.simulation_msec + 600000, true)
	_check(not bool(ending_rejected.get("ok", false)) and not terminal_rejection_source.is_terminal(), "rejected ending cannot leak its town incident or terminal mutations")
	var narrow := original.to_action_snapshot_without_world()
	var full := original.to_save_snapshot()
	for key in ["town_state", "world_map", "grand_casino_room_states"]: full[key] = {}
	_check(Runtime.canonical_json(narrow) == Runtime.canonical_json(full), "evidence projection omits only the three audited read-only world roots")
	print("ROURKE_AUTHORITY_EVIDENCE ", JSON.stringify({"fidelity":"unchanged preserved v0.5.1 fixture through SaveService migration; real surface intents and production sealed host; full legacy state parity", "timings":times,"proposal_world_mutations":game.world_mutations,"failures":failures}))
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _hand(game: Blackjack, run: RunState, now: int, audit_rejection: bool = false) -> Dictionary:
	var deal: Dictionary = Driver.surface_intent(game, "blackjack_deal", 20, run, run.current_environment, 0, false, now)
	_check(bool(deal.get("handled", false)), "deal handled")
	var command: Dictionary = Driver.surface_intent(game, "blackjack_stand", 20, run, run.current_environment, 0, false, now + 5000)
	var pending_snapshot := _public_snapshot(run, true) if audit_rejection else ""
	var host: Control = Driver._new_production_host()
	host.current_game = game
	host.game_module_cache = {"blackjack":game}
	host.run_state = run
	host.current_game_state_key = "blackjack"
	host.selected_stake = 20
	var delivery: Dictionary = command.get("_sealed_action_host_delivery", {})
	var start := Time.get_ticks_usec()
	var result: Dictionary = host._sealed_action_host_resolve_intent(str(command.get("action_id", "")), int(delivery.get("stake", 20)), delivery, command.get("_sealed_action_host_prepared", {}))
	last_hand_elapsed_usec = Time.get_ticks_usec() - start
	if audit_rejection:
		_check(not bool(result.get("ok", false)) and _public_snapshot(run, true) == pending_snapshot, "rejected ending preserves every live model, authority, money and RNG field")
	if not bool(result.get("ok", false)):
		print("ROURKE_REJECTION ", JSON.stringify({"code":result.get("error_code"),"detail":result.get("diagnostic_detail"),"action":command.get("action_id"),"stake":delivery.get("stake"),"deal_message":deal.get("message"),"stand_message":command.get("message"),"deal_keys":deal.keys(),"stand_keys":command.keys()}))
	host.free()
	return result

func _public_snapshot(run: RunState, retain_authority_metadata: bool = false) -> String:
	# Save snapshots can borrow immutable storage projections. Mutating a test
	# comparison must never erase authority metadata through those live aliases.
	var snapshot := run.to_save_snapshot().duplicate(true)
	var crew: Dictionary = snapshot.get("crew_state", {})
	crew.erase("a")
	crew.erase("z")
	if not retain_authority_metadata: _strip_metadata(snapshot)
	return Runtime.canonical_json(snapshot)

func _strip_metadata(value: Variant) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for key in [Authority.LEDGER_KEY, Authority.PENDING_APPLY_RECEIPT_KEY, "environment_runtime_revision"]: value.erase(key)
		for key in value: _strip_metadata(value[key])
	elif typeof(value) == TYPE_ARRAY:
		for child in value: _strip_metadata(child)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
