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
FastCast:SetFastCastEventsModule(
moduleScript: ModuleScript-- The FastCastEventsModule to set.
) → ()
```

For usage, please refer to the [API documentation](/api/FastCast#new)!
