--[[
	- Author: Mawin CK
	- Date: 2026
]]

--!native
--!optimize 2

local RS = game:GetService("RunService")

local FastCastModule = script.Parent

local TypeDef = require(FastCastModule:WaitForChild("TypeDefinitions"))
local Config = require(FastCastModule:WaitForChild("Config"))
local ActiveCast = require(FastCastModule:WaitForChild("ActiveCast"))
local Motor6DCache = require(FastCastModule:WaitForChild("Motor6DCache"))

local DebugLogging = Config.DebugLogging
local CAST_TYPE_RAYCAST = 1
local CAST_TYPE_BLOCKCAST = 2
local CAST_TYPE_SPHERECAST = 3

local HIGH_FIDELITY_BEHAVIOR_AUTOMATIC = 2
local HIGH_FIDELITY_BEHAVIOR_ALWAYS = 3

local DEFAULT_MAX_DISTANCE = 1000
local FC_VIS_OBJ_NAME = "FastCastVisualizationObjects"

local SerialSimulation = {}

-- ============================================================================
-- Types
-- ============================================================================

type RaycastVariant = {
	CastType: number
}

type BlockcastVariant = {
	CastType: number,
	Size: Vector3
}

type SpherecastVariant = {
	CastType: number,
	Radius: number
}

type CastVariants = RaycastVariant | BlockcastVariant | SpherecastVariant

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

local activeInstancedCasts: { any } = {}
local activeInstancelessCasts: { any } = {}
local Motor6DCacheInstance: any = nil

local CurrentMovementMode: "BulkMoveTo" | "Motor6D" = "BulkMoveTo"
local MovementEnabled = false

local queuedOnStep = {}
local dispatchOnStep = {}
local queuedLengthChanged = {}
local dispatchLengthChanged = {}
local queuedHit = {}
local dispatchHit = {}
local queuedPierced = {}
local dispatchPierced = {}
local queuedCastTerminating = {}
local dispatchCastTerminating = {}

local eventPool = {}

