extends RefCounted

# Package D remains data-driven. This allowlisted boundary preserves the
# authenticated command and runtime context before env06_6 validates and
# applies the command at its authoritative boundary.

func extension_id() -> String:
	return "punchline_clubs"


func prepare_command(command: Dictionary, context: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"command": command.duplicate(true),
		"context": context.duplicate(true),
		"errors": [],
	}
