# Hardcore Survival Game

A data-driven hardcore survival game built with Godot 4.x.

The project focuses on systemic survival simulation, modular gameplay systems, expandable content data, and long-term maintainability.

## Technology

- Godot 4.x
- GDScript
- JSON
- Python 3
- Git
- GitHub
- Codex-assisted development

## Repository

Repository root:

D:\Codex-Projects\codex-game

Godot project:

D:\Codex-Projects\codex-game\game

## Opening the Project

Open the following directory using Godot Project Manager:

D:\Codex-Projects\codex-game\game

Open the repository root in VS Code / Codex:

D:\Codex-Projects\codex-game

## Repository Structure

`game/`
Godot runtime project.

`docs/`
Architecture, design, schema, roadmap, and development documentation.

`tools/`
Python validation and content-development utilities.

`source_assets/`
Editable source files for art and audio.

`reference/`
External reference repositories and research material.

`builds/`
Local game builds.

## Data Architecture

Gameplay content should be data-driven where practical.

Static content is stored in JSON under:

game/data/

Runtime logic is implemented in GDScript.

The implemented data foundation is:

JSON
-> Data Loader
-> Schema / ID / Reference Validation
-> Definitions
-> Registry

Future simulation, runtime entities and scenes/UI will query this registry.

## Data Validation

Run from the repository root with Python 3.10+ (standard library only):

```powershell
python tools/validate_json.py
python tools/validate_ids.py
python tools/validate_references.py
python tools/content_report.py
python -m unittest discover -s tools/tests -v
```

All tools return 0 on success and 1 for content errors. `--data-root PATH`
selects another data root containing `core/`, `materials/`, `items/` and `loot/`;
the production six-group manifest also requires `consumables/`, `creatures/`
and `weapons/`.
The default root is resolved relative to the tools, independent of the working directory.
The syntax checker scans all JSON recursively. The other three tools validate
the complete supported schemas, IDs and references before reporting success.

Godot verification using the current external tools directory (or set the variable
to your installed Godot executable):

```powershell
$godotExecutable = 'D:/Codex Projects/md and tools/Godot_v4.7.2-stable_win64_console.exe'
& $godotExecutable --headless --editor --path './game' --quit
& $godotExecutable --headless --path './game' --quit-after 2
& $godotExecutable --headless --path './game' --script res://tests/unit/data/test_data_foundation.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/items/test_runtime_foundation.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/player/test_player_foundation.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/interaction/test_interaction_foundation.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/interaction/test_interaction_integration.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/inventory/test_inventory_foundation.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/inventory/test_inventory_stress.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/items/test_world_item_foundation.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/interaction/test_world_item_integration.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/inventory/test_inventory_transfer.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/containers/test_container_foundation.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/containers/test_container_integration.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/loot/test_loot_registry.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/loot/test_loot_resolution.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/core/test_game_clock.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/survival/test_survival_state.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/survival/test_survival_component.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/consumables/test_consumable_registry.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/consumables/test_consumable_use_service.gd
& $godotExecutable --headless --path './game' res://debug/test_scenes/consumable_test.tscn --quit-after 4
& $godotExecutable --headless --path './game' --script res://tests/unit/creatures/test_creature_registry.gd
& $godotExecutable --headless --path './game' --script res://tests/unit/creatures/test_zombie_foundation.gd
& $godotExecutable --headless --path './game' res://debug/test_scenes/zombie_test.tscn --quit-after 4
& $godotExecutable --headless --path './game' --script res://tests/unit/combat/test_combat_foundation.gd
& $godotExecutable --headless --path './game' res://debug/test_scenes/combat_test.tscn --quit-after 4
& $godotExecutable --headless --path './game' --script res://tests/unit/combat/test_player_melee_foundation.gd
& $godotExecutable --headless --path './game' res://debug/test_scenes/player_melee_test.tscn --quit-after 4
```

The first command imports and checks scripts; inspect its log for parser errors
as well as its exit code. The second starts the real Autoload and the Player
Foundation test world. Expected output includes `Materials: 5; Items: 10; Loot: 9; Consumables: 2; Creatures: 2; Weapons: 1`
and `[PlayerFoundation] Test world ready`. Startup terminates with exit code 1
if data validation fails. The original data-only scene remains available at
`res://scenes/bootstrap/data_smoke_test.tscn`.

