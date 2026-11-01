extends SceneTree

const Blackjack := preload("res://scripts/games/blackjack.gd")
const Driver := preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const Codec := preload("res://scripts/core/run_save_codec.gd")
const Saves := preload("res://scripts/core/save_service.gd")
const Store := preload("res://scripts/core/durable_store.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-save-float-samewire-blackjack-") and OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty(), "fresh synthetic root, no captured fixture"):
		_finish(); return
	var library := ContentLibrary.new()
	library.load(false)
	var run := RunState.new()
	run.start_new("SYNTHETIC-SAMEWIRE-BLACKJACK-RECEIPT")
	run.crew_change_reputation(0)
	# Explicit synthetic wallet/table constructor, matching the established
	# authority test driver. No user route, save or predicted outcome is used.
	run.bankroll = 78
	run.grand_casino_chips = 80
	run.current_environment = {"id": "samewire_receipt_table", "archetype_id": RunState.GRAND_CASINO_ARCHETYPE_ID, "display_name": "Synthetic receipt table", "game_ids": ["blackjack"], "economic_profile": {"stake_floor": 1, "stake_ceiling": 100}, "security_profile": {}, "game_states": {}}
	var game := Blackjack.new()
	for definition in library.games:
		if str(definition.get("id", "")) == "blackjack": game.setup(definition, library)
	var table := game.generate_environment_state(run, run.current_environment, run.create_rng("samewire_receipt_table"))
	game.environment_state_generated(run, run.current_environment, table)
	run.current_environment.game_states["blackjack"] = table
	# Retain the actual sealed delivery. Driver.resolve intentionally mints a
	# fresh intent and is not a replay API; using it twice tests two new actions.
	var command := Driver.surface_intent(game, "blackjack_deal", 40, run, run.current_environment, 0, false, 24000)
	if not _check(command.has("_sealed_action_host_delivery"), "surface issues actual sealed delivery"):
		_finish(); return
	var dealt := Driver.resolve_surface_command(game, command, 40, run, run.current_environment)
	if not _check(dealt.get("ok", false), "normal production authority accepts synthetic Deal"):
		_finish(); return
	var original: Dictionary = run.current_environment.game_states.blackjack[Authority.LEDGER_KEY]
	var binding := str(original.table_binding)
	_check(not Authority.validate_persisted_ledger(original, binding).is_empty(), "original production receipt/ledger validates")
	var service := Saves.new()
	_check(not service.has_run("samewire_blackjack_current") and service.save_run(run, "samewire_blackjack_current") == OK, "official current Save stores authorized table")
	var current: Variant = Saves.new().load_run("samewire_blackjack_current")
	if not _check(current is RunState, "fresh service restores current authorized table"):
		_finish(); return
	var ledger: Dictionary = current.current_environment.game_states.blackjack[Authority.LEDGER_KEY]
	_check(not Authority.validate_persisted_ledger(ledger, binding).is_empty(), "current stored receipt and hash chain validate unchanged")
	_check(typeof(ledger.next_request_ordinal) == TYPE_INT and typeof(ledger.boundary_ordinal) == TYPE_INT, "typed ledger integer markers survive storage")
	var changed := ledger.duplicate(true)
	if _check(not changed.journal.is_empty(), "authorized Deal creates actual journal evidence"):
		changed.journal[0].stake += 1
		_check(Authority.validate_persisted_ledger(changed, binding).is_empty(), "mutated signed journal still rejects")
	var snapshot := run.to_save_snapshot()
	var old_text := JSON.stringify(Codec.encode(snapshot))
	var bytes := old_text.to_utf8_buffer()
	var compressed := bytes.compress(FileAccess.COMPRESSION_ZSTD)
	var old_pack := {Codec.STORAGE_MARKER_KEY: Codec.STORAGE_FORMAT, Codec.STORAGE_DATA_KEY: Codec._z85_encode(compressed), Codec.STORAGE_HASH_KEY: old_text.sha256_text(), Codec.STORAGE_SIZE_KEY: bytes.size(), Codec.STORAGE_COMPRESSED_SIZE_KEY: compressed.size()}
	var payload := {"schema": Saves.SAVE_SCHEMA, "version": 2, "act": 1, "slot_id": "samewire_blackjack_legacy", "run_state": old_pack}
	_check(Store.write_json(service.run_save_path("samewire_blackjack_legacy"), payload).get("ok", false), "generated old-writer spelling fixture installs")
	var legacy: Variant = Saves.new().load_run("samewire_blackjack_legacy")
	_check(legacy is RunState and not Authority.validate_persisted_ledger(legacy.current_environment.game_states.blackjack[Authority.LEDGER_KEY], binding).is_empty(), "generated legacy receipt/hash chain validates after corrected decimal parse")
	var before := [current.bankroll, current.grand_casino_chips, current.rng_state, current.story_log.size()]
	var replay := Driver.resolve_surface_command(game, command, 40, current, current.current_environment)
	_check([current.bankroll, current.grand_casino_chips, current.rng_state, current.story_log.size()] == before, "repeated original command cannot charge, advance RNG or append history twice")
	facts["replay_result_ok"] = replay.get("ok", false)
	facts["fidelity"] = "Fresh synthetic producer/authority action, current Save/fresh-service load and old writer spelling. No actual old profile, historical key, cold UI or natural outcome claim."
	_finish()

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _finish() -> void:
	print("SAMEWIRE_BLACKJACK_RECEIPT " + JSON.stringify({"checks": checks, "failures": failures, "facts": facts}))
	quit(0 if failures.is_empty() else 1)
