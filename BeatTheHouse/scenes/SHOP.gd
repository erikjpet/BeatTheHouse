# File: shop.gd

extends Node2D

var money_label
var inventory_label

var bailout_button 
var level_button
var change_scene_button
var Background


var items = ["lucky_coin", "gamer_glasses", "smoked_sausage", "bean", "charm_bracelet", "ace_up_sleeve", "free_bev"]  # Add your item names here
var item_sprites = []  # List to store the item sprites
var inventory_sprites = []  # List to store the inventory sprites

# Define shop object
var shop = {
	"setting": "default",
	"available_items": [],
	"prices": {"lucky_coin": 70, "gamer_glasses": 70, "smoked_sausage": 20, "bean": 400, "charm_bracelet": 35, "ace_up_sleeve": 50, "free_bev": 12}
}

# Define a dictionary mapping settings to background GIFs
var settings_to_backgrounds = {
	"alley": "res://images/BackgroundFrames/alley.gif",
	"bar": "res://images/BackgroundFrames/bar.gif",
	"forest": "res://images/BackgroundFrames/forest.gif",
	"space": "res://images/BackgroundFrames/Settings.gif",
	#"market": "res://images/BackgroundFrames/market.gif"
}

func _ready():
	if Money.active_shop == null:
		print("Generating new shop")
		Money.active_shop = generate_shop()
	else:
		print("Loaded existing shop:", Money.active_shop)

	var tmp_label = Label.new()
	tmp_label.name = "tmp_label"
	tmp_label.text = shop["setting"]
	tmp_label.position = Vector2(20, 60)
	add_child(tmp_label)
	
	await(sleep(2))

	
	# Setting background node to fill entire screen
	Background = TextureRect.new()
	Background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	Background.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Background.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(Background)

	# Add and set up the scene change button
	change_scene_button = Button.new()
	change_scene_button.text = "GO TO CASINO"
	change_scene_button.position = Vector2(20, 20)
	change_scene_button.connect("pressed", Callable(self, "_on_ChangeSceneButton_pressed"))
	add_child(change_scene_button)
	
	# Add and set up the bailout button
	bailout_button = Button.new()
	bailout_button.text = "Government subsidized bailout"
	bailout_button.position = Vector2(890, 600)
	bailout_button.connect("pressed", Callable(self, "_on_BailoutButton_pressed"))
	add_child(bailout_button)

	# Add and set up the next level button
	level_button = Button.new()
	level_button.text = "Move to next level"
	level_button.position = Vector2(890, 560)
	level_button.connect("pressed", Callable(self, "_on_next_level_pressed"))
	add_child(level_button)
	
	# Display money count
	money_label = Label.new()
	money_label.name = "money_label"
	money_label.position = Vector2(20, 60)
	add_child(money_label)

	# Display inventory count
	inventory_label = Label.new()
	inventory_label.name = "inventory_label"
	inventory_label.position = Vector2(20, 550)
	add_child(inventory_label)
	
	# Connect the money_changed signal using Callable
	Money.connect("money_changed", Callable(self, "_on_money_changed"))

	# Initial update of money label
	update_money_label()

		# Set background based on the setting
	var background_path = settings_to_backgrounds.get(Money.active_shop["setting"], null)
	set_animated_background(background_path)
	
	display_shop()
	update_inventory_display()  # Update inventory display initially
	
	# Connect hitbox_selected signal to a handler
	tools.connect("hitbox_selected", Callable(self, "_on_hitbox_selected"))
	
	#set up scene specific elements:
	
	if Money.active_shop["setting"] == "bar":
		print("making bar hitboxes")
		# character wireframe command
		tools.create_wireframe(Vector2(0, 360), Vector2(180, 200), "_on_drunk_clicked")
		tools.create_wireframe(Vector2(560, 290), Vector2(140, 150), "_on_dice_clicked")
		tools.create_wireframe(Vector2(860, 290), Vector2(140, 150), "_on_lady_clicked")

	
	tools.show_dialogue(2.0, "Welcome to the " + shop["setting"])
	

