extends "res://scripts/tests/character_offers_check.gd"

const InteractionController := preload("res://scripts/ui/environment_interaction_controller.gd")
const PixelCanvas := preload("res://scripts/ui/pixel_scene_canvas.gd")

class OfferRefreshHost extends "res://scripts/ui/foundation_main.gd":
	var offer_refreshes := 0

	func _render_environment_canvas_snapshot() -> void:
		offer_refreshes += 1
		rendered_character_offer_presence_stamp = CharacterOfferModelScript.visible_cache_stamp(run_state, library)

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

func _marco_record(records: Array) -> Dictionary:
	for record in records:
		if str(record.get("manifest_object_id", "")) == "motel:marco":
			return record
	return {}
