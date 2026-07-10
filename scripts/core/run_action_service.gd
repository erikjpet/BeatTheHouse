class_name RunActionService
extends RefCounted

# Resolves non-game run actions from data definitions.
#
# FoundationMain should call this service for content/system behavior and keep
# only presentation, selection, modal, and focus state in UI. The service never
# reads UI controls and never draws; it builds shared result deltas and applies
# them through RunState/GameModule so the same path can support a large catalog
# of environments, items, services, and lenders.

const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")
const ItemEffectScript := preload("res://scripts/core/item_effect.gd")

const JAZZ_CLUB_ARCHETYPE_ID := "jazz_club"
const JAZZ_SAX_ROUND_SERVICE_ID := "jazz_sax_round"
const JAZZ_CELLO_ROUND_SERVICE_ID := "jazz_cello_round"
const JAZZ_DRUMMER_ROUND_SERVICE_ID := "jazz_drummer_round"
const JAZZ_TIP_JAR_SERVICE_ID := "jazz_band_tip_jar"
const JAZZ_LISTEN_SERVICE_ID := "listen_to_jazz"
const JAZZ_SHOW_GLASSES_SERVICE_ID := "show_drummer_glasses"
const JAZZ_SAX_COIN_ITEM_ID := "jazz_sax_lucky_coin"
const JAZZ_CELLO_COIN_ITEM_ID := "jazz_cello_lucky_coin"
const JAZZ_DRUMMER_COIN_ITEM_ID := "jazz_drummer_lucky_coin"
const JAZZ_DRUMMER_GLASSES_ITEM_ID := "jazz_drummer_glasses"
const JAZZ_MUSICIAN_SAX := "sax"
const JAZZ_MUSICIAN_CELLO := "cello"
const JAZZ_MUSICIAN_DRUMMER := "drummer"
const JAZZ_NO_REWARD_HOLDER := "none"
const JAZZ_REWARD_MIN_DRINKS := 3
const JAZZ_REWARD_MAX_DRINKS := 5
const JAZZ_DRUMMER_LISTEN_THRESHOLD := 2
const JAZZ_TIP_JAR_CHANCE_DENOMINATOR := 4
const JAZZ_COIN_LUCK_REWARD := 5
const JAZZ_GLASSES_LUCK_REWARD := 2

var library: ContentLibrary
var run_state: RunState


# Stores the current content library and run state used by resolver methods.
func setup(p_library: ContentLibrary, p_run_state: RunState) -> void:
	library = p_library
	run_state = p_run_state


# Returns true when both ContentLibrary and RunState are available.
func is_ready() -> bool:
	return library != null and run_state != null


# Builds presentation data for current environment item offers.
func item_offer_view_list(selected_item_id: String = "") -> Array:
	if not is_ready():
		return []
	var offers: Array = []
	for offer in _copy_array(run_state.current_environment.get("item_offers", [])):
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var offer_data := offer as Dictionary
		var item_id := str(offer_data.get("id", ""))
		if item_id.is_empty():
			continue
		var item_definition := library.item(item_id)
		if item_definition.is_empty():
			continue
		if not _item_enabled_for_run(item_id):
			continue
		var display_name := str(offer_data.get("display_name", item_definition.get("display_name", item_id)))
		var price := int(offer_data.get("price", item_definition.get("price_min", 0)))
		var pickup := bool(offer_data.get("pickup", false))
		if pickup:
			price = 0
		var item_context := item_definition.duplicate(true)
		item_context["price"] = price
		item_context["pickup"] = pickup
		offers.append({
			"id": item_id,
			"display_name": display_name,
			"price": price,
			"pickup": pickup,
			"action_label": "Pick Up" if pickup else "Buy",
			"description": str(item_definition.get("description", "")),
			"purpose_summary": _item_purpose_summary(item_definition),
			"asset_path": str(item_definition.get("asset_path", "")),
			"icon_key": str(item_definition.get("icon_key", item_id)),
			"environment_prop": str(item_definition.get("environment_prop", "")),
			"surface": str(item_definition.get("surface", "counter")),
			"effect_summary": "",
			"attribute_badges": AttributeBadgesScript.for_item(item_context),
			"affordable": run_state.bankroll >= price,
			"selected": item_id == selected_item_id,
		})
	return offers


# Finds one current environment item offer by id.
func item_offer(item_id: String, selected_item_id: String = "") -> Dictionary:
	if item_id.is_empty():
		return {}
	for offer in item_offer_view_list(selected_item_id):
		if typeof(offer) == TYPE_DICTIONARY and str((offer as Dictionary).get("id", "")) == item_id:
			return (offer as Dictionary).duplicate(true)
	return {}


func _item_purpose_summary(item_definition: Dictionary) -> String:
	var effect := _copy_dict(item_definition.get("effect", {}))
	var item_class := str(item_definition.get("class", item_definition.get("item_class", ""))).strip_edges().to_lower()
	var domain := str(item_definition.get("domain", "")).strip_edges().to_lower()
	if int(effect.get("container_capacity", item_definition.get("container_capacity", 0))) > 0 or item_class == "container":
		return "Stores items outside your carried kit."
	if bool(effect.get("active_item", false)) or not str(effect.get("active_mode", "")).strip_edges().is_empty():
		var target := str(effect.get("active_target", domain)).strip_edges()
		return "Active item for %s." % _purpose_domain_label(target)
	var families := _copy_dict(effect.get("families", {}))
	if not families.is_empty():
		return "Helps %s." % _purpose_family_list(families.keys())
	if int(effect.get("travel_scouting_level", 0)) > 0:
		return "Reveals better route intel."
	if effect.has("debt_grace_turns") or effect.has("debt_default_heat_delta"):
		return "Helps manage debt pressure."
	if int(effect.get("cheat_suspicion_delta", 0)) < 0:
		return "Makes risky moves quieter."
	if int(effect.get("cheat_suspicion_delta", 0)) > 0:
		return "Stronger edge, more heat."
	if effect.has("win_chance") or effect.has("legal_win_chance") or effect.has("win_bonus") or effect.has("loss_reduction"):
		return "Improves clean-play outcomes."
	if domain == "games":
		return "Helps gambling decisions."
	if domain == "travel":
		return "Helps route choices."
	return "Adds a useful run item."


func _purpose_family_list(family_ids: Array) -> String:
	var labels: Array[String] = []
	for family_value in family_ids:
		var label := _purpose_domain_label(str(family_value))
		if label.is_empty() or labels.has(label):
			continue
		labels.append(label)
	if labels.is_empty():
		return "gambling"
	if labels.size() == 1:
		return labels[0]
	if labels.size() == 2:
		return "%s and %s" % [labels[0], labels[1]]
	return "%s, %s, and more" % [labels[0], labels[1]]


func _purpose_domain_label(value: String) -> String:
	match value.strip_edges().to_lower():
		"slots", "slot":
			return "slot machines"
		"cards":
			return "card games"
		"wheel", "roulette":
			return "roulette"
		"dice":
			return "dice games"
		"pull_tabs":
			return "pull tabs"
		"blackjack":
			return "blackjack"
		"baccarat":
			return "baccarat"
		"video_poker":
			return "video poker"
		"travel":
			return "travel"
		_:
			var clean := value.strip_edges().replace("_", " ")
			return clean if not clean.is_empty() else "this run"


# Buys one item offer, applies its ItemEffect, removes the offer, and returns the result.
func buy_item_offer(item_id: String) -> Dictionary:
	var offer := item_offer(item_id)
	if offer.is_empty():
		return _service_error("Item offer is not available.")
	var item_definition := library.item(item_id)
	if item_definition.is_empty():
		return _service_error("Item definition is missing.")
	if not _item_enabled_for_run(item_id):
		return _service_error("That item is not part of this run.")
	var price := int(offer.get("price", 0))
	if price < 0:
		return _service_error("Item price is invalid.")
	if run_state.bankroll < price:
		return _service_error("Not enough bankroll for %s." % str(item_definition.get("display_name", item_id)))
	var item_effect := ItemEffectScript.new()
	item_effect.setup(item_definition)
	var context := {
		"domain": str(item_definition.get("domain", "global")),
		"domains": [str(item_definition.get("domain", "global")), "global"],
		"environment_id": str(run_state.current_environment.get("id", "")),
		"action_id": "buy_item",
	}
	var effect_result: Dictionary = item_effect.apply(context)
	var result := purchase_item_result(effect_result, item_definition, offer)
	run_state.advance_environment_turns(1)
	GameModule.apply_result(run_state, result)
	if _definition_is_active_item(item_definition):
		_auto_select_active_item_after_gain(item_id)
	run_state.remove_item_offer(item_id)
	return _service_success(result)


# Builds presentation data for current run inventory.
func inventory_item_view_list() -> Array:
	if not is_ready():
		return []
	var result: Array = []
	for item_id in _copy_array(run_state.inventory):
		var detail := inventory_item_detail(str(item_id))
		if not detail.is_empty():
			result.append(detail)
	return result


# Returns the equipped active item id, falling back to the only held active item
# for display without mutating save state.
func selected_active_item_id() -> String:
	if not is_ready():
		return ""
	var active_ids := _held_active_item_ids()
	var current := str(run_state.active_item_id)
	if not current.is_empty() and active_ids.has(current):
		return current
	if active_ids.size() == 1:
		return str(active_ids[0])
	return ""


