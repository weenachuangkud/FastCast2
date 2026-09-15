--[[
	- Author: Mawin CK
	- Date: 2026
]]

--!native
--!optimize 2

local RS = game:GetService("RunService")

local FastCastModule = script.Parent

local TypeDef = require(FastCastModule:WaitForChild("TypeDefinitions"))
local FastCastEnums = require(FastCastModule:WaitForChild("FastCastEnums"))
local Config = require(FastCastModule:WaitForChild("Config"))

local DebugLogging = Config.DebugLogging
local EnumCastTypes = FastCastEnums.CastType

local DEFAULT_MAX_DISTANCE = 1000
local FC_VIS_OBJ_NAME = "FastCastVisualizationObjects"

-- ============================================================================
-- Types
-- ============================================================================

type BlockcastVariant = {
	CastType: number,
	Size: Vector3
}

type SpherecastVariant = {
	CastType: number,
	Radius: number
}

type CastVariants = BlockcastVariant | SpherecastVariant

type RayVisualizerVariant = {
	castLength: number
}

type BlockVisualizerVariant = {
	size: Vector3
}

type SphereVisualizerVariant = {
	radius: number
}

type CastVisualizerVariants =
	RayVisualizerVariant
	| BlockVisualizerVariant
	| SphereVisualizerVariant

type QueuedEventData = {
	eventType: string,
	args: { any }
}

type QueuedVisualizeCastData = {
	castStartCFrame: CFrame,
	sub: boolean
}

type QueuedVisualizeHitData = {
	atCF: CFrame,
	wasPierce: boolean,
	sub: boolean
}

-- ============================================================================
-- State
-- ============================================================================

local casts_TotalRunTime = {} :: { [number]: number }
local casts_DistanceCovered = {} :: { [number]: number }

local casts_HighFidelitySegmentSize = {} :: { [number]: number }
local casts_HighFidelityBehavior = {} :: { [number]: number }

local casts_IsActivelySimulatingPierce = {} :: { [number]: boolean }
local casts_IsActivelyResimulating = {} :: { [number]: boolean }
local casts_CancelHighResCast = {} :: { [number]: boolean }

local casts_Trajectory = {} :: { [number]: TypeDef.CastTrajectory }

local casts_FastCastEventsConfig =
	{} :: { [number]: TypeDef.FastCastEventsConfig }

local casts_VisualizeCasts = {} :: { [number]: boolean }
local casts_VisualizeCastSettings =
	{} :: { [number]: TypeDef.VisualizeCastSettings }

local casts_RayInfo = {} :: { [number]: TypeDef.CastRayInfo }
local casts_UserData = {} :: { [number]: any }

local casts_CFrame = {} :: { [number]: CFrame }

local casts_CastType = {} :: { [number]: number }
local casts_CastVariant = {} :: { [number]: CastVariants }

local casts_MaxDistance = {} :: { [number]: number }
local casts_RayDisplacement = {} :: { [number]: number }

local casts_ActiveMotor6Ds = {} :: { [number]: Motor6D }

local casts_ID = {} :: { number }
local casts_ID_Index = {} :: { [number]: number }

local queuedEvents: { [number]: { QueuedEventData } } = {}
local queuedVisualizes: {
	[number]: { QueuedVisualizeCastData | QueuedVisualizeHitData }
} = {}

local ActivesRef: any = nil
local BaseCastRef: any = nil

local CurrentMovementMode: "BulkMoveTo" | "Motor6D" = "BulkMoveTo"
local MovementEnabled = false

local FastCastEvents = {} :: {[number]: (any) -> ()}

-- ============================================================================
-- Math
-- ============================================================================

local function GetPositionAtTime(
	t: number,
	origin: Vector3,
	initialVelocity: Vector3,
	acceleration: Vector3
): Vector3
	return origin
		+ initialVelocity * t
		+ acceleration * (t ^ 2 / 2)
end

local function GetVelocityAtTime(
	t: number,
	initialVelocity: Vector3,
	acceleration: Vector3
): Vector3
	return initialVelocity + acceleration * t
end

-- ============================================================================
-- Cast handlers
-- ============================================================================

