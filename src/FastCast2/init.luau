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
		
		A caster (created with FastCast.new()) represents a "gun".
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
	
	FastCast is intended to be require()'d once in a script, as you can create as many casters as you need with FastCast.new()
	This is generally handy since you can store settings and information in these casters, and even send them out to other scripts via events
	for use.
	
	Remember -- A "Caster" represents an entire gun (or whatever is launching your projectiles), *NOT* the individual bullets.
	Make the caster once, then use the caster to fire your bullets. Do not make a caster for each bullet.
--]]

-- Mozilla Public License 2.0 (files originally from FastCast)

--[[
	- Modified by: Mawin CK 
	- Date : 2025
]]

-- Verison : 0.0.6

--[=[
	@class FastCast

	FastCast is the root class of the module and offers the surface level methods required to make it work. This is the object returned from `require(FastCast)`.
]=]

-- Services
--local HTTPService = game:GetService("HttpService")

-- Modules
--local BaseCast = script:WaitForChild("BaseCast")

-- Requires
local Signal = require(script:WaitForChild("Signal"))
local TypeDef = require(script:WaitForChild("TypeDefinitions"))
local DefaultConfigs = require(script:WaitForChild("DefaultConfigs"))
local Configs = require(script:WaitForChild("Configs"))
local ObjectCache = require(script:WaitForChild("ObjectCache"))

--local SharedCasters = require(script:WaitForChild("SharedCasters"))

local DispatcherModule = script:WaitForChild("FastCastVMs")
local Dispatcher = require(DispatcherModule)

-- Types
type vaildcast = TypeDef.ActiveCastCompement | TypeDef.ActiveBlockcastCompement

-- CONSTANTS
local DEFAULT_CACHE_SIZE = 500
local DEFAULT_CACHE_HOLDER = workspace

-- FastCast

local FastCast = {}

--[[
If true, verbose debug logging will be used, 
	printing detailed information about what's going on during processing to the output.
]]

FastCast.__index = FastCast
FastCast.__type = "FastCast"

-- Local functions

local function DestroySignal(signal: Signal.Signal)
	if type(signal) == "table" then
		signal:Destroy()
	else
		signal = nil
	end
end

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

local function GetTrajectoryInfo(
	cast: TypeDef.ActiveCastCompement | TypeDef.ActiveBlockCast,
	index: number
): { [number]: Vector3 }
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	local trajectories = cast.StateInfo.Trajectories
	local trajectory = trajectories[index]
	local duration = trajectory.EndTime - trajectory.StartTime

	local origin = trajectory.Origin
	local vel = trajectory.InitialVelocity
	local accel = trajectory.Acceleration

	return { GetPositionAtTime(duration, origin, vel, accel), GetVelocityAtTime(duration, vel, accel) }
end

