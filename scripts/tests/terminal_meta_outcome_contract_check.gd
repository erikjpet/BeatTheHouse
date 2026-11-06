extends SceneTree

# Synthetic public RunState terminal DTO controls; no host/navigation claim.
# Reviewed candidate: Drop 8c123c2b0f612463b037855dfe7b57906ab7e180f371ac0cbcd88aab349726b0
# Meta 0ae6cbb7386c95dc7f7f3349b9241062bf50151131b6cd94b5d605adfe643676.
# Execute only through the guarded private-storage launcher described in audit phase029.
# Eager API parity below shares the candidate stage helper; it is an API parity
# control, not independent historical-source or full player-flow evidence.
const MetaScript := preload("res://scripts/core/meta_collection_service.gd")
const DropScript := preload("res://scripts/core/collection_drop_service.gd")
const RunScript := preload("res://scripts/core/run_state.gd")
const SENTINEL := "Preserve this ordinary phase029 temporary-path obstruction.\n"
const SEED := "AUDIT029-DOMAIN"

var checks: int = 0
var failures: Array[String] = []
var observations: Array = []
var owned_root: String = ""
var original_meta_path: String = ""

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
	return condition

func _run() -> void:
	original_meta_path = OS.get_environment(MetaScript.STORE_PATH_ENV)
	if _paths():
		for kind in ["highroller", "tutorial", "chips", "prestige"]:
			_outcome_case(kind)
		_rollback_case("failed")
		_rollback_case("highroller")
		_legacy_and_malformed()
	OS.set_environment(MetaScript.STORE_PATH_ENV, original_meta_path)
	print("META029_DOMAIN_OBSERVATIONS " + JSON.stringify({
		"stage": "domain", "checks": checks, "failures": failures, "observations": observations,
		"scope": "Synthetic primitive/public DTO controls; fresh Meta.load is same-process cold service, not a fresh-process Continue or host acknowledgement proof."
	}))
	quit(0 if failures.is_empty() else 1)

func _paths() -> bool:
	owned_root = OS.get_environment("BTH_AUDIO_LEGACY_PRIVATE_ROOT").replace("\\", "/").trim_suffix("/").simplify_path()
	if not _check(not OS.has_feature("web") and OS.get_cmdline_user_args().is_empty(), "Fixed native domain script, no process arguments"):
		return false
	if not _check(owned_root.is_absolute_path() and owned_root.ends_with("/meta029-domain-regression-r2"), "Exact launcher-owned fresh domain root"):
		return false
	if not _check(original_meta_path.replace("\\", "/").simplify_path() == owned_root.path_join("meta/collection.json"), "Launcher Meta path belongs to selected root"):
		return false
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").replace("\\", "/").simplify_path() == owned_root.path_join("data"), "Launcher distribution root belongs to selected case"):
		return false
	var cases_path: String = owned_root.path_join("cases")
	return _check(DirAccess.dir_exists_absolute(owned_root) and not DirAccess.dir_exists_absolute(cases_path) and not FileAccess.file_exists(cases_path), "No inherited domain case storage") \
		and _check(DirAccess.make_dir_absolute(cases_path) == OK, "Fresh case parent created nonrecursively")

func _select_case(name: String, fresh: bool = true) -> MetaCollectionService:
	var directory: String = owned_root.path_join("cases").path_join(name).simplify_path()
	if not _check(directory.begins_with(owned_root + "/cases/") and name == name.get_file(), name + ": fixed child case path"):
		return null
	if fresh:
		if not _check(not DirAccess.dir_exists_absolute(directory) and not FileAccess.file_exists(directory), name + ": fresh child storage") \
			or not _check(DirAccess.make_dir_absolute(directory) == OK, name + ": child created nonrecursively"):
			return null
	var path: String = directory.path_join("collection.json")
	OS.set_environment(MetaScript.STORE_PATH_ENV, path)
	var service: MetaCollectionService = MetaScript.new()
	service.load()
	if not fresh and not _check(bool(service.last_load_result().get("ok", false)), name + ": new Meta.load reads durable collection"):
		return null
	return service

