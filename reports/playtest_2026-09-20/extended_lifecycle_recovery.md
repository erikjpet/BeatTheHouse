# Beat the House — Extended Lifecycle and Recovery Static Playtest

Date: 2026-09-20  
Owner: lifecycle/recovery specialist  
Disposition: investigation and documentation only; no product, test, or data files were changed  
Method: bounded static-only audit; Godot was not launched while the performance-soak worker owned runtime

## Executive summary

This pass retained **three independently supportable production defects**:

1. The run clock, autoplay, real-time table state, and environment runtime have no application-focus or minimization pause owner.
2. A game-surface drag/hold has no authoritative cancel route for OS focus loss, pause, or minimization.
3. Settings Back can leave an uncommitted High Contrast draft value active in the global palette.

The review also covered WM-close/in-game Exit, main-menu cleanup, overlay teardown, run-UI load failure, and message/banner presentation. Those paths either had explicit recovery handling or belonged to already reported accessibility, audio, persistence, or harness findings and were not duplicated.

Detailed static evidence is in `.tmp/playtest_extended/lifecycle_recovery/static_audit.md`.

## Defects

### LIFE-001 — Alt-tab or minimization does not suspend time-sensitive gameplay

- Severity: **High**
- Confidence: **High (static control-flow proof)**
- Affected state: any active non-meta run, especially an auto-resolving game or time-sensitive environment
- Reproduction:
  1. Start a run with the continuous environment clock active.
  2. Enter a game that uses auto ticks or real-time surface state.
  3. Alt-tab away from the application or minimize its window for a meaningful interval.
  4. Return and inspect clock, automated actions, and table/environment state.
- Expected: losing application visibility/control suspends player-affecting simulation, or the game explicitly warns and obtains consent to continue in the background.
- Actual from code: `_process()` continues to call the run clock, game automation, real-time surface refresh, and environment runtime. None of those paths checks application focus or minimized state.
- Root cause:
  - `FoundationMain._process()` unconditionally enters progression paths on each process frame (`scripts/ui/foundation_main.gd:689-734`).
  - The clock, automation, and real-time guards recognize internal simulation pause state, but not OS lifecycle state (`foundation_main.gd:737-746`, `2836-2864`, `2879-2900`).
  - The root notification handler recognizes resize and WM close only (`foundation_main.gd:787-797`). A repository-wide search found no application-focus/pause or minimized-window handler.
- Player impact: time can elapse and automatic wagers or table transitions can resolve while the player cannot observe or intervene. This can change bankroll, deadlines, and run state merely because the player switched applications.
- Fix options:
  1. Add application focus/visibility as an explicit simulation pause owner and gate clock, automation, real-time game state, and environment runtime with it.
  2. Handle application focus-out/in and pause/resume notifications centrally, leaving non-gameplay maintenance such as save completion separately controlled.
  3. If background play is intentional, make it an opt-in setting and surface an unmistakable warning/state indicator.
  4. Add integration coverage that focuses out/minimizes during continuous clock, autoplay, and a real-time table, asserting no player-affecting state change until focus returns.

### LIFE-002 — OS focus loss can strand or later complete a stale game-surface hold

- Severity: **High**
- Confidence: **High (missing lifecycle route; existing cancel contract proves required cleanup)**
- Affected interactions: drag/hold surfaces such as Coin Pusher charge/carriage input and other games using `surface_pointer_action` begin/move/end/cancel phases
- Reproduction:
  1. Begin a mouse drag, touch drag, keyboard hold, or controller hold on a game-surface region.
  2. While still held, alt-tab, minimize, or otherwise deactivate the application window.
  3. Release the input outside the application, then return.
  4. Move/click/press on the game surface again.
