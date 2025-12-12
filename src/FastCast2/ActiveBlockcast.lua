--[[
	- Author : Mawin CK 
	- Date : 2025
]]

-- Services
local RS = game:GetService("RunService")

-- Variables
local FastCastModule = script.Parent

-- Requires
--local UtilityModule = FastCastModule:WaitForChild("Utility")

local FastCastEnums = require(FastCastModule:WaitForChild("FastCastEnums"))
--local Utility = require(UtilityModule)
local TypeDef = require(FastCastModule:WaitForChild("TypeDefinitions"))
local ErrorMsgs = require(script.Parent:WaitForChild("ErrorMessage"))
--local MathUtil = require(UtilityModule.Math)
local Configs = require(FastCastModule:WaitForChild("Configs"))
--local LookUpTables = require(FastCastModule:WaitForChild("LookUpTables"))

-- CONSTs
local MAX_PIERCE_TEST_COUNT = 100
local FC_VIS_OBJ_NAME = "FastCastVisualizationObjects"


--- ActiveCast

local ActiveCast = {}

ActiveCast.__index = ActiveCast
ActiveCast.__type = "ActiveBlockCast"

-----> Local functions

local function GetPositionAtTime(time: number, origin: Vector3, initialVelocity: Vector3, acceleration: Vector3): Vector3
	local force = Vector3.new((acceleration.X * time^2) / 2,(acceleration.Y * time^2) / 2, (acceleration.Z * time^2) / 2)
	return origin + (initialVelocity * time) + force
end

local function GetVelocityAtTime(time: number, initialVelocity: Vector3, acceleration: Vector3): Vector3
	return initialVelocity + acceleration * time
end

local function CloneCastParams(params: RaycastParams): RaycastParams
	local clone : RaycastParams = RaycastParams.new()
	clone.CollisionGroup = params.CollisionGroup
	clone.FilterType = params.FilterType
	clone.FilterDescendantsInstances = params.FilterDescendantsInstances
	clone.IgnoreWater = params.IgnoreWater
	return clone
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
	cast: TypeDef.ActiveCast | TypeDef.ActiveBlockCast, 
	index: number
): {[number]: Vector3}
	assert(cast.StateInfo.UpdateConnection ~= nil, ErrorMsgs.ERR_OBJECT_DISPOSED)
	local trajectories = cast.StateInfo.Trajectories
	local trajectory = trajectories[index]
	local duration = trajectory.EndTime - trajectory.StartTime

	local origin = trajectory.Origin
	local vel = trajectory.InitialVelocity
	local accel = trajectory.Acceleration

	return {GetPositionAtTime(duration, origin, vel, accel), GetVelocityAtTime(duration, vel, accel)}
end

