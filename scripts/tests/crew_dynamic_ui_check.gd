extends SceneTree

# Contract mode is a synthetic, read-only projection check. Other modes require
# complete disposable copies of the captured Crew profiles, supplied externally.
const Main = preload("res://scenes/main.tscn")
const Event = preload("res://scripts/core/event_module.gd")
const Slot = "NEXT-ORDINARY-20261115-O"
var app
var checks = 0
var failures = []
var facts = {}

class ProjectionRun:
 extends RunState
 var rows: Array = []
 var pending: Dictionary = {"payload": {"crew_stake": 20}}
 func crew_heist_table_choices() -> Array: return rows
 func _pending_crew_job(_kind: String, _flag: String) -> Dictionary: return pending

func _initialize(): call_deferred("go")
func frames(n: int):
 for i in range(n): await process_frame
func check(ok: bool, label: String):
 checks += 1
 if not ok: failures.append(label)
 return ok
func wire(v): return JSON.parse_string(JSON.stringify(v))
func signature():
 var r = app.run_state
 var jobs = []
 for job in r.crew_jobs.values(): jobs.append(r._crew_job_public_projection(job))
 return {"cash": r.bankroll, "chips": r.grand_casino_chips, "rng": str(r.rng_state), "duties": r.crew_delivery_obligation_count(), "standing": r.crew_reputation(), "heist": r.crew_heist_snapshot(), "delivery": r.delivery_snapshot(), "jobs": jobs}
func button_for(node: Node, event_id: String, choice_id: String):
 if node is Button and node.get_meta("event_id", "") == event_id and node.get_meta("choice_id", "") == choice_id and not node.is_queued_for_deletion(): return node
 for child in node.get_children():
  var found = button_for(child, event_id, choice_id)
  if found != null: return found
 return null
func open_event(id: String):
 if not check(app.focus_interactable_object("event:" + id) and app.activate_interactable_object("event:" + id), "normal visible " + id + " opens"): return false
 await frames(5)
 return true
func boundary(label: String):
 var before = signature()
 app.save_foundation_run(); app.save_service.wait_for_async_save()
 if not check(app.load_foundation_run(), label + " official Continue"): return false
 await frames(7)
 check(wire(signature()) == wire(before), label + " exact public wallet RNG duties jobs heist and delivery persist")
 check(not app.run_state.narrative_flags.has("crew_private_authority_error"), label + " intact private companions")
 check(app.run_state.validate_room_action_authority().get("ok", false), label + " active room authority valid")
 return true
