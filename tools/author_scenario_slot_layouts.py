#!/usr/bin/env python3
"""Author scenario-scoped physical slot instances for every catalog layout.

Shared fixed, event, and exit slots remain in placement_surfaces.json.
This companion authority restores the object-specific scenario placement that
was lost when all scenario visuals were collapsed into map-wide class pools.
The runtime overlays exactly one layout and keeps only explicitly marked
runtime-reserve scenario capacity beside it.
"""

from __future__ import annotations

import argparse
import copy
import json
import re
import sys
from collections import Counter, defaultdict
from functools import cache
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT / "tools") not in sys.path:
    sys.path.insert(0, str(ROOT / "tools"))

import environment_fixed_slot_static_check as StaticCheck  # noqa: E402
import rw06_1_author_fixed_slots as SlotAuthoring  # noqa: E402


PLACEMENT_PATH = ROOT / "data" / "environments" / "placement_surfaces.json"
SCENARIO_PATH = ROOT / "data" / "environments" / "scenarios.json"
OUTPUT_PATH = ROOT / "data" / "environments" / "scenario_slot_layouts.json"
SCHEMA_VERSION = 1
TEMPLATE_ONLY_MAP_IDS = {"small_underground_casino"}
ROLE_SLOT_TOKEN = {
    "wall_mounted": "wall_item",
    "hanging": "hanging_item",
}
BOARD_WIDTH = 900.0
BOARD_HEIGHT = 430.0
SMALL_SCREEN_TARGET = (104.0, 76.0)
MANDATORY_ACCESS_LANE = [16.0, 378.0, 868.0, 36.0]

# Reviewed corrections for a source position that is valid in isolation but
# cannot coexist with its scenario obstruction.  Keep this keyed by the exact
# semantic position, so a later manual report can replace it without moving the
# same object in its other phase/zone.
EXACT_POSITION_RECT_OVERRIDES: dict[tuple[str, str, str], list[float]] = {
    (
        "delta_queen",
        "delta_queen_wedding_charter",
        "delta_queen_wedding_charter_ring_case||right|",
    ): [160.0, 80.0, 72.0, 48.0],
    (
        "grand_casino",
        "grand_casino_convention_crowd",
        "grand_casino_convention_crowd_table_block|grand_work_object_left|center|",
    ): [700.0, 150.0, 44.0, 44.0],
}

# These event records are actions attached to an already tangible room host.
# The (map, scenario) key is deliberate: it makes the attachment exact and
# reviewable instead of relying on prop/class heuristics.  None of these action
# ids may create a second physical object or a manual-placement marker.
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

# These catalog services remain gameplay actions, but in the two exact
# Punchline layouts below they are presented through a tangible room host
# instead of receiving a second manual-placement marker. Keep this authority
# separate from EXACT_ACTION_HOST_IDS: that event-only table also owns the
# reviewed event catalog labels and terminal resolved-event lifecycle.
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

# The remaining reviewed event markers are literal room objects (A) or named
# people (B).  Their labels and classes describe what the owner will actually
# position, never the action performed through them.
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

# These scene-operation records describe actions performed through an existing
# room object.  They stay in the semantic interaction graph, but never become
# separate manual-placement markers.  ``game_lane`` is intentionally absent:
# its lane is tangible room geometry and remains scenario-positioned.
ATTACHED_CONTROL_ROLES = {
    "decision_route",
    "task_station",
    "task_zone",
}

# Exact scenario layouts are sealed presentation authority, not only geometry.
# Use the same small concrete silhouette vocabulary as the production canvas so
# every later-phase prop has a deterministic renderer before it can enter a
# room. Object nouns win; footprint class is only the final conservative
# fallback for genuinely generic authored fixtures.
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

# Scenario-conditioned runtime records that are not declared by the catalog's
# mutation arrays still belong to the one scenario layout in which they can
# appear. Their broad role is explicit here so unstable prop heuristics cannot
# relabel named recruitment actors as counters or doors.
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


