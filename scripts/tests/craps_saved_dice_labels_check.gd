extends SceneTree

const Craps = preload("res://scripts/games/craps.gd")
class Labels extends RefCounted:
	var values: Array[String]=[]
	func surface_animation_active(_channel):return false
	func surface_animation_progress(_channel):return 1.0
	func draw_rect(_rect,_color,_filled=true,_width=-1.0):pass
	func surface_label_centered(text,_rect,_size,_color):values.append(text)

func _initialize() -> void:
	var game=Craps.new()
	var failures: Array[String]=[]
	var checks=0
	# Exercise fresh integer faces and the float-valued JSON load representation.
	for pair in [[1,6],[2,5],[3,4]]:
		for dice in [pair,JSON.parse_string(JSON.stringify(pair))]:
			var state={"last_roll":{"dice":dice},"reduce_motion":true}
			var before=state.duplicate(true)
			for street in [true,false]:
				var labels=Labels.new()
				if street:game._draw_street_dice(labels,state)
				else:game._draw_dice(labels,state)
				checks+=1
				if labels.values!=[str(pair[0]),str(pair[1])]:failures.append("decimal/wrong faces: %s" % str(labels.values))
				checks+=1
				if state!=before:failures.append("drawing changed saved dice state")
	print("CRAPS_SAVED_DICE_LABELS checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
