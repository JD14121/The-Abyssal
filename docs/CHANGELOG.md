# Changelog

## Unreleased

### Added

- Milestone B Survival Demo: seeded bounded town, JSON-authored rooms/furniture/loot, doors, windows, world containers and extraction objective
- WorldGrid, scene-local NoiseSystem, Zombie vision/hearing/investigation/search, bounded population, staggered simplified AI and dormant tiers
- Wound-linked infection and injury progression, antibiotic treatment, pain/fracture status and movement penalties
- Inventory/Container HUD, item use/drop/treatment, equipment slot references, facing melee/stagger/noise and projectile firearm combat with ammo/reload
- Milestone B assembly and deterministic seed tests; Python validates weapon ammunition and demo layout loot references
- MedicalDefinition JSON schema, Item lookup indexes and validated Bandage profile
- TreatmentService for exact `wound_id` bleeding treatment with exact Inventory ItemInstance consumption and rollback on rejected Wound mutation
- Medical registry/treatment tests and Python Medical validation/reporting coverage
- Milestone A Combat Survival Slice record
- Player WoundState records with unique wound IDs, strict runtime serialization and bleeding reduction
- Player WoundComponent creates a Wound for each accepted hit and applies GameClock-based blood loss through PlayerDamageReceiver
- Wound foundation and Player/Combat bleeding integration tests
- PlayerDefeatComponent shuts down Player movement, melee, interaction and Container access once Health depletes while preserving the Player node and Inventory
- Optional CreatureDeathComponent transaction replaces a depleted Zombie with a non-blocking, inspectable Corpse; failed setup leaves the Zombie inert and present
- Corpse metadata, placeholder inspection, death/corpse debug scene, lifecycle tests and persistence deferral notes
- WeaponDefinition JSON and atomic DataRegistry indexes, static/Python validation, and Weapon reporting
- PlayerMeleeComponent with exact-instance equip validation, Creature-only target tracking, nearest-target selection, one-press Space input and physics-time cooldown
- Player melee attacks through the existing CombatService, plus a two-Zombie melee debug scene and integration checks
- Combat foundation: Creature max health and melee damage, DamageEvent, DamageReceiver adapters, Creature runtime health, CombatService, scene-local CombatCoordinator, Zombie attack resolution, depletion handling, tests and an isolated Combat debug scene
- CreatureDefinition static schema, Creature Registry lookup, and all-or-nothing load integration
- Zombie CharacterBody2D scene with distance perception, IDLE/CHASE/ATTACK behavior, NavigationAgent2D and attack-request cadence
- Creature Python validation/report support, invalid fixtures, runtime/navigation tests and Zombie debug yard
- ConsumableDefinition data, item-to-Consumable Registry lookups and Item reference validation
- Atomic hunger/thirst ConsumableUseService that consumes the exact ItemInstance with rollback diagnostics
- Consumable Python validation/content reporting, fixtures, tests and development test scene

- Shared GameClock Autoload with scaled logical time, pause and strict runtime-state serialization
- Independent bounded SurvivalState and Player SurvivalComponent driven by elapsed game time
- Phase 7 survival debug scene and deterministic GameClock/state/component tests

- LootDefinition/LootEntry static data, load-order integration and ItemDefinition reference validation
- Weighted LootResolver with injected RNG, chance checks, quantity ranges and ItemFactory instances
- Atomic Container Inventory population with capacity prevalidation and rollback
- Original test Loot groups, invalid fixtures, Python reporting support and fixed-seed Loot test scene
- Loot schema, authoring workflow and pipeline documentation

- Generic InventoryTransfer with shared prevalidation, identity preservation and same-instance rollback
- WorldContainer scene with an independent empty-by-default Inventory
- Player-local Container access that clears when leaving range or when the Container is freed
- Player-to-Container and Container-to-Player transfer integration
- Transfer invariants, rollback, Container foundation and interaction integration tests
- Container debug test scene with active Container and Inventory count/weight feedback

- WorldItem spatial runtime scene holding an existing ItemInstance reference
- PlayerInventoryComponent owning the Phase 3 Inventory and identity-preserving pickup/drop APIs
- Pickup transaction, validated drop setup and same-instance rollback on failure
- Deterministic WorldItem test scene with inventory count, weight and last-pickup feedback
- WorldItem ownership, pickup/drop, rollback, round-trip and Area2D interaction tests

- Reusable RefCounted Inventory with instance-ID add/remove/query operations
- Definition-backed weight, optional capacity and atomic add validation
- Strict Inventory serialization and ItemFactory-based all-or-nothing restoration
- Inventory core, invalid-data, round-trip and 1000-instance stress tests

- Phase 2 Interactable contract and reusable Player InteractionComponent
- Circular proximity detection, candidate tracking, nearest-valid target selection and prompt API
- E-bound `interact` action and one-request-per-press behavior
- Debug interactable, isolated interaction test scene, and unit/integration tests

- Phase 1 CharacterBody2D Player with a 32x32 placeholder and collision shape
- WASD/arrow Input Map actions and normalized physics movement at configurable speed
- Local Camera2D follow with no smoothing or gameplay dependencies
- Development test world with four boundary walls and three static obstacles
- Player calculation and integration tests, including wall sliding and camera scrolling

- Phase 0B ItemInstance runtime model with independent validated condition
- ItemFactory with UUID v4 creation and identity-preserving reconstruction
- Strict runtime record validation and JSON-compatible three-field serialization
- Runtime tests for isolation, registry lifecycle, malformed records and round-trips
- Uniqueness check for 10,000 live item instances across two factories

- Initial repository architecture
- Project development documentation
- Data architecture specification
- Initial DataRegistry Autoload with atomic loading and dictionary-based queries
- Deterministic recursive JSON loader with strict token checks
- Typed MaterialDefinition and ItemDefinition static objects
- Schema, stable ID, duplicate ID and material-reference validation
- Four standard-library Python validation/report tools with shared utilities
- Five example materials and ten items covering six categories
- Minimal data startup verification scene
- Shared invalid fixtures, Python CLI regression tests and Godot data tests
- Generated 100-item validation coverage without adding bulk production content

### Changed

- Project entry point now opens the Player test world after checking DataRegistry
- Added explicit World/Player collision layer names; existing engine settings preserved
- Added Player run commands and manual movement/collision/camera acceptance steps

- Documented actual schemas, defaults, query APIs, startup and validation commands
- Added Loot as the third static data group after Materials and Items
- Added DataRegistry and the verification main scene while preserving engine settings
