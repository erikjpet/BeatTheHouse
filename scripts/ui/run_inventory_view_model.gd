class_name RunInventoryViewModel
extends RefCounted


static func build(run_state: RunState, run_action_service: RunActionService, mode: String, container_id: String, selected: Dictionary) -> Dictionary:
	var items := _inventory_popup_item_view_list(run_state, run_action_service, mode, container_id)
	return {
		"mode": mode,
		"title": _title_text(run_state, mode, container_id),
		"summary": _summary_text(run_state, run_action_service, mode, container_id),
		"container_id": container_id,
		"selected": selected.duplicate(true),
		"empty_text": _empty_text(mode),
		"items": items,
		"layout": {"columns": 2},
	}


static func _inventory_popup_item_view_list(run_state: RunState, run_action_service: RunActionService, mode: String, container_id: String) -> Array:
	if mode == "pawn_counter":
		return _pawn_counter_item_details(run_state, run_action_service, container_id)
	if mode == "place_container":
		return _held_container_inventory_details(run_state, run_action_service)
	if mode == "home_container":
		return _home_container_inventory_details(run_state, run_action_service, container_id)
	if run_action_service == null:
		return []
	return run_action_service.inventory_item_view_list()


static func _pawn_counter_item_details(run_state: RunState, run_action_service: RunActionService, lender_id: String) -> Array:
	var result: Array = []
	if run_state == null or run_action_service == null:
		return result
	for quote_value in run_action_service.pawn_quote_options(lender_id):
		if typeof(quote_value) != TYPE_DICTIONARY:
			continue
		var quote := quote_value as Dictionary
		var item_id := str(quote.get("item_id", "")).strip_edges()
		var detail := run_action_service.inventory_item_detail(item_id)
		if detail.is_empty():
			continue
		detail["storage_source"] = "carried"
		detail["pawn_action"] = "pawn"
		detail["lender_id"] = lender_id
		detail["loan_amount"] = maxi(0, int(quote.get("loan_amount", 0)))
		result.append(detail)
	for ticket_value in run_state.pawn_tickets_for_lender(lender_id):
		if typeof(ticket_value) != TYPE_DICTIONARY:
			continue
		var ticket := ticket_value as Dictionary
		var item_id := str(ticket.get("item_id", "")).strip_edges()
		var detail := run_action_service.inventory_item_detail(item_id)
		if detail.is_empty():
			detail = {
				"id": item_id,
				"display_name": str(ticket.get("item_name", item_id.replace("_", " ").capitalize())),
				"description": "Collateral held by Sal.",
				"item_class": "pawn ticket",
				"domain": "global",
				"asset_path": "",
			}
		detail["storage_source"] = "pawn_ticket"
		detail["pawn_action"] = "redeem"
		detail["lender_id"] = lender_id
		detail["debt_id"] = str(ticket.get("debt_id", ""))
		detail["payoff_amount"] = maxi(0, int(ticket.get("payoff_amount", 0)))
		detail["turns_remaining"] = maxi(0, int(ticket.get("turns_remaining", 0)))
		detail["pawn_action_enabled"] = bool(ticket.get("enabled", false))
		detail["disabled_reason"] = str(ticket.get("disabled_reason", ""))
		result.append(detail)
	return result


static func _held_container_inventory_details(run_state: RunState, run_action_service: RunActionService) -> Array:
	var result: Array = []
	if run_state == null or run_action_service == null:
		return result
	for item_id in _string_array(run_state.inventory):
		var option := _container_item_option(run_action_service, item_id)
		if option.is_empty():
			continue
		var detail := run_action_service.inventory_item_detail(item_id)
		if detail.is_empty():
			continue
		detail["storage_source"] = "carried"
		detail["capacity"] = int(option.get("capacity", 0))
		result.append(detail)
	return result


