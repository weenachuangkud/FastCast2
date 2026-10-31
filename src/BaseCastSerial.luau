--[[
	- Author : Mawin CK
	- Date : 2025

]]

local FastCast2 = script.Parent

local SerialSimulation = require(script.Parent.SerialSimulation)
local ActiveCast = require(FastCast2:WaitForChild("ActiveCast"))
local TypeDef = require(FastCast2:WaitForChild("TypeDefinitions"))
local Motor6DCache = require(FastCast2:WaitForChild("Motor6DCache"))

local CAST_TYPE_RAYCAST = 1
local CAST_TYPE_BLOCKCAST = 2
local CAST_TYPE_SPHERECAST = 3

local BaseCast = {}

local NextProjectileID = 0
local Actives = {}
local Initialized = false
local Motor6DCacheInstance = nil
local CurrentMovementMode = "BulkMoveTo"

function BaseCast.Init(movementMode: "BulkMoveTo" | "Motor6D"?)
	if Initialized then
		warn("[FastCast2] FastCast.Init() has already been called. Skipping.")
		return
	end

	CurrentMovementMode = movementMode or "BulkMoveTo"

	if CurrentMovementMode == "Motor6D" then
		Motor6DCacheInstance = Motor6DCache.new()
	end

	SerialSimulation.Init(BaseCast, Actives)
	SerialSimulation.SetMovementModeEnabled(true, CurrentMovementMode)
	SerialSimulation.Start()
	Initialized = true
end

function BaseCast.RegisterCaster(casterId: number, events: any)
	SerialSimulation.RegisterCaster(casterId, events)
end

local function FireCastFire(caster: any, cast, origin, direction, velocity, behavior)
	local events = caster._events
	local CastFireEvent = events and events.CastFire

	if CastFireEvent and CastFireEvent:HasListeners() then
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
		CastType = CAST_TYPE_RAYCAST
	} :: any)

	cast.CasterId = caster.CasterId
	SerialSimulation.Register(cast)
	Actives[cast.ID] = cast
	FireCastFire(caster, cast, Origin, Direction, Velocity, Behavior)
	return cast
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
		CastType = CAST_TYPE_BLOCKCAST,
		Size = Size
	} :: any)

	cast.CasterId = caster.CasterId
	SerialSimulation.Register(cast)
	Actives[cast.ID] = cast
	FireCastFire(caster, cast, Origin, Direction, Velocity, Behavior)
	return cast
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
		CastType = CAST_TYPE_SPHERECAST,
		Radius = Radius
	} :: any)

	cast.CasterId = caster.CasterId
	SerialSimulation.Register(cast)
	Actives[cast.ID] = cast
	FireCastFire(caster, cast, Origin, Direction, Velocity, Behavior)
	return cast
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
	local casterId = caster.CasterId
	local castIDs = {}
	for castID, cast in Actives do
		if cast.CasterId == casterId then
			table.insert(castIDs, castID)
		end
	end

	for _, castID in castIDs do
		BaseCast._TerminateCast(castID)
	end

	SerialSimulation.UnregisterCaster(casterId)
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
