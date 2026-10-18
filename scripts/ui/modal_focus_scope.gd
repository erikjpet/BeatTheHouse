class_name ModalFocusScope
extends RefCounted

# Shared keyboard/controller ownership for stacked modal surfaces. Each scope
# remembers the control that opened it, traps traversal inside the topmost
# visible modal, and restores a valid owner when that modal closes.

var _stack: Array[Dictionary] = []
var _viewport: Viewport
var _redirecting := false
var _block_accept_once := false
var _debug_movement_history: Array[Dictionary] = []
var _debug_sequence := 0


func push_scope(modal_root: Control, initial_focus: Control = null, fallback_focus: Control = null, explicit_controls: Array = []) -> void:
	if not is_instance_valid(modal_root) or not modal_root.is_inside_tree():
		return
	var viewport := modal_root.get_viewport()
	if viewport == null:
		return
	var existing_index := _scope_index(modal_root)
	if existing_index >= 0:
		var existing: Dictionary = _stack[existing_index]
		if initial_focus != null:
			existing["preferred"] = initial_focus
		if fallback_focus != null:
			existing["fallback"] = fallback_focus
		if not explicit_controls.is_empty():
			existing["controls"] = explicit_controls.duplicate()
		_stack.remove_at(existing_index)
		_stack.append(existing)
		_bind_viewport(viewport)
		_focus_top_scope()
		return
	var previous := viewport.gui_get_focus_owner()
	_stack.append({
		"root": modal_root,
		"previous": previous,
		"fallback": fallback_focus,
		"preferred": initial_focus,
		"last": initial_focus,
		"controls": explicit_controls.duplicate(),
	})
	_bind_viewport(viewport)
	_focus_top_scope()


func pop_scope(modal_root: Control) -> void:
	var index := _scope_index(modal_root)
	if index < 0:
		return
	var was_top := index == _stack.size() - 1
	var entry: Dictionary = _stack[index]
	_stack.remove_at(index)
	if not was_top:
		return
	_redirecting = true
	var restore := entry.get("previous", null) as Control
	if not _is_focusable(restore) or _belongs_to(restore, modal_root):
		restore = null
	if not _stack.is_empty():
		var top: Dictionary = _stack[_stack.size() - 1]
		var top_root := top.get("root", null) as Control
		if restore == null or not _belongs_to(restore, top_root):
			restore = _preferred_control(top)
	else:
		var fallback := entry.get("fallback", null) as Control
		if _is_focusable(fallback) and not _belongs_to(fallback, modal_root):
			restore = fallback
		elif restore == null:
			restore = _first_focusable_outside(modal_root)
	if restore != null:
		restore.grab_focus()
	_redirecting = false
	_block_accept_once = false
	if _stack.is_empty():
		_unbind_viewport()


func refresh_scope(modal_root: Control, preferred_focus: Control = null, explicit_controls: Array = []) -> void:
	var index := _scope_index(modal_root)
	if index < 0:
		return
	var entry: Dictionary = _stack[index]
	if preferred_focus != null:
		entry["preferred"] = preferred_focus
	if not explicit_controls.is_empty():
		entry["controls"] = explicit_controls.duplicate()
	_stack[index] = entry
	if index != _stack.size() - 1:
		return
	var owner := _viewport.gui_get_focus_owner() if _viewport != null else null
	if not _is_focusable(owner) or not _belongs_to(owner, modal_root):
		_focus_top_scope()


func handle_input(event: InputEvent) -> bool:
	if _stack.is_empty() or event.is_echo():
		return false
	_prune_invalid_scopes()
	if _stack.is_empty():
		return false
	var dispatch_owner := _viewport.gui_get_focus_owner() if _viewport != null else null
	_debug_record("input_dispatch", event, dispatch_owner, null, 0, false)
	# A modal scope owns the complete navigation gesture. Claiming the release as
	# well as the press prevents Godot's native GUI traversal from applying a
	# second wrap after the scope has already moved focus explicitly.
	if not event.is_pressed():
		if _is_focus_navigation_event(event):
			_claim_input_event()
			return true
		return false
	var entry: Dictionary = _stack[_stack.size() - 1]
	var modal_root := entry.get("root", null) as Control
	var owner := dispatch_owner
	var accept_pressed := event.is_action_pressed("ui_accept") or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A)
	if accept_pressed and _block_accept_once:
		_claim_input_event()
		_block_accept_once = false
		_focus_top_scope()
		return true
	var backward := event.is_action_pressed("ui_focus_prev")
	var forward := event.is_action_pressed("ui_focus_next")
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_TAB:
		backward = (event as InputEventKey).shift_pressed
		forward = not backward
	var navigation_direction := 0
	if backward or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		navigation_direction = -1
	elif forward or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		navigation_direction = 1
	elif event is InputEventJoypadButton:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP:
				navigation_direction = -1
			JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN:
				navigation_direction = 1
	if navigation_direction != 0:
		_claim_input_event()
		_move_focus(entry, owner, navigation_direction)
		return true
	if not _is_focusable(owner) or not _belongs_to(owner, modal_root):
		if accept_pressed:
			_claim_input_event()
		_focus_top_scope()
		return accept_pressed
	return false


