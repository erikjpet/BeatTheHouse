extends SceneTree
const Main = preload("res://scenes/main.tscn")
var app
var checks = 0
var failures = []
var facts = {"actions": [], "observations": [], "manual_save_attempted": false}
var args = {}
var matched = false
var saved = false

func _initialize():
 if OS.get_cmdline_user_args() == PackedStringArray(["--syntax-only"]):
  print("CREW_NATIVE_SYNTAX_PASS"); quit(0); return
 if OS.get_cmdline_user_args() == PackedStringArray(["--control-only"]):
  call_deferred("control_qualification"); return
 call_deferred("go")
func frames(n: int):
 for i in range(n): await process_frame
func check(ok: bool, label: String):
 checks += 1
 if not ok: failures.append(label)
 return ok
func wire(v): return JSON.parse_string(JSON.stringify(v))
func button_for(node: Node, id: String):
 if node is Button and node.get_meta("choice_id", "") == id and not node.is_queued_for_deletion(): return node
 for child in node.get_children():
  var found = button_for(child, id)
  if found != null: return found
 return null
func public_state():
 var r = app.run_state
 var jobs = []
 for job in r.crew_jobs.values(): jobs.append(r._crew_job_public_projection(job))
 jobs.sort_custom(func(a,b): return str(a.get("id", "")) < str(b.get("id", "")))
 var debts = r.debt.duplicate(true)
 debts.sort_custom(func(a,b): return str(a.get("id", "")) < str(b.get("id", "")))
 return {"cash": r.bankroll, "clock": r.game_clock_minutes, "node": r.current_world_node_id(), "environment": r.current_environment.get("display_name", ""), "archetype": r.current_environment.get("archetype_id", ""), "layer": r.current_environment.get("current_layer_id", ""), "standing": r.crew_reputation(), "duties": r.crew_delivery_obligation_count(), "debt": debts, "delivery": r.delivery_snapshot(), "jobs": jobs, "crew_present": r.crew_present_member_ids(), "knuckles": r.crew_recruitment_public_state("crew_knuckles"), "rng": str(r.rng_state), "action_index": r.crew_action_index(), "chips": r.grand_casino_chips, "heat": r.suspicion_level()}
func offered(id: String):
 for o in app.current_spatial_interaction_snapshot().get("objects", []):
  if o.get("object_id", "") == id and o.get("enabled", false): return true
 return false
func observe(label: String):
 var contacts = []
 for o in app.current_spatial_interaction_snapshot().get("objects", []):
  if o.get("object_id", "") in ["crew::package_handoff", "delivery:handoff:back_alley"] or o.get("delivery_contact", false): contacts.append(o)
 facts.handoff_public_descriptors = contacts
 facts.delivery_projection = {"mounted_owner": app.run_state.world_sequence_mounted_owner_for_channel("delivery_handoff", "back_alley"), "presentation_owner": app.run_state.delivery_world_sequence_owner_for_presentation("back_alley")}
 var objects = []
 for o in app.current_spatial_interaction_snapshot().get("objects", []): objects.append({"id": o.get("object_id"), "label": o.get("label"), "enabled": o.get("enabled"), "visible": o.get("visible"), "interactive": o.get("interactive"), "delivery_contact": o.get("delivery_contact"), "object_type": o.get("object_type"), "source_id": o.get("source_id"), "confirm_action_id": o.get("confirm_action_id"), "summary": o.get("choice_summary")})
 var choices = []
 for choice in app.talk_dock.option.get("choices", []):
  var actual_button = button_for(app.talk_dock, str(choice.get("id", "")))
  choices.append({"id": choice.get("id"), "label": choice.get("label"), "enabled": choice.get("enabled"), "disabled_reason": choice.get("disabled_reason"), "button_present": actual_button != null, "button_disabled": actual_button.disabled if actual_button != null else true, "button_visible": actual_button.is_visible_in_tree() if actual_button != null else false})
 facts.observations.append({"label": label, "state": public_state(), "objects": objects, "talk": app.talk_dock.current_snapshot(), "talk_choices": choices, "popup": app.current_event_choice_popup_snapshot(), "blocking_modal": app._blocking_modal_message()})
