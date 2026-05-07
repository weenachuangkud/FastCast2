--[[
	- Author : Mawin CK
	- Date : 2025
	

	SerialSimulation - Single RunService handling multiple ActiveCastSerial
	Uses SoA pattern for performance, queue technique for events
	Like SwiftCast implementation
]]

local RS = game:GetService("RunService")

local FastCastModule = script.Parent
local TypeDef = require(FastCastModule:WaitForChild("TypeDefinitions"))
local Configs = require(FastCastModule:WaitForChild("Configs"))
local DebugLogging = Configs.DebugLogging
local FastCastEnums = require(FastCastModule:WaitForChild("FastCastEnums"))
local ActiveCastSerial = require(FastCastModule:WaitForChild("ActiveCastSerial"))
local Motor6DPool = require(FastCastModule:WaitForChild("Motor6DPool"))

local EnumCastTypes = FastCastEnums.CastType
local HIGH_FIDE_INCREASE_SIZE = 0.5
local MAX_SEGMENT_CAL_TIME = 0.016 * 5
local MAX_CASTING_TIME = 0.2
local DEFAULT_MAX_DISTANCE = 1000
local EPSILON = 1e-6
local RAY_SEARCH_OFFSET = 0.001

local DBG_SEGMENT_SUB_COLOR = Color3.new(0.286275, 0.329412, 0.247059)
local DBG_SEGMENT_SUB_COLOR2 = Color3.new(0.454902, 0.933333, 0.011765)
local DBG_HIT_SUB_COLOR = Color3.new(0.0588235, 0.87451, 1)
local DBG_RAYPIERCE_SUB_COLOR = Color3.new(1, 0.113725, 0.588235)

local castHandlers = {
	[EnumCastTypes.Raycast] = function(targetWorldRoot: WorldRoot, origin: Vector3, direction: Vector3, params: RaycastParams)
		return targetWorldRoot:Raycast(origin, direction, params)
	end,
	[EnumCastTypes.Blockcast] = function(targetWorldRoot: WorldRoot, origin: Vector3, direction: Vector3, params: RaycastParams, size: Vector3)
		return targetWorldRoot:Blockcast(CFrame.new(origin), size, direction, params)
	end,
	[EnumCastTypes.Spherecast] = function(targetWorldRoot: WorldRoot, origin: Vector3, direction: Vector3, params: RaycastParams, radius: number)
		return targetWorldRoot:Spherecast(origin, radius, direction, params)
	end
}

local function GetPositionAtTime(t: number, origin: Vector3, velocity: Vector3, accel: Vector3): Vector3
	local force = Vector3.new(
		(accel.X * t ^ 2) / 2,
		(accel.Y * t ^ 2) / 2,
		(accel.Z * t ^ 2) / 2
	)
	return origin + (velocity * t) + force
end

local function GetVelocityAtTime(time: number, velocity: Vector3, accel: Vector3): Vector3
	return velocity + accel * time
end

-- SoA Arrays
local castCount = 0
local casts = {} :: { [number]: any }
local castIDs = {} :: { [number]: number }
local castOrigin = {} :: { [number]: Vector3 }
local castVelocity = {} :: { [number]: Vector3 }
local castAcceleration = {} :: { [number]: Vector3 }
local castTotalRuntime = {} :: { [number]: number }
local castDistanceCovered = {} :: { [number]: number }
local castMaxDistance = {} :: { [number]: number }
local castPaused = {} :: { [number]: boolean }
local castHighFidelitySegmentSize = {} :: { [number]: number }
local castHighFidelityBehavior = {} :: { [number]: number }
local castIsActivelyResimulating = {} :: { [number]: boolean }
local castCancelHighResCast = {} :: { [number]: boolean }
local castCFrame = {} :: { [number]: CFrame }
local castWorldRoot = {} :: { [number]: WorldRoot }
local castRaycastParams = {} :: { [number]: RaycastParams }
local castCosmeticBullet = {} :: { [number]: Instance? }
local castCastType = {} :: { [number]: number }
local castSize = {} :: { [number]: Vector3? }
local castRadius = {} :: { [number]: number? }
local castVisualize = {} :: { [number]: boolean }
local castVisualizeSettings = {} :: { [number]: any }
local castCaster = {} :: { [number]: any }
local castMotor6D = {} :: { [number]: Motor6D? }

