--[[
	- Author : Mawin CK
	- Date : 2025
	-- Version : 0.0.9

	ActiveCastSerial - Serial mode with single RunService, SoA pattern, queue technique
	Similar to SwiftCast implementation
]]

local RS = game:GetService("RunService")

local FastCastModule = script.Parent
local TypeDef = require(FastCastModule:WaitForChild("TypeDefinitions"))
local Configs = require(FastCastModule:WaitForChild("Configs"))
local DebugLogging = Configs.DebugLogging
local FastCastEnums = require(FastCastModule:WaitForChild("FastCastEnums"))

local FC_VIS_OBJ_NAME = "FastCastVisualizationObjects"
local MAX_SEGMENT_CAL_TIME = 0.016 * 5
local MAX_CASTING_TIME = 0.2
local DEFAULT_MAX_DISTANCE = 1000
local HIGH_FIDE_INCREASE_SIZE = 0.5

local EnumCastTypes = FastCastEnums.CastType

local DBG_SEGMENT_SUB_COLOR = Color3.new(0.286275, 0.329412, 0.247059)
local DBG_SEGMENT_SUB_COLOR2 = Color3.new(0.454902, 0.933333, 0.011765)
local DBG_HIT_SUB_COLOR = Color3.new(0.0588235, 0.87451, 1)
local DBG_RAYPIERCE_SUB_COLOR = Color3.new(1, 0.113725, 0.588235)

type CastVariant = { CastType: number, Size: Vector3?, Radius: number? }

local CastVariantTypes = {
	[EnumCastTypes.Raycast] = "Raycast",
	[EnumCastTypes.Blockcast] = "Blockcast",
	[EnumCastTypes.Spherecast] = "Spherecast"
}

local castHandlers = {
	[EnumCastTypes.Raycast] = function(targetWorldRoot: WorldRoot, origin: Vector3, direction: Vector3, parameters: RaycastParams)
		return targetWorldRoot:Raycast(origin, direction, parameters)
	end,
	[EnumCastTypes.Blockcast] = function(targetWorldRoot: WorldRoot, origin: Vector3, direction: Vector3, parameters: RaycastParams, size: Vector3)
		return targetWorldRoot:Blockcast(CFrame.new(origin), size, direction, parameters)
	end,
	[EnumCastTypes.Spherecast] = function(targetWorldRoot: WorldRoot, origin: Vector3, direction: Vector3, parameters: RaycastParams, radius: number)
		return targetWorldRoot:Spherecast(origin, radius, direction, parameters)
	end
}

local ActiveCastSerial = {}

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

local function DebrisAdd(obj: Instance, Lifetime: number)
	if not obj then return end
	if Lifetime <= 0 then
		obj:Destroy()
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

local function DbgVisualizeRaySegment(castStartCFrame: CFrame, visualize: boolean, settings: any, length: number)
	if not visualize then return end
	local adornment = Instance.new("ConeHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = castStartCFrame
	adornment.Height = length
	adornment.Color3 = settings.Debug_SegmentColor
	adornment.Radius = settings.Debug_SegmentSize
	adornment.Transparency = settings.Debug_SegmentTransparency
	adornment.Parent = GetFastCastVisualizationContainer()
	DebrisAdd(adornment, settings.Debug_RayLifetime)
end

local function DbgVisualizeHit(atCF: CFrame, wasPierce: boolean, visualize: boolean, settings: any)
	if not visualize then return end
	local adornment = Instance.new("SphereHandleAdornment")
	adornment.Adornee = workspace.Terrain
	adornment.CFrame = atCF
	adornment.Radius = wasPierce and settings.Debug_RayPierceSize or settings.Debug_HitSize
	adornment.Transparency = wasPierce and settings.Debug_RayPierceTransparency or settings.Debug_HitTransparency
	adornment.Color3 = wasPierce and settings.Debug_RayPierceColor or settings.Debug_HitColor
	adornment.Parent = GetFastCastVisualizationContainer()
	DebrisAdd(adornment, settings.Debug_HitLifetime)
end

local function CloneCastParams(params: RaycastParams): RaycastParams
	local clone: RaycastParams = RaycastParams.new()
	clone.CollisionGroup = params.CollisionGroup
	clone.FilterType = params.FilterType
	clone.FilterDescendantsInstances = params.FilterDescendantsInstances
	clone.IgnoreWater = params.IgnoreWater
	return clone
end

local EPSILON = 1e-6
local RAY_SEARCH_OFFSET = 0.001
local FIXED_DELTA_TIME = 1 / 240

function ActiveCastSerial.new(caster: any, castData: any): any
	return {
		Caster = caster,
		StateInfo = {
			Paused = false,
			TotalRuntime = 0,
			DistanceCovered = 0,
			HighFidelitySegmentSize = castData.HighFidelitySegmentSize,
			HighFidelityBehavior = castData.HighFidelityBehavior,
			IsActivelyResimulating = false,
			CancelHighResCast = false,
			Trajectory = {
				StartTime = 0,
				EndTime = -1,
				Origin = castData.Origin,
				InitialVelocity = castData.Velocity,
				Acceleration = castData.Acceleration,
			},
			VisualizeCasts = castData.VisualizeCasts,
			VisualizeCastSettings = castData.VisualizeCastSettings
		},

		RayInfo = {
			Parameters = castData.RaycastParams,
			WorldRoot = workspace,
			MaxDistance = castData.MaxDistance or DEFAULT_MAX_DISTANCE,
			CosmeticBulletObject = castData.CosmeticBulletObject
		},

		Type = CastVariantTypes[castData.CastType],
		CFrame = CFrame.new(castData.Origin),
		ID = castData.ID
	}
end

return ActiveCastSerial