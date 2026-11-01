extends "res://scripts/ui/foundation_main.gd"

# Synthetic native integration probe: real widgets, callbacks and entry guards.
# Persistence requests are spies, never proof of Save/cold durability.
var qa_save_requests := 0
var qa_save_queue_requests := 0

func _autosave_foundation_run(_status_text: String = "Autosaved.", _force: bool = false) -> bool:
	qa_save_requests += 1
	return true

func _queue_pending_autosave(_status_text: String, _defer_frames: int, _debounce_override_msec: int = -1, _max_defer_override_msec: int = -1) -> void:
	qa_save_queue_requests += 1
