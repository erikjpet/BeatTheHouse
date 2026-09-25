class_name RoomActionList
extends VBoxContainer

signal action_selected(record: Dictionary, action: Dictionary)

const MIN_TARGET := Vector2(44.0, 44.0)
const PREFERRED_PANEL_WIDTH := 520.0
const PREFERRED_COLUMN_WIDTH := 480.0
const PANEL_EDGE_MARGIN := 16.0
const PANEL_CHROME_HEIGHT := 96.0
const GRID_GAP := 4.0
const SOURCE_INLINE := "inline_actions"
const SOURCE_SEQUENCE := "scenario_sequence_actions"
const SOURCE_AVAILABLE := "available_actions"

var _modal_focus_scope: RefCounted
var _action_dispatcher: Callable
var _launcher: Button
var _modal_layer: Control
var _overlay: Control
var _panel: PanelContainer
var _list: GridContainer
var _close: Button
var _records: Array = []
var _render_signature := ""
var _last_focus_key := ""
var _selection_dispatch_pending := false
var _pending_selection_object_id := ""
var _pending_selection_action_key := ""


func _ready() -> void:
	set_process(false)
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_launcher = Button.new()
	_launcher.text = "More room actions"
	_launcher.tooltip_text = "Open overflow actions and a reachable fallback for every room exit."
	_launcher.custom_minimum_size = MIN_TARGET
	_launcher.clip_text = true
	_launcher.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_launcher.focus_mode = Control.FOCUS_ALL
	_launcher.pressed.connect(open)
	add_child(_launcher)

	# The Web release template strips CanvasLayer, so the modal is a top-level Control
	# sized to the viewport and drawn above the room instead of a separate layer.
	_modal_layer = Control.new()
	_modal_layer.name = "RoomActionModalLayer"
	_modal_layer.top_level = true
	_modal_layer.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_modal_layer)
	_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay = Control.new()
	_overlay.name = "RoomActionOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.mouse_force_pass_scroll_events = false
	_overlay.focus_mode = Control.FOCUS_NONE
	_modal_layer.add_child(_overlay)
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.02, 0.03, 0.05, 0.72)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# PASS keeps descendant buttons eligible for pointer/touch hit-testing while
	# allowing empty panel surroundings to bubble into the STOP overlay shield.
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_overlay.add_child(center)
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.custom_minimum_size = Vector2(MIN_TARGET.x, 0.0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel.focus_mode = Control.FOCUS_NONE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	var heading := Label.new()
	heading.text = "Room actions"
	heading.clip_text = true
	heading.tooltip_text = "These objects remain available here without being drawn on the room canvas."
	stack.add_child(heading)
	_list = GridContainer.new()
	_list.columns = 1
	_list.add_theme_constant_override("h_separation", int(GRID_GAP))
	_list.add_theme_constant_override("v_separation", int(GRID_GAP))
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stack.add_child(_list)
	_close = Button.new()
	_close.text = "Close"
	_close.custom_minimum_size = MIN_TARGET
	_close.clip_text = true
	_close.focus_mode = Control.FOCUS_ALL
	_close.pressed.connect(close)
	stack.add_child(_close)
	get_viewport().size_changed.connect(_sync_panel_width)
	_sync_panel_width()
	set_process_unhandled_input(true)
	render([])


func configure(modal_focus_scope: RefCounted, action_dispatcher: Callable = Callable()) -> void:
	_modal_focus_scope = modal_focus_scope
	_action_dispatcher = action_dispatcher


func has_action_dispatcher() -> bool:
	return _action_dispatcher.is_valid()


func action_dispatcher_matches(expected: Callable) -> bool:
	return _action_dispatcher == expected


func render(records: Array) -> void:
	_enforce_persistent_target_sizes()
	var filtered: Array = []
	for value in records:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var record := (value as Dictionary).duplicate(true)
		if not is_visible_action_list_record(record):
			continue
		filtered.append(record)
	filtered.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := left_value as Dictionary
		var right := right_value as Dictionary
		var left_order := int(left.get("focus_order", 0))
		var right_order := int(right.get("focus_order", 0))
		return str(left.get("object_id", "")) < str(right.get("object_id", "")) if left_order == right_order else left_order < right_order
	)
	_records = filtered
	var next_signature := _records_signature(_records)
	if next_signature != _render_signature:
		_render_signature = next_signature
		_rebuild_rows()
	_sync_panel_width()
	visible = not _records.is_empty()
	_launcher.visible = visible
	_launcher.text = "More room actions (%d)" % _records.size()
	if _records.is_empty():
		close()


