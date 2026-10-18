# Beat the House — Static Accessibility, Input, and Localization Follow-Up

Date: 2026-09-21  
Owner: `/root/ui_environment`  
Build reviewed: `b7c51bf4`  
Method: static-only follow-up while another worker owned Godot. No runtime was launched and no product source or data was modified.

## Executive summary

Four new findings survived source-level proof and deduplication: two High, one Medium, and one Low. The most important are that four blocking overlays beyond World Map still lack complete modal focus ownership, and the Run Menu cannot fit inside the code-supported 640x360 minimum window. Run Journal attempts responsive sizing but retains a 600x440 custom minimum that defeats its 336-pixel height calculation. The new shared routed-currency formatter also produces `1 chips` for a one-chip result.

The audit covered keyboard/gamepad focus entry, focus containment, cancellation and restoration; small-screen and large-text geometry; native/custom hit targets; truncated-text disclosure and tooltips; shared player text, count grammar, currency, and time formatting; and localization infrastructure. Previously reported World Map focus escape, expanded small-screen scenario/base hit validation, and environment-label truncation were excluded rather than refiled.

## AIF-001 — Four blocking overlays do not fully own keyboard/controller focus

- Severity: **High**
- Confidence: **High static control-flow proof**
- Validation mode: **Static only; not runtime-reproduced in this follow-up**
- Affected surfaces: Run Menu, Run Journal, Run Inventory, and Meta Item Interaction
- Affected resolutions: all; the ownership failure is resolution-independent.
- Frequency: deterministic from each overlay's open path; runtime frequency was not measured because this wave was explicitly static-only.

### Reproduction

1. Give a gameplay or HUD control keyboard focus.
2. Open Run Menu, or open Run Journal from Run Menu.
3. Observe that neither open path focuses a control inside the new overlay.
4. Separately open Run Inventory or Meta Item Interaction; these correctly focus a selected slot or Close.
5. Continue forward/reverse Tab navigation past the overlay's last focusable control.

### Expected

Every blocking overlay stores the prior owner, focuses a meaningful enabled control when shown, traps forward/reverse focus within its enabled controls, and restores the prior owner on close. Controller focus navigation should follow the same ownership boundary.

### Actual

- Run Menu becomes visible and moves to front, but never calls `grab_focus()` or stores/restores the prior owner.
- Run Journal behaves the same way; its Close button is a local variable, so the host cannot focus it after opening.
- Run Inventory and Meta Item Interaction store/restore prior focus and acquire initial focus, but neither traps `ui_focus_next`/`ui_focus_prev`. Their only overlay-level input handling is `ui_cancel`.
- `FoundationMain._input()` contains a focus trap only for event-choice popups. The full-screen overlays stop pointer input, but `MOUSE_FILTER_STOP` does not create a keyboard focus scope.

The declared overlay contract says gameplay input is blocked while these surfaces are open (`scripts/ui/foundation_main.gd:653-674`), yet the focus contract does not enforce the same ownership.

### Player impact

Keyboard, controller, switch, and assistive-technology users can have an invisible background control remain focused when an overlay opens, or can Tab out of an inventory/meta modal after initial focus. Focus indication then disappears behind the overlay and activation ownership becomes ambiguous. Run Journal is especially fragile because focus remains on its opening button in the Run Menu behind it.

### Root cause

- Run Menu open path: `scripts/ui/foundation_main.gd:5972-5988`; hide path: `foundation_main.gd:16708-16712`.
- Run Journal open/hide paths: `foundation_main.gd:18379-18389,18465-18473`.
- Run Journal Close button is not retained as a member: `foundation_main.gd:8884-8920`.
- Run Inventory initial focus/restore is implemented at `scripts/ui/run_inventory_screen.gd:83-135`, but `_unhandled_input()` handles only cancel at `run_inventory_screen.gd:676-681`.
- Meta Item Interaction has the same partial implementation at `scripts/ui/meta_item_interaction_screen.gd:41-82,289-294`.
- The only host focus trap is event-choice-specific: `foundation_main.gd:782-794,12329-12340`.

This is distinct from UIENV-PF-002: that report owns World Map's broken focus graph. This finding covers four other blocking overlay implementations and two separate missing behaviors—entry/restoration for Run Menu/Journal and containment for Inventory/Meta Item.

### Fix options

1. Introduce one shared modal focus-scope controller that collects visible enabled controls, stores/restores prior focus, and wraps forward/reverse traversal.
2. Retain Run Journal's Close button as a member and focus it on open; focus Resume or the previously used Run Menu action when opening Run Menu.
3. Apply the same scope to Run Inventory and Meta Item Interaction rather than relying on initial `grab_focus()` alone.
4. Add keyboard and controller tests that open each overlay from a focused background control, traverse both directions beyond every boundary, close it, and assert the owner always belongs to the topmost modal or the restored prior control.

