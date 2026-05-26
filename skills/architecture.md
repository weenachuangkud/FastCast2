# FastCast2 Architecture

## Overview

FastCast2 is a Roblox projectile library in Luau that simulates projectile physics using **workspace raycasting** (not Roblox physics). It supports **raycast, blockcast, and spherecast** casting types, each following the same projectile simulation lifecycle.

The library provides two execution modes:

| Mode | Execution | Threading | Caster Factory | Simulation | BaseCast |
|------|-----------|-----------|----------------|------------|----------|
| **Serial** (`FastCast.new()`) | Main thread | Single RunService connection | `FastCastSerial` | `SerialSimulation` | `BaseCastSerial` |
| **Parallel** (`FastCast.newParallel()`) | Actor VMs | One VM per worker, round-robin dispatch | `FastCastParallel` | `ParallelSimulation` | `BaseCastParallel` |

---

## Module Layout (`src/`)

| File | Role |
|------|------|
| `init.luau` | Entry point. Exports `FastCast` static methods + `FastCastSerial` / `FastCastParallel` caster constructors. |
| `BaseCastSerial.luau` | Serial-mode caster handler. Owns `ObjectCache`, `Motor6DCache`, `SerialSimulation`. Routes `Raycast/Blockcast/Spherecast` calls to simulation. |
| `BaseCastParallel.luau` | Parallel-mode caster handler. Same responsibility but lives inside each Actor VM (module-scoped state). |
| `SerialSimulation.luau` | SoA physics engine (serial). Connected to RunService on main thread. |
| `ParallelSimulation.luau` | SoA physics engine (parallel). Connected via `ConnectParallel` inside Actor VM. |
| `ActiveCast.luau` | Cast data factory. Creates the cast data table used by both modes. |
| `ObjectCache.luau` | Cosmetic bullet part pooling (bulk-move based). |
| `Motor6DCache.luau` | Motor6D pooling for Transform movement mode. |
| `TypeDefinitions.luau` | All Luau type exports. |
| `FastCastEnums.luau` | Enums: `HighFidelityBehavior` (Default/Automatic/Always), `CastType` (Raycast/Blockcast/Spherecast). |
| `Config.luau` | Debug logging toggles. |
| `DefaultConfigs.luau` | Default `FastCastBehavior` values. |
| `FastCastVMs/init.luau` | VM Dispatcher — creates/manages Actor VMs, round-robins fire requests. |
| `FastCastVMs/ClientVM.client.luau` | Client-side Actor script running inside each VM. |
| `FastCastVMs/ServerVM.server.luau` | Server-side Actor script running inside each VM. |

---

## Execution Flow

### Initialization

```
FastCast.new() or FastCast.newParallel()
  └─> Returns FastCastSerial / FastCastParallel metatable

caster:Init(...)
  └─> Serial: creates BaseCastSerial → SerialSimulation → Start() (RunService.Heartbeat/PreSimulation)
  └─> Parallel: creates VM Dispatcher → spawns Actor VMs → each VM creates BaseCastParallel → ParallelSimulation → Start() (ConnectParallel)
```

### Firing a Cast

```
caster:RaycastFire(origin, direction, velocity, behavior)
    OR
caster:BlockcastFire(origin, size, direction, velocity, behavior)
    OR
caster:SpherecastFire(origin, radius, direction, velocity, behavior)
  └─> Serial: BaseCastSerial creates ActiveCast data → SerialSimulation.Register() → fires CastFire event
  └─> Parallel: Dispatcher:Dispatch() → round-robins to next Actor VM → BaseCastParallel creates ActiveCast data → ParallelSimulation.Register() → fires CastFire event
```

### Per-Frame Simulation

Each frame the simulation engine:

1. **Iterates all registered cast IDs** stored in a dense `casts_ID` array (fast iteration).
2. **Computes position** at current runtime using kinematic equation: `P(t) = origin + velocity*t + 0.5*acceleration*t²`
3. **Performs a workspace cast** (Raycast/Blockcast/Spherecast) from the last position toward the current position.
4. **Handles hits** — if a part is hit:
   - Checks `CanPierce` callback
   - If not piercing: queues `Hit` + `CastTerminating` events (with optional High-Fidelity sub-stepping)
   - If piercing: queues `Pierced` event, continues simulation
5. **Checks MaxDistance** — terminates if exceeded.
6. **Queues events** (`LengthChanged`, `Hit`, `Pierced`, `CastTerminating`) for deferred firing.
7. **Updates cosmetic bullet position** via `BulkMoveTo` or `Motor6D.Transform`.
8. **Fires queued events** sorted by cast ID.

---

## SoA (Structure of Arrays) Pattern

Both `SerialSimulation` and `ParallelSimulation` use the SoA pattern for cache-efficient per-frame iteration:

```lua
local casts_TotalRunTime = {} :: { [number]: number }
local casts_Trajectory = {} :: { [number]: CastTrajectory }
local casts_RayInfo = {} :: { [number]: CastRayInfo }
-- ... ~20 SoA arrays total
local casts_ID = {} :: { number }           -- dense active-ID list
local casts_ID_Index = {} :: { [number]: number }  -- reverse lookup
```

