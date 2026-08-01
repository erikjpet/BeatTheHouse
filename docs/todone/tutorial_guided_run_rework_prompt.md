# Agent Prompt — Guided First-Run Tutorial: Complete Rework (Dialogue-Guided)

Copy everything below this line into the worker agent. Use a capable model.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. The guided first-run tutorial is being COMPLETELY REWORKED. Today
it is a chain of ~31 `tutorial_*` coach lessons ("dealer's advice" bubbles)
in `data/tutorial/lessons.json` that no longer lines up with the run around
it. Replace it with a DIALOGUE-GUIDED run: a friendly guide character talks
the player through the run in a dialogue popup while the relevant on-screen
area is highlighted. Audit the current tutorial/coach/dialogue systems first
and record a short map before editing; build on the existing lesson
engine + dialogue/talk system, do not invent a parallel one.

## Delivery model (how guidance works now)

- The guide SPEAKS through the dialogue/talk popup (real character
  conversation), NOT the old coach-bubble-only "dealer's advice."
- Keep the existing coach HIGHLIGHT anchors to point at the subject on screen
  ("look here"), driven alongside the dialogue.
- **Remove the 8 ambient first-time tips** (`tip_first_*` and the
  `tip_starter_card_home` beat) — the guide covers everything; no
  double-teaching. (Replace the starter-card-home beat with a guide line if
  needed.)
- Gating never soft-locks: the guide restricts input to the intended action,
  but the player can always progress, and the optional detour (Path A) is
  genuinely skippable.

## New characters (define both; add to `docs/plans/0.5_voice_bible.md`)

