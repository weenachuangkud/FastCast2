--[[
	- Author : Mawin CK
	- Date : 2025
	-- Version : 0.0.9

	SerialSimulation manages all active casts with a single RunService connection.
	Uses SoA (Structure of Arrays) for better cache performance.
]]

local RS = game:GetService("RunService")

local FastCastModule = script.Parent
local TypeDef = require(FastCastModule:WaitForChild("TypeDefinitions"))
local Configs = require(FastCastModule:WaitForChild("Configs"))
local DebugLogging = Configs.DebugLogging
local FastCastEnums = require(FastCastModule:WaitForChild("FastCastEnums"))

local EnumCastTypes = FastCastEnums.CastType

local MAX_SEGMENT_CAL_TIME = 0.016 * 5
local MAX_CASTING_TIME = 0.2
local DEFAULT_MAX_DISTANCE = 1000
local HIGH_FIDE_INCREASE_SIZE = 0.5

local EPSILON = 1e-6

-- Cast handlers
local castHandlers = {
	[EnumCastTypes.Raycast] = function(
		targetWorldRoot: WorldRoot,
		origin: Vector3,
		direction: Vector3,
		parameters: RaycastParams
	)
		return targetWorldRoot:Raycast(origin, direction, parameters)
	end,
	[EnumCastTypes.Blockcast] = function(
		targetWorldRoot: WorldRoot,
		origin: Vector3,
		direction: Vector3,
		parameters: RaycastParams,
		size: Vector3
	)
		return targetWorldRoot:Blockcast(CFrame.new(origin), size, direction, parameters)
	end,
	[EnumCastTypes.Spherecast] = function(
		targetWorldRoot: WorldRoot,
		origin: Vector3,
		direction: Vector3,
		parameters: RaycastParams,
		radius: number
	)
		return targetWorldRoot:Spherecast(origin, radius, direction, parameters)
	end
}

-- SoA structure for active casts
type SerialSimulation = {
	ActiveCasts: { any },
	StepConnection: RBXScriptConnection,
	IsRunning: boolean,

	Register: (self: SerialSimulation, cast: any) -> (),
	Unregister: (self: SerialSimulation, castID: number) -> (),
	Start: (self: SerialSimulation) -> (),
	Stop: (self: SerialSimulation) -> (),
}

local SerialSimulation = {}
SerialSimulation.__index = SerialSimulation

-- SoA arrays for cast data
local castCount = 0
local castIDs = {} :: { number }
local castOrigin = {} :: { Vector3 }
local castDirection = {} :: { Vector3 }
local castVelocity = {} :: { Vector3 }
local castAcceleration = {} :: { Vector3 }
local castTotalRuntime = {} :: { number }
local castDistanceCovered = {} :: { number }
local castMaxDistance = {} :: { number }
local castPaused = {} :: { boolean }
local castHighFidelitySegmentSize = {} :: { number }
local castHighFidelityBehavior = {} :: { number }
local castIsActivelyResimulating = {} :: { boolean }
local castCancelHighResCast = {} :: { boolean }
local castCFrame = {} :: { CFrame }
local castWorldRoot = {} :: { WorldRoot }
local castRaycastParams = {} :: { RaycastParams }
local castCosmeticBulletObject = {} :: { Instance? }
local castCastType = {} :: { number }
local castSize = {} :: { Vector3? }
local castRadius = {} :: { number? }
local castVisualizeCasts = {} :: { boolean }
local castCaster = {} :: { any }

-- Event queue
local QueuedEvents = {} :: { any }

local function GetPositionAtTime(t: number, origin: Vector3, initialVelocity: Vector3, acceleration: Vector3): Vector3
	local force = Vector3.new(
		(acceleration.X * t ^ 2) / 2,
		(acceleration.Y * t ^ 2) / 2,
		(acceleration.Z * t ^ 2) / 2
	)
	return origin + (initialVelocity * t) + force
end

local function GetVelocityAtTime(time: number, initialVelocity: Vector3, acceleration: Vector3): Vector3
	return initialVelocity + acceleration * time
end

local function OnError(errorMessage: string)
	warn(debug.traceback(errorMessage, 2))
end

