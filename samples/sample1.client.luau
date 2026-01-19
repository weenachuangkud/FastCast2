--[[
	- Author :  Mawin CK
	- Date : 2025
]]

-- Services
local Rep = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

-- Modules
local GunEngine = Rep:WaitForChild("Gun_Engine")
local Modules = GunEngine:WaitForChild("Modules")
local Libraries = Modules:WaitForChild("Libraries")

local FastCastModule = Libraries:WaitForChild("FastCast2")

-- Requires
local TypeDef = require(FastCastModule:WaitForChild("TypeDefinitions"))
local FastCast = require(FastCastModule)

-- Assets
local Assets = GunEngine:WaitForChild("Assets")
local ModelAssets = Assets:WaitForChild("Models")
local ProjectileAssets = ModelAssets:WaitForChild("Projectiles")
local GenericBulletAssets = ProjectileAssets:WaitForChild("Generic")
local BulletTemplate = GenericBulletAssets:WaitForChild("BulletProjectile")

-- Variables
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local character = player.Character or player.CharacterAdded:Wait()
local OriginPart = character:WaitForChild("Head")

local SPEED = 45

-- Test

local CastParams = RaycastParams.new()
CastParams.FilterType = Enum.RaycastFilterType.Exclude
CastParams.FilterDescendantsInstances = {character}
CastParams.IgnoreWater = true

local behavior = FastCast.newBehavior()
behavior.RaycastParams = CastParams
behavior.CosmeticBulletTemplate = BulletTemplate
behavior.CosmeticBulletContainer = workspace.Projectiles
behavior.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
behavior.AutoIgnoreContainer = true

--local EventDef = {}

--EventDef.OnLengthChanged = OnLengthChanged
--EventDef.OnCastTerminating = OnTerminated
--EventDef.OnRayHit = OnRayHit


local Caster = FastCast.new()
Caster:Init(
	12, -- numWorkers
	player, -- Where VMs Stored
	"CastVMs", -- Name of VMs
	game:GetService("ReplicatedFirst").CastVMsContainer, -- Where workers stored
	"VMsContainer", -- Name Folder of workerFolder
	"CastWorkers" -- Name of workers
)

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

-- TEST 1 : Basic Fire

--[[UIS.InputBegan:Connect(function(input : InputObject, gp : boolean)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local origin = OriginPart.Position
		local direction = (mouse.Hit.Position - origin).Unit
		--VisualPoint(direction)
		Caster:RaycastFire(origin, direction, SPEED, behavior)
	end
end)]]

local targetPos = Vector3.new(0, 5, 0)

task.spawn(function()
	while Caster do 
		local origin = OriginPart.Position
		local direction = (targetPos - origin).Unit
		FastCast:SafeCall(Caster.RaycastFire, Caster, origin, direction, SPEED, behavior)
		task.wait()
	end
end)

task.wait(100)
print("CLEAN UP")
Caster:Destroy()
