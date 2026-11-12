extends "res://scripts/tests/standard_travel_integration_check.gd"

# Bounded generated-route probe. A late clock is an explicit synthetic setup;
# the normal menu chooses its actual route/mode and settles its own risk/RNG.
var attempts: Array = []
func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	root.add_child(app)
	app.continuous_environment_clock_enabled = false
	app._build_travel_cinematic_overlay()
	var accepted := false
	for index in [1]:
		app._cancel_travel_presentation()
		app.pending_autosave = false
		var seed_text := "BACK-ALLEY-NIGHT-" + str(index)
		if not app.start_foundation_run(seed_text, {"modifiers":{"home_archetype_id":"apartment"}}, false): continue
		app.run_state.game_clock_minutes = 1300
		# Current generated start is an actual public venue. Do not edit graph,
		# destinations, fares, methods, risk chance or RNG to force a result.
		var target := "back_alley"
		var choice: Dictionary = app._travel_choice(target)
		if not bool(choice.get("enabled", false)):
			attempts.append({"seed":seed_text,"enabled":false,"choices":app._travel_choice_view_list()})
			continue
		var before := _state(app.run_state)
		var result := _menu_travel(target, true)
		var receipt: Dictionary = app.run_state.travel_journey_receipt.duplicate(true)
		attempts.append({"seed":seed_text,"enabled":true,"ok":result.get("ok"),"mode":receipt.get("travel_method_kind"),"risk":receipt.get("route_risk",{}),"choice":choice})
		if not result.get("ok",false): continue
		if not bool(receipt.get("route_risk",{}).get("triggered",false)):
			app._cancel_travel_presentation()
			continue
		var settled := _state(app.run_state)
		for frame in range(4): await process_frame
		_expect(not app.travel_presentation_active and not app.travel_cinematic_overlay.active, "fresh real incident menu trip automatically reveals the installed room")
		var feedback: Dictionary = app._environment_result_feedback_view()
		var risk: Dictionary = receipt["route_risk"]
		_expect(feedback.get("visible",false) and feedback.get("dismissible",false), "destination incident Result panel stays visible and dismissible")
		_expect(str(feedback.get("text","")).contains(str(risk["label"])) and str(feedback.get("text","")).contains(str(risk["message"])), "persistent destination Result panel retains full incident label and narrative")
		_expect(str(feedback.get("text","")).contains(str(absi(int(risk["bankroll_delta"])))) or int(risk["bankroll_delta"]) == 0, "incident cash effect stays readable")
		_expect(_state(app.run_state) == settled, "fallback presentation never repeats settlement or consumes cash clock or RNG")
		_expect(not app.run_state.travel_journey_receipt.get("receipt_pending",true), "actual receipt acknowledged once")
		attempts.append({"accepted_fixture":true,"seed":seed_text,"before":before,"settled":settled,"feedback":feedback,"receipt":receipt})
		_expect(app.environment_result_panel.is_visible_in_tree() and app.environment_result_body_label.text.contains(str(risk["message"])), "rendered destination Result panel contains the incident narrative")
		if DisplayServer.get_name() != "headless":
			# Ordinary generated-start advice can cover the persistent Result panel.
			# Exercise its real Skip tip button before verifying readable pixels.
			for tip in range(8):
				if not app.coach_overlay.panel.is_visible_in_tree(): break
				if not app.coach_overlay.ok_button.is_visible_in_tree(): break
				app.coach_overlay.ok_button.pressed.emit()
				await process_frame
			_expect(not app.coach_overlay.panel.is_visible_in_tree(), "ordinary Skip tip exposes the persistent incident Result panel")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("BTH_QA_EVIDENCE_DIR").path_join("incident-result.png"))
		accepted = true
		break
	_expect(accepted, "bounded search finds a real triggered incident without risk override")
	var report := {"suite":"back_alley_incident_host", "passed":failures.is_empty(),"checks":checks,"failures":failures,"fidelity":"normal Travel-menu transaction from generated late-clock synthetic QA state; no route/mode/risk/RNG overrides or personal save","attempts":attempts}
	var file := FileAccess.open(OS.get_environment("BTH_QA_EVIDENCE_DIR").path_join("incident-host.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t")); file.close()
	print(JSON.stringify(report))
	app._cancel_travel_presentation()
	app.pending_autosave = false
	app.save_service.wait_for_async_save()
	app.free()
	quit(0 if failures.is_empty() else 1)
