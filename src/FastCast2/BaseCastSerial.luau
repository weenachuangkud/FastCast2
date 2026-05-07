--[[
	- Author : Mawin CK
	- Date : 2025
	

	BaseCastSerial - Uses SerialSimulation with SoA pattern
]]

local RS = game:GetService("RunService")

local FastCast2 = script.Parent
local FastCastM = require(FastCast2)

local FastCastEnums = require(FastCast2:WaitForChild("FastCastEnums"))
local TypeDef = require(FastCast2:WaitForChild("TypeDefinitions"))
local ActiveCastSerial = require(FastCast2:WaitForChild("ActiveCastSerial"))
local SerialSimulation = require(FastCast2:WaitForChild("SerialSimulation"))

local EnumCastTypes = FastCastEnums.CastType

--[=[
	@class BaseCastSerial

	Base class for Serial (non-parallel) Raycast operations.
	Uses SerialSimulation with SoA pattern for performance.
]=]

local BaseCastSerial = {}
BaseCastSerial.__index = BaseCastSerial
BaseCastSerial.__type = "BaseCastSerial"

local BulkMoveToConnection: RBXScriptConnection? = nil
local Output: BindableEvent? = nil
local ObjectCache: BindableFunction? = nil
local NextProjectileID = 0
local ParentCaster = nil

--[=[
	@function Init
	@within BaseCastSerial
]=]
function BaseCastSerial.Init(BindableOutput: BindableEvent, Data: any, parentCaster: any)
	local self = setmetatable({}, BaseCastSerial)
	Output = BindableOutput
	ParentCaster = parentCaster

	if Data.useBulkMoveTo then
		-- BulkMoveTo is handled by SerialSimulation
	end

	return self
end

local function CloneCastParams(params: RaycastParams): RaycastParams
	local clone: RaycastParams = RaycastParams.new()
	clone.CollisionGroup = params.CollisionGroup
	clone.FilterType = params.FilterType
	clone.FilterDescendantsInstances = params.FilterDescendantsInstances
	clone.IgnoreWater = params.IgnoreWater
	return clone
end

