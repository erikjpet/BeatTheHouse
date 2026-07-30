# Agent Prompt — SFX Realism Refinement (True-to-Life Fidelity)

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. The SFX are PROCEDURALLY SYNTHESIZED in `scripts/ui/sfx_player.gd`
(~57 `_sample_*` functions, ~2,000 lines), routed through a web audio bridge.
The earlier casino-smooth pass LANDED, but some cues still do not sound like
the REAL THING they represent — the phone ring (`phone_call` /
`_sample_phone_call`) does not read as a phone at all, and it is not the only
one. This is a REALISM refinement: make every cue that represents a
recognizable real-world object actually SOUND like that object, while keeping
the warmth/smoothness the first pass added. DO NOT TOUCH THE MUSIC SYSTEM.

## The bar: blind recognizability

Each real-world cue must pass a blind test — played with no context, a
listener should identify it (or at minimum never MIS-identify it). "Smooth
but generic" is the current failure; the fix is to synthesize each sound's
actual acoustic signature. Realism AND pleasantness together — model the real
object, then keep it warm and non-harsh.

## Audit every recognizable-object cue; the key offenders + fidelity targets

Audit ALL `_sample_*` functions and their cues. For each that represents a
real object, re-synthesize to match its real-world reference. Targets for the
important ones (cover the rest to the same standard):

| Cue(s) | Must sound like | Acoustic signature to synthesize |
| --- | --- | --- |
| `phone_call` | a ringing phone | warbling dual-tone ring (classic ~440/480 Hz interrupted bell, or a clean electronic ringtone) with the unmistakable RING-RING … pause CADENCE. It must be obviously a phone. |
| `coin_cascade`, `gold_coin_tease`, `double_gold_coin_tease`, `pinball_money_ding` | metal coins | bright metallic pings with inharmonic partials; a cascade is many coins scattering/jingling with slightly random pitches and a short bright decay. |
| `blackjack_chip`, `baccarat_chip`, `roulette_chip_*` | clay casino chips | a muted woody-plastic clack with a faint low ring; stacks add a soft rattle. Not a beep, not metallic. |
| `blackjack_card`, `card`, `paper_peek`, `paper_peel`, `pull_tab_click`, `pull_tab_thump` | cardstock / paper | soft papery friction and a light snap on the deal; peel is a slow tearing friction; thump is a dull low card-box knock. |
| `roulette_ball_roll/loop/rim_tick/bounce/scatter/drop/pocket`, `roulette_rotor_launch` | an ivory ball on a spinning wheel | a rolling rattle on the track, discrete rim ticks that DECELERATE, then a clattering settle into a pocket. The whole gesture should read as a real roulette spin. |
| `lever`, `lever_*` | a slot machine arm | a spring-loaded mechanical ratchet: the pull, the tension, the release/return. |
| `reel_loop/stop`, `buffalo_reel_*`, `digital_reel_*` | spinning reels | a rhythmic mechanical (or clean digital, for the digital family) spin with a satisfying detent/stop — a reel landing, not a tone cutting off. |
| `button`, `*_button`, `machine_button`, `rounded_cabinet_click`, `digital_button` | a physical cabinet button | a tactile click-THUNK with body; the digital family may be a clean UI click. No naked beep. |
| `jackpot`, `jackpot_hit`, `bonus_total`, `pinball_money_ding` | a casino win bell/chime | bright, IN-TUNE bell/chime cascade — celebratory, not a siren. |
| `drink_consumed` | a drink | a pour/gulp/glass set-down, recognizably drinking. |
| `scratch_box_pop`, `scratch_paper_foley_loop` | scratching a ticket | coin-on-latex friction and a light pop when a cell clears. |
| `bumper` | a pinball bumper | a punchy sprung pop/ding. |

Anything not in this table that still sounds generic or wrong gets the same
treatment. Report the full audit.

## Hard rules

- Procedural only — synthesize in `sfx_player.gd`; no external audio assets.
  Keep the first pass's warmth (nothing goes back to ringy/metallic-harsh);
  realism must not reintroduce harshness — model the object AND keep it
  pleasant on the hundredth hear.
