# Architecture

## High-Level Architecture

The diagram below describes the long-term architecture. Phase 0 implements the
static data foundation and its minimal startup verification scene. Phase 0B adds
item runtime records, creation and record serialization. Phase 1 adds a locally
controlled 2D player and a collision test world; Phase 2 adds local interaction;
Phase 3 adds a standalone Inventory runtime container. Phase 4 connects it to a
spatial WorldItem through identity-preserving Player pickup/drop transactions.
Phase 5 adds a generic Inventory-to-Inventory transfer layer and a world
Container that owns its own Inventory. Inventory itself remains separate: it
does not depend on Player, World, Interaction or UI. Phase 6 adds static Loot
definitions, resolution through injected RNG, and atomic Container Inventory
population. Phase 7 adds a shared logical GameClock and per-entity SurvivalState
advanced by a Player-local SurvivalComponent.

Gameplay Data
-> Data Registry
-> Simulation Systems
-> Runtime Entities
-> Scenes
-> UI

Persistence operates alongside runtime entities and simulation systems.

## Main Layers

### Data

Contains static definitions.

Examples:

- materials
- items
- creatures
- loot tables
- recipes
- skills

### Simulation

Contains gameplay rules.

Examples:

- survival
- combat
- time
- damage
- noise
- decay

### Runtime Entities

Contains stateful game instances.

Examples:

- player
- zombie
- item instance
- container
- world object

### Presentation

Contains Godot scenes, graphics, animations, and audio.

### UI

Displays information and receives user interaction.

### Persistence

Serializes runtime state into stable save data.

### Game Time and Survival (Phase 7)

`GameClock` is the sole global clock and advances logical game seconds from real
frame time using a configurable non-negative scale. It can pause and strictly
serialize/restore its elapsed time, scale and pause flag. It does not emit
per-frame signals. `SurvivalState` is a plain `RefCounted` value object owned
per entity; health, hunger and thirst remain bounded from 0 to 100 and serialize
as primitive fields. The Player's `SurvivalComponent` samples clock elapsed time
and applies configured hunger/thirst rates per game hour. Rates are development
placeholders, not balance data. Health does not change automatically, and no
death, stamina, consumable or UI gameplay system is implied.

## Important Separation

Static definitions must not contain per-instance state.

Example:

ItemDefinition:

kitchen_knife
mass = 0.25
base_damage = 8

ItemInstance:

definition_id = kitchen_knife
condition = 0.72
bloodied = true

## Composition

Gameplay entities should prefer reusable components.

Example Player:

Player
- Movement
- Interaction
- Inventory
- Survival
- Health
- Combat
- Equipment

Avoid deep inheritance chains.

## Globals

Autoload singletons should be limited to systems that truly require global lifetime.

Possible future singletons:

- Game
- DataRegistry
- GameClock
- EventBus
- SaveManager

Do not automatically create Manager singletons for each gameplay system.

## Implemented Data Foundation

`game/scripts/data/data_loader.gd` handles recursive sorted JSON discovery,
file reads, JSON syntax checking and source paths. A small lexical check rejects
permissive Godot JSON extensions before the engine parser handles structural
grammar and conversion.

`game/scripts/data/data_validator.gd` owns manifest, schema, ID, duplicate and
reference rules. It collects errors and unknown-field warnings with source and
field context. Supported types are material, item and loot.

`game/scripts/data/definitions/` contains typed `RefCounted` definitions. These
represent shared static data and carry their source file for diagnostics.

`game/autoload/data_registry.gd` is registered as the `DataRegistry` Autoload.
Its `_ready()` loads materials, then items, then loot. It builds temporary dictionaries,
publishes them only after all validation succeeds, and provides dictionary-based
O(1) ID lookup. Failed initial loads and reloads leave it unloaded and empty;
callers cannot accidentally query partially loaded or stale data. Loading is
synchronous, and the startup scene runs after Autoload initialization.

### Query API

```gdscript
func load_all_data(data_root: String = "res://data") -> bool
func is_loaded() -> bool
func get_material(id: StringName) -> MaterialDefinition
func has_material(id: StringName) -> bool
func get_item(id: StringName) -> ItemDefinition
func has_item(id: StringName) -> bool
func get_all_materials() -> Array
func get_all_items() -> Array
func get_loot(id: StringName) -> LootDefinition
func has_loot(id: StringName) -> bool
func get_all_loot() -> Array
func get_errors() -> Array[String]
func get_warnings() -> Array[String]
```

