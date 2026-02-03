-- Mozilla Public License 2.0 (files originally from FastCast)
--[[
	- Modified by: Mawin CK 
	- Date : 2025
	-- Verison : 0.0.5
]]
	

-- Services
local RS = game:GetService("RunService")

-- Variables
local FastCastModule = script.Parent

-- Dependencies
local TypeDefinitions = require(script.Parent.TypeDefinitions)
local TypeDef = require(FastCastModule:WaitForChild("TypeDefinitions"))
local Configs = require(FastCastModule:WaitForChild("Configs"))
local DebugLogging = Configs.DebugLogging
local FastCastEnums = require(FastCastModule:WaitForChild("FastCastEnums"))

-- Constants
local MAX_PIERCE_TEST_COUNT = 100
local FC_VIS_OBJ_NAME = "FastCastVisualizationObjects"
local MAX_SEGMENT_CAL_TIME = 0.016 * 5 -- 80ms
local MAX_CASTING_TIME = 0.2 -- 200ms
local DEFAULT_MAX_DISTANCE = 1000

-- Debugging
local DBG_SEGMENT_SUB_COLOR = Color3.new(0.286275, 0.329412, 0.247059)
local DBG_SEGMENT_SUB_COLOR2 = Color3.new(0.286275, 0.329412, 0.247059)
local DBG_HIT_SUB_COLOR = Color3.new(0.0588235, 0.87451, 1)
local DBG_RAYPIERCE_SUB_COLOR = Color3.new(1, 0.113725, 0.588235)

-- Automatic Performance setting
local HIGH_FIDE_INCREASE_SIZE = 0.5

-- SoA Data Storage
local ActiveCastSOA = {
	-- Main data arrays
	Caster = table.create(1024),
	StateInfo_UpdateConnection = table.create(1024),
	StateInfo_Paused = table.create(1024),
	StateInfo_TotalRuntime = table.create(1024),
	StateInfo_DistanceCovered = table.create(1024),
	StateInfo_HighFidelitySegmentSize = table.create(1024),
	StateInfo_HighFidelityBehavior = table.create(1024),
	StateInfo_IsActivelySimulatingPierce = table.create(1024),
	StateInfo_IsActivelyResimulating = table.create(1024),
	StateInfo_CancelHighResCast = table.create(1024),
	StateInfo_Trajectories = table.create(1024),
	StateInfo_VisualizeCasts = table.create(1024),
	StateInfo_VisualizeCastSettings = table.create(1024),
	StateInfo_UseLengthChanged = table.create(1024),
	StateInfo_UseBetterLengthChanged = table.create(1024),

	RayInfo_Parameters = table.create(1024),
	RayInfo_WorldRoot = table.create(1024),
	RayInfo_MaxDistance = table.create(1024),
	RayInfo_CosmeticBulletObject = table.create(1024),
	RayInfo_FastCastEventsModule = table.create(1024),
	RayInfo_CanPierceModule = table.create(1024),
	RayInfo_BetterLengthChangedModule = table.create(1024),

	UserData = table.create(1024),
	CFrame = table.create(1024),
	ID = table.create(1024),

	-- Free indices for reuse
	FreeIndices = table.create(1024),
	ActiveCount = 0
}

--[=[
	@class ActiveCast

	An ActiveCast represents a bullet fired by a parent [Caster](Caster). It contains methods of accessing the physics 
	data of this specific bullet at any given time, as well as methods to alter its trajectory during runtime.
]=]

local ActiveCast = {}
ActiveCast.__type = "ActiveCast"

local ActiveCastFunctions = {}

-- Local functions

local function DebrisAdd(obj: Instance, Lifetime: number)
	if not obj then
		return
	end
	if Lifetime <= 0 then
		obj:Destroy()
	end

	task.delay(Lifetime, function()
		obj:Destroy()
	end)
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

local function CloneCastParams(params: RaycastParams): RaycastParams
	local clone: RaycastParams = RaycastParams.new()
	clone.CollisionGroup = params.CollisionGroup
	clone.FilterType = params.FilterType
	clone.FilterDescendantsInstances = params.FilterDescendantsInstances
	clone.IgnoreWater = params.IgnoreWater
	return clone
end

local function ResolveCanPierceCheck(idx: number): TypeDef.CanPierceFunction?
	local canPierceModule = ActiveCastSOA.RayInfo_CanPierceModule[idx]
	if canPierceModule == nil then
		return nil
	end

	local loadedModule = require(canPierceModule)
	if loadedModule == nil then
		return nil
	end

	return loadedModule.CanPierce
end

