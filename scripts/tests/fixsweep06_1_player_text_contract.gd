extends SceneTree

const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunReportViewModelScript := preload("res://scripts/ui/run_report_view_model.gd")
const FoundationHudViewModelScript := preload("res://scripts/ui/foundation_hud_view_model.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")

const PROVIDERS := {
	"bar_dice": preload("res://scripts/games/bar_dice.gd"),
	"baccarat": preload("res://scripts/games/baccarat.gd"),
	"blackjack": preload("res://scripts/games/blackjack.gd"),
	"roulette": preload("res://scripts/games/roulette.gd"),
	"slot": preload("res://scripts/games/slot.gd"),
	"video_poker": preload("res://scripts/games/video_poker.gd"),
}
const REJECTION_CODES := ["invalid_intent", "pending_delivery", "stale_boundary", "unknown_receipt", "invalid_proposal", "apply_receipt_rejected", "environment_turn_failed", "invalid_cache", "internal_fail_closed"]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_authority_copy()
	_check_currency_copy()
	_check_clock_copy()
	_check_plural_and_sentence_copy()
	_check_object_labels()
	_check_title_assets()
	if failures.is_empty():
		print("FIXSWEEP06_1_PLAYER_TEXT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_authority_copy() -> void:
	var app := FoundationMainScript.new()
	for provider_id in PROVIDERS:
		app.set("current_game", PROVIDERS[provider_id].new())
		for code in REJECTION_CODES:
			var result: Dictionary = app.call("_sealed_action_host_rejection", code, "Blackjack diagnostic for %s" % provider_id)
			var message := str(result.get("message", ""))
			if message.findn("blackjack") >= 0 or str(result.get("message_key", "")).is_empty() or str(result.get("diagnostic_detail", "")).find("Blackjack diagnostic") < 0:
				failures.append("BTH-055: %s/%s did not separate neutral player copy from diagnostic detail: %s" % [provider_id, code, JSON.stringify(result)])
	app.free()


func _check_currency_copy() -> void:
	var module := GameModuleScript.new()
	if not module.has_method("finalize_routed_player_message"):
		failures.append("BTH-056: GameModule has no post-routing structured player-message boundary.")
		module.free()
		return
	for game_id in ["blackjack", "baccarat", "roulette", "bar_dice", "video_poker", "pull_tabs"]:
		for casino in [false, true]:
			var run := RunStateScript.new()
			run.grand_casino_chips = 100
			var environment_id := "grand_casino_high_limit" if casino else "bar"
			var result := {"ok": true, "game_id": game_id, "source_id": game_id, "environment_id": environment_id, "environment_archetype_id": environment_id, "bankroll_delta": 12, "message": "Bankroll +12", "deltas": GameModuleScript.empty_result_deltas()}
			(result.deltas as Dictionary)["bankroll_delta"] = 12
			var routed := run.route_grand_casino_game_currency(result, result.deltas)
			module.call("finalize_routed_player_message", result, routed)
			var message := str(result.get("message", ""))
			if casino and (message.findn("chip") < 0 or message.find("$") >= 0 or int(routed.get("chips_delta", 0)) != 12 or int(routed.get("bankroll_delta", 0)) != 0):
				failures.append("BTH-056: %s casino result did not name the routed chip balance: %s" % [game_id, JSON.stringify(result)])
			if not casino and (message.findn("cash") < 0 or message.findn("chip") >= 0 or int(routed.get("bankroll_delta", 0)) != 12):
				failures.append("BTH-056: %s non-casino result did not retain cash semantics: %s" % [game_id, JSON.stringify(result)])
	var meaningful := {"message": "Fixture all-in wager lost.", "deltas": {"bankroll_delta": -2}}
	module.call("finalize_routed_player_message", meaningful, meaningful.deltas)
	if not str(meaningful.get("message", "")).begins_with("Fixture all-in wager lost.") or str(meaningful.get("message", "")).findn("cash") < 0:
		failures.append("BTH-056: post-routing copy discarded meaningful game result context: %s" % JSON.stringify(meaningful))
	module = null


func _check_clock_copy() -> void:
	for total in [0, 720, 780, 1500]:
		var run := RunStateScript.new()
		run.game_clock_minutes = total
		var canonical := "Day %d %s" % [run.game_day(), _expected_time(total)]
		if run.clock_display_text() != canonical:
			failures.append("BTH-057: RunState clock is not canonical at %d: %s" % [total, run.clock_display_text()])
		var hud := FoundationHudViewModelScript.clock_model(run)
		if str(hud.get("clock_display", "")) != canonical:
			failures.append("BTH-057: HUD clock diverged at %d: %s" % [total, JSON.stringify(hud)])
		var report_clock := RunReportViewModelScript.format_game_clock(total)
		if report_clock != canonical:
			failures.append("BTH-057: replay clock diverged at %d: %s" % [total, report_clock])
		var outcome := RunReportViewModelScript.build_outcome({"game_clock_minutes": total, "current_environment": {"display_name": "Fixture"}, "run_status": "failed", "narrative_flags": {}}, {})
		if str(outcome.get("where", "")).find(_expected_time(total)) < 0:
			failures.append("BTH-057: outcome clock diverged at %d: %s" % [total, JSON.stringify(outcome)])


func _expected_time(total: int) -> String:
	var minute_of_day := posmod(total, 1440)
	var hour_24 := int(minute_of_day / 60)
	var hour_12 := hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	return "%d:%02d %s" % [hour_12, minute_of_day % 60, "AM" if hour_24 < 12 else "PM"]


func _check_plural_and_sentence_copy() -> void:
	var text_script: Script = load("res://scripts/ui/player_text.gd") as Script
	if text_script == null:
		failures.append("BTH-058: shared count-keyed player-text formatter does not exist.")
		return
	var formatter: Variant = text_script.new()
	for count in [0, 1, 2, 101]:
		var ticket := str(formatter.call("count_text", "ticket", count))
		var row := str(formatter.call("count_text", "active_row", count))
		var action := str(formatter.call("count_text", "action", count))
		if (count == 1 and (ticket != "1 ticket" or row != "1 active row" or action != "1 action")) or (count != 1 and (ticket.find("tickets") < 0 or row.find("active rows") < 0 or action.find("actions") < 0)):
			failures.append("BTH-058: count-keyed grammar failed at %d: %s / %s / %s" % [count, ticket, row, action])
	var joined := str(formatter.call("join_sentences", ["Natural hand.", "0 won, 1 lost, 0 pushed."]))
	if joined != "Natural hand. 0 won, 1 lost, 0 pushed.":
		failures.append("BTH-058: sentence composition omitted a separator: %s" % joined)
	formatter = null


func _check_object_labels() -> void:
	var canvas := PixelSceneCanvasScript.new()
	var font := ThemeDB.fallback_font
	var full := "Gas Station Casino Numbers Booth"
	var fitted := str(canvas.call("_fit_draw_text", full, font, 8, 120.0))
	if fitted == full or not fitted.ends_with("…"):
		failures.append("BTH-024: long object label does not render with an ellipsis: %s" % fitted)
	if not canvas.has_method("object_label_accessibility_snapshot"):
		failures.append("BTH-024: object labels expose no full tooltip/accessibility and two-line contract.")
	else:
		var snapshot: Dictionary = canvas.call("object_label_accessibility_snapshot", full)
		if str(snapshot.get("tooltip", "")) != full or str(snapshot.get("accessibility_name", "")) != full or int(snapshot.get("line_count", 0)) != 2:
			failures.append("BTH-024: long-label accessibility snapshot is incomplete: %s" % JSON.stringify(snapshot))
	canvas.free()


func _check_title_assets() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/environment_ui.json"))
	var modes := {}
	for value in (parsed as Array):
		if typeof(value) == TYPE_DICTIONARY:
			modes[str((value as Dictionary).get("id", ""))] = str((value as Dictionary).get("title_mode", "art"))
	if str(modes.get("grand_casino_high_limit", "")) != "text":
		failures.append("BTH-025: Grand Casino High-Limit does not force text title mode.")
	for path in DirAccess.get_files_at("res://assets/art/ui/environment_titles"):
		if not path.ends_with(".png"):
			continue
		var texture := load("res://assets/art/ui/environment_titles/%s" % path) as Texture2D
		var unsafe := _title_ink_reaches_right_edge(texture.get_image())
		var room_id := path.trim_suffix(".png")
		if unsafe and str(modes.get(room_id, "art")) != "text":
			failures.append("BTH-025: title asset ink reaches the right safety edge without text-mode fallback: %s" % path)


func _title_ink_reaches_right_edge(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var edge := image.get_width() - 8
	for y in range(8, mini(image.get_height(), 36)):
		for x in range(maxi(0, edge), image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a > 0.5 and color.r > 0.82 and color.g > 0.82 and color.b > 0.82:
				return true
	return false
