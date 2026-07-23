class_name RunInventoryViewModel
extends RefCounted


static func build(run_state: RunState, run_action_service: RunActionService, mode: String, container_id: String, selected: Dictionary) -> Dictionary:
	var items := _inventory_popup_item_view_list(run_state, run_action_service, mode, container_id)
	var containers := _spatial_container_models(run_state, mode, container_id, items)
	var spatial_items := _flatten_container_items(containers)
	var selected_key := _selected_spatial_key(spatial_items, selected)
	return {
		"mode": mode,
		"title": _title_text(run_state, mode, container_id),
		"summary": _summary_text(run_state, run_action_service, mode, container_id),
		"container_id": container_id,
		"selected": selected.duplicate(true),
		"empty_text": _empty_text(mode),
		"items": spatial_items,
		"containers": containers,
		"selected_key": selected_key,
		"active_container_key": _active_container_key(containers, selected_key),
		"layout": {"columns": 2, "presentation": "spatial_container", "stable_view": true},
	}


static func _flatten_container_items(containers: Array) -> Array:
	var result: Array = []
	for container_value in containers:
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		for slot_value in _dictionary_array((container_value as Dictionary).get("slots", [])):
			var item: Dictionary = slot_value.get("item", {}) if typeof(slot_value.get("item", {})) == TYPE_DICTIONARY else {}
			if not item.is_empty():
				result.append(item.duplicate(true))
	return result


static func _spatial_container_models(run_state: RunState, mode: String, container_id: String, items: Array) -> Array:
	var carried: Array = []
	var stored: Array = []
	var tickets: Array = []
	for item_value in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		match str(item.get("storage_source", "carried")):
			"container", "loadout":
				stored.append(item)
			"pawn_ticket":
				tickets.append(item)
			_:
				carried.append(item)
	var result: Array = []
	if mode == "home_container":
		result.append(_container_model("run_carried", "loose_carry", "Carried Items", 0, carried, false))
		for home_container_value in _dictionary_array(run_state.current_home_containers() if run_state != null else []):
			var home_container: Dictionary = home_container_value
			var home_container_id := str(home_container.get("id", ""))
			var container_type := str(home_container.get("item_id", "home_storage")).strip_edges().to_lower()
			if container_type.is_empty():
				container_type = "home_storage"
			var container_items: Array = []
			for item_value in stored:
				if typeof(item_value) == TYPE_DICTIONARY and str((item_value as Dictionary).get("container_id", "")) == home_container_id:
					container_items.append((item_value as Dictionary).duplicate(true))
			result.append(_container_model(
				"run_home:%s" % home_container_id,
				container_type,
				str(home_container.get("display_name", "Home Storage")),
				maxi(0, int(home_container.get("capacity", 0))),
				container_items,
				bool(home_container.get("meta_loadout", false))
			))
		return result
	if mode == "pawn_counter":
		result.append(_container_model("run_carried", "loose_carry", "Carried Items", 0, carried, false))
		if not tickets.is_empty():
			result.append(_container_model("run_pawn_tickets", "pawn_tray", "Pawn Tickets", 0, tickets, false))
		return result
	if mode != "place_container":
		var projected := _meta_loadout_container_models(run_state, items)
		if not projected.is_empty():
			return projected
	var label := "Containers to Place" if mode == "place_container" else "Carried Items"
	result.append(_container_model("run_carried", "loose_carry", label, 0, items, false))
	return result


static func _container_model(key: String, container_type: String, display_name: String, capacity: int, items: Array, read_only: bool) -> Dictionary:
	var slots: Array = []
	for item_value in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var selection_key := _item_selection_key(item, slots.size())
		item["selection_key"] = selection_key
		slots.append({
			"slot_index": slots.size(),
			"occupied": true,
			"selection_key": selection_key,
			"item": item.duplicate(true),
			"actionable": not read_only,
			"disabled_reason": "Packed meta-home items are read-only during this run." if read_only else str(item.get("disabled_reason", "")),
		})
	return {
		"key": key,
		"container_type": container_type,
		"display_name": display_name,
		"capacity": maxi(0, capacity),
		"read_only": read_only,
		"slots": slots,
	}


