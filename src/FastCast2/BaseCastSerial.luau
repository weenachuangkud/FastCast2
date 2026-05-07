--[[
	- Author : Mawin CK
	- Date : 2025
	-- Version : 0.0.9
]]

local RS = game:GetService("RunService")

local FastCast2 = script.Parent
local FastCastM = require(FastCast2)

local FastCastEnums = require(FastCast2:WaitForChild("FastCastEnums"))
local TypeDef = require(FastCast2:WaitForChild("TypeDefinitions"))
local ActiveCastSerial = require(FastCast2:WaitForChild("ActiveCastSerial"))

local EnumCastTypes = FastCastEnums.CastType

--[=[
	@class BaseCastSerial

	Base class for Serial (non-parallel) Raycast operations.
]=]

local BaseCastSerial = {}
BaseCastSerial.__index = BaseCastSerial
BaseCastSerial.__type = "BaseCastSerial"

local BulkMoveToConnection: RBXScriptConnection? = nil
local Actives: any = {}
local Output: BindableEvent? = nil
local ActiveCastCleaner: BindableEvent? = nil
local ObjectCache: BindableFunction? = nil
local NextProjectileID = 0
local SyncChanges: BindableEvent? = nil
local CastFireFunc = nil
local ParentCaster = nil

local function HandleBulkMoveTo()
	local Parts: { BasePart } = {}
	local CFrames: { CFrame } = {}

	for _, ActiveCasts in Actives do
		local ProjectilePart = ActiveCasts.RayInfo.CosmeticBulletObject
		if not ProjectilePart then continue end

		local resultCFrame = ActiveCasts.CFrame
		if ProjectilePart:IsA("BasePart") then
			table.insert(Parts, ProjectilePart)
			table.insert(CFrames, resultCFrame)
		else
			ProjectilePart:PivotTo(resultCFrame)
		end
	end

	task.synchronize()
	workspace:BulkMoveTo(Parts, CFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function SendCastFire(
	cast: TypeDef.ActiveCastData,
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: TypeDef.FastCastBehavior
)
	if Output then
		Output:Fire("CastFire", cast, origin, direction, velocity, behavior)
	end
end

--[=[
	@function Init
	@within BaseCastSerial

	@param BindableOutput BindableEvent -- The BindableEvent used for outputting events.
	@param Data any -- Configuration data for the BaseCastSerial.
	@return BaseCastSerial -- The initialized BaseCastSerial instance.
]=]
function BaseCastSerial.Init(BindableOutput: BindableEvent, Data: any, parentCaster: any)
	local self = setmetatable({}, BaseCastSerial)
	Actives = setmetatable({}, { __mode = "v" })
	Output = BindableOutput
	ParentCaster = parentCaster

	local BindableCleaner = Instance.new("BindableEvent")
	BindableCleaner.Name = "ActiveCastDestroyer"
	BindableCleaner.Parent = script

	if Data.useObjectCache then
		local BindableObjectCache = Instance.new("BindableFunction")
		BindableObjectCache.Parent = script
		BindableObjectCache.Name = "ActiveCastObjectCache"
		ObjectCache = BindableObjectCache
	end

	if Data.useBulkMoveTo then
		BulkMoveToConnection = RS.PreRender:Connect(HandleBulkMoveTo)
	end

	ActiveCastCleaner = BindableCleaner

	ActiveCastCleaner.Event:Connect(function(activeCastID: number)
		if Actives[activeCastID] then
			Actives[activeCastID] = nil
		end
	end)

	SyncChanges = Instance.new("BindableEvent")
	SyncChanges.Name = "SyncChanges"
	SyncChanges.Parent = script

	SyncChanges.Event:Connect(function(cast: TypeDef.ActiveCastData)
		local ID = cast.ID
		local TargetCast = Actives[ID]

		if TargetCast then
			for i, v in cast do
				TargetCast[i] = v
			end
		end
	end)

	return self
end

--[=[
	@method Raycast
	@within BaseCastSerial
]=]
function BaseCastSerial:Raycast(
	Origin: Vector3,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1

	Actives[NextProjectileID] = ActiveCastSerial.createCastData(self, {
		Output = Output,
		ActiveCastCleaner = ActiveCastCleaner,
		ObjectCache = ObjectCache,
		SyncChange = SyncChanges
	}, NextProjectileID, Origin, Direction, Velocity, Behavior, nil, {
		CastType = EnumCastTypes.Raycast
	} :: any)

	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(Actives[NextProjectileID], Origin, Direction, Velocity, Behavior)
	end
end

--[=[
	@method Blockcast
	@within BaseCastSerial
]=]
function BaseCastSerial:Blockcast(
	Origin: Vector3,
	Size: Vector3,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1

	Actives[NextProjectileID] = ActiveCastSerial.createCastData(self, {
		Output = Output,
		ActiveCastCleaner = ActiveCastCleaner,
		ObjectCache = ObjectCache,
		SyncChange = SyncChanges
	}, NextProjectileID, Origin, Direction, Velocity, Behavior, nil, {
		CastType = EnumCastTypes.Blockcast,
		Size = Size
	} :: any)

	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(Actives[NextProjectileID], Origin, Direction, Velocity, Behavior)
	end
end

--[=[
	@method Spherecast
	@within BaseCastSerial
]=]
function BaseCastSerial:Spherecast(
	Origin: Vector3,
	Radius: number,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	NextProjectileID += 1

	Actives[NextProjectileID] = ActiveCastSerial.createCastData(self, {
		Output = Output,
		ActiveCastCleaner = ActiveCastCleaner,
		ObjectCache = ObjectCache,
		SyncChange = SyncChanges
	}, NextProjectileID, Origin, Direction, Velocity, Behavior, nil, {
		CastType = EnumCastTypes.Spherecast,
		Radius = Radius
	} :: any)

	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(Actives[NextProjectileID], Origin, Direction, Velocity, Behavior)
	end
end

--[=[
	@method BindBulkMoveTo
	@within BaseCastSerial
]=]
function BaseCastSerial:BindBulkMoveTo(bool: boolean)
	if bool then
		if not BulkMoveToConnection then
			BulkMoveToConnection = RS.PreRender:Connect(HandleBulkMoveTo)
		end
	else
		if BulkMoveToConnection then
			BulkMoveToConnection:Disconnect()
			BulkMoveToConnection = nil
		end
	end
end

--[=[
	@method BindObjectCache
	@within BaseCastSerial
]=]
function BaseCastSerial:BindObjectCache(bool: boolean)
	if bool then
		if ObjectCache then return end
		local BindableObjectCache = Instance.new("BindableFunction")
		BindableObjectCache.Parent = script
		BindableObjectCache.Name = "ActiveCastObjectCache"
		ObjectCache = BindableObjectCache
	else
		if ObjectCache then
			ObjectCache:Destroy()
			ObjectCache = nil
		end
	end
end

--[=[
	@method TerminateCast
	@within BaseCastSerial
]=]
function BaseCastSerial:TerminateCast(cast: vaildcast, castTerminatingFunction: TypeDef.OnCastTerminatingFunction?)
	if ParentCaster and ParentCaster.TerminateCast then
		ParentCaster:TerminateCast(cast, castTerminatingFunction)
	end
end

--[=[
	@method Destroy
	@within BaseCastSerial
]=]
function BaseCastSerial:Destroy()
	if BulkMoveToConnection then
		BulkMoveToConnection:Disconnect()
		BulkMoveToConnection = nil
	end

	FastCastEventsModule = nil

	for _, v in Actives do
		if ParentCaster and ParentCaster.TerminateCast then
			ParentCaster:TerminateCast(v)
		end
	end

	Actives = {}
	ParentCaster = nil
	setmetatable(self, nil)
end

return BaseCastSerial