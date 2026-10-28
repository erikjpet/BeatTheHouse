extends RefCounted

# Report-only, versioned summary of rows already removed from story_log.
# N tracks the entire removed prefix; K tracks rows actually observed here.
# A legacy unknown prefix stays unknown as later, known rows are appended.
const SCHEMA := "bth.story_money_archive/v1"


static func normalize_archive(raw: Variant, expected_count: int) -> Dictionary:
	var count := maxi(0, expected_count)
	var unknown := {"schema": SCHEMA, "archived_entry_count": count, "known_entry_count": 0, "sources": {}}
	if typeof(raw) != TYPE_DICTIONARY:
		return unknown
	var archive: Dictionary = raw
	if archive.get("schema") != SCHEMA or not _integer(archive.get("archived_entry_count")) or not _integer(archive.get("known_entry_count")):
		return unknown
	var known := int(archive.known_entry_count)
	if int(archive.archived_entry_count) != count or known < 0 or known > count or typeof(archive.get("sources")) != TYPE_DICTIONARY:
		return unknown
	var sources: Dictionary = archive.sources
	if known == 0 and not sources.is_empty():
		return unknown
	for bucket_key in sources:
		if typeof(bucket_key) != TYPE_STRING or typeof(sources[bucket_key]) != TYPE_DICTIONARY:
			return unknown
		var bucket: Dictionary = sources[bucket_key]
		for field in ["key", "id", "kind", "label_hint", "currency"]:
			if typeof(bucket.get(field)) != TYPE_STRING:
				return unknown
		if bucket.key.is_empty() or bucket.currency not in ["cash", "chips"] or bucket_key != "%s|%s" % [bucket.currency, bucket.key] or not _integer(bucket.get("net")):
			return unknown
	return {"schema": SCHEMA, "archived_entry_count": count, "known_entry_count": known, "sources": sources.duplicate(true)}


static func append_evicted_rows(raw_archive: Variant, previous_archive_count: int, evicted_rows: Array, rules: Dictionary = {}) -> Dictionary:
	var archive := normalize_archive(raw_archive, previous_archive_count)
	_fold_rows(archive.sources, evicted_rows, rules)
	archive.archived_entry_count += evicted_rows.size()
	archive.known_entry_count += evicted_rows.size()
	return archive


static func summarize(raw_archive: Variant, archive_count: int, retained_rows: Array, rules: Dictionary = {}) -> Dictionary:
	var archive := normalize_archive(raw_archive, archive_count)
	var sources: Dictionary = archive.sources.duplicate(true)
	_fold_rows(sources, retained_rows, rules)
	var missing := int(archive.archived_entry_count) - int(archive.known_entry_count)
	return {"sources": sources, "coverage": {
		"archived_entry_count": int(archive.archived_entry_count),
		"known_entry_count": int(archive.known_entry_count),
		"unknown_entry_count": missing,
		"retained_entry_count": retained_rows.size(),
		"complete": missing == 0,
	}}


static func _fold_rows(sources: Dictionary, rows: Array, rules: Dictionary) -> void:
	for value in rows:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		if str(entry.get("type", "")) == "travel_risk_event":
			continue
		var source := money_source(entry)
		var legs := money_legs(entry, rules)
		for currency in legs:
			var delta := int(legs[currency])
			if delta == 0:
				continue
			var bucket_key := "%s|%s" % [currency, source.key]
			var bucket: Dictionary = sources.get(bucket_key, source.merged({"currency": str(currency), "net": 0, "label_hint": ""}))
			bucket.net = int(bucket.net) + delta
			bucket.label_hint = str(entry.get("label", str(source.id).replace("_", " ").capitalize()))
			sources[bucket_key] = bucket


static func money_legs(entry: Dictionary, rules: Dictionary = {}) -> Dictionary:
	var currency := str(entry.get("currency", ""))
	var delta := _story_delta(entry)
	# Old Grand receipts recorded chip movement under bankroll_delta. Only
	# recorded game/room evidence can identify that alias; never use live funds.
	# Rules come from the owner so this pure model has no RunState dependency.
	var legacy_chip_alias: bool = currency.is_empty() and str(entry.get("type", "")) == "game_action" \
		and str(entry.get("game_id", entry.get("id", ""))) in rules.get("chip_game_ids", []) \
		and _recorded_grand_room(entry, rules)
	var chip_alias: bool = currency == "chips" or legacy_chip_alias
	var legs := {}
	# Explicit legs win; the chip alias must not create a duplicate cash leg.
	if entry.has("chips_delta"):
		legs.chips = int(entry.chips_delta)
	elif chip_alias:
		legs.chips = int(entry.get("currency_delta", delta))
	if entry.has("cash_delta"):
		legs.cash = int(entry.cash_delta)
	elif not chip_alias:
		legs.cash = int(entry.get("currency_delta", delta)) if currency == "cash" else delta
	return legs


static func _recorded_grand_room(entry: Dictionary, rules: Dictionary) -> bool:
	var archetypes: Array = rules.get("grand_archetype_ids", [])
	var archetype := str(entry.get("environment_archetype_id", ""))
	if not archetype.is_empty():
		return archetype in archetypes
	var environment_id := str(entry.get("environment_id", ""))
	if environment_id in archetypes:
		return true
	# Same generated-room suffix format used by RunState's location reader.
	# Early Blackjack wager receipts recorded only this stable room ID.
	var separator := environment_id.rfind("_")
	return separator > 0 and environment_id.substr(separator + 1).is_valid_int() \
		and environment_id.substr(0, separator) in archetypes


static func _story_delta(entry: Dictionary) -> int:
	if entry.has("bankroll_delta"):
		return int(entry.bankroll_delta)
	match str(entry.get("type", "")):
		"item_sale": return maxi(0, int(entry.get("sale_price", 0)))
		"item_purchase": return -maxi(0, int(entry.get("price", 0)))
	return 0


static func money_source(entry: Dictionary) -> Dictionary:
	var entry_type := str(entry.get("type", "other"))
	if entry_type == "game_action":
		var game_id := str(entry.get("game_id", entry.get("id", "game")))
		return {"key": "game:%s" % game_id, "id": game_id, "kind": "game"}
	if entry_type == "travel": return {"key": "travel", "id": "travel", "kind": "travel"}
	if entry_type == "item_purchase": return {"key": "items_bought", "id": "items_bought", "kind": "items"}
	if entry_type == "item_sale": return {"key": "items_sold", "id": "items_sold", "kind": "items"}
	if entry_type == "lender_hook" or entry_type.begins_with("debt_"): return {"key": "lender:%s" % str(entry.get("lender_id", entry.get("id", "loans"))), "id": str(entry.get("lender_id", entry.get("id", "loans"))), "kind": "lender"}
	if entry_type == "service_hook": return {"key": "services", "id": "services", "kind": "service"}
	if entry_type.find("event") != -1 or entry.has("event_id"): return {"key": "events", "id": "events", "kind": "event"}
	return {"key": entry_type, "id": str(entry.get("id", entry_type)), "kind": entry_type}


static func _integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and absf(value) <= 9007199254740991.0 and floor(value) == value)