### Regression acceptance

For each of the four overlays, test both forward and reverse focus traversal from every boundary control with keyboard and controller input. At no point may the focus owner be null, hidden, or outside the topmost blocking overlay; closing must restore the previously focused visible control or a documented safe fallback.

## AIF-002 — Run Menu is taller than the supported minimum window

- Severity: **High**
- Confidence: **High static geometry proof**
- Validation mode: **Static only; not runtime-reproduced in this follow-up**
- Affected configuration: the runtime's 640x360 safe-window floor; large text, 130% UI scale, and Play on small screen increase the overflow.
- Affected surface: Run Menu.
- Frequency: deterministic whenever Run Menu is opened at an available height below 430 pixels.

### Reproduction

1. Run on a constrained display where `UserSettings._safe_window_size()` returns 640x360.
2. Open Run Menu.
3. Repeat with Large text, 130% UI scale, and Play on small screen.

### Expected

The complete menu, including status, save/load, Journal, Settings, Abandon, Main Menu, tutorial action, and Resume, fits inside the viewport or uses a bounded scroll region. Every action remains visibly reachable.

### Actual

The Run Menu panel has a fixed 540x430 minimum inside a full-rect `CenterContainer`. It has no viewport-bounded layout method and no scroll container. At 640x360, its minimum is already 70 pixels taller than the whole viewport before margins, spacing, text growth, or small-screen control growth are considered. Centering necessarily places content outside the visible frame.

Small-screen accessibility increases every eligible control to a 52-pixel minimum (`scripts/ui/foundation_main.gd:19945-19959`), while large text/UI scale further increases font and control height. The menu contains four rows of actions plus heading, 50-pixel status, explanatory text, attribute legend, margins, and gaps, so accessibility settings compound rather than absorb the overflow.

### Player impact

Important run-management actions can be clipped at the top or bottom of the smallest supported window. A player may be unable to see the focused action or use the pointer to reach it, including actions required to save, abandon, or return to the main menu.

### Root cause

- The application deliberately permits a 640x360 safe window at `scripts/core/user_settings.gd:317-328`.
- Run Menu uses `custom_minimum_size = Vector2(540, 430)` at `scripts/ui/foundation_main.gd:9478-9506`.
- Eight menu buttons use a fixed grid and base 42-pixel rows at `foundation_main.gd:9537-9563`.
- `open_run_menu()` only refreshes content and shows the overlay; it performs no responsive layout (`foundation_main.gd:5972-5988`).
- Unlike World Map, Settings, Inventory, and Journal, no `_layout_run_menu` or viewport clamp exists.

### Fix options

1. Clamp the outer panel to viewport size minus safe margins and place the body/action grid in a vertical scroll container.
2. Use a one-column compact layout at narrow heights/widths while preserving 52-pixel touch targets.
3. Recompute layout after accessibility settings change and on viewport resize.
4. Add 640x360 tests for every text/UI-scale combination and assert each action can be scrolled into view and focused.

### Regression acceptance

At 640x360, verify default text and every supported accessibility combination, including Large text, 130% UI scale, and Play on small screen. Every Run Menu action must remain visible or scrollable, retain its minimum hit target, and expose a visible focus indicator without any panel edge leaving the safe viewport.

## AIF-003 — Run Journal's retained 600x440 minimum defeats its small-window clamp

- Severity: **Medium**
- Confidence: **High static geometry proof**
- Validation mode: **Static only; not runtime-reproduced in this follow-up**
- Affected configuration: 640x360 and other viewports shorter than 464 pixels; large text increases pressure.
- Affected surface: Run Journal.
- Frequency: deterministic at the affected sizes.

### Reproduction

1. Present the game at 640x360.
2. Open Run Journal and navigate through the entry list to its lowest content and Close action.
3. Check whether the entire panel remains inside the 12-pixel safe margins and whether the focused row remains visible.

### Expected

The journal panel fits inside 12-pixel safe margins, with its entry list scrolling internally.

### Actual

`_position_run_journal_popup()` calculates `360 - 24 = 336` pixels and assigns that as the panel height. The same panel still has `custom_minimum_size.y = 440`, and the function never clears or reduces it. Godot layout cannot shrink a Control below its combined minimum, so the requested 336-pixel bound is not authoritative; the panel/content extends below the viewport. The existing internal `ScrollContainer` cannot fix overflow of its own parent.

