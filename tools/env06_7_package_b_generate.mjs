import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();
const PACKAGE_PATH = path.join(ROOT, "data/environments/scenario_sequences/env06_7_roadside_shelter.json");
const DOSSIER_PATH = path.join(ROOT, "docs/plans/env06_7_package_b_sequence_dossiers.json");

const specs = [
  {
    id: "motel_conventioneers", archetype: "motel", pressure: "room_mix_deadline",
    arrival: "Suitcases, a brass luggage cart, and two guest groups divide the lobby while the exterior stair remains clear.",
    exit: "The exterior stair stays marked and open throughout the room mix-up.",
    props: [["luggage_cart", "Brass luggage cart", "obstacle", "left"], ["blue_cases", "Blue-tag suitcases", "stock", "center"], ["red_cases", "Red-tag suitcases", "stock", "right"], ["room_board", "Room assignment board", "workstation", "background"]],
    actors: [["desk_clerk", "Desk clerk", "motel_desk_clerk", "work", "service_lane"], ["coach_party", "Coach party", "motel_coach_party", "idle", "left"]],
    beats: [
      ["compare_claim_tags", "Compare claim tags", "Inspect the cart tags against the room board.", "set_state", "room_board", "cross_checked", "set_pose", "desk_clerk", "checking_ledger"],
      ["roll_cart_to_wing", "Route the luggage cart", "Roll the cart through the unoccupied wing before the guests move.", "move", "luggage_cart", "right", "set_position", "coach_party", "center"],
      ["reassign_room_keys", "Reassign room keys", "Match the separated cases to a room and hand over the corrected keys.", "set_appearance", "blue_cases", "sorted_tags", "set_behavior", "desk_clerk", "work"]
    ],
    outcomes: [["rooms_balanced", "Balanced wings", "The carts sit by the correct wing and both desk windows serve guests.", "set_state", "luggage_cart", "parked_right"], ["service_wing_open", "Service wing open", "The crowd moves upstairs and the side desk reopens.", "set_appearance", "room_board", "reassigned"], ["crowd_jammed", "Lobby jammed", "Mixed cases and guests still choke the center lane.", "set_state", "red_cases", "misrouted"], ["mixup_refused", "Mix-up refused", "The clerk ropes off one wing and handles the dispute alone.", "set_appearance", "luggage_cart", "roped_off"], ["mixup_interrupted", "Mix-up interrupted", "The cart remains tagged for the next visit beside the clear stair.", "set_state", "room_board", "paused"]],
    fact: "service_result", connection: "lodging_rest_service", expiry: ["visit_end", 1, "cleanup"]
  },
  {
    id: "motel_stakeout", archetype: "motel", pressure: "moving_sight_cones",
    arrival: "Two observers hold opposite balcony angles while a laundry trolley creates one moving patch of cover.",
    exit: "The open courtyard gate remains outside both marked sight cones.",
    props: [["north_scope", "North surveillance scope", "evidence", "background"], ["south_camera", "South balcony camera", "evidence", "right"], ["laundry_trolley", "Laundry trolley cover", "obstacle", "left"], ["watched_door", "Watched room door", "door", "center"], ["courtyard_gate", "Clear courtyard gate", "exit", "exit_lane"]],
    actors: [["north_observer", "North observer", "motel_north_observer", "watch", "background"], ["south_observer", "South observer", "motel_south_observer", "watch", "right"]],
    beats: [
      ["trace_sight_cones", "Trace both sight cones", "Compare the two observer angles without entering either cone.", "set_appearance", "north_scope", "cone_marked", "set_pose", "north_observer", "scanning"],
      ["shift_laundry_cover", "Shift the laundry cover", "Move the trolley once to expose which door both observers track.", "move", "laundry_trolley", "center", "set_position", "south_observer", "background"]
    ],
    outcomes: [["occupant_warned", "Occupant warned", "The watched room empties and the trolley shields its open door.", "set_state", "watched_door", "cleared"], ["observers_misdirected", "Observers misdirected", "Both scopes point toward an empty service room.", "set_appearance", "south_camera", "false_target"], ["observer_waitout_failed", "Wait-out failed", "One observer moves downstairs and the watched door remains occupied.", "set_state", "north_scope", "mobile_watch"], ["stakeout_refused", "Stakeout refused", "The balcony remains divided by visible sight lines.", "set_appearance", "watched_door", "watched"], ["stakeout_interrupted", "Stakeout interrupted", "The laundry trolley stays parked as a partial cover marker.", "set_state", "laundry_trolley", "partial_cover"]],
    fact: "sweep_changed", connection: "security_sweep_sightline", expiry: ["leave", 1, "ignore"]
  },
  {
    id: "motel_weekly_rates", archetype: "motel", pressure: "failing_room_inspection",
    arrival: "A sagging bed, dead lamp, leaking sink, and landlord's clipboard make the weekly room physically inspectable.",
    exit: "The room door remains usable even while utilities are isolated.",
    props: [["weekly_bed", "Sagging weekly bed", "furniture", "left"], ["weekly_lamp", "Dead bedside lamp", "utility", "right"], ["weekly_sink", "Leaking sink", "utility", "background"], ["lease_clipboard", "Weekly lease clipboard", "workstation", "center"]],
    actors: [["landlord", "Motel landlord", "motel_landlord", "watch", "service_lane"]],
    beats: [
      ["inspect_room_faults", "Inspect the room faults", "Test the lamp, sink, and bed before discussing a weekly price.", "set_state", "weekly_lamp", "tested_dead", "set_pose", "landlord", "taking_notes"],
      ["isolate_sink_valve", "Isolate the sink valve", "Shut the leaking valve without disabling the room door.", "set_appearance", "weekly_sink", "valve_closed", "set_behavior", "landlord", "work"],
      ["brace_bed_frame", "Brace the bed frame", "Fit the loose brace and demonstrate whether the room is rest-ready.", "set_state", "weekly_bed", "braced", "set_pose", "landlord", "checking_repair"],
      ["negotiate_weekly_terms", "Negotiate weekly terms", "Mark repaired or accepted-as-is utilities on the clipboard.", "set_appearance", "lease_clipboard", "terms_marked", "set_behavior", "landlord", "idle"]
    ],
    outcomes: [["room_repaired", "Room repaired", "The lamp works, sink is dry, and repaired room offers full rest.", "set_appearance", "weekly_lamp", "lit"], ["room_accepted", "Room accepted as-is", "The braced bed remains usable while the lamp stays tagged out.", "set_state", "weekly_bed", "accepted_brace"], ["negotiation_failed", "Negotiation failed", "The clipboard is withdrawn and utilities remain isolated.", "set_state", "lease_clipboard", "withdrawn"], ["inspection_refused", "Inspection refused", "The room stays available only as an unverified short stop.", "set_appearance", "weekly_sink", "warning_tag"], ["repair_interrupted", "Repair interrupted", "Tools remain boxed beside the dry valve for a safe revisit.", "set_state", "weekly_lamp", "repair_paused"]],
    fact: "service_result", connection: "rest_service_authority", expiry: ["town_action", 2, "fail"]
  },
  {
    id: "motel_wedding_overflow", archetype: "motel", pressure: "processional_room_clock",
    arrival: "Bouquet cases, garment bags, and two wedding parties occupy alternating doors along the motel corridor.",
    exit: "A ribbon-marked exterior stair remains clear past the last room.",
    props: [["bouquet_case", "Missing bouquet case", "clue", "left"], ["garment_rack", "Wedding garment rack", "obstacle", "center"], ["room_key_tray", "Mixed room-key tray", "workstation", "service_lane"], ["reception_cart", "Reception cart", "furniture", "right"], ["ribbon_stair", "Ribbon-marked stair", "exit", "exit_lane"]],
    actors: [["wedding_runner", "Wedding runner", "motel_wedding_runner", "work", "left"], ["best_person", "Best person", "motel_best_person", "watch", "right"], ["desk_clerk", "Desk clerk", "motel_desk_clerk", "work", "service_lane"]],
    beats: [
      ["read_room_key_trail", "Read the room-key trail", "Compare the mixed keys with ribbons left at three doors.", "set_state", "room_key_tray", "three_clues", "set_position", "wedding_runner", "center"],
      ["wheel_garments_clear", "Clear the garment rack", "Wheel the rack to open the second-room clue without blocking the stair.", "move", "garment_rack", "right", "set_pose", "best_person", "checking_tags"],
      ["recover_bouquet_case", "Recover the bouquet case", "Carry the recovered case to either the reception cart or the arguing party.", "move", "bouquet_case", "center", "set_behavior", "wedding_runner", "depart"]
    ],
    outcomes: [["reception_reunited", "Reception reunited", "The bouquet reaches the reception cart and guests gather in one open room.", "set_state", "reception_cart", "reception_ready"], ["corridor_argument", "Corridor argument", "The bouquet is claimed at the wrong door and both parties face the corridor.", "set_appearance", "bouquet_case", "contested"], ["corridor_locked", "Corridor locked", "Room doors close around the missing-item dispute.", "set_state", "room_key_tray", "keys_recalled"], ["wedding_refused", "Wedding task refused", "The garment rack remains parked but the stair stays open.", "set_appearance", "garment_rack", "unclaimed"], ["wedding_interrupted", "Wedding task interrupted", "The recovered clue is pinned to the key tray for revisit.", "set_state", "room_key_tray", "clue_pinned"]],
    fact: "travel_departed", connection: "traveler_party_routing", expiry: ["night_end", 1, "cleanup"]
  },
  {
    id: "gas_station_trucker_convoy", archetype: "gas_station_casino", pressure: "departure_wave",
    arrival: "Three rig markers, a pallet lane, and driver groups occupy alternating pumps and machines in a visible departure queue.",
    exit: "The pedestrian stripe stays clear between the forecourt and road.",
    props: [["lead_rig", "Lead rig marker", "vehicle", "left"], ["relay_rig", "Relay rig marker", "vehicle", "center"], ["tail_rig", "Tail rig marker", "vehicle", "right"], ["freight_pallet", "Freight pallet", "stock", "foreground"], ["departure_board", "Convoy departure board", "workstation", "background"]],
    actors: [["lead_driver", "Lead driver", "gas_lead_driver", "work", "left"], ["relay_driver", "Relay driver", "gas_relay_driver", "idle", "center"], ["machine_driver", "Machine-side driver", "gas_machine_driver", "idle", "right"]],
    beats: [
      ["read_departure_board", "Read departure order", "Compare the board with the rigs physically blocking each wave.", "set_appearance", "departure_board", "wave_order", "set_pose", "lead_driver", "calling_wave"],
      ["clear_freight_lane", "Clear the freight lane", "Shift the pallet to free one rig without closing the pedestrian stripe.", "move", "freight_pallet", "background", "set_position", "relay_driver", "foreground"],
      ["release_convoy_wave", "Release a convoy wave", "Signal the correct driver group and free its machine seats.", "move", "lead_rig", "exit_lane", "set_behavior", "lead_driver", "depart"]
    ],
    outcomes: [["convoy_coordinated", "Convoy coordinated", "Rigs depart in order and traveler seats reopen beside a clear forecourt.", "set_state", "departure_board", "departed_orderly"], ["machine_claim_won", "Machine claim won", "One rig remains loading while its driver's machine seat opens.", "set_appearance", "relay_rig", "loading_hold"], ["convoy_gridlocked", "Convoy gridlocked", "The tail rig rotates across two pumps and the freight lane closes.", "set_state", "tail_rig", "cross_pumps"], ["convoy_refused", "Convoy refused", "Drivers keep their original stations and the marked stripe remains the only route.", "set_appearance", "departure_board", "no_coordinator"], ["convoy_interrupted", "Convoy interrupted", "One released rig is gone and remaining wave numbers stay posted.", "set_state", "lead_rig", "departed_partial"]],
    fact: "travel_departed", connection: "traveler_departure_link", expiry: ["town_action", 1, "cleanup"]
  },
  {
    id: "gas_station_tour_bus_stop", archetype: "gas_station_casino", pressure: "boarding_countdown",
    arrival: "A bus door, passenger queue, restroom line, and ticket basket divide the forecourt into timed boarding stations.",
    exit: "The road-side pedestrian gate remains open behind the queue.",
    props: [["tour_bus_door", "Tour bus door", "vehicle", "right"], ["ticket_basket", "Loose ticket basket", "clue", "center"], ["boarding_counter", "Boarding counter", "workstation", "background"], ["restroom_queue", "Restroom queue marker", "obstacle", "left"]],
    actors: [["bus_driver", "Tour bus driver", "gas_bus_driver", "watch", "right"], ["stranded_passenger", "Ticketless passenger", "gas_stranded_passenger", "idle", "center"], ["queue_marshal", "Queue marshal", "gas_queue_marshal", "work", "left"]],
    beats: [
      ["count_boarding_groups", "Count boarding groups", "Mark passengers at the bus, restroom, and machines on the counter.", "set_state", "boarding_counter", "count_started", "set_pose", "queue_marshal", "counting"],
      ["trace_lost_ticket", "Trace the lost ticket", "Match the loose ticket stub to the passenger's three physical stops.", "set_appearance", "ticket_basket", "stub_matched", "set_position", "stranded_passenger", "left"],
      ["close_boarding_count", "Close the boarding count", "Reconcile the driver count before the bus door closes.", "set_state", "tour_bus_door", "final_call", "set_behavior", "bus_driver", "work"]
    ],
    outcomes: [["bus_boarded", "Bus boarded", "The matched passenger boards and the forecourt clears at departure.", "set_appearance", "tour_bus_door", "departing"], ["passenger_stranded", "Passenger stranded", "The bus leaves while a ticketless passenger remains by the counter.", "set_state", "stranded_passenger", "stranded"], ["bus_delayed", "Bus delayed", "The driver reopens the door while the restroom group is recounted.", "set_state", "boarding_counter", "recount"], ["count_refused", "Count refused", "The marshal handles a noisy queue without closing the pedestrian gate.", "set_appearance", "restroom_queue", "unmanaged"], ["count_interrupted", "Count interrupted", "A partial tally remains legible on the boarding counter.", "set_state", "boarding_counter", "partial_tally"]],
    fact: "travel_arrived", connection: "timed_travel_manifest", expiry: ["visit_end", 1, "fail"]
  },
  {
    id: "gas_station_graveyard_shift", archetype: "gas_station_casino", pressure: "alternating_lock_cycle",
    arrival: "A camera monitor, shutter panel, flashlight dock, and alternating locked zones define a solitary night-check route.",
    exit: "The illuminated emergency strip remains open outside every lock cycle.",
    props: [["camera_monitor", "Camera monitor", "security", "background"], ["shutter_panel", "Shutter control panel", "workstation", "right"], ["flashlight_dock", "Flashlight dock", "utility", "center"], ["cooler_gate", "Cooler-zone gate", "door", "left"], ["machine_gate", "Machine-zone gate", "door", "foreground"]],
    actors: [["night_clerk", "Night clerk", "gas_night_clerk", "guard", "service_lane"]],
    beats: [
      ["take_flashlight", "Take the docked flashlight", "Remove the flashlight and acknowledge the first camera blind spot.", "set_appearance", "flashlight_dock", "empty_dock", "set_pose", "night_clerk", "watching_monitor"],
      ["check_cooler_lock", "Check the cooler lock", "Cross the open zone and physically test the cooler gate.", "set_state", "cooler_gate", "checked", "set_position", "night_clerk", "left"],
      ["cycle_machine_shutter", "Cycle the machine shutter", "Close the cooler before opening the machine zone.", "set_state", "machine_gate", "open", "set_behavior", "night_clerk", "patrol"],
      ["review_camera_gap", "Review the camera gap", "Return to the monitor and reconcile the route with the recorded blind spot.", "set_appearance", "camera_monitor", "gap_marked", "set_pose", "night_clerk", "logging"]
    ],
    outcomes: [["night_check_complete", "Night check complete", "Lights and shutters settle into a verified alternating pattern.", "set_state", "shutter_panel", "verified_cycle"], ["camera_bypass", "Camera bypassed", "One dark machine lane stays open outside the camera arc.", "set_appearance", "camera_monitor", "bypassed_lane"], ["lock_cycle_failed", "Lock cycle failed", "Both internal gates close while the emergency strip remains open.", "set_state", "machine_gate", "failed_closed"], ["night_check_refused", "Night check refused", "The clerk keeps all internal shutters closed and watches the entry.", "set_appearance", "shutter_panel", "manual_lock"], ["night_check_interrupted", "Night check interrupted", "The flashlight returns beside a panel showing the last completed zone.", "set_state", "flashlight_dock", "partial_route"]],
    fact: "sweep_changed", connection: "security_camera_exposure", expiry: ["night_end", 1, "cleanup"]
  },
  {
    id: "gas_station_road_crew_payday", archetype: "gas_station_casino", pressure: "pooled_stake_rotation",
    arrival: "A work-order board, pooled-stake envelope, barricade stack, and rotating road crew occupy counter and machine stations.",
    exit: "A cone-marked walkway remains clear beside the work stations.",
    props: [["work_order_board", "Road work-order board", "workstation", "background"], ["stake_envelope", "Pooled-stake envelope", "evidence", "center"], ["barricade_stack", "Road barricade stack", "obstacle", "left"], ["repair_crate", "Repair parts crate", "stock", "right"]],
    actors: [["crew_foreman", "Road crew foreman", "gas_crew_foreman", "work", "left"], ["stake_keeper", "Crew stake keeper", "gas_stake_keeper", "watch", "center"], ["machine_player", "Crew machine player", "gas_machine_player", "idle", "right"]],
    beats: [
      ["audit_pooled_stake", "Audit the pooled stake", "Match envelope marks to the crew names and occupied machine station.", "set_state", "stake_envelope", "audited", "set_pose", "stake_keeper", "checking_marks"],
      ["stage_repair_parts", "Stage repair parts", "Move the correct crate beside the barricades before settling the work order.", "move", "repair_crate", "left", "set_position", "crew_foreman", "center"],
      ["reconcile_work_order", "Reconcile the work order", "Mark whether pooled play funded parts or delayed the crew.", "set_appearance", "work_order_board", "reconciled", "set_behavior", "machine_player", "depart"]
    ],
    outcomes: [["route_repaired", "Route repaired", "The crew takes the staged parts and removes the barricades from one road lane.", "set_state", "barricade_stack", "loaded_out"], ["floor_occupied", "Floor occupied", "The stake envelope stays open and crew members rotate through machines.", "set_appearance", "stake_envelope", "active_pool"], ["crew_departed_early", "Crew departed early", "The work order is crossed out and unstaged barricades remain.", "set_state", "work_order_board", "departed_early"], ["stake_dispute_refused", "Stake dispute refused", "The foreman closes the envelope and keeps the walkway open.", "set_appearance", "stake_envelope", "sealed_dispute"], ["payday_interrupted", "Payday interrupted", "Audited marks remain on the envelope without settling any game authority.", "set_state", "stake_envelope", "audit_paused"]],
    fact: "game_result", connection: "public_game_result_work_order", expiry: ["town_action", 2, "ignore"]
  },
  {
    id: "gas_station_storm_shelter", archetype: "gas_station_casino", pressure: "progressive_weather_closure",
    arrival: "Rain shutters, a generator cart, supply shelves, and arriving patrons progressively compress the shop into marked safe zones.",
    exit: "The rear emergency door remains clear behind the shelter tape.",
    props: [["rain_shutters", "Rain shutters", "door", "background"], ["generator_cart", "Generator cart", "utility", "left"], ["supply_shelves", "Storm supply shelves", "stock", "right"], ["safe_zone_tape", "Safe-zone floor tape", "route", "center"], ["power_panel", "Shelter power panel", "workstation", "service_lane"]],
    actors: [["shelter_clerk", "Shelter clerk", "gas_shelter_clerk", "work", "service_lane"], ["family_group", "Sheltering family", "gas_shelter_family", "idle", "right"], ["driver_group", "Sheltering drivers", "gas_shelter_drivers", "idle", "left"]],
    beats: [
      ["close_rain_shutters", "Close rain shutters", "Latch the exterior shutters before wind reaches the supply lane.", "set_state", "rain_shutters", "latched", "set_position", "driver_group", "center"],
      ["roll_generator_safe", "Roll the generator safe", "Move the generator cart onto the dry service pad.", "move", "generator_cart", "service_lane", "set_pose", "shelter_clerk", "checking_power"],
      ["inventory_storm_supplies", "Inventory storm supplies", "Count water and blankets before allocating the taped zones.", "set_appearance", "supply_shelves", "counted", "set_position", "family_group", "center"],
      ["allocate_safe_space", "Allocate safe space", "Place drivers and family on opposite sides of the powered lane.", "set_state", "safe_zone_tape", "allocated", "set_behavior", "driver_group", "idle"]
    ],
    outcomes: [["station_reopened", "Station reopened", "Shutters lift, generator returns left, and ordinary service lanes reopen.", "set_appearance", "rain_shutters", "open_after_storm"], ["shelter_blackout", "Shelter blackout", "The dead panel moves everyone inside the taped center zone.", "set_state", "power_panel", "blackout"], ["shelter_crowded", "Shelter remains crowded", "Supplies stay rationed and both groups occupy separate marked zones.", "set_state", "safe_zone_tape", "crowded_split"], ["shelter_refused", "Shelter duty refused", "The clerk closes exterior shutters but makes no unsafe allocation.", "set_appearance", "power_panel", "clerk_only"], ["shelter_interrupted", "Shelter duty interrupted", "Latched shutters and counted stock preserve safe partial progress.", "set_state", "supply_shelves", "partial_count"]],
    fact: "town_transition", connection: "weather_town_boundary", expiry: ["town_action", 1, "cleanup"]
  },
  {
    id: "beach_bonfire_night", archetype: "beach", pressure: "tide_and_wind_window",
    arrival: "Driftwood bundles, movable seats, a tide marker, and a windbreak outline define a growing fire site above the clear dune exit.",
    exit: "The dune stair remains marked above the tide line.",
    props: [["driftwood_bundle", "Dry driftwood bundle", "stock", "left"], ["bonfire_ring", "Stone bonfire ring", "workstation", "center"], ["beach_seats", "Movable beach seats", "furniture", "right"], ["tide_marker", "Rising tide marker", "route", "foreground"], ["windbreak", "Windbreak outline", "obstacle", "background"]],
    actors: [["fire_tender", "Fire tender", "beach_fire_tender", "work", "center"], ["night_swimmers", "Night swimmers", "beach_night_swimmers", "idle", "right"]],
    beats: [
      ["read_tide_wind", "Read tide and wind", "Compare the tide marker with the windbreak before placing fuel.", "set_appearance", "tide_marker", "wind_read", "set_pose", "fire_tender", "testing_wind"],
      ["stack_bonfire_fuel", "Stack bonfire fuel", "Carry dry driftwood into the ring above the wet line.", "move", "driftwood_bundle", "center", "set_position", "fire_tender", "left"],
      ["reposition_beach_seats", "Reposition beach seats", "Arc the seats around the lee side without closing the dune stair.", "move", "beach_seats", "background", "set_position", "night_swimmers", "center"]
    ],
    outcomes: [["communal_fire", "Communal fire", "Seats circle a bright ring and swimmers return above the tide line.", "set_state", "bonfire_ring", "communal_lit"], ["hidden_fire", "Hidden fire", "The low fire burns behind the windbreak with a narrow seated arc.", "set_appearance", "windbreak", "concealing_fire"], ["fire_extinguished", "Fire extinguished", "Wet stones and stacked seats leave the shoreline route open.", "set_state", "bonfire_ring", "extinguished"], ["bonfire_refused", "Bonfire refused", "Fuel remains bundled while the dune stair stays clear.", "set_appearance", "driftwood_bundle", "untouched"], ["bonfire_interrupted", "Bonfire interrupted", "A half-built ring sits above a visibly updated tide marker.", "set_state", "tide_marker", "partial_build"]],
    fact: "world_boundary", connection: "weather_tide_boundary", expiry: ["night_end", 1, "cleanup"]
  },
  {
    id: "beach_storm_coming", archetype: "beach", pressure: "evacuation_warning_phases",
    arrival: "A warning flag, loose rental props, rescue skiff, and inland staging line make the approaching storm physically readable.",
    exit: "The inland boardwalk remains open beyond the staging line.",
    props: [["warning_flag", "Storm warning flag", "signal", "background"], ["rental_props", "Loose beach rentals", "stock", "right"], ["rescue_skiff", "Rescue skiff", "vehicle", "left"], ["evacuation_line", "Inland staging line", "route", "center"], ["closed_stall", "Closing rental stall", "workstation", "foreground"]],
    actors: [["lifeguard", "Lifeguard", "beach_lifeguard", "guard", "center"], ["stall_keeper", "Rental stall keeper", "beach_stall_keeper", "work", "foreground"], ["late_swimmer", "Late swimmer", "beach_late_swimmer", "idle", "right"]],
    beats: [
      ["raise_warning_flag", "Raise the warning flag", "Hoist the visible warning before securing shoreline props.", "set_state", "warning_flag", "raised", "set_pose", "lifeguard", "signaling"],
      ["lash_rental_props", "Lash rental props", "Bundle loose rentals onto the stall's inland side.", "move", "rental_props", "foreground", "set_position", "stall_keeper", "right"],
      ["stage_rescue_skiff", "Stage the rescue skiff", "Pull the skiff to the evacuation line for the late swimmer.", "move", "rescue_skiff", "center", "set_behavior", "lifeguard", "work"],
      ["evacuate_shoreline", "Evacuate shoreline", "Move the final actor inland before the warning phase closes.", "set_appearance", "evacuation_line", "active_inland", "set_behavior", "late_swimmer", "depart"]
    ],
    outcomes: [["shoreline_protected", "Shoreline protected", "Lashed rentals and the staged skiff survive behind the inland line.", "set_state", "closed_stall", "secured"], ["shoreline_damaged", "Shoreline damaged", "Unsecured stall pieces scatter below the intact boardwalk exit.", "set_appearance", "rental_props", "storm_scattered"], ["shoreline_abandoned", "Shoreline abandoned", "Actors leave early and the rescue skiff remains below the warning flag.", "set_state", "rescue_skiff", "abandoned"], ["storm_task_refused", "Storm task refused", "The lifeguard clears people while loose props remain marked.", "set_appearance", "warning_flag", "people_only_warning"], ["evacuation_interrupted", "Evacuation interrupted", "Secured rentals remain inland while the skiff marks incomplete evacuation.", "set_state", "evacuation_line", "partial_evacuation"]],
    fact: "town_transition", connection: "weather_evacuation_state", expiry: ["town_action", 1, "fail"]
  },
  {
    id: "beach_festival_weekend", archetype: "beach", pressure: "moving_show_schedule",
    arrival: "Vendor stalls, a cable stage, moving crowd lanes, and a lost-child marker divide the beach into distinct festival zones.",
    exit: "The boardwalk ramp remains outside the crowd-control rope.",
    props: [["food_stall", "Food stall", "service", "left"], ["craft_stall", "Craft stall", "service", "right"], ["festival_stage", "Festival cable stage", "workstation", "background"], ["schedule_board", "Festival schedule board", "clue", "center"], ["lost_child_marker", "Lost-child meeting marker", "signal", "foreground"], ["crowd_rope", "Moving crowd rope", "route", "service_lane"]],
    actors: [["stage_manager", "Stage manager", "beach_stage_manager", "work", "background"], ["lost_child", "Lost child", "beach_lost_child", "idle", "foreground"], ["stall_vendor", "Stall vendor", "beach_stall_vendor", "work", "left"], ["crowd_marshal", "Crowd marshal", "beach_crowd_marshal", "guard", "center"]],
    beats: [
      ["read_festival_schedule", "Read the moving schedule", "Compare stage changes with the child's last seen stall.", "set_appearance", "schedule_board", "route_noted", "set_pose", "stage_manager", "checking_schedule"],
      ["move_crowd_rope", "Move the crowd rope", "Open a lane from the marker to the next attraction.", "move", "crowd_rope", "right", "set_position", "crowd_marshal", "service_lane"],
      ["trace_attraction_route", "Trace the attraction route", "Follow physical stall clues as the crowd changes zones.", "set_state", "craft_stall", "clue_found", "set_position", "lost_child", "right"],
      ["reset_stage_cables", "Reset stage cables", "Clear the route while the schedule gap is active.", "set_state", "festival_stage", "cables_safe", "set_behavior", "stage_manager", "work"],
      ["reunite_at_meeting_marker", "Reunite at the marker", "Return the child through the reopened lane before the final set.", "move", "lost_child_marker", "center", "set_behavior", "lost_child", "depart"]
    ],
    outcomes: [["lineup_changed", "Lineup changed", "The recovered schedule moves one act while the stage and crowd lane stay open.", "set_state", "schedule_board", "revised_lineup"], ["stall_closed", "Stall closed", "The clue-bearing craft stall shutters and its crowd relocates left.", "set_appearance", "craft_stall", "closed_after_search"], ["after_hours_beach", "After-hours beach", "Stalls pack down around a cable-safe empty stage.", "set_state", "festival_stage", "after_hours"], ["festival_task_refused", "Festival task refused", "The meeting marker stays staffed while attractions continue their route.", "set_appearance", "lost_child_marker", "marshal_staffed"], ["festival_interrupted", "Festival task interrupted", "A moved rope and marked schedule preserve the partial search route.", "set_state", "crowd_rope", "partial_route"]],
    fact: "travel_arrived", connection: "traveler_festival_schedule", expiry: ["visit_end", 1, "cleanup"]
  }
];

