--!nonstrict

-- Mozilla Public License 2.0 (files originally from FastCast)
--[[
	- Modified by: Mawin CK 
	- Date : 2025
	-- Verison : 0.0.4
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

--[=[
	@class ActiveCast

	An ActiveCast represents a bullet fired by a parent [Caster](Caster). It contains methods of accessing the physics 
	data of this specific bullet at any given time, as well as methods to alter its trajectory during runtime.
]=]

local ActiveCast = {}

ActiveCast.__index = ActiveCast
ActiveCast.__type = "ActiveCast"

-- Local functions

local function SafeCall(f: (...any) -> ...any, ...)
	-- am i tripping
	if f then
		return f(...)
	end
	return nil
end

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

local function ResolveCanPierceCheck(cast: TypeDef.ActiveCast): TypeDef.CanPierceFunction?
	local canPierceModule = cast.RayInfo.CanPierceModule
	if canPierceModule == nil then
		return nil
	end

	local loadedModule = require(canPierceModule)
	if loadedModule == nil then
		return nil
	end

	return loadedModule.Check
end

local function RunCanPierceCheck(
	cast: TypeDef.ActiveCast,
	canPierceCheck: TypeDef.CanPierceFunction?,
	resultOfCast: RaycastResult,
	segmentVelocity: Vector3
): boolean?
	if canPierceCheck == nil then
		return nil
	end

	return SafeCall(canPierceCheck, cast, resultOfCast, segmentVelocity, cast.RayInfo.CosmeticBulletObject)
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

local function GetLatestTrajectoryEndInfo(cast: TypeDef.ActiveCast | TypeDef.ActiveBlockCast): { [number]: Vector3 }
	return GetTrajectoryInfo(cast, #cast.StateInfo.Trajectories)
end

-- Debugging

--[[local function PrintDebug(message : string)
	if Configs.DebugLogging then
		print(message)
	end
end]]

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
	-- Alert! someone is Mawining it!!!!!
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
	cast: TypeDef.ActiveCast,
	resultOfCast: RaycastResult,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
)
	--cast.Caster.RayHit:Fire(cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
	--cast.CasterBindable:Fire("RayHit", cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
	--cast.Definition.OnRayHit(cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
	cast.Caster.Output:Fire("RayHit", cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
end

local function SendRayPierced(
	cast: TypeDef.ActiveCast,
	resultOfCast: RaycastResult,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
)
	--cast.Caster.RayPierced:Fire(cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
	--cast.CasterBindable:Fire("RayPierced", cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
	--cast.Definition.OnRayPierce(ActiveCast, resultOfCast, segmentVelocity, cosmeticBulletObject)
	cast.Caster.Output:Fire("RayPierced", cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
end

local function SendLengthChanged(
	cast: TypeDef.ActiveCast,
	lastPoint: Vector3,
	rayDir: Vector3,
	rayDisplacement: number,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
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

local function SendCastFire(
	cast: TypeDef.ActiveCast,
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: TypeDef.FastCastBehavior
)
	cast.Caster.Output:Fire("CastFire", cast, origin, direction, velocity, behavior)
end

local function SimulateCast(cast: TypeDef.ActiveCast, delta: number, expectingShortCall: boolean)
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")

	--PrintDebug("Casting for frame.")
	--print("1C")
	if DebugLogging.Casting then
		print("Casting for frame.")
	end

	local latestTrajectory = cast.StateInfo.Trajectories[#cast.StateInfo.Trajectories]

	local origin = latestTrajectory.Origin
	local totalDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime
	local initialVelocity = latestTrajectory.InitialVelocity
	local acceleration = latestTrajectory.Acceleration

	local lastPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
	--local lastVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
	local lastDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime

	cast.StateInfo.TotalRuntime += delta

	totalDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime

	local currentTarget = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
	local segmentVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
	local totalDisplacement = currentTarget - lastPoint

	local rayDir = totalDisplacement.Unit * segmentVelocity.Magnitude * delta

	local targetWorldRoot = cast.RayInfo.WorldRoot
	local resultOfCast = targetWorldRoot:Raycast(lastPoint, rayDir, cast.RayInfo.Parameters)

	local point = currentTarget
	local part: Instance? = nil
	local material = Enum.Material.Air
	--local normal = Vector3.new()

	if resultOfCast ~= nil then
		point = resultOfCast.Position
		part = resultOfCast.Instance
		material = resultOfCast.Material
		--normal = resultOfCast.Normal
	end

	local rayDisplacement = (point - lastPoint).Magnitude

	local VisualizeCasts = cast.StateInfo.VisualizeCasts
	local VisualizeCastSettings = cast.StateInfo.VisualizeCastSettings

	if typeof(latestTrajectory.Acceleration) ~= "Vector3" then
		latestTrajectory.Acceleration = Vector3.new()
	end

	cast.CFrame = CFrame.new(lastPoint, lastPoint + rayDir) * CFrame.new(0, 0, -rayDisplacement / 2)

	task.synchronize()

	if cast.StateInfo.UseLengthChanged then
		SendLengthChanged(
			cast,
			lastPoint,
			rayDir.Unit,
			rayDisplacement,
			segmentVelocity,
			cast.RayInfo.CosmeticBulletObject,
			VisualizeCasts
		)
	end
	cast.StateInfo.DistanceCovered += rayDisplacement

	local rayVisualization: ConeHandleAdornment? = nil

	if delta > 0 then
		rayVisualization = DbgVisualizeSegment(
			CFrame.new(lastPoint, lastPoint + rayDir),
			rayDisplacement,
			VisualizeCasts,
			VisualizeCastSettings
		)
	end

	local canPierceCheck = ResolveCanPierceCheck(cast)

	--print("2C")

	-- I feel so gay

	if part and part ~= cast.RayInfo.CosmeticBulletObject then
		local start = tick()
		--PrintDebug("Hit something, testing now.")
		if DebugLogging.Hit then
			print("Hit something, testing now.")
		end

		if canPierceCheck == nil then
			if DebugLogging.RayPierce then
				print("No piercing function set, proceeding to hit processing.")
			end
		end

		if cast.RayInfo.CanPierceCallback ~= nil then
			if expectingShortCall == false and cast.StateInfo.IsActivelySimulatingPierce then
				cast:Terminate()
				warn(
					"WARN: The latest call to CanPierceCallback took too long to complete! This cast is going to suffer desyncs which WILL cause unexpected behavior and errors. Please fix your performance problems, or remove statements that yield (e.g. wait() calls)"
				)
			end
			cast.StateInfo.IsActivelySimulatingPierce = true
		end

		if canPierceCheck == nil or RunCanPierceCheck(cast, canPierceCheck, resultOfCast, segmentVelocity) == false then
			--PrintDebug("Piercing function is nil or it returned FALSE to not pierce this hit.")

			if DebugLogging.RayPierce then
				print("Piercing function is nil or it returned FALSE to not pierce this hit.")
			end

			cast.StateInfo.IsActivelySimulatingPierce = false

			if
				cast.StateInfo.HighFidelityBehavior == FastCastEnums.HighFidelityBehavior.Automatic
				and cast.StateInfo.HighFidelitySegmentSize > 0
			then
				--print("2CR")
				cast.StateInfo.CancelHighResCast = false

				if cast.StateInfo.IsActivelyResimulating then
					cast:Terminate()
					warn(
						"Cascading cast lag encountered! The caster attempted to perform a high fidelity cast before the previous one completed, resulting in exponential cast lag. Consider increasing HighFidelitySegmentSize."
					)
				end

				cast.StateInfo.IsActivelyResimulating = true

				--PrintDebug("Hit was registered, but recalculation is on for physics based casts. Recalculating to verify a real hit...")

				if DebugLogging.Calculation then
					print(
						"Hit was registered, but recalculation is on for physics based casts. Recalculating to verify a real hit..."
					)
				end

				local numSegmentsDecimal = rayDisplacement / cast.StateInfo.HighFidelitySegmentSize
				local numSegmentsReal = math.floor(numSegmentsDecimal)
				--local realSegmentLength = rayDisplacement / numSegmentsReal

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
					if cast.StateInfo.CancelHighResCast then
						cast.StateInfo.CancelHighResCast = false
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
					local subResult = targetWorldRoot:Raycast(subPosition, subRayDir, cast.RayInfo.Parameters)

					local subDisplacement = (subPosition - (subPosition + subVelocity)).Magnitude

					-- What?
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
						or RunCanPierceCheck(cast, canPierceCheck, subResult, subVelocity) == false
					then
							cast.StateInfo.IsActivelyResimulating = false

							SendRayHit(cast, subResult, subVelocity, cast.RayInfo.CosmeticBulletObject)
							cast:Terminate()
							local vis = DbgVisualizeHit(CFrame.new(point), false, VisualizeCasts, VisualizeCastSettings)
							if vis ~= nil then
								vis.Color3 = DBG_HIT_SUB_COLOR
							end

							return
						else
							SendRayPierced(cast, subResult, subVelocity, cast.RayInfo.CosmeticBulletObject)
							local vis = DbgVisualizeHit(CFrame.new(point), true, VisualizeCasts, VisualizeCastSettings)
							if vis ~= nil then
								vis.Color3 = DBG_RAYPIERCE_SUB_COLOR
							end
							--if (dbgSeg ~= nil) then dbgSeg.Color3 = DBG_RAYPIERCE_SEGMENT_COLOR end
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

				cast.StateInfo.IsActivelyResimulating = false
				--elseif (cast.StateInfo.HighFidelityBehavior ~= 1 and cast.StateInfo.HighFidelityBehavior ~= 3) then
				--	cast:Terminate()
				--	error("Invalid value " .. (cast.StateInfo.HighFidelityBehavior) .. " for HighFidelityBehavior.")
			else
				--print("1CR")
				--PrintDebug("Hit was successful. Terminating.")

				if DebugLogging.Hit then
					print("Hit was successful. Terminating.")
				end

				SendRayHit(cast, resultOfCast, segmentVelocity, cast.RayInfo.CosmeticBulletObject)
				cast:Terminate()
				DbgVisualizeHit(CFrame.new(point), false, VisualizeCasts, VisualizeCastSettings)
				return
			end
		else
			--PrintDebug("Piercing function returned TRUE to pierce this part.")

			if DebugLogging.RayPierce then
				print("Piercing function returned TRUE to pierce this part.")
			end

			if rayVisualization ~= nil then
				rayVisualization.Color3 = Color3.new(0.4, 0.05, 0.05)
			end
			DbgVisualizeHit(CFrame.new(point), true, VisualizeCasts, VisualizeCastSettings)

			local params = cast.RayInfo.Parameters
			local alteredParts = {}
			local currentPierceTestCount = 0
			local originalFilter = params.FilterDescendantsInstances
			local brokeFromSolidObject = false
			while true do
				if resultOfCast.Instance:IsA("Terrain") then
					if material == Enum.Material.Water then
						cast:Terminate()
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

				SendRayPierced(cast, resultOfCast, segmentVelocity, cast.RayInfo.CosmeticBulletObject)

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

				if RunCanPierceCheck(cast, canPierceCheck, resultOfCast, segmentVelocity) == false then
					brokeFromSolidObject = true
					break
				end
			end

			cast.RayInfo.Parameters.FilterDescendantsInstances = originalFilter
			cast.StateInfo.IsActivelySimulatingPierce = false

			if brokeFromSolidObject then
				--PrintDebug("Broke because the ray hit something solid (" .. tostring(resultOfCast.Instance) .. ") while testing for a pierce. Terminating the cast.")

				if DebugLogging.Hit then
					print(
						"Broke because the ray hit something solid ("
							.. tostring(resultOfCast.Instance)
							.. ") while testing for a pierce. Terminating the cast."
					)
				end

				SendRayHit(cast, resultOfCast, segmentVelocity, cast.RayInfo.CosmeticBulletObject)
				cast:Terminate()
				DbgVisualizeHit(CFrame.new(resultOfCast.Position), false, VisualizeCasts, VisualizeCastSettings)
				return
			end
		end
	end

	if cast.StateInfo.DistanceCovered >= cast.RayInfo.MaxDistance then
		cast:Terminate()
		DbgVisualizeHit(CFrame.new(currentTarget), false, VisualizeCasts, VisualizeCastSettings)
	end
end

--[=[
	@function new
	@private
	@within ActiveCast

	Creates a new ActiveCast instance with the given parameters.
	Don't use this method! Instead, use [Caster:RaycastFire()](TypeDefinitions#Caster) to create ActiveCasts.

	@param BaseCast TypeDef.BaseCastData -- The base cast data used to initialize the active cast.

	@param activeCastID string -- Unique identifier for this active cast.

	@param origin Vector3 -- The starting position of the cast.

	@param direction Vector3 -- The direction the cast will travel in.

	@param velocity Vector3 | number -- The velocity of the cast (either directional or scalar).

	@param behavior TypeDef.FastCastBehavior -- The FastCast behavior configuration.

	@return ActiveCast -- The newly created ActiveCast instance.
]=]

function ActiveCast.new(
	BaseCast: TypeDef.BaseCastData,
	activeCastID: string,
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: TypeDef.FastCastBehavior,
	canpierce: TypeDef.CanPierceModule?
): TypeDef.ActiveCast
	if typeof(velocity) == "number" then
		velocity = direction.Unit * velocity
	end

	if behavior.HighFidelitySegmentSize <= 0 then
		error("Cannot set FastCastBehavior.HighFidelitySegmentSize <= 0!", 0)
	end

	-- This world is cruel, and I must accept it.
	if behavior.HighFidelityBehavior <= 0 then
		behavior.HighFidelityBehavior = 1
	elseif behavior.HighFidelityBehavior >= 4 then
		behavior.HighFidelityBehavior = 3
	end

	local cast: TypeDefinitions.ActiveCast = {
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
					Acceleration = behavior.Acceleration,
				},
			},
			UseLengthChanged = behavior.UseLengthChanged,
			VisualizeCasts = behavior.VisualizeCasts,
			VisualizeCastSettings = behavior.VisualizeCastSettings,
		},

		RayInfo = {
			Parameters = behavior.RaycastParams,
			WorldRoot = workspace,
			MaxDistance = behavior.MaxDistance or DEFAULT_MAX_DISTANCE,
			CosmeticBulletObject = behavior.CosmeticBulletTemplate,
			CanPierceModule = canpierce,
		},

		UserData = {},

		CFrame = CFrame.new(),
		ID = activeCastID,
	} :: any

	--[[if cast.StateInfo.HighFidelityBehavior == 2 then
		cast.StateInfo.HighFidelityBehavior = 3
	end]]

	if cast.RayInfo.Parameters ~= nil then
		cast.RayInfo.Parameters = CloneCastParams(cast.RayInfo.Parameters)
	else
		cast.RayInfo.Parameters = RaycastParams.new()
	end

	-- CosmeticBulletObject GET

	local targetContainer: Instance
	if cast.Caster.ObjectCache then
		if cast.RayInfo.CosmeticBulletObject ~= nil then
			warn("ObjectCache already handle that for you, Template Dupe")
		end
		-- 1 kebab please
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
		end
	end

	-- the rest? :P

	if behavior.AutoIgnoreContainer == true and targetContainer ~= nil then
		local igroneList = cast.RayInfo.Parameters.FilterDescendantsInstances
		if not table.find(igroneList, targetContainer) then
			table.insert(igroneList, targetContainer)
			cast.RayInfo.Parameters.FilterDescendantsInstances = igroneList
		end
	end

	SendCastFire(cast, origin, direction, velocity, behavior)

	local event
	if RS:IsClient() then
		event = behavior.SimulateAfterPhysic and RS.Heartbeat or RS.PostSimulation
	else
		event = RS.Heartbeat
	end

	setmetatable(cast, ActiveCast)

	local function Stepped(delta: number)
		if cast.StateInfo.Paused then
			return
		end

		--PrintDebug("Casting for frame.")

		if DebugLogging.Casting then
			print("Casting for frame.")
		end

		local Cast_timeAtStart = tick()

		local latestTrajectory = cast.StateInfo.Trajectories[#cast.StateInfo.Trajectories]

		if typeof(latestTrajectory.Acceleration) ~= "Vector3" then
			latestTrajectory.Acceleration = Vector3.new()
		end

		if
			cast.StateInfo.HighFidelityBehavior == FastCastEnums.HighFidelityBehavior.Always
			and cast.StateInfo.HighFidelitySegmentSize > 0
		then
			local Segment_timeAtStart = tick()

			if cast.StateInfo.IsActivelyResimulating then
				cast:Terminate()
				warn(
					"Cascading cast lag encountered! The caster attempted to perform a high fidelity cast before the previous one completed, resulting in exponential cast lag. Consider increasing HighFidelitySegmentSize."
				)
			end

			cast.StateInfo.IsActivelyResimulating = true

			local origin = latestTrajectory.Origin
			local totalDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime
			local initialVelocity = latestTrajectory.InitialVelocity
			local acceleration = latestTrajectory.Acceleration

			local lastPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
			--local lastVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
			--local lastDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime

			cast.StateInfo.TotalRuntime += delta

			totalDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime

			local currentPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
			local currentVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
			local totalDisplacement = currentPoint - lastPoint

			local rayDir = totalDisplacement.Unit * currentVelocity.Magnitude * delta

			local targetWorldRoot = cast.RayInfo.WorldRoot
			local resultOfCast = targetWorldRoot:Raycast(lastPoint, rayDir, cast.RayInfo.Parameters)

			local point = currentPoint

			if resultOfCast ~= nil then
				point = resultOfCast.Position
			end

			local rayDisplacement = (point - lastPoint).Magnitude

			cast.StateInfo.TotalRuntime -= delta

			local numSegmentsDecimal = rayDisplacement / cast.StateInfo.HighFidelitySegmentSize
			local numSegmentsReal = math.floor(numSegmentsDecimal)
			if numSegmentsReal == 0 then
				numSegmentsReal = 1
			end

			local timeIncrement = delta / numSegmentsReal

			if DebugLogging.Calculation then
				print("Performing subcast! Time increment: " .. timeIncrement .. ", num segments: " .. numSegmentsReal)
			end

			for segmentIndex = 1, numSegmentsReal do
				if getmetatable(cast) == nil then
					return
				end
				if cast.StateInfo.CancelHighResCast then
					cast.StateInfo.CancelHighResCast = false
					break
				end

				if DebugLogging.Segment then
					print("[" .. segmentIndex .. "] Subcast of time increment " .. timeIncrement)
				end

				--PrintDebug("[" .. segmentIndex .. "] Subcast of time increment " .. timeIncrement)
				SimulateCast(cast, timeIncrement, true)
			end

			if getmetatable(cast) == nil then
				return
			end
			cast.StateInfo.IsActivelyResimulating = false

			if behavior.AutomaticPerformance and (tick() - Segment_timeAtStart) > MAX_SEGMENT_CAL_TIME then
				local HighFideSizeAmount = behavior.AdaptivePerformance.HighFidelitySegmentSizeIncrease
					or HIGH_FIDE_INCREASE_SIZE

				if DebugLogging.AutomaticPerformance then
					warn("AutomaticPerformance increasing size of HighFidelitySize by : ", HighFideSizeAmount)
				end

				cast.StateInfo.HighFidelitySegmentSize += HighFideSizeAmount
			end
		else
			SimulateCast(cast, delta, false)
		end

		if
			behavior.AutomaticPerformance
			and behavior.AdaptivePerformance.LowerHighFidelityBehavior
			and (tick() - Cast_timeAtStart) > MAX_CASTING_TIME
		then
			if cast.StateInfo.HighFidelityBehavior > 1 then
				cast.StateInfo.HighFidelityBehavior -= 1
			end
		end
	end

	cast.StateInfo.UpdateConnection = event:ConnectParallel(Stepped)

	return cast
end

-- ... Wow?

local function ModifyTransformation(
	cast: TypeDef.ActiveCast,
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

Destroys an ActiveCast, terminating it's simulation, firing the CastTerminating event, and cleaning up resources. 
This is the equivilant of calling `ActiveCast:Terminate()`.

@method Destroy
@within ActiveCast

]=]
function ActiveCast:Destroy()
	ActiveCast:Terminate()
end

--[=[

Sets the velocity of an ActiveCast to the specified Vector3.

@method SetVelocity
@param velocity Vector3 -- The new velocity to set.
@within ActiveCast

]=]
function ActiveCast:SetVelocity(velocity: Vector3)
	assert(getmetatable(self) == ActiveCast, "ERR_NOT_INSTANCE")
	assert(self.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	ModifyTransformation(self, velocity, nil, nil)
end

--[=[

Sets the acceleration of an ActiveCast to the specified Vector3.

@method SetAcceleration
@param acceleration Vector3 -- The new acceleration to set.
@within ActiveCast

]=]
function ActiveCast:SetAcceleration(acceleration: Vector3)
	assert(getmetatable(self) == ActiveCast, "ERR_NOT_INSTANCE")
	assert(self.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	ModifyTransformation(self, nil, acceleration, nil)
end

--[=[

Gets the velocity of an ActiveCast.

@method GetVelocity
@within ActiveCast
@return Vector3 -- The current velocity of the ActiveCast.
]=]
function ActiveCast:GetVelocity(): Vector3
	assert(getmetatable(self) == ActiveCast, "ERR_NOT_INSTANCE")
	assert(self.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	local currentTrajectory = self.StateInfo.Trajectories[#self.StateInfo.Trajectories]
	return GetVelocityAtTime(
		self.StateInfo.TotalRuntime - currentTrajectory.StartTime,
		currentTrajectory.InitialVelocity,
		currentTrajectory.Acceleration
	)
end

--[=[

Gets the acceleration of an ActiveCast.

@method GetAcceleration
@within ActiveCast
@return Vector3 -- The current acceleration of the ActiveCast.

]=]
function ActiveCast:GetAcceleration(): Vector3
	assert(getmetatable(self) == ActiveCast, "ERR_NOT_INSTANCE")
	assert(self.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	local currentTrajectory = self.StateInfo.Trajectories[#self.StateInfo.Trajectories]
	return currentTrajectory.Acceleration
end

--[=[

Gets the position of an ActiveCast.

@method GetPosition
@within ActiveCast
@return Vector3 -- The current position of the ActiveCast.
]=]
function ActiveCast:GetPosition(): Vector3
	assert(getmetatable(self) == ActiveCast, "ERR_NOT_INSTANCE")
	assert(self.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	local currentTrajectory = self.StateInfo.Trajectories[#self.StateInfo.Trajectories]
	return GetPositionAtTime(
		self.StateInfo.TotalRuntime - currentTrajectory.StartTime,
		currentTrajectory.Origin,
		currentTrajectory.InitialVelocity,
		currentTrajectory.Acceleration
	)
end

--[=[

Add velocity to an ActiveCast with the specified Vector3.

@method AddVelocity
@param velocity Vector3 -- The new velocity to add.
@within ActiveCast

]=]
function ActiveCast:AddVelocity(velocity: Vector3)
	assert(getmetatable(self) == ActiveCast, "ERR_NOT_INSTANCE")
	assert(self.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	self:SetVelocity(self:GetVelocity() + velocity)
end

--[=[

Add acceleration to an ActiveCast with the specified Vector3.

@method AddAcceleration
@param acceleration Vector3 -- The new acceleration to add.
@within ActiveCast

]=]
function ActiveCast:AddAcceleration(acceleration: Vector3)
	assert(getmetatable(self) == ActiveCast, "ERR_NOT_INSTANCE")
	assert(self.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	self:SetAcceleration(self:GetAcceleration() + acceleration)
end

--[=[

Add position to an ActiveCast with the specified Vector3.

@method AddPosition
@param position Vector3 -- The new position to add.
@within ActiveCast

]=]
function ActiveCast:AddPosition(position: Vector3)
	assert(getmetatable(self) == ActiveCast, "ERR_NOT_INSTANCE")
	assert(self.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	self:SetPosition(self:GetPosition() + position)
end

--[=[

Pauses simulation for an ActiveCast.

@method Pause
@within ActiveCast

]=]
function ActiveCast:Pause()
	assert(getmetatable(self) == ActiveCast, "ERR_NOT_INSTANCE")
	assert(self.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	self.StateInfo.Paused = true
end

--[=[

Resumes simulation for an ActiveCast if it was paused previously.

@method Resume
@within ActiveCast

]=]
function ActiveCast:Resume()
	assert(getmetatable(self) == ActiveCast, "ERR_NOT_INSTANCE")
	assert(self.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")
	self.StateInfo.Paused = false
end

--[=[

Terminates an ActiveCast, firing the CastTerminating event, and cleaning up resources. 
This is the equivilant of calling `Active:Destroy()`.

@method Resume
@within ActiveCast

]=]
function ActiveCast:Terminate()
	assert(getmetatable(self) == ActiveCast, "ERR_NOT_INSTANCE")
	assert(self.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED"
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