func open() -> void:
	if _records.is_empty() or _overlay.visible:
		return
	_enforce_persistent_target_sizes()
	_sync_panel_width()
	_overlay.visible = true
	_panel.visible = true
	# Hidden container children do not participate in a layout pass. Reapply the
	# viewport cap after showing the panel so a prior desktop allocation cannot
	# survive into the first compact frame.
	_sync_panel_width()
	var controls := _focus_controls()
	var first := controls[0] as Control if not controls.is_empty() else _close
	if _modal_focus_scope != null and _modal_focus_scope.has_method("push_scope"):
		_modal_focus_scope.call("push_scope", _overlay, first, _launcher, controls)
	elif first != null:
		first.grab_focus()


func close() -> void:
	if _overlay == null or not _overlay.visible:
		return
	var scope_was_top := true
	if _modal_focus_scope != null and _modal_focus_scope.has_method("active_root"):
		scope_was_top = _modal_focus_scope.call("active_root") == _overlay
	if _modal_focus_scope != null and _modal_focus_scope.has_method("pop_scope"):
		_modal_focus_scope.call("pop_scope", _overlay)
	_panel.visible = false
	_overlay.visible = false
	_last_focus_key = ""
	if (_modal_focus_scope == null or not _modal_focus_scope.has_method("pop_scope")) \
			and scope_was_top and is_instance_valid(_launcher) and _launcher.visible:
		_launcher.grab_focus()


static func is_visible_overflow_record(record: Dictionary) -> bool:
	return str(record.get("presentation_mode", "room")) == "overflow" \
		and bool(record.get("visible", true)) \
		and bool(record.get("presentation_required", true)) \
		and not str(record.get("object_id", "")).strip_edges().is_empty()


static func is_visible_action_list_record(record: Dictionary) -> bool:
	if is_visible_overflow_record(record):
		return true
	# A delivery contact is deadline-bound and may be temporarily unhittable while
	# its person arrival or another room sequence owns the canvas hit plane. Keep
	# its authenticated handoff action in the reachable drawer as a parallel path.
	if bool(record.get("delivery_contact", false)):
		return str(record.get("presentation_mode", "room")) == "room" \
			and bool(record.get("visible", true)) \
			and bool(record.get("presentation_required", true)) \
			and not str(record.get("object_id", "")).strip_edges().is_empty()
	# A physical door stays rendered in its authored room slot, but camera focus,
	# result cards, and object detail cards can temporarily put that slot outside
	# the usable canvas. Mirror every live travel control here as a safety route so
	# entering a room or inspecting another object can never strand the player.
	return str(record.get("presentation_mode", "room")) == "room" \
		and str(record.get("object_type", "")).strip_edges() == "travel" \
		and bool(record.get("visible", true)) \
		and bool(record.get("presentation_required", true)) \
		and not str(record.get("object_id", "")).strip_edges().is_empty()


static func action_entries_for_record(record: Dictionary) -> Array:
	var entries: Array = []
	var seen_dispatch_identities: Dictionary = {}
	for candidate_source in [SOURCE_INLINE, SOURCE_SEQUENCE, SOURCE_AVAILABLE]:
		var source := str(candidate_source)
		var actions_value: Variant = record.get(source, [])
		if typeof(actions_value) != TYPE_ARRAY:
			continue
		var source_actions := actions_value as Array
		for index in range(source_actions.size()):
			if typeof(source_actions[index]) != TYPE_DICTIONARY:
				continue
			var action := source_actions[index] as Dictionary
			if not _action_is_visible(action):
				continue
			var dispatch_identity := _logical_dispatch_identity(record, action, source)
			if seen_dispatch_identities.has(dispatch_identity):
				continue
			seen_dispatch_identities[dispatch_identity] = true
			var entry := action.duplicate(true)
			entry["_overflow_source"] = source
			entry["_overflow_index"] = index
			entry["_overflow_dispatch_identity"] = dispatch_identity
			entry["_overflow_action_key"] = _action_key(record, source, index, entry)
			entries.append(entry)
	return entries


