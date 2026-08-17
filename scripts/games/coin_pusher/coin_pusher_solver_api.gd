class_name CoinPusherSolverApi
extends RefCounted

# Compile-time geometry is part of the pusher module's public contract. The
# heavyweight implementation is loaded only when a cabinet actually simulates.
const SCHEMA := "coin_pusher_fixed_point"
const FIXED_HZ := 60
const FP := 1000
const WIDTH := 100000
const FRONT_EDGE := 7000
const UPPER_EDGE := 52000
const REAR_EDGE := 95000
const UPPER_FLOOR_Z := 12000
const LOWER_FLOOR_Z := 0
const COIN_RADIUS := 4300
const COIN_HEIGHT := 1700
const OBJECT_RADIUS := 5200
const OBJECT_HEIGHT := 2800
const ACTION_TICKS := 48
const PHASE_PERIOD := 12000
const TRAY_LEFT := 2000
const TRAY_RIGHT := 98000

static var _implementation: Script = null


static func create(seed_rng: RngStream, coin_cap: int, opening_coins: int, lane_count: int) -> Dictionary:
	return _implementation_script().call("create", seed_rng, coin_cap, opening_coins, lane_count) as Dictionary


static func migrate_height_grid(source: Dictionary, seed_rng: RngStream, coin_cap: int, lane_count: int) -> Dictionary:
	return _implementation_script().call("migrate_height_grid", source, seed_rng, coin_cap, lane_count) as Dictionary


static func add_coin(state: Dictionary, rng: RngStream, lane: int, lane_count: int, density: int = 1) -> Dictionary:
	return _implementation_script().call("add_coin", state, rng, lane, lane_count, density) as Dictionary


static func add_feature(state: Dictionary, kind: String, feature_id: String, lane: int, depth_milli: int, lane_count: int, metadata: Dictionary = {}) -> Dictionary:
	return _implementation_script().call("add_feature", state, kind, feature_id, lane, depth_milli, lane_count, metadata) as Dictionary


static func add_recovered_coin(state: Dictionary, rng: RngStream, lane_count: int) -> Dictionary:
	return _implementation_script().call("add_recovered_coin", state, rng, lane_count) as Dictionary


static func step_action(state: Dictionary, config: Dictionary) -> Dictionary:
	return _implementation_script().call("step_action", state, config) as Dictionary


static func step_action_reference_for_test(state: Dictionary, config: Dictionary) -> Dictionary:
	return _implementation_script().call("step_action_reference_for_test", state, config) as Dictionary


static func hot_state_eligible_for_test(state: Dictionary) -> bool:
	return bool(_implementation_script().call("hot_state_eligible_for_test", state))


static func body_views(state: Dictionary) -> Array:
	return _implementation_script().call("body_views", state) as Array


static func coin_count(state: Dictionary) -> int:
	return int(_implementation_script().call("coin_count", state))


static func awake_count(state: Dictionary) -> int:
	return int(_implementation_script().call("awake_count", state))


static func edge_hanger_count(state: Dictionary) -> int:
	return int(_implementation_script().call("edge_hanger_count", state))


static func canonical_digest(state: Dictionary) -> Dictionary:
	return _implementation_script().call("canonical_digest", state) as Dictionary


static func implementation_contract() -> Dictionary:
	return _implementation_script().call("public_contract") as Dictionary


static func _implementation_script() -> Script:
	if _implementation == null:
		_implementation = load("res://scripts/games/coin_pusher/coin_pusher_solver.gd") as Script
	return _implementation
