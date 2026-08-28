# Current-main inactive-delivery triage

Status: UNREVIEWED diagnostic checkpoint

Base: `3f5e990750a8e2809f556c4e01a3d60972f49f21`

Native identity retained from the Integrator gate:
`BB1CDDA7C8EA4534A8C9E9BD3F00808FFD7D4C8617E09555AAEB7586670F5233`.

## First red

The retained Smoke gate passed validation, import, script loading, and the
foundation smoke suite. The only failure was the inactive-delivery
ordinary-travel byte-identity assertion in the UI compile suite. The expected
and actual values agree on destination (`bar`), route choice, bankroll cost,
clock advance, RNG state, story entry, heat, town action index, and travel-count
advance. Only the whole `current_environment` and `world_map` serialization
digests differ.

## Causal boundary and exact delta

The expected full-state digests were last reproduced and committed by
`f9eaebbfc526d8bc9dbe09e11c3f67a86d4626c4`. A focused capture at pre-change
head `70eaaf80` reproduces the committed expected hashes exactly. A focused
capture at current main produces the same two actual digests as the Integrator
gate:

- `current_environment`: `45af0f598ae637b57cbb4b32124cfa7367fcb4528b7ca7dd26f13219b038ff12`
- `world_map`: `7ca2d05cb3378c802eb8df85894974b24f5d7f4953b8f34b62f3d7ebc450fbd4`

The focused run also captured the full current serialized values locally under
the untracked `.tmp/` diagnostic directory; those owner artifacts are not part
of this commit.

A recursive field-by-field comparison of both complete JSON values finds
exactly one leaf difference in each digest:

- `current_environment.game_states.coin_pusher.last_message`
- `world_map.nodes[1].environment.game_states.coin_pusher.last_message`

Both change from `Quarter Falls shoves two shelves under a pile that remembers
every coin.` to `Quarter Falls moves one platform under a pile that remembers
every coin.` No key, array length, type, or other leaf value changes.

The exact introducing change is the already-landed, player-visible copy repair
`737a8fe94bac9e193d5918fe7f6d722fa0a074a0` (`fix06_7`), which deliberately
corrected the Quarter Falls description from the obsolete two-shelf model to
the shipped one-platform model. Its duplicate lineage is `b466aa7a`; the
first-parent landing is `040f9fe2`.

Exact ancestry resolves the apparent `meta06_1` correlation: `f9eaebbf` is an
ancestor of the clean pre-meta head `ff2d4e14`, and the only commits on that
ancestry path touching either the asserted test or the serialized pusher state
are `f07699d5`, `737a8fe9`, and its landing merge `040f9fe2`. The expected
constants are identical on both parents of `040f9fe2` and after the merge; the
serialized intro leaf changes only on the `737a8fe9` side. Thus the first red
tree is the `040f9fe2` landing, before `meta06_1`. Commit `63e926c4` is excluded
as a cause.

## Classification and constrained correction

This is stale test evidence, not a new product-behavior defect. The only changed
leaf is authorized player-visible copy from the already-landed `fix06_7` row;
ordinary travel itself is byte-identical in every scalar and structured leaf
outside that copy. Reverting the copy would reintroduce the defect `fix06_7`
closed.

The minimal correction would replace only the two expected SHA-256 constants
with the exact current values above, leaving the full-value assertion and every
travel invariant intact. That operation is a golden refresh, however, and this
triage assignment explicitly forbids golden refreshes. Therefore no correction
is applied on this branch. The immutable diagnosis head must be handed to the
Integrator/owner for authorization or applied by a lane authorized to update
stale evidence; test weakening, field exclusions, budget changes, and product
changes are neither needed nor proposed.