const inputs = ["ui_accept", "ui_right", "ui_down", "ui_left", "ui_cancel", "ui_up"];
const commonZones = ["background", "center", "exit_lane", "foreground", "left", "right", "service_lane"];

function sceneOp(op, receipt, id, value = "") {
  const row = {family: "scene_ops", op, receipt_id: receipt, owner_namespace: "scenario", stable_object_id: id};
  if (op === "set_state") row.state = value;
  if (op === "set_appearance") row.appearance = value;
  if (op === "move") row.zone_id = value;
  return row;
}

function actorOp(op, receipt, id, value = "") {
  const row = {family: "actor_ops", op, receipt_id: receipt, owner_namespace: "scenario", stable_object_id: id};
  if (op === "set_pose") row.pose = value;
  if (op === "set_behavior") row.behavior = value;
  if (op === "set_position") row.zone_id = value;
  return row;
}

function action(id, label, index, handler = "publish_feedback", handlerInputs = null) {
  return {id, label, input_action: inputs[index % inputs.length], non_color_state: id, handler,
    inputs: handlerInputs ?? {message: `${label} is recorded at this physical boundary.`}};
}

function interactionOp(receipt, id, label, actions, safeExit = false) {
  return {family: "interaction_ops", op: "add", receipt_id: receipt, owner_namespace: "scenario", stable_object_id: id,
    interaction: {owner_namespace: "scenario", stable_object_id: id, label, state_label: "Available", prompt: `Use ${label.toLowerCase()} or leave by the marked route.`, enabled: true,
      available_actions: actions, input_actions: [...new Set(actions.map(a => a.input_action))], non_color_state: "available", focus_order: safeExit ? 0 : 2,
      hit_bounds: {w: 56, h: 56}, min_target_size: 44, safe_exit: safeExit, alternate_exit: false}};
}