local function RunCanPierceCheck(
	idx: number,
	canPierceCheck: TypeDef.CanPierceFunction?,
	resultOfCast: RaycastResult,
	segmentVelocity: Vector3
): boolean?
	if canPierceCheck == nil then
		return nil
	end

	local castObject = {
		Caster = ActiveCastSOA.Caster[idx],
		StateInfo = {
			UpdateConnection = ActiveCastSOA.StateInfo_UpdateConnection[idx],
			Paused = ActiveCastSOA.StateInfo_Paused[idx],
			TotalRuntime = ActiveCastSOA.StateInfo_TotalRuntime[idx],
			DistanceCovered = ActiveCastSOA.StateInfo_DistanceCovered[idx],
			HighFidelitySegmentSize = ActiveCastSOA.StateInfo_HighFidelitySegmentSize[idx],
			HighFidelityBehavior = ActiveCastSOA.StateInfo_HighFidelityBehavior[idx],
			IsActivelySimulatingPierce = ActiveCastSOA.StateInfo_IsActivelySimulatingPierce[idx],
			IsActivelyResimulating = ActiveCastSOA.StateInfo_IsActivelyResimulating[idx],
			CancelHighResCast = ActiveCastSOA.StateInfo_CancelHighResCast[idx],
			Trajectories = ActiveCastSOA.StateInfo_Trajectories[idx],
			VisualizeCasts = ActiveCastSOA.StateInfo_VisualizeCasts[idx],
			VisualizeCastSettings = ActiveCastSOA.StateInfo_VisualizeCastSettings[idx],
			UseLengthChanged = ActiveCastSOA.StateInfo_UseLengthChanged[idx],
			UseBetterLengthChanged = ActiveCastSOA.StateInfo_UseBetterLengthChanged[idx]
		},
		RayInfo = {
			Parameters = ActiveCastSOA.RayInfo_Parameters[idx],
			WorldRoot = ActiveCastSOA.RayInfo_WorldRoot[idx],
			MaxDistance = ActiveCastSOA.RayInfo_MaxDistance[idx],
			CosmeticBulletObject = ActiveCastSOA.RayInfo_CosmeticBulletObject[idx],
			FastCastEventsModule = ActiveCastSOA.RayInfo_FastCastEventsModule[idx],
			CanPierceModule = ActiveCastSOA.RayInfo_CanPierceModule[idx],
			BetterLengthChangedModule = ActiveCastSOA.RayInfo_BetterLengthChangedModule[idx]
		},
		UserData = ActiveCastSOA.UserData[idx],
		CFrame = ActiveCastSOA.CFrame[idx],
		ID = ActiveCastSOA.ID[idx],
		_idx = idx
	}

	castObject.Destroy = function(self) return ActiveCastFunctions.Terminate(self) end
	castObject.Terminate = ActiveCastFunctions.Terminate
	castObject.SetVelocity = ActiveCastFunctions.SetVelocity
	castObject.SetAcceleration = ActiveCastFunctions.SetAcceleration
	castObject.SetPosition = ActiveCastFunctions.SetPosition
	castObject.GetVelocity = ActiveCastFunctions.GetVelocity
	castObject.GetAcceleration = ActiveCastFunctions.GetAcceleration
	castObject.GetPosition = ActiveCastFunctions.GetPosition
	castObject.AddVelocity = ActiveCastFunctions.AddVelocity
	castObject.AddAcceleration = ActiveCastFunctions.AddAcceleration
	castObject.AddPosition = ActiveCastFunctions.AddPosition
	castObject.Pause = ActiveCastFunctions.Pause
	castObject.Resume = ActiveCastFunctions.Resume

	return canPierceCheck(castObject, resultOfCast, segmentVelocity, ActiveCastSOA.RayInfo_CosmeticBulletObject[idx])
end

local function ResolveOnLengthChanged(idx: number): TypeDef.OnLengthChangedFunction?
	local lengthchangedModule = ActiveCastSOA.RayInfo_BetterLengthChangedModule[idx]
	if lengthchangedModule == nil then
		return nil
	end

	local loadedModule = require(lengthchangedModule)
	if loadedModule == nil then
		return nil
	end

	return loadedModule.OnLengthChanged
end

local function GetFastCastVisualizationContainer(): Instance
	local fcVisualizationObjects = workspace.Terrain:FindFirstChild(FC_VIS_OBJ_NAME)
	if fcVisualizationObjects then
		return fcVisualizationObjects
	end

	fcVisualizationObjects = Instance.new("Folder")
	fcVisualizationObjects.Name = FC_VIS_OBJ_NAME
	fcVisualizationObjects.Archivable = false
	fcVisualizationObjects.Parent = workspace.Terrain
	return fcVisualizationObjects
end

local function GetTrajectoryInfo(
	idx: number,
	trajectoryIndex: number
): { [number]: Vector3 }
	assert(ActiveCastSOA.StateInfo_UpdateConnection[idx] ~= nil, "ERR_OBJECT_DISPOSED")
	local trajectories = ActiveCastSOA.StateInfo_Trajectories[idx]
	local trajectory = trajectories[trajectoryIndex]
	local duration = ActiveCastSOA.StateInfo_TotalRuntime[idx] - trajectory.StartTime

	local origin = trajectory.Origin
	local vel = trajectory.InitialVelocity
	local accel = trajectory.Acceleration

	return { GetPositionAtTime(duration, origin, vel, accel), GetVelocityAtTime(duration, vel, accel) }
end