func _is_focus_navigation_event(event: InputEvent) -> bool:
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_TAB:
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		return true
	return event.is_action_pressed("ui_focus_prev") \
		or event.is_action_released("ui_focus_prev") \
		or event.is_action_pressed("ui_focus_next") \
		or event.is_action_released("ui_focus_next") \
		or event.is_action_pressed("ui_left") \
		or event.is_action_released("ui_left") \
		or event.is_action_pressed("ui_right") \
		or event.is_action_released("ui_right") \
		or event.is_action_pressed("ui_up") \
		or event.is_action_released("ui_up") \
		or event.is_action_pressed("ui_down") \
		or event.is_action_released("ui_down")


func _claim_input_event() -> void:
	if _viewport != null:
		_viewport.set_input_as_handled()


func active_root() -> Control:
	_prune_invalid_scopes()
	if _stack.is_empty():
		return null
	return _stack[_stack.size() - 1].get("root", null) as Control


func debug_movement_history() -> Array:
	return _debug_movement_history.duplicate(true)


func clear_debug_movement_history() -> void:
	_debug_movement_history.clear()
	_debug_sequence = 0


func clear() -> void:
	_stack.clear()
	_block_accept_once = false
	_redirecting = false
	_unbind_viewport()


func _bind_viewport(viewport: Viewport) -> void:
	if _viewport == viewport:
		return
	_unbind_viewport()
	_viewport = viewport
	var callback := Callable(self, "_on_gui_focus_changed")
	if not _viewport.gui_focus_changed.is_connected(callback):
		_viewport.gui_focus_changed.connect(callback)


func _unbind_viewport() -> void:
	if _viewport != null:
		var callback := Callable(self, "_on_gui_focus_changed")
		if _viewport.gui_focus_changed.is_connected(callback):
			_viewport.gui_focus_changed.disconnect(callback)
	_viewport = null


func _on_gui_focus_changed(control: Control) -> void:
	_debug_record("focus_changed", null, null, control, 0, _redirecting)
	if _redirecting or _stack.is_empty():
		return
	_prune_invalid_scopes()
	if _stack.is_empty():
		return
	var index := _stack.size() - 1
	var entry: Dictionary = _stack[index]
	var modal_root := entry.get("root", null) as Control
	if _is_focusable(control) and _belongs_to(control, modal_root):
		entry["last"] = control
		_stack[index] = entry
		return
	_block_accept_once = true
	_focus_top_scope()


func _focus_top_scope() -> void:
	_prune_invalid_scopes()
	if _stack.is_empty():
		return
	var entry: Dictionary = _stack[_stack.size() - 1]
	var target := _preferred_control(entry)
	if target == null:
		return
	_redirecting = true
	target.grab_focus()
	_redirecting = false
	entry["last"] = target
	_stack[_stack.size() - 1] = entry


func _preferred_control(entry: Dictionary) -> Control:
	var modal_root := entry.get("root", null) as Control
	for key in ["last", "preferred"]:
		var candidate := entry.get(key, null) as Control
		if _is_focusable(candidate) and _belongs_to(candidate, modal_root):
			return candidate
	var controls := _controls_for_entry(entry)
	return controls[0] if not controls.is_empty() else null


