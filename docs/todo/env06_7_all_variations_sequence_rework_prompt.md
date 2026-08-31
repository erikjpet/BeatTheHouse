Status: IN_PROGRESS — implementation landed on `main`; formal row acceptance remains open
Board row: `env06_7` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 env06_7: Rebuild All 55 Environment Variations as Unique Sequences

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is the complete
content conversion for the owner-requested environment-depth rework. Read
`env06_6_dynamic_scenario_runtime_prompt.md`, the shipped scenario/event
catalogs, all environment renderers/interactables, town/crew/game systems, and
the archived env06_2/env06_3/env06_5 prompts. Do not delete established ids,
selection weights, rumor anchors, or compatible consequences without a logged
reason. Migrate them into genuine sequences.

## Non-negotiable content standard

Every checkbox below is a separate deliverable. A variant is incomplete if it
only changes text, tint, music, crowd metadata, prices, pools, cash, suspicion,
flags, reputation, or items. Those may support its outcome; they cannot be its
primary activity.

For each of all 55 ids, author and validate a sequence dossier containing:

- arrival tableau and at least two semantic object/actor changes;
- phase graph with arrival, complication/opportunity, and branch aftermath;
- the player's scenario-specific verbs and at least two action boundaries;
- success, failure, refuse/ignore, and interruption/revisit behavior;
- at least two outcomes with materially different space, actors,
  interactables, services, routes, or game rules afterward;
- one meaningful connection to a game, crew, town, sweep, travel, heat,
  security, economy, or rumor system;
- cleanup/expiry/save rules and zero-overlap visual captures;
- normalized mechanic signature. No two entries may share the same complete
  verb → phase → aftermath signature, even when they reuse primitives.

The anchor below is a minimum identity contract, not optional flavor. Improve
details when code reality requires it, but preserve the distinct player task
and physical transformation. Existing one-shot event rewards become beats
inside these sequences.

## Corner store — five complete conversions

- [ ] `corner_store_delivery_day` — cartons physically block/re-route aisles;
  help sort a mismarked delivery or inspect/ignore it, opening different shelf
  sections and clerk/service states afterward.
- [ ] `corner_store_lotto_fever` — a ticket queue grows around the counter;
  choose how to secure a place/handle a disputed number before stock sells out,
  then leave a cleared, angry, or celebration layout.
- [ ] `corner_store_aftermath` — boarded glass, evidence, and a nervous clerk
  create a restricted path; decide whether to quietly recover/flag the suspect
  object while the plainclothes cop moves through the store.
- [ ] `corner_store_dead_shift` — restore a flickering aisle/cooler circuit in
  stages to reach the clerk's rumor source, trading visibility against privacy;
  the lit and deliberately-dark endings change surveillance and access.
- [ ] `corner_store_inventory_night` — counters close aisles section by
  section; perform a physical shelf-count discrepancy trail whose resolution
  reopens, quarantines, or rearranges stock rather than simply granting loot.

## Back alley — four complete conversions

- [ ] `back_alley_street_craps` — assemble/read the chalk circle, take a
  shooter turn, respond to lookout escalation, then see the ring continue,
  relocate, or disperse with persistent chalk/actor aftermath.
- [ ] `back_alley_cruiser_parked` — patrol light and officer sightline divide
  the alley; move through cover or create a diversion to reach a target, with
  the cruiser repositioning/leaving or a route remaining watched.
- [ ] `back_alley_fence_night` — goods arrive in visible lots and buyers rotate
  through stations; authenticate, broker, or walk away from one contested lot,
  changing which stall/exit remains available and who controls it.
- [ ] `back_alley_nothing_moving` — shutters and absent regulars turn the alley
  into an investigation of three physical traces; following or erasing a trail
  opens different exits/rumors and changes who returns.

## Motel — four complete conversions

- [ ] `motel_conventioneers` — luggage and guests occupy the lobby/walkway;
  route a room mix-up or exploit/avoid the crowd, moving carts/people and
  changing access to rooms/services.
- [ ] `motel_stakeout` — surveillance positions and sight cones alter the
  balcony path; identify the watched room and choose to warn, misdirect, or
  wait out observers, producing different occupied/cleared rooms.
- [ ] `motel_weekly_rates` — inspect and repair/accept a failing weekly room in
  a short landlord negotiation sequence; furniture/utilities/access and future
  rest service differ by branch.
- [ ] `motel_wedding_overflow` — wedding parties physically spill between
  rooms; reunite a missing item/person through room-to-room clues or exploit
  the confusion, ending in a reception, argument, or locked-down corridor.

## Bar — seven complete conversions

- [ ] `bar_wake` — tables combine around a memorial and the regular bar route
  closes; deliver/withhold a remembrance through specific patrons, changing
  seating, mood, and who stays after the toast.
- [ ] `bar_fight_night` — arguments move furniture and escalate through warning,
  confrontation, and cleanup; de-escalate, choose a side, or protect an exit,
  leaving repaired, broken, or security-controlled space.