static func action_is_enabled(record: Dictionary, action: Dictionary) -> bool:
	var record_enabled := bool(record.get("enabled", true))
	var record_interactive := bool(record.get("interactive", record_enabled))
	return record_enabled and record_interactive and bool(action.get("enabled", true))


static func _action_is_visible(action: Dictionary) -> bool:
	if not bool(action.get("visible", true)) \
			or not bool(action.get("presentation_visible", true)) \
			or bool(action.get("hidden", false)) \
			or bool(action.get("hidden_only", false)):
		return false
	var action_id := _first_nonempty([action.get("emit_object_id", ""), action.get("id", "")])
	return not action_id.is_empty()


static func _action_key(record: Dictionary, source: String, index: int, action: Dictionary) -> String:
	var object_id := str(record.get("object_id", "")).strip_edges()
	var effective_scenario_command_id := _effective_scenario_command_id(record, action, source)
	var authority := {
		"object_id": object_id,
		"object_type": str(record.get("object_type", "")).strip_edges(),
		"record_owner_namespace": str(record.get("owner_namespace", "")).strip_edges(),
		"record_stable_object_id": str(record.get("stable_object_id", "")).strip_edges(),
		"record_scenario_owner_namespace": str(record.get("scenario_owner_namespace", "")).strip_edges(),
		"record_scenario_stable_object_id": str(record.get("scenario_stable_object_id", "")).strip_edges(),
		"dispatch_identity": str(action.get("_overflow_dispatch_identity", _logical_dispatch_identity(record, action, source))),
		"emit_object_id": str(action.get("emit_object_id", "")).strip_edges(),
		"action_id": str(action.get("id", "")).strip_edges(),
		"action_scenario_command_id": str(action.get("scenario_command_id", "")).strip_edges(),
		"record_scenario_command_id": str(record.get("scenario_command_id", "")).strip_edges(),
		"effective_scenario_command_id": effective_scenario_command_id,
		"scenario_owner_namespace": _first_nonempty([action.get("scenario_owner_namespace", ""), action.get("owner_namespace", ""), record.get("scenario_owner_namespace", ""), record.get("owner_namespace", ""), "scenario"]),
		"scenario_stable_object_id": _first_nonempty([action.get("scenario_stable_object_id", ""), action.get("stable_object_id", ""), record.get("scenario_stable_object_id", ""), record.get("stable_object_id", ""), object_id]),
		"scenario_idempotency_key": _first_nonempty([action.get("scenario_idempotency_key", ""), record.get("scenario_idempotency_key", "")]),
		"action_origin_owner_namespace": _first_nonempty([action.get("action_origin_owner_namespace", ""), record.get("action_origin_owner_namespace", "")]),
		"action_origin_stable_object_id": _first_nonempty([action.get("action_origin_stable_object_id", ""), record.get("action_origin_stable_object_id", "")]),
		"action_origin_receipt_key": _first_nonempty([action.get("action_origin_receipt_key", ""), record.get("action_origin_receipt_key", "")]),
		"action_origin_boundary_id": _first_nonempty([action.get("action_origin_boundary_id", ""), record.get("action_origin_boundary_id", "")]),
		"action_origin_fingerprint": _first_nonempty([action.get("action_origin_fingerprint", ""), record.get("action_origin_fingerprint", "")]),
		"world_sequence_owner_token": _first_nonempty([action.get("world_sequence_owner_token", ""), record.get("world_sequence_owner_token", "")]),
		"parent_id": _first_nonempty([action.get("parent_id", ""), record.get("parent_id", "")]),
		"source_id": _first_nonempty([action.get("source_id", ""), action.get("hook_id", ""), record.get("source_id", "")]),
		"handler": str(action.get("handler", "")).strip_edges(),
		"inputs": action.get("inputs", {}),
		"cost": int(action.get("cost", 0)),
	}
	return "%s:%s:%d:%s" % [object_id, source, index, JSON.stringify(authority).sha256_text()]


