#include "coin_pusher_native_core.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

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
	ClassDB::bind_method(D_METHOD("divi", "numerator", "denominator"), &CoinPusherNativeCore::divi);
	ClassDB::bind_method(D_METHOD("pusher_face_y", "phase_fp", "upper"), &CoinPusherNativeCore::pusher_face_y);
	ClassDB::bind_method(D_METHOD("apply_nudge_columns", "columns", "config"), &CoinPusherNativeCore::apply_nudge_columns);
}

String CoinPusherNativeCore::backend_id() const {
	return "coin_pusher_native_integer_v1";
}

int64_t CoinPusherNativeCore::divi(int64_t numerator, int64_t denominator) const {
	return denominator == 0 ? 0 : numerator / denominator;
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
	if (radius < COIN_RADIUS * 2) {
		radius = COIN_RADIUS * 2;
	}
	int64_t woken = 0;
	for (int64_t index = 0; index < count; ++index) {
		const int64_t dx = static_cast<int64_t>(x[index]) - aimed_x;
		if ((dx < 0 ? -dx : dx) > radius) {
			continue;
		}
		const int64_t mass = masses[index] > 0 ? masses[index] : 1;
		vx.set(index, static_cast<int32_t>(static_cast<int64_t>(vx[index]) + divi(nudge_x, mass)));
		vy.set(index, static_cast<int32_t>(static_cast<int64_t>(vy[index]) + divi(nudge_y, mass)));
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
