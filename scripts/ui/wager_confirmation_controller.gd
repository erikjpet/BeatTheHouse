class_name WagerConfirmationController
extends RefCounted

signal confirm_requested()
signal cancel_requested()

var pending_action_id: String = ""
var pending_skip_stake_validation := false
var pending_preserve_surface_ui_state := false
var pending_stake: int = 0
var pending_source_game_id: String = ""


func configure_confirmation(action_id: String, stake: int, wager_cost: int, skip_stake_validation: bool, preserve_surface_ui_state: bool, source_game_id: String, action_label: String) -> Dictionary:
	pending_action_id = action_id
	pending_skip_stake_validation = skip_stake_validation
	pending_preserve_surface_ui_state = preserve_surface_ui_state
	pending_stake = stake
	pending_source_game_id = source_game_id
	var summary := "Betting $%d risks your last cash. If this play loses, the run ends after the result finishes resolving." % wager_cost
	return {
		"title": "All-in wager",
		"summary": summary,
		"snapshot": {
			"visible": true,
			"blocking": true,
			"popup_type": "wager_confirmation",
			"interaction_kind": "blocking_decision",
			"dismissible": false,
			"summary": summary,
			"action_id": action_id,
			"action_label": action_label,
			"stake": stake,
			"wager_cost": wager_cost,
			"choices": [
				{"id": "confirm", "label": "Confirm Bet", "text": "Resolve %s at stake %d." % [action_label, stake], "consequence_summary": "Loss can end the run."},
				{"id": "cancel", "label": "Change Stake", "text": "Return to the game surface.", "consequence_summary": "No wager placed."},
			],
		},
		"cards": [
			{"label": "Confirm Bet", "text": "Resolve %s at stake %d." % [action_label, stake], "impact": "Loss can end the run.", "action": "confirm", "primary": true},
			{"label": "Change Stake", "text": "Return to the game surface.", "impact": "No wager placed.", "action": "cancel", "primary": false},
		],
	}


func pending_state() -> Dictionary:
	return {
		"action_id": pending_action_id,
		"skip_stake_validation": pending_skip_stake_validation,
		"preserve_surface_ui_state": pending_preserve_surface_ui_state,
		"stake": pending_stake,
		"source_game_id": pending_source_game_id,
	}


func has_pending() -> bool:
	return not pending_action_id.is_empty()


func clear() -> void:
	pending_action_id = ""
	pending_skip_stake_validation = false
	pending_preserve_surface_ui_state = false
	pending_stake = 0
	pending_source_game_id = ""
