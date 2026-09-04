import json
from pathlib import Path


PACKAGE = Path("data/environments/scenario_sequences/env06_7_shops_streets.json")

# Hand-authored room-reading copy. The script only installs and checks these
# lines; it never manufactures prose from ids, labels, or templates.
COPY = {
    "delivery_cartons": ("The cartons are stacked by mismatched labels; sorting them would clear the clerk's work path.", {"center": "The cartons now fill the sorting spot, close enough for every damaged label to be compared.", "left": "The cartons line the left wall, leaving their mismatched labels facing the sorting shelf.", "package_a_delivery_cartons_wait": "The cartons wait off the aisle in a neat stack while the clerk holds for your decision.", "changed_by_shift_cartons": "You reroute the cartons. The clerk shifts the dolly aside, exposing the damaged label and a route for the mismarked cartons."}, None),
    "mismarked_crate": ("A torn label hides the crate's destination, which is why the rest of the delivery cannot be trusted yet.", {"crushed_corner": "A crushed corner exposes enough of the old label to trace where the crate belongs.", "foreground": "The damaged crate has been pulled forward as the clearest piece of evidence in the shipment.", "background": "The mismarked crate waits behind the sorted cartons with its torn destination label still exposed.", "manifest_open": "The open manifest and the crate's torn label now tell the same story."}, None),
    "delivery_event_gate": ("A damaged manifest lies open at the work station; reading it will start a real stock conversation.", {"acted_inspect_manifest": "You spread the damaged manifest beneath the work light, exposing the mismatched destination lines."}, None),
    "delivery_exit": ("Ada has kept the front-door lane clear of the dolly and its mismarked cartons.", {"acted_ignore_delivery": "You leave the dolly parked; mismarked cartons continue to occupy the sorting side of the aisle.", "acted_refuse_sort": "You refuse the sort. The cartons remain strapped to the dolly beside Ada's return paperwork."}, None),
    "delivery_clerk": ("The delivery clerk checks the manifest twice, unwilling to shelve anything under the wrong name.", {"delivery_clerk_work": "The clerk has moved to the open work side of the shelf, keeping every label in view.", "work": "The clerk works the delivery in public instead of waving the mismatch through.", "checking_labels": "The clerk works down the exposed labels, waiting for the mismatched carton to surface.", "checking_manifest": "The clerk has returned to the manifest, keeping the stock decision open.", "awaiting_choice": "The clerk has stopped moving boxes and is plainly waiting for your answer."}, "background"),
    "delivery_runner": ("The runner braces the dolly and watches the aisle, ready to move whatever the manifest clears.", {"left": "The runner holds the left edge of the aisle so the marked exit stays open.", "delivery_runner_route": "The runner follows the dolly route between the cartons and verification shelf.", "shifting_cartons": "The runner rolls the mismarked cartons into the sorting spot without closing the front lane.", "holding_twine": "The runner holds fresh twine beside the verified shelf, ready to bind the corrected lot.", "waiting_on_choice": "The runner rests both hands on the dolly while the stock choice hangs in the air."}, "left"),
    "sorting_shelf": ("The cleared shelf pairs twine with the manifest, making the corrected lot easy to verify.", {"event_pending": "The shelf is staged and the manifest is checked; the clerk's stock decision is ready to open."}, None),
    "queue_rail": ("Handwritten place marks crowd the rail; the regulars use them to dispute who stood where.", {"center": "The queue rail has been pulled into the open so every claimed place can be seen.", "places_marked": "Fresh marks fix the queue order, and the regulars are watching who respects it.", "left": "The rail is back against the wall with the final queue order still visible."}, None),
    "number_board": ("The number board is dark enough that nobody can honestly claim a result yet.", {"active_station": "The board is lit for the draw, drawing every eye in the store.", "verified_digits": "The posted digits have been checked in public and can no longer be quietly changed."}, None),
    "corner_store_lotto_fever_exit": ("A taped path to the door stays clear beyond the restless lottery line.", {}, None),
    "lotto_regular": ("A lottery regular studies the board and the queue, making any sleight of hand feel conspicuous.", {"service_lane": "The regular has edged up beside the counter for a clean view of the draw.", "background": "The regular watches the queue from the rear wall, keeping the called order in view.", "watching_draw": "The regular watches the lit digits without blinking.", "watch": "The regular keeps both the lit digits and the clerk's hands plainly in view."}, None),
    "boarded_glass": ("Fresh boards cover the broken pane; their hurried nail pattern shows the store closed in a rush.", {"center": "The boarded pane is now the room's center of attention, with the break pattern exposed.", "left": "The boarded pane fills the left wall, where its splintered edge can be compared with the swept glass.", "foreground": "The boards have been pulled close enough to trace where the impact began."}, None),
    "suspect_object": ("A small object sits where the broken glass was swept aside, still too obscured to identify safely.", {"active_station": "The object is isolated under the counter light for a careful look.", "bagged_for_trace": "The object is sealed in a trace bag, preserving what it may reveal later."}, None),
    "corner_store_aftermath_exit": ("The marked door path avoids both the broken glass and the evidence station.", {}, None),
    "plainclothes_officer": ("A plainclothes officer watches the repair work rather than the customers, inviting careful cooperation.", {"service_lane": "The officer has moved beside the evidence station to see the recovery clearly.", "left": "The officer stands off to the side with the bagged object in view.", "background": "The officer keeps to the rear wall while watching the boarded pane and evidence light."}, "background"),
    "breaker_panel": ("The breaker panel hums behind a warm cover; its feed is the only visible link to the dead cooler.", {"center": "The suspect breaker has been brought into the work area where its feed can be isolated.", "foreground": "The breaker cover has been pulled forward under the work light, with its failed feed plainly tagged.", "open_breaker": "The breaker cover is open and the bad circuit is plainly separated from the live rows."}, None),
    "cooler_circuit": ("Condensation beads around a dark cooler circuit, tying the closed counter to the failed feed.", {"active_station": "The cooler circuit is exposed under a work light for a safe restart.", "circuit_isolated": "The failed circuit is tagged and isolated; the rest of the cooler can be handled without guessing."}, None),
    "corner_store_dead_shift_exit": ("Glow tape marks a clear route out even with half the store dark.", {}, None),
    "night_clerk": ("The night clerk listens to the cooler and keeps one hand near the emergency light.", {"service_lane": "The clerk waits beside the breaker lane, leaving room for someone to work.", "background": "The clerk stands behind the dark cooler bank, tracking the repair by sound and work light.", "holding_flashlight": "The clerk holds a steady flashlight on the isolated circuit."}, "background"),
    "count_cage": ("Open count sheets and separated stock show that tonight's inventory has not balanced.", {"center": "The count cage sits in the open with each section ready to be checked aloud.", "left": "The count cage now occupies the left aisle, with its open sheets clipped toward the counter.", "right": "The cage has been shifted beside the discrepancy shelf for a direct recount.", "section_counted": "One cage section is sealed and initialed, narrowing the remaining discrepancy."}, None),
    "discrepancy_shelf": ("A shelf of duplicate tags marks the stock nobody is willing to sign off yet.", {"active_station": "The discrepancy shelf is lit for a second count.", "discrepancy_tags": "Matched and unmatched tags now hang in separate rows, making the short lot obvious."}, None),
    "corner_store_inventory_night_exit": ("The door lane stays clear of the count cage and its loose paperwork.", {}, None),
    "inventory_clerk": ("The inventory clerk guards the pencil marks, knowing a careless recount could hide the shortage.", {"package_a_inventory_clerk_work": "The clerk moves to the signed work mark beside the discrepancy shelf.", "service_lane": "The clerk takes the counter side of the cage and leaves the customer lane open.", "work": "The clerk keeps working the visible count instead of closing the books early.", "recounting_shelf": "The clerk calls each shelf tag aloud and waits for the count to match."}, "background"),
    "chalk_ring": ("A scuffed chalk circle and heel marks show where the street dice have been landing.", {"center": "The chalk ring has been redrawn in the center where every throw can be seen.", "left": "The chalk ring has shifted left, with fresh heel marks preserving the shooters' new line.", "chalk_point_ring": "Fresh point marks ring the layout, recording how this game has been running."}, None),
    "lookout_marker": ("A bottle cap on the curb is the lookout's signal; when it moves, the game is no longer safe.", {"active_station": "The lookout marker has been set upright where the shooter can read it.", "foreground": "The marker has been kicked forward into everyone's sightline.", "right": "The bottle-cap signal rests at the right curb, visible from both the ring and alley mouth.", "warning_active": "The marker is turned to warning, making another throw a conspicuous risk."}, None),
    "back_alley_street_craps_exit": ("A gap beside the chalk ring remains wide enough to leave without crossing the game.", {}, None),
    "street_shooter": ("The shooter palms the dice and listens for the lookout before setting a point.", {"alley_background_right": "The shooter waits against the back-right wall, leaving the chalk ring readable.", "background": "The shooter has retreated behind the ring, still watching the curb signal over the crowd.", "service_lane": "The shooter has stepped to the edge of the ring so the alley route stays open.", "setting_dice": "The shooter squares the dice in the chalk, ready for a visible throw.", "watch": "The shooter pauses to watch the warning marker instead of rolling blind.", "right": "The shooter has backed off to the right, leaving the marked exit clear."}, None),
    "cruiser_beam": ("A patrol-car beam cuts across the alley mouth, closing any route that crosses its white sweep.", {"center": "The beam reaches the center of the alley, forcing movement into the remaining cover.", "left": "The cruiser beam washes the left wall, exposing the gap beside the stacked cover.", "background": "The cruiser beam has swung away, leaving only a pale reflection on the far wall."}, None),
    "stacked_cover": ("Stacked crates break the cruiser's sightline, though moving them will be easy to hear.", {"active_station": "The cover stack has been measured against the beam's sweep.", "right": "The crates now shield the right-hand route without blocking the exit.", "diversion_ready": "The top crate is tipped for a noisy diversion if the patrol looks back."}, None),
    "back_alley_cruiser_parked_exit": ("The marked exit hugs the wall outside the cruiser's direct beam.", {}, None),
    "patrol_officer": ("A patrol officer scans the alley in a practiced rhythm, punishing movement made at the wrong moment.", {"service_lane": "The officer has walked toward the service side, changing which cover matters.", "background": "The officer returns to the cruiser at the alley mouth, where the beam outlines the patrol route.", "patrol": "The officer is actively patrolling instead of merely watching the cruiser.", "scanning_doorway": "The officer's attention is fixed on the doorway, briefly leaving the far wall unwatched.", "center": "The officer has entered the alley center and made the open ground unsafe."}, "background"),
    "goods_lot": ("Several bundled lots carry conflicting marks; a clean sale starts with separating their histories.", {"center": "The goods have been spread through the center so every maker's mark can be compared.", "left": "The rejected lot sits apart on the left, leaving the likely match near the station.", "marked_goods_lots": "Each bundle now carries a chalk lot mark tied to its visible provenance."}, None),
    "auth_station": ("A loupe, lamp, and ledger wait at the authentication station, promising proof before payment.", {"active_station": "The authentication lamp is on and the ledger is open to the relevant page.", "authentication_open": "The station is ready for a public check, making a false claim harder to pass."}, None),
    "back_alley_fence_night_exit": ("A painted arrow keeps the alley exit separate from the rotating goods lots.", {}, None),
    "rotating_buyer": ("A buyer checks hands and marks more closely than faces, making provenance matter here.", {"service_lane": "The buyer waits by the checking station instead of crowding the goods.", "background": "The buyer has stepped behind the goods table, keeping the marked lots and open ledger together.", "checking_marks": "The buyer compares each chalk mark against the open ledger.", "foreground": "The buyer has stepped forward for the final authentication."}, None),
    "three_traces": ("Three faint scuffs cross at the shutter, proof that the supposedly quiet alley has seen traffic.", {"center": "The three traces are exposed together in the center light.", "left": "The three scuffs reach the left wall, where their overlapping edges become easiest to compare.", "three_traces_compared": "The scuffs have been matched into one route, pointing toward the shutter gap."}, None),
    "shutter_gap": ("A narrow gap under the shutter carries dust in both directions, suggesting recent passage.", {"active_station": "A low work light makes the dust trail beneath the shutter readable.", "right": "The shutter gap opens along the right wall, with the matched dust trail ending at its edge.", "background": "The shutter gap sits at the end of the matched trail, away from the open lane.", "opened_trace_gap": "The gap is open enough to follow, but it also leaves the route visible to anyone returning."}, None),
    "back_alley_nothing_moving_exit": ("The wall-side exit remains untouched by the trace work around the shutter.", {}, None),
    "returning_regular": ("A returning regular recognizes the scuffs and keeps glancing toward the shutter.", {"service_lane": "The regular has moved aside to let the trail be examined.", "background": "The regular waits against the rear wall, looking from the three scuffs to the shutter gap.", "flee": "The regular bolts after seeing where the matched trail leads.", "pointing_to_exit": "While retreating, the regular points out the clear wall-side exit."}, "background"),
    "estate_cart": ("An estate cart mixes keepsakes with ordinary stock; faded wrapping notes show which pieces arrived together.", {"center": "The estate lot is spread through the appraisal space so nothing stays hidden beneath the pile.", "left": "The estate cart has rolled left of the appraisal lamp, with its wrapping notes turned outward.", "segmented_appraisal_cart": "The cart is divided into signed sections, giving every object a visible place in the appraisal.", "service_lane": "The sorted cart waits beside the counter without blocking the customer path."}, None),
    "provenance_marks": ("Faded initials and auction dots offer the only honest trail through the estate lot.", {"active_station": "The marks are under the appraisal lamp beside the matching ledger.", "provenance_matched": "The visible marks now agree with the estate record, clearing the lot for a decision."}, None),
    "pawn_shop_estate_lot_day_exit": ("The front path skirts the appraisal cart and remains open to the street.", {}, None),
    "estate_appraiser": ("The appraiser handles every piece in view, making quiet substitutions difficult.", {"service_lane": "The appraiser keeps to the service side of the cart, leaving the customer route open.", "comparing_marks": "The appraiser compares the faded marks against the estate sheet line by line.", "guard": "The appraiser now guards the matched lot until its disposition is settled.", "foreground": "The appraiser stands with the provenanced pieces at the front of the station."}, "service_lane"),
    "serial_station": ("A lamp and carbon sheet wait for a serial check that will leave a paper trail.", {"center": "The serial station is pulled into the open for a legible copy.", "left": "The serial lamp and carbon sheet occupy the left counter, clear of the held object and door lane.", "serial_lamp": "The lamp catches every stamped digit, removing the excuse of a bad reading.", "background": "The lamp is dark and the station has been put away after the copy was made."}, None),
    "hold_object": ("The held object is wrapped but unsealed, pending a serial match before it can move.", {"active_station": "The object is unwrapped beside the serial copy for comparison.", "record_hold_sealed": "The matched object is sealed with the record attached, preventing a quiet swap.", "right": "The sealed hold rests to the right of the active customer lane."}, None),
    "pawn_shop_serial_check_day_exit": ("The shop door remains clear of both the serial lamp and the held object.", {}, None),
    "records_clerk": ("The records clerk keeps the carbon copy visible, making the hold accountable.", {"service_lane": "The clerk works from the service side, leaving the door path clear.", "copying_serial": "The clerk copies each serial digit under the lamp and checks it once more.", "guard": "The clerk guards the sealed hold until the record decision is complete.", "left": "The clerk stands beside the filed copy, away from the open door."}, "service_lane"),
    "unfinished_jobs": ("Half-finished repairs crowd Sal's bench; finishing one would change the shop's mood more than small talk.", {"center": "The unfinished jobs are laid out in order of what can actually be completed tonight.", "left": "The repair queue now lines the left bench, with the nearest unfinished job pulled into reach.", "jobs_prioritized": "The bench now shows a workable order, with the most urgent repair already pulled forward."}, None),
    "private_appraisal": ("A curtained appraisal waits behind the public counter, promising privacy at the cost of outside witnesses.", {"active_station": "The private lamp is on and the appraisal tools are arranged for a serious offer.", "right": "The curtained appraisal occupies the right side of the counter, apart from Sal's open repair bench.", "background": "The appraisal has moved behind the counter, out of the public traffic.", "privacy_screen": "The screen is closed around the appraisal, making the conversation quieter and less observable."}, None),
    "pawn_shop_sals_mood_exit": ("The front door path stays clear even while Sal's bench spills into the room.", {}, None),
    "sal_shopkeeper": ("Sal studies the unfinished bench before looking at customers; useful work will get farther than flattery.", {"service_lane": "Sal waits behind the counter with the open work lane between you.", "work": "Sal has turned back to the bench, judging the room by what gets finished.", "checking_finished_job": "Sal checks the completed repair closely, ready to talk once the work proves itself."}, "service_lane"),
}

