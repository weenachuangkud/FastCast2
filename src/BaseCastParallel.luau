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
local ActiveCastCleaner: BindableEvent = nil
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

	cast.Caster.ActiveCastCleaner:Fire(cast.ID)

	for key, _ in (cast :: any) do
		cast[key] = nil
	end
end

function BaseCast.Init(BindableOutput: BindableEvent, Data: any)
	local self = setmetatable({}, BaseCast)
	Actor = BindableOutput.Parent
	self.Actives = {}
	Output = BindableOutput

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

	ActiveCastCleaner = BindableCleaner

	ActiveCastCleaner.Event:Connect(function(activeCastID: number)
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
			Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks") - 1)
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

	local cast = ActiveCast.createCastData({
		Output = Output,
		ActiveCastCleaner = ActiveCastCleaner,
		SyncChange = SyncChanges
	}, NextProjectileID, Origin, Direction, Velocity, Behavior, FastCastEventsModule, {
		CastType = EnumCastTypes.Raycast
	} :: any, ObjectCacheInstance, true)

	ParallelSimulation.Register(cast)
	self.Actives[cast.ID] = cast

	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(cast, Origin, Direction, Velocity, Behavior)
	end
	if Behavior.FastCastEventsModuleConfig.UseCastFire and CastFireFunc then
		CastFireFunc(cast, Origin, Direction, Velocity, Behavior)
	end
end

--[=[

@method SetFastCastEventsModule
@within BaseCast

@param moduleScript ModuleScript -- The FastCastEventsModule to set.

]=]
function BaseCast:SetFastCastEventsModule(moduleScript: ModuleScript)
	FastCastEventsModule = moduleScript
	if moduleScript and typeof(moduleScript) == "Instance" and moduleScript:IsA("ModuleScript") then
		CastFireFunc = require(moduleScript)
		if CastFireFunc.CastFire then
			CastFireFunc = CastFireFunc.CastFire
		else
			CastFireFunc = nil
		end
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
	Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks") + 1)
	NextProjectileID += 1

	local cast = ActiveCast.createCastData({
		Output = Output,
		ActiveCastCleaner = ActiveCastCleaner,
		SyncChange = SyncChanges
	}, NextProjectileID, Origin, Direction, Velocity, Behavior, FastCastEventsModule, {
		CastType = EnumCastTypes.Blockcast,
		Size = Size
	} :: any, ObjectCacheInstance, true)

	ParallelSimulation.Register(cast)
	self.Actives[cast.ID] = cast

	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(cast, Origin, Direction, Velocity, Behavior)
	end
	if Behavior.FastCastEventsModuleConfig.UseCastFire and CastFireFunc then
		CastFireFunc(cast, Origin, Direction, Velocity, Behavior)
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
	Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks") + 1)
	NextProjectileID += 1

	local cast = ActiveCast.createCastData({
		Output = Output,
		ActiveCastCleaner = ActiveCastCleaner,
		SyncChange = SyncChanges
	}, NextProjectileID, Origin, Direction, Velocity, Behavior, FastCastEventsModule, {
		CastType = EnumCastTypes.Spherecast,
		Radius = Radius
	} :: any,  ObjectCacheInstance, true)

	ParallelSimulation.Register(cast)
	self.Actives[cast.ID] = cast

	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(cast, Origin, Direction, Velocity, Behavior)
	end
	if Behavior.FastCastEventsModuleConfig.UseCastFire and CastFireFunc then
		CastFireFunc(cast, Origin, Direction, Velocity, Behavior)
	end
end

--[=[
	@method SetMovementModeEnabled
	@within BaseCast

	@param mode "BulkMoveTo" | "Motor6D" -- The movement mode to set.
	@param enabled boolean -- Whether to enable or disable the movement mode.

	Sets the movement mode for the casts. This determines how the cast's position is updated during simulation.

]=]
function BaseCast:SetMovementModeEnabled(enabled: boolean, mode: "BulkMoveTo" | "Motor6D")
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

	ParallelSimulation.SetMovementModeEnabled(enabled, mode)
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
	if ParallelSimulation then
		ParallelSimulation.Stop()
	end

	if ObjectCacheInstance then
		ObjectCacheInstance:Destroy()
	end

	if Motor6DCacheInstance then
		Motor6DCacheInstance:Destroy()
	end

	FastCastEventsModule = nil

	if SyncChangesConnection then
		SyncChangesConnection:Disconnect()
		SyncChangesConnection = nil
	end

	local activeList = {}
	for _, v in self.Actives do
		table.insert(activeList, v)
	end
	for _, v in activeList do
		TerminateCast(v)
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
