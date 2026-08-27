# 0.6 cross-system economy and difficulty audit

Status: **PARTIAL HANDOFF**. The source model and opt-in harness prototype exist,
but the required multi-seed complete-run distributions, ranked economic
findings, and proposals are **NOT STARTED**. One deterministic point sample per
playstyle and one eight-action smoke sample per playstyle were measured. They are
recorded below as prototype evidence only, not as balance conclusions. This row
reports and proposes; it does not authorize or apply tuning.

The exact harness scripts exercised by the archived precommit runs are committed
unchanged at `e74a57cebbda198cda9c1a95ada1c2081f1bb7c6`. The embedded artifact label is
`WORKTREE-PRECOMMIT`; at run time the tracked tree was `3d4a41da...` plus exactly
the two script blobs later frozen by `e74a57ce...`.

## Scope and authority

The audit reads the landed economy at the Wave 1 claimed base and exercises it
through `tools/cross_economy_audit.gd`. Product values are unchanged. The source
authority is `data/economy/content06_1_audit.json`, the Crew jobs/plays/Numbers/
heist catalogs, all item/service/lender/travel/event/game catalogs, their
production modules, `tools/coin_pusher_ev_harness.ps1`, and the economy rulings
in the 0.6 board.

The existing content audit is binding context, not a result: it says no tuning
is authorized, that Numbers cuts must remain below a strong table session in
aggregate, that coin-pusher tray collection is the only cash-credit boundary,
that Crew rewards are bounded by completed work, and that heist payouts are
terminal and non-repeatable.

## Source and constraint model

Status: **PARTIAL**. The grouped register and machine-readable source register
are implemented, but they have not received an independent completeness review.
No product values were changed.

All dollar figures are within-run cash unless stated otherwise.

