# File: blackjack.gd

extends Node2D

var bet = 5

# Sprites stored as sprite 
var sprites = []
var sprite_dict = {}  # Dictionary to store sprite references

var player_hand = []
var dealer_hand = []
var pscore = 0
var dscore = 0

var suits = ["Hearts", "Diamond", "Clubs", "Spades"]
var values = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"]
var deck = []
var saved_deck = []

# Button references
var button1
var button2
var button3

# Text labels
var player_count
var dealer_count
var card_count
var count = 0


var back_card = load("res://images/Cards Pack/Back Blue 2.png")


func item_mods():
	if "gamer_glasses" in Money.inventory:
		#add card count label
		# Display money count
		card_count = Label.new()
		card_count.name = "card_count"
		card_count.position = Vector2(-20, 120)
		add_child(card_count)

func _ready():
	item_mods()
	# Set initial positions of slot icons
	var sprite = Sprite2D.new()  # Create a new Sprite node
	sprite.texture = preload("res://images/5chip.png")  # Set the texture
	sprite.position = Vector2(100, 160)  # Set the position
	add_child(sprite)  # Add the sprite as a child of the current node

	# Add "Button 1"
	button1 = Button.new()
	button1.text = "Deal"
	button1.position = Vector2(250, 0)  # Adjust position as needed
	add_child(button1)
	button1.connect("pressed", Callable(self, "_on_button1_pressed"))

	# Add "Button 2"
	button2 = Button.new()
	button2.text = "Increase Bet"
	button2.position = Vector2(250, 40)  # Adjust position as needed
	add_child(button2)
	button2.connect("pressed", Callable(self, "_on_button2_pressed"))

	# Add "Button 3"
	button3 = Button.new()
	button3.text = "Decrease Bet"
	button3.position = Vector2(250, 80)  # Adjust position as needed
	add_child(button3)
	button3.connect("pressed", Callable(self, "_on_button3_pressed"))
	
	make_deck()
	saved_deck = deck

func _on_button1_pressed():
	if button1.text == "Deal":
		if Money.get_money() >= bet:
			Money.update_money(-bet)
			clear_sprites()
			dealCards()
			clearCountLabels()
			makeCountLabels()
		else:
			print("You're broke!")	
	elif button1.text == "Hit":
		var hcard = getRandomCard()
		var hitcard = Sprite2D.new()
		player_hand.append(hcard)
		hitcard.texture = load("res://images/Cards Pack/" + hcard + ".png")
		hitcard.position = Vector2(player_hand.size() * -20 + 120, 80)  # Adjust position as needed
		add_child(hitcard)
		sprites.append(hitcard)
		
		calc_score()
		updateCountLabels()

func makeCountLabels():
	# Display money count
	player_count = Label.new()
	player_count.name = "player_count"
	player_count.position = Vector2(160, 40)
	add_child(player_count)
	
	# Display money count
	dealer_count = Label.new()
	dealer_count.name = "dealer_count"
	dealer_count.position = Vector2(160, 20)
	add_child(dealer_count)
	
	updateCountLabels()

func updateCountLabels():
	player_count.text = "Player: " + str(pscore)
	dealer_count.text = "Dealer: " + str(dscore)
	
func clearCountLabels():
	if player_count:
		player_count.text = ""
	if dealer_count:
		dealer_count.text = ""

func _on_button2_pressed():
	if button2.text == "Increase Bet":
		if bet+1 > Money.get_money():
			bet = Money.get_money()
		else:
			bet += 1
			print("Bet increased to: ", bet)

	if button2.text == "Stand":
		finalize_game()

func _on_button3_pressed():
	if button3.text == "Decrease Bet":
		if bet > 5:
			bet -= 1
			print("Bet decreased to: ", bet)
		else:
			print("Bet cannot go below 5!")

