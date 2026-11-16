extends SceneTree
const Main = preload("res://scenes/main.tscn")
var app
var checks = 0
var failures = []
var facts = {"actions": [], "observations": []}
var args = {}
var matched = false
var saved = false

func _initialize():
 if OS.get_cmdline_user_args() == PackedStringArray(["--syntax-only"]):
  print("CREW_NATIVE_SYNTAX_PASS"); quit(0); return
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
 var objects = []
 for o in app.current_spatial_interaction_snapshot().get("objects", []): objects.append({"id": o.get("object_id"), "label": o.get("label"), "enabled": o.get("enabled"), "summary": o.get("choice_summary")})
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
func go():
 var tokens = OS.get_cmdline_user_args()
 if tokens.size() % 2 != 0: failures.append("explicit native arguments required"); return await done()
 for i in range(0, tokens.size(), 2): args[tokens[i]] = tokens[i+1]
 if not check(args.get("--autosave-slot", "") == "CREW-FRESH-CJ2-261116" and args.get("--mode", "") in ["inspect", "wait", "interact", "respond"] and not args.get("--evidence-output", "").is_empty(), "exact authorized native campaign and bounded mode"): return await done()
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
 var subset = {}
 for key in expected.keys(): subset[key] = facts.immediate_loaded.get(key)
 matched = check(wire(subset) == wire(expected), "immediate loaded public state matches previous actual saved result before any forward action")
 if not matched: return await done()
 await frames(7)
 if not check(app.run_state.validate_room_action_authority().get("ok", false) and not app.run_state.narrative_flags.has("crew_private_authority_error"), "continued room and private authority valid without regeneration"): return await done()
 observe("qualified native Continue")
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
  check(app.run_state.validate_room_action_authority().get("ok", false), "final active room authority retained")
  if matched and failures.is_empty():
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