- Expected: application deactivation immediately emits one `cancel`, clears capture, and prevents any interrupted gesture from placing a wager or retaining charge/drag state.
- Actual from code: capture clears on a later ordinary release, a Control-level GUI focus exit, or canvas invisibility. There is no handler for application/window focus loss, pause, or minimization.
- Root cause:
  - Drag capture and keyboard/controller hold capture store persistent action state and emit `begin` (`scripts/ui/game_surface_canvas.gd:1141-1149`, `1174-1208`).
  - The explicit safe recovery method emits `cancel` and clears all capture fields (`game_surface_canvas.gd:1219-1231`).
  - `_notification()` calls it only for `NOTIFICATION_FOCUS_EXIT` on the Control and visibility loss (`game_surface_canvas.gd:1234-1238`). OS deactivation is a separate lifecycle event and may preserve the GUI focus owner for restoration.
  - The existing regression test injects only `Control.NOTIFICATION_FOCUS_EXIT`, so it does not cover the missing application-focus boundary (`scripts/tests/foundation/check_coin_pusher.gd:457-461`).
- Player impact: an interrupted hold can remain logically active after returning, retain stale charge/drag state, or complete on a later unrelated release. For wager-bearing gestures, this risks an unintended action.
- Fix options:
  1. Route root application focus-out, application pause, and window-hide/minimize events to `GameSurfaceCanvas._cancel_captured_surface_pointer()`.
  2. Make cancellation idempotent and clear any coalesced move before processing focus-in input.
  3. Add a lifecycle integration test that begins each input modality, delivers application focus-out without a release, and asserts exactly one cancel plus empty capture state.
  4. On focus-in, reject orphan release/motion events until a fresh press begins a new gesture.

### LIFE-003 — Settings Back can leak an unsaved High Contrast choice globally

- Severity: **Medium**
- Confidence: **High (deterministic static state-flow proof)**
- Reproduction:
  1. Open Settings with High Contrast disabled.
  2. Enable High Contrast, but do not select Apply.
  3. Change Text Size or Play on Small Screen.
  4. Select Back.
  5. Open another screen or rebuild controls that consume the global visual palette.
- Expected: Back discards every draft setting and restores all live/global presentation to the last committed settings.
- Actual from code: changing Text Size or Play on Small Screen calls the preview refresh, which reads the entire draft and publishes its High Contrast value into global `VisualStyleScript`. Back hides Settings without restoring the committed palette.
- Root cause:
  - Settings explicitly edits a draft copied on open (`scripts/ui/settings_menu.gd:60-67`).
  - High Contrast changes the draft, while the Text Size and Small Screen callbacks invoke `_apply_accessibility_settings()` (`settings_menu.gd:394-427`).
  - That method reads the draft's High Contrast value and mutates global visual-style state (`settings_menu.gd:474-487`).
  - Back emits only a close request, and both visibility teardown and `FoundationMain.close_settings_menu()` omit palette rollback (`settings_menu.gd:162-164`, `211-219`; `scripts/ui/foundation_main.gd:16242-16256`).
- Player impact: a setting the player canceled can affect later/rebuilt controls, while disk and live `UserSettings` still report the old value. The UI can therefore present a mixed or unexpectedly high-contrast palette until another apply/restart path repairs it.
- Fix options:
  1. Keep preview palette state scoped to the Settings subtree; publish global `VisualStyle` only after Apply commits the draft.
  2. Alternatively snapshot the committed global palette on open and restore it on every non-Apply close path.
  3. Give Settings an explicit `commit` versus `cancel` close contract instead of treating visibility loss as teardown.
  4. Add a regression matrix for each draft field followed by Back, asserting `UserSettings`, global visual-style state, and newly constructed controls all match the pre-open committed state.

## Recovery paths reviewed without a new finding

- WM close and in-game Exit both establish an explicit synchronous autosave boundary. Save-write failures remain owned by the persistence report.
- Return to Main Menu clears game runtime, bindings, selection, guidance, overlays, focus, and run state, then restores the complete menu surface.
- Run-UI load failure is surfaced on the main menu, launch controls are disabled with explanatory tooltips, and refresh re-presents the failure.
- The hidden legacy message label feeds visible result/consequence presenters; it is not a lost player-facing error banner.
- Decision-popup focus ownership and Settings Escape behavior were excluded as duplicates of A11Y-006 and A11Y-002.
- Audio behavior, persistence behavior, and known runtime-harness ownership failures were intentionally excluded.

