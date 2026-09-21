# Beat the House — Extended Localization and Player-Text Audit

**Date:** 2026-09-20  
**Method:** bounded static-only sweep; no Godot process launched  
**Scope:** localization readiness, numeric/currency/time formatting, string encoding and truncation, pluralization, locale-sensitive parsing, and player-visible error consistency  
**Disposition:** investigation only; no product source or data was changed

## Executive summary

This sweep retained **four independently supportable player-text defects**. The most important current issues are that the shared sealed-action host still calls every authority failure a “Blackjack” failure even when used by Bar Dice, Baccarat, Roulette, Slot, and Video Poker, and that Grand Casino result messages describe changes as dollars or “Bankroll” before the economy layer converts those exact deltas to chips.

The run report also mixes a 24-hour timestamp with the game's otherwise consistent 12-hour AM/PM clock. The retained grammar/composition family includes reachable one-count states that render `1 tickets` or `1 actions` and Baccarat natural-hand copy that joins two sentences without whitespace (`Natural hand.0 won...`).

No malformed UTF-8 was found. The repository has no translation hooks, resources, or locale configuration, but the current product does not advertise or expose a non-English locale; that is therefore documented as a serious readiness limitation, not counted as a defect. UIE-023 already owns confirmed silent text truncation, so the 196 additional fixed-character truncation sites are recorded as localization risk without creating a duplicate bug. Existing accessibility and audio findings were not refiled.

## Findings

### EXT-TXT-001 — Shared authority errors incorrectly identify non-Blackjack games as Blackjack

**Severity:** P2 / Medium  
**Frequency:** deterministic whenever an affected rejection/retry branch is reached  
**Affected games:** Bar Dice, Baccarat, Roulette, Slot, and Video Poker; Blackjack wording is correct only for Blackjack itself

#### Reproduction

1. Enter any non-Blackjack game that implements `sealed_action_authority_contract()`—for example Roulette or a Slot cabinet.
2. Reach a sealed-host rejection branch such as an invalid/stale delivery, failed proposal replay, missing receipt, late environment-turn rejection, or pending-action conflict.
3. Observe the message routed to the player.

#### Expected

The message names the active game, uses a neutral term such as “game action,” or provides a recovery instruction without exposing another game's name.

#### Actual

The generic host returns text including:

- `Blackjack action intent is unavailable.`
- `Retry or cancel the pending Blackjack action...`
- `Blackjack game proposal failed closed validation.`
- `Blackjack transaction could not cross the environment boundary.`
- `Blackjack replay did not match the canonical committed response.`

These strings can appear while the player is at Baccarat, Roulette, Bar Dice, Video Poker, or Slot/Pinball/Buffalo. `FoundationMain._resolve_game_action()` unconditionally passes `result.message` to `_show_message()`, so the incorrect noun is player-visible rather than diagnostic-only.

#### Root cause

The action-authority system originated as a Blackjack host and was generalized to six providers without generalizing its text contract. `scripts/ui/foundation_main.gd` contains 55 remaining `Blackjack` references. Many are comments, but numerous literals are returned from shared code paths at lines 1651-1992 and 2288-2641. The active `current_game` and its display name are available, but none of these error builders use them.

Six modules currently implement the shared authority contract: Bar Dice, Baccarat, Blackjack, Roulette, Slot, and Video Poker.

#### Fix options

1. Replace provider-specific shared-host prose with neutral localized keys such as `sealed_action.pending`, `sealed_action.retry_failed`, and `sealed_action.boundary_failed`.
2. Pass a trusted game display-name key in the authority contract only when naming the provider improves the message.
3. Separate internal diagnostic detail (“proposal fingerprint mismatch”) from concise player recovery copy.
4. Add a table-driven test that invokes every rejection code once for every authority provider and asserts that no other game's name appears.

#### Evidence

- `scripts/ui/foundation_main.gd:1651-1992`
- `scripts/ui/foundation_main.gd:2288-2641`
- `scripts/ui/foundation_main.gd:12220-12330`
- `scripts/ui/foundation_main.gd:12430`

### EXT-TXT-002 — Grand Casino result copy reports dollars or “Bankroll” when the applied balance is chips

**Severity:** P2 / Medium  
**Frequency:** common on affected Grand Casino game results  
**Affected games:** Blackjack, Baccarat, Roulette, Video Poker, Bar Dice, and potentially any newly routed module that authors cash-centric result prose; Craps already demonstrates the correct explicit-unit pattern

#### Reproduction

