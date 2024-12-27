extends Node2D

# Game Selection
var selected_tab_index = -1
var tab_buttons = []

# Label for displaying money count
var money_label

# Declare variable for Game instances
var slot_machine_instance
var pull_tabs_instance
var blackjack_instance
var dice_instance

func _ready():
	# Setting background node to fill entire screen
	var Background = $Background
	Background.stretch_mode = TextureRect.STRETCH_TILE
	
	# Set button location and connect to press function
	$ChangeSceneButton.position = Vector2(20, 20)
	$ChangeSceneButton.connect("pressed", Callable(self, "_on_ChangeSceneButton_pressed"))
	
	# Display money count
	money_label = Label.new()
	money_label.text = "Money: " + str(Money.money)
	money_label.position = Vector2(20, 60)  # Adjust position as needed
	add_child(money_label)


	# Game selection tabs
	add_tab("Bar-Slots")
	add_tab("Pull-Tabs")
	add_tab("Blackjack")
	add_tab("Dice")
	
	# Select the initial tab
	select_tab(0)
	
	Money.connect("money_changed", Callable(self, "_on_money_changed"))

func _on_ChangeSceneButton_pressed():
	get_tree().change_scene_to_file("res://scenes/SHOP.tscn")

# Whenever a tab button is pressed
func _on_tab_button_pressed(button):
	# Get the index of the button that was pressed
	var index = tab_buttons.find(button)

	# Deselect the currently selected tab
	if selected_tab_index >= 0 and selected_tab_index < tab_buttons.size():
		deselect_tab(selected_tab_index)

	# Select the new tab
	select_tab(index)

# Function to select new game tab
func select_tab(index):
	# Set the selected tab
	selected_tab_index = index
	if selected_tab_index >= 0 and selected_tab_index < tab_buttons.size():
		var selected_button = tab_buttons[selected_tab_index]
		selected_button.modulate = Color(1, 1, 0)  # Change color to yellow

	# Implement logic to show content based on the selected tab
	match index:
		0:
			load_slot_machine()
		1:
			load_pull_tabs()
		2:
			load_blackjack()
		3:
			load_dice()
		_:
			clear_current_game()

# Function to deselect current game tab
func deselect_tab(tab_index):
	if tab_index >= 0 and tab_index < tab_buttons.size():
		var button = tab_buttons[tab_index]
		button.modulate = Color(1, 1, 1)  # Change color to white

# Function to add a game tab to the header selection
func add_tab(tab_name):
	var new_button = Button.new()
	new_button.text = tab_name
	new_button.position = Vector2(600 + 100 * tab_buttons.size(), 20)  # Adjust position as needed
	add_child(new_button)

	# Connect the new button to the tab selection function
	new_button.connect("pressed", Callable(self, "_on_tab_button_pressed").bind(new_button))
	
	# Add the new button to the list of tab buttons
	tab_buttons.append(new_button)

func load_slot_machine():
	# Clear previous content
	clear_current_game()

	# Preload the SlotMachine scene
	var slot_machine_scene = preload("res://scenes/SlotMachine.tscn")
	if slot_machine_scene:
		# Instance the scene properly
		slot_machine_instance = slot_machine_scene.instantiate()
		if slot_machine_instance:
			add_child(slot_machine_instance)

			# Adjust the position of the slot machine instance
			slot_machine_instance.position = Vector2(200, 200)  # Adjust as needed
		else:
			print("Error: Failed to instance SlotMachine scene")
	else:
		print("Error: SlotMachine.tscn could not be loaded")

func load_pull_tabs():
	print("loading pullTABS")
	# Clear previous content
	clear_current_game()

	# Preload the SlotMachine scene
	var pull_tabs_scene = preload("res://scenes/PullTabs.tscn")
	if pull_tabs_scene:
		# Instance the scene properly
		pull_tabs_instance = pull_tabs_scene.instantiate()
		if pull_tabs_instance:
			add_child(pull_tabs_instance)

			# Adjust the position of the slot machine instance
			pull_tabs_instance.position = Vector2(200, 200)  # Adjust as needed
		else:
			print("Error: Failed to instance PullTabs scene")
	else:
		print("Error: PullTabs.tscn could not be loaded")


func load_blackjack():
	print("loading Blackjack")
	# Clear previous content
	clear_current_game()

	# Preload the SlotMachine scene
	var blackjack_scene = preload("res://scenes/Blackjack.tscn")
	if blackjack_scene:
		# Instance the scene properly
		blackjack_instance = blackjack_scene.instantiate()
		if blackjack_instance:
			add_child(blackjack_instance)

			# Adjust the position of the slot machine instance
			blackjack_instance.position = Vector2(200, 200)  # Adjust as needed
		else:
			print("Error: Failed to instance blackjack scene")
	else:
		print("Error: blackjack.tscn could not be loaded")

func load_dice():
	print("loading dice")
	# Clear previous content
	clear_current_game()

	# Preload the SlotMachine scene
	var dice_scene = preload("res://scenes/Dice.tscn")
	if dice_scene:
		# Instance the scene properly
		dice_instance = dice_scene.instantiate()
		if dice_instance:
			add_child(dice_instance)

			# Adjust the position of the slot machine instance
			dice_instance.position = Vector2(200, 200)  # Adjust as needed
		else:
			print("Error: Failed to instance dice scene")
	else:
		print("Error: dice.tscn could not be loaded")

func clear_current_game():
	if slot_machine_instance:
		remove_child(slot_machine_instance)
		slot_machine_instance.queue_free()
		slot_machine_instance = null
	if pull_tabs_instance:
		remove_child(pull_tabs_instance)
		pull_tabs_instance.queue_free()
		pull_tabs_instance = null
	if blackjack_instance:
		remove_child(blackjack_instance)
		blackjack_instance.queue_free()
		blackjack_instance = null
	if dice_instance:
		remove_child(dice_instance)
		dice_instance.queue_free()
		dice_instance = null

func _on_money_changed(new_money, inventory):
	# Update the money label when the signal is received
	money_label.text = "Money: " + str(new_money)
	
	if new_money == 0:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
