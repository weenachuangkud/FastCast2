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

	NOTE:
	FastCast2's main repository contains the serial simulation implementation. Parallel simulation is maintained separately in FastCast2Parallel.
A powerful modern projectile library

	Because FastCast is no longer actively maintained by EtiTheSpirit, this repository continues the project with updates and adaptations.
	- Devforum: https://devforum.roblox.com/t/fastcast2-an-improved-version-of-fastcast-with-parallel-scripting-more-extensions-and-statically-typed-a-powerful-modern-projectile-library/4093890
]]



-- Services

--local HTTPService = game:GetService("HttpService")
--local RS = game:GetService("RunService")

-- Modules
--local BaseCast = script:WaitForChild("BaseCast")

-- Requires
local Signal = require(script:WaitForChild("Signal"))
local TypeDef = require(script:WaitForChild("TypeDefinitions"))
local DefaultConfigs = require(script:WaitForChild("DefaultConfigs"))
local BaseCastSerial = require(script:WaitForChild("BaseCastSerial"))
local SerialSimulation = require(script:WaitForChild("SerialSimulation"))

-- Type Exports
export type FastCastSignalEvents = TypeDef.FastCastSignalEvents

export type CanPierceFunction = TypeDef.CanPierceFunction
export type OnHitFunction = TypeDef.OnHitFunction
export type OnPiercedFunction = TypeDef.OnPiercedFunction
export type OnLengthChangedFunction = TypeDef.OnLengthChangedFunction
export type OnCastTerminatingFunction = TypeDef.OnCastTerminatingFunction
export type OnCastFireFunction = TypeDef.OnCastFireFunction
export type OnStepFunction = TypeDef.OnStepFunction

export type VisualizeCastSettings = TypeDef.VisualizeCastSettings
export type CasterSerial = TypeDef.CasterSerial

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

-- Events exposed on a Caster as a Signal. Assigning a function to one of these
-- names is equivalent to connecting that function to the underlying Signal.
local SIGNAL_EVENTS = {
	["CastFire"] = true,
	["OnStep"] = true,
	["CastTerminating"] = true,
	["Hit"] = true,
	["Pierced"] = true,
	["LengthChanged"] = true
}

-- CanPierce is a query (it has to return a boolean), so it stays a plain function.
local QUERY_EVENTS = {
	["CanPierce"] = true
}

local function NewCasterSignals()
	return {
		CastFire = Signal.new(),
		OnStep = Signal.new(),
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

local function RegisterCasterEvents(self)
	local casterId = rawget(self, "CasterId")
	local events = rawget(self, "_events")

	if not casterId or not events then
		return
	end

	BaseCastSerial.RegisterCaster(casterId, {
		CastFire = events.CastFire,
		OnStep = events.OnStep,
		Pierced = events.Pierced,
		Hit = events.Hit,
		LengthChanged = events.LengthChanged,
		CanPierce = rawget(self, "CanPierce"),
		CastTerminating = events.CastTerminating,
	})
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
		RegisterCasterEvents(self)
		return
	end

	if QUERY_EVENTS[key] then
		if value == nil or type(value) == "function" then
			rawset(self, key, value)
			RegisterCasterEvents(self)
		else
			warn("[FastCast2] Cannot set CanPierce, expected a function")
		end
		return
	end

	rawset(self, key, value)
end

--[=[
	@class FastCast

	FastCast provides static utility methods for manipulating active casts (velocity, position, acceleration)
	and serves as the module root for constructing new casters.
]=]

local FastCast = {}
local NextCasterId = 0
local RuntimeInitialized = false
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

--[[
If true, verbose debug logging will be used, 
	printing detailed information about what's going on during processing to the output.
]]

FastCastSerial.__index = IndexCaster
FastCastSerial.__newindex = NewIndexCaster
FastCastSerial.__type = "FastCastSerial"

-- Local functions

local function GetPositionAtTime(
	time: number,
	origin: Vector3,
	initialVelocity: Vector3,
	acceleration: Vector3
): Vector3
	local force = Vector3.new(
		(acceleration.X * time ^ 2) / 2,
		(acceleration.Y * time ^ 2) / 2,
		(acceleration.Z * time ^ 2) / 2
	)
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
	SerialSimulation.CancelHighResResimulation(cast.ID)
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
	Initialize the shared serial simulation runtime.
	@method Init
	@within FastCast

	@param movementMode: "BulkMoveTo" | "Motor6D"? -- Projectile movement method. Defaults to "BulkMoveTo".
]=]
--[=[
	Sets movement mode for the shared serial runtime.

	@method SetMovementModeEnabled
	@within FastCast

	@param enabled boolean -- Whether cosmetic projectile movement is enabled.
	@param mode "BulkMoveTo" | "Motor6D" -- The movement mode used by all Serial casters.
]=]
function FastCast.SetMovementModeEnabled(enabled: boolean, mode: "BulkMoveTo" | "Motor6D")
	if not RuntimeInitialized then
		return
	end

	BaseCastSerial.SetMovementModeEnabled(enabled, mode)
end

--[=[
	Stop simulation updates while preserving active casts and the shared runtime.
	Call FastCast.Init() again to resume the existing runtime.

	@method Stop
	@within FastCast
]=]
function FastCast.Stop()
	if not RuntimeInitialized then
		return
	end

	SerialSimulation.Stop()
end

function FastCast.Init(movementMode: "BulkMoveTo" | "Motor6D"?)
	if RuntimeInitialized then
		if movementMode then
			FastCast.SetMovementModeEnabled(true, movementMode)
		end

		SerialSimulation.Start()
		return
	end

	BaseCastSerial.Init(movementMode)
	RuntimeInitialized = true
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
	if not RuntimeInitialized then
		error("Please call FastCast.Init() before firing casts")
	end
	if not self.CasterId then
		error("This caster has been destroyed")
	end
	if BehaviorData == nil then
		BehaviorData = FastCast.newBehavior()
	end

	return BaseCastSerial.Raycast(self, origin, direction, velocity, BehaviorData)
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
	if not RuntimeInitialized then
		error("Please call FastCast.Init() before firing casts")
	end
	if not self.CasterId then
		error("This caster has been destroyed")
	end
	if BehaviorData == nil then
		BehaviorData = FastCast.newBehavior()
	end

	return BaseCastSerial.Blockcast(self, origin, Size, direction, velocity, BehaviorData)
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
	if not RuntimeInitialized then
		error("Please call FastCast.Init() before firing casts")
	end
	if not self.CasterId then
		error("This caster has been destroyed")
	end
	if BehaviorData == nil then
		BehaviorData = FastCast.newBehavior()
	end

	return BaseCastSerial.Spherecast(self, origin, Radius, direction, velocity, BehaviorData)
end



--[=[
	@method Destroy
	@within FastCastSerial
]=]
function FastCastSerial:Destroy()
	if getmetatable(self) ~= FastCastSerial then
		return
	end

	BaseCastSerial.Destroy(self)
	self.CasterId = nil
	DestroyCasterSignals(self)
	setmetatable(self, nil)

	self.Destroy = function() end
end

-- Utility Methods

--[=[

Gets the velocity of an ActiveCast.

	@method GetVelocityCast
	@param cast vaildcast -- The active cast to get the velocity of.
	@within FastCast
	@return Vector3 -- The current velocity of the ActiveCast.
]=]
function FastCast.GetVelocityCast(cast: vaildcast)
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
function FastCast.GetAccelerationCast(cast: vaildcast)
	return cast.StateInfo.Trajectory.Acceleration
end

--[=[

Gets the position of an ActiveCast.

	@method GetPositionCast
	@param cast vaildcast -- The active cast to get the position of.
	@within FastCast
	@return Vector3 -- The current position of the ActiveCast.
]=]
function FastCast.GetPositionCast(cast: vaildcast)
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
function FastCast.SetVelocityCast(cast: vaildcast, velocity: Vector3)
	ModifyTransformation(cast, velocity, nil, nil)
end

--[=[

Sets the acceleration of an ActiveCast to the specified Vector3.

	@method SetAccelerationCast
	@param cast vaildcast -- The active cast to modify.
	@param acceleration Vector3 -- The new acceleration to set.
	@within FastCast

]=]
function FastCast.SetAccelerationCast(cast: vaildcast, acceleration: Vector3)
	ModifyTransformation(cast, nil, acceleration, nil)
end

--[=[
	Sets the velocity of an active cast to a world-space velocity vector.
	The cast keeps its current position, runtime, and accumulated distance.
	@method SetVelocity
	@param cast vaildcast
	@param velocity Vector3
	@within FastCast
]=]
function FastCast.SetVelocity(cast: vaildcast, velocity: Vector3)
	FastCast.SetVelocityCast(cast, velocity)