function spawnScene(spec, row, index) {
  const [id, label, role, zone] = row;
  return {family: "scene_ops", op: "spawn", receipt_id: `arrival_${spec.id}_${id}`, owner_namespace: "scenario", stable_object_id: `${spec.id}_${id}`,
    object: {label, role, zone_id: zone, bounds: {w: 48 + (index % 3) * 12, h: 44 + (index % 2) * 12}, visible: true, enabled: true, state: "arrival", appearance: `${id}_arrival`}};
}

function spawnExitScene(spec) {
  const exitId = `${spec.id}_safe_exit`;
  return {family: "scene_ops", op: "spawn", receipt_id: `arrival_${spec.id}_exit_visual`, owner_namespace: "scenario", stable_object_id: exitId,
    object: {label: "Marked safe exit", role: "exit", zone_id: "exit_lane", bounds: {w: 56, h: 56}, visible: true, enabled: true, state: "clear", appearance: "marked_lane"}};
}

function spawnActor(spec, row, index) {
  const [id, label, actorId, behavior, zone] = row;
  return {family: "actor_ops", op: "spawn", receipt_id: `arrival_${spec.id}_${id}`, owner_namespace: "scenario", stable_object_id: `${spec.id}_${id}`,
    actor: {label, actor_id: actorId, zone_id: zone, behavior, pose: index % 2 ? "waiting" : "working"}};
}