local function DispatchEvent(callback: any, ...)
	if callback then
		if Configs.UseProtectedCalls then
			xpcall(callback, OnError, ...)
		else
			callback(...)
		end
	end
end

local function QueueEvent(callback: any, ...)
	if callback then
		table.insert(QueuedEvents, { Callback = callback, Args = { ... } })
	end
end

local function DispatchAllEvents()
	for _, event in QueuedEvents do
		DispatchEvent(event.Callback, unpack(event.Args))
	end
	table.clear(QueuedEvents)
end

function SerialSimulation.new(): SerialSimulation
	local self = setmetatable({}, SerialSimulation)
	self.ActiveCasts = {}
	self.IsRunning = false
	return self
end

function SerialSimulation:Register(cast: any)
	castCount += 1
	local id = castCount

	castIDs[id] = cast.ID
	castOrigin[id] = cast.StateInfo.Trajectories[1].Origin
	castDirection[id] = cast.StateInfo.Trajectories[1].InitialVelocity.Unit
	castVelocity[id] = cast.StateInfo.Trajectories[1].InitialVelocity
	castAcceleration[id] = cast.StateInfo.Trajectories[1].Acceleration
	castTotalRuntime[id] = 0
	castDistanceCovered[id] = 0
	castMaxDistance[id] = cast.RayInfo.MaxDistance
	castPaused[id] = false
	castHighFidelitySegmentSize[id] = cast.StateInfo.HighFidelitySegmentSize
	castHighFidelityBehavior[id] = cast.StateInfo.HighFidelityBehavior
	castIsActivelyResimulating[id] = false
	castCancelHighResCast[id] = false
	castCFrame[id] = cast.CFrame
	castWorldRoot[id] = cast.RayInfo.WorldRoot
	castRaycastParams[id] = cast.RayInfo.Parameters
	castCosmeticBulletObject[id] = cast.RayInfo.CosmeticBulletObject
	castCastType[id] = cast.StateInfo.Trajectories[1].CastType or 1
	castVisualizeCasts[id] = cast.StateInfo.VisualizeCasts
	castCaster[id] = cast.Caster

	if cast.RayInfo.Size then
		castSize[id] = cast.RayInfo.Size
	end
	if cast.RayInfo.Radius then
		castRadius[id] = cast.RayInfo.Radius
	end

	cast.ID = id
	self.ActiveCasts[id] = cast
end

function SerialSimulation:Unregister(castID: number)
	if not self.ActiveCasts[castID] then return end

	local lastID = castCount
	if castID ~= lastID then
		-- Swap with last element
		castIDs[castID] = castIDs[lastID]
		castOrigin[castID] = castOrigin[lastID]
		castDirection[castID] = castDirection[lastID]
		castVelocity[castID] = castVelocity[lastID]
		castAcceleration[castID] = castAcceleration[lastID]
		castTotalRuntime[castID] = castTotalRuntime[lastID]
		castDistanceCovered[castID] = castDistanceCovered[lastID]
		castMaxDistance[castID] = castMaxDistance[lastID]
		castPaused[castID] = castPaused[lastID]
		castHighFidelitySegmentSize[castID] = castHighFidelitySegmentSize[lastID]
		castHighFidelityBehavior[castID] = castHighFidelityBehavior[lastID]
		castIsActivelyResimulating[castID] = castIsActivelyResimulating[lastID]
		castCancelHighResCast[castID] = castCancelHighResCast[lastID]
		castCFrame[castID] = castCFrame[lastID]
		castWorldRoot[castID] = castWorldRoot[lastID]
		castRaycastParams[castID] = castRaycastParams[lastID]
		castCosmeticBulletObject[castID] = castCosmeticBulletObject[lastID]
		castCastType[castID] = castCastType[lastID]
		castSize[castID] = castSize[lastID]
		castRadius[castID] = castRadius[lastID]
		castVisualizeCasts[castID] = castVisualizeCasts[castID]
		castCaster[castID] = castCaster[lastID]

		local movedCast = self.ActiveCasts[lastID]
		if movedCast then
			movedCast.ID = castID
		end
	end

	-- Clear last slot
	castIDs[lastID] = nil
	castOrigin[lastID] = nil
	castDirection[lastID] = nil
	castVelocity[lastID] = nil
	castAcceleration[lastID] = nil
	castTotalRuntime[lastID] = nil
	castDistanceCovered[lastID] = nil
	castMaxDistance[lastID] = nil
	castPaused[lastID] = nil
	castHighFidelitySegmentSize[lastID] = nil
	castHighFidelityBehavior[lastID] = nil
	castIsActivelyResimulating[lastID] = nil
	castCancelHighResCast[lastID] = nil
	castCFrame[lastID] = nil
	castWorldRoot[lastID] = nil
	castRaycastParams[lastID] = nil
	castCosmeticBulletObject[lastID] = nil
	castCastType[lastID] = nil
	castSize[lastID] = nil
	castRadius[lastID] = nil
	castVisualizeCasts[lastID] = nil
	castCaster[lastID] = nil

	self.ActiveCasts[castID] = nil
	castCount = lastID - 1