func actual_response(eid: String, cid: String):
 var panel = app.event_choice_popup_choices_list
 var talk = app.talk_dock.current_snapshot()
 if talk.get("visible", false) and talk.get("event_id", "") == eid: panel = app.talk_dock
 var b = button_for(panel, cid)
 if b == null or b.disabled or not b.is_visible_in_tree() or b.get_meta("event_id", "") != eid: return false
 var stages = [b.text]
 b.button_down.emit(); b.pressed.emit(); await frames(7)
 for i in range(2):
  b = button_for(panel, cid)
  if b == null or b.disabled or not b.is_visible_in_tree() or not b.text.begins_with("Confirm"): break
  stages.append(b.text); b.button_down.emit(); b.pressed.emit(); await frames(7)
 facts.actions.append({"event": eid, "choice": cid, "stages": stages})
 return true
func accept_displayed_package():
 var talk = app.talk_dock.current_snapshot()
 if not (talk.get("visible", false) and talk.get("event_id", "") == "crew_favor_delivery"):
  if not offered("event:crew_favor_delivery"): return false
  if not check(app.focus_interactable_object("event:crew_favor_delivery") and app.activate_interactable_object("event:crew_favor_delivery"), "actual offered Crew request opens"): return false
  await frames(5)
 var before = public_state()
 observe("actual package request before confirmation")
 if not await actual_response("crew_favor_delivery", "run_package"): return false
 var popup = app.current_event_choice_popup_snapshot()
 if not app.run_state.delivery_has_active_run() and popup.get("visible", false) and popup.get("event_id", "") == "crew_favor_delivery":
  await actual_response("crew_favor_delivery", "run_package")
 check(app.run_state.delivery_has_active_run(), "normal displayed confirmation starts one package")
 if app.run_state.delivery_has_active_run():
  check(app.run_state.bankroll == int(before.cash) and app.run_state.crew_delivery_obligation_count() == int(before.duties), "package acceptance defers cash reward and duty credit")
  check(wire(app.run_state.debt) == wire(before.debt), "actual debt array unchanged by package acceptance")
 return app.run_state.delivery_has_active_run()
func inspect_concurrent_board():
 if not app.run_state.delivery_has_active_run() or not offered("event:crew_job_board"): return
 if not check(app.focus_interactable_object("event:crew_job_board") and app.activate_interactable_object("event:crew_job_board"), "actual enabled Job Board opens during active route"): return
 await frames(5)
 facts.concurrent_board = app.current_event_choice_popup_snapshot()
 var b = button_for(app.event_choice_popup_choices_list, "accept_knuckles_friendly_collection")
 facts.collection_actual_button = {"present": b != null, "visible": b.is_visible_in_tree() if b != null else false, "disabled": b.disabled if b != null else true, "text": b.text if b != null else ""}
 # Capture availability first. Do not accept a second job as an adapter test.

func visible_buttons(node: Node, meta_key: String, value: String) -> Array:
 var found = []
 if node is Button and node.is_visible_in_tree() and not node.is_queued_for_deletion() and str(node.get_meta(meta_key, "")) == value: found.append(node)
 for child in node.get_children(): found.append_array(visible_buttons(child, meta_key, value))
 return found
func press_visible_button(b) -> bool:
 if b == null or not is_instance_valid(b) or not b is Button or b.disabled or not b.is_visible_in_tree() or b.is_queued_for_deletion(): return false
 b.button_down.emit(); b.button_up.emit(); b.pressed.emit()
 return true
func route_snapshot_ok(d: Dictionary) -> bool:
 if d.get("status", "") != "active" or d.get("mode", "") != "package" or d.get("job_id", "") != "crew_favor_delivery:0001" or not d.get("carrying_contraband", false) or d.get("physical", {}).get("cargo_state", "") != "carried": return false
 for t in d.get("targets", []):
  if t.get("node_id", "") == "back_alley" and t.get("status", "") == "pending": return true
 return false
func handoff_candidates(objects: Array, d: Dictionary, node: String, arrival: Dictionary) -> Array:
 if not route_snapshot_ok(d) or node != "back_alley" or not arrival.get("available", false) or arrival.get("node_id", "") != node: return []
 var result = []
 for o in objects:
  var id = str(o.get("object_id", ""))
  var owned_contact = id in ["crew::package_handoff", "delivery:handoff:back_alley"] or (o.get("delivery_handoff_direct", false) and o.get("delivery_handoff_node_id", "") == node)
  if owned_contact and o.get("enabled", false) and o.get("visible", false) and o.get("interactive", false) and o.get("delivery_contact", false): result.append(o)
 return result
