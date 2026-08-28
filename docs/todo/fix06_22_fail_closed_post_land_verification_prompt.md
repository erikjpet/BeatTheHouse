# Agent Prompt — fix06_22: Fail-Closed Post-Land Verification

Board row: `fix06_22` in `docs/todo/README_0_6_board.md`.

Continue only the process/tooling commits preserved at `c1d80ff0` and
`41d54f61`, transplanted semantically onto exact current main `a62f4884` in a
new named branch/worktree. The landed hash correction belongs to fix06_21 and
must not be duplicated.

The authoritative post-land path must run the complete Smoke suite: validation,
import, GDScript load, foundation smoke, UI compile, Dave encounter, roulette
audio, native pusher smoke, and foundation performance smoke. It must bind exact
start/end main commit and tree, clean tracked checkout, Godot path/hash, native
source tree, descriptor hash, and Gate Service-approved built DLL hash. Any
stage red, identity mismatch, narrowing attempt, missing runtime, timeout,
stderr policy failure, or timing/performance failure must produce a structured
report with `eligible_for_done=false`. A focused or proportionate row gate can
never substitute for PostLand, and no board row may become DONE unless the
exact landed main head has a retained eligible PostLand report.

Do not change product/runtime behavior, suite composition, assertions, budgets,
performance limits, or evidence. Return an immutable head and positive/negative
proof manifest to the dedicated Integrator. Never modify main, remotes, release
state, or owner artifacts.
