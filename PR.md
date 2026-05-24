## Summary

Complete architectural rewrite from the original single-mode FastCast into two distinct modes with 350+ commits.

- **`FastCast.new()`** — Serial caster (main thread, simple API)
- **`FastCast.newParallel()`** — Parallel caster (Actor VMs, high performance)

---

## 0. Before (main branch — pre-PR state)

The `main` branch contained a monolithic single-mode FastCast with files under `src/FastCast2/`.

### Architecture (pre-PR)
- Single `FastCast.new()` returning one caster type — no serial/parallel split
- Per-cast RunService connections (one `Heartbeat`/`RenderStepped` per active cast)
- OOP-style `ActiveCast` (808 lines) with metatable methods (`__index`)
- `Trajectories` array (list of trajectory segments) on each cast
- `Behavior.MovementMethod` field for movement mode selection
- `xpcall`/`pcall` wrapping on all user callbacks
- Module-scoped variables (cross-instance corruption risk with multiple casters)
- `Signal.luau` utility class for event handling
- VM Dispatcher in `FastCastVMs/` with Actor-based workers
- ObjectCache (basic pooling, no Motor6D support)

### API (pre-PR)
- `FastCast.new()` — returned single caster type
- `caster:Fire(origin, direction, velocity, behavior)` — single fire method
- Events: `.RayHit`, `.RayPierced`, `.CanRayPierce`, `.LengthChanged`, `.CastTerminating`
- `SafeCall()` utility for error-handled callback invocation
- `PauseCast()` / `ResumeCast()`
- `SetBulkMoveEnabled(bool)`
- `BetterLengthChangedModule` / `CanRayPierceModule` pattern

### Source layout (pre-PR)
```
src/FastCast2/
├── init.luau              — Main module
├── ActiveCast.luau         — OOP cast class (808 lines)
├── BaseCast.luau           — Base caster (302 lines)
├── Configs.luau            — Debug logging flags
├── DefaultConfigs.luau     — Default behavior values
├── FastCastEnums.luau      — Enum values
├── ObjectCache.luau        — Basic part pooling
├── Signal.luau             — Event signal class (223 lines)
├── TypeDefinitions.luau    — Type definitions
└── FastCastVMs/
    ├── init.luau           — VM Dispatcher
    ├── ClientVM.client.luau
    └── ServerVM.server.luau
```

---

## 1. Architecture

### New modules (5 new source files)
- `BaseCastSerial.luau` — Serial-mode caster handler, owns ObjectCache/Motor6DCache, routes to `SerialSimulation`
- `BaseCastParallel.luau` — Parallel-mode caster handler (module-scoped state inside each Actor VM), routes to `ParallelSimulation`
- `SerialSimulation.luau` — SoA physics engine on main-thread RunService (Heartbeat/PreSimulation)
- `ParallelSimulation.luau` — SoA physics engine via `ConnectParallel` inside Actor VMs
- `Motor6DCache.luau` — Motor6D instance pooling for Transform movement mode (initial pool 128, growth rate 2x)

### Rewritten modules (3)
- `ActiveCast.luau` — OOP class (808 lines) → Cast data factory (149 lines, pure data, AoS exposed to users, SoA internally)
- `ObjectCache.luau` — Basic pooling → BulkMoveTo-based with auto-expand and Model template support
- `FastCastVMs/init.luau` — VM Dispatcher: template Actor with controller script, clones N workers, round-robin dispatch

### SoA (Structure of Arrays) pattern
- ~25 parallel arrays per simulation: `casts_TotalRunTime`, `casts_Trajectory`, `casts_RayInfo`, `casts_CFrame`, `casts_UserData`, `casts_CastType`, `casts_CastVariant`, `casts_MaxDistance`, `casts_ActiveMotor6Ds`, etc.
- Dense `casts_ID` array for O(n) per-frame iteration (no table traversal overhead)
- O(1) unregistration via swap-and-pop with `casts_ID_Index` reverse lookup
- Eliminates per-cast RunService connections entirely — one connection per simulation instance
- Queued event/visualization system: events are collected during simulation step, sorted by cast ID, and fired after physics

