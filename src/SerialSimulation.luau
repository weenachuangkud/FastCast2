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

-- Event type constants (numeric IDs avoid string comparison in hot path)
local EVT_LENGTH_CHANGED = 1
local EVT_HIT = 2
local EVT_PIERCED = 3
local EVT_CAST_TERMINATING = 4

--[[
	Shoutout to DrSinek for some code
]]
local EPSILON = 1e-6
local RAY_SEARCH_OFFSET = 1e-4

type QueuedVisualizeCastData = {
	castStartCFrame: CFrame,
	sub: boolean
}

type QueuedVisualizeHitData = {
	atCF: CFrame,
	wasPierce: boolean,
	sub: boolean
}

type QueuedVis = { any }

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

-- Cached per-cast "does anyone care about this event?" flags.
local casts_WantLengthChanged = {} :: { [number]: boolean }
local casts_HasCosmetic = {} :: { [number]: boolean }
local castsWithCosmetics: number = 0

-- Packed metadata: f64 cast ID + u8 event type. Keep IDs lossless (no u32
-- wraparound); Roblox values stay in the reusable argument tables below.
-- Capacity doubles only at a new high-water mark, never during steady state.
local EVENT_STRIDE = 9
local eventCapacity = 256
local eventMetadata = buffer.create(eventCapacity * EVENT_STRIDE)
local queuedEventsCount: number = 0

-- Flat visualization queue: { castID, data }
-- Reused every frame via table.clear
local queuedVisualizes: { QueuedVis } = {}
local queuedVisCount: number = 0

local ActivesRef: any = nil
local BaseCastRef: any = nil

local CurrentMovementMode: "BulkMoveTo" | "Motor6D" = "BulkMoveTo"
local MovementEnabled = false

local FastCastEvents = {} :: any

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
		+ acceleration * (t * t * 0.5)
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

-- ============================================================================
-- Pre-allocated pools (reused every frame, never freed)
-- ============================================================================

local argsPool: { { any } } = {}
local argsPoolCount: number = 0

local function GetArgs(): { any }
	argsPoolCount += 1
	if argsPoolCount > #argsPool then
		argsPool[argsPoolCount] = {}
	end
	return argsPool[argsPoolCount]
end

local visPool: { QueuedVis } = {}
local visPoolCount: number = 0

local function GetVis(): QueuedVis
	visPoolCount += 1
	if visPoolCount > #visPool then
		visPool[visPoolCount] = { 0, nil }
	end
	return visPool[visPoolCount]
end

-- Pooled visualization data tables (avoids per-frame allocations)
-- Hit/pierce data layout: { atCF :: CFrame, wasPierce :: boolean, sub :: boolean }
-- Segment data layout: { castStartCFrame :: CFrame, sub :: boolean }
local hitVisPool: { { any } } = {}
local hitVisPoolCount: number = 0

local segVisPool: { { any } } = {}
local segVisPoolCount: number = 0

--[[
	Do not remove ":: any" it giving me annoying warning
]]

local function GetHitVisData(): { any }
	hitVisPoolCount += 1
	if hitVisPoolCount > #hitVisPool then
		hitVisPool[hitVisPoolCount] = { nil :: any, false, false }
	end
	return hitVisPool[hitVisPoolCount]
end

local function GetSegVisData(): { any }
	segVisPoolCount += 1
	if segVisPoolCount > #segVisPool then
		segVisPool[segVisPoolCount] = { nil :: any, false }
	end
	return segVisPool[segVisPoolCount]
end

local function ResetPools()
	argsPoolCount = 0
	visPoolCount = 0
	hitVisPoolCount = 0
	segVisPoolCount = 0
end

-- ============================================================================
-- Queued visualizations (flat, allocation-free)
-- ============================================================================

-- Hit/pierce visualization: pass fields directly, data table is pooled
local function QueueVisualizeHit(
	castID: number,
	atCF: CFrame,
	wasPierce: boolean,
	sub: boolean
)
	if not casts_VisualizeCasts[castID] then
		return
	end

	local data = GetHitVisData()
	data[1] = atCF
	data[2] = wasPierce
	data[3] = sub

	queuedVisCount += 1
	local entry = GetVis()
	entry[1] = castID
	entry[2] = data
	entry[3] = 1 -- tag: 1 = hit data
	queuedVisualizes[queuedVisCount] = entry
end