static func _logical_dispatch_identity(record: Dictionary, action: Dictionary, source: String = "") -> String:
	var object_id := str(record.get("object_id", "")).strip_edges()
	var object_type := str(record.get("object_type", "")).strip_edges()
	var scenario_command_id := _effective_scenario_command_id(record, action, source)
	if _uses_scenario_sequence_dispatch(record, source) \
			or object_type == "scenario" \
			or not scenario_command_id.is_empty():
		var owner := _first_nonempty([action.get("scenario_owner_namespace", ""), action.get("owner_namespace", ""), record.get("scenario_owner_namespace", ""), record.get("owner_namespace", ""), "scenario"])
		var stable_id := _first_nonempty([action.get("scenario_stable_object_id", ""), action.get("stable_object_id", ""), record.get("scenario_stable_object_id", ""), record.get("stable_object_id", ""), object_id])
		var world_owner_token := _first_nonempty([action.get("world_sequence_owner_token", ""), record.get("world_sequence_owner_token", "")])
		return "%s:%s:%s:%s" % ["world:%s" % world_owner_token if not world_owner_token.is_empty() else "scenario", owner, stable_id, scenario_command_id]
	var emit_object_id := str(action.get("emit_object_id", "")).strip_edges()
	if not emit_object_id.is_empty():
		return "emit:%s" % emit_object_id
	var action_id := str(action.get("id", "")).strip_edges()
	if object_type == "game_hook":
		return "game_hook:%s:%s:%s" % [
			str(action.get("parent_id", record.get("parent_id", ""))),
			str(action.get("source_id", action.get("hook_id", record.get("source_id", "")))),
			action_id,
		]
	return "record:%s:%s" % [object_id, action_id]


static func _effective_scenario_command_id(record: Dictionary, action: Dictionary, source: String) -> String:
	# Sequence dispatch consumes only the action id. Every other path mirrors
	# FoundationMain: action authority wins over record authority, and an
	# ordinary id becomes a command only for a true scenario record.
	if _uses_scenario_sequence_dispatch(record, source):
		return str(action.get("id", "")).strip_edges()
	var explicit_scenario_command_id := _first_nonempty([
		action.get("scenario_command_id", ""),
		record.get("scenario_command_id", ""),
	])
	if not explicit_scenario_command_id.is_empty():
		return explicit_scenario_command_id
	if str(record.get("object_type", "")).strip_edges() == "scenario":
		return str(action.get("id", "")).strip_edges()
	return ""


static func _uses_scenario_sequence_dispatch(record: Dictionary, source: String) -> bool:
	return source == SOURCE_SEQUENCE \
		or str(record.get("object_type", "")).strip_edges() in [
			"scenario_sequence",
			"scenario_scene_object",
			"scenario_actor",
			"character",
		]


static func _first_nonempty(values: Array) -> String:
	for value in values:
		var text := str(value).strip_edges()
		if not text.is_empty():
			return text
	return ""


func _rebuild_rows() -> void:
	if _list == null:
		return
	var focus_key := _focused_action_key()
	if not focus_key.is_empty():
		_last_focus_key = focus_key
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var preferred: Control = null
	for record_value in _records:
		var record := record_value as Dictionary
		var actions := action_entries_for_record(record)
		if actions.is_empty():
			_add_unavailable_record_row(record)
			continue
		for action_value in actions:
			var action := action_value as Dictionary
			var button := _add_action_row(record, action)
			if str(action.get("_overflow_action_key", "")) == _last_focus_key and not button.disabled:
				preferred = button
	if _overlay != null and _overlay.visible:
		var controls := _focus_controls()
		if preferred == null:
			preferred = controls[0] as Control if not controls.is_empty() else _close
		if _modal_focus_scope != null and _modal_focus_scope.has_method("refresh_scope"):
			_modal_focus_scope.call("refresh_scope", _overlay, preferred, controls)
		if preferred != null:
			preferred.grab_focus()


