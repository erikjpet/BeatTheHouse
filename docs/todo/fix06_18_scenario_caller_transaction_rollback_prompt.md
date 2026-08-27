Status: TODO — routed from env06_6 accepted-head content evidence
Board row: `fix06_18` in `docs/todo/README_0_6_board.md`

# Agent Prompt — fix06_18: scenario caller transaction rollback

Work from exact current `main` only after the env06_6 integration row lands or
parks with its accepted implementation heads preserved. This row owns the shared
public-caller rollback defect exposed when deferred foundation runner commit
`c373bb52786bb51ac44f2e4cddf5fd8e4b536b39` first allowed the caller contract to
run inside a ready `SceneTree`.

## Retained reproduction

The clean accepted env06_6 head `c373bb52786bb51ac44f2e4cddf5fd8e4b536b39`
ran filtered content once at `.tmp/env06_6_accepted_head_content_01/`. The report
is SHA-256 `E882AAA8ADE0F7E1A7E8D2466171F95E1D2A39017F77B7A2190A9D24C9EF8F7E`,
stdout is `60E53DBA63920A0778CB1941B87B9CC0EF6D0B7861256E21FFFE007916103DF2`,
and stderr is `92AD011AFD8EEC7768BAF6EB8646C1A0BDA768A78C6310569A9443837CBBE095`.
The run retained exactly these eleven caller failures:

1. tutorial event-card completion;
2. tutorial world-map acknowledgement;
3. public meta-map entry;
4. public direct exit;
5. Cage shortcut entry;
6. delivery-arrival travel;
7. forced casino event entry;
8. meta environment apply;
9. meta entry;
10. direct game-test entry; and
11. health-inspector forced travel.

Seven `Condition "!is_inside_tree()" is true` diagnostics accompany the UI
paths. The evidence indicates restore/focus ordering attempts to restore focus
before detached controls are reattached, while all eleven assertions show the
broader shared transaction invariant is not met: a rejected environment entry
must restore the enclosing run, environment, controller, selection, popup,
focus and caller flags byte-for-byte, emit exactly one terminal error, and
perform no downstream success UI or autosave.

## Required work

1. Reproduce all eleven failures with the deferred runner active and preserve
   exact per-caller before/after snapshots and error order.
2. Identify the common transaction boundary before changing any caller.
3. Repair the smallest shared rollback/reattach/focus ordering seam. Change an
   individual caller only when evidence proves it has an additional defect.
4. Add exact success, rejection and hostile nested-state coverage for every
   affected caller, including controls detached from and attached to a tree.
5. Prove no rejected path autosaves, presents success, consumes an event,
   changes travel/session state, or leaks duplicate errors.
6. Run focused caller contracts, then the owning content gate, and obtain an
   independent exact-head review before landing.

## Locked boundaries

- Do not change RTP, EV, payout, odds, wager math, RNG, economy values, schema,
  migration, version, packaging, release or remote state.
- Do not weaken, filter, delete or skip any caller assertion or deferred-runner
  behavior.
- Do not absorb the routed env06_7 content/evidence cluster or the stale live
  semantic refresh expectation.
- Do not infer success from the absence of a crash; exact state restoration and
  one terminal error are required.

Preserve the accepted-head evidence and every new reproduction. Commit
logically, self-review, obtain independent review, and land as its own row.
