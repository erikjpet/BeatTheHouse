extends SceneTree

const CYCLE := "environment_situation_cycle_id"
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var library := ContentLibrary.new()
	library.load(false)
	var generator := RunGenerator.new(library)
	var state := RunState.new()
	state.start_new("LAYER-SITUATION-CYCLE")
	var generated: Dictionary = generator.environment_test_result(state, {"archetype_id": "small_underground_casino", "scenario_id": "__none"})
	_check(bool(generated.get("ok", false)) and state.is_layered_environment(), "The production practice factory must create the layered Punchline fixture.")
	if not bool(generated.get("ok", false)):
		_finish()
		return
	var first_cycle: String = generator._environment_situation_cycle_id(state, "small_underground_casino")
	state.current_environment[CYCLE] = first_cycle
	var cash := state.bankroll
	var rng := state.rng_state
	var layer: Dictionary = state.environment_layer_state("casino")
	_check(state.install_environment_layer_state("casino", layer), "The ordinary layer-state boundary must install the casino floor.")
	_check(str(state.current_environment.get(CYCLE, "")) == first_cycle, "Entering a layer must retain the venue's operating-cycle stamp.")
	_check(state.bankroll == cash and state.rng_state == rng, "A layer metadata handoff must not change money or RNG.")
	var restored := RunState.new()
	restored.from_dict(state.to_dict())
	_check(str(restored.current_environment.get(CYCLE, "")) == first_cycle, "The layer cycle stamp must survive RunState persistence.")
	var legacy := state.current_environment.duplicate(true)
	legacy.erase(CYCLE)
	legacy["layer_states"] = {"club": {"archetype_id": "small_underground_casino", "world_node_id": "small_underground_casino", CYCLE: first_cycle}}
	var before := JSON.stringify(legacy)
	_check(generator._stored_environment_matches_situation_cycle(state, "small_underground_casino", legacy), "A missing top-level stamp must retain same-cycle saved layer progress.")
	state.advance_game_clock_minutes(1440)
	_check(not generator._stored_environment_matches_situation_cycle(state, "small_underground_casino", legacy), "An old sibling-layer stamp must expire the old cached room in the next venue cycle.")
	_check(JSON.stringify(legacy) == before, "Cycle lookup must not mutate cached room or sibling-layer state.")
	var today: String = generator._environment_situation_cycle_id(state, "small_underground_casino")
	var current := legacy.duplicate(true)
	current[CYCLE] = today
	_check(generator._stored_environment_matches_situation_cycle(state, "small_underground_casino", current), "The authoritative current-room stamp must take precedence over older layer snapshots.")
	var unknown := legacy.duplicate(true)
	unknown["layer_states"] = {}
	_check(generator._stored_environment_matches_situation_cycle(state, "small_underground_casino", unknown), "A legacy room with no cycle evidence must retain existing compatibility behavior.")
	var foreign := unknown.duplicate(true)
	foreign["layer_states"] = {"other": {"archetype_id": "jazz_club", "world_node_id": "jazz_club", CYCLE: first_cycle}}
	_check(generator._stored_environment_matches_situation_cycle(state, "small_underground_casino", foreign), "A foreign venue's layer must not supply expiry authority.")
	var ambiguous := legacy.duplicate(true)
	ambiguous["layer_states"]["other"] = {"archetype_id": "small_underground_casino", "world_node_id": "small_underground_casino", CYCLE: today}
	_check(generator._stored_environment_matches_situation_cycle(state, "small_underground_casino", ambiguous), "Conflicting legacy stamps must not silently discard room progress.")
	var guarded := RunState.new()
	guarded.start_new("LAYER-CYCLE-IDENTITY-GUARD")
	generator.next_environment(guarded)
	var canonical: Dictionary = library._scenario_readonly("punchline_open_mic_night")
	guarded.seed_scenario_for_node("small_underground_casino", canonical)
	guarded.remember_environment_situation_cycle("small_underground_casino", today, "punchline_open_mic_night")
	var guarded_before := JSON.stringify(guarded.to_dict())
	var rejected: Dictionary = generator._trusted_scenario_install_data(guarded, {"id": "bad-room", "archetype_id": "small_underground_casino", "world_node_id": "small_underground_casino", "scenario_id": "punchline_bringer_show"})
	_check(not bool(rejected.get("ok", true)), "An unrelated caller-carried scenario must still fail the exact seeded-identity guard.")
	_check(JSON.stringify(guarded.to_dict()) == guarded_before, "A rejected install must preserve the authoritative run.")
	_finish()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	print("LAYER_SITUATION_CYCLE_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
