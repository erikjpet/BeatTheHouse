# env06_7 Package C ordered recovery

Status: WIP, unreviewed, and awaiting the serialized Godot verification lane.

This candidate is based exactly on ordered Package A+B recovery `59e478dd`. It
recovers the eight-path Package C payload through rejected semantic head
`cb684cc2` and its immutable documentation child `4aee8b9c`, without using the
rejected branch as the implementation base.

The recovery removes every declared `work_0` through `work_5` target. The only
two generic positions actually used by the payload are rebound to named anchors
at exact existing production layout points. Each scenario also declares one
guaranteed route already exposed by its Bar or Jazz Club archetype.

| Scenario | Recovered scene target | Recovered actor target | Sealed route |
| --- | --- | --- | --- |
| `bar_wake` | `wake_memorial_tables` | `wake_host` | `base::world:motel` |
| `bar_fight_night` | `fight_toppled_chair` | `fight_right_brawler` | `base::world:kitty_cat_lounge` |
| `bar_payday_rush` | `payday_order_rail` | `payday_runner` | `base::world:corner_store` |
| `bar_lock_in` | `lockin_shutters` | `lockin_regular` | `base::world:delta_queen` |
| `bar_darts_league_night` | `darts_oche` | `darts_scorer` | `base::world:corner_store` |
| `bar_live_band` | `live_band_speakers` | `live_band_runner` | `base::world:kitty_cat_lounge` |
| `bar_dead_tuesday` | `dead_tuesday_bartender` | n/a | `base::world:motel` |
| `jazz_club_guest_legend` | `guest_legend_table` | `guest_legend_stage_manager` | `base::world:bar` |
| `jazz_club_rent_party` | `rent_party_donation` | `rent_party_creditor` | `base::world:motel` |
| `jazz_club_recording_night` | `recording_microphone` | `recording_audience` | `base::world:corner_store` |
| `jazz_club_union_trouble` | `union_picket` | `union_manager` | `base::world:bar` |

The focused contract now composes `bar` and `jazz_club` through the production
`ContentLibrary` and `EnvironmentInstance`, seals them with
`EnvironmentSemanticInventory`, and bounds every declared anchor, zone, and
route to the resulting exact collections. The prior synthetic digest is gone.

The tracked evidence manifest names the real raster directory, filename
pattern, required state suffixes, and contact sheet without claiming captures
that have not yet been produced. No Godot command has been run in this
worktree; signature regeneration, runtime checks, captures, and project gates
remain pending the Warden-owned slot.