func dealCards():
	clear_sprites()
	# Deal two random cards
	var pcard1 = getRandomCard()
	var pcard2 = getRandomCard()
	var dcard1 = getRandomCard()
	var dcard2 = getRandomCard()

	# Create sprites for the player cards
	var player1 = Sprite2D.new()
	player1.texture = load("res://images/Cards Pack/" + pcard1 + ".png")
	player1.position = Vector2(80, 80)  # Adjust position as needed
	add_child(player1)
	sprites.append(player1)

	var player2 = Sprite2D.new()
	player2.texture = load("res://images/Cards Pack/" + pcard2 + ".png")
	player2.position = Vector2(130, 80)  # Adjust position as needed
	add_child(player2)
	sprites.append(player2)
	
	player_hand.append(pcard1)
	player_hand.append(pcard2)
	dealer_hand.append(dcard1)
	dealer_hand.append(dcard2)
	
	# Create sprites for the dealer cards
	var dealer1 = Sprite2D.new()
	dealer1.texture = load("res://images/Cards Pack/" + dcard1 + ".png")
	dealer1.position = Vector2(80, 0)  # Adjust position as needed
	add_child(dealer1)
	sprites.append(dealer1)

	var dealer2 = Sprite2D.new()
	dealer2.texture = back_card
	dealer2.position = Vector2(130, 0)  # Adjust position as needed
	add_child(dealer2)
	sprites.append(dealer2)
	sprite_dict["dealer2"] = dealer2
	
	# Example usage:
	update_button_texts("Hit", "Stand", "-")
	calc_score()
	
func getRandomCard():
	# Get a random card from the deck
	if deck.size() == 0:
		print("The deck is empty! shuffling.")
		make_deck()
	
	# Get a random index
	var random_index = randi() % deck.size()
	# Get the card at the random index
	var new_card = deck[random_index] 
	# Remove the chosen card from the deck
	deck.remove_at(random_index)
	
	if "gamer_glasses" in Money.inventory:
		#logic for card counting
		var parts = new_card.split(" ")
		var val = parts[1].to_int()
		if val > 9 || val == 1:
			count = count - 1
		if  val < 7 && val > 1:
			count = count + 1
		card_count.text = "Count: " + str(count)
	
	return new_card

func clear_sprites():
	for sprite in sprites:
		sprite.queue_free()  # This will remove the node from the scene tree and free its memory
	sprites.clear()  # Clear the array to remove references
	sprite_dict.clear()  # Clear the dictionary
	
	pscore = 0
	dscore = 0
	player_hand = []
	dealer_hand = []
	
	
func make_deck():
	for suit in suits:
		for value in values:
			var card = "%s %s" % [suit, value]
			deck.append(card)

# Function to update button texts
func update_button_texts(text1: String, text2: String, text3: String):
	button1.text = text1
	button2.text = text2
	button3.text = text3
	
func calc_score():
	var ace = false
	pscore = 0
	dscore = 0
	# CALC player score
	for card in player_hand:
		var parts = card.split(" ")
		var val = parts[1].to_int()
		if val > 10:
			val = 10
		if val == 1:
			ace = true
		pscore = pscore + val
		print(pscore)
	if ace and pscore < 12:
		pscore = pscore + 10
	print("player score: " + str(pscore))
	ace = false
	
	# CALC dealer score
	for card in dealer_hand:
		var parts = card.split(" ")
		var val = parts[1].to_int()
		if val > 10:
			val = 10
		if val == 1:
			ace = true
		dscore = dscore + val
	if ace and dscore < 12:
		dscore = dscore + 10
	print("dealer score: " + str(dscore))
	
	# If dealer isn't showing second card yet
	if sprite_dict["dealer2"].texture == back_card:
		var parts = dealer_hand[0].split(" ")
		var val = parts[1].to_int()
		if val > 10:
			val = 10
		if val == 1:
			val = 11
		dscore = val
		
	if pscore > 21:
		finalize_game()
	
func finalize_game():
	
	sprite_dict["dealer2"].texture = load("res://images/Cards Pack/" +dealer_hand[1]+ ".png")
	
	while dscore < 17:
		var hcard = getRandomCard()
		var hitcard = Sprite2D.new()
		dealer_hand.append(hcard)
		hitcard.texture = load("res://images/Cards Pack/" + hcard + ".png")
		hitcard.position = Vector2(dealer_hand.size() * -20 + 120, 0)  # Adjust position as needed
		add_child(hitcard)
		sprites.append(hitcard)
		sprite_dict["dealer_card" + str(dealer_hand.size())] = hitcard
		
		calc_score()
	if pscore > 21:
		print("YOU LOSE")
	elif dscore > 21:
		print("YOU WIN")
		Money.update_money(bet*2)
	elif pscore > dscore:
		print("YOU WIN")
		Money.update_money(bet*2)
	elif pscore == dscore:
		print("YOU PUSH")
		Money.update_money(bet)
	else:
		print("YOU LOSE")
	
	updateCountLabels()
	update_button_texts("Deal", "Increase Bet", "Decrease Bet")
