--[[
	- Author : Mawin CK
	- Date : 2025
	

	ParallelSimulation - SoA pattern for Parallel mode
	Each Actor has its own instance of this for parallel processing
]]

local RS = game:GetService("RunService")

local FastCastModule = script.Parent
local TypeDef = require(FastCastModule:WaitForChild("TypeDefinitions"))
local Configs = require(FastCastModule:WaitForChild("Configs"))
local DebugLogging = Configs.DebugLogging
local FastCastEnums = require(FastCastModule:WaitForChild("FastCastEnums"))
local Configs = require(FastCastModule:WaitForChild("Configs"))
local DebugLogging = Configs.DebugLogging
local Motor6DPool = require(FastCastModule:WaitForChild("Motor6DPool"))

local EnumCastTypes = FastCastEnums.CastType
local HighFidelityBehavior = FastCastEnums.HighFidelityBehavior
local HIGH_FIDE_INCREASE_SIZE = 0.5
local MAX_SEGMENT_CAL_TIME = 0.016 * 5
local MAX_CASTING_TIME = 0.2
local DEFAULT_MAX_DISTANCE = 1000
local EPSILON = 1e-6
local RAY_SEARCH_OFFSET = 0.001

local DBG_SEGMENT_SUB_COLOR = Color3.new(0.286275, 0.329412, 0.247059)
local DBG_SEGMENT_SUB_COLOR2 = Color3.new(0.454902, 0.933333, 0.011765)
local DBG_HIT_SUB_COLOR = Color3.new(0.0588235, 0.87451, 1)
local DBG_RAYPIERCE_SUB_COLOR = Color3.new(1, 0.113725, 0.588235)

local FC_VIS_OBJ_NAME = "FastCastVisualizationObjects"

local function GetVisualizationContainer(): Instance
	local container = workspace.Terrain:FindFirstChild(FC_VIS_OBJ_NAME)
	if not container then
		container = Instance.new("Folder")
		container.Name = FC_VIS_OBJ_NAME
		container.Archivable = false
		container.Parent = workspace.Terrain
	end
	return container
end

local function DebrisVisualization(obj: Instance?, lifetime: number)
	if not obj then return end
	if lifetime <= 0 then
		obj:Destroy()
		return
	end
	task.delay(lifetime, function()
		if obj then obj:Destroy() end
	end)
end