--[=[
	@method Raycast
	@within BaseCastSerial
]=]
function BaseCastSerial:Raycast(
	Origin: Vector3,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1

	if typeof(Velocity) == "number" then
		Velocity = Direction.Unit * Velocity
	end

	local raycastParams = Behavior.RaycastParams
	if raycastParams then
		raycastParams = CloneCastParams(raycastParams)
	else
		raycastParams = RaycastParams.new()
	end

	local cosmeticBullet = Behavior.CosmeticBulletTemplate
	if cosmeticBullet then
		cosmeticBullet = cosmeticBullet:Clone()
		cosmeticBullet.CFrame = CFrame.new(Origin, Origin + Direction)
		cosmeticBullet.Parent = Behavior.CosmeticBulletContainer
	end

	local castData = {
		ID = NextProjectileID,
		Origin = Origin,
		Velocity = Velocity,
		Acceleration = Behavior.Acceleration,
		RaycastParams = raycastParams,
		MaxDistance = Behavior.MaxDistance or 1000,
		CosmeticBulletObject = cosmeticBullet,
		CastType = EnumCastTypes.Raycast,
		VisualizeCasts = Behavior.VisualizeCasts,
		VisualizeCastSettings = Behavior.VisualizeCastSettings,
		HighFidelitySegmentSize = Behavior.HighFidelitySegmentSize,
		HighFidelityBehavior = Behavior.HighFidelityBehavior,
		MovementMethod = Behavior.MovementMethod or "BulkMoveTo"
	}

	local cast = ActiveCastSerial.new(ParentCaster, castData)
	SerialSimulation.Register(cast)

	if Output then
		Output:Fire("CastFire", cast, Origin, Direction, Velocity, Behavior)
	end
end

--[=[
	@method Blockcast
	@within BaseCastSerial
]=]
function BaseCastSerial:Blockcast(
	Origin: Vector3,
	Size: Vector3,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1

	if typeof(Velocity) == "number" then
		Velocity = Direction.Unit * Velocity
	end

	local raycastParams = Behavior.RaycastParams
	if raycastParams then
		raycastParams = CloneCastParams(raycastParams)
	else
		raycastParams = RaycastParams.new()
	end

	local cosmeticBullet = Behavior.CosmeticBulletTemplate
	if cosmeticBullet then
		cosmeticBullet = cosmeticBullet:Clone()
		cosmeticBullet.CFrame = CFrame.new(Origin, Origin + Direction)
		cosmeticBullet.Parent = Behavior.CosmeticBulletContainer
	end

	local castData = {
		ID = NextProjectileID,
		Origin = Origin,
		Velocity = Velocity,
		Acceleration = Behavior.Acceleration,
		RaycastParams = raycastParams,
		MaxDistance = Behavior.MaxDistance or 1000,
		CosmeticBulletObject = cosmeticBullet,
		CastType = EnumCastTypes.Blockcast,
		Size = Size,
		VisualizeCasts = Behavior.VisualizeCasts,
		VisualizeCastSettings = Behavior.VisualizeCastSettings,
		HighFidelitySegmentSize = Behavior.HighFidelitySegmentSize,
		HighFidelityBehavior = Behavior.HighFidelityBehavior,
		MovementMethod = Behavior.MovementMethod or "BulkMoveTo"
	}

	local cast = ActiveCastSerial.new(ParentCaster, castData)
	SerialSimulation.Register(cast)

	if Output then
		Output:Fire("CastFire", cast, Origin, Direction, Velocity, Behavior)
	end
end

--[=[
	@method Spherecast
	@within BaseCastSerial
]=]
function BaseCastSerial:Spherecast(
	Origin: Vector3,
	Radius: number,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1

	if typeof(Velocity) == "number" then
		Velocity = Direction.Unit * Velocity
	end

	local raycastParams = Behavior.RaycastParams
	if raycastParams then
		raycastParams = CloneCastParams(raycastParams)
	else
		raycastParams = RaycastParams.new()
	end

	local cosmeticBullet = Behavior.CosmeticBulletTemplate
	if cosmeticBullet then
		cosmeticBullet = cosmeticBullet:Clone()
		cosmeticBullet.CFrame = CFrame.new(Origin, Origin + Direction)
		cosmeticBullet.Parent = Behavior.CosmeticBulletContainer
	end

	local castData = {
		ID = NextProjectileID,
		Origin = Origin,
		Velocity = Velocity,
		Acceleration = Behavior.Acceleration,
		RaycastParams = raycastParams,
		MaxDistance = Behavior.MaxDistance or 1000,
		CosmeticBulletObject = cosmeticBullet,
		CastType = EnumCastTypes.Spherecast,
		Radius = Radius,
		VisualizeCasts = Behavior.VisualizeCasts,
		VisualizeCastSettings = Behavior.VisualizeCastSettings,
		HighFidelitySegmentSize = Behavior.HighFidelitySegmentSize,
		HighFidelityBehavior = Behavior.HighFidelityBehavior,
		MovementMethod = Behavior.MovementMethod or "BulkMoveTo"
	}

	local cast = ActiveCastSerial.new(ParentCaster, castData)
	SerialSimulation.Register(cast)

	if Output then
		Output:Fire("CastFire", cast, Origin, Direction, Velocity, Behavior)
	end
end

--[=[
	@method BindBulkMoveTo
	@within BaseCastSerial
]=]
function BaseCastSerial:BindBulkMoveTo(enabled: boolean)
	-- BulkMoveTo is now handled by SerialSimulation directly
end

--[=[
	@method BindObjectCache
	@within BaseCastSerial
]=]
function BaseCastSerial:BindObjectCache(bool: boolean)
	if bool then
		if ObjectCache then return end
		ObjectCache = Instance.new("BindableFunction")
		ObjectCache.Name = "ObjectCache"
	else
		if ObjectCache then
			ObjectCache:Destroy()
			ObjectCache = nil
		end
	end
end

--[=[
	@method TerminateCast
	@within BaseCastSerial
]=]
function BaseCastSerial:TerminateCast(cast: any, castTerminatingFunction: TypeDef.OnCastTerminatingFunction?)
	if cast and cast.ID then
		SerialSimulation.Terminate(cast.ID)
	end
	if castTerminatingFunction then
		castTerminatingFunction(cast)
	end
	if Output then
		Output:Fire("CastTerminating", cast)
	end
end

--[=[
	@method Destroy
	@within BaseCastSerial
]=]
function BaseCastSerial:Destroy()
	if BulkMoveToConnection then
		BulkMoveToConnection:Disconnect()
		BulkMoveToConnection = nil
	end

	Output = nil
	ParentCaster = nil
	setmetatable(self, nil)
end

return BaseCastSerial