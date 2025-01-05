# Money.gd
extends Node

# Singleton instance
var money_instance = null

# Shared money count variable
var money = 0
var inventory = []
var level = 0
var active_shop = null
var queued_shop = null

# Signal for money change
signal money_changed(new_money)

# Initialize singleton instance
func _ready():
	if money_instance == null:
		money_instance = self

# Function to add or subtract money
func update_money(amount):
	money += amount

	# Ensure money doesn't go below zero
	if money < 0:
		money = 0
	
	print(money)
	# Emit signal to notify money change
	emit_signal("money_changed", money, inventory)

func update_inventory(item, action):
	if action == "add":
		print("Adding: " + item)
		inventory.append(item)
	elif action == "rem":
		print("Adding: " + item)
		inventory.append(item)
	else:
		print("No action")
		

# Function to get current money count
func get_money():
	return money