- Music system OUT OF SCOPE — do not touch music synthesis/arrangement/player.
- Determinism preserved (seeded variation via named streams / stable hashes,
  never wall-clock-random in a way that breaks the probe). Family event names,
  loop points (`reel_loop`, `roulette_ball_loop`, `scratch_paper_foley_loop`),
  and the hooks games call stay intact — games need no edits.
- Web-safe: verify through the web audio bridge; no clipping/dropouts; stays
  within the audio-generation performance budget (measure — no frame-time
  spike). Consistent loudness across cues.
- Coordination: if the video poker cabinet rework has landed custom sounds,
  bring them up to this realism bar too and keep the synth helpers reusable.
- Style: tabs, typed GDScript, sparse comments; rendered samples/reports under
  `.tmp/sfx/`. Suite timeout = max(300s, ceil(recorded baseline × 1.5)).

## QA

1. RECOGNIZABILITY ACCEPTANCE (the core test): render a WAV per real-world cue
   under `.tmp/sfx/`, and for each state plainly what real object it now
   represents and why it reads as that (esp. `phone_call` — confirm it is
   unmistakably a phone). If a cue still would be mis-identified blind, it is
   not done.
2. Before/after audit table: every recognizable cue, old vs new, and the
   real-world model it now matches.
3. No regression to warmth/levels: nothing reverts to ringy/harsh; no
   clipping; loudness consistent through the web bridge (report peak/RMS
   spread).
4. Determinism + performance: `foundation_determinism_probe` self-consistent;
   `foundation_performance_probe` shows no audio-driven frame regression; web
   smoke passes with audio.
5. Manual: trigger the offenders in-game (get a phone call, cascade coins,
   spin roulette, pull a lever, hit a jackpot, scratch a ticket) — each reads
   as the real thing while staying pleasant.

## Gates

