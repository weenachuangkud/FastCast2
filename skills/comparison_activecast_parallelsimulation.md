# ActiveCast vs ParallelSimulation Comparison

## Overview

| Aspect | ActiveCast (Legacy) | ParallelSimulation (New) |
|--------|---------------------|--------------------------|
| **Lines** | 993 | 669 |
| **Pattern** | Object-oriented (table per cast) | SoA (Array of Structs) |
| **Execution** | Sequential (Heartbeat) | Parallel (ConnectParallel) |
| **Event System** | Direct firing via Output | Queued + Dispatched |
| **Movement** | BulkMoveTo / PivotTo | Motor6D + BulkMoveTo/PivotTo |

---

## Core Architecture

### ActiveCast (Legacy)
```lua
-- Each cast is a complete table with all data
local cast = {
    StateInfo = { ... },
    RayInfo = { ... },
    Caster = ...,
    CFrame = ...,
    ID = ...
}
```

### ParallelSimulation (New)
```lua
-- SoA pattern: separate arrays for each field
local castOrigin = {} :: { [number]: Vector3 }
local castVelocity = {} :: { [number]: Vector3 }
local castAcceleration = {} :: { [number]: Vector3 }
-- ... etc
```

---

## Key Differences

### 1. Cast Registration

**ActiveCast:**
- `createCastData()` function creates full cast table
- Sets up Stepped connection internally (commented out)
- No parallel registration

**ParallelSimulation:**
- `Register(cast)` extracts data from cast table into SoA arrays
- Assigns numeric ID for array indexing
- Initializes Motor6D if needed
- Queues CastFire event

### 2. Simulation Loop

**ActiveCast:**
- Single cast per frame via `Stepped()` function
- Uses `GetPositionAtTime()` and `GetVelocityAtTime()`
- Complex HighFidelity logic with sub-segments
- Direct event firing

**ParallelSimulation:**
- `UpdateCasts(deltaTime)` iterates all casts
- Same physics math but batched
- HighFidelity logic inline in main loop
- Event queuing via `QueueFire()`

### 3. Event Handling

**ActiveCast:**
```lua
cast.Caster.Output:Fire("Hit", cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
```

**ParallelSimulation:**
```lua
local function QueueFire(caster, eventsConfig, eventsModuleConfig, eventsModule, eventName, ...)
    -- queues event
end

local function DispatchAllEvents()
    -- dispatches all queued events after frame
end
```

### 4. Visualization

**ActiveCast:**
- Built-in functions: `DbgVisualizeRaySegment`, `DbgVisualizeBlockSegment`, `DbgVisualizeSphereSegment`, `DbgVisualizeHit`
- Uses `task.synchronize()` inside simulation

**ParallelSimulation:**
- Separate functions: `VisualizeRaySegment`, `VisualizeBlockSegment`, etc.
- Uses `task.synchronize()` only when visualization enabled

### 5. Movement Methods

**ActiveCast:**
- `MovementMethod` stored but limited implementation
- Direct CFrame assignment

**ParallelSimulation:**
- Full Motor6D support via `Motor6DPool`
- Conditional movement: Motor6D.Transform vs bullet.CFrame vs bullet:PivotTo()

---

## Physics Comparison

### Position Calculation (Identical)
```lua
-- Both use same formula
local force = Vector3.new(
    (accel.X * t ^ 2) / 2,
    (accel.Y * t ^ 2) / 2,
    (accel.Z * t ^ 2) / 2
)
return origin + (velocity * t) + force
```

### Velocity Calculation (Identical)
```lua
-- Both use same formula
return velocity + accel * time
```

### Ray Direction Calculation (Identical)
```lua
local rayDir = displacement.Unit * currentVelocity.Magnitude * deltaTime
```

---

## HighFidelity Logic

### ActiveCast
- Checks `HighFidelityBehavior.Automatic` + segment size
- Full sub-segment loop with detailed event handling
- Cancel/resume logic

### ParallelSimulation
- Same conditions: `highFidelityBehavior == HighFidelityBehavior.Automatic`
- Same segment calculation logic
- Same piercing check flow

---

## Event Config

### ActiveCast
```lua
FastCastEventsModuleConfig = {
    UseLengthChanged = behavior.FastCastEventsModuleConfig.UseLengthChanged,
    UseHit = behavior.FastCastEventsModuleConfig.UseHit,
    -- ...
}
```

### ParallelSimulation
```lua
castEventsConfig[id] = cast.StateInfo.FastCastEventsConfig
castEventsModuleConfig[id] = cast.StateInfo.FastCastEventsModuleConfig
```

---

## Known Differences to Check

1. **Cast Type Handling**: ActiveCast has explicit type handling via `CastVariantTypes`, ParallelSimulation converts string to enum

2. **Cosmetic Bullet**: ActiveCast handles ObjectCache differently than ParallelSimulation

3. **Automatic Performance**: ActiveCast has commented-out automatic performance adjustment code

4. **Motor6D Pool**: ParallelSimulation has dedicated Motor6D pooling, ActiveCast does not

5. **Parallel Execution**: ParallelSimulation uses `RS.PreRender:ConnectParallel` on client, ActiveCast uses `RS.PreSimulation` or `RS.Heartbeat`

---

## Potential Issues When Editing

1. **Event Dispatch Timing**: ParallelSimulation queues events and dispatches at end of frame - ensure timing is correct

2. **Thread Safety**: Parallel execution requires `task.synchronize()` before any Roblox API calls

3. **ID Management**: When unregistering casts, ParallelSimulation swaps with last element - must update cast.ID correctly

4. **Motor6D Cleanup**: Must disconnect Motor6D when cast terminates to avoid leaks

5. **Pierce Function Storage**: `castCanPierceFn` stores CanPierce callback - verify it's properly copied from cast