The test commands run static-data, runtime-item, player, interaction,
Inventory, WorldItem, transfer and Container tests and return nonzero if any check fails. The runtime suite also creates 10,000 live
instances across two factories to check UUID uniqueness and format.
Negative cases intentionally emit errors/warnings; the final check summary
distinguishes expected rejections from test failures. Tests use isolated temporary
data roots and never modify production `game/data`.

The player suite drives the real Input Map and physics scene. It checks no-input
behavior, direction, opposing keys, diagonal speed, configurable speed, 60/120 Hz
physics movement, obstacles, all four map boundaries, wall sliding and camera
scrolling. It takes about 15 seconds with the default physics tick rate.

## Run and Check Player Foundation

Open `game/project.godot` in Godot and press **F6** with
`game/scenes/world/test_world.tscn` open, or press **F5** to run the project.
From the repository root, use the executable variable above without `--headless`:

```powershell
& $godotExecutable --path './game'
```

Manual acceptance:

1. Locate the turquoise square on the grid floor; it spawns clear of obstacles.
2. Press W, A, S and D individually: up, left, down and right. Arrow keys also work.
3. Hold W+D and compare with D alone: diagonal speed must not be faster.
4. Hold W+S or A+D: opposing directions must cancel.
5. Walk against all four outside walls and each of the three interior obstacles;
   the square must stop at the visible surface rather than pass through it.
6. Hold a diagonal direction against a wall: slide along it, then move around its corner.
7. Cross the open floor and verify that the camera keeps following the square.
8. Release all movement keys: the square must stop without drifting.

Speed is configured by the player's `move_speed` property (default 220 pixels/s).
The player is a 32x32 placeholder without character animation. The Phase 1 map
is a development test yard, not the production world. Interaction uses a
separate scene:

```powershell
& $godotExecutable --path './game' res://debug/test_scenes/interaction_test.tscn
```

Walk within 96 pixels of the orange test objects; the nearest eligible object is
the current target. Press E to print one interaction message. The component
exposes the target prompt API, but no interaction HUD is included.

## Run and Check World Item Foundation

Run the dedicated pickup scene:

```powershell
& $godotExecutable --path './game' res://debug/test_scenes/world_item_test.tscn
```

Move next to either yellow item and press E. The debug label reports Inventory
count, total weight and the last picked-up instance ID. The scene has two fixed
items for nearest-target and candidate-cleanup checks; it has no drop input or
Inventory UI. The two Phase 4 test scripts are listed with the Godot regression
commands above.

## Run and Check Container Foundation

Run the dedicated Container scene:

```powershell
& $godotExecutable --path './game' res://debug/test_scenes/container_test.tscn
```

Move near a container and press E to access it. The debug scene shows the active
container and each Inventory's count and weight. Press **1** to transfer one item
from the Player to the active Container or **2** for the reverse transfer. These
keys exist only in this test scene; gameplay interaction remains on E.

## Run and Check Loot Foundation

Run the fixed-seed Loot test scene:

```powershell
& $godotExecutable --path './game' res://debug/test_scenes/loot_test.tscn
```

It populates two empty Containers with kitchen and medical test groups and shows
their seeds, item counts and generated definition IDs. The dedicated tests cover
static validation, weighted selection, chance, quantity, seed repeatability,
capacity rejection and add-failure rollback. Re-population is allowed; this
development scene does not add Loot UI or automatic world placement.

## Run and Check Consumables

Run `res://debug/test_scenes/consumable_test.tscn`. It creates one canned-bean
instance, one water bottle and one hammer in the Player Inventory. Press **3**
to advance an hour, **1** to use the beans, **2** to use the water, or **H** to
verify a non-consumable is rejected; WASD movement remains available. The debug
text shows needs, held instance IDs and the last use result. This scene does not
add a formal use input, Inventory UI or Survival HUD.

## Run and Check Combat Foundation

Open `game/debug/test_scenes/combat_test.tscn` and run it with F6, or use:

```powershell
& $godotExecutable --path './game' res://debug/test_scenes/combat_test.tscn
```

