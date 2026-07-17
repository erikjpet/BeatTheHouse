# Jazz Club Music Handoff

This is the short delivery guide for the verified Jazz Club music system on
`main` at merge commit `a94f338d` (2026-07-17). The WAV files currently under
`assets/audio/music/jazz_club_delivery_fixture_*` are quiet test signals. They
prove the pipeline works, but they are not production music.

## What to send

Deliver one folder of uncompressed, integer PCM WAV masters plus a simple
metadata sheet. Use 44.1 kHz, 24-bit, and one consistent mono/stereo format.
All looping files in a set must have the same BPM, exact frame count, start,
end, and bar-one alignment. Use exactly 8 or 16 bars of 4/4.

At the current 120 BPM, the exact loop lengths are:

- 8 bars: 705,600 frames (16 seconds);
- 16 bars: 1,411,200 frames (32 seconds).

Name files as
`Environment_Classification_Instrument_PatternNumber.wav`, for example:

- `JazzClub_Chords_Piano_1.wav`
- `JazzClub_Chords_Guitar_1.wav`
- `JazzClub_Bass_UprightBass_1.wav`
- `JazzClub_Lead_Trumpet_1.wav`
- `JazzClub_DrumsHigh_BrushKit_1.wav`
- `JazzClub_Fill_BrushKit_1.wav`
- `JazzClub_Stinger_Trumpet_1.wav`

Supported classifications are `Chords`, `Bass`, `Lead`, `DrumsLow`,
`DrumsHigh`, `Tension`, `Texture`, `Fill`, and `Stinger`. Fills and stingers
are separate one-shots and must not contain loop metadata.

## Musical information to include

For every harmony bundle, list its stable ID, key, section (`A`, `B`, or
`C`), ordered chord voicings, matching bass roots, and the exact chord and
bass files that are compatible. The game selects the bundle before it selects
instruments, so incompatible bass and chords will never be paired.

The verified form is `A A B A / A A C A`, with four-bar phrases. The current
`C` section reuses the `A` harmony but deliberately changes chord instrument;
a true alternate progression needs its own bundle. Please provide at least
two chord instruments for the main progression so this contrast is audible.

For each stem or one-shot, also supply:

- intensity range, selection weight, tags, and exclusions;
- preferred reverb, delay, distortion, and compression-send notes;
- fill source/destination sections, compatible progression IDs, and a 1-,
  2-, or 4-bar lead-in;
- outcome class and desired landing for stingers: small win (beat), loss
  (half-bar), big win (bar), and optionally feature start/end;
- desired reverb-pulse attack, hold, release, peak, eligible instruments,
  and cooldown in musical beats.

Do not put key, progression, intensity, or effects in the filename. Those
belong in the metadata sheet and game manifest.

## What the verified game does

- Decodes each 24-bit master once to cached float PCM on native builds. The
  source master is not reduced to a 16-bit Godot stream.
- Keeps every parallel stem phase locked and selects harmony, instruments,
  and arrangement deterministically from the run seed and action history.
- Moves Jazz Club gradually from 116 to 124 BPM as heat changes, centered on
  120 BPM. Native playback uses one shared rate plus pitch compensation; Web
  stays at the authored base BPM.
- Runs a 32-bar room-dwell arc from sparse layers through builds, peak,
  release, and alternate-instrument rebuild without restarting the loop.
- Removes regular drums before a transition, plays one compatible authored
  fill, and lands the destination section and layers together.
- Schedules wins, losses, big wins, and feature boundaries on the live beat
  grid without delaying gameplay. Duplicate event tokens cannot replay a
  cue. Big-win intensity consumes exactly four musical bars.
- Applies outcome reverb only to selected instrument sends. Pulses are
  bounded, cannot accumulate into a full-mix wash, and return to the room
  baseline.
- Saves and restores musical transport, arrangement, layers, tempo, and
  pending boundaries deterministically. Missing production audio falls back
  safely.

## Delivery and acceptance

Place the production folder under `assets/audio/music/<track_id>/`. A game
developer will add its record to `data/audio/music_manifest.json` and point
the Jazz Club environment at the production track ID. Keep the fixture
folders intact as regression assets.

Before approval, listen on native headphones through low, rising, high, and
falling heat; the complete room-dwell arc; A/B/C transitions and feature
recovery; rapid small wins and losses; and a big win. Reject pitch wobble,
drum flamming, doubled or late fills, phase seams, abrupt gain steps, cue
latency that feels disconnected, accumulating reverb, or failure to return to
the room baseline.

The focused automated checks are:

```powershell
tools/check_audio_harmony_selection.ps1
tools/audio_float_pcm_probe.ps1
tools/audio_adaptive_tempo_probe.ps1
tools/audio_jazz_choreography_probe.ps1
tools/audio_jazz_outcome_probe.ps1
```

The integrated implementation passed project validation, all 19 accepted
FoundationSuite names, performance, 10-seed determinism, zero-warning visual
QA, exported-WebGL performance smoke, and the strict mouse playtest before it
was merged.
