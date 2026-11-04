#!/usr/bin/env python3
"""Read-only semantic and geometry contracts for current authored slot authority.

The catalog JSON is authored input. This module never regenerates or rewrites
its accepted geometry, phase positions, action hosts or saved authority.
"""
from __future__ import annotations
import argparse
import copy
import json
import math
import re
import sys
from collections import defaultdict
from functools import cache
from pathlib import Path
from typing import Any
import environment_fixed_slot_static_check as StaticCheck
import rw06_1_author_fixed_slots as SlotAuthoring

ROOT = Path(__file__).resolve().parents[1]


PLACEMENT_PATH = ROOT / "data" / "environments" / "placement_surfaces.json"


SCENARIO_PATH = ROOT / "data" / "environments" / "scenarios.json"


OUTPUT_PATH = ROOT / "data" / "environments" / "scenario_slot_layouts.json"


ROLE_SLOT_TOKEN = {
    "wall_mounted": "wall_item",
    "hanging": "hanging_item",
}


BOARD_WIDTH = 900.0


BOARD_HEIGHT = 430.0


SMALL_SCREEN_TARGET = (104.0, 76.0)


MANDATORY_ACCESS_LANE = [16.0, 378.0, 868.0, 36.0]


EXACT_ACTION_HOST_IDS: dict[tuple[str, str], dict[str, str]] = {
    ("back_alley", "back_alley_cruiser_parked"): {
        "event:scenario_cruiser_parked_watch": "scenario::patrol_officer",
    },
    ("back_alley", "back_alley_fence_night"): {
        "event:scenario_fence_night_mags": "scenario::goods_lot",
    },
    ("back_alley", "back_alley_nothing_moving"): {
        "event:scenario_nothing_moving_wait": "scenario::returning_regular",
    },
    ("back_alley", "back_alley_street_craps"): {
        "event:scenario_street_craps_circle": "scenario::chalk_ring",
    },
    ("bar", "bar_darts_league_night"): {
        "event:scenario_darts_league_decider": "scenario::bar_darts_league_night_league_captain",
    },
    ("bar", "bar_dead_tuesday"): {
        "event:scenario_dead_tuesday_regular": "scenario::bar_dead_tuesday_lone_patron",
    },
    ("bar", "bar_live_band"): {
        "event:scenario_live_band_request": "scenario::bar_live_band_band_leader",
    },
    ("bar", "bar_lock_in"): {
        "event:scenario_lock_in_private_game": "scenario::bar_lock_in_private_bench",
    },
    ("bar", "bar_wake"): {
        "event:scenario_wake_route_story": "scenario::bar_wake_wake_host",
    },
    ("beach", "beach_bonfire_night"): {
        "event:scenario_bonfire_story": "scenario::beach_bonfire_night_fire_tender",
    },
    ("beach", "beach_festival_weekend"): {
        "event:scenario_festival_lucky_pitch": "scenario::beach_festival_weekend_stall_vendor",
    },
    ("corner_store", "corner_store_aftermath"): {
        "event:scenario_aftermath_fence_offer": "scenario::suspect_object",
    },
    ("corner_store", "corner_store_dead_shift"): {
        "event:scenario_dead_shift_rumor": "scenario::night_clerk",
    },
    ("corner_store", "corner_store_delivery_day"): {
        "event:scenario_delivery_day_stock": "scenario::delivery_clerk",
    },
    ("corner_store", "corner_store_inventory_night"): {
        "event:scenario_inventory_night_count": "scenario::inventory_clerk",
    },
    ("corner_store", "corner_store_lotto_fever"): {
        "event:scenario_lotto_fever_jackpot": "scenario::lotto_regular",
    },
    ("delta_queen", "delta_queen_captains_invitational"): {
        "event:scenario_captains_invitational_card": "scenario::delta_queen_captains_invitational_captain_scorer",
    },
    ("delta_queen", "delta_queen_engine_trouble"): {
        "event:scenario_engine_trouble_repairs": "scenario::delta_queen_engine_trouble_engine_mate",
    },
    ("delta_queen", "delta_queen_fog_delay"): {
        "event:scenario_fog_delay_pool": "scenario::delta_queen_fog_delay_waiting_crowd",
    },
    ("delta_queen", "delta_queen_wedding_charter"): {
        "event:scenario_wedding_best_man": "scenario::delta_queen_wedding_charter_best_man",
    },
    ("delta_queen", "delta_queen_whale_aboard"): {
        "event:scenario_whale_aboard_vouch": "scenario::delta_queen_whale_aboard_whale_host",
    },
    ("gas_station_casino", "gas_station_graveyard_shift"): {
        "event:scenario_graveyard_maintenance": "scenario::gas_station_graveyard_shift_shutter_panel",
    },
    ("gas_station_casino", "gas_station_road_crew_payday"): {
        "event:scenario_road_crew_payday_pool": "scenario::gas_station_road_crew_payday_stake_envelope",
    },
    ("gas_station_casino", "gas_station_storm_shelter"): {
        "event:scenario_storm_shelter_corner": "character:nell",
    },
    ("gas_station_casino", "gas_station_tour_bus_stop"): {
        "event:scenario_tour_bus_ticket_rush": "scenario::gas_station_tour_bus_stop_ticket_basket",
    },
    ("gas_station_casino", "gas_station_trucker_convoy"): {
        "event:scenario_trucker_convoy_route": "scenario::gas_station_trucker_convoy_relay_driver",
    },
    ("grand_casino", "grand_casino_convention_crowd"): {
        "event:scenario_convention_badge": "scenario::grand_casino_convention_crowd_booking_board",
    },
    ("grand_casino", "grand_casino_gala_night"): {
        "event:scenario_gala_cover": "scenario::grand_casino_gala_night_gala_host",
    },
    ("jazz_club", "jazz_club_guest_legend"): {
        "event:scenario_guest_legend_tip": "scenario::jazz_club_guest_legend_guest_legend",
    },
    ("jazz_club", "jazz_club_recording_night"): {
        "event:scenario_recording_night_tape": "scenario::jazz_club_recording_night_recording_desk",
    },
    ("jazz_club", "jazz_club_rent_party"): {
        "event:chain06_trio_rent_payoff": "fixture:jazz_band_stage",
        "event:scenario_rent_party_hat": "scenario::jazz_club_rent_party_donation_station",
    },
    ("jazz_club", "jazz_club_union_trouble"): {
        "event:scenario_union_trouble_line": "scenario::jazz_club_union_trouble_picket_line",
    },
    ("kitty_cat_lounge", "kitty_cat_lounge_amateur_night"): {
        "event:scenario_amateur_night_applause": "scenario::kitty_cat_lounge_amateur_night_judging_desk",
    },
    ("kitty_cat_lounge", "kitty_cat_lounge_buyout"): {
        "event:scenario_buyout_rope": "scenario::kitty_cat_lounge_buyout_buyout_host",
    },
    ("kitty_cat_lounge", "kitty_cat_lounge_slow_night"): {
        "event:scenario_slow_night_intel": "staff:kitty_bar_host",
    },
    ("motel", "motel_stakeout"): {
        "event:scenario_stakeout_watch_or_leave": "scenario::motel_stakeout_north_observer",
    },
    ("motel", "motel_weekly_rates"): {
        "event:chain06_nico_what_it_covers": "scenario::motel_weekly_rates_landlord",
        "event:scenario_weekly_rates_soft_terms": "scenario::motel_weekly_rates_landlord",
    },
    ("pawn_shop", "pawn_shop_estate_lot_day"): {
        "event:scenario_estate_lot_provenance": "staff:pawn_counter_sal",
    },
    ("pawn_shop", "pawn_shop_sals_mood"): {
        "event:scenario_sals_mood_read": "staff:pawn_counter_sal",
    },
    ("pawn_shop", "pawn_shop_serial_check_day"): {
        "event:scenario_serial_check_hot_goods": "scenario::records_clerk",
    },
    ("small_underground_casino:casino", "punchline_greased_week"): {
        "event:scenario_greased_week_window": "scenario::punchline_greased_week_payoff_ledger",
    },
    ("small_underground_casino:casino", "punchline_high_stakes_night"): {
        "event:scenario_punchline_high_stakes_table": "scenario::punchline_high_stakes_night_protected_table",
    },
    ("small_underground_casino:casino", "punchline_new_muscle"): {
        "event:scenario_new_muscle_door": "scenario::punchline_new_muscle_new_guard_lead",
    },
    ("small_underground_casino:club", "punchline_bringer_show"): {
        "event:scenario_bringer_show_favor": "scenario::punchline_bringer_show_bringer_performer",
    },
    ("small_underground_casino:club", "punchline_headliner_night"): {
        "event:scenario_headliner_cover": "scenario::punchline_headliner_night_service_door",
    },
    ("small_underground_casino:club", "punchline_open_mic_night"): {
        "event:scenario_open_mic_signup": "scenario::punchline_open_mic_night_signup_lectern",
    },
    ("small_underground_casino:club", "punchline_raid_jitters"): {
        "event:scenario_raid_jitters_check": "scenario::punchline_raid_jitters_raid_lookout",
    },
}


