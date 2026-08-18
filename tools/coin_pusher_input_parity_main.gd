extends Node

const Smoke := preload("res://tools/native_coin_pusher_smoke.gd")
const RESULT_MARKER := "COIN_PUSHER_V3_SMOKE_RESULT="


func _ready() -> void:
	var report: Dictionary = Smoke._run_smoke()
	print(RESULT_MARKER + JSON.stringify(report))
	get_tree().quit(0 if bool(report.get("ok", false)) else 1)
