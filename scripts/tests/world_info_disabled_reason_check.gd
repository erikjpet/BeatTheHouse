extends SceneTree

const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
const ROOK_REASON := "Rook keeps this door for made company or people he escorts."
var checks := 0
var failures: Array[String] = []

func _init() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	# Exact production locked_reason observed clipped in the ordinary underground
	# on Web. This is a presentation fixture, not a replacement player save.
	var canvas := Canvas.new()
	root.add_child(canvas)
	var object := {"type":"info","label":"Crew Back Room","description":"A private door behind the tables.","cost_summary":"Cost: 0","disabled":true,"enabled":false,"interactive":false,"disabled_reason":ROOK_REASON}
	var lines: Array = canvas._object_info_lines(object)
	_check(" ".join(lines).contains(ROOK_REASON),"The complete Rook escort alternative must remain readable in the disabled card.")
	_check(lines.size() <= canvas.OBJECT_INFO_MAX_LINES,"Disabled explanation exceeded the existing card line budget.")
	for line in lines:
		_check(str(line).length() <= canvas.OBJECT_INFO_MAX_CHARS,"A disabled-card line exceeds the existing wrap width.")
	var visible := Rect2(0,0,900,430)
	var size: Vector2 = canvas._object_info_size("Crew Back Room",lines,"info",visible,object)
	_check(size.x<=visible.size.x and size.y<=visible.size.y,"Wrapped card no longer fits the normal room viewport.")
	_check(not canvas._selected_info_single_action_enabled(object) and not canvas._object_info_is_actionable(object),"Readable requirement must not enable the locked door.")
	var short := object.duplicate(true)
	short["disabled_reason"]="No cash."
	_check(" ".join(canvas._object_info_lines(short)).ends_with("No cash."),"Short explanations changed while wrapping the long reason.")
	for failure in failures: push_error(failure)
	print("Disabled reason card checks: ",checks," failures=",failures.size()," lines=",JSON.stringify(lines))
	canvas.free();quit(0 if failures.is_empty() else 1)