func _terminal(kind: String, extra_modifiers: Dictionary = {}) -> RunState:
	# Explicit synthetic terminal state, using public fields and normal start API.
	var modifiers: Dictionary = {"meta_collection_enabled": true}
	modifiers.merge(extra_modifiers, true)
	var config: Dictionary = {"mode": "standard", "id": "standard", "modifiers": modifiers}
	if kind == "tutorial":
		config = {"mode": "custom", "id": "tutorial_first_card", "tutorial": true,
			"completion_flag": "challenge_tutorial_first_card_complete",
			"modifiers": {"tutorial_run": true, "tutorial_main_floor_only": true}}
	elif kind == "highroller":
		config["hidden_seed"] = true
	var run: RunState = RunScript.new()
	run.start_new(SEED + "-" + kind, config)
	run.bankroll = 500
	run.run_spending_score = 37
	run.game_clock_minutes = 2340
	run.run_status = RunScript.RUN_STATUS_FAILED if kind == "failed" else RunScript.RUN_STATUS_ENDED
	if kind in ["highroller", "tutorial"]:
		run.narrative_flags["demo_victory_route"] = DropScript.TUTORIAL_BRONZE_ROUTE if kind == "tutorial" else RunScript.GRAND_CASINO_HIGH_ROLLER_EVENT_ID
		run.narrative_flags["grand_casino_players_card_highest_tier"] = "bronze" if kind == "tutorial" else "gold"
		run.log_story({"type": "grand_casino_players_card_tier", "tier": "bronze", "games_played": 1, "net_winnings": 5})
		run.log_story({"type": "grand_casino_players_card_tier", "tier": "gold", "games_played": 5, "net_winnings": 30})
	elif kind == "chips":
		run.narrative_flags.merge({"demo_victory_route": RunScript.GRAND_CASINO_SHOWDOWN_ROUTE,
			"grand_casino_walked_with_chips": true, "grand_casino_duel_outcome": "shown_the_door",
			"grand_casino_uncashed_chip_amount": 37}, true)
	return run

