# Working on Beat the House

Beat the House is a Godot 4.6 pixel-art casino roguelike for Windows and Web.
Main scene: scenes/main.tscn. Design notes: docs/design/. Tasks: TODO.md.

## Phase: refinement
The game is close to feature-complete. Improve existing features, fix bugs,
keep tests and docs current. Do not start new features unless Erik has put
them in the Now section of TODO.md.

## Done
A change is done when it is committed, the game runs, and tests/run_all.gd
passes (locally or in GitHub Actions). If you change behavior on purpose,
update the affected test in the same commit.

## Tests
- Test game rules and money: settlement, saves, travel, progression.
- Never test pixels, layout, image hashes, exact text or timings.
- No saved fixture files; build state in code from a seed.
- Performance is checked by playing, never by a pass/fail gate.

## Rendering
Never optimize by disabling canvas processing, removing autonomous redraws or
tying redraws to input. Run tests/test_liveness.gd after rendering or
performance changes.

## Finish the job
Nobody is watching to tell you to continue. Work until the request is done.
- A progress update is never a stopping point. Don't end with "next I will";
  do it.
- Setup problem (paths, caches, environment, a failed command): fix it and
  continue. If an approach fails twice, try a different one.
- Stop to ask Erik only for: changing game behavior beyond the request, a
  release blocker, or an action under "Ask first" below. Even then, finish
  every part of the request that isn't blocked before you ask.
- Commit after each finished step, so work survives a restart. On restart,
  read your branch's commits and continue from there.
- Before you finish, check your work against the request, item by item:
  1. Run tests/run_all.gd.
  2. Show the changed behavior works once, the simple way: play it, or run a
     short script. Add or update at most one test per changed behavior.
  3. Anything not done: do it. Anything you truly can't do: add it to
     TODO.md and say why.
- Proof is that check, not a suite. Don't build new test campaigns, matrices
  or repeated runs to prove a change.

## Working style
- Do not write reports, ledgers, evidence or receipt files. The commit message
  is the record. Final summary to Erik: five lines or fewer: what was asked,
  what was done, what is left (and that it is in TODO.md).
- Follow the rules at the top of TODO.md.
- Scratch and QA output goes outside the repository and never on drive C:.
- These rules do not authorize extra permissions or portrait-mode app updates.

## Pushing (Erik, 2026-11-23)
Pushes to main and working branches are allowed once work is done. No need to
ask per push. Ask first: force push, history rewrite, deleting branches or
tags, creating tags or GitHub releases, uploading to itch. While main is
frozen for a release, only the freeze commit and release-blocker fixes may be
pushed.

## Releases
Freeze main: the freeze commit sets the version in scripts/core/build_identity.gd,
project.godot (config/version) and export_presets.cfg (file and product
version), and the CHANGELOG. Run tests/run_all.gd, export with
tools/export_itch.ps1 (package names must show the release version), play 15
minutes on Windows and Web (new run, travel, a paid round, Save, quit,
Continue). Erik tags and uploads. Release blockers: crash, lost or duplicated
money or progress, broken progression, broken saves. Everything else goes in
TODO.md.