- [ ] `bar_payday_rush` — a live order queue consumes counter space; carry and
  prioritize orders/settlements while patrons rotate, changing service speed,
  tabs, and table availability.
- [ ] `bar_lock_in` — shutters close and legal exit disappears; earn inclusion,
  find the quiet exit, or trigger reopening through a private after-hours task,
  with different hidden interactions and occupants afterward.
- [ ] `bar_darts_league_night` — league lanes replace ordinary seating; play or
  officiate a multi-round darts dispute with throw-line/crowd states and a
  bracket-dependent final room arrangement.
- [ ] `bar_live_band` — stage/speakers/cables take over a route; solve soundcheck
  and crowd-flow problems or let the set fail, changing performance, dancing,
  service access, and post-show actors.
- [ ] `bar_dead_tuesday` — nearly empty room invites a deliberate choose-your-
  company sequence among bartender, lone patron, and back booth; each choice
  activates a different part of the room/task and closes the others for night.

## Gas-station casino — five complete conversions

- [ ] `gas_station_trucker_convoy` — rigs/driver groups occupy parking and
  machines in waves; coordinate departure/loading or compete for a machine,
  changing exterior route, seats, and traveler links.
- [ ] `gas_station_tour_bus_stop` — timed passengers flood shop/restroom/games;
  navigate a lost-ticket or boarding-count task before departure, producing
  boarded, stranded, or delayed aftermath.
- [ ] `gas_station_graveyard_shift` — only clerk, cameras, and alternating
  locked zones remain; complete a night-check route or bypass it, changing
  lighting, shutters, and surveillance exposure.
- [ ] `gas_station_road_crew_payday` — workers rotate from counter to machines;
  settle a pooled-stake/work-order dispute through play and physical crew
  stations, ending with a repaired route, occupied floor, or early departure.
- [ ] `gas_station_storm_shelter` — weather progressively closes exterior
  access and moves patrons inside; secure power/supplies and allocate safe
  space, then reopen, black out, or remain crowded based on choices.

## Punchline / underground casino — eight complete conversions

- [ ] `punchline_open_mic_night` — signup sheet, stage queue, and audience seats
  change over acts; manage/support/sabotage a slot and live with a reordered
  bill, emptied room, or successful late show.
- [ ] `punchline_headliner_night` — ropes and backstage access restructure all
  three layers; solve a credential/runner task that changes who reaches the
  headliner and which crew/service doors remain open.
- [ ] `punchline_bringer_show` — performers must fill seats; choose which crowd
  group to usher/manage, physically changing occupancy and whether the room
  becomes a show, hostile pitch, or abandoned stage.
- [ ] `punchline_high_stakes_night` — a protected table displaces ordinary play;
  qualify, observe, or service a multi-step high-stakes session whose outcome
  moves guards, opens/closes games, and changes the casino floor.
- [ ] `punchline_greased_week` — bribed inspection routes alter staff behavior;
  trace and maintain/expose the payoff chain across layers, changing blocked
  doors, inspectors, and operating services.
- [ ] `punchline_debt_court` — chairs form a hearing and jobs pause; present,
  verify, or contest a case using room evidence/crew testimony, then physically
  return the room to work under a distinct ruling.
- [ ] `punchline_new_muscle` — new guards impose checkpoints; test, be tested by,
  or route around their procedures, ending with reassigned posts, open paths,
  or an entrenched checkpoint.
- [ ] `punchline_raid_jitters` — knocks/rumors trigger staged hide, clear, and
  reopen actions across layers; choose what/whom to secure, with a genuinely
  altered resumed floor or aborted night.

## Jazz club — four complete conversions

- [ ] `jazz_club_guest_legend` — a guest's arrival reshapes stage/table access;
  retrieve/prepare a missing instrument cue and choose when to reveal them,
  changing set order, crowd positions, and backstage access.
- [ ] `jazz_club_rent_party` — donation stations and furniture move as the goal
  approaches; help run a specific revenue activity or challenge its terms,
  ending in continued music, shutdown, or creditor occupation.
- [ ] `jazz_club_recording_night` — microphones/cables create silence zones and
  blocked routes; perform a quiet multi-step take/reset task, with a saved take,
  ruined session, or relocated audience aftermath.
- [ ] `jazz_club_union_trouble` — picket/management lines split entrances and
  stage work stops; mediate, cross, or support a side through concrete setup
  tasks, changing performers, service, and future entry route.

## Kitty Cat Lounge — four complete conversions

- [ ] `kitty_cat_lounge_amateur_night` — signup, dressing, stage, and judging
  stations cycle contestants; help one act prepare or run the bracket, changing
  lineup, crowd, and backstage availability.
- [ ] `kitty_cat_lounge_buyout` — private-party ropes progressively claim the
  room; verify guests, serve a request chain, or resist displacement, resulting
  in full buyout, public reopening, or split-floor operation.
- [ ] `kitty_cat_lounge_slow_night` — staff consolidate/close sections; choose a
  mini-show, maintenance, or conversation task that physically reactivates a
  different zone and determines who remains.
