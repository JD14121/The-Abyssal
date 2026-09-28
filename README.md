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
selects another data root containing `core/`, `materials/` and `items/`.
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
```

The first command imports and checks scripts; inspect its log for parser errors
as well as its exit code. The second starts the real Autoload and the Player
Foundation test world. Expected output includes `Materials: 5; Items: 10`
and `[PlayerFoundation] Test world ready`. Startup terminates with exit code 1
if data validation fails. The original data-only scene remains available at
`res://scenes/bootstrap/data_smoke_test.tscn`.

The final twelve commands run static-data, runtime-item, player, interaction,
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

Phase 5: Container Foundation

Implemented: deterministic JSON loading, typed material/item definitions,
atomic DataRegistry publication, schema/ID/reference validation, Python tools,
5 example materials and 10 example items across 6 categories.

Phase 0B adds independent item instances, UUID identities, validated condition
changes and JSON-compatible serialization/reconstruction. Usage and record
contracts are in [Architecture](docs/ARCHITECTURE.md) and
[Save Format](docs/SAVE_FORMAT.md).

Phase 2 adds a generic Interactable contract, proximity targeting and a debug
interaction pipeline. Phase 3 adds a reusable Inventory runtime object that
holds ItemInstances, calculates definition-backed weight and supports strict
in-memory serialization. Phase 4 adds spatial WorldItems and identity-preserving
pickup/drop through PlayerInventoryComponent. Containers, loot, UI and persistence
remain deferred.

Phase 5 adds generic atomic Inventory transfer, empty-by-default world Containers
with independent Inventories, and Player-local Container access. Loot, UI and
persistence remain deferred.

## Project Status

Repository initialization, static data, item runtime, player movement,
interaction, Inventory and WorldItem pickup/drop foundations are implemented.
Container access and Inventory transfers are also implemented. No Inventory or
Container UI, Loot generation or full save/load is implemented.
Existing engine settings are preserved; the project uses the DataRegistry Autoload
and the Player Foundation test-world entry scene. See [Data Schema](docs/DATA_SCHEMA.md) and
[Architecture](docs/ARCHITECTURE.md) for the current contract.

Import `game/project.godot` in Godot Project Manager to open the editor.
Use an installed Godot version compatible with the project configuration.
The current Godot executables and VS Code shortcut live outside this repository.

The first-stage empty directories exist locally. Git does not preserve empty
directories; create them as needed after cloning. No placeholder files are required.

Next phase, specified separately: Phase 6 - Loot Foundation.
