extends SceneTree

const Resolver := preload("res://scripts/core/collection_item_resolver.gd")
const MetaService := preload("res://scripts/core/meta_collection_service.gd")
const HomeModel := preload("res://scripts/ui/meta_item_interaction_view_model.gd")
const RunActions := preload("res://scripts/core/run_action_service.gd")
const Library := preload("res://scripts/core/content_library.gd")
const State := preload("res://scripts/core/run_state.gd")

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var resolver := Resolver.new()
	var service := MetaService.new()
	service.load()
	var card := resolver.roll_instance(9500, "card-help")
	card["instance_id"] = 23
	card["instance_data"] = {"tier_reached": "gold", "seed": "preserved-stamp"}
	service.grant_instance(card)
	var modifiers := service.normal_run_start_modifiers()
	var before_profile := JSON.stringify(service.snapshot())
	var run := State.new()
	run.start_new("card-help", {"mode": "standard", "modifiers": modifiers})
	var run_item := resolver.resolve_run_item(card)
	run.inventory.append(run_item)
	var actions := RunActions.new()
	actions.setup(Library.new(), run)
	var before_run := JSON.stringify(run.to_dict())
	for tier in ["bronze", "silver", "gold"]:
		# The earned stamp changes the name/tier, not prestige tuning or loss policy.
		card["instance_data"]["tier_reached"] = tier
		run.inventory[0] = resolver.resolve_run_item(card)
		var detail := actions.inventory_item_detail(str(run_item.get("id", "")))
		_expect(not detail.get("effect_lines", []).is_empty(), "%s run Card has explicit effects" % tier)
		_expect(str(detail.get("effect_summary", "")).contains(str(modifiers.get("grand_casino_prestige_recognition_heat_delta"))), "%s recognition help matches granted modifier" % tier)
		_expect(str(detail.get("effect_summary", "")).contains("Heat: %d" % int(modifiers.get("grand_casino_prestige_clean_heat_ceiling_delta"))), "%s ceiling help matches granted modifier" % tier)
		_expect(str(detail.get("effect_summary", "")).contains("%d tier(s)" % int(modifiers.get("meta_collection_drop_tier_bonus_steps"))), "%s drop help matches granted modifier" % tier)
		_expect(str(detail.get("use_instructions", "")).contains("failed or abandoned") and str(detail.get("use_instructions", "")).contains("permanently destroyed"), "%s warns of carried failure and Abandon" % tier)
		_expect(str(detail.get("use_instructions", "")).contains("cannot be repaired"), "%s explains pinned Critical condition" % tier)
	# Home and run use one description despite separate ordinary item-effect paths.
	var home := HomeModel.build(service, HomeModel.MODE_CONTAINER)
	var home_card: Dictionary = home.get("items", [])[0]
	var run_card := actions.inventory_item_detail(str(run_item.get("id", "")))
	_expect(home_card.get("effect_lines") == run_card.get("effect_lines"), "Home and run effects agree")
	_expect(home_card.get("use_instructions") == run_card.get("use_instructions"), "Home and run instructions agree")
	_expect(not str(home_card).contains("no direct run modifier"), "Home no longer claims Card has no modifier")
	_expect(JSON.stringify(service.snapshot()) == before_profile, "inspection preserves profile, exact Card and meta RNG")
	_expect(JSON.stringify(run.to_dict()) == before_run, "inspection preserves run, exact Card, balances and RNG")
	# Non-Card items retain their regular effects and do not gain Card warnings.
	var ordinary := resolver.resolve_run_item(resolver.roll_instance(1000, "ordinary-help"))
	run.inventory.append(ordinary)
	var ordinary_detail := actions.inventory_item_detail(str(ordinary.get("id", "")))
	_expect(not str(ordinary_detail.get("use_instructions", "")).contains("permanently destroyed"), "ordinary collection item help is unchanged")
	_expect(ordinary_detail.get("effect", {}) == ordinary.get("effect", {}), "ordinary collection effect remains exact")
	var report := {"checks": checks, "failures": failures, "fidelity": "Synthetic native Home/run presentation parity against actual granted prestige modifiers; read-only profile/run checks."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("PLAYERS_CARD_HELP checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
