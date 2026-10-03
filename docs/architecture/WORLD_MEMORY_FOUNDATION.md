# World Memory Foundation — Codex Integration Brief

> Project: **The-Abyssal / codex-game**  
> Repository: `JD14121/The-Abyssal`  
> Known local workspace: `D:\Codex-Projects\codex-game`  
> Baseline assumption for this brief: **Phase 13 — Wound & Bleeding Foundation completed**  
> Intended location in repository: `docs/architecture/WORLD_MEMORY_FOUNDATION.md`  
> Status: architecture specification / implementation brief for Codex

---

## 0. Codex execution directive

This document defines the architectural direction for adding a **World Memory Foundation** to the existing Godot survival-game codebase.

Before changing any code, Codex MUST:

1. Audit the actual repository tree and current HEAD.
2. Confirm the real locations/names of:
   - Data Registry / definition loading;
   - runtime item instances;
   - Inventory / WorldItem;
   - Loot;
   - Survival;
   - Combat;
   - Weapon / melee;
   - Lifecycle / death / Corpse;
   - Wound & Bleeding;
   - test directories;
   - architecture / roadmap / changelog documents.
3. Treat all paths in this brief as **recommended target structure**, not as proof that those exact folders already exist.
4. Preserve all Phase 0–13 behavior and all existing tests.
5. Do not perform a broad refactor merely to match this document's names.
6. Prefer adapters and narrow integration points over changing mature subsystems.
7. Implement the memory system as a new foundation layer; do not make existing gameplay systems depend on memory internals.
8. Do not add full ecosystem simulation, NPC oral-history simulation, large-scale world persistence, procedural narrative AI, or multiplayer legacy exchange in the first memory phase.
9. Keep deterministic logic testable. Any distortion/random fragmentation must use injected RNG/seeded deterministic sources.
10. Stop and report if the repository architecture materially conflicts with this brief instead of silently rewriting established boundaries.

The memory subsystem is intended to become infrastructure for later:

- long-term world persistence;
- historical archaeology;
- player/NPC legacy;
- relic interpretation;
- ecological evidence;
- settlement archives;
- rumors and cultural memory;
- world evolution across decades/centuries/millennia.

It is **not** a replacement for SaveGame, WorldSimulation, Loot, AI, or Lifecycle.

---

# 1. Design objective

The world must be capable of distinguishing between:

1. **what actually happened**;
2. **what physical traces remain**;
3. **what a particular observer currently believes**;
4. **what society has preserved as history**;
5. **what has been distorted, fragmented, forgotten, or rediscovered**.

The central rule is:

> **Persist causality; allow memory to decay.**

A historical fact may remain causally relevant even after every character has forgotten it.

Example:

```text
Explorer dies
    ↓
corpse decomposes
    ↓
local soil nutrients increase
    ↓
fungal colony expands
    ↓
animal distribution changes
```

Centuries later, the explorer's name may be completely forgotten while the fungal colony still exists.

Therefore:

```text
Historical truth != world memory != observer knowledge != narrative
```

These must be separate layers.

---

# 2. Existing project systems and intended relationship

The current project already contains foundations for:

- static data loading / validation / registry;
- runtime `ItemInstance`;
- Inventory;
- player interaction;
- WorldItem pickup/drop;
- Container / transfer;
- Loot;
- GameClock / Survival;
- Consumables;
- Creature / Zombie AI;
- Combat;
- weapons / melee;
- Lifecycle / death;
- Corpse;
- Wound & Bleeding.

The World Memory Foundation must consume **significant completed outcomes** from those systems without taking ownership of their gameplay logic.

Target dependency direction:

```text
Combat / Lifecycle / WorldItem / Survival / Wounds / future World
                     │
                     │ significant event notifications / adapters
                     ▼
              Historical Event API
                     │
                     ▼
                Causal Ledger
                     │
                     ▼
                Memory Encoder
                     │
                     ▼
              World Memory Graph
                     │
            ┌────────┴────────┐
            ▼                 ▼
      Memory Anchors     Knowledge Layer
            │                 │
            ▼                 ▼
 physical evidence      beliefs / archives
```

Forbidden dependency direction:

```text
CombatService -> MemoryGraph internals
Inventory -> KnowledgeRegistry internals
Health -> narrative generation
Corpse -> global historical query logic
```

Existing systems should emit or submit narrowly-scoped event records; the history/memory layer performs the rest.

---

# 3. Two-network architecture

The architecture MUST separate two graphs.

## 3.1 Causal Ledger — objective causal truth

Purpose:

- store the compact canonical record of significant events;
- preserve cause/effect linkage;
- remain stable even when world memory is destroyed;
- support future historical reconstruction and world-evolution causality;
- never represent rumor as truth.

Characteristics:

```text
append-oriented
immutable historical events
compact
deterministic
serializable
not directly player-facing
not subject to memory decay
```

The ledger is **not** intended to record every frame or action.

It records only events accepted by a significance policy.

Examples:

- character death;
- important injury;
- first/deepest exploration record;
- unique creature encounter;
- discovery of a region/relic;
- construction/destruction of a persistent structure;
- ownership transfer of historically significant relics;
- placement/loss of an important object;
- major ecological change;
- major geological change;
- migration anomaly;
- settlement archival event.

The ledger must never contain generated prose as its canonical representation.

---

## 3.2 World Memory Graph — mutable memory

Purpose:

- represent what traces of history remain accessible in the world;
- bind memories to real physical/social/environmental anchors;
- allow reinforcement;
- allow fading;
- allow fragmentation;
- allow distortion;
- allow dormancy;
- allow rediscovery/reactivation;
- support multiple conflicting versions of the same underlying event.

Characteristics:

```text
mutable
evidence-linked
observer-accessible
subject to time and environment
may be incomplete
may be incorrect
may conflict with other memories
```

A memory graph node must be able to survive without exposing the entire Causal Ledger event.

Example:

```text
Truth:
Explorer Elias and Mara entered Mine 7 at depth 2130m.
Mara died after attack by Creature_17.

Late memory:
"Someone died in Mine 7."

Later cultural residue:
"Mine 7 is dangerous."
```

The causal event remains stable.  
The world memory becomes progressively less specific.

---

# 4. Third layer: Knowledge Registry

The World Memory Graph represents memory/evidence available in the world.

A future/current **Knowledge Registry** represents what a specific observer or institution believes.

Possible observer scopes:

```text
character
NPC
faction
research guild
settlement
archive
general culture
```

Do not conflate:

```text
evidence exists
```

with:

```text
a character knows the evidence
```

or:

```text
society accepts the conclusion
```

Recommended flow:

```text
Causal Ledger
    ↓ encoded traces
World Memory Graph
    ↓ discovered/interpreted
Knowledge Record
    ↓ shared/archived
Institutional or Cultural Knowledge
```

The first memory-foundation phase may implement only the data boundary/interface for Knowledge Registry if full observer knowledge is outside current scope.

---

# 5. Core runtime data models

The exact GDScript class names may be adapted to repository conventions after audit.

## 5.1 `HistoricalEvent`

Represents one canonical significant event.

Recommended fields:

```text
event_id
schema_version
event_type
world_time
location_ref
absolute_depth
actor_refs[]
object_refs[]
cause_event_ids[]
effect_tags[]
fact_fragments[]
significance_tags[]
source_system
```

Rules:

- `event_id` immutable.
- Event data immutable after acceptance into ledger.
- References use stable IDs, not Node references.
- Runtime Nodes must not be serialized into historical data.
- Historical events must remain valid after scenes unload.
- Causes refer to prior canonical event IDs where known.
- Missing causal knowledge is allowed; never fabricate a cause.

### Suggested JSON-like debug representation

```json
{
  "event_id": "evt_...",
  "schema_version": 1,
  "event_type": "character_death",
  "world_time": {
    "tick": 843102
  },
  "location_ref": {
    "region_id": "region_07",
    "area_id": "mine_7"
  },
  "absolute_depth_m": 2130.0,
  "actors": [
    {
      "entity_id": "character_elias",
      "role": "subject"
    }
  ],
  "objects": [
    {
      "instance_id": "item_knife_882",
      "role": "carried_relic_candidate"
    }
  ],
  "cause_event_ids": [
    "evt_bleeding_..."
  ],
  "facts": [
    {
      "key": "death_cause",
      "value": "blood_loss"
    }
  ],
  "source_system": "lifecycle"
}
```

This is a serialization/debug shape, not necessarily the exact on-disk format.

---

## 5.2 `CausalLedger`

Responsibilities:

```text
append_event(event)
has_event(event_id)
get_event(event_id)
get_causes(event_id)
get_effects(event_id)
query_by_actor(...)
query_by_object(...)
query_by_location(...)
```

Foundation requirements:

- append-only public behavior;
- duplicate ID rejection;
- invalid reference validation;
- deterministic ordering;
- no mutation through returned collections;
- failed append must not partially change state;
- no generated prose;
- no memory decay logic.

The ledger may initially live in memory if Save/World Persistence is not yet implemented, but serialization boundaries and round-trip tests should exist from the beginning.

---

## 5.3 `MemoryClaim`

Memory must not be represented as a single prose sentence.

A memory node should be composed of semantic claim fragments.

Example:

```text
subject = character_elias
predicate = entered
object/location = mine_7
qualifier depth = 2130m
```

or:

```text
subject = character_mara
predicate = died_at
object = mine_7
```

Recommended fields:

```text
claim_id
subject_ref
predicate
object_ref_or_value
source_event_ids[]
clarity
retention
confidence
accessibility
fragment_state
```

Important:

- gameplay-accessible memory should not contain an authoritative `truth_accuracy` field;
- tests/debug tools may compare claims against the Causal Ledger;
- confidence is not truth;
- reinforcement may increase confidence while accuracy remains poor.

---

## 5.4 `MemoryNode`

Represents a coherent remembered episode/concept.

Recommended fields:

```text
memory_id
memory_class
memory_state
claim_ids[]
anchor_refs[]
edge_refs[]
created_world_time
last_reinforced_world_time
reinforcement_score
redundancy_score
accessibility
stability
fragmentation
```

Do not encode the entire memory only as free text.

Optional presentation text should be generated later from claims.

---

## 5.5 `MemoryEdge`

Represents relationships among memory nodes.

Examples:

```text
derived_from
associated_with
contradicts
supports
same_subject
same_location
caused_by
interpreted_as
copied_from
```

Recommended fields:

```text
edge_id
from_memory_id
to_memory_id
relation_type
strength
provenance
```

The graph must permit contradiction.

---

## 5.6 `MemoryAnchor`

A memory anchor is the thing that physically/socially/environmentally carries a memory.

Supported conceptual anchor categories:

```text
world_item
corpse
location
structure
npc
archive
ecological_state
geological_state
spiritual_residue
```

Foundation should prioritize:

1. WorldItem / ItemInstance;
2. Corpse;
3. simple location anchor.

Other anchor types should have interfaces/data types but may remain unimplemented until their owning systems exist.

Recommended anchor fields:

```text
anchor_id
anchor_type
target_ref
memory_ids[]
durability
readability
accessibility
environmental_exposure
last_known_location
```

Destroying an anchor may remove or weaken access to a memory.

Destroying an anchor MUST NOT delete the canonical HistoricalEvent.

---

## 5.7 `KnowledgeRecord`

Recommended future-compatible fields:

```text
knowledge_id
observer_scope
claim_refs[]
source_memory_ids[]
confidence
verification_state
first_learned_time
last_reinforced_time
```

Possible verification states:

```text
rumor
unverified
corroborated
institutionalized
disputed
```

Do not implement political/social simulation here; this is just the data boundary for future world knowledge.

---

# 6. Memory classes and memory states

These are separate concepts.

## 6.1 Memory class

Recommended classes:

### Working / Trace Memory

Examples:

- fresh blood;
- footprints;
- scent;
- fresh damage;
- immediate battle traces.

Characteristics:

```text
high detail
very low stability
rapid decay
```

### Episodic Memory

Examples:

- corpse;
- abandoned camp;
- damaged equipment;
- personal journal;
- NPC recollection.

Characteristics:

```text
moderate/high detail
medium lifetime
environment-sensitive
```

### Persistent Memory

Examples:

- relic;
- inscription;
- major structure;
- archive;
- fossil;
- long-lived terrain/ecological effect.

Characteristics:

```text
variable detail
high stability
long lifetime
```

A memory may be consolidated/promoted; promotion is not based only on elapsed time.

---

## 6.2 Memory state

Required conceptual state machine:

```text
ACTIVE
  ↓
FADING
  ↓
FRAGMENTED
  ↓
DORMANT
  ↓
LOST
```

Possible reverse transition:

```text
DORMANT
  ↓ discovery
REACTIVATED / ACTIVE
```

Interpretation:

### `ACTIVE`
Accessible and sufficiently intact.

### `FADING`
Still accessible but detail/retention is degrading.

### `FRAGMENTED`
Only part of the semantic claims survive.

### `DORMANT`
No active observer/access path currently exists, but at least one durable anchor or recoverable trace remains.

### `LOST`
No usable world-memory representation remains.

`LOST` does **not** mean deleting the Causal Ledger event.

Codex may implement `REACTIVATED` as either a distinct transient state or transition metadata, according to existing state-machine conventions.

---

# 7. Reinforcement and consolidation

Repeated meaningful access can strengthen a memory.

However:

> repeated access must not automatically make a memory more truthful.

Reinforcement should consider:

```text
new independent observer
new independent physical evidence
copy into a new durable medium
archival action
cross-confirmation
institutional adoption
meaningful inspection
```

Weak reinforcement:

```text
same observer repeatedly clicking same object
same source copied repeatedly without independent evidence
passive proximity
```

Recommended rule:

```text
Reinforcement != visit_count
```

Use diminishing returns for repeated access from the same source/observer.

The foundation should expose a `ReinforcementContext` or equivalent that can later distinguish:

```text
EXPOSURE
INSPECTION
RECORDING
CORROBORATION
ARCHIVAL
INSTITUTIONALIZATION
```

Do not hard-code large gameplay bonuses in Phase 1.

---

# 8. Decay, fragmentation and distortion

These must be separate processes.

## 8.1 Decay

Reduces retention/accessibility/stability according to:

```text
time
medium durability
environmental exposure
isolation
anchor damage
```

Decay should be deterministic for a given state/time interval unless an injected RNG is explicitly part of a rule.

---

## 8.2 Fragmentation

Removes or weakens individual semantic claims rather than deleting an entire story at once.

Example initial memory:

```text
subject: Elias
location: Mine 7
depth: 2130m
companion: Mara
cause: Creature_17
outcome: Mara died
```

Later:

```text
subject: unknown
location: Mine 7
depth: unknown
companion: unknown
cause: unknown
outcome: death occurred
```

Later:

```text
location: Mine 7
semantic residue: danger
```

This allows myths/taboos to emerge from degraded factual memory.

Fragmentation MUST operate on claim data, not string truncation.

---

## 8.3 Distortion

Distortion creates altered interpretations or copied claims.

Rules:

- never mutate the Causal Ledger;
- never overwrite the only source memory without provenance;
- retain origin/provenance links;
- conflicting claims may coexist;
- use seeded/injected randomness;
- distortion probability may depend on missing context, unstable medium, interpretation, or repeated oral transmission.

Example:

```text
Truth:
Elias killed one creature.

Memory interpretation:
Five corpses were found near Elias' knife.

Belief:
"Elias killed five creatures."
```

The false belief may become highly reinforced.

---

## 8.4 Reconsolidation

When a memory is recalled and then rewritten into a new medium, create or update a derived memory with provenance.

Preferred model:

```text
Recall
  ↓
Interpret
  ↓
Derived Memory
  ↓
New Anchor
```

Avoid silently mutating the original source memory.

This preserves historical auditability.

---

# 9. Memory anchors and existing project integration

## 9.1 WorldItem / ItemInstance

Do not bloat every `ItemInstance` with a complete historical graph.

Preferred approach:

```text
ItemInstance
    stable instance_id
          │
          ▼
MemoryAnchorRef / History index
```

A historically irrelevant spoon should not carry expensive memory state.

Memory becomes attached only when:

- item participates in a significant event;
- item is explicitly recorded/inscribed;
- item becomes a relic candidate;
- item is used as an evidence anchor.

Possible item-relevant events:

```text
historical ownership transfer
dropped/lost in significant expedition
present at character death
unique repair/modification
used in notable encounter
recovered centuries later
```

WorldItem movement should update anchor location through an adapter/service, not through direct graph manipulation.

---

## 9.2 Corpse / Lifecycle

Character death is one of the strongest integration points.

Required conceptual flow:

```text
Health / Wounds / Bleeding / Combat
        ↓ existing gameplay resolution
Lifecycle decides death
        ↓
HistoricalEvent(character_death)
        ↓
CausalLedger
        ↓
MemoryEncoder
        ↓
Corpse anchor + item anchors + location trace
```

The Lifecycle component remains responsible for death behavior.

The memory system records the completed outcome.

The memory system must not decide whether a character dies.

A death event may reference causal events such as:

```text
major wound
severe bleeding
combat attack
environmental exposure
```

Only if those events were actually recorded.

Do not fabricate absent causal chains.

---

## 9.3 Wound & Bleeding

Phase 13 provides a useful first causal chain.

Potential event policy:

Do **not** record every bleeding tick.

Record significant transitions such as:

```text
major wound created
bleeding severity crosses historical threshold
wound stabilized
death caused/contributed by blood loss
```

Exact thresholds should be data-driven or policy-driven later.

Initial foundation tests can use explicit test events rather than changing gameplay balance.

---

## 9.4 Combat

Combat should not submit every hit to long-term history.

Potential significant events:

```text
unique creature kill
first encounter with species
boss/rare entity death
combat causing permanent injury
combat causing character death
destruction of historically significant object
```

Ordinary damage remains only gameplay state.

---

## 9.5 Inventory / Containers / Loot

Ordinary transfers should remain outside Causal Ledger.

Record only history-relevant transitions, for example:

```text
relic recovered
historically significant item changes owner
legacy cache opened
dead explorer inventory recovered
```

Loot generation itself is not automatically history.

---

## 9.6 Survival

Do not record hunger/thirst every tick.

Potential significant event later:

```text
near-fatal exposure
major adaptation milestone
environmental condition contributing to death
survival discovery tied to region
```

