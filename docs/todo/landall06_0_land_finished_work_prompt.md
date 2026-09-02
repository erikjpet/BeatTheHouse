Status: LAUNCHER — single agent, supersedes all prior program launchers for landing purposes

# Orchestration Prompt — landall06_0: Land All Finished Work

Copy everything below this line into ONE agent. Its only job is landing.

---

You are working in `D:\Projects\Beat-The-House`. Three previous agents produced a
large amount of finished and near-finished work and then all three stopped,
blocked, waiting on owner decisions. Your job is to get that work onto `main`.

**You land finished work. You do not implement, you do not redesign, and you do
not stop the program to ask permission.**

## 1. The situation

- `main` is **green** at `00ee744f` and is your base. Verify that before you start.
- Roughly eighty branches carry unlanded work from the last 24 hours. Substantial
  examples: `codex/world06_2` (+59), `codex/world06_1` (+54), `codex/env06_6b-smoke-remediation`
  (+46), `codex/land06-env06_6-final` (+35), `codex/crew06_10-first-remediation`
  (+35), `codex/env06_7-pkg-a` through `-pkg-e` (+32 to +34 each),
  `codex/craps06_3-impl` (+31), plus `game06_1` through `game06_7` and
  `world06_3` through `world06_6` implementation branches.
- Only **1 of 29 program rows is complete**. Everything else is built, partly
  reviewed, and stranded.
- The recurring failure has been owner-decision paralysis: rows stop, then whole
  lanes stop, then the program stops. That must not happen to you.

## 2. Standing authority — you do not wait for the owner

The owner has pre-authorized the following. Record each use; do not request
permission.

- **Park, never block.** If a row genuinely needs an owner decision, park it with
  the exact question recorded, and move to the next landable row. Never halt the
  program for a decision. Batch every outstanding question into your reports.
- **`fix06_13` is PARKED** (option C). It is not a dependency for landing
  anything else. `fix06_9` and `pusherv3_11` stay parked with it. Do not let a
  `WeakRef` annotation debate gate the game.
- **Performance is a checkpoint gate, not a per-landing gate**, per the owner's
  prior ruling: run it on a quiesced host after every five landings and before
  any playtest build. Functional gates remain mandatory per landing.
- **You are the independent reviewer.** You authored none of this work. Where a
  row lacks an independent review, you may perform it yourself rather than
  waiting for a review pool that no longer exists.
- **Land partial rows when the partial is coherent and green.** A row whose
  accepted portion passes its gates may land, with the remainder recorded as an
  explicit follow-on row. Landing 60% of a row beats landing none of it.
- **Expand scope only to keep `main` green**, never to improve. Anything
  worthwhile but not required to land becomes a follow-on row.

## 3. Hard limits — these do not bend

- **Never weaken a test, refresh a golden, or raise a budget to make a red go
  away.** A golden changes only on proof the content legitimately changed. A
  budget changes only on five runs on a quiesced host with every result reported.
  A budget crossing 16.67 ms needs the owner's explicit sign-off.
- **Never merge unreviewed work to `main`.** Preservation is achieved by branches
  existing, not by merging.
- **`main` must be green after every landing.** A red `main` reopens the
  responsible row immediately and is your only priority until fixed.
- **Delete nothing.** No branch, worktree or stash removal. No `gc`, no
  `reset --hard`, no `clean`.
- **Never push, never modify remote state, never perform release activity.**
  Publishing belongs to `consolidate06_1`, later.
- Owner property — `.tmp/`, `.tools/`, `review_artifacts/`, editor state, build
  output — is never staged, moved or removed.
- The primary worktree may hold stale tracked changes. Never stage from it. If
  `run_state.gd` or `check_lenders_release_saves.gd` show as modified there, that
  is a known hazard preserved on `salvage/game_test_heat_cap_unreviewed_wip` —
  ignore it, do not commit it, and never integrate from it.

## 4. Triage first, then land

1. Enumerate every branch with commits ahead of `main` and touched in the last
   48 hours. Ignore the 62 `salvage/*` branches — they are preserved, not
   landable.
2. Classify each: **LANDABLE** (coherent, green or gateable now),
   **PARTIAL** (an accepted portion is landable, remainder becomes a follow-on),
   **BLOCKED** (needs an owner decision — park with the exact question), or
   **SUPERSEDED** (a later branch replaces it; record and move on).
3. Where several branches cover one row — `craps06_3-impl` and
   `craps06_3-env-integration`, `crew06_10-impl` and `-first-remediation` and
   `-product-handoff`, `env06_7-assembly` and `-assembly-ordered`,
   `land06-env06_6-final` and `-855-current` — identify the true tip and say why.
   Do not merge two branches of the same row separately.
4. Publish the triage before landing anything. It is the plan.

## 5. Landing order

Land in this order, adjusting only for real dependencies you discover:

1. **`env06_6`** — the scenario runtime. It gates Family 2 and the depth rows.
   Its accepted payload was `855a2961`; a smoke-remediation successor exists at
   `codex/env06_6b-smoke-remediation`. Determine the correct tip and land it.
2. **`env06_7` packages A–E**, in a fixed recorded order — they share a catalog
   and must be integrated sequentially, never merged as they arrive.
3. **`craps06_3`** and **`crew06_10`** — the depth game rows, partials acceptable.
4. **`world06_1`**, then `world06_2` through `world06_6` — the crew lane, in
   dependency order.
5. **`game06_1`** through `game06_7` — Family 1, in dependency order.
6. Cross-cutting prestage rows (`audio06_1`, `integ06_1`, `perf06_1`,
   `teach06_2`, `playtest06_2`, `depth06_1`, `game06_8`, `world06_7`) last, since
   most are prestage scaffolding rather than finished work.

For each: verify the head, review it, gate it, merge `--no-ff`, verify `main`
green, record the merge commit, move on. Never squash a clean row; extract the
net payload when a branch's history is entangled with other rows.

## 6. Known landing hazards

- **`env06_6`'s merge invariant**: `RunState._apply_delivery_resolution` must
  preserve the `resolved && !world_applied` guard, the existing
  delivery/job/Numbers/heist consequence order, and the package/multi_stop
  counter inside that guard immediately before `world_applied = true`. Do not
  count hold/getaway. Four overlap files need semantic inspection; never
  wholesale-replace a file in a three-way merge.
- **The caller-supplied authority defect** has appeared three times — `env06_6`'s
  route resolver, `world06_5`'s `sweep_intel` flag, and one earlier. Before
  landing any `world06_*` or `game06_*` row, check that it never trusts a
  caller-supplied capability or authority claim, and that observers without
  authentic capability see no hidden-state difference. This is a P0 class.
- **Hidden state is absolute**: no Turn, traitor, grievance, rigged-draw or
  unrevealed-ticket information may leak through scene data, serialized keys,
  captures, audio, logs or fixtures.
- **Exactly-once**: every consequence fires once across save, reload, travel,
  revisit, abort and expiry.

## 7. Reporting

Report at every landing. Lead with **rows landed of 29**, the merge commit, and
`main`'s health at that head. Then: what remains landable, what is parked with
which exact owner question, and what you have classified superseded.

Never report a row complete before it is on `main` and `main` is green there.
Never stop the program because a question is outstanding — park it and continue.

Your final response leads with the outcome: rows landed of 29, `main`'s final
commit and health, every parked question in one list, and explicit confirmation
that nothing was force-pushed, no remote state changed, no release activity
performed, and no branch or owner file deleted.
