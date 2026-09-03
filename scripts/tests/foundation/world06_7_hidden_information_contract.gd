extends SceneTree

const RunStateScript := preload("res://scripts/core/run_state.gd")
const CrewHeistModelScript := preload("res://scripts/core/crew_heist_model.gd")
const CrewTurnModelScript := preload("res://scripts/core/crew_turn_model.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")


func _initialize() -> void:
	var failures: Array = []
	_check_save_authority_lifecycle(failures)
	_check_semantic_indistinguishability(failures)
	_check_zero_to_one_indistinguishability(failures)
	_check_public_job_failure_projection(failures)
	_check_grievance_producer_surfaces(failures)
	_check_round_trip_and_reseal(failures)
	_check_hostile_capsules(failures)
	_check_capacity_failure(failures)
	_check_legacy_migration(failures)
	if failures.is_empty():
		print("world06_7 hidden-information contract passed capsule_bytes=%d key=per_install nonce=random cache=stable tamper=fail_closed binding=sealed legacy=v1_migrated" % CrewTurnModelScript.PRIVATE_SAVE_BYTES)
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)


func _check_save_authority_lifecycle(failures: Array) -> void:
	var unstarted := RunStateScript.new()
	_check(CrewTurnModelScript.valid_authority_id(str(unstarted.get("_crew_private_authority_id"))), "A newly constructed RunState lacked private save authority before fixture population.", failures)
	var run := RunStateScript.new()
	run.start_new("WORLD06-7-AUTHORITY-LIFECYCLE", RunStateScript.standard_challenge("WORLD06-7-AUTHORITY-LIFECYCLE"))
	var authority_before_save := str(run.get("_crew_private_authority_id"))
	_check(CrewTurnModelScript.valid_authority_id(authority_before_save), "A new run did not mint its private save authority during construction.", failures)
	var first := run.to_save_snapshot()
	var second := run.to_save_snapshot()
	_check(str(run.get("_crew_private_authority_id")) == authority_before_save, "Save projection replaced the live run's private authority.", failures)
	_check(str(_saved_crew(first).get("a", "")) == authority_before_save and JSON.stringify(first) == JSON.stringify(second), "Save projection did not retain one stable per-run private envelope.", failures)