EXACT_ATTACHED_SERVICE_HOST_IDS: dict[tuple[str, str], dict[str, str]] = {
    ("small_underground_casino:club", "punchline_bringer_show"): {
        # The rendered two-drink service occupies fixed.service_stage.
        "service:house_drink": "service:punchline_two_drink_minimum",
    },
    ("small_underground_casino:club", "punchline_headliner_night"): {
        "service:punchline_cover_charge": (
            "scenario::punchline_headliner_night_service_door"
        ),
    },
}


ACTION_ONLY_BASE_OBJECT_IDS = frozenset(
    action_id
    for action_hosts in EXACT_ACTION_HOST_IDS.values()
    for action_id in action_hosts
)


EXACT_ACTION_LABELS = {
    "event:scenario_cruiser_parked_watch": "Watch the Cruiser's Target",
    "event:scenario_fence_night_mags": "Ask for the Real Price",
    "event:scenario_nothing_moving_wait": "Wait Out the Light",
    "event:scenario_street_craps_circle": "Join the Chalk Ring",
    "event:scenario_darts_league_decider": "Bet the Deciding Leg",
    "event:scenario_dead_tuesday_regular": "Talk to the Last Regular",
    "event:scenario_live_band_request": "Make a Request",
    "event:scenario_lock_in_private_game": "Join the Private Game",
    "event:scenario_wake_route_story": "Hear the Empty-Stool Story",
    "event:scenario_bonfire_story": "Hear the Bonfire Story",
    "event:scenario_festival_lucky_pitch": "Hear Lucky's Pitch",
    "event:scenario_aftermath_fence_offer": "Inspect What Fell Off",
    "event:scenario_dead_shift_rumor": "Ask the Night Clerk",
    "event:scenario_delivery_day_stock": "Ask About Fresh Stock",
    "event:scenario_inventory_night_count": "Take the Short Count",
    "event:scenario_lotto_fever_jackpot": "Chase the Jackpot Rumor",
    "event:scenario_captains_invitational_card": "Enter with the Captain's Card",
    "event:scenario_engine_trouble_repairs": "Help Below Deck",
    "event:scenario_fog_delay_pool": "Join the Delayed Pool",
    "event:scenario_wedding_best_man": "Cover the Best Man's Hand",
    "event:scenario_whale_aboard_vouch": "Seek the Whale's Vouch",
    "event:scenario_graveyard_maintenance": "Study the Open Panel",
    "event:scenario_road_crew_payday_pool": "Join the Pay-Envelope Pool",
    "event:scenario_storm_shelter_corner": "Cover the Shelter Coffee",
    "event:scenario_tour_bus_ticket_rush": "Buy Regional Ticket Stock",
    "event:scenario_trucker_convoy_route": "Trade for the Convoy Route",
    "event:scenario_convention_badge": "Use a Borrowed Badge",
    "event:scenario_gala_cover": "Enter Under a Borrowed Name",
    "event:scenario_guest_legend_tip": "Tip the Guest Legend",
    "event:scenario_recording_night_tape": "Use the Recording Quiet",
    "event:chain06_trio_rent_payoff": "Keep the Rent-Party Promise",
    "event:scenario_rent_party_hat": "Contribute to the Rent Hat",
    "event:scenario_union_trouble_line": "Respond to the Meeting Line",
    "event:scenario_amateur_night_applause": "Back the First-Timer",
    "event:scenario_buyout_rope": "Approach the Private Rope",
    "event:scenario_slow_night_intel": "Ask the Bartender What She Knows",
    "event:scenario_stakeout_watch_or_leave": "Watch the Watchers",
    "event:chain06_nico_what_it_covers": "Ask Nico What It Covers",
    "event:scenario_weekly_rates_soft_terms": "Ask Nico for Soft Terms",
    "event:scenario_estate_lot_provenance": "Ask Sal About the Lot",
    "event:scenario_sals_mood_read": "Take Sal's First Quote",
    "event:scenario_serial_check_hot_goods": "Move the Hot Goods",
    "event:scenario_greased_week_window": "Mark the Paid-Quiet Window",
    "event:scenario_punchline_high_stakes_table": "Join the Serious Table",
    "event:scenario_new_muscle_door": "Face the New Guard Lead",
    "event:scenario_bringer_show_favor": "Fill a Chair for the Comic",
    "event:scenario_headliner_cover": "Use the House-Full Cover",
    "event:scenario_open_mic_signup": "Sign Up for Five Minutes",
    "event:scenario_raid_jitters_check": "Use the Second Check",
}


