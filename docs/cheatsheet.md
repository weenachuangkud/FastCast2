# FastCast2 CheatSheet v0.0.9

## Caster

```lua

-- Construct and Init
local Caster = FastCast2.new() -- Construct a new Caster

Caster:Init(
    numWorker: number, -- The number of worker VMs to create for this Caster. Must be greater than 1.
    newParent: Folder, -- The Folder in which to place the FastCastVMs Folder
    newName: string,-- The name to give the FastCastVMs Folder containing worker scripts.
    ContainerParent: Folder,-- The parent Folder in which to place the worker VM Containers.
    VMname: string,-- The name to give each worker VM.
    useBulkMoveTo: boolean,-- Whether to enable BulkMoveTo for the CosmeticBulletObjects
    FastCastEventsModule: ModuleScript,-- The ModuleScript containing the FastCastEvents, A table of callback functions (events/hooks) used by ActiveCast..
    useObjectCache: boolean,-- Whether to use ObjectCache for the Caster
    Template: BasePart | Model,-- The template object to use for the ObjectCache (if enabled)
    CacheHolder: Instance-- The Instance in which to place cached objects (if enabled)
)
-- Initializes the Caster with the given parameters. This is required before firing using Raycasts in the Caster or nothing will happen!


-- Functions
Caster:RaycastFire(origin: Vector3, direction: Vector3, velocity: Vector3 | number, BehaviorData: FastCastBehavior?) → () -- Raycasts the Caster with the specified parameters.
Caster:BlockcastFire(origin: Vector3, Size: Vector3, direction: Vector3, velocity: Vector3 | number, BehaviorData: FastCastBehavior?) -> () -- Blockcasts the Caster with the specified parameters.
Caster:SpherecastFire(origin: Vector3, Radius: number, direction: Vector3, velocity: Vector3 | number, BehaviorData: TypeDef.FastCastBehavior? ) -> () -- Spherecasts the Caster with the specified parameters.

Caster:SetFastCastEventsModule(moduleScript: ModuleScript) → () -- Set the FastCastEventsModule for all BaseCasts created from this Caster.

Caster:SetBulkMoveEnabled(enabled: boolean) -- Sets whether BulkMoveTo is enabled for this Caster.
Caster:SetObjectCacheEnabled(
    enabled: boolean, -- Is enabled
    Template: BasePart | Model, -- Projectile template
    CacheSize: number, -- Pre allocate size
    CacheHolder: Instance -- Where ObjectCache are stored
) -- Sets whether ObjectCache is enabled for this Caster.

Caster:Destroy() → () -- Destroy's a Caster, cleaning up all resources used by it.

FastCast:GetVelocityCast(cast: vaildcast) -- Gets the velocity of an ActiveCast.
FastCast:GetAccelerationCast(cast: vaildcast) -- Gets the acceleration of an ActiveCast.
FastCast:GetPositionCast(cast: vaildcast) -- Gets the position of an ActiveCast.

FastCast:SetVelocityCast(cast: vaildcast, velocity: Vector3) -- Sets the velocity of an ActiveCast to the specified Vector3.
FastCast:SetAccelerationCast(cast: vaildcast, acceleration: Vector3) -- Sets the acceleration of an ActiveCast to the specified Vector3.

FastCast:PauseCast(cast: vaildcast) -- Pauses simulation for an ActiveCast.
FastCast:ResumeCast(cast: vaildcast) -- Resumes simulation for an ActiveCast if it was paused previously.

FastCast:AddPositionCast(cast: vaildcast, position: Vector3) -- Add position to an ActiveCast with the specified Vector3.
FastCast:AddVelocityCast(cast: vaildcast, velocity: Vector3) -- Add velocity to an ActiveCast with the specified Vector3.
FastCast:AddAccelerationCast(cast: vaildcast, acceleration: Vector3) -- Add acceleration to an ActiveCast with the specified Vector3.

FastCast:SyncChangesToCast(cast: vaildcast) -- Synchronize new changes to the ActiveCast.
FastCast:TerminateCast(cast: vaildcast) -- Terminate function for casts

-- Field


```