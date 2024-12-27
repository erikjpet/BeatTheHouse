extends Node2D

var bet = 5

# Sprites stored as sprite 
var sprites = []
var sprite_dict = {}  # Dictionary to store sprite references

var player_roll = [0, 0, 0, 0, 0]
var savelog = [0, 0, 0, 0, 0]
var dealer_roll = [0, 0, 0, 0, 0, 0]
var pscore = 0
var dscore = 0

var rem_rolls = 3

var roll_options = [1, 2, 3, 4, 5, 6]

# Preload textures
var lock = preload("res://images/Lock.png")
var unlock = preload("res://images/Unlock.png")

# Button references
var rollButton
var button1
var button2
var button3
var button4
var button5

var pscore_label
var dscore_label

func _ready():
	print("test")
	rollButton = Button.new()
	rollButton.text = "Bet"
	rollButton.position = Vector2(0, 0)  # Adjust position as needed
	add_child(rollButton)
	rollButton.connect("pressed", Callable(self, "_on_rollButton_pressed"))

func create_score_label():	# Display score details
	pscore_label = Label.new()
	pscore_label.name = "pscore_label"
	pscore_label.position = Vector2(160, 40)
	add_child(pscore_label)
	
	dscore_label = Label.new()
	dscore_label.name = "dscore_label"
	dscore_label.position = Vector2(260, 40)
	add_child(dscore_label)

func create_saveBtn():
	# Add "Button 1"
	button1 = TextureButton.new()
	button1.texture_normal = unlock
	button1.position = Vector2(0, 100)  # Adjust position as needed
	add_child(button1)
	button1.connect("pressed", Callable(self, "_on_button_pressed").bind(button1, 1))

	# Add "Button 2"
	button2 = TextureButton.new()
	button2.texture_normal = unlock
	button2.position = Vector2(60, 100)  # Adjust position as needed
	add_child(button2)
	button2.connect("pressed", Callable(self, "_on_button_pressed").bind(button2, 2))

	# Add "Button 3"
	button3 = TextureButton.new()
	button3.texture_normal = unlock
	button3.position = Vector2(120, 100)  # Adjust position as needed
	add_child(button3)
	button3.connect("pressed", Callable(self, "_on_button_pressed").bind(button3, 3))

	# Add "Button 4"
	button4 = TextureButton.new()
	button4.texture_normal = unlock
	button4.position = Vector2(180, 100)  # Adjust position as needed
	add_child(button4)
	button4.connect("pressed", Callable(self, "_on_button_pressed").bind(button4, 4))

	# Add "Button 5"
	button5 = TextureButton.new()
	button5.texture_normal = unlock
	button5.position = Vector2(240, 100)  # Adjust position as needed
	add_child(button5)
	button5.connect("pressed", Callable(self, "_on_button_pressed").bind(button5, 5))
	
	create_score_label()

func _on_rollButton_pressed():
	if rem_rolls > 0:
		print("REMROLLS:" + str(rem_rolls))
		rem_rolls = rem_rolls - 1
		rollButton.text = "Roll"
	else:
		if rollButton.text == "Bet":
			clear_dice()
	
	if button1 == null:
		create_saveBtn()
		
	Roll()

func getRandomRoll():
	# Get a random roll from the options
	return roll_options[randi() % roll_options.size()]

func Roll():
	if rollButton.text == "Bet":
		if Money.get_money() >= bet:
			Money.update_money(-bet)
			clear_dice()
		else:
			print("You're broke!")
			return
		
	clear_unlocked_dice()
	for i in range(5):
		if savelog[i] == 0:
			var rroll = getRandomRoll()
			player_roll[i] = rroll
			var rollDice = Sprite2D.new()
			rollDice.texture = load("res://images/Dice/" + str(rroll) + ".png")
			rollDice.position = Vector2(i * 60 + 30, 80)  # Adjust position as needed
			add_child(rollDice)
			sprites.append(rollDice)
		else:
			var rollDice = Sprite2D.new()
			rollDice.texture = load("res://images/Dice/" + str(player_roll[i]) + ".png")
			rollDice.position = Vector2(i * 60 + 30, 80)  # Adjust position as needed
			add_child(rollDice)
			sprites.append(rollDice)
	print(player_roll)
	var score = calculate_score(player_roll)
	if rem_rolls == 0:
		finish_game(score)

func _on_button_pressed(button, num):
	if button.texture_normal == lock:
		button.texture_normal = unlock
		savelog[num - 1] = 0
	elif button.texture_normal == unlock:
		button.texture_normal = lock
		savelog[num - 1] = 1

func clear_unlocked_dice():
	var new_sprites = []
	for i in range(savelog.size()):
		if savelog[i] == 0 and i < sprites.size():
			sprites[i].queue_free()
		else:
			if i < sprites.size():
				new_sprites.append(sprites[i])
	sprites = new_sprites


func clear_sprites():
	for sprite in sprites:
		sprite.queue_free()  # This will remove the node from the scene tree and free its memory
	sprites.clear()  # Clear the array to remove references

