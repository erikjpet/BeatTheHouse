extends "res://scripts/tests/character_offers_check.gd"

const InteractionController := preload("res://scripts/ui/environment_interaction_controller.gd")
const PixelCanvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
const FIXED_RIDE_LABEL := "Heading to the Grand Casino"

class OfferRefreshHost extends "res://scripts/ui/foundation_main.gd":
	var offer_refreshes := 0

	func _render_environment_canvas_snapshot() -> void:
		offer_refreshes += 1
		rendered_character_offer_presence_stamp = _character_offer_visible_cache_stamp()

func _run() -> void:
	library = ContentLibraryScript.new()
	library.load(false)
	var winner := _winner("marco")
	var run := RunStateScript.new()
	run.start_new(winner.seed_text)
	run.game_clock_minutes = 1380
	var environment := EnvironmentInstanceScript.from_archetype(library.environment_archetype("motel"), 1, run.create_rng("offer_cache_fixture"), library).to_dict()
	environment["world_node_id"] = "motel"
	var installed := run.set_environment(environment)
	_expect(bool(installed.get("ok", false)), "A generated production motel installs through its normal boundary.")
	var host := _iris_host(run)
	var before_records: Array = host._interactable_object_view_list()
	var before := _marco_record(before_records)
	_expect(not before.is_empty() and before.has("character_offer"), "Winning Marco offer is published on its real authenticated host through the production cache.")
	var base_catalog: Array = host.interactable_object_catalog_cache
	var before_signature := host._environment_snapshot_signature()
	var existing_action_ids: Array = []
	for action in before.get("attached_room_actions", []):
		if not str(action.get("id", "")).begins_with("character_offer:"):
			existing_action_ids.append(str(action.get("id", "")))
	var offer := _view(run, "marco")
	var declined := CharacterOfferModelScript.resolve(run, library, str(OFFER_IDS.marco), offer.token, false)
	_expect(bool(declined.get("ok", false)) and _view(run, "marco").is_empty(), "The authoritative offer has resolved as declined.")
	_expect(host._environment_snapshot_signature() != before_signature, "The canvas snapshot signature tracks a resolved offer without clock or room changes.")
	var after_records: Array = host._interactable_object_view_list()
	var after := _marco_record(after_records)
	_expect(not after.is_empty() and not after.has("character_offer"), "Declining removes the cached offer without an unrelated room action.")
	var after_action_ids: Array = []
	for action in after.get("attached_room_actions", []):
		after_action_ids.append(str(action.get("id", "")))
	_expect(after_action_ids == existing_action_ids, "Declining retains the existing host service actions.")
	_expect(is_same(host.interactable_object_catalog_cache, base_catalog), "Offer-only changes retain the expensive sealed room catalog.")
	host.free()
	_check_background_offer_refresh()
	_check_fixed_ride_cache_refresh()
	_finish()

func _check_background_offer_refresh() -> void:
	var run := _winner("rafi")
	var host := OfferRefreshHost.new()
	host.run_state = run
	host.library = library
	host.environment_canvas = PixelCanvas.new()
	host._refresh_character_offer_visibility()
	_expect(host.offer_refreshes == 1, "A visible coffee offer can request its initial card projection.")
	host._refresh_character_offer_visibility()
	_expect(host.offer_refreshes == 1, "Unchanged offers do not refresh the room repeatedly.")
	run.bankroll = 2
	host._refresh_character_offer_visibility()
	_expect(host.offer_refreshes == 2, "A background wallet change that makes coffee ineligible refreshes the card.")
	run.game_clock_minutes += 1
	host._refresh_character_offer_visibility()
	_expect(host.offer_refreshes == 2, "Ordinary clock movement without visibility change retains the cheap background patch.")
	run.bankroll = 100
	host._refresh_character_offer_visibility()
	_expect(host.offer_refreshes == 3, "A newly affordable background coffee offer becomes visible.")
	run.drunk_level += 1
	host._refresh_character_offer_visibility()
	_expect(host.offer_refreshes == 3, "An alcohol change that preserves eligibility does not rebuild the room.")
	host.environment_canvas.free()
	host.environment_canvas = null
	host.free()