func map_confirmation_ok(snapshot: Dictionary, b) -> bool:
 return snapshot.get("world_map_overlay_visible", false) and snapshot.get("selected_world_map_node_id", "") == "back_alley" and snapshot.get("world_map_confirm_enabled", false) and b != null and b is Button and b.is_visible_in_tree() and not b.disabled
func arrival_ack_button_ok(s: Dictionary, journey: String, b) -> bool:
 return s.get("active", false) and s.get("phase", "") == "receipt" and not journey.is_empty() and s.get("journey_id", "") == journey and b != null and b is Button and b.text == s.get("continue_text", "") and not b.text.is_empty() and b.is_visible_in_tree() and not b.disabled
func travel_back_alley():
 if not check(route_snapshot_ok(app.run_state.delivery_snapshot()), "travel retains the exact carried Rook package and pending target"): return
 facts.before_travel = public_state()
 if app.run_state.current_world_node_id() == "back_alley": facts.stop_reason = "Already at the target; no second trip attempted"; return
 var leaves = []
 for o in app.current_spatial_interaction_snapshot().get("objects", []):
  if o.get("object_id", "") == "travel:leave" and o.get("enabled", false) and o.get("visible", false) and o.get("interactive", false): leaves.append(o)
 if leaves.size() != 1: facts.stop_reason = "Normal displayed Leave is unavailable or ambiguous"; return
 if not check(app.focus_interactable_object("travel:leave") and app.activate_interactable_object("travel:leave"), "actual enabled Leave opens Map"): return
 await frames(5)
 facts.map_opened = app.current_screen_snapshot()
 if not check(facts.map_opened.get("world_map_overlay_visible", false), "actual Map is visible before node selection"): return
 var buttons = visible_buttons(app.world_map_overlay, "node_id", "back_alley")
 if buttons.size() != 1 or buttons[0].disabled: facts.stop_reason = "Back Alley is absent, ambiguous or disabled on the actual Map"; return
 if not check(press_visible_button(buttons[0]), "actual visible Back Alley node pressed once"): return
 facts.actions.append({"map_node": "back_alley"}); await frames(5)
 facts.map_selected = app.current_screen_snapshot()
 var b = app.world_map_confirm_button
 facts.travel_button = {"text": b.text if b != null else "", "visible": b.is_visible_in_tree() if b != null else false, "disabled": b.disabled if b != null else true}
 if not map_confirmation_ok(facts.map_selected, b): facts.stop_reason = "Displayed Back Alley route cannot currently be confirmed"; return
 if not check(press_visible_button(b), "actual selected-map Travel pressed once"): return
 facts.actions.append({"travel_button": facts.travel_button, "selected_node": "back_alley"})
 var deadline_ms = Time.get_ticks_msec() + 30000
 var continued = false
 while (app.travel_transition_active or app.travel_presentation_active) and Time.get_ticks_msec() < deadline_ms:
  if app.travel_presentation_active and not continued and app.travel_cinematic_overlay != null:
   var presentation = app.current_travel_presentation_snapshot()
   var continue_text = str(presentation.get("continue_text", ""))
   var continue_buttons = text_buttons(app.travel_cinematic_overlay, continue_text)
   if continue_buttons.size() == 1 and arrival_ack_button_ok(presentation, str(app.run_state.travel_journey_receipt.get("journey_id", "")), continue_buttons[0]) and press_visible_button(continue_buttons[0]):
    facts.actions.append({"arrival_button": continue_text, "journey_id": presentation.get("journey_id", "")}); continued = true
  await create_timer(0.1).timeout
 check(not app.travel_transition_active and not app.travel_presentation_active, "normal travel transaction and presentation both settled")
 facts.travel_reached_target = app.run_state.current_world_node_id() == "back_alley"
 if not facts.travel_reached_target: facts.stop_reason = "Normal travel did not reach Back Alley; inspect the actual result before any retry"
 facts.travel_receipt = app.run_state.travel_journey_receipt.duplicate(true)
 facts.arrival = app.run_state.delivery_arrival_interaction()
 facts.delivery_timing = app.run_state.delivery_timing_text()
 observe("after normal Map travel")
func text_buttons(node: Node, text: String) -> Array:
 var result = []
 if node is Button and node.text == text and node.is_visible_in_tree() and not node.disabled and not node.is_queued_for_deletion(): result.append(node)
 for child in node.get_children(): result.append_array(text_buttons(child, text))
 return result