AFTERMATH_COPY = {
    "stocked_rack": ("The corrected cartons are on the rack with their labels facing out; the delivery is plainly finished.", "center"),
    "torn_carton": ("A torn carton leaks packing paper beside the shelf, evidence that the rushed sort ended badly.", "foreground"),
    "sealed_pallet": ("The refused delivery remains sealed on its pallet, taking up space but preserving the clerk's choice.", "background"),
    "abandoned_manifest": ("The abandoned manifest lies under the dolly wheel, leaving the mismarked stock unresolved.", "background"),
    "angry_queue": ("The queue has bunched around crossed-out place marks; nobody trusts the order now.", "center"),
    "sold_out_counter": ("The ticket tray is empty and the counter sign is turned over; the crowd waited too long.", "service_lane"),
    "number_board_abandoned": ("The dark number board still carries half-checked chalk marks from an interrupted draw.", "background"),
    "economy_stock_public_service": ("A public stock notice lists the draw-day shortage where every customer can see it.", "service_lane"),
    "sold_out_counter_refused": ("The counter is sold out and the untouched queue marks show where the request was refused.", "service_lane"),
    "celebration_layout": ("Winning slips and paper cups cover the counter; the verified draw ended in a loud celebration.", "center"),
    "police_hold": ("A signed police hold occupies the evidence shelf, stopping the recovered object from moving quietly.", "service_lane"),
    "watched_aisle": ("The repaired aisle looks ordinary except for an officer's fresh sightline marks on the floor.", "background"),
    "suspect_object_abandoned": ("The suspect object remains where the trace work stopped, exposed but never properly bagged.", "foreground"),
    "evidence_sweep_hold": ("A sweep tag seals the evidence station and warns that official attention is still active.", "service_lane"),
    "watched_aisle_refused": ("The aisle is open, but a refused evidence tag tells everyone it is still being watched.", "background"),
    "quiet_recovery": ("New glass and a clean shelf leave only a small trace bag to show the break-in was resolved.", "background"),
    "private_darkness": ("Only the back counter has power; dark coolers and a closed register show that service stopped.", "background"),
    "flicker_lockout": ("A lockout tag hangs from the flickering breaker while the cooler doors stay shut.", "service_lane"),
    "cooler_circuit_abandoned": ("The cooler circuit is open and unattended, freezing the repair exactly where it stopped.", "foreground"),
    "surveillance_rumor_route": ("A handwritten warning points from the dead circuit toward a camera outside the store.", "background"),
    "flicker_lockout_refused": ("The same bad light pulses over a signed refusal tag; the circuit remains unsafe to touch.", "service_lane"),
    "lit_service": ("The coolers hum under steady light again, and the night counter has reopened.", "background"),
    "quarantined_section": ("One stock section is roped off with discrepancy tags after the count failed.", "background"),
    "closed_aisles": ("Folding gates close the uncounted aisles while the unresolved sheets sit at the counter.", "background"),
    "discrepancy_shelf_abandoned": ("Loose count tags remain mid-sort on the shelf, showing exactly where the recount stopped.", "foreground"),
    "economy_inventory_public_service": ("A public inventory notice explains the missing stock without naming anyone responsible.", "service_lane"),
    "closed_aisles_refused": ("The aisles stay gated after the recount was refused, leaving fewer shelves available.", "background"),
    "reopened_sections": ("Counted sections stand open with signed tags, restoring the store's normal paths.", "background"),
    "ring_relocated": ("The chalk ring has moved deeper into the alley, where the next game will be harder to see from the street.", "background"),
    "ring_dispersed": ("Only smeared chalk and hurried footprints remain; the street game broke up without a finish.", "background"),
    "lookout_marker_abandoned": ("The warning marker lies on its side beside an unfinished point, marking an interrupted game.", "foreground"),
    "street_stake_recovered": ("A tied stake pouch rests where the public game ended, ready for its rightful owner.", "foreground"),
    "ring_dispersed_refused": ("The ring is scuffed out and the untouched dice show the game was refused before the throw.", "background"),
    "ring_continues": ("A clean point and upright lookout marker show the street game is still running.", "center"),
    "diverted_patrol": ("Fresh tire marks turn away from the alley after the diversion pulled the cruiser off route.", "background"),
    "watched_route": ("The cruiser remains parked with its beam trained along the wall route.", "background"),
    "stacked_cover_abandoned": ("The shifted cover stack remains half-built, exposing the route where work stopped.", "foreground"),
    "cruiser_pressure_route": ("A chalk warning redirects foot traffic away from the cruiser's persistent beam.", "exit_lane"),
    "watched_route_refused": ("The wall route is still watched, and the untouched cover records the refused diversion.", "background"),
    "cruiser_departed": ("Cooling tire tracks and a dark alley mouth show the cruiser finally left.", "background"),
    "brokered_exit": ("A closed ledger and empty hooks show the questionable lot was moved through another exit.", "background"),
    "buyer_control": ("The buyer's tags now cover every bundle on the table, showing that the sale ended on the buyer's terms.", "center"),
    "auth_station_abandoned": ("The loupe and open ledger remain beside an unchecked lot, preserving the interrupted appraisal.", "foreground"),
    "economy_fence_public_service": ("A public price card replaces the private ledger, making the night's terms visible.", "service_lane"),
    "buyer_control_refused": ("The buyer has tagged the refused lot and left it apart from the open goods.", "background"),
    "verified_stall": ("Verified lots sit under matching marks at an orderly stall, ready for honest comparison.", "center"),
    "erased_rumor_exit": ("The shutter trail has been brushed away, leaving a clean exit and no proof of who used it.", "exit_lane"),
    "empty_alley": ("The alley is empty except for old scuffs that nobody chose to follow.", "background"),
    "shutter_gap_abandoned": ("The lit shutter gap remains open with the trace ending abruptly at its edge.", "foreground"),
    "weather_rumor_exit": ("Rain arrows painted near the shutter point toward a sheltered route out.", "exit_lane"),
    "empty_alley_refused": ("The traces remain untouched in an otherwise empty alley after the search was refused.", "background"),
    "opened_follow_exit": ("The opened shutter reveals a narrow follow route with dust still settling beyond it.", "exit_lane"),
    "returned_cart": ("The estate cart is packed for return, its rejected pieces wrapped separately.", "background"),
    "quarantined_lot": ("The estate lot sits behind a quarantine cord until its missing history can be resolved.", "background"),
    "provenance_marks_abandoned": ("The marks remain under the lamp beside an unfinished ledger comparison.", "foreground"),
    "economy_provenance_public_service": ("A public provenance card lists the matched marks and the appraisal terms offered for the lot.", "service_lane"),
    "quarantined_lot_refused": ("The refused lot remains quarantined with its estate sheet folded shut.", "background"),
    "displayed_lot": ("Matched estate pieces are displayed with their history cards facing the room.", "center"),
    "withdrawn_stock": ("The serial-checked object has been pulled from sale and sealed in the back rack.", "background"),
    "waiting_hold": ("The held object waits beside an incomplete serial sheet, unable to move without a match.", "service_lane"),
    "hold_object_abandoned": ("The unsealed hold and carbon copy remain exactly where the serial check stopped.", "foreground"),
    "serial_sweep_hold": ("An official sweep tag seals the held object and makes the paper trail public.", "service_lane"),
    "waiting_hold_refused": ("The refused serial hold sits under the lamp with no clerk's signature.", "service_lane"),
    "disclosed_hold": ("The sealed hold is displayed with its matching serial record, leaving no hidden swap.", "center"),
    "closed_shutters": ("Sal's shutters are down and the unfinished bench explains why business ended early.", "background"),
    "private_appraisal_abandoned": ("The privacy screen remains half-closed around tools left mid-appraisal.", "foreground"),
    "service_appraisal_public_service": ("The appraisal sheet is posted at the counter, turning a private offer into a visible service.", "service_lane"),
    "private_appraisal_refused": ("The screen is closed and the untouched appraisal tools record the refusal.", "background"),
    "reopened_counter": ("The repaired job sits beside an open register; Sal's counter is plainly back in business.", "service_lane"),
}

