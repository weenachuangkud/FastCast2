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
local Configs = require(FastCastModule:WaitForChild("Configs"))
local DebugLogging = Configs.DebugLogging
local FastCastEnums = require(FastCastModule:WaitForChild("FastCastEnums"))

-- Constants

local FC_VIS_OBJ_NAME = "FastCastVisualizationObjects"
local MAX_SEGMENT_CAL_TIME = 0.016 * 5
local MAX_CASTING_TIME = 0.2
local DEFAULT_MAX_DISTANCE = 1000

local EnumCastTypes = FastCastEnums.CastType

local DBG_SEGMENT_SUB_COLOR = Color3.new(0.286275, 0.329412, 0.247059)
local DBG_HIT_SUB_COLOR = Color3.new(0.0588235, 0.87451, 1)
local DBG_RAYPIERCE_SUB_COLOR = Color3.new(1, 0.113725, 0.588235)

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

local function DebrisAdd(obj: Instance, lifetime: number)
	if not obj then
		return
	end
	if lifetime <= 0 then
		obj:Destroy()
		return
	end
	task.delay(lifetime, function()
		obj:Destroy()
	end)
end

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

local function GetFastCastVisualizationContainer(): Instance
	local container = workspace.Terrain:FindFirstChild(FC_VIS_OBJ_NAME)
	if container then
		return container
	end
	container = Instance.new("Folder")
	container.Name = FC_VIS_OBJ_NAME
	container.Archivable = false
	container.Parent = workspace.Terrain
	return container
end

local function DbgVisualizeRaySegment(
	startCF: CFrame,
	visualize: boolean,
	settings: TypeDef.VisualizeCastSettings,
	variant: RayVisualizerVariant
)
	if not visualize then
		return
	end
	local adornment = Instance.new("ConeHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = startCF
	adornment.Height = variant.castLength
	adornment.Color3 = settings.Debug_SegmentColor
	adornment.Radius = settings.Debug_SegmentSize
	adornment.Transparency = settings.Debug_SegmentTransparency
	adornment.Parent = GetFastCastVisualizationContainer()
	DebrisAdd(adornment, settings.Debug_RayLifetime)
end

local function DbgVisualizeBlockSegment(
	startCF: CFrame,
	visualize: boolean,
	settings: TypeDef.VisualizeCastSettings,
	variant: BlockVisualizerVariant
)
	if not visualize then
		return
	end
	local adornment = Instance.new("BoxHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = startCF
	adornment.Size = variant.size
	adornment.Color3 = settings.Debug_SegmentColor
	adornment.Transparency = settings.Debug_SegmentTransparency
	adornment.Parent = GetFastCastVisualizationContainer()
	DebrisAdd(adornment, settings.Debug_RayLifetime)
end

local function DbgVisualizeSphereSegment(
	startCF: CFrame,
	visualize: boolean,
	settings: TypeDef.VisualizeCastSettings,
	variant: SphereVisualizerVariant
)
	if not visualize then
		return
	end
	local adornment = Instance.new("SphereHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = startCF
	adornment.Radius = variant.radius
	adornment.Color3 = settings.Debug_SegmentColor
	adornment.Transparency = settings.Debug_SegmentTransparency
	adornment.Parent = GetFastCastVisualizationContainer()
	DebrisAdd(adornment, settings.Debug_RayLifetime)
end

local function DbgVisualizeHit(
	atCF: CFrame,
	wasPierce: boolean,
	visualize: boolean,
	settings: TypeDef.VisualizeCastSettings
)
	if not visualize then
		return
	end
	local adornment = Instance.new("SphereHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = atCF
	adornment.Radius = wasPierce and settings.Debug_RayPierceSize or settings.Debug_HitSize
	adornment.Transparency = wasPierce and settings.Debug_RayPierceTransparency or settings.Debug_HitTransparency
	adornment.Color3 = wasPierce and settings.Debug_RayPierceColor or settings.Debug_HitColor
	adornment.Parent = GetFastCastVisualizationContainer()
	DebrisAdd(adornment, settings.Debug_HitLifetime)
end

local function QueueEvent(castID: number, eventType: string, ...: any)
	local args = { ... }
	table.insert(queuedEvents[castID], {
		eventType = eventType,
		args = args
	})
end

local function FireQueuedEvents()
	for castID, eventList in queuedEvents do
		if not eventList then 
			return 
		end
		for _, event in eventList do
			local cast = ActivesRef[castID]
			if not cast then 
				continue
			end
			local eventType: string = event.eventType
			local args: { any } = event.args

			if eventType == "LengthChanged" then
				-- handle LengthChanged
			elseif eventType == "Hit" then
				-- handle Hit
			elseif eventType == "Pierced" then
				-- handle Pierced
			elseif eventType == "CastTerminating" then
				FastCast.TerminateCast(cast, args[1])
			end
		end
	end
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
	casts_HighFidelitySegmentSize[id] = cast.Behavior.HighFidelitySegmentSize or 0.1
	casts_HighFidelityBehavior[id] = cast.Behavior.HighFidelityBehavior or 0
	casts_IsActivelySimulatingPierce[id] = false
	casts_IsActivelyResimulating[id] = false
	casts_CancelHighResCast[id] = false
	casts_Trajectory[id] = cast.StateInfo.Trajectory
	casts_VisualizeCasts[id] = cast.Behavior.VisualizeCasts or false
	casts_VisualizeCastSettings[id] = cast.Behavior.VisualizeCastSettings
	casts_FastCastEventsModuleConfig[id] = cast.Behavior.FastCastEventsModuleConfig
	casts_FastCastEventsConfig[id] = cast.Behavior.FastCastEventsConfig
	casts_RayInfo[id] = cast.RayInfo
	casts_UserData[id] = cast.UserData
	casts_CastType[id] = cast.CastType
	casts_CastVariant[id] = cast.CastVariant
	casts_Origin[id] = cast.StateInfo.Trajectory.Origin
	casts_Acceleration[id] = cast.StateInfo.Trajectory.Acceleration
	casts_MaxDistance[id] = cast.Behavior.MaxDistance or DEFAULT_MAX_DISTANCE
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

	table.clear(queuedEvents[castID])
	queuedEvents[castID] = nil
end

function ParallelSimulation.SetMovementMode(mode: "BulkMoveTo" | "Motor6D", enabled: boolean)
	CurrentMovementMode = mode
	MovementEnabled = enabled
end

function ParallelSimulation.GetQueuedEvents()
	local events = queuedEvents
	queuedEvents = {}
	return events
end

function ParallelSimulation.GetActiveMotor6Ds()
	return casts_ActiveMotor6Ds
end

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
local function SimluateCast()
	-- TODO: Implement
end

local function UpdateCasts(delta: number)
	for _, id in casts_ID do
		if casts_Paused[id] then 
			return 
		end

		if DebugLogging.Casting then
			print("Casting for frame.")
		end


		local Trajectory: TypeDef.CastTrajectory = casts_Trajectory[id]
		if typeof(Trajectory.Acceleration) ~= "Vector3" then
			Trajectory.Acceleration = Vector3.new()
		end

		if casts_HighFidelitySegmentSize[id] > 0 then
			casts_HighFidelitySegmentSize = 0.1
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
			end
			-- TODO: Contiune
		end
	end
end

function ParallelSimulation.Start()
	if RS:IsClient() then
		ParallelSimulation.Connection = RS.PreRender:ConnectParallel(UpdateCasts)
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