- [ ] `kitty_cat_lounge_bachelorette_storm` — party groups move props and flood
  stage/bar; recover control through a missing-person/prop sequence or ride the
  chaos, ending in orderly show, commandeered stage, or cleared room.

## Delta Queen — five complete conversions

- [ ] `delta_queen_wedding_charter` — ceremony/reception zones replace normal
  deck access; solve a rings/guest-routing crisis across decks, producing a
  ceremony, delay, or broken charter layout.
- [ ] `delta_queen_whale_aboard` — entourage and security move between premium
  spaces; earn/avoid access through an observation/service sequence, changing
  table availability, guards, and the whale's location.
- [ ] `delta_queen_fog_delay` — visibility and docking access close in phases;
  gather navigation/dock information and choose wait/reroute assistance,
  changing deck stations and final route state.
- [ ] `delta_queen_engine_trouble` — engine noise/failure closes a deck and
  shifts staff; diagnose, fetch, and apply/withhold a repair path, ending with
  resumed travel, limited power, or evacuation staging.
- [ ] `delta_queen_captains_invitational` — bracket tables and spectators rotate
  through rounds; qualify/observe/officiate a disputed result, leading to a
  different final table, access tier, and winner entourage.

## Beach — three complete conversions

- [ ] `beach_bonfire_night` — gather/place fuel and seating around a growing
  fire while tide/wind changes usable space; choose communal, hidden, or
  extinguished aftermath with different actors/routes.
- [ ] `beach_storm_coming` — warning, securing, and evacuation phases move props
  and people inland; decide what to secure and when to leave, producing damaged,
  protected, or abandoned shoreline state.
- [ ] `beach_festival_weekend` — stalls/stage/crowds occupy distinct zones;
  complete a lost-person, setup, or schedule task through moving attractions,
  ending with altered lineup, closed stall, or after-hours beach.

## Pawn shop — three complete conversions

- [ ] `pawn_shop_estate_lot_day` — estate objects arrive on carts and move
  through appraisal/display/hold zones; establish provenance through physical
  clues, changing which lots are sold, quarantined, or returned.
- [ ] `pawn_shop_serial_check_day` — inspection station and police hold area
  restrict inventory; trace one serial through owner records/objects and choose
  disclose, withdraw, or wait, changing access and who remains in shop.
- [ ] `pawn_shop_sals_mood` — Sal visibly cycles between counter/back room and
  alters deal access; complete a read-and-response sequence using shop tasks,
  leading to reopened counter, private appraisal, or closed shutters.

## Grand Casino — three complete conversions

- [ ] `grand_casino_gala_night` — ropes, coat check, stage, and VIP routes
  replace ordinary circulation; obtain/verify access or handle a gala failure,
  changing room connectivity and table/service availability.
- [ ] `grand_casino_convention_crowd` — delegations reserve blocks of machines
  and tables on a schedule; navigate/mediate a booking conflict, causing groups
  and open play areas to relocate rather than merely changing crowd density.
- [ ] `grand_casino_audit_night` — auditors and pit staff inspect zones in a
  visible route; comply, misdirect, or wait through a multi-stage table check,
  changing security positions, game availability, and post-audit access.

## Cross-catalog acceptance and anti-cloning gate

1. Build a machine-readable dossier for all 55 ids and fail if any checkbox has
   no implementation, test, complete phase graph, or capture set.
2. Run pairwise signature comparison. A renamed queue/fetch/choice sequence
   with the same object operations and aftermath is a duplicate and fails.
   When two scenarios share a primitive (queue, repair, escort, investigation),
   their pressure, second verb, world-system interaction, branch topology, and
   aftermath must differ.
3. No archetype may reuse one unchanged room arrangement for all variants.
   Produce a contact sheet per archetype showing every arrival and terminal
   aftermath; reviewers must identify the variant without its title/sign text.
4. Verify every scenario is seed-reachable, every phase/branch is fixture-
   reachable, all interactables are clickable and keyboard/controller
   reachable, and all exits remain safe.
5. Save/load at every phase and branch for every scenario. Revisit partial and
   terminal states. No reward, trust, heat, suspicion, inventory, rumor, or
   transition fires twice.
6. Test coexistence with base services/games/events/travelers/Sweep and
   conflicts unique to each venue. No scenario may permanently destroy base
   functionality outside its authored aftermath/expiry.
7. Run content/privacy/Voice Bible, full systems/UI/save/accessibility,
   determinism, native/Web parity, performance, and visual QA gates. Zero
   overlap, clipping, orphan props, stale hit targets, and unknown references.

## Completion report

Report all 55 dossiers grouped by archetype, their distinct mechanic
signatures, phase/branch counts, changed objects/interactables, world-system
connections, revisit policies, captures, and gate evidence. Any omitted or
reward-only variation keeps this row `IN_PROGRESS`/`BLOCKED`; partial catalog
conversion is not completion.
