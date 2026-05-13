--[[
	- Author : Mawin CK
	- Date : 2025

]]

local RS = game:GetService("RunService")

local FastCast2 = script.Parent
local FastCastM = require(FastCast2)

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

local MovementConnection: RBXScriptConnection? = nil

local Actives: any = {}
local Actor = nil
local Output = nil
local ActiveCastCleaner: BindableEvent = nil
local ObjectCacheInstance: any = nil
local Motor6DCacheInstance: any = nil
local NextProjectileID = 0
local SyncChanges: BindableEvent = nil
local CastFireFunc = nil
local CurrentMovementMode: "BulkMoveTo" | "Motor6D" = "BulkMoveTo"
local MovementEnabled = false
local SimulationConnection: RBXScriptConnection? = nil

local function CloneCastParams(params: RaycastParams): RaycastParams
	local clone: RaycastParams = RaycastParams.new()
	clone.CollisionGroup = params.CollisionGroup
	clone.FilterType = params.FilterType
	clone.FilterDescendantsInstances = params.FilterDescendantsInstances
	clone.IgnoreWater = params.IgnoreWater
	return clone
end

local function FireQueuedEvents()
	local events = ParallelSimulation.GetQueuedEvents()
	for _, event in events do
		local cast = Actives[event.castID]
		if not cast then continue end

		local rayInfo = cast.RayInfo
		local args = event.args
		if event.eventType == "LengthChanged" then
			if rayInfo.FastCastEventsConfig.UseLengthChanged then
				if rayInfo.FastCastEventsModuleConfig.UseLengthChanged and rayInfo.LengthChangedFunc then
					rayInfo.LengthChangedFunc(cast, args[1], args[2], args[3])
				else
					cast.Caster.Output:Fire("LengthChanged", cast, args[1], args[2], args[3])
				end
			end
		elseif event.eventType == "Hit" then
			if rayInfo.FastCastEventsConfig.UseHit then
				if rayInfo.FastCastEventsModuleConfig.UseHit and rayInfo.HitFunc then
					rayInfo.HitFunc(cast, args[1], args[2], args[3])
				else
					cast.Caster.Output:Fire("Hit", cast, args[1], args[2], args[3])
				end
			end
		elseif event.eventType == "Pierced" then
			if rayInfo.FastCastEventsConfig.UsePierced then
				if rayInfo.FastCastEventsModuleConfig.UsePierced and rayInfo.PiercedFunc then
					rayInfo.PiercedFunc(cast, args[1], args[2], args[3])
				else
					cast.Caster.Output:Fire("Pierced", cast, args[1], args[2], args[3])
				end
			end
		elseif event.eventType == "CastTerminating" then
			if rayInfo.FastCastEventsConfig.UseCastTerminating then
				if rayInfo.FastCastEventsModuleConfig.UseCastTerminating and rayInfo.CastTerminatingFunc then
					rayInfo.CastTerminatingFunc(cast)
				else
					cast.Caster.Output:Fire("CastTerminating", cast)
				end
			end
		end
	end
end

local function HandleBulkMoveTo()
	local soa = ParallelSimulation.GetSoA()
	local rayInfo = soa.RayInfo
	local cframes = soa.CFrame

	local parts: { BasePart } = {}
	local cfList: { CFrame } = {}

	for castID, bullet in pairs(rayInfo) do
		local cosmetic = bullet.CosmeticBulletObject
		if not cosmetic then continue end

		local cf = cframes[castID]
		if cosmetic:IsA("BasePart") then
			table.insert(parts, cosmetic)
			table.insert(cfList, cf)
		else
			cosmetic:PivotTo(cf)
		end
	end

	task.synchronize()

	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfList, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function HandleMotor6D()
	local soa = ParallelSimulation.GetSoA()
	local rayInfo = soa.RayInfo
	local cframes = soa.CFrame
	local motor6Ds = soa.ActiveMotor6Ds

	for castID, motor6d in pairs(motor6Ds) do
		if motor6d then
			local bullet = rayInfo[castID] and rayInfo[castID].CosmeticBulletObject
			if bullet and bullet:IsA("BasePart") then
				motor6d.Transform = cframes[castID]
			end
		end
	end
end

local function UpdateCastsParallel()
	ParallelSimulation.UpdateCasts()
end

local function SendCastFire(
	cast: TypeDef.ActiveCastData,
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: TypeDef.FastCastBehavior
)
	cast.Caster.Output:Fire("CastFire", cast, origin, direction, velocity, behavior)
end

