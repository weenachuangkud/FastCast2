--[[
	- Author: Mawin_CK
	- Date: 2025
]]

-- TODO: Add blockcast support

-- Services
local Rep = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RepFirst = game:GetService("ReplicatedFirst")
local UIS = game:GetService("UserInputService")

-- Modules
local FastCast2 = Rep:WaitForChild("FastCast2")

-- Requires
local iris = require(Rep:WaitForChild("iris"))
local FastCastM = require(FastCast2)
local FastCastTypes = require(FastCast2:WaitForChild("TypeDefinitions"))
local Jolt = require(Rep:WaitForChild("Jolt"))
local Signal = require(FastCast2:WaitForChild("Signal"))

-- Types
type RequestLogDataType = "FastCastBehavior" | "Setting"

-- Variables
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

--local TargetPartOrigin: BasePart = nil
--local TargetOrigin: Vector3 = Vector3.new()

--local TargetDirection = Vector3.new()

local ProjectileContainer = workspace:WaitForChild('Projectiles')
local ProjectileTemplate = Rep:WaitForChild("Projectile")

local ClientProjectileCount = 0
local ServerProjectileCount = 0


local HighFidelityBehaviorName = {
	[1] = "Default",
	[2] = "Automatic",
	[3] = "Always"
}

local TestModules = {}
for _, value in Rep:WaitForChild("Tests"):GetChildren() do
	TestModules[value.Name] = require(value)
end

local FastCastEventsModules = {}
for _, value in Rep:WaitForChild("FastCastEventsModules"):GetChildren() do
	FastCastEventsModules[value.Name] = value
end

local debounce_lc = false
local debounce_lc_time = 1.5

-- CastParams
local CastParams = RaycastParams.new()
CastParams.FilterDescendantsInstances = {character}
CastParams.FilterType = Enum.RaycastFilterType.Exclude
CastParams.IgnoreWater = true

-- Behavior
local CastBehaviorClient: FastCastTypes.FastCastBehavior = FastCastM.newBehavior()
CastBehaviorClient.RaycastParams = CastParams
CastBehaviorClient.VisualizeCasts = false
CastBehaviorClient.Acceleration = Vector3.new()
CastBehaviorClient.AutoIgnoreContainer = true
CastBehaviorClient.MaxDistance = 1000
CastBehaviorClient.HighFidelitySegmentSize = 1

CastBehaviorClient.CosmeticBulletContainer = ProjectileContainer
CastBehaviorClient.CosmeticBulletTemplate = ProjectileTemplate

CastBehaviorClient.FastCastEventsConfig = {
	UseLengthChanged = false,
	UseHit = false,
	UseCastTerminating = true,
	UseCastFire = false,
	UsePierced = false
}

CastBehaviorClient.FastCastEventsModuleConfig = {
	UseLengthChanged = false,
	UseHit = false,
	UseCastTerminating = true,
	UseCastFire = false,
	UsePierced = false,
	UseCanPierce = false
}

CastBehaviorClient.SimulateAfterPhysic = true

-- Events
local CastBehaviorServerUpdate = Jolt.Client("CastBehaviorServerUpdate") :: Jolt.Client<FastCastTypes.FastCastBehavior>
local LoggingServer = Jolt.Client("LoggingServer") :: Jolt.Client<RequestLogDataType>
local ServerSettingUpdate = Jolt.Client("ServerSettingUpdate") :: Jolt.Client<{velocity: number, ProjectileLimit: number}>
local ServerProjectile = Jolt.Client("ServerProjectile") :: Jolt.Client<Vector3, Vector3, number>
local ServerProjectileCountEvent = Jolt.Client("ServerProjectileCount") :: Jolt.Client<number>
local ServerCastModuleUpdate = Jolt.Client("ServerCastModuleUpdate") :: Jolt.Client<ModuleScript>

-- Caster
local Caster = FastCastM.new()
Caster:Init(
	4,
	RepFirst,
	"CastVMs",
	RepFirst,
	"VMContainer",
	"CastVM",
	true
)

-- CONSTANTS
local DEFAULT_CACHE_SIZE = 1000

-- States

local WindowSize = iris.State(Vector2.new(500, 400))
local WindowVisible = iris.State(true)

