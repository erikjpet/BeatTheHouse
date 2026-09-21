class_name FunctionOptions
extends RefCounted


class SlotSpinResultOptions extends RefCounted:
	var values: Dictionary

	static func from(values_value: Dictionary) -> SlotSpinResultOptions:
		var options := SlotSpinResultOptions.new()
		options.values = values_value
		return options


class ScenarioAuthorityRecordOptions extends RefCounted:
	var values: Dictionary

	static func from(values_value: Dictionary) -> ScenarioAuthorityRecordOptions:
		var options := ScenarioAuthorityRecordOptions.new()
		options.values = values_value
		return options


class BlackjackResultOptions extends RefCounted:
	var values: Dictionary

	static func from(values_value: Dictionary) -> BlackjackResultOptions:
		var options := BlackjackResultOptions.new()
		options.values = values_value
		return options


class BuffaloBoardOverlayOptions extends RefCounted:
	var values: Dictionary

	static func from(values_value: Dictionary) -> BuffaloBoardOverlayOptions:
		var options := BuffaloBoardOverlayOptions.new()
		options.values = values_value
		return options


class VideoPokerHandPanelOptions extends RefCounted:
	var values: Dictionary

	static func from(values_value: Dictionary) -> VideoPokerHandPanelOptions:
		var options := VideoPokerHandPanelOptions.new()
		options.values = values_value
		return options


class WorldSequenceCommandOptions extends RefCounted:
	var values: Dictionary

	static func from(values_value: Dictionary) -> WorldSequenceCommandOptions:
		var options := WorldSequenceCommandOptions.new()
		options.values = values_value
		return options


class ScenarioSequenceCommandOptions extends RefCounted:
	var values: Dictionary

	static func from(values_value: Dictionary) -> ScenarioSequenceCommandOptions:
		var options := ScenarioSequenceCommandOptions.new()
		options.values = values_value
		return options


class DiceRowOptions extends RefCounted:
	var values: Dictionary

	static func from(values_value: Dictionary) -> DiceRowOptions:
		var options := DiceRowOptions.new()
		options.values = values_value
		return options


class SlotResolveOptions extends RefCounted:
	var values: Dictionary

	static func from(values_value: Dictionary) -> SlotResolveOptions:
		var options := SlotResolveOptions.new()
		options.values = values_value
		return options


class VideoPokerOutcomeOptions extends RefCounted:
	var values: Dictionary

	static func from(values_value: Dictionary) -> VideoPokerOutcomeOptions:
		var options := VideoPokerOutcomeOptions.new()
		options.values = values_value
		return options


static func world_sequence_command(token: String, command_id: String, idempotency_key: String, optional: Dictionary = {}) -> WorldSequenceCommandOptions:
	var values := optional.duplicate(false)
	values["token"] = token
	values["command_id"] = command_id
	values["idempotency_key"] = idempotency_key
	return WorldSequenceCommandOptions.from(values)


static func scenario_sequence_command(command_id: String, node_id: String, phase_id: String, idempotency_key: String, optional: Dictionary = {}) -> ScenarioSequenceCommandOptions:
	var values := optional.duplicate(false)
	values["command_id"] = command_id
	values["node_id"] = node_id
	values["phase_id"] = phase_id
	values["idempotency_key"] = idempotency_key
	return ScenarioSequenceCommandOptions.from(values)


static func slot_resolve(machine: Dictionary, action_id: String, selected_bet: Dictionary, remaining: Dictionary) -> SlotResolveOptions:
	var values := remaining.duplicate(false)
	values["machine"] = machine
	values["action_id"] = action_id
	values["selected_bet"] = selected_bet
	return SlotResolveOptions.from(values)
