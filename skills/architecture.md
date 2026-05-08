# FastCast2 Architecture

## Overview

FastCast2 is a high-performance raycast library for Roblox with two execution modes:
- **Parallel**: Multi-threaded via Actor VMs, using SoA (Structure of Arrays) pattern
- **Serial**: Single-threaded with SoA pattern (simpler, lower performance)

## Module Structure

```
FastCast2/
├── init.luau                    # Entry point, creates casters
├── BaseCast.luau                # Parallel mode cast handler
├── BaseCastSerial.luau          # Serial mode cast handler
├── ParallelSimulation.luau      # Parallel SoA simulation (one per Actor)
├── SerialSimulation.luau       # Serial SoA simulation (single instance)
├── ActiveCast.luau              # Cast data container (AoS pattern)
├── ActiveCastSerial.luau       # Serial cast data
├── Motor6DPool.luau            # Motor6D object pooling
├── ObjectCache.luau             # Cosmetic bullet object pooling
├── Signal.luau                  # Event signal system
├── FastCastEnums.luau          # Enum definitions
├── TypeDefinitions.luau        # TypeScript-style type definitions
├── Configs.luau                 # Configuration
├── DefaultConfigs.luau         # Default behavior config
└── FastCastVMs/
    ├── init.luau               # Dispatcher (manages Actors)
    ├── ServerVM.server.luau    # Server Actor script
    └── ClientVM.client.luau    # Client Actor script
```

## Execution Modes

### Parallel Mode (`FastCast.newParallel()`)

```
┌─────────────────────────────────────────────────────────────┐
│                     FastCastParallel                        │
│                    (init.luau)                              │
│                         │                                   │
│          ┌──────────────┴──────────────┐                    │
│          │        Dispatcher           │                    │
│          │     (FastCastVMs)           │                    │
│          │                             │                    │
│          ▼                             ▼                    │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│   │  Actor  │    │  Actor  │    │  Actor  │  ...           │
│   │ (VM #1) │    │ (VM #2) │    │ (VM #3) │                │
│   │         │    │         │    │         │                │
│   │BaseCast │    │BaseCast │    │BaseCast │                │
│   │    │    │    │    │    │    │    │    │                │
│   │    ▼    │    │    ▼    │    │    ▼    │                │
│   │Parallel │    │Parallel │    │Parallel │                │
│   │ Sim     │    │ Sim     │    │ Sim     │                │
│   │ (SoA)   │    │ (SoA)   │    │ (SoA)   │                │
│   └─────────┘    └─────────┘    └─────────┘                │
└─────────────────────────────────────────────────────────────┘
```

**How Parallel Mode Works:**

1. **Dispatcher** (`FastCastVMs/init.luau`) creates N Actor VMs
2. Each **Actor** runs its own **BaseCast + ParallelSimulation**
3. When `RaycastFire()` is called:
   - Dispatcher selects Actor with lowest `Tasks` attribute (load balancing)
   - Sends `Raycast` message to that Actor
4. Each **ParallelSimulation** instance:
   - Uses `PreRender:ConnectParallel` (client) or `Heartbeat` (server)
   - Stores casts in SoA arrays (one set per Actor)
   - Runs parallel physics calculations
   - Uses **event queue** for cross-thread communication

### Serial Mode (`FastCast.new()`)

```
┌─────────────────────────────────────────────────────────────┐
│                     FastCastSerial                         │
│                    (init.luau)                              │
│                         │                                   │
│                         ▼                                   │
│                   BaseCastSerial                           │
│                         │                                   │
│                         ▼                                   │
│                SerialSimulation                           │
│                 (single instance)                         │
│                    (SoA arrays)                            │
└─────────────────────────────────────────────────────────────┘
```

**How Serial Mode Works:**

1. Single **BaseCastSerial** handles all casts
2. **SerialSimulation** runs on `Heartbeat` (single thread)
3. All casts stored in single SoA array set
4. Event queue dispatches callbacks after simulation

## SoA (Structure of Arrays) Pattern

Instead of storing casts as individual objects:
```lua
-- Bad: Array of Structures (AoS)
casts = { {id=1, origin=..., velocity=...}, {id=2, origin=..., velocity=...} }
```

FastCast2 uses Structure of Arrays:
```lua
-- Good: Structure of Arrays (SoA)
castIDs = {1, 2, 3, ...}
castOrigin = {Vector3, Vector3, Vector3, ...}
castVelocity = {Vector3, Vector3, Vector3, ...}
castAcceleration = {Vector3, Vector3, Vector3, ...}
```