# Returns display data for the current active item slot.
func active_item_detail() -> Dictionary:
	var item_id := selected_active_item_id()
	if item_id.is_empty():
		return {}
	return inventory_item_detail(item_id)


# Equips one held active item.
func set_active_item(item_id: String) -> Dictionary:
	if not is_ready():
		return _service_error("Inventory is not available.")
	if item_id.is_empty():
		run_state.active_item_id = ""
		return _service_success({"ok": true, "type": "active_item_selection", "item_id": "", "message": "Active item cleared."})
	if not run_state.inventory.has(item_id):
		return _service_error("That item is not in your inventory.")
	var definition := library.item(item_id)
	if definition.is_empty():
		return _service_error("Item definition is missing.")
	if not _definition_is_active_item(definition):
		return _service_error("%s is not an active item." % str(definition.get("display_name", item_id)))
	run_state.set_active_item(item_id)
	var display_name := str(definition.get("display_name", item_id))
	return _service_success({
		"ok": true,
		"type": "active_item_selection",
		"item_id": item_id,
		"message": "%s equipped as your active item." % display_name,
	})


# Returns display, type, effect, and sale data for one inventory item.
func inventory_item_detail(item_id: String) -> Dictionary:
	if item_id.is_empty() or library == null:
		return {}
	var definition := library.item(item_id)
	if definition.is_empty():
		return {}
	var effect: Dictionary = definition.get("effect", {}) if typeof(definition.get("effect", {})) == TYPE_DICTIONARY else {}
	var item_class := str(definition.get("class", definition.get("item_type", "gear")))
	var sellable := bool(definition.get("sellable", true))
	var sale_price := item_sale_price(definition)
	var is_active := _definition_is_active_item(definition)
	var selected_id := selected_active_item_id() if run_state != null else ""
	var item_context := definition.duplicate(true)
	item_context["item_class"] = item_class
	item_context["sale_price"] = sale_price
	return {
		"id": item_id,
		"display_name": str(definition.get("display_name", item_id.capitalize())),
		"description": str(definition.get("description", "")),
		"item_type": item_class,
		"item_class": item_class,
		"domain": str(definition.get("domain", "global")),
		"sellable": sellable,
		"sale_price": sale_price,
		"effect_summary": "",
		"attribute_badges": AttributeBadgesScript.for_item(item_context),
		"asset_path": str(definition.get("asset_path", "")),
		"icon_key": str(definition.get("icon_key", item_id)),
		"active_item": is_active,
		"active_mode": str(effect.get("active_mode", "")),
		"active_target": str(effect.get("active_target", "")),
		"active_selected": is_active and item_id == selected_id,
		"repairable": _item_repairable(effect),
		"repair_cost": maxi(0, int(effect.get("repair_cost", 0))),
		"repair_to_item": str(effect.get("repair_to_item", "")),
	}


func repair_inventory_item(item_id: String) -> Dictionary:
	if not is_ready():
		return _service_error("Inventory is not available.")
	if not shopkeeper_available():
		return _service_error("You need a shopkeeper to repair gear.")
	if not run_state.inventory.has(item_id):
		return _service_error("That item is not in your inventory.")
	var item := inventory_item_detail(item_id)
	if item.is_empty():
		return _service_error("Item definition is missing.")
	if not bool(item.get("repairable", false)):
		return _service_error("%s cannot be repaired." % str(item.get("display_name", item_id)))
	var repair_cost := maxi(0, int(item.get("repair_cost", 0)))
	if run_state.bankroll < repair_cost:
		return _service_error("Repairs cost %d." % repair_cost)
	var repaired_id := str(item.get("repair_to_item", ""))
	var repaired_definition := library.item(repaired_id)
	if repaired_id.is_empty() or repaired_definition.is_empty():
		return _service_error("Repair target is missing.")
	var display_name := str(item.get("display_name", item_id))
	var repaired_name := str(repaired_definition.get("display_name", repaired_id))
	var message := "Paid %d to repair %s into %s." % [repair_cost, display_name, repaired_name]
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = -repair_cost
	deltas["inventory_remove"] = [item_id]
	deltas["inventory_add"] = [repaired_id]
	deltas["messages"] = [message]
	deltas["story_log"] = [{
		"type": "item_repair",
		"item_id": item_id,
		"repaired_item_id": repaired_id,
		"repair_cost": repair_cost,
		"environment_id": str(run_state.current_environment.get("id", "")),
		"message": message,
	}]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "item_repair",
		"source_id": "shopkeeper",
		"item_id": item_id,
		"action_id": "repair_item",
		"action_kind": "merchant",
		"bankroll_delta": -repair_cost,
		"suspicion_delta": 0,
		"deltas": deltas,
		"environment_id": str(run_state.current_environment.get("id", "")),
		"message": message,
	})
	result["repair_cost"] = repair_cost
	result["item_id"] = item_id
	result["repaired_item_id"] = repaired_id
	GameModule.apply_result(run_state, result)
	return _service_success(result)


func _item_repairable(effect: Dictionary) -> bool:
	return not str(effect.get("repair_to_item", "")).is_empty() and int(effect.get("repair_cost", 0)) > 0


func _item_enabled_for_run(item_id: String) -> bool:
	if library == null:
		return false
	if run_state == null:
		return not library.item(item_id).is_empty()
	return library.item_enabled_for_challenge(item_id, run_state.challenge_config)


# Returns true for item definitions that can be placed in the active item slot.
func _definition_is_active_item(definition: Dictionary) -> bool:
	var effect: Dictionary = definition.get("effect", {}) if typeof(definition.get("effect", {})) == TYPE_DICTIONARY else {}
	if bool(effect.get("active_item", false)):
		return true
	var item_class := str(definition.get("class", definition.get("item_type", ""))).to_lower()
	return item_class == "active"


# Returns held active item ids in inventory order.
func _held_active_item_ids() -> Array:
	var result: Array = []
	if run_state == null or library == null:
		return result
	for item_id_value in _copy_array(run_state.inventory):
		var item_id := str(item_id_value)
		var definition := library.item(item_id)
		if not definition.is_empty() and _definition_is_active_item(definition):
			result.append(item_id)
	return result


# Equips a newly gained active item when there is no competing active choice.
func _auto_select_active_item_after_gain(item_id: String) -> void:
	if run_state == null:
		return
	var active_ids := _held_active_item_ids()
	if active_ids.size() <= 1 or str(run_state.active_item_id).is_empty() or not active_ids.has(str(run_state.active_item_id)):
		run_state.set_active_item(item_id)


# Returns the sale price for an item definition.
func item_sale_price(item_definition: Dictionary) -> int:
	if item_definition.has("sale_price"):
		return maxi(0, int(item_definition.get("sale_price", 0)))
	var price_min := int(item_definition.get("price_min", 0))
	var price_max := int(item_definition.get("price_max", price_min))
	return maxi(0, int(round(float(price_min + price_max) * 0.25)))


# Returns whether the current environment can host merchant sales.
func shopkeeper_available() -> bool:
	if run_state == null:
		return false
	for offer_value in _copy_array(run_state.current_environment.get("item_offers", [])):
		if typeof(offer_value) == TYPE_DICTIONARY and not bool((offer_value as Dictionary).get("pickup", false)):
			return true
	if str(run_state.current_environment.get("kind", "")) == "shop":
		var archetype := _environment_archetype(str(run_state.current_environment.get("archetype_id", "")))
		return not _string_array(archetype.get("item_pool", [])).is_empty()
	return false


# Returns the player-facing merchant label for the current environment.
func shopkeeper_label() -> String:
	var kind := str(run_state.current_environment.get("kind", "")) if run_state != null else ""
	return "Shopkeeper" if kind == "shop" else "Merchant"


# Returns the compact merchant description for the current environment.
func shop_description() -> String:
	if run_state == null:
		return ""
	var display_name := str(run_state.current_environment.get("display_name", "this place"))
	return "%s: %s buys sellable gear." % [display_name, shopkeeper_label().to_lower()]


# Sells one inventory item through the current merchant.
func sell_inventory_item(item_id: String) -> Dictionary:
	if not is_ready():
		return _service_error("Inventory is not available.")
	if not shopkeeper_available():
		return _service_error("You need a merchant to sell items.")
	if not run_state.inventory.has(item_id):
		return _service_error("That item is not in your inventory.")
	var item := inventory_item_detail(item_id)
	if item.is_empty():
		return _service_error("Item definition is missing.")
	if not bool(item.get("sellable", false)):
		return _service_error("%s cannot be sold." % str(item.get("display_name", item_id)))
	var sale_price := maxi(0, int(item.get("sale_price", 0)))
	var display_name := str(item.get("display_name", item_id))
	var message := "Sold %s for %d." % [display_name, sale_price]
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = sale_price
	deltas["inventory_remove"] = [item_id]
	deltas["story_log"] = [{
		"type": "item_sale",
		"item_id": item_id,
		"item_name": display_name,
		"sale_price": sale_price,
		"environment_id": str(run_state.current_environment.get("id", "")),
		"message": message,
	}]
	deltas["messages"] = [message]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "item_sale",
		"source_id": "shopkeeper",
		"item_id": item_id,
		"action_id": "sell_item",
		"action_kind": "merchant",
		"bankroll_delta": sale_price,
		"suspicion_delta": 0,
		"deltas": deltas,
		"environment_id": str(run_state.current_environment.get("id", "")),
		"message": message,
	})
	result["sale_price"] = sale_price
	result["item_id"] = item_id
	GameModule.apply_result(run_state, result)
	return _service_success(result)