Foundation should expose an event API, not flood the ledger.

---

# 10. Significance policy

A new `HistorySignificancePolicy` or equivalent should decide which completed gameplay outcomes are worthy of canonical historical storage.

Do not distribute history thresholds through every gameplay script.

Preferred:

```text
Gameplay event
   ↓
history recorder / significance policy
   ↓ accepted?
HistoricalEvent
```

Possible categories:

```text
TRIVIAL        -> ignored
LOCAL_TRACE    -> memory only / short-lived trace
HISTORICAL     -> ledger + memory
LANDMARK       -> ledger + stronger initial anchors
```

The first implementation can support only `HISTORICAL` events with explicit calls; the policy interface should exist for future expansion.

---

# 11. Recording form: canonical event vs memory representation

## 11.1 Canonical event form

Must be:

```text
structured
semantic
ID-based
minimal
immutable
prose-free
```

Do not store:

```text
"Elias heroically fought until his final breath..."
```

inside `HistoricalEvent`.

Store:

```text
actor
action/event type
location
time
depth
objects
causes
outcomes
```

Narrative text belongs to a later presentation layer.

---

## 11.2 Memory representation form

Memory nodes store claim fragments plus quality metadata.

Example:

```json
{
  "memory_id": "mem_...",
  "class": "episodic",
  "state": "active",
  "claims": [
    {
      "claim_id": "claim_1",
      "subject_ref": "character_elias",
      "predicate": "died_at",
      "object_ref": "mine_7",
      "clarity": 0.92,
      "retention": 0.81,
      "confidence": 0.88,
      "source_event_ids": ["evt_..."]
    }
  ],
  "anchor_refs": [
    "anchor_corpse_...",
    "anchor_knife_..."
  ]
}
```

Do not treat these exact float values as gameplay constants.  
They demonstrate data shape only.

---

# 12. Recommended repository/work-directory structure

Codex must first inspect the actual repository and adapt these paths to existing conventions.

If the repository already uses a clear `scripts/`, `data/`, `tests/`, `docs/` split, prefer:

```text
res://
├── scripts/
│   ├── history/
│   │   ├── historical_event.gd
│   │   ├── causal_ledger.gd
│   │   ├── history_event_builder.gd
│   │   ├── history_significance_policy.gd
│   │   └── history_serializer.gd
│   │
│   ├── memory/
│   │   ├── memory_claim.gd
│   │   ├── memory_node.gd
│   │   ├── memory_edge.gd
│   │   ├── memory_anchor_ref.gd
│   │   ├── world_memory_graph.gd
│   │   ├── memory_encoder.gd
│   │   ├── memory_decay_service.gd
│   │   ├── memory_reinforcement_service.gd
│   │   ├── memory_fragmentation_service.gd
│   │   └── memory_reconsolidation_service.gd
│   │
│   └── knowledge/
│       ├── knowledge_record.gd
│       └── knowledge_registry.gd
│
├── data/
│   └── world_memory/
│       ├── memory_retention_profiles.json
│       └── memory_event_policies.json
│
├── tests/
│   ├── unit/
│   │   ├── history/
│   │   ├── memory/
│   │   └── knowledge/
│   └── integration/
│       └── world_memory/
│
└── docs/
    └── architecture/
        └── WORLD_MEMORY_FOUNDATION.md
```

If the project uses a different established naming scheme, map these conceptual boundaries into that scheme rather than creating parallel conventions.

---

# 13. Static data files

Recommended data-driven configuration:

## `memory_retention_profiles.json`

Defines properties of memory media/anchor categories.

Conceptual entries:

```text
fresh_blood
corpse
paper_record
metal_inscription
world_item_generic
relic
location_trace
ecological_trace
archive
spiritual_residue
```

Possible fields:

```text
id
base_stability
base_readability
base_decay_rate
fragmentation_bias
environment_sensitivity
```

These should be validated using the project's existing data-definition/registry pattern where appropriate.

Do not hard-code all memory media constants in services.

---

## `memory_event_policies.json`

Optional after audit.

Purpose:

- classify event types;
- initial memory class;
- whether physical anchors should be generated;
- default significance category.

Do not add this file if the current project's static-data conventions indicate a different better fit.

---

# 14. Existing files likely to require modification

Codex must identify the real files before editing.

Expected integration categories:

### Lifecycle / Death

Add a narrow post-resolution history notification after confirmed death.

### Corpse

Expose stable corpse identity / anchor target data if not already available.

Do not embed the whole memory graph in Corpse.

### WorldItem

Expose stable instance/location lifecycle events needed by `MemoryAnchor` adapters.

Do not make WorldItem responsible for memory decay.

### ItemInstance

