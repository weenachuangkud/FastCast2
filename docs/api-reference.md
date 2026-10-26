# FastCast2 Documentation

### 1.0 Runtime Lifecycle

The Serial implementation uses a shared singleton runtime. Call `FastCast.Init()` to initialize the runtime on the first call and ensure simulation is running. Calling it again while running is safe; after `FastCast.Stop()`, calling `FastCast.Init()` resumes simulation without reinitializing the runtime.

```lua
FastCast.Init() -- Initialize once, or resume if stopped

-- Later, when simulation should pause:
FastCast.Stop()

-- Resume the existing runtime and active casts:
FastCast.Init()
```

`Stop()` disconnects simulation updates; it does not destroy active casts or reset the runtime. Active casts resume when simulation starts again. If `Config.SimulationMode` is changed while stopped, the next `Init()` uses the updated mode. Use `FastCast.SetMovementModeEnabled(enabled, mode)` to change movement mode; do not reinitialize for that.

---

## 1. Caster

### 1.1 Serial Mode (`FastCast.new()`)

Serial Caster runs all cast simulations on the main thread. Simpler.

```lua
local caster = FastCast2.new()
FastCast.Init(movementMode)
```

#### 1.1.1 Events

Caster events are lightweight `Signal` objects (not `BindableEvent`s), so any
number of listeners can connect and disconnect independently. Events can be
connected **before or after Init**:

```lua
local connection = caster.Hit:Connect(function(cast, result, velocity, cosmeticBullet) end)
connection:Disconnect() -- stop listening

caster.Pierced:Connect(function(cast, result, velocity, cosmeticBullet) end)
caster.LengthChanged:Connect(function(cast, lastPoint, rayDir, rayDisplacement, velocity, cosmeticBullet) end)
caster.CastFire:Connect(function(cast, origin, direction, velocity, behavior) end)
caster.CastTerminating:Connect(function(cast) end)
```

`CanPierce` is a query that must return a boolean, so it stays a single function:

```lua
caster.CanPierce = function(cast, result, velocity, cosmeticBullet) -> boolean end
```

For backwards compatibility, assigning a function to a signal event is shorthand
for `:Connect` and replaces any previous function assigned this way:

```lua
caster.Hit = function(cast, result, velocity, cosmeticBullet) end
```

`Signal` supports `Connect`, `Once`, `Wait`, `Fire`, `DisconnectAll`, and `Destroy`.

#### 1.1.2 Movement Modes

- **`"BulkMoveTo"`** — Uses `workspace:BulkMoveTo()` each frame. (General/Default)
- **`"Motor6D"`** — Uses Motor6D instances (Transform property). Better for performance.

Switch the shared Serial runtime's mode at runtime with `FastCast2.SetMovementModeEnabled(enabled, mode)`. This setting applies to all Serial casters because they share one simulation runtime.

---

### 1.2 Fire Methods

The serial caster supports all three fire methods:

```lua
caster:RaycastFire(origin, direction, velocity, BehaviorData?)
caster:BlockcastFire(origin, Size, direction, velocity, BehaviorData?)
caster:SpherecastFire(origin, Radius, direction, velocity, BehaviorData?)
```

- `velocity` can be a `Vector3` (exact velocity) or `number` (speed in the fire direction)
- `BehaviorData` is a `FastCastBehavior` created with `FastCast2.newBehavior()`

```lua
-- Raycast: simple line-of-sight
caster:RaycastFire(Vector3.new(0, 5, 0), Vector3.new(0, 0, -1), 500, behavior)

-- Blockcast: pass a Vector3 size after origin
caster:BlockcastFire(Vector3.new(0, 5, 0), Vector3.new(2, 4, 2), Vector3.new(0, 0, -1), 500, behavior)

-- Spherecast: pass a radius after origin
caster:SpherecastFire(Vector3.new(0, 5, 0), 3, Vector3.new(0, 0, -1), 500, behavior)
```

---

### 1.3 Cast Manipulation (static methods on `FastCast`)

```lua
-- Getters
FastCast:GetPositionCast(cast) → Vector3
FastCast:GetVelocityCast(cast) → Vector3
FastCast:GetAccelerationCast(cast) → Vector3

-- Setters (modifies trajectory, triggers CancelHighResCast)
FastCast:SetVelocityCast(cast, velocity) → ()
FastCast:SetAccelerationCast(cast, acceleration) → ()
FastCast:SetPositionCast(cast, position) → ()

-- Adders (relative modification)
FastCast:AddPositionCast(cast, position) → ()
FastCast:AddVelocityCast(cast, velocity) → ()
FastCast:AddAccelerationCast(cast, acceleration) → ()

-- Termination
FastCast:TerminateCast(cast) → ()
```

```lua
-- Example: modify a cast mid-flight
local function onHit(cast, result, velocity, bullet)
	-- Deflect the projectile upward on hit
	FastCast.SetVelocityCast(cast, Vector3.new(0, 100, 0))
	FastCast.SetPositionCast(cast, result.Position + Vector3.new(0, 2, 0))

end
```

---

### 1.4 Lifecycle

```lua
caster:Destroy()  -- Cleans up the caster's simulation state and event signals
```

---

## 2. FastCastBehavior

Created via `FastCast2.newBehavior()`. Configuration for cast behavior:

```lua
local behavior = FastCast2.newBehavior()
behavior.MaxDistance = 500
behavior.MaxPiercesPerStep = 3 -- Check up to 3 collisions per movement segment when piercing
behavior.InitialOffset = CFrame.new(0, 0, -2) -- Initial local-space cosmetic offset
behavior.RaycastParams = RaycastParams.new()
behavior.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
behavior.RaycastParams.FilterDescendantsInstances = {character}
behavior.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
behavior.CosmeticBulletContainer = workspace.Projectiles
behavior.CosmeticBulletTemplate = ReplicatedStorage.Projectile
behavior.HighFidelityBehavior = FastCastEnums.HighFidelityBehavior.Automatic
behavior.HighFidelitySegmentSize = 0.5
behavior.VisualizeCasts = true
behavior.VisualizeCastSettings = {
	Debug_SegmentColor = Color3.new(1, 1, 0),
	Debug_HitColor = Color3.new(1, 0, 0),
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `RaycastParams` | `RaycastParams?` | `nil` | Filter rules for raycasting |
| `MaxDistance` | `number` | `1000` | Max range before auto-termination |
| `MaxPiercesPerStep` | `number` | `1` | Maximum collision-query attempts in one movement segment, including the first hit; further queries continue after a pierce |
| `InitialOffset` | `CFrame` | `CFrame.identity` | Initial local-space offset applied to each cast's cosmetic projectile; does not affect simulation or hit detection |
| `Acceleration` | `Vector3` | `(0,0,0)` | Constant acceleration applied each frame |
| `HighFidelityBehavior` | `number` | `1` | Default(1) / Automatic(2) / Always(3) |
| `HighFidelitySegmentSize` | `number` | `0.5` | Segment size for sub-stepping |
| `CosmeticBulletTemplate` | `BasePart?` | `nil` | Visual projectile part |
| `CosmeticBulletContainer` | `Instance?` | `nil` | Parent for non-cached bullets |
| `AutoIgnoreContainer` | `boolean` | `true` | Auto-adds container to filter list |
| `VisualizeCasts` | `boolean` | `false` | Debug visualization toggle |
| `VisualizeCastSettings` | `table` | (defaults) | Debug viz colors, sizes, lifetimes |
| `CloneTemplate` | `boolean` | `true` | Clone CosmeticBulletTemplate or not  |
| `UserData` | `any` | `nil` | Arbitrary data accessible on the cast |

### Event Configuration

```lua
behavior.FastCastEventsConfig = {
    UseLengthChanged = false,
    UseHit = true,
    UsePierced = true,
    UseCastTerminating = true,
    UseCanPierce = true,
    UseCastFire = true
}

```

---

## 3. ActiveCastData

### 3.1 What is ActiveCast

ActiveCast represents a projectile in flight. It's a pure data structure (AoS) exposed to users, while internally FastCast2 uses SoA for performance.

### 3.2 Data Structure

```lua
cast.ID: number              -- Unique identifier
cast.PreviousPosition: Vector3 -- Position at the start of the most recent simulation step
cast.CFrame: CFrame          -- Current cosmetic bullet CFrame
cast.Offset: CFrame          -- Local-space cosmetic offset; can be changed while the cast is active
cast.UserData: any           -- From behavior.UserData
cast.CastVariant: {          -- Cast type info
    CastType: number,        -- 1=Raycast, 2=Blockcast, 3=Spherecast
    Size: Vector3?,          -- Blockcast only
    Radius: number?          -- Spherecast only
}
```

Set `behavior.InitialOffset` to initialize `cast.Offset` for each cast. You can then change `cast.Offset` while that cast is active. The offset is composed in local space on top of the calculated cosmetic CFrame and affects only cosmetic placement/orientation; raycasts, trajectory, and hit detection are unchanged. `CFrame.identity` preserves the existing appearance.

### 3.3 StateInfo

```lua
cast.StateInfo.TotalRuntime: number
cast.StateInfo.MaxPiercesPerStep: number
cast.StateInfo.HighFidelityBehavior: number
cast.StateInfo.HighFidelitySegmentSize: number
cast.StateInfo.IsActivelyResimulating: boolean
cast.StateInfo.CancelHighResCast: boolean
cast.StateInfo.VisualizeCasts: boolean
cast.StateInfo.VisualizeCastSettings: VisualizeCastSettings
cast.StateInfo.FastCastEventsConfig: FastCastEventsConfig
cast.StateInfo.Trajectory = {
    StartTime: number,
    EndTime: number,            -- -1 if still active
    Origin: Vector3,
    InitialVelocity: Vector3,
    Acceleration: Vector3
}
```

### 3.4 RayInfo

```lua
cast.RayInfo.Parameters: RaycastParams
cast.RayInfo.WorldRoot: WorldRoot
cast.RayInfo.MaxDistance: number
cast.RayInfo.CosmeticBulletObject: Instance?
cast.RayInfo.Size: Vector3       -- Blockcast only
cast.RayInfo.Radius: number      -- Spherecast only
```

---

## 4. High-Fidelity Behavior

| Mode | Value | Description |
|------|-------|-------------|
| **Default** | `1` | Single cast per frame. Fastest, lowest accuracy. |
| **Automatic** | `2` | On hit, subdivides the frame's cast into sub-segments to find precise hit point. |
| **Always** | `3` | Always subdivides every frame. Most accurate, most expensive. |

`HighFidelitySegmentSize` controls the segment size for sub-stepping (default 0.5 studs).
