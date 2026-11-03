extends SceneTree

# Historical entry point retained; selection details now show authored narrative.
# Detached components and synthetic rooms. No event choice is ever dispatched.
const Host := preload("res://scripts/ui/foundation_main.gd")
const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
const Fingerprint := preload("res://scripts/core/game_ritual_runtime.gd")
var checks := 0
var failures: Array[String] = []
var facts: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "explicit isolated component-test root required"):
		finish(); return
	var library := ContentLibrary.new()
	library.load(false)
	root.size = Vector2i(1280, 720)
	var host := Host.new()
	host.library = library
	host.user_settings = UserSettings.new()
	if not check(host._ensure_run_ui_stage_scripts(0), "normal centralized UI dependency loader initializes the detached host"):
		host.free(); finish(); return
	host.run_state = RunState.new()
	host.run_state.start_new("AUDIT-ACTION-COST-DISCLOSURE-COMPONENT")
	host.run_state.current_environment = {"id": "audit_cost_component", "archetype_id": "grand_casino", "kind": "boss", "tier": 5, "event_ids": ["scenario_audit_roster"], "resolved_event_ids": []}
	var before := Fingerprint.canonical_fingerprint(host.run_state.to_save_snapshot())
	var authored := library.event("scenario_audit_roster")
	var authored_before := Fingerprint.canonical_fingerprint(authored)
	var option: Dictionary = host._eligible_event_option_with_context("scenario_audit_roster")
	if not check(not option.is_empty(), "real authored Audit event produces its public choice model in a detached component context"):
		host.free(); finish(); return
	var read: Dictionary = {}
	for value in option.get("choices", []):
		if str(value.get("id", "")) == "read_the_shift": read = value
	if not check(not read.is_empty(), "authored Read the shift choice exists"):
		host.free(); finish(); return
	check(int(read.get("consequences", {}).get("suspicion_delta", 0)) == 3, "existing Heat3 effect retained in the model")
	check(str(read.get("impact_summary", "")).begins_with("Heat +3"), "existing resolved public model already contains the cost")
	var detail := host._event_choice_action_detail(read)
	check(detail == str(read.get("text", "")), "selection detail is exactly the authored narrative")
	check(not detail.contains("Heat +3"), "generated Heat summary is absent from narrative detail")
	var actions: Array = host._event_inline_response_actions("scenario_audit_roster", option.get("choices", []))
	check(actions.size() == option.get("choices", []).size(), "same response count and dispatch identities")
	check(str(actions[0].get("text", "")) == str(read.get("text", "")), "actual inline response model carries only narrative")
	for index in range(actions.size()):
		var choice: Dictionary = option.get("choices", [])[index]
		var token := "event_response:scenario_audit_roster:" + str(choice.get("id", ""))
		check(str(actions[index].get("id", "")) == token and str(actions[index].get("emit_object_id", "")) == token, "exact ordered Audit dispatch identity retained")
	_format_controls(host)
	_catalog_cost_controls(host, library)
	await _side_door_controls(host, library)
	for text_size in UserSettings.TEXT_SIZES:
		host.user_settings.text_size = text_size
		_native_detail(host, read, text_size)
		for small in [false, true]:
			await _canvas_detail(host, option, actions, text_size, small)
	check(Fingerprint.canonical_fingerprint(host.run_state.to_save_snapshot()) == before, "all previews/render readers preserve full state including Heat, knowledge, history and RNG")
	check(Fingerprint.canonical_fingerprint(library.event("scenario_audit_roster")) == authored_before, "authored effects and content remain unchanged")
	host.free()
	finish()

