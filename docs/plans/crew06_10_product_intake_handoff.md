# crew06_10 Product Intake Handoff

Status: **UNREVIEWED product intake; dependency-held; not accepted**

This handoff freezes the crew06_10 product candidate for review-first intake. It does not claim independent review, gate acceptance, landing, or PostLand acceptance.

## Immutable product identity

- Product head: `678c3e2742fb0f1f93252b1ebd935a4248e85334`
- Product tree: `2c648e97a8d374b19cbb4c3c4a3666680979c1de`
- Product base: `855a296126e8b4747b78fbe89cb5a2d02daf61f5`
- Product commits, in order: `a0090874`, `47d049af`, `4945bce6`, `678c3e27`
- Net product delta: five files, 960 insertions and 13 deletions

The exact five-file payload is:

1. `data/games/rituals/crew06_10_poker_nights.json`
2. `docs/plans/crew06_10_policy_and_turn_engine.md`
3. `docs/plans/crew06_10_shared_assembly_manifest.md`
4. `scripts/games/crew_draw_poker.gd`
5. `scripts/tests/foundation/crew06_10_depth_contract.gd`

This handoff document is outside that product payload. The product head and tree above remain the immutable review subject.

## Reported and retained evidence provenance

The focused 5.100-second result is Director-board/producer-reported evidence covering five profiles and ten seeds, including conservation, receipt, interruption, and save behavior. There is no retained on-disk artifact for that result and no exact-head or hash binding for it. It is producer-reported evidence only; it is not independent acceptance.

The following are local retained artifacts:

- Validation: PASS, 66.046 seconds.
- GDScript load: PASS, 30.437 seconds.
- Predecessor full `crew_poker`: RED, 76.612 seconds, mostly from inherited environment failures. This predecessor-red artifact is not hash-bound to the final product. The timing red was addressed by the final product commit, but no qualifying full gate has been run on the final exact product head.

## Intentional formatting exception

`docs/plans/crew06_10_shared_assembly_manifest.md:3` ends with two trailing spaces to create an intentional CommonMark hard line break. Consequently, the product-range `git diff --check` reports that single known line. It is intentional product content, not an undisclosed formatting cleanup opportunity.

## Dependency-held and not accepted

The following evidence and closure remain missing. None is accepted by this handoff:

- env06_6 room-sequence assembly;
- five production spatial/actor nights and their aftermath behavior;
- visual captures;
- native/Web parity;
- accessibility, input, reduced-motion, and small-screen evidence;
- performance evidence;
- final exact-head full-project, foundation, and crew-poker gates;
- independent review;
- landing and PostLand verification.

The product must remain dependency-held until the applicable owners and services provide this evidence. No environment assembly, visual behavior, platform parity, accessibility closure, performance closure, or integration status should be inferred from the focused producer result.