end

local function UpdateAllCasts(deltaTime: number)
	if castCount == 0 then return end

	local destroyedCastIDs = {} :: { number }

	for i = 1, castCount do
		if castPaused[i] then continue end

		local castType = castCastType[i]
		local CastHandler = castHandlers[castType]

		local origin = castOrigin[i]
		local totalDelta = castTotalRuntime[i]
		local initialVelocity = castVelocity[i]
		local acceleration = castAcceleration[i]

		local lastPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)

		castTotalRuntime[i] += deltaTime
		totalDelta = castTotalRuntime[i]

		local currentTarget = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
		local segmentVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
		local totalDisplacement = currentTarget - lastPoint
		local rayDir = totalDisplacement.Unit * segmentVelocity.Magnitude * deltaTime

		local variant = {}
		if castType == EnumCastTypes.Blockcast then
			variant.Size = castSize[i]
		elseif castType == EnumCastTypes.Spherecast then
			variant.Radius = castRadius[i]
		end

		local resultOfCast = CastHandler(castWorldRoot[i], lastPoint, rayDir, castRaycastParams[i], variant)

		local point = currentTarget
		if resultOfCast ~= nil then
			point = resultOfCast.Position
		end

		local rayDisplacement = (point - lastPoint).Magnitude
		castDistanceCovered[i] += rayDisplacement
		castCFrame[i] = CFrame.new(lastPoint, lastPoint + rayDir) * CFrame.new(0, 0, -rayDisplacement / 2)

		-- Fire LengthChanged event
		local caster = castCaster[i]
		if caster and caster.Output then
			caster.Output:Fire(
				"LengthChanged",
				self.ActiveCasts[i],
				lastPoint,
				rayDir.Unit,
				rayDisplacement,
				segmentVelocity,
				castCosmeticBulletObject[i]
			)
		end

		-- Update cosmetic bullet
		local bullet = castCosmeticBulletObject[i]
		if bullet then
			if bullet:IsA("BasePart") then
				bullet.CFrame = castCFrame[i]
			else
				bullet:PivotTo(castCFrame[i])
			end
		end

		-- Handle hit
		if resultOfCast ~= nil and resultOfCast.Instance ~= castCosmeticBulletObject[i] then
			local caster = castCaster[i]
			if caster and caster.Output then
				caster.Output:Fire("Hit", self.ActiveCasts[i], resultOfCast, segmentVelocity, castCosmeticBulletObject[i])
			end

			-- Destroy cast
			table.insert(destroyedCastIDs, i)
		end

		-- Check max distance
		if castDistanceCovered[i] >= castMaxDistance[i] then
			table.insert(destroyedCastIDs, i)
		end
	end

	-- Remove destroyed casts
	for _, id in destroyedCastIDs do
		local cast = self.ActiveCasts[id]
		if cast and cast.RayInfo and cast.RayInfo.CosmeticBulletObject then
			cast.RayInfo.CosmeticBulletObject:Destroy()
		end
		self:Unregister(id)
	end

	DispatchAllEvents()
end

function SerialSimulation:Start()
	if self.IsRunning then return end
	self.IsRunning = true
	self.StepConnection = RS.Heartbeat:Connect(UpdateAllCasts)
end

function SerialSimulation:Stop()
	if not self.IsRunning then return end
	self.IsRunning = false
	if self.StepConnection then
		self.StepConnection:Disconnect()
		self.StepConnection = nil
	end
end

return SerialSimulation