# Physical silhouettes for Package A aftermath props. These are deliberately
# keyed per authored object; lifecycle words such as "aftermath" or "refused"
# must never decide what the player sees in an unlabeled room.
AFTERMATH_ICONS = {
    "angry_queue": "patron_talk",
    "sold_out_counter": "room_surface",
    "number_board_abandoned": "room_display",
    "economy_stock_public_service": "paper_note",
    "sold_out_counter_refused": "room_surface",
    "celebration_layout": "room_surface",
    "police_hold": "paper_note",
    "watched_aisle": "room_route",
    "suspect_object_abandoned": "room_storage",
    "evidence_sweep_hold": "paper_note",
    "watched_aisle_refused": "room_route",
    "quiet_recovery": "room_storage",
    "private_darkness": "room_hazard",
    "flicker_lockout": "room_signal",
    "cooler_circuit_abandoned": "jammed_machine",
    "surveillance_rumor_route": "security_camera",
    "flicker_lockout_refused": "room_signal",
    "lit_service": "jammed_machine",
    "quarantined_section": "room_barrier",
    "closed_aisles": "room_barrier",
    "discrepancy_shelf_abandoned": "room_storage",
    "economy_inventory_public_service": "paper_note",
    "closed_aisles_refused": "room_barrier",
    "reopened_sections": "room_storage",
    "ring_relocated": "room_route",
    "ring_dispersed": "room_route",
    "lookout_marker_abandoned": "room_signal",
    "street_stake_recovered": "trunk_offer",
    "ring_dispersed_refused": "room_route",
    "ring_continues": "room_route",
    "diverted_patrol": "room_vehicle",
    "watched_route": "room_vehicle",
    "stacked_cover_abandoned": "room_barrier",
    "cruiser_pressure_route": "room_route",
    "watched_route_refused": "room_route",
    "cruiser_departed": "room_vehicle",
    "brokered_exit": "paper_note",
    "buyer_control": "room_surface",
    "auth_station_abandoned": "paper_note",
    "economy_fence_public_service": "paper_note",
    "buyer_control_refused": "room_storage",
    "verified_stall": "room_surface",
    "erased_rumor_exit": "side_door",
    "empty_alley": "room_route",
    "shutter_gap_abandoned": "side_door",
    "weather_rumor_exit": "room_route",
    "empty_alley_refused": "room_route",
    "opened_follow_exit": "side_door",
    "returned_cart": "room_vehicle",
    "quarantined_lot": "room_barrier",
    "provenance_marks_abandoned": "paper_note",
    "economy_provenance_public_service": "paper_note",
    "quarantined_lot_refused": "room_storage",
    "displayed_lot": "room_display",
    "withdrawn_stock": "room_storage",
    "waiting_hold": "paper_note",
    "hold_object_abandoned": "paper_note",
    "serial_sweep_hold": "paper_note",
    "waiting_hold_refused": "paper_note",
    "disclosed_hold": "room_display",
    "closed_shutters": "room_barrier",
    "private_appraisal": "room_surface",
    "private_appraisal_abandoned": "room_barrier",
    "service_appraisal_public_service": "paper_note",
    "private_appraisal_refused": "room_barrier",
    "reopened_counter": "room_surface",
}

