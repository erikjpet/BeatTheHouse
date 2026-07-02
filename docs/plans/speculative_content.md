# Speculative Content Log

Status: IDEA POOL — nothing here is scheduled. This is a PM-curated backlog of
possible content that fits the theme (seedy mid-century American gambling
underworld, debt-and-heat spiral, deterministic luck, no real money). Sift it,
mark keepers, and promote them into tasks on the Act 1 board.

**How to read an entry:**
- **Purpose** — the player fantasy or system gap it serves.
- **Function** — what it mechanically does.
- **Architecture** — where it plugs in: data pack, effect keys, module
  contracts, hooks. All content must obey the design rules: data-driven JSON
  via `ContentLibrary`, deterministic `RngStream` only, results applied through
  `GameModule.apply_result`/`RunActionService`, copy within validator limits.

Tags: `[clean]` `[advantage]` `[cheat]` `[drunk]` `[debt]` `[heat]` `[travel]`
mark which build/system an entry feeds.

---

## 1. Items

Existing classes: permanent, temporary, consumable, contraband, active, game,
security, travel. All entries land in `data/items/items.json` with an
`effect.families` block consumed by `ItemEffect` or a game module, plus
price band, content group, icon, and environment prop/surface.

**1.1 Lucky Rabbit's Foot** `[clean]`
- Purpose: the baseline superstition item every casino story needs; a cheap first purchase that teaches the luck stat.
- Function: permanent +small flat luck floor; luck cannot drop below a threshold while held.
- Architecture: permanent class, `effect.families.global.luck_floor`; RunState luck getters already clamp — add floor support in the luck accessor.

**1.2 St. Christopher Medal** `[travel]`
- Purpose: patron saint of travelers; protection-flavored travel economy.
- Function: negates the first travel-risk event each run; small discount on bus-class routes.
- Architecture: travel class; new `travel.risk_shield_uses` and `travel.route_discount_percent` keys consumed by `RunActionService` travel handling.

**1.3 Green Dealer's Visor** `[advantage]`
- Purpose: the classic card-room silhouette; signals "I take cards seriously."
- Function: card games display extra table info (running count hint quality up in blackjack, discard memory aid in video poker).
- Architecture: game class; per-family keys (`cards.info_tier`) read by blackjack/video poker surface state; UI-only edge, no payout math change.

**1.4 Cigarette Case Mirror** `[cheat]`
- Purpose: period-perfect spy tool; contraband that makes peeking tangible.
- Function: one hole-card peek per blackjack shoe without triggering the peek heat cost; confiscated if caught cheating elsewhere.
- Architecture: contraband; `cards.free_peek_per_shoe`; blackjack peek path checks/consumes it; confiscation via a new ItemEffect `confiscate_on_caught` flag.

**1.5 Marked Deck** `[cheat]`
- Purpose: the nuclear option of card cheating; huge edge, huge exposure.
- Function: active-use — swap into a card game for N hands of visible opponent/dealer cards; every hand while active adds suspicion; discovery is near-certain if watched.
- Architecture: contraband active; challenge-window integration per the skill-cheat contract (T2.6); `cards.marked_deck_hands`, watched-discovery routed through `security_action_pressure`.

**1.6 Counterfeit Chip Stack** `[cheat]` `[debt]`
- Purpose: desperation money; a loan from the devil with heat as interest.
- Function: single use — instantly +$150 bankroll as "chips"; sets a delayed narrative flag; a later cage/cashier event can detect the counterfeits for a massive heat spike or clawback.
- Architecture: contraband active; grants bankroll via RunActionService; plants `narrative_flags.counterfeit_chips_floated` consumed by a paired event in `events.json`.

**1.7 Flask of Rye** `[drunk]`
- Purpose: drink on your own schedule instead of the house's.
- Function: consumable ×3; each use applies the house_drink alcohol/luck effect anywhere, no service needed, slightly stronger hangover.
- Architecture: consumable; reuses the service alcohol pipeline via `ItemEffect` calling the same RunState alcohol methods.

**1.8 Thermos of Black Coffee** `[drunk]`
- Purpose: the sober-up counterpart; makes drunk builds manageable.
- Function: consumable ×2; reduces current alcohol level a tier and suppresses drunk visual distortion for a while.
- Architecture: consumable; `global.alcohol_delta` negative value; drunk_distortion_overlay reads suppression timer from RunState.

**1.9 Pawn Ticket** `[debt]`
- Purpose: liquidity — turn inventory into bankroll without a shop.
- Function: active — instantly sell any held item at 60% sale price from anywhere; ticket lets you buy it back at the pawn shop later at 80%.
- Architecture: active class; new RunActionService action `pawn_item`; buyback stored as a narrative flag + pawn shop object pool entry.

**1.10 Regular's Jacket** `[heat]`
- Purpose: belonging — look like furniture in the dives you frequent.
- Function: permanent; heat decays faster in tier-1 venues you have visited 2+ times; no effect in tier-2+.
- Architecture: permanent/security; `security.heat_decay_bonus_tier1`; RunState heat decay consults environment tier + visit history (already tracked).

**1.11 Sunday Suit** `[clean]` `[heat]`
- Purpose: the respectability play; dress for the room you want.
- Function: permanent; tier-2/Grand Casino entry costs reduced; staff attention accrues slower while heat is low; effect void while any contraband is held.
- Architecture: permanent; `security.attention_scale` + travel entry discount; the contraband-void check reads inventory class list.

**1.12 Fake Mustache & Glasses** `[cheat]` `[heat]`
- Purpose: cartoonish, memorable, and mechanically precious: one identity reset.
- Function: active single-use — clears watched status and staff attention in the current venue; useless (auto-fizzles, +suspicion) if used during a showdown-pending state.
- Architecture: security active; RunActionService clears `pit_boss_watch`/attention flags; guarded against endgame abuse via demo-objective state check.

**1.13 Rosary of the Losing Streak** `[clean]`
- Purpose: comeback drama; the item that makes cold nights bearable.
- Function: permanent; after 4 consecutive game losses, the next win pays +50%; counter visible on HUD.
- Architecture: permanent; RunState tracks loss streak (near-free — result path already sees outcomes); payout bonus applied in `GameModule.apply_result`.

**1.14 Two-Headed Quarter** `[advantage]`
- Purpose: a pocket legend; guaranteed once, then it's just a quarter.
- Function: active single-use — forces the player-favorable outcome on the next coin-flip-class resolution (bar dice tie-break, event coin choices, double-up first step).
- Architecture: active; sets a one-shot RunState flag consumed by any module that declares a `coin_flip` resolution kind.

**1.15 Bartender's Favor** `[heat]`
- Purpose: social capital as an item; the bar looks after its own.
- Function: active single-use — cancels one heat spike inside a bar-kind venue the moment it happens (auto-triggers).
- Architecture: security active; RunState heat-add path checks for auto-consume shields scoped by environment kind.

**1.16 Little Black Book** `[advantage]` `[debt]`
- Purpose: information is the real currency; a scout's item.
- Function: permanent; event choices display odds hints; lender terms show true total repayment; travel previews upgrade one tier.
- Architecture: permanent; UI-tier flags (`global.info_tier`) read by event popup, lender panel, travel panel. No simulation change.

