extends SceneTree

const Overlay := preload("res://scripts/ui/travel_cinematic_overlay.gd")
const Catalog := preload("res://scripts/ui/travel_presentation_catalog.gd")
const Main := preload("res://scripts/ui/foundation_main.gd")
const FocusScope := preload("res://scripts/ui/modal_focus_scope.gd")
const Appearance := preload("res://scripts/ui/character_appearance_snapshot.gd")
var failures: Array[String] = []
var checks := 0
var completions := 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _run() -> void:
	var overlay := Overlay.new()
	var scope := FocusScope.new()
	overlay.focus_scope = scope
	root.add_child(overlay)
	overlay.completed.connect(func(_id: String) -> void: completions += 1)
	var receipt := {"schema_version":1, "journey_id":"travel_test_1", "presentation_key":"back_alley_bar_typical_v1", "receipt_text":"Traveled to Roadside Bar. Route cost 2, 24 min.", "travel_method_kind":"bus", "travel_method_label":"Bus", "base_minutes":24, "quoted_departure_fare":2, "departed_game_clock_minutes":1200}
	var frozen := var_to_bytes(receipt)
	overlay.present(receipt)
	_expect(overlay.active and overlay.phase == "bus_approach" and overlay.is_processing(), "motion begins autonomously")
	_expect(bool(overlay.snapshot()["has_art"]), "street foreground and layered driving bus load")
	var scene_profile: Dictionary = Catalog.profile(receipt)
	var reference: Array = scene_profile["exterior"]["reference_size"]
	var view_height := 0.80 * float(reference[0]) / float(reference[1]) * 500.0 / 1152.0
	var facade_top := 1.0 - view_height
	_expect(scene_profile.get("backdrop_path", "") != scene_profile["main_scene_path"] and not str(scene_profile.get("backdrop_path", "")).is_empty(), "main scene and distant backdrop are separate assets")
	_expect(not scene_profile.has("ground_path") and not scene_profile.has("foreground_band_top_uv"), "no generic ground plane or foreground band is present")
	_expect(is_equal_approx(float(scene_profile["source_top_y_uv"]), facade_top) and is_equal_approx(float(scene_profile["view_height_uv"]), view_height) and is_equal_approx(float(scene_profile["view_bottom_uv"]), 1.0), "close facade and integrated road crop stays inside the main PNG")
	var stage: Rect2 = overlay.get("_stage")
	var design_scale := overlay.size / Vector2(1280.0, 720.0)
	_expect(stage.is_equal_approx(Rect2(Vector2(64, 116) * design_scale, Vector2(1152, 500) * design_scale)), "travel uses tall 1152 by 500 stage")
	_expect(not overlay.snapshot()["narration_visible"] and overlay.snapshot()["caption"].is_empty(), "travel narration is hidden and empty")
	var previous_main := -1.0
	var previous_far := -1.0
	for index in range(161):
		var windows: Dictionary = overlay.layer_window_snapshot(index * 0.05)
		var main: Rect2 = windows["main"]
		var far: Rect2 = windows["backdrop"]
		_expect(is_equal_approx(far.position.x, main.position.x * 0.35) and is_equal_approx(main.size.x, 0.80) and is_equal_approx(main.position.y, facade_top) and is_equal_approx(main.size.y, view_height), "actual draw windows use the main crop and genuine distant parallax at %d" % index)
		_expect(Rect2(Vector2.ZERO, Vector2.ONE).encloses(main) and Rect2(Vector2.ZERO, Vector2.ONE).encloses(far), "both scenery windows stay within their PNG at %d" % index)
		_expect(main.position.x > previous_main and far.position.x > previous_far, "both scenery layers keep moving through every pause at %d" % index)
		var pose: Dictionary = overlay.choreography_snapshot(index * 0.05)
		_expect(not pose["player_visible"] or (Vector2(pose["player_position_uv"]).y < 1.0 and is_equal_approx(float(pose["player_scale"]), 1.0)), "visible traveler stays within integrated scene at uniform height at %d" % index)
		_expect(not pose["vehicle_visible"] or is_equal_approx(float(pose["vehicle_road_y_uv"]), float(scene_profile["exterior"]["road_y_uv"])), "wheels stay on the actual authored road at %d" % index)
		previous_main = main.position.x
		previous_far = far.position.x
	for backwards in [false, true]:
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.shift_pressed = backwards
		tab.pressed = true
		scope.handle_input(tab)
		_expect(overlay.is_ancestor_of(root.gui_get_focus_owner()), "Tab focus trapped in scene")
	for direction in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		var button := InputEventJoypadButton.new()
		button.button_index = direction
		button.pressed = true
		scope.handle_input(button)
		_expect(overlay.is_ancestor_of(root.gui_get_focus_owner()), "controller focus trapped in scene")
	await create_timer(0.1).timeout
	_expect(overlay.elapsed > 0.0, "motion advances without pointer input")
	overlay.advance_presentation(0.8)
	_expect(overlay.phase == "bus_approach", "bus approach phase")
	overlay.advance_presentation(1.2)
	_expect(overlay.phase == "dropoff", "visible passenger dropoff phase")
	overlay.advance_presentation(3.0)
	_expect(overlay.phase == "approach_door", "passenger walks to bar door after bus leaves")
	overlay.advance_presentation(6.95 - overlay.elapsed)
	_expect(overlay.phase == "enter_bar" and overlay.snapshot()["choreography"]["player_alpha"] == 1.0 and overlay.snapshot()["entry_progress"] > 0.0, "passenger visibly enters actual doorway before closure")
	overlay.advance_presentation(7.575 - overlay.elapsed)
	_expect(overlay.phase == "destination_close" and overlay.snapshot()["choreography"]["player_visible"], "actual door closes over still-opaque passenger")
	overlay.advance_presentation(overlay.DURATION_SECONDS - overlay.elapsed)
	_expect(overlay.phase == "receipt" and overlay.active and not overlay.is_processing(), "bounded animation queues completion outside its callback")
	overlay.skip_to_receipt()
	await process_frame
	_expect(not overlay.active and completions == 1, "natural finish automatically completes without Continue")
	overlay.acknowledge()
	overlay.acknowledge()
	_expect(completions == 1 and not overlay.active, "completion exactly once")
	for seconds in [0.0, 0.8, 1.6, 2.15, 3.6, 4.20, 5.35, 6.15, 6.4, 6.95, 7.575, 7.95, 8.0]:
		overlay.present(receipt)
		overlay.advance_presentation(seconds)
		overlay.skip_to_receipt()
		overlay.skip_to_receipt()
		_expect(overlay.phase == "receipt" and overlay.active and not overlay.snapshot()["narration_visible"] and overlay.snapshot()["caption"].is_empty(), "skip retains readable receipt without narration at %s" % seconds)
		overlay.acknowledge()
	overlay.present(receipt, true, true, 1.5)
	_expect(overlay.phase == "receipt" and bool(overlay.snapshot()["static"]), "reduced motion and large text static summary")
	overlay.cancel()
	_expect(not overlay.active and not overlay.visible and not overlay.is_processing(), "interruption releases node")
	overlay.present(receipt, false, false, 1.0, true)
	_expect(overlay.phase == "receipt", "loaded receipt does not replay motion")
	overlay.acknowledge()
	var custom_appearance := Appearance.from_character({"id":"created_test_character", "model":{"skin_color":"#785240", "hair_color":"#201831", "jacket_color":"#315177", "accent_color":"#21d7c5", "silhouette":"cap", "scale":1.12}}, [{"id":"cheap_sunglasses", "environment_prop":"sunglasses"}])
	var frozen_appearance := var_to_bytes(custom_appearance)
	overlay.present(receipt, false, false, 1.0, false, custom_appearance)
	overlay.advance_presentation(2.15)
	var avatar: Control = overlay.get("_avatar_view")
	_expect(avatar.snapshot()["character_id"] == "created_test_character" and avatar.snapshot()["model"] == custom_appearance["model"] and avatar.snapshot()["accessories"] == custom_appearance["accessories"], "travel consumes the supplied canonical character and equipment snapshot")
	_expect(avatar.visible and avatar.pose_snapshot()["pose"] == "walk", "canonical character animates during dropoff")
	var frozen_bus_angle: float = overlay.snapshot()["wheel_angle"]
	overlay.advance_presentation(0.2)
	_expect(is_equal_approx(overlay.snapshot()["wheel_angle"], frozen_bus_angle), "parked bus wheels stay still while passenger exits")
	overlay.advance_presentation(1.45)
	_expect(not is_equal_approx(overlay.snapshot()["wheel_angle"], frozen_bus_angle), "departing bus rotates its actual wheel sprite layer")
	_expect(var_to_bytes(custom_appearance) == frozen_appearance, "travel view never mutates the supplied character")
	overlay.skip_to_receipt()
	overlay.acknowledge()
	var non_bus := receipt.duplicate(true)
	non_bus["travel_method_kind"] = "taxi"
	non_bus["travel_method_label"] = "Taxi ride"
	overlay.present(non_bus)
	_expect(overlay.phase == "taxi_approach" and not bool(overlay.snapshot()["static"]) and overlay.snapshot()["mode"] == "taxi", "taxi journey selects its own shared-structure vehicle scene")
	overlay.skip_to_receipt()
	overlay.acknowledge()
	overlay.force_missing_art_for_test = true
	overlay.present(receipt)
	_expect(overlay.phase == "receipt" and overlay.active, "missing assets use summary immediately")
	overlay.acknowledge()
	overlay.force_missing_art_for_test = false
	var unknown := receipt.duplicate(true)
	unknown["presentation_key"] = "future_missing_content"
	overlay.present(unknown)
	_expect(overlay.phase == "receipt", "unknown presentation uses summary")
	overlay.acknowledge()
	_expect(var_to_bytes(receipt) == frozen, "presentation never mutates frozen receipt")
	var long_receipt := receipt.duplicate(true)
	long_receipt["receipt_text"] = "A readable journey detail. ".repeat(160)
	overlay.present(long_receipt, true, true, 1.5)
	await process_frame
	await process_frame
	var scroll: ScrollContainer = overlay.get("_summary_scroll")
	_expect(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "long large-text receipt scrolls inside viewport")
	overlay.acknowledge()
	await _check_auto_completion_lifecycle(overlay, receipt)
	overlay.free()
	print(JSON.stringify({"suite":"travel_cinematic_overlay", "checks":checks, "passed":failures.is_empty(), "failures":failures}))
	quit(0 if failures.is_empty() else 1)