func handoff_success(d: Dictionary) -> bool:
 return d.get("status", "") == "resolved" and not d.get("carrying_contraband", true) and d.get("resolution", {}).get("outcome", "") == "success" and d.get("resolution", {}).get("reason", "") == "delivered"
func handoff_back_alley():
 if not check(route_snapshot_ok(app.run_state.delivery_snapshot()) and app.run_state.current_world_node_id() == "back_alley", "handoff requires exact carried package at its real Back Alley target"): return
 facts.before_handoff = public_state()
 var arrival = app.run_state.delivery_arrival_interaction()
 facts.handoff_availability = arrival; facts.delivery_timing = app.run_state.delivery_timing_text()
 var candidates = handoff_candidates(app.current_spatial_interaction_snapshot().get("objects", []), app.run_state.delivery_snapshot(), app.run_state.current_world_node_id(), arrival)
 facts.handoff_candidates = candidates
 if candidates.size() != 1: facts.stop_reason = "No unique currently available displayed package handoff"; return
 var id = str(candidates[0].get("object_id", ""))
 facts.handoff_activation_returned = app.focus_interactable_object(id) and app.activate_interactable_object(id)
 facts.actions.append({"handoff_contact": id, "activated": facts.handoff_activation_returned}); await frames(8)
 facts.handoff_completed = not app.run_state.delivery_has_active_run() and handoff_success(app.run_state.delivery_snapshot())
 if not facts.handoff_completed: facts.stop_reason = "Displayed handoff did not complete the package; no retry attempted"
 observe("after one displayed package handoff")
func wait_recipient():
 if not check(route_snapshot_ok(app.run_state.delivery_snapshot()) and app.run_state.current_world_node_id() == "back_alley", "recipient wait requires exact carried package at the real target"): return
 var started = Time.get_ticks_msec(); var max_ms = int(args.get("--max-wait-seconds", "60")) * 1000
 facts.recipient_before = app.run_state.delivery_arrival_interaction(); facts.delivery_timing = app.run_state.delivery_timing_text()
 facts.recipient_clock_before = app.run_state.game_clock_minutes; facts.recipient_pause_before = app.application_lifecycle_snapshot()
 while Time.get_ticks_msec() - started < max_ms:
  var d = app.run_state.delivery_snapshot(); var a = app.run_state.delivery_arrival_interaction()
  if a.get("available", false): facts.wait_stop = "Recipient became available"; break
  if not route_snapshot_ok(d) or int(d.get("deadline_remaining", 0)) <= 10: facts.wait_stop = "Route changed or deadline is close"; break
  if paused or app.application_lifecycle_snapshot().get("simulation_paused", false): facts.wait_stop = "Application or tree pause prevents normal recipient wait"; break
  if not app._blocking_modal_message().is_empty() or app.current_event_choice_popup_snapshot().get("visible", false): facts.wait_stop = "Normal modal pauses recipient wait"; break
  await create_timer(0.25).timeout
 facts.normal_wait_ms = Time.get_ticks_msec() - started; facts.recipient_after = app.run_state.delivery_arrival_interaction()
 facts.recipient_clock_after = app.run_state.game_clock_minutes; facts.recipient_pause_after = app.application_lifecycle_snapshot()
 observe("ordinary bounded recipient wait")