| System | Sources | Sinks / exposure | Gates, caps, and rate limits | Constraint register |
| --- | --- | --- | --- | --- |
| Start / terminal | Run starts at $100. Act 1 ends through the Grand Casino or `crew_heist` routes. | Bankroll zero, stranding, police capture, or the casino back-room failure are terminal. | Grand Casino travel is $70; Gold review requires five settled games and $30 net with the release heat restrictions. | Shared bankroll, heat, action clock, travel graph, terminal state. |
| Eleven games | `scratch_tickets`, `pull_tabs`, `slot`, `bar_dice`, `blackjack`, `baccarat`, `craps`, `roulette`, `crew_draw_poker`, `video_poker`, and `coin_pusher` credit their production-module payouts. | Stakes are paid from cash or the authored Grand Casino chip rack. Game-specific settlement, inventory, table, and stock limits apply. | Venue stake floors/ceilings, bankroll/chip capacity, finite ticket/tab stock, session state, heat/security, and terminal checks. Descriptive `legal_actions` percentages are not treated as authoritative EV where a full production module owns a richer paytable. | Mostly shared bankroll/heat; independent stock, table/session, and game-specific skill windows. |
| Coin pusher | Paid-origin coins crossing the physical tray edge; Ridge multiplier credit; separately reported Vault option cash and $4/$7 rider values. | $1 per accepted drop. Paid gutter coins are terminal loss. Opening stock is excluded from paid-origin ROI. | One persistent generated machine per seed; no favorable reset; 160-body production cap; authored physical ROI bands Quarter `[0.72,0.94]`, Ridge `[0.70,1.08]`, Vault `[0.72,0.94]`; Vault cash option value stays separate. | Shared bankroll/heat; independent machine stock, variation schedule, alarm tolerance, tray collection timing, Vault fragments. |
| Crew jobs | Package $24/$32/$40; Numbers routes $34/$42; lookout $28/$30; stake-job posted reward $8/$10/$14 plus a finite crew stake; collections $22/$28 friendly or $38/$46 pressed. | Ordinary route/time exposure, cargo heat, stake losses, and optional repayment; failed/expired jobs cost 4-7 trust and can add grievances. | Member presence, Associate/Made rank, 10-22 action expiry, delivery/hold/session completion. The catalog has no universal per-run completion cap, but one matching job instance cannot be pending twice. | Shared actions/travel/heat; independent per-member trust, job expiry, grievance, and job-kind completion. |
| Coordinated plays | Spotter improves four blackjack boundaries; Distraction removes 18 heat; Big Player consumes a warm count; Chip Dump conservatively converts $40 cash to chips; Table Flood reduces detection to 60%. | Spotter $8, Distraction $10, Big Player $14, Chip Dump $6 fee on the player-funded $40 transfer, Table Flood $16. Detection can add 10-14 heat; security consequence threshold is 65 heat. | Made rank, physical presence, game context, active-window cap 1 except Spotter+Big Player, 1-2 uses/run, 5-8 boundary cooldowns. | Shared cash/heat; independent uses, cooldowns, presence, pair/window state. |
| Numbers honest book | Straight gross return 0.50/$; best distinct-digit box gross 0.42/$. Straight pays 500:1 capped $5,000/slip; box 70:1 capped $1,400; declared pool cap $9,000. | $1-20 stake/slip. | 24 actions/day; post at 16, settlement at 21; signed venue closes; physical venue and contraband slip marker. | Shared bankroll/actions/heat; independent day/venue close, pool and slip caps. |
| Numbers runner / fix | Runner pays 18% of 3-4 venue bags worth $35-70 each. Fix cut is 10-28% of the $240 crew pool (authored $24 minimum). | Fix allocation target is $60 across at least three venues, no venue over 45%; concentrated operation adds 18 heat. | Lucky Associate for runner; Lucky and Mags Made for fix; real delivery deadlines, sweep pause/reroute, retry one day after failure. | Shared actions/routes/heat; independent Lucky/Mags trust, delivery state, day retry, allocation concentration. |
| Numbers past-post | An undetected known-number straight has very high burst value within the $5,000 slip cap. | Silas costs $12 for a tip or $24 for today's number; detection penalty is $20 + 2x stake and enters street-debt pressure. | Two distinct staggered-close rumors; detection is 5% +7 points/repeat +3 per $5 stake, capped 70%; venue must remain open after post. | Shared cash/debt/heat; independent knowledge, venue close, repeat counter, detection roll. |
| The Count | Terminal payout ladder $720 pinched, $900 out hot, $1,150 clean. | Three real $8-30 blackjack identity sessions plus schedule and swap-cart route exposure. Abort is `15 + 10 * stored setup keys`, capped at bankroll-1. | Bishop Inner Circle, audit-night world hook, three distinct clean sessions under heat 35, two-action hold, cart delivery, three live decisions/rounds, real getaway. Completing ends Act 1; abort closes both plans for the run. | Shares all global constraints; independent Bishop trust, world hook, setup keys, decision window, getaway pressure. |
| The Whale Game | Starts with a 650-chip invitational pot; terminal payout clamps to $180-1,300. | Real qualifying loss target $60. The $120 name requirement reads existing scored run spending and is not a second fee. False-Bottom Cup is checked, not consumed. | Velvet Inner Circle; gala/whale hook; two loss rounds; $120 score and two seen beats; cup plus craps training; five-game sequence, two hazard rounds, interview, getaway. Completion ends Act 1. | Shares cash/spending/heat; independent Velvet trust, component/training, pot, sequence/hazards/interview. |
| Items / resale | 78 of 88 items are sellable. Landed sale ranges by class: permanent $3-24, consumable $3-18, temporary $7, contraband $10-40, active $20, container $8-34, souvenir $4-14. | Purchase bands are item-authored; Mags bench costs $32/$34/$38/$42/$44 and consumes optional components. | Inventory capacity/offers, member rank for bench, item ownership, per-offer state. Thirteen free scenario souvenirs resolve once and remain within-run only. | Shared cash/inventory; independent offer, scenario-resolution, and ownership state. |
| Services | 18 catalog services cost $0-28. Key sinks: ordinary rounds/tips $4-10, Punchline cover $14, private table $24, Kitty champagne $18, show $28. | Cash and sometimes alcohol intake; service may exchange cash for heat, luck, discovery, recovery, or flags. | Venue presence, challenge restrictions, authored repeat/use state. | Shared cash/heat; independent venue/service flags and alcohol/recovery state. |
| Scenario/event economy | 74 authored event-choice economy deltas are present: cash results span -$35 to +$35, with heat/flag/item/debt consequences. | Negative choices cover bribes, stakes, covers, tips, and pressure relief; positive choices commonly add heat or consume an item/one-shot event. | Event generation, conditions, one resolution per environment instance, scenario/revisit persistence. | Shared cash/heat; independent scenario selection, choice prerequisites, resolved-event state. |
| Travel | Twelve authored destinations cost $0-70: four $0 routes, motel/bar $2, gas $3, jazz $4, Punchline $5, Kitty $10, Delta $12, Grand $70. Back Alley also carries a 35% -$8/+4 heat risk. | Cost, risk cash loss, heat, alcohol decay, and action time. | Visible/revealed world graph, route conditions, affordability, one travel boundary. | Shared cash/actions/heat; independent graph reveal and risk roll. |
| Lenders / debt | Street +$25 (note $30), motel +$20 (note $24), Crew +$45 against two favors, family +$30, pawn up to 2x sale price. | Street due 3 turns and repeats +$10; motel due 4; Crew favors due 2 then $45/favor at 35% if refused; family due 6 with recurring nag; pawn redemption adds 25%. | Location, lender repeat policy, collateral, open-note state, deadlines, repayment cash. | Shared bankroll/actions/heat; independent lender clocks, favor/grievance, collateral ticket. |