func _outcome_case(kind: String) -> void:
	var meta: MetaCollectionService = _select_case(kind)
	if meta == null:
		return
	var extra: Dictionary = {}
	if kind == "prestige":
		extra = {"grand_casino_prestige": true, "grand_casino_prestige_card_instance_ids": [21, 22], "meta_collection_drop_tier_bonus_steps": 2}
	var run: RunState = _terminal(kind, extra)
	var drop: CollectionDropService = DropScript.new()
	if kind == "tutorial":
		meta.add_gold(60)
		if not _check(bool(meta.purchase_housing_upgrade().get("ok", false)), "Tutorial control prepares ordinary upgraded home"):
			return
	var before_items: Array = meta.owned_instances()
	var before_sal_rng: Dictionary = meta.sal_resale_rng_snapshot()
	var before_meta_rng: Dictionary = meta.meta_rng_snapshot()
	var prepared: Dictionary = drop.prepare_terminal_special_outcome(run, meta)
	if not _check(bool(prepared.get("ok", false)), kind + ": preparation accepts synthetic terminal DTO"):
		return
	var record: Dictionary = (prepared.get("record", {}) as Dictionary).duplicate(true)
	if not _check(not record.is_empty() and meta.owned_instances() == before_items and not bool(run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG, false)), kind + ": preparation keeps effects unprocessed"):
		return
	var repeated_prepare: Dictionary = drop.prepare_terminal_special_outcome(run, meta)
	_check(repeated_prepare.get("record", {}) == record, kind + ": repeated preparation preserves exact receipt and intent")
	var result: Dictionary = drop.commit_terminal_special_outcome(run, meta)
	if not _check(bool(result.get("ok", false)), kind + ": public commit saves collection and receipt"):
		return
	_assert_result(kind, result, run, meta)
	_check(meta.sal_resale_rng_snapshot() == before_sal_rng and meta.meta_rng_snapshot() == before_meta_rng, kind + ": terminal receipts preserve both unrelated RNG streams")
	if kind == "highroller":
		_check(not JSON.stringify(meta.snapshot()).contains(SEED), "Hidden winning seed does not leak through durable outcome intent or result")
	var warm_items: Array = meta.owned_instances()
	var warm_carried: Array = meta.carried_instance_ids()
	var warm_story: String = JSON.stringify(run.story_log)
	var warm_store: String = JSON.stringify(meta.snapshot())
	var path: String = MetaScript.store_path()
	var disk_hash: String = FileAccess.get_sha256(path)
	var repeated: Dictionary = drop.commit_terminal_special_outcome(run, meta)
	_check(bool(repeated.get("ok", false)) and bool(repeated.get("reused", false)) and JSON.stringify(run.story_log) == warm_story and JSON.stringify(meta.snapshot()) == warm_store, kind + ": warm replay repeats no effects or story")
	var cold: MetaCollectionService = _select_case(kind, false)
	if cold == null:
		return
	var cold_before: String = JSON.stringify(cold.snapshot())
	var replay_run: RunState = _terminal(kind, extra)
	replay_run.narrative_flags[DropScript.SPECIAL_OUTCOME_RECORD_FLAG] = record.duplicate(true)
	var replay: Dictionary = drop.commit_terminal_special_outcome(replay_run, cold)
	_check(bool(replay.get("ok", false)) and bool(replay.get("reused", false)), kind + ": fresh Meta.load reuses exact durable receipt")
	_assert_result(kind, replay, replay_run, cold)
	_check(JSON.stringify(cold.snapshot()) == cold_before and FileAccess.get_sha256(path) == disk_hash, kind + ": cold replay preserves collection/RNG/receipt bytes")
	var mismatch: Dictionary = cold.commit_terminal_special_outcome(str(record.get("receipt", "")), str(record.get("intent_json", "")) + " ")
	_check(not bool(mismatch.get("ok", true)) and JSON.stringify(cold.snapshot()) == cold_before and FileAccess.get_sha256(path) == disk_hash, kind + ": same receipt rejects different intent bytes without effects")
	observations.append({"case": kind, "receipt": record.get("receipt"), "owned_count": cold.owned_instances().size(), "reused": replay.get("reused"), "reward": replay})
	var parity: MetaCollectionService = _select_case("parity-" + kind)
	if parity == null:
		return
	if kind == "tutorial":
		parity.add_gold(60)
		if not _check(bool(parity.purchase_housing_upgrade().get("ok", false)), "Tutorial eager parity prepares same upgraded home"):
			return
		_check(not run.meta_collection_enabled_for_run() and run.is_tutorial_run(), "Tutorial eligibility remains the explicit exception")
	var parity_run: RunState = _terminal(kind, extra)
	var eager: Dictionary = drop.apply_terminal_special_outcome(parity_run, parity)
	_check(bool(eager.get("ok", false)) and parity.owned_instances() == warm_items and parity.carried_instance_ids() == warm_carried, kind + ": retained eager API matches public item/loadout result")
	_check(parity_run.story_log == run.story_log, kind + ": retained eager API matches acknowledged story")

