Status: FINALIZE — handoff prompt for the agent holding `codex/cross-remediation`

# Finalize Prompt — fix06_4 contract red, then hand off

Copy everything below this line into the agent that owns
`codex/cross-remediation`.

---

Stop what you are currently doing and read this in full before your next action.

You are working in `D:\Projects\Beat-The-House-worktrees\cross-remediation` on
branch `codex/cross-remediation` (head `f072b1c3` at the time this was written).
Your task is no longer open-ended diagnosis. It is: land the correct fix for the
contract red, get the suite green, commit clean, and hand off. A single project
manager agent is taking over the whole 0.6 landing effort after you.

## 1. Stop the native rebuild

You are running `tools/build_native_solver.ps1 -Platform Windows -Target
template_debug` and compiling godot-cpp from scratch — 596 object files were
written between 09:35:31 and 09:38:48 today, and your worktree shows hours of
this churn. The hypothesis behind it, recorded in your ledger as "contract
native fallback", is not supported by the evidence.

Terminate that build and any Godot process it spawned. Do not start another
native build unless a measurement in this prompt's section 3 tells you to.

## 2. The actual root cause, already in your evidence

The contract suite fails inside `foundation_contracts` at exactly the point
your timeout occurs. The stderr, captured in
`D:\Projects\Beat-The-House-worktrees\cross-balance\.tmp\balance06_1\foundation_contracts_1\foundation_contracts.stderr.txt`,
reads:

```
SCRIPT ERROR: Invalid call. Nonexistent function 'surface_add_exact_hover_hit'
in base 'RefCounted (SurfaceHarness)'.
   at: BlackjackGame._draw_count_challenge (res://scripts/games/blackjack.gd:2939)
   [1] _check_blackjack_surface_contract
   [2] _check_game_surface_contracts
   [3] _check_foundation_contract_smoke
```

Commit `43767b42 feat(blackjack): add heat backoffs and hover counting` added a
call to `surface_add_exact_hover_hit` at `scripts/games/blackjack.gd:2939`. That
method exists on the real canvas at `scripts/ui/game_surface_canvas.gd:699`. The
test double `SurfaceHarness` at `scripts/tests/foundation/check_core_content.gd:139`
implements `surface_add_hit`, `surface_add_invisible_hit` and
`surface_add_exact_hit`, but never received the hover variant. Any contract run
that draws the blackjack count challenge errors there.

Verify this yourself before acting on it — reproduce the error, confirm the
missing method, and confirm the call site. Do not take this prompt's word for it.

## 3. Land the fix

- Add the missing method to `SurfaceHarness`, mirroring the canvas exactly so
  the double and the real implementation cannot drift again:

```gdscript
	func surface_add_exact_hover_hit(rect: Rect2, action: String, index: int = -1) -> void:
		surface_add_hit(rect, action, index, false)
		if not hit_regions.is_empty():
			(hit_regions[-1] as Dictionary)["activate_on_hover"] = true
```

- Then audit the whole double against the canvas: enumerate every public
  `surface_*` method on `game_surface_canvas.gd` and every method any game
  module calls on a surface, and report which are absent from `SurfaceHarness`.
  This class of gap will recur through the coming depth programs, which add
  pointer verbs to every game. Fix the ones that are currently reachable; list
  the rest as findings.
- Consider adding a guard test that fails when a game module calls a surface
  method the double does not implement, so this cannot silently return.
- Re-run the contract suite on the exact head. Report the real duration against
  the 230.391s immutable baseline. If it now passes, the native hypothesis is
  closed; say so explicitly in your handoff. If it still times out with the
  script error gone, you have a second, genuine finding — measure it, do not
  guess at it, and do not resume the native rebuild without evidence naming it.

## 4. Clean up your own branch

Your branch carries 47 commits including two reverted attempts
(`Revert "fix(fix06_4): focus blackjack acceptance runner"` and
`Revert "fix(fix06_4): complete focused runner inheritance"`) and a reverted
`pusherv3_10` dependency merge. Do not rewrite that history — the reverts are
evidence.

Do make the final state honest: no debug code, no leftover scaffolding, no
generated artifacts staged, no build output committed, and `git status` showing
only intended files. Native build products must not be committed.

## 5. Hand off

Produce a written handoff containing:

1. exact base and head commits, and `git status` proving only intended files;
2. the commit list with a one-sentence purpose each;
3. the reproduction of the root cause, the fix, and the before/after contract
   suite durations with exact commands;
4. the full `SurfaceHarness` versus canvas gap audit, with what you fixed and
   what remains as findings;
5. an explicit statement closing or keeping the native-fallback hypothesis, with
   the measurement that settles it;
6. every uncommitted artifact you are leaving behind and where it lives;
7. known risks or assumptions — "None" must be explicit, not omitted.

Then stop. Do not merge to any integration branch, do not edit
`docs/todo/README_0_6_board.md`, do not start another row, and do not delete
your worktree or branch. The incoming project manager agent will collect your
branch by name and land it. Leave it intact and reviewable.