local function VisualizeRaySegment(cframe: CFrame, length: number, visualizeSettings: any, lifetime: number): ConeHandleAdornment?
	if not visualizeSettings then return nil end
	local adornment = Instance.new("ConeHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = cframe
	adornment.Height = length
	adornment.Color3 = visualizeSettings.Debug_SegmentColor
	adornment.Radius = visualizeSettings.Debug_SegmentSize
	adornment.Transparency = visualizeSettings.Debug_SegmentTransparency
	adornment.Parent = GetVisualizationContainer()
	DebrisVisualization(adornment, lifetime)
	return adornment
end

local function VisualizeBlockSegment(cframe: CFrame, size: Vector3, visualizeSettings: any, lifetime: number): BoxHandleAdornment?
	if not visualizeSettings then return nil end
	local adornment = Instance.new("BoxHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = cframe
	adornment.Size = size
	adornment.Color3 = visualizeSettings.Debug_SegmentColor
	adornment.Transparency = visualizeSettings.Debug_SegmentTransparency
	adornment.Parent = GetVisualizationContainer()
	DebrisVisualization(adornment, lifetime)
	return adornment
end

local function VisualizeSphereSegment(cframe: CFrame, radius: number, visualizeSettings: any, lifetime: number): SphereHandleAdornment?
	if not visualizeSettings then return nil end
	local adornment = Instance.new("SphereHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = cframe
	adornment.Radius = radius
	adornment.Color3 = visualizeSettings.Debug_SegmentColor
	adornment.Transparency = visualizeSettings.Debug_SegmentTransparency
	adornment.Parent = GetVisualizationContainer()
	DebrisVisualization(adornment, lifetime)
	return adornment
end

local function VisualizeHit(cframe: CFrame, wasPierce: boolean, visualizeSettings: any, lifetime: number): SphereHandleAdornment?
	if not visualizeSettings then return nil end
	local adornment = Instance.new("SphereHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = cframe
	adornment.Radius = wasPierce and visualizeSettings.Debug_RayPierceSize or visualizeSettings.Debug_HitSize
	adornment.Transparency = wasPierce and visualizeSettings.Debug_RayPierceTransparency or visualizeSettings.Debug_HitTransparency
	adornment.Color3 = wasPierce and visualizeSettings.Debug_RayPierceColor or visualizeSettings.Debug_HitColor
	adornment.Parent = GetVisualizationContainer()
	DebrisVisualization(adornment, lifetime)
	return adornment
end

local castHandlers = {
	[EnumCastTypes.Raycast] = function(targetWorldRoot: WorldRoot, origin: Vector3, direction: Vector3, params: RaycastParams)
		return targetWorldRoot:Raycast(origin, direction, params)
	end,
	[EnumCastTypes.Blockcast] = function(targetWorldRoot: WorldRoot, origin: Vector3, direction: Vector3, params: RaycastParams, size: Vector3)
		return targetWorldRoot:Blockcast(CFrame.new(origin), size, direction, params)
	end,
	[EnumCastTypes.Spherecast] = function(targetWorldRoot: WorldRoot, origin: Vector3, direction: Vector3, params: RaycastParams, radius: number)
		return targetWorldRoot:Spherecast(origin, radius, direction, params)
	end
}

local function GetPositionAtTime(t: number, origin: Vector3, velocity: Vector3, accel: Vector3): Vector3
	local force = Vector3.new(
		(accel.X * t ^ 2) / 2,
		(accel.Y * t ^ 2) / 2,
		(accel.Z * t ^ 2) / 2
	)
	return origin + (velocity * t) + force
end

local function GetVelocityAtTime(time: number, velocity: Vector3, accel: Vector3): Vector3
	return velocity + accel * time
end

-- SoA Arrays (per Actor)
local castCount = 0
local casts = {} :: { [number]: any }
local castIDs = {} :: { [number]: number }
local castOrigin = {} :: { [number]: Vector3 }
local castVelocity = {} :: { [number]: Vector3 }
local castAcceleration = {} :: { [number]: Vector3 }
local castTotalRuntime = {} :: { [number]: number }
local castDistanceCovered = {} :: { [number]: number }
local castMaxDistance = {} :: { [number]: number }
local castPaused = {} :: { [number]: boolean }
local castHighFidelitySegmentSize = {} :: { [number]: number }
local castHighFidelityBehavior = {} :: { [number]: number }
local castIsActivelyResimulating = {} :: { [number]: boolean }
local castCancelHighResCast = {} :: { [number]: boolean }
local castCFrame = {} :: { [number]: CFrame }
local castWorldRoot = {} :: { [number]: WorldRoot }
local castRaycastParams = {} :: { [number]: RaycastParams }
local castCosmeticBullet = {} :: { [number]: Instance? }
local castCastType = {} :: { [number]: number }
local castSize = {} :: { [number]: Vector3? }
local castRadius = {} :: { [number]: number? }
local castVisualize = {} :: { [number]: boolean }
local castVisualizeSettings = {} :: { [number]: any }
local castCaster = {} :: { [number]: any }
local castMotor6D = {} :: { [number]: Motor6D? }
local castCanPierceFn = {} :: { [number]: any? }
local castEventsConfig = {} :: { [number]: any? }
local castEventsModuleConfig = {} :: { [number]: any? }
local castEventsModule = {} :: { [number]: ModuleScript? }

-- Event queue
local QueuedEvents = {} :: { { Callback: any, Args: { any } } }

local function QueueEvent(callback: any, ...)
	if callback then
		table.insert(QueuedEvents, { Callback = callback, Args = { ... } })
	end
end

local function DispatchEvent(callback: any, ...)
	if callback then
		callback(...)
	end
end

local function DispatchAllEvents()
	for _, event in QueuedEvents do
		DispatchEvent(event.Callback, unpack(event.Args))
	end
	table.clear(QueuedEvents)
end

local function ShouldFireEvent(eventsConfig: any?, eventName: string): boolean
	if not eventsConfig then return true end
	if eventName == "Hit" then return eventsConfig.UseHit ~= false end
	if eventName == "Pierced" then return eventsConfig.UsePierced ~= false end
	if eventName == "LengthChanged" then return eventsConfig.UseLengthChanged ~= false end
	if eventName == "CastTerminating" then return eventsConfig.UseCastTerminating ~= false end
	if eventName == "CastFire" then return eventsConfig.UseCastFire ~= false end
	return true
end

local function QueueFire(caster: any, eventsConfig: any?, eventsModuleConfig: any?, eventsModule: ModuleScript?, eventName: string, ...)
	if not ShouldFireEvent(eventsConfig, eventName) then return end

	if eventsModuleConfig and eventsModuleConfig["Use" .. eventName] == false then return end

	if eventsModule then
		local mod = require(eventsModule)
		local fn = mod[eventName]
		if fn then fn(...) end
	end

	if caster and caster.Output then
		caster.Output:Fire(eventName, ...)
	end
end

local function DispatchEvent(callback: any, ...)
	if callback then
		callback(...)
	end
end

local function DispatchAllEvents()
	for _, event in QueuedEvents do
		DispatchEvent(event.Callback, unpack(event.Args))
	end
	table.clear(QueuedEvents)
end

local ParallelSimulation = {
	StepConnection = nil
}

function ParallelSimulation.Register(cast: any)
	castCount += 1
	local id = castCount

	casts[id] = cast
	castIDs[id] = cast.ID
	castOrigin[id] = cast.StateInfo.Trajectory.Origin
	castVelocity[id] = cast.StateInfo.Trajectory.InitialVelocity
	castAcceleration[id] = cast.StateInfo.Trajectory.Acceleration
	castTotalRuntime[id] = 0
	castDistanceCovered[id] = 0
	castMaxDistance[id] = cast.RayInfo.MaxDistance
	castPaused[id] = false
	castHighFidelitySegmentSize[id] = cast.StateInfo.HighFidelitySegmentSize
	castHighFidelityBehavior[id] = cast.StateInfo.HighFidelityBehavior
	castIsActivelyResimulating[id] = false
	castCancelHighResCast[id] = false
	castCFrame[id] = cast.CFrame
	castWorldRoot[id] = cast.RayInfo.WorldRoot
	castRaycastParams[id] = cast.RayInfo.Parameters
	castCosmeticBullet[id] = cast.RayInfo.CosmeticBulletObject
	castCastType[id] = cast.Type == "Blockcast" and EnumCastTypes.Blockcast or (cast.Type == "Spherecast" and EnumCastTypes.Spherecast or EnumCastTypes.Raycast)
	castVisualize[id] = cast.StateInfo.VisualizeCasts
	castVisualizeSettings[id] = cast.StateInfo.VisualizeCastSettings
	castCaster[id] = cast.Caster
	castCanPierceFn[id] = nil

	if cast.CanPierce then
		castCanPierceFn[id] = cast.CanPierce
	end

	castEventsConfig[id] = cast.StateInfo.FastCastEventsConfig
	castEventsModuleConfig[id] = cast.StateInfo.FastCastEventsModuleConfig
	castEventsModule[id] = cast.RayInfo.FastCastEventsModule

	if cast.RayInfo.Size then
		castSize[id] = cast.RayInfo.Size
	end
	if cast.RayInfo.Radius then
		castRadius[id] = cast.RayInfo.Radius
	end

	castMotor6D[id] = nil
	if cast.RayInfo.MovementMethod == "Transform" then
		Motor6DPool.Initialize()
		castMotor6D[id] = Motor6DPool.Connect(id, cast.RayInfo.CosmeticBulletObject :: any)
	end

	cast.ID = id

	local behavior = cast.StateInfo.Behavior or {}
	local origin = castOrigin[id]
	local velocity = castVelocity[id]
	local direction = velocity.Magnitude > 0 and velocity.Unit * velocity.Magnitude or Vector3.new()
	QueueFire(cast.Caster, cast.StateInfo.FastCastEventsConfig, cast.StateInfo.FastCastEventsModuleConfig, cast.RayInfo.FastCastEventsModule, "CastFire", cast, origin, direction, velocity, behavior)
end

function ParallelSimulation.Unregister(id: number)
	if not casts[id] then return end

	local lastId = castCount
	if id ~= lastId then
		castIDs[id] = castIDs[lastId]
		castOrigin[id] = castOrigin[lastId]
		castVelocity[id] = castVelocity[lastId]
		castAcceleration[id] = castAcceleration[lastId]
		castTotalRuntime[id] = castTotalRuntime[lastId]
		castDistanceCovered[id] = castDistanceCovered[lastId]
		castMaxDistance[id] = castMaxDistance[lastId]
		castPaused[id] = castPaused[lastId]
		castHighFidelitySegmentSize[id] = castHighFidelitySegmentSize[lastId]
		castHighFidelityBehavior[id] = castHighFidelityBehavior[lastId]
		castIsActivelyResimulating[id] = castIsActivelyResimulating[lastId]
		castCancelHighResCast[id] = castCancelHighResCast[lastId]
		castCFrame[id] = castCFrame[lastId]
		castWorldRoot[id] = castWorldRoot[lastId]
		castRaycastParams[id] = castRaycastParams[lastId]
		castCosmeticBullet[id] = castCosmeticBullet[lastId]
		castCastType[id] = castCastType[lastId]
		castSize[id] = castSize[lastId]
		castRadius[id] = castRadius[lastId]
		castVisualize[id] = castVisualize[lastId]
		castVisualizeSettings[id] = castVisualizeSettings[lastId]
		castCaster[id] = castCaster[lastId]
		castMotor6D[id] = castMotor6D[lastId]
		castCanPierceFn[id] = castCanPierceFn[lastId]
		castEventsConfig[id] = castEventsConfig[lastId]
		castEventsModuleConfig[id] = castEventsModuleConfig[lastId]
		castEventsModule[id] = castEventsModule[lastId]

		if casts[lastId] then
			casts[lastId].ID = id
			casts[id] = casts[lastId]
		end
	end

	if id ~= lastId and castMotor6D[lastId] then
		Motor6DPool.Disconnect(castMotor6D[lastId])
	end

	castIDs[lastId] = nil
	castOrigin[lastId] = nil
	castVelocity[lastId] = nil
	castAcceleration[lastId] = nil
	castTotalRuntime[lastId] = nil
	castDistanceCovered[lastId] = nil
	castMaxDistance[lastId] = nil
	castPaused[lastId] = nil
	castHighFidelitySegmentSize[lastId] = nil
	castHighFidelityBehavior[lastId] = nil
	castIsActivelyResimulating[lastId] = nil
	castCancelHighResCast[lastId] = nil
	castCFrame[id] = nil
	castWorldRoot[lastId] = nil
	castRaycastParams[lastId] = nil
	castCosmeticBullet[lastId] = nil
	castCastType[lastId] = nil
	castSize[lastId] = nil
	castRadius[lastId] = nil
	castVisualize[lastId] = nil
	castVisualizeSettings[lastId] = nil
	castCaster[lastId] = nil
	castMotor6D[lastId] = nil
	castCanPierceFn[lastId] = nil
	castEventsConfig[lastId] = nil
	castEventsModuleConfig[lastId] = nil
	castEventsModule[lastId] = nil

	casts[id] = nil
	castCount = lastId - 1
end

function ParallelSimulation.PauseCast(id: number, paused: boolean)
	castPaused[id] = paused
end

function ParallelSimulation.Terminate(id: number)
	local bullet = castCosmeticBullet[id]
	if bullet then
		bullet:Destroy()
	end

	QueueFire(castCaster[id], castEventsConfig[id], castEventsModuleConfig[id], castEventsModule[id], "CastTerminating", casts[id])

	ParallelSimulation.Unregister(id)
end

local function UpdateCasts(deltaTime: number)
	if castCount == 0 then return end

	if DebugLogging.Casting then
		print("Casting for frame.")
	end

	local destroyedIds = {} :: { number }

	for i = 1, castCount do
		if castPaused[i] then continue end

		local caster = castCaster[i]
		local castType = castCastType[i]
		local CastHandler = castHandlers[castType]
		local highFidelityBehavior = castHighFidelityBehavior[i]
		local highFidelitySegmentSize = castHighFidelitySegmentSize[i]
		local canPierceFn = castCanPierceFn[i]

		local origin = castOrigin[i]
		local totalDelta = castTotalRuntime[i]
		local velocity = castVelocity[i]
		local acceleration = castAcceleration[i]

		local lastPosition = GetPositionAtTime(totalDelta, origin, velocity, acceleration)
		castTotalRuntime[i] += deltaTime
		totalDelta = castTotalRuntime[i]

		local currentPosition = GetPositionAtTime(totalDelta, origin, velocity, acceleration)
		local currentVelocity = GetVelocityAtTime(totalDelta, velocity, acceleration)
		local displacement = currentPosition - lastPosition

		local rayDir = displacement.Unit * currentVelocity.Magnitude * deltaTime

		local variant = {}
		if castType == EnumCastTypes.Blockcast then
			variant.Size = castSize[i]
		elseif castType == EnumCastTypes.Spherecast then
			variant.Radius = castRadius[i]
		end

		local result = CastHandler(castWorldRoot[i], lastPosition, rayDir, castRaycastParams[i], variant)

		local hitPoint = currentPosition
		local hitPart = nil
		local hitNormal = Vector3.new()
		if result then
			hitPoint = result.Position
			hitPart = result.Instance
			hitNormal = result.Normal
		end

		local rayDisplacement = (hitPoint - lastPosition).Magnitude
		castDistanceCovered[i] += rayDisplacement

		local newCFrame = CFrame.new(lastPosition, lastPosition + rayDir) * CFrame.new(0, 0, -rayDisplacement / 2)
		castCFrame[i] = newCFrame

		-- Update cosmetic bullet
		local bullet = castCosmeticBullet[i]
		local motor6d = castMotor6D[i]
		if bullet then
			if motor6d then
				motor6d.Transform = newCFrame
			elseif bullet:IsA("BasePart") then
				bullet.CFrame = newCFrame
			else
				bullet:PivotTo(newCFrame)
			end
		end

		-- Visualization (requires task.synchronize for cross-thread)
		local visualize = castVisualize[i]
		local visualizeSettings = castVisualizeSettings[i]
		if visualize and visualizeSettings and deltaTime > 0 then
			task.synchronize()
			local lifetime = visualizeSettings.Debug_RayLifetime or 1
			if castType == EnumCastTypes.Raycast then
				VisualizeRaySegment(CFrame.new(lastPosition, lastPosition + rayDir), rayDisplacement, visualizeSettings, lifetime)
			elseif castType == EnumCastTypes.Blockcast then
				VisualizeBlockSegment(CFrame.new(lastPosition, lastPosition + rayDir), castSize[i], visualizeSettings, lifetime)
			elseif castType == EnumCastTypes.Spherecast then
				VisualizeSphereSegment(CFrame.new(lastPosition, lastPosition + rayDir), castRadius[i], visualizeSettings, lifetime)
			end
		end

		-- Fire LengthChanged
		QueueFire(caster, castEventsConfig[i], castEventsModuleConfig[i], castEventsModule[i], "LengthChanged", casts[i], lastPosition, rayDir.Unit, rayDisplacement, currentVelocity, bullet)

		-- Handle hit with HighFidelity and Piercing
		if result and hitPart ~= bullet then
			if DebugLogging.Hit then
				print("Hit something, testing now.")
			end

			if DebugLogging.RayPierce and not canPierceFn then
				print("No piercing function set, proceeding to hit processing.")
			end

			if
				highFidelityBehavior == HighFidelityBehavior.Automatic
				and highFidelitySegmentSize > 0
				and rayDisplacement > highFidelitySegmentSize
			then
				castIsActivelyResimulating[i] = true
				castCancelHighResCast[i] = false

				local numSegmentsDecimal = rayDisplacement / highFidelitySegmentSize
				local numSegmentsReal = math.floor(numSegmentsDecimal)

				if numSegmentsReal == 0 then
					numSegmentsReal = 1
				end

				local timeIncrement = deltaTime / numSegmentsReal

				if DebugLogging.Calculation then
					print("Performing subcast! Time increment: " .. timeIncrement .. ", num segments: " .. numSegmentsReal)
				end

				local subLastPoint = lastPosition
				for segmentIndex = 1, numSegmentsReal do
					if castCancelHighResCast[i] then
						castCancelHighResCast[i] = false
						break
					end

					if DebugLogging.Segment then
						print("[" .. segmentIndex .. "] Subcast of time increment " .. timeIncrement)
					end

					local subTime = totalDelta - deltaTime + (timeIncrement * segmentIndex)
					local subPosition = GetPositionAtTime(subTime, origin, velocity, acceleration)
					local subVelocity = GetVelocityAtTime(subTime, velocity, acceleration)
					local subRayDir = subVelocity * timeIncrement

					local subResult = CastHandler(castWorldRoot[i], subLastPoint, subRayDir, castRaycastParams[i], variant)

					if subResult then
						local subDisplacement = (subLastPoint - subResult.Position).Magnitude
						local subHitVelocity = GetVelocityAtTime(subTime, velocity, acceleration)

						local canPierce = canPierceFn and canPierceFn(casts[i], subResult, subHitVelocity, bullet)

						if canPierce then
							if DebugLogging.RayPierce then
								print("Piercing function returned TRUE to pierce this part.")
							end

							castDistanceCovered[i] += subDisplacement

							local subCFrame = CFrame.new(subLastPoint, subLastPoint + subRayDir) * CFrame.new(0, 0, -subDisplacement / 2)
							castCFrame[i] = subCFrame

							if bullet then
								if motor6d then
									motor6d.Transform = subCFrame
								elseif bullet:IsA("BasePart") then
									bullet.CFrame = subCFrame
								else
									bullet:PivotTo(subCFrame)
								end
							end

							QueueFire(caster, castEventsConfig[i], castEventsModuleConfig[i], castEventsModule[i], "Pierced", casts[i], subResult, subHitVelocity, bullet)
							subLastPoint = subResult.Position

							if visualize and visualizeSettings then
								task.synchronize()
								local lifetime = visualizeSettings.Debug_RayLifetime or 1
								local hitVis = VisualizeHit(CFrame.new(subResult.Position), true, visualizeSettings, lifetime)
								if hitVis then
									hitVis.Color3 = DBG_RAYPIERCE_SUB_COLOR
								end
							end
						else
							if DebugLogging.RayPierce then
								print("Piercing function is nil or it returned FALSE to not pierce this hit.")
							end

							castIsActivelyResimulating[i] = false

							castTotalRuntime[i] = totalDelta
							castDistanceCovered[i] += subDisplacement

							local subCFrame = CFrame.new(subLastPoint, subLastPoint + subRayDir) * CFrame.new(0, 0, -subDisplacement / 2)
							castCFrame[i] = subCFrame

							if bullet then
								if motor6d then
									motor6d.Transform = subCFrame
								elseif bullet:IsA("BasePart") then
									bullet.CFrame = subCFrame
								else
									bullet:PivotTo(subCFrame)
								end
							end

							QueueFire(caster, castEventsConfig[i], castEventsModuleConfig[i], castEventsModule[i], "Hit", casts[i], subResult, subHitVelocity, bullet)

							if visualize and visualizeSettings then
								task.synchronize()
								local lifetime = visualizeSettings.Debug_RayLifetime or 1
								local hitVis = VisualizeHit(CFrame.new(subResult.Position), false, visualizeSettings, lifetime)
								if hitVis then
									hitVis.Color3 = DBG_HIT_SUB_COLOR
								end
							end

							table.insert(destroyedIds, i)
							break
						end
					else
						subLastPoint = subPosition
					end
				end

				if castIsActivelyResimulating[i] then
					castIsActivelyResimulating[i] = false
				end
			else
				local canPierce = canPierceFn and canPierceFn(casts[i], result, currentVelocity, bullet)

				if canPierce then
					if DebugLogging.RayPierce then
						print("Piercing function returned TRUE to pierce this part.")
					end

					castDistanceCovered[i] += rayDisplacement
					QueueFire(caster, castEventsConfig[i], castEventsModuleConfig[i], castEventsModule[i], "Pierced", casts[i], result, currentVelocity, bullet)

					if visualize and visualizeSettings then
						task.synchronize()
						VisualizeHit(CFrame.new(result.Position), true, visualizeSettings, visualizeSettings.Debug_HitLifetime or 1)
					end
				else
					if DebugLogging.RayPierce then
						print("Piercing function is nil or it returned FALSE to not pierce this hit.")
					end

					if DebugLogging.Hit then
						print("Hit was successful. Terminating.")
					end

					QueueFire(caster, castEventsConfig[i], castEventsModuleConfig[i], castEventsModule[i], "Hit", casts[i], result, currentVelocity, bullet)

					if visualize and visualizeSettings then
						task.synchronize()
						VisualizeHit(CFrame.new(result.Position), false, visualizeSettings, visualizeSettings.Debug_HitLifetime or 1)
					end

					table.insert(destroyedIds, i)
				end
			end
		end

		-- Check max distance
		if castDistanceCovered[i] >= castMaxDistance[i] then
			table.insert(destroyedIds, i)
		end
	end

	-- Process destroyed casts (iterate in reverse to avoid index invalidation)
	for i = #destroyedIds, 1, -1 do
		ParallelSimulation.Terminate(destroyedIds[i])
	end

	DispatchAllEvents()
end

function ParallelSimulation.Start()
	if ParallelSimulation.StepConnection then return end
	if RS:IsClient() then
		ParallelSimulation.StepConnection = RS.PreRender:ConnectParallel(UpdateCasts)
	else
		ParallelSimulation.StepConnection = RS.Heartbeat:Connect(UpdateCasts)
	end
end

function ParallelSimulation.Stop()
	if ParallelSimulation.StepConnection then
		ParallelSimulation.StepConnection:Disconnect()
		ParallelSimulation.StepConnection = nil
	end
end

-- Auto-start when loaded
ParallelSimulation.Start()

return ParallelSimulation