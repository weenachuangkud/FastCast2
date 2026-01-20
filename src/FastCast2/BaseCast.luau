--[[
	- Author : Mawin CK
	- Date : 2025
	-- Verison : 0.0.4
]]

-- Services
local HTTPS = game:GetService("HttpService")
local RS = game:GetService("RunService")

-- Requires
local FastCastM = script.Parent
local TypeDefinitions = require(script.Parent.TypeDefinitions)
local TypeDef = require(FastCastM:WaitForChild("TypeDefinitions"))
local Signal = require(FastCastM:WaitForChild("Signal"))
local ActiveCast = require(FastCastM:WaitForChild("ActiveCast"))
local ActiveBlockcast = require(FastCastM:WaitForChild("ActiveBlockcast"))
local BaseCastFunction: BindableFunction = nil
--local ObjectCache = require(FastCastM:WaitForChild("ObjectCache"))

--[=[

@class BaseCast
@private
Base class for all Raycast operations.

]=]
local BaseCast = {}
BaseCast.__index = BaseCast
BaseCast.__type = "BaseCast"

-- Connections
local BulkMoveToConnection: RBXScriptConnection = nil

-- Variables
-- Because each different threads have different BaseCast haha
local Actives: any = {}
local Actor = nil
local Output = nil
local ActiveCastCleaner = nil
local ObjectCache = nil
local CacheHolder = nil
local CanPierceBindableFunction = nil

-- Private functions

local function HandleBulkMoveTo()
	local Parts: { BasePart } = {}
	local CFrames: { CFrame } = {}

	for _, ActiveCasts in Actives do
		local ProjectilePart = ActiveCasts.RayInfo.CosmeticBulletObject
		if not ProjectilePart then
			continue
		end
		if ProjectilePart:IsA("BasePart") then
			table.insert(Parts, ProjectilePart)
			table.insert(CFrames, ActiveCasts.CFrame)
		else
			ProjectilePart:PivotTo(ActiveCasts.CFrame)
		end
	end

	task.synchronize()

	--print("BulkMoveTo parts : ", Parts, "CFrames : ", CFrames)
	workspace:BulkMoveTo(Parts, CFrames, Enum.BulkMoveMode.FireCFrameChanged)
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

	ActiveCastCleaner.Event:Connect(function(activeCastID: string)
		if Actives[activeCastID] then
			--print("CLEANED ACTIVECAST : " .. activeCastID)
			Actives[activeCastID] = nil
			Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks") - 1)
		end
	end)

	CanPierceBindableFunction = Instance.new("BindableFunction")
	CanPierceBindableFunction.Parent = Actor
	CanPierceBindableFunction.Name = "CanPierceBindableFunction"

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
	Behavior: TypeDef.FastCastBehavior,
	GUID: string
)
	--table.insert(self.Actives, ActiveCast.new(self, Origin, Direction, Velocity, Behavior))
	Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks") + 1)

	local activeCastID = GUID
	Actives[activeCastID] = ActiveCast.new({
		Output = Output,
		ActiveCastCleaner = ActiveCastCleaner,
		ObjectCache = ObjectCache,
	}, activeCastID, Origin, Direction, Velocity, Behavior, BaseCastFunction)
end

--[=[

@method CanPierceFunction
@within BaseCast

@param f TypeDef.CanPierceFunction? -- The function to set as the can pierce function.

Set the can pierce function.

]=]
function BaseCast:SetCanPierceFunction(Caster: TypeDefinitions.Caster, f: TypeDefinitions.CanPierceFunction?)
	print("i set that")
	CanPierceBindableFunction.OnInvoke = f
	BaseCastFunction = CanPierceBindableFunction
	print(Caster)
end

--[=[

@method Blockcast
@within BaseCast

@param Origin Vector3 -- The origin of the raycast.
@param Size Vector3 -- The size of the blockcast.
@param Direction Vector3 -- The direction of the raycast.
@param Velocity Vector3 | number -- The velocity of the raycast.
@param Behavior FastCastBehavior -- The behavior data for the raycast.
@param GUID string -- The unique identifier for the raycast.

Create a Blockcast.

]=]
function BaseCast:Blockcast(
	Origin: Vector3,
	Size: Vector3,
	Direction: Vector3,
	Velocity: Vector3 | number,
	Behavior: TypeDef.FastCastBehavior,
	GUID: string
)
	Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks") + 1)

	local activeCastID = GUID
	Actives[activeCastID] = ActiveBlockcast.new({
		Output = Output,
		ActiveCastCleaner = ActiveCastCleaner,
		ObjectCache = ObjectCache,
	}, activeCastID, Origin, Size, Direction, Velocity, Behavior, BaseCastFunction)
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

	if CanPierceBindableFunction then
		CanPierceBindableFunction.OnInvoke = nil
		CanPierceBindableFunction = nil
	end

	for k, v in Actives do
		v:Terminate()
	end

	Actives = {}
	setmetatable(self, nil)
end

return BaseCast
