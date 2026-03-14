--!strict
--[[
	Author: Mawin_CK
	Date: 2025
	Note: Studio DebuggerUI only. Published UI is separate.
]]

-- TODO: Add blockcast support

-- Services
local Rep = game:GetService("ReplicatedStorage")
local RepFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Modules
local FastCast2 = Rep:WaitForChild("FastCast2")
local FastCastM = require(FastCast2)
local FastCastTypes = require(FastCast2:WaitForChild("TypeDefinitions"))
local Jolt = require(Rep:WaitForChild("Jolt"))
local Signal = require(FastCast2:WaitForChild("Signal"))
local iris = require(Rep:WaitForChild("iris"))
local RemoteTable = require(Rep:WaitForChild("RemoteTableLight")).Client

-- ============================================================
-- Types
-- ============================================================

type CastType = "Raycast" | "Blockcast" | "Spherecast"

-- ============================================================
-- Constants
-- ============================================================

local DEBOUNCE_LC_TIME = 1.5
local DEFAULT_CACHE_SIZE = 1000
local DEBUGGER_TOKEN = "DebuggerState"

local HIGH_FIDELITY_NAMES = {
	[1] = "Default",
	[2] = "Automatic",
	[3] = "Always",
}

local CAST_TYPES: { CastType } = { "Raycast", "Blockcast", "Spherecast" }

-- ============================================================
-- Player / Character
-- ============================================================

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- ============================================================
-- Assets
-- ============================================================

local ProjectileContainer = workspace:WaitForChild("Projectiles")
local ProjectileTemplate = Rep:WaitForChild("Projectile")

-- ============================================================
-- External Modules (Tests & FastCastEventsModules)
-- ============================================================

local TestModules: { [string]: any } = {}
for _, mod: ModuleScript in Rep:WaitForChild("Tests"):GetChildren() do
	TestModules[mod.Name] = require(mod) :: any
end

local FastCastEventsModules: { [string]: ModuleScript } = {}
for _, mod in Rep:WaitForChild("FastCastEventsModules"):GetChildren() do
	FastCastEventsModules[mod.Name] = mod :: ModuleScript
end

-- ============================================================
-- Jolt Events (client → server)
-- ============================================================

local CastBehaviorServerUpdate = Jolt.Client("CastBehaviorServerUpdate") :: Jolt.Client<FastCastTypes.FastCastBehavior>
local LoggingServer            = Jolt.Client("LoggingServer")            :: Jolt.Client<string>
local ServerSettingUpdate      = Jolt.Client("ServerSettingUpdate")      :: Jolt.Client<{ velocity: number, projectileLimit: number }>
local ServerProjectile         = Jolt.Client("ServerProjectile")         :: Jolt.Client<Vector3, Vector3, number>
local ServerCastModuleUpdate   = Jolt.Client("ServerCastModuleUpdate")   :: Jolt.Client<ModuleScript>

-- ============================================================
-- RemoteTable — live server state (replaces ServerProjectileCountEvent)
-- ============================================================

local serverState = RemoteTable.WaitForTable(DEBUGGER_TOKEN, 10)
if not serverState then
	warn("[IrisLocal] Timed out waiting for DebuggerState RemoteTable.")
end

-- ============================================================
-- CastParams
-- ============================================================

local CastParams = RaycastParams.new()
CastParams.FilterDescendantsInstances = { character }
CastParams.FilterType = Enum.RaycastFilterType.Exclude
CastParams.IgnoreWater = true

-- ============================================================
-- Behavior
-- ============================================================

local CastBehaviorClient: FastCastTypes.FastCastBehavior = FastCastM.newBehavior()
CastBehaviorClient.RaycastParams = CastParams
CastBehaviorClient.VisualizeCasts = false
CastBehaviorClient.Acceleration = Vector3.new()
CastBehaviorClient.AutoIgnoreContainer = true
CastBehaviorClient.MaxDistance = 1000
CastBehaviorClient.HighFidelitySegmentSize = 1
CastBehaviorClient.CosmeticBulletContainer = ProjectileContainer
CastBehaviorClient.CosmeticBulletTemplate = ProjectileTemplate
CastBehaviorClient.SimulateAfterPhysic = true

CastBehaviorClient.FastCastEventsConfig = {
	UseLengthChanged = false,
	UseHit = false,
	UseCastTerminating = true,
	UseCastFire = false,
	UsePierced = false,
}

CastBehaviorClient.FastCastEventsModuleConfig = {
	UseLengthChanged = false,
	UseHit = false,
	UseCastTerminating = true,
	UseCastFire = false,
	UsePierced = false,
	UseCanPierce = false,
}

