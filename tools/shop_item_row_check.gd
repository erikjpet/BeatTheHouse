extends SceneTree

# One-shot placement check for merchandise. It generates every archetype in its
# base state and at every authored scenario phase, runs the production base-slot
# binder, and proves that each live offer occupies the shared fixed shop row or
# its exact scenario-local shop position.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var challenge := RunStateScript.standard_challenge("SHOP-ITEM-ROW-CHECK")
	var failures: Array = []
	var room_lines: Array = []
	var variant_count := 0
	var offer_count := 0
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype := (archetype_value as Dictionary).duplicate(true)
		var archetype_id := str(archetype.get("id", "")).strip_edges()
		if archetype_id.is_empty():
			continue
		var room_failures: Array = []
		var listed: Dictionary = {}
		var variants := _scenario_variants(library, archetype_id)
		for variant_index in range(variants.size()):
			var variant := _dict(variants[variant_index])
			var seed := RngStreamScript.derive_seed(62041, variant_index + 1, "%s:%s" % [archetype_id, str(variant.get("label", "base"))])
			var rng: RngStream = RngStreamScript.new()
			rng.configure(seed)
			var environment := EnvironmentInstanceScript.from_archetype(
				archetype,
				3,
				rng,
				library,
				challenge,
				_dict(variant.get("state", {}))
			).to_dict()
			_maximize_authored_stock(environment, archetype, library)
			environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(environment, library)
			var surface_map := EnvironmentPlacementScript.surface_map(environment)
			var scenario_item_slots := _dict(surface_map.get("scenario_instance_object_slot_ids", {}))
			var live_ids := _live_offer_ids(environment)
			var bindings := _dict(_dict(environment.get("layout", {})).get("slot_bindings", {}))
			var manifest_families: Dictionary = {}
			for row_value in EnvironmentInstanceScript.active_object_manifest_rows(environment):
				var row := _dict(row_value)
				manifest_families[str(row.get("presentation_object_id", row.get("object_id", "")))] = str(row.get("family", ""))
			var occupied: Dictionary = {}
			var family_ordinals := {"fixed": 0, "scenario": 0}
			for offer_index in range(live_ids.size()):
				var object_id := str(live_ids[offer_index])
				var binding := _dict(bindings.get(object_id, {}))
				var slot_id := str(binding.get("slot_id", ""))
				var family := str(manifest_families.get(object_id, ""))
				if family not in family_ordinals:
					room_failures.append("%s %s has invalid merchandise family %s" % [str(variant.get("label", "base")), object_id, family])
					continue
				family_ordinals[family] = int(family_ordinals.get(family, 0)) + 1
				var expected_slot := "%s.item_shop_%d" % [family, int(family_ordinals.get(family, 0))]
				if family == "scenario":
					expected_slot = str(scenario_item_slots.get(object_id, ""))
				listed["%s=%s" % [object_id, slot_id if not slot_id.is_empty() else "MISSING"]] = true
				offer_count += 1
				if str(binding.get("presentation_mode", "")) != "room" \
						or str(binding.get("slot_family", "")) != family \
						or str(binding.get("placement_class", "")) != "shop_item" \
						or family == "scenario" and not expected_slot.begins_with("scenario.shop_item_") \
						or slot_id != expected_slot:
					room_failures.append("%s %s expected %s, got %s" % [str(variant.get("label", "base")), object_id, expected_slot, slot_id])
				if occupied.has(slot_id):
					room_failures.append("%s duplicates %s with %s" % [object_id, slot_id, str(occupied.get(slot_id, ""))])
				elif not slot_id.is_empty():
					occupied[slot_id] = object_id
			for binding_id_value in bindings.keys():
				var binding_id := str(binding_id_value)
				var bound_slot := str(_dict(bindings.get(binding_id_value, {})).get("slot_id", ""))
				if bound_slot.begins_with("fixed.item_shop_") and not live_ids.has(binding_id):
					room_failures.append("%s non-offer %s occupies %s" % [str(variant.get("label", "base")), binding_id, bound_slot])
			variant_count += 1
		var entries := listed.keys()
		entries.sort()
		var line := "SHOP_ROW room=%s variants=%d offers=[%s] flagged=%d" % [archetype_id, variants.size(), ", ".join(entries), room_failures.size()]
		print(line)
		room_lines.append(line)
		for failure_value in room_failures:
			failures.append("%s: %s" % [archetype_id, str(failure_value)])
	print("SHOP_ROW_SUMMARY rooms=%d variants=%d offers_checked=%d flagged=%d" % [room_lines.size(), variant_count, offer_count, failures.size()])
	for failure_value in failures:
		printerr("SHOP_ROW_FLAG %s" % str(failure_value))
	quit(0 if failures.is_empty() else 1)


