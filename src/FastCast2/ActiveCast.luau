--[[
	- Author : Mawin CK
	- Date : 2025
	

	ActiveCastSerial - Serial mode with single RunService, SoA pattern, queue technique
	Similar to SwiftCast implementation
]]

local FastCastModule = script.Parent
local TypeDef = require(FastCastModule:WaitForChild("TypeDefinitions"))
local FastCastEnums = require(FastCastModule:WaitForChild("FastCastEnums"))

local DEFAULT_MAX_DISTANCE = 1000

local EnumCastTypes = FastCastEnums.CastType

type CastVariant = { CastType: number, Size: Vector3?, Radius: number?, CosmeticBulletObject: Instance? }

type BlockcastVariant = { CastType: number, Size: Vector3, CosmeticBulletObject: Instance? }
type SpherecastVariant = { CastType: number, Radius: number, CosmeticBulletObject: Instance? }
type CastVariants = BlockcastVariant | SpherecastVariant


local CastVariantTypes = {
	[EnumCastTypes.Raycast] = "Raycast",
	[EnumCastTypes.Blockcast] = "Blockcast",
	[EnumCastTypes.Spherecast] = "Spherecast"
}

local ActiveCast = {}

local function CloneCastParams(params: RaycastParams): RaycastParams
	local clone: RaycastParams = RaycastParams.new()
	clone.CollisionGroup = params.CollisionGroup
	clone.FilterType = params.FilterType
	clone.FilterDescendantsInstances = params.FilterDescendantsInstances
	clone.IgnoreWater = params.IgnoreWater
	return clone
end

function ActiveCast.createCastData(
	BaseCast: TypeDef.BaseCastData,
	activeCastID: number,
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: TypeDef.FastCastBehavior,
	eventModule: TypeDef.FastCastEventsModule?,
	variant: CastVariants,
	_parallel: boolean
): any
	local cast = {
		Caster = BaseCast,
		StateInfo = {
			Paused = false,
			TotalRuntime = 0,
			DistanceCovered = 0,
			HighFidelitySegmentSize = behavior.HighFidelitySegmentSize,
			HighFidelityBehavior = behavior.HighFidelityBehavior,
			IsActivelyResimulating = false,
			CancelHighResCast = false,
			Trajectory = {
				StartTime = 0,
				EndTime = -1,
				Origin = origin,
				InitialVelocity = if typeof(velocity) == "number" then direction * velocity else velocity,
				Acceleration = behavior.Acceleration,
			},
			VisualizeCasts = behavior.VisualizeCasts,
			VisualizeCastSettings = behavior.VisualizeCastSettings,

			FastCastEventsConfig = {
				UseLengthChanged = behavior.FastCastEventsConfig.UseLengthChanged,
				UseHit = behavior.FastCastEventsConfig.UseHit,
				UsePierced = behavior.FastCastEventsConfig.UsePierced,
				UseCastTerminating = behavior.FastCastEventsConfig.UseCastTerminating,
				UseCanPierce = behavior.FastCastEventsConfig.UseCanPierce
			}
		},

		RayInfo = {
			Parameters = behavior.RaycastParams and CloneCastParams(behavior.RaycastParams) or RaycastParams.new(),
			WorldRoot = workspace,
			MaxDistance = behavior.MaxDistance or DEFAULT_MAX_DISTANCE,
			CosmeticBulletObject = behavior.CosmeticBulletTemplate,
			MovementMethod = behavior.MovementMethod or "BulkMoveTo",
			FastCastModule = eventModule
		},

		Type = CastVariantTypes[variant.CastType],
		CastVariant = variant,
		CFrame = CFrame.new(origin),
		ID = activeCastID
	}

	if _parallel then
		cast.StateInfo.FastCastEventsModuleConfig = {
				UseLengthChanged = behavior.FastCastEventsModuleConfig.UseLengthChanged,
				UseHit = behavior.FastCastEventsModuleConfig.UseHit,
				UsePierced = behavior.FastCastEventsModuleConfig.UsePierced,
				UseCastTerminating = behavior.FastCastEventsModuleConfig.UseCastTerminating,
				UseCanPierce = behavior.FastCastEventsModuleConfig.UseCanPierce,
			}
	end

	if variant.CastType == EnumCastTypes.Blockcast then
		cast.RayInfo.Size = (variant :: BlockcastVariant).Size
	elseif variant.CastType == EnumCastTypes.Spherecast then
		cast.RayInfo.Radius = (variant :: SpherecastVariant).Radius
	end

	if behavior.UserData then
		cast.UserData = behavior.UserData
	end

	if cast.RayInfo.Parameters ~= nil then
		cast.RayInfo.Parameters = CloneCastParams(cast.RayInfo.Parameters)
	else
		cast.RayInfo.Parameters = RaycastParams.new()
	end

	local targetContainer: Instance?
	if _parallel and variant.CosmeticBulletObject then
		cast.RayInfo.CosmeticBulletObject = variant.CosmeticBulletObject
		targetContainer = behavior.CosmeticBulletContainer
	elseif cast.Caster.GetObjectCache then
		cast.RayInfo.CosmeticBulletObject = cast.Caster.GetObjectCache(CFrame.new(origin, origin + direction))
		targetContainer = cast.Caster.CacheHolder
	else
		if cast.RayInfo.CosmeticBulletObject ~= nil then
			local basePart = cast.RayInfo.CosmeticBulletObject
			basePart = basePart:Clone()
			basePart.CFrame = CFrame.new(origin, origin + direction)
			basePart.Parent = behavior.CosmeticBulletContainer

			cast.RayInfo.CosmeticBulletObject = basePart
		end

		if behavior.CosmeticBulletContainer then
			targetContainer = behavior.CosmeticBulletContainer
		end
	end

	if behavior.AutoIgnoreContainer == true and targetContainer ~= nil then
		local igroneList = cast.RayInfo.Parameters.FilterDescendantsInstances
		if not table.find(igroneList, targetContainer) then
			table.insert(igroneList, targetContainer)
			cast.RayInfo.Parameters.FilterDescendantsInstances = igroneList
		end
	end

	return cast
end

return ActiveCast