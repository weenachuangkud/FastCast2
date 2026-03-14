--[[
	Author: Mawin_CK
	Date: 2025
	Note: Studio DebuggerUI server script.
]]

-- Services
local Rep = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- Modules
local FastCast2 = Rep:WaitForChild("FastCast2")
local FastCastM = require(FastCast2)
local FastCastTypes = require(FastCast2:WaitForChild("TypeDefinitions"))
local Jolt = require(Rep:WaitForChild("Jolt"))
local RemoteTable = require(Rep:WaitForChild("RemoteTableLight")).Server

-- ============================================================
-- Types
-- ============================================================

type LogRequest = "FastCastBehavior" | "Setting"

type DebuggerState = {
	velocity: number,
	projectileLimit: number,
	projectileCount: number,
}

-- ============================================================
-- Constants
-- ============================================================

local DEBOUNCE_LC_TIME = 1.5
local DEBUGGER_TOKEN = "DebuggerState"

-- ============================================================
-- State
-- ============================================================

local state: DebuggerState = {
	velocity = 50,
	projectileLimit = 1000,
	projectileCount = 0,
}

-- ============================================================
-- RemoteTable — server → client state sync
-- ============================================================

local debuggerData = RemoteTable.Create(DEBUGGER_TOKEN, state)

local function setState(key: string, value: any)
	state[key] = value
	RemoteTable.Set(debuggerData, key, value)
end

-- ============================================================
-- Behavior
-- ============================================================

local CastBehaviorServer: FastCastTypes.FastCastBehavior = FastCastM.newBehavior()
CastBehaviorServer.VisualizeCasts = false
CastBehaviorServer.Acceleration = Vector3.new()
CastBehaviorServer.AutoIgnoreContainer = true
CastBehaviorServer.MaxDistance = 1000
CastBehaviorServer.HighFidelitySegmentSize = 1

CastBehaviorServer.FastCastEventsConfig = {
	UseLengthChanged = false,
	UseRayHit = true,
	UseCastTerminating = true,
	UseCastFire = false,
	UseRayPierced = false,
}

CastBehaviorServer.FastCastEventsModuleConfig = {
	UseLengthChanged = false,
	UseRayHit = true,
	UseCastTerminating = true,
	UseCastFire = false,
	UseRayPierced = false,
	UseCanRayPierce = false,
}

-- ============================================================
-- Caster
-- ============================================================

local Caster = FastCastM.new()
Caster:Init(4, SSS, "CastVMs", SSS, "VMContainer", "CastVM")

local debounce_lc = false

Caster.CastTerminating = function()
	setState("projectileCount", state.projectileCount - 1)
end

Caster.CastFire = function()
	print("[IrisServer] CastFire")
end

Caster.Hit = function(_cast: FastCastTypes.ActiveCastCompement, _result: RaycastResult)
	print("[IrisServer] RayHit")
end

Caster.LengthChanged = function()
	if debounce_lc then return end
	debounce_lc = true
	print("[IrisServer] LengthChanged")
	task.delay(DEBOUNCE_LC_TIME, function()
		debounce_lc = false
	end)
end

Caster.Pierced = function()
	print("[IrisServer] Pierced")
end

-- ============================================================
-- Jolt Events (client → server commands)
-- ============================================================

local CastBehaviorServerUpdate = Jolt.Server("CastBehaviorServerUpdate") :: Jolt.Server<FastCastTypes.FastCastBehavior>
local LoggingServer            = Jolt.Server("LoggingServer")            :: Jolt.Server<LogRequest>
local ServerSettingUpdate      = Jolt.Server("ServerSettingUpdate")      :: Jolt.Server<{ velocity: number, projectileLimit: number }>
local ServerProjectile         = Jolt.Server("ServerProjectile")         :: Jolt.Server<Vector3, Vector3, number>
local ServerCastModuleUpdate   = Jolt.Server("ServerCastModuleUpdate")   :: Jolt.Server<ModuleScript>

-- ============================================================
-- Connections
-- ============================================================

LoggingServer:Connect(function(_player: Player, request: LogRequest)
	if request == "FastCastBehavior" then
		print("[IrisServer] CastBehaviorServer:", CastBehaviorServer)
	elseif request == "Setting" then
		print("[IrisServer] Settings:", {
			velocity = state.velocity,
			projectileLimit = state.projectileLimit,
		})
	end
end)

CastBehaviorServerUpdate:Connect(function(player: Player, newBehavior: FastCastTypes.FastCastBehavior)
	for key, value in newBehavior do
		CastBehaviorServer[key] = value
	end

	-- Server never uses a cosmetic template
	CastBehaviorServer.CosmeticBulletTemplate = nil

	-- Always ensure valid RaycastParams exist
	if not CastBehaviorServer.RaycastParams then
		local castParams = RaycastParams.new()
		castParams.IgnoreWater = true
		castParams.FilterType = Enum.RaycastFilterType.Exclude
		castParams.FilterDescendantsInstances = {
			player.Character :: any,
			workspace:WaitForChild("Projectiles"),
		}
		CastBehaviorServer.RaycastParams = castParams -- was missing in original!
	end
end)

ServerSettingUpdate:Connect(function(_player: Player, data: { velocity: number, projectileLimit: number })
	setState("velocity", data.velocity)
	setState("projectileLimit", data.projectileLimit)
end)

ServerProjectile:Connect(function(_player: Player, origin: Vector3, direction: Vector3, velocity: number?)
	if state.projectileCount >= state.projectileLimit then return end
	Caster:RaycastFire(origin, direction, velocity or state.velocity, CastBehaviorServer)
	setState("projectileCount", state.projectileCount + 1)
end)

ServerCastModuleUpdate:Connect(function(_player: Player, moduleScript: ModuleScript)
	Caster:SetFastCastEventsModule(moduleScript)
end)

-- ============================================================
-- Player lifecycle — grant / revoke RemoteTable access
-- ============================================================

local function onPlayerAdded(player: Player)
	RemoteTable.AddClient(DEBUGGER_TOKEN, player)
end

local function onPlayerRemoving(player: Player)
	RemoteTable.RemoveClient(DEBUGGER_TOKEN, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Catch players who joined before this script ran
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