Missing IDs return `null` or `false`. All-definition lists and diagnostic arrays
are returned as separate arrays; altering list membership does not alter the
registry. Definition objects remain shared and must be treated as read-only.
List order follows deterministic registration order, not alphabetical ID order.
Reloading replaces the definitions; consumers must not retain old references
across a reload.

```gdscript
if DataRegistry.is_loaded():
    var knife = DataRegistry.get_item(&"kitchen_knife")
    if knife != null:
        print(knife.name, knife.mass)
```

`game/scenes/bootstrap/data_smoke_test.tscn` is the preserved data-only check scene.
It verifies the loaded state and exits with code 1 on failure. It contains no UI
or gameplay and remains an empty scene after successful startup.

### Offline Validation and Tests

The four Python entry points share `tools/data_utils.py` and use only the standard
library. The JSON tool checks syntax recursively; the ID/reference/report commands
all enforce the complete current schema before returning success. Schema rules
exist in both Python and GDScript, so changes must update both implementations
and the shared fixture cases under `game/tests/fixtures/data/`.

Python `unittest` exercises real CLI exit codes and diagnostics against temporary
data roots. The standalone Godot test script exercises the actual registry,
failure state, recovery, lookup APIs, deterministic scans and generated bulk data.
It uses `user://` temporary fixtures and never changes production content.

Export packaging is outside this phase. When adding export presets, explicitly
include runtime JSON files and exclude regression-test fixtures, then verify the
same loading contract in the exported build.

## Implemented Loot Foundation (Phase 6)

```text
Loot JSON -> LootDefinition -> DataRegistry -> LootResolver -> ItemFactory
          -> ItemInstance[] -> ContainerLootPopulator -> Inventory
```

`LootDefinition` and `LootEntry` hold static IDs and selection settings only.
Entries reference items by `item_id`; the registry validates those references
after the item group. `LootResolver` receives a ready DataRegistry, an ItemFactory
and a caller-owned RandomNumberGenerator. Per roll it selects by cumulative
weight, checks chance, rolls inclusive quantity, then creates independent
ItemInstances. It returns a success flag, items and diagnostics without depending
on Player, scenes or Inventory. Loot RNG controls selection, chance and quantity;
ItemFactory UUID generation remains independent.

`ContainerLootPopulator` resolves the complete group, checks item validity,
identity uniqueness and combined capacity, then uses Inventory's public add API.
An unexpected add failure removes only IDs added by that attempt. Existing
Inventory contents are preserved. Re-populating is allowed because no persistent
generated-state flag exists yet. Containers remain empty by default; test setup
decides which Loot group to populate.

## Implemented Item Runtime Foundation (Phase 0B)

```text
Static JSON -> ItemDefinition -> DataRegistry
                                    |
                               ItemFactory
                                    |
                               ItemInstance
                                    |
                          Serializable Dictionary
```

`game/scripts/items/item_instance.gd` is a `RefCounted` runtime data object, not a
scene node. It exposes a read-only `instance_id: String`, a read-only
`definition_id: StringName`, and a mutable `condition: float` (default `1.0`).
Instance identity and Definition identity are distinct. It neither copies static
fields nor modifies shared definitions.

`game/scripts/items/item_factory.gd` is an ordinary `RefCounted` factory created
with the existing DataRegistry. It is not an Autoload and has no global runtime
object tracker. It uses the existing lookup and ready-state APIs unchanged.
Runtime validation is kept in `item_instance_validator.gd`, separate from the
Phase 0 static schemas and Python tools.

```gdscript
var factory := ItemFactory.new(DataRegistry)
var knife := factory.create(&"kitchen_knife")
if knife != null:
    knife.set_condition(0.73)
    var definition = knife.get_definition()
    var record := knife.serialize()
    var restored := factory.deserialize(record)
```

### Runtime API and Failure Behavior

Factory API:

```gdscript
func create(definition_id: StringName) -> ItemInstance
func create_with_condition(definition_id: StringName, initial_condition: Variant) -> ItemInstance
func deserialize(data: Variant) -> ItemInstance
func get_errors() -> Array[String]
```