local castHandlers = {
	[EnumCastTypes.Raycast] = function(
		worldRoot: WorldRoot,
		origin: Vector3,
		direction: Vector3,
		params: RaycastParams
	)
		return worldRoot:Raycast(origin, direction, params)
	end,

	[EnumCastTypes.Blockcast] = function(
		worldRoot: WorldRoot,
		origin: Vector3,
		direction: Vector3,
		params: RaycastParams,
		variant: BlockcastVariant
	)
		return worldRoot:Blockcast(
			CFrame.new(origin),
			variant.Size,
			direction,
			params
		)
	end,

	[EnumCastTypes.Spherecast] = function(
		worldRoot: WorldRoot,
		origin: Vector3,
		direction: Vector3,
		params: RaycastParams,
		variant: SpherecastVariant
	)
		return worldRoot:Spherecast(
			origin,
			variant.Radius,
			direction,
			params
		)
	end
}

-- ============================================================================
-- Visualization
-- ============================================================================

local function DebrisAdd(obj: Instance, lifetime: number)
	if lifetime <= 0 then
		obj:Destroy()
		return
	end

	task.delay(lifetime, function()
		if obj.Parent then
			obj:Destroy()
		end
	end)
end

local function GetVisualizationContainer(): Instance
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
	startCFrame: CFrame,
	settings: TypeDef.VisualizeCastSettings,
	variant: RayVisualizerVariant
)
	local adornment = Instance.new("ConeHandleAdornment")

	adornment.Adornee = workspace.Terrain
	adornment.CFrame = startCFrame
	adornment.Height = variant.castLength
	adornment.Color3 = settings.Debug_SegmentColor
	adornment.Radius = settings.Debug_SegmentSize
	adornment.Transparency = settings.Debug_SegmentTransparency
	adornment.Parent = GetVisualizationContainer()

	DebrisAdd(adornment, settings.Debug_RayLifetime)
end

local function DbgVisualizeBlockSegment(
	startCFrame: CFrame,
	settings: TypeDef.VisualizeCastSettings,
	variant: BlockVisualizerVariant
)
	local adornment = Instance.new("BoxHandleAdornment")

	adornment.Adornee = workspace.Terrain
	adornment.CFrame = startCFrame
	adornment.Size = variant.size
	adornment.Color3 = settings.Debug_SegmentColor
	adornment.Transparency = settings.Debug_SegmentTransparency
	adornment.Parent = GetVisualizationContainer()

	DebrisAdd(adornment, settings.Debug_RayLifetime)
end

local function DbgVisualizeSphereSegment(
	startCFrame: CFrame,
	settings: TypeDef.VisualizeCastSettings,
	variant: SphereVisualizerVariant
)
	local adornment = Instance.new("SphereHandleAdornment")

	adornment.Adornee = workspace.Terrain
	adornment.CFrame = startCFrame
	adornment.Radius = variant.radius
	adornment.Color3 = settings.Debug_SegmentColor
	adornment.Transparency = settings.Debug_SegmentTransparency
	adornment.Parent = GetVisualizationContainer()

	DebrisAdd(adornment, settings.Debug_RayLifetime)
end

local function DbgVisualizeHit(
	atCFrame: CFrame,
	wasPierce: boolean,
	settings: TypeDef.VisualizeCastSettings
)
	local adornment = Instance.new("SphereHandleAdornment")

	adornment.Adornee = workspace.Terrain
	adornment.CFrame = atCFrame

	if wasPierce then
		adornment.Radius = settings.Debug_RayPierceSize
		adornment.Transparency = settings.Debug_RayPierceTransparency
		adornment.Color3 = settings.Debug_RayPierceColor
	else
		adornment.Radius = settings.Debug_HitSize
		adornment.Transparency = settings.Debug_HitTransparency
		adornment.Color3 = settings.Debug_HitColor
	end

	adornment.Parent = GetVisualizationContainer()

	DebrisAdd(adornment, settings.Debug_HitLifetime)
end

local Visualizers = {
	[EnumCastTypes.Raycast] = DbgVisualizeRaySegment,
	[EnumCastTypes.Blockcast] = DbgVisualizeBlockSegment,
	[EnumCastTypes.Spherecast] = DbgVisualizeSphereSegment
}

