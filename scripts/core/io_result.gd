class_name IoResult
extends RefCounted

const KeysScript := preload("res://scripts/core/keys.gd")

const KEY_OK := KeysScript.OK
const KEY_ERROR := "error"
const KEY_ERROR_CODE := "error_code"
const KEY_MESSAGE := KeysScript.MESSAGE


static func ok(extra: Dictionary = {}) -> Dictionary:
	var result := extra.duplicate(true)
	result[KEY_OK] = true
	result[KEY_ERROR] = int(OK)
	result[KEY_ERROR_CODE] = ""
	if not result.has(KEY_MESSAGE):
		result[KEY_MESSAGE] = ""
	return result


static func failed(error: Error, error_code: String, message: String = "", extra: Dictionary = {}) -> Dictionary:
	var result := extra.duplicate(true)
	result[KEY_OK] = false
	result[KEY_ERROR] = int(error)
	result[KEY_ERROR_CODE] = error_code.strip_edges()
	result[KEY_MESSAGE] = message
	if OS.is_debug_build() and message.strip_edges().is_empty():
		push_warning("Silent I/O failure: %s (error=%d)." % [result[KEY_ERROR_CODE], int(error)])
	return result


static func is_ok(result: Dictionary) -> bool:
	return bool(result.get(KEY_OK, false))


static func assert_shape(result: Dictionary) -> Array[String]:
	if not OS.is_debug_build():
		return []
	var errors: Array[String] = []
	if typeof(result.get(KEY_OK)) != TYPE_BOOL:
		errors.append("ok must be a bool")
	if typeof(result.get(KEY_ERROR)) != TYPE_INT:
		errors.append("error must be an Error/int")
	if typeof(result.get(KEY_ERROR_CODE)) != TYPE_STRING:
		errors.append("error_code must be a String")
	if typeof(result.get(KEY_MESSAGE)) != TYPE_STRING:
		errors.append("message must be a String")
	return errors
