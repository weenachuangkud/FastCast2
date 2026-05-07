-- Mozilla Public License 2.0
--[[
	- Author : Mawin CK
	- Date : 2025
	-- Version : 0.0.9
]]

local RS = game:GetService("RunService")

local FastCastModule = script.Parent
local FastCast = require(FastCastModule)
local TypeDef = require(FastCastModule:WaitForChild("TypeDefinitions"))
local Configs = require(FastCastModule:WaitForChild("Configs"))
local DebugLogging = Configs.DebugLogging
local FastCastEnums = require(FastCastModule:WaitForChild("FastCastEnums"))
local SerialSimulation = require(FastCastModule:WaitForChild("SerialSimulation"))

local FC_VIS_OBJ_NAME = "FastCastVisualizationObjects"
local MAX_SEGMENT_CAL_TIME = 0.016 * 5
local MAX_CASTING_TIME = 0.2
local DEFAULT_MAX_DISTANCE = 1000

local EnumCastTypes = FastCastEnums.CastType

-- Shared simulation for all serial casts
local SharedSimulation = SerialSimulation.new()
SharedSimulation:Start()

local DBG_SEGMENT_SUB_COLOR = Color3.new(0.286275, 0.329412, 0.247059)
local DBG_SEGMENT_SUB_COLOR2 = Color3.new(0.454902, 0.933333, 0.011765)
local DBG_HIT_SUB_COLOR = Color3.new(0.0588235, 0.87451, 1)
local DBG_RAYPIERCE_SUB_COLOR = Color3.new(1, 0.113725, 0.588235)

type vaildcast = TypeDef.ActiveCastData | TypeDef.ActiveBlockcastData | TypeDef.ActiveSpherecastData

type BlockcastVariant = { CastType: number, Size: Vector3 }
type SpherecastVariant = { CastType: number, Radius: number }
type CastVariants = BlockcastVariant | SpherecastVariant

type RayVisualizerVariant = { castLength: number }
type BlockVisualizerVariant = { size: Vector3 }
type SphereVisualizerVariant = { radius: number }
type CastVisualizerVariants = RayVisualizerVariant | BlockVisualizerVariant | SphereVisualizerVariant

type CastHandler = (WorldRoot: WorldRoot, origin: Vector3, direction: Vector3, castVariant: CastVariants) -> RaycastResult

local HIGH_FIDE_INCREASE_SIZE = 0.5

local CastVariantTypes = {
	[EnumCastTypes.Raycast] = "Raycast",
	[EnumCastTypes.Blockcast] = "Blockcast",
	[EnumCastTypes.Spherecast] = "Spherecast"
}

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
		variant: BlockcastVariant
	)
		return targetWorldRoot:Blockcast(CFrame.new(origin), variant.Size, direction, parameters)
	end,
	[EnumCastTypes.Spherecast] = function(
		targetWorldRoot: WorldRoot,
		origin: Vector3,
		direction: Vector3,
		parameters: RaycastParams,
		variant: SpherecastVariant
	)
		return targetWorldRoot:Spherecast(origin, variant.Radius, direction, parameters)
	end
}

--[=[
	@class ActiveCastSerial

	ActiveCast for serial (non-parallel) mode. Runs simulation directly on main thread.
]=]

local ActiveCastSerial = {}

local function DebrisAdd(obj: Instance, Lifetime: number)
	if not obj then return end
	if Lifetime <= 0 then
		obj:Destroy()
	end
	task.delay(Lifetime, function()
		obj:Destroy()
	end)
end

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

local function CloneCastParams(params: RaycastParams): RaycastParams
	local clone: RaycastParams = RaycastParams.new()
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