static func _meta_loadout_container_models(run_state: RunState, items: Array) -> Array:
	if run_state == null:
		return []
	var modifiers := run_state.challenge_modifiers()
	var rows := _dictionary_array(modifiers.get("meta_collection_containers", []))
	if rows.is_empty():
		return []
	var remaining := items.duplicate(true)
	var result: Array = []
	for row_value in rows:
		var row: Dictionary = row_value
		var assigned: Array = []
		for item_id_value in _string_array(row.get("items", [])):
			var item_id := str(item_id_value)
			for index in range(remaining.size()):
				if typeof(remaining[index]) != TYPE_DICTIONARY or str((remaining[index] as Dictionary).get("id", "")) != item_id:
					continue
				var item := (remaining[index] as Dictionary).duplicate(true)
				item["storage_source"] = "loadout"
				assigned.append(item)
				remaining.remove_at(index)
				break
		result.append(_container_model(
			"run_meta:%s" % str(row.get("id", result.size())),
			str(row.get("item_id", "bag")),
			str(row.get("item_id", "bag")).replace("_", " ").capitalize(),
			maxi(0, int(row.get("capacity", 0))),
			assigned,
			false
		))
	if not remaining.is_empty():
		result.append(_container_model("run_carried", "loose_carry", "Loose Carry", 0, remaining, false))
	return result


static func _selected_spatial_key(items: Array, selected: Dictionary) -> String:
	var explicit_key := str(selected.get("selection_key", "")).strip_edges()
	if not explicit_key.is_empty():
		for item_value in items:
			if typeof(item_value) != TYPE_DICTIONARY:
				continue
			var keyed_item: Dictionary = item_value
			if str(keyed_item.get("selection_key", "")) == explicit_key:
				return explicit_key
	var wanted_id := str(selected.get("id", "")).strip_edges()
	var wanted_source := str(selected.get("source", "carried")).strip_edges()
	if wanted_source.is_empty():
		wanted_source = "carried"
	for item_value in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		if str(item.get("id", "")) == wanted_id and str(item.get("storage_source", "carried")) == wanted_source:
			return str(item.get("selection_key", _item_selection_key(item)))
	return ""


static func _item_selection_key(item: Dictionary, slot_index: int = 0) -> String:
	var source := str(item.get("storage_source", "carried")).strip_edges()
	if source == "pawn_ticket":
		var debt_id := str(item.get("debt_id", "")).strip_edges()
		if not debt_id.is_empty():
			return "pawn:ticket:%s" % debt_id
	if source == "container" or source == "loadout":
		var container_id := str(item.get("container_id", "")).strip_edges()
		return "run:%s:%s:%s:%d" % [source, container_id, str(item.get("id", "")), slot_index]
	return "run:%s:%s" % [source if not source.is_empty() else "carried", str(item.get("id", ""))]


static func _active_container_key(containers: Array, selected_key: String) -> String:
	for container_value in containers:
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = container_value
		for slot_value in container.get("slots", []):
			if typeof(slot_value) == TYPE_DICTIONARY and str((slot_value as Dictionary).get("selection_key", "")) == selected_key:
				return str(container.get("key", ""))
	if not containers.is_empty() and typeof(containers[0]) == TYPE_DICTIONARY:
		return str((containers[0] as Dictionary).get("key", ""))
	return ""


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
	for cash_value in run_action_service.portable_ticket_cash_options(lender_id):
		if typeof(cash_value) != TYPE_DICTIONARY:
			continue
		var cash_quote := cash_value as Dictionary
		var pile_item_id := str(cash_quote.get("item_id", "")).strip_edges()
		var pile_detail := run_action_service.inventory_item_detail(pile_item_id)
		if pile_detail.is_empty():
			continue
		pile_detail["storage_source"] = "carried"
		pile_detail["pawn_action"] = "cash_ticket_pile"
		pile_detail["lender_id"] = lender_id
		pile_detail["ticket_count"] = maxi(0, int(cash_quote.get("ticket_count", 0)))
		pile_detail["ticket_face_value"] = maxi(0, int(cash_quote.get("face_value", 0)))
		pile_detail["sal_cash_value"] = maxi(0, int(cash_quote.get("cash_value", 0)))
		result.append(pile_detail)
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
	var containers := _dictionary_array(run_state.current_home_containers())
	var destinations := _storage_destinations(containers)
	var stored_item_counts := _stored_item_counts(containers)
	for item_id in _storable_inventory_item_ids(run_state, run_action_service):
		var clean_item_id := str(item_id)
		var stored_count := int(stored_item_counts.get(clean_item_id, 0))
		if stored_count > 0:
			stored_item_counts[clean_item_id] = stored_count - 1
			continue
		var carried_detail := run_action_service.inventory_item_detail(clean_item_id)
		if carried_detail.is_empty():
			continue
		carried_detail["storage_source"] = "carried"
		carried_detail["container_full"] = _all_destinations_full(destinations)
		carried_detail["storage_destinations"] = destinations.duplicate(true)
		result.append(carried_detail)
	for container_value in containers:
		var container: Dictionary = container_value
		var home_container_id := str(container.get("id", ""))
		var stored_items := _string_array(container.get("items", []))
		var meta_loadout := bool(container.get("meta_loadout", false))
		var other_destinations := _storage_destinations(containers, home_container_id)
		for item_index in range(stored_items.size()):
			var item_id := str(stored_items[item_index])
			var stored_detail := run_action_service.inventory_item_detail(item_id)
			if stored_detail.is_empty():
				continue
			stored_detail["storage_source"] = "loadout" if meta_loadout else "container"
			stored_detail["container_id"] = home_container_id
			stored_detail["container_display_name"] = str(container.get("display_name", "Container"))
			stored_detail["container_slot_index"] = item_index
			stored_detail["storage_destinations"] = other_destinations.duplicate(true)
			stored_detail["sellable"] = false
			stored_detail["active_selected"] = false
			stored_detail["container_read_only"] = meta_loadout
			stored_detail["disabled_reason"] = "Packed meta-home items are read-only during this run." if meta_loadout else ""
			result.append(stored_detail)
	return result


