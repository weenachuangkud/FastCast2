---
sidebar_position: 2
---

# Usage

Constructs a new Caster object.
```lua
local Caster = FastCast.new()
```

<br />

Initializes the Caster with the given parameters. This is required before firing using Raycasts in the Caster or nothing will happen!

```lua
Caster:Init(
  numWorkers: number,-- The number of worker VMs to create for this Caster. Must be greater than 1.
  newParent: Folder,-- The Folder in which to place the FastCastVMs Folder
  newName: string,-- The name to give the FastCastVMs Folder containing worker scripts.
  ContainerParent: Folder,-- The parent Folder in which to place the worker VM Containers.
  VMContainerName: Folder,-- The name to give to the Containers housing each worker VM.
  VMname: string,-- The name to give each worker VM.
  useBulkMoveTo: boolean,-- Whether to enable BulkMoveTo for the CosmeticBulletObjects
  FastCastEventsModule: ModuleScript,-- The ModuleScript containing the FastCastEvents, A table of callback functions (events/hooks) used by ActiveCast..
  useObjectCache: boolean,-- Whether to use ObjectCache for the Caster
  Template: BasePart | Model,-- The template object to use for the ObjectCache (if enabled)
  CacheSize: number,-- The size of the ObjectCache (if enabled)
  CacheHolder: Instance-- The Instance in which to place cached objects (if enabled)
) → ()
Initializes the Caster with the given parameters. This is required before firing using Raycasts in the Caster or nothing will happen!
```

<br />

Set the FastCastEventsModule for all BaseCasts created from this Caster.
```lua
Caster:SetFastCastEventsModule(
moduleScript: ModuleScript-- The FastCastEventsModule to set.
) → ()
```

<br />

Raycasts the Caster with the specified parameters.
```lua
Caster:RaycastFire(
  origin: Vector3,-- The origin of the raycast.
  direction: Vector3,-- The direction of the raycast.
  velocity: Vector3 | number,-- The velocity of the raycast.
  BehaviorData: FastCastBehavior?-- The behavior data for the raycast.
) → string-- The ActiveCast ID of the fired raycast.
```

<br />

Blockcasts the Caster with the specified parameters.
```lua
Caster:BlockcastFire(
  origin: Vector3,-- The origin of the blockcast.
  Size: Vector3,-- The size of the blockcast.
  direction: Vector3,-- The direction of the blockcast.
  velocity: Vector3 | number,-- The velocity of the raycast.
  BehaviorData: FastCastBehavior?-- The behavior data for the raycast.
) → string-- The ActiveCast ID of the fired raycast.
```

<br />

Gets the velocity of an ActiveCast.

```lua
Caster:GetVelocityCast(
  cast: ActiveCastCompement | ActiveBlockcastCompement-- Compement
) → Vector3-- The current velocity of the ActiveCast.
```

<br />

Gets the acceleration of an ActiveCast.
```lua
Caster:GetAccelerationCast(
  cast: ActiveCastCompement | ActiveBlockcastCompement-- Compement
) → Vector3-- The current acceleration of the ActiveCast.
```

<br />

Gets the position of an ActiveCast.
```lua
Caster:GetPositionCast(
  cast: ActiveCastCompement | ActiveBlockcastCompement-- Compement
) → Vector3-- The current position of the ActiveCast.
```

<br />

Sets the velocity of an ActiveCast to the specified Vector3.
```lua
Caster:SetVelocityCast(
  cast: ActiveCastCompement | ActiveBlockcastCompement,-- Compement
  velocity: Vector3-- The new velocity to set.
) → ()
```

For usage, please refer to the [API documentation](/api/FastCast#new)!