EXACT_TANGIBLE_EVENT_MARKERS: dict[
    tuple[str, str, str], dict[str, str]
] = {
    ("bar", "bar_fight_night", "event:scenario_fight_night_swing_bet"): {
        "category": "A",
        "label": "Fight-Night Betting Book",
        "placement_class": "surface_item",
        "environment_prop": "paper_note",
    },
    ("bar", "bar_payday_rush", "event:scenario_payday_rush_side_pot"): {
        "category": "A",
        "label": "Pay Envelope",
        "placement_class": "surface_item",
        "environment_prop": "paper_note",
    },
    (
        "kitty_cat_lounge",
        "kitty_cat_lounge_bachelorette_storm",
        "event:scenario_bachelorette_storm_table",
    ): {
        "category": "A",
        "label": "Reserved Party Table",
        "placement_class": "floor_fixture",
        "environment_prop": "room_surface",
    },
    ("motel", "motel_conventioneers", "event:scenario_conventioneers_room_nine"): {
        "category": "A",
        "label": "Room Nine Door",
        "placement_class": "doorway",
        "environment_prop": "motel_door",
    },
    ("motel", "motel_wedding_overflow", "event:scenario_wedding_overflow_hallway"): {
        "category": "A",
        "label": "Hallway Card Table",
        "placement_class": "floor_fixture",
        "environment_prop": "room_surface",
    },
    ("motel", "motel_weekly_rates", "event:chain06_nico_weekly_door"): {
        "category": "A",
        "label": "Nico's Weekly-Room Door",
        "placement_class": "doorway",
        "environment_prop": "motel_door",
    },
    ("pawn_shop", "pawn_shop_estate_lot_day", "event:chain06_sal_estate_item"): {
        "category": "A",
        "label": "Estate Map",
        "placement_class": "surface_item",
        "environment_prop": "paper_note",
    },
    ("back_alley", "back_alley_fence_night", "event:recruitment_mags"): {
        "category": "B",
        "label": "Mags",
        "placement_class": "standing_person",
        "environment_prop": "character_actor",
    },
    ("bar", "bar_fight_night", "event:recruitment_knuckles"): {
        "category": "B",
        "label": "Knuckles",
        "placement_class": "standing_person",
        "environment_prop": "character_actor",
    },
    ("beach", "beach_festival_weekend", "event:recruitment_lucky"): {
        "category": "B",
        "label": "Lucky",
        "placement_class": "standing_person",
        "environment_prop": "character_actor",
        "environment_actor": False,
    },
    ("beach", "beach_storm_coming", "event:scenario_storm_stranger"): {
        "category": "B",
        "label": "Storm-Watching Stranger",
        "placement_class": "standing_person",
        "environment_prop": "patron_talk",
        "environment_actor": False,
    },
    (
        "gas_station_casino",
        "gas_station_trucker_convoy",
        "event:recruitment_switch",
    ): {
        "category": "B",
        "label": "Switch",
        "placement_class": "standing_person",
        "environment_prop": "character_actor",
    },
    ("kitty_cat_lounge", "kitty_cat_lounge_buyout", "event:recruitment_velvet"): {
        "category": "B",
        "label": "Velvet",
        "placement_class": "standing_person",
        "environment_prop": "character_actor",
    },
    (
        "kitty_cat_lounge",
        "kitty_cat_lounge_slow_night",
        "event:recruitment_velvet",
    ): {
        "category": "B",
        "label": "Velvet",
        "placement_class": "standing_person",
        "environment_prop": "character_actor",
    },
    (
        "small_underground_casino:club",
        "punchline_debt_court",
        "event:scenario_debt_court_office_hours",
    ): {
        "category": "B",
        "label": "The Collector",
        "placement_class": "standing_person",
        "environment_prop": "character_actor",
    },
}