func _add_action_row(record: Dictionary, action: Dictionary) -> Button:
	var button := Button.new()
	var record_label := str(record.get("label", record.get("object_id", "Room action"))).strip_edges()
	var action_label := str(action.get("label", "")).strip_edges()
	if action_label.is_empty():
		action_label = _first_nonempty([action.get("id", ""), action.get("emit_object_id", ""), "Use"]).replace("_", " ").capitalize()
	var enabled := action_is_enabled(record, action)
	var reason := _disabled_reason(record, action) if not enabled else ""
	button.text = "%s: %s%s" % [record_label, action_label, " - %s" % reason if not reason.is_empty() else ""]
	var description := str(action.get("text", action.get("short_description", record.get("short_description", "")))).strip_edges()
	button.tooltip_text = reason if not reason.is_empty() else description
	button.custom_minimum_size = MIN_TARGET
	button.clip_text = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = not enabled
	var object_id := str(record.get("object_id", ""))
	var action_key := str(action.get("_overflow_action_key", ""))
	button.set_meta("object_id", object_id)
	button.set_meta("action_id", _first_nonempty([action.get("emit_object_id", ""), action.get("id", "")]))
	button.set_meta("action_source", str(action.get("_overflow_source", "")))
	button.set_meta("action_key", action_key)
	button.focus_entered.connect(_remember_focus.bind(action_key))
	button.pressed.connect(_defer_select_action.bind(object_id, action_key))
	_list.add_child(button)
	return button


func _add_unavailable_record_row(record: Dictionary) -> void:
	var button := Button.new()
	var label := str(record.get("label", record.get("object_id", "Room action"))).strip_edges()
	var reason := str(record.get("disabled_reason", "")).strip_edges()
	if reason.is_empty():
		reason = str(record.get("short_description", "")).strip_edges()
	if reason.is_empty() and bool(record.get("enabled", true)) and bool(record.get("interactive", true)):
		reason = "No actions are available."
	if reason.is_empty():
		reason = "Unavailable."
	button.text = "%s - %s" % [label, reason]
	button.tooltip_text = reason
	button.custom_minimum_size = MIN_TARGET
	button.clip_text = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = true
	button.set_meta("object_id", str(record.get("object_id", "")))
	button.set_meta("action_id", "")
	button.set_meta("action_source", "")
	button.set_meta("action_key", "")
	_list.add_child(button)


func _focus_controls() -> Array:
	var controls: Array = []
	if _list != null:
		for child in _list.get_children():
			if child is Button and (child as Button).visible and not (child as Button).disabled:
				controls.append(child)
	if is_instance_valid(_close):
		controls.append(_close)
	return controls


func _defer_select_action(object_id: String, action_key: String) -> void:
	# A touch release is dispatched after its emulated mouse release. Defer any
	# screen transition until both events have unwound so rebuilding the list
	# cannot detach the pressed Control while Viewport still owns touch focus.
	if _selection_dispatch_pending:
		return
	_selection_dispatch_pending = true
	_pending_selection_object_id = object_id
	_pending_selection_action_key = action_key
	set_process(true)


func _process(_delta: float) -> void:
	if not _selection_dispatch_pending:
		set_process(false)
		return
	var object_id := _pending_selection_object_id
	var action_key := _pending_selection_action_key
	_selection_dispatch_pending = false
	_pending_selection_object_id = ""
	_pending_selection_action_key = ""
	set_process(false)
	_select_action(object_id, action_key)


