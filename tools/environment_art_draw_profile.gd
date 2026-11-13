extends RefCounted

# Bounded QA instrumentation, never loaded by production canvas code.
var frames := PackedInt64Array()
var usec := PackedInt64Array()
var root_calls := 0
var all_calls := 0
var total_usec := 0
var root_usec := 0


func _init() -> void:
	frames.resize(4096)
	usec.resize(4096)
	reset()


func reset() -> void:
	frames.fill(-1)
	usec.fill(0)
	root_calls = 0
	all_calls = 0
	total_usec = 0
	root_usec = 0


func record(elapsed: int, root_call: bool) -> void:
	var frame := Engine.get_process_frames()
	var slot := frame % frames.size()
	if frames[slot] != frame:
		frames[slot] = frame
		usec[slot] = 0
	usec[slot] += elapsed
	total_usec += elapsed
	all_calls += 1
	if root_call:
		root_calls += 1
		root_usec += elapsed


func result() -> Dictionary:
	var samples: Array[int] = []
	for index in range(frames.size()):
		if frames[index] >= 0:
			samples.append(usec[index])
	samples.sort()
	return {"root_cpu_ms": float(root_usec) / float(maxi(root_calls, 1)) / 1000.0, "child_cpu_ms": float(total_usec - root_usec) / float(maxi(root_calls, 1)) / 1000.0, "root_draw_calls": root_calls, "all_draw_callbacks": all_calls, "mean_cpu_ms_per_root_draw": float(total_usec) / float(maxi(root_calls, 1)) / 1000.0, "p95_cpu_ms_per_callback_frame": float(samples[mini(samples.size() - 1, int(samples.size() * 0.95))]) / 1000.0 if not samples.is_empty() else 0.0, "source": "timed_original_draw_bodies_including_retained_art_children", "frame_samples": samples.size(), "callback_frame_usec": samples}
