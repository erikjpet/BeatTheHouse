extends Node2D

# Configuration for the table layout
var table_config = {
	"numbers": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", 
				"13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", 
				"24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36"],
	"colors": {"0": "green", "1": "red", "2": "black", "3": "red", "4": "black", "5": "red"}
}

var bets = []  # Track player bets
var wheel_sprite
var spin_button
var result_label
var table_image
var table_scale
var preview_chip
var preview_chip_loc
var selected_chip_value = 5

func _ready():
	# Initialize all elements
	setup_table_background()
	setup_betting_areas()
	setup_chip_selection()
	setup_wheel()
	setup_ui()
	print("Roulette initialized.")

# Setup the betting table background
func setup_table_background():
	table_image = Sprite2D.new()
	table_image.texture = load("res://images/rbet_table.png")
	print("Betting table texture loaded:", table_image.texture != null)
	table_scale = 0.6
	table_image.scale = Vector2(table_scale, table_scale)  # Scale down to fit
	table_image.position = Vector2(600, 100)  # Positioned next to the wheel
	table_image.z_index = 1
	add_child(table_image)
	print("Table initialized at position:", table_image.position)

# Define and setup betting areas based on the correct table layout
func setup_betting_areas():
	# Base position for the top-left corner of the table
	var base_x = 290  # Table's x-coordinate
	var base_y = -50  # Table's y-coordinate

	# Dimensions of each cell
	var cell_width = 73 * table_scale
	var cell_height = 102 * table_scale

	# Predefined mapping of numbers to rows and columns (table layout)
	var number_positions = {
		"0": Vector2(0, 1),  # "0" is in its own row (special case)
		"1": Vector2(1, 2), "2": Vector2(1, 1), "3": Vector2(1, 0),
		"4": Vector2(2, 2), "5": Vector2(2, 1), "6": Vector2(2, 0),
		"7": Vector2(3, 2), "8": Vector2(3, 1), "9": Vector2(3, 0),
		"10": Vector2(4, 2), "11": Vector2(4, 1), "12": Vector2(4, 0),
		"13": Vector2(5, 2), "14": Vector2(5, 1), "15": Vector2(5, 0),
		"16": Vector2(6, 2), "17": Vector2(6, 1), "18": Vector2(6, 0),
		"19": Vector2(7, 2), "20": Vector2(7, 1), "21": Vector2(7, 0),
		"22": Vector2(8, 2), "23": Vector2(8, 1), "24": Vector2(8, 0),
		"25": Vector2(9, 2), "26": Vector2(9, 1), "27": Vector2(9, 0),
		"28": Vector2(10, 2), "29": Vector2(10, 1), "30": Vector2(10, 0),
		"31": Vector2(11, 2), "32": Vector2(11, 1), "33": Vector2(11, 0),
		"34": Vector2(12, 2), "35": Vector2(12, 1), "36": Vector2(12, 0)
	}


	# Create clickable areas for each number
	for number in table_config["numbers"]:
		if number in number_positions:
			var position = number_positions[number]
			var area = Area2D.new()
			var collision = CollisionPolygon2D.new()
			collision.polygon = PackedVector2Array([
				Vector2(base_x + position.x * cell_width, base_y + position.y * cell_height),
				Vector2(base_x + (position.x + 1) * cell_width, base_y + position.y * cell_height),
				Vector2(base_x + (position.x + 1) * cell_width, base_y + (position.y + 1) * cell_height),
				Vector2(base_x + position.x * cell_width, base_y + (position.y + 1) * cell_height)
			])
			area.add_child(collision)
			area.z_index = 2
			area.connect("input_event", Callable(self, "_on_area_clicked").bind(number))
			add_child(area)
	print("Betting areas set up.")



# Handle clicks on betting areas
func _on_area_clicked(viewport, event, shape_idx, number):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if preview_chip_loc == number:
			print("Clicked betting region:", number)
			print("Bet Placed on " + number)
			var bet = {"Bet": number, "Wager": selected_chip_value}
			bets.append(bet)  # Add the bet to the array
			print(bets)  # Debugging: Check the contents of bets
			Money.update_money(-selected_chip_value)
		else:
			preview_chips(number)

		


# Preview chips on selected region
func preview_chips(number):
	if preview_chip:
		preview_chip.queue_free()
	preview_chip = Sprite2D.new()
	preview_chip.texture = load("res://images/" + str(selected_chip_value) + "chip.png")
	preview_chip.position = get_chip_position(number)
	preview_chip.z_index = 3
	preview_chip.modulate = Color(1, 1, 1, 0.5)
	preview_chip_loc = number
	add_child(preview_chip)
	print("Preview chip placed at:", preview_chip.position)

