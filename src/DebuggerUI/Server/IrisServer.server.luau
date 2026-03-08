-- Services
local Rep = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

-- Modules
local FastCast2 = Rep:WaitForChild("FastCast2")

-- Requires
local FastCastM = require(FastCast2)
local FastCastTypes = require(FastCast2:WaitForChild("TypeDefinitions"))
local Jolt = require(Rep:WaitForChild("Jolt"))

-- Types
type RequestLogDataType = "FastCastBehavior" | "Setting"

-- Variables
local currentVelocity = 50
local ServerProjectileLimit = 1000
local scriptController: LocalScript = nil

local debounce_lc = false
local debounce_lc_time = 1.5

local ServerProjectileCount = 0

-- Events
local CastBehaviorServerUpdate = Jolt.Server("CastBehaviorServerUpdate") :: Jolt.Server<FastCastTypes.FastCastBehavior>
local LoggingServer = Jolt.Server("LoggingServer") :: Jolt.Server<RequestLogDataType>
local ServerSettingUpdate = Jolt.Server("ServerSettingUpdate") :: Jolt.Server<{velocity: number, projectileLimit: number}>
local ServerProjectile = Jolt.Server("ServerProjectile") :: Jolt.Server<Vector3, Vector3, number>
local ServerProjectileCountEvent = Jolt.Server("ServerProjectileCount") :: Jolt.Server<number>
local ServerCastModuleUpdate = Jolt.Server("ServerCastModuleUpdate") :: Jolt.Server<ModuleScript>


-- Behavior
local CastBehaviorServer: FastCastTypes.FastCastBehavior = FastCastM.newBehavior()
CastBehaviorServer.VisualizeCasts = false -- Explictly set to false to avoid confusion.
CastBehaviorServer.Acceleration = Vector3.new()
CastBehaviorServer.AutoIgnoreContainer = true
CastBehaviorServer.MaxDistance = 1000
CastBehaviorServer.HighFidelitySegmentSize = 1

CastBehaviorServer.FastCastEventsConfig = {
	UseLengthChanged = false,
	UseRayHit = true,
	UseCastTerminating = true,
	UseCastFire = false,
	UseRayPierced = false
}

CastBehaviorServer.FastCastEventsModuleConfig = {
	UseLengthChanged = false,
	UseRayHit = true,
	UseCastTerminating = true,
	UseCastFire = false,
	UseRayPierced = false,
	UseCanRayPierce = false
}

-- Local functions

local function IntCount(amount: number)
	ServerProjectileCount += amount
	ServerProjectileCountEvent:FireAllUnreliable(ServerProjectileCount)
end

-- Caster
local Caster = FastCastM.new()
Caster:Init(
	4,
	SSS,
	"CastVMs",
	SSS,
	"VMContainer",
	"CastVM"
)

Caster.CastTerminating = function()
	IntCount(-1)	
end
Caster.CastFire = function()
	print("CastFire Test!")
end
Caster.Hit = function(cast, result)
	print("RayHit Test!")
end
Caster.LengthChanged = function()
	if not debounce_lc then
		debounce_lc = true
		print("OnLengthChanged Test!")
		task.delay(debounce_lc_time, function()
			debounce_lc = false
		end)
	end
end
Caster.Pierced = function()
	print("Ray pierced Test!")
end

-- Connections

LoggingServer:Connect(function(player: Player, RequestLogDataType: RequestLogDataType)
	if RequestLogDataType == "FastCastBehavior" then
		print(CastBehaviorServer)
	end
	
	if RequestLogDataType == "Setting" then
		print({
			velocity = currentVelocity,
			projectileLimit = ServerProjectileLimit
		})
	end
end)

CastBehaviorServerUpdate:Connect(function(player: Player, newBehavior: FastCastTypes.FastCastBehavior)
	for key, value in newBehavior do
		CastBehaviorServer[key] = value
	end
	if CastBehaviorServer.CosmeticBulletTemplate then
		CastBehaviorServer.CosmeticBulletTemplate = nil
	end
	if not CastBehaviorServer.RaycastParams then
		local CastParams = RaycastParams.new()
		CastParams.IgnoreWater = true
		CastParams.FilterType = Enum.RaycastFilterType.Exclude
		CastParams.FilterDescendantsInstances = {player.Character, workspace:WaitForChild("Projectiles")}
	end
end)

ServerSettingUpdate:Connect(function(player: Player, data)
	currentVelocity = data.velocity
	ServerProjectileLimit = data.projectileLimit
end)

ServerProjectile:Connect(function(player: Player, Origin: Vector3, Direction: Vector3, velocity: number?)
	if ServerProjectileCount >= ServerProjectileLimit then
		return
	end
	Caster:RaycastFire(Origin, Direction, velocity or currentVelocity, CastBehaviorServer)
	IntCount(1)
end)

ServerCastModuleUpdate:Connect(function(player: Player, moduleScript: ModuleScript)
	Caster:SetFastCastEventsModule(moduleScript)
end)