func _scenario_variants(library: ContentLibrary, archetype_id: String) -> Array:
	var result: Array = [{"label": "base", "state": {}}]
	for scenario_value in library._scenarios_for_archetype_readonly(archetype_id):
		if typeof(scenario_value) != TYPE_DICTIONARY:
			continue
		var definition := library._runtime_scenario_definition_unvalidated(scenario_value as Dictionary)
		var phases := _array(definition.get("phases", []))
		var phase_count := maxi(1, phases.size())
		for phase_index in range(phase_count):
			var state := ScenarioEngineScript.initial_state(definition)
			state["phase_index"] = phase_index
			var phase_id := "phase_%d" % phase_index
			if phase_index < phases.size():
				phase_id = str(_dict(phases[phase_index]).get("id", phase_id))
			result.append({
				"label": "%s/%s" % [str(definition.get("id", "scenario")), phase_id],
				"state": state,
			})
	return result


func _maximize_authored_stock(environment: Dictionary, archetype: Dictionary, library: ContentLibrary) -> void:
	var offers := _array(environment.get("item_offers", [])).duplicate(true)
	var maximum := _maximum_count(archetype.get("item_count", 0))
	var seen: Dictionary = {}
	for offer_value in offers:
		seen[str(_dict(offer_value).get("id", ""))] = true
	for item_id_value in _array(archetype.get("item_pool", [])):
		if offers.size() >= maximum:
			break
		var item_id := str(item_id_value)
		if item_id.is_empty() or seen.has(item_id):
			continue
		var definition := library.item(item_id)
		offers.append({
			"id": item_id,
			"display_name": str(definition.get("display_name", item_id)),
			"price": maxi(1, int(definition.get("price_min", 1))),
		})
		seen[item_id] = true
	environment["item_offers"] = offers
	if str(environment.get("archetype_id", "")) == "grand_casino_cage":
		var stock: Array = []
		var shop_config := _dict(_dict(archetype.get("local_narrative_flags", {})).get("casino_gift_shop", {}))
		var stock_maximum := _maximum_count(shop_config.get("stock_count", [3, 4]))
		for candidate_value in _array(shop_config.get("candidate_offers", [])):
			if stock.size() >= stock_maximum:
				break
			var candidate := _dict(candidate_value).duplicate(true)
			candidate["sold"] = false
			stock.append(candidate)
		environment["cage_gift_shop_state"] = {"version": 1, "stock": stock, "stock_count": stock.size()}


func _live_offer_ids(environment: Dictionary) -> Array:
	var result: Array = []
	for offer_value in _array(environment.get("item_offers", [])):
		var item_id := str(_dict(offer_value).get("id", "")).strip_edges()
		if not item_id.is_empty() and not result.has("item:%s" % item_id):
			result.append("item:%s" % item_id)
	var stock := _array(_dict(environment.get("cage_gift_shop_state", {})).get("stock", []))
	for stock_index in range(stock.size()):
		if not bool(_dict(stock[stock_index]).get("sold", false)):
			result.append("cage_gift_item:%d" % stock_index)
	return result


func _maximum_count(value: Variant) -> int:
	var values := _array(value)
	if values.size() >= 2:
		return maxi(0, int(values[1]))
	return maxi(0, int(value))


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []
