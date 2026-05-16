--[[
	- Author: Mawin CK
	- Date: 2026
]]

-- Services

local RS = game:GetService("RunService")

local FastCastModule = script.Parent

-- Requires

local FastCast = require(FastCastModule)
local TypeDef = require(FastCastModule:WaitForChild("TypeDefinitions"))
local FastCastEnums = require(FastCastModule:WaitForChild("FastCastEnums"))

-- Constants
local EnumCastTypes = FastCastEnums.CastType
local DEFAULT_MAX_DISTANCE = 1000

-- Variables

local casts_Paused = {} :: { [number]: boolean }
local casts_TotalRunTime = {} :: { [number]: number }
local casts_DistanceCovered = {} :: { [number]: number }
local casts_HighFidelitySegmentSize = {} :: { [number]: number }
local casts_HighFidelityBehavior = {} :: { [number]: number }
local casts_IsActivelySimulatingPierce = {} :: { [number]: boolean }
local casts_IsActivelyResimulating = {} :: { [number]: boolean }
local casts_CancelHighResCast = {} :: { [number]: boolean }
local casts_Trajectory = {} :: { [number]: TypeDef.CastTrajectory }
local casts_VisualizeCasts = {} :: { [number]: boolean }
local casts_VisualizeCastSettings = {} :: { [number]: TypeDef.VisualizeCastSettings }
local casts_FastCastEventsModuleConfig = {} :: { [number]: TypeDef.FastCastEventsModuleConfig }
local casts_FastCastEventsConfig = {} :: { [number]: TypeDef.FastCastEventsConfig }
local casts_RayInfo = {} :: { [number]: TypeDef.CastRayInfo }
local casts_UserData = {} :: { [number]: any }
local casts_CFrame = {} :: { [number]: CFrame }
local casts_CastType = {} :: { [number]: number }
local casts_CastVariant = {} :: { [number]: CastVariants }
local casts_Origin = {} :: { [number]: Vector3 }
local casts_Acceleration = {} :: { [number]: Vector3 }
local casts_MaxDistance = {} :: { [number]: number }
local casts_ActiveMotor6Ds = {} :: { [number]: Motor6D }

local casts_ID = {} :: { number }
local casts_ID_Index = {} :: { [number]: number }

local casts_FastCastEvents = {} :: { [number]: ModuleScript }

type QueuedEventData = {
	eventType: string,
	args: { any }
}

local queuedEvents: { [number]: { QueuedEventData } } = {}

local ActivesRef: any = nil
local BaseCastRef = nil :: any
local CurrentMovementMode: "BulkMoveTo" | "Motor6D" = "BulkMoveTo"
local MovementEnabled = false

-- Types

type BlockcastVariant = { CastType: number, Size: Vector3 }
type SpherecastVariant = { CastType: number, Radius: number }
type CastVariants = BlockcastVariant | SpherecastVariant

type RayVisualizerVariant = { castLength: number }
type BlockVisualizerVariant = { size: Vector3 }
type SphereVisualizerVariant = { radius: number }
type CastVisualizerVariants = RayVisualizerVariant | BlockVisualizerVariant | SphereVisualizerVariant

local castHandlers = {
	[EnumCastTypes.Raycast] = function(
		targetWorldRoot: WorldRoot,
		origin: Vector3,
		direction: Vector3,
		params: RaycastParams
	)
		return targetWorldRoot:Raycast(origin, direction, params)
	end,
	[EnumCastTypes.Blockcast] = function(
		targetWorldRoot: WorldRoot,
		origin: Vector3,
		direction: Vector3,
		params: RaycastParams,
		variant: BlockcastVariant
	)
		return targetWorldRoot:Blockcast(CFrame.new(origin), variant.Size, direction, params)
	end,
	[EnumCastTypes.Spherecast] = function(
		targetWorldRoot: WorldRoot,
		origin: Vector3,
		direction: Vector3,
		params: RaycastParams,
		variant: SpherecastVariant
	)
		return targetWorldRoot:Spherecast(origin, variant.Radius, direction, params)
	end
}

-- Utils