end

--[=[
	Sets the acceleration of an active cast.
	The cast keeps its current position, runtime, and accumulated distance.
	@method SetAcceleration
	@param cast vaildcast
	@param acceleration Vector3
	@within FastCast
]=]
function FastCast.SetAcceleration(cast: vaildcast, acceleration: Vector3)
	FastCast.SetAccelerationCast(cast, acceleration)
end

--[=[
	Sets the position of an ActiveCast to the specified Vector3.

	@method SetPositionCast
	@param cast vaildcast -- The active cast to modify.
	@param position Vector3 -- The new position to set.
	@within FastCast
]=]
function FastCast.SetPositionCast(cast: vaildcast, position: Vector3)
	ModifyTransformation(cast, nil, nil, position)
end

--[=[

Add position to an ActiveCast with the specified Vector3.

	@method AddPositionCast
	@param cast vaildcast -- The active cast to modify.
	@param position Vector3 -- The new position to add.
	@within FastCast

]=]
function FastCast.AddPositionCast(cast: vaildcast, position: Vector3)
	FastCast:SetPositionCast(cast, FastCast.GetPositionCast(cast) + position)
end

--[=[

Add velocity to an ActiveCast with the specified Vector3.

	@method AddVelocityCast
	@param cast vaildcast -- The active cast to modify.
	@param velocity Vector3 -- The new velocity to add.
	@within FastCast

]=]
function FastCast.AddVelocityCast(cast: vaildcast, velocity: Vector3)
	FastCast:SetVelocityCast(cast, FastCast.GetVelocityCast(cast) + velocity)
end

--[=[

Add acceleration to an ActiveCast with the specified Vector3.

	@method AddAccelerationCast
	@param cast vaildcast -- The active cast to modify.
	@param acceleration Vector3 -- The new acceleration to add.
	@within FastCast

]=]
function FastCast.AddAccelerationCast(cast: vaildcast, acceleration: Vector3)
	FastCast:SetAccelerationCast(cast, FastCast.GetAccelerationCast(cast) + acceleration)
end

--[=[
	Pauses an active cast without advancing its simulation time or trajectory.
	The cast can be resumed later with ResumeCast.
	@method PauseCast
	@param cast vaildcast -- The active cast to pause.
	@within FastCast
]=]
function FastCast.PauseCast(cast: any)
	if not cast or not cast.StateInfo or cast._Destroying or cast._TerminationQueued then
		return
	end

	cast.StateInfo.IsPaused = true
end

--[=[
	Resumes a cast paused with PauseCast.
	Calling this on a terminated cast has no effect.
	@method ResumeCast
	@param cast vaildcast -- The paused cast to resume.
	@within FastCast
]=]
function FastCast.ResumeCast(cast: any)
	if not cast or not cast.StateInfo or cast._Destroying or cast._TerminationQueued then
		return
	end

	cast.StateInfo.IsPaused = false
end

--[=[
	Terminate function for casts
	@method TerminateCast
	@param cast vaildcast -- The active cast to terminate.
	@param castTerminatingFunction (cast: vaildcast) -> ())? -- Optional callback invoked just before the cast is terminated.
	@within FastCast

	Note: If EndTime is already set, the cast is already terminated and this function returns early.
]=]
function FastCast.TerminateCast(cast: any)
	-- A cast reference can outlive its simulation entry after natural termination.
	-- _TerminateCast clears the table, so reject stale references before queuing.
	if not cast or type(cast.ID) ~= "number" or cast._Destroying or cast._TerminationQueued then
		return
	end

	cast._Destroying = true
	cast._TerminationQueued = true

	-- QueueTerminate ignores casts that are already terminating.
	SerialSimulation.QueueEvent(cast.ID, "CastTerminating")
end

-- Constructors

--[=[
	Creates a new Serial Caster. A Serial Caster runs all cast simulations on the main thread
	and runs cast simulations on the main thread.

	@function new
	@within FastCast

	@return Caster
]=]
function FastCast.new()
	NextCasterId += 1

	local events = NewCasterSignals()
	local fs = {
		CasterId = NextCasterId,
		_events = events,
		WorldRoot = workspace,
	}

	setmetatable(fs, FastCastSerial)
	RegisterCasterEvents(fs)
	return fs
end

return FastCast
