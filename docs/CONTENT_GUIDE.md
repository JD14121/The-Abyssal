# Content Guide

## Purpose

This document defines how new gameplay content should be added.

## General Rule

Do not implement a new ordinary content entry by creating a new gameplay script.

Prefer:

JSON data
+
existing gameplay systems

## Naming

Use lowercase snake_case IDs.

Example:

canned_beans
kitchen_knife
bandage_clean

## Content Workflow

The current material/item pipeline supports the first validation and loading
steps below. Balance review and playtesting are future gameplay work:

Design
-> JSON Entry
-> Schema Validation
-> ID Validation
-> Reference Validation
-> Game Load
-> Automated Tests
-> Balance Review
-> Playtest

## Items

Items should be grouped by content purpose.

Examples:

data/items/food/
data/items/medicine/
data/items/weapons/
data/items/tools/
data/items/clothing/
data/items/misc/

## Data Ownership

JSON describes what an object is.

GDScript describes how game systems behave.

Avoid embedding complex executable behavior in content data.

## Current Material and Item Workflow

Add JSON objects or arrays under `game/data/materials/` or `game/data/items/`.
Subdirectories are supported. Follow the required fields and defaults in
[DATA_SCHEMA.md](DATA_SCHEMA.md), then run the four Python tools documented in
[README.md](../README.md). Start the Godot data verification scene to confirm the
runtime path as well. Unknown fields warn; invalid fields, IDs and references fail
the whole load. Keep intentionally invalid examples in test fixtures.

## Loot Groups

Add a Loot definition or array under `game/data/loot/`. Choose a stable
`loot_...` ID, set a nonnegative integer-valued `rolls` count, and reference
existing item IDs in `entries`. Each entry needs a positive relative `weight`;
optional `chance` defaults to `1.0`, `min_quantity` defaults to `1`, and
`max_quantity` defaults to the minimum. Keep Loot weight separate from the
referenced item's mass. An empty entries array is valid and resolves to no items.

Run the Python JSON, ID, reference and content-report commands from the
repository root, then run the Godot Loot registry and resolver tests. Runtime
selection uses the caller's injected RandomNumberGenerator; fixed seeds make
tests repeatable. The resolver returns fresh ItemInstances, and callers can use
ContainerLootPopulator to add all of them atomically to an Inventory. Loot
profiles are not bound to every Container automatically.

## Consumable Profiles

To make an existing Item usable for hunger/thirst effects:

1. Create or confirm its ordinary `ItemDefinition` under `game/data/items/`.
2. Add a `ConsumableDefinition` under `game/data/consumables/` with a unique
   Consumable `id` and an `item_id` referencing that Item.
3. Set optional finite `hunger_delta` and `thirst_delta` values; omitted fields
   default to zero. Negative values reduce the need; positive values increase it.
4. Keep each Item mapped to at most one Consumable profile. Two zero effects are
   allowed but produce a warning.
5. Run the Python JSON, ID, reference and content-report tools, then run the
   Consumable Registry and use-service tests.

Consumable behavior comes from this profile rather than the Item category. The
current use service consumes one exact Inventory `instance_id`; it does not
support WorldItems, Container UI, charges or partial use.

## Creature Definitions

To add a Creature definition for the AI and base melee combat layers:

1. Choose a stable lowercase `id` and non-empty `name`.
2. Add a record under `game/data/creatures/` with `move_speed`, `vision_range`,
   `attack_range`, `attack_interval`, `max_health` and `melee_damage`.
3. Use finite positive values and keep `attack_range <= vision_range`.
4. Run the JSON, ID, reference and content-report tools; the report includes
   `Creatures: N`.
5. Set the matching `definition_id` on a Zombie scene/controller and exercise
   it in `res://debug/test_scenes/zombie_test.tscn`.
6. To exercise resolved attacks, use `res://debug/test_scenes/combat_test.tscn`,
   where the scene-local CombatCoordinator is explicitly connected.

Creature parameters describe shared static data. `attack_interval` controls
when ZombieController requests attacks; `melee_damage` is applied by Combat
only after a request reaches a scene-local CombatCoordinator. ZombieController
owns runtime targeting and state and never changes Health. Perception uses
distance only, so walls do not block detection. Creature runtime Health belongs
to CreatureHealthComponent. Armor, damage types, death, hearing, loot and
persistence are not implemented.
