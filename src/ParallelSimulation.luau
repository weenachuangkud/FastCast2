--[[
	- Author: Mawin CK
	- Date: 2026
]]

-- NOTE: The reason why this module is not OOP, because it's made for parallel luau
-- Basically in parallel luau, each actors will have completely different copys of this module in multiple threads
-- So if this module is OOP, then each thread will have to create a new instance of the class, which is not what we want
-- We want to have a single instance of the class that is shared across all threads, so
-- If this changed in the future, please Pull request

-- Services
local RS = game:GetService("RunService")

-- Variables
local FastCastModule = script.Parent

-- Dependencies
local FastCast = require(FastCastModule)
local TypeDef = require(FastCastModule:WaitForChild("TypeDefinitions"))
local Configs = require(FastCastModule:WaitForChild("Configs"))
local DebugLogging = Configs.DebugLogging
local FastCastEnums = require(FastCastModule:WaitForChild("FastCastEnums"))
-- Constants
local FC_VIS_OBJ_NAME = "FastCastVisualizationObjects"
local MAX_SEGMENT_CAL_TIME = 0.016 * 5 -- 80ms
local MAX_CASTING_TIME = 0.2 -- 200ms

local DEFAULT_MAX_DISTANCE = 1000

-- Enums
local EnumCastTypes = FastCastEnums.CastType

-- Debugging

local DBG_SEGMENT_SUB_COLOR = Color3.new(0.286275, 0.329412, 0.247059)
local DBG_SEGMENT_SUB_COLOR2 = Color3.new(0.454902, 0.933333, 0.011765)

local DBG_HIT_SUB_COLOR = Color3.new(0.0588235, 0.87451, 1)

local DBG_RAYPIERCE_SUB_COLOR = Color3.new(1, 0.113725, 0.588235)

-- Types
type vaildcast = TypeDef.ActiveCastData | TypeDef.ActiveBlockcastData | TypeDef.ActiveSpherecastData

type BlockcastVariant = { CastType: number, Size: Vector3}
type SpherecastVariant = { CastType: number, Radius: number }
type CastVariants = BlockcastVariant | SpherecastVariant

type RayVisualizerVariant = { castLength: number}
type BlockVisualizerVariant = { size: Vector3 }
type SphereVisualizerVariant = { radius: number }
type CastVisualizerVariants = RayVisualizerVariant | BlockVisualizerVariant | SphereVisualizerVariant

type CastHandler = (WorldRoot: WorldRoot, origin: Vector3, direction: Vector3, castVariant: CastVariants) -> RaycastResult
type CastVisualizer = (castStartCFrame: CFrame, VisualizeCasts: boolean, VisualizeCastSettings: TypeDef.VisualizeCastSettings, castVariant: CastVisualizerVariants) -> (ConeHandleAdornment | BoxHandleAdornment | SphereHandleAdornment)?

-- Is this even useful?
-- What Is even these magic numbers?
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

-- Utils
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
	t: number,
	origin: Vector3,
	initialVelocity: Vector3,
	acceleration: Vector3
): Vector3
	local force =
		Vector3.new((acceleration.X * t ^ 2) / 2, (acceleration.Y * t ^ 2) / 2, (acceleration.Z * t ^ 2) / 2)
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
	if not VisualizeCasts then
		return
	end
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
	VisualizeCastSetting: TypeDef.VisualizeCastSettings,
	variant: BlockVisualizerVariant
): BoxHandleAdornment?
	if not VisualizeCasts then
		return
	end
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
	VisualizeCasts: boolean,
	VisualizeCastSetting: TypeDef.VisualizeCastSettings,
	variant: SphereVisualizerVariant
): SphereHandleAdornment?
	if not VisualizeCasts then
		return
	end
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

-- SoA

local casts_Paused = {} :: { [number]: boolean }
local casts_TotalRunTime = {} :: { [number]: number }
local casts_DistanceCovered = {} :: { [number]: number }
local casts_HighFidelitySegmentSize = {} :: { [number]: number }
local casts_HighFidelityBehavior = {} :: { [number]: number }
local casts_IsActivelySimulatingPierce = {} :: { [number]: boolean }
local casts_IsActivelyResimulating = {} :: { [number]: boolean }
local casts_CancelHighResCast = {} :: { [number]: boolean }
local casts_Trajectory  = {} :: { [number]: TypeDef.CastTrajectory }
local casts_VisualizeCasts = {} :: { [number]: boolean }
local casts_VisualizeCastSettings = {} :: { [number]: TypeDef.VisualizeCastSettings }
local casts_FastCastEventsModuleConfig = {} :: { [number]: TypeDef.FastCastEventsModuleConfig }
local casts_FastCastEventsConfig = {} :: { [number]: TypeDef.FastCastEventsConfig }
local casts_RayInfo = {} :: { [number]: TypeDef.CastRayInfo }
local casts_UserData = {} :: { [number]: any }
local casts_CFrame = {} :: { [number]: CFrame }
local casts_ID = {} :: { [number]: number }
--local casts_Type

-- QueueEvents
local castsData

-- QueueVisualizes

-- RS
local function UpdateCasts()
	-- TODO
end

-- ParallelSimulation

local ParallelSimulation = {}
ParallelSimulation.Connection = nil :: RBXScriptConnection?

function ParallelSimulation.Register(cast: any)
	-- TODO
end

function ParallelSimulation.Unregister(cast: any)
	-- TODO
end

function ParallelSimulation.Init()
	-- TODO
	-- use ObjectCache from BaseCastParallel
	-- use Motor6DCache from BaseCastParallel
end

function ParallelSimulation.Start()
	if ParallelSimulation.Connection then return end
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