function BaseCast.Init(BindableOutput: BindableEvent, Data: any)
	local self = setmetatable({}, BaseCast)
	Actor = BindableOutput.Parent
	Actives = setmetatable({}, { __mode = "v" })
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

	ActiveCastCleaner = BindableCleaner

	ActiveCastCleaner.Event:Connect(function(activeCastID: number)
		if Actives[activeCastID] then
			local cast = Actives[activeCastID]
			if cast.RayInfo and cast.RayInfo.CosmeticBulletObject and ObjectCacheInstance then
				ObjectCacheInstance:ReturnPart(cast.RayInfo.CosmeticBulletObject)
			end
			Actives[activeCastID] = nil
			ParallelSimulation.Unregister(activeCastID)
			Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks") - 1)
		end
	end)

	SyncChanges = Instance.new("BindableEvent")
	SyncChanges.Name = "SyncChanges"
	SyncChanges.Parent = Actor

	SyncChanges.Event:Connect(function(cast: TypeDef.ActiveCastData)
		local ID = cast.ID
		local TargetCast = Actives[ID]

		if TargetCast then
			for i, v in cast do
				TargetCast[i] = v
			end
		end
	end)

	ParallelSimulation.Init(self)

	if RS:IsClient() then
		SimulationConnection = RS.PreRender:ConnectParallel(UpdateCastsParallel)
	else
		SimulationConnection = RS.Heartbeat:Connect(UpdateCastsParallel)
	end

	ParallelSimulation.SetMovementMode(CurrentMovementMode, true)
	MovementEnabled = true

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
		ObjectCache = ObjectCacheInstance,
		SyncChange = SyncChanges
	}, NextProjectileID, Origin, Direction, Velocity, Behavior, FastCastEventsModule, {
		CastType = EnumCastTypes.Raycast
	} :: any, true)

	ParallelSimulation.Register(cast)
	Actives[cast.ID] = cast

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
		ObjectCache = ObjectCacheInstance,
		SyncChange = SyncChanges
	}, NextProjectileID, Origin, Direction, Velocity, Behavior, FastCastEventsModule, {
		CastType = EnumCastTypes.Blockcast,
		Size = Size
	} :: any, true)

	ParallelSimulation.Register(cast)
	Actives[cast.ID] = cast

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
		ObjectCache = ObjectCacheInstance,
		SyncChange = SyncChanges
	}, NextProjectileID, Origin, Direction, Velocity, Behavior, FastCastEventsModule, {
		CastType = EnumCastTypes.Spherecast,
		Radius = Radius
	} :: any, true)

	ParallelSimulation.Register(cast)
	Actives[cast.ID] = cast

	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(cast, Origin, Direction, Velocity, Behavior)
	end
	if Behavior.FastCastEventsModuleConfig.UseCastFire and CastFireFunc then
		CastFireFunc(cast, Origin, Direction, Velocity, Behavior)
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
	end

	if enabled then
		if not MovementConnection then
			if mode == "BulkMoveTo" then
				MovementConnection = RS.PreRender:ConnectParallel(HandleBulkMoveTo)
			elseif mode == "Motor6D" then
				MovementConnection = RS.PreRender:ConnectParallel(HandleMotor6D)
			end
		end
	else
		if MovementConnection then
			MovementConnection:Disconnect()
			MovementConnection = nil
		end
	end

	ParallelSimulation.SetMovementMode(mode, enabled)
end

--[=[

@method BindObjectCache
@within BaseCast

@param bool boolean -- Whether to enable or disable ObjectCache.

Enables or disables the ObjectCache feature.

]=]
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

function BaseCast:BindMotor6DCache(enabled: boolean)
	if enabled then
		if Motor6DCacheInstance then
			return
		end
		Motor6DCacheInstance = Motor6DCache.new()
	else
		if Motor6DCacheInstance then
			Motor6DCacheInstance:Destroy()
			Motor6DCacheInstance = nil
		end
	end
end

--[=[

@method Destroy
@within BaseCast

Destroys the BaseCast instance and cleans up resources.

]=]
function BaseCast:Destroy()
	if SimulationConnection then
		SimulationConnection:Disconnect()
		SimulationConnection = nil
	end

	if MovementConnection then
		MovementConnection:Disconnect()
		MovementConnection = nil
	end

	if Motor6DCacheInstance then
		Motor6DCacheInstance:Destroy()
		Motor6DCacheInstance = nil
	end

	FastCastEventsModule = nil

	for _, v in Actives do
		FastCastM.TerminateCast(v)
	end

	Actives = {}
	setmetatable(self, nil)
end

-- ObjectCache
function BaseCast:_GetObjectCache(object: BasePart)
	if ObjectCacheInstance then
		return ObjectCacheInstance:GetPart(object)
	end
	return nil
end

function BaseCast:_ReturnObjectCache(object: BasePart)
	if ObjectCacheInstance then
		ObjectCacheInstance:ReturnPart(object)
	end
end

function BaseCast:_GetMotor6D(castID: number, projectilePart: BasePart?)
	if Motor6DCacheInstance and projectilePart then
		return Motor6DCacheInstance:Connect(castID, projectilePart)
	end
	return nil
end

function BaseCast:_ReturnMotor6D(motor6d: Motor6D?)
	if Motor6DCacheInstance then
		Motor6DCacheInstance:Disconnect(motor6d)
	end
end

return BaseCast
