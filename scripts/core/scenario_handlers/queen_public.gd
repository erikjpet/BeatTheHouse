extends RefCounted

# Package E remains data-driven. This adapter preserves authenticated command
# and runtime context fields before the shared runtime validates and applies
# the command at its authoritative boundary.

func extension_id() -> String:
	return "queen_public"


func prepare_command(command: Dictionary, context: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"command": command.duplicate(true),
		"context": context.duplicate(true),
		"errors": [],
	}
