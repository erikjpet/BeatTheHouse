extends SceneTree

# Source-prepared component regression. No event choice is ever dispatched.
# Synthetic Grand component context; no captured pre-Read save is fabricated.
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
	check(detail.begins_with("Heat +3"), "existing public Heat cost is first in the detail")
	check(detail.contains(str(read.get("text", ""))), "authored route prose is retained")
	check(not str(read.get("text", "")).contains("Heat +3"), "baseline prose-only renderer omitted the public cost")
	var actions: Array = host._event_inline_response_actions("scenario_audit_roster", option.get("choices", []))
	check(actions.size() == option.get("choices", []).size(), "same response count and dispatch identities")
	check(str(actions[0].get("text", "")).begins_with("Heat +3"), "actual inline response model carries the disclosed cost")
	_format_controls(host)
	_catalog_cost_controls(host, library)
	for text_size in UserSettings.TEXT_SIZES:
		host.user_settings.text_size = text_size
		_native_detail(host, read, text_size)
		for small in [false, true]:
			await _canvas_detail(host, option, actions, text_size, small)
	check(Fingerprint.canonical_fingerprint(host.run_state.to_save_snapshot()) == before, "all previews/render readers preserve full state including Heat, knowledge, history and RNG")
	check(Fingerprint.canonical_fingerprint(library.event("scenario_audit_roster")) == authored_before, "authored effects and content remain unchanged")
	host.free()
	finish()

func _format_controls(host: Host) -> void:
	check(host._event_choice_action_detail({"text": "Authored answer."}) == "Authored answer.", "prose without public terms remains exact")
	check(host._event_choice_action_detail({}) == "Resolve this response.", "existing empty-choice fallback remains")
	check(host._event_choice_action_detail({"consequence_summary": "Heat +3"}) == "Heat +3", "terms-only choice retains disclosure")
	check(host._event_choice_action_detail({"text": "Heat +3", "impact_summary": "Heat +3"}) == "Heat +3", "existing exact disclosure is not duplicated")
	check(host._event_choice_action_detail({"text": "Keep the exact item.", "impact_summary": "  ", "consequence_summary": "No effect"}) == "No effect\nKeep the exact item.", "empty public impact falls back to the existing consequence summary")
	var hidden := host._event_choice_action_detail({"text": "Take a chance.", "consequence_summary": "Hidden", "consequences": {"suspicion_delta": 99}, "effects_hidden": true})
	check(hidden == "Hidden\nTake a chance." and not hidden.contains("99"), "detail never derives or leaks hidden effects")
	check(host._event_choice_action_detail({"text": "Offer.", "impact_summary": "Bankroll -5", "consequence_summary": "Old terms"}) == "Bankroll -5\nOffer.", "resolved public impact takes precedence over old terms")
	check(host._event_choice_action_detail({"text": "Refuse.", "impact_summary": "Heat +4", "consequence_summary": "Next action forces travel"}) == "Heat +4\nRefuse.", "descriptive authored terms cannot displace a resolved public Heat cost")

func _native_detail(host: Host, choice: Dictionary, text_size: String) -> void:
	var stack := VBoxContainer.new()
	root.add_child(stack)
	host._add_event_choice_action_option(stack, "scenario_audit_roster", choice)
	var labels: Array = []
	for child in stack.get_children():
		if child is Label: labels.append(child)
	if check(not labels.is_empty(), text_size + " native action detail label exists"):
		var label: Label = labels[0]
		check(label.text.begins_with("Heat +3") and label.max_lines_visible == Host.EVENT_CHOICE_TEXT_MAX_LINES, text_size + " native label begins with cost under the unchanged2-line policy")
	stack.queue_free()

func _catalog_cost_controls(host: Host, library: ContentLibrary) -> void:
	# These real authored summaries omit a Heat amount. Preserve the existing
	# resolved public terms rather than preferring their descriptive copy.
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
		check(detail.contains(str(spec[2])), "real adjacent resolved Heat term remains disclosed: " + str(spec[0]))
		check(detail.contains(str(choice.get("text", ""))) and Fingerprint.canonical_fingerprint(choice) == original, "adjacent authored prose/effects remain unchanged: " + str(spec[0]))
		if str(spec[0]) == "health_inspector":
			check(detail.contains("Bankroll -20"), "real combined cash and Heat cost retains both public amounts")

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
		check(text.begins_with("Heat +3") and rect.size.y > 0.0, mode + " actual Pixel action detail publishes the cost")
		var font := canvas.get_theme_default_font()
		var paragraph := TextParagraph.new()
		paragraph.width = rect.size.x
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
		paragraph.add_string(text, font, 8)
		check(paragraph.get_line_count() > 0 and paragraph.get_line_range(0).y >= "Heat +3".length(), mode + " full Heat3 term fits the first visible shaped line")
		var card: Rect2 = info.get("rect", Rect2())
		check(card.encloses(rect), mode + " detail is within its card")
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