func _side_door_controls(host: Host, library: ContentLibrary) -> void:
	var authored_before := Fingerprint.canonical_fingerprint(library.event("side_door"))
	var environment := {"id": "side_door_component", "archetype_id": "bar", "kind": "casino", "tier": 1, "event_ids": ["side_door"], "resolved_event_ids": []}
	var option: Dictionary = host._eligible_event_option_with_context("side_door", {}, environment)
	if not check(not option.is_empty(), "real Side Door option generated in a synthetic bar context"): return
	var actions: Array = host._event_inline_response_actions("side_door", option.get("choices", []))
	check(actions.size() == 2, "real Clean stop and Back-alley lead remain available")
	for index in range(actions.size()):
		var choice: Dictionary = option.get("choices", [])[index]
		var choice_id := str(choice.get("id", ""))
		var expected := "A quiet shop stop comes into view." if choice_id == "cheap_route" else "The Back Alley route opens. Heat follows."
		var token := "event_response:side_door:" + choice_id
		check(str(actions[index].get("id", "")) == token and str(actions[index].get("emit_object_id", "")) == token, "exact Side Door dispatch identity retained: " + choice_id)
		check(str(choice.get("text", "")) == expected and str(actions[index].get("text", "")) == expected, "exact Side Door narrative only: " + choice_id)
		if choice_id == "cheap_route":
			check(choice.get("consequences", {}).get("set_next_archetypes", []) == ["corner_store", "motel"], "Clean stop retains both destination effects")
		else:
			check(int(choice.get("consequences", {}).get("suspicion_delta", 0)) == 2 and choice.get("consequences", {}).get("add_next_archetypes", []) == ["back_alley"], "Back-alley retains Heat2 and route effects")
			check(bool(choice.get("requires_confirm", false)), "Back-alley confirmation requirement retained")
	for text_size in UserSettings.TEXT_SIZES:
		host.user_settings.text_size = text_size
		for visual in ["event", "character"]:
			var canvas := Canvas.new()
			canvas.size = Vector2(1280, 720)
			canvas.uses_foundation_snapshot = true
			root.add_child(canvas)
			canvas.set_process(false)
			host._apply_accessibility_to_node(canvas, host._accessibility_font_scale(), host._accessibility_control_scale())
			var record := {"object_id": "event:side_door", "object_type": "event", "visual_type": visual, "label": option.get("display_name", ""), "short_description": option.get("summary", ""), "action_summary": option.get("start_summary", ""), "classification_summary": "New lead", "enabled": true, "interactive": true, "normalized_rect": {"x": 0.45, "y": 0.30, "w": 0.08, "h": 0.10}, "fixed_slot_geometry": true, "inline_actions": actions}
			canvas.foundation_scene_objects = canvas._objects_from_interactable_records([record])
			canvas._rebuild_scene_object_cache()
			canvas.set_selected_object("event:side_door")
			var info: Dictionary = canvas._selected_object_info()
			var context := " ".join(info.get("lines", []))
			var mode := "%s/%s" % [text_size, visual]
			check(context.count("A runner knows two ways off the floor.") == 1, mode + " Side Door context appears exactly once")
			check(context.contains("Discovery: New Lead"), mode + " Discovery context remains")
			var distinct := {"type": visual, "interaction_type": "event", "description": "A runner waits.", "action_summary": "Follow the runner.", "classification_summary": "New lead"}
			var distinct_lines := " ".join(canvas._object_info_lines(distinct))
			check(distinct_lines.contains("A runner waits.") and distinct_lines.contains("Follow the runner."), mode + " distinct event action text remains")
			distinct["disabled"] = true
			distinct["disabled_reason"] = "The door is locked."
			var disabled_lines := " ".join(canvas._object_info_lines(distinct))
			check(disabled_lines.contains("The door is locked.") and not disabled_lines.contains("Follow the runner."), mode + " disabled reason retains priority")
			var entries: Array = canvas._selected_info_action_entries_from_info(info)
			check(entries.size() == actions.size(), mode + " both Side Door response buttons remain")
			for index in range(entries.size()):
				check(str(entries[index].get("detail", "")) == str(actions[index].get("text", "")), mode + " Side Door rendered detail contains exact narrative")
			facts.append({"mode": mode, "side_door_context": context, "distinct_context": distinct_lines, "disabled_context": disabled_lines})
			canvas.queue_free()
			await process_frame
	check(Fingerprint.canonical_fingerprint(library.event("side_door")) == authored_before, "Side Door authored content and effects unchanged")

func _format_controls(host: Host) -> void:
	check(host._event_choice_action_detail({"text": "Authored answer."}) == "Authored answer.", "prose without public terms remains exact")
	check(host._event_choice_action_detail({}) == "Resolve this response.", "existing empty-choice fallback remains")
	check(host._event_choice_action_detail({"consequence_summary": "Heat +3"}) == "Resolve this response.", "summary-only choice uses neutral fallback")
	check(host._event_choice_action_detail({"text": "Heat +3", "impact_summary": "Heat +3"}) == "Heat +3", "existing exact disclosure is not duplicated")
	check(host._event_choice_action_detail({"text": "Keep the exact item.", "impact_summary": "  ", "consequence_summary": "No effect"}) == "Keep the exact item.", "empty impact cannot reintroduce a consequence summary")
	var hidden := host._event_choice_action_detail({"text": "Take a chance.", "consequence_summary": "Hidden", "consequences": {"suspicion_delta": 99}, "effects_hidden": true})
	check(hidden == "Take a chance.", "detail never derives or leaks hidden effects or extra summary")
	check(host._event_choice_action_detail({"text": "Offer.", "impact_summary": "Bankroll -5", "consequence_summary": "Old terms"}) == "Offer.", "neither summary field is displayed")
	check(host._event_choice_action_detail({"text": "Refuse.", "impact_summary": "Heat +4", "consequence_summary": "Next action forces travel"}) == "Refuse.", "authored narrative remains exact with multiple summary fields")