static func _home_container_inventory_details(run_state: RunState, run_action_service: RunActionService, container_id: String) -> Array:
	var result: Array = []
	if run_state == null or run_action_service == null:
		return result
	var container := _home_container_by_id(run_state, container_id)
	var stored_items := _string_array(container.get("items", []))
	for item_id in _storable_inventory_item_ids(run_state, run_action_service):
		var carried_detail := run_action_service.inventory_item_detail(str(item_id))
		if carried_detail.is_empty():
			continue
		carried_detail["storage_source"] = "carried"
		result.append(carried_detail)
	for item_id in stored_items:
		var stored_detail := run_action_service.inventory_item_detail(str(item_id))
		if stored_detail.is_empty():
			continue
		stored_detail["storage_source"] = "container"
		stored_detail["sellable"] = false
		stored_detail["active_selected"] = false
		result.append(stored_detail)
	return result


static func _summary_text(run_state: RunState, run_action_service: RunActionService, mode: String, container_id: String) -> String:
	if mode == "merchant_sale":
		return "Sellable run items can be sold here."
	if mode == "pawn_counter":
		return "Cash $%d. Pawn carried gear, or redeem an open ticket before Sal shelves it." % (run_state.bankroll if run_state != null else 0)
	if mode == "place_container":
		return "Select a carried container to place it as home storage."
	if mode == "home_container":
		var container := _home_container_by_id(run_state, container_id)
		var stored_items := _string_array(container.get("items", []))
		var capacity := maxi(0, int(container.get("capacity", 0)))
		return "%d/%d stored. Stored item effects do not apply until moved back to inventory." % [stored_items.size(), capacity]
	var count := 0
	if run_action_service != null:
		count = run_action_service.inventory_item_view_list().size()
	return "Current run items: %d. Select an icon to inspect description and value." % count


static func _title_text(run_state: RunState, mode: String, container_id: String) -> String:
	match mode:
		"merchant_sale":
			return "Sell Items"
		"pawn_counter":
			return "Pawn Counter"
		"place_container":
			return "Place Storage"
		"home_container":
			var container := _home_container_by_id(run_state, container_id)
			return str(container.get("display_name", "Storage"))
		_:
			return "Inventory"


static func _empty_text(mode: String) -> String:
	match mode:
		"merchant_sale":
			return "No sellable run items yet."
		"pawn_counter":
			return "No pawnable gear or open pawn tickets."
		"place_container":
			return "No carried containers. Pick up a bag, backpack, suitcase, or trunk first."
		"home_container":
			return "No movable items. Carry gear to store, or take stored gear from this container."
		_:
			return "No run items yet."


static func _storable_inventory_item_ids(run_state: RunState, run_action_service: RunActionService) -> Array:
	var result: Array = []
	if run_state == null:
		return result
	for item_id in _string_array(run_state.inventory):
		if _container_item_option(run_action_service, item_id).is_empty():
			result.append(item_id)
	return result


static func _container_item_option(run_action_service: RunActionService, item_id: String) -> Dictionary:
	var clean_id := item_id.strip_edges()
	if clean_id.is_empty() or run_action_service == null or run_action_service.library == null:
		return {}
	var definition := run_action_service.library.item(clean_id)
	if definition.is_empty():
		return {}
	var effect: Dictionary = definition.get("effect", {}) if typeof(definition.get("effect", {})) == TYPE_DICTIONARY else {}
	var capacity := maxi(0, int(definition.get("container_capacity", 0)))
	capacity = maxi(capacity, int(effect.get("container_capacity", 0)))
	var item_class := str(definition.get("class", "")).strip_edges().to_lower()
	if item_class != "container" and capacity <= 0:
		return {}
	return {
		"id": clean_id,
		"display_name": str(definition.get("display_name", clean_id.replace("_", " ").capitalize())),
		"capacity": capacity,
		"description": str(definition.get("description", "")),
	}


static func _home_container_by_id(run_state: RunState, container_id: String) -> Dictionary:
	if run_state == null:
		return {}
	for container_value in run_state.current_home_containers():
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = container_value
		if str(container.get("id", "")) == container_id:
			return container.duplicate(true)
	return {}


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result