# Builds presentation options for current environment service hooks.
func service_hook_view_list(selected_service_id: String = "") -> Array:
	if run_state == null:
		return []
	var options: Array = []
	var service_ids := _string_array(run_state.current_environment.get("service_ids", []))
	if _jazz_glasses_service_visible() and not service_ids.has(JAZZ_SHOW_GLASSES_SERVICE_ID):
		service_ids.append(JAZZ_SHOW_GLASSES_SERVICE_ID)
	for service_id in service_ids:
		var definition := hook_definition("service", service_id)
		if _service_blocked_by_challenge(definition):
			continue
		var option := hook_option("service", service_id, selected_service_id)
		if not bool(option.get("hidden", false)):
			options.append(option)
	return options


# Builds presentation options for current environment lender hooks.
func lender_hook_view_list(selected_lender_id: String = "") -> Array:
	if run_state == null:
		return []
	var options: Array = []
	for lender_id in _string_array(run_state.current_environment.get("lender_hooks", [])):
		var option := hook_option("lender", lender_id, selected_lender_id)
		if not bool(option.get("hidden", false)):
			options.append(option)
	return options


# Finds one service hook option.
func service_hook(service_id: String, selected_service_id: String = "") -> Dictionary:
	return _find_option(service_hook_view_list(selected_service_id), service_id)


# Finds one lender hook option.
func lender_hook(lender_id: String, selected_lender_id: String = "") -> Dictionary:
	return _find_option(lender_hook_view_list(selected_lender_id), lender_id)


# Builds one service or lender hook presentation option.
func hook_option(kind: String, hook_id: String, selected_hook_id: String = "") -> Dictionary:
	var definition := hook_definition(kind, hook_id)
	var display_name := hook_display_name(kind, hook_id, definition)
	var summary := str(definition.get("description", definition.get("summary", ""))) if not definition.is_empty() else ""
	var hook_status := hook_run_status(kind, definition)
	var deltas := hook_result_deltas(definition, kind, hook_status)
	var supported := not definition.is_empty() and (result_deltas_have_mutation(deltas) or (kind == "service" and _is_jazz_custom_service(hook_id)) or (kind == "lender" and _lender_has_dynamic_contract(definition)))
	var availability_class := _hook_availability_class(kind, hook_id, definition, hook_status, supported)
	var enabled := supported and bool(hook_status.get("available", true))
	var disabled_reason := ""
	if not supported:
		disabled_reason = display_only_hook_status(kind, definition)
	elif not enabled:
		disabled_reason = str(hook_status.get("disabled_reason", "Not available right now."))
	var status := "Ready to use." if enabled else disabled_reason
	var badge_source := definition.duplicate(true)
	badge_source["cost"] = int(hook_status.get("cost", definition.get("cost", 0)))
	badge_source["deltas"] = deltas
	var attribute_badges := AttributeBadgesScript.for_service(badge_source) if kind == "service" else AttributeBadgesScript.for_lender(badge_source)
	return {
		"id": hook_id,
		"kind": kind,
		"display_name": display_name,
		"category": str(definition.get("category", "")),
		"summary": summary,
		"status": status,
		"mutation_supported": supported,
		"enabled": enabled,
		"availability_class": availability_class,
		"hidden": availability_class == RunState.AVAILABILITY_CATEGORICAL_UNAVAILABLE,
		"disabled_reason": disabled_reason,
		"cost": int(hook_status.get("cost", definition.get("cost", 0))),
		"delta_summary": delta_summary(deltas) if supported else "",
		"icon_key": str(definition.get("icon_key", kind)),
		"environment_prop": str(definition.get("environment_prop", "")),
		"surface": str(definition.get("surface", "")),
		"asset_path": str(definition.get("asset_path", "")),
		"attribute_badges": attribute_badges,
		"selected": hook_id == selected_hook_id,
	}


func _hook_availability_class(kind: String, hook_id: String, definition: Dictionary, hook_status: Dictionary, supported: bool) -> String:
	if definition.is_empty() or not supported:
		return RunState.AVAILABILITY_CATEGORICAL_UNAVAILABLE
	var status_class := str(hook_status.get("availability_class", RunState.AVAILABILITY_AVAILABLE))
	if status_class == RunState.AVAILABILITY_CATEGORICAL_UNAVAILABLE or status_class == RunState.AVAILABILITY_TRANSIENT_BLOCKED:
		return status_class
	if bool(hook_status.get("available", true)):
		return RunState.AVAILABILITY_AVAILABLE
	var reason := str(hook_status.get("disabled_reason", "")).to_lower()
	if reason.find("not enough") != -1 or reason.find("too drunk") != -1 or reason.find("already owe") != -1 or reason.find("sellable item") != -1 or reason.find("no local heat") != -1 or reason.find("already cooled") != -1:
		return RunState.AVAILABILITY_TRANSIENT_BLOCKED
	if kind == "service" and _is_jazz_custom_service(hook_id) and reason.find("not here") != -1:
		return RunState.AVAILABILITY_CATEGORICAL_UNAVAILABLE
	return RunState.AVAILABILITY_CATEGORICAL_UNAVAILABLE


# Applies a service or lender hook through shared result deltas.
func use_hook(kind: String, hook_id: String) -> Dictionary:
	if not is_ready():
		return _service_error("That contact is not available.")
	var option := hook_option(kind, hook_id)
	if option.is_empty():
		return _service_error("That %s is not available." % kind)
	if not bool(option.get("mutation_supported", false)):
		return _service_error(str(option.get("status", "This %s is not usable yet." % kind)))
	if not bool(option.get("enabled", true)):
		return _service_error(str(option.get("disabled_reason", "%s cannot be used right now." % kind.capitalize())))
	var result := hook_result(kind, hook_id)
	if result.is_empty():
		return _service_error("This %s is only informational right now." % kind)
	if kind == "service" and hook_id == JAZZ_SHOW_GLASSES_SERVICE_ID:
		GameModule.apply_result(run_state, result)
		run_state.advance_environment_turns(1)
		return _service_success(result)
	run_state.advance_environment_turns(1)
	GameModule.apply_result(run_state, result)
	return _service_success(result)


# Converts an ItemEffect result plus offer data into a purchase result.
func purchase_item_result(effect_result: Dictionary, item_definition: Dictionary, offer: Dictionary) -> Dictionary:
	var item_id := str(item_definition.get("id", offer.get("id", "")))
	var display_name := str(item_definition.get("display_name", offer.get("display_name", item_id)))
	var price := int(offer.get("price", 0))
	var pickup := bool(offer.get("pickup", false))
	var result := effect_result.duplicate(true)
	var deltas := copy_result_deltas(effect_result.get("deltas", {}))
	if _definition_is_active_item(item_definition):
		_clear_active_purchase_use_deltas(deltas)
	deltas["bankroll_delta"] = int(deltas.get("bankroll_delta", 0)) - price
	var inventory_add: Array = deltas.get("inventory_add", [])
	if not inventory_add.has(item_id):
		inventory_add.append(item_id)
	deltas["inventory_add"] = inventory_add
	var story_log: Array = deltas.get("story_log", [])
	var message := "Picked up %s." % display_name if pickup else "Bought %s for %d." % [display_name, price]
	story_log.append({
		"type": "item_purchase",
		"item_id": item_id,
		"item_name": display_name,
		"price": price,
		"pickup": pickup,
		"environment_id": str(run_state.current_environment.get("id", "")),
		"message": message,
	})
	deltas["story_log"] = story_log
	var messages: Array = deltas.get("messages", [])
	if messages.is_empty():
		messages.append(message)
	deltas["messages"] = messages
	result["ok"] = bool(effect_result.get("ok", true))
	result["type"] = "item_effect"
	result["source_id"] = item_id
	result["item_id"] = item_id
	result["item_effect_id"] = item_id
	result["action_id"] = "buy_item"
	result["price"] = price
	result["bankroll_delta"] = int(deltas.get("bankroll_delta", 0))
	result["suspicion_delta"] = int(deltas.get("suspicion_delta", 0))
	result["deltas"] = deltas
	result["message"] = message
	result["messages"] = _copy_array(deltas.get("messages", []))
	result["ended"] = bool(deltas.get("ended", false))
	result["state"] = GameModule.RESULT_ENDED if bool(result.get("ended", false)) else GameModule.RESULT_CONTINUE
	return result


func _clear_active_purchase_use_deltas(deltas: Dictionary) -> void:
	for key in [
		"alcohol_intake",
		"drunk_delta",
		"pending_drunk_absorption_delta",
		"drunk_distortion_suppression_turns",
		"heat_cooldown_actions",
		"heat_cooldown_per_action",
		"alcoholic_delta",
		"baseline_luck_delta",
		"suspicion_delta",
	]:
		deltas[key] = 0
	for key in ["debt_changes", "inventory_add", "inventory_remove", "travel_hooks_add", "story_log", "messages", "event_hooks", "pending_bags"]:
		deltas[key] = []
	for key in ["flags_set", "travel_changes"]:
		deltas[key] = {}
	deltas["ended"] = false


