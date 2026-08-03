# 0.5 integration gate recovery

Date: 2026-08-03

## Git identity

- Preserved checkpoint: `agent/v05-pre-rework-baseline` at `d83020843f9e2053ab00dbfecbfb4ba173d540d5`.
- Working branch: `agent/v05-pre-human-playtest-rework`.
- Recovery implementation commit: `5389fba8` (`fix integration gate regressions`).
- The checkpoint was clean before the branch was created. No user-owned change was reverted or omitted.

## Integrated change inventory

`git diff main...d8302084` contained 43 files and 3,142 insertions / 332 deletions:

- tutorial data, flow, travel, TalkDock, coach overlay, and route tests;
- Scratch Ticket rendering, mask input, portable receipts/piles, and compact save state;
- invitation spawning, world-state persistence, and tutorial isolation;
- environment interaction, spatial canvas, SFX prewarm, and performance instrumentation;
- Foundation/UI tests, verification reports, and the active 0.5 queue.

The preserved checkpoint already committed that integration work as one recoverable snapshot. This recovery added only the demonstrated gate fixes and documentation.

## Root causes and fixes

### Pal dialogue contracts

Four shortened Pal lines no longer contained required mechanical meaning. The Crew warning already passed its contract. Restored concise copy now states:

- the parking tip may be useful later;
- the lookaway is the easiest cheat and `DRINK PASS` spills a drink;
- a caught Peek adds Heat and may close the table;
- the player must scan the environment, open the invitation, and accept it.

No tutorial progression or simulation state changed.

### Sal pawn-shop overlap

The reserved-dialogue reflow moved each intersecting fixture independently. Multiple fixtures selected the same nearest escape position, producing shelf 0/4 and Sal/counter collisions. After avoiding those collisions, a no-space fallback left shelf 4 partly under the counter.

The reflow now reserves clear fixture footprints, accepts only deterministic collision-free preferred placements, includes all four escape directions, and uses a deterministic nearest-free board search when preferred placements are occupied. The authored focus points and distinct interaction identities remain unchanged. The strict overlap assertion remains unchanged.

## Compatibility and integration findings

- Scratch Ticket compact receipts and portable piles pass current/legacy save round-trips, preserve fixed-at-purchase outcomes, and retain deterministic state.
- Grand Casino invitations remain unique, persistent, and tutorial/normal-run isolated.
- Tutorial-only configuration remains absent from normal runs in the systems assertions.
- TalkDock/reserved-overlay reflow keeps modal targets distinct without weakening spatial or overlap tests.
- SFX prewarm and performance-smoke boundaries pass without new script errors, leak warnings, or idle-liveness regressions.

## Fresh gate evidence

| Gate | Result | Evidence |
| --- | --- | --- |
| `git diff --check` | PASS | Clean before the recovery commit; line-ending notices only from Git working-copy policy |
| `tools/validate_project.ps1` | PASS | Repeated by every check below |
| `check_godot.ps1 -FoundationSuite ui -TimeoutSec 300` | PASS | `.tmp/test_reports/20260803_115040_smoke/summary.json` |
| `check_godot.ps1 -FoundationSuite systems -TimeoutSec 300` | PASS | `.tmp/test_reports/20260803_115332_smoke/summary.json` |
| `check_godot.ps1 -FoundationSuite scratch_tickets -TimeoutSec 300` | PASS | `.tmp/test_reports/20260803_115505_smoke/summary.json` |
| `check_godot.ps1 -Smoke -TimeoutSec 300` | PASS | `.tmp/test_reports/20260803_115625_smoke/summary.json` |
| `check_godot.ps1 -FoundationSuite all -TimeoutSec 300` | PASS | `.tmp/test_reports/20260803_115956_smoke/summary.json` |

The final Smoke run passed validation, import, script loading, foundation smoke, UI scene compilation, Dave bus coverage, roulette audio, and performance smoke. The broad FoundationSuite passed all aggregated system/content/game contracts.

## Deferred to binding later phases

- TUT-N01 through TUT-N25 and the complete real-interface tutorial matrix.
- Retained-memory slope and full 180-minute performance soak.
- Final pre-human release matrix, refreshed evidence, and owner playtest preparation.

Phase 1 verdict: **PASS — integration gates recovered without losing the preserved checkpoint.**
