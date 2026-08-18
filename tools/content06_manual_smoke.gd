extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const RunViewModelScript := preload("res://scripts/ui/run_inventory_view_model.gd")
const RunScreenScript := preload("res://scripts/ui/run_inventory_screen.gd")

var out_dir := "res://.tmp/content06_1_manual_smoke"
var failures: Array = []
var evidence: Array = []


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=").strip_edges()
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load(false)
	var absolute_dir := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	await _capture_buy(library, "%s/buy_item.png" % absolute_dir)
	await _capture_craft(library, "%s/craft_crew_gear.png" % absolute_dir)
	await _capture_earn(library, "%s/earn_souvenir.png" % absolute_dir)
	var manifest := {
		"tool": "content06_manual_smoke",
		"passed": failures.is_empty(),
		"captures": evidence,
		"failures": failures,
	}
	var manifest_path := "%s/manifest.json" % absolute_dir
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write manual smoke manifest: %s" % manifest_path)
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print("CONTENT06_MANUAL_SMOKE %s captures=%d manifest=%s" % ["PASS" if failures.is_empty() else "FAIL", evidence.size(), manifest_path])
	quit(0 if failures.is_empty() else 1)


func _capture_buy(library: ContentLibrary, path: String) -> void:
	var run := RunStateScript.new()
	run.start_new("CONTENT06-VISUAL-BUY")
	run.bankroll = 100
	run.current_environment = {
		"id": "content06_buy_fixture",
		"archetype_id": "corner_store",
		"kind": "shop",
		"item_offers": [{"id": "instant_coffee", "price": 7}],
	}
	var service := RunActionServiceScript.new()
	service.setup(library, run)
	var before := run.bankroll
	var result := service.buy_item_offer("instant_coffee")
	if not bool(result.get("ok", false)) or not run.inventory.has("instant_coffee") or run.bankroll != before - 7:
		failures.append("Production item purchase did not buy Instant Coffee for exact authored cash.")
	await _capture_inventory(run, library, "PURCHASED · INSTANT COFFEE", "Bought through the live shop offer path for $7.", path)
	evidence.append({"category": "buy", "path": path, "source": "RunActionService.buy_item_offer", "item_id": "instant_coffee", "bankroll_before": before, "bankroll_after": run.bankroll, "result_ok": bool(result.get("ok", false))})


func _capture_craft(library: ContentLibrary, path: String) -> void:
	var run := RunStateScript.new()
	run.start_new("CONTENT06-VISUAL-CRAFT")
	run.bankroll = 32
	run.current_environment = {"id": "content06_bench", "archetype_id": "small_underground_casino", "kind": "crew", "event_ids": ["crew_mags_bench"], "resolved_event_ids": []}
	run.crew_add_trust("crew_mags", CrewStateModelScript.rank_threshold("associate"), "visual_smoke")
	run.add_item("false_bottom_cup")
	run.add_item("weighted_keyring")
	var module := EventModuleScript.new()
	module.setup(library.event("crew_mags_bench"), library)
	var result := module.resolve(run, run.current_environment, "craft_loaded_dice")
	if not bool(result.get("ok", false)) or not run.inventory.has("mags_loaded_dice") or run.inventory.has("false_bottom_cup") or run.inventory.has("weighted_keyring") or run.bankroll != 0:
		failures.append("Production Mags bench did not consume components/cash and craft loaded dice.")
	await _capture_inventory(run, library, "CRAFTED · MAGS' LOADED DICE", "Built through Mags' live bench event from two consumed components.", path)
	evidence.append({"category": "craft", "path": path, "source": "EventModule.crew_mags_bench", "item_id": "mags_loaded_dice", "components_consumed": not run.inventory.has("false_bottom_cup") and not run.inventory.has("weighted_keyring"), "bankroll_after": run.bankroll, "result_ok": bool(result.get("ok", false))})


func _capture_earn(library: ContentLibrary, path: String) -> void:
	var run: RunState
	var selected_seed := ""
	for seed_index in range(512):
		var candidate := RunStateScript.new()
		selected_seed = "CONTENT06-VISUAL-EARN-%03d" % seed_index
		candidate.start_new(selected_seed)
		var generator := RunGeneratorScript.new(library)
		generator.next_environment(candidate)
		generator.next_environment(candidate, "delta_queen", true)
		if str(candidate.current_environment.get("scenario_id", "")) == "delta_queen_wedding_charter":
			run = candidate
			break
	if run == null:
		failures.append("Production generation never selected the wedding souvenir scenario.")
		return
	var module := EventModuleScript.new()
	module.setup(library.event("scenario_wedding_best_man"), library)
	var choices := module.choices(run, run.current_environment)
	if choices.is_empty():
		failures.append("Production wedding event exposed no souvenir choice.")
		return
	var choice_id := str((choices[0] as Dictionary).get("id", ""))
	var result := module.resolve(run, run.current_environment, choice_id)
	if not bool(result.get("ok", false)) or not run.inventory.has("wedding_ribbon_favor"):
		failures.append("Production seeded scenario event did not earn the Wedding Ribbon Favor.")
	await _capture_inventory(run, library, "EARNED · WEDDING RIBBON FAVOR", "Earned through seeded world generation, scenario selection, and its authored event.", path)
	evidence.append({"category": "earn", "path": path, "source": "RunGenerator -> scenario -> EventModule", "seed": selected_seed, "scenario_id": str(run.current_environment.get("scenario_id", "")), "event_id": "scenario_wedding_best_man", "item_id": "wedding_ribbon_favor", "result_ok": bool(result.get("ok", false))})


func _capture_inventory(run: RunState, library: ContentLibrary, title: String, summary: String, path: String) -> void:
	var service := RunActionServiceScript.new()
	service.setup(library, run)
	var model := RunViewModelScript.build(run, service, "inspect", "", {})
	model["title"] = title
	model["summary"] = summary
	root.size = Vector2i(1280, 720)
	var backdrop := ColorRect.new()
	backdrop.color = Color("#05060a")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var screen: RunInventoryScreen = RunScreenScript.new()
	backdrop.add_child(screen)
	screen.configure(Callable(self, "_texture"))
	screen.set_reduced_motion(true)
	screen.set_small_screen_mode(false)
	screen.open(model)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		failures.append("Screenshot save failed for %s: %s" % [path, error])
	backdrop.queue_free()
	await process_frame


func _texture(path: String) -> Texture2D:
	return load(path) as Texture2D if not path.is_empty() else null
