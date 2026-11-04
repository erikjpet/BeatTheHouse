extends SceneTree

const Library := preload("res://scripts/core/content_library.gd")
const State := preload("res://scripts/core/run_state.gd")
const Actions := preload("res://scripts/core/run_action_service.gd")
const Badges := preload("res://scripts/core/attribute_badges.gd")
const Card := preload("res://scripts/ui/item_card_view_model.gd")
const Inventory := preload("res://scripts/ui/run_inventory_screen.gd")
const Resolver := preload("res://scripts/core/collection_item_resolver.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button: result += str(node.get("text")) + "\n"
	for child in node.get_children(): result += _text(child)
	return result

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var library := Library.new()
	library.load(false)
	var run := State.new()
	run.start_new("BTH-15-17-FACTUAL-HELP", {})
	run.inventory = ["ledger_pencil", "lucky_penny", "instant_coffee", "cashout_envelope"]
	run.current_environment = {"id": "item-help-room", "archetype_id": "corner_store", "item_offers": [
		{"id": "ledger_pencil", "price": 20}, {"id": "lucky_penny", "price": 18}
	]}
	var actions := Actions.new()
	actions.setup(library, run)
	var before := JSON.stringify(run.to_dict())
	var ledger := actions.inventory_item_detail("ledger_pencil")
	var penny := actions.inventory_item_detail("lucky_penny")
	for item_id in ["ledger_pencil", "lucky_penny"]:
		var detail := actions.inventory_item_detail(item_id)
		var definition := library.item(item_id)
		_check(detail.get("effect") == definition.get("effect"), item_id + " retains exact effect and synergies")
		_check(detail.get("effect_lines") == definition.get("effect_lines"), item_id + " uses authored full lines")
		_check(detail.get("use_instructions") == definition.get("use_instructions"), item_id + " uses authored instructions")
		_check(detail.get("effect_summary") == definition.get("effect_description"), item_id + " uses authored compact summary")
		_check(detail.get("sale_price") == definition.get("sale_price"), item_id + " sale price unchanged")
		_check(detail.get("domain") == definition.get("domain"), item_id + " domain unchanged")
		var card := Card.build(detail)
		_check(not str(card.get("tooltip")).contains("Scratch Penalty Shields"), item_id + " card has no false shield label")
		_check(card.get("affinity_label") == definition.get("game_affinity_label"), item_id + " card keeps authored affinity")
		_check(Badges.item_game_affinity_id(detail) == Badges.item_game_affinity_id(definition), item_id + " affinity identity unchanged")
	_check(Card.build(ledger).get("affinity_label") == "Selected games", "Ledger no longer promises All games")
	_check(str(ledger.effect_summary).contains("Roulette receives neither"), "Ledger summary discloses Roulette boundary")
	_check(str(ledger.effect_lines).contains("Blackjack main") and str(ledger.effect_lines).contains("Bar Dice") and str(ledger.effect_lines).contains("Video Poker"), "Ledger full text lists distinct consumers")
	_check(str(ledger.effect_lines).contains("45%") and str(ledger.effect_lines).contains("85%") and str(ledger.effect_lines).contains("35%"), "Ledger caps are disclosed")
	_check(str(ledger.synergy_lines).contains("Instant Coffee") and str(ledger.synergy_lines).contains("Cashout Envelope"), "Ledger ordinary synergy presentation retained")
	_check(str(penny.effect_summary).contains("79%") and str(penny.effect_summary).contains("80%"), "Penny exposes actual threshold difference")
	_check(str(penny.use_instructions).contains("Existing assisted tickets keep"), "Penny explains persistence after removal")
	_check(str(penny.effect_lines).contains("previously bought tickets do not gain"), "Penny excludes retroactive assistance")
	_check(run.item_effect_total("win_chance", "") == 2, "Ledger plus Coffee keeps existing odds total")
	_check(run.item_effect_total("loss_reduction", "") == 5, "Ledger plus Envelope and Coffee keep existing cushion total")
	_check(run.item_effect_total("scratch_penalty_shields", "scratch") == 1, "Penny serialized modifier remains one")
	var offers := actions.item_offer_view_list()
	_check(offers.size() == 2, "Both offer fixtures visible")
	for offer in offers:
		var definition := library.item(str(offer.id))
		_check(offer.game_affinity_label == definition.game_affinity_label, str(offer.id) + " shop affinity agrees")
		_check(offer.purpose_summary == definition.purpose_summary, str(offer.id) + " shop explains actual benefit before purchase")
		_check(offer.price in [18, 20], str(offer.id) + " shop keeps price")
	# Generated fallback remains available for ordinary and runtime definitions.
	var coffee := actions.inventory_item_detail("instant_coffee")
	_check(coffee.effect_lines == actions._inventory_effect_lines(library.item("instant_coffee").effect), "Unrelated ordinary effect fallback unchanged")
	_check(coffee.use_instructions == actions._inventory_use_instructions("consumable", library.item("instant_coffee").effect), "Unrelated instructions fallback unchanged")
	var fallback := {"id": "help-fallback-fixture", "display_name": "Fixture", "class": "permanent", "domain": "global", "effect": {"loss_reduction": 2}, "effect_lines": [" ", ""], "use_instructions": " "}
	var fallback_detail := actions._inventory_item_detail("help-fallback-fixture", "", fallback)
	_check(fallback_detail.effect_lines.size() == 1 and str(fallback_detail.effect_lines[0]).to_lower() == "loss cushion +2", "Blank authored full copy uses generated fallback")
	_check(str(fallback_detail.use_instructions).contains("No activation"), "Blank authored instructions use default")
	var resolver := Resolver.new()
	var meta := resolver.resolve_run_item(resolver.roll_instance(1002, "separate-ledger-help"))
	var meta_detail := actions._inventory_item_detail(str(meta.id), "", meta)
	_check(not str(meta_detail.effect_summary).contains("Roulette receives neither"), "Separate collection Ledger not overwritten")
	_check(meta_detail.effect == meta.effect, "Separate collection Ledger effects unchanged")
	# Actual inventory controls lay out the new full text inside the existing detail scroll.
	for detail in [ledger, penny]:
		var screen := Inventory.new()
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(screen)
		var item: Dictionary = detail.duplicate(true)
		item["selection_key"] = "carried:0"
		item["storage_source"] = "carried"
		screen.open({"mode": "inventory", "items": [item], "selected_key": "carried:0", "selected": {"id": item.id, "source": "carried"}, "containers": [{"key": "carried", "container_type": "loose_carry", "display_name": "Carried", "slots": [{"slot_index": 0, "occupied": true, "selection_key": "carried:0", "item": item}]}]})
		for frame in range(4): await process_frame
		var detail_box: VBoxContainer = screen.get("_detail_box")
		var text := _text(detail_box)
		_check(not text.contains("All games"), str(item.id) + " rendered facts avoid All games")
		_check(text.contains(str(item.effect_lines[0])), str(item.id) + " actual full panel uses authored text")
		var rects := screen.layout_rects()
		var panel: Rect2 = rects.popup_rect
		_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(panel), str(item.id) + " fixed 16:9 panel remains in viewport")
		var scroll: ScrollContainer = screen.get("_detail_scroll")
		_check(scroll.size.x > 0 and scroll.size.y > 0, str(item.id) + " detail scrolling remains usable")
		var close_button: Button = screen.get("_close_button")
		_check(close_button.focus_mode != Control.FOCUS_NONE and close_button.size.y >= 28, str(item.id) + " existing focus/touch close control retained")
		screen.close()
		screen.queue_free()
		await process_frame
	_check(JSON.stringify(run.to_dict()) == before, "Read-only shop/inventory inspection preserves full run, money, inventory and RNG")
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "fidelity": "Synthetic native offer/inventory/card and rendered fixed-16:9 UI; no wagers or private saves."}, "\t"))
	for failure in failures: push_error(failure)
	print("ITEM_FACTUAL_HELP checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