local function GetLatestTrajectoryEndInfo(idx: number): { [number]: Vector3 }
	local trajectories = ActiveCastSOA.StateInfo_Trajectories[idx]
	return GetTrajectoryInfo(idx, #trajectories)
end

-- Debugging

local function DbgVisualizeSegment(
	castStartCFrame: CFrame,
	castLength: number,
	VisualizeCasts: boolean,
	VisualizeCastSettings: TypeDef.VisualizeCastSettings
): ConeHandleAdornment?
	if not VisualizeCasts then
		return
	end
	local adornment = Instance.new("ConeHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = castStartCFrame
	adornment.Height = castLength
	adornment.Color3 = VisualizeCastSettings.Debug_SegmentColor
	adornment.Radius = VisualizeCastSettings.Debug_SegmentSize
	adornment.Transparency = VisualizeCastSettings.Debug_SegmentTransparency
	adornment.Parent = GetFastCastVisualizationContainer()

	DebrisAdd(adornment, VisualizeCastSettings.Debug_RayLifetime)
	return adornment
end

local function DbgVisualizeHit(
	atCF: CFrame,
	wasPierce: boolean,
	VisualizeCasts: boolean,
	VisualizeCastSettings: TypeDef.VisualizeCastSettings
): SphereHandleAdornment?
	if not VisualizeCasts then
		return
	end
	local adornment = Instance.new("SphereHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = atCF
	adornment.Radius = (wasPierce == false) and VisualizeCastSettings.Debug_HitSize
		or VisualizeCastSettings.Debug_RayPierceSize
	adornment.Transparency = (wasPierce == false) and VisualizeCastSettings.Debug_HitTransparency
		or VisualizeCastSettings.Debug_RayPierceTransparency
	adornment.Color3 = (wasPierce == false) and VisualizeCastSettings.Debug_HitColor
		or VisualizeCastSettings.Debug_RayPierceColor
	adornment.Parent = GetFastCastVisualizationContainer()

	DebrisAdd(adornment, VisualizeCastSettings.Debug_HitLifetime)
	return adornment
end

-- Send signals

local function SendRayHit(
	idx: number,
	resultOfCast: RaycastResult,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
)
	local caster = ActiveCastSOA.Caster[idx]
	local castObject = CreateCastObject(idx)
	caster.Output:Fire("RayHit", castObject, resultOfCast, segmentVelocity, cosmeticBulletObject)
end

local function SendRayPierced(
	idx: number,
	resultOfCast: RaycastResult,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
)
	local caster = ActiveCastSOA.Caster[idx]
	local castObject = CreateCastObject(idx)
	caster.Output:Fire("RayPierced", castObject, resultOfCast, segmentVelocity, cosmeticBulletObject)
end

local function SendLengthChanged(
	idx: number,
	lastPoint: Vector3,
	rayDir: Vector3,
	rayDisplacement: number,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
)
	local caster = ActiveCastSOA.Caster[idx]
	local castObject = CreateCastObject(idx)
	caster.Output:Fire(
		"LengthChanged",
		castObject,
		lastPoint,
		rayDir,
		rayDisplacement,
		segmentVelocity,
		cosmeticBulletObject
	)
end

local function SimulateCast(idx: number, delta: number, expectingShortCall: boolean)
	assert(ActiveCastSOA.StateInfo_UpdateConnection[idx] ~= nil, "ERR_OBJECT_DISPOSED")

	if DebugLogging.Casting then
		print("Casting for frame.")
	end

	local latestTrajectory = ActiveCastSOA.StateInfo_Trajectories[idx][#ActiveCastSOA.StateInfo_Trajectories[idx]]

	local origin = latestTrajectory.Origin
	local totalDelta = ActiveCastSOA.StateInfo_TotalRuntime[idx] - latestTrajectory.StartTime
	local initialVelocity = latestTrajectory.InitialVelocity
	local acceleration = latestTrajectory.Acceleration

	local lastPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
	local lastDelta = ActiveCastSOA.StateInfo_TotalRuntime[idx] - latestTrajectory.StartTime

	ActiveCastSOA.StateInfo_TotalRuntime[idx] += delta

	totalDelta = ActiveCastSOA.StateInfo_TotalRuntime[idx] - latestTrajectory.StartTime

	local currentTarget = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
	local segmentVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
	local totalDisplacement = currentTarget - lastPoint

	local rayDir = totalDisplacement.Unit * segmentVelocity.Magnitude * delta

	local targetWorldRoot = ActiveCastSOA.RayInfo_WorldRoot[idx]
	local resultOfCast = targetWorldRoot:Raycast(lastPoint, rayDir, ActiveCastSOA.RayInfo_Parameters[idx])

	local point = currentTarget
	local part: Instance? = nil
	local material = Enum.Material.Air

	if resultOfCast ~= nil then
		point = resultOfCast.Position
		part = resultOfCast.Instance
		material = resultOfCast.Material
	end

	local rayDisplacement = (point - lastPoint).Magnitude

	local VisualizeCasts = ActiveCastSOA.StateInfo_VisualizeCasts[idx]
	local VisualizeCastSettings = ActiveCastSOA.StateInfo_VisualizeCastSettings[idx]

	ActiveCastSOA.CFrame[idx] = CFrame.new(lastPoint, lastPoint + rayDir) * CFrame.new(0, 0, -rayDisplacement / 2)

	local betterOnLengthChanged : TypeDef.OnLengthChangedFunction? = ActiveCastSOA.StateInfo_UseBetterLengthChanged[idx] and ResolveOnLengthChanged(idx)

	if ActiveCastSOA.StateInfo_UseLengthChanged[idx] then
		SendLengthChanged(
			idx,
			lastPoint,
			rayDir.Unit,
			rayDisplacement,
			segmentVelocity,
			ActiveCastSOA.RayInfo_CosmeticBulletObject[idx]
		)
	end

	if betterOnLengthChanged then
		local castObject = CreateCastObject(idx)
		betterOnLengthChanged(
			castObject,
			lastPoint,
			rayDir.Unit,
			rayDisplacement,
			segmentVelocity,
			ActiveCastSOA.RayInfo_CosmeticBulletObject[idx]
		)
	end

	ActiveCastSOA.StateInfo_DistanceCovered[idx] += rayDisplacement

	local rayVisualization: ConeHandleAdornment? = nil

	if delta > 0 then
		rayVisualization = DbgVisualizeSegment(
			CFrame.new(lastPoint, lastPoint + rayDir),
			rayDisplacement,
			VisualizeCasts,
			VisualizeCastSettings
		)
	end

	local canPierceCheck = ResolveCanPierceCheck(idx)

	if part and part ~= ActiveCastSOA.RayInfo_CosmeticBulletObject[idx] then
		local start = tick()

		if DebugLogging.Hit then
			print("Hit something, testing now.")
		end

		if canPierceCheck == nil then
			if DebugLogging.RayPierce then
				print("No piercing function set, proceeding to hit processing.")
			end
		end

		if ActiveCastSOA.RayInfo_CanPierceModule[idx] ~= nil then
			if expectingShortCall == false and ActiveCastSOA.StateInfo_IsActivelySimulatingPierce[idx] then
				local castObject = CreateCastObject(idx)
				castObject:Terminate()
				warn(
					"WARN: The latest call to CanPierceCallback took too long to complete! This cast is going to suffer desyncs which WILL cause unexpected behavior and errors. Please fix your performance problems, or remove statements that yield (e.g. wait() calls)"
				)
			end
			ActiveCastSOA.StateInfo_IsActivelySimulatingPierce[idx] = true
		end

		if canPierceCheck == nil or RunCanPierceCheck(idx, canPierceCheck, resultOfCast, segmentVelocity) == false then
			if DebugLogging.RayPierce then
				print("Piercing function is nil or it returned FALSE to not pierce this hit.")
			end

			ActiveCastSOA.StateInfo_IsActivelySimulatingPierce[idx] = false

			if
				ActiveCastSOA.StateInfo_HighFidelityBehavior[idx] == FastCastEnums.HighFidelityBehavior.Automatic
				and ActiveCastSOA.StateInfo_HighFidelitySegmentSize[idx] > 0
			then
				ActiveCastSOA.StateInfo_CancelHighResCast[idx] = false

				if ActiveCastSOA.StateInfo_IsActivelyResimulating[idx] then
					local castObject = CreateCastObject(idx)
					castObject:Terminate()
					warn(
						"Cascading cast lag encountered! The caster attempted to perform a high fidelity cast before the previous one completed, resulting in exponential cast lag. Consider increasing HighFidelitySegmentSize."
					)
				end

				ActiveCastSOA.StateInfo_IsActivelyResimulating[idx] = true

				if DebugLogging.Calculation then
					print(
						"Hit was registered, but recalculation is on for physics based casts. Recalculating to verify a real hit..."
					)
				end

				local numSegmentsDecimal = rayDisplacement / ActiveCastSOA.StateInfo_HighFidelitySegmentSize[idx]
				local numSegmentsReal = math.floor(numSegmentsDecimal)

				if numSegmentsReal == 0 then
					numSegmentsReal = 1
				end

				local timeIncrement = delta / numSegmentsReal

				if DebugLogging.Calculation then
					print(
						"Performing subcast! Time increment: " .. timeIncrement .. ", num segments: " .. numSegmentsReal
					)
				end

				for segmentIndex = 1, numSegmentsReal do
					if ActiveCastSOA.StateInfo_CancelHighResCast[idx] then
						ActiveCastSOA.StateInfo_CancelHighResCast[idx] = false
						break
					end

					local subPosition = GetPositionAtTime(
						lastDelta + (timeIncrement * segmentIndex),
						origin,
						initialVelocity,
						acceleration
					)
					local subVelocity =
						GetVelocityAtTime(lastDelta + (timeIncrement * segmentIndex), initialVelocity, acceleration)
					local subRayDir = subVelocity * delta
					local subResult = targetWorldRoot:Raycast(subPosition, subRayDir, ActiveCastSOA.RayInfo_Parameters[idx])

					local subDisplacement = (subPosition - (subPosition + subVelocity)).Magnitude

					if subResult ~= nil then
						local subDisplacement = (subPosition - subResult.Position).Magnitude
						local dbgSeg = DbgVisualizeSegment(
							CFrame.new(subPosition, subPosition + subVelocity),
							subDisplacement,
							VisualizeCasts,
							VisualizeCastSettings
						)
						if dbgSeg ~= nil then
							dbgSeg.Color3 = DBG_SEGMENT_SUB_COLOR
						end

						if
							canPierceCheck == nil
							or RunCanPierceCheck(idx, canPierceCheck, subResult, subVelocity) == false
						then
							ActiveCastSOA.StateInfo_IsActivelyResimulating[idx] = false

							SendRayHit(idx, subResult, subVelocity, ActiveCastSOA.RayInfo_CosmeticBulletObject[idx])
							local castObject = CreateCastObject(idx)
							castObject:Terminate()
							local vis = DbgVisualizeHit(CFrame.new(point), false, VisualizeCasts, VisualizeCastSettings)
							if vis ~= nil then
								vis.Color3 = DBG_HIT_SUB_COLOR
							end

							return
						else
							SendRayPierced(idx, subResult, subVelocity, ActiveCastSOA.RayInfo_CosmeticBulletObject[idx])
							local vis = DbgVisualizeHit(CFrame.new(point), true, VisualizeCasts, VisualizeCastSettings)
							if vis ~= nil then
								vis.Color3 = DBG_RAYPIERCE_SUB_COLOR
							end
						end
					else
						local dbgSeg = DbgVisualizeSegment(
							CFrame.new(subPosition, subPosition + subVelocity),
							subDisplacement,
							VisualizeCasts,
							VisualizeCastSettings
						)
						if dbgSeg ~= nil then
							dbgSeg.Color3 = DBG_SEGMENT_SUB_COLOR2
						end
					end

					if DebugLogging.Segment then
						print("[" .. segmentIndex .. "] Subcast of time increment " .. timeIncrement)
					end
				end

				ActiveCastSOA.StateInfo_IsActivelyResimulating[idx] = false
			else
				if DebugLogging.Hit then
					print("Hit was successful. Terminating.")
				end

				SendRayHit(idx, resultOfCast, segmentVelocity, ActiveCastSOA.RayInfo_CosmeticBulletObject[idx])
				local castObject = CreateCastObject(idx)
				castObject:Terminate()
				DbgVisualizeHit(CFrame.new(point), false, VisualizeCasts, VisualizeCastSettings)
				return
			end
		else
			if DebugLogging.RayPierce then
				print("Piercing function returned TRUE to pierce this part.")
			end

			if rayVisualization ~= nil then
				rayVisualization.Color3 = Color3.new(0.4, 0.05, 0.05)
			end
			DbgVisualizeHit(CFrame.new(point), true, VisualizeCasts, VisualizeCastSettings)

			local params = ActiveCastSOA.RayInfo_Parameters[idx]
			local alteredParts = {}
			local currentPierceTestCount = 0
			local originalFilter = params.FilterDescendantsInstances
			local brokeFromSolidObject = false
			while true do
				if resultOfCast.Instance:IsA("Terrain") then
					if material == Enum.Material.Water then
						local castObject = CreateCastObject(idx)
						castObject:Terminate()
						error(
							"Do not add Water as a piercable material. If you need to pierce water, set cast.RayInfo.Parameters.IgnoreWater = true instead",
							0
						)
					end
					warn(
						"WARNING: The pierce callback for this cast returned TRUE on Terrain! This can cause severely adverse effects."
					)
				end

				if params.FilterType == Enum.RaycastFilterType.Exclude then
					local filter = params.FilterDescendantsInstances
					table.insert(filter, resultOfCast.Instance)
					table.insert(alteredParts, resultOfCast.Instance)
					params.FilterDescendantsInstances = filter
				else
					local filter = params.FilterDescendantsInstances
					table.removeObject(filter, resultOfCast.Instance)
					table.insert(alteredParts, resultOfCast.Instance)
					params.FilterDescendantsInstances = filter
				end

				SendRayPierced(idx, resultOfCast, segmentVelocity, ActiveCastSOA.RayInfo_CosmeticBulletObject[idx])

				resultOfCast = targetWorldRoot:Raycast(lastPoint, rayDir, params)

				if resultOfCast == nil then
					break
				end

				if currentPierceTestCount >= MAX_PIERCE_TEST_COUNT then
					warn(
						"WARNING: Exceeded maximum pierce test budget for a single ray segment (attempted to test the same segment "
							.. MAX_PIERCE_TEST_COUNT
							.. " times!)"
					)
					break
				end
				currentPierceTestCount = currentPierceTestCount + 1

				if RunCanPierceCheck(idx, canPierceCheck, resultOfCast, segmentVelocity) == false then
					brokeFromSolidObject = true
					break
				end
			end

			ActiveCastSOA.RayInfo_Parameters[idx].FilterDescendantsInstances = originalFilter
			ActiveCastSOA.StateInfo_IsActivelySimulatingPierce[idx] = false

			if brokeFromSolidObject then
				if DebugLogging.Hit then
					print(
						"Broke because the ray hit something solid ("
							.. tostring(resultOfCast.Instance)
							.. ") while testing for a pierce. Terminating the cast."
					)
				end

				SendRayHit(idx, resultOfCast, segmentVelocity, ActiveCastSOA.RayInfo_CosmeticBulletObject[idx])
				local castObject = CreateCastObject(idx)
				castObject:Terminate()
				DbgVisualizeHit(CFrame.new(resultOfCast.Position), false, VisualizeCasts, VisualizeCastSettings)
				return
			end
		end
	end

	if ActiveCastSOA.StateInfo_DistanceCovered[idx] >= ActiveCastSOA.RayInfo_MaxDistance[idx] then
		local castObject = CreateCastObject(idx)
		castObject:Terminate()
		DbgVisualizeHit(CFrame.new(currentTarget), false, VisualizeCasts, VisualizeCastSettings)
	end
end

local function ModifyTransformation(
	idx: number,
	velocity: Vector3?,
	acceleration: Vector3?,
	position: Vector3?
)
	local trajectories = ActiveCastSOA.StateInfo_Trajectories[idx]
	local lastTrajectory = trajectories[#trajectories]

	if lastTrajectory.StartTime == ActiveCastSOA.StateInfo_TotalRuntime[idx] then
		if velocity ~= nil then
			lastTrajectory.InitialVelocity = velocity
		end
		if acceleration ~= nil then
			lastTrajectory.Acceleration = acceleration
		end
		if position ~= nil then
			lastTrajectory.Origin = position
		end
	else
		lastTrajectory.EndTime = ActiveCastSOA.StateInfo_TotalRuntime[idx]

		local point, velAtPoint = unpack(GetLatestTrajectoryEndInfo(idx))

		local newTrajectory = {
			StartTime = ActiveCastSOA.StateInfo_TotalRuntime[idx],
			EndTime = -1,
			Origin = position or point,
			InitialVelocity = velocity or velAtPoint,
			Acceleration = acceleration or lastTrajectory.Acceleration,
		}

		table.insert(trajectories, newTrajectory)
		ActiveCastSOA.StateInfo_CancelHighResCast[idx] = true
	end
end



function ActiveCastFunctions.Destroy(self)
	self:Terminate()
end

function ActiveCastFunctions.SetVelocity(self, velocity: Vector3)
	local idx = self._idx
	assert(idx and ActiveCastSOA.StateInfo_UpdateConnection[idx] ~= nil, "ERR_OBJECT_DISPOSED")
	ModifyTransformation(idx, velocity, nil, nil)
end

function ActiveCastFunctions.SetAcceleration(self, acceleration: Vector3)
	local idx = self._idx
	assert(idx and ActiveCastSOA.StateInfo_UpdateConnection[idx] ~= nil, "ERR_OBJECT_DISPOSED")
	ModifyTransformation(idx, nil, acceleration, nil)
end

function ActiveCastFunctions.SetPosition(self, position: Vector3)
	local idx = self._idx
	assert(idx and ActiveCastSOA.StateInfo_UpdateConnection[idx] ~= nil, "ERR_OBJECT_DISPOSED")
	ModifyTransformation(idx, nil, nil, position)
end

function ActiveCastFunctions.GetVelocity(self): Vector3
	local idx = self._idx
	assert(idx and ActiveCastSOA.StateInfo_UpdateConnection[idx] ~= nil, "ERR_OBJECT_DISPOSED")
	local currentTrajectory = ActiveCastSOA.StateInfo_Trajectories[idx][#ActiveCastSOA.StateInfo_Trajectories[idx]]
	return GetVelocityAtTime(
		ActiveCastSOA.StateInfo_TotalRuntime[idx] - currentTrajectory.StartTime,
		currentTrajectory.InitialVelocity,
		currentTrajectory.Acceleration
	)
end

function ActiveCastFunctions.GetAcceleration(self): Vector3
	local idx = self._idx
	assert(idx and ActiveCastSOA.StateInfo_UpdateConnection[idx] ~= nil, "ERR_OBJECT_DISPOSED")
	local currentTrajectory = ActiveCastSOA.StateInfo_Trajectories[idx][#ActiveCastSOA.StateInfo_Trajectories[idx]]
	return currentTrajectory.Acceleration
end

function ActiveCastFunctions.GetPosition(self): Vector3
	local idx = self._idx
	assert(idx and ActiveCastSOA.StateInfo_UpdateConnection[idx] ~= nil, "ERR_OBJECT_DISPOSED")
	local currentTrajectory = ActiveCastSOA.StateInfo_Trajectories[idx][#ActiveCastSOA.StateInfo_Trajectories[idx]]
	return GetPositionAtTime(
		ActiveCastSOA.StateInfo_TotalRuntime[idx] - currentTrajectory.StartTime,
		currentTrajectory.Origin,
		currentTrajectory.InitialVelocity,
		currentTrajectory.Acceleration
	)
end

function ActiveCastFunctions.AddVelocity(self, velocity: Vector3)
	local idx = self._idx
	assert(idx and ActiveCastSOA.StateInfo_UpdateConnection[idx] ~= nil, "ERR_OBJECT_DISPOSED")
	self:SetVelocity(self:GetVelocity() + velocity)
end

function ActiveCastFunctions.AddAcceleration(self, acceleration: Vector3)
	local idx = self._idx
	assert(idx and ActiveCastSOA.StateInfo_UpdateConnection[idx] ~= nil, "ERR_OBJECT_DISPOSED")
	self:SetAcceleration(self:GetAcceleration() + acceleration)
end

function ActiveCastFunctions.AddPosition(self, position: Vector3)
	local idx = self._idx
	assert(idx and ActiveCastSOA.StateInfo_UpdateConnection[idx] ~= nil, "ERR_OBJECT_DISPOSED")
	self:SetPosition(self:GetPosition() + position)
end

function ActiveCastFunctions.Pause(self)
	local idx = self._idx
	assert(idx and ActiveCastSOA.StateInfo_UpdateConnection[idx] ~= nil, "ERR_OBJECT_DISPOSED")
	ActiveCastSOA.StateInfo_Paused[idx] = true
end

function ActiveCastFunctions.Resume(self)
	local idx = self._idx
	assert(idx and ActiveCastSOA.StateInfo_UpdateConnection[idx] ~= nil, "ERR_OBJECT_DISPOSED")
	ActiveCastSOA.StateInfo_Paused[idx] = false
end


function ActiveCastFunctions.Terminate(self)
	local idx = self._idx
	assert(idx and ActiveCastSOA.StateInfo_UpdateConnection[idx] ~= nil, "ERR_OBJECT_DISPOSED")

	local trajectories = ActiveCastSOA.StateInfo_Trajectories[idx]
	if trajectories and #trajectories > 0 then
		trajectories[#trajectories].EndTime = ActiveCastSOA.StateInfo_TotalRuntime[idx]
	end

	if ActiveCastSOA.StateInfo_UpdateConnection[idx] then
		task.synchronize()
		ActiveCastSOA.StateInfo_UpdateConnection[idx]:Disconnect()
	end

	-- Fire termination event
	if ActiveCastSOA.Caster[idx] then
		ActiveCastSOA.Caster[idx].Output:Fire("CastTerminating", self)
		ActiveCastSOA.Caster[idx].ActiveCastCleaner:Fire(ActiveCastSOA.ID[idx])
	end

	-- Clear data
	ActiveCastSOA.Caster[idx] = nil
	ActiveCastSOA.StateInfo_UpdateConnection[idx] = nil
	ActiveCastSOA.StateInfo_Trajectories[idx] = nil
	ActiveCastSOA.RayInfo_Parameters[idx] = nil
	ActiveCastSOA.RayInfo_CosmeticBulletObject[idx] = nil
	ActiveCastSOA.UserData[idx] = nil

	-- Reset simple values
	ActiveCastSOA.StateInfo_Paused[idx] = false
	ActiveCastSOA.StateInfo_TotalRuntime[idx] = 0
	ActiveCastSOA.StateInfo_DistanceCovered[idx] = 0
	ActiveCastSOA.StateInfo_HighFidelitySegmentSize[idx] = 0
	ActiveCastSOA.StateInfo_IsActivelySimulatingPierce[idx] = false
	ActiveCastSOA.StateInfo_IsActivelyResimulating[idx] = false
	ActiveCastSOA.StateInfo_CancelHighResCast[idx] = false

	-- Add to free indices
	table.insert(ActiveCastSOA.FreeIndices, idx)
	ActiveCastSOA.ActiveCount -= 1
end

function CreateCastObject(idx)
	local castObject = {
		Caster = ActiveCastSOA.Caster[idx],
		CFrame = ActiveCastSOA.CFrame[idx],
		ID = ActiveCastSOA.ID[idx],
		UserData = ActiveCastSOA.UserData[idx],
		_idx = idx
	}

	castObject.StateInfo = {
		UpdateConnection = ActiveCastSOA.StateInfo_UpdateConnection[idx],
		Paused = ActiveCastSOA.StateInfo_Paused[idx],
		TotalRuntime = ActiveCastSOA.StateInfo_TotalRuntime[idx],
		DistanceCovered = ActiveCastSOA.StateInfo_DistanceCovered[idx],
		HighFidelitySegmentSize = ActiveCastSOA.StateInfo_HighFidelitySegmentSize[idx],
		HighFidelityBehavior = ActiveCastSOA.StateInfo_HighFidelityBehavior[idx],
		IsActivelySimulatingPierce = ActiveCastSOA.StateInfo_IsActivelySimulatingPierce[idx],
		IsActivelyResimulating = ActiveCastSOA.StateInfo_IsActivelyResimulating[idx],
		CancelHighResCast = ActiveCastSOA.StateInfo_CancelHighResCast[idx],
		Trajectories = ActiveCastSOA.StateInfo_Trajectories[idx],
		VisualizeCasts = ActiveCastSOA.StateInfo_VisualizeCasts[idx],
		VisualizeCastSettings = ActiveCastSOA.StateInfo_VisualizeCastSettings[idx],
		UseLengthChanged = ActiveCastSOA.StateInfo_UseLengthChanged[idx],
		UseBetterLengthChanged = ActiveCastSOA.StateInfo_UseBetterLengthChanged[idx]
	}

	castObject.RayInfo = {
		Parameters = ActiveCastSOA.RayInfo_Parameters[idx],
		WorldRoot = ActiveCastSOA.RayInfo_WorldRoot[idx],
		MaxDistance = ActiveCastSOA.RayInfo_MaxDistance[idx],
		CosmeticBulletObject = ActiveCastSOA.RayInfo_CosmeticBulletObject[idx],
		FastCastEventsModule = ActiveCastSOA.RayInfo_FastCastEventsModule[idx],
		CanPierceModule = ActiveCastSOA.RayInfo_CanPierceModule[idx],
		BetterLengthChangedModule = ActiveCastSOA.RayInfo_BetterLengthChangedModule[idx]
	}

	castObject.Destroy = ActiveCastFunctions.Destroy
	castObject.Terminate = ActiveCastFunctions.Terminate
	castObject.SetVelocity = ActiveCastFunctions.SetVelocity
	castObject.SetAcceleration = ActiveCastFunctions.SetAcceleration
	castObject.SetPosition = ActiveCastFunctions.SetPosition
	castObject.GetVelocity = ActiveCastFunctions.GetVelocity
	castObject.GetAcceleration = ActiveCastFunctions.GetAcceleration
	castObject.GetPosition = ActiveCastFunctions.GetPosition
	castObject.AddVelocity = ActiveCastFunctions.AddVelocity
	castObject.AddAcceleration = ActiveCastFunctions.AddAcceleration
	castObject.AddPosition = ActiveCastFunctions.AddPosition
	castObject.Pause = ActiveCastFunctions.Pause
	castObject.Resume = ActiveCastFunctions.Resume

	return castObject
end

--[=[
	@function new
	@private
	@within ActiveCast

	Creates a new ActiveCast instance with the given parameters.

	@return ActiveCast -- The newly created ActiveCast instance.
]=]

function ActiveCast.new(
	BaseCast: TypeDef.BaseCastData,
	activeCastID: string,
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: TypeDef.FastCastBehavior,
	FastCastEventsModule: TypeDef.FastCastEventsModule
): TypeDef.ActiveCast
	if typeof(velocity) == "number" then
		velocity = direction.Unit * velocity
	end

	if behavior.HighFidelitySegmentSize <= 0 then
		error("Cannot set FastCastBehavior.HighFidelitySegmentSize <= 0!", 0)
	end

	if behavior.HighFidelityBehavior <= 0 then
		behavior.HighFidelityBehavior = 1
	elseif behavior.HighFidelityBehavior >= 4 then
		behavior.HighFidelityBehavior = 3
	end

	-- Get or create index
	local idx
	if #ActiveCastSOA.FreeIndices > 0 then
		idx = table.remove(ActiveCastSOA.FreeIndices)
	else
		idx = #ActiveCastSOA.Caster + 1
	end

	-- Store data in SoA arrays
	ActiveCastSOA.Caster[idx] = BaseCast

	ActiveCastSOA.StateInfo_Paused[idx] = false
	ActiveCastSOA.StateInfo_TotalRuntime[idx] = 0
	ActiveCastSOA.StateInfo_DistanceCovered[idx] = 0
	ActiveCastSOA.StateInfo_HighFidelitySegmentSize[idx] = behavior.HighFidelitySegmentSize
	ActiveCastSOA.StateInfo_HighFidelityBehavior[idx] = behavior.HighFidelityBehavior
	ActiveCastSOA.StateInfo_IsActivelySimulatingPierce[idx] = false
	ActiveCastSOA.StateInfo_IsActivelyResimulating[idx] = false
	ActiveCastSOA.StateInfo_CancelHighResCast[idx] = false
	ActiveCastSOA.StateInfo_UseLengthChanged[idx] = behavior.UseLengthChanged or false
	ActiveCastSOA.StateInfo_UseBetterLengthChanged[idx] = behavior.UseBetterLengthChanged or false

	ActiveCastSOA.StateInfo_Trajectories[idx] = {
		{
			StartTime = 0,
			EndTime = -1,
			Origin = origin,
			InitialVelocity = velocity,
			Acceleration = behavior.Acceleration or Vector3.new(),
		},
	}

	ActiveCastSOA.StateInfo_VisualizeCasts[idx] = behavior.VisualizeCasts
	ActiveCastSOA.StateInfo_VisualizeCastSettings[idx] = behavior.VisualizeCastSettings

	if behavior.RaycastParams ~= nil then
		ActiveCastSOA.RayInfo_Parameters[idx] = CloneCastParams(behavior.RaycastParams)
	else
		ActiveCastSOA.RayInfo_Parameters[idx] = RaycastParams.new()
	end

	ActiveCastSOA.RayInfo_WorldRoot[idx] = workspace
	ActiveCastSOA.RayInfo_MaxDistance[idx] = behavior.MaxDistance or DEFAULT_MAX_DISTANCE
	ActiveCastSOA.RayInfo_FastCastEventsModule[idx] = FastCastEventsModule
	ActiveCastSOA.RayInfo_CanPierceModule[idx] = behavior.CanPierceModule
	ActiveCastSOA.RayInfo_BetterLengthChangedModule[idx] = behavior.BetterLengthChangedModule

	ActiveCastSOA.UserData[idx] = {}
	ActiveCastSOA.CFrame[idx] = CFrame.new(origin, origin + direction)
	ActiveCastSOA.ID[idx] = activeCastID

	-- CosmeticBulletObject GET
	local targetContainer: Instance
	if BaseCast.ObjectCache then
		ActiveCastSOA.RayInfo_CosmeticBulletObject[idx] = BaseCast.ObjectCache:Invoke(CFrame.new(origin, origin + direction))
		targetContainer = BaseCast.CacheHolder
	else
		if behavior.CosmeticBulletTemplate ~= nil then
			ActiveCastSOA.RayInfo_CosmeticBulletObject[idx] = behavior.CosmeticBulletTemplate:Clone()
			ActiveCastSOA.RayInfo_CosmeticBulletObject[idx].CFrame = CFrame.new(origin, origin + direction)
			ActiveCastSOA.RayInfo_CosmeticBulletObject[idx].Parent = behavior.CosmeticBulletContainer
		end
		if behavior.CosmeticBulletContainer then
			targetContainer = behavior.CosmeticBulletContainer
		end
	end

	if behavior.AutoIgnoreContainer == true and targetContainer ~= nil then
		local ignoreList = ActiveCastSOA.RayInfo_Parameters[idx].FilterDescendantsInstances
		if not table.find(ignoreList, targetContainer) then
			table.insert(ignoreList, targetContainer)
			ActiveCastSOA.RayInfo_Parameters[idx].FilterDescendantsInstances = ignoreList
		end
	end

	local event
	if RS:IsClient() then
		event = behavior.SimulateAfterPhysic and RS.Heartbeat or RS.PostSimulation
	else
		event = RS.Heartbeat
	end

	local castObject = CreateCastObject(idx)

	local function Stepped(delta: number)
		if ActiveCastSOA.StateInfo_Paused[idx] then
			return
		end

		if DebugLogging.Casting then
			print("Casting for frame.")
		end

		local Cast_timeAtStart = tick()

		local latestTrajectory = ActiveCastSOA.StateInfo_Trajectories[idx][#ActiveCastSOA.StateInfo_Trajectories[idx]]

		if
			ActiveCastSOA.StateInfo_HighFidelityBehavior[idx] == FastCastEnums.HighFidelityBehavior.Always
			and ActiveCastSOA.StateInfo_HighFidelitySegmentSize[idx] > 0
		then
			local Segment_timeAtStart = tick()

			if ActiveCastSOA.StateInfo_IsActivelyResimulating[idx] then
				castObject:Terminate()
				warn(
					"Cascading cast lag encountered! The caster attempted to perform a high fidelity cast before the previous one completed, resulting in exponential cast lag. Consider increasing HighFidelitySegmentSize."
				)
			end

			ActiveCastSOA.StateInfo_IsActivelyResimulating[idx] = true

			local origin = latestTrajectory.Origin
			local totalDelta = ActiveCastSOA.StateInfo_TotalRuntime[idx] - latestTrajectory.StartTime
			local initialVelocity = latestTrajectory.InitialVelocity
			local acceleration = latestTrajectory.Acceleration

			local lastPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)

			ActiveCastSOA.StateInfo_TotalRuntime[idx] += delta

			totalDelta = ActiveCastSOA.StateInfo_TotalRuntime[idx] - latestTrajectory.StartTime

			local currentPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
			local currentVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
			local totalDisplacement = currentPoint - lastPoint

			local rayDir = totalDisplacement.Unit * currentVelocity.Magnitude * delta

			local targetWorldRoot = ActiveCastSOA.RayInfo_WorldRoot[idx]
			local resultOfCast = targetWorldRoot:Raycast(lastPoint, rayDir, ActiveCastSOA.RayInfo_Parameters[idx])

			local point = currentPoint

			if resultOfCast ~= nil then
				point = resultOfCast.Position
			end

			local rayDisplacement = (point - lastPoint).Magnitude

			ActiveCastSOA.StateInfo_TotalRuntime[idx] -= delta

			local numSegmentsDecimal = rayDisplacement / ActiveCastSOA.StateInfo_HighFidelitySegmentSize[idx]
			local numSegmentsReal = math.floor(numSegmentsDecimal)
			if numSegmentsReal == 0 then
				numSegmentsReal = 1
			end

			local timeIncrement = delta / numSegmentsReal

			if DebugLogging.Calculation then
				print("Performing subcast! Time increment: " .. timeIncrement .. ", num segments: " .. numSegmentsReal)
			end

			for segmentIndex = 1, numSegmentsReal do
				if ActiveCastSOA.StateInfo_CancelHighResCast[idx] then
					ActiveCastSOA.StateInfo_CancelHighResCast[idx] = false
					break
				end

				if DebugLogging.Segment then
					print("[" .. segmentIndex .. "] Subcast of time increment " .. timeIncrement)
				end

				SimulateCast(idx, timeIncrement, true)
			end

			ActiveCastSOA.StateInfo_IsActivelyResimulating[idx] = false

			if behavior.AutomaticPerformance and (tick() - Segment_timeAtStart) > MAX_SEGMENT_CAL_TIME then
				local HighFideSizeAmount = behavior.AdaptivePerformance.HighFidelitySegmentSizeIncrease
					or HIGH_FIDE_INCREASE_SIZE

				if DebugLogging.AutomaticPerformance then
					warn("AutomaticPerformance increasing size of HighFidelitySize by : ", HighFideSizeAmount)
				end

				ActiveCastSOA.StateInfo_HighFidelitySegmentSize[idx] += HighFideSizeAmount
			end
		else
			SimulateCast(idx, delta, false)
		end

		if
			behavior.AutomaticPerformance
			and behavior.AdaptivePerformance.LowerHighFidelityBehavior
			and (tick() - Cast_timeAtStart) > MAX_CASTING_TIME 
		then
			if ActiveCastSOA.StateInfo_HighFidelityBehavior[idx] > 1 then
				ActiveCastSOA.StateInfo_HighFidelityBehavior[idx] -= 1
			end
		end
	end

	ActiveCastSOA.StateInfo_UpdateConnection[idx] = event:ConnectParallel(Stepped)
	ActiveCastSOA.ActiveCount += 1

	return castObject
end

return ActiveCast