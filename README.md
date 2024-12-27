# BeatTheHouse

 Beat the House
DESIGN DOCUMENT
By Erik


Introduction	2
Game Summary	2
Inspiration	2
Player Experience	2
Platform	3
Development Software	3
Genre	3
Concept	3
Gameplay overview	3
Theme Interpretation (Sacrifice Is Strength)	4
Primary Mechanics	4
Secondary Mechanics	5
Art	6
Theme Interpretation	6
Design	6
Audio	7
Music	7
Sound Effects	7
Game Experience	7
UI	7
Controls	7
Development Timeline	8
Beat the house
LOGO
Introduction
Game Summary Pitch
Beat the House is a roguelike casino/puzzle game about earning money in the casino to buy house advantages.  The player must also avoid getting caught cheating by the casino. 

Goals:
Each level consists of a unique casino and shop. You can purchase temp upgrades, perm upgrades or the main goal of traveling to the next destination.
Inspiration
Balatro
Balatro is the inspiration for the main control & menu system of the game. As well as the art style being what the best case scenario would resemble. All user control will be menu based and side menu’s will contain information about the current status of the Day/Level.

The poker gameplay will likely be used as a base for the poker sub-game.

Binding of Issac
The base roguelike idea of binding of isaac is the goal for this type of game, with locations in the game relating to floors. However the way to exit a floor won't always be a boss like BOI, sometimes it will be retrieving a specific item or likely purchasing transportation to the next location.


Player Experience
The player starts at a bar, discussing with a shop owner. The player then enters the first casino, with the goal of earning enough money to be able to afford their first item. At any time in the casino the player can walk away  with their current balance and immediately go to the shop. Ending the current day.

Platform
The game is developed to be released on windows PC via steam
	
Development Software
GODOT 2d engine.
Aseprite for graphics and UI

Genre
Singleplayer, puzzle, casual




Concept
Gameplay overview
There are two main gameplay parts:

SHOP:
The player is presented with a number of items in a unique environment. Each item may be one of 3 groups: permanent - keep entire game, temp - removed at next travel. There is also an option to purchase (or unlock with item) the ability to move on to the next level.

CASINO:
The time in the casino section is limited to a DAY (timer).  The player has several options of game they can play depending on the 
Environment they are in. (For example, bar level may have slot machine, bar dice, or pull tabs; meanwhile a low tier casino may have slots, video poker, video roulette, blackjack). The player enters the casino and initially chooses a game. The game can be changed at any time before the end of the day. Each game has unique mechanics and can be affected independently or completely by an item depending on its ability. CHIPS are in effect, cannot use chips at slots.



Player starts in shop:
	Meets X person who tells them about shop and gives STARTING ITEM sends you off to casino with ONLY starting item

First casino is bar games:
Slots
Pull tabs
Dice

	First Milestone $50
	
	second Casino - backroom
Blackjack
Hold em
Dice

	Second milestone - $200










Casino Mechanics

Mechanic
Other info
        Slots         a






        Spikes        a


When a player cell walks on top of a spike, that cell will die and further simplify the player mass.

        Holes       a


The player mass can walk freely over a hole as long as at least one cell is on a floor tile. If the entire mass is over the hole, the entire player mass dies.

        Fruit       a


If a player cell moves over a fruit, it will eat the fruit and generate a new cell on the opposite side of the mass it is a part of.


	
Shop/Item Mechanics

Mechanic
Other info
        Item Types        a


Each item will be one of several types:
Temp - removed at next travel
Perm - keep entire game
Contraband - Perm, but removed at specific travel points 


        Set Spikes        a


When a player cell walks on top of a set spike, after moving off of it, it will then become a regular spike trap



Art
Design
A very minimalistic approach will initially go into the design of the game, attempting to use pixel art to keep things reproducible.

Audio
Music
Par’s brain-child
Until then free/online/tmp assets
Sound Effects
todo

Game Experience
UI
The menu UI will remain pixel art, however the goal is to not lock items to a grid but have the pixel art items to be floating in free space.
Controls
MOUSE ONLY
Want the game to be able to easily be ported to mobile

Development Timeline

MINIMUM VIABLE PRODUCT

#
Assignment
Type
Status
Notes
1
Design Document
 Other
 In progress


2
Create shell project
 Coding
 Not started


3


 Coding
 Not started


4
Implement money storage
 Coding
 Not started


5
Implement initial shop menu
 Coding
 Not started


6
Temp display/art of bar slot machine game
 Coding
 Not started


7
Create initial bar slot machine “game” logic
 Coding
 Not started


8


 Other
 Not started


9


 Other
 Not started


10


 Other
 Not started


11


 Other
 Not started


12


 Other
 Not started


13


 Other
 Not started


14


 Other
 Not started


15


 Other
 Not started


16


 Other
 Not started


17


 Other
 Not started


18


 Other
 Not started




BEYOND (if ahead of schedule / extra time)



 Other
 Not started




 Other
 Not started


Settings Menu
 Coding
 Not started