func _assert_result(kind: String, result: Dictionary, run: RunState, meta: MetaCollectionService) -> void:
	_check(bool(run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG, false)), kind + ": successful result acknowledges run processing")
	if kind in ["highroller", "tutorial"]:
		var reward: Dictionary = result.get("card_reward", {})
		var stamp: Dictionary = reward.get("instance_data", {})
		var timeline: Array = stamp.get("tier_timeline", [])
		_check(meta.owned_instances().size() == 1 and int(reward.get("itemdef_id", 0)) == 9500 and typeof(reward.get("instance_id")) == TYPE_INT, kind + ": exactly one first-class card with integer identity")
		_check(typeof(stamp.get("final_score")) == TYPE_INT and int(stamp.get("final_score", -1)) == int(run.terminal_score_summary().get("score", -2)) and typeof(stamp.get("days_survived")) == TYPE_INT and int(stamp.get("days_survived", 0)) == 2, kind + ": score and day stamp survives integer JSON transport")
		var timeline_valid: bool = timeline.size() == 2
		if timeline_valid:
			var first: Dictionary = timeline[0]
			var last: Dictionary = timeline[1]
			timeline_valid = typeof(first.get("games_played")) == TYPE_INT and int(first.get("games_played", 0)) == 1 and typeof(last.get("net_winnings")) == TYPE_INT and int(last.get("net_winnings", 0)) == 30
		_check(timeline_valid, kind + ": ordered tier timeline retains exact integer observations")
		if kind == "highroller":
			_check(str(stamp.get("seed", "")) == "Hidden challenge" and bool(stamp.get("seed_hidden", false)) and not JSON.stringify(stamp).contains(SEED), "Highroller card preserves hidden seed presentation")
		else:
			_check(bool(stamp.get("starter_card", false)) and bool(stamp.get("tutorial", false)) and str(stamp.get("tutorial_challenge_id", "")) == "tutorial_first_card" and meta.carried_instance_ids().has(int(reward.get("instance_id", 0))), "Tutorial card retains starter stamp and carried identity")
	elif kind == "chips":
		var reward: Dictionary = result.get("chips_reward", {})
		var stamp: Dictionary = reward.get("instance_data", {})
		var quote: Dictionary = meta.sale_quote(MetaScript.SALE_KIND_ITEM, int(reward.get("instance_id", 0)))
		_check(meta.owned_instances().size() == 1 and typeof(reward.get("stack_amount")) == TYPE_INT and int(reward.get("stack_amount", 0)) == 37 and typeof(reward.get("face_value")) == TYPE_INT and int(reward.get("face_value", 0)) == 37 and typeof(stamp.get("chip_amount")) == TYPE_INT, "Shown-door chips retain integer stack/face/stamp values")
		_check(bool(quote.get("ok", false)) and int(quote.get("price", 0)) == 22 and typeof(reward.get("fenced_gold_value")) == TYPE_INT and int(reward.get("fenced_gold_value", 0)) == 22 and is_equal_approx(float(quote.get("gold_rate", 0)), 0.6), "Shown-door stack keeps ordinary 60-percent Sal quote")
		_check(meta.carried_instance_ids().is_empty(), "Chip stack remains outside the run loadout")
	elif kind == "prestige":
		var prestige: Dictionary = result.get("prestige_result", {})
		_check(meta.owned_instances().is_empty() and bool(prestige.get("active", false)) and str(prestige.get("status", "")) == "retained", "Prestige-only outcome preserves no-grant semantics")
		_check(typeof(prestige.get("card_count")) == TYPE_INT and int(prestige.get("card_count", 0)) == 2 and typeof(prestige.get("drop_tier_bonus_steps")) == TYPE_INT and int(prestige.get("drop_tier_bonus_steps", 0)) == 2, "Prestige counters remain integers after receipt replay")

func _ordinary(meta: MetaCollectionService, definition_id: int, condition: float) -> Dictionary:
	return meta.grant_instance({"itemdef_id": definition_id, "potency": 0.5, "condition": condition, "resonance": 0.5, "usage": 0.5, "source": "earned_domain_control", "source_id": "audit029"})

func _owned(meta: MetaCollectionService, identity: int) -> Dictionary:
	for value in meta.owned_instances():
		var item: Dictionary = value
		if int(item.get("instance_id", 0)) == identity:
			return item
	return {}

