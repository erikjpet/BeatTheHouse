# game06_7 Rourke duel and Grand Casino showdown final closeout

Date: 2026-09-02
Recovered product integration: `a6e7be912e8ca9e979d5eb35edefbb4883b49889`
Save/revisit remediation: `45e87257584ff30fd4086f89d49cf1d5ee23bfbe`

## Verdict

`game06_7` is complete. The existing Showdown product was recovered rather
than rebuilt. It presents the nine authored phases through the shipped
Blackjack surface, keeps the Rourke duel and room projections subordinate to
authoritative state, preserves distinct showdown, Players Card, crew, and
defeat endings, and does not expose private Turn state.

Closeout found one row-owned product defect: a dealt Rourke hand was held only
in the ordinary Blackjack surface state, so save/exit/revisit could lose its
cards. Commit `45e87257` persists each handled dealt intermediate state into
the existing serialized duel session at the action boundary that produced it.
The change does not alter rules, RNG, odds, stakes, routes, thresholds, heat,
or settlement. The permanent row contract now deals through the shipped
Blackjack module, serializes the real run, restores it, and proves the exact
player and dealer cards reopen.

## Recovered dependency and ownership disposition

- Game ritual runtime `5a2b1e1a6782a13308585e1a974adeeb86be0647`
  and accepted Blackjack recovery `b091bc43` are ancestors of the product.
- Showdown depth integration `a6e7be91` already contains the product adapter,
  explicit ritual projection, nine phases, authoritative actor/room staging,
  route-specific endings, privacy constraints, tests, platform probe, and 19
  checked-in visual states. Closeout retained these instead of recreating them.
- The shipped Blackjack module is the actual host for this boss surface. The
  save correction therefore belongs at its Rourke-specific action boundary;
  it does not introduce a second duel ledger or presentation authority.
- Crew presence consumes only public projection fields. The row contract's
  paired private variants remain byte-identical before authorized disclosure.

## Ladder-preservation table

| Boundary | Preserved shipped authority | Closeout proof |
| --- | --- | --- |
| Invitation | `grand_casino_invite`; Players Card, showdown, and crew routes remain separate | Presentation cannot create or bypass the invitation |
| Pat-down clean | no classified item | no penalty |
| Pat-down minor | exactly one contraband item | shipped confiscation only |
| Pat-down serious | surveillance or at least two contraband items | 18-stack handicap and forced ante +5 |
| Pat-down blatant | at least three contraband items, or watched cheat plus contraband | immediate `taken_out_back` / `casino_taken_out_back` |
| Duel | base ante 20, maximum five hands, earlier terminal when either stack reaches zero | authoritative terms, hand index, stacks, and receipts drive all staging |
| Rourke edge | 10% base plus 20% per cheat level | existing sealed result only |
| Edge call | correct swing 18; false-call cost 6 | caller labels cannot set correctness |
| Player cheat | 55% + 5% per aggression + 5% per cheat level; caught cost 18 | existing detection and heat result only |
| `walk_out_clean` | Rourke stack zero or final margin >= 12 | unchanged showdown victory/Cage settlement |
| `shown_the_door` | final margin >= -60 and < 12 | unchanged showdown ending and chip handling |
| `taken_out_back` | player stack zero or final margin < -60 | unchanged failure route |
| Players Card | deliberate Gold review | distinct `high_roller_cashout` ending |
| Crew | shipped heist terminal result | distinct `crew_heist` ending and exactly-once consequence |

The executable contract covers boundary margins `-61`, `-60`, `11`, and `12`,
both stack-zero terminals, all five ladder cases, all nine phases, all eight
phase transitions, ending separation, privacy, product-host integration,
save/revisit, and 1,000 liveness transitions.

## Exact-tree automated evidence

- Project validation: PASS after the remediation.
- `game06_7_showdown_duel_contract.gd`: PASS; nine phases, ten seeds, durable
  product save/revisit, route/ladder/privacy assertions, and no skipped,
  doubled, or replayed transition.
- `game06_2_depth_contract.gd`: PASS, preserving the accepted Blackjack
  dependency contract.
- Focused shipped `blackjack_game_suite`: PASS with zero failures in 11.379s.
  Report SHA-256:
  `3F51B6D84275CA8642888E46BB9BCE47964B48B2FF9A752E82992CAC1EB31FA0`.
