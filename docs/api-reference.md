# FastCast2 Documentation

## 1. Caster

### 1.1 How to construct and initialize Caster (`.new()`) - Serial Mode

Serial Caster runs all cast simulations on the main thread. Simpler to use but less performant than Parallel.

```lua
local caster = FastCast2.new()
caster:Init(useBulkMoveTo, useObjectCache, template, cacheSize, cacheHolder)
```

#### 1.1.1 How Initialization Works

- `Init()` sets up the Serial Caster with optional BulkMoveTo and ObjectCache
- No Dispatcher needed - runs directly on main thread

#### 1.1.2 ObjectCache

ObjectCache reuses projectile parts for better performance:

```lua
caster:Init(true, true, projectileTemplate, 500, workspace)
-- useBulkMoveTo: true, useObjectCache: true, template, cacheSize, holder
```

#### 1.1.3 Motor6D Transform

Movement method for projectile animation:

```lua
local behavior = FastCast2.newBehavior()
behavior.MovementMethod = "BulkMoveTo"  -- Default - uses BulkMoveTo
-- or
behavior.MovementMethod = "Transform"   -- Uses Motor6D for better performance
```

#### 1.1.4 Fields and Properties

- `caster.LengthChanged` - Signal fired when cast length changes
- `caster.Hit` - Signal fired when cast hits something
- `caster.Pierced` - Signal fired when cast pierces something
- `caster.CastTerminating` - Signal fired when cast terminates
- `caster.CastFire` - Signal fired when cast is fired

---

### 1.2 How to construct and initialize Caster (`.newParallel()`) - Parallel Mode

Parallel Caster runs cast simulations on separate worker VMs for high-performance scenarios.

```lua
local caster = FastCast2.newParallel()
caster:Init(
    numWorkers,      -- number of worker VMs (must be > 1)
    newParent,       -- Folder to place FastCastVMs
    newName,         -- name for FastCastVMs folder
    ContainerParent, -- parent for worker containers
    VMContainerName, -- name for containers
    VMname,          -- name for each worker VM
    useBulkMoveTo,   -- enable BulkMoveTo
    fastCastEventsModule, -- optional events module
    useObjectCache,  -- enable ObjectCache
    template,        -- ObjectCache template
    cacheSize,       -- ObjectCache size
    CacheHolder      -- ObjectCache parent
)
```

#### 1.2.1 How Does Initialization Work

- Creates Actor-based worker VMs using VMsDispatcher
- Each worker handles multiple casts in parallel via `ConnectParallel`

#### 1.2.2 numWorkers

Number of parallel workers. More workers = more parallel processing but higher overhead.

#### 1.2.3 What are FastCastVMs (VMsDispatcher)

FastCastVMs is a dispatcher system that spawns Actor-based worker scripts to handle casts in parallel.

#### 1.2.4 ObjectCache (Parallel)

Same as Serial but shared across workers.

#### 1.2.5 BulkMoveTo

Moves cosmetic bullets efficiently:

```lua
caster:SetBulkMoveEnabled(true)
```

#### 1.2.6 Motor6D Transform

Same as Serial - set `MovementMethod` in behavior.

---

### 1.3 Methods

#### 1.3.1 `.newBehavior()`

Creates a FastCastBehavior for configuring casts:

```lua
local behavior = caster:newBehavior()
-- or
local behavior = FastCast2.newBehavior()
```

#### 1.3.2 `:RaycastFire(origin, direction, velocity, behavior)`

Fire a raycast projectile.

#### 1.3.3 `:BlockcastFire(origin, size, direction, velocity, behavior)`

Fire a blockcast projectile.

#### 1.3.4 ':SpherecastFire(origin, radius, direction, velocity, behavior)'

Fire a spherecast projectile.

#### 1.3.5 - 1.3.14 Cast Manipulation

- `GetVelocityCast(cast)` - Get projectile velocity
- `GetAccelerationCast(cast)` - Get projectile acceleration
- `GetPositionCast(cast)` - Get projectile position
- `SetVelocityCast(cast, velocity)` - Set projectile velocity
- `SetAccelerationCast(cast, acceleration)` - Set projectile acceleration
- `SetPositionCast(cast, position)` - Set projectile position
- `PauseCast(cast, paused)` - Pause/resume projectile
- `AddPositionCast(cast, position)` - Add position offset
- `AddVelocityCast(cast, velocity)` - Add velocity offset
- `AddAccelerationCast(cast, acceleration)` - Add acceleration offset

