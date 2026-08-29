# env06_7 Package D ordered recovery

Status: WIP, unreviewed, and awaiting the serialized Godot verification lane.

This candidate is based exactly on ordered Package A+B+C recovery `a4c57bf`.
It recovers the Package D product semantics through `8c2fc885` and its
documentation child `20a445f4`; neither rejected branch is used as the
implementation base.

Every generic `work_0` and `work_1` spatial operation is rebound to a named
semantic anchor. Every declared `work_0` through `work_5` target is removed.
The coordinates below already existed in the named Punchline layer layout or
Kitty Cat Lounge layout before this recovery.

| Scenario | Recovered scene target | Existing slot | Recovered actor target | Existing slot | Sealed route |
| --- | --- | --- | --- | --- | --- |
| `punchline_open_mic_night` | `punchline_open_mic_signup` | club service `[154,264]` | `punchline_open_mic_waiting_comic` | club layer `[410,130]` | `base::layer:casino` |
| `punchline_headliner_night` | `punchline_headliner_credential_rope` | club layer `[786,302]` | `punchline_headliner_door_guard` | back-room travel `[842,374]` | `base::layer:casino` |
| `punchline_bringer_show` | `punchline_bringer_crowd_ropes` | club layer `[410,130]` | `punchline_bringer_crowd_captain` | club event `[704,214]` | `base::layer:casino` |
| `punchline_high_stakes_night` | `punchline_high_stakes_protected_table` | casino game `[798,176]` | `punchline_high_stakes_floor_runner` | casino service `[78,220]` | `base::layer:back_room` |
| `punchline_greased_week` | `punchline_greased_inspection_seals` | club layer `[786,302]` | `punchline_greased_payoff_runner` | casino event `[410,96]` | `base::layer:club` |
| `punchline_debt_court` | `punchline_debt_hearing_chairs` | back-room game `[450,218]` | `punchline_debt_room_witness` | back-room event `[270,205]` | `base::layer:casino` |
| `punchline_new_muscle` | `punchline_new_muscle_inspection_tray` | club service `[154,264]` | `punchline_new_muscle_checkpoint_rover` | casino event `[220,300]` | `base::layer:back_room` |
| `punchline_raid_jitters` | `punchline_raid_hide_cart` | club layer `[410,130]` | `punchline_raid_reopen_steward` | back-room layer `[410,168]` | `base::layer:casino` |
| `kitty_cat_lounge_amateur_night` | `kitty_amateur_signup` | event `[92,100]` | `kitty_amateur_judge` | event `[820,72]` | `base::world:bar` |
| `kitty_cat_lounge_buyout` | `kitty_buyout_ropes` | event `[520,260]` | `kitty_buyout_steward` | service `[638,160]` | `base::world:gas_station_casino` |
| `kitty_cat_lounge_slow_night` | `kitty_slow_closed_section` | game `[330,250]` | `kitty_slow_booth_regular` | lender `[690,376]` | `base::world:delta_queen` |
| `kitty_cat_lounge_bachelorette_storm` | `kitty_storm_prop_trunk` | item `[500,176]` | `kitty_storm_floor_host` | service `[520,150]` | `base::world:grand_casino` |

The focused contract now composes the exact production archetype and, for
Punchline scenarios, the declared club/casino/back-room layer through
`ContentLibrary` and `EnvironmentInstance`. `EnvironmentSemanticInventory`
must seal every declared zone, anchor, and route; the former fixture digest is
gone.

The recovered JSON signatures and dossier are intentionally pending author
regeneration because no Godot command is permitted outside the Warden-owned
slot. The tracked evidence manifest names 120 required rasters without
claiming they exist.
