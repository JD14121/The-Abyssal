# Milestone B — Playable Survival Sandbox

## Demo target

Build one deterministic, top-down, small-town survival demo that can be played
from a fresh launch: explore buildings, search containers, manage food/water,
avoid or fight Zombies, equip melee/ranged weapons, treat injuries, and reach a
safe extraction point. All game content and placeholder visuals are original.

## Phase acceptance map

- [x] 15 Infection progression, health consequence, and wound-targeted antibiotic treatment
- [x] 16 Injury severity, pain, fracture state, recovery, and movement consequence
- [x] 17 World-local Noise events with distance falloff and Zombie hearing
- [x] 18 Vision cone/line of sight, target memory, investigation and search behaviors
- [x] 19 World-owned population cap and seeded spawn sites
- [x] 20 Distance-based full, simplified, and dormant Zombie simulation tiers
- [x] 21 World ownership and stable cell/chunk coordinate APIs
- [x] 22 Data-authored rooms, furniture, doors, windows and containers
- [x] 23 Room/furniture loot-profile placement with checked references
- [x] 24 Seeded small-map placement, loot and population within fixed bounds
- [x] 25 Inventory, Container transfer, needs, wounds, equipment and treatment HUD
- [x] 26 Equipment slots reference exact inventory-owned ItemInstances
- [x] 27 Facing-based melee arc, weapon reach, stagger, cooldown, and attack noise
- [x] 28 Ranged weapon, individual ammunition, timed reload, projectiles and gunshot Noise
- [x] Demo launch scene assembles all systems and exposes an understandable control guide
- [x] Full Godot/Python validation, headless launch check, controls guide and milestone docs

## Delivery boundaries

Systems stay composed at the world/entity level. World simulation services are
owned by the DemoWorld scene rather than Autoloads. Initial world generation is
limited to a small bounded town; streaming and large-scale simulation remain
outside this milestone. Placeholder visuals use Godot drawing and shapes; no
third-party assets are required for the demo.