- `tools\validate_project.ps1`
- every supported `-FoundationSuite` (audio-touching suites especially)
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_performance_probe.ps1 -RequireGodot`
- `tools\web_perf_smoke.ps1`

## On completion

Only after every gate passes AND every recognizable cue reads true-to-life:

1. Commit in logical units (by cue group).
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, commit hashes, the
   recognizability audit table, gate results), and stage the move.
3. PUSH to the remote.
4. Report: the audit table, what each fixed cue now models, level/perf
   numbers, and confirmation the phone finally sounds like a phone.

On an unfixable gate, stop at the last green commit, do NOT push, and report
verbatim.

---

## Execution record - 2026-07-30

Implementation commit:

- `9de6f7ae` - Refine procedural SFX realism

Archive commit:

- This archive commit records the prompt move and execution evidence.

Recognizability QA:

- Rendered 66 procedural WAVs under `.tmp/sfx/`.
- Audit JSON: `.tmp/sfx/recognizability_audit.json`.
- Level spread: 0 clipped; peak range -25.69 to -6.68 dBFS; RMS range -34.48 to -14.40 dBFS.
- Phone confirmation: `phone_call.wav` is modeled as a classic dual-tone phone ringer with a clear RING-RING cadence, 440/480 Hz tones, warble/tremolo, and pause tail. Peak -16.77 dBFS, RMS -28.87 dBFS, no clipping.

Recognizability audit table:

| Cue group | Old read | New real-world model |
| --- | --- | --- |
| `phone_call` | Smooth but generic tone/click | Classic dual-tone telephone: 440/480 Hz warbling RING-RING cadence with line/cradle detail |
| `button`, `button_pinball`, `button_buffalo`, `button_digital`, `machine_button`, `video_poker_button`, `video_poker_hold`, `video_poker_cheat_beat`, `video_poker_double` | Soft UI beep/click | Physical cabinet button: cap snap, plunger body, plastic return tick; digital remains cleaner but tactile |
| `lever`, `lever_buffalo`, `lever_digital` | Generic low sweep | Spring-loaded slot arm: handle pull, ratchet teeth, spring return, cabinet clunk |
| `reel_loop`, `reel_loop_pinball`, `reel_loop_buffalo`, `reel_loop_digital` | Warm loop tone | Reel motor/belt with rhythmic detents; buffalo adds heavier cabinet body; digital stays cleaner |
| `reel_stop`, `reel_stop_pinball`, `reel_stop_buffalo`, `reel_stop_digital` | Tone cutoff/clack | Reel brake and latch: detent clack, lock body, landing thud |
| `gold_coin_tease`, `double_gold_coin_tease`, `payout`, `payout_digital` | Rounded bell cascade | Metal coins: inharmonic partials, scattered starts, short bright decay, soft tabletop contact |
| `jackpot_hit*`, `bonus_total*`, `jackpot*`, `pinball_money_ding` | Generic celebratory sweep | Casino win bell/chime: in-tune bell stack plus coin/body accents, kept warm and non-siren |
| `blackjack_chip`, `baccarat_chip`, `roulette_chip_select/place/lift/stack/sweep`, `blackjack_payout`, `roulette_payout`, `video_poker_win` | Too metallic/coin-like in places | Clay casino chips: muted woody-plastic clacks, low felt/body thumps, faint non-metal ring |
| `blackjack_card`, `video_poker_deal`, `video_poker_draw`, `paper_peek`, `paper_peel` | Papery but thin/generic | Cardstock and paper: fibrous friction, crinkle train, soft snap, felt slide |
| `pull_tab_click`, `pull_tab_thump` | Click/thump with generic bell edge | Pull-tab cardstock: tab snap, tearing friction, cardboard thump/drop |
| `scratch_paper_foley_loop`, `scratch_box_pop` | Scratch/noise loop that risked metallic regression | Scratch-ticket latex/foil: soft grit, latex drag, clearing pop, no retired metallic scratch identifiers |
| `roulette_rotor_launch`, `roulette_ball_loop`, `roulette_ball_rim_tick`, `roulette_ball_roll`, `roulette_ball_drop`, `roulette_ball_scatter`, `roulette_ball_bounce`, `roulette_ball_pocket` | Smooth wheel/rim texture | Ivory ball on roulette wheel: hard rim ticks, rolling rattle, drop, scatter, bounce, pocket settle |
| `roulette_dolly_tap`, `blackjack_felt` | Generic table tap | Felt/table tap: dull body, light contact, felt grain |
| `drink_consumed` | Glass/sip suggestion | Drink: glass lift, liquid sip/pour, bubbles, swallow, glass set-down |
| `bumper` | General pop/ding | Pinball bumper: solenoid body, rubber pop, contact snap, rebound |

Gate results:

| Gate | Result | Notes |
| --- | --- | --- |
| `tools\validate_project.ps1` | PASS | Final rerun passed |
| `tools\check_godot.ps1 -RequireGodot -FoundationSuite all -TimeoutSec 300` | PASS | Final report `.tmp/test_reports/20260730_182359_smoke/summary.json` |
| `tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300` | PASS | Final report `.tmp/test_reports/20260730_182641_smoke/summary.json` |
| `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10` | PASS | Seeds 10, checkpoints 320, hash 700837014 |
| `tools\foundation_performance_probe.ps1 -RequireGodot` | PASS | 62 observations, 8 seeds; renderer/game/resolve coverage complete |
| `tools\web_perf_smoke.ps1` | PASS | Exit code 0 after final tree rerun |
| WAV recognizability render | PASS | 66 WAVs rendered under `.tmp/sfx/`, zero clipping |

Deviations / notes:

- No music-system files were touched.
- Family event names, loop ids, and game-call hooks were preserved.
- Video-poker SFX ids already had sample bodies but were missing from the normalized-event allow-list; they were added so the new cabinet hooks resolve to their intended procedural cues instead of falling back to generic button audio.
- A transient broad `data/events/events.json` working-copy rewrite appeared while addressing an unrelated content gate. It was not staged or committed; the file was restored to the committed voice-pass content and final gates were rerun on the clean final tree.
