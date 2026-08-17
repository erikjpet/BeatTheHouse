#include "coin_pusher_native_core.h"

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <limits>
#include <map>
#include <set>
#include <unordered_map>
#include <utility>
#include <vector>

using namespace godot;

namespace {

constexpr int64_t FP = 1000;
constexpr int64_t WIDTH = 100000;
constexpr int64_t FRONT_EDGE = 7000;
constexpr int64_t UPPER_EDGE = 52000;
constexpr int64_t REAR_EDGE = 95000;
constexpr int64_t UPPER_FLOOR_Z = 12000;
constexpr int64_t LOWER_FLOOR_Z = 0;
constexpr int64_t COIN_RADIUS = 4300;
constexpr int64_t COIN_HEIGHT = 1700;
constexpr int64_t OBJECT_RADIUS = 5200;
constexpr int64_t OBJECT_HEIGHT = 2800;
constexpr int64_t GRAVITY = 560;
constexpr int64_t AIR_DRAG_NUM = 61;
constexpr int64_t AIR_DRAG_DEN = 64;
constexpr int64_t FLOOR_DRAG_NUM = 42;
constexpr int64_t FLOOR_DRAG_DEN = 64;
constexpr int64_t SLEEP_SPEED = 90;
constexpr int64_t SLEEP_TICKS = 8;
constexpr int64_t ACTION_TICKS = 48;
constexpr int64_t TRACE_INTERVAL = 4;
constexpr int64_t PHASE_PERIOD = 12000;
constexpr int64_t TRAY_LEFT = 2000;
constexpr int64_t TRAY_RIGHT = 98000;
constexpr int64_t BROADPHASE_CELL = 10000;
constexpr int64_t HOT_GRID_KEY_CAPACITY = 1048576;
constexpr int64_t HOT_POSITION_ABS_LIMIT = 100000000;
constexpr int64_t HOT_VELOCITY_ABS_LIMIT = 100000000;
constexpr int64_t HOT_DIMENSION_LIMIT = 10000;
constexpr int64_t HOT_GENERAL_SCALAR_ABS_LIMIT = 1000000;
constexpr int64_t HOT_PRESSURE_ACCEL_ABS_LIMIT = 100000;
constexpr int64_t HOT_BODY_COUNT_LIMIT = 256;
constexpr int64_t HOT_CONFIG_IMPULSE_ABS_LIMIT = 100000000;
constexpr int64_t HOT_PUSH_SCALE_ABS_LIMIT = 1000;
constexpr int64_t PACKED_TRACE_VERSION = 1;

int64_t divi(int64_t numerator, int64_t denominator) {
	return denominator == 0 ? 0 : numerator / denominator;
}

int64_t abs_i(int64_t value) {
	return value < 0 ? -value : value;
}

int64_t clamp_i(int64_t value, int64_t low, int64_t high) {
	return value < low ? low : value > high ? high : value;
}

int64_t posmod_i(int64_t value, int64_t modulus) {
	const int64_t remainder = value % modulus;
	return remainder < 0 ? remainder + modulus : remainder;
}

int64_t elapsed_usec(const std::chrono::steady_clock::time_point &started) {
	return std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - started).count();
}

int64_t bucket_key(int64_t x, int64_t y, int64_t z) {
	return (x + 32) + (y + 32) * 128 + (z + 32) * 16384;
}

int64_t pusher_face(int64_t phase, bool upper) {
	const int64_t half = divi(PHASE_PERIOD, 2);
	const int64_t folded = phase <= half ? phase : PHASE_PERIOD - phase;
	const int64_t travel = upper ? 24000 : 18000;
	const int64_t rear = upper ? REAR_EDGE - 3000 : UPPER_EDGE - 3000;
	return rear - divi(folded * travel, half);
}

String material_category(const String &kind) {
	if (kind == "coin") return "coin";
	if (kind == "puck") return "feature_puck";
	if (kind == "fragment") return "key_fragment";
	if (kind == "rider") return "prize_rider";
	return "physical_object";
}

Dictionary isolated_metadata(const Dictionary &metadata) {
	// Empty event/exit metadata needs no recursive walk: a fresh Dictionary already
	// owns its storage. Non-empty body metadata—including full-cap opening-pile
	// descriptors—retains the hostile-tested deep publication boundary, including
	// nested arrays and dictionaries.
	return metadata.is_empty() ? Dictionary() : metadata.duplicate(true);
}

struct Body {
	Dictionary ref;
	String id;
	String kind;
	String trace_material_category;
	Dictionary metadata;
	int32_t trace_descriptor_index = -1;
	String rest_state;
	int64_t x = 0;
	int64_t y = 0;
	int64_t z = 0;
	int64_t vx = 0;
	int64_t vy = 0;
	int64_t vz = 0;
	int64_t radius = COIN_RADIUS;
	int64_t height = COIN_HEIGHT;
	int64_t mass = 1;
	int64_t sleep_ticks = 0;
	bool sleeping = false;
	int64_t lean = 0;
	int64_t pressure_ticks = 0;
	int64_t pressure_accel = 0;
};

struct ExitTrail {
	Array views;
	int64_t index = 0;
};

struct OrderedTraceRow {
	int body_index = -1;
	int extra_index = -1;
	int64_t depth = 0;
	const String *id = nullptr;
};

struct TraceRowValues {
	int32_t body_index = -1;
	String material_category;
	int32_t x = 0;
	int32_t y = 0;
	int32_t z = 0;
	int32_t radius = 0;
	int32_t height = 0;
	uint8_t sleeping = 0;
	String rest_state;
	uint8_t has_level = 0;
	String level;
	int32_t lean = 0;
};

class SpatialGrid {
public:
	static constexpr size_t SLOT_COUNT = 512;
	static constexpr size_t SLOT_MASK = SLOT_COUNT - 1;
	std::array<int64_t, SLOT_COUNT> bucket_keys{};
	std::array<uint32_t, SLOT_COUNT> bucket_generations{};
	std::array<std::vector<int>, SLOT_COUNT> bucket_members{};
	std::array<int64_t, SLOT_COUNT> candidate_keys{};
	std::array<uint32_t, SLOT_COUNT> candidate_generations{};
	std::array<std::vector<int>, SLOT_COUNT> candidate_members{};
	std::unordered_map<int64_t, std::vector<int>> overflow_buckets;
	std::unordered_map<int64_t, std::vector<int>> overflow_candidates;
	uint32_t generation = 0;

	static size_t slot_start(int64_t key) {
		uint64_t mixed = static_cast<uint64_t>(key) * UINT64_C(11400714819323198485);
		mixed ^= mixed >> 32;
		return static_cast<size_t>(mixed) & SLOT_MASK;
	}

	int find_slot(const std::array<int64_t, SLOT_COUNT> &keys, const std::array<uint32_t, SLOT_COUNT> &generations, int64_t key) const {
		size_t slot = slot_start(key);
		for (size_t probe = 0; probe < SLOT_COUNT; ++probe) {
			if (generations[slot] != generation) return -1;
			if (keys[slot] == key) return static_cast<int>(slot);
			slot = (slot + 1) & SLOT_MASK;
		}
		return -1;
	}

	int claim_slot(std::array<int64_t, SLOT_COUNT> &keys, std::array<uint32_t, SLOT_COUNT> &generations, int64_t key) {
		size_t slot = slot_start(key);
		for (size_t probe = 0; probe < SLOT_COUNT; ++probe) {
			if (generations[slot] != generation) {
				generations[slot] = generation;
				keys[slot] = key;
				return static_cast<int>(slot);
			}
			if (keys[slot] == key) return static_cast<int>(slot);
			slot = (slot + 1) & SLOT_MASK;
		}
		return -1;
	}

	void rebuild(const std::vector<Body> &bodies) {
		if (++generation == 0) {
			bucket_generations.fill(0);
			candidate_generations.fill(0);
			generation = 1;
		}
		overflow_buckets.clear();
		overflow_candidates.clear();
		for (int index = 0; index < static_cast<int>(bodies.size()); ++index) {
			const Body &body = bodies[index];
			const int64_t key = bucket_key(divi(body.x, BROADPHASE_CELL), divi(body.y, BROADPHASE_CELL), divi(body.z, BROADPHASE_CELL));
			int slot = find_slot(bucket_keys, bucket_generations, key);
			if (slot < 0) {
				slot = claim_slot(bucket_keys, bucket_generations, key);
				if (slot >= 0) bucket_members[static_cast<size_t>(slot)].clear();
			}
			if (slot < 0) {
				overflow_buckets[key].push_back(index);
				continue;
			}
			std::vector<int> &members = bucket_members[static_cast<size_t>(slot)];
			members.push_back(index);
		}
	}

