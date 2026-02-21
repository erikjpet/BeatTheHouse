# Beat The House - Standalone Rewrite

This folder is a **Godot-free standalone application** that keeps the core concept:

- Roguelike casino runs.
- Heat/suspicion from cheating too aggressively.
- Floor-based progression.
- Shop upgrades between floors.
- Meta progression persisted across runs.

## Run it

```bash
cd standalone_casino
python -m pip install -e .
beat-the-house
```

## Architecture

- `models.py`: run and meta data models.
- `games.py`: independent casino mini-game systems.
- `progression.py`: shop and meta unlock logic.
- `main.py`: CLI loop and orchestration.

## Why this structure

The code is split by domain (run state, mini-games, progression, app loop) so future additions like event decks, AI opponents, floor modifiers, or UI frontends (desktop/web) can be added without rewriting core logic.
