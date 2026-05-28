---
sidebar_position: 2
---

# FastCast2 CheatSheet

## Quick Example

```lua
local caster = FastCast2.new()
caster:Init("BulkMoveTo", false)

caster.Hit = function(cast, result, velocity, bullet)
	print("Hit:", result.Instance)
end

caster:RaycastFire(origin, direction, 500, behavior)
```

## Caster — Serial Mode

```luau
--// Construct & Init

local Caster = FastCast2.new()  -- Construct a new Serial Caster

Caster:Init(
    movementMode: "BulkMoveTo" | "Motor6D",  -- Movement method for cosmetic bullets.
    useObjectCache: boolean,                  -- Enable ObjectCache for this Caster.
    Template: BasePart | Model?,              -- Template for ObjectCache (if enabled).
    CacheSize: number?,                       -- Number of objects to pre-allocate.
    CacheHolder: Instance?                    -- Parent for cached objects.
)
-- ⚠ Must be called before any Fire methods — nothing happens without Init!


--// Events (assign callbacks before Init)

Caster.Hit = function(cast, result, velocity, cosmeticBullet) end
Caster.Pierced = function(cast, result, velocity, cosmeticBullet) end
Caster.LengthChanged = function(cast, lastPoint, rayDir, rayDisplacement) end
Caster.CastFire = function(cast, origin, direction, velocity, behavior) end
Caster.CastTerminating = function(cast) end
Caster.CanPierce = function(cast, result, velocity, cosmeticBullet) -> boolean end

--// Fire Methods

Caster:RaycastFire(origin, direction, velocity, BehaviorData)
Caster:BlockcastFire(origin, Size, direction, velocity, BehaviorData)
Caster:SpherecastFire(origin, Radius, direction, velocity, BehaviorData)

-- Example:
-- caster:RaycastFire(Vector3.new(0,5,0), Vector3.new(0,0,-1), 500, behavior)
-- caster:BlockcastFire(Vector3.new(0,5,0), Vector3.new(2,2,2), Vector3.new(0,0,-1), 500, behavior)
-- caster:SpherecastFire(Vector3.new(0,5,0), 3, Vector3.new(0,0,-1), 500, behavior)


--// Configuration

Caster:SetMovementModeEnabled(enabled: boolean, mode: "BulkMoveTo" | "Motor6D") → ()
Caster:SetObjectCacheEnabled(enabled, Template?, CacheSize?, CacheHolder?) → ()


--// Lifecycle

Caster:Destroy() → ()
```

---

## Caster — Parallel Mode

```luau
--// Construct & Init

local Caster = FastCast2.newParallel()

Caster:Init(
    numWorkers: number,                 -- Number of Actor VMs. Must be > 1.
    newParent: Folder,                  -- Parent for the FastCastVMs Folder.
    newName: string,                    -- Name for the FastCastVMs Folder.
    ContainerParent: Folder,            -- Parent for worker VM Containers.
    VMContainerName: string,            -- Name for VM Containers.
    VMname: string,                     -- Name given to each worker VM.
    movementMode: "BulkMoveTo" | "Motor6D",  -- Movement method.
    FastCastEventsModule: ModuleScript?,-- ModuleScript returning a FastCastEvents table.
    useObjectCache: boolean,            -- Enable ObjectCache for this Caster.
    Template: BasePart | Model?,        -- Template for ObjectCache (if enabled).
    CacheSize: number?,                 -- Number of objects to pre-allocate.
    CacheHolder: Instance?              -- Parent for cached objects.
)
-- ⚠ Must be called before any Fire methods — nothing happens without Init!


--// Fire Methods (same as Serial)

Caster:RaycastFire(origin, direction, velocity, BehaviorData)
Caster:BlockcastFire(origin, Size, direction, velocity, BehaviorData)
Caster:SpherecastFire(origin, Radius, direction, velocity, BehaviorData)

-- Example:
-- caster:RaycastFire(Vector3.new(0,5,0), Vector3.new(0,0,-1), 500, behavior)
-- caster:BlockcastFire(Vector3.new(0,5,0), Vector3.new(2,2,2), Vector3.new(0,0,-1), 500, behavior)
-- caster:SpherecastFire(Vector3.new(0,5,0), 3, Vector3.new(0,0,-1), 500, behavior)


--// Configuration

Caster:SetFastCastEventsModule(moduleScript: ModuleScript) → ()
Caster:SetMovementModeEnabled(enabled: boolean, mode: "BulkMoveTo" | "Motor6D") → ()
Caster:SetObjectCacheEnabled(enabled, Template?, CacheSize?, CacheHolder?) → ()


--// Cast Manipulation  (use FastCast static methods)

FastCast.GetPositionCast(cast) → Vector3
FastCast.GetVelocityCast(cast) → Vector3
FastCast.GetAccelerationCast(cast) → Vector3

FastCast.SetVelocityCast(cast, velocity) → ()
FastCast.SetAccelerationCast(cast, acceleration) → ()
FastCast.SetPositionCast(cast, position) → ()

FastCast.AddPositionCast(cast, position) → ()
FastCast.AddVelocityCast(cast, velocity) → ()
FastCast.AddAccelerationCast(cast, acceleration) → ()

-- ⚠ After any Set/Add, sync changes to push state to the worker VM:
Caster:SyncChangesToCast(cast) → ()

FastCast.TerminateCast(cast) → ()
-- TerminateCast fires CastTerminating, returns cosmetic to cache, and unregisters the cast.
-- Call from Hit/Pierced callback to stop a cast early:
-- caster.Hit = function(cast) FastCast.TerminateCast(cast) end


--// Lifecycle

Caster:Destroy() → ()
```

