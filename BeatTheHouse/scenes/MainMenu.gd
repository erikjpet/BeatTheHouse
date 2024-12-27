# File: MainMenu.gd

extends Node2D

var play_button
var settings_button
var inventory_button

func _ready():
	# Create and set up the background
	var background = TextureRect.new()
	var background_texture = load("res://images/BGtile.png")
	if background_texture:
		background.texture = background_texture
		background.stretch_mode = TextureRect.STRETCH_TILE
		add_child(background)
	else:
		print("Error: Failed to load background texture")

	# Create and set up the game icon

	var game_icon = TextureButton.new()
	var game_icon_texture = load("res://images/menu/GameIcon.png")
	if game_icon_texture:
		game_icon.texture_normal = game_icon_texture
		game_icon.position = Vector2(500, 150)
		add_child(game_icon)
	else:
		print("Error: Failed to load game icon texture")

	# Create and set up the play button
	var play_icon = TextureButton.new()
	var play_icon_texture = load("res://images/menu/PlayBtn.png")
	if play_icon_texture:
		play_icon.texture_normal = play_icon_texture
		play_icon.position = Vector2(400, 300)
		play_icon.connect("pressed", Callable(self, "_on_PlayButton_pressed"))
		add_child(play_icon)
	else:
		print("Error: Failed to load play button texture")

	# Create and set up the settings button
	settings_button = TextureButton.new()
	var settings_button_texture = load("res://images/menu/SettingsBtn.png")
	if settings_button_texture:
		settings_button.texture_normal = settings_button_texture
		settings_button.position = Vector2(500, 300)
		settings_button.connect("pressed", Callable(self, "_on_SettingsButton_pressed"))
		add_child(settings_button)
	else:
		print("Error: Failed to load settings button texture")

	# Create and set up the inventory button
	inventory_button = TextureButton.new()
	var inventory_button_texture = load("res://images/menu/InventoryBtn.png")
	if inventory_button_texture:
		inventory_button.texture_normal = inventory_button_texture
		inventory_button.position = Vector2(600, 300)
		inventory_button.connect("pressed", Callable(self, "_on_InventoryButton_pressed"))
		add_child(inventory_button)
	else:
		print("Error: Failed to load inventory button texture")

func _on_PlayButton_pressed():
	Money.money = 18
	Money.inventory = []
	get_tree().change_scene_to_file("res://scenes/SHOP.tscn")

func _on_SettingsButton_pressed():
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")
	print("Settings Button Pressed")  # Placeholder for settings logic

func _on_InventoryButton_pressed():
	print("Inventory Button Pressed")  # Placeholder for inventory logic