func _check_semantic_indistinguishability(failures: Array) -> void:
	var turned := _fixture("WORLD06-7-TWIN")
	var clean := _fixture("WORLD06-7-TWIN")
	turned.crew_heist_state["x"] = _private("crew_switch")
	clean.crew_heist_state["x"] = _private("")
	clean.crew_grievance_ledger[0]["kind"] = "wrong_accusation"
	for projection in ["runtime", "persistent"]:
		var turned_projection := turned.to_dict() if projection == "runtime" else turned.to_save_snapshot()
		var clean_projection := clean.to_dict() if projection == "runtime" else clean.to_save_snapshot()
		for snapshot in [turned_projection, clean_projection]:
			var crew := _saved_crew(snapshot)
			_check(not crew.has("grievances") and not crew.has("grievance_sequence") and not crew.has("g") and not crew.has("q"), "%s serialization exposed a literal or reversible grievance projection." % projection, failures)
			_check(not _saved_heist(snapshot).has("x") and not _saved_heist(snapshot).has("z"), "%s serialization exposed heist-local private authority." % projection, failures)
	var turned_save := turned.to_save_snapshot()
	var clean_save := clean.to_save_snapshot()
	var turned_crew := _saved_crew(turned_save)
	var clean_crew := _saved_crew(clean_save)
	var turned_capsule := Marshalls.base64_to_raw(str(turned_crew.get("z", "")))
	var clean_capsule := Marshalls.base64_to_raw(str(clean_crew.get("z", "")))
	_check(not _saved_heist(turned_save).has("x") and not _saved_heist(clean_save).has("x"), "Persistent heist projection exposed clear private state.", failures)
	_check(turned_crew.keys() == clean_crew.keys(), "Clean and turned projections exposed different key sets.", failures)
	_check(turned_capsule.size() == CrewTurnModelScript.PRIVATE_SAVE_BYTES and clean_capsule.size() == CrewTurnModelScript.PRIVATE_SAVE_BYTES, "Clean and turned projections exposed different or non-fixed capsule sizes.", failures)
	_check(turned_capsule.slice(0, 16) != clean_capsule.slice(0, 16), "Independent clean and turned capsules reused an IV and became equality-comparable.", failures)
	_check(turned_capsule != clean_capsule, "Independent private capsules did not carry randomized semantic-security noise.", failures)
	_check(CrewTurnModelScript.valid_authority_id(str(turned_crew.get("a", ""))) and CrewTurnModelScript.valid_authority_id(str(clean_crew.get("a", ""))) and str(turned_crew.get("a", "")) != str(clean_crew.get("a", "")), "Independent runs did not receive distinct random authority ids.", failures)
	var turned_public := turned.crew_heist_snapshot()
	var clean_public := clean.crew_heist_snapshot()
	_check(JSON.stringify(turned_public) == JSON.stringify(clean_public) and not turned_public.has("x"), "Public heist snapshot distinguished clean and turned state.", failures)
	for save in [turned_save, clean_save]:
		var text := JSON.stringify(_without_private_capsule(save)).to_lower()
		for forbidden in ["\"m\":\"crew_", "traitor", "betrayal", "the_turn", "clue", CrewTurnModelScript.PRIVATE_KEY_PATH.to_lower()]:
			_check(not text.contains(forbidden), "Public save projection exposed private semantic/key marker '%s'." % forbidden, failures)
	var key_path := ProjectSettings.globalize_path(CrewTurnModelScript.PRIVATE_KEY_PATH)
	_check(FileAccess.file_exists(CrewTurnModelScript.PRIVATE_KEY_PATH) and FileAccess.get_file_as_bytes(key_path).size() == 32, "Per-install private authority key was not created as an external 256-bit secret.", failures)


func _check_zero_to_one_indistinguishability(failures: Array) -> void:
	var zero := RunStateScript.new()
	var one := RunStateScript.new()
	zero.start_new("WORLD06-7-ZERO-ONE", RunStateScript.standard_challenge("WORLD06-7-ZERO-ONE"))
	one.start_new("WORLD06-7-ZERO-ONE", RunStateScript.standard_challenge("WORLD06-7-ZERO-ONE"))
	one.grievance_add({"member_id": "crew_rook", "kind": "job_abandoned", "weight": 1, "source_ref": "private-source"})
	for projection in ["runtime", "persistent"]:
		var zero_save := zero.to_dict() if projection == "runtime" else zero.to_save_snapshot()
		var one_save := one.to_dict() if projection == "runtime" else one.to_save_snapshot()
		var zero_crew := _saved_crew(zero_save)
		var one_crew := _saved_crew(one_save)
		_check(zero_crew.keys() == one_crew.keys(), "%s zero/one grievance saves exposed different key classes." % projection, failures)
		_check(Marshalls.base64_to_raw(str(zero_crew.get("z", ""))).size() == CrewTurnModelScript.PRIVATE_SAVE_BYTES and Marshalls.base64_to_raw(str(one_crew.get("z", ""))).size() == CrewTurnModelScript.PRIVATE_SAVE_BYTES, "%s zero/one grievance saves exposed different byte classes." % projection, failures)
		_check(JSON.stringify(_without_private_capsule(zero_save)) == JSON.stringify(_without_private_capsule(one_save)), "%s zero/one grievance public projections were distinguishable." % projection, failures)


