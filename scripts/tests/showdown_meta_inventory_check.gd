extends SceneTree

# Focused authored event/public RunState check with normal Meta producers.
# Explicit base-room setup bypasses journey, scenarios and rendered input.
const RunScript := preload("res://scripts/core/run_state.gd")
const LibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentScript := preload("res://scripts/core/environment_instance.gd")
const EventScript := preload("res://scripts/core/event_module.gd")
const MetaScript := preload("res://scripts/core/meta_collection_service.gd")
const ResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const SaveScript := preload("res://scripts/core/save_service.gd")
const RngScript := preload("res://scripts/core/rng_stream.gd")
const NumericJsonScript := preload("res://scripts/core/storage_numeric_json.gd")
const SLOT := "showdown_meta_handoff"
var checks := 0
var failures: Array[String] = []
var library: ContentLibrary
var event: EventModule
var environment: Dictionary
var config: Dictionary
var items: Array = []
var modifiers: Dictionary

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
	return ok

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--cold"):
		_cold_continue()
	else:
		_setup()
		if failures.is_empty():
			_trash_and_legacy()
			_rejections()
			_crew_handoff()
	print("SHOWDOWN_META_INVENTORY " + JSON.stringify({"checks": checks, "failures": failures, "cold": args.has("--cold")}))
	quit(0 if failures.is_empty() else 1)

func _setup() -> void:
	library = LibraryScript.new()
	library.load(false)
	event = EventScript.new()
	event.setup(library.event(RunScript.GRAND_CASINO_SHOWDOWN_EVENT_ID), library)
	config = event._grand_casino_showdown_config(event.definition.get("payload", {}))
	var room_rng := RngScript.new()
	room_rng.configure(30212)
	var room := EnvironmentScript.from_archetype(library.environment_archetype("grand_casino"), 2, room_rng, library)
	environment = room.to_dict()
	var meta := MetaScript.new()
	var resolver := ResolverScript.new()
	meta.grant_instance(resolver.roll_instance(1000, "showdown-instance-a"))
	meta.grant_instance(resolver.roll_instance(1000, "showdown-instance-b"))
	_check(meta.save() == OK, "Isolated collection snapshot saved")
	meta.load()
	modifiers = meta.normal_run_start_modifiers()
	items = modifiers.get("meta_collection_loadout", [])
	_check(items.size() == 2 and items[0].get("id") != items[1].get("id"), "Normal producer creates two distinct canonical Meta IDs")

func _new_run(seed: String, crew: bool = true) -> RunState:
	var run := RunScript.new()
	run.start_new(seed, {"mode": "standard", "modifiers": modifiers.duplicate(true)})
	run.set_environment(environment.duplicate(true))
	# Same import boundary as FoundationMain._apply_meta_collection_loadout_to_run.
	run.inventory = items.duplicate(true)
	run.add_item("scratch_pad")
	run.invalidate_inventory_effect_cache()
	if crew:
		run.narrative_flags["crew_favor_completed"] = true
	run.add_suspicion("showdown_meta_check", int(run.current_environment.get("demo_objective", {}).get("showdown_heat_threshold", 85)), "behavior")
	run.evaluate_environment_objective_state()
	var result := event.resolve(run, run.current_environment, "enter_back_room")
	_check(bool(result.get("ok", false)), "Authored arrival starts public showdown walk: " + seed + " " + str(result.get("message", "")))
	return run

func _choice(run: RunState, method: String, id: String) -> Dictionary:
	for value in event.choices(run, run.current_environment):
		if str(value.get("showdown_method", "")) == method and str(value.get("item_id", "")) == id:
			return value
	return {}

