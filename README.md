# FastCast2
An improved version of FastCast with Parallel scripting, more extensions, and statically typed

> [!NOTE]
> I still have not finished making the API Usage, README.md

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
	game:GetService("ReplicatedFirst").CastVMsContainer, -- Where workers stored
	"VMsContainer", -- Name Folder of workerFolder
	"CastWorkers" -- Name of workers
)
```

5. **Connecting events**
```luau
-- Local functions
local function OnRayHit(
	ActiveCast : TypeDef.ActiveCast, 
	resultOfCast : RaycastResult, 
	segmentVelocity : Vector3, 
	segmentAcceleration : Vector3, 
	cosmeticBulletObject : Instance?
)
	FastCast:SafeCall(ActiveCast.Terminate)
end

local function OnLengthChanged(
	ActiveCast : TypeDef.ActiveCast, 
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

local function OnCastTerminating(cast : TypeDef.ActiveCast)
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

## API Usages/Examples

Function are **unsafe**?, use `Caster:SafeCall(f : (...any) -> (...any), ...)`\
**Q:** How do you know that the function is not safe to call?\
**A:** You're going to run the game first, to test if it will throw an error at you or not\
If so, meaning, the functions are **unsafe**
**Q:** Why It's **unsafe** in this example?
**A:** Because it attempts to call a nil (function does not exist, nil)
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
