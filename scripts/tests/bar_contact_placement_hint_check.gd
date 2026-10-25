extends SceneTree

const Instance := preload("res://scripts/core/environment_instance.gd")
const Placement := preload("res://scripts/core/environment_placement.gd")
const Library := preload("res://scripts/core/content_library.gd")

class FixtureLibrary extends Library:
	var definitions: Dictionary = {}
	func event(event_id: String) -> Dictionary:
		return definitions.get(event_id, {}).duplicate(true)

var checks := 0
var failures: Array[String] = []

func _init() -> void:
	var library := Library.new()
	var loaded := library.load(false)
	_expect(library.is_fully_loaded() and loaded.has("events") and not library.event("crew_contact_lucky").is_empty(), "catalog loads")
	var bar := {"archetype_id": "bar", "art_key": "bar"}
	var surface := Placement.surface_map(bar)
	_expect(not surface.get("seats", []).is_empty(), "real Bar has background stools")
	_expect(not (surface.get("event_slots", []) as Array).any(func(slot: Dictionary) -> bool: return slot.get("footprint_class") == "seated_person"), "real Bar has no authored event seat")
	var hints := Instance._event_placement_hints(["crew_contact_lucky", "town_rumor_staff"], library, bar)
	_expect(hints.get("event:crew_contact_lucky", {}).get("placement_class") == "standing_person", "Lucky uses supported standing contact class instead of an unbindable background stool")
	_expect(hints.get("event:town_rumor_staff", {}).get("placement_class") == "behind_counter_person", "counter staff stays behind counter")

	var fixture := FixtureLibrary.new()
	fixture.definitions = {
		"explicit_seat": {"placement_class": "seated_person", "environment_prop": "rowdy_patron", "speaker": {"character_id": "fixture", "role": "crew"}},
		"patron": {"environment_prop": "rowdy_patron", "speaker": {"character_id": "fixture", "role": "crew"}},
	}
	var explicit := Instance._event_placement_hints(["explicit_seat"], fixture, bar)
	_expect(explicit["event:explicit_seat"]["placement_class"] == "seated_person", "explicit seated content is never silently reclassified")
	# An isolated authored layer supplies a real event seat. This exercises the
	# positive hint contract without modifying shipped coordinates or authority.
	var layer_key := "bar:contact_hint_fixture"
	var layer := surface.duplicate(true)
	(layer["event_slots"] as Array).append({"id": "event.seated_person_fixture", "kind": "event", "footprint_class": "seated_person"})
	Placement._surface_maps[layer_key] = layer
	var with_seat := Instance._event_placement_hints(["patron"], fixture, {"archetype_id": "bar", "current_layer_id": "contact_hint_fixture"})
	_expect(with_seat["event:patron"]["placement_class"] == "seated_person", "authored event seat retains patron seating hint")
	Placement._surface_maps.erase(layer_key)
	Placement._effective_surface_maps.erase(layer_key + "::base")
	Placement._runtime_surface_maps.clear()

	for failure in failures: push_error(failure)
	print("BAR_CONTACT_PLACEMENT_HINT_CHECK " + JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