OBJECT_ICONS = {
    "serial_station": "paper_note",
}

# Scenario-level presentation copy is explicit too. These lines replace the
# conversion-era transition, prompt, and service templates with observations a
# player can verify in the room. Keys mirror the authored phase/state vocabulary
# so this remains a reviewable content manifest rather than a prose generator.
SCENARIO_PRESENTATION = {
    "corner_store_lotto_fever": {
        "exits": {
            "arrival": "The taped door path remains open beyond the restless ticket line.",
            "work": "The door route stays clear while the lit number board holds the crowd's attention.",
            "resolution": "The crossed-out queue marks stop short of the unobstructed front door.",
        },
        "prompts": {
            "queue_rail": "Read the place marks, hold your spot, or decline before the line closes around you.",
            "corner_store_lotto_fever_exit": "Step past the end of the queue and leave through the taped door path.",
            "number_board": "Compare the called number with the public board before choosing what to do.",
        },
        "arrival_reduced": "The queue is already bent around the stock rack, leaving the taped door path open.",
        "arrival_stage": "Customers compress around the place rail as the unlit board waits above them.",
        "work_feedback": "The lit number board and marked queue order turn the crowded aisle into a public draw.",
        "resolution_feedback": "The counter and queue retain the marks left by the completed lottery rush.",
        "work_transition": "The number board lights above the counter and the queue pivots toward it.",
        "work_reduced": "The lit digits and fixed place marks now make the draw readable from the aisle.",
        "resolution_transition": "Crossed-out places, the posted digits, and the counter display preserve how the draw ended.",
        "resolution_label": "The draw leaves its marks",
    },
    "corner_store_aftermath": {
        "exits": {
            "arrival": "The marked door route skirts the boarded pane and the loose evidence.",
            "work": "A clear strip beside the evidence station still reaches the front door.",
            "resolution": "The finished evidence lane leaves an unobstructed path out of the store.",
        },
        "prompts": {
            "boarded_glass": "Trace the break around the boards, secure the find, or leave it untouched.",
            "corner_store_aftermath_exit": "Follow the marked strip past the glass and out the front door.",
            "suspect_object": "Inspect the isolated object and decide whether to preserve its trace.",
        },
        "arrival_reduced": "Boards narrow the aisle, but the loose object and door route remain separately marked.",
        "arrival_stage": "The officer moves along the boards while the loose object remains isolated from the door path.",
        "work_feedback": "A lit evidence station now separates the recovered object from the repaired aisle.",
        "resolution_feedback": "The last trace tag and repaired glass preserve the result of the officer's search.",
        "work_transition": "A counter lamp isolates the suspect object as the officer clears an evidence lane.",
        "work_reduced": "The object rests under the lamp with a clear route between the station and the door.",
        "resolution_transition": "The boards, trace bag, and officer's floor marks show how the recovery concluded.",
        "resolution_label": "The evidence lane settles",
    },
    "corner_store_dead_shift": {
        "exits": {
            "arrival": "Glow tape leads around the dark cooler to the front door.",
            "work": "The taped route stays outside the open breaker and the cooler work area.",
            "resolution": "Steady or flickering, the lights still reveal a clear path to the door.",
        },
        "prompts": {
            "breaker_panel": "Read the warm breaker cover, isolate the feed, or leave the dark aisle alone.",
            "corner_store_dead_shift_exit": "Use the glow-taped route without crossing the electrical work.",
            "cooler_circuit": "Examine the exposed cooler circuit before attempting a safe restart.",
        },
        "arrival_reduced": "Emergency light separates the warm breaker cover from the open door lane.",
        "arrival_stage": "The cooler falls silent as the breaker flicker divides the lit counter from the dark aisle.",
        "work_feedback": "An open panel and work lamp make the failed cooler feed the center of the shift.",
        "resolution_feedback": "Light, lockout tags, and cooler noise show exactly where the repair ended.",
        "work_transition": "The breaker cover opens and a work light picks out the failed cooler feed.",
        "work_reduced": "The bad circuit is exposed under a steady lamp while the customer aisle remains dark.",
        "resolution_transition": "The breaker tag, cooler doors, and counter lights record whether service returned.",
        "resolution_label": "The power state remains",
    },
    "corner_store_inventory_night": {
        "exits": {
            "arrival": "The front path threads past the count cage without crossing loose sheets.",
            "work": "The signed customer lane stays open beside the active recount.",
            "resolution": "Gates and count tags leave the door route legible after the tally ends.",
        },
        "prompts": {
            "count_cage": "Review the open count sections, begin the tally, or refuse the recount.",
            "corner_store_inventory_night_exit": "Take the customer lane around the cage and out the door.",
            "discrepancy_shelf": "Match the separated shelf tags before closing any stock section.",
        },
        "arrival_reduced": "Count cages occupy two aisles while a signed customer path remains open.",
        "arrival_stage": "Rolling cages settle beside open sheets as the clerk begins calling shelf sections.",
        "work_feedback": "A closed cage section and two rows of tags narrow the remaining discrepancy.",
        "resolution_feedback": "The final gate positions and signed tally sheets record the night's count.",
        "work_transition": "One cage section closes and the unmatched shelf tags move under the work light.",
        "work_reduced": "A sealed cage section now sits beside two distinct rows of count tags.",
        "resolution_transition": "Signed sections, loose tags, and aisle gates preserve the final state of the recount.",
        "resolution_label": "The count closes visibly",
    },
    "back_alley_street_craps": {
        "exits": {
            "arrival": "A wall-side gap remains open beyond the chalk ring and waiting shooters.",
            "work": "The lookout marker faces the ring while the wall route stays outside the throw.",
            "resolution": "Scuffed chalk ends before the marked gap leading out of the alley.",
        },
        "prompts": {
            "chalk_ring": "Read the heel marks, set the point, or walk away before joining the throw.",
            "back_alley_street_craps_exit": "Leave along the wall without stepping through the dice ring.",
            "lookout_marker": "Check the curb signal before deciding whether the street game continues.",
        },
        "arrival_reduced": "The chalk circle, curb backstop, and wall-side exit are plainly separated.",
        "arrival_stage": "Shooters gather outside the chalk while a bottle-cap signal waits on the curb.",
        "work_feedback": "A fresh point and upright lookout marker make the alley game live.",
        "resolution_feedback": "Chalk, dice marks, and retreating footprints retain the outcome of the throw.",
        "work_transition": "Fresh point marks appear as the lookout bottle cap turns upright.",
        "work_reduced": "The marked point and raised warning signal now define the live game.",
        "resolution_transition": "The final chalk, footprints, and lookout marker show whether the game held or scattered.",
        "resolution_label": "The alley keeps the score",
    },
    "back_alley_cruiser_parked": {
        "exits": {
            "arrival": "The wall-hugging route remains outside the cruiser's white beam.",
            "work": "Shifted crates narrow the cover lane but do not close the wall exit.",
            "resolution": "Tire marks and the last beam angle leave the safe way out readable.",
        },
        "prompts": {
            "cruiser_beam": "Study the patrol sweep, time a crossing, or stay behind cover.",
            "back_alley_cruiser_parked_exit": "Follow the wall beyond the edge of the cruiser beam.",
            "stacked_cover": "Judge the crate stack against the patrol sightline before moving it.",
        },
        "arrival_reduced": "A hard cruiser beam cuts the doorway while stacked crates shelter the wall route.",
        "arrival_stage": "The patrol light sweeps from the doorway toward a low stack of crate cover.",
        "work_feedback": "Repositioned crates now divide the sheltered wall from the exposed alley center.",
        "resolution_feedback": "The final beam angle and cover stack show whether the patrol moved on.",
        "work_transition": "The cover stack shifts across one beam just as the patrol turns toward another.",
        "work_reduced": "Crates now shelter the right-hand route, leaving the open ground fully exposed.",
        "resolution_transition": "The crate position, chalk warning, and tire tracks reveal where the patrol pressure ended.",
        "resolution_label": "The patrol leaves a route",
    },
    "back_alley_fence_night": {
        "exits": {
            "arrival": "A painted arrow keeps the rotating lots away from the alley exit.",
            "work": "The checking station stays inside the goods lane and leaves the arrowed route clear.",
            "resolution": "Lot marks stop at the painted path leading out of the stall.",
        },
        "prompts": {
            "goods_lot": "Separate the conflicting marks, choose a lot to check, or refuse the sale.",
            "back_alley_fence_night_exit": "Follow the painted arrow around the goods tables.",
            "auth_station": "Use the lamp and ledger to test the contested crate's visible history.",
        },
        "arrival_reduced": "Three marked lots face one open checking station beside the painted exit arrow.",
        "arrival_stage": "Buyers circle three separated bundles while the ledger lamp remains unclaimed.",
        "work_feedback": "The contested crate occupies the checking station under the rotating buyer's gaze.",
        "resolution_feedback": "Tags, ledger marks, and empty hooks preserve the result of the night sale.",
        "work_transition": "The buyer clears the lamp and the contested crate moves beside the open ledger.",
        "work_reduced": "One lot now rests under the authentication lamp with its chalk mark visible.",
        "resolution_transition": "Ledger pages, buyer tags, and separated lots show how the sale was settled.",
        "resolution_label": "The lots show their terms",
    },
    "back_alley_nothing_moving": {
        "exits": {
            "arrival": "The clear wall route avoids the wet print and dragged crate line.",
            "work": "The shutter gap sits beyond the trace work while the side exit remains untouched.",
            "resolution": "Dust and scuffs end short of the marked way out of the alley.",
        },
        "prompts": {
            "three_traces": "Compare the wet print, drag line, and broken seal, or leave the trail cold.",
            "back_alley_nothing_moving_exit": "Take the wall-side route without disturbing the traces.",
            "shutter_gap": "Inspect the dust below the shutter before opening the route it suggests.",
        },
        "arrival_reduced": "Three separate traces cross the shutter area beside an undisturbed exit lane.",
        "arrival_stage": "A low light catches a wet print, a crate scrape, and a broken seal at the shutters.",
        "work_feedback": "The compared traces now converge at one dusty gap beneath the shutter.",
        "resolution_feedback": "The remaining dust and shutter position show how far the silent search went.",
        "work_transition": "A low lamp joins the wet print and drag line at the dusty shutter gap.",
        "work_reduced": "The compared scuffs now form one readable path to the bottom of the shutter.",
        "resolution_transition": "The shutter opening, brushed dust, and remaining prints preserve where the search finished.",
        "resolution_label": "The trace ends at the shutter",
    },
    "pawn_shop_estate_lot_day": {
        "exits": {
            "arrival": "The street door remains reachable around the mixed estate cart.",
            "work": "Appraisal sections stay behind the service line and away from the front path.",
            "resolution": "Wrapped or displayed, the estate pieces leave the shop door clear.",
        },
        "prompts": {
            "estate_cart": "Separate the keepsakes from ordinary stock, or decline the appraisal.",
            "pawn_shop_estate_lot_day_exit": "Walk around the cart and leave by the street door.",
            "provenance_marks": "Compare the faded marks with the estate sheet before valuing the lot.",
        },
        "arrival_reduced": "The mixed cart occupies the appraisal area without blocking the street door.",
        "arrival_stage": "Keepsakes and shop stock shift apart as the appraiser opens the estate sheet.",
        "work_feedback": "Signed cart sections bring the faded provenance marks under the appraisal lamp.",
        "resolution_feedback": "Wrapping, display cards, and the sorted cart preserve the lot's disposition.",
        "work_transition": "The appraiser divides the cart as faded marks move beneath the ledger lamp.",
        "work_reduced": "Signed cart sections now separate display pieces from returns and held stock.",
        "resolution_transition": "History cards, wrapping, and the final cart position show what became of the estate lot.",
        "resolution_label": "The estate lot is sorted",
    },
    "pawn_shop_serial_check_day": {
        "exits": {
            "arrival": "The taped hold zone ends before the open path to the shop door.",
            "work": "The serial lamp faces away from the clear customer lane.",
            "resolution": "Filed records and the sealed hold remain clear of the exit.",
        },
        "prompts": {
            "serial_station": "Light the stamped digits, make a paper copy, or decline the check.",
            "pawn_shop_serial_check_day_exit": "Pass the edge of the hold tape and use the shop door.",
            "hold_object": "Compare the unwrapped object with the carbon copy before sealing it.",
        },
        "arrival_reduced": "The serial desk and taped hold occupy one side of the open customer route.",
        "arrival_stage": "The records clerk lights the serial desk while the wrapped object waits inside the tape.",
        "work_feedback": "The unwrapped stamp and fresh carbon copy now share the guarded hold station.",
        "resolution_feedback": "Filed paper, shelf position, and the state of the seal document the completed check.",
        "work_transition": "The records clerk unwraps the held object and brings its serial beneath the lamp.",
        "work_reduced": "The stamped digits and carbon copy now sit together inside the hold line.",
        "resolution_transition": "The seal, filed copy, and object's final shelf show how the hold concluded.",
        "resolution_label": "The serial hold is recorded",
    },
    "pawn_shop_sals_mood": {
        "exits": {
            "arrival": "The front door stays clear despite the repairs spilling off Sal's bench.",
            "work": "The active repair remains at the bench while the customer path reaches the door.",
            "resolution": "The finished job and appraisal screen leave a readable route out of Sal's shop.",
        },
        "prompts": {
            "unfinished_jobs": "Read the repair bench, finish useful work, or leave Sal to the backlog.",
            "pawn_shop_sals_mood_exit": "Use the open path between the counter and front door.",
            "private_appraisal": "Inspect the screened tools before accepting a quieter appraisal.",
        },
        "arrival_reduced": "Three unfinished repairs crowd the bench while the front-door path remains open.",
        "arrival_stage": "Sal sorts the crowded bench without opening the curtained appraisal behind him.",
        "work_feedback": "A finished repair reaches the counter as Sal turns toward the private tools.",
        "resolution_feedback": "The register, shutters, and cleared bench show how Sal answered the work.",
        "work_transition": "One repaired piece moves to the counter and Sal turns toward the appraisal screen.",
        "work_reduced": "The completed job now rests apart from the backlog beside the private tools.",
        "resolution_transition": "The shutter, register, and appraisal screen make Sal's final response visible.",
        "resolution_label": "Sal answers through the shop",
    },
}