local function GetLatestTrajectoryEndInfo(cast: TypeDef.ActiveBlockcastCompement): { [number]: Vector3 }
	return GetTrajectoryInfo(cast, #cast.StateInfo.Trajectories)
end

local function ModifyTransformation(
	cast: TypeDef.ActiveCastCompement,
	velocity: Vector3?,
	acceleration: Vector3?,
	position: Vector3?
)
	local trajectories = cast.StateInfo.Trajectories
	local lastTrajectory = trajectories[#trajectories]

	if lastTrajectory.StartTime == cast.StateInfo.TotalRuntime then
		if velocity == nil then
			velocity = lastTrajectory.InitialVelocity
		end
		if acceleration == nil then
			acceleration = lastTrajectory.Acceleration
		end
		if position == nil then
			position = lastTrajectory.Origin
		end

		lastTrajectory.Origin = position
		lastTrajectory.InitialVelocity = velocity
		lastTrajectory.Acceleration = acceleration
	else
		lastTrajectory.EndTime = cast.StateInfo.TotalRuntime

		local point, velAtPoint = unpack(GetLatestTrajectoryEndInfo(cast))

		if velocity == nil then
			velocity = velAtPoint
		end
		if acceleration == nil then
			acceleration = lastTrajectory.Acceleration
		end
		if position == nil then
			position = point
		end
		table.insert(cast.StateInfo.Trajectories, {
			StartTime = cast.StateInfo.TotalRuntime,
			EndTime = -1,
			Origin = position,
			InitialVelocity = velocity,
			Acceleration = acceleration,
		})
		cast.StateInfo.CancelHighResCast = true
	end
end

--[=[
	Creates a new FastCastBehavior, which contains information necessary to Fire the cast properly.
	
	@return FastCastBehavior
]=]
function FastCast.newBehavior(): TypeDef.FastCastBehavior
	return DefaultConfigs.FastCastBehavior :: TypeDef.FastCastBehavior
end

local DEFAULT_FASTCAST_BEHAVIOR = FastCast.newBehavior()

--[=[
	:::warning

	You must [initialize](FastCast#Init) the Caster before using it. Failing to do so will result in nothing happening when attempting to fire!

	:::
	Contructs a new Caster object.
	@function new
	@within FastCast
	@return Caster
]=]
function FastCast.new(): TypeDef.Caster
	return setmetatable(
		{
			LengthChanged = Signal.new(),
			RayHit = Signal.new(),
			RayPierced = Signal.new(),
			CastTerminating = Signal.new(),
			CastFire = Signal.new(),
			WorldRoot = workspace,
			Dispatcher = nil,
			AlreadyInit = false,
		} :: any,
		FastCast
	) :: TypeDef.Caster
end

--[=[
	Initializes the Caster with the given parameters. This is required before firing using Raycasts in the Caster or nothing will happen!
	@method Init
	@within FastCast

	@param numWorkers number -- The number of worker VMs to create for this Caster. Must be greater than 1.
	@param newParent Folder -- The Folder in which to place the FastCastVMs Folder
	@param newName string -- The name to give the FastCastVMs Folder containing worker scripts.
	@param ContainerParent Folder -- The parent Folder in which to place the worker VM Containers.
	@param VMContainerName Folder -- The name to give to the Containers housing each worker VM.
	@param VMname string -- The name to give each worker VM.
	@param useBulkMoveTo boolean -- Whether to enable BulkMoveTo for the [CosmeticBulletObjects](TypeDefinitions#CastRayInfo)
	@param useObjectCache boolean -- Whether to use ObjectCache for the [Caster](TypeDefinitions#Caster)
	@param Template BasePart | Model -- The template object to use for the ObjectCache (if enabled)
	@param CacheSize number -- The size of the ObjectCache (if enabled)
	@param CacheHolder Instance -- The Instance in which to place cached objects (if enabled)
]=]
function FastCast:Init(
	numWorkers: number,
	newParent: Folder,
	newName: string,
	ContainerParent: Folder,
	VMContainerName: string,
	VMname: string,

	useBulkMoveTo: boolean,

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
	
	if not CacheSize then
		CacheSize = DEFAULT_CACHE_SIZE
	end
	
	if not CacheHolder then
		CacheHolder = DEFAULT_CACHE_HOLDER
	end
	
	self.ObjectCache = useObjectCache and ObjectCache.new(Template, CacheSize, CacheHolder) :: any

	local data = {
		useBulkMoveTo = useBulkMoveTo,
		useObjectCache = useObjectCache,
		CacheHolder = CacheHolder,
	}
	self.Dispatcher = newDispatcher.new(numWorkers, data, function(signalName: string, ...)
		local f = self[signalName]
		if not f then
			return
		end

		if type(f) == "function" then
			f(...)
		else
			f:Fire(...)
		end
	end)


	self.AlreadyInit = true
	self.ObjectCacheEnabled = useObjectCache
	self.BulkMoveEnabled = useBulkMoveTo

	if not useObjectCache then
		return
	end

	local Dispatcher = self.Dispatcher

	repeat
		task.wait()
	until #Dispatcher.Threads == numWorkers
	--print("STARTED CONNECTING")

	for i, v in Dispatcher.Threads do
		-- Please dont change this to FindFirstChild, or else diddy will oil you up
		local BindableObjectCache: BindableFunction = v:WaitForChild("ActiveCastObjectCache") :: BindableFunction
		if BindableObjectCache then
			--print("CONNECTED")
			BindableObjectCache.OnInvoke = function(v: CFrame)
				--print("INVOKED")
				return self.ObjectCache:GetPart(v)
			end -- OH MY GOD
		end -- KEEP GOING
	end -- OH YES DADDY
end

--[=[
	@type FastCastEventsModule ModuleScript
	@within TypeDefinitions

	A table of callback functions (events/hooks) used by ActiveCast.
	These functions are invoked by ActiveCast during a cast lifecycle, (e.g. length updates, pierce checks).
]=]

--[=[
	Set the FastCastEventsModule for all BaseCasts created from this Caster.
	
	@method SetFastCastEventsModule
	@param moduleScript ModuleScript -- The FastCastEventsModule to set.
]=]
function FastCast:SetFastCastEventsModule(moduleScript: ModuleScript)
	self.Dispatcher:DispatchAll("SetFastCastEventsModule", moduleScript)
end

--[=[
	Raycasts the Caster with the specified parameters.
	@method RaycastFire
	@within FastCast

	@param origin Vector3 -- The origin of the raycast.
	@param direction Vector3 -- The direction of the raycast.
	@param velocity Vector3 | number -- The velocity of the raycast.
	@param BehaviorData FastCastBehavior? -- The behavior data for the raycast.
	@return string -- The ActiveCast ID of the fired raycast.
]=]
function FastCast:RaycastFire(
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	BehaviorData: TypeDef.FastCastBehavior?
)
	if not self.AlreadyInit then
		error("Please Init caster")
	end
	if BehaviorData == nil then
		BehaviorData = DEFAULT_FASTCAST_BEHAVIOR
	end
	--local ActiveCastID = HTTPService:GenerateGUID(false)

	-- BABE RAYCAST!!!!!
	self.Dispatcher:Dispatch("Raycast", origin, direction, velocity, BehaviorData)
	--return ActiveCastID
end

--[=[
	Blockcasts the Caster with the specified parameters.
	@method BlockcastFire
	@within FastCast

	@param origin Vector3 -- The origin of the blockcast.
	@param Size Vector3 -- The size of the blockcast.
	@param direction Vector3 -- The direction of the blockcast.
	@param velocity Vector3 | number -- The velocity of the raycast.
	@param BehaviorData FastCastBehavior? -- The behavior data for the raycast.
	@return string -- The ActiveCast ID of the fired raycast.
]=]
function FastCast:BlockcastFire(
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
		BehaviorData = DEFAULT_FASTCAST_BEHAVIOR
	end
	--local ActiveCastID = HTTPService:GenerateGUID(false)

	self.Dispatcher:Dispatch("Blockcast", origin, Size, direction, velocity, BehaviorData)
	--return ActiveCastID
end

--[=[

Gets the velocity of an ActiveCast.

@method GetVelocityCast
@param cast ActiveCastCompement | ActiveBlockcastCompement -- Compement
@within FastCast
@return Vector3 -- The current velocity of the ActiveCast.
]=]
function FastCast.GetVelocityCast(cast: vaildcast)
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	local currentTrajectory = cast.StateInfo.Trajectories[#cast.StateInfo.Trajectories]
	return GetVelocityAtTime(
		cast.StateInfo.TotalRuntime - currentTrajectory.StartTime,
		currentTrajectory.InitialVelocity,
		currentTrajectory.Acceleration
	)
end

--[=[

Gets the acceleration of an ActiveCast.

@method GetAccelerationCast
@param cast ActiveCastCompement | ActiveBlockcastCompement -- Compement
@within FastCast
@return Vector3 -- The current acceleration of the ActiveCast.

]=]
function FastCast.GetAccelerationCast(cast: vaildcast)
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	local currentTrajectory = cast.StateInfo.Trajectories[#cast.StateInfo.Trajectories]
	return GetVelocityAtTime(
		cast.StateInfo.TotalRuntime - currentTrajectory.StartTime,
		currentTrajectory.InitialVelocity,
		currentTrajectory.Acceleration
	)
end

--[=[

Gets the position of an ActiveCast.

@method GetPositionCast
@param cast ActiveCastCompement | ActiveBlockcastCompement -- Compement
@within FastCast
@return Vector3 -- The current position of the ActiveCast.
]=]
function FastCast.GetPositionCast(cast: vaildcast)
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	local currentTrajectory = cast.StateInfo.Trajectories[#cast.StateInfo.Trajectories]
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
@param cast ActiveCastCompement | ActiveBlockcastCompement -- Compement
@param velocity Vector3 -- The new velocity to set.
@within FastCast

]=]
function FastCast.SetVelocityCast(cast: vaildcast, velocity: Vector3)
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	ModifyTransformation(cast, velocity, nil, nil)
end

--[=[

Sets the acceleration of an ActiveCast to the specified Vector3.

@method SetAccelerationCast
@param cast ActiveCastCompement | ActiveBlockcastCompement -- Compement
@param acceleration Vector3 -- The new acceleration to set.
@within FastCast

]=]
function FastCast.SetAccelerationCast(cast: vaildcast, acceleration: Vector3)
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	ModifyTransformation(cast, nil, acceleration, nil)
end

--[=[

Pauses simulation for an ActiveCast.

@method PauseCast
@param cast ActiveCastCompement | ActiveBlockcastCompement -- Compement
@within FastCast

]=]
function FastCast.PauseCast(cast: vaildcast)
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	cast.StateInfo.Paused = true
end

--[=[

Resumes simulation for an ActiveCast if it was paused previously.

@method ResumeCast
@param cast ActiveCastCompement | ActiveBlockcastCompement -- Compement
@within FastCast

]=]
function FastCast.ResumeCast(cast: vaildcast)
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	cast.StateInfo.Paused = false
end

--[=[

Add position to an ActiveCast with the specified Vector3.

@method AddPositionCast
@param cast ActiveCastCompement | ActiveBlockcastCompement -- Compement
@param position Vector3 -- The new position to add.
@within FastCast

]=]
function FastCast.AddPositionCast(cast: vaildcast, position: Vector3)
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	local currentTrajectory = cast.StateInfo.Trajectories[#cast.StateInfo.Trajectories]
	return GetPositionAtTime(
		cast.StateInfo.TotalRuntime - currentTrajectory.StartTime,
		currentTrajectory.Origin,
		currentTrajectory.InitialVelocity,
		currentTrajectory.Acceleration
	)
end

--[=[

Add velocity to an ActiveCast with the specified Vector3.

@method AddVelocityCast
@param cast ActiveCastCompement | ActiveBlockcastCompement -- Compement
@param velocity Vector3 -- The new velocity to add.
@within FastCast

]=]
function FastCast.AddVelocityCast(cast: vaildcast, velocity: Vector3)
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	FastCast:SetVelocity(cast:GetVelocity() + velocity)
end

--[=[

Add acceleration to an ActiveCast with the specified Vector3.

@method AddAccelerationCast
@param cast ActiveCastCompement | ActiveBlockcastCompement -- Compement
@param acceleration Vector3 -- The new acceleration to add.
@within FastCast

]=]
function FastCast.AddAccelerationCast(cast: vaildcast, acceleration: Vector3)
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	cast:SetAcceleration(cast:GetAcceleration() + acceleration)
end

--[=[

Synchronize new changes to the ActiveCast.

@method SyncChangesToCast
@param cast ActiveCastCompement | ActiveBlockcastCompement -- Compement
@within FastCast

]=]
function FastCast.SyncChangesToCast(cast: vaildcast)
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	cast.Caster.SyncChange:Fire(cast)
end

-- Terminate function for casts

function FastCast.TerminateCast(cast: vaildcast, castTerminatingFunction: (cast: vaildcast) -> ())
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED"
	)

	local trajectories = cast.StateInfo.Trajectories
	local lastTrajectory = trajectories[#trajectories]
	lastTrajectory.EndTime = cast.StateInfo.TotalRuntime

	cast.StateInfo.UpdateConnection:Disconnect()

	--self.CasterBindable:Fire("CastTerminating", self)
	--self.Definition.OnCastTerminating(self)

	cast.StateInfo.UpdateConnection = nil
	
	local FastCastEventsConfig = cast.StateInfo.FastCastEventsConfig
	if FastCastEventsConfig and FastCastEventsConfig.UseCastTerminating then
		cast.Caster.Output:Fire("CastTerminating", cast)
	end
	
	if castTerminatingFunction then
		castTerminatingFunction(cast)
	end
	
	cast.Caster.ActiveCastCleaner:Fire(cast.ID)

	for key, _ in cast do
		cast[key] = nil
	end
	--[[cast.Caster = nil
	cast.StateInfo = nil
	cast.RayInfo = nil
	cast.UserData = nil
	cast = nil]]
end

--[=[
	Calls a function safely.
	@method SafeCall
	@within FastCast
	@private

	@param f (any)
	@return any -- The result of the function call.
]=]
function FastCast:SafeCall(f: (...any) -> ...any, ...)
	-- am i tripping
	if f then
		return f(...)
	end
	return nil
end

--[=[
	Sets whether BulkMoveTo is enabled for this Caster.
	@method SetBulkMoveEnabled
	@within FastCast

	@param enabled boolean
]=]
function FastCast:SetBulkMoveEnabled(enabled: boolean)
	if not self.AlreadyInit or not self.Dispatcher then
		warn("Caster not initialized", self)
	end

	self.Dispatcher:DispatchAll("BindBulkMoveTo", enabled)
	self.BulkMoveEnabled = enabled
end

--[=[
	Sets whether ObjectCache is enabled for this Caster.
	It is recommended to interface with this via [`FastCast:Init()`](FastCast#Init) instead.
	@method SetObjectCacheEnabled
	@within FastCast

	@param enabled boolean
]=]
function FastCast:SetObjectCacheEnabled(
	enabled: boolean,
	Template: BasePart | Model,
	CacheSize: number,
	CacheHolder: Instance
)
	local Dispatcher = self.Dispatcher

	if enabled then
		self.ObjectCache = ObjectCache.new(Template, CacheSize, CacheHolder)
		Dispatcher:DispatchAll("BindObjectCache", enabled)

		for i, v in Dispatcher.Threads do
			local BindableObjectCache: BindableFunction = v:WaitForChild("ActiveCastObjectCache") :: BindableFunction
			if BindableObjectCache then
				BindableObjectCache.OnInvoke = function(v: CFrame)
					return self.ObjectCache:GetPart(v)
				end
			end 
		end
	else
		Dispatcher:DispatchAll("BindObjectCache", enabled)
		if self.ObjectCache then
			self.ObjectCache:Destroy()
		end

		if self.ObjectCacheConnection then
			self.ObjectCacheConnection.OnInvoke = nil
		end
	end
	
	self.ObjectCacheEnabled = enabled
end

--[[function FastCast:SetVisualizeCasts(bool : boolean)
	Configs.VisualizeCasts = bool
end]]

--[=[
	:::warning

	Don't call this method if you didn't enable ObjectCache in [FastCast:Init()](FastCast#Init) or via [FastCast:SetObjectCacheEnabled()](FastCast#SetObjectCacheEnabled). Doing so will result in an error.

	:::
	Returns a part to the `ObjectCache` for reuse.
	@method ReturnObject
	@within FastCast

	@param obj Instance -- The object to return to the cache.
]=]
function FastCast:ReturnObject(obj: Instance)
	self.ObjectCache:ReturnPart(obj)
end

--[=[
	Destroy's a Caster, cleaning up all resources used by it.
	@method Destroy
	@within FastCast
]=]
function FastCast:Destroy()
	if self.ObjectCache then
		self.ObjectCache:Destroy()
	end
	if self.ObjectCacheConnection then
		self.ObjectCacheConnection.OnInvoke = nil
	end

	-- I'm making sure that everything is destroyed here lmao
	DestroySignal(self.LengthChanged)
	DestroySignal(self.RayHit)
	DestroySignal(self.RayPierced)
	DestroySignal(self.CastTerminating)
	DestroySignal(self.CastFire)

	self.Dispatcher:Destroy()
	setmetatable(self, nil)
end

return FastCast