local SelectedBehavior = iris.State(CastBehaviorClient.HighFidelityBehavior)
local AcclerationState = iris.State(CastBehaviorClient.Acceleration)
local AutoIgnoreContainerState = iris.State(CastBehaviorClient.AutoIgnoreContainer)
local MaxDistanceState = iris.State(CastBehaviorClient.MaxDistance)
local VisualizeCastsState = iris.State(CastBehaviorClient.VisualizeCasts)
local HighFidelitySegmentSizeState = iris.State(CastBehaviorClient.HighFidelitySegmentSize)
local UseCosmeticBulletTemplate = iris.State(true)
local SimulateAfterPhysicState = iris.State(CastBehaviorClient.SimulateAfterPhysic)

local OriginValue = iris.State(Vector3.new(0, 5, 0))
local DirectionValue = iris.State(Vector3.new(0,0,-1000))
local VelocityValue = iris.State(50)
local ClientProjectileLimitValue = iris.State(1000)
local P_ClientTestValue = iris.State(false)
local P_ServerTestValue = iris.State(false)
local FastCastEventsConfigStates = {}
local FastCastEventsModuleConfigStates = {}

local CastTypeState = iris.State("Raycast")

local CastTypes = {
	"Raycast",
	"Blockcast",
	"Spherecast"
}

local P_TestValue = iris.State(false)

for key, value in CastBehaviorClient.FastCastEventsConfig do
	FastCastEventsConfigStates[key] = iris.State(value)
end

for key, value in CastBehaviorClient.FastCastEventsModuleConfig do
	FastCastEventsModuleConfigStates[key] = iris.State(value)
end

local AutomaticPerformanceState = iris.State(true)
local AdaptivePerformanceStates = {}
for key, value in CastBehaviorClient.AdaptivePerformance do
	AdaptivePerformanceStates[key] = iris.State(value)
end

local VisualizeCastSettingSt = {}
for key, value in CastBehaviorClient.VisualizeCastSettings do
	VisualizeCastSettingSt[key] = iris.State(value)
end

local ObjectEnabledValue = iris.State(Caster.ObjectCacheEnabled)
local ObjectCacheSizeValue = iris.State(DEFAULT_CACHE_SIZE)
local BulkMoveEnabledValue = iris.State(Caster.BulkMoveEnabled)

local SelectedTests = {}
for key, _ in TestModules do
	SelectedTests[key] = iris.State(false)	
end

local SelcetedModule = iris.State(nil)

-- Local functions

--[[local function Format(Time: number): string
	if Time < 1E-6 then
		return `{Time * 1E+9} ns`
	elseif Time < 0.001 then
		return `{Time * 1E+6} μs`
	elseif Time < 1 then
		return `{Time * 1000} ms`
	else
		return `{Time} s`
	end
end]]

local function UpdateClientBehavior()
	CastBehaviorClient.HighFidelityBehavior = SelectedBehavior.value
	CastBehaviorClient.Acceleration = AcclerationState.value
	CastBehaviorClient.AutoIgnoreContainer = AutoIgnoreContainerState.value
	CastBehaviorClient.MaxDistance = MaxDistanceState.value
	CastBehaviorClient.VisualizeCasts = VisualizeCastsState.value
	CastBehaviorClient.HighFidelitySegmentSize = HighFidelitySegmentSizeState.value
	CastBehaviorClient.CosmeticBulletTemplate = UseCosmeticBulletTemplate.value == true and ProjectileTemplate or nil
	CastBehaviorClient.SimulateAfterPhysic = SimulateAfterPhysicState.value
	CastBehaviorClient.AutomaticPerformance = AutomaticPerformanceState.value
	for key, v in FastCastEventsConfigStates do
		CastBehaviorClient.FastCastEventsConfig[key] = v.value
	end
	for key, v in FastCastEventsModuleConfigStates do
		CastBehaviorClient.FastCastEventsModuleConfig[key] = v.value
	end
	for key, v in AdaptivePerformanceStates do
		CastBehaviorClient.AdaptivePerformance[key] = v.value
	end
	for key, v in VisualizeCastSettingSt do
		CastBehaviorClient.VisualizeCastSettings[key] = v.value
	end
end