-- ============================================================================
-- Queued visualization
-- ============================================================================

local function QueueVisualize(
	castID: number,
	data: QueuedVisualizeCastData | QueuedVisualizeHitData
)
	if not casts_VisualizeCasts[castID] then
		return
	end

	local queue = queuedVisualizes[castID]

	if not queue then
		queue = {}
		queuedVisualizes[castID] = queue
	end

	table.insert(queue, data)
end

local function FireQueuedVisualizes(
	visualizes: {
		[number]: {
			QueuedVisualizeCastData | QueuedVisualizeHitData
		}
	}
)
	local sortedIDs = {}

	for id in visualizes do
		table.insert(sortedIDs, id)
	end

	table.sort(sortedIDs)

	for _, castID in sortedIDs do
		local list = visualizes[castID]

		if not list then
			continue
		end

		local settings = casts_VisualizeCastSettings[castID]

		if not settings then
			continue
		end

		for _, data in list do
			-- Hit visualization
			if data.atCF then
				if DebugLogging.Hit 
					and not data.wasPierce 
					and not data.sub 
				then
					print("Hit was successful. Terminating.")
				end

				if DebugLogging.Pierced 
					and data.wasPierce 
					and not data.sub 
				then
					print("Piercing function returned TRUE to pierce this part.")
				end

				DbgVisualizeHit(
					data.atCF,
					data.wasPierce,
					settings
				)

				continue
			end

			-- Segment visualization
			if DebugLogging.Segment and data.sub then
				print("Subcast visualization")
			end

			local castType = casts_CastType[castID]
			local visualizer = Visualizers[castType]

			if not visualizer then
				continue
			end

			local variant: CastVisualizerVariants

			if castType == EnumCastTypes.Raycast then
				variant = {
					castLength = casts_RayDisplacement[castID] or 1
				}
			elseif castType == EnumCastTypes.Blockcast then
				variant = {
					size = (casts_CastVariant[castID] :: BlockcastVariant).Size
				}
			else
				variant = {
					radius = (casts_CastVariant[castID] :: SpherecastVariant).Radius
				}
			end

			visualizer(
				data.castStartCFrame,
				settings,
				variant
			)
		end
	end
end

-- ============================================================================
-- Queued events
-- ============================================================================

local function QueueEvent(
	castID: number,
	eventType: string,
	...: any
)
	local queue = queuedEvents[castID]

	if not queue then
		queue = {}
		queuedEvents[castID] = queue
	end

	table.insert(queue, {
		eventType = eventType,
		args = { ... }
	})
end

local function FireQueuedEvents(
	events: { [number]: { QueuedEventData } }
)
	local sortedIDs = {}

	for id in events do
		table.insert(sortedIDs, id)
	end

	table.sort(sortedIDs)

	for _, castID in sortedIDs do
		local eventList = events[castID]

		if not eventList then
			continue
		end

		for _, event in eventList do
			local cast = ActivesRef[castID]

			if not cast then
				continue
			end

			local args = event.args

			local eventConfig = casts_FastCastEventsConfig[castID]

			local eventType = event.eventType

			if eventType == "LengthChanged" then
				local lastPoint = args[1]
				local rayDirection = args[2]
				local displacement = args[3]
				local velocity = args[4]
				local cosmetic = args[5]

				if eventConfig and eventConfig.UseLengthChanged then

					local lengthChanged = FastCastEvents.LengthChanged
					if lengthChanged then
						lengthChanged(
							cast,
							lastPoint,
							rayDirection,
							displacement,
							velocity,
							cosmetic
						)
					end
				end

			elseif eventType == "Hit" then
				local result = args[1]
				local velocity = args[2]
				local cosmetic = args[3]

				if eventConfig and eventConfig.UseHit then

					local Hit = FastCastEvents.Hit
					if Hit then
						Hit(
							cast,
							result,
							velocity,
							cosmetic
						)
					end
				end

			elseif eventType == "Pierced" then
				local result = args[1]
				local velocity = args[2]
				local cosmetic = args[3]

				if eventConfig and eventConfig.UsePierced then

					local Pierced = FastCastEvents.Pierced
					if Pierced then
						Pierced(
							cast,
							result,
							velocity,
							cosmetic
						)
					end
				end

			elseif eventType == "CastTerminating" then
				local callback = args[1]
				if callback then
					callback(cast)
				end
				BaseCastRef._TerminateCast(castID)
				SerialSimulation_Unregister(castID)
			end
		end
	end