ATTACHED_CONTROL_ROLES = {
    "decision_route",
    "task_station",
    "task_zone",
}


SCENARIO_ART_TOKEN_GROUPS: tuple[tuple[str, set[str]], ...] = (
    ("security_camera", {"camera", "monitor", "scope", "surveillance"}),
    ("payphone", {"phone", "payphone"}),
    ("side_door", {"exit", "door", "doorway", "gangway", "hatch"}),
    ("jammed_machine", {"machine", "workstation", "terminal", "engine", "generator", "pump", "repair", "tool", "tools", "speaker", "equipment", "panel", "microphone", "cable", "circuit", "control", "cooler", "sink", "job", "jobs"}),
    ("room_vehicle", {"vehicle", "rig", "cruiser", "bus", "dolly", "patrol", "car"}),
    ("room_hazard", {"fire", "smoke", "fog", "storm", "flood", "leak", "hazard"}),
    ("room_display", {"gauge", "instrument", "board", "score", "scoreboard", "bracket", "display", "screen", "slate", "tally"}),
    ("room_route", {"route", "lane", "corridor", "path", "aisle", "trail", "ring", "detour", "arrow", "arrows", "footprint", "footprints", "evacuation", "tape"}),
    ("room_barrier", {"rope", "rail", "boarded", "barrier", "barricade", "fence", "picket", "windbreak", "cage", "cordon", "gate", "gates", "shutter", "shutters", "beam"}),
    ("room_seating", {"chair", "chairs", "seat", "seats", "booth", "bench", "benches", "stool"}),
    ("room_refreshment", {"bottle", "drink", "keg", "food", "cup", "coffee"}),
    ("room_surface", {"table", "tables", "counter", "desk", "lectern", "stage", "platform", "surface", "stand", "stall", "station"}),
    ("room_storage", {"bed", "furniture", "rack", "shelf", "cart", "tray", "trolley", "stack", "dock", "coat", "case", "cases", "suitcase", "suitcases"}),
    ("trunk_offer", {"crate", "carton", "stock", "goods", "luggage", "trunk", "pallet", "box", "boxes", "pouch"}),
    ("paper_note", {"manifest", "paper", "label", "evidence", "ledger", "record", "ticket", "badge", "clipboard", "note", "card", "cards", "tag", "sheet", "slip", "receipt", "pencil", "placard", "placards", "envelope"}),
    ("room_signal", {"light", "lights", "flashlight", "lamp", "sign", "signal", "beacon", "marker"}),
    ("room_trace", {"trace", "traces", "clue", "clues", "aftermath", "debris", "abandoned", "interrupted"}),
)


SCENARIO_ART_CLASS_DEFAULTS = {
    "doorway": "side_door",
    "wall_mounted": "room_display",
    "hanging": "room_signal",
    "surface_item": "paper_note",
    "shop_item": "trunk_offer",
    "ground_marker": "room_route",
    "seated_person": "room_seating",
    "floor_fixture": "room_fixture",
    "standing_person": "room_fixture",
    "behind_counter_person": "room_fixture",
    "group": "room_fixture",
}


EXACT_PLACEMENT_CLASS_OVERRIDES = {
    "angry_queue": "ground_marker",
    # Manual-facing labels name the individual props inside these stations.
    # Keep their reviewed counter/curb placement classes independent of noun
    # wording so a clearer label cannot silently move them into a wall bank.
    "auth_station": "surface_item",
    "brokered_exit": "surface_item",
    "bar_lock_in_cellar_hatch": "doorway",
    "celebration_layout": "surface_item",
    "delivery_event_gate": "surface_item",
    "delta_queen_captains_invitational_entry_cards": "surface_item",
    "delta_queen_fog_delay_gangway_shutter": "doorway",
    "delta_queen_fog_delay_aftermath_fog_departure_prop": "doorway",
    "delta_queen_wedding_charter_ring_case": "surface_item",
    "gas_station_tour_bus_stop_aftermath_count_refused": "ground_marker",
    "kitty_cat_lounge_bachelorette_storm_bar_route_rope": "ground_marker",
    "lookout_marker": "surface_item",
    "motel_weekly_rates_lease_clipboard": "surface_item",
    "punchline_headliner_night_service_door": "doorway",
    "serial_station": "surface_item",
    "delta_queen_fog_delay_aftermath_assisted_reroute_prop": "ground_marker",
    "delta_queen_whale_aboard_aftermath_shadowed_entourage_prop": "ground_marker",
    "unfinished_jobs": "surface_item",
}


