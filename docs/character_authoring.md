# Character and Encounter Authoring

Reusable identities live in two JSON packs:

- `data/characters/characters.json` defines who a character is, how their
  animated model looks, how they speak, and which authored encounters use
  their lines.
- `data/characters/pools.json` groups character IDs and declares how many
  unique members appear together.

The Crew is the first implementation: `crew_regulars` contains seven identities
and selects three for `the_crew`.

## Add a character

Add one entry to `characters.json`:

```json
{
  "id": "crew_example",
  "display_name": "Example",
  "title": "Specialist",
  "role": "crew",
  "model": {
    "skin_color": "#b77b52",
    "hair_color": "#201820",
    "jacket_color": "#24334a",
    "accent_color": "#21d7c5",
    "silhouette": "glasses",
    "scale": 1.0
  },
  "voice": {
    "style": "Short direction for future writing and performance.",
    "lines": {
      "loan_offer": ["An authored line for this encounter context."],
      "favor_due": ["A different line for the favor context."]
    }
  },
  "encounters": [
    {
      "context": "favor_due",
      "line_key": "favor_due",
      "event_id": "crew_favor_delivery"
    }
  ]
}
```

Model colors must be valid HTML colors. `scale` is limited to `0.75` through
`1.25`.
Current pixel-model silhouettes include `coat`, `cap`, `glasses`, and `rings`.
New renderer features can be added without changing the character/pool
selection contract.

`voice.lines` is keyed by encounter context. Each key may contain multiple
lines; the resolver selects one deterministically for that run and character.
`voice.style` is authoring direction and is not displayed to the player.

`encounters` documents what can call this character. An optional `event_id`
must reference a real event and is validated during content loading. Gameplay
effects remain in the authoritative event/lender definitions rather than being
duplicated in character flavor data.

## Add or extend a pool

Add the character ID to a pool in `pools.json`, or create a new pool:

```json
{
  "id": "new_character_group",
  "display_name": "New Character Group",
  "member_ids": ["character_a", "character_b", "character_c"],
  "lineup_size": 2
}
```

Pool members must be unique and reference existing characters. `lineup_size`
cannot exceed the pool size.

## Use a pool in a conversation

Add these fields to an event, dialogue, or lender `speaker`:

```json
{
  "name": "The Crew",
  "portrait_count": 3,
  "character_pool_id": "crew_regulars",
  "character_identity_key": "the_crew",
  "voice_line_key": "loan_offer"
}
```

- `character_pool_id` chooses the candidate set.
- `character_identity_key` identifies the encountered group. The same identity
  gets the same lineup throughout a run, even if unrelated RNG advances.
- `voice_line_key` chooses the lead member's line collection.
- The pool's `lineup_size` controls the selected and rendered lineup.
- `portrait_count` remains useful documentation on the speaker and is replaced
  by the resolved pool lineup size when the conversation is queued.

The selected lineup is copied into the queued conversation and save payload.
The first selected member speaks in front, and their name and title appear on
the name plate. The other two render behind, side-by-side. UI refreshes and
save/load cannot reshuffle an open conversation.

In-person lenders and interactable talk events automatically use the resolved
character model in the environment. The actor keeps the same object ID,
highlight, tooltip card, keyboard/controller focus, touch target, and
interaction action as the older prop. Phone-only lenders remain non-physical.

## Use one specific character

For a named character who should not be selected from a pool, use
`character_id`:

```json
{
  "name": "Example",
  "character_id": "crew_example",
  "character_identity_key": "example_contact",
  "voice_line_key": "loan_offer"
}
```

`character_id` and `character_pool_id` are mutually exclusive and validated.
The same definition drives both the in-environment animated actor and the
conversation model, so their appearance cannot drift.

Set `"environment_actor": false` on a speaker who is heard remotely, such as a
phone contact. Their conversation model still works, but no physical character
is placed in the room.

Run `tools/validate_project.ps1` and the supported `ui` and `systems`
Foundation suites after changing character content or rendering.