func contract():
 var r = ProjectionRun.new()
 r.rows = [{"id":"authored", "disabled":true, "disabled_reason":"Authored reason", "text":"Other text"}, {"id":"text", "disabled":true, "text":"No audit on the books this season."}, {"id":"explicit", "enabled":false}, {"id":"ordinary"}, {"id":"available", "disabled":false, "enabled":true, "disabled_reason":"Old reason"}]
 var before = JSON.stringify(r.rows)
 var event = Event.new(); event.setup({"id":"crew_planning_table"})
 var views = event.choice_views(r)
 check(views.size() == 5, "dynamic provider response identities retained")
 check(not views[0].enabled and views[0].disabled_reason == "Authored reason", "authored disabled reason retained")
 check(not views[1].enabled and views[1].disabled_reason == r.rows[1].text, "disabled provider text becomes reason")
 check(not views[2].enabled and not views[2].disabled_reason.is_empty(), "explicit enabled false remains unavailable with fallback")
 check(views[3].enabled and views[4].enabled and views[4].disabled_reason.is_empty(), "ordinary enabled defaults and stale reason clearing preserved")
 check(JSON.stringify(r.rows) == before, "choice projection does not mutate provider state")
 facts.price_cases = []
 for cash in [0, 7, 20, 50]:
  r.bankroll = cash
  var choice = r.crew_stake_horse_loss_choices()[0]
  var expected = mini(cash, 20)
  check(str(choice.text).contains("$%d" % expected), "repayment prose shows actual debit for wallet " + str(cash))
  check(choice.presentation_consequence_summary.begins_with("Bankroll -%d;" % expected), "repayment consequence shows exact capped debit " + str(cash))
  check(choice.requires_confirm == (expected > 0), "positive repayment confirmation hint matches actual debit " + str(cash))
  check(r.bankroll == cash, "repayment quote consumes no money " + str(cash))
  facts.price_cases.append({"cash":cash,"debit":expected,"text":choice.text,"impact":choice.presentation_consequence_summary})
 # Synthetic Collector ledger: no captured profile or payment is changed.
 var collector_choice = {"id":"settle_the_marker", "label":"Settle the marker", "text":"The whole note disappears.", "conditions":{"requires_collectible_debt":true}, "consequence_summary":"Authored story flag", "requires_confirm":false, "consequences":{"debt_settlement_discount_percent":25, "flags":{"debt_court_settlement":true}, "resolve_event":true}}
 var collector = Event.new(); collector.setup({"id":"scenario_debt_court_office_hours", "payload":{"choices":[collector_choice]}})
 facts.collector_cases = []
 for price in [{"balance":22,"payment":17}, {"balance":23,"payment":18}, {"balance":1,"payment":1}]:
  r.bankroll = 100
  r.debt = [{"id":"collector_projection_note", "lender_id":"motel_friend", "balance":price.balance, "principal":20, "status":"active", "debt_kind":"cash"}]
  var quote_before = wire({"cash":r.bankroll, "debt":r.debt, "rng":str(r.rng_state), "clock":r.game_clock_minutes, "flags":r.narrative_flags})
  var choice_before = wire(collector_choice)
  var quoted = collector.choices(r)[0]
  check(str(quoted.label).ends_with("($%d)" % int(price.payment)), "Collector button quotes the rounded payment for marker " + str(price.balance))
  check(str(quoted.text).contains("$%d marker" % int(price.balance)) and str(quoted.text).contains("Pay $%d" % int(price.payment)) and str(quoted.text).contains("25% off"), "Collector prose identifies marker payment and discount " + str(price.balance))
  check(str(quoted.presentation_consequence_summary).begins_with("Bankroll -%d;" % int(price.payment)), "Collector consequence quotes the same single debit " + str(price.balance))
  check(wire(quoted.consequences) == wire(collector_choice.consequences) and not quoted.consequences.has("bankroll_delta"), "Collector quote preserves authored settlement without adding a second debit " + str(price.balance))
  check(wire(collector_choice) == choice_before and wire({"cash":r.bankroll, "debt":r.debt, "rng":str(r.rng_state), "clock":r.game_clock_minutes, "flags":r.narrative_flags}) == quote_before, "Collector projection consumes no cash debt RNG clock or flags " + str(price.balance))
  check(quoted.id == collector_choice.id and quoted.requires_confirm == false, "Collector identity and existing confirmation behavior retained " + str(price.balance))
  facts.collector_cases.append({"balance":price.balance,"payment":price.payment,"label":quoted.label,"text":quoted.text,"impact":quoted.presentation_consequence_summary})
 r.debt[0]["balance"] = 22
 for authored_state in [{"disabled":true,"disabled_reason":"Authored Collector reason","requires_confirm":false}, {"enabled":false,"requires_confirm":true}, {"enabled":true,"disabled":false,"requires_confirm":false}]:
  var authored = collector_choice.duplicate(true); authored.merge(authored_state, true)
  var projected = collector._contextualized_choice(authored, r, {})
  var preserved = projected.duplicate(true); var authored_expected = authored.duplicate(true)
  for key in ["label", "text", "presentation_consequence_summary"]:
   preserved.erase(key); authored_expected.erase(key)
  check(wire(preserved) == wire(authored_expected), "Collector quote preserves every authored availability reason flag and confirmation field " + str(authored_state))
 r.bankroll = 0
 var unaffordable = collector._contextualized_choice(collector_choice, r, {})
 check(str(unaffordable.label).ends_with("($17)") and not unaffordable.requires_confirm, "unaffordable Collector quote retains actual price and existing confirmation contract")
 check(r.bankroll == 0 and int(r.debt[0].balance) == 22, "unaffordable Collector projection does not settle the marker")
 r.debt = []
 check(wire(collector._contextualized_choice(collector_choice, r, {})) == wire(collector_choice), "Collector no-marker fallback remains unchanged")
 check(wire(event._collector_settlement_choice(collector_choice, r)) == wire(collector_choice), "unrelated event retains authored choice unchanged")
 facts.fidelity = "SYNTHETIC read-only provider repayment and Collector projection contracts; no captured run altered."
func go():
 if not check(OS.get_environment("BTH_QA_RUN_DIR").replace("\\", "/").begins_with("E:/CodexQA/BTH/runs/"), "admitted isolated E QA run required"): return await done()
 var mode = OS.get_cmdline_user_args()[0]; facts.mode = mode
 if mode == "contract":
  contract(); return await done()
 app = Main.instantiate(); app.autosave_slot_id = Slot; root.add_child(app); await frames(4)
 if not check(app.load_foundation_run(), "captured intact cold Continue"): return await done()
 await frames(7); facts.before = signature()
 if mode == "noaudit":
  if not await open_event("crew_planning_table"): return await done()
  var p = app.current_event_choice_popup_snapshot(); facts.offer = p
  var lock = {}; var leave = {}
  for choice in p.get("choices", []):
   if choice.id == "lock_the_count": lock = choice
   if choice.id == "leave": leave = choice
  check(not lock.is_empty() and not lock.get("enabled", true) and str(lock.get("disabled_reason", "")).contains("No audit"), "real no-audit Lock is disabled with the missing-star reason")
  var b = button_for(app.event_choice_popup_choices_list, "crew_planning_table", "lock_the_count")
  check(b != null and b.disabled, "actual rendered Lock button is disabled")
  check(leave.get("enabled", false), "ordinary Leave remains enabled")
  var before = signature()
  check(not app.activate_event_choice_action("crew_planning_table", "lock_the_count"), "authoritative host still rejects stale unavailable lock")
  await frames(5)
  check(wire(signature()) == wire(before), "rejected stale lock cannot alter the campaign")
  if not await boundary("Disabled planning"): return await done()
  if not await open_event("crew_planning_table"): return await done()
  b = button_for(app.event_choice_popup_choices_list, "crew_planning_table", "lock_the_count")
  check(b != null and b.disabled, "disabled planning state survives Save Continue")
 elif mode in ["repay", "shrug"]:
  if not await open_event("crew_stake_horse_loss"): return await done()
  var p = app.current_event_choice_popup_snapshot(); facts.offer = p
  var repay = {}
  for choice in p.get("choices", []):
   if choice.id == "repay": repay = choice
  check(str(repay.get("text", "")).contains("$20") and str(repay.get("consequence_summary", "")).begins_with("Bankroll -20;"), "actual repayment card discloses its twenty-dollar debit")
  check(wire(signature()) == wire(facts.before), "opening the quoted loss decision charges nothing")
  if not await boundary("Open loss terms"): return await done()
  if not await open_event("crew_stake_horse_loss"): return await done()
  var b = button_for(app.event_choice_popup_choices_list, "crew_stake_horse_loss", mode)
  if not check(b != null and b.is_visible_in_tree() and not b.disabled, "actual enabled " + mode + " response button"): return await done()
  b.pressed.emit(); await frames(9)
  check(app.run_state.bankroll == int(facts.before.cash) - (20 if mode == "repay" else 0), "one exact debit for ordinary " + mode + " response")
  check(app.run_state.crew_delivery_obligation_count() == int(facts.before.duties), "loss response preserves separate delivery duties")
  var settled = signature()
  check(settled.jobs.size() == 1 and settled.jobs[0].status == "resolved" and settled.jobs[0].outcome == "failed", "normal loss response resolves the original job once")
  check(not app.activate_event_choice_action("crew_stake_horse_loss", mode), "resolved loss rejects stale repeat")
  await frames(4)
  check(wire(signature()) == wire(settled), "stale response preserves money RNG and public job state")
  if not await boundary("Settled loss"): return await done()
 elif mode == "settled":
  check(facts.before.jobs.size() == 1 and facts.before.jobs[0].status == "resolved", "cold settled job remains resolved")
  check(not app.activate_event_choice_action("crew_stake_horse_loss", "repay"), "cold settled job still rejects another repayment")
  check(wire(signature()) == wire(facts.before), "cold stale repayment has no effect")
  if not await boundary("Cold settled loss"): return await done()
 else: failures.append("Unknown focused mode")
 facts.after = signature(); facts.fidelity = "Captured ordinary Crew checkpoint, official Continue, live public UI and actual Control response signals. No state/outcome forcing."
 await done()
func done():
 print("CREW_SIDEBAR_UI_FIX " + JSON.stringify({"checks":checks,"failures":failures,"facts":facts}))
 if app != null:
  app.save_service.wait_for_async_save(); app.queue_free(); await frames(4)
 quit(0 if failures.is_empty() else 1)
