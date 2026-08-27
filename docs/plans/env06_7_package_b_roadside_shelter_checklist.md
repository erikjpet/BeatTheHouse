# env06_7 Package B — Roadside and Shelter Checklist

Scope: Motel (4), Gas-Station Casino (5), Beach (3); 12 ids total.

The common package checklist is binding. This package owns no shared catalog
index, env runtime, travel/sweep model, game module, or board file.

## Exact inventory

- [ ] Motel: `motel_conventioneers`, `motel_stakeout`,
  `motel_weekly_rates`, `motel_wedding_overflow`.
- [ ] Gas-Station Casino: `gas_station_trucker_convoy`,
  `gas_station_tour_bus_stop`, `gas_station_graveyard_shift`,
  `gas_station_road_crew_payday`, `gas_station_storm_shelter`.
- [ ] Beach: `beach_bonfire_night`, `beach_storm_coming`,
  `beach_festival_weekend`.

## Identity-specific proof

- [ ] Conventioneers moves luggage/carts/guests and branches room-mix handling
  into different rooms and services.
- [ ] Stakeout uses real surveillance positions/sight cones and watched-room
  inference; warn/misdirect/wait produces occupied/cleared room differences
  without leaking hidden observer state.
- [ ] Weekly Rates stages inspect plus repair/accept negotiation and persists
  furniture, utilities, access, and rest-service outcome.
- [ ] Wedding Overflow follows room-to-room physical clues and ends in reception,
  argument, or locked corridor.
- [ ] Trucker Convoy moves rigs/drivers/machine occupancy in waves and changes
  exterior route, seats, and traveler links.
- [ ] Tour Bus stages a passenger flood and lost-ticket/boarding-count task,
  ending boarded, stranded, or delayed.
- [ ] Graveyard Shift uses alternating locked zones, cameras, lighting, and
  shutters for a check-route/bypass branch.
- [ ] Road Crew Payday connects pooled play and work stations to repaired route,
  occupied floor, or early departure without scenario-owned game settlement.
- [ ] Storm Shelter progressively closes exterior access, moves patrons, and
  stages power/supplies/space allocation into reopen/blackout/crowded aftermath.
- [ ] Bonfire makes fuel, seating, tide, and wind alter usable space and yields
  communal, hidden, or extinguished states.
- [ ] Storm Coming stages warning, securing, and evacuation with damaged,
  protected, or abandoned shoreline outcomes.
- [ ] Festival Weekend moves stalls/stage/crowds through a lost-person, setup,
  or schedule task into changed lineup, closed stall, or after-hours beach.

## Package conflicts

- [ ] Traveler/travel and weather/sweep connections use authenticated public
  facts and preserve a clean exit at every closure phase.
- [ ] Temporary lodging/rest changes never corrupt base housing or save
  authority; partial reentry cannot re-charge or re-grant service.
- [ ] Moving exterior blockers always provide a validated alternate objective
  or exit and restore safely at expiry.
