# Audio Engineer Delivery Contract

The game treats the music as a live band made from synchronized recordings.
It chooses parts, changes intensity, adds fills, and applies effects while the
player is gambling. Steam and mobile use the full native Godot mix. The web
version remains a reduced fallback and does not limit the master recordings.

## Jazz Club filename and master checklist

- [ ] Export uncompressed integer PCM WAV masters at 44.1 kHz and 24-bit.
- [ ] Name every file `Environment_Classification_Instrument_PatternNumber.wav`.
- [ ] Use a positive pattern number and a stable instrument name without spaces or underscores.
- [ ] Render every looping file as exactly 8 or 16 bars in 4/4.
- [ ] Keep every looping file at the same BPM, mono/stereo format, exact frame count, start, and end.
- [ ] Leave every stem aligned to bar one; do not add different leading silence to individual files.
- [ ] Put key, relative key, progression compatibility, intensity, weights, exclusions, tags, and DSP-send preferences in the manifest, not the filename.
- [ ] Export fills and win/accent stingers as separate files; they play once unless deliberately marked to loop.

Copyable filename examples:

- `JazzClub_Lead_Trumpet_1.wav`
- `JazzClub_Chords_Piano_1.wav`
- `JazzClub_Bass_UprightBass_1.wav`
- `JazzClub_DrumsHigh_BrushKit_1.wav`

Supported classifications are `Chords`, `Bass`, `Lead`, `DrumsLow`,
`DrumsHigh`, `Tension`, `Texture`, `Fill`, and `Stinger`. Classification
aliases can be added in the track manifest without changing playback code.

The file name only identifies the venue, musical role, instrument, and
pattern number. For example, `JazzClub_Lead_Trumpet_1.wav` means Jazz Club,
lead role, Trumpet instrument, pattern 1. It does not declare a key or chord
progression.

## Harmony-safe Jazz bundles

For each chord progression, deliver a named compatibility bundle. A bundle
states the key, ordered 3- or 4-note chord voicings, one matching bass root per
chord, and the exact chord and bass recordings allowed to play together. The
game chooses the bundle first, then chooses instruments inside it. It will not
randomly pair a bass line with a different chord progression.

When possible, give the main A progression at least two chord-instrument
recordings, such as piano and guitar. The game can retain one instrument for a
declared number of phrases and deliberately change it at the scheduled
contrast. A section label and progression are separate: the Jazz fixture's C
contrast keeps the A progression/key/root motion but forces its alternate
chord instrument. A true B progression gets its own chord and bass files.

The current test form is `A A B A / A A C A`. It advances only when the music
transport reports a completed phrase. Saving during the form preserves the
current phrase, chosen instruments, and change schedule, so loading continues
with the same next phrase and parts.

## What to deliver for a legacy venue

- Internally consistent 16-bit, 44.1 kHz WAV sets remain supported.
- Every looping stem must use the same mono/stereo format, exact frame count,
  start point, end point, BPM, and number of 4/4 bars.
- Name each musical part by role: `pad`, `bass`, `lead`, `drums_low`,
  `drums_high`, `tension`, or `texture`.
- Optional alternatives may also use `bass_dark` and
  `drums_high_double`.
- Leave the beginning of every stem aligned to bar one. Do not add a different
  amount of silence to individual files.
- Render every instrument/pattern choice as its own stem variant. Include a
  short ID plus its instrument, pattern, intensity range, musical section,
  selection weight, and any part it must not play beside.
- Supply an A/B arrangement list and identify the key and relative key of each
  section. A and B parts must keep the same BPM and exact loop length.
- Supply separate one-shot WAVs for wins and musical accents. They never loop
  unless a file is deliberately marked as looping.
- Supply separate 2-bar or 4-bar fill WAVs for transitions. State which section
  or pattern each fill can leave and enter.
- Include preferred room reverb notes and any stem-specific effect-send notes.

## What the game does with those files

- Selects weighted instrument and pattern variants deterministically, so a
  room has an identity while still changing from run to run.
- Selects a compatible chord/bass bundle before selecting instruments, retains
  eligible instruments for their authored hold, and forces scheduled changes.
- Uses intensity, harmonic section, heat, attention, alcohol, bankroll
  pressure, showdown state, and slot-feature state as selection tags.
- Prevents mutually exclusive parts from being selected together.
- Changes musical sections at phrase boundaries and places a supplied fill in
  the final 2 or 4 bars before the destination section.
- Keeps every stem phase-locked while changing parts independently.
- Routes each stem independently into band-pass, delay, distortion, reverb,
  and compressor effect sends. A final limiter protects the complete mix.
- Makes attention narrow a real band-pass, alcohol raise delay sends and later
  close a low-pass, heat add distortion to more instruments, bankroll pressure
  compress the bass, and room size control reverb.
- Plays win accents on beat with cooldowns and a four-voice limit. A big-win
  mix envelope lasts four actual musical bars, then releases and cools down.
- Leaves venue percussion present when appropriate while slot-feature music
  replaces or ducks the venue instruments.

## Folder handoff

Place one venue in `assets/audio/music/<track_id>/`. The accompanying entry in
`data/audio/music_manifest.json` identifies the BPM, bar count, loop frames,
stems, banks, weights, tags, exclusions, keys, arrangement, fills, transitions,
and stingers. The game rejects a delivery if synchronized stems differ, so a
bad export cannot silently drift in play.

The import helper reads the folder and proposes manifest records; it never
silently rewrites the hand-authored manifest. The game validates the WAV data
chunk itself, including metadata chunks and RIFF padding, so the reported
frame count cannot hide a short or mismatched export.