Move the Player with WASD or the arrow keys. The test-only status label shows
Player and Zombie Health, Zombie state and attack requests. When the Zombie
reaches attack range, each AI request reduces Player Health by the displayed
melee damage at the configured attack interval. Press **H** to apply 25 test
damage to the Zombie. This scene explicitly connects CombatCoordinator;
`zombie_test.tscn` remains AI-only and has no damage resolution.

## Development Rules

Read `AGENTS.md` before making significant changes.

Important principles:

- keep data and logic separated
- prefer composition
- avoid hardcoded gameplay content
- use stable string IDs
- validate references
- make small incremental changes
- run tests after modifications

## Current Development Phase

Phase 8: Consumable Foundation (complete)

Implemented: deterministic JSON loading, typed material/item definitions,
atomic DataRegistry publication, schema/ID/reference validation, Python tools,
5 example materials and 10 example items across 6 categories. Consumable profiles
reference Items by ID and contain only hunger/thirst deltas.

Phase 9: Creature / Zombie Foundation (complete)

Implemented: shared CreatureDefinition loading and validation, a data-bound
ZombieController with distance-based IDLE/CHASE/ATTACK states, NavigationAgent2D
movement and an attack-request signal. The debug yard includes a navigable
obstacle; this AI-only scene has no CombatCoordinator and does not resolve damage.

Phase 10: Combat Foundation (complete)

Implemented: Creature maximum Health and melee damage, DamageEvent,
DamageReceiver, Player damage through SurvivalState, CreatureHealthComponent,
CombatService and a scene-local CombatCoordinator. The separate Combat test
scene connects Zombie requests to damage resolution. A depleted Zombie stops
acting but stays in the scene.

Phase 11: Player Melee and Weapon Foundation (complete)

WeaponDefinition maps existing Items to validated damage, range and interval
values. PlayerMeleeComponent equips one exact Inventory ItemInstance, tracks
Creature targets independently of interaction, and resolves Space-triggered
attacks through CombatService. The `player_melee_test.tscn` scene seeds and
equips a knife and places two Zombies in the test yard. Health depletion still
does not create a corpse; armor, wounds, death, UI and persistence remain future
work.

Phase 0B adds independent item instances, UUID identities, validated condition
changes and JSON-compatible serialization/reconstruction. Usage and record
contracts are in [Architecture](docs/ARCHITECTURE.md) and
[Save Format](docs/SAVE_FORMAT.md).

Phase 2 adds a generic Interactable contract, proximity targeting and a debug
interaction pipeline. Phase 3 adds a reusable Inventory runtime object that
holds ItemInstances, calculates definition-backed weight and supports strict
in-memory serialization. Phase 4 adds spatial WorldItems and identity-preserving
pickup/drop through PlayerInventoryComponent.

Phase 5 adds generic atomic Inventory transfer, empty-by-default world Containers
with independent Inventories, and Player-local Container access. Phase 6 adds
validated Loot groups, injected-RNG resolution into independent ItemInstances,
and all-or-nothing capacity-aware Container population. Phase 8 adds
ConsumableDefinition loading and atomic consumption of an exact Inventory item
instance. Phase 9 adds a generic Creature registry and Zombie AI/navigation
foundation. Phase 10 adds the first damage resolution pipeline and Phase 11
adds Player melee. Map placement, UI and persistence remain deferred.

## Project Status

Repository initialization, static data, item runtime, player movement,
interaction, Inventory and WorldItem pickup/drop foundations are implemented.
Container access, Inventory transfers and the Loot foundation are implemented.
The Phase 7 GameClock and Player survival foundations, Phase 8 Consumable
Foundation, Phase 9 Creature/Zombie Foundation, Phase 10 Combat Foundation and
Phase 11 Player Melee / Weapon Foundation are implemented. No
Inventory or Container UI, map-based Loot placement or full save/load is implemented.
Existing engine settings are preserved; the project uses DataRegistry and GameClock
Autoloads and the Player Foundation test-world entry scene. See [Data Schema](docs/DATA_SCHEMA.md) and
[Architecture](docs/ARCHITECTURE.md) for the current contract.

Import `game/project.godot` in Godot Project Manager to open the editor.
Use an installed Godot version compatible with the project configuration.
The current Godot executables and VS Code shortcut live outside this repository.

The first-stage empty directories exist locally. Git does not preserve empty
directories; create them as needed after cloning. No placeholder files are required.

Recommended next phase: Phase 12 - Death and Corpse Lifecycle.