-- Segment visualization: pass fields directly, data table is pooled
local function QueueVisualizeSegment(
	castID: number,
	castStartCFrame: CFrame,
	sub: boolean
)
	if not casts_VisualizeCasts[castID] then
		return
	end

	local data = GetSegVisData()
	data[1] = castStartCFrame
	data[2] = sub

	queuedVisCount += 1
	local entry = GetVis()
	entry[1] = castID
	entry[2] = data
	entry[3] = 2 -- tag: 2 = segment data
	queuedVisualizes[queuedVisCount] = entry
end

-- Reusable variant table (consumed synchronously, safe to reuse)
local reusableVariant = {} :: CastVisualizerVariants

local function FireQueuedVisualizes()
	for i = 1, queuedVisCount do
		local entry = queuedVisualizes[i]
		local castID = entry[1] :: number
		local data = entry[2]
		local dataTag = entry[3] :: number

		local settings = casts_VisualizeCastSettings[castID]
		if not settings then
			continue
		end

		-- Hit visualization (tag 1)
		if dataTag == 1 then
			local atCF = data[1] :: CFrame
			local wasPierce = data[2] :: boolean
			local sub = data[3] :: boolean

			if DebugLogging.Hit
				and not wasPierce
				and not sub
			then
				print("Hit was successful. Terminating.")
			end

			if DebugLogging.Pierced
				and wasPierce
				and not sub
			then
				print("Piercing function returned TRUE to pierce this part.")
			end

			DbgVisualizeHit(
				atCF,
				wasPierce,
				settings
			)

			continue
		end

		-- Segment visualization (tag 2)
		local castStartCFrame = data[1] :: CFrame
		local sub = data[2] :: boolean

		if DebugLogging.Segment and sub then
			print("Subcast visualization")
		end

		local castType = casts_CastType[castID]
		local visualizer = Visualizers[castType]

		if not visualizer then
			continue
		end

		-- Reuse single variant table (consumed synchronously)
		if castType == EnumCastTypes.Raycast then
			reusableVariant.castLength = casts_RayDisplacement[castID] or 1
		elseif castType == EnumCastTypes.Blockcast then
			reusableVariant.size = (casts_CastVariant[castID] :: BlockcastVariant).Size
		else
			reusableVariant.radius = (casts_CastVariant[castID] :: SpherecastVariant).Radius
		end

		visualizer(
			castStartCFrame,
			settings,
			reusableVariant
		)
	end
end

-- ============================================================================
-- Queued events (flat, allocation-free)
-- ============================================================================

-- Event signatures have at most five payload values. Assign all slots so
-- nil holes cannot leave stale references behind (the # operator is undefined
-- for sparse arrays), and avoid select/vararg loops in the hot path.
local function QueueEvent(
	castID: number,
	eventType: number,
	arg1: any,
	arg2: any,
	arg3: any,
	arg4: any,
	arg5: any
)
	local args = GetArgs()
	args[1] = arg1
	args[2] = arg2
	args[3] = arg3
	args[4] = arg4
	args[5] = arg5

	queuedEventsCount += 1
	if queuedEventsCount > eventCapacity then
		eventCapacity *= 2
		local expanded = buffer.create(eventCapacity * EVENT_STRIDE)
		buffer.copy(expanded, 0, eventMetadata)
		eventMetadata = expanded
	end
	local offset = (queuedEventsCount - 1) * EVENT_STRIDE
	buffer.writef64(eventMetadata, offset, castID)
	buffer.writeu8(eventMetadata, offset + 8, eventType)
end