func _check_fixed_ride_cache_refresh() -> void:
	var winner := _winner("rafi")
	if winner == null:
		return
	var run := RunStateScript.new()
	run.start_new(winner.seed_text)
	run.game_clock_minutes = winner.game_clock_minutes
	run.bankroll = 100
	run.drunk_level = 0
	run.pending_drunk_absorption = []
	run.environment_history = [{"id": "previous_fixture", "archetype_id": "apartment", "world_node_id": "apartment", "display_name": "Home", "kind": "home"}]
	var environment := EnvironmentInstanceScript.from_archetype(library.environment_archetype("bar"), 1, run.create_rng("ride_cache_bar"), library).to_dict()
	environment["world_node_id"] = "bar"
	var installed := run.set_environment(environment)
	_expect(bool(installed.get("ok", false)), "The fixed-ride cache fixture installs a production Bar.")
	var grand := EnvironmentInstanceScript.from_archetype(library.environment_archetype("grand_casino"), 2, run.create_rng("ride_cache_grand"), library).to_dict()
	grand["world_node_id"] = "grand_casino"
	run.world_map = WorldMapScript.normalize({
		"version": 3, "start_node_id": "apartment", "current_node_id": "bar", "visited_path": ["apartment", "bar"],
		"nodes": [
			{"id": "bar", "archetype_id": "bar", "label": "Bar", "kind": "bar", "state": "visited", "seen": true},
			{"id": "grand_casino", "archetype_id": "grand_casino", "label": "Grand Casino", "kind": "casino", "state": "visited", "seen": true, "environment": grand},
			{"id": "apartment", "archetype_id": "apartment", "label": "Home", "kind": "home", "state": "visited", "seen": true},
		],
		"edges": [{"a": "bar", "b": "grand_casino", "distance_blocks": 8, "base_cost": 70, "cost": 70}, {"a": "bar", "b": "apartment", "distance_blocks": 2}],
	})
	run.narrative_flags["grand_casino_invite"] = false
	var host := OfferRefreshHost.new()
	host.library = library
	host.run_state = run
	host.generator = RunGeneratorScript.new(library)
	for field in host.RUN_UI_SCRIPT_PATHS:
		host.set(str(field), load(str(host.RUN_UI_SCRIPT_PATHS[field])))
	host.current_screen = host.SCREEN_ENVIRONMENT
	host.environment_canvas = PixelCanvas.new()
	var initial_records: Array = host._interactable_object_view_list()
	var initial := _rafi_record(initial_records)
	_expect(not initial.is_empty() and bool(initial.get("manifest_physical", false)) and str(initial.get("presentation_mode", "room")) == "room", "The production Bar fixture authenticates Rafi's physical card before cache checks; room authority errors: %s" % JSON.stringify(_room_authority_errors(initial_records)))
	_expect(not initial.is_empty() and not initial.has("character_offer"), "Rafi's real cached card has no ride before route eligibility.")
	_expect(str(_record(run, "rafi").get("status", "")) == "available" and str(_record(run, "rafi").get("offer_id", "")) == "", "The blocked ride retains an unbound winning daily decision.")
	var base_catalog: Array = host.interactable_object_catalog_cache
	var roll: Variant = _record(run, "rafi").get("roll")
	var clock := run.game_clock_minutes
	var cash := run.bankroll
	host._refresh_character_offer_visibility()
	var refreshes := host.offer_refreshes
	run.narrative_flags["grand_casino_invite"] = true
	host._refresh_character_offer_visibility()
	_expect(host.offer_refreshes == refreshes + 1, "An invitation-only change refreshes a pending Rafi ride in the background.")
	var selected := _rafi_record(host._interactable_object_view_list())
	_expect(str((selected.get("character_offer", {}) as Dictionary).get("id", "")) == "rafi_grand_casino_ride" and _has_offer_action(selected, FIXED_RIDE_LABEL), "The refreshed real Rafi card exposes the selected ride and its inline action.")
	_expect(_record(run, "rafi").get("roll") == roll and str(_record(run, "rafi").get("offer_id", "")) == "rafi_grand_casino_ride", "Background eligibility binds the same saved roll to Rafi's ride exactly once.")
	_expect(is_same(host.interactable_object_catalog_cache, base_catalog), "Binding the ride preserves the sealed production Bar catalog.")
	var visible_nodes: Array = (run.world_map.get("nodes", []) as Array).duplicate(true)
	for gate in ["invitation", "travel_lock", "visibility"]:
		refreshes = host.offer_refreshes
		_set_ride_cache_gate(run, gate, true, visible_nodes)
		host._refresh_character_offer_visibility()
		var blocked := _rafi_record(host._interactable_object_view_list())
		_expect(host.offer_refreshes == refreshes + 1 and not blocked.has("character_offer") and not _has_offer_action(blocked, FIXED_RIDE_LABEL), "A selected ride disappears from the cached card after an unchanged-clock %s gate closes." % gate)
		_expect(str(_record(run, "rafi").get("offer_id", "")) == "rafi_grand_casino_ride" and _record(run, "rafi").get("roll") == roll, "Closing the %s gate preserves Rafi's selected daily decision." % gate)
		_expect(is_same(host.interactable_object_catalog_cache, base_catalog), "A %s eligibility patch retains the sealed Bar catalog." % gate)
		_set_ride_cache_gate(run, gate, false, visible_nodes)
		host._refresh_character_offer_visibility()
		var restored := _rafi_record(host._interactable_object_view_list())
		_expect(host.offer_refreshes == refreshes + 2 and _has_offer_action(restored, FIXED_RIDE_LABEL), "The selected ride reappears when the %s gate opens." % gate)
	var offer: Dictionary = _rafi_record(host._interactable_object_view_list()).get("character_offer", {})
	var declined := CharacterOfferModelScript.resolve(run, library, "rafi_grand_casino_ride", offer.get("token", {}), false)
	refreshes = host.offer_refreshes
	host._refresh_character_offer_visibility()
	var after := _rafi_record(host._interactable_object_view_list())
	_expect(bool(declined.get("ok", false)) and host.offer_refreshes == refreshes + 1 and not after.has("character_offer") and not _has_offer_action(after, FIXED_RIDE_LABEL), "Declining removes the selected ride from the background cache and visible card.")
	_expect(_service_action_ids(after) == _service_action_ids(initial) and is_same(host.interactable_object_catalog_cache, base_catalog), "Ride resolution preserves original Bar services and the same sealed catalog.")
	_expect(run.game_clock_minutes == clock and run.bankroll == cash and _record(run, "rafi").get("roll") == roll, "All invitation, lock, visibility and decline cache changes preserve clock, cash and the original daily roll.")
	host.environment_canvas.free()
	host.environment_canvas = null
	host.free()