local function UpdateServerBehavior()
	local newBehavior = FastCastM.newBehavior()
	newBehavior.HighFidelityBehavior = SelectedBehavior.value
	newBehavior.Acceleration = AcclerationState.value
	newBehavior.AutoIgnoreContainer = AutoIgnoreContainerState.value
	newBehavior.MaxDistance = MaxDistanceState.value
	newBehavior.VisualizeCasts = VisualizeCastsState.value
	newBehavior.HighFidelitySegmentSize = HighFidelitySegmentSizeState.value
	newBehavior.SimulateAfterPhysic = SimulateAfterPhysicState.value
	newBehavior.AutomaticPerformance = AutomaticPerformanceState.value
	for key, v in FastCastEventsConfigStates do
		newBehavior.FastCastEventsConfig[key] = v.value
	end
	for key, v in FastCastEventsModuleConfigStates do
		newBehavior.FastCastEventsModuleConfig[key] = v.value
	end
	for key, v in AdaptivePerformanceStates do
		newBehavior.AdaptivePerformance[key] = v.value
	end
	for key, v in VisualizeCastSettingSt do
		newBehavior.VisualizeCastSettings[key] = v.value
	end
	CastBehaviorServerUpdate:Fire(newBehavior)
end

local function IntCount(amount: number)
	ClientProjectileCount += amount
end

local function OnCastTerminating(cast: FastCastTypes.ActiveCastCompement)
	local obj = cast.RayInfo.CosmeticBulletObject
	if obj then
		obj:Destroy()
	end
	IntCount(-1)
end

local function OnCastTerminating_ObjectCache(cast: FastCastTypes.ActiveCastCompement)
	local obj = cast.RayInfo.CosmeticBulletObject
	if obj then
		Caster.ObjectCache:ReturnObject(obj)
	end
	IntCount(-1)
end

local function CasterFire(
	targetType: "Raycast" | "Blockcast" | "Spherecast",
	origin: Vector3,
	arg: any?,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: FastCastTypes.FastCastBehavior?
)
	--print(targetType, origin, arg, direction, velocity)
	if targetType == "Raycast" then
		Caster:RaycastFire(origin, direction, velocity, behavior)
	elseif targetType == "Blockcast" then
		Caster:BlockcastFire(origin, arg, direction, velocity, behavior)
	elseif targetType == "Spherecast" then
		Caster:SpherecastFire(origin, arg, direction, velocity, behavior)
	end
end

local BlockSizeState = iris.State(Vector3.new(1,1,1))
local SphereRadiusState = iris.State(1)

-- Init
iris.Init()
CastBehaviorServerUpdate:Fire(CastBehaviorClient)
ServerSettingUpdate:Fire({
	velocity = VelocityValue.value,
	projectileLimit = ClientProjectileLimitValue.value
})

local IntCountEvent = Signal.new()
IntCountEvent:Connect(function(amount: number)
	ClientProjectileCount += amount
end)

Caster.CastTerminating = OnCastTerminating
Caster.CastFire = function()
	print("CastFire Test!")
end
Caster.Hit = function()
	print("Hit Test!")
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
	print("pierced Test!")
end

