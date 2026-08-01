# Agent Prompt — Tutorial Rework: VERIFY Everything Is Done Per Spec (and Finish What Isn't)

Copy everything below this line into the worker agent. Use a capable model.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. The guided first-run tutorial was reworked per
`docs/todone/tutorial_guided_run_rework_prompt.md` (its archived copy — that
is the binding spec). Your job: INDEPENDENTLY VERIFY that EVERY beat and
requirement of that spec is actually implemented and working, with concrete
PROOF — and where any is NOT met, FINISH implementing it until you can prove
it. Do not trust prior claims or commit messages. Conclude "done" ONLY when
every checklist item is proven with the stated evidence and all gates pass.

## Rules of this pass

- VERIFY-AND-FINISH, not a rebuild: do not churn parts that already work and
  are proven. Only fix what a verification step shows is broken or missing,
  then prove it.
- Every item needs EVIDENCE: a driven playthrough capture (under
  `.tmp/tut_verify/`) or a test/assertion. "Should work" is not proof.
- Produce `docs/plans/tutorial_verification.md`: one row per requirement →
  PASS (with the capture path / test name) or FIXED (what was wrong, what you
  changed, new proof). No blank or hand-waved rows.
- The single most important proof: DRIVE the full tutorial end-to-end via
  BOTH routes and confirm each reaches the Bronze card and the tutorial end
  with NO soft-lock.

## The verification checklist (prove EACH; finish any that fails)

**Delivery & characters**
1. Guidance is delivered through the DIALOGUE popup (the guide actually
   speaks) plus coach HIGHLIGHT anchors — not the old coach-bubble-only
   "dealer's advice." PROOF: captures of the guide speaking with the subject
   highlighted.
2. The 8 ambient `tip_first_*` lessons (and the old `tip_starter_card_home`
   beat) are REMOVED — no double-teaching during the tutorial. PROOF: data
   check + a run showing no ambient tips fire.
3. **Pal** (the early-run guide who calls themselves "your pal") is defined in
   `docs/plans/0.5_voice_bible.md` and voices the first half in-character.
   PROOF: bible entry + capture.
4. **The Host** (named, distinct from Linda) is defined in the voice bible,
   guides the Grand Casino half, AND greets the player on Grand Casino entry
   in NORMAL (non-tutorial) runs. PROOF: bible entry + tutorial capture + a
   normal-run entry-greeting capture.

**Apartment → corner store**
5. Forced start home = **apartment**; forced starting item = **X-ray
   Glasses**; the player picks it up and confirms it in the INVENTORY (not the
   meta-home bag flow). PROOF: capture of X-ray in inventory at tutorial start.
6. The map first offers ONLY the corner store; the player travels there.
   PROOF: capture.
7. Corner store: the guide teaches purchasing and has the player INVESTIGATE
   EACH available item then buy one; **The Crew present** with the "last place
   you turn" warning; the player MAKES THE FAMILY CALL and TAKES the phone loan
   (real debt appears); the guide tells them about EVENTS and the **parking
   lot tip** opens, "Follow the tip" is taken with the guide's "may lead
   somewhere useful later" line; the guide then explicitly tells the player
   the parking tip is the SOURCE of the two new routes it opens (BOTH the gas
   casino and the underground casino). PROOF: captures of the loan/debt and
   the two routes opening.

**Path A (gas casino) — steered but skippable**
8. Pal strongly steers to Path A but it is genuinely SKIPPABLE (going straight
   to underground works with no soft-lock). PROOF: both a take-Path-A run and
   a skip-Path-A run.
9. On Path A: a scripted pull-tab machine has an X-ray-revealed WINNER near
   the bottom of a stack (existing X-ray-on-pull-tabs mechanic, scripted stock
   only); buy/peel it, win, and cash at the clerk. PROOF: capture of the
   X-ray-visible winner and the payout.

**Path B (underground blackjack)**
10. Enter blackjack, play a hand, then change the BET with on-screen chips and
    raise it. PROOF: capture of the bet change.
