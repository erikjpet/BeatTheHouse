class_name CoinPusherSolverApi
extends RefCounted

const CoinPusherSolverScript := preload("res://scripts/games/coin_pusher/coin_pusher_solver.gd")
const SCHEMA := CoinPusherSolverScript.SCHEMA
const VERSION := CoinPusherSolverScript.VERSION
const FIXED_HZ := CoinPusherSolverScript.FIXED_HZ
const FP := CoinPusherSolverScript.FP
const PHASE_PERIOD := CoinPusherSolverScript.PHASE_PERIOD
const WIDTH := CoinPusherSolverScript.WIDTH
const TRAY_LIP_Y := CoinPusherSolverScript.TRAY_LIP_Y
const PAYOUT_RAMP_RUN := CoinPusherSolverScript.PAYOUT_RAMP_RUN
const PAYOUT_RAMP_RISE := CoinPusherSolverScript.PAYOUT_RAMP_RISE
const DECK_Z := CoinPusherSolverScript.DECK_Z
const PLATFORM_TOP_Z := CoinPusherSolverScript.PLATFORM_TOP_Z
const FACE_EXTENDED_Y := CoinPusherSolverScript.FACE_EXTENDED_Y
const FACE_RETRACTED_Y := CoinPusherSolverScript.FACE_RETRACTED_Y
const BACK_PLATE_Y := CoinPusherSolverScript.BACK_PLATE_Y
const DROP_Y := CoinPusherSolverScript.DROP_Y
const DROP_Z := CoinPusherSolverScript.DROP_Z
const GUTTER_X := CoinPusherSolverScript.GUTTER_X
const COIN_RADIUS := CoinPusherSolverScript.COIN_RADIUS
const COIN_HEIGHT := CoinPusherSolverScript.COIN_HEIGHT
const OBJECT_RADIUS := CoinPusherSolverScript.OBJECT_RADIUS
const OBJECT_HEIGHT := CoinPusherSolverScript.OBJECT_HEIGHT
const GRAVITY := CoinPusherSolverScript.GRAVITY
const HARD_IMPACT_SPEED := CoinPusherSolverScript.HARD_IMPACT_SPEED


static func create_machine(seed_rng: RngStream, machine_definition: Dictionary, opening_bodies: int = 0) -> Dictionary:
	return CoinPusherSolverScript.create_machine(seed_rng, machine_definition, opening_bodies)


static func add_coin(state: Dictionary, rng: RngStream, x: int, density: int = 1, provenance: Dictionary = {}, bonus_origin: bool = false) -> Dictionary:
	return CoinPusherSolverScript.add_coin(state, rng, x, density, provenance, bonus_origin)


static func add_feature(state: Dictionary, kind: String, feature_id: String, x: int, y: int, metadata: Dictionary = {}) -> Dictionary:
	return CoinPusherSolverScript.add_feature(state, kind, feature_id, x, y, metadata)


static func return_gutter_body(state: Dictionary, return_data: Dictionary) -> Dictionary:
	return CoinPusherSolverScript.return_gutter_body(state, return_data)


static func step_ticks(state: Dictionary, config: Dictionary, tick_count: int) -> Dictionary:
	return CoinPusherSolverScript.step_ticks(state, config, tick_count)


static func step_ticks_reference_for_test(state: Dictionary, config: Dictionary, tick_count: int) -> Dictionary:
	return CoinPusherSolverScript.step_ticks_reference_for_test(state, config, tick_count)


static func replay_input_trace(snapshot: Dictionary, rng: RngStream, trace: Array, ticks: int) -> Dictionary:
	return CoinPusherSolverScript.replay_input_trace(snapshot, rng, trace, ticks)


static func face_y_for_phase(machine_definition: Dictionary, phase: int) -> int:
	return CoinPusherSolverScript.face_y_for_phase(machine_definition, phase)


static func set_skill_stop(state: Dictionary, engaged: bool, resume_rate_fp: int = -1) -> void:
	CoinPusherSolverScript.set_skill_stop(state, engaged, resume_rate_fp)


static func set_motor_run_rate(state: Dictionary, rate_fp: int) -> int:
	return CoinPusherSolverScript.set_motor_run_rate(state, rate_fp)


static func set_carriage(state: Dictionary, x: int) -> int:
	return CoinPusherSolverScript.set_carriage(state, x)


static func select_hole(state: Dictionary, index: int) -> int:
	return CoinPusherSolverScript.select_hole(state, index)


static func apply_nudge(state: Dictionary, impulse_x: int, impulse_y: int) -> int:
	return CoinPusherSolverScript.apply_nudge(state, impulse_x, impulse_y)


static func settle(state: Dictionary, motor_running: bool, max_ticks: int = 1200) -> Dictionary:
	return CoinPusherSolverScript.settle(state, motor_running, max_ticks)


static func all_steady(state: Dictionary, motor_running: bool = true) -> bool:
	return CoinPusherSolverScript.all_steady(state, motor_running)


static func collect_tray(state: Dictionary) -> Dictionary:
	return CoinPusherSolverScript.collect_tray(state)


static func body_views(state: Dictionary) -> Array:
	return CoinPusherSolverScript.body_views(state)


static func canonical_digest(state: Dictionary) -> Dictionary:
	return CoinPusherSolverScript.canonical_digest(state)


static func implementation_contract() -> Dictionary:
	return CoinPusherSolverScript.implementation_contract()


static func coin_count(state: Dictionary) -> int:
	return CoinPusherSolverScript.coin_count(state)


static func awake_count(state: Dictionary) -> int:
	return CoinPusherSolverScript.awake_count(state)


static func contacting_coin_count(state: Dictionary, tolerance: int = 120) -> int:
	return CoinPusherSolverScript.contacting_coin_count(state, tolerance)


static func edge_hanger_count(state: Dictionary) -> int:
	return CoinPusherSolverScript.edge_hanger_count(state)


static func payout_ramp_height_for_y(machine_definition: Dictionary, y: int) -> int:
	return CoinPusherSolverScript.payout_ramp_height_for_y(machine_definition, y)


static func payout_ramp_downhill_acceleration(machine_definition: Dictionary) -> int:
	return CoinPusherSolverScript.payout_ramp_downhill_acceleration(machine_definition)


static func native_backend_available_for_test() -> bool:
	return CoinPusherSolverScript.native_backend_available_for_test()


static func last_step_backend_for_test() -> String:
	return CoinPusherSolverScript.last_step_backend_for_test()


static func reset_native_backend_for_test() -> void:
	CoinPusherSolverScript.reset_native_backend_for_test()