local function GetLatestTrajectoryEndInfo(cast: TypeDef.ActiveCast | TypeDef.ActiveBlockCast): {[number]: Vector3}
	return GetTrajectoryInfo(cast, #cast.StateInfo.Trajectories)
end

---> Debugging

local function PrintDebug(message : string)
	if Configs.DebugLogging then
		print(message)
	end
end

local function DbgVisualizeSegment(castStartCFrame: CFrame, size : Vector3, castLength: number) : BoxHandleAdornment?
	if Configs.VisualizeCasts ~= true then return nil end
	local adornment = Instance.new("BoxHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = castStartCFrame
	--adornment.Height = castLength
	adornment.Size = Vector3.new(size.X, size.Y, castLength)
	adornment.Color3 = Color3.new()
	--adornment.Radius = 0.25
	adornment.Transparency = 0.5
	adornment.Parent = GetFastCastVisualizationContainer()
	return adornment
end

local function DbgVisualizeHit(atCF: CFrame, size : Vector3, wasPierce: boolean): BoxHandleAdornment?
	if Configs.VisualizeCasts ~= true then return nil end
	local adornment = Instance.new("BoxHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = atCF
	--adornment.Radius = 0.4
	adornment.Size = size
	adornment.Transparency = 0.25
	adornment.Color3 = (wasPierce == false) and Color3.new(0.2, 1, 0.5) or Color3.new(1, 0.2, 0.2)
	adornment.Parent = GetFastCastVisualizationContainer()
	return adornment
end

---> Send signals

local function SendRayHit(
	cast : TypeDef.ActiveBlockCast,
	resultOfCast : RaycastResult,
	segmentVelocity : Vector3,
	cosmeticBulletObject : Instance?
)
	--cast.Caster.RayHit:Fire(cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
	--cast.CasterBindable:Fire("RayHit", cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
	--cast.Definition.OnRayHit(cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
	cast.Caster.Output:Fire(
		"RayHit",
		cast, 
		resultOfCast, 
		segmentVelocity, 
		cosmeticBulletObject
	)
end

local function SendRayPierced(
	cast : TypeDef.ActiveBlockCast, 
	resultOfCast : RaycastResult,
	segmentVelocity : Vector3,
	cosmeticBulletObject : Instance?
)
	--cast.Caster.RayPierced:Fire(cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
	--cast.CasterBindable:Fire("RayPierced", cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
	--cast.Definition.OnRayPierce(ActiveCast, resultOfCast, segmentVelocity, cosmeticBulletObject)
	cast.Caster.Output:Fire(
		"RayPierced",
		cast, 
		resultOfCast, 
		segmentVelocity, 
		cosmeticBulletObject
	)
end

local function SendLengthChanged(
	cast : TypeDef.ActiveBlockCast,
	lastPoint : Vector3,
	rayDir : Vector3, 
	rayDisplacement : number,
	segmentVelocity : Vector3,
	cosmeticBulletObject : Instance?
)
	--cast.Caster.LengthChanged:Fire(cast, lastPoint, rayDir, rayDisplacement, cosmeticBulletObject)
	--cast.Definition.OnLengthChanged(ActiveCast, lastPoint, rayDir, rayDisplacement, segmentVelocity, cosmeticBulletObject)
	--cast.Caster.LengthChanged:Fire(ActiveCast, lastPoint, rayDir, rayDisplacement, segmentVelocity, cosmeticBulletObject)

	--print(cast.Caster.Output)
	cast.Caster.Output:Fire(
		"LengthChanged",
		cast, 
		lastPoint, 
		rayDir, 
		rayDisplacement, 
		segmentVelocity, 
		cosmeticBulletObject
	)
end

local function SimulateCast(
	cast : TypeDef.ActiveBlockCast, 
	delta : number, 
	expectingShortCall : boolean
)
	assert(cast.StateInfo.UpdateConnection ~= nil, ErrorMsgs.ERR_OBJECT_DISPOSED)

	PrintDebug("Casting for frame.")

	local latestTrajectory = cast.StateInfo.Trajectories[#cast.StateInfo.Trajectories]

	local origin = latestTrajectory.Origin
	local totalDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime
	local initialVelocity = latestTrajectory.InitialVelocity
	local acceleration = latestTrajectory.Acceleration

	local lastPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
	local lastVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
	local lastDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime

	cast.StateInfo.TotalRuntime += delta

	totalDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime

	local currentTarget = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
	local segmentVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
	local totalDisplacement = currentTarget - lastPoint

	local rayDir = totalDisplacement.Unit * segmentVelocity.Magnitude * delta

	local targetWorldRoot = cast.RayInfo.WorldRoot
	local resultOfCast = targetWorldRoot:Blockcast(lastPoint, cast.RayInfo.Size, rayDir, cast.RayInfo.Parameters)

	local point = currentTarget
	local part: Instance? = nil
	local material = Enum.Material.Air
	local normal = Vector3.new()

	if (resultOfCast ~= nil) then
		point = resultOfCast.Position
		part = resultOfCast.Instance
		material = resultOfCast.Material
		normal = resultOfCast.Normal
	end

	local rayDisplacement = (point - lastPoint).Magnitude
	local BlockcastSize = cast.RayInfo.Size

	task.synchronize()

	if cast.StateInfo.UseLengthChanged then
		SendLengthChanged(cast, lastPoint, rayDir.Unit, rayDisplacement, segmentVelocity, cast.RayInfo.CosmeticBulletObject)
	end
	cast.StateInfo.DistanceCovered += rayDisplacement

	local rayVisualization: ConeHandleAdornment? = nil

	if (delta > 0) then
		rayVisualization = DbgVisualizeSegment(CFrame.new(lastPoint, lastPoint + rayDir), BlockcastSize, rayDisplacement)
	end

	if part and part ~= cast.RayInfo.CosmeticBulletObject then
		local start = tick()
		PrintDebug("Hit something, testing now.")

		if (cast.RayInfo.CanPierceCallback ~= nil) then
			if expectingShortCall == false then
				if (cast.StateInfo.IsActivelySimulatingPierce) then
					cast:Terminate()
					error("ERROR: The latest call to CanPierceCallback took too long to complete! This cast is going to suffer desyncs which WILL cause unexpected behavior and errors. Please fix your performance problems, or remove statements that yield (e.g. wait() calls)")
				end
			end
			cast.StateInfo.IsActivelySimulatingPierce = true
		end

		if cast.RayInfo.CanPierceCallback == nil or (cast.RayInfo.CanPierceCallback ~= nil and cast.RayInfo.CanPierceCallback(cast, resultOfCast, segmentVelocity, cast.RayInfo.CosmeticBulletObject) == false) then
			PrintDebug("Piercing function is nil or it returned FALSE to not pierce this hit.")
			cast.StateInfo.IsActivelySimulatingPierce = false

			if (cast.StateInfo.HighFidelityBehavior == 2 and latestTrajectory.Acceleration ~= Vector3.new() and cast.StateInfo.HighFidelitySegmentSize ~= 0) then
				cast.StateInfo.CancelHighResCast = false

				if cast.StateInfo.IsActivelyResimulating then
					cast:Terminate()
					error("Cascading cast lag encountered! The caster attempted to perform a high fidelity cast before the previous one completed, resulting in exponential cast lag. Consider increasing HighFidelitySegmentSize.")
				end

				cast.StateInfo.IsActivelyResimulating = true

				PrintDebug("Hit was registered, but recalculation is on for physics based casts. Recalculating to verify a real hit...")

				local numSegmentsDecimal = rayDisplacement / cast.StateInfo.HighFidelitySegmentSize
				local numSegmentsReal = math.floor(numSegmentsDecimal)
				local realSegmentLength = rayDisplacement / numSegmentsReal

				local timeIncrement = delta / numSegmentsReal
				for segmentIndex = 1, numSegmentsReal do
					if cast.StateInfo.CancelHighResCast then
						cast.StateInfo.CancelHighResCast = false
						break
					end

					local subPosition = GetPositionAtTime(lastDelta + (timeIncrement * segmentIndex), origin, initialVelocity, acceleration)
					local subVelocity = GetVelocityAtTime(lastDelta + (timeIncrement * segmentIndex), initialVelocity, acceleration)
					local subRayDir = subVelocity * delta
					local subResult = targetWorldRoot:Raycast(subPosition, subRayDir, cast.RayInfo.Parameters)

					local subDisplacement = (subPosition - (subPosition + subVelocity)).Magnitude

					if (subResult ~= nil) then
						local subDisplacement = (subPosition - subResult.Position).Magnitude
						local dbgSeg = DbgVisualizeSegment(CFrame.new(subPosition, subPosition + subVelocity), BlockcastSize, subDisplacement)
						if (dbgSeg ~= nil) then dbgSeg.Color3 = Color3.new(0.286275, 0.329412, 0.247059) end

						if cast.RayInfo.CanPierceCallback == nil or (cast.RayInfo.CanPierceCallback ~= nil and cast.RayInfo.CanPierceCallback(cast, subResult, subVelocity, cast.RayInfo.CosmeticBulletObject) == false) then
							cast.StateInfo.IsActivelyResimulating = false

							SendRayHit(cast, subResult, subVelocity, cast.RayInfo.CosmeticBulletObject)
							cast:Terminate()
							local vis = DbgVisualizeHit(CFrame.new(point), BlockcastSize, false)
							if (vis ~= nil) then vis.Color3 = Color3.new(0.0588235, 0.87451, 1) end
							return
						else
							SendRayPierced(cast, subResult, subVelocity, cast.RayInfo.CosmeticBulletObject)
							local vis = DbgVisualizeHit(CFrame.new(point), BlockcastSize, true)
							if (vis ~= nil) then vis.Color3 = Color3.new(1, 0.113725, 0.588235) end
							if (dbgSeg ~= nil) then dbgSeg.Color3 = Color3.new(0.305882, 0.243137, 0.329412) end
						end
					else
						local dbgSeg = DbgVisualizeSegment(CFrame.new(subPosition, subPosition + subVelocity), BlockcastSize, subDisplacement)
						if (dbgSeg ~= nil) then dbgSeg.Color3 = Color3.new(0.286275, 0.329412, 0.247059) end
					end
				end

				cast.StateInfo.IsActivelyResimulating = false
			elseif (cast.StateInfo.HighFidelityBehavior ~= 1 and cast.StateInfo.HighFidelityBehavior ~= 3) then
				cast:Terminate()
				error("Invalid value " .. (cast.StateInfo.HighFidelityBehavior) .. " for HighFidelityBehavior.")
			else
				PrintDebug("Hit was successful. Terminating.")
				SendRayHit(cast, resultOfCast, segmentVelocity, cast.RayInfo.CosmeticBulletObject)
				cast:Terminate()
				DbgVisualizeHit(CFrame.new(point), BlockcastSize, false)
				return
			end
		else
			PrintDebug("Piercing function returned TRUE to pierce this part.")
			if rayVisualization ~= nil then
				rayVisualization.Color3 = Color3.new(0.4, 0.05, 0.05)
			end
			DbgVisualizeHit(CFrame.new(point), BlockcastSize, true)

			local params = cast.RayInfo.Parameters
			local alteredParts = {}
			local currentPierceTestCount = 0
			local originalFilter = params.FilterDescendantsInstances
			local brokeFromSolidObject = false
			while true do
				if resultOfCast.Instance:IsA("Terrain") then
					if material == Enum.Material.Water then
						cast:Terminate()
						error("Do not add Water as a piercable material. If you need to pierce water, set cast.RayInfo.Parameters.IgnoreWater = true instead", 0)
					end
					warn("WARNING: The pierce callback for this cast returned TRUE on Terrain! This can cause severely adverse effects.")
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

				SendRayPierced(cast, resultOfCast, segmentVelocity, cast.RayInfo.CosmeticBulletObject)

				resultOfCast = targetWorldRoot:Raycast(lastPoint, rayDir, params)

				if resultOfCast == nil then
					break
				end

				if currentPierceTestCount >= MAX_PIERCE_TEST_COUNT then
					warn("WARNING: Exceeded maximum pierce test budget for a single ray segment (attempted to test the same segment " .. MAX_PIERCE_TEST_COUNT .. " times!)")
					break
				end
				currentPierceTestCount = currentPierceTestCount + 1;

				if cast.RayInfo.CanPierceCallback(cast, resultOfCast, segmentVelocity, cast.RayInfo.CosmeticBulletObject) == false then
					brokeFromSolidObject = true
					break
				end
			end

			cast.RayInfo.Parameters.FilterDescendantsInstances = originalFilter
			cast.StateInfo.IsActivelySimulatingPierce = false

			if brokeFromSolidObject then
				PrintDebug("Broke because the ray hit something solid (" .. tostring(resultOfCast.Instance) .. ") while testing for a pierce. Terminating the cast.")
				SendRayHit(cast, resultOfCast, segmentVelocity, cast.RayInfo.CosmeticBulletObject)
				cast:Terminate()
				DbgVisualizeHit(CFrame.new(resultOfCast.Position), BlockcastSize, false)
				return
			end
		end
	end

	if (cast.StateInfo.DistanceCovered >= cast.RayInfo.MaxDistance) then
		cast:Terminate()
		DbgVisualizeHit(CFrame.new(currentTarget), BlockcastSize, false)
	end
end

---> ActiveCast functions

function ActiveCast.new(
	BaseCast : TypeDef.BaseCastData,
	activeCastID : string,
	origin : Vector3, 
	size : Vector3,
	direction : Vector3,
	velocity : Vector3 | number, 
	behavior : TypeDef.FastCastBehavior
): TypeDef.ActiveCast
	if typeof(velocity) == "number" then
		velocity = direction.Unit * velocity
	end


	if (behavior.HighFidelitySegmentSize <= 0) then
		error("Cannot set FastCastBehavior.HighFidelitySegmentSize <= 0!", 0)
	end

	local cast : TypeDef.ActiveBlockCast = {
		Caster = BaseCast,

		StateInfo = {
			UpdateConnection = nil,
			Paused = false,
			TotalRuntime = 0,
			DistanceCovered = 0,
			HighFidelitySegmentSize = behavior.HighFidelitySegmentSize,
			HighFidelityBehavior = behavior.HighFidelityBehavior,
			IsActivelySimulatingPierce = false,
			IsActivelyResimulating = false,
			CancelHighResCast = false,
			Trajectories = {
				{
					StartTime = 0,
					EndTime = -1,
					Origin = origin,
					InitialVelocity = velocity,
					Acceleration = behavior.Acceleration
				}
			},
			UseLengthChanged = behavior.UseLengthChanged
			--OnParallel = false
		},

		RayInfo = {
			Size = size,
			Parameters = behavior.RaycastParams,
			WorldRoot = workspace,
			MaxDistance = behavior.MaxDistance or 1000,
			CosmeticBulletObject = behavior.CosmeticBulletTemplate,
			CanPierceCallback = behavior.CanPierceFunction
		},

		UserData = {},
		ID = activeCastID
	}

	if cast.StateInfo.HighFidelityBehavior == 2 then
		cast.StateInfo.HighFidelityBehavior = 3
	end

	if cast.RayInfo.Parameters ~= nil then
		cast.RayInfo.Parameters = CloneCastParams(cast.RayInfo.Parameters)
	else
		cast.RayInfo.Parameters = RaycastParams.new()
	end

	---> CosmeticBulletObject GET

	local targetContainer: Instance;
	if cast.Caster.ObjectCache then
		if cast.RayInfo.CosmeticBulletObject ~= nil then
			warn("ObjectCache already handle that for you, Template Dupe")
		end
		cast.RayInfo.CosmeticBulletObject = cast.Caster.ObjectCache:Invoke(CFrame.new(origin, origin + direction))
		targetContainer = cast.Caster.CacheHolder
	else
		if cast.RayInfo.CosmeticBulletObject ~= nil then
			cast.RayInfo.CosmeticBulletObject = cast.RayInfo.CosmeticBulletObject:Clone()
			cast.RayInfo.CosmeticBulletObject.CFrame = CFrame.new(origin, origin + direction)
			cast.RayInfo.CosmeticBulletObject.Parent = behavior.CosmeticBulletContainer
		end
		if behavior.CosmeticBulletContainer then
			targetContainer = behavior.CosmeticBulletContainer
		else
			error("CosmeticBulletContainer is nil")
		end
	end
	
	--[[local usingProvider = false
	if behavior.CosmeticBulletProvider == nil then
		if cast.RayInfo.CosmeticBulletObject ~= nil then
			cast.RayInfo.CosmeticBulletObject = cast.RayInfo.CosmeticBulletObject:Clone()
			cast.RayInfo.CosmeticBulletObject.CFrame = CFrame.new(origin, origin + direction)
			cast.RayInfo.CosmeticBulletObject.Parent = behavior.CosmeticBulletContainer
		end
	else
		local LIB_GETPART = LookUpTables.Supported_Lib_GETPART[typeof(behavior.CosmeticBulletProvider)]
		if cast.RayInfo.CosmeticBulletObject ~= nil then
			warn("Do not define FastCastBehavior.CosmeticBulletTemplate and FastCastBehavior.CosmeticBulletProvider at the same time! The provider will be used, and CosmeticBulletTemplate will be set to nil.")
			cast.RayInfo.CosmeticBulletObject = nil
			behavior.CosmeticBulletTemplate = nil
		end

		if LIB_GETPART then
			cast.RayInfo.CosmeticBulletObject = LIB_GETPART(behavior.CosmeticBulletProvider, origin, direction)
			usingProvider = true
		else
			warn("FastCastBehavior.CosmeticBulletProvider was not an instance of the PartCache module (an external/separate model)! Are you inputting an instance created via PartCache.new? If so, are you on the latest version of PartCache? Setting FastCastBehavior.CosmeticBulletProvider to nil.")
			behavior.CosmeticBulletProvider = nil
		end
	end

	---> CosmeticBulletObject Container GET

	local targetContainer: Instance;
	local LIB_GETCONTAINER = LookUpTables.Supported_Lib_GETCONTAINER[typeof(behavior.CosmeticBulletProvider)]

	if usingProvider then
		if LIB_GETCONTAINER then
			targetContainer = LIB_GETCONTAINER(behavior.CosmeticBulletProvider)
		else
			warn("No TargetContainer for Supported lib")
		end
	else
		targetContainer = behavior.CosmeticBulletContainer
	end]]

	-- the rest? :P

	if behavior.AutoIgnoreContainer == true and targetContainer ~= nil then
		local igroneList = cast.RayInfo.Parameters.FilterDescendantsInstances
		if not table.find(igroneList, targetContainer) then
			table.insert(igroneList, targetContainer)
			cast.RayInfo.Parameters.FilterDescendantsInstances = igroneList
		end
	end

	local event
	if RS:IsClient() then
		event = behavior.SimulateAfterPhysic and RS.Heartbeat or RS.PostSimulation
	else
		event = RS.Heartbeat
	end

	setmetatable(cast, ActiveCast)

	local function Stepped(delta : number)
		if cast.StateInfo.Paused then return end

		PrintDebug("Casting for frame.")
		local latestTrajectory = cast.StateInfo.Trajectories[#cast.StateInfo.Trajectories]
		if (cast.StateInfo.HighFidelityBehavior == 3 and latestTrajectory.Acceleration ~= Vector3.new() and cast.StateInfo.HighFidelitySegmentSize > 0) then

			local timeAtStart = tick()

			if cast.StateInfo.IsActivelyResimulating then
				cast:Terminate()
				error("Cascading cast lag encountered! The caster attempted to perform a high fidelity cast before the previous one completed, resulting in exponential cast lag. Consider increasing HighFidelitySegmentSize.")
			end

			cast.StateInfo.IsActivelyResimulating = true

			local origin = latestTrajectory.Origin
			local totalDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime
			local initialVelocity = latestTrajectory.InitialVelocity
			local acceleration = latestTrajectory.Acceleration

			local lastPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
			local lastVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
			local lastDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime

			cast.StateInfo.TotalRuntime += delta

			totalDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime

			local currentPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
			local currentVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
			local totalDisplacement = currentPoint - lastPoint

			local rayDir = totalDisplacement.Unit * currentVelocity.Magnitude * delta

			local targetWorldRoot = cast.RayInfo.WorldRoot
			local resultOfCast = targetWorldRoot:Blockcast(lastPoint, cast.RayInfo.Size, rayDir, cast.RayInfo.Parameters)

			local point = currentPoint

			if (resultOfCast ~= nil) then
				point = resultOfCast.Position
			end

			local rayDisplacement = (point - lastPoint).Magnitude

			cast.StateInfo.TotalRuntime -= delta

			local numSegmentsDecimal = rayDisplacement / cast.StateInfo.HighFidelitySegmentSize
			local numSegmentsReal = math.floor(numSegmentsDecimal)
			if (numSegmentsReal == 0) then
				numSegmentsReal = 1
			end

			local timeIncrement = delta / numSegmentsReal

			for segmentIndex = 1, numSegmentsReal do
				if getmetatable(cast) == nil then return end
				if cast.StateInfo.CancelHighResCast then
					cast.StateInfo.CancelHighResCast = false
					break
				end
				PrintDebug("[" .. segmentIndex .. "] Subcast of time increment " .. timeIncrement)
				SimulateCast(cast, timeIncrement, true)
			end

			if getmetatable(cast) == nil then return end
			cast.StateInfo.IsActivelyResimulating = false

			if (tick() - timeAtStart) > 0.016 * 5 then
				warn("Extreme cast lag encountered! Consider increasing HighFidelitySegmentSize.")
			end
		else
			SimulateCast(cast, delta, false)
		end
	end

	cast.StateInfo.UpdateConnection = event:ConnectParallel(Stepped)

	return cast
end

-- ... Wow?

local function ModifyTransformation(cast: TypeDef.ActiveBlockCast, velocity: Vector3?, acceleration: Vector3?, position: Vector3?)
	local trajectories = cast.StateInfo.Trajectories
	local lastTrajectory = trajectories[#trajectories]

	if lastTrajectory.StartTime == cast.StateInfo.TotalRuntime then
		if (velocity == nil) then
			velocity = lastTrajectory.InitialVelocity
		end
		if (acceleration == nil) then
			acceleration = lastTrajectory.Acceleration
		end
		if (position == nil) then
			position = lastTrajectory.Origin
		end

		lastTrajectory.Origin = position
		lastTrajectory.InitialVelocity = velocity
		lastTrajectory.Acceleration = acceleration
	else
		lastTrajectory.EndTime = cast.StateInfo.TotalRuntime

		local point, velAtPoint = unpack(GetLatestTrajectoryEndInfo(cast))

		if (velocity == nil) then
			velocity = velAtPoint
		end
		if (acceleration == nil) then
			acceleration = lastTrajectory.Acceleration
		end
		if (position == nil) then
			position = point
		end
		table.insert(cast.StateInfo.Trajectories, {
			StartTime = cast.StateInfo.TotalRuntime,
			EndTime = -1,
			Origin = position,
			InitialVelocity = velocity,
			Acceleration = acceleration
		})
		cast.StateInfo.CancelHighResCast = true
	end
end


-- same as ActiveCast:Terminate()
function ActiveCast:Destroy()
	ActiveCast:Terminate()
end

----> SET

function ActiveCast:SetVelocity(velocity : Vector3)
	assert(
		getmetatable(self) == ActiveCast, 
		ErrorMsgs.ERR_NOT_INSTANCE:format("SetVelocity", "ActiveCast.new(...)")
	)
	assert(
		self.StateInfo.UpdateConnection ~= nil, 
		ErrorMsgs.ERR_OBJECT_DISPOSED
	)
	ModifyTransformation(self, velocity, nil, nil)
end

function ActiveCast:SetAcceleration(acceleration: Vector3)
	assert(
		getmetatable(self) == ActiveCast, 
		ErrorMsgs.ERR_NOT_INSTANCE:format("SetAcceleration", "ActiveCast.new(...)")
	)
	assert(
		self.StateInfo.UpdateConnection ~= nil, 
		ErrorMsgs.ERR_OBJECT_DISPOSED
	)
	ModifyTransformation(self, nil, acceleration, nil)
end

---> GET

function ActiveCast:GetVelocity() : Vector3
	assert(
		getmetatable(self) == ActiveCast, 
		ErrorMsgs.ERR_NOT_INSTANCE:format("GetVelocity", "ActiveCast.new(...)")
	)
	assert(
		self.StateInfo.UpdateConnection ~= nil, 
		ErrorMsgs.ERR_OBJECT_DISPOSED
	)
	local currentTrajectory = self.StateInfo.Trajectories[#self.StateInfo.Trajectories]
	return GetVelocityAtTime(self.StateInfo.TotalRuntime - currentTrajectory.StartTime, currentTrajectory.InitialVelocity, currentTrajectory.Acceleration)
end

function ActiveCast:GetAcceleration(): Vector3
	assert(getmetatable(self) == ActiveCast, 
		ErrorMsgs.ERR_NOT_INSTANCE:format("GetAcceleration", "ActiveCast.new(...)")
	)
	assert(
		self.StateInfo.UpdateConnection ~= nil, 
		ErrorMsgs.ERR_OBJECT_DISPOSED
	)
	local currentTrajectory = self.StateInfo.Trajectories[#self.StateInfo.Trajectories]
	return currentTrajectory.Acceleration
end

function ActiveCast:GetPosition(): Vector3
	assert(
		getmetatable(self) == ActiveCast, 
		ErrorMsgs.ERR_NOT_INSTANCE:format("GetPosition", "ActiveCast.new(...)")
	)
	assert(
		self.StateInfo.UpdateConnection ~= nil, 
		ErrorMsgs.ERR_OBJECT_DISPOSED
	)
	local currentTrajectory = self.StateInfo.Trajectories[#self.StateInfo.Trajectories]
	return GetPositionAtTime(self.StateInfo.TotalRuntime - currentTrajectory.StartTime, currentTrajectory.Origin, currentTrajectory.InitialVelocity, currentTrajectory.Acceleration)
end

---> Add

function ActiveCast:AddVelocity(velocity: Vector3)
	assert(
		getmetatable(self) == ActiveCast, 
		ErrorMsgs.ERR_NOT_INSTANCE:format("AddVelocity", "ActiveCast.new(...)")
	)
	assert(
		self.StateInfo.UpdateConnection ~= nil, 
		ErrorMsgs.ERR_OBJECT_DISPOSED
	)
	self:SetVelocity(self:GetVelocity() + velocity)
end

function ActiveCast:AddAcceleration(acceleration: Vector3)
	assert(
		getmetatable(self) == ActiveCast, 
		ErrorMsgs.ERR_NOT_INSTANCE:format("AddAcceleration", "ActiveCast.new(...)")
	)
	assert(
		self.StateInfo.UpdateConnection ~= nil, 
		ErrorMsgs.ERR_OBJECT_DISPOSED
	)
	self:SetAcceleration(self:GetAcceleration() + acceleration)
end

function ActiveCast:AddPosition(position: Vector3)
	assert(
		getmetatable(self) == ActiveCast, 
		ErrorMsgs.ERR_NOT_INSTANCE:format("AddPosition", "ActiveCast.new(...)")
	)
	assert(
		self.StateInfo.UpdateConnection ~= nil, 
		ErrorMsgs.ERR_OBJECT_DISPOSED
	)
	self:SetPosition(self:GetPosition() + position)
end

---> Others

function ActiveCast:Pause()
	assert(
		getmetatable(self) == ActiveCast, 
		ErrorMsgs.ERR_NOT_INSTANCE:format("Pause", "ActiveCast.new(...)")
	)
	assert(
		self.StateInfo.UpdateConnection ~= nil, 
		ErrorMsgs.ERR_OBJECT_DISPOSED
	)
	self.StateInfo.Paused = true
end

function ActiveCast:Resume()
	assert(
		getmetatable(self) == ActiveCast, 
		ErrorMsgs.ERR_NOT_INSTANCE:format("Resume", "ActiveCast.new(...)")
	)
	assert(
		self.StateInfo.UpdateConnection ~= nil, 
		ErrorMsgs.ERR_OBJECT_DISPOSED
	)
	self.StateInfo.Paused = false
end

function ActiveCast:Terminate()
	assert(
		getmetatable(self) == ActiveCast, 
		ErrorMsgs.ERR_NOT_INSTANCE:format("Terminate", "ActiveCast.new(...)"))
	assert(self.StateInfo.UpdateConnection ~= nil, ErrorMsgs.ERR_OBJECT_DISPOSED

	)

	local trajectories = self.StateInfo.Trajectories
	local lastTrajectory = trajectories[#trajectories]
	lastTrajectory.EndTime = self.StateInfo.TotalRuntime

	self.StateInfo.UpdateConnection:Disconnect()

	--self.CasterBindable:Fire("CastTerminating", self)
	--self.Definition.OnCastTerminating(self)

	self.StateInfo.UpdateConnection = nil

	self.Caster.Output:Fire("CastTerminating", self)
	self.Caster.ActiveCastCleaner:Fire(self.ID)
	
	self.Caster = nil
	self.StateInfo = nil
	self.RayInfo = nil
	self.UserData = nil
	setmetatable(self, nil)
	--print("DELETED ACTIVECAST")
end

return ActiveCast