---

## FastCastBehavior

```luau
local behavior = FastCast2.newBehavior()

behavior.RaycastParams = RaycastParams.new()
behavior.MaxDistance = 1000
behavior.Acceleration = Vector3.new(0, -196.2, 0)
behavior.HighFidelityBehavior = 1  -- Default | Automatic(2) | Always(3)
behavior.HighFidelitySegmentSize = 0.5
behavior.CosmeticBulletTemplate = somePart  -- Visual projectile
behavior.CosmeticBulletContainer = workspace  -- Parent for non-cached bullets
behavior.AutoIgnoreContainer = true
behavior.VisualizeCasts = false
behavior.VisualizeCastSettings = { ... }  -- Debug viz colors/sizes
behavior.UserData = {}  -- Arbitrary data accessible on the cast

behavior.FastCastEventsConfig = {
    UseLengthChanged = false,
    UseHit = true,
    UsePierced = true,
    UseCastTerminating = true,
    UseCanPierce = true,
    UseCastFire = true
}

behavior.FastCastEventsModuleConfig = {
    UseLengthChanged = false,
    UseHit = true,
    UsePierced = true,
    UseCastTerminating = true,
    UseCanPierce = true,
    UseCastFire = true
}
```

---

## ActiveCastData

```luau
cast.ID: number              -- Unique cast identifier
cast.Type: number            -- 1=Raycast, 2=Blockcast, 3=Spherecast
cast.CFrame: CFrame          -- Current cosmetic bullet CFrame
cast.UserData: any           -- Custom data from behavior.UserData
cast.CastVariant: table      -- { CastType, Size?|Radius? }

--// cast.StateInfo

cast.StateInfo.TotalRuntime: number
cast.StateInfo.HighFidelityBehavior: number
cast.StateInfo.HighFidelitySegmentSize: number
cast.StateInfo.IsActivelyResimulating: boolean
cast.StateInfo.CancelHighResCast: boolean
cast.StateInfo.FastCastEventsConfig: FastCastEventsConfig
cast.StateInfo.FastCastEventsModuleConfig: FastCastEventsModuleConfig  -- Parallel only
cast.StateInfo.VisualizeCasts: boolean
cast.StateInfo.VisualizeCastSettings: VisualizeCastSettings

cast.StateInfo.Trajectory = {
    StartTime: number,
    EndTime: number,            -- -1 if still active
    Origin: Vector3,
    InitialVelocity: Vector3,
    Acceleration: Vector3
}

--// cast.RayInfo

cast.RayInfo.Parameters: RaycastParams
cast.RayInfo.WorldRoot: WorldRoot
cast.RayInfo.MaxDistance: number
cast.RayInfo.CosmeticBulletObject: Instance?
cast.RayInfo.Size: Vector3       -- Blockcast only
cast.RayInfo.Radius: number      -- Spherecast only
```