### ActiveCast refactor (OOP → pure data)
- `createCastData()` factory function replaces class instantiation
- `StateInfo.Trajectories` (array) → `Trajectory` (single object — saves memory, simplifies access)
- `StateInfo.UpdateConnection` removed — no per-cast RunService connections
- `UserData` attached from `behavior.UserData` when provided
- `FastCastEventsModule` reference stored in `RayInfo`
- `CosmeticBulletObject` created on the main thread (critical for parallel mode — instance writes restricted in actors)
- `AutoIgnoreContainer` support — automatically adds bullet container to filter list
- `CloneCastParams` — deep-clones RaycastParams with `table.unpack` on FilterDescendantsInstances
- `RespectCanCollide` now propagated in cloned params

### Instance-local state (fixes multi-caster corruption)
- `BaseCastSerial` moved from module-scoped variables to `self.*` properties
- Each caster instance now owns its own `Actives`, `ObjectCacheInstance`, `Motor6DCacheInstance`, `NextProjectileID`, `SerialSimulation`
- Prevents cross-instance corruption when multiple casters exist

### VM Dispatcher improvements
- Actor-based worker VMs with `Actor:SendMessage()` for cross-context communication
- Round-robin dispatch for load balancing (`_nextIndex % #Threads + 1`)
- `DispatchAll()` for broadcasting settings changes to all workers
- `Allocate()` for dynamic worker pool growth
- ObjectCache moved locally into each Actor VM (eliminates BindableFunction cross-thread calls)
- `Actor:SetAttribute("Tasks", ...)` for tracking active cast count per worker

---

## 2. New Features

### Serial mode (`FastCast.new()`)
- `caster:Init(movementMode, useObjectCache, template?, cacheSize?, cacheHolder?)`
- Events set directly: `caster.Hit = function(cast, result, velocity, cosmeticBullet) end`
- `__newindex` metamethod on `FastCastSerial` routes event assignments to `BaseCastSerial:_UpdateEvents()`
- TerminateCast support with proper cleanup (cosmetic bullet return, simulation unregister)
- Single RunService connection (Heartbeat on server, PreSimulation on client)

### Parallel mode (`FastCast.newParallel()`)
- `caster:Init(numWorkers, newParent, newName, ContainerParent, VMContainerName, VMname, movementMode, fastCastEventsModule?, useObjectCache, template?, cacheSize?, cacheHolder?)`
- Actor VM workers with `ConnectParallel` for truly parallel physics simulation
- `Output:BindableEvent` + Dispatcher callback for event routing back to main thread
- `SyncChanges:BindableEvent` for pushing trajectory/state modifications into Actor VMs
- `ActiveCastCleaner:BindableEvent` for cleanup orchestration
- `SetFastCastEventsModule(moduleScript)` — direct callback (no BindableEvent routing, better perf)
- `FastCastEventsModuleConfig` separate from `FastCastEventsConfig` for dual event channel support
- `task.synchronize()` barrier between simulation and event firing for safe cross-context communication

### Motor6D movement mode
- Alternative to BulkMoveTo using `Motor6D.Transform`
- Set via `caster:Init("Motor6D", ...)` or `caster:SetMovementMode("Motor6D", true)`
- `Motor6DCache` pools Motor6D instances (initial 128, grows 2x on exhaustion)
- Invisible anchored anchor part as Part0, cosmetic bullet as Part1
- Per-frame transform update: `motor6d.Transform = casts_CFrame[id]`
- Smooth visual interpolation via engine Motor6D physics
- Automatic Motor6D connection on cast registration, disconnection on unregistration
- Mode switching at runtime: converts all active casts between BulkMoveTo and Motor6D

### High-Fidelity sub-stepping
- **Default (1)** — single cast per frame (fastest)
- **Automatic (2)** — on hit, subdivides displacement into `rayDisplacement / HighFidelitySegmentSize` segments, recasts each to find precise hit point
- **Always (3)** — always subdivides every frame (most accurate)
- `CancelHighResCast` flag allows aborting in-progress high-res pass
- Cascading cast lag detection with warning
- Fixed: subRayDir now uses `timeIncrement` instead of `delta` (was causing missed hits in Automatic mode)
- Fixed: Always-mode sub-step delta calculation

### Debug visualization system
- ConeHandleAdornment for raycast segments
- BoxHandleAdornment for blockcast segments (not stretched by cast length)
- SphereHandleAdornment for spherecast segments
- Distinct hit vs. pierce visualization (different colors, sizes, transparency)
- Configurable via `VisualizeCastSettings`:
  - `Debug_SegmentColor`, `Debug_SegmentTransparency`, `Debug_SegmentSize`
  - `Debug_HitColor`, `Debug_HitTransparency`, `Debug_HitSize`
  - `Debug_RayPierceColor`, `Debug_RayPierceTransparency`, `Debug_RayPierceSize`
  - `Debug_RayLifetime`, `Debug_HitLifetime`