func _trash_and_legacy() -> void:
	var run := _new_run("SHOWDOWN-META-TRASH")
	var id := str(items[0].get("id", ""))
	var other_id := str(items[1].get("id", ""))
	var choice := _choice(run, "trash", id)
	_check(not choice.is_empty() and str(choice.get("id", "")) == "trash_item__" + id, "Offered Meta trash choice has compact canonical ID")
	_check(str(choice.get("label", "")).contains("#" + str(items[0].get("meta_collection", {}).get("instance_id", 0))), "Meta choice label distinguishes exact instance")
	var before_effect := run.item_effect_total("win_chance")
	_check(int(items[0].get("effect", {}).get("win_chance", 0)) > 0, "Selected Meta instance has a nonzero passive effect")
	var result := event.resolve(run, run.current_environment, str(choice.get("id", "")))
	_check(bool(result.get("ok", false)), "Offered Meta trash action succeeds")
	_check(not run.carries_item(id) and run.carries_item(other_id) and run.carries_item("scratch_pad"), "Trash removes only selected Meta instance")
	_check(run.item_effect_total("win_chance") == before_effect - int(items[0].get("effect", {}).get("win_chance", 0)), "Trash invalidates selected instance passive effects")
	_check(str(run.narrative_flags.get("grand_casino_showdown_step", "")) == "pat_down", "Meta trash advances to pat-down")
	var settled := run.to_dict()
	_check(not bool(run.resolve_grand_casino_showdown_walk("trash", other_id, config).get("ok", true)) and run.to_dict() == settled, "Repeated walk rejects without mutation")
	var replay := _new_run("SHOWDOWN-META-TRASH")
	var replay_choice := _choice(replay, "trash", id)
	event.resolve(replay, replay.current_environment, str(replay_choice.get("id", "")))
	_check(replay.grand_casino_showdown_walk_status() == run.grand_casino_showdown_walk_status() and replay.rng_state == run.rng_state, "Meta trash RNG/flavor remains deterministic")
	var legacy := _new_run("SHOWDOWN-STRING-TRASH")
	var legacy_result := event.resolve(legacy, legacy.current_environment, "trash_item__scratch_pad")
	_check(bool(legacy_result.get("ok", false)) and not legacy.carries_item("scratch_pad") and legacy.carries_item(id), "Legacy ordinary String trash remains usable")
	var direct := _new_run("SHOWDOWN-META-DIRECT")
	_check(bool(direct.resolve_grand_casino_showdown_walk("trash", id, config).get("ok", false)) and not direct.carries_item(id), "Canonical owner API accepts carried Dictionary item")
	var meta := MetaScript.new()
	meta.load()
	_check(meta.normal_run_start_modifiers() == modifiers, "Run trash leaves persistent collection ownership/effects unchanged")

func _rejections() -> void:
	for lock in ["locked", "reserved", "collateral", "reservation_id", "reserved_for"]:
		var run := _new_run("SHOWDOWN-LOCK-" + lock)
		run.inventory[0][lock] = "owner" if lock in ["reservation_id", "reserved_for"] else true
		var id := str(run.inventory[0].get("id", ""))
		_check(_choice(run, "trash", id).is_empty() and _choice(run, "crew", id).is_empty(), lock + ": ineligible item has no offered discard/handoff")
		var before := run.to_dict()
		_check(not bool(run.resolve_grand_casino_showdown_walk("trash", id, config).get("ok", true)) and run.to_dict() == before, lock + ": owner rejects without mutation")
	var stale := _new_run("SHOWDOWN-META-STALE")
	var id := str(items[0].get("id", ""))
	var old_choice := _choice(stale, "trash", id)
	stale.remove_available_carried_item(id)
	var before := stale.to_dict()
	_check(not bool(event.resolve(stale, stale.current_environment, str(old_choice.get("id", ""))).get("ok", true)) and stale.to_dict() == before, "Stale selected instance rejects without mutation")
	_check(not bool(stale.resolve_grand_casino_showdown_walk("trash", str(items[0]), config).get("ok", true)) and stale.to_dict() == before, "Dictionary-text alias is rejected without mutation")
	var no_crew := _new_run("SHOWDOWN-NO-CREW", false)
	before = no_crew.to_dict()
	_check(_choice(no_crew, "crew", id).is_empty() and not bool(no_crew.resolve_grand_casino_showdown_walk("crew", id, config).get("ok", true)) and no_crew.to_dict() == before, "Crew eligibility remains enforced")
	var ticket := _new_run("SHOWDOWN-TICKET")
	ticket.portable_ticket_piles = {"pull_tabs": {"origin": {"winner_pile": [{"payout": 5}]}}}
	ticket.add_item("pile_of_pull_tabs")
	_check(int(ticket.portable_ticket_pile_summary("pile_of_pull_tabs").get("ticket_count", 0)) > 0, "Synthetic ticket marker has owned ticket payload")
	before = ticket.to_dict()
	_check(_choice(ticket, "trash", "pile_of_pull_tabs").is_empty() and not bool(ticket.resolve_grand_casino_showdown_walk("trash", "pile_of_pull_tabs", config).get("ok", true)) and ticket.to_dict() == before, "Nonremovable ticket marker is not offered or falsely accepted")

