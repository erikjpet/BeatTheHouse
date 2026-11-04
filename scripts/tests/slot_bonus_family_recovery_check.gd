extends SceneTree

# Synthetic producer states, never a captured player save. Family loss changes
# only the redundant tag; recorded machine, feature header and payload stay exact.
# Renderer signatures below describe projections, not actual canvas/pointer play.
const Slot := preload("res://scripts/games/slot.gd")
const State := preload("res://scripts/games/slots/slot_machine_state.gd")
const Generator := preload("res://scripts/games/slots/slot_machine_generator.gd")
const Pinball := preload("res://scripts/games/slots/slot_family_pinball.gd")
const Buffalo := preload("res://scripts/games/slots/slot_family_buffalo.gd")
const Feature := preload("res://scripts/games/slots/pinball/pinball_feature.gd")
const PinballSim := preload("res://scripts/games/slots/pinball/pinball_sim.gd")
const Renderer := preload("res://scripts/games/slots/slot_renderer.gd")
const Library := preload("res://scripts/core/content_library.gd")
const Saves := preload("res://scripts/core/save_service.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
const SaveCodec := preload("res://scripts/core/run_save_codec.gd")
const Main := preload("res://scripts/ui/foundation_main.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const FORMATS := ["classic_3_reel", "line_5x3", "video_feature"]
const TAGS := ["canonical", "missing", "empty"]

class FailingAdvanceHost extends Main:
	var failures_remaining := 1
	func _sealed_action_host_advance_environment_turn(candidate: RunState) -> Dictionary:
		if failures_remaining > 0:
			failures_remaining -= 1
			return {"ok": false, "error_code": "forced_turn_rejection", "failure_stage": "slot_family_recovery"}
		return super._sealed_action_host_advance_environment_turn(candidate)

var checks := 0
var failures: Array[String] = []
var facts: Array = []
var library
var definition: Dictionary = {}
var completed := false
var private_root := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _private_roots():
		_finish()
		return
	library = Library.new()
	library.load()
	definition = library.game("slot")
	if not _check(not definition.is_empty(), "authored Slot definition loads"):
		_finish()
		return
	for format_id in FORMATS:
		_check_tag_matrix("pinball", str(format_id), "pinball")
		for entry_class in ["free_games", "hold_and_spin", "monster_feature"]:
			_check_tag_matrix("buffalo", str(format_id), str(entry_class))
			_check_buffalo_owned_parity(str(format_id), str(entry_class))
		_check_durable_matrix(str(format_id), false)
		_check_durable_matrix(str(format_id), true)
		_check_scalar_cold_matrix(str(format_id), false)
		_check_scalar_cold_matrix(str(format_id), true)
		_check_invalid_authority(str(format_id))
		for tag in ["missing", "empty"]:
			_check_pending_raw_protection(str(format_id), str(tag), false)
			_check_pending_raw_protection(str(format_id), str(tag), true)
	for tag in TAGS:
		_check_pending_family(str(tag), false)
		_check_pending_family(str(tag), true)
	_check_item_capsule()
	Feature.clear_runtime_session_cache()
	completed = true
	_finish()


func _fixture(family: String, format_id: String, entry_class: String) -> Dictionary:
	var run := RunState.new()
	run.start_new("SLOT-FAMILY-RECOVERY:%s:%s:%s" % [family, format_id, entry_class])
	run.bankroll = 100000
	run.grand_casino_chips = 25
	run.set_environment({"id": "slot_family_recovery", "archetype_id": "bar", "kind": "casino", "game_ids": ["slot"], "game_states": {}, "economic_profile": {"stake_floor": 2, "stake_ceiling": 60}, "security_profile": {"risk": "loose"}})
	var machine: Dictionary = Generator.new().build_machine_from_ids(definition, {"format_id": format_id, "type_id": family, "math_variant_id": "standard", "bonus_variant_id": "plain", "cabinet_variant_id": "neon_magenta"}, run.create_rng("recorded_machine"))
	machine = State.set_selected_bet(machine, "bet_10")
	var active: Dictionary
	if family == "pinball":
		active = Pinball.new().open_feature(machine, 10, run.create_rng("recorded_feature"), definition)
	else:
		active = Buffalo.new().open_feature(machine, {"classification": entry_class}, 10, run.create_rng("recorded_feature"), definition)
	machine["active_bonus"] = active
	machine["slot_animation_id"] = ""
	machine["slot_bonus_trigger_revealed"] = true
	State.write_machine(run.current_environment, "slot", machine)
	return {"run": run, "machine": State.peek_machine(run.current_environment, "slot").duplicate(true), "runtime": Feature.runtime_transaction_checkpoint(active) if family == "pinball" else {}}


func _check_tag_matrix(family: String, format_id: String, entry_class: String) -> void:
	var fixture := _fixture(family, format_id, entry_class)
	var canonical_surface: Dictionary = {}
	var canonical_machine: Dictionary = fixture.machine
	var label := "%s/%s/%s" % [family, format_id, entry_class]
	for tag in TAGS:
		Feature.clear_runtime_session_cache()
		var run := RunState.new()
		run.from_dict(fixture.run.to_dict())
		var machine := canonical_machine.duplicate(true)
		var active: Dictionary = machine.active_bonus
		if tag == "missing":
			active.erase("family")
		elif tag == "empty":
			active["family"] = ""
		_check(_without_family(machine) == _without_family(canonical_machine), label + "/" + tag + " changes only family")
		State.write_machine(run.current_environment, "slot", machine)
		# Exercise accepted raw missing tags as well as normalized explicit empty.
		if tag == "missing":
			run.current_environment.game_states.slot.active_bonus.erase("family")
		if family == "pinball":
			_check(Feature.restore_runtime_transaction_checkpoint(active, fixture.runtime), label + "/" + tag + " restores identical warm producer runtime")
		var game := Slot.new()
		game.setup(definition, library)
		var before := _economy_guard(run)
		var stored_before := State.peek_machine(run.current_environment, "slot").duplicate(true)
		var surface: Dictionary = game.surface_state(run, run.current_environment, {"surface_time_msec": 1000})
		var manifest: Dictionary = Renderer.new().render_signature(surface, definition, 1000, "feature")
		var shown: Dictionary = surface.get("slot_active_bonus", {})
		_check(not bool(surface.get("slot_bonus_recovery_required", false)), label + "/" + tag + " valid tag-only state needs no recovery prompt")
		_check(str(shown.get("family", "")) == family and str(shown.get("mode", "")) == str(canonical_machine.active_bonus.mode), label + "/" + tag + " uses recorded native family and mode")
		_check(bool(surface.get("slot_active_bonus_active", false)), label + "/" + tag + " retains active feature")
		if family == "pinball":
			_check(bool(manifest.get("pinball_takeover_active", false)) and str(manifest.get("pinball_controls_mode", "")) == "launch", label + "/" + tag + " reaches current native prelaunch controls")
		var projection := _projection(surface, manifest)
		if tag == "canonical":
			canonical_surface = projection
		else:
			_check(_fingerprint(projection) == _fingerprint(canonical_surface), label + "/" + tag + " projection equals unchanged canonical authority")
		_check(_economy_guard(run) == before, label + "/" + tag + " query preserves wallets RNG clocks action counters and history")
		_check(_without_family(State.peek_machine(run.current_environment, "slot")) == _without_family(stored_before), label + "/" + tag + " query preserves every recorded non-tag machine field")
		var repeated: Dictionary = game.surface_state(run, run.current_environment, {"surface_time_msec": 1000})
		_check(_fingerprint(_projection(repeated, Renderer.new().render_signature(repeated, definition, 1000, "feature"))) == _fingerprint(projection), label + "/" + tag + " repeated query is idempotent")
		_check(_economy_guard(run) == before, label + "/" + tag + " repeated query does not transact")
		facts.append({"case": label, "tag": tag, "mode": shown.get("mode", ""), "family": shown.get("family", ""), "native_takeover": manifest.get("pinball_takeover_active", false), "recovery_required": surface.get("slot_bonus_recovery_required", false), "projection": _fingerprint(projection)})


func _projection(surface: Dictionary, manifest: Dictionary) -> Dictionary:
	var result := {}
	for key in ["slot_cabinet_identity", "slot_active_bonus_active", "slot_active_bonus", "slot_feature_scene", "slot_bonus_total", "slot_bonus_steps", "slot_bonus_recovery_required", "slot_bonus_recovery_message"]:
		result[key] = surface.get(key, null)
	for key in ["pinball_takeover_active", "pinball_controls_mode", "pinball_launch_control_visible", "pinball_in_play_controls_visible", "pinball_aim_choice_count", "pinball_power_choice_count"]:
		result[key] = manifest.get(key, null)
	return result


func _without_family(machine: Dictionary) -> Dictionary:
	var copy := machine.duplicate(true)
	var active: Dictionary = copy.get("active_bonus", {})
	active.erase("family")
	return copy


func _economy_guard(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "seed": str(run.rng_seed), "rng": str(run.rng_state), "clock": run.game_clock_minutes, "simulation_msec": run.simulation_msec, "town": run.town_state.snapshot() if run.town_state != null else {}, "history": run.story_log.duplicate(true), "environment_turns": run.current_environment.get("turns", 0)}


func _fingerprint(value: Variant) -> String:
	return Runtime.canonical_fingerprint(value)


func _private_roots() -> bool:
	private_root = OS.get_environment("BTH_SLOT_FAMILY_PRIVATE_ROOT").replace("\\", "/").simplify_path()
	if not _check(private_root.is_absolute_path() and "native-private-" in private_root, "explicit disposable native root required"):
		return false
	for key in ["APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == private_root.to_lower() or path.begins_with(private_root.to_lower() + "/"), "private containment for " + key):
			return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no captured player save or browser profile accepted")


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok


func _finish() -> void:
	_check(completed, "requested matrix reaches final assertion")
	var report := {"id": "BTH061-AUDIT-SLOT-LEGACY-FAMILY-004", "stage": "family-authority-save-retry", "checks": checks, "failures": failures, "facts": facts, "source_sha256": {"slot": FileAccess.get_sha256("res://scripts/games/slot.gd"), "state": FileAccess.get_sha256("res://scripts/games/slots/slot_machine_state.gd"), "presentation": FileAccess.get_sha256("res://scripts/games/slots/slot_presentation.gd"), "recovery": FileAccess.get_sha256("res://scripts/games/slots/slot_bonus_recovery.gd"), "feature": FileAccess.get_sha256("res://scripts/games/slots/pinball/pinball_feature.gd"), "sim": FileAccess.get_sha256("res://scripts/games/slots/pinball/pinball_sim.gd"), "test": FileAccess.get_sha256("res://scripts/tests/slot_bonus_family_recovery_check.gd")}, "fidelity": "Synthetic public family producers, unchanged recorded payloads, official SaveService, cold-cache durable and scalar paths, current module projections, renderer signatures and authentic sealed-host retry/cancel/failed-publication seams. Cache-cleared same-process recovery; no independent-process restart, original save, actual canvas draw, pointer gameplay or v1 opaque-payload provenance claim."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print("SLOT_BONUS_FAMILY_RECOVERY_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func _check_durable_matrix(format_id: String, midflight: bool) -> void:
	var fixture := _fixture("pinball", format_id, "pinball")
	var producer: RunState = fixture.run
	var game := Slot.new()
	game.setup(definition, library)
	var machine: Dictionary = fixture.machine
	if midflight:
		var launch: Dictionary = Pinball.new().step_bonus(machine, "slot_bonus_launch", producer.create_rng("recorded_launch"), definition, {"surface_time_msec": 1000})
		var live: Dictionary = launch.get("active_bonus", {})
		live = Feature.surface_refresh(live, 1032)
		machine["active_bonus"] = live
		_check(int(live.get("active_ball_count", 0)) > 0, format_id + " midflight fixture has a genuinely launched live ball")
		State.write_machine(producer.current_environment, "slot", machine)
	game.checkpoint_surface_ui_state_for_save({}, producer, producer.current_environment)
	machine = State.peek_machine(producer.current_environment, "slot").duplicate(true)
	var durable: Dictionary = machine.active_bonus.get(Feature.DURABLE_RUNTIME_KEY, {})
	if not _check(str(durable.get("schema", "")) == Feature.DURABLE_RUNTIME_SCHEMA and not str(durable.get("payload", "")).is_empty(), format_id + " producer emits existing v1 durable authority"):
		return
	var stage := "durable-midflight" if midflight else "durable-prelaunch"
	var canonical_projection := ""
	for tag in TAGS:
		var run := RunState.new()
		run.from_dict(producer.to_dict())
		_install_tag(run, machine, str(tag))
		var loaded := _save_load(run, "%s_%s_%s" % [stage, format_id, tag])
		if loaded == null:
			continue
		Feature.clear_runtime_session_cache()
		var stored := State.peek_machine(loaded.current_environment, "slot").duplicate(true)
		var saved_active: Dictionary = stored.active_bonus
		var saved_durable: Dictionary = saved_active.get(Feature.DURABLE_RUNTIME_KEY, {})
		var label := "%s/%s/%s" % [format_id, stage, tag]
		_check(saved_durable == durable, label + " official save preserves exact object-free v1 solver payload")
		var before := _economy_guard(loaded)
		var surface: Dictionary = game.surface_state(loaded, loaded.current_environment, {"surface_time_msec": 10})
		var shown: Dictionary = surface.get("slot_active_bonus", {})
		var manifest: Dictionary = Renderer.new().render_signature(surface, definition, 10, "feature")
		_check(not bool(surface.get("slot_bonus_recovery_required", false)) and str(shown.get("family", "")) == "pinball", label + " valid v1 is accepted with current family presentation")
		_check(bool(manifest.get("pinball_takeover_active", false)), label + " cold-cache official load reaches native takeover")
		var status := Feature.live_status(shown)
		if _check(Feature.runtime_session_cache_size() == 1 and bool(status.get("runtime_active", false)), label + " surface restored the one recorded runtime before inspection"):
			var restored := Feature.runtime_transaction_checkpoint(shown)
			_check(Marshalls.variant_to_base64(restored.get("sim", {}), false) == str(durable.get("payload", "")), label + " first query restores every solver array counter and RNG bit without advancing physics")
		var projection := _fingerprint(_projection(surface, manifest))
		if tag == "canonical":
			canonical_projection = projection
		else:
			_check(projection == canonical_projection, label + " tag-only loss is equivalent to canonical durable recovery")
		var patch: Dictionary = game.surface_realtime_state_patch(loaded, loaded.current_environment, {"surface_time_msec": 42}, surface)
		var next_active: Dictionary = patch.get("slot_active_bonus", shown)
		var next_status := Feature.live_status(next_active)
		if midflight:
			_check(int(status.get("active_ball_count", 0)) > 0 and int(next_status.get("tick", 0)) > int(status.get("tick", 0)), label + " restored live solver progresses with a new process-relative clock origin")
		else:
			_check(int(status.get("active_ball_count", -1)) == 0 and str(manifest.get("pinball_controls_mode", "")) == "launch", label + " durable prelaunch remains prelaunch")
		_check(not shown.has(Feature.DURABLE_RUNTIME_KEY) and not next_active.has(Feature.DURABLE_RUNTIME_KEY), label + " presentation patches do not copy durable authority")
		_check(_economy_guard(loaded) == before and _without_family(State.peek_machine(loaded.current_environment, "slot")) == _without_family(stored), label + " restore and presentation preserve money RNG clocks history and recorded non-tag machine")
		facts.append({"case": label, "cache": "cleared in same process before official-load surface", "schema": saved_durable.get("schema", ""), "payload_sha256": str(saved_durable.get("payload", "")).sha256_text(), "before_tick": status.get("tick", 0), "after_tick": next_status.get("tick", 0), "active_balls": status.get("active_ball_count", 0), "exact_live_physics_claimed": true})


func _check_scalar_cold_matrix(format_id: String, midflight: bool) -> void:
	var fixture := _fixture("pinball", format_id, "pinball")
	var producer: RunState = fixture.run
	var machine: Dictionary = fixture.machine
	if midflight:
		var launch: Dictionary = Pinball.new().step_bonus(machine, "slot_bonus_launch", producer.create_rng("scalar_launch"), definition, {"surface_time_msec": 1000})
		machine["active_bonus"] = Feature.surface_refresh(launch.get("active_bonus", {}), 1032)
	State.write_machine(producer.current_environment, "slot", machine)
	machine = State.peek_machine(producer.current_environment, "slot").duplicate(true)
	_check(not machine.active_bonus.has(Feature.DURABLE_RUNTIME_KEY) and (int(machine.active_bonus.get("active_ball_count", 0)) > 0) == midflight, format_id + " scalar-only fixture has recorded header and expected live marker but no solver payload")
	var stage := "scalar-midflight" if midflight else "scalar-between-launches"
	var canonical_projection := ""
	for tag in TAGS:
		var run := RunState.new()
		run.from_dict(producer.to_dict())
		_install_tag(run, machine, str(tag))
		var loaded := _save_load(run, "%s_%s_%s" % [stage, format_id, tag])
		if loaded == null:
			continue
		Feature.clear_runtime_session_cache()
		var game := Slot.new()
		game.setup(definition, library)
		var stored := State.peek_machine(loaded.current_environment, "slot").duplicate(true)
		var before := _economy_guard(loaded)
		var surface: Dictionary = game.surface_state(loaded, loaded.current_environment, {"surface_time_msec": 10})
		var manifest: Dictionary = Renderer.new().render_signature(surface, definition, 10, "feature")
		var projection := _fingerprint(_projection(surface, manifest))
		var label := "%s/%s/%s" % [format_id, stage, tag]
		if tag == "canonical":
			canonical_projection = projection
			_check(not bool(surface.get("slot_bonus_recovery_required", false)), label + " explicit canonical legacy scalar compatibility remains accepted")
		elif midflight:
			_check(bool(surface.get("slot_bonus_recovery_required", false)) and not str(surface.get("slot_bonus_recovery_message", "")).strip_edges().is_empty() and Feature.runtime_session_cache_size() == 0, label + " lost tag with live scalar summary but no solver authority needs recovery without inventing physics")
		else:
			_check(projection == canonical_projection, label + " uses the same supported scalar compatibility policy as canonical identity")
		_check(_economy_guard(loaded) == before and _without_family(State.peek_machine(loaded.current_environment, "slot")) == _without_family(stored), label + " preserves every recorded scalar award and progress field without settlement")
		var again: Dictionary = game.surface_state(loaded, loaded.current_environment, {"surface_time_msec": 10})
		_check(_fingerprint(_projection(again, Renderer.new().render_signature(again, definition, 10, "feature"))) == projection, label + " repeated fallback or recovery query is idempotent")
		facts.append({"case": label, "cache": "cleared in same process", "durable_payload_present": false, "runtime_cache_size": Feature.runtime_session_cache_size(), "recovery_required": surface.get("slot_bonus_recovery_required", false), "exact_live_physics_claimed": false})


func _check_invalid_authority(format_id: String) -> void:
	var fixture := _fixture("pinball", format_id, "pinball")
	var canonical: Dictionary = fixture.machine
	var sim: Dictionary = fixture.runtime.get("sim", {})
	var incomplete_sim := sim.duplicate(true)
	incomplete_sim.erase("positions")
	var changes := [
		{"id": "missing-mode", "erase": "mode"},
		{"id": "unknown-mode", "set": {"mode": "unrecorded_mode"}},
		{"id": "missing-seed", "erase": "runtime_seed"},
		{"id": "missing-session", "erase": "runtime_session_id"},
		{"id": "missing-board", "erase": "board_id"},
		{"id": "conflicting-family", "set": {"family": "buffalo"}},
		{"id": "conflicting-board", "set": {"board_id": "foreign_recorded_board"}},
		{"id": "wrong-durable-schema", "durable": {"schema": "unknown_runtime", "payload": Marshalls.variant_to_base64(sim, false)}},
		{"id": "empty-durable-payload", "durable": {"schema": Feature.DURABLE_RUNTIME_SCHEMA, "payload": ""}},
		{"id": "scalar-durable-payload", "durable": {"schema": Feature.DURABLE_RUNTIME_SCHEMA, "payload": Marshalls.variant_to_base64(7, false)}},
		{"id": "incomplete-durable-solver", "durable": {"schema": Feature.DURABLE_RUNTIME_SCHEMA, "payload": Marshalls.variant_to_base64(incomplete_sim, false)}},
		{"id": "completed-canonical", "set": {"family": "pinball", "complete": true}},
		{"id": "completed-empty-family", "set": {"complete": true}},
		{"id": "completed-unknown-family", "set": {"family": "unknown_saved_family", "complete": true}},
		{"id": "completed-visual-canonical", "set": {"family": "pinball", "complete": true, "visual_replay": true}},
		{"id": "inactive-visual-canonical", "set": {"family": "pinball", "active": false, "complete": true, "visual_replay": true}},
	]
	for change in changes:
		Feature.clear_runtime_session_cache()
		var run := RunState.new()
		run.from_dict(fixture.run.to_dict())
		var machine := canonical.duplicate(true)
		var active: Dictionary = machine.active_bonus
		active["family"] = ""
		if change.has("erase"):
			active.erase(str(change.erase))
		for key in change.get("set", {}):
			active[key] = change.set[key]
		if change.has("durable"):
			active[Feature.DURABLE_RUNTIME_KEY] = change.durable.duplicate(true)
		State.write_machine(run.current_environment, "slot", machine)
		var game := Slot.new()
		game.setup(definition, library)
		var before := _economy_guard(run)
		var raw_before := State.peek_machine(run.current_environment, "slot").duplicate(true)
		var label := "%s/recovery/%s" % [format_id, change.id]
		var surface: Dictionary = game.surface_state(run, run.current_environment, {"surface_time_msec": 1000})
		_check(bool(surface.get("slot_bonus_recovery_required", false)) and not str(surface.get("slot_bonus_recovery_message", "")).strip_edges().is_empty(), label + " exposes truthful recovery-required message")
		_check(Feature.runtime_session_cache_size() == 0, label + " does not manufacture a physics session from incomplete authority")
		for action in ["slot_bonus_launch", "slot_bonus_left", "slot_bonus_start_00", "slot_spin", "slot_auto_toggle"]:
			var command: Dictionary = game.surface_action_command(str(action), 0, false, {"surface_time_msec": 1000}, run, run.current_environment)
			_check(not bool(command.get("resolve", false)) and not bool(command.get("direct_resolve", false)), label + " blocks interactive command " + str(action))
		var owned_machine := raw_before.duplicate(true)
		var denied_rng := run.create_rng("denied_owned_bonus")
		var denied_rng_before := denied_rng.snapshot()
		var owned: Dictionary = game.resolver.resolve_bonus_action_owned(owned_machine, "slot_bonus_launch", denied_rng, definition, run.current_environment, run, {}, {"surface_time_msec": 1000})
		var owned_result: Dictionary = owned.get("result", {})
		_check(not bool(owned_result.get("ok", true)) and not bool(owned_result.get("host_apply_result", true)), label + " direct owned resolver explicitly rejects recovery without an apply receipt")
		_check(owned.get("machine", {}) == raw_before and denied_rng.snapshot() == denied_rng_before, label + " owned rejection preserves every input field and RNG bit")
		_check(_economy_guard(run) == before and State.peek_machine(run.current_environment, "slot") == raw_before, label + " recovery observation and denied controls preserve complete recorded authority")
		_check(Feature.runtime_session_cache_size() == 0, label + " denied inputs never create a solver")
		facts.append({"case": label, "recovery_required": surface.get("slot_bonus_recovery_required", false), "message": surface.get("slot_bonus_recovery_message", ""), "runtime_cache_size": Feature.runtime_session_cache_size(), "arbitrary_valid_payload_swap_authentication_claimed": false})


func _install_tag(run: RunState, canonical: Dictionary, tag: String) -> void:
	var machine := canonical.duplicate(true)
	var active: Dictionary = machine.active_bonus
	if tag == "missing":
		active.erase("family")
	elif tag == "empty":
		active["family"] = ""
	_check(_without_family(machine) == _without_family(canonical), tag + " save variant changes only family")
	State.write_machine(run.current_environment, "slot", machine)
	if tag == "missing":
		run.current_environment.game_states.slot.active_bonus.erase("family")


func _save_load(run: RunState, suffix: String) -> RunState:
	var slot_id := "slot_bonus_family_" + suffix.replace("-", "_")
	var service := Saves.new()
	var before := _all_guard(run)
	if not _check(service.save_run(run, slot_id) == OK, suffix + " official SaveService writes disposable fixture"):
		return null
	_check(_all_guard(run) == before, suffix + " official save leaves live run unchanged")
	var loaded: Variant = service.load_run(slot_id)
	service.clear_run(slot_id)
	if not _check(loaded is RunState, suffix + " official SaveService loads fixture"):
		return null
	# The codec may normalize only the missing redundant family tag; all remaining
	# state and numeric transport representation must survive the official codec.
	_check(_persistent_fingerprint(_codec_guard_without_family(loaded)) == _persistent_fingerprint(_codec_guard_without_family(run)), suffix + " official codec preserves wallets RNG clocks all history and every non-tag non-definition cabinet field")
	return loaded as RunState


func _all_guard(run: RunState) -> Dictionary:
	var result := _economy_guard(run)
	result["all_game_states"] = run.current_environment.get("game_states", {}).duplicate(true)
	result["active_game_state_keys"] = run.current_environment.get("active_game_state_keys", {}).duplicate(true)
	return result


func _codec_guard_without_family(run: RunState) -> Dictionary:
	var result := _all_guard(run)
	var states: Dictionary = result.all_game_states
	# The official codec deliberately omits only these regenerable definition /
	# duplicate timeline arrays. Preserve every other machine and unknown key.
	for state_key in states:
		if str(state_key) != "slot" and not str(state_key).begins_with("slot:"):
			continue
		if typeof(states[state_key]) != TYPE_DICTIONARY:
			continue
		var machine: Dictionary = states[state_key]
		for key in SaveCodec.SLOT_DEFINITION_KEYS + SaveCodec.SLOT_DUPLICATE_PRESENTATION_KEYS:
			machine.erase(key)
		if str(state_key) == "slot":
			states[state_key] = _without_family(machine)
	return result


func _persistent_fingerprint(value: Variant) -> String:
	return _fingerprint(JSON.parse_string(JSON.stringify(value)))


func _check_item_capsule() -> void:
	var fixture := _fixture("pinball", "classic_3_reel", "pinball")
	var producer: RunState = fixture.run
	var machine: Dictionary = fixture.machine
	Feature.clear_runtime_session_cache()
	var feature := Feature.new()
	var rng := producer.create_rng("recorded_item_feature")
	var active: Dictionary = feature.open(machine, "em_bumper_drop", 10, rng, {"ball_budget": 3, "cap": 100, "bet_id": "bet_10", "item_effects": {"slot_pinball_bumper_battery_hits": 3, "slot_pinball_bumper_battery_award_percent": 40, "slot_pinball_bumper_battery_kick_percent": 130, "slot_pinball_bumper_battery_up_impulse": 18}})
	var sim = Feature._session_for_static(active)
	if not _check(sim != null, "item capsule fixture reads its existing producer runtime without creating a replacement"):
		return
	# Use the simulation's real event primitive, then let the normal public step
	# consume that event and execute its actual item hook once. This is not a
	# collision-driven end-to-end fixture and assigns no award/counter scalars.
	sim._register_event(PinballSim.EVENT_BUMPER, 1000, 0, 5, Vector2(0.5, 0.5))
	machine["active_bonus"] = active
	var step: Dictionary = feature.step(machine, "slot_bonus_tilt", rng, definition, {"surface_time_msec": 1000})
	active = step.get("active_bonus", {})
	var durable := Feature.durable_runtime_checkpoint(active)
	var decoded: Variant = Marshalls.base64_to_variant(str(durable.get("payload", "")), false)
	if not _check(typeof(decoded) == TYPE_DICTIONARY, "real item source emits a genuine object-free v1 solver capsule"):
		return
	_check(int(decoded.get("total_awarded", -1)) == 7 and int(decoded.get("gross_awarded", -1)) == 5 and int(decoded.get("bumper_battery_hits_remaining", -1)) == 3, "event primitive plus real hook produces total7 gross5 without consuming collision-only battery capacity")
	_check(int(active.get("bumper_battery_used", -1)) == 1 and active.get("pinball_item_hooks", []) == [{"item": "slot_pinball_bumper_battery", "hook": "charged_bumper", "award": 2}], "public feature step applies exactly one recorded charged-bumper hook")
	active[Feature.DURABLE_RUNTIME_KEY] = durable
	machine["active_bonus"] = active
	State.write_machine(producer.current_environment, "slot", machine)
	machine = State.peek_machine(producer.current_environment, "slot").duplicate(true)
	var canonical_projection := ""
	for tag in TAGS:
		var run := RunState.new()
		run.from_dict(producer.to_dict())
		_install_tag(run, machine, str(tag))
		var loaded := _save_load(run, "item_capsule_" + str(tag))
		if loaded == null:
			continue
		Feature.clear_runtime_session_cache()
		var game := Slot.new()
		game.setup(definition, library)
		var before := _economy_guard(loaded)
		var raw := State.peek_machine(loaded.current_environment, "slot").duplicate(true)
		var surface: Dictionary = game.surface_state(loaded, loaded.current_environment, {"surface_time_msec": 10})
		var shown: Dictionary = surface.get("slot_active_bonus", {})
		var manifest: Dictionary = Renderer.new().render_signature(surface, definition, 10, "feature")
		var label := "item-capsule/" + str(tag)
		_check(not bool(surface.get("slot_bonus_recovery_required", false)) and bool(manifest.get("pinball_takeover_active", false)), label + " accepts genuine v1 item awards where total exceeds gross")
		if _check(bool(Feature.live_status(shown).get("runtime_active", false)), label + " restores its existing recorded solver authority"):
			var checkpoint := Feature.runtime_transaction_checkpoint(shown)
			_check(Marshalls.variant_to_base64(checkpoint.get("sim", {}), false) == str(durable.get("payload", "")), label + " official save and cold-cache surface preserve the exact item-hook solver state")
		var projection := _fingerprint(_projection(surface, manifest))
		if tag == "canonical":
			canonical_projection = projection
		else:
			_check(projection == canonical_projection, label + " tag-only loss preserves the canonical item-capsule projection")
		_check(_economy_guard(loaded) == before and _without_family(State.peek_machine(loaded.current_environment, "slot")) == _without_family(raw), label + " restoration pays nothing and preserves every recorded non-tag field")
		facts.append({"case": label, "source": "real simulation event primitive consumed by public feature step and actual item hook; no collision claim", "total_awarded": decoded.get("total_awarded", -1), "gross_awarded": decoded.get("gross_awarded", -1), "battery_remaining": decoded.get("bumper_battery_hits_remaining", -1), "battery_used": active.get("bumper_battery_used", -1), "item_hooks": active.get("pinball_item_hooks", []).duplicate(true), "payload_sha256": str(durable.get("payload", "")).sha256_text()})


func _check_pending_raw_protection(format_id: String, tag: String, with_durable: bool) -> void:
	Feature.clear_runtime_session_cache()
	var fixture := _fixture("pinball", format_id, "pinball")
	var run: RunState = fixture.run
	var machine: Dictionary = fixture.machine
	if with_durable:
		var launch: Dictionary = Pinball.new().step_bonus(machine, "slot_bonus_launch", run.create_rng("pending_raw_launch"), definition, {"surface_time_msec": 1000})
		machine["active_bonus"] = Feature.surface_refresh(launch.get("active_bonus", {}), 1032)
		_check(int(machine.active_bonus.get("active_ball_count", 0)) > 0, format_id + " raw protection durable fixture contains a real live ball")
		machine.active_bonus[Feature.DURABLE_RUNTIME_KEY] = Feature.durable_runtime_checkpoint(machine.active_bonus)
	# Only presentation timing is synthetic. Match the finite channel exactly so
	# an unguarded checkpoint would write its elapsed offset, and let the normal
	# reveal calculation yield the board without latching the raw pending model.
	var animation_id := "spin:pending-family:" + format_id
	machine["slot_animation_id"] = animation_id
	machine["slot_animation_started_msec"] = 1000
	machine["slot_animation_duration_msec"] = 1600
	machine["slot_animation_plan"] = {"duration_msec": 1600, "reel_timeline": [{"reel_index": 0, "settle_end": 0.4}]}
	machine["slot_bonus_trigger_revealed"] = false
	machine.erase("slot_animation_resume_elapsed_msec")
	_install_tag(run, machine, tag)
	var suffix := "%s_%s_%s" % [format_id, tag, "durable" if with_durable else "warm"]
	run = _save_load(run, "pending_raw_base_" + suffix)
	if run == null:
		return
	var game := Slot.new()
	game.setup(definition, library)
	var bound_machine: Dictionary = game.definition_cache.owned_runtime_machine(State.peek_machine(run.current_environment, "slot").duplicate(true))
	State.write_runtime_machine(run.current_environment, "slot", bound_machine)
	var host = _new_host(game, run, false)
	if host == null:
		return
	var command: Dictionary = host.call("_sealed_action_host_surface_intent", "slot_bonus_left" if with_durable else "slot_bonus_launch", 0, false, 1100)
	var delivery: Dictionary = command.get("_sealed_action_host_delivery", {})
	var label := "pending-raw/" + suffix
	if not _check(bool(command.get("handled", false)) and not delivery.is_empty(), label + " normal surface seals authentic pending bonus input"):
		host.free()
		return
	var raw := State.peek_machine(run.current_environment, "slot").duplicate(true)
	var raw_bytes := Marshalls.variant_to_base64(raw, false)
	var before := _economy_guard(run)
	_check(str(raw.active_bonus.get("family", "")).is_empty() and not bool(raw.get("slot_bonus_trigger_revealed", true)), label + " pending source still has lost family and an unlatched trigger")
	_check(raw.active_bonus.has(Feature.DURABLE_RUNTIME_KEY) == with_durable and not raw.has("slot_animation_resume_elapsed_msec"), label + " source capsule and finite checkpoint presence are deliberate")
	var ui := {"surface_time_msec": 1100, "surface_runtime_status": {"surface_animations": {"slot_spin": {"active_id": animation_id, "active": true, "elapsed": 1.0}}}}
	var surface: Dictionary = game.surface_state(run, run.current_environment, ui)
	var manifest: Dictionary = Renderer.new().render_signature(surface, definition, 1100, "feature")
	_check(bool(manifest.get("pinball_takeover_active", false)) and not bool(surface.get("slot_bonus_trigger_reveal_pending", true)), label + " after-reveal full view uses the current native board")
	_check(Marshalls.variant_to_base64(State.peek_machine(run.current_environment, "slot"), false) == raw_bytes, label + " full query preserves every raw pending field and exact capsule bytes")
	var next_ui := ui.duplicate(true)
	next_ui["surface_time_msec"] = 1132
	var patch: Dictionary = game.surface_realtime_state_patch(run, run.current_environment, next_ui, surface)
	var combined := surface.duplicate(true)
	combined.merge(patch, true)
	_check(bool(Renderer.new().render_signature(combined, definition, 1132, "feature").get("pinball_takeover_active", false)), label + " realtime projection retains native takeover")
	_check(Marshalls.variant_to_base64(State.peek_machine(run.current_environment, "slot"), false) == raw_bytes, label + " realtime reveal never latches or replaces sealed raw authority")
	game.checkpoint_surface_ui_state(ui, run, run.current_environment)
	_check(Marshalls.variant_to_base64(State.peek_machine(run.current_environment, "slot"), false) == raw_bytes, label + " matching finite animation checkpoint cannot change pending elapsed fields")
	game.checkpoint_surface_ui_state_for_save(ui, run, run.current_environment)
	_check(Marshalls.variant_to_base64(State.peek_machine(run.current_environment, "slot"), false) == raw_bytes, label + " save checkpoint cannot add replace or erase sealed durable authority")
	_check(_economy_guard(run) == before, label + " projections and save checkpoints preserve wallets RNG clocks account progress and history")
	var loaded := _save_load(run, "pending_raw_" + suffix)
	_check(Marshalls.variant_to_base64(State.peek_machine(run.current_environment, "slot"), false) == raw_bytes, label + " official save leaves the complete live pending machine byte-identical")
	if loaded != null:
		host.run_state = loaded
		var loaded_before := _full_fingerprint(loaded)
		var loaded_runtime := _runtime_fingerprint(loaded)
		var candidate: RunState = host.call("_sealed_action_host_detached")
		var context: Dictionary = host.call("_sealed_action_host_trusted_context", candidate, int(delivery.stake), str(delivery.action_id))
		var context_matches := _fingerprint(context) == str(delivery.get("trusted_context_fingerprint", ""))
		var before_preview: Dictionary = host.call("_sealed_action_host_prepare_delivery", str(delivery.action_id), int(delivery.stake), delivery)
		_check((context_matches and bool(before_preview.get("ok", false)) and before_preview.get("delivery", {}) == delivery) or (not context_matches and not bool(before_preview.get("ok", true)) and str(before_preview.get("error_code", "")) == "receipt_content_conflict"), label + " preflight strictly honors the original recorded context before normal Retry binding")
		_check(_full_fingerprint(loaded) == loaded_before and _runtime_fingerprint(loaded) == loaded_runtime, label + " observing pre-Retry delivery never changes account model runtime or original receipt")
		var expected_preview := _expected_main_retry_snapshot(loaded, game)
		var retry: Dictionary = host.call("_sealed_action_host_surface_intent", "slot_retry_pending", 0, false, 10)
		_check(bool(retry.get("handled", false)) and retry.get("_sealed_action_host_delivery", {}) == delivery, label + " actual Main Retry returns the exact original envelope")
		_check(_full_fingerprint(loaded) == _fingerprint(expected_preview) and _runtime_fingerprint(loaded) == loaded_runtime, label + " actual Main Retry performs only its full expected production binding")
		loaded_before = _full_fingerprint(loaded)
		var prepared: Dictionary = host.call("_sealed_action_host_prepare_delivery", str(delivery.action_id), int(delivery.stake), delivery)
		_check(bool(prepared.get("ok", false)) and prepared.get("delivery", {}) == delivery, label + " original pending context still validates after presentation checkpoint and official load")
		_check(_full_fingerprint(loaded) == loaded_before, label + " observing the existing prepared delivery never rewrites or reseals it")
	facts.append({"case": label, "authority": "existing valid durable midflight" if with_durable else "existing warm between-launch runtime without capsule", "raw_machine_sha256": raw_bytes.sha256_text(), "request_key": delivery.get("request_key", ""), "finite_animation_id": animation_id, "finite_elapsed_msec": 1000, "stored_trigger_revealed": State.peek_machine(run.current_environment, "slot").get("slot_bonus_trigger_revealed", true)})
	host.free()


func _check_pending_family(tag: String, reject_turn: bool) -> void:
	var fixture := _fixture("pinball", "classic_3_reel", "pinball")
	var run: RunState = fixture.run
	var machine: Dictionary = fixture.machine
	machine.active_bonus[Feature.DURABLE_RUNTIME_KEY] = Feature.durable_runtime_checkpoint(machine.active_bonus)
	_install_tag(run, machine, tag)
	# Start from an officially restored account before sealing. A fresh synthetic
	# zero-suspicion room otherwise gains its first recorded local level on load,
	# changing the existing authority context independently of family recovery.
	run = _save_load(run, "pending_base_%s_%s" % [tag, "retry" if reject_turn else "cancel"])
	if run == null:
		return
	# Use the real runtime writer before the protected baseline: it removes the
	# derived pinball_view that a producer snapshot legitimately still contains.
	var game := Slot.new()
	game.setup(definition, library)
	var bound_machine: Dictionary = game.definition_cache.owned_runtime_machine(State.peek_machine(run.current_environment, "slot").duplicate(true))
	State.write_runtime_machine(run.current_environment, "slot", bound_machine)
	game.surface_state(run, run.current_environment, {"surface_time_msec": 1000})
	var before := _all_guard(run)
	var before_machine := _without_ledger(State.peek_machine(run.current_environment, "slot"))
	var runtime_before := _runtime_fingerprint(run)
	var host = _new_host(game, run, false)
	if host == null:
		return
	var command: Dictionary = host.call("_sealed_action_host_surface_intent", "slot_bonus_launch", 0, false, 1000)
	var delivery: Dictionary = command.get("_sealed_action_host_delivery", {})
	var label := "pending/%s/%s" % [tag, "forced-failure-retry" if reject_turn else "cancel"]
	if not _check(bool(command.get("handled", false)) and bool(command.get("direct_resolve", false)) and not delivery.is_empty(), label + " normal current launch intent seals an authentic durable delivery"):
		host.free()
		return
	_check(_economy_guard(run) == _economy_guard_from_all(before) and _without_ledger(State.peek_machine(run.current_environment, "slot")) == before_machine and _runtime_fingerprint(run) == runtime_before, label + " staging delivery does not settle or advance feature physics")
	host.free()
	var loaded := _save_load(run, "pending_%s_%s" % [tag, "retry" if reject_turn else "cancel"])
	if loaded == null:
		return
	Feature.clear_runtime_session_cache()
	game.surface_state(loaded, loaded.current_environment, {"surface_time_msec": 10})
	# Normal production Retry first binds the restored machine. The derived host
	# exists only later at the deliberate failure seam, never as a substitute for
	# Main's actual cold-request preflight.
	host = _new_host(game, loaded, false)
	if host == null:
		return
	var ledger := _ledger(loaded)
	_check(ledger.get("pending_delivery", {}) == delivery, label + " official load retains the exact sealed pending delivery")
	var pending_before := _full_fingerprint(loaded)
	var expected_preview_snapshot := _expected_main_retry_snapshot(loaded, game)
	var pending_revision := int(loaded.current_environment.get("environment_runtime_revision", -1))
	var pending_runtime := _runtime_fingerprint(loaded)
	var retry: Dictionary = host.call("_sealed_action_host_surface_intent", "slot_retry_pending", 0, false, 10)
	_check(bool(retry.get("handled", false)) and bool(retry.get("direct_resolve", false)) and bool(retry.get("skip_stake_validation", false)) and retry.get("_sealed_action_host_delivery", {}) == delivery and int(retry.get("set_stake", -1)) == int(delivery.get("stake", -2)), label + " explicit retry preview returns the original sealed action stake and envelope")
	_check(int(loaded.current_environment.get("environment_runtime_revision", -1)) == pending_revision + 1, label + " Main preview performs exactly its existing one render revision increment")
	_check(_full_fingerprint(loaded) == _fingerprint(expected_preview_snapshot) and _runtime_fingerprint(loaded) == pending_runtime, label + " Main preview equals the complete expected production binding and preserves exact runtime")
	# The unchanged original envelope is now ready for settlement. Protect this
	# actual normal preflight boundary exactly through cancellation or rollback.
	pending_before = _full_fingerprint(loaded)
	pending_runtime = _runtime_fingerprint(loaded)
	if reject_turn:
		host.free()
		host = _new_host(game, loaded, true)
		if host == null:
			return
	if not reject_turn:
		var economic_before := _economy_guard(loaded)
		var machine_before := _without_ledger(State.peek_machine(loaded.current_environment, "slot"))
		var cancelled: Dictionary = host.call("_sealed_action_host_surface_intent", "slot_cancel_pending", 0, false, 10)
		var after := _ledger(loaded)
		_check(bool(cancelled.get("handled", false)) and (after.get("pending_delivery", {}) as Dictionary).is_empty() and (after.get("pending_recovery_session", {}) as Dictionary).is_empty(), label + " explicit cancel clears both pending authority fields")
		_check(after.get("session", {}) == ledger.get("pending_recovery_session", {}) and after.get("request_cache", {}) == ledger.get("request_cache", {}) and after.get("journal", []) == ledger.get("journal", []) and after.get("boundary_ordinal", -1) == ledger.get("boundary_ordinal", -2) and after.get("next_request_ordinal", -1) == ledger.get("next_request_ordinal", -2), label + " cancel restores prior session while retaining settled history and issued ordinals")
		_check(_economy_guard(loaded) == economic_before and _without_ledger(State.peek_machine(loaded.current_environment, "slot")) == machine_before and _runtime_fingerprint(loaded) == pending_runtime, label + " cancel preserves wallets global progress complete feature and runtime")
		var canceled_before := _full_fingerprint(loaded)
		var stale: Dictionary = host.call("_sealed_action_host_resolve_intent", str(delivery.action_id), int(delivery.stake), delivery)
		_check(not bool(stale.get("ok", true)) and str(stale.get("error_code", "")) == "stale_boundary", label + " cancelled envelope cannot later launch or settle")
		_check(_full_fingerprint(loaded) == canceled_before and _runtime_fingerprint(loaded) == pending_runtime, label + " stale replay leaves complete run and runtime unchanged")
	else:
		var rejected: Dictionary = host.call("_sealed_action_host_resolve_intent", str(delivery.action_id), int(delivery.stake), delivery)
		_check(not bool(rejected.get("ok", true)) and str(rejected.get("error_code", "")) == "forced_turn_rejection", label + " supported publish-boundary rejection seam is actually reached")
		_check(_full_fingerprint(loaded) == pending_before and _runtime_fingerprint(loaded) == pending_runtime and _ledger(loaded).get("pending_delivery", {}) == delivery, label + " failed publication rolls back feature and solver while preserving exact retry authority")
		var preview: Dictionary = host.call("_sealed_action_host_surface_intent", "slot_retry_pending", 0, false, 10)
		_check(preview.get("_sealed_action_host_delivery", {}) == delivery, label + " failed delivery remains explicitly retryable")
		var cash_before := loaded.bankroll
		var chips_before := loaded.grand_casino_chips
		var turns_before := int(loaded.current_environment.get("turns", 0))
		var state_before := State.peek_machine(loaded.current_environment, "slot").duplicate(true)
		var receipts_before := _bonus_receipts(loaded)
		var accepted: Dictionary = host.call("_sealed_action_host_resolve_intent", str(delivery.action_id), int(delivery.stake), delivery)
		var state_after := State.peek_machine(loaded.current_environment, "slot")
		_check(bool(accepted.get("ok", false)) and int(state_after.active_bonus.get("active_ball_count", 0)) > 0, label + " explicit retry commits one real native launch")
		_check(loaded.bankroll == cash_before and loaded.grand_casino_chips == chips_before and int(state_after.get("coin_in", 0)) == int(state_before.get("coin_in", 0)) and int(state_after.get("spin_count", 0)) == int(state_before.get("spin_count", 0)), label + " zero-cost bonus retry never places a second paid wager")
		_check(_bonus_receipts(loaded) == receipts_before + 1 and int(loaded.current_environment.get("turns", 0)) == turns_before + 1 and (_ledger(loaded).get("pending_delivery", {}) as Dictionary).is_empty(), label + " accepted retry publishes one bonus receipt and one normal turn")
		var accepted_before := _full_fingerprint(loaded)
		var accepted_runtime := _runtime_fingerprint(loaded)
		var replay: Dictionary = host.call("_sealed_action_host_resolve_intent", str(delivery.action_id), int(delivery.stake), delivery)
		var replay_content := replay.duplicate(true)
		var original_content := accepted.duplicate(true)
		replay_content.erase("blackjack_host_replay")
		original_content.erase("blackjack_host_replay")
		_check(bool(replay.get("ok", false)) and replay.has("blackjack_host_replay") and _fingerprint(replay_content) == _fingerprint(original_content), label + " exact envelope replay returns the original cached response")
		_check(_full_fingerprint(loaded) == accepted_before and _runtime_fingerprint(loaded) == accepted_runtime, label + " cached replay never launches pays records or advances twice")
	facts.append({"case": label, "delivery_request_key": delivery.get("request_key", ""), "recorded_stake": delivery.get("stake", -1), "automatic_pending_recovery_claimed": false})
	host.free()


func _new_host(game, run: RunState, fail_turn: bool):
	var host = FailingAdvanceHost.new() if fail_turn else Main.new()
	for stage in [0, 4, 10, 12]:
		if not _check(bool(host.call("_ensure_run_ui_stage_scripts", stage)), "normal host collaborator stage %d loads" % stage):
			host.free()
			return null
	host.library = library
	host.current_game = game
	host.game_module_cache = {"slot": game}
	host.run_state = run
	host.selected_stake = 10
	return host


func _ledger(run: RunState) -> Dictionary:
	return State.peek_machine(run.current_environment, "slot").get(Authority.LEDGER_KEY, {}).duplicate(true)


func _without_ledger(machine: Dictionary) -> Dictionary:
	# An accepted intent may persist the redundant family repair and compact the
	# same four regenerable arrays as the official codec. Every other feature and
	# machine field remains protected alongside the separate runtime guard.
	var copy := _without_family(machine)
	copy.erase(Authority.LEDGER_KEY)
	copy.erase(Authority.PENDING_APPLY_RECEIPT_KEY)
	for key in SaveCodec.SLOT_DEFINITION_KEYS + SaveCodec.SLOT_DUPLICATE_PRESENTATION_KEYS:
		copy.erase(key)
	return copy


func _economy_guard_from_all(value: Dictionary) -> Dictionary:
	var copy := value.duplicate(true)
	copy.erase("all_game_states")
	copy.erase("active_game_state_keys")
	return copy


func _full_fingerprint(run: RunState) -> String:
	return _fingerprint(run.to_save_snapshot())


func _runtime_fingerprint(run: RunState) -> String:
	var active: Dictionary = State.peek_machine(run.current_environment, "slot").get("active_bonus", {})
	return Marshalls.variant_to_base64(Feature.runtime_transaction_checkpoint(active), false).sha256_text()


func _bonus_receipts(run: RunState) -> int:
	var count := 0
	for value in run.story_log:
		if typeof(value) == TYPE_DICTIONARY and str(value.get("game_id", "")) == "slot" and str(value.get("slot_event", "")) == "slot_bonus_step":
			count += 1
	return count


func _check_buffalo_owned_parity(format_id: String, entry_class: String) -> void:
	var fixture := _fixture("buffalo", format_id, entry_class)
	var original: Dictionary = fixture.machine
	var source_rng: RngStream = fixture.run.create_rng("paired_buffalo_owned_step")
	var start_rng: Dictionary = source_rng.snapshot()
	var canonical_machine: Dictionary = {}
	var canonical_result: Dictionary = {}
	var canonical_rng: Dictionary = {}
	var mode := str(original.active_bonus.mode)
	var action := "slot_bonus_left" if mode == "wheel" else "slot_bonus_launch"
	for tag in TAGS:
		var run := RunState.new()
		run.from_dict(fixture.run.to_dict())
		_install_tag(run, original, str(tag))
		var owned := State.peek_machine(run.current_environment, "slot").duplicate(true)
		_check(_without_family(owned) == _without_family(original), "Buffalo paired producer differs only in family tag")
		var rng := RngStream.new()
		rng.restore(start_rng)
		var game := Slot.new()
		game.setup(definition, library)
		var before := _economy_guard(run)
		var raw := State.peek_machine(run.current_environment, "slot").duplicate(true)
		var effects: Dictionary = game.call("_slot_cross_game_item_effects", run, owned, false)
		var resolved: Dictionary = game.resolver.resolve_bonus_action_owned(owned, action, rng, definition, run.current_environment, run, effects, {"surface_time_msec": 1000})
		var result: Dictionary = resolved.get("result", {})
		var after_machine: Dictionary = resolved.get("machine", {})
		var label := "buffalo-owned/%s/%s/%s" % [format_id, mode, tag]
		_check(bool(result.get("ok", false)) and not after_machine.is_empty(), label + " one actual supported owned bonus step is admitted")
		if tag == "canonical":
			canonical_machine = after_machine.duplicate(true)
			canonical_result = result.duplicate(true)
			canonical_rng = rng.snapshot()
		else:
			_check(after_machine == canonical_machine, label + " entire output machine equals paired canonical producer step")
			_check(result == canonical_result, label + " entire result equals paired canonical producer step")
			_check(rng.snapshot() == canonical_rng, label + " exact post-step RNG equals paired canonical producer step")
		_check(_economy_guard(run) == before and State.peek_machine(run.current_environment, "slot") == raw, label + " owned proposal never applies to live money clocks history or cabinet")
		facts.append({"case": label, "action": action, "machine_fingerprint": _fingerprint(after_machine), "result_fingerprint": _fingerprint(result), "rng_fingerprint": _fingerprint(rng.snapshot()), "oracle": "whole paired actual canonical resolver output with normal wrapper-derived effects; no handwritten outcome or paytable"})


func _expected_main_retry_snapshot(run: RunState, game, state_key: String = "slot") -> Dictionary:
	# Build the full expected model using the same existing production APIs as
	# Main's one ledger store. Never normalize an authority hash or old delivery,
	# and never omit a field from the expected account/machine snapshot.
	var expected := run.to_save_snapshot().duplicate(true)
	var environment: Dictionary = expected.current_environment
	var owned: Dictionary = game.definition_cache.owned_runtime_machine(State.peek_machine(environment, state_key).duplicate(true))
	State.write_runtime_machine(environment, state_key, owned)
	return expected
