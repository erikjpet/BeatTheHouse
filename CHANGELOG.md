# Changelog

All notable public release changes for Beat the House are recorded here.

## 0.4.0 - Act 1 completion release

Status: **unreleased and in final development.** An earlier candidate was
packaged and tagged, but game-breaking playtest defects sent 0.4.0 back into
development. Fresh final-gate evidence, owner playtest, export packaging,
itch/GitHub upload, and the release tag are still pending.

### Release Notes

- Completes the Act 1 release cut while leaving the new boss fight/final scene
  out of scope.
- Adds the walkable meta home, housing progression, pawn-shop sell counter,
  local collection bags, loadout injection, and run-end collection drops.
- Finishes profile persistence, run history/stat tracking, dialogue/talk
  content, jazz/beach route content, semantic room layouts, and attribute
  glyph panels.
- Gates Grand Casino travel behind an earned invitation, adds the run-side
  beach and Sal's Pawn Shop environments, and fixes venue-hours/time-state
  travel behavior.
- Hardens save recovery, process/liveness guards, deterministic state handling,
  stuck/terminal polling, and idle/active rendering on native and Web paths.
- Splits the oversized foundation UI host into focused terminal consequence,
  environment interaction, HUD, screen, travel, action, journal, map, wager,
  and meta-session modules without changing deterministic gameplay behavior.
- Adds explicit idle-animation liveness and performance attribution gates plus
  a verified local artifact retention/export tool.
- Final 0.4 evidence: **PENDING**. The fresh release battery will be recorded in
  `.tmp/release_readiness_0_4_0.md` before release.
- Keeps the simulated-gambling boundary: no real-money wagering, cash prizes,
  gambling monetization, or store credentials in the repository.

## 0.3.3 - GitHub source release

Status: GitHub source release cut from the current PM release tree. Itch export
artifacts remain a separate operator action.

### Release Notes

- Better low-end stability.
- Starting home location.
- Containers.
- World map travel.
- Audio fix on web.
- Miscellaneous bug fixes.

### Additional Fixes Since The 0.3.2 Internal Package

- Restored table animation behavior after low-end cleanup work.
- Kept idle table scenes lively without reintroducing expensive redraw loops.
- Made slot autoplay activate from one clear click.
- Fixed duplicate canvas activation on Pull Tabs.
- Kept roulette wheel motion and labels stable through post-spin result states.
- Reduced roulette bet placement hot-path cost.
- Hardened duplicate pointer suppression, including delayed duplicate clicks.

### Carried Forward From 0.3.2

- Web and Windows remain the primary release targets.
- Low-end and web performance gates cover game surfaces, world map, memory,
  deterministic replay, stuck-state sweeps, and mouse-only play.
- The release is simulated gambling only: no real-money wagering, cash prizes,
  gambling monetization, or platform credentials in the repository.

### Publishing Notes

- Itch upload stays a manual operator action after `tools/export_itch.ps1`
  produces web and Windows zips.
- Android and iOS presets remain configured but blocked on real signing and
  store credentials.

## 0.3.2 - Internal release closure

0.3.2 closed the low-end and web cleanup line. Its release ledger is
`docs/plans/0.3.2_release_checklist.md`. The packaged 0.3.2 zips should not be
uploaded because post-close playtest hotfixes are included in the 0.3.3 patch
cut instead.

## 0.3.0 - Act 1 feature-complete baseline

0.3.0 established the Act 1 source-release baseline: full simulations for Pull
Tabs, Slots, Bar Dice, Blackjack, Baccarat, Roulette, and Video Poker; seeded
world-map travel; tier-2 venues; skill-cheat actions; the Grand Casino win
routes; release packaging tools; and the first current README truth pass.