local function GetPositionAtTime(
	t: number,
	origin: Vector3,
	initialVelocity: Vector3,
	acceleration: Vector3
): Vector3
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

local function QueueEvent(castID: number, eventType: string, ...: any)
	local args = { ... }
	if not queuedEvents[castID] then
		queuedEvents[castID] = {}
	end
	table.insert(queuedEvents[castID], {
		eventType = eventType,
		args = args
	})
end

local function FireQueuedEvents(events: { [number]: { QueuedEventData } })
	local sortedIDs = {}
	for id in events do
		table.insert(sortedIDs, id)
	end
	table.sort(sortedIDs)

	for _, castID in sortedIDs do
		local eventList = events[castID]
		if not eventList or not next(eventList) then
			continue
		end

		for _, event in eventList do
			local cast = ActivesRef[castID]
			if not cast then
				continue
			end

			local eventType: string = event.eventType
			local args: { any } = event.args

			local caster = cast.Caster
			local moduleConfig = casts_FastCastEventsModuleConfig[castID]
			local eventConfig = casts_FastCastEventsConfig[castID]
			local fastCastEvents = casts_FastCastEvents[castID]

			if eventType == "LengthChanged" then
				local lastPoint = args[1]
				local rayDir = args[2]
				local rayDisplacement = args[3]

				if eventConfig and eventConfig.UseLengthChanged then
					caster.Output:Fire("LengthChanged", cast, lastPoint, rayDir, rayDisplacement)
				end

				if moduleConfig and moduleConfig.UseLengthChanged and fastCastEvents and fastCastEvents.LengthChanged then
					fastCastEvents.LengthChanged(cast, lastPoint, rayDir, rayDisplacement)
				end

			elseif eventType == "Hit" then
				local result = args[1]
				local velocity = args[2]
				local cosmeticBulletObject = args[3]

				if eventConfig and eventConfig.UseHit then
					caster.Output:Fire("Hit", cast, result, velocity, cosmeticBulletObject)
				end

				if moduleConfig and moduleConfig.UseHit and fastCastEvents and fastCastEvents.Hit then
					fastCastEvents.Hit(cast, result, velocity, cosmeticBulletObject)
				end

			elseif eventType == "Pierced" then
				local result = args[1]
				local velocity = args[2]
				local cosmeticBulletObject = args[3]

				if eventConfig and eventConfig.UsePierced then
					caster.Output:Fire("Pierced", cast, result, velocity, cosmeticBulletObject)
				end

				if moduleConfig and moduleConfig.UsePierced and fastCastEvents and fastCastEvents.Pierced then
					fastCastEvents.Pierced(cast, result, velocity, cosmeticBulletObject)
				end

			elseif eventType == "CastTerminating" then
				local castTerminatingfn = args[1]
				FastCast:TerminateCast(cast, castTerminatingfn)
			end
		end
	end
end

