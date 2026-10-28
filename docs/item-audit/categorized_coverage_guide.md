# Beat the House categorized item audit

Snapshot: `9adf460d1ad0d716e91049bda0d9477483e7aebe` (`erikjpet/BeatTheHouse`). Source-only acquisition analysis; no game/content changes or gameplay testing.

The original four-column, duplicate-free 153-row CSV remains unchanged. This new 15-column companion preserves those four fields exactly and adds canonical ID, game-role category, acquisition, current obtainability, ordinary default-shop eligibility, contraband/risk information, same-name distinctions, acquisition evidence, a plain-language practical explanation, value/noticeability notes and review decisions. It supports later item-by-item description/design review; it does not choose or implement new behavior. The matching self-contained HTML presents one item at a time for phone reading, with search and filters, while keeping all full fields available.

## Why 153 rows does not mean 153 ordinary shop items

**60 unique ordinary item IDs are eligible for generated merchant offers under the default content-group selection.** The offer builder appends enabled sellable definitions to each supplied archetype pool. All enabled explicit stock-pool entries are already within those 60 IDs. The count is a global eligible pool, not the number stocked at once, available in a particular seed, or always affordable.

The other 93 rows are 29 ordinary definitions obtained through other paths, 28 collection gear definitions, 10 collection bags, 2 special casino rewards, 1 profile reference collectible, 15 ticket merchandise definitions and 8 mission-only cargo/context IDs. 60 + 29 + 28 + 10 + 2 + 1 + 15 + 8 = 153. The separate role table below counts ticket-pile and Numbers markers under tickets, and the registered Package under mission cargo; do not add its role totals to the preceding catalog-definition totals.

| Exclusive game-role category | Rows |
| --- | ---: |
| Run gear / consumable | 68 |
| Inventory ticket / betting slip | 18 |
| Storage container | 4 |
| Souvenir | 13 |
| Mission cargo | 9 |
| Collection gear | 28 |
| Collection bag | 10 |
| Casino special reward | 2 |
| Profile reference collectible | 1 |
| **Total** | **153** |

Filter **Default shop eligibility** to the values beginning `Yes` to obtain the 60 ordinary items (56 run gear/consumables and 4 storage containers). Tickets remain ticket-category merchandise even when bought at a physical counter. Collection bags are rewards that open into gear; ordinary Bag/Backpack/Suitcase/Trunk are storage containers.