11. Lookaway/peek: the guide teaches peeking the dealer's card ONLY when the
    dealer looks away, and the spill-a-drink lookaway window — using the REAL
    existing mechanic (confirm it drives the actual code, not a fake) — and
    frames it as the EASIEST way to cheat here but with CONSEQUENCES if caught.
    PROOF: capture of a triggered lookaway + peek.
12. Counting: the player must select ALL count bubbles or gain heat; heat
    gains are flagged by the guide with the "don't hit the top / police or
    worse" warning. PROOF: capture of a count-miss heat flag.
13. Leaving the table, the HIGH ROLLER INVITATION event is present; the guide
    points it out with the "always keep an eye on your environment" line, has
    the player LOOK AT and ACCEPT it; then travels to the Grand Casino with
    Pal's "I'm banned from the Grand Casino / be careful cheating or Rourke
    will be on you" line and Pal's goodbye + wishes-luck. PROOF: capture.

**Grand Casino**
14. On Grand Casino entry the Host greets the player and BECOMES the guide,
    EXPLAINS the reward system, and introduces Rourke; Rourke tells the player
    they have nothing to worry about as long as they play clean in "his
    casino." PROOF: captures.
15. The free comp on the main floor is FORCED (taken). PROOF: capture.
16. At the Cage, Linda uses EXTENDED tutorial text and explains chips loan +
    cashout + debt-in-cashout; the player BUYS CHIPS and is shown the shop
    (chips buy anything there). PROOF: captures.
17. The player plays TABLE games (using the chips) to a COMPRESSED Bronze
    threshold; the Host then sends them back to Linda, who explains the
    Players Card system and the golden-card goal; the tutorial ENDS there.
    PROOF: capture of the Bronze award + the review + end.

**After the tutorial & isolation**
18. A scripted Rourke WARNING can occur if the player cheats/gains heat post-
    tutorial — but there is NO fixed every-20-heat escalation ladder. PROOF:
    confirm the warning exists and the escalation ladder does NOT.
19. NORMAL-RUN ISOLATION: a non-tutorial run has byte-identical home/item
    spawns, loans, pull-tab stock, and card thresholds; only the Host greeting
    is added. PROOF: a normal-run check/test.
20. No soft-locks; determinism (10 seeds) and stuck-state sweep (100 seeds)
    green on the tutorial config; save/load mid-tutorial restores the correct
    step. PROOF: gate results + a save/load test.

## Hard rules

- Determinism, zero-copy per-frame, idle liveness untouched; keep tutorial
  forcing tutorial-config-scoped; never weaken a test/gate to pass. Style:
  tabs, typed GDScript, sparse comments; captures under `.tmp/` (the
  verification doc in `docs/plans/`). Suite timeout = max(300s, ceil(recorded
  baseline × 1.5)). Never revert or stage unrelated user-owned uncommitted
  work. Work on `main` (or an isolated worktree branch if another agent is
  active, then merge back green).

## Gates (all must pass)