local function BulkMoveTo()
	if CurrentMovementMode ~= "BulkMoveTo" or not MovementEnabled then
		return
	end

	local parts = table.create(#casts_ID)
	local cframes = table.create(#casts_ID)

	for _, id in casts_ID do
		local cosmeticPart = casts_RayInfo[id] and casts_RayInfo[id].CosmeticBulletObject
		if cosmeticPart and cosmeticPart.Parent then
			table.insert(parts, cosmeticPart)
			table.insert(cframes, casts_CFrame[id])
		end
	end

	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function UpdateMotor6Ds()
	if CurrentMovementMode ~= "Motor6D" or not MovementEnabled then
		return
	end

	for id, motor6d in casts_ActiveMotor6Ds do
		if motor6d and motor6d.Parent then
			motor6d.Transform = casts_CFrame[id]
		end
	end
end

local function SyncPhase()
	task.synchronize()

	UpdateMotor6Ds()
	BulkMoveTo()

	local eventsToProcess = queuedEvents
	queuedEvents = {}
	FireQueuedEvents(eventsToProcess)
end

-- ParallelSimulation

local ParallelSimulation = {}
ParallelSimulation.Connection = nil :: RBXScriptConnection?

function ParallelSimulation.Init(baseCastRef: any)
	BaseCastRef = baseCastRef
	ActivesRef = baseCastRef.Actives
end

function ParallelSimulation.Register(cast: any)
	local id = cast.ID

	casts_Paused[id] = cast.StateInfo.Paused or false
	casts_TotalRunTime[id] = cast.StateInfo.TotalRuntime or 0
	casts_DistanceCovered[id] = 0
	casts_HighFidelitySegmentSize[id] = cast.StateInfo.HighFidelitySegmentSize or 0.1
	casts_HighFidelityBehavior[id] = cast.StateInfo.HighFidelityBehavior or 0
	casts_IsActivelySimulatingPierce[id] = false
	casts_IsActivelyResimulating[id] = false
	casts_CancelHighResCast[id] = false
	casts_Trajectory[id] = cast.StateInfo.Trajectory
	casts_VisualizeCasts[id] = cast.StateInfo.VisualizeCasts or false
	casts_VisualizeCastSettings[id] = cast.StateInfo.VisualizeCastSettings
	casts_FastCastEventsModuleConfig[id] = cast.StateInfo.FastCastEventsModuleConfig
	casts_FastCastEventsConfig[id] = cast.StateInfo.FastCastEventsConfig
	casts_RayInfo[id] = cast.RayInfo
	casts_UserData[id] = cast.UserData
	casts_CastType[id] = cast.CastVariant.CastType
	casts_CastVariant[id] = cast.CastVariant
	casts_Origin[id] = cast.StateInfo.Trajectory.Origin
	casts_Acceleration[id] = cast.StateInfo.Trajectory.Acceleration
	casts_MaxDistance[id] = cast.RayInfo.MaxDistance or DEFAULT_MAX_DISTANCE
	table.insert(casts_ID, id)
	casts_ID_Index[id] = #casts_ID

	local eventModule = cast.RayInfo.FastCastEventsModule
	casts_FastCastEvents[id] = typeof(eventModule) == "ModuleScript" and require(eventModule) or nil

	local position = GetPositionAtTime(
		casts_TotalRunTime[id],
		casts_Trajectory[id].Origin,
		casts_Trajectory[id].InitialVelocity,
		casts_Trajectory[id].Acceleration
	)
	casts_CFrame[id] = CFrame.new(position)

	cast.CFrame = casts_CFrame[id]

	if CurrentMovementMode == "Motor6D" and MovementEnabled then
		local cosmeticPart = casts_RayInfo[id] and casts_RayInfo[id].CosmeticBulletObject
		if cosmeticPart and BaseCastRef and BaseCastRef._GetMotor6D then
			local motor6d = BaseCastRef:_GetMotor6D(cosmeticPart)
			casts_ActiveMotor6Ds[id] = motor6d
		end
	end

	queuedEvents[id] = {}
end

function ParallelSimulation.Unregister(castID: number)
	casts_Paused[castID] = nil
	casts_TotalRunTime[castID] = nil
	casts_DistanceCovered[castID] = nil
	casts_HighFidelitySegmentSize[castID] = nil
	casts_HighFidelityBehavior[castID] = nil
	casts_IsActivelySimulatingPierce[castID] = nil
	casts_IsActivelyResimulating[castID] = nil
	casts_CancelHighResCast[castID] = nil
	casts_Trajectory[castID] = nil
	casts_VisualizeCasts[castID] = nil
	casts_VisualizeCastSettings[castID] = nil
	casts_FastCastEventsModuleConfig[castID] = nil
	casts_FastCastEventsConfig[castID] = nil
	casts_RayInfo[castID] = nil
	casts_UserData[castID] = nil
	casts_CFrame[castID] = nil
	casts_CastType[castID] = nil
	casts_CastVariant[castID] = nil
	casts_Origin[castID] = nil
	casts_Acceleration[castID] = nil
	casts_MaxDistance[castID] = nil

	if casts_ActiveMotor6Ds[castID] then
		if BaseCastRef and BaseCastRef._ReturnMotor6D then
			BaseCastRef:_ReturnMotor6D(casts_ActiveMotor6Ds[castID])
		end
		casts_ActiveMotor6Ds[castID] = nil
	end

	local idx = casts_ID_Index[castID]
	if idx then
		local lastID = casts_ID[#casts_ID]
		casts_ID[idx] = lastID
		casts_ID_Index[lastID] = idx
		casts_ID[#casts_ID] = nil
		casts_ID_Index[castID] = nil
	end
	casts_FastCastEvents[castID] = nil

	queuedEvents[castID] = nil
end

function ParallelSimulation.SetMovementMode(mode: "BulkMoveTo" | "Motor6D", enabled: boolean)
	local oldMode = CurrentMovementMode
	CurrentMovementMode = mode
	MovementEnabled = enabled

	if oldMode == "Motor6D" and mode ~= "Motor6D" then
		for id, motor6d in casts_ActiveMotor6Ds do
			if BaseCastRef and BaseCastRef._ReturnMotor6D then
				BaseCastRef:_ReturnMotor6D(motor6d)
			end
			casts_ActiveMotor6Ds[id] = nil
		end
	end

	if mode == "Motor6D" and enabled and oldMode ~= "Motor6D" then
		for _, id in casts_ID do
			if not casts_ActiveMotor6Ds[id] then
				local cosmeticPart = casts_RayInfo[id] and casts_RayInfo[id].CosmeticBulletObject
				if cosmeticPart and BaseCastRef and BaseCastRef._GetMotor6D then
					local motor6d = BaseCastRef:_GetMotor6D(cosmeticPart)
					casts_ActiveMotor6Ds[id] = motor6d
				end
			end
		end
	end
end

function ParallelSimulation.GetActiveMotor6Ds()
	return casts_ActiveMotor6Ds
end

--[[
function ParallelSimulation.GetSoA()
	return {
		Paused = casts_Paused,
		TotalRunTime = casts_TotalRunTime,
		DistanceCovered = casts_DistanceCovered,
		HighFidelitySegmentSize = casts_HighFidelitySegmentSize,
		HighFidelityBehavior = casts_HighFidelityBehavior,
		IsActivelySimulatingPierce = casts_IsActivelySimulatingPierce,
		IsActivelyResimulating = casts_IsActivelyResimulating,
		CancelHighResCast = casts_CancelHighResCast,
		Trajectory = casts_Trajectory,
		VisualizeCasts = casts_VisualizeCasts,
		VisualizeCastSettings = casts_VisualizeCastSettings,
		FastCastEventsModuleConfig = casts_FastCastEventsModuleConfig,
		FastCastEventsConfig = casts_FastCastEventsConfig,
		RayInfo = casts_RayInfo,
		UserData = casts_UserData,
		CFrame = casts_CFrame,
		CastType = casts_CastType,
		CastVariant = casts_CastVariant,
		Origin = casts_Origin,
		Acceleration = casts_Acceleration,
		MaxDistance = casts_MaxDistance,
		ActiveMotor6Ds = casts_ActiveMotor6Ds
	}
end
]]

function ParallelSimulation.GetBaseCastRef()
	return BaseCastRef
end

function ParallelSimulation.GetCurrentMovementMode()
	return CurrentMovementMode
end

function ParallelSimulation.IsMovementEnabled()
	return MovementEnabled
end

-- RS
local function SimluateCast(
	id: number,
	delta: number, 
	FastCastEvents 
)
	local trajectory = casts_Trajectory[id]

	local origin = trajectory.Origin
	local totalDelta = casts_TotalRunTime[id] - trajectory.StartTime
	local initialVelocity = trajectory.InitialVelocity
	local acceleration = trajectory.Acceleration

	local lastPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)

	local lastDelta = casts_TotalRunTime[id] - trajectory.StartTime

	casts_TotalRunTime[id] += delta

	totalDelta = casts_TotalRunTime[id] - trajectory.StartTime

	local currentTarget = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
	local segmentVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
	local totalDisplacement = currentTarget - lastPoint

	local rayDir = totalDisplacement * segmentVelocity.Magnitude * delta

	local targetWorldRoot = casts_RayInfo[id].WorldRoot

	local castHandler = castHandlers[casts_CastVariant[id].CastType]
	local resultOfCast = castHandler(targetWorldRoot, lastPoint, rayDir, casts_RayInfo[id].Parameters, casts_CastVariant[id])

	local point = currentTarget
	local part: Instance? = nil

	if resultOfCast ~= nil then
		point = resultOfCast.Position
		part = resultOfCast.Instance 
	end

	local rayDisplacement = (point - lastPoint).Magnitude

	casts_CFrame[id] = CFrame.new(lastPoint, lastPoint + rayDir) * CFrame.new(0, 0, -rayDisplacement / 2)

	QueueEvent(id, "LengthChanged", lastPoint, rayDir.Unit, rayDisplacement)

	casts_DistanceCovered[id] += rayDisplacement

	local canPierceCheckfn: TypeDef.CanPierceFunction? = nil
	local castTerminatingfn: TypeDef.OnCastTerminatingFunction? = nil

	if FastCastEvents then
		canPierceCheckfn = casts_FastCastEventsModuleConfig[id].UseCanPierce and FastCastEvents.CanPierce or nil
		castTerminatingfn = casts_FastCastEventsModuleConfig[id].UseCastTerminating and FastCastEvents.CastTerminating or nil
	end

	-- NOTE: Please dont remove "part and"
	-- Why? basically when part doesn't exist it will do nothing, but removing "part and" will break the logic
	-- You can't do anything about it
	if part and part ~= casts_RayInfo.cosmeticBulletObject then
		if 
			canPierceCheckfn == nil
			or canPierceCheckfn(ActivesRef[id], resultOfCast, segmentVelocity, casts_RayInfo[id].CosmeticBulletObject) == false
		then

			casts_IsActivelyResimulating[id] = false

			if 
				casts_HighFidelityBehavior[id] == FastCastEnums.HighFidelityBehavior.Automatic
				and casts_HighFidelitySegmentSize[id] > 0 
			then
				casts_CancelHighResCast[id] = false

				if casts_IsActivelyResimulating[id] then
					QueueEvent(id, "CastTerminating", castTerminatingfn)

					warn(
						"Cascading cast lag encountered! The caster attempted to perform a high fidelity cast before the previous one completed, resulting in exponential cast lag. Consider increasing HighFidelitySegmentSize."
					)
					return
				end

				casts_IsActivelyResimulating[id] = true

				local numSegmentsDecimal = rayDisplacement / casts_HighFidelitySegmentSize[id]
				local numSegmentsReal = math.floor(numSegmentsDecimal)
				--local realSegmentLength = rayDisplacement / numSegmentsReal

				if numSegmentsReal == 0 then
					numSegmentsReal = 1
				end

				local timeIncrement = delta / numSegmentsReal

				for segmentIndex = 1, numSegmentsReal do
					if casts_CancelHighResCast[id] then
						casts_CancelHighResCast[id] = false
						break
					end

					local subPosition = GetPositionAtTime(
						totalDelta + (timeIncrement * segmentIndex),
						origin, 
						initialVelocity, 
						acceleration
					)
					local subVelocity = GetVelocityAtTime(
						lastDelta + (timeIncrement * segmentIndex),
						initialVelocity, 
						acceleration
					)
					local subRayDir = subVelocity * delta
					local subResult = castHandler(targetWorldRoot, subPosition, subRayDir, casts_RayInfo[id].Parameters)


					--local subDisplacement = (subPosition - (subPosition + subVelocity)).Magnitude

					if subResult ~= nil then
						--subDispalcement = (subPosition - subResult.Position).Magnitude

						if 
							canPierceCheckfn == nil
							or canPierceCheckfn(ActivesRef[id], subResult, subVelocity, casts_RayInfo[id].CosmeticBulletObject) == false
						then
							casts_IsActivelyResimulating[id] = false
							QueueEvent(id, "Hit", subResult, subVelocity, casts_RayInfo[id].CosmeticBulletObject)
							QueueEvent(id, "CastTerminating", castTerminatingfn)
						else
							QueueEvent(id, "Pierced", subResult, subVelocity, casts_RayInfo[id].CosmeticBulletObject)
						end
					end
				end
				casts_IsActivelyResimulating[id] = false
			else

				QueueEvent(id, "Hit", resultOfCast, segmentVelocity, casts_RayInfo[id].CosmeticBulletObject)
				QueueEvent(id, "CastTerminating", castTerminatingfn)

				return
			end
		else

			QueueEvent(id, "Pierced", resultOfCast, segmentVelocity, casts_RayInfo[id].CosmeticBulletObject)

		end
	end

	if casts_DistanceCovered[id] >= casts_RayInfo[id].MaxDistance then
		QueueEvent(id, "CastTerminating", castTerminatingfn)
	end
end

local function UpdateCasts(delta: number)
	for _, id in casts_ID do
		if casts_Paused[id] then
			continue
		end


		local Trajectory: TypeDef.CastTrajectory = casts_Trajectory[id]

		if casts_HighFidelitySegmentSize[id] <= 0 then
			casts_HighFidelitySegmentSize[id] = 0.1
		end

		local FastCastEvents: TypeDef.FastCastEvents = casts_FastCastEvents[id]

		if casts_HighFidelityBehavior[id] == FastCastEnums.HighFidelityBehavior.Always then
			local castTerminatingfn: TypeDef.OnCastTerminatingFunction? = nil
			if FastCastEvents then
				castTerminatingfn = casts_FastCastEventsModuleConfig[id].UseCastTerminating
					and FastCastEvents.CastTerminating
					or nil
			end

			if casts_IsActivelyResimulating[id] then
				QueueEvent(id, "CastTerminating", castTerminatingfn)
				warn("Casading cast lag encountered! The caster attempted to perform a high fidelity cast before the previous one completed, resulting in exponential cast lag. Consider increasing HighFidelitySegmentSize.")
				continue
			end
			casts_IsActivelyResimulating[id] = true

			local origin = Trajectory.Origin
			local totalDelta = casts_TotalRunTime[id] - Trajectory.StartTime
			local initialVelocity = Trajectory.InitialVelocity
			local acceleration = Trajectory.Acceleration

			local lastPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)

			casts_TotalRunTime[id] += delta

			totalDelta = casts_TotalRunTime[id] - Trajectory.StartTime

			local currentPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
			local currentVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
			local totalDisplacement = currentPoint - lastPoint

			local rayDir = totalDisplacement.Unit * currentVelocity.Magnitude * delta

			local RayInfo = casts_RayInfo[id]
			local targetWorldRoot = RayInfo.WorldRoot

			local castHandler = castHandlers[casts_CastVariant[id].CastType]
			local resultOfCast = castHandler(targetWorldRoot, lastPoint, rayDir, RayInfo.Parameters, casts_CastVariant[id])

			local point = currentPoint
			if resultOfCast ~= nil then
				point = resultOfCast.Position
			end

			local rayDisplacement = (point - lastPoint).Magnitude
			casts_TotalRunTime[id] -= delta

			local numSegmentsDecimal = rayDisplacement / casts_HighFidelitySegmentSize[id]
			local numSegmentsReal = math.floor(numSegmentsDecimal)
			if numSegmentsReal == 0 then
				numSegmentsReal = 1
			end

			--local timeIncrement = delta / numSegmentsReal

			local cast_nil = false
			for segmentIndex = 1, numSegmentsReal do

				-- In case when cast Destroyed or not exist
				if ActivesRef[id] == nil then
					cast_nil = true
				end


				if casts_CancelHighResCast[id] then
					casts_CancelHighResCast[id] = false
					break
				end

				SimluateCast(id, delta, FastCastEvents)
			end

			if cast_nil then
				continue
			end

			-- Double check again
			if ActivesRef[id] == nil then
				continue
			end
			casts_IsActivelyResimulating[id] = false
		else
			SimluateCast(id, delta, FastCastEvents)
		end
	end

	SyncPhase()
end

function ParallelSimulation.Start()
	if RS:IsClient() then
		ParallelSimulation.Connection = RS.PreSimulation:ConnectParallel(UpdateCasts)
	else
		ParallelSimulation.Connection = RS.Heartbeat:Connect(UpdateCasts)
	end
end

function ParallelSimulation.Stop()
	if ParallelSimulation.Connection then
		ParallelSimulation.Connection:Disconnect()
		ParallelSimulation.Connection = nil
	end
end

return ParallelSimulation