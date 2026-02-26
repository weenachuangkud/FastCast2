--[[
	- Author : Mawin CK
	- Date : 2025
	-- Verison : 0.0.6
]]

-- Services
--local HTTPS = game:GetService("HttpService")
local RS = game:GetService("RunService")

-- Requires
local FastCast2 = script.Parent
local FastCastM = require(FastCast2)
local TypeDefinitions = require(script.Parent.TypeDefinitions)
local TypeDef = require(FastCast2:WaitForChild("TypeDefinitions"))
--local Signal = require(FastCast2:WaitForChild("Signal"))
local ActiveCast = require(FastCast2:WaitForChild("ActiveCast"))
local ActiveBlockcast = require(FastCast2:WaitForChild("ActiveBlockcast"))
local FastCastEventsModule: ModuleScript? = nil


--[=[

@class BaseCast
@private
Base class for all Raycast operations.

]=]
local BaseCast = {}
BaseCast.__index = BaseCast
BaseCast.__type = "BaseCast"

-- Connections
local BulkMoveToConnection: RBXScriptConnection? = nil

-- Variables
-- Because each different threads have different BaseCast haha
local Actives: any = {}
local Actor = nil
local Output = nil
local ActiveCastCleaner: BindableEvent = nil
local ObjectCache: BindableEvent? = nil
local CacheHolder = nil
local NextProjectileID = 0

local SyncChanges: BindableEvent = nil

-- Private functions

