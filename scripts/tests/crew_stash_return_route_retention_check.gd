extends SceneTree

const Generator := preload("res://scripts/core/run_generator.gd")
const Host := preload("res://scripts/ui/foundation_main.gd")
const Travel := preload("res://scripts/ui/foundation_travel_view_model.gd")
const Interaction := preload("res://scripts/ui/environment_interaction_controller.gd")
const Map := preload("res://scripts/core/world_map.gd")
const SOURCE := "back_alley"
const STASH := "small_underground_casino"
const ORDINARY := ["bar", "kitty_cat_lounge", "pawn_shop"]

# Detached projection fixtures only: no delivery acceptance, authority, save or
# gameplay actions. The real map, route generator and route-status gates run.
class ProjectionRun:
	extends "res://scripts/core/run_state.gd"
	var projected_delivery: Dictionary = {}
	func delivery_has_active_run() -> bool:
		return str(projected_delivery.get("status", "")) == "active"
	func delivery_snapshot() -> Dictionary:
		return projected_delivery.duplicate(true)

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _node(id: String) -> Dictionary:
	return {"id":id, "archetype_id":id, "state":"visited", "seen":true}

func _edge(a: String, b: String, blocks: int, cost: int) -> Dictionary:
	return {"a":a, "b":b, "distance_blocks":blocks, "cost":cost, "base_cost":cost, "travel_method_kind":"bus"}

func _delivery(state: String = "stashed", node_id: String = STASH) -> Dictionary:
	return {
		"run_id":"synthetic-stash-route", "status":"active", "deadline_remaining":12,
		"delivered_count":0, "handoff_pending_node_id":"",
		"physical":{"cargo_state":state, "cargo_node_id":node_id, "cargo_kind":"numbers_slips"},
		"targets":[{"node_id":"bar", "status":"pending"}, {"node_id":"kitty_cat_lounge", "status":"pending"}],
	}

func _fixture() -> Variant:
	var run := ProjectionRun.new()
	run.start_new("SYNTHETIC-CREW-STASH-ROUTE")
	run.bankroll = 100
	run.current_environment = {"id":SOURCE, "archetype_id":SOURCE, "world_node_id":SOURCE, "turns":3}
	run.world_map = Map.normalize_topology({
		"start_node_id":SOURCE, "current_node_id":SOURCE,
		"visited_path":[SOURCE, STASH, "bar", "kitty_cat_lounge", "pawn_shop"],
		"nodes":[_node(SOURCE), _node("bar"), _node("kitty_cat_lounge"), _node("pawn_shop"), _node(STASH)],
		"edges":[_edge(SOURCE,"bar",1,3), _edge(SOURCE,"kitty_cat_lounge",2,4), _edge(SOURCE,"pawn_shop",3,5), _edge(SOURCE,STASH,10,7)],
	})
	run.projected_delivery = _delivery()
	var host := Host.new()
	# Main normally loads these delegates during its run-UI ready stages. This
	# detached fixture mounts no UI, so bind the same real scripts explicitly.
	host.FoundationTravelViewModelScript = Travel
	host.EnvironmentInteractionControllerScript = Interaction
	host.run_state = run
	host.library = ContentLibrary.new()
	host.library.travel_routes = [{"id":STASH, "cost":7, "method":"Bus Ticket", "travel_method_kind":"bus"}]
	host.generator = Generator.new(host.library)
	return host

func _state(host: Variant) -> String:
	return JSON.stringify({"run":host.run_state.to_dict(), "delivery":host.run_state.delivery_snapshot()})

func _retain(host: Variant, ordinary: Array, label: String, cap: int = 3) -> Array:
	var before := _state(host)
	var input_before := JSON.stringify(ordinary)
	var result: Array = Travel._retain_delivery_next_hops(host, ordinary, cap)
	_expect(_state(host) == before and JSON.stringify(ordinary) == input_before, label + ": projection changes no run, cargo, map, cash, RNG, clock, debt or input choices")
	return result

