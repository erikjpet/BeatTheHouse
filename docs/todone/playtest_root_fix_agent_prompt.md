# Agent Prompt — Playtest Bug Root Fixes (Roulette / Video Poker / Pull Tabs / Betting UX)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4 GDScript casino roguelike. All game rendering is immediate-mode GDScript drawing onto `GameSurfaceCanvas` (scripts/ui/game_surface_canvas.gd); game logic lives in per-game modules under scripts/games/ that communicate with the host (scripts/ui/foundation_main.gd, ~11k lines) through dictionary "surface commands" and "surface state" snapshots. The design-space board is 900x430 (scripts/core/art_contracts.gd `GAME_BOARD_SIZE`).

Your job is to implement **final, root-cause fixes** for the playtest bugs below. Prior sessions shipped repeated hotfixes for some of these (commits 22deecb, dc09d69, f6330e8, 9510f94 — "Keep roulette idle on full wheel motion layer", "Keep roulette wheel labels locked after spins"); those were band-aids on a duplicated rendering system. Do not add another band-aid. Where a redundant or half-finished system is the cause, remove or consolidate the system.

## Hard constraints

1. **Do not extensively run the built-in QA suites.** `scripts/tests/foundation_check.gd` and `ui_scene_compile_check.gd` are large and slow. Verify primarily by reading code and reasoning about data flow. At the very end you may run a single targeted compile/smoke pass; do not iterate against the full QA harness. If an existing QA check hard-codes behavior you are deliberately changing (e.g. asserts the ambient overlay is active for roulette, or asserts the 20s timer), update that check to match the new intended behavior rather than contorting the fix.
2. **Preserve the uncommitted work already in the tree.** `scripts/games/roulette.gd`, `scripts/ui/foundation_main.gd`, and `scripts/tests/foundation_check.gd` have in-progress changes (wheel label drawing via `surface_label_plain`, outside-bet minimum chip logic, explicit `surface_audio_cue` routing plus `_play_surface_command_audio` in the host). Build on them; do not revert them.
3. Per-frame code paths must stay zero-copy (no `duplicate(true)` of live state per frame) — this codebase previously shipped 32ms/frame regressions from exactly that (see slot.gd watchdog history).
4. Match existing code style: tab indentation, typed GDScript where present, sparse comments stating constraints only.

## Architectural root cause you must fix first (drives bugs 1 and 5)

