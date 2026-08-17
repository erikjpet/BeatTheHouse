class_name CoinPusherPackedTraceReader
extends RefCounted

# Presentation-only decoder for the native compact replay contract. Packed rows
# arrive in final renderer order; this reader never sorts or mutates authority.
# Only the two frames needed for the current interpolation sample are retained.

const SCHEMA := "coin_pusher_presentation_trace_packed"
const VERSION := 1
const CACHE_LIMIT := 2

var _replay_id := ""
var _packed_source: Dictionary = {}
var _frames: Dictionary = {}
var _recency: Array = []


func frame_count(packed: Dictionary) -> int:
	if not _contract_valid(packed):
		return 0
	return maxi(0, int(packed.get("frame_count", 0)))


func sample(packed: Dictionary, replay_id: String, progress: float) -> Dictionary:
	var count := frame_count(packed)
	if count <= 0:
		return {}
	_select_replay(packed, replay_id)
	var frame_position := clampf(progress, 0.0, 1.0) * float(count - 1)
	var frame_index := clampi(int(floor(frame_position)), 0, count - 1)
	var next_index := mini(frame_index + 1, count - 1)
	var frame := _frame(packed, frame_index)
	var next_frame := _frame(packed, next_index)
	if frame.is_empty() or next_frame.is_empty():
		return {}
	return {
		"frame": frame,
		"next_frame": next_frame,
		"weight": frame_position - float(frame_index),
		"frame_index": frame_index,
		"next_frame_index": next_index,
	}


func clear() -> void:
	_replay_id = ""
	_packed_source = {}
	_frames.clear()
	_recency.clear()


func _select_replay(packed: Dictionary, replay_id: String) -> void:
	# Action counters restart for each run/cabinet, so replay_id alone is not a
	# safe cache key. The packed payload is immutable and ownership-preserved on
	# the internal render path; identity distinguishes two action_1 payloads in
	# constant time without hashing every packed row on every draw.
	if _replay_id == replay_id and is_same(_packed_source, packed):
		return
	_replay_id = replay_id
	_packed_source = packed
	_frames.clear()
	_recency.clear()


func _frame(packed: Dictionary, frame_index: int) -> Dictionary:
	if _frames.has(frame_index):
		_touch(frame_index)
		return _frames[frame_index]
	var decoded := _decode_frame(packed, frame_index)
	if decoded.is_empty():
		return {}
	_frames[frame_index] = decoded
	_touch(frame_index)
	while _recency.size() > CACHE_LIMIT:
		var evicted := int(_recency.pop_front())
		_frames.erase(evicted)
	return decoded


func _touch(frame_index: int) -> void:
	_recency.erase(frame_index)
	_recency.append(frame_index)


func _decode_frame(packed: Dictionary, frame_index: int) -> Dictionary:
	var offsets: Variant = packed.get("frame_offsets", PackedInt32Array())
	var tick_offsets: Variant = packed.get("tick_offsets", PackedInt32Array())
	var upper_phases: Variant = packed.get("upper_phase_fp", PackedInt32Array())
	var lower_phases: Variant = packed.get("lower_phase_fp", PackedInt32Array())
	if offsets.size() <= frame_index + 1 or tick_offsets.size() <= frame_index \
			or upper_phases.size() <= frame_index or lower_phases.size() <= frame_index:
		return {}
	var row_start := int(offsets[frame_index])
	var row_end := int(offsets[frame_index + 1])
	if row_start < 0 or row_end < row_start:
		return {}
	var body_indices: Variant = packed.get("row_body_indices", PackedInt32Array())
	if row_end > body_indices.size():
		return {}
	# Resolve the packed columns once per decoded frame. Looking them up through
	# the Dictionary for every body would move thousands of hash lookups back
	# onto the draw path this compact replay is intended to protect.
	var body_ids: Variant = packed.get("body_ids", PackedStringArray())
	var kinds: Variant = packed.get("body_kinds", PackedStringArray())
	var radii: Variant = packed.get("body_radii", PackedInt32Array())
	var heights: Variant = packed.get("body_heights", PackedInt32Array())
	var masses: Variant = packed.get("body_masses", PackedInt32Array())
	var metadata: Variant = packed.get("body_metadata", [])
	var material: Variant = packed.get("row_material_categories", PackedStringArray())
	var xs: Variant = packed.get("row_x", PackedInt32Array())
	var ys: Variant = packed.get("row_y", PackedInt32Array())
	var zs: Variant = packed.get("row_z", PackedInt32Array())
	var sleeping: Variant = packed.get("row_sleeping", PackedByteArray())
	var rest_states: Variant = packed.get("row_rest_states", PackedStringArray())
	var has_levels: Variant = packed.get("row_has_level", PackedByteArray())
	var levels: Variant = packed.get("row_levels", PackedStringArray())
	var leans: Variant = packed.get("row_lean_milli", PackedInt32Array())
	for descriptor_values in [kinds, radii, heights, masses, metadata]:
		if descriptor_values.size() != body_ids.size():
			return {}
	for row_values in [material, xs, ys, zs, sleeping, rest_states, has_levels, levels, leans]:
		if row_values.size() < row_end:
			return {}
	var bodies: Array = []
	for row_index in range(row_start, row_end):
		var descriptor_index := int(body_indices[row_index])
		if descriptor_index < 0 or descriptor_index >= body_ids.size():
			return {}
		var body := {
			"id": str(body_ids[descriptor_index]),
			"kind": str(kinds[descriptor_index]),
			"material_category": str(material[row_index]),
			"x": int(xs[row_index]),
			"y": int(ys[row_index]),
			"z": int(zs[row_index]),
			"radius": int(radii[descriptor_index]),
			"height": int(heights[descriptor_index]),
			"mass": int(masses[descriptor_index]),
			"sleeping": int(sleeping[row_index]) != 0,
			"rest_state": str(rest_states[row_index]),
		}
		if int(has_levels[row_index]) != 0:
			body["level"] = str(levels[row_index])
		body["lean_milli"] = int(leans[row_index])
		body["metadata"] = metadata[descriptor_index] if typeof(metadata[descriptor_index]) == TYPE_DICTIONARY else {}
		bodies.append(body)
	return {
		"tick_offset": int(tick_offsets[frame_index]),
		"upper_phase_fp": int(upper_phases[frame_index]),
		"lower_phase_fp": int(lower_phases[frame_index]),
		"bodies": bodies,
	}

func _contract_valid(packed: Dictionary) -> bool:
	return str(packed.get("schema", "")) == SCHEMA \
			and int(packed.get("version", 0)) == VERSION \
			and int(packed.get("frame_count", 0)) > 0
