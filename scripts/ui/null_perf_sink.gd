class_name NullPerfSink
extends RefCounted


func is_live() -> bool:
	return false


func begin_foundation_frame() -> void:
	pass


func record_foundation_subsystem_usec(_name: String, _elapsed_usec: int) -> void:
	pass
