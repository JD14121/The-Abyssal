# Save Format

## Status

The full save system has not yet been implemented. Phase 0B implements
ItemInstance serialization, and Phase 3 implements Inventory runtime-state
serialization and reconstruction through in-memory Dictionaries.

No file I/O, save slots, SaveManager or world/player persistence is implemented.
These runtime record contracts do not constitute persistent save files; full-save
requirements remain future work.

## Principle

Save runtime state, not Godot scene trees.

Static definitions should be referenced by stable IDs.

Example:

```json
{
  "instance_id": "550e8400-e29b-41d4-a716-446655440000",
  "definition_id": "kitchen_knife",
  "condition": 0.73
}
```

During loading:

definition_id
-> DataRegistry
-> Static Definition
+
Saved Runtime State
-> Runtime Instance

## Implemented Item Runtime Record

| Field | Required format | Meaning |
| --- | --- | --- |
| `instance_id` | Non-empty String, not whitespace only; differs from definition_id | Persistent identity of this individual item |
| `definition_id` | ASCII lowercase_snake_case String resolving to a known item | Reference to current shared static data |
| `condition` | Finite number in `[0.0, 1.0]`; no bool/string/null coercion | Independent runtime condition |

All three fields are required during reconstruction. New creation defaults
condition to `1.0`; restoration never substitutes this default for missing data.
Out-of-range state is rejected, never silently clamped. Runtime mutation follows
the same reject-without-change range policy.

`ItemInstance.serialize()` converts internal StringName IDs to String and returns
a fresh Dictionary containing only these three primitive fields. Static `name`,
`mass`, `materials` and `category` are not duplicated, and no Godot objects or
scene references enter the record. Modifying the returned Dictionary does not
modify the instance.

`ItemFactory.deserialize(data)` requires a ready registry, validates the entire
record before construction, returns null and reports errors on failure, and
preserves the supplied instance ID exactly on success. Input dictionaries are
not retained. New factory IDs use UUID v4; restoring existing opaque non-empty
string IDs does not require UUID format. Unknown fields, including unsupported
version fields, are rejected rather than silently discarding potentially newer
runtime state. Unknown definitions are not replaced by placeholders.

The serialized record has no version field in this minimal first version.
When the record structure changes, add explicit version handling/migration before
accepting new fields. A future full-save `save_version` is a separate enclosing
format concern and is not emitted by ItemInstance today.

Round-trip tests pass the Dictionary through `JSON.stringify()` and JSON parsing
before reconstruction and verify identity, definition ID and condition. Future
save readers must parse JSON successfully before calling `deserialize()`.

Duplicate restored instance IDs across records are the responsibility of future
ownership systems; ItemFactory validates individual records and adds no global
runtime tracker. Inventory restoration rejects duplicate IDs within one
Inventory payload. Static definitions remain shared and read-only by convention.

## Implemented Inventory Runtime State (Phase 3)

```json
{
  "max_weight": 20.0,
  "items": [
    {
      "instance_id": "550e8400-e29b-41d4-a716-446655440000",
      "definition_id": "kitchen_knife",
      "condition": 0.73
    }
  ]
}
```

`max_weight` is a finite number greater than or equal to zero; zero means no
weight limit. `items` is an insertion-ordered array of strict ItemInstance
records. No static definition fields are copied. Inventory rejects missing or
unknown top-level fields, invalid capacity values, non-array `items`, unknown
definitions, invalid item records and repeated `instance_id` values. Restoration
uses `ItemFactory.deserialize()` and is all-or-nothing; no partial Inventory is
published. Configured capacity is serialized because it belongs to this runtime
Inventory instance. Inventory state has no version field yet; versioning remains
deferred until actual persistence is introduced.

This is JSON-compatible runtime-state preparation only. There is still no
SaveManager, file I/O, slot management or disk persistence. `InventoryTransfer`
now moves the same `ItemInstance` between separate Inventories atomically in the
normal transfer path; it does not add a global ownership registry. Detecting
duplicate ownership created outside that controlled API remains future work.

Loot definitions are static data and are not embedded in runtime saves.
Generated ItemInstances are represented by the existing serialized Inventory
runtime state; Loot group IDs and roll history are not recorded.

## Phase 7 Runtime Records

The logical clock exposes a strict in-memory record with exactly
`elapsed_game_seconds` (finite non-negative number), `time_scale` (finite
non-negative number) and `paused` (boolean). Restoring rejects missing,
unknown, malformed or out-of-range fields without changing the current clock.
The pause flag is preserved as runtime clock state.

Each `SurvivalState` exposes exactly `health`, `hunger` and `thirst`, each a
finite number in `[0.0, 100.0]`. New entities start with full health and zero
hunger/thirst. Mutation clamps finite values to the range; strict restoration
rejects out-of-range values and leaves the current state unchanged. The clock
and survival dictionaries are runtime record contracts only: there is still no
file I/O, SaveManager, player persistence, or enclosing versioned save format.

## Requirements

Future saves should:

- use stable IDs
- separate static definitions from mutable state
- support validation
- support save format versioning
- avoid direct dependence on Node paths where possible

## Future Versioning

Every save should eventually include:

save_version

Example:

{
  "save_version": 1
}