-- ============================================================
-- Caster
-- ============================================================

local Caster = FastCastM.new()
Caster:Init(4, RepFirst, "CastVMs", RepFirst, "VMContainer", "CastVM", true)

local debounce_lc = false
local ClientProjectileCount = 0

local IntCountEvent = Signal.new()
IntCountEvent:Connect(function(amount: number)
	ClientProjectileCount += amount
end)

local function onCastTerminating(cast: FastCastTypes.ActiveCastCompement)
	local obj = cast.RayInfo.CosmeticBulletObject
	if obj then obj:Destroy() end
	ClientProjectileCount -= 1
end

local function onCastTerminatingObjectCache(cast: FastCastTypes.ActiveCastCompement)
	local obj = cast.RayInfo.CosmeticBulletObject
	if obj then Caster.ObjectCache:ReturnObject(obj) end
	ClientProjectileCount -= 1
end

Caster.CastTerminating = onCastTerminating
Caster.CastFire = function() print("[IrisLocal] CastFire") end
Caster.Hit = function() print("[IrisLocal] Hit") end
Caster.LengthChanged = function()
	if debounce_lc then return end
	debounce_lc = true
	print("[IrisLocal] LengthChanged")
	task.delay(DEBOUNCE_LC_TIME, function() debounce_lc = false end)
end
Caster.Pierced = function() print("[IrisLocal] Pierced") end

-- ============================================================
-- Iris States
-- ============================================================

-- Window
local WindowSize    = iris.State(Vector2.new(500, 400))
local WindowVisible = iris.State(true)

-- Behavior
local SelectedBehavior             = iris.State(CastBehaviorClient.HighFidelityBehavior)
local AccelerationState            = iris.State(CastBehaviorClient.Acceleration)
local AutoIgnoreContainerState     = iris.State(CastBehaviorClient.AutoIgnoreContainer)
local MaxDistanceState             = iris.State(CastBehaviorClient.MaxDistance)
local VisualizeCastsState          = iris.State(CastBehaviorClient.VisualizeCasts)
local HighFidelitySegmentSizeState = iris.State(CastBehaviorClient.HighFidelitySegmentSize)
local UseCosmeticBulletTemplate    = iris.State(true)
local SimulateAfterPhysicState     = iris.State(CastBehaviorClient.SimulateAfterPhysic)
local AutomaticPerformanceState    = iris.State(true)

-- Settings
local VelocityValue            = iris.State(50)
local ClientProjectileLimitValue = iris.State(1000)
local CastTypeState            = iris.State("Raycast")
local BlockSizeState           = iris.State(Vector3.new(1, 1, 1))
local SphereRadiusState        = iris.State(1)

-- Caster toggles
local ObjectEnabledValue  = iris.State(Caster.ObjectCacheEnabled)
local ObjectCacheSizeValue = iris.State(DEFAULT_CACHE_SIZE)
local BulkMoveEnabledValue = iris.State(Caster.BulkMoveEnabled)

-- Performance / config sub-tables (built from behavior defaults)
local FastCastEventsConfigStates: { [string]: any }       = {}
local FastCastEventsModuleConfigStates: { [string]: any } = {}
local AdaptivePerformanceStates: { [string]: any }        = {}
local VisualizeCastSettingSt: { [string]: any }           = {}

for key, value in CastBehaviorClient.FastCastEventsConfig do
	FastCastEventsConfigStates[key] = iris.State(value)
end
for key, value in CastBehaviorClient.FastCastEventsModuleConfig do
	FastCastEventsModuleConfigStates[key] = iris.State(value)
end
for key, value in CastBehaviorClient.AdaptivePerformance do
	AdaptivePerformanceStates[key] = iris.State(value)
end
for key, value in CastBehaviorClient.VisualizeCastSettings do
	VisualizeCastSettingSt[key] = iris.State(value)
end

-- Tests / Modules
local SelectedTests: { [string]: any } = {}
for key in TestModules do
	SelectedTests[key] = iris.State(false)
end

-- Performance test
local OriginValue       = iris.State(Vector3.new(0, 5, 0))
local DirectionValue    = iris.State(Vector3.new(0, 0, -1000))
local P_ClientTestValue = iris.State(false)
local P_ServerTestValue = iris.State(false)
local P_TestValue       = iris.State(false)

-- FastCastEventsModule selection
local SelectedModuleKey: string? = nil

-- ============================================================
-- Helpers
-- ============================================================

local function buildClientBehavior()
	CastBehaviorClient.HighFidelityBehavior    = SelectedBehavior.value
	CastBehaviorClient.Acceleration            = AccelerationState.value
	CastBehaviorClient.AutoIgnoreContainer     = AutoIgnoreContainerState.value
	CastBehaviorClient.MaxDistance             = MaxDistanceState.value
	CastBehaviorClient.VisualizeCasts          = VisualizeCastsState.value
	CastBehaviorClient.HighFidelitySegmentSize = HighFidelitySegmentSizeState.value
	CastBehaviorClient.CosmeticBulletTemplate  = UseCosmeticBulletTemplate.value and ProjectileTemplate or nil
	CastBehaviorClient.SimulateAfterPhysic     = SimulateAfterPhysicState.value
	CastBehaviorClient.AutomaticPerformance    = AutomaticPerformanceState.value
	for key, v in FastCastEventsConfigStates       do CastBehaviorClient.FastCastEventsConfig[key]       = v.value end
	for key, v in FastCastEventsModuleConfigStates do CastBehaviorClient.FastCastEventsModuleConfig[key] = v.value end
	for key, v in AdaptivePerformanceStates        do CastBehaviorClient.AdaptivePerformance[key]        = v.value end
	for key, v in VisualizeCastSettingSt           do CastBehaviorClient.VisualizeCastSettings[key]      = v.value end
end

local function buildServerBehavior()
	local b = FastCastM.newBehavior()
	b.HighFidelityBehavior    = SelectedBehavior.value
	b.Acceleration            = AccelerationState.value
	b.AutoIgnoreContainer     = AutoIgnoreContainerState.value
	b.MaxDistance             = MaxDistanceState.value
	b.VisualizeCasts          = false -- never visualize on server
	b.HighFidelitySegmentSize = HighFidelitySegmentSizeState.value
	b.SimulateAfterPhysic     = SimulateAfterPhysicState.value
	b.AutomaticPerformance    = AutomaticPerformanceState.value
	for key, v in FastCastEventsConfigStates       do b.FastCastEventsConfig[key]       = v.value end
	for key, v in FastCastEventsModuleConfigStates do b.FastCastEventsModuleConfig[key] = v.value end
	for key, v in AdaptivePerformanceStates        do b.AdaptivePerformance[key]        = v.value end
	for key, v in VisualizeCastSettingSt           do b.VisualizeCastSettings[key]      = v.value end
	CastBehaviorServerUpdate:Fire(b)
end

local function casterFire(castType: CastType, origin: Vector3, arg: any, direction: Vector3, velocity: number, behavior: FastCastTypes.FastCastBehavior?)
	if castType == "Raycast" then
		Caster:RaycastFire(origin, direction, velocity, behavior)
	elseif castType == "Blockcast" then
		Caster:BlockcastFire(origin, arg, direction, velocity, behavior)
	elseif castType == "Spherecast" then
		Caster:SpherecastFire(origin, arg, direction, velocity, behavior)
	end
end

-- ============================================================
-- Init — push initial state to server on load
-- ============================================================

iris.Init()

CastBehaviorServerUpdate:Fire(CastBehaviorClient)
ServerSettingUpdate:Fire({
	velocity = VelocityValue.value,
	projectileLimit = ClientProjectileLimitValue.value,
})

-- ============================================================
-- Iris UI
-- ============================================================

