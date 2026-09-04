import json
from pathlib import Path


PACKAGE = Path("data/environments/scenario_sequences/env06_7_shops_streets.json")

# Hand-authored room-reading copy. The script only installs and checks these
# lines; it never manufactures prose from ids, labels, or templates.
COPY = {
    "delivery_cartons": ("The cartons are stacked by mismatched labels; sorting them would clear the clerk's work path.", {"center": "The cartons now fill the sorting spot, close enough for every damaged label to be compared.", "package_a_delivery_cartons_wait": "The cartons wait off the aisle in a neat stack while the clerk holds for your decision."}, None),
    "mismarked_crate": ("A torn label hides the crate's destination, which is why the rest of the delivery cannot be trusted yet.", {"crushed_corner": "A crushed corner exposes enough of the old label to trace where the crate belongs.", "foreground": "The damaged crate has been pulled forward as the clearest piece of evidence in the shipment.", "manifest_open": "The open manifest and the crate's torn label now tell the same story."}, None),
    "delivery_event_gate": ("A damaged manifest lies open at the work station; reading it will start a real stock conversation.", {}, None),
    "delivery_exit": ("The front-door lane is deliberately open, so the delivery never traps anyone in the store.", {}, None),
    "delivery_clerk": ("The delivery clerk checks the manifest twice, unwilling to shelve anything under the wrong name.", {"delivery_clerk_work": "The clerk has moved to the open work side of the shelf, keeping every label in view.", "work": "The clerk works the delivery in public instead of waving the mismatch through.", "checking_labels": "The clerk works down the exposed labels, waiting for the mismatched carton to surface.", "checking_manifest": "The clerk has returned to the manifest, keeping the stock decision open.", "awaiting_choice": "The clerk has stopped moving boxes and is plainly waiting for your answer."}, "background"),
    "delivery_runner": ("The runner braces the dolly and watches the aisle, ready to move whatever the manifest clears.", {"left": "The runner holds the left edge of the aisle so the marked exit stays open.", "delivery_runner_route": "The runner follows the dolly route between the cartons and verification shelf.", "shifting_cartons": "The runner rolls the mismarked cartons into the sorting spot without closing the front lane.", "holding_twine": "The runner holds fresh twine beside the verified shelf, ready to bind the corrected lot.", "waiting_on_choice": "The runner rests both hands on the dolly while the stock choice hangs in the air."}, "left"),
    "sorting_shelf": ("The cleared shelf pairs twine with the manifest, making the corrected lot easy to verify.", {"event_pending": "The shelf is staged and the manifest is checked; the clerk's stock decision is ready to open."}, None),
    "queue_rail": ("Handwritten place marks crowd the rail; holding a spot makes the draw easier to follow but harder to leave casually.", {"center": "The queue rail has been pulled into the open so every claimed place can be seen.", "places_marked": "Fresh marks fix the queue order, and the regulars are watching who respects it.", "left": "The rail is back against the wall with the final queue order still visible."}, None),
    "number_board": ("The number board is dark enough that nobody can honestly claim a result yet.", {"active_station": "The board is lit for the draw, drawing every eye in the store.", "verified_digits": "The posted digits have been checked in public and can no longer be quietly changed."}, None),
    "corner_store_lotto_fever_exit": ("A taped path to the door stays clear beyond the restless lottery line.", {}, None),
    "lotto_regular": ("A lottery regular studies the board and the queue, making any sleight of hand feel conspicuous.", {"service_lane": "The regular has edged up beside the counter for a clean view of the draw.", "watching_draw": "The regular watches the lit digits without blinking.", "watch": "The regular is openly keeping watch, raising the cost of anything that looks crooked."}, None),
    "boarded_glass": ("Fresh boards cover the broken pane; their hurried nail pattern shows the store closed in a rush.", {"center": "The boarded pane is now the room's center of attention, with the break pattern exposed.", "foreground": "The boards have been pulled close enough to trace where the impact began."}, None),
    "suspect_object": ("A small object sits where the broken glass was swept aside, still too obscured to identify safely.", {"active_station": "The object is isolated under the counter light for a careful look.", "bagged_for_trace": "The object is sealed in a trace bag, preserving what it may reveal later."}, None),
    "corner_store_aftermath_exit": ("The marked door path avoids both the broken glass and the evidence station.", {}, None),
    "plainclothes_officer": ("A plainclothes officer watches the repair work rather than the customers, inviting careful cooperation.", {"service_lane": "The officer has moved beside the evidence station to see the recovery clearly.", "left": "The officer stands off to the side with the bagged object in view."}, "background"),
    "breaker_panel": ("The breaker panel hums behind a warm cover; isolating it would stop the cooler from worsening.", {"center": "The suspect breaker has been brought into the work area where its feed can be isolated.", "open_breaker": "The breaker cover is open and the bad circuit is plainly separated from the live rows."}, None),
    "cooler_circuit": ("Condensation beads around a dark cooler circuit, warning that the stock will not keep forever.", {"active_station": "The cooler circuit is exposed under a work light for a safe restart.", "circuit_isolated": "The failed circuit is tagged and isolated; the rest of the cooler can be handled without guessing."}, None),
    "corner_store_dead_shift_exit": ("Glow tape marks a clear route out even with half the store dark.", {}, None),
    "night_clerk": ("The night clerk listens to the cooler and keeps one hand near the emergency light.", {"service_lane": "The clerk waits beside the breaker lane, leaving room for someone to work.", "holding_flashlight": "The clerk holds a steady flashlight on the isolated circuit."}, "background"),
    "count_cage": ("Open count sheets and separated stock show that tonight's inventory has not balanced.", {"center": "The count cage sits in the open with each section ready to be checked aloud.", "right": "The cage has been shifted beside the discrepancy shelf for a direct recount.", "section_counted": "One cage section is sealed and initialed, narrowing the remaining discrepancy."}, None),
    "discrepancy_shelf": ("A shelf of duplicate tags marks the stock nobody is willing to sign off yet.", {"active_station": "The discrepancy shelf is lit for a second count.", "discrepancy_tags": "Matched and unmatched tags now hang in separate rows, making the short lot obvious."}, None),
    "corner_store_inventory_night_exit": ("The door lane stays clear of the count cage and its loose paperwork.", {}, None),
    "inventory_clerk": ("The inventory clerk guards the pencil marks, knowing a careless recount could hide the shortage.", {"package_a_inventory_clerk_work": "The clerk moves to the signed work mark beside the discrepancy shelf.", "service_lane": "The clerk takes the counter side of the cage and leaves the customer lane open.", "work": "The clerk keeps working the visible count instead of closing the books early.", "recounting_shelf": "The clerk calls each shelf tag aloud and waits for the count to match."}, "background"),
    "chalk_ring": ("A scuffed chalk circle and heel marks show where the street dice have been landing.", {"center": "The chalk ring has been redrawn in the center where every throw can be seen.", "chalk_point_ring": "Fresh point marks ring the layout, recording how this game has been running."}, None),
    "lookout_marker": ("A bottle cap on the curb is the lookout's signal; when it moves, the game is no longer safe.", {"active_station": "The lookout marker has been set upright where the shooter can read it.", "foreground": "The marker has been kicked forward into everyone's sightline.", "warning_active": "The marker is turned to warning, making another throw a conspicuous risk."}, None),
    "back_alley_street_craps_exit": ("A gap beside the chalk ring remains wide enough to leave without crossing the game.", {}, None),
    "street_shooter": ("The shooter palms the dice and listens for the lookout before setting a point.", {"alley_background_right": "The shooter waits against the back-right wall, leaving the chalk ring readable.", "service_lane": "The shooter has stepped to the edge of the ring so the alley route stays open.", "setting_dice": "The shooter squares the dice in the chalk, ready for a visible throw.", "watch": "The shooter pauses to watch the warning marker instead of rolling blind.", "right": "The shooter has backed off to the right, leaving the marked exit clear."}, None),
    "cruiser_beam": ("A patrol-car beam cuts across the alley mouth, closing any route that crosses its white sweep.", {"center": "The beam reaches the center of the alley, forcing movement into the remaining cover.", "background": "The cruiser beam has swung away, leaving only a pale reflection on the far wall."}, None),
    "stacked_cover": ("Stacked crates break the cruiser's sightline, though moving them will be easy to hear.", {"active_station": "The cover stack has been measured against the beam's sweep.", "right": "The crates now shield the right-hand route without blocking the exit.", "diversion_ready": "The top crate is tipped for a noisy diversion if the patrol looks back."}, None),
    "back_alley_cruiser_parked_exit": ("The marked exit hugs the wall outside the cruiser's direct beam.", {}, None),
    "patrol_officer": ("A patrol officer scans the alley in a practiced rhythm, punishing movement made at the wrong moment.", {"service_lane": "The officer has walked toward the service side, changing which cover matters.", "patrol": "The officer is actively patrolling instead of merely watching the cruiser.", "scanning_doorway": "The officer's attention is fixed on the doorway, briefly leaving the far wall unwatched.", "center": "The officer has entered the alley center and made the open ground unsafe."}, "background"),
    "goods_lot": ("Several bundled lots carry conflicting marks; a clean sale starts with separating their histories.", {"center": "The goods have been spread through the center so every maker's mark can be compared.", "left": "The rejected lot sits apart on the left, leaving the likely match near the station.", "marked_goods_lots": "Each bundle now carries a chalk lot mark tied to its visible provenance."}, None),
    "auth_station": ("A loupe, lamp, and ledger wait at the authentication station, promising proof before payment.", {"active_station": "The authentication lamp is on and the ledger is open to the relevant page.", "authentication_open": "The station is ready for a public check, making a false claim harder to pass."}, None),
    "back_alley_fence_night_exit": ("A painted arrow keeps the alley exit separate from the rotating goods lots.", {}, None),
    "rotating_buyer": ("A buyer checks hands and marks more closely than faces, making provenance matter here.", {"service_lane": "The buyer waits by the checking station instead of crowding the goods.", "checking_marks": "The buyer compares each chalk mark against the open ledger.", "foreground": "The buyer has stepped forward for the final authentication."}, None),
    "three_traces": ("Three faint scuffs cross at the shutter, proof that the supposedly quiet alley has seen traffic.", {"center": "The three traces are exposed together in the center light.", "three_traces_compared": "The scuffs have been matched into one route, pointing toward the shutter gap."}, None),
    "shutter_gap": ("A narrow gap under the shutter carries dust in both directions, suggesting recent passage.", {"active_station": "A low work light makes the dust trail beneath the shutter readable.", "background": "The shutter gap sits at the end of the matched trail, away from the open lane.", "opened_trace_gap": "The gap is open enough to follow, but it also leaves the route visible to anyone returning."}, None),
    "back_alley_nothing_moving_exit": ("The wall-side exit remains untouched by the trace work around the shutter.", {}, None),
    "returning_regular": ("A returning regular recognizes the scuffs and keeps glancing toward the shutter.", {"service_lane": "The regular has moved aside to let the trail be examined.", "flee": "The regular bolts after seeing where the matched trail leads.", "pointing_to_exit": "While retreating, the regular points out the clear wall-side exit."}, "background"),
    "estate_cart": ("An estate cart mixes keepsakes with ordinary stock; separating them protects both value and trust.", {"center": "The estate lot is spread through the appraisal space so nothing stays hidden beneath the pile.", "segmented_appraisal_cart": "The cart is divided into signed sections, giving every object a visible place in the appraisal.", "service_lane": "The sorted cart waits beside the counter without blocking the customer path."}, None),
    "provenance_marks": ("Faded initials and auction dots offer the only honest trail through the estate lot.", {"active_station": "The marks are under the appraisal lamp beside the matching ledger.", "provenance_matched": "The visible marks now agree with the estate record, clearing the lot for a decision."}, None),
    "pawn_shop_estate_lot_day_exit": ("The front path skirts the appraisal cart and remains open to the street.", {}, None),
    "estate_appraiser": ("The appraiser handles every piece in view, making quiet substitutions difficult.", {"service_lane": "The appraiser keeps to the service side of the cart, leaving the customer route open.", "comparing_marks": "The appraiser compares the faded marks against the estate sheet line by line.", "guard": "The appraiser now guards the matched lot until its disposition is settled.", "foreground": "The appraiser stands with the provenanced pieces at the front of the station."}, "service_lane"),
    "serial_station": ("A lamp and carbon sheet wait for a serial check that will leave a paper trail.", {"center": "The serial station is pulled into the open for a legible copy.", "serial_lamp": "The lamp catches every stamped digit, removing the excuse of a bad reading.", "background": "The lamp is dark and the station has been put away after the copy was made."}, None),
    "hold_object": ("The held object is wrapped but unsealed, pending a serial match before it can move.", {"active_station": "The object is unwrapped beside the serial copy for comparison.", "record_hold_sealed": "The matched object is sealed with the record attached, preventing a quiet swap.", "right": "The sealed hold rests to the right of the active customer lane."}, None),
    "pawn_shop_serial_check_day_exit": ("The shop door remains clear of both the serial lamp and the held object.", {}, None),
    "records_clerk": ("The records clerk keeps the carbon copy visible, making the hold accountable.", {"service_lane": "The clerk works from the service side, leaving the door path clear.", "copying_serial": "The clerk copies each serial digit under the lamp and checks it once more.", "guard": "The clerk guards the sealed hold until the record decision is complete.", "left": "The clerk stands beside the filed copy, away from the open door."}, "service_lane"),
    "unfinished_jobs": ("Half-finished repairs crowd Sal's bench; finishing one would change the shop's mood more than small talk.", {"center": "The unfinished jobs are laid out in order of what can actually be completed tonight.", "jobs_prioritized": "The bench now shows a workable order, with the most urgent repair already pulled forward."}, None),
    "private_appraisal": ("A curtained appraisal waits behind the public counter, promising privacy at the cost of outside witnesses.", {"active_station": "The private lamp is on and the appraisal tools are arranged for a serious offer.", "background": "The appraisal has moved behind the counter, out of the public traffic.", "privacy_screen": "The screen is closed around the appraisal, making the conversation quieter and less observable."}, None),
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
    "private_darkness": ("Only the private back counter has power; the dark coolers make lingering expensive.", "background"),
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
    "buyer_control": ("The buyer's tags now control every bundle on the table, making later bargaining harder.", "center"),
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
    "economy_provenance_public_service": ("A public provenance card lists the matched marks and makes the lot easier to price fairly.", "service_lane"),
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


def main():
    package = json.loads(PACKAGE.read_text(encoding="utf-8"))
    used = set()
    for scenario in package["scenarios"]:
        for phase in scenario["sequence"]["phase_graph"]["phases"]:
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
                    if zone and not payload.get("zone_id"):
                        payload["zone_id"] = zone
                    used.add(stable_id)
        for aftermath in scenario["sequence"].get("aftermath", {}).values():
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
                used.add(stable_id)
    unused = sorted((set(COPY) | set(AFTERMATH_COPY)) - used)
    if unused:
        raise SystemExit(f"unused authored copy: {unused}")
    PACKAGE.write_text(json.dumps(package, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"PACKAGE_A_AUTHORED objects={len(used)}")


if __name__ == "__main__":
    main()
