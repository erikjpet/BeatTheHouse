extends RefCounted

# Bar and Jazz Club sequences remain data-driven. The package adapter preserves
# authenticated command and runtime context fields before env06_6 validates and
# applies the command at its authoritative boundary.

func extension_id() -> String:
	return "bars_road"


func prepare_command(command: Dictionary, context: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"command": command.duplicate(true),
		"context": context.duplicate(true),
		"errors": [],
	}