	const std::vector<int> &candidate_sequence(int64_t center_x, int64_t center_y, int64_t center_z) {
		const int64_t center_key = bucket_key(center_x, center_y, center_z);
		int candidate_slot = find_slot(candidate_keys, candidate_generations, center_key);
		if (candidate_slot >= 0) return candidate_members[static_cast<size_t>(candidate_slot)];
		candidate_slot = claim_slot(candidate_keys, candidate_generations, center_key);
		std::vector<int> &sequence = candidate_slot >= 0 ? candidate_members[static_cast<size_t>(candidate_slot)] : overflow_candidates[center_key];
		sequence.clear();
		for (int64_t zo = -1; zo <= 1; ++zo) {
			for (int64_t yo = -1; yo <= 1; ++yo) {
				for (int64_t xo = -1; xo <= 1; ++xo) {
					const int64_t neighbor_key = bucket_key(center_x + xo, center_y + yo, center_z + zo);
					const int bucket_slot = find_slot(bucket_keys, bucket_generations, neighbor_key);
					if (bucket_slot >= 0) {
						const std::vector<int> &members = bucket_members[static_cast<size_t>(bucket_slot)];
						sequence.insert(sequence.end(), members.begin(), members.end());
					} else {
						auto overflow = overflow_buckets.find(neighbor_key);
						if (overflow != overflow_buckets.end()) sequence.insert(sequence.end(), overflow->second.begin(), overflow->second.end());
					}
				}
			}
		}
		return sequence;
	}
};

bool scalar_in_range(const Dictionary &dictionary, const char *key, int64_t limit) {
	const int64_t value = dictionary.get(key, 0);
	return value >= -limit && value <= limit;
}

bool validate_step_header(const Dictionary &state, const Dictionary &config, Array &bodies) {
	Variant bodies_value = state.get("bodies", Array());
	if (bodies_value.get_type() != Variant::ARRAY) return false;
	bodies = bodies_value;
	if (bodies.size() > HOT_BODY_COUNT_LIMIT) return false;
	const int64_t tick = state.get("tick", 0);
	if (tick > std::numeric_limits<int64_t>::max() - ACTION_TICKS) return false;
	if (!config.has("captured_upper_phase_fp")) {
		const int64_t phase = state.get("upper_phase_fp", 0);
		if (phase < 0 || phase >= PHASE_PERIOD) return false;
	}
	if (!config.has("captured_lower_phase_fp")) {
		const int64_t phase = state.get("lower_phase_fp", 0);
		if (phase < 0 || phase >= PHASE_PERIOD) return false;
	}
	for (const char *key : {"nudge_x", "nudge_y", "aimed_x", "nudge_radius"}) {
		if (!scalar_in_range(config, key, HOT_CONFIG_IMPULSE_ABS_LIMIT)) return false;
	}
	const int64_t push_scale = config.get("push_scale", 1);
	if (push_scale < -HOT_PUSH_SCALE_ABS_LIMIT || push_scale > HOT_PUSH_SCALE_ABS_LIMIT) return false;
	return true;
}

bool read_validated_body(const Variant &value, Body &body, std::set<String> &ids, bool &normalized_hot_fields, bool normalize_ref) {
	if (value.get_type() != Variant::DICTIONARY) return false;
	Dictionary ref = value;
	bool exact_hot_fields = true;
	for (const char *key : {"x", "y", "z", "vx", "vy", "vz", "radius", "height", "mass", "sleep_ticks", "lean_milli"}) {
		if (ref.get(key, Variant()).get_type() != Variant::INT) exact_hot_fields = false;
	}
	for (const char *key : {"cap_pressure_ticks", "cap_pressure_accel"}) {
		if (ref.has(key) && ref.get(key, Variant()).get_type() != Variant::INT) exact_hot_fields = false;
	}
	if (ref.get("id", Variant()).get_type() != Variant::STRING || ref.get("kind", Variant()).get_type() != Variant::STRING ||
			ref.get("metadata", Variant()).get_type() != Variant::DICTIONARY || ref.get("rest_state", Variant()).get_type() != Variant::STRING ||
			ref.get("sleeping", Variant()).get_type() != Variant::BOOL) exact_hot_fields = false;
	body.id = ref.get("id", "");
	if (!ids.insert(body.id).second) return false;
	body.kind = ref.get("kind", "coin");
	Variant metadata_value = ref.get("metadata", Dictionary());
	body.metadata = metadata_value.get_type() == Variant::DICTIONARY ? Dictionary(metadata_value) : Dictionary();
	body.rest_state = ref.get("rest_state", "settling");
	body.x = ref.get("x", 0); body.y = ref.get("y", 0); body.z = ref.get("z", 0);
	body.vx = ref.get("vx", 0); body.vy = ref.get("vy", 0); body.vz = ref.get("vz", 0);
	body.radius = ref.get("radius", COIN_RADIUS); body.height = ref.get("height", COIN_HEIGHT); body.mass = ref.get("mass", 1);
	body.sleep_ticks = ref.get("sleep_ticks", 0); body.sleeping = ref.get("sleeping", false);
	body.lean = ref.get("lean_milli", 0); body.pressure_ticks = ref.get("cap_pressure_ticks", 0); body.pressure_accel = ref.get("cap_pressure_accel", 0);
	if (!exact_hot_fields && normalize_ref) {
		if (!ref.has("id")) ref["id"] = "";
		if (!ref.has("kind")) ref["kind"] = "coin";
		ref["x"] = body.x; ref["y"] = body.y; ref["z"] = body.z;
		ref["vx"] = body.vx; ref["vy"] = body.vy; ref["vz"] = body.vz;
		ref["radius"] = body.radius; ref["height"] = body.height; ref["mass"] = body.mass;
		ref["sleep_ticks"] = body.sleep_ticks; ref["sleeping"] = body.sleeping;
		ref["rest_state"] = body.rest_state; ref["lean_milli"] = body.lean;
		ref["metadata"] = body.metadata;
		if (ref.has("cap_pressure_ticks")) ref["cap_pressure_ticks"] = body.pressure_ticks;
		if (ref.has("cap_pressure_accel")) ref["cap_pressure_accel"] = body.pressure_accel;
		normalized_hot_fields = true;
	}
	body.ref = ref;
	if (body.x < -HOT_POSITION_ABS_LIMIT || body.x > HOT_POSITION_ABS_LIMIT || body.y < -HOT_POSITION_ABS_LIMIT || body.y > HOT_POSITION_ABS_LIMIT || body.z < -HOT_POSITION_ABS_LIMIT || body.z > HOT_POSITION_ABS_LIMIT) return false;
	if (body.vx < -HOT_VELOCITY_ABS_LIMIT || body.vx > HOT_VELOCITY_ABS_LIMIT || body.vy < -HOT_VELOCITY_ABS_LIMIT || body.vy > HOT_VELOCITY_ABS_LIMIT || body.vz < -HOT_VELOCITY_ABS_LIMIT || body.vz > HOT_VELOCITY_ABS_LIMIT) return false;
	if (body.radius <= 0 || body.radius > HOT_DIMENSION_LIMIT || body.height <= 0 || body.height > HOT_DIMENSION_LIMIT) return false;
	if (body.mass < -HOT_GENERAL_SCALAR_ABS_LIMIT || body.mass > HOT_GENERAL_SCALAR_ABS_LIMIT || body.sleep_ticks < -HOT_GENERAL_SCALAR_ABS_LIMIT || body.sleep_ticks > HOT_GENERAL_SCALAR_ABS_LIMIT ||
			body.lean < -HOT_GENERAL_SCALAR_ABS_LIMIT || body.lean > HOT_GENERAL_SCALAR_ABS_LIMIT || body.pressure_ticks < -HOT_GENERAL_SCALAR_ABS_LIMIT || body.pressure_ticks > HOT_GENERAL_SCALAR_ABS_LIMIT ||
			body.pressure_accel < -HOT_PRESSURE_ACCEL_ABS_LIMIT || body.pressure_accel > HOT_PRESSURE_ACCEL_ABS_LIMIT) return false;
	const int64_t cx = divi(body.x, BROADPHASE_CELL);
	const int64_t cy = divi(body.y, BROADPHASE_CELL);
	const int64_t cz = divi(body.z, BROADPHASE_CELL);
	return bucket_key(cx - 1, cy - 1, cz - 1) >= 0 && bucket_key(cx + 1, cy + 1, cz + 1) < HOT_GRID_KEY_CAPACITY;
}

