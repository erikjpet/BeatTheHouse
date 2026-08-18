#ifndef BTH_COIN_PUSHER_NATIVE_CORE_H
#define BTH_COIN_PUSHER_NATIVE_CORE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <cstdint>

namespace godot {

class CoinPusherNativeCore : public RefCounted {
	GDCLASS(CoinPusherNativeCore, RefCounted)

protected:
	static void _bind_methods();

public:
	String backend_id() const;
	Dictionary solver_contract() const;
	int64_t divi(int64_t numerator, int64_t denominator) const;
	bool can_step(const Dictionary &state, const Dictionary &config) const;
	Dictionary step_ticks(Dictionary state, const Dictionary &config, int64_t tick_count) const;
};

} // namespace godot

#endif