func _rollback_case(kind: String) -> void:
	var label: String = "rollback-" + kind
	var meta: MetaCollectionService = _select_case(label)
	if meta == null:
		return
	var item: Dictionary = _ordinary(meta, 1000, 0.75)
	var card: Dictionary = meta.mint_players_card({"seed": "audit029-origin", "route": RunScript.GRAND_CASINO_HIGH_ROLLER_EVENT_ID})
	if not _check(not item.is_empty() and not card.is_empty() and meta.save() == OK, label + ": ordinary baseline is durable"):
		return
	var path: String = MetaScript.store_path()
	var disk_before: String = FileAccess.get_sha256(path)
	# Unrelated dirty work must survive a failed transaction; no disk reload.
	meta.add_gold(17)
	var dirty_item: Dictionary = _ordinary(meta, 1001, 0.8)
	meta.grant_bag(9000, "audit029-dirty-bag", {"source": "earned_domain_control", "source_id": "audit029"})
	var run: RunState = _terminal(kind, {"meta_collection_carried_instance_ids": [int(item["instance_id"]), int(card["instance_id"])]})
	var drop: CollectionDropService = DropScript.new()
	var prepared: Dictionary = drop.prepare_terminal_special_outcome(run, meta)
	if not _check(bool(prepared.get("ok", false)), label + ": public preparation succeeds"):
		return
	var record: Dictionary = (prepared.get("record", {}) as Dictionary).duplicate(true)
	var before: Dictionary = meta.snapshot()
	var before_json: String = JSON.stringify(before)
	var before_rng: Dictionary = meta.meta_rng_snapshot()
	var before_quote: Dictionary = meta.sale_quote(MetaScript.SALE_KIND_ITEM, int(item["instance_id"]))
	var revision: int = meta.state_revision()
	var blocked: String = path + ".tmp"
	var preserved: String = path + ".tmp-blocker-preserved"
	if not _check(blocked.begins_with(owned_root + "/cases/") and preserved.begins_with(owned_root + "/cases/") and not DirAccess.dir_exists_absolute(blocked) and not FileAccess.file_exists(blocked) and not DirAccess.dir_exists_absolute(preserved) and not FileAccess.file_exists(preserved), label + ": exact fresh owned obstruction paths"):
		return
	if not _check(DirAccess.make_dir_absolute(blocked) == OK, label + ": actual temporary-path obstruction created"):
		return
	var sentinel: FileAccess = FileAccess.open(blocked.path_join("preserve.txt"), FileAccess.WRITE)
	if not _check(sentinel != null, label + ": obstruction sentinel opens"):
		return
	sentinel.store_string(SENTINEL)
	sentinel.close()
	var failed: Dictionary = drop.commit_terminal_special_outcome(run, meta)
	_check(not bool(failed.get("ok", true)) and failed.has("save_error"), label + ": real filesystem prevents collection commit")
	_check(JSON.stringify(meta.snapshot()) == before_json and meta.meta_rng_snapshot() == before_rng and int(meta.snapshot().get("next_instance_id", -1)) == int(before.get("next_instance_id", -2)), label + ": rollback restores all owned/counter/loadout/RNG/dirty state")
	_check(meta.sale_quote(MetaScript.SALE_KIND_ITEM, int(item["instance_id"])) == before_quote and bool(meta.ensure_players_card_carried(int(card["instance_id"])).get("ok", false)) and not _owned(meta, int(dirty_item["instance_id"])).is_empty(), label + ": public indexed lookups recover original and unrelated dirty items")
	_check(meta.state_revision() > revision and FileAccess.get_sha256(path) == disk_before and not bool(run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG, false)) and run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_RECORD_FLAG, {}) == record, label + ": failure preserves disk, pending intent and monotonic revision")
	if not _check(DirAccess.rename_absolute(blocked, preserved) == OK and FileAccess.get_file_as_string(preserved.path_join("preserve.txt")) == SENTINEL, label + ": checked nonrecursive rename preserves obstruction"):
		return
	var retried: Dictionary = drop.commit_terminal_special_outcome(run, meta)
	if not _check(bool(retried.get("ok", false)) and run.narrative_flags.get(DropScript.SPECIAL_OUTCOME_RECORD_FLAG, {}) == record, label + ": same prepared identity succeeds after obstruction moves"):
		return
	var cold: MetaCollectionService = _select_case(label, false)
	if cold == null:
		return
	var cold_before: String = JSON.stringify(cold.snapshot())
	var replay: Dictionary = cold.commit_terminal_special_outcome(str(record.get("receipt", "")), str(record.get("intent_json", "")))
	_check(bool(replay.get("ok", false)) and bool(replay.get("reused", false)) and JSON.stringify(cold.snapshot()) == cold_before, label + ": cold retry repeats no effects")
	_check(int(cold.snapshot().get("gold_balance", 0)) == 17 and cold.unopened_bag_count() == 1 and is_equal_approx(float(_owned(cold, int(dirty_item["instance_id"])).get("condition", 0)), 0.8), label + ": successful retry preserves unrelated dirty work")
	if kind == "failed":
		_check(is_equal_approx(float(_owned(cold, int(item["instance_id"])).get("condition", 0)), 0.65) and _owned(cold, int(card["instance_id"])).is_empty(), "Ordinary condition loses 0.10 once and carried card is destroyed once")
	else:
		_check(cold.owned_instances().size() == (before.get("owned_instances", []) as Array).size() + 1, "Failed card allocation leaves no phantom instance before exactly one successful grant")
	observations.append({"case": label, "save_error": failed.get("save_error"), "preserved_directory": preserved, "receipt": record.get("receipt"), "reused": replay.get("reused")})

