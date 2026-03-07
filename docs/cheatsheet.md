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
FastCast:RaycastFire(origin: Vector3, direction: Vector3, velocity: Vector3 | number, BehaviorData: FastCastBehavior?) → () -- Raycasts the Caster with the specified parameters.
FastCast:BlockcastFire(origin: Vector3, Size: Vector3, direction: Vector3, velocity: Vector3 | number, BehaviorData: FastCastBehavior?) -> () -- Blockcasts the Caster with the specified parameters.
FastCast:SpherecastFire(origin: Vector3, Radius: number, direction: Vector3, velocity: Vector3 | number, BehaviorData: TypeDef.FastCastBehavior? ) -> () -- Spherecasts the Caster with the specified parameters.

FastCast:SetFastCastEventsModule(moduleScript: ModuleScript) → () -- Set the FastCastEventsModule for all BaseCasts created from this Caster.



```