function buildScenario(spec, scenarioIndex) {
  const objectiveId = `${spec.id}_work`;
  const exitId = `${spec.id}_safe_exit`;
  const phases = [];
  const firstVerb = spec.beats[0][0];
  phases.push({
    id: "arrival", label: "Arrival tableau", arrival_feedback: spec.arrival, exit_prompt: spec.exit,
    entry_conditions: [{type: "always"}], objective_ids: [objectiveId], advance_after_actions: 0,
    scene_ops: [...spec.props.map((row, i) => spawnScene(spec, row, i)), spawnExitScene(spec)],
    interaction_ops: [
      interactionOp(`arrival_${spec.id}_exit`, exitId, "Marked safe exit", [action(`${spec.id}_leave_safe`, "Leave by the safe route", 5)], true),
      interactionOp(`arrival_${spec.id}_${firstVerb}`, `${spec.id}_station_0`, spec.beats[0][1], [action(firstVerb, spec.beats[0][1], 0, "complete_objective_step", {objective_id: objectiveId, step_id: firstVerb})])
    ],
    actor_ops: spec.actors.map((row, i) => spawnActor(spec, row, i)),
    transition_ops: [{family: "transition_ops", op: "stage", receipt_id: `arrival_${spec.id}_stage`, owner_namespace: "scenario", stable_object_id: `${spec.id}_arrival_stage`, channel: "scenario", message: spec.arrival, stage_id: `${spec.id}_arrival`, duration_boundaries: 1 + (scenarioIndex % 3), reduced_motion_message: "Arrival objects and the marked exit appear without motion."}],
    branches: [{id: `${spec.id}_begin`, condition: {type: "command", command_id: firstVerb}, next_phase: "beat_1"}]
  });
  for (let i = 0; i < spec.beats.length; i++) {
    const beat = spec.beats[i];
    const next = i + 1 < spec.beats.length ? `beat_${i + 2}` : "decision";
    const previousStation = `${spec.id}_station_${i}`;
    const nextStation = `${spec.id}_station_${i + 1}`;
    const nextBeat = spec.beats[i + 1];
    const sceneId = `${spec.id}_${beat[4]}`;
    const actorId = `${spec.id}_${beat[7]}`;
    const sceneOperation = sceneOp(beat[3], `${spec.id}_beat_${i + 1}_${beat[3]}`, sceneId, beat[5]);
    const actorOperation = actorOp(beat[6], `${spec.id}_beat_${i + 1}_${beat[6]}`, actorId, beat[8]);
    const interactionOps = [{family: "interaction_ops", op: "remove", receipt_id: `${spec.id}_remove_station_${i}`, owner_namespace: "scenario", stable_object_id: previousStation}];
    if (nextBeat) interactionOps.push(interactionOp(`${spec.id}_add_station_${i + 1}`, nextStation, nextBeat[1], [action(nextBeat[0], nextBeat[1], i + 1, "complete_objective_step", {objective_id: objectiveId, step_id: nextBeat[0]})]));
    else interactionOps.push(interactionOp(`${spec.id}_add_advance_station`, `${spec.id}_advance_station`, "Open the aftermath station", [
      action(`${spec.id}_open_decision`, "Open the aftermath station", 3)
    ]));
    phases.push({
      id: `beat_${i + 1}`, label: beat[1], arrival_feedback: beat[2], exit_prompt: spec.exit,
      entry_conditions: [], objective_ids: [objectiveId], advance_after_actions: 0,
      scene_ops: [sceneOperation], interaction_ops: interactionOps, actor_ops: [actorOperation],
      transition_ops: [{family: "transition_ops", op: i % 2 ? "feedback" : "scene_change", receipt_id: `${spec.id}_beat_${i + 1}_feedback`, owner_namespace: "scenario", stable_object_id: `${spec.id}_beat_${i + 1}_transition`, channel: "scenario", message: beat[2], ...(i % 2 ? {} : {change_id: `${spec.id}_change_${i + 1}`})}],
      branches: [{id: `${spec.id}_advance_${i + 1}`, condition: {type: "command", command_id: nextBeat ? nextBeat[0] : `${spec.id}_open_decision`}, next_phase: next}]
    });
  }
  phases.push({
    id: "decision", label: "Branch aftermath", arrival_feedback: `The ${spec.pressure.replaceAll("_", " ")} now demands a physical resolution.`, exit_prompt: spec.exit, terminal: true,
    entry_conditions: [], objective_ids: [objectiveId], advance_after_actions: 0,
    scene_ops: [sceneOp("set_state", `${spec.id}_decision_ready`, `${spec.id}_${spec.props[(scenarioIndex + 1) % spec.props.length][0]}`, "decision_ready")],
    interaction_ops: [
      {family: "interaction_ops", op: "remove", receipt_id: `${spec.id}_remove_advance_station`, owner_namespace: "scenario", stable_object_id: `${spec.id}_advance_station`},
      interactionOp(`${spec.id}_add_decision`, `${spec.id}_decision_station`, "Resolve the physical aftermath", [
        action(`${spec.id}_resolve_a`, spec.outcomes[0][1], 0, "resolve_objective", {objective_id: objectiveId, outcome: "success"}),
        action(`${spec.id}_resolve_b`, spec.outcomes[1][1], 1, "resolve_objective", {objective_id: objectiveId, outcome: "success"}),
        action(`${spec.id}_fail`, spec.outcomes[2][1], 2, "resolve_objective", {objective_id: objectiveId, outcome: "failure"}),
        action(`${spec.id}_refuse`, spec.outcomes[3][1], 4, "resolve_objective", {objective_id: objectiveId, outcome: "cancel"})
      ])
    ], actor_ops: [],
    transition_ops: [{family: "transition_ops", op: "feedback", receipt_id: `${spec.id}_decision_feedback`, owner_namespace: "scenario", stable_object_id: `${spec.id}_decision_transition`, channel: "scenario", message: "The changed room remains visible while the final branch is recorded."}],
    branches: [
      {id: `${spec.id}_outcome_a`, condition: {type: "command", command_id: `${spec.id}_resolve_a`}, outcome: spec.outcomes[0][0], objective_outcomes: {[objectiveId]: "success"}},
      {id: `${spec.id}_outcome_b`, condition: {type: "command", command_id: `${spec.id}_resolve_b`}, outcome: spec.outcomes[1][0], objective_outcomes: {[objectiveId]: "success"}},
      {id: `${spec.id}_outcome_fail`, condition: {type: "command", command_id: `${spec.id}_fail`}, outcome: spec.outcomes[2][0], objective_outcomes: {[objectiveId]: "failure"}},
      {id: `${spec.id}_outcome_refuse`, condition: {type: "command", command_id: `${spec.id}_refuse`}, outcome: spec.outcomes[3][0], objective_outcomes: {[objectiveId]: "cancel"}},
      {id: `${spec.id}_outcome_interrupt`, condition: {type: "fact", fact_type: spec.fact}, outcome: spec.outcomes[4][0], objective_outcomes: {[objectiveId]: "ignore"}}
    ]
  });

  const cleanup = [];
  for (const row of spec.props) cleanup.push(sceneOp("remove", `cleanup_${spec.id}_${row[0]}`, `${spec.id}_${row[0]}`));
  for (const row of spec.actors) cleanup.push({family: "actor_ops", op: "despawn", receipt_id: `cleanup_${spec.id}_${row[0]}`, owner_namespace: "scenario", stable_object_id: `${spec.id}_${row[0]}`});
  cleanup.push(sceneOp("remove", `cleanup_${spec.id}_exit_visual`, exitId));
  cleanup.push({family: "interaction_ops", op: "remove", receipt_id: `cleanup_${spec.id}_exit`, owner_namespace: "scenario", stable_object_id: exitId});
  cleanup.push({family: "interaction_ops", op: "remove", receipt_id: `cleanup_${spec.id}_decision_station`, owner_namespace: "scenario", stable_object_id: `${spec.id}_decision_station`});

  const aftermath = {};
  spec.outcomes.forEach((outcome, i) => {
    const [, label, feedback, op, target, value] = outcome;
    const sceneId = `${spec.id}_aftermath_${outcome[0]}`;
    const sceneSpawn = {family: "scene_ops", op: "spawn", receipt_id: `aftermath_${spec.id}_${i}_scene`, owner_namespace: "scenario", stable_object_id: sceneId,
      object: {label: `${label} physical marker`, role: ["aftermath", "route", "service", "evidence", "shelter"][i], zone_id: ["center", "right", "left", "background", "foreground"][i],
        bounds: {w: 48 + i * 8 + (scenarioIndex % 3) * 4, h: 44 + ((i + scenarioIndex) % 3) * 8}, visible: true, enabled: i !== 2,
        state: value, appearance: `${op}_${target}_${value}`}};
    aftermath[outcome[0]] = {label, revisit_feedback: feedback, scene_ops: [sceneSpawn]};
    if (i === 0 || i === 2 || (i === 4 && scenarioIndex % 2 === 0)) {
      const actorId = `${spec.id}_aftermath_actor_${outcome[0]}`;
      aftermath[outcome[0]].actor_ops = [{family: "actor_ops", op: "spawn", receipt_id: `aftermath_${spec.id}_${i}_actor`, owner_namespace: "scenario", stable_object_id: actorId,
        actor: {label: `${label} witness`, actor_id: `${spec.archetype}_${outcome[0]}_witness`, zone_id: ["right", "left", "background"][i % 3], behavior: i === 2 ? "guard" : "idle", pose: `aftermath_${i}`}}];
    }
    if (i === 1 && scenarioIndex % 3 === 0) {
      aftermath[outcome[0]].scene_ops.push({family: "scene_ops", op: "spawn", receipt_id: `aftermath_${spec.id}_${i}_secondary`, owner_namespace: "scenario", stable_object_id: `${sceneId}_secondary`,
        object: {label: `${label} secondary route marker`, role: "route", zone_id: "service_lane", bounds: {w: 72, h: 48}, visible: true, enabled: true, state: "secondary", appearance: "split_route"}});
    }
  });

  const objectiveSteps = spec.beats.map(beat => ({id: beat[0], label: beat[1], kind: "command", command_id: beat[0]}));
  const captureIds = ["arrival", ...spec.beats.map((_, i) => `phase_${i + 1}`), ...spec.outcomes.map(o => `aftermath_${o[0]}`), "partial_revisit", "terminal_revisit", "reduced_motion", "small_screen", "obstruction_overlay", "hit_target_overlay"].map(x => `${spec.id}_${x}`);
  return {
    scenario_id: spec.id,
    sequence: {
      schema_version: 2,
      local_state_schema: {world_boundary_seen: {type: "bool", default: false, visibility: "public"}},
      phase_graph: {initial_phase: "arrival", phases},
      objectives: [{id: objectiveId, label: `Complete ${spec.id.replaceAll("_", " ")}`, progress_label: spec.pressure.replaceAll("_", " "), steps: objectiveSteps, outcomes: ["success", "failure", "ignore", "cancel"]}],
      reentry_policy: {partial: "resume", terminal: "aftermath", expired: "expired"},
      expiry: {boundary: spec.expiry[0], after: spec.expiry[1], policy: spec.expiry[2]},
      cleanup: {operations: cleanup},
      aftermath,
      mechanic_tags: [spec.archetype, spec.pressure, spec.connection, `beats_${spec.beats.length}`, `props_${spec.props.length}`, `actors_${spec.actors.length}`],
      sequence_signature: "UNSIGNED",
      owner_exceptions: [],
      declared_targets: {scene_objects: [], interactions: [], actors: [], services: [], games: [], routes: [], anchors: [], zones: commonZones.map(zone => `base::zone:${zone}`)},
      fact_subscriptions: [{fact_type: spec.fact, handler: "set_local", inputs: {key: "world_boundary_seen", value: true}}],
      completion_contract: {arrival_readable: true, semantic_changes: true, scenario_interaction: true, action_boundaries: true, choice_or_failure: true, material_outcomes: true, revisit_coverage: true, world_connection: true, primary_verb: true, feedback_and_exit: true}
    },
    authoring: {
      arrival_summary: spec.arrival,
      player_verbs: [...spec.beats.map(b => b[0]), `${spec.id}_resolve_a`, `${spec.id}_resolve_b`, `${spec.id}_fail`, `${spec.id}_refuse`],
      world_connections: [spec.connection, spec.fact, "safe_exit", "save_revisit", "exact_receipts"],
      references: {events: [], games: [], services: [], items: [], actors: spec.actors.map(a => a[2]), objects: spec.props.map(p => `scenario::${spec.id}_${p[0]}`)},
      capture_ids: captureIds,
      seed_evidence: {proof_seed: `${spec.id}_env06_7_b`, expected_outcomes: spec.outcomes.map(o => o[0]), phase_count: phases.length, branch_count: phases.reduce((n, p) => n + p.branches.length, 0), save_every_phase: true, save_every_branch: true, duplicate_receipt_atomic: true, conflicting_receipt_rejected: true, safe_exit_all_phases: true, reduced_motion: true, small_screen: true},
      masked_visual_explanations: {}
    }
  };
}