local function FireQueuedEvents()
	for i = 1, queuedEventsCount do
		local offset = (i - 1) * EVENT_STRIDE
		local castID = buffer.readf64(eventMetadata, offset)
		local eventType = buffer.readu8(eventMetadata, offset + 8)
		local args = argsPool[i]

		local cast = ActivesRef[castID]
		if not cast then
			continue
		end

		local eventConfig = casts_FastCastEventsConfig[castID]

		if not eventConfig then
			return
		end

		if eventType == EVT_LENGTH_CHANGED then
			if eventConfig.UseLengthChanged then
				local lengthChanged = FastCastEvents.LengthChanged
				if lengthChanged then
					lengthChanged:Fire(
						cast,
						args[1],
						args[2],
						args[3],
						args[4],
						args[5]
					)
				end
			end

		elseif eventType == EVT_HIT then
			if eventConfig.UseHit then
				local Hit = FastCastEvents.Hit
				if Hit then
					Hit:Fire(
						cast,
						args[1],
						args[2],
						args[3]
					)
				end
			end

		elseif eventType == EVT_PIERCED then
			if eventConfig.UsePierced then
				local Pierced = FastCastEvents.Pierced
				if Pierced then
					Pierced:Fire(
						cast,
						args[1],
						args[2],
						args[3]
					)
				end
			end

		elseif eventType == EVT_CAST_TERMINATING then
			if not cast._Destroying then
				cast._Destroying = true
				local castTerminating = FastCastEvents.CastTerminating
				--local eventConfig = cast.StateInfo and cast.StateInfo.FastCastEventsConfig
				if eventConfig.UseCastTerminating and castTerminating then
					castTerminating:Fire(cast)
				end
			end
			BaseCastRef._TerminateCast(castID)
			SerialSimulation_Unregister(castID)
		end
	end

	ResetPools()
	queuedEventsCount = 0
	queuedVisCount = 0
end

-- ============================================================================
-- Movement
-- ============================================================================

-- Pre-allocated arrays for BulkMoveTo (reused every frame)
local bulkParts: { BasePart } = {}
local bulkCframes: { CFrame } = {}
local bulkCount: number = 0
local cosmeticFrame: number = 0

-- Cosmetic parts can be pushed at a lower rate than the simulation. Moving
-- thousands of parts (and replicating their CFrames) is the single most
-- expensive per-frame cost once cosmetics exist.
local function ShouldUpdateCosmetics(): boolean
	local interval = Config.CosmeticUpdateInterval or 1
	if interval <= 1 then
		return true
	end

	cosmeticFrame += 1
	return cosmeticFrame % interval == 0
end