bool validate_step_input(const Dictionary &state, const Dictionary &config) {
	Array bodies;
	if (!validate_step_header(state, config, bodies)) return false;
	std::set<String> ids;
	bool normalized_hot_fields = false;
	for (int index = 0; index < bodies.size(); ++index) {
		Body body;
		if (!read_validated_body(bodies[index], body, ids, normalized_hot_fields, false)) return false;
	}
	return true;
}

class StepKernel {
public:
	Dictionary state;
	Dictionary config;
	Array source_bodies;
	std::vector<Body> bodies;
	std::vector<int64_t> start_x;
	std::vector<int64_t> start_y;
	std::vector<int64_t> start_z;
	std::vector<int64_t> peak_z;
	std::vector<int> active_indices;
	std::vector<int> awake_indices;
	std::vector<int> support_indices;
	std::vector<uint8_t> support_seen;
	std::vector<int> exit_indices;
	std::vector<OrderedTraceRow> trace_ordered_rows;
	std::vector<String> trace_extra_ids;
	std::vector<TraceRowValues> trace_rows;
	Array exits;
	Array motion_events;
	std::set<String> motion_event_keys;
	Array trace;
	std::vector<ExitTrail> exit_trails;
	PackedInt32Array trace_frame_offsets;
	PackedInt32Array trace_tick_offsets;
	PackedInt32Array trace_upper_phases;
	PackedInt32Array trace_lower_phases;
	PackedStringArray trace_body_ids;
	PackedStringArray trace_body_kinds;
	PackedInt32Array trace_body_radii;
	PackedInt32Array trace_body_heights;
	PackedInt32Array trace_body_masses;
	Array trace_body_metadata;
	PackedInt32Array trace_row_body_indices;
	PackedStringArray trace_row_material_categories;
	PackedInt32Array trace_row_x;
	PackedInt32Array trace_row_y;
	PackedInt32Array trace_row_z;
	PackedInt32Array trace_row_radius;
	PackedInt32Array trace_row_height;
	PackedByteArray trace_row_sleeping;
	PackedStringArray trace_row_rest_states;
	PackedByteArray trace_row_has_level;
	PackedStringArray trace_row_levels;
	PackedInt32Array trace_row_lean;
	std::map<String, int32_t> trace_descriptor_by_id;
	bool trace_storage_preallocated = false;
	int32_t trace_frames_written = 0;
	int32_t trace_rows_written = 0;
	int64_t upper_phase = 0;
	int64_t lower_phase = 0;
	int64_t state_tick = 0;
	int64_t wake_count = 0;
	int64_t collision_count = 0;
	bool capture_trace = false;
	bool emit_presentation = true;

	StepKernel(Dictionary p_state, const Dictionary &p_config) : state(p_state), config(p_config) {}

	bool load() {
		if (!validate_step_header(state, config, source_bodies)) return false;
		Array source = source_bodies;
		capture_trace = config.get("capture_presentation_trace", false);
		emit_presentation = config.get("emit_presentation_events", true);
		bodies.reserve(source.size());
		active_indices.reserve(source.size());
		awake_indices.reserve(source.size());
		support_indices.reserve(source.size());
		support_seen.reserve(source.size());
		exit_indices.reserve(source.size());
		trace_ordered_rows.reserve(source.size());
		trace_extra_ids.reserve(source.size());
		std::set<String> ids;
		bool normalized_hot_fields = false;
		for (int index = 0; index < source.size(); ++index) {
			Body body;
			if (!read_validated_body(source[index], body, ids, normalized_hot_fields, true)) return false;
			if (capture_trace) {
				body.trace_material_category = material_category(body.kind);
				body.trace_descriptor_index = ensure_trace_descriptor(body);
			}
			bodies.push_back(body);
		}
		if (normalized_hot_fields) state["_native_normalized_hot_fields"] = true;
		if (capture_trace) prepare_trace_storage();
		upper_phase = state.get("upper_phase_fp", 0);
		lower_phase = state.get("lower_phase_fp", 0);
		state_tick = state.get("tick", 0);
		if (config.has("captured_upper_phase_fp")) {
			upper_phase = posmod_i(static_cast<int64_t>(config.get("captured_upper_phase_fp", 0)), PHASE_PERIOD);
			state["upper_phase_fp"] = upper_phase;
		}
		if (config.has("captured_lower_phase_fp")) {
			lower_phase = posmod_i(static_cast<int64_t>(config.get("captured_lower_phase_fp", 0)), PHASE_PERIOD);
			state["lower_phase_fp"] = lower_phase;
		}
		for (const Body &body : bodies) {
			start_x.push_back(body.x); start_y.push_back(body.y); start_z.push_back(body.z);
			if (emit_presentation) peak_z.push_back(body.z);
		}
		return true;
	}

	int32_t ensure_trace_descriptor(const Body &body) {
		auto found = trace_descriptor_by_id.find(body.id);
		if (found != trace_descriptor_by_id.end()) return found->second;
		const int32_t index = trace_body_ids.size();
		trace_descriptor_by_id[body.id] = index;
		trace_body_ids.append(body.id);
		trace_body_kinds.append(body.kind);
		trace_body_radii.append(static_cast<int32_t>(body.radius));
		trace_body_heights.append(static_cast<int32_t>(body.height));
		trace_body_masses.append(static_cast<int32_t>(body.mass));
		// The packed trace is a public solver result. Its nested descriptor metadata
		// must not alias the shallow candidate or authoritative simulation state: a
		// caller may retain and mutate this result before any renderer boundary.
		trace_body_metadata.append(isolated_metadata(body.metadata));
		return index;
	}

	int32_t ensure_trace_descriptor(const Dictionary &view) {
		const String id = view.get("id", "");
		auto found = trace_descriptor_by_id.find(id);
		if (found != trace_descriptor_by_id.end()) return found->second;
		const int32_t index = trace_body_ids.size();
		trace_descriptor_by_id[id] = index;
		const String kind = view.get("kind", "coin");
		trace_body_ids.append(id);
		trace_body_kinds.append(kind);
		trace_body_radii.append(static_cast<int32_t>(view.get("radius", kind == "coin" ? COIN_RADIUS : OBJECT_RADIUS)));
		trace_body_heights.append(static_cast<int32_t>(view.get("height", kind == "coin" ? COIN_HEIGHT : OBJECT_HEIGHT)));
		trace_body_masses.append(static_cast<int32_t>(view.get("mass", 1)));
		Variant metadata_value = view.get("metadata", Dictionary());
		trace_body_metadata.append(metadata_value.get_type() == Variant::DICTIONARY ? isolated_metadata(Dictionary(metadata_value)) : Dictionary());
		return index;
	}

