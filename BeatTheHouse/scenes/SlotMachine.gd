extends Node2D

var slot_values = ["bar", "barbar", "barbarbar", "7", "cherry", "bell"]  # Add more values as needed

var bet_amount = 1

func item_mods():
	if "lucky_coin" in Money.inventory:
		slot_values.append("7")

func _ready():
	item_mods()
	# Set initial positions of slot icons
	$Slot1.position = Vector2(-80, 0)  # Adjust X and Y positions as needed
	$Slot2.position = Vector2(0, 0)    # Adjust X and Y positions as needed
	$Slot3.position = Vector2(80, 0)   # Adjust X and Y positions as needed
	$Frame1.position = Vector2(-80, 0)  # Adjust X and Y positions as needed
	$Frame2.position = Vector2(0, 0)    # Adjust X and Y positions as needed
	$Frame3.position = Vector2(80, 0)   # Adjust X and Y positions as needed
	
	# Connect SpinButton press signal and position
	$SpinButton.connect("pressed", Callable(self, "_on_SpinButton_pressed"))
	$SpinButton.position = Vector2(0, 100)   # Adjust X and Y positions as needed
	# Update initial slot visuals
	update_slots()

func _on_SpinButton_pressed():
	if Money.money > 0:
		Money.update_money(-1)
		spin_slots()
	else:
		print("YOU'RE Broke")

func spin_slots():
	# Randomize the slot values
	var slot1_value = slot_values[randi() % slot_values.size()]
	var slot2_value = slot_values[randi() % slot_values.size()]
	var slot3_value = slot_values[randi() % slot_values.size()]
	
	# Update the slot sprites
	$Slot1.texture = load("res://images/" + slot1_value + ".png")
	$Slot2.texture = load("res://images/" + slot2_value + ".png")
	$Slot3.texture = load("res://images/" + slot3_value + ".png")
	
	if slot1_value == slot3_value && slot2_value == slot3_value:
		print("WIN!!! " + slot1_value)
		if(slot1_value == "7"):
			Money.update_money(70)
		if(slot1_value == "cherry"):
			Money.update_money(1)
		if(slot1_value == "barbarbar"):
			Money.update_money(5)
		if(slot1_value == "barbar"):
			Money.update_money(4)
		if(slot1_value == "bar"):
			Money.update_money(3)
		if(slot1_value == "bell"):
			Money.update_money(2)

func update_slots():
	# Set initial slot values
	$Slot1.texture = load("res://images/bar.png")
	$Slot2.texture = load("res://images/7.png")
	$Slot3.texture = load("res://images/cherry.png")
	
