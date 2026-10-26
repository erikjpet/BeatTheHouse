extends SceneTree

const Scope = preload("res://scripts/ui/modal_focus_scope.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1280,720)
	await _freed_opener()
	await _rebuilt_focused_item()
	await _freed_explicit_control()
	await _freed_modal()
	print("MODAL_FOCUS_LIFETIME checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _fixture() -> Dictionary:
	var owner=Control.new();root.add_child(owner);owner.size=Vector2(1000,650)
	var opener=_button(owner,"Opener",Vector2(20,20))
	var fallback=_button(owner,"Outside fallback",Vector2(20,80))
	var modal=Control.new();owner.add_child(modal);modal.position=Vector2(300,20);modal.size=Vector2(500,500)
	var item=_button(modal,"Item action",Vector2(20,20))
	var close_button=_button(modal,"Close",Vector2(20,80))
	opener.grab_focus()
	return {"owner":owner,"opener":opener,"fallback":fallback,"modal":modal,"item":item,"close":close_button,"scope":Scope.new()}

func _button(parent: Control, text: String, position: Vector2) -> Button:
	var button=Button.new();button.text=text;button.position=position;button.size=Vector2(180,44);parent.add_child(button)
	return button

func _freed_opener() -> void:
	var f=_fixture();var scope=f.scope
	scope.push_scope(f.modal,f.close,f.fallback)
	_check(root.gui_get_focus_owner()==f.close,"opening did not focus modal")
	f.opener.queue_free();await process_frame;await process_frame
	scope.pop_scope(f.modal)
	_check(not scope._redirecting,"closing a freed opener left focus redirection locked")
	_check(scope.active_root()==null,"closing a freed opener left a modal scope")
	_check(root.gui_get_focus_owner()==f.fallback,"closing did not restore live outside fallback")
	await _dispose(f)

func _rebuilt_focused_item() -> void:
	var f=_fixture();var scope=f.scope
	scope.push_scope(f.modal,f.item)
	f.item.queue_free()
	scope.refresh_scope(f.modal,f.close)
	_check(root.gui_get_focus_owner()==f.close,"queued item retained focus until deletion")
	await process_frame;await process_frame
	scope.refresh_scope(f.modal,f.close)
	_check(root.gui_get_focus_owner()==f.close,"rebuilt item did not fall back to live Close control")
	_check(not scope._redirecting,"rebuilt item left focus redirection locked")
	var event=InputEventKey.new();event.keycode=KEY_TAB;event.pressed=true
	_check(scope.handle_input(event),"Tab stopped being owned by the live modal")
	_check(root.gui_get_focus_owner()==f.close,"Tab selected a retired item control")
	scope.pop_scope(f.modal)
	_check(root.gui_get_focus_owner()==f.opener,"live opener restoration regressed")
	await _dispose(f)

func _freed_explicit_control() -> void:
	var f=_fixture();var scope=f.scope
	scope.push_scope(f.modal,f.close,f.fallback,[f.item,f.close])
	f.item.queue_free();await process_frame;await process_frame
	var event=InputEventKey.new();event.keycode=KEY_TAB;event.pressed=true
	_check(scope.handle_input(event),"stale explicit traversal control broke Tab handling")
	_check(root.gui_get_focus_owner()==f.close,"stale explicit control displaced live modal focus")
	scope.pop_scope(f.modal)
	await _dispose(f)

func _freed_modal() -> void:
	var f=_fixture();var scope=f.scope
	scope.push_scope(f.modal,f.close,f.fallback)
	f.modal.queue_free();await process_frame;await process_frame
	_check(scope.active_root()==null and scope._stack.is_empty(),"retired modal was not pruned")
	var event=InputEventKey.new();event.keycode=KEY_TAB;event.pressed=true
	_check(not scope.handle_input(event),"retired modal still consumed navigation")
	await _dispose(f)

func _dispose(f: Dictionary) -> void:
	f.scope.clear();f.owner.queue_free();await process_frame;await process_frame

func _check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
