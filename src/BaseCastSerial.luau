--[[
	- Author : Mawin CK
	- Date : 2025

]]

local FastCast2 = script.Parent

local SerialSimulation = require(script.Parent.SerialSimulation)
local FastCastEnums = require(FastCast2:WaitForChild("FastCastEnums"))
local ActiveCast = require(FastCast2:WaitForChild("ActiveCast"))
local TypeDef = require(FastCast2:WaitForChild("TypeDefinitions"))
local ObjectCache = require(FastCast2:WaitForChild("ObjectCache"))
local Motor6DCache = require(FastCast2:WaitForChild("Motor6DCache"))

local EnumCastTypes = FastCastEnums.CastType

--[=[
	@class BaseCast

	BaseCast is the underlying class that manages cast simulation, lifecycle, and movement modes.
	It is used internally by FastCastSerial and FastCastParallel.
]=]
local BaseCast = {}

local DEFAULT_CACHE_SIZE = 500
local DEFAULT_CACHE_HOLDER = workspace

local NextProjectileID = 0

local Actives = {}
local CastFirefn = nil
local Motor6DCacheInstance = nil
local ObjectCacheInstance = nil
local CurrentMovementMode = "BulkMoveTo"

function BaseCast.Init(events: any, Data: any)
	BaseCast.Destroy()

	CastFirefn = events.CastFire
	Motor6DCacheInstance = nil
	ObjectCacheInstance = nil
	CurrentMovementMode = "BulkMoveTo"

	if Data.useObjectCache then
		local objectCacheArgs = Data.objectCacheArgs or {}
		if not objectCacheArgs.CacheSize then
			objectCacheArgs.CacheSize = DEFAULT_CACHE_SIZE
		end

		if not objectCacheArgs.CacheHolder then
			objectCacheArgs.CacheHolder = DEFAULT_CACHE_HOLDER
		end

		ObjectCacheInstance = ObjectCache.new(objectCacheArgs.Template, objectCacheArgs.CacheSize, objectCacheArgs.CacheHolder) :: any
	end

	CurrentMovementMode = Data.movementMode or "BulkMoveTo"
	if CurrentMovementMode == "Motor6D" then
		Motor6DCacheInstance = Motor6DCache.new()
	end

	SerialSimulation.Init(BaseCast, Actives, events)

	SerialSimulation.SetMovementModeEnabled(true, CurrentMovementMode)

	SerialSimulation.Start()
end

--[=[

@method Raycast
@within BaseCast

@param Origin Vector3 -- The origin of the raycast.
@param Direction Vector3 -- The direction of the raycast.
@param Velocity Vector3 | number -- The velocity of the raycast.
@param Behavior FastCastBehavior -- The behavior data for the raycast.
@param GUID string -- The unique identifier for the raycast.

Create a raycast.

]=]
function BaseCast.Raycast(
	Origin: Vector3,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1
	local cast = ActiveCast.createCastData(BaseCast, NextProjectileID, Origin, Direction, Velocity, Behavior, nil, {
		CastType = EnumCastTypes.Raycast
	} :: any, ObjectCacheInstance)

	SerialSimulation.Register(cast)
	Actives[cast.ID] = cast

	if Behavior.FastCastEventsConfig.UseCastFire and CastFirefn then
		CastFirefn:Fire(cast, Origin, Direction, Velocity, Behavior)
	end
end

--[=[

@method Blockcast
@within BaseCast

@param Origin Vector3 -- The origin of the raycast.
@param Size Vector3 -- The size of the raycast.
@param Direction Vector3 -- The direction of the raycast.
@param Velocity Vector3 | number -- The velocity of the raycast.
@param Behavior FastCastBehavior -- The behavior data for the raycast.

Create a Blockcast.

]=]
function BaseCast.Blockcast(
	Origin: Vector3,
	Size: Vector3,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1

	local cast = ActiveCast.createCastData(BaseCast, NextProjectileID, Origin, Direction, Velocity, Behavior, nil, {
		CastType = EnumCastTypes.Blockcast,
		Size = Size
	} :: any, ObjectCacheInstance)

	SerialSimulation.Register(cast)
	Actives[cast.ID] = cast

	if Behavior.FastCastEventsConfig.UseCastFire and CastFirefn then
		CastFirefn:Fire(cast, Origin, Direction, Velocity, Behavior)
	end
end

--[=[

@method Spherecast
@within BaseCast

@param Origin Vector3 -- The origin of the spherecast.
@param Radius number -- The radius of the spherecast.
@param Direction Vector3 -- The direction of the spherecast.
@param Velocity Vector3 | number -- The velocity of the spherecast.
@param Behavior FastCastBehavior -- The behavior data for the spherecast.

Create a Spherecast.

]=]
function BaseCast.Spherecast(
	Origin: Vector3,
	Radius: number,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1

	local cast = ActiveCast.createCastData(BaseCast, NextProjectileID, Origin, Direction, Velocity, Behavior, nil, {
		CastType = EnumCastTypes.Spherecast,
		Radius = Radius
	} :: any, ObjectCacheInstance)

	SerialSimulation.Register(cast)
	Actives[cast.ID] = cast

	if Behavior.FastCastEventsConfig.UseCastFire and CastFirefn then
		CastFirefn:Fire(cast, Origin, Direction, Velocity, Behavior)
	end
end

--[=[

@method SetMovementModeEnabled
@within BaseCast

	@param mode "BulkMoveTo" | "Motor6D" -- The movement mode to set.
	@param enabled boolean -- Whether to enable or disable the movement mode.

	Sets the movement mode for the casts. This determines how the cast's position is updated during simulation.

]=]
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

function BaseCast.BindObjectCache(
	enabled: boolean,
	Template: BasePart?,
	CacheSize: number?,
	CacheHolder: Instance?
)
	if enabled then
		if ObjectCacheInstance then
			return
		end

		if not Template then
			error("Template must be provided when enabling ObjectCache.")
		end

		if not CacheSize then
			CacheSize = DEFAULT_CACHE_SIZE
		end

		if not CacheHolder then
			CacheHolder = DEFAULT_CACHE_HOLDER
		end
		ObjectCacheInstance = ObjectCache.new(Template, CacheSize, CacheHolder)
	else
		if ObjectCacheInstance then
			ObjectCacheInstance:Destroy()
			ObjectCacheInstance = nil
		end
	end
end

--[=[

@method Destroy
@within BaseCast

Destroys the BaseCast instance and cleans up resources.

]=]
function BaseCast.Destroy()
	SerialSimulation.Stop()

	if ObjectCacheInstance then
		ObjectCacheInstance:Destroy()
	end

	if Motor6DCacheInstance then
		Motor6DCacheInstance:Destroy()
	end

	local castIDs = {}
	for castID in Actives do
		table.insert(castIDs, castID)
	end
	for _, castID in castIDs do
		BaseCast._TerminateCast(castID)
	end

	Actives = {}
end

-- Utils

function BaseCast._TerminateCast(castID: number)
	if Actives[castID] then
		local cast = Actives[castID]

		if cast.RayInfo and cast.RayInfo.CosmeticBulletObject then
			if ObjectCacheInstance then
				ObjectCacheInstance:ReturnPart(cast.RayInfo.CosmeticBulletObject)
			else
				cast.RayInfo.CosmeticBulletObject:Destroy()
				cast.RayInfo.CosmeticBulletObject = nil
			end
		end

		table.clear(cast :: any)
		Actives[castID] = nil
	end
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
