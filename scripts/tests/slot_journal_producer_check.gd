extends SceneTree

# Synthetic producer-boundary qualification only. Controlled spin-result inputs
# enter the actual typed Slot receipt builder and offscreen builder; they do not
# qualify reel/RNG selection, sealed Host delivery or applied wallet accounting.
# The Buffalo sibling uses an authored machine and the actual bounded family
# steps. Tutorial coverage calls only the existing receipt/net transformation.
# No player save/profile, actual wager replay, Web or process-cold claim.

const Resolver := preload("res://scripts/games/slots/slot_resolver.gd")
const Generator := preload("res://scripts/games/slots/slot_machine_generator.gd")
const MachineState := preload("res://scripts/games/slots/slot_machine_state.gd")
const Buffalo := preload("res://scripts/games/slots/slot_family_buffalo.gd")
const SlotGame := preload("res://scripts/games/slot.gd")
const Journal := preload("res://scripts/ui/run_journal_view_model.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")

var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {
	"scope": "Synthetic direct production receipt builders; real bounded Buffalo family steps; existing tutorial transformation. No Host wallet, reel selection, Web, original profile or cold qualification.",
	"cases": {},
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _private_roots():
		_finish(); return
	var library := ContentLibrary.new()
	library.load(false)
	var definition: Dictionary = library.game("slot")
	if not _check(not definition.is_empty(), "authored Slot definition loads"):
		_finish(); return
	for context in ["cash_venue", "grand_cash_slot"]:
		var run := _run_state(context)
		_check(not run.grand_casino_game_uses_chips("slot", run.current_environment) and GameModule.presentation_currency_for_game(run, "slot", run.current_environment) == "cash", context + " supported Slot routing remains cash with chip wallet present")
		for path in ["normal", "offscreen"]:
			for sample in [
				{"id": "paid_loss", "cost": 2, "payout": 0, "net": -2},
				{"id": "paid_win", "cost": 2, "payout": 7, "net": 5},
				{"id": "paid_zero", "cost": 2, "payout": 2, "net": 0},
				{"id": "free_zero", "cost": 0, "payout": 0, "net": 0},
				{"id": "free_win", "cost": 0, "payout": 4, "net": 4},
			]:
				_spin_case(definition, run, context, path, sample)
	_bonus_family(definition)
	_tutorial_transform(definition)
	_legacy_unknown()
	_finish()

func _private_roots() -> bool:
	var private_root := OS.get_environment("BTH_WORLD_REENTRY_ROOT").replace("\\", "/").trim_suffix("/").to_lower()
	if not _check(private_root.is_absolute_path() and private_root.get_file().begins_with("native-private-"), "explicit disposable native root required"):
		return false
	for path in [ProjectSettings.globalize_path("user://"), OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT"), OS.get_environment("BTH_SAVE_DIR"), OS.get_environment("BTH_PROFILE_INVENTORY_PATH"), OS.get_environment("BTH_USER_SETTINGS_PATH"), OS.get_environment("BTH_META_COLLECTION_PATH"), OS.get_environment("APPDATA")]:
		if not _check(str(path).replace("\\", "/").to_lower().begins_with(private_root + "/" ) or str(path).replace("\\", "/").to_lower() == private_root, "all runtime and profile paths remain inside disposable root"):
			return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no captured save or original browser input accepted")

func _run_state(label: String) -> RunState:
	var run := RunState.new()
	run.start_new("SYNTHETIC-SLOT-JOURNAL-PRODUCER-" + label)
	run.bankroll = 134
	run.grand_casino_chips = 25
	run.baseline_luck = 0
	var grand := label.contains("grand")
	run.current_environment = {
		"id": "grand_casino_synthetic_slot" if grand else "synthetic_slot_producer_room",
		"archetype_id": "grand_casino" if grand else "gas_station_casino",
		"kind": "casino", "display_name": "Synthetic Slot Producer Room",
		"game_ids": ["slot"], "game_states": {}, "event_ids": [],
		"economic_profile": {"stake_floor": 2, "stake_ceiling": 60},
		"security_profile": {"strictness": "loose"},
	}
	return run

func _machine(definition: Dictionary, run: RunState, family: String) -> Dictionary:
	return Generator.new().build_machine_from_ids(definition, {
		"type_id": family, "format_id": "line_5x3", "math_variant_id": "standard",
		"cabinet_variant_id": "neon_magenta", "bonus_variant_id": "plain",
	}, run.create_rng("authored_machine_" + family))

func _normal_result(machine: Dictionary, environment: Dictionary, sample: Dictionary) -> Dictionary:
	# Deliberately supplied receipt-boundary inputs, never selected reel outcomes.
	return Resolver.new()._spin_result(FunctionOptions.SlotSpinResultOptions.from({
		"machine": machine, "entry": {"id": "synthetic_receipt_" + str(sample.id)},
		"action_id": "spin", "stake": 2, "stake_cost": int(sample.cost),
		"payout": int(sample.payout), "bankroll_delta": int(sample.net),
		"environment": environment, "free_spin": int(sample.cost) == 0,
	}))

func _spin_case(definition: Dictionary, run: RunState, context: String, path: String, sample: Dictionary) -> void:
	var label := context + "/" + path + "/" + str(sample.id)
	var machine := _machine(definition, run, "pinball")
	machine["last_classification"] = "true_win" if int(sample.net) > 0 else "zero_loss"
	var before := Runtime.content_fingerprint(run.to_dict())
	var machine_before := Runtime.content_fingerprint(machine)
	var result: Dictionary
	if path == "normal":
		result = _normal_result(machine, run.current_environment, sample)
	else:
		result = Resolver.new()._offscreen_spin_result(machine, {"id": "synthetic_receipt_" + str(sample.id)}, 2, int(sample.cost), int(sample.payout), int(sample.net), false, run.current_environment, {})
	_check(bool(result.get("ok", false)), label + " actual producer returns successful receipt")
	_check(Runtime.content_fingerprint(run.to_dict()) == before and Runtime.content_fingerprint(machine) == machine_before, label + " direct producer changes no run or machine state")
	_check(int(result.get("slot_stake_cost", -1)) == int(sample.cost) and int(result.get("slot_payout", -1)) == int(sample.payout) and int(result.get("slot_net", -999)) == int(sample.net) and int(result.get("deltas", {}).get("bankroll_delta", -999)) == int(sample.net), label + " existing stake payout and net stay exact")
	var entries: Array = result.get("deltas", {}).get("story_log", [])
	if not _check(entries.size() == 1, label + " exactly one existing spin story is produced"):
		return
	var entry: Dictionary = entries[0]
	_check(int(entry.get("stake_cost", -1)) == int(sample.cost) and int(entry.get("bankroll_delta", 0)) == int(sample.net), label + " story keeps actual current-action cost and net")
	_assert_money(entry, int(sample.net), label)
	_check(int(sample.net) != 0 or not entry.has("bankroll_delta"), label + " existing zero-bankroll compaction remains unchanged")
	run.log_story(entry)
	_read_only(run, label)
	facts.cases[label] = {"supplied_stake_cost": sample.cost, "supplied_payout": sample.payout, "supplied_net": sample.net, "journal": Journal._recorded_money_detail_lines(entry)}

func _bonus_family(definition: Dictionary) -> void:
	var run := _run_state("grand_buffalo_family")
	var machine := _machine(definition, run, "buffalo")
	var rng: RngStream = run.create_rng("real_buffalo_family_steps")
	# Authored family entry is synthetic setup, not a qualified trigger spin.
	machine["active_bonus"] = Buffalo.new().open_feature(machine, {"classification": "hold_and_spin"}, 2, rng, definition)
	var resolver := Resolver.new()
	var completed := false
	var saw_progression := false
	var public_steps: Array = []
	var root_rng_before: int = run.rng_state
	var initial_coin_out := int(machine.get("coin_out", 0))
	var final_award := 0
	for index in range(24):
		var resolved: Dictionary = resolver.resolve_bonus_action(machine, "slot_bonus_launch", rng, definition, run.current_environment, run)
		machine = resolved.get("machine", {})
		var result: Dictionary = resolved.get("result", {})
		if not _check(bool(result.get("ok", false)), "Buffalo family step%d succeeds" % index):
			break
		var entries: Array = result.get("deltas", {}).get("story_log", [])
		if not _check(entries.size() == 1, "Buffalo step%d produces one existing bonus receipt" % index):
			break
		var award := int(result.get("slot_bonus_award", -1))
		completed = bool(result.get("slot_bonus_complete", false))
		_check(award >= 0 and int(result.get("deltas", {}).get("bankroll_delta", -1)) == award, "Buffalo step%d metadata uses current awarded delta" % index)
		_assert_money(entries[0], award, "Buffalo family step%d" % index)
		if not completed:
			saw_progression = true
			_check(award == 0 and int(machine.get("coin_out", 0)) == initial_coin_out, "uncompleted Buffalo feature defers payment")
		public_steps.append({"step": index + 1, "complete": completed, "award": award, "journal": Journal._recorded_money_detail_lines(entries[0])})
		run.log_story(entries[0])
		if completed:
			final_award = award
			break
	_check(saw_progression and completed and final_award > 0, "bounded authored Buffalo family covers deferred progression and positive completion")
	_check(int(machine.get("coin_out", -1)) == initial_coin_out + final_award and not MachineState.active_bonus_incomplete(machine), "family completion credits machine output once and closes bonus")
	var repeat: Dictionary = resolver.resolve_bonus_action(machine, "slot_bonus_launch", rng, definition, run.current_environment, run)
	_check(int(repeat.get("result", {}).get("deltas", {}).get("bankroll_delta", 0)) == 0 and (repeat.get("result", {}).get("deltas", {}).get("story_log", []) as Array).is_empty() and int(repeat.get("machine", {}).get("coin_out", -1)) == int(machine.get("coin_out", 0)), "completed family guard creates no second award or story")
	# Direct family resolution does not apply wallet deltas; only the actual
	# emitted rows were appended above to exercise the read-only projection.
	_check(run.rng_state == root_rng_before and run.bankroll == 134 and run.grand_casino_chips == 25, "direct family fixture does not claim or change applied wallets or root RNG")
	_read_only(run, "Buffalo family rows")
	facts.cases["buffalo_actual_family"] = {"synthetic_entry": "authored hold_and_spin at2", "steps": public_steps, "completion_award": final_award, "coin_out_delta": int(machine.get("coin_out", 0)) - initial_coin_out}

func _tutorial_transform(definition: Dictionary) -> void:
	var run := _run_state("tutorial_existing_transform")
	run.challenge_config = {"id": "synthetic_tutorial_boundary", "tutorial": true, "modifiers": {"tutorial_first_slot_net": 6}}
	var machine := _machine(definition, run, "pinball")
	machine["spin_count"] = 1
	var sample := {"id": "tutorial_pre_match_loss", "cost": 2, "payout": 0, "net": -2}
	var original := {"machine": machine, "result": _normal_result(machine, run.current_environment, sample)}
	var before := Runtime.content_fingerprint(original)
	var run_before := Runtime.content_fingerprint(run.to_dict())
	var adjusted: Dictionary = SlotGame.new()._apply_tutorial_first_night_match(original, machine, "spin", run)
	var result: Dictionary = adjusted.get("result", {})
	var entry: Dictionary = result.get("deltas", {}).get("story_log", [{}])[0]
	_check(bool(result.get("tutorial_first_night_match", false)) and int(result.get("slot_net", -1)) == 6 and int(result.get("slot_payout", -1)) == 8 and int(result.get("deltas", {}).get("bankroll_delta", -1)) == 6, "existing tutorial transformation still returns its friendly net and payout")
	_check(int(entry.get("bankroll_delta", -1)) == 6 and int(entry.get("payout", -1)) == 8, "tutorial existing story net and payout match transformation")
	_assert_money(entry, 6, "tutorial transformed receipt")
	_check(Runtime.content_fingerprint(original) == before and Runtime.content_fingerprint(run.to_dict()) == run_before, "tutorial transformation changes only its detached receipt and machine")
	run.log_story(entry)
	_read_only(run, "tutorial transformed receipt")
	facts.cases["tutorial_existing_transformation"] = {"prior_net": -2, "transformed_net": result.get("slot_net"), "journal": Journal._recorded_money_detail_lines(entry)}

func _assert_money(entry: Dictionary, expected: int, label: String) -> void:
	_check(str(entry.get("currency", "")) == "cash" and entry.has("currency_delta") and int(entry.get("currency_delta", -999)) == expected, label + " newly produced story records exact cash delta including zero")
	_check(Journal._recorded_money_detail_lines(entry) == ["Bankroll %+d" % expected], label + " journal names exact cash unit without stake or payout double count")

func _legacy_unknown() -> void:
	var run := _run_state("grand_legacy_negative_control")
	# The only hand-authored story is the explicit pre-metadata negative control.
	var legacy := {"type": "game_action", "game_id": "slot", "slot_event": "slot_spin", "bankroll_delta": -2}
	run.log_story(legacy)
	var before := Runtime.content_fingerprint(run.story_log)
	_check(Journal._recorded_money_detail_lines(run.story_log[-1]) == ["Recorded change -2 (currency not recorded)"], "legacy Slot entry retains unknown-unit fallback at Grand")
	_read_only(run, "legacy unknown unit")
	_check(Runtime.content_fingerprint(run.story_log) == before and not run.story_log[-1].has("currency") and not run.story_log[-1].has("currency_delta"), "legacy history is never repaired or inferred")

func _read_only(run: RunState, label: String) -> void:
	var before := Runtime.content_fingerprint(run.to_dict())
	for repeat in range(3):
		Journal.entry_view_list(run, {})
	_check(Runtime.content_fingerprint(run.to_dict()) == before, label + " repeated journal reads preserve complete run state")

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
	return ok

func _finish() -> void:
	facts["source_sha256"] = {"resolver": FileAccess.get_sha256("res://scripts/games/slots/slot_resolver.gd"), "slot": FileAccess.get_sha256("res://scripts/games/slot.gd"), "journal": FileAccess.get_sha256("res://scripts/ui/run_journal_view_model.gd"), "test": FileAccess.get_sha256("res://scripts/tests/slot_journal_producer_check.gd")}
	var receipt := {"checks": checks, "failures": failures, "facts": facts}
	var output := OS.get_environment("BTH_TARGET_OUTPUT").replace("\\", "/")
	var private_root := OS.get_environment("BTH_WORLD_REENTRY_ROOT").replace("\\", "/").trim_suffix("/")
	if not output.is_empty() and output.to_lower().begins_with(private_root.get_base_dir().path_join("evidence").to_lower() + "/"):
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(receipt, "  ")); file.close()
	print("SLOT_JOURNAL_PRODUCER ", JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
