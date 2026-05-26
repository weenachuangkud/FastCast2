---
sidebar_position: 3
---

# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog (https://keepachangelog.com/en/1.0.0/)

---

## [0.1.0] — 2026-05-07

### Added
- **Serial Mode** (`FastCast.new()`) - Main thread projectile simulation, simpler API
- **Parallel Mode** (`FastCast.newParallel()`) - Worker VM based parallel simulation
- **Motor6D movement mode** - New movement method using Motor6D for better performance
  - Pass `"Motor6D"` as the movement mode to `caster:Init()`
- **SerialSimulation** - Single RunService with SoA pattern for Serial casts
- **ParallelSimulation** - Per-Actor SoA pattern for Parallel casts
- **Motor6DCache** - Object pooling for Motor6D instances

### Changed
NONE
 
### Fixed
- **HighFidelityBehavior = 2 bug** - Fixed subRayDir calculation using `delta` instead of `timeIncrement`

### Performance
- Serial: 1 global RunService handling all casts with SoA arrays
- Parallel: 1 RunService per Actor with SoA arrays within each

---

## [0.0.9] — 2026-03-03

### Changed
- Refactored ActiveCast.luau
- Merged ActiveBlockcast.luau and ActiveSpherecast.luau with ActiveCast.luau
- Updated TypeDef, Enums, FastCastVMs
- Removed FastCast:SafeCall(func, ...)
- Changed CFrame.new() to CFrame.new(origin) in ActiveCast.luau

### Fixed
- Spherecast not working
- Type errors
- Typo fixes
- No longer errors now when attempting to index with FastCastEvents with guarding
- Fix CanPierce logic and unnecessary things
- Fix unnamed parameters in all callback function types
- Fix incorrect union types on Caster signal fields (removed RBXScriptSignal, RBXScriptConnection)
- Fix GetVelocityCast and AddAccelerationCast signatures
- Fix SphereCastRayInfo `@type` doc copying BlockCastRayInfo
- Fix OnCastFireFunction `@type` unnamed parameters
- Remove stale RBXScriptSignal references from Caster `@type` doc
- Fixed GetAccelerationCast returning velocity instead of acceleration
- Fixed AddPositionCast, AddVelocityCast, AddAccelerationCast calling nonexistent methods
- Fixed missing return after cascading cast warn in SimulateCast and Stepped
- Fixed Destroy referencing RayHit/RayPierced instead of Hit/Pierced
- Fixed DBG_SEGMENT_SUB_COLOR2 being identical to DBG_SEGMENT_SUB_COLOR
- Fixed numWorkers assertion from > 1 to >= 1
- Fixed BulkMoveTo double-connection guard in BindBulkMoveTo

### Removed
- Removed unused SafeCall, material, and dead code

### Improved
- Merged ResumeCast into PauseCast(cast, value) for simplicity
- Added missing SetPositionCast method
- Updated all doc comments to use vaildcast type consistently
- Add guarding for SetFastCastEventsModule
- Cached CastFire from require FastCastEventsModule result in SetFastCastEventsModule
- Removed unused variables in ActiveCast.luau and BaseCast.luau

## [0.0.8] — 2026-02-21

### Added
- Spherecast feature — adds sphere-based casting for broader collision detection and hit testing.

### Changed
- Blockcast visualization no longer stretched by cast length.
- Cleaned up code and performed minor refactors for readability.
- Updated documentation comments for clarity.

### Fixed
- Type errors
- FastCast2 now uses copy table instead of shared table for .newBehavior()

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