func _crew_handoff() -> void:
	var run := _new_run("SHOWDOWN-META-CREW")
	var id := str(items[0].get("id", ""))
	var result := event.resolve(run, run.current_environment, str(_choice(run, "crew", id).get("id", "")))
	if not _check(bool(result.get("ok", false)), "Offered Meta Crew handoff succeeds"):
		return
	_check(not run.carries_item(id) and run.carries_item(str(items[1].get("id", ""))), "Crew holds exactly selected instance")
	_check(run.narrative_flags.get("grand_casino_showdown_crew_handoff_item_entry", {}) == items[0], "Crew escrow preserves complete instance/effect data")
	var save := SaveScript.new()
	_check(save.save_run(run, SLOT) == OK, "Meta handoff saved with ordinary SaveService")
	var loaded: RunState = save.load_run(SLOT)
	if _check(loaded != null, "Same-process SaveService Continue accepts handoff state"):
		_finish_return(loaded, items[0])
	var failed := RunScript.new()
	failed.from_dict(run.to_dict())
	failed._complete_grand_casino_showdown_failure("Focused failure control")
	_check(not failed.carries_item(id) and not failed.narrative_flags.has("grand_casino_showdown_crew_handoff_item_entry") and str(failed.narrative_flags.get("grand_casino_showdown_crew_handoff_lost_on_failure", "")) == id, "Failure clears escrow without returning/duplicating Meta instance")
	var legacy := _new_run("SHOWDOWN-STRING-CREW")
	event.resolve(legacy, legacy.current_environment, "hand_to_crew__scratch_pad")
	legacy.narrative_flags.erase("grand_casino_showdown_crew_handoff_item_entry")
	legacy._return_grand_casino_crew_handoff()
	_check(legacy.inventory.has("scratch_pad"), "Old String-only handoff save remains return-compatible")

func _finish_return(run: RunState, expected: Dictionary) -> void:
	var id := str(expected.get("id", ""))
	run._return_grand_casino_crew_handoff()
	_check(run.carries_item(id) and _same_entry(run.inventory[run.available_carried_item_index(id)], expected) and not run.inventory.has(id), "Crew return restores exact Dictionary, never an opaque String")
	var before := run.to_dict()
	run._return_grand_casino_crew_handoff()
	_check(run.to_dict() == before, "Repeated Crew return is exactly once")

func _cold_continue() -> void:
	var save := SaveScript.new()
	var run: RunState = save.load_run(SLOT)
	if not _check(run != null, "Separate-process cold Continue accepts saved Meta handoff"):
		return
	var meta := MetaScript.new()
	meta.load()
	var start := meta.normal_run_start_modifiers()
	var expected: Dictionary = start.get("meta_collection_loadout", [])[0]
	_check(_same_entry(run.narrative_flags.get("grand_casino_showdown_crew_handoff_item_entry", {}), expected) and not run.carries_item(str(expected.get("id", ""))), "Cold escrow retains exact collection instance without carried duplicate")
	_finish_return(run, expected)
	_check(meta.normal_run_start_modifiers() == start, "Cold handoff return leaves collection ownership unchanged")

func _same_entry(actual: Variant, expected: Variant) -> bool:
	# Save JSON restores all numbers as floats. Compare the complete instance
	# through that existing storage contract, with full float precision retained.
	return NumericJsonScript.parse(NumericJsonScript.stringify(actual)).get("data") == NumericJsonScript.parse(NumericJsonScript.stringify(expected)).get("data")