-- iris
iris:Connect(function()
	iris.Window({"FastCast2 TestGUI"},{size=WindowSize, isOpened=WindowVisible})
		iris.Tree("Setting")
			iris.InputNum({"Velocity"}, {number=VelocityValue})
			iris.InputNum({"Projectile limit"}, {number=ClientProjectileLimitValue})
			iris.Tree("CastType")
				for k,v in CastTypes do
					iris.RadioButton(
						{ v, v },
						{index = CastTypeState},
						k
					)
				end
			iris.End()
			
			local arg = nil
			
			if CastTypeState.value == "Blockcast" then
				local input = iris.InputVector3({"BlockcastSize"}, {number = BlockSizeState})
				if input.numberChanged() then
					arg = BlockSizeState.value
				end
			end

			if CastTypeState.value == "Spherecast" then
				local input = iris.InputNum({"SpherecastRadius"}, {number = SphereRadiusState})
				if input.numberChanged() then
					arg = SphereRadiusState.value
				end
			end
			if iris.Button("Update Server").clicked() then
				ServerSettingUpdate:Fire({
					velocity = VelocityValue.value,
					projectileLimit = ClientProjectileLimitValue.value,
					castType = CastTypeState.value,
					arg = arg
				})
			end
		iris.End()
		
		-- FastCastBehavior
		iris.Tree({"FastCastBehavior"})
			iris.Tree("HighFidelityBehavior")
				for i = 1, 3 do
					iris.RadioButton(
						{ HighFidelityBehaviorName[i], i },
						{index = SelectedBehavior},
						i
					)
				end
			iris.End()
			
			iris.InputVector3({"Acceleration"}, {number = AcclerationState})
			iris.Checkbox({"AutoIgnoreContainer"}, {isChecked = AutoIgnoreContainerState})
			iris.InputNum({"MaxDistance"}, {number = MaxDistanceState})
			iris.Checkbox({"VisualizeCasts"}, {isChecked = VisualizeCastsState})
			iris.InputNum({"HighFidelitySegmentSize", 0.1, 0.1, 2}, {number = HighFidelitySegmentSizeState})
			iris.Checkbox({"Use CosmeticBulletTemplate"}, {isChecked = UseCosmeticBulletTemplate})
			iris.Checkbox({"SimulateAfterPhysic"}, {isChecked=SimulateAfterPhysicState})
			
			iris.Tree("FastCastEventsConfig")
			for key, state in FastCastEventsConfigStates do
				iris.Checkbox({key}, {isChecked = state})
			end
			iris.End()

			iris.Tree("FastCastEventsModuleConfig")
			for key, state in FastCastEventsModuleConfigStates do 
				iris.Checkbox({key}, {isChecked = state})
			end
			iris.End()
			
			iris.Checkbox({"Automatic performance"}, {isChecked=AutomaticPerformanceState})
			
			iris.Tree("Adaptive performance")
				iris.InputNum({"HighFidelitySegmentSizeIncrease", 0.1, 0.1, 2}, {number=AdaptivePerformanceStates.HighFidelitySegmentSizeIncrease})
				iris.Checkbox({"LowerHighFidelityBehavior"}, {isChecked=AdaptivePerformanceStates.LowerHighFidelityBehavior})
			iris.End()
			
			iris.Tree("VisualizeCastSettings")
				iris.Text({"Segment"})
				
				iris.InputColor3({"Debug_SegmentColor"}, {number=VisualizeCastSettingSt.Debug_SegmentColor})
				iris.InputNum({"Debug_SegmentTransparency", 0.1, 0, 1}, {number=VisualizeCastSettingSt.Debug_SegmentTransparency})
				iris.InputNum({"Debug_SegmentSize", 0.05, 0.05, 2}, {number=VisualizeCastSettingSt.Debug_SegmentSize})
				
				iris.Text({"Hit"})
				
				iris.InputColor3({"Debug_HitColor"}, {number=VisualizeCastSettingSt.Debug_HitColor})
				iris.InputNum({"Debug_HitTransparency", 0.1, 0, 1}, {number=VisualizeCastSettingSt.Debug_HitTransparency})
				iris.InputNum({"Debug_HitSize", 0.5, 0.5, 5}, {number=VisualizeCastSettingSt.Debug_HitSize})
				
				iris.Text({"Raypierce"})
				
				iris.InputColor3({"Debug_RayPierceColor"}, {number=VisualizeCastSettingSt.Debug_RayPierceColor})
				iris.InputNum({"Debug_RayPierceTransparency", 0.1, 0, 1}, {number=VisualizeCastSettingSt.Debug_RayPierceTransparency})
				iris.InputNum({"Debug_RayPierceSize", 0.5, 0.5, 5}, {number=VisualizeCastSettingSt.Debug_RayPierceSize})
				
				iris.Text({"Lifetime"})
				iris.InputNum({"Debug_RayLifetime"}, {number=VisualizeCastSettingSt.Debug_RayLifetime})
				iris.InputNum({"Debug_HitLifetime"}, {number=VisualizeCastSettingSt.Debug_HitLifetime})
			iris.End()
			
			if iris.Button("Update Client").clicked() then
				print("Updated FastCastBehaviorClient")
				UpdateClientBehavior()
			end
			
			if iris.Button("Update Server").clicked() then
				print("Updated FastCastBehaviorServer")
				UpdateServerBehavior()
			end
			
		iris.End()
		
		iris.Tree({"Caster"})
			do
				iris.Checkbox({"ObjectCache Enabled"}, {isChecked = ObjectEnabledValue})
				if ObjectEnabledValue.value == true then
					if not Caster.ObjectCacheEnabled then
						Caster:SetObjectCacheEnabled(true, ProjectileTemplate, DEFAULT_CACHE_SIZE, ProjectileContainer)
						Caster.CastTerminating = OnCastTerminating_ObjectCache
					end
				else
					if Caster.ObjectCacheEnabled then
						Caster:SetObjectCacheEnabled(false)
						Caster.CastTerminating = OnCastTerminating
					end
				end
				
				iris.Checkbox({"BulkMoveTo"}, {isChecked = BulkMoveEnabledValue})
				if BulkMoveEnabledValue.value == true then
					if not Caster.BulkMoveEnabled then
						Caster:SetBulkMoveEnabled(true)
					end
				else
					if Caster.BulkMoveEnabled then
						Caster:SetBulkMoveEnabled(false)
					end
				end
			end
		iris.End()
		
		iris.Tree({"Logging"})
			if iris.Button({"FastCastBehavior Client"}).clicked() then
				print(CastBehaviorClient)
			end
			
			if iris.Button({"FastCastBehavior Server"}).clicked() then
				LoggingServer:Fire("FastCastBehavior")
			end
			
			if iris.Button({"Server Setting"}).clicked() then
				LoggingServer:Fire("Setting")
			end
		
		iris.End()
		
		iris.Tree("Performance Test")
			iris.InputVector3({"Origin"}, {number=OriginValue})
			iris.InputVector3({"Direction"}, {number=DirectionValue})
			do 
				iris.Checkbox({"Client Test"}, {isChecked=P_ClientTestValue})
				iris.Checkbox({"Server Test"}, {isChecked=P_ServerTestValue})
				
				iris.Checkbox({"Fire Projectiles"}, {isChecked=P_TestValue})
				
				if P_TestValue.value == true then
					if ClientProjectileCount < ClientProjectileLimitValue.value and P_ClientTestValue.value == true then
						CasterFire(CastTypeState.value, OriginValue.value, arg, DirectionValue.value, VelocityValue.value, CastBehaviorClient)
						IntCount(1)
					end
					
					if P_ServerTestValue.value == true then
						ServerProjectile:FireUnreliable(OriginValue.value, DirectionValue.value)
					end
				end
			end
			
		iris.End()
		
		iris.Tree("FastCastEventsModule")
			--[[
				S1 = nil
				
				A1
				A2
			]]
			for key, moduleScript in FastCastEventsModules do
				local isThisChecked = (SelcetedModule == key)
				
				local checkbox = iris.Checkbox({key}, {isChecked = isThisChecked})
				if checkbox.checked() then
					SelcetedModule = key
					Caster:SetFastCastEventsModule(moduleScript)
				end
				
				if checkbox.unchecked() then
					SelcetedModule = nil
					Caster:SetFastCastEventsModule(nil)
				end
			end
			
			if iris.Button("Update Server").clicked() then
				ServerCastModuleUpdate:Fire(Caster.FastCastEventsModule)
			end
		iris.End()
		
		iris.Tree("TestModules")
			for key, state in SelectedTests do
				local checkbox = iris.Checkbox({key}, {isChecked = state})
				
				if checkbox.checked() then
					TestModules[key].Start(IntCountEvent, Caster, VelocityValue.value, CastBehaviorClient)
				end
				
				if checkbox.unchecked() then
					TestModules[key].Stop()
				end
			end
			
			if iris.Button("Update TestModules").clicked() then
				for key, state in SelectedTests do
					if state.value == true then
						TestModules[key].Update(Caster, VelocityValue.value, CastBehaviorClient)
					end
				end
			end
		iris.End()
		
	iris.Text({"Client projectile count : " .. ClientProjectileCount})
	iris.Text({"Server projectile count : " .. ServerProjectileCount})
	
	iris.End()
end)

game:GetService("UserInputService").InputEnded:Connect(function(input: InputObject, gp: boolean)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.E then
		WindowVisible:set(not WindowVisible:get())
	end
end)

-- Event Connections

ServerProjectileCountEvent:Connect(function(newCount: number)
	ServerProjectileCount = newCount
end)