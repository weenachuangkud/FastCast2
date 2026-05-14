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



--[=[
	@class FastCastParallel

	FastCastParallel is the root class of the module and offers the surface level methods required to make it work. This is the object returned from `require(FastCastParallel)`.
]=]

-- Services

--local HTTPService = game:GetService("HttpService")
--local RS = game:GetService("RunService")

-- Modules
--local BaseCast = script:WaitForChild("BaseCast")

-- Requires
-- local FastCastEnums = require(script.FastCastEnums)
local Signal = require(script:WaitForChild("Signal"))
local TypeDef = require(script:WaitForChild("TypeDefinitions"))
local DefaultConfigs = require(script:WaitForChild("DefaultConfigs"))
--local Configs = require(script:WaitForChild("Configs"))
local ObjectCache = require(script:WaitForChild("ObjectCache"))
local BaseCastSerial = require(script:WaitForChild("BaseCastSerial"))

--local SharedCasters = require(script:WaitForChild("SharedCasters"))

local DispatcherModule = script:WaitForChild("FastCastVMs")
local Dispatcher = require(DispatcherModule)

-- Types
type vaildcast = TypeDef.ActiveCastData | TypeDef.ActiveBlockcastData | TypeDef.ActiveSpherecastData

-- CONSTANTS
local DEFAULT_CACHE_SIZE = 500
local DEFAULT_CACHE_HOLDER = workspace

-- FastCast

local FastCast = {}
local FastCastSerial = {}
local FastCastParallel = {}

--[[
If true, verbose debug logging will be used, 
	printing detailed information about what's going on during processing to the output.
]]

FastCastSerial.__index = FastCastSerial
FastCastSerial.__type = "FastCastSerial"

FastCastParallel.__index = FastCastParallel
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
	assert(numWorkers >= 1, "numWorker must be more than 1")

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
		}
	}
	self.Dispatcher = newDispatcher.new(numWorkers, data, function(signalName: string, ...)
		local f = self[signalName]
		if not f then
			return
		end

		if type(f) == "function" then
			f(...)
		end
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

	BehaviorData._CosmeticBullet = nil
	if BehaviorData.CosmeticBulletTemplate then
		local bullet = BehaviorData.CosmeticBulletTemplate:Clone()
		bullet.CFrame = CFrame.new(origin, origin + direction)
		bullet.Parent = BehaviorData.CosmeticBulletContainer
		BehaviorData._CosmeticBullet = bullet
	end

	self.Dispatcher:Dispatch("Raycast", origin, direction, velocity, BehaviorData)
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

	BehaviorData._CosmeticBullet = nil
	if BehaviorData.CosmeticBulletTemplate then
		local bullet = BehaviorData.CosmeticBulletTemplate:Clone()
		bullet.CFrame = CFrame.new(origin, origin + direction)
		bullet.Parent = BehaviorData.CosmeticBulletContainer
		BehaviorData._CosmeticBullet = bullet
	end

	self.Dispatcher:Dispatch("Blockcast", origin, Size, direction, velocity, BehaviorData)
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

	BehaviorData._CosmeticBullet = nil
	if BehaviorData.CosmeticBulletTemplate then
		local bullet = BehaviorData.CosmeticBulletTemplate:Clone()
		bullet.CFrame = CFrame.new(origin, origin + direction)
		bullet.Parent = BehaviorData.CosmeticBulletContainer
		BehaviorData._CosmeticBullet = bullet
	end

	self.Dispatcher:Dispatch("Spherecast", origin, Radius, direction, velocity, BehaviorData)
end

--[=[
	Sets the movement mode for casts.

	@method SetMovementMode
	@param mode "BulkMoveTo" | "Motor6D" -- The movement mode to set for casts.
	@within FastCastParallel
]=]
function FastCastParallel:SetMovementMode(mode: "BulkMoveTo" | "Motor6D", enabled: boolean)
	if not self.AlreadyInit or not self.Dispatcher then
		warn("Caster not initialized", self)
		return
	end

	self.Dispatcher:DispatchAll("SetMovementMode", mode, enabled)
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
	useBulkMoveTo: boolean,
	useObjectCache: boolean,
	Template: BasePart | Model?,
	CacheSize: number?,
	CacheHolder: Instance?
)
	if self.BaseCast then
		warn("Serial Caster already initialized")
		return
	end

	local BindableOutput = Instance.new("BindableEvent")
	BindableOutput.Name = "Output"
	BindableOutput.Parent = script

	local data = {
		useBulkMoveTo = useBulkMoveTo,
		useObjectCache = useObjectCache
	}

	self.BaseCast = BaseCastSerial.Init(BindableOutput, data, self)

	self.Output = BindableOutput

	BindableOutput.Event:Connect(function(eventName: string, ...)
		local f = self[eventName]
		if not f then
			return
		end
		
		if type(f) == "function" then
			f(...)
		end
	end)

	if useObjectCache then
		if not CacheSize then
			CacheSize = DEFAULT_CACHE_SIZE
		end
		if not CacheHolder then
			CacheHolder = DEFAULT_CACHE_HOLDER
		end
		-- HEy I use "Template :: any" here because of a weird issue where the type of Template is not being recognized as BasePart | Model, even though it is. I have no idea why this is happening, but it works so I'm not gonna question it.
		self.ObjectCache = ObjectCache.new((Template :: any), CacheSize, CacheHolder) :: any
		self.ObjectCacheEnabled = true
	end

	self.MovementMode = useBulkMoveTo and "BulkMoveTo" or "Motor6D"
	self.Initialized = true
end

--[=[
	@method RaycastFire
	@within FastCastSerial
]=]
function FastCastSerial:RaycastFire(
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	BehaviorData: TypeDef.FastCastBehavior?
)
	if not self.Initialized or not self.BaseCast then
		error("Please Init caster first")
	end
	if BehaviorData == nil then
		BehaviorData = FastCast.newBehavior()
	end

	self.BaseCast:Raycast(origin, direction, velocity, BehaviorData)
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
	BehaviorData: TypeDef.FastCastBehavior?
)
	if not self.Initialized or not self.BaseCast then
		error("Please Init caster first")
	end
	if BehaviorData == nil then
		BehaviorData = FastCast.newBehavior()
	end

	self.BaseCast:Blockcast(origin, Size, direction, velocity, BehaviorData)
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
	BehaviorData: TypeDef.FastCastBehavior?
)
	if not self.Initialized or not self.BaseCast then
		error("Please Init caster first")
	end
	if BehaviorData == nil then
		BehaviorData = FastCast.newBehavior()
	end

	self.BaseCast:Spherecast(origin, Radius, direction, velocity, BehaviorData)
end

--[[
	@method SetMovementMode
	@within FastCastSerial

	Sets movement mode for the Serial Caster.
]]
function FastCastSerial:SetMovementMode(mode: "BulkMoveTo" | "Motor6D")
	if not self.BaseCast then return end

	self.BaseCast:SetMovementMode(mode)
	self.MovementMode = mode
end

--[=[
	@method SetObjectCacheEnabled
	@within FastCastSerial
]=]
function FastCastSerial:SetObjectCacheEnabled(enabled: boolean)
	if not self.BaseCast then return end

	if enabled then
		if not self.ObjectCache then
			warn("ObjectCache not initialized. Call Init with useObjectCache = true first.")
			return
		end
		self.BaseCast:BindObjectCache(true)
	else
		self.BaseCast:BindObjectCache(false)
		if self.ObjectCache then
			self.ObjectCache:Destroy()
			self.ObjectCache = nil
		end
	end

	self.ObjectCacheEnabled = enabled
end

--[=[
	@method Destroy
	@within FastCastSerial
]=]
function FastCastSerial:Destroy()
	if self.ObjectCache then
		self.ObjectCache:Destroy()
	end

	if self.BaseCast then
		self.BaseCast:Destroy()
	end

	self.LengthChanged = nil
	self.Hit = nil
	self.Pierced = nil
	self.CastTerminating = nil
	self.CastFire = nil

	if self.Output then
		self.Output:Destroy()
	end

	setmetatable(self, nil)
end

--[=[
	Destroy's a Caster, cleaning up all resources used by it.
	@method Destroy
	@within FastCastParallel
]=]
function FastCastParallel:Destroy()
	if self.ObjectCache then
		self.ObjectCache:Destroy()
	end

	-- I'm making sure that everything is destroyed here lmao
	self.LengthChanged = nil
	self.Hit = nil
	self.Pierced = nil
	self.CastTerminating = nil
	self.CastFire = nil

	self.Dispatcher:Destroy()
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

Pauses or resumes simulation for an ActiveCast.

	@method PauseCast
	@param cast vaildcast -- The active cast to modify.
	@param value boolean -- Whether to pause (true) or resume (false) the cast.
	@within FastCast

]=]
function FastCast:PauseCast(cast: vaildcast, value: boolean)
	cast.StateInfo.Paused = value
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
function FastCast:SyncChangesToCast(cast: vaildcast)
	cast.Caster.SyncChange:Fire(cast)
end

--[=[
	Terminate function for casts
	@method TerminateCast
	@param cast vaildcast -- The active cast to terminate.
	@param castTerminatingFunction (cast: vaildcast) -> ())? -- Optional callback invoked just before the cast is terminated.
	@within FastCast

	Note: If EndTime is already set, the cast is already terminated and this function returns early.
]=]
function FastCast:TerminateCast(cast: vaildcast, castTerminatingFunction: TypeDef.OnCastTerminatingFunction?)
	local trajectory = cast.StateInfo.Trajectory
	if trajectory.EndTime ~= -1 then
		return
	end
	trajectory.EndTime = cast.StateInfo.TotalRuntime

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
		LengthChanged = Signal.new(),
		Hit = Signal.new(),
		Pierced = Signal.new(),
		CastTerminating = Signal.new(),
		CastFire = Signal.new(),
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
		LengthChanged = Signal.new(),
		Hit = Signal.new(),
		Pierced = Signal.new(),
		CastTerminating = Signal.new(),
		CastFire = Signal.new(),
		WorldRoot = workspace,
		Dispatcher = nil,
		AlreadyInit = false
	}
	setmetatable(fp, FastCastParallel)
	return fp
end

return FastCast