func finish_game(score):
	print("finishing game with score: " + str(score))
	for i in range(6):
		var droll = getRandomRoll()
		dealer_roll[i] = droll
		var rollDice = Sprite2D.new()
		rollDice.texture = load("res://images/Dice/" + str(droll) + ".png")
		rollDice.position = Vector2(i * 60 + 360, 80)  # Adjust position as needed
		add_child(rollDice)
		sprites.append(rollDice)
	print(dealer_roll)
	dscore = calculate_score(dealer_roll)
	
	if score > dscore:
		print("PLAYER WINS: " + str(bet*2))
		Money.update_money(bet*2)
	elif score == dscore:
		print("PLAYER PUSHES")
		Money.update_money(bet)
	else:
		print("PLAYER LOSES")
	rollButton.text = "Bet"
	
	

func calculate_score(rawHand: Array) -> int:
	var hand = rawHand
	
	# Initialize variables for scoring categories
	var possible_scores = []
	var counts = [0, 0, 0, 0, 0, 0]  # Count occurrences of each dice value
	var dice_sum = 0
	
	# Count occurrences of each dice value
	for die_value in hand:
		counts[die_value - 1] += 1
		dice_sum = dice_sum + die_value
	
	# Check for Three of a Kind
	for i in range(6):
		if counts[i] >= 3:
			possible_scores.append("3ofkind")
			print("3 of a Kind")
			break
	
	# Check for Four of a Kind
	for i in range(6):
		if counts[i] >= 4:
			possible_scores.append("4ofkind")
			print("4 of a Kind")
			break
	
	# Check for Full House
	var has_two = false
	var has_three = false
	for count in counts:
		if count == 2:
			has_two = true
		elif count == 3:
			has_three = true
	if has_two and has_three:
		possible_scores.append("fh")
		print("Full House")
	
	# Check for Small Straight (4 in a row)
	if (1 in hand and 2 in hand and 3 in hand and 4 in hand) or \
	   (2 in hand and 3 in hand and 4 in hand and 5 in hand) or \
	   (3 in hand and 4 in hand and 5 in hand and 6 in hand):
		possible_scores.append("smst")
		print("Small Straight")
	
	# Check for Large Straight (5 in a row)
	if (1 in hand and 2 in hand and 3 in hand and 4 in hand and 5 in hand) or \
	   (2 in hand and 3 in hand and 4 in hand and 5 in hand and 6 in hand):
		possible_scores.append("lgst")
		print("Large Straight")
	
	# Check for Yahtzee (all dice same)
	if counts.count(5) > 0:
		possible_scores.append("yz")
		print("Yahtzee")
	
	# Add the highest pair or highest single value if no specific category is found
	var highest_pair_sum = 0
	for i in range(6):
		if counts[i] >= 2:
			var pair_sum = (i + 1) * 2
			if pair_sum > highest_pair_sum:
				highest_pair_sum = pair_sum
	
	if highest_pair_sum > 0:
		possible_scores.append("p")
		print("Highest Pair")
	
	
	# If no pairs found, use the highest single value
	var highest_single_value = 0
	for i in range(6):
		if counts[i] > 0:
			highest_single_value = max(highest_single_value, (i + 1))
	possible_scores.append("hi")
	print("Highest Single Value")

	#assign values to every score
	var possible_vals = []
	for score in possible_scores:
		if score == "hi":
			possible_vals.append(highest_single_value)
		elif score == "p":
			possible_vals.append(highest_pair_sum)
		elif score == "3ofkind":
			possible_vals.append(dice_sum)
		elif score == "4ofkind":
			var FOKadd = 10
			possible_vals.append(dice_sum + FOKadd)
		elif score == "yz":
			possible_vals.append(50)
		elif score == "fh":
			possible_vals.append(25)
		elif score == "smst":
			possible_vals.append(30)
		elif score == "lgst":
			possible_vals.append(40)
	
	
	# Find the highest possible score
	var final_score = -1
	var f_score_name
	# Find the highest possible score and corresponding category name
	var final_score_index = -1
	for i in range(possible_vals.size()):
		if possible_vals[i] > final_score:
			final_score = possible_vals[i]
			final_score_index = i
	var highest_score_name = ""
	if final_score_index != -1:
		highest_score_name = possible_scores[final_score_index]
	
	if hand == player_roll:
		#set player score label
		pscore_label.text = highest_score_name + " - " + str(final_score) 
	if hand == dealer_roll:
		#set player score label
		dscore_label.text = highest_score_name + " - " + str(final_score)
	
	print("Final Score:", final_score)
	return final_score


func sum_array(hand: Array) -> int:
	var total_sum = 0
	for value in hand:
		total_sum += value
	return total_sum
	
func clear_dice():
	for sprite in sprites:
		sprite.queue_free()  # This will remove the node from the scene tree and free its memory
	sprites.clear()  # Clear the array to remove references
	sprite_dict.clear()  # Clear the dictionary
	
	player_roll = [0, 0, 0, 0, 0]
	savelog = [0, 0, 0, 0, 0]
	dealer_roll = [0, 0, 0, 0, 0, 0]
	pscore = 0
	dscore = 0
	rem_rolls = 3
	
	pscore_label.text = ""
	dscore_label.text = ""

