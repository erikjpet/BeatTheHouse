extends Node2D

# Signals for communicating settings changes
signal volume_changed(volume)
signal resolution_changed(resolution)

var volume_slider
var resolution_dropdown
var background
var return_button

# Predefined resolutions
var resolutions = ["1920x1080", "1440x900", "1280x720"]

func _ready():
	# Set up the background (assuming this part is unchanged)
	background = TextureRect.new()
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	background.size_flags_vertical = Control.SIZE_EXPAND_FILL
	background.texture = tools.load_gif("res://images/BackgroundFrames/Settings.gif")
	add_child(background)
	
	# Set up the volume slider (assuming this part is unchanged)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.value = 50  # Default volume
	volume_slider.set_size(Vector2(200, 20))
	volume_slider.position = Vector2(10, 40)
	volume_slider.connect("value_changed", Callable(self, "_on_VolumeSlider_value_changed"))
	add_child(volume_slider)

	# Set up the resolution dropdown (assuming this part is unchanged)
	resolution_dropdown = OptionButton.new()
	for resolution in resolutions:
		resolution_dropdown.add_item(resolution)
	resolution_dropdown.position = Vector2(10, 110)
	resolution_dropdown.connect("item_selected", Callable(self, "_on_ResolutionDropdown_item_selected"))
	add_child(resolution_dropdown)

	# Add labels for clarity (assuming this part is unchanged)
	var volume_label = Label.new()
	volume_label.text = "Volume"
	volume_label.position = Vector2(10, 10)
	add_child(volume_label)

	var resolution_label = Label.new()
	resolution_label.text = "Resolution"
	resolution_label.position = Vector2(10, 80)
	add_child(resolution_label)

	# Add a return button
	return_button = Button.new()
	return_button.text = "Return to Menu"
	return_button.connect("pressed", Callable(self, "_on_ReturnButton_pressed"))
	return_button.position = Vector2(10, 160)
	add_child(return_button)

func _on_VolumeSlider_value_changed(value):
	emit_signal("volume_changed", value)

func _on_ResolutionDropdown_item_selected(index):
	# Get the selected resolution string (e.g., "1920x1080")
	var resolution = resolutions[index]
	
	# Parse the resolution into width and height
	var dimensions = resolution.split("x")
	if dimensions.size() == 2:
		var width = int(dimensions[0])
		var height = int(dimensions[1])
		
		# Set the new window size
		DisplayServer.window_set_size(Vector2(width, height))
		emit_signal("resolution_changed", resolution)
	else:
		# Handle invalid resolution format (optional)
		print("Invalid resolution format:", resolution)
	
	
	emit_signal("resolution_changed", resolution)

func _on_ReturnButton_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