# Builds a service/lender result without applying it.
func hook_result(kind: String, hook_id: String) -> Dictionary:
	var definition := hook_definition(kind, hook_id)
	if definition.is_empty():
		return {}
	var status := hook_run_status(kind, definition)
	if kind == "lender" and _lender_has_dynamic_contract(definition):
		return _dynamic_lender_result(hook_id, definition, status)
	if kind == "service" and _is_jazz_custom_service(hook_id):
		return _jazz_service_result(hook_id, definition, status)
	var deltas := hook_result_deltas(definition, kind, status)
	if not result_deltas_have_mutation(deltas):
		return {}
	var display_name := hook_display_name(kind, hook_id, definition)
	var message := str(definition.get("message", "Used %s." % display_name))
	var story_log: Array = deltas.get("story_log", [])
	if story_log.is_empty():
		story_log.append({
			"type": "%s_hook" % kind,
			"id": hook_id,
			"label": display_name,
			"environment_id": str(run_state.current_environment.get("id", "")),
			"message": message,
		})
	deltas["story_log"] = story_log
	var messages: Array = deltas.get("messages", [])
	if messages.is_empty():
		messages.append(message)
	deltas["messages"] = messages
	return GameModule.build_action_result({
		"ok": true,
		"type": "%s_hook" % kind,
		"source_id": hook_id,
		"action_id": "use_service" if kind == "service" else "borrow",
		"environment_id": str(run_state.current_environment.get("id", "")),
		"deltas": deltas,
		"message": message,
	})


# Extracts result deltas from service/lender definitions.
func hook_result_deltas(definition: Dictionary, kind: String = "", status: Dictionary = {}) -> Dictionary:
	if kind == "lender" and _lender_has_dynamic_contract(definition):
		return _dynamic_lender_deltas(definition, status)
	var source := {}
	for key in ["deltas", "result_delta", "result_deltas", "effect"]:
		var candidate: Variant = definition.get(key, {})
		if typeof(candidate) == TYPE_DICTIONARY:
			source = (candidate as Dictionary).duplicate(true)
			if not source.is_empty():
				break
	var deltas := copy_result_deltas(source)
	if kind == "service":
		var cost := maxi(0, int(status.get("cost", definition.get("cost", 0))))
		if cost > 0:
			deltas["bankroll_delta"] = int(deltas.get("bankroll_delta", 0)) - cost
	if definition.has("debt") and typeof(definition.get("debt", {})) == TYPE_DICTIONARY and deltas.get("debt_changes", []).is_empty():
		deltas["debt_changes"] = [(definition.get("debt", {}) as Dictionary).duplicate(true)]
	return deltas


# Copies arbitrary result delta data into the canonical delta shape.
func copy_result_deltas(value: Variant) -> Dictionary:
	var source: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var deltas := GameModule.empty_result_deltas()
	for key in deltas.keys():
		var current: Variant = source.get(key, deltas[key])
		if typeof(current) == TYPE_ARRAY:
			deltas[key] = (current as Array).duplicate(true)
		elif typeof(current) == TYPE_DICTIONARY:
			deltas[key] = (current as Dictionary).duplicate(true)
		else:
			deltas[key] = current
	return deltas


# Returns whether deltas would mutate run state.
func result_deltas_have_mutation(deltas: Dictionary) -> bool:
	if int(deltas.get("bankroll_delta", 0)) != 0 or int(deltas.get("suspicion_delta", 0)) != 0:
		return true
	for key in ["alcohol_intake", "drunk_delta", "pending_drunk_absorption_delta", "drunk_distortion_suppression_turns", "heat_cooldown_actions", "heat_cooldown_per_action", "alcoholic_delta", "baseline_luck_delta"]:
		if int(deltas.get(key, 0)) != 0:
			return true
	if bool(deltas.get("ended", false)):
		return true
	for key in ["debt_changes", "inventory_add", "inventory_remove", "travel_hooks_add", "story_log", "pending_bags"]:
		if not _copy_array(deltas.get(key, [])).is_empty():
			return true
	for key in ["flags_set", "travel_changes"]:
		var value: Variant = deltas.get(key, {})
		if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
			return true
	return false


# Summarizes result deltas for compact UI copy.
func delta_summary(deltas: Dictionary) -> String:
	var parts: Array = []
	var bankroll_delta := int(deltas.get("bankroll_delta", 0))
	if bankroll_delta != 0:
		parts.append("bankroll %+d" % bankroll_delta)
	var suspicion_delta := int(deltas.get("suspicion_delta", 0))
	if suspicion_delta != 0:
		parts.append("heat %+d" % suspicion_delta)
	var alcohol_intake := int(deltas.get("alcohol_intake", 0))
	if alcohol_intake != 0:
		parts.append("drink +%d" % alcohol_intake)
	var drunk_delta := int(deltas.get("drunk_delta", 0))
	if drunk_delta != 0:
		parts.append("drunk %+d" % drunk_delta)
	var pending_drunk_absorption_delta := int(deltas.get("pending_drunk_absorption_delta", 0))
	if pending_drunk_absorption_delta != 0:
		parts.append("pending drink %+d" % pending_drunk_absorption_delta)
	var drunk_distortion_suppression_turns := int(deltas.get("drunk_distortion_suppression_turns", 0))
	if drunk_distortion_suppression_turns > 0:
		parts.append("steady vision %d" % drunk_distortion_suppression_turns)
	var heat_cooldown_actions := int(deltas.get("heat_cooldown_actions", 0))
	var heat_cooldown_per_action := int(deltas.get("heat_cooldown_per_action", 0))
	if heat_cooldown_actions > 0 and heat_cooldown_per_action > 0:
		parts.append("heat cools %d actions" % heat_cooldown_actions)
	var alcoholic_delta := int(deltas.get("alcoholic_delta", 0))
	if alcoholic_delta != 0:
		parts.append("need %+d" % alcoholic_delta)
	var baseline_luck_delta := int(deltas.get("baseline_luck_delta", 0))
	if baseline_luck_delta != 0:
		parts.append("luck %+d" % baseline_luck_delta)
	var debt_changes := _copy_array(deltas.get("debt_changes", []))
	if not debt_changes.is_empty():
		parts.append("debt added" if debt_changes.size() == 1 else "%d debt changes" % debt_changes.size())
	var flags: Dictionary = deltas.get("flags_set", {})
	if not flags.is_empty():
		parts.append("story changes" if flags.size() == 1 else "%d story changes" % flags.size())
	var travel_hooks := _copy_array(deltas.get("travel_hooks_add", []))
	if not travel_hooks.is_empty():
		parts.append("routes +%d" % travel_hooks.size())
	var inventory_add := _copy_array(deltas.get("inventory_add", []))
	if not inventory_add.is_empty():
		parts.append("items +%d" % inventory_add.size())
	var inventory_remove := _copy_array(deltas.get("inventory_remove", []))
	if not inventory_remove.is_empty():
		parts.append("items -%d" % inventory_remove.size())
	var pending_bags := _copy_array(deltas.get("pending_bags", []))
	if not pending_bags.is_empty():
		parts.append("bags +%d" % pending_bags.size())
	return "; ".join(parts) if not parts.is_empty() else "story changes"


# Summarizes item effects for compact UI copy.
func effect_summary(effect: Dictionary) -> String:
	var parts: Array = []
	for key in effect.keys():
		var key_text := str(key)
		if key_text == "asset_path":
			continue
		if key_text == "synergies":
			continue
		var value: Variant = effect[key]
		if key_text == "families" and typeof(value) == TYPE_DICTIONARY:
			for family_key in (value as Dictionary).keys():
				var family_effect: Variant = (value as Dictionary)[family_key]
				if typeof(family_effect) != TYPE_DICTIONARY:
					continue
				var family_summary := effect_summary(family_effect)
				if not family_summary.is_empty():
					parts.append("%s games: %s" % [label_from_id(str(family_key)), family_summary])
		elif typeof(value) == TYPE_DICTIONARY:
			var nested_summary := effect_summary(value)
			if not nested_summary.is_empty():
				parts.append("%s: %s" % [effect_summary_label(key_text), nested_summary])
		else:
			parts.append("%s %s" % [effect_summary_label(key_text), effect_summary_value(value)])
	return "; ".join(parts)


func effect_summary_label(key: String) -> String:
	match key:
		"win_chance":
			return "better odds"
		"legal_win_chance":
			return "clean-play odds"
		"cheat_suspicion_delta":
			return "risky-play heat"
		"suspicion_delta":
			return "heat"
		"alcohol_intake":
			return "drink"
		"drunk_delta":
			return "drunk"
		"pending_drunk_absorption_delta":
			return "pending drink"
		"drunk_distortion_suppression_turns":
			return "steady vision"
		"alcoholic_delta":
			return "need"
		"baseline_luck_delta":
			return "baseline luck"
		"loss_reduction":
			return "loss cushion"
		"win_bonus":
			return "win payout"
		"bankroll_delta":
			return "cash"
		"debt_changes":
			return "debt pressure"
		"debt_grace_turns":
			return "debt grace"
		"debt_default_heat_delta":
			return "default heat"
		"inventory_add":
			return "adds"
		"inventory_remove":
			return "removes"
		"flags_set":
			return "story shift"
		"travel_hooks_add":
			return "new routes"
		"travel_changes":
			return "travel shift"
		"travel_scouting_level":
			return "route scouting"
		"item_hooks":
			return "item effect"
		"event_hooks":
			return "event effect"
		_:
			return _fallback_effect_summary_label(key)


