--[[
	- Author : Mawin CK
	- Date : 2025

]]

local FastCast2 = script.Parent

local FastCastEnums = require(FastCast2:WaitForChild("FastCastEnums"))
local ActiveCast = require(FastCast2:WaitForChild("ActiveCast"))
local TypeDef = require(FastCast2:WaitForChild("TypeDefinitions"))
local ParallelSimulation = require(FastCast2:WaitForChild("ParallelSimulation"))
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
local Output = nil
local ObjectCacheInstance: any = nil
local Motor6DCacheInstance: any = nil
local NextProjectileID = 0
local SyncChanges: BindableEvent = nil
local SyncChangesConnection: RBXScriptConnection? = nil
local CastFireFunc = nil
local CurrentMovementMode: "BulkMoveTo" | "Motor6D" = "BulkMoveTo"

local function SendCastFire(
	cast: TypeDef.ActiveCastData,
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: TypeDef.FastCastBehavior
)
	(cast.Caster :: any).Output:Fire("CastFire", cast, origin, direction, velocity, behavior)
end

local function TerminateCast(cast: any, castTerminatingFunction: TypeDef.OnCastTerminatingFunction?)
	if cast._Destroying then return end
	cast._Destroying = true

	local FastCastEventsConfig = cast.StateInfo.FastCastEventsConfig
	if FastCastEventsConfig and FastCastEventsConfig.UseCastTerminating then
		cast.Caster.Output:Fire("CastTerminating", cast)
	end

	if castTerminatingFunction then
		castTerminatingFunction((cast :: any))
	end

	if cast.RayInfo and cast.RayInfo.CosmeticBulletObject then
		if ObjectCacheInstance then
			ObjectCacheInstance:ReturnPart(cast.RayInfo.CosmeticBulletObject)
		else
			cast.RayInfo.CosmeticBulletObject:Destroy()
		end
	end
	table.clear(cast :: any)
end

local BaseCastInitialized = false
local BaseCastInstance = nil
function BaseCast.Init(BindableOutput: BindableEvent, Data: any)
	if BaseCastInitialized then
		return BaseCastInstance
	end
	BaseCastInitialized = true

	local self = setmetatable({}, BaseCast)
	Actor = BindableOutput.Parent
	self.Actives = {}
	self.Actor = Actor
	Output = BindableOutput

	Actor:SetAttribute("FastCast2Ready", true)

	if Data.useObjectCache then
		local objectCacheArgs = Data.objectCacheArgs or {}
		if not objectCacheArgs.Template then
			error("Template must be provided when enabling ObjectCache.")
		end
		objectCacheArgs.CacheSize = objectCacheArgs.CacheSize or DEFAULT_CACHE_SIZE
		objectCacheArgs.CacheHolder = objectCacheArgs.CacheHolder or DEFAULT_CACHE_HOLDER
		ObjectCacheInstance = ObjectCache.new(objectCacheArgs.Template, objectCacheArgs.CacheSize, objectCacheArgs.CacheHolder) :: any
	end

	self.ObjectCacheInstance = ObjectCacheInstance
	self.CacheHolder = ObjectCacheInstance and ObjectCacheInstance.CacheHolder or nil

	CurrentMovementMode = Data.movementMode or "BulkMoveTo"
	if CurrentMovementMode == "Motor6D" then
		Motor6DCacheInstance = Motor6DCache.new()
	end

	Actor:BindToMessage("Cleanup", function(activeCastID: number)
		if self.Actives[activeCastID] then
			local cast = self.Actives[activeCastID]
			if cast.RayInfo and cast.RayInfo.CosmeticBulletObject then
				if ObjectCacheInstance then
					ObjectCacheInstance:ReturnPart(cast.RayInfo.CosmeticBulletObject)
				else
					cast.RayInfo.CosmeticBulletObject:Destroy()
					cast.RayInfo.CosmeticBulletObject = nil
				end
			end
			self.Actives[activeCastID] = nil
			ParallelSimulation.Unregister(activeCastID)
		end
	end)

	SyncChanges = Instance.new("BindableEvent")
	SyncChanges.Name = "SyncChanges"
	SyncChanges.Parent = Actor

	SyncChangesConnection = SyncChanges.Event:Connect(function(cast: TypeDef.ActiveCastData)
		local ID = cast.ID
		local TargetCast = self.Actives[ID]
		if TargetCast then
			for i, v in cast do
				if i == "StateInfo" and type(v) == "table" and type(TargetCast[i]) == "table" then
					for k, v2 in v do
						if k == "Trajectory" and type(v2) == "table" and type(TargetCast[i][k]) == "table" then
							for tk, tv in v2 do
								TargetCast[i][k][tk] = tv
							end
						else
							TargetCast[i][k] = v2
						end
					end
				else
					TargetCast[i] = v
				end
			end
		end
	end)

	ParallelSimulation.Init(self)
	ParallelSimulation.SetMovementModeEnabled(true, CurrentMovementMode)
	ParallelSimulation.Start()

	BaseCastInstance = self
	return self
end

