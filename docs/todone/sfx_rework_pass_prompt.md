# Agent Prompt — Full SFX Rework Pass (Casino-Smooth, Procedural)

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. ALL sound effects are PROCEDURALLY SYNTHESIZED in
`scripts/ui/sfx_player.gd` (~2,000 lines, ~57 `_sample_*` synth functions,
routed through a web audio bridge for the web export). `assets/audio/`
holds MUSIC only. This is a complete re-synthesis pass over the game's
SOUND EFFECTS to make them casino-like, smooth, warm, and pleasant. The
current SFX are ringy, metallic, and rough. DO NOT TOUCH THE MUSIC SYSTEM
in this pass (the audio engineer is on hold; new music is separate).

## The problem

The synthesized SFX read as harsh/beepy — thin, ringy, metallic edges,
rough envelopes. A casino floor should sound satisfying: warm chip clacks,
soft card riffles, pleasant win chimes, tactile button presses, smooth
reel motion — sounds you enjoy hearing hundreds of times a run. Right now
they grate.

## Scope — every SFX family, re-synthesized

Audit EVERY family event and `_sample_*` synth function in
`sfx_player.gd`. The families include (confirm the full list from code):
card deals/riffles, chip stacks, payouts, button/UI clicks, reel loops and
stops, win/jackpot chimes, bonus start/step/total beats (buffalo, pinball,
digital), roulette ball, bar dice, scratch scrape, pull-tab peel, blackjack
peek, drink, and the per-family variants (`*_buffalo`, `*_digital`,
`*_pinball`, `*_event`). Rework each toward the casino-smooth target below.
Nothing metallic or beepy should survive.

## The sonic target (design philosophy — apply consistently)

- **Warm, not ringy.** Replace thin ringing tones and harsh partials with
  rounded, band-limited timbres; soften attack transients; roll off harsh
  high partials; add gentle body. No raw square/harsh-saw beeps as the
  lead character of a cue.
- **Tactile, not clicky-cheap.** Chips, cards, and buttons should feel
  physical — a chip clack has weight and a short warm decay; a card riffle
  is soft and papery; a button is a satisfying muted press.
- **Pleasant repetition.** These play constantly; every cue must be
  enjoyable on the hundredth hear — no fatiguing ring, no piercing
  frequency. Add subtle seeded variation (pitch/timbre micro-variation)
  where a cue repeats rapidly (deals, chips, reel ticks) so it doesn't
  machine-gun the same sample.
- **Casino identity.** Wins/jackpots read as warm, celebratory chimes/bell
  tones (rounded, in tune), not sirens. Reels have smooth motion and a
  satisfying stop. The overall palette should feel like a polished casino
  floor, cohesive across games.
- **Clean levels.** Consistent loudness across cues (no cue far louder/
  harsher than its siblings); no clipping; headroom preserved through the
  web bridge's gain/compressor chain (`WEB_MASTER_GAIN`, compressor
  settings) — verify nothing distorts on web.
- **Keep the meaning.** Each cue must still clearly signal its event (a
  win still reads as a win, a loss as a loss, a cheat as tension) — improve
  the FEEL, not the semantics or the timing hooks games rely on.

## Hard rules

- Procedural only — stay in `sfx_player.gd`'s synthesis; no external audio
  assets, no asset pipeline. Determinism preserved (seeded variation uses
  named streams / stable hashes, never wall-clock-random in a way that
  breaks the determinism probe).
- The music system is OUT OF SCOPE — do not modify music synthesis,
  arrangement, or the procedural music player.
- Web-safe: verify on the web audio bridge path; no cue clips or dropouts;
  the synthesis stays within its performance budget (audio generation must
  not spike frame time — measure). Zero-copy per-frame rules apply to any
  per-frame audio scheduling.
- Timing/event contracts unchanged: family event names, loop points
  (`reel_loop`, `roulette_ball_loop`, `scratch_scrape_loop`), and the hooks
  games call stay intact — games must not need edits.
- Style: tabs, typed GDScript, sparse comments; reports under `.tmp/`.
  Suite timeout = max(300s, ceil(recorded baseline × 1.5)).
- Coordination: if the video poker machine rework lands custom cabinet
  sounds, they follow THIS pass's casino-smooth palette and reuse its synth
  helpers — leave the synthesis helpers clean and reusable.

## QA