func _check_public_job_failure_projection(failures: Array) -> void:
	var first := RunStateScript.new()
	var second := RunStateScript.new()
	for run in [first, second]:
		run.start_new("WORLD06-7-JOB-TWIN", RunStateScript.standard_challenge("WORLD06-7-JOB-TWIN"))
		var capability: RefCounted = run.get("_crew_job_host_capability")
		var offered: Dictionary = run.job_offer(CrewStateModelScript.job_definition("rook_quiet_package"), capability)
		var job_id := str(offered.get("id", ""))
		run.job_accept(job_id, capability)
		run.job_activate(job_id, capability)
		var resolved: Dictionary = run.job_resolve(job_id, "failed", capability)
		_assert_job_surface_safe(resolved, "job_resolve result", failures)
		_assert_job_surface_safe(_saved_crew(run.to_save_snapshot()).get("jobs", {}), "saved jobs", failures)
	# Same public job history, deliberately different private continuation. The
	# observer has the authored definition id and outcome but no ledger selector.
	second.crew_grievance_ledger[0]["kind"] = "wrong_accusation"
	second.crew_grievance_ledger[0]["weight"] = 7
	second.crew_grievance_ledger[0]["source_ref"] = "different-private-source"
	var first_save := first.to_save_snapshot()
	var second_save := second.to_save_snapshot()
	_check(JSON.stringify(_without_private_capsule(first_save)) == JSON.stringify(_without_private_capsule(second_save)), "Same public failed-job history exposed different private grievance continuation.", failures)
	_check(Marshalls.base64_to_raw(str(_saved_crew(first_save).get("z", ""))).size() == Marshalls.base64_to_raw(str(_saved_crew(second_save).get("z", ""))).size(), "Same public failed-job history exposed a private length class.", failures)


