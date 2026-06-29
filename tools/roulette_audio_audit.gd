extends SceneTree

const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")

const OUTPUT_PATH := "res://.tmp/roulette_audio_audit/report.json"
const ROULETTE_EVENTS := [
	"roulette_chip_select",
	"roulette_chip_place",
	"roulette_chip_lift",
	"roulette_chip_stack",
	"roulette_chip_sweep",
	"roulette_rotor_launch",
	"roulette_ball_loop",
	"roulette_ball_rim_tick",
	"roulette_ball_drop",
	"roulette_ball_scatter",
	"roulette_ball_bounce",
	"roulette_ball_pocket",
	"roulette_dolly_tap",
	"roulette_payout",
]

var failures: Array[String] = []
var stats := {
	"events_checked": 0,
	"total_pcm_bytes": 0,
	"looped_events": [],
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := SfxPlayerScript.new()
	for event_id in ROULETTE_EVENTS:
		var stream := player.preview_event_stream(str(event_id))
		if stream == null:
			failures.append("Roulette audio event %s did not create a stream." % event_id)
			continue
		var bytes := stream.data.size()
		stats["events_checked"] = int(stats.get("events_checked", 0)) + 1
		stats["total_pcm_bytes"] = int(stats.get("total_pcm_bytes", 0)) + bytes
		if stream.mix_rate != 22050:
			failures.append("Roulette audio event %s used mix rate %d." % [event_id, stream.mix_rate])
		if stream.format != AudioStreamWAV.FORMAT_16_BITS:
			failures.append("Roulette audio event %s was not 16-bit PCM." % event_id)
		if bytes <= 0:
			failures.append("Roulette audio event %s generated empty PCM data." % event_id)
		var should_loop := str(event_id) == "roulette_ball_loop"
		if should_loop:
			if stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
				failures.append("Roulette ball rim loop was not configured to loop.")
			else:
				(stats["looped_events"] as Array).append(event_id)
		elif stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			failures.append("Roulette one-shot event %s was unexpectedly looped." % event_id)
	if int(stats.get("events_checked", 0)) != ROULETTE_EVENTS.size():
		failures.append("Roulette audio audit checked %d events, expected %d." % [int(stats.get("events_checked", 0)), ROULETTE_EVENTS.size()])
	player.free()
	_finish()


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var report := {
		"tool": "roulette_audio_audit",
		"passed": failures.is_empty(),
		"failure_count": failures.size(),
		"failures": failures,
		"stats": stats,
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT_PATH), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