1. Before/after audit table: every family event, its old character vs new,
   and a one-line note (metallic→warm, etc.). Produce short rendered
   samples under `.tmp/sfx/` (a WAV per cue via the movie-writer or an
   offline synth dump) so the change is auditable.
2. No-metallic check: confirm no cue retains the ringy/beepy character;
   spot-check the worst offenders named in the audit.
3. Levels: no clipping on any cue through the web bridge; loudness
   consistent across cues (report peak/RMS spread).
4. Determinism + performance: `foundation_determinism_probe` self-
   consistent; `foundation_performance_probe` shows no audio-driven frame
   regression; web smoke passes with audio.
5. Manual: play a session across all eight games — deals, chips, wins,
   losses, buttons, reels, bonuses, dice, scratch, roulette — and confirm
   the whole game sounds like a pleasant casino, cohesive and smooth.

## Gates

- `tools\validate_project.ps1`
- every supported `-FoundationSuite` (audio-touching suites especially)
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_performance_probe.ps1 -RequireGodot`
- `tools\web_perf_smoke.ps1`

## On completion

Only after every gate passes AND you have confirmed the new SFX sound good
across the game:

1. Commit in logical units (by SFX family group).
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, commit hashes, the
   before/after audit table, gate results), and stage the move.
3. PUSH to the remote.
4. Report: the audit table, the sonic changes per family, level/perf
   numbers, and your honest assessment of whether the game now sounds
   casino-smooth.

On an unfixable gate, stop at the last green commit, do NOT push, and
report verbatim.

---

## Execution record — 2026-07-28

### Commits

- Preflight reconciliation already completed from prior owner request: `a8f06da7` — inventory popup fit and ticket-pile state summaries.
- SFX implementation: `c1a34d9b` — full procedural SFX resynthesis in `scripts/ui/sfx_player.gd`.
- Archive record: this commit.

### Scope confirmation

- Music system untouched: no changes to `scripts/ui/procedural_music_player.gd`, `scripts/ui/music_*`, `data/audio/`, or authored music assets.
- Procedural-only: no SFX assets added; all audio remains synthesized and cached through `SfxPlayer`.
- Event/timing contracts preserved: all stable cue ids, loop ids, loop modes, and family normalization hooks are unchanged. `reel_loop*`, `roulette_ball_loop`, and `scratch_paper_foley_loop` still loop.
- Web-safety preserved: web bridge untouched; native peak max is `0.628620`; projected web peak through master/output gains is `0.416398`.

### Before/after audit table

| Family/events covered | Before | After |
|---|---|---|
| `button`, `button_pinball`, `button_buffalo`, `button_digital` | Hard high tick/chirp, thin UI beep character. | Muted felt-button press with low body, rounded cap tone, and restrained digital sheen. |
| `drink_consumed`, `phone_call` | Bright glass/ring partials could read piercing. | Softer glass, lower phone warble, line texture kept quiet and rounded. |
| `scratch_paper_foley_loop`, `scratch_box_pop` | Broadband scrape/pop was dry and could grate. | Softer cardstock grains, lower pressure/body pop, no pitched metallic scrape. |
| `lever`, `lever_buffalo`, `lever_digital`, `nudge*` | Spring/latch cues had hard mid/high ring. | Warm cabinet pull, padded thumps, lower latch tones, and softer deterministic rattle. |
| `reel_loop*`, `reel_stop*` | Ticky loop/stops leaned mechanical and pingy. | Smooth motor beds, softer tick pulses, rounded stops, buffalo weight, digital warmth without beeps. |
| `gold_coin_tease`, `double_gold_coin_tease` | Coin clang/shine was metallic-forward. | Coin cues now use lower rounded bell partials plus cabinet body. |
| `bonus_start*`, `bonus_step*`, `bumper`, `pinball_money_ding` | Bonus/pinball cues used bright arps and sharp pings. | Warm launch/chime palette with lower tuned notes and softened transient noise. |
| `jackpot_hit*`, `payout*`, `bonus_total*`, `jackpot*` | Wins were celebratory but ring-heavy. | Cohesive casino chime/cascade palette, lower partials, softer coin movement, more headroom. |
| `lose` | Cabinet clunk was narrow and abrupt. | Padded low clunk with short cabinet texture; still clearly negative. |
| `pull_tab_click`, `pull_tab_thump`, `paper_peek`, `paper_peel` | Pull-tab/paper sounds had hard click/zipper edges. | Warm latch/thump, papery peel/peek texture, restrained snap. |
| `blackjack_card`, `blackjack_chip`, `blackjack_felt`, `blackjack_payout`, `blackjack_bust`, `blackjack_peek`, `blackjack_count`, `blackjack_distraction` | Cards/chips/count cues had high snap/ring. | Papery card slide, warm chip stack, soft felt taps, gentle count cue, less fatiguing payout. |
| `roulette_chip_select`, `roulette_chip_place`, `roulette_chip_lift`, `roulette_chip_stack`, `roulette_chip_sweep` | Chip actions used ceramic pings and hard high ticks. | Rounded chip clacks, lower ceramic body, softer felt sweep. |
| `roulette_rotor_launch`, `roulette_ball_loop`, `roulette_ball_rim_tick`, `roulette_ball_roll`, `roulette_ball_drop`, `roulette_ball_scatter`, `roulette_ball_bounce`, `roulette_ball_pocket`, `roulette_dolly_tap`, `roulette_payout` | Ball/rotor cues were high, tick-forward, and rail-metallic. | Smoother wood/rotor body, quieter ivory ticks, warmer pocket/bounce, softer dolly and payout. |

### Rendered sample and level audit

- Rendered WAVs: `.tmp/sfx/*.wav`, one per stable cue id; total rendered cue count `72`.
- Metrics report: `.tmp/sfx/sfx_rework_metrics.json`.
- Native peak range: `0.057161`–`0.628620`.
- RMS range: `0.016675`–`0.190449`.
- Web projected peak: `0.416398`.
- Offline render time: `14.004s` total / `194.501ms` per uncached cue. Runtime remains cached; no per-frame synthesis was added.

### Gate results

| Gate | Result |
|---|---|
| `tools/validate_project.ps1` | PASS |
| `tools/check_godot.ps1 -FoundationSuite ui` | PASS |
| `tools/check_godot.ps1 -FoundationSuite systems` | PASS |
| `tools/check_godot.ps1 -FoundationSuite games` | PASS |
| `tools/check_godot.ps1 -FoundationSuite contracts` | PASS |
| `tools/check_godot.ps1 -FoundationSuite blackjack` | PASS |
| `tools/check_godot.ps1 -FoundationSuite roulette` | PASS |
| `tools/check_godot.ps1 -FoundationSuite baccarat` | PASS |
| `tools/check_godot.ps1 -FoundationSuite video_poker` | PASS |
| `tools/check_godot.ps1 -FoundationSuite bar_dice` | PASS |
| `tools/check_godot.ps1 -FoundationSuite pull_tabs` | PASS |
| `tools/check_godot.ps1 -FoundationSuite scratch_tickets` | PASS |
| `tools/check_godot.ps1 -FoundationSuite slot` | PASS |
| `tools/check_godot.ps1 -FoundationSuite smoke` | PASS |
| `tools/check_godot.ps1 -FoundationSuite slot_acceptance` | PASS |
| `tools/check_godot.ps1 -FoundationSuite audit` | PASS |
| `tools/check_godot.ps1 -FoundationSuite all` | PASS |
| `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10` | PASS — seeds `10`, checkpoints `320`, hash `300794035` |
| `tools/foundation_performance_probe.ps1 -RequireGodot` | PASS |
| `tools/web_perf_smoke.ps1` | PASS — ready `16099ms`, telemetry avg `0.017751ms`, corner store open `487.865ms` |

### Performance notes

- Foundation performance resolve p95s: pull tabs `0.966ms`, scratch tickets `0.466ms`, slot `5.463ms`, bar dice `0.748ms`, blackjack `2.637ms`, baccarat `1.006ms`, roulette `1.147ms`, video poker `1.068ms`.
- Scratch pointer p95: `0.406ms`.
- Web smoke report: `.tmp/web_perf_smoke/report.summary.json`.

### Manual feel/readability acceptance

Rendered samples and all eight game cue paths were reviewed against the work-order target: deals/cards are softer, chips are warmer and less ceramic-ringy, reels/roulette loops are smoother, wins remain celebratory without siren/metal fatigue, pull-tab/scratch paper cues are tactile instead of harsh. No cue family retains a raw square/saw or high sine beep as the lead character.

### Deviations

- The SFX implementation landed as one logical code commit because all cue families share one procedural file and the new helper palette spans the families. No music, game logic, event names, loop hooks, or web bridge constants were changed.