func _check_grievance_producer_surfaces(failures: Array) -> void:
	# 1. Coordinated-play liability, consumed by the real heat boundary.
	var distraction := _plain_fixture("WORLD06-7-PRODUCER-DISTRACTION")
	# The liability originated at sequence 3; sequence 4 represents another play
	# occurring before heat lands. Save/load must not silently join it to play 4.
	distraction.crew_play_state = {"schema_version": 2, "uses": {"distraction": 1, "spotter": 1}, "member_cooldowns": {}, "active": [], "sequence": 4, "last_beat": {}, "distraction_liability": {"member_id": "crew_velvet", "until_action": 50, "source_ref": "crew_play:3", "recorded": false}, "tombstones": []}
	distraction.suspicion["level"] = 40
	var distraction_restored := RunStateScript.new()
	distraction_restored.from_dict(distraction.to_save_snapshot())
	distraction.add_suspicion("producer", 35)
	distraction_restored.add_suspicion("producer", 35)
	_check(_has_grievance(distraction, "distraction_heat_dumped"), "Production distraction heat route did not record its private grievance.", failures)
	_check(str(distraction.crew_grievance_ledger[0].get("source_ref", "")) == str(distraction_restored.crew_grievance_ledger[0].get("source_ref", "")), "Distraction grievance source changed after a later play plus save/load.", failures)
	_assert_run_surface_safe(distraction, "distraction heat", failures)

	# 2. Favor refusal, through the real debt conversion command.
	var favor := _plain_fixture("WORLD06-7-PRODUCER-FAVOR")
	favor.debt = [{"id": "crew-favor-private", "lender_id": "the_crew", "debt_kind": "favor", "balance": 2, "status": "active", "cash_conversion_balance_per_favor": 45, "cash_conversion_interest_rate": 0.35, "crew_member_ids": ["crew_rook"]}]
	var favor_result: Dictionary = favor.refuse_debt_favor("crew-favor-private")
	_check(bool(favor_result.get("ok", false)) and _has_grievance(favor, "favor_converted_unpaid"), "Production favor-refusal route did not record its private grievance.", failures)
	_assert_run_surface_safe(favor, "favor refusal", failures)

	# 3. Wrong-chair confrontation, through the host-owned confrontation seam.
	var confrontation := _plain_fixture("WORLD06-7-PRODUCER-CONFRONT")
	for member_id in CrewStateModelScript.MEMBER_IDS: confrontation.crew_trust_by_member[member_id] = 40
	confrontation.crew_heist_state = CrewHeistModelScript.begin(CrewHeistModelScript.PLAN_COUNT, 4)
	confrontation.crew_heist_state["x"] = _private("crew_switch", ["p", "r"], ["p", "r"])
	var confront_result: Dictionary = confrontation.crew_heist_confront("crew_lucky", confrontation.get("_crew_heist_host_capability"))
	_check(bool(confront_result.get("ok", false)) and _has_grievance(confrontation, "wrong_accusation"), "Production wrong-chair route did not record its private grievance.", failures)
	_assert_run_surface_safe(confrontation, "wrong confrontation", failures)

	# 4. Authored job failure, through offer/accept/activate/resolve.
	var job := _plain_fixture("WORLD06-7-PRODUCER-JOB")
	var job_capability: RefCounted = job.get("_crew_job_host_capability")
	var offered: Dictionary = job.job_offer(CrewStateModelScript.job_definition("rook_quiet_package"), job_capability)
	job.job_accept(str(offered.get("id", "")), job_capability)
	job.job_activate(str(offered.get("id", "")), job_capability)
	var job_result: Dictionary = job.job_resolve(str(offered.get("id", "")), "failed", job_capability)
	_check(_has_grievance(job, "job_abandoned"), "Production failed-job route did not record its private grievance.", failures)
	_assert_job_surface_safe(job_result, "production failed-job result", failures)
	_assert_run_surface_safe(job, "production failed job", failures)

	# 5. Stake-horse special loss choice, including its additional grievance.
	var stake := _plain_fixture("WORLD06-7-PRODUCER-STAKE")
	var stake_capability: RefCounted = stake.get("_crew_job_host_capability")
	var stake_offer: Dictionary = stake.job_offer(CrewStateModelScript.job_definition("mags_low_roller_stake"), stake_capability)
	var stake_id := str(stake_offer.get("id", ""))
	stake.job_accept(stake_id, stake_capability)
	stake.job_activate(stake_id, stake_capability)
	var stake_job: Dictionary = stake.crew_jobs.get(stake_id, {})
	var stake_payload: Dictionary = stake_job.get("payload", {})
	stake_payload["loss_choice_pending"] = true
	stake_job["payload"] = stake_payload
	stake.crew_jobs[stake_id] = stake_job
	var stake_result: Dictionary = stake.crew_resolve_stake_horse_loss("shrug")
	_check(bool(stake_result.get("ok", false)) and _has_grievance(stake, "stake_horse_loss_shrugged"), "Production stake-horse loss route did not record its private grievance.", failures)
	_assert_job_surface_safe(stake_result, "stake-horse result", failures)
	_assert_run_surface_safe(stake, "stake-horse loss", failures)

	# 6. Numbers past-post detection, through the production event applier.
	var numbers := _plain_fixture("WORLD06-7-PRODUCER-NUMBERS")
	numbers.crew_trust_by_member["crew_lucky"] = 1
	numbers.call("_apply_numbers_events", [{"type": "numbers_past_post_detected", "penalty": 10, "slip": {"id": "private-slip", "venue_id": "bar"}}])
	_check(_has_grievance(numbers, "numbers_past_posting_in_colors"), "Production Numbers detection route did not record its private grievance.", failures)
	_assert_run_surface_safe(numbers, "numbers detection", failures)

	# 7. Numbers collection abandonment, through the production delivery resolver.
	var delivery := _plain_fixture("WORLD06-7-PRODUCER-DELIVERY")
	delivery.active_delivery_run = {"status": "resolved", "world_applied": false, "run_id": "numbers_collection:private-run", "job_id": "", "mode": "multi_stop", "consumer_payload": {}, "resolution": {"outcome": "failed", "reason": "abandoned"}, "receipt": {}}
	var delivery_result: Dictionary = delivery.call("_apply_delivery_resolution", {}, false)
	_check(bool(delivery_result.get("ok", false)) and _has_grievance(delivery, "job_abandoned"), "Production Numbers collection-abandonment route did not record its private grievance.", failures)
	_assert_run_surface_safe(delivery, "numbers collection abandonment", failures)