SCENARIO_ART_STABLE_OVERRIDES = {
    # Final reviewed physical nouns for exact scenario layouts. These entries
    # deliberately supersede broad legacy map/payload icons below.
    "angry_queue": "room_route",
    "auth_station": "room_surface",
    "bar_fight_night_door_buffer": "room_route",
    "bar_live_band_cable_crossing": "room_hazard",
    "bar_lock_in_locked_shutters": "room_barrier",
    "bar_payday_rush_order_rail": "room_surface",
    "beach_bonfire_night_bonfire_ring": "room_hazard",
    "beach_bonfire_night_windbreak": "room_barrier",
    "beach_storm_coming_warning_flag": "room_signal",
    "cruiser_beam": "room_signal",
    "cruiser_departed": "room_trace",
    "delivery_event_gate": "paper_note",
    "delta_queen_captains_invitational_scorer_rail": "room_display",
    "delta_queen_engine_trouble_engine_bulkhead": "room_barrier",
    "delta_queen_fog_delay_gangway_shutter": "side_door",
    "delta_queen_wedding_charter_ceremony_rope": "room_barrier",
    "delta_queen_wedding_charter_ring_case": "room_storage",
    "diverted_patrol": "room_trace",
    "gas_station_graveyard_shift_cooler_gate": "room_barrier",
    "gas_station_road_crew_payday_barricade_stack": "room_barrier",
    "gas_station_road_crew_payday_repair_crate": "trunk_offer",
    "gas_station_tour_bus_stop_aftermath_bus_boarded": "side_door",
    "gas_station_tour_bus_stop_aftermath_count_refused": "room_route",
    "gas_station_tour_bus_stop_restroom_queue": "room_signal",
    "gas_station_trucker_convoy_lead_rig": "room_signal",
    "gas_station_trucker_convoy_relay_rig": "room_signal",
    "gas_station_trucker_convoy_tail_rig": "room_signal",
    "grand_casino_audit_night_audit_barrier": "room_barrier",
    "grand_casino_audit_night_open_exit_marker": "room_signal",
    "grand_casino_gala_night_stage_lift": "jammed_machine",
    "jazz_club_guest_legend_instrument_case": "room_storage",
    "jazz_club_union_trouble_management_rope": "room_barrier",
    "jazz_club_union_trouble_picket_line": "room_barrier",
    "kitty_cat_lounge_buyout_buyout_ropes": "room_barrier",
    "kitty_cat_lounge_slow_night_closed_section_ropes": "room_barrier",
    "lookout_marker": "room_signal",
    "punchline_bringer_show_crowd_ropes": "room_barrier",
    "punchline_debt_court_paused_table_rope": "room_barrier",
    "punchline_greased_week_payoff_ledger": "paper_note",
    "punchline_greased_week_service_barrier": "room_barrier",
    "punchline_headliner_night_credential_rope": "room_barrier",
    "punchline_high_stakes_night_observer_rail": "room_barrier",
    "punchline_new_muscle_guard_posts": "room_barrier",
    "punchline_raid_jitters_clear_bins": "room_storage",
    "punchline_raid_jitters_room_screen": "room_barrier",
    "returned_cart": "room_storage",
    "surveillance_rumor_route": "paper_note",
    # This is a stack of sightline-blocking crates. A scenario action attached
    # to it carries a legacy paper-note icon, but the physical prop must retain
    # the room-storage silhouette in the exact placement layout.
    "stacked_cover": "room_storage",
}


EXACT_SCENARIO_LABEL_OVERRIDES = {
    "angry_queue": "Disputed Queue Marks",
    "auth_station": "Authentication Loupe, Lamp, and Ledger",
    "auth_station_abandoned": "Abandoned Loupe and Open Ledger",
    "brokered_exit": "Closed Broker Ledger",
    "buyer_control": "Buyer-Tagged Goods Table",
    "buyer_control_refused": "Tagged Refused Goods Lot",
    "celebration_layout": "Winning Slips and Cups",
    "delivery_event_gate": "Damaged Delivery Manifest",
    "economy_fence_public_service": "Public Price Card",
    "economy_inventory_public_service": "Public Inventory Notice",
    "economy_provenance_public_service": "Public Provenance Card",
    "economy_stock_public_service": "Public Stock Notice",
    "gas_station_tour_bus_stop_aftermath_count_refused": "Overflow Queue Line",
    "gas_station_graveyard_shift_machine_gate": "Machine-Zone Gate",
    "grand_casino_convention_crowd_table_block": "Delegation Cart Block",
    "grand_casino_gala_night_stage_lift": "Stalled Stage Lift",
    "hold_object": "Wrapped Item Awaiting Serial Check",
    "hold_object_abandoned": "Unsealed Item and Unfinished Carbon Copy",
    "kitty_cat_lounge_amateur_night_judging_desk": "Judges' Card Desk",
    "kitty_cat_lounge_slow_night_maintenance_panel": "Maintenance Panel",
    "lit_service": "Lit Cooler Bank",
    "lookout_marker": "Bottle-Cap Lookout Signal",
    "lookout_marker_abandoned": "Fallen Bottle-Cap Lookout Signal",
    "private_darkness": "Dark Cooler Bank and Closed Register",
    "quiet_recovery": "Repaired Glass and Trace Bag",
    "reopened_sections": "Signed Open Shelves",
    "service_appraisal_public_service": "Posted Appraisal Sheet",
    "serial_station": "Serial Lamp and Carbon Sheet",
    "suspect_object": "Unidentified Object by Swept Glass",
    "suspect_object_abandoned": "Unbagged Unidentified Evidence",
    "surveillance_rumor_route": "Handwritten Camera Warning",
    "unfinished_jobs": "Half-Finished Repairs",
}