### Shared versus independent constraints

Bankroll, action count, heat, travel access, and terminal state are shared. They
can restrain every route at once. Most 0.6 brakes are instead independent:
member trust does not consume a pusher schedule; pusher stock does not consume a
Numbers day; Numbers retry does not consume play uses; heist setup keys do not
consume ordinary job availability; souvenir resolution does not consume a
service or lender use. Independent positive sources can therefore be sequenced
inside one run while each local constraint still appears to bind. The harness's
mixed policy exists specifically to test that multiplication.

## Harness and reproduction

Status: **PARTIAL / runnable prototype**. The harness is opt-in and is not wired
into a default suite. It parsed and executed on the recorded build, but the full
64-seed-per-style run was not attempted.

`tools/cross_economy_audit.gd` is opt-in and is not registered in a default
suite. Ordinary games, events, travel, services, lenders, and endgame use the
same production drivers as `tools/endgame_metrics_probe.gd`. Specialized
policies use a deterministic one-boundary contact selector, then production job
acceptance, real delivery/stake settlement, real route costs and risk, production
Numbers bribe/allocation/payday, and The Count's production blackjack/setup/
getaway state machine. The grinder pays the normal route into a naturally
generated gas-station room and grinds only when that seed actually rolls a
pusher; availability and reached-machine results are reported separately. It
keeps that machine for the whole run, executes real $1 drops, advances fixed
solver ticks, and invokes production COLLECT after every drop so a sample cap
cannot strand already-claimable tray cash. It preserves a final $1 reserve
instead of deliberately tripping the bankroll-zero terminal before collection.
Each seed receives a unique deterministic production transient context, so the
cabinet persists within that run but opening stock and solver state cannot leak
between seed rows; the stateful module is also renewed at the run boundary so
settled simulations do not accumulate in the 512-run process.
The JSON also embeds an exact
source register: all 11 game action definitions and module authorities, 13 jobs,
five plays, Numbers/heist definitions, 88 item price/effect projections, 18
services, five lenders, 12 routes, and all 159 event choice consequence sets.
That register is the exhaustive machine-readable companion to the grouped table
above; full-simulation game modules remain authoritative where catalog
`win_chance` copy is descriptive rather than a paytable.

The dedicated Crew policy specializes through action 64, the Numbers policy
uses one real Lucky runner route and specializes through action 112, and the
pusher policy specializes for 64 paid drops. They then hand control to the
ordinary endgame driver. The global action cap is therefore a censoring guard,
not the intended ending for a permanently grinding policy. The 208-boundary
guard leaves up to 96 ordinary endgame boundaries after the longest
specialization, slightly more than the base endgame probe's complete-run budget.

The default sample is 64 seeds per playstyle (512 runs). For a binary rate near
50%, 64 independent deterministic seeds give an approximate 95% half-width of
12.3 percentage points and expose outcomes occurring at roughly the 5% level;
that is adequate for ranking large balance signals before human playtest, not
for certifying small tuning changes. Every table reports min/p05/p25/median/
p75/p95/max, mean, and sample standard deviation; raw seed rows and ledgers stay
in JSON.

### 0.5-compatible control boundary

The repository does not contain an executable 0.5 binary or a historical 0.5
economy-distribution artifact, so this report does not invent a numeric
before/after series. The meaningful landed comparison is the maintained golden
crew-ignored capture in
`scripts/tests/fixtures/crew06_5_ignored_run_baseline.json`: two fixed seeds and
five checkpoints each (initial room, ordinary action, travel, revisit, and
save/load), captured at its recorded pre-Crew baseline commit. The relevant
foundation contract proves that ignoring Crew preserves those ordinary-run and
round-trip boundaries. The `control_crew_ignoring` policy then supplies the
current-build 64-seed bankroll/heat/debt distribution. These are complementary
claims--structural 0.5 compatibility plus current quantitative behavior--not a
claim that this branch re-simulated an unavailable historical build.