local function DbgVisualizeRaySegment(
	castStartCFrame: CFrame,
	VisualizeCasts: boolean,
	VisualizeCastSettings: TypeDef.VisualizeCastSettings,
	variant: RayVisualizerVariant
): ConeHandleAdornment?
	if not VisualizeCasts then return end
	local adornment = Instance.new("ConeHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = castStartCFrame
	adornment.Height = variant.castLength
	adornment.Color3 = VisualizeCastSettings.Debug_SegmentColor
	adornment.Radius = VisualizeCastSettings.Debug_SegmentSize
	adornment.Transparency = VisualizeCastSettings.Debug_SegmentTransparency
	adornment.Parent = GetFastCastVisualizationContainer()
	DebrisAdd(adornment, VisualizeCastSettings.Debug_RayLifetime)
	return adornment
end

local function DbgVisualizeBlockSegment(
	castStartCFrame: CFrame,
	VisualizeCasts: boolean,
	VisualizeCastSettings: TypeDef.VisualizeCastSettings,
	variant: BlockVisualizerVariant
): BoxHandleAdornment?
	if not VisualizeCasts then return end
	local adornment = Instance.new("BoxHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = castStartCFrame
	adornment.Size = variant.size
	adornment.Color3 = VisualizeCastSettings.Debug_SegmentColor
	adornment.Transparency = VisualizeCastSettings.Debug_SegmentTransparency
	adornment.Parent = GetFastCastVisualizationContainer()
	DebrisAdd(adornment, VisualizeCastSettings.Debug_RayLifetime)
	return adornment
end

local function DbgVisualizeSphereSegment(
	castStartCFrame: CFrame,
	VisualizeCasts: boolean,
	VisualizeCastSettings: TypeDef.VisualizeCastSettings,
	variant: SphereVisualizerVariant
): SphereHandleAdornment?
	if not VisualizeCasts then return end
	local adornment = Instance.new("SphereHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = castStartCFrame
	adornment.Radius = variant.radius
	adornment.Color3 = VisualizeCastSettings.Debug_SegmentColor
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
	if not VisualizeCasts then return end
	local adornment = Instance.new("SphereHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = atCF
	adornment.Radius = (wasPierce == false) and VisualizeCastSettings.Debug_HitSize or VisualizeCastSettings.Debug_RayPierceSize
	adornment.Transparency = (wasPierce == false) and VisualizeCastSettings.Debug_HitTransparency or VisualizeCastSettings.Debug_RayPierceTransparency
	adornment.Color3 = (wasPierce == false) and VisualizeCastSettings.Debug_HitColor or VisualizeCastSettings.Debug_RayPierceColor
	adornment.Parent = GetFastCastVisualizationContainer()
	DebrisAdd(adornment, VisualizeCastSettings.Debug_HitLifetime)
	return adornment
end

local Visualizers = {
	[EnumCastTypes.Raycast] = DbgVisualizeRaySegment,
	[EnumCastTypes.Blockcast] = DbgVisualizeBlockSegment,
	[EnumCastTypes.Spherecast] = DbgVisualizeSphereSegment
}

local function SendHit(
	cast: vaildcast,
	resultOfCast: RaycastResult,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
)
	local FastCastEventsConfig = cast.StateInfo.FastCastEventsConfig
	if FastCastEventsConfig and FastCastEventsConfig.UseHit == false then return end
	cast.Caster.Output:Fire("Hit", cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
end

local function SendPierced(
	cast: vaildcast,
	resultOfCast: RaycastResult,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
)
	local FastCastEventsConfig = cast.StateInfo.FastCastEventsConfig
	if FastCastEventsConfig and FastCastEventsConfig.UsePierced == false then return end
	cast.Caster.Output:Fire("Pierced", cast, resultOfCast, segmentVelocity, cosmeticBulletObject)
end

local function SendLengthChanged(
	cast: vaildcast,
	lastPoint: Vector3,
	rayDir: Vector3,
	rayDisplacement: number,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
)
	local FastCastEventsConfig = cast.StateInfo.FastCastEventsConfig
	if FastCastEventsConfig and FastCastEventsConfig.UseLengthChanged == false then return end
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
	cast: any,
	delta: number,
	FastCastEvents: TypeDef.FastCastEvents,
	variant: CastVariants
)
	assert(cast.StateInfo.UpdateConnection ~= nil, "ERR_OBJECT_DISPOSED")

	if DebugLogging.Casting then
		print("Casting for frame.")
	end

	local latestTrajectory = cast.StateInfo.Trajectories[#cast.StateInfo.Trajectories]
	local origin = latestTrajectory.Origin
	local totalDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime
	local initialVelocity = latestTrajectory.InitialVelocity
	local acceleration = latestTrajectory.Acceleration

	local lastPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
	local lastDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime

	cast.StateInfo.TotalRuntime += delta
	totalDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime

	local currentTarget = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
	local segmentVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
	local totalDisplacement = currentTarget - lastPoint
	local rayDir = totalDisplacement.Unit * segmentVelocity.Magnitude * delta

	local CastType = variant.CastType
	local targetWorldRoot = cast.RayInfo.WorldRoot

	local CastHandler = castHandlers[CastType]
	local Visualizer = Visualizers[CastType]

	local resultOfCast = CastHandler(targetWorldRoot, lastPoint, rayDir, cast.RayInfo.Parameters, variant)

	local point = currentTarget
	local part: Instance? = nil

	if resultOfCast ~= nil then
		point = resultOfCast.Position
		part = resultOfCast.Instance
	end

	local rayDisplacement = (point - lastPoint).Magnitude

	local VisualizeCasts = cast.StateInfo.VisualizeCasts
	local VisualizeCastSettings = cast.StateInfo.VisualizeCastSettings
	local FastCastEventsModuleConfig = cast.StateInfo.FastCastEventsModuleConfig

	if typeof(latestTrajectory.Acceleration) ~= "Vector3" then
		latestTrajectory.Acceleration = Vector3.new()
	end

	local VisualizeVariant = {}
	if CastType == EnumCastTypes.Raycast then
		VisualizeVariant.castLength = rayDisplacement
	elseif CastType == EnumCastTypes.Blockcast then
		VisualizeVariant.size = cast.RayInfo.Size
	elseif CastType == EnumCastTypes.Spherecast then
		VisualizeVariant.radius = cast.RayInfo.Radius
	end

	cast.CFrame = CFrame.new(lastPoint, lastPoint + rayDir) * CFrame.new(0, 0, -rayDisplacement / 2)

	local LengthChangedfn: TypeDef.OnLengthChangedFunction? = nil
	local canPierceCheckfn: TypeDef.CanPierceFunction? = nil
	local castTerminatingfn: TypeDef.OnCastTerminatingFunction? = nil
	local Hitfn: TypeDef.OnHitFunction? = nil
	local Piercedfn: TypeDef.OnPiercedFunction? = nil

	if FastCastEvents then
		canPierceCheckfn = FastCastEventsModuleConfig.UseCanPierce and FastCastEvents.CanPierce or nil
		castTerminatingfn = FastCastEventsModuleConfig.UseCastTerminating and FastCastEvents.CastTerminating or nil
		Hitfn = FastCastEventsModuleConfig.UseHit and FastCastEvents.Hit or nil
		Piercedfn = FastCastEventsModuleConfig.UsePierced and FastCastEvents.Pierced or nil
		LengthChangedfn = FastCastEventsModuleConfig.UseLengthChanged and FastCastEvents.LengthChanged or nil
	end

	SendLengthChanged(cast, lastPoint, rayDir.Unit, rayDisplacement, segmentVelocity, cast.RayInfo.CosmeticBulletObject)

	if LengthChangedfn then
		LengthChangedfn(
			cast,
			lastPoint,
			rayDir.Unit,
			rayDisplacement,
			segmentVelocity,
			cast.RayInfo.CosmeticBulletObject
		)
	end

	cast.StateInfo.DistanceCovered += rayDisplacement

	local rayVisualization = nil
	if delta > 0 then
		rayVisualization = Visualizer(
			CFrame.new(lastPoint, lastPoint + rayDir),
			VisualizeCasts,
			VisualizeCastSettings,
			VisualizeVariant
		)
	end

	if part and part ~= cast.RayInfo.CosmeticBulletObject then
		if DebugLogging.Hit then
			print("Hit something, testing now.")
		end

		if DebugLogging.RayPierce and canPierceCheckfn == nil then
			print("No piercing function set, proceeding to hit processing.")
		end

		if
			canPierceCheckfn == nil
			or canPierceCheckfn(cast, resultOfCast, segmentVelocity, cast.RayInfo.CosmeticBulletObject) == false
		then
			if DebugLogging.RayPierce then
				print("Piercing function is nil or it returned FALSE to not pierce this hit.")
			end

			cast.StateInfo.IsActivelySimulatingPierce = false

			if
				cast.StateInfo.HighFidelityBehavior == FastCastEnums.HighFidelityBehavior.Automatic
				and cast.StateInfo.HighFidelitySegmentSize > 0
			then
				cast.StateInfo.CancelHighResCast = false

				if cast.StateInfo.IsActivelyResimulating then
					FastCast:TerminateCast(cast, castTerminatingfn)
					warn("Cascading cast lag encountered!")
					return
				end

				cast.StateInfo.IsActivelyResimulating = true

				if DebugLogging.Calculation then
					print("Hit was registered, but recalculation is on for physics based casts. Recalculating to verify a real hit...")
				end

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
					local subVelocity = GetVelocityAtTime(lastDelta + (timeIncrement * segmentIndex), initialVelocity, acceleration)
					local subRayDir = subVelocity * delta
					local subResult = CastHandler(targetWorldRoot, subPosition, subRayDir, cast.RayInfo.Parameters, variant)

					local subDisplacement = (subPosition - (subPosition + subVelocity)).Magnitude

					if CastType == EnumCastTypes.Raycast then
						VisualizeVariant.castLength = subDisplacement
					end

					if subResult ~= nil then
						subDisplacement = (subPosition - subResult.Position).Magnitude
						local dbgSeg = Visualizer(
							CFrame.new(subPosition, subPosition + subVelocity),
							VisualizeCasts,
							VisualizeCastSettings,
							VisualizeVariant
						)
						if dbgSeg ~= nil then
							dbgSeg.Color3 = DBG_SEGMENT_SUB_COLOR
						end

						if
							canPierceCheckfn == nil
							or canPierceCheckfn(cast, subResult, subVelocity, cast.RayInfo.CosmeticBulletObject) == false
						then
							cast.StateInfo.IsActivelyResimulating = false
							SendHit(cast, subResult, subVelocity, cast.RayInfo.CosmeticBulletObject)
							if Hitfn then
								Hitfn(cast, subResult, subVelocity, cast.RayInfo.CosmeticBulletObject)
							end
cast.Caster:TerminateCast(cast, castTerminatingfn)

							local vis = DbgVisualizeHit(CFrame.new(point), false, VisualizeCasts, VisualizeCastSettings)
							if vis ~= nil then
								vis.Color3 = DBG_HIT_SUB_COLOR
							end
							return
						else
							SendPierced(cast, subResult, subVelocity, cast.RayInfo.CosmeticBulletObject)
							if Piercedfn then
								Piercedfn(cast, subResult, subVelocity, cast.RayInfo.CosmeticBulletObject)
							end

							local vis = DbgVisualizeHit(CFrame.new(point), true, VisualizeCasts, VisualizeCastSettings)
							if vis ~= nil then
								vis.Color3 = DBG_RAYPIERCE_SUB_COLOR
							end
						end
					else
						local dbgSeg = Visualizer(
							CFrame.new(subPosition, subPosition + subVelocity),
							VisualizeCasts,
							VisualizeCastSettings,
							VisualizeVariant
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
			else
				if DebugLogging.Hit then
					print("Hit was successful. Terminating.")
				end

				SendHit(cast, resultOfCast, segmentVelocity, cast.RayInfo.CosmeticBulletObject)
				if Hitfn then
					Hitfn(cast, resultOfCast, segmentVelocity, cast.RayInfo.CosmeticBulletObject)
				end
				FastCast:TerminateCast(cast, castTerminatingfn)

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
			SendPierced(cast, resultOfCast, segmentVelocity, cast.RayInfo.CosmeticBulletObject)
			if Piercedfn then
				Piercedfn(cast, resultOfCast, segmentVelocity, cast.RayInfo.CosmeticBulletObject)
			end
		end
	end

	if cast.StateInfo.DistanceCovered >= cast.RayInfo.MaxDistance then
		FastCast:TerminateCast(cast, castTerminatingfn)
		DbgVisualizeHit(CFrame.new(currentTarget), false, VisualizeCasts, VisualizeCastSettings)
	end
end

--[=[
	@function createCastData
	@within ActiveCastSerial

	Creates a new ActiveCastSerial instance.
]=]
function ActiveCastSerial.createCastData(
	BaseCast: TypeDef.BaseCastData,
	activeCastID: number,
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: TypeDef.FastCastBehavior,
	eventModule: TypeDef.FastCastEventsModule?,
	variant: CastVariants
): vaildcast
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

	local cast = {
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
			VisualizeCasts = behavior.VisualizeCasts,
			VisualizeCastSettings = behavior.VisualizeCastSettings,
			FastCastEventsModuleConfig = {
				UseLengthChanged = behavior.FastCastEventsModuleConfig.UseLengthChanged,
				UseHit = behavior.FastCastEventsModuleConfig.UseHit,
				UsePierced = behavior.FastCastEventsModuleConfig.UsePierced,
				UseCastTerminating = behavior.FastCastEventsModuleConfig.UseCastTerminating,
				UseCanPierce = behavior.FastCastEventsModuleConfig.UseCanPierce,
			},
			FastCastEventsConfig = {
				UseLengthChanged = behavior.FastCastEventsConfig.UseLengthChanged,
				UseHit = behavior.FastCastEventsConfig.UseHit,
				UsePierced = behavior.FastCastEventsConfig.UsePierced,
				UseCastTerminating = behavior.FastCastEventsConfig.UseCastTerminating,
			},
		},
		RayInfo = {
			Parameters = behavior.RaycastParams,
			WorldRoot = workspace,
			MaxDistance = behavior.MaxDistance or DEFAULT_MAX_DISTANCE,
			CosmeticBulletObject = behavior.CosmeticBulletTemplate,
			FastCastEventsModule = eventModule
		},
		UserData = {},
		Type = CastVariantTypes[variant.CastType],
		CFrame = CFrame.new(origin) :: CFrame,
		ID = activeCastID
	} :: any

	if variant.CastType == EnumCastTypes.Blockcast then
		cast.RayInfo.Size = (variant :: BlockcastVariant).Size
	elseif variant.CastType == EnumCastTypes.Spherecast then
		cast.RayInfo.Radius = (variant :: SpherecastVariant).Radius
	end

	if behavior.UserData then
		cast.UserData = behavior.UserData
	end

	if cast.RayInfo.Parameters ~= nil then
		cast.RayInfo.Parameters = CloneCastParams(cast.RayInfo.Parameters)
	else
		cast.RayInfo.Parameters = RaycastParams.new()
	end

	local targetContainer: Instance?
	if cast.Caster.ObjectCache then
		cast.RayInfo.CosmeticBulletObject = cast.Caster.ObjectCache:Invoke(CFrame.new(origin, origin + direction))
		targetContainer = cast.Caster.CacheHolder
	else
		if cast.RayInfo.CosmeticBulletObject ~= nil then
			local basePart = cast.RayInfo.CosmeticBulletObject
			basePart = basePart:Clone()
			basePart.CFrame = CFrame.new(origin, origin + direction)
			basePart.Parent = behavior.CosmeticBulletContainer
			cast.RayInfo.CosmeticBulletObject = basePart
		end

		if behavior.CosmeticBulletContainer then
			targetContainer = behavior.CosmeticBulletContainer
		end
	end

	if behavior.AutoIgnoreContainer == true and targetContainer ~= nil then
		local ignoreList = cast.RayInfo.Parameters.FilterDescendantsInstances
		if not table.find(ignoreList, targetContainer) then
			table.insert(ignoreList, targetContainer)
			cast.RayInfo.Parameters.FilterDescendantsInstances = ignoreList
		end
	end

	local event = RS.Heartbeat

	local FastCastEvents: TypeDef.FastCastEvents = eventModule and require(eventModule) or nil

	local function Stepped(delta: number)
		if cast.StateInfo.Paused then return end

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

			local castTerminatingfn: TypeDef.OnCastTerminatingFunction? = nil
			if FastCastEvents then
				castTerminatingfn = cast.StateInfo.FastCastEventsModuleConfig.UseCastTerminating
					and FastCastEvents.CastTerminating
					or nil
			end
			if cast.StateInfo.IsActivelyResimulating then
				FastCast:TerminateCast(cast, castTerminatingfn)
				warn("Cascading cast lag encountered!")
				return
			end

			cast.StateInfo.IsActivelyResimulating = true

			local origin = latestTrajectory.Origin
			local totalDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime
			local initialVelocity = latestTrajectory.InitialVelocity
			local acceleration = latestTrajectory.Acceleration

			local lastPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
			cast.StateInfo.TotalRuntime += delta
			totalDelta = cast.StateInfo.TotalRuntime - latestTrajectory.StartTime

			local currentPoint = GetPositionAtTime(totalDelta, origin, initialVelocity, acceleration)
			local currentVelocity = GetVelocityAtTime(totalDelta, initialVelocity, acceleration)
			local totalDisplacement = currentPoint - lastPoint

			local rayDir = totalDisplacement.Unit * currentVelocity.Magnitude * delta

			local targetWorldRoot = cast.RayInfo.WorldRoot
			local CastHandler = castHandlers[variant.CastType]

			local resultOfCast = CastHandler(targetWorldRoot, lastPoint, rayDir, cast.RayInfo.Parameters, variant)

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
				if next(cast) == nil then return end
				if cast.StateInfo.CancelHighResCast then
					cast.StateInfo.CancelHighResCast = false
					break
				end

				if DebugLogging.Segment then
					print("[" .. segmentIndex .. "] Subcast of time increment " .. timeIncrement)
				end

				SimulateCast(cast, timeIncrement, FastCastEvents, variant)
			end

			if next(cast) == nil then return end
			cast.StateInfo.IsActivelyResimulating = false

			if
				behavior.AutomaticPerformance
				and (tick() - Segment_timeAtStart) > MAX_SEGMENT_CAL_TIME
				and cast.StateInfo
			then
				local HighFideSizeAmount = behavior.AdaptivePerformance.HighFidelitySegmentSizeIncrease or HIGH_FIDE_INCREASE_SIZE
				if DebugLogging.AutomaticPerformance then
					warn("AutomaticPerformance increasing size of HighFidelitySize by: ", HighFideSizeAmount)
				end
				cast.StateInfo.HighFidelitySegmentSize += HighFideSizeAmount
			end
		else
			SimulateCast(cast, delta, FastCastEvents, variant)
		end

		if
			behavior.AutomaticPerformance
			and behavior.AdaptivePerformance.LowerHighFidelityBehavior
			and (tick() - Cast_timeAtStart) > MAX_CASTING_TIME
			and cast.StateInfo
		then
			if cast.StateInfo.HighFidelityBehavior > 1 then
				cast.StateInfo.HighFidelityBehavior -= 1
			end
		end
	end

	cast.StateInfo.UpdateConnection = event:Connect(Stepped)

	return cast
end

return ActiveCastSerial