- Sub-cast visualization for high-fidelity segments
- Adornments parented to `workspace.Terrain.FastCastVisualizationObjects` with debris cleanup
- Queued visualization system: collected during simulation, fired after physics

### ObjectCache system
- Bullet part/model pooling with pre-allocation (default 500, expand by 50)
- `BulkMoveTo` for moving parts to/from far-away CFrame `(2^24, 2^24, 2^24)`
- Model support (uses PrimaryPart as root)
- `GetPart(CFrame?)`, `ReturnPart(Part)`, `ExpandCache(Amount)`, `SetExpandAmount(Amount)`
- `IsInUse(Object)` for introspection
- `PartToObject` mapping to prevent Model template orphaning
- Memory leak fix: stores full objects in free pool

### Event system
- **Serial mode**: Direct callbacks via `FastCastEvents` table passed to `BaseCastSerial.Init()` — fired from `SerialSimulation:FireQueuedEvents()`
- **Parallel mode**: Two channels:
  1. `FastCastEventsConfig` → `Output:BindableEvent:Fire()` → Dispatcher callback → user handler
  2. `FastCastEventsModuleConfig` → direct `require()` callbacks (no BindableEvent overhead)
- Events: `CastFire`, `Hit`, `Pierced`, `LengthChanged`, `CastTerminating`, `CanPierce`
- Event gating via `Use*` booleans in config tables
- Queued event system: events collected in `{ [castID]: { QueuedEventData[] } }`, sorted by cast ID, fired in order

---

## 3. API Changes

### Removed
| API | Replacement / Reason |
|-----|---------------------|
| `FastCastParallel.new()` | `FastCast2.newParallel()` |
| `behavior.MovementMethod` | Set via `caster:Init("Motor6D", ...)` or `caster:SetMovementMode()` |
| `SetBulkMoveEnabled()` | `SetMovementMode(mode, enabled)` |
| `PauseCast()` / `ResumeCast()` | Removed entirely (unused, cross-context complexity) |
| `UpdateConnection` on StateInfo | No per-cast RunService connections |
| `xpcall`/`pcall` from hot path | Direct calls for performance |
| `FastCastEventsModule` from Serial | Parallel only |
| `Trajectories` (array of segments) | `Trajectory` (single object) |
| `SafeCall()` | Removed |
| `BetterLengthChangedModule` | Replaced by FastCastEventsModule |
| `CanRayPierceModule` | Replaced by FastCastEventsModule |
| `ObjectCache.Type` field | Internal refactor |
| `self.self.*` patterns | Fixed to `self.*` |
| `TEST_LOGS`, `roblox.yml`, `mcp.json` | Cleanup |
| Legacy `ActiveCast.luau` (OOP) | Replaced by data factory |
| Legacy `BaseCast.luau` | Split into `BaseCastSerial` + `BaseCastParallel` |
| `Signal.luau` | Replaced by direct function calls |
| `Configs.luau` | Renamed to `Config.luau` |
| `Benchmarks/bench1.client.luau` | Removed |

### New methods on `FastCast`
| Method | Signature |
|--------|-----------|
| `new()` | `→ FastCastSerial caster` |
| `newParallel()` | `→ FastCastParallel caster` |
| `newBehavior()` | `→ FastCastBehavior` |
| `GetPositionCast(cast)` | `→ Vector3` |
| `GetVelocityCast(cast)` | `→ Vector3` (now computes actual velocity including acceleration) |
| `GetAccelerationCast(cast)` | `→ Vector3` |
| `SetPositionCast(cast, pos)` | `→ ()` |
| `SetVelocityCast(cast, vel)` | `→ ()` |
| `SetAccelerationCast(cast, accel)` | `→ ()` |
| `AddPositionCast(cast, pos)` | `→ ()` |
| `AddVelocityCast(cast, vel)` | `→ ()` |
| `AddAccelerationCast(cast, accel)` | `→ ()` |
| `TerminateCast(cast)` | `→ ()` |

### New methods on Caster
| Method | Mode | Purpose |
|--------|------|---------|
| `caster:SetMovementMode(mode, enabled)` | Both | Switch between BulkMoveTo/Motor6D |
| `caster:SetObjectCacheEnabled(enabled, ...)` | Both | Toggle part pooling |
| `caster:SetFastCastEventsModule(module)` | Parallel | Register events module |
| `caster:SyncChangesToCast(cast)` | Parallel | Push state to worker VM |

### Changed signatures
| Old | New |
|-----|-----|
| `caster:Init(true, true, ...)` | `caster:Init("BulkMoveTo", true, ...)` |
| `FastCast:GetVelocityCast` returns `InitialVelocity` | Returns actual current velocity with acceleration |
| `Behavior.MovementMethod = "Transform"` | `caster:Init("Motor6D", ...)` |
| `numWorkers > 1` assertion | `numWorkers > 1` (was `>= 1`, reverted to `> 1`) |
| `Spawn(function)` | `task.spawn(function)` |
| `.RayHit`, `.RayPierced`, `.CanRayPierce` events | `.Hit`, `.Pierced`, `.CanPierce` |
| `table.clear()` | `queuedEvents[castID] = nil` |
| Cast data with `__index` metatable | Plain table from `createCastData()` |
| `RaycastParams` reference | Deep clone via `CloneCastParams()` |

### Configuration changes
- `FastCastEventsConfig` now includes `UseCanPierce` (was missing in DefaultConfigs)
- `FastCastEventsModuleConfig` added for parallel module event gating
- `VisualizeCasts` and `VisualizeCastSettings` added to behavior
- `UserData` field for arbitrary data attachment

---

## 4. Bug Fixes

### Critical
- **HighFidelityBehavior.Automatic ray direction**: `local rayDir = totalDisplacement.Unit * segmentVelocity.Magnitude * delta` → `local rayDir = totalDisplacement` (was using wrong delta causing missed hits)
- **HighFidelityBehavior.Always sub-step**: Fixed sub-step delta calculation (was accumulating incorrectly)
- **Pierce-stuck bug**: Reset parametric trajectory after pierce so next frame continues from hit position
- **Double Destroy regression**: Stash no-op Destroy before removing metatable to prevent re-entry
- **CastTerminating not firing for serial**: Fixed TerminateCast serial branch isolation
- **Missing return after cascading cast warn**: Added return to prevent further execution
- **EndTime early-return**: Prevent double-termination when EndTime already set
- **TerminateCast nil-state guard**: Isolate Actives cleanup to serial branch
- **Cosmetic bullet creation in parallel**: Move to main thread (pre-dispatch) — instance writes restricted in Actor threads
- **ObjectCache cross-thread BindableFunction**: Moved ObjectCache locally into each Actor VM
- **ModuleScript typeof returning 'Instance'**: Added `typeof(module) == "ModuleScript" or (typeof(module) == "Instance" and module:IsA("ModuleScript"))` check

### Cast manipulation
- **GetAccelerationCast returning velocity**: Now returns `cast.StateInfo.Trajectory.Acceleration` correctly
- **AddPositionCast/AddVelocityCast/AddAccelerationCast**: Were calling nonexistent methods, now use `SetPositionCast`/etc
- **SetPositionCast missing**: Was not implemented, now added via `ModifyTransformation`
- **GetVelocityCast returning InitialVelocity**: Now computes velocity at current runtime using acceleration
- **Trajectory rebase in setters**: Before modifying Origin/InitialVelocity/Acceleration, forward-integrate trajectory to current TotalRuntime and set StartTime = TotalRuntime

### Cleanup & memory
- **Destroy referencing RayHit/RayPierced**: Changed to Hit/Pierced
- **Motor6DCache memory leak**: Destroy pooled Motor6D instances on Destroy
- **ObjectCache Model template orphaning**: Store full objects in free pool, add PartToObject mapping
- **SyncChanges nested merge**: Deep merge StateInfo/Trajectory to preserve nested properties
- **SerialSimulation ActivesRef**: `ActivesRef` → `self.ActivesRef` in SimulateCast
- **BaseCastParallel safe iteration**: Collect active list before iterating in Destroy
- **SyncChanges connection leak**: Disconnect SyncChanges event in Destroy
- **Zero-direction CFrame guard**: `if rayDir ~= Vector3.new() then CFrame.new(lastPoint, lastPoint + rayDir) else CFrame.new(lastPoint)`
- **DebrisAdd return after Destroy**: Add return statement
- **IsActivelyResimulating reset on early exit**: Reset flag when cast is nil

