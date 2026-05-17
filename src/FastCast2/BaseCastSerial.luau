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
local FastCastEventsModule: ModuleScript? = nil

local EnumCastTypes = FastCastEnums.CastType

local BaseCast = {}
BaseCast.__index = BaseCast
BaseCast.__type = "BaseCast"

local DEFAULT_CACHE_SIZE = 500
local DEFAULT_CACHE_HOLDER = workspace

local Actor = nil
local ObjectCacheInstance: any = nil
local Motor6DCacheInstance: any = nil
local NextProjectileID = 0
local CurrentMovementMode: "BulkMoveTo" | "Motor6D" = "BulkMoveTo"

local function SendCastFire(
	cast: TypeDef.ActiveCastData,
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: TypeDef.FastCastBehavior
)
	cast.Caster.Output:Fire("CastFire", cast, origin, direction, velocity, behavior)
end

function BaseCast.Init(events: TypeDef.FastCastEvents, Data: any)
	local self = setmetatable({}, BaseCast)
	self.Actives = {}

	local BindableCleaner = Instance.new("BindableEvent")
	BindableCleaner.Name = "ActiveCastDestroyer"
	BindableCleaner.Parent = Actor

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

	self.SerialSimulation = SerialSimulation.new()
	self.SerialSimulation:Init(self, events)

	self.SerialSimulation:SetMovementMode(CurrentMovementMode, true)

	self.SerialSimulation:Start()

	return self
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
function BaseCast:Raycast(
	Origin: Vector3,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks") + 1)
	NextProjectileID += 1

	local cast = ActiveCast.createCastData(nil, NextProjectileID, Origin, Direction, Velocity, Behavior, FastCastEventsModule, {
		CastType = EnumCastTypes.Raycast
	} :: any, ObjectCacheInstance, true)

	SerialSimulation.Register(cast)
	self.Actives[cast.ID] = cast

	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(cast, Origin, Direction, Velocity, Behavior)
	end
end

--[=[

@method Blockcast
@within BaseCast

@param Origin Vector3 -- The origin of the blockcast.
@param Size Vector3 -- The size of the blockcast.
@param Direction Vector3 -- The direction of the blockcast.
@param Velocity Vector3 | number -- The velocity of the blockcast.
@param Behavior FastCastBehavior -- The behavior data for the blockcast.

Create a Blockcast.

]=]
function BaseCast:Blockcast(
	Origin: Vector3,
	Size: Vector3,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1

	local cast = ActiveCast.createCastData(nil, NextProjectileID, Origin, Direction, Velocity, Behavior, FastCastEventsModule, {
		CastType = EnumCastTypes.Blockcast,
		Size = Size
	} :: any, ObjectCacheInstance, true)

	SerialSimulation.Register(cast)
	self.Actives[cast.ID] = cast

	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(cast, Origin, Direction, Velocity, Behavior)
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
function BaseCast:Spherecast(
	Origin: Vector3,
	Radius: number,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1

	local cast = ActiveCast.createCastData(nil, NextProjectileID, Origin, Direction, Velocity, Behavior, FastCastEventsModule, {
		CastType = EnumCastTypes.Spherecast,
		Radius = Radius
	} :: any,  ObjectCacheInstance)

	SerialSimulation.Register(cast)
	self.Actives[cast.ID] = cast

	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(cast, Origin, Direction, Velocity, Behavior)
	end
end

--[=[
	@method SetMovementMode
	@within BaseCast

	@param mode "BulkMoveTo" | "Motor6D" -- The movement mode to set.
	@param enabled boolean -- Whether to enable or disable the movement mode.

	Sets the movement mode for the casts. This determines how the cast's position is updated during simulation.

]=]
function BaseCast:SetMovementMode(mode: "BulkMoveTo" | "Motor6D", enabled: boolean)
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

	SerialSimulation.SetMovementMode(mode, enabled)
end

function BaseCast:BindObjectCache(
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
function BaseCast:Destroy()
	if SerialSimulation then
		SerialSimulation:Destroy()
	end

	if ObjectCacheInstance then
		ObjectCacheInstance:Destroy()
	end

	if Motor6DCacheInstance then
		Motor6DCacheInstance:Destroy()
	end

	FastCastEventsModule = nil

	for _, v in self.Actives do
		FastCastM:TerminateCast(v)
	end

	self.Actives = {}
	setmetatable(self, nil)
end

-- Motor6D

function BaseCast:_GetMotor6D(projectilePart: BasePart?)
	if Motor6DCacheInstance and projectilePart then
		return Motor6DCacheInstance:Connect(projectilePart)
	end
	return nil
end

function BaseCast:_ReturnMotor6D(motor6d: Motor6D?)
	if Motor6DCacheInstance then
		Motor6DCacheInstance:Disconnect(motor6d)
	end
end

return BaseCast