- Native real-renderer platform probe: PASS on NVIDIA OpenGL, all 19 states,
  semantic SHA-256
  `0fbde506dcf5395a82d0801e5fd52a509b1296ae35339a9cf3d90345b57c385a`,
  serialization 208.517ms and maximum idle 3.893ms. Report SHA-256:
  `E202B155538D71CBCF4BD9ED233C231F69AE3DBFD0E1E23FCA71443F42EFE547`.
- Fresh Web release export: PASS, ten files / 69,195,606 bytes, zero script,
  engine, or export errors. Export-log SHA-256:
  `AE6791DA63FD2CFEBA65DF3155F050C168A87950048E6E2BE8114DE8A3168CF9`.
- Chrome 152 Web probe at CPU4 throttle: PASS, all 19 states, zero console,
  page, or request errors, and the same semantic SHA-256 as native.
  Serialization was 1208.785ms and maximum idle 19.825ms. Report SHA-256:
  `F14DB17044ECC5E44AF7FABE9915EADEA063C157E3488BA2B4DF1C869864F046`.
- Two exact-tree ten-seed determinism passes: PASS, 560 checkpoints each,
  identical combined hash `3685946140` and byte-identical report SHA-256
  `3719693600DFB5AA903EEC62D4FDFF7928FDA7107441B23F21C6462C2C3B1C5C`.
- Performance probe: PASS with zero failures. Rourke idle rendered 50 samples
  at 0.287ms average, 0.351ms p95, and 0.379ms maximum against the unchanged
  5ms p95 budget; liveness was 50 against floor 8, with zero full-snapshot
  calls. Report SHA-256:
  `8AC2FAD2AF13ABE10901FDC369EA1BF7A2FBD5BD8309CC488B9B458417F8980E`.
- Canonical Foundation visual/accessibility QA: PASS with no warnings or
  failures. Report SHA-256:
  `0BD9BADB0886403BA53DEEB639BA2A31A758DAFE8EACF70213F2550C03951891`.
- Fresh 1280x720 visual capture set: all 19 PNGs and the contact sheet are
  byte-identical to the checked-in evidence; mismatch count zero. Manifest
  SHA-256:
  `365C8BB3DBEEC0DCD93B3CFB8AC9F905951978A9B38293A602929CD71B685DF8`;
  contact-sheet SHA-256:
  `E3C313DF0DBDA7BB055D03A5511ACEA8F40D050944927032404F6C5A169B7C81`.

The retained visual matrix includes every presentation phase, all three duel
outcomes, showdown/Players Card/crew endings, maximum crowd, cheat edge call,
reduced motion, small screen, and colorblind labels. The checked-in evidence is
under `docs/plans/evidence/game06_7_showdown_duel/`.

## Retained non-green attempts and routed findings

No failed attempt was erased or relabeled as a pass.

- The first focused wrapper attempt was timing-only red because its full stage
  took 193.315s against a stale 17.79s wrapper allowance. Its functional
  content and Blackjack reports both passed with zero failures; the isolated
  exact suite subsequently passed in 11.379s. No timing cap was changed.
- A broad four-suite sample retained unrelated existing failures in UI popup
  hostile serialization, Crew heist/Turn fixtures, and a save-service fixture.
  Its Rourke single-surface path emitted no failure. Those findings remain with
  the Family 2/environment owners and are not rewritten as game06_7 results.
- The post-fix broad boss-objective report removed the genuine saved-card
  failure and retained four non-row findings: one Grand Casino room-return seam
  owned by the environment flow, plus three audit cases that fabricate
  receipt-free Blackjack results. The shipped sealed host intentionally rejects
  those stale fixtures before bankroll, cash/chip, heat, or showdown mutation.
  Report SHA-256:
  `64EDABDD57A6C9D10C239CB87185B19D538C51CFFF0B832452435F3897829326`.
  The real Players Card and Rourke route assertions in that run passed.

These broader findings do not demonstrate a game06_7 regression and do not
change its row verdict. They remain visible for their owning rows and for the
independent `game06_8` release audit.

## Remaining human check

No implementation or automated-verification work remains for game06_7. The
program-level playtest should confirm that a player can tell the current phase,
stake, relative position, and ending without outside explanation. That manual
experience check is not represented as automated evidence and remains part of
the later release/playtest gate.