const scenarios = specs.map(buildScenario);
const pkg = {schema_version: 1, package_id: "env06_7_roadside_shelter", handler_pack: "roadside_shelter", renderer_id: "roadside_shelter", scenarios};
const dossier = {schema_version: 1, package_id: pkg.package_id, frozen_base: "855a2961", scenario_count: scenarios.length,
  scenarios: scenarios.map((row, index) => ({scenario_id: row.scenario_id, archetype: specs[index].archetype, definition_path: "data/environments/scenario_sequences/env06_7_roadside_shelter.json", handler_pack: pkg.handler_pack, renderer_id: pkg.renderer_id,
    phase_graph: row.sequence.phase_graph.phases.map(p => ({id: p.id, terminal: p.terminal === true, branches: p.branches.map(b => b.next_phase ?? b.outcome)})),
    terminal_branches: specs[index].outcomes.map(o => o[0]), semantic_objects: specs[index].props.map(p => `${row.scenario_id}_${p[0]}`), semantic_actors: specs[index].actors.map(a => `${row.scenario_id}_${a[0]}`),
    player_verbs: row.authoring.player_verbs, world_connections: row.authoring.world_connections, reentry_policy: row.sequence.reentry_policy, expiry: row.sequence.expiry,
    mechanic_signature_axes: {pressure: specs[index].pressure, beat_count: specs[index].beats.length, prop_count: specs[index].props.length, actor_count: specs[index].actors.length, fact: specs[index].fact, aftermath: specs[index].outcomes.map(o => `${o[3]}:${o[4]}:${o[5]}`)},
    capture_ids: row.authoring.capture_ids, seed_evidence: row.authoring.seed_evidence}))};

fs.mkdirSync(path.dirname(PACKAGE_PATH), {recursive: true});
fs.mkdirSync(path.dirname(DOSSIER_PATH), {recursive: true});
fs.writeFileSync(PACKAGE_PATH, JSON.stringify(pkg, null, 2) + "\n");
fs.writeFileSync(DOSSIER_PATH, JSON.stringify(dossier, null, 2) + "\n");
console.log(JSON.stringify({package: PACKAGE_PATH, dossier: DOSSIER_PATH, scenarios: scenarios.length}));
