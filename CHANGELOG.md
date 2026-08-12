# Changelog

All notable public release changes for Beat the House are recorded here.

## 0.5.0 - Released (2026-08-12)

Status: **official GitHub release.** The owner approved the accumulated 0.5
source, tests, art, reports, review artifacts, and final playtest fixes as the
baseline for the 2026-08-12 playtest event. The annotated `v0.5.0` tag is the
authoritative boundary for all work completed before 0.5.

### Final playtest completion pass

- Rebuilds the main menu with original logo/button art, a centered control
  grid, live environment backgrounds, and reliable reopen behavior.
- Adds the Pocket Watch and Fred's Poker Hat, including precise clock display,
  video-poker best-play guidance, and a small Heat cost on wins.
- Adds scalable red-edge Heat feedback with subtle audio while preserving the
  police-light overlay across rooms and game surfaces.
- Reworks map discovery and first-location variance, restores click focus and
  recenter behavior, fixes popup/icon separation, and animates accurate
  location-to-location travel on the run report.
- Fixes late-run responsiveness through bounded ticket/item persistence,
  reduced copy churn, and extreme-state probes covering large inventories,
  debt, money, tickets, dialogue, and concurrent machine activity.
- Fixes Blackjack tutorial pacing, patron/dealer/card animation, persistent
  count state, instant settlement skips, and Heat balance for counting and
  nonstandard strategy.
- Fixes Video Poker denomination/bet limits, Draw resolution, Double Up reveal
  timing, and recommendation presentation.
- Fixes slot entry, reel-symbol animation, autoplay lifecycle, Grand Casino
  machine count/currency, and Pinball Jackpot launch/board presentation.
- Fixes Roulette table layout, wheel-read bias/Heat mechanics, and the complete
  exported-Web spin, payout, and reveal sequence.
- Fixes Bar Dice pot selection, Pull Tab liveness, Scratch Ticket dispense and
  click-to-file behavior, and measured irregular per-well foil/icon alignment.
- Expands the guided tutorial with corrected dialogue sequencing, screen-safe
  highlights, tutorial restart on failure, Cage shop interaction, Bronze-card
  pacing, and the post-first-run Players Card help item.

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
- Replaces the legacy tutorial bubble chain with a dialogue-guided first night
  led by Pal and the Grand Casino Host. New Run and Replay Lessons begin in the
  Apartment and teach X-ray inventory use, the Corner Store/family loan,
  optional pull tabs, Blackjack/Peek/counting/Heat, the High Roller Invitation,
  Linda's Cage economy, and the Bronze Players Card through real actions.
- Rebuilds all seven Scratch Tickets around distinct generated-art backgrounds
  and exactly separated background, result-icon, and theme-matched foil layers.
  Results remain fixed at purchase; high-resolution interpolated scratching,
  deliberate drag-to-bin discard, result totals, and visible win/dud piles are
  presentation-only additions.
- Adds a second High Roller Invitation path: a table-game win over $300 places
  the invitation in the current environment and suppresses the random Tier-2
  copy once earned or accepted.
- Adds deterministic Scratch Ticket machine restocking every three in-game
  hours with the 50% none/40% one/10% two distribution, elapsed-time catch-up,
  and a seeded scalper encounter whose dialogue may reveal the next drop.

### Changed

- Tunes Rourke edge callouts from an 8-chip to an 18-chip swing so preparation
  materially matters, and moves the shown-the-door lower margin from -8 to -60
  so all three duel endings occupy meaningful measured bands.
- Makes travel between the Delta Queen and Beach a free dockside walk in both
  directions while preserving the River Queen's authored availability rules.
- Keeps tutorial highlights visual and mouse-pass-through, synchronizes them
  with camera/object movement, and lets requested actions advance dialogue
  exactly once after modal lifecycle boundaries such as Inventory and map.
- Compacts settled Scratch Ticket masks into bounded receipts while preserving
  seeded outcomes, old-save migration, portable piles, and the seven RTP bands.
- Removes recurring Grand Casino late-floor deep copies and redundant slot
  autoplay presentation rebuilds. The 180-minute/504-action soak now finishes
  with a negative retained-memory trend and bounded serialized RunState.
- Aligns Web audio with native playback: all 80 SFX cues use the shared 22.05
  kHz synthesis contract, authored music derivatives preserve their stem mix,
  decoding/validation stays off the main thread, and browser playback follows
  Master/Music/SFX bus gains.
- Ships the Web export single-threaded and replaces runtime procedural-music
  synthesis with deterministic prebuilt 22.05 kHz beds. Bounded run-shell
  staging and slot autoplay de-allocation bring 4x-throttled cold ready to
  17.557 seconds/20 seconds and autoplay to 88.312 ms/100 ms without changing
  simulation or performance budgets.
- Unifies run inventory and meta storage around responsive pooled item cards
  with voiced descriptions, affinity/attribute glyphs, stack counts, and
  source-level exclusion of the irrelevant risk badge.
- Gives every authored destination a distinct offer/tradeoff contract and
  shows live time, cash, Heat, risk, and forfeited-alternative costs in the
  production map before travel.

### Fixed

- Fixes native micro-stutters on ordinary room/game selections by removing
  redundant full-room rebuilds and guaranteeing a draw boundary before
  autosave serialization. Also fixes Scratch Ticket vending clicks resolving
  against the previous row selection instead of the clicked ticket and
  quantity.
- Fixes Sal's Pawn Shop authored fixture overlaps and restores the tutorial
  dialogue contracts caught by the integration suites.
- Fixes tutorial starts leaking profile home state, deprecated Dealer's Advice
  tips, missing X-ray Glasses, offscreen or blocking highlights, map/modal
  ownership failures, natural phone-dialogue interruption, and skip/recovery
  loops.
- Fixes Scratch Ticket completion feedback disappearing before the player can
  read the payout, completed tickets not entering their win/dud piles, overly
  easy accidental trashing, and stale scratch marks at the last pointer point.
- Fixes sustained Grand Casino slowdown caused by per-frame environment-state
  scans/copies and the repeating Web slot-autoplay action hitch.
- Fixes the low-bandwidth Web-only music/SFX substitutions and missing native
  audio-bus gain parity.
- Makes release gates authoritative for parser/runtime stderr, validates
  compositional tests through their real generated runners, and fixes map
  focus, lifecycle/layout, and stale content-contract regressions found by the
  honest gate.
- Keeps late-run Crew recovery live by recognizing debt-profile liquidity and
  removing an unrelated terminal checkpoint from conversation opening.
- Rebalances Buffalo true wins through explicit format-aware paytables and
  makes the deep audit/report contracts validate the canonical payout seam.
- Rebalances Buffalo free games on the 5x4 and 6x5 cabinets so large boards
  generate fewer gold tokens and cannot retrigger past 28 total spins, while
  preserving the classic 3-reel math and terminal full-board Grand result.
- Fixes Rourke duel hands becoming trapped on SETTLE after a hit to 21 by
  keeping the fixed ante inside the duel stacks instead of charging the
  player's ordinary cash or casino chips again at settlement.

Current evidence is recorded in `docs/plans/0.5_pre_release_audit.md`,
`docs/plans/tutorial_completion_report.md`, `docs/plans/0.5_performance_audit.md`, and
`docs/plans/0.5_release_checklist.md`. No final release approval is claimed
until the human, owner, packaging, and publishing gates close.

## 0.4.0 - Unpublished Act 1 candidate

Status: **tagged candidate, not published.** The candidate gate battery passed,
but later playtesting found defects and development continued into 0.5.0.

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