func _fallback_effect_summary_label(key: String) -> String:
	var clean_key := key.strip_edges()
	if clean_key.ends_with("_delta"):
		clean_key = clean_key.trim_suffix("_delta")
	if clean_key.ends_with("_msec"):
		clean_key = clean_key.trim_suffix("_msec")
	clean_key = clean_key.replace("suspicion", "heat")
	clean_key = clean_key.replace("skill_cheat", "skill check")
	clean_key = clean_key.replace("window_offset", "window margin")
	clean_key = clean_key.replace("memory_offset", "memory margin")
	clean_key = clean_key.replace("base_heat", "base heat")
	clean_key = clean_key.replace("catch_chance", "catch chance")
	clean_key = clean_key.replace("cue_count", "cue count")
	clean_key = clean_key.replace("memory_tolerance", "memory tolerance")
	clean_key = clean_key.replace("loss_reduction", "loss cushion")
	clean_key = clean_key.replace("win_chance", "better odds")
	return label_from_id(clean_key)


func effect_summary_value(value: Variant) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var parts: Array = []
		for key in (value as Dictionary).keys():
			parts.append("%s %s" % [label_from_id(str(key)), effect_summary_value((value as Dictionary)[key])])
		return "; ".join(parts)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var amount := float(value)
		var value_text := str(value)
		if is_equal_approx(amount, float(int(amount))):
			value_text = str(int(amount))
		if amount > 0.0:
			return "+%s" % value_text
		return value_text
	return str(value)


func label_from_id(id: String) -> String:
	if id == "high_roller_cashout":
		return "Players Card"
	return id.replace("_", " ").capitalize()


func hook_run_status(kind: String, definition: Dictionary) -> Dictionary:
	if run_state == null:
		return {"available": true, "disabled_reason": "", "cost": int(definition.get("cost", 0))}
	if kind == "service":
		var service_id := str(definition.get("id", ""))
		if _service_blocked_by_challenge(definition):
			return {
				"available": false,
				"disabled_reason": "This challenge blocks that service.",
				"cost": int(definition.get("cost", 0)),
			}
		if _is_jazz_custom_service(service_id):
			return _jazz_service_status(service_id, definition)
		var service_definition := definition.duplicate(true)
		if _jazz_comped_house_drink_applies(service_id):
			service_definition["cost"] = 0
		return run_state.service_hook_status(service_definition)
	if kind == "lender":
		var lender_status := run_state.lender_hook_status(definition)
		return _dynamic_lender_status(definition, lender_status)
	return {"available": true, "disabled_reason": "", "cost": int(definition.get("cost", 0))}


func _dynamic_lender_result(lender_id: String, definition: Dictionary, status: Dictionary) -> Dictionary:
	if not bool(status.get("available", false)):
		return {}
	var deltas := _dynamic_lender_deltas(definition, status)
	if not result_deltas_have_mutation(deltas):
		return {}
	var display_name := hook_display_name("lender", lender_id, definition)
	var message := str(definition.get("message", "Borrowed from %s." % display_name))
	var messages := _copy_array(deltas.get("messages", []))
	if messages.is_empty():
		messages.append(message)
	deltas["messages"] = messages
	var story_log := _copy_array(deltas.get("story_log", []))
	if story_log.is_empty():
		story_log.append({
			"type": "lender_hook",
			"id": lender_id,
			"label": display_name,
			"environment_id": str(run_state.current_environment.get("id", "")),
			"environment_archetype_id": str(run_state.current_environment.get("archetype_id", "")),
			"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
			"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
			"debt_changes": _copy_array(deltas.get("debt_changes", [])),
			"message": message,
		})
	deltas["story_log"] = story_log
	return GameModule.build_action_result({
		"ok": true,
		"type": "lender_hook",
		"source_id": lender_id,
		"action_id": "borrow",
		"action_kind": "lender",
		"environment_id": str(run_state.current_environment.get("id", "")),
		"environment_archetype_id": str(run_state.current_environment.get("archetype_id", "")),
		"deltas": deltas,
		"message": message,
	})


func _dynamic_lender_status(definition: Dictionary, base_status: Dictionary) -> Dictionary:
	var status := base_status.duplicate(true)
	if not bool(status.get("available", true)):
		return status
	var lender_type := str(definition.get("lender_type", ""))
	var profile := _copy_dict(definition.get("debt_profile", {}))
	if lender_type == "pawn":
		var collateral := _pawn_collateral_option(profile)
		if collateral.is_empty():
			status["available"] = false
			status["disabled_reason"] = "Sal needs a sellable item as collateral."
			status["availability_class"] = RunState.AVAILABILITY_TRANSIENT_BLOCKED
		else:
			status["collateral_item_id"] = str(collateral.get("item_id", ""))
			status["collateral_item_name"] = str(collateral.get("item_name", ""))
			status["loan_amount"] = int(collateral.get("loan_amount", 0))
	elif not profile.is_empty():
		status["loan_amount"] = _profile_loan_amount(profile, str(definition.get("id", "")))
	return status


func _dynamic_lender_deltas(definition: Dictionary, status: Dictionary) -> Dictionary:
	var deltas := GameModule.empty_result_deltas()
	if not bool(status.get("available", true)):
		return deltas
	var lender_id := str(definition.get("id", ""))
	var lender_type := str(definition.get("lender_type", ""))
	var profile := _copy_dict(definition.get("debt_profile", {}))
	match lender_type:
		"favor_crew":
			return _crew_lender_deltas(definition, profile)
		"family_phone":
			return _family_lender_deltas(definition, profile)
		"pawn":
			return _pawn_lender_deltas(definition, profile, status)
		_:
			if not lender_id.is_empty() and not profile.is_empty():
				return _cash_lender_deltas(definition, profile)
	return deltas


func _crew_lender_deltas(definition: Dictionary, profile: Dictionary) -> Dictionary:
	var lender_id := str(definition.get("id", "the_crew"))
	var loan_amount := _profile_loan_amount(profile, lender_id)
	var favor_count := maxi(1, int(profile.get("favor_count", 2)))
	var deadline_turns := maxi(0, int(profile.get("deadline_turns", 2)))
	var location_id := _current_lender_location_id()
	var debt_change := {
		"id": "%s_marker" % lender_id,
		"lender_id": lender_id,
		"balance": favor_count,
		"principal": loan_amount,
		"status": "active",
		"debt_kind": "favor",
		"deadline_turns": deadline_turns,
		"turns_remaining": deadline_turns,
		"loan_count": 1,
		"source_location_id": location_id,
		"source_location_ids": [location_id] if not location_id.is_empty() else [],
		"interest_rate": 0.0,
		"default_consequence": str(profile.get("default_consequence", "crew_favor_due")),
		"refuse_consequence": str(profile.get("refuse_consequence", "crew_convert_to_cash")),
		"cash_conversion_balance_per_favor": maxi(1, int(profile.get("cash_conversion_balance_per_favor", 45))),
		"cash_conversion_interest_rate": maxf(0.0, float(profile.get("cash_conversion_interest_rate", 0.35))),
	}
	return _dynamic_lender_delta_payload(definition, loan_amount, [debt_change], {
		"crew_marker_open": true,
	}, ["The Crew wants favors, not interest."])


func _family_lender_deltas(definition: Dictionary, profile: Dictionary) -> Dictionary:
	var lender_id := str(definition.get("id", "brother_in_law"))
	var loan_amount := _profile_loan_amount(profile, lender_id)
	var interest_rate := maxf(0.0, float(profile.get("interest_rate", 0.0)))
	var balance := maxi(loan_amount, int(ceil(float(loan_amount) * (1.0 + interest_rate))))
	var deadline_turns := maxi(0, int(profile.get("deadline_turns", 6)))
	var debt_change := {
		"id": "%s_note" % lender_id,
		"lender_id": lender_id,
		"balance": balance,
		"principal": loan_amount,
		"status": "active",
		"debt_kind": "cash",
		"deadline_turns": deadline_turns,
		"turns_remaining": deadline_turns,
		"source_location_id": _current_lender_location_id(),
		"interest_rate": interest_rate,
		"default_consequence": str(profile.get("default_consequence", "family_nag")),
		"early_repay_flag": str(profile.get("early_repay_flag", "brother_in_law_goodwill")),
		"late_scar_flag": str(profile.get("late_scar_flag", "brother_in_law_story_scar")),
		"nag_interval_turns": maxi(1, int(profile.get("nag_interval_turns", 3))),
	}
	var availability := _copy_dict(definition.get("availability", {}))
	var single_use_flag := str(availability.get("single_use_flag", "brother_in_law_loan_used"))
	var flags := {}
	if not single_use_flag.is_empty():
		flags[single_use_flag] = true
	flags["brother_in_law_phone_ready"] = false
	return _dynamic_lender_delta_payload(definition, loan_amount, [debt_change], flags, ["Fair money, family pressure."])


