# Beat The House - Standalone Rewrite

This folder is a **basic standalone desktop game** that keeps the core concept while providing a minimal UI:

- Roguelike casino runs.
- Heat/suspicion from cheating too aggressively.
- Floor-based progression.
- Shop upgrades between floors.
- Meta progression persisted across runs.
- Simple Tkinter interface (menus, action buttons, run log).

## Run it

```bash
cd standalone_casino
python -m pip install -e .
beat-the-house
```

## UI flow

1. Click **Start Run**.
2. Choose a game and wager, then play rounds.
3. Use **Shop** to buy upgrades.
4. Use **Advance Floor** when bankroll meets the floor requirement.
5. Use **Cash Out** to end the run any time.

## Architecture

- `models.py`: run and meta data models.
- `games.py`: independent casino mini-game systems.
- `progression.py`: shop and meta unlock logic.
- `ui.py`: Tkinter interface and menu/game orchestration.
- `main.py`: entrypoint that launches the UI.

## Notes

- The code is intentionally minimal and modular so we can continue porting more original game systems and visuals in small increments.
- Saves are written to `standalone_casino/save_meta.json`.
