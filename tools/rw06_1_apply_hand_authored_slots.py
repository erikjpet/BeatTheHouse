#!/usr/bin/env python3
"""Serialize Q-007 hand-authored fixed slots into placement_surfaces.json.

Every contact coordinate and label anchor below was chosen against the raw
900x430 room art.  This tool performs no placement search, packing, candidate
generation, or coordinate adjustment; it only expands the literal records into
the existing closed slot schema.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SLOT_SIZE = {
    "standing_person": (72.0, 80.0),
    "behind_counter_person": (72.0, 72.0),
    "seated_person": (68.0, 64.0),
    "group": (104.0, 78.0),
    "floor_fixture": (92.0, 64.0),
    "ground_marker": (72.0, 48.0),
    "surface_item": (72.0, 48.0),
    "wall_mounted": (80.0, 48.0),
    "hanging": (72.0, 44.0),
    "doorway": (64.0, 72.0),
}
PERSON_CLASSES = {"standing_person", "behind_counter_person", "seated_person", "group"}


# (id, footprint class, contact position, label anchor, named support)
HAND_SLOTS: dict[str, dict[str, list[tuple[str, str, tuple[float, float], tuple[float, float], str]]]] = {
    "bar": {
        "base": [
            ("base.game_1", "surface_item", (74.0, 178.0), (74.0, 124.0), "bar_counter"),
            ("base.game_2", "surface_item", (194.0, 178.0), (194.0, 146.0), "bar_counter"),
            ("base.game_3", "surface_item", (314.0, 178.0), (314.0, 124.0), "bar_counter"),
            ("base.staff_bartender", "behind_counter_person", (430.0, 178.0), (430.0, 100.0), "bar_counter"),
            ("base.fixed_ticket_redeemer", "surface_item", (300.0, 92.0), (300.0, 38.0), "bottle_rail"),
            ("base.fixed_drink", "surface_item", (100.0, 92.0), (100.0, 38.0), "bottle_rail"),
            ("base.event_floor_1", "floor_fixture", (160.0, 278.0), (160.0, 208.0), "stage"),
            ("base.event_floor_2", "floor_fixture", (276.0, 278.0), (276.0, 208.0), "stage"),
            ("base.patron_floor_1", "standing_person", (508.0, 366.0), (508.0, 410.0), "floor"),
            ("base.travel_left", "doorway", (38.0, 370.0), (38.0, 328.0), "left_exit"),
            ("base.travel_right", "doorway", (862.0, 370.0), (862.0, 328.0), "right_exit"),
        ],
        "stage": [
            ("stage.staff_bar_1", "behind_counter_person", (550.0, 178.0), (550.0, 204.0), "bar_counter"),
            ("stage.event_pool_table_1", "surface_item", (666.0, 188.0), (666.0, 134.0), "pool_table"),
            ("stage.event_pool_table_2", "surface_item", (786.0, 188.0), (786.0, 112.0), "pool_table"),
            ("stage.event_floor_fixture_1", "floor_fixture", (392.0, 278.0), (392.0, 240.0), "stage"),
            ("stage.event_floor_fixture_2", "floor_fixture", (508.0, 278.0), (508.0, 270.0), "stage"),
            ("stage.event_floor_fixture_3", "floor_fixture", (624.0, 278.0), (624.0, 240.0), "stage"),
            ("stage.event_floor_marker_1", "ground_marker", (160.0, 366.0), (174.0, 380.0), "floor"),
            ("stage.event_floor_marker_2", "ground_marker", (276.0, 366.0), (276.0, 410.0), "floor"),
            ("stage.event_floor_marker_3", "ground_marker", (392.0, 366.0), (392.0, 380.0), "floor"),
            ("stage.patron_floor_1", "standing_person", (624.0, 366.0), (590.0, 410.0), "floor"),
            ("stage.patron_floor_2", "standing_person", (740.0, 366.0), (724.0, 410.0), "floor"),
            ("stage.event_wall_1", "wall_mounted", (560.0, 24.0), (560.0, 60.0), "wall"),
            ("stage.event_wall_2", "wall_mounted", (680.0, 24.0), (680.0, 86.0), "wall"),
            ("stage.event_wall_3", "wall_mounted", (800.0, 24.0), (800.0, 60.0), "wall"),
        ],
        "exit": [
            ("exit.safe_left", "doorway", (38.0, 270.0), (38.0, 228.0), "left_exit"),
            ("exit.safe_right", "doorway", (862.0, 270.0), (862.0, 228.0), "right_exit"),
        ],
    },
    "corner_store": {
        "base": [
            ("base.shop_item_1", "surface_item", (100.0, 108.0), (100.0, 54.0), "shelf_row_1"),
            ("base.shop_item_2", "surface_item", (230.0, 108.0), (230.0, 54.0), "shelf_row_1"),
            ("base.shop_item_3", "surface_item", (100.0, 192.0), (100.0, 138.0), "shelf_row_4"),
            ("base.shop_item_4", "surface_item", (230.0, 192.0), (230.0, 138.0), "shelf_row_4"),
            ("base.shop_item_5", "surface_item", (692.0, 136.0), (692.0, 82.0), "cooler_upper"),
            ("base.staff_shopkeeper", "behind_counter_person", (374.0, 206.0), (374.0, 128.0), "register"),
            ("base.staff_dialogue", "behind_counter_person", (480.0, 206.0), (480.0, 244.0), "register"),
            ("base.staff_dialogue_2", "behind_counter_person", (586.0, 206.0), (586.0, 128.0), "register"),
            ("base.fixed_phone", "surface_item", (220.0, 270.0), (220.0, 286.0), "left_checkout_counter"),
            ("base.fixed_drink", "surface_item", (796.0, 136.0), (796.0, 82.0), "cooler_upper"),
            ("base.game_1", "floor_fixture", (270.0, 358.0), (270.0, 398.0), "floor"),
            ("base.event_group_1", "group", (384.0, 358.0), (384.0, 398.0), "floor"),
            ("base.lender_floor_1", "standing_person", (498.0, 358.0), (498.0, 398.0), "floor"),
            ("base.travel_left", "doorway", (41.0, 370.0), (41.0, 430.0), "left_exit"),
            ("base.travel_right", "doorway", (859.0, 370.0), (859.0, 328.0), "right_exit"),
        ],
        "stage": [
            ("stage.event_delivery_floor_1", "floor_fixture", (156.0, 358.0), (180.0, 398.0), "floor"),
            ("stage.staff_floor_1", "standing_person", (612.0, 358.0), (612.0, 398.0), "floor"),
            ("stage.patron_floor_1", "standing_person", (726.0, 358.0), (730.0, 370.0), "floor"),
            ("stage.event_cooler_1", "surface_item", (692.0, 220.0), (670.0, 246.0), "cooler_top"),
            ("stage.event_cooler_2", "surface_item", (796.0, 220.0), (730.0, 272.0), "cooler_top"),
            ("stage.event_wall_1", "wall_mounted", (450.0, 50.0), (450.0, 112.0), "wall"),
        ],
        "exit": [
            ("exit.safe_left", "doorway", (41.0, 286.0), (41.0, 244.0), "left_exit"),
            ("exit.safe_right", "doorway", (859.0, 286.0), (859.0, 244.0), "right_exit"),
        ],
    },
    "grand_casino": {
        "base": [
            ("base.game_machine_1", "wall_mounted", (180.0, 80.0), (180.0, 32.0), "wall"),
            ("base.game_machine_2", "wall_mounted", (315.0, 80.0), (315.0, 32.0), "wall"),
            ("base.game_machine_3", "wall_mounted", (450.0, 80.0), (450.0, 32.0), "wall"),
            ("base.game_machine_4", "wall_mounted", (585.0, 80.0), (585.0, 32.0), "wall"),
            ("base.game_machine_5", "wall_mounted", (720.0, 80.0), (720.0, 32.0), "wall"),
            ("base.game_table_left", "surface_item", (210.0, 184.0), (210.0, 130.0), "left_table_felt"),
            ("base.game_table_right", "surface_item", (690.0, 184.0), (690.0, 130.0), "right_table_felt"),
            ("base.staff_host", "behind_counter_person", (450.0, 248.0), (450.0, 170.0), "mid_game_rail"),
            ("base.fixed_drink", "surface_item", (824.0, 100.0), (824.0, 46.0), "base_drink_shelf"),
            ("base.fixed_ticket_redeemer", "wall_mounted", (60.0, 24.0), (60.0, 72.0), "wall"),
            ("base.event_wall_1", "wall_mounted", (330.0, 170.0), (330.0, 218.0), "wall"),
            ("base.fixture_host_desk", "floor_fixture", (384.0, 340.0), (384.0, 270.0), "floor"),
            ("base.event_floor_1", "floor_fixture", (156.0, 430.0), (156.0, 376.0), "floor"),
            ("base.travel_left", "doorway", (36.0, 390.0), (36.0, 348.0), "left_exit"),
            ("base.travel_right", "doorway", (864.0, 390.0), (864.0, 348.0), "right_exit"),
        ],
        "stage": [
            ("stage.event_table_left_1", "surface_item", (160.0, 276.0), (180.0, 326.0), "left_table_rail"),
            ("stage.event_table_left_2", "surface_item", (280.0, 276.0), (294.0, 244.0), "left_table_rail"),
            ("stage.event_table_right_1", "surface_item", (620.0, 276.0), (700.0, 326.0), "right_table_rail"),
            ("stage.event_table_right_2", "surface_item", (740.0, 276.0), (754.0, 244.0), "right_table_rail"),
            ("stage.event_floor_center", "floor_fixture", (488.0, 340.0), (560.0, 330.0), "floor"),
            ("stage.event_floor_left", "floor_fixture", (264.0, 430.0), (264.0, 376.0), "floor"),
            ("stage.group_floor_1", "group", (372.0, 430.0), (372.0, 400.0), "floor"),
            ("stage.patron_floor_1", "standing_person", (480.0, 430.0), (480.0, 400.0), "floor"),
            ("stage.patron_floor_2", "standing_person", (588.0, 430.0), (588.0, 400.0), "floor"),
            ("stage.event_ground_1", "ground_marker", (696.0, 430.0), (696.0, 400.0), "floor"),
            ("stage.event_wall_left", "wall_mounted", (60.0, 170.0), (60.0, 218.0), "wall"),
            ("stage.event_wall_center", "wall_mounted", (570.0, 170.0), (570.0, 146.0), "wall"),
            ("stage.event_wall_right", "wall_mounted", (840.0, 170.0), (840.0, 146.0), "wall"),
        ],
        "exit": [
            ("exit.safe_left", "doorway", (36.0, 278.0), (36.0, 236.0), "left_exit"),
            ("exit.safe_right", "doorway", (864.0, 278.0), (864.0, 236.0), "right_exit"),
        ],
    },
    "grand_casino_high_limit": {
        "base": [
            ("base.game_table_1", "surface_item", (130.0, 184.0), (130.0, 130.0), "left_table"),
            ("base.game_table_2", "surface_item", (250.0, 184.0), (250.0, 130.0), "left_table"),
            ("base.game_table_3", "surface_item", (650.0, 184.0), (650.0, 130.0), "right_table"),
            ("base.game_table_4", "surface_item", (770.0, 184.0), (770.0, 130.0), "right_table"),
            ("base.event_floor_1", "floor_fixture", (384.0, 358.0), (384.0, 288.0), "floor"),
            ("base.patron_floor_1", "standing_person", (498.0, 358.0), (498.0, 398.0), "floor"),
            ("base.travel_left", "doorway", (36.0, 370.0), (36.0, 328.0), "left_exit"),
            ("base.travel_right", "doorway", (864.0, 370.0), (864.0, 328.0), "right_exit"),
        ],
        "stage": [
            ("stage.event_wall_1", "wall_mounted", (450.0, 80.0), (450.0, 32.0), "wall"),
            ("stage.event_floor_1", "floor_fixture", (612.0, 358.0), (612.0, 288.0), "floor"),
            ("stage.patron_floor_1", "standing_person", (726.0, 358.0), (726.0, 398.0), "floor"),
        ],
        "exit": [
            ("exit.safe_left", "doorway", (36.0, 274.0), (36.0, 232.0), "left_exit"),
            ("exit.safe_right", "doorway", (864.0, 274.0), (864.0, 232.0), "right_exit"),
        ],
    },
    "grand_casino_back_room": {
        "base": [
            ("base.game_table_left", "surface_item", (210.0, 184.0), (210.0, 130.0), "left_table"),
            ("base.game_table_right", "surface_item", (690.0, 184.0), (690.0, 130.0), "right_table"),
            ("base.patron_floor_1", "standing_person", (450.0, 358.0), (450.0, 398.0), "floor"),
            ("base.travel_left", "doorway", (36.0, 370.0), (36.0, 328.0), "left_exit"),
        ],
        "stage": [
            ("stage.event_floor_1", "floor_fixture", (330.0, 358.0), (330.0, 288.0), "floor"),
            ("stage.patron_floor_1", "standing_person", (570.0, 358.0), (570.0, 398.0), "floor"),
        ],
        "exit": [
            ("exit.safe_left", "doorway", (36.0, 274.0), (36.0, 232.0), "left_exit"),
            ("exit.safe_right", "doorway", (864.0, 274.0), (864.0, 232.0), "right_exit"),
        ],
    },
    "grand_casino_cage": {
        "base": [
            ("base.shop_item_1", "surface_item", (96.0, 124.0), (96.0, 70.0), "gift_case"),
            ("base.shop_item_2", "surface_item", (200.0, 124.0), (200.0, 70.0), "gift_case"),
            ("base.shop_item_3", "surface_item", (320.0, 260.0), (320.0, 206.0), "teller_counter"),
            ("base.shop_item_4", "surface_item", (440.0, 260.0), (440.0, 206.0), "teller_counter"),
            ("base.fixture_cage_1", "floor_fixture", (330.0, 358.0), (330.0, 288.0), "floor"),
            ("base.fixture_cage_2", "floor_fixture", (450.0, 358.0), (450.0, 288.0), "floor"),
            ("base.travel_floor_door", "doorway", (847.0, 160.0), (847.0, 118.0), "floor_door"),
            ("base.casino_floor_door", "doorway", (847.0, 248.0), (847.0, 206.0), "floor_door"),
        ],
        "stage": [
            ("stage.event_atm_1", "surface_item", (720.0, 116.0), (720.0, 62.0), "atm"),
            ("stage.event_floor_1", "floor_fixture", (570.0, 358.0), (570.0, 288.0), "floor"),
            ("stage.patron_floor_1", "standing_person", (690.0, 358.0), (690.0, 398.0), "floor"),
        ],
        "exit": [
            ("exit.safe_left", "doorway", (36.0, 278.0), (36.0, 236.0), "left_exit"),
            ("exit.safe_left_lower", "doorway", (36.0, 370.0), (36.0, 328.0), "left_exit"),
        ],
    },
}


SCENARIO_SLOT_RENAMES = {
    "bar": {
        "stage.behind_counter_person.01": "stage.staff_bar_1",
        "stage.floor_fixture.01": "stage.event_floor_fixture_1",
        "stage.floor_fixture.02": "stage.event_floor_fixture_2",
        "stage.floor_fixture.03": "stage.event_floor_fixture_3",
        "stage.ground_marker.01": "stage.event_floor_marker_1",
        "stage.ground_marker.02": "stage.event_floor_marker_2",
        "stage.ground_marker.03": "stage.event_floor_marker_3",
        "stage.standing_person.01": "stage.patron_floor_1",
        "stage.standing_person.02": "stage.patron_floor_2",
        "stage.surface_item.01": "stage.event_pool_table_1",
        "stage.surface_item.02": "stage.event_pool_table_2",
        "stage.wall_mounted.01": "stage.event_wall_1",
        "stage.wall_mounted.02": "stage.event_wall_2",
        "stage.wall_mounted.03": "stage.event_wall_3",
        "exit.doorway.01": "exit.safe_right",
        "exit.doorway.02": "exit.safe_left",
    },
    "corner_store": {
        "stage.behind_counter_person.01": "stage.staff_floor_1",
        "stage.floor_fixture.01": "stage.event_delivery_floor_1",
        "stage.standing_person.01": "stage.patron_floor_1",
        "stage.surface_item.01": "stage.event_cooler_1",
        "stage.surface_item.02": "stage.event_cooler_2",
        "stage.wall_mounted.01": "stage.event_wall_1",
        "exit.doorway.01": "exit.safe_left",
        "exit.doorway.02": "exit.safe_right",
    },
    "grand_casino": {
        "stage.floor_fixture.01": "stage.event_floor_center",
        "stage.floor_fixture.02": "stage.event_floor_left",
        "stage.ground_marker.01": "stage.event_ground_1",
        "stage.group.01": "stage.group_floor_1",
        "stage.standing_person.01": "stage.patron_floor_1",
        "stage.standing_person.02": "stage.patron_floor_2",
        "stage.surface_item.01": "stage.event_table_left_1",
        "stage.surface_item.02": "stage.event_table_left_2",
        "stage.surface_item.03": "stage.event_table_right_1",
        "stage.surface_item.04": "stage.event_table_right_2",
        "stage.wall_mounted.01": "stage.event_wall_right",
        "stage.wall_mounted.02": "stage.event_wall_center",
        "stage.wall_mounted.03": "stage.event_wall_left",
        "exit.doorway.01": "exit.safe_left",
        "exit.doorway.02": "exit.safe_right",
    },
    "grand_casino_high_limit": {},
    "grand_casino_back_room": {},
    "grand_casino_cage": {},
}


OBJECT_SLOT_IDS = {
    "bar": {
        "event:rowdy_regular": "base.patron_floor_1",
        "event:scenario_dead_tuesday_regular": "base.patron_floor_1",
        "event:scenario_lock_in_private_game": "base.event_floor_1",
        "event:scenario_wake_route_story": "base.patron_floor_1",
        "event:side_door": "base.travel_left",
        "event:town_rumor_staff": "base.staff_bartender",
        "game_hook:pull_tabs:ticket_redeemer": "base.fixed_ticket_redeemer",
        "numbers:book": "base.fixed_ticket_redeemer",
        "service:house_drink": "base.fixed_drink",
        "travel:leave": "base.travel_right",
    },
    "corner_store": {
        "event:call_brother_in_law": "base.fixed_phone",
        "event:chatty_clerk": "base.staff_dialogue",
        "event:late_shift_discount": "base.staff_dialogue",
        "event:scenario_delivery_day_stock": "base.staff_dialogue_2",
        "event:town_rumor_staff": "base.staff_dialogue",
        "item:bag": "base.shop_item_5",
        "lender:the_crew": "base.event_group_1",
        "service:house_drink": "base.fixed_drink",
        "shopkeeper:merchant": "base.staff_shopkeeper",
        "travel:bar": "base.travel_left",
        "travel:gas_station_casino": "base.travel_right",
        "travel:jazz_club": "base.travel_right",
        "travel:leave": "base.travel_left",
        "travel:pawn_shop": "base.travel_left",
    },
    "grand_casino": {
        "casino_fixture:host_desk": "base.fixture_host_desk",
        "event:chain06_cass_first_contact": "base.staff_host",
        "event:chain06_rourke_noticed": "base.event_wall_1",
        "event:comped_suite_offer": "base.staff_host",
        "event:scenario_audit_roster": "base.event_wall_1",
        "event:scenario_convention_badge": "base.event_wall_1",
        "event:scenario_gala_cover": "base.event_floor_1",
        "event:the_house_calls": "base.staff_host",
        "event:town_rumor_staff": "base.staff_host",
        "game_hook:pull_tabs:ticket_redeemer": "base.fixed_ticket_redeemer",
        "service:house_drink": "base.fixed_drink",
        "travel:grand_casino_back_room": "base.travel_left",
        "travel:grand_casino_cage": "base.travel_right",
        "travel:grand_casino_high_limit": "base.travel_left",
        "travel:leave": "base.travel_right",
        "travel:motel": "base.travel_left",
        "travel:small_underground_casino": "base.travel_right",
    },
    "grand_casino_high_limit": {},
    "grand_casino_back_room": {},
    "grand_casino_cage": {},
}


CATEGORY_SLOT_IDS = {
    "bar": {
        "game_spots:0": "base.game_1", "game_spots:1": "base.game_2", "game_spots:2": "base.game_3",
        "event_spots:0": "base.event_floor_1", "event_spots:1": "base.event_floor_2",
        "event_spots:2": "base.patron_floor_1", "event_spots:3": "base.event_floor_2",
        "service_spots:0": "base.fixed_drink",
        "game_hook_spots:0": "base.fixed_ticket_redeemer", "game_hook_spots:1": "base.fixed_ticket_redeemer",
        "numbers_spots:0": "base.fixed_ticket_redeemer", "numbers_silas_spots:0": "base.patron_floor_1",
        "travel_spots:0": "base.travel_right", "travel_spots:1": "base.travel_left",
        "travel_spots:2": "base.travel_right", "travel_spots:3": "base.travel_left",
        "travel_spots:4": "base.travel_right", "travel_spots:5": "base.travel_left",
    },
    "corner_store": {
        "shopkeeper_spots:0": "base.staff_shopkeeper",
        "item_spots:0": "base.shop_item_1", "item_spots:1": "base.shop_item_2",
        "item_spots:2": "base.shop_item_3", "item_spots:3": "base.shop_item_4", "item_spots:4": "base.shop_item_5",
        "game_spots:0": "base.game_1",
        "event_spots:0": "base.staff_dialogue", "event_spots:1": "base.game_1",
        "event_spots:2": "base.event_group_1", "event_spots:3": "base.lender_floor_1",
        "service_spots:0": "base.fixed_phone", "service_spots:1": "base.fixed_drink",
        "lender_spots:0": "base.lender_floor_1", "lender_spots:1": "base.lender_floor_1",
        "numbers_spots:0": "base.fixed_phone",
        "travel_spots:0": "base.travel_right", "travel_spots:1": "base.travel_left",
    },
    "grand_casino": {
        "game_spots:0": "base.game_machine_1", "game_spots:1": "base.game_machine_2",
        "game_spots:2": "base.game_machine_3", "game_spots:3": "base.game_machine_4",
        "game_spots:4": "base.game_machine_5", "game_spots:5": "base.game_table_left",
        "game_spots:6": "base.game_table_right",
        "event_spots:0": "base.staff_host", "event_spots:1": "base.event_wall_1",
        "event_spots:2": "base.event_floor_1", "event_spots:3": "base.event_floor_1",
        "service_spots:0": "base.fixed_drink",
        "game_hook_spots:0": "base.fixed_ticket_redeemer",
        "game_hook_spots:1": "base.fixed_ticket_redeemer",
        "casino_fixture_spots:0": "base.fixture_host_desk",
        "casino_fixture_spots:1": "base.event_floor_1",
        "casino_door_spots:0": "base.travel_right",
        "casino_door_spots:1": "base.travel_left",
        "casino_door_spots:2": "base.travel_left",
        "travel_spots:0": "base.travel_left",
    },
    "grand_casino_high_limit": {
        "game_spots:0": "base.game_table_1", "game_spots:1": "base.game_table_2",
        "game_spots:2": "base.game_table_3", "game_spots:3": "base.game_table_4",
        "event_spots:0": "base.event_floor_1", "event_spots:1": "base.patron_floor_1",
        "casino_door_spots:0": "base.travel_left", "casino_door_spots:1": "base.travel_right",
        "travel_spots:0": "base.travel_right",
    },
    "grand_casino_back_room": {
        "game_spots:0": "base.game_table_left", "game_spots:1": "base.game_table_right",
        "event_spots:0": "base.patron_floor_1",
        "travel_spots:0": "base.travel_left",
    },
    "grand_casino_cage": {
        "item_spots:0": "base.shop_item_1", "item_spots:1": "base.shop_item_2",
        "item_spots:2": "base.shop_item_3", "item_spots:3": "base.shop_item_4",
        "casino_fixture_spots:0": "base.fixture_cage_1",
        "casino_fixture_spots:1": "base.fixture_cage_2",
        "casino_door_spots:0": "base.casino_floor_door",
        "travel_spots:0": "base.travel_floor_door",
    },
}


CLASS_OVERRIDES = {
    "bar": {
        "game:slot": "surface_item",
        "game:bar_dice": "surface_item",
        "game:pull_tabs": "surface_item",
        "game:coin_pusher": "surface_item",
        "game_hook:pull_tabs:ticket_redeemer": "surface_item",
        "event:rowdy_regular": "standing_person",
    },
    "corner_store": {
        "event:chatty_clerk": "behind_counter_person",
        "event:late_shift_discount": "behind_counter_person",
        "event:town_rumor_staff": "behind_counter_person",
        "delivery_clerk": "standing_person",
        "inventory_clerk": "standing_person",
        "night_clerk": "standing_person",
    },
    "grand_casino": {
        "event:chain06_rourke_noticed": "wall_mounted",
        "event:scenario_audit_roster": "wall_mounted",
        "event:scenario_convention_badge": "wall_mounted",
        "game:blackjack": "surface_item",
        "game:craps": "surface_item",
        "game:pull_tabs": "wall_mounted",
        "game:slot": "wall_mounted",
        "game:slot:2": "wall_mounted",
        "game:slot:3": "wall_mounted",
        "game:video_poker": "wall_mounted",
        "game_hook:pull_tabs:ticket_redeemer": "wall_mounted",
        "service:house_drink": "surface_item",
    },
    "grand_casino_high_limit": {
        "game:baccarat": "surface_item",
        "game:blackjack": "surface_item",
        "game:craps": "surface_item",
        "game:roulette": "surface_item",
    },
    "grand_casino_back_room": {
        "game:blackjack": "surface_item",
        "game:craps": "surface_item",
    },
    "grand_casino_cage": {},
}


COUNTER_UPDATES = {
    "corner_store": {"register": {"x1": 624.0}},
}


COUNTER_ADDITIONS = {
    "corner_store": [
        {
            "id": "left_checkout_counter",
            "x0": 170.0,
            "x1": 270.0,
            "top_y": 270.0,
            "front_y": 286.0,
            "classes": ["surface_item"],
        },
    ],
}


LANE_Y = {
    "bar": 366.0,
    "corner_store": 358.0,
    "grand_casino": 414.0,
    "grand_casino_high_limit": 358.0,
    "grand_casino_back_room": 358.0,
    "grand_casino_cage": 358.0,
}


def slot_record(kind: str, index: int, spec: tuple[str, str, tuple[float, float], tuple[float, float], str]) -> dict[str, Any]:
    slot_id, placement_class, position, label_anchor, support_id = spec
    width, height = SLOT_SIZE[placement_class]
    if placement_class in {"wall_mounted", "hanging", "doorway"}:
        hit = [position[0] - width / 2.0, position[1] - height / 2.0, width, height]
    else:
        hit = [position[0] - width / 2.0, position[1] - height, width, height]
    facing = "front" if placement_class in PERSON_CLASSES or placement_class == "doorway" else "none"
    return {
        "id": slot_id,
        "kind": kind,
        "pos": [position[0], position[1]],
        "footprint_class": placement_class,
        "hit_rect": hit,
        "label_anchor": [label_anchor[0], label_anchor[1]],
        "facing": facing,
        "priority": (index + 1) * 10,
        "zone_id": "room",
        "support_id": support_id,
        "walk_lane_ids": ["lane.public"] if placement_class in PERSON_CLASSES or placement_class == "doorway" else [],
    }


def apply_layout(map_data: dict[str, Any]) -> None:
    map_id = str(map_data.get("id", ""))
    literal = HAND_SLOTS[map_id]
    map_data["slot_schema_version"] = 1
    for field, kind in (("base_slots", "base"), ("stage_slots", "stage"), ("exit_slots", "exit")):
        specs = literal[kind]
        map_data[field] = [slot_record(kind, index, spec) for index, spec in enumerate(specs)]
    lane_y = LANE_Y[map_id]
    map_data["walk_lanes"] = [{
        "id": "lane.public",
        "points": [[64.0, lane_y], [450.0, lane_y], [836.0, lane_y]],
        "clearance_px": 8.0,
        "direction": "both",
        "entry": True,
    }]
    map_data["actor_routes"] = []
    map_data["scenario_position_route_ids"] = {}
    map_data["object_slot_ids"] = dict(sorted(OBJECT_SLOT_IDS[map_id].items()))
    map_data["category_slot_ids"] = dict(sorted(CATEGORY_SLOT_IDS[map_id].items()))
    renames = SCENARIO_SLOT_RENAMES[map_id]
    valid_slot_ids = {
        str(slot["id"])
        for field in ("stage_slots", "exit_slots")
        for slot in map_data[field]
    }
    scenario_preferences: dict[str, str] = {}
    for identity, old_slot_id in map_data.get("scenario_slot_ids", {}).items():
        new_slot_id = renames.get(str(old_slot_id), str(old_slot_id))
        if new_slot_id not in valid_slot_ids:
            raise ValueError(f"{map_id}: no literal slot mapping for {identity} -> {old_slot_id}")
        scenario_preferences[str(identity)] = new_slot_id
    map_data["scenario_slot_ids"] = dict(sorted(scenario_preferences.items()))
    class_overrides = dict(map_data.get("class_overrides", {}))
    class_overrides.update(CLASS_OVERRIDES[map_id])
    map_data["class_overrides"] = dict(sorted(class_overrides.items()))
    updates = COUNTER_UPDATES.get(map_id, {})
    for counter in map_data.get("counters", []):
        if isinstance(counter, dict) and str(counter.get("id", "")) in updates:
            counter.update(updates[str(counter["id"])])
    counters = [counter for counter in map_data.get("counters", []) if isinstance(counter, dict)]
    additions = {str(counter["id"]): counter for counter in COUNTER_ADDITIONS.get(map_id, [])}
    map_data["counters"] = [counter for counter in counters if str(counter.get("id", "")) not in additions]
    map_data["counters"].extend(additions.values())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--map", action="append", dest="maps", choices=sorted(HAND_SLOTS))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    selected = set(args.maps or HAND_SLOTS)
    path = args.root.resolve() / "data/environments/placement_surfaces.json"
    source = json.loads(path.read_text(encoding="utf-8"))
    generated = json.loads(json.dumps(source))
    found: set[str] = set()
    for map_data in generated.get("maps", []):
        if isinstance(map_data, dict) and str(map_data.get("id", "")) in selected:
            apply_layout(map_data)
            found.add(str(map_data["id"]))
    if found != selected:
        raise SystemExit(f"missing placement maps: {sorted(selected - found)}")
    encoded = json.dumps(generated, indent=2, ensure_ascii=False) + "\n"
    if args.check:
        if encoded != path.read_text(encoding="utf-8"):
            raise SystemExit("hand-authored fixed slots are stale")
        print("RW06_1_HAND_AUTHORED_SLOT_CHECK PASS " + ",".join(sorted(selected)))
        return 0
    path.write_text(encoded, encoding="utf-8", newline="\n")
    print("RW06_1_HAND_AUTHORED_SLOT_WRITE PASS " + ",".join(sorted(selected)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
