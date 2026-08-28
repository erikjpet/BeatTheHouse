extends RefCounted


func extension_id() -> String:
	return "semantic_v1"


func prepare_command(command: Dictionary, context: Dictionary) -> Dictionary:
	return {"ok": true, "command": command.duplicate(true), "context": context.duplicate(true), "errors": []}
