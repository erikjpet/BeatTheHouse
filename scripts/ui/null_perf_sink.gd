class_name NullPerfSink
extends RefCounted

# No-op implementation of the performance telemetry interface, used so normal
# play pays no allocation or instrumentation cost when telemetry is absent.


func is_live() -> bool:
	return false


func begin_foundation_frame() -> void:
	pass


func record_foundation_subsystem_usec(_name: String, _elapsed_usec: int) -> void:
	pass
