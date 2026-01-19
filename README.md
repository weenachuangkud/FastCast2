<p align="center">
  <img width="500" height="225" alt="FastCast2CoverTrans" src="https://github.com/user-attachments/assets/dcb6f17c-0e3e-46c2-b694-432a6ef867ac" />
</p>

# FastCast2 (Unofficial) 
**An improved version of [FastCast](https://etithespir.it/FastCastAPIDocs/)**  
with **Parallel lua scripting**, **static typing**, **more extensions**, **built-in object pooling**

---

**FastCast2** It's a projectiles library powered by [VMsDispatcher](https://github.com/weenachuangkud/VMsDispatcher) meant to **simulate** projectiles without any **physic replication**

<br />

What the benefits of **using** FastCast2 :

* More customizable
* Able to communicate between the main thread and different threads, with more control over the thread (costs performance)
* Parallel scripting
* Easy to use
* Raycast, Blockcast support
* BulkMoveTo support
* Built-in ObjectCache
* Flexible

Follow on [FastCast2 devforum](https://devforum.roblox.com/t/fastcast2-an-improved-version-of-fastcast-with-parallel-scripting-more-extensions-and-statically-typed/4093890)

&nbsp;

> [!NOTE]
> - I still have not finished making the API Usage, README.md 100% yet

## How to install
1. Go to the toolbox 
<img width="43" height="51" alt="Screenshot 2026-01-04 012731" src="https://github.com/user-attachments/assets/41851631-06cf-4ab3-a2cc-d1af66c317ef" />

2. Inside the toolbox, model tab. Search for "FastCast2"
<img width="292" height="36" alt="Screenshot 2026-01-04 012824" src="https://github.com/user-attachments/assets/c1010991-f481-405d-b9e6-9230cd2104ac" />

3. You should see FastCast2 and then click it
<img width="275" height="330" alt="Screenshot 2026-01-04 012904" src="https://github.com/user-attachments/assets/d1252231-834a-4407-b2bb-facdd18ffd06" />

4. Make sure it's owned by "Mawin_CK"
<img width="109" height="51" alt="Screenshot 2026-01-04 012926" src="https://github.com/user-attachments/assets/b10dd12b-e389-41d7-b72f-1eb291c492f3" />

5. Insert into the studio
<img width="273" height="48" alt="Screenshot 2026-01-04 012943" src="https://github.com/user-attachments/assets/1586939e-1627-4b22-8a42-c1c149f54bf7" />

6. If you're seeing this. Click "OK"
<img width="494" height="150" alt="Screenshot 2026-01-04 013009" src="https://github.com/user-attachments/assets/87abd09c-69c8-4e77-8327-a3c192626de7" />

7. Now you will see "FastCast2" inside the workspace. Drag it into ReplicatedStorage
<img width="201" height="126" alt="Screenshot 2026-01-04 013047" src="https://github.com/user-attachments/assets/88ec449a-ee11-4930-8775-c9deb5453264" />

8. Make sure inside the FastCast2. The "ClientVM" and "ServerVM" path is correct
<img width="185" height="298" alt="Screenshot 2026-01-04 013134" src="https://github.com/user-attachments/assets/9910a3bd-1705-43ce-8c50-4cab0f096146" />
<img width="449" height="49" alt="Screenshot 2026-01-04 013203" src="https://github.com/user-attachments/assets/cf4355d9-9faf-432c-9fde-7ed9b8b1675b" />

9. Insert a part into the workspace and then rename it to "Projectile" and set its size to 1,1,1, and make sure "CanCollide", "CanQuery", "CanTouch" are all unmarked. And drag it into ReplicatedStorage
<img width="194" height="59" alt="Screenshot 2026-01-04 013358" src="https://github.com/user-attachments/assets/19be90fd-66ce-4cf5-849d-ab84d718edd8" />

(If you dont found FastCast2 in the toolbox, click this link: https://create.roblox.com/store/asset/87459814880446/FastCast2)

## Testing
- To test if FastCast2 actually works. Insert a "LocalScript" Inside "StarterCharacterScripts" and paste this code :

```lua
--[[
	- Author : Mawin_CK
	- Date : 2025
]]

-- Services
local Rep = game:GetService("ReplicatedStorage")
local RepFirst = game:GetService("ReplicatedFirst")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

-- Modules
local FastCast2ModuleScript = Rep:WaitForChild("FastCast2")

-- Requires
local FastCast2 = require(FastCast2ModuleScript)
local FastCastEnums = require(FastCast2ModuleScript:WaitForChild("FastCastEnums"))
local FastCastTypes = require(FastCast2ModuleScript:WaitForChild("TypeDefinitions"))

-- Variables
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local Head = character:WaitForChild("Head")

local Mouse = player:GetMouse()

local ProjectileTemplate = Rep:WaitForChild("Projectile")
local ProjectileContainer = workspace:FindFirstChild("Projectiles")

if not ProjectileContainer then
	ProjectileContainer = Instance.new("Folder")
	ProjectileContainer.Name = "Projectiles"
	ProjectileContainer.Parent = workspace
end

local debounce = false

-- CONSTANTS
local DEBOUNCE_TIME = 0.1
local SPEED = 75

-- CastParams
local CastParams = RaycastParams.new()
CastParams.FilterDescendantsInstances = {character}
CastParams.IgnoreWater = true
CastParams.FilterType = Enum.RaycastFilterType.Exclude

-- Behavior
local Behavior = FastCast2.newBehavior()
Behavior.RaycastParams = CastParams
Behavior.MaxDistance = 1000 -- Explicitly set the max distance
Behavior.HighFidelityBehavior = FastCastEnums.HighFidelityBehavior.Default
Behavior.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
Behavior.CosmeticBulletTemplate = ProjectileTemplate
Behavior.CosmeticBulletContainer = ProjectileContainer
Behavior.AutoIgnoreContainer = true
Behavior.UseLengthChanged = false

-- Caster
local Caster = FastCast2.new()
Caster:Init(
	4, -- Due to roblox limits :P
	RepFirst, -- Where cloned FastCastVMs will be parented to
	"CastVMs", -- New name of cloned FastCastVMs
	RepFirst, -- VMs Container
	"CastVMsContainer", -- Name of VMs Container
	"CastVM", -- Name of VMs
	true -- useBulkMoveTo
)

-- Event functions
local function OnRayHit(cast : FastCastTypes.ActiveCast)
	print("Hit")
	FastCast2:SafeCall(cast.Terminate)
end

local function OnCastTerminating(cast : FastCastTypes.ActiveCast)
	local obj = cast.RayInfo.CosmeticBulletObject
	if obj then
		obj:Destroy()
	end
end

-- Listeners

Caster.RayHit:Connect(OnRayHit)
Caster.CastTerminating:Connect(OnCastTerminating)

UIS.InputBegan:Connect(function(input : InputObject, gp : boolean)
	if gp then return end
	if debounce then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local Origin = Head.Position
		local Direction = (Mouse.Hit.Position - Origin).Unit
		
		Caster:RaycastFire(Origin, Direction, SPEED, Behavior)
		
		debounce = true
		task.wait(DEBOUNCE_TIME)
		debounce = false
	end
end)
```
- Or you can get FastCast2 testing ground from : https://github.com/weenachuangkud/FastCast2/releases

# API Usages

## Caster Methods

```lua
FastCast.new()
```
Construct a new Caster instance

<br />
<br />

```lua
FastCast:Init(
	numWorkers : number, 
	newParent : Folder, 
	newName : string,
	ContainerParent : Folder,
	VMContainerName : string,
	VMname : string,
	
	useBulkMoveTo : boolean,

	useObjectCache : boolean,
	Template : BasePart | Model,
	CacheSize : number,
	CacheHolder : Instance
)
```
Initialize Caster. Allocate the worker amount of `numWorkers`, rename it to `VMname`, clone `FastCastVMs` to `newParent`, rename it to `newName` , and then create a VMsContainer which is a container of workers, set its parent to `ContainerParent`, and rename it to `VMContainerName`
- useBulkMoveTo: if true, will enable BulkMoveTo to handle CFrame changes for every `ActiveCast.RayInfo.CosmeticBulletObject`. Can be disabled and enabled by `Caster:BindBulkMoveTo(boolean)`
- useObjectCache: if true, will permanently use ObjectCache for Caster

<br />
<br />

```lua
FastCast:SafeCall(f : (...any) -> (...any), ...)
```
Call the passed-in function if it exists

<br />
<br />

```lua
FastCast:BindBulkMoveTo(bool : boolean)
```
Enable or disable `BulkMoveTo` for `Caster`

<br />
<br />

```lua
FastCast:ReturnObject(obj : Instance)
```
Return passed-in `obj` to `ObjectCache`

<br />
<br />

```lua
FastCast:Destroy()
```
Destroy Caster

<br />
<br />

```lua
FastCast:RaycastFire(origin: Vector3, direction: Vector3, velocity: Vector3 | number, BehaviorData: TypeDef.FastCastBehavior?)
```
Create a new `ActiveCast`; it will not work if the `Caster` has not initialized

<br />
<br />

```lua
FastCast:BlockcastFire(origin : Vector3, Size : Vector3, direction : Vector3, velocity : Vector3 | number, BehaviorData: TypeDef.FastCastBehavior?)
```
Create a new `ActiveBlockCast`; it will not work if the `Caster` has not initialized

## Caster Signals

```lua
Caster.RayHit(ActiveCast, RaycastResult, segmentVelocity : Vector3, cosmeticBulletObject : Instance?)
```
Fires every RayHit 

<br />
<br />

```lua
Caster.RayPierceFunction(ActiveCast, RaycastResult, segmentVelocity : Vector3, cosmeticBulletObject : Instance?)
```
Fires every RayPierceFunction

<br />
<br />

```lua
Caster.LengthChanged(ActiveCast,lastPoint : Vector3, rayDir : Vector3, rayDisplacement : number, segmentVelocity : Vector3, cosmeticBulletObject : Instance?)
```
Fires every LengthChanged

<br />
<br />

```lua
Caster.CastTerminating(ActiveCast)
```
Fires every CastTerminating

<br />
<br />

```lua
Caster.CastFire(ActiveCast, Origin : Vector3, Direction : Vector3, Velocity : Vector3, behavior : FastCastBehavior)
```
Fires if `ActiveCast` is created successfully before the RunService

# SPECIAL THANKS TO
- @avibah On Discord: **For helping me make VMDispatcher**
- @ace9b472eeec4f53ba9e8d91bo87c636 On Discord: **For advice/ideas**

