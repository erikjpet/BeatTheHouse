# Changelog

All notable public release changes for Beat the House are recorded here.

## 0.5.0 - In development

Status: **in development.** The Grand Casino feature queue is implemented;
repository release verification and owner playtesting are still in progress.

### Added

- Adds the default-off **Play on small screen** setting as the first step in
  the 0.5 interface rework. The persistent mode enlarges standard controls,
  text, map nodes, dialogue and inventory actions, environment-object tap
  regions, and gambling-surface hit regions for phone and tablet play while
  preserving the existing desktop presentation when disabled.
- Rebuilds the Grand Casino as three connected rooms: a machine-and-Cage Main
  Floor, a Silver-card or paid-entry High-Limit Room, and a locked Back Room
  for the boss duel. Room movement advances the existing clock while all
  casino heat, memory, progression, chips, and finale state remain shared.
- Adds Grand Casino chips for blackjack, baccarat, and roulette plus Linda's
  Cage window for chip exchange, Players Card progress, comps, and the
  deliberate clean-route Gold review. Machines and bar dice continue to use
  cash.
- Makes Pit Boss Rourke a visible, spatial agent who moves at deterministic
  action boundaries toward room heat. Seeded rival cheaters can draw him away
  or be escorted off the floor, while daily seeded dealer/bartender rotation
  and re-entry memory make the casino persist across visits and days.
- Adds Linda's data-driven Bronze/Silver/Gold Players Card ladder with chip and
  drink comps, suite recovery, Silver high-limit access, a one-shot low-heat
  look-away, and permanent card ineligibility after cheat evidence.
- Replaces the old showdown check with a saveable four-phase encounter: ditch
  one item on the walk, face a visible contraband pat-down tier, answer three
  questions drawn from the run ledger, then play a five-hand heads-up
  blackjack duel against Rourke's readable edges.
- Adds the showdown outcome ladder: cash out and walk clean, be shown the door
  with uncashed chips, or be taken out back. The successful uncashed ending
  keeps half the rack's value for score and mints the full rack as a stack Sal
  can fence for gold.
- Adds unique Gold Players Card meta items stamped with run results. Cards stay
  at critical condition, are destroyed if carried into a failed prestige run,
  and provide recognition heat relief, a tighter clean heat ceiling, and a
  one-tier collection-drop bonus when carried.
- Records the Act 2 seam on a Gold-card victory while keeping the run terminal
  in Act 1; the victory report states that the Gold card opens doors beyond
  this city without exposing unimplemented Act 2 UI.

### Changed

- Tunes Rourke edge callouts from an 8-chip to an 18-chip swing so preparation
  materially matters, and moves the shown-the-door lower margin from -8 to -60
  so all three duel endings occupy meaningful measured bands. Full before/
  after seed evidence will be cited with the 0.5 release-readiness battery.

## 0.4.0 - Act 1 completion release

Status: **released on 2026-07-15.** The fresh final-gate battery passed on
2026-07-14, followed by owner playtesting and publication.

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
- Final 0.4 repository-gate evidence: **PASS** on 2026-07-14. The exact suites,
  timeouts, metrics, warnings, and report paths are recorded in
  `.tmp/release_readiness_0_4_0.md`; owner playtest and publishing remain manual.
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