def scenario_base_objects(
    map_id: str,
    scenario_id: str,
    surface: dict[str, Any],
    scenario_row: dict[str, Any],
) -> list[dict[str, Any]]:
    serialized = json.dumps(scenario_row, sort_keys=True, separators=(",", ":"))
    slots = {
        str(slot.get("id", "")): slot
        for slot in values(surface.get("scenario_slots"))
        if isinstance(slot, dict)
    }
    class_overrides = mapping(surface.get("class_overrides"))
    family_ids = mapping(surface.get("object_family_ids"))
    candidates: dict[str, dict[str, str]] = {}
    for object_id, old_slot_id_value in sorted(
        mapping(surface.get("scenario_object_slot_ids")).items()
    ):
        old_slot_id = str(old_slot_id_value)
        old_slot = mapping(slots.get(old_slot_id))
        source_id = str(object_id).partition(":")[2]
        if not source_id or source_id not in serialized or not old_slot:
            continue
        candidates[str(object_id)] = {
            "source_id": source_id,
            "preferred_slot_id": old_slot_id,
            "object_type": str(object_id).partition(":")[0],
        }

    source_fields = {
        "event_pool_add": "event",
        "service_add": "service",
        "item_offer_add": "item",
        "game_pool_add": "game",
    }
    for node in StaticCheck._v2_iter_dict_nodes(scenario_row):
        for field, prefix in source_fields.items():
            for raw in values(node.get(field)):
                source_id = (
                    raw.strip()
                    if isinstance(raw, str)
                    else str(raw.get("id", "")).strip()
                    if isinstance(raw, dict)
                    else ""
                )
                if not source_id:
                    continue
                object_id = f"{prefix}:{source_id}"
                declared_family = str(family_ids.get(object_id, ""))
                if declared_family == "fixed":
                    continue
                old_slot_id = str(
                    mapping(surface.get("scenario_object_slot_ids")).get(object_id, "")
                )
                candidates[object_id] = {
                    "source_id": source_id,
                    "preferred_slot_id": old_slot_id,
                    "object_type": prefix,
                }
        opportunity = mapping(node.get("exclusive_opportunity"))
        for field, prefix in (("event_id", "event"), ("game_id", "game")):
            source_id = str(opportunity.get(field, "")).strip()
            if not source_id:
                continue
            object_id = f"{prefix}:{source_id}"
            if str(family_ids.get(object_id, "")) == "fixed":
                continue
            candidates[object_id] = {
                "source_id": source_id,
                "preferred_slot_id": str(
                    mapping(surface.get("scenario_object_slot_ids")).get(object_id, "")
                ),
                "object_type": prefix,
            }

    for conditional in CONDITIONAL_SCENARIO_OBJECTS.get((map_id, scenario_id), []):
        object_id = str(conditional["object_id"])
        candidates[object_id] = {
            "source_id": object_id.partition(":")[2],
            "preferred_slot_id": str(
                mapping(surface.get("scenario_object_slot_ids")).get(object_id, "")
            ),
            "object_type": object_id.partition(":")[0],
            "placement_class": str(conditional["placement_class"]),
            "label": str(conditional["label"]),
            "conditional": "true",
        }

    for object_id, candidate in candidates.items():
        marker = EXACT_TANGIBLE_EVENT_MARKERS.get(
            (map_id, scenario_id, object_id), {}
        )
        if marker:
            candidate["placement_class"] = str(marker["placement_class"])
            candidate["label"] = str(marker["label"])

    attached_service_hosts = EXACT_ATTACHED_SERVICE_HOST_IDS.get(
        (map_id, scenario_id), {}
    )
    missing_attached_services = sorted(set(attached_service_hosts) - set(candidates))
    if missing_attached_services:
        raise ValueError(
            f"{map_id}/{scenario_id}: attached service authority names catalog "
            f"services absent from this scenario: {missing_attached_services}"
        )

    for object_id in list(candidates):
        candidate = candidates[object_id]
        if object_id in attached_service_hosts:
            if not object_id.startswith("service:"):
                raise ValueError(
                    f"{map_id}/{scenario_id}: attached service authority contains "
                    f"non-service object {object_id}"
                )
            candidates.pop(object_id)
            continue
        if object_id in ACTION_ONLY_BASE_OBJECT_IDS:
            if object_id not in EXACT_ACTION_HOST_IDS.get((map_id, scenario_id), {}):
                raise ValueError(
                    f"{map_id}/{scenario_id}: action-only event {object_id} lacks "
                    "layout-specific host authority"
                )
            candidates.pop(object_id)
            continue
        object_type = candidate["object_type"]
        semantic = copy.deepcopy(base_semantics().get(object_id, {}))
        override = str(class_overrides.get(object_id, "")).strip()
        placement_class = str(candidate.get("placement_class", ""))
        if placement_class not in StaticCheck.CLASSES:
            visual_prop = str(
                semantic.get("environment_prop", semantic.get("visual_prop", ""))
            ).strip()
            # EnvironmentInstance adds context-sensitive event placement hints
            # before the live binder classifies base records. Mirror those two
            # physical rules here so generated exact slots cannot disagree with
            # production about a bar patron's seat or a clerk's counter.
            if override in StaticCheck.CLASSES:
                placement_class = override
            elif object_type == "item":
                placement_class = "shop_item"
            elif (
                object_type == "event"
                and map_id.partition(":")[0] == "bar"
                and values(surface.get("seats"))
                and visual_prop
                in {"bar_patron", "patron", "patron_talk", "rowdy_patron"}
            ):
                placement_class = "seated_person"
            elif object_type == "event" and visual_prop in {
                "clerk_counter",
                "host_station",
            }:
                placement_class = "behind_counter_person"
            else:
                placement_class = SlotAuthoring.classify_with_override(
                    semantic, object_type, object_id, override
                )
        if placement_class not in StaticCheck.CLASSES:
            candidates.pop(object_id)
            continue
        candidate["placement_class"] = placement_class
        if not str(candidate.get("label", "")).strip():
            candidate["label"] = str(
                semantic.get("display_name", semantic.get("label", friendly(candidate["source_id"])))
            )
        preferred_slot = mapping(slots.get(candidate["preferred_slot_id"]))
        if str(preferred_slot.get("footprint_class", "")) != placement_class:
            candidate["preferred_slot_id"] = ""

    # Any source-added object without a legacy exact hint receives deterministic
    # geometry from the first unused compatible source bank.
    available = source_slots_by_class(surface)
    used_preferred: dict[str, set[str]] = defaultdict(set)
    for candidate in candidates.values():
        placement_class = candidate["placement_class"]
        preferred = candidate["preferred_slot_id"]
        if preferred:
            used_preferred[placement_class].add(preferred)
    for object_id in sorted(candidates):
        candidate = candidates[object_id]
        placement_class = candidate["placement_class"]
        if not candidate["preferred_slot_id"]:
            source = next(
                (
                    slot
                    for slot in available.get(placement_class, [])
                    if str(slot.get("id", "")) not in used_preferred[placement_class]
                ),
                {},
            )
            candidate["preferred_slot_id"] = str(source.get("id", ""))
            if candidate["preferred_slot_id"]:
                used_preferred[placement_class].add(candidate["preferred_slot_id"])

    result: list[dict[str, Any]] = []
    for object_id, candidate in sorted(candidates.items()):
        source_id = candidate["source_id"]
        result.append(
            {
                "node_key": f"base::{object_id}",
                "object_id": str(object_id),
                "identity": str(object_id),
                "stable_id": source_id,
                "placement_class": candidate["placement_class"],
                "label": candidate["label"],
                "preferred_slot_id": candidate["preferred_slot_id"],
                "base_record": True,
                "conditional": candidate.get("conditional") == "true",
            }
        )
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


