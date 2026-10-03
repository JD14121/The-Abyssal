# Development Roadmap

## Phase 0 - Foundation

Goal:

Create a reliable project and data foundation.

Tasks:

- repository structure
- project documentation
- Godot project setup
- DataRegistry
- JSON loader
- stable IDs
- duplicate ID validation
- malformed JSON validation
- reference validation
- Material definition
- Item definition
- Python data tools

Completion Criteria:

Godot can reliably load and validate at least 100 data entries.

Current Phase 0 implementation provides the initial material/item data foundation
with 5 example materials and 10 example items. Automated tests additionally
generate and validate 100 items plus 2 materials in isolated temporary roots.
The Phase 0 static data layer remains unchanged by Phase 0B and Phase 1.

---

## Phase 0B - Runtime Foundation (Complete)

- RefCounted ItemInstance with independent condition state
- ItemFactory using the existing DataRegistry
- Serializable UUID v4 runtime identities
- Strict runtime record validation and three-field serialization
- Reconstruction preserving instance IDs and JSON round-trip tests
- Definition isolation, registry lifecycle and 10,000-instance uniqueness tests
- Phase 0 regression suite retained

At Phase 0B completion, Inventory, WorldItem, equipment and full save were still
deferred.
Phase 1 player movement and Phase 2 interaction are complete below. Phase 3 -
Inventory follows its separate specification. Later systems below remain
long-term planning and may be reordered by subsequent specifications.

---

## Phase 1 - Player Foundation (Complete)

- player scene
- movement
- collision
- camera
- input mapping

Implemented a standalone CharacterBody2D player with WASD/arrow movement,
normalized diagonals, exported speed, rectangle collision and an unsmoothed
Camera2D. The development test world contains a grid floor, four boundary walls
and three static obstacles. New automated tests cover real movement, collision,
wall sliding and camera follow; Phase 0 and Phase 0B regressions remain passing.

At Phase 1 completion, no interaction key, inventory, combat, survival, animation
framework or map generation was included. Interaction was added separately in
Phase 2 and Phase 3 are recorded below.

---

## Phase 2 - Interaction Foundation (Complete)

- Generic Interactable Area2D contract with eligibility, request handling and prompt API
- Player-local InteractionComponent with configurable circular detection range
- Candidate deduplication/removal, invalid-node pruning and nearest-valid selection
- `interact` Input Map action bound to E; one request per press
- Debug interactable, isolated integration scene, and unit/integration tests

At Phase 2 completion, Inventory, pickup/drop, Container gameplay, Loot, timed
interactions, line of sight, final HUD and interaction manager were deferred.

---

## Phase 3 - Inventory Foundation (Complete)

- Reusable RefCounted Inventory holding ItemInstance references
- Add, remove and query by stable instance_id with duplicate protection
- Definition-backed total weight and optional maximum weight capacity
- Strict JSON-compatible serialization and ItemFactory-based all-or-nothing restore
- Unit, invalid-data, round-trip and 1000-instance stress coverage

No WorldItem, pickup/drop, Container, Loot, UI, equipment, stacking or disk save
system was included in Phase 3. Phase 4 follows below.

---

## Phase 4 - World Item and Pickup/Drop Foundation (Complete)

- WorldItem scene holds one existing ItemInstance without copying its definition state
- PlayerInventoryComponent owns the Phase 3 Inventory and exposes narrow transfer APIs
- interaction-driven pickup and Inventory-to-world drop preserve ItemInstance identity
- pickup/drop failures preserve holder state; post-removal drop failures restore the same instance
- deterministic two-item test scene and real Area2D/E-key integration coverage
- unit, transfer, rollback, round-trip and prior-phase regression suites

At the end of Phase 4, Inventory UI, user-facing drop input, containers, loot,
stacking, item use, and world persistence remained deferred. Phase 5 follows.

---

## Phase 5 - Container Foundation (Complete)

- generic InventoryTransfer with shared add prevalidation, capacity checks and rollback
- same ItemInstance transfer between independent Inventories without owner-type dependencies
- transfer rejection for null/invalid inventories, self-transfer, unknown IDs, duplicates and capacity
- reusable empty-by-default WorldContainer scene owning an independent Inventory
- Player-local ContainerAccessComponent with generic interaction and safe range/free cleanup
- Player ↔ Container transfers and test-only debug scene controls
- transfer invariant, rollback, Container and real interaction integration tests

No Loot, random contents, UI, stacking, batch transfer or persistence was included
in Phase 5. Phase 6 — Loot Foundation follows.

---

## Phase 6 - Loot Foundation

- **Complete** — Loot definitions, entries, registry lookup and ItemDefinition reference validation
- **Complete** — weighted selection, per-entry chance, quantity ranges and injected deterministic RNG
- **Complete** — ItemFactory-backed runtime item creation and atomic capacity-aware Inventory population
- **Complete** — Python validators, content reporting, regression coverage and documentation
- Map/building/room placement, respawn and search interactions remain future work

