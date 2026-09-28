# Project

This repository contains a hardcore data-driven survival game built with Godot 4.x.

The project takes architectural inspiration from systemic survival games such as CDDA and Project Zomboid, but all final game content, implementation, balance, assets, world building, and gameplay systems should be original unless explicitly documented otherwise.

# Repository Layout

The repository root is:

D:\Codex Projects\codex game

The Godot project root is:

D:\Codex Projects\codex game\game

Godot runtime files belong under `game/`.

Development tools, documentation, references, source assets, and build outputs must remain outside the Godot project unless there is a clear runtime requirement.

# Technology

- Engine: Godot 4.x Stable
- Language: GDScript
- Gameplay Data: JSON
- Utility Tooling: Python 3
- Version Control: Git
- Repository Hosting: GitHub

# Architecture Principles

Keep the following layers separated:

1. Gameplay data
2. Simulation logic
3. Runtime entity state
4. Scene presentation
5. User interface
6. Persistence

Prefer composition over deep inheritance.

Prefer data-driven content where practical.

Do not create one gameplay script for every item or creature subtype when differences can be expressed as data.

Avoid large global manager classes.

Do not place gameplay-specific logic in generic core utilities.

# Data Rules

All gameplay IDs must use stable lowercase snake_case string identifiers.

Examples:

- kitchen_knife
- canned_beans
- zombie_basic
- loot_kitchen
- skill_first_aid

Never silently accept:

- duplicate IDs
- malformed JSON
- missing required fields
- unresolved references
- invalid data types

Errors should include enough information to identify the source file and invalid entry.

Do not hardcode gameplay content in GDScript when it belongs in JSON.

# Runtime Data Model

Static definitions and runtime instances must remain separate.

Example:

ItemDefinition:

- id
- name
- category
- mass
- material
- base damage

ItemInstance:

- instance_id
- definition_id
- current condition
- custom state

Do not store per-instance runtime state inside shared static definitions.

# Godot Project

The Godot project is under:

`game/`

Godot should not depend directly on:

- `reference/`
- `source_assets/`
- `builds/`
- repository-level Python tools

unless explicitly designed otherwise.

# Source Assets

Original editable asset files belong under:

`source_assets/`

Examples:

- .aseprite
- .blend
- .psd
- .kra
- original audio projects

Exported runtime assets belong under:

`game/assets/`

# Reference Material

Third-party source repositories and research material belong under:

`reference/`

They must not become accidental runtime dependencies.

Do not copy third-party content into production game data without explicit review of licensing and project requirements.

# Coding Rules

Use typed GDScript where practical.

Prefer small focused scripts and components.

Avoid unnecessary inheritance hierarchies.

Avoid circular dependencies.

Avoid hidden side effects.

Do not use magic strings when a stable identifier or constant should exist.

Public APIs should have clear naming and responsibilities.

Do not introduce a new global singleton without a clear architectural justification.

# Codex Workflow

Before implementing a significant feature:

1. Read this AGENTS.md.
2. Read relevant documentation under `docs/`.
3. Inspect the current implementation.
4. Identify affected systems and files.
5. Explain the proposed implementation.
6. Implement the smallest working change.
7. Run relevant validation and tests.
8. Report modified files.
9. Report validation results.
10. Report remaining risks or technical debt.

Do not make large unrelated changes.

Do not refactor working architecture without explaining why.

Do not silently fix unrelated code.

Do not introduce new dependencies without justification.

# Validation

Any new gameplay data type should eventually have validation.

Cross-references between data entries must be validated.

Examples:

- recipe -> item
- loot group -> item
- creature -> loot group
- profession -> item
- building -> loot group

Validation failures must be visible and actionable.

# Current Scope

The current project is in early foundation development.

Prioritize:

- repository structure
- documentation
- data loading
- data validation
- maintainable architecture
- small testable increments

Do not implement the following unless explicitly requested:

- multiplayer
- vehicles
- NPC society simulation
- large-scale procedural world generation
- electricity grid
- farming
- complex fire simulation
- Steam Workshop integration
- large third-party frameworks

# General Rule

When uncertain, choose the smallest implementation that establishes a clean foundation for future expansion.