func _legacy_and_malformed() -> void:
	var meta: MetaCollectionService = _select_case("legacy")
	if meta == null:
		return
	var drop: CollectionDropService = DropScript.new()
	var legacy: RunState = _terminal("highroller")
	legacy.narrative_flags[DropScript.SPECIAL_OUTCOME_PROCESSED_FLAG] = true
	var before: String = JSON.stringify(meta.snapshot())
	var old_result: Dictionary = drop.commit_terminal_special_outcome(legacy, meta)
	_check(bool(old_result.get("ok", false)) and bool(old_result.get("legacy_processed", false)) and not legacy.narrative_flags.has(DropScript.SPECIAL_OUTCOME_RECORD_FLAG) and not drop.terminal_special_outcome_pending(legacy) and JSON.stringify(meta.snapshot()) == before, "Legacy processed/no-record remains unchanged without fabricated receipt or grant")
	var unprocessed: RunState = _terminal("legacy_unprocessed")
	var prepared: Dictionary = drop.prepare_terminal_special_outcome(unprocessed, meta)
	_check(bool(prepared.get("ok", false)) and not (prepared.get("record", {}) as Dictionary).is_empty() and drop.terminal_special_outcome_pending(unprocessed), "Legacy-shaped unprocessed terminal prepares a new pending record")
	var malformed: RunState = _terminal("highroller")
	var bad_record: Dictionary = {"schema_version": 1, "receipt": "terminal-outcome:1", "intent_json": "[]"}
	malformed.narrative_flags[DropScript.SPECIAL_OUTCOME_RECORD_FLAG] = bad_record.duplicate(true)
	before = JSON.stringify(meta.snapshot())
	_check(drop.terminal_special_outcome_pending(malformed) and not bool(drop.prepare_terminal_special_outcome(malformed, meta).get("ok", true)) and not bool(drop.commit_terminal_special_outcome(malformed, meta).get("ok", true)) and malformed.narrative_flags.get(DropScript.SPECIAL_OUTCOME_RECORD_FLAG, {}) == bad_record and JSON.stringify(meta.snapshot()) == before, "Malformed modern run record is rejected and preserved as pending")
	# Public snapshot -> primitive JSON fixture -> ordinary load. No private fields.
	var corrupt_meta: MetaCollectionService = _select_case("malformed-store")
	if corrupt_meta == null:
		return
	var control_run: RunState = _terminal("highroller")
	var control: Dictionary = drop.prepare_terminal_special_outcome(control_run, corrupt_meta)
	if not _check(bool(control.get("ok", false)), "Malformed-store control obtains ordinary public intent"):
		return
	var record: Dictionary = (control.get("record", {}) as Dictionary).duplicate(true)
	var dto: Dictionary = corrupt_meta.snapshot()
	var bad_receipts: Dictionary = {}
	bad_receipts[str(record.get("receipt", ""))] = {"intent_json": str(record.get("intent_json", "")), "result": "invalid ordinary DTO"}
	dto["terminal_special_outcomes"] = bad_receipts
	var file: FileAccess = FileAccess.open(MetaScript.store_path(), FileAccess.WRITE)
	if not _check(file != null, "Fresh owned malformed receipt DTO opens"):
		return
	file.store_string(JSON.stringify(dto))
	file.close()
	var loaded: MetaCollectionService = _select_case("malformed-store", false)
	if loaded == null:
		return
	before = JSON.stringify(loaded.snapshot())
	var mismatch: Dictionary = loaded.commit_terminal_special_outcome(str(record.get("receipt", "")), str(record.get("intent_json", "")))
	_check(not bool(mismatch.get("ok", true)) and JSON.stringify(loaded.snapshot()) == before and loaded.owned_instances().is_empty(), "Malformed stored modern receipt is rejected without treating it as absent or granting")
	observations.append({"case": "legacy-and-malformed", "legacy_processed": old_result.get("legacy_processed"), "malformed_stored_rejected": not bool(mismatch.get("ok", true))})