Factories reject absent/unready registries, unknown item IDs and invalid runtime
state. Failure returns `null`, emits `[ItemFactory]` errors and exposes a copied
diagnostic array. Each operation replaces the previous diagnostics. The Variant
boundary lets invalid serialized types fail explicitly before any coercion.

Instance API:

```gdscript
func get_definition() -> ItemDefinition
func is_valid() -> bool
func set_condition(value: Variant) -> bool
func serialize() -> Dictionary
```

Use the factory to create validated objects. `set_condition()` accepts finite
numbers from 0 through 1 and returns false without changing state for bad values,
including booleans, strings, null and non-finite numbers. Assignment to the typed
`condition` property also passes through range/finite validation; use the method
at untyped boundaries to prevent GDScript argument coercion. A zero condition has
no gameplay behavior yet. Public identity setters reject reassignment.

Factory and instances keep weak references to the supplied registry. Definitions
are looked up dynamically, so the instance sees the current definition after a
reload rather than a cached old object. If the registry is freed, unready or no
longer contains the ID, `get_definition()` returns null and `is_valid()` is false.
Serializing an invalid instance emits `[ItemInstance]` errors and returns `{}`.
Reloading valid definitions can restore validity without changing instance IDs.

### Identity and Ownership

New creation uses 16 cryptographically random bytes from Godot's built-in Crypto,
with UUID v4 version and variant bits. IDs are lowercase hyphenated strings and
do not use object IDs, addresses, array indices or timestamps. Restoration keeps
the supplied non-empty ID exactly; it never regenerates one.

Two new instances of one definition share the same static object but have
independent runtime state and different UUIDs. Restoring the same serialized ID
twice is allowed at this record boundary: future world/save ownership must detect
duplicate live identities. No global runtime registry or collision database is
introduced. UUID uniqueness is probabilistic; the 10,000-instance regression
check detects implementation mistakes, not a mathematical impossibility of collision.

The factory does not retain created instances. Their lifetime follows normal
RefCounted ownership. At Phase 0B completion, Inventory, WorldItem, equipment,
combat, SaveManager and filesystem save I/O were deferred.

The three-field serialization contract, strict reconstruction rules and future
versioning boundary are documented in [SAVE_FORMAT.md](SAVE_FORMAT.md).

## Implemented Inventory Foundation (Phase 3)

```text
ItemDefinition -> DataRegistry
       ↓
ItemFactory -> ItemInstance -> Inventory
                                  ├─ add / remove / query by instance_id
                                  ├─ live weight from ItemDefinition.mass
                                  └─ JSON-compatible runtime state
```

`game/scripts/inventory/inventory.gd` is a reusable `RefCounted` data container.
It retains the supplied `ItemInstance` references in insertion order and keeps
an index by `instance_id`; multiple instances of one definition remain distinct.
The constructor receives the registry and an optional `max_weight` (zero means
unlimited). Add validates the instance, identity, current definition and capacity
before mutating. Weight is recalculated from current definitions without a cache.
The small capacity comparison tolerance is `0.000001` kg to allow exact-limit
items through floating-point summation.

Its core API is `add_item`, `remove_item(instance_id)`, `has_item`, `get_item`,
`get_all_items`, `get_item_count` and `get_total_weight`. Removal returns the
removed reference or `null`; add/restore failures return `false`, serialization
failures return `{}`, and `get_errors()` provides copied diagnostics. A weight
calculation failure returns `NAN` instead of silently treating a missing
definition as zero mass.

`serialize()` writes `max_weight` and the nested records returned by each
`ItemInstance.serialize()`. `deserialize(data, item_factory)` strictly validates
the top-level shape, delegates item records to `ItemFactory.deserialize()`,
rejects repeated IDs and capacity overflow, and publishes the rebuilt state only
after every record succeeds. Failed restoration leaves the Inventory's previous
contents unchanged. The inventory record has no version field; versioning is
deferred until a persistent save format exists. No Player, World, Interaction,
UI, Autoload or file I/O dependency is added.

## Implemented Player Foundation (Phase 1)

```text
Input Map -> Player Controller -> Desired Velocity -> move_and_slide()
                  |
          Player (CharacterBody2D)
          + Visual (Polygon2D)
          + CollisionShape2D
          + Camera2D
```

