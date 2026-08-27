#ifndef BTH_COIN_PUSHER_NATIVE_CORE_H
#define BTH_COIN_PUSHER_NATIVE_CORE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <cstdint>
#include <memory>

namespace godot {

class CoinPusherNativeCore : public RefCounted {
	GDCLASS(CoinPusherNativeCore, RefCounted)

	struct LiveKernelCache;
	mutable std::unique_ptr<LiveKernelCache> live_kernel_cache_;

protected:
	static void _bind_methods();

public:
	CoinPusherNativeCore();
	~CoinPusherNativeCore() override;
	String backend_id() const;
	Dictionary solver_contract() const;
	int64_t divi(int64_t numerator, int64_t denominator) const;
	bool can_step(const Dictionary &state, const Dictionary &config) const;
	bool supports_live_batch_capture() const;
	Dictionary build_live_render_batch(const Dictionary &config, const Array &current, const Array &previous, double alpha) const;
	Dictionary step_ticks(Dictionary state, const Dictionary &config, int64_t tick_count) const;
};

} // namespace godot

#endif
