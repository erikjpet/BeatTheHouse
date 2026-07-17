class_name MusicOutcomeDirectorModel
extends RefCounted

const OUTCOME_CLASSES := ["small_win", "loss", "big_win", "feature_start", "feature_end", "neutral", "push"]
const QUANTIZATIONS := ["beat", "half_bar", "bar", "phrase"]
const DEFAULT_CUES := {
	"small_win": {"cue_id": "small_win", "quantize": "beat", "max_latency_beats": 1.0, "cooldown_beats": 2.0, "volume_db": -3.0},
	"loss": {"cue_id": "loss", "quantize": "half_bar", "max_latency_beats": 2.0, "cooldown_beats": 2.0, "volume_db": -5.0},
	"big_win": {"cue_id": "big_win", "quantize": "bar", "max_latency_beats": 4.0, "cooldown_beats": 8.0, "volume_db": -1.0},
	"feature_start": {"cue_id": "feature_start", "quantize": "bar", "max_latency_beats": 4.0, "cooldown_beats": 2.0, "volume_db": -4.0},
	"feature_end": {"cue_id": "feature_end", "quantize": "bar", "max_latency_beats": 4.0, "cooldown_beats": 2.0, "volume_db": -5.0},
	"neutral": {"cue_id": "", "quantize": "beat", "max_latency_beats": 1.0, "cooldown_beats": 0.0, "volume_db": -6.0},
	"push": {"cue_id": "", "quantize": "beat", "max_latency_beats": 1.0, "cooldown_beats": 0.0, "volume_db": -6.0},
}


static func normalize_event(value: Variant) -> Dictionary:
	var source: Dictionary = value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
	var outcome_class := str(source.get("outcome_class", source.get("class", "neutral"))).strip_edges().to_lower()
	if not OUTCOME_CLASSES.has(outcome_class):
		outcome_class = "neutral"
	return {
		"event_token": str(source.get("event_token", source.get("token", ""))).strip_edges(),
		"outcome_class": outcome_class,
		"magnitude": maxf(0.0, float(source.get("magnitude", source.get("amount", 0.0)))),
		"tier": str(source.get("tier", "standard")).strip_edges().to_lower(),
		"source_game": str(source.get("source_game", source.get("game_id", ""))).strip_edges(),
		"result_time": source.get("result_time", source.get("game_clock_minutes", 0)),
		"requested_quantization": str(source.get("requested_quantization", source.get("quantize", ""))).strip_edges().to_lower(),
		"cue_id": str(source.get("cue_id", "")).strip_edges(),
		"transport_beat": maxf(0.0, float(source.get("transport_beat", 0.0))),
	}


static func select_cue(stinger_metadata_value: Variant, event: Dictionary) -> Dictionary:
	var outcome_class := str(event.get("outcome_class", "neutral"))
	var requested_cue := str(event.get("cue_id", ""))
	var metadata: Dictionary = stinger_metadata_value as Dictionary if typeof(stinger_metadata_value) == TYPE_DICTIONARY else {}
	var cue_ids := metadata.keys()
	cue_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for cue_value in cue_ids:
		var cue_id := str(cue_value)
		var cue_value_data: Variant = metadata.get(cue_value)
		if typeof(cue_value_data) != TYPE_DICTIONARY:
			continue
		var cue: Dictionary = cue_value_data
		var outcome_classes := _string_array(cue.get("outcome_classes", []))
		if not requested_cue.is_empty() and cue_id != requested_cue:
			continue
		if requested_cue.is_empty() and not outcome_classes.has(outcome_class):
			continue
		return normalize_cue(cue_id, cue, outcome_class)
	var fallback: Dictionary = (DEFAULT_CUES.get(outcome_class, DEFAULT_CUES["neutral"]) as Dictionary).duplicate(true)
	if not requested_cue.is_empty():
		fallback["cue_id"] = requested_cue
	fallback["outcome_classes"] = [outcome_class]
	fallback["reverb_pulse"] = {}
	return fallback


