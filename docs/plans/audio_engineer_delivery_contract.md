# Audio Engineer Delivery Contract

The game treats the music as a live band made from synchronized recordings.
It chooses parts, changes intensity, adds fills, and applies effects while the
player is gambling. Steam and mobile use the full native Godot mix. The web
version remains a reduced fallback and does not limit the master recordings.

## What to deliver for one venue

- 16-bit, 44.1 kHz WAV files.
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
