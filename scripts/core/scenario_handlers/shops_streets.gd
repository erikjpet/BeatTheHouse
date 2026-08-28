extends RefCounted

# Shops-and-streets sequences stay data-driven: package commands cross this
# boundary unchanged and are then validated by the authoritative runtime.
# Keeping this adapter explicit gives every package a fixed, allowlisted
# extension point without introducing a content scripting VM.

func extension_id() -> String:
	return "shops_streets"


func prepare_command(command: Dictionary, context: Dictionary) -> Dictionary:
	return {"ok": true, "command": command.duplicate(true), "context": context.duplicate(true), "errors": []}
