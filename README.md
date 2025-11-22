# FastCast2
An improved version of FastCast with Parallel scripting, more extensions, and statically typed

## How to setup (Basic)

1. Create a behavior
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

2. Create Caster and initialize
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

3. Connecting events
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

4. Enjoy, see more [samples](https://github.com/weenachuangkud/FastCast2/tree/main/samples)