CONDITIONAL_SCENARIO_OBJECTS: dict[tuple[str, str], list[dict[str, str]]] = {
    ("pawn_shop", "pawn_shop_estate_lot_day"): [
        {
            "object_id": "event:chain06_sal_estate_item",
            "placement_class": "surface_item",
            "label": "Estate Map",
        },
    ],
    ("motel", "motel_weekly_rates"): [
        {
            "object_id": "event:chain06_nico_weekly_door",
            "placement_class": "doorway",
            "label": "Nico's Weekly-Room Door",
        },
    ],
    ("gas_station_casino", "gas_station_trucker_convoy"): [
        {
            "object_id": "event:recruitment_switch",
            "placement_class": "standing_person",
            "label": "Switch",
        },
    ],
    ("back_alley", "back_alley_fence_night"): [
        {
            "object_id": "event:recruitment_mags",
            "placement_class": "standing_person",
            "label": "Mags",
        },
    ],
    ("bar", "bar_fight_night"): [
        {
            "object_id": "event:recruitment_knuckles",
            "placement_class": "standing_person",
            "label": "Knuckles",
        },
    ],
    ("kitty_cat_lounge", "kitty_cat_lounge_buyout"): [
        {
            "object_id": "event:recruitment_velvet",
            "placement_class": "standing_person",
            "label": "Velvet",
        },
    ],
    ("kitty_cat_lounge", "kitty_cat_lounge_slow_night"): [
        {
            "object_id": "event:recruitment_velvet",
            "placement_class": "standing_person",
            "label": "Velvet",
        },
    ],
    ("beach", "beach_festival_weekend"): [
        {
            "object_id": "event:recruitment_lucky",
            "placement_class": "standing_person",
            "label": "Lucky",
        },
    ],
}