func _native_detail(host: Host, choice: Dictionary, text_size: String) -> void:
	var stack := VBoxContainer.new()
	root.add_child(stack)
	host._add_event_choice_action_option(stack, "scenario_audit_roster", choice)
	var labels: Array = []
	for child in stack.get_children():
		if child is Label: labels.append(child)
	if check(not labels.is_empty(), text_size + " native action detail label exists"):
		var label: Label = labels[0]
		check(label.text == str(choice.get("text", "")) and label.max_lines_visible == Host.EVENT_CHOICE_TEXT_MAX_LINES, text_size + " native label contains narrative under unchanged2-line policy")
	stack.queue_free()

func _catalog_cost_controls(host: Host, library: ContentLibrary) -> void:
	# Adjacent real authored choices keep their effects while rendering prose only.
	for spec in [["health_inspector", "slip_twenty", "Heat +1"], ["inspector_return", "refuse", "Heat +4"], ["rival_counter", "tip_off", "Heat +2"]]:
		var definition := library.event(str(spec[0]))
		var choice: Dictionary = {}
		for value in definition.get("payload", {}).get("choices", []):
			if str(value.get("id", "")) == str(spec[1]): choice = value.duplicate(true)
		if not check(not choice.is_empty(), "real adjacent authored choice exists: " + str(spec[0])): continue
		var original := Fingerprint.canonical_fingerprint(choice)
		var public_choice := choice.duplicate(true)
		public_choice["impact_summary"] = host._event_choice_consequence_summary(choice)
		var detail := host._event_choice_action_detail(public_choice)
		check(detail == str(choice.get("text", "")).strip_edges(), "real adjacent narrative excludes generated summaries: " + str(spec[0]))
		check(detail.contains(str(choice.get("text", ""))) and Fingerprint.canonical_fingerprint(choice) == original, "adjacent authored prose/effects remain unchanged: " + str(spec[0]))
		if str(spec[0]) == "health_inspector":
			check(int(public_choice.get("consequences", {}).get("bankroll_delta", 0)) == -20, "real combined cash and Heat effects remain in the model")

func _canvas_detail(host: Host, option: Dictionary, actions: Array, text_size: String, small: bool) -> void:
	var canvas := Canvas.new()
	canvas.size = Vector2(1280, 720)
	root.add_child(canvas)
	canvas.set_process(false)
	host._apply_accessibility_to_node(canvas, host._accessibility_font_scale(), host._accessibility_control_scale())
	canvas.small_screen_mode = small
	canvas.uses_foundation_snapshot = true
	var record := {"object_id": "event:scenario_audit_roster", "object_type": "event", "visual_type": "event", "label": option.get("display_name", ""), "short_description": option.get("summary", ""), "enabled": true, "interactive": true, "normalized_rect": {"x": 0.45, "y": 0.30, "w": 0.08, "h": 0.10}, "fixed_slot_geometry": true, "inline_actions": actions}
	canvas.foundation_scene_objects = canvas._objects_from_interactable_records([record])
	canvas._rebuild_scene_object_cache()
	canvas.set_selected_object("event:scenario_audit_roster")
	var info: Dictionary = canvas._selected_object_info()
	var entries: Array = canvas._selected_info_action_entries_from_info(info)
	var mode := "%s/%s" % [text_size, "small" if small else "normal"]
	if check(entries.size() == actions.size(), mode + " same ordinary inline actions remain present"):
		var entry: Dictionary = entries[0]
		var text := str(entry.get("detail", ""))
		var rect: Rect2 = entry.get("detail_rect", Rect2())
		check(text == str(actions[0].get("text", "")) and not text.contains("Heat +3") and rect.size.y > 0.0, mode + " actual Pixel action detail publishes exact narrative")
		var font := canvas.get_theme_default_font()
		var paragraph := TextParagraph.new()
		paragraph.width = rect.size.x
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
		paragraph.add_string(text, font, 8)
		check(paragraph.get_line_count() > 0 and paragraph.get_line_range(0).y > 0, mode + " narrative has a visible shaped first line")
		var card: Rect2 = info.get("rect", Rect2())
		check(card.encloses(rect), mode + " detail is within its card")
		check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(card), mode + " card remains inside 16:9 viewport")
		if entries.size() > 1:
			var next_button: Rect2 = entries[1].get("button_rect", Rect2())
			check(rect.end.y <= next_button.position.y, mode + " disclosure does not overlap the next choice")
		facts.append({"mode": mode, "detail": text, "detail_rect": str(rect), "card_rect": str(card), "first_line": str(paragraph.get_line_range(0))})
	canvas.queue_free()
	await process_frame

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func finish() -> void:
	var result := {"checks": checks, "failures": failures, "facts": facts, "fidelity": "Authored event choice/public-model and detached native/Pixel rendering only. Synthetic component context and display anchor. No event choice, Heat application, knowledge grant, Save, Continue or gameplay acceptance."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "  "))
	print("EVENT_ACTION_COST_DISCLOSURE checks=%d failures=%s" % [checks, str(failures)])
	quit(0 if failures.is_empty() else 1)