	void materialize_trace_rows() {
		const int64_t size = static_cast<int64_t>(trace_rows.size());
		trace_row_body_indices.resize(size);
		trace_row_material_categories.resize(size);
		trace_row_x.resize(size); trace_row_y.resize(size); trace_row_z.resize(size);
		trace_row_radius.resize(size); trace_row_height.resize(size);
		trace_row_sleeping.resize(size);
		trace_row_rest_states.resize(size);
		trace_row_has_level.resize(size);
		trace_row_levels.resize(size);
		trace_row_lean.resize(size);

		// Packed-array write pointers are valid only while their owning packed
		// array remains untouched. Keep every pointer inside one primitive-only
		// fill so no Godot allocation or String operation can cross its lifetime.
		{
			int32_t *write = trace_row_body_indices.ptrw();
			for (int64_t index = 0; index < size; ++index) write[index] = trace_rows[index].body_index;
		}
		{
			int32_t *write = trace_row_x.ptrw();
			for (int64_t index = 0; index < size; ++index) write[index] = trace_rows[index].x;
		}
		{
			int32_t *write = trace_row_y.ptrw();
			for (int64_t index = 0; index < size; ++index) write[index] = trace_rows[index].y;
		}
		{
			int32_t *write = trace_row_z.ptrw();
			for (int64_t index = 0; index < size; ++index) write[index] = trace_rows[index].z;
		}
		{
			int32_t *write = trace_row_radius.ptrw();
			for (int64_t index = 0; index < size; ++index) write[index] = trace_rows[index].radius;
		}
		{
			int32_t *write = trace_row_height.ptrw();
			for (int64_t index = 0; index < size; ++index) write[index] = trace_rows[index].height;
		}
		{
			uint8_t *write = trace_row_sleeping.ptrw();
			for (int64_t index = 0; index < size; ++index) write[index] = trace_rows[index].sleeping;
		}
		{
			uint8_t *write = trace_row_has_level.ptrw();
			for (int64_t index = 0; index < size; ++index) write[index] = trace_rows[index].has_level;
		}
		{
			int32_t *write = trace_row_lean.ptrw();
			for (int64_t index = 0; index < size; ++index) write[index] = trace_rows[index].lean;
		}
		for (int64_t index = 0; index < size; ++index) {
			trace_row_material_categories.set(index, trace_rows[index].material_category);
			trace_row_rest_states.set(index, trace_rows[index].rest_state);
			trace_row_levels.set(index, trace_rows[index].level);
		}
	}

	void prepare_trace_storage() {
		const int32_t frame_capacity = ACTION_TICKS / TRACE_INTERVAL + 2;
		trace_frame_offsets.resize(frame_capacity + 1);
		trace_tick_offsets.resize(frame_capacity);
		trace_upper_phases.resize(frame_capacity);
		trace_lower_phases.resize(frame_capacity);
		trace_rows.clear();
		trace_rows.reserve(static_cast<size_t>(frame_capacity) * bodies.size());
		trace_storage_preallocated = true;
		trace_frames_written = 0;
		trace_rows_written = 0;
	}

	void append_trace_row_values(int32_t descriptor_index, const String &material, int64_t x, int64_t y, int64_t z,
			int64_t radius, int64_t height, bool sleeping, const String &rest_state, bool has_level, const String &level, int64_t lean) {
		TraceRowValues row;
		row.body_index = descriptor_index;
		row.material_category = material;
		row.x = static_cast<int32_t>(x);
		row.y = static_cast<int32_t>(y);
		row.z = static_cast<int32_t>(z);
		row.radius = static_cast<int32_t>(radius);
		row.height = static_cast<int32_t>(height);
		row.sleeping = sleeping ? 1 : 0;
		row.rest_state = rest_state;
		row.has_level = has_level ? 1 : 0;
		row.level = has_level ? level : String();
		row.lean = static_cast<int32_t>(lean);
		trace_rows.push_back(std::move(row));
		trace_rows_written = static_cast<int32_t>(trace_rows.size());
	}

	void append_trace_row(const Body &body) {
		append_trace_row_values(
			body.trace_descriptor_index, body.trace_material_category, body.x, body.y, body.z, body.radius, body.height,
			body.sleeping, body.rest_state, true,
			body.y >= UPPER_EDGE && body.z >= UPPER_FLOOR_Z ? "upper" : body.y >= FRONT_EDGE && body.z >= LOWER_FLOOR_Z && body.z < UPPER_FLOOR_Z ? "lower" : "falling",
			body.lean
		);
	}

	void append_trace_row(const Dictionary &view) {
		const bool has_level = view.has("level");
		append_trace_row_values(
			ensure_trace_descriptor(view), String(view.get("material_category", "physical_object")),
			view.get("x", 0), view.get("y", 0), view.get("z", 0), view.get("radius", COIN_RADIUS), view.get("height", COIN_HEIGHT),
			view.get("sleeping", false), String(view.get("rest_state", "settling")), has_level,
			has_level ? String(view.get("level", "falling")) : String(), view.get("lean_milli", 0)
		);
	}

	void append_packed_trace_frame(int64_t tick_offset, const Array &extra) {
		trace_ordered_rows.clear();
		trace_extra_ids.clear();
		if (trace_ordered_rows.capacity() < bodies.size() + static_cast<size_t>(extra.size())) {
			trace_ordered_rows.reserve(bodies.size() + extra.size());
		}
		if (trace_extra_ids.capacity() < static_cast<size_t>(extra.size())) trace_extra_ids.reserve(extra.size());
		for (int index = 0; index < extra.size(); ++index) {
			Dictionary view = extra[index];
			trace_extra_ids.push_back(view.get("id", ""));
		}
		for (int index = 0; index < static_cast<int>(bodies.size()); ++index) {
			const Body &body = bodies[index];
			OrderedTraceRow row; row.body_index = index; row.depth = body.y * 10 - body.z; row.id = &body.id; trace_ordered_rows.push_back(row);
		}
		for (int index = 0; index < extra.size(); ++index) {
			Dictionary view = extra[index];
			OrderedTraceRow row; row.extra_index = index;
			row.depth = static_cast<int64_t>(view.get("y", 0)) * 10 - static_cast<int64_t>(view.get("z", 0));
			row.id = &trace_extra_ids[index]; trace_ordered_rows.push_back(row);
		}
		std::sort(trace_ordered_rows.begin(), trace_ordered_rows.end(), [](const OrderedTraceRow &left, const OrderedTraceRow &right) {
			if (left.depth == right.depth) return *left.id < *right.id;
			return left.depth > right.depth;
		});
		if (trace_storage_preallocated) {
			const int32_t frame = trace_frames_written++;
			trace_frame_offsets.set(frame, static_cast<int32_t>(trace_rows.size()));
			trace_tick_offsets.set(frame, static_cast<int32_t>(tick_offset));
			trace_upper_phases.set(frame, static_cast<int32_t>(upper_phase));
			trace_lower_phases.set(frame, static_cast<int32_t>(lower_phase));
		} else {
			trace_frame_offsets.append(static_cast<int32_t>(trace_rows.size()));
			trace_tick_offsets.append(static_cast<int32_t>(tick_offset));
			trace_upper_phases.append(static_cast<int32_t>(upper_phase));
			trace_lower_phases.append(static_cast<int32_t>(lower_phase));
		}
		for (const OrderedTraceRow &row : trace_ordered_rows) {
			if (row.body_index >= 0) append_trace_row(bodies[row.body_index]); else append_trace_row(Dictionary(extra[row.extra_index]));
		}
	}

