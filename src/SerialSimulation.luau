--[[
	- Author: Mawin CK
	- Date: 2026
]]

--!native
--!optimize 2

-- Services

local RS = game:GetService("RunService")

local TypeDef = require(script.Parent:WaitForChild("TypeDefinitions"))
local FastCastEnums = require(script.Parent:WaitForChild("FastCastEnums"))
local Config = require(script.Parent:WaitForChild("Config"))
local DebugLogging = Config.DebugLogging

-- Constants
local EnumCastTypes = FastCastEnums.CastType
local DEFAULT_MAX_DISTANCE = 1000
local FC_VIS_OBJ_NAME = "FastCastVisualizationObjects"

-- Variables

local casts_TotalRunTime = {} :: { [number]: number }
local casts_DistanceCovered = {} :: { [number]: number }
local casts_HighFidelitySegmentSize = {} :: { [number]: number }
local casts_HighFidelityBehavior = {} :: { [number]: number }
local casts_IsActivelySimulatingPierce = {} :: { [number]: boolean }
local casts_IsActivelyResimulating = {} :: { [number]: boolean }
local casts_CancelHighResCast = {} :: { [number]: boolean }
local casts_Trajectory = {} :: { [number]: TypeDef.CastTrajectory }
local casts_FastCastEventsConfig = {} :: { [number]: TypeDef.FastCastEventsConfig }
local casts_VisualizeCasts = {} :: { [number]: boolean }
local casts_VisualizeCastSettings = {} :: { [number]: TypeDef.VisualizeCastSettings }
local casts_RayInfo = {} :: { [number]: TypeDef.CastRayInfo }
local casts_UserData = {} :: { [number]: any }
local casts_CFrame = {} :: { [number]: CFrame }
local casts_CastType = {} :: { [number]: number }
local casts_CastVariant = {} :: { [number]: CastVariants }
local casts_MaxDistance = {} :: { [number]: number }
local casts_ActiveMotor6Ds = {} :: { [number]: Motor6D }
local casts_RayDisplacement = {} :: { [number]: number }

-- Types

type BlockcastVariant = { CastType: number, Size: Vector3 }
type SpherecastVariant = { CastType: number, Radius: number }
type CastVariants = BlockcastVariant | SpherecastVariant


type RayVisualizerVariant = { castLength: number}
type BlockVisualizerVariant = { size: Vector3 }
type SphereVisualizerVariant = { radius: number }
type CastVisualizerVariants = RayVisualizerVariant | BlockVisualizerVariant | SphereVisualizerVariant

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

-- queued things

local queuedEvents: { [number]: { QueuedEventData } } = {}
local queuedVisualizes: { [number]: { QueuedVisualizeCastData | QueuedVisualizeHitData }} = {}

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

