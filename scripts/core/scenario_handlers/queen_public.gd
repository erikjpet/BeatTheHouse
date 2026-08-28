extends RefCounted

# Delta Queen and Grand Casino sequences stay data-driven. Commands cross this
# allowlisted package boundary unchanged before the authoritative scenario
# runtime validates and applies them.

func extension_id() -> String:
	return "queen_public"


func prepare_command(command: Dictionary, context: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"command": command.duplicate(true),
		"context": context.duplicate(true),
		"errors": [],
	}
