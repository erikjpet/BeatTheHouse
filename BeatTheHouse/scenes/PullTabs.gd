extends Node2D

var slot_values = ["bar", "barbar", "barbarbar", "7", "cherry", "bell"]  # Add more values as needed

var bet = 2
#size of card
var row = 5
var column = 3
#Sprites stored as sprite 
var sprites = []
var sprite_dict = {}  # Dictionary to store sprite references

func _ready():
	# Set initial positions of slot icons
	var sprite = Sprite2D.new()  # Create a new Sprite node
	sprite.texture = preload("res://images/PullTab.png")  # Set the texture
	sprite.position = Vector2(100, 160)  # Set the position
	add_child(sprite)  # Add the sprite as a child of the current node
	
	# Connect SpinButton press signal and position
	$SpinButton.connect("pressed", Callable(self, "_on_Button_pressed"))
	$SpinButton.position = Vector2(250, 0)   # Adjust X and Y positions as needed
	# Update initial slot visuals
	update_tab()

func _on_Button_pressed():
	if Money.money > bet-1:
		Money.update_money(-1 * bet)
		clear_sprites()
		pullTab()
	else:
		print("YOU'RE Broke")

func pullTab():
	
	sprites = []
	# Randomize the slot values
	for ro in range(row):
		for col in range(column):
			var slot_value = slot_values[randi() % slot_values.size()]
			var icon = Sprite2D.new()
			icon.texture = load("res://images/" + slot_value + ".png")
			icon.position = Vector2(24 + col * 76, ro * 76)
			sprites.append(icon)  # Store the sprite reference in array
			sprite_dict["icon_%d_%d" % [ro, col]] = icon
			add_child(icon)
		check_row(ro)
	
	

func update_tab():
	print("update")
	
func check_row(num):
	if num >= row:
		print("Row number out of range")
		return null

	# Get the texture of the first sprite in the row to compare with others
	var first_sprite = sprite_dict["icon_%d_%d" % [num, 0]]
	var first_texture = first_sprite.texture

	# Check if all sprites in the row have the same texture
	for col in range(1, column):
		var sprite = sprite_dict["icon_%d_%d" % [num, col]]
		if sprite.texture != first_texture:
			return null  # If any sprite doesn't match, return null
	var texture_path = first_texture.get_path()
	var texture_name = texture_path.get_file().get_basename()  # Get the file name without extension
	print("WIN!!! " + texture_name)
	if(texture_name == "7"):
		Money.update_money(7)
	if(texture_name == "cherry"):
		Money.update_money(1)
	if(texture_name == "barbarbar"):
		Money.update_money(5)
	if(texture_name == "barbar"):
		Money.update_money(4)
	if(texture_name == "bar"):
		Money.update_money(3)
	if(texture_name == "bell"):
		Money.update_money(2)
	
func clear_sprites():
	for sprite in sprites:
		sprite.queue_free()  # This will remove the node from the scene tree and free its memory
	sprites.clear()  # Clear the array to remove references
