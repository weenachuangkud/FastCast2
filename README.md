# FastCast2
An improved version of FastCast with Parallel scripting, more extensions, and statically typed

> [!NOTE]
> - I still have not finished making the API Usage, README.md
> - This library is still in development and consistently improving 

## How to install

1. Go to https://create.roblox.com/store/asset/87459814880446/FastCast2
2. Get the module
3. Go to the Roblox Studio
4. Click "Toolbox"
5. In the Toolbox, click Inventory. The module should be in "My Models"
6. Once you have found it, click it, and now it will be inserted in the workspace. You can put it in any folder
7. Inside FastCast2, go to FastCastVMs, inside the ClientVM and the ServerVM, you can see a comment telling you to replace the highlighted warning line with the correct path.
8. Enjoy

https://github.com/user-attachments/assets/157b0829-b56a-48c8-ad08-bb37dd8c3215

## How to set up (Basic example)

1. **In StarterCharacterScripts, insert a LocalScript, rename it to anything**

2. **Inside the LocalScript, require the FastCast2**
```luau
local FastCast = require(PathTo.FastCastModule)
```

3. **Create a behavior**
```luau
local CastParams = RaycastParams.new()
CastParams.FilterType = Enum.RaycastFilterType.Exclude
CastParams.FilterDescendantsInstances = {character}
CastParams.IgnoreWater = true

local behavior = FastCast.newBehavior()
behavior.RaycastParams = CastParams
behavior.CosmeticBulletTemplate = BulletTemplate
behavior.CosmeticBulletContainer = ProjectileContainer
behavior.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
behavior.AutoIgnoreContainer = true
```

4. **Create Caster and initialize**
```luau
local Caster = FastCast.new()
Caster:Init(
	12, -- numWorkers
	player, -- Where VMs Stored
	"CastVMs", -- Name of VMs
	CastVMsContainer, -- Where workers stored
	"VMsContainer", -- Name Folder of workerFolder
	"CastWorkers" -- Name of workers
)
```

5. **Connecting events**
```luau
-- Local functions
local function OnRayHit(
	ActiveCast, 
	resultOfCast : RaycastResult, 
	segmentVelocity : Vector3, 
	segmentAcceleration : Vector3, 
	cosmeticBulletObject : Instance?
)
	FastCast:SafeCall(ActiveCast.Terminate)
end

local function OnLengthChanged(
	ActiveCast, 
	lastPoint : Vector3, 
	rayDir : Vector3, 
	rayDisplacement : number, 
	segmentVelocity : Vector3, 
	cosmeticBulletObject : Instance?
)
	if cosmeticBulletObject then
		cosmeticBulletObject.CFrame = CFrame.new(lastPoint, lastPoint + rayDir) * CFrame.new(0, 0, -rayDisplacement / 2)
	end
end

local function OnCastTerminating(cast)
	if cast.RayInfo.CosmeticBulletObject then
		cast.RayInfo.CosmeticBulletObject:Destroy()
		cast.RayInfo.CosmeticBulletObject = nil
	end
end

-- Listeners
Caster.LengthChanged:Connect(OnLengthChanged)
Caster.CastTerminating:Connect(OnCastTerminating)
Caster.RayHit:Connect(OnRayHit)
```

