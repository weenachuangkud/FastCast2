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

type CastVariant = { CastType: number, Size: Vector3?, Radius: number? }

type BlockcastVariant = { CastType: number, Size: Vector3}
type SpherecastVariant = { CastType: number, Radius: number }
type CastVariants = BlockcastVariant | SpherecastVariant


--[[local CastVariantTypes = {
	[EnumCastTypes.Raycast] = "Raycast",
	[EnumCastTypes.Blockcast] = "Blockcast",
	[EnumCastTypes.Spherecast] = "Spherecast"
}]]

local ActiveCast = {}

local function CloneCastParams(params: RaycastParams): RaycastParams
	local clone: RaycastParams = RaycastParams.new()
	clone.CollisionGroup = params.CollisionGroup
	clone.FilterType = params.FilterType
	clone.FilterDescendantsInstances = {table.unpack(params.FilterDescendantsInstances)}
	clone.IgnoreWater = params.IgnoreWater
	return clone
end

function ActiveCast.createCastData(
	BaseCast: any,
	activeCastID: number,
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: TypeDef.FastCastBehavior,
	eventModule: TypeDef.FastCastEventsModule?,
	variant: CastVariants,
	ObjectCacheRef: any,
	_parallel: boolean?
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

			FastCastEventsConfig = {
				UseLengthChanged = behavior.FastCastEventsConfig.UseLengthChanged,
				UseHit = behavior.FastCastEventsConfig.UseHit,
				UsePierced = behavior.FastCastEventsConfig.UsePierced,
				UseCastTerminating = behavior.FastCastEventsConfig.UseCastTerminating,
				UseCanPierce = behavior.FastCastEventsConfig.UseCanPierce
			},

			--VisualizeCasts = behavior.VisualizeCasts, -- I don't use this
			VisualizeCastSettings = behavior.VisualizeCastSettings,
		},

		RayInfo = {
			Parameters = behavior.RaycastParams and CloneCastParams(behavior.RaycastParams) or RaycastParams.new(),
			WorldRoot = workspace,
			MaxDistance = behavior.MaxDistance or DEFAULT_MAX_DISTANCE,
			CosmeticBulletObject = behavior.CosmeticBulletTemplate,
			MovementMethod = behavior.MovementMethod or "BulkMoveTo",
			FastCastModule = eventModule
		},

		Type = variant.CastType,
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

	local targetContainer: Instance?
	if ObjectCacheRef then
		cast.RayInfo.CosmeticBulletObject = ObjectCacheRef:GetPart(CFrame.new(origin, origin + direction))
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
		local ignoreList = cast.RayInfo.Parameters.FilterDescendantsInstances
		if not table.find(ignoreList, targetContainer) then
			table.insert(ignoreList, targetContainer)
			cast.RayInfo.Parameters.FilterDescendantsInstances = ignoreList
		end
	end

	return cast
end

return ActiveCast