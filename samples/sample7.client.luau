--[[
	- Author :  Mawin CK
	- Date : 2025
]]

-- Services
local Rep = game:GetService("ReplicatedStorage")
local RepFirst = game:GetService("ReplicatedFirst")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

-- Module
local FastCastModule = Rep:WaitForChild("FastCast2")

-- Requires
local TypeDef = require(FastCastModule:WaitForChild("TypeDefinitions"))
local FastCast = require(FastCastModule)

-- Projectile
local ProjectileTemplate = Rep:WaitForChild("Projectile")

-- Variables
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local character = player.Character or player.CharacterAdded:Wait()
local OriginPart = character:WaitForChild("Head")

-- CONSTs
local SPEED = 720

-- Params

local CastParams = RaycastParams.new()
CastParams.FilterType = Enum.RaycastFilterType.Exclude
CastParams.FilterDescendantsInstances = {character}
CastParams.IgnoreWater = true

-- Behavior

local behavior = FastCast.newBehavior()
behavior.RaycastParams = CastParams
behavior.CosmeticBulletTemplate = ProjectileTemplate
behavior.CosmeticBulletContainer = workspace.Projectiles
behavior.Acceleration = Vector3.new(0, -workspace.Gravity/2, 0)
behavior.AutoIgnoreContainer = true

-- Caster

local Caster = FastCast.new()
-- Due to roblox limits worker to 4
Caster:Init(
	4, -- numWorkers
	player, -- Where VMs Stored
	"CastVMs", -- Name of VMs
	RepFirst, -- Where workers stored
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

UIS.InputBegan:Connect(function(input : InputObject, gp : boolean)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local origin = OriginPart.Position
		local direction = (mouse.Hit.Position - origin).Unit
		Caster:RaycastFire(origin, direction, SPEED, behavior)
	end
end)
