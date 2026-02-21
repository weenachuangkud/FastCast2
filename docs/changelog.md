# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog (https://keepachangelog.com/en/1.0.0/)
and this project adheres to Semantic Versioning (https://semver.org/).

---

## [0.0.8] — 2026-02-22
### Added
- Spherecast feature — adds sphere-based casting for broader collision detection and hits testing.

### Changed
- Blockcast visualization no longer stretched by cast length.
- Cleaned up code and performed minor refactors for readability.
- Updated documentation comments for clarity.

## [0.0.7] - 2026-02-11

### Added
- Support for initial `UserData` on cast behaviors (`behavior.UserData`).
- Additional Caster interface methods to mirror ActiveCast/ActiveBlockcast functionality.

### Changed
- Refactored core architecture into an Entity-Component-System (ECS) structure.
- Updated FastCast method calls to use object-style syntax (`FastCast:method()`).
- Renamed events for clarity:
  - `RayHit` → `Hit`
  - `CanRayPierce` → `CanPierce`
  - `RayPierced` → `Pierced`
- Improved and corrected type definitions.
- Updated documentation comments for clarity and accuracy.

### Removed
- Removed `BetterLengthChangedModule`.
- Removed `CanRayPierceModule` (functionality replaced by FastCastEventsModule).

### Fixed
- Fixed crash in `Caster:Destroy()` when indexing nil components.
- Fixed module loading issues when required in parallel threads.
- Added safeguards to prevent indexing nil `FastCastEventsModule`.
- Added proper initialization checks to prevent premature Caster method usage.

---

## [0.0.6] - 2026-02-08

### Changed
- Internal structural improvements and refactoring for stability.
- Documentation refinements and cleanup.

### Fixed
- Various minor internal consistency fixes.

---

## [0.0.5] - 2026-01-31

### Added
- Introduced FastCast2 testing ground.
- Added benchmarking tools.
- Added AWPTestGround for projectile behavior testing.

---

## [0.0.3] - 2026-01-03

### Added
- Introduced testing framework components.
- Added client-server projectile simulation.
- Added performance testing scenarios.
- Added unreliable packet networking support.

---

## [0.0.1] - 2025-11-23

### Added
- Initial release of FastCast2.
- Core casting and blockcasting functionality.
- Basic project structure.
- Initial Roblox Studio test project.