`game/scenes/player/player.tscn` is reusable independently of any map. Its single
controller script, `game/scripts/player/player_controller.gd`, reads Input Map
actions in `_physics_process()` and drives CharacterBody2D velocity in pixels/s.
`Input.get_vector()` combines opposing directions and limits diagonal magnitude;
the pure `calculate_velocity(direction, speed)` helper also limits input magnitude
to one while retaining analog input strength. `move_speed` is an exported local
configuration value, default 220 pixels/s. Velocity is not multiplied by delta
again: CharacterBody2D applies the physics timestep in `move_and_slide()`.

There is no acceleration, friction, sprinting, direct position stepping, terrain
modifier or isometric coordinate transform. No input sets velocity to zero on
the next physics tick. The controller has no world-root paths, ItemFactory calls,
inventory, interaction, survival, combat or persistence responsibilities.

### Input, Collision and Camera

`move_up/down/left/right` bind physical W/S/A/D and the corresponding arrow keys
in `project.godot`. The controller itself uses action names, not physical keys.

Only two physics layers are named: layer 1 World and layer 2 Player. Static world
bodies use layer 1 / mask 2; the player uses layer 2 / mask 1. The player's
RectangleShape2D is 32x32 and matches its turquoise Polygon2D. Motion mode is
floating for top-down motion and sliding against all surfaces, without a floor
or gravity model. Walls are real StaticBody2D collision, not position clamps.

The player's child Camera2D is the only camera in the test world, enabled with
no smoothing. It follows the player's center without zoom controls, shake, look
ahead or effects. It has no map limits; physical world boundaries prevent the
player leaving the test yard. Some outside background is visible near map edges.

### Development Test World and Startup

`game/scenes/world/test_world.tscn` is the current project entry point. It instances
the Player at `(480, 360)` in a 1600x1000 test yard with four 32-pixel-thick outside
walls and three interior rectangular obstacles. All collision positions and
shapes are authored in the scene. `game/scripts/world/test_world.gd` draws a static
grid and placeholder wall rectangles from these shapes so surfaces match their
collision dimensions. This is not map generation or a TileMap system.

DataRegistry still initializes as an Autoload first. The test-world root checks
its ready state and exits with code 1 if static data failed to load. This startup
check is separate from the Player controller. The original data-only smoke scene
is retained unchanged. Input Map, layer names and main-scene selection are the
only Phase 1 changes to project settings; renderer, physics and stretch settings
are preserved.

`game/tests/unit/player/test_player_foundation.gd` exercises the pure calculation,
actual key/action mappings and an instantiated physics world. It verifies cardinal
and diagonal movement, opposing input, release-to-stop, configuration, distance
at 60/120 physics ticks, every boundary and obstacle, wall sliding, going around
corners and the active camera's screen center. Tests reposition the player only
to arrange scenarios; production movement always uses `move_and_slide()`.
The suite can capture the rendered viewport with `-- --capture` in a graphical
run. Manual acceptance steps and run commands are in README.

## Implemented Interaction Foundation (Phase 2)

```text
Player CharacterBody2D
└─ InteractionComponent (Area2D, layer 0 / mask Interactable)
   └─ CircleShape2D (interaction_range)
        ⇅ detects
Interactable (Area2D, layer Interactable / mask 0)
   └─ can_interact / interact / get_interaction_prompt
```

`game/scripts/interaction/interactable.gd` is a small Area2D base contract.
The interaction target is a distinct Area2D and does not have to be the physical
root of a world object; a future StaticBody2D or CharacterBody2D can own an
Interactable child component. `InteractionComponent` stores unique candidates,
prunes freed nodes, filters them through `can_interact(interactor)` and selects
the closest target by squared global distance. Equal distances retain candidate
discovery order, giving deterministic selection without priorities. It exposes
the current target and prompt API, and calls `interact()` locally on a single
Input Map `interact` press. Only this component reads the action.

The exported `interaction_range` value is the sole radius setting and updates
the component's CircleShape2D. Detection uses physics overlap on collision layer
3, independently of the Player's layer 2 body collision. No line-of-sight check
is performed, so an in-range target may be selected through a wall. There is no
formal HUD; prompt access and DebugInteractable console feedback support testing.
`game/debug/test_scenes/interaction_test.tscn` is separate from the Phase 1
movement yard and demonstrates two targets plus world collision. Automated
checks are in `game/tests/unit/interaction/`.

