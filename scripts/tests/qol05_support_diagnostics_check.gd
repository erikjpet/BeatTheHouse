extends SceneTree

const Main := preload("res://scripts/ui/foundation_main.gd")
const Support := preload("res://scripts/ui/support_diagnostics.gd")
const Identity := preload("res://scripts/core/build_identity.gd")

class Host extends Main:
	var copied := ""
	var opened := ""
	var open_error: Error = OK
	func _write_support_clipboard(text: String) -> void: copied=text
	func _open_support_folder(path: String) -> Error:
		opened=path
		return open_error

class MissingFolder extends SaveService:
	func save_dir() -> String:return "user://qol05_nonexistent_folder"

var checks := 0
var failures: Array[String] = []
func _init() -> void:call_deferred("_run")
func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _keys(value: Dictionary, expected: Array) -> bool:
	var actual := value.keys()
	actual.sort()
	var wanted := expected.duplicate()
	wanted.sort()
	return actual==wanted
func _frames(n: int) -> void:
	for i in range(n):await process_frame

func _run() -> void:
	root.size=Vector2i(1280,720)
	var app := Host.new()
	root.add_child(app)
	await _frames(8)
	app.open_settings_menu()
	await _frames(4)
	var menu: SettingsMenu=app.settings_menu
	_check(menu!=null and menu.visible,"Actual Settings opens")
	_check(menu.copy_diagnostics!=null and menu.copy_diagnostics.text=="Copy diagnostics","Copy diagnostics button exists")
	_check(menu.open_save_folder!=null and menu.open_save_folder.text=="Open save folder","Open save folder button exists")
	_check(app.has_method("support_diagnostics_text") and app.has_method("_open_save_folder"),"Host support actions exist")
	app.save_service.last_save_outcome={"ok":false,"error":ERR_CANT_OPEN,"error_code":"rename_failed","slot_id":"PRIVATE_SLOT_MARKER","path":"C:/Users/PRIVATE_PERSON_MARKER/save.json","message":"PRIVATE_MESSAGE_MARKER","data":{"seed_text":"PRIVATE_SEED_MARKER","bankroll":321}}
	app.save_service.last_load_outcome={"outcome":"loaded-backup","slot_id":"PRIVATE_SLOT_MARKER","primary_exists":true,"primary_loadable":false,"backup_exists":true,"backup_loadable":true,"primary":{"path":"PRIVATE_PATH_MARKER"}}
	app.autosave_last_error_code="disk_full"
	var before_save:=var_to_bytes(app.save_service.last_save_outcome)
	var before_load:=var_to_bytes(app.save_service.last_load_outcome)
	var live_settings:=var_to_bytes(app.user_settings.to_dict())
	menu.draft.music_volume=0.17
	var draft:=var_to_bytes(menu.draft.to_dict())
	menu.copy_diagnostics.pressed.emit()
	var data:Dictionary=JSON.parse_string(app.copied)
	_check(_keys(data,["schema","build","platform","last_save","last_load","autosave_failure_code"]),"Only allowed top-level fields")
	_check(_keys(data.last_save,["ok","error","error_code"]),"Only safe save scalars")
	_check(_keys(data.last_load,["outcome","primary_exists","primary_loadable","backup_exists","backup_loadable"]),"Only safe load status fields")
	_check(_keys(data.build,["version","source_commit","source_tree","export_sha256","identity_source"]),"Only build identity fields")
	_check(data.build.version==Identity.display_version(),"Current BuildIdentity version")
	_check(data.platform==OS.get_name(),"Current platform")
	_check(not data.last_save.ok and int(data.last_save.error)==ERR_CANT_OPEN and data.last_save.error_code=="rename_failed","Save outcome values preserved")
	_check(data.last_load.outcome=="loaded-backup" and data.last_load.primary_exists and not data.last_load.primary_loadable and data.last_load.backup_exists and data.last_load.backup_loadable,"Load outcome values preserved")
	_check(data.autosave_failure_code=="disk_full","Autosave failure code preserved")
	_check(not app.copied.contains("PRIVATE_") and not app.copied.contains("C:/") and not app.copied.contains("bankroll") and not app.copied.contains("seed_text"),"No personal paths/slot/message/save contents")
	_check(var_to_bytes(app.save_service.last_save_outcome)==before_save and var_to_bytes(app.save_service.last_load_outcome)==before_load,"Diagnostics does not mutate outcomes")
	_check(var_to_bytes(app.user_settings.to_dict())==live_settings and var_to_bytes(menu.draft.to_dict())==draft and not menu.draft_committed,"Copy does not apply/discard settings draft")
	_check(menu.visible and menu.status.text=="Diagnostics copied.","Copy feedback stays in Settings")
	_check(menu.focus_controls.has(menu.copy_diagnostics) and menu.copy_diagnostics.focus_mode!=Control.FOCUS_NONE,"Copy belongs to keyboard focus ring")
	menu.copy_diagnostics.grab_focus()
	await _frames(2)
	_check(menu.get_viewport().gui_get_focus_owner()==menu.copy_diagnostics,"Copy can receive keyboard focus")
	menu.apply_viewport_layout(Vector2(375,667))
	_check(menu.action_row.vertical,"Narrow layout keeps existing stacked footer")
	for row in menu.responsive_rows:_check(row.vertical,"Narrow settings row remains stacked")
	for platform in ["Web","Android","iOS"]:_check(not Support.desktop_platform(platform),"No desktop folder on "+platform)
	for platform in ["Windows","Linux","macOS"]:_check(Support.desktop_platform(platform),"Folder available on "+platform)
	_check(menu.open_save_folder.visible==Support.desktop_platform(OS.get_name()),"Actual folder visibility follows platform")
	var poisoned:=Support.snapshot({"ok":false,"error":ERR_FILE_CANT_WRITE,"error_code":"C:/Users/PRIVATE_PERSON_MARKER"},{"outcome":"PRIVATE_LOAD_MARKER","slot_id":"PRIVATE_SLOT_MARKER"},"bad\nPRIVATE_AUTOSAVE_MARKER")
	_check(poisoned.last_save.error_code=="unavailable" and poisoned.last_load.outcome=="unavailable" and poisoned.autosave_failure_code=="unavailable","Path/free-text status tokens excluded")
	_check(not JSON.stringify(poisoned).contains("PRIVATE_"),"Rejected values never copied")
	var directory:=ProjectSettings.globalize_path(app.save_service.save_dir())
	_check(DirAccess.make_dir_recursive_absolute(directory)==OK,"Disposable QA save folder exists")
	menu.open_save_folder.pressed.emit()
	_check(app.opened==directory,"Folder action targets actual active save directory")
	_check(menu.status.text=="Save folder opened.","Folder success feedback")
	app.open_error=ERR_CANT_OPEN
	menu.open_save_folder.pressed.emit()
	_check(menu.status.text=="Could not open the save folder. Try again.","Folder error feedback")
	app.save_service=MissingFolder.new()
	app.opened=""
	menu.open_save_folder.pressed.emit()
	_check(app.opened.is_empty() and menu.status.text=="No save folder yet. Start a run and save first.","Missing folder does not invoke system shell")
	print("QOL05_SAFE_REPORT "+app.copied)
	print("QOL05_SUPPORT_DIAGNOSTICS "+JSON.stringify({"checks":checks,"failures":failures,"clipboard":"captured at final platform boundary; no system clipboard write in native test","folder":"system-open stub records actual path; Explorer launch not claimed"}))
	app.queue_free()
	await _frames(3)
	quit(0 if failures.is_empty() else 1)