Only add the minimum stable metadata/reference needed if no suitable stable ID/history lookup exists already.

Avoid adding large arrays of history records directly to every item.

### Combat / Wounds / Bleeding

Provide meaningful event hooks or result objects that history recording can consume.

Do not change combat or wound outcome semantics.

### GameClock

Provide world-time input to history/memory services.

The memory layer must not own simulation time.

### Data Registry

Only modify if retention/event-policy definitions use the existing definition-registry system.

### Documentation

Update architecture map, roadmap, changelog, and changed-files report according to repository convention.

---

# 15. New files: foundation minimum

The first implementation should remain small.

Minimum recommended production set:

```text
historical_event.gd
causal_ledger.gd

memory_claim.gd
memory_node.gd
memory_edge.gd
memory_anchor_ref.gd
world_memory_graph.gd
memory_encoder.gd

memory_decay_service.gd
memory_reinforcement_service.gd

history_serializer.gd
```

Optional/deferred:

```text
memory_fragmentation_service.gd
memory_reconsolidation_service.gd
knowledge_registry.gd
knowledge_record.gd
```

Whether these are foundation or next-phase files should be decided after repository audit and workload estimate.

---

# 16. Do not create a monolithic global singleton

Avoid:

```text
WorldMemoryManager.gd
```

containing:

```text
all events
all decay
all knowledge
all serialization
all anchors
all narrative
all queries
```

Prefer small services with explicit responsibility.

If an Autoload is required later, it should be a composition/root service exposing stable APIs, not contain all domain logic.

Possible future composition:

```text
WorldHistoryRuntime
    causal_ledger
    world_memory_graph
    encoder
    decay_service
    reinforcement_service
```

But do not introduce an Autoload unless it fits established project patterns.

---

# 17. Persistence strategy

The project may not yet have a complete Save/World Persistence foundation.

Therefore memory code should support:

```text
to_data()
from_data()
```

or repository-equivalent serializers from the first phase.

Requirements:

- stable schema version;
- no live Node references;
- stable entity/item/location IDs;
- deterministic round-trip;
- invalid data fails cleanly;
- failure does not leave partially loaded graph/ledger state.

Do not invent a full save-game architecture inside World Memory Foundation.

When a future Save/World Persistence phase arrives, it should own disk/world-slot lifecycle and call the memory serializers.

---

# 18. Long-term world evolution boundary

The memory system does **not** simulate ecology.

Future world simulation may produce events such as:

```text
corpse_decomposed
food_consumed_by_wildlife
item_moved_by_animal
structure_collapsed
plant_colony_expanded
species_migrated
biome_degraded
region_subsided
```

Those events can enter the same causal architecture if significant.

Recommended future relationship:

```text
World Evolution
      │
      ├── changes actual world state
      │
      └── emits significant historical events
                        ↓
                  Causal Ledger
                        ↓
                surviving evidence
                        ↓
                World Memory Graph
```

The memory system observes historical consequences.  
It must not own the ecological simulation itself.

---

# 19. Absolute depth vs ecological history

Future deep-world architecture should avoid conflating:

```text
absolute physical depth
historical ecological origin
current ecological state
species behavioral preference
```

Memory/event location records should therefore avoid a single overloaded `depth_zone` string.

At minimum, canonical location records should be extensible enough to later support:

```text
absolute_depth
region_id
ecological_region_id
world_epoch
```

Do not implement the full subsidence model in the first memory phase.

Preserve data extensibility.

---

# 20. Object/relic history

A future relic may accumulate history across multiple owners.

Preferred model:

```text
ItemInstance stable ID
      │
      ├── ownership event
      ├── combat event
      ├── repair event
      ├── death-site event
      ├── recovery event
      └── archival event
```

The item does not need to duplicate all events.

Query:

```text
CausalLedger.query_by_object(instance_id)
```

can reconstruct its canonical history.

The World Memory Graph can separately track which parts of that history remain discoverable.

This permits:

```text
object history longer than any single character life
```

without bloating item serialization.

---

# 21. Historical character lifecycle

A character chronicle should be **derived from canonical events**, not be the only copy of them.

Possible future `CharacterChronicleView`:

```text
query ledger by character ID
↓
select significant events
↓
build life chronology
↓
bind surviving memory/evidence
```

At death:

```text
finalize character active participation
```

but do not generate a globally-known biography.

Death should create evidence opportunities:

```text
corpse
equipment
journal if present
location traces
witness memories
```

The world learns only if those sources are discovered/interpreted/transmitted.

---

# 22. Narrative generation boundary

Do not make an LLM or free-text generator part of the canonical memory layer.

Recommended later pipeline:

```text
Structured Claims
      ↓
Narrative Interpreter
      ↓
Template / authored grammar / optional AI layer
      ↓
player-facing text
```

