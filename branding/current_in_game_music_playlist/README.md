# Beat the House — Current In-Game Music Playlist

This folder contains a listening export of every current in-game music source:

- 18 environment themes, ordered roughly from early-game locations through the
  Grand Casino rooms.
- The Buffalo slot bonus-feature loop.
- The Pinball slot bonus-feature loop.

Open `playlist.m3u8` in a playlist-capable audio player to hear all 20 tracks in
order. The numbered WAV files can also be played individually.

Extended 2:30 versions of every track are available in `extended_2m30s/`. Open
`extended_2m30s/extended_playlist.m3u8` to play the extended set in order.

## Export format

- Mono PCM WAV
- 16-bit
- 44.1 kHz
- Environment tracks contain one complete generated or authored loop.
- Feature loops are repeated to 30 seconds for convenient listening.
- Each playlist master preserves the runtime role balance and is normalized to
  a peak of -0.72 dBFS.

## What “current” means

Procedural tracks were rendered from the active music engine in
`scripts/ui/procedural_music_player.gd` using each environment's current
`music_profile`. The Corner Store master uses its active authored track. The two
slot-feature masters use the same feature-stem generator and profiles used by
the live bonus modes.

The two Jazz Club delivery fixtures in `data/audio/music_manifest.json` are not
included because the manifest explicitly marks them as non-production music.
Track 10 is the active procedural Jazz Club music instead.

The game can change layer gains, tension, effects, and tempo in response to
heat, debt, wins, surveillance, and room state. These WAVs are stable playlist
masters of the underlying current music, not recordings of every dynamic mix
state.

See `playlist_manifest.json` for exact source IDs, BPM, duration, roles, and mix
weights.
