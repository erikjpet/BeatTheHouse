# BeatTheHouse Newcomer Guide

This is a quick orientation guide for engineers opening this repository for the first time.

## 1) What this project is

BeatTheHouse is a Godot 4.2 2D game project centered around a casino loop:

1. Start from a menu.
2. Enter a **Shop** where you buy upgrades and move to the next location.
3. Enter a **Casino** where you play mini-games to earn money.
4. Return to the shop and repeat.

The main scene is `MainMenu.tscn`, and global game state is managed via autoload singletons.

## 2) High-level folder structure

- `BeatTheHouse/project.godot`
  - Core Godot project config, run scene, and autoloaded scripts.
- `BeatTheHouse/scenes/`
  - Scene files (`.tscn`) plus scene controllers (`.gd`) for menu, shop, casino, and mini-games.
- `BeatTheHouse/images/`
  - Art assets for UI, mini-games, cards, dice, items, and animated backgrounds.
- `BeatTheHouse/addons/godotgif/`
  - GIF extension used to render animated background assets.
- `README.md`
  - Design-document style notes and gameplay goals.

## 3) Runtime architecture you should know first

### Global state (`Money.gd` autoload)

`Money.gd` is the single shared state store and event source. It currently owns:

- `money`
- `inventory`
- `level`
- `active_shop`
- `queued_shop`

and emits `money_changed` when money is updated.

Most scenes read from this singleton directly and react to `money_changed` for UI updates.

### Utility singleton (`tools.gd` autoload)

`tools.gd` provides cross-scene helpers:

- showing timed dialogue popups;
- creating invisible clickable wireframes/hitboxes;
- loading animated GIF textures.

Shop and settings rely heavily on this helper for UI behavior.

## 4) Scene flow and ownership

### Main menu

`scenes/MainMenu.gd` builds a menu in code, resets run state (`money`, `inventory`) when Play is pressed, then moves to `SHOP.tscn`.

### Shop

`scenes/SHOP.gd` is the progression hub:

- Generates and persists current/next shop structures via `Money.active_shop` / `Money.queued_shop`.
- Displays purchasable items and prices.
- Handles inventory rendering.
- Lets players move to casino or pay an exit price to travel to next level.
- Includes map-specific interactive NPC hitboxes in the bar setting.

### Casino container

`scenes/CASINO.gd` is a tabbed loader scene:

- Builds top tabs for each mini-game.
- Instantiates exactly one game scene at a time (slots, pull tabs, blackjack, dice, roulette).
- Listens for money changes and returns to menu on bankruptcy.

### Mini-games

Each mini-game has an isolated script, but they all mutate `Money`:

- `SlotMachine.gd`: simple 3-reel random match payouts.
- `PullTabs.gd`: grid reveal with row-match payouts.
- `Blackjack.gd`: deck, hand scoring, hit/stand flow, optional card-count aid item.
- `Dice.gd`: dice roll/hold flow with player/dealer scoring.
- `Roulette.gd`: clickable betting spots, chip values, wheel tween spin, payout processing.

## 5) Important implementation details (current state)

- There is heavy direct coupling to the `Money` singleton and scene scripts use mutable globals.
- Many UIs are generated in GDScript at runtime rather than authored fully in scenes.
- Item effects are currently checked inline in mini-games (for example, checking `Money.inventory`).
- The shop script has a local `shop` dictionary and also uses `Money.active_shop`; keep those synchronized if refactoring.
- `tools.gd` appears to preload `GodotGifManager` but `load_gif` calls `GifManager`, so verify naming/runtime behavior before relying on animated assets in new code.

## 6) Suggested learning order for new contributors

1. **Open `project.godot` first** to understand startup scene and autoloads.
2. **Read `Money.gd` and `tools.gd`** to learn global contracts used everywhere.
3. **Trace run loop**: `MainMenu.gd` -> `SHOP.gd` -> `CASINO.gd`.
4. **Pick one mini-game** (slots or pull tabs first) and follow how it debits/credits money.
5. **Then inspect complex games** (`Blackjack.gd`, `Roulette.gd`, `Dice.gd`) for patterns to standardize.

## 7) Good next improvements

- Create a typed `GameState` model to replace ad-hoc dictionaries and globals.
- Standardize mini-game interface (`start_round`, `resolve_round`, payout API).
- Split large scene scripts (`SHOP.gd`, `Dice.gd`, `Blackjack.gd`) into smaller components.
- Add deterministic tests for payout logic (pure functions first).
- Add explicit save/load boundaries and reset points for run state.

