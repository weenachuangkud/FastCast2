--[[
	- Author : Mawin CK
	- Date : 2025

]]

local FastCast2 = script.Parent

local SerialSimulation = require(script.Parent.SerialSimulation)
local FastCastEnums = require(FastCast2:WaitForChild("FastCastEnums"))
local ActiveCast = require(FastCast2:WaitForChild("ActiveCast"))
local TypeDef = require(FastCast2:WaitForChild("TypeDefinitions"))
local Motor6DCache = require(FastCast2:WaitForChild("Motor6DCache"))

local EnumCastTypes = FastCastEnums.CastType

local BaseCast = {}

local NextProjectileID = 0
local Actives = {}
local Initialized = false
local Motor6DCacheInstance = nil
local CurrentMovementMode = "BulkMoveTo"

function BaseCast.Init(events: any, Data: any)
	if Initialized then
		return
	end

	Data = Data or {}
	CurrentMovementMode = Data.movementMode or "BulkMoveTo"

	if CurrentMovementMode == "Motor6D" then
		Motor6DCacheInstance = Motor6DCache.new()
	end

	SerialSimulation.Init(BaseCast, Actives, events)
	SerialSimulation.SetMovementModeEnabled(true, CurrentMovementMode)
	SerialSimulation.Start()
	Initialized = true
end

local function FireCastFire(cast, origin, direction, velocity, behavior)
	local events = cast._FastCastEvents
	local CastFireEvent = events and events.CastFire

	if behavior.FastCastEventsConfig.UseCastFire and CastFireEvent then
		CastFireEvent:Fire(cast, origin, direction, velocity, behavior)
	end
end

function BaseCast.Raycast(
	caster: any,
	Origin: Vector3,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1
	local cast = ActiveCast.createCastData(BaseCast, NextProjectileID, Origin, Direction, Velocity, Behavior, {
		CastType = EnumCastTypes.Raycast
	} :: any)

	cast._Caster = caster
	cast._FastCastEvents = caster._events
	SerialSimulation.Register(cast)
	Actives[cast.ID] = cast
	FireCastFire(cast, Origin, Direction, Velocity, Behavior)
end

function BaseCast.Blockcast(
	caster: any,
	Origin: Vector3,
	Size: Vector3,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1
	local cast = ActiveCast.createCastData(BaseCast, NextProjectileID, Origin, Direction, Velocity, Behavior, {
		CastType = EnumCastTypes.Blockcast,
		Size = Size
	} :: any)

	SerialSimulation.Register(cast)
	Actives[cast.ID] = cast
	FireCastFire(cast, Origin, Direction, Velocity, Behavior)
end

function BaseCast.Spherecast(
	caster: any,
	Origin: Vector3,
	Radius: number,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1
	local cast = ActiveCast.createCastData(BaseCast, NextProjectileID, Origin, Direction, Velocity, Behavior, {
		CastType = EnumCastTypes.Spherecast,
		Radius = Radius
	} :: any)

	SerialSimulation.Register(cast)
	Actives[cast.ID] = cast
	FireCastFire(cast, Origin, Direction, Velocity, Behavior)
end

function BaseCast.SetMovementModeEnabled(enabled: boolean, mode: "BulkMoveTo" | "Motor6D")
	CurrentMovementMode = mode

	if mode == "Motor6D" and enabled then
		if not Motor6DCacheInstance then
			Motor6DCacheInstance = Motor6DCache.new()
		end
	else
		if Motor6DCacheInstance then
			Motor6DCacheInstance:Destroy()
			Motor6DCacheInstance = nil
		end
	end

	SerialSimulation.SetMovementModeEnabled(enabled, mode)
end

function BaseCast.Destroy(caster: any)
	local castIDs = {}
	for castID, cast in Actives do
		if cast._Caster == caster then
			table.insert(castIDs, castID)
		end
	end

	for _, castID in castIDs do
		BaseCast._TerminateCast(castID)
	end
end

function BaseCast._TerminateCast(castID: number)
	local cast = Actives[castID]
	if not cast then
		return
	end

	table.clear(cast :: any)
	Actives[castID] = nil

	SerialSimulation.Unregister(castID)
end

function BaseCast._GetMotor6D(projectilePart: BasePart?)
	if Motor6DCacheInstance and projectilePart then
		return Motor6DCacheInstance:Connect(projectilePart)
	end
	return nil
end

function BaseCast._ReturnMotor6D(motor6d: Motor6D?)
	if Motor6DCacheInstance then
		Motor6DCacheInstance:Disconnect(motor6d)
	end
end

return BaseCast
