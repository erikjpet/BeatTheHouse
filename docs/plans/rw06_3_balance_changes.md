# rw06_3 balance changes

Scope: ending-route economy data only. Game rules, wager math, payout tables and
RTP are unchanged.

## Grand invitation package

Status: implemented; lightweight JSON/PowerShell checks and the combined replay
source contract pass. Focused Foundation evidence and the post-change route
measurement remain pending the accepted rw06_1 landing and an authorized engine
slot.

- `grand_casino_invite.accept_invite` bankroll grant: absent / `$0` -> `$50`.
- `grand_casino` route comp origins: absent -> exactly
  `kitty_cat_lounge`, `delta_queen`, and `beach`.
- Player-facing effect: accepting the invitation explicitly says that the host
  comps a first `$50` stake; Grand travel is free from either normal invitation
  venue and from the Q-011 Beach detour.

Reason: Clean Probe 29 followed only deterministic, public liquidity and ended
at `$126` cash with a displayed `$95` Grand fare and a required `$50` playable
stake. The resulting `$145` entry requirement left a measured `$19` shortfall.
Twenty-four straight lowest-stake Slot losses in Probe 19 also show that a
gambling win is not an acceptable deterministic recovery requirement.

Projected effect pending the post-change replay:

- Before: `$126 - $95 fare = $31`, which is `$19` below the `$50` stake floor.
- After, on the same Kitty/Delta/Beach invitation route: the `$50` grant raises
  the checkpoint to `$176`, and the comped ride preserves all `$176` on Grand
  arrival. That is a deterministic `$126` margin above the immediate `$50`
  stake floor, subject to confirmation by the next no-retry replay.
- A player who accepts at `$1` reaches `$51` and can enter with the full stake.
  Zero bankroll remains terminal; absent an existing Rook discount, non-comp
  origins keep the positive authored fare. Ordinary global travel locks still
  apply.

This is one authored invitation package, not two independent tuning passes: the
grant supplies the promised first stake and the three-origin comp prevents that
stake from being consumed by the invitation trip. Reckless pre-invite losses,
all game variance, the `$70` base fare from other origins, and bankruptcy risk
remain intact.

The package intentionally moves its two coupled data fields together, so it is
the one documented exception to the ordinary one-change-at-a-time diagnostic
sequence. No later balance value may change until a real Clean replay measures
the combined package and the Cheat/Heist public curves exist. Accepting the
invitation awards the `$50` only once, after which it is ordinary bankroll; the
eligible-origin travel comp is repeatable under the current data model.

## Finished-route balance pass (2026-09-25)

### Clean / Players Card

- Data change: none.
- Reason: the completed normal-use Clean replay took 197 player actions, inside
  the 150–350 target. It ended debt-free with `$37`, after `$120` of Blackjack
  inflow, `$63` of event inflow, and `$37` of travel spend. Raising prices,
  reducing rewards, or extending the Players Card gates would add risk to an
  already correctly paced route; lowering them would shorten it unnecessarily.
- Measured effect of the existing invitation package: the route reached the
  Gold Players Card without a loan or a lucky recovery requirement. The `$50`
  invitation stake and eligible-origin `$0` Grand trip remain unchanged.
- Final confirmation: the single permitted post-tuning replay again reached
  `players_card` in exactly 197 player actions. No Clean price, reward, lender,
  or Players Card gate change was needed.

### Cheat / Rourke

- Grand Casino `showdown_heat_threshold`: `70 → 85` in every Grand room's
  shared objective data.
- Reason: the completed deterministic Cheat replay took 101 player actions,
  below the normal-player guideline but appropriate for an optimized fast
  route. Aligning the ordinary heat call with the existing 85-heat Pit Boss
  warning requires a normal heat-driven player to survive another visible
  pressure cycle instead of receiving Rourke's call immediately after the
  65-heat Floor Staff warning. The separate `$30` dirty-money trigger remains
  available to a profitable cheater, and the 95-heat forced call remains the
  hard ceiling, so legitimate fast finishes are preserved.
- Measured effect: the single permitted post-change replay reached
  `showdown_survived` in 118 player actions, up from 101 (`+17`). The fixed
  replay is an optimized legitimate fast route: it deliberately uses public
  watched-cheat pressure and ordinary visible decisions to reach Rourke, so it
  remains allowed to finish below the 150-action normal-player guideline. The
  ordinary heat path now waits through the 85-heat Pit Boss warning, while the
  `$30` dirty-money route and 95-heat forced ceiling still preserve faster
  skilled or profitable finishes.

### Prices, rewards, and lender terms

- No additional change after the finished-route measurements. Clean ended at
  197 actions and Cheat ended debt-free with `$46`; both routes already carry
  meaningful travel and bankroll pressure. Increasing prices or weakening the
  `$50` invitation reward would threaten deterministic entry, while cheaper
  prices or softer lender terms would reduce bankruptcy risk without solving
  an observed route-length problem. Heist-related prices, Crew rewards, lender
  terms, and gates remain untouched until Lane C finishes its route.

### Final-push T2 confirmation (2026-09-25)

- Clean reached `players_card` in 197 player actions on current `main`. Its
  rendered money curve was `$80 -> $100 -> $108`, then travel and the hallway
  event moved it through `$101 -> $95 -> $105 -> $97 -> $81`; the invitation
  raised it to `$131`, the comped Grand trip preserved `$131`, and the `$50`
  cage exchange left `$81` cash / `$50` chips. The table route peaked at
  `$193` chips and ended debt-free with `$68` cash. This stays inside the
  150-350 normal-player target, so no Clean data changed.