local function HandleBulkMoveTo()
	local Parts: { BasePart } = {}
	local CFrames: { CFrame } = {}

	for _, ActiveCasts in Actives do
		local ProjectilePart = ActiveCasts.RayInfo.CosmeticBulletObject
		if not ProjectilePart then
			continue
		end
		
		local resultCFrame = ActiveCasts.CFrame
		if ProjectilePart:IsA("BasePart") then
			table.insert(Parts, ProjectilePart)
			table.insert(CFrames, resultCFrame)
		else
			ProjectilePart:PivotTo(resultCFrame)
		end
	end

	task.synchronize()

	--print("BulkMoveTo parts : ", Parts, "CFrames : ", CFrames)
	workspace:BulkMoveTo(Parts, CFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function SendCastFire(
	cast: TypeDefinitions.ActiveCastCompement,
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: TypeDef.FastCastBehavior
)
	cast.Caster.Output:Fire("CastFire", cast, origin, direction, velocity, behavior)
end

local function GetCastFireFunction()
	if FastCastEventsModule then
		local loadedModule = require(FastCastEventsModule)
		return loadedModule.CastFire
	end
end

--[=[

@function Init
@within BaseCast

@param BindableOutput BindableEvent -- The BindableEvent used for outputting events.
@param Data any -- Configuration data for the BaseCast.
@return BaseCast -- The initialized BaseCast instance.

To initialize a new BaseCast instance.

]=]
function BaseCast.Init(BindableOutput: BindableEvent, Data: any)
	local self = setmetatable({}, BaseCast)
	-- Others
	--print(BindableOutput.Parent)
	Actor = BindableOutput.Parent
	Actives = setmetatable({}, { __mode = "v" })
	-- Bindable
	Output = BindableOutput

	local BindableCleaner = Instance.new("BindableEvent")
	BindableCleaner.Name = "ActiveCastDestroyer"
	BindableCleaner.Parent = Actor

	if Data.useObjectCache then
		local BindableObjectCache = Instance.new("BindableFunction")
		BindableObjectCache.Parent = Actor
		BindableObjectCache.Name = "ActiveCastObjectCache"
		ObjectCache = BindableObjectCache
		CacheHolder = Data.CacheHolder
	end

	if Data.useBulkMoveTo then
		--print("Connecting PreRender")
		BulkMoveToConnection = RS.PreRender:ConnectParallel(HandleBulkMoveTo)
	end

	ActiveCastCleaner = BindableCleaner

	ActiveCastCleaner.Event:Connect(function(activeCastID: number)
		if Actives[activeCastID] then
			Actives[activeCastID] = nil
			Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks") - 1)
		end
	end)
	
	SyncChanges = Instance.new("BindableEvent")
	SyncChanges.Name = "SyncChanges"
	SyncChanges.Parent = Actor
	
	SyncChanges.Event:Connect(function(cast: TypeDef.ActiveCastCompement)
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
@within BaseCast

@param Origin Vector3 -- The origin of the raycast.
@param Direction Vector3 -- The direction of the raycast.
@param Velocity Vector3 | number -- The velocity of the raycast.
@param Behavior FastCastBehavior -- The behavior data for the raycast.
@param GUID string -- The unique identifier for the raycast.

Create a raycast.

]=]
function BaseCast:Raycast(
	Origin: Vector3,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	--table.insert(self.Actives, ActiveCast.new(self, Origin, Direction, Velocity, Behavior))
	Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks") + 1)
	
	NextProjectileID += 1
	
	Actives[NextProjectileID] = ActiveCast.new({
		Output = Output,
		ActiveCastCleaner = ActiveCastCleaner,
		ObjectCache = ObjectCache,
		SyncChange = SyncChanges
	}, NextProjectileID, Origin, Direction, Velocity, Behavior, FastCastEventsModule)
	
	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(Actives[NextProjectileID], Origin, Direction, Velocity, Behavior)
	end
	if Behavior.FastCastEventsModuleConfig.UseCastFire then
		local CastFireFunction = GetCastFireFunction()
		if CastFireFunction then
			CastFireFunction(Actives[NextProjectileID], Origin, Direction, Velocity, Behavior)
		end
	end
end

--[=[

@method SetFastCastEventsModule
@within BaseCast

@param moduleScript ModuleScript -- The FastCastEventsModule to set.

]=]
function BaseCast:SetFastCastEventsModule(moduleScript: ModuleScript)
	FastCastEventsModule = moduleScript
end

--[=[

@method Blockcast
@within BaseCast

@param Origin Vector3 -- The origin of the raycast.
@param Size Vector3 -- The size of the blockcast.
@param Direction Vector3 -- The direction of the raycast.
@param Velocity Vector3 | number -- The velocity of the raycast.
@param Behavior FastCastBehavior -- The behavior data for the raycast.

Create a Blockcast.

]=]
function BaseCast:Blockcast(
	Origin: Vector3,
	Size: Vector3,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior
)
	Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks") + 1)
	NextProjectileID += 1

	Actives[NextProjectileID] = ActiveBlockcast.new({
		Output = Output,
		ActiveCastCleaner = ActiveCastCleaner,
		ObjectCache = ObjectCache,
		SyncChange = SyncChanges
	}, NextProjectileID, Origin, Size, Direction, Velocity, Behavior, FastCastEventsModule)
	
	if Behavior.FastCastEventsConfig.UseCastFire then
		SendCastFire(Actives[NextProjectileID], Origin, Direction, Velocity, Behavior)
	end
	if Behavior.FastCastEventsModuleConfig.UseCastFire then
		local CastFireFunction = GetCastFireFunction()
		if CastFireFunction then
			CastFireFunction(Actives[NextProjectileID], Origin, Direction, Velocity, Behavior)
		end
	end
end

--[=[

@method BindBulkMoveTo
@within BaseCast

@param bool boolean -- Whether to enable or disable BulkMoveTo.

Enables or disables the BulkMoveTo feature.

]=]
function BaseCast:BindBulkMoveTo(bool: boolean)
	if bool then
		BulkMoveToConnection = RS.PreRender:ConnectParallel(HandleBulkMoveTo)
	else
		if BulkMoveToConnection then
			BulkMoveToConnection:Disconnect()
			BulkMoveToConnection = nil
		end
	end
end

--[=[

@method BindObjectCache
@within BaseCast

@param bool boolean -- Whether to enable or disable ObjectCache.

Enables or disables the ObjectCache feature.

]=]
function BaseCast:BindObjectCache(bool: boolean)
	if bool then
		if ObjectCache then
			return
		end
		local BindableObjectCache = Instance.new("BindableFunction")
		BindableObjectCache.Parent = Actor
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

@method Destroy
@within BaseCast

Destroys the BaseCast instance and cleans up resources.

]=]
function BaseCast:Destroy()
	if BulkMoveToConnection then
		BulkMoveToConnection:Disconnect()
		BulkMoveToConnection = nil
	end

	FastCastEventsModule = nil

	for _, v in Actives do
		FastCastM:TerminateCast(v)
	end

	Actives = {}
	setmetatable(self, nil)
end

return BaseCast