### Type system
- **Spherecast not working**: Fixed type errors in variant handling and radius extraction
- **Unnamed parameters in all callback function types**: Added parameter names
- **Incorrect union types on Caster signal fields**: Removed RBXScriptSignal/RBXScriptConnection
- **SphereCastRayInfo `@type` doc copying BlockCastRayInfo**: Fixed copy-paste error
- **OnCastFireFunction `@type` unnamed parameters**: Added names
- **GetVelocityCast signature**: Fixed return type
- **AddAccelerationCast signature**: Fixed parameter type
- **Lua-ModuleScript union typing**: `FastCastEventsModule` type exported
- **Type errors in ParallelSimulation**: Silenced with proper casts

### Visualization
- **DBG_SEGMENT_SUB_COLOR2 identical to DBG_SEGMENT_SUB_COLOR**: Distinguished
- **Blockcast visualization stretched**: No longer stretched by cast length
- **Complete visualization in ParallelSimulation**: Was missing, fully wired
- **Complete visualization in SerialSimulation**: Was missing, fully wired

### Misc
- **BulkMoveTo double-connection guard**: Fixed in BindBulkMoveTo
- **numWorkers assertion**: `> 1` (correct)
- **FastCastEventsModule nil guard**: Added guarding in ActiveCast
- **CanPierce logic**: Fixed pierce decision flow in both simulations
- **BaseCastSerial cross-instance corruption**: Made state instance-local
- **Acceleration validation**: Guard before kinematic read
- **RaycastParams deep copy**: `CloneCastParams` with `table.unpack`
- **DefaultConfigs missing UseCanPierce**: Added to FastCastEventsConfig
- **Fire Hit when max distance reached after pierce**: Fixed termination logic
- **Preserve StateInfo/RayInfo in SeriaSimulation TerminateCast**: Fixed cleanup order
- **init.luau redundant cloning in parallel fire methods**: Removed

---

## 5. Documentation

### New files
- `AGENTS.md` — Project overview, development commands, project structure, code style guidelines
- `docs/api-reference.md` — Full API reference with Init signatures, parameter tables, event docs, FastCastBehavior fields
- `skills/architecture.md` — Full architecture documentation (module layout, execution flow, SoA pattern, event system, data flow diagram)
- `PR.md` — This PR description document

### Updated files
- `README.md` — Corrected Init examples, added Rojo installation guide, simplified serial/parallel code examples, fixed FastCastEventsModule section, fixed `module.RayHit` → `module.Hit` in events example
- `docs/changelog.md` — Updated changelog from 0.0.1 to 0.1.0
- `docs/intro.md` — Updated project introduction
- `docs/cheatsheet.md` — Updated API reference with serial/parallel sections

### Doc comments
- Moonwave-compatible documentation comments throughout all source files:
  - `@class`, `@method`, `@param`, `@return`, `@within` annotations
  - Type definitions with `@type` and `@within` tags
  - Cross-references to TypeDefinitions
- `TypeDefinitions.luau` — All public types exported with documentation:
  - `FastCastBehavior`, `FastCastEvents`, `FastCastEventsConfig`, `FastCastEventsModuleConfig`
  - `CastStateInfo`, `CastTrajectory`, `CastRayInfo`, `BlockCastRayInfo`, `SphereCastRayInfo`
  - `ActiveCastData`, `ActiveBlockcastData`, `ActiveSpherecastData`
  - `BaseCastData`, `CasterSerial`, `CasterParallel`
  - All callback function types with named parameters
  - `VisualizeCastSettings` with all debug visualization properties

---

## 6. Chores & Infrastructure

### Project setup
- `default.project.json`, `sourcemap.json` — Rojo build configuration
- `wally.toml` — Wally package manager config (version bumped)
- `.gitignore` — Added `src/*.legacy.luau`, `opencode.json`, `.aider`, `.luaurc`, `sourcemap.json`

### Code cleanup
- Removed `SafeCall`, `material`, dead code
- Removed unused variables and type warnings
- Cleaned up comments, spacing, boilerplate
- `table.clear()` → `queuedEvents[castID] = nil`
- Signal → function where appropriate
- DOT → COLON for method calls (`TerminateCast`, etc.)
- Fixed AI-introduced nonsense edits
- Removed `AutomaticPerformance` flag
- Removed `mcp.json`, `roblox.yml`, `TEST_LOGS`

### Source files moved
- `src/FastCast2/` → `src/` (flattened for Rojo compatibility)