func control_qualification():
 var panel = Control.new(); root.add_child(panel)
 var target = Button.new(); target.set_meta("node_id", "back_alley"); panel.add_child(target)
 var wrong = Button.new(); wrong.set_meta("node_id", "grand"); panel.add_child(wrong)
 var hidden = Button.new(); hidden.set_meta("node_id", "back_alley"); panel.add_child(hidden); hidden.hide()
 var count = [0]; target.pressed.connect(func(): count[0] += 1)
 await frames(2)
 check(visible_buttons(panel, "node_id", "back_alley") == [target], "Map discovers only exact visible target metadata")
 target.disabled = true; check(not press_visible_button(target) and count[0] == 0, "disabled control emits no press")
 target.disabled = false; target.hide(); check(not press_visible_button(target) and count[0] == 0, "hidden control emits no press")
 target.show(); check(press_visible_button(target) and count[0] == 1, "actual enabled visible control emits exactly one press")
 var s = {"world_map_overlay_visible": true, "selected_world_map_node_id": "back_alley", "world_map_confirm_enabled": true}
 check(map_confirmation_ok(s, target), "actual visible enabled Travel qualifies selected target")
 for key in s.keys():
  var bad = s.duplicate(true); bad[key] = "grand" if key == "selected_world_map_node_id" else false
  check(not map_confirmation_ok(bad, target) and count[0] == 1, "Map mismatch cannot press Travel: " + key)
 target.disabled = true; check(not map_confirmation_ok(s, target), "disabled actual Travel rejects"); target.disabled = false
 target.text = "Continue to Alley"
 var receipt = {"active": true, "phase": "receipt", "journey_id": "fixture-journey", "continue_text": target.text}
 check(arrival_ack_button_ok(receipt, "fixture-journey", target), "actual destination-specific receipt label qualifies")
 for key in ["phase", "journey_id", "continue_text"]:
  var bad = receipt.duplicate(true); bad[key] = "foreign"
  check(not arrival_ack_button_ok(bad, "fixture-journey", target), "arrival phase identity or displayed label mismatch rejects: " + key)
 var d = {"status": "active", "mode": "package", "job_id": "crew_favor_delivery:0001", "carrying_contraband": true, "physical": {"cargo_state": "carried"}, "targets": [{"node_id": "back_alley", "status": "pending"}]}
 var a = {"available": true, "node_id": "back_alley"}
 var o = {"object_id": "crew::package_handoff", "enabled": true, "visible": true, "interactive": true, "delivery_contact": true}
 check(handoff_candidates([o], d, "back_alley", a) == [o], "live owned handoff may activate once")
 for bad in [{}, {"available": false, "node_id": "back_alley"}, {"available": true, "node_id": "grand"}]: check(handoff_candidates([o], d, "back_alley", bad).is_empty(), "missing early or foreign recipient rejects")
 for key in ["status", "mode", "job_id", "carrying_contraband", "physical", "targets"]:
  var bad = d.duplicate(true); bad.erase(key)
  check(handoff_candidates([o], bad, "back_alley", a).is_empty(), "invalid carried route rejects: " + key)
 for key in ["enabled", "visible", "interactive", "delivery_contact"]:
  for value in [false, null]:
   var bad = o.duplicate(true)
   if value == null: bad.erase(key)
   else: bad[key] = value
   check(handoff_candidates([bad], d, "back_alley", a).is_empty(), "missing or false contact presentation rejects: " + key)
 check(handoff_candidates([o], d, "grand", a).is_empty(), "foreign room cannot hand over package")
 check(handoff_candidates([{"object_id": "crew::package_handoff", "enabled": false}], d, "back_alley", a).is_empty(), "disabled contact cannot hand over package")
 check(handoff_candidates([{"object_id": "foreign", "enabled": true}], d, "back_alley", a).is_empty(), "unowned contact cannot hand over package")
 var success = {"status": "resolved", "carrying_contraband": false, "resolution": {"outcome": "success", "reason": "delivered"}}
 check(handoff_success(success), "successful resolved delivery counts as handoff")
 for bad in [{}, {"status": "active", "carrying_contraband": true}, {"status": "resolved", "carrying_contraband": false, "resolution": {"outcome": "failure", "reason": "expired"}}, {"status": "resolved", "carrying_contraband": true, "resolution": {"outcome": "success", "reason": "delivered"}}]:
  check(not handoff_success(bad), "missing active expired or still-carried route is not handoff success")
 panel.queue_free(); await frames(2)
 print("CREW_NATIVE_CONTROL_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "main_instantiated": false, "profile_loaded": false}))
 quit(0 if failures.is_empty() else 1)


func diag_dict(value) -> Dictionary:
 return value if value is Dictionary else {}
func diag_keys(value) -> Array:
 return value.keys() if value is Dictionary else []
func cold_publication_diag(r, token: String) -> Dictionary:
 var env = r.current_environment
 var reg = diag_dict(r.world_sequence_registrations.get(token, {}))
 var entry = diag_dict(diag_dict(env.get("world_sequence_instances", {})).get(token, {}))
 var state = diag_dict(entry.get("state", {})); var primary = diag_dict(env.get("scenario_sequence_state", {}))
 var projection = diag_dict(env.get("scenario_sequence_projection", {})); var semantic = diag_dict(state.get("semantic_state", {})); var cached = diag_dict(projection.get("semantic_state", {}))
 var definition = diag_dict(reg.get("definition", {}))
 var fp = RunState.ScenarioSequenceRuntimeScript.content_fingerprint(definition) if not definition.is_empty() else ""
 return {
  "environment": {"scenario_id": env.get("scenario_id"), "archetype_id": env.get("archetype_id"), "world_node_id": env.get("world_node_id"), "current_layer_id": env.get("current_layer_id"), "ready": env.get("scenario_semantic_ready"), "restore_pending": env.get("scenario_restore_pending_trusted_rebuild"), "restore_contract": env.get("scenario_restore_contract"), "has_primary_state": not primary.is_empty(), "primary_status": primary.get("status"), "primary_phase": primary.get("phase_id"), "has_projection": not projection.is_empty(), "has_renderer": env.has("scenario_render_snapshot"), "has_audit": env.has("scenario_layout_audit"), "cached_scene_keys": diag_keys(cached.get("scene_objects")), "cached_interaction_keys": diag_keys(cached.get("interactions")), "cached_actor_keys": diag_keys(cached.get("actors"))},
  "definition_cache_keys": diag_keys(r.get("_world_sequence_definition_cache")),
  "registration": {"owner": reg.get("owner_token"), "source": reg.get("source"), "instance": reg.get("public_instance_token"), "node": reg.get("node_id"), "lifecycle": reg.get("lifecycle"), "definition_id": definition.get("id"), "definition_fingerprint": reg.get("definition_fingerprint"), "computed_fingerprint": fp, "fingerprint_matches": not definition.is_empty() and fp == reg.get("definition_fingerprint"), "pending_outcome_keys": diag_keys(reg.get("pending_outcomes")), "owner_outcome_result_keys": diag_keys(reg.get("owner_outcome_results"))},
  "instance": {"owner": entry.get("owner_token"), "node": entry.get("node_id"), "lifecycle": entry.get("lifecycle"), "definition_fingerprint": entry.get("definition_fingerprint"), "state_status": state.get("status"), "phase": state.get("phase_id"), "boundary_serial": state.get("boundary_serial"), "creation_owners": semantic.get("creation_owner_namespaces", []), "scene_keys": diag_keys(semantic.get("scene_objects")), "interaction_keys": diag_keys(semantic.get("interactions")), "actor_keys": diag_keys(semantic.get("actors")), "command_receipt_keys": diag_keys(state.get("command_receipts")), "outcome_keys": diag_keys(entry.get("outcome_receipts")), "ack_keys": diag_keys(entry.get("outcome_acknowledgements"))}}

func go():
 var tokens = OS.get_cmdline_user_args()
 if tokens.size() % 2 != 0: failures.append("explicit native arguments required"); return await done()
 for i in range(0, tokens.size(), 2): args[tokens[i]] = tokens[i+1]
 if not check(args.get("--autosave-slot", "") == "CREW-FRESH-CJ2-261116" and args.get("--mode", "") in ["inspect", "wait", "interact", "respond", "travel-back-alley", "handoff-back-alley", "wait-recipient"] and not args.get("--evidence-output", "").is_empty(), "exact authorized native campaign and bounded mode"): return await done()
 var expected_file = FileAccess.open(args.get("--expected-state-file", ""), FileAccess.READ)
 if not check(expected_file != null, "declared previous QA public-state receipt opens"): return await done()
 var expected = JSON.parse_string(expected_file.get_as_text()); expected_file.close()
 if not check(expected is Dictionary and not expected.is_empty(), "previous public state is a nonempty QA dictionary"): return await done()
 app = Main.instantiate(); app.autosave_slot_id = args["--autosave-slot"]; root.add_child(app); await frames(8)
 facts.slot = args["--autosave-slot"]; facts.initial_menu = app.current_start_menu_snapshot()
 facts.slot_before = app.save_service.slot_status(app.autosave_slot_id)
 if not check(facts.slot_before.get("has_loadable", false) and facts.slot_before.get("primary_exists", false) and facts.slot_before.get("primary_loadable", false) and not facts.slot_before.get("primary_corrupt", true), "existing exact slot has a valid primary before Continue"): return await done()
 if not check(app.new_run_button != null and app.new_run_button.is_visible_in_tree() and not app.new_run_button.disabled and app.new_run_button.text == "CONTINUE", "actual CONTINUE offered for exact existing slot; PLAY is forbidden"): return await done()
 app.new_run_button.pressed.emit()
 if not check(app.run_state != null and not app.run_state.is_tutorial_run(), "actual menu CONTINUE loads existing ordinary campaign"): return await done()
 facts.immediate_loaded = public_state()
 facts.immediate_cold_publication = cold_publication_diag(app.run_state, "crew::crew::crew_favor_delivery::crew_favor_delivery:0001")
 var subset = {}
 for key in expected.keys(): subset[key] = facts.immediate_loaded.get(key)
 matched = check(wire(subset) == wire(expected), "immediate loaded public state matches previous actual saved result before any forward action")
 if not matched: return await done()
 await frames(7)
 if not check(app.run_state.validate_room_action_authority().get("ok", false) and not app.run_state.narrative_flags.has("crew_private_authority_error"), "continued room and private authority valid without regeneration"): return await done()
 observe("qualified native Continue")
 facts.after_initial_publication = cold_publication_diag(app.run_state, "crew::crew::crew_favor_delivery::crew_favor_delivery:0001")
 if args["--mode"] == "travel-back-alley": await travel_back_alley()
 if args["--mode"] == "handoff-back-alley": await handoff_back_alley()
 if args["--mode"] == "wait-recipient": await wait_recipient()
 if args["--mode"] == "interact":
  var object_id = str(args.get("--object-id", ""))
  if not check((object_id.begins_with("event:crew_") or object_id.begins_with("event:recruitment_") or object_id.begins_with("environment_layer:")) and offered(object_id), "requested Crew interaction is actually offered and enabled"): return await done()
  if not check(app.focus_interactable_object(object_id) and app.activate_interactable_object(object_id), "normal displayed Crew interaction opens"): return await done()
  facts.actions.append({"object": object_id}); await frames(7)
  observe("actual Crew interaction")
 if args["--mode"] == "respond" or (args["--mode"] == "interact" and not str(args.get("--choice-id", "")).is_empty()):
  var event_id = str(args.get("--event-id", ""))
  if not check(event_id.begins_with("crew_") or event_id.begins_with("recruitment_"), "requested response belongs to actual Crew content"): return await done()
  facts.before_response = public_state()
  if not check(await actual_response(event_id, str(args.get("--choice-id", ""))), "actual enabled displayed Crew response pressed"): return await done()
  observe("after actual Crew response")
 if args["--mode"] == "wait":
  var wait_ms = clampi(int(args.get("--max-wait-seconds", "60")), 1, 90) * 1000
  var started = Time.get_ticks_msec()
  while not app.run_state.delivery_has_active_run() and Time.get_ticks_msec() - started < wait_ms:
   if await accept_displayed_package(): break
   if not failures.is_empty(): break
   if app.current_event_choice_popup_snapshot().get("visible", false): break
   await create_timer(1.0).timeout
  facts.normal_wait_ms = Time.get_ticks_msec() - started
  observe("normal forward request observation")
  await inspect_concurrent_board()
 await done()
func done():
 if app != null and app.run_state != null:
  facts.final = public_state()
  facts.final_run_terminal = app.run_state.is_terminal()
  facts.final_screen = str(app.current_screen)
  facts.final_room_authority = app.run_state.validate_room_action_authority()
  facts.autosave_before_manual = {"completed": app.autosave_completed_generation, "dirty": app.autosave_dirty_generation, "status": app.save_status_message}
  check(facts.final_room_authority.get("ok", false), "final active room authority retained")
  if matched and failures.is_empty():
   facts.manual_save_attempted = true
   app.save_foundation_run(); var save_error = app.save_service.wait_for_async_save()
   facts.final_save = app.save_service.slot_status(app.autosave_slot_id)
   saved = check(save_error == OK and facts.final_save.get("has_loadable", false) and facts.final_save.get("primary_loadable", false), "ordinary Save persists this same continued slot")
 var result = {"checks": checks, "failures": failures, "facts": facts, "native_forward": {"previous_case": args.get("--previous-case", ""), "previous_campaign_sha256": args.get("--previous-campaign-sha256", ""), "prior_state_matched": matched, "save_completed": saved, "closed": true, "completed": failures.is_empty(), "inflight": null, "error": null}}
 if app != null:
  if app.save_service != null: app.save_service.wait_for_async_save()
  app.queue_free(); await frames(4)
 var output_path = args.get("--evidence-output", "")
 if not output_path.is_empty():
  var output = FileAccess.open(output_path, FileAccess.WRITE)
  if output != null: output.store_string(JSON.stringify(result, "  ") + "\n"); output.close()
 print("CREW_NATIVE_FORWARD_RESULT " + JSON.stringify(result))
 quit(0 if failures.is_empty() else 1)
