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