# Handler for hitbox_selected signal
func _on_hitbox_selected(function_name):
	if has_method(function_name):
		call_deferred(function_name)
	else:
		print("Method not found: ", function_name)

# Sleep function using a Timer node
func sleep(seconds: float) -> void:
	var timer = Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await(timer)
	timer.queue_free()


# Function to generate a shop structure based on predetermined settings
func generate_shop():
	# Define shop object
	var shop_structure = {
		"setting": "default",
		"exit_price": 200,
		"available_items": [],
		"prices": {"lucky_coin": 70, "gamer_glasses": 70, "smoked_sausage": 20, "bean": 400, "charm_bracelet": 35, "ace_up_sleeve": 50, "free_bev": 12}
	}

	# Randomly select a setting
	var settings = settings_to_backgrounds.keys()
	shop_structure["setting"] = settings[randi() % settings.size()]

	# Log the current setting
	print("Generated shop setting: " + shop_structure["setting"])

	# Randomly select available items, ensuring at least 2 items are available
	var selected_items = []
	var num_items = randi() % (items.size() - 1) + 2  # Ensure at least 2 items are selected
	while selected_items.size() < num_items:
		var item = items[randi() % items.size()]
		if item not in selected_items:
			selected_items.append(item)

	shop_structure["available_items"] = selected_items

	# Save the generated shop as the active shop
	var active_shop = shop_structure
	print("Shop structure generated and saved:", active_shop)
	return active_shop


func display_shop():
	if Money.active_shop == null:
		print("No active shop to display.")
		return

	# Set the background based on the shop's setting
	var background_path = settings_to_backgrounds.get(Money.active_shop["setting"], null)
	if background_path:
		set_animated_background(background_path)
	else:
		print("Warning: Background not found for setting", Money.active_shop["setting"])

	# Populate the shop with items
	clear_items()
	for i in range(Money.active_shop["available_items"].size()):
		var position
		if Money.active_shop["setting"] == "bar":
			position = Vector2(i * 80 + 200, 325)
		else:
			position = get_random_position_in_middle()
		add_item_to_shop(Money.active_shop["available_items"][i], position)

	# Show dialogue about the shop setting
	tools.show_dialogue(2.0, "Welcome to the " + Money.active_shop["setting"])
	print("Shop displayed.")


# Function to set an animated background
func set_animated_background(background_path: String):
	var animated_texture = tools.load_gif(background_path)
	if animated_texture:
		Background.texture = animated_texture
		Background.set_size(Vector2(get_viewport().size.x, get_viewport().size.y))
	else:
		print("Failed to load animated texture for path:", background_path)


func populate_shop():
	clear_items()
	for i in range(shop["available_items"].size()):
		#var position = get_random_position_in_middle()
		var position
		if shop["setting"] == "bar":
			position = Vector2(i*80 + 200, 325)
		else:
			position = get_random_position_in_middle()
		add_item_to_shop(shop["available_items"][i], position)

func get_random_position_in_middle():
	var screen_size = get_viewport_rect().size
	var x = randi() % int(screen_size.x * 0.6) + int(screen_size.x * 0.2)
	var y = randi() % int(screen_size.y * 0.6) + int(screen_size.y * 0.2)
	return Vector2(x, y)

# Function to add an item to the shop
func add_item_to_shop(item_name: String, position: Vector2):
	var item = TextureButton.new()
	item.texture_normal = load("res://images/Items/" + item_name + ".png")
	item.position = position
	item.name = item_name  # Set the item name for identification
	add_child(item)
	item.connect("pressed", Callable(self, "_on_item_pressed").bind(item_name))
	item_sprites.append(item)

# Function to clear existing items in the shop
func clear_items():
	for item in item_sprites:
		item.queue_free()
	item_sprites.clear()

func update_money_label():
	# Update the money label initially
	money_label.text = "Money: " + str(Money.get_money())
	update_inventory_display()  # Update inventory display when money label is updated

