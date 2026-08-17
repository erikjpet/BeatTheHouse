#include "coin_pusher_native_core.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

#include <initializer_list>
#include <limits>
#include <vector>

using namespace godot;

namespace {
constexpr int64_t FP = 1000;
constexpr int64_t WIDTH = 100000;
constexpr int64_t UPPER_EDGE = 52000;
constexpr int64_t REAR_EDGE = 95000;
constexpr int64_t COIN_RADIUS = 4300;
constexpr int64_t PHASE_PERIOD = 12000;
} // namespace

void CoinPusherNativeCore::_bind_methods() {
	ClassDB::bind_method(D_METHOD("backend_id"), &CoinPusherNativeCore::backend_id);
	ClassDB::bind_method(D_METHOD("solver_contract"), &CoinPusherNativeCore::solver_contract);
	ClassDB::bind_method(D_METHOD("divi", "numerator", "denominator"), &CoinPusherNativeCore::divi);
	ClassDB::bind_method(D_METHOD("pusher_face_y", "phase_fp", "upper"), &CoinPusherNativeCore::pusher_face_y);
	ClassDB::bind_method(D_METHOD("apply_nudge_columns", "columns", "config"), &CoinPusherNativeCore::apply_nudge_columns);
	ClassDB::bind_method(D_METHOD("can_step", "state", "config"), &CoinPusherNativeCore::can_step);
	ClassDB::bind_method(D_METHOD("step_action", "state", "config"), &CoinPusherNativeCore::step_action);
}

String CoinPusherNativeCore::backend_id() const {
	return "coin_pusher_native_integer_v1";
}

Dictionary CoinPusherNativeCore::solver_contract() const {
	Dictionary value;
	value["abi_version"] = 1;
	value["schema"] = "coin_pusher_fixed_point";
	value["state_version"] = 1;
	value["fixed_point_scale"] = FP;
	value["action_ticks"] = 48;
	return value;
}

int64_t CoinPusherNativeCore::divi(int64_t numerator, int64_t denominator) const {
	if (denominator == 0) return 0;
	if (numerator == std::numeric_limits<int64_t>::min() && denominator == -1) return std::numeric_limits<int64_t>::max();
	return numerator / denominator;
}

int64_t CoinPusherNativeCore::pusher_face_y(int64_t phase_fp, bool upper) const {
	int64_t normalized = phase_fp % PHASE_PERIOD;
	if (normalized < 0) {
		normalized += PHASE_PERIOD;
	}
	const int64_t half = divi(PHASE_PERIOD, 2);
	const int64_t folded = normalized <= half ? normalized : PHASE_PERIOD - normalized;
	const int64_t travel = upper ? 24000 : 18000;
	const int64_t rear = upper ? REAR_EDGE - 3000 : UPPER_EDGE - 3000;
	return rear - divi(folded * travel, half);
}

Dictionary CoinPusherNativeCore::apply_nudge_columns(const Dictionary &columns, const Dictionary &config) const {
	PackedInt32Array x = columns.get("x", PackedInt32Array());
	PackedInt32Array vx = columns.get("vx", PackedInt32Array());
	PackedInt32Array vy = columns.get("vy", PackedInt32Array());
	PackedInt32Array masses = columns.get("masses", PackedInt32Array());
	PackedByteArray sleeping = columns.get("sleeping", PackedByteArray());
	PackedInt32Array sleep_ticks = columns.get("sleep_ticks", PackedInt32Array());
	PackedStringArray rest_states = columns.get("rest_states", PackedStringArray());
	const int64_t count = x.size();
	Dictionary result;
	if (vx.size() != count || vy.size() != count || masses.size() != count || sleeping.size() != count ||
			sleep_ticks.size() != count || rest_states.size() != count) {
		result["ok"] = false;
		result["error"] = "column_size_mismatch";
		return result;
	}

	const int64_t nudge_x = config.get("nudge_x", 0);
	const int64_t nudge_y = config.get("nudge_y", 0);
	const int64_t aimed_x = config.get("aimed_x", divi(WIDTH, 2));
	int64_t radius = config.get("nudge_radius", WIDTH);
	constexpr int64_t INPUT_ABS_LIMIT = 100000000;
	for (int64_t value : {nudge_x, nudge_y, aimed_x, radius}) {
		if (value < -INPUT_ABS_LIMIT || value > INPUT_ABS_LIMIT) {
			result["ok"] = false;
			result["error"] = "numeric_envelope";
			return result;
		}
	}
	if (radius < COIN_RADIUS * 2) {
		radius = COIN_RADIUS * 2;
	}
	std::vector<int64_t> next_vx(static_cast<size_t>(count));
	std::vector<int64_t> next_vy(static_cast<size_t>(count));
	std::vector<uint8_t> targeted(static_cast<size_t>(count), 0);
	for (int64_t index = 0; index < count; ++index) {
		const int64_t dx = static_cast<int64_t>(x[index]) - aimed_x;
		if ((dx < 0 ? -dx : dx) > radius) continue;
		const int64_t mass = masses[index] > 0 ? masses[index] : 1;
		next_vx[static_cast<size_t>(index)] = static_cast<int64_t>(vx[index]) + divi(nudge_x, mass);
		next_vy[static_cast<size_t>(index)] = static_cast<int64_t>(vy[index]) + divi(nudge_y, mass);
		if (next_vx[static_cast<size_t>(index)] < std::numeric_limits<int32_t>::min() || next_vx[static_cast<size_t>(index)] > std::numeric_limits<int32_t>::max() ||
				next_vy[static_cast<size_t>(index)] < std::numeric_limits<int32_t>::min() || next_vy[static_cast<size_t>(index)] > std::numeric_limits<int32_t>::max()) {
			result["ok"] = false;
			result["error"] = "numeric_envelope";
			return result;
		}
		targeted[static_cast<size_t>(index)] = 1;
	}
	int64_t woken = 0;
	for (int64_t index = 0; index < count; ++index) {
		if (targeted[static_cast<size_t>(index)] == 0) continue;
		vx.set(index, static_cast<int32_t>(next_vx[static_cast<size_t>(index)]));
		vy.set(index, static_cast<int32_t>(next_vy[static_cast<size_t>(index)]));
		sleeping.set(index, 0);
		sleep_ticks.set(index, 0);
		rest_states.set(index, "settling");
		++woken;
	}

	result["ok"] = true;
	result["vx"] = vx;
	result["vy"] = vy;
	result["sleeping"] = sleeping;
	result["sleep_ticks"] = sleep_ticks;
	result["rest_states"] = rest_states;
	result["woken_count"] = woken;
	return result;
}