Source chain: [scripts/core/content_library.gd:926](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/content_library.gd#L926); [scripts/core/content_library.gd:1019](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/content_library.gd#L1019); [scripts/core/content_library.gd:4180](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/content_library.gd#L4180); [scripts/core/environment_instance.gd:1014](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/environment_instance.gd#L1014); [scripts/core/run_action_service.gd:1287](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/run_action_service.gd#L1287).

Default selection uses the content groups’ `default_enabled` flags; `scenario_souvenirs` (13 sellable definitions) and `crew_gear` (5 sellable craft outputs plus one unsellable Package) are disabled by default. Explicitly enabling both optional groups expands ordinary merchant eligibility from 60 to 78. Those 18 extra definitions use $0..$0 authored offer ranges; environment price multipliers/sale-price rules can override that. This is observed code/configuration, not a recommendation to enable them or a claim about intended pricing. Tutorial strict-pool mode can reduce the pool further.

Groups/settings evidence: [data/content_groups/groups.json:1](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/data/content_groups/groups.json#L1); [scripts/core/content_library.gd:954](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/content_library.gd#L954); [scripts/ui/foundation_main.gd:9692](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/ui/foundation_main.gd#L9692); [scripts/ui/foundation_main.gd:9926](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/ui/foundation_main.gd#L9926).

## Where the 29 non-default-shop ordinary definitions come from

| Non-default-shop ordinary definitions | Count | Current source path |
| --- | ---: | --- |
| Scenario souvenirs | 13 | Scenario event choice adds inventory; 5 also have direct sequence reward commands |
| Mags craft outputs | 5 | Punchline backroom bench, standing/cash/parts gates |
| Musician favor rewards | 4 | Jazz favor thresholds choose sax/cello/drummer coin or drummer glasses |
| Half thermos and Broken Cufflinks | 2 | Use/damage transformations; half thermos also has event grant |
| Cumquat Sandwich | 1 | Beach sand-pile service |
| Scratch and Pull Tabs pile markers | 2 | Derived from owned portable ticket state |
| Numbers Slips | 1 | Open Numbers bets; also an existing canonical ID for a crew route context |
| The Package | 1 | Crew delivery registered cargo marker |
| **Total** | **29** | |

A disabled shop content group is not proof of an unreachable reward. Scenario/event and Mags output grants do not apply the merchant group filter. The bench has a real room producer: Punchline backroom includes `crew_mags_bench` in both its event pool and required events; this is not merely an unused recipe table. Source chains: [data/environments/archetypes.json:1980](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/data/environments/archetypes.json#L1980); [scripts/core/event_module.gd:368](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/event_module.gd#L368); [scripts/core/game_module.gd:1231](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/game_module.gd#L1231); [scripts/core/scenario_sequence_catalog.gd:177](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/scenario_sequence_catalog.gd#L177); [scripts/core/scenario_engine.gd:1571](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/scenario_engine.gd#L1571).

The eight mission-only rows retain code cargo IDs because the requested broad catalog already includes them. They are state/model labels, not eight shop inventory definitions. The delivery facade adds an ordinary inventory marker specifically for `crew_package`; other named mission cargo remains delivery/job state. Two additional mission contexts were already merged into `crew_package` and `numbers_slips`, so they do not add rows. Evidence: [scripts/core/crew_run_facade.gd:1937](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/crew_run_facade.gd#L1937); [scripts/core/crew_run_facade.gd:1968](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/crew_run_facade.gd#L1968); [scripts/core/delivery_run_facade.gd:799](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/delivery_run_facade.gd#L799).

## Acquisition channels overlap

These counts describe separate ways to obtain the same catalog entries. They must not be added to produce a catalog total. They are source-connected candidates, not claims that every candidate appears during one run.

| Acquisition channel | Canonical rows |
| --- | ---: |
| beach_service_reward | 1 |
| cage_chip_gift_shop | 13 |
| casino_terminal_reward | 2 |
| collection_bag_open | 28 |
| collection_run_reward | 10 |
| crew_mission_context | 10 |
| event_reward | 1 |
| home_start_container | 2 |
| home_start_pickup | 12 |
| jazz_favor_reward | 4 |
| legacy_held_ticket | 1 |
| mags_crafting | 5 |
| meta_home_starter_container | 1 |
| meta_sal_gold_shop | 28 |
| numbers_bet_marker | 1 |
| ordinary_shop_default | 60 |
| ordinary_shop_optional_group | 18 |
| ordinary_transformation | 2 |
| portable_ticket_inventory_marker | 2 |
| profile_acquire_button | 1 |
| pull_tab_merchandise | 8 |
| pusher_reward_candidate | 47 |
| scenario_reward | 13 |
| scratch_merchandise | 6 |
| sequence_reward | 5 |

The pusher candidate count is 47 before the runtime art-resource existence check: the 60 ordinary pool IDs minus 13 classified as contraband by class OR flag. Having an asset path is not itself proof that ResourceLoader succeeds on every deployed build. Per-row acquisition cells state this condition. Cage chip shop, starting-home pickups and pusher rewards overlap ordinary shop gear. Successful-run Sal stock is a separate persistent gold economy and can roll all 28 collection gear definitions; bags can also roll all 28 because every represented collection/tier has a positive weight and a matching item definition.

Collection source chain: [scripts/core/collection_drop_service.gd:197](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/collection_drop_service.gd#L197); [scripts/core/collection_drop_service.gd:331](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/collection_drop_service.gd#L331); [scripts/core/collection_drop_service.gd:259](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/collection_drop_service.gd#L259); [scripts/core/meta_collection_service.gd:237](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/meta_collection_service.gd#L237); [scripts/core/collection_drop_service.gd:33](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/collection_drop_service.gd#L33); [scripts/core/meta_collection_service.gd:685](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/meta_collection_service.gd#L685); [scripts/core/meta_collection_service.gd:785](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/meta_collection_service.gd#L785); [scripts/core/collection_item_resolver.gd:244](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/collection_item_resolver.gd#L244).

## Same displayed name, different currently connected systems

There are 21 exact shared-name groups: 20 ordinary/collection pairs and Lucky 7s scratch versus pull-tab merchandise. The expanded column additionally catches two punctuation-only pairs (Side-Bet Chart / Side Bet Chart and Split-Reel Note / Split Reel Note). Names stay as currently authored. Canonical IDs explain which item is being discussed.

Concrete example: `creased_luck_card` is ordinary merchant/run gear; `creased_luck_card_meta` is persistent collection gear from a bag or Sal’s gold stock. Both paths are connected in current code. The ordinary item has fixed authored effects and direct pickup handling; collection instances use rolled bindings and loadout handling. Shared display text does not make them a duplicated CSV record.

Concrete example: `marked_cards` is ordinary contraband, while `marked_cards_meta` is persistent collection gear that the resolver exposes as class permanent without copying an ordinary contraband risk flag. Individual cheat actions can still create Heat. Both are reachable through their respective source paths; do not infer identical effect or risk rules from their name.

Example definitions and resolution: [data/items/items.json:3](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/data/items/items.json#L3); [data/items/items.json:353](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/data/items/items.json#L353); [data/collections/collections.json:185](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/data/collections/collections.json#L185); [data/collections/collections.json:1398](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/data/collections/collections.json#L1398); [scripts/core/collection_item_resolver.gd:321](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/collection_item_resolver.gd#L321).

## Contraband is a flag dimension, not an extra primary total

17 ordinary definitions use class `contraband`; another 3 use different classes but explicitly carry risk_flags=[contraband]: Coin-Return Shim, Cold Quarters and X-Ray Glasses. The carried-risk consumer accepts either condition. Therefore **20 ordinary canonical IDs are tagged contraband**, including **13 of the 60 default ordinary shop IDs**. The Numbers marker and Package are among the 20; Mags’ 5 outputs are also included. This count excludes conditional delivery-state cargo risk and does not label all collection gear illegal merely because some cheat effects add Heat.

Delivery snapshot marks actual CARGO_CARRIED state as contraband. Lookout/hold mode initializes cargo as NONE; a shift-note or guest-list label alone is not proof that illegal cargo is carried. Evidence: [scripts/core/run_state.gd:14047](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/run_state.gd#L14047); [scripts/core/delivery_run_model.gd:292](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/delivery_run_model.gd#L292); [scripts/core/delivery_run_model.gd:825](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/delivery_run_model.gd#L825); [scripts/core/delivery_run_facade.gd:828](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/delivery_run_facade.gd#L828).

## Current, held and reference content

New-sale merchandise contains 6 scratch types and 8 Pull Tabs types. Crossword Corner is the seventh defined scratch type, retained because previously issued tickets remain valid; purchase explicitly rejects it as held. It is the one row with no established active new-issue route. The Rain City Poker Chip is a reference/demo collectible, but its current main-menu inventory Acquire Chip path is wired, so it is not described as unreachable. No other whole canonical definition in this 153-row baseline was proven wholly unreachable. This is a statement about traced source paths; no browser/gameplay verification was performed.

Held/reference evidence: [scripts/games/scratch_tickets.gd:846](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/games/scratch_tickets.gd#L846); [scripts/ui/foundation_screen_builder.gd:63](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/ui/foundation_screen_builder.gd#L63); [scripts/ui/foundation_main.gd:10596](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/ui/foundation_main.gd#L10596); [scripts/ui/foundation_main.gd:20070](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/ui/foundation_main.gd#L20070).

## Review decision recorded from the live discussion

**`lucky_penny` — flag for full effect and description rework. Replacement design undecided.** Current player-observable benefit: it makes scratching finish slightly sooner; it does not protect prizes. The factual four columns are unchanged. No replacement values, description rewrite or gameplay tuning has been chosen or implemented. Other items are not automatically marked for a complete rework solely because the user expects many may need one.

**`xray_glasses` — preserve functionality.** The user identified this as a positive example with a substantial effect they do not want changed. Description discussion remains pending; no tuning is authorized.

## Evidence limits for the later redesign and value review

The first four columns retain the completed definition→effect consumer analysis. The added evidence column traces acquisition producers and their gates; it does not treat a definition’s presence or authored effect dictionary as proof of a working benefit. Full baseline consumer references remain in the existing coverage evidence, keyed by canonical ID.

Separate three questions during the later item review:

- Connected/unused effect: a concrete reader, trigger and required state must exist. Existing audit examples include the collection cufflink absorb key with no reader; baseline-luck collection loadout not applying its direct delta; Mags Shim Kit’s ordinary-shim gate; and ordinary cabinet activations overriding collection keys. These are code-supported mechanism discrepancies, with scope/conditions stated in each functionality cell. They do not prove every aspect of the item is ineffective.
- Value/balance: a connected numeric benefit may still be too small or too expensive. Source inspection alone cannot establish expected net benefit, noticeable improvement, or a fair price. No intended numeric values or balance verdicts are assigned here.
- Player feedback: labels such as Lucky Penny’s “Scratch Penalty Shields” can misdescribe what the connected code does. A small auto-scratch threshold change gives little direct purchase/use feedback. The current audit establishes the trigger and threshold, not a playtested perception score.

The strongest existing description/behavior discrepancies remain: Lucky Penny’s shield label versus scratch cleanup; passive Instant Coffee despite consumable class; collection cufflinks’ unread absorb key versus ordinary ID-specific break protection; Pull Tabs authored prize rows replaced by the runtime shared ladder; and collection “luck” text versus loadout not applying baseline_luck_delta. These are not replacement descriptions. Current source references for each are preserved in the original per-ID evidence and the content cells.

Direct discrepancy checks: Lucky Penny assist/threshold consumer [scripts/games/scratch_tickets.gd:2052](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/games/scratch_tickets.gd#L2052); Instant Coffee activation classification [scripts/core/run_action_service.gd:878](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/run_action_service.gd#L878) against [data/items/items.json:64](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/data/items/items.json#L64); collection cufflink declaration [data/collections/collections.json:1910](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/data/collections/collections.json#L1910) versus the literal ordinary-ID protection at [scripts/games/blackjack.gd:8868](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/games/blackjack.gd#L8868) (production-script search found the numeric absorb key only in the resolver whitelist); Pull Tabs live ladder [scripts/games/pull_tabs.gd:2596](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/games/pull_tabs.gd#L2596); collection loadout application [scripts/ui/foundation_main.gd:18559](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/ui/foundation_main.gd#L18559) versus direct ItemEffect luck handling [scripts/core/item_effect.gd:142](https://github.com/erikjpet/BeatTheHouse/blob/9adf460d1ad0d716e91049bda0d9477483e7aebe/scripts/core/item_effect.gd#L142).

## Completeness, preservation and duplicate validation

The independent canonical-ID set matches the 153 baseline IDs exactly. There are 154 CSV records including header, 15 fields per record, 153 unique canonical IDs, zero exact repeated rows and zero repeated canonical IDs. The first four parsed fields on every row equal the delivered baseline. Primary role counts sum to 153. The baseline file hash is unchanged: `34b8909ce25b5ecf3feae248265c722635dd9b688aa82028393baac19b53d97f`.

UTF-8 with BOM, all cells quoted, embedded newlines/double quotes escaped by Python csv. Formula-prefix scan covers every cell after leading whitespace; escapes applied: 0. Maximum cell length: 2829 characters, below Excel’s 32,767-character cell limit. The four original fields are preserved, including any existing audit-generated formatting characters; no authored text is rewritten.

Runtime rolled instances, card earned tiers, ticket serials/prizes/puzzles, pawn-debt presentations and mission contexts are not repeated as arbitrary separate rows. Non-inventory room fixtures, services, currencies, played game components and obsolete tool/test-only aliases remain excluded, as documented in the baseline coverage report. No catalog omissions or new canonical items were introduced by this categorization.

Companion files: `categorized_acquisition_evidence.json` gives per-row role/channel/ID/source mapping and review decision; `categorized_validation.json` gives machine-readable preservation/duplicate/count checks. The expanded CSV adds acquisition evidence without changing the baseline’s four columns.

## Per-ID category and acquisition reconciliation

| Canonical ID | Role | Default ordinary shop? | Acquisition channels |
| --- | --- | --- | --- |
| `creased_luck_card` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, home_start_pickup |
| `pile_of_pull_tabs` | Inventory ticket / betting slip | No | portable_ticket_inventory_marker |
| `pile_of_scratch_tickets` | Inventory ticket / betting slip | No | portable_ticket_inventory_marker |
| `instant_coffee` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, cage_chip_gift_shop, home_start_pickup |
| `ledger_pencil` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, home_start_pickup |
| `cashout_envelope` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, cage_chip_gift_shop, home_start_pickup |
| `thermos_black_coffee` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, cage_chip_gift_shop |
| `thermos_black_coffee_half` | Run gear / consumable | No | ordinary_transformation, event_reward |
| `pickled_olive_jar` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, cage_chip_gift_shop |
| `lucky_bar_napkin` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, cage_chip_gift_shop, home_start_pickup |
| `cheap_sunglasses` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, cage_chip_gift_shop, home_start_pickup |
| `marked_cards` | Run gear / consumable | Yes | ordinary_shop_default |
| `edge_sort_loupe` | Run gear / consumable | Yes | ordinary_shop_default |
| `scratch_pad` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, cage_chip_gift_shop, home_start_pickup |
| `freds_poker_hat` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `odds_notebook` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `shoe_cut_marker` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `card_counters_notes` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, cage_chip_gift_shop, home_start_pickup |
| `side_bet_chart` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, cage_chip_gift_shop, home_start_pickup |
| `basic_strategy_card` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `lucky_ladies_compact` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `coolers_cufflinks` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `broken_cufflinks` | Run gear / consumable | No | ordinary_transformation |
| `high_roller_watch` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `pocket_watch` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `lucky_keychain` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, cage_chip_gift_shop, home_start_pickup |
| `foil_sleeve` | Run gear / consumable | Yes | ordinary_shop_default |
| `holdout_wax` | Run gear / consumable | Yes | ordinary_shop_default |
| `chip_slide_wax` | Run gear / consumable | Yes | ordinary_shop_default |
| `sleeve_rig` | Run gear / consumable | Yes | ordinary_shop_default |
| `coin_return_shim` | Run gear / consumable | Yes | ordinary_shop_default |
| `lucky_reel_grease` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `timing_bracelet` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `gold_tooth_token` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `payout_pamphlet` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `cold_quarters` | Run gear / consumable | Yes | ordinary_shop_default |
| `neon_players_charm` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `split_reel_note` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `feature_magnet` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `cumquat_sandwich` | Run gear / consumable | No | beach_service_reward |
| `drain_cleaner` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `jackpot_magnet` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `splitter_token` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `return_spring` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `tilt_dampener` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `bumper_battery` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `rubber_pegs` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `magnet_cup` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `extra_ball_token` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `plunger_tuner` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `lock_jammer` | Run gear / consumable | Yes | ordinary_shop_default |
| `weighted_keyring` | Run gear / consumable | Yes | ordinary_shop_default |
| `dice_calipers` | Run gear / consumable | Yes | ordinary_shop_default |
| `false_bottom_cup` | Run gear / consumable | Yes | ordinary_shop_default |
| `roadside_map` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, cage_chip_gift_shop, home_start_pickup |
| `payment_calendar` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, cage_chip_gift_shop, home_start_pickup |
| `pawn_receipt_sleeve` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `xray_glasses` | Run gear / consumable | Yes | ordinary_shop_default |
| `tab_detector` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `tarot_card` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate |
| `lucky_penny` | Run gear / consumable | Yes | ordinary_shop_default, pusher_reward_candidate, cage_chip_gift_shop |
| `jazz_sax_lucky_coin` | Run gear / consumable | No | jazz_favor_reward |
| `jazz_cello_lucky_coin` | Run gear / consumable | No | jazz_favor_reward |
| `jazz_drummer_lucky_coin` | Run gear / consumable | No | jazz_favor_reward |
| `jazz_drummer_glasses` | Run gear / consumable | No | jazz_favor_reward |
| `bag` | Storage container | Yes | ordinary_shop_default, pusher_reward_candidate, meta_home_starter_container |
| `backpack` | Storage container | Yes | ordinary_shop_default, pusher_reward_candidate, home_start_container |
| `suitcase` | Storage container | Yes | ordinary_shop_default, pusher_reward_candidate |
| `numbers_slips` | Inventory ticket / betting slip | No | numbers_bet_marker, crew_mission_context |
| `trunk` | Storage container | Yes | ordinary_shop_default, pusher_reward_candidate, home_start_container |
| `wedding_ribbon_favor` | Souvenir | No | ordinary_shop_optional_group, scenario_reward |
| `wake_matchbook` | Souvenir | No | ordinary_shop_optional_group, scenario_reward, sequence_reward |
| `fight_night_betting_slip` | Souvenir | No | ordinary_shop_optional_group, scenario_reward, sequence_reward |
| `festival_brass_token` | Souvenir | No | ordinary_shop_optional_group, scenario_reward |
| `estate_map_clasp` | Souvenir | No | ordinary_shop_optional_group, scenario_reward |
| `convoy_cb_tag` | Souvenir | No | ordinary_shop_optional_group, scenario_reward |
| `tour_bus_luggage_tag` | Souvenir | No | ordinary_shop_optional_group, scenario_reward |
| `lock_in_door_chit` | Souvenir | No | ordinary_shop_optional_group, scenario_reward, sequence_reward |
| `delivery_twine` | Souvenir | No | ordinary_shop_optional_group, scenario_reward |
| `lotto_queue_number` | Souvenir | No | ordinary_shop_optional_group, scenario_reward |
| `boarded_window_nail` | Souvenir | No | ordinary_shop_optional_group, scenario_reward |
| `rent_party_hat_pin` | Souvenir | No | ordinary_shop_optional_group, scenario_reward, sequence_reward |
| `recording_room_tape` | Souvenir | No | ordinary_shop_optional_group, scenario_reward, sequence_reward |
| `mags_loaded_dice` | Run gear / consumable | No | ordinary_shop_optional_group, mags_crafting |
| `mags_tuned_loupe` | Run gear / consumable | No | ordinary_shop_optional_group, mags_crafting |
| `mags_lined_sleeve` | Run gear / consumable | No | ordinary_shop_optional_group, mags_crafting |
| `mags_nudge_dampener` | Run gear / consumable | No | ordinary_shop_optional_group, mags_crafting |
| `mags_shim_kit` | Run gear / consumable | No | ordinary_shop_optional_group, mags_crafting |
| `crew_package` | Mission cargo | No | crew_mission_context |
| `creased_luck_card_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `instant_coffee_packet_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `ledger_pencil_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `cashout_envelope_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `lucky_bar_napkin_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `roadside_map_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `payment_calendar_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `pawn_receipt_sleeve_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `lucky_keychain_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `rabbits_foot_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `neon_player_charm_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `high_roller_watch_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `feature_magnet_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `golden_motel_token_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `roadside_luck_blue_bag` | Collection bag | No | collection_run_reward |
| `roadside_luck_purple_bag` | Collection bag | No | collection_run_reward |
| `roadside_luck_pink_bag` | Collection bag | No | collection_run_reward |
| `roadside_luck_red_bag` | Collection bag | No | collection_run_reward |
| `roadside_luck_gold_bag` | Collection bag | No | collection_run_reward |
| `cheap_sunglasses_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `scratch_pad_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `side_bet_chart_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `payout_pamphlet_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `marked_cards_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `edge_sort_loupe_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `timing_bracelet_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `cold_quarters_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `holdout_wax_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `split_reel_note_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `weighted_keyring_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `holdout_rig_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `coolers_cufflinks_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `velvet_table_key_meta` | Collection gear | No | collection_bag_open, meta_sal_gold_shop |
| `house_edge_blue_bag` | Collection bag | No | collection_run_reward |
| `house_edge_purple_bag` | Collection bag | No | collection_run_reward |
| `house_edge_pink_bag` | Collection bag | No | collection_run_reward |
| `house_edge_red_bag` | Collection bag | No | collection_run_reward |
| `house_edge_gold_bag` | Collection bag | No | collection_run_reward |
| `grand_casino_players_card` | Casino special reward | No | casino_terminal_reward |
| `grand_casino_chips` | Casino special reward | No | casino_terminal_reward |
| `profile_poker_chip` | Profile reference collectible | No | profile_acquire_button |
| `two_fer` | Inventory ticket / betting slip | No | scratch_merchandise |
| `lucky_7s` | Inventory ticket / betting slip | No | scratch_merchandise |
| `tic_tac_gold` | Inventory ticket / betting slip | No | scratch_merchandise |
| `crossword_corner` | Inventory ticket / betting slip | No | legacy_held_ticket |
| `bonus_bingo` | Inventory ticket / betting slip | No | scratch_merchandise |
| `high_roller_holdem` | Inventory ticket / betting slip | No | scratch_merchandise |
| `golden_vault` | Inventory ticket / betting slip | No | scratch_merchandise |
| `cherry_bells` | Inventory ticket / betting slip | No | pull_tab_merchandise |
| `lucky_sevens` | Inventory ticket / betting slip | No | pull_tab_merchandise |
| `pickle_card` | Inventory ticket / betting slip | No | pull_tab_merchandise |
| `bowl_game` | Inventory ticket / betting slip | No | pull_tab_merchandise |
| `moonlight_jars` | Inventory ticket / betting slip | No | pull_tab_merchandise |
| `velvet_kiss` | Inventory ticket / betting slip | No | pull_tab_merchandise |
| `delta_crown` | Inventory ticket / betting slip | No | pull_tab_merchandise |
| `cooler_cash` | Inventory ticket / betting slip | No | pull_tab_merchandise |
| `sealed_motor_part` | Mission cargo | No | crew_mission_context |
| `numbers_bag` | Mission cargo | No | crew_mission_context |
| `shift_note` | Mission cargo | No | crew_mission_context |
| `guest_list` | Mission cargo | No | crew_mission_context |
| `collection_note` | Mission cargo | No | crew_mission_context |
| `bar_ledger` | Mission cargo | No | crew_mission_context |
| `cage_packet` | Mission cargo | No | crew_mission_context |
| `route_packet` | Mission cargo | No | crew_mission_context |

## Mobile artifact verification

The matching `beat_the_house_item_audit_mobile.html` is a self-contained offline report, with all 153 records embedded from the categorized CSV. It offers search, role/category filters, a default ordinary-shop filter, overlapping contraband filter, an item chooser and previous/next navigation. It displays one item card at a time, with readable wrapped practical explanations and expandable current text/full analysis/evidence. No external fonts, scripts, assets or network dependencies are required; GitHub evidence links need a connection only when tapped.

An isolated bundled Chromium headless process tested the local report at 375×812 and 320px width, without opening or changing existing browser sessions. All 153 cards were opened with their details expanded, and full functionality text was checked. Maximum document width at the 375px viewport was 375px: no horizontal overflow. Search, empty state, selection, previous/next, the 60-item shop filter, 13-item shop+contraband intersection, 20-item contraband total, 28 collection gear filter and both review flags passed. There were zero JavaScript errors and zero network requests. Non-checkbox search/select/button controls meet the 44px minimum height check. Internal screenshots were inspected; they are not deliverables.

This validates the local HTML report layout and controls, not gameplay behavior or Library’s phone-preview support. The parent delivery must still verify the chosen phone-access route. CSV itself is data; the HTML provides the one-card navigation.
