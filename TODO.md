# Beat the House - TODO

The only task list for this project. Erik owns it.

Phase: refinement. The game is close to feature-complete. Work improves
existing features, tests and docs. A new feature starts only when Erik moves
it into Now.

## Rules (keep this file small)

1. One item = one line, two at most. Say what the player sees or gets, not how
   to test it. No IDs, SHAs, dates, links to reports, or status words.
2. Section caps: Now 5, Bugs 15, Decide 8, Later 25. If a section is full,
   something must be finished, merged or dropped before adding.
3. A bug needs a way to see it in the game. No "verify", "qualify",
   "reconcile" or "more coverage" items. If it can't be seen, it isn't a bug.
4. Finished items are deleted, not checked off. The commit message and
   CHANGELOG.md are the record.
5. Only Erik moves items into Now or out of Decide. Workers may add to Bugs
   and Later within the caps, and must say so in their summary.
6. Plans longer than two lines go in a commit message or a pull request,
   never in a new file.

## Now

- Check the 16 unreviewed room briefs in the artist package, then send it to
  the artist.

## Bugs

- Release packages still carry a "-dev" build name. The Windows and Web ZIPs
  and Windows executable properties should use the release version.
- Cold travel can briefly stutter while the destination games load for the
  first time, especially on Web.
- 9 items promise an effect that never applies: Foil Sleeve and Mags' Lined
  Sleeve (Slot odds), Wedding Ribbon Favor and Rent-Party Hat Pin (luck when a
  scene grants them; check the other 11 souvenirs), Creased Luck Card, Lucky
  Keychain, Rabbit's Foot, Golden Motel Token (luck when equipped from home),
  Cooler's Cufflinks (peek shield). Waits on the item review below.

## Decide (Erik)

- Item review: what every item should do, including new effects for Lucky
  Penny and Ledger Pencil and whether Bumper Battery's unused boost stays.
- The Whale Game and the full Crew trust climb: bring them back? The Whale
  Game has never been finished in normal play.
- The Count is longer than planned (389 actions vs a 150-350 target): trim?
- Scenario polish: what should it cover?
- Layered room-art system on the art branch: merge it when the new art arrives?

## Later

- For the full 1.0.0 release, remove the Developer section, placement tools,
  and debug library links from player builds.
- Voice and copy pass on all 0.6 text (Erik, by hand).
- Daily Challenge leaderboard, in the game only.
- Heist plans C "The Jackpot Job" and D "Lights Out" are designed but not
  built. Long-term goal: one heist per Crew member.
- Grand Casino "High-Limit Invitational" scenario is designed but not built.
- Scenario characters snap between spots instead of walking (45 scenarios,
  plus the Delta Queen captain, guard and wedding party).
- Delta Queen wedding rope and Grand Casino convention table blockade have no
  drawn object.
- New room art for all 20 rooms (artist), then the 12 travel doorways.
- Finish the room placement pass after the new art (19 of 75 layouts saved).
- More object spots per room.
- Cross-system balance review before any item change ships.
- Tutorial test with five players who have never seen the game.
- Play a run on a real phone in landscape to check touch selection and the new
  inventory icons.
- Act 2: the hand-off from Act 1 is saved at victory; nothing else exists.

## Not now

- Android and iOS builds (need signing accounts).
- Steam inventory, online leaderboards and achievements.
- Trailer and devlog.
- Not wanted for now: controls page or rebinding, rebet in more games, faster
  tables, more save slots, translations, collection sorting.
