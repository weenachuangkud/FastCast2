--[[
	Written by Eti the Spirit (18406183)
	
		The latest patch notes can be located here (and do note, the version at the top of this script might be outdated. I have a thing for forgetting to change it):
		>	https://etithespirit.github.io/FastCastAPIDocs/changelog
		
		*** If anything is broken, please don't hesitate to message me! ***
		
		YOU CAN FIND IMPORTANT USAGE INFORMATION HERE: https://etithespirit.github.io/FastCastAPIDocs
		YOU CAN FIND IMPORTANT USAGE INFORMATION HERE: https://etithespirit.github.io/FastCastAPIDocs
		YOU CAN FIND IMPORTANT USAGE INFORMATION HERE: https://etithespirit.github.io/FastCastAPIDocs
		
		YOU SHOULD ONLY CREATE ONE CASTER PER GUN.
		YOU SHOULD >>>NEVER<<< CREATE A NEW CASTER EVERY TIME THE GUN NEEDS TO BE FIRED.
		
		A caster (created with FastCast.new() or FastCastParallel.new()) represents a "gun".
		When you consider a gun, you think of stats like accuracy, bullet speed, etc. This is the info a caster stores. 
	
	--
	
	This is a library used to create hitscan-based guns that simulate projectile physics.
	
	This means:
		- You don't have to worry about bullet lag / jittering
		- You don't have to worry about keeping bullets at a low speed due to physics being finnicky between clients
		- You don't have to worry about misfires in bullet's Touched event (e.g. where it may going so fast that it doesn't register)
		
	Hitscan-based guns are commonly seen in the form of laser beams, among other things. Hitscan simply raycasts out to a target
	and says whether it hit or not.
	
	Unfortunately, while reliable in terms of saying if something got hit or not, this method alone cannot be used if you wish
	to implement bullet travel time into a weapon. As a result of that, I made this library - an excellent remedy to this dilemma.
	
	FastCastParallel is intended to be require()'d once in a script, as you can create as many casters as you need with FastCastParallel.new()
	This is generally handy since you can store settings and information in these casters, and even send them out to other scripts via events
	for use.
	
	Remember -- A "Caster" represents an entire gun (or whatever is launching your projectiles), *NOT* the individual bullets.
	Make the caster once, then use the caster to fire your bullets. Do not make a caster for each bullet.
--]]

-- Mozilla Public License 2.0 (files originally from FastCastParallel)

--[[
	- Modified by: Mawin CK 
	- Date : 2025
]]



-- Services

--local HTTPService = game:GetService("HttpService")
--local RS = game:GetService("RunService")

-- Modules
--local BaseCast = script:WaitForChild("BaseCast")

-- Services

local RunService = game:GetService("RunService")

-- Requires
local Signal = require(script:WaitForChild("Signal"))
local TypeDef = require(script:WaitForChild("TypeDefinitions"))
local DefaultConfigs = require(script:WaitForChild("DefaultConfigs"))
local BaseCastSerial = require(script:WaitForChild("BaseCastSerial"))
local SerialSimulation = require(script:WaitForChild("SerialSimulation"))
local DispatcherModule = script:WaitForChild("FastCastVMs")
local Dispatcher = require(DispatcherModule)

-- Type Exports
export type FastCastEventsModule = TypeDef.FastCastEventsModule
export type FastCastEvents = TypeDef.FastCastEvents
export type FastCastSignalEvents = TypeDef.FastCastSignalEvents

export type CanPierceFunction = TypeDef.CanPierceFunction
export type OnHitFunction = TypeDef.OnHitFunction
export type OnPiercedFunction = TypeDef.OnPiercedFunction
export type OnLengthChangedFunction = TypeDef.OnLengthChangedFunction
export type OnCastTerminatingFunction = TypeDef.OnCastTerminatingFunction
export type OnCastFireFunction = TypeDef.OnCastFireFunction

export type VisualizeCastSettings = TypeDef.VisualizeCastSettings

export type CasterParallel = TypeDef.CasterParallel
export type CasterSerial = TypeDef.CasterSerial

export type FastCastEventsModuleConfig = TypeDef.FastCastEventsModuleConfig
export type FastCastEventsConfig = TypeDef.FastCastEventsConfig
export type FastCastBehavior = TypeDef.FastCastBehavior

export type CastTrajectory = TypeDef.CastTrajectory
export type CastStateInfo = TypeDef.CastStateInfo
export type CastRayInfo = TypeDef.CastRayInfo
export type BlockCastRayInfo = TypeDef.BlockCastRayInfo
export type SphereCastRayInfo = TypeDef.SphereCastRayInfo

export type BaseCastData = TypeDef.BaseCastData
export type ActiveCastData = TypeDef.ActiveCastData
export type ActiveBlockcastData = TypeDef.ActiveBlockcastData
export type ActiveSpherecastData = TypeDef.ActiveSpherecastData

-- Types
type vaildcast = TypeDef.ActiveCastData | TypeDef.ActiveBlockcastData | TypeDef.ActiveSpherecastData

-- CONSTANTS
local DEFAULT_CACHE_SIZE = 500
local DEFAULT_CACHE_HOLDER = workspace

-- Events exposed on a Caster as a Signal. Assigning a function to one of these
-- names is equivalent to connecting that function to the underlying Signal.
local SIGNAL_EVENTS = {
	["CastFire"] = true,
	["CastTerminating"] = true,
	["Hit"] = true,
	["Pierced"] = true,
	["LengthChanged"] = true
}

-- CanPierce is a query (it has to return a boolean), so it stays a plain function.
local QUERY_EVENTS = {
	["CanPierce"] = true
}

-- Mirrors the EVT_* numeric constants in ParallelSimulation. Parallel workers
-- send one "Batch" message per frame containing records tagged with these IDs;
-- the main thread demuxes them back into the Caster's signals.
local OUTPUT_EVENT_NAMES = {
	[1] = "LengthChanged",
	[2] = "Hit",
	[3] = "Pierced",
	[4] = "CastTerminating"
}

local function NewCasterSignals()
	return {
		CastFire = Signal.new(),
		CastTerminating = Signal.new(),
		Hit = Signal.new(),
		Pierced = Signal.new(),
		LengthChanged = Signal.new()
	}
end

local function DestroyCasterSignals(self)
	local legacy = rawget(self, "_legacy")
	if legacy then
		for _, connection in legacy do
			connection:Disconnect()
		end
		rawset(self, "_legacy", nil)
	end

	local events = rawget(self, "_events")
	if events then
		for _, signal in events do
			signal:Destroy()
		end
		rawset(self, "_events", nil)
	end

	rawset(self, "CanPierce", nil)
end

local function IndexCaster(self, key)
	local events = rawget(self, "_events")
	if events then
		local signal = events[key]
		if signal ~= nil then
			return signal
		end
	end

	local mt = getmetatable(self)
	if mt then
		return mt[key]
	end
	return nil
end

local function NewIndexCaster(self, key, value)
	if SIGNAL_EVENTS[key] then
		local events = rawget(self, "_events")
		if not events then
			events = NewCasterSignals()
			rawset(self, "_events", events)
		end

		if type(value) == "function" then
			-- Backwards compatible assignment: connect the function, replacing
			-- any previous function assigned this way.
			local legacy = rawget(self, "_legacy")
			if not legacy then
				legacy = {}
				rawset(self, "_legacy", legacy)
			end

			local previous = legacy[key]
			if previous then
				previous:Disconnect()
			end

			legacy[key] = events[key]:Connect(value)
		elseif Signal.is(value) then
			local legacy = rawget(self, "_legacy")
			if legacy and legacy[key] then
				legacy[key]:Disconnect()
				legacy[key] = nil
			end

			events[key] = value
		elseif value == nil then
			local legacy = rawget(self, "_legacy")
			if legacy and legacy[key] then
				legacy[key]:Disconnect()
				legacy[key] = nil
			end
		else
			warn("[FastCast2] Cannot set event '" .. tostring(key) .. "', expected a function or Signal")
		end
		return
	end

	if QUERY_EVENTS[key] then
		if value == nil or type(value) == "function" then
			rawset(self, key, value)
		else
			warn("[FastCast2] Cannot set CanPierce, expected a function")
		end
		return
	end

	rawset(self, key, value)
end

-- Demux a batch of worker events (see ParallelSimulation.FireQueuedEvents).
-- Record layout: { eventType, cast, args, argCount }
local function DispatchOutputBatch(self, batch)
	for i = 1, #batch do
		local record = batch[i]
		local signalName = OUTPUT_EVENT_NAMES[record[1]]

		if signalName then
			local signal = self[signalName]
			if Signal.is(signal) then
				local argCount = record[4]
				if argCount > 0 then
					signal:Fire(record[2], table.unpack(record[3], 1, argCount))
				else
					signal:Fire(record[2])
				end
			end
		end
	end
end

--[=[
	@class FastCast

	FastCast provides static utility methods for manipulating active casts (velocity, position, acceleration)
	and serves as the module root for constructing new Serial and Parallel casters.
]=]

local FastCast = {}
FastCast.HighFidelityBehavior = {
	Default = 1,
	Automatic = 2,
	Always = 3
}
FastCast.CastType = {
	Raycast = 1,
	Blockcast = 2,
	Spherecast = 3
}
--[=[
	@class FastCastSerial

	FastCastSerial is the serial caster class that runs all cast simulations on the main thread.
]=]
local FastCastSerial = {}
--[=[
	@class FastCastParallel

	FastCastParallel is the parallel caster class that runs cast simulations on separate worker VMs.
]=]
local FastCastParallel = {}

--[[
If true, verbose debug logging will be used, 
	printing detailed information about what's going on during processing to the output.
]]

FastCastSerial.__index = IndexCaster
FastCastSerial.__newindex = NewIndexCaster
FastCastSerial.__type = "FastCastSerial"

FastCastParallel.__index = IndexCaster
FastCastParallel.__newindex = NewIndexCaster
FastCastParallel.__type = "FastCastParallel"

-- Local functions

local function GetPositionAtTime(
	time: number,
	origin: Vector3,
	initialVelocity: Vector3,
	acceleration: Vector3
): Vector3
	local force =
		Vector3.new((acceleration.X * time ^ 2) / 2, (acceleration.Y * time ^ 2) / 2, (acceleration.Z * time ^ 2) / 2)
	return origin + (initialVelocity * time) + force
end

local function GetVelocityAtTime(time: number, initialVelocity: Vector3, acceleration: Vector3): Vector3
	return initialVelocity + acceleration * time
end

--[[
local function GetTrajectoryInfo(
	cast: vaildcast,
	index: number
): { [number]: Vector3 }
	local trajectory = cast.StateInfo.Trajectory
	local duration = trajectory.EndTime ~= -1
		and (trajectory.EndTime - trajectory.StartTime)
		or (cast.StateInfo.TotalRuntime - trajectory.StartTime)

	local origin = trajectory.Origin
	local vel = trajectory.InitialVelocity
	local accel = trajectory.Acceleration

	return { GetPositionAtTime(duration, origin, vel, accel), GetVelocityAtTime(duration, vel, accel) }
end
--]]

--[[
local function GetLatestTrajectoryEndInfo(cast: vaildcast): { [number]: Vector3 }
	return GetTrajectoryInfo(cast, 1)
end
--]]

local function ModifyTransformation(
	cast: vaildcast,
	velocity: Vector3?,
	acceleration: Vector3?,
	position: Vector3?
)
	local trajectory = cast.StateInfo.Trajectory

	local t = cast.StateInfo.TotalRuntime - trajectory.StartTime
	local currentPosition = GetPositionAtTime(t, trajectory.Origin, trajectory.InitialVelocity, trajectory.Acceleration)
	local currentVelocity = GetVelocityAtTime(t, trajectory.InitialVelocity, trajectory.Acceleration)

	trajectory.Origin = position or currentPosition
	trajectory.InitialVelocity = velocity or currentVelocity
	trajectory.Acceleration = acceleration or trajectory.Acceleration
	trajectory.StartTime = cast.StateInfo.TotalRuntime
	cast.StateInfo.CancelHighResCast = true
end

local function deepCopyTable(tbl: {any}): {any}
	local newTable = {}
	for i, v in tbl do
		if type(v) == "table" then
			newTable[i] = deepCopyTable(v)
		else
			newTable[i] = v
		end
	end
	return newTable
end

--[=[
	Creates a new FastCastBehavior, which contains information necessary to Fire the cast properly.
	
	@return FastCastBehavior
]=]
function FastCast.newBehavior(): TypeDef.FastCastBehavior
	return deepCopyTable(DefaultConfigs.FastCastBehavior) :: TypeDef.FastCastBehavior
end

-- Batched parallel dispatch. Shots are queued and sent once per frame per
-- worker instead of one message per shot, removing the per-shot cost of
-- crossing the Actor boundary. The behavior is snapshotted when queued so
-- per-shot mutations (such as the raycast filter) are preserved.

local function CloneCastParams(params: RaycastParams): RaycastParams
	local clone = RaycastParams.new()
	clone.CollisionGroup = params.CollisionGroup
	clone.FilterType = params.FilterType
	clone.FilterDescendantsInstances = table.clone(params.FilterDescendantsInstances)
	clone.IgnoreWater = params.IgnoreWater
	clone.RespectCanCollide = params.RespectCanCollide
	return clone
end

local function SnapshotBehavior(behavior: any): any
	local copy = table.clone(behavior)
	if behavior.RaycastParams then
		copy.RaycastParams = CloneCastParams(behavior.RaycastParams)
	end
	return copy
end

local function QueueFire(self: any, request: { any })
	local queue = self._fireQueue
	queue[#queue + 1] = request
end

local function FlushFires(self: any)
	local queue = self._fireQueue
	local count = #queue
	if count == 0 then
		return
	end

	local dispatcher = self.Dispatcher
	local threads = dispatcher and dispatcher.Threads
	local workerCount = if threads then #threads else 0
	if workerCount == 0 then
		table.clear(queue)
		return
	end

	local batches = self._fireBatches
	local used = self._fireUsed
	local usedCount = 0

	for i = 1, count do
		local worker = (i - 1) % workerCount + 1
		local batch = batches[worker]
		if not batch then
			batch = {}
			batches[worker] = batch
			usedCount += 1
			used[usedCount] = worker
		end
		batch[#batch + 1] = queue[i]
	end
	table.clear(queue)

	for i = 1, usedCount do
		local worker = used[i]
		local batch = batches[worker]
		threads[worker]:SendMessage("FireBatch", batch)
		table.clear(batch)
		used[i] = nil
	end
end

--[=[
	Initializes the Caster with the given parameters. This is required before firing using Raycasts in the Caster or nothing will happen!
	@method Init
	@within FastCastParallel

	@param numWorkers number -- The number of worker VMs to create for this Caster. Must be greater than 1.
	@param newParent Folder -- The Folder in which to place the FastCastVMs Folder
	@param newName string -- The name to give the FastCastVMs Folder containing worker scripts.
	@param ContainerParent Folder -- The parent Folder in which to place the worker VM Containers.
	@param VMContainerName Folder -- The name to give to the Containers housing each worker VM.
	@param VMname string -- The name to give each worker VM.
	@param useBulkMoveTo boolean -- Whether to enable BulkMoveTo for the [CosmeticBulletObjects](TypeDefinitions#CastRayInfo)
	@param FastCastEventsModule ModuleScript -- The ModuleScript containing the FastCastEvents, A table of callback functions (events/hooks) used by ActiveCast..
	@param useObjectCache boolean -- Whether to use ObjectCache for the [Caster](TypeDefinitions#Caster)
	@param Template BasePart | Model -- The template object to use for the ObjectCache (if enabled)
	@param CacheSize number -- The size of the ObjectCache (if enabled)
	@param CacheHolder Instance -- The Instance in which to place cached objects (if enabled)
]=]
function FastCastParallel:Init(
	numWorkers: number,
	newParent: Folder,
	newName: string,
	ContainerParent: Folder,
	VMContainerName: string,
	VMname: string,

	movementMode: "BulkMoveTo" | "Motor6D",
	FastCastEventsModule: ModuleScript,

	useObjectCache: boolean,
	Template: BasePart | Model,
	CacheSize: number,
	CacheHolder: Instance
)
	if self.AlreadyInit then
		warn("Cannot Init more than 1")
		return
	end
	assert(numWorkers > 1, "numWorker must be more than 1")

	local DispatcherClone = DispatcherModule:Clone()
	DispatcherClone.Parent = newParent
	DispatcherClone.Name = newName or "FastCastVMs"

	local newDispatcher: Dispatcher.Dispatcher = require(DispatcherClone) :: Dispatcher.Dispatcher

	newDispatcher.Init(ContainerParent, VMContainerName, VMname)

	local data = {
		movementMode = movementMode,
		useObjectCache = useObjectCache,
		objectCacheArgs = {
			Template = Template,
			CacheSize = CacheSize,
			CacheHolder = CacheHolder
		},
		FastCastModule = script
	}
	self.Dispatcher = newDispatcher.new(numWorkers, data, function(eventName: string, ...)
		if eventName == "Batch" then
			DispatchOutputBatch(self, ...)
			return
		end

		local signal = self[eventName]
		if Signal.is(signal) then
			signal:Fire(...)
		end
	end)

	-- Queue shots and flush them once per frame (see FlushFires).
	self._fireQueue = {}
	self._fireBatches = {}
	self._fireUsed = {}
	self._flushConnection = RunService.PreSimulation:Connect(function()
		FlushFires(self)
	end)

	self.AlreadyInit = true
	self.ObjectCacheEnabled = useObjectCache
	self.MovementMode = movementMode

	if FastCastEventsModule then
		self:SetFastCastEventsModule(FastCastEventsModule)
	end
end

--[=[
	Set the FastCastEventsModule for all BaseCasts created from this Caster.
	
	@method SetFastCastEventsModule
	@within FastCastParallel
	
	@param moduleScript ModuleScript -- The FastCastEventsModule to set.
]=]
function FastCastParallel:SetFastCastEventsModule(moduleScript: ModuleScript)
	if not self.AlreadyInit then
		error("Please Init caster")
	end

	self.Dispatcher:DispatchAll("SetFastCastEventsModule", moduleScript)
	self.FastCastEventsModule = moduleScript
end

--[=[
	Raycasts the Caster with the specified parameters.
	@method RaycastFire
	@within FastCastParallel

	@param origin Vector3 -- The origin of the raycast.
	@param direction Vector3 -- The direction of the raycast.
	@param velocity Vector3 | number -- The velocity of the raycast.
	@param BehaviorData FastCastBehavior? -- The behavior data for the raycast.
]=]
function FastCastParallel:RaycastFire(
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	BehaviorData: TypeDef.FastCastBehavior?
)
	if not self.AlreadyInit then
		error("Please Init caster")
	end
	if BehaviorData == nil then
		BehaviorData = FastCast.newBehavior()
	end

	QueueFire(self, {
		1,
		origin,
		direction,
		velocity,
		SnapshotBehavior(BehaviorData)
	})
end

--[=[
	Blockcasts the Caster with the specified parameters.
	@method BlockcastFire
	@within FastCastParallel

	@param origin Vector3 -- The origin of the blockcast.
	@param Size Vector3 -- The size of the blockcast.
	@param direction Vector3 -- The direction of the blockcast.
	@param velocity Vector3 | number -- The velocity of the blockcast.
	@param BehaviorData FastCastBehavior? -- The behavior data for the blockcast.
]=]
function FastCastParallel:BlockcastFire(
	origin: Vector3,
	Size: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	BehaviorData: TypeDef.FastCastBehavior?
)
	if not self.AlreadyInit then
		error("Please Init caster")
	end
	if BehaviorData == nil then
		BehaviorData = FastCast.newBehavior()
	end

	QueueFire(self, {
		2,
		origin,
		Size,
		direction,
		velocity,
		SnapshotBehavior(BehaviorData)
	})
end

--[=[
	Spherecasts the Caster with the specified parameters.
	@method SpherecastFire
	@within FastCastParallel

	@param origin Vector3 -- The origin of the spherecast.
	@param Radius number -- The radius of the spherecast.
	@param direction Vector3 -- The direction of the spherecast.
	@param velocity Vector3 | number -- The velocity of the spherecast.
	@param BehaviorData FastCastBehavior? -- The behavior data for the spherecast.
]=]
function FastCastParallel:SpherecastFire(
	origin: Vector3,
	Radius: number,
	direction: Vector3,
	velocity: Vector3 | number,
	BehaviorData: TypeDef.FastCastBehavior?
)
	if not self.AlreadyInit then
		error("Please Init caster")
	end
	if BehaviorData == nil then
		BehaviorData = FastCast.newBehavior()
	end

	QueueFire(self, {
		3,
		origin,
		Radius,
		direction,
		velocity,
		SnapshotBehavior(BehaviorData)
	})
end

--[=[
	Sets the movement mode for casts.

	@method SetMovementModeEnabled
	@param enabled boolean -- Is enabled
	@param mode "BulkMoveTo" | "Motor6D" -- The movement mode to set for casts.
	@within FastCastParallel
]=]
function FastCastParallel:SetMovementModeEnabled(enabled: boolean, mode: "BulkMoveTo" | "Motor6D")
	if not self.AlreadyInit or not self.Dispatcher then
		warn("Caster not initialized", self)
		return
	end

	self.Dispatcher:DispatchAll("SetMovementModeEnabled", enabled, mode)
	self.MovementMode = mode
end

--[=[
	Sets whether ObjectCache is enabled for this Caster.
	It is recommended to interface with this via [`FastCastParallel:Init()`](FastCastParallel#Init) instead.
	@method SetObjectCacheEnabled
	@within FastCastParallel

	@param enabled boolean
]=]
function FastCastParallel:SetObjectCacheEnabled(
	enabled: boolean,
	Template: BasePart | Model,
	CacheSize: number,
	CacheHolder: Instance
)
	if not self.AlreadyInit then
		error("Please Init caster")
	end
	local vmDispatcher = self.Dispatcher

	if enabled then
		vmDispatcher:DispatchAll("BindObjectCache", enabled, Template, CacheSize, CacheHolder)
	else
		vmDispatcher:DispatchAll("BindObjectCache", enabled)
	end

	self.ObjectCacheEnabled = enabled
end

-- Serial Caster Methods

--[=[
	Initialize the Serial Caster.
	@method Init
	@within FastCastSerial

	@param useBulkMoveTo boolean -- Whether to use BulkMoveTo for projectile movement.
	@param useObjectCache boolean -- Whether to use ObjectCache.
	@param Template BasePart | Model? -- Template for ObjectCache.
	@param CacheSize number? -- Size of ObjectCache.
	@param CacheHolder Instance? -- Parent for cached objects.
]=]
function FastCastSerial:Init(
	movementMode: "BulkMoveTo" | "Motor6D",
	useObjectCache: boolean,
	Template: BasePart | Model?,
	CacheSize: number?,
	CacheHolder: Instance?
)
	if self.BaseCast then
		warn("Serial Caster already initialized")
		return
	end

	local data = {
		movementMode = movementMode or "BulkMoveTo",
		useObjectCache = useObjectCache,
		objectCacheArgs = {
			Template = Template,
			CacheSize = CacheSize or DEFAULT_CACHE_SIZE,
			CacheHolder = CacheHolder or DEFAULT_CACHE_HOLDER
		}
	}

	local events: TypeDef.FastCastSignalEvents = {
		CastFire = self.CastFire,
		Pierced = self.Pierced,
		Hit = self.Hit,
		LengthChanged = self.LengthChanged,
		CanPierce = self.CanPierce,
		CastTerminating = self.CastTerminating
	}

	BaseCastSerial.Init(events, data)
	self.BaseCast = BaseCastSerial

	self.MovementMode = movementMode or "BulkMoveTo"
	self.AlreadyInit = true
end

--[=[
	@method RaycastFire
	@within FastCastSerial
]=]
function FastCastSerial:RaycastFire(
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	BehaviorData: TypeDef.FastCastBehavior
)
	if not self.AlreadyInit then
		error("Please Init caster first")
	end
	if BehaviorData == nil then
		BehaviorData = FastCast.newBehavior()
	end

	BaseCastSerial.Raycast(origin, direction, velocity, BehaviorData)
end

--[=[
	@method BlockcastFire
	@within FastCastSerial
]=]
function FastCastSerial:BlockcastFire(
	origin: Vector3,
	Size: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	BehaviorData: TypeDef.FastCastBehavior
)
	if not self.AlreadyInit then
		error("Please Init caster first")
	end
	if BehaviorData == nil then
		BehaviorData = FastCast.newBehavior()
	end

	BaseCastSerial.Blockcast(origin, Size, direction, velocity, BehaviorData)
end

--[=[
	@method SpherecastFire
	@within FastCastSerial
]=]
function FastCastSerial:SpherecastFire(
	origin: Vector3,
	Radius: number,
	direction: Vector3,
	velocity: Vector3 | number,
	BehaviorData: TypeDef.FastCastBehavior
)
	if not self.AlreadyInit then
		error("Please Init caster first")
	end
	if BehaviorData == nil then
		BehaviorData = FastCast.newBehavior()
	end

	BaseCastSerial.Spherecast(origin, Radius, direction, velocity, BehaviorData)
end

--[[
	@method SetMovementModeEnabled
	@param enabled boolean -- Is enabled
	@param mode "BulkMoveTo" | "Motor6D" -- MovementMode

	@within FastCastSerial
	Sets movement mode for the Serial Caster.
]]
function FastCastSerial:SetMovementModeEnabled(enabled: boolean, mode: "BulkMoveTo" | "Motor6D")
	if not self.BaseCast then return end

	BaseCastSerial.SetMovementModeEnabled(enabled, mode)
	self.MovementMode = mode
end

--[=[
	@method SetObjectCacheEnabled
	@within FastCastSerial
]=]
function FastCastSerial:SetObjectCacheEnabled(
	enabled: boolean,
	Template: BasePart?,
	CacheSize: number,
	CacheHolder: Instance
)
	BaseCastSerial.BindObjectCache(
		enabled,
		Template,
		CacheSize,
		CacheHolder
	)
	self.ObjectCacheEnabled = enabled
end

--[=[
	@method Destroy
	@within FastCastSerial
]=]
function FastCastSerial:Destroy()
	if getmetatable(self) ~= FastCastSerial then
		return
	end

	BaseCastSerial.Destroy()
	DestroyCasterSignals(self)
	setmetatable(self, nil)

	self.Destroy = function() end
end

--[=[
	Destroy's a Caster, cleaning up all resources used by it.
	@method Destroy
	@within FastCastParallel
]=]
function FastCastParallel:Destroy()
	if getmetatable(self) ~= FastCastParallel then
		return
	end

	if self._flushConnection then
		self._flushConnection:Disconnect()
		self._flushConnection = nil
	end

	if self.Dispatcher then
		self.Dispatcher:Destroy()
	end

	DestroyCasterSignals(self)
	self.Destroy = function() end
	setmetatable(self, nil)
end

-- Utility Methods

--[=[

Gets the velocity of an ActiveCast.

	@method GetVelocityCast
	@param cast vaildcast -- The active cast to get the velocity of.
	@within FastCast
	@return Vector3 -- The current velocity of the ActiveCast.
]=]
function FastCast:GetVelocityCast(cast: vaildcast)
	local currentTrajectory = cast.StateInfo.Trajectory
	return GetVelocityAtTime(
		cast.StateInfo.TotalRuntime - currentTrajectory.StartTime,
		currentTrajectory.InitialVelocity,
		currentTrajectory.Acceleration
	)
end

--[=[

Gets the acceleration of an ActiveCast.

	@method GetAccelerationCast
	@param cast vaildcast -- The active cast to get the acceleration of.
	@within FastCast
	@return Vector3 -- The current acceleration of the ActiveCast.

]=]
function FastCast:GetAccelerationCast(cast: vaildcast)
	return cast.StateInfo.Trajectory.Acceleration
end

--[=[

Gets the position of an ActiveCast.

	@method GetPositionCast
	@param cast vaildcast -- The active cast to get the position of.
	@within FastCast
	@return Vector3 -- The current position of the ActiveCast.
]=]
function FastCast:GetPositionCast(cast: vaildcast)
	local currentTrajectory = cast.StateInfo.Trajectory
	return GetPositionAtTime(
		cast.StateInfo.TotalRuntime - currentTrajectory.StartTime,
		currentTrajectory.Origin,
		currentTrajectory.InitialVelocity,
		currentTrajectory.Acceleration
	)
end

--[=[

Sets the velocity of an ActiveCast to the specified Vector3.

	@method SetVelocityCast
	@param cast vaildcast -- The active cast to modify.
	@param velocity Vector3 -- The new velocity to set.
	@within FastCast

]=]
function FastCast:SetVelocityCast(cast: vaildcast, velocity: Vector3)
	ModifyTransformation(cast, velocity, nil, nil)
end

--[=[

Sets the acceleration of an ActiveCast to the specified Vector3.

	@method SetAccelerationCast
	@param cast vaildcast -- The active cast to modify.
	@param acceleration Vector3 -- The new acceleration to set.
	@within FastCast

]=]
function FastCast:SetAccelerationCast(cast: vaildcast, acceleration: Vector3)
	ModifyTransformation(cast, nil, acceleration, nil)
end

--[=[
	Sets the position of an ActiveCast to the specified Vector3.

	@method SetPositionCast
	@param cast vaildcast -- The active cast to modify.
	@param position Vector3 -- The new position to set.
	@within FastCast
]=]
function FastCast:SetPositionCast(cast: vaildcast, position: Vector3)
	ModifyTransformation(cast, nil, nil, position)
end

--[=[

Add position to an ActiveCast with the specified Vector3.

	@method AddPositionCast
	@param cast vaildcast -- The active cast to modify.
	@param position Vector3 -- The new position to add.
	@within FastCast

]=]
function FastCast:AddPositionCast(cast: vaildcast, position: Vector3)
	FastCast:SetPositionCast(cast, FastCast:GetPositionCast(cast) + position)
end

--[=[

Add velocity to an ActiveCast with the specified Vector3.

	@method AddVelocityCast
	@param cast vaildcast -- The active cast to modify.
	@param velocity Vector3 -- The new velocity to add.
	@within FastCast

]=]
function FastCast:AddVelocityCast(cast: vaildcast, velocity: Vector3)
	FastCast:SetVelocityCast(cast, FastCast:GetVelocityCast(cast) + velocity)
end

--[=[

Add acceleration to an ActiveCast with the specified Vector3.

	@method AddAccelerationCast
	@param cast vaildcast -- The active cast to modify.
	@param acceleration Vector3 -- The new acceleration to add.
	@within FastCast

]=]
function FastCast:AddAccelerationCast(cast: vaildcast, acceleration: Vector3)
	FastCast:SetAccelerationCast(cast, FastCast:GetAccelerationCast(cast) + acceleration)
end

--[=[

Synchronize new changes to the ActiveCast.

	@method SyncChangesToCast
	@param cast vaildcast -- The active cast to synchronize.
	@within FastCastParallel

]=]
function FastCastParallel:SyncChangesToCast(cast: vaildcast)
	local syncChange: BindableEvent = (cast.Caster :: any).SyncChange

	syncChange:Fire(cast)
end

--[=[
	Terminate function for casts
	@method TerminateCast
	@param cast vaildcast -- The active cast to terminate.
	@param castTerminatingFunction (cast: vaildcast) -> ())? -- Optional callback invoked just before the cast is terminated.
	@within FastCast

	Note: If EndTime is already set, the cast is already terminated and this function returns early.
]=]
function FastCast:TerminateCast(cast: vaildcast)
	if cast._Destroying then return end
	(cast :: any)._Destroying = true

	if cast.Mode == "Serial" then
		local eventsCfg = cast.StateInfo and cast.StateInfo.FastCastEventsConfig
		if eventsCfg and eventsCfg.UseCastTerminating then
			local castTerminating = SerialSimulation.GetEvent("CastTerminating")
			if castTerminating then
				castTerminating:Fire(cast)
			end
		end
		SerialSimulation.QueueEvent(cast.ID, "CastTerminating")
	elseif cast.Mode == "Parallel" then
		local caster = cast.Caster
		if caster == nil then return end

		local eventsCfg = cast.StateInfo and cast.StateInfo.FastCastEventsConfig
		if eventsCfg and eventsCfg.UseCastTerminating then
			caster.Output:Fire("CastTerminating", cast)
		end
		caster.Actor:SendMessage("Cleanup", cast.ID)
	end
end

-- Constructors

--[=[
	Creates a new Serial Caster. A Serial Caster runs all cast simulations on the main thread
	and is simpler to use but less performant than [FastCast.newParallel](FastCast#newParallel).

	@function new
	@within FastCast

	@return Caster
]=]
function FastCast.new()
	local fs = {
		_events = NewCasterSignals(),
		WorldRoot = workspace,
	}
	setmetatable(fs, FastCastSerial)
	return fs
end

--[=[
	Creates a new Parallel Caster. A Parallel Caster runs cast simulations on separate worker VMs

	:::warning
	You must [initialize](FastCastParallel#Init) the Parallel Caster before using it!
	Failing to do so will result in nothing happening when attempting to fire!
	:::

	@function newParallel
	@within FastCast

	@return Caster
]=]
function FastCast.newParallel()
	local fp = {
		_events = NewCasterSignals(),
		WorldRoot = workspace,
		Dispatcher = nil,
		AlreadyInit = false
	}
	setmetatable(fp, FastCastParallel)
	return fp
end

return FastCast