static func normalize_cue(cue_id: String, value: Variant, outcome_class: String) -> Dictionary:
	var source: Dictionary = value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
	var quantize := str(source.get("quantize", "beat")).strip_edges().to_lower()
	if not QUANTIZATIONS.has(quantize):
		quantize = "beat"
	var outcome_classes := _string_array(source.get("outcome_classes", [outcome_class]))
	var pulse_value: Variant = source.get("reverb_pulse", {})
	var pulse_source: Dictionary = pulse_value as Dictionary if typeof(pulse_value) == TYPE_DICTIONARY else {}
	var pulse := {}
	if not pulse_source.is_empty():
		pulse = {
			"attack_beats": maxf(0.0, float(pulse_source.get("attack_beats", 0.0))),
			"hold_beats": maxf(0.0, float(pulse_source.get("hold_beats", 0.0))),
			"release_beats": maxf(0.0, float(pulse_source.get("release_beats", 0.0))),
			"peak_send": clampf(float(pulse_source.get("peak_send", 0.0)), 0.0, 0.45),
			"eligible_roles": _string_array(pulse_source.get("eligible_roles", [])),
			"outcome_classes": _string_array(pulse_source.get("outcome_classes", outcome_classes)),
			"cooldown_beats": maxf(0.0, float(pulse_source.get("cooldown_beats", source.get("cooldown_beats", 0.0)))),
		}
	return {
		"cue_id": cue_id,
		"quantize": quantize,
		"max_latency_beats": maxf(1.0, float(source.get("max_latency_beats", 1.0))),
		"cooldown_beats": maxf(0.0, float(source.get("cooldown_beats", 0.0))),
		"volume_db": clampf(float(source.get("volume_db", -3.0)), -24.0, 3.0),
		"outcome_classes": outcome_classes,
		"reverb_pulse": pulse,
	}


static func quantized_boundary(current_beat: float, requested_quantization: String, phrase_bars: int, max_latency_beats: float) -> Dictionary:
	var requested := requested_quantization.strip_edges().to_lower()
	if not QUANTIZATIONS.has(requested):
		requested = "beat"
	var quantum_by_id := {
		"beat": 1.0,
		"half_bar": 2.0,
		"bar": 4.0,
		"phrase": float(maxi(1, phrase_bars) * 4),
	}
	var candidates := [requested]
	match requested:
		"phrase":
			candidates.append_array(["bar", "half_bar", "beat"])
		"bar":
			candidates.append_array(["half_bar", "beat"])
		"half_bar":
			candidates.append("beat")
	var safe_current := maxf(0.0, current_beat)
	var safe_latency := maxf(1.0, max_latency_beats)
	for quantization_value in candidates:
		var quantization := str(quantization_value)
		var quantum := float(quantum_by_id.get(quantization, 1.0))
		var target: float = ceil((safe_current + 0.000001) / quantum) * quantum
		var latency: float = target - safe_current
		if latency <= safe_latency + 0.000001 or quantization == "beat":
			return {
				"requested_quantization": requested,
				"quantization": quantization,
				"quantum_beats": quantum,
				"target_transport_beat": snappedf(target, 0.000001),
				"latency_beats": snappedf(latency, 0.000001),
				"fallback_used": quantization != requested,
			}
	return {}


static func reverb_level(envelope: Dictionary, transport_beat: float) -> float:
	if envelope.is_empty():
		return 0.0
	var beat := maxf(0.0, transport_beat)
	var start := float(envelope.get("start_beat", 0.0))
	var attack := maxf(0.0, float(envelope.get("attack_beats", 0.0)))
	var hold := maxf(0.0, float(envelope.get("hold_beats", 0.0)))
	var release := maxf(0.0, float(envelope.get("release_beats", 0.0)))
	var peak := clampf(float(envelope.get("peak_send", 0.0)), 0.0, 0.45)
	var start_level := clampf(float(envelope.get("start_level", 0.0)), 0.0, peak)
	if beat < start:
		return 0.0
	if attack > 0.0 and beat < start + attack:
		return lerpf(start_level, peak, clampf((beat - start) / attack, 0.0, 1.0))
	var release_start := start + attack + hold
	if beat <= release_start:
		return peak
	if release <= 0.0 or beat >= release_start + release:
		return 0.0
	return lerpf(peak, 0.0, clampf((beat - release_start) / release, 0.0, 1.0))


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value as Array:
		var text := str(item).strip_edges().to_lower()
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result