func _move_focus(entry: Dictionary, owner: Control, direction: int) -> void:
	var controls := _controls_for_entry(entry)
	if controls.is_empty():
		return
	var index := controls.find(owner)
	if index < 0:
		index = 0 if direction < 0 else -1
	var target: Control = controls[posmod(index + direction, controls.size())]
	_debug_record("scoped_move", null, owner, target, direction, true)
	_redirecting = true
	target.grab_focus()
	_redirecting = false
	var stack_index := _stack.size() - 1
	entry["last"] = target
	_stack[stack_index] = entry


func _controls_for_entry(entry: Dictionary) -> Array[Control]:
	var controls: Array[Control] = []
	var modal_root := entry.get("root", null) as Control
	var explicit: Array = entry.get("controls", [])
	if not explicit.is_empty():
		# Preserve the authored order for controls that are still live, then merge
		# any control that became visible/enabled after the last host refresh. World
		# Map camera settling can reveal a destination without rebuilding the stored
		# array in that exact frame; traversal must reflect the live modal, not a
		# stale visibility snapshot.
		for value in explicit:
			var control := value as Control
			if _is_focusable(control) and _belongs_to(control, modal_root) and not controls.has(control):
				controls.append(control)
		if modal_root != null:
			for node in modal_root.find_children("*", "Control", true, false):
				var live_control := node as Control
				if _is_focusable(live_control) and not controls.has(live_control):
					controls.append(live_control)
		entry["controls"] = controls.duplicate()
		return controls
	if modal_root == null:
		return controls
	if _is_focusable(modal_root):
		controls.append(modal_root)
	for node in modal_root.find_children("*", "Control", true, false):
		var control := node as Control
		if _is_focusable(control) and not controls.has(control):
			controls.append(control)
	return controls


func _first_focusable_outside(excluded_root: Control) -> Control:
	if _viewport == null:
		return null
	for node in _viewport.find_children("*", "Control", true, false):
		var control := node as Control
		if _is_focusable(control) and not _belongs_to(control, excluded_root):
			return control
	return null


func _scope_index(modal_root: Control) -> int:
	for index in range(_stack.size()):
		if _stack[index].get("root", null) == modal_root:
			return index
	return -1


func _prune_invalid_scopes() -> void:
	for index in range(_stack.size() - 1, -1, -1):
		var modal_root := _stack[index].get("root", null) as Control
		if not is_instance_valid(modal_root) or not modal_root.is_inside_tree() or not modal_root.is_visible_in_tree():
			_stack.remove_at(index)
	if _stack.is_empty():
		_unbind_viewport()


func _debug_record(kind: String, event: InputEvent, source: Control, target: Control, direction: int, claimed_or_redirecting: bool) -> void:
	_debug_sequence += 1
	var event_snapshot := {
		"pressed": event.is_pressed() if event != null else false,
		"echo": event.is_echo() if event != null else false,
		"keycode": int((event as InputEventKey).keycode) if event is InputEventKey else 0,
		"shift": (event as InputEventKey).shift_pressed if event is InputEventKey else false,
		"joy_button": (event as InputEventJoypadButton).button_index if event is InputEventJoypadButton else -1,
		"focus_prev": event.is_action_pressed("ui_focus_prev") if event != null else false,
		"focus_next": event.is_action_pressed("ui_focus_next") if event != null else false,
	}
	_debug_movement_history.append({
		"sequence": _debug_sequence,
		"kind": kind,
		"event": event_snapshot,
		"source": _debug_control_identity(source),
		"target": _debug_control_identity(target),
		"direction": direction,
		"claimed_or_redirecting": claimed_or_redirecting,
		"active_root": _debug_control_identity(_stack[_stack.size() - 1].get("root", null) as Control) if not _stack.is_empty() else "<none>",
	})
	if _debug_movement_history.size() > 128:
		_debug_movement_history.pop_front()


func _debug_control_identity(control: Control) -> String:
	if not is_instance_valid(control):
		return "<null>"
	var node_id := str(control.get_meta("node_id", "")).strip_edges()
	var text := (control as Button).text.strip_edges() if control is Button else ""
	return "%s[node_id=%s,text=%s,id=%d]" % [control.name, node_id, text, control.get_instance_id()]


func _belongs_to(control: Control, modal_root: Control) -> bool:
	return control != null and modal_root != null and (control == modal_root or modal_root.is_ancestor_of(control))


func _is_focusable(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_inside_tree() or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	if control.focus_mode == Control.FOCUS_ACCESSIBILITY and (control.get_tree() == null or not control.get_tree().is_accessibility_enabled()):
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	return true
