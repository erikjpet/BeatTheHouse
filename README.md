# Beat the House

Beat the House is a single-player pixel-art casino roguelike for Windows and
Web. Play eleven simulated casino games, move through a town that changes
with each run, and build your bankroll while the house keeps an eye on you.

**No real money is wagered or paid out.** There are no cash prizes or purchases
that affect the odds.

## Download

Get the [latest release](https://github.com/erikjpet/BeatTheHouse/releases/latest).
On Windows, extract the entire Windows ZIP and open the game executable inside.
For the Web build, serve the extracted folder over HTTP and open `index.html`.

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

For a public release, run `.\tools\export_itch.ps1 -Target all -Release` from a clean
checkout. This uses the project version in the archive names and checks the
Windows executable's file and product versions. The command above produces
development candidates. Packaging does not publish the result.

## Tests

With Godot 4.6 installed, run these commands from the checkout:

```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/run_all.gd
```

The same tests run on every push and pull request. They use disposable data
outside the checkout. On Windows, if the system temporary directory is on
C:, point `BTH_TEST_TMPDIR` to a scratch directory on another drive.

The travel case uses the normal game actions to take one trip, settle one paid
Slot round and save. A second headless source process uses Continue and checks
that the same run, venue, bankroll, items and settled spin survived the quit.

To also check an extracted Windows package, keep its DLL alongside the EXE.
Use a disposable shell with a scratch directory outside the checkout and off C:.

```powershell
$bthTestRoot = 'D:\CodexQA\BTH\test-scratch'
$env:BTH_TEST_TMPDIR = $bthTestRoot
$env:APPDATA = Join-Path $bthTestRoot 'runner-appdata'
$env:LOCALAPPDATA = Join-Path $bthTestRoot 'runner-localappdata'
$env:TEMP = $bthTestRoot
$env:TMP = $bthTestRoot
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
godot --headless --path . --script res://tests/run_all.gd -- --windows-exe 'D:\path\to\extracted\BeatTheHouse.exe'
```

The extra check starts the exact packaged EXE without a window and checks its
startup log and exit status. Gameplay and cold Continue run against the source
checkout. Headless checks do not verify physical display placement or rendered
gameplay.

Use [TODO.md](TODO.md) for the work list and
[docs/design](docs/design/) for design references.
