class_name FoundationTestHarness
extends RefCounted

var failures: Array


func _init(target_failures: Array) -> void:
	failures = target_failures


func _expect(condition: bool, message: String, context: Variant = {}) -> bool:
	if condition:
		return true
	var detail := ""
	if typeof(context) == TYPE_DICTIONARY and not (context as Dictionary).is_empty():
		detail = " context=%s" % JSON.stringify(context)
	elif typeof(context) != TYPE_NIL and str(context).strip_edges() != "":
		detail = " context=%s" % str(context)
	failures.append("%s%s" % [message, detail])
	return false
