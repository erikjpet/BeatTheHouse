# File: Tools.gd

extends Node

var dialogue_box
var GodotGifManager = preload("res://addons/godotgif/godotgif.gdextension")

signal hitbox_selected(event)

var wireframe_event = null

# Load a GIF and return an animated texture
func load_gif(path: String) -> AnimatedTexture:
	var animated_texture = GifManager.animated_texture_from_file(path)
	if animated_texture:
		return animated_texture
	else:
		print("Failed to load GIF: " + path)
		return null

# Function to create and show a dialogue popup
func show_dialogue(duration: float, content: String) -> Control:
	if dialogue_box != null:
		dialogue_box.queue_free()
	dialogue_box = Control.new()
	dialogue_box.mouse_filter = Control.MOUSE_FILTER_PASS

	var dialogue_texture = TextureRect.new()
	dialogue_texture.texture = load("res://images/menu/dialogueBox.png")
	dialogue_texture.position = Vector2(500, 0)
	dialogue_box.add_child(dialogue_texture)

	var content_label = Label.new()
	content_label.text = content
	content_label.modulate = Color(0, 0, 0)
	content_label.position = Vector2(600, 40)
	dialogue_box.add_child(content_label)

	get_tree().get_root().add_child(dialogue_box)

	var remove_timer = Timer.new()
	remove_timer.one_shot = true
	remove_timer.wait_time = duration
	remove_timer.connect("timeout", Callable(self, "_on_timer_timeout"))
	dialogue_box.add_child(remove_timer)
	remove_timer.start()

	return dialogue_box

func _on_timer_timeout():
	print("Timer expired!")
	dialogue_box.queue_free()

func _on_wireframe_input(event, function):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("hitbox_selected", function)

func create_wireframe(position: Vector2, size: Vector2, event):
	print(wireframe_event)
	var wireframe = Control.new()
	wireframe.size = size
	wireframe.position = position
	wireframe.mouse_filter = Control.MOUSE_FILTER_STOP
	wireframe.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	wireframe.connect("gui_input", Callable(self, "_on_wireframe_input").bind(event))

	var wireframe_texture = TextureRect.new()
	wireframe_texture.texture = load("res://images/menu/hitbox_test.png")
	wireframe_texture.texture = null
	wireframe_texture.size = size
	wireframe.add_child(wireframe_texture)

	get_tree().get_root().add_child(wireframe)
	
