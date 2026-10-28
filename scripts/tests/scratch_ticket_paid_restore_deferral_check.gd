extends SceneTree

const Scratch := preload("res://scripts/games/scratch_tickets.gd")
const Codec := preload("res://scripts/core/run_save_codec.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	var base := RunState.new()
	base.start_new("SCRATCH-PAID-RESTORE-REGRESSION")
	# Synthetic shape control for the shared predicate's other paid-game leg.
	# Real caught-Peek saves retain debit/session display fields after barring.
	var blackjack := RunState.new()
	blackjack.start_new("PAID-CLOSED-BLACKJACK-CONTROL")
	blackjack.bankroll=0
	blackjack.current_environment={"id":"grand_paid_control","archetype_id":"grand_casino","game_states":{"blackjack":{"_blackjack_action_authority":{"session":{"bankroll_wager_debited":true,"wager_debited":40,"player_hands":[{}]}}}}}
	_check(blackjack.has_pending_paid_game_resolution(),"existing paid live Blackjack hand defers zero funds")
	blackjack.change_bankroll(0)
	_check(blackjack.run_status=="active","zero-funds economy boundary preserves live paid hand")
	blackjack.current_environment.game_states.blackjack.barred=true
	_check(not blackjack.has_pending_paid_game_resolution(),"closed barred hand is not an unresolved paid asset")
	blackjack.evaluate_immediate_terminal_state()
	_check(blackjack.run_status=="failed","barred display receipt cannot keep zero funds alive")
	var env := {"id":"scratch_restore_fixture","world_node_id":"gas_station_casino","archetype_id":"gas_station_casino","game_ids":["scratch_tickets"],"game_states":{}}
	var origin := RunState.portable_ticket_origin_key(env)
	var ticket := {"id":"issued-paid-ticket","price":2,"payout":0,"settled":false}
	var winner := ticket.merged({"payout":5,"settled":true},true)
	var cases := [
		{"name":"paid tray loser","machine":{"tray_stack":[ticket]},"pending":true},
		{"name":"paid tray winner","machine":{"tray_stack":[ticket.merged({"payout":5},true)]},"pending":true},
		{"name":"paid queue","machine":{"pending_queue":[ticket]},"pending":true},
		{"name":"active partial","machine":{"active_ticket":ticket},"pending":true},
		{"name":"revealed unfiled","machine":{"active_ticket":ticket.merged({"fully_revealed":true},true)},"pending":true},
		{"name":"filed collectible winner","machine":{"winner_pile":[winner]},"pending":true},
		{"name":"filed loser","machine":{"loser_pile":[ticket.merged({"settled":true},true)]},"pending":false},
		{"name":"settled stale tray","machine":{"tray_stack":[ticket.merged({"settled":true},true)]},"pending":false},
		{"name":"redeemed winner","machine":{"redeemed_pile":[winner]},"pending":false},
		{"name":"unsold stock","machine":{"stock":[ticket]},"pending":false},
		{"name":"display receipt","machine":{"last_settled_ticket":winner},"pending":false},
		{"name":"archive only","machine":{"loser_archive_count":20},"pending":false},
		{"name":"penalty only","machine":{"pending_penalty":{"heat":4}},"pending":false},
		{"name":"malformed tray","machine":{"tray_stack":{"id":"not-an-array"}},"pending":false},
		{"name":"empty ticket","machine":{"tray_stack":[{}]},"pending":false},
		{"name":"missing identity","machine":{"tray_stack":[{"price":2}]},"pending":false},
		{"name":"unissued zero price","machine":{"tray_stack":[ticket.merged({"price":0},true)]},"pending":false},
		{"name":"portable paid","machine":{},"portable":{"tray_stack":[ticket]},"pending":true},
		{"name":"portable empty owns state","machine":{"tray_stack":[ticket]},"portable":{"tray_stack":[],"pending_queue":[],"active_ticket":{},"winner_pile":[]},"pending":false},
		{"name":"saved failure stays terminal","machine":{"tray_stack":[ticket]},"saved_status":"failed","pending":true},
	]
	for row in cases:
		_check(RunState.scratch_ticket_resolution_pending(row.get("portable",row.machine)) == row.pending,"shared pending predicate: " + row.name)
		var data := base.to_dict().duplicate(true)
		var current := env.duplicate(true)
		current.game_states = {"scratch_tickets":row.machine.duplicate(true)}
		data.current_environment=current
		data.environment_registry={current.id:current}
		data.bankroll=0
		data.run_status=row.get("saved_status","active")
		data.portable_ticket_piles={}
		if row.has("portable"):
			data.portable_ticket_piles={"scratch_tickets":{origin:row.portable.duplicate(true)}}
		var before := data.duplicate(true)
		var restored := RunState.new()
		restored.from_dict(data)
		var expected_active:bool = row.pending and str(row.get("saved_status","active"))=="active"
		if expected_active:
			restored.change_bankroll(0)
			_check(restored.run_status=="active","intervening zero-delta economy boundary: "+row.name)
			restored.change_bankroll(-3)
			_check(restored.run_status=="active" and restored.bankroll==0,"intervening clamped event charge: "+row.name)
			restored.evaluate_immediate_terminal_state()
			_check(restored.run_status=="active","immediate terminal boundary: "+row.name)
			var evaluated := RunTerminalEvaluator.evaluate_terminal(restored)
			_check(not bool(evaluated.failed) and bool(evaluated.bankroll_zero_deferred),"shared evaluator needs no library to recognize paid assets: "+row.name)
		_check((restored.run_status=="active")==expected_active,"restore terminal boundary: "+row.name)
		_check(restored.bankroll==0 and restored.rng_state==base.rng_state,"no cash or RNG replay: "+row.name)
		_check(data==before,"input snapshot unchanged: "+row.name)
		var again := RunState.new()
		var encoded:=Codec.encode(restored.to_save_snapshot())
		var parsed:Dictionary=JSON.parse_string(JSON.stringify(encoded))
		again.from_dict(Codec.decode(parsed))
		_check(again.run_status==restored.run_status and again.rng_state==restored.rng_state,"JSON cold restore stable: "+row.name)
		_check(_identities(again.portable_ticket_piles)==_identities(restored.portable_ticket_piles),"portable ticket identities stable: "+row.name)
		if expected_active:
			# Synthetic terminal boundary: all issued tickets are now filed losers
			# and any old venue state is superseded by the empty portable pile.
			restored.portable_ticket_piles={"scratch_tickets":{origin:{"tray_stack":[],"pending_queue":[],"active_ticket":{},"winner_pile":[]}}}
			restored.current_environment.game_states={"scratch_tickets":{"loser_pile":[ticket.merged({"settled":true},true)]}}
			restored.evaluate_immediate_terminal_state()
			_check(restored.run_status=="failed" and restored.run_failure_reason==RunState.FAILURE_BANKROLL_ZERO,"no permanent deferral after final worthless settlement: "+row.name)
	print("SCRATCH_PAID_RESTORE checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func _identities(value:Variant,path:String="")->Array:
	var result:=[]
	if typeof(value)==TYPE_DICTIONARY:
		if value.has("id"):
			result.append("%s:%s:%d:%d:%s" % [path,str(value.id),int(value.get("price",0)),int(value.get("payout",0)),str(bool(value.get("settled",false)))])
		else:
			for key in value:result.append_array(_identities(value[key],path+"/"+str(key)))
	elif typeof(value)==TYPE_ARRAY:
		for index in range(value.size()):result.append_array(_identities(value[index],path+"/"+str(index)))
	result.sort();return result

func _check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