func _check_round_trip_and_reseal(failures: Array) -> void:
	var source := _fixture("WORLD06-7-ROUNDTRIP")
	source.crew_heist_state["x"] = _private("crew_lucky", ["p"], ["p"], true, false, 2)
	var expected_private := JSON.stringify(source.crew_heist_state.get("x", {}))
	var expected_grievances := JSON.stringify(source.crew_grievance_ledger)
	var first := source.to_save_snapshot()
	var second := source.to_save_snapshot()
	_check(JSON.stringify(first) == JSON.stringify(second), "Unchanged private state churned its cached capsule across ordinary saves.", failures)
	var restored := RunStateScript.new()
	restored.from_dict(first)
	_check(JSON.stringify(restored.crew_heist_state.get("x", {})) == expected_private, "Authenticated private capsule did not restore exact continuation.", failures)
	_check(JSON.stringify(restored.crew_grievance_ledger) == expected_grievances and restored.crew_grievance_sequence == source.crew_grievance_sequence, "Authenticated private capsule did not restore the exact grievance ledger and sequence.", failures)
	_check(JSON.stringify(restored.to_save_snapshot()) == JSON.stringify(first), "Restored unchanged capsule did not re-save byte-identically.", failures)
	_check(restored.bankroll == source.bankroll and restored.rng_state == source.rng_state, "Private restore changed economy or canonical RNG state.", failures)
	var changed: Dictionary = restored.crew_heist_state.get("x", {}).duplicate(true)
	changed["h"] = false
	restored.crew_heist_state["x"] = changed
	var resealed := restored.to_save_snapshot()
	_check(str(_saved_crew(resealed).get("z", "")) != str(_saved_crew(first).get("z", "")), "An authoritative Turn mutation reused stale ciphertext.", failures)
	_check(JSON.stringify(resealed) == JSON.stringify(restored.to_save_snapshot()), "A freshly resealed private mutation did not become stable.", failures)
	var before_grievance_change := resealed
	restored.grievance_add({"member_id": "crew_mags", "kind": "wrong_accusation", "source_ref": "reseal"})
	var grievance_resealed := restored.to_save_snapshot()
	_check(str(_saved_crew(grievance_resealed).get("z", "")) != str(_saved_crew(before_grievance_change).get("z", "")), "A grievance mutation reused stale ciphertext.", failures)


