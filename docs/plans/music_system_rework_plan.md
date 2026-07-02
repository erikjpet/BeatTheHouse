# Dynamic Music System Rework Plan

Date: 2026-07-02
Status: PLANNED (review + design; no code changed)
Scope: `scripts/ui/procedural_music_player.gd` (1,225 lines), the slot bonus
music paths inside `scripts/ui/sfx_player.gd`, and the audio bus graph.

---

## 1. Review of the current implementation

### What it does today
- **Composer (good bones):** real music theory — mode scales (minor, dorian,
  phrygian, harmonic minor), chord progressions with chord-tone gravity for
  the lead, motif-driven melodies, phrase energy arcs, per-theme BPM/root/
  texture, all deterministically seeded per environment. This layer is worth
  keeping almost verbatim.
- **Renderer (the architectural limit):** the entire arrangement — pad, bass,
  lead, drums, siren, ambience texture — is summed per-frame into ONE mono
  16-bit 22 kHz PCM buffer on a background thread, cached as a WAV, and
  looped on a single `AudioStreamPlayer`. Latency is masked by a three-stage
  ladder (1.25 s instant bed → 8-step primer → full arrangement) and stream
  swaps wait for phrase breakpoints.
- **Input surface (narrow):** exactly two inputs — the environment's
  `music_profile` and heat quantized to 10 bands. One call site
  (`foundation_main.gd:3354`). Every heat-band crossing re-bakes and swaps an
  entirely new song.
- **Second, disconnected music system:** slot feature music
  (`bonus_music_pinball`/`bonus_music_buffalo`) is baked separately inside
  `sfx_player.gd` with no coordination with the ambient system.
- **Zero DSP:** the bus layout has volume buses only — no filter, chorus,
  distortion, reverb, or compressor anywhere.

### Why it can't meet the goals as-is
| Goal | Blocker in current design |
| --- | --- |
| Updates quickly on input criteria | any state change = full re-bake + wait for phrase break; only heat is even an input |
| Dynamic on ALL input factors | alcohol, watch state, win streaks, debt, showdown, feature state are invisible to music |
| Layers | one pre-mixed stream — nothing can fade in/out independently |
| Distortion/FX | no AudioEffect exists on any bus |
| Unique, well composed | straight 16ths (no swing), root-position pads (no voice leading), single A-section loop, one instrument palette for all venues |

**Core diagnosis:** the system bakes *a song per state* when it should bake
*stems per theme* and perform the *state* live in the mixer. Everything below
follows from that one inversion.

---

## 2. Target architecture: stems + live mix + bus DSP

### 2.1 Stem rendering (keep the composer, split the output)
Render each voice to its own looping WAV stem with identical length and loop
points: `pad`, `bass`, `lead`, `drums_low` (kick/snare), `drums_high`
(hats/brushes), `tension` (tremolo/heartbeat layer, composed but silent by
default), `texture` (venue ambience). Play all stems on parallel
sample-synced `AudioStreamPlayer`s on dedicated child buses under Music.
Bake cost is unchanged (same math, split writes); the existing generation
thread, token cancellation, instant-bed and primer staging all carry over.

### 2.2 MusicDirector (the new brain, ~replaces the top of the player)
A single node owning: current theme context, stem players, a **mix target
vector** (per-stem gain) and an **FX target vector** (per-effect parameters).
Each frame it lerps live values toward targets (fast attack ~0.25 s, slow
release ~2 s) — so state changes audibly land within a beat, never a re-bake.
Musical changes (unmuting a stem, stingers) quantize to the next beat/bar
using playback position and the known `step_period` — transitions become
musical instead of crossfaded.

### 2.3 Input matrix (the "all input factors" contract)
`MusicDirector.update(snapshot)` consumes one dictionary built in
`foundation_main` from RunState + surface context. Initial mapping:

| Input | Musical response (mix) | FX response (DSP) |
| --- | --- | --- |
| heat (continuous, not banded) | drums_high density stem gain up; tension stem creeps in above 60 | subtle distortion drive rises above 70 |
| pit boss watch / staff attention | tension stem on (bar-quantized); lead pulls back | narrow band-pass "surveillance" tinge, gentle |
| alcohol tier | swing amount already baked per-theme; mix slightly duckier | **drunk chain:** chorus depth + slow pitch wobble (wow/flutter) + low-pass closing as tiers rise; ties to existing drunk overlay/reduce-motion settings |
| win streak / big win moment | lead + drums_high brighten for N bars; sparkle accent stinger | reverb send briefly opens |
| bankroll pressure / overdue debt | bass stem swaps to darker variant (pre-baked B-stem); pad drops thirds | low shelf +2 dB, everything slightly drier |
| showdown pending / boss floor | percussion-only mix state + heartbeat tension; venue pad muted | distortion + compressor pump (danger grit) |
| venue archetype | instrument palette + theme (as today) | **reverb size/damping from visual_context room scale** |
| slot feature active | feature stem set layered over venue bed, venue pad ducked (see 2.5) | feature-specific brightness |

### 2.4 Bus DSP graph (the missing distortion/layer half)
Build once at startup (code, not .tres, to keep it versioned):
`Music` master bus → children per stem group. Effects, all default-bypassed
and parameter-driven by the director:
1. `AudioEffectLowPassFilter` (drunk fog, interior muffle)
2. `AudioEffectChorus` (drunk wow/flutter; light on jazz venues always)
3. `AudioEffectDistortion` (danger/showdown grit; lo-fi character at dives)
4. `AudioEffectReverb` (venue size — room scale from archetype)
5. `AudioEffectCompressor` → `AudioEffectLimiter` (glue + safety, always on)
This alone — even before stems — transforms perceived quality and is Phase 1
because it's independent of the re-architecture.

