Status: TODO — inventory/prestage landed; the authored SFX pass has not run
Board row: `audio06_1` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 audio06_1: Surface SFX Pass

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This row gives the reworked
surfaces sound. Read `data/audio/surface_sfx_manifest.json`,
`data/audio/music_manifest.json`, `scripts/core/music_delivery_index.gd`, the
audio handling in `scripts/ui/game_surface_canvas.gd`, the coin pusher's audio
implementation, `docs/plans/audio_engineer_delivery_contract.md`,
`docs/plans/audio_engineer_handoff.md`, `docs/plans/music_system_rework_plan.md`,
and the settings and mixer paths in `scripts/ui/settings_menu.gd` and
`scripts/core/user_settings.gd`.

## The current state, precisely

`data/audio/surface_sfx_manifest.json` contains exactly one profile: the coin
pusher, with its motor loop and event classes. Every other surface in the game
either produces sound through ad-hoc code or produces none. `assets/audio/sfx_native`
holds 41 sounds, most of them from the slot and pinball era.

Music is a separate matter and is **out of scope for this row**. The music
manifest contains three fixtures — a corner store sparse fixture and two jazz
club delivery fixtures explicitly labelled "not production music" — and
production music belongs to the external audio-engineer delivery contract.

## Board and dependencies

Follow the active board protocol. Claim `audio06_1`. This row requires Families 1
and 2 to have landed their rituals — sound for a ritual that is still being
designed will be wrong. You own `data/audio/surface_sfx_manifest.json`, new SFX
assets, the shared surface audio path, and their tests. You may not change music
system behavior or the music manifest beyond the handoff document in section 4.

## 1. Generalize the pusher's pattern

- The coin pusher profile is the shipped precedent: a manifest-driven set of
  event classes with deterministic selection and a contact lifecycle. Generalize
  that pattern so any surface can declare a profile, rather than writing a second
  audio system beside it.
- Sound must be driven by the `game06_1` game facts and the `env06_6` /
  `world06_1` transition ops — the same boundaries that drive visuals — so audio
  cannot desynchronize from what is on screen and cannot fire on a frame timer.
- Deterministic selection seeded from run RNG, with variation that does not
  repeat audibly. No wall-clock dependence anywhere.

## 2. Cover the reworked surfaces

Author profiles for the surfaces the depth programs changed, at minimum:

- **Craps:** dice cup, offer, throw, table contact, dice settle, the call, chip
  placement, collection, payout, crowd swell and drop, street cues.
- **Table games:** chip placement and correction, shoe and cut card, the deal,
  card squeeze, wheel and ball, dolly placement, clearing, paying, dealer
  procedure, shift change.
- **Machine games:** handle and button, direct-bankroll wager acceptance and
  settlement, reel stops, feature entry, Slot jackpot acknowledgement, tower
  light, attract. Do not author machine-credit in/out or Video Poker hand-pay
  events under the selected W0 + H0 authority contract.
- **Counter games:** rack, ticket handed over, the scratch itself, the peel,
  redemption, refusal.
- **Bar dice:** cup shake, slam, lift, reveal, cash on the bar.
- **Back-room poker:** chips, cards, the beats a tell lands in — without giving
  any tell an audio signature the tell contract does not permit.
- **Crew and world sequences:** door, handoff, package, stash, duck, pursuit,
  sweep proximity, book close, slip written, draw called, confrontation.
- **Scenario transition ops:** the staged beats `env06_6` introduced.

Every sound must be justifiable as something a person in that room would hear.
An abstract UI blip in a diegetic scene is a failure.

## 3. Discipline

- **No audio may reveal hidden state.** No tell, traitor, rigged draw, unrevealed
  ticket or unearned clue may have an audio signature that discloses it earlier
  or more reliably than its own contract allows. This is the same P0 rule the
  visual surfaces carry, and it is easier to violate in sound.
- Respect the shipped mixer, buses, volume settings and mute behavior. A player
  who has turned SFX down must get that everywhere, including new profiles.
- Budget: no audio work per frame, no unbounded voice counts, and a hard cap on
  concurrent sources per surface with a documented stealing policy.
- Native and Web must behave identically in event selection and timing, using the
  existing `sfx_native` and `sfx_web` split.
- Accessibility: nothing may depend on audio alone. Every sound that carries
  information must have a visual counterpart, since the reverse is already a
  project rule and this row must not break the symmetry.

## 4. Music handoff, not music

- Produce the 0.6 delta for the external audio-engineer contract: the venues,
  layers, games and states that now exist and need beds or stems, with their
  intended register, energy tiers and transitions, written into the existing
  handoff document format.
- Do not author production music, do not add fixtures beyond what testing needs,
  and do not change the music system's behavior.

## 5. Tests and acceptance

- Manifest validation: unknown event classes, missing assets, unbounded voice
  counts and undeclared profiles must fail loudly.
- Determinism: identical input traces produce identical audio event sequences
  across 10 seeds, on native and Web.
- Boundary binding: assert audio events derive from game facts and transition
  ops, with a test that a frame-driven sound cannot be introduced silently.
- Hidden-state audio audit across every profile, mirroring the visual audit.
- Concurrency and budget assertions per surface at maximum activity.
- Settings and mute behavior honored by every new profile.
- Playtest checklist: a player with the screen off can tell that something
  happened but not what secret it was.

Run project validation, the relevant foundation suites, determinism, native/Web
parity, performance and accessibility gates. Archive with the profile coverage
table and the music handoff delta recorded on the board.