func _cash_lender_deltas(definition: Dictionary, profile: Dictionary) -> Dictionary:
	var lender_id := str(definition.get("id", ""))
	if lender_id.is_empty():
		return GameModule.empty_result_deltas()
	var loan_amount := _profile_loan_amount(profile, lender_id)
	var interest_rate := maxf(0.0, float(profile.get("interest_rate", 0.10)))
	var balance := maxi(loan_amount, int(ceil(float(loan_amount) * (1.0 + interest_rate))))
	var deadline_turns := maxi(0, int(profile.get("deadline_turns", 3)))
	var debt_change := {
		"id": "%s_note" % lender_id,
		"lender_id": lender_id,
		"balance": balance,
		"principal": loan_amount,
		"status": "active",
		"debt_kind": "cash",
		"deadline_turns": deadline_turns,
		"turns_remaining": deadline_turns,
		"source_location_id": _current_lender_location_id(),
		"interest_rate": interest_rate,
		"default_consequence": str(profile.get("default_consequence", "favor_owed")),
	}
	var flags := {}
	flags["%s_debt" % lender_id] = true
	var base_effect := copy_result_deltas(definition.get("effect", {}))
	var suspicion_delta := int(base_effect.get("suspicion_delta", 0))
	return _dynamic_lender_delta_payload(definition, loan_amount, [debt_change], flags, ["Loan lands in your hand; payoff comes with interest."], suspicion_delta)


func _pawn_lender_deltas(definition: Dictionary, profile: Dictionary, status: Dictionary) -> Dictionary:
	var collateral := _pawn_collateral_option(profile)
	if collateral.is_empty():
		return GameModule.empty_result_deltas()
	var lender_id := str(definition.get("id", "sals_pawn_counter"))
	var loan_amount := int(collateral.get("loan_amount", status.get("loan_amount", 0)))
	var deadline_turns := maxi(0, int(profile.get("deadline_turns", 5)))
	var item_id := str(collateral.get("item_id", ""))
	var item_name := str(collateral.get("item_name", item_id))
	var debt_change := {
		"id": "%s_%s_ticket" % [lender_id, item_id],
		"lender_id": lender_id,
		"balance": loan_amount,
		"status": "active",
		"debt_kind": "pawn",
		"deadline_turns": deadline_turns,
		"turns_remaining": deadline_turns,
		"interest_rate": 0.0,
		"default_consequence": str(profile.get("default_consequence", "collateral_forfeit")),
		"collateral_item_id": item_id,
		"collateral_item_name": item_name,
	}
	var deltas := _dynamic_lender_delta_payload(definition, loan_amount, [debt_change], {
		"sals_pawn_open": true,
	}, ["%s is in Sal's envelope until you redeem it." % item_name])
	deltas["inventory_remove"] = [item_id]
	return deltas


func _dynamic_lender_delta_payload(definition: Dictionary, bankroll_delta: int, debt_changes: Array, flags: Dictionary, messages: Array, suspicion_delta: int = 0) -> Dictionary:
	var deltas := GameModule.empty_result_deltas()
	var lender_id := str(definition.get("id", ""))
	var display_name := str(definition.get("display_name", lender_id))
	var message := str(definition.get("message", "Borrowed from %s." % display_name))
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	deltas["debt_changes"] = debt_changes.duplicate(true)
	deltas["flags_set"] = flags.duplicate(true)
	deltas["messages"] = messages.duplicate(true)
	if (deltas.get("messages", []) as Array).is_empty():
		deltas["messages"] = [message]
	deltas["story_log"] = [{
		"type": "lender_hook",
		"id": lender_id,
		"label": display_name,
		"environment_id": str(run_state.current_environment.get("id", "")),
		"environment_archetype_id": str(run_state.current_environment.get("archetype_id", "")),
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"debt_changes": debt_changes.duplicate(true),
		"message": message,
	}]
	return deltas


func _profile_loan_amount(profile: Dictionary, lender_id: String = "") -> int:
	var minimum := maxi(0, int(profile.get("principal_min", 0)))
	var maximum := maxi(minimum, int(profile.get("principal_max", minimum)))
	var configured := int(profile.get("loan_amount", minimum))
	var paid_count := 0
	if run_state != null and not lender_id.is_empty():
		paid_count = maxi(0, int(run_state.narrative_flags.get("lender_%s_paid_count" % lender_id, 0)))
	var repeat_step := int(profile.get("repeat_loan_step", maxi(5, int(ceil(float(configured) * 0.25)))))
	return clampi(configured + repeat_step * paid_count, minimum, maximum)


func _current_lender_location_id() -> String:
	if run_state == null:
		return ""
	var environment_id := str(run_state.current_environment.get("id", "")).strip_edges()
	if not environment_id.is_empty():
		return environment_id
	environment_id = str(run_state.current_environment.get("world_node_id", "")).strip_edges()
	if not environment_id.is_empty():
		return environment_id
	return str(run_state.current_environment.get("archetype_id", "")).strip_edges()


func _pawn_collateral_option(profile: Dictionary) -> Dictionary:
	if run_state == null or library == null:
		return {}
	var minimum := maxi(0, int(profile.get("principal_min", 0)))
	var maximum := maxi(minimum, int(profile.get("principal_max", minimum)))
	var multiplier := maxi(1, int(profile.get("loan_to_sale_price_multiplier", 2)))
	for item_value in _copy_array(run_state.inventory):
		var item_id := str(item_value)
		if item_id.is_empty():
			continue
		var detail := inventory_item_detail(item_id)
		if detail.is_empty() or not bool(detail.get("sellable", false)):
			continue
		var sale_price := maxi(0, int(detail.get("sale_price", 0)))
		if sale_price <= 0:
			continue
		var loan_amount := clampi(sale_price * multiplier, minimum, maximum)
		if loan_amount <= 0:
			continue
		return {
			"item_id": item_id,
			"item_name": str(detail.get("display_name", item_id)),
			"sale_price": sale_price,
			"loan_amount": loan_amount,
		}
	return {}


func _lender_has_dynamic_contract(definition: Dictionary) -> bool:
	if ["favor_crew", "family_phone", "pawn"].has(str(definition.get("lender_type", ""))):
		return true
	var profile := _copy_dict(definition.get("debt_profile", {}))
	return not profile.is_empty()


func hook_definition(kind: String, hook_id: String) -> Dictionary:
	if library == null or hook_id.is_empty():
		return {}
	if kind == "service":
		return library.service(hook_id).duplicate(true)
	if kind == "lender":
		return library.lender(hook_id).duplicate(true)
	return {}


func hook_display_name(kind: String, hook_id: String, definition: Dictionary) -> String:
	if not definition.is_empty():
		var display_name := str(definition.get("display_name", definition.get("name", definition.get("label", ""))))
		if not display_name.is_empty():
			return display_name
	return "%s %s" % [label_from_id(kind), label_from_id(hook_id)]


func display_only_hook_status(_kind: String, definition: Dictionary) -> String:
	if definition.is_empty():
		return "Not available here yet."
	return "Not usable yet."


func _service_blocked_by_challenge(definition: Dictionary) -> bool:
	if run_state == null or definition.is_empty():
		return false
	return run_state.challenge_service_category_blocked(str(definition.get("category", "")))


func _is_jazz_custom_service(service_id: String) -> bool:
	return [
		JAZZ_SAX_ROUND_SERVICE_ID,
		JAZZ_CELLO_ROUND_SERVICE_ID,
		JAZZ_DRUMMER_ROUND_SERVICE_ID,
		JAZZ_TIP_JAR_SERVICE_ID,
		JAZZ_LISTEN_SERVICE_ID,
		JAZZ_SHOW_GLASSES_SERVICE_ID,
	].has(service_id)


func _jazz_glasses_service_visible() -> bool:
	return run_state != null and run_state.inventory.has(JAZZ_DRUMMER_GLASSES_ITEM_ID)


func _jazz_comped_house_drink_applies(service_id: String) -> bool:
	return service_id == "house_drink" and _is_jazz_club_environment() and _has_jazz_reward_item()


func _is_jazz_club_environment() -> bool:
	if run_state == null:
		return false
	return str(run_state.current_environment.get("archetype_id", "")) == JAZZ_CLUB_ARCHETYPE_ID


func _has_jazz_reward_item() -> bool:
	if run_state == null:
		return false
	return run_state.inventory.has(JAZZ_SAX_COIN_ITEM_ID) or run_state.inventory.has(JAZZ_CELLO_COIN_ITEM_ID) or run_state.inventory.has(JAZZ_DRUMMER_COIN_ITEM_ID) or run_state.inventory.has(JAZZ_DRUMMER_GLASSES_ITEM_ID)


