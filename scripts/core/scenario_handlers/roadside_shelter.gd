extends RefCounted

# Package B remains data-driven.  This allowlisted boundary preserves the
# authenticated command and runtime context byte-for-byte before env06_6 owns
# validation and mutation.

func extension_id() -> String:
	return "roadside_shelter"


func prepare_command(command: Dictionary, context: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"command": command.duplicate(true),
		"context": context.duplicate(true),
		"errors": [],
	}