func update_inventory_display():
	# Clear existing inventory display
	for sprite in inventory_sprites:
		sprite.queue_free()
	inventory_sprites.clear()
	
	# Add initial inventory text
	inventory_label.text = "Inventory:"
	
	# Display each item as an image
	var x_offset = 50
	var y_offset = 610  # Adjust position as needed
	for item in Money.inventory:
		var item_sprite = Sprite2D.new()
		item_sprite.texture = load("res://images/Items/" + item + ".png")
		item_sprite.position = Vector2(x_offset, y_offset)
		add_child(item_sprite)
		inventory_sprites.append(item_sprite)
		x_offset += 60  # Adjust spacing as needed

func _on_ChangeSceneButton_pressed():
	print("Attempting to change to CASINO")
	var result = get_tree().change_scene_to_file("res://scenes/CASINO.tscn")
	if result != OK:
		print("Scene change failed with error code:", result)

func _on_BailoutButton_pressed():
	# Define the bailout logic here
	Money.update_money(13)

func _on_next_level_pressed():
	if(Money.active_shop["exit_price"] < Money.money):
		Money.update_money(-1 * Money.active_shop["exit_price"])
		Money.active_shop = null
		#Move to shop reset scene
		get_tree().change_scene_to_file("res://scenes/SHOP.tscn")
	else:
		print("You are too broke to continue...")

func _on_money_changed(new_money, new_inventory):
	# Update the money label when the signal is received
	money_label.text = "Money: " + str(new_money)
	update_inventory_display()  # Update inventory display when money or inventory changes

func _on_item_pressed(item_name):
	var price = shop["prices"].get(item_name, 70)
	if Money.money > price:
		print("Item pressed: " + item_name)
		Money.update_inventory(item_name, "add")
		Money.update_money(-1 * price)
		
		# Remove the item from the shop
		remove_item_from_shop(item_name)
	else:
		print("YOU'RE Broke")

func remove_item_from_shop(item_name: String):
	# Remove the item from the available_items list
	shop["available_items"].erase(item_name)
	
	# Find and remove the item sprite
	for sprite in item_sprites:
		if sprite.name == item_name:
			item_sprites.erase(sprite)
			sprite.queue_free()
			break



var drunk_click = 0

func _on_drunk_clicked():
	print("Clicked drunk!")
	if drunk_click < 4:
		tools.show_dialogue(1.5, "UGH... leave me alone")
	elif drunk_click < 7:
		tools.show_dialogue(1.5, "What can i do to get you to leave me alone?")
	elif drunk_click == 7:
		tools.show_dialogue(1.5, "Fine.... here you go.")
		Money.update_inventory("free_bev", "add")
		update_inventory_display()
	else:
		tools.show_dialogue(1.5, "Thats all i got buddy. zzzZZZ")
	drunk_click = drunk_click + 1

var dice_click = 0
var dice_instance
func _on_dice_clicked():
	print("Clicked dice!")

	if dice_instance:
		return


	if dice_click == 0:
		tools.show_dialogue(1.5, "Want to play Dice?")
		dice_click = dice_click+1
		var dtimer = Timer.new()
		dtimer.one_shot = true
		dtimer.wait_time = 2
		dtimer.connect("timeout", Callable(self, "_on_dtimer_timeout"))
		add_child(dtimer)
		dtimer.start()
	else:
		#call dice game
		if dice_instance:
			remove_child(dice_instance)
			dice_instance.queue_free()
			dice_instance = null
		var dice_scene = preload("res://scenes/Dice.tscn")
		if dice_scene:
			# Instance the scene properly
			dice_instance = dice_scene.instantiate()
			if dice_instance:
				add_child(dice_instance)
				# Adjust the position of the instance
				dice_instance.position = Vector2(300, 450)  # Adjust as needed
			else:
				print("Error: Failed to instance dice scene")
		else:
			print("Error: dice.tscn could not be loaded")
		
		
		drunk_click = 0


func _on_lady_clicked():
	print("Clicked lady!")
	tools.show_dialogue(1.5, "Hey there")

func _on_dtimer_timeout():
	print("dTimer expired!")
	dice_click = 0