func _run() -> void:
	var host: Variant = _fixture()
	var run: ProjectionRun = host.run_state
	var ordinary: Array = Map.travel_target_ids(run.world_map, SOURCE, 2, 3, ORDINARY + [STASH])
	_expect(ordinary.size() == 3 and not ordinary.has(STASH), "real map cap reproduces a visible recovery route crowded out by ordinary stops")
	_expect(Map.path_between(run.world_map, SOURCE, STASH, true) == [SOURCE, STASH], "recovery uses an existing visible edge")
	var route_before: Dictionary = host._world_route_for_target(STASH)
	var status_before: Dictionary = run.travel_route_status(route_before)
	var retained := _retain(host, ordinary, "stashed-away cap")
	_expect(retained.size() == 3 and retained.has(STASH), "recovery stays within the three-card cap")
	_expect(retained.has("bar") and retained.has("kitty_cat_lounge"), "two reachable recipient hops fit beside recovery")
	_expect(host._world_route_for_target(STASH) == route_before and run.travel_route_status(route_before) == status_before, "retention changes no route fare, method, risk, locks or availability")
	_expect(int(status_before.get("cost",0)) == 7 and str(route_before.get("method","")) == "Bus Ticket", "retained recovery preserves its actual generated seven-dollar bus fare")
	var full_before := _state(host)
	var shared_targets: Array = Travel.travel_target_ids(host)
	_expect(shared_targets.size() == 3 and shared_targets.has(STASH), "shared cached card/map target list retains recovery")
	_expect(Travel.travel_target_ids(host) == shared_targets and _state(host) == full_before, "cache hits are read-only and preserve recovery")
	host.free()

	host = _fixture()
	run = host.run_state
	run.projected_delivery["targets"] = [{"node_id":"bar"}, {"node_id":"kitty_cat_lounge"}, {"node_id":"pawn_shop"}]
	retained = _retain(host, ORDINARY, "Lucky three-recipient overflow")
	_expect(retained.size() == 3 and retained.has(STASH) and retained.has("bar") and retained.has("kitty_cat_lounge"), "stash recovery takes priority when three recipient hops would protect every card")
	_expect(not retained.has("pawn_shop"), "lowest-priority currently nonactionable recipient yields without expanding cap")
	run.projected_delivery["targets"] = [{"node_id":STASH}, {"node_id":STASH}]
	retained = _retain(host, [STASH,"bar","kitty_cat_lounge"], "shared-hop deduplication")
	_expect(retained == [STASH,"bar","kitty_cat_lounge"], "existing recovery and duplicate handoffs do not duplicate a card")
	_expect(_retain(host, [], "zero cap", 0).is_empty(), "recovery respects a zero-card cap")
	run.world_map["nodes"].append(_node("stash_annex"))
	run.world_map["edges"].append(_edge(STASH,"stash_annex",1,3))
	run.projected_delivery["physical"]["cargo_node_id"] = "stash_annex"
	retained = _retain(host, ORDINARY, "multi-edge recovery")
	_expect(retained.has(STASH) and not retained.has("stash_annex"), "multi-edge recovery retains only the first real hop")
	host.free()

	for cargo_state in ["carried", "delivered", "ditched"]:
		host = _fixture()
		host.run_state.projected_delivery = _delivery(str(cargo_state))
		_expect(_retain(host, ORDINARY, str(cargo_state)) == ORDINARY, "non-stashed cargo preserves ordinary pending-recipient behavior: " + str(cargo_state))
		host.free()
	for status in ["completed", "failed", ""]:
		host = _fixture()
		host.run_state.projected_delivery["status"] = status
		_expect(_retain(host, ORDINARY, "inactive " + str(status)) == ORDINARY, "inactive or resolved run adds no recovery hop: " + str(status))
		host.free()
	host = _fixture()
	host.run_state.projected_delivery["physical"]["cargo_node_id"] = SOURCE
	_expect(_retain(host, ORDINARY, "same-node stash") == ORDINARY, "stash at current node does not add a self route")
	host.run_state.projected_delivery["physical"]["cargo_node_id"] = "missing_node"
	_expect(_retain(host, ORDINARY, "absent stash path") == ORDINARY, "absent path never fabricates a recovery edge")
	host.run_state.projected_delivery["physical"]["cargo_node_id"] = ""
	_expect(_retain(host, ORDINARY, "empty stash node") == ORDINARY, "empty stash node leaves ordinary choices unchanged")
	host.free()

	host = _fixture()
	run = host.run_state
	var nodes: Array = run.world_map["nodes"]
	for node_value in nodes:
		var node: Dictionary = node_value
		if str(node.get("id","")) == STASH:
			node["state"] = "hidden"
			node["seen"] = false
	_expect(Map.path_between(run.world_map,SOURCE,STASH,true).is_empty(), "hidden recovery node has no visible path")
	_expect(_retain(host, ORDINARY, "hidden stash path") == ORDINARY, "hidden recovery cannot evict ordinary cards or reveal a node")
	host.free()

	host = _fixture()
	host.library.travel_routes[0]["requires_flags"] = {"synthetic_missing_route_flag":true}
	var hidden_route: Dictionary = host._world_route_for_target(STASH)
	_expect(bool(host.run_state.travel_route_status(hidden_route).get("hidden",false)), "real route status hides unmet authored flag gate")
	_expect(_retain(host, ORDINARY, "hidden recovery route") == ORDINARY, "a real path does not bypass route visibility conditions")
	host.free()

	for gate in ["funds", "lock", "departure window", "blocked flags"]:
		host = _fixture()
		run = host.run_state
		if gate == "funds":
			run.bankroll = 0
		elif gate == "lock":
			run.current_environment["travel_lock_remaining"] = 2
		elif gate == "departure window":
			host.library.travel_routes[0]["availability_window"] = {"period":2, "open_turns":[0], "closed_text":"Synthetic departure window is closed."}
		else:
			host.library.travel_routes[0]["blocked_by_flags"] = ["synthetic_route_closed"]
			run.narrative_flags["synthetic_route_closed"] = true
		var gated_route: Dictionary = host._world_route_for_target(STASH)
		var gated_status: Dictionary = run.travel_route_status(gated_route)
		_expect(not bool(gated_status.get("available",true)) and not bool(gated_status.get("hidden",true)), "fixture has a visible disabled recovery route: " + str(gate))
		retained = _retain(host, ORDINARY, "disabled recovery " + str(gate))
		_expect(retained.has(STASH) and run.travel_route_status(gated_route) == gated_status, "retention preserves authored disabled reason and fare: " + str(gate))
		host.free()

	host = _fixture()
	run = host.run_state
	run.projected_delivery = _delivery("carried",SOURCE)
	var carried_key: String = Travel.travel_base_cache_key(host)
	var carried_targets: Array = Travel.travel_target_ids(host)
	var fixed_inputs := JSON.stringify({"clock":run.game_clock_minutes, "environment":run.current_environment, "inventory":run.inventory, "map":run.world_map})
	run.projected_delivery["physical"]["cargo_state"] = "stashed"
	var same_node_key: String = Travel.travel_base_cache_key(host)
	_expect(same_node_key != carried_key, "cargo state alone invalidates the shared cache at the same clock")
	run.projected_delivery["physical"]["cargo_node_id"] = STASH
	var stash_key: String = Travel.travel_base_cache_key(host)
	_expect(stash_key != same_node_key, "stash node alone invalidates the shared cache at the same clock")
	_expect(not carried_targets.has(STASH) and Travel.travel_target_ids(host).has(STASH), "same-clock stash refreshes the cached public target list without explicit invalidation")
	run.projected_delivery["physical"]["cargo_state"] = "carried"
	run.projected_delivery["physical"]["cargo_node_id"] = SOURCE
	_expect(Travel.travel_base_cache_key(host) == carried_key and Travel.travel_target_ids(host) == carried_targets, "retrieval restores normal carried-route projection and cache dependency")
	_expect(JSON.stringify({"clock":run.game_clock_minutes, "environment":run.current_environment, "inventory":run.inventory, "map":run.world_map}) == fixed_inputs, "cargo cache contract does not rely on turn, clock, inventory or map changes")
	host.free()

	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"checks":checks, "failures":failures, "fidelity":"Synthetic read-only cargo projection fixtures using actual WorldMap, RunGenerator, route-status gates and shared travel target cache. Actual saved native UI/Continue coverage is separate."}, "  "))
			file.close()
	print("CREW_STASH_RETURN_ROUTE_RETENTION checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