1. Enter a Grand Casino instance of an affected game, where wagers use casino chips.
2. Complete an action that wins, loses, or places a wager.
3. Compare the result sentence with the balance that actually changes.

#### Expected

The message should say `chips`, show a chip icon/label, or use a neutral localized balance-change phrase consistent with the applied account. Dollar signs should be reserved for cash.

#### Actual

Examples authored by the game modules include:

- Blackjack: `Blackjack wager placed: $N on the felt.` and result fragments such as `Main +N`.
- Baccarat: `Commission $N` and `Net +N` without identifying chips.
- Roulette: `Bankroll +N`.
- Bar Dice: a `$N pot`, `$N rake`, then `Bankroll +N`.
- Video Poker: `Bankroll +N`.

At the Grand Casino, those module `bankroll_delta` values are converted into `chips_delta`; the cash bankroll delta is set to zero. The prose can therefore tell the player that cash/bankroll changed when only chips changed.

#### Root cause

Game modules construct final English text before the shared economy layer determines the authoritative currency. `GameModule.apply_result()` calls `RunState.route_grand_casino_game_currency()` at `scripts/core/game_module.gd:867`. The router (`scripts/core/run_state.gd:4702-4729`) recognizes seven Grand Casino chip games, moves the proposed `bankroll_delta` into `chips_delta`, zeroes `bankroll_delta`, and sets `result.currency="chips"`. It updates numeric result fields but does not rebuild `result.message`.

Craps already avoids the ambiguity in `_roll_message()` by choosing `cash` for Street Craps and `chips` for the casino table (`scripts/games/craps.gd:1171-1182`). The other modules do not consistently make that distinction.

#### Fix options

1. Build player-facing result copy only after currency routing, using `result.currency`, `bankroll_delta`, and `chips_delta`.
2. Carry structured result-message keys and parameters from each module; let the host supply the final currency noun/symbol.
3. Use separate formatters for cash, chips, and mixed settlements. Do not use `$` as a generic score marker.
4. Add Grand Casino and non-casino message assertions for every routable game, checking both the named unit and the balance that actually changes.

#### Evidence

- `scripts/core/game_module.gd:852-873`
- `scripts/core/run_state.gd:119`
- `scripts/core/run_state.gd:4279-4289`
- `scripts/core/run_state.gd:4702-4729`
- Packaged production captures: `.tmp/playtest_2026-09-20/packaged_platform/windows_l02/report.json` and `windows_l02_repro/report.json` (Bar Dice `Bankroll -10`, Baccarat unitless `Net -20`, Roulette `Bankroll -1`, contrasted with Craps `Net -10 chips`)
- `.tmp/playtest_extended/localization_text/static_evidence.md`

### EXT-TXT-003 — Run outcome card switches to an inconsistent 24-hour clock without a suffix

**Severity:** P3 / Low  
**Frequency:** every completed run; most obvious for times at or after 13:00  
**Area:** run report outcome header

#### Reproduction

1. Finish a run at 13:00 game time.
2. Compare the outcome-card `where` line with the in-run HUD and run-report replay clock.

#### Expected

The same game time uses one consistent convention. Under the current English UI, 13:00 should appear as `1:00 PM` everywhere.

#### Actual

- HUD/replay/schedules: `Day N 1:00 PM`.
- Outcome `where` line: `Day N, 13:00`.

The outcome line has neither an AM/PM suffix nor any setting or locale signal that the display intentionally changed to 24-hour time.

#### Root cause

The project has several independent clock formatters. `RunState.clock_display_text()`, `FoundationHudViewModel.clock_model()`, Scratch Ticket schedule copy, and `RunReportViewModel.format_game_clock()` all convert to a 12-hour clock with AM/PM. `RunReportViewModel.build_outcome()` separately divides total minutes and interpolates raw `hour` into `%02d:%02d` (`scripts/ui/run_report_view_model.gd:496-507`) instead of calling the existing formatter.

#### Fix options

1. Route every game-clock display through one locale-aware formatter.
2. Make 12/24-hour preference explicit if both styles are intentionally supported.
3. Add boundary tests for midnight, noon, 13:00, and day rollover across HUD, schedules, map, report outcome, and replay clock.

### EXT-TXT-004 — Hand-built grammar produces singular-count and sentence-joining errors

**Severity:** P3 / Low  
**Frequency:** deterministic at affected count values  
**Area:** Scratch Tickets, Pull Tabs, Baccarat, career/crew/action status copy

#### Reproduction examples

- Deplete Scratch Ticket stock until one ticket remains in one active row.
- Deplete Pull Tabs until one ticket remains.
- Display an action-duration record whose duration is one action.
- Resolve a Baccarat natural hand.

