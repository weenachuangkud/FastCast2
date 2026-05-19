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
BaseCast.__index = BaseCast
BaseCast.__type = "BaseCast"

local DEFAULT_CACHE_SIZE = 500
local DEFAULT_CACHE_HOLDER = workspace

local NextProjectileID = 0

local function TerminateCast(cast: any, castTerminatingFunction: TypeDef.OnCastTerminatingFunction?)
	if castTerminatingFunction then
		castTerminatingFunction((cast :: any))
	end

	for key, _ in (cast :: any) do
		cast[key] = nil
	end
end


function BaseCast.Init(events: TypeDef.FastCastEvents, Data: any)
	local self = setmetatable({}, BaseCast)
	self.Actives = {}
	self.CastFirefn = events.CastFire
	self.Motor6DCacheInstance = nil
	self.ObjectCacheInstance = nil
	self.CurrentMovementMode = "BulkMoveTo"

	if Data.useObjectCache then
		local objectCacheArgs = Data.objectCacheArgs or {}
		if not objectCacheArgs.CacheSize then
			objectCacheArgs.CacheSize = DEFAULT_CACHE_SIZE
		end

		if not objectCacheArgs.CacheHolder then
			objectCacheArgs.CacheHolder = DEFAULT_CACHE_HOLDER
		end

		self.ObjectCacheInstance = ObjectCache.new(objectCacheArgs.Template, objectCacheArgs.CacheSize, objectCacheArgs.CacheHolder) :: any
	end

	self.CurrentMovementMode = Data.movementMode or "BulkMoveTo"
	if self.CurrentMovementMode == "Motor6D" then
		self.Motor6DCacheInstance = Motor6DCache.new()
	end

	self.SerialSimulation = SerialSimulation.new()
	self.SerialSimulation:Init(self, events)

	self.SerialSimulation:SetMovementMode(self.CurrentMovementMode, true)

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
	NextProjectileID += 1
	local cast = ActiveCast.createCastData(self, NextProjectileID, Origin, Direction, Velocity, Behavior, nil, {
		CastType = EnumCastTypes.Raycast
	} :: any, self.ObjectCacheInstance)

self.SerialSimulation:Register(cast)
	self.Actives[cast.ID] = cast

	if Behavior.FastCastEventsConfig.UseCastFire and self.CastFirefn then
		self.CastFirefn(cast, Origin, Direction, Velocity, Behavior)
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
function BaseCast:Blockcast(
	Origin: Vector3,
	Size: Vector3,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1

	local cast = ActiveCast.createCastData(self, NextProjectileID, Origin, Direction, Velocity, Behavior, nil, {
		CastType = EnumCastTypes.Blockcast,
		Size = Size
	} :: any, self.ObjectCacheInstance)

	self.SerialSimulation:Register(cast)
	self.Actives[cast.ID] = cast

	if Behavior.FastCastEventsConfig.UseCastFire and self.CastFirefn then
		self.CastFirefn(cast, Origin, Direction, Velocity, Behavior)
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

	local cast = ActiveCast.createCastData(self, NextProjectileID, Origin, Direction, Velocity, Behavior, nil, {
		CastType = EnumCastTypes.Spherecast,
		Radius = Radius
	} :: any, self.ObjectCacheInstance)

self.SerialSimulation:Register(cast)
	self.Actives[cast.ID] = cast

	if Behavior.FastCastEventsConfig.UseCastFire and self.CastFirefn then
		self.CastFirefn(cast, Origin, Direction, Velocity, Behavior)
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
	self.CurrentMovementMode = mode

	if mode == "Motor6D" and enabled then
		if not self.Motor6DCacheInstance then
			self.Motor6DCacheInstance = Motor6DCache.new()
		end
	else 
		if self.Motor6DCacheInstance then
			self.Motor6DCacheInstance:Destroy()
			self.Motor6DCacheInstance = nil
		end
	end

	self.SerialSimulation:SetMovementMode(mode, enabled)
end

function BaseCast:BindObjectCache(
	enabled: boolean,
	Template: BasePart?,
	CacheSize: number?,
	CacheHolder: Instance?
)
	if enabled then
		if self.ObjectCacheInstance then
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
		self.ObjectCacheInstance = ObjectCache.new(Template, CacheSize, CacheHolder)
	else
		if self.ObjectCacheInstance then
			self.ObjectCacheInstance:Destroy()
			self.ObjectCacheInstance = nil
		end
	end
end

--[=[

@method Destroy
@within BaseCast

Destroys the BaseCast instance and cleans up resources.

]=]
function BaseCast:Destroy()
	if self.SerialSimulation then
		self.SerialSimulation:Stop()
	end

	if self.ObjectCacheInstance then
		self.ObjectCacheInstance:Destroy()
	end

	if self.Motor6DCacheInstance then
		self.Motor6DCacheInstance:Destroy()
	end

	for _, v in self.Actives do
		TerminateCast(v)
	end

	self.Actives = {}
	setmetatable(self, nil)
end

-- Motor6D

function BaseCast:_GetMotor6D(projectilePart: BasePart?)
	if self.Motor6DCacheInstance and projectilePart then
		return self.Motor6DCacheInstance:Connect(projectilePart)
	end
	return nil
end

function BaseCast:_ReturnMotor6D(motor6d: Motor6D?)
	if self.Motor6DCacheInstance then
		self.Motor6DCacheInstance:Disconnect(motor6d)
	end
end

function BaseCast:_UpdateEvents(eventName: string, newEventfn: (...any) -> ())
	self.SerialSimulation:_UpdateEvents(eventName, newEventfn)
end

return BaseCast