#### 1.3.15 `SyncChangesToCast(cast)`

Sync changes to parallel workers (only needed in Parallel mode).

#### 1.3.16 `TerminateCast(cast)`

Forcefully terminate a cast.

#### 1.3.17 - 1.3.20 Other Methods

- `:SetBulkMoveEnabled(enabled)` - Enable/disable BulkMoveTo
- `:SetObjectCacheEnabled(enabled)` - Enable/disable ObjectCache
- ':SetFastCastEventsModule(module)' - Set events module (Parallel only)
- `:Destroy()` - Destroy the caster

---

## 2. ActiveCastData

### 2.1 What is ActiveCast

ActiveCast represents a projectile in flight. It's a pure data structure (AoS) exposed to users, while internally FastCast2 uses SoA for performance.

### 2.2 Data Structure

```lua
cast.Caster      -- Reference to parent Caster
cast.StateInfo   -- Runtime state (paused, runtime, etc.)
cast.RayInfo     -- Raycast parameters and result
cast.UserData   -- User-defined data
cast.Type       -- "Raycast", "Blockcast", or "Spherecast"
cast.CFrame     -- Current position and rotation
cast.ID         -- Unique cast identifier
```

### 2.3 Variants

- `ActiveCastData` - Standard raycast
- `ActiveBlockcastData` - Has `.RayInfo.Size`
- `ActiveSpherecastData` - Has `.RayInfo.Radius`

---

## 3. TypeDefinitions

### 3.1 Caster

Properties exposed on Caster object:

- `WorldRoot` - Workspace for raycasts
- `Events` - Signal connections
- `Dispatcher` - Parallel dispatcher (Parallel only)
- `ObjectCache` - Object caching system
- `ObjectCacheEnabled` - Whether ObjectCache is active
- `BulkMoveEnabled` - Whether BulkMoveTo is active

### 3.2 ActiveCastData

#### 3.2.2 StateInfo

- `HighFidelityBehavior` - Precision mode:
  - `Default` (1) - Standard precision
  - `Automatic` (2) - Auto-adjusts precision
  - `Always` (3) - Always high precision
- `HighFidelitySegmentSize` - Segment size for high-fidelity mode
- `Paused` - Whether cast is paused
- `TotalRuntime` - Time since cast started
- `DistanceCovered` - Total distance traveled
- `Trajectory` - Single trajectory object (Origin, Velocity, Acceleration, StartTime, EndTime)

#### 3.2.3 RayInfo

- `Parameters` - RaycastParams
- `WorldRoot` - Target WorldRoot
- `MaxDistance` - Maximum travel distance
- `CosmeticBulletObject` - Visual projectile part
- `MovementMethod` - "BulkMoveTo" or "Transform"

### 3.3 FastCastBehavior

Configuration for cast behavior:

```lua
local behavior = FastCast2.newBehavior()
behavior.RaycastParams = RaycastParams.new()
behavior.MaxDistance = 1000
behavior.Acceleration = Vector3.new(0, -196.2, 0)  -- Gravity
behavior.HighFidelityBehavior = 1  -- Default
behavior.HighFidelitySegmentSize = 0.5
behavior.MovementMethod = "BulkMoveTo"
behavior.CosmeticBulletTemplate = part
behavior.CosmeticBulletContainer = workspace
behavior.AutoIgnoreContainer = true
```

---

## 4. Special

### 4.1 FastCastEventsModule

FastCastEventsModule is a ModuleScript with callback functions for parallel optimization.

```lua
-- In a ModuleScript
local module = {}

module.LengthChanged = function(cast)
    -- Called every frame
end

module.Hit = function(cast, result, velocity, bullet)
    -- Called on hit
end

module.CanPierce = function(cast, result, velocity, bullet)
    -- Return true to pierce, false to stop
    return false
end

return module
```

Then set it:
```lua
caster:SetFastCastEventsModule(pathToModule)
```

Note: Not available in Serial mode - use standard Signals instead.

---

## Performance

FastCast2 uses:
- **Serial Mode**: Single RunService with SoA for all casts
- **Parallel Mode**: One RunService per Actor with SoA within each

This approach replaces per-cast RunService connections for better performance.