**Benefits:**
- Better cache locality (all velocities adjacent in memory)
- Single iteration updates all casts
- Reduced heap allocations

## Threading Model

### Parallel Mode Threading

Each Actor VM runs in **separate Lua environment** with its own:

```
┌─────────────────────────────────────────────────────────┐
│                   Actor (per VM)                        │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │         ParallelSimulation                      │   │
│  │                                                 │   │
│  │  RunService (PreRender:ConnectParallel)        │   │
│  │    │                                            │   │
│  │    ├── Parallel math/raycast calculations      │   │
│  │    │   (task.defer/disconnect allowed)          │   │
│  │    │                                            │   │
│  │    └── task.synchronize()                       │   │
│  │           │                                    │   │
│  │           ▼                                    │   │
│  │  ┌──────────────────────────────────────┐     │   │
│  │  │     BulkMoveTo / Motor6D updates      │     │   │
│  │  │   (task.sync / BindableEvent fire)    │     │   │
│  │  └──────────────────────────────────────┘     │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Key Points:**

1. **`task.synchronize()`** - Called after parallel calculations
   - Forces all parallel tasks to complete
   - Required before modifying shared state

2. **`task.defer()` / disconnect** - Allowed in parallel phase
   - Used for cleanup operations

3. **`task.sync()` / BindableEvent** - Used for sync phase
   - Queues callbacks to run after synchronization
   - Events fire on main thread

### Event Queue System

Both simulations use an event queue to batch callbacks:

```lua
local QueuedEvents = {}

local function QueueFire(caster, eventName, ...)
    if caster and caster.Output then
        caster.Output:Fire(eventName, ...)
    end
end

-- In simulation loop (parallel or serial):
QueueFire(caster, "LengthChanged", cast, pos, dir, displacement, vel, bullet)
QueueFire(caster, "Hit", cast, result, vel, bullet)

-- After simulation, dispatch all at once:
for _, event in QueuedEvents do
    event.Callback(unpack(event.Args))
end
table.clear(QueuedEvents)
```

## Module Descriptions

### `init.luau` - Entry Point
- Creates `FastCast` table with two modes
- `FastCast.new()` - Returns Serial caster
- `FastCast.newParallel()` - Returns Parallel caster
- Handles Signal creation (LengthChanged, Hit, Pierced, etc.)

### `BaseCast.luau` - Parallel Cast Handler
- Runs inside each Actor VM
- Handles Raycast/Blockcast/Spherecast methods
- Manages BulkMoveTo connection (`PreRender:ConnectParallel`)
- Uses `ParallelSimulation.Register()` to add casts
- Syncs changes via `BindableEvent`

### `BaseCastSerial.luau` - Serial Cast Handler
- Single-threaded cast handler
- Registers casts with `SerialSimulation`
- Simpler, no Actor overhead

### `ParallelSimulation.luau` - Parallel Physics Engine
- **One instance per Actor VM**
- Auto-starts with `PreRender:ConnectParallel` (client) or `Heartbeat` (server)
- SoA arrays for all cast data
- Motor6D/BulkMoveTo handled in sync phase
- Event queue for cross-thread communication

### `SerialSimulation.luau` - Serial Physics Engine
- **Single global instance**
- Runs on `Heartbeat`
- SoA arrays (same structure as ParallelSimulation)
- Simpler threading model

### `ActiveCast.luau` - Cast Data Container
- AoS (Array of Structures) for cast metadata
- Contains:
  - `StateInfo`: trajectory, timing, high-fidelity settings
  - `RayInfo`: raycast params, world root, max distance
  - `UserData`: user-defined data

### `Motor6DPool.luau` - Transform Mode Support
- Object pool for Motor6D instances
- Efficient for moving cosmetic bullets via `Transform` property
- Grows dynamically (2x growth rate)
- Used when `MovementMethod == "Transform"`

### `ObjectCache.luau` - Cosmetic Bullet Pooling
- Pool of reusable cosmetic bullet parts
- Reduces Clone() overhead
- `GetPart(cframe)` and `ReturnPart(part)` interface

### `Signal.luau` - Event System
- Custom signal implementation
- Supports Connect, Once, Wait, Fire
- Uses thread pooling for performance
- Threaded signal firing via `task.spawn`

### `FastCastVMs/init.luau` - Dispatcher
- Manages Actor VM pool
- Load balancing via `Tasks` attribute
- `Dispatch()` - Sends to least-loaded Actor
- `DispatchAll()` - Broadcasts to all Actors

### `FastCastVMs/ServerVM.server.luau` - Server Actor
- Handles messages from Dispatcher
- Initializes BaseCast on `Init` message
- Processes Raycast/Blockcast/Spherecast

## How Connections Work

### Cast Flow (Parallel Mode)

```
User calls caster:RaycastFire(origin, direction, velocity, behavior)
        │
        ▼