static func _storage_destinations(containers: Array, excluded_container_id: String = "") -> Array:
	var result: Array = []
	for container_value in containers:
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = container_value
		var home_container_id := str(container.get("id", ""))
		if home_container_id.is_empty() or home_container_id == excluded_container_id:
			continue
		var items := _string_array(container.get("items", []))
		var capacity := maxi(0, int(container.get("capacity", 0)))
		var meta_loadout := bool(container.get("meta_loadout", false))
		result.append({
			"container_id": home_container_id,
			"display_name": str(container.get("display_name", "Container")),
			"capacity": capacity,
			"used": items.size(),
			"full": capacity > 0 and items.size() >= capacity,
			"read_only": meta_loadout,
		})
	return result


static func _all_destinations_full(destinations: Array) -> bool:
	if destinations.is_empty():
		return true
	for destination_value in destinations:
		if typeof(destination_value) != TYPE_DICTIONARY:
			continue
		var destination: Dictionary = destination_value
		if not bool(destination.get("read_only", false)) and not bool(destination.get("full", false)):
			return false
	return true


static func _summary_text(run_state: RunState, run_action_service: RunActionService, mode: String, container_id: String) -> String:
	if mode == "merchant_sale":
		return "Sellable run items can be sold here."
	if mode == "pawn_counter":
		return "Cash $%d. Pawn carried gear, redeem pawn tickets, or let Sal cash revealed lottery winners for 20%%." % (run_state.bankroll if run_state != null else 0)
	if mode == "place_container":
		return "Select a carried container to place it as home storage."
	if mode == "home_container":
		var selected_container := _home_container_by_id(run_state, container_id)
		if not selected_container.is_empty():
			var used := _string_array(selected_container.get("items", [])).size()
			var capacity := maxi(0, int(selected_container.get("capacity", 0)))
			if bool(selected_container.get("meta_loadout", false)):
				return "%d/%d packed from the meta-home. Packed item effects apply during this run; items are read-only here." % [used, capacity]
			return "%d/%d stored in %s. Stored item effects do not apply until moved back to inventory." % [used, capacity, str(selected_container.get("display_name", "this container"))]
		var total_stored := 0
		var total_capacity := 0
		for container_value in _dictionary_array(run_state.current_home_containers() if run_state != null else []):
			var home_container: Dictionary = container_value
			total_stored += _string_array(home_container.get("items", [])).size()
			total_capacity += maxi(0, int(home_container.get("capacity", 0)))
		return "%d/%d stored across home containers. Stored item effects do not apply until moved back to inventory." % [total_stored, total_capacity]
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
			return "Home Storage"
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
		if RunState.is_portable_ticket_pile_item(item_id):
			continue
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


static func _stored_item_counts(containers: Array) -> Dictionary:
	var result := {}
	for container_value in containers:
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		for item_id in _string_array((container_value as Dictionary).get("items", [])):
			result[item_id] = int(result.get(item_id, 0)) + 1
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var id := str((entry as Dictionary).get("id", "")) if typeof(entry) == TYPE_DICTIONARY else str(entry)
		if not id.is_empty():
			result.append(id)
	return result


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result