### Conditioning and censoring

Action-cap survivors are right-censored observations, not player choices. The
JSON marks them `censored_action_cap`, reports their rate, and computes
pressure-versus-choice rates only across observed terminals (with all-run shares
alongside them). The pusher policy is unconditional: it pays to reach a natural
gas-station generation and separately reports whether that seed offered the
machine. Specialist policies dynamically mark themselves conditioned whenever
their one-boundary selector supplies a desired Crew contact who was not naturally
present; production acceptance and every economic consequence remain real, but
the resulting elapsed actions are not natural contact-opportunity rates. The
Count policy is additionally route-conditioned by injecting only the
`audit_night` world prerequisite; it is valid for setup-cost, post-contact
completion-time, and payout-shape measurement, but its victory rate is not an
unconditional probability of finding The Count in an ordinary run.

Planned full command (**NOT RUN**):

```powershell
$env:GODOT_BIN = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe'
powershell -NoProfile -ExecutionPolicy Bypass -File tools/cross_economy_audit.ps1 -SeedsPerPlaystyle 64 -MaxActions 208 -SeedPrefix BALANCE06-1 -BuildRef e74a57cebbda198cda9c1a95ada1c2081f1bb7c6 -Output res://.tmp/balance06_1/cross_economy_audit.json
```

Executed determinism command (one seed per style, 208-action censoring cap):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/cross_economy_audit.ps1 -SeedsPerPlaystyle 1 -MaxActions 208 -SeedPrefix BALANCE06-1-DETERMINISM -BuildRef WORKTREE-PRECOMMIT -Output res://.tmp/balance06_1/determinism_first.json -VerifyDeterminism
```

The wrapper produced `determinism_first.json` and
`cross_economy_audit_repeat.json`; both are 1,546,805 bytes with SHA-256
`f7cf3730922226710244dc49e985a98aaa8d5824f24f78d4b6851252d3cec897`.

Executed smoke command (one seed per style, eight-action cap):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/cross_economy_audit.ps1 -SeedsPerPlaystyle 1 -MaxActions 8 -SeedPrefix BALANCE06-1-SMOKE -BuildRef STATIC-SMOKE -Output res://.tmp/balance06_1/smoke_retry2.json
```

The smoke artifact is 539,889 bytes with SHA-256
`ea75e88e0921041601a44316a2f467a77e71de31494d8e2fa70feca8a65c7883`.

### Landing evidence disposition

The three raw measurement JSONs above are deliberately omitted from the clean
landing payload. Together they add roughly 3.5 MB of permanent Git history for
`n=1` point samples that the required full audit will supersede. Their exact
blobs remain recoverable from immutable source head
`1c0dec3b1e091939cccc8295b9a218be2aa42b96`, their SHA-256 values remain in
`docs/plans/evidence/balance06_1/SHA256SUMS.txt`, and the original ignored files
remain preserved in the source worktree's `.tmp/balance06_1/` directory. The
landing payload retains the report, handoff, evidence README, checksum manifest,
and smaller validation artifacts. No measurement was re-derived, rewritten,
compressed, or deleted to make this disposition.