# Get chip position for a specific number
# Get chip position for a specific number
func get_chip_position(number):
	# Base position for the table
	var base_x = 290  # Table's x-coordinate
	var base_y = -50  # Table's y-coordinate

	# Dimensions of each cell
	var cell_width = 73 * table_scale
	var cell_height = 122 * table_scale

	# Map of numbers to their (row, column) positions
	var number_positions = {
		"0": Vector2(0, 1),  # "0" is in its own row (special case)
		"1": Vector2(1, 2), "2": Vector2(1, 1), "3": Vector2(1, 0),
		"4": Vector2(2, 2), "5": Vector2(2, 1), "6": Vector2(2, 0),
		"7": Vector2(3, 2), "8": Vector2(3, 1), "9": Vector2(3, 0),
		"10": Vector2(4, 2), "11": Vector2(4, 1), "12": Vector2(4, 0),
		"13": Vector2(5, 2), "14": Vector2(5, 1), "15": Vector2(5, 0),
		"16": Vector2(6, 2), "17": Vector2(6, 1), "18": Vector2(6, 0),
		"19": Vector2(7, 2), "20": Vector2(7, 1), "21": Vector2(7, 0),
		"22": Vector2(8, 2), "23": Vector2(8, 1), "24": Vector2(8, 0),
		"25": Vector2(9, 2), "26": Vector2(9, 1), "27": Vector2(9, 0),
		"28": Vector2(10, 2), "29": Vector2(10, 1), "30": Vector2(10, 0),
		"31": Vector2(11, 2), "32": Vector2(11, 1), "33": Vector2(11, 0),
		"34": Vector2(12, 2), "35": Vector2(12, 1), "36": Vector2(12, 0)
	}

	if number in number_positions:
		var position = number_positions[number]
		return Vector2(
			base_x + position.x * cell_width + cell_width / 2,
			base_y + position.y * cell_height + cell_height / 2
		)
	else:
		return Vector2(base_x, base_y)  # Default fallback





# Setup chip selection buttons
func setup_chip_selection():
	var chip_values = [5, 10, 20, 50, 100]
	var x_offset = 150
	var y_position = 400

	for chip in chip_values:
		var button = Button.new()
		button.text = str(chip) + " Chips"
		button.position = Vector2(x_offset, y_position)
		button.set("custom_minimum_size", Vector2(100, 40))
		button.z_index = 3
		button.connect("pressed", Callable(self, "_on_chip_selected").bind(chip))
		add_child(button)
		x_offset += 120
		print("Chip button created for value:", chip, "at position:", button.position)
	print("Chip selection set up.")

func _on_chip_selected(chip_value):
	print("Selected chip value:", chip_value)
	selected_chip_value = chip_value

# Setup the roulette wheel
func setup_wheel():
	wheel_sprite = Sprite2D.new()
	wheel_sprite.texture = load("res://images/roulette_wheel.png")
	wheel_sprite.position = Vector2(50, 100)  # Positioned in the top-left quadrant
	wheel_sprite.z_index = 1
	add_child(wheel_sprite)
	print("Wheel initialized at position:", wheel_sprite.position)

# Setup UI elements (spin button and result label)
func setup_ui():
	spin_button = Button.new()
	spin_button.text = "Spin"
	spin_button.position = Vector2(0, 400)  # Position near the bottom center
	spin_button.set("custom_minimum_size", Vector2(-100, 50))
	spin_button.z_index = 3
	spin_button.connect("pressed", Callable(self, "_on_spin_button_pressed"))
	add_child(spin_button)
	print("Spin button created at position:", spin_button.position)

	result_label = Label.new()
	result_label.text = "Place your bets!"
	result_label.position = Vector2(-150, 400)  # Centered below spin button
	result_label.z_index = 3
	add_child(result_label)
	print("Result label created at position:", result_label.position)

# Spin the roulette wheel
func _on_spin_button_pressed():
	print("Spinning the wheel...")
	result_label.text = "Spinning..."
	simulate_spin()

func simulate_spin():
	var rotation_duration = 5.0
	var base_angle = wheel_sprite.rotation
	var final_angle = randf_range(0, 360)
	var total_angle = base_angle + deg_to_rad(360 * 3) + deg_to_rad(final_angle)

	var tween = create_tween()
	tween.tween_property(wheel_sprite, "rotation", total_angle, rotation_duration)
	await tween.finished

	var normalized_final_angle = rad_to_deg(fmod(total_angle, 360))
	var winning_number = get_number_from_angle(normalized_final_angle)
	result_label.text = "Winning number: " + winning_number
	
	payout_game()

# Map angle to a number
func get_number_from_angle(angle):
	var normalized_angle = fmod(angle, 360)
	var segment_angle = 360.0 / table_config["numbers"].size()
	var index = int(normalized_angle / segment_angle) % table_config["numbers"].size()
	return table_config["numbers"][index]
	
func payout_game():
	print("Processing payouts...")
	
	if bets.size() == 0:
		print("No bets to process.")
		return
	
	# Simulate the winning number (or replace with the actual result from the spin)
	var winning_number = get_number_from_angle(wheel_sprite.rotation)
	print("Winning number is:", winning_number)

	# Process each bet
	for bet in bets:
		var bet_number = bet["Bet"]
		var wager = bet["Wager"]
		
		if bet_number == winning_number:
			# Calculate payout (35:1 for straight bets)
			var payout = wager * 35
			Money.update_money(payout) 
			print("Bet on", bet_number, "won! Wager:", wager, "Payout:", payout)
		else:
			# Losing bet, wager is lost
			print("Bet on", bet_number, "lost. Wager:", wager)
	
	# Clear bets after processing
	bets.clear()
	print("All bets cleared.")