Native builds keep the engineer's 24-bit WAV master untouched and decode every
signed 24-bit sample once into cached float PCM. A shared source-frame cursor
feeds Godot's float mixer, preserving information below the 16-bit threshold
along with the full 44.1 kHz rate, channel layout, loop length, and parallel-
stem phase. Debug snapshots show the 24-bit source, float playback provider,
and an actual low-order reconstruction probe. This path avoids the 16-bit
`AudioStreamWAV` container entirely for 24-bit masters. It is independent of
the reduced web packaging path; the web build never changes the source-master
contract.

The files under `assets/audio/music/jazz_club_delivery_fixture_*` are quiet
deterministic test signals, clearly labelled fixtures. They prove 8- and
16-bar 24-bit ingestion and are not the audio engineer's music.

## Native adaptive-tempo handoff

Jazz Club's first tunable profile is centered on 120 BPM and currently spans
116-124 BPM. Track metadata owns the heat curve, per-second and per-bar rate
limits, attack/release time, hysteresis, stakes classification, enable flag,
and web fallback; an environment profile may override those same fields.

Native Godot playback uses one authoritative ratio for venue stems, feature
stems, effect-send mirrors, fills, and music stingers. Every player advances
at that same ratio. One `AudioEffectPitchShift` on the shared Music bus applies
the inverse ratio after the stems have mixed, preserving musical pitch without
introducing per-stem phase processors or restarting a loop. Beat, bar, phrase,
fill, stinger, and four-bar outcome boundaries stay in source musical time;
the shared player ratio makes those boundaries occur at the live BPM. The web
build deliberately remains at the authored base BPM.

`tools/audio_adaptive_tempo_probe.ps1` is the native stress and acceptance
fixture. It covers low, rising, high, and falling heat; monotonic mapping;
slew/deadband behavior; a long up/down ramp with a 0.001-frame phase-error
ceiling; live beat/bar/phrase math; the four-bar outcome envelope; and exact
save/load continuation. Final headphone review should use the same four heat
conditions and listen specifically for stable pitch, drum flamming, transient
smear, and artifacts while the ratio is moving.

## Phrase fills and room-dwell choreography

`layer_choreography` is a musical-bar recipe, not a wall-clock automation.
Each stage declares its starting bar, duration, target role gains, and optional
fill request. Jazz Club's 32-bar fixture moves through sparse, bass build,
drum build, full-band peak, release, and an alternate-instrument rebuild.
Gameplay music may duck or override those gains, but it does not reset the
underlying visit bar or stage. Gain changes are smoothed over the declared
number of beats and all source players remain phase locked.

Section and layer changes publish their destination up to four bars ahead.
The default is two bars: regular loop drums leave at the lead-in boundary, one
compatible authored fill may play, then the destination section and intended
drum pattern land together. Fill metadata must declare a 1-, 2-, or 4-bar
lead, `loop: false`, valid source/destination sections, compatible progression
IDs, and any roles it introduces. Section requests outrank layer requests;
same-boundary requests share one fill. If no candidate matches, the director
uses a quiet drum exit and entry instead of substituting an incompatible fill.

Saving preserves the visit bar, stage, live/target gains, fill cooldown, and
scheduled destination. Feature music releases at the next valid phrase
boundary and resumes that same future. Adaptive tempo changes when the boundary
is heard but never changes its authored bar number.

Run `tools/audio_jazz_choreography_probe.ps1` for the deterministic native
timeline, compatibility, arbitration, tempo, save/load, and feature-recovery
checks. Headphone QA should listen through sparse-to-build, the two-bar drum
exit and fill, simultaneous section/drum arrival, peak-to-release, the C-form
instrument rebuild, and feature recovery. Reject doubled fills, incompatible
harmony, abrupt gain steps, late drums, restarts, or seams at any of those
boundaries.

## Beat-synchronized gameplay outcomes

Gameplay resolves immediately, then submits one outcome event containing a
stable token, class, magnitude/tier, source game, game-clock result time, and
optional requested quantization. The music director returns the scheduled
transport beat/bar to result presentation code; this may align a flash or
count-up, but it never holds input or authoritative state. Stable tokens are
deduplicated, and the bounded queue keeps at most eight pending cues feeding a
four-voice one-shot pool.

Outcome stinger metadata declares `outcome_classes`, `quantize` (`beat`,
`half_bar`, `bar`, or `phrase`), `max_latency_beats`, `cooldown_beats`, and
`volume_db`. A distant requested boundary falls back through smaller safe
subdivisions until it meets the latency ceiling. The unwrapped saved musical
transport is authoritative, so a loop wrap or adaptive-tempo ramp cannot move
the selected beat. Big-win intensity consumes exactly 16 beats (four 4/4
bars), regardless of how long those beats take in real time. Feature start/end
and feature stingers use this same event path.

`reverb_pulse` metadata controls attack, hold, and release in musical beats,
peak send, eligible instrument roles, eligible outcome classes, and its own
cooldown. The pulse raises only those role sends into the existing reverb bus;
it never opens permanent reverb on the complete Music mix. Overlap replaces a
single normalized pulse rather than accumulating, the outcome contribution is
clamped to 0.45, and it returns to the live baseline at the declared end.

The three Jazz outcome definitions are explicitly quiet non-production
fixtures: small win on a beat, darker loss on a half-bar, and big win on a bar.
They reuse the labelled fixture recording and are not final engineer audio.
Run `tools/audio_jazz_outcome_probe.ps1` for boundary, tempo-ramp,
deduplication, cooldown, voice-cap, reverb, four-bar, and immediate-resolution
acceptance. Headphone QA should check all three cues, rapid wins, and feature
start/end while listening for a clear underlying band, exact landings, no
wash buildup, and a complete return to the room's baseline ambience.
