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

## Causal boundary

The expected full-state digests were last reproduced and committed by
`f9eaebbfc526d8bc9dbe09e11c3f67a86d4626c4`. Path history from that point to
current main shows only the `meta06_1` reporting change `63e926c4` touching
state-generation code (`scripts/core/run_state.gd`); environment catalogs and
the run generator are unchanged. A focused exact-base reproduction produces
the same two actual digests as the Integrator gate:

- `current_environment`: `45af0f598ae637b57cbb4b32124cfa7367fcb4528b7ca7dd26f13219b038ff12`
- `world_map`: `7ca2d05cb3378c802eb8df85894974b24f5d7f4953b8f34b62f3d7ebc450fbd4`

The focused run also captured the full current serialized values locally under
the untracked `.tmp/` diagnostic directory; those owner artifacts are not part
of this commit.

## Provisional classification

The invariant player-visible travel facts are unchanged, so there is no
evidence yet of a routing, economy, timing, or narrative regression. The
remaining question is whether the full-state difference is a deterministic,
non-observable serialization change introduced by `meta06_1`, or contains a
player-observable state mutation. Exact pre/post field comparison is the next
and only diagnostic step; no golden refresh, assertion weakening, budget
change, or product redesign is authorized.
