# Changelog

## Unreleased

### Added

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
- Added DataRegistry and the verification main scene while preserving engine settings