- **Pal — the early-run guide (apartment → underground casino).** A NEW
  character: warm, friendly, encouraging, streetwise; on your side. Speaks in
  first person and refers to themselves as "your pal" ("Hey — think of me as
  your pal on this one"). Upbeat, plain-spoken, roots for you. This is the
  voice for the whole first half of the tutorial.
- **The Host — the Grand Casino hostess (name her; e.g. "Vivienne / Viv" —
  owner-tunable).** A NEW named character who is the game's existing casino
  "Host" role given an identity: polished, velvet-gloved, warmly professional
  with a hook under the charm. She becomes the guide once the player reaches
  the Grand Casino. She is DISTINCT from Linda (the cage) — she works the
  floor and sends the player to Linda. ALSO wire her a short GREETING when the
  player enters the Grand Casino in NORMAL (non-tutorial) runs, not just the
  tutorial.

## The guided run — full order of operations (rebuild the sequence)

Runs on a FIXED tutorial seed with tutorial-scoped scripting; normal runs are
unaffected by any of the forcing below.

### 1. Apartment (forced start home)

- Force the start home to the **apartment**, and force the starting item to
  the **X-ray Glasses** (override the apartment's normal starting item for the
  tutorial only).
- Pal introduces themselves ("your pal"). Pal tells the player a home that
  isn't the back alley gives you a starting item — there's one waiting in your
  place. PICK IT UP.
- Pal has them OPEN THE INVENTORY and confirm the X-ray Glasses are there.
  (Do NOT teach the meta-home "open the bag" flow — that's out-of-run and not
  relevant here.)
- Pal shows how to leave: open the TRAVEL MAP.

### 2. Travel to the corner store

- The map offers only ONE destination: the corner store. Pal has them travel
  there.

### 3. Corner store (buying, debt, events, the split)

- Pal teaches PURCHASING: investigate each available item, then buy one.
- DEBT SOURCES: **The Crew is present at the corner store.** Pal warns the
  player about them — a last resort only. Then Pal points at the **counter
  phone**: the player MAKES THE FAMILY CALL and TAKES the family loan (the
  existing phone-loan event) so they learn firsthand what taking a loan does
  (real debt follows them).
- EVENTS: a **parking lot tip** event is present. Pal has them investigate it;
  when it opens, Pal tells them to pick **"Follow the tip"** — it may lead
  somewhere useful later.
- Pal prompts travel again. The map now offers the **gas station casino
  (Path A)** OR the **underground casino (Path B)**, and Pal explicitly tells
  the player that the parking-lot tip is where they got the information
  pointing them to these places. Pal STRONGLY STEERS the player toward Path A
  (the gas casino) but the player CAN skip it and go straight to Path B.

### PATH A — Gas station casino (optional detour: item-cheating + funds)

- Pal directs the player to the **pull tab machine**.
- Because the player owns the **X-ray Glasses**, they can spot a WINNING pull
  tab. SCRIPT the machine's generation so one of the X-ray-revealed winners
  sits near the BOTTOM of one of the stacks (this uses the existing, working
  X-ray-on-pull-tabs reveal — do not change the mechanic, just script the
  tutorial machine's stock). Pal has them buy that ticket and peel it.
- After the win, leaving the machine, Pal directs them to the CLERK to cash
  their tickets.
- After cashing out, Pal prompts travel → which leads to Path B (the
  underground casino). Path A taught item-based cheating and handed the player
  extra funds.

### PATH B — Underground casino (blackjack + skill-cheats)

- Pal has the player ENTER the blackjack table and PLAY A HAND normally.
- Then Pal teaches changing the BET using the on-screen chips; the player
  raises their bet and a hand is dealt.
- **Peeking the dealer's card:** Pal teaches that you can peek at the dealer's
  hole card ONLY WHEN THE DEALER IS LOOKING AWAY, and that you have LOOKAWAY
  events you can trigger — e.g. spilling a drink makes the dealer look away for
  a few seconds, opening a peek window. This mechanic ALREADY EXISTS — AUDIT
  THE CODE to see exactly how the lookaway/peek works and have Pal explain it
  accurately; do not build a new system. Pal notes this is the easiest way to
  cheat here, but getting caught has consequences.
- **Counting cards:** Pal runs the count tutorial — the player must select ALL
  the count bubbles, or they gain heat "tripping over the count."
- **Heat:** whenever the player gains heat, Pal flags it and explains you don't
  want your heat to hit the top or the police come — or worse.
- After play, leaving the table, a **high roller invitation** event is present.
  Pal points it out and tells the player to always keep an eye on their
  environment. Pal has them look at and ACCEPT the invitation.
- Pal prompts travel to the **Grand Casino**. Pal tells the player they
  themselves have been "banned from the Grand Casino" (this is just Pal's
  in-character reason for not coming along — NOT a real player state), and to
  be very careful cheating there or Rourke will be on top of them. Pal says
  goodbye and wishes them luck.

### 4. Grand Casino (the Host takes over)

- On entry the **Host** greets the player and becomes the new guide. She
  explains the reward system and introduces **Rourke**; Rourke tells the
  player they have nothing to worry about as long as they play clean in "his
  casino."
- The Host points at the **free comp** event on the main floor and the player
  is FORCED to take it (the comp's attention hook is intentional).
- The Host instructs the player to visit **Linda at the Cage**. On entering
  the Cage, the player talks to Linda with EXTENDED tutorial text (fuller than
  her normal voice lines). Linda explains the CHIPS loan + cashout system and
  how debt is settled during cashout.
- The player BUYS CHIPS from Linda. The Host/Linda points at the SHOP and
  notes chips buy anything there.
- The player is then FREE to play — steer them to the TABLE GAMES (which use
  the chips they just bought) — until they've gambled enough to earn the FIRST
  (Bronze) Players Card tier. Use a COMPRESSED Bronze threshold for the
  tutorial so it's reachable quickly.
- The Host then prompts the player to RETURN to Linda. Back at the Cage, Linda
  explains the Players Card system and that the goal is the GOLDEN Players
  Card. **The guided tutorial ends here.**

### 5. After the tutorial (scripted Rourke warning — NOT an escalation system)

- If, after the tutorial, the player cheats and gains heat, Rourke may deliver
  a warning popup ("I've got my eye on you — I know what you're up to"). This
  is a possible Rourke warning that can occur in normal runs — do NOT build a
  fixed every-20-heat escalation ladder. Use/keep Rourke's existing appearance
  and warning hooks; the tutorial simply includes one scripted Rourke warning
  beat.

## Scope boundaries (keep normal runs clean)

- All forcing (apartment start, forced X-ray, forced family loan, scripted
  pull-tab winner, forced comp, compressed Bronze, the A/B routing) is
  TUTORIAL-CONFIG-SCOPED. A normal run's balance, item spawns, loans, pull-tab
  generation, and card thresholds are byte-identical.
- The ONLY intentional normal-run change in this task is the **Host greeting**
  on Grand Casino entry (a small, general addition) and adding **Pal** and the
  **Host** to the voice bible.
- Determinism: fixed tutorial seed; the A/B split is a real player choice,
  both branches deterministic and reproducible; no wall-clock in scripted
  beats.

## Hard rules

- Zero soft-locks: every gated step is escapable; skipping Path A works
  cleanly; a "skip the lessons" escape remains reachable throughout; the
  stuck-state sweep must stay green on the tutorial config.
- Zero-copy per-frame; idle liveness untouched; determinism preserved; tokens
  for chrome; dialogue copy per `docs/plans/content_style_guide.md` and the
  voice bible. Tabs, typed GDScript, sparse comments; captures under `.tmp/`.
  Suite timeout = max(300s, ceil(recorded baseline × 1.5)). Never revert or
  stage unrelated user-owned uncommitted work.

## QA / Tests

1. Full guided playthrough via BOTH routes: (a) Path A then Path B, (b) skip
   Path A straight to Path B — both reach the Bronze card and the tutorial end
   with no soft-lock; capture key beats.
2. Forced beats fire: apartment start + X-ray in inventory; family loan taken
   (debt appears); parking-tip "Follow the tip" opens gas+underground; scripted
   pull-tab winner is X-ray-visible near a stack bottom and pays; forced comp;
   compressed Bronze reachable; Linda extended text; Host guide + Rourke intro.
3. Lookaway/peek + counting lessons drive the REAL mechanics (agent-audited),
   not a fake; heat flags fire on the count-miss.
4. Normal-run isolation: a non-tutorial run has unchanged home/item spawns,
   loans, pull-tab stock, and card thresholds; the Host greeting appears on
   Grand Casino entry in normal runs.
5. Ambient `tip_first_*` lessons removed; no double-teaching.
6. Determinism (10 seeds) + stuck-state sweep (100 seeds) green on the tutorial
   config; save/load mid-tutorial restores the correct step.
7. Voice: Pal and the Host read in-character and distinct; extended Linda text
   reads well.

## Gates

- `tools\validate_project.ps1`
- every supported `-FoundationSuite` (systems + ui + tutorial/content)
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`
- `tools\foundation_visual_qa.ps1`

## On completion

Only after both routes are proven end-to-end with no soft-lock AND normal-run
isolation is confirmed AND all gates pass:

1. Commit in logical units (voice bible + Host greeting; tutorial sequence by
   phase; scripted overrides).
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, commit hashes, the beat
   list as built, both-route proofs, normal-run isolation proof, gate results),
   and stage the move.
3. PUSH to the remote.
4. Report: Pal and the Host as defined, the full built sequence, both-route
   playthrough proofs, the normal-run Host greeting, and gate results.

On an unfixable gate or a soft-lock you cannot resolve, stop at the last green
commit, do NOT push, and report exactly what is unmet.

---

## Execution record — 2026-08-01

### Implementation commits

- `55f73f07` — Rework first run as guided dialogue.
- `02433b0e` — Script deterministic tutorial routes.

### Pre-edit system map

The production lesson path remains `CoachOverlay` + `CoachViewModel`; speech is
queued through `FoundationMain.start_dialogue`, `RunState` pending talk events,
and the existing `TalkDock`. Travel remains owned by `RunGenerator`/`WorldMap`,
items by `RunActionService`, event consequences by `EventModule`, pull-tab stock
and X-ray targeting by `PullTabs`, and lookaway/peek/counting by the existing
Blackjack surface actions. No parallel tutorial, conversation, or cheat system
was introduced.

### Beat list as built

1. Apartment: fixed seed `FIRST-NIGHT-ACE-17`, forced apartment, sole free
   X-ray Glasses pickup, inventory confirmation, and travel-map instruction.
2. Corner store: inspect both offers and buy one; Pal warns about the Crew;
   the real phone chain forces the family call and accepted loan; the real
   parking-lot event forces **Follow the tip** and opens the route split.
3. Path A: optional gas-station detour; the existing X-ray display marks a
   seeded winner at stack offset 2; the player buys down, peels all windows,
   leaves the machine, and redeems through the real clerk action.
4. Path B: real Blackjack clean hand, chip-based raised bet, real Drink Pass or
   Chip Spill lookaway, real peek window, every real count icon, and heat copy;
   the invitation is accepted before Pal's banned-from-the-Grand farewell.
5. Grand Casino: Vivienne Vale greets and guides; Rourke gives the clean-play
   introduction; the comp choice is forced; Linda explains chips, the shop,
   cashout, and debt; one table hand reaches tutorial-only Bronze; Linda issues
   Bronze and establishes the Golden Players Card goal; the run ends there.
6. The existing one-shot Rourke heat warning remains; no repeating heat ladder
   was added. All `tip_first_*` and `tip_starter_card_home` lessons were removed.

### Route and isolation proof

- Path A → Path B: PASS; X-ray target at offset 2, `$100` redeemed through the
  clerk, 8 real count pulses selected, Bronze issued, end route
  `tutorial_bronze_card`.
- Direct Path B skip: PASS; no pull-tab payout required, 6 real count pulses
  selected, Bronze issued, end route `tutorial_bronze_card`.
- Save/load: PASS; a queued Pal dialogue restored its exact current node.
- Normal isolation: PASS; family-phone chain chance remains `0.75`; normal
  Grand thresholds remain 5 games / `$30` net / 30 heat; ordinary pull-tab
  stock has no tutorial scripting; tutorial modifier keys are absent from the
  standard config. The only normal-run feature is Vivienne's one-time Grand
  Casino entry greeting.

Mechanic report: `.tmp/tutorial_rework/tutorial_guided_run_audit.md` and JSON.
Proof captures: `.tmp/tutorial_rework/captures/01_path_a_apartment_pal.png`
through `08_normal_run_host_greeting.png`, including the route split, X-ray
pull-tab surface, Blackjack count surface, Vivienne, Rourke, Linda, and the
normal-run Host greeting.

### Final gates (clean detached snapshot at `02433b0e`)

- `tools/validate_project.ps1`: PASS.
- Foundation `all`: PASS (150.4 s total; `foundation_all` 89.263 s).
- Foundation `ui`: PASS (147.6 s total; UI scene compile 70.289 s).
- Foundation `systems`: PASS (81.0 s total; systems 26.308 s).
- Dedicated fixed-seed two-route audit: PASS.
- Determinism: PASS, 10 seeds, 320 checkpoints, matching hash `3323631074`.
- Stuck-state sweep: PASS, 100 seeds, 0 stuck states.
- Visual QA: PASS (35.3 s).