-- Event queue
local QueuedEvents = {} :: { { Callback: any, Args: { any } } }

local function QueueEvent(callback: any, ...)
	if callback then
		table.insert(QueuedEvents, { Callback = callback, Args = { ... } })
	end
end

local function DispatchEvent(callback: any, ...)
	if callback then
		callback(...)
	end
end

local function DispatchAllEvents()
	for _, event in QueuedEvents do
		DispatchEvent(event.Callback, unpack(event.Args))
	end
	table.clear(QueuedEvents)
end

local function QueueFire(caster: any, eventName: string, ...)
	if caster and caster.Output then
		caster.Output:Fire(eventName, ...)
	end
end

local SerialSimulation = {
	IsRunning = false,
	StepConnection = nil
}

function SerialSimulation.Register(cast: any)
	castCount += 1
	local id = castCount

	casts[id] = cast
	castIDs[id] = cast.ID
	castOrigin[id] = cast.StateInfo.Trajectory.Origin
	castVelocity[id] = cast.StateInfo.Trajectory.InitialVelocity
	castAcceleration[id] = cast.StateInfo.Trajectory.Acceleration
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
	castCosmeticBullet[id] = cast.RayInfo.CosmeticBulletObject
	castCastType[id] = cast.Type == "Blockcast" and EnumCastTypes.Blockcast or (cast.Type == "Spherecast" and EnumCastTypes.Spherecast or EnumCastTypes.Raycast)
	castVisualize[id] = cast.StateInfo.VisualizeCasts
	castVisualizeSettings[id] = cast.StateInfo.VisualizeCastSettings
	castCaster[id] = cast.Caster

	if cast.RayInfo.Size then
		castSize[id] = cast.RayInfo.Size
	end
	if cast.RayInfo.Radius then
		castRadius[id] = cast.RayInfo.Radius
	end

	castMotor6D[id] = nil
	if cast.RayInfo.MovementMethod == "Transform" then
		Motor6DPool.Initialize()
		castMotor6D[id] = Motor6DPool.Connect(id, cast.RayInfo.CosmeticBulletObject :: any)
	end

	cast.ID = id
end

function SerialSimulation.Unregister(id: number)
	if not casts[id] then return end

	local lastId = castCount
	if id ~= lastId then
		castIDs[id] = castIDs[lastId]
		castOrigin[id] = castOrigin[lastId]
		castVelocity[id] = castVelocity[lastId]
		castAcceleration[id] = castAcceleration[lastId]
		castTotalRuntime[id] = castTotalRuntime[lastId]
		castDistanceCovered[id] = castDistanceCovered[lastId]
		castMaxDistance[id] = castMaxDistance[lastId]
		castPaused[id] = castPaused[lastId]
		castHighFidelitySegmentSize[id] = castHighFidelitySegmentSize[lastId]
		castHighFidelityBehavior[id] = castHighFidelityBehavior[lastId]
		castIsActivelyResimulating[id] = castIsActivelyResimulating[lastId]
		castCancelHighResCast[id] = castCancelHighResCast[lastId]
		castCFrame[id] = castCFrame[lastId]
		castWorldRoot[id] = castWorldRoot[lastId]
		castRaycastParams[id] = castRaycastParams[lastId]
		castCosmeticBullet[id] = castCosmeticBullet[lastId]
		castCastType[id] = castCastType[lastId]
		castSize[id] = castSize[lastId]
		castRadius[id] = castRadius[lastId]
		castVisualize[id] = castVisualize[lastId]
		castVisualizeSettings[id] = castVisualizeSettings[lastId]
		castCaster[id] = castCaster[lastId]
		castMotor6D[id] = castMotor6D[lastId]

		if casts[lastId] then
			casts[lastId].ID = id
		end
	end

	-- Return motor6d to pool
	if castMotor6D[id] then
		Motor6DPool.Disconnect(castMotor6D[id])
	end

	castIDs[lastId] = nil
	castOrigin[lastId] = nil
	castVelocity[lastId] = nil
	castAcceleration[lastId] = nil
	castTotalRuntime[lastId] = nil
	castDistanceCovered[lastId] = nil
	castMaxDistance[lastId] = nil
	castPaused[lastId] = nil
	castHighFidelitySegmentSize[lastId] = nil
	castHighFidelityBehavior[lastId] = nil
	castIsActivelyResimulating[lastId] = nil
	castCancelHighResCast[lastId] = nil
	castCFrame[id] = nil
	castWorldRoot[lastId] = nil
	castRaycastParams[lastId] = nil
	castCosmeticBullet[lastId] = nil
	castCastType[lastId] = nil
	castSize[lastId] = nil
	castRadius[lastId] = nil
	castVisualize[lastId] = nil
	castVisualizeSettings[lastId] = nil
	castCaster[lastId] = nil
	castMotor6D[lastId] = nil

	casts[id] = nil
	castCount = lastId - 1
