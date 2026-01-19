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
local TypeDef = require(FastCastM:WaitForChild("TypeDefinitions"))
local Signal = require(FastCastM:WaitForChild("Signal"))
local ActiveCast = require(FastCastM:WaitForChild("ActiveCast"))
local ActiveBlockcast = require(FastCastM:WaitForChild("ActiveBlockcast"))
--local ObjectCache = require(FastCastM:WaitForChild("ObjectCache"))

-- BaseCast
local BaseCast = {}
BaseCast.__index = BaseCast
BaseCast.__type = "BaseCast"

-- Connections
local BulkMoveToConnection : RBXScriptConnection = nil

-- Variables
-- Because each different threads have different BaseCast haha
local Actives = {}
local Actor = nil
local Output = nil
local ActiveCastCleaner = nil
local ObjectCache = nil
local CacheHolder = nil

-- Private functions 

local function HandleBulkMoveTo()
	local Parts : {BasePart} = {}
	local CFrames : {CFrame} = {}

	for _, ActiveCast : TypeDef.ActiveCast in Actives do
		local ProjectilePart = ActiveCast.RayInfo.CosmeticBulletObject
		if not ProjectilePart then continue end
		if ProjectilePart:IsA("BasePart") then
			table.insert(Parts, ProjectilePart)
			table.insert(CFrames, ActiveCast.CFrame)
		else
			ProjectilePart:PivotTo(ActiveCast.CFrame)
		end
	end

	task.synchronize()

	--print("BulkMoveTo parts : ", Parts, "CFrames : ", CFrames)
	workspace:BulkMoveTo(Parts, CFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Public functions

function BaseCast.Init(BindableOutput : BindableEvent, Data : any)
	local self = setmetatable({}, BaseCast)
	-- Others
	--print(BindableOutput.Parent)
	Actor = BindableOutput.Parent
	Actives = setmetatable({}, {__mode = 'v'})
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

	ActiveCastCleaner.Event:Connect(function(activeCastID : string)
		if Actives[activeCastID] then
			--print("CLEANED ACTIVECAST : " .. activeCastID)
			Actives[activeCastID] = nil
			Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks")-1)
		end
	end)

	return self
end

function BaseCast:Raycast(
	Origin : Vector3, 
	Direction : Vector3, 
	Velocity : Vector3 | number, 
	Behavior : TypeDef.FastCastBehavior,
	GUID: string
)
	--table.insert(self.Actives, ActiveCast.new(self, Origin, Direction, Velocity, Behavior))
	Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks")+1)

	local activeCastID = GUID
	Actives[activeCastID] = ActiveCast.new({
		Output = Output,
		ActiveCastCleaner = ActiveCastCleaner,
		ObjectCache = ObjectCache
	}, activeCastID, Origin, Direction, Velocity, Behavior)
end

function BaseCast:Blockcast(
	Origin : Vector3,
	Size : Vector3, 
	Direction : Vector3,
	Velocity : Vector3 | number,
	Behavior : TypeDef.FastCastBehavior,
	GUID : string
)
	Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks")+1)

	local activeCastID = GUID
	Actives[activeCastID] = ActiveBlockcast.new({
		Output = Output,
		ActiveCastCleaner = ActiveCastCleaner,
		ObjectCache = ObjectCache
	}, activeCastID, Origin, Size, Direction, Velocity, Behavior)
end

function BaseCast:BindBulkMoveTo(bool : boolean)
	if bool then
		BulkMoveToConnection = RS.PreRender:ConnectParallel(HandleBulkMoveTo)
	else
		if BulkMoveToConnection then
			BulkMoveToConnection:Disconnect()
			BulkMoveToConnection = nil
		end
	end
end

function BaseCast:BindObjectCache(bool : boolean)
	if bool then
		if ObjectCache then return end
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

function BaseCast:Destroy()
	if BulkMoveToConnection then
		BulkMoveToConnection:Disconnect()
		BulkMoveToConnection = nil
	end
	
	for k, v in Actives do
		v:Terminate()
	end
	
	Actives = {}
	setmetatable(self, nil)
end


return BaseCast