## Implemented World Item and Transfer Foundation (Phase 4)

```text
ItemFactory -> ItemInstance
                   ↕ same reference
       WorldItem <-> Inventory
            ↑           ↑
            └─ PlayerInventoryComponent ─ Player interaction request
```

`game/scripts/items/world_item.gd` is a spatial runtime holder of one
`ItemInstance`, not a second representation of item state. It neither creates
instances nor copies `ItemDefinition` fields. Initialization is single-use;
`take_item()` releases the same reference and makes the WorldItem ineligible for
interaction. An empty or invalid WorldItem cannot be picked up.

`PlayerInventoryComponent` owns a Phase 3 `Inventory`, creates it from the
DataRegistry at node readiness, and provides `try_pickup_world_item()` and
`drop_item(instance_id, world_parent, world_position)`. The Player controller
only forwards the generic pickup contract from Interactable to this component;
the InteractionComponent remains unaware of WorldItem behavior.

Pickup adds the current reference to Inventory first. Only after add succeeds
does the WorldItem release the reference and queue itself for deletion. A failed
add leaves the WorldItem and Inventory unchanged. Drop validates the requested
instance, parent and PackedScene, creates an empty WorldItem, removes the item,
then binds the same reference and attaches it at the caller-provided world
position. If setup fails after removal, it re-adds that same reference; rollback
failure is reported with `push_error`.

Both directions preserve `instance_id`, `definition_id` and `condition`; no new
UUID or ItemInstance is produced during transfer. There is no global ownership
registry, so Phase 3's documented duplicate-reference possibility across
separate Inventories remains until a later atomic cross-inventory transfer phase.
The component owns only the Player Inventory; no Inventory UI, drop input,
Container, Loot, stacking, item use or world persistence is included.

`game/debug/test_scenes/world_item_test.tscn` deterministically spawns two
placeholder WorldItems and displays Inventory count, total weight and the last
picked-up instance ID. Unit and integration tests exercise reference identity,
capacity rejection, duplicate IDs, drop setup failures, rollback, round-trip
weight and real Area2D/E-key target cleanup.

## Implemented Inventory Transfer and Container Foundation (Phase 5)

```text
Player
├─ PlayerInventoryComponent -> Inventory ─┐
└─ ContainerAccessComponent                │
                                            ├─ InventoryTransfer
WorldContainer -> Inventory ────────────────┘
```

`game/scripts/inventory/inventory_transfer.gd` implements the generic
`transfer_item(source, destination, instance_id)` operation. It validates both
Inventories, rejects self-transfer and unknown IDs, and calls the destination's
`can_add_item()` before changing either side. `can_add_item()` and `add_item()`
share the same Inventory validation path, including ItemInstance validity,
duplicate IDs, live definition-backed mass and the existing capacity tolerance.

After prevalidation, transfer removes the existing reference from the source
and passes it directly to the destination. An unexpected destination rejection
restores that same object to the source. A failed restoration emits `push_error`
with the instance ID, both Inventory object IDs and both failure reasons. The
normal operation neither serializes/reconstructs an item nor calls ItemFactory;
identity, definition ID, condition, total item count and combined weight remain
unchanged.

`game/scripts/containers/world_container.gd` is named `WorldContainer` in code
because Godot already has a built-in `Container` Control class. Its Area2D scene
implements the existing generic `Interactable` contract and creates one
independent Phase 3 Inventory on readiness. Each production Container starts
empty. It has no Player Inventory component, loot generation, save record or
persistent ID.

`ContainerAccessComponent` stores a Player-local active WorldContainer after its
Interactable handles E through the Player's thin `set_active_container()`
forwarder. It checks the generic InteractionComponent candidate list and clears
the active reference when the Container leaves range or is freed. The
InteractionComponent does not check for Container types. Transfers remain
independent of interaction and can operate on any two Inventory objects.

`game/debug/test_scenes/container_test.tscn` seeds fixed test-only items and
shows the active Container plus each side's count and weight. The test-only 1/2
keys transfer one item in either direction; the project's Input Map is unchanged.
Automated tests cover same-reference transfer, reverse transfer, duplicates,
capacity and exact-capacity cases, source restoration after an unexpected add
failure, combined count/weight invariants, independent empty Containers, access
cleanup, both Player/Container directions and Player-capacity rejection.