SERVICE_DISABLED_COPY = {
    "angry_queue": "Crossed-out place marks have left this ticket service without a trusted order.",
    "sold_out_counter": "The empty tray and overturned sign show there are no tickets left to serve.",
    "number_board_abandoned": "The half-checked board cannot support another draw until its digits are verified.",
    "economy_stock_public_service": "The posted shortage notice replaces the usual counter service for this outcome.",
    "sold_out_counter_refused": "The refused request did not preserve stock; the bare counter has nothing to offer.",
    "police_hold": "The signed hold prevents the evidence shelf from returning to ordinary use.",
    "watched_aisle": "The officer's sightline marks keep the repaired aisle under observation.",
    "suspect_object_abandoned": "Unbagged evidence makes this station unsafe to reopen.",
    "evidence_sweep_hold": "The official sweep tag closes the station while the hold remains active.",
    "watched_aisle_refused": "A refusal tag leaves the open aisle watched and unavailable for service.",
    "private_darkness": "The unpowered coolers have closed ordinary night-counter service.",
    "flicker_lockout": "The breaker lockout keeps the cooler lane closed.",
    "cooler_circuit_abandoned": "An exposed, unattended circuit prevents the counter from reopening.",
    "surveillance_rumor_route": "The warning at the dead circuit redirects attention outside instead of restoring service.",
    "flicker_lockout_refused": "The signed refusal leaves the unstable circuit isolated.",
    "quarantined_section": "The failed count has put this stock section behind a rope.",
    "closed_aisles": "Unresolved sheets keep the folding aisle gates shut.",
    "discrepancy_shelf_abandoned": "Loose, unmatched tags prevent the inventory desk from signing off.",
    "economy_inventory_public_service": "The public shortage notice stands in place of normal inventory access.",
    "closed_aisles_refused": "The declined recount leaves fewer shelves available behind the gates.",
    "ring_relocated": "The relocated chalk ring no longer offers the street-side game found here.",
    "ring_dispersed": "Smeared chalk and empty pavement leave no active game to join.",
    "lookout_marker_abandoned": "The fallen warning marker has suspended the unfinished point.",
    "street_stake_recovered": "The tied stake is held for its owner, not open for another wager.",
    "ring_dispersed_refused": "Untouched dice beside a scuffed ring record that this throw was declined.",
    "diverted_patrol": "The departing tire marks leave no patrol here to engage.",
    "watched_route": "The fixed cruiser beam keeps the wall route unavailable.",
    "stacked_cover_abandoned": "Half-built cover exposes the work lane and closes further passage.",
    "cruiser_pressure_route": "The chalk detour replaces access through the beam-covered route.",
    "watched_route_refused": "The untouched cover leaves the refused diversion under direct observation.",
    "brokered_exit": "The empty hooks show the disputed goods have already left by another route.",
    "buyer_control": "Buyer tags have removed every bundled lot from open negotiation.",
    "auth_station_abandoned": "An unchecked lot beside the open ledger prevents a clean new appraisal.",
    "economy_fence_public_service": "The posted price card has replaced the private terms offered at this station.",
    "buyer_control_refused": "The refused lot has been tagged and separated from anything still for sale.",
    "erased_rumor_exit": "The brushed-away trail leaves no evidence service to continue.",
    "empty_alley": "Old scuffs alone provide no active lead to follow.",
    "shutter_gap_abandoned": "The abruptly ending trace leaves the open gap unsafe to use as a service route.",
    "weather_rumor_exit": "Painted rain arrows now direct traffic away from this shutter station.",
    "empty_alley_refused": "The untouched traces record that this search was declined.",
    "returned_cart": "Wrapped returns have closed appraisal on this estate lot.",
    "quarantined_lot": "Missing provenance keeps the cordoned pieces out of service.",
    "provenance_marks_abandoned": "An unfinished ledger comparison prevents the lot from being offered.",
    "economy_provenance_public_service": "The posted history card replaces any private appraisal at this counter.",
    "quarantined_lot_refused": "The folded estate sheet leaves the declined lot in quarantine.",
    "withdrawn_stock": "The sealed back-rack object has been removed from sale.",
    "waiting_hold": "An incomplete serial sheet keeps the held object from moving.",
    "hold_object_abandoned": "The unsealed object and unfinished copy leave this hold unresolved.",
    "serial_sweep_hold": "An official sweep seal suspends ordinary access to the held object.",
    "waiting_hold_refused": "Without a clerk's signature, the declined serial hold cannot proceed.",
    "closed_shutters": "The lowered shutters show Sal ended business before the repair was settled.",
    "private_appraisal": "The curtained offer remains private and unavailable without Sal's attention.",
    "private_appraisal_abandoned": "Tools left behind a half-closed screen cannot start another appraisal.",
    "service_appraisal_public_service": "The posted sheet has replaced the private offer previously made here.",
    "private_appraisal_refused": "The closed screen and untouched tools preserve the refused appraisal.",
}

