extends SceneTree

# Synthetic committed receipts and actual production overlay. No player save,
# travel transaction, route override or consequence application occurs here.
const Overlay := preload("res://scripts/ui/travel_cinematic_overlay.gd")
const Catalog := preload("res://scripts/ui/travel_presentation_catalog.gd")
const Appearance := preload("res://scripts/ui/character_appearance_snapshot.gd")
var failures: Array[String] = []
var checks := 0
var completions := 0
var facts: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _receipt(mode: String, incident: bool = false) -> Dictionary:
	return {"journey_id":"alley-" + mode, "presentation_key":"static_receipt" if incident else Catalog.STANDARD_KEY,
		"origin_label":"Motel", "destination_label":"Back Alley", "effective_destination_archetype_id":"back_alley",
		"travel_method_kind":mode, "travel_method_label":mode, "departed_game_clock_minutes":1300,
		"base_minutes":24, "quoted_departure_fare":12, "receipt_text":"Traveled to Back Alley. Route cost 12, Shortcut Shakedown -8, heat +4.",
		"route_risk":{"triggered":incident, "id":"travel_shakedown", "label":"Shortcut Shakedown", "bankroll_delta":-8, "suspicion_delta":4, "message":"Someone at the shortcut takes eight dollars."}}

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var overlay := Overlay.new()
	root.add_child(overlay)
	overlay.completed.connect(func(_id: String) -> void: completions += 1)
	var receipt := _receipt("night_cab", true)
	var frozen := var_to_bytes(receipt)
	overlay.present(receipt)
	_expect(overlay.phase == "receipt" and overlay.snapshot()["static"], "incident fallback retains truthful static classification")
	await process_frame
	await process_frame
	_expect(not overlay.active and completions == 1, "fresh fallback automatically reveals destination once instead of freezing")
	overlay.acknowledge()
	_expect(completions == 1 and var_to_bytes(receipt) == frozen, "fallback completion never repeats or mutates committed incident")
	for recovered in [false, true]:
		overlay.present(receipt, not recovered, false, 1.5, recovered)
		await process_frame
		_expect(overlay.active and overlay.phase == "receipt" and overlay.get("_summary_scroll").visible and overlay.get("_continue").visible, "reduced motion or recovered summary stays readable until Continue")
		_expect(overlay.get("_summary").text == receipt["receipt_text"], "manual summary retains all committed consequences")
		overlay.acknowledge()
	var before := completions
	overlay.present(receipt)
	overlay.cancel()
	overlay.present(_receipt("walk"))
	overlay.set_process(false)
	await process_frame
	_expect(overlay.active and overlay.phase != "receipt" and completions == before, "stale fallback completion cannot dismiss a replacement journey")
	overlay.cancel()
	var contract := Catalog.exterior_contract("back_alley")
	for invalid in [null, "bad", [], [0.7, 0.6, 0.1], [0.7, 0.6, -0.1, 0.1], [0.7, 0.6, INF, 0.1], [0.7, 0.6, 0.5, 0.1]]:
		var bad := contract.duplicate(true)
		bad["passage_clearance_rect_uv"] = invalid
		_expect(Catalog.validated_exterior_contract(bad).is_empty(), "malformed passage clearance fails closed: " + str(invalid))
	var appearance := Appearance.from_character({"model":{"scale":1.25, "silhouette":"cap"}})
	for mode in Catalog.MODES:
		var profile := Catalog.profile(_receipt(mode))
		overlay.present(_receipt(mode), false, false, 1.0, false, appearance)
		var initial := overlay.snapshot()
		overlay.set_process(false)
		var clear := true
		var continuous := true
		var previous_scale := 1.0
		var minimum_head_y := 1.0
		# Bound the entire canonical Control at maximum model scale, including cap
		# and bob margin. This is stricter than just fitting an idle head center.
		for index in range(801):
			var pose := overlay.choreography_snapshot(float(index) / 100.0)
			var foot: Vector2 = pose["player_position_uv"]
			var scale_value := float(pose["player_scale"])
			continuous = continuous and absf(scale_value - previous_scale) < 0.015
			previous_scale = scale_value
			if foot.y <= float(profile["motion"]["destination_anchor_uv"].y):
				var head_y := foot.y - float(profile["avatar_height_uv"]) * scale_value * 120.0 / 107.0 * 1.08
				minimum_head_y = minf(minimum_head_y, head_y)
				clear = clear and head_y >= 0.630
		_expect(clear, mode + " maximum-size capped player clears painted alley overhang throughout entry")
		_expect(continuous, mode + " passage depth remains continuous without a size snap")
		overlay.advance_presentation(6.95)
		_expect(overlay.snapshot()["avatar_pose"]["pose"] == "walk_away" and overlay.get("_avatar_view").modulate.a == 1.0, mode + " recedes physically without disappearing or altering identity")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("BTH_QA_EVIDENCE_DIR").path_join("alley-" + mode + ".png"))
		facts.append({"mode":mode, "minimum_head_y_uv":minimum_head_y, "far_scale":previous_scale, "motion":profile["motion"], "has_art":initial.get("has_art",false)})
		overlay.cancel()
	overlay.free()
	var report := {"suite":"back_alley_cinematic_regression", "passed":failures.is_empty(), "checks":checks, "failures":failures, "fidelity":"synthetic committed receipts; production overlay and timeline; no player save or route transaction", "facts":facts}
	var file := FileAccess.open(OS.get_environment("BTH_QA_EVIDENCE_DIR").path_join("back-alley-regression.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report, "\t")); file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
