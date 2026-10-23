extends SceneTree

const Blackjack := preload("res://scripts/games/blackjack.gd")
const TableVisuals := preload("res://scripts/games/table_game_visuals.gd")

class SurfaceProbe:
	extends RefCounted
	var low_detail := false
	var clock := 0.41
	var commands: Array = []
	var arm_lines := 0
	func surface_low_detail_idle() -> bool: return low_detail
	func surface_flicker() -> float: return clock
	func surface_board_size() -> Vector2: return Vector2(900, 430)
	func surface_animation_active(_channel: String) -> bool: return false
	func surface_elapsed(_channel: String) -> float: return 100.0
	func draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0) -> void:
		commands.append(["rect", rect, color, filled, width])
	func draw_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0) -> void:
		commands.append(["line", from, to, color, width])
		if color == Color("#05060a") and width >= 5.0:
			arm_lines += 1
	func draw_polygon(points: PackedVector2Array, colors: PackedColorArray) -> void:
		commands.append(["polygon", points, colors])
	func draw_circle(pos: Vector2, radius: float, color: Color, filled: bool = true, width: float = -1.0) -> void:
		commands.append(["circle", pos, radius, color, filled, width])
	func surface_label(label: String, pos: Vector2, font_size: int, color: Color) -> void:
		commands.append(["label", label, pos, font_size, color])
	func surface_label_centered(label: String, rect: Rect2, font_size: int, color: Color) -> void:
		commands.append(["centered", label, rect, font_size, color])
	func surface_add_invisible_hit(_rect: Rect2, _action: String, _index: int = -1) -> void: pass

func _initialize() -> void:
	var blackjack := Blackjack.new()
	var checks := 0
	# Hold simulation time and semantic state fixed: cadence, hover, and action
	# handoffs must never replace the cast or change its identity/details.
	for phase in ["player_turn", "insurance", "dealer_turn", "resolved", "betting"]:
		for pose in ["idle", "snitch", "covered"]:
			for silhouette in ["coat", "cap", "glasses", "rings"]:
				var state := {
					"phase": phase, "between_hands": phase == "betting",
					"dealer_name": "Fidelity Dealer", "dealer_profile": {"blink_offset": 19},
					"dealer_focus": {"peek_window_open": pose == "covered", "blink": pose == "idle", "eye_offset": 1.5},
					"patrons": [{"name": "Fidelity Patron", "silhouette": silhouette,
						"watching_player": pose == "snitch", "covered": pose == "covered",
						"active_snitch_risk": 55, "tell_active": pose == "snitch", "animation_offset": 120}],
				}
				var original := JSON.stringify(state)
				for shared in [false, true]:
					for dealer in [false, true]:
						var expected: Array = []
						for low_detail in [false, true, false]:
							var surface := SurfaceProbe.new()
							surface.low_detail = low_detail
							if shared:
								if dealer: TableVisuals.draw_dealer_station(surface, state)
								else: TableVisuals.draw_table_patrons(surface, state)
							else:
								blackjack.call("_draw_dealer_station" if dealer else "_draw_table_patrons", surface, state)
							# The shared dealer computes gaze from wall time. Its eyes and
							# meters may move between calls; primitive membership stays fixed.
							var changed := surface.commands.size() != expected.size() if shared and dealer else surface.commands != expected
							if surface.arm_lines != 2 or (not expected.is_empty() and changed):
								push_error("Character fidelity changed: phase=%s pose=%s silhouette=%s shared=%s dealer=%s low_detail=%s arms=%d" % [phase, pose, silhouette, shared, dealer, low_detail, surface.arm_lines])
								quit(1)
								return
							expected = surface.commands
							checks += 1
					if JSON.stringify(state) != original:
						push_error("Drawing mutated the shared character snapshot.")
						quit(1)
						return
	print("TABLE_CHARACTER_FIDELITY_CHECK PASS: %d draw comparisons; blackjack/shared cast, all hand phases, expressions and silhouettes" % checks)
	quit(0)
