# Coding Style

## Language

Primary runtime language:

GDScript

Utility tooling:

Python 3

## GDScript

Prefer typed GDScript where practical.

Use clear descriptive names.

Prefer:

player_movement.gd
data_registry.gd
item_definition.gd

Avoid:

manager2.gd
new_script.gd
temp.gd

## Responsibilities

Each script should have a focused responsibility.

Avoid giant classes that combine:

- data loading
- UI
- save logic
- gameplay simulation
- input handling

## Composition

Prefer reusable components over deep inheritance.

## Errors

Invalid data should fail loudly during development.

Do not silently ignore malformed gameplay content.

## Comments

Comments should explain:

- architectural intent
- non-obvious constraints
- unusual algorithmic decisions

Do not comment obvious code line by line.

## Refactoring

Do not refactor unrelated systems while implementing a feature.

Large refactors require an explicit reason and validation plan.