#### Expected

`1 ticket`, `1 active row`, `1 action`, and a visible separator between the natural-hand sentence and the settlement counts.

#### Actual

Templates emit phrases such as:

- `1 tickets across 1 active rows.`
- `1 tickets remain across four deal rows.`
- `1 actions`.
- `Natural hand.0 won, 1 lost, 0 pushed.`

#### Root cause

Grammar is assembled ad hoc. Some files correctly concatenate `"" if count == 1 else "s"`, while other status templates bake in the plural noun. Baccarat separately concatenates `natural` and `bet_text` with adjacent `%s%s` placeholders; the first fragment ends in a period and the second has no leading whitespace. There is no shared count-message or sentence-composition boundary, so correctness depends on each author manually supplying English suffixes and separators.

Confirmed sites include:

- `scripts/games/scratch_tickets.gd:189`
- `scripts/games/pull_tabs.gd:372`
- `scripts/ui/career_stats_view_model.gd:170`
- `scripts/core/crew_play_model.gd:176,346`
- `scripts/core/run_action_service.gd:1228`
- `scripts/games/baccarat.gd:2872-2895`
- Production reproduction: `.tmp/playtest_2026-09-20/packaged_platform/windows_l02/report.json:14013` and `windows_l02_repro/report.json:14011`

#### Fix options

1. Replace suffix concatenation and baked plural nouns with localized plural messages keyed by count.
2. Add zero, one, two, and large-count assertions for every count-bearing status model.
3. Keep count numeric values structured until presentation so locales with more than two plural categories can work correctly.

## Numeric, parsing, encoding, and truncation disposition

### Numeric and currency formatting

Money is currently rendered through direct `$%d` interpolation with no digit grouping or locale placement. Because the product exposes no locale choice or non-English support contract, that is recorded as readiness risk rather than multiplied into hundreds of site-level bugs. The semantically wrong cash/chip labeling is independently actionable and is retained as EXT-TXT-002.

### Localization-readiness limitation (not counted as a defect)

Static inventory found zero `tr(...)` calls, zero translation catalog resources, and no internationalization/locale configuration in `project.godot`. It also found 288 direct money/bankroll formats and 196 literal character caps. The product does not currently advertise a locale selector or non-English build, so this does not violate an exposed player-facing contract and is intentionally excluded from the bug count. Before any localized release, the game will need stable translation keys, structured formatting parameters, plural rules, a centralized clock/currency formatter, catalogs, fallback configuration, and pseudo-localization coverage.

### Locale-sensitive parsing

No player-facing free-form decimal parser was found that clearly accepts one locale and silently misreads another. Most wager inputs use numeric controls, while generation-override text is developer-facing. No parsing defect is filed without a player-reachable misparse.

### Encoding

Every file under `scripts/` and `data/` decoded successfully with strict UTF-8. No source/data mojibake sequence was confirmed. Apparent `Â·` output seen in the Windows shell is the shell's legacy display decoding of valid UTF-8 `·`, not a repository defect.

### Truncation

The static sweep counted 196 literal `.left(N)` caps across game/UI code, which will make expansion-heavy locales difficult. However, UIE-023 already documents the confirmed player-visible silent-truncation family and its missing ellipsis/tooltip behavior. This report records the scale as a localization risk but does not inflate the bug count with a duplicate.

## Recommended remediation order

1. Fix EXT-TXT-002 so current players are told the correct balance and unit.
2. Generalize shared-host messages for EXT-TXT-001 before additional games adopt sealed authority.
3. Establish a structured localization/formatting boundary as readiness work; use it to solve plural and clock formatting rather than adding more English-only conditionals.
4. Convert the outcome time and one-count messages as the first regression fixtures for the new formatter.
5. Run pseudo-localization and long-string layout validation, using UIE-023 as the existing truncation owner.

## Evidence index

- Static inventory and exact source map: `.tmp/playtest_extended/localization_text/static_evidence.md`
- Existing truncation owner: `reports/playtest_2026-09-20/ui_environment.md` (UIE-023)
- Existing accessibility duplicate screen: `reports/playtest_2026-09-20/accessibility_input.md`

## Final disposition

- **New retained findings:** 4
- **P2 / Medium:** 2
- **P3 / Low:** 2
- **Malformed UTF-8 findings:** 0
- **Locale-sensitive player-input parsing findings:** 0
- **Duplicate truncation findings refiled:** 0
- **Godot/runtime processes launched:** 0
- **Product fixes made:** none