Canonical history and memory must remain understandable without generated prose.

Generated narrative must never invent facts and write them back into the Causal Ledger.

---

# 23. Phase implementation plan

Do not renumber the project's existing roadmap until Codex audits it.

Use an internal memory workstream naming scheme first.

## WM-0 — Repository Audit

Deliverables:

- current HEAD;
- clean/dirty workspace state;
- actual directory map;
- exact integration files;
- existing signal/service patterns;
- existing serialization patterns;
- existing IDs/entity identity patterns;
- test command baseline;
- proposed changed/new file list.

No production implementation before this audit.

---

## WM-1 — Causal History Foundation

Implement:

```text
HistoricalEvent
CausalLedger
validation
queries
serialization boundary
```

Tests:

- append;
- duplicate rejection;
- immutable access;
- causal references;
- actor/object/location query;
- failed append rollback;
- round-trip serialization.

No decay or distortion yet.

---

## WM-2 — Memory Graph Foundation

Implement:

```text
MemoryClaim
MemoryNode
MemoryEdge
MemoryAnchorRef
WorldMemoryGraph
MemoryEncoder
```

Support:

- event -> one/more memory nodes;
- claim-level storage;
- anchor links;
- contradictions allowed;
- no generated prose.

Tests:

- event encoding;
- anchor linking;
- graph queries;
- removing anchor does not delete ledger truth;
- multiple memories may derive from one event.

---

## WM-3 — Reinforcement / Decay / Dormancy

Implement:

```text
memory classes
memory states
reinforcement
decay
dormant/reactivation
```

Rules:

- same-source spam has diminishing/no reinforcement;
- independent anchor adds redundancy;
- time/environment can reduce accessibility;
- dormant durable memory can be reactivated.

Use deterministic injected time/RNG.

---

## WM-4 — Fragmentation / Reconsolidation

Implement:

```text
claim-level fragmentation
derived memories
provenance
distortion hooks
```

Must demonstrate:

```text
full memory
→ partial memory
→ semantic residue
```

without touching canonical history.

---

## WM-5 — First Gameplay Integration

Start with a very small set:

1. character death;
2. corpse as anchor;
3. significant carried item as anchor;
4. death location;
5. optional severe wound/bleeding cause chain.

Example integration test:

```text
character receives severe wound
↓
bleeding event recorded
↓
character dies
↓
death event references bleeding event
↓
corpse and knife become memory anchors
↓
corpse anchor is destroyed
↓
knife still preserves partial discoverable memory
↓
ledger retains complete canonical death event
```

Do not integrate every system at once.

---

## WM-6 — Knowledge / Interpretation

Later:

```text
observer discovery
knowledge records
corroboration
rumor
institutional archive
contradictory histories
```

This should occur only after the core memory model is stable.

---

# 24. Test strategy

Every new service requires unit tests.

At minimum:

## Causal Ledger

```text
valid append
duplicate IDs
invalid references
cause/effect query
actor query
object query
location query
immutability
rollback after failure
serialization
```

## Memory Graph

```text
event encoding
claim storage
edge relationships
contradiction coexistence
anchor binding
anchor removal
memory lookup
```

## Decay

```text
no elapsed time -> no decay
known elapsed time -> deterministic decay
stable medium > unstable medium
state transitions
dormancy
```

## Reinforcement

```text
new independent evidence strengthens memory
same source repeated has diminishing return
archival action stronger than passive exposure
reinforcement does not mutate ledger
```

## Fragmentation

```text
individual claims degrade
memory can retain semantic residue
fragmentation is deterministic under seeded RNG
source provenance remains intact
```

## Integration

At least:

```text
death -> ledger -> memory -> corpse anchor
death -> item anchor
anchor destruction -> memory accessibility changes
ledger remains intact
```

All existing project tests must remain green.

---

# 25. Performance constraints

Do not treat the memory graph as a per-frame simulation.

Rules:

- no `_process()` loop on every memory node;
- no Node per historical event;
- no Node per memory claim;
- use `RefCounted`, data objects, arrays/dictionaries/indexes according to project conventions;
- perform decay lazily or in batched world-time updates;
- index common queries by stable IDs;
- unloaded regions should not require active scene objects;
- future centuries of history must be compressible.

Recommended future pattern:

```text
last_updated_world_time
↓
on access / scheduled batch
↓
calculate elapsed interval
↓
apply compressed decay
```

instead of simulating every day individually.

---

# 26. Failure and rollback requirements

The existing project uses fail-closed patterns in foundational data systems; preserve that philosophy.

Examples:

### Ledger append failure

```text
no partial event inserted
no partial index entry
```

### Memory encode failure