### 2.5 Unify the second music system
Slot feature music leaves `sfx_player.gd`: `bonus_music_*` becomes a feature
stem set registered with the director (same theory context, feature palette),
layered over the ducked venue bed. Feature events (multiball start, jackpot,
super jackpot) become beat-quantized one-shot stingers through the director,
so game moments land ON the music instead of over it. `sfx_player` keeps all
non-musical SFX.

### 2.6 Composition quality upgrades (the "well composed" ask)
All inside the existing composer, cheap and testable:
- **Swing/shuffle** per theme (period jazz feel; straight for casino floor).
- **Voice-led pads:** nearest-inversion chord voicing instead of root stacks.
- **AABA arrangement:** add a bridge phrase variant (relative-major or iv
  lift) so loops breathe; re-seed lead ornaments per loop pass for
  non-repetition without losing the motif identity.
- **Answer phrases:** motif call in bars 1-2, transformed answer (inversion/
  transposition) in bars 3-4 — the single biggest "composed, not generated"
  tell.
- **Phrase-end drum fills** gated by the existing phrase-energy arc.
- **Per-venue instrument palettes:** jazz club = brushes/upright/warm pad;
  grand casino = strings/vibraphone; dive = slightly detuned dual-osc lead;
  motel = sparse phaser pad. Palettes are synthesis-parameter sets on the
  existing voice functions (`_music_lead` etc. gain a `palette` dict), not
  new synths.

### 2.7 Authored music plug-in contract (future-proofing)

The director must never know where stems came from. Define a **stem-set
contract** as the only thing MusicDirector consumes:

```
{ "source": "procedural" | "authored",
  "stems": { "pad": AudioStream, "bass": ..., ... },   # sparse allowed
  "bpm": float, "bars": int, "loop_frames": int,
  "palette_id": String, "stingers": { cue_id: AudioStream } }
```

- **Two providers, one interface.** The procedural baker (§2.1) is provider
  one. Provider two loads authored OGG/WAV stems from
  `assets/audio/music/<track_id>/` described by a new
  `data/audio/music_manifest.json` entry: stem filenames, bpm, bar count,
  loop points, optional per-stem role mapping and stinger files.
  ContentLibrary validates the manifest (files exist, loop metadata sane).
- **Binding is data-driven:** an archetype's `music_profile` (or a feature's
  music spec) gains an optional `authored_track_id`. If set and the manifest
  entry resolves, the authored provider wins; otherwise silent fallback to
  procedural — a missing file must never break a run.
- **Sparse stem sets are legal.** An authored track may ship as one full-mix
  stem plus a tension layer; the director treats absent stems as silent and
  maps its mix matrix onto whatever roles exist. Authored bpm/loop metadata
  drives the same beat/bar quantization, so stingers and state transitions
  work identically.
- **The FX chain (§2.4) is source-agnostic by construction** — it lives on
  buses, so drunk/danger/venue treatment applies equally to authored music.
- Result: a composer can later hand us real recordings and they drop in as
  content (manifest + files), zero code changes.

### 2.8 Cache economics (a hidden win)
Today's cache key includes the heat band → up to 10 full bakes per venue.
With heat moved to the live mix, the key drops to (archetype, theme,
palette): one stem-set bake per venue per run, reused across all heat/state
changes. Fewer bakes, faster venue entry, smaller memory footprint.

---

## 3. Build phases

1. **Bus DSP graph + state-driven FX** on the existing single stream:
   drunk chain, venue reverb, danger grit, limiter. Immediate audible win,
   zero re-architecture risk. Extend the existing snapshot API with
   `music_fx_snapshot()` for headless validation.
2. **Stem split + sample-synced players + MusicDirector** with mix lerping;
   retire per-heat-band cache; keep instant-bed/primer staging per stem set.
   Gate: stems verified sample-locked (equal frame counts, loop points) in
   foundation checks; perf probe budget on bake time and runtime CPU.
3. **Input matrix**: wire the full snapshot (heat continuous, watch,
   alcohol, streaks, debt, showdown) with beat-quantized stem transitions.
   Gate: deterministic mix-state snapshot tests per scripted run fixture.
4. **Feature music unification** (pinball/buffalo into the director +
   stingers). Coordinate with slot module owners; `sfx_player` sheds the
   `bonus_music_*` samplers.
5. **Composition pass**: swing, voice leading, AABA, answer phrases, fills,
   palettes. Gate: theory snapshot extended (swing, voicing inversions,
   arrangement form) + a listening checklist per venue archetype.
6. **Polish/perf/accessibility**: reduce-motion-equivalent audio setting
   (calmer dynamics), settings for music intensity, final perf gates.

Each phase ships independently; Phase 1 alone is a worthwhile release.

---

## 4. Constraints & risks

- **Baked stems can't change tempo live.** Heat-driven BPM lift is replaced
  by drum-density stem variants (double-time hats) — reads as acceleration
  without resampling artifacts. True tempo ramps would need a streaming
  synth rewrite; explicitly out of scope.
- **Stem sync:** all stems must be started on the same mix frame and share
  exact loop lengths; the design mandates a single length authority in the
  generation context and a foundation check for it.
- **Thread model:** reuse the existing single generation thread + token
  cancellation; stems generate as one job to avoid partial sets.
- **Headless/CI:** all new behavior must expose snapshot APIs (mix state,
  FX state, stem manifest) like the existing theory/latency/transition
  snapshots — the current test pattern extends cleanly.
- **Do not regress the staging ladder:** venue entry must still make sound
  within ~1.25 s (instant bed) regardless of stem bake time.