iris:Connect(function()
	iris.Window({ "FastCast2 Debugger [Studio]" }, { size = WindowSize, isOpened = WindowVisible })

	-- --------------------------------------------------------
	-- Settings
	-- --------------------------------------------------------
	iris.Tree({ "Settings" })
	iris.InputNum({ "Velocity" }, { number = VelocityValue })
	iris.InputNum({ "Projectile Limit" }, { number = ClientProjectileLimitValue })

	iris.Tree({ "Cast Type" })
	for _, castType in CAST_TYPES do
		iris.RadioButton({ castType, castType }, { index = CastTypeState }, castType)
	end
	iris.End()

	local castArg: any = nil
	if CastTypeState.value == "Blockcast" then
		iris.InputVector3({ "Blockcast Size" }, { number = BlockSizeState })
		castArg = BlockSizeState.value
	elseif CastTypeState.value == "Spherecast" then
		iris.InputNum({ "Spherecast Radius" }, { number = SphereRadiusState })
		castArg = SphereRadiusState.value
	end

	if iris.Button({ "Update Server Settings" }).clicked() then
		ServerSettingUpdate:Fire({
			velocity = VelocityValue.value,
			projectileLimit = ClientProjectileLimitValue.value,
		})
	end
	iris.End()

	-- --------------------------------------------------------
	-- FastCastBehavior
	-- --------------------------------------------------------
	iris.Tree({ "FastCastBehavior" })
	iris.Tree({ "HighFidelityBehavior" })
	for i = 1, 3 do
		iris.RadioButton({ HIGH_FIDELITY_NAMES[i], i }, { index = SelectedBehavior }, i)
	end
	iris.End()

	iris.InputVector3({ "Acceleration" }, { number = AccelerationState })
	iris.Checkbox({ "AutoIgnoreContainer" }, { isChecked = AutoIgnoreContainerState })
	iris.InputNum({ "MaxDistance" }, { number = MaxDistanceState })
	iris.Checkbox({ "VisualizeCasts" }, { isChecked = VisualizeCastsState })
	iris.InputNum({ "HighFidelitySegmentSize", 0.1, 0.1, 2 }, { number = HighFidelitySegmentSizeState })
	iris.Checkbox({ "Use CosmeticBulletTemplate" }, { isChecked = UseCosmeticBulletTemplate })
	iris.Checkbox({ "SimulateAfterPhysic" }, { isChecked = SimulateAfterPhysicState })

	iris.Tree({ "FastCastEventsConfig" })
	for key, state in FastCastEventsConfigStates do
		iris.Checkbox({ key }, { isChecked = state })
	end
	iris.End()

	iris.Tree({ "FastCastEventsModuleConfig" })
	for key, state in FastCastEventsModuleConfigStates do
		iris.Checkbox({ key }, { isChecked = state })
	end
	iris.End()

	iris.Checkbox({ "Automatic Performance" }, { isChecked = AutomaticPerformanceState })

	iris.Tree({ "Adaptive Performance" })
	iris.InputNum({ "HighFidelitySegmentSizeIncrease", 0.1, 0.1, 2 }, { number = AdaptivePerformanceStates.HighFidelitySegmentSizeIncrease })
	iris.Checkbox({ "LowerHighFidelityBehavior" }, { isChecked = AdaptivePerformanceStates.LowerHighFidelityBehavior })
	iris.End()

	iris.Tree({ "VisualizeCastSettings" })
	iris.Text({ "-- Segment --" })
	iris.InputColor3({ "Debug_SegmentColor" }, { number = VisualizeCastSettingSt.Debug_SegmentColor })
	iris.InputNum({ "Debug_SegmentTransparency", 0.1, 0, 1 }, { number = VisualizeCastSettingSt.Debug_SegmentTransparency })
	iris.InputNum({ "Debug_SegmentSize", 0.05, 0.05, 2 }, { number = VisualizeCastSettingSt.Debug_SegmentSize })

	iris.Text({ "-- Hit --" })
	iris.InputColor3({ "Debug_HitColor" }, { number = VisualizeCastSettingSt.Debug_HitColor })
	iris.InputNum({ "Debug_HitTransparency", 0.1, 0, 1 }, { number = VisualizeCastSettingSt.Debug_HitTransparency })
	iris.InputNum({ "Debug_HitSize", 0.5, 0.5, 5 }, { number = VisualizeCastSettingSt.Debug_HitSize })

	iris.Text({ "-- Ray Pierce --" })
	iris.InputColor3({ "Debug_RayPierceColor" }, { number = VisualizeCastSettingSt.Debug_RayPierceColor })
	iris.InputNum({ "Debug_RayPierceTransparency", 0.1, 0, 1 }, { number = VisualizeCastSettingSt.Debug_RayPierceTransparency })
	iris.InputNum({ "Debug_RayPierceSize", 0.5, 0.5, 5 }, { number = VisualizeCastSettingSt.Debug_RayPierceSize })

	iris.Text({ "-- Lifetime --" })
	iris.InputNum({ "Debug_RayLifetime" }, { number = VisualizeCastSettingSt.Debug_RayLifetime })
	iris.InputNum({ "Debug_HitLifetime" }, { number = VisualizeCastSettingSt.Debug_HitLifetime })
	iris.End()

	if iris.Button({ "Update Client Behavior" }).clicked() then
		buildClientBehavior()
		print("[IrisLocal] Client behavior updated")
	end
	if iris.Button({ "Update Server Behavior" }).clicked() then
		buildServerBehavior()
		print("[IrisLocal] Server behavior updated")
	end
	iris.End()

	-- --------------------------------------------------------
	-- Caster (ObjectCache / BulkMove)
	-- --------------------------------------------------------
	iris.Tree({ "Caster" })
	iris.Checkbox({ "ObjectCache Enabled" }, { isChecked = ObjectEnabledValue })
	if ObjectEnabledValue.value then
		if not Caster.ObjectCacheEnabled then
			Caster:SetObjectCacheEnabled(true, ProjectileTemplate, DEFAULT_CACHE_SIZE, ProjectileContainer)
			Caster.CastTerminating = onCastTerminatingObjectCache
		end
	else
		if Caster.ObjectCacheEnabled then
			Caster:SetObjectCacheEnabled(false)
			Caster.CastTerminating = onCastTerminating
		end
	end

	iris.Checkbox({ "BulkMoveTo" }, { isChecked = BulkMoveEnabledValue })
	if BulkMoveEnabledValue.value then
		if not Caster.BulkMoveEnabled then Caster:SetBulkMoveEnabled(true) end
	else
		if Caster.BulkMoveEnabled then Caster:SetBulkMoveEnabled(false) end
	end
	iris.End()

	-- --------------------------------------------------------
	-- Logging
	-- --------------------------------------------------------
	iris.Tree({ "Logging" })
	if iris.Button({ "Print Client Behavior" }).clicked() then
		print(CastBehaviorClient)
	end
	if iris.Button({ "Print Server Behavior" }).clicked() then
		LoggingServer:Fire("FastCastBehavior")
	end
	if iris.Button({ "Print Server Settings" }).clicked() then
		LoggingServer:Fire("Setting")
	end
	iris.End()

	-- --------------------------------------------------------
	-- Performance Test
	-- --------------------------------------------------------
	iris.Tree({ "Performance Test" })
	iris.InputVector3({ "Origin" }, { number = OriginValue })
	iris.InputVector3({ "Direction" }, { number = DirectionValue })
	iris.Checkbox({ "Client Test" }, { isChecked = P_ClientTestValue })
	iris.Checkbox({ "Server Test" }, { isChecked = P_ServerTestValue })
	iris.Checkbox({ "Fire Projectiles" }, { isChecked = P_TestValue })

	if P_TestValue.value then
		if P_ClientTestValue.value and ClientProjectileCount < ClientProjectileLimitValue.value then
			casterFire(CastTypeState.value, OriginValue.value, castArg, DirectionValue.value, VelocityValue.value, CastBehaviorClient)
			ClientProjectileCount += 1
		end
		if P_ServerTestValue.value then
			ServerProjectile:FireUnreliable(OriginValue.value, DirectionValue.value)
		end
	end
	iris.End()

	-- --------------------------------------------------------
	-- FastCastEventsModule
	-- --------------------------------------------------------
	iris.Tree({ "FastCastEventsModule" })
	for key, moduleScript in FastCastEventsModules do
		local isSelected = iris.State(SelectedModuleKey == key)
		local checkbox = iris.Checkbox({ key }, { isChecked = isSelected })

		if checkbox.checked() then
			SelectedModuleKey = key
			Caster:SetFastCastEventsModule(moduleScript)
		elseif checkbox.unchecked() then
			SelectedModuleKey = nil
			Caster:SetFastCastEventsModule(nil)
		end
	end

	if iris.Button({ "Sync Module to Server" }).clicked() then
		ServerCastModuleUpdate:Fire(Caster.FastCastEventsModule)
	end
	iris.End()

	-- --------------------------------------------------------
	-- Test Modules
	-- --------------------------------------------------------
	iris.Tree({ "Test Modules" })
	for key, state in SelectedTests do
		local checkbox = iris.Checkbox({ key }, { isChecked = state })

		if checkbox.checked() then
			TestModules[key].Start(IntCountEvent, Caster, VelocityValue.value, CastBehaviorClient)
		elseif checkbox.unchecked() then
			TestModules[key].Stop()
		end
	end

	if iris.Button({ "Update Running Tests" }).clicked() then
		for key, state in SelectedTests do
			if state.value then
				TestModules[key].Update(Caster, VelocityValue.value, CastBehaviorClient)
			end
		end
	end
	iris.End()

	-- --------------------------------------------------------
	-- Projectile Counters (live via RemoteTable)
	-- --------------------------------------------------------
	iris.Separator()
	iris.Text({ "Client projectiles: " .. ClientProjectileCount })
	iris.Text({ "Server projectiles: " .. (serverState and serverState.projectileCount or "?") })

	iris.End() -- Window
end)

-- ============================================================
-- Keybind: E to toggle window
-- ============================================================

UserInputService.InputEnded:Connect(function(input: InputObject, gp: boolean)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.E then
		WindowVisible:set(not WindowVisible:get())
	end
end)