	bool load_existing_packed_trace(const Dictionary &packed) {
		if (String(packed.get("schema", "")) != "coin_pusher_presentation_trace_packed" || static_cast<int64_t>(packed.get("version", 0)) != PACKED_TRACE_VERSION) return false;
		trace_frame_offsets = packed.get("frame_offsets", PackedInt32Array());
		trace_tick_offsets = packed.get("tick_offsets", PackedInt32Array());
		trace_upper_phases = packed.get("upper_phase_fp", PackedInt32Array());
		trace_lower_phases = packed.get("lower_phase_fp", PackedInt32Array());
		trace_body_ids = packed.get("body_ids", PackedStringArray());
		trace_body_kinds = packed.get("body_kinds", PackedStringArray());
		trace_body_radii = packed.get("body_radii", PackedInt32Array());
		trace_body_heights = packed.get("body_heights", PackedInt32Array());
		trace_body_masses = packed.get("body_masses", PackedInt32Array());
		Variant metadata_value = packed.get("body_metadata", Array());
		if (metadata_value.get_type() != Variant::ARRAY) return false;
		trace_body_metadata = metadata_value;
		trace_row_body_indices = packed.get("row_body_indices", PackedInt32Array());
		trace_row_material_categories = packed.get("row_material_categories", PackedStringArray());
		trace_row_x = packed.get("row_x", PackedInt32Array()); trace_row_y = packed.get("row_y", PackedInt32Array()); trace_row_z = packed.get("row_z", PackedInt32Array());
		trace_row_radius = packed.get("row_radius", PackedInt32Array()); trace_row_height = packed.get("row_height", PackedInt32Array());
		trace_row_sleeping = packed.get("row_sleeping", PackedByteArray());
		trace_row_rest_states = packed.get("row_rest_states", PackedStringArray());
		trace_row_has_level = packed.get("row_has_level", PackedByteArray());
		trace_row_levels = packed.get("row_levels", PackedStringArray());
		trace_row_lean = packed.get("row_lean_milli", PackedInt32Array());
		const int64_t frame_count = packed.get("frame_count", -1);
		const int64_t descriptor_count = trace_body_ids.size();
		const int64_t row_count = trace_row_body_indices.size();
		if (frame_count < 0 || trace_tick_offsets.size() != frame_count || trace_upper_phases.size() != frame_count || trace_lower_phases.size() != frame_count || trace_frame_offsets.size() != frame_count + 1) return false;
		if (trace_body_kinds.size() != descriptor_count || trace_body_radii.size() != descriptor_count || trace_body_heights.size() != descriptor_count || trace_body_masses.size() != descriptor_count || trace_body_metadata.size() != descriptor_count) return false;
		if (trace_row_material_categories.size() != row_count || trace_row_x.size() != row_count || trace_row_y.size() != row_count || trace_row_z.size() != row_count || trace_row_radius.size() != row_count || trace_row_height.size() != row_count || trace_row_sleeping.size() != row_count || trace_row_rest_states.size() != row_count || trace_row_has_level.size() != row_count || trace_row_levels.size() != row_count || trace_row_lean.size() != row_count) return false;
		if (trace_frame_offsets[0] != 0 || trace_frame_offsets[frame_count] != row_count) return false;
		for (int64_t index = 0; index < frame_count; ++index) if (trace_frame_offsets[index] > trace_frame_offsets[index + 1]) return false;
		for (int64_t index = 0; index < row_count; ++index) if (trace_row_body_indices[index] < 0 || trace_row_body_indices[index] >= descriptor_count) return false;
		for (int32_t index = 0; index < trace_body_ids.size(); ++index) {
			if (trace_descriptor_by_id.count(trace_body_ids[index]) != 0) return false;
			trace_descriptor_by_id[trace_body_ids[index]] = index;
		}
		trace_rows.clear();
		trace_rows.reserve(static_cast<size_t>(row_count));
		for (int64_t index = 0; index < row_count; ++index) {
			TraceRowValues row;
			row.body_index = trace_row_body_indices[index];
			row.material_category = trace_row_material_categories[index];
			row.x = trace_row_x[index];
			row.y = trace_row_y[index];
			row.z = trace_row_z[index];
			row.radius = trace_row_radius[index];
			row.height = trace_row_height[index];
			row.sleeping = trace_row_sleeping[index];
			row.rest_state = trace_row_rest_states[index];
			row.has_level = trace_row_has_level[index];
			row.level = trace_row_levels[index];
			row.lean = trace_row_lean[index];
			trace_rows.push_back(std::move(row));
		}
		trace_rows_written = static_cast<int32_t>(trace_rows.size());
		trace_frame_offsets.resize(frame_count);
		return true;
	}

	Dictionary finish_packed_trace() {
		if (trace_storage_preallocated) {
			trace_frame_offsets.set(trace_frames_written, static_cast<int32_t>(trace_rows.size()));
			trace_frame_offsets.resize(trace_frames_written + 1);
			trace_tick_offsets.resize(trace_frames_written);
			trace_upper_phases.resize(trace_frames_written);
			trace_lower_phases.resize(trace_frames_written);
			trace_storage_preallocated = false;
		} else {
			trace_frame_offsets.append(static_cast<int32_t>(trace_rows.size()));
		}
		materialize_trace_rows();
		Dictionary packed;
		packed["schema"] = "coin_pusher_presentation_trace_packed";
		packed["version"] = PACKED_TRACE_VERSION;
		packed["frame_count"] = trace_tick_offsets.size();
		packed["frame_offsets"] = trace_frame_offsets;
		packed["tick_offsets"] = trace_tick_offsets;
		packed["upper_phase_fp"] = trace_upper_phases;
		packed["lower_phase_fp"] = trace_lower_phases;
		packed["body_ids"] = trace_body_ids;
		packed["body_kinds"] = trace_body_kinds;
		packed["body_radii"] = trace_body_radii;
		packed["body_heights"] = trace_body_heights;
		packed["body_masses"] = trace_body_masses;
		packed["body_metadata"] = trace_body_metadata;
		packed["row_body_indices"] = trace_row_body_indices;
		packed["row_material_categories"] = trace_row_material_categories;
		packed["row_x"] = trace_row_x; packed["row_y"] = trace_row_y; packed["row_z"] = trace_row_z;
		packed["row_radius"] = trace_row_radius; packed["row_height"] = trace_row_height;
		packed["row_sleeping"] = trace_row_sleeping;
		packed["row_rest_states"] = trace_row_rest_states;
		packed["row_has_level"] = trace_row_has_level;
		packed["row_levels"] = trace_row_levels;
		packed["row_lean_milli"] = trace_row_lean;
		return packed;
	}

	int64_t apply_nudge() {
		const int64_t nx = config.get("nudge_x", 0);
		const int64_t ny = config.get("nudge_y", 0);
		if (nx == 0 && ny == 0) return 0;
		const int64_t aimed = config.get("aimed_x", divi(WIDTH, 2));
		const int64_t radius = std::max<int64_t>(COIN_RADIUS * 2, config.get("nudge_radius", WIDTH));
		int64_t count = 0;
		for (Body &body : bodies) {
			if (abs_i(body.x - aimed) > radius) continue;
			const int64_t mass = std::max<int64_t>(1, body.mass);
			body.vx += divi(nx, mass); body.vy += divi(ny, mass);
			body.sleeping = false; body.sleep_ticks = 0; body.rest_state = "settling";
			++count;
		}
		return count;
	}

	int64_t apply_pushers(int64_t old_upper, int64_t new_upper, int64_t old_lower, int64_t new_lower, int64_t push_scale, std::vector<int> &active) {
		const bool upper_active = new_upper < old_upper;
		const bool lower_active = new_lower < old_lower;
		int64_t count = 0;
		for (int index = 0; index < static_cast<int>(bodies.size()); ++index) {
			Body &body = bodies[index];
			const bool upper = body.y >= UPPER_EDGE && body.z >= UPPER_FLOOR_Z;
			const bool enabled = upper ? upper_active : lower_active;
			const int64_t old_face = upper ? old_upper : old_lower;
			const int64_t new_face = upper ? new_upper : new_lower;
			const int64_t floor_z = upper ? UPPER_FLOOR_Z : LOWER_FLOOR_Z;
			const bool eligible = enabled && (upper || (body.y >= FRONT_EDGE && body.y < UPPER_EDGE && body.z < UPPER_FLOOR_Z + COIN_HEIGHT));
			if (eligible && body.y > new_face - body.radius && body.y < old_face + body.radius && body.z <= floor_z + body.height * 5) {
				body.y = std::min(body.y, new_face - body.radius);
				body.vy -= (old_face - new_face) * push_scale;
				body.sleeping = false; body.sleep_ticks = 0; body.rest_state = "settling";
				++count;
			}
			if (!body.sleeping) active.push_back(index);
		}
		return count;
	}

	void append_impact(Body &body, const String &material, int64_t stack_depth, int64_t fall_height, int64_t tick_offset) {
		const String key = String("impact|") + body.id;
		if (body.id.is_empty() || motion_event_keys.count(key) != 0) return;
		Dictionary event;
		event["kind"] = "impact"; event["body_id"] = body.id;
		event["x"] = body.x; event["y"] = body.y; event["z"] = body.z;
		event["tick_offset"] = tick_offset; event["material"] = material;
		event["stack_depth"] = std::max<int64_t>(0, stack_depth);
		event["fall_height_milli"] = std::max<int64_t>(0, divi(fall_height * FP, COIN_HEIGHT));
		motion_events.append(event);
		motion_event_keys.insert(key);
	}