ACTION_STATE_COPY = {
    "acted_ignore_delivery": "You leave the dolly parked; mismarked cartons continue to occupy the sorting side of the aisle.",
    "acted_refuse_sort": "You refuse the sort. The cartons remain strapped to the dolly beside Ada's return paperwork.",
    "acted_inspect_manifest": "You spread the damaged manifest beneath the work light, exposing the mismatched destination lines.",
}

DELIVERY_REVISIT_COPY = {
    "broken": "Packing paper spills from the torn carton; Ada has closed the tip counter and blocked the route toward the club.",
    "refused": "The sealed return pallet sits under Ada's eye, with the tip counter and club route both closed.",
    "interrupted": "The manifest remains under the abandoned dolly; the tip counter is open, but unloading still blocks the club route.",
}

DELIVERY_RESOLUTION_COPY = "Ada's shelf, return paperwork, and the remaining cartons show how the delivery ended."

STREET_CRAPS_EVENT_SUBSCRIPTIONS = [
    {
        "fact_type": "event_result",
        "payload_equals": {
            "event_id": "scenario_street_craps_circle",
            "choice_id": "read_the_circle",
            "resolution_id": "read_the_circle",
            "resolved": True,
            "ok": True,
        },
        "handler": "publish_feedback",
        "inputs": {"message": "The shooters' explanation leaves the stake line and wall exit plainly marked."},
    },
    {
        "fact_type": "event_result",
        "payload_equals": {
            "event_id": "scenario_street_craps_circle",
            "choice_id": "join_the_circle",
            "resolution_id": "read_the_circle",
            "resolved": True,
            "ok": True,
        },
        "handler": "publish_feedback",
        "inputs": {"message": "The shooters open the chalk ring and point out where the line cash moves."},
    },
]