local function DebrisAdd(obj: Instance, Lifetime: number)
	if not obj then
		return
	end
	if Lifetime <= 0 then
		obj:Destroy()
		return
	end

	task.delay(Lifetime, function()
		obj:Destroy()
	end)
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
	VisualizeCastSettings: TypeDef.VisualizeCastSettings,
	variant: RayVisualizerVariant
): ConeHandleAdornment?
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
	VisualizeCastSetting: TypeDef.VisualizeCastSettings,
	variant: BlockVisualizerVariant
): BoxHandleAdornment?
	local adornment = Instance.new("BoxHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = castStartCFrame
	--adornment.Height = castLength

	adornment.Size = variant.size
	adornment.Color3 = VisualizeCastSetting.Debug_SegmentColor
	adornment.Transparency = VisualizeCastSetting.Debug_SegmentTransparency

	adornment.Parent = GetFastCastVisualizationContainer()

	DebrisAdd(adornment, VisualizeCastSetting.Debug_RayLifetime)
	return adornment
end

local function DbgVisualizeSphereSegment(
	castStartCFrame: CFrame,
	VisualizeCastSetting: TypeDef.VisualizeCastSettings,
	variant: SphereVisualizerVariant
): SphereHandleAdornment?
	local adornment = Instance.new("SphereHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = castStartCFrame
	--adornment.Height = castLength
	adornment.Radius = variant.radius
	--adornment.Size = Vector3.new(size.X, size.Y, size.Z + castLength)
	adornment.Color3 = VisualizeCastSetting.Debug_SegmentColor
	adornment.Transparency = VisualizeCastSetting.Debug_SegmentTransparency

	adornment.Parent = GetFastCastVisualizationContainer()

	DebrisAdd(adornment, VisualizeCastSetting.Debug_RayLifetime)
	return adornment
end

local function DbgVisualizeHit(
	atCF: CFrame,
	wasPierce: boolean,
	VisualizeCastSettings: TypeDef.VisualizeCastSettings
): SphereHandleAdornment?
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

local Visualizers = {
	[EnumCastTypes.Raycast] = DbgVisualizeRaySegment,
	[EnumCastTypes.Blockcast] = DbgVisualizeBlockSegment,
	[EnumCastTypes.Spherecast] = DbgVisualizeSphereSegment
}

-- SerialSimulation

local SerialSimulation = {}
SerialSimulation.__index = SerialSimulation
SerialSimulation.__type = "SerialSimulation"

function SerialSimulation:Register(cast: any)
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
	casts_CastType[id] = cast.CastVariant.CastType
	casts_CastVariant[id] = cast.CastVariant
	casts_MaxDistance[id] = cast.RayInfo.MaxDistance or DEFAULT_MAX_DISTANCE
	table.insert(self.casts_ID, id)
	self.casts_ID_Index[id] = #self.casts_ID

	local position = GetPositionAtTime(
		casts_TotalRunTime[id],
		casts_Trajectory[id].Origin,
		casts_Trajectory[id].InitialVelocity,
		casts_Trajectory[id].Acceleration
	)
	casts_CFrame[id] = CFrame.new(position)

	cast.CFrame = casts_CFrame[id]

	if self.CurrentMovementMode == "Motor6D" and self.MovementEnabled then
		local cosmeticPart = casts_RayInfo[id] and casts_RayInfo[id].CosmeticBulletObject
		if cosmeticPart and self.BaseCastRef and self.BaseCastRef._GetMotor6D then
			local motor6d = self.BaseCastRef:_GetMotor6D(cosmeticPart)
			casts_ActiveMotor6Ds[id] = motor6d
		end
	end

	queuedEvents[id] = {}
end

function SerialSimulation:Unregister(castID: number)
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
	casts_RayDisplacement[castID] = nil

	if casts_ActiveMotor6Ds[castID] then
		if self.BaseCastRef and self.BaseCastRef._ReturnMotor6D then
			self.BaseCastRef:_ReturnMotor6D(casts_ActiveMotor6Ds[castID])
		end
		casts_ActiveMotor6Ds[castID] = nil
	end

	local idx = self.casts_ID_Index[castID]
	if idx then
		local lastID = self.casts_ID[#self.casts_ID]
		self.casts_ID[idx] = lastID
		self.casts_ID_Index[lastID] = idx
		self.casts_ID[#self.casts_ID] = nil
		self.casts_ID_Index[castID] = nil
	end

	queuedEvents[castID] = nil
	queuedVisualizes[castID] = nil
end

function SerialSimulation:SetMovementModeEnabled(enabled: boolean, mode: "BulkMoveTo" | "Motor6D")
	local oldMode = self.CurrentMovementMode
	self.CurrentMovementMode = mode
	self.MovementEnabled = enabled

	if oldMode == "Motor6D" and mode ~= "Motor6D" then
		for id, motor6d in casts_ActiveMotor6Ds do
			if self.BaseCastRef and self.BaseCastRef._ReturnMotor6D then
				self.BaseCastRef:_ReturnMotor6D(motor6d)
			end
			casts_ActiveMotor6Ds[id] = nil
		end
	end

	if mode == "Motor6D" and enabled and oldMode ~= "Motor6D" then
		for _, id in self.casts_ID do
			if not casts_ActiveMotor6Ds[id] then
				local cosmeticPart = casts_RayInfo[id] and casts_RayInfo[id].CosmeticBulletObject
				if cosmeticPart and self.BaseCastRef and self.BaseCastRef._GetMotor6D then
					local motor6d = self.BaseCastRef:_GetMotor6D(cosmeticPart)
					casts_ActiveMotor6Ds[id] = motor6d
				end
			end
		end
	end
end

function SerialSimulation:QueueVisualize(castID: number, visualizeData: QueuedVisualizeCastData | QueuedVisualizeHitData)
	if not casts_VisualizeCasts[castID] then
		return
	end

	if not queuedVisualizes[castID] then
		queuedVisualizes[castID] = {}
	end

	table.insert(queuedVisualizes[castID], visualizeData)
end

function SerialSimulation:FireQueuedVisualizes(unFiredVisualizes: { [number]: { QueuedVisualizeCastData | QueuedVisualizeHitData }})
	local sortedIDs = {}
	for id in unFiredVisualizes do
		table.insert(sortedIDs, id)
	end
	table.sort(sortedIDs)
	
	for _, castID in sortedIDs do
		local visualizesList = unFiredVisualizes[castID]
		if not visualizesList or not next(visualizesList) then
			continue
		end

		for _, visualizeData in visualizesList do
			-- VisualizeHit
			if visualizeData.atCF then
				if DebugLogging.Hit and not visualizeData.wasPierce and not visualizeData.sub then
					print("Hit was successful. Terminating.")
				end
				if DebugLogging.Pierced and visualizeData.wasPierce and not visualizeData.sub then
					print("Piercing function returned TRUE to pierce this part.")
				end
				DbgVisualizeHit(visualizeData.atCF, visualizeData.wasPierce, casts_VisualizeCastSettings[castID])
				continue
			end
			-- VisualizeCasts
			if DebugLogging.Segment and visualizeData.sub then
				print("Subcast visualization")
			end
			local castType = casts_CastType[castID]
			local castVisualizer = Visualizers[castType]
			if not castVisualizer then
				continue
			end
			local visualizerVariant: CastVisualizerVariants
			if castType == EnumCastTypes.Raycast then
				visualizerVariant = { castLength = casts_RayDisplacement[castID] or 1 }
			elseif castType == EnumCastTypes.Blockcast then
				visualizerVariant = { size = (casts_CastVariant[castID] :: BlockcastVariant).Size }
			else
				visualizerVariant = { radius = (casts_CastVariant[castID] :: SpherecastVariant).Radius }
			end
			castVisualizer(visualizeData.castStartCFrame, casts_VisualizeCastSettings[castID], visualizerVariant)
		end
	end
end

function SerialSimulation:QueueEvent(castID: number, eventType: string, ...: any)
	local args = { ... }
	if not queuedEvents[castID] then
		queuedEvents[castID] = {}
	end
	table.insert(queuedEvents[castID], {
		eventType = eventType,
		args = args
	})
end

function SerialSimulation:FireQueuedEvents(unFiredEvents: { [number]: { QueuedEventData } })
	local sortedIDs = {}
	for id in unFiredEvents do
		table.insert(sortedIDs, id)
	end
	table.sort(sortedIDs)

	local eventsFunction = self.Events

	for _, castID in sortedIDs do
		local eventList = unFiredEvents[castID]
		if not eventList or not next(eventList) then
			continue
		end

		for _, event in eventList do
			local cast = self.ActivesRef[castID]
			if not cast then
				continue
			end

			local eventType: string = event.eventType
			local args: { any } = event.args

			local eventConfig = casts_FastCastEventsConfig[castID]

			if eventType == "LengthChanged" then
				local lastPoint = args[1]
				local rayDir = args[2]
				local rayDisplacement = args[3]

				if eventConfig and eventConfig.UseLengthChanged and eventsFunction.LengthChanged then
					eventsFunction.LengthChanged(cast, lastPoint, rayDir, rayDisplacement)
				end

			elseif eventType == "Hit" then
				local result = args[1]
				local velocity = args[2]
				local cosmeticBulletObject = args[3]

				if eventConfig and eventConfig.UseHit and eventsFunction.Hit then
					eventsFunction.Hit(cast, result, velocity, cosmeticBulletObject)
				end

			elseif eventType == "Pierced" then
				local result = args[1]
				local velocity = args[2]
				local cosmeticBulletObject = args[3]

				if eventConfig and eventConfig.UsePierced and eventsFunction.Pierced then
					eventsFunction.Pierced(cast, result, velocity, cosmeticBulletObject)
				end

			elseif eventType == "CastTerminating" then
				self.BaseCastRef:_TerminateCast(castID, eventsFunction.CastTerminating)
				self:Unregister(castID)
			end
		end
	end
end

function SerialSimulation:BulkMoveTo()
	if self.CurrentMovementMode ~= "BulkMoveTo" or not self.MovementEnabled then
		return
	end

	local parts = table.create(#self.casts_ID)
	local cframes = table.create(#self.casts_ID)

	for _, id in self.casts_ID do
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

function SerialSimulation:UpdateMotor6Ds()
	if self.CurrentMovementMode ~= "Motor6D" or not self.MovementEnabled then
		return
	end

	for id, motor6d in casts_ActiveMotor6Ds do
		if motor6d and motor6d.Parent then
			motor6d.Transform = casts_CFrame[id]
		end
	end
end

-- RS
function SerialSimulation:SimulateCast(
	id: number,
	delta: number,
	CanPiercefn: TypeDef.CanPierceFunction?
)
	if DebugLogging.Casting then
		print("Casting for frame - SimulateCast")
	end
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

	local rayDir = totalDisplacement

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
	casts_RayDisplacement[id] = rayDisplacement

	casts_CFrame[id] = (if rayDir ~= Vector3.new() then CFrame.new(lastPoint, lastPoint + rayDir) else CFrame.new(lastPoint)) * CFrame.new(0, 0, -rayDisplacement / 2)

	self:QueueEvent(id, "LengthChanged", lastPoint, rayDir.Unit, rayDisplacement)

	casts_DistanceCovered[id] += rayDisplacement

	if delta > 0 then
		self:QueueVisualize(
			id,
			{
				castStartCFrame = CFrame.new(lastPoint, lastPoint+rayDir),
				sub = false
			} :: any
		)
	end

	-- NOTE: Please dont remove "part and"
	-- Why? basically when part doesn't exist it will do nothing, but removing "part and" will break the logic
	-- You can't do anything about it
	if part and part ~= casts_RayInfo[id].CosmeticBulletObject then
		if 
			CanPiercefn == nil
			or CanPiercefn(self.ActivesRef[id], resultOfCast, segmentVelocity, casts_RayInfo[id].CosmeticBulletObject) == false
		then

			casts_IsActivelyResimulating[id] = false

			if 
				casts_HighFidelityBehavior[id] == FastCastEnums.HighFidelityBehavior.Automatic
				and casts_HighFidelitySegmentSize[id] > 0 
			then
				casts_CancelHighResCast[id] = false

				if casts_IsActivelyResimulating[id] then
					self:QueueEvent(id, "CastTerminating")

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
				local subHitFound = false

				for segmentIndex = 1, numSegmentsReal do
					if casts_CancelHighResCast[id] then
						casts_CancelHighResCast[id] = false
						break
					end

					local subPosition = GetPositionAtTime(
						lastDelta + (timeIncrement * segmentIndex),
						origin, 
						initialVelocity, 
						acceleration
					)
					local subVelocity = GetVelocityAtTime(
						lastDelta + (timeIncrement * segmentIndex),
						initialVelocity, 
						acceleration
					)
					local subRayDir = subVelocity * timeIncrement
					local subResult = castHandler(
						targetWorldRoot,
						subPosition,
						subRayDir,
						casts_RayInfo[id].Parameters,
						casts_CastVariant[id]
					)

					--local subDisplacement = (subPosition - (subPosition + subVelocity)).Magnitude

					if subResult ~= nil then
						subHitFound = true

						self:QueueVisualize(id, {
							castStartCFrame = CFrame.new(subPosition, subPosition + subVelocity),
							sub = true
						} :: any)

						--subDispalcement = (subPosition - subResult.Position).Magnitude

						if 
							CanPiercefn == nil
							or CanPiercefn(self.ActivesRef[id], subResult, subVelocity, casts_RayInfo[id].CosmeticBulletObject) == false
						then
							casts_IsActivelyResimulating[id] = false
							self:QueueEvent(id, "Hit", subResult, subVelocity, casts_RayInfo[id].CosmeticBulletObject)
							self:QueueEvent(id, "CastTerminating")
							self:QueueVisualize(id, {
								atCF = CFrame.new(subResult.Position),
								wasPierce = false,
								sub = true
							}:: any)

							return
						else
							self:QueueEvent(id, "Pierced", subResult, subVelocity, casts_RayInfo[id].CosmeticBulletObject)
							self:QueueVisualize(id, {
								atCF = CFrame.new(subResult.Position),
								wasPierce = true,
								sub = true
							}:: any)
						end
					else
						self:QueueVisualize(id, {
							castStartCFrame = CFrame.new(subPosition, subPosition+subVelocity),
							sub = true
						}:: any)
					end
				end
				casts_IsActivelyResimulating[id] = false
				if not subHitFound then
					self:QueueEvent(id, "Hit", resultOfCast, segmentVelocity, casts_RayInfo[id].CosmeticBulletObject)
					self:QueueVisualize(id, {
						atCF = CFrame.new(point),
						sub = false,
						wasPierce = false
					}:: any)
					self:QueueEvent(id, "CastTerminating")
					return
				end
			else
				self:QueueEvent(id, "Hit", resultOfCast, segmentVelocity, casts_RayInfo[id].CosmeticBulletObject)
				self:QueueVisualize(id, {
					atCF = CFrame.new(point),
					sub = false,
					wasPierce = false
				}:: any)
				self:QueueEvent(id, "CastTerminating")

				return
			end
		else
			self:QueueEvent(id, "Pierced", resultOfCast, segmentVelocity, casts_RayInfo[id].CosmeticBulletObject)
			self:QueueVisualize(id, {
				atCF = CFrame.new(point),
				sub = false,
				wasPierce = true
			}:: any)
		end
	end

	if casts_DistanceCovered[id] >= casts_MaxDistance[id] then
		if resultOfCast then
			self:QueueEvent(id, "Hit", resultOfCast, segmentVelocity, casts_RayInfo[id].CosmeticBulletObject)
			self:QueueVisualize(id, {
				atCF = CFrame.new(point),
				sub = false,
				wasPierce = false
			}:: any)
		end
		self:QueueEvent(id, "CastTerminating")
	end
end

function SerialSimulation:UpdateCasts(delta: number)
	for _, id in self.casts_ID do
		if DebugLogging.Casting then
			print("Casting for frame - UpdateCasts")
		end

		if self.ActivesRef[id] and self.ActivesRef[id]._Destroying then
			continue
		end

		local Trajectory: TypeDef.CastTrajectory = casts_Trajectory[id]

		if casts_HighFidelitySegmentSize[id] <= 0 then
			casts_HighFidelitySegmentSize[id] = 0.1
		end

		if casts_HighFidelityBehavior[id] == FastCastEnums.HighFidelityBehavior.Always then

			if casts_IsActivelyResimulating[id] then
				self:QueueEvent(id, "CastTerminating")
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

			local timeIncrement = delta / numSegmentsReal

			if DebugLogging.Calculation then
				print("Performing subcast! Time increment: " .. timeIncrement .. ", num segments: " .. numSegmentsReal)
			end

			local cast_nil = false
			for segmentIndex = 1, numSegmentsReal do

				-- In case when cast Destroyed or not exist
				if self.ActivesRef[id] == nil then
					cast_nil = true
				end


				if casts_CancelHighResCast[id] then
					casts_CancelHighResCast[id] = false
					break
				end

				if DebugLogging.Segment then
					print("[" .. segmentIndex .. "] Subcast of time increment " .. timeIncrement)
				end

				self:SimulateCast(id, timeIncrement, self.Events.CanPierce)
			end

			if cast_nil then
				casts_IsActivelyResimulating[id] = false
				continue
			end

			-- Double check again
			if self.ActivesRef[id] == nil then
				casts_IsActivelyResimulating[id] = false
				continue
			end
			casts_IsActivelyResimulating[id] = false
		else
			self:SimulateCast(id, delta, self.Events.CanPierce)
		end
	end

	-- Write-back SoA -> ActiveCast so ActivesRef[id] has current values
	for _, id in self.casts_ID do
		local cast = self.ActivesRef[id]
		if cast then
			cast.StateInfo.TotalRuntime = casts_TotalRunTime[id]
			cast.StateInfo.DistanceCovered = casts_DistanceCovered[id]
			cast.CFrame = casts_CFrame[id]
		end
	end

	-- Motor6D, BulkMoveTo, FireQueuedVisualizes, FireQueuedEvents
	-- NOTE: Do not change these if you don't knows how it works

	self:UpdateMotor6Ds()
	self:BulkMoveTo()

	local eventsToProcess = queuedEvents
	queuedEvents = {}
	local visualizesToProcess = queuedVisualizes
	queuedVisualizes = {}

	self:FireQueuedVisualizes(visualizesToProcess)
	self:FireQueuedEvents(eventsToProcess)
end

function SerialSimulation.new()
    local self = setmetatable({}, SerialSimulation)
    self.Connection = nil
	self.CurrentMovementMode = "BulkMoveTo"
	self.MovementEnabled = true
	self.Events = {}
	self.BaseCastRef = nil
	self.ActivesRef = nil
	self.casts_ID = {}
	self.casts_ID_Index = {}
	return self
end

function SerialSimulation:Init(baseCastRef: any, events: TypeDef.FastCastEvents)
	self.BaseCastRef = baseCastRef
	self.ActivesRef = baseCastRef.Actives
	self.Events = events
end

function SerialSimulation:Start()
	if self.Connection then 
		warn("Already started")
		return
	end

	if RS:IsClient() then
		self.Connection = RS.PreSimulation:Connect(function(delta: number)
			self:UpdateCasts(delta)
		end)
	else
		self.Connection = RS.Heartbeat:Connect(function(delta: number)
			self:UpdateCasts(delta)
		end)
	end
end

function SerialSimulation:Stop()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

-- Utils
function SerialSimulation:_UpdateEvents(eventName: string, newEventfn: (...any) -> ())
	self.Events[eventName] = newEventfn
end

return SerialSimulation