func _jazz_service_status(service_id: String, definition: Dictionary) -> Dictionary:
	var cost := maxi(0, int(round(float(definition.get("cost", 0)) * run_state.challenge_service_cost_multiplier(definition))))
	var status := {
		"available": true,
		"disabled_reason": "",
		"cost": cost,
		"availability_class": RunState.AVAILABILITY_AVAILABLE,
	}
	if service_id == JAZZ_SHOW_GLASSES_SERVICE_ID:
		status["cost"] = 0
		if not run_state.inventory.has(JAZZ_DRUMMER_GLASSES_ITEM_ID):
			status["available"] = false
			status["disabled_reason"] = "You do not have the drummer's glasses."
			status["availability_class"] = RunState.AVAILABILITY_CATEGORICAL_UNAVAILABLE
			return status
		var location_id := run_state.current_suspicion_location_id()
		if bool(run_state.narrative_flags.get(_jazz_glasses_used_flag(location_id), false)):
			status["available"] = false
			status["disabled_reason"] = "The glasses have already cooled heat here tonight."
			status["availability_class"] = RunState.AVAILABILITY_TRANSIENT_BLOCKED
			return status
		if run_state.suspicion_level() <= 0:
			status["available"] = false
			status["disabled_reason"] = "No local heat needs cooling."
			status["availability_class"] = RunState.AVAILABILITY_TRANSIENT_BLOCKED
		return status
	if not _is_jazz_club_environment():
		status["available"] = false
		status["disabled_reason"] = "That jazz contact is not here."
		status["availability_class"] = RunState.AVAILABILITY_CATEGORICAL_UNAVAILABLE
		return status
	if _has_jazz_reward_item() and service_id != JAZZ_TIP_JAR_SERVICE_ID:
		status["cost"] = 0
	var musician_id := _jazz_musician_for_service(service_id)
	var reward_claimed := bool(run_state.narrative_flags.get(_jazz_local_flag("reward_claimed"), false))
	if service_id == JAZZ_TIP_JAR_SERVICE_ID and reward_claimed:
		status["available"] = false
		status["disabled_reason"] = "The trio has given all it can tonight."
		status["availability_class"] = RunState.AVAILABILITY_TRANSIENT_BLOCKED
	elif not musician_id.is_empty() and reward_claimed:
		status["available"] = false
		status["disabled_reason"] = "The trio has given all it can tonight."
		status["availability_class"] = RunState.AVAILABILITY_TRANSIENT_BLOCKED
	elif not musician_id.is_empty() and bool(run_state.narrative_flags.get(_jazz_no_item_flag(musician_id), false)):
		status["available"] = false
		status["disabled_reason"] = "%s has already told you there is nothing to give." % _jazz_musician_name(musician_id)
		status["availability_class"] = RunState.AVAILABILITY_TRANSIENT_BLOCKED
	elif not musician_id.is_empty() and run_state.inventory.has(_jazz_item_for_musician(musician_id)):
		status["available"] = false
		status["disabled_reason"] = "You already carry that musician's keepsake."
		status["availability_class"] = RunState.AVAILABILITY_TRANSIENT_BLOCKED
	elif int(status.get("cost", 0)) > run_state.bankroll:
		status["available"] = false
		status["disabled_reason"] = "Not enough bankroll for this round."
		status["availability_class"] = RunState.AVAILABILITY_TRANSIENT_BLOCKED
	return status


func _jazz_service_result(service_id: String, definition: Dictionary, status: Dictionary) -> Dictionary:
	if not bool(status.get("available", false)):
		return {}
	var deltas := GameModule.empty_result_deltas()
	var flags: Dictionary = {}
	var messages: Array = []
	var inventory_add: Array = []
	var story_type := "jazz_club_favor"
	var cost := maxi(0, int(status.get("cost", definition.get("cost", 0))))
	deltas["bankroll_delta"] = -cost
	var baseline_luck_delta := 0
	var favor_key := ""
	var listen_key := _jazz_local_flag("listen_count")
	var favor_count := 0
	var tip_successes := 0
	match service_id:
		JAZZ_SAX_ROUND_SERVICE_ID:
			favor_key = _jazz_favor_flag(JAZZ_MUSICIAN_SAX)
			favor_count = _jazz_increment_flag(flags, favor_key)
			baseline_luck_delta += 1
			messages.append("The sax player leans into a brighter chorus.")
			baseline_luck_delta += _jazz_try_reward_from_round(JAZZ_MUSICIAN_SAX, favor_count, flags, inventory_add, messages)
		JAZZ_CELLO_ROUND_SERVICE_ID:
			favor_key = _jazz_favor_flag(JAZZ_MUSICIAN_CELLO)
			favor_count = _jazz_increment_flag(flags, favor_key)
			deltas["suspicion_delta"] = -1 if run_state.suspicion_level() > 0 else 0
			messages.append("The cellist answers with a low, steady run.")
			baseline_luck_delta += _jazz_try_reward_from_round(JAZZ_MUSICIAN_CELLO, favor_count, flags, inventory_add, messages)
		JAZZ_DRUMMER_ROUND_SERVICE_ID:
			favor_key = _jazz_favor_flag(JAZZ_MUSICIAN_DRUMMER)
			favor_count = _jazz_increment_flag(flags, favor_key)
			deltas["alcohol_intake"] = 4
			messages.append("The drummer gives you a two-tap salute.")
			baseline_luck_delta += _jazz_try_reward_from_round(JAZZ_MUSICIAN_DRUMMER, favor_count, flags, inventory_add, messages)
		JAZZ_TIP_JAR_SERVICE_ID:
			story_type = "jazz_tip_jar"
			deltas["heat_cooldown_actions"] = 3
			deltas["heat_cooldown_per_action"] = 1
			var tip_result := _jazz_apply_tip_jar(flags, inventory_add, messages)
			baseline_luck_delta += int(tip_result.get("baseline_luck_delta", 0))
			favor_count = int(tip_result.get("favor_count", 0))
			tip_successes = int(tip_result.get("tip_successes", 0))
		JAZZ_LISTEN_SERVICE_ID:
			story_type = "jazz_club_listen"
			_jazz_increment_flag(flags, listen_key)
			deltas["suspicion_delta"] = -1 if run_state.suspicion_level() > 0 else 0
			messages.append("You stay for the set and the room lets you breathe.")
		JAZZ_SHOW_GLASSES_SERVICE_ID:
			story_type = "jazz_glasses_heat_clear"
			var location_id := run_state.current_suspicion_location_id()
			var cleared_heat := run_state.suspicion_level()
			deltas["suspicion_delta"] = -cleared_heat
			flags[_jazz_glasses_used_flag(location_id)] = true
			messages.append("The drummer's glasses stop the whispers cold.")
		_:
			messages.append(str(definition.get("message", "The jazz room shifts around you.")))
	deltas["baseline_luck_delta"] = baseline_luck_delta
	deltas["inventory_add"] = inventory_add
	deltas["flags_set"] = flags
	if messages.is_empty():
		messages.append(str(definition.get("message", "The jazz room shifts around you.")))
	deltas["messages"] = messages
	deltas["story_log"] = [{
		"type": story_type,
		"id": service_id,
		"label": str(definition.get("display_name", service_id)),
		"environment_id": str(run_state.current_environment.get("id", "")),
		"environment_name": str(run_state.current_environment.get("display_name", "")),
		"environment_archetype_id": str(run_state.current_environment.get("archetype_id", "")),
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"alcohol_intake": int(deltas.get("alcohol_intake", 0)),
		"heat_cooldown_actions": int(deltas.get("heat_cooldown_actions", 0)),
		"baseline_luck_delta": baseline_luck_delta,
		"favor_count": favor_count,
		"listen_count": _jazz_flag_value(flags, listen_key),
		"tip_successes": tip_successes,
		"inventory_add": inventory_add.duplicate(true),
		"message": " ".join(messages),
	}]
	return GameModule.build_action_result({
		"ok": true,
		"type": "service_hook",
		"source_id": service_id,
		"action_id": "use_service",
		"action_kind": "service",
		"environment_id": str(run_state.current_environment.get("id", "")),
		"environment_archetype_id": str(run_state.current_environment.get("archetype_id", "")),
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"deltas": deltas,
		"message": " ".join(messages),
	})


func _jazz_try_reward_from_round(musician_id: String, favor_count: int, flags: Dictionary, inventory_add: Array, messages: Array) -> int:
	var setup := _jazz_reward_setup(flags)
	var holder_id := str(setup.get("holder", ""))
	var drinks_required := clampi(int(setup.get("drinks_required", JAZZ_REWARD_MIN_DRINKS)), JAZZ_REWARD_MIN_DRINKS, JAZZ_REWARD_MAX_DRINKS)
	if favor_count < drinks_required:
		messages.append(_jazz_progress_message(musician_id))
		return 0
	if musician_id != holder_id:
		flags[_jazz_no_item_flag(musician_id)] = true
		messages.append(_jazz_no_item_message(musician_id))
		return 0
	flags[_jazz_local_flag("reward_claimed")] = true
	var item_id := _jazz_reward_item_for_musician(musician_id, flags)
	if not item_id.is_empty() and not _item_enabled_for_run(item_id):
		messages.append("%s has nothing for this run's table." % _jazz_musician_name(musician_id))
		return 0
	if item_id.is_empty() or run_state.inventory.has(item_id) or inventory_add.has(item_id):
		messages.append("%s has nothing else to put in your hand tonight." % _jazz_musician_name(musician_id))
		return 0
	inventory_add.append(item_id)
	_jazz_set_reward_obtained_flag(flags, item_id)
	messages.append(_jazz_reward_message(musician_id, item_id))
	return JAZZ_GLASSES_LUCK_REWARD if item_id == JAZZ_DRUMMER_GLASSES_ITEM_ID else JAZZ_COIN_LUCK_REWARD