**1.17 Racing Form (Today's Edition)** `[advantage]`
- Purpose: pairs with the Horse Book game (see 3.3); the handicapper fantasy.
- Function: temporary (expires after 3 races) — reveals one horse's true odds band per race.
- Architecture: game/temporary; `racing.form_tier` consumed by the horse book module; expiry via existing temporary-item duration support.

**1.18 Union Card** `[clean]`
- Purpose: working-class identity; the economy of belonging.
- Function: permanent; all services cost 20% less; unlocks a "union rate" dialogue variant at the motel lender.
- Architecture: permanent; `services.discount_percent` in RunActionService service pricing; lender variant via condition on item held.

**1.19 Cooler Charm** `[clean]`
- Purpose: variance insurance against catastrophic hands.
- Function: permanent; once per venue visit, a single-hand loss exceeding 30% of bankroll is refunded to exactly 30%.
- Architecture: permanent; clamp applied in `apply_result` delta path with per-visit flag; readable toast explains the save.

**1.20 Comp Voucher Book** `[clean]`
- Purpose: the comped lifestyle; stretch a bankroll through services.
- Function: consumable ×3 — each voucher redeems any one service free.
- Architecture: consumable; RunActionService service payment path accepts voucher consumption before bankroll.

**1.21 Snakeskin Boots** `[cheat]` `[heat]`
- Purpose: intimidation as a stat; dress loud, play loud.
- Function: permanent; bar dice patrons fold/press in your favor more; +1 passive suspicion in casino-kind venues (you're memorable).
- Architecture: permanent; `dice.intimidation` read by bar_dice patron AI; passive suspicion via a small periodic modifier in RunState heat accrual.

**1.22 Hearing-Aid Wire** `[cheat]`
- Purpose: the wire — classic sports-service scam hardware.
- Function: contraband; sports book (see 3.9) and keno (3.2) reveal one insider hint per venue visit; if a security sweep event fires while held, it is found (big heat).
- Architecture: contraband; `info.insider_hint_per_visit`; security sweep events check inventory for `detectable: true` items.

**1.23 Ledger of Debts** `[debt]`
- Purpose: fight the lenders with bookkeeping.
- Function: permanent; unlocks a "negotiate" action on any active loan once (extend due date or shave interest); HUD shows exact daily interest.
- Architecture: permanent; new RunActionService lender action gated on item; lender data gains `negotiable` fields.

**1.24 Motel Key Ring** `[travel]`
- Purpose: home base; the motel as sanctuary.
- Function: travel; once per day, free route back to the motel from anywhere; sleeping there clears a small amount of heat.
- Architecture: travel class; injects a synthetic route via travel offer generation; heat relief via motel service hook.

**1.25 Monkey's Paw Slot Token** `[cheat]`
- Purpose: cursed-item flavor; references the real slot-cheating "monkey paw" tool.
- Function: contraband active — force the next slot spin to be a feature trigger; the feature's cap is halved and suspicion jumps if watched.
- Architecture: contraband active; sets a forced-outcome flag consumed by slot resolver's outcome pick; cap modifier passed into feature open params. Coordinate with pinball rework before implementing.

**1.26 Deck of Saints Tarot** `[clean]`
- Purpose: extends the existing tarot/pull-tab mysticism into a general oracle.
- Function: active, 3 charges — draw a card that reveals the classification band (cold/warm/hot) of the next outcome in the current game.
- Architecture: active; games expose a `next_outcome_band` hint API (deterministic from the already-seeded resolver state); no outcome change.

**1.27 Brass Knuckle Paperweight** `[debt]`
- Purpose: dark-comedy protection; changes a collection scene's script.
- Function: permanent; during collector/shakedown events, unlocks a "stand your ground" choice with better outcomes but a heat cost.
- Architecture: permanent; event choices in `events.json` conditioned on item held (EventModule already supports item conditions).

**1.28 Lucky Ashtray** `[drunk]`
- Purpose: dive-bar talisman; rewards drinking where you gamble.
- Function: permanent; while alcohol level is above tipsy, +1 effective luck in bar-kind venues.
- Architecture: permanent; conditional luck modifier keyed on alcohol tier + environment kind in RunState effective-luck calc.

**1.29 Out-of-State Plates** `[travel]` `[heat]`
- Purpose: the drifter build; heat doesn't follow you.
- Function: travel/permanent; heat carried between venues on travel is reduced 25%; venue re-entry after absence starts one attention tier lower.
- Architecture: travel; modifier applied in travel transition heat handling in RunActionService.

**1.30 The Dead Man's Hand Card** `[advantage]`
- Purpose: aces-and-eights lore; a memento that gambles with fate.
- Function: permanent; whenever a dealt poker/blackjack hand contains two pair aces-and-eights, instantly +$88; you cannot fold/surrender that hand.
- Architecture: permanent; hand-pattern hook in card game result evaluation; forced-play constraint surfaced in UI state.

---

## 2. Environments

Existing archetypes live in `data/environments/archetypes.json`: name parts,
visual_context, layout points, security/economic/music profiles, object pools,
route hooks, narrative flags, objective hints. New venues need routes in
`data/travel/routes.json` and generation weights compatible with
`run_generator.gd`.

**2.1 Riverboat Casino "The Delta Queen"** — tier 2
- Purpose: the canonical mid-game rung; legally gray water gambling with a captive-audience twist.
- Function: mid-stakes blackjack/roulette/video poker; boards on a schedule — once aboard, travel is locked for N actions (the boat is out); disembark events at the dock.
- Architecture: casino kind, tier 2; new archetype field `travel_locked_actions` enforced by RunActionService travel gating; schedule via route availability windows.

**2.2 The Meridian Social Club** — tier 2
- Purpose: invitation-only backroom; the "you know somebody" fantasy.
- Function: high-stakes bar dice, baccarat-adjacent play, contraband shop pool, lender presence; entry requires an item, event flag, or fee.
- Architecture: casino kind, tier 2; route prerequisite via `narrative_flags` or item condition on the route entry (routes gain a `requires` block).

**2.3 Off-Track Betting Parlor** — tier 1
- Purpose: home of the Horse Book game (3.3); smoke, paper slips, and radio calls.
- Function: horse betting, racing-form item in shop pool, tout characters, race-day events.
- Architecture: casino kind, tier 1; hosts a single anchor game plus services; music profile: AM radio race calls.

**2.4 Church Basement Bingo Night** — tier 1
- Purpose: the lowest-heat room in the game; gambling with a guilty conscience.
- Function: bingo game (3.5), zero security profile, no cheat actions available (they're church ladies), unique low-stakes economy; Deacon character.
- Architecture: casino kind, tier 1; `security_profile` near-zero but cheating disabled via archetype flag `cheats_disabled` respected by cheat_actions().

**2.5 Sal's Pawn & Loan** — tier 1 shop
- Purpose: item liquidity hub; pairs with Pawn Ticket (1.9) and the pawn lender (6.1).
- Function: buy/sell at real spreads, buyback of pawned items, occasional contraband under the counter after trust builds.
- Architecture: shop kind; object pools split by trust flag; lender attached via existing lender placement.

**2.6 Starlite Bowling Lounge** — tier 1
- Purpose: Americana; gambling hiding inside recreation.
- Function: punchboards (3.6) and bar dice in the lounge; league-night events; low security, chatty patrons (info hints).
- Architecture: casino kind, tier 1; standard pools; distinct visual_context (lanes backdrop props).

**2.7 The All-Nite Diner** — tier 1 shop
- Purpose: the 3AM decompression room; services and story, no gambling.
- Function: coffee (sober-up), grease (hangover cure), the corner booth (event hub — meets with characters happen here), tip-the-waitress goodwill flag.
- Architecture: shop kind; service-heavy pools; several events scoped `diner_only`; like jazz_club, a deliberate no-games room.

**2.8 Union Hall Poker Night** — tier 2, periodic
- Purpose: home of Five-Card Draw vs NPCs (3.4); the weekly game everyone knows about.
- Function: appears in route offers only on some days; fixed table of recurring NPC players with memory of your past behavior.
- Architecture: casino kind, tier 2; route availability window; NPC memory via narrative flags per character id.

**2.9 The Kitty Cat Lounge** — tier 2
- Purpose: velvet-rope vice; heat management through nightlife.
- Function: burlesque shows as services (expensive luck/heat effects), champagne economy, a house game of Big Six (3.7); staff turns a blind eye (slow attention) but drinks flow (alcohol pressure).
- Architecture: casino kind, tier 2; service-forward pools; attention scale in security_profile below tier norm, alcohol-push events.

**2.10 Greyhound Depot** — travel hub
- Purpose: makes travel itself a place; lockers, rumors, departures.
- Function: many cheap routes out; locker service (stash items/cash between visits); rumor board (paid route previews); pickpocket risk event while drunk.
- Architecture: shop kind with travel-forward pools; locker = new RunActionService stash action storing an inventory sublist in RunState.

**2.11 County Fair Midway** — seasonal tier 1
- Purpose: carnival grift in daylight; a rotating venue that isn't always there.
- Function: Razzle (3.14) and coin pusher (3.11); games are beatable only with items/knowledge; barker events; appears in route offers for a window of run-days.
- Architecture: casino kind; availability window on routes; deliberately negative-EV games with readable tells (odds literacy teaching).

**2.12 The Penthouse Game** — tier 3 alternate
- Purpose: an endgame variant venue — a private high-stakes evening as a counterpoint to the Grand Casino floor.
- Function: invitation via event chain only; one long poker/baccarat session against named characters; huge swing potential; feeds the same victory accounting as Grand Casino net-winnings if designed as an Act 1 alt-path (or hold for Act 2).
- Architecture: boss kind, tier 3; entered via event-granted route; scope decision needed (Act 1 alt vs Act 2 content).

**2.13 Police Impound Auction** — special shop, rare
- Purpose: buy confiscated contraband back from the law; delicious irony, real risk.
- Function: rotating contraband stock at steep discounts; buying while heat is high triggers an ID-check event; a cop character recognizes repeat visitors.
- Architecture: shop kind; stock pool weighted to contraband; entry event conditioned on heat band.

**2.14 The Boneyard** — tier 1 shop, hidden
- Purpose: the fence; where contraband becomes clean money.
- Function: sells contraband at real value (normal shops undercut it), meets The Dentist (6.3), route discovered only via events or the Little Black Book.
- Architecture: shop kind; hidden route (`requires` flag); sale price override for contraband class.

**2.15 Lucky's Laundromat (Back Room)** — tier 1
- Purpose: the numbers bank; front business with a back-room count.
- Function: hosts the Numbers Racket game (3.15); wash small amounts of "hot" winnings for a fee (converts heat-flagged bankroll clean); raid-risk events.
- Architecture: casino/shop hybrid via object pools; money-wash service reduces a new `hot_money` counter if that mechanic is adopted (see 3.15 note).

---

## 3. Games

Every game is a `GameModule` implementer in `scripts/games/`, defined in
`data/games/games.json`, with its own surface state/actions/drawing on
`game_surface_canvas`, deterministic `RngStream` forks, result dictionaries
through `apply_result`, and a cheat/advantage action set following the Epic 2
skill-cheat contract.

**3.1 Craps** — the big table gap
- Purpose: the loudest table in any casino; the only major casino staple missing from the roster.
- Function: full pass/don't-pass, come/don't-come, odds, field, place bets; a "table crowd" mood that swells with hot rolls; shooter phases (player can be shooter or bet on a patron shooter).
- Cheats: dice sliding (timing skill-check per the contract), late bet capping.
- Architecture: dice family module; multi-bet layout surface like roulette's chip placement; crowd mood as surface-state juice fed by roll streaks; patron shooter = seeded NPC roll sequence.

**3.2 Lounge Keno** — the slow burn
- Purpose: the ambient game — pick numbers, then keep living while the draw happens.
- Function: pick 4-10 spots, draws resolve after N other actions elsewhere in the venue (the board runs on its own clock); multi-race tickets; big top-end payouts.
- Cheats: crayon ticket forgery (post-draw ticket alteration, high heat), hearing-aid wire hint (1.22).
- Architecture: novelty family; introduces a deferred-resolution pattern — RunState holds pending keno tickets resolved by a venue-action counter hook; surface is a number board + ticket view.

**3.3 Horse Book (Off-Track Betting)** — the handicapper
- Purpose: betting on a story: six named horses, a radio call, a photo finish.
- Function: win/place/show + exacta; odds bands generated per race with hidden true odds; the race plays as a ~10-second animated call with lead changes; racing form items reveal information.
- Cheats: past-post the window (timing), tout collusion (pay a character for the fix — sometimes he's lying).
- Architecture: novelty family anchored to the OTB parlor; race sim = seeded segment-by-segment position updates rendered as a side-view strip; odds/true-odds generated from environment RNG fork.

**3.4 Five-Card Draw vs The Table** — the character game
- Purpose: poker against people, not the house — reads, bluffs, and grudges.
- Function: 3-4 recurring NPC opponents with distinct fold/bluff/call personalities and session memory; ante/draw/bet rounds; leaving while up creates social consequences (events later).
- Cheats: holding out a card (skill window), signaling with a bought partner (2-session setup), cold-deck swap (item-gated).
- Architecture: cards family; NPC policies as data-tuned deterministic decision tables seeded per run; personality memory in narrative flags; biggest new-module effort on this list — treat as its own epic if adopted.

**3.5 Bingo Night** — the innocent one
- Purpose: tonal contrast — the gentlest room in the game, and cover for a heat-cooldown loop.
- Function: buy 1-3 cards, numbers call automatically with daub interaction, multiple patterns (line, four corners, blackout) with escalating pots; jackpot ball countdown.
- Cheats: none available (venue rule) — that IS the design: the one place your habits are useless.
- Architecture: novelty family bound to church basement (2.4); auto-call cadence uses surface animation channels; low stakes tuned as heat-decay downtime.

**3.6 Punchboards** — pull tabs' older cousin
- Purpose: authentic period bar novelty; a 1000-hole board of tiny gambles with a visible prize sheet.
- Function: pay per punch, prizes listed on the header; the board depletes across ALL visits (persistent per venue instance) — late boards with unclaimed jackpots become mathematically hot; punch animation with a brass stylus.
- Cheats: weighted pen (feel the filled holes), header peek (see which prizes remain claimed — actually advantage play).
- Architecture: novelty family; reuses pull-tab finite-deal architecture (persistent deal state per environment instance already proven there).

**3.7 Big Six Money Wheel** — the barker's wheel
- Purpose: the simplest casino bet there is; a volume knob for casual gambling and a house-edge object lesson.
- Function: bet on symbols ($1/$2/$5/$10/$20/joker), wheel spins with clacker physics and near-miss drama; joker pays 40:1.
- Cheats: wheel gaffing observation (advantage — track a worn wheel's bias over spins in one venue), clacker timing read.
- Architecture: wheel family; simplest new module on the list — good first candidate; wheel render reuses roulette spin/celebration patterns; bias tracking = per-instance seeded wheel offset discoverable by counting.

**3.8 Backgammon Hustle** — stakes and doubling
- Purpose: the doubling cube is the purest gambling object ever made; hustle culture fits the bar rooms.
- Function: abbreviated backgammon (running game or race position abstraction, not full board play) vs patron hustlers; the core interaction is the doubling cube — offer/accept/drop decisions against read-able opponents; stakes escalate fast.
- Cheats: dice manipulation (shared with bar dice tech), sandbagging (lose small early to raise stakes — a social mechanic, not an action).
- Architecture: dice family; if full board play is too heavy, model as a position-value race with checkpoints where cube decisions occur; opponent cube policies data-driven.

**3.9 The Sports Book** — bets across time
- Purpose: long bets that resolve while you live your run; appointment tension.
- Function: bet fight cards / ball games listed on a chalkboard; results resolve N venue-actions or day-ticks later via radio broadcast events wherever you are; parlays for degenerates.
- Cheats: the wire (1.22 — early result knowledge), bookie credit line (6.4 ties in).
- Architecture: novelty family + event integration; pending bets in RunState with deferred resolution (shares the keno pattern 3.2); results generated at bet time (deterministic), revealed later.

**3.10 Faro** — the antique
- Purpose: the outlaw-era card game, kept alive in one underground room; deep-cut Americana that flatters connoisseurs.
- Function: bet on ranks against a dealing box; copper tokens to reverse bets; "calling the turn" for the 4:1 finale; a case-keeper (bead counter) tracks dealt ranks — the game literally comes with a counting device.
- Cheats: rigged dealing box (house cheats YOU — spotting it is the advantage play), case-keeper errors to exploit.
- Architecture: cards family scoped to the underground casino only; shoe logic via card_shoe.gd; case-keeper is the signature surface element.

**3.11 Coin Pusher** — the hypnotist
- Purpose: pure physics compulsion; the arcade cousin of the pinball rework.
- Function: drop coins onto a moving shelf; coins/prize tokens teeter on the edge; some pushes cascade; prize tokens redeem for items or cash.
- Cheats: machine nudge (shared tilt-meter concept with pinball), slug coins (contraband).
- Architecture: novelty family; ONLY build on the pinball rework's packed-array sim core (Epic 1) — same deterministic physics boundary, simpler board; do not attempt with the old dict-sim pattern.

**3.12 Chuck-a-Luck (The Birdcage)** — dice in a cage
- Purpose: a carnival-to-casino classic; three dice in a spinning hourglass cage, pure spectacle.
- Function: bet numbers 1-6; payout scales with how many dice show it; triple bonus; the cage flip is the whole show.
- Cheats: cage rhythm read (advantage timing), magnet ring (1.7-adjacent item synergy).
- Architecture: dice family; small module — bar_dice rendering DNA with a cage animation; good filler game for tier-1 variety.

**3.13 Liar's Poker (Serial Numbers)** — bar bills game
- Purpose: gambling with the money itself — bluffing over dollar-bill serial numbers.
- Function: each player "holds" a seeded bill; bid escalating claims about combined digits; challenge or raise; wins take the bills. Compact, social, fast.
- Cheats: memorized bill swap (item: the Kept Bill), digit tells on patrons.
- Architecture: cards-family-adjacent logic with dice-family sociality; tiny state space — cheap module that adds bar texture; patron policies data-driven.

**3.14 Razzle** — the honest scam
- Purpose: a REAL carnival con presented honestly by the game: nearly unwinnable, and the design point is learning to walk away.
- Function: roll marbles for points toward a prize ladder that practically never pays; the barker offers "you're so close" escalations; quitting early is the win condition (small consolation + a narrative flag: you saw through it).
- Cheats: none needed — recognizing it IS the skill; a "call out the scam" action (with the right knowledge item) flips it into a confrontation event with payout.
- Architecture: novelty family, midway-scoped; deliberately negative EV with the walk-away flag feeding a "wise player" event later; strong tonal piece, cheap to build.

**3.15 The Numbers Racket** — the neighborhood lottery
- Purpose: pre-lottery street gambling; a daily three-digit draw run out of the laundromat.
- Function: pick 3 digits any time, draw resolves at the next day-tick from a deterministic seed; 600:1 on a straight hit (real numbers odds paid 600 on 1000:1 chances — the vig is the lesson); dream-book item suggests numbers (pure flavor).
- Cheats: bank runner tip (late knowledge of heavy-bet numbers), fixing the figure (deep event chain — becoming part of the racket).
- Architecture: novelty family + deferred resolution (keno/sports-book pattern); requires the day-tick concept — if runs lack a day cycle, resolve on Nth travel instead; laundromat-scoped (2.15).

---

## 4. Events

Events land in `data/events/events.json`: conditions (environment kind/tier,
heat band, items held, narrative flags, alcohol tier), choices with
consequence summaries, and flags for chains. `EventModule` resolves; copy must
fit validator limits.

**4.1 The Cooler Walks In**
- Purpose: casino superstition made flesh — the house's luck-killer.
- Function: while you're on a win streak, a gray man sits at your table; choices: keep playing (luck debuff this venue), move games (small fee/time), confront him (heat, but he leaves).
- Architecture: condition on session win-streak counter; luck debuff as a timed environment-scoped modifier.

**4.2 Health Inspector**
- Purpose: dive-bar reality; venues are fragile.
- Function: the bar is shutting down for the night — finish one more action, then travel is forced; slipping the inspector $20 keeps it open (flag: he remembers you).
- Architecture: bar-kind condition; forced-travel consequence via RunActionService; bribe flag enables a later repeat-extortion event.

**4.3 Rival Counter at the Table**
- Purpose: you're not the only advantage player in town.
- Function: another counter works your blackjack shoe; play through (pit attention rises for the whole table — including you), tip him off (he owes you — flag), or drop a word to the pit (he's ejected; you're clean but patrons mark you a snitch).
- Architecture: blackjack-scoped condition; attention modifier; two mutually exclusive flags feeding later payoffs (4.20, character 7.10).

**4.4 On the House**
- Purpose: the classic trap — free drinks are never free.
- Function: a comped drink arrives unasked; refusing offends the host (attention up slightly), accepting applies alcohol; a third option with the Thermos (1.8) sidesteps both.
- Architecture: casino tier-2+ condition; three-choice event demonstrating item-conditioned choices.

**4.5 The Invitation** — chain (3 parts)
- Purpose: gateway chain to the Union Hall game (2.8) or Penthouse (2.12).
- Function: (i) a player notices your action and mentions "a game"; (ii) vouching — a character asks a favor (deliver an envelope: travel + risk); (iii) the invitation route unlocks.
- Architecture: three events linked by escalating narrative flags; final consequence adds a requires-flag route.

**4.6 The Collector**
- Purpose: debt has a face and a schedule.
- Function: a lender's man appears when a payment is overdue; pay now, promise (interest bump + flag), or stand your ground (Brass Knuckles 1.27 changes the odds; failure = bankroll hit + heat).
- Architecture: condition on overdue-loan state; deterministic check using the skill-cheat check pattern; escalation ladder per missed encounter.

**4.7 Ticket on the Floor**
- Purpose: tiny found-money story with a hook.
- Function: a discarded keno/pull-tab ticket near the trash; cash it (small win, small chance the owner returns — awkward scene), hand it in (goodwill flag with staff), ignore it.
- Architecture: casino-kind condition; the owner-returns branch is a delayed follow-up event keyed on the flag.

**4.8 Raid Rumor**
- Purpose: heat weather-forecasting; tests trust in information.
- Function: a barfly whispers the underground room gets raided tonight; leave now (safe), stay (rumor true = mass heat event; false = tables empty out and odds soften).
- Architecture: underground-casino condition; truth determined at event time from seeded roll; both branches concrete.

**4.9 The Entourage**
- Purpose: whale weather — the room bends around big money.
- Function: a high roller arrives with a crowd; tables raise minimums (economy shift this visit), but staff attention is all on him (your attention accrual halves).
- Architecture: tier-2+ condition; temporary environment modifiers on stakes and attention scale.

**4.10 Shift Change**
- Purpose: the pit has rhythms; reward players who watch.
- Function: the pit boss hands over to a rookie — for the next N actions watched-cheat risk drops visibly; telegraphed a beat early so players can position.
- Architecture: casino condition; timed modifier on security_action_pressure inputs; HUD hint through the watch-status model.

**4.11 The Broken Machine**
- Purpose: moral gradient in one prop.
- Function: a slot pays out on a stuck reel unattended; scoop the tray (money + heat spike), report it (goodwill flag + tiny comp), walk on.
- Architecture: slot-venue condition; scoop consequence adds suspicion; report flag feeds staff-goodwill economy.

**4.12 The Counterfeiter's Offer** — chain
- Purpose: entry point to counterfeit chips (1.6) as narrative, not just an item.
- Function: (i) a printer offers a "sample" (gain item 1.6); (ii) if floated successfully, he proposes a bigger batch — real money, real exposure; (iii) the cage audit event resolves the arc either way.
- Architecture: chain flags; final audit event conditioned on counterfeit_chips_floated; ties to Grand Casino attention rules.

**4.13 Sub for the Trio**
- Purpose: jazz club payoff for musician-flavored runs.
- Function: the club's bass player is out; sit in (deterministic performance check where slightly drunk actually helps — a curve peaking at tipsy) for cash, reputation flag, and the musician reward path.
- Architecture: jazz-club-scoped; a rare positive-alcohol moment; check inputs are luck + alcohol tier curve.

**4.14 Payday Friday**
- Purpose: economy weather; the room floods with wages.
- Function: patrons everywhere, pots and table minimums swell, service prices bump, pickpocket risk while drunk; the best night to win and be seen winning.
- Architecture: day/venue condition; visit-scoped multipliers on stakes, pots, and event weights.

**4.15 Lights Out**
- Purpose: chaos window; the room's rules blink.
- Function: power cut mid-session — one free action while staff scramble (a cheat window with no watch), but when lights return the pit counts everything (attention spike for anyone who moved).
- Architecture: casino condition; grants a one-action unwatched modifier, then applies a retroactive attention check.

**4.16 They Caught a Card Cheat**
- Purpose: show, don't tell — the house's consequences performed on someone else.
- Function: security walks a cheat past you; watch quietly (your attention decays a touch — they're busy), or the cheat gestures at YOU on the way out (deterministic false-accusation check if your suspicion is high).
- Architecture: casino condition weighted by your heat band; the false-accusation branch is the punchline for dirty players.

**4.17 The Preacher Outside**
- Purpose: tonal breath; the world judges the spiral.
- Function: a street preacher outside the venue; listen (small luck buff, "someone prayed for you"), donate (bankroll dip, larger buff, flag), scoff (nothing — or is it).
- Architecture: street/shop condition; cheap flavor event with a light mechanical touch.

**4.18 Stormed In**
- Purpose: forced intimacy with a venue; weather as a wall.
- Function: a storm locks travel for N actions; the venue leans into it — free coffee (diner), storm specials (bar), a captive-audience card game spins up.
- Architecture: travel-lock consequence (shares 2.1's mechanism); spawns a bonus temporary game/service object in the room.

**4.19 The Hot Streak Problem**
- Purpose: winning is its own heat source.
- Function: after big session winnings the floor notices: cash out and cool off (bank it, leave), press on (stakes up, attention up), or spread it around (tip big: convert winnings into a goodwill flag).
- Architecture: condition on session net-win threshold; the tip-big branch feeds staff-goodwill used by 4.7/4.11 flags.

**4.20 A Favor Repaid**
- Purpose: payoff node for accumulated goodwill flags.
- Function: someone you helped (counter 4.3, staff goodwill, the Kid 7.9) returns the favor: a warning before a sweep, a route tip, or a debt payment covered — branch depends on which flags exist.
- Architecture: multi-condition payoff event checking several flags in priority order; the kindness ledger made visible.

**4.21 Bad Ice**
- Purpose: drink-economy texture; the house waters the well.
- Function: your drink's watered down — alcohol effect halves this round; call it out (comp voucher or attention, deterministic on venue tier), or let it slide.
- Architecture: bar/casino condition on drink purchase; small, frequently-eligible filler event.

**4.22 The Bus Leaves in Ten**
- Purpose: a decision clock; punish dithering deliciously.
- Function: the cheap route out is boarding NOW: take it (discount travel immediately) or stay (route disappears from offers for a while).
- Architecture: depot/street condition; consequence edits current route offers; teaches route-offer volatility.

**4.23 Wrong Pocket**
- Purpose: drunk-state consequence with comedy.
- Function: while drunk+, you realize you've been playing with the rent money — a chunk of bankroll is "committed"; win it back before leaving the venue or take an informal debt flag.
- Architecture: alcohol-tier condition; escrow mechanic on a bankroll slice with venue-exit settlement.

**4.24 The Whale's Marker**
- Purpose: found leverage; a rich man's debt in your hands.
- Function: a whale drops a signed marker (IOU); return it (reward + tier-2 goodwill flag), sell it to The Dentist (cash, dark flag), or keep it (dead item until the whale chain recurs — then it's leverage).
- Architecture: tier-2+ condition; grants a unique active item whose only use is in linked events; three-way payoff chain.

**4.25 Last Call**
- Purpose: end-of-night rhythm; venues should breathe.
- Function: the room announces last call — one more game action at boosted stakes ("nightcap odds"), then services close and travel is nudged.
- Architecture: action-count condition per venue visit; visit-scoped closing state that pools can react to.

---

## 5. Services

Services live in `data/services/services.json`, resolved by
`RunActionService`; each needs cost, availability conditions, effect, and copy.

**5.1 The Barber's Chair** — Purpose: a new man walks out. Function: pay to drop one attention tier and clear "recognized" flags in this venue; costs an action. Architecture: attention/flag mutation via RunActionService; barbershop prop in shop venues.
**5.2 Coat Check** — Purpose: don't carry it onto the floor. Function: stash contraband for the visit — sweeps can't find what you're not holding; retrieval on exit (forgetting is an event). Architecture: temporary inventory sublist keyed to venue visit; sweep checks skip checked items.
**5.3 Valet Stand** — Purpose: arrive like money. Function: tier-2+ entry; next travel from this venue is discounted and risk-free; small attention reduction on arrival. Architecture: travel modifier flag consumed on next route purchase.
**5.4 Madame Zora's Table** — Purpose: buy a peek at fate. Function: fortune reading reveals the band of your next event roll and +1 luck for N actions; her patter references your actual flags (reads the story log). Architecture: service reads flag state for copy assembly; luck timer standard.
**5.5 The Cage Advance** — Purpose: casino credit without a lender's face. Function: tier-2+ venues advance cash up to a bankroll-history limit; auto-collected from winnings at that venue; leaving with balance outstanding marks staff attention. Architecture: venue-scoped micro-loan on RunState with winnings-garnish hook.
**5.6 Western Union Counter** — Purpose: protect winnings from yourself. Function: wire money "home" — banked cash leaves bankroll, untouchable, counts toward victory accounting at run end. Architecture: RunState banked field; terminal evaluator includes banked totals; the anti-spiral pressure valve.
**5.7 Shoeshine Stand** — Purpose: the floor's intelligence network. Function: cheap; the shoeshine man tells you one true thing: pit boss mood, hot table, or tonight's event weighting. Architecture: info service surfacing one seeded fact from current venue state.
**5.8 The Steam Room** — Purpose: sweat it out. Function: motel/club service; clears one alcohol tier and a little heat; costs an action and cash. Architecture: standard stat mutation; pairs with 5.1 as a recovery suite.
**5.9 House Band Request** — Purpose: set the room's tempo. Function: pay the band to play slow (attention decays faster this visit) or hot (stakes/pots up, patrons loosen). Architecture: visit-scoped modifier via music profile hooks; jazz club/lounge only.
**5.10 The Doorman's Palm** — Purpose: the universal key. Function: grease a doorman — reveals whether a venue's special object is active before entry; sometimes opens requires-gated content for cash instead of flags. Architecture: preview + conditional gate bypass on route/entry checks.
**5.11 Taxi Stand** — Purpose: fast, safe, expensive. Function: premium travel to any discovered venue, no risk events; price scales with heat (drivers know a hot fare). Architecture: dynamic route pricing off heat band; complements bus/walking tiers.
**5.12 The Notary** — Purpose: paperwork as armor. Function: formalize one informal debt (brother-in-law, marker) into fixed terms — stops escalation events on it. Architecture: converts a debt record's event-chain eligibility; back-alley/pawn venue scoped.
**5.13 Confession Booth** — Purpose: absolution, statistically. Function: church venue; confess (free): clears snitch/dark flags others react to, tiny luck buff; the priest has heard worse. Architecture: flag-clearing service with a luck touch; pairs with 2.4.

---

## 6. Lenders

Lenders live in `data/debt/lenders.json` with offer scaling, interest,
schedule, and consequence hooks; RunActionService owns the lifecycle.

**6.1 Sal's Pawn Counter** — Purpose: collateral, not credit. Function: loans against a held item (item escrowed, unusable); repay to redeem; default = item gone forever, no other consequence. Architecture: loan record holds an item ref; the cleanest-consequence lender — the beginner loan.
**6.2 The Casino Line** — Purpose: respectable debt with teeth. Function: tier-2+ credit at low interest, but a missed payment marks staff attention EVERYWHERE (casinos talk) and can gate Grand Casino entry until settled. Architecture: default consequence writes attention flags across casino-kind venues.
**6.3 The Dentist** — Purpose: the shark you were warned about. Function: big principal, brutal weekly interest, collector events (4.6) escalate to a genuinely dangerous final visit; will always lend, even at heat 90 and bankroll 3 — that is the trap. Architecture: no availability conditions (always offers); the escalation ladder is his identity; the final event can end a run.
**6.4 Bookie Credit** — Purpose: bet now, owe later. Function: sports/horse wagers on credit up to a limit; losses become debt automatically; winning while owing pays him first. Architecture: game-integrated lender — modules check the credit flag at bet placement; winnings-garnish hook shared with 5.5.
**6.5 The Benevolent Fund** — Purpose: charity with a ledger of guilt. Function: church micro-loan, zero interest, but while owing: cheating anywhere sets a shame flag Deacon events call out, and bingo pays it down at a bonus rate. Architecture: conduct-conditioned lender; flag interactions over math.
**6.6 Your Brother-in-Law** — Purpose: family money, family strings. Function: one phone-call loan per run, fair terms; repay late and a recurring nag event plus a permanent story-log scar; repay early for goodwill. Architecture: single-use lender via a phone service object; the consequence is narrative, not financial.
**6.7 Paycheck Advance Window** — Purpose: the legal trap. Function: small instant loans, fee not interest — but each rollover doubles the fee; the storefront math lesson. Architecture: fee-schedule lender (rollover counter, no compounding field); teaches the difference viscerally.
**6.8 The Widow Malone** — Purpose: kindness as the heaviest debt. Function: generous terms from the boarding-house widow; no collectors — but defaulting permanently closes her lending AND her venue's recovery services, and the story log never forgets. Architecture: consequence = content removal, not events; the moral-weight lender.
**6.9 The Jeweler's Consignment** — Purpose: liquidity for the item-rich. Function: hands you a saleable luxury item to sell anywhere at market; you owe its value +20% — sell high at the right venue and pocket the spread. Architecture: loan disbursed as an item with a debt attached; venue-economy price variance makes it a trading minigame.
**6.10 The Crew** — Purpose: borrowing from people with plans for you. Function: street crew lends free — repayment is favors: their events (deliveries, lookout jobs, a fix) arrive on THEIR schedule until the marker's clear; refusing a favor converts the debt to cash at Dentist rates. Architecture: debt denominated in event-completions; a lender that generates content instead of interest.

---

## 7. Recurring Characters

Characters are not a data pack today; they live as event casts and flags.
Architecture note for all: implement as a character registry (id, name, home
venues, disposition flags) referenced by events/services so one person can
recur — the cheapest way to make the world feel authored. Rourke proves the
pattern.

**7.1 Fast Eddie** — Purpose: the proposition hustler; the tutorial in human form. Function: offers prop bets (liar's poker 3.13, bar bets) that are always slightly against you — until you own the right item or flag, then he respects you and sells info instead. Architecture: event cast + disposition flag flip on first win against him.
**7.2 Miss Dora** — Purpose: the fortune teller (5.4) as a person, not a kiosk. Function: her readings improve with visits; at trust 3 she reads something true about the endgame (a Grand Casino hint). Architecture: per-character trust counter in flags; service copy tiers off it.
**7.3 The Dentist** — Purpose: the shark (6.3) embodied; the run's recurring dread. Function: appears in venues when you owe him; polite, precise, escalating; some events let you work off debt in favors instead of cash. Architecture: lender-bound character; his presence is a spawned venue object while debt is overdue.
**7.4 Officer Kowalski** — Purpose: the beat cop who knows your face. Function: neutral at low heat (small talk events), a real problem at high heat (stops that cost time/money), bribable exactly twice per run — the third attempt is a sting. Architecture: heat-band-conditioned street events with a hard-coded bribe counter; the sting is the payoff for greed.
**7.5 Ruby** — Purpose: the bartender; the game's warmest NPC and its alcohol governor. Function: sells drinks, cuts you off when you're deep (a mercy mechanic), remembers tips (goodwill flags), and slides you 4.20-class favors. Architecture: service-attached character; her cut-off is a soft cap on alcohol purchases per visit at high tiers.
**7.6 Deacon Jones** — Purpose: conscience of the bingo basement (2.4, 6.5). Function: judges flags (shame/snitch/dark), rewards clean streaks with benevolent-fund terms, delivers the game's only unconditional kindness event when you're near bankroll-zero. Architecture: flag-reactive event cast; his charity event is the anti-frustration valve for busted runs.
**7.7 Vegas Vic** — Purpose: the washed-up pro; the ghost of the player's future. Function: found at bars; drinks with you (shared alcohol events), teaches one real technique per run (unlocks an advantage action tier in one game), and his stories foreshadow endgame mechanics. Architecture: mentor flag granting a per-game advantage unlock; strong tutorialization channel.
**7.8 Lefty** — Purpose: the dealer who deals seconds; the house cheats too. Function: at his table the house edge is silently worse — spotting him (observation cue in the deal animation) unlocks confront/report/extort choices. Architecture: a dealer variant flag on card game instances; the visual tell is a renderer state; extortion feeds a dark flag.
**7.9 The Kid** — Purpose: the lookout you can invest in. Function: hire him cheap outside dive venues — he warns before sweeps/raid events (one-event lookahead); pay him fairly across a run and 4.20 pays it back big; stiff him once and he's gone. Architecture: hired-state flag with a per-venue warning hook into event scheduling.
**7.10 The Counter** — Purpose: the rival from 4.3 given a life. Function: shows up at blackjack rooms on his own circuit; your 4.3 choice sets him as friendly (shares shoe intel), neutral, or hostile (he tips the pit about YOU). Architecture: disposition flag from 4.3 drives three event variants; the game's cleanest consequence-echo character.
**7.11 Mr. Pemberton** — Purpose: the whale (4.9, 4.24); gravity for the tier-2 economy. Function: where he plays, stakes rise; befriend via the marker chain and he vouches you into the Penthouse (2.12); embarrass him and tier-2 doors cool. Architecture: character flags gating the 2.12 route; his presence modifier reuses 4.9's mechanics.
**7.12 Sister of the Player** — Purpose: the phone call home; the run's emotional anchor. Function: periodic payphone events — she asks how you're doing; lying while deep in debt sets a weight flag; honesty unlocks the brother-in-law loan (6.6) warmly instead of coldly. Architecture: payphone service object + periodic event chain; pure narrative system glue.

---

## 8. Cheats & Advantage Techniques

All implement the Epic 2 skill-cheat contract: multi-step interaction, skill
check (timing/memory/observation), graded outcomes, suspicion/watched
integration via security_action_pressure, story context for clean-vs-cheat
tracking. Marked [A] = legal advantage play (no cheat evidence), [C] = cheating.

**8.1 Hole Carding [A]** — Purpose: the premier legal edge. Function: blackjack/baccarat — a sloppy dealer flashes cards; an observation minigame (spot the flash window) grants partial next-card knowledge; entirely legal, so no evidence — but staring draws attention anyway. Architecture: dealer-sloppiness as a seeded table trait; observation window in the deal animation; knowledge as a surface hint tier.
**8.2 Shuffle Tracking [A]** — Purpose: counting's big brother. Function: blackjack — follow a rich card clump through the shuffle animation (memory challenge across the shuffle); success biases your bet timing next shoe segment. Architecture: shuffle rendered as trackable segments; challenge state machine like count_challenge; effect = temporary true-count bonus.
**8.3 Wheel Clocking [A]** — Purpose: roulette's honest edge. Function: track a worn wheel's bias across N spins in one venue (observation log the player fills); a clocked wheel reveals a hot octant. Architecture: per-instance seeded wheel bias (small, real); a player-facing tally card surface; pays off only with venue loyalty.
**8.4 Dice Sliding [C]** — Purpose: the craps cheat with a visible tell. Function: timing challenge on the throw — a slid die doesn't tumble; graded success keeps one die fixed; the no-tumble animation IS the risk (watchers may notice even on success). Architecture: craps (3.1) throw input window; success probability separated from detection probability — the contract's cleanest two-axis example.
**8.5 Past-Posting [C]** — Purpose: already planned for roulette (Act 1 board T2.4); listed for completeness. Function/Architecture: see the skill-cheat design doc task.
**8.6 The Cold Deck Swap [C]** — Purpose: the movie move. Function: poker (3.4) — swap a prepared deck in during a distraction event (requires item + an active distraction like 4.15); one guaranteed monster hand; the highest-evidence act in the game. Architecture: multi-precondition cheat (item + event window); on success sets permanent open-cheat evidence; the deliberate point-of-no-return for clean routes.
**8.7 Rathole [C-gray]** — Purpose: chip palming — hide winnings from the house's accounting. Function: pocket chips mid-session (timing window per palm); ratholed money doesn't count toward the session-win attention triggers (4.19) but is evidence if searched. Architecture: splits bankroll into visible/pocketed at venue scope; sweeps/searches check pocketed value; heat-management as sleight of hand.
**8.8 The Signal Partner [C]** — Purpose: collusion; cheating as a relationship. Function: recruit a character (the Kid grown up, a bought patron) over 2 events; thereafter a signal action in card games grants info at shared risk — if HE'S caught, he might name you (his loyalty flag decides). Architecture: partner state + loyalty flag; detection resolves against the partner first; betrayal event closes the arc.
**8.9 Slot Stringing [C]** — Purpose: the period coin-on-a-string classic. Function: slots — a timing challenge on coin insert; success = free credit; machines "learn" (per-machine attempt counter raises detection each try). Architecture: slot module cheat action; per-machine-instance counters; coordinate with pinball rework before touching slot internals.
**8.10 Keno Crayon [C]** — Purpose: paper-era forgery. Function: alter your keno ticket after the draw (memory + timing: recreate the winning marks in the writing style check); small wins only — big forged wins are always audited. Architecture: keno (3.2) post-draw action; auto-audit threshold makes greed self-punishing.
**8.11 The Pigeon Drop [C]** — Purpose: a street con — cheating people, not houses. Function: street venues — run a short con on a patron mark (multi-step social event with reads); pays cash, no casino heat, but dark flags and a chance the mark had friends. Architecture: pure event-chain cheat with no game module; consequences live in the character/flag layer.
**8.12 Bet Capping [C]** — Purpose: the simplest chip cheat. Function: add chips to a winning bet in the payout beat (short timing window every win); tiny gains, low individual risk — but the contract's suspicion accumulates per attempt, making it the death-by-a-thousand-cuts trap. Architecture: generic table-game action available in roulette/blackjack/craps; identical window logic shared via GameModule helper.
**8.13 The Tell Book [A]** — Purpose: people-reading as collectible knowledge. Function: poker/bar dice — each session with a recurring character logs observed behavior; at 3 logs their bluff/fold tells surface in UI. Architecture: per-character observation counters; pure info-tier reward; pairs with the character registry (7.x).

---

## 9. Challenges

Land in data/challenges/challenges.json (Act 1 board T5.2): id, title,
description, modifier set on challenge_config, completion flag to profile.

**9.1 Dry Run** — no alcohol services or items; luck floor lowered. Tests play without the luck lever. Architecture: content-group exclusion + stat clamp.
**9.2 Debt Spiral** — start owing The Dentist $300; he's already calling. Architecture: initial debt record + collector event pre-armed.
**9.3 Clean Hands** — cheat actions disabled everywhere; high-roller target reduced 25%. The purist route as a formal mode. Architecture: global cheats_disabled + objective override.
**9.4 Heat Wave** — heat decays at half rate; bribe/barber services 30% cheaper. Heat management as the whole game. Architecture: decay modifier + service price overrides.
**9.5 One Machine** — slots-only content group; adjusted economy; the pinball/buffalo feature events carry victory. Architecture: existing content-group machinery, tuned targets.
**9.6 Graveyard Shift** — all venues in permanent last-call state: fewer patrons, nightcap odds always on, event pool skews strange. Tone showcase. Architecture: forced visit-state flag + event weighting set.
**9.7 The Whale Run** — start with $2,000 and a $5,000 target; stakes floors tripled. Variance appreciation course. Architecture: start/target overrides + stake floor multiplier.
**9.8 Barred** — every venue locks behind you on exit (no revisits). Roguelike routing pressure at maximum. Architecture: route pruning on travel; requires enough venue supply (post-T4.1).
**9.9 Lightweight** — alcohol effects doubled (both luck AND impairment). The drunk build turned up to eleven. Architecture: alcohol effect multiplier in challenge modifiers.
**9.10 Shark Bait** — lenders always available with double limits; victory requires zero outstanding debt. Borrowing as core mechanic. Architecture: lender availability override + victory condition addendum.
**9.11 Pilgrim** — victory additionally requires visiting every venue archetype at least once. The tourist route. Architecture: visit-set tracking against archetype list; HUD checklist.
**9.12 The Anniversary** — every game's stakes and payouts doubled; heat gains doubled. Short, loud runs. Architecture: global multipliers; the streamer mode.

---

## 10. Travel & World Systems

Routes live in data/travel/routes.json; travel resolution in
RunActionService; these entries add systemic depth rather than single venues.

**10.1 Transit Tiers** — Purpose: make "how you travel" a decision. Function: walking (free, event-heavy), bus (cheap, scheduled), taxi (5.11: instant, heat-priced) as parallel offers per destination. Architecture: route entries gain a mode field with cost/risk/availability profiles.
**10.2 Route Rumors** — Purpose: scouting economy. Function: rumors (from shoeshine 5.7, barflies, the Kid) attach preview info to specific route offers — "the Meridian's hot tonight" — with a reliability stat. Architecture: preview payload on route offers; reliability resolves at arrival (rumor sources build track records via flags).
**10.3 Police Checkpoints** — Purpose: contraband risk while moving. Function: some routes roll a checkpoint event: holding contraband = confiscation/heat unless checked (5.2) or stashed (10.4); clean players breeze through with a story beat. Architecture: route risk-event hook conditioned on inventory class scan.
**10.4 The Depot Locker** — Purpose: strategic stashing. Function: rent a locker (2.10) to store items/cash mid-run; retrieve on any depot visit; lockers survive save/load, not run end. Architecture: RunState stash sublist + locker service actions.
**10.5 Day/Night Ticks** — Purpose: give the world a clock without a calendar. Function: every N travels advances a day-tick driving: numbers draws (3.15), sports results (3.9), payday events (4.14), route availability windows (2.8, 2.11). Architecture: a single counter on RunState with subscriber hooks; the smallest change that makes many entries above possible.
**10.6 Weather Fronts** — Purpose: route texture. Function: a seeded weather state per day-tick: rain cheapens cabs' appeal (walking risk up), storms enable 4.18, heat waves push drink economies. Architecture: day-tick-derived state consumed by route generation and event weights.
**10.7 The Long Way Around** — Purpose: risk-graded pathing. Function: every destination offers a safe-expensive and a cheap-risky route variant where geography allows; the risky one carries the checkpoint/shakedown pool. Architecture: paired route entries with shared destination, distinct risk pools.
**10.8 Burned Venues** — Purpose: consequences with geography. Function: catastrophic exits (caught cheating, defaulted widow, stiffed the Kid) can burn a venue — barred for the run, its routes pruned, its regulars remembering. Architecture: venue-barred flag consumed by route generation and character events.
**10.9 The Circuit** — Purpose: reward planned loops. Function: revisiting venues in a repeatable loop builds regular status per venue (Regular's Jacket 1.10 synergy): better service prices, softer attention starts. Architecture: visit-count tiers per venue instance; small compounding modifiers.
**10.10 The Strip (Act 2 seam)** — Purpose: the horizon. Function: a permanently visible, permanently locked route — "The Strip — 1,400 miles" — whose lock copy changes after Act 1 victory; pure foreshadowing. Architecture: display-only route entry; the world's edge made concrete (ties to Act 1 board T8.1).

---

## 11. Prestige / Meta Purchases

Land in data/prestige/purchases.json (currently empty; Act 1 board T5.1
decides Act 1 posture — most of these are Act 2 material, logged now so the
decision has a menu).

**11.1 The Lucky Start** — begin runs with one common item slot pre-filled from a small pool. Architecture: run-generation inventory injection.
**11.2 Hometown Reputation** — choose your starting venue archetype. Architecture: run_generator start-selection override.
**11.3 The Seed Library** — save/replay favorite seeds with a label; pure QoL. Architecture: profile-stored seed list surfacing in the start menu.
**11.4 Known Associate** — start with one character disposition pre-warmed (Ruby, the Kid, Miss Dora). Architecture: initial flag injection; requires the character registry.
**11.5 The Wardrobe** — cosmetic outfits with a whisper of mechanics (Sunday Suit start, Snakeskin swagger) — one minor start modifier each. Architecture: cosmetic id + small start effect; render via player prop in pixel_scene_canvas.
**11.6 A Backer's Stake** — start with +$100 but owe the backer 20% of victory winnings (recorded on the victory screen). Architecture: start bankroll + victory accounting deduction; prestige with teeth.
**11.7 The Long Memory** — story-log highlights from past runs appear as bar gossip in new runs ("heard about a guy who..."). Architecture: profile run-history sampled into event copy; the game remembering itself.
**11.8 Act Select** — after first Act 1 victory: start future runs at tier-2 with scaled bankroll. Architecture: run-generation preset; the replayer's respect.
**11.9 The Scrapbook** — unlockable gallery: characters met, games mastered, endings reached; completion teases hidden content. Architecture: profile collection flags + a menu view; pure retention texture.
**11.10 House Rules** — unlock run modifiers as toggles (mix challenge modifiers freely, unranked). Architecture: challenge_config free-composition mode gated on challenge completions.

---

## 12. Sifting guide

- Cheapest high-impact picks: Big Six (3.7), Punchboards (3.6), Razzle (3.14),
  the Cooler (4.1), Shift Change (4.10), Western Union (5.6), Sal's Pawn
  (6.1), Wheel Clocking (8.3), Dry Run / Clean Hands (9.1/9.3), Transit Tiers
  (10.1).
- Entries that unlock many others: Day/Night Ticks (10.5) enables 3.9, 3.15,
  4.14, 2.8, 2.11; the character registry (7.x note) enables 4.20, 8.8, 8.13,
  11.4, 11.7; the deferred-resolution pattern (3.2) enables 3.9 and 3.15.
- Biggest builds (own epics if adopted): Craps (3.1), Draw Poker vs NPCs
  (3.4), the Penthouse Game (2.12), the Signal Partner (8.8).
- Respect standing constraints: anything touching slots (1.25, 8.9, 3.11)
  waits for the pinball rework to land; new games follow the GameModule +
  skill-cheat contracts; all randomness through RngStream.
