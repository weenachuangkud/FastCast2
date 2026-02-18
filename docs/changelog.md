---
sidebar_position: 2
---
# Changelog

## [v0.0.1]
### Added
- Parallel scripting support
- Built-in ObjectCache for FastCast2
- FastCastVMs system
- ActiveBlockcast.luau module

### Changed
- Updated documentation


## [v0.0.2]
### Added
- Initial client-server projectile testing setup
- Basic networking structure for projectile replication

### Changed
- Internal refactoring for future ECS migration
- Improved module organization


## [v0.0.3]
### Added
- Testing Ground environment
- Performance testing scripts
- Packet-based networking (UnreliablePacket)

### Changed
- Disabled object pooling temporarily
- Disabled LengthChanged behavior for performance testing


## [v0.0.4]
### Added
- Additional benchmarking scenarios
- Weapon test environment (AWP testing ground)

### Changed
- Internal improvements to casting performance
- Improved test structure


## [v0.0.5]
### Added
- Dedicated benchmarking modules for FastCast2
- Stress testing support for high projectile counts

### Changed
- Refined testing environments
- Performance optimizations


## [v0.0.6]
### Added
- Caster component interaction functions
- ECS-based architecture for ActiveCast and ActiveBlockcast

### Changed
- Rewrote core modules into Entity-Component-System structure
- Renamed events:
  - RayHit → Hit
  - CanRayPierce → CanPierce
  - RayPierced → Pierced

### Removed
- BetterLengthChangedModule
- CanRayPierceModule

### Fixed
- Parallel script module loading issues
- FastCastEventsModule nil indexing bug
- Caster initialization order issues


## [v0.0.7]
### Added
- Initial UserData support for casts

### Changed
- Switched FastCast method calls to colon syntax
- Improved internal type definitions

### Fixed
- Caster:Destroy nil error
- Documentation comment inconsistencies