---

## Phase 7 - Survival

- **Complete** — shared logical GameClock with scale, pause and strict runtime-state restoration
- **Complete** — per-entity SurvivalState for health, hunger and thirst with bounded values and strict serialization
- **Complete** — Player SurvivalComponent advances hunger and thirst deterministically from game time
- **Complete** — test-only survival scene and clock/state/component regression coverage
- Stamina and automatic health changes remain deferred to later phases

---

## Phase 8 - Consumable Foundation (Complete)

- **Complete** — Consumable definitions, Item references, Registry indexes and static validation
- **Complete** — hunger/thirst deltas and exact-instance ConsumableUseService
- **Complete** — atomic Inventory/SurvivalState use with rollback diagnostics
- **Complete** — Python validator/report support, debug scene and regression tests

No Medicine, Health effects, charges, partial use, stacking, consumption UI or
persistent effect history was included. Phase 9 follows.

---

## Phase 9 - Creature and Zombie Foundation (Complete)

- **Complete** — CreatureDefinition schema, JSON data, atomic Registry integration and Python validation/reporting
- **Complete** — CharacterBody2D Zombie scene, definition binding, injected target and safe initialization failures
- **Complete** — distance-based IDLE/CHASE/ATTACK transitions and NavigationAgent2D movement with world collision
- **Complete** — real-time attack request cadence with no damage or SurvivalState coupling
- **Complete** — Creature registry/schema tests, Zombie state/cadence/navigation integration test and debug yard

No combat resolution, damage, Creature health/death, bites, scratches, wounds,
infection, hearing/noise, line of sight, vision cone, target memory,
search/investigation/wandering, Zombie separation/hordes, spawning, population
simulation, off-screen AI, loot, animation, sound or persistence was included.
Phase 10 — Combat Foundation follows.

---

## Phase 10 - Combat Foundation

- **Complete** — finite positive Creature `max_health` and `melee_damage` schema fields
- **Complete** — DamageEvent and shared DamageReceiver contract
- **Complete** — Player damage adapter backed only by SurvivalState health
- **Complete** — CreatureHealthComponent, clamped damage and one-time depletion signal
- **Complete** — CombatService and scene-local CombatCoordinator
- **Complete** — Zombie attack requests resolve once per AI cooldown in the Combat test scene
- **Complete** — depleted Zombie AI stops while the node remains in the scene tree
- Weapons, armor, wounds, death, corpses, UI and persistence remain deferred

---

## Phase 11 - Player Melee and Weapon Foundation (Complete)

- **Complete** — WeaponDefinition schema, item references, independent registry mapping and Python validation/reporting
- **Complete** — exact-ItemInstance equip/unequip and Inventory ownership revalidation
- **Complete** — Creature-only candidate detection, nearest legal target selection and deterministic tie order
- **Complete** — one-press Space input and physics-time weapon cooldown through CombatService
- **Complete** — Player melee test scene and runtime regression coverage
- Armor, wounds, infection and ranged combat remain deferred

## Phase 12 - Death and Corpse Lifecycle Foundation (Complete)

- **Complete** — Player depletion triggers a one-time defeated state and disables movement, melee, interaction and active Container access
- **Complete** — Player node, zero Health and exact Inventory contents are preserved; no Player Corpse or respawn behavior
- **Complete** — Opt-in CreatureDeathComponent stops Zombie AI/collision, initializes Corpse metadata and queues removal only after successful spawn
- **Complete** — Corpse supports placeholder inspection and remains outside Creature combat collision; it owns no Health, Inventory or Loot
- **Complete** — repeated transitions are idempotent; missing/invalid scene, invalid parent and invalid metadata leave the zero-Health Zombie inert and present
- Corpse Loot, Player death presentation, wounds, persistence and respawn remain deferred

## Phase 13 - Wound and Bleeding Foundation (Complete)

- Player DamageReceiver publishes accepted damage without adding wound rules to CombatService
- Each accepted Player hit creates an independent WoundState with a stable runtime `wound_id`
- WoundState validates and serializes its identity and finite non-negative bleeding rate
- Player WoundComponent advances bleeding using GameClock time and applies Health loss through PlayerDamageReceiver
- Lethal blood loss uses the existing Player defeat signal and lifecycle
- Body-region localization, infection, pain, fractures, UI and disk persistence were deferred at the Phase 13 boundary; Milestone B adds the first versions below

## Phase 14 - Medical and Bandage Foundation (Complete)

- MedicalDefinition static data maps a treatment Item to bleeding reduction
- TreatmentService applies a bandage to one exact `wound_id`
- Successful treatment consumes only the requested Inventory `instance_id`; invalid targets and rejected effects preserve it
- Complex infection, detailed injury treatment, and persistence remain deferred