func _check_auto_completion_lifecycle(overlay: Control, receipt: Dictionary) -> void:
	# Pure presentation coverage for every shared profile, not invented routes.
	for destination in Catalog.EXTERIOR_IDS:
		for mode in Catalog.MODES:
			var variant := receipt.duplicate(true)
			variant["presentation_key"] = Catalog.STANDARD_KEY
			variant["effective_destination_archetype_id"] = destination
			variant["travel_method_kind"] = mode
			var before := completions
			overlay.present(variant)
			overlay.advance_presentation(7.99)
			_expect(overlay.active and completions == before, destination + "/" + mode + " cannot finish early")
			overlay.advance_presentation(0.01)
			overlay.skip_to_receipt()
			_expect(overlay.active and completions == before, "completion never emits inside advance/Skip")
			await process_frame
			_expect(not overlay.active and completions == before + 1, destination + "/" + mode + " finishes automatically exactly once")
			overlay.acknowledge()
			overlay.skip_to_receipt()
			await process_frame
			_expect(completions == before + 1, "late duplicate Skip/Continue cannot repeat completion")
	var before := completions
	overlay.present(receipt)
	overlay.skip_to_receipt()
	overlay.cancel()
	await process_frame
	_expect(not overlay.active and completions == before, "cancel invalidates queued auto-completion without acknowledgment")
	overlay.present(receipt)
	overlay.skip_to_receipt()
	overlay.present(receipt)
	await process_frame
	_expect(overlay.active and overlay.phase != "receipt" and completions == before, "same-ID replacement cannot be completed by the old deferred callback")
	overlay.skip_to_receipt()
	overlay.present(receipt, false, false, 1.0, true)
	await process_frame
	_expect(overlay.active and overlay.phase == "receipt" and completions == before, "same-ID reload receipt stays readable despite old queued completion")
	overlay.acknowledge()
	_expect(completions == before + 1, "reload still acknowledges once manually")
	for fallback in ["reduced", "missing", "incident", "unknown", "legacy_summary", "reload"]:
		var static_receipt := receipt.duplicate(true)
		if fallback == "incident": static_receipt["route_risk"] = {"triggered":true, "message":"Do not hide this consequence."}
		if fallback == "unknown": static_receipt["presentation_key"] = "unknown"
		if fallback == "legacy_summary": static_receipt = {"journey_id":"old_summary", "receipt_text":"Saved outcome."}
		overlay.force_missing_art_for_test = fallback == "missing"
		before = completions
		overlay.present(static_receipt, fallback == "reduced", false, 1.0, fallback == "reload")
		overlay.advance_presentation(99.0)
		await process_frame
		await process_frame
		_expect(overlay.active and overlay.phase == "receipt" and overlay.snapshot()["static"] and completions == before, fallback + " remains manually readable")
		overlay.acknowledge()
		_expect(completions == before + 1, fallback + " manual acknowledgment remains exactly once")
	overlay.force_missing_art_for_test = false
	for action in ["ui_accept", "ui_cancel"]:
		before = completions
		overlay.present(receipt)
		var press := InputEventAction.new()
		press.action = action
		press.pressed = true
		overlay._input(press)
		_expect(overlay.active and completions == before, action + " Skip keeps input handler alive until deferred completion")
		await process_frame
		_expect(not overlay.active and completions == before + 1, action + " automatically enters without a second key press")
	var removed := Overlay.new()
	root.add_child(removed)
	removed.completed.connect(func(_id: String) -> void: completions += 1)
	before = completions
	removed.present(receipt)
	removed.skip_to_receipt()
	root.remove_child(removed)
	await process_frame
	_expect(completions == before, "detached owner cannot emit queued completion")
	removed.free()
	var freed := Overlay.new()
	root.add_child(freed)
	freed.present(receipt)
	freed.skip_to_receipt()
	freed.free()
	await process_frame
	_expect(completions == before, "freed owner safely drops its queued callback")
