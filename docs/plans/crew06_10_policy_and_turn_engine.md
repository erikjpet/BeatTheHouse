# crew06_10 policy and ordered-turn design

The ordered engine is opt-in as `ordered_v1` during shared assembly. Each
accepted action advances one seat decision only. State records the button,
ordered active seats, turn cursor/owner, current bet, round and lifetime
contributions, bounded raise count, player/NPC stacks, fold state, pot, and a
bounded public-action memory. A round closes only after every active actor has
acted since the last raise and every contribution equals the current bet.

The sequence is ante/deal → ordered pre-draw betting → ordered discards/draw →
ordered post-draw betting → showdown. A fold with hidden cards verifies no tell.
Settlement, trust, and learned-tell receipts remain exactly once. A later
explicit `new_session` advances the durable session identity and never reuses a
deck, pot, observation receipt, or settlement boundary.

The seven existing policy identities remain rules-owned and deterministic:

| Member | Opening/draw/post-draw identity | Adaptation boundary |
| --- | --- | --- |
| Rook | patient, medium-tight, high-card caution, rare bluff | remembers raises/folds without seeing hidden cards |
| Velvet | selective trap range, persuasive value/bluff raises | responds to public pressure and position |
| Knuckles | loose pressure, made-hand raises, reluctant folds | raises more often within the friendly cap |
| Switch | medium range, frequent probe, exits expensive traps | uses public facing-raise state |
| Mags | tight value range, cautious draw, almost no bluff | avoids marginal public calls |
| Bishop | conservative opening, firmer post-draw counter | changes only after public phase/raise information |
| Lucky | loose opening, frequent bluff, broad redraw | accepts thin public situations more often |

No policy reads another hand, undealt cards, hidden tell-learning state, or
future RNG. Session memory contains only public actions and current swing.