```text
canonical event remains valid
memory graph unchanged or transaction rolled back
```

### Serialization load failure

```text
do not expose partially initialized ledger/graph as ready
```

### Invalid anchor

```text
reject or mark unresolved
do not fabricate target identity
```

### Missing cause

Allowed as unknown.

Never invent historical cause to satisfy validation.

---

# 27. Compatibility constraints

Codex MUST preserve:

- existing DataRegistry APIs;
- existing ItemInstance behavior;
- Inventory behavior;
- pickup/drop atomicity;
- Container transfer rollback;
- Loot behavior;
- Survival tick behavior;
- Consumable rollback;
- Zombie AI;
- Combat resolution;
- weapon/melee behavior;
- death/lifecycle behavior;
- Corpse behavior;
- wound/bleeding behavior.

Memory is an additive foundation.

If an integration requires changing an established public API, Codex must document:

```text
old API
new API
reason
affected files
migration
test coverage
```

before making the change.

---

# 28. Recommended first vertical slice

The first playable proof should be intentionally small.

Scenario:

```text
Character A owns Knife X.
Character A receives a severe bleeding wound.
Character A dies in Region R.
```

Canonical truth:

```text
Wound Event
↓
Bleeding Event
↓
Death Event
```

Memory/evidence:

```text
Corpse A
Knife X
Location R
```

Then simulate elapsed time:

```text
corpse memory degrades faster
knife memory survives longer
location trace becomes vague
```

Destroy corpse anchor:

```text
death truth remains
knife preserves partial evidence
```

Inspect Knife X later:

```text
memory reactivated
```

Expected result:

The system can answer internally:

```text
what happened?
what evidence remains?
what has been forgotten?
what can be rediscovered?
```

without generating a biography.

If this slice works, expand outward.

---

# 29. Example of the intended long-term causal trace

Future world history may contain:

```text
Explorer A carries food
↓
food lost at camp
↓
animal scavenges food
↓
animal moves backpack
↓
remaining organic matter decays
↓
soil nutrient state changes
↓
fungal growth expands
↓
later ecological region changes
```

Causal Ledger:

```text
preserves significant causal chain
```

World Memory Graph:

```text
fresh tracks disappear
corpse decomposes
backpack moves
metal tag survives
fungal pattern remains
```

Knowledge:

```text
later explorer may incorrectly infer
that the backpack owner died at the animal den
```

This is the intended architectural capability.

The first implementation does not need to simulate this entire chain.

---

# 30. Documentation requirements after implementation

Codex should update the repository's existing documentation convention.

At minimum report:

```text
baseline HEAD
new files
modified files
tests added
tests passed
architecture decisions
deferred scope
known limitations
```

Add/update architecture documentation explaining:

```text
Causal Ledger
World Memory Graph
Memory Anchors
dependency direction
persistence boundary
```

Update roadmap only after confirming where the memory workstream belongs relative to planned medical/world/persistence phases.

---

# 31. Acceptance criteria

The World Memory Foundation is accepted only if all of the following are true:

1. Canonical events are structured and immutable after ledger acceptance.
2. Memory data is separate from canonical history.
3. Memory can decay without modifying historical truth.
4. Memory can fragment at claim level.
5. Multiple anchors can support one memory.
6. Destroying one anchor does not necessarily erase a memory.
7. Destroying all accessible anchors can make a memory dormant/lost.
8. Dormant memory can be reactivated if a surviving anchor is rediscovered.
9. Reinforcement is based on meaningful/independent access, not raw click count.
10. Reinforcement does not imply increased truth accuracy.
11. Contradictory memories may coexist.
12. Every derived/distorted memory retains provenance.
13. Existing gameplay subsystems do not depend on memory internals.
14. Existing Phase 0–13 tests remain green.
15. New unit/integration tests pass.
16. No per-frame simulation is required for inactive memory.
17. Runtime Node references are not used as persistent historical identity.
18. Serialization can round-trip deterministic foundation data.
19. Failure paths do not expose partial/invalid state.
20. The implementation remains extensible for future world persistence and ecological evolution.

---

# 32. Final architectural rule

Codex should use the following as the governing principle when making implementation choices:

> **The Causal Ledger remembers what the world did.  
> The World Memory Graph remembers what traces survived.  
> The Knowledge layer remembers what someone believes.  
> The narrative layer only tells a story from those records.**

No later layer may rewrite an earlier layer's truth.

A character may be forgotten.

A relic may preserve only one fragment of that character.

A rumor may become stronger than the real history.

An ecosystem may preserve an ancient consequence after every name has disappeared.

The world is therefore not required to preserve stories forever.

It is required to preserve enough causal structure that surviving evidence can have a real historical reason.