def values(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def mapping(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


@cache
def base_semantics() -> dict[str, dict[str, Any]]:
    return SlotAuthoring.collect_base_semantics(ROOT)


def clean_slug(value: str) -> str:
    cleaned = re.sub(r"[^a-z0-9]+", "_", value.strip().lower()).strip("_")
    return cleaned or "object"


def friendly(value: str) -> str:
    return clean_slug(value).replace("_", " ").title()


def exact_scenario_art_key(
    surface: dict[str, Any],
    semantic: dict[str, Any],
    actor: bool,
    safe_exit: bool,
    navigation_exit: bool,
    placement_class: str,
) -> str:
    if actor:
        return ""
    identity = str(semantic.get("identity", "")).strip()
    stable_id = str(
        semantic.get("stable_object_id", identity.removeprefix("scenario::"))
    ).strip()
    if stable_id in SCENARIO_ART_STABLE_OVERRIDES:
        return SCENARIO_ART_STABLE_OVERRIDES[stable_id]
    reviewed = StaticCheck._v2_scenario_art_key(
        surface, semantic, actor, safe_exit, navigation_exit
    )
    if reviewed:
        return reviewed
    scenario_id = str(semantic.get("_slot_scenario_id", "")).strip()
    local_identity = stable_id.removeprefix(f"{scenario_id}_") if scenario_id else stable_id
    token_tiers = [
        set(re.findall(
            r"[a-z0-9]+",
            " ".join(
                str(semantic.get(field, ""))
                for field in ("label", "display_name", "prop")
            ).lower(),
        )),
        set(re.findall(r"[a-z0-9]+", local_identity.lower())),
        set(re.findall(r"[a-z0-9]+", str(semantic.get("role", "")).lower())),
    ]
    for tokens in token_tiers:
        if not tokens:
            continue
        if tokens & {"bench", "benches"} and tokens & {"task", "work", "service"}:
            return "room_surface"
        for art_key, candidate_tokens in SCENARIO_ART_TOKEN_GROUPS:
            if tokens & candidate_tokens:
                return art_key
    return SCENARIO_ART_CLASS_DEFAULTS.get(placement_class, "room_fixture")


def effective_map(base: dict[str, Any], scenario_id: str) -> dict[str, Any]:
    result = copy.deepcopy(base)
    override = mapping(mapping(base.get("scenario_overrides")).get(scenario_id))
    base_classes = copy.deepcopy(mapping(base.get("class_overrides")))
    result.update(copy.deepcopy(override))
    base_classes.update(copy.deepcopy(mapping(override.get("class_overrides"))))
    result["class_overrides"] = base_classes
    return result


def scenario_rows() -> list[tuple[str, str, dict[str, Any]]]:
    catalog = json.loads(SCENARIO_PATH.read_text(encoding="utf-8"))
    rows: list[tuple[str, str, dict[str, Any]]] = []
    for host_id, host_rows in catalog.items():
        for row in values(host_rows):
            if not isinstance(row, dict):
                continue
            layer_id = str(row.get("layer_id", "")).strip()
            map_id = f"{host_id}:{layer_id}" if layer_id else str(host_id)
            rows.append((map_id, str(row.get("id", "")), row))
    return sorted(rows, key=lambda item: (item[0], item[1]))


def snapshots_by_scenario() -> dict[tuple[str, str], list[list[dict[str, Any]]]]:
    result: dict[tuple[str, str], list[list[dict[str, Any]]]] = defaultdict(list)
    for map_id, snapshots in SlotAuthoring.collect_active_phase_snapshots(
        ROOT, include_aftermath=True
    ).items():
        for snapshot in snapshots:
            scenario_id = next(
                (
                    str(entry.get("_slot_scenario_id", "")).strip()
                    for entry in snapshot
                    if isinstance(entry, dict)
                    and str(entry.get("_slot_scenario_id", "")).strip()
                ),
                "",
            )
            if scenario_id:
                result[(map_id, scenario_id)].append(snapshot)
    return result


def visual_entry(
    surface: dict[str, Any], semantic: dict[str, Any]
) -> dict[str, Any] | None:
    if bool(semantic.get("_slot_interaction_only", False)) or bool(
        semantic.get("_slot_nonvisual", False)
    ):
        return None
    identity = str(semantic.get("identity", "")).strip()
    if not identity.startswith("scenario::") or not bool(
        semantic.get("present", True)
    ):
        return None
    if str(semantic.get("role", "")).strip().lower() in ATTACHED_CONTROL_ROLES:
        return None
    stable_id = identity.removeprefix("scenario::")
    interaction = mapping(semantic.get("_slot_interaction"))
    actor = bool(semantic.get("_slot_actor", False))
    safe_exit = bool(interaction.get("safe_exit", semantic.get("safe_exit", False)))
    navigation_exit = StaticCheck._v2_interaction_navigates_environment(interaction)
    if navigation_exit:
        # Real travel continues to use the shared exit family.
        return None
    reviewed_art_key = StaticCheck._v2_scenario_art_key(
        surface, semantic, actor, safe_exit, navigation_exit
    )
    # A scene_ops object is itself positive visual authority. The generated
    # exact mapping closes its geometry before runtime, so it does not need a
    # bespoke art key merely to receive a manual position. Interaction-only
    # records were filtered above and continue to attach to tangible hosts.
    classified = copy.deepcopy(semantic)
    if reviewed_art_key:
        classified["icon_key"] = reviewed_art_key
    class_overrides = mapping(surface.get("class_overrides"))
    placement_class = SlotAuthoring.classify_with_override(
        classified,
        "actor" if actor else "scene_object",
        identity,
        str(class_overrides.get(identity, class_overrides.get(stable_id, ""))),
    )
    if safe_exit:
        placement_class = "doorway"
    placement_class = EXACT_PLACEMENT_CLASS_OVERRIDES.get(stable_id, placement_class)
    art_key = exact_scenario_art_key(
        surface,
        semantic,
        actor,
        safe_exit,
        navigation_exit,
        placement_class,
    )
    position_key = SlotAuthoring.scenario_position_key(stable_id, semantic)
    route_id = str(semantic.get("route_id", "")).strip() or str(
        mapping(surface.get("scenario_position_route_ids")).get(position_key, "")
    ).strip()
    preferences = mapping(surface.get("scenario_slot_ids"))
    preferred = next(
        (
            str(preferences[key])
            for key in (position_key, stable_id, identity)
            if key and key in preferences
        ),
        "",
    )
    label = EXACT_SCENARIO_LABEL_OVERRIDES.get(
        stable_id,
        str(semantic.get("label", "")).strip() or friendly(stable_id),
    )
    return {
        "node_key": position_key,
        "position_key": position_key,
        "identity": identity,
        "stable_id": stable_id,
        "placement_class": placement_class,
        "label": label,
        "label_variants": [label] if label else [],
        "preferred_slot_id": preferred,
        "route_id": route_id,
        "zone_id": str(semantic.get("zone_id", "")).strip(),
        "semantic": copy.deepcopy(semantic),
        "actor": actor,
        "art_key": art_key,
        "base_record": False,
    }


def _rect_intersects(left: list[float], right: list[float]) -> bool:
    return not (
        left[0] + left[2] <= right[0]
        or right[0] + right[2] <= left[0]
        or left[1] + left[3] <= right[1]
        or right[1] + right[3] <= left[1]
    )


def _expanded_hit_rect(rect: list[float]) -> list[float]:
    width = max(float(rect[2]), SMALL_SCREEN_TARGET[0])
    height = max(float(rect[3]), SMALL_SCREEN_TARGET[1])
    x = float(rect[0]) - (width - float(rect[2])) / 2.0
    y = float(rect[1]) - (height - float(rect[3])) / 2.0
    return [
        min(max(0.0, x), BOARD_WIDTH - width),
        min(max(0.0, y), BOARD_HEIGHT - height),
        width,
        height,
    ]


def _rect_contains_center(rect: list[float], target: list[float]) -> bool:
    center_x = target[0] + target[2] / 2.0
    center_y = target[1] + target[3] / 2.0
    return (
        rect[0] <= center_x <= rect[0] + rect[2]
        and rect[1] <= center_y <= rect[1] + rect[3]
    )


def reviewed_grand_capacity_addition(map_data: dict[str, Any]) -> bool:
    """One reviewed House Calls pit-boss bank beyond the old 30-row ceiling."""
    rows = [row for row in values(map_data.get("event_slots"))
            if isinstance(row, dict) and row.get("id") == "event.behind_counter_person_3"]
    return (map_data.get("id") == "grand_casino" and len(rows) == 1
            and rows[0].get("kind") == "event"
            and rows[0].get("footprint_class") == "behind_counter_person"
            and rows[0].get("physical_role") == "Pit boss"
            and rows[0].get("occupant_ids") == ["event:the_house_calls"]
            and rows[0].get("runtime_reserve") is False)


def semantic_zone_conflicts(layout: dict[str, Any], entries: list[dict[str, Any]]) -> list[str]:
    """Validate current semantic aliases; no allocation or graph coloring."""
    zones: dict[str, set[str]] = defaultdict(set)
    preferences = mapping(layout.get("scenario_instance_slot_ids"))
    for entry in entries:
        if entry.get("route_id"):
            continue
        slot_id = str(preferences.get(entry.get("position_key", ""), ""))
        zone = str(entry.get("zone_id", "")).strip()
        if slot_id and zone:
            zones[slot_id].add(zone)
    return sorted(slot_id for slot_id, claims in zones.items() if len(claims) > 1)


def current_effective_surface(
    surface: dict[str, Any], scenario_id: str,
    layouts: dict[tuple[str, str], dict[str, Any]],
    project_rooms: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Compose authored authority then apply the committed rigid slot overlay.

    Matches EnvironmentPlacement._with_slot_overrides/_translate_slot and
    DeveloperPlacementStore._room_slot_overrides. Object scale does not change
    contact/interaction geometry. User-machine edits are deliberately excluded.
    """
    result = StaticCheck._v2_effective_scenario_map(surface, scenario_id, layouts)
    result = copy.deepcopy(result)
    if project_rooms is None:
        project_rooms = mapping(json.loads((ROOT / "data/environments/developer_placement_overrides.json").read_text(encoding="utf-8")).get("rooms"))
    room = mapping(project_rooms.get(str(surface.get("id", ""))))
    local = mapping(mapping(room.get("scenario_layouts")).get(scenario_id))
    positions = {**mapping(room.get("slot_positions")), **mapping(local.get("slot_positions"))}
    layers = {**mapping(room.get("slot_layers")), **mapping(local.get("slot_layers"))}
    scales = {**mapping(room.get("slot_scales")), **mapping(local.get("slot_scales"))}
    for family in ("fixed", "event", "scenario", "exit"):
        for slot in values(result.get(family + "_slots")):
            if not isinstance(slot, dict):
                continue
            slot_id = str(slot.get("id", ""))
            if slot_id in positions:
                target = positions[slot_id]
                if not isinstance(target, list) or len(target) != 2 or any(isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) for value in target):
                    raise ValueError("slot overlay requires two finite JSON numbers")
                delta = [target[index] - slot["pos"][index] for index in range(2)]
                slot["pos"] = list(target)
                for field in ("hit_rect", "label_anchor"):
                    if field in slot:
                        slot[field][:2] = [slot[field][index] + delta[index] for index in range(2)]
            if slot_id in layers:
                layer = layers[slot_id]
                if isinstance(layer, bool) or not isinstance(layer, (int, float)) or layer not in (-1, 0, 1):
                    raise ValueError("slot draw layer must be -1, 0 or 1")
                slot["draw_layer"] = int(layer)
            if slot_id in scales:
                scale = scales[slot_id]
                if isinstance(scale, bool) or not isinstance(scale, (int, float)) or not math.isfinite(scale) or not 0.5 <= scale <= 2.0:
                    raise ValueError("slot visual scale must be between 0.5 and 2")
                slot["object_scale"] = float(scale)
    return result


def current_geometry_audit(surface: dict[str, Any], active_ids: set[str]) -> dict[str, Any]:
    """Separate capacity diagnostics from active shared-route obstructions.

    PixelSceneCanvas permits scenario-local overlap, retaining diagnostics and
    deterministic selection. Shared route endpoints keep its strict expanded
    meaningful-intersection policy. No slot-ID or scenario-name exceptions.
    """
    slots = {str(slot.get("id", "")): slot for family in ("fixed", "event", "scenario", "exit")
             for slot in values(surface.get(family + "_slots")) if isinstance(slot, dict)}
    missing = sorted(active_ids - slots.keys())
    if missing:
        raise ValueError("active geometry names missing slots: " + ", ".join(missing))
    endpoints = {str(route.get(field, "")) for route in values(surface.get("actor_routes"))
                 if isinstance(route, dict) for field in ("start_slot_id", "end_slot_id", "reduced_motion_slot_id")}
    diagnostics = []
    strict = []
    for index, left_id in enumerate(sorted(slots)):
        left = slots[left_id]
        for right_id in sorted(slots)[index+1:]:
            right = slots[right_id]
            a, b = _expanded_hit_rect(left["hit_rect"]), _expanded_hit_rect(right["hit_rect"])
            width = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
            height = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
            if width <= 1.01 or height <= 1.01:
                continue
            active = left_id in active_ids and right_id in active_ids
            local = bool(left.get("scenario_instance")) or bool(right.get("scenario_instance"))
            pair = (left_id, right_id)
            diagnostics.append({"pair": pair, "simultaneously_active": active, "scenario_local_advisory": local})
            if active and not local and (left_id in endpoints or right_id in endpoints):
                strict.append(pair)
    return {"strict_conflicts": strict, "overlap_diagnostics": diagnostics}


def check_current_authority() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate the current authored JSON without writing any file")
    parser.parse_args()
    placement = json.loads(PLACEMENT_PATH.read_text(encoding="utf-8"))
    catalog = json.loads(SCENARIO_PATH.read_text(encoding="utf-8"))
    maps = {str(row.get("id", "")): row for row in values(placement.get("maps"))}
    check = StaticCheck.Check()
    layouts, count = StaticCheck._v2_load_scenario_layouts(check, ROOT, maps, catalog)
    if check.errors:
        for error in check.errors:
            print(error, file=sys.stderr)
        return 1
    print(f"SCENARIO_SLOT_AUTHORITY_CHECK PASS layouts={len(layouts)} slots={count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(check_current_authority())