func _set_ride_cache_gate(run: RunState, gate: String, blocked: bool, visible_nodes: Array) -> void:
	match gate:
		"invitation": run.narrative_flags["grand_casino_invite"] = not blocked
		"travel_lock": run.current_environment["travel_lock_remaining"] = 1 if blocked else 0
		"visibility":
			run.world_map["nodes"] = visible_nodes.duplicate(true)
			if blocked:
				for node in run.world_map["nodes"]:
					if str(node.get("id", "")) == "grand_casino":
						node["state"] = "hidden"
						node["seen"] = false
						node["unlocked"] = false


func _has_offer_action(record: Dictionary, label: String) -> bool:
	for action in record.get("inline_actions", []):
		if str(action.get("label", "")) == label:
			return true
	return false


func _service_action_ids(record: Dictionary) -> Array:
	var ids: Array = []
	for action in record.get("attached_room_actions", []):
		var id := str(action.get("id", ""))
		if not id.begins_with("character_offer:"):
			ids.append(id)
	return ids


func _room_authority_errors(records: Array) -> Array:
	var reasons: Array = []
	for record in records:
		var reason := str(record.get("room_geometry_rejection_reason", ""))
		if not reason.is_empty() and not reasons.has(reason):
			reasons.append(reason)
	return reasons


func _rafi_record(records: Array) -> Dictionary:
	for record in records:
		if str(record.get("manifest_object_id", "")) == "bar:bartender":
			return record
	return {}


func _marco_record(records: Array) -> Dictionary:
	for record in records:
		if str(record.get("manifest_object_id", "")) == "motel:marco":
			return record
	return {}