- Cheat reached `showdown_survived` in 117 player actions. Its rendered money
  curve was `$80 -> $100`, then travel moved it through
  `$94 -> $89 -> $82 -> $54`; the invitation raised it to `$104`, the comped
  Grand trip preserved `$104`, and the cage exchange left `$54` cash / `$50`
  chips. The route then moved through `$41 -> $39` chips while pressure rose,
  collected the authored `$10` comp and `$15` Rourke event rewards, and ended
  debt-free with `$79` cash / `$39` chips at 89 heat.
- The one-action difference from the earlier 118-action Cheat confirmation is
  route-driver timing, not a new economy change. This remains an explicitly
  allowed optimized fast route. The ordinary showdown threshold stays at 85,
  the forced ceiling stays at 95, and the profitable dirty-money trigger
  remains available.
- Final T2 tuning decision: no further prices, rewards, lender terms, or gates
  changed. The Clean route is in range; slowing the intentional Cheat fast
  route would undercut legitimate fast finishes without evidence that a normal
  player's route is too short. RTP, odds, wager rules, and payout tables remain
  unchanged.

### Heist / The Count (final-push T4, 2026-09-25)

- Count-only Crew transport: the required Punchline-to-Grand setup/play leg
  changed from the `$70` base fare to `$0` (the preserved run's one-use Rook
  display was `$35 -> $0`); Grand-to-Punchline setup travel changed
  `$5 -> $0`; and the marked Grand-to-Delta getaway changed `$12 -> $0`.
  Combining identity with setup makes the minimum required Count path
  `$232 -> $0` across three outbound trips, two returns, and the getaway. A
  dedicated identity round trip followed by setup would be `$307 -> $0`.
  Only the Count's authenticated setup, play, and marked-getaway legs are
  covered. Global fares, Rook's one-use ride, travel heat/risk, and non-Count
  routes are unchanged.
- Count live-table liquidity: no Crew stake / `0` chips -> one-time `24` chips
  at authenticated play start, persisted in the play state. This is exactly
  three `$8` minimum blackjack hands. The completed run reached valid Count
  play with `$5` cash and no chips before this change, so the authored
  three-hand requirement otherwise had a deterministic liquidity dead end.
  Blackjack stakes, odds, RTP, and payouts are unchanged.
- Count schedule gate: Grand Heat cap `40 -> 55`, aligned with the existing
  Crew lookout band; the nine-action live-table window now includes its ninth
  action. The observed normal return reached Grand at Heat 53, and the third
  required minimum hand occupied the final authored boundary. Global heat
  rules, travel risk, wagers, odds, and payouts are unchanged.
- No automatic heat cooldown remains. The completed run recovered normally by
  taking the public Cage ATM draw and buying cheap Pull Tabs, moving from `$3`
  cash / Grand Heat 62 to `$39` cash / Grand Heat 47 before the retry. The
  unchanged Grand trip then arrived within the Heat 55 schedule cap.
- Final confirmation: the same normal-play Count run completed at gameplay
  action 184 (bridge command 998) with Bishop as its sole required specialist
  and reached `heist_somebody_got_pinched`. Its late curve entered final play
  at `$13` cash, used the one-time `24`-chip table float for the three required
  hands, and finished with `$733` cash, `46` Grand chips, and `$149` of Grand
  Casino ATM marker debt after the `$720` Heist payout. The public result also
  records `$366` put to work and a `$45` Crew settlement.
- Tuning decision: 184 gameplay actions is inside the 150-350 normal-player
  target. The scoped transport and table-float changes remove deterministic
  dead ends without slowing jackpots or changing any game payout, RTP, or
  global lender term; no further Heist economy change is needed.

### Owner-directed Heist pacing correction (2026-09-25)

The owner clarified that the normal Count route's authoritative length is the
998 normal-play bridge actions, not the 184 simulation-action counter. T4 was
therefore reopened and the prior in-range conclusion withdrawn.

- Count replay gate alignment: the release route's required Bishop standing is
  Associate rather than Inner Circle, so the normal replay no longer performs
  the obsolete twelve-job promotion grind. The deferred Made/Inner Circle arc
  remains in `docs/plans/0.6.1_backlog.md`.
- Count identity setup: three Grand visits / `$125` staged chips / a variable
  `$8-$30` qualifying hand -> one Grand visit / `$8` staged chips / exactly one
  ordinary `$8` qualifying hand. The one-session gate had already landed for
  the release route; this pass caps its authored stake at the minimum and
  brings the replay and economy audit into agreement with it.
- Crew marker terms: fixed `$45` principal with two favors -> fixed `$70`
  principal with one favor. Refusing the remaining favor converts it to the
  same `$70` principal before the unchanged 35% conversion interest. The extra
  `$25` covers the normal `$70` pre-plan Grand fare deterministically, removing
  slot or event-income grinding before Bishop; eliminating the second favor
  removes one complete timed delivery loop.
- Unchanged boundaries: Count-only required travel remains `$0` after the plan
  locks; the one-time live-table float remains 24 chips; global travel prices,
  blackjack minimum stakes and rules, odds, RTP, and the `$720/$900/$1,150`
  Count payout ladder are unchanged. Jackpot and unusually profitable routes
  can still finish sooner.

One fresh normal replay is required below before T4 closes.

## Departure-price integrity repair (rw06_2 blocker fix)

The balance data exposed an existing travel transaction defect: the map priced
the route from the departure room, but production installed the destination and
then recomputed the charge from that new room. A comp could therefore render as
`$0` and still deduct the full fare after arrival.

This is classified as an rw06_2 arc fix, not another balance lever.
`FoundationMain` now snapshots the authoritative route status at departure and
uses that same status when constructing the arrival result. The exact focused
gate confirms real Delta-to-Grand travel preserves a `$51` bankroll, records a
`$0` route cost, and starts Grand net winnings at zero; its real Bar-to-Grand
control deducts the positive departure fare exactly once.