### Player impact

Journal entries and lower content are clipped, and focus can move into content outside the visible frame. Escape still provides a close route, so this is Medium rather than High.

### Root cause

- Fixed minimum: `scripts/ui/foundation_main.gd:8897-8906`.
- Responsive calculation requests a 336-pixel height but does not update `custom_minimum_size`: `foundation_main.gd:18440-18463`.
- Hide resets the panel size back to its unchanged minimum, reinforcing the mismatch: `foundation_main.gd:18465-18473`.

### Fix options

1. Set `custom_minimum_size` to the bounded popup size before assigning size/position, as the inventory overlays already do.
2. Keep header/Close fixed and let only the entry body scroll.
3. Add bounds assertions at 640x360, 800x450, 960x540, and Large text/130% UI scale.

### Regression acceptance

At 640x360, 800x450, and 960x540 under default and maximum text/UI scale, the panel rectangle must stay inside the 12-pixel viewport margins. Traversing every journal entry and Close must keep the focused control visible while only the entry body scrolls.

## AIF-004 — Shared chip settlement grammar emits “1 chips”

- Severity: **Low**
- Confidence: **High static data-flow proof**
- Validation mode: **Static only; not runtime-reproduced in this follow-up**
- Affected surface/resolutions: routed Grand Casino result text at every resolution.
- Frequency: every routed Grand Casino result whose absolute chip delta is exactly one; the exact occurrence rate depends on chosen game/stake.

### Reproduction

1. Produce a routed casino result with `chips_delta` equal to `1` or `-1`, such as a one-chip settlement.
2. Observe the appended shared settlement sentence.

### Expected

`Chip change: +1 chip.` or `Chip change: -1 chip.`

### Actual

The formatter always emits `Chip change: %+d chips.`, producing `Chip change: +1 chips.` The compatibility rewrite in the currency-routing layer can also convert an authored `$1` fragment into `1 chips`, so the malformed singular can occur twice in one routed message.

### Root cause

- `PlayerText.format_currency_settlement()` hardcodes the plural noun at `scripts/ui/player_text.gd:91-97` instead of using the same file's count-form boundary.
- `GameModule.finalize_routed_player_message()` appends this settlement to every nonzero routed result and rewrites `$N` to `N chips` without singular handling (`scripts/core/game_module.gd:855-880`).
- The new player-text regression contract verifies that chip currency is named, but does not exercise a one-chip delta.

This is not a refile of the old Baccarat sentence-joining or ticket/action examples. It is a new singular regression in the shared formatter added to remediate casino currency labeling.

### Fix options

1. Add a `chip` form to `COUNT_FORMS` and use it for absolute values while preserving the signed delta.
2. Replace regex rewriting of authored prose with structured message keys/parameters so currency nouns are formatted once.
3. Add `-1`, `0`, `+1`, and multi-chip cases to the shared player-text contract.

### Regression acceptance

The shared formatting contract must produce singular `chip` for `-1` and `+1`, plural `chips` for zero and magnitudes above one, preserve the delta sign, and avoid adding a second currency noun when authored text already contains the same settlement.

## Audited areas with no additional retained defect

- **World Map:** excluded because UIENV-PF-002 already owns its focus escape.
- **Settings and event-choice popup:** both have explicit focus traps and cancel routes; no new independent gap survived.
- **Tooltip/readability:** inventory slot truncation exposes full card text through `tooltip_text`; environment-label truncation remains owned by UIE-023. Numerous custom game-surface `.left(N)` caps remain localization risk, but no new root distinct from the existing truncation family was filed.
- **Hit-target authority:** native controls are raised to the 52-pixel small-screen minimum by the accessibility transform, and inventory/meta close controls have explicit small-screen sizing. The expanded scenario/base target omission remains owned by UIENV-PF-009.
- **Time formatting:** HUD and report paths now use `PlayerText.format_game_clock()`; no remaining independent 24-hour inconsistency was proven.
- **Known plural family:** additional hand-built plural risks exist, but instances sharing EXT-TXT-004's already documented root were excluded. AIF-004 was retained because it is a regression in the new shared remediation boundary.
- **Localization infrastructure:** the repository still has zero `tr(...)` calls and no translation catalogs. As in the prior localization report, the current product exposes no non-English locale contract, so this remains readiness debt rather than a counted defect.
- **Runtime:** no Godot process was launched, inspected, interrupted, or terminated in this wave.

## Final disposition

- New retained findings: **4**
- High: **2**
- Medium: **1**
- Low: **1**
- Product fixes made: **none**
- Runtime used: **none**
