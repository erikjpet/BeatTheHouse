# audio06_1 independent closeout evidence

Date: 2026-09-03

Base: `9e8af74b712ed9c3a2bf69f9a330a57719cb0f85`

Branch: `codex/audio-closeout`
Status: independently accepted; final archive remains gated on Family 1 and the
cross-system green rerun.

## Profile coverage

| Profile | Classes | Max voices | Loop |
| --- | ---: | ---: | --- |
| `coin_pusher` | 19 | 8 | `coin_pusher_motor` |
| `craps_table` | 13 | 7 | - |
| `blackjack_table` | 16 | 7 | - |
| `baccarat_table` | 11 | 7 | - |
| `roulette_table` | 14 | 8 | - |
| `slot_machine:*` | 8 | 8 | - |
| `video_poker_machine` | 12 | 6 | - |
| `pull_tab_dispenser` | 7 | 5 | - |
| `scratch_ticket_machine` | 8 | 5 | - |
| `bar_dice_table` | 7 | 6 | - |
| `crew_cards` | 6 | 6 | - |
| `crew_world` | 11 | 6 | - |
| `scenario_transition` | 16 | 5 | - |

The classes resolve to 80 unique delivery event IDs. Manifest SHA-256:
`6E2629542C403FCC96B21EB07FB77C10D3A080994B1E14CC9E3F7F15B74E1DC3`.

## Accepted checks

| Check | Result |
| --- | --- |
| `Godot --headless --audio-driver Dummy --path . --script res://tools/audio06_1_surface_sfx_audit.gd` | PASS: 13 profiles, 80 complete signal-bearing streams, 10 deterministic seed traces |
| Combined Foundation runner with `--check-ids=music_fx_foundation,music_stem_director_foundation` | PASS: 2/2 |
| `Godot --headless --audio-driver Dummy --path . --script res://tools/roulette_audio_audit.gd` | PASS: 14 events, 254,016 PCM bytes |
| `tools/validate_project.ps1 -Quiet` through supported harness | PASS (two runs) |
| Godot import through supported harness | PASS |
| Non-test GDScript load sweep through supported harness | PASS |

The audio audit covers closed manifest/schema failures, authoritative helper
capabilities including hostile rebind, deterministic native/Web selection,
paired hidden-state inputs, complete waveform delivery, visual/text
counterparts, bounded per-profile/global voice selection, mixer routing, and
idle-frame work.

## Preserved non-acceptance evidence

1. A pre-correction audit process timed out because a GDScript type-inference
   error aborted the deferred runner before `quit`; the type was made explicit
   and the final load/audit passed.
2. The first broad Systems invocation used a report directory nested under
   `docs` and was rejected before Systems execution to prevent a recursive
   shard junction. The corrected `.tmp` retry was used thereafter.
3. The corrected broad Systems retry timed out with extensive non-audio
   game/world/save failures on the integrated Family 2 base. The audio-owned
   focused checks pass. Root owns attribution and rerun after Family 1 lands.
4. The UI-scene compile reported only the inherited Slot fixture-3
   serialize/restore mismatch; it reported no audio or authority regression.

No production music, music manifest, or music-system behavior changed. The 0.6
external-audio delta remains in `docs/plans/audio_engineer_handoff.md`.