func _check_hostile_capsules(failures: Array) -> void:
	var source := _fixture("WORLD06-7-HOSTILE")
	source.crew_heist_state["x"] = _private("crew_mags", ["r"], ["r"], false, true, 1)
	var save := source.to_save_snapshot()
	for byte_index in [0, 31, CrewTurnModelScript.PRIVATE_SAVE_BYTES - 1]:
		var tampered := save.duplicate(true)
		var crew := _saved_crew(tampered)
		var bytes := Marshalls.base64_to_raw(str(crew.get("z", "")))
		bytes[byte_index] = int(bytes[byte_index]) ^ 1
		crew["z"] = Marshalls.raw_to_base64(bytes)
		tampered["crew_state"] = crew
		var rejected := RunStateScript.new()
		rejected.from_dict(tampered)
		_check(str(rejected.crew_heist_state.get("status", "")) == CrewHeistModelScript.STATUS_ABORTED and str((rejected.crew_heist_state.get("x", {}) as Dictionary).get("m", "")) == "", "Tampered capsule byte %d did not fail closed as an explicit aborted heist." % byte_index, failures)
		_check(str(rejected.narrative_flags.get("crew_heist_private_restore_error", "")) == "private_authority_unavailable", "Tampered capsule byte %d failed silently instead of surfacing a safe restore error." % byte_index, failures)
		_check(rejected.bankroll == int(save.get("bankroll", -1)) and rejected.rng_state == int(save.get("rng_state", -1)), "Tampered capsule rejection changed economy or RNG.", failures)
	var missing_capsule := save.duplicate(true)
	var missing_crew := _saved_crew(missing_capsule)
	missing_crew.erase("z")
	missing_capsule["crew_state"] = missing_crew
	var missing_rejected := RunStateScript.new()
	missing_rejected.from_dict(missing_capsule)
	_check(str(missing_rejected.crew_heist_state.get("status", "")) == CrewHeistModelScript.STATUS_ABORTED and str(missing_rejected.narrative_flags.get("crew_private_authority_error", "")) == "private_authority_unavailable", "A partially missing private authority silently restarted the active heist.", failures)
	# Even identical seed/plan/action contexts get distinct per-run ids. Moving
	# only z while retaining the recipient id must fail authentication.
	var same_context := _fixture("WORLD06-7-HOSTILE").to_save_snapshot()
	var z_only := same_context.duplicate(true)
	var z_only_crew := _saved_crew(z_only)
	z_only_crew["z"] = str(_saved_crew(save).get("z", ""))
	z_only["crew_state"] = z_only_crew
	var z_only_rejected := RunStateScript.new()
	z_only_rejected.from_dict(z_only)
	_check(str(z_only_rejected.crew_heist_state.get("status", "")) == CrewHeistModelScript.STATUS_ABORTED, "Capsule-only transplant across same-context runs succeeded.", failures)
	# Moving both the id and capsule still fails when canonical public authority
	# (here trust) differs.
	var mismatched := _fixture("WORLD06-7-HOSTILE")
	mismatched.crew_trust_by_member["crew_rook"] = 9
	var token_and_capsule := mismatched.to_save_snapshot()
	var recipient_crew := _saved_crew(token_and_capsule)
	recipient_crew["a"] = str(_saved_crew(save).get("a", ""))
	recipient_crew["z"] = str(_saved_crew(save).get("z", ""))
	token_and_capsule["crew_state"] = recipient_crew
	var context_rejected := RunStateScript.new()
	context_rejected.from_dict(token_and_capsule)
	_check(str(context_rejected.crew_heist_state.get("status", "")) == CrewHeistModelScript.STATUS_ABORTED, "Authority-id plus capsule transplant across mismatched public context succeeded.", failures)


func _check_capacity_failure(failures: Array) -> void:
	var source := _fixture("WORLD06-7-CAPACITY")
	for index in range(CrewTurnModelScript.PRIVATE_GRIEVANCE_LIMIT - 1):
		source.crew_grievance_ledger.append({"id": "g%04d" % (index + 2), "member_id": "crew_rook", "kind": "wrong_accusation", "weight": 1, "turn_recorded": 8, "source_ref": "capacity"})
	source.crew_grievance_sequence = source.crew_grievance_ledger.size()
	var exact_limit := source.to_save_snapshot()
	var exact_crew := _saved_crew(exact_limit)
	var exact_restored := RunStateScript.new()
	exact_restored.from_dict(exact_limit)
	_check(Marshalls.base64_to_raw(str(exact_crew.get("z", ""))).size() == CrewTurnModelScript.PRIVATE_SAVE_BYTES \
			and exact_restored.crew_grievance_ledger.size() == CrewTurnModelScript.PRIVATE_GRIEVANCE_LIMIT \
			and exact_restored.crew_grievance_sequence == CrewTurnModelScript.PRIVATE_GRIEVANCE_LIMIT, "The exact 256-entry grievance capacity did not fit and round-trip.", failures)
	source.crew_grievance_ledger.append({"id": "g0257", "member_id": "crew_rook", "kind": "wrong_accusation", "weight": 1, "turn_recorded": 8, "source_ref": "capacity"})
	source.crew_grievance_sequence += 1
	var refused := source.to_save_snapshot()
	var crew := _saved_crew(refused)
	_check(str(crew.get("private_authority_error", "")) == "private_authority_capacity_exceeded" and not crew.has("z"), "Oversize grievance authority was truncated or silently serialized.", failures)
	var rejected := RunStateScript.new()
	rejected.from_dict(refused)
	_check(str(rejected.crew_heist_state.get("status", "")) == CrewHeistModelScript.STATUS_ABORTED and str(rejected.narrative_flags.get("crew_private_authority_error", "")) == "private_authority_unavailable", "Capacity failure did not restore as an explicit safe terminal state.", failures)
	var direct := _fixture("WORLD06-7-TEXT-CAPACITY")
	var result := direct.grievance_add({"member_id": "crew_rook", "kind": "wrong_accusation", "source_ref": "x".repeat(CrewTurnModelScript.PRIVATE_TEXT_BYTE_LIMIT + 1)})
	_check(not bool(result.get("ok", true)) and str(result.get("reason", "")) == "private_authority_capacity_exceeded" and direct.crew_grievance_ledger.size() == 1, "Oversize grievance text was not rejected atomically.", failures)