func _jazz_apply_tip_jar(flags: Dictionary, inventory_add: Array, messages: Array) -> Dictionary:
	var tip_key := _jazz_local_flag("tip_count")
	var tip_count := _jazz_increment_flag(flags, tip_key)
	var rng := run_state.create_rng("jazz_tip_jar:%s:%d" % [str(run_state.current_environment.get("id", JAZZ_CLUB_ARCHETYPE_ID)), tip_count])
	var tip_successes := 0
	var latest_favor_count := 0
	var baseline_luck_delta := 0
	for musician_id in _jazz_musician_ids():
		if bool(flags.get(_jazz_local_flag("reward_claimed"), run_state.narrative_flags.get(_jazz_local_flag("reward_claimed"), false))):
			break
		if rng.randi_range(1, JAZZ_TIP_JAR_CHANCE_DENOMINATOR) != 1:
			continue
		tip_successes += 1
		var favor_count := _jazz_increment_flag(flags, _jazz_favor_flag(musician_id))
		latest_favor_count = favor_count
		messages.append("%s gets a quiet round from the band jar." % _jazz_musician_name(musician_id))
		baseline_luck_delta += _jazz_try_reward_from_round(musician_id, favor_count, flags, inventory_add, messages)
	if tip_successes == 0:
		messages.append("The tip jar swallows the bills; the band nods, but no glass reaches the stage.")
	return {
		"baseline_luck_delta": baseline_luck_delta,
		"favor_count": latest_favor_count,
		"tip_successes": tip_successes,
	}


func _jazz_reward_setup(flags: Dictionary) -> Dictionary:
	var holder_key := _jazz_local_flag("reward_holder")
	var threshold_key := _jazz_local_flag("reward_drinks_required")
	var holder_id := str(flags.get(holder_key, run_state.narrative_flags.get(holder_key, "")))
	var drinks_required := int(flags.get(threshold_key, run_state.narrative_flags.get(threshold_key, 0)))
	var needs_holder_roll := not _jazz_reward_holder_ids().has(holder_id)
	var needs_threshold_roll := drinks_required < JAZZ_REWARD_MIN_DRINKS or drinks_required > JAZZ_REWARD_MAX_DRINKS
	if needs_holder_roll or needs_threshold_roll:
		var rng := run_state.create_rng("jazz_reward:%s" % str(run_state.current_environment.get("id", JAZZ_CLUB_ARCHETYPE_ID)))
		if needs_holder_roll:
			holder_id = str(rng.pick(_jazz_reward_holder_pool(), JAZZ_NO_REWARD_HOLDER))
			flags[holder_key] = holder_id
		if needs_threshold_roll:
			drinks_required = rng.randi_range(JAZZ_REWARD_MIN_DRINKS, JAZZ_REWARD_MAX_DRINKS)
			flags[threshold_key] = drinks_required
	return {
		"holder": holder_id,
		"drinks_required": drinks_required,
	}


func _jazz_musician_ids() -> Array:
	return [JAZZ_MUSICIAN_SAX, JAZZ_MUSICIAN_CELLO, JAZZ_MUSICIAN_DRUMMER]


func _jazz_reward_holder_ids() -> Array:
	return [JAZZ_MUSICIAN_SAX, JAZZ_MUSICIAN_CELLO, JAZZ_MUSICIAN_DRUMMER]


func _jazz_reward_holder_pool() -> Array:
	return [
		JAZZ_MUSICIAN_SAX,
		JAZZ_MUSICIAN_CELLO,
		JAZZ_MUSICIAN_DRUMMER,
	]


func _jazz_musician_for_service(service_id: String) -> String:
	match service_id:
		JAZZ_SAX_ROUND_SERVICE_ID:
			return JAZZ_MUSICIAN_SAX
		JAZZ_CELLO_ROUND_SERVICE_ID:
			return JAZZ_MUSICIAN_CELLO
		JAZZ_DRUMMER_ROUND_SERVICE_ID:
			return JAZZ_MUSICIAN_DRUMMER
		_:
			return ""


func _jazz_item_for_musician(musician_id: String) -> String:
	match musician_id:
		JAZZ_MUSICIAN_SAX:
			return JAZZ_SAX_COIN_ITEM_ID
		JAZZ_MUSICIAN_CELLO:
			return JAZZ_CELLO_COIN_ITEM_ID
		JAZZ_MUSICIAN_DRUMMER:
			return JAZZ_DRUMMER_GLASSES_ITEM_ID
		_:
			return ""


func _jazz_reward_item_for_musician(musician_id: String, flags: Dictionary) -> String:
	if musician_id == JAZZ_MUSICIAN_DRUMMER and _jazz_flag_value(flags, _jazz_local_flag("listen_count")) < JAZZ_DRUMMER_LISTEN_THRESHOLD:
		return JAZZ_DRUMMER_COIN_ITEM_ID
	return _jazz_item_for_musician(musician_id)


func _jazz_set_reward_obtained_flag(flags: Dictionary, item_id: String) -> void:
	match item_id:
		JAZZ_SAX_COIN_ITEM_ID:
			flags["jazz_sax_coin_obtained"] = true
		JAZZ_CELLO_COIN_ITEM_ID:
			flags["jazz_cello_coin_obtained"] = true
		JAZZ_DRUMMER_COIN_ITEM_ID:
			flags["jazz_drummer_coin_obtained"] = true
		JAZZ_DRUMMER_GLASSES_ITEM_ID:
			flags["jazz_drummer_glasses_obtained"] = true


func _jazz_musician_name(musician_id: String) -> String:
	match musician_id:
		JAZZ_MUSICIAN_SAX:
			return "The sax player"
		JAZZ_MUSICIAN_CELLO:
			return "The cellist"
		JAZZ_MUSICIAN_DRUMMER:
			return "The drummer"
		_:
			return "The musician"


func _jazz_no_item_message(musician_id: String) -> String:
	match musician_id:
		JAZZ_MUSICIAN_SAX:
			return "The sax player appreciates the drink, but says he has nothing to give tonight."
		JAZZ_MUSICIAN_CELLO:
			return "The cellist thanks you, then admits she has nothing tucked away tonight."
		JAZZ_MUSICIAN_DRUMMER:
			return "The drummer gives you the grin, not the goods; nothing to give tonight."
		_:
			return "The musician has nothing to give tonight."


func _jazz_progress_message(musician_id: String) -> String:
	match musician_id:
		JAZZ_MUSICIAN_SAX:
			return "The sax player keeps the favor in the pocket and plays on."
		JAZZ_MUSICIAN_CELLO:
			return "The cellist lets the low line linger, but holds the keepsake back."
		JAZZ_MUSICIAN_DRUMMER:
			return "The drummer watches you over the rims and keeps time."
		_:
			return "The musician warms to you, but not enough yet."


func _jazz_reward_message(musician_id: String, item_id: String) -> String:
	match musician_id:
		JAZZ_MUSICIAN_SAX:
			return "He palms you the one lucky coin in the room."
		JAZZ_MUSICIAN_CELLO:
			return "She slides the one lucky coin across the table."
		JAZZ_MUSICIAN_DRUMMER:
			if item_id == JAZZ_DRUMMER_COIN_ITEM_ID:
				return "The local legend flicks you a lucky coin, but keeps his glasses through the short stay."
			return "The local legend leaves his glasses on your table."
		_:
			return "The musician finally gives up a rare keepsake."


func _jazz_favor_flag(musician_id: String) -> String:
	return _jazz_local_flag("%s_favor" % musician_id)


func _jazz_increment_flag(flags: Dictionary, key: String) -> int:
	var next_value := int(run_state.narrative_flags.get(key, 0)) + 1
	flags[key] = next_value
	return next_value


func _jazz_flag_value(flags: Dictionary, key: String) -> int:
	if flags.has(key):
		return int(flags.get(key, 0))
	return int(run_state.narrative_flags.get(key, 0))


func _jazz_local_flag(suffix: String) -> String:
	var environment_id := str(run_state.current_environment.get("id", JAZZ_CLUB_ARCHETYPE_ID))
	return "jazz_%s_%s" % [environment_id, suffix]


func _jazz_no_item_flag(musician_id: String) -> String:
	return _jazz_local_flag("%s_no_item" % musician_id)


func _jazz_glasses_used_flag(location_id: String) -> String:
	var safe_location := location_id if not location_id.strip_edges().is_empty() else "unknown"
	return "jazz_glasses_cleared_%s" % safe_location


func _environment_archetype(archetype_id: String) -> Dictionary:
	if library == null or archetype_id.is_empty():
		return {}
	for archetype in library.environment_archetypes:
		if typeof(archetype) == TYPE_DICTIONARY and str((archetype as Dictionary).get("id", "")) == archetype_id:
			return (archetype as Dictionary).duplicate(true)
	return {}


func _find_option(options: Array, option_id: String) -> Dictionary:
	if option_id.is_empty():
		return {}
	for option in options:
		if typeof(option) == TYPE_DICTIONARY and str((option as Dictionary).get("id", "")) == option_id:
			return (option as Dictionary).duplicate(true)
	return {}


func _service_success(result: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"result": result.duplicate(true),
		"message": str(result.get("message", "")),
	}


func _service_error(message: String) -> Dictionary:
	return {
		"ok": false,
		"result": {},
		"message": message,
	}


static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	for entry in _copy_array(value):
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result