def source_slots_by_class(surface: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for slot in values(surface.get("scenario_slots")):
        if not isinstance(slot, dict) or bool(slot.get("runtime_reserve", False)):
            continue
        result[str(slot.get("footprint_class", ""))].append(slot)
    for slots in result.values():
        slots.sort(key=lambda slot: (int(slot.get("priority", 0)), str(slot.get("id", ""))))
    return result


def geometry_templates_by_class(
    surface: dict[str, Any],
) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for family in ("scenario", "event", "fixed", "exit"):
        for slot in values(surface.get(f"{family}_slots")):
            if not isinstance(slot, dict):
                continue
            placement_class = str(slot.get("footprint_class", ""))
            if placement_class not in StaticCheck.CLASSES:
                continue
            template = copy.deepcopy(slot)
            template["_source_slot_id"] = str(slot.get("id", ""))
            template["_source_family"] = family
            result[placement_class].append(template)
    for slots in result.values():
        slots.sort(
            key=lambda slot: (
                ("scenario", "event", "fixed", "exit").index(
                    str(slot.get("_source_family", "exit"))
                ),
                int(slot.get("priority", 0)),
                str(slot.get("id", "")),
            )
        )
    aliases = {
        "behind_counter_person": ("standing_person", "seated_person"),
        "standing_person": ("behind_counter_person", "seated_person"),
        "seated_person": ("standing_person", "behind_counter_person"),
        "group": ("standing_person", "floor_fixture"),
        "shop_item": ("surface_item", "wall_mounted"),
        "surface_item": ("shop_item", "wall_mounted", "floor_fixture"),
        "wall_mounted": ("surface_item", "hanging"),
        "hanging": ("wall_mounted", "surface_item"),
        "ground_marker": ("floor_fixture", "surface_item"),
        "floor_fixture": ("ground_marker", "surface_item"),
        "doorway": ("standing_person", "floor_fixture"),
    }
    for placement_class in StaticCheck.CLASSES:
        if result.get(placement_class):
            continue
        for alias in aliases.get(placement_class, ()):
            if result.get(alias):
                template = copy.deepcopy(result[alias][0])
                template["footprint_class"] = placement_class
                template["_synthetic_geometry"] = True
                result[placement_class].append(template)
                break
    return result


def _color_graph(
    node_keys: list[str],
    conflicts: dict[str, set[str]],
    color_count: int,
) -> dict[str, int] | None:
    """Return a deterministic coloring using at most ``color_count`` banks."""

    colors: dict[str, int] = {}

    def solve() -> bool:
        if len(colors) == len(node_keys):
            return True
        remaining = [node for node in node_keys if node not in colors]
        node_key = min(
            remaining,
            key=lambda key: (
                -len(
                    {
                        colors[neighbor]
                        for neighbor in conflicts.get(key, set())
                        if neighbor in colors
                    }
                ),
                -len(conflicts.get(key, set())),
                key,
            ),
        )
        unavailable = {
            colors[neighbor]
            for neighbor in conflicts.get(node_key, set())
            if neighbor in colors
        }
        used_colors = sorted(set(colors.values()))
        candidates = [color for color in used_colors if color not in unavailable]
        next_color = len(used_colors)
        if next_color < color_count and next_color not in unavailable:
            candidates.append(next_color)
        for color in candidates:
            colors[node_key] = color
            if solve():
                return True
            colors.pop(node_key, None)
        return False

    return colors if solve() else None


def add_zone_mismatch_conflicts(
    nodes: dict[str, dict[str, Any]], conflicts: dict[str, set[str]]
) -> None:
    """Prevent one manual marker from representing two authored room zones.

    Snapshot conflicts still determine whether same-zone alternatives may
    reuse geometry.  This additional edge only separates objects that declare
    different non-empty zones and use the same placement class.
    """

    node_keys = sorted(nodes)
    for index, left_key in enumerate(node_keys):
        left = nodes[left_key]
        left_zone = str(left.get("zone_id", "")).strip()
        if not left_zone:
            continue
        left_class = str(left.get("placement_class", ""))
        for right_key in node_keys[index + 1 :]:
            right = nodes[right_key]
            right_zone = str(right.get("zone_id", "")).strip()
            if (
                not right_zone
                or right_zone == left_zone
                or str(right.get("placement_class", "")) != left_class
            ):
                continue
            conflicts[left_key].add(right_key)
            conflicts[right_key].add(left_key)


def _best_geometry_by_color(
    color_nodes: dict[int, list[str]],
    nodes: dict[str, dict[str, Any]],
    available: list[dict[str, Any]],
) -> dict[int, dict[str, Any]]:
    """Match compact banks to old geometry while maximizing retained hints."""

    colors = sorted(color_nodes)
    source_ids = [str(slot.get("id", "")) for slot in available]
    weights: list[list[int]] = []
    for color in colors:
        preferred = Counter(str(nodes[key].get("preferred_slot_id", "")) for key in color_nodes[color])
        weights.append([preferred.get(source_id, 0) for source_id in source_ids])

    @cache
    def solve(color_index: int, used_mask: int) -> tuple[int, tuple[int, ...]]:
        if color_index == len(colors):
            return 0, ()
        best_score = -1
        best_choice: tuple[int, ...] = ()
        for source_index in range(len(available)):
            if used_mask & (1 << source_index):
                continue
            tail_score, tail_choice = solve(
                color_index + 1, used_mask | (1 << source_index)
            )
            score = weights[color_index][source_index] * 1000 + tail_score
            choice = (source_index, *tail_choice)
            if score > best_score or (score == best_score and choice < best_choice):
                best_score = score
                best_choice = choice
        return best_score, best_choice

    _, chosen = solve(0, 0)
    if len(chosen) != len(colors):
        raise ValueError("could not assign distinct source geometry to compact banks")
    return {color: available[chosen[index]] for index, color in enumerate(colors)}


def assign_geometry(
    nodes: dict[str, dict[str, Any]],
    conflicts: dict[str, set[str]],
    source_slots: dict[str, list[dict[str, Any]]],
    fallback_templates: dict[str, list[dict[str, Any]]],
    scope: str,
) -> tuple[dict[str, int], dict[tuple[str, int], dict[str, Any]]]:
    """Color semantic objects into compact, scenario-local role banks.

    Mutually exclusive phase/outcome objects deliberately reuse one physical
    marker. Only objects proven able to coexist consume separate ordinals.
    """

    assigned_colors: dict[str, int] = {}
    bank_geometry: dict[tuple[str, int], dict[str, Any]] = {}
    by_class: dict[str, list[str]] = defaultdict(list)
    for node_key, node in nodes.items():
        by_class[str(node.get("placement_class", ""))].append(node_key)

    for placement_class, class_nodes in sorted(by_class.items()):
        available = copy.deepcopy(source_slots.get(placement_class, []))
        templates = fallback_templates.get(placement_class, [])
        if not available and not templates:
            raise ValueError(
                f"{scope}: no geometry template exists for scenario class {placement_class}"
            )
        class_nodes.sort()
        colors: dict[str, int] | None = None
        for color_count in range(1, len(class_nodes) + 1):
            colors = _color_graph(class_nodes, conflicts, color_count)
            if colors is not None:
                break
        if colors is None:
            raise ValueError(
                f"{scope}: scenario {placement_class} conflict graph cannot be colored"
            )
        required_geometry = max(colors.values(), default=-1) + 1
        while len(available) < required_geometry:
            template = copy.deepcopy(
                templates[len(available) % len(templates)]
                if templates
                else available[0]
            )
            template["_synthetic_geometry"] = True
            template["id"] = (
                f"__provisional__.{clean_slug(placement_class)}_{len(available) + 1}"
            )
            available.append(template)
        grouped: dict[int, list[str]] = defaultdict(list)
        for node_key, color in colors.items():
            grouped[color].append(node_key)
            assigned_colors[node_key] = color
        chosen_geometry = _best_geometry_by_color(grouped, nodes, available)
        for color, source in chosen_geometry.items():
            bank_geometry[(placement_class, color)] = source
    return assigned_colors, bank_geometry


def clone_slot(
    source: dict[str, Any],
    slot_id: str,
    placement_class: str,
    ordinal: int,
    bank_nodes: list[dict[str, Any]],
    scenario_id: str,
    priority: int,
) -> dict[str, Any]:
    slot = copy.deepcopy(source)
    position_keys = sorted(
        {
            str(node.get("position_key", "")).strip()
            for node in bank_nodes
            if str(node.get("position_key", "")).strip()
        }
    )
    object_ids = sorted(
        {
            str(node.get("identity", node.get("object_id", ""))).strip()
            for node in bank_nodes
            if str(node.get("identity", node.get("object_id", ""))).strip()
        }
    )
    # Source packages occasionally differ only in label capitalization between
    # an arrival and aftermath projection (for example ``Relay Driver`` versus
    # ``Relay driver``).  They are one owner-facing role, not two alternatives.
    # Keep the deterministic first spelling while deduplicating case-insensitively.
    labels_by_folded: dict[str, str] = {}
    labels = [
        str(label).strip()
        for node in bank_nodes
        for label in (
            values(node.get("label_variants"))
            or [str(node.get("label", "")).strip()]
        )
        if str(label).strip()
    ]
    for label in sorted(labels):
        labels_by_folded.setdefault(label.casefold(), label)
    occupant_labels = sorted(labels_by_folded.values())
    zone_ids = sorted(
        {
            str(node.get("zone_id", "")).strip()
            for node in bank_nodes
            if str(node.get("zone_id", "")).strip()
        }
    )
    if not occupant_labels:
        occupant_labels = [f"{friendly(placement_class)} {ordinal}"]
    physical_role = occupant_labels[0]
    if len(occupant_labels) > 1:
        physical_role = "Scenario alternatives: " + " / ".join(occupant_labels)
    scenario_obstruction = any(
        str(mapping(node.get("semantic")).get("role", "")).strip().lower()
        in {"obstacle", "barrier", "blockade"}
        for node in bank_nodes
    )
    slot.update(
        {
            "id": slot_id,
            "kind": "scenario",
            "priority": priority,
            "occupancy_required": False,
            "physical_role": physical_role,
            "occupant_ids": object_ids,
            "scenario_occupant_labels": occupant_labels,
            "scenario_zone_ids": zone_ids,
            "runtime_reserve": False,
            "reserve_reason": "",
            "scenario_id": scenario_id,
            "scenario_instance": True,
            "scenario_role": placement_class,
            "scenario_ordinal": ordinal,
            "scenario_position_keys": position_keys,
            "scenario_object_ids": object_ids,
            "source_slot_id": str(
                source.get("_source_slot_id", source.get("id", ""))
            ),
            "source_slot_family": str(source.get("_source_family", "scenario")),
            "provisional_geometry": bool(source.get("_synthetic_geometry", False)),
            "_scenario_obstruction": scenario_obstruction,
        }
    )
    return slot


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


def _shared_occupied_rects(surface: dict[str, Any]) -> list[list[float]]:
    occupied: list[list[float]] = []
    for family in ("fixed", "event", "exit"):
        for slot in values(surface.get(f"{family}_slots")):
            hit = values(mapping(slot).get("hit_rect"))
            if len(hit) >= 4:
                occupied.append([float(hit[index]) for index in range(4)])
    for slot in values(surface.get("scenario_slots")):
        if not isinstance(slot, dict) or not bool(slot.get("runtime_reserve", False)):
            continue
        hit = values(slot.get("hit_rect"))
        if len(hit) >= 4:
            occupied.append([float(hit[index]) for index in range(4)])
    return occupied


def _set_slot_hit_rect(slot: dict[str, Any], rect: list[float]) -> None:
    slot["hit_rect"] = rect
    slot["pos"] = [rect[0] + rect[2] / 2.0, rect[1] + rect[3]]
    slot["label_anchor"] = [rect[0] + rect[2] / 2.0, max(0.0, rect[1] - 6.0)]


def apply_exact_geometry_overrides(
    authored_slots: list[dict[str, Any]],
    map_id: str,
    scenario_id: str,
) -> None:
    matched: set[tuple[str, str, str]] = set()
    for slot in authored_slots:
        override_rects = {
            tuple(float(value) for value in rect)
            for position_key in values(slot.get("scenario_position_keys"))
            if (
                rect := EXACT_POSITION_RECT_OVERRIDES.get(
                    (map_id, scenario_id, str(position_key))
                )
            )
        }
        if len(override_rects) > 1:
            raise ValueError(
                f"{map_id}/{scenario_id}: one compact slot has conflicting exact geometry overrides"
            )
        if not override_rects:
            continue
        rect = list(next(iter(override_rects)))
        _set_slot_hit_rect(slot, rect)
        slot["provisional_geometry"] = True
        slot["zone_id"] = "provisional"
        slot["support_id"] = "manual_placement_required"
        slot["_exact_geometry_locked"] = True
        for position_key in values(slot.get("scenario_position_keys")):
            authority_key = (map_id, scenario_id, str(position_key))
            if authority_key in EXACT_POSITION_RECT_OVERRIDES:
                matched.add(authority_key)
    expected = {
        key for key in EXACT_POSITION_RECT_OVERRIDES if key[:2] == (map_id, scenario_id)
    }
    if matched != expected:
        raise ValueError(
            f"{map_id}/{scenario_id}: exact geometry overrides did not resolve: "
            f"{sorted(expected - matched)}"
        )


def resolve_starting_geometry(
    authored_slots: list[dict[str, Any]],
    surface: dict[str, Any],
) -> None:
    """Give every manual local marker a clear, collision-free starting point.

    Placement mode draws the complete scenario-local bank, including mutually
    exclusive phase alternatives.  Keeping every local hit target separate
    from every other local and every shared-capacity target makes that editing
    pass unambiguous while preserving the compact semantic slot reuse.
    """

    shared = _shared_occupied_rects(surface)
    placed: list[list[float]] = []

    def in_bounds(rect: list[float]) -> bool:
        return (
            rect[0] >= 0.0
            and rect[1] >= 0.0
            and rect[0] + rect[2] <= BOARD_WIDTH
            and rect[1] + rect[3] <= BOARD_HEIGHT
        )

    def safe(slot: dict[str, Any], rect: list[float]) -> bool:
        if not in_bounds(rect):
            return False
        occupied = shared + placed
        if any(_rect_intersects(rect, other) for other in occupied):
            return False
        if bool(slot.get("_scenario_obstruction", False)):
            expanded = _expanded_hit_rect(rect)
            if _rect_intersects(rect, MANDATORY_ACCESS_LANE) or _rect_intersects(
                expanded, MANDATORY_ACCESS_LANE
            ):
                return False
            if any(_rect_contains_center(expanded, other) for other in occupied):
                return False
        return True

    def candidate_rects(origin: list[float]) -> list[list[float]]:
        width, height = origin[2], origin[3]
        candidates = [
            [float(x), float(y), width, height]
            for y in range(0, int(BOARD_HEIGHT - height) + 1, 8)
            for x in range(0, int(BOARD_WIDTH - width) + 1, 8)
        ]
        candidates.sort(
            key=lambda rect: (
                (rect[0] - origin[0]) ** 2 + (rect[1] - origin[1]) ** 2,
                rect[1],
                rect[0],
            )
        )
        return candidates

    def slot_area(slot: dict[str, Any]) -> float:
        hit = values(slot.get("hit_rect"))
        return float(hit[2]) * float(hit[3]) if len(hit) >= 4 else 0.0

    ordered = sorted(
        authored_slots,
        key=lambda slot: (
            not bool(slot.get("_exact_geometry_locked", False)),
            -slot_area(slot),
            int(slot.get("priority", 0)),
            str(slot.get("id", "")),
        ),
    )
    for slot in ordered:
        hit = values(slot.get("hit_rect"))
        if len(hit) < 4:
            raise ValueError(
                f"{surface.get('id', '<map>')}: local slot {slot.get('id', '<slot>')} "
                "has no starting hit rectangle"
            )
        original = [float(hit[index]) for index in range(4)]
        locked = bool(slot.get("_exact_geometry_locked", False))
        candidate = original if safe(slot, original) else None
        if candidate is None and locked:
            raise ValueError(
                f"{surface.get('id', '<map>')}: exact geometry for "
                f"{slot.get('id', '<slot>')} intersects another placement target"
            )
        if candidate is None:
            candidate = next(
                (rect for rect in candidate_rects(original) if safe(slot, rect)),
                None,
            )
        if candidate is None:
            raise ValueError(
                f"{surface.get('id', '<map>')}: no collision-free starting position "
                f"for {slot.get('id', '<slot>')}"
            )
        if candidate != original:
            _set_slot_hit_rect(slot, candidate)
            slot["provisional_geometry"] = True
        if bool(slot.get("provisional_geometry", False)):
            slot["zone_id"] = "provisional"
            slot["support_id"] = "manual_placement_required"
        placed.append(candidate)
        slot.pop("_exact_geometry_locked", None)
        slot.pop("_scenario_obstruction", None)


def clear_obstruction_conflicts(
    authored_slots: list[dict[str, Any]],
    surface: dict[str, Any],
) -> None:
    """Keep tangible scenario obstructions out of the mandatory access lane.

    Source layouts predate exact scenario composition and some barrier donors sit
    directly on the travel strip.  Move only the conflicting exact slot to a
    deterministic provisional location; placement mode remains the final owner.
    """

    occupied = _shared_occupied_rects(surface)
    obstructions: list[dict[str, Any]] = []
    for slot in authored_slots:
        hit = values(slot.get("hit_rect"))
        if len(hit) < 4:
            continue
        rect = [float(hit[index]) for index in range(4)]
        if bool(slot.get("_scenario_obstruction", False)):
            obstructions.append(slot)
        else:
            occupied.append(rect)

    lane = [float(value) for value in MANDATORY_ACCESS_LANE]
    for slot in sorted(
        obstructions,
        key=lambda value: (int(value.get("priority", 0)), str(value.get("id", ""))),
    ):
        hit = values(slot.get("hit_rect"))
        rect = [float(hit[index]) for index in range(4)]
        blocks_lane = _rect_intersects(rect, lane) or _rect_intersects(
            _expanded_hit_rect(rect), lane
        )
        overlaps_other_authority = any(
            _rect_intersects(rect, other) for other in occupied
        )
        obscures_other_authority = any(
            _rect_contains_center(_expanded_hit_rect(rect), other)
            for other in occupied
        )
        if not blocks_lane and not overlaps_other_authority and not obscures_other_authority:
            occupied.append(rect)
            slot.pop("_scenario_obstruction", None)
            continue

        width, height = rect[2], rect[3]
        largest_height = max(height, SMALL_SCREEN_TARGET[1])
        highest_safe_top = int(MANDATORY_ACCESS_LANE[1] - largest_height - 12.0)
        y_values = list(range(max(8, highest_safe_top), 7, -8))
        candidate: list[float] | None = None
        for y in y_values:
            for x in range(8, max(9, int(BOARD_WIDTH - width) - 7), 8):
                proposed = [float(x), float(y), width, height]
                proposed_small = _expanded_hit_rect(proposed)
                if _rect_intersects(proposed, lane) or _rect_intersects(
                    proposed_small, lane
                ):
                    continue
                if all(not _rect_intersects(proposed, other) for other in occupied):
                    if all(
                        not _rect_contains_center(proposed_small, other)
                        for other in occupied
                    ):
                        candidate = proposed
                        break
            if candidate is not None:
                break
        if candidate is None:
            raise ValueError(
                f"{surface.get('id', '<map>')}: no access-safe provisional position "
                f"for obstruction {slot.get('id', '<slot>')}"
            )
        _set_slot_hit_rect(slot, candidate)
        slot["provisional_geometry"] = True
        slot["zone_id"] = "provisional"
        slot["support_id"] = "manual_placement_required"
        occupied.append(candidate)
        slot.pop("_scenario_obstruction", None)

    for slot in authored_slots:
        slot.pop("_scenario_obstruction", None)


def build_layout(
    map_id: str,
    scenario_id: str,
    scenario_row: dict[str, Any],
    base_map: dict[str, Any],
    snapshots: list[list[dict[str, Any]]],
) -> dict[str, Any]:
    surface = effective_map(base_map, scenario_id)
    nodes: dict[str, dict[str, Any]] = {}
    conflicts: dict[str, set[str]] = defaultdict(set)
    action_only_ids: set[str] = set()
    route_nodes: dict[str, tuple[str, str]] = {}
    max_simultaneous = 0

    base_nodes = scenario_base_objects(map_id, scenario_id, surface, scenario_row)
    for node in base_nodes:
        nodes[str(node["node_key"])] = node
    # Catalog-added game/event/service/item records are active base-room objects
    # while the sequence projection is composed above them. Treat them as live
    # in every reachable snapshot so exact banks never double-book a base event
    # and a scenario visual.
    for index, left in enumerate(base_nodes):
        for right in base_nodes[index + 1 :]:
            left_key = str(left["node_key"])
            right_key = str(right["node_key"])
            conflicts[left_key].add(right_key)
            conflicts[right_key].add(left_key)

    for snapshot in snapshots:
        active: list[str] = []
        for semantic in snapshot:
            if not isinstance(semantic, dict):
                continue
            entry = visual_entry(surface, semantic)
            identity = str(semantic.get("identity", ""))
            if entry is None:
                if identity.startswith("scenario::") and not bool(
                    semantic.get("_slot_nonvisual", False)
                ):
                    action_only_ids.add(identity.removeprefix("scenario::"))
                continue
            route_id = str(entry.get("route_id", ""))
            if route_id:
                route_pair = route_nodes.get(route_id)
                if route_pair is None:
                    start_key = f"route::{route_id}::start"
                    end_key = f"route::{route_id}::end"
                    route_pair = (start_key, end_key)
                    route_nodes[route_id] = route_pair
                    routes = {
                        str(route.get("id", "")): route
                        for route in values(surface.get("actor_routes"))
                        if isinstance(route, dict)
                    }
                    source_route = mapping(routes.get(route_id))
                    for node_key, endpoint in zip(route_pair, ("start", "end")):
                        route_node = copy.deepcopy(entry)
                        route_node.update(
                            {
                                "node_key": node_key,
                                "position_key": node_key,
                                "label": f"{entry['label']} route {endpoint}",
                                "route_endpoint": endpoint,
                                "preferred_slot_id": str(
                                    source_route.get(f"{endpoint}_slot_id", "")
                                ),
                            }
                        )
                        nodes[node_key] = route_node
                active.extend(route_pair)
                continue
            node_key = str(entry["node_key"])
            prior = nodes.get(node_key)
            if prior is not None and str(prior.get("placement_class", "")) != str(
                entry.get("placement_class", "")
            ):
                node_key = f"{node_key}|@class={entry['placement_class']}"
                entry["node_key"] = node_key
            if node_key not in nodes:
                nodes[node_key] = entry
            else:
                retained = nodes[node_key]
                variants = {
                    str(label).strip().casefold(): str(label).strip()
                    for label in values(retained.get("label_variants"))
                    if str(label).strip()
                }
                for label in values(entry.get("label_variants")):
                    if str(label).strip():
                        variants.setdefault(str(label).strip().casefold(), str(label).strip())
                retained["label_variants"] = sorted(variants.values())
            active.append(node_key)
        active = sorted(set(active))
        active_with_base = sorted(
            set(active + [str(node["node_key"]) for node in base_nodes])
        )
        max_simultaneous = max(max_simultaneous, len(active_with_base))
        for index, left in enumerate(active_with_base):
            for right in active_with_base[index + 1 :]:
                conflicts[left].add(right)
                conflicts[right].add(left)

    if not snapshots:
        raise ValueError(f"{map_id}/{scenario_id} has no reachable scenario snapshots")
    # Mutually exclusive objects may share a marker only when they also share
    # the authored room zone.  The owner can therefore place each local marker
    # once without moving it between semantic areas as phases change.
    add_zone_mismatch_conflicts(nodes, conflicts)
    assigned_colors, bank_geometry = assign_geometry(
        nodes,
        conflicts,
        source_slots_by_class(surface),
        geometry_templates_by_class(surface),
        f"{map_id}/{scenario_id}",
    )
    authored_slots: list[dict[str, Any]] = []
    exact_preferences: dict[str, str] = {}
    exact_object_preferences: dict[str, str] = {}
    exact_object_classes: dict[str, str] = {}
    exact_art_keys: dict[str, str] = {}
    route_slot_ids: dict[str, dict[str, str]] = defaultdict(dict)
    stable_nodes: dict[str, list[str]] = defaultdict(list)

    bank_nodes: dict[tuple[str, int], list[dict[str, Any]]] = defaultdict(list)
    for node_key, color in assigned_colors.items():
        placement_class = str(nodes[node_key].get("placement_class", ""))
        bank_nodes[(placement_class, color)].append(nodes[node_key])
    bank_slot_ids: dict[tuple[str, int], str] = {}
    class_ordinals: dict[str, int] = defaultdict(int)
    for priority, bank_key in enumerate(sorted(bank_nodes), start=1):
        placement_class, color = bank_key
        slot_token = f"local_{ROLE_SLOT_TOKEN.get(placement_class, placement_class)}"
        class_ordinals[placement_class] += 1
        ordinal = class_ordinals[placement_class]
        # Exact layout slots use their own namespace so role ordinals remain
        # compact while shared runtime reserves can coexist without collisions.
        slot_id = f"scenario.{clean_slug(slot_token)}_{ordinal}"
        bank_slot_ids[bank_key] = slot_id
        authored_slots.append(
            clone_slot(
                bank_geometry[bank_key],
                slot_id,
                placement_class,
                ordinal,
                bank_nodes[bank_key],
                scenario_id,
                priority,
            )
        )
    apply_exact_geometry_overrides(authored_slots, map_id, scenario_id)
    resolve_starting_geometry(authored_slots, surface)

    for node_key in sorted(nodes):
        node = nodes[node_key]
        placement_class = str(node.get("placement_class", ""))
        slot_id = bank_slot_ids[(placement_class, assigned_colors[node_key])]
        if not bool(node.get("base_record", False)) and not bool(node.get("actor", False)):
            art_position_key = str(node.get("position_key", "")).strip()
            art_key = str(node.get("art_key", "")).strip()
            if not art_position_key or art_key not in StaticCheck.CONCRETE_SCENARIO_ART_KEYS:
                raise ValueError(
                    f"{map_id}/{scenario_id}: {node_key} lacks exact concrete art authority"
                )
            prior_art_key = exact_art_keys.get(art_position_key, art_key)
            if prior_art_key != art_key:
                raise ValueError(
                    f"{map_id}/{scenario_id}: {art_position_key} has conflicting exact art "
                    f"{prior_art_key}/{art_key}"
                )
            exact_art_keys[art_position_key] = art_key
        route_endpoint = str(node.get("route_endpoint", ""))
        if bool(node.get("base_record", False)):
            object_id = str(node.get("object_id", ""))
            exact_object_preferences[object_id] = slot_id
            exact_object_classes[object_id] = placement_class
        elif route_endpoint:
            route_slot_ids[str(node.get("route_id", ""))][route_endpoint] = slot_id
        else:
            position_key = str(node.get("position_key", ""))
            if position_key:
                exact_preferences[position_key] = slot_id
            stable_nodes[str(node.get("stable_id", ""))].append(slot_id)

    for stable_id, slot_ids in stable_nodes.items():
        unique_slot_ids = sorted(set(slot_ids))
        if stable_id and len(unique_slot_ids) == 1:
            exact_preferences[stable_id] = unique_slot_ids[0]
            exact_preferences[f"scenario::{stable_id}"] = unique_slot_ids[0]

    source_routes = {
        str(route.get("id", "")): route
        for route in values(surface.get("actor_routes"))
        if isinstance(route, dict)
    }
    authored_routes: list[dict[str, Any]] = []
    for route_id, endpoints in sorted(route_slot_ids.items()):
        source_route = copy.deepcopy(mapping(source_routes.get(route_id)))
        if not source_route:
            raise ValueError(f"{map_id}/{scenario_id} references missing route {route_id}")
        source_start_id = str(source_route.get("start_slot_id", ""))
        source_end_id = str(source_route.get("end_slot_id", ""))
        source_reduced_id = str(source_route.get("reduced_motion_slot_id", ""))
        source_route["start_slot_id"] = endpoints.get("start", "")
        source_route["end_slot_id"] = endpoints.get("end", "")
        if not source_route["start_slot_id"] or not source_route["end_slot_id"]:
            raise ValueError(f"{map_id}/{scenario_id} route {route_id} lacks endpoints")
        if source_reduced_id:
            if source_reduced_id not in {source_start_id, source_end_id}:
                raise ValueError(
                    f"{map_id}/{scenario_id} route {route_id} has unknown reduced-motion endpoint"
                )
            source_route["reduced_motion_slot_id"] = (
                source_route["start_slot_id"]
                if source_reduced_id == source_start_id
                else source_route["end_slot_id"]
            )
        authored_routes.append(source_route)

    by_class = Counter(str(slot.get("footprint_class", "")) for slot in authored_slots)
    event_action_host_ids = EXACT_ACTION_HOST_IDS.get((map_id, scenario_id), {})
    service_action_host_ids = EXACT_ATTACHED_SERVICE_HOST_IDS.get(
        (map_id, scenario_id), {}
    )
    duplicate_action_ids = sorted(
        set(event_action_host_ids) & set(service_action_host_ids)
    )
    if duplicate_action_ids:
        raise ValueError(
            f"{map_id}/{scenario_id}: action-host authority is duplicated across "
            f"event and service tables: {duplicate_action_ids}"
        )
    action_host_ids = dict(
        sorted({**event_action_host_ids, **service_action_host_ids}.items())
    )
    physical_host_ids: set[str] = set()
    for slot in values(surface.get("fixed_slots")) + authored_slots:
        if not isinstance(slot, dict):
            continue
        physical_host_ids.update(
            str(identity).strip()
            for field in ("occupant_ids", "scenario_object_ids")
            for identity in values(slot.get(field))
            if str(identity).strip()
        )
    missing_hosts = sorted(set(action_host_ids.values()) - physical_host_ids)
    if missing_hosts:
        raise ValueError(
            f"{map_id}/{scenario_id}: exact action hosts lack physical placement "
            f"authority: {missing_hosts}"
        )
    return {
        "layout_id": f"{map_id}::{scenario_id}",
        "map_id": map_id,
        "scenario_id": scenario_id,
        "display_name": str(scenario_row.get("display_name", scenario_id)),
        "scenario_slots": authored_slots,
        "scenario_instance_slot_ids": dict(sorted(exact_preferences.items())),
        "scenario_instance_object_slot_ids": dict(
            sorted(exact_object_preferences.items())
        ),
        "scenario_instance_object_class_ids": dict(
            sorted(exact_object_classes.items())
        ),
        "scenario_instance_art_keys": dict(sorted(exact_art_keys.items())),
        "scenario_instance_action_host_ids": action_host_ids,
        "scenario_instance_object_family_ids": {
            object_id: "scenario" for object_id in sorted(exact_object_preferences)
        },
        "actor_routes": authored_routes,
        "audit": {
            "snapshot_count": len(snapshots),
            "slot_count": len(authored_slots),
            "semantic_position_count": len(nodes),
            "reused_semantic_position_count": len(nodes) - len(authored_slots),
            "slots_by_class": dict(sorted(by_class.items())),
            "max_simultaneous_slot_count": max_simultaneous,
            "concrete_art_key_count": len(exact_art_keys),
            "action_host_count": len(action_host_ids),
            "action_only_ids": sorted(action_only_ids),
            "source_generic_slot_ids": sorted(
                {str(slot.get("source_slot_id", "")) for slot in authored_slots}
            ),
        },
    }


def build_payload() -> dict[str, Any]:
    placement = json.loads(PLACEMENT_PATH.read_text(encoding="utf-8"))
    maps = {str(item.get("id", "")): item for item in values(placement.get("maps"))}
    snapshots = snapshots_by_scenario()
    layouts: list[dict[str, Any]] = []
    for map_id, scenario_id, row in scenario_rows():
        if map_id not in maps:
            raise ValueError(f"catalog scenario {scenario_id} references missing map {map_id}")
        layouts.append(
            build_layout(
                map_id,
                scenario_id,
                row,
                maps[map_id],
                snapshots.get((map_id, scenario_id), []),
            )
        )
    if len(layouts) != 55:
        raise ValueError(f"expected 55 scenario layouts, authored {len(layouts)}")
    unknown_templates = TEMPLATE_ONLY_MAP_IDS - set(maps)
    if unknown_templates:
        raise ValueError(
            f"template-only placement maps are missing: {sorted(unknown_templates)}"
        )
    # The layered Punchline parent is source geometry used by its three real
    # floors. Runtime always resolves it to club/casino/back_room, so counting
    # the raw parent as a manual base context would make coverage impossible.
    base_layout_ids = sorted(set(maps) - TEMPLATE_ONLY_MAP_IDS)
    template_map_ids = sorted(TEMPLATE_ONLY_MAP_IDS)
    maps_with_scenarios = sorted({str(layout["map_id"]) for layout in layouts})
    return {
        "schema_version": SCHEMA_VERSION,
        "slot_schema_version": int(placement.get("slot_schema_version", 0)),
        "base_layout_ids": base_layout_ids,
        "template_map_ids": template_map_ids,
        "maps_with_catalog_scenarios": maps_with_scenarios,
        "layout_count": len(layouts),
        "scenario_slot_count": sum(
            len(values(layout.get("scenario_slots"))) for layout in layouts
        ),
        "layouts": layouts,
    }


def encoded(payload: dict[str, Any]) -> bytes:
    return (json.dumps(payload, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    payload = build_payload()
    output = encoded(payload)
    if args.check:
        if not OUTPUT_PATH.exists() or OUTPUT_PATH.read_bytes() != output:
            raise SystemExit(
                "scenario slot layout authority is missing or stale; run "
                "tools/author_scenario_slot_layouts.py"
            )
        print(
            "SCENARIO_SLOT_LAYOUT_CHECK PASS "
            f"layouts={payload['layout_count']} slots={payload['scenario_slot_count']}"
        )
        return 0
    OUTPUT_PATH.write_bytes(output)
    print(
        "Authored scenario slot layouts: "
        f"layouts={payload['layout_count']} slots={payload['scenario_slot_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
