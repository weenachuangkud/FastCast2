--[[
	- Author: Mawin CK
	- Date: 2026
]]

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

-- SoA

local castUserDatas = {} :: { [number]: any }
local castStateInfos = {} :: { [number]: TypeDef.CastStateInfo }
local castRayInfos = {} :: { [number]: TypeDef.CastRayInfo }
local castVisualizeInfos = {} :: { [number]: TypeDef.CastVisualizeInfo }

-- QueueEvents

-- ParallelSimulation

local ParallelSimulation = {}
ParallelSimulation.Connection = nil :: RBXScriptConnection?

function ParallelSimulation.Register(cast: any)
	-- TODO
end

function ParallelSimulation.Unregister(cast: any)
	-- TODO
end

function ParallelSimulation.Start()
	-- TODO
end

function ParallelSimulation.Stop()
	-- TODO
end

return ParallelSimulation