FastCastParallel:RaycastFire() [init.luau]
        │
        ▼
Dispatcher:Dispatch("Raycast", ...)
        │
        ▼
Dispatcher selects Actor with lowest Tasks
        │
        ▼
Actor receives "Raycast" message
        │
        ▼
BaseCast:Raycast() [BaseCast.luau]
        │
        ├── Creates ActiveCast data
        │
        ▼
ParallelSimulation.Register(cast)
        │
        └── Stores in Actor-local SoA arrays
        │
        ▼
ParallelSimulation.UpdateCasts() [PreRender:ConnectParallel]
        │
        ├── For each cast (parallel):
        │   ├── Calculate position/velocity
        │   ├── Raycast physics
        │   └── Update cosmetic bullet
        │
        ├── task.synchronize()
        │
        └── Fire events via queue
        │
        ▼
Event callbacks fire (LengthChanged, Hit, etc.)
```

### BulkMoveTo Connection (Parallel)

```lua
-- In BaseCast.luau:
BulkMoveToConnection = RS.PreRender:ConnectParallel(HandleBulkMoveTo)

function HandleBulkMoveTo()
    -- Collect all CFrame updates from SoA arrays
    for _, ActiveCasts in Actives do
        table.insert(Parts, ActiveCasts.RayInfo.CosmeticBulletObject)
        table.insert(CFrames, ActiveCasts.CFrame)
    end

    task.synchronize()  -- Wait for parallel calcs

    workspace:BulkMoveTo(Parts, CFrames, Enum.BulkMoveMode.FireCFrameChanged)
end
```

### Motor6D Transform Mode

```lua
-- In ParallelSimulation.Register():
if cast.RayInfo.MovementMethod == "Transform" then
    castMotor6D[id] = Motor6DPool.Connect(id, cosmeticBullet)
end

-- In UpdateCasts():
if motor6d then
    motor6d.Transform = newCFrame  -- Efficient, no physics sync needed
end
```

## Key Design Patterns

### 1. SoA Arrays
```lua
-- ParallelSimulation.luau lines 58-83
local castCount = 0
local casts = {}
local castIDs = {}
local castOrigin = {}
local castVelocity = {}
local castAcceleration = {}
-- ... all arrays indexed by cast ID
```

### 2. Event Queue (Sync Phase)
```lua
-- Events queued during parallel phase, dispatched after sync
QueueFire(caster, "Hit", cast, result, vel, bullet)
-- ... later:
DispatchAllEvents()
```

### 3. Load Balancing
```lua
-- Dispatcher:Dispatch() sorts by Tasks attribute
table.sort(Threads, function(a, b)
    return a:GetAttribute("Tasks") < b:GetAttribute("Tasks")
end)
Threads[1]:SendMessage("Raycast", ...)
```

### 4. Motor6D Pooling
```lua
-- Efficient Transform mode without per-bullet physics
local motor6d = Motor6DPool.Connect(castID, part)
motor6d.Transform = newCFrame  -- Set without parenting complexity
```

## Configuration

### FastCastBehavior Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `RaycastParams` | RaycastParams | nil | Collision filtering |
| `MaxDistance` | number | 1000 | Max cast distance |
| `Acceleration` | Vector3 | (0,0,0) | Gravity effect |
| `HighFidelityBehavior` | number | 1 | Hit verification mode |
| `HighFidelitySegmentSize` | number | 0.1 | Sub-cast segment size |
| `CosmeticBulletTemplate` | Instance | nil | Visual bullet part |
| `CosmeticBulletContainer` | Instance | nil | Parent for bullets |
| `MovementMethod` | string | "BulkMoveTo" | "BulkMoveTo" or "Transform" |
| `VisualizeCasts` | boolean | false | Show debug rays |

## Performance Considerations

1. **SoA vs AoS**: SoA provides ~2-3x better cache performance
2. **BulkMoveTo**: Batches part updates efficiently
3. **Motor6D Pool**: Avoids CreateInstance overhead
4. **Event Queue**: Reduces cross-thread communication
5. **Parallel Simulation**: Scales with Actor count
6. **Load Balancing**: Prevents Actor overload

## Summary

FastCast2 uses modern game engine techniques adapted for Roblox:
- **Multi-threading via Actors**
- **SoA data layout for cache efficiency**
- **Event queue for thread-safe communication**
- **Object pooling for memory efficiency**
- **Bulk operations for reduced overhead**