- `tools\validate_project.ps1`
- every supported `-FoundationSuite` (systems + ui + tutorial/content)
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`
- `tools\foundation_visual_qa.ps1`

## On completion

Conclude COMPLETE only when ALL 20 checklist items are PROVEN (every row of
`tutorial_verification.md` is PASS or FIXED with evidence), BOTH routes are
proven end-to-end with no soft-lock, normal-run isolation holds, and all gates
pass:

1. Commit any fixes in logical units.
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, commit hashes, the
   verification table with proof paths, both-route proofs, gate results), and
   stage the move.
3. PUSH to the remote.
4. Report the full verification table (20 items, each PASS/FIXED with proof),
   the both-route playthrough proofs, the normal-run isolation proof, and a
   plain verdict: "TUTORIAL COMPLETE PER SPEC — all 20 proven" or the exact
   list of what remained unmet.

If any item cannot be proven or a gate cannot pass, do NOT declare complete:
keep implementing until it can, or stop at the last green commit and report
exactly what is unproven and why.

---

## Execution record — 2026-08-01

Result: **TUTORIAL COMPLETE PER SPEC — all 20 proven.**

Commits:

- `aadd80ee` — tutorial-only first-map constraint plus binding Pal copy and regression checks.
- `592405c2` — independent two-route audit, expanded production capture harness, and verification plan.

Canonical detailed report: `docs/plans/tutorial_verification.md`
Machine-readable proof: `.tmp/tut_verify/tutorial_guided_run_audit.json`
Capture set: `.tmp/tut_verify/captures/` (18 PNGs)

### Verification table

| # | Result | Archived proof |
|---:|:---:|---|
| 1 | PASS | 48/48 lessons use dialogue and highlights; capture `01_dialogue_highlight_apartment_pal.png`. |
| 2 | PASS | Audit `ambient_tip_ids=[]`; removed lesson IDs are rejected by the authored-contract check. |
| 3 | PASS | Pal voice-bible/data assertions; capture 01. |
| 4 | PASS | Vivienne voice-bible/data assertions; tutorial capture 13 and normal-run capture 18. |
| 5 | PASS | Both route audits pick up X-ray Glasses through `RunActionService`; inventory capture 02. |
| 6 | FIXED | Tutorial map had leaked Gas Casino at start; tutorial-only first reveal now contains Corner Store only; capture 03. |
| 7 | FIXED | Real store purchase, Crew, family debt, and parking event pass; binding Crew/parking copy corrected; captures 04–05. |
| 8 | PASS | Path A and genuine skip route both reach Bronze/end; 50+50 tutorial sweeps, zero stuck. |
| 9 | PASS | Real X-ray pull-tab offset 2, `$100` target, `$103` clerk redemption; captures 06–07. |
| 10 | PASS | Real Blackjack hand settled and chip bet raised to `$4`; capture 08. |
| 11 | FIXED | Real Drink Pass lookaway + peek proven; easiest-cheat and caught-consequence copy corrected; capture 09. |
| 12 | PASS | All-bubbles path plus expired-bubble miss adds heat; capture 11. |
| 13 | FIXED | Real invitation accepted; environment-scan/accept wording corrected; capture 12. |
| 14 | PASS | Vivienne reward/Rourke handoff captures 13–14. |
| 15 | PASS | Forced real `take_comp` result plus capture 15. |
| 16 | PASS | Generated Cage stock (3 offers), real 10-chip purchase, Linda debt/cashout copy; capture 16. |
| 17 | PASS | Real chip-funded table hand, compressed Bronze claim, Linda goal/end; capture 17. |
| 18 | PASS | Exactly one Rourke warning at heat 85; no every-20 ladder. |
| 19 | PASS | Normal same-seed byte comparisons, 0.75 loan chance, unscripted stock, unchanged card thresholds; only Host greeting added. |
| 20 | PASS | Both routes restore `map_corner` mid-tutorial; tutorial sweep 100/100, general stuck 100/100, determinism 10/10. |

### Both-route proof

- Path A: apartment → Corner Store → scripted X-ray pull tab + clerk redemption → Underground Blackjack → invitation → Grand Casino/Cage/table → Bronze → `tutorial_bronze_card`; PASS, ended, no soft-lock.
- Skip Path A: apartment → Corner Store → direct Underground Blackjack → invitation → Grand Casino/Cage/table → Bronze → `tutorial_bronze_card`; PASS, ended, no soft-lock.

### Final gates

- `tools/validate_project.ps1` — PASS.
- `tools/check_godot.ps1 -RequireGodot -NoImport -FoundationSuite all -TimeoutSec 300` — PASS (`.tmp/tut_verify/gates/foundation_all_final/summary.json`; 130.9 s wall time).
- Tutorial two-route audit + alternating 100-run tutorial sweep — PASS.
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10` — PASS; 320 checkpoints in each process, matching hash `3634294742`.
- `tools/foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100` — PASS; zero stuck.
- `tools/foundation_visual_qa.ps1 -RequireGodot` — PASS; no warnings (`.tmp/tut_verify/gates/foundation_visual_qa_final.log`).

No tests, budgets, determinism rules, zero-copy paths, or idle-animation liveness requirements were weakened.