local function BulkMoveTo()
	if CurrentMovementMode ~= "BulkMoveTo"
		or not MovementEnabled
	then
		return
	end

	-- Nothing to move if no cast has a cosmetic part.
	if castsWithCosmetics == 0 then
		return
	end

	if not ShouldUpdateCosmetics() then
		return
	end

	bulkCount = 0

	for _, id in casts_ID do
		local rayInfo = casts_RayInfo[id]
		local cosmetic = rayInfo and rayInfo.CosmeticBulletObject

		if cosmetic and cosmetic.Parent then
			bulkCount += 1
			bulkParts[bulkCount] = cosmetic
			bulkCframes[bulkCount] = casts_CFrame[id]
		end
	end

	if bulkCount > 0 then
		workspace:BulkMoveTo(
			bulkParts,
			bulkCframes,
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

	if not ShouldUpdateCosmetics() then
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
		EVT_HIT,
		result,
		velocity,
		casts_RayInfo[id].CosmeticBulletObject
	)

	QueueVisualizeHit(
		id,
		CFrame.new(result.Position),
		false,
		sub
	)

	QueueEvent(
		id,
		EVT_CAST_TERMINATING,
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
		EVT_PIERCED,
		result,
		velocity,
		casts_RayInfo[id].CosmeticBulletObject
	)

	QueueVisualizeHit(
		id,
		CFrame.new(result.Position),
		true,
		sub
	)
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

	local lastPierced = false

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

		-- Only offset after the previous subcast pierced
		local subOrigin = if lastPierced
			then subPosition + subVelocity.Unit * RAY_SEARCH_OFFSET
			else subPosition

		lastPierced = false

		local subResult = castHandler(
			targetWorldRoot,
			subOrigin,
			subDirection,
			casts_RayInfo[id].Parameters,
			casts_CastVariant[id]
		)

		if casts_VisualizeCasts[id] then
			QueueVisualizeSegment(
				id,
				CFrame.new(
					subPosition,
					subPosition + subVelocity
				),
				true
			)
		end

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

			lastPierced = true
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

	local velocity = GetVelocityAtTime(
		currentTime,
		initialVelocity,
		acceleration
	)

	-- p(t1)-p(t0) = (v0 + a*(t0+t1)/2)*(t1-t0).
	-- Avoid a second position evaluation and cancellation of large world
	-- coordinates. Use the actual elapsed interval after runtime rounding.
	local displacement = (initialVelocity + acceleration * ((previousTime + currentTime) * 0.5))
		* (currentTime - previousTime)
	local displacementMagnitude = displacement.Magnitude

	-- Skip raycast when displacement is negligible (matches SwiftCast EPSILON)
	if displacementMagnitude <= EPSILON then
		casts_DistanceCovered[id] += displacementMagnitude
		return
	end

	local worldRoot = rayInfo.WorldRoot
	local handler = castHandlers[variant.CastType]

	local result = handler(
		worldRoot,
		lastPoint,
		displacement,
		rayInfo.Parameters,
		variant
	)

	local rayDisplacement = if result
		then (result.Position - lastPoint).Magnitude
		else displacementMagnitude

	casts_RayDisplacement[id] = rayDisplacement

	-- Build the midpoint transform directly instead of multiplying two
	-- CFrames. lookAlong avoids losing direction when origin + direction
	-- rounds back to origin at large world coordinates.
	local unitDirection = displacement / displacementMagnitude
	casts_CFrame[id] = CFrame.lookAlong(
		lastPoint + unitDirection * (rayDisplacement * 0.5),
		unitDirection
	)

	if casts_WantLengthChanged[id] and FastCastEvents.LengthChanged then
		QueueEvent(
			id,
			EVT_LENGTH_CHANGED,
			lastPoint,
			unitDirection,
			rayDisplacement,
			velocity,
			rayInfo.CosmeticBulletObject
		)
	end

	casts_DistanceCovered[id] += rayDisplacement

	if delta > 0 and casts_VisualizeCasts[id] then
		QueueVisualizeSegment(
			id,
			CFrame.lookAlong(lastPoint, unitDirection),
			false
		)
	end

	-- ------------------------------------------------------------------------
	-- No hit.
	-- ------------------------------------------------------------------------

	if not result then
		if casts_DistanceCovered[id] >= casts_MaxDistance[id] then
			QueueEvent(
				id,
				EVT_CAST_TERMINATING
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
				EVT_CAST_TERMINATING,
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
			EVT_CAST_TERMINATING
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

	local eventConfig = casts_FastCastEventsConfig[id]

	casts_WantLengthChanged[id] =
		eventConfig ~= nil and eventConfig.UseLengthChanged == true

	local hasCosmetic = cast.RayInfo.CosmeticBulletObject ~= nil
	casts_HasCosmetic[id] = hasCosmetic
	if hasCosmetic then
		castsWithCosmetics += 1
	end

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

	casts_WantLengthChanged[castID] = nil
	if casts_HasCosmetic[castID] then
		castsWithCosmetics -= 1
	end
	casts_HasCosmetic[castID] = nil

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

		-- Write-back SoA -> ActiveCast (merged to avoid second iteration)
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

	FireQueuedVisualizes()
	FireQueuedEvents()
end

-- ============================================================================
-- Public API
-- ============================================================================

local SerialSimulation = {}

SerialSimulation.Connection = nil :: RBXScriptConnection?

function SerialSimulation.Init(baseCastRef: any, Actives: any, events: TypeDef.FastCastSignalEvents)
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

	if Config.SimulationMode == "Fixed" then
		SerialSimulation.Connection = RS:BindToSimulation(function(dt)
			UpdateCasts(dt)
		end, Config.FixedSimulationFrequency)
	else
		if RS:IsClient() then
			SerialSimulation.Connection =
				RS.PreSimulation:Connect(UpdateCasts)
		else
			SerialSimulation.Connection =
				RS.Heartbeat:Connect(UpdateCasts)
		end
	end
end

function SerialSimulation.Stop()
	if SerialSimulation.Connection then
		SerialSimulation.Connection:Disconnect()
		SerialSimulation.Connection = nil
	end
	ActivesRef = nil
end

function SerialSimulation.GetEvent(name: string): any
	return FastCastEvents[name]
end

function SerialSimulation.QueueEvent(castID: number, eventType: string, ...: any)
	-- Public wrapper for external callers (e.g. init.luau TerminateCast)
	-- Map string event type to numeric constant
	local numericType: number
	if eventType == "CastTerminating" then
		numericType = EVT_CAST_TERMINATING
	elseif eventType == "Hit" then
		numericType = EVT_HIT
	elseif eventType == "Pierced" then
		numericType = EVT_PIERCED
	elseif eventType == "LengthChanged" then
		numericType = EVT_LENGTH_CHANGED
	else
		return
	end
	QueueEvent(castID, numericType, ...)
end

return SerialSimulation