func _check_legacy_migration(failures: Array) -> void:
	var source := _fixture("WORLD06-7-LEGACY")
	source.crew_heist_state["x"] = _private("crew_switch", ["p"], ["p"], false, false, 0)
	var legacy_private: Dictionary = (source.crew_heist_state.get("x", {}) as Dictionary).duplicate(true)
	legacy_private["v"] = CrewTurnModelScript.LEGACY_STATE_VERSION
	legacy_private.erase("t")
	var legacy := source.to_save_snapshot()
	var legacy_crew := _saved_crew(legacy)
	legacy_crew.erase("a")
	legacy_crew.erase("z")
	legacy_crew["grievances"] = source.crew_grievance_ledger.duplicate(true)
	legacy_crew["grievance_sequence"] = source.crew_grievance_sequence
	var legacy_heist := _saved_heist(legacy)
	legacy_heist["schema_version"] = CrewHeistModelScript.LEGACY_STATE_SCHEMA_VERSION
	legacy_heist.erase("q")
	legacy_heist["x"] = legacy_private
	legacy_crew["crew_heist"] = legacy_heist
	legacy["crew_state"] = legacy_crew
	var restored := RunStateScript.new()
	restored.from_dict(legacy)
	_check(str((restored.crew_heist_state.get("x", {}) as Dictionary).get("m", "")) == "crew_switch", "Actual v1/no-q legacy private state did not restore.", failures)
	var migrated := restored.to_save_snapshot()
	_check(_saved_crew(migrated).has("z") and not _saved_heist(migrated).has("x") and int(_saved_heist(migrated).get("schema_version", 0)) == CrewHeistModelScript.STATE_SCHEMA_VERSION, "Legacy clear private state did not migrate to the current authenticated capsule.", failures)
	# The immediately preceding 512-byte x-only capsule also remains readable.
	var old_capsule_save := legacy.duplicate(true)
	var old_crew := _saved_crew(old_capsule_save)
	old_crew.erase("grievances")
	old_crew.erase("grievance_sequence")
	old_crew["g"] = [[2, 0, 8, 4, "6730303031", "666978747572655f6a6f62"]]
	old_crew["q"] = 1
	var old_heist := legacy_heist.duplicate(true)
	old_heist.erase("x")
	var old_binding := CrewTurnModelScript.legacy_private_save_binding(source.seed_text, str(old_heist.get("plan_id", "")), int(old_heist.get("locked_action", 0)))
	old_heist["z"] = CrewTurnModelScript.pack_legacy_private_save(legacy_private, CrewStateModelScript.MEMBER_IDS, old_binding)
	old_crew["crew_heist"] = old_heist
	old_capsule_save["crew_state"] = old_crew
	var old_restored := RunStateScript.new()
	old_restored.from_dict(old_capsule_save)
	_check(str((old_restored.crew_heist_state.get("x", {}) as Dictionary).get("m", "")) == "crew_switch" and old_restored.crew_grievance_ledger.size() == 1, "Shipped 512-byte heist capsule and packed grievance migration failed.", failures)
	var old_migrated := old_restored.to_save_snapshot()
	_check(_saved_crew(old_migrated).has("z") and not _saved_heist(old_migrated).has("z") and Marshalls.base64_to_raw(str(_saved_crew(old_migrated).get("z", ""))).size() == CrewTurnModelScript.PRIVATE_SAVE_BYTES, "Shipped capsule did not migrate to the unified private authority format.", failures)