- **Registration**: Cast data is split across arrays by `cast.ID`.
- **Iteration**: The dense `casts_ID` list is iterated each frame with a simple numeric `for` loop.
- **Unregistration**: O(1) removal via swap-and-pop: the last ID replaces the removed ID's slot.

---

## High-Fidelity Sub-Stepping

Three modes controlled by `HighFidelityBehavior`:

| Mode | Behavior |
|------|----------|
| **Default (1)** | Single cast per frame. Fastest, lowest accuracy. |
| **Automatic (2)** | Upon hit, subdivides the frame's displacement into `displacement / HighFidelitySegmentSize` segments and recasts each. Finds the precise hit point. |
| **Always (3)** | Always subdivides every frame's cast. Most accurate, most expensive. |

---

## Cast Customization

### FastCastBehavior

Configured via `FastCast.newBehavior()` then populated:

| Field | Type | Purpose |
|-------|------|---------|
| `RaycastParams` | `RaycastParams?` | Filter rules |
| `MaxDistance` | `number` | Max range before auto-termination |
| `Acceleration` | `Vector3` | Constant acceleration applied each frame |
| `HighFidelityBehavior` | `number` | Default / Automatic / Always |
| `HighFidelitySegmentSize` | `number` | Segment size for sub-stepping |
| `CosmeticBulletTemplate` | `BasePart?` | Visual bullet part |
| `CosmeticBulletContainer` | `Instance?` | Parent for non-cached bullet instances |
| `AutoIgnoreContainer` | `boolean` | Auto-adds bullet container to filter list |
| `FastCastEventsConfig` | table | Enables/disables built-in event callbacks |
| `FastCastEventsModuleConfig` | table | Enables/disables module-script event callbacks |
| `VisualizeCasts` | `boolean` | Debug visualization |
| `VisualizeCastSettings` | table | Visualization colors/sizes |
| `UserData` | `any` | Arbitrary user data attached to the cast |

---

## Event System

Two event channels exist in **parallel mode**; serial mode uses direct callbacks:

1. **FastCastEvents** (built-in) — configured via `FastCastEventsConfig`:
   - `CastFire`, `Hit`, `Pierced`, `LengthChanged`, `CastTerminating`, `CanPierce`

2. **FastCastEventsModule** (user-supplied ModuleScript) — configured via `FastCastEventsModuleConfig`:
   - Same event names, resolved via `require()`. Only available in parallel mode.

### Parallel Event Routing

```
BaseCastParallel
  ├─> Output:BindableEvent:Fire("Hit", cast, ...)  → Dispatcher callback → user event handler
  └─> CastFireFunc functions (from module) → direct call
```

### Serial Event Routing

```
BaseCastSerial
  └─> user-provided events table → direct callbacks during FireQueuedEvents
```

---

## Caching Systems

### ObjectCache (`ObjectCache.luau`)

- Pools cosmetic bullet parts/models for reuse.
- Uses `BulkMoveTo` to move parts to/from a far-away CFrame.
- Pre-allocates on init, auto-expands by 50 when exhausted.

### Motor6DCache (`Motor6DCache.luau`)

- Pools `Motor6D` instances for Transform movement mode.
- Connects cosmetic parts to an invisible anchored anchor part via Motor6Ds.
- Movement is applied by setting `Motor6D.Transform` each frame.

---

## Parallel Architecture (`FastCastVMs/`)

### VM Dispatcher (`FastCastVMs/init.luau`)

- Creates a template `Actor` with a `ClientVM` or `ServerVM` script inside.
- Clones the actor `N` times into a container folder.
- `Dispatch()` sends a message to the next actor in round-robin order.
- `DispatchAll()` sends to every actor (for settings changes).

### Actor Scripts (`ClientVM.client.luau`, `ServerVM.server.luau`)

- Receive `"Init"` message → create `BaseCastParallel`.
- Receive `"Raycast"` / `"Blockcast"` / `"Spherecast"` messages → call corresponding `BaseCastParallel` method.
- Receive `"BindObjectCache"` / `"SetMovementMode"` / `"SetFastCastEventsModule"` → update shared state.
- Receive `"Destroy"` → cleanup.

### Data Flow

```
Script requiring FastCast2
  ├─> init.luau (entry)
  │    ├─> FastCastSerial (metatable for serial casters)
  │    └─> FastCastParallel (metatable for parallel casters)
  │
  ├─> FastCastVMs/init.luau (Dispatcher)
  │    └─> Spawns N Actor VMs
  │         ├─> ClientVM / ServerVM (Actor script)
  │         │    └─> BaseCastParallel (inside VM)
  │         │         ├─> ParallelSimulation (SoA engine)
  │         │         ├─> ActiveCast (cast data factory)
  │         │         ├─> ObjectCache (bullet pooling)
  │         │         └─> Motor6DCache (Motor6D pooling)
  │         └─> ... repeat for N workers
  │
  └─> BaseCastSerial (used for serial casters)
       ├─> SerialSimulation (SoA engine)
       ├─> ActiveCast (cast data factory)
       ├─> ObjectCache (bullet pooling)
       └─> Motor6DCache (Motor6D pooling)
```