6. Enjoy, see more [samples](https://github.com/weenachuangkud/FastCast2/tree/main/samples)

# API Usages

## Constructor
> [!warning]
> Do not create a new caster every time your weapon fires! This is a common mistake people make. Doing this will cause severe performance problems and unexpected behavior in the  module.\
> Remember - A caster is like a gun. Creating a caster every time the weapon is fired is like buying a new gun every time you want to fire a bullet.

```luau
FastCast.new()
```

Construct a new **Caster** instance, which represents an entire gun or other projectile launching system.


```luau
FastCast.newBehavior()
```

Creates a new **FastCastBehavior**, which contains information necessary to fire the cast properly.

## Methods

```luau
FastCast:Init(
	numWorkers : number,
	newParent : Folder,
	newName : string,
	ContainerParent : Folder,
	VMContainerName : string,
	VMname : string,

	useObjectCache : boolean,
	Template : BasePart | Model,
	CacheSize : number,
	CacheHolder : Instance
)
```

Initialize the **Caster** instance and then create a copy of **FastCastVMs**\
Set its Parent to the specified **newParent**, and rename it to the specified **newName**
and then create a Folder which is a Container of workers, rename it specified **VMContainerName**
Clone the number of workers specified by **numWorkers**, and rename all cloned workers to **VMname**

**Built-in object pool:** if **useObjectCache** is true, then create an ObjectPool instance, and create a clone **Template** amount of specified **CacheSize**, set its Parent to ContainerFolder that is Parented to specified **CacheHolder** instance

```luau
FastCast:RaycastFire(
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	BehaviorData: FastCastBehavior?
)
```

Dispatch a **Raycast** task to the **workers**

```luau
FastCast:BlockcastFire(
	origin : Vector3,
	Size : Vector3,
	direction : Vector3,
	velocity : Vector3 | number,
	BehaviorData: TypeDef.FastCastBehavior?
)
```

Dispatch a **Blockcast** task to the **workers**

```luau
FastCast:SafeCall(f : (...any) -> (...any), ...)
```

Attempt to call the passed-in function with arguments... if it exists, otherwise pass

```luau
FastCast:SetVisualizeCasts(bool : boolean)
```

Set **VisualizeCasts** to the specified boolean

```luau
FastCast:ReturnObject(obj : Instance)
```

Return passed-in **obj** to **ObjectCache** if it is a valid **obj** instance from ObjectCache, otherwise do nothing
> [!warning]
> You must **useObjectCache** when initializing, or else you will get an error

```luau
FastCast:Destroy()
```
Destroy **Caster** instance, which includes: **ObjectCache**, **Dispatcher**

## Properties

## WorldRoot
The target **WorldRoot** that this Caster runs in by default. Its default value is **workspace**.
> [!NOTE]
> Changing this value will not update any existing ActiveCasts during runtime.
> When an ActiveCast is instantiated by a Caster, it looks at this property to see what it should set its own WorldRoot property to (see CastRayInfo), and then from there onward, it uses its own property to determine where to simulate.

## Events

```luau
LengthChanged:Connect(
	ActiveCast : ActiveCast,
	lastPoint : Vector3,
	rayDir : Vector3,
	displacement : Vector3,
	segmentVelocity : Vector3,
	cosmeticBulletObject : Instance?
)
```
Safety level: **intermediate**

This event fires every time any ray fired by this **Caster** updates and moves
- **lastPoint** parameter is the point the ray was at before it was moved
- **rayDir** represents the direction of movement, and displacement represents how far it moved in that direction. To calculate the current point, use **lastPoint + (rayDir * displacement)**
- **segmentVelocity** represents the velocity of the bullet at the time this event fired.
- **cosmeticBulletObject** is a reference to the cosmetic bullet passed into the Fire method (or nil if no such object was passed in)

```luau
RayHit:Connect(
	ActiveCast : ActiveCast,
	result : RaycastResult,
	segmentVelocity : Vector3,
	cosmeticBulletObject : Instance?
```
This event fires when any ray fired by this **Caster** runs into something and will be subsequently terminated
-  **ActiveCast** that fired this event
-  **RaycastResult** is the result of the ray that caused this hit to occur
> [!NOTE]
> The **RaycastResult** passed into this event will never be nil.
-  **segmentVelocity** is the velocity of the bullet at the time of the hit
-  **cosmeticBulletObject** is a reference to the passed-in cosmetic bullet. This will not fire if the ray hits nothing and instead reaches its maximum distance.

# API Examples

Function are **unsafe**?, use `Caster:SafeCall(f : (...any) -> (...any), ...)`\
**Q:** How do you know that the function is not safe to call?\
**A:** You're going to run the game first, to test if it will throw an error at you or not\
If so, meaning, the functions are **unsafe**\
**Q:** Why It's **unsafe** in this example?\
**A:** Because it attempts to call a nil (function does not exist, even though it should)
```luau
local function OnRayHit(
	ActiveCast : TypeDef.ActiveCast, 
	resultOfCast : RaycastResult, 
	segmentVelocity : Vector3, 
	segmentAcceleration : Vector3, 
	cosmeticBulletObject : Instance?
)
	FastCast:SafeCall(ActiveCast.Terminate)
end
```
