extends SceneTree

const MainScript = preload("res://scripts/ui/foundation_main.gd")
const CanvasScript = preload("res://scripts/ui/game_surface_canvas.gd")


func _initialize() -> void:
	var passed := _restored_exit_pending_matches_host()
	print(JSON.stringify({
		"check": "coin_pusher_exit_pending_rollback",
		"assertions": 1,
		"saved_states": [false, true],
		"passed": passed,
		"fidelity": "production Main and Canvas capture/change/restore; no scene ready or drawing stubs",
	}))
	quit(0 if passed else 1)


func _restored_exit_pending_matches_host() -> bool:
	# Never enter the tree: production _ready/storage/gameplay must not run.
	var host = MainScript.new()
	var canvas = CanvasScript.new()
	host.game_surface_canvas = canvas
	var passed := true
	for saved_pending in [false, true]:
		host._set_game_exit_settle_active(saved_pending)
		var snapshot: Dictionary = host._foundation_lifecycle_snapshot()
		host._set_game_exit_settle_active(not saved_pending)
		host._restore_foundation_lifecycle_snapshot(snapshot)
		passed = passed \
			and host.game_exit_settle_active == saved_pending \
			and canvas.surface_exit_pending == saved_pending \
			and canvas._surface_action_block_reason("surface_back").is_empty() == (not saved_pending)
	host.game_surface_canvas = null
	canvas.free()
	host.free()
	return passed
