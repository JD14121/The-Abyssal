# Project Milestones

Milestones are the GitHub delivery points for completed groups of Phases. Small
Phase work remains local until its milestone is complete. Each milestone gets a
Git commit, an annotated tag and a push of the main branch plus that tag.

## Milestone A — Combat Survival Slice (Complete)

**Scope:** Phase 0 through Phase 14.

The slice connects the Player, runtime Items and Inventory, Loot and Containers,
Survival needs, Creatures and Zombies, Combat, Player melee weapons, defeat and
Corpse lifecycle, Wounds and basic bleeding treatment.

Phase 14 adds a validated MedicalDefinition for `clean_bandage` and a
TreatmentService. A successful treatment targets one exact Wound ID, applies a
bleeding reduction, and consumes the exact bandage instance from Inventory.
Invalid targets and failed Wound mutations preserve the bandage.

This milestone completes a systemic combat and survival runtime slice. It does
not claim the game is a full playable sandbox: world simulation and population,
medical infection, UI, world generation and persistence are later milestones.

**Next:** Phase 15 — Infection and Disease Foundation.

## Future Milestones

- **Milestone B — Playable Survival Sandbox:** Noise and Zombie perception,
  population, a persistent world composition, buildings and loot placement,
  Inventory UI, and Equipment.
- **Milestone C — Persistent Survival Game:** versioned save/load, Player and
  world state persistence, and chunk state management.
- **Milestone D — Hardcore Survival Systems:** advanced injuries, infection,
  weather, temperature, fatigue, crafting and environmental systems.