Planned persisted-machine physical EV command (**NOT RUN**):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/coin_pusher_ev_harness.ps1 -AcceptedPerMachine 200000 -ShardsPerMachine 8 -Throttle 6 -OutDir .tmp/balance06_1_coin_pusher_ev
```

## Measured distributions

Status: **PARTIAL — point samples only**. Each row has `n=1`, so min, median,
mean, and max are the same point and do not constitute a distribution. Every
run reached the 208-action guard while still active; there were no observed
terminal failures or victories. The Crew, heist, and mixed rows are explicitly
contact/route conditioned. The pusher row did not reach a naturally generated
machine. These values are useful for reproducing harness behavior, not for
ranking strategies.

| Playstyle | Start | Final | Min | Peak | Peak heat | Final / peak debt | Actions / disposition | Conditioning |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Crew-ignoring control | 113 | 5 | 5 | 133 | 5 | 2 / 2 | 208 / censored active | none |
| Pure gambler | 163 | 38 | 38 | 163 | 1 | 0 / 0 | 208 / censored active | none |
| Crew maximizer | 157 | 20 | 20 | 307 | 10 | 2 / 2 | 208 / censored active | contact-conditioned |
| Numbers specialist | 72 | 3 | 3 | 72 | 1 | 2 / 2 | 208 / censored active | none recorded |
| Coin-pusher grinder | 148 | 19 | 19 | 148 | 2 | 2 / 2 | 208 / censored active | no machine reached |
| Cheater | 33 | 2 | 2 | 65 | 28 | 24 / 24 | 208 / censored active | none |
| Heist rusher | 132 | 260 | 132 | 282 | 9 | 0 / 0 | 208 / censored active | route/contact-conditioned |
| Mixed opportunist | 36 | 2 | 2 | 39 | 3 | 22 / 22 | 208 / censored active | contact-conditioned |

All final heat values were zero. Raw per-boundary ledgers, curves, source/sink
totals, exact seeds, and aggregate point statistics remain at immutable source
head `1c0dec3b...` under
`docs/plans/evidence/balance06_1/measurements/determinism_first.json` and in the
preserved source-worktree `.tmp` original; the landing disposition above omits
the raw blob without discarding its provenance.

## Registered questions and evidence

Status: **NOT STARTED**. The point samples are insufficient to answer repeatable
Numbers cuts versus median table profit; persisted pusher EV per variation;
jobs/travel versus the $32-44 bench; Count and Whale setup exposure versus
terminal ladders; abort-cost clarity; or souvenir resale exact-once persistence.

## Ranked findings

Status: **NOT STARTED for economy findings**. No balance finding is asserted from
eight censored point samples.

One non-economy suite defect was isolated while validating the harness. The
contract suite calls missing method `surface_add_exact_hover_hit` on the
`SurfaceHarness` test double at `scripts/tests/foundation/check_core_content.gd:139`;
the production call is `scripts/games/blackjack.gd:2939`. The archived stderr
contains the exact stack. This belongs to `fix06_4` on
`codex/cross-remediation`; it was not patched or retried here.

## Ranked proposals (not applied)

Status: **NOT STARTED**. There is no evidence-backed economic finding from which
to derive a proposal. No product or tuning file was changed.

## What this report does not cover

- It does not satisfy the contract's multi-seed complete-run distribution
  requirement. The only 208-action evidence is one seed per playstyle, and all
  eight rows are right-censored.
- It does not contain a 0.5 numeric distribution, coin-pusher 600k-drop EV run,
  victory-time distribution, pressure-terminal distribution, or evidence-backed
  ranking of findings/proposals.

- It does not replace human skill/feel, onboarding, or subjective pressure
  playtest. Contact selection and legal table decisions are deterministic
  action-boundary policies, not UI bots; their consequences settle through the
  production state machines.
- It does not estimate rare-event tails below this sample's useful resolution.
- It reports economic time in action boundaries. The inherited fixed
  `estimated_minutes` convenience field is not a wall-clock measurement and is
  not used as evidence for a finding.
- It does not use contact-conditioned specialist samples or the Count sample as
  unconditional opportunity or time-to-victory frequencies.
- It does not count the Whale's $120 scored-spending gate as a second cash fee.
- It does not merge Vault option value into physical coin-to-tray ROI.
- It does not tune product data or authorize a balance change.

## Validation and serialization evidence

- Harness determinism: **PASS** for one seed per style. The two comparable full
  JSON outputs are byte-identical; exact command and hash are above.
- Eight-action harness smoke: **PASS**, eight rows, no harness failures or
  warnings; exact command and hash are above.
- `tools/validate_project.ps1 -Quiet`: **PASS** twice in archived wrappers
  (48.167s and 49.470s).
- Godot import: **PASS** twice (17.753s and 17.979s).
- GDScript load check over `res://scripts,res://tools`: **PASS** twice (27.258s
  and 24.907s), including the untracked-at-the-time harness scripts now frozen at
  `e74a57ce...`.
- Relevant Foundation systems suite: **PASS**, four shards, 41.382s wall stage,
  archived under `docs/plans/evidence/balance06_1/validation/foundation_systems_retry1/`.
- Foundation contracts suite: **BLOCKED / non-evidence for harness health**. It
  timed out at 300.047s after the unrelated missing `SurfaceHarness` method
  error described above. It must not be retried on this row.
- The 64-seed-per-style audit, 0.5 numeric comparison, and 600k-drop pusher EV
  run are **NOT STARTED**.