	void integrate(const std::vector<int> &active, int64_t tick_offset) {
		exit_indices.clear();
		for (int index : active) {
			if (index < 0 || index >= static_cast<int>(bodies.size())) continue;
			Body &body = bodies[index];
			const int64_t previous_z = body.z;
			if (emit_presentation) peak_z[index] = std::max(peak_z[index], previous_z);
			if (body.pressure_ticks > 0) {
				body.vy -= std::max<int64_t>(0, body.pressure_accel);
				--body.pressure_ticks;
			}
			const bool was_upper = body.z >= UPPER_FLOOR_Z;
			body.vz -= GRAVITY;
			body.vx = divi(body.vx * AIR_DRAG_NUM, AIR_DRAG_DEN);
			body.vy = divi(body.vy * AIR_DRAG_NUM, AIR_DRAG_DEN);
			body.x += divi(body.vx, 60); body.y += divi(body.vy, 60); body.z += divi(body.vz, 60);
			String outcome;
			if (body.x < -body.radius || body.x > WIDTH + body.radius) outcome = "gutter";
			else if (body.y < FRONT_EDGE - body.radius) outcome = body.x >= TRAY_LEFT && body.x <= TRAY_RIGHT ? "tray" : "gutter";
			if (!outcome.is_empty()) {
				Dictionary event;
				event["body_id"] = body.id; event["kind"] = body.kind;
				event["outcome"] = outcome; event["cause"] = "physical_fall";
				event["x"] = body.x; event["y"] = body.y; event["z"] = body.z;
				event["mass"] = body.mass; event["tick_offset"] = tick_offset;
				event["metadata"] = isolated_metadata(body.metadata);
				exits.append(event); exit_indices.push_back(index); continue;
			}
			const int64_t base_z = body.y >= UPPER_EDGE ? UPPER_FLOOR_Z : LOWER_FLOOR_Z;
			if (was_upper && body.y < UPPER_EDGE) {
				Dictionary event;
				event["kind"] = "upper_to_lower"; event["body_id"] = body.id;
				event["x"] = body.x; event["y"] = body.y; event["z"] = body.z; event["tick_offset"] = tick_offset;
				motion_events.append(event);
			}
			if (body.z <= base_z) {
				const int64_t fall_height = std::max<int64_t>(0, (emit_presentation ? peak_z[index] : previous_z) - base_z);
				if (emit_presentation && previous_z > base_z && fall_height > 0) append_impact(body, "coin_on_metal", 0, fall_height, tick_offset);
				body.z = base_z; body.vz = 0;
				body.vx = divi(body.vx * FLOOR_DRAG_NUM, FLOOR_DRAG_DEN);
				body.vy = divi(body.vy * FLOOR_DRAG_NUM, FLOOR_DRAG_DEN);
				const int64_t speed = abs_i(body.vx) + abs_i(body.vy) + abs_i(body.vz);
				if (speed <= SLEEP_SPEED) {
					++body.sleep_ticks;
					if (body.sleep_ticks >= SLEEP_TICKS) { body.vx = 0; body.vy = 0; body.vz = 0; body.sleeping = true; body.rest_state = "resting"; }
				} else { body.sleep_ticks = 0; body.rest_state = "settling"; }
			} else { body.rest_state = "falling"; body.sleep_ticks = 0; }
		}
		for (auto it = exit_indices.rbegin(); it != exit_indices.rend(); ++it) {
			const int index = *it;
			source_bodies.remove_at(index);
			bodies.erase(bodies.begin() + index);
			start_x.erase(start_x.begin() + index); start_y.erase(start_y.begin() + index); start_z.erase(start_z.begin() + index);
			if (emit_presentation) peak_z.erase(peak_z.begin() + index);
		}
	}

	int64_t resolve_collisions(SpatialGrid &grid, std::vector<int64_t> &visited, int64_t generation, const std::vector<int> &awake, std::vector<int> &supports, std::vector<uint8_t> &support_seen) {
		int64_t resolved = 0;
		const int64_t body_count = static_cast<int64_t>(bodies.size());
		for (int left_index : awake) {
			Body &left = bodies[left_index];
			const std::vector<int> &candidates = grid.candidate_sequence(divi(left.x, BROADPHASE_CELL), divi(left.y, BROADPHASE_CELL), divi(left.z, BROADPHASE_CELL));
			for (int right_index : candidates) {
				if (right_index == left_index) continue;
				const int low = std::min(left_index, right_index);
				const int high = std::max(left_index, right_index);
				const int64_t pair_key = static_cast<int64_t>(low) * body_count + high;
				if (visited[pair_key] == generation) continue;
				visited[pair_key] = generation;
				Body &right = bodies[right_index];
				const int64_t dx = right.x - left.x;
				const int64_t dy = right.y - left.y;
				const int64_t min_distance = left.radius + right.radius;
				if (abs_i(dx) >= min_distance || abs_i(dy) >= min_distance || dx * dx + dy * dy >= min_distance * min_distance) continue;
				if (abs_i(left.z - right.z) >= std::min(left.height, right.height)) continue;
				const int64_t overlap = min_distance - std::max(abs_i(dx), abs_i(dy));
				if (overlap <= 0) continue;
				if (abs_i(dx) >= abs_i(dy)) {
					const int64_t sign = dx >= 0 ? 1 : -1;
					right.x += divi(sign * overlap, 2); left.x -= divi(sign * overlap, 2);
					right.vx += sign * overlap * 5; left.vx -= sign * overlap * 5;
				} else {
					const int64_t sign = dy >= 0 ? 1 : -1;
					right.y += divi(sign * overlap, 2); left.y -= divi(sign * overlap, 2);
					right.vy += sign * overlap * 5; left.vy -= sign * overlap * 5;
				}
				if (right.sleeping && support_seen[right_index] == 0) { support_seen[right_index] = 1; supports.push_back(right_index); }
				left.sleeping = false; left.sleep_ticks = 0; left.rest_state = "settling";
				right.sleeping = false; right.sleep_ticks = 0; right.rest_state = "settling";
				++resolved;
			}
		}
		return resolved;
	}

	void resolve_supports(SpatialGrid &grid, const std::vector<int> &active, int64_t tick_offset) {
		for (int body_index : active) {
			if (body_index < 0 || body_index >= static_cast<int>(bodies.size())) continue;
			Body &body = bodies[body_index];
			const int64_t base_z = body.y >= UPPER_EDGE ? UPPER_FLOOR_Z : LOWER_FLOOR_Z;
			if (body.z <= base_z) { body.lean = 0; continue; }
			int support_index = -1;
			int64_t support_distance = INT64_C(1) << 30;
			const std::vector<int> &candidates = grid.candidate_sequence(divi(body.x, BROADPHASE_CELL), divi(body.y, BROADPHASE_CELL), divi(body.z, BROADPHASE_CELL));
			for (int candidate_index : candidates) {
				if (candidate_index == body_index) continue;
				Body &candidate = bodies[candidate_index];
				const int64_t target = candidate.z + candidate.height;
				if (target > body.z + COIN_HEIGHT || target < body.z - COIN_HEIGHT * 2) continue;
				const int64_t dx = body.x - candidate.x;
				const int64_t dy = body.y - candidate.y;
				const int64_t distance = dx * dx + dy * dy;
				const int64_t radius = std::min(body.radius, candidate.radius);
				if (distance < radius * radius && distance < support_distance) { support_index = candidate_index; support_distance = distance; }
			}
			if (support_index < 0) { body.rest_state = "falling"; body.sleeping = false; continue; }
			Body &support = bodies[support_index];
			const int64_t target_z = support.z + support.height;
			if (body.vz <= 0 && body.z <= target_z + COIN_HEIGHT) {
				const int64_t fall_height = std::max<int64_t>(0, (emit_presentation ? peak_z[body_index] : body.z) - target_z);
				if (emit_presentation && fall_height > 0) append_impact(body, "coin_on_coin", std::max<int64_t>(1, divi(target_z - base_z, COIN_HEIGHT)), fall_height, tick_offset);
				body.z = target_z; body.vz = 0;
				const int64_t dx = body.x - support.x;
				const int64_t dy = body.y - support.y;
				body.lean = divi(std::max(abs_i(dx), abs_i(dy)) * FP, std::max<int64_t>(1, body.radius));
				if (body.lean > 620) {
					const String key = String("topple|") + body.id;
					if (motion_event_keys.count(key) == 0) {
						Dictionary event; event["kind"] = "topple"; event["body_id"] = body.id; event["support_id"] = support.id; event["lean_milli"] = body.lean;
						motion_events.append(event); motion_event_keys.insert(key);
					}
					body.vx += dx >= 0 ? 120 : -120; body.vy += dy >= 0 ? 120 : -120;
					body.z = target_z + 80; body.rest_state = "toppling"; body.sleeping = false;
				} else {
					const int64_t speed = abs_i(body.vx) + abs_i(body.vy) + abs_i(body.vz);
					if (speed <= SLEEP_SPEED) {
						++body.sleep_ticks;
						if (body.sleep_ticks >= SLEEP_TICKS) { body.vx = 0; body.vy = 0; body.vz = 0; body.sleeping = true; body.rest_state = "resting"; }
					} else { body.sleep_ticks = 0; body.sleeping = false; body.rest_state = "settling"; }
				}
			}
		}
	}

