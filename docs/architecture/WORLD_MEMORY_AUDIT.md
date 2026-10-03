# WM-0 repository audit

Baseline: `cde8f61b63065274c1c94c825286a17cad6ac637`, Milestone B / bounded Phase 28 Demo.
Workspace: `D:/Codex-Projects/codex-game`, origin `JD14121/The-Abyssal`.
The supplied Phase 13 brief is integrated against current behavior rather than
renaming/moving mature subsystems. The separate older 3D Demo is not this target.

The workspace already has modified gameplay/UI files and untracked presentation
scripts. Baseline diff and test logs are retained outside the runtime project in
`builds/world_memory/`. Existing modifications remain in place.

| Responsibility | Actual implementation | Integration |
|---|---|---|
| Static definitions | `autoload/data_registry.gd`, `scripts/data/` | Preserve APIs; separate validated memory configuration reuses DataLoader |
| Item identity | `scripts/items/item_instance.gd`, `item_factory.gd` | Existing stable instance_id; no history fields added |
| Inventory / WorldItem | `scripts/inventory/`, `scripts/items/world_item.gd`, `scripts/player/player_inventory_component.gd` | Existing pickup signal; add post-commit drop notification |
| Containers / Loot | `scripts/containers/`, `scripts/loot/` | No routine transfer/loot logging |
| Time / Survival | `autoload/game_clock.gd`, `scripts/survival/` | Read logical seconds; no memory-owned clock |
| Combat / weapons | `scripts/combat/`, `scripts/player/player_melee_component.gd`, `scripts/weapons/` | Preserve resolution and balance |
| Death / Corpse | `scripts/lifecycle/creature_death_component.gd`, `player_defeat_component.gd`, `corpse.gd` | Consume confirmed corpse_spawned / defeated signals |
| Wounds / bleeding | `scripts/wounds/wound_component.gd`, `wound_state.gd` | Observe significant created wounds; never log each bleeding tick or invent a death cause |
| World / population | `scripts/world/demo_world.gd`, `world_grid.gd`, `scripts/creatures/zombie_population_controller.gd` | World-local composition and adapters; scene-independent IDs |
| Tests | `tests/unit/<system>/test_*.gd`, `tools/tests/` | Standalone SceneTree suites and Python unittest |
| Documents | `docs/ARCHITECTURE.md`, `ROADMAP.md`, `CHANGELOG.md`, `SAVE_FORMAT.md` | Add WM workstream without renumbering gameplay phases |

No world save-slot manager exists yet (roadmap Phases 29–32). History/memory
provide versioned record serializers and transactional restoration only.
Existing actor and corpse scripts have no persistent entity/corpse IDs; the
adapter supplies stable opaque identities with an explicit binding boundary.
Node paths and Godot object IDs are not historical identities.

Planned new files: `scripts/history/` event/ledger/policy/serializer and world
adapter/composition; `scripts/memory/` records, graph, encoder, decay,
reinforcement, fragmentation and reconsolidation services; `scripts/knowledge/`
record/registry; `data/world_memory/` profiles/policies; focused unit/integration
suites; architecture and acceptance documents.

Planned existing production edits: DemoWorld composition plus a post-commit
PlayerInventory drop signal. Existing ItemInstance, DataRegistry, damage,
death, corpse, wound, loot, model, animation and rendering APIs stay intact.

Verification baseline and final commands use the installed Godot 4.7.2 console:
`E:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe` with
`--headless --path game --script res://tests/unit/.../test_*.gd`, plus Python
`unittest discover -s tools/tests` and JSON/schema/reference validators.
