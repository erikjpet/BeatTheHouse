#include "coin_pusher_native_core.h"

#include <godot_cpp/core/class_db.hpp>
#include <limits>

using namespace godot;

void CoinPusherNativeCore::_bind_methods() {
	ClassDB::bind_method(D_METHOD("backend_id"), &CoinPusherNativeCore::backend_id);
	ClassDB::bind_method(D_METHOD("solver_contract"), &CoinPusherNativeCore::solver_contract);
	ClassDB::bind_method(D_METHOD("divi", "numerator", "denominator"), &CoinPusherNativeCore::divi);
	ClassDB::bind_method(D_METHOD("can_step", "state", "config"), &CoinPusherNativeCore::can_step);
	ClassDB::bind_method(D_METHOD("supports_live_batch_capture"), &CoinPusherNativeCore::supports_live_batch_capture);
	ClassDB::bind_method(D_METHOD("build_live_render_batch", "config", "current", "previous", "alpha"), &CoinPusherNativeCore::build_live_render_batch);
	ClassDB::bind_method(D_METHOD("build_live_render_batch_packed", "config", "current", "previous", "alpha"), &CoinPusherNativeCore::build_live_render_batch_packed);
	ClassDB::bind_method(D_METHOD("step_ticks", "state", "config", "tick_count"), &CoinPusherNativeCore::step_ticks);
}

bool CoinPusherNativeCore::supports_live_batch_capture() const { return true; }

String CoinPusherNativeCore::backend_id() const { return "coin_pusher_native_integer_v3"; }

Dictionary CoinPusherNativeCore::solver_contract() const {
	Dictionary value;
	value["abi_version"] = 3;
	value["schema"] = "coin_pusher_machine_v3";
	value["state_version"] = 3;
	value["fixed_hz"] = 60;
	value["fixed_point_scale"] = 1000;
	value["geometry_amendment"] = "6.3";
	value["contact_normal"] = "radial_euclidean";
	value["collision_passes"] = 6;
	value["hard_body_ceiling"] = 600;
	value["broadphase_table_capacity"] = 2048;
	value["candidate_pool_capacity"] = 19200;
	value["transport_rule"] = "platform_carry_plus_back_plate";
	value["integer_only_outcome_path"] = true;
	value["supports_tick_trace"] = true;
	return value;
}

int64_t CoinPusherNativeCore::divi(int64_t numerator, int64_t denominator) const {
	if (denominator == 0) return 0;
	if (numerator == std::numeric_limits<int64_t>::min() && denominator == -1) return std::numeric_limits<int64_t>::max();
	return numerator / denominator;
}
