extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")


func _init() -> void:
	var failures: Array[String] = []
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	if not library.validation_errors.is_empty():
		failures.append("Content validation failed: %s" % JSON.stringify(library.validation_errors))
	var event_definition := library.event("call_brother_in_law")
	var success_result: Dictionary = {}
	var miss_result: Dictionary = {}
	for seed_index in range(512):
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("PHONE-AUDIO-%03d" % seed_index)
		run_state.set_environment({
			"id": "phone_audio_room",
			"archetype_id": "motel",
			"kind": "shop",
			"tier": 1,
			"event_ids": ["call_brother_in_law"],
			"resolved_event_ids": [],
		})
		var event_module := EventModule.new()
		event_module.setup(event_definition, library)
		var result := event_module.resolve(run_state, run_state.current_environment, "make_call")
		if run_state.pending_triggered_events.is_empty():
			if miss_result.is_empty():
				miss_result = result
		else:
			if success_result.is_empty():
				success_result = result
		if not success_result.is_empty() and not miss_result.is_empty():
			break
	if success_result.is_empty() or miss_result.is_empty():
		failures.append("Could not produce both answered and unanswered deterministic phone outcomes.")
	else:
		if str(success_result.get("audio_cue", "")) != "phone_call":
			failures.append("Answered call did not preserve the normal phone_call cue.")
		if str(miss_result.get("audio_cue", "")) != "phone_out_of_service":
			failures.append("Unanswered call did not select the phone_out_of_service cue.")
		if str(miss_result.get("post_resolution_message", "")) != "No one picked up.":
			failures.append("Unanswered call lost its no-answer result message.")
	var sfx_player := SfxPlayerScript.new()
	var answered_stream: AudioStreamWAV = sfx_player.preview_event_stream("phone_call")
	var unanswered_stream: AudioStreamWAV = sfx_player.preview_event_stream("phone_out_of_service")
	var web_unanswered_stream: AudioStreamWAV = sfx_player.call("_web_delivery_event_stream", "phone_out_of_service") as AudioStreamWAV
	if answered_stream == null or unanswered_stream == null:
		failures.append("Phone audio streams could not be generated.")
	else:
		if answered_stream.mix_rate != SfxPlayerScript.TELEPHONE_SAMPLE_RATE or unanswered_stream.mix_rate != SfxPlayerScript.TELEPHONE_SAMPLE_RATE:
			failures.append("Phone cues did not retain the telephone-band sample rate.")
		if unanswered_stream.data.size() <= answered_stream.data.size() or unanswered_stream.data == answered_stream.data:
			failures.append("Out-of-service cue is not a distinct extended failure sound.")
	if web_unanswered_stream == null or web_unanswered_stream.format != AudioStreamWAV.FORMAT_IMA_ADPCM or web_unanswered_stream.mix_rate != SfxPlayerScript.TELEPHONE_SAMPLE_RATE or web_unanswered_stream.data.is_empty():
		failures.append("Compressed Web delivery for the out-of-service cue is missing or invalid.")
	sfx_player.free()
	if failures.is_empty():
		print("PHONE CALL AUDIO AUDIT PASS: answered calls ring normally; unanswered calls end out of service.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