`GameSurfaceCanvas` renders the full scene via the game module's `draw_surface()` on the main canvas, but to keep idle animation cheap it also owns a second child Control, `AmbientSurfaceOverlay` (game_surface_canvas.gd:57), that redraws every frame **on top of the main canvas's last (stale) frame**. For roulette the overlay id is `roulette_full_idle` (roulette.gd:160, active whenever the table isn't barred), and `_draw_roulette_full_idle_overlay` (game_surface_canvas.gd:841) calls the module's `_draw_roulette_wheel`, `_draw_croupier_station`, `_draw_table_patrons`, and `_draw_round_timer` a **second time** over the base frame.

Consequences:
- Every drawn element in that list exists twice on screen. When the overlay's wheel rotation drifts from the angle baked into the stale base frame, the player sees a frozen ring of numbers with a second live ring spinning over it (**bug 5**).
- The overlay's croupier is drawn after (above) the base frame's recent-numbers panel, so the dealer and attention meter cover it (**bug 1**).
- Every animated frame pays for the wheel/patron/dealer draw twice — pure waste on low-end/web targets, which is the 0.3.2 focus.

**Required fix: single ownership per drawn element.** Choose and implement one consolidation cleanly:
- (a) Remove `roulette_full_idle` overlay duplication entirely: while roulette should animate (which is effectively always — idle wheel motion, spin, payout), let the *main* canvas redraw on the existing animation cadence (`_surface_animation_redraw_due` / `_needs_continuous_redraw` in `_process`, game_surface_canvas.gd:683) so there is exactly one wheel ever drawn. Profile-mindedly: the roulette full scene draw must then be cheap enough — if the full-scene redraw is too heavy, split `draw_surface` so static background (room, table felt, betting grid) is drawn once into a cached texture/`draw` layer and only dynamic elements redraw per tick.
- (b) Keep the overlay as the sole owner of the animated elements and make the module's base `draw_surface` skip exactly those elements whenever the overlay is active — with the activation predicate shared (one function, not two copies that can drift; note `_ambient_surface_overlay_active` currently disables the overlay while any animation channel runs, which is exactly when the base frame and overlay trade ownership and produce the stuck-copy handoff artifacts).

Option (a) is preferred if performance allows: it deletes a whole coordination system rather than patching its seams. Whichever you choose, also audit `table_idle` (blackjack/baccarat/bar_dice use it — blackjack.gd:260, baccarat.gd:167, bar_dice.gd:291) for the same double-draw of dealer/patrons/timer and apply the same ownership rule so the fix is uniform, not roulette-only.

## Bug list with investigated root causes

### 1. Roulette recent-spins panel hidden behind the dealer
- Panel: `_draw_recent_numbers` (roulette.gd:2126) draws at `Rect2(246, 84, 492, 28)`.
- Dealer station: `TableVisualsScript.draw_dealer_station` (table_game_visuals.gd:77) fills `Rect2(352, 54, 196, 104)` plus the attention meter — directly overlapping the panel; and the ambient overlay re-draws the dealer *above* the panel (see architectural section).
- Fix: move the recent-numbers strip to the top of the board (a clear strip along y≈4–34 works; the room title from `TableVisualsScript.draw_room` is the only occupant up there — check `_roulette_room_info` rendering and reposition/shrink as needed so nothing overlaps). It must render above the dealer and never be repainted-over by any overlay (this falls out of the single-ownership fix).

### 2. Selected chip / bet amount resets to default after every bet (all games)
- Root cause: `_resolve_game_action` (foundation_main.gd:4894) wipes the whole per-game session at line 4943–4944: `if not preserve_surface_ui_state: game_surface_ui_state = {}`. The wipe flag comes from three places that all default to destroy:
  - `GameModule.surface_command()` defaults `preserve_surface_ui_state` to **false** (game_module.gd:346).
  - Roulette's auto-spin command explicitly passes `"preserve_surface_ui_state": false` (roulette.gd:354).
  - Video poker's `_action_command` sets `preserve: not resolving` (video_poker.gd:2270), and resolve results (`_build_result`, video_poker.gd:2306) carry no `ui_state`, so the wipe fires after every resolved hand — resetting `bet_level`/`denomination_index` (the "bet goes back to default" report).
- Fix at the root, once, in the host: player *bet preferences* must survive session wipes. Introduce a preserved-keys contract — when `game_surface_ui_state` is cleared after a resolve, carry over a small whitelist (`selected_chip`, `selected_stake`, `bet_level`, `denomination_index` — grep each module's `_normalized_ui_state`/session normalizer for its preference keys: roulette.gd, video_poker.gd, pull_tabs.gd, blackjack.gd, baccarat.gd, bar_dice.gd) instead of nuking to `{}`. Modules that intentionally reset a preference can still overwrite it explicitly. Do **not** fix this per-game with scattered `preserve_surface_ui_state: true` flags — that leaves the default-destructive trap for the next module.

### 3. Roulette chips vanish from the layout during the spin
- Same wipe: the auto-spin's `preserve_surface_ui_state: false` clears `roulette_bets` from the session the moment the spin resolves (resolution happens at spin *start*; the 5s wheel animation plays out of `last_result` afterwards). `_draw_bet_chips` (roulette.gd:2208) reads session `roulette_bets`, so chips disappear at ball launch.
- Required behavior: chips stay on the layout during the whole spin; losing chips are swept only once the result is revealed; winning chips get their payout presentation (which already exists — `_draw_bet_chips` draws winner chips from `last_result.bet_results` post-spin, and `_draw_payout_animation` at roulette.gd:2351 animates payouts).
- Fix: during the spin/reveal window, draw the wagered chips from `last_result.bet_results` (each entry already carries `placement` and `stake` — see `_resolve` around roulette.gd:2535–2547). Sweep losing chips exactly when the payout phase starts (`ROULETTE_PAYOUT_CHANNEL` active or `spin_elapsed_msec >= SPIN_ANIMATION_DURATION_MSEC`), optionally with a brief croupier-sweep animation, but correctness first: losers visible until result known, gone after.

### 4. Player can bet on the next round while the wheel is spinning
- **Both** gates that should prevent this are no-ops:
  - `_surface_locked` (roulette.gd:2699) is `return false` — vestigial stub. The "No more bets while the wheel is moving." branch at roulette.gd:366 can never fire.
  - `_surface_action_blocks(blocked)` (roulette.gd:2689) emits `{"action": ..., "reason": ...}` entries with **no** `while_animation` channel, and the canvas consumer `_surface_action_blocked` (game_surface_canvas.gd:1390) skips any block whose `while_animation` is empty (line 1398–1399). So the canvas-side blocking is also dead code.
- Fix both layers:
  - Implement `_surface_locked` for real: derive spin/payout activity from the stored table's `last_result.resolved_at_msec` vs now (the same math as `spin_active`/`payout_active` in `surface_state`, roulette.gd:150–152 — factor it into one shared helper; `_roulette_motion_active` already exists, check whether it is the right predicate and reuse it). This is the authoritative, module-side gate: no bet placement, clear, undo, rebet, double, or chip-follow mutations while the wheel or payout is running.
  - Make the canvas honor unconditional blocks: in `_surface_action_blocked`, treat an entry without `while_animation` as always-blocking (that is clearly what the roulette code intended), and surface the block `reason` as the click feedback message.
  - While you're in there, check baccarat's `_surface_locked` (baccarat.gd:1933) actually works, since it shares the pattern.

### 5. Duplicate/stuck wheel numbers during spin
- Root cause and fix: the AmbientSurfaceOverlay double-render described in the architectural section. The uncommitted `surface_label_plain` label change in `_draw_roulette_wheel` (roulette.gd:1936ff) treats a symptom (label fit-cache jitter); keep it, but the duplication only ends when exactly one canvas layer draws the wheel per frame. After your fix, verify by reasoning through the frame flow: at any instant, which CanvasItem draws pockets/labels? There must be exactly one answer in idle, during spin, and during the idle↔spin transitions.

### 6. Roulette spin interval: 20s → 40s
- The interval is `GameModule.TABLE_ROUND_START_DELAY_MSEC := 20000` (game_module.gd:10), shared by blackjack, baccarat, and bar dice. **Only roulette should change.**
- Fix: add a roulette-local `const ROULETTE_ROUND_DELAY_MSEC := 40000` and pass it as the `duration_msec` argument at the three roulette call sites: roulette.gd:163 (`table_round_timer_status_peek` in `surface_state`), :316 (`surface_needs_auto_tick`), :338 (`surface_auto_action_command`). All three must agree or the auto-tick scheduler and the on-screen countdown will desync. Check foundation_check.gd for any assertion pinning the 20s value and update it.

### 7. Pull tabs "TOP" overlay appears on buy buttons/rows
- Two badge sites render when a deal's top prize is exhausted: pull_tabs.gd:2838–2841 (ticket-stack "TOP" strip) and pull_tabs.gd:2881–2882 (column-button "TOP-" label). The product decision is to **remove this indicator entirely** — delete both `elif not bool(deal.get("top_prize_available", true)):` branches. Then check whether `top_prize_available` / `_deal_top_prize_summary` (pull_tabs.gd:2014) still has any consumer; if the only consumers were these badges, remove the dead plumbing too (search the whole repo for `top_prize_` before deleting — there are view fields at pull_tabs.gd:2027–2039 that may feed other UI or QA).

### 8. Video poker freezes after a hand and won't accept bets
This one needs diagnosis before the fix; here are the investigated leads, in likelihood order:
- **Stuck flip animation channel.** `surface_state` publishes `FLIP_CHANNEL`/`DRAW_CASCADE_CHANNEL` with `started_msec` = `last_result.resolved_at_msec` (video_poker.gd:428–441, `_active_flip` at 2298). `resolved_at_msec` comes from `GameModule.deterministic_time_msec(run_state, ui)` (game_module.gd:323): it uses `ui_state.surface_time_msec` when present, else `run_state.simulation_time_msec()`. The host stamps `surface_time_msec` on the ui_state it passes to `surface_state` (foundation_main.gd:823) — but verify whether `_current_game_surface_ui_state()` used in `_resolve_game_action` (foundation_main.gd:4916) carries that stamp at resolve time, especially after the session wipe from bug 2. If `resolved_at_msec` is ever a *simulation* timestamp larger than `Time.get_ticks_msec()`, `surface_elapsed` (game_surface_canvas.gd:395, `maxi(0, ticks - started)`) returns 0 forever → the flip channel never completes → cards render permanently mid-flip (`_draw_card_row` gates on flip progress at video_poker.gd:2457) and `_needs_continuous_redraw` burns frames forever. That presents exactly as "froze after a hand."
- **Phase machine stranding.** Phase derives from ui flags (`hand_active`, `collected`, `double_active`, video_poker.gd:313–320). After the bug-2 whitelist change, re-verify every path: draw resolve wipes the session (via `_action_command` preserve=not resolving) so flags reset — confirm the preserved-keys change keeps *preferences* but still clears `hand_active`/`double_active`/`holds`/`deal_id` (those must NOT be whitelisted, or you'll create the stranded-hold freeze). Also check `double_active` with `_pending_double_credits > 0` (phase `double_up` disables betting, video_poker.gd:2633) — if the double-up resolve fails or is interrupted, is there any path back to `settled`?
- **Modal guard.** `_resolve_game_action` can detour into the all-in wager confirmation popup (foundation_main.gd:4908–4911); if that popup is pending, `_guard_player_input_route` (foundation_main.gd:5072) blocks all input. Confirm the popup is actually reachable/dismissible from the embedded video-poker surface.
Implement the real fix for whichever cause you confirm (fix the timestamp contract at its source — one clock domain for animation `started_msec`, wall-clock ticks — rather than clamping symptoms), and make sure a defensive recovery exists: a settled/idle machine must always accept DEAL.

## Cleanup expectations (part of the deliverable, not optional)

- Delete dead systems you decommission: the vestigial `_surface_locked` stub becomes real code (bug 4); the roulette overlay duplication path and any now-unused overlay draw helpers go away or gain a single owner (bug 5); dead `top_prize` plumbing goes if unconsumed (bug 7).
- Do not leave two sources of truth for spin-phase math — `surface_state`, `surface_needs_auto_tick`, `surface_auto_action_command`, `_surface_locked`, and the chip-draw phase logic should all read one shared helper for "is the wheel/payout running".
- Keep per-frame paths allocation-free; `surface_needs_auto_tick` deliberately uses `_peek_table_state` zero-copy views (roulette.gd:322) — follow that pattern.

## Verification (lightweight, code-first)

- For each bug, state the root cause you confirmed, the fix, and trace the data flow that proves the symptom is gone (e.g. for bug 4: click during spin → `surface_action_command` → `_surface_locked` true → message command; and canvas-level: block entry matched → input swallowed).
- Launch-free static verification is preferred. At the end, run at most one targeted syntax/compile validation of the changed scripts (e.g. a headless `godot --check-only` style pass or the single compile-check script) — not the full QA suites.
- Summarize which QA assertions you had to update and why.