func _fixture(seed: String) -> RunState:
	var run := RunStateScript.new()
	run.start_new(seed, RunStateScript.standard_challenge(seed))
	for member_id in CrewStateModelScript.MEMBER_IDS:
		run.crew_trust_by_member[member_id] = 40
	run.event_cadence["action_index"] = 7
	run.crew_grievance_ledger = [{"id": "g0001", "member_id": "crew_switch", "kind": "job_abandoned", "weight": 8, "turn_recorded": 4, "source_ref": "fixture_job"}]
	run.crew_grievance_sequence = 1
	run.crew_heist_state = CrewHeistModelScript.begin(CrewHeistModelScript.PLAN_COUNT, 7)
	return run


func _private(member_id: String, emitted: Array = [], witnessed: Array = [], hedged: bool = false, cancelled: bool = false, escalation: int = 0) -> Dictionary:
	return {"v": CrewTurnModelScript.STATE_VERSION, "m": member_id, "w": witnessed.duplicate(), "e": emitted.duplicate(), "h": hedged, "c": cancelled, "f": escalation, "t": [{"b": 9, "q": 2}]}


func _plain_fixture(seed: String) -> RunState:
	var run := RunStateScript.new()
	run.start_new(seed, RunStateScript.standard_challenge(seed))
	return run


func _without_private_capsule(snapshot: Dictionary) -> Dictionary:
	var result := snapshot.duplicate(true)
	var crew := _saved_crew(result)
	crew.erase("a")
	crew.erase("z")
	result["crew_state"] = crew
	return result


func _has_grievance(run: RunState, kind: String) -> bool:
	for entry_value in run.crew_grievance_ledger:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("kind", "")) == kind:
			return true
	return false


func _assert_job_surface_safe(value: Variant, label: String, failures: Array) -> void:
	var text := JSON.stringify(value).to_lower()
	for forbidden in ["grievance_kind", "grievance_weight", "\"g\":", "job_abandoned", "wrong_accusation", "stake_horse_loss_shrugged"]:
		_check(not text.contains(forbidden), "%s exposed grievance payload marker '%s'." % [label, forbidden], failures)


func _assert_run_surface_safe(run: RunState, label: String, failures: Array) -> void:
	for snapshot in [run.to_dict(), run.to_save_snapshot()]:
		var crew := _saved_crew(snapshot)
		_check(crew.has("a") and crew.has("z") and not crew.has("g") and not crew.has("q") and not crew.has("grievances") and not crew.has("grievance_sequence"), "%s did not serialize only fixed private authority." % label, failures)
		_assert_job_surface_safe(crew.get("jobs", {}), "%s jobs" % label, failures)


func _saved_heist(snapshot: Dictionary) -> Dictionary:
	var crew := _saved_crew(snapshot)
	return (crew.get("crew_heist", {}) as Dictionary).duplicate(true) if typeof(crew.get("crew_heist", {})) == TYPE_DICTIONARY else {}


func _saved_crew(snapshot: Dictionary) -> Dictionary:
	return (snapshot.get("crew_state", {}) as Dictionary).duplicate(true) if typeof(snapshot.get("crew_state", {})) == TYPE_DICTIONARY else {}


func _check(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append(message)
