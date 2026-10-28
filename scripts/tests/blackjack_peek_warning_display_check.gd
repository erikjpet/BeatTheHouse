extends SceneTree

const View := preload("res://scripts/ui/environment_interaction_view_model.gd")
const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
const Blackjack := preload("res://scripts/games/blackjack.gd")
const Host := preload("res://scripts/ui/foundation_main.gd")
var checks := 0
var failures: Array[String] = []
var facts: Array = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var library := ContentLibrary.new()
	library.load(false)
	var definition := library.game("blackjack")
	var warning := View.game_risk_summary(definition)
	var settings := UserSettings.new()
	var host := Host.new()
	host.user_settings = settings
	for barred in [false,true]:
		var run := RunState.new()
		run.start_new("PEEK-WARNING-DISPLAY-CONTRACT")
		run.current_environment = {"id":"grand_warning_display","archetype_id":"grand_casino","game_ids":["blackjack"],"game_states":{},"economic_profile":{"stake_floor":1,"stake_ceiling":100}}
		var game := Blackjack.new()
		game.setup(definition,library)
		var table := game.generate_environment_state(run,run.current_environment,run.create_rng("table"))
		table["barred"] = barred
		table["barred_reason"] = "June will not deal to you again after the caught hole-card peek."
		run.current_environment.game_states["blackjack"] = table
		var before := run.to_save_snapshot()
		var object_state := game.environment_object_state(run,run.current_environment)
		var objects := View.interactable_object_view_list(run,library,{"game_sources":[{"id":"blackjack","definition":definition,"object_state":object_state}]})
		var record: Dictionary = {}
		for value in objects:
			if str(value.get("object_id","")) == "game:blackjack": record = value
		if not check(not record.is_empty(),"normal/barred game model produced"):
			continue
		# Only this detached display fixture receives a synthetic safe card anchor.
		record["normalized_rect"] = {"x":0.45,"y":0.35,"w":0.10,"h":0.15}
		record["fixed_slot_geometry"] = true
		for text_size in UserSettings.TEXT_SIZES:
			settings.text_size = text_size
			var canvas := Canvas.new()
			canvas.size = Vector2(1280,720)
			root.add_child(canvas)
			canvas.set_process(false)
			host._apply_accessibility_to_node(canvas,host._accessibility_font_scale(),host._accessibility_control_scale())
			canvas.uses_foundation_snapshot = true
			canvas.foundation_scene_objects = canvas.call("_objects_from_interactable_records",[record])
			canvas.call("_rebuild_scene_object_cache")
			canvas.set_selected_object("game:blackjack")
			var info: Dictionary = canvas.call("_selected_object_info")
			var lines: Array = info.get("lines",[])
			var visible := " ".join(lines)
			var label := "%s/%s" % ["barred" if barred else "normal",text_size]
			check(visible.contains("Risk: "+warning),label+" all warning words survive actual three-line/six-line card limits")
			check(visible.contains("forfeit the hand") and visible.contains("bar this table"),label+" forfeiture and bar visible")
			check(visible.contains("total Heat up to %d" % RunState.BLACKJACK_BACKOFF_HEAT),label+" conditional total-Heat ceiling visible")
			check(visible.contains("dealer attention and modifiers affect risk"),label+" risk qualification visible")
			var card: Rect2 = info.get("rect",Rect2())
			var font := canvas.get_theme_default_font()
			var fitted: Array = []
			for line in lines:
				var drawn: String = canvas.call("_fit_draw_text",str(line),font,9,card.size.x-Canvas.OBJECT_INFO_PADDING_X*2.0)
				fitted.append(drawn)
				check(drawn == str(line),label+" measured body width does not trim wrapped line")
			var object_data: Dictionary = info.get("object",{})
			var y: float = canvas.call("_selected_info_body_text_start_y",object_data,card,true)
			var action_height: float = canvas.call("_selected_info_action_area_height",object_data,card.size.x-Canvas.OBJECT_INFO_PADDING_X*2.0)
			var bottom := card.end.y-Canvas.OBJECT_INFO_BOTTOM_PADDING-(Canvas.OBJECT_INFO_ACTION_GAP+action_height if action_height>0 else 0.0)
			check(y+float(lines.size()-1)*Canvas.OBJECT_INFO_LINE_HEIGHT <= bottom,label+" every warning line fits drawn body height")
			var prior := record.duplicate(true)
			prior["type"] = "game"
			prior["description"] = record.get("short_description","")
			prior["risk_summary"] = "%s A caught Peek can forfeit the hand, bar this table, and push total Heat as high as %d. Risk depends on dealer attention and current modifiers." % [definition.cheat_actions[0].summary,RunState.BLACKJACK_BACKOFF_HEAT]
			var prior_lines: Array = canvas.call("_object_info_lines",prior)
			check(not " ".join(prior_lines).contains(str(prior.risk_summary)),label+" original long warning reproduces truncation")
			facts.append({"state":label,"warning":warning,"lines":lines,"drawn":fitted,"card":str(card),"body_font_size":9,"effective_font_scale":host._accessibility_font_scale(),"original_lines":prior_lines})
			canvas.free()
		check(run.to_save_snapshot() == before,"display/model projections preserve full run state and RNG")
	host.free()
	var report := {"checks":checks,"failures":failures,"facts":facts,"fidelity":"Real view-model game objects, normal/barred Blackjack object-state projection and PixelSceneCanvas selected-card wrapping/width/body-height methods under existing small/normal/large accessibility settings. Synthetic detached card anchor; no gameplay action, pointer/browser or deployed acceptance claim."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	print("PEEK_WARNING_DISPLAY checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok
