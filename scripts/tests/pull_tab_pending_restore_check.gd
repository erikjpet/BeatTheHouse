extends SceneTree
const State=preload("res://scripts/core/run_state.gd")
var checks=0
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func _initialize() -> void:
	# Synthetic restore-shape matrix; the captured player-save check is separate.
	var base=State.new();base.start_new("PULL-TAB-RESTORE-MATRIX")
	var environment={"id":"pending_tab_fixture","archetype_id":"bar","world_node_id":"bar","game_ids":["pull_tabs"],"game_states":{}}
	var origin=State.portable_ticket_origin_key(environment)
	var ticket={"id":"paid-ticket","price":1,"payout":0,"rows":[["A","B","C"]]}
	var winning=ticket.duplicate(true);winning.payout=5
	var cases=[
		{"name":"uncollected loser","machine":{"tray_stack":[ticket]},"active":true},
		{"name":"uncollected winner","machine":{"tray_stack":[winning]},"active":true},
		{"name":"collected unopened","machine":{"ticket_stack":[ticket]},"active":true},
		{"name":"revealed unfiled loser","machine":{"ticket_stack":[ticket.merged({"fully_revealed":true})]},"active":true},
		{"name":"revealed unfiled winner","machine":{"ticket_stack":[winning.merged({"fully_revealed":true})]},"active":true},
		{"name":"winner awaiting cashout","machine":{"winner_pile":[winning]},"active":true},
		{"name":"filed loser","machine":{"loser_pile":[ticket]},"active":false},
		{"name":"redeemed winner","machine":{"redeemed_pile":[winning]},"active":false},
		{"name":"stock is not paid","machine":{"deals":[{"remaining":50}]},"active":false},
		{"name":"wrong pile shape","machine":{"tray_stack":{"not":"tickets"}},"active":false},
		{"name":"portable paid pile","machine":{},"portable":{"tray_stack":[ticket]},"active":true},
		{"name":"portable empty overrides stale location","machine":{"tray_stack":[ticket]},"portable":{"tray_stack":[],"ticket_stack":[],"winner_pile":[]},"active":false},
		{"name":"terminal stays terminal","machine":{"tray_stack":[ticket]},"saved_status":"failed","active":false},
	]
	for case in cases:
		var data=base.to_dict().duplicate(true)
		var env=environment.duplicate(true);env.game_states={"pull_tabs":case.machine.duplicate(true)}
		data.current_environment=env;data.environment_registry={env.id:env};data.bankroll=0;data.run_status=case.get("saved_status","active");data.portable_ticket_piles={}
		if case.has("portable"):data.portable_ticket_piles={"pull_tabs":{origin:case.portable.duplicate(true)}}
		var before=data.duplicate(true)
		var restored=State.new();restored.from_dict(data)
		check((restored.run_status=="active")==case.active,"wrong restore status: "+case.name)
		check(restored.bankroll==0 and restored.rng_state==base.rng_state,"restore changed cash/RNG: "+case.name)
		check(data==before,"restore mutated source snapshot: "+case.name)
		var again=State.new();again.from_dict(restored.to_dict())
		check(again.run_status==restored.run_status and again.rng_state==restored.rng_state,"repeat restore changed status/RNG: "+case.name)
	print("PULL_TAB_PENDING_RESTORE checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