	Array exit_views(const Dictionary &event) const {
		const String kind = event.get("kind", "coin");
		Dictionary first;
		first["id"] = event.get("body_id", ""); first["kind"] = kind;
		first["material_category"] = kind == "coin" ? "coin" : "physical_object";
		first["x"] = event.get("x", 0); first["y"] = event.get("y", 0); first["z"] = event.get("z", 0);
		first["radius"] = kind == "coin" ? COIN_RADIUS : OBJECT_RADIUS;
		first["height"] = kind == "coin" ? COIN_HEIGHT : OBJECT_HEIGHT;
		first["mass"] = event.get("mass", 1); first["sleeping"] = false;
		first["rest_state"] = String("falling_") + String(event.get("outcome", "tray"));
		first["lean_milli"] = 0;
		Variant metadata_value = event.get("metadata", Dictionary());
		first["metadata"] = metadata_value.get_type() == Variant::DICTIONARY ? isolated_metadata(Dictionary(metadata_value)) : Dictionary();
		Dictionary second = first.duplicate(true);
		second["y"] = static_cast<int64_t>(first.get("y", 0)) - 4500;
		second["z"] = static_cast<int64_t>(first.get("z", 0)) - 6000;
		Array result; result.append(first); result.append(second); return result;
	}

	Dictionary presentation_event(const String &kind, int body_index, const Dictionary &fallback_body, int64_t intensity, int64_t tick_offset, const Dictionary &metadata) const {
		Dictionary event;
		event["kind"] = kind;
		if (body_index >= 0) {
			const Body &body = bodies[body_index];
			event["body_id"] = String(body.ref.get("body_id", body.id));
			event["x"] = body.x; event["y"] = body.y; event["z"] = body.z;
		} else {
			event["body_id"] = String(fallback_body.get("body_id", fallback_body.get("id", "")));
			event["x"] = fallback_body.get("x", divi(WIDTH, 2));
			event["y"] = fallback_body.get("y", UPPER_EDGE);
			event["z"] = fallback_body.get("z", 0);
		}
		event["intensity_milli"] = clamp_i(intensity, 0, 1000);
		event["tick_offset"] = clamp_i(tick_offset, 0, ACTION_TICKS);
		event["metadata"] = isolated_metadata(metadata);
		return event;
	}

	Array build_presentation_events(const Dictionary &metrics) const {
		Array result;
		int focus = -1;
		for (int index = 0; index < static_cast<int>(bodies.size()); ++index) if (!bodies[index].sleeping) { focus = index; break; }
		if (focus < 0 && !bodies.empty()) focus = 0;
		const int64_t moved = metrics.get("moved_count", 0);
		if (moved > 1) {
			Dictionary metadata; metadata["moved_count"] = moved;
			result.append(presentation_event("slide", focus, Dictionary(), std::min<int64_t>(1000, 180 + moved * 24), ACTION_TICKS / 2, metadata));
		}
		std::map<String, int> index_by_id;
		if (!motion_events.is_empty()) for (int index = 0; index < static_cast<int>(bodies.size()); ++index) index_by_id[bodies[index].id] = index;
		for (int index = 0; index < motion_events.size(); ++index) {
			Dictionary motion = motion_events[index];
			const String kind = motion.get("kind", "");
			int64_t intensity = kind == "topple" ? 720 : 820;
			if (kind == "impact") intensity = std::min<int64_t>(1000, 320 + divi(static_cast<int64_t>(motion.get("fall_height_milli", 0)), 8) + static_cast<int64_t>(motion.get("stack_depth", 0)) * 70);
			auto found = index_by_id.find(String(motion.get("body_id", "")));
			const int body_index = found == index_by_id.end() ? -1 : found->second;
			result.append(presentation_event(kind, body_index, motion, intensity, motion.get("tick_offset", ACTION_TICKS / 2), motion));
		}
		int64_t tray_total = 0;
		int64_t gutter_total = 0;
		for (int index = 0; index < exits.size(); ++index) {
			Dictionary event = exits[index];
			if (String(event.get("outcome", "gutter")) == "tray") ++tray_total; else ++gutter_total;
		}
		int64_t tray_index = 0;
		int64_t gutter_index = 0;
		for (int index = 0; index < exits.size(); ++index) {
			Dictionary exit = exits[index];
			const String outcome = exit.get("outcome", "gutter");
			const int64_t tick_offset = exit.get("tick_offset", ACTION_TICKS);
			const int64_t group_index = outcome == "tray" ? tray_index++ : gutter_index++;
			const int64_t group_count = outcome == "tray" ? tray_total : gutter_total;
			Dictionary ledge_metadata; ledge_metadata["outcome"] = outcome;
			result.append(presentation_event("ledge_tip", -1, exit, 760, std::max<int64_t>(0, tick_offset - 3), ledge_metadata));
			Dictionary landing_metadata; landing_metadata["outcome"] = outcome; landing_metadata["group_count"] = group_count; landing_metadata["group_index"] = group_index;
			result.append(presentation_event(outcome == "tray" ? "tray_landing" : "gutter_loss", -1, exit, std::min<int64_t>(1000, 450 + static_cast<int64_t>(exit.get("mass", 1)) * 110), tick_offset, landing_metadata));
		}
		const int64_t nx = config.get("nudge_x", 0);
		const int64_t ny = config.get("nudge_y", 0);
		if (nx != 0 || ny != 0) result.append(presentation_event("cabinet_shake", focus, Dictionary(), std::min<int64_t>(1000, divi(abs_i(nx) + abs_i(ny), 24)), 1, Dictionary()));
		return result;
	}

	void write_back() {
		for (Body &body : bodies) {
			body.ref["x"] = body.x; body.ref["y"] = body.y; body.ref["z"] = body.z;
			body.ref["vx"] = body.vx; body.ref["vy"] = body.vy; body.ref["vz"] = body.vz;
			body.ref["sleep_ticks"] = body.sleep_ticks; body.ref["sleeping"] = body.sleeping;
			body.ref["rest_state"] = body.rest_state; body.ref["lean_milli"] = body.lean;
			if (body.ref.has("cap_pressure_ticks") || body.pressure_ticks > 0) body.ref["cap_pressure_ticks"] = body.pressure_ticks;
			if (body.ref.has("cap_pressure_accel") || body.pressure_accel > 0) body.ref["cap_pressure_accel"] = body.pressure_accel;
		}
		state["bodies"] = source_bodies;
	}

	Dictionary run();
};

} // namespace

bool CoinPusherNativeCore::can_step(const Dictionary &state, const Dictionary &config) const {
	return validate_step_input(state, config);
}