end

-- ============================================================================
-- Movement
-- ============================================================================

local function BulkMoveTo()
	if CurrentMovementMode ~= "BulkMoveTo"
		or not MovementEnabled
	then
		return
	end

	local parts = table.create(#casts_ID)
	local cframes = table.create(#casts_ID)

	for _, id in casts_ID do
		local rayInfo = casts_RayInfo[id]
		local cosmetic = rayInfo and rayInfo.CosmeticBulletObject

		if cosmetic and cosmetic.Parent then
			table.insert(parts, cosmetic)
			table.insert(cframes, casts_CFrame[id])
		end
	end

	if #parts > 0 then
		workspace:BulkMoveTo(
			parts,
			cframes,
			Enum.BulkMoveMode.FireCFrameChanged
		)
	end
end

local function UpdateMotor6Ds()
	if CurrentMovementMode ~= "Motor6D"
		or not MovementEnabled
	then
		return
	end

	for id, motor6d in casts_ActiveMotor6Ds do
		if motor6d and motor6d.Parent then
			motor6d.Transform = casts_CFrame[id]
		end
	end
end

-- ============================================================================
-- Simulation helpers
-- ============================================================================

local function QueueHit(
	id: number,
	result: RaycastResult,
	velocity: Vector3,
	sub: boolean,
	castTerminatingfn: TypeDef.OnCastTerminatingFunction?
)
	QueueEvent(
		id,
		"Hit",
		result,
		velocity,
		casts_RayInfo[id].CosmeticBulletObject
	)

	QueueVisualize(id, {
		atCF = CFrame.new(result.Position),
		wasPierce = false,
		sub = sub
	})

	QueueEvent(
		id,
		"CastTerminating",
		castTerminatingfn
	)
end

local function QueuePierce(
	id: number,
	result: RaycastResult,
	velocity: Vector3,
	sub: boolean
)
	QueueEvent(
		id,
		"Pierced",
		result,
		velocity,
		casts_RayInfo[id].CosmeticBulletObject
	)

	QueueVisualize(id, {
		atCF = CFrame.new(result.Position),
		wasPierce = true,
		sub = sub
	})
end

local function ShouldPierce(
	id: number,
	result: RaycastResult,
	velocity: Vector3,
	canPierce: TypeDef.CanPierceFunction?
): boolean
	if not canPierce then
		return false
	end

	return canPierce(
		ActivesRef[id],
		result,
		velocity,
		casts_RayInfo[id].CosmeticBulletObject
	)
end

-- ============================================================================
-- Automatic high-fidelity resimulation
-- ============================================================================

local function ResimulateHit(
	id: number,
	delta: number,
	lastDelta: number,
	origin: Vector3,
	initialVelocity: Vector3,
	acceleration: Vector3,
	targetWorldRoot: WorldRoot,
	castHandler: any,
	canPierce: TypeDef.CanPierceFunction?,
	castTerminatingfn: TypeDef.OnCastTerminatingFunction?,
	fallbackResult: RaycastResult,
	fallbackVelocity: Vector3
): boolean

	casts_IsActivelyResimulating[id] = true

	local rayDisplacement = casts_RayDisplacement[id]

	local segmentCount = math.max(
		1,
		math.floor(
			rayDisplacement
				/ casts_HighFidelitySegmentSize[id]
		)
	)

	local timeIncrement = delta / segmentCount

	if DebugLogging.Calculation then
		print(
			"Performing subcast! Time increment: "
				.. timeIncrement
				.. ", num segments: "
				.. segmentCount
		)
	end

	for segmentIndex = 1, segmentCount do
		if casts_CancelHighResCast[id] then
			casts_CancelHighResCast[id] = false
			break
		end

		local subTime =
			lastDelta + timeIncrement * segmentIndex

		local subPosition = GetPositionAtTime(
			subTime,
			origin,
			initialVelocity,
			acceleration
		)

		local subVelocity = GetVelocityAtTime(
			subTime,
			initialVelocity,
			acceleration
		)

		local subDirection = subVelocity * timeIncrement

		local subResult = castHandler(
			targetWorldRoot,
			subPosition,
			subDirection,
			casts_RayInfo[id].Parameters,
			casts_CastVariant[id]
		)

		QueueVisualize(id, {
			castStartCFrame = CFrame.new(
				subPosition,
				subPosition + subVelocity
			),
			sub = true
		})

		if not subResult then
			continue
		end

		if ShouldPierce(
			id,
			subResult,
			subVelocity,
			canPierce
			) then
			QueuePierce(
				id,
				subResult,
				subVelocity,
				true
			)

			continue
		end

		casts_IsActivelyResimulating[id] = false

		QueueHit(
			id,
			subResult,
			subVelocity,
			true,
			castTerminatingfn
		)

		return true
	end

	casts_IsActivelyResimulating[id] = false

	-- The original cast hit, but none of the
	-- high-resolution subcasts did.
	QueueHit(
		id,
		fallbackResult,
		fallbackVelocity,
		false,
		castTerminatingfn
	)

	return true
end

-- ============================================================================
-- Single simulation step
-- ============================================================================

local function SimulateCast(
	id: number,
	delta: number
)
	if DebugLogging.Casting then
		print("Casting for frame - SimulateCast")
	end

	local trajectory = casts_Trajectory[id]
	local rayInfo = casts_RayInfo[id]
	local variant = casts_CastVariant[id]

	local origin = trajectory.Origin
	local initialVelocity = trajectory.InitialVelocity
	local acceleration = trajectory.Acceleration

	local previousTime = casts_TotalRunTime[id] - trajectory.StartTime

	local lastPoint = GetPositionAtTime(
		previousTime,
		origin,
		initialVelocity,
		acceleration
	)

	casts_TotalRunTime[id] += delta

	local currentTime = casts_TotalRunTime[id] - trajectory.StartTime

	local currentPoint = GetPositionAtTime(
		currentTime,
		origin,
		initialVelocity,
		acceleration
	)

	local velocity = GetVelocityAtTime(
		currentTime,
		initialVelocity,
		acceleration
	)

	local displacement = currentPoint - lastPoint

	local worldRoot = rayInfo.WorldRoot
	local handler = castHandlers[variant.CastType]

	local result = handler(
		worldRoot,
		lastPoint,
		displacement,
		rayInfo.Parameters,
		variant
	)

	local hitPoint = result
		and result.Position
		or currentPoint

	local rayDisplacement = (hitPoint - lastPoint).Magnitude

	casts_RayDisplacement[id] = rayDisplacement

	-- Update cosmetic transform.
	local direction = displacement

	casts_CFrame[id] =
		(
			if direction ~= Vector3.zero
			then CFrame.new(
				lastPoint,
				lastPoint + direction
			)
			else CFrame.new(lastPoint)
		)
		* CFrame.new(
			0,
			0,
			-rayDisplacement / 2
		)

	QueueEvent(
		id,
		"LengthChanged",
		lastPoint,
		direction.Unit,
		rayDisplacement,
		velocity,
		rayInfo.CosmeticBulletObject
	)

	casts_DistanceCovered[id] += rayDisplacement

	if delta > 0 then
		QueueVisualize(id, {
			castStartCFrame = CFrame.new(
				lastPoint,
				lastPoint + direction
			),
			sub = false
		})
	end

	-- ------------------------------------------------------------------------
	-- No hit.
	-- ------------------------------------------------------------------------

	if not result then
		if casts_DistanceCovered[id] >= casts_MaxDistance[id] then
			QueueEvent(
				id,
				"CastTerminating"
			)
		end

		return
	end

	-- ------------------------------------------------------------------------
	-- Cosmetic bullet collision.
	-- ------------------------------------------------------------------------

	if result.Instance == rayInfo.CosmeticBulletObject then
		return
	end

	local canPiercefn = FastCastEvents.CanPierce
	local castTerminatingfn = FastCastEvents.CastTerminating

	-- ------------------------------------------------------------------------
	-- Pierce.
	-- ------------------------------------------------------------------------

	if ShouldPierce(
		id,
		result,
		velocity,
		canPiercefn
		) then
		QueuePierce(
			id,
			result,
			velocity,
			false
		)

		return
	end

	-- ------------------------------------------------------------------------
	-- Hit.
	-- ------------------------------------------------------------------------

	if casts_HighFidelityBehavior[id]
		== FastCastEnums.HighFidelityBehavior.Automatic
		and casts_HighFidelitySegmentSize[id] > 0
	then
		if casts_IsActivelyResimulating[id] then
			QueueEvent(
				id,
				"CastTerminating",
				castTerminatingfn
			)

			warn(
				"Cascading cast lag encountered! "
					.. "The caster attempted to perform a high fidelity "
					.. "cast before the previous one completed. "
					.. "Consider increasing HighFidelitySegmentSize."
			)

			return
		end

		local lastDelta = previousTime

		ResimulateHit(
			id,
			delta,
			lastDelta,
			origin,
			initialVelocity,
			acceleration,
			worldRoot,
			handler,
			canPiercefn,
			castTerminatingfn,
			result,
			velocity
		)

		return
	end

	QueueHit(
		id,
		result,
		velocity,
		false
	)
end

-- ============================================================================
-- Always high-fidelity simulation
-- ============================================================================

local function SimulateAlwaysHighFidelity(
	id: number,
	delta: number
)
	if casts_IsActivelyResimulating[id] then
		QueueEvent(
			id,
			"CastTerminating"
		)

		warn(
			"Cascading cast lag encountered! "
				.. "The caster attempted to perform a high fidelity "
				.. "cast before the previous one completed. "
				.. "Consider increasing HighFidelitySegmentSize."
		)

		return
	end

	casts_IsActivelyResimulating[id] = true

	local trajectory = casts_Trajectory[id]
	local rayInfo = casts_RayInfo[id]
	local variant = casts_CastVariant[id]

	local origin = trajectory.Origin
	local initialVelocity = trajectory.InitialVelocity
	local acceleration = trajectory.Acceleration

	local currentTime = casts_TotalRunTime[id] - trajectory.StartTime

	local lastPoint = GetPositionAtTime(
		currentTime,
		origin,
		initialVelocity,
		acceleration
	)

	-- Temporarily advance time to determine
	-- the approximate distance for this frame.
	casts_TotalRunTime[id] += delta

	local nextTime = casts_TotalRunTime[id] - trajectory.StartTime

	local currentPoint = GetPositionAtTime(
		nextTime,
		origin,
		initialVelocity,
		acceleration
	)

	local currentVelocity = GetVelocityAtTime(
		nextTime,
		initialVelocity,
		acceleration
	)

	local totalDisplacement = currentPoint - lastPoint

	local direction =
		totalDisplacement.Unit
		* currentVelocity.Magnitude
		* delta

	local handler = castHandlers[variant.CastType]

	local resultOfCast = handler(
		rayInfo.WorldRoot,
		lastPoint,
		direction,
		rayInfo.Parameters,
		variant
	)

	local endpoint =
		resultOfCast
		and resultOfCast.Position
		or currentPoint

	local distance = (endpoint - lastPoint).Magnitude

	casts_TotalRunTime[id] -= delta

	local segmentCount = math.max(
		1,
		math.floor(
			distance
				/ casts_HighFidelitySegmentSize[id]
		)
	)

	local timeIncrement = delta / segmentCount

	if DebugLogging.Calculation then
		print(
			"Performing subcast! Time increment: "
				.. timeIncrement
				.. ", num segments: "
				.. segmentCount
		)
	end

	for segmentIndex = 1, segmentCount do
		if casts_CancelHighResCast[id] then
			casts_CancelHighResCast[id] = false
			break
		end

		if not ActivesRef[id] then
			casts_IsActivelyResimulating[id] = false
			return
		end

		if DebugLogging.Segment then
			print(
				"["
					.. segmentIndex
					.. "] Subcast of time increment "
					.. timeIncrement
			)
		end

		SimulateCast(
			id,
			timeIncrement
		)
	end

	casts_IsActivelyResimulating[id] = false
end

-- ============================================================================
-- Registration
-- ============================================================================

function SerialSimulation_Register(cast: any)
	local id = cast.ID

	casts_TotalRunTime[id] = cast.StateInfo.TotalRuntime or 0

	casts_DistanceCovered[id] = 0

	casts_HighFidelitySegmentSize[id] = cast.StateInfo.HighFidelitySegmentSize or 0.1

	casts_HighFidelityBehavior[id] = cast.StateInfo.HighFidelityBehavior or 0

	casts_IsActivelySimulatingPierce[id] = false
	casts_IsActivelyResimulating[id] = false
	casts_CancelHighResCast[id] = false

	casts_Trajectory[id] = cast.StateInfo.Trajectory

	casts_FastCastEventsConfig[id] = cast.StateInfo.FastCastEventsConfig

	casts_VisualizeCasts[id] = cast.StateInfo.VisualizeCasts

	casts_VisualizeCastSettings[id] = cast.StateInfo.VisualizeCastSettings

	casts_RayInfo[id] = cast.RayInfo
	casts_UserData[id] = cast.UserData

	casts_CastType[id] =
		cast.CastVariant.CastType

	casts_CastVariant[id] =
		cast.CastVariant

	casts_MaxDistance[id] =
		cast.RayInfo.MaxDistance
		or DEFAULT_MAX_DISTANCE

	table.insert(casts_ID, id)
	casts_ID_Index[id] = #casts_ID

	local trajectory = casts_Trajectory[id]

	local position = GetPositionAtTime(
		casts_TotalRunTime[id],
		trajectory.Origin,
		trajectory.InitialVelocity,
		trajectory.Acceleration
	)

	casts_CFrame[id] = CFrame.new(position)
	cast.CFrame = casts_CFrame[id]

	if CurrentMovementMode == "Motor6D"
		and MovementEnabled
	then
		local cosmetic = casts_RayInfo[id].CosmeticBulletObject

		if cosmetic
			and BaseCastRef
			and BaseCastRef._GetMotor6D
		then
			casts_ActiveMotor6Ds[id] =
				BaseCastRef._GetMotor6D(cosmetic)
		end
	end

	queuedEvents[id] = {}
end

function SerialSimulation_Unregister(castID: number)
	casts_TotalRunTime[castID] = nil
	casts_DistanceCovered[castID] = nil

	casts_HighFidelitySegmentSize[castID] = nil
	casts_HighFidelityBehavior[castID] = nil

	casts_IsActivelySimulatingPierce[castID] = nil
	casts_IsActivelyResimulating[castID] = nil
	casts_CancelHighResCast[castID] = nil

	casts_Trajectory[castID] = nil

	casts_FastCastEventsConfig[castID] = nil

	casts_VisualizeCasts[castID] = nil
	casts_VisualizeCastSettings[castID] = nil

	casts_RayInfo[castID] = nil
	casts_UserData[castID] = nil

	casts_CFrame[castID] = nil
	casts_CastType[castID] = nil
	casts_CastVariant[castID] = nil

	casts_MaxDistance[castID] = nil
	casts_RayDisplacement[castID] = nil

	if casts_ActiveMotor6Ds[castID] then
		if BaseCastRef
			and BaseCastRef._ReturnMotor6D
		then
			BaseCastRef._ReturnMotor6D(
				casts_ActiveMotor6Ds[castID]
			)
		end

		casts_ActiveMotor6Ds[castID] = nil
	end

	local index = casts_ID_Index[castID]

	if index then
		local lastID = casts_ID[#casts_ID]

		casts_ID[index] = lastID
		casts_ID_Index[lastID] = index

		table.remove(casts_ID, #casts_ID)
		casts_ID_Index[castID] = nil
	end

	queuedEvents[castID] = nil
	queuedVisualizes[castID] = nil
end

-- ============================================================================
-- Movement configuration
-- ============================================================================

local function SetMovementModeEnabled(
	enabled: boolean,
	mode: "BulkMoveTo" | "Motor6D"
)
	local oldMode = CurrentMovementMode

	CurrentMovementMode = mode
	MovementEnabled = enabled

	if oldMode == "Motor6D"
		and mode ~= "Motor6D"
	then
		for id, motor6d in casts_ActiveMotor6Ds do
			if BaseCastRef
				and BaseCastRef._ReturnMotor6D
			then
				BaseCastRef._ReturnMotor6D(motor6d)
			end

			casts_ActiveMotor6Ds[id] = nil
		end
	end

	if mode == "Motor6D"
		and enabled
		and oldMode ~= "Motor6D"
	then
		for _, id in casts_ID do
			if casts_ActiveMotor6Ds[id] then
				continue
			end

			local cosmetic =
				casts_RayInfo[id].CosmeticBulletObject

			if cosmetic
				and BaseCastRef
				and BaseCastRef._GetMotor6D
			then
				casts_ActiveMotor6Ds[id] =
					BaseCastRef._GetMotor6D(cosmetic)
			end
		end
	end
end

-- ============================================================================
-- Main update
-- ============================================================================

local function UpdateCasts(delta: number)
	for _, id in casts_ID do
		local cast = ActivesRef[id]

		if cast and cast._Destroying then
			continue
		end

		if not casts_Trajectory[id] then
			continue
		end

		if casts_HighFidelitySegmentSize[id] <= 0 then
			casts_HighFidelitySegmentSize[id] = 0.1
		end

		local behavior = casts_HighFidelityBehavior[id]

		if behavior == FastCastEnums.HighFidelityBehavior.Always then
			SimulateAlwaysHighFidelity(
				id,
				delta
			)
		else
			SimulateCast(
				id,
				delta
			)
		end
	end

	-- =========================================================================
	-- Write-back SoA -> ActiveCast so ActivesRef[id] has current values
	-- =========================================================================

	for _, id in casts_ID do
		local cast = ActivesRef[id]

		if cast then
			cast.StateInfo.TotalRuntime = casts_TotalRunTime[id]
			cast.StateInfo.DistanceCovered = casts_DistanceCovered[id]
			cast.CFrame = casts_CFrame[id]
		end
	end

	-- =========================================================================
	-- Main-thread-only work.
	-- =========================================================================

	UpdateMotor6Ds()
	BulkMoveTo()

	local eventsToProcess = queuedEvents
	queuedEvents = {}

	local visualizesToProcess = queuedVisualizes
	queuedVisualizes = {}

	FireQueuedVisualizes(
		visualizesToProcess
	)

	FireQueuedEvents(
		eventsToProcess
	)
end

-- ============================================================================
-- Public API
-- ============================================================================

local SerialSimulation = {}

SerialSimulation.Connection = nil :: RBXScriptConnection?

function SerialSimulation.Init(baseCastRef: any, Actives: any, events: TypeDef.FastCastEvents)
	if ActivesRef ~= nil then
		warn(
			"[FastCast2] SerialSimulation already initialized. Skipping."
		)

		return
	end

	BaseCastRef = baseCastRef
	ActivesRef = Actives

	FastCastEvents = events
end

function SerialSimulation.Register(cast: any)
	SerialSimulation_Register(cast)
end

function SerialSimulation.Unregister(castID: number)
	SerialSimulation_Unregister(castID)
end

function SerialSimulation.SetMovementModeEnabled(
	enabled: boolean,
	mode: "BulkMoveTo" | "Motor6D"
)
	SetMovementModeEnabled(enabled, mode)
end

function SerialSimulation.Start()
	if SerialSimulation.Connection then
		--warn("[FastCast2] SerialSimulation already started.")
		return
	end

	--[[
		You can edit RunService event, if you want
	]]
	if RS:IsClient() then
		SerialSimulation.Connection = RS.PreSimulation:Connect(UpdateCasts)
	else
		SerialSimulation.Connection = RS.Heartbeat:Connect(UpdateCasts)
	end
end

function SerialSimulation.Stop()
	if SerialSimulation.Connection then
		SerialSimulation.Connection:Disconnect()
		SerialSimulation.Connection = nil
	end
end

function SerialSimulation._UpdateEvent(name: string, newEventfn: (any) -> ())
	if type(newEventfn) ~= "function" then
		return
	end

	FastCastEvents[name] = newEventfn
end

return SerialSimulation
