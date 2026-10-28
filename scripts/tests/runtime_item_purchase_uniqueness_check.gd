extends SceneTree

const Service := preload("res://scripts/core/run_action_service.gd")
const View := preload("res://scripts/ui/environment_interaction_view_model.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}
var library: ContentLibrary

class BoundaryRun extends RunState:
	func advance_environment_turns(amount: int = 1, profile_stages: bool = false) -> Dictionary:
		var result := super.advance_environment_turns(amount,profile_stages)
		if bool(result.get("ok",false)) and str(current_environment.get("purchase_test_fault","")) == "acquire":
			add_item(str(current_environment.get("purchase_test_item","")))
		return result
	func add_item(item_id: String) -> void:
		if str(current_environment.get("purchase_test_fault","")) != "drop_grant": super.add_item(item_id)
	func prepare_current_environment_object_membership_for_publication() -> Dictionary:
		if str(current_environment.get("purchase_test_fault","")) == "membership": return {"ok":false,"errors":["Explicit test-only membership rejection."]}
		return super.prepare_current_environment_object_membership_for_publication()
	func publish_host_action_candidate(candidate: RunState) -> bool:
		if str(current_environment.get("purchase_test_fault","")) == "publication": return false
		return super.publish_host_action_candidate(candidate)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var private_ready := true
	for key in ["BTH_DISTRIBUTION_DATA_ROOT","BTH_PROFILE_INVENTORY_PATH","BTH_META_COLLECTION_PATH","BTH_USER_SETTINGS_PATH","BTH_TARGET_OUTPUT"]:
		private_ready = private_ready and not OS.get_environment(key).is_empty()
	if not check(private_ready,"private diagnostic persistence roots are required"):
		_finish()
		return
	# Install the original copied host key before any synthetic SaveService call
	# can initialize its process-local authority cache.
	var captured_ready := not OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and _install_bundle()
	library = ContentLibrary.new()
	library.load(false)
	for chips in [false,true]:
		for item_id in ["roadside_map","tab_detector","creased_luck_card"]:
			var run := _fixture(item_id,chips)
			run.add_item(item_id)
			var service := _service(run)
			var before := run.to_save_snapshot()
			var offer := _offer(service,item_id,chips)
			check(bool(offer.get("affordable",false)) and not bool(offer.get("enabled",true)), "%s/%s held offer is disabled independently of funds" % [item_id,chips])
			check(str(offer.get("disabled_reason","")) == "Already carried.", "held offer explains eligibility")
			var objects := View.interactable_object_view_list(run,library,{"item_offers":service.item_offer_view_list()})
			var model := _item_object(objects,item_id)
			check(not model.is_empty() and not bool(model.get("enabled",true)) and model.get("available_actions",[1]).is_empty() and str(model.get("confirm_action_id","missing")).is_empty(), "held item has no Buy or confirmation")
			check(str(model.get("action_summary","")) == "Already carried.", "rendered model does not falsely ask for more funds")
			for repeat in range(2):
				var response := service.buy_item_offer(item_id)
				check(not bool(response.get("ok",true)) and str(response.get("message","")).contains("Already carried"), "direct/stale held Buy rejects")
				check(_equal(run.to_save_snapshot(),before), "rejected held Buy preserves complete live state")
		for fault in ["acquire","drop_grant","membership","publication"]:
			var run := _fixture("roadside_map",chips)
			run.current_environment["purchase_test_fault"] = fault
			run.current_environment["purchase_test_item"] = "roadside_map"
			var before := run.to_save_snapshot()
			var response := _service(run).buy_item_offer("roadside_map")
			check(not bool(response.get("ok",true)), "candidate %s/%s rejects before live publication" % [fault,chips])
			check(_equal(run.to_save_snapshot(),before), "candidate rejection preserves funds/stock/score/turn/clock/history/RNG")
		var poor_offer := _fixture("roadside_map",chips)
		if chips: poor_offer.grand_casino_chips = 4
		else: poor_offer.bankroll = 4
		var poor_offer_before := poor_offer.to_save_snapshot()
		check(not bool(_service(poor_offer).buy_item_offer("roadside_map").get("ok",true)) and _equal(poor_offer.to_save_snapshot(),poor_offer_before), "insufficient intended currency cannot settle")
		var ended := _fixture("roadside_map",chips)
		ended.fail_run(RunState.FAILURE_BANKROLL_ZERO,"Explicit synthetic terminal guard.")
		var ended_before := ended.to_save_snapshot()
		check(not bool(_service(ended).buy_item_offer("roadside_map").get("ok",true)) and _equal(ended.to_save_snapshot(),ended_before), "terminal run cannot buy an unowned item")
		var accepted := _fixture("roadside_map",chips)
		var before_cash := accepted.bankroll
		var before_chips := accepted.grand_casino_chips
		var service := _service(accepted)
		var response := service.buy_item_offer("roadside_map")
		check(bool(response.get("ok",false)) and accepted.inventory.count("roadside_map") == 1, "eligible purchase grants one runtime item")
		check(accepted.bankroll == before_cash - (0 if chips else 5) and accepted.grand_casino_chips == before_chips - (5 if chips else 0), "eligible purchase charges exact intended currency once")
		check(_purchase_count(accepted) == 1, "eligible purchase records one receipt")
		var settled := accepted.to_save_snapshot()
		check(not bool(service.buy_item_offer("roadside_map").get("ok",true)) and _equal(accepted.to_save_snapshot(),settled), "repeat confirmation cannot charge twice")
		var saves := SaveService.new()
		var slot := "shop-grant-chips" if chips else "shop-grant-cash"
		check(saves.save_run(accepted,slot) == OK, "accepted grant saves through official codec")
		var restored: RunState = SaveService.new().load_run(slot)
		check(restored != null and restored.bankroll == accepted.bankroll and restored.grand_casino_chips == accepted.grand_casino_chips and restored.rng_state == accepted.rng_state and restored.inventory.count("roadside_map") == 1 and _purchase_count(restored) == 1, "fresh SaveService preserves accepted funds/RNG/grant/one receipt")
		if restored != null:
			var restored_before := restored.to_save_snapshot()
			check(not bool(_service(restored).buy_item_offer("roadside_map").get("ok",true)) and _equal(restored.to_save_snapshot(),restored_before), "restored repeated confirmation cannot debit again")
		accepted.remove_item("roadside_map")
		_restock(accepted,"roadside_map",chips)
		check(bool(service.runtime_item_purchase_eligibility("roadside_map").enabled), "removed/sold/consumed runtime item becomes eligible again")
		check(bool(service.buy_item_offer("roadside_map").get("ok",false)) and accepted.inventory.count("roadside_map") == 1 and _purchase_count(accepted) == 2, "restocked item can be bought again after removal")
		var active := _fixture("tab_detector",chips)
		var active_service := _service(active)
		check(bool(active_service.buy_item_offer("tab_detector").get("ok",false)) and active.inventory.count("tab_detector") == 1 and active.active_item_id == "tab_detector", "eligible active item is granted and selected")
		active.remove_item("tab_detector") # Explicit synthetic post-consumption state.
		_restock(active,"tab_detector",chips)
		check(bool(active_service.buy_item_offer("tab_detector").get("ok",false)) and active.inventory.count("tab_detector") == 1, "consumed active item can be bought again")
	var instances := _fixture("roadside_map",false)
	instances.inventory = [{"id":"roadside_map","instance_id":101},{"id":"roadside_map","instance_id":102}]
	var instance_before := instances.inventory.duplicate(true)
	check(bool(_service(instances).runtime_item_purchase_eligibility("roadside_map").enabled), "distinct instance dictionaries do not block a runtime string grant")
	check(bool(_service(instances).buy_item_offer("roadside_map").get("ok",false)), "runtime string can coexist with instance entries")
	check(instances.inventory.size() == 3 and instances.inventory[0] == instance_before[0] and instances.inventory[1] == instance_before[1], "distinct instance identities remain intact")
	var stored := _fixture("roadside_map",false)
	stored.home_state["purchase_test_stored_item"] = "roadside_map"
	check(bool(_service(stored).runtime_item_purchase_eligibility("roadside_map").enabled), "stored-only identity does not become carried ownership")
	var sold := _fixture("roadside_map",false)
	sold.add_item("roadside_map")
	var selling := _service(sold)
	check(bool(selling.sell_inventory_item("roadside_map").get("ok",false)) and not sold.inventory.has("roadside_map"), "real merchant sale removes the held runtime item")
	check(bool(selling.buy_item_offer("roadside_map").get("ok",false)) and sold.inventory.count("roadside_map") == 1, "sold item is eligible to buy from unchanged shelf")
	var pickup := _fixture("roadside_map",false)
	pickup.current_environment.item_offers[0]["pickup"] = true
	pickup.current_environment.item_offers[0]["price"] = 0
	check(bool(_service(pickup).buy_item_offer("roadside_map").get("ok",false)) and pickup.bankroll == 100 and pickup.inventory.count("roadside_map") == 1, "zero-price pickup still grants once without debit")
	var poor := _fixture("roadside_map",false)
	poor.bankroll = 4
	var poor_before := poor.to_save_snapshot()
	check(not bool(_service(poor).buy_item_offer("roadside_map").get("ok",true)) and _equal(poor.to_save_snapshot(),poor_before), "insufficient cash rejects without effects")
	var exact := _fixture("roadside_map",false)
	exact.bankroll = 5
	check(bool(_service(exact).buy_item_offer("roadside_map").get("ok",false)) and exact.bankroll == 0 and exact.inventory.has("roadside_map"), "existing exact-price cash contract preserved")
	var luck := _fixture("creased_luck_card",false)
	var initial_luck := luck.baseline_luck
	check(bool(_service(luck).buy_item_offer("creased_luck_card").get("ok",false)) and luck.baseline_luck == initial_luck + 1, "authored purchase-time Luck effect remains once")
	if captured_ready: _captured_l06()
	_finish()

func _fixture(item_id: String, chips: bool) -> RunState:
	var run := BoundaryRun.new()
	run.start_new("RUNTIME-PURCHASE-UNIQUENESS")
	run.bankroll = 100
	run.grand_casino_chips = 20
	var archetype := RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID if chips else "corner_store"
	var definition := library.environment_archetype(archetype)
	run.set_environment({"id":"purchase_boundary_room","world_node_id":"purchase_boundary_node","archetype_id":archetype,"kind":definition.get("kind","shop"),"object_fixtures":definition.get("object_fixtures",[]).duplicate(true),"turns":0,"item_offers":[],"service_ids":[],"lender_hooks":[],"game_ids":[],"event_ids":[],"next_archetypes":[],"travel_hooks":[],"game_states":{},"layout":{}})
	_restock(run,item_id,chips)
	return run

func _restock(run: RunState, item_id: String, chips: bool) -> void:
	if chips: run.current_environment["cage_gift_shop_state"] = {"version":1,"stock":[{"item_id":item_id,"chip_price":5,"sold":false}]}
	else: run.current_environment["item_offers"] = [{"id":item_id,"price":5,"pickup":false}]

func _service(run: RunState) -> RunActionService:
	var service := Service.new()
	service.setup(library,run)
	return service

func _offer(service: RunActionService, item_id: String, chips: bool) -> Dictionary:
	for offer in service.cage_gift_shop_offer_view_list() if chips else service.item_offer_view_list():
		if str(offer.get("id","")) == item_id: return offer
	return {}

func _item_object(objects: Array, item_id: String) -> Dictionary:
	for object in objects:
		if str(object.get("source_id","")) == item_id and str(object.get("object_type","")) == "item": return object
	return {}

func _purchase_count(run: RunState) -> int:
	return run.story_log.filter(func(row: Dictionary) -> bool: return str(row.get("type","")) == "item_purchase").size()

func _captured_l06() -> void:
	var run: RunState = SaveService.new().load_run("foundation_ui_autosave")
	if not check(run != null,"official SaveService loads copied L06"): return
	var before := run.to_save_snapshot()
	facts["captured_before"] = {"cash":run.bankroll,"inventory":run.inventory.duplicate(true),"rng":run.rng_state}
	check(run.bankroll == 150 and run.inventory.count("roadside_map") == 1,"captured L06 identities/funds unchanged")
	var service := _service(run)
	var offer := _offer(service,"roadside_map",false)
	check(not bool(offer.get("enabled",true)) and str(offer.get("disabled_reason","")) == "Already carried.","captured Map offer rejects duplicate with clear reason")
	check(not bool(service.buy_item_offer("roadside_map").get("ok",true)) and _equal(run.to_save_snapshot(),before),"captured stale/direct Buy cannot charge or advance")
	var saves := SaveService.new()
	check(saves.save_run(run,"shop-unchanged-copy") == OK,"unchanged rejected copy saves")
	var restored: RunState = SaveService.new().load_run("shop-unchanged-copy")
	check(restored != null and _equal(restored.to_save_snapshot(),before),"fresh SaveService preserves rejected purchase state without compensation")
	facts["captured_after"] = {"cash":restored.bankroll,"inventory":restored.inventory.duplicate(true),"rng":restored.rng_state} if restored != null else {}

func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user_dir := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves)
	DirAccess.make_dir_recursive_absolute(user_dir)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name)) == OK,"install unchanged copied save"): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user_dir.path_join(".crew_host_authority_v1")) == OK,"install unchanged copied authority"): return false
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"]]:
		for suffix in ["",".bak"]:
			var path := bundle.path_join(str(pair[0])+suffix)
			if FileAccess.file_exists(path) and not check(DirAccess.copy_absolute(path,OS.get_environment(pair[1])+suffix) == OK,"install unchanged copied companion"): return false
	return true

func _equal(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT,TYPE_FLOAT] and typeof(right) in [TYPE_INT,TYPE_FLOAT]: return left == right
	if typeof(left) != typeof(right): return false
	if typeof(left) in [TYPE_ARRAY,TYPE_DICTIONARY]:
		if left.size() != right.size(): return false
		for key in left.keys() if typeof(left) == TYPE_DICTIONARY else range(left.size()):
			if typeof(left) == TYPE_DICTIONARY and not right.has(key): return false
			if not _equal(left[key],right[key]): return false
		return true
	return left == right

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _finish() -> void:
	var report := {"checks":checks,"failures":failures,"facts":facts,"fidelity":"Synthetic real service/candidate transactions with explicitly labeled candidate fault seams, plus optional official L06 copied-save service/SaveService check. Native model coverage, no normal Web/pointer claim; original profiles untouched."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	print("RUNTIME_ITEM_UNIQUENESS checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
