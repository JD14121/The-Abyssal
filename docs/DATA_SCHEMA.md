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

## Initial Data Types

Phase 0 supports:

1. Material
2. Item

Additional types will be added incrementally.

## Files and Load Order

Content files use UTF-8 JSON. Each file contains one definition object or an
array of definition objects. Non-object entries and other root types are fatal.
JSON syntax errors, including trailing commas, unescaped control characters,
invalid escapes and malformed numeric tokens, are rejected.

`game/data/core/load_order.json` contains:

```json
{"groups": ["materials", "items"]}
```

Both groups must appear exactly once in this order in this initial version.
Missing, reordered, duplicated or unknown groups are fatal. Supporting additional
groups requires an explicit schema/implementation change. The manifest is
configuration, not a gameplay definition, so it needs no `type` or `id`.

The loader recursively reads only lowercase `.json` files in `materials/` and
`items/`. Paths are sorted lexically within each group and array order is retained.
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

## References

References use stable IDs.

Example:

"materials": [
  "steel",
  "plastic"
]

Every referenced ID must exist.

Invalid references must produce validation errors.

## Validation Requirements

The implemented pipeline detects:

- malformed JSON
- duplicate IDs
- missing required fields
- invalid field types
- unresolved references
- unknown or misplaced definition types
- negative or non-finite density/mass
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
