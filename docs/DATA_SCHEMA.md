# Data Schema

## Purpose

Gameplay content should be defined using stable JSON data wherever practical.

The data system should support large-scale content expansion without requiring one script per content entry.

## Identifier Rules

IDs must:

- be strings
- use lowercase snake_case
- remain stable after release
- match the ASCII pattern `^[a-z][a-z0-9_]*$` over the entire string
- be unique within a definition type, including across different files

The unique key is `(type, id)`. A material and an item may share an ID.
Whitespace, non-ASCII characters and line breaks are invalid in IDs.

Examples:

kitchen_knife
steel
water_bottle_1l

## Supported Data Types

1. Material
2. Item
3. Loot group
4. Consumable
5. Creature

Consumables were added in Phase 8. Additional types will be added incrementally.

## Files and Load Order

Content files use UTF-8 JSON. Each file contains one definition object or an
array of definition objects. Non-object entries and other root types are fatal.
JSON syntax errors, including trailing commas, unescaped control characters,
invalid escapes and malformed numeric tokens, are rejected.

`game/data/core/load_order.json` contains:

```json
{"groups": ["materials", "items", "loot", "consumables", "creatures"]}
```

Production manifests list each group exactly once in dependency order. The
supported production order is `materials`, `items`, `loot`, `consumables`, then
`creatures`. Previous three- and four-group manifests remain accepted for
isolated earlier-phase fixtures. Missing, reordered, duplicated or unknown
groups are fatal. The manifest is configuration, not a gameplay definition, so
it needs no `type` or `id`.

Items load before Loot and Consumables so their `item_id` references can be
checked against an existing ItemDefinition. Consumables load after Loot; Loot
has no Consumable dependency. The loader recursively reads lowercase `.json`
Creature definitions have no references to earlier data groups. Creature data
loads last to keep stage order explicit. The loader recursively reads lowercase
`.json` files in each listed group. Paths are sorted lexically within each group
and array order is retained.
Directories must exist and be readable. Directory symbolic links are rejected.
Other directories are not runtime content in this phase; the Python syntax tool
still checks their JSON files. Broken fixtures live under `game/tests/fixtures/data/`
and are never scanned by normal startup.

## Material

Example:

```json
{
  "type": "material",
  "id": "steel",
  "name": "Steel",
  "density": 7.85,
  "flammable": false
}
```

Initial required fields:

- type
- id
- name

| Field | Validation | Default when omitted |
| --- | --- | --- |
| `type` | String equal to `material`, in the materials group | Required |
| `id` | Stable ASCII ID, unique within material definitions | Required |
| `name` | Non-empty string, not whitespace only | Required |
| `density` | Finite number >= 0; booleans are not numbers | `1.0` |
| `flammable` | Boolean | `false` |

Density uses g/cm³ for these illustrative test values. The values do not define
finished physical simulation or gameplay balance.

## Item

Example:

```json
{
  "type": "item",
  "id": "kitchen_knife",
  "name": "Kitchen Knife",
  "category": "weapon",
  "mass": 0.25,
  "materials": ["steel", "plastic"]
}
```

Initial required fields:

- type
- id
- name
- category

| Field | Validation | Default when omitted |
| --- | --- | --- |
| `type` | String equal to `item`, in the items group | Required |
| `id` | Stable ASCII ID, unique within item definitions | Required |
| `name` | Non-empty string, not whitespace only | Required |
| `category` | Non-empty string, not whitespace only; no enum restriction | Required |
| `mass` | Finite number >= 0, in kg; booleans are not numbers | `0.0` |
| `materials` | Array of string IDs resolving to loaded materials | `[]` |

Optional means absent, not `null`. Values are not silently coerced. Categories
such as food, medicine, weapon, tool, clothing and misc are examples, not an enum.

## Loot Group

Loot groups describe possible static item outcomes. They do not contain runtime
ItemInstances or copies of ItemDefinition fields.

```json
{
  "type": "loot",
  "id": "loot_test_kitchen",
  "rolls": 3,
  "entries": [
    {"item_id": "canned_beans", "weight": 10, "chance": 1.0, "min_quantity": 1, "max_quantity": 2}
  ]
}
```

| Field | Validation | Default |
| --- | --- | --- |
| `type` | String equal to `loot`, in the loot group | Required |
| `id` | Stable ASCII ID, unique within Loot definitions | Required |
| `rolls` | Finite, nonnegative integer value; bools and fractional values are rejected | Required |
| `entries` | Array of entry objects; an empty array is valid | Required |

Each entry supports:

| Field | Validation | Default |
| --- | --- | --- |
| `item_id` | Non-empty stable ID resolving to a loaded ItemDefinition | Required |
| `weight` | Finite number greater than zero; fractional weights are allowed | Required |
| `chance` | Finite number in `[0.0, 1.0]` | `1.0` |
| `min_quantity` | Nonnegative integer value | `1` |
| `max_quantity` | Integer value greater than or equal to `min_quantity` | `min_quantity` |

For each roll with nonempty entries, the resolver follows this order:

```text
weighted entry selection -> chance check -> inclusive quantity roll -> ItemFactory creation
```

Chance failure creates nothing for that roll. On success it creates that many
separate ItemInstances through ItemFactory. Rolls use replacement, so
an entry may be selected repeatedly. `rolls: 0` or an empty entries array resolves
successfully to no items; positive rolls with no entries also produce a warning.
Unknown definition and entry fields warn and are ignored.

## Consumable

A ConsumableDefinition describes the hunger and thirst changes for using one
ItemDefinition. It is a separate static profile; `category` does not grant use
behavior.

```json
{
  "type": "consumable",
  "id": "consumable_canned_beans",
  "item_id": "canned_beans",
  "hunger_delta": -25.0,
  "thirst_delta": 0.0
}
```

| Field | Validation | Default |
| --- | --- | --- |
| `type` | String equal to `consumable`, in the `consumables` group | Required |
| `id` | Stable ASCII ID, unique within Consumable definitions | Required |
| `item_id` | Non-empty ID resolving to a loaded ItemDefinition; at most one Consumable per Item | Required |
| `hunger_delta` | Finite number; positive and negative values are allowed | `0.0` |
| `thirst_delta` | Finite number; positive and negative values are allowed | `0.0` |

Delta values are added to the current `[0.0, 100.0]` SurvivalState need and use
its existing clamping rules. A negative hunger or thirst delta reduces that
need. Two zero deltas are accepted with a warning. Unknown fields follow the
static-definition warning policy and are ignored. A Consumable has its own
stable ID and need not share the referenced Item ID.

## References

References use stable IDs.

Example:

"materials": [
  "steel",
  "plastic"
]

Every referenced ID must exist.

Loot Entry `item_id` values must resolve to an ItemDefinition loaded earlier in
the manifest.

Consumable `item_id` values must also resolve to an earlier ItemDefinition;
each Item may map to at most one Consumable.

## Creature

Creature definitions hold shared AI, movement and base melee combat parameters.
The current version supports the Zombie controller and requires all fields
below:

```json
{
  "type": "creature",
  "id": "zombie_basic",
  "name": "Basic Zombie",
  "move_speed": 70.0,
  "vision_range": 320.0,
  "attack_range": 38.0,
  "attack_interval": 1.2,
  "max_health": 100.0,
  "melee_damage": 10.0
}
```

`move_speed` is world pixels per real gameplay second. `vision_range` and
`attack_range` are world-space pixels. `attack_interval` is real gameplay
seconds and is unaffected by GameClock time scale. `max_health` is the runtime
Creature's starting and maximum Health. `melee_damage` is the base damage
requested for each resolved melee attack. Every numeric field must be finite
and greater than zero; `attack_range` must not exceed `vision_range`. Creature
IDs are unique within the Creature type. Armor, damage types, hearing, loot and
Creature persistence are not part of this schema.

Invalid references must produce validation errors.

## Validation Requirements

The implemented pipeline detects:

- malformed JSON
- duplicate IDs
- duplicate Item-to-Consumable mappings
- missing required fields
- invalid field types
- unresolved references
- unknown or misplaced definition types
- negative or non-finite density/mass
- non-finite Consumable effects
- non-finite or non-positive Creature movement/perception/cadence values
- non-finite or non-positive Creature `max_health` and `melee_damage`
- Creature attack range larger than its vision range
- invalid load-order configuration or unreadable data paths

Validation errors should include:

- source file
- entry ID when available
- validation reason

Duplicate errors also identify the first definition's source. Unknown fields
produce warnings and are ignored during Definition construction. Unknown types
are fatal. Any fatal error leaves the Registry unloaded, with no partial or old
definitions exposed. A later successful explicit reload can recover it.

## Static and Runtime Data

JSON should primarily define static game content.

Runtime mutable state belongs in runtime objects and save files.

Godot constructs lightweight `RefCounted` objects with typed fields and
`StringName` IDs after validation. Each records `source_file`. Definitions are
shared static objects: consumers must treat their fields as read-only. The item
materials array is also marked read-only; the other public fields are not enforced
as immutable by the language. Static definitions do not contain instance state,
behavior or complex weapon/food fields. Phase 0B runtime records are a separate
contract documented in [SAVE_FORMAT.md](SAVE_FORMAT.md).