func _select_action(object_id: String, action_key: String) -> void:
	for record_value in _records:
		var record := record_value as Dictionary
		if str(record.get("object_id", "")) != object_id:
			continue
		for action_value in action_entries_for_record(record):
			var action := action_value as Dictionary
			if str(action.get("_overflow_action_key", "")) != action_key:
				continue
			if not action_is_enabled(record, action):
				return
			var record_snapshot := record.duplicate(true)
			var action_snapshot := action.duplicate(true)
			if _action_dispatcher.is_valid():
				if not bool(_action_dispatcher.call(record_snapshot, action_snapshot)):
					return
				action_selected.emit(record_snapshot, action_snapshot)
				if is_open():
					close()
			else:
				action_selected.emit(record_snapshot, action_snapshot)
				close()
			return


func _remember_focus(action_key: String) -> void:
	_last_focus_key = action_key


func _focused_action_key() -> String:
	if _overlay == null or not _overlay.visible or get_viewport() == null:
		return ""
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null or not _overlay.is_ancestor_of(owner):
		return ""
	return str(owner.get_meta("action_key", ""))


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func _sync_panel_width() -> void:
	if _panel == null or _list == null or get_viewport() == null:
		return
	var layout_size := get_viewport_rect().size
	var window := get_window()
	# The project stretches its logical 1280px canvas into the real Window. On a
	# compact native window the viewport therefore remains 1280x720; cap against
	# both authorities so the modal still observes the physical safe rectangle.
	if window != null:
		if window.size.x > 0:
			layout_size.x = minf(layout_size.x, float(window.size.x))
		if window.size.y > 0:
			layout_size.y = minf(layout_size.y, float(window.size.y))
	var available_width := maxf(MIN_TARGET.x, layout_size.x - PANEL_EDGE_MARGIN * 2.0)
	var available_height := maxf(MIN_TARGET.y, layout_size.y - PANEL_EDGE_MARGIN * 2.0)
	var row_stride := MIN_TARGET.y + GRID_GAP
	var available_grid_height := maxf(MIN_TARGET.y, available_height - PANEL_CHROME_HEIGHT)
	var maximum_rows := maxi(1, int(floor((available_grid_height + GRID_GAP) / row_stride)))
	var action_count := _list.get_child_count()
	var column_count := maxi(1, ceili(float(action_count) / float(maximum_rows)))
	_list.columns = column_count
	var preferred_width := PREFERRED_PANEL_WIDTH if column_count == 1 else (
		PREFERRED_COLUMN_WIDTH * float(column_count)
		+ GRID_GAP * float(column_count - 1)
		+ PANEL_EDGE_MARGIN
	)
	_panel.custom_minimum_size.x = minf(preferred_width, available_width)
	# CenterContainer can retain the former preferred allocation for one layout
	# pass after a viewport shrink. Reset against the new combined minimum now so
	# a compact surface never spends a frame outside its safe margins.
	_panel.reset_size()
	var parent_container := _panel.get_parent() as Container
	if parent_container != null:
		parent_container.queue_sort()


func _enforce_persistent_target_sizes() -> void:
	# These controls outlive rebuilt action rows and can be visited by host-wide
	# accessibility passes before this node's first render. Reassert both axes at
	# every public layout boundary; action rows already receive the same floor at
	# construction time.
	for button_value in [_launcher, _close]:
		var button := button_value as Button
		if not is_instance_valid(button):
			continue
		button.custom_minimum_size = Vector2(
			maxf(MIN_TARGET.x, button.custom_minimum_size.x),
			maxf(MIN_TARGET.y, button.custom_minimum_size.y)
		)


func _disabled_reason(record: Dictionary, action: Dictionary) -> String:
	var reason := str(action.get("disabled_reason", record.get("disabled_reason", ""))).strip_edges()
	return reason if not reason.is_empty() else "Unavailable."


func _records_signature(records: Array) -> String:
	var rows: Array = []
	for record_value in records:
		var record := record_value as Dictionary
		rows.append({
			"object_id": str(record.get("object_id", "")),
			"label": str(record.get("label", "")),
			"enabled": bool(record.get("enabled", true)),
			"interactive": bool(record.get("interactive", true)),
			"disabled_reason": str(record.get("disabled_reason", "")),
			"short_description": str(record.get("short_description", "")),
			"focus_order": int(record.get("focus_order", 0)),
			"actions": action_entries_for_record(record),
		})
	return JSON.stringify(rows)


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
