# Beat the House — Agent Instructions

Godot 4.6 GDScript casino roguelike. Windows dev environment; web (itch.io)
and Windows desktop are the release targets.

## Architecture in one paragraph

All game rendering is immediate-mode GDScript drawing onto `GameSurfaceCanvas`
(scripts/ui/game_surface_canvas.gd) on a 900×430 design board
(scripts/core/art_contracts.gd `GAME_BOARD_SIZE`). Game logic lives in
per-game modules under scripts/games/ that talk to the host
(scripts/ui/foundation_main.gd, ~11k lines) through dictionary "surface
commands" and "surface state" snapshots. Content is data-driven from
data/*.json. On web exports, audio bypasses Godot's mixer entirely via
scripts/ui/web_audio_bridge.gd.

## Roles and work queue

This repository is worked by two kinds of agent session:

- **Project manager** (owner's primary machine): researches, authors, and
  reviews prompt files; curates the queue. Only the PM writes new prompts
  into `docs/todo/`.
- **Work agent** (any machine): executes prompts. Everything a work agent
  needs MUST be in this repository — prompts are self-contained by rule and
  no agent may depend on another machine's session memory.

Queue mechanics:

- `docs/todo/` is the backlog of record: complete, self-contained agent
  prompt files for pending work. When asked to "work on the todo list",
  "pick up a task", or similar: follow `docs/todo/QUEUE.md` — claim the
  first ready entry for your machine, execute it per `docs/todo/RULES.md`
  (binding), archive it, and **keep looping until nothing is ready for your
  machine**, then report what remains and why.
- `docs/todone/` archives executed prompts with execution records. Never
  execute prompts from there. Rules: `docs/todone/RULES.md` (binding).
- Before executing a prompt, state which one you are executing so overlapping
  sessions don't double-claim it.
- `docs/plans/` holds boards, specs, and release ledgers — planning material
  and history, not directly executable. Plans get promoted into `docs/todo/`
  prompts by the project manager before execution (pending examples:
  pinball_feature_rework_plan.md, skill_based_cheating_methods_plan.md,
  music_system_rework_plan.md).

## Hard rules

- Per-frame code paths stay zero-copy: never `duplicate(true)` live state per
  frame (this repo shipped a measured 32.6 ms/frame regression from that).
- Generated reports go under `.tmp/` (gitignored), never committed.
  `tools/function_census.ps1` output is generated — do not re-track it.
- Match existing style: tab indentation, typed GDScript, sparse comments that
  state constraints only.

## Validation

- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1` is
  the cheap always-run gate.
- Full/targeted Godot suites run via `tools\check_godot.ps1` (see flags in
  the script); they are slow — run targeted suites, and full only for
  release-grade verification.
