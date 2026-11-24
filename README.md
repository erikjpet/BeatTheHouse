# Beat the House

Beat the House is a single-player pixel-art casino roguelike for Windows and
Web. Play eleven simulated casino games, move through a town that changes
with each run, and build your bankroll while the house keeps an eye on you.

**No real money is wagered or paid out.** There are no cash prizes or purchases
that affect the odds.

## Download

Get the [0.6.1 release](https://github.com/erikjpet/BeatTheHouse/releases/tag/v0.6.1).
On Windows, extract the entire ZIP and open `BeatTheHouse.exe`. For the Web
build, serve the extracted folder over HTTP and open `index.html`.

## Run from source

Install Godot 4.6 and open `project.godot`. The main scene is
`scenes/main.tscn`. Run it from the editor, or use these Windows commands:

```powershell
.\tools\install_godot.ps1
.\tools\run_godot.ps1
```

Use `-Editor` to open the editor instead. Set `GODOT_BIN` to select an existing
Godot installation.

## Export

On Windows, install the matching Godot export templates and build the
native Coin Pusher libraries for the export targets:

```powershell
.\tools\install_export_templates.ps1
.\tools\build_native_solver.ps1 -Platform Windows -Target template_release
.\tools\build_native_solver.ps1 -Platform Web -Target template_release
.\tools\export_itch.ps1 -Target all
```

To export just one package, use `-Target windows` or `-Target web`.
Packaging does not publish the result.

## Tests

From a Windows checkout with Godot 4.6 and Python:

```powershell
.\tools\check_godot.ps1 -Suite Smoke
```

Use [TODO.md](TODO.md) for the work list and
[docs/design](docs/design/) for design references.