function BaseCast:Raycast(Origin: Vector3, Direction: Vector3, Velocity: Vector3 | number, Behavior: TypeDef.FastCastBehavior)
	NextProjectileID += 1
	local cast = ActiveCast.createCastData({
		Output = Output,
		Actor = Actor,
		SyncChange = SyncChanges,
		CacheHolder = self.CacheHolder
	}, NextProjectileID, Origin, Direction, Velocity, Behavior, FastCastEventsModule, {
		CastType = EnumCastTypes.Raycast
	} :: any, self.ObjectCacheInstance, true)
	ParallelSimulation.Register(cast)
	self.Actives[cast.ID] = cast
	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(cast, Origin, Direction, Velocity, Behavior)
	end
	if Behavior.FastCastEventsModuleConfig.UseCastFire and CastFireFunc then
		CastFireFunc(cast, Origin, Direction, Velocity, Behavior)
	end
end

function BaseCast:SetFastCastEventsModule(moduleScript: ModuleScript?)
	if moduleScript ~= nil and (typeof(moduleScript) ~= "Instance" or not moduleScript:IsA("ModuleScript")) then
		error("FastCastEventsModule must be a ModuleScript")
	end

	FastCastEventsModule = moduleScript
	CastFireFunc = nil
	if moduleScript then
		local events = require(moduleScript)
		if type(events) ~= "table" then
			error("FastCastEventsModule must return a table")
		end
		if type(events.CastFire) == "function" then
			CastFireFunc = events.CastFire
		end
	end
end

function BaseCast:Blockcast(Origin: Vector3, Size: Vector3, Direction: Vector3, Velocity: Vector3 | number, Behavior: TypeDef.FastCastBehavior)
	NextProjectileID += 1
	local cast = ActiveCast.createCastData({
		Output = Output,
		Actor = Actor,
		SyncChange = SyncChanges,
		CacheHolder = self.CacheHolder
	}, NextProjectileID, Origin, Direction, Velocity, Behavior, FastCastEventsModule, {
		CastType = EnumCastTypes.Blockcast,
		Size = Size
	} :: any, self.ObjectCacheInstance, true)
	ParallelSimulation.Register(cast)
	self.Actives[cast.ID] = cast
	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(cast, Origin, Direction, Velocity, Behavior)
	end
	if Behavior.FastCastEventsModuleConfig.UseCastFire and CastFireFunc then
		CastFireFunc(cast, Origin, Direction, Velocity, Behavior)
	end
end

function BaseCast:Spherecast(Origin: Vector3, Radius: number, Direction: Vector3, Velocity: Vector3 | number, Behavior: TypeDef.FastCastBehavior)
	NextProjectileID += 1
	local cast = ActiveCast.createCastData({
		Output = Output,
		Actor = Actor,
		SyncChange = SyncChanges,
		CacheHolder = self.CacheHolder
	}, NextProjectileID, Origin, Direction, Velocity, Behavior, FastCastEventsModule, {
		CastType = EnumCastTypes.Spherecast,
		Radius = Radius
	} :: any, self.ObjectCacheInstance, true)
	ParallelSimulation.Register(cast)
	self.Actives[cast.ID] = cast
	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(cast, Origin, Direction, Velocity, Behavior)
	end
	if Behavior.FastCastEventsModuleConfig.UseCastFire and CastFireFunc then
		CastFireFunc(cast, Origin, Direction, Velocity, Behavior)
	end
end

function BaseCast:SetMovementModeEnabled(enabled: boolean, mode: "BulkMoveTo" | "Motor6D")
	CurrentMovementMode = mode
	if mode == "Motor6D" and enabled then
		if not Motor6DCacheInstance then Motor6DCacheInstance = Motor6DCache.new() end
	else
		if Motor6DCacheInstance then Motor6DCacheInstance:Destroy(); Motor6DCacheInstance = nil end
	end
	ParallelSimulation.SetMovementModeEnabled(enabled, mode)
end

function BaseCast:BindObjectCache(enabled: boolean, Template: BasePart | Model?, CacheSize: number?, CacheHolder: Instance?)
	if enabled then
		if self.ObjectCacheInstance then return end
		if not Template then error("Template must be provided when enabling ObjectCache.") end
		local cache = ObjectCache.new(Template, CacheSize or DEFAULT_CACHE_SIZE, CacheHolder or DEFAULT_CACHE_HOLDER)
		self.ObjectCacheInstance = cache
		ObjectCacheInstance = cache
		self.CacheHolder = cache.CacheHolder
	else
		if self.ObjectCacheInstance then self.ObjectCacheInstance:Destroy() end
		self.ObjectCacheInstance = nil
		self.CacheHolder = nil
		ObjectCacheInstance = nil
	end
end

function BaseCast:Destroy()
	if ParallelSimulation then ParallelSimulation.Stop() end
	if self.ObjectCacheInstance then self.ObjectCacheInstance:Destroy() end
	if Motor6DCacheInstance then Motor6DCacheInstance:Destroy() end
	FastCastEventsModule = nil
	CastFireFunc = nil
	ObjectCacheInstance = nil
	if SyncChangesConnection then SyncChangesConnection:Disconnect(); SyncChangesConnection = nil end
	local activeList = {}
	for _, v in self.Actives do table.insert(activeList, v) end
	for _, v in activeList do TerminateCast(v) end
	self.Actives = {}
	setmetatable(self, nil)
end

function BaseCast:_GetMotor6D(projectilePart: BasePart?)
	if Motor6DCacheInstance and projectilePart then return Motor6DCacheInstance:Connect(projectilePart) end
	return nil
end

function BaseCast:_ReturnMotor6D(motor6d: Motor6D?)
	if Motor6DCacheInstance then Motor6DCacheInstance:Disconnect(motor6d) end
end

return BaseCast