## Milestone B - Playable Survival Sandbox (Complete)

Milestone B combines Phases 15-28 into a bounded top-down demo. It is a
systems slice with original shape-based placeholder visuals. Save/load,
streaming, large-scale population and broad authored content remain future work.

### Phase 15 - Infection and Disease Foundation (Complete)

- Independent InfectionState records advance per wound on GameClock time
- Infection causes gradual Health loss after the symptom threshold
- Antibiotic MedicalDefinition treats one infected wound and consumes the exact ItemInstance

### Phase 16 - Advanced Injury Foundation (Complete)

- Wound-linked InjuryState tracks severity, pain, fracture and recovery
- Severe injuries reduce movement speed; the HUD shows pain and fractures

### Phase 17 - Noise Foundation (Complete)

- World-local NoiseSystem emits validated events with distance falloff
- Melee and firearm attacks emit noise; Zombies react through hearing

### Phase 18 - Advanced Zombie Perception (Complete)

- Vision cone and line of sight
- Hearing, last known position, investigate, search and lost-target behavior

### Phase 19 - Zombie Population and Spawning (Complete for the bounded demo)

- Seeded spawn sites and a world-owned population cap
- Distant actors enter dormant simulation; unloading and persistence are deferred

### Phase 20 - Zombie Performance and Simulation Scaling (Complete for the bounded demo)

- Active and simplified simulation ranges
- Full, simplified and dormant simulation tiers are selected by Player distance

### Phase 21 - World Foundation (Complete for the bounded demo)

- World ownership, region/chunk coordinates and replacement of debug-only world composition

### Phase 22 - Building and Interior Foundation (Complete for the bounded demo)

- Buildings, rooms, doors, windows, furniture and Containers

### Phase 23 - Data-driven Loot Placement (Complete for the bounded demo)

- Connect building/room/furniture/container types to Loot profiles

### Phase 24 - Seeded Small-Town Generation (Complete for the bounded demo)

- Seeded roads, zones, buildings, interiors, furniture, Loot and population

### Phase 25 - Inventory UI (Complete for the bounded demo)

- Player and Container item lists, selection, transfer, weight and basic details

### Phase 26 - Equipment Foundation (Complete for the bounded demo)

- Equipment slots, hands, clothing and equipped-item state

### Phase 27 - Combat Interaction Refinement (Complete for the bounded demo)

- Facing, attack arc, hit area, weapon reach, animation timing and stagger

### Phase 28 - Ranged Weapons (Complete for the bounded demo)

- Guns, ammunition, magazines, reloading, projectile/hitscan and gunshot Noise

The default launch scene is `game/scenes/world/survival_demo.tscn`. The room,
furniture and loot references plus bounded coordinate layout live in
`game/data/world/demo_town.json`. DemoWorld's `world_seed` reproduces house
placement, loot and Zombie spawn arrangement.

## Phase 29 - Save Foundation

### World Memory workstream (bounded foundation implemented before Phase 29)

- WM-0–WM-5: repository audit, immutable causal history, semantic memory graph,
  anchors, logical-time decay, reinforcement, fragmentation, derived versions,
  and completed gameplay outcome adapters.
- WM-6: explicit observer knowledge records and source validation are available;
  NPC interpretation, social propagation and narrative remain deferred.
- Phase 29 should persist the versioned history snapshot atomically alongside
  the save manifest. Phases 30–32 should restore matching clock and gameplay
  identities, then bind actor/corpse and item evidence to restored scenes.
- No existing gameplay phases are renumbered. See
  [integration and limits](architecture/WORLD_MEMORY_INTEGRATION.md).

- SaveManager, manifest/version, atomic writes and load validation

## Phase 30 - Player Save and Load

- Position, Inventory, equipment, Health, survival state and Wounds

## Phase 31 - World State Persistence

- Containers, WorldItems, dead Creatures, Corpses, doors, windows and Loot state

## Phase 32 - Chunk Persistence and Streaming

- Nearby chunk loading, distant chunk unloading and changed-state serialization

## Phase 33 - Weather

- Rain, clouds, wind and shared weather state

## Phase 34 - Temperature

- Body/environment temperature, clothing insulation and wetness

## Phase 35 - Fatigue and Sleep

- Fatigue, sleep, rest and sleep quality

## Phase 36 - Crafting Foundation

- Recipe definitions, requirements, tools, components and results

## Phase 37 - Fire, Power and Water

- Environmental simulation for fire, electricity, water and decay

---

## Deferred

Do not prioritize until core architecture is stable:

- vehicles
- multiplayer
- NPC society simulation
- electricity networks
- farming
- large-scale fire simulation
- Steam Workshop
