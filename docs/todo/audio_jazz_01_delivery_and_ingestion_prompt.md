# Agent Prompt - Jazz Audio 1: Delivery Contract and Ingestion

Copy everything below this line into the implementing agent.

---

Implement the production-audio ingestion contract for the Jazz Club vertical
slice in `D:\Projects\Beat-The-House`. Read
`docs/todo/audio_jazz_00_meeting_notes_execution_prompt.md` and the current
music manifest, validator, selector, and player first.

## Goal

An engineer can place correctly named 8- or 16-bar 24-bit WAV files into the
Jazz Club music folder, add musical compatibility metadata, and have the
current authored-stem system validate and load them without code changes.

## Filename contract

Implement one canonical parser for:

`Environment_Classification_Instrument_PatternNumber.wav`

Example: `JazzClub_Lead_Trumpet_1.wav`

- Match `.wav` case-insensitively, but preserve the original filename.
- `Environment` identifies the venue family (`JazzClub` first).
- `Classification` maps to a director role. Support at least `Chords`,
  `Bass`, `Lead`, `DrumsLow`, `DrumsHigh`, `Tension`, `Texture`, `Fill`, and
  `Stinger`; keep aliases data-driven where practical.
- `Instrument` is a stable human-readable instrument ID, not merely display
  copy.
- `PatternNumber` is a positive integer and is part of variant identity.
- Reject malformed names, unknown classifications, duplicate semantic IDs,
  and filenames whose declared environment disagrees with their track.
- Do not overload the filename with key/progression/intensity data. Those
  belong in explicit manifest or sidecar metadata.

Add a startup/editor-safe index builder or import helper that can report the
parsed files and propose manifest entries without silently rewriting a
hand-authored manifest. The runtime remains data-driven and must not scan the
filesystem every frame.

## Audio master contract

- Jazz production masters are uncompressed PCM WAV, 44.1 kHz, 24-bit.
- Every looping file in a track is exactly 8 or 16 bars and shares sample
  rate, bit depth, channel count, real frame length, start/end loop points,
  BPM, and time signature.
- Extend WAV inspection so real 24-bit PCM headers/data lengths are validated,
  including odd-sized chunks and non-audio metadata chunks.
- Keep legacy tracks working when they are internally consistent 16-bit
  sets, but require Jazz Club production entries to declare and validate
  24-bit. Never mix bit depths inside one synchronized set.
- Verify the native Godot import/playback path. If the engine import path
  converts the source internally, preserve the 24-bit master, document the
  conversion, and prove native playback uses a fidelity-safe decoded stream.
  If necessary, add a native decoder/stream provider rather than rejecting
  the files.
- Web conversion/compression is a later packaging concern and must not alter
  the source-master contract.

## Manifest/sidecar metadata

For each parsed file, support metadata for:

- role/classification, instrument, pattern number, weight, and tags;
- progression compatibility set, harmonic section, key, and relative key;
- intensity range and mutual-exclusion group;
- loop/stinger/fill behavior;
- preferred stem-specific DSP sends.

Provide one complete Jazz Club fixture using the exact naming convention.
Generated/silent test WAVs are allowed for automated coverage but must be
clearly located and labelled as fixtures, not production music.

## Documentation

Update `docs/plans/audio_engineer_delivery_contract.md` in plain language.
Include a copyable checklist and at least these examples:

- `JazzClub_Lead_Trumpet_1.wav`
- `JazzClub_Chords_Piano_1.wav`
- `JazzClub_Bass_UprightBass_1.wav`
- `JazzClub_DrumsHigh_BrushKit_1.wav`

## Tests and acceptance

1. Valid 24-bit 8-bar and 16-bar fixtures parse, validate, and load.
2. Frame count is derived from WAV data, not trusted metadata.
3. A renamed/malformed file, mixed bit depth, mismatched channel count,
   mismatched length, or wrong environment fails with an actionable message.
4. Legacy synchronized 16-bit fixture behavior remains covered.
5. Snapshot output exposes parsed filename fields and source audio format.
6. Project validation, GDScript load, and systems tests pass.

After verification, archive this prompt per `docs/todone/RULES.md`.