end

function SerialSimulation.PauseCast(id: number, paused: boolean)
	castPaused[id] = paused
end

function SerialSimulation.Terminate(id: number)
	local bullet = castCosmeticBullet[id]
	if bullet then
		bullet:Destroy()
	end
	SerialSimulation.Unregister(id)
end

local function UpdateCasts(deltaTime: number)
	if castCount == 0 then return end

	local destroyedIds = {} :: { number }

	for i = 1, castCount do
		if castPaused[i] then continue end

		local caster = castCaster[i]
		local castType = castCastType[i]
		local CastHandler = castHandlers[castType]

		local origin = castOrigin[i]
		local totalDelta = castTotalRuntime[i]
		local velocity = castVelocity[i]
		local acceleration = castAcceleration[i]

		local lastPosition = GetPositionAtTime(totalDelta, origin, velocity, acceleration)
		castTotalRuntime[i] += deltaTime
		totalDelta = castTotalRuntime[i]

		local currentPosition = GetPositionAtTime(totalDelta, origin, velocity, acceleration)
		local currentVelocity = GetVelocityAtTime(totalDelta, velocity, acceleration)
		local displacement = currentPosition - lastPosition

		local rayDir = displacement.Unit * currentVelocity.Magnitude * deltaTime

		local variant = {}
		if castType == EnumCastTypes.Blockcast then
			variant.Size = castSize[i]
		elseif castType == EnumCastTypes.Spherecast then
			variant.Radius = castRadius[i]
		end

		local result = CastHandler(castWorldRoot[i], lastPosition, rayDir, castRaycastParams[i], variant)

		local hitPoint = currentPosition
		local hitPart = nil
		if result then
			hitPoint = result.Position
			hitPart = result.Instance
		end

		local rayDisplacement = (hitPoint - lastPosition).Magnitude
		castDistanceCovered[i] += rayDisplacement

		local newCFrame = CFrame.new(lastPosition, lastPosition + rayDir) * CFrame.new(0, 0, -rayDisplacement / 2)
		castCFrame[i] = newCFrame

		-- Update cosmetic bullet
		local bullet = castCosmeticBullet[i]
		local motor6d = castMotor6D[i]
		if bullet then
			if motor6d then
				motor6d.Transform = newCFrame
			elseif bullet:IsA("BasePart") then
				bullet.CFrame = newCFrame
			else
				bullet:PivotTo(newCFrame)
			end
		end

		-- Fire LengthChanged
		QueueFire(caster, "LengthChanged", casts[i], lastPosition, rayDir.Unit, rayDisplacement, currentVelocity, bullet)

		-- Handle hit
		if result and hitPart ~= bullet then
			QueueFire(caster, "Hit", casts[i], result, currentVelocity, bullet)
			table.insert(destroyedIds, i)
		end

		-- Check max distance
		if castDistanceCovered[i] >= castMaxDistance[i] then
			table.insert(destroyedIds, i)
		end
	end

	-- Process destroyed casts
	for _, id in destroyedIds do
		SerialSimulation.Terminate(id)
	end

	DispatchAllEvents()
end

function SerialSimulation.Start()
	if SerialSimulation.IsRunning then return end
	SerialSimulation.IsRunning = true
	SerialSimulation.StepConnection = RS.Heartbeat:Connect(UpdateCasts)
end

function SerialSimulation.Stop()
	if not SerialSimulation.IsRunning then return end
	SerialSimulation.IsRunning = false
	if SerialSimulation.StepConnection then
		SerialSimulation.StepConnection:Disconnect()
		SerialSimulation.StepConnection = nil
	end
end

-- Auto-start
SerialSimulation.Start()

return SerialSimulation