local queuedVisualizes: { QueuedVis } = {}
local queuedVisCount: number = 0

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
	[CAST_TYPE_RAYCAST] = function(
		worldRoot: WorldRoot,
		origin: Vector3,
		direction: Vector3,
		params: RaycastParams
	)
		return worldRoot:Raycast(origin, direction, params)
	end,

	[CAST_TYPE_BLOCKCAST] = function(
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

	[CAST_TYPE_SPHERECAST] = function(
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
	[CAST_TYPE_RAYCAST] = DbgVisualizeRaySegment,
	[CAST_TYPE_BLOCKCAST] = DbgVisualizeBlockSegment,
	[CAST_TYPE_SPHERECAST] = DbgVisualizeSphereSegment
}

-- ============================================================================
-- Visualization queues (pooled)
-- ============================================================================

local visPool: { QueuedVis } = {}
local visPoolCount = 0

local function GetVis(): QueuedVis
	visPoolCount += 1
	if visPoolCount > #visPool then
		visPool[visPoolCount] = { nil, nil, nil }
	end
	return visPool[visPoolCount]
end

local hitVisPool: { { any } } = {}
local hitVisPoolCount = 0
local segVisPool: { { any } } = {}
local segVisPoolCount = 0

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

local function ResetVisualPools()
	visPoolCount = 0
	hitVisPoolCount = 0
	segVisPoolCount = 0
end

local function QueueVisualizeHit(cast: any, atCF: CFrame, wasPierce: boolean, sub: boolean)
	if not cast.StateInfo.VisualizeCasts then
		return
	end

	local data = GetHitVisData()
	data[1] = atCF
	data[2] = wasPierce
	data[3] = sub

	queuedVisCount += 1
	local entry = GetVis()
	entry[1] = cast
	entry[2] = data
	entry[3] = 1
	queuedVisualizes[queuedVisCount] = entry
end

local function QueueVisualizeSegment(cast: any, castStartCFrame: CFrame, sub: boolean)
	if not cast.StateInfo.VisualizeCasts then
		return
	end

	local data = GetSegVisData()
	data[1] = castStartCFrame
	data[2] = sub

	queuedVisCount += 1
	local entry = GetVis()
	entry[1] = cast
	entry[2] = data
	entry[3] = 2
	queuedVisualizes[queuedVisCount] = entry
end

local reusableVariant = {} :: CastVisualizerVariants

local function FireQueuedVisualizes()
	for i = 1, queuedVisCount do
		local entry = queuedVisualizes[i]
		local cast = entry[1]
		local data = entry[2]
		local dataTag = entry[3]

		if not cast or not cast.StateInfo then
			entry[1] = nil
			entry[2] = nil
			entry[3] = nil
			continue
		end

		local settings = cast.StateInfo.VisualizeCastSettings
		if not settings then
			entry[1] = nil
			entry[2] = nil
			entry[3] = nil
			continue
		end

		if dataTag == 1 then
			local atCF = data[1] :: CFrame
			local wasPierce = data[2] :: boolean
			local sub = data[3] :: boolean

			if DebugLogging.Hit and not wasPierce and not sub then
				print("Hit was successful. Terminating.")
			end
			if DebugLogging.Pierced and wasPierce and not sub then
				print("Piercing function returned TRUE to pierce this part.")
			end

			DbgVisualizeHit(atCF, wasPierce, settings)
			entry[1] = nil
			entry[2] = nil
			entry[3] = nil
			continue
		end

		local castStartCFrame = data[1] :: CFrame
		local sub = data[2] :: boolean

		if DebugLogging.Segment and sub then
			print("Subcast visualization")
		end

		local castType = cast.CastVariant.CastType
		local visualizer = Visualizers[castType]
		if not visualizer then
			entry[1] = nil
			entry[2] = nil
			entry[3] = nil
			continue
		end

		if castType == CAST_TYPE_RAYCAST then
			reusableVariant.castLength = cast._RayDisplacement or 1
		elseif castType == CAST_TYPE_BLOCKCAST then
			reusableVariant.size = cast.CastVariant.Size
		else
			reusableVariant.radius = cast.CastVariant.Radius
		end

		visualizer(castStartCFrame, settings, reusableVariant)
		entry[1] = nil
		entry[2] = nil
		entry[3] = nil
	end
end

-- ============================================================================
-- Movement
-- ============================================================================

local bulkParts: { BasePart } = {}
local bulkCframes: { CFrame } = {}
local bulkCount = 0
local previousBulkCount = 0
local cosmeticFrame = 0

local function ShouldUpdateCosmetics(): boolean
	local interval = Config.CosmeticUpdateInterval or 1
	if interval <= 1 then return true end
	cosmeticFrame += 1
	return cosmeticFrame % interval == 0
end

local function GetCosmeticCFrame(cast: any): CFrame
	local baseCFrame = cast._SimulationCFrame
	local offset = cast.Offset
	if typeof(offset) == "CFrame" then
		return baseCFrame * offset
	end
	return baseCFrame
end

local function BulkMoveTo()
	if CurrentMovementMode ~= "BulkMoveTo" or not MovementEnabled then
		return
	end
	if #activeInstancedCasts > 0 and not ShouldUpdateCosmetics() then
		return
	end

	bulkCount = 0
	for _, cast in activeInstancedCasts do
		local cosmetic = cast.RayInfo.CosmeticBulletObject
		if cosmetic and cosmetic.Parent then
			bulkCount += 1
			bulkParts[bulkCount] = cosmetic
			bulkCframes[bulkCount] = GetCosmeticCFrame(cast)
		end
	end

	for i = bulkCount + 1, previousBulkCount do
		bulkParts[i] = nil
		bulkCframes[i] = nil
	end
	previousBulkCount = bulkCount
	if bulkCount > 0 then
		workspace:BulkMoveTo(bulkParts, bulkCframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function UpdateMotor6Ds()
	if CurrentMovementMode ~= "Motor6D" or not MovementEnabled then
		return
	end
	if not ShouldUpdateCosmetics() then
		return
	end

	for _, cast in activeInstancedCasts do
		local motor6d = cast._Motor6D
		if motor6d and motor6d.Parent then
			motor6d.Transform = GetCosmeticCFrame(cast)
		end
	end
end

-- ============================================================================
-- Simulation helpers
-- ============================================================================

local function QueueHit(cast: any, result: RaycastResult, velocity: Vector3, sub: boolean)
	local event = table.remove(eventPool)
	if not event then event = {} end
	event.cast = cast
	event.result = result
	event.velocity = velocity
	event.cosmetic = cast.RayInfo.CosmeticBulletObject
	table.insert(queuedHit, event)

	QueueVisualizeHit(cast, CFrame.new(result.Position), false, sub)

	local terminateEvent = table.remove(eventPool)
	if not terminateEvent then terminateEvent = {} end
	terminateEvent.cast = cast
	table.insert(queuedCastTerminating, terminateEvent)
end

local function QueuePierce(cast: any, result: RaycastResult, velocity: Vector3, sub: boolean)
	local event = table.remove(eventPool)
	if not event then event = {} end
	event.cast = cast
	event.result = result
	event.velocity = velocity
	event.cosmetic = cast.RayInfo.CosmeticBulletObject
	table.insert(queuedPierced, event)

	QueueVisualizeHit(cast, CFrame.new(result.Position), true, sub)
end

local function ShouldPierce(cast: any, result: RaycastResult, velocity: Vector3, canPierce: TypeDef.CanPierceFunction?): boolean
	if not canPierce or not cast.StateInfo then
		return false
	end
	local shouldPierce = canPierce(cast, result, velocity, cast.RayInfo.CosmeticBulletObject)
	return cast.StateInfo ~= nil and not cast._Destroying and shouldPierce
end

local function CastSegment(
	cast: any,
	pierceResults: { RaycastResult },
	origin: Vector3,
	displacement: Vector3,
	velocity: Vector3,
	worldRoot: WorldRoot,
	castHandler: any,
	canPierce: TypeDef.CanPierceFunction?
): (RaycastResult?, boolean, number)
	table.clear(pierceResults)
	local direction = if displacement.Magnitude > EPSILON then displacement.Unit else Vector3.zero
	local endpoint = origin + displacement + direction * RAY_SEARCH_OFFSET
	local rayOrigin = origin
	local lastResult: RaycastResult? = nil
	local rayInfo = cast.RayInfo
	local variant = cast.CastVariant

	for _ = 1, cast.StateInfo.MaxPiercesPerStep do
		local remainingDisplacement = endpoint - rayOrigin
		if remainingDisplacement.Magnitude <= EPSILON then break end

		local result = castHandler(worldRoot, rayOrigin, remainingDisplacement, rayInfo.Parameters, variant)
		if not result then
			return nil, false, #pierceResults
		end

		lastResult = result
		if result.Instance == rayInfo.CosmeticBulletObject then
			return result, false, #pierceResults
		end

		local shouldPierce = ShouldPierce(cast, result, velocity, canPierce)
		if not cast.StateInfo or cast._Destroying then
			return nil, false, #pierceResults
		end
		if not shouldPierce then
			return result, true, #pierceResults
		end

		table.insert(pierceResults, result)
		rayOrigin = result.Position + direction * RAY_SEARCH_OFFSET
	end
	return lastResult, false, #pierceResults
end

local function QueueSegmentPierces(cast: any, pierceResults: { RaycastResult }, velocity: Vector3, sub: boolean): number
	local pierceCount = #pierceResults
	for index = 1, pierceCount do
		QueuePierce(cast, pierceResults[index], velocity, sub)
	end
	return pierceCount
end

-- ============================================================================
-- Automatic high-fidelity resimulation
-- ============================================================================

local function ResimulateHit(
	cast: any,
	delta: number,
	lastDelta: number,
	origin: Vector3,
	initialVelocity: Vector3,
	acceleration: Vector3,
	targetWorldRoot: WorldRoot,
	castHandler: any,
	canPierce: TypeDef.CanPierceFunction?,
	fallbackResult: RaycastResult,
	fallbackVelocity: Vector3
): boolean

	cast.StateInfo.IsActivelyResimulating = true

	local rayDisplacement = cast._RayDisplacement

	local segmentCount = math.max(
		1,
		math.floor(
			rayDisplacement
				/ cast.StateInfo.HighFidelitySegmentSize
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
		if cast.StateInfo.CancelHighResCast then
			cast.StateInfo.CancelHighResCast = false
			break
		end

		local subTime = lastDelta + timeIncrement * segmentIndex

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

		local subResult, subDidHit, subPierceCount = CastSegment(
			cast,
			cast._ResimPierceResults,
			subOrigin,
			subDirection,
			subVelocity,
			targetWorldRoot,
			castHandler,
			canPierce
		)
		if not cast.StateInfo or cast._Destroying then
			if cast.StateInfo then
				cast.StateInfo.IsActivelyResimulating = false
			end
			return true
		end

		if cast.StateInfo.VisualizeCasts then
			QueueVisualizeSegment(
				cast,
				CFrame.new(
					subPosition,
					subPosition + subVelocity
				),
				true
			)
		end

		QueueSegmentPierces(cast, cast._ResimPierceResults, subVelocity, true)
		lastPierced = subPierceCount > 0

		if not subResult or not subDidHit then
			continue
		end

		cast.StateInfo.IsActivelyResimulating = false

		QueueHit(
			cast,
			subResult,
			subVelocity,
			true
		)

		return true
	end

	cast.StateInfo.IsActivelyResimulating = false

	-- The original cast hit, but none of the
	-- high-resolution subcasts did.
	QueueHit(
		cast,
		fallbackResult,
		fallbackVelocity,
		false
	)

	return true
end

-- ============================================================================
-- Single simulation step
-- ============================================================================

local function SimulateCast(
	cast: any,
	delta: number
): boolean
	if DebugLogging.Casting then
		print("Casting for frame - SimulateCast")
	end

	local trajectory = cast.StateInfo.Trajectory
	local rayInfo = cast.RayInfo
	local variant = cast.CastVariant

	local origin = trajectory.Origin
	local initialVelocity = trajectory.InitialVelocity
	local acceleration = trajectory.Acceleration

	local previousTime = cast.StateInfo.TotalRuntime - trajectory.StartTime

	local lastPoint = GetPositionAtTime(
		previousTime,
		origin,
		initialVelocity,
		acceleration
	)

	cast.StateInfo.TotalRuntime += delta

	local currentTime = cast.StateInfo.TotalRuntime - trajectory.StartTime

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

	-- Do not simulate beyond MaxDistance. Clamping the displacement before
	-- raycasting prevents a long frame from hitting something past the cast's
	-- allowed range.
	local remainingDistance = (cast.RayInfo.MaxDistance or DEFAULT_MAX_DISTANCE) - cast.StateInfo.DistanceCovered
	if remainingDistance <= 0 then
		do
			local event = table.remove(eventPool)
			if not event then event = {} end
			event.cast = cast
			table.insert(queuedCastTerminating, event)
		end
		return true
	end

	if displacementMagnitude > remainingDistance then
		displacement = displacement.Unit * remainingDistance
		displacementMagnitude = remainingDistance
	end

	if displacementMagnitude <= EPSILON then
		cast.StateInfo.DistanceCovered += displacementMagnitude
		return false
	end

	local worldRoot = rayInfo.WorldRoot
	local handler = castHandlers[variant.CastType]

	local canPiercefn = cast._Caster and cast._Caster.CanPierce
	
	local result, didHit = CastSegment(
		cast,
		cast._StepPierceResults,
		lastPoint,
		displacement,
		velocity,
		worldRoot,
		handler,
		canPiercefn
	)
	if not cast.StateInfo or cast._Destroying then
		return true
	end

	local rayDisplacement = if result
		then (result.Position - lastPoint).Magnitude
		else displacementMagnitude

	cast._RayDisplacement = rayDisplacement

	-- Build the midpoint transform directly instead of multiplying two
	-- CFrames. lookAlong avoids losing direction when origin + direction
	-- rounds back to origin at large world coordinates.
	local unitDirection = displacement / displacementMagnitude
	cast._SimulationCFrame = CFrame.lookAlong(
		lastPoint + unitDirection * (rayDisplacement * 0.5),
		unitDirection
	)

	-- Keep the public cast transform in sync with the transform used to move
	-- its cosmetic object. Offset is writable at runtime, so update this every
	-- simulation step rather than only when the cast is registered.
	if cast then
		cast.CFrame = cast._SimulationCFrame * cast.Offset
	end

	do
		local event = table.remove(eventPool)
		if not event then event = {} end
		event.cast = cast
		event.lastPoint = lastPoint
		event.unitDirection = unitDirection
		event.rayDisplacement = rayDisplacement
		event.velocity = velocity
		event.cosmetic = rayInfo.CosmeticBulletObject
		table.insert(queuedLengthChanged, event)
	end

	cast.StateInfo.DistanceCovered += rayDisplacement

	if delta > 0 and cast.StateInfo.VisualizeCasts then
		QueueVisualizeSegment(
			cast,
			CFrame.lookAlong(lastPoint, unitDirection),
			false
		)
	end

	-- Queue LengthChanged before this segment's Pierced/Hit events.
	if not result then
		QueueSegmentPierces(cast, cast._StepPierceResults, velocity, false)
		if cast.StateInfo.DistanceCovered >= (cast.RayInfo.MaxDistance or DEFAULT_MAX_DISTANCE) then
			do
			local event = table.remove(eventPool)
			if not event then event = {} end
			event.cast = cast
			table.insert(queuedCastTerminating, event)
		end
			return true
		end
		return false
	end

	if result.Instance == rayInfo.CosmeticBulletObject then
		QueueSegmentPierces(cast, cast._StepPierceResults, velocity, false)
		return false
	end

	if not didHit then
		QueueSegmentPierces(cast, cast._StepPierceResults, velocity, false)
		return false
	end

	-- ------------------------------------------------------------------------
	-- Hit.
	-- ------------------------------------------------------------------------

	if cast.StateInfo.HighFidelityBehavior
		== HIGH_FIDELITY_BEHAVIOR_AUTOMATIC
		and cast.StateInfo.HighFidelitySegmentSize > 0
	then
		if cast.StateInfo.IsActivelyResimulating then
			QueueSegmentPierces(cast, cast._StepPierceResults, velocity, false)
			do
				local event = table.remove(eventPool)
				if not event then event = {} end
				event.cast = cast
				table.insert(queuedCastTerminating, event)
			end

			warn(
				"Cascading cast lag encountered! "
					.. "The caster attempted to perform a high fidelity "
					.. "cast before the previous one completed. "
					.. "Consider increasing HighFidelitySegmentSize."
			)

			return true
		end

		local lastDelta = previousTime

		ResimulateHit(
			cast,
			delta,
			lastDelta,
			origin,
			initialVelocity,
			acceleration,
			worldRoot,
			handler,
			canPiercefn,
			result,
			velocity
		)

		return true
	end

	QueueSegmentPierces(cast, cast._StepPierceResults, velocity, false)
	QueueHit(
		cast,
		result,
		velocity,
		false
	)
	return true
end

-- ============================================================================
-- Always high-fidelity simulation
-- ============================================================================

local function SimulateAlwaysHighFidelity(
	cast: any,
	delta: number
)
	if cast.StateInfo.IsActivelyResimulating then
		do
			local event = table.remove(eventPool)
			if not event then event = {} end
			event.cast = cast
			table.insert(queuedCastTerminating, event)
		end

		warn(
			"Cascading cast lag encountered! "
				.. "The caster attempted to perform a high fidelity "
				.. "cast before the previous one completed. "
				.. "Consider increasing HighFidelitySegmentSize."
		)

		return
	end

	cast.StateInfo.IsActivelyResimulating = true

	local trajectory = cast.StateInfo.Trajectory
	local rayInfo = cast.RayInfo
	local variant = cast.CastVariant

	local origin = trajectory.Origin
	local initialVelocity = trajectory.InitialVelocity
	local acceleration = trajectory.Acceleration

	local currentTime = cast.StateInfo.TotalRuntime - trajectory.StartTime

	local lastPoint = GetPositionAtTime(
		currentTime,
		origin,
		initialVelocity,
		acceleration
	)

	-- Temporarily advance time to determine
	-- the approximate distance for this frame.
	cast.StateInfo.TotalRuntime += delta

	local nextTime = cast.StateInfo.TotalRuntime - trajectory.StartTime

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

	local direction = totalDisplacement.Unit * currentVelocity.Magnitude * delta

	local handler = castHandlers[variant.CastType]

	local resultOfCast = handler(
		rayInfo.WorldRoot,
		lastPoint,
		direction,
		rayInfo.Parameters,
		variant
	)

	local canPiercefn = cast._Caster and cast._Caster.CanPierce
	local canPierceEnabled = canPiercefn ~= nil
	
	local endpoint = (resultOfCast and resultOfCast.Position) or currentPoint

	local distance = (endpoint - lastPoint).Magnitude

	cast.StateInfo.TotalRuntime -= delta

	-- Ceiling guarantees each substep is no longer than the configured
	-- segment size; floor can leave long segments and undermine Always mode.
	local segmentCount = math.max(
		1,
		math.ceil(
			distance
				/ cast.StateInfo.HighFidelitySegmentSize
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

	local substepStopped = false
	for segmentIndex = 1, segmentCount do
		if cast.StateInfo.CancelHighResCast then
			cast.StateInfo.CancelHighResCast = false
			break
		end

		if not cast.StateInfo or cast._Destroying then
			if cast.StateInfo then
				cast.StateInfo.IsActivelyResimulating = false
			end
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

		-- Stop advancing the cast in this frame as soon as a substep hits
		-- something or reaches MaxDistance.
		local stopped = SimulateCast(cast, timeIncrement)

		if not cast.StateInfo or cast._Destroying then
			if cast.StateInfo then
				cast.StateInfo.IsActivelyResimulating = false
			end
			return
		end

		if stopped then
			substepStopped = true
			break
		end
	end

	cast.StateInfo.IsActivelyResimulating = false

	-- The coarse cast already saw a non-pierceable obstacle. Normally a
	-- refined substep reports it, but preserve that hit if rounding leaves
	-- every refined substep short of the surface.
	if resultOfCast and not substepStopped and not canPierceEnabled then
		QueueHit(cast, resultOfCast, currentVelocity, false)
	end
end

-- ============================================================================
-- Cast storage and lifecycle
-- ============================================================================

local function RegisterCast(cast: any)
	local state = cast.StateInfo
	local trajectory = state.Trajectory

	state.TotalRuntime = state.TotalRuntime or 0
	state.DistanceCovered = 0
	state.HighFidelitySegmentSize = state.HighFidelitySegmentSize or 0.1
	state.HighFidelityBehavior = state.HighFidelityBehavior or 0
	state.IsActivelySimulatingPierce = false
	state.IsActivelyResimulating = false
	state.CancelHighResCast = false

	cast._StepPierceResults = {}
	cast._ResimPierceResults = {}
	cast._RayDisplacement = 0
	cast._SimulationCFrame = CFrame.new(GetPositionAtTime(
		state.TotalRuntime,
		trajectory.Origin,
		trajectory.InitialVelocity,
		trajectory.Acceleration
	))

	local cosmetic = cast.RayInfo.CosmeticBulletObject
	local activeArray = if cosmetic then activeInstancedCasts else activeInstancelessCasts
	local index = #activeArray + 1
	activeArray[index] = cast
	cast._Index = index
	cast._ActiveArray = activeArray
	cast._Terminated = false
	cast.CFrame = cast._SimulationCFrame * cast.Offset

	if cosmetic and CurrentMovementMode == "Motor6D" and MovementEnabled and Motor6DCacheInstance then
		cast._Motor6D = Motor6DCacheInstance:Connect(cosmetic)
	end
end

local function UnregisterCast(cast: any)
	local activeArray = cast._ActiveArray
	if activeArray then
		local index = cast._Index
		local lastIndex = #activeArray
		if index ~= lastIndex then
			local lastCast = activeArray[lastIndex]
			activeArray[index] = lastCast
			lastCast._Index = index
		end
		activeArray[lastIndex] = nil
		cast._Index = nil
		cast._ActiveArray = nil
	end

	if cast._Motor6D and Motor6DCacheInstance then
		Motor6DCacheInstance:Disconnect(cast._Motor6D)
		cast._Motor6D = nil
	end
end

local function TerminateCastInternal(cast: any)
	if not cast or not cast.StateInfo or cast._Terminated then
		return
	end
	UnregisterCast(cast)
	cast._Terminated = true
	table.clear(cast)
end

local function SetMovementModeEnabled(enabled: boolean, mode: "BulkMoveTo" | "Motor6D")
	local oldMode = CurrentMovementMode
	CurrentMovementMode = mode
	MovementEnabled = enabled

	if oldMode == "Motor6D" and (mode ~= "Motor6D" or not enabled) then
		for _, cast in activeInstancedCasts do
			if cast._Motor6D and Motor6DCacheInstance then
				Motor6DCacheInstance:Disconnect(cast._Motor6D)
				cast._Motor6D = nil
			end
		end
		if Motor6DCacheInstance then
			Motor6DCacheInstance:Destroy()
			Motor6DCacheInstance = nil
		end
	end

	if mode == "Motor6D" and enabled then
		if not Motor6DCacheInstance then
			Motor6DCacheInstance = Motor6DCache.new()
		end
		for _, cast in activeInstancedCasts do
			if not cast._Motor6D then
				local cosmetic = cast.RayInfo.CosmeticBulletObject
				if cosmetic then
					cast._Motor6D = Motor6DCacheInstance:Connect(cosmetic)
				end
			end
		end
	end
end

local function UpdateCastArray(activeArray: { any }, delta: number)
	local index = 1
	while index <= #activeArray do
		local cast = activeArray[index]
		if not cast or not cast.StateInfo or cast._Destroying then
			index += 1
			continue
		end

		local state = cast.StateInfo
		local maxLifetime = state.MaxLifetime
		if maxLifetime ~= nil and state.TotalRuntime >= maxLifetime then
			if not cast._TerminationQueued then
				cast._Destroying = true
				cast._TerminationQueued = true
				local event = table.remove(eventPool)
				if not event then event = {} end
				event.cast = cast
				table.insert(queuedCastTerminating, event)
			end
			index += 1
			continue
		end

		if state.IsPaused then
			index += 1
			continue
		end

		if state.HighFidelitySegmentSize <= 0 then
			state.HighFidelitySegmentSize = 0.1
		end

		local trajectory = state.Trajectory
		cast.PreviousPosition = GetPositionAtTime(
			state.TotalRuntime - trajectory.StartTime,
			trajectory.Origin,
			trajectory.InitialVelocity,
			trajectory.Acceleration
		)

		if state.HighFidelityBehavior == HIGH_FIDELITY_BEHAVIOR_ALWAYS then
			SimulateAlwaysHighFidelity(cast, delta)
		else
			SimulateCast(cast, delta)
		end

		if cast.StateInfo and not cast._Destroying then
			cast.CFrame = GetCosmeticCFrame(cast)
		end

		if activeArray[index] == cast then
			index += 1
		end
	end
end

-- ============================================================================
-- Main update
-- ============================================================================

local function QueueOnStepFor(activeArray: { any }, delta: number)
	for _, cast in activeArray do
		local state = cast.StateInfo
		local maxLifetime = state and state.MaxLifetime
		if state
			and not cast._Destroying
			and not state.IsPaused
			and (maxLifetime == nil or state.TotalRuntime < maxLifetime)
			and state.Trajectory
		then
			local event = table.remove(eventPool)
			if not event then event = {} end
			event.cast = cast
			event.delta = delta
			table.insert(queuedOnStep, event)
		end
	end
end

local function UpdateCasts(delta: number)
	QueueOnStepFor(activeInstancedCasts, delta)
	QueueOnStepFor(activeInstancelessCasts, delta)

	local eventsToProcess = queuedOnStep
	queuedOnStep = dispatchOnStep
	dispatchOnStep = eventsToProcess
	table.clear(queuedOnStep)

	for i = 1, #eventsToProcess do
		local event = eventsToProcess[i]
		local cast = event.cast
		if cast and cast.StateInfo then
			local signal = cast._CasterEvents and cast._CasterEvents.OnStep
			if signal and signal:HasListeners() then
				signal:Fire(cast, event.delta)
			end
		end
		table.clear(event)
		eventsToProcess[i] = nil
		table.insert(eventPool, event)
	end
	table.clear(eventsToProcess)

	UpdateCastArray(activeInstancedCasts, delta)
	UpdateCastArray(activeInstancelessCasts, delta)
	UpdateMotor6Ds()
	BulkMoveTo()
	FireQueuedVisualizes()

	local lengthEvents = queuedLengthChanged
	queuedLengthChanged = dispatchLengthChanged
	dispatchLengthChanged = lengthEvents
	table.clear(queuedLengthChanged)
	for i = 1, #lengthEvents do
		local event = lengthEvents[i]
		local cast = event.cast
		if cast and cast.StateInfo then
			local signal = cast._CasterEvents and cast._CasterEvents.LengthChanged
			if signal and signal:HasListeners() then
				signal:Fire(cast, event.lastPoint, event.unitDirection, event.rayDisplacement, event.velocity, event.cosmetic)
			end
		end
		table.clear(event)
		lengthEvents[i] = nil
		table.insert(eventPool, event)
	end
	table.clear(lengthEvents)

	local hitEvents = queuedHit
	queuedHit = dispatchHit
	dispatchHit = hitEvents
	table.clear(queuedHit)
	for i = 1, #hitEvents do
		local event = hitEvents[i]
		local cast = event.cast
		if cast and cast.StateInfo then
			local signal = cast._CasterEvents and cast._CasterEvents.Hit
			if signal and signal:HasListeners() then
				signal:Fire(cast, event.result, event.velocity, event.cosmetic)
			end
		end
		table.clear(event)
		hitEvents[i] = nil
		table.insert(eventPool, event)
	end
	table.clear(hitEvents)

	local piercedEvents = queuedPierced
	queuedPierced = dispatchPierced
	dispatchPierced = piercedEvents
	table.clear(queuedPierced)
	for i = 1, #piercedEvents do
		local event = piercedEvents[i]
		local cast = event.cast
		if cast and cast.StateInfo then
			local signal = cast._CasterEvents and cast._CasterEvents.Pierced
			if signal and signal:HasListeners() then
				signal:Fire(cast, event.result, event.velocity, event.cosmetic)
			end
		end
		table.clear(event)
		piercedEvents[i] = nil
		table.insert(eventPool, event)
	end
	table.clear(piercedEvents)

	local terminatingEvents = queuedCastTerminating
	queuedCastTerminating = dispatchCastTerminating
	dispatchCastTerminating = terminatingEvents
	table.clear(queuedCastTerminating)
	for i = 1, #terminatingEvents do
		local event = terminatingEvents[i]
		local cast = event.cast
		if cast and cast.StateInfo then
			cast._Destroying = true
			cast._TerminationQueued = false
			local signal = cast._CasterEvents and cast._CasterEvents.CastTerminating
			if signal and signal:HasListeners() then
				signal:Fire(cast)
			end
			TerminateCastInternal(cast)
		end
		table.clear(event)
		terminatingEvents[i] = nil
		table.insert(eventPool, event)
	end
	table.clear(terminatingEvents)

	ResetVisualPools()
	queuedVisCount = 0
end

-- ============================================================================
-- Public API
-- ============================================================================

SerialSimulation.Connection = nil :: RBXScriptConnection?

local function FireCastFire(caster: any, cast: any, origin: Vector3, direction: Vector3, velocity: Vector3 | number, behavior: TypeDef.FastCastBehavior)
	local events = caster._events
	local signal = events and events.CastFire
	if signal and signal:HasListeners() then
		signal:Fire(cast, origin, direction, velocity, behavior)
	end
end

function SerialSimulation.Raycast(caster: any, origin: Vector3, direction: Vector3, velocity: Vector3 | number, behavior: TypeDef.FastCastBehavior)
	local cast = ActiveCast.createCastData(SerialSimulation, origin, direction, velocity, behavior, { CastType = CAST_TYPE_RAYCAST } :: any)
	cast.CasterId = caster.CasterId
	cast._Caster = caster
	cast._CasterEvents = caster._events
	RegisterCast(cast)
	FireCastFire(caster, cast, origin, direction, velocity, behavior)
	return cast
end

function SerialSimulation.Blockcast(caster: any, origin: Vector3, size: Vector3, direction: Vector3, velocity: Vector3 | number, behavior: TypeDef.FastCastBehavior)
	local cast = ActiveCast.createCastData(SerialSimulation, origin, direction, velocity, behavior, { CastType = CAST_TYPE_BLOCKCAST, Size = size } :: any)
	cast.CasterId = caster.CasterId
	cast._Caster = caster
	cast._CasterEvents = caster._events
	RegisterCast(cast)
	FireCastFire(caster, cast, origin, direction, velocity, behavior)
	return cast
end

function SerialSimulation.Spherecast(caster: any, origin: Vector3, radius: number, direction: Vector3, velocity: Vector3 | number, behavior: TypeDef.FastCastBehavior)
	local cast = ActiveCast.createCastData(SerialSimulation, origin, direction, velocity, behavior, { CastType = CAST_TYPE_SPHERECAST, Radius = radius } :: any)
	cast.CasterId = caster.CasterId
	cast._Caster = caster
	cast._CasterEvents = caster._events
	RegisterCast(cast)
	FireCastFire(caster, cast, origin, direction, velocity, behavior)
	return cast
end

function SerialSimulation.DestroyCaster(caster: any)
	local index = 1
	while index <= #activeInstancedCasts do
		local cast = activeInstancedCasts[index]
		if cast._Caster == caster then
			TerminateCastInternal(cast)
		else
			index += 1
		end
	end
	index = 1
	while index <= #activeInstancelessCasts do
		local cast = activeInstancelessCasts[index]
		if cast._Caster == caster then
			TerminateCastInternal(cast)
		else
			index += 1
		end
	end
end

function SerialSimulation.QueueTerminate(cast: any)
	if not cast or not cast.StateInfo or cast._Destroying or cast._TerminationQueued then
		return
	end
	cast._Destroying = true
	cast._TerminationQueued = true
	local event = table.remove(eventPool)
	if not event then event = {} end
	event.cast = cast
	table.insert(queuedCastTerminating, event)
end

function SerialSimulation.CancelHighResResimulation(cast: any)
	if cast and cast.StateInfo and cast.StateInfo.IsActivelyResimulating then
		cast.StateInfo.CancelHighResCast = true
	end
end

function SerialSimulation.SetMovementModeEnabled(enabled: boolean, mode: "BulkMoveTo" | "Motor6D")
	SetMovementModeEnabled(enabled, mode)
end

function SerialSimulation.Init(movementMode: ("BulkMoveTo" | "Motor6D")?)
	if SerialSimulation.Connection then
		warn("[FastCast2] SerialSimulation already initialized. Skipping.")
		return
	end
	SetMovementModeEnabled(true, movementMode or "BulkMoveTo")
	SerialSimulation.Start()
end

function SerialSimulation.Start()
	if SerialSimulation.Connection then
		return
	end
	if Config.SimulationMode == "Fixed" then
		SerialSimulation.Connection = RS:BindToSimulation(function(dt)
			UpdateCasts(dt)
		end, Config.FixedSimulationFrequency)
	else
		if RS:IsClient() then
			SerialSimulation.Connection = RS.PreSimulation:Connect(UpdateCasts)
		else
			SerialSimulation.Connection = RS.Heartbeat:Connect(UpdateCasts)
		end
	end
end

function SerialSimulation.Stop()
	if SerialSimulation.Connection then
		SerialSimulation.Connection:Disconnect()
		SerialSimulation.Connection = nil
	end
end

return SerialSimulation
