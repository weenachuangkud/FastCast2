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

	CastFirefn = if type(events.CastFire) == "function" then events.CastFire else nil
	Motor6DCacheInstance = nil
	ObjectCacheInstance = nil
	BaseCast.CacheHolder = nil
	CurrentMovementMode = "BulkMoveTo"

	Data = Data or {}
	if Data.useObjectCache then
		local objectCacheArgs = Data.objectCacheArgs or {}
		local template = objectCacheArgs.Template
		if not template then
			error("Template must be provided when enabling ObjectCache.")
		end

		local cacheSize = objectCacheArgs.CacheSize or DEFAULT_CACHE_SIZE
		local cacheHolder = objectCacheArgs.CacheHolder or DEFAULT_CACHE_HOLDER
		ObjectCacheInstance = ObjectCache.new(template, cacheSize, cacheHolder) :: any
		BaseCast.CacheHolder = ObjectCacheInstance.CacheHolder
	end

	CurrentMovementMode = Data.movementMode or "BulkMoveTo"
	if CurrentMovementMode == "Motor6D" then
		Motor6DCacheInstance = Motor6DCache.new()
	end

	SerialSimulation.Init(BaseCast, Actives, events)
	SerialSimulation.SetMovementModeEnabled(true, CurrentMovementMode)
	SerialSimulation.Start()
end

local function FireCastFire(cast, origin, direction, velocity, behavior)
	if behavior.FastCastEventsConfig.UseCastFire and CastFirefn then
		CastFirefn(cast, origin, direction, velocity, behavior)
	end
end

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
	FireCastFire(cast, Origin, Direction, Velocity, Behavior)
end

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
	FireCastFire(cast, Origin, Direction, Velocity, Behavior)
end

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

function BaseCast.BindObjectCache(
	enabled: boolean,
	Template: BasePart | Model?,
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

		ObjectCacheInstance = ObjectCache.new(
			Template,
			CacheSize or DEFAULT_CACHE_SIZE,
			CacheHolder or DEFAULT_CACHE_HOLDER
		)
		BaseCast.CacheHolder = ObjectCacheInstance.CacheHolder
	else
		if ObjectCacheInstance then
			ObjectCacheInstance:Destroy()
		end
		ObjectCacheInstance = nil
		BaseCast.CacheHolder = nil
	end
end

function BaseCast.Destroy()
	if SerialSimulation then
		SerialSimulation.Stop()
	end

	local castIDs = {}
	for castID in Actives do
		table.insert(castIDs, castID)
	end
	for _, castID in castIDs do
		BaseCast._TerminateCast(castID)
	end
	Actives = {}

	if ObjectCacheInstance then
		ObjectCacheInstance:Destroy()
		ObjectCacheInstance = nil
	end
	BaseCast.CacheHolder = nil

	if Motor6DCacheInstance then
		Motor6DCacheInstance:Destroy()
		Motor6DCacheInstance = nil
	end

	CastFirefn = nil
end

function BaseCast._TerminateCast(castID: number)
	local cast = Actives[castID]
	if not cast then
		return
	end

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
