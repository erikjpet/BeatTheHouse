# ENV-06.7 masked visual uniqueness review

Status: PASS for the 27 catalog pairs in the schema warning band on the current
ENV-06.6/06.7 acceptance candidate.

## Review method

The reviewer inspected the rendered contact sheets and the arrival raster for
both members of every pair. Scenario titles and capture labels were excluded
from every verdict: only object roles, actor placement, action stations,
obstruction overlays, and spatial routes were used to distinguish a pair. The
review used the tracked manifests under
`docs/plans/evidence/env06_7_package_[a-e]`.
Packages A, C, and D were rendered from their recovered authored semantic
objects, actors, actions, small-screen state, focus state, reduced-motion state,
hit overlay, and obstruction state because their earlier handoffs contained
capture ids but no raster receipts. Packages B and E retain their original
tracked raster evidence.

Each `capture receipt` below is SHA-256 over this UTF-8 material:

`left_scenario_id:left_arrival_png_sha256|right_scenario_id:right_arrival_png_sha256`

The ids only bind the digest and title/sign text is not accepted as visual
distinction evidence. The individual PNG hashes and capture ids are recorded
in the package manifests. All reviewed pairs remain mechanically distinct in
the executable catalog; this report resolves only the schema's 0.600-0.719
visual-review band and does not waive its blocking threshold.

## Pair verdicts

| Pair | Capture receipt | Masked visual finding |
|---|---|---|
| `corner_store_lotto_fever::back_alley_street_craps` | `f859de33e6212b91098bf71bb8c1822ddc06e4906790661d0e82ebc1bae6bd24` | Ticket queue/number board stations differ from a chalk ring, lookout marker, and shooter route. |
| `corner_store_lotto_fever::back_alley_cruiser_parked` | `102eee626cc8eb059f0309e1d53de7dfa674fe0243dfd6cf4ed649eb87e8eca6` | Queue service and number verification differ from the patrol beam, movable cover, and scanning officer. |
| `corner_store_lotto_fever::back_alley_nothing_moving` | `b687adced1224211f4e214032a22f1234ee148ab7f20f5b27b58a510f8e34886` | A live counter queue differs from a closed-shutter trace investigation and exposed route. |
| `corner_store_lotto_fever::pawn_shop_estate_lot_day` | `f6453c80fb1fb27fa3cb522f13c4b110eba9236c45972d117200da6ed587ede8` | Number-board verification differs from a segmented appraisal cart and provenance lanes. |
| `corner_store_inventory_night::back_alley_street_craps` | `00cd3ca246569ee44ac3c0bd8ff3dc446a9bb7d8ff5f9ea1b1f74cb9d61d8764` | Count cages and discrepancy shelving differ from the public dice ring and lookout state. |
| `corner_store_inventory_night::back_alley_nothing_moving` | `d164b209730c86771b9c636e34de1fea62ebdae4663e8544a28999b3fa153c99` | A lit inventory discrepancy path differs from the three-trace shutter route. |
| `back_alley_street_craps::pawn_shop_estate_lot_day` | `d50903782c99ad713e01c68ad7dd257cafc16b79676861cb8c6db902990b1b0f` | A curb dice layout and shooter differ from provenance carts and a guarded appraiser lane. |
| `back_alley_cruiser_parked::pawn_shop_estate_lot_day` | `5aeb7bcaaf770bd541c2863b35994866debde40fd0fb28f971c2fbd2c4bb990c` | Patrol sightline/cover movement differs from appraisal sorting and estate provenance. |
| `back_alley_cruiser_parked::pawn_shop_serial_check_day` | `356bd8cb06d07a583927791fdc47b433bdadd18be87e8df56c0b155d18bba282` | A moving patrol beam differs from a sealed hold object, serial station, and records clerk. |
| `back_alley_nothing_moving::pawn_shop_sals_mood` | `b8073771584628e56eb867544287e2d65a1b539c5091c8cf636a9d787a45555f` | An empty-alley trail differs from unfinished shop jobs and Sal's counter/back-room route. |
| `bar_payday_rush::jazz_club_recording_night` | `f6b34586d6f2b1ff18f5e837e27e5edde157b566be9b5744ed11017ac1c80830` | Crowd/token handling at the bar differs from recording booths, cue lamps, and a session route. |
| `bar_lock_in::bar_live_band` | `82123d820191cad954015b0c21e72c124a8fe073ab99023ef54a314aea95f37c` | A sealed lock-in route differs from the band stage, equipment, and live-room actions. |
| `bar_lock_in::punchline_new_muscle` | `614323c416ded98140c6f3d06f86dde1615434973d22267eee9ab49e1dc747bd` | Bar lock-in controls differ from guarded comedy-club access and muscle positioning. |
| `bar_lock_in::kitty_cat_lounge_amateur_night` | `b05f15c40256bb1a563f402df87049c30e9ea1761c2653a6032dce404784f65f` | A closed bar route differs from signup, dressing-room, and stage-light presentation. |
| `bar_live_band::punchline_new_muscle` | `9b36633cae73c9290c8fa77459ceb39b0413924847045c865d3d0206cf86364e` | A performance/equipment stage differs from guarded club lanes and enforcement choices. |
| `bar_live_band::kitty_cat_lounge_amateur_night` | `f44ce026a985480ee10f923e8e23906cff5e4bd0b22621932994f6550d335ae5` | Band equipment and live-room movement differ from amateur signup and dressing-room staging. |
| `punchline_headliner_night::punchline_greased_week` | `ad337a08e74b3d21b56a41cd46d3c8ce10d920696b2d0bd39ee36af30208157c` | Headliner escort/green-room staging differs from grease-payment pressure and altered club access. |
| `punchline_headliner_night::kitty_cat_lounge_buyout` | `937327fd354067a783dd83c95e39dc6395277bcf9b0d28a6e02dab2f9b4fbc9c` | Headliner movement differs from buyout signage, private floor zones, and guest routing. |
| `punchline_bringer_show::jazz_club_union_trouble` | `91353022f2df40f3104afc44870d0f4f8c28a8e37e088d0fa2b206650fa097d3` | Bringer seating/pitch flow differs from union positions, contract pressure, and work stoppage. |
| `punchline_high_stakes_night::punchline_debt_court` | `8b8d46e9aca3555489291a6d2c176f11ffae09022e4a385b5b3e6e3f26d40339` | A wager-driven club arrangement differs from debt claims, testimony positions, and judgment state. |
| `punchline_high_stakes_night::jazz_club_rent_party` | `94ff946767f7a1824ff4b56a90f895cfac50ee79156a77b7184fbc522dd6f934` | High-stakes table pressure differs from rent collection, contribution stations, and party access. |
| `punchline_greased_week::kitty_cat_lounge_buyout` | `ce3c165062c1d95077ad11c42b5d9504bbb4f2ff80edf3b621e6392868e7c192` | Greased-week payment and backstage pressure differ from a whole-floor buyout and private routing. |
| `punchline_debt_court::jazz_club_rent_party` | `fb1f2a4ca9cfb6e4774b5145bf1ed5adef08759eda59fdd241df7f85b7ef3245` | Formal debt-court positions differ from communal rent collection and party-floor movement. |
| `punchline_new_muscle::kitty_cat_lounge_amateur_night` | `97a63b218c150563e1f3d412e9994a533ae7a26453153fde9fba91ca74582075` | Guarded muscle placement differs from amateur signup, performer preparation, and stage entry. |
| `jazz_club_guest_legend::kitty_cat_lounge_bachelorette_storm` | `fc0cf513c6ebc589d75cb0f1d65051cb4bc89847d14c0542dc2397581b3254d3` | Guest-legend listening/performance space differs from a moving party group and disrupted lounge zones. |
| `delta_queen_wedding_charter::delta_queen_fog_delay` | `08c4b0dde7c9720aeb8ebf26060cfae5d50ad8bbfa443b708f8f6c358e2453bc` | Ceremony ropes, rings, and guest routing differ from a closed gangway, chart board, and signal lamp. |
| `pawn_shop_serial_check_day::pawn_shop_sals_mood` | `810a21fa1f6d8cb020996ed9bad31ce10c3b95949baa8b2b1619b1f57cebb689` | A sealed serial-hold workflow differs from visible unfinished jobs and Sal's mood-dependent route. |

## Review conclusion

All 27 pairs were distinguishable by object roles, actor placement, action
labels, and/or spatial route before identities were unmasked. Small-screen,
reduced-motion, focus, hit-target, safe-exit, and obstruction rows were also
present in the inspected sheets. No warning-band pair requires a content block;
the receipt-bound explanations can be admitted by the catalog audit.
