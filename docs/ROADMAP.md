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
- Stamina, food consumption and automatic health changes remain deferred to later phases

---

## Phase 8 - Consumable Foundation

- Consumable definitions and item-use validation
- Food and drink effects applied to SurvivalState
- Atomic use semantics across Inventory and survival effects
- Preserve ItemDefinition/ItemInstance separation and deterministic failure handling

This is the recommended next phase to close the first resource-to-survival loop
before adding creatures.

---

## Phase 9 - Creature and Zombie Foundation

- creature definitions
- zombie scene
- perception
- idle state
- chase state
- attack state

---

## Phase 10 - Combat Foundation

- melee attack
- damage
- knockback
- death
- simple weapon durability

---

## Phase 11 - World

- building templates
- chunks
- map generation
- world persistence

---

## Phase 12 - Advanced Simulation

Future systems:

- wounds
- bleeding
- pain
- infection
- temperature
- fatigue
- weather
- crafting
- skills

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