Dictionary StepKernel::run() {
	const bool debug_profile = config.get("_debug_profile_stages", false);
	std::chrono::steady_clock::time_point started;
	std::chrono::steady_clock::time_point stage_started;
	int64_t profile_pack = 0;
	int64_t profile_push_integrate = 0;
	int64_t profile_collision_setup = 0;
	int64_t profile_grid = 0;
	int64_t profile_collisions = 0;
	int64_t profile_supports = 0;
	int64_t profile_trace = 0;
	int64_t profile_final_scan = 0;
	int64_t profile_writeback = 0;
	int64_t profile_result = 0;
	if (debug_profile) {
		started = std::chrono::steady_clock::now();
		stage_started = started;
	}
	if (!load()) return Dictionary();
	if (debug_profile) profile_pack = elapsed_usec(stage_started);
	if (capture_trace) {
		if (debug_profile) stage_started = std::chrono::steady_clock::now();
		append_packed_trace_frame(0, Array());
		if (debug_profile) profile_trace += elapsed_usec(stage_started);
	}
	if (debug_profile) stage_started = std::chrono::steady_clock::now();
	wake_count += apply_nudge();
	if (debug_profile) profile_push_integrate += elapsed_usec(stage_started);
	const int64_t starting_count = static_cast<int64_t>(bodies.size());
	if (debug_profile) stage_started = std::chrono::steady_clock::now();
	std::vector<int64_t> collision_visited(static_cast<size_t>(starting_count * starting_count), 0);
	if (debug_profile) profile_collision_setup = elapsed_usec(stage_started);
	const bool upper_locked = config.get("upper_locked", false);
	const bool lower_locked = config.get("lower_locked", false);
	const bool ridge_double = config.get("ridge_double", false);
	const int64_t push_scale = std::max<int64_t>(1, config.get("push_scale", 1));
	SpatialGrid grid;
	for (int64_t tick_index = 0; tick_index < ACTION_TICKS; ++tick_index) {
		const int event_count_before = exits.size();
		const int64_t old_upper = pusher_face(upper_phase, true);
		const int64_t old_lower = pusher_face(lower_phase, false);
		if (!upper_locked) {
			upper_phase = posmod_i(upper_phase + 280 * (ridge_double ? 2 : 1), PHASE_PERIOD);
			state["upper_phase_fp"] = upper_phase;
		}
		if (!lower_locked) {
			lower_phase = posmod_i(lower_phase + 360 * (ridge_double ? 2 : 1), PHASE_PERIOD);
			state["lower_phase_fp"] = lower_phase;
		}
		const int64_t new_upper = pusher_face(upper_phase, true);
		const int64_t new_lower = pusher_face(lower_phase, false);
		active_indices.clear();
		if (debug_profile) stage_started = std::chrono::steady_clock::now();
		wake_count += apply_pushers(old_upper, new_upper, old_lower, new_lower, push_scale, active_indices);
		if (!active_indices.empty()) integrate(active_indices, tick_index + 1);
		if (debug_profile) profile_push_integrate += elapsed_usec(stage_started);
		if (!active_indices.empty()) {
			awake_indices.clear();
			for (int index = 0; index < static_cast<int>(bodies.size()); ++index) if (!bodies[index].sleeping) awake_indices.push_back(index);
			if (debug_profile) stage_started = std::chrono::steady_clock::now();
			grid.rebuild(bodies);
			if (debug_profile) profile_grid += elapsed_usec(stage_started);
			if (debug_profile) stage_started = std::chrono::steady_clock::now();
			support_indices.assign(awake_indices.begin(), awake_indices.end());
			support_seen.assign(bodies.size(), 0);
			for (int index : awake_indices) support_seen[index] = 1;
			if (debug_profile) profile_supports += elapsed_usec(stage_started);
			const int64_t generation = tick_index + 1;
			if (debug_profile) stage_started = std::chrono::steady_clock::now();
			const int64_t resolved = resolve_collisions(grid, collision_visited, generation, awake_indices, support_indices, support_seen);
			collision_count += resolved;
			if (debug_profile) profile_collisions += elapsed_usec(stage_started);
			if (debug_profile) stage_started = std::chrono::steady_clock::now();
			std::sort(support_indices.begin(), support_indices.end());
			resolve_supports(grid, support_indices, tick_index + 1);
			if (debug_profile) profile_supports += elapsed_usec(stage_started);
		}
		++state_tick;
		state["tick"] = state_tick;
		if (capture_trace) {
			if (debug_profile) stage_started = std::chrono::steady_clock::now();
			for (int event_index = event_count_before; event_index < exits.size(); ++event_index) {
				ExitTrail trail; trail.views = exit_views(Dictionary(exits[event_index])); exit_trails.push_back(trail);
			}
			if ((tick_index + 1) % TRACE_INTERVAL == 0 || tick_index + 1 == ACTION_TICKS) {
				Array extra;
				std::vector<ExitTrail> remaining;
				for (ExitTrail &trail : exit_trails) {
					if (trail.index < trail.views.size()) {
						extra.append(trail.views[trail.index]);
						++trail.index;
						if (trail.index < trail.views.size()) remaining.push_back(trail);
					}
				}
				exit_trails = std::move(remaining);
				append_packed_trace_frame(tick_index + 1, extra);
			}
			if (debug_profile) profile_trace += elapsed_usec(stage_started);
		}
	}
	// The persisted action boundary is one presentation beat after the final
	// fixed tick. Author that exact final pile while this kernel and its packed
	// descriptors are already hot instead of constructing a second kernel solely
	// to duplicate tick 48 at tick 49.
	if (capture_trace) {
		if (debug_profile) stage_started = std::chrono::steady_clock::now();
		append_packed_trace_frame(ACTION_TICKS + 1, Array());
		if (debug_profile) profile_trace += elapsed_usec(stage_started);
	}

	if (debug_profile) stage_started = std::chrono::steady_clock::now();
	int64_t moved_count = 0;
	int64_t awake_count = 0;
	for (int index = 0; index < static_cast<int>(bodies.size()); ++index) {
		const Body &body = bodies[index];
		if (abs_i(start_x[index] - body.x) > 180 || abs_i(start_y[index] - body.y) > 180 || abs_i(start_z[index] - body.z) > 180) ++moved_count;
		if (!body.sleeping) ++awake_count;
	}
	int64_t topple_count = 0;
	int64_t upper_lower_count = 0;
	for (int index = 0; index < motion_events.size(); ++index) {
		Dictionary event = motion_events[index];
		const String kind = event.get("kind", "");
		if (kind == "topple") ++topple_count;
		else if (kind == "upper_to_lower") ++upper_lower_count;
	}
	if (debug_profile) profile_final_scan = elapsed_usec(stage_started);
	if (debug_profile) stage_started = std::chrono::steady_clock::now();
	write_back();
	if (debug_profile) profile_writeback = elapsed_usec(stage_started);
	if (debug_profile) stage_started = std::chrono::steady_clock::now();
	Dictionary metrics;
	metrics["fixed_ticks"] = ACTION_TICKS;
	metrics["body_count"] = static_cast<int64_t>(bodies.size());
	metrics["awake_count"] = awake_count;
	metrics["woken_count"] = wake_count;
	metrics["moved_count"] = moved_count;
	metrics["collision_passes"] = 1;
	metrics["collision_count"] = collision_count;
	metrics["topple_count"] = topple_count;
	metrics["upper_lower_fall_count"] = upper_lower_count;
	state["last_events"] = exits;
	state["last_motion_events"] = motion_events;
	state["last_step_metrics"] = metrics;
	Array presentation_events = emit_presentation ? build_presentation_events(metrics) : Array();
	Dictionary result;
	result["events"] = exits;
	result["motion_events"] = motion_events;
	result["presentation_events"] = presentation_events;
	result["metrics"] = metrics;
	result["presentation_trace"] = trace;
	if (capture_trace) result["presentation_trace_packed"] = finish_packed_trace();
	if (debug_profile) {
		profile_result = elapsed_usec(stage_started);
		Dictionary profile;
		profile["pack"] = profile_pack;
		profile["push_integrate_48_ticks"] = profile_push_integrate;
		profile["collision_visited_setup"] = profile_collision_setup;
		profile["grid"] = profile_grid;
		profile["collisions"] = profile_collisions;
		profile["supports"] = profile_supports;
		profile["trace_construction"] = profile_trace;
		profile["final_scan"] = profile_final_scan;
		profile["writeback"] = profile_writeback;
		profile["solver_result_assembly"] = profile_result;
		profile["solver_total"] = elapsed_usec(started);
		result["debug_stage_timing_usec"] = profile;
	}
	return result;
}

Dictionary CoinPusherNativeCore::step_action(Dictionary state, const Dictionary &config) const {
	StepKernel kernel(state, config);
	return kernel.run();
}

Dictionary CoinPusherNativeCore::append_presentation_trace_frame(Dictionary packed_trace, const Dictionary &state, int64_t tick_offset) const {
	Dictionary validation_config;
	if (!validate_step_input(state, validation_config)) return Dictionary();
	Dictionary config;
	config["capture_presentation_trace"] = true;
	config["emit_presentation_events"] = false;
	StepKernel kernel(state, config);
	if (!kernel.load_existing_packed_trace(packed_trace)) return Dictionary();
	if (!kernel.load()) return Dictionary();
	kernel.append_packed_trace_frame(tick_offset, Array());
	return kernel.finish_packed_trace();
}
