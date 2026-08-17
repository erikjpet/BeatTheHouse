#ifndef BTH_COIN_PUSHER_NATIVE_CORE_H
#define BTH_COIN_PUSHER_NATIVE_CORE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class CoinPusherNativeCore : public RefCounted {
	GDCLASS(CoinPusherNativeCore, RefCounted)

protected:
	static void _bind_methods();

public:
	String backend_id() const;
	int64_t divi(int64_t numerator, int64_t denominator) const;
	int64_t pusher_face_y(int64_t phase_fp, bool upper) const;
	Dictionary apply_nudge_columns(const Dictionary &columns, const Dictionary &config) const;
};

} // namespace godot

#endif