def main():
    package = json.loads(PACKAGE.read_text(encoding="utf-8"))
    used = set()
    for scenario in package["scenarios"]:
        presentation = SCENARIO_PRESENTATION.get(scenario["scenario_id"])
        if scenario["scenario_id"] == "back_alley_street_craps":
            scenario.setdefault("authoring", {}).setdefault("references", {})["events"] = ["scenario_street_craps_circle"]
            subscriptions = scenario["sequence"].setdefault("fact_subscriptions", [])
            subscriptions[:] = [row for row in subscriptions if not (
                row.get("fact_type") == "event_result"
                and row.get("payload_equals", {}).get("event_id") == "scenario_street_craps_circle"
                and row.get("payload_equals", {}).get("resolution_id") == "read_the_circle"
            )]
            subscriptions.extend(STREET_CRAPS_EVENT_SUBSCRIPTIONS)
        for phase in scenario["sequence"]["phase_graph"]["phases"]:
            if scenario["scenario_id"] == "corner_store_delivery_day" and phase["id"] == "resolution":
                for op in phase.get("transition_ops", []):
                    if op.get("op") == "feedback":
                        op["message"] = DELIVERY_RESOLUTION_COPY
            if presentation:
                phase["exit_prompt"] = presentation["exits"][phase["id"]]
                if phase["id"] == "work":
                    phase["arrival_feedback"] = presentation["work_feedback"]
                elif phase["id"] == "resolution":
                    phase["arrival_feedback"] = presentation["resolution_feedback"]
                    phase["label"] = presentation["resolution_label"]
                for op in phase.get("interaction_ops", []):
                    interaction = op.get("interaction")
                    if not interaction:
                        continue
                    stable_id = interaction.get("stable_object_id", "")
                    if stable_id in presentation["prompts"]:
                        interaction["prompt"] = presentation["prompts"][stable_id]
                for op in phase.get("transition_ops", []):
                    message = op.get("message", "")
                    reduced = op.get("reduced_motion_message", "")
                    if phase["id"] == "arrival" and op.get("op") == "stage":
                        op["message"] = presentation["arrival_stage"]
                    elif phase["id"] == "work" and message.startswith("The room visibly shifts into the decisive second step."):
                        op["message"] = presentation["work_transition"]
                    elif phase["id"] == "resolution" and message.startswith("The outcome is recorded once"):
                        op["message"] = presentation["resolution_transition"]
                    if reduced.startswith("The changed fixture is already in its new position."):
                        op["reduced_motion_message"] = presentation["arrival_reduced" if phase["id"] == "arrival" else "work_reduced"]
            for op in phase.get("interaction_ops", []):
                interaction = op.get("interaction")
                if not interaction:
                    continue
                for action in interaction.get("available_actions", []):
                    if scenario["scenario_id"] == "back_alley_street_craps" and action.get("id") == "read_ring":
                        action["handler"] = "event_bridge"
                        action["inputs"] = {
                            "event_id": "scenario_street_craps_circle",
                            "resolution_id": "read_the_circle",
                            "message": "A shooter steps into the chalk and explains the stake line face to face.",
                        }
                        action["label"] = "Ask how the chalk ring works"
                    elif scenario["scenario_id"] == "corner_store_delivery_day" and action.get("id") == "request_stock_check":
                        action["inputs"]["message"] = "Ada opens the manifest and talks through the mismatched delivery with you."
                    inputs = action.get("inputs", {})
                    state = inputs.get("state", "")
                    if state in ACTION_STATE_COPY:
                        inputs["message"] = ACTION_STATE_COPY[state]
            for family, payload_key in (("scene_ops", "object"), ("actor_ops", "actor")):
                for op in phase.get(family, []):
                    payload = op.get(payload_key)
                    if not payload:
                        continue
                    stable_id = op["stable_object_id"]
                    if stable_id not in COPY:
                        raise SystemExit(f"missing authored copy for {stable_id}")
                    description, variants, zone = COPY[stable_id]
                    payload["description"] = description
                    payload["description_variants"] = variants
                    if family == "scene_ops" and stable_id in OBJECT_ICONS:
                        payload["icon_key"] = OBJECT_ICONS[stable_id]
                    if zone and not payload.get("zone_id"):
                        payload["zone_id"] = zone
                    used.add(stable_id)
        for aftermath_id, aftermath in scenario["sequence"].get("aftermath", {}).items():
            if scenario["scenario_id"] == "corner_store_delivery_day" and aftermath_id in DELIVERY_REVISIT_COPY:
                aftermath["revisit_feedback"] = DELIVERY_REVISIT_COPY[aftermath_id]
            aftermath_visual_id = ""
            for op in aftermath.get("scene_ops", []) + aftermath.get("actor_ops", []):
                payload = op.get("object") or op.get("actor")
                stable_id = op["stable_object_id"]
                if stable_id in COPY:
                    description, variants, zone = COPY[stable_id]
                    zone = payload.get("zone_id") or zone or "background"
                else:
                    if stable_id not in AFTERMATH_COPY:
                        raise SystemExit(f"missing aftermath copy for {stable_id}")
                    description, zone = AFTERMATH_COPY[stable_id]
                    variants = {}
                payload["description"] = description
                payload["description_variants"] = variants
                payload["zone_id"] = zone
                if "object" in op and stable_id in AFTERMATH_ICONS:
                    payload["icon_key"] = AFTERMATH_ICONS[stable_id]
                used.add(stable_id)
                if stable_id in SERVICE_DISABLED_COPY:
                    aftermath_visual_id = stable_id
            if aftermath_visual_id:
                for op in aftermath.get("service_ops", []):
                    service = op.get("object")
                    if service and not service.get("enabled", True):
                        service["disabled_reason"] = SERVICE_DISABLED_COPY[aftermath_visual_id]
    unused = sorted((set(COPY) | set(AFTERMATH_COPY)) - used)
    if unused:
        raise SystemExit(f"unused authored copy: {unused}")
    PACKAGE.write_text(json.dumps(package, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"PACKAGE_A_AUTHORED objects={len(used)}")


if __name__